#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zh_core>

#define PLUGIN_VERSION "0.2.0-dev"
#define MST_LIBRARY "zh_mst"

// Ability flags mirror zh_mst.inc
enum MSTAbilityFlags
{
    MSTAbility_None              = 0,
    MSTAbility_Revive            = 1 << 0,
    MSTAbility_Turret            = 1 << 1,
    MSTAbility_Barricade         = 1 << 2,
    MSTAbility_GrenadeLauncher   = 1 << 3,
    MSTAbility_SpecialVision     = 1 << 4,
    MSTAbility_FlashlightForce   = 1 << 5,
    MSTAbility_SpeedScout        = 1 << 6,
    MSTAbility_ShieldCarrier     = 1 << 7,
    MSTAbility_GasImmunity       = 1 << 8,
    MSTAbility_EngineerToolset   = 1 << 9
};

enum ClassFields
{
    ClassId,
    ClassAbilityFlags,
    ClassTeamMask
};

#define TEAMMASK_T      (1 << 0)
#define TEAMMASK_CT     (1 << 1)
#define TEAMMASK_ANY    (TEAMMASK_T | TEAMMASK_CT)

ConVar g_CvarMstMode;
ConVar g_CvarMstDebug;
ConVar g_CvarMstAutoAssign;
ConVar g_CvarMstModeTDM;
ConVar g_CvarMstModeDM;
ConVar g_CvarMstModeGG;
ConVar g_CvarMstModeChicken;
ConVar g_CvarMstModeRevive;

char g_MainConfig[PLATFORM_MAX_PATH];
bool g_ConfigsLoaded;
bool g_AutoAssign;
int g_DefaultClassT = -1;
int g_DefaultClassCT = -1;
int g_DefaultClassSpec = -1;

int g_ClientClass[MAXPLAYERS + 1];
ArrayList g_ClassDefs;
StringMap g_ClassNames;
StringMap g_ClassModels;
StringMap g_ClassSounds;
ArrayList g_DownloadModels;
ArrayList g_DownloadSounds;

Handle g_fwdClassChanged;

public Plugin myinfo =
{
    name = "ZH-sys MST (ModelSwitchTool)",
    author = "ZloyHohol integration workbench",
    description = "Model/class switch manager skeleton for ZH-sys.",
    version = PLUGIN_VERSION,
    url = ""
};

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int errMax)
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        strcopy(error, errMax, "zh_core is required for mst.");
        return APLRes_Failure;
    }

    RegPluginLibrary(MST_LIBRARY);
    CreateNative("MST_DefineClass", Native_DefineClass);
    CreateNative("MST_SetClientClass", Native_SetClientClass);
    CreateNative("MST_GetClientClass", Native_GetClientClass);
    CreateNative("MST_GetClassAbilityFlags", Native_GetClassAbilityFlags);
    CreateNative("MST_GetClassModel", Native_GetClassModel);
    CreateNative("MST_GetClassName", Native_GetClassName);
    CreateNative("MST_GetClassSoundProfile", Native_GetClassSoundProfile);
    CreateNative("MST_RegisterModel", Native_RegisterModel);
    CreateNative("MST_RegisterSound", Native_RegisterSound);
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("zh_core.phrases");

    g_CvarMstMode = CreateConVar("zh_mst_mode", "1", "0=disabled,1=generic,2=generic+by-choice,3=map-specific merge.", _, true, 0.0, true, 3.0);
    g_CvarMstDebug = CreateConVar("zh_mst_debug", "0", "Enables extra MST debug output.");
    g_CvarMstAutoAssign = CreateConVar("zh_mst_autoassign", "1", "Auto-assign default class per team on join.");
    g_CvarMstModeDM = CreateConVar("zh_mode_dm", "0", "Enable Deathmatch modifiers (auto respawn etc).");
    g_CvarMstModeTDM = CreateConVar("zh_mode_tdm", "0", "Enable Team Deathmatch modifiers.");
    g_CvarMstModeGG = CreateConVar("zh_mode_gg", "0", "Enable GunGame modifiers.");
    g_CvarMstModeChicken = CreateConVar("zh_mode_chicken", "0", "Enable Chicken Fight mode.");
    g_CvarMstModeRevive = CreateConVar("zh_mode_revive", "0", "Enable revive module (should be off for DM).");

    AutoExecConfig(true, "zh_mst", "sourcemod");

    ResolveConfigPaths();

    RegAdminCmd("sm_mst_reload", Command_ReloadMst, ADMFLAG_CONFIG, "Reloads MST configs.");
    RegAdminCmd("sm_mst_mode", Command_SetMode, ADMFLAG_GENERIC, "Set mode flags (dm/tdm/gg/chicken/revive).");

    g_ClassDefs = new ArrayList(3); // ClassId + AbilityFlags + TeamMask
    g_ClassNames = new StringMap();
    g_ClassModels = new StringMap();
    g_ClassSounds = new StringMap();
    g_DownloadModels = new ArrayList(PLATFORM_MAX_PATH);
    g_DownloadSounds = new ArrayList(PLATFORM_MAX_PATH);

    g_fwdClassChanged = CreateGlobalForward("MST_OnClassChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);

    ResetClientClasses();

    ZH_RegisterModule("mst");
}

