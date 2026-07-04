#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <keyvalues>
#include <multicolors>
#include <adminmenu>
#include <adt_trie>

#define PLUGIN_VERSION "1.1"

ConVar g_hCvarEnabled;
ConVar g_hCvarImmortalityMode;
ConVar g_hCvarEnableLogging;

KeyValues g_kvHumans;
KeyValues g_kvBots;

TopMenu g_hAdminMenu;

bool g_bImmortalityAdmins[MAXPLAYERS + 1];

StringMap g_smPermissions;

public Plugin myinfo = 
{
    name = "Rule_Health&Armor",
    author = "ZloyHohol",
    description = "Sets health and armor based on admin flags.",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    g_hCvarEnabled = CreateConVar("sm_rha_enabled", "1", "Enable/Disable the Rule_Health&Armor plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarImmortalityMode = CreateConVar("sm_rha_admin_immortality_mode", "0", "Global immortality mode for eligible admins (0: Disabled, 1: Invincible).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarEnableLogging = CreateConVar("sm_rha_enable_logging", "0", "Enable/Disable logging for the RHA plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    CreateConVar("sm_rha_version", PLUGIN_VERSION, "Rule_Health&Armor plugin version.", FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_DONTRECORD);

    g_smPermissions = new StringMap();

    LoadTranslations("common.phrases.txt");
    LoadTranslations("RHA.phrases.txt");

    LoadConfig();

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        }
    }

    RegConsoleCmd("sm_rha", Command_RHA, "RHA admin menu");
    RegConsoleCmd("rha", Command_RHA, "RHA admin menu");
    RegAdminCmd("sm_rha_reload", Command_RHAReload, ADMFLAG_ROOT, "Reload RHA configs");
}

public void OnPluginEnd()
{
    if (g_kvHumans != null)
    {
        delete g_kvHumans;
    }
    if (g_kvBots != null)
    {
        delete g_kvBots;
    }
    if (g_smPermissions != null)
    {
        delete g_smPermissions;
    }
}

public void OnAllPluginsLoaded()
{
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && (topmenu = GetAdminTopMenu()) != null)
    {
        OnAdminMenuReady(view_as<Handle>(topmenu));
    }
}

public void OnAdminMenuReady(Handle topmenu)
{
    TopMenu hMenu = view_as<TopMenu>(topmenu);
    if (hMenu == g_hAdminMenu) return;
    g_hAdminMenu = hMenu;

    TopMenuObject category = hMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
    if (category != INVALID_TOPMENUOBJECT)
    {
        hMenu.AddItem(
            "sm_rha",
            AdminMenu_RHAMenu,
            category,
            "sm_rha",
            ADMFLAG_ROOT
        );
    }
}

public void AdminMenu_RHAMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        strcopy(buffer, maxlength, "RHA Settings");
    }
    else if (action == TopMenuAction_SelectOption)
    {
        BuildRHAMenu(param);
    }
}

