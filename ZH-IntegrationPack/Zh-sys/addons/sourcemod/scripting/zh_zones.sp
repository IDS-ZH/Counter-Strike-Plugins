#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zh_core>

#define PLUGIN_VERSION "0.1.0-draft"

ConVar g_CvarZonesDebug;
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
    ReplyToCommand(client, g_ZonesLoaded ? "[ZH-Zones] Reloaded." : "[ZH-Zones] No config for this map.");
    return Plugin_Handled;
}

void LoadZones()
{
    g_ZonesLoaded = false;

    char map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));

    char cfgPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, cfgPath, sizeof(cfgPath), "configs/ZH-sys/Modifiers/Zones/%s.cfg", map);

    if (g_CvarZonesDebug != null && g_CvarZonesDebug.BoolValue)
    {
        ZH_LogInfo("Zones: loading %s", cfgPath);
    }

    if (!FileExists(cfgPath))
    {
        ZH_LogWarn("Zones config not found for map: %s", cfgPath);
        return;
    }

    // TODO: parse zones, register areas (buy/spawn/restrict/portal/beacon/hostage_evac), store for other modules (bots, MST).

    g_ZonesLoaded = true;
    ZH_LogInfo("Zones loaded for map %s", map);
}
