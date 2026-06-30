#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <easy_hudmessage>

#define PLUGIN_VERSION "3.5"
#define MAX_SMOKES 128
#define SMOKE_RADIUS 200.0
#define SMOKE_TTL 16.0

// HUD: acid green (rgba) and not on channel 3
#define HUD_CHANNEL 4
#define HUD_COLOR1 0x39FF14FF
#define HUD_COLOR2 0xFFFFFFFF

// ----------------------------
// Data
// ----------------------------
enum struct SmokeData
{
    int ownerUserId;     // who threw it (UserId, stable across slot reuse)
    int entRef;          // env_particlesmokegrenade EntRef
    int lightRef;        // light_dynamic EntRef (optional)
    Handle dmgTimer;     // damage timer
    float bornTime;      // creation time
    bool active;         // if false, plugin ignores this smoke (deactivated)
}

ArrayList g_Smokes;
StringMap g_smPermissions;

// ----------------------------
// CVars
// ----------------------------
ConVar g_hEnabled;
ConVar g_hDamageEnabled;
ConVar g_hDamageAmount;
ConVar g_hDamageInterval;
ConVar g_hAllowTeamDamage;
ConVar g_hColorT;
ConVar g_hColorCT;
ConVar g_hColorMode;      // 0=team colors, 1=override
ConVar g_hOverrideColor;  // "R G B"

// ----------------------------
// Plugin info
// ----------------------------
public Plugin myinfo =
{
    name        = "SmokeBomb Combo V3.5",
    author      = "ZloyHohol",
    description = "Настраиваемый, Токсичный дым с уровнями доступа",
    version     = PLUGIN_VERSION
};