void BuildRHAMenu(int client)
{
    Menu menu = new Menu(RHAMenuHandler);
    menu.SetTitle("RHA Settings\n ");
    
    char buffer[128];

    if (HasAccessToSetting(client, "sm_rha_enabled"))
    {
        Format(buffer, sizeof(buffer), "Plugin Status: %s", g_hCvarEnabled.BoolValue ? "Enabled" : "Disabled");
        menu.AddItem("sm_rha_enabled", buffer);
    }
    else
    {
        Format(buffer, sizeof(buffer), "Plugin Status: [No Access]");
        menu.AddItem("sm_rha_enabled", buffer, ITEMDRAW_DISABLED);
    }

    if (HasAccessToSetting(client, "sm_rha_admin_immortality_mode"))
    {
        Format(buffer, sizeof(buffer), "Immortality Mode: %s", g_hCvarImmortalityMode.BoolValue ? "Invincible" : "Disabled");
        menu.AddItem("sm_rha_admin_immortality_mode", buffer);
    }
    else
    {
        Format(buffer, sizeof(buffer), "Immortality Mode: [No Access]");
        menu.AddItem("sm_rha_admin_immortality_mode", buffer, ITEMDRAW_DISABLED);
    }

    if (HasAccessToSetting(client, "sm_rha_enable_logging"))
    {
        Format(buffer, sizeof(buffer), "Logging: %s", g_hCvarEnableLogging.BoolValue ? "Enabled" : "Disabled");
        menu.AddItem("sm_rha_enable_logging", buffer);
    }
    else
    {
        Format(buffer, sizeof(buffer), "Logging: [No Access]");
        menu.AddItem("sm_rha_enable_logging", buffer, ITEMDRAW_DISABLED);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

bool HasAccessToSetting(int client, const char[] settingName)
{
    char allowRuler[256];
    if (g_smPermissions.GetString(settingName, allowRuler, sizeof(allowRuler)))
    {
        if (allowRuler[0] == '\0') return false; 
    }
    else
    {
        AdminId admin = GetUserAdmin(client);
        if (admin != INVALID_ADMIN_ID && GetAdminFlag(admin, Admin_Root)) return true;
        return false;
    }

    AdminId admin = GetUserAdmin(client);
    if (admin != INVALID_ADMIN_ID && GetAdminFlag(admin, Admin_Root)) return true;

    char auth[64];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

    char parts[16][64];
    int count = ExplodeString(allowRuler, " ", parts, sizeof(parts), sizeof(parts[]));
    for (int i = 0; i < count; i++)
    {
        if (parts[i][0] == '\0') continue;
        if (StrEqual(parts[i], auth, false)) return true;

        if (admin != INVALID_ADMIN_ID)
        {
            int groupCount = GetAdminGroupCount(admin);
            char groupName[64];
            for (int g = 0; g < groupCount; g++)
            {
                admin.GetGroup(g, groupName, sizeof(groupName));
                if (StrEqual(groupName, parts[i], false)) return true;
            }
        }
    }
    return false;
}

public int RHAMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "sm_rha_enabled"))
        {
            g_hCvarEnabled.BoolValue = !g_hCvarEnabled.BoolValue;
            RHA_LogAction(param1, -1, "Toggled RHA plugin %s", g_hCvarEnabled.BoolValue ? "On" : "Off");
        }
        else if (StrEqual(info, "sm_rha_admin_immortality_mode"))
        {
            g_hCvarImmortalityMode.BoolValue = !g_hCvarImmortalityMode.BoolValue;
            RHA_LogAction(param1, -1, "Toggled RHA immortality %s", g_hCvarImmortalityMode.BoolValue ? "On" : "Off");
        }
        else if (StrEqual(info, "sm_rha_enable_logging"))
        {
            g_hCvarEnableLogging.BoolValue = !g_hCvarEnableLogging.BoolValue;
            RHA_LogAction(param1, -1, "Toggled RHA logging %s", g_hCvarEnableLogging.BoolValue ? "On" : "Off");
        }

        BuildRHAMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_RHA(int client, int args)
{
    if (client > 0 && IsClientInGame(client))
    {
        BuildRHAMenu(client);
    }
    return Plugin_Handled;
}

public Action Command_RHAReload(int client, int args)
{
    LoadConfig();
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "[RHA] Configs reloaded successfully.");
    }
    else
    {
        PrintToServer("[RHA] Configs reloaded successfully.");
    }
    return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Empty
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hCvarEnabled.BoolValue) return;

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) return;

    CreateTimer(0.5, Timer_ApplySettings, userid);
}

public Action Timer_ApplySettings(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
    {
        ApplyHealthArmorToClient(client, false);
    }
    return Plugin_Stop;
}

void LoadConfig()
{
    // --- Load Settings Config (Allow_ruler & default cvars) ---
    char settings_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, settings_path, sizeof(settings_path), "configs/RHA_settings.cfg");
    g_smPermissions.Clear();
    
    KeyValues kvSettings = new KeyValues("RuleHealthArmor");
    if (kvSettings.ImportFromFile(settings_path))
    {
        if (kvSettings.GotoFirstSubKey())
        {
            do
            {
                char keyName[64];
                kvSettings.GetSectionName(keyName, sizeof(keyName));

                char valStr[64];
                kvSettings.GetString("value", valStr, sizeof(valStr));

                ConVar cv = FindConVar(keyName);
                if (cv != null)
                {
                    cv.SetString(valStr);
                }

                char allowRuler[256];
                kvSettings.GetString("Allow_ruler", allowRuler, sizeof(allowRuler));
                g_smPermissions.SetString(keyName, allowRuler);

            } while (kvSettings.GotoNextKey());
        }
    }
    else
    {
        LogError("[RHA] Failed to load %s. Proceeding without Allow_ruler limits.", settings_path);
    }
    delete kvSettings;

    // --- Load Humans Config ---
    char human_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, human_path, sizeof(human_path), "configs/RHA_humans.cfg");

    if (g_kvHumans != null) delete g_kvHumans;
    g_kvHumans = new KeyValues("Groups");

    if (!g_kvHumans.ImportFromFile(human_path))
    {
        LogError("[RHA] Failed to load or parse config file: %s. Check for syntax errors.", human_path);
    }

    // --- Load Bots Config ---
    char bot_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, bot_path, sizeof(bot_path), "configs/RHA_bots.cfg");

    if (g_kvBots != null) delete g_kvBots;
    g_kvBots = new KeyValues("Bots");

    if (!g_kvBots.ImportFromFile(bot_path))
    {
        LogError("[RHA] Failed to load or parse config file: %s. Check for syntax errors.", bot_path);
    }
}

