#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zh_core>

#define PLUGIN_VERSION "1.0.0"
#define LOG_FILE_NAME "zh_debug.log"

public Plugin myinfo = 
{
    name = "[ZH-sys] Debug Logger",
    author = "ZH-sys development team",
    description = "Comprehensive event logger for debugging all aspects of the game",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    // Создаем файл лога
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    LogToFileEx(logPath, "[ZH-DEBUG] Debug logger plugin loaded at %d", GetTime());
    
    // Регистрируем все необходимые хуки
    HookEvent("player_connect", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("weapon_fire", Event_WeaponFire);
    HookEvent("bullet_impact", Event_BulletImpact);
    HookEvent("player_chat", Event_PlayerChat);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_say", Event_PlayerSay);
    HookEvent("player_info", Event_PlayerInfo);
    HookEvent("player_changename", Event_PlayerChangeName);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("bomb_exploded", Event_BombExploded);
    HookEvent("round_freeze_end", Event_RoundFreezeEnd);
    HookEvent("buytime_ended", Event_BuytimeEnded);
    HookEvent("item_equip", Event_ItemEquip);
    HookEvent("item_pickup", Event_ItemPickup);
    HookEvent("item_remove", Event_ItemRemove);
    
    // Зарегистрируем команды для отладки
    RegAdminCmd("sm_debuglog", Command_DebugLog, ADMFLAG_ROOT, "Enable/disable debug logging");
    
    PrintToServer("[ZH-DEBUG] Debug logger plugin initialized");
}

public void OnPluginEnd()
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    LogToFileEx(logPath, "[ZH-DEBUG] Debug logger plugin unloaded at %d", GetTime());
}

public Action Command_DebugLog(int client, int args)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    if (args == 0)
    {
        ReplyToCommand(client, "[ZH-DEBUG] Usage: sm_debuglog <message>");
        return Plugin_Handled;
    }
    
    char message[256];
    GetCmdArgString(message, sizeof(message));

    char actorName[64];
    if (client > 0 && IsClientInGame(client))
    {
        GetClientName(client, actorName, sizeof(actorName));
    }
    else
    {
        strcopy(actorName, sizeof(actorName), "Console");
    }

    LogToFileEx(logPath, "[ZH-DEBUG] Manual log by %s (ID: %d): %s", actorName, client, message);
    ReplyToCommand(client, "[ZH-DEBUG] Message logged: %s", message);
    
    return Plugin_Handled;
}

public Action Event_PlayerConnect(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    char playerName[64], address[64], networkId[64];
    int userid = event.GetInt("userid");
    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("address", address, sizeof(address));
    event.GetString("networkid", networkId, sizeof(networkId));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player connect: Name=%s, UserID=%d, Address=%s, NetworkID=%s", 
                playerName, userid, address, networkId);
    
    return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    char playerName[64], reason[64];
    int userid = event.GetInt("userid");
    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("reason", reason, sizeof(reason));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player disconnect: Name=%s, UserID=%d, Reason=%s, Duration=%d", 
                playerName, userid, reason, event.GetInt("duration"));
    
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    
    if (client > 0 && IsClientInGame(client))
    {
        char playerName[64];
        GetClientName(client, playerName, sizeof(playerName));
        int team = GetClientTeam(client);
        float pos[3];
        GetClientAbsOrigin(client, pos);
        
        LogToFileEx(logPath, "[ZH-DEBUG] Player spawn: Name=%s, UserID=%d, Team=%d, Position=(%.2f, %.2f, %.2f)", 
                    playerName, userid, team, pos[0], pos[1], pos[2]);
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int victimId = event.GetInt("userid");
    int attackerId = event.GetInt("attacker");
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    int victim = GetClientOfUserId(victimId);
    int attacker = GetClientOfUserId(attackerId);
    
    char victimName[64], attackerName[64];
    if (victim > 0) GetClientName(victim, victimName, sizeof(victimName));
    if (attacker > 0) GetClientName(attacker, attackerName, sizeof(attackerName));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player death: Victim=%s (UserID: %d), Attacker=%s (UserID: %d), Weapon=%s, Distance=%.2f", 
                victimName, victimId, attackerName, attackerId, weapon, event.GetFloat("distance"));
    
    return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    int team = event.GetInt("team");
    int oldteam = event.GetInt("oldteam");
    bool disconnect = event.GetBool("disconnect");
    bool autoteam = event.GetBool("autoteam");
    bool switchteam = event.GetBool("switchteam");
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player team change: Name=%s, UserID=%d, OldTeam=%d, NewTeam=%d, AutoTeam=%s, SwitchTeam=%s, Disconnect=%s", 
                name, userid, oldteam, team, autoteam ? "true" : "false", switchteam ? "true" : "false", disconnect ? "true" : "false");
    
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int victimId = event.GetInt("userid");
    int attackerId = event.GetInt("attacker");
    int health = event.GetInt("health");
    int armor = event.GetInt("armor");
    int dmg_health = event.GetInt("dmg_health");
    int dmg_armor = event.GetInt("dmg_armor");
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    int hitgroup = event.GetInt("hitgroup");
    
    int victim = GetClientOfUserId(victimId);
    int attacker = GetClientOfUserId(attackerId);
    
    char victimName[64], attackerName[64];
    if (victim > 0) GetClientName(victim, victimName, sizeof(victimName));
    if (attacker > 0) GetClientName(attacker, attackerName, sizeof(attackerName));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player hurt: Victim=%s, Attacker=%s, Health=%d, Armor=%d, DmgHealth=%d, DmgArmor=%d, Weapon=%s, HitGroup=%d", 
                victimName, attackerName, health, armor, dmg_health, dmg_armor, weapon, hitgroup);
    
    return Plugin_Continue;
}

