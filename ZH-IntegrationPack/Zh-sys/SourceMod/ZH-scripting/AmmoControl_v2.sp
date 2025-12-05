#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <datapack>

#define PLUGIN_VERSION "2.0"

public Plugin myinfo = 
{
    name = "Ammunition Control v2",
    author = "Gemini",
    description = "Controls ammunition amounts for weapons and implements custom shotgun reload.",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// --- Global CVAR Handles for general ammo control ---
ConVar g_cvAmmo_338mag_max;
ConVar g_cvAmmo_357sig_max;
ConVar g_cvAmmo_45acp_max;
ConVar g_cvAmmo_50AE_max;
ConVar g_cvAmmo_556mm_box_max;
ConVar g_cvAmmo_556mm_max;
ConVar g_cvAmmo_57mm_max;
ConVar g_cvAmmo_762mm_max;
ConVar g_cvAmmo_9mm_max;
ConVar g_cvAmmo_buckshot_max;
ConVar g_cvAmmo_flashbang_max;
ConVar g_cvAmmo_hegrenade_max;
ConVar g_cvAmmo_smokegrenade_max;

// --- Global CVAR Handles for M3 and XM1014 shotgun reload ---
ConVar g_cvWeapon_m3_mag_reload_enabled;
ConVar g_cvWeapon_m3_clip;
ConVar g_cvWeapon_m3_reload_time;
ConVar g_cvWeapon_xm1014_mag_reload_enabled;
ConVar g_cvWeapon_xm1014_clip;
ConVar g_cvWeapon_xm1014_reload_time;

// --- Global variables for shotgun reload logic ---
bool g_bCanReload[MAXPLAYERS + 1];

// --- Plugin Start ---
public void OnPluginStart()
{
    CreateConVar("sm_ammocontrol_version", PLUGIN_VERSION, "Ammunition Control Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

    // General Ammo CVARs
    g_cvAmmo_338mag_max = CreateConVar("sm_ammo_338mag_max", "60", "Max ammo for AWP");
    g_cvAmmo_357sig_max = CreateConVar("sm_ammo_357sig_max", "104", "Max ammo for P228");
    g_cvAmmo_45acp_max = CreateConVar("sm_ammo_45acp_max", "200", "Max ammo for UMP45, Mac10");
    g_cvAmmo_50AE_max = CreateConVar("sm_ammo_50AE_max", "70", "Max ammo for Desert Eagle");
    g_cvAmmo_556mm_box_max = CreateConVar("sm_ammo_556mm_box_max", "400", "Max ammo for M249");
    g_cvAmmo_556mm_max = CreateConVar("sm_ammo_556mm_max", "180", "Max ammo for M4A1, Galil, Famas, SG552");
    g_cvAmmo_57mm_max = CreateConVar("sm_ammo_57mm_max", "200", "Max ammo for P90");
    g_cvAmmo_762mm_max = CreateConVar("sm_ammo_762mm_max", "180", "Max ammo for AK47, G3SG1");
    g_cvAmmo_9mm_max = CreateConVar("sm_ammo_9mm_max", "240", "Max ammo for Glock, USP, MP5, TMP");
    g_cvAmmo_buckshot_max = CreateConVar("sm_ammo_buckshot_max", "64", "Max ammo for M3, XM1014");
    g_cvAmmo_flashbang_max = CreateConVar("sm_ammo_flashbang_max", "4", "Max ammo for Flashbang");
    g_cvAmmo_hegrenade_max = CreateConVar("sm_ammo_hegrenade_max", "4", "Max ammo for HE Grenade");
    g_cvAmmo_smokegrenade_max = CreateConVar("sm_ammo_smokegrenade_max", "4", "Max ammo for Smoke Grenade");

    // Shotgun Reload CVARs
    g_cvWeapon_m3_mag_reload_enabled = CreateConVar("sm_weapon_m3_magazine_reload", "1", "Enable magazine-style reload for M3? 0=No, 1=Yes", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvWeapon_m3_clip = CreateConVar("sm_weapon_m3_clip", "8", "Clip size for M3 Shotgun. 0 = default");
    g_cvWeapon_m3_reload_time = CreateConVar("sm_weapon_m3_reload_time", "5.7", "Reload time in seconds for M3 magazine.", FCVAR_NONE, true, 3.0, true, 6.0);
    g_cvWeapon_xm1014_mag_reload_enabled = CreateConVar("sm_weapon_xm1014_magazine_reload", "1", "Enable magazine-style reload for XM1014? 0=No, 1=Yes", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvWeapon_xm1014_clip = CreateConVar("sm_weapon_xm1014_clip", "20", "Clip size for XM1014 Shotgun. 0 = default");
    g_cvWeapon_xm1014_reload_time = CreateConVar("sm_weapon_xm1014_reload_time", "5.7", "Reload time in seconds for XM1014 magazine.", FCVAR_NONE, true, 3.0, true, 6.0);

    // Hooks
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    // CVAR Change Hooks
    g_cvAmmo_338mag_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_357sig_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_45acp_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_50AE_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_556mm_box_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_556mm_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_57mm_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_762mm_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_9mm_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_buckshot_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_flashbang_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_hegrenade_max.AddChangeHook(OnCvarChanged);
    g_cvAmmo_smokegrenade_max.AddChangeHook(OnCvarChanged);
    g_cvWeapon_m3_mag_reload_enabled.AddChangeHook(OnCvarChanged);
    g_cvWeapon_m3_clip.AddChangeHook(OnCvarChanged);
    g_cvWeapon_m3_reload_time.AddChangeHook(OnCvarChanged);
    g_cvWeapon_xm1014_mag_reload_enabled.AddChangeHook(OnCvarChanged);
    g_cvWeapon_xm1014_clip.AddChangeHook(OnCvarChanged);
    g_cvWeapon_xm1014_reload_time.AddChangeHook(OnCvarChanged);

    AutoExecConfig(true, "ammocontrol_v2");

    UpdateGameCvrs();
}

public void OnConfigsExecuted()
{
    UpdateGameCvrs();
}

public void OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    UpdateGameCvrs();
}

void UpdateGameCvrs()
{
    SetConVarInt(FindConVar("ammo_338mag_max"), g_cvAmmo_338mag_max.IntValue);
    SetConVarInt(FindConVar("ammo_357sig_max"), g_cvAmmo_357sig_max.IntValue);
    SetConVarInt(FindConVar("ammo_45acp_max"), g_cvAmmo_45acp_max.IntValue);
    SetConVarInt(FindConVar("ammo_50AE_max"), g_cvAmmo_50AE_max.IntValue);
    SetConVarInt(FindConVar("ammo_556mm_box_max"), g_cvAmmo_556mm_box_max.IntValue);
    SetConVarInt(FindConVar("ammo_556mm_max"), g_cvAmmo_556mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_57mm_max"), g_cvAmmo_57mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_762mm_max"), g_cvAmmo_762mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_9mm_max"), g_cvAmmo_9mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_buckshot_max"), g_cvAmmo_buckshot_max.IntValue);
    SetConVarInt(FindConVar("ammo_flashbang_max"), g_cvAmmo_flashbang_max.IntValue);
    SetConVarInt(FindConVar("ammo_hegrenade_max"), g_cvAmmo_hegrenade_max.IntValue);
    SetConVarInt(FindConVar("ammo_smokegrenade_max"), g_cvAmmo_smokegrenade_max.IntValue);
}

// --- Shotgun Reload Logic ---

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
}