KeyValues GetClientGroupSettings(int client, bool isBot)
{
    if (isBot)
    {
        g_kvBots.Rewind();
        KeyValues kvBot = new KeyValues("Bots");
        KvCopySubkeys(g_kvBots, kvBot);
        return kvBot;
    }

    g_kvHumans.Rewind();
    
    KeyValues kvBestGroup = null;
    int bestImmunity = -1;
    char bestGroupName[64];
    bestGroupName[0] = '\0';

    AdminId adminId = GetUserAdmin(client);
    StringMap userGroups = null;

    if (adminId != INVALID_ADMIN_ID)
    {
        userGroups = new StringMap();
        char groupName[64];
        int groupCount = GetAdminGroupCount(adminId);
        for (int i = 0; i < groupCount; i++)
        {
            adminId.GetGroup(i, groupName, sizeof(groupName));
            userGroups.SetString(groupName, "1");
        }
    }

    if (g_kvHumans.GotoFirstSubKey())
    {
        do
        {
            char configGroupName[64];
            g_kvHumans.GetSectionName(configGroupName, sizeof(configGroupName));

            if (StrEqual(configGroupName, "Default"))
            {
                continue;
            }

            bool userIsInThisGroup = false;
            if (userGroups != null && userGroups.ContainsKey(configGroupName))
            {
                userIsInThisGroup = true;
            }
            
            if (userIsInThisGroup)
            {
                GroupId groupId = FindAdmGroup(configGroupName);
                if (groupId != INVALID_GROUP_ID)
                {
                    int immunity = GetAdmGroupImmunityLevel(groupId);
                    if (immunity > bestImmunity)
                    {
                        bestImmunity = immunity;
                        strcopy(bestGroupName, sizeof(bestGroupName), configGroupName);
                    }
                }
            }
        } while (g_kvHumans.GotoNextKey());
    }

    if (userGroups != null)
    {
        delete userGroups;
    }

    if (bestImmunity > -1 && bestGroupName[0] != '\0')
    {
        g_kvHumans.Rewind();
        if (g_kvHumans.JumpToKey(bestGroupName))
        {
            kvBestGroup = new KeyValues(bestGroupName);
            KvCopySubkeys(g_kvHumans, kvBestGroup);
        }
    }

    if (kvBestGroup == null)
    {
        g_kvHumans.Rewind();
        if (g_kvHumans.JumpToKey("Default"))
        {
            kvBestGroup = new KeyValues("Default");
            KvCopySubkeys(g_kvHumans, kvBestGroup);
        }
    }
    
    return kvBestGroup;
}

void ApplyHealthArmorToClient(int client, bool silent)
{
    bool isBot = IsFakeClient(client);
    KeyValues kvGroup = GetClientGroupSettings(client, isBot);

    if (kvGroup == null) return;

    char groupName[64];
    kvGroup.GetSectionName(groupName, sizeof(groupName));

    int team = GetClientTeam(client);
    char sTeam[16];
    if (team == CS_TEAM_T) strcopy(sTeam, sizeof(sTeam), "Team_T");
    else if (team == CS_TEAM_CT) strcopy(sTeam, sizeof(sTeam), "Team_CT");
    else 
    {
        delete kvGroup;
        return;
    }

    g_bImmortalityAdmins[client] = kvGroup.GetNum("CanUseImmortality", 0) == 1;

    if (kvGroup.JumpToKey(sTeam))
    {
        int health = kvGroup.GetNum("health", 100);
        int armor = kvGroup.GetNum("armor", 0);
        int helmet = kvGroup.GetNum("Helmet", 0);

        // Set Armor and Helmet first
        SetEntProp(client, Prop_Send, "m_ArmorValue", armor);
        if (armor > 0 && helmet == 1)
        {
            SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
        } else {
            SetEntProp(client, Prop_Send, "m_bHasHelmet", 0); // Ensure helmet is removed if not given
        }

        // Then set Health using the dedicated function
        SetEntityHealth(client, health);

        if (g_hCvarEnableLogging.BoolValue)
        {
            char clientName[MAX_NAME_LENGTH];
            GetClientName(client, clientName, sizeof(clientName));
            RHA_LogAction(-1, client, "Applied settings to \"%s\" (group: %s, health: %d, armor: %d, helmet: %d)", clientName, groupName, health, armor, helmet);
        }

        if (!silent)
        {
            CPrintToChat(client, "%t", "RHA_GroupMessage", groupName, health, armor, (helmet == 1) ? "Yes" : "No");
        }
    }

    delete kvGroup;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (g_hCvarEnabled.BoolValue && g_hCvarImmortalityMode.BoolValue && g_bImmortalityAdmins[victim])
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void RHA_LogAction(int client, int target, const char[] format, any ...)
{
    if (!g_hCvarEnableLogging.BoolValue) return;

    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 4);

    char clientName[MAX_NAME_LENGTH];
    if (client > 0)
    {
        GetClientName(client, clientName, sizeof(clientName));
    }
    else
    {
        Format(clientName, sizeof(clientName), "Console");
    }

    if (target > 0)
    {
        char targetName[MAX_NAME_LENGTH];
        GetClientName(target, targetName, sizeof(targetName));
        LogMessage("[%s] %s -> %s", clientName, buffer, targetName);
    }
    else
    {
        LogMessage("[%s] %s", clientName, buffer);
    }
}
