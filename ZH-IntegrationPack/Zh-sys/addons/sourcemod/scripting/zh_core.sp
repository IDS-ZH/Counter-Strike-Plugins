#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <zh_core>

#define PLUGIN_VERSION "0.1.0-dev"
#define CONFIG_ROOT "configs/ZH-sys"
#define LOG_ROOT "logs/ZH-sys"
#define CORE_LOG_FILE "zh_core.log"

ConVar g_CvarDebug;
ConVar g_CvarLogLevel;
ArrayList g_Modules;

public Plugin myinfo =
{
    name = "ZH-sys Core",
    author = "ZloyHohol integration workbench",
    description = "Core utilities and shared natives for ZH-sys modules.",
    version = PLUGIN_VERSION,
    url = ""
};

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int errMax)
{
    RegPluginLibrary(ZH_CORE_LIBRARY);
    CreateNative("ZH_IsDebugEnabled", Native_IsDebugEnabled);
    CreateNative("ZH_LogInfo", Native_LogInfo);
    CreateNative("ZH_LogWarn", Native_LogWarn);
    CreateNative("ZH_LogError", Native_LogError);
    CreateNative("ZH_BuildConfigDir", Native_BuildConfigDir);
    CreateNative("ZH_BuildConfigPath", Native_BuildConfigPath);
    CreateNative("ZH_GetTranslationsToken", Native_GetTranslationsToken);
    CreateNative("ZH_RegisterModule", Native_RegisterModule);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_Modules = new ArrayList(32);

    g_CvarDebug = CreateConVar("zh_core_debug", "0", "Enables verbose debug output for ZH-sys modules.");
    g_CvarLogLevel = CreateConVar("zh_core_loglevel", "1", "0=errors only, 1=warnings, 2=info, 3=debug.");

    AutoExecConfig(true, "zh_core", "sourcemod");

    LoadTranslations("zh_core.phrases");

    CreateCorePaths();

    RegAdminCmd("sm_zhdiag", Command_ZHDiag, ADMFLAG_GENERIC, "Prints ZH-sys core diagnostics.");
}

public void OnAllPluginsLoaded()
{
    // Ensure core is always present in diagnostics.
    RegisterModuleInternal("core");
}

// --- Natives -----------------------------------------------------------------

public any Native_IsDebugEnabled(Handle plugin, int numParams)
{
    return g_CvarDebug != null && g_CvarDebug.BoolValue;
}

public any Native_LogInfo(Handle plugin, int numParams)
{
    char message[256];
    FormatNativeString(0, 1, 2, message, sizeof(message));
    ZhLog(LOGLEVEL_INFO, "%s", message);
    return 0;
}

public any Native_LogWarn(Handle plugin, int numParams)
{
    char message[256];
    FormatNativeString(0, 1, 2, message, sizeof(message));
    ZhLog(LOGLEVEL_WARN, "%s", message);
    return 0;
}

public any Native_LogError(Handle plugin, int numParams)
{
    char message[256];
    FormatNativeString(0, 1, 2, message, sizeof(message));
    ZhLog(LOGLEVEL_ERROR, "%s", message);
    return 0;
}

public any Native_BuildConfigDir(Handle plugin, int numParams)
{
    ZHConfigScope scope = view_as<ZHConfigScope>(GetNativeCell(1));
    int maxlen = GetNativeCell(3);
    char[] buffer = new char[maxlen];
    BuildConfigDir(scope, buffer, maxlen);
    SetNativeString(2, buffer, maxlen);
    return 0;
}

public any Native_BuildConfigPath(Handle plugin, int numParams)
{
    ZHConfigScope scope = view_as<ZHConfigScope>(GetNativeCell(1));
    int maxlen = GetNativeCell(4);
    char[] fileName = new char[PLATFORM_MAX_PATH];
    GetNativeString(2, fileName, sizeof(fileName));

    char[] buffer = new char[maxlen];
    BuildConfigPath(scope, fileName, buffer, maxlen);
    SetNativeString(3, buffer, maxlen);
    return 0;
}

public any Native_GetTranslationsToken(Handle plugin, int numParams)
{
    int maxlen = GetNativeCell(2);
    char[] buffer = new char[maxlen];
    strcopy(buffer, maxlen, "zh_core");
    SetNativeString(1, buffer, maxlen);
    return 0;
}

public any Native_RegisterModule(Handle plugin, int numParams)
{
    char module[64];
    GetNativeString(1, module, sizeof(module));
    RegisterModuleInternal(module);
    return 0;
}

// --- Commands ----------------------------------------------------------------

