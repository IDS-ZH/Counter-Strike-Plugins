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
    description = "РџСЂРѕСЃС‚РѕР№, РЅР°РґС‘Р¶РЅС‹Р№ РўРѕРєСЃРёС‡РЅС‹Р№ РґС‹Рј СЃ РјРµРЅСЋ Рё СЃР°РјРѕ-РѕС‡РёСЃС‚РєР°РјРё",
    version     = PLUGIN_VERSION
};

// ----------------------------
// Startup
// ----------------------------
public void OnPluginStart()
{
    g_Smokes = new ArrayList(sizeof(SmokeData));

    g_hEnabled         = CreateConVar("sm_sbc_enabled", "1", "Р’РєР»СЋС‡РёС‚СЊ/РІС‹РєР»СЋС‡РёС‚СЊ РїР»Р°РіРёРЅ", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hDamageEnabled   = CreateConVar("sm_sbc_damage_enabled", "1", "Р’РєР»СЋС‡РёС‚СЊ СѓСЂРѕРЅ РґС‹РјРѕРј", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hDamageAmount    = CreateConVar("sm_sbc_damage_amount", "15", "РЈСЂРѕРЅ Р·Р° С‚РёРє", FCVAR_NOTIFY, true, 1.0, true, 100.0);
    g_hDamageInterval  = CreateConVar("sm_sbc_damage_interval", "1.0", "РРЅС‚РµСЂРІР°Р» СѓСЂРѕРЅР° (СЃРµРє)", FCVAR_NOTIFY, true, 1.0, true, 10.0);
    g_hAllowTeamDamage = CreateConVar("sm_sbc_teammate_damage", "0", "РЈСЂРѕРЅ РїРѕ СЃРІРѕРёРј (0/1), РёРіРЅРѕСЂРёСЂСѓРµС‚ mp_friendlyfire РїСЂРё 1", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hColorT          = CreateConVar("sm_sbc_color_t", "255 0 0", "Р¦РІРµС‚ РґС‹РјР° РґР»СЏ T (R G B)");
    g_hColorCT         = CreateConVar("sm_sbc_color_ct", "0 0 255", "Р¦РІРµС‚ РґС‹РјР° РґР»СЏ CT (R G B)");
    g_hColorMode       = CreateConVar("sm_sbc_colormode", "0", "0=РєРѕРјР°РЅРґРЅС‹Рµ С†РІРµС‚Р°, 1=override", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hOverrideColor   = CreateConVar("sm_sbc_override_color", "0 0 0", "Р¦РІРµС‚ override (R G B)");

    HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    RegConsoleCmd("sbc", Command_SBC, "РћС‚РєСЂС‹С‚СЊ РјРµРЅСЋ SBC");
    RegConsoleCmd("sm_sbc", Command_SBC, "РћС‚РєСЂС‹С‚СЊ РјРµРЅСЋ SBC");

    PrintToServer("[SBC] v%s Р·Р°РіСЂСѓР¶РµРЅ", PLUGIN_VERSION);
    AutoExecConfig(true, "SM_SBC-v3.5");
    

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
    // РџРѕР»РЅР°СЏ РѕС‡РёСЃС‚РєР° РїСЂРё СЃРјРµРЅРµ РєР°СЂС‚С‹
    CleanupAllSmokes(true);
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
        // РЎРІРµС‚ РјРѕР¶РЅРѕ СѓР±РёС‚СЊ РјСЏРіРєРѕ
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

    // Stop timers
    if (d.dmgTimer != null) { KillTimer(d.dmgTimer); d.dmgTimer = null; }

    // Mark inactive
    d.active = false;

    // Kill light
    int l = EntRefToEntIndex(d.lightRef);
    if (l != INVALID_ENT_REFERENCE && IsValidEntity(l)) { AcceptEntityInput(l, "Kill"); d.lightRef = INVALID_ENT_REFERENCE; }

    // Optionally kill smoke entity
    if (killEntities)
    {
        int e = EntRefToEntIndex(d.entRef);
        if (e != INVALID_ENT_REFERENCE && IsValidEntity(e))
        {
            AcceptEntityInput(e, "TurnOff");
            AcceptEntityInput(e, "Kill");
        }
        // Remove from registry
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

    // Create smoke entity and color
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
            DispatchSpawn(lightEnt);
            AcceptEntityInput(lightEnt, "DisableShadow");
        }

        PushSmoke(GetClientUserId(client), smokeEnt, lightEnt);

        // Damage timer only if enabled
        if (g_hDamageEnabled.BoolValue)
        {
            Handle t = CreateTimer(g_hDamageInterval.FloatValue, Timer_ApplySmokeDamage, EntIndexToEntRef(smokeEnt), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            // Store timer in last record
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
    // РњСЏРіРєР°СЏ РѕС‡РёСЃС‚РєР°: РІС‹РєР»СЋС‡РёС‚СЊ СЃРІРµС‚, РЅРѕ РѕСЃС‚Р°РІРёС‚СЊ РґС‹Рј Р¶РёС‚СЊ РїРѕ СЃРІРѕРµРјСѓ TTL
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
    // Р–С‘СЃС‚РєР°СЏ РѕС‡РёСЃС‚РєР° вЂ” РїРѕ С‚СЂРµР±РѕРІР°РЅРёСЋ: РїРѕР»РЅРѕСЃС‚СЊСЋ РґРµР°РєС‚РёРІРёСЂРѕРІР°С‚СЊ Рё СѓР±СЂР°С‚СЊ
    CleanupAllSmokes(true);
    return Plugin_Continue;
}

// ----------------------------
// Disconnect handling
// ----------------------------
public void OnClientDisconnect(int client)
{
    int uid = GetClientUserId(client);
    // Р”РµР°РєС‚РёРІРёСЂРѕРІР°С‚СЊ РІСЃРµ РґС‹РјРѕРІСѓС…Рё СЌС‚РѕРіРѕ РІР»Р°РґРµР»СЊС†Р° вЂ” РїР»Р°РіРёРЅ Р±РѕР»СЊС€Рµ РЅРµ С‚СЂРѕРіР°РµС‚ РёС… (РєР°Рє РїСЂРѕСЃРёР»)
    for (int i = g_Smokes.Length - 1; i >= 0; i--)
    {
        SmokeData d;
        g_Smokes.GetArray(i, d, sizeof(d));
        if (d.ownerUserId == uid)
        {
            // РџРѕР»РЅР°СЏ РґРµР°РєС‚РёРІР°С†РёСЏ (Р±РµР· РѕР±СЏР·Р°С‚РµР»СЊРЅРѕРіРѕ Kill СЃР°РјРѕРіРѕ РґС‹РјР° вЂ” РјРѕР¶РЅРѕ РѕСЃС‚Р°РІРёС‚СЊ РјРёСЂСѓ)
            DeactivateSmokeByIndex(i, true);
        }
    }
}

// ----------------------------
// Timers
// ----------------------------
public Action Timer_ApplySmokeDamage(Handle timer, any smokeEntRef)
{
    // РќР°Р№С‚Рё Р·Р°РїРёСЃСЊ
    int idx = FindSmokeIndexByEntRef(smokeEntRef);
    if (idx == -1)
    {
        return Plugin_Stop;
    }

    SmokeData d;
    g_Smokes.GetArray(idx, d, sizeof(d));

    // TTL
    float now = GetEngineTime();
    if ((now - d.bornTime) >= SMOKE_TTL || !d.active)
    {
        DeactivateSmokeByIndex(idx, true);
        return Plugin_Stop;
    }

    // Р”С‹Рј РІСЃС‘ РµС‰С‘ СЃСѓС‰РµСЃС‚РІСѓРµС‚?
    int smokeEnt = EntRefToEntIndex(d.entRef);
    if (smokeEnt == INVALID_ENT_REFERENCE || !IsValidEntity(smokeEnt))
    {
        DeactivateSmokeByIndex(idx, true);
        return Plugin_Stop;
    }

    // Р•СЃР»Рё СѓСЂРѕРЅ РѕС‚РєР»СЋС‡С‘РЅ вЂ” С‚Р°Р№РјРµСЂ РјРѕР¶РЅРѕ РјСЏРіРєРѕ РѕСЃС‚Р°РЅРѕРІРёС‚СЊ
    if (!g_hDamageEnabled.BoolValue)
    {
        DeactivateSmokeByIndex(idx, false);
        return Plugin_Stop;
    }

    // РџРѕР·РёС†РёСЏ РґС‹РјР°
    float smokePos[3];
    GetEntPropVector(smokeEnt, Prop_Data, "m_vecOrigin", smokePos);

    int owner = GetClientOfUserId(d.ownerUserId);
    bool allowTeamDamage = g_hAllowTeamDamage.BoolValue;
    float damage = g_hDamageAmount.FloatValue;
    int ownerTeam = (owner > 0 && IsClientInGame(owner)) ? GetClientTeam(owner) : 0;

    // Цикл: обходим всех игроков
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i)) { continue; }

        // Пропускаем союзников, если тимдамаг выключен
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
                // Тимдамаг включен -> attacker = 0 (игнорируем mp_friendlyfire)
                // Тимдамаг выключен -> attacker = owner (чтобы урон записался на владельца)
                SDKHooks_TakeDamage(i, smokeEnt, owner, damage, DMG_POISON);
                // Выбираем случайный кашель
                int rnd = GetRandomInt(1, 4);
                char snd[64];
                Format(snd, sizeof(snd), "player/cough-%d.wav", rnd);
                // Проигрываем жертве (он слышит сам)
                EmitSoundToClient(i, snd, i, SNDCHAN_VOICE, SNDLEVEL_NORMAL);
                // Проигрываем всем вокруг в стандартном радиусе
                EmitSoundToAll(snd, i, SNDCHAN_VOICE, SNDLEVEL_NORMAL);
            }
            else
            {
                // Владелец вышел - деактивируем немедленно (плагин больше не действует)
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
    m.SetTitle("SmokeBomb Combo вЂ” Р±Р°Р·РѕРІРѕРµ РјРµРЅСЋ");
    m.ExitButton = true;

    char line[64];

    Format(line, sizeof(line), "РџР»Р°РіРёРЅ: %s", g_hEnabled.BoolValue ? "Р’РєР»СЋС‡РµРЅ" : "Р’С‹РєР»СЋС‡РµРЅ");
    m.AddItem("toggle_plugin", line);

    Format(line, sizeof(line), "РЈСЂРѕРЅ РґС‹РјРѕРј: %s", g_hDamageEnabled.BoolValue ? "Р’РєР»СЋС‡РµРЅ" : "Р’С‹РєР»СЋС‡РµРЅ");
    m.AddItem("toggle_damage", line);

    Format(line, sizeof(line), "РЈСЂРѕРЅ РїРѕ СЃРІРѕРёРј: %s", g_hAllowTeamDamage.BoolValue ? "Р’РєР»СЋС‡РµРЅ" : "Р’С‹РєР»СЋС‡РµРЅ");
    m.AddItem("toggle_teammate", line);

    Format(line, sizeof(line), "Р РµР¶РёРј С†РІРµС‚Р°: %s", g_hColorMode.IntValue == 0 ? "РљРѕРјР°РЅРґРЅС‹Р№" : "Override");
    m.AddItem("toggle_colormode", line);

    if (g_hColorMode.IntValue == 1)
    {
        m.AddItem("color_black",    "Р¦РІРµС‚: Р§С‘СЂРЅС‹Р№");
        m.AddItem("color_white",    "Р¦РІРµС‚: Р‘РµР»С‹Р№");
        m.AddItem("color_orange",   "Р¦РІРµС‚: РћСЂР°РЅР¶РµРІС‹Р№");
        m.AddItem("color_red",      "Р¦РІРµС‚: РљСЂР°СЃРЅС‹Р№");
        m.AddItem("color_blue",     "Р¦РІРµС‚: РЎРёРЅРёР№");
        m.AddItem("color_brown",    "Р¦РІРµС‚: РљРѕСЂРёС‡РЅРµРІС‹Р№");
        m.AddItem("color_purple",   "Р¦РІРµС‚: РџСѓСЂРїСѓСЂРЅС‹Р№");
        m.AddItem("color_moss",     "Р¦РІРµС‚: РњС…РѕРІС‹Р№ (С‚С‘РјРЅРѕ-Р·РµР»С‘РЅС‹Р№)");
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
            g_hEnabled.SetBool(!g_hEnabled.BoolValue);
            NotifyAll("РџР»Р°РіРёРЅ", g_hEnabled.BoolValue);
        }
        else if (StrEqual(info, "toggle_damage"))
        {
            g_hDamageEnabled.SetBool(!g_hDamageEnabled.BoolValue);
            NotifyAll("РЈСЂРѕРЅ РґС‹РјРѕРј", g_hDamageEnabled.BoolValue);
        }
        else if (StrEqual(info, "toggle_teammate"))
        {
            g_hAllowTeamDamage.SetBool(!g_hAllowTeamDamage.BoolValue);
            NotifyAll("РЈСЂРѕРЅ РїРѕ СЃРІРѕРёРј", g_hAllowTeamDamage.BoolValue);
        }
        else if (StrEqual(info, "toggle_colormode"))
        {
            g_hColorMode.SetInt(g_hColorMode.IntValue == 0 ? 1 : 0);
            NotifyAll("Р РµР¶РёРј С†РІРµС‚Р°", g_hColorMode.IntValue == 1);
        }
        else if (StrContains(info, "color_") == 0)
        {
            if (StrEqual(info, "color_black"))  g_hOverrideColor.SetString("0 0 0");
            else if (StrEqual(info, "color_white"))  g_hOverrideColor.SetString("255 255 255");
            else if (StrEqual(info, "color_orange")) g_hOverrideColor.SetString("255 140 0");
            else if (StrEqual(info, "color_red"))    g_hOverrideColor.SetString("255 0 0");
            else if (StrEqual(info, "color_blue"))   g_hOverrideColor.SetString("0 0 255");
            else if (StrEqual(info, "color_brown"))  g_hOverrideColor.SetString("150 75 0");
            else if (StrEqual(info, "color_purple")) g_hOverrideColor.SetString("128 0 128");
            else if (StrEqual(info, "color_moss"))   g_hOverrideColor.SetString("25 50 25");

            CPrintToChatAll("{green}[SBC]{default} Override-С†РІРµС‚ РґС‹РјР° РёР·РјРµРЅС‘РЅ.");
            SendHudMessage(client, HUD_CHANNEL, -1.0, 0.20, HUD_COLOR1, HUD_COLOR2, 0, 0.5, 0.5, 2.5, 0.0,
                "SBC: Р¦РІРµС‚ РёР·РјРµРЅС‘РЅ");
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
    Format(msg, sizeof(msg), "{green}[SBC]{default} %s: %s", what, state ? "{lime}Р’РєР»СЋС‡РµРЅРѕ" : "{red}Р’С‹РєР»СЋС‡РµРЅРѕ");
    CPrintToChatAll(msg);

    // HUD РІСЃРµРј Р¶РёРІС‹Рј РёРіСЂРѕРєР°Рј
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SendHudMessage(i, HUD_CHANNEL, -1.0, 0.20, HUD_COLOR1, HUD_COLOR2, 0, 0.4, 0.4, 2.0, 0.0,
                "SBC: %s %s", what, state ? "Р’РљР›" : "Р’Р«РљР›");
        }
    }
}
