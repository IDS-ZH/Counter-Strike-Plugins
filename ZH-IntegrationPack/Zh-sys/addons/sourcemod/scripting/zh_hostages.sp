#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "ZH Hostages Rescue Mission",
    author = "Agent",
    description = "NavMesh based hostages escape",
    version = "1.2",
    url = "https://github.com/ZloyHohol/"
};

native int ZH_NavGetNextPoint(float start[3], float goal[3], float nextPoint[3]);

bool g_CvarImmortal = true;
bool g_bHostageMoving[2048];
float g_RescueZone[3];
bool g_bHasRescueZone = false;
float g_HostageVelocity[2048][3];

public void OnPluginStart()
{
    HookEvent("hostage_follows", Event_HostageFollows);
    HookEvent("hostage_hurt", Event_HostageHurt);
    HookEvent("round_start", Event_RoundStart);
    
    CreateTimer(0.1, Timer_HostageThink, _, TIMER_REPEAT);
    PrintToServer("ZH-Sys Smart Hostage Plugin loaded successfully!");
}

public void OnGameFrame()
{
    for (int i = MaxClients + 1; i < 2048; i++)
    {
        if (g_bHostageMoving[i] && IsValidEntity(i))
        {
            // Apply pushing velocity every frame so the engine doesn't stutter them!
            float vel[3];
            GetEntPropVector(i, Prop_Data, "m_vecVelocity", vel);
            vel[0] = g_HostageVelocity[i][0];
            vel[1] = g_HostageVelocity[i][1];
            // Do not overwrite vel[2] so gravity and stair stepping work naturally!
            SetEntPropVector(i, Prop_Data, "m_vecVelocity", vel);
            SetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", vel);
            
            // CHostage::PhysicsSimulate forces the entity's velocity back to its internal m_vel!
            // We must update m_vel (offset + 20 from m_leader) to prevent jitter and allow native animations.
            // Also, CHostage only processes step-ups (stairs) if m_accel (offset + 32) is non-zero!
            static int leaderOffset = -1;
            if (leaderOffset == -1) leaderOffset = FindSendPropInfo("CHostage", "m_leader");
            if (leaderOffset > 0)
            {
                SetEntDataVector(i, leaderOffset + 20, vel, true);
                
                // m_vel += deltaT * (m_accel - damping * m_vel); damping is 2.0f
                // We set m_accel = vel * 2.0f so the equation balances out perfectly and triggers StepUp!
                float accel[3];
                accel[0] = vel[0] * 2.0;
                accel[1] = vel[1] * 2.0;
                accel[2] = vel[2] * 2.0;
                SetEntDataVector(i, leaderOffset + 32, accel, true);
            }
            
            // Allow native animation blending based on velocity
            // if (GetEntProp(i, Prop_Send, "m_nSequence") != 7)
            // {
            //     SetEntProp(i, Prop_Send, "m_nSequence", 7);
            //     SetEntPropFloat(i, Prop_Send, "m_flPlaybackRate", 1.0);
            // }
        }
    }
}

public void OnMapStart()
{
    FindRescueZone();
}

void FindRescueZone()
{
    int zone = FindEntityByClassname(-1, "func_hostage_rescue");
    if (zone != -1)
    {
        float mins[3], maxs[3], origin[3];
        GetEntPropVector(zone, Prop_Send, "m_vecMins", mins);
        GetEntPropVector(zone, Prop_Send, "m_vecMaxs", maxs);
        GetEntPropVector(zone, Prop_Send, "m_vecOrigin", origin);
        
        g_RescueZone[0] = origin[0] + (mins[0] + maxs[0]) * 0.5;
        g_RescueZone[1] = origin[1] + (mins[1] + maxs[1]) * 0.5;
        g_RescueZone[2] = origin[2] + (mins[2] + maxs[2]) * 0.5;
        g_bHasRescueZone = true;
        PrintToServer("[ZH-sys] Rescue Zone Found at %.1f, %.1f, %.1f", g_RescueZone[0], g_RescueZone[1], g_RescueZone[2]);
    }
    else
    {
        g_bHasRescueZone = false;
        PrintToServer("[ZH-sys] NO RESCUE ZONE FOUND!");
    }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    FindRescueZone();
    int hostage = -1;
    while ((hostage = FindEntityByClassname(hostage, "hostage_entity")) != -1)
    {
        g_bHostageMoving[hostage] = false;
        SetEntityRenderMode(hostage, RENDER_NORMAL);
        SetEntityRenderColor(hostage, 255, 255, 255, 255);
    }
    PrintToServer("[ZH-sys] Hostages are ready for a new round.");
    return Plugin_Continue;
}

public Action Event_HostageFollows(Event event, const char[] name, bool dontBroadcast)
{
    return Plugin_Continue;
}

