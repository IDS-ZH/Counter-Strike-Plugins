
// Обновленная функция DefineOrUpdateClass с поддержкой типа скина
void DefineOrUpdateClass(int classId, const char[] name, const char[] model, const char[] sound, int flags, int teamMask = TEAMMASK_ANY, int skinType = SkinType_Regular)
{
    // Найти или создать запись в ArrayList
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        idx = g_ClassDefs.Push(0);
        g_ClassDefs.Set(idx, classId, ClassId);
        g_ClassDefs.Set(idx, 0, ClassAbilityFlags);  // default flags
        g_ClassDefs.Set(idx, TEAMMASK_ANY, ClassTeamMask);  // default team mask
        g_ClassDefs.Set(idx, SkinType_Regular, ClassSkinType);  // default skin type
    }

    g_ClassDefs.Set(idx, flags, ClassAbilityFlags);
    g_ClassDefs.Set(idx, teamMask, ClassTeamMask);
    g_ClassDefs.Set(idx, skinType, ClassSkinType);

    SetStringValueForClass(g_ClassNames, classId, name);
    SetStringValueForClass(g_ClassModels, classId, model);
    SetStringValueForClass(g_ClassSounds, classId, sound);

    if (model[0] != '\0')
    {
        PushUniqueString(g_DownloadModels, model);
    }
    if (sound[0] != '\0')
    {
        PushUniqueString(g_DownloadSounds, sound);
    }

    if (g_CvarMstDebug != null && g_CvarMstDebug.BoolValue)
    {
        ZH_LogInfo("Defined class %d (%s) flags=%d model=%s sound=%s skinType=%d", classId, name, flags, model, sound, skinType);
    }
}

bool SetClientClassInternal(int client, int classId, const char[] reason)
{
    if (!ZH_IsValidClient(client))
    {
        return false;
    }

    int oldClass = g_ClientClass[client];
    g_ClientClass[client] = classId;

    if (g_fwdClassChanged != null)
    {
        Call_StartForward(g_fwdClassChanged);
        Call_PushCell(client);
        Call_PushCell(classId);
        Call_PushCell(oldClass);
        Call_PushString(reason);
        Call_Finish();
    }

    if (g_CvarMstDebug != null && g_CvarMstDebug.BoolValue)
    {
        ZH_LogInfo("Client %d switched class %d -> %d (%s)", client, oldClass, classId, reason);
    }

    return true;
}

void ResetClientClasses()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_ClientClass[i] = -1;
        g_ClientViewModels[i][0] = -1;
        g_ClientViewModels[i][1] = -1;
        
        g_ClientTpMode[i] = ThirdPersonMode_FirstPerson;
        if (g_FreezeEndTimer[i] != null)
        {
            KillTimer(g_FreezeEndTimer[i]);
            g_FreezeEndTimer[i] = null;
        }
    }
}

int GetAbilityFlags(int classId)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        return 0;
    }

    return g_ClassDefs.Get(idx, ClassAbilityFlags);
}

int GetTeamMaskForClass(int classId)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        return TEAMMASK_ANY;
    }

    return g_ClassDefs.Get(idx, ClassTeamMask);
}

int GetSkinTypeForClass(int classId)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        return SkinType_Regular;
    }

    return g_ClassDefs.Get(idx, ClassSkinType);
}

void GetGloveInfoForClass(int classId, char[] gloveModel, int maxlen, int& gloveSkin)
{
    char classIdStr[16];
    Format(classIdStr, sizeof(classIdStr), "%d", classId);

    bool hasModel = g_ClassGloveModels != null && g_ClassGloveModels.GetString(classIdStr, gloveModel, maxlen);
    bool hasSkin = g_ClassGloveSkins != null && g_ClassGloveSkins.GetValue(classIdStr, gloveSkin);

    if (!hasModel)
    {
        gloveModel[0] = '\0';
    }
    if (!hasSkin)
    {
        gloveSkin = 0;
    }
}

int FindClassIndex(int classId)
{
    for (int i = 0; i < g_ClassDefs.Length; i++)
    {
        if (g_ClassDefs.Get(i, ClassId) == classId)
        {
            return i;
        }
    }
    return -1;
}

void SetStringValueForClass(StringMap map, int classId, const char[] value)
{
    char key[16];
    Format(key, sizeof(key), "%d", classId);
    map.SetString(key, value);
}

bool GetStringValueForClass(StringMap map, int classId, char[] buffer, int maxlen)
{
    char key[16];
    Format(key, sizeof(key), "%d", classId);
    return map.GetString(key, buffer, maxlen);
}

Action Timer_AssignDefaultClass(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!ZH_IsValidClient(client))
    {
        return Plugin_Stop;
    }

    if (!g_ConfigsLoaded || !g_AutoAssign || (g_CvarMstMode != null && g_CvarMstMode.IntValue == 0))
    {
        return Plugin_Stop;
    }

    int team = GetClientTeam(client);
    int desired = GetDefaultClassForTeam(team);
    if (desired == -1 || !IsClassAllowedForTeam(desired, team))
    {
        return Plugin_Stop;
    }

    SetClientClassInternal(client, desired, "auto-assign");
    UpdateGlovesForClient(client);
    SetClientViewMode(client, g_ClientTpMode[client]); // Устанавливаем вид от третьего лица при автоприсвоении класса
    return Plugin_Stop;
}

