# Архитектура ZH-sys (ZH-IntegrationPack)

ZH-sys - это модульная система плагинов SourceMod для Counter-Strike: Source, разработанная для интеграции различных игровых модификаций и утилит в единую структуру.

## Компоненты ZH-sys

### Ядро (Core)
- **zh_core**: Основные нативы, логирование, пути к конфигам, базовые функции системы
- **zh_modes**: Переключение игровых режимов (DM/TDM/GG/Chicken/Revive)
- **zh_webbridge**: REST + WebSocket коммуникация для удаленного управления сервером
- **zh_c4**: Управление C4 с кастомными временами детонации

### Модификаторы (Modifiers)
- **zh_mst**: ModelSwitchTool для скинов игроков/бота, классов/моделей/способностей
- **zh_hostages**: Управление заложниками с настройками здоровья, маяков
- **zh_zones**: Зоны на картах для пользовательских областей
- **zh_bots**: Утилиты для настройки ботов (сложность, подсветка и т.д.)

## Структура конфигурационных файлов

```
addons/sourcemod/configs/ZH-sys/
├── Modifiers/
│   ├── Model_Switch_Tool/     # Управление скинами игроков
│   ├── Hostages/              # Настройки поведения заложников
│   ├── Gravity/               # Физические параметры
│   ├── Rule-Health+Armor/     # Настройки здоровья и брони
│   ├── Weapons/               # Изменение параметров оружия
│   ├── Zones/                 # Определение специальных областей
│   ├── Special_items/
│   │   └── C4/                # Настройки C4
│   └── SBC/                   # Комбо дыма, токсичный дым и механики
├── GUI/                       # Графические интерфейсы
├── Tools/                     # Вспомогательные инструменты
│   ├── ZH-Downloader/         # Загрузка ресурсов
│   ├── ZH-Bot_preferences/    # Настройки ботов
│   ├── WebBridge/             # Настройки веб-интерфейса
│   └── Zones/                 # Управление зонами
├── PRD/                       # Кара/награда/дисциплина (MVP, антикампер, тимкилл)
├── SM/                        # Звуковой манифест (событийные аудиоуведомления)
└── Core/                      # Автогенерируемый конфиг zh_core

cfg/sourcemod/                 # AutoExecConfig для core CVARs
```

## Обновленная Архитектура ZH-sys (декабрь 2025)

### Правильное понимание архитектуры

ZH-sys - это модульная система, в которой есть как **Core компоненты** (zh_core, zh_modes, zh_webbridge, zh_c4), так и **Modifier компоненты** (zh_mst, zh_hostages, zh_zones, zh_bots).

ZH-MST (ModelSwitchTool) функционально является важной частью системы, но архитектурно правильно организован как модификатор и расположен в `configs/ZH-sys/Modifiers/Model_Switch_Tool/`. Это не является архитектурной проблемой, а отражает модульный подход проекта.

### Объединение функциональности ZH-MST

Ранее существовали отдельные файлы для ZH-MST:
- `zh_mst.sp` - основной файл с системой скинов и моделей
- `zh_mst_updated.sp` - временный файл с обновлениями
- `zh_mst_tp.sp` - отдельный файл для функциональности от третьего лица

Эта структура нарушала принцип единого плагина для ZH-MST. Была выполнена интеграция всей функциональности в **один единый файл `zh_mst.sp`**, включающий:
- Расширенную систему скинов (regular, female, robot, longsleeve, animal, monster)
- Систему перчаток с поддержкой различных типов скинов
- Функциональность от третьего лица (third-person view) с автоматическим переключением при freeze time
- SDKHooks для отслеживания viewmodel-ов и обновления перчаток

### Обновленная структура конфигурации

Согласно архитектуре ZH-sys, ZH-MST правильно классифицирован как модификатор и его конфигурации должны находиться в:
`addons/sourcemod/configs/ZH-sys/Modifiers/Model_Switch_Tool/`

Основной конфигурационный файл:
- `MST-main-config.cfg` - содержит определения классов, модели, скины, перчатки и типы скинов

Поддерживаемые типы скинов:
- Regular (обычный/стандартный скин)
- Female (женский скин)
- Robot (робот/киборг скин)
- LongSleeve (скин с длинным рукавом)
- Animal (животное)
- Monster (чудовище)

