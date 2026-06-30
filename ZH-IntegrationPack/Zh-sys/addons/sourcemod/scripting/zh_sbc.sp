#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <easy_hudmessage>
#include <zh_core>

#define PLUGIN_VERSION "3.6.0-zh-sys"

// Radius in Hammer units for smoke damage effect
#define SMOKE_RADIUS 200.0
// Targetnames to identify SBC-created entities for cleanup
#define SBC_SMOKE_NAME "zh_sbc_smoke"
#define SBC_LIGHT_NAME "zh_sbc_light"

// --- Global CVAR Handles for SBC functionality ---
ConVar g_cvSBC_Enabled;
ConVar g_cvSBC_Damage_Enabled;
ConVar g_cvSBC_Damage_Amount;
ConVar g_cvSBC_Damage_Interval;
ConVar g_cvSBC_Allow_Team_Damage;
ConVar g_cvSBC_Color_T;
ConVar g_cvSBC_Color_CT;
ConVar g_cvSBC_Color_Mode;
ConVar g_cvSBC_Override_Color;

public Plugin myinfo =
{
    name = "ZH-sys SmokeBomb Combo",
    author = "ZloyHohol",
    description = "ZH-sys version of the toxic smoke system with damage and menu controls",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    CreateConVar("zh_sbc_version", PLUGIN_VERSION, "ZH SBC Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

    // SBC CVARs
    g_cvSBC_Enabled = CreateConVar("zh_sbc_enabled", "1", "Enable/disable the SBC plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSBC_Damage_Enabled = CreateConVar("zh_sbc_damage_enabled", "1", "Enable damage from smoke", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSBC_Damage_Amount = CreateConVar("zh_sbc_damage_amount", "15", "Damage per tick", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_cvSBC_Damage_Interval = CreateConVar("zh_sbc_damage_interval", "1.0", "Damage interval (sec)", FCVAR_NOTIFY, true, 1.0, true, 10.0);
    g_cvSBC_Allow_Team_Damage = CreateConVar("zh_sbc_teammate_damage", "0", "Damage to teammates (0/1), ignores mp_friendlyfire when 1", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvSBC_Color_T = CreateConVar("zh_sbc_color_t", "255 0 0", "Smoke color for T (R G B)");
    g_cvSBC_Color_CT = CreateConVar("zh_sbc_color_ct", "0 0 255", "Smoke color for CT (R G B)");
    g_cvSBC_Color_Mode = CreateConVar("zh_sbc_colormode", "0", "0=team colors, 1=override", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSBC_Override_Color = CreateConVar("zh_sbc_override_color", "0 0 0", "Override color (R G B)");

    HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Post);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    RegConsoleCmd("sbc", Command_SBC, "Open SBC menu");
    RegConsoleCmd("sm_sbc", Command_SBC, "Open SBC menu");

    AutoExecConfig(true, "zh_sbc", "sourcemod");

    // Register this module with ZH Core
    ZH_RegisterModule("sbc");
}

public void OnMapStart()
{
    PrecacheSound("player/cough-1.wav", true);
    PrecacheSound("player/cough-2.wav", true);
    PrecacheSound("player/cough-3.wav", true);
    PrecacheSound("player/cough-4.wav", true);
    AddFileToDownloadsTable("sound/player/cough-1.wav");
    AddFileToDownloadsTable("sound/player/cough-2.wav");
    AddFileToDownloadsTable("sound/player/cough-3.wav");
    AddFileToDownloadsTable("sound/player/cough-4.wav");
}

// --- Event Handlers ---

public void Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvSBC_Enabled.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client)) return;

    float pos[3];
    pos[0] = event.GetFloat("x");
    pos[1] = event.GetFloat("y");
    pos[2] = event.GetFloat("z");

    // Create smoke entity and color
    char sColor[32];
    GetSmokeColorForClient(client, sColor, sizeof(sColor));

    int smokeEnt = CreateEntityByName("env_particlesmokegrenade");
    if (smokeEnt > 0)
    {
        DispatchKeyValue(smokeEnt, "targetname", SBC_SMOKE_NAME);

        char sOrigin[64];
        Format(sOrigin, sizeof(sOrigin), "%f %f %f", pos[0], pos[1], pos[2]);
        DispatchKeyValue(smokeEnt, "origin", sOrigin);
        DispatchKeyValue(smokeEnt, "rendercolor", sColor);
        DispatchSpawn(smokeEnt);
        TeleportEntity(smokeEnt, pos, NULL_VECTOR, NULL_VECTOR);

        // Optional dynamic light
        int lightEnt = CreateEntityByName("light_dynamic");
        if (lightEnt > 0)
        {
            DispatchKeyValue(lightEnt, "origin", sOrigin);
            DispatchKeyValue(lightEnt, "_light", sColor);
            DispatchKeyValue(lightEnt, "pitch", "-90");
            DispatchKeyValue(lightEnt, "distance", "256");
            DispatchKeyValue(lightEnt, "spotlight_radius", "96");
            DispatchKeyValue(lightEnt, "brightness", "3");
            DispatchKeyValue(lightEnt, "style", "6");
            DispatchKeyValue(lightEnt, "spawnflags", "1");
            DispatchKeyValue(lightEnt, "targetname", SBC_LIGHT_NAME);
            DispatchSpawn(lightEnt);
            AcceptEntityInput(lightEnt, "DisableShadow");
            TeleportEntity(lightEnt, pos, NULL_VECTOR, NULL_VECTOR);
            SetVariantString("parentname");
            AcceptEntityInput(lightEnt, "SetParent", lightEnt, smokeEnt, 0);
        }

        if (g_cvSBC_Damage_Enabled.BoolValue)
        {
            DataPack pack = new DataPack();
            pack.WriteCell(GetClientSerial(client));
            pack.WriteCell(EntIndexToEntRef(smokeEnt));
            if (lightEnt > 0)
            {
                pack.WriteCell(EntIndexToEntRef(lightEnt));
            }
            else
            {
                pack.WriteCell(INVALID_ENT_REFERENCE);
            }
            CreateTimer(g_cvSBC_Damage_Interval.FloatValue, Timer_ApplySmokeDamage, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // No per-client state to reset here yet
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // Clean up SBC-created smoke entities when round ends
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "env_particlesmokegrenade")) != -1)
    {
        char nameBuf[64];
        GetEntPropString(ent, Prop_Data, "m_iName", nameBuf, sizeof(nameBuf));
        if (StrEqual(nameBuf, SBC_SMOKE_NAME, false))
        {
            AcceptEntityInput(ent, "Kill");
        }
    }

    ent = -1;
    while ((ent = FindEntityByClassname(ent, "light_dynamic")) != -1)
    {
        char nameBuf[64];
        GetEntPropString(ent, Prop_Data, "m_iName", nameBuf, sizeof(nameBuf));
        if (StrEqual(nameBuf, SBC_LIGHT_NAME, false))
        {
            AcceptEntityInput(ent, "Kill");
        }
    }
}

