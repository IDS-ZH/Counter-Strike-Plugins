
void ResolveConfigPaths()
{
    // Путь к основному конфигурационному файлу MST в директории Modifiers/Model_Switch_Tool
    BuildPath(Path_SM, g_MainConfig, sizeof(g_MainConfig), "configs/ZH-sys/Modifiers/Model_Switch_Tool/MST-main-config.cfg");
}

void LoadMstConfigs()
{
    g_ConfigsLoaded = false;
    g_AutoAssign = g_CvarMstAutoAssign != null && g_CvarMstAutoAssign.BoolValue;
    ClearClassData();

    if (!FileExists(g_MainConfig))
    {
        ZH_LogWarn("MST main config missing: %s", g_MainConfig);
        return;
    }

    KeyValues kv = new KeyValues("MST");
    if (!kv.ImportFromFile(g_MainConfig))
    {
        ZH_LogError("Failed to read MST config: %s", g_MainConfig);
        delete kv;
        return;
    }

    int fileMode = kv.GetNum("mode", g_CvarMstMode.IntValue);
    g_CvarMstMode.SetInt(fileMode);

    g_AutoAssign = kv.GetNum("auto_assign", g_AutoAssign ? 1 : 0) != 0;
    if (g_CvarMstAutoAssign != null)
    {
        g_CvarMstAutoAssign.SetInt(g_AutoAssign ? 1 : 0);
    }

    LoadDefaultClasses(kv);
    LoadClasses(kv);
    LoadDownloads(kv);

    g_ConfigsLoaded = true;
    ZH_LogInfo("MST configs loaded (mode=%d, autoassign=%d).", fileMode, g_AutoAssign ? 1 : 0);

    delete kv;
}

void LoadDefaultClasses(KeyValues kv)
{
    kv.Rewind();

    if (!kv.JumpToKey("defaults", false))
    {
        g_DefaultClassT = -1;
        g_DefaultClassCT = -1;
        g_DefaultClassSpec = -1;
        return;
    }

    g_DefaultClassT = kv.GetNum("t", g_DefaultClassT);
    g_DefaultClassCT = kv.GetNum("ct", g_DefaultClassCT);
    g_DefaultClassSpec = kv.GetNum("spec", g_DefaultClassSpec);

    kv.Rewind();
}

void LoadClasses(KeyValues kv)
{
    kv.Rewind();

    if (!kv.JumpToKey("classes", false) || !kv.GotoFirstSubKey(false))
    {
        kv.Rewind();
        return;
    }

    do
    {
        char keyName[32];
        kv.GetSectionName(keyName, sizeof(keyName));
        int classId = StringToInt(keyName);

        char name[64];
        char model[PLATFORM_MAX_PATH];
        char sound[64];
        kv.GetString("name", name, sizeof(name));
        kv.GetString("model", model, sizeof(model));
        kv.GetString("sound", sound, sizeof(sound));

        int flags = kv.GetNum("flags", 0);

        char flagsText[128];
        kv.GetString("flags_text", flagsText, sizeof(flagsText));
        if (flagsText[0] != '\0')
        {
            flags = ParseAbilityFlags(flagsText, flags);
        }

        int teamMask = TEAMMASK_ANY;
        char teamText[64];
        kv.GetString("teams", teamText, sizeof(teamText));
        if (teamText[0] != '\0')
        {
            teamMask = ParseTeamMask(teamText, TEAMMASK_ANY);
        }

        // Загружаем тип скина
        char skinTypeStr[32];
        kv.GetString("skin_type", skinTypeStr, sizeof(skinTypeStr));
        int skinType = ParseSkinType(skinTypeStr);

        DefineOrUpdateClass(classId, name, model, sound, flags, teamMask, skinType);

        // Загружаем информацию о перчатках
        char gloveModel[PLATFORM_MAX_PATH];
        int gloveSkin = kv.GetNum("glove_skin", 0);
        kv.GetString("glove_model", gloveModel, sizeof(gloveModel));

        if (gloveModel[0] != '\0')
        {
            char classIdStr[16];
            Format(classIdStr, sizeof(classIdStr), "%d", classId);

            g_ClassGloveModels.SetString(classIdStr, gloveModel);
            g_ClassGloveSkins.SetValue(classIdStr, gloveSkin);

            // Добавляем модель перчаток для прекеширования
            PushUniqueString(g_DownloadModels, gloveModel);
        }
    }
    while (kv.GotoNextKey(false));

    kv.Rewind();
}

void LoadDownloads(KeyValues kv)
{
    kv.Rewind();

    if (!kv.JumpToKey("downloads", false))
    {
        return;
    }

    if (kv.JumpToKey("models", false))
    {
        if (kv.GotoFirstSubKey(false))
        {
            do
            {
                char path[PLATFORM_MAX_PATH];
                kv.GetString(NULL_STRING, path, sizeof(path), "");
                if (path[0] != '\0')
                {
                    PushUniqueString(g_DownloadModels, path);
                }
            }
            while (kv.GotoNextKey(false));

            kv.GoBack();
        }
        kv.GoBack();
    }

    if (kv.JumpToKey("sounds", false))
    {
        if (kv.GotoFirstSubKey(false))
        {
            do
            {
                char path[PLATFORM_MAX_PATH];
                kv.GetString(NULL_STRING, path, sizeof(path), "");
                if (path[0] != '\0')
                {
                    PushUniqueString(g_DownloadSounds, path);
                }
            }
            while (kv.GotoNextKey(false));

            kv.GoBack();
        }
        kv.GoBack();
    }

    kv.Rewind();
}
