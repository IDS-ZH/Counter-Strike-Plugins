#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <zh_core>

#define PLUGIN_VERSION "0.1.0-draft"

ConVar g_CvarImmortal;
ConVar g_CvarNoHostages;

public Plugin myinfo =
{
    name = "ZH-sys Hostage tools (draft)",
    author = "ZloyHohol integration workbench",
    description = "Hostage control placeholder (immortal/disable per-map).",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    g_CvarImmortal = CreateConVar("zh_hostage_immortal", "1", "Prevent hostage death.");
    g_CvarNoHostages = CreateConVar("zh_hostage_disable", "0", "Remove hostages on map start.");
    AutoExecConfig(true, "zh_hostages", "sourcemod");

    HookEvent("hostage_hurt", Event_HostageHurt, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    ZH_RegisterModule("hostages");
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (g_CvarNoHostages.BoolValue)
    {
        RemoveHostages();
    }
}

Action Event_HostageHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_CvarImmortal.BoolValue)
    {
        return Plugin_Continue;
    }

    int hostage = GetEventInt(event, "userid"); // entity userid
    int entity = GetClientOfUserId(hostage);
    if (entity > 0)
    {
        SetEntProp(entity, Prop_Data, "m_iHealth", 100);
    }
    return Plugin_Handled;
}

void RemoveHostages()
{
    int maxEntities = GetMaxEntities();
    for (int i = MaxClients + 1; i <= maxEntities; i++)
    {
        if (!IsValidEntity(i))
        {
            continue;
        }
        char classname[64];
        GetEntityClassname(i, classname, sizeof(classname));
        if (StrEqual(classname, "hostage_entity", false))
        {
            AcceptEntityInput(i, "Kill");
        }
    }
    ZH_LogInfo("Hostages removed (stub).");
}