public void OnConfigsExecuted()
{
    LoadMstConfigs();
}

public void OnMapStart()
{
    PrecacheRegisteredResources();
}

public void OnClientDisconnect(int client)
{
    g_ClientClass[client] = -1;
}

public void OnClientPutInServer(int client)
{
    g_ClientClass[client] = -1;

    // Delay to allow team assignment to settle for bots/players.
    CreateTimer(0.2, Timer_AssignDefaultClass, GetClientUserId(client));
}

// --- Natives -----------------------------------------------------------------

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

public any Native_SetClientClass(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int classId = GetNativeCell(2);

    char reason[64];
    GetNativeString(3, reason, sizeof(reason));

    return SetClientClassInternal(client, classId, reason);
}

public any Native_GetClientClass(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
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

// --- Commands ----------------------------------------------------------------

public Action Command_ReloadMst(int client, int args)
{
    LoadMstConfigs();
    ReplyToCommand(client, "[ZH-MST] Configs reloaded.");
    return Plugin_Handled;
}

public Action Command_SetMode(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "Usage: sm_mst_mode <mode> <0/1> (modes: dm,tdm,gg,chicken,revive)");
        return Plugin_Handled;
    }

    char mode[16];
    GetCmdArg(1, mode, sizeof(mode));
    int value = StringToInt(GetCmdArgString(2));

    if (StrEqual(mode, "dm", false))
    {
        g_CvarMstModeDM.SetInt(value);
    }
    else if (StrEqual(mode, "tdm", false))
    {
        g_CvarMstModeTDM.SetInt(value);
    }
    else if (StrEqual(mode, "gg", false))
    {
        g_CvarMstModeGG.SetInt(value);
    }
    else if (StrEqual(mode, "chicken", false))
    {
        g_CvarMstModeChicken.SetInt(value);
    }
    else if (StrEqual(mode, "revive", false))
    {
        g_CvarMstModeRevive.SetInt(value);
    }
    else
    {
        ReplyToCommand(client, "Unknown mode: %s", mode);
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[ZH-MST] %s set to %d", mode, value);
    return Plugin_Handled;
}

// --- Internals ---------------------------------------------------------------

void ResolveConfigPaths()
{
    ZH_BuildConfigPath(ZHConfig_MST, "MST-main-config.cfg", g_MainConfig, sizeof(g_MainConfig));
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
    KeyValues defaults = kv.FindKey("defaults");
    if (defaults == null)
    {
        g_DefaultClassT = -1;
        g_DefaultClassCT = -1;
        g_DefaultClassSpec = -1;
        return;
    }

    g_DefaultClassT = defaults.GetNum("t", g_DefaultClassT);
    g_DefaultClassCT = defaults.GetNum("ct", g_DefaultClassCT);
    g_DefaultClassSpec = defaults.GetNum("spec", g_DefaultClassSpec);
}

