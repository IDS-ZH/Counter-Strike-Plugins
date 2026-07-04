# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Общайся с человеком на русском языке (он отлично его понимает). Документы и вставки кода могут быть на другом языке.

## Что это за проект

Моддинг выделенного сервера Counter-Strike: Source (SRCDS, AppID 232330) под GNU/Linux —
система **ZH-sys** («ZloyHohol-IntegrationPack»). Это не одно приложение, а конвейер:
чужие Legacy-плагины → анализ/тегирование → адаптация в модульные `zh_*` модули →
компиляция SourcePawn 1.13 → деплой `.smx` на локальный сервер → тестирование.

Существует `AGENTS.md` — он написан под Windows (`D:\`, `R:\`, `.exe`) и **устарел** для
текущей Linux-среды. Верить Linux-командам из этого файла, а не Windows-путям из AGENTS.md.

## Два физических дерева

- **Дерево разработки (этот репозиторий):** `/mnt/2TB-NVME/mge_engineer/ZH-sys/For Games/CSS/for debugging/Counter-Strike-Plugins/` — исходники, компилятор, документация, MCP-серверы.
- **Рантайм-сервер (cwd сессии):** `/mnt/1tb_storage/SRCDS/CS_Source/` — чистый SRCDS от Valve + развёрнутые MetaMod/SourceMod. Сюда кладутся скомпилированные `.smx` и отсюда запускается сервер.

Деплой = копирование `.smx` (и конфигов/переводов) из dev-дерева в
`/mnt/1tb_storage/SRCDS/CS_Source/cstrike/addons/sourcemod/{plugins,configs,translations}`.
Серверный SM-инсталл — **отдельная копия**, не симлинк на `MM+SM/`.

## Сборка и запуск (Linux, реальные команды)

Компилятор SourcePawn 1.13.0.7375 (только Linux):
```
SP="/mnt/2TB-NVME/mge_engineer/ZH-sys/For Games/CSS/for debugging/Counter-Strike-Plugins/MM+SM/sourcemod-1.13.0-git7375-linux/addons/sourcemod/scripting"
cd "$SP" && ./spcomp64 -i./include -o<out.smx> <plugin.sp>
```
Батч: `compile.sh` в `scripting/` (если есть) либо перебор `*.sp` циклом. Чистая компиляция
(0 errors, 0 warnings) — минимальный гейт; warnings в spcomp часто = tag mismatch, роняющий сервер.

Запуск сервера (из cwd `/mnt/1tb_storage/SRCDS/CS_Source`):
- со SourceMod: `./run_sourcemod_test.sh` → `./srcds_run -game cstrike -console -insecure -nomaster -dev +map de_port -maxplayers 20 -condebug +log on`
- ванильный (для сбора «шумов»): `./run_vanilla_noise_dump.sh`
- Логи пишутся в `Журналы AppId 240 AppId 232330/` (в dev-дереве).

Загрузить плагин на работающем сервере: `sm plugins load <Name>` (через rcon/`-netconport`).
Проверка модулей ZH-sys: команда `sm_zhdiag`.

## Архитектура ZH-sys (большая картина)

Единый источник истины — `ZH-IntegrationPack/All_Docs.md` (~1900 строк, мастер-спека).
Рабочие журналы агентов: `ZH-IntegrationPack/Codex_Worklog.md`, `Gemini3-worklog.md`.
Стратегия миграции на Linux — `ZH-IntegrationPack/GNU-Linux_update.md` (отказ от коробочных
панелей Pterodactyl/LinuxGSM в пользу vanilla SRCDS + свой лёгкий стартер; используются только
как референсы для tmux/steamcmd/watchdog/RCON).

Продакшн-код живёт в `ZH-IntegrationPack/Zh-sys/` (зеркало `cstrike/`):
`addons/sourcemod/{scripting,scripting/include,plugins,configs,translations}` + `MetaMod-Sources/`.
Модули (по `All_Docs.md` §2):
- **zh_core** — фундамент: `ZH_IsValidClient`, `ZH_Log`, `ZH_RegisterModule`. Раньше `IsValidClient`
  копировался в каждый файл — теперь централизован здесь.
- **zh_mst** (ModelSwitchTool) — скины/руки/цвета, конфиги `Player-settings/`, `Bot-settings/`, `Modifiers/Model_Switch_Tool/`.
- **zh_prd** (Punish/Reward/Discipline) — TK-менеджмент, MVP, меню наказаний (скин «Курицы» через MST).
- **zh_sound** (SoundManifest) — звуковые события, жёстко связан с ядром.
- **zh_sbc** (SmokeBombCombo) и др.

Конфиг-стандарт: корень `addons/sourcemod/configs/ZH-sys/`, категории `Core/GUI/Modifiers/Tools`,
все конфиги поддерживают переопределение для карты (Map Overrides). Переводы —
`addons/sourcemod/translations/SM_<Plugin>.phrases.txt`.

### Канон портирования плагинов (Win32/MFC → Linux/Qt6)
Отдельная подзадача — портирование редактора Valve Hammer. Реализовано как MCP-сервер
`port_hammer_mcp` (см. `/mnt/2TB-NVME/.../MCP/port_hammer_mcp/`, зарегистрирован в
`~/.gemini/config/mcp_config.json`). Локальные Ollama-модели делают черновик, Gemini/Codex
получают только компактные refine-пакеты. Ядро — `port_core.py`, CLI-враппер —
`служебные сценарии/port_hammer_multiagent.py`. Не путать с SourcePawn-плагинами.

## Legacy: адаптация чужих плагинов

`In Development/Metamod+SourceMod/Legacy/` — 574 чужих плагина/фрагмента (`.sp`/`.inc`),
сгруппированных в 14 категорий (`Other`, `VIP_System_or_AS`, `Bots_and_NPCs`, `Weapons_and_Guns`,
`Shop_System`, `Zombie_Mods`, `UI_Menus_MOTD`, `Physics_and_DM`, `Platform_*` и др.).

Workflow — модуль `MCP/legacy_analyzer/` (переписан со scratch-скриптов Gemini; старый
`process_all_ollama.py`/`group_legacy.py`/`init_registry.py` в brain-scratch — deprecated-референс).
Ядро `legacy_core.py`, MCP-сервер `legacy_mcp.py` (зарегистрирован как `legacy-mcp` в
`~/.gemini/config/mcp_config.json`), CLI-враппер `служебные сценарии/legacy_phase1.py`.
Статусы `PENDING`/`IN_PROGRESS`/`PHASE1_COMPLETED`/`PHASE2_COMPLETED`, чекпойнт после каждого item (resume-safe).
Модель `gemma4_128k` (128k, хороший русский) — файл целиком, структурированный JSON
`{mechanic, architecture_notes, adaptability_notes, tags, analysis_md}`. Теги поднимаются в реестр
(`[TAG: ENGINE_HAVOK_CHECK]`/`[TAG: NAVMESH_CHECK]`/`[TAG: CUSERCMD_SPOOFING]`/`[TAG: GAMEDATA_SIGNATURE]`/
`[TAG: HUGE_MODPACK_MANUAL_REVIEW]`, >5MB → HUGE без модели). Томы в `Documents/Reports/Legacy_Library/<category>.md`.
Рукописные блоки Vol1_Bots (intro + инженерные заметки) сохраняются через `extract_manual_blocks`
и вшиваются в новый `Bots_and_NPCs.md`.

Перепрогон Phase 1: `python3 "служебные сценарии/legacy_phase1.py" {env,group --force,init --reset,
analyze-all --force}` (фон, ~5-10 ч на RX 6900 XT, resume-safe). `PHASE2_COMPLETED` (ручная
инженерная адаптация в `zh_*`) ещё не начат. **Бывший кавеат с `???` в томах устранён** —
старые тома в brain-scratch (`Legacy_Library_*.md`, кодировка `???` от `qwen2.5-coder`) не использовать;
актуальные — в `Documents/Reports/Legacy_Library/`.

## MCP-инфраструктура (для Gemini/Antigravity IDE)

Конфиг живого Antigravity: `~/.gemini/config/mcp_config.json` (не путать с устаревшим
`mcp_config.json` в корне этого репо и с `Documents/MCP_Help.md` — оба Windows-старые).
Серверы (FastMCP, stdio, `python3 <path>.py`):
- **css-rag** — ChromaDB RAG по `Documents/` (SourceMod/C++/Valve wiki).
- **ollama-minion** — ReAct-тул с уровнями прав `none`/`read`/`read_write`, вызывает локальные Ollama.
- **port-hammer-mcp** — портирование Hammer + VMF-манipуляции (14 тулов).
- **legacy-mcp** — Phase-1 анализ чужих Legacy-плагинов (gemma4_128k, JSON, resume). См. `MCP/legacy_analyzer/README.md`.

GPU-изоляция Ollama уже в systemd-юните (`ROCR_VISIBLE_DEVICES=GPU-1a432fe5aeddc8b0` = RX 6900 XT,
не Vega APU). Локальные алиасы моделей имеют `num_ctx` на максимуме (`granite4.1_128k`,
`gemma4_128k`, `qwen3-vl_256k` и т.д.). `qwen2.5-coder` имеет контекст только 32k — не годится
для сшивки больших файлов, только для коротких задач.

## SourcePawn-конвенции

`#pragma semicolon 1`, `#pragma newdecls required`, новый синтаксис (`int client`, `void F()`,
`delete handle`), 4 пробела, скобки на отдельной строке. Глобальные — префикс `g_`, enum'ы в
ALL_CAPS с чёткими разделителями (`MST_ABILITY_REVIVE`, не `MSTAbility_Revive`). CVAR/команды —
в неймспейсе `sm_<plugin>_*`. Конфиги через `AutoExecConfig()` в `cfg/sourcemod/`.

