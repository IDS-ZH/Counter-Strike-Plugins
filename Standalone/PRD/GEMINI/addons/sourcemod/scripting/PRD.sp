#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <multicolors>
#include <easy_hudmessage>
#include <keyvalues>
#include <menus>
#include <adt_trie>

#define PLUGIN_VERSION "1.7"
#define TEAM_T 2
#define TEAM_CT 3
#define CAMPER_FALLBACK_SOUND "buttons/blip1.wav"

// --- Глобальные переменные ---
// MVP
bool g_bHasVoted[MAXPLAYERS + 1];
int g_iYesVotes = 0;
int g_iNoVotes = 0;
int g_iMvpNativeScore[MAXPLAYERS + 1];
ConVar g_hMVPVoteEnable;
ConVar g_hMVPVoteAmount;
ConVar g_hMVPMaxReward;
ConVar g_hMVPBotVoteProxy;
ConVar g_hMVPNativeVoteScale;
ConVar g_hAccountCapCvar;
bool g_bMvpVoteActive = false;
int g_iAccountCap = 0;
int g_iPendingWinner = -1;
int g_iPendingMvp = -1;
bool g_bMvpPendingVote = false;
int g_iPrevMvpStars[MAXPLAYERS + 1];
float g_fJoinTime[MAXPLAYERS + 1];
float g_fTeamDamage[5];
int g_iMVP = -1;

// Teamkill
ConVar g_hTeamkillEnable;
ConVar g_hTeamkillPunishMode;
ConVar g_hTeamkillForgiveThreshold;
ConVar g_hTeamDamageMutualThreshold;
ConVar g_hBotPunishment;
int g_iTeamKills[MAXPLAYERS + 1];
ArrayList g_hTeamkillIncidents;
ArrayList g_hPunishments;
ConVar g_hPunishmentsFile;
int g_iTeamkillAttacker[MAXPLAYERS + 1];
int g_iMutualDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];


// Camper
ConVar g_hAntiCamperEnable;
ConVar g_hAntiCamperTime;
ConVar g_hAntiCamperSoundEnable;
ConVar g_hAntiCamperSoundPath;
ConVar g_hAntiCamperPenaltyMode;
ConVar g_hAntiCamperPenaltyAmount;
ConVar g_hAntiCamperPenaltyInterval;
ConVar g_hAntiCamperIgniteDuration;
float g_vLastPosition[MAXPLAYERS + 1][3];
int g_iCampingTime[MAXPLAYERS + 1];
bool g_bIsCamping[MAXPLAYERS + 1];
Handle g_hCampingTimers[MAXPLAYERS + 1];
Handle g_hBeaconTimers[MAXPLAYERS + 1];
int g_hBeaconSprite;
char g_sAntiCamperSound[PLATFORM_MAX_PATH];
bool g_bAntiCamperSoundReady = false;
float g_fLastCamperPenalty[MAXPLAYERS + 1];

// Rules
ConVar g_hFreezeTime;
ArrayList g_hPlayerRules;
ArrayList g_hAdminRules;
ConVar g_hPlayerRulesFile;
ConVar g_hAdminRulesFile;
ConVar g_hRulesInterval;
int g_iRoundCounter = 0;
Handle g_hRulesTimer = INVALID_HANDLE;

// --- Информация о плагине ---
public Plugin myinfo =
{
    name        = "Player Reward and Discipline",
    author      = "Gemini (адаптация)",
    description = "Rewards MVP players and penalizes campers and teamkillers.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/M-G-E/Counter-Strike-Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("prd");
    CreateNative("PRD_RegisterMVPContribution", Native_RegisterMVPContribution);
    return APLRes_Success;
}

