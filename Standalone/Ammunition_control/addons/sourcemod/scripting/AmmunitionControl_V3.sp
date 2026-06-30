#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <datapack>

#define PLUGIN_VERSION "3.0"
#define EXPLODE_SOUND "plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav"

public Plugin myinfo = 
{
    name = "Ammunition Control V3 (Merged)",
    author = "Gemini & ZloyHohol",
    description = "Контроль патронов, перезарядки и \"Дыхание Дракона\" для дробовиков M3/XM1014(с доступами)",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// --- Config Variables ---
StringMap g_smPermissions;

ConVar g_cvAmmo_338mag_max, g_cvAmmo_357sig_max, g_cvAmmo_45acp_max, g_cvAmmo_50AE_max;
ConVar g_cvAmmo_556mm_box_max, g_cvAmmo_556mm_max, g_cvAmmo_57mm_max, g_cvAmmo_762mm_max;
ConVar g_cvAmmo_9mm_max, g_cvAmmo_buckshot_max, g_cvAmmo_flashbang_max, g_cvAmmo_hegrenade_max, g_cvAmmo_smokegrenade_max;

ConVar g_cvM3_Reload, g_cvM3_Clip, g_cvM3_ReloadTime;
ConVar g_cvXM1014_Reload, g_cvXM1014_Clip, g_cvXM1014_ReloadTime;

ConVar g_cvDB_M3_Enable, g_cvDB_XM1014_Enable;
ConVar g_cvDB_Damage, g_cvDB_IgniteTime, g_cvDB_PlaySound;

// --- State Variables ---
bool g_bCanReload[MAXPLAYERS + 1];
int g_iBlockTimeDB[MAXPLAYERS + 1] = {0};


public void OnPluginStart()
{
    g_smPermissions = new StringMap();

    // General Ammo CVARs
    g_cvAmmo_338mag_max = CreateConVar("sm_ammo_338mag_max", "60", "");
    g_cvAmmo_357sig_max = CreateConVar("sm_ammo_357sig_max", "104", "");
    g_cvAmmo_45acp_max = CreateConVar("sm_ammo_45acp_max", "200", "");
    g_cvAmmo_50AE_max = CreateConVar("sm_ammo_50AE_max", "70", "");
    g_cvAmmo_556mm_box_max = CreateConVar("sm_ammo_556mm_box_max", "400", "");
    g_cvAmmo_556mm_max = CreateConVar("sm_ammo_556mm_max", "180", "");
    g_cvAmmo_57mm_max = CreateConVar("sm_ammo_57mm_max", "200", "");
    g_cvAmmo_762mm_max = CreateConVar("sm_ammo_762mm_max", "180", "");
    g_cvAmmo_9mm_max = CreateConVar("sm_ammo_9mm_max", "240", "");
    g_cvAmmo_buckshot_max = CreateConVar("sm_ammo_buckshot_max", "64", "");
    g_cvAmmo_flashbang_max = CreateConVar("sm_ammo_flashbang_max", "4", "");
    g_cvAmmo_hegrenade_max = CreateConVar("sm_ammo_hegrenade_max", "4", "");
    g_cvAmmo_smokegrenade_max = CreateConVar("sm_ammo_smokegrenade_max", "4", "");

    // Shotgun Reload CVARs
    g_cvM3_Reload = CreateConVar("sm_weapon_m3_magazine_reload", "1", "");
    g_cvM3_Clip = CreateConVar("sm_weapon_m3_clip", "8", "");
    g_cvM3_ReloadTime = CreateConVar("sm_weapon_m3_reload_time", "5.7", "");
    g_cvXM1014_Reload = CreateConVar("sm_weapon_xm1014_magazine_reload", "1", "");
    g_cvXM1014_Clip = CreateConVar("sm_weapon_xm1014_clip", "20", "");
    g_cvXM1014_ReloadTime = CreateConVar("sm_weapon_xm1014_reload_time", "5.7", "");

    // Dragon Breath CVARs
    g_cvDB_M3_Enable = CreateConVar("sm_dragonguns_m3_enable", "1", "");
    g_cvDB_XM1014_Enable = CreateConVar("sm_dragonguns_xm1014_enable", "1", "");
    g_cvDB_Damage = CreateConVar("sm_dragonguns_damage", "5.0", "");
    g_cvDB_IgniteTime = CreateConVar("sm_dragonguns_ignite_time", "4.0", "");
    g_cvDB_PlaySound = CreateConVar("sm_dragonguns_playsound", "1", "");

    // Commands
    RegConsoleCmd("sm_ammo", Command_AmmoMenu, "Открыть меню управления аммуницией");
    RegAdminCmd("sm_ammo_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Перезагрузить конфиг AmmunitionControl_V3");

    // Hooks
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
    HookEvent("bullet_impact", Event_BulletImpact, EventHookMode_Post);
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Pre);

    LoadConfig();
}

