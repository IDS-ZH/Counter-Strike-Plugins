# Counter-Strike-Plugins

Сборка плагинов/модов для CS:S с двумя основными сценариями:
- **ZH-IntegrationPack**: интеграционный набор с ZH-sys (ядро/классы/режимы), веб-панелью (MaterialAdmin в xampp) и свежими сборками MetaMod+SourceMod.
- **Standalone**: отдельные плагины/моды без плотной интеграции (оставлены как есть).

Все разрозненные .md сведены в `ZH-IntegrationPack/All_Docs.md`. Исходные .md убраны (есть копии у владельца).

## Структура (уровни до 7)
- `ZH-IntegrationPack/`
  - `All_Docs.md` — объединённая документация (архитектура, классификатор Legacy, планы).
  - `New Metamod+Sourcemod/` — свежие бинарники MM/SM (git 1374/7280) + configs (добавлена секция DB `materialadmin`).
  - `Zh-sys/`
    - `SourceMod/` — исходники ZH-системы: `zh_core`, `zh_mst`, `zh_modes`, `zh_bots`, `zh_c4`, `zh_hostages`, `zh_zones`, `zh_webbridge`, и пр.; `include/` с общими .inc; `ZH-translations/`.
    - `MetaMod/sm-ext-websocket/` — исходники C++ расширения WebSocket/HTTP (AMB/VS сборка).
  - `xampp/htdocs/` — веб-панель MaterialAdmin (`materialadmin/`) + MOTD (`motd-CS_Source.html`); пример DB `data/database.php` (materialadmin/ma_user/ma_pass).
  - `СПИСКИ/` — вспомогательные списки/ТЗ.
- `Standalone/` — отдельные плагины (не интегрированы).
- `Sourcemod-1.13-CUSTOMized/` — предыдущая кастомная сборка SM с include/ext (использовать точечно при необходимости).

## ZH-sys в двух словах
- `zh_core`: общие нативы/логирование/путь к конфигам.
- `zh_mst`: классы/модели/способности, загрузчик ресурсов, хуки для режимов.
- `zh_modes`: переключатели DM/TDM/GG/Chicken/Revive (админ, голосования и web-хуки — в планах).
- `zh_bots`: базовые утилиты (override bot_difficulty, классы MST, фонарик/маяк — черновик).
- `zh_c4`, `zh_hostages`, `zh_zones`: черновики управления бомбой/заложниками/зонами.
- `zh_webbridge`: REST (system2) + опционально WebSocket (sm-ext-websocket) для связи с панелью.

## Веб-панель
- Файлы: `xampp/htdocs/materialadmin/` (копия Legacy/Web).
- Настройки БД: `ZH-IntegrationPack/New Metamod+Sourcemod/addons/sourcemod/configs/databases.cfg` (секция `materialadmin`) и `xampp/htdocs/materialadmin/data/database.php` (dsn/user/pass/prefix).
- Расширения для realtime: sm-ext-websocket (исходники в Zh-sys/MetaMod), можно собрать через Visual Studio/AMB.

## Дополнительные ресурсы

-   **CSS-GH:** Каталог `CSS-GH` содержит полезные 2 версии сборок исходного хоть и старого кода CSS из GitHub (народные порты), что предоставляет ценные ресурсы для понимания и разработки плагинов.

## Собрать/запуск (черновики)
- Компиляция .sp пока не запускалась. Используйте spcomp из `New Metamod+Sourcemod`.
- Для веба: задать реальные креды MySQL, развернуть XAMPP, проверить материалadmin.
- Для C++ ext: собрать sm-ext-websocket, подключить к `New Metamod+Sourcemod`.

Дополнительно см. `ZH-IntegrationPack/РефакторMD.txt` (памятка по объединённым .md). Перемещайтесь с осторожностью: многие исходники Legacy требуют портирования под SM 1.13. Ҭ
