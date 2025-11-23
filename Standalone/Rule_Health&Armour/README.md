# Ruler Health & Armour (RHA)

This plugin allows server administrators to configure custom health and armor values for players based on their admin flags. It also includes configurable immortality features and settings for bots.

## Installation

1.  Copy `ruler_health_armour.smx` to your server's `addons/sourcemod/plugins/` directory.
2.  The configuration file will be automatically generated at `addons/sourcemod/configs/RHA.cfg` on the first run.

## Commands

The plugin's functions are managed through the admin menu.

*   **`sm_admin`** -> **`Player Commands`** -> **`RHA Settings`**
    *   This opens the main menu for the RHA plugin. Access is granted to admins who are part of a group with `"CanUseImmortality" "1"` in the configuration.
    *   **Plugin Status: [Enabled/Disabled]**: A master switch to turn the entire plugin on or off. When disabled, all players will have default health/armor.
    *   **Set Immortality Mode**: Opens a submenu to set the global immortality mode for all eligible admins.
        *   `0`: Disabled
        *   `1`: Invincible (takes no damage)
    *   **Reset Player HP/Armor**: Opens a menu to select any player on the server and reset their Health and Armor to 100.

## CVars (Console Variables)

*   **`sm_rha_enabled`** (Default: 1)
    *   The master switch for the plugin. `1` = On, `0` = Off.

*   **`sm_rha_admin_immortality_mode`** (Default: 0)
    *   Sets the global immortality mode for eligible admins (0: Disabled, 1: Invincible). Can be changed via the admin menu.

*   **`sm_rha_enable_logging`** (Default: 0)
    *   Enable/Disable logging for RHA plugin actions. `0` = Off, `1` = On. Logs are saved to `addons/sourcemod/logs/rha-YYYY-MM-DD.log`.

*   **`sm_rha_version`**
    *   The current version of the plugin (read-only).

## Configuration (`addons/sourcemod/configs/RHA.cfg`)

The plugin is configured using a `KeyValues` file. You can define different groups and a special section for bots.

### Example Structure

```
// Note: This is the root of the file. There is no single parent section.

"Human-gamers"
{
    "Guest"
    {
        "Flags"         ""
        "Team_T"
        {
            "health"        "100"
            "armor"         "0"
        }
        "Team_CT"
        {
            "health"        "100"
            "armor"         "0"
        }
    }

    "Admin_z"
    {
        "Flags"                 "z"
        "CanUseImmortality"     "1"
        "Team_T"
        {
            "health"        "120"
            "armor"         "100"
        }
        "Team_CT"
        {
            "health"        "120"
            "armor"         "100"
        }
    }
    // ... other groups for humans
}

"bots"
{
    "Team_T"
    {
        "health"        "90"
        "armor"         "50"
    }
    "Team_CT"
    {
        "health"        "90"
        "armor"         "50"
    }
}
```

### Key Explanations

*   **`Bots`**: A special section that applies only to bots (fake clients). It does not have `Flags` or `CanUseImmortality`.
*   **Group Name** (e.g., "Guest", "Admin_z"): A custom name for your group.
*   **`Flags`**: The set of admin flags a player must have to be in this group. An empty string `""` is for the default group (guests). The plugin will assign players to the group with the most matching flags.
*   **`CanUseImmortality`**: If set to `"1"`, players in this group can access the `RHA Settings` menu and will be affected by the global immortality mode.
*   **`Team_T` / `Team_CT`**: Sub-sections for Terrorist and Counter-Terrorist teams.
*   **`Health` / `Armor`**: The health and armor values to apply to players in that group and on that team.

## Known Issues

*   **Armor HUD Display Bug**: The default HUD in Counter-Strike: Source does not correctly display armor values above 100. For example, 200 armor might be displayed as "22", and 175 as "47". This is a purely visual engine bug. The plugin correctly assigns the armor value, and other plugins (like death info plugins) will see the correct value.

## Compilation

This plugin was last compiled with SourcePawn Compiler 1.11 or newer. The following dependencies are required:

*   `sourcemod.inc`
*   `sdktools.inc`
*   `sdkhooks.inc`
*   `cstrike.inc`
*   `keyvalues.inc`
*   `multicolors.inc`
*   `adminmenu.inc`
*   `topmenus.inc` (included by `adminmenu.inc`)

All required include files are provided in the `scripting` directory alongside the source code.

The original code was written using an older SourceMod API. The main compilation errors were due to:

1.  **Outdated `KeyValues` API**: The script was updated to use the modern `KeyValues` methodmap API (e.g., `JumpToKey` instead of `FindKey`, `new KeyValues()` instead of `CreateNewKey`).
2.  **Incorrect `TopMenu` Usage**: The method for adding an item to the admin menu was updated to use a `TopMenuHandler` as required by the `topmenus` API.
3.  **Incorrect `SDKHook` Signature**: The function signature for the `OnTakeDamage` hook was updated to match the modern `sdkhooks` API.

## Development Notes

A simplified plugin, `VIP_GOD.sp`, located in the `In Development/SourceMod/Legacy` directory, was used as a conceptual reference during development. It demonstrated a basic implementation of applying a status effect (invincibility) to a player based on certain conditions (VIP status). This served as an analogy for how this plugin applies custom health and armor values based on a player's admin flags.

**Armor Assignment Requirements:**
As a core requirement, the plugin must ensure that the correct armor value for a player's group is applied at the following times:
1.  When a player connects to the server (`OnPlayerSpawn`).
2.  At the start of every new round (`OnRoundStart`).

### Spawn Logic and Notifications

*   **Notification on Every Spawn**: To ensure the player is always aware of their status, the notification informing them of their group, health, and armor now appears on **every spawn**.
*   **Event Logic**:
    *   `OnPlayerSpawn`: This is the primary event for applying health/armor and displaying the notification.
    *   `OnRoundStart`: This event handler is intentionally left empty. Since `OnPlayerSpawn` reliably handles all players at the start of a round, any logic here would be redundant.
*   **Color Scheme**: The notification message uses a violet-blue base color (`{blueviolet}`) to be more distinct in the chat. The health and armor values retain their unique colors (`{darkgreen}` and `{brown}`) for readability.

---

## Русское описание

# Ruler Health & Armour (RHA)

Этот плагин позволяет администраторам сервера настраивать пользовательские значения здоровья и брони для игроков на основе их флагов администратора. Он также включает настраиваемые функции бессмертия и настройки для ботов.

## Установка

1.  Скопируйте `ruler_health_armour.smx` в каталог `addons/sourcemod/plugins/` вашего сервера.
2.  Конфигурационный файл будет автоматически создан по адресу `addons/sourcemod/configs/RHA.cfg` при первом запуске.

## Команды

Функции плагина управляются через меню администратора.

*   **`sm_admin`** -> **`Команды игрока`** -> **`Настройки RHA`**
    *   Это открывает главное меню плагина RHA. Доступ предоставляется администраторам, которые входят в группу с `"CanUseImmortality" "1"` в конфигурации.
    *   **Статус плагина: [Включен/Отключен]**: главный переключатель для включения или выключения всего плагина. При отключении все игроки будут иметь стандартное здоровье/броню.
    *   **Установить режим бессмертия**: открывает подменю для установки глобального режима бессмертия для всех подходящих администраторов.
        *   `0`: Отключено
        *   `1`: Неуязвимость (не получает урон)
    *   **Сбросить HP/броню игрока**: открывает меню для выбора любого игрока на сервере и сброса его здоровья и брони до 100.

## CVars (консольные переменные)

*   **`sm_rha_enabled`** (по умолчанию: 1)
    *   Главный переключатель для плагина. `1` = Вкл, `0` = Выкл.

*   **`sm_rha_admin_immortality_mode`** (по умолчанию: 0)
    *   Устанавливает глобальный режим бессмертия для подходящих администраторов (0: Отключено, 1: Неуязвимость). Можно изменить через меню администратора.

*   **`sm_rha_enable_logging`** (по умолчанию: 0)
    *   Включить/отключить ведение журнала для действий плагина RHA. `0` = Выкл, `1` = Вкл. Журналы сохраняются в `addons/sourcemod/logs/rha-YYYY-MM-DD.log`.

*   **`sm_rha_version`**
    *   Текущая версия плагина (только для чтения).

## Конфигурация (`addons/sourcemod/configs/RHA.cfg`)

Плагин настраивается с помощью файла `KeyValues`. Вы можете определить различные группы и специальный раздел для ботов.

### Пример структуры

```
// Примечание: это корень файла. Нет единого родительского раздела.

"Human-gamers"
{
    "Guest"
    {
        "Flags"         ""
        "Team_T"
        {
            "health"        "100"
            "armor"         "0"
        }
        "Team_CT"
        {
            "health"        "100"
            "armor"         "0"
        }
    }

    "Admin_z"
    {
        "Flags"                 "z"
        "CanUseImmortality"     "1"
        "Team_T"
        {
            "health"        "120"
            "armor"         "100"
        }
        "Team_CT"
        {
            "health"        "120"
            "armor"         "100"
        }
    }
    // ... другие группы для людей
}

"bots"
{
    "Team_T"
    {
        "health"        "90"
        "armor"         "50"
    }
    "Team_CT"
    {
        "health"        "90"
        "armor"         "50"
    }
}
```

