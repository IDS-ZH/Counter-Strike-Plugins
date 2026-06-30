
public any Native_DefineClass(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    char name[64];
    char model[PLATFORM_MAX_PATH];
    char sound[64];
    int flags = GetNativeCell(5);

    GetNativeString(2, name, sizeof(name));
    GetNativeString(3, model, sizeof(model));
    GetNativeString(4, sound, sizeof(sound));

    DefineOrUpdateClass(classId, name, model, sound, flags);
    return true;
}

// Новый натив для установки информации о перчатках
public any Native_SetClassGloveInfo(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    char gloveModel[PLATFORM_MAX_PATH];
    int gloveSkin = GetNativeCell(3);

    GetNativeString(2, gloveModel, sizeof(gloveModel));

    char classIdStr[16];
    Format(classIdStr, sizeof(classIdStr), "%d", classId);

    g_ClassGloveModels.SetString(classIdStr, gloveModel);
    g_ClassGloveSkins.SetValue(classIdStr, gloveSkin);

    if (g_CvarMstDebug != null && g_CvarMstDebug.BoolValue)
    {
        ZH_LogInfo("Set glove info for class %d: model=%s, skin=%d", classId, gloveModel, gloveSkin);
    }

    // Добавляем модель перчаток для прекеширования
    if (gloveModel[0] != '\0')
    {
        PushUniqueString(g_DownloadModels, gloveModel);
    }

    return true;
}

// Новый натив для получения информации о перчатках
public any Native_GetClassGloveInfo(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    char[] buffer = new char[maxlen];
    int gloveSkin;

    char classIdStr[16];
    Format(classIdStr, sizeof(classIdStr), "%d", classId);

    bool hasModel = g_ClassGloveModels.GetString(classIdStr, buffer, maxlen);
    bool hasSkin = g_ClassGloveSkins.GetValue(classIdStr, gloveSkin);

    if (!hasModel || !hasSkin)
    {
        buffer[0] = '\0';
        gloveSkin = 0;
    }

    SetNativeString(2, buffer, maxlen);
    SetNativeCellRef(4, gloveSkin);

    return hasModel && hasSkin;
}

// Новый натив для установки типа скина
public any Native_SetClassSkinType(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    int skinType = GetNativeCell(2);
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        DefineOrUpdateClass(classId, "Undefined", "", "", 0, TEAMMASK_ANY, skinType);
        idx = FindClassIndex(classId);
        if (idx == -1)
        {
            return false;
        }
    }

    g_ClassDefs.Set(idx, skinType, ClassSkinType);

    if (g_CvarMstDebug != null && g_CvarMstDebug.BoolValue)
    {
        ZH_LogInfo("Set skin type %d for class %d", skinType, classId);
    }

    return true;
}

// Новый натив для получения типа скина
public any Native_GetClassSkinType(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    return GetSkinTypeForClass(classId);
}

// Остальные нативы остаются без изменений
public any Native_SetClientClass(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int classId = GetNativeCell(2);

    char reason[64];
    GetNativeString(3, reason, sizeof(reason));

    bool result = SetClientClassInternal(client, classId, reason);

    // Обновляем перчатки после смены класса
    if (result && ZH_IsValidClient(client))
    {
        UpdateGlovesForClient(client);
        // Также обновляем thirdperson режим при смене класса, если это необходимо
        SetClientViewMode(client, g_ClientTpMode[client]);
    }

    return result;
}

public any Native_GetClientClass(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!ZH_IsValidClient(client))
    {
        return -1;
    }
    return g_ClientClass[client];
}

public any Native_GetClassAbilityFlags(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    return GetAbilityFlags(classId);
}

public any Native_GetClassModel(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    char[] buffer = new char[maxlen];

    if (!GetStringValueForClass(g_ClassModels, classId, buffer, maxlen))
    {
        return false;
    }

    SetNativeString(2, buffer, maxlen);
    return true;
}

public any Native_GetClassName(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    char[] buffer = new char[maxlen];

    if (!GetStringValueForClass(g_ClassNames, classId, buffer, maxlen))
    {
        return false;
    }

    SetNativeString(2, buffer, maxlen);
    return true;
}

public any Native_GetClassSoundProfile(Handle plugin, int numParams)
{
    int classId = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    char[] buffer = new char[maxlen];

    if (!GetStringValueForClass(g_ClassSounds, classId, buffer, maxlen))
    {
        return false;
    }

    SetNativeString(2, buffer, maxlen);
    return true;
}

public any Native_RegisterModel(Handle plugin, int numParams)
{
    char path[PLATFORM_MAX_PATH];
    GetNativeString(1, path, sizeof(path));
    PushUniqueString(g_DownloadModels, path);
    return 0;
}

public any Native_RegisterSound(Handle plugin, int numParams)
{
    char path[PLATFORM_MAX_PATH];
    GetNativeString(1, path, sizeof(path));
    PushUniqueString(g_DownloadSounds, path);
    return 0;
}

// Нативы для thirdperson режима
public any Native_SetClientTpMode(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    ThirdPersonMode mode = view_as<ThirdPersonMode>(GetNativeCell(2));
    bool sendUpdate = GetNativeCell(3);

    return SetClientThirdPersonMode(client, mode, sendUpdate);
}

public any Native_GetClientTpMode(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (!ZH_IsValidClient(client))
    {
        return ThirdPersonMode_FirstPerson;
    }

    return g_ClientTpMode[client];
}

public any Native_ToggleClientTpMode(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    bool sendUpdate = GetNativeCell(2);

    return ToggleClientThirdPersonMode(client, sendUpdate);
}