public void OnWeaponEquip(int client, int weapon)
{
    if (!IsValidEdict(weapon)) return;

    char sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

    if (StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
    {
        SDKHook(weapon, SDKHook_ReloadPost, OnWeaponReload);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (buttons & IN_RELOAD)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if (IsValidEdict(weapon))
        {
            char sWeapon[32];
            GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
            if (StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
            {
                g_bCanReload[client] = true;
            }
        }
    }
    return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            g_bCanReload[i] = false;
        }
    }
}

public Action OnWeaponReload(int weapon)
{
    int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Continue;

    char sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

    bool isM3 = StrEqual(sWeapon, "weapon_m3");
    bool isXm1014 = StrEqual(sWeapon, "weapon_xm1014");

    if ((isM3 && !g_cvWeapon_m3_mag_reload_enabled.BoolValue) || (isXm1014 && !g_cvWeapon_xm1014_mag_reload_enabled.BoolValue)) return Plugin_Continue;

    int clipSize = isM3 ? g_cvWeapon_m3_clip.IntValue : g_cvWeapon_xm1014_clip.IntValue;
    float reloadTime = isM3 ? g_cvWeapon_m3_reload_time.FloatValue : g_cvWeapon_xm1014_reload_time.FloatValue;

    int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(weapon, Prop_Send, "m_iClip1");

    if(clip > 0 && g_bCanReload[client] == false)
        return Plugin_Handled;

    if(ammo <= 0)
        return Plugin_Handled;

    if(clip >= clipSize)
    {
        g_bCanReload[client] = false;
        return Plugin_Handled;
    }

    if(clip == 0 && ammo > 0)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientSerial(client));
        pack.WriteCell(weapon);
        pack.WriteCell(isM3 ? 1 : 0); // 1 for M3, 0 for XM1014
        CreateTimer(reloadTime, Timer_Reload, pack);

        DataPack pack2 = new DataPack();
        pack2.WriteCell(GetClientSerial(client));
        pack2.WriteCell(weapon);
        CreateTimer(reloadTime + 0.1, Timer_BlockShoot, pack2);

        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 9999.0);
    }

    if(clip > 0 && clip < clipSize && ammo > 0)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientSerial(client));
        pack.WriteCell(weapon);
        pack.WriteCell(isM3 ? 1 : 0); // 1 for M3, 0 for XM1014
        CreateTimer(reloadTime, Timer_Reload2, pack);

        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 9999.0);
    }
    return Plugin_Handled;
}