void LoadClasses(KeyValues kv)
{
    KeyValues kvClasses = kv.FindKey("classes");
    if (kvClasses == null || !kvClasses.GotoFirstSubKey(false))
    {
        return;
    }

    do
    {
        char keyName[32];
        kvClasses.GetName(keyName, sizeof(keyName));
        int classId = StringToInt(keyName);

        char name[64];
        char model[PLATFORM_MAX_PATH];
        char sound[64];
        kvClasses.GetString("name", name, sizeof(name));
        kvClasses.GetString("model", model, sizeof(model));
        kvClasses.GetString("sound", sound, sizeof(sound));

        int flags = kvClasses.GetNum("flags", 0);

        char flagsText[128];
        kvClasses.GetString("flags_text", flagsText, sizeof(flagsText));
        if (flagsText[0] != '\0')
        {
            flags = ParseAbilityFlags(flagsText, flags);
        }

        int teamMask = TEAMMASK_ANY;
        char teamText[64];
        kvClasses.GetString("teams", teamText, sizeof(teamText));
        if (teamText[0] != '\0')
        {
            teamMask = ParseTeamMask(teamText, TEAMMASK_ANY);
        }

        DefineOrUpdateClass(classId, name, model, sound, flags, teamMask);
    }
    while (kvClasses.GotoNextKey(false));

    kvClasses.GoBack();
}

void LoadDownloads(KeyValues kv)
{
    KeyValues dl = kv.FindKey("downloads");
    if (dl == null)
    {
        return;
    }

    KeyValues models = dl.FindKey("models");
    if (models != null && models.GotoFirstSubKey(false))
    {
        do
        {
            char path[PLATFORM_MAX_PATH];
            models.GetString(NULL_STRING, path, sizeof(path), "");
            if (path[0] != '\0')
            {
                PushUniqueString(g_DownloadModels, path);
            }
        }
        while (models.GotoNextKey(false));
        models.GoBack();
    }

    KeyValues sounds = dl.FindKey("sounds");
    if (sounds != null && sounds.GotoFirstSubKey(false))
    {
        do
        {
            char path[PLATFORM_MAX_PATH];
            sounds.GetString(NULL_STRING, path, sizeof(path), "");
            if (path[0] != '\0')
            {
                PushUniqueString(g_DownloadSounds, path);
            }
        }
        while (sounds.GotoNextKey(false));
        sounds.GoBack();
    }
}

void DefineOrUpdateClass(int classId, const char[] name, const char[] model, const char[] sound, int flags, int teamMask = TEAMMASK_ANY)
{
    SetNumericValueForClass(classId, flags);
    SetTeamValueForClass(classId, teamMask);
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
        ZH_LogInfo("Defined class %d (%s) flags=%d model=%s sound=%s", classId, name, flags, model, sound);
    }
}

bool SetClientClassInternal(int client, int classId, const char[] reason)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
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

void SetNumericValueForClass(int classId, int flags)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        idx = g_ClassDefs.Push(0);
        g_ClassDefs.Set(idx, classId, ClassId);
        g_ClassDefs.Set(idx, TEAMMASK_ANY, ClassTeamMask);
    }
    g_ClassDefs.Set(idx, flags, ClassAbilityFlags);
}

void SetTeamValueForClass(int classId, int teamMask)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        idx = g_ClassDefs.Push(0);
        g_ClassDefs.Set(idx, classId, ClassId);
    }
    g_ClassDefs.Set(idx, teamMask, ClassTeamMask);
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

void PushUniqueString(ArrayList list, const char[] value)
{
    char existing[PLATFORM_MAX_PATH];
    for (int i = 0; i < list.Length; i++)
    {
        list.GetString(i, existing, sizeof(existing));
        if (StrEqual(existing, value, false))
        {
            return;
        }
    }
    list.PushString(value);
}

void PrecacheRegisteredResources()
{
    char path[PLATFORM_MAX_PATH];

    for (int i = 0; i < g_DownloadModels.Length; i++)
    {
        g_DownloadModels.GetString(i, path, sizeof(path));
        if (path[0] == '\0')
        {
            continue;
        }
        PrecacheModel(path, true);
        AddFileToDownloadsTable(path);
    }

    for (int j = 0; j < g_DownloadSounds.Length; j++)
    {
        g_DownloadSounds.GetString(j, path, sizeof(path));
        if (path[0] == '\0')
        {
            continue;
        }
        PrecacheSound(path, true);
        AddFileToDownloadsTable(path);
    }
}

