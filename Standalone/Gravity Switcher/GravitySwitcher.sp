#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <menus>

#define PLUGIN_VERSION "2.0"

public Plugin myinfo = {
    name = "Gravity Switcher (Access Control)",
    author = "ZloyHohol & Gemini",
    description = "Меняет гравитацию в игре без SV_CHEATS 1 (с KV-доступами)",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// --- Глобальные переменные для хранения состояния ---
bool g_bLowGravEnabled = false;
float g_fGravityMultiplier = 0.5;

StringMap g_smPermissions;

// --- Переменные для ConVar ---
ConVar g_hCvarEnabled;
ConVar g_hCvarMultiplier;

public void OnPluginStart() {
    g_smPermissions = new StringMap();

    g_hCvarEnabled = CreateConVar("sm_gravity_enabled", "0", "Включен ли режим низкой гравитации", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarMultiplier = CreateConVar("sm_gravity_multiplier", "0.5", "Множитель гравитации", FCVAR_NOTIFY, true, 0.1, true, 2.0);

    RegConsoleCmd("sm_gravity", Command_GravityMenu, "Меню гравитации");
    RegConsoleCmd("gravity", Command_GravityMenu, "Меню гравитации");
    RegAdminCmd("sm_gravity_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Перезагрузить конфиг Gravity Switcher");
    
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    
    LoadConfig();
    
    PrintToServer("[GravitySwitcher] Плагин загружен. Версия %s", PLUGIN_VERSION);
}

void LoadConfig()
{
    g_smPermissions.Clear();
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/GravitySwitcher.cfg");

    KeyValues kv = new KeyValues("GravitySwitcher");
    if (!kv.ImportFromFile(path))
    {
        LogError("[GravitySwitcher] Cannot load configs/GravitySwitcher.cfg");
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

    g_bLowGravEnabled = g_hCvarEnabled.BoolValue;
    g_fGravityMultiplier = g_hCvarMultiplier.FloatValue;

    if (g_bLowGravEnabled) {
        SetAllGravity(g_fGravityMultiplier);
    } else {
        SetAllGravity(1.0);
    }

    PrintToServer("[GravitySwitcher] Конфиг и доступы успешно загружены.");
}

public Action Command_ReloadConfig(int client, int args)
{
    LoadConfig();
    if (client > 0 && IsClientInGame(client))
        PrintToChat(client, "\x04[GravitySwitcher]\x01 Конфиг перезагружен.");
    return Plugin_Handled;
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

public Action Command_GravityMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;
    DisplayGravityMenu(client);
    return Plugin_Handled;
}

void DisplayGravityMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Gravity);
    menu.SetTitle("Меню гравитации\n ");
    menu.ExitButton = true;

    char status[128];

    if (HasAccessToSetting(client, "sm_gravity_enabled"))
    {
        Format(status, sizeof(status), "Низкая гравитация: %s", g_bLowGravEnabled ? "Включена" : "Выключена");
        menu.AddItem("toggle_lowgrav", status);
    }
    else
    {
        Format(status, sizeof(status), "Низкая гравитация: [Нет доступа]");
        menu.AddItem("toggle_lowgrav", status, ITEMDRAW_DISABLED);
    }

    if (HasAccessToSetting(client, "sm_gravity_multiplier"))
    {
        menu.AddItem("set_multiplier", "Установить множитель гравитации");
    }
    else
    {
        menu.AddItem("set_multiplier", "Установить множитель [Нет доступа]", ITEMDRAW_DISABLED);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Gravity(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[64];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "toggle_lowgrav"))
        {
            g_bLowGravEnabled = !g_bLowGravEnabled;
            g_hCvarEnabled.BoolValue = g_bLowGravEnabled;

            PrintToChat(param1, "\x04[GravitySwitcher]\x01 Низкая гравитация %s.", g_bLowGravEnabled ? "включена" : "выключена");

            if (g_bLowGravEnabled)
            {
                SetAllGravity(g_fGravityMultiplier);
            }
            else
            {
                SetAllGravity(1.0);
            }
            DisplayGravityMenu(param1);
        }
        else if (StrEqual(info, "set_multiplier"))
        {
            DisplayMultiplierSubMenu(param1);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void DisplayMultiplierSubMenu(int client)
{
    Menu menu = new Menu(MenuHandler_GravityMultiplier);
    menu.SetTitle("Множитель (текущий: %.2f)\n ", g_fGravityMultiplier);
    menu.ExitButton = true;

    menu.AddItem("1.0", "Нормальная (1.0)");
    menu.AddItem("0.75", "Пониженная (0.75)");
    menu.AddItem("0.5", "Половинная (0.5)");
    menu.AddItem("0.25", "Четверть (0.25)");
    menu.AddItem("1.5", "Полуторная (1.5)");
    menu.AddItem("2.0", "Двойная (2.0)");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_GravityMultiplier(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[64];
        menu.GetItem(param2, info, sizeof(info));

        float newMultiplier = StringToFloat(info);
        
        g_fGravityMultiplier = newMultiplier;
        g_hCvarMultiplier.FloatValue = g_fGravityMultiplier;
        
        if (!g_bLowGravEnabled)
        {
            g_bLowGravEnabled = true;
            g_hCvarEnabled.BoolValue = true;
        }

        SetAllGravity(g_fGravityMultiplier);

        PrintToChat(param1, "\x04[GravitySwitcher]\x01 Гравитация установлена на %.2f и включена.", g_fGravityMultiplier);

        DisplayGravityMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_bLowGravEnabled && client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        CreateTimer(0.1, Timer_SetGrav, GetClientUserId(client));
    }
}

public Action Timer_SetGrav(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntityGravity(client, g_fGravityMultiplier);
    }
    return Plugin_Stop;
}

stock void SetAllGravity(float grav) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            SetEntityGravity(i, grav);
        }
    }
}