### Нативы и функции ZH-MST

Обновленный ZH-MST включает следующие нативы:
- `MST_DefineClass` - определение классов
- `MST_SetClientClass` - установка класса игроку
- `MST_GetClientClass` - получение текущего класса игрока
- `MST_GetClassAbilityFlags` - получение флагов способностей
- `MST_GetClassModel` - получение модели класса
- `MST_GetClassName` - получение имени класса
- `MST_GetClassSoundProfile` - получение профиля звуков
- `MST_RegisterModel` - регистрация моделей
- `MST_RegisterSound` - регистрация звуков
- `MST_SetClassGloveInfo` - установка информации о перчатках
- `MST_GetClassGloveInfo` - получение информации о перчатках
- `MST_GetClassSkinType` - получение типа скина
- `MST_SetClassSkinType` - установка типа скина
- `MST_TP_SetClientThirdPersonMode` - установка third-person режима
- `MST_TP_GetClientThirdPersonMode` - получение current third-person режима
- `MST_TP_ToggleClientThirdPersonMode` - переключение third-person режима

### Рекомендации по поддержке архитектуры

- Все новые функции ZH-MST должны интегрироваться в единый файл `zh_mst.sp`
- Не создавать дополнительные `zh_mst_*.sp` файлы
- Все конфигурации ZH-MST должны храниться в `configs/ZH-sys/Modifiers/Model_Switch_Tool/`
- Для новой функциональности использовать существующие нативы или добавлять новые в `zh_mst.inc`
- Поддерживать модульную архитектуру ZH-sys, где ZH-MST является важным, но архитектурно правильным модификатором

## Полный список модулей ZH-sys

ZH-sys - это модульная система плагинов SourceMod/MetaMod для Counter-Strike: Source, разработанная для интеграции различных функций в единый каркас. Система состоит из ядра (zh_core) и набора модулей, каждый из которых отвечает за определенную функциональность:

### Ядро
- **zh_core**: Центральное ядро, обеспечивающее базовую инфраструктуру для других модулей

### Модули
- **zh_ammocontrol**: Контроль боеприпасов, кастомная перезарядка дробовиков и система "драконьих пуль" для оружия
- **zh_deathinformer**: Улучшенная система информирования о нанесенном уроне
- **zh_gravity**: Управление гравитацией
- **zh_mst**: Управление моделями игроков и ботов (ModelSwitchTool)
- **zh_prd**: Система наказаний и поощрений (Punish/Reward/Discipline)
- **zh_sm**: Воспроизведение звуковых событий (SoundManifest)
- **zh_sbc**: Система токсичного дыма
- **zh_modes**: Управление игровыми режимами
- **zh_bots**: Расширенное управление ботами
- **zh_c4**: Расширенное управление бомбой C4
- **zh_hostages**: Управление заложниками
- **zh_zones**: Управление пользовательскими зонами
- **zh_webbridge**: Мост для взаимодействия с веб-панелью
- **zh_rha**: Установка здоровья и брони на основе флагов администратора
- **zh_showdamage**: Отображение нанесенного урона игроку
- **zh_steamid**: Показ SteamID игрока

## Интеграция MaterialAdmin с ZH-sys

### ZH-WebBridge улучшения

Плагин `zh_webbridge.sp` был значительно улучшен для лучшей интеграции с MaterialAdmin веб-панелью:

#### Новые функции:
1. **Динамическая валидация CVAR** через конфигурационный файл
   - Использует `configs/ZH-sys/Tools/WebBridge/zh_web_cvar_config.cfg`
   - Позволяет контролировать, какие CVAR могут изменяться через веб-панель
   - Поддерживает проверку типов и диапазонов значений

2. **Безопасное управление CVAR**
   - Только CVAR, перечисленные в конфигурационном файле, могут управляться через веб-панель
   - Поддержка ZH-sys специфичных CVAR (с префиксом `zh_`) по умолчанию
   - Валидация типов (int, float, bool, string) и значений

3. **WebSocket сообщения с JSON**
   - Поддержка различных типов сообщений: `cvar_set`, `server_command`, `config_reload`, `broadcast`
   - Безопасная обработка команд с проверкой разрешений

