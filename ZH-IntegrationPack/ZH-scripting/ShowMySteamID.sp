#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Show My SteamID",
    author = "ZloyHohol",
    description = "Shows a player their SteamID.",
    version = "1.5",
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// !mysteamid /mysteamid - command to show player's SteamID in chat
public void OnPluginStart()
{
    RegConsoleCmd("sm_mysteamid", Command_MySteamID, "Shows your SteamID");
    RegConsoleCmd("sm_steamid", Command_MySteamID, "Shows your SteamID");
}

public Action Command_MySteamID(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("This command can only be used by a player.");
        return Plugin_Handled;
    }

    char steamid[64];
    GetClientAuthString(client, steamid, sizeof(steamid)); // Using GetClientAuthString to match example

    PrintToChat(client, "\x04[SM] \x01Привет \x03%N \x01, твой SteamID - \x03%s", client, steamid);

    return Plugin_Handled;
}