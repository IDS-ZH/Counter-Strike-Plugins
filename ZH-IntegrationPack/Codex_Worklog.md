# Codex Worklog (ZH-IntegrationPack)
# Codex Worklog (ZH-IntegrationPack)
# Purpose: brief, dated notes of edits/analysis done in this pack. Keep concise to avoid bloat. Times are 24-hour, local to host.

## 2025-12-03 (times local to host)
- [21:04] Added this timed entry as a reminder to keep using timestamps for changes; no code edits.

## 2025-12-04
- Added MST integration note (SoundManifest sync, PRD/RHA, loader, bots, web) and documented CS:S armor HUD >150 bug + need for SM/MM extension fix in All_Docs.md.
- Expanded zh_mst.sp: class/team parsing from MST-main-config.cfg, ability token parsing, auto-assign on join, downloads queues, team masks; added zh_mst_autoassign. Fixed zh_modes.sp arg parsing.
- Maintained no-compilation policy; pending items: apply models/arms on spawn, sample configs, centralized loader (ZH-Downloads), HUD armor fix extension.

## 2025-12-05 (times local to host)
- [22:38] Added explicit note to All_Docs.md about compile-time module pattern (funvotes-style) for integrating features like DragonBreath into core plugins.
- [22:42] Fixed zh_sbc.sp compile blockers: defined smoke radius, removed stray reload state, targeted cleanup of SBC smoke/light entities.
- [22:47] Added placeholder translations (zh_deathinformer, zh_rha, zh_steamid) to prevent missing phrase errors at runtime.
- [22:55] Folded DragonBreath into zh_ammocontrol via compile-time module include (zh_ammocontrol/dragonbreath.sp), stubbed zh_dragonbullet.sp, and aligned sample cfg cvars.
- [23:05] Made DragonBreath sound path configurable (zh_dragonbreath_sound cvar) to avoid hardcoded audio paths; precache/download uses the configured path.
- [23:10] Documented that DragonBreath ships only inside zh_ammocontrol (module); standalone reference belongs in /Standalone/; updated All_Docs.md and left stub in ZH-scripting to fail fast.
- [23:16] Stubbed remaining non-ZH standalone files in Zh-sys/SourceMod/ZH-scripting (AmmoControl_v2, DeathInformer, Dragon Breath Bullet, GravitySwitcher, ImmortalHostages_fixed, PRD, Rule_Health+Armor, ShowDamage_MultiColour, ShowMySteamID, SkinChooser-v55, SmokeBombCombo-V3.5, SoundManifest) to fail fast and point to /Standalone/; ZH-sys directory now contains only working ZH variants.
- [23:29] Removed legacy zh_dragonbullet.sp from ZH-scripting after migrating DragonBreath into zh_ammocontrol.
- [23:32] Deleted all remaining standalone stubs from Zh-sys/SourceMod/ZH-scripting; only zh_* plugins remain in that folder.
- [23:40] Merged New Metamod+Sourcemod into Zh-sys/addons/sourcemod and Zh-sys/cfg; moved ZH-sys includes/scripts/translations into the same addons tree. Zh-sys/SourceMod now empty, unified view of all SP/inc/phrases under Zh-sys/addons/sourcemod/.
- [01:31] Adjusted All_Docs.md paths to new unified structure (ddons/sourcemod/{configs,translations,scripting} for ZH modules).
- [02:29] Added ZH_abilities plan to All_Docs.md (revive/second life modules under ddons/sourcemod/scripting/ZH_abilities/, trap/turret/robot class ideas, config path guidance).
- [02:36] Expanded ZH_abilities ideas with invisibility, parachute (fall damage mitigation), hitgroup armor, and legacy sources (KillStats/revival/lasermines/VIP/zb) noted in All_Docs.md.
- [02:45] Added explicit conflict notes for standard SM stack in All_Docs.md (mapchooser/rockthevote/nominations/nextmap, admin-flatfile vs admin-sql, reservedslots/antiflood/chat formatters) with guidance to pick one stack and align with zh_core.

