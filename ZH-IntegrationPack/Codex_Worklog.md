# Codex Worklog (ZH-IntegrationPack)
# Codex Worklog (ZH-IntegrationPack)
# Purpose: brief, dated notes of edits/analysis done in this pack. Keep concise to avoid bloat.

## 2025-12-03 (times local to host)
- [21:04] Added this timed entry as a reminder to keep using timestamps for changes; no code edits.

## 2025-12-04
- Added MST integration note (SoundManifest sync, PRD/RHA, loader, bots, web) and documented CS:S armor HUD >150 bug + need for SM/MM extension fix in `All_Docs.md`.
- Expanded `zh_mst.sp`: class/team parsing from MST-main-config.cfg, ability token parsing, auto-assign on join, downloads queues, team masks; added `zh_mst_autoassign`. Fixed `zh_modes.sp` arg parsing.
- Maintained no-compilation policy; pending items: apply models/arms on spawn, sample configs, centralized loader (ZH-Downloads), HUD armor fix extension.

## 2025-12-05 (times local to host)
- [22:38] Added explicit note to `All_Docs.md` about compile-time module pattern (funvotes-style) for integrating features like DragonBreath into core plugins.
- [22:42] Fixed `zh_sbc.sp` compile blockers: defined smoke radius, removed stray reload state, targeted cleanup of SBC smoke/light entities.
- [22:47] Added placeholder translations (`zh_deathinformer`, `zh_rha`, `zh_steamid`) to prevent missing phrase errors at runtime.
- [22:55] Folded DragonBreath into `zh_ammocontrol` via compile-time module include (`zh_ammocontrol/dragonbreath.sp`), stubbed `zh_dragonbullet.sp`, and aligned sample cfg cvars.
- [23:05] Made DragonBreath sound path configurable (`zh_dragonbreath_sound` cvar) to avoid hardcoded audio paths; precache/download uses the configured path.
- [23:10] Documented that DragonBreath ships only inside `zh_ammocontrol` (module), standalone reference belongs in `/Standalone/`; updated `All_Docs.md` and left stub in ZH-scripting to fail fast.
- [23:16] Stubbed remaining non-ZH standalone files in `Zh-sys/SourceMod/ZH-scripting` (AmmoControl_v2, DeathInformer, Dragon Breath Bullet, GravitySwitcher, ImmortalHostages_fixed, PRD, Rule_Health+Armor, ShowDamage_MultiColour, ShowMySteamID, SkinChooser-v55, SmokeBombCombo-V3.5, SoundManifest) to fail fast and point to `/Standalone/`; ZH-sys directory now contains only working ZH variants.
- [23:29] Removed legacy `zh_dragonbullet.sp` from ZH-scripting after migrating DragonBreath into `zh_ammocontrol`.
- [23:32] Deleted all remaining standalone stubs from `Zh-sys/SourceMod/ZH-scripting`; only zh_* plugins remain in that folder.
## 2025-12-03 (times local to host)
- [21:22] Added CSS-GH subfolder notes to `All_Docs.md` and appended CSS-GH note to `AGENTS.md` via binary-safe append; worklog updated. No code changes.
