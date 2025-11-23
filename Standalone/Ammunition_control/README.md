# AmmoControl_v2 SourceMod Plugin

## English Description

This SourceMod plugin, `AmmoControl_v2`, provides enhanced ammunition management and custom reload mechanics for Counter-Strike: Source.

**Key Features:**

*   **Global Ammunition Limits:** Configurable CVARs (`sm_ammo_*_max`) to set maximum ammunition counts for various weapon types (e.g., AWP, P228, UMP45, Desert Eagle, M249, M4A1, AK47, Glock, USP, M3, XM1014, grenades).
*   **Magazine-Style Shotgun Reload:** Implements a custom magazine-style reload for `weapon_m3` and `weapon_xm1014` shotguns, replacing the default shell-by-shell reload.
*   **Configurable Shotgun Reload:**
    *   Enable/disable the custom reload for each shotgun (`sm_weapon_m3_magazine_reload`, `sm_weapon_xm1014_magazine_reload`).
    *   Set custom clip sizes (`sm_weapon_m3_clip`, `sm_weapon_xm1014_clip`).
    *   Adjust reload times (`sm_weapon_m3_reload_time`, `sm_weapon_xm1014_reload_time`).

**Known Issues / Bugs:**

*   **Engine Quirk & Reload Bug:** The M3 and XM1014 shotguns have a hardcoded default ammo capacity (8 and 7 rounds, respectively) within the game engine. If you set `sm_weapon_m3_clip` or `sm_weapon_xm1014_clip` to a value different from this default, a reload bug can occur. After the initial magazine-style reload completes, pressing the reload key again may cause the shotgun to start reloading its entire reserve ammunition. This is due to underlying "crutches" in the game's logic, and it is impractical to fix without advanced modding (e.g., using DHooks).

---

## Русское описание

Этот плагин SourceMod, `AmmoControl_v2`, предоставляет расширенное управление боеприпасами и пользовательскую механику перезарядки для Counter-Strike: Source.

**Основные возможности:**

*   **Глобальные лимиты боеприпасов:** Настраиваемые CVAR'ы (`sm_ammo_*_max`) для установки максимального количества боеприпасов для различных типов оружия (например, AWP, P228, UMP45, Desert Eagle, M249, M4A1, AK47, Glock, USP, M3, XM1014, гранаты).
*   **Перезарядка дробовика в стиле магазина:** Реализует пользовательскую перезарядку в стиле магазина для дробовиков `weapon_m3` и `weapon_xm1014`, заменяя стандартную перезарядку по одному патрону.
*   **Настраиваемая перезарядка дробовика:**
    *   Включение/отключение пользовательской перезарядки для каждого дробовика (`sm_weapon_m3_magazine_reload`, `sm_weapon_xm1014_magazine_reload`).
    *   Установка пользовательских размеров магазина (`sm_weapon_m3_clip`, `sm_weapon_xm1014_clip`).
    *   Настройка времени перезарядки (`sm_weapon_m3_reload_time`, `sm_weapon_xm1014_reload_time`).

**Известные проблемы / Баги:**

*   **Особенность движка и баг с перезарядкой:** У дробовиков M3 и XM1014 в коде игры "зашит" стандартный боезапас в 8 и 7 патронов соответственно. Если в `sm_weapon_m3_clip` или `sm_weapon_xm1014_clip` выставить значение, отличающееся от стандартного, может возникнуть сбой. После "магазинной" перезарядки до указанного в плагине количества патронов, если снова нажать на перезарядку, дробовик может начать дозаряжать в себя весь остальной боезапас. Это связано с "костылями" в логике самой игры, и бороться с этим без серьезного вмешательства в движок (например, через DHooks) практически бесполезно.