// --- Damage and smoke logic ---

public Action Timer_ApplySmokeDamage(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    int smokeEntRef = pack.ReadCell();
    int lightEntRef = pack.ReadCell();
    delete pack;

    int smokeEnt = EntRefToEntIndex(smokeEntRef);
    int lightEnt = EntRefToEntIndex(lightEntRef);

    if (smokeEnt == INVALID_ENT_REFERENCE || !IsValidEntity(smokeEnt))
    {
        if (lightEnt != INVALID_ENT_REFERENCE && IsValidEntity(lightEnt))
        {
            AcceptEntityInput(lightEnt, "Kill");
        }
        return Plugin_Stop;
    }

    float smokePos[3];
    GetEntPropVector(smokeEnt, Prop_Send, "m_vecOrigin", smokePos);

    float damage = g_cvSBC_Damage_Amount.FloatValue;
    bool allowTeamDamage = g_cvSBC_Allow_Team_Damage.BoolValue;
    int ownerTeam = (client > 0 && IsClientInGame(client)) ? GetClientTeam(client) : 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;

        // Skip teammates if team damage is disabled
        if (!allowTeamDamage && client > 0 && IsClientInGame(client) && GetClientTeam(i) == ownerTeam && i != client)
        {
            continue;
        }

        float playerPos[3];
        GetClientAbsOrigin(i, playerPos);

        if (GetVectorDistance(smokePos, playerPos) <= SMOKE_RADIUS)
        {
            if (client > 0 && IsClientInGame(client))
            {
                // Apply damage
                SDKHooks_TakeDamage(i, smokeEnt, client, damage, DMG_POISON);

                // Play cough sound
                int randomCough = GetRandomInt(1, 4);
                char coughSound[64];
                Format(coughSound, sizeof(coughSound), "player/cough-%d.wav", randomCough);
                EmitSoundToClient(i, coughSound);

                // For dramatic effect, also emit to nearby players
                for (int j = 1; j <= MaxClients; j++)
                {
                    if (IsClientInGame(j) && i != j)
                    {
                        float otherPos[3];
                        GetClientAbsOrigin(j, otherPos);
                        if (GetVectorDistance(playerPos, otherPos) < 500.0)
                        {
                            EmitSoundToClient(j, coughSound);
                        }
                    }
                }
            }
        }
    }

    return Plugin_Continue;
}