// --- OnPluginStart ---
public void OnPluginStart()
{
    LoadTranslations("PlayerRewardAndDiscipline.phrases.txt");

    // ConVars
    CreateConVar("sm_prd_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
    g_hMVPVoteEnable = CreateConVar("sm_prd_mvp_enable", "1", "Enable/disable MVP reward system.", _, true, 0.0, true, 1.0);
    g_hMVPVoteAmount = CreateConVar("sm_prd_mvp_amount", "1000", "Amount of money per vote for MVP.", _, true, 0.0);
    g_hMVPMaxReward = CreateConVar("sm_prd_mvp_max_reward", "0", "Maximum MVP reward (0 = follow mp_maxmoney).", _, true, 0.0);
    g_hMVPBotVoteProxy = CreateConVar("sm_prd_mvp_bot_vote_proxy", "1", "Count bots on the winning team as automatic YES votes.", _, true, 0.0, true, 1.0);
    g_hMVPNativeVoteScale = CreateConVar("sm_prd_mvp_native_vote_scale", "1.0", "Scale factor applied to MVP_native contributions when converting into votes.", _, true, 0.0);

    g_hTeamkillEnable = CreateConVar("sm_prd_teamkill_enable", "1", "Enable/disable teamkill punishment system.", _, true, 0.0, true, 1.0);
    g_hTeamkillPunishMode = CreateConVar("sm_teamkill_punish_mode", "2", "0=off, 1=auto-punish, 2=victim vote", _, true, 0.0, true, 2.0);
    g_hTeamkillForgiveThreshold = CreateConVar("sm_teamkill_forgive_threshold", "2", "How many teamkills are needed for it to be considered justice.", _, true, 1.0);
    g_hTeamDamageMutualThreshold = CreateConVar("sm_teamdamage_mutual_threshold", "25", "Damage for mutual aggression.", _, true, 1.0);
    g_hBotPunishment = CreateConVar("sm_prd_bot_punishment", "0", "Enable/disable punishments for bots.", _, true, 0.0, true, 1.0);

    g_hAntiCamperEnable = CreateConVar("sm_prd_anticamper_enable", "1", "Enable/disable anti-camper system.", _, true, 0.0, true, 1.0);
    g_hAntiCamperTime = CreateConVar("sm_anticamper_time", "10.0", "Time (sec) after which a player is considered a camper.", _, true, 5.0);
    g_hAntiCamperSoundEnable = CreateConVar("sm_prd_anticamper_sound", "1", "Play a warning sound for campers (heartbeat indicator).", _, true, 0.0, true, 1.0);
    g_hAntiCamperSoundPath = CreateConVar("sm_prd_anticamper_sound_path", "plugins/prd/heartbeat_loop.mp3", "Sound path relative to sound/ for camper warning.");
    g_hAntiCamperPenaltyMode = CreateConVar("sm_prd_anticamper_penalty_mode", "0", "Camper penalty: 0=Warn only, 1=Slap, 2=Ignite.");
    g_hAntiCamperPenaltyAmount = CreateConVar("sm_prd_anticamper_penalty_amount", "5", "Damage/slap strength applied to campers.", _, true, 0.0);
    g_hAntiCamperPenaltyInterval = CreateConVar("sm_prd_anticamper_penalty_interval", "3.0", "Seconds between camper penalty pulses.", _, true, 0.5);
    g_hAntiCamperIgniteDuration = CreateConVar("sm_prd_anticamper_ignite_duration", "2.0", "Ignite duration when penalty mode is 2 (seconds).", _, true, 0.5);

    g_hPlayerRulesFile = CreateConVar("sm_prd_player_rules_file", "configs/prd_rules_players.txt", "File with rules for players.");
    g_hAdminRulesFile = CreateConVar("sm_prd_admin_rules_file", "configs/prd_rules_admins.txt", "File with rules for admins.");
    g_hRulesInterval = CreateConVar("sm_prd_rules_interval", "1", "How many rounds to wait before showing the next rule.", _, true, 1.0);
    g_hPunishmentsFile = CreateConVar("sm_prd_punishments_file", "configs/prd_punishments.cfg", "File with teamkill punishments.");

    g_hFreezeTime = FindConVar("mp_freezetime");
    g_hAccountCapCvar = FindConVar("mp_maxmoney");
    if (g_hAccountCapCvar != null)
    {
        g_iAccountCap = g_hAccountCapCvar.IntValue;
        g_hAccountCapCvar.AddChangeHook(OnAccountCapChanged);
    }
    else
    {
        // fallback на стандартное ограничение, если mp_maxmoney недоступен
        g_iAccountCap = 16000;
    }
    if (g_hAntiCamperSoundPath != null)
    {
        g_hAntiCamperSoundPath.AddChangeHook(OnAntiCamperSoundChanged);
    }
    CacheAntiCamperSound();
    PrecacheSound(CAMPER_FALLBACK_SOUND, true);

    // Initialize arrays and handles
    if (g_hTeamkillIncidents == null) g_hTeamkillIncidents = new ArrayList();
    if (g_hPunishments == null) g_hPunishments = new ArrayList(8);
    if (g_hPlayerRules == null) g_hPlayerRules = new ArrayList(256);
    if (g_hAdminRules == null) g_hAdminRules = new ArrayList(256);
    for (int i = 0; i <= MaxClients; i++)
    {
        g_hBeaconTimers[i] = INVALID_HANDLE;
    }


    RegAdminCmd("sm_prd", Command_AdminMenu, ADMFLAG_CONFIG, "Open the Player Reward and Discipline admin menu.");

    // Hooks
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("round_end", Event_OnRoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);

    LoadRules();
    LoadPunishments();
    CreateOrRestartRulesTimer();
}

public void OnPluginEnd()
{
    StopRulesTimer();

    // Kill all beacon timers
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_hBeaconTimers[i] != INVALID_HANDLE)
        {
            KillTimer(g_hBeaconTimers[i]);
            g_hBeaconTimers[i] = INVALID_HANDLE;
        }
    }

    // Clean KeyValues in punishments ArrayList
    if (g_hPunishments != null)
    {
        for (int i = 0; i < g_hPunishments.Length; i++)
        {
            KeyValues kv = g_hPunishments.Get(i);
            if (kv != null) delete kv;
        }
        g_hPunishments.Clear();
        delete g_hPunishments;
        g_hPunishments = null;
    }

    // Clean other arrays
    if (g_hTeamkillIncidents != null) { g_hTeamkillIncidents.Clear(); delete g_hTeamkillIncidents; g_hTeamkillIncidents = null; }
    if (g_hPlayerRules != null)  { g_hPlayerRules.Clear();  delete g_hPlayerRules;  g_hPlayerRules = null; }
    if (g_hAdminRules != null)   { g_hAdminRules.Clear();   delete g_hAdminRules;   g_hAdminRules = null; }

}

