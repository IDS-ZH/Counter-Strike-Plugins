import requests
from bs4 import BeautifulSoup
import json
import time
import sys
from urllib.parse import urljoin
import urllib3
import resource

# Защита от дурака (OOM Killer). Ограничиваем Python процесс 1 Гигабайтом ОЗУ.
# Это гарантирует, что даже если случится утечка в Beautifulsoup или парсинге, 
# упадет только сам скрипт, а не всё ПО на сервере.
try:
    MAX_VIRTUAL_MEMORY = 1 * 1024 * 1024 * 1024 # 1 GB
    resource.setrlimit(resource.RLIMIT_AS, (MAX_VIRTUAL_MEMORY, resource.RLIM_INFINITY))
except ValueError:
    pass

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Настройка Ollama
OLLAMA_API = "http://localhost:11434/api/generate"
MODEL_EXTRACTOR = "granite4.1:8b" # Быстрый сборщик с большим окном контекста
MODEL_SUPERVISOR = "gemma4:e4b-it-q8_0"  # Быстрый надзиратель

def query_ollama(prompt, model, system_prompt=""):
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system_prompt,
        "stream": False,
        "format": "json",
        "options": {
            "num_thread": 6, 
            "num_predict": 1024,
            "num_ctx": 8192, # Явно задаем окно контекста для больших кусков текста
            "temperature": 0.1
        }
    }
    
    try:
        response = requests.post(OLLAMA_API, json=payload, timeout=240)
        response.raise_for_status()
        return response.json().get("response", "").strip()
    except Exception as e:
        print(f"Ошибка Ollama API: {e}")
        return None

def extract_nuggets(thread_url, text, thread_title):
    sys_prompt = "You are a SourceMod and Counter-Strike: Source expert. Extract the core problem and solution."
    
    solved_hint = ""
    if "[решено]" in thread_title.lower() or "решено" in thread_title.lower():
        solved_hint = "IMPORTANT: This thread title indicates it is SOLVED. A definitive solution is present in the text. Find it."
        
    prompt = f"""
    Analyze the following forum thread text containing multiple posts.
    Thread Title: {thread_title}
    {solved_hint}
    
    If it contains a clear technical problem and a solution regarding CS:S or SourceMod, output a JSON object with strictly two keys: "problem" and "solution".
    If there is no clear problem/solution, output exactly {{}}.
    
    Text:
    {text[:20000]}
    """
    
    extracted_raw = query_ollama(prompt, MODEL_EXTRACTOR, sys_prompt)
    if not extracted_raw or extracted_raw == "{}" or extracted_raw == '{"problem": "", "solution": ""}':
        return None
        
    try:
        data = json.loads(extracted_raw)
        if "problem" not in data or "solution" not in data: return None
        if not isinstance(data.get("problem"), str) or not isinstance(data.get("solution"), str): return None
        if len(data["problem"]) < 10 or len(data["solution"]) < 10: return None
        return data
    except json.JSONDecodeError:
        return None

def supervise_nuggets(data, thread_title):
    sys_prompt = "You are a SourceMod technical reviewer. Only reject impossible hallucinated fixes."
    
    solved_hint = ""
    if "[решено]" in thread_title.lower() or "решено" in thread_title.lower():
        solved_hint = "IMPORTANT: This thread title indicates it is SOLVED. Do NOT blindly reject the solution, as the author has confirmed it works."
        
    prompt = f"""
    Review this extracted problem and solution for Counter-Strike: Source / SourceMod.
    Thread Title: {thread_title}
    {solved_hint}
    
    Reject it ONLY if it contains technically impossible actions (like deleting Windows folders to fix a server, using Unreal Engine functions, etc).
    If it is a valid configuration change (like sv_pure 0), a valid SourceMod plugin suggestion, or a logical fix, output the exact same JSON.
    If it is absolute nonsense, output exactly {{}}.
    
    JSON:
    {json.dumps(data, ensure_ascii=False)}
    """
    
    supervised_raw = query_ollama(prompt, MODEL_SUPERVISOR, sys_prompt)
    if not supervised_raw or supervised_raw == "{}": return None
    
    try:
        return json.loads(supervised_raw)
    except json.JSONDecodeError:
        return None