## 2025-12-06
- [04:35] Audited HUD fonts in Textures/fixed_64-bit_hud/fixed 64-bit HUD/resource/ClientScheme.res: confirmed all Hemi references removed, Cornerita-VF/pixel registered as custom font files; ChatFont still uses Verdana (Cyrillic-safe). Captured font metrics with fontTools (Cornerita-VF/pixel support Cyrillic, Hemi lacks it) and noted color defaults (Orange/DodgerBlue) for chat/HUD.
- [04:55] Switched ChatFont to Cornerita-VF across resolutions and set chat typing color to DodgerBlue to match HUD blue; cleaned up temp font script.
- [05:10] Found legacy VIP assassination mode source (Legacy/CSS Modern War on Terror Mods Integration Package/cstrike/addons/sourcemod/scripting/VIPMod.sp) and documented porting plan into All_Docs.md (move to zh_modes/zh_vip.sp, wrap with zh_core/modes, no hardcoded resources, config path under ddons/sourcemod/configs/ZH-sys/MST/Modes/).
- [05:20] Added VIP escape modifiers plan to All_Docs.md (count 1 vs 2+, hardcore fail-on-any-death, bot-only vs any CT vs players-only vs whitelist-by-group/SteamID; all options to ddons/sourcemod/configs/ZH-sys/MST/Modes/zh_vip.cfg).
- [05:30] Clarified canonical CS 1.6 VIP rules in All_Docs.md (200 armor, no buys, limited pickups, drop-all config note) and scanned Legacy for supporting plugins: found shield implementations (Legacy/CSS Modern War on Terror Mods.../New_Shield.sp, bot shield helper) but no drop-all weapon plugin yet (only DropBombDefuse.sp seen).
- [05:38] Added note in All_Docs.md that DropBombDefuse.sp can serve as optional zh_c4 modifier (global or admin/web toggle via chat-menu).
- [05:45] Recorded arrival of Legacy/Every Version of Equipment Drop/ (CS:GO-heavy, needs cleanup for CS:S) as potential drop-all base in All_Docs.md.
- [05:52] Documented goal for equipment-drop module: allow G to drop any item (even usually undroppable) and drop all carried gear on death, beyond default primary+secondary+one grenade/defuse.
- [06:05] Compared tripmine sources: noted Legacy/tripmines v.4.0/tripmines.sp (multi-game, needs TF2 cleanup, good base for standalone traps) vs ZR lasermines (lasermines_155, ZombieReloaded/ZR/lasermines*.sp tied to ZR). Added guidance to All_Docs.md.
- [06:12] Added sapper/demolition ability notes: bind/key for mine placement, optional slot 4 integration, class-only access with larger stacks for sapper, config path configs/ZH-sys/Abilities/sapper_mines.cfg in All_Docs.md.
- [06:20] Clarified slot vs buy-menu note for mines in All_Docs.md: slot 4 equip (not buy menu), warned about price-display mismatch (
esource/ui/*.res/cstrike_*.txt) and referenced custom _buymenu example for full UI edits.
- [06:30] Logged large Legacy bundles in All_Docs.md as references for heavy resource/weapon patching (ZombieReloaded packs, CSS Modern War on Terror, Gustav Recoilless Cannon).
- [06:40] Added MySQL map-familiarity idea to All_Docs.md (per-player map buckets NEW/novice/aware/expert/master/tracker, REST/API for web panel + mapvote personalization with family grouping).
- [07:48] Created Zh-sys/{resource,scripts} and copied fixed HUD package (ClientScheme/fonts + HudLayout/HudAnimations) for deployment; noted HUD path in All_Docs.md.
- [08:07] Recorded clarified ZH-sys layout in All_Docs.md: root mirrors cstrike (addons, cfg, resource, scripts, materials/models/sound as added), HUD lives in 
esource/scripts.
- [08:25] Audited logic-only ZH plugins (no custom resources): zh_core/zh_modes/zh_mst/zh_rha/zh_c4/zh_bots/zh_hostages/zh_gravity/zh_deathinformer/zh_showdamage/zh_steamid/zh_webbridge/zh_zones/zh_sbc/zh_ammocontrol (dragonbreath uses cvar sound path). No 
esource/scripts/materials changes needed; depend on configs/ZH-sys/... and standard assets. Next: tune default configs and tie into zh_modes/MST.
- [08:55] Noted in All_Docs.md: use Standalone SkinChooser 5.5 CS-Source as base, restore arms/thirdperson features from legacy sm_skinchooser 5.3, add !mst menu entry "Виды обзора" (1st/3rd/3rd static 	hirdperson_mayamode) with MST-side config.
- [21:11] Created skeleton config tree under ddons/sourcemod/configs/ZH-sys/ for logic-only plugins (C4, Bots, Hostages, Gravity, DeathInformer, ShowDamage, SteamID, WebBridge, Zones, SBC, RHA humans/bots) with placeholder cfgs and README for per-map zones.

- [21:25] Filled skeleton configs under addons/sourcemod/configs/ZH-sys/ for logic plugins (C4, Bots, Hostages, Gravity, DeathInformer, ShowDamage, SteamID, WebBridge, Zones README, SBC, RHA humans/bots) with baseline settings.

- [21:45] Added bot customization plan to All_Docs.md: difficulty spread slider (0 flat, 3 full 0-3), class-based skill tweaks (fast/accurate vs heavy -15..20%), WeaponPreference linked to MST classes/model groups, thematic names (IDF/spec-ops), using default_skins.ini groupings as reference.

- [21:52] Updated bot model grouping reference in All_Docs.md to SRCDS-current-modded-catalog/addons/sourcemod/configs/sm_skinchooser/default_skins.ini (source of team groupings for MST/bots).

- [22:05] Expanded zh_bots.cfg with difficulty spread, sniper ratio, class skill multipliers, mode-role enforcement to match bot plan in All_Docs.md.

- [22:18] Ported sm_skinchooser grouping into MST format: added configs/ZH-sys/MST/Player-settings/Generic/Generic_Player-skins.cfg with Team_T/CT groups (CS:GO sets + extras) based on SRCDS-current-modded-catalog default_skins.ini; copied download list to configs/ZH-sys/MST/Downloads/skins_downloads.txt.

- [22:28] Clarified in All_Docs.md: skins_downloads.txt now under configs/ZH-sys/MST/Downloads/ and should be handled by ZH-sys loader (MST/Downloads or ZH-Downloads), not legacy skinchooser.

- [22:36] Clarified downloads: skins_downloads.txt under configs/ZH-sys/MST/Downloads is just a list; a unified ZH-sys loader (master with slave includes) handles FastDL, replacing legacy skinchooser logic.

- [22:50] Added unified downloads prototype: master config configs/ZH-sys/Downloads/zh_downloads.cfg (FastDL URL/limits, include lists) plus placeholders for Abilities and Modes lists; documented in All_Docs.md.

- [23:05] Annotated zh_downloads.cfg to note no .bz2 usage by default (plain files mirroring server); bz2 optional if someone prepares/uploads separately.

- [23:25] Reorganized ZH-sys configs: created new folders (ZH-Downloader, ZH-Bot_preferences, Special_items/C4, GUI/{Death_Informer,Show_Damage,SteamID}) and updated paths in All_Docs.md. Old folders remain due to access-denied; content copied to new structure; needs manual deletion if permissions allow.

- [23:40] Removed legacy empty config folders (Bots, C4, DeathInformer, ShowDamage, SteamID, Downloads) after reorganizing to new structure.

- [04:30] Restructured configs into categories: Modifiers/ (MST, RHA, Hostages, Gravity, SBC, Special_items/C4) and Tools/ (GUI, WebBridge, ZH-Downloader, ZH-Bot_preferences, Zones); removed old top-level folders.

- [04:50] Moved Zones configs under Modifiers (mods affect base gameplay), per guidance; Tools now contains GUI/WebBridge/ZH-Downloader/ZH-Bot_preferences only.

- [04:55] Moved GUI configs to top-level configs/ZH-sys/GUI/ (out of Tools), per instruction.

- [05:05] Updated zh_downloads.cfg include paths to new Tools/ZH-Downloader/Abilities and Modes lists.

## 2025-12-09
- [05:27] Synced All_Docs.md with new Modifiers/Model_Switch_Tool config paths (hands/downloads/modes), updated VIP cfg location, and logged legacy grenade sources (AntiTeamFlash, COD_life quick grenades, ZR napalm, New_Weapons_NoBot projectiles, ZR grenade limits) for Modifiers/Weapons/Grenades after an rg sweep of Legacy.

## 2025-12-21
- Audited `ZH-IntegrationPack/Zh-sys` build health: ensured all `zh_*.sp` compile cleanly on SM 1.13 `spcomp`.
- Fixed compile blockers across ZH modules (include-guards, SourcePawn syntax, KeyValues API usage, enum typing) and added missing vendor includes (`multicolors`, `easy_hudmessage`, `system2`, `json`) under `Zh-sys/addons/sourcemod/scripting/include/`.
- Updated docs to match the canonical deploy-tree and config roots (`Zh-sys` + `configs/ZH-sys/{Core,GUI,Modifiers,Tools}`); corrected a few stale `configs/ZH/...` references.

## 2025-12-24
- Copied `Default_game_dir/cstrike/cfg/config.cfg` into `Zh-sys/cfg/config.cfg` and added `MOUSE3` bind for ammo-type cycling.
- Added HUD/ammo icon research notes and canonical paths to All_Docs.md (mod_textures/clientscheme/640hud1/csd.ttf).
- Confirmed ammo icon sources: `mod_textures.txt` (`ammo_*`), `CSTypeDeath`->`csd.ttf`, and `materials/sprites/640hud1`.
- Expanded All_Docs.md to document the exact chain `weapon_*.txt` -> `TextureData` -> `mod_textures.txt` and the split between sprite-based vs glyph-based ammo icons.
- Audited non-`zh_*` SourceMod plugin sources under `Zh-sys/addons/sourcemod/scripting` for backdoor patterns; only expected admin/menu command execution (`sm_rcon`, `exec`, dynamic menu commands) and normal file I/O (mapchooser/admin files) found, no network/download code in sources.
- Disabled `sm_rcon` registration in `basecommands.sp` and added mapcycle path fallback logic to `nextmap.sp` + `mapchooser.sp` (cfg/mapcycle.txt -> ZH-sys Tools/MapCycle).
- Updated All_Docs.md with ZH-sys mapcycle priority + DB-backed rotation directive.
- Created `configs/ZH-sys/Tools/MapCycle/` and seeded `zh_mapcycle.cfg` + `adminmenu_maplist.cfg` from default mapcycle; updated maplists.cfg and basecommands map list path to ZH-sys.
- [23:29] Normalized HUD/mapcycle doc punctuation to ASCII and added prefix-based mapcycle pooling directive to All_Docs.md.
- [23:38] Added mapcycle fallback checks to `nominations.sp` and `randomcycle.sp`, and aligned `nextmap.sp`/`mapchooser.sp` to prefer `cfg/mapcycle.txt` when default or missing while honoring explicit custom paths.
- [23:49] Added `zh_mapcycle_pools.cfg` + `zh_mapcycle_pool` support in `nextmap.sp`, `mapchooser.sp`, `nominations.sp`, `randomcycle.sp` to select mapcycle pools; documented the pool config path in All_Docs.md.
- [01:07] Generated mapcycle pool files from `CUSTOM/Custom_Maps/maps` (prefix groups >=3; others to misc), and rewrote `zh_mapcycle_pools.cfg` to include aim/as/awp/cs/de/dm/fy/gg + misc.
- [01:10] Merged `Default_game_dir/cstrike/cfg/mapcycle.txt` into pool lists; regenerated mapcycle_*.cfg (cs/de counts grew) and refreshed `zh_mapcycle_pools.cfg`.
- [20:16] Restored missing block separator for Legacy classifier in All_Docs.md (split inline separator into its own line).
- [21:07] Prefixed numbered level-2 headings in All_Docs.md with block names and renumbered within each block to eliminate duplicate section numbers.

## 2026-06-30
- Cleaned up Git repository: restored corrupted 3rd party translations and added MetaMod-Sources to .gitignore (except sm-ext-websocket) to remove 600+ phantom changes.
- Implemented 'Allow_ruler' access control system for Standalone plugins: `Immortal Hostages`, `Gravity Switcher`, and `Rule_Health&Armour`. Admins can now specify precise access via configs (SteamIDs and group names).
- Bumped `Rule_Health&Armour` version to 1.1 and added RHA_settings.cfg for CVARs and Allow_ruler limits.