public Action Timer_Reload(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    int weapon = pack.ReadCell();
    bool isM3 = pack.ReadCell() == 1;
    delete pack;

    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Stop;

    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));

    if((isM3 && !StrEqual(sWeapon, "weapon_m3")) || (!isM3 && !StrEqual(sWeapon, "weapon_xm1014"))) return Plugin_Stop;

    int clipSize = isM3 ? g_cvWeapon_m3_clip.IntValue : g_cvWeapon_xm1014_clip.IntValue;

    int ammoType = GetEntProp(currentWeapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(currentWeapon, Prop_Send, "m_iClip1");

    if(clip > 0 && g_bCanReload[client] == false)
        return Plugin_Stop;

    if(ammo <= 0)
        return Plugin_Stop;

    if(clip >= clipSize)
        return Plugin_Stop;

    if(ammo >= clipSize)
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", clipSize);
        SetEntProp(client, Prop_Data, "m_iAmmo", ammo - clipSize, 4, ammoType);
    }
    else
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", ammo);
        SetEntProp(client, Prop_Data, "m_iAmmo", 0, 4, ammoType);
    }

    g_bCanReload[client] = false;
    return Plugin_Continue;
}


public Action Timer_Reload2(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    int weapon = pack.ReadCell();
    bool isM3 = pack.ReadCell() == 1;
    delete pack;

    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Stop;

    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));

    if((isM3 && !StrEqual(sWeapon, "weapon_m3")) || (!isM3 && !StrEqual(sWeapon, "weapon_xm1014"))) return Plugin_Stop;

    int clipSize = isM3 ? g_cvWeapon_m3_clip.IntValue : g_cvWeapon_xm1014_clip.IntValue;

    int ammoType = GetEntProp(currentWeapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(currentWeapon, Prop_Send, "m_iClip1");
    int TempClip = clipSize - clip;

    if(clip > 0 && g_bCanReload[client] == false)
        return Plugin_Stop;

    if(ammo <= 0)
        return Plugin_Stop;

    if(clip >= clipSize)
        return Plugin_Stop;

    if(ammo >= TempClip)
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", clipSize);
        SetEntProp(client, Prop_Data, "m_iAmmo", ammo - TempClip, 4, ammoType);
    }
    else
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", clip + ammo);
        SetEntProp(client, Prop_Data, "m_iAmmo", 0, 4, ammoType);
    }
    SetEntPropFloat(currentWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.0);

    g_bCanReload[client] = false;
    return Plugin_Continue;
}


public Action Timer_BlockShoot(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    int weapon = pack.ReadCell();
    delete pack;

    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Stop;

    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));

    if(StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
    {
        SetEntPropFloat(currentWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.0);
    }
    return Plugin_Continue;
}
