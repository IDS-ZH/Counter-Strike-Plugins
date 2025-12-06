#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <zh_core>

public Plugin myinfo =
{
    name = "ZH-sys Show My SteamID",
    author = "ZloyHohol",
    description = "Shows a player their SteamID in ZH-sys architecture.",
    version = "1.6.0-zh-sys",
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// !mysteamid /mysteamid - command to show player's SteamID in chat
public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    RegConsoleCmd("sm_mysteamid", Command_MySteamID, "Shows your SteamID");
    RegConsoleCmd("sm_steamid", Command_MySteamID, "Shows your SteamID");

    AutoExecConfig(true, "zh_steamid", "sourcemod");

    // Register this module with ZH Core
    ZH_RegisterModule("steamid");
}

public Action Command_MySteamID(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "This command can only be used by a player.");
        return Plugin_Handled;
    }

    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    CPrintToChat(client, "%t", "ZH_SteamID_Message", client, steamid);

    return Plugin_Handled;
}