public void OnClientPutInServer(int client)
{
    g_fJoinTime[client] = GetGameTime();
    g_fLastCamperPenalty[client] = 0.0;
    g_iMvpNativeScore[client] = 0;
    g_bHasVoted[client] = false;
    g_iPrevMvpStars[client] = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iMutualDamage[client][i] = 0;
        g_iMutualDamage[i][client] = 0;
    }
}

public void OnClientDisconnect(int client)
{
    if (client <= 0 || client > MaxClients)
    {
        return;
    }

    if (g_hBeaconTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hBeaconTimers[client]);
        g_hBeaconTimers[client] = INVALID_HANDLE;
    }

    g_iTeamkillAttacker[client] = 0;
    g_iMvpNativeScore[client] = 0;
    g_bHasVoted[client] = false;
    StopAntiCamperCue(client);
    g_bIsCamping[client] = false;
    g_iPrevMvpStars[client] = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iMutualDamage[client][i] = 0;
        g_iMutualDamage[i][client] = 0;
    }
}

public void OnMapStart()
{
    CacheAntiCamperSound();
    g_hBeaconSprite = PrecacheModel("sprites/laserbeam.vmt");
    g_bMvpPendingVote = false;
    g_iPendingWinner = -1;
    g_iPendingMvp = -1;
    LoadRules();
    LoadPunishments();
    CreateOrRestartRulesTimer();
}

// --- Rules timer helpers ---
void CreateOrRestartRulesTimer()
{
    if (g_hRulesTimer != INVALID_HANDLE)
    {
        KillTimer(g_hRulesTimer);
        g_hRulesTimer = INVALID_HANDLE;
    }
    g_hRulesTimer = CreateTimer(1.0, Timer_DisplayRules, _, TIMER_REPEAT);
}

void StopRulesTimer()
{
    if (g_hRulesTimer != INVALID_HANDLE)
    {
        KillTimer(g_hRulesTimer);
        g_hRulesTimer = INVALID_HANDLE;
    }
}



// --- Load Rules ---
void LoadRules()
{
    g_hPlayerRules.Clear();
    g_hAdminRules.Clear();

    char path[PLATFORM_MAX_PATH];
    g_hPlayerRulesFile.GetString(path, sizeof(path));

    char file_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file_path, sizeof(file_path), path);

    File file = OpenFile(file_path, "r");
    if (file != null)
    {
        char line[256];
        while (file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] != 0)
            {
                g_hPlayerRules.PushString(line);
            }
        }
        delete file;
    }

    g_hAdminRulesFile.GetString(path, sizeof(path));
    BuildPath(Path_SM, file_path, sizeof(file_path), path);

    file = OpenFile(file_path, "r");
    if (file != null)
    {
        char line[256];
        while (file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] != 0)
            {
                g_hAdminRules.PushString(line);
            }
        }
        delete file;
    }
}

// --- Load Punishments ---
void LoadPunishments()
{
    // Clear existing punishments and their KeyValues handles
    if (g_hPunishments != null)
    {
        for (int i = 0; i < g_hPunishments.Length; i++)
        {
            KeyValues kv = g_hPunishments.Get(i);
            if (kv != null) delete kv;
        }
        g_hPunishments.Clear();
    }

    char path[PLATFORM_MAX_PATH];
    g_hPunishmentsFile.GetString(path, sizeof(path));
    char file_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file_path, sizeof(file_path), path);

    KeyValues kv = new KeyValues("Punishments");
    if (kv.ImportFromFile(file_path))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                char name[32];
                kv.GetSectionName(name, sizeof(name));
                KeyValues punishment = new KeyValues(name);
                KvCopySubkeys(kv, punishment);
                g_hPunishments.Push(punishment);
            } while (kv.GotoNextKey());
        }
    }
    delete kv;
}

