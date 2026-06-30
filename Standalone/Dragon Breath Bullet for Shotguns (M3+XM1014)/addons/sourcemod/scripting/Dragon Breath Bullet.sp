#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Global Definitions
#define PLUGIN_VERSION "1.0.0"

#define EXPLODE_SOUND   "plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav"

ConVar cvarEnable;
ConVar cvarGuns;
ConVar cvarIgniteTime;
ConVar cvarDamage;
ConVar cvarIsPlayerSound;

int BlockTime4[MAXPLAYERS+1] = {0};

// Functions
public Plugin myinfo =
{
    name = "Dragon Breath Bullet",
    author = "bl4nk,cjsrk, ZloyHohol",
    description = "Specified guns shoot Dragon Breath Bullet + добавлен M3!",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net  , https://github.com/ZloyHohol/Counter-Strike-Plugins"
}


public void OnPluginStart()
{
    CreateConVar("sm_dragonguns_version", PLUGIN_VERSION, "Dragon Breath Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    cvarEnable = CreateConVar("sm_dragonguns_enable", "1", "Enable/Disable the plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    cvarGuns = CreateConVar("sm_dragonguns_guns", "xm1014 m3", "Which guns shoot explosions (separated by spaces)", FCVAR_PLUGIN);
    cvarDamage = CreateConVar("sm_dragonguns_damage", "5.0", "Fire damage on touch, per second (0.0 = no damage)");
    cvarIgniteTime = CreateConVar("sm_dragonguns_ignite_time", "4.0", "Time in seconds for ignite player (require sm_dragonguns_ignite enable)");
    cvarIsPlayerSound = CreateConVar("sm_dragonguns_playsound", "1", "Enable/Disable play sound when player was burn", FCVAR_PLUGIN, true, 0.0, true, 1.0);

    HookEvent("bullet_impact", event_BulletImpact, EventHookMode_Post);
    HookEvent("round_start", RoundStart_Burn, EventHookMode_Post);
    HookEvent("weapon_fire", DragonBreathFire, EventHookMode_Pre);
}


public void OnMapStart()
{
    PrecacheSound(EXPLODE_SOUND, true);
    PrecacheSound("player/damage1.wav");
    PrecacheSound("player/damage2.wav");
    PrecacheSound("player/damage3.wav");
    AddFileToDownloadsTable("sound/plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav");
}


public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage2);  
}


public Action DragonBreathFire(Event event, const char[] name, bool dontBroadcast)
{
    if(!cvarEnable.BoolValue)
        return Plugin_Continue;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsValidClient(client))
        return Plugin_Continue;
    
    char weapon[32], gunsString[255];
    GetClientWeapon(client, weapon, sizeof(weapon));
    ReplaceString(weapon, sizeof(weapon), "weapon_", "");

    cvarGuns.GetString(gunsString, sizeof(gunsString));
    int startidx = 0;
    if (gunsString[0] == '"')
    {
        startidx = 1;

        int len = strlen(gunsString);
        if (gunsString[len-1] == '"')
        {
            gunsString[len-1] = '\0';
        }
    }

    if (StrContains(gunsString[startidx], weapon, false) != -1)
    {       
        float attackerOrigin[3], NewOrigin[3], NewOrigin2[3];
        GetClientEyePosition(client, attackerOrigin);
        float attackerAngles[3];
        GetClientEyeAngles(client, attackerAngles);
        MoveRigh(attackerOrigin, attackerAngles, NewOrigin, 1.8);
        MoveForward(NewOrigin, attackerAngles, NewOrigin2, 50.0);
        NewOrigin2[2] = attackerOrigin[2] - 1.0;
        
        
        int particle = CreateEntityByName("info_particle_system");
        char particleName[64];
        char particleType[] = "AC_muzzle_shotgun_db_jak12";

        if (IsValidEdict(particle))
        {
            TeleportEntity(particle, NewOrigin2, attackerAngles, NULL_VECTOR);
            GetEntPropString(client, Prop_Data, "m_iName", particleName, sizeof(particleName));
            DispatchKeyValue(particle, "targetname", "tf2particle");
            DispatchKeyValue(particle, "parentname", particleName);
            DispatchKeyValue(particle, "effect_name", particleType);
            DispatchSpawn(particle);
            SetVariantString(particleName);
            AcceptEntityInput(particle, "SetParent", particle, particle, 0);
            ActivateEntity(particle);
            AcceptEntityInput(particle, "start");
            CreateTimer(2.5, DeleteParticle, particle);
        }
    }
    return Plugin_Continue;
}


public Action DeleteParticle(Handle timer, any particle)
{
    if (IsValidEntity(particle))
    {
        char classN[64];
        GetEdictClassname(particle, classN, sizeof(classN));
        if (StrEqual(classN, "info_particle_system", false))
        {
            AcceptEntityInput(particle, "Kill");
        }
    }
    return Plugin_Stop;
}


stock void MoveRigh(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
    float vDir[3];
    GetAngleVectors(vAng, NULL_VECTOR, vDir, NULL_VECTOR);
    vReturn[0] = vPos[0];
    vReturn[1] = vPos[1];
    vReturn[2] = vPos[2];
    vReturn[0] += vDir[0] * fDistance;
    vReturn[1] += vDir[1] * fDistance;
} 