void GetSmokeColorForClient(int client, char[] buffer, int maxlen)
{
    if (g_cvSBC_Color_Mode.IntValue == 1)
    {
        g_cvSBC_Override_Color.GetString(buffer, maxlen);
        return;
    }

    int team = GetClientTeam(client);
    if (team == 2) { g_cvSBC_Color_T.GetString(buffer, maxlen); }
    else { g_cvSBC_Color_CT.GetString(buffer, maxlen); }
}

// --- Menu and Commands ---

public Action Command_SBC(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client)) return Plugin_Handled;

    if (!CheckCommandAccess(client, "sm_sbc_access", ADMFLAG_CUSTOM6))
    {
        CReplyToCommand(client, "%t", "No Access");
        return Plugin_Handled;
    }

    ShowSBCMenu(client);
    return Plugin_Handled;
}

void ShowSBCMenu(int client)
{
    Menu menu = new Menu(MenuHandler_SBC);
    menu.SetTitle("ZH-Sys SmokeBomb Combo - Main Menu");
    menu.ExitButton = true;

    char line[64];

    Format(line, sizeof(line), "Plugin: %s", g_cvSBC_Enabled.BoolValue ? "Enabled" : "Disabled");
    menu.AddItem("toggle_plugin", line);

    Format(line, sizeof(line), "Smoke Damage: %s", g_cvSBC_Damage_Enabled.BoolValue ? "Enabled" : "Disabled");
    menu.AddItem("toggle_damage", line);

    Format(line, sizeof(line), "Teammate Damage: %s", g_cvSBC_Allow_Team_Damage.BoolValue ? "Enabled" : "Disabled");
    menu.AddItem("toggle_teammate", line);

    Format(line, sizeof(line), "Color Mode: %s", g_cvSBC_Color_Mode.IntValue == 0 ? "Team" : "Override");
    menu.AddItem("toggle_colormode", line);

    if (g_cvSBC_Color_Mode.IntValue == 1)
    {
        menu.AddItem("color_black", "Color: Black");
        menu.AddItem("color_white", "Color: White");
        menu.AddItem("color_orange", "Color: Orange");
        menu.AddItem("color_red", "Color: Red");
        menu.AddItem("color_blue", "Color: Blue");
        menu.AddItem("color_brown", "Color: Brown");
        menu.AddItem("color_purple", "Color: Purple");
        menu.AddItem("color_moss", "Color: Moss (dark green)");
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SBC(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[64];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "toggle_plugin"))
        {
            g_cvSBC_Enabled.SetBool(!g_cvSBC_Enabled.BoolValue);
            CPrintToChatAll("{green}[ZH-SBC]{default} Plugin %s.", g_cvSBC_Enabled.BoolValue ? "enabled" : "disabled");
        }
        else if (StrEqual(info, "toggle_damage"))
        {
            g_cvSBC_Damage_Enabled.SetBool(!g_cvSBC_Damage_Enabled.BoolValue);
            CPrintToChatAll("{green}[ZH-SBC]{default} Smoke damage %s.", g_cvSBC_Damage_Enabled.BoolValue ? "enabled" : "disabled");
        }
        else if (StrEqual(info, "toggle_teammate"))
        {
            g_cvSBC_Allow_Team_Damage.SetBool(!g_cvSBC_Allow_Team_Damage.BoolValue);
            CPrintToChatAll("{green}[ZH-SBC]{default} Teammate damage %s.", g_cvSBC_Allow_Team_Damage.BoolValue ? "enabled" : "disabled");
        }
        else if (StrEqual(info, "toggle_colormode"))
        {
            g_cvSBC_Color_Mode.SetInt(g_cvSBC_Color_Mode.IntValue == 0 ? 1 : 0);
            CPrintToChatAll("{green}[ZH-SBC]{default} Color mode set to %s.", g_cvSBC_Color_Mode.IntValue == 0 ? "team colors" : "override");
        }
        else if (StrContains(info, "color_") == 0)
        {
            if (StrEqual(info, "color_black")) g_cvSBC_Override_Color.SetString("0 0 0");
            else if (StrEqual(info, "color_white")) g_cvSBC_Override_Color.SetString("255 255 255");
            else if (StrEqual(info, "color_orange")) g_cvSBC_Override_Color.SetString("255 140 0");
            else if (StrEqual(info, "color_red")) g_cvSBC_Override_Color.SetString("255 0 0");
            else if (StrEqual(info, "color_blue")) g_cvSBC_Override_Color.SetString("0 0 255");
            else if (StrEqual(info, "color_brown")) g_cvSBC_Override_Color.SetString("150 75 0");
            else if (StrEqual(info, "color_purple")) g_cvSBC_Override_Color.SetString("128 0 128");
            else if (StrEqual(info, "color_moss")) g_cvSBC_Override_Color.SetString("25 50 25");

            CPrintToChatAll("{green}[ZH-SBC]{default} Override smoke color changed.");
        }

        ShowSBCMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}
