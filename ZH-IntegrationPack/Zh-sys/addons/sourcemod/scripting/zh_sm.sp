#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <zh_core>

#define PLUGIN_VERSION "1.0.0-draft"

public Plugin myinfo =
{
    name = "ZH-sys Sound System (SoundManifest Integration)",
    author = "ZloyHohol integration workbench",
    description = "Integration wrapper for SoundManifest system in ZH-sys architecture.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    AutoExecConfig(true, "zh_sm", "sourcemod");

    ZH_RegisterModule("sm");

    // Wrapper only: the actual SoundManifest implementation is expected to be loaded separately.
    LogMessage("[ZH-SM] Wrapper loaded. Ensure SoundManifest.smx is installed/loaded if you need SoundManifest features.");
}

public void OnAllPluginsLoaded()
{
    // Additional initialization after all plugins are loaded
}