// --- Event Handlers ---

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundCounter++;

    if (g_bMvpVoteActive)
    {
        FinalizeMvpReward();
    }
    else
    {
        ResetMvpRoundState();
    }

    if (g_bMvpPendingVote)
    {
        int pendingWinner = g_iPendingWinner;
        int pendingMvp = g_iPendingMvp;
        g_bMvpPendingVote = false;
        g_iPendingWinner = -1;
        g_iPendingMvp = -1;

        g_iMVP = pendingMvp;
        if (g_iMVP != -1 && IsValidClient(g_iMVP))
        {
            StartMvpVote(pendingWinner);
        }
        else
        {
            ResetMvpRoundState();
        }
    }

    // Snapshot MVP stars to compute delta in next round
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            g_iPrevMvpStars[i] = CS_GetMVPCount(i);
        }
        else
        {
            g_iPrevMvpStars[i] = 0;
        }
    }

    for (int i = 0; i < 5; i++)
    {
        g_fTeamDamage[i] = 0.0;
    }

    // reset per-round counters
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iTeamKills[i] = 0;
        for (int j = 1; j <= MaxClients; j++)
        {
            g_iMutualDamage[i][j] = 0;
        }
    }


    // process incidents by snapshotting list
    if (g_hTeamkillIncidents != null && g_hTeamkillIncidents.Length > 0 && g_hTeamkillPunishMode.IntValue == 2)
    {
        int len = g_hTeamkillIncidents.Length;
        ArrayList incidentsSnapshot = new ArrayList();
        for (int idx = 0; idx < len; idx++)
        {
            KeyValues kv = g_hTeamkillIncidents.Get(idx);
            if (kv != null) incidentsSnapshot.Push(kv);
        }
        g_hTeamkillIncidents.Clear(); // Clear original list after snapshotting

        for (int idx = 0; idx < incidentsSnapshot.Length; idx++)
        {
            KeyValues kv = incidentsSnapshot.Get(idx);
            if (kv == null) continue;

            int victim_userid = kv.GetNum("victim_userid");
            int attacker_userid = kv.GetNum("attacker_userid");

            int victim = GetClientOfUserId(victim_userid);
            int attacker = GetClientOfUserId(attacker_userid);

            if (IsValidClient(victim) && IsValidClient(attacker) && attacker != 0 && victim != 0)
            {
                char sName[MAX_NAME_LENGTH];
                GetClientName(attacker, sName, sizeof(sName));

                Menu menu = new Menu(MenuHandler_TeamkillPunishment);
                menu.SetTitle("%t", "TKMenuTitle", sName);
                char forgiveText[64];
                Format(forgiveText, sizeof(forgiveText), "%t", "TKMenuForgive");
                menu.AddItem("forgive", forgiveText);

                for (int j = 0; j < g_hPunishments.Length; j++)
                {
                    KeyValues p = g_hPunishments.Get(j);
                    char p_name[32], p_translation[64];
                    p.GetSectionName(p_name, sizeof(p_name));
                    p.GetString("translation", p_translation, sizeof(p_translation));
                    menu.AddItem(p_name, p_translation);
                }

                g_iTeamkillAttacker[victim] = attacker; // Store attacker for menu handler
                menu.Display(victim, 15);
            }
            delete kv; // Delete KeyValues handle after processing
        }
        delete incidentsSnapshot; // Delete the snapshot ArrayList
    }

    // Голосование за MVP

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client)) return Plugin_Continue;

    g_iCampingTime[client] = 0;
    g_bIsCamping[client] = false;
    if (g_hBeaconTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hBeaconTimers[client]);
        g_hBeaconTimers[client] = INVALID_HANDLE;
    }
    StopAntiCamperCue(client);
    g_fLastCamperPenalty[client] = 0.0;

    if (g_hAntiCamperEnable.BoolValue)
        g_hCampingTimers[client] = CreateTimer(1.0, Timer_Camping, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(attacker) || !IsValidClient(victim) || attacker == victim)
        return Plugin_Continue;

    bool isTeamkill = (GetClientTeam(attacker) == GetClientTeam(victim));

    if (isTeamkill)
    {
        if (!g_hTeamkillEnable.BoolValue)
        {
            return Plugin_Continue;
        }

        if (IsFakeClient(attacker) && !g_hBotPunishment.BoolValue)
        {
            return Plugin_Continue;
        }

        // --- �������� "������������ ���������" ---
        if (g_iTeamKills[victim] >= g_hTeamkillForgiveThreshold.IntValue)
        {
            CPrintToChatAll("%t", "Teamkill_Justice", attacker, victim);
            return Plugin_Continue;
        }
        // --- �������� "�������� ��������" ---
        int mutual = g_iMutualDamage[victim][attacker];
        if (mutual >= g_hTeamDamageMutualThreshold.IntValue)
        {
            g_iTeamKills[attacker]++;
            CPrintToChatAll("%t", "Teamkill_Mutual", attacker, victim);
            return Plugin_Continue;
        }
        int punishMode = g_hTeamkillPunishMode.IntValue;
        if (punishMode == 1)
        {
            ForcePlayerSuicide(attacker);
            CPrintToChatAll("%t", "Teamkill_AutoPunish", attacker, victim);
        }
        else if (punishMode == 2)
        {
            KeyValues kv = new KeyValues("TeamkillIncident");
            kv.SetNum("victim_userid", GetClientUserId(victim));
            kv.SetNum("attacker_userid", GetClientUserId(attacker));
            g_hTeamkillIncidents.Push(kv);

            CPrintToChat(victim, "%t", "Teamkill_VictimNotice", attacker);
        }
        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hTeamkillEnable.BoolValue)
        return Plugin_Continue;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(attacker) || !IsValidClient(victim) || attacker == victim)
        return Plugin_Continue;

    int team = GetClientTeam(attacker);
    if (team >= 2 && team <= 3)
    {
        g_fTeamDamage[team] += event.GetInt("damage");
    }

    return Plugin_Continue;
}

