ImmortalHostages (fixed)
=========================

This package contains a safe, reviewed SourceMod plugin to control hostage damage behavior.

Modes (set with `sm_hostages_setmode <mode>`):
- 0 = normal (hostages take damage normally)
- 1 = vulnerable_to_T (only Terrorists can damage hostages)
- 2 = vulnerable_to_CT (only Counter-Terrorists can damage hostages)
- 3 = invulnerable (hostages take no damage from any source)

Installation:
1) Copy `addons/sourcemod/plugins/ImmortalHostages_fixed.smx` to your server's `cstrike/addons/sourcemod/plugins/`.
2) Put `cfg/sourcemod/immortal_hostages.cfg` into `cstrike/cfg/sourcemod/`.
3) Restart server or load plugin via `sm plugins load ImmortalHostages_fixed`.

Admin commands:
- `sm_hostages_setmode <0-3>` — set mode (requires admin rights).
- `sm_hostages_debug <0/1>` — enable debug logging.

Notes:
- The plugin uses SDKHooks and SourceMod; ensure your server has compatible versions.
- Test on a staging server before production.

Files in this package:
- `scripting/ImmortalHostages_fixed.sp` — source
- `addons/sourcemod/plugins/ImmortalHostages_fixed.smx` — compiled binary
- `addons/sourcemod/plugins/ImmortalHostages_fixed_compilation_Journal.txt` — compilation log
- `cfg/sourcemod/immortal_hostages.cfg` — example config

License: adapt as you prefer. Suggested: MIT/ISC.

---

## Русское описание

Этот пакет содержит безопасный, проверенный плагин SourceMod для управления поведением урона по заложникам.

Режимы (устанавливаются с помощью `sm_hostages_setmode <режим>`):
- 0 = normal (заложники получают урон как обычно)
- 1 = vulnerable_to_T (только террористы могут наносить урон заложникам)
- 2 = vulnerable_to_CT (только контр-террористы могут наносить урон заложникам)
- 3 = invulnerable (заложники не получают урон ни от какого источника)

Установка:
1) Скопируйте `addons/sourcemod/plugins/ImmortalHostages_fixed.smx` в `cstrike/addons/sourcemod/plugins/` вашего сервера.
2) Поместите `cfg/sourcemod/immortal_hostages.cfg` в `cstrike/cfg/sourcemod/`.
3) Перезапустите сервер или загрузите плагин через `sm plugins load ImmortalHostages_fixed`.

Админ-команды:
- `sm_hostages_setmode <0-3>` — установить режим (требуются права администратора).
- `sm_hostages_debug <0/1>` — включить отладочное логирование.

Примечания:
- Плагин использует SDKHooks и SourceMod; убедитесь, что на вашем сервере установлены совместимые версии.
- Протестируйте на промежуточном сервере перед использованием в производственной среде.

Файлы в этом пакете:
- `scripting/ImmortalHostages_fixed.sp` — исходный код
- `addons/sourcemod/plugins/ImmortalHostages_fixed.smx` — скомпилированный бинарный файл
- `addons/sourcemod/plugins/ImmortalHostages_fixed_compilation_Journal.txt` — журнал компиляции
- `cfg/sourcemod/immortal_hostages.cfg` — пример конфигурации

Лицензия: адаптируйте по своему усмотрению. Предлагается: MIT/ISC.