### Пояснения к ключам

*   **`Bots`**: специальный раздел, который применяется только к ботам (поддельным клиентам). В нем нет `Flags` или `CanUseImmortality`.
*   **Имя группы** (например, "Guest", "Admin_z"): пользовательское имя для вашей группы.
*   **`Flags`**: набор флагов администратора, которые должен иметь игрок, чтобы состоять в этой группе. Пустая строка `""` предназначена для группы по умолчанию (гостей). Плагин назначит игроков в группу с наибольшим количеством совпадающих флагов.
*   **`CanUseImmortality`**: если установлено значение `"1"`, игроки в этой группе могут получить доступ к меню `Настройки RHA` и будут затронуты глобальным режимом бессмертия.
*   **`Team_T` / `Team_CT`**: подразделы для команд террористов и контртеррористов.
*   **`Health` / `Armor`**: значения здоровья и брони, которые будут применяться к игрокам в этой группе и в этой команде.

## Известные проблемы

*   **Баг отображения брони в HUD**: Стандартный HUD в Counter-Strike: Source некорректно отображает значения брони выше 100. Например, 200 единиц брони могут отображаться как "22", а 175 — как "47". Это чисто визуальный баг движка. Плагин при этом начисляет корректное количество брони, и другие плагины (например, информеры о смерти) будут видеть правильное значение.

## Компиляция

Этот плагин был в последний раз скомпилирован с помощью компилятора SourcePawn 1.11 или новее. Требуются следующие зависимости:

*   `sourcemod.inc`
*   `sdktools.inc`
*   `sdkhooks.inc`
*   `cstrike.inc`
*   `keyvalues.inc`
*   `multicolors.inc`
*   `adminmenu.inc`
*   `topmenus.inc` (входит в `adminmenu.inc`)

Все необходимые включаемые файлы предоставлены в каталоге `scripting` вместе с исходным кодом.

Исходный код был написан с использованием более старого API SourceMod. Основные ошибки компиляции были связаны с:

1.  **Устаревший API `KeyValues`**: сценарий был обновлен для использования современного API `KeyValues` methodmap (например, `JumpToKey` вместо `FindKey`, `new KeyValues()` вместо `CreateNewKey`).
2.  **Неправильное использование `TopMenu`**: метод добавления элемента в меню администратора был обновлен для использования `TopMenuHandler`, как того требует API `topmenus`.
3.  **Неправильная подпись `SDKHook`**: подпись функции для перехвата `OnTakeDamage` была обновлена в соответствии с современным API `sdkhooks`.

## Примечания по разработке

Упрощенный плагин `VIP_GOD.sp`, расположенный в каталоге `In Development/SourceMod/Legacy`, использовался в качестве концептуального справочника во время разработки. Он демонстрировал базовую реализацию применения эффекта состояния (неуязвимости) к игроку на основе определенных условий (статус VIP). Это послужило аналогом того, как этот плагин применяет пользовательские значения здоровья и брони на основе флагов администратора игрока.

**Требования к назначению брони:**
В качестве основного требования плагин должен гарантировать, что правильное значение брони для группы игрока применяется в следующих случаях:
1.  Когда игрок подключается к серверу (`OnPlayerSpawn`).
2.  В начале каждого нового раунда (`OnRoundStart`).

### Логика появления и уведомления

*   **Уведомление при каждом появлении**: чтобы игрок всегда был в курсе своего статуса, уведомление, информирующее его о его группе, здоровье и броне, теперь появляется при **каждом появлении**.
*   **Логика событий**:
    *   `OnPlayerSpawn`: это основное событие для применения здоровья/брони и отображения уведомления.
    *   `OnRoundStart`: этот обработчик событий намеренно оставлен пустым. Поскольку `OnPlayerSpawn` надежно обрабатывает всех игроков в начале раунда, любая логика здесь была бы избыточной.
*   **Цветовая схема**: в уведомлении используется базовый фиолетово-синий цвет (`{blueviolet}`), чтобы он был более заметен в чате. Значения здоровья и брони сохраняют свои уникальные цвета (`{darkgreen}` и `{brown}`) для удобства чтения.
