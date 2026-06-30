// --- Dragon Breath CVARs ---
ConVar g_cvDragonBreath_Enable;
ConVar g_cvDragonBreath_Guns;
ConVar g_cvDragonBreath_Damage;
ConVar g_cvDragonBreath_IgniteTime;
ConVar g_cvDragonBreath_PlaySound;
ConVar g_cvDragonBreath_Sound;

// --- Dragon Breath state ---
int g_iDragonBlockTime[MAXPLAYERS + 1] = {0};

void DragonBreath_OnPluginStart()
{
    g_cvDragonBreath_Enable = CreateConVar("zh_dragonbreath_enable", "0", "Enable Dragon Breath bullets (0=off, 1=on)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvDragonBreath_Guns = CreateConVar("zh_dragonbreath_guns", "xm1014 m3", "Which guns shoot dragon breath bullets (space separated)", FCVAR_NONE);
    g_cvDragonBreath_Damage = CreateConVar("zh_dragonbreath_damage", "5.0", "Fire damage on touch, per second (0.0 = no damage)");
    g_cvDragonBreath_IgniteTime = CreateConVar("zh_dragonbreath_ignite_time", "4.0", "Time in seconds for ignite player (requires enable)");
    g_cvDragonBreath_PlaySound = CreateConVar("zh_dragonbreath_playsound", "1", "Enable/Disable play sound when player was burned", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvDragonBreath_Sound = CreateConVar("zh_dragonbreath_sound", "plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav", "Sound to play for dragon breath (relative to sound/)", FCVAR_NONE);

    HookEvent("bullet_impact", DragonBreath_OnBulletImpact, EventHookMode_Post);
    HookEvent("weapon_fire", DragonBreathFire, EventHookMode_Pre);

    g_cvDragonBreath_Enable.AddChangeHook(DragonBreath_OnCvarChanged);
    g_cvDragonBreath_Sound.AddChangeHook(DragonBreath_OnCvarChanged);
}

void DragonBreath_OnMapStart()
{
    DragonBreath_MaybePrecache();
}

void DragonBreath_OnConfigsExecuted()
{
    DragonBreath_MaybePrecache();
}

void DragonBreath_OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, DragonBreath_OnTakeDamage);
}

void DragonBreath_OnRoundStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iDragonBlockTime[i] = 0;
    }
}

void DragonBreath_OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    if (cvar == g_cvDragonBreath_Enable && StringToInt(newValue) == 1)
    {
        DragonBreath_MaybePrecache();
    }
}

void DragonBreath_MaybePrecache()
{
    if (!g_cvDragonBreath_Enable.BoolValue)
        return;

    char soundPath[PLATFORM_MAX_PATH];
    DragonBreath_GetSoundPath(soundPath, sizeof(soundPath));

    PrecacheSound(soundPath, true);
    PrecacheSound("player/damage1.wav");
    PrecacheSound("player/damage2.wav");
    PrecacheSound("player/damage3.wav");
    char downloadPath[PLATFORM_MAX_PATH];
    Format(downloadPath, sizeof(downloadPath), "sound/%s", soundPath);
    AddFileToDownloadsTable(downloadPath);
}

public void DragonBreathFire(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_cvDragonBreath_Enable.BoolValue)
        return;

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(!ZH_IsValidClient(client))
        return;

    char weapon[32], gunsString[255];
    GetClientWeapon(client, weapon, sizeof(weapon));
    ReplaceString(weapon, sizeof(weapon), "weapon_", "");

    g_cvDragonBreath_Guns.GetString(gunsString, sizeof(gunsString));
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
            CreateTimer(2.5, DragonBreath_DeleteParticle, particle);
        }
    }
}

public Action DragonBreath_DeleteParticle(Handle timer, any particle)
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
    return Plugin_Continue;
}

// Calculate right coordinate of a distance from the position
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

// Calculate forward coordinate of a distance from the position
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

