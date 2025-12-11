# Доступные документы и руководство по использованию RAG-функциональности

## Доступные документы

### 1. SourceMod документация (208 файлов)
Расположение: `Documents/sourcemod-wiki/`

**Основные категории:**
- Установка и конфигурация (Installing_SourceMod.txt, SourceMod_Configuration.txt)
- Администрирование (Adding_Admins_SourceMod.txt, Admin_Commands_SourceMod.txt)
- API (Admin_API_SourceMod.txt, Handle_API_SourceMod.txt)
- Скриптинг (Category_SourceMod_Scripting.txt, Commands_SourceMod_Scripting.txt)
- Меню (Admin_Menu_Configuration_SourceMod.txt, Menu_API_SourceMod.txt)
- Работа с базами данных (SQL_SourceMod_Scripting.txt, SQL_Admins_SourceMod.txt)
- Работа с событиями (Events_SourceMod_Scripting.txt, Game_Events_Source.txt)
- Таймеры и потоки (Timers_SourceMod_Scripting.txt, DataPacks.txt)
- Переводы (Translations_SourceMod_Scripting.txt)
- Прочее (Building_SourceMod.txt, Managing_your_Sourcemod_installation.txt)

### 2. Valve SRCDS документация (14 файлов)
Расположение: `Documents/valve-srcds/`

- SRCDS (Source Dedicated Server): Опции запуска, настройка, управление
- Список команд сервера (List_of_CS_S_Cvars.txt)
- Сетевая модель Source (Source_Multiplayer_Networking.txt)
- Опции командной строки (Command_Line_Options.txt)

### 3. MySQL документация
Расположение: `Documents/mysql-refman/`

Содержит справочную информацию по MySQL, включая операторы, функции, команды и административные функции.

### 4. Дополнительные документы в директории Documents

- `MCP_Help.md` - Информация о MCP серверах (DocsRAG и File Finder)
- `RAG_Help.md` - Подробное руководство по RAG-системе
- `README_RAG.md` - Структура документации для RAG-системы
- `Source_Engine_Notes.md` - Заметки по Source Engine

## Руководство по использованию RAG-функциональности

### Обзор RAG-системы

RAG (Retrieval Augmented Generation) система позволяет эффективно запрашивать документацию по плагинам Counter-Strike: Source. Система использует ChromaDB для хранения векторных представлений документации и позволяет находить наиболее релевантные фрагменты текста по запросу.

### Компоненты системы

1. **rag_context.py** - основной скрипт, обеспечивающий:
   - Индексацию документов в ChromaDB
   - Поиск релевантных фрагментов по запросу
   - Возвращение топ-N релевантных фрагментов с указанием источника

2. **rag_agent.ps1** - PowerShell-скрипт, обеспечивающий интеграцию с агентами:
   - Автоматическая установка зависимостей
   - Вызов rag_context.py с правильными параметрами
   - Передача результата в CODEX, Gemini или Qwen

3. **rag_query.py** - обертка для более удобного программного доступа к системе

### Использование с агентами

#### Через MCP (рекомендуемый способ):

Система RAG доступна через MCP-серверы:
- `mcp-docs-rag` - RAG по локальной документации (Node 18+)
- `file-finder-mcp` - поиск файлов по фрагменту пути

Команда для проверки доступных серверов: `/mcp list`

#### Через командную строку (альтернативный способ):

```
# Для CODEX
.\rag-agent.ps1 codex "Ваш запрос к документации"

# Для Gemini
.\rag-agent.ps1 gemini "Ваш запрос к документации"

# Для Qwen
.\rag-agent.ps1 qwen "Ваш запрос к документации"
```

Если директория с документацией отличается от `Documents`, можно указать путь явно:

```
.\rag-agent.ps1 codex -DocsDir "путь\к\документации" "Ваш запрос"
```

#### Через Python-скрипт:

```
python rag_query.py --query "Ваш запрос к документации" --top-k 3
```

### Принцип работы системы

1. При первом обращении к документации система индексирует все текстовые файлы в директории
2. Документы разбиваются на фрагменты с небольшим перекрытием
3. Для каждого фрагмента вычисляется векторное представление
4. При поиске запрос векторизуется и ищутся наиболее близкие фрагменты
5. Результаты возвращаются с указанием файла и номера строки

### Индексируемые форматы файлов

Система индексирует файлы следующих расширений:
- .txt, .md, .html, .htm
- .inc, .sp (файлы SourcePawn)
- .json, .rst

### Примеры запросов

Примеры типичных запросов к системе:
- "Как создать админа в SourceMod?"
- "Синтаксис функции OnPlayerConnect"
- "Настройка SQL базы данных для плагинов"
- "Как создать меню в SourceMod?"
- "Работа с базами данных в SourceMod"
- "Настройка команд в SourceMod"
- "API для работы с игроками в SourceMod"