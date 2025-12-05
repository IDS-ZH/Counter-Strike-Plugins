#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zh_core>
#include <zh_mst>

#define PLUGIN_VERSION "0.1.0-draft"

ConVar g_CvarBotBeacons;
ConVar g_CvarBotFlashlight;
ConVar g_CvarBotSkill;

public Plugin myinfo =
{
    name = "ZH-sys Bots (draft)",
    author = "ZloyHohol integration workbench",
    description = "Bot helper placeholder (class assignment + beacons/flashlight).",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY) || !LibraryExists(ZH_MST_LIBRARY))
    {
        SetFailState("zh_core and zh_mst are required.");
    }

    g_CvarBotBeacons = CreateConVar("zh_bot_beacon", "0", "Send bots to beacon position (0=off).");
    g_CvarBotFlashlight = CreateConVar("zh_bot_flashlight", "0", "Force flashlight for bots (0=off).");
    g_CvarBotSkill = CreateConVar("zh_bot_skill", "-1", "Override bot_difficulty (0-3) per spawn; -1 = do not touch.");
    AutoExecConfig(true, "zh_bots", "sourcemod");

    RegAdminCmd("sm_zhbot_beacon", Command_SetBeacon, ADMFLAG_GENERIC, "Place/remove a beacon to attract bots.");

    ZH_RegisterModule("bots");
}

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client))
    {
        ApplyBotSkillOverride();
        // Assign default class for bots; can be overridden by config later.
        MST_SetClientClass(client, 0, "bot-default");
    }
}

public Action Command_SetBeacon(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }
    float pos[3];
    GetClientAbsOrigin(client, pos);
    // TODO: store beacon position and issue bot navigation orders (ccsbot detours).
    ZH_LogInfo("Bot beacon placed at %.1f %.1f %.1f (stub)", pos[0], pos[1], pos[2]);
    return Plugin_Handled;
}

public void OnGameFrame()
{
    if (!g_CvarBotFlashlight.BoolValue)
    {
        return;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsFakeClient(i))
        {
            continue;
        }
        SetEntProp(i, Prop_Send, "m_bNightVisionOn", 1);
        // Note: flashlight toggle may require offsets per game; stub only.
    }
}

void ApplyBotSkillOverride()
{
    int skill = g_CvarBotSkill.IntValue;
    if (skill >= 0 && skill <= 3)
    {
        SetConVarInt(FindConVar("bot_difficulty"), skill);
    }
}
