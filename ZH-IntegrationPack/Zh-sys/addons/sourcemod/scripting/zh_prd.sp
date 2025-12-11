#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <zh_core>

#define PLUGIN_VERSION "1.0.0-draft"

public Plugin myinfo =
{
    name = "ZH-sys Player Reward and Discipline System (PRD Integration)",
    author = "ZloyHohol integration workbench",
    description = "Integration wrapper for Player Reward and Discipline system in ZH-sys architecture.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    AutoExecConfig(true, "zh_prd", "sourcemod");

    ZH_RegisterModule("prd");

    // Attempt to load the PRD plugin if available
    if (LoadPlugin("PRD.smx", true, true))
    {
        LogMessage("[ZH-PRD] Successfully loaded PRD plugin");
    }
    else
    {
        LogMessage("[ZH-PRD] PRD plugin not found, will depend on external load");
    }
}

public void OnAllPluginsLoaded()
{
    // Additional initialization after all plugins are loaded
}