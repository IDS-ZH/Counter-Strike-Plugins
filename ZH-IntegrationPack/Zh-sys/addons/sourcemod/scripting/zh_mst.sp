#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zh_core>

#define PLUGIN_VERSION "0.2.1-dev"
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

// Skin type enumeration
enum SkinType
{
    SkinType_Regular = 0,     // Обычный/стандартный скин
    SkinType_Female,          // Женский скин
    SkinType_Robot,           // Робот/киборг скин
    SkinType_LongSleeve,      // Скин с длинным рукавом
    SkinType_Animal,          // Животное
    SkinType_Monster          // Чудовище
};

// Типы видов от третьего лица
enum ThirdPersonMode
{
    ThirdPersonMode_FirstPerson = 0,      // 0: Обычный вид от первого лица
    ThirdPersonMode_ThirdPerson,          // 1: Вид от третьего лица (обычный)
    ThirdPersonMode_ThirdPersonStatic     // 2: Вид от третьего лица (статичный, как thirdperson_mayamode)
}

// ClassFields with additional glove information
enum ClassFields
{
    ClassId,
    ClassAbilityFlags,
    ClassTeamMask,
    ClassSkinType,            // Тип скина
    ClassGloveModel[PLATFORM_MAX_PATH],  // Модель перчаток
    ClassGloveSkin            // Скин перчаток
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

// Переменные для системы thirdperson
ConVar g_CvarTpEnabled;
ConVar g_CvarTpFreezeTime;
ConVar g_CvarTpFreezeTimeEnd;

char g_MainConfig[PLATFORM_MAX_PATH];
bool g_ConfigsLoaded;
bool g_AutoAssign;
int g_DefaultClassT = -1;
int g_DefaultClassCT = -1;
int g_DefaultClassSpec = -1;

int g_ClientClass[MAXPLAYERS + 1];
ArrayList g_ClassDefs;           // ClassDefs теперь содержит больше данных
StringMap g_ClassNames;
StringMap g_ClassModels;
StringMap g_ClassSounds;
StringMap g_ClassGloveModels;    // Новое: карта моделей перчаток
StringMap g_ClassGloveSkins;     // Новое: карта скинов перчаток
StringMap g_ClassSkinTypes;      // Новое: карта типов скинов
ArrayList g_DownloadModels;
ArrayList g_DownloadSounds;

// Трекинг viewmodel-ов для обновления перчаток
int g_ClientViewModels[MAXPLAYERS + 1][2];  // Хранит оба viewmodel-а игрока

// Трекинг состояния thirdperson для каждого игрока
int g_ClientTpMode[MAXPLAYERS + 1];
float g_ClientTpAngleOffset[MAXPLAYERS + 1][3];  // Угловое смещение для static thirdperson

// Таймер для автоматического отключения thirdperson после freeze time
Handle g_FreezeEndTimer[MAXPLAYERS + 1];

Handle g_fwdClassChanged;

public Plugin myinfo =
{
    name = "ZH-sys MST (ModelSwitchTool) - Enhanced with Gloves Support and ThirdPerson",
    author = "ZloyHohol integration workbench",
    description = "Model/class switch manager skeleton for ZH-sys with gloves support and third-person view modes.",
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
    // Добавляем новые нативы для работы с типами скинов и перчатками
    CreateNative("MST_SetClassGloveInfo", Native_SetClassGloveInfo);
    CreateNative("MST_GetClassGloveInfo", Native_GetClassGloveInfo);
    CreateNative("MST_GetClassSkinType", Native_GetClassSkinType);
    CreateNative("MST_SetClassSkinType", Native_SetClassSkinType);
    // Нативы для thirdperson режима
    CreateNative("MST_TP_SetClientThirdPersonMode", Native_SetClientTpMode);
    CreateNative("MST_TP_GetClientThirdPersonMode", Native_GetClientTpMode);
    CreateNative("MST_TP_ToggleClientThirdPersonMode", Native_ToggleClientTpMode);
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

    // Переменные для thirdperson
    g_CvarTpEnabled = CreateConVar("zh_mst_tp_enabled", "1", "Enable third-person modes for MST.", _, true, 0.0, true, 1.0);
    g_CvarTpFreezeTime = CreateConVar("zh_mst_tp_freezetime", "1", "Enable automatic thirdperson during freeze time.", _, true, 0.0, true, 1.0);
    g_CvarTpFreezeTimeEnd = CreateConVar("zh_mst_tp_freezetime_end", "1", "Auto disable thirdperson after freeze time ends.", _, true, 0.0, true, 1.0);

    AutoExecConfig(true, "zh_mst", "sourcemod");

    ResolveConfigPaths();

    RegAdminCmd("sm_mst_reload", Command_ReloadMst, ADMFLAG_CONFIG, "Reloads MST configs.");
    RegAdminCmd("sm_mst_mode", Command_SetMode, ADMFLAG_GENERIC, "Set mode flags (dm/tdm/gg/chicken/revive).");

    // Команды для игроков thirdperson
    RegConsoleCmd("sm_tp", Command_ThirdPerson, "Toggle third-person view");
    RegConsoleCmd("sm_tp_mode", Command_ThirdPersonMode, "Set specific third-person mode");

    g_ClassDefs = new ArrayList(5 + PLATFORM_MAX_PATH + 1); // ClassId + AbilityFlags + TeamMask + SkinType + [Model] + GloveSkin
    g_ClassNames = new StringMap();
    g_ClassModels = new StringMap();
    g_ClassSounds = new StringMap();
    g_ClassGloveModels = new StringMap();
    g_ClassGloveSkins = new StringMap();
    g_ClassSkinTypes = new StringMap();
    g_DownloadModels = new ArrayList(PLATFORM_MAX_PATH);
    g_DownloadSounds = new ArrayList(PLATFORM_MAX_PATH);

    g_fwdClassChanged = CreateGlobalForward("MST_OnClassChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);

    ResetClientClasses();

    // Хуки для thirdperson
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("round_freeze_end", Event_FreezeEnd, EventHookMode_PostNoCopy);

    ZH_RegisterModule("mst");
}

public void OnConfigsExecuted()
{
    LoadMstConfigs();
}

public void OnMapStart()
{
    PrecacheRegisteredResources();

    // Хуки для отслеживания viewmodel-ов
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
    // Подписываемся на создание viewmodel-ов
    HookEntityOutput("", "OnSpawn", OnEntitySpawned);
}

public void OnClientDisconnect(int client)
{
    g_ClientClass[client] = -1;
    g_ClientViewModels[client][0] = -1;
    g_ClientViewModels[client][1] = -1;

    g_ClientTpMode[client] = ThirdPersonMode_FirstPerson;
    if (g_FreezeEndTimer[client] != null)
    {
        KillTimer(g_FreezeEndTimer[client]);
        g_FreezeEndTimer[client] = null;
    }
}

public void OnClientPutInServer(int client)
{
    g_ClientClass[client] = -1;
    g_ClientViewModels[client][0] = -1;
    g_ClientViewModels[client][1] = -1;

    // SDK Hooks для обновления перчаток при смене оружия
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

    // Инициализация thirdperson состояния
    g_ClientTpMode[client] = ThirdPersonMode_FirstPerson;
    g_FreezeEndTimer[client] = null;

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

    char classIdStr[16];
    Format(classIdStr, sizeof(classIdStr), "%d", classId);

    g_ClassSkinTypes.SetValue(classIdStr, skinType);

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

    char classIdStr[16];
    Format(classIdStr, sizeof(classIdStr), "%d", classId);

    int skinType;
    bool result = g_ClassSkinTypes.GetValue(classIdStr, skinType);

    if (!result)
    {
        skinType = SkinType_Regular;
    }

    return skinType;
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
    if (result && 1 <= client <= MaxClients && IsClientInGame(client))
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

// Нативы для thirdperson режима
public any Native_SetClientTpMode(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int mode = GetNativeCell(2);
    bool sendUpdate = GetNativeCell(3);

    if (client < 1 || client > MaxClients || !IsClientInGame(client))
    {
        return false;
    }

    if (mode < ThirdPersonMode_FirstPerson || mode > ThirdPersonMode_ThirdPersonStatic)
    {
        return false;
    }

    g_ClientTpMode[client] = mode;

    if (sendUpdate)
    {
        SetClientViewMode(client, mode);
    }

    if (g_CvarTpEnabled.BoolValue && g_CvarMstDebug != null && g_CvarMstDebug.BoolValue)
    {
        ZH_LogInfo("Client %d set to thirdperson mode %d", client, mode);
    }

    return true;
}

public any Native_GetClientTpMode(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (client < 1 || client > MaxClients || !IsClientInGame(client))
    {
        return ThirdPersonMode_FirstPerson;
    }

    return g_ClientTpMode[client];
}

public any Native_ToggleClientTpMode(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    bool sendUpdate = GetNativeCell(2);

    if (client < 1 || client > MaxClients || !IsClientInGame(client))
    {
        return false;
    }

    // Переключаем между firstperson и thirdperson (игнорируем static mode при тоггле)
    if (g_ClientTpMode[client] == ThirdPersonMode_FirstPerson)
    {
        g_ClientTpMode[client] = ThirdPersonMode_ThirdPerson;
    }
    else
    {
        g_ClientTpMode[client] = ThirdPersonMode_FirstPerson;
    }

    if (sendUpdate)
    {
        SetClientViewMode(client, g_ClientTpMode[client]);
    }

    return true;
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

// Команды thirdperson
public Action Command_ThirdPerson(int client, int args)
{
    if (!g_CvarTpEnabled.BoolValue || client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    Native_ToggleClientTpMode(null, 2, client, true);

    char modeName[32];
    GetThirdPersonModeName(g_ClientTpMode[client], modeName, sizeof(modeName));
    ReplyToCommand(client, "[ZH-MST-TP] Third-person mode changed to: %s", modeName);

    return Plugin_Handled;
}

public Action Command_ThirdPersonMode(int client, int args)
{
    if (!g_CvarTpEnabled.BoolValue || client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    if (args == 0)
    {
        ReplyToCommand(client, "[ZH-MST-TP] Usage: sm_tp_mode <0|1|2> (0=firstperson, 1=thirdperson, 2=static thirdperson)");
        ReplyToCommand(client, "[ZH-MST-TP] Current mode: %d (%s)", g_ClientTpMode[client],
                      GetThirdPersonModeName(g_ClientTpMode[client], modeName, sizeof(modeName)));
        return Plugin_Handled;
    }

    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));
    int mode = StringToInt(arg);

    if (mode < ThirdPersonMode_FirstPerson || mode > ThirdPersonMode_ThirdPersonStatic)
    {
        ReplyToCommand(client, "[ZH-MST-TP] Invalid mode. Valid modes: 0=firstperson, 1=thirdperson, 2=static thirdperson");
        return Plugin_Handled;
    }

    Native_SetClientTpMode(null, 3, client, mode, true);

    char modeName[32];
    GetThirdPersonModeName(g_ClientTpMode[client], modeName, sizeof(modeName));
    ReplyToCommand(client, "[ZH-MST-TP] Third-person mode set to: %d (%s)", mode, modeName);

    return Plugin_Handled;
}

// --- Internals ---------------------------------------------------------------

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

        // Загружаем тип скина
        char skinTypeStr[32];
        kvClasses.GetString("skin_type", skinTypeStr, sizeof(skinTypeStr));
        int skinType = ParseSkinType(skinTypeStr);

        DefineOrUpdateClass(classId, name, model, sound, flags, teamMask, skinType);

        // Загружаем информацию о перчатках
        char gloveModel[PLATFORM_MAX_PATH];
        int gloveSkin = kvClasses.GetNum("glove_skin", 0);
        kvClasses.GetString("glove_model", gloveModel, sizeof(gloveModel));

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
        g_ClassDefs.SetString(idx, "", ClassGloveModel);  // default glove model
        g_ClassDefs.Set(idx, 0, ClassGloveSkin);  // default glove skin
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

void SetGloveInfoForClass(int classId, const char[] gloveModel, int gloveSkin)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        // Если класс еще не определен, определяем с дефолтными значениями
        DefineOrUpdateClass(classId, "Undefined", "", "", 0, TEAMMASK_ANY, SkinType_Regular);
        idx = FindClassIndex(classId);
        if (idx == -1) return; // Ошибка
    }

    g_ClassDefs.SetString(idx, gloveModel, ClassGloveModel);
    g_ClassDefs.Set(idx, gloveSkin, ClassGloveSkin);
}

void GetGloveInfoForClass(int classId, char[] gloveModel, int maxlen, int& gloveSkin)
{
    int idx = FindClassIndex(classId);
    if (idx == -1)
    {
        gloveModel[0] = '\0';
        gloveSkin = 0;
        return;
    }

    g_ClassDefs.GetString(idx, gloveModel, maxlen, ClassGloveModel);
    gloveSkin = g_ClassDefs.Get(idx, ClassGloveSkin);
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
        g_ClassDefs.Set(idx, SkinType_Regular, ClassSkinType);
        g_ClassDefs.SetString(idx, "", ClassGloveModel);
        g_ClassDefs.Set(idx, 0, ClassGloveSkin);
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
        g_ClassDefs.Set(idx, SkinType_Regular, ClassSkinType);
        g_ClassDefs.SetString(idx, "", ClassGloveModel);
        g_ClassDefs.Set(idx, 0, ClassGloveSkin);
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
            flags |= MSTAbility_Revive;
        }
        else if (StrEqual(parts[i], "turret", false))
        {
            flags |= MSTAbility_Turret;
        }
        else if (StrEqual(parts[i], "barricade", false))
        {
            flags |= MSTAbility_Barricade;
        }
        else if (StrEqual(parts[i], "grenadelauncher", false))
        {
            flags |= MSTAbility_GrenadeLauncher;
        }
        else if (StrEqual(parts[i], "specialvision", false))
        {
            flags |= MSTAbility_SpecialVision;
        }
        else if (StrEqual(parts[i], "flashlightforce", false))
        {
            flags |= MSTAbility_FlashlightForce;
        }
        else if (StrEqual(parts[i], "speedscout", false))
        {
            flags |= MSTAbility_SpeedScout;
        }
        else if (StrEqual(parts[i], "shieldcarrier", false))
        {
            flags |= MSTAbility_ShieldCarrier;
        }
        else if (StrEqual(parts[i], "gasimmunity", false))
        {
            flags |= MSTAbility_GasImmunity;
        }
        else if (StrEqual(parts[i], "engineertoolset", false))
        {
            flags |= MSTAbility_EngineerToolset;
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
    if (g_ClassSkinTypes != null)
    {
        g_ClassSkinTypes.Clear();
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

// --- SDKHooks for updating gloves when player changes weapons ---
// Эти хуки работают только при наличии viewmodel-ов и только для перчаток

// Хук при экипировке оружия
public void OnWeaponEquipPost(int client, int weapon)
{
    if (!IsClientInGame(client) || !g_ConfigsLoaded)
        return;

    // Обновляем перчатки при смене оружия
    UpdateGlovesForClient(client);
}

// Хук при переключении оружия
public void OnWeaponSwitchPost(int client, int weapon)
{
    if (!IsClientInGame(client) || !g_ConfigsLoaded)
        return;

    // Обновляем перчатки при переключении оружия
    UpdateGlovesForClient(client);
}

// Обновление перчаток на viewmodel-е
void UpdateGlovesForClient(int client)
{
    if (!IsClientInGame(client) || !g_ConfigsLoaded)
        return;

    int clientClass = g_ClientClass[client];
    if (clientClass == -1)
        return;

    // Получаем информацию о перчатках для текущего класса
    char gloveModel[PLATFORM_MAX_PATH];
    int gloveSkin;
    GetGloveInfoForClass(clientClass, gloveModel, sizeof(gloveModel), gloveSkin);

    if (gloveModel[0] == '\0')
        return; // Нет модели перчаток для этого класса

    // Обновляем перчатки на обоих viewmodel-ах
    UpdateGloveOnViewModel(client, 0, gloveModel, gloveSkin);
    UpdateGloveOnViewModel(client, 1, gloveModel, gloveSkin);
}

void UpdateGloveOnViewModel(int client, int viewModelIndex, const char[] gloveModel, int gloveSkin)
{
    // Получаем viewmodel игрока
    int viewModel = GetEntPropEnt(client, PropData, viewModelIndex == 0 ? "m_hViewModel[0]" : "m_hViewModel[1]");
    if (viewModel == -1 || !IsValidEntity(viewModel))
        return;

    // Устанавливаем модель перчаток
    SetVariantString(gloveModel);
    AcceptEntityInput(viewModel, "SetModel");
}

// Хуки для отслеживания создания viewmodel-ов
public void OnEntitySpawned(const char[] output, int caller, int activator, float delay)
{
    // Проверяем, является ли entity viewmodel-ом
    char className[64];
    GetEntityClassname(caller, className, sizeof(className));

    if (StrEqual(className, "viewmodel", false))
    {
        // Проверяем, принадлежит ли viewmodel игроку
        int owner = GetEntPropEnt(caller, PropSend, "m_hOwner");
        if (owner > 0 && owner <= MaxClients && IsClientInGame(owner))
        {
            // Получаем текущий класс игрока и обновляем перчатки на этом viewmodel-е
            int clientClass = g_ClientClass[owner];
            if (clientClass != -1)
            {
                char gloveModel[PLATFORM_MAX_PATH];
                int gloveSkin;
                GetGloveInfoForClass(clientClass, gloveModel, sizeof(gloveModel), gloveSkin);

                if (gloveModel[0] != '\0')
                {
                    SetVariantString(gloveModel);
                    AcceptEntityInput(caller, "SetModel");
                }
            }
        }
    }
}

// Событие при спауне игрока
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return;

    // Обновляем перчатки после спауна игрока
    UpdateGlovesForClient(client);
}

// --- ThirdPerson Functions ---

void SetClientViewMode(int client, int mode)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
    {
        return;
    }

    switch (mode)
    {
        case ThirdPersonMode_FirstPerson:
        {
            // Включаем firstperson
            SetThirdPersonClient(client, false);
        }
        case ThirdPersonMode_ThirdPerson:
        {
            // Включаем thirdperson
            SetThirdPersonClient(client, true);
        }
        case ThirdPersonMode_ThirdPersonStatic:
        {
            // Включаем thirdperson и фиксируем угол (имитация thirdperson_mayamode)
            SetThirdPersonClient(client, true);
            // Пользовательский угол устанавливается отдельно
        }
    }
}

void SetThirdPersonClient(int client, bool enabled)
{
    // Устанавливаем клиентскую переменную для thirdperson
    // В CS:Source для этого нужно отправить клиентскую команду
    if (enabled)
    {
        // Включаем thirdperson
        ClientCommand(client, "cl_thirdperson 1");
    }
    else
    {
        // Выключаем thirdperson
        ClientCommand(client, "cl_thirdperson 0");
    }
}

void GetThirdPersonModeName(int mode, char[] buffer, int maxlen)
{
    switch (mode)
    {
        case ThirdPersonMode_FirstPerson:
            strcopy(buffer, maxlen, "First Person");
        case ThirdPersonMode_ThirdPerson:
            strcopy(buffer, maxlen, "Third Person");
        case ThirdPersonMode_ThirdPersonStatic:
            strcopy(buffer, maxlen, "Static Third Person");
        default:
            strcopy(buffer, maxlen, "Unknown");
    }
}

// События для thirdperson
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_CvarTpEnabled.BoolValue || !g_CvarTpFreezeTime.BoolValue)
    {
        return;
    }

    // Включаем thirdperson для всех игроков на время freeze time
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            g_ClientTpMode[i] = ThirdPersonMode_ThirdPerson;
            SetClientViewMode(i, ThirdPersonMode_ThirdPerson);
        }
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // Отключаем thirdperson для всех игроков
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && g_ClientTpMode[i] != ThirdPersonMode_FirstPerson)
        {
            g_ClientTpMode[i] = ThirdPersonMode_FirstPerson;
            SetClientViewMode(i, ThirdPersonMode_FirstPerson);
        }
    }
}

public void Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_CvarTpEnabled.BoolValue || !g_CvarTpFreezeTimeEnd.BoolValue)
    {
        return;
    }

    // Отключаем thirdperson после окончания freeze time
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && g_ClientTpMode[i] == ThirdPersonMode_ThirdPerson)
        {
            g_ClientTpMode[i] = ThirdPersonMode_FirstPerson;
            SetClientViewMode(i, ThirdPersonMode_FirstPerson);
        }
    }
}