// ----------------------------
// Startup
// ----------------------------
public void OnPluginStart()
{
    g_Smokes = new ArrayList(sizeof(SmokeData));
    g_smPermissions = new StringMap();

    g_hEnabled         = CreateConVar("sm_sbc_enabled", "1", "Включить/выключить плагин", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hDamageEnabled   = CreateConVar("sm_sbc_damage_enabled", "1", "Включить урон дымом", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hDamageAmount    = CreateConVar("sm_sbc_damage_amount", "15", "Урон за тик", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_hDamageInterval  = CreateConVar("sm_sbc_damage_interval", "1.0", "Интервал урона (сек)", FCVAR_NOTIFY, true, 1.0, true, 10.0);
    g_hAllowTeamDamage = CreateConVar("sm_sbc_teammate_damage", "0", "Урон по своим (0/1), игнорирует mp_friendlyfire при 1", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hColorT          = CreateConVar("sm_sbc_color_t", "255 0 0", "Цвет дыма для T (R G B)");
    g_hColorCT         = CreateConVar("sm_sbc_color_ct", "0 0 255", "Цвет дыма для CT (R G B)");
    g_hColorMode       = CreateConVar("sm_sbc_colormode", "0", "0=командные цвета, 1=override", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hOverrideColor   = CreateConVar("sm_sbc_override_color", "0 0 0", "Цвет override (R G B)");

    HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    RegConsoleCmd("sbc", Command_SBC, "Открыть меню SBC");
    RegConsoleCmd("sm_sbc", Command_SBC, "Открыть меню SBC");
    RegAdminCmd("sm_sbc_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Перезагрузить конфиг доступов SBC");

    PrintToServer("[SBC] v%s загружен", PLUGIN_VERSION);
    
    LoadConfig();
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

public void OnMapEnd()
{
    CleanupAllSmokes(true);
}

// ----------------------------
// Config & Access
// ----------------------------
void LoadConfig()
{
    g_smPermissions.Clear();
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/SBC_V3.cfg");

    KeyValues kv = new KeyValues("SmokeBombCombo");
    if (!kv.ImportFromFile(path))
    {
        LogError("[SBC] Cannot load configs/SBC_V3.cfg");
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
    PrintToServer("[SBC] Конфиг и доступы успешно загружены.");
}

public Action Command_ReloadConfig(int client, int args)
{
    LoadConfig();
    if (client > 0 && IsClientInGame(client))
    {
        CPrintToChat(client, "{green}[SBC]{default} Конфиг перезагружен.");
    }
    else
    {
        PrintToServer("[SBC] Конфиг перезагружен.");
    }
    return Plugin_Handled;
}

bool HasAccessToSetting(int client, const char[] settingName)
{
    // Root admins ALWAYS have access
    if (GetAdminFlag(GetUserAdmin(client), Admin_Root))
    {
        return true;
    }

    char allowRuler[256];
    if (g_smPermissions.GetString(settingName, allowRuler, sizeof(allowRuler)))
    {
        if (allowRuler[0] == '\0')
        {
            return false; // Only root allowed if empty
        }

        char auth[64];
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

        char parts[16][64];
        int count = ExplodeString(allowRuler, " ", parts, sizeof(parts), sizeof(parts[]));

        for (int i = 0; i < count; i++)
        {
            if (parts[i][0] == '\0') continue;

            if (StrEqual(parts[i], auth, false))
                return true;

            AdminId admin = GetUserAdmin(client);
            if (admin != INVALID_ADMIN_ID)
            {
                int groupCount = GetAdminGroupCount(admin);
                char groupName[64];
                for (int g = 0; g < groupCount; g++)
                {
                    admin.GetGroup(g, groupName, sizeof(groupName));
                    if (StrEqual(groupName, parts[i], false))
                    {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

// ----------------------------
// Helpers
// ----------------------------
static void GetSmokeColorForClient(int client, char[] buffer, int maxlen)
{
    if (g_hColorMode.IntValue == 1)
    {
        g_hOverrideColor.GetString(buffer, maxlen);
        return;
    }

    int team = GetClientTeam(client);
    if (team == 2) { g_hColorT.GetString(buffer, maxlen); }
    else { g_hColorCT.GetString(buffer, maxlen); }
}

static void PushSmoke(int ownerUserId, int smokeEnt, int lightEnt)
{
    if (g_Smokes.Length >= MAX_SMOKES)
    {
        SmokeData old;
        g_Smokes.GetArray(0, old, sizeof(old));
        if (old.dmgTimer != null) { KillTimer(old.dmgTimer); }
        int l = EntRefToEntIndex(old.lightRef);
        if (l != INVALID_ENT_REFERENCE && IsValidEntity(l)) { AcceptEntityInput(l, "Kill"); }
        g_Smokes.Erase(0);
    }

    SmokeData d;
    d.ownerUserId = ownerUserId;
    d.entRef      = EntIndexToEntRef(smokeEnt);
    d.lightRef    = (lightEnt > 0) ? EntIndexToEntRef(lightEnt) : INVALID_ENT_REFERENCE;
    d.dmgTimer    = null;
    d.bornTime    = GetEngineTime();
    d.active      = true;

    g_Smokes.PushArray(d);
}

static void DeactivateSmokeByIndex(int idx, bool killEntities)
{
    SmokeData d;
    g_Smokes.GetArray(idx, d, sizeof(d));

    if (d.dmgTimer != null) { KillTimer(d.dmgTimer); d.dmgTimer = null; }
    d.active = false;

    int l = EntRefToEntIndex(d.lightRef);
    if (l != INVALID_ENT_REFERENCE && IsValidEntity(l)) { AcceptEntityInput(l, "Kill"); d.lightRef = INVALID_ENT_REFERENCE; }

    if (killEntities)
    {
        int e = EntRefToEntIndex(d.entRef);
        if (e != INVALID_ENT_REFERENCE && IsValidEntity(e))
        {
            AcceptEntityInput(e, "TurnOff");
            AcceptEntityInput(e, "Kill");
        }
        g_Smokes.Erase(idx);
    }
    else
    {
        g_Smokes.SetArray(idx, d, sizeof(d));
    }
}

// ----------------------------
// Events
// ----------------------------
public Action Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnabled.BoolValue) { return Plugin_Continue; }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client)) { return Plugin_Continue; }

    float pos[3];
    pos[0] = event.GetFloat("x");
    pos[1] = event.GetFloat("y");
    pos[2] = event.GetFloat("z");

    char sColor[32];
    GetSmokeColorForClient(client, sColor, sizeof(sColor));

    int smokeEnt = CreateEntityByName("env_particlesmokegrenade");
    if (smokeEnt > 0)
    {
        char sOrigin[64];
        Format(sOrigin, sizeof(sOrigin), "%f %f %f", pos[0], pos[1], pos[2]);
        DispatchKeyValue(smokeEnt, "origin", sOrigin);
        DispatchKeyValue(smokeEnt, "rendercolor", sColor);
        DispatchSpawn(smokeEnt);

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
            DispatchSpawn(lightEnt);
            AcceptEntityInput(lightEnt, "DisableShadow");
        }

        PushSmoke(GetClientUserId(client), smokeEnt, lightEnt);

        if (g_hDamageEnabled.BoolValue)
        {
            Handle t = CreateTimer(g_hDamageInterval.FloatValue, Timer_ApplySmokeDamage, EntIndexToEntRef(smokeEnt), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            int idx = g_Smokes.Length - 1;
            SmokeData d;
            g_Smokes.GetArray(idx, d, sizeof(d));
            d.dmgTimer = t;
            g_Smokes.SetArray(idx, d, sizeof(d));
        }
    }

    return Plugin_Handled;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = g_Smokes.Length - 1; i >= 0; i--)
    {
        SmokeData d;
        g_Smokes.GetArray(i, d, sizeof(d));
        int l = EntRefToEntIndex(d.lightRef);
        if (l != INVALID_ENT_REFERENCE && IsValidEntity(l)) { AcceptEntityInput(l, "Kill"); d.lightRef = INVALID_ENT_REFERENCE; }
        g_Smokes.SetArray(i, d, sizeof(d));
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    CleanupAllSmokes(true);
    return Plugin_Continue;
}

// ----------------------------
// Disconnect handling
// ----------------------------
public void OnClientDisconnect(int client)
{
    int uid = GetClientUserId(client);
    for (int i = g_Smokes.Length - 1; i >= 0; i--)
    {
        SmokeData d;
        g_Smokes.GetArray(i, d, sizeof(d));
        if (d.ownerUserId == uid)
        {
            DeactivateSmokeByIndex(i, true);
        }
    }
}

// ----------------------------
// Timers
// ----------------------------
public Action Timer_ApplySmokeDamage(Handle timer, any smokeEntRef)
{
    int idx = FindSmokeIndexByEntRef(smokeEntRef);
    if (idx == -1)
    {
        return Plugin_Stop;
    }

    SmokeData d;
    g_Smokes.GetArray(idx, d, sizeof(d));

    float now = GetEngineTime();
    if ((now - d.bornTime) >= SMOKE_TTL || !d.active)
    {
        DeactivateSmokeByIndex(idx, true);
        return Plugin_Stop;
    }

    int smokeEnt = EntRefToEntIndex(d.entRef);
    if (smokeEnt == INVALID_ENT_REFERENCE || !IsValidEntity(smokeEnt))
    {
        DeactivateSmokeByIndex(idx, true);
        return Plugin_Stop;
    }

    if (!g_hDamageEnabled.BoolValue)
    {
        DeactivateSmokeByIndex(idx, false);
        return Plugin_Stop;
    }

    float smokePos[3];
    GetEntPropVector(smokeEnt, Prop_Data, "m_vecOrigin", smokePos);

    int owner = GetClientOfUserId(d.ownerUserId);
    bool allowTeamDamage = g_hAllowTeamDamage.BoolValue;
    float damage = g_hDamageAmount.FloatValue;
    int ownerTeam = (owner > 0 && IsClientInGame(owner)) ? GetClientTeam(owner) : 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i)) { continue; }

        if (!allowTeamDamage && owner > 0 && IsClientInGame(owner) && GetClientTeam(i) == ownerTeam)
        {
            continue;
        }

        float playerPos[3];
        GetClientAbsOrigin(i, playerPos);

        if (GetVectorDistance(smokePos, playerPos) <= SMOKE_RADIUS)
        {
            if (owner > 0 && IsClientInGame(owner))
            {
                SDKHooks_TakeDamage(i, smokeEnt, owner, damage, DMG_POISON);
                int rnd = GetRandomInt(1, 4);
                char snd[64];
                Format(snd, sizeof(snd), "player/cough-%d.wav", rnd);
                EmitSoundToClient(i, snd, i, SNDCHAN_VOICE, SNDLEVEL_NORMAL);
                EmitSoundToAll(snd, i, SNDCHAN_VOICE, SNDLEVEL_NORMAL);
            }
            else
            {
                DeactivateSmokeByIndex(idx, true);
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}

static int FindSmokeIndexByEntRef(int entRef)
{
    for (int i = g_Smokes.Length - 1; i >= 0; i--)
    {
        SmokeData d;
        g_Smokes.GetArray(i, d, sizeof(d));
        if (d.entRef == entRef) { return i; }
    }
    return -1;
}

static void CleanupAllSmokes(bool killEntities)
{
    for (int i = g_Smokes.Length - 1; i >= 0; i--)
    {
        DeactivateSmokeByIndex(i, killEntities);
    }
}

// ----------------------------
// Menu
// ----------------------------
public Action Command_SBC(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    ShowSBCMenu(client);
    return Plugin_Handled;
}

static void ShowSBCMenu(int client)
{
    Menu m = CreateMenu(MenuHandler_SBC);
    m.SetTitle("SmokeBomb Combo — управление");
    m.ExitButton = true;

    char line[64];
    int itemCount = 0;

    if (HasAccessToSetting(client, "sm_sbc_enabled"))
    {
        Format(line, sizeof(line), "Плагин: %s", g_hEnabled.BoolValue ? "Включен" : "Выключен");
        m.AddItem("toggle_plugin", line);
        itemCount++;
    }

    if (HasAccessToSetting(client, "sm_sbc_damage_enabled"))
    {
        Format(line, sizeof(line), "Урон дымом: %s", g_hDamageEnabled.BoolValue ? "Включен" : "Выключен");
        m.AddItem("toggle_damage", line);
        itemCount++;
    }

    if (HasAccessToSetting(client, "sm_sbc_teammate_damage"))
    {
        Format(line, sizeof(line), "Урон по своим: %s", g_hAllowTeamDamage.BoolValue ? "Включен" : "Выключен");
        m.AddItem("toggle_teammate", line);
        itemCount++;
    }

    if (HasAccessToSetting(client, "sm_sbc_colormode"))
    {
        Format(line, sizeof(line), "Режим цвета: %s", g_hColorMode.IntValue == 0 ? "Командный" : "Override");
        m.AddItem("toggle_colormode", line);
        itemCount++;
    }

    if (g_hColorMode.IntValue == 1 && HasAccessToSetting(client, "sm_sbc_override_color"))
    {
        m.AddItem("color_black",    "Цвет: Чёрный");
        m.AddItem("color_white",    "Цвет: Белый");
        m.AddItem("color_orange",   "Цвет: Оранжевый");
        m.AddItem("color_red",      "Цвет: Красный");
        m.AddItem("color_blue",     "Цвет: Синий");
        m.AddItem("color_brown",    "Цвет: Коричневый");
        m.AddItem("color_purple",   "Цвет: Пурпурный");
        m.AddItem("color_moss",     "Цвет: Мховый (тёмно-зелёный)");
        itemCount++;
    }

    if (itemCount == 0)
    {
        CPrintToChat(client, "{red}[SBC]{default} У вас нет прав для изменения настроек.");
        delete m;
        return;
    }

    m.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SBC(Menu m, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[64];
        m.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "toggle_plugin"))
        {
            if (HasAccessToSetting(client, "sm_sbc_enabled"))
            {
                g_hEnabled.SetBool(!g_hEnabled.BoolValue);
                NotifyAll("Плагин", g_hEnabled.BoolValue);
            }
        }
        else if (StrEqual(info, "toggle_damage"))
        {
            if (HasAccessToSetting(client, "sm_sbc_damage_enabled"))
            {
                g_hDamageEnabled.SetBool(!g_hDamageEnabled.BoolValue);
                NotifyAll("Урон дымом", g_hDamageEnabled.BoolValue);
            }
        }
        else if (StrEqual(info, "toggle_teammate"))
        {
            if (HasAccessToSetting(client, "sm_sbc_teammate_damage"))
            {
                g_hAllowTeamDamage.SetBool(!g_hAllowTeamDamage.BoolValue);
                NotifyAll("Урон по своим", g_hAllowTeamDamage.BoolValue);
            }
        }
        else if (StrEqual(info, "toggle_colormode"))
        {
            if (HasAccessToSetting(client, "sm_sbc_colormode"))
            {
                g_hColorMode.SetInt(g_hColorMode.IntValue == 0 ? 1 : 0);
                NotifyAll("Режим цвета", g_hColorMode.IntValue == 1);
            }
        }
        else if (StrContains(info, "color_") == 0)
        {
            if (HasAccessToSetting(client, "sm_sbc_override_color"))
            {
                if (StrEqual(info, "color_black"))  g_hOverrideColor.SetString("0 0 0");
                else if (StrEqual(info, "color_white"))  g_hOverrideColor.SetString("255 255 255");
                else if (StrEqual(info, "color_orange")) g_hOverrideColor.SetString("255 140 0");
                else if (StrEqual(info, "color_red"))    g_hOverrideColor.SetString("255 0 0");
                else if (StrEqual(info, "color_blue"))   g_hOverrideColor.SetString("0 0 255");
                else if (StrEqual(info, "color_brown"))  g_hOverrideColor.SetString("150 75 0");
                else if (StrEqual(info, "color_purple")) g_hOverrideColor.SetString("128 0 128");
                else if (StrEqual(info, "color_moss"))   g_hOverrideColor.SetString("25 50 25");

                CPrintToChatAll("{green}[SBC]{default} Override-цвет дыма изменён.");
                SendHudMessage(client, HUD_CHANNEL, -1.0, 0.20, HUD_COLOR1, HUD_COLOR2, 0, 0.5, 0.5, 2.5, 0.0,
                    "SBC: Цвет изменён");
            }
        }

        ShowSBCMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete m;
    }
    return 0;
}

// ----------------------------
// Notifications
// ----------------------------
static void NotifyAll(const char[] what, bool state)
{
    char msg[128];
    Format(msg, sizeof(msg), "{green}[SBC]{default} %s: %s", what, state ? "{lime}Включено" : "{red}Выключено");
    CPrintToChatAll(msg);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SendHudMessage(i, HUD_CHANNEL, -1.0, 0.20, HUD_COLOR1, HUD_COLOR2, 0, 0.4, 0.4, 2.0, 0.0,
                "SBC: %s %s", what, state ? "ВКЛ" : "ВЫКЛ");
        }
    }
}
