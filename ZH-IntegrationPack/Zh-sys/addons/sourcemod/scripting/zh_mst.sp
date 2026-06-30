#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zh_core>

#define PLUGIN_VERSION "0.2.1-dev-modular"
#define MST_LIBRARY "zh_mst"

// Include shared definitions and global variables
#include "zh_mst/defines.sp"
#include "zh_mst/classes.sp"
#include "zh_mst/models.sp"
#include "zh_mst/gloves.sp"
#include "zh_mst/thirdperson.sp"
#include "zh_mst/config.sp"
#include "zh_mst/natives.sp"
#include "zh_mst/commands.sp"

public Plugin myinfo =
{
    name = "ZH-sys MST (ModelSwitchTool) - Enhanced",
    author = "ZloyHohol integration workbench",
    description = "Model/class switch manager for ZH-sys with gloves support and third-person view modes.",
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
    // Добавляем новые нативы для работы с типом скина и перчатками
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

    g_ClassDefs = new ArrayList(4); // ClassId + AbilityFlags + TeamMask + SkinType
    g_ClassNames = new StringMap();
    g_ClassModels = new StringMap();
    g_ClassSounds = new StringMap();
    g_ClassGloveModels = new StringMap();
    g_ClassGloveSkins = new StringMap();
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

    // Хуки для отслеживания viewmodel-ов (в gloves.sp)
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
