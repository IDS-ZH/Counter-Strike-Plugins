import sys
import re
from collections import Counter

def process_log(file_path):
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
        
    counts = Counter()
    for line in lines:
        line = line.strip()
        if not line: continue
        
        # Убираем даты и время вида "06/24 22:07:07" или "L 06/24/2026 - 22:07:07:"
        line = re.sub(r'^(L )?\d{2}/\d{2}(/\d{4})? -? \d{2}:\d{2}:\d{2}:?\s*', '', line)
        line = re.sub(r'^\d{2}/\d{2} \d{2}:\d{2}:\d{2}\s*', '', line)
        
        # Упрощаем имена игроков, SteamID, IP-адреса, чтобы схлопнуть одинаковые события
        # Пример: "Player"<1><STEAM_0:1:1234><CT>
        line = re.sub(r'"[^"]+"<\d+><STEAM_[0-9:]+><[^>]*>', '<PLAYER>', line)
        line = re.sub(r'STEAM_[0-9:]+', '<STEAM_ID>', line)
        line = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+\b', '<IP:PORT>', line)
        line = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '<IP>', line)
        
        # Упрощаем технические ID (потоки, версии)
        line = re.sub(r'tid\(\d+\)', 'tid(<TID>)', line)
        line = re.sub(r'version\(\d+\)', 'version(<VERSION>)', line)
        line = re.sub(r'Steam ID:  \d+', 'Steam ID:  <STEAM64>', line)
        
        counts[line] += 1
        
    print(f"=== Карта Шума для {file_path} ===\n")
    for line, count in counts.most_common():
        print(f"[{count:5d} упоминаний] {line}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Использование: python generate_noise_map.py <путь_к_логу>")
    else:
        process_log(sys.argv[1])