public void OnMapStart()
{
    PrecacheSound(EXPLODE_SOUND, true);
    PrecacheSound("player/damage1.wav");
    PrecacheSound("player/damage2.wav");
    PrecacheSound("player/damage3.wav");
    AddFileToDownloadsTable(EXPLODE_SOUND);
}

// -------------------------------------------------------------------------
// Config & Permissions
// -------------------------------------------------------------------------
void LoadConfig()
{
    g_smPermissions.Clear();
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/AmmunitionControl_V3.cfg");

    KeyValues kv = new KeyValues("AmmunitionControl");
    if (!kv.ImportFromFile(path))
    {
        LogError("[Ammo] Cannot load configs/AmmunitionControl_V3.cfg");
        delete kv;
        return;
    }

    if (kv.GotoFirstSubKey())
    {
        do
        {
            char keyName[64];
            kv.GetSectionName(keyName, sizeof(keyName));

            char valStr[64];
            kv.GetString("value", valStr, sizeof(valStr));

            ConVar cv = FindConVar(keyName);
            if (cv != null)
            {
                cv.SetString(valStr);
            }

            char allowRuler[256];
            kv.GetString("Allow_ruler", allowRuler, sizeof(allowRuler));
            g_smPermissions.SetString(keyName, allowRuler);

        } while (kv.GotoNextKey());
    }

    delete kv;
    UpdateGameCvrs();
    PrintToServer("[Ammo] Конфиг и доступы успешно загружены.");
}

public Action Command_ReloadConfig(int client, int args)
{
    LoadConfig();
    if (client > 0 && IsClientInGame(client))
        PrintToChat(client, "\x04[Ammo]\x01 Конфиг перезагружен.");
    return Plugin_Handled;
}

bool HasAccessToSetting(int client, const char[] settingName)
{
    if (GetAdminFlag(GetUserAdmin(client), Admin_Root)) return true;

    char allowRuler[256];
    if (g_smPermissions.GetString(settingName, allowRuler, sizeof(allowRuler)))
    {
        if (allowRuler[0] == '\0') return false; // Only root
        
        char auth[64];
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

        char parts[16][64];
        int count = ExplodeString(allowRuler, " ", parts, sizeof(parts), sizeof(parts[]));
        for (int i = 0; i < count; i++)
        {
            if (parts[i][0] == '\0') continue;
            if (StrEqual(parts[i], auth, false)) return true;

            AdminId admin = GetUserAdmin(client);
            if (admin != INVALID_ADMIN_ID)
            {
                int groupCount = GetAdminGroupCount(admin);
                char groupName[64];
                for (int g = 0; g < groupCount; g++)
                {
                    admin.GetGroup(g, groupName, sizeof(groupName));
                    if (StrEqual(groupName, parts[i], false)) return true;
                }
            }
        }
    }
    return false;
}

