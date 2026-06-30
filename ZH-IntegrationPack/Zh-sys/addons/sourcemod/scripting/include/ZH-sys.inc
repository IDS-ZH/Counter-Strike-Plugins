#if defined _ZH_SYS_INC_
    #endinput
#endif
#define _ZH_SYS_INC_

#define ZH_SYS_VERSION "1.0.0"

/**
 * Инициализация ядра ZH-sys
 * Должна вызываться другими модулями для регистрации.
 */
native void ZH_Core_RegisterModule(const char[] moduleName);

/**
 * Получение уникального ID игрока в системе ZH
 */
native int ZH_Core_GetPlayerId(int client);

public SharedPlugin __pl_zh_sys = 
{
    name = "zh_sys",
    file = "zh_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_zh_sys_SetNTVOptional()
{
    MarkNativeAsOptional("ZH_Core_RegisterModule");
    MarkNativeAsOptional("ZH_Core_GetPlayerId");
}
#endif