public void DragonBreath_OnBulletImpact(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_cvDragonBreath_Enable.BoolValue)
        return;

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(!ZH_IsValidClient(client))
        return;

    char weapon[32], gunsString[255];
    GetClientWeapon(client, weapon, sizeof(weapon));
    ReplaceString(weapon, sizeof(weapon), "weapon_", "");

    g_cvDragonBreath_Guns.GetString(gunsString, sizeof(gunsString));
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
        if(g_iDragonBlockTime[client] == 0)
        {
            float origin[3];
            origin[0] = GetEventFloat(event, "x");
            origin[1] = GetEventFloat(event, "y");
            origin[2] = GetEventFloat(event, "z");

            int fire = CreateEntityByName("env_fire");

            SetEntPropEnt(fire, Prop_Send, "m_hOwnerEntity", client);
            DispatchKeyValue(fire, "firesize", "50");
            DispatchKeyValue(fire, "health", "1");
            DispatchKeyValue(fire, "firetype", "Normal");

            DispatchKeyValueFloat(fire, "damagescale", g_cvDragonBreath_Damage.FloatValue);
            DispatchKeyValue(fire, "spawnflags", "256");  //Used to control flags
            SetVariantString("WaterSurfaceExplosion");
            AcceptEntityInput(fire, "DispatchEffect");
            DispatchSpawn(fire);
            TeleportEntity(fire, origin, NULL_VECTOR, NULL_VECTOR);
            AcceptEntityInput(fire, "StartFire");
            TE_SetupSparks(origin, NULL_VECTOR, 5, 2);
            TE_SendToAll();
            char soundPath[PLATFORM_MAX_PATH];
            DragonBreath_GetSoundPath(soundPath, sizeof(soundPath));
            EmitAmbientSound( soundPath, origin, fire, SNDLEVEL_NORMAL, _ , 1.0 );

            g_iDragonBlockTime[client] = 1;
            CreateTimer(0.1, DragonBreath_Timer_RestrictTime, client);
            DataPack pack = new DataPack();
            pack.WriteCell(fire);
            pack.WriteFloat(origin[0]);
            pack.WriteFloat(origin[1]);
            pack.WriteFloat(origin[2]);
            CreateTimer(0.5, DragonBreath_Timer_RestrictTimeLoop, pack, TIMER_REPEAT);
        }
        else if(g_iDragonBlockTime[client] == 1)
        {
            float origin[3];
            origin[0] = GetEventFloat(event, "x");
            origin[1] = GetEventFloat(event, "y");
            origin[2] = GetEventFloat(event, "z");
            TE_SetupSparks(origin, NULL_VECTOR, 5, 2);
            TE_SendToAll();
        }
    }
}

public Action DragonBreath_Timer_RestrictTime(Handle timer, int client)
{
    g_iDragonBlockTime[client] = 0;
    return Plugin_Continue;
}

public Action DragonBreath_Timer_RestrictTimeLoop(Handle timer, DataPack pack)
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
    char soundPath[PLATFORM_MAX_PATH];
    DragonBreath_GetSoundPath(soundPath, sizeof(soundPath));
    EmitAmbientSound( soundPath, origin, fire, SNDLEVEL_NORMAL, _ , 1.0 );
    numPrinted2++;
    return Plugin_Continue;
}

public Action DragonBreath_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if(!g_cvDragonBreath_Enable.BoolValue)
        return Plugin_Continue;

    char arma[64];
    GetEdictClassname(inflictor, arma, sizeof(arma));
    if (!StrEqual(arma, "env_fire", false))
        return Plugin_Continue;

    int client = GetEntPropEnt(inflictor, Prop_Send, "m_hOwnerEntity");
    if(!ZH_IsValidClient(client))
        return Plugin_Continue;

    // Ignite the victim
    int isBurn = GetRandomInt(1,3);
    if(isBurn == 1)
        IgniteEntity(victim, g_cvDragonBreath_IgniteTime.FloatValue);

    if(g_cvDragonBreath_PlaySound.BoolValue)
    {
        int isPlaySound = GetRandomInt(1,3);
        if(isPlaySound > 1)
        {
            char soundFile[64];
            switch(GetRandomInt(1,3))
            {
                case 1: strcopy(soundFile, sizeof(soundFile), "player/damage1.wav");
                case 2: strcopy(soundFile, sizeof(soundFile), "player/damage2.wav");
                case 3: strcopy(soundFile, sizeof(soundFile), "player/damage3.wav");
            }
            EmitSoundToAll(soundFile, client, SNDCHAN_VOICE, _, _, 1.0);
        }
    }
    return Plugin_Continue;
}

// Pulls configured sound path, falls back to default if empty
void DragonBreath_GetSoundPath(char[] buffer, int maxlen)
{
    g_cvDragonBreath_Sound.GetString(buffer, maxlen);
    if (buffer[0] == '\0')
    {
        strcopy(buffer, maxlen, "plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav");
    }
}
