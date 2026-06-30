#if defined _zh_prd_events_included
 #endinput
#endif
#define _zh_prd_events_included

// --- Hooks ---

public void OnPluginStart_Events()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("round_end", Event_OnRoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
}

// --- Round Logic ---

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundCounter++;
    ResetMvpRoundState(); // Reset regardless
    
    // Snapshot MVP stars
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i)) g_iPrevMvpStars[i] = CS_GetMVPCount(i);
        else g_iPrevMvpStars[i] = 0;
    }

    // Reset counters
    for (int i = 0; i < 5; i++) g_fTeamDamage[i] = 0.0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iTeamKills[i] = 0;
        for (int j = 1; j <= MaxClients; j++) g_iMutualDamage[i][j] = 0;
    }

    return Plugin_Continue;
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    int winner = event.GetInt("winner");
    if (winner == 0)
    {
        ResetMvpRoundState();
        return Plugin_Continue;
    }

    // Check for target save (reason 1) without damage
    int reason = event.GetInt("reason");
    if (reason == 1 && g_fTeamDamage[winner] == 0.0)
    {
        ResetMvpRoundState();
        return Plugin_Continue;
    }

    if (g_hMVPVoteEnable.BoolValue)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(winner);
        CreateTimer(0.1, Timer_FindMvp, pack);
    }

    return Plugin_Continue;
}

public Action Timer_FindMvp(Handle timer, DataPack pack)
{
    pack.Reset();
    int winner = pack.ReadCell();
    g_iPendingMvp = FindMVPByStars(winner);
    g_iPendingWinner = winner;
    
    if (g_iPendingMvp != -1 && ZH_IsValidClient(g_iPendingMvp))
    {
        g_iMVP = g_iPendingMvp;
        StartMvpVote(winner);
    }
    delete pack;
    return Plugin_Continue;
}


// --- Player Logic ---

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!ZH_IsValidClient(client)) return Plugin_Continue;

    g_iCampingTime[client] = 0;
    g_bIsCamping[client] = false;
    StopAntiCamperCue(client);
    g_fLastCamperPenalty[client] = 0.0;

    if (g_hAntiCamperEnable.BoolValue)
    {
        if (g_hCampingTimers[client] != INVALID_HANDLE) KillTimer(g_hCampingTimers[client]);
        g_hCampingTimers[client] = CreateTimer(1.0, Timer_Camping, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));

    if (!ZH_IsValidClient(attacker) || !ZH_IsValidClient(victim) || attacker == victim)
        return Plugin_Continue;

    // Teamkill Check
    if (g_hTeamkillEnable.BoolValue && GetClientTeam(attacker) == GetClientTeam(victim))
    {
         if (IsFakeClient(attacker) && !g_hBotPunishment.BoolValue) return Plugin_Continue;

         // Mutual forgiveness check
         // ... (Logic from legacy)
         
         int punishMode = g_hTeamkillPunishMode.IntValue;
         if (punishMode == 1) // Auto
         {
             ForcePlayerSuicide(attacker);
             CPrintToChatAll("%t", "Teamkill_AutoPunish", attacker, victim);
         }
         else if (punishMode == 2) // Vote
         {
             ShowPunishmentMenu(victim, attacker);
             CPrintToChat(victim, "%t", "Teamkill_VictimNotice", attacker);
         }
    }

    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));
    
    if (ZH_IsValidClient(attacker) && ZH_IsValidClient(victim) && attacker != victim)
    {
        int team = GetClientTeam(attacker);
        if (team >= 2 && team <= 3) g_fTeamDamage[team] += event.GetInt("damage");
    }
    return Plugin_Continue;
}

// --- Anti-Camper ---

public Action Timer_Camping(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!ZH_IsValidClient(client, true)) // CheckAlive=true
    {
        g_hCampingTimers[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    // Logic: distance from last pos
    float vec[3];
    GetClientAbsOrigin(client, vec);
    float dist = GetVectorDistance(vec, g_vLastPosition[client]);
    g_vLastPosition[client] = vec;

    if (dist < 50.0) // Threshold
    {
        g_iCampingTime[client]++;
    }
    else
    {
        g_iCampingTime[client] = 0;
        if (g_bIsCamping[client])
        {
            g_bIsCamping[client] = false;
            StopAntiCamperCue(client);
        }
    }

    if (g_iCampingTime[client] >= g_hAntiCamperTime.IntValue)
    {
        if (!g_bIsCamping[client])
        {
            g_bIsCamping[client] = true;
            CPrintToChat(client, "%T", "Camp_Warning", client);
        }
        
        // Sound cue
        if (g_hAntiCamperSoundEnable.BoolValue && g_bAntiCamperSoundReady)
        {
             // Loop logic handled by helper
             PlayAntiCamperCue(client);
        }

        // Penalty
        float time = GetGameTime();
        if (time - g_fLastCamperPenalty[client] >= g_hAntiCamperPenaltyInterval.FloatValue)
        {
            ApplyCamperPenalty(client);
            g_fLastCamperPenalty[client] = time;
        }
    }

    return Plugin_Continue;
}

void StopAntiCamperCue(int client)
{
    if (g_hBeaconTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hBeaconTimers[client]);
        g_hBeaconTimers[client] = INVALID_HANDLE;
    }
    // StopSound? SourceMod doesn't always handle looping sounds well on stop.
}

void PlayAntiCamperCue(int client)
{
    // Simplified: just emit sound once per tick (not efficient) or rely on loop
    // Legacy used heartbeat_loop.mp3.
    EmitSoundToClient(client, g_sAntiCamperSound, SOUND_from_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
}

void ApplyCamperPenalty(int client)
{
    int mode = g_hAntiCamperPenaltyMode.IntValue;
    if (mode == 0) return; // Warn only

    if (mode == 1) // Slap aka Damage
    {
        int dmg = g_hAntiCamperPenaltyAmount.IntValue;
        SDKHooks_TakeDamage(client, client, client, float(dmg)); // Self damage
        CPrintToChat(client, "%T", "Camp_Penalty_Slap", client, dmg);
    }
    else if (mode == 2) // Ignite
    {
        IgniteEntity(client, g_hAntiCamperIgniteDuration.FloatValue);
        CPrintToChat(client, "%T", "Camp_Penalty_Ignite", client);
    }
}
