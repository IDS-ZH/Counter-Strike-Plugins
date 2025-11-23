# Dragon Breath Bullet for Shotguns (M3+XM1014)

This is a rewritten version of the Dragon Breath Bullet plugin for Counter-Strike: Source. It adds a fire-breathing effect to the M3 and XM1014 shotguns.

## English Description

This plugin makes the M3 and XM1014 shotguns fire "dragon's breath" rounds, which create a small fire effect on impact that can ignite players.

### CVars and Their Impact

*   `sm_dragonguns_enable` (default: `1`): Enable/disable the plugin.
*   `sm_dragonguns_guns` (default: `xm1014 m3`): Which weapons shoot fire (space-separated).
*   `sm_dragonguns_damage` (default: `5.0`): Fire damage on touch, per second (0.0 = no damage).
*   `sm_dragonguns_ignite_time` (default: `4.0`): Time in seconds for a player to be ignited.
*   `sm_dragonguns_playsound` (default: `1`): Enable/disable the sound when a player is ignited.

*   **How it can "break"**: If you specify a weapon in `sm_dragonguns_guns` that is not a shotgun, it can lead to unexpected behavior. For example, with an automatic weapon, every shot will create a fire effect, which can cause severe server lag and visual chaos.

---

## Русское описание

Этот плагин заставляет дробовики M3 и XM1014 стрелять патронами "дыхание дракона", которые создают небольшой огненный эффект при попадании, способный поджечь игроков.

### CVAR'ы и их влияние

*   `sm_dragonguns_enable` (стандартное значение: `1`): Включить/выключить плагин.
*   `sm_dragonguns_guns` (стандартное значение: `xm1014 m3`): Какие оружия стреляют огнем (разделенные пробелами).
*   `sm_dragonguns_damage` (стандартное значение: `5.0`): Урон от огня при касании, в секунду (0.0 = нет урона).
*   `sm_dragonguns_ignite_time` (стандартное значение: `4.0`): Время в секундах, на которое поджигается игрок.
*   `sm_dragonguns_playsound` (стандартное значение: `1`): Включить/выключить звук при поджоге игрока.

*   **Как может "сломать"**: Если в `sm_dragonguns_guns` указать оружие, не являющееся дробовиком, это может привести к неожиданному поведению. Например, у автоматического оружия каждый выстрел будет создавать огненный эффект, что может вызвать сильные лаги на сервере и визуальный хаос.
