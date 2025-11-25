/*******************************************************************************

  SM_SoundManifest - A Unified Sound Event Plugin (V3.2)

  Version: 3.2
  Author: Gemini for ZloyHohol

  Description:
  A modern, configurable plugin to play sounds for various game events,
  including a flexible welcome sound system and Quake-style kill events.
  All messages are now localized via translations with enhanced features.

*******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <easy_hudmessage>

// --- Constants & Defines ---
#define PLUGIN_VERSION "3.2"
#define MAX_SOUNDS_PER_EVENT 5
#define MAX_GROUPS 8
#define MAX_AUDIENCE_TYPES 6
#define COMBO_TIME 4.0 // Time in seconds to chain kills for a combo
#define MAX_FILE_SIZE 52428800 // 50MB in bytes

// --- Enums ---

enum AudienceType {
    AUDIENCE_KILLER = 0,
    AUDIENCE_VICTIM,
    AUDIENCE_KILLER_TEAM,
    AUDIENCE_VICTIM_TEAM,
    AUDIENCE_ALL_ALIVE,
    AUDIENCE_ALL
};

enum SoundEventType {
    EVENT_FIRSTBLOOD = 0,
    EVENT_HEADSHOT,
    EVENT_DOUBLEKILL,
    EVENT_TRIPLEKILL,
    EVENT_QUADKILL,
    EVENT_MULTIKILL,
    EVENT_SUPERKILL,
    EVENT_ULTRAKILL,
    EVENT_MEGAKILL,
    EVENT_MONSTERKILL,
    EVENT_GODLIKE,
    EVENT_COMBO,
    EVENT_KNIFEKILL,
    EVENT_GRENADEKILL,
    EVENT_SUICIDE,
    EVENT_TEAMKILL,
    EVENT_JUSTICEKILL,
    EVENT_SPECIALKILL,
    EVENT_RIFLEKILL,
    EVENT_SMGKILL,
    EVENT_SHOTGUNKILL,
    EVENT_SNIPERKILL,
    EVENT_PISTOLKILL,
    EVENT_MACHINEGUNKILL, // Added for M249
    EVENT_PLAYER_DISCONNECT,
    EVENT_PLAYER_KICK,
    EVENT_PLAYER_VAC_BANNED,
    EVENT_COUNT
};

// --- Data Structures ---

// Forward declaration for the arrays we need
// In SourcePawn, we can't declare complex structs like in C++,
// so we need to define arrays for each field
// Instead of using complex structs, we'll implement a different approach:

// Structure to hold sound information (will be handled through arrays)
// struct SoundInfo is not directly supported in this way in SP 1.13
// So we need to simulate it with global arrays

// Structure for each event's sound configuration
// We'll use global arrays instead of struct fields
// This is how it's typically done in SourcePawn

// Individual arrays to simulate the struct
char g_sSoundsPaths[EVENT_COUNT][MAX_SOUNDS_PER_EVENT][PLATFORM_MAX_PATH];
float g_fSoundsDurations[EVENT_COUNT][MAX_SOUNDS_PER_EVENT];
bool g_bSoundsValid[EVENT_COUNT][MAX_SOUNDS_PER_EVENT];
int g_iSoundsCount[EVENT_COUNT];

// CT-specific sounds
char g_sCTSndPaths[EVENT_COUNT][MAX_SOUNDS_PER_EVENT][PLATFORM_MAX_PATH];
float g_fCTSDurations[EVENT_COUNT][MAX_SOUNDS_PER_EVENT];
bool g_bCTValid[EVENT_COUNT][MAX_SOUNDS_PER_EVENT];
int g_iCTSoundCount[EVENT_COUNT];

// T-specific sounds
char g_sTSndPaths[EVENT_COUNT][MAX_SOUNDS_PER_EVENT][PLATFORM_MAX_PATH];
float g_fTSDurations[EVENT_COUNT][MAX_SOUNDS_PER_EVENT];
bool g_bTValid[EVENT_COUNT][MAX_SOUNDS_PER_EVENT];
int g_iTSoundCount[EVENT_COUNT];

// Message for each event
char g_sEventMessages[EVENT_COUNT][256];

// Audience settings for each event
AudienceType g_EventAudience[EVENT_COUNT][MAX_AUDIENCE_TYPES];
int g_iAudienceCount[EVENT_COUNT];

// --- Global Variables ---

// For welcome sounds
char g_sWelcomeSoundPaths[MAX_GROUPS][MAX_SOUNDS_PER_EVENT][PLATFORM_MAX_PATH];
int g_iWelcomeSoundCounts[MAX_GROUPS];
char g_sWelcomeGroupFlags[MAX_GROUPS][32];
int g_iWelcomeGroupCount = 0;
int g_iDefaultGroupIndex = -1;

// --- ConVars ---
ConVar g_hEnabled;
ConVar g_hJoinDelay;
ConVar g_hJoinAudience;
ConVar g_hJoinInterval;
ConVar g_hDefaultSetting;
ConVar g_hJusticeKillThreshold;
ConVar g_hComboKillTime;
ConVar g_hQuadKillThreshold;
ConVar g_hEpicStreakThreshold;
ConVar g_hCooldownInterval;
ConVar g_hDebugLevel;          // Added for debugging
ConVar g_hMaxFileSize;         // Added for file size limit
ConVar g_hMaxSoundsPerEvent;   // Added for sound count limit

// --- State Variables ---
Handle g_hCookieSoundPref;
bool g_bSoundEnabled[MAXPLAYERS + 1];
Handle g_hEventForward = null;
int g_iLastWelcomeSoundTime = 0;
float g_fLastPlayedTime[EVENT_COUNT]; // Track last played time for each event type

// Killstreak Tracking
int g_iKillstreak[MAXPLAYERS + 1];
float g_fLastKillTime[MAXPLAYERS + 1];  // Changed from int to float to match GetGameTime() return type
int g_iTotalKillsThisRound = 0;  // Fixed: track total kills in round
int g_iLastKillCount[MAXPLAYERS + 1]; // For Combo
int g_iPlayerTeamkills[MAXPLAYERS + 1]; // For JusticeKill
int g_iEpicStreak[MAXPLAYERS + 1]; // For Epic Streaks (MultiKill, etc.)
int g_iAnnouncedStreakLevel[MAXPLAYERS + 1]; // Tracks the highest announced streak level per round
char g_sLastWeaponType[MAXPLAYERS + 1][64]; // For SpecialKill detection
int g_iPersistentRoundCount = 0; // For enhanced logging

// --- Plugin Info ---

public Plugin myinfo = {
    name        = "Sound Manifest",
    author      = "Gemini for ZloyHohol",
    description = "Unified plugin for game event sounds with enhanced features.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// --- Plugin Forwards ---

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_hEventForward = CreateGlobalForward("SoundManifest_OnEvent", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    return APLRes_Success;
}

public void OnPluginStart()
{
    // Create version cvar and other CVars
    CreateConVar("sm_soundmanifest_version", PLUGIN_VERSION, "Sound Manifest Version", FCVAR_NOTIFY | FCVAR_SPONLY);
    g_hEnabled          = CreateConVar("sm_soundmanifest_enabled", "1", "0 = Disable the plugin, 1 = Enable.");
    g_hJoinDelay        = CreateConVar("sm_soundmanifest_join_delay", "3.0", "Delay in seconds before playing the welcome sound.", _, true, 0.0, true, 30.0);
    g_hJoinAudience     = CreateConVar("sm_soundmanifest_join_audience", "0", "Who hears the welcome sound: 0 = Joiner only, 1 = Everyone.", _, true, 0.0, true, 1.0);
    g_hJoinInterval     = CreateConVar("sm_soundmanifest_join_interval", "10.0", "Minimum interval in seconds between playing welcome sounds.", _, true, 0.0, true, 300.0);
    g_hDefaultSetting   = CreateConVar("sm_soundmanifest_default_setting", "1", "Should sounds be enabled by default for new players? 1 = Yes, 0 = No.");
    g_hJusticeKillThreshold = CreateConVar("sm_soundmanifest_justicekill_threshold", "2", "Number of teamkills a victim must have to trigger JusticeKill.", _, true, 0.0, true, 10.0);
    g_hComboKillTime    = CreateConVar("sm_soundmanifest_combokill_time", "4.0", "Time in seconds to chain kills for a combo.", _, true, 0.0, true, 10.0);
    g_hQuadKillThreshold = CreateConVar("sm_soundmanifest_quadkill_threshold", "4", "Number of kills for a QuadKill.", _, true, 0.0, true, 10.0);
    g_hEpicStreakThreshold = CreateConVar("sm_soundmanifest_epicstreak_threshold", "5", "Number of kills for an Epic Streak (MultiKill, etc.).", _, true, 0.0, true, 10.0);
    g_hCooldownInterval = CreateConVar("sm_soundmanifest_cooldown_interval", "2.0", "Minimum interval in seconds between repetitions of the same sound.", _, true, 0.0, true, 10.0);
    
    // New CVars for enhanced functionality
    g_hDebugLevel = CreateConVar("sm_soundmanifest_debug_level", "0", "Debug level: 0=errors only, 1=warnings, 2=info, 3=debug", _, true, 0.0, true, 3.0);
    g_hMaxFileSize = CreateConVar("sm_soundmanifest_max_file_size", "50", "Maximum sound file size in MB", _, true, 1.0, true, 100.0);
    g_hMaxSoundsPerEvent = CreateConVar("sm_soundmanifest_max_sounds_per_event", "5", "Maximum sounds per event (1-5)", _, true, 1.0, true, 5.0);

    AutoExecConfig(true, "SoundManifest-extra");

    LoadTranslations("SoundManifest.phrases");

    g_hCookieSoundPref = RegClientCookie("sm_soundmanifest_preference", "User preference for sounds", CookieAccess_Private);

    RegConsoleCmd("sm_soundmanifest", Command_SoundMenu, "Open the Sound Manifest settings menu");
    RegConsoleCmd("soundmanifest", Command_SoundMenu);
    RegConsoleCmd("sm_soundmanifest_reset_cooldowns", Command_ResetCooldowns, "Resets all event cooldowns (admin only)", ADMFLAG_CONFIG); // Only for debugging

    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
    HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);
    
    LogDebug(2, "[SM] Plugin version %s loaded successfully", PLUGIN_VERSION);
}

public void OnAllPluginsLoaded() { LoadSoundsConfig(); }
public void OnConfigsExecuted() { LoadSoundsConfig(); }

// --- Sound Config Loading ---

void LoadSoundsConfig()
{
    // Initialize all event sounds arrays
    for (int i = 0; i < view_as<int>(EVENT_COUNT); i++) {
        // Initialize sound arrays
        g_iSoundsCount[i] = 0;
        g_iCTSoundCount[i] = 0;
        g_iTSoundCount[i] = 0;
        
        // Initialize messages
        g_sEventMessages[i][0] = '\0';
        
        // Initialize audience arrays
        g_iAudienceCount[i] = 0;
    }

    // Also reset welcome sound data
    g_iWelcomeGroupCount = 0;
    g_iDefaultGroupIndex = -1;

    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/SoundManifestConfiguration.cfg");

    if (!FileExists(sPath)) {
        LogDebug(0, "[SM] Config file not found: %s. No sounds will be played.", sPath);
        return;
    }

    KeyValues hKV = new KeyValues("SoundManifest");
    if (!hKV.ImportFromFile(sPath)) {
        LogDebug(0, "[SM] Failed to parse sound config file: %s", sPath);
        delete hKV;
        return;
    }

    // Process each section in the config
    if (hKV.GotoFirstSubKey()) {
        do {
            char sSectionName[64];
            hKV.GetSectionName(sSectionName, sizeof(sSectionName));
            
            // Check if this is a join server section (special case)
            if (StrEqual(sSectionName, "JoinServer")) {
                ParseWelcomeSounds(hKV);
            } else {
                // Try to find the event type
                SoundEventType eventType = GetEventTypeByName(sSectionName);
                if (eventType != EVENT_COUNT) {
                    ParseEventSounds(hKV, eventType, sSectionName);
                } else {
                    LogDebug(1, "[SM] Unknown event type in config: %s", sSectionName);
                }
            }
        } while (hKV.GotoNextKey(false));
    }

    delete hKV;
}

void ParseEventSounds(KeyValues kv, SoundEventType eventType, const char[] eventName)
{
    char tempStr[256];
    int maxSounds = g_hMaxSoundsPerEvent.IntValue;
    
    // Get message
    kv.GetString("message", g_sEventMessages[eventType], sizeof(g_sEventMessages[eventType]));
    
    // Get sound count
    int soundCount = 1;
    if (kv.GetNum("sound_count", 1) > 0) {
        soundCount = kv.GetNum("sound_count", 1);
    }
    
    // Limit sound count
    if (soundCount > maxSounds) {
        LogDebug(1, "[SM] Event %s has more than %d sounds, limiting to %d", eventName, maxSounds, maxSounds);
        soundCount = maxSounds;
    }
    
    // Process regular sounds
    int processedSounds = 0;
    for (int i = 1; i <= soundCount && processedSounds < MAX_SOUNDS_PER_EVENT; i++) {
        Format(tempStr, sizeof(tempStr), "sound_%d", i);
        if (kv.GetString(tempStr, g_sSoundsPaths[eventType][processedSounds], sizeof(g_sSoundsPaths[eventType][processedSounds]))) {
            // Validate and precache the sound
            float maxSize = g_hMaxFileSize.FloatValue;
            if (PrecacheAndValidateSound(g_sSoundsPaths[eventType][processedSounds], maxSize)) {
                // Try to get duration if available
                Format(tempStr, sizeof(tempStr), "duration_%d", i);
                g_fSoundsDurations[eventType][processedSounds] = kv.GetFloat(tempStr, 0.0);
                g_bSoundsValid[eventType][processedSounds] = true;
                processedSounds++;
            } else {
                LogDebug(1, "[SM] Skipping invalid sound for event %s: %s", eventName, g_sSoundsPaths[eventType][processedSounds]);
            }
        }
    }
    g_iSoundsCount[eventType] = processedSounds;
    
    // Process CT sounds (for team-specific sounds)
    if (kv.JumpToKey("CT", false)) {
        int ctProcessed = 0;
        for (int i = 1; i <= soundCount && ctProcessed < MAX_SOUNDS_PER_EVENT; i++) {
            Format(tempStr, sizeof(tempStr), "sound_%d", i);
            if (kv.GetString(tempStr, g_sCTSndPaths[eventType][ctProcessed], sizeof(g_sCTSndPaths[eventType][ctProcessed]))) {
                float maxSize = g_hMaxFileSize.FloatValue;
                if (PrecacheAndValidateSound(g_sCTSndPaths[eventType][ctProcessed], maxSize)) {
                    Format(tempStr, sizeof(tempStr), "duration_%d", i);
                    g_fCTSDurations[eventType][ctProcessed] = kv.GetFloat(tempStr, 0.0);
                    g_bCTValid[eventType][ctProcessed] = true;
                    ctProcessed++;
                } else {
                    LogDebug(1, "[SM] Skipping invalid CT sound for event %s: %s", eventName, g_sCTSndPaths[eventType][ctProcessed]);
                }
            }
        }
        g_iCTSoundCount[eventType] = ctProcessed;
        kv.GoBack();
    }
    
    // Process T sounds
    if (kv.JumpToKey("T", false)) {
        int tProcessed = 0;
        for (int i = 1; i <= soundCount && tProcessed < MAX_SOUNDS_PER_EVENT; i++) {
            Format(tempStr, sizeof(tempStr), "sound_%d", i);
            if (kv.GetString(tempStr, g_sTSndPaths[eventType][tProcessed], sizeof(g_sTSndPaths[eventType][tProcessed]))) {
                float maxSize = g_hMaxFileSize.FloatValue;
                if (PrecacheAndValidateSound(g_sTSndPaths[eventType][tProcessed], maxSize)) {
                    Format(tempStr, sizeof(tempStr), "duration_%d", i);
                    g_fTSDurations[eventType][tProcessed] = kv.GetFloat(tempStr, 0.0);
                    g_bTValid[eventType][tProcessed] = true;
                    tProcessed++;
                } else {
                    LogDebug(1, "[SM] Skipping invalid T sound for event %s: %s", eventName, g_sTSndPaths[eventType][tProcessed]);
                }
            }
        }
        g_iTSoundCount[eventType] = tProcessed;
        kv.GoBack();
    }
    
    // Process audience settings
    kv.GetString("audience", tempStr, sizeof(tempStr));
    if (strlen(tempStr) > 0) {
        ParseAudienceTypes(tempStr, eventType);
    } else {
        // Set default audience if not specified
        SetDefaultAudienceByEventType(eventType);
    }
}

void ParseWelcomeSounds(KeyValues hKV)
{
    // Implementation for welcome sounds with admin groups
    // This would parse the admin-specific sections as well
    if (!hKV.GotoFirstSubKey(false)) return;
    
    do {
        if (g_iWelcomeGroupCount >= MAX_GROUPS) break;

        hKV.GetSectionName(g_sWelcomeGroupFlags[g_iWelcomeGroupCount], 31);
        if (StrEqual(g_sWelcomeGroupFlags[g_iWelcomeGroupCount], "Default", false)) {
            g_sWelcomeGroupFlags[g_iWelcomeGroupCount][0] = '\0';
            g_iDefaultGroupIndex = g_iWelcomeGroupCount;
        }

        int iSoundCount = 0;
        if (hKV.GotoFirstSubKey(false)) {
            do {
                char sKey[64];
                hKV.GetSectionName(sKey, sizeof(sKey));
                if (StrContains(sKey, "sound", false) == 0 && iSoundCount < MAX_SOUNDS_PER_EVENT) {
                    char sSoundPath[PLATFORM_MAX_PATH];
                    hKV.GetString(NULL_STRING, sSoundPath, sizeof(sSoundPath));
                    NormalizePath(sSoundPath, sizeof(sSoundPath));

                    if (PrecacheAndValidateSound(sSoundPath, g_hMaxFileSize.FloatValue)) {
                        strcopy(g_sWelcomeSoundPaths[g_iWelcomeGroupCount][iSoundCount], PLATFORM_MAX_PATH, sSoundPath);
                        iSoundCount++;
                    }
                }
            } while (hKV.GotoNextKey(false));
            hKV.GoBack();
        }
        g_iWelcomeSoundCounts[g_iWelcomeGroupCount] = iSoundCount;
        g_iWelcomeGroupCount++;
    } while (hKV.GotoNextKey(false));
    hKV.GoBack();
}

bool PrecacheAndValidateSound(const char[] sRelativePath, float maxSizeMB)
{
    if (sRelativePath[0] == '\0') return false;
    
    // Check if file exists
    char sFullPath[PLATFORM_MAX_PATH];
    Format(sFullPath, sizeof(sFullPath), "sound/%s", sRelativePath);
    
    if (!FileExists(sFullPath)) {
        LogDebug(0, "[SM] Sound file does not exist: %s", sFullPath);
        return false;
    }
    
    // Check file size
    int fileSize = FileSize(sFullPath);
    if (fileSize == -1) {
        LogDebug(0, "[SM] Cannot get file size for: %s", sFullPath);
        return false;
    }
    
    float maxSizeBytes = maxSizeMB * 1024.0 * 1024.0; // Convert MB to bytes
    if (fileSize > maxSizeBytes) {
        LogDebug(1, "[SM] Sound file too large (%d bytes > %f MB): %s", fileSize, maxSizeMB, sFullPath);
        return false;
    }
    
    // Check file extension
    char ext[8];
    GetExtension(sRelativePath, ext, sizeof(ext));
    if (!StrEqual(ext, ".wav", false) && !StrEqual(ext, ".mp3", false) && !StrEqual(ext, ".ogg", false)) {
        LogDebug(1, "[SM] Sound file has unsupported format: %s (only .wav, .mp3, .ogg supported)", sFullPath);
        return false;
    }
    
    // Add to downloads table and precache
    AddFileToDownloadsTable(sFullPath);
    PrecacheSound(sRelativePath, true);
    
    LogDebug(3, "[SM] Successfully validated and precached sound: %s", sRelativePath);
    return true;
}

void NormalizePath(char[] sPath, int iMaxLen) { ReplaceString(sPath, iMaxLen, "\\", "/"); }

void GetExtension(const char[] filename, char[] ext, int maxlen)
{
    int len = strlen(filename);
    int dotPos = -1;

    for (int i = len - 1; i >= 0; i--)
    {
        if (filename[i] == '.')
        {
            dotPos = i;
            break;
        }
    }

    if (dotPos == -1 || maxlen <= 1)
    {
        ext[0] = '\0';
        return;
    }

    int j = 0;
    for (int i = dotPos; i < len && j < maxlen - 1; i++)
    {
        ext[j++] = filename[i];
    }
    ext[j] = '\0';
}

SoundEventType GetEventTypeByName(const char[] name)
{
    if (StrEqual(name, "FirstBlood")) return EVENT_FIRSTBLOOD;
    if (StrEqual(name, "Headshot")) return EVENT_HEADSHOT;
    if (StrEqual(name, "DoubleKill")) return EVENT_DOUBLEKILL;
    if (StrEqual(name, "TripleKill")) return EVENT_TRIPLEKILL;
    if (StrEqual(name, "QuadKill")) return EVENT_QUADKILL;
    if (StrEqual(name, "MultiKill")) return EVENT_MULTIKILL;
    if (StrEqual(name, "SuperKill")) return EVENT_SUPERKILL;
    if (StrEqual(name, "UltraKill")) return EVENT_ULTRAKILL;
    if (StrEqual(name, "MegaKill")) return EVENT_MEGAKILL;
    if (StrEqual(name, "MonsterKill")) return EVENT_MONSTERKILL;
    if (StrEqual(name, "Godlike")) return EVENT_GODLIKE;
    if (StrEqual(name, "Combo")) return EVENT_COMBO;
    if (StrEqual(name, "KnifeKill")) return EVENT_KNIFEKILL;
    if (StrEqual(name, "GrenadeKill")) return EVENT_GRENADEKILL;
    if (StrEqual(name, "Suicide")) return EVENT_SUICIDE;
    if (StrEqual(name, "TeamKill")) return EVENT_TEAMKILL;
    if (StrEqual(name, "JusticeKill")) return EVENT_JUSTICEKILL;
    if (StrEqual(name, "SpecialKill")) return EVENT_SPECIALKILL;
    if (StrEqual(name, "RifleKill")) return EVENT_RIFLEKILL;
    if (StrEqual(name, "SMGKill")) return EVENT_SMGKILL;
    if (StrEqual(name, "ShotgunKill")) return EVENT_SHOTGUNKILL;
    if (StrEqual(name, "SniperKill")) return EVENT_SNIPERKILL;
    if (StrEqual(name, "PistolKill")) return EVENT_PISTOLKILL;
    if (StrEqual(name, "MachineGunKill")) return EVENT_MACHINEGUNKILL;  // Added for M249
    if (StrEqual(name, "PlayerDisconnect")) return EVENT_PLAYER_DISCONNECT;
    if (StrEqual(name, "PlayerKick")) return EVENT_PLAYER_KICK;
    if (StrEqual(name, "PlayerVACBanned")) return EVENT_PLAYER_VAC_BANNED;
    return EVENT_COUNT;
}

// --- Unified Event Handling Functions ---

int GetRandomValidSoundIndex(SoundEventType eventType, int soundSet) // 0=regular, 1=CT, 2=T
{
    // Count valid sounds based on the sound set
    int validCount = 0;
    int maxCount;
    
    if (soundSet == 1) { // CT sounds
        maxCount = g_iCTSoundCount[eventType];
        // Count valid sounds in CT array
        for (int i = 0; i < maxCount; i++) {
            if (g_bCTValid[eventType][i]) {
                validCount++;
            }
        }
    } else if (soundSet == 2) { // T sounds
        maxCount = g_iTSoundCount[eventType];
        // Count valid sounds in T array
        for (int i = 0; i < maxCount; i++) {
            if (g_bTValid[eventType][i]) {
                validCount++;
            }
        }
    } else { // Regular sounds
        maxCount = g_iSoundsCount[eventType];
        // Count valid sounds in regular array
        for (int i = 0; i < maxCount; i++) {
            if (g_bSoundsValid[eventType][i]) {
                validCount++;
            }
        }
    }
    
    if (validCount == 0) {
        return -1; // No valid sounds
    }
    
    // Select a random valid sound
    int randomValidIndex = GetRandomInt(0, validCount - 1);
    int currentIndex = 0;
    
    if (soundSet == 1) { // CT sounds
        for (int i = 0; i < maxCount; i++) {
            if (g_bCTValid[eventType][i]) {
                if (currentIndex == randomValidIndex) {
                    return i; // Return the index of the randomly selected valid sound
                }
                currentIndex++;
            }
        }
    } else if (soundSet == 2) { // T sounds
        for (int i = 0; i < maxCount; i++) {
            if (g_bTValid[eventType][i]) {
                if (currentIndex == randomValidIndex) {
                    return i; // Return the index of the randomly selected valid sound
                }
                currentIndex++;
            }
        }
    } else { // Regular sounds
        for (int i = 0; i < maxCount; i++) {
            if (g_bSoundsValid[eventType][i]) {
                if (currentIndex == randomValidIndex) {
                    return i; // Return the index of the randomly selected valid sound
                }
                currentIndex++;
            }
        }
    }
    
    return -1; // Should not happen if validCount > 0
}

void PlaySoundEvent(SoundEventType eventType, int param1 = 0, int param2 = 0)
{
    // Skip notification for basic weapon kills as these are "banal" and should not be announced
    if (IsBasicWeaponKill(eventType)) {
        LogDebug(3, "[SM] Skipping sound/message for basic weapon kill event %d", eventType);
        return; // Don't play sounds or messages for basic weapon kill events
    }
    
    if (g_iSoundsCount[eventType] == 0 && g_iCTSoundCount[eventType] == 0 && g_iTSoundCount[eventType] == 0) {
        LogDebug(2, "[SM] No sounds configured for event %d", eventType);
        return;
    }
    
    // Check cooldown
    if (view_as<int>(eventType) < view_as<int>(EVENT_COUNT)) {
        if (GetGameTime() - g_fLastPlayedTime[eventType] < g_hCooldownInterval.FloatValue) {
            LogDebug(3, "[SM] Event %d on cooldown", eventType);
            return;
        }
    }
    
    // Determine which sound set to use based on teams
    int soundSetToUse = 0; // 0=regular, 1=CT, 2=T
    
    if (param1 > 0 && IsClientInGame(param1)) {
        int team = GetClientTeam(param1);
        if (team == 3 && g_iCTSoundCount[eventType] > 0) { // CT (in CS:S: 3 = CT, 2 = T)
            soundSetToUse = 1;
            LogDebug(3, "[SM] Using CT-specific sounds for event %d", eventType);
        } else if (team == 2 && g_iTSoundCount[eventType] > 0) { // T (in CS:S: 3 = CT, 2 = T)
            soundSetToUse = 2;
            LogDebug(3, "[SM] Using T-specific sounds for event %d", eventType);
        } else {
            soundSetToUse = 0;
            LogDebug(3, "[SM] Using default sounds for event %d", eventType);
        }
    } else {
        soundSetToUse = 0;
    }
    
    // Select random sound
    int soundIndex = GetRandomValidSoundIndex(eventType, soundSetToUse);
    if (soundIndex == -1) {
        LogDebug(1, "[SM] No valid sounds available for event %d", eventType);
        return;
    }
    
    // Determine the sound path based on the selected sound set
    char soundPath[PLATFORM_MAX_PATH];
    if (soundSetToUse == 1) { // CT sounds
        strcopy(soundPath, sizeof(soundPath), g_sCTSndPaths[eventType][soundIndex]);
    } else if (soundSetToUse == 2) { // T sounds
        strcopy(soundPath, sizeof(soundPath), g_sTSndPaths[eventType][soundIndex]);
    } else { // Regular sounds
        strcopy(soundPath, sizeof(soundPath), g_sSoundsPaths[eventType][soundIndex]);
    }
    
    // Update last played time
    if (view_as<int>(eventType) < view_as<int>(EVENT_COUNT)) {
        g_fLastPlayedTime[eventType] = GetGameTime();
    }
    
    // Play the selected sound to the appropriate audience
    PlaySoundToAudience(eventType, soundPath, param1, param2);
    
    LogDebug(3, "[SM] Played sound %s for event %d to appropriate audience", soundPath, eventType);
}

// Function to determine if event type is a basic weapon kill (should not be announced)
bool IsBasicWeaponKill(SoundEventType eventType)
{
    switch (eventType) {
        case EVENT_RIFLEKILL, EVENT_SMGKILL, EVENT_SHOTGUNKILL, 
             EVENT_SNIPERKILL, EVENT_PISTOLKILL, EVENT_MACHINEGUNKILL:
            return true;
        default:
            return false;
    }
}

void PlaySoundToAudience(SoundEventType eventType, const char[] soundPath, int param1, int param2)
{
    // Process each audience type
    for (int i = 0; i < g_iAudienceCount[eventType]; i++) {
        AudienceType audience = g_EventAudience[eventType][i];
        if (audience == AUDIENCE_KILLER) {
            if (param1 > 0 && IsClientInGame(param1) && g_bSoundEnabled[param1]) {
                EmitSoundToClient(param1, soundPath);
                LogDebug(3, "[SM] Played sound to killer: %N", param1);
            }
        } else if (audience == AUDIENCE_VICTIM) {
            if (param2 > 0 && IsClientInGame(param2) && g_bSoundEnabled[param2]) {
                EmitSoundToClient(param2, soundPath);
                LogDebug(3, "[SM] Played sound to victim: %N", param2);
            }
        } else if (audience == AUDIENCE_KILLER_TEAM) {
            int killerTeam = GetClientTeam(param1);
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && GetClientTeam(client) == killerTeam && g_bSoundEnabled[client]) {
                    EmitSoundToClient(client, soundPath);
                }
            }
        } else if (audience == AUDIENCE_VICTIM_TEAM) {
            int victimTeam = GetClientTeam(param2);
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && GetClientTeam(client) == victimTeam && g_bSoundEnabled[client]) {
                    EmitSoundToClient(client, soundPath);
                }
            }
        } else if (audience == AUDIENCE_ALL_ALIVE) {
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && IsPlayerAlive(client) && g_bSoundEnabled[client]) {
                    EmitSoundToClient(client, soundPath);
                }
            }
        } else if (audience == AUDIENCE_ALL) {
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && g_bSoundEnabled[client]) {
                    EmitSoundToClient(client, soundPath);
                }
            }
        }
    }
    
    // Show message to appropriate audience
    ShowMessageToAudience(eventType, param1, param2);
    
    // Show HUD message for key events
    ShowHudMessageToAudience(eventType, param1, param2);

    DispatchSoundManifestForward(eventType, param1, param2);
}

void ParseAudienceTypes(const char[] audienceStr, SoundEventType eventType)
{
    char tempStr[256];
    strcopy(tempStr, sizeof(tempStr), audienceStr);
    
    // Use ExplodeString to split by commas
    char parts[8][32]; // Maximum 8 audience types
    int partCount = ExplodeString(tempStr, ",", parts, 8, 32);
    
    // Process each part
    g_iAudienceCount[eventType] = 0;
    for (int i = 0; i < partCount && i < MAX_AUDIENCE_TYPES; i++) {
        TrimString(parts[i]); // Trim each part
        
        if (strlen(parts[i]) == 0) continue; // Skip empty parts
        
        if (StrEqual(parts[i], "killer", false)) {
            g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_KILLER;
        } else if (StrEqual(parts[i], "victim", false)) {
            g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_VICTIM;
        } else if (StrEqual(parts[i], "killer_team", false)) {
            g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_KILLER_TEAM;
        } else if (StrEqual(parts[i], "victim_team", false)) {
            g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_VICTIM_TEAM;
        } else if (StrEqual(parts[i], "all_alive", false)) {
            g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_ALL_ALIVE;
        } else if (StrEqual(parts[i], "all", false)) {
            g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_ALL;
        } else {
            LogDebug(1, "[SM] Invalid audience type '%s' for event, skipping", parts[i]);
            // Continue with other valid parts instead of using default for invalid part
        }
    }
    
    if (g_iAudienceCount[eventType] == 0) {
        // If no valid audience types were found, set default
        SetDefaultAudienceByEventType(eventType);
    }
    
    LogDebug(2, "[SM] Parsed %d audience types for event %d", g_iAudienceCount[eventType], eventType);
}

void SetDefaultAudienceByEventType(SoundEventType eventType)
{
    g_iAudienceCount[eventType] = 0;

    if (eventType == EVENT_FIRSTBLOOD || 
        eventType == EVENT_DOUBLEKILL || eventType == EVENT_TRIPLEKILL || eventType == EVENT_QUADKILL ||
        eventType == EVENT_MULTIKILL || eventType == EVENT_SUPERKILL || eventType == EVENT_ULTRAKILL ||
        eventType == EVENT_MEGAKILL || eventType == EVENT_MONSTERKILL || eventType == EVENT_GODLIKE ||
        eventType == EVENT_COMBO ||
        eventType == EVENT_SUICIDE || eventType == EVENT_TEAMKILL || eventType == EVENT_JUSTICEKILL) {
        g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_ALL;
    } else if (eventType == EVENT_HEADSHOT || eventType == EVENT_KNIFEKILL || eventType == EVENT_GRENADEKILL || eventType == EVENT_SPECIALKILL) {
        g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_KILLER;
        g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_VICTIM;
    } else if (eventType == EVENT_RIFLEKILL || eventType == EVENT_SMGKILL || eventType == EVENT_SHOTGUNKILL ||
               eventType == EVENT_SNIPERKILL || eventType == EVENT_PISTOLKILL || eventType == EVENT_MACHINEGUNKILL) {
        // No default audience
    } else {
        // Default for any other case
        g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_KILLER;
        g_EventAudience[eventType][g_iAudienceCount[eventType]++] = AUDIENCE_VICTIM;
    }
}

// Format translation phrase for a specific client and expand name tokens
void FormatLocalizedMessageForClient(const char[] phrase, int client, int param1, int param2, char[] buffer, int maxLen)
{
    FormatEx(buffer, maxLen, "%T", phrase, client, param1, param2);
    ExpandNameTokens(buffer, maxLen, param1, param2);
}

void ShowMessageToAudience(SoundEventType eventType, int param1, int param2)
{
    // Return if no message is configured
    if (strlen(g_sEventMessages[eventType]) == 0) {
        return;
    }
    
    // Pre-format a server-localized message for logging
    char sLogMessage[256];
    FormatLocalizedMessageForClient(g_sEventMessages[eventType], LANG_SERVER, param1, param2, sLogMessage, sizeof(sLogMessage));

    // Log the chat message to the server log if debug level is high enough
    if (g_hDebugLevel != null && g_hDebugLevel.IntValue >= 2) {
        LogMessage("[SM-SoundManifest-CHAT] %s", sLogMessage);
    }

    // If we're dealing with a client-specific event, only show to that client
    // Otherwise, follow the same audience pattern as the sound
    for (int i = 0; i < g_iAudienceCount[eventType]; i++) {
        AudienceType audience = g_EventAudience[eventType][i];
        if (audience == AUDIENCE_KILLER) {
            if (param1 > 0 && IsClientInGame(param1) && g_bSoundEnabled[param1]) {
                char sClientMessage[256];
                FormatLocalizedMessageForClient(g_sEventMessages[eventType], param1, param1, param2, sClientMessage, sizeof(sClientMessage));
                CPrintToChat(param1, sClientMessage);
                LogDebug(3, "[SM] Sent message to killer: %N", param1);
            }
        } else if (audience == AUDIENCE_VICTIM) {
            if (param2 > 0 && IsClientInGame(param2) && g_bSoundEnabled[param2]) {
                char sClientMessage[256];
                FormatLocalizedMessageForClient(g_sEventMessages[eventType], param2, param1, param2, sClientMessage, sizeof(sClientMessage));
                CPrintToChat(param2, sClientMessage);
                LogDebug(3, "[SM] Sent message to victim: %N", param2);
            }
        } else if (audience == AUDIENCE_KILLER_TEAM) {
            int killerTeam = GetClientTeam(param1);
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && GetClientTeam(client) == killerTeam && g_bSoundEnabled[client]) {
                    char sClientMessage[256];
                    FormatLocalizedMessageForClient(g_sEventMessages[eventType], client, param1, param2, sClientMessage, sizeof(sClientMessage));
                    CPrintToChat(client, sClientMessage);
                }
            }
        } else if (audience == AUDIENCE_VICTIM_TEAM) {
            int victimTeam = GetClientTeam(param2);
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && GetClientTeam(client) == victimTeam && g_bSoundEnabled[client]) {
                    char sClientMessage[256];
                    FormatLocalizedMessageForClient(g_sEventMessages[eventType], client, param1, param2, sClientMessage, sizeof(sClientMessage));
                    CPrintToChat(client, sClientMessage);
                }
            }
        } else if (audience == AUDIENCE_ALL_ALIVE) {
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && IsPlayerAlive(client) && g_bSoundEnabled[client]) {
                    char sClientMessage[256];
                    FormatLocalizedMessageForClient(g_sEventMessages[eventType], client, param1, param2, sClientMessage, sizeof(sClientMessage));
                    CPrintToChat(client, sClientMessage);
                }
            }
        } else if (audience == AUDIENCE_ALL) {
            for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && g_bSoundEnabled[client]) {
                    char sClientMessage[256];
                    FormatLocalizedMessageForClient(g_sEventMessages[eventType], client, param1, param2, sClientMessage, sizeof(sClientMessage));
                    CPrintToChat(client, sClientMessage);
                }
            }
        }
    }
}

// Function to convert event message key to HUD message key
void GetHudMessageKey(SoundEventType eventType, char[] output, int maxLen)
{
    switch (eventType) {
        case EVENT_FIRSTBLOOD: {
            strcopy(output, maxLen, "FirstBlood_HUD");
            return;
        }
        case EVENT_HEADSHOT: {
            strcopy(output, maxLen, "Headshot_HUD");
            return;
        }
        case EVENT_DOUBLEKILL: {
            strcopy(output, maxLen, "DoubleKill_HUD");
            return;
        }
        case EVENT_TRIPLEKILL: {
            strcopy(output, maxLen, "TripleKill_HUD");
            return;
        }
        case EVENT_QUADKILL: {
            strcopy(output, maxLen, "QuadKill_HUD");
            return;
        }
        case EVENT_MULTIKILL: {
            strcopy(output, maxLen, "MultiKill_HUD");
            return;
        }
        case EVENT_SUPERKILL: {
            strcopy(output, maxLen, "SuperKill_HUD");
            return;
        }
        case EVENT_ULTRAKILL: {
            strcopy(output, maxLen, "UltraKill_HUD");
            return;
        }
        case EVENT_MEGAKILL: {
            strcopy(output, maxLen, "MegaKill_HUD");
            return;
        }
        case EVENT_MONSTERKILL: {
            strcopy(output, maxLen, "MonsterKill_HUD");
            return;
        }
        case EVENT_GODLIKE: {
            strcopy(output, maxLen, "Godlike_HUD");
            return;
        }
        case EVENT_COMBO: {
            strcopy(output, maxLen, "Combo_HUD");
            return;
        }
        case EVENT_KNIFEKILL: {
            strcopy(output, maxLen, "KnifeKill_HUD");
            return;
        }
        case EVENT_GRENADEKILL: {
            strcopy(output, maxLen, "GrenadeKill_HUD");
            return;
        }
        case EVENT_SUICIDE: {
            strcopy(output, maxLen, "Suicide_HUD");
            return;
        }
        case EVENT_TEAMKILL: {
            strcopy(output, maxLen, "TeamKill_HUD");
            return;
        }
        case EVENT_JUSTICEKILL: {
            strcopy(output, maxLen, "JusticeKill_HUD");
            return;
        }
        case EVENT_SPECIALKILL: {
            strcopy(output, maxLen, "SpecialKill_HUD");
            return;
        }
        case EVENT_PLAYER_DISCONNECT: {
            strcopy(output, maxLen, "PlayerDisconnect_HUD");
            return;
        }
        case EVENT_PLAYER_KICK: {
            strcopy(output, maxLen, "PlayerKick_HUD");
            return;
        }
        case EVENT_PLAYER_VAC_BANNED: {
            strcopy(output, maxLen, "PlayerVACBanned_HUD");
            return;
        }
        default: {
            // For any other event, try to create HUD key by adding "_HUD" suffix
            // If we don't have a HUD translation for this event, we'll use the same key as chat
            strcopy(output, maxLen, g_sEventMessages[eventType]);
        }
    }
}

// Additional function to handle HUD messages for key events
void ShowHudMessageToAudience(SoundEventType eventType, int param1, int param2)
{
    // Only show HUD messages for key events (first blood, kill streaks, etc.)
    if (!IsKeyHudEvent(eventType)) {
        return;
    }
    
    // Show to all players
    char hudMessageKey[64];
    
    GetHudMessageKey(eventType, hudMessageKey, sizeof(hudMessageKey));
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && g_bSoundEnabled[i]) {
            char message[256];
            FormatLocalizedMessageForClient(hudMessageKey, i, param1, param2, message, sizeof(message));
            SendHudMessage(i,
                -1, -1.0, 0.25,   // channel and positions
                0xFFFFFFFF, 0xFFFFFFFF, // colors (Changed from Magenta to White)
                0, 0.5, 1.0, 2.0, 0.0, // fade in/out times
                message);
        }
    }
}

bool IsKeyHudEvent(SoundEventType eventType)
{
    switch (eventType) {
        case EVENT_FIRSTBLOOD, EVENT_TRIPLEKILL, EVENT_QUADKILL, 
             EVENT_MULTIKILL, EVENT_SUPERKILL, EVENT_ULTRAKILL, 
             EVENT_MEGAKILL, EVENT_MONSTERKILL, EVENT_GODLIKE:
            return true;
        default:
            return false;
    }
}

void LogDebug(int level, const char[] format, any...)
{
    if (g_hDebugLevel == null) {
        return;
    }
    
    int debugLevel = g_hDebugLevel.IntValue;
    
    if (level <= debugLevel) {
        char buffer[512];
        VFormat(buffer, sizeof(buffer), format, 3);
        
        if (debugLevel > 0) { // If any debug logging is on
            float gameTime = GetGameTime();
            if (level == 0) {
                LogError("[SM-SoundManifest][R:%d|T:%.2f] %s", g_iPersistentRoundCount, gameTime, buffer);
            } else {
                PrintToServer("[SM-SoundManifest-DEBUG-%d][R:%d|T:%.2f] %s", level, g_iPersistentRoundCount, gameTime, buffer);
            }
        } else { // Only log errors if debug is 0
             if (level == 0) {
                LogError("[SM-SoundManifest] %s", buffer);
            }
        }
    }
}

// --- Event Handlers ---

public void OnRoundStart(Event event, const char[] name, bool silent)
{
    g_iPersistentRoundCount++; // Increment for logging

    // Fixed: Reset total kills for the round to properly handle FirstBlood
    g_iTotalKillsThisRound = 0;
    
    for (int i = 1; i <= MaxClients; i++) {
        g_iKillstreak[i] = 0;
        g_fLastKillTime[i] = 0.0;
        g_iLastKillCount[i] = 0;
        g_iEpicStreak[i] = 0;
        g_iAnnouncedStreakLevel[i] = 0; // Reset announced streak level
        // g_iPlayerTeamkills is not reset here, as it tracks across rounds/maps for JusticeKill
        g_sLastWeaponType[i][0] = '\0';
    }
    
    for (int i = 0; i < view_as<int>(EVENT_COUNT); i++) {
        g_fLastPlayedTime[i] = 0.0;
    }
    
    LogDebug(2, "[SM] Round started, all kill counters reset");
}

public void OnPlayerDeath(Event event, const char[] name, bool silent)
{
    if (!g_hEnabled.BoolValue) return;

    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
    char sWeapon[64];
    event.GetString("weapon", sWeapon, sizeof(sWeapon));
    bool bHeadshot = event.GetBool("headshot");

    // Reset victim's killstreak/combo/epicstreak if they die
    if (iVictim > 0) {
        g_iKillstreak[iVictim] = 0;
        g_iLastKillCount[iVictim] = 0;
        g_iEpicStreak[iVictim] = 0;
    }

    // --- Event Selection Logic ---
    SoundEventType eventType = EVENT_COUNT;
    int iEventParam = 0; // Used for combo count, etc.

    // 1. Suicide Check (Highest Priority, immediate return)
    if (iAttacker == 0 || iAttacker == iVictim) {
        PlaySoundEvent(EVENT_SUICIDE, iVictim, 0);
        return;
    }

    // 2. Teamkill Check (High Priority, immediate return)
    if (GetClientTeam(iAttacker) == GetClientTeam(iVictim)) {
        PlaySoundEvent(EVENT_TEAMKILL, iAttacker, iVictim);
        g_iPlayerTeamkills[iVictim]++; // Increment victim's teamkill count
        // Reset killer's progress as per scheme
        g_iKillstreak[iAttacker] = 0;
        g_iLastKillCount[iAttacker] = 0;
        g_iEpicStreak[iAttacker] = 0;
        return;
    }

    // 3. JusticeKill Check (High Priority, immediate return if triggered)
    if (g_iPlayerTeamkills[iVictim] >= g_hJusticeKillThreshold.IntValue) {
        PlaySoundEvent(EVENT_JUSTICEKILL, iAttacker, iVictim);
        g_iPlayerTeamkills[iVictim] = 0; // Reset victim's teamkill count after justice
        return;
    }

    // Increment total kills for the round - FIXED: This was the main issue with FirstBlood
    g_iTotalKillsThisRound++;

    // Update killstreak and combo counters
    if (GetGameTime() - g_fLastKillTime[iAttacker] <= g_hComboKillTime.FloatValue) {
        g_iKillstreak[iAttacker]++;
        g_iLastKillCount[iAttacker]++;
    } else {
        g_iKillstreak[iAttacker] = 1;
        g_iLastKillCount[iAttacker] = 1;
    }
    g_fLastKillTime[iAttacker] = GetGameTime();

    // Update epic streak
    g_iEpicStreak[iAttacker]++;

    // --- Determine the event type based on the hierarchy ---
    // Unique Event: FirstBlood - FIXED: Now properly checks if it's the first kill of the round
    if (g_iTotalKillsThisRound == 1) {
        eventType = EVENT_FIRSTBLOOD;
        LogDebug(2, "[SM] FirstBlood detected (total kills now: %d)", g_iTotalKillsThisRound);
    }

    // Secondary Events: Killstreaks
    if (eventType == EVENT_COUNT) { // Only check killstreaks if first blood didn't occur
        if (g_iKillstreak[iAttacker] == 2) {
            eventType = EVENT_DOUBLEKILL;
        } else if (g_iKillstreak[iAttacker] == 3) {
            eventType = EVENT_TRIPLEKILL;
        } else if (g_iKillstreak[iAttacker] == g_hQuadKillThreshold.IntValue) {
            eventType = EVENT_QUADKILL;
        }
    }

    // Tertiary Events: Epic Streaks (MultiKill, SuperKill, etc.) - FIXED: Now properly tracks announced levels
    if (eventType == EVENT_COUNT && g_iEpicStreak[iAttacker] >= g_hEpicStreakThreshold.IntValue) {
        if (g_iEpicStreak[iAttacker] >= 10 && g_iAnnouncedStreakLevel[iAttacker] < 6) {
            eventType = EVENT_GODLIKE;
            g_iAnnouncedStreakLevel[iAttacker] = 6;
        } else if (g_iEpicStreak[iAttacker] == 9 && g_iAnnouncedStreakLevel[iAttacker] < 5) {
            eventType = EVENT_MONSTERKILL;
            g_iAnnouncedStreakLevel[iAttacker] = 5;
        } else if (g_iEpicStreak[iAttacker] == 8 && g_iAnnouncedStreakLevel[iAttacker] < 4) {
            eventType = EVENT_MEGAKILL;
            g_iAnnouncedStreakLevel[iAttacker] = 4;
        } else if (g_iEpicStreak[iAttacker] == 7 && g_iAnnouncedStreakLevel[iAttacker] < 3) {
            eventType = EVENT_ULTRAKILL;
            g_iAnnouncedStreakLevel[iAttacker] = 3;
        } else if (g_iEpicStreak[iAttacker] == 6 && g_iAnnouncedStreakLevel[iAttacker] < 2) {
            eventType = EVENT_SUPERKILL;
            g_iAnnouncedStreakLevel[iAttacker] = 2;
        } else if (g_iEpicStreak[iAttacker] == 5 && g_iAnnouncedStreakLevel[iAttacker] < 1) {
            eventType = EVENT_MULTIKILL;
            g_iAnnouncedStreakLevel[iAttacker] = 1;
        }
    }

    // Combo event if not already set
    if (eventType == EVENT_COUNT && g_iLastKillCount[iAttacker] >= 2) {
        eventType = EVENT_COMBO;
        iEventParam = g_iLastKillCount[iAttacker]; // Pass combo count as parameter
    }

    // Primary Events: Headshot & Weapon-Specific Kills - FIXED: Now includes MachineGunKill
    if (eventType == EVENT_COUNT) {
        if (bHeadshot) {
            eventType = EVENT_HEADSHOT;
        } else {
            WeaponType weaponType = GetWeaponType(sWeapon);

            if (weaponType == WEAPON_TYPE_RIFLE) {
                eventType = EVENT_RIFLEKILL;
            } else if (weaponType == WEAPON_TYPE_SMG) {
                eventType = EVENT_SMGKILL;
            } else if (weaponType == WEAPON_TYPE_SHOTGUN) {
                eventType = EVENT_SHOTGUNKILL;
            } else if (weaponType == WEAPON_TYPE_SNIPER) {
                eventType = EVENT_SNIPERKILL;
            } else if (weaponType == WEAPON_TYPE_PISTOL) {
                eventType = EVENT_PISTOLKILL;
            } else if (weaponType == WEAPON_TYPE_MACHINEGUN) { // Added for M249
                eventType = EVENT_MACHINEGUNKILL;
            } else if (weaponType == WEAPON_TYPE_GRENADE) {
                eventType = EVENT_GRENADEKILL;
            } else if (weaponType == WEAPON_TYPE_KNIFE) {
                eventType = EVENT_KNIFEKILL;
            } else {
                // SpecialKill for unknown/other weapon types
                eventType = EVENT_SPECIALKILL;
            }
        }
    }

    // Ensure we have a valid event type before proceeding
    if (eventType != EVENT_COUNT) {
        // For EVENT_COMBO we pass the combo count as param2, for all other events we pass the victim
        int param2 = (eventType == EVENT_COMBO) ? iEventParam : iVictim;
        PlaySoundEvent(eventType, iAttacker, param2);
        LogDebug(3, "[SM] Event processed: %d, attacker: %N, param2: %d", eventType, iAttacker, param2);
    } else {
        LogDebug(1, "[SM] No suitable event type found for kill");
    }
}

public void OnPlayerDisconnect(Event event, const char[] name, bool silent)
{
    if (!g_hEnabled.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    char sReason[256];
    event.GetString("reason", sReason, sizeof(sReason));

    if (StrContains(sReason, "VAC", false) != -1) {
        PlaySoundEvent(EVENT_PLAYER_VAC_BANNED, client, 0);
    } else if (StrContains(sReason, "Kicked", false) != -1 || StrContains(sReason, "Banned", false) != -1) {
        PlaySoundEvent(EVENT_PLAYER_KICK, client, 0);
    } else {
        PlaySoundEvent(EVENT_PLAYER_DISCONNECT, client, 0);
    }
}

// --- Client Management ---

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client) || !g_hEnabled.BoolValue) return;

    char sCookie[4];
    GetClientCookie(client, g_hCookieSoundPref, sCookie, sizeof(sCookie));

    if (sCookie[0] == '\0') {
        // Cookie is not set, use the default cvar value.
        g_bSoundEnabled[client] = g_hDefaultSetting.BoolValue;
        LogDebug(3, "[SM] Client %d has no sound cookie, using default cvar value: %d", client, g_hDefaultSetting.BoolValue);
    } else if (StrEqual(sCookie, "0")) {
        // Cookie is "0", disable sounds.
        g_bSoundEnabled[client] = false;
        LogDebug(3, "[SM] Client %d sound cookie is '0', disabling sounds.", client);
    } else {
        // Cookie is "1" or anything else, enable sounds.
        g_bSoundEnabled[client] = true;
        LogDebug(3, "[SM] Client %d sound cookie is '%s', enabling sounds.", client, sCookie);
    }

    if (GetGameTime() - float(g_iLastWelcomeSoundTime) < g_hJoinInterval.FloatValue) return;

    // Using a timer to ensure the player is fully connected
    CreateTimer(g_hJoinDelay.FloatValue, Timer_PlayWelcomeSound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PlayWelcomeSound(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client) || !g_bSoundEnabled[client]) return Plugin_Stop;

    // Determine which group of sounds to use based on admin status
    int iTargetGroup = -1;
    AdminId admin = GetUserAdmin(client);

    if (admin != INVALID_ADMIN_ID) {
        for (int i = 0; i < g_iWelcomeGroupCount; i++) {
            if (g_sWelcomeGroupFlags[i][0] != '\0' && GetAdminFlags(admin, Access_Effective) & ReadFlagString(g_sWelcomeGroupFlags[i])) {
                if (g_iWelcomeSoundCounts[i] > 0) {
                    iTargetGroup = i;
                    break;
                }
            }
        }
    }

    // If no specific admin group matched, or admin group has no sounds, use default
    if (iTargetGroup == -1 && g_iDefaultGroupIndex != -1 && g_iWelcomeSoundCounts[g_iDefaultGroupIndex] > 0) {
        iTargetGroup = g_iDefaultGroupIndex;
    }

    if (iTargetGroup != -1) {
        // Randomly select a sound from the available ones
        int iSoundIndex = GetRandomInt(0, g_iWelcomeSoundCounts[iTargetGroup] - 1);
        char sSound[PLATFORM_MAX_PATH];
        strcopy(sSound, sizeof(sSound), g_sWelcomeSoundPaths[iTargetGroup][iSoundIndex]);

        // Play to appropriate audience
        if (g_hJoinAudience.BoolValue) {
            // Play to everyone
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && g_bSoundEnabled[i]) {
                    EmitSoundToClient(i, sSound);
                }
            }
        } else {
            // Play only to the joining player
            EmitSoundToClient(client, sSound);
        }

        g_iLastWelcomeSoundTime = RoundToZero(GetGameTime());
        LogDebug(2, "[SM] Played welcome sound %s to client %N", sSound, client);
    } else {
        LogDebug(1, "[SM] No welcome sounds available for client %N", client);
    }

    return Plugin_Stop;
}

// --- Weapon Type Classification ---

enum WeaponType {
    WEAPON_TYPE_UNKNOWN,
    WEAPON_TYPE_RIFLE,
    WEAPON_TYPE_SMG,
    WEAPON_TYPE_SHOTGUN,
    WEAPON_TYPE_SNIPER,
    WEAPON_TYPE_PISTOL,
    WEAPON_TYPE_GRENADE,
    WEAPON_TYPE_KNIFE,
    WEAPON_TYPE_MACHINEGUN  // Added for M249
};

WeaponType GetWeaponType(const char[] sWeapon) {
    if (StrContains(sWeapon, "knife", false) != -1) return WEAPON_TYPE_KNIFE;
    if (StrContains(sWeapon, "hegrenade", false) != -1) return WEAPON_TYPE_GRENADE;

    // Rifles
    if (StrEqual(sWeapon, "galil") || StrEqual(sWeapon, "famas") || StrEqual(sWeapon, "ak47") || StrEqual(sWeapon, "m4a1") || StrEqual(sWeapon, "sg552") || StrEqual(sWeapon, "aug")) {
        return WEAPON_TYPE_RIFLE;
    }
    // SMGs
    if (StrEqual(sWeapon, "mp5navy") || StrEqual(sWeapon, "tmp") || StrEqual(sWeapon, "p90") || StrEqual(sWeapon, "mac10") || StrEqual(sWeapon, "ump45")) {
        return WEAPON_TYPE_SMG;
    }
    // Shotguns
    if (StrEqual(sWeapon, "m3") || StrEqual(sWeapon, "xm1014")) {
        return WEAPON_TYPE_SHOTGUN;
    }
    // Snipers
    if (StrEqual(sWeapon, "scout") || StrEqual(sWeapon, "sg550") || StrEqual(sWeapon, "awp") || StrEqual(sWeapon, "g3sg1")) {
        return WEAPON_TYPE_SNIPER;
    }
    // Pistols
    if (StrEqual(sWeapon, "glock") || StrEqual(sWeapon, "usp") || StrEqual(sWeapon, "p228") || StrEqual(sWeapon, "deagle") || StrEqual(sWeapon, "elite") || StrEqual(sWeapon, "fiveseven")) {
        return WEAPON_TYPE_PISTOL;
    }
    // Machine Gun - ADDING SUPPORT FOR M249
    if (StrEqual(sWeapon, "m249")) {
        return WEAPON_TYPE_MACHINEGUN;
    }

    return WEAPON_TYPE_UNKNOWN;
}

// --- Player Settings Menu ---

public Action Command_SoundMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;

    Menu menu = new Menu(Handler_SoundMenu);
    menu.SetTitle("%T", "SoundMenu_Title", client);

    char toggleText[64];
    if (g_bSoundEnabled[client]) {
        FormatEx(toggleText, sizeof(toggleText), "%T", "SoundMenu_ToggleOn", client);
    } else {
        FormatEx(toggleText, sizeof(toggleText), "%T", "SoundMenu_ToggleOff", client);
    }

    menu.AddItem("toggle", toggleText);
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int Handler_SoundMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select && item == 0) {
        g_bSoundEnabled[client] = !g_bSoundEnabled[client];

        char sCookieValue[4];
        IntToString(view_as<int>(g_bSoundEnabled[client]), sCookieValue, sizeof(sCookieValue));
        SetClientCookie(client, g_hCookieSoundPref, sCookieValue);

        if (g_bSoundEnabled[client]) {
            CPrintToChat(client, "%t", "SoundMenu_Enabled");
        } else {
            CPrintToChat(client, "%t", "SoundMenu_Disabled");
        }

        // Reopen the menu to show updated settings
        Command_SoundMenu(client, 0);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

// --- Utility Functions ---

void ExpandNameTokens(char[] buffer, int maxLen, int killer, int victim)
{
    char killerName[MAX_NAME_LENGTH];
    char victimName[MAX_NAME_LENGTH];

    if (killer > 0 && IsClientInGame(killer))
    {
        GetClientName(killer, killerName, sizeof(killerName));
    }
    else
    {
        strcopy(killerName, sizeof(killerName), "Unknown");
    }

    if (victim > 0 && IsClientInGame(victim))
    {
        GetClientName(victim, victimName, sizeof(victimName));
    }
    else
    {
        strcopy(victimName, sizeof(victimName), "Unknown");
    }

    ReplaceString(buffer, maxLen, "{1:N}", killerName, false);
    ReplaceString(buffer, maxLen, "{2:N}", victimName, false);
}

void DispatchSoundManifestForward(SoundEventType eventType, int killer, int victim)
{
    if (g_hEventForward == null)
    {
        return;
    }

    Call_StartForward(g_hEventForward);
    Call_PushCell(eventType);
    Call_PushCell(killer);
    Call_PushCell(victim);
    Call_Finish();
}

// --- Final functions to complete the plugin ---




// Function to reset all event cooldowns (for debugging purposes)
public Action Command_ResetCooldowns(int client, int args)
{
    if (client != 0) {
        CPrintToChat(client, "%t", "ResetCooldowns");
    } else {
        PrintToServer("[SM] Resetting all event cooldowns");
    }
    
    for (int i = 0; i < view_as<int>(EVENT_COUNT); i++) {
        g_fLastPlayedTime[i] = 0.0;
    }
    
    return Plugin_Handled;
}
