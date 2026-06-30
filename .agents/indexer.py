import os
import json
import urllib.request
import urllib.error

# Настройки
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "qwen2.5-coder:14b-instruct-q6_K"

TARGET_DIRS = [
    "/mnt/2TB-NVME/mge_engineer/ZH-sys/For Games/CSS/for debugging/Counter-Strike-Plugins/In Development/Metamod+SourceMod/Legacy",
    "/mnt/2TB-NVME/mge_engineer/ZH-sys/For Games/CSS/for debugging/Counter-Strike-Plugins/CSS-GH"
]

OUTPUT_FILE = "/mnt/2TB-NVME/mge_engineer/ZH-sys/For Games/CSS/for debugging/Counter-Strike-Plugins/.agents/Architecture_Map.md"

PROMPT_TEMPLATE = """
Ты — старший инженер по SourcePawn. Твоя задача — проанализировать исходный код плагина и извлечь ключевую информацию.
Ответь СТРОГО в формате JSON, без лишнего текста, маркдауна или комментариев. Формат:
{{
    "summary": "Краткое описание (1-2 предложения) того, что делает этот код.",
    "includes": ["список", "зависимостей", "из", "#include"],
    "commands": ["список", "зарегистрированных", "команд", "RegConsoleCmd", "RegAdminCmd"],
    "convars": ["список", "созданных", "ConVar"]
}}

Код для анализа:
{code}
"""

def query_ollama(prompt):
    data = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "stream": False,
        "format": "json"
    }
    req = urllib.request.Request(OLLAMA_URL, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            result = json.loads(response.read().decode('utf-8'))
            return json.loads(result['response'])
    except Exception as e:
        print(f"Ошибка обращения к Ollama: {e}")
        return None

def process_file(filepath):
    print(f"Обработка: {filepath}")
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Если файл огромный, пока берем первые 20000 символов (RLM-подход для экономии контекста)
    if len(content) > 20000:
        content = content[:20000]

    prompt = PROMPT_TEMPLATE.format(code=content)
    result = query_ollama(prompt)
    return result

def main():
    print(f"Запуск индексатора с моделью {MODEL_NAME}...")
    results = {}
    
    for directory in TARGET_DIRS:
        if not os.path.exists(directory):
            print(f"Директория не найдена: {directory}")
            continue
            
        for root, _, files in os.walk(directory):
            for file in files:
                if file.endswith(('.sp', '.inc')):
                    filepath = os.path.join(root, file)
                    res = process_file(filepath)
                    if res:
                        results[filepath] = res
                    else:
                        print(f"Пропуск {file} из-за ошибки анализа.")

    # Запись в Markdown
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("# Карта архитектуры (Legacy & CSS-GH)\n\n")
        for filepath, data in results.items():
            f.write(f"## Файл: `{os.path.basename(filepath)}`\n")
            f.write(f"**Путь:** `{filepath}`\n\n")
            f.write(f"**Описание:** {data.get('summary', 'Нет описания')}\n\n")
            f.write(f"**Includes:** {', '.join(str(x) for x in data.get('includes', []))}\n\n")
            f.write(f"**Commands:** {', '.join(str(x) for x in data.get('commands', []))}\n\n")
            f.write(f"**ConVars:** {', '.join(str(x) for x in data.get('convars', []))}\n\n")
            f.write("---\n")
            
    print(f"Индексация завершена. Результат в {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