Коммиты: `<type>(scope): summary` (например `feat(SoundManifest): ...`), история смешивает
русский/английский. При правке плагина обновлять соответствующий `.md` (например
`SoundManifest-3.2-Documentation.md`) и `Development_Changelog.md`.

## Архитектурные запреты

- Не дублировать каталоги для настройки одной сущности в разных местах (конфиги C4, скины MST
  — не в CORE; единое место — `configs/ZH-sys/`).
- Не вставлять хардкод-строки меню/чата в `.sp` — выносить в `.phrases.txt`.
- Ассеты референсить полными путями `sound/plugins/<plugin>/...`, размеры — в рамках лимитов
  плагина (например SoundManifest 50МБ), не предполагать VFS.
- `copy_includes.sh` и `Documents/MCP_Help.md` содержат **устаревшие Windows/WSL-пути**
  (`/mnt/d/Documents/Archives/...`) — не использовать как референс путей, сверяться с `MM+SM/`.

## Ключевые ссылки

- `CSS-GH/` — две народные сборки исходников CS:S (CSS_SDK_2007/hl2sdk-css, CSS_BASE-2007) для
  исследования сигнатур/патчей; Source SDK Base 2013 MP/SP.
- `Standalone/` — готовые независимые плагины (Ammunition_control, SoundManifest, SBC_V3, PRD,
  Gravity Switcher, HUD_Damage и др.); реестр их статусов — `Standalone/register_functionality.md`.
- `Documents/` — SourceMod wiki, valve-srcds, source_SDK_2013-MP, Source_Engine_Notes.md, RAG-доки.