public Action Timer_FindMvp(Handle timer, DataPack pack)
{
    pack.Reset();
    int winner = pack.ReadCell();
    g_iPendingMvp = FindMVPByStars(winner);
    g_iPendingWinner = winner;
    g_bMvpPendingVote = true;
    delete pack;
    return Plugin_Continue;
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    int winner = event.GetInt("winner");
    if (winner == 0)
    {
        ResetMvpRoundState();
        return Plugin_Continue; // No MVP on draw
    }

    int reason = event.GetInt("reason");

    if (reason == 1 && g_fTeamDamage[winner] == 0.0)
    {
        ResetMvpRoundState();
        return Plugin_Continue; // Target saved, no damage
    }

    // Move MVP vote to next round start to avoid menu being closed by round transition
    DataPack pack = new DataPack();
    pack.WriteCell(winner);
    CreateTimer(0.1, Timer_FindMvp, pack);

    return Plugin_Continue;
}


int FindMVPByStars(int winning_team)
{
    int bestClient = -1;
    int bestDelta = 0;
    float bestJoinTime = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i) || GetClientTeam(i) != winning_team)
        {
            continue;
        }

        int current = CS_GetMVPCount(i);
        int delta = current - g_iPrevMvpStars[i];
        if (delta > bestDelta)
        {
            bestDelta = delta;
            bestClient = i;
            bestJoinTime = g_fJoinTime[i];
        }
        else if (delta > 0 && delta == bestDelta)
        {
            if (g_fJoinTime[i] < bestJoinTime)
            {
                bestClient = i;
                bestJoinTime = g_fJoinTime[i];
            }
        }
    }

    return bestDelta > 0 ? bestClient : -1;
}

// --- Menu Handlers ---

public int MenuHandler_TeamkillPunishment(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (!IsValidClient(client)) return 0;

        int attacker = g_iTeamkillAttacker[client];

        if (!IsValidClient(attacker))
        {
            CPrintToChat(client, "%t", "TKAggressorLeft");
            return 0;
        }

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "forgive"))
        {
            CPrintToChatAll("%t", "Teamkill_Forgive", client, attacker);
        }
        else
        {
            for (int i = 0; i < g_hPunishments.Length; i++)
            {
                KeyValues p = g_hPunishments.Get(i);
                char p_name[32];
                p.GetSectionName(p_name, sizeof(p_name));
                if (StrEqual(info, p_name))
                {
                    char command[256], translation[64];
                    p.GetString("command", command, sizeof(command));
                    p.GetString("translation", translation, sizeof(translation));
                    char formatted_command[256];
                    FormatEx(formatted_command, sizeof(formatted_command), command, attacker);
                    ServerCommand(formatted_command);
                    CPrintToChatAll("%t", translation, client, attacker);
                    break;
                }
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
        g_iTeamkillAttacker[client] = 0; // Clear attacker data
    }
    return 0;
}

int GetAccountCap()
{
    // Clamp payouts to mp_maxmoney when available; otherwise use cached/default.
    if (g_hAccountCapCvar != null)
    {
        return g_hAccountCapCvar.IntValue;
    }
    return g_iAccountCap > 0 ? g_iAccountCap : 16000;
}

public void OnAccountCapChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_iAccountCap = StringToInt(newValue);
    if (g_iAccountCap <= 0)
    {
        g_iAccountCap = 16000;
    }
}

void ResetNativeMvpScores()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iMvpNativeScore[i] = 0;
    }
}