// -------------------------------------------------------------------------
// Engine CVAR Updates
// -------------------------------------------------------------------------
void UpdateGameCvrs()
{
    SetConVarInt(FindConVar("ammo_338mag_max"), g_cvAmmo_338mag_max.IntValue);
    SetConVarInt(FindConVar("ammo_357sig_max"), g_cvAmmo_357sig_max.IntValue);
    SetConVarInt(FindConVar("ammo_45acp_max"), g_cvAmmo_45acp_max.IntValue);
    SetConVarInt(FindConVar("ammo_50AE_max"), g_cvAmmo_50AE_max.IntValue);
    SetConVarInt(FindConVar("ammo_556mm_box_max"), g_cvAmmo_556mm_box_max.IntValue);
    SetConVarInt(FindConVar("ammo_556mm_max"), g_cvAmmo_556mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_57mm_max"), g_cvAmmo_57mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_762mm_max"), g_cvAmmo_762mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_9mm_max"), g_cvAmmo_9mm_max.IntValue);
    SetConVarInt(FindConVar("ammo_buckshot_max"), g_cvAmmo_buckshot_max.IntValue);
    SetConVarInt(FindConVar("ammo_flashbang_max"), g_cvAmmo_flashbang_max.IntValue);
    SetConVarInt(FindConVar("ammo_hegrenade_max"), g_cvAmmo_hegrenade_max.IntValue);
    SetConVarInt(FindConVar("ammo_smokegrenade_max"), g_cvAmmo_smokegrenade_max.IntValue);
}

// -------------------------------------------------------------------------
// Menu Logic
// -------------------------------------------------------------------------
public Action Command_AmmoMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;
    ShowAmmoMenu(client);
    return Plugin_Handled;
}

void ShowAmmoMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Ammo);
    menu.SetTitle("Контроль Аммуниции V3\n ");
    
    int itemsAdded = 0;

    if (HasAccessToSetting(client, "sm_weapon_m3_magazine_reload"))
    {
        char buffer[128];
        Format(buffer, sizeof(buffer), "Магазинная перезарядка: M3 [%s]", g_cvM3_Reload.BoolValue ? "Вкл" : "Выкл");
        menu.AddItem("toggle_m3_reload", buffer);
        itemsAdded++;
    }

    if (HasAccessToSetting(client, "sm_weapon_xm1014_magazine_reload"))
    {
        char buffer[128];
        Format(buffer, sizeof(buffer), "Магазинная перезарядка: XM1014 [%s]", g_cvXM1014_Reload.BoolValue ? "Вкл" : "Выкл");
        menu.AddItem("toggle_xm1014_reload", buffer);
        itemsAdded++;
    }

    if (HasAccessToSetting(client, "sm_dragonguns_m3_enable"))
    {
        char buffer[128];
        Format(buffer, sizeof(buffer), "Дыхание Дракона: M3 [%s]", g_cvDB_M3_Enable.BoolValue ? "Вкл" : "Выкл");
        menu.AddItem("toggle_m3_db", buffer);
        itemsAdded++;
    }

    if (HasAccessToSetting(client, "sm_dragonguns_xm1014_enable"))
    {
        char buffer[128];
        Format(buffer, sizeof(buffer), "Дыхание Дракона: XM1014 [%s]", g_cvDB_XM1014_Enable.BoolValue ? "Вкл" : "Выкл");
        menu.AddItem("toggle_xm1014_db", buffer);
        itemsAdded++;
    }

    if (HasAccessToSetting(client, "sm_ammo_buckshot_max")) // proxy for global ammo rights
    {
        menu.AddItem("apply_limits", "Пересчитать лимиты патронов (Reset)");
        itemsAdded++;
    }

    if (itemsAdded == 0)
    {
        PrintToChat(client, "\x02[Ammo]\x01 У вас нет прав для изменения настроек.");
        delete menu;
    }
    else
    {
        menu.Display(client, MENU_TIME_FOREVER);
    }
}