int GetDefaultClassForTeam(int team)
{
    if (team == 2) return g_DefaultClassT;
    if (team == 3) return g_DefaultClassCT;
    return g_DefaultClassSpec;
}

bool IsClassAllowedForTeam(int classId, int team)
{
    int teamMask = GetTeamMaskForClass(classId);
    switch (team)
    {
        case 2: return (teamMask & TEAMMASK_T) != 0;
        case 3: return (teamMask & TEAMMASK_CT) != 0;
        default: return true;
    }
}

// --- Class System Helpers ---

int ParseAbilityFlags(const char[] flagsText, int defaultFlags)
{
    int flags = defaultFlags;

    char buffer[128];
    char parts[16][16];
    strcopy(buffer, sizeof(buffer), flagsText);
    int count = ExplodeString(buffer, "|", parts, sizeof(parts), sizeof(parts[]));

    for (int i = 0; i < count; i++)
    {
        TrimString(parts[i]);
        if (StrEqual(parts[i], "revive", false))
        {
            flags |= view_as<int>(MSTAbility_Revive);
        }
        else if (StrEqual(parts[i], "turret", false))
        {
            flags |= view_as<int>(MSTAbility_Turret);
        }
        else if (StrEqual(parts[i], "barricade", false))
        {
            flags |= view_as<int>(MSTAbility_Barricade);
        }
        else if (StrEqual(parts[i], "grenadelauncher", false))
        {
            flags |= view_as<int>(MSTAbility_GrenadeLauncher);
        }
        else if (StrEqual(parts[i], "specialvision", false))
        {
            flags |= view_as<int>(MSTAbility_SpecialVision);
        }
        else if (StrEqual(parts[i], "flashlightforce", false))
        {
            flags |= view_as<int>(MSTAbility_FlashlightForce);
        }
        else if (StrEqual(parts[i], "speedscout", false))
        {
            flags |= view_as<int>(MSTAbility_SpeedScout);
        }
        else if (StrEqual(parts[i], "shieldcarrier", false))
        {
            flags |= view_as<int>(MSTAbility_ShieldCarrier);
        }
        else if (StrEqual(parts[i], "gasimmunity", false))
        {
            flags |= view_as<int>(MSTAbility_GasImmunity);
        }
        else if (StrEqual(parts[i], "engineertoolset", false))
        {
            flags |= view_as<int>(MSTAbility_EngineerToolset);
        }
    }

    return flags;
}

int ParseTeamMask(const char[] teamText, int defaultMask)
{
    int mask = defaultMask;

    char buffer[64];
    char parts[8][8];
    strcopy(buffer, sizeof(buffer), teamText);
    int count = ExplodeString(buffer, "|", parts, sizeof(parts), sizeof(parts[]));

    for (int i = 0; i < count; i++)
    {
        TrimString(parts[i]);
        if (StrEqual(parts[i], "t", false))
        {
            mask |= TEAMMASK_T;
            mask &= ~TEAMMASK_CT;  // Remove "any" if specific team specified.
        }
        else if (StrEqual(parts[i], "ct", false))
        {
            mask |= TEAMMASK_CT;
            mask &= ~TEAMMASK_T;  // Remove "any" if specific team specified.
        }
        else if (StrEqual(parts[i], "any", false))
        {
            mask = TEAMMASK_ANY;
        }
    }

    return mask;
}

int ParseSkinType(const char[] skinTypeStr)
{
    if (StrEqual(skinTypeStr, "female", false))
        return SkinType_Female;
    else if (StrEqual(skinTypeStr, "robot", false))
        return SkinType_Robot;
    else if (StrEqual(skinTypeStr, "longsleeve", false))
        return SkinType_LongSleeve;
    else if (StrEqual(skinTypeStr, "animal", false))
        return SkinType_Animal;
    else if (StrEqual(skinTypeStr, "monster", false))
        return SkinType_Monster;
    else // "regular" or default
        return SkinType_Regular;
}

void ClearClassData()
{
    if (g_ClassDefs != null)
    {
        g_ClassDefs.Clear();
    }
    if (g_ClassNames != null)
    {
        g_ClassNames.Clear();
    }
    if (g_ClassModels != null)
    {
        g_ClassModels.Clear();
    }
    if (g_ClassSounds != null)
    {
        g_ClassSounds.Clear();
    }
    if (g_ClassGloveModels != null)
    {
        g_ClassGloveModels.Clear();
    }
    if (g_ClassGloveSkins != null)
    {
        g_ClassGloveSkins.Clear();
    }
    if (g_DownloadModels != null)
    {
        g_DownloadModels.Clear();
    }
    if (g_DownloadSounds != null)
    {
        g_DownloadSounds.Clear();
    }

    g_DefaultClassT = -1;
    g_DefaultClassCT = -1;
    g_DefaultClassSpec = -1;
}
