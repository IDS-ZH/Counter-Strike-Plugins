#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <menus>

ArrayList g_hHostages;
ConVar g_hCvarMode;
ConVar g_hCvarDebug;
StringMap g_smPermissions;

public Plugin myinfo = 
{
    name = "ImmortalHostages (with Access Control)",
    author = "By Copilot / ZloyHohol & Gemini",
    description = "Safe hostages damage control with selectable modes & KV access",
    version = "0.3",
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    g_smPermissions = new StringMap();
    g_hHostages = new ArrayList();
    g_hCvarMode = CreateConVar("sm_hostages_mode", "3", "Hostage damage mode: 0=normal, 1=vuln_T, 2=vuln_CT, 3=invulnerable", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    g_hCvarDebug = CreateConVar("sm_hostages_debug", "0", "Enable debug prints (0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    RegConsoleCmd("sm_hostages", Command_HostagesMenu, "Меню настроек заложников");
    RegAdminCmd("sm_hostages_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Перезагрузить конфиг ImmortalHostages");

    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    ScanAndHookHostages();
    CreateTimer(5.0, Timer_RescanHostages, _, TIMER_REPEAT);

    LoadConfig();
    
    PrintToServer("[ImmortalHostages] Loaded. Mode: %d", g_hCvarMode.IntValue);
}

void LoadConfig()
{
    g_smPermissions.Clear();
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/ImmortalHostages.cfg");

    KeyValues kv = new KeyValues("ImmortalHostages");
    if (!kv.ImportFromFile(path))
    {
        LogError("[ImmortalHostages] Cannot load configs/ImmortalHostages.cfg");
        delete kv;
        return;
    }

    if (kv.GotoFirstSubKey())
    {
        do
        {
            char keyName[64];
            kv.GetSectionName(keyName, sizeof(keyName));

            char valStr[64];
            kv.GetString("value", valStr, sizeof(valStr));

            ConVar cv = FindConVar(keyName);
            if (cv != null)
            {
                cv.SetString(valStr);
            }

            char allowRuler[256];
            kv.GetString("Allow_ruler", allowRuler, sizeof(allowRuler));
            g_smPermissions.SetString(keyName, allowRuler);

        } while (kv.GotoNextKey());
    }

    delete kv;
    PrintToServer("[ImmortalHostages] Конфиг и доступы успешно загружены.");
}

public Action Command_ReloadConfig(int client, int args)
{
    LoadConfig();
    if (client > 0 && IsClientInGame(client))
        ReplyToCommand(client, "\x04[ImmortalHostages]\x01 Конфиг перезагружен.");
    return Plugin_Handled;
}

bool HasAccessToSetting(int client, const char[] settingName)
{
    if (GetAdminFlag(GetUserAdmin(client), Admin_Root)) return true;

    char allowRuler[256];
    if (g_smPermissions.GetString(settingName, allowRuler, sizeof(allowRuler)))
    {
        if (allowRuler[0] == '\0') return false; 
        
        char auth[64];
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

        char parts[16][64];
        int count = ExplodeString(allowRuler, " ", parts, sizeof(parts), sizeof(parts[]));
        for (int i = 0; i < count; i++)
        {
            if (parts[i][0] == '\0') continue;
            if (StrEqual(parts[i], auth, false)) return true;

            AdminId admin = GetUserAdmin(client);
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
    }
    return false;
}

public Action Command_HostagesMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;
    DisplayHostagesMenu(client);
    return Plugin_Handled;
}

void DisplayHostagesMenu(int client)
{
    if (!HasAccessToSetting(client, "sm_hostages_mode"))
    {
        PrintToChat(client, "\x02[ImmortalHostages]\x01 У вас нет прав для изменения режима заложников.");
        return;
    }

    Menu menu = new Menu(MenuHandler_HostagesMode);
    int curMode = g_hCvarMode.IntValue;
    menu.SetTitle("Режим бессмертия заложников\nТекущий режим: %d\n ", curMode);
    menu.ExitButton = true;

    menu.AddItem("0", "Нормальный (получают урон)");
    menu.AddItem("1", "Уязвимы только для T");
    menu.AddItem("2", "Уязвимы только для CT");
    menu.AddItem("3", "Бессмертны (invulnerable)");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_HostagesMode(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        int mode = StringToInt(info);

        g_hCvarMode.IntValue = mode;
        
        char modeStr[64];
        switch(mode) {
            case 0: strcopy(modeStr, sizeof(modeStr), "Нормальный");
            case 1: strcopy(modeStr, sizeof(modeStr), "Уязвимы для Т");
            case 2: strcopy(modeStr, sizeof(modeStr), "Уязвимы для СТ");
            case 3: strcopy(modeStr, sizeof(modeStr), "Бессмертны");
        }
        
        PrintToChat(param1, "\x04[ImmortalHostages]\x01 Режим заложников установлен: %s", modeStr);
        ScanAndHookHostages();
        DisplayHostagesMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public void OnMapEnd()
{
    UnhookAllHostages();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ScanAndHookHostages();
    return Plugin_Continue;
}

stock void ScanAndHookHostages()
{
    UnhookAllHostages();
    int maxEnts = GetMaxEntities();
    for (int ent = 1; ent <= maxEnts; ent++)
    {
        if (!IsValidEdict(ent)) continue;
        char cname[64];
        GetEdictClassname(ent, cname, sizeof(cname));
        if (!StrEqual(cname, "hostage_entity")) continue;

        SDKHook(ent, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        g_hHostages.Push(ent);
        if (g_hCvarDebug.BoolValue) PrintToServer("[ImmortalHostages] Hooked hostage ent %d", ent);
    }
}

public Action Timer_RescanHostages(Handle timer, any data)
{
    ScanAndHookHostages();
    return Plugin_Continue;
}

stock void UnhookAllHostages()
{
    if (g_hHostages == null) g_hHostages = new ArrayList();
    int size = g_hHostages.Length;
    for (int i = 0; i < size; i++)
    {
        int ent = g_hHostages.Get(i);
        if (IsValidEdict(ent))
        {
            SDKUnhook(ent, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
            if (g_hCvarDebug.BoolValue) PrintToServer("[ImmortalHostages] Unhooked hostage ent %d", ent);
        }
    }
    g_hHostages.Clear();
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsValidEdict(victim)) return Plugin_Continue;

    char cname[64];
    GetEdictClassname(victim, cname, sizeof(cname));
    if (!StrEqual(cname, "hostage_entity")) return Plugin_Continue;

    int mode = g_hCvarMode.IntValue;

    if (mode == 0) return Plugin_Continue;

    if (mode == 3)
    {
        damage = 0.0;
        return Plugin_Handled;
    }

    bool attackerIsPlayer = false;
    int client = -1;
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
    {
        attackerIsPlayer = true;
        client = attacker;
    }

    if (mode == 1)
    {
        if (attackerIsPlayer && GetClientTeam(client) == 2) return Plugin_Continue;
        damage = 0.0;
        return Plugin_Handled;
    }

    if (mode == 2)
    {
        if (attackerIsPlayer && GetClientTeam(client) == 3) return Plugin_Continue;
        damage = 0.0;
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void OnPluginEnd()
{
    UnhookAllHostages();
}