public Action Event_WeaponFire(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Weapon fire: Player=%s, UserID=%d, Weapon=%s", name, userid, weapon);
    
    return Plugin_Continue;
}

public Action Event_BulletImpact(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    float x = event.GetFloat("x");
    float y = event.GetFloat("y");
    float z = event.GetFloat("z");
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Bullet impact: Player=%s, UserID=%d, Position=(%.2f, %.2f, %.2f)", name, userid, x, y, z);
    
    return Plugin_Continue;
}

public Action Event_PlayerChat(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char text[256];
    event.GetString("text", text, sizeof(text));
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player chat: Player=%s, UserID=%d, Text=\"%s\"", name, userid, text);
    
    return Plugin_Continue;
}

public Action Event_PlayerSay(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char text[256];
    event.GetString("text", text, sizeof(text));
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player say: Player=%s, UserID=%d, Text=\"%s\"", name, userid, text);
    
    return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    char mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Round start: Map=%s, TimeLimit=%d, FragLimit=%d", 
                mapname, event.GetInt("timelimit"), event.GetInt("fraglimit"));
    
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int winner = event.GetInt("winner");
    char reason[64];
    event.GetString("reason", reason, sizeof(reason));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Round end: WinnerTeam=%d, Reason=%s", winner, reason);
    
    return Plugin_Continue;
}

public Action Event_PlayerInfo(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char name[64];
    event.GetString("name", name, sizeof(name));
    bool bot = event.GetBool("bot");
    bool premium = event.GetBool("premium");
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player info: Name=%s, UserID=%d, IsBot=%s, IsPremium=%s", 
                name, userid, bot ? "true" : "false", premium ? "true" : "false");
    
    return Plugin_Continue;
}

public Action Event_PlayerChangeName(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char oldname[64], newname[64];
    event.GetString("oldname", oldname, sizeof(oldname));
    event.GetString("newname", newname, sizeof(newname));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Player name change: UserID=%d, OldName=%s, NewName=%s", 
                userid, oldname, newname);
    
    return Plugin_Continue;
}

public Action Event_BombPlanted(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    int entityid = event.GetInt("entityid");
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    float pos[3];
    GetEntPropVector(entityid, Prop_Send, "m_vecOrigin", pos);
    
    LogToFileEx(logPath, "[ZH-DEBUG] Bomb planted: Player=%s, UserID=%d, EntityID=%d, Position=(%.2f, %.2f, %.2f)", 
                name, userid, entityid, pos[0], pos[1], pos[2]);
    
    return Plugin_Continue;
}

public Action Event_BombDefused(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    int entityid = event.GetInt("entityid");
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Bomb defused: Player=%s, UserID=%d, EntityID=%d", 
                name, userid, entityid);
    
    return Plugin_Continue;
}

public Action Event_BombExploded(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    int entityid = event.GetInt("entityid");
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Bomb exploded: Player=%s, UserID=%d, EntityID=%d", 
                name, userid, entityid);
    
    return Plugin_Continue;
}

public Action Event_RoundFreezeEnd(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    LogToFileEx(logPath, "[ZH-DEBUG] Round freeze ended");
    
    return Plugin_Continue;
}

public Action Event_BuytimeEnded(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    LogToFileEx(logPath, "[ZH-DEBUG] Buy time ended");
    
    return Plugin_Continue;
}

public Action Event_ItemEquip(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char item[64];
    event.GetString("item", item, sizeof(item));
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Item equipped: Player=%s, UserID=%d, Item=%s", 
                name, userid, item);
    
    return Plugin_Continue;
}

public Action Event_ItemPickup(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char item[64];
    event.GetString("item", item, sizeof(item));
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Item picked up: Player=%s, UserID=%d, Item=%s", 
                name, userid, item);
    
    return Plugin_Continue;
}

public Action Event_ItemRemove(Event event, const char[] eventName, bool dontBroadcast)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    int userid = event.GetInt("userid");
    char item[64];
    event.GetString("item", item, sizeof(item));
    
    int client = GetClientOfUserId(userid);
    char name[64];
    if (client > 0) GetClientName(client, name, sizeof(name));
    
    LogToFileEx(logPath, "[ZH-DEBUG] Item removed: Player=%s, UserID=%d, Item=%s", 
                name, userid, item);
    
    return Plugin_Continue;
}

// Добавим также SDK хуки для более глубокого отслеживания
public int g_iMVPCount[MAXPLAYERS + 1];

public void OnClientPutInServer(int client)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    char name[64];
    GetClientName(client, name, sizeof(name));
    LogToFileEx(logPath, "[ZH-DEBUG] Client put in server: %s (ID: %d)", name, client);
    
    g_iMVPCount[client] = 0;
}

public void OnClientDisconnect(int client)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/ZH-sys/%s", LOG_FILE_NAME);
    
    if (client > 0 && IsClientInGame(client))
    {
        char name[64];
        GetClientName(client, name, sizeof(name));
        LogToFileEx(logPath, "[ZH-DEBUG] Client disconnect start: %s (ID: %d)", name, client);
    }
}
