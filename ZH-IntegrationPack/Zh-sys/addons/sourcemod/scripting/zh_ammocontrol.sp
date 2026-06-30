#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <datapack>
#include <zh_core>

#include "zh_ammocontrol/dragonbreath.sp"
#include "zh_ammocontrol/shotgun.sp"

#define PLUGIN_VERSION "2.2.0-zh-sys"

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

// --- Enum for weapon types ---
enum WeaponType
{
    WEAPONTYPE_UNKNOWN,
    WEAPONTYPE_SHOTGUN,
    WEAPONTYPE_RIFLE,
    WEAPONTYPE_PISTOL,
    WEAPONTYPE_SNIPER,
    WEAPONTYPE_SMG,
    WEAPONTYPE_HEAVY,
    WEAPONTYPE_MELEE,
    WEAPONTYPE_GRENADE
};

public Plugin myinfo =
{
    name = "ZH-sys Ammunition Control",
    author = "Gemini for ZloyHohol",
    description = "Controls ammunition amounts for weapons, implements custom shotgun reload and dragon breath bullets in ZH-sys architecture.",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    CreateConVar("zh_ammocontrol_version", PLUGIN_VERSION, "ZH Ammunition Control Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

    // General Ammo CVARs
    g_cvAmmo_338mag_max = CreateConVar("zh_ammo_338mag_max", "60", "Max ammo for AWP");
    g_cvAmmo_357sig_max = CreateConVar("zh_ammo_357sig_max", "104", "Max ammo for P228");
    g_cvAmmo_45acp_max = CreateConVar("zh_ammo_45acp_max", "200", "Max ammo for UMP45, Mac10");
    g_cvAmmo_50AE_max = CreateConVar("zh_ammo_50AE_max", "70", "Max ammo for Desert Eagle");
    g_cvAmmo_556mm_box_max = CreateConVar("zh_ammo_556mm_box_max", "400", "Max ammo for M249");
    g_cvAmmo_556mm_max = CreateConVar("zh_ammo_556mm_max", "180", "Max ammo for M4A1, Galil, Famas, SG552");
    g_cvAmmo_57mm_max = CreateConVar("zh_ammo_57mm_max", "200", "Max ammo for P90");
    g_cvAmmo_762mm_max = CreateConVar("zh_ammo_762mm_max", "180", "Max ammo for AK47, G3SG1");
    g_cvAmmo_9mm_max = CreateConVar("zh_ammo_9mm_max", "240", "Max ammo for Glock, USP, MP5, TMP");
    g_cvAmmo_buckshot_max = CreateConVar("zh_ammo_buckshot_max", "64", "Max ammo for M3, XM1014");
    g_cvAmmo_flashbang_max = CreateConVar("zh_ammo_flashbang_max", "4", "Max ammo for Flashbang");
    g_cvAmmo_hegrenade_max = CreateConVar("zh_ammo_hegrenade_max", "4", "Max ammo for HE Grenade");
    g_cvAmmo_smokegrenade_max = CreateConVar("zh_ammo_smokegrenade_max", "4", "Max ammo for Smoke Grenade");

    // Shotgun Reload CVARs
    g_cvWeapon_m3_mag_reload_enabled = CreateConVar("zh_weapon_m3_magazine_reload", "1", "Enable magazine-style reload for M3? 0=No, 1=Yes", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvWeapon_m3_clip = CreateConVar("zh_weapon_m3_clip", "8", "Clip size for M3 Shotgun. 0 = default");
    g_cvWeapon_m3_reload_time = CreateConVar("zh_weapon_m3_reload_time", "5.7", "Reload time in seconds for M3 magazine.", FCVAR_NONE, true, 3.0, true, 6.0);
    g_cvWeapon_xm1014_mag_reload_enabled = CreateConVar("zh_weapon_xm1014_magazine_reload", "1", "Enable magazine-style reload for XM1014? 0=No, 1=Yes", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvWeapon_xm1014_clip = CreateConVar("zh_weapon_xm1014_clip", "20", "Clip size for XM1014 Shotgun. 0 = default");
    g_cvWeapon_xm1014_reload_time = CreateConVar("zh_weapon_xm1014_reload_time", "5.7", "Reload time in seconds for XM1014 magazine.", FCVAR_NONE, true, 3.0, true, 6.0);

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

    // Dragon Breath module setup (creates its own convars and hooks)
    DragonBreath_OnPluginStart();

    AutoExecConfig(true, "zh_ammocontrol", "sourcemod");

    UpdateGameCvrs();

    // Register this module with ZH Core
    ZH_RegisterModule("ammocontrol");
}

public void OnMapStart()
{
    DragonBreath_OnMapStart();
}

public void OnConfigsExecuted()
{
    UpdateGameCvrs();
    DragonBreath_OnConfigsExecuted();
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

public void OnClientPutInServer(int client)
{
    Shotgun_OnClientPutInServer(client);
    DragonBreath_OnClientPutInServer(client);
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

    DragonBreath_OnRoundStart();
}
