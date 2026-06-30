#if defined _zh_core_included
  #endinput
#endif
#define _zh_core_included

#include <sourcemod>

/**
 * Shared enums for ZH-sys modules.
 */
enum ZHConfigScope
{
    ZHConfig_Core = 0,
    ZHConfig_MST,
    ZHConfig_PRD,
    ZHConfig_Sound,
    ZHConfig_Smoke,
    ZHConfig_SBC,
    ZHConfig_Classes,
    ZHConfig_Custom
};

#define ZH_CORE_LIBRARY "zh_core"

/**
 * Returns true when verbose debug logging is enabled.
 */
native bool ZH_IsDebugEnabled();

/**
 * Writes an info level line into the ZH core log.
 */
native void ZH_LogInfo(const char[] fmt, any ...);

/**
 * Writes a warning line into the ZH core log.
 */
native void ZH_LogWarn(const char[] fmt, any ...);

/**
 * Writes an error line into the ZH core log.
 */
native void ZH_LogError(const char[] fmt, any ...);

/**
 * Builds a config directory path for the given scope.
 * The path points under addons/sourcemod/configs/ZH-sys/.
 */
native void ZH_BuildConfigDir(ZHConfigScope scope, char[] buffer, int maxlen);

/**
 * Builds a config file path for the given scope and file name.
 */
native void ZH_BuildConfigPath(ZHConfigScope scope, const char[] filename, char[] buffer, int maxlen);

/**
 * Builds the translations token (file prefix without extension) for shared ZH-sys phrases.
 */
native void ZH_GetTranslationsToken(char[] buffer, int maxlen);

/**
 * Registers a module name so diagnostics can report loaded pieces.
 */
native void ZH_RegisterModule(const char[] moduleName);

/**
 * Checks if a client index is valid, connected, and optionally alive/bot-safe.
 * 
 * @param client        Client index.
 * @param checkAlive    If true, checks IsPlayerAlive().
 * @param checkBot      If true, checks IsFakeClient().
 * @return              True if valid.
 */
native bool ZH_IsValidClient(int client, bool checkAlive = false, bool checkBot = false);