public any Native_RegisterMVPContribution(Handle plugin, int numParams)
{
    if (numParams < 1)
    {
        return 0;
    }

    int client = GetNativeCell(1);
    int amount = 1;
    if (numParams >= 2)
    {
        amount = GetNativeCell(2);
    }

    if (!IsValidClient(client) || amount <= 0)
    {
        return 0;
    }

    g_iMvpNativeScore[client] += amount;
    return g_iMvpNativeScore[client];
}

int CountBotsOnTeam(int team)
{
    if (team <= 0) return 0;

    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) == team && IsFakeClient(i))
        {
            count++;
        }
    }
    return count;
}

int GetEffectiveMvpRewardCap()
{
    int accountCap = GetAccountCap();
    int configuredCap = g_hMVPMaxReward.IntValue;
    if (configuredCap <= 0 || configuredCap > accountCap)
    {
        return accountCap;
    }
    return configuredCap;
}

void ApplyMvpRewardVotes(int addedVotes)
{
    if (addedVotes <= 0) return;
    if (g_iMVP == -1 || !IsValidClient(g_iMVP)) return;

    int rewardPerVote = g_hMVPVoteAmount.IntValue;
    if (rewardPerVote <= 0) return;

    int reward = addedVotes * rewardPerVote;
    int rewardCap = GetEffectiveMvpRewardCap();
    if (reward > rewardCap)
    {
        reward = rewardCap;
    }

    int money = GetEntProp(g_iMVP, Prop_Send, "m_iAccount");
    int accountCap = GetAccountCap();
    if (money + reward > accountCap)
    {
        reward = accountCap - money;
        if (reward < 0) reward = 0;
    }

    if (reward > 0)
    {
        SetEntProp(g_iMVP, Prop_Send, "m_iAccount", money + reward);
        CPrintToChat(g_iMVP, "%t", "MVP_Reward", reward);
    }
}

int GetNativeVoteContribution(int client)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        return 0;
    }

    int contribution = g_iMvpNativeScore[client];
    if (contribution <= 0)
    {
        return 0;
    }

    float scale = g_hMVPNativeVoteScale != null ? g_hMVPNativeVoteScale.FloatValue : 1.0;
    if (scale <= 0.0)
    {
        return 0;
    }

    return RoundToFloor(float(contribution) * scale);
}

void ResetMvpRoundState()
{
    ResetNativeMvpScores();

    g_bMvpVoteActive = false;
    g_iMVP = -1;
    g_iYesVotes = 0;
    g_iNoVotes = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bHasVoted[i] = false;
    }
}

void FinalizeMvpReward()
{
    ResetMvpRoundState();
}

void StartMvpVote(int winningTeam)
{
    if (g_iMVP == -1 || !IsValidClient(g_iMVP))
    {
        ResetMvpRoundState();
        return;
    }

    g_bMvpVoteActive = true;

    // Авто-голоса ботов: каждый бот даёт мгновенное начисление.
    int botVotes = g_hMVPBotVoteProxy.BoolValue ? CountBotsOnTeam(winningTeam) : 0;
    if (botVotes > 0)
    {
        ApplyMvpRewardVotes(botVotes);
        g_iYesVotes += botVotes;
    }

    // Convert native contributions into immediate rewards as well.
    int nativeVotes = GetNativeVoteContribution(g_iMVP);
    if (nativeVotes > 0)
    {
        ApplyMvpRewardVotes(nativeVotes);
        g_iYesVotes += nativeVotes;
    }

    if (!g_hMVPVoteEnable.BoolValue)
    {
        FinalizeMvpReward();
        return;
    }

    char sMVPName[MAX_NAME_LENGTH];
    GetClientName(g_iMVP, sMVPName, sizeof(sMVPName));

    Menu menu = new Menu(MenuHandler_MVPVote);
    menu.SetTitle("%t", "MVP_MenuTitle", sMVPName);
    char yesText[32];
    char noText[32];
    Format(yesText, sizeof(yesText), "%t", "VoteYes");
    Format(noText, sizeof(noText), "%t", "VoteNo");
    menu.AddItem("yes", yesText);
    menu.AddItem("no",  noText);

    bool displayed = false;
    int votingTeam = GetClientTeam(g_iMVP);
    if (votingTeam < TEAM_T || votingTeam > TEAM_CT)
    {
        votingTeam = winningTeam;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) == votingTeam)
        {
            // MVP не должен голосовать сам за себя; собираем мнения только союзников.
            if (i == g_iMVP)
            {
                continue;
            }
            menu.Display(i, 15);
            displayed = true;
        }
    }

    if (!displayed)
    {
        delete menu;
        FinalizeMvpReward();
    }
}