def get_thread_posts(thread_base_url, headers):
    thread_text = []
    for page in range(1, 4):
        url = f"{thread_base_url}page-{page}" if page > 1 else thread_base_url
        try:
            tr = requests.get(url, headers=headers, timeout=10, verify=False)
            if tr.status_code == 404: break 
            tr.raise_for_status()
            
            tsoup = BeautifulSoup(tr.text, 'html.parser')
            posts = tsoup.select('article.message')
            if not posts and page == 1: return []
            if not posts: break
            
            for idx, post in enumerate(posts):
                text_content = post.text.strip()
                thread_text.append(f"Post {idx+1} (Page {page}):\n{text_content}")
                
            if not tsoup.select('ul.pageNav-main'):
                break
                
        except Exception as e:
            print(f"     Ошибка парсинга страницы темы {url}: {e}")
            break
            
    return thread_text

def scrape_page(page_num):
    base_url = "https://hlmod.net/forums/counter-strike-source.73/"
    url = f"{base_url}page-{page_num}" if page_num > 1 else base_url
    print(f"\n[+] Парсинг раздела: {url}")
    
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
    try:
        r = requests.get(url, headers=headers, timeout=10, verify=False)
        r.raise_for_status()
    except Exception as e:
        print(f"Ошибка доступа к {url}: {e}")
        return [], []
        
    soup = BeautifulSoup(r.text, 'html.parser')
    threads = soup.select('div.structItem-title a[data-tp-primary="on"]')
    
    # === ФАЗА 1: Экстракция (Работает только 1-я модель) ===
    # Это предотвращает выгрузку моделей из VRAM туда-сюда на каждой теме
    print("\n[+] ФАЗА 1: Экстракция данных (Модель Сборщика в VRAM)...")
    extracted_items = []
    
    for t in threads:
        thread_title = t.text.strip()
        thread_link = urljoin(base_url, t['href'])
        
        thread_text_list = get_thread_posts(thread_link, headers)
        if not thread_text_list: continue
        
        post_text = "\n\n".join(thread_text_list)
        post_text = " ".join(post_text.split())[:20000]
        
        extracted = extract_nuggets(thread_link, post_text, thread_title)
        if not extracted: 
            print(f"  [-] Нет решения: {thread_title[:40]}...")
            continue
            
        extracted['url'] = thread_link
        extracted['title'] = thread_title
        extracted_items.append(extracted)
        print(f"  [+] Извлечено: {thread_title[:40]}...")
        time.sleep(1)
        
    # === ФАЗА 2: Надзор (Работает только 2-я модель) ===
    print(f"\n[+] ФАЗА 2: Проверка {len(extracted_items)} записей (Модель Надзирателя в VRAM)...")
    results = []
    quarantine = []
    
    for item in extracted_items:
        supervised = supervise_nuggets(item, item['title'])
        if not supervised: 
            print(f"  [Х] Брак: {item['title'][:40]}... (Отправлено в карантин)")
            quarantine.append(item)
            continue
            
        supervised['url'] = item['url']
        supervised['title'] = item['title']
        results.append(supervised)
        print(f"  [V] Одобрено: {supervised.get('problem')[:30]}...")
        
    return results, quarantine

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Использование: python3 spider_hlmod.py <кол-во_страниц>")
        sys.exit(1)
        
    pages_to_scrape = int(sys.argv[1])
    all_nuggets = []
    all_quarantine = []
    
    for p in range(1, pages_to_scrape + 1):
        nuggets, quarantine = scrape_page(p)
        all_nuggets.extend(nuggets)
        all_quarantine.extend(quarantine)
        
    with open('hlmod_nuggets.jsonl', 'w', encoding='utf-8') as f:
        for n in all_nuggets:
            f.write(json.dumps(n, ensure_ascii=False) + '\n')
            
    with open('quarantine.jsonl', 'w', encoding='utf-8') as f:
        for q in all_quarantine:
            f.write(json.dumps(q, ensure_ascii=False) + '\n')
            
    # Принудительно выгружаем модели из памяти Ollama, чтобы не было OOM после завершения скрипта
    print("\n[+] Выгрузка моделей из памяти Ollama...")
    try:
        requests.post(OLLAMA_API, json={"model": MODEL_EXTRACTOR, "keep_alive": 0}, timeout=10)
        requests.post(OLLAMA_API, json={"model": MODEL_SUPERVISOR, "keep_alive": 0}, timeout=10)
    except:
        pass
        
    print(f"[✓] Готово! Сохранено {len(all_nuggets)} проверенных записей.")
