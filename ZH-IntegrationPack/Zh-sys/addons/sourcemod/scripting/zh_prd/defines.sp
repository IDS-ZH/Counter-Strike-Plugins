#if defined _zh_prd_defines_included
 #endinput
#endif
#define _zh_prd_defines_included

#define TEAM_T 2
#define TEAM_CT 3
#define CAMPER_FALLBACK_SOUND "buttons/blip1.wav"

// --- Global ConVars ---
// MVP
ConVar g_hMVPVoteEnable;
ConVar g_hMVPVoteAmount;
ConVar g_hMVPMaxReward;
ConVar g_hMVPBotVoteProxy;
ConVar g_hMVPNativeVoteScale;
ConVar g_hAccountCapCvar;

// Teamkill
ConVar g_hTeamkillEnable;
ConVar g_hTeamkillPunishMode;
ConVar g_hTeamkillForgiveThreshold;
ConVar g_hTeamDamageMutualThreshold;
ConVar g_hBotPunishment;

// Camper
ConVar g_hAntiCamperEnable;
ConVar g_hAntiCamperTime;
ConVar g_hAntiCamperSoundEnable;
ConVar g_hAntiCamperSoundPath;
ConVar g_hAntiCamperPenaltyMode;
ConVar g_hAntiCamperPenaltyAmount;
ConVar g_hAntiCamperPenaltyInterval;
ConVar g_hAntiCamperIgniteDuration;

// Rules & Configs
ConVar g_hFreezeTime;
ConVar g_hPlayerRulesFile;
ConVar g_hAdminRulesFile;
ConVar g_hRulesInterval;
ConVar g_hPunishmentsFile;

// --- Global Variables ---
// MVP
bool g_bHasVoted[MAXPLAYERS + 1];
int g_iYesVotes = 0;
int g_iNoVotes = 0;
int g_iMvpNativeScore[MAXPLAYERS + 1];
bool g_bMvpVoteActive = false;
int g_iAccountCap = 0;
int g_iPendingWinner = -1;
int g_iPendingMvp = -1;
bool g_bMvpPendingVote = false;
int g_iPrevMvpStars[MAXPLAYERS + 1];
float g_fJoinTime[MAXPLAYERS + 1];
int g_iMVP = -1;

// Teamkill
int g_iTeamKills[MAXPLAYERS + 1];
ArrayList g_hTeamkillIncidents;
ArrayList g_hPunishments;
int g_iTeamkillAttacker[MAXPLAYERS + 1];
int g_iMutualDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fTeamDamage[5];

// Camper
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
ArrayList g_hPlayerRules;
ArrayList g_hAdminRules;
int g_iRoundCounter = 0;
Handle g_hRulesTimer = INVALID_HANDLE;
