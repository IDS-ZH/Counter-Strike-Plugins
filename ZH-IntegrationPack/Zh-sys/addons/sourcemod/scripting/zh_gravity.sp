#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <menus>
#include <zh_core>

#define PLUGIN_VERSION "1.5.0-zh-sys"

// --- Глобальные переменные для хранения состояния ---
bool g_bLowGravEnabled = false;
float g_fGravityMultiplier = 0.5;

// --- Переменные для ConVar (для сохранения настроек) ---
ConVar g_hCvarEnabled;
ConVar g_hCvarMultiplier;

public Plugin myinfo = {
    name = "ZH-sys Gravity Switcher",
    author = "ZloyHohol & Gemini",
    description = "Меняет гравитацию в игре без SV_CHEATS 1 in ZH-sys architecture",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart() {
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    g_hCvarEnabled = CreateConVar("zh_gravity_enabled", "0", "Включен ли режим низкой гравитации (сохраняется).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarMultiplier = CreateConVar("zh_gravity_multiplier", "0.5", "Множитель гравитации (сохраняется).", FCVAR_NOTIFY, true, 0.1, true, 2.0);

    g_bLowGravEnabled = g_hCvarEnabled.BoolValue;
    g_fGravityMultiplier = g_hCvarMultiplier.FloatValue;

    RegConsoleCmd("sm_gravity", Command_GravityMenu, "Меню администратора гравитации");
    RegConsoleCmd("gravity", Command_GravityMenu, "Меню администратора гравитации");

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    AutoExecConfig(true, "zh_gravity", "sourcemod");

    if (g_bLowGravEnabled) {
        SetAllGravity(g_fGravityMultiplier);
    }

    LogMessage("[ZH-Gravity] Плагин загружен. Версия %s", PLUGIN_VERSION);

    // Register this module with ZH Core
    ZH_RegisterModule("gravity");
}

public void OnConfigsExecuted()
{
    g_bLowGravEnabled = g_hCvarEnabled.BoolValue;
    g_fGravityMultiplier = g_hCvarMultiplier.FloatValue;

    if (g_bLowGravEnabled) {
        SetAllGravity(g_fGravityMultiplier);
    } else {
        SetAllGravity(1.0);
    }
}

public Action Command_GravityMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;
	if (!CheckCommandAccess(client, "sm_gravity_admin", ADMFLAG_CONFIG, true))
	{
		ReplyToCommand(client, "У вас нет прав для использования этой команды.");
		return Plugin_Handled;
	}
	DisplayGravityMenu(client);
	return Plugin_Handled;
}

void DisplayGravityMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Gravity);
	menu.SetTitle("Меню гравитации");
	menu.ExitButton = true;

	char status[64];
	Format(status, sizeof(status), "Низкая гравитация: %s", g_bLowGravEnabled ? "Включена" : "Выключена");
	menu.AddItem("toggle_lowgrav", status);

	menu.AddItem("set_multiplier", "Установить множитель гравитации");

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
            g_hCvarEnabled.SetBool(g_bLowGravEnabled);

			ReplyToCommand(param1, "Низкая гравитация %s.", g_bLowGravEnabled ? "включена" : "выключена");

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
	menu.SetTitle("Множитель (текущий: %.2f)", g_fGravityMultiplier);
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
        g_hCvarMultiplier.SetFloat(g_fGravityMultiplier);

        // --- ИСПРАВЛЕННАЯ ЛОГИКА ---
        // Если режим низкой гравитации был выключен, включаем его
        if (!g_bLowGravEnabled)
        {
            g_bLowGravEnabled = true;
            g_hCvarEnabled.SetBool(true);
        }

        // Немедленно применяем новую гравитацию
        SetAllGravity(g_fGravityMultiplier);

		ReplyToCommand(param1, "Гравитация установлена на %.2f и включена.", g_fGravityMultiplier);

        // Возвращаемся в главное меню
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
    if (g_bLowGravEnabled && IsClientInGame(client) && IsPlayerAlive(client)) {
        CreateTimer(0.1, Timer_SetGrav, GetClientUserId(client));
    }
}

public Action Timer_SetGrav(Handle timer, int userid) {
    int client = GetClientOfUserId(userid);
    if (IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntityGravity(client, g_fGravityMultiplier);
    }
    return Plugin_Stop;
}

void SetAllGravity(float grav) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            SetEntityGravity(i, grav);
        }
    }
}
