#if defined _zh_prd_config_included
 #endinput
#endif
#define _zh_prd_config_included

void LoadPrdConfigs()
{
    // ConVars
    CreateConVar("sm_prd_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
    
    // MVP Controls
    g_hMVPVoteEnable = CreateConVar("sm_prd_mvp_enable", "1", "Enable/disable MVP reward system.", _, true, 0.0, true, 1.0);
    g_hMVPVoteAmount = CreateConVar("sm_prd_mvp_amount", "1000", "Amount of money per vote for MVP.", _, true, 0.0);
    g_hMVPMaxReward = CreateConVar("sm_prd_mvp_max_reward", "0", "Maximum MVP reward (0 = follow mp_maxmoney).", _, true, 0.0);
    g_hMVPBotVoteProxy = CreateConVar("sm_prd_mvp_bot_vote_proxy", "1", "Count bots on the winning team as automatic YES votes.", _, true, 0.0, true, 1.0);
    g_hMVPNativeVoteScale = CreateConVar("sm_prd_mvp_native_vote_scale", "1.0", "Scale factor for native MVP contributions.", _, true, 0.0);

    // Teamkill Controls
    g_hTeamkillEnable = CreateConVar("sm_prd_teamkill_enable", "1", "Enable/disable teamkill punishment system.", _, true, 0.0, true, 1.0);
    g_hTeamkillPunishMode = CreateConVar("sm_teamkill_punish_mode", "2", "0=off, 1=auto, 2=vote", _, true, 0.0, true, 2.0);
    g_hTeamkillForgiveThreshold = CreateConVar("sm_teamkill_forgive_threshold", "2", "Teamkills required for justice.", _, true, 1.0);
    g_hTeamDamageMutualThreshold = CreateConVar("sm_teamdamage_mutual_threshold", "25", "Damage threshold for mutual aggression.", _, true, 1.0);
    g_hBotPunishment = CreateConVar("sm_prd_bot_punishment", "0", "Punish bots?", _, true, 0.0, true, 1.0);

    // Camper Controls
    g_hAntiCamperEnable = CreateConVar("sm_prd_anticamper_enable", "1", "Enable anti-camper system.", _, true, 0.0, true, 1.0);
    g_hAntiCamperTime = CreateConVar("sm_anticamper_time", "10.0", "Seconds before camper detection.", _, true, 5.0);
    g_hAntiCamperSoundEnable = CreateConVar("sm_prd_anticamper_sound", "1", "Play warning sound.", _, true, 0.0, true, 1.0);
    g_hAntiCamperSoundPath = CreateConVar("sm_prd_anticamper_sound_path", "plugins/prd/heartbeat_loop.mp3", "Warning sound path.");
    g_hAntiCamperPenaltyMode = CreateConVar("sm_prd_anticamper_penalty_mode", "0", "0=Warn, 1=Slap, 2=Ignite.");
    g_hAntiCamperPenaltyAmount = CreateConVar("sm_prd_anticamper_penalty_amount", "5", "Penalty amount.", _, true, 0.0);
    g_hAntiCamperPenaltyInterval = CreateConVar("sm_prd_anticamper_penalty_interval", "3.0", "Penalty interval.", _, true, 0.5);
    g_hAntiCamperIgniteDuration = CreateConVar("sm_prd_anticamper_ignite_duration", "2.0", "Ignite duration.", _, true, 0.5);

    // Rules & Files
    g_hPlayerRulesFile = CreateConVar("sm_prd_player_rules_file", "configs/ZH-sys/Modifiers/PRD/prd_rules_players.txt", "Player rules file.");
    g_hAdminRulesFile = CreateConVar("sm_prd_admin_rules_file", "configs/ZH-sys/Modifiers/PRD/prd_rules_admins.txt", "Admin rules file.");
    g_hRulesInterval = CreateConVar("sm_prd_rules_interval", "1", "Rounds between rules.", _, true, 1.0);
    g_hPunishmentsFile = CreateConVar("sm_prd_punishments_file", "configs/ZH-sys/Modifiers/PRD/prd_punishments.cfg", "Punishments config file.");

    // Engine ConVars
    g_hFreezeTime = FindConVar("mp_freezetime");
    g_hAccountCapCvar = FindConVar("mp_maxmoney");
    if (g_hAccountCapCvar != null)
    {
        g_iAccountCap = g_hAccountCapCvar.IntValue;
        g_hAccountCapCvar.AddChangeHook(OnAccountCapChanged);
    }
    else
    {
        g_iAccountCap = 16000;
    }

    if (g_hAntiCamperSoundPath != null)
    {
        g_hAntiCamperSoundPath.AddChangeHook(OnAntiCamperSoundChanged);
    }
    
    LoadRulesFiles();
    LoadPunishmentsFile();
}

void OnAccountCapChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_iAccountCap = StringToInt(newValue);
    if (g_iAccountCap <= 0) g_iAccountCap = 16000;
}

void OnAntiCamperSoundChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CacheAntiCamperSound();
}

void CacheAntiCamperSound()
{
    char path[PLATFORM_MAX_PATH];
    g_hAntiCamperSoundPath.GetString(path, sizeof(path));
    if (path[0] != '\0')
    {
        Format(g_sAntiCamperSound, sizeof(g_sAntiCamperSound), "sound/%s", path);
        if (FileExists(g_sAntiCamperSound, true))
        {
            PrecacheSound(path, true);
            g_bAntiCamperSoundReady = true;
            ZH_Log(ZH_LOG_DEBUG, "Camp sound cached: %s", path);
        }
        else
        {
            g_bAntiCamperSoundReady = false;
            ZH_Log(ZH_LOG_WARN, "Camp sound not found: %s", g_sAntiCamperSound);
        }
        strcopy(g_sAntiCamperSound, sizeof(g_sAntiCamperSound), path); // Store relative path for EmitSound
    }
}

void LoadRulesFiles()
{
    if (g_hPlayerRules != null) g_hPlayerRules.Clear();
    if (g_hAdminRules != null) g_hAdminRules.Clear();

    char path[PLATFORM_MAX_PATH];
    g_hPlayerRulesFile.GetString(path, sizeof(path));
    
    char fullPath[PLATFORM_MAX_PATH];
    ZH_BuildPath(ZH_CONFIG_MODIFIER, fullPath, sizeof(fullPath), "PRD", "prd_rules_players.txt"); // Try standard ZH path first
    
    // Fallback to convar path if ZH standard fails or is different (simple load logic)
    // Actually, let's enforce ConVar path but allow relative to sourcemod root
    BuildPath(Path_SM, fullPath, sizeof(fullPath), path);

    File file = OpenFile(fullPath, "r");
    if (file != null)
    {
        char line[256];
        while (file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] != 0 && g_hPlayerRules != null) g_hPlayerRules.PushString(line);
        }
        delete file;
    }

    g_hAdminRulesFile.GetString(path, sizeof(path));
    BuildPath(Path_SM, fullPath, sizeof(fullPath), path);
    file = OpenFile(fullPath, "r");
    if (file != null)
    {
        char line[256];
        while (file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] != 0 && g_hAdminRules != null) g_hAdminRules.PushString(line);
        }
        delete file;
    }
}

void LoadPunishmentsFile()
{
    if (g_hPunishments != null)
    {
        // Clean existing
        for (int i = 0; i < g_hPunishments.Length; i++)
        {
            KeyValues kv = g_hPunishments.Get(i);
            if (kv != null) delete kv;
        }
        g_hPunishments.Clear();
    }

    char path[PLATFORM_MAX_PATH];
    g_hPunishmentsFile.GetString(path, sizeof(path));
    char fullPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, fullPath, sizeof(fullPath), path);

    KeyValues kv = new KeyValues("Punishments");
    if (kv.ImportFromFile(fullPath))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                char name[32];
                kv.GetSectionName(name, sizeof(name));
                KeyValues punishment = new KeyValues(name);
                KvCopySubkeys(kv, punishment);
                if (g_hPunishments != null) g_hPunishments.Push(punishment);
            } while (kv.GotoNextKey());
        }
    }
    delete kv;
}