public Action Command_ZHDiag(int client, int args)
{
    ReplyToCommand(client, "[ZH] Core version %s", PLUGIN_VERSION);

    char cfgDir[PLATFORM_MAX_PATH];
    BuildConfigDir(ZHConfig_Core, cfgDir, sizeof(cfgDir));
    ReplyToCommand(client, "[ZH] Config root: %s", cfgDir);

    int modulesCount = g_Modules != null ? g_Modules.Length : 0;
    ReplyToCommand(client, "[ZH] Registered modules: %d", modulesCount);

    for (int i = 0; i < modulesCount; i++)
    {
        char name[64];
        g_Modules.GetString(i, name, sizeof(name));
        ReplyToCommand(client, " - %s", name);
    }

    return Plugin_Handled;
}

// --- Internals ---------------------------------------------------------------

enum ZhLogLevel
{
    LOGLEVEL_ERROR = 0,
    LOGLEVEL_WARN,
    LOGLEVEL_INFO,
    LOGLEVEL_DEBUG
};

void CreateCorePaths()
{
    char path[PLATFORM_MAX_PATH];

    BuildPath(Path_SM, path, sizeof(path), CONFIG_ROOT);
    CreateDirectory(path, 511);

    BuildPath(Path_SM, path, sizeof(path), LOG_ROOT);
    CreateDirectory(path, 511);
}

ZhLogLevel GetConfiguredLogLevel()
{
    if (g_CvarLogLevel == null)
    {
        return LOGLEVEL_WARN;
    }

    int value = g_CvarLogLevel.IntValue;

    switch (value)
    {
        case 0:
        {
            return LOGLEVEL_ERROR;
        }
        case 1:
        {
            return LOGLEVEL_WARN;
        }
        case 2:
        {
            return LOGLEVEL_INFO;
        }
        default:
        {
            return LOGLEVEL_DEBUG;
        }
    }
}

void ZhLog(ZhLogLevel level, const char[] fmt, any ...)
{
    ZhLogLevel configured = GetConfiguredLogLevel();
    if (level > configured)
    {
        return;
    }

    char message[256];
    VFormat(message, sizeof(message), fmt, 3);

    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "%s/%s", LOG_ROOT, CORE_LOG_FILE);

    switch (level)
    {
        case LOGLEVEL_ERROR:
        {
            LogError("[ZH-core] %s", message);
            LogToFileEx(logPath, "[ERROR] %s", message);
            break;
        }
        case LOGLEVEL_WARN:
        {
            LogMessage("[ZH-core] %s", message);
            LogToFileEx(logPath, "[WARN] %s", message);
            break;
        }
        case LOGLEVEL_INFO:
        {
            LogMessage("[ZH-core] %s", message);
            LogToFileEx(logPath, "[INFO] %s", message);
            break;
        }
        default:
        {
            // Debug falls through only when explicitly enabled.
            if (g_CvarDebug != null && g_CvarDebug.BoolValue)
            {
                LogMessage("[ZH-core] %s", message);
                LogToFileEx(logPath, "[DEBUG] %s", message);
            }
            break;
        }
    }
}

void BuildConfigDir(ZHConfigScope scope, char[] buffer, int maxlen)
{
    const char[] scopeDir = GetScopeDir(scope);
    BuildPath(Path_SM, buffer, maxlen, "%s/%s", CONFIG_ROOT, scopeDir);
    CreateDirectory(buffer, 511);
}

void BuildConfigPath(ZHConfigScope scope, const char[] filename, char[] buffer, int maxlen)
{
    char dir[PLATFORM_MAX_PATH];
    BuildConfigDir(scope, dir, sizeof(dir));
    BuildPath(Path_SM, buffer, maxlen, "%s/%s", dir, filename);
}

const char[] GetScopeDir(ZHConfigScope scope)
{
    switch (scope)
    {
        case ZHConfig_Core:
        {
            return "Core";
        }
        case ZHConfig_MST:
        {
            return "MST";
        }
        case ZHConfig_PRD:
        {
            return "PRD";
        }
        case ZHConfig_Sound:
        {
            return "SM";
        }
        case ZHConfig_Smoke:
        {
            return "SBC";
        }
        case ZHConfig_SBC:
        {
            return "SBC";
        }
        case ZHConfig_Classes:
        {
            return "Classes";
        }
        default:
        {
            return "Custom";
        }
    }
}

void RegisterModuleInternal(const char[] moduleName)
{
    if (g_Modules == null)
    {
        return;
    }

    char lowered[64];
    strcopy(lowered, sizeof(lowered), moduleName);
    TrimString(lowered);
    if (lowered[0] == '\0')
    {
        return;
    }

    // Avoid duplicates.
    for (int i = 0; i < g_Modules.Length; i++)
    {
        char existing[64];
        g_Modules.GetString(i, existing, sizeof(existing));
        if (StrEqual(existing, lowered, false))
        {
            return;
        }
    }

    g_Modules.PushString(lowered);
    ZhLog(LOGLEVEL_INFO, "Registered module: %s", lowered);
}
