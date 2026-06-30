import sys
import json
import requests
import re
from pathlib import Path

OLLAMA_API = "http://localhost:11434/api/generate"
MODELS = ["granite4.1:8b", "gemma4:e4b-it-q8_0"]

LOG_PATHS = [
    "/mnt/1tb_storage/SRCDS/CS_Source/cstrike/console.log",
    "/mnt/2TB-NVME/mge_engineer/ZH-sys/For Games/CSS/for debugging/Counter-Strike-Plugins/Журналы AppId 240 AppId 232330/vanilla_noise_log_2026-06-26_21-04-12.log"
]

def query_ollama(prompt, model):
    payload = {
        "model": model,
        "prompt": prompt,
        "system": "You are a senior Source Engine and Counter-Strike: Source technical expert. Analyze the provided server logs and identify critical errors, missing assets, configuration issues, or performance warnings. Be concise, technical, and output your findings in Markdown.",
        "stream": False,
        "options": {
            "num_thread": 6,
            "num_predict": 1024,
            "num_ctx": 8192,
            "temperature": 0.2
        }
    }
    try:
        response = requests.post(OLLAMA_API, json=payload, timeout=300)
        response.raise_for_status()
        return response.json().get("response", "").strip()
    except Exception as e:
        return f"Error analyzing with {model}: {e}"

def extract_anomalies(log_text):
    anomalies = []
    # Keywords to look for
    keywords = ["error", "warning", "fail", "missing", "cannot", "exception", "not found", "bad", "invalid"]
    # Filter out common noise that is not an error
    noise_keywords = ["killed", "attacked", "triggered", "entered the game", "connected", "bot_kill"]
    
    for line in log_text.splitlines():
        line_lower = line.lower()
        if any(k in line_lower for k in keywords) and not any(nk in line_lower for nk in noise_keywords):
            anomalies.append(line.strip())
            
    # Remove duplicates but preserve order
    seen = set()
    unique_anomalies = []
    for a in anomalies:
        if a not in seen:
            seen.add(a)
            unique_anomalies.append(a)
            
    return "\n".join(unique_anomalies)

if __name__ == "__main__":
    combined_log_text = ""
    for path in LOG_PATHS:
        p = Path(path)
        if p.exists():
            print(f"[+] Чтение файла: {p.name} (Размер: {p.stat().st_size / 1024:.2f} KB)")
            with open(p, 'r', encoding='utf-8', errors='replace') as f:
                combined_log_text += f.read() + "\n"
        else:
            print(f"[-] Файл не найден: {path}")

    print("\n[+] Извлечение аномалий и ошибок из логов...")
    anomalies_text = extract_anomalies(combined_log_text)
    
    print(f"[!] Найдено {len(anomalies_text.splitlines())} уникальных строк с ошибками/предупреждениями.")
    
    # Ограничиваем длину лога, чтобы он поместился в контекст
    if len(anomalies_text) > 20000:
        anomalies_text = anomalies_text[:20000] + "\n...[TRUNCATED]"

    prompt = f"Here is the filtered list of warnings and errors from a vanilla CS:S server log. Please analyze them and group them by category (e.g., Engine Errors, Network Warnings, Missing Files). Explain what they mean and if they need fixing:\n\n{anomalies_text}"

    report_file = "Log_Analysis_Report.md"
    with open(report_file, 'w', encoding='utf-8') as rf:
        rf.write("# Анализ журналов Vanilla CS:S сервера\n\n")

    for model in MODELS:
        print(f"\n[+] Запуск анализа моделью {model}...")
        report = query_ollama(prompt, model)
        
        with open(report_file, 'a', encoding='utf-8') as rf:
            rf.write(f"## Отчет модели {model}\n\n{report}\n\n---\n\n")
            
        print(f"    [✓] Модель {model} завершила анализ.")
        
        # Выгружаем модель из памяти
        try:
            requests.post(OLLAMA_API, json={"model": model, "keep_alive": 0}, timeout=10)
        except:
            pass

    print(f"\n[✓] Анализ завершен! Отчет сохранен в файл: {report_file}")
