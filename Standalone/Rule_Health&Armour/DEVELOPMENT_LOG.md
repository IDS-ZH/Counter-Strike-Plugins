# Rule_Health&Armour Plugin Development Log

## 2025-11-09

### Initial Bug Report & Refactoring Request

**User reported issues:**
1.  Incorrect group assignment for players with flags 'b', 'e', 'be' (assigned to "guest"). Only 'z' flag worked.
2.  Desire to remove auto-creation of default config files (`RHA_humans.cfg`, `RHA_bots.cfg`).
3.  Request to switch from flag-based group assignment to **admin group-based assignment** (using `admin_groups.cfg` for group definitions).
4.  Reported translation issues (only English displayed).
5.  Reported armor display bug (values > 100-127 displayed incorrectly in HUD).
6.  Request to add German translation.
7.  Request to document changes and commit.

---

### Implemented Changes:

1.  **Removed Auto-Config Creation:**
    *   **File:** `Rule_Health+Armor.sp`
    *   **Change:** Removed the `if (!FileExists(path))` blocks in `LoadConfig()` that generated default `RHA_humans.cfg` and `RHA_bots.cfg`. Plugin now relies on existing config files.

2.  **Fixed Latent Flag Checking Logic (Deprecated by Group-Based System):**
    *   **File:** `Rule_Health+Armor.sp`
    *   **Change:** Modified `(playerFlags & flagsMask) != 0` to `(playerFlags & flagsMask) == flagsMask` in `GetClientGroupSettings`. This ensured players needed *all* flags for a group, not just *any*. (Note: This logic was later replaced by the group-based system).

3.  **Refactored to Group-Based Assignment:**
    *   **File:** `Rule_Health+Armor.sp`
    *   **Change:** Rewrote `GetClientGroupSettings()` to:
        *   Retrieve player's admin groups using `GetUserAdmin()` and `Admin_GetAdminGroup()`.
        *   Prioritize group assignment based on the highest immunity level defined in `admin_groups.cfg`.
        *   Search for matching group names as sections in `RHA_humans.cfg`.
        *   Implemented a fallback to a dedicated `"Default"` section in `RHA_humans.cfg` for players not matching any defined admin group.
    *   **File:** `RHA_humans.cfg`
    *   **Change:** Restructured the config file to use group names (e.g., "VIP", "Full Admins", "Default") as top-level keys instead of flag-based names (e.g., "Admin_z", "Admin_be"). Values were mapped from old config to new group names.

4.  **Improved Chat and Log Feedback:**
    *   **File:** `Rule_Health+Armor.sp`
    *   **Change:** Modified `ApplyHealthArmorToClient()` to include helmet status in both the chat message to the player and the server log.

5.  **Implemented Translation System:**
    *   **File:** `Rule_Health&Armour/sourcemod/translations/RHA.phrases` (renamed to `RHA.phrases.txt`)
    *   **Change:** Renamed the file to `RHA.phrases.txt` for standard compliance. Updated content to include helmet status (`%t` for "Yes"/"No") and added German (`de`) translations for all phrases.
    *   **File:** `Rule_Health+Armor.sp`
    *   **Change:** Added `LoadTranslations("common.phrases.txt");` and `LoadTranslations("RHA.phrases.txt");` to `OnPluginStart()`.
    *   **Change:** Modified `CPrintToChat()` in `ApplyHealthArmorToClient()` to use the `"RHA_GroupMessage"` translation key.

6.  **Experimental Armor Display Fix:**
    *   **File:** `Rule_Health+Armor.sp`
    *   **Change:** In `ApplyHealthArmorToClient()`, changed `SetEntProp(client, Prop_Data, "m_iHealth", health);` to `SetEntityHealth(client, health);`.
    *   **Change:** Reordered operations to set armor and helmet values *before* setting health. This is an attempt to force the client HUD to update correctly for high armor values. Explicitly set `m_bHasHelmet` to 0 if no helmet is given.

---

### Next Steps for User:

1.  **Compile** `Rule_Health+Armor.sp` to generate the new `.smx` plugin file.
2.  **Upload** the new `.smx` file, `RHA_humans.cfg`, and `RHA.phrases.txt` to the server.
3.  **Test** the plugin, paying close attention to group assignments, chat messages, and the armor display for values > 100.
4.  **Verify** that the `admins.cfg` on the server correctly assigns players to the desired admin groups (e.g., "VIP", "Full Admins").
