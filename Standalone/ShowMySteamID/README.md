# Show My SteamID Plugin

## English

### Overview
This SourceMod plugin allows players to retrieve their SteamID by typing a command in chat.

### Planned Features:
-   **Chat Commands:** Players can use `!mysteamid`, `/mysteamid`, `!steamid`, or `/steamid` in chat.
-   **Private Message:** The SteamID is displayed only to the requesting player.
-   **Localization:** Support for multiple languages (Russian and English).
-   **Colored Output:** Messages are displayed with color coding for better readability.
-   **Compatibility:** Compiled for both 32-bit (`spcomp.exe`) and 64-bit (`spcomp64.exe`) server architectures.

### Current Status:
-   The plugin is compiled and available in `plugins/x32/ShowMySteamID.smx` and `plugins/x64/ShowMySteamID.smx`.
-   The core functionality of displaying the SteamID to the player is implemented.
-   Initial attempts to use `AddCommandListener` for chat commands were problematic; reverted to `RegConsoleCmd` which is the standard way for SourceMod to handle chat commands with `!` and `/` prefixes.
-   Initial attempts to use the translation system (`LoadTranslations`) and `%t` in `PrintToChat` seemed to cause issues, leading to a simplified version with hardcoded Russian text for debugging purposes.
-   Compatibility with 32-bit SRCDS servers was addressed by providing both 32-bit and 64-bit compiled versions.

### What Didn't Work / Debugging Notes:
-   **`RegChatCommand`:** This function does not exist in SourceMod. Chat commands are handled by `RegConsoleCmd` and SourceMod's internal chat processing.
-   **`AddCommandListener` for chat commands:** While `AddCommandListener` is a valid function, using it to parse chat commands manually proved to be less reliable than `RegConsoleCmd` for standard chat command prefixes (`!` and `/`).
-   **Localization (`LoadTranslations` and `%t`):** There were issues when using the translation system, leading to no output. This was temporarily removed for debugging. Further investigation is needed to ensure proper loading and usage of translation files.
-   **Compatibility with 32-bit SRCDS:** Compiling with `spcomp64.exe` for a 32-bit SRCDS server caused the plugin not to load. Providing both 32-bit and 64-bit compiled versions resolves this.

## Русский

### Обзор
Этот плагин для SourceMod позволяет игрокам получить свой SteamID, введя команду в чате.

### Запланированные функции:
-   **Команды чата:** Игроки могут использовать `!mysteamid`, `/mysteamid`, `!steamid` или `/steamid` в чате.
-   **Личное сообщение:** SteamID отображается только запросившему игроку.
-   **Локализация:** Поддержка нескольких языков (русский и английский).
-   **Цветной вывод:** Сообщения отображаются с цветовой кодировкой для лучшей читаемости.
-   **Совместимость:** Скомпилирован для 32-битной (`spcomp.exe`) и 64-битной (`spcomp64.exe`) архитектур сервера.

### Текущий статус:
-   Плагин скомпилирован и доступен в `plugins/x32/ShowMySteamID.smx` и `plugins/x64/ShowMySteamID.smx`.
-   Основная функциональность отображения SteamID игроку реализована.
-   Первоначальные попытки использовать `AddCommandListener` для команд чата были проблематичными; вернулись к `RegConsoleCmd`, который является стандартным способом обработки команд чата с префиксами `!` и `/` в SourceMod.
-   Первоначальные попытки использовать систему переводов (`LoadTranslations`) и `%t` в `PrintToChat` приводили к отсутствию вывода. Это было временно удалено для отладки, с использованием жестко закодированного русского текста.
-   Проблема совместимости с 32-битными серверами SRCDS была решена путем предоставления как 32-битных, так и 64-битных скомпилированных версий.

### Что не сработало / Заметки по отладке:
-   **`RegChatCommand`:** Эта функция не существует в SourceMod. Команды чата обрабатываются `RegConsoleCmd` и внутренней обработкой чата SourceMod.
-   **`AddCommandListener` для команд чата:** Хотя `AddCommandListener` является допустимой функцией, использование ее для ручного парсинга команд чата оказалось менее надежным, чем `RegConsoleCmd` для стандартных префиксов команд чата (`!` и `/`).
-   **Локализация (`LoadTranslations` и `%t`):** Возникали проблемы при использовании системы переводов, что приводило к отсутствию вывода. Это было временно удалено для отладки. Требуется дальнейшее исследование для обеспечения правильной загрузки и использования файлов перевода.
-   **Совместимость с 32-битными SRCDS:** Компиляция с `spcomp64.exe` для 32-битного сервера SRCDS приводила к тому, что плагин не загружался. Предоставление как 32-битных, так и 64-битных скомпилированных версий решает эту проблему.
