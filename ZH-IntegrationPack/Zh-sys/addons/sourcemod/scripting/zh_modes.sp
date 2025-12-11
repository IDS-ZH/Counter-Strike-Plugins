#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zh_core>

#define PLUGIN_VERSION "0.1.0-draft"

ConVar g_CvarModeDM;
ConVar g_CvarModeTDM;
ConVar g_CvarModeGG;
ConVar g_CvarModeChicken;
ConVar g_CvarModeRevive;

public Plugin myinfo =
{
    name = "ZH-sys Modes (draft)",
    author = "ZloyHohol integration workbench",
    description = "Mode toggles (admin/vote/web stub) with guardrails.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    g_CvarModeDM = CreateConVar("zh_mode_dm", "0", "Enable Deathmatch modifiers (auto respawn etc).");
    g_CvarModeTDM = CreateConVar("zh_mode_tdm", "0", "Enable Team Deathmatch modifiers.");
    g_CvarModeGG = CreateConVar("zh_mode_gg", "0", "Enable GunGame modifiers.");
    g_CvarModeChicken = CreateConVar("zh_mode_chicken", "0", "Enable Chicken Fight mode.");
    g_CvarModeRevive = CreateConVar("zh_mode_revive", "0", "Enable revive module (should be off for DM).");

    AutoExecConfig(true, "zh_modes", "sourcemod");

    RegAdminCmd("sm_mode_set", Command_SetMode, ADMFLAG_GENERIC, "Set mode: sm_mode_set <dm|tdm|gg|chicken|revive> <0/1>");
    // TODO: add player vote commands + webbridge hooks.

    ZH_RegisterModule("modes");
}

public Action Command_SetMode(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "Usage: sm_mode_set <dm|tdm|gg|chicken|revive> <0/1>");
        return Plugin_Handled;
    }

    char mode[16];
    GetCmdArg(1, mode, sizeof(mode));
    char argValue[8];
    GetCmdArg(2, argValue, sizeof(argValue));
    int value = StringToInt(argValue);

    if (StrEqual(mode, "dm", false))
    {
        g_CvarModeDM.SetInt(value);
        if (value == 1)
        {
            g_CvarModeRevive.SetInt(0); // guard: disable revive in DM
        }
    }
    else if (StrEqual(mode, "tdm", false))
    {
        g_CvarModeTDM.SetInt(value);
    }
    else if (StrEqual(mode, "gg", false))
    {
        g_CvarModeGG.SetInt(value);
    }
    else if (StrEqual(mode, "chicken", false))
    {
        g_CvarModeChicken.SetInt(value);
    }
    else if (StrEqual(mode, "revive", false))
    {
        if (g_CvarModeDM.BoolValue && value == 1)
        {
            ReplyToCommand(client, "[ZH] Revive not allowed in DM mode.");
            return Plugin_Handled;
        }
        g_CvarModeRevive.SetInt(value);
    }
    else
    {
        ReplyToCommand(client, "Unknown mode: %s", mode);
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[ZH] %s set to %d", mode, value);

    // Notify other modules about the mode change
    Call_ZHModeChangedForward(mode, value);

    return Plugin_Handled;
}

// Forward for other modules to react to mode changes
void Call_ZHModeChangedForward(const char[] mode, int value)
{
    static GlobalForward hModeChangedForward = null;
    if (hModeChangedForward == null)
    {
        hModeChangedForward = CreateGlobalForward("ZH_ModeChanged", ET_Ignore, Param_String, Param_Cell);
    }

    Call_StartForward(hModeChangedForward);
    Call_PushString(mode);
    Call_PushCell(value);
    Call_Finish();
}