stock void MoveForward(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
    float vDir[3];
    GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
    vReturn[0] = vPos[0];
    vReturn[1] = vPos[1];
    vReturn[2] = vPos[2];
    vReturn[0] += vDir[0] * fDistance;
    vReturn[1] += vDir[1] * fDistance;
} 


public Action event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
    if(!cvarEnable.BoolValue)
        return Plugin_Continue;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsValidClient(client))
        return Plugin_Continue;
    
    char weapon[32], gunsString[255];
    GetClientWeapon(client, weapon, sizeof(weapon));
    ReplaceString(weapon, sizeof(weapon), "weapon_", "");

    cvarGuns.GetString(gunsString, sizeof(gunsString));
    int startidx = 0;
    if (gunsString[0] == '"')
    {
        startidx = 1;

        int len = strlen(gunsString);
        if (gunsString[len-1] == '"')
        {
            gunsString[len-1] = '\0';
        }
    }

    if (StrContains(gunsString[startidx], weapon, false) != -1)
    {
        if(BlockTime4[client] == 0)
        {
            float origin[3];
            origin[0] = event.GetFloat("x");
            origin[1] = event.GetFloat("y");
            origin[2] = event.GetFloat("z");
            
            int fire = CreateEntityByName("env_fire");
            
            SetEntPropEnt(fire, Prop_Send, "m_hOwnerEntity", client);
            DispatchKeyValue(fire, "firesize", "50");
            DispatchKeyValue(fire, "health", "1");
            DispatchKeyValue(fire, "firetype", "Normal");

            DispatchKeyValueFloat(fire, "damagescale", cvarDamage.FloatValue);
            DispatchKeyValue(fire, "spawnflags", "256");
            SetVariantString("WaterSurfaceExplosion");
            AcceptEntityInput(fire, "DispatchEffect"); 
            DispatchSpawn(fire);
            TeleportEntity(fire, origin, NULL_VECTOR, NULL_VECTOR);
            AcceptEntityInput(fire, "StartFire");
            TE_SetupSparks(origin, NULL_VECTOR, 5, 2);
            TE_SendToAll();
            EmitAmbientSound(EXPLODE_SOUND, origin, fire, SNDLEVEL_NORMAL, _, 1.0);
            
            BlockTime4[client] = 1;
            CreateTimer(0.1, Timer_RestrictTime4, client);
            
            DataPack pack = new DataPack();
            pack.WriteCell(fire);
            pack.WriteFloat(origin[0]);
            pack.WriteFloat(origin[1]);
            pack.WriteFloat(origin[2]);
            CreateTimer(0.5, Timer_RestrictTime5, pack, TIMER_REPEAT);
        }
        else if(BlockTime4[client] == 1)
        {
            float origin[3];
            origin[0] = event.GetFloat("x");
            origin[1] = event.GetFloat("y");
            origin[2] = event.GetFloat("z");
            TE_SetupSparks(origin, NULL_VECTOR, 5, 2);
            TE_SendToAll();
        }
    }
    return Plugin_Continue;
}

public Action Timer_RestrictTime4(Handle timer, int client)
{
    BlockTime4[client] = 0;
    return Plugin_Stop;
}


public Action Timer_RestrictTime5(Handle timer, DataPack pack)
{
    pack.Reset(); 
    int fire = pack.ReadCell();
    float pos0 = pack.ReadFloat();
    float pos1 = pack.ReadFloat();
    float pos2 = pack.ReadFloat();
    
    static int numPrinted2 = 0;
    if (numPrinted2 >= 1)
    {
        delete pack;
        numPrinted2 = 0;
        return Plugin_Stop;
    }
    float origin[3];
    origin[0] = pos0;
    origin[1] = pos1;
    origin[2] = pos2;
    EmitAmbientSound(EXPLODE_SOUND, origin, fire, SNDLEVEL_NORMAL, _, 1.0);
    numPrinted2++;
    
    return Plugin_Continue;
}


public Action OnTakeDamage2(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (inflictor > 0 && IsValidEdict(inflictor))
    {
        char arma[64];
        GetEdictClassname(inflictor, arma, sizeof(arma));
        if (!strcmp(arma, "env_fire", false))
        {
            int client = GetEntPropEnt(inflictor, Prop_Send, "m_hOwnerEntity");
            if(!IsValidClient(client))
                return Plugin_Continue;
            
            int IsBurn = GetRandomInt(1,3);
            if(IsBurn == 1)
                IgniteEntity(victim, cvarIgniteTime.FloatValue);
            
            if(cvarIsPlayerSound.BoolValue)
            {
                int IsPlaySound = GetRandomInt(1,3);
                if(IsPlaySound > 1)
                {
                    switch(GetRandomInt(1,3))
                    {
                        case 1: EmitSoundToAll("player/damage1.wav", client, SNDCHAN_VOICE, _, _, 1.0);
                        case 2: EmitSoundToAll("player/damage2.wav", client, SNDCHAN_VOICE, _, _, 1.0);
                        case 3: EmitSoundToAll("player/damage3.wav", client, SNDCHAN_VOICE, _, _, 1.0);
                    }
                }
            }       
        }
    }
    return Plugin_Continue;
}


public void RoundStart_Burn(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 0; i <= MAXPLAYERS; i++)
    {
        BlockTime4[i] = 0;
    }
}


public bool IsValidClient(int client) 
{ 
    if ( !( 1 <= client && client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}