public int MenuHandler_Ammo(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "toggle_m3_reload"))
        {
            g_cvM3_Reload.SetBool(!g_cvM3_Reload.BoolValue);
            ShowAmmoMenu(client);
        }
        else if (StrEqual(info, "toggle_xm1014_reload"))
        {
            g_cvXM1014_Reload.SetBool(!g_cvXM1014_Reload.BoolValue);
            ShowAmmoMenu(client);
        }
        else if (StrEqual(info, "toggle_m3_db"))
        {
            g_cvDB_M3_Enable.SetBool(!g_cvDB_M3_Enable.BoolValue);
            ShowAmmoMenu(client);
        }
        else if (StrEqual(info, "toggle_xm1014_db"))
        {
            g_cvDB_XM1014_Enable.SetBool(!g_cvDB_XM1014_Enable.BoolValue);
            ShowAmmoMenu(client);
        }
        else if (StrEqual(info, "apply_limits"))
        {
            LoadConfig();
            PrintToChat(client, "\x04[Ammo]\x01 Лимиты пересчитаны.");
            ShowAmmoMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// -------------------------------------------------------------------------
// Logic: Shotgun Reloads
// -------------------------------------------------------------------------
public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageDB);  
}

public void OnWeaponEquip(int client, int weapon)
{
    if (!IsValidEdict(weapon)) return;
    char sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

    if (StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
    {
        SDKHook(weapon, SDKHook_ReloadPost, OnWeaponReload);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (buttons & IN_RELOAD)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if (IsValidEdict(weapon))
        {
            char sWeapon[32];
            GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
            if (StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
            {
                g_bCanReload[client] = true;
            }
        }
    }
    return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            g_bCanReload[i] = false;
            g_iBlockTimeDB[i] = 0;
        }
    }
}

public Action OnWeaponReload(int weapon)
{
    int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Continue;

    char sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

    bool isM3 = StrEqual(sWeapon, "weapon_m3");
    bool isXm1014 = StrEqual(sWeapon, "weapon_xm1014");

    if ((isM3 && !g_cvM3_Reload.BoolValue) || (isXm1014 && !g_cvXM1014_Reload.BoolValue)) return Plugin_Continue;

    int clipSize = isM3 ? g_cvM3_Clip.IntValue : g_cvXM1014_Clip.IntValue;
    float reloadTime = isM3 ? g_cvM3_ReloadTime.FloatValue : g_cvXM1014_ReloadTime.FloatValue;

    int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(weapon, Prop_Send, "m_iClip1");

    if(clip > 0 && g_bCanReload[client] == false) return Plugin_Handled;
    if(ammo <= 0) return Plugin_Handled;
    if(clip >= clipSize)
    {
        g_bCanReload[client] = false;
        return Plugin_Handled;
    }

    if(clip == 0 && ammo > 0)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientSerial(client));
        pack.WriteCell(weapon);
        pack.WriteCell(isM3 ? 1 : 0);
        CreateTimer(reloadTime, Timer_Reload, pack);

        DataPack pack2 = new DataPack();
        pack2.WriteCell(GetClientSerial(client));
        pack2.WriteCell(weapon);
        CreateTimer(reloadTime + 0.1, Timer_BlockShoot, pack2);

        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 9999.0);
    }
    else if(clip > 0 && clip < clipSize && ammo > 0)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientSerial(client));
        pack.WriteCell(weapon);
        pack.WriteCell(isM3 ? 1 : 0);
        CreateTimer(reloadTime, Timer_Reload2, pack);

        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 9999.0);
    }
    return Plugin_Handled;
}

public Action Timer_Reload(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    pack.ReadCell(); 
    bool isM3 = pack.ReadCell() == 1;
    delete pack;

    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Stop;
    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));
    if((isM3 && !StrEqual(sWeapon, "weapon_m3")) || (!isM3 && !StrEqual(sWeapon, "weapon_xm1014"))) return Plugin_Stop;

    int clipSize = isM3 ? g_cvM3_Clip.IntValue : g_cvXM1014_Clip.IntValue;
    int ammoType = GetEntProp(currentWeapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(currentWeapon, Prop_Send, "m_iClip1");

    if(clip > 0 && g_bCanReload[client] == false) return Plugin_Stop;
    if(ammo <= 0 || clip >= clipSize) return Plugin_Stop;

    if(ammo >= clipSize)
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", clipSize);
        SetEntProp(client, Prop_Data, "m_iAmmo", ammo - clipSize, 4, ammoType);
    }
    else
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", ammo);
        SetEntProp(client, Prop_Data, "m_iAmmo", 0, 4, ammoType);
    }
    g_bCanReload[client] = false;
    return Plugin_Continue;
}