public int MenuHandler_MVPVote(Menu menu, MenuAction action, int client, int item)
{
    if (!g_bMvpVoteActive)
    {
        if (action == MenuAction_End)
        {
            delete menu;
        }
        return 0;
    }

    if (action == MenuAction_Select)
    {
        if (!IsValidClient(client)) return 0;
        if (g_bHasVoted[client])
            return 0;

        g_bHasVoted[client] = true;
        
        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "yes"))
        {
            ApplyMvpRewardVotes(1);
            g_iYesVotes++;
        }
        else if (StrEqual(info, "no"))
        {
            g_iNoVotes++;
        }
    }
    else if (action == MenuAction_End)
    {
        if (g_bMvpVoteActive)
        {
            FinalizeMvpReward();
        }
        delete menu;
    }
    return 0;
}

// --- Timers ---

public Action Timer_Camping(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !IsPlayerAlive(client))
    {
        StopAntiCamperCue(client);
        g_bIsCamping[client] = false;
        return Plugin_Stop;
    }

    AdminId admin = GetUserAdmin(client);
    if (admin != INVALID_ADMIN_ID && (GetAdminFlags(admin, Access_Effective) & ADMFLAG_ROOT))
        return Plugin_Continue;

    float pos[3];
    GetClientAbsOrigin(client, pos);

    if (GetVectorDistance(pos, g_vLastPosition[client]) < 1.0)
    {
        g_iCampingTime[client]++;
        if (g_iCampingTime[client] >= g_hAntiCamperTime.IntValue && !g_bIsCamping[client])
        {
            g_bIsCamping[client] = true;
        }
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

    if (g_bIsCamping[client])
    {
        PulseBeaconForClient(client, pos);
        PlayAntiCamperCue(client, pos);
        TryApplyCamperPenalty(client);
    }

    StoreVector(pos, g_vLastPosition[client]);
    return Plugin_Continue;
}

void PlayAntiCamperCue(int client, const float origin[3])
{
    if (!g_hAntiCamperSoundEnable.BoolValue)
    {
        return;
    }

    if (!IsValidClient(client))
    {
        return;
    }

    char sample[PLATFORM_MAX_PATH];
    if (g_bAntiCamperSoundReady)
    {
        strcopy(sample, sizeof(sample), g_sAntiCamperSound);
    }
    else
    {
        strcopy(sample, sizeof(sample), CAMPER_FALLBACK_SOUND);
    }

    EmitSoundToAll(sample, client, SNDCHAN_STATIC, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, origin);
}

void StopAntiCamperCue(int client)
{
    if (!IsValidClient(client))
    {
        return;
    }

    if (g_sAntiCamperSound[0] != '\0')
    {
        StopSound(client, SNDCHAN_STATIC, g_sAntiCamperSound);
    }
    StopSound(client, SNDCHAN_STATIC, CAMPER_FALLBACK_SOUND);
}

void GetTeamBeaconColor(int client, int color[4])
{
    int team = GetClientTeam(client);
    if (team == TEAM_CT)
    {
        color[0] = 64;
        color[1] = 128;
        color[2] = 255;
    }
    else if (team == TEAM_T)
    {
        color[0] = 255;
        color[1] = 80;
        color[2] = 80;
    }
    else
    {
        color[0] = 200;
        color[1] = 200;
        color[2] = 200;
    }
    color[3] = 255;
}

void PulseBeaconForClient(int client, const float origin[3])
{
    int color[4];
    GetTeamBeaconColor(client, color);

    TE_SetupBeamRingPoint(origin, 50.0, 250.0, g_hBeaconSprite, g_hBeaconSprite,
                          0, 10, 1.0, 5.0, 0.0, color, 10, 0);
    TE_SendToAll();
}

void TryApplyCamperPenalty(int client)
{
    int mode = g_hAntiCamperPenaltyMode.IntValue;
    if (mode <= 0 || !IsValidClient(client))
    {
        return;
    }

    float interval = g_hAntiCamperPenaltyInterval.FloatValue;
    if (interval < 0.5)
    {
        interval = 0.5;
    }

    float now = GetGameTime();
    if (now - g_fLastCamperPenalty[client] < interval)
    {
        return;
    }
    g_fLastCamperPenalty[client] = now;

    int amount = g_hAntiCamperPenaltyAmount.IntValue;
    if (amount < 0)
    {
        amount = 0;
    }

    if (mode == 1)
    {
        SlapPlayer(client, amount, true);
        CPrintToChat(client, "%t", "CamperWarning");
    }
    else if (mode == 2)
    {
        float duration = g_hAntiCamperIgniteDuration.FloatValue;
        if (duration <= 0.0)
        {
            duration = 2.0;
        }
        IgniteEntity(client, duration, false, 0.0, false);
    }
}

