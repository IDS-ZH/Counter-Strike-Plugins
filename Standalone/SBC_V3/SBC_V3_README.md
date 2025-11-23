# SmokeBomb Combo Plugin (Version 3.5)

This document provides an overview of the SmokeBomb Combo plugin, version 3.5.

## English

### Overview
The SmokeBomb Combo plugin (version 3.5) is designed to manage smoke grenades in Counter-Strike: Source, adding damage functionality and visual effects. This version includes improvements in stability, code readability, and new features.

### Key Changes and Improvements:
*   **Compilation Errors Fixed:** Syntax errors, such as a missing semicolon after `enum struct` and incorrect global variable declaration for `g_hLogQueue`, have been resolved.
*   **Improved Code Readability:** "Magic numbers" have been replaced with named constants (`LOG_TIMER_INTERVAL`, `RECOLOR_TIMER_INTERVAL`, `SMOKE_DAMAGE_RADIUS`, `SMOKE_LIFETIME`) for better understanding and easier maintenance.
*   **Added Sound Effects:** When taking damage from smoke, players now hear a random coughing sound, enhancing immersion in the gameplay.
*   **Timer Optimization:** While previous versions might have had inefficient timers, the current implementation uses timers per smoke grenade, which is a more manageable approach.
*   **Enhanced Resource Handling:** `ArrayList` and `DataPack` management has been reviewed to prevent potential memory leaks.

### CVars and Their Impact

*   `sm_sbc_enabled` (default: `1`): Enable/disable the plugin.
*   `sm_sbc_damage_enabled` (default: `1`): Enable smoke damage.
*   `sm_sbc_damage_amount` (default: `15`): Damage per tick.
*   `sm_sbc_damage_interval` (default: `1.0`): Damage interval (seconds).
*   `sm_sbc_teammate_damage` (default: `0`): Friendly fire (0/1), ignores `mp_friendlyfire` if 1.
*   `sm_sbc_color_t` (default: `255 0 0`): Smoke color for T (R G B).
*   `sm_sbc_color_ct` (default: `0 0 255`): Smoke color for CT (R G B).
*   `sm_sbc_colormode` (default: `0`): 0=team colors, 1=override.
*   `sm_sbc_override_color` (default: `0 0 0`): Override color (R G B).

*   **How it can "break"**: If `sm_sbc_teammate_damage` is set to `1`, smoke grenades will damage teammates, which can lead to chaos and accidental kills. This can be especially problematic on small maps.

---

## Русский

### Обзор
Плагин SmokeBomb Combo (версия 3.5) предназначен для управления дымовыми гранатами в Counter-Strike: Source, добавляя функциональность урона и визуальных эффектов. Эта версия включает улучшения стабильности, читаемости кода и новые возможности.

### Основные изменения и улучшения:
*   **Исправлены ошибки компиляции:** Устранены синтаксические ошибки, такие как отсутствующая точка с запятой после `enum struct` и некорректное объявление глобальной переменной `g_hLogQueue`.
*   **Улучшена читаемость кода:** "Магические числа" заменены на именованные константы (`LOG_TIMER_INTERVAL`, `RECOLOR_TIMER_INTERVAL`, `SMOKE_DAMAGE_RADIUS`, `SMOKE_LIFETIME`) для лучшего понимания и удобства поддержки.
*   **Добавлены звуковые эффекты:** При получении урона от дыма игроки теперь слышат случайный звук кашля, что повышает погружение в игровой процесс.
*   **Оптимизация таймеров:** Хотя в предыдущих версиях могли быть неэффективные таймеры, текущая реализация использует таймеры для каждой дымовой гранаты, что является более управляемым подходом.
*   **Улучшенная обработка ресурсов:** Управление `ArrayList` и `DataPack` было пересмотрено для предотвращения потенциальных утечек памяти.

### CVAR'ы и их влияние

*   `sm_sbc_enabled` (стандартное значение: `1`): Включить/выключить плагин.
*   `sm_sbc_damage_enabled` (стандартное значение: `1`): Включить урон дымом.
*   `sm_sbc_damage_amount` (стандартное значение: `15`): Урон за тик.
*   `sm_sbc_damage_interval` (стандартное значение: `1.0`): Интервал урона (сек).
*   `sm_sbc_teammate_damage` (стандартное значение: `0`): Урон по своим (0/1), игнорирует `mp_friendlyfire` при 1.
*   `sm_sbc_color_t` (стандартное значение: `255 0 0`): Цвет дыма для T (R G B).
*   `sm_sbc_color_ct` (стандартное значение: `0 0 255`): Цвет дыма для CT (R G B).
*   `sm_sbc_colormode` (стандартное значение: `0`): 0=командные цвета, 1=переопределение.
*   `sm_sbc_override_color` (стандартное значение: `0 0 0`): Цвет переопределения (R G B).

*   **Как может "сломать"**: Если `sm_sbc_teammate_damage` установлен в `1`, дымовые гранаты будут наносить урон товарищам по команде, что может привести к хаосу и случайным убийствам. Это может быть особенно проблематично на маленьких картах.