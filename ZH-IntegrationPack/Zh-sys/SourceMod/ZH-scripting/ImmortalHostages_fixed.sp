/**
 * ImmortalHostages_fixed.sp
 *
 * Safe, reviewed rewrite of the provided 'ImmortalHostages.sp'.
 * Adds selectable modes and fixes several safety/logic issues.
 *
 * Modes (sm_hostages_mode):
 * 0 = normal (hostages take damage normally)
 * 1 = vulnerable_to_T (only Terrorists can damage hostages)
 * 2 = vulnerable_to_CT (only Counter-Terrorists can damage hostages)
 * 3 = invulnerable (hostages take no damage from any source)
 *
 * Notes:
 * - This file is intended as a safe replacement for an untrusted source.
 * - It avoids executing untrusted code and limits surface area.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>

new Handle:g_hHostages; // dynamic array of hooked hostage entity indexes
new Handle:g_hCvarMode;
new Handle:g_hCvarDebug;

public Plugin:myinfo = 
{
    name = "ImmortalHostages (fixed)",
    author = "By Copilot (reviewed)",
    description = "Safe hostages damage control with selectable modes",
    version = "0.1",
    url = ""
};

public void OnPluginStart()
{
    g_hHostages = CreateArray();
    g_hCvarMode = CreateConVar("sm_hostages_mode", "3", "Hostage damage mode: 0=normal,1=vuln_T,2=vuln_CT,3=invulnerable", FCVAR_PLUGIN, true, 0.0, true, 3.0);
    g_hCvarDebug = CreateConVar("sm_hostages_debug", "0", "Enable debug prints (0/1)", FCVAR_PLUGIN, true, 0.0, true, 1.0);

    // Create a default config file (autoexec) to store defaults for admins
    AutoExecConfig(true, "immortal_hostages");

    // Register an admin command to change mode at runtime
    RegAdminCmd("sm_hostages_setmode", Command_SetHostagesMode, ADMFLAG_GENERIC, "Usage: sm_hostages_setmode <0-3> - Set hostage damage mode");

    // Hook round start to (re)hook hostages present on the map
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    // Initial scan
    ScanAndHookHostages();

    // Periodic rescan to catch dynamically spawned hostages (every 5 seconds)
    CreateTimer(5.0, Timer_RescanHostages, _, TIMER_REPEAT);
    PrintToServer("[ImmortalHostages_fixed] Loaded. Mode: %d", GetConVarInt(g_hCvarMode));
}

public void OnMapEnd()
{
    // Unhook everything and clear
    UnhookAllHostages();
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    ScanAndHookHostages();
    return Plugin_Continue;
}

// Helper to scan for hostage_entity ents and SDKHook them
stock void ScanAndHookHostages()
{
    // Clear previous list safely
    UnhookAllHostages();

    int maxEnts = GetMaxEntities();
    for (int ent = 1; ent <= maxEnts; ent++)
    {
        if (!IsValidEdict(ent)) continue;
        char cname[64];
        GetEdictClassname(ent, cname, sizeof(cname));
        if (!StrEqual(cname, "hostage_entity")) continue;

        SDKHook(ent, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        PushArrayCell(g_hHostages, ent);
        if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] Hooked hostage ent %d", ent);
    }
    if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] Scan complete, total hooked: %d", GetArraySize(g_hHostages));
}

public Action:Timer_RescanHostages(Handle:timer, any:data)
{
    ScanAndHookHostages();
    return Plugin_Continue;
}

stock void UnhookAllHostages()
{
    if (g_hHostages == INVALID_HANDLE) g_hHostages = CreateArray();
    int size = GetArraySize(g_hHostages);
    for (int i = 0; i < size; i++)
    {
        int ent = GetArrayCell(g_hHostages, i);
        if (IsValidEdict(ent))
        {
            SDKUnhook(ent, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
            if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] Unhooked hostage ent %d", ent);
        }
    }
    ClearArray(g_hHostages);
}

// Note: we rely on map_start and round_start events to rescan hostages.
// If dynamic entities require catching, we can add a short repeating timer to rescan periodically.

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    // Always validate
    if (!IsValidEdict(victim)) return Plugin_Continue;

    char cname[64];
    GetEdictClassname(victim, cname, sizeof(cname));
    if (!StrEqual(cname, "hostage_entity")) return Plugin_Continue;

    int mode = GetConVarInt(g_hCvarMode);

    // Mode 0: normal
    if (mode == 0)
    {
        if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] mode=0 allow victim=%d attacker=%d dmg=%f", victim, attacker, damage);
        return Plugin_Continue;
    }

    // Mode 3: invulnerable to everything
    if (mode == 3)
    {
        if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] mode=3 block victim=%d attacker=%d dmg=%f", victim, attacker, damage);
        damage = 0.0;
        return Plugin_Handled; // block damage
    }

    // Determine if attacker is a connected client
    bool attackerIsPlayer = false;
    int client = -1;
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
    {
        attackerIsPlayer = true;
        client = attacker;
    }

    if (mode == 1)
    {
        // vulnerable only to Terrorists
        if (attackerIsPlayer && GetClientTeam(client) == 2)
        {
            if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] mode=1 allow (T) victim=%d attacker=%d dmg=%f", victim, attacker, damage);
            return Plugin_Continue; // allow damage
        }
        if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] mode=1 block victim=%d attacker=%d dmg=%f", victim, attacker, damage);
        damage = 0.0;
        return Plugin_Handled; // block other sources
    }

    if (mode == 2)
    {
        // vulnerable only to Counter-Terrorists
        if (attackerIsPlayer && GetClientTeam(client) == 3)
        {
            if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] mode=2 allow (CT) victim=%d attacker=%d dmg=%f", victim, attacker, damage);
            return Plugin_Continue;
        }
        if (GetConVarInt(g_hCvarDebug)) PrintToServer("[ImmortalHostages_fixed] mode=2 block victim=%d attacker=%d dmg=%f", victim, attacker, damage);
        damage = 0.0;
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:Command_SetHostagesMode(int client, int args)
{
    if (args < 1)
    {
        if (client > 0)
            ReplyToCommand(client, "Usage: sm_hostages_setmode <0-3>");
        else
            PrintToServer("Usage: sm_hostages_setmode <0-3>");
        return Plugin_Handled;
    }

    char arg[8];
    GetCmdArg(1, arg, sizeof(arg));
    int mode = StringToInt(arg);
    if (mode < 0 || mode > 3)
    {
        if (client > 0)
            ReplyToCommand(client, "Mode must be 0..3");
        else
            PrintToServer("Mode must be 0..3");
        return Plugin_Handled;
    }

    SetConVarInt(g_hCvarMode, mode);
    if (client > 0)
        ReplyToCommand(client, "Hostages mode set to %d", mode);
    else
        PrintToServer("[ImmortalHostages_fixed] Hostages mode set to %d", mode);

    // Re-scan to ensure hooks reflect any mode changes
    ScanAndHookHostages();
    return Plugin_Handled;
}

public void OnPluginEnd()
{
    UnhookAllHostages();
}