public Action Timer_Reload2(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    pack.ReadCell(); 
    bool isM3 = pack.ReadCell() == 1;
    delete pack;

    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Stop;
    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));
    if((isM3 && !StrEqual(sWeapon, "weapon_m3")) || (!isM3 && !StrEqual(sWeapon, "weapon_xm1014"))) return Plugin_Stop;

    int clipSize = isM3 ? g_cvM3_Clip.IntValue : g_cvXM1014_Clip.IntValue;
    int ammoType = GetEntProp(currentWeapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(currentWeapon, Prop_Send, "m_iClip1");
    int TempClip = clipSize - clip;

    if(clip > 0 && g_bCanReload[client] == false) return Plugin_Stop;
    if(ammo <= 0 || clip >= clipSize) return Plugin_Stop;

    if(ammo >= TempClip)
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", clipSize);
        SetEntProp(client, Prop_Data, "m_iAmmo", ammo - TempClip, 4, ammoType);
    }
    else
    {
        SetEntProp(currentWeapon, Prop_Send, "m_iClip1", clip + ammo);
        SetEntProp(client, Prop_Data, "m_iAmmo", 0, 4, ammoType);
    }
    SetEntPropFloat(currentWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.0);
    g_bCanReload[client] = false;
    return Plugin_Continue;
}

public Action Timer_BlockShoot(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    delete pack;

    if(client <= 0 || client > MaxClients || !IsPlayerAlive(client)) return Plugin_Stop;
    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));
    if(StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
    {
        SetEntPropFloat(currentWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.0);
    }
    return Plugin_Continue;
}


// -------------------------------------------------------------------------
// Logic: Dragon Breath
// -------------------------------------------------------------------------
public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(client <= 0 || client > MaxClients || !IsClientInGame(client)) return Plugin_Continue;
    
    char weapon[32];
    GetClientWeapon(client, weapon, sizeof(weapon));
    
    bool isM3 = StrEqual(weapon, "weapon_m3");
    bool isXM1014 = StrEqual(weapon, "weapon_xm1014");

    if ( (isM3 && g_cvDB_M3_Enable.BoolValue) || (isXM1014 && g_cvDB_XM1014_Enable.BoolValue) )
    {       
        float attackerOrigin[3], NewOrigin[3], NewOrigin2[3], attackerAngles[3];
        GetClientEyePosition(client, attackerOrigin);
        GetClientEyeAngles(client, attackerAngles);
        MoveRight(attackerOrigin, attackerAngles, NewOrigin, 1.8);
        MoveForward(NewOrigin, attackerAngles, NewOrigin2, 50.0);
        NewOrigin2[2] = attackerOrigin[2] - 1.0;
        
        int particle = CreateEntityByName("info_particle_system");
        char particleName[64];
        if (IsValidEdict(particle))
        {
            TeleportEntity(particle, NewOrigin2, attackerAngles, NULL_VECTOR);
            GetEntPropString(client, Prop_Data, "m_iName", particleName, sizeof(particleName));
            DispatchKeyValue(particle, "targetname", "tf2particle");
            DispatchKeyValue(particle, "parentname", particleName);
            DispatchKeyValue(particle, "effect_name", "AC_muzzle_shotgun_db_jak12");
            DispatchSpawn(particle);
            SetVariantString(particleName);
            AcceptEntityInput(particle, "SetParent", particle, particle, 0);
            ActivateEntity(particle);
            AcceptEntityInput(particle, "start");
            CreateTimer(2.5, Timer_DeleteParticle, particle);
        }
    }
    return Plugin_Continue;
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(client <= 0 || client > MaxClients || !IsClientInGame(client)) return Plugin_Continue;
    
    char weapon[32];
    GetClientWeapon(client, weapon, sizeof(weapon));

    bool isM3 = StrEqual(weapon, "weapon_m3");
    bool isXM1014 = StrEqual(weapon, "weapon_xm1014");

    if ( (isM3 && g_cvDB_M3_Enable.BoolValue) || (isXM1014 && g_cvDB_XM1014_Enable.BoolValue) )
    {
        if(g_iBlockTimeDB[client] == 0)
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
            DispatchKeyValueFloat(fire, "damagescale", g_cvDB_Damage.FloatValue);
            DispatchKeyValue(fire, "spawnflags", "256");
            SetVariantString("WaterSurfaceExplosion");
            AcceptEntityInput(fire, "DispatchEffect"); 
            DispatchSpawn(fire);
            TeleportEntity(fire, origin, NULL_VECTOR, NULL_VECTOR);
            AcceptEntityInput(fire, "StartFire");
            TE_SetupSparks(origin, NULL_VECTOR, 5, 2);
            TE_SendToAll();
            EmitAmbientSound(EXPLODE_SOUND, origin, fire, SNDLEVEL_NORMAL, _, 1.0);
            
            g_iBlockTimeDB[client] = 1;
            CreateTimer(0.1, Timer_RestrictTimeDB, client);
            
            DataPack pack = new DataPack();
            pack.WriteCell(fire);
            pack.WriteFloat(origin[0]);
            pack.WriteFloat(origin[1]);
            pack.WriteFloat(origin[2]);
            CreateTimer(0.5, Timer_SoundDB, pack, TIMER_REPEAT);
        }
        else if(g_iBlockTimeDB[client] == 1)
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

