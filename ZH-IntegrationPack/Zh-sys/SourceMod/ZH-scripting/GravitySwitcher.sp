#include <sourcemod>
#include <menus>

#define PLUGIN_VERSION "1.4"

public Plugin:myinfo = {
    name = "Gravity Switcher",
    author = "ZloyHohol & Gemini",
    description = "Меняет гравитацию в игре без SV_CHEATS 1",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// --- Глобальные переменные для хранения состояния ---
new bool:g_bLowGravEnabled = false;
new Float:g_fGravityMultiplier = 0.5;

// --- Переменные для ConVar (для сохранения настроек) ---
new Handle:g_hCvarEnabled;
new Handle:g_hCvarMultiplier;

public OnPluginStart() {
    g_hCvarEnabled = CreateConVar("sm_gravity_enabled", "0", "Включен ли режим низкой гравитации (сохраняется).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarMultiplier = CreateConVar("sm_gravity_multiplier", "0.5", "Множитель гравитации (сохраняется).", FCVAR_NOTIFY, true, 0.1, true, 2.0);

    g_bLowGravEnabled = GetConVarBool(g_hCvarEnabled);
    g_fGravityMultiplier = GetConVarFloat(g_hCvarMultiplier);

    RegConsoleCmd("sm_gravity", Command_GravityMenu, "Меню администратора гравитации");
    RegConsoleCmd("gravity", Command_GravityMenu, "Меню администратора гравитации");
    
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    
    AutoExecConfig(true, "GravitySwitcher"); 

    if (g_bLowGravEnabled) {
        SetAllGravity(g_fGravityMultiplier);
    }
    
    PrintToServer("[GravitySwitcher] Плагин загружен. Версия %s", PLUGIN_VERSION);
}

public OnConfigsExecuted()
{
    g_bLowGravEnabled = GetConVarBool(g_hCvarEnabled);
    g_fGravityMultiplier = GetConVarFloat(g_hCvarMultiplier);

    if (g_bLowGravEnabled) {
        SetAllGravity(g_fGravityMultiplier);
    } else {
        SetAllGravity(1.0);
    }
}

public Action:Command_GravityMenu(client, args)
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

DisplayGravityMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Gravity);
	SetMenuTitle(menu, "Меню гравитации");	
	SetMenuExitButton(menu, true);

	decl String:status[64];
	Format(status, sizeof(status), "Низкая гравитация: %s", g_bLowGravEnabled ? "Включена" : "Выключена");
	AddMenuItem(menu, "toggle_lowgrav", status);

	AddMenuItem(menu, "set_multiplier", "Установить множитель гравитации");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Gravity(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));

		if (StrEqual(info, "toggle_lowgrav"))
		{
			g_bLowGravEnabled = !g_bLowGravEnabled;
            SetConVarBool(g_hCvarEnabled, g_bLowGravEnabled);

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
		CloseHandle(menu);
	}
}

DisplayMultiplierSubMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_GravityMultiplier);
	SetMenuTitle(menu, "Множитель (текущий: %.2f)", g_fGravityMultiplier);
	SetMenuExitButton(menu, true);

	AddMenuItem(menu, "1.0", "Нормальная (1.0)");
	AddMenuItem(menu, "0.75", "Пониженная (0.75)");
	AddMenuItem(menu, "0.5", "Половинная (0.5)");
	AddMenuItem(menu, "0.25", "Четверть (0.25)");
	AddMenuItem(menu, "1.5", "Полуторная (1.5)");
	AddMenuItem(menu, "2.0", "Двойная (2.0)");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_GravityMultiplier(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));

		new Float:newMultiplier = StringToFloat(info);
        
        g_fGravityMultiplier = newMultiplier;
        SetConVarFloat(g_hCvarMultiplier, g_fGravityMultiplier);
		
        // --- ИСПРАВЛЕННАЯ ЛОГИКА ---
        // Если режим низкой гравитации был выключен, включаем его
        if (!g_bLowGravEnabled)
        {
            g_bLowGravEnabled = true;
            SetConVarBool(g_hCvarEnabled, true);
        }

        // Немедленно применяем новую гравитацию
        SetAllGravity(g_fGravityMultiplier);

		ReplyToCommand(param1, "Гравитация установлена на %.2f и включена.", g_fGravityMultiplier);

        // Возвращаемся в главное меню
        DisplayGravityMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Event_PlayerSpawn(Event:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_bLowGravEnabled && IsClientInGame(client) && IsPlayerAlive(client)) {
        CreateTimer(0.1, Timer_SetGrav, GetClientUserId(client));
    }
}

public Action:Timer_SetGrav(Handle:timer, any:userid) {
    new client = GetClientOfUserId(userid);
    if (IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntityGravity(client, g_fGravityMultiplier);
    }
    return Plugin_Stop;
}

stock SetAllGravity(Float:grav) {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            SetEntityGravity(i, grav);
        }
    }
}