void CacheAntiCamperSound()
{
    g_bAntiCamperSoundReady = false;
    g_sAntiCamperSound[0] = '\0';

    if (g_hAntiCamperSoundPath == null)
    {
        return;
    }

    char rawPath[PLATFORM_MAX_PATH];
    g_hAntiCamperSoundPath.GetString(rawPath, sizeof(rawPath));
    TrimString(rawPath);

    if (rawPath[0] == '\0')
    {
        return;
    }

    char normalized[PLATFORM_MAX_PATH];
    strcopy(normalized, sizeof(normalized), rawPath);
    ReplaceString(normalized, sizeof(normalized), "\\", "/");

    if (strncmp(normalized, "sound/", 6, false) == 0)
    {
        int len = strlen(normalized);
        for (int i = 0; i <= len - 6; i++)
        {
            normalized[i] = normalized[i + 6];
        }
    }

    if (normalized[0] == '\0')
    {
        return;
    }

    if (PrecacheSound(normalized, true))
    {
        strcopy(g_sAntiCamperSound, sizeof(g_sAntiCamperSound), normalized);
        g_bAntiCamperSoundReady = true;
        char downloadPath[PLATFORM_MAX_PATH];
        FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", normalized);
        AddFileToDownloadsTable(downloadPath);
    }
    else
    {
        LogError("[PRD] Failed to precache anti-camper sound '%s'", normalized);
    }
}

public void OnAntiCamperSoundChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CacheAntiCamperSound();
}

public Action Timer_DisplayRules(Handle timer)
{
    if (g_hFreezeTime != null && GetGameTime() > g_hFreezeTime.FloatValue)
        return Plugin_Stop;

    if (g_hPlayerRules.Length == 0 && g_hAdminRules.Length == 0) return Plugin_Continue;

    if (g_iRoundCounter % g_hRulesInterval.IntValue != 0)
        return Plugin_Continue;

    int player_rule_index = (g_hPlayerRules.Length > 0) ? (g_iRoundCounter / g_hRulesInterval.IntValue) % g_hPlayerRules.Length : -1;
    int admin_rule_index = (g_hAdminRules.Length > 0) ? (g_iRoundCounter / g_hRulesInterval.IntValue) % g_hAdminRules.Length : -1;

    char player_rule[256];
    if (player_rule_index != -1) g_hPlayerRules.GetString(player_rule_index, player_rule, sizeof(player_rule));

    char admin_rule[256];
    if (admin_rule_index != -1) g_hAdminRules.GetString(admin_rule_index, admin_rule, sizeof(admin_rule));

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            AdminId admin = GetUserAdmin(i);
            if (admin != INVALID_ADMIN_ID && (GetAdminFlags(admin, Access_Effective) & ADMFLAG_ROOT))
            {
                if (admin_rule_index != -1) PrintHintText(i, "%t", "AdminRuleHint", admin_rule);
            }
            else
            {
                if (player_rule_index != -1) PrintHintText(i, "%t", "PlayerRuleHint", player_rule);
            }
        }
    }
    return Plugin_Continue;
}

// --- Admin Menu ---
public Action Command_AdminMenu(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    AdminMenu(client);
    return Plugin_Handled;
}

void AdminMenu(int client)
{
    Menu menu = new Menu(AdminMenuHandler);
    menu.SetTitle("%t", "AdminMenuTitle");

    char buffer[64];
    Format(buffer, sizeof(buffer), "%t", g_hMVPVoteEnable.BoolValue ? "AdminMenuMVP_On" : "AdminMenuMVP_Off");
    menu.AddItem("mvp", buffer);

    Format(buffer, sizeof(buffer), "%t", g_hTeamkillEnable.BoolValue ? "AdminMenuTK_On" : "AdminMenuTK_Off");
    menu.AddItem("teamkill", buffer);

    Format(buffer, sizeof(buffer), "%t", g_hAntiCamperEnable.BoolValue ? "AdminMenuCamper_On" : "AdminMenuCamper_Off");
    menu.AddItem("camper", buffer);

    menu.Display(client, MENU_TIME_FOREVER);
}

public int AdminMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (!IsValidClient(client)) return 0;

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "mvp"))
        {
            g_hMVPVoteEnable.SetBool(!g_hMVPVoteEnable.BoolValue);
            AdminMenu(client);
        }
        else if (StrEqual(info, "teamkill"))
        {
            g_hTeamkillEnable.SetBool(!g_hTeamkillEnable.BoolValue);
            AdminMenu(client);
        }
        else if (StrEqual(info, "camper"))
        {
            g_hAntiCamperEnable.SetBool(!g_hAntiCamperEnable.BoolValue);
            AdminMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// --- Utilities ---

void StoreVector(float src[3], float dest[3])
{
    dest[0] = src[0];
    dest[1] = src[1];
    dest[2] = src[2];
}stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