public Action Event_HostageHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_CvarImmortal) return Plugin_Continue;
    return Plugin_Continue;
}

public Action Timer_HostageThink(Handle timer)
{
    int movingCount = 0;
    int totalCount = 0;
    int hostage = -1;

    while ((hostage = FindEntityByClassname(hostage, "hostage_entity")) != -1)
    {
        totalCount++;

        float hostOrigin[3];
        GetEntPropVector(hostage, Prop_Data, "m_vecOrigin", hostOrigin);

        bool isCaught = false;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
            {
                float tPos[3];
                GetClientAbsOrigin(i, tPos);
                
                if (GetVectorDistance(hostOrigin, tPos) < 600.0)
                {
                    isCaught = true;
                    break;
                }
            }
        }

        if (isCaught)
        {
            float zeroVel[3] = {0.0, 0.0, 0.0};
            SetEntPropVector(hostage, Prop_Data, "m_vecAbsVelocity", zeroVel);
            SetEntPropVector(hostage, Prop_Data, "m_vecBaseVelocity", zeroVel);
            SetEntityRenderMode(hostage, RENDER_TRANSCOLOR);
            SetEntityRenderColor(hostage, 50, 255, 50, 255);
            g_bHostageMoving[hostage] = false;
            SetEntPropEnt(hostage, Prop_Send, "m_leader", -1);
            continue;
        }

        if (GetVectorDistance(hostOrigin, g_RescueZone) < 50.0)
        {
            float zeroVel[3] = {0.0, 0.0, 0.0};
            SetEntPropVector(hostage, Prop_Data, "m_vecAbsVelocity", zeroVel);
            SetEntPropVector(hostage, Prop_Data, "m_vecBaseVelocity", zeroVel);
            SetEntityRenderMode(hostage, RENDER_TRANSCOLOR);
            SetEntityRenderColor(hostage, 50, 50, 255, 255);
            g_bHostageMoving[hostage] = false;
            continue;
        }

        int leader = GetEntPropEnt(hostage, Prop_Send, "m_leader");
        if (leader > 0 && leader <= MaxClients && IsClientInGame(leader) && IsPlayerAlive(leader))
        {
            g_bHostageMoving[hostage] = false;
            SetEntityRenderMode(hostage, RENDER_NORMAL);
            SetEntityRenderColor(hostage, 255, 255, 255, 255);
            continue;
        }


        int breakable = -1;
        while ((breakable = FindEntityByClassname(breakable, "func_breakable")) != -1)
        {
            float breakOrigin[3];
            GetEntPropVector(breakable, Prop_Data, "m_vecOrigin", breakOrigin);
            if (GetVectorDistance(hostOrigin, breakOrigin) < 100.0)
            {
                AcceptEntityInput(breakable, "Break");
            }
        }

        float nextPoint[3];
        if (g_bHasRescueZone)
        {
            int navResult = ZH_NavGetNextPoint(hostOrigin, g_RescueZone, nextPoint);
            if (navResult > 0)
            {
                float dir[3];
                SubtractVectors(nextPoint, hostOrigin, dir);
                dir[2] = 0.0;
                
                float dist = GetVectorLength(dir);
                if (dist > 1.0)
                {
                    NormalizeVector(dir, dir);
                    ScaleVector(dir, 150.0);
                    
                    // Don't push down, let engine handle gravity and stairs
                    if (dir[2] < 0.0) dir[2] = 0.0; 

                    // Set velocity and angle manually
                    float angles[3];
                    GetVectorAngles(dir, angles);
                    angles[0] = 0.0;
                    angles[2] = 0.0;
                    
                    TeleportEntity(hostage, NULL_VECTOR, angles, NULL_VECTOR); // Only update angles here
                    
                    g_HostageVelocity[hostage][0] = dir[0];
                    g_HostageVelocity[hostage][1] = dir[1];
                    g_HostageVelocity[hostage][2] = dir[2];
                    
                    g_bHostageMoving[hostage] = true;
                    movingCount++;
                    SetEntityRenderMode(hostage, RENDER_TRANSCOLOR);
                    SetEntityRenderColor(hostage, 255, 50, 50, 255);
                }
            }
            else
            {
                g_bHostageMoving[hostage] = false;
                static float lastPrint = 0.0;
                if (GetEngineTime() - lastPrint > 2.0)
                {
                    PrintToServer("[ZH-sys] NavGetNextPoint failed for hostage %d", hostage);
                    lastPrint = GetEngineTime();
                }
            }
        }
    }

    if (totalCount > 0)
    {
        PrintCenterTextAll("Заложников: %d | Бегут: %d | Ждут/Сдались: %d", totalCount, movingCount, totalCount - movingCount);
    }

    return Plugin_Continue;
}
