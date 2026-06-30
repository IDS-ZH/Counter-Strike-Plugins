// --- Shotgun Reload Logic ---

void Shotgun_OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
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

public Action OnWeaponReload(int weapon)
{
    int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(!ZH_IsValidClient(client, true)) return Plugin_Continue;

    char sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

    bool isM3 = StrEqual(sWeapon, "weapon_m3");
    bool isXm1014 = StrEqual(sWeapon, "weapon_xm1014");

    if ((isM3 && !g_cvWeapon_m3_mag_reload_enabled.BoolValue) || (isXm1014 && !g_cvWeapon_xm1014_mag_reload_enabled.BoolValue)) return Plugin_Continue;

    int clipSize = isM3 ? g_cvWeapon_m3_clip.IntValue : g_cvWeapon_xm1014_clip.IntValue;
    float reloadTime = isM3 ? g_cvWeapon_m3_reload_time.FloatValue : g_cvWeapon_xm1014_reload_time.FloatValue;

    int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(weapon, Prop_Send, "m_iClip1");

    if(clip > 0 && g_bCanReload[client] == false)
        return Plugin_Handled;

    if(ammo <= 0)
        return Plugin_Handled;

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
        pack.WriteCell(isM3 ? 1 : 0); // 1 for M3, 0 for XM1014
        CreateTimer(reloadTime, Timer_Reload, pack);

        DataPack pack2 = new DataPack();
        pack2.WriteCell(GetClientSerial(client));
        pack2.WriteCell(weapon);
        CreateTimer(reloadTime + 0.1, Timer_BlockShoot, pack2);

        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 9999.0);
    }

    if(clip > 0 && clip < clipSize && ammo > 0)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientSerial(client));
        pack.WriteCell(weapon);
        pack.WriteCell(isM3 ? 1 : 0); // 1 for M3, 0 for XM1014
        CreateTimer(reloadTime, Timer_Reload2, pack);

        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 9999.0);
    }
    return Plugin_Handled;
}


public Action Timer_Reload(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientFromSerial(pack.ReadCell());
    int expectedWeapon = pack.ReadCell();
    bool isM3 = pack.ReadCell() == 1;
    delete pack;

    if(!ZH_IsValidClient(client, true)) return Plugin_Stop;

    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;
    if (expectedWeapon != currentWeapon) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));

    if((isM3 && !StrEqual(sWeapon, "weapon_m3")) || (!isM3 && !StrEqual(sWeapon, "weapon_xm1014"))) return Plugin_Stop;

    int clipSize = isM3 ? g_cvWeapon_m3_clip.IntValue : g_cvWeapon_xm1014_clip.IntValue;

    int ammoType = GetEntProp(currentWeapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(currentWeapon, Prop_Send, "m_iClip1");

    if(clip > 0 && g_bCanReload[client] == false)
        return Plugin_Stop;

    if(ammo <= 0)
        return Plugin_Stop;

    if(clip >= clipSize)
        return Plugin_Stop;

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
    int expectedWeapon = pack.ReadCell();
    bool isM3 = pack.ReadCell() == 1;
    delete pack;

    if(!ZH_IsValidClient(client, true)) return Plugin_Stop;

    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;
    if (expectedWeapon != currentWeapon) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));

    if((isM3 && !StrEqual(sWeapon, "weapon_m3")) || (!isM3 && !StrEqual(sWeapon, "weapon_xm1014"))) return Plugin_Stop;

    int clipSize = isM3 ? g_cvWeapon_m3_clip.IntValue : g_cvWeapon_xm1014_clip.IntValue;

    int ammoType = GetEntProp(currentWeapon, Prop_Data, "m_iPrimaryAmmoType");
    int ammo = GetEntProp(client, Prop_Data, "m_iAmmo", 4, ammoType);
    int clip =  GetEntProp(currentWeapon, Prop_Send, "m_iClip1");
    int TempClip = clipSize - clip;

    if(clip > 0 && g_bCanReload[client] == false)
        return Plugin_Stop;

    if(ammo <= 0)
        return Plugin_Stop;

    if(clip >= clipSize)
        return Plugin_Stop;

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
    int expectedWeapon = pack.ReadCell();
    delete pack;

    if(!ZH_IsValidClient(client, true)) return Plugin_Stop;

    int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(currentWeapon) || currentWeapon == -1) return Plugin_Stop;
    if (expectedWeapon != currentWeapon) return Plugin_Stop;

    char sWeapon[32];
    GetEdictClassname(currentWeapon, sWeapon, sizeof(sWeapon));

    if(StrEqual(sWeapon, "weapon_m3") || StrEqual(sWeapon, "weapon_xm1014"))
    {
        SetEntPropFloat(currentWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.0);
    }
    return Plugin_Continue;
}
