#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <connection_problem_fix> 
#include <multicolors>
#include <zh_core>  // ZH_IsValidClient, ZH_RegisterModule

#define PLUGIN_VERSION "2.0-modular"

// Includes
#include "zh_prd/defines.sp"
#include "zh_prd/config.sp"
#include "zh_prd/defaults.sp" // Placeholder if needed
#include "zh_prd/stats.sp"
#include "zh_prd/events.sp"
#include "zh_prd/menu.sp"

public Plugin myinfo =
{
    name = "ZH-sys Player Reward & Discipline",
    author = "Gemini integration",
    description = "Modular PRD system (MVP, TK, Campers)",
    version = PLUGIN_VERSION,
    url = "https://github.com/M-G-E/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core library is required.");
    }

    LoadTranslations("zh_prd.phrases.txt"); // Ensure this file exists!
    
    LoadPrdConfigs();
    OnPluginStart_Events(); // Hook events

    ZH_RegisterModule("prd");
    
    // Commands
    RegAdminCmd("sm_prd", Command_AdminMenu, ADMFLAG_CONFIG, "Open PRD Admin Menu");
    
    // Natives
    CreateNative("PRD_RegisterMVPContribution", Native_RegisterMVPContribution);
}

public void OnClientPutInServer(int client)
{
    g_fJoinTime[client] = GetGameTime();
    g_fLastCamperPenalty[client] = 0.0;
    g_iMvpNativeScore[client] = 0;
    g_bHasVoted[client] = false;
    g_iPrevMvpStars[client] = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iMutualDamage[client][i] = 0;
        g_iMutualDamage[i][client] = 0;
    }
}

public void OnClientDisconnect(int client)
{
    g_iTeamkillAttacker[client] = 0;
    StopAntiCamperCue(client);
    if (g_hCampingTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hCampingTimers[client]);
        g_hCampingTimers[client] = INVALID_HANDLE;
    }
}

public Action Command_AdminMenu(int client, int args)
{
    if (!ZH_IsValidClient(client)) return Plugin_Handled;
    // Todo: Implement main admin menu
    CPrintToChat(client, "PRD Admin Menu not implemented yet.");
    return Plugin_Handled;
}

public any Native_RegisterMVPContribution(Handle plugin, int numParams)
{
    if (numParams < 1) return 0;
    int client = GetNativeCell(1);
    int amount = (numParams >= 2) ? GetNativeCell(2) : 1;
    if (!ZH_IsValidClient(client)) return 0;
    
    g_iMvpNativeScore[client] += amount;
    return g_iMvpNativeScore[client];
}