public Action OnTakeDamageDB(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (inflictor > 0 && IsValidEdict(inflictor))
    {
        char classname[64];
        GetEdictClassname(inflictor, classname, sizeof(classname));
        if (StrEqual(classname, "env_fire", false))
        {
            int client = GetEntPropEnt(inflictor, Prop_Send, "m_hOwnerEntity");
            if(client <= 0 || client > MaxClients || !IsClientInGame(client)) return Plugin_Continue;
            
            if(GetRandomInt(1,3) == 1)
            {
                IgniteEntity(victim, g_cvDB_IgniteTime.FloatValue);
            }
            
            if(g_cvDB_PlaySound.BoolValue && GetRandomInt(1,3) > 1)
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
    return Plugin_Continue;
}

// Helpers DB
public Action Timer_DeleteParticle(Handle timer, any particle)
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

public Action Timer_RestrictTimeDB(Handle timer, int client)
{
    g_iBlockTimeDB[client] = 0;
    return Plugin_Stop;
}

public Action Timer_SoundDB(Handle timer, DataPack pack)
{
    pack.Reset(); 
    int fire = pack.ReadCell();
    float pos[3];
    pos[0] = pack.ReadFloat();
    pos[1] = pack.ReadFloat();
    pos[2] = pack.ReadFloat();
    
    static int numPrinted2 = 0;
    if (numPrinted2 >= 1)
    {
        delete pack;
        numPrinted2 = 0;
        return Plugin_Stop;
    }
    EmitAmbientSound(EXPLODE_SOUND, pos, fire, SNDLEVEL_NORMAL, _, 1.0);
    numPrinted2++;
    
    return Plugin_Continue;
}

void MoveRight(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
    float vDir[3];
    GetAngleVectors(vAng, NULL_VECTOR, vDir, NULL_VECTOR);
    vReturn[0] = vPos[0] + (vDir[0] * fDistance);
    vReturn[1] = vPos[1] + (vDir[1] * fDistance);
    vReturn[2] = vPos[2];
} 

void MoveForward(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
    float vDir[3];
    GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
    vReturn[0] = vPos[0] + (vDir[0] * fDistance);
    vReturn[1] = vPos[1] + (vDir[1] * fDistance);
    vReturn[2] = vPos[2];
}
