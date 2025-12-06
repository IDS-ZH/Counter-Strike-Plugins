#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zh_core>

#define PLUGIN_VERSION "0.1.0-draft"

ConVar g_CvarZonesDebug;
char g_ConfigPath[PLATFORM_MAX_PATH];
bool g_ZonesLoaded;

public Plugin myinfo =
{
    name = "ZH-sys Zones (draft)",
    author = "ZloyHohol integration workbench",
    description = "Unified zone loader/editor placeholder (buy/spawn/restrict/portal).",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    g_CvarZonesDebug = CreateConVar("zh_zones_debug", "0", "Enables extra debug output for zones.");
    AutoExecConfig(true, "zh_zones", "sourcemod");

    ZH_BuildConfigPath(ZHConfig_Custom, "Zones/%s.cfg", g_ConfigPath, sizeof(g_ConfigPath));

    RegAdminCmd("sm_zhzones_reload", Command_ReloadZones, ADMFLAG_CONFIG, "Reload ZH zone definitions for the current map.");

    ZH_RegisterModule("zones");
}

public void OnMapStart()
{
    LoadZones();
}

public Action Command_ReloadZones(int client, int args)
{
    LoadZones();
    ReplyToCommand(client, "[ZH-Zones] Reloaded.");
    return Plugin_Handled;
}

void LoadZones()
{
    char map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));

    char cfgPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, cfgPath, sizeof(cfgPath), "configs/ZH-sys/Zones/%s.cfg", map);

    if (!FileExists(cfgPath))
    {
        ZH_LogWarn("Zones config not found for map: %s", cfgPath);
        return;
    }

    // TODO: parse zones, register areas (buy/spawn/restrict/portal/beacon/hostage_evac), store for other modules (bots, MST).

    g_ZonesLoaded = true;
    ZH_LogInfo("Zones loaded for map %s", map);
}