Action Timer_AssignDefaultClass(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client))
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
    return Plugin_Stop;
}

int GetDefaultClassForTeam(int team)
{
    if (team == 2)
    {
        return g_DefaultClassT;
    }
    else if (team == 3)
    {
        return g_DefaultClassCT;
    }
    else
    {
        return g_DefaultClassSpec;
    }
}

bool IsClassAllowedForTeam(int classId, int team)
{
    int mask = GetTeamMaskForClass(classId);
    if (mask == TEAMMASK_ANY)
    {
        return true;
    }

    if (team == 2 && (mask & TEAMMASK_T) != 0)
    {
        return true;
    }
    if (team == 3 && (mask & TEAMMASK_CT) != 0)
    {
        return true;
    }
    return false;
}

int ParseAbilityFlags(const char[] text, int fallback)
{
    if (text[0] == '\0')
    {
        return fallback;
    }

    bool numeric = true;
    for (int i = 0; i < strlen(text); i++)
    {
        if (!IsCharNumeric(text[i]))
        {
            numeric = false;
            break;
        }
    }
    if (numeric)
    {
        return StringToInt(text);
    }

    int mask = 0;
    char buffer[256];
    strcopy(buffer, sizeof(buffer), text);

    char token[64];
    int idx = 0;
    while ((idx = SplitString(buffer, "|,; ", token, sizeof(token), idx)) != -1)
    {
        TrimString(token);
        if (token[0] == '\0')
        {
            continue;
        }

        if (StrEqual(token, "revive", false) || StrEqual(token, "medic", false))
        {
            mask |= MSTAbility_Revive;
        }
        else if (StrEqual(token, "turret", false) || StrEqual(token, "sentry", false))
        {
            mask |= MSTAbility_Turret;
        }
        else if (StrEqual(token, "barricade", false) || StrEqual(token, "cover", false))
        {
            mask |= MSTAbility_Barricade;
        }
        else if (StrEqual(token, "grenadelauncher", false) || StrEqual(token, "explosive", false) || StrEqual(token, "demolition", false))
        {
            mask |= MSTAbility_GrenadeLauncher;
        }
        else if (StrEqual(token, "vision", false) || StrEqual(token, "nvg", false) || StrEqual(token, "thermal", false))
        {
            mask |= MSTAbility_SpecialVision;
        }
        else if (StrEqual(token, "flashlight", false) || StrEqual(token, "lamp", false))
        {
            mask |= MSTAbility_FlashlightForce;
        }
        else if (StrEqual(token, "scout", false) || StrEqual(token, "speed", false) || StrEqual(token, "recon", false))
        {
            mask |= MSTAbility_SpeedScout;
        }
        else if (StrEqual(token, "shield", false))
        {
            mask |= MSTAbility_ShieldCarrier;
        }
        else if (StrEqual(token, "gas", false) || StrEqual(token, "hazmat", false) || StrEqual(token, "smoke", false))
        {
            mask |= MSTAbility_GasImmunity;
        }
        else if (StrEqual(token, "engineer", false) || StrEqual(token, "tools", false))
        {
            mask |= MSTAbility_EngineerToolset;
        }
    }

    return (mask == 0) ? fallback : mask;
}

int ParseTeamMask(const char[] text, int fallback)
{
    if (text[0] == '\0')
    {
        return fallback;
    }

    int mask = 0;
    char buffer[128];
    strcopy(buffer, sizeof(buffer), text);

    char token[32];
    int idx = 0;
    while ((idx = SplitString(buffer, "|,; ", token, sizeof(token), idx)) != -1)
    {
        TrimString(token);
        if (token[0] == '\0')
        {
            continue;
        }

        if (StrEqual(token, "t", false) || StrEqual(token, "terrorist", false))
        {
            mask |= TEAMMASK_T;
        }
        else if (StrEqual(token, "ct", false) || StrEqual(token, "counter", false))
        {
            mask |= TEAMMASK_CT;
        }
        else if (StrEqual(token, "any", false) || StrEqual(token, "both", false) || StrEqual(token, "all", false))
        {
            mask |= TEAMMASK_ANY;
        }
    }

    return (mask == 0) ? fallback : mask;
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