4. **Интеграция с MaterialAdmin**
   - Настройка через `configs/ZH-sys/Tools/WebBridge/zh_webbridge.cfg`
   - Поддержка REST API и WebSocket соединений
   - Аутентификация через API ключ

#### Конфигурация веб-панели:
- **Файл конфигурации CVAR**: `configs/ZH-sys/Tools/WebBridge/zh_web_cvar_config.cfg`
- **Общая конфигурация**: `configs/ZH-sys/Tools/WebBridge/zh_webbridge.cfg`
- **Поддерживаемые CVAR**: mp_timelimit, mp_maxrounds, mp_winlimit, sv_gravity, sv_maxspeed, mp_friendlyfire, mp_weaponstay, и др.

### WebBridge Configuration

#### CVARs
- `zh_web_mode`: 0=REST only, 1=WebSocket (requires sm-ext-websocket)
- `zh_web_endpoint`: Base URL for REST API (default: http://127.0.0.1/materialadmin/api)
- `zh_web_apikey`: API key/shared secret (default: changeme)
- `zh_web_wsurl`: WebSocket URL (if mode=1) (default: ws://127.0.0.1:8080/ws)

### Web Panel Integration

#### WebSocket Message Format
The WebBridge supports several message types via WebSocket:

1. **CVAR Changes**
   ```json
   {
     "type": "cvar_set",
     "cvar": "mp_timelimit",
     "value": "45"
   }
   ```

2. **Server Commands**
   ```json
   {
     "type": "server_command",
     "cmd": "map de_dust2"
   }
   ```

3. **Configuration Reload**
   ```json
   {
     "type": "config_reload",
     "config": "zh_mst"
   }
   ```

4. **Broadcast Messages**
   ```json
   {
     "type": "broadcast",
     "msg": "Server maintenance in 5 minutes"
   }
   ```

### Security
- All CVAR changes are validated against allowed list
- Server commands are restricted to safe operations
- API key authentication required for all communications

### Available CVARs for Web Control

The following CVARs can be controlled via the web panel:

#### ZH-sys Specific CVARs
- All `zh_` prefixed CVARs are allowed by default
- Includes mode settings, MST configuration, etc.

#### Standard Server CVARs
- `mp_timelimit`, `mp_maxrounds`, `mp_winlimit`, `mp_fraglimit`
- `mp_freezetime`, `mp_roundtime`, `mp_c4timer`, `mp_limitteams`
- `mp_friendlyfire`, `mp_forcecamera`, `sv_alltalk`, `sv_gravity`
- `mp_hostagepenalty`, `mp_autoteambalance`, `mp_scrambleteams_auto`
- `sv_maxspeed`, `sv_accelerate`, and others

### Events and Forwards
Other ZH-sys modules can listen for CVAR changes from the web panel using the forward:
`ZH_WebCvarChanged(const char[] cvarName, const char[] cvarValue)`

### Setup Instructions

1. Configure the WebBridge CVARs with your MaterialAdmin server details
2. Ensure the WebSocket server is running on the specified endpoint
3. Use the API key for authentication
4. The WebBridge will automatically connect and maintain the connection

### Troubleshooting

- Check logs for authentication failures
- Verify WebSocket endpoint is accessible
- Ensure CVARs being changed are in the allowed list
- Monitor heartbeat status for connection health

### Файлы конфигурации веб-панели

1. **zh_webbridge.cfg** - основные настройки подключения к веб-панели
2. **zh_web_cvar_config.cfg** - определяет, какие CVAR могут управляться через веб-панель
3. **databases.cfg** - содержит настройки подключения к базе данных MaterialAdmin

### Безопасность

- Все CVAR, которые можно изменить через веб-панель, должны быть явно указаны в `zh_web_cvar_config.cfg`
- Проверка типов и диапазонов значений для предотвращения некорректных настроек
- API ключ для аутентификации всех запросов
- Ограничение команд, которые могут выполняться через веб-интерфейс

### Поддерживаемые CVAR

Полный список CVAR, поддерживаемых для веб-панели, определяется в `zh_web_cvar_config.cfg`. Ниже приведен расширенный список, извлеченный из исходных кодов CSS:

#### Основные игровые CVAR:
- `mp_teamplay` - включение командной игры
- `mp_falldamage` - урон от падения
- `mp_weaponstay` - оружие остается после подбора
- `mp_forcerespawn` - принудительное возрождение
- `mp_footsteps` - звуки шагов
- `mp_flashlight` - фонарик
- `mp_autocrosshair` - автоматический прицел
- `mp_friendlyfire` - дружественный огонь
- `mp_fadetoblack` - эффект затухания до черного
- `mp_timelimit` - лимит времени
- `mp_fraglimit` - лимит фрагов
- `mp_maxrounds` - максимальное количество раундов
- `mp_winlimit` - лимит побед
- `mp_roundtime` - время раунда
- `mp_freezetime` - время заморозки
- `mp_c4timer` - таймер C4
- `mp_limitteams` - ограничение разницы команд
- `mp_autoteambalance` - автоматическое балансирование команд
- `mp_scrambleteams_auto` - автоматическая перетасовка команд
- `mp_scrambleteams_auto_windifference` - разница побед до перетасовки
- `mp_hostagepenalty` - штраф за заложников
- `mp_startmoney` - начальные деньги

#### Физические CVAR:
- `sv_gravity` - гравитация
- `sv_maxspeed` - максимальная скорость
- `sv_accelerate` - ускорение
- `sv_airaccelerate` - ускорение в воздухе
- `sv_wateraccelerate` - ускорение в воде
- `sv_waterfriction` - трение в воде
- `sv_friction` - трение
- `sv_bounce` - отскок
- `sv_stepsize` - высота шага
- `sv_stopspeed` - скорость остановки

#### Прочие CVAR:
- `sv_alltalk` - все могут разговаривать
- `sv_voiceenable` - включение голосовой связи
- `bot_quota` - количество ботов
- `decalfrequency` - частота декалей
- `sv_cheats` - включение читов
- `sv_pausable` - возможность поставить на паузу
- `sv_contact` - контакт для сервера
- `sv_tags` - теги сервера
- `sv_password` - пароль сервера
- `deathmatch` - режим дм
- `coop` - режим кооператив

## Архитектурные особенности

### Модульная структура

ZH-sys использует модульную структуру, где:
- Ядро предоставляет основные функции и API
- Модификаторы расширяют функциональность
- Интеграция осуществляется через нативы и события

### Установка

1. Скопируйте файлы из `addons/sourcemod/plugins/ZH-sys/` в `addons/sourcemod/plugins/` вашего сервера
2. Скопируйте файлы из `addons/sourcemod/scripting/ZH-scripting/` в `addons/sourcemod/scripting/` вашего сервера
3. Скопируйте файлы из `addons/sourcemod/include/` в `addons/sourcemod/include/` вашего сервера
4. Скопируйте файлы из `addons/sourcemod/translations/ZH-sys/` в `addons/sourcemod/translations/` вашего сервера
5. Скопируйте конфигурационные файлы из `configs/ZH-sys/` в `addons/sourcemod/configs/ZH-sys/` вашего сервера

### Конфигурация

Каждый модуль имеет свои конфигурационные файлы в подкаталогах `addons/sourcemod/configs/ZH-sys/`. Конфигурационные файлы автоматически генерируются через AutoExecConfig при первом запуске.

### Разработка

Новые модули должны:
- Включать `zh_core.inc`
- Вызывать `ZH_RegisterModule()` при старте
- Следовать соглашениям об именовании (префикс `zh_`)
- Использовать систему конфигурации ZH-sys

### Управление ресурсами

- Все ресурсы (модели, звуки, материалы) должны быть доступны через FastDownload
- Загрузка ресурсов осуществляется через ZH-Downloader
- Конфигурация загрузки: `configs/ZH-sys/Tools/ZH-Downloader/`

### Совместимость с системой SourceMod

- Используется SourceMod 1.13 с дополнительными библиотеками
- Плагины могут использоваться совместно с стандартными плагинами SourceMod
- Необходимо учитывать конфликты с: mapchooser, admin-flatfile/admin-sql, antiflood и другими системами

## Историческая информация

ZH-sys развивается из архивной коллекции плагинов, представленной в `In Development/SourceMod/Legacy`, и представляет собой современную интеграцию различных игровых функций в единую систему.