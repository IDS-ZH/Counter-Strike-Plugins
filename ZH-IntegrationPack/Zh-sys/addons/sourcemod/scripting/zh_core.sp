#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ZH-sys>

public Plugin myinfo = 
{
    name = "ZH-sys Core",
    author = "Antigravity & mge_engineer",
    description = "Ядро для интеграции модулей ZH-sys",
    version = ZH_SYS_VERSION,
    url = "https://github.com/ZloyHohol"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("zh_sys");
    
    CreateNative("ZH_Core_RegisterModule", Native_RegisterModule);
    CreateNative("ZH_Core_GetPlayerId", Native_GetPlayerId);
    
    return APLRes_Success;
}

Database g_hDatabase = null;
int g_PlayerZhId[MAXPLAYERS + 1];

public void OnPluginStart()
{
    PrintToServer("[ZH-sys] Core module initialized (v%s)", ZH_SYS_VERSION);
    
    // Инициализация базы данных (MaterialAdmin или кастомная таблица)
    Database_Connect();
}

public void OnClientPutInServer(int client)
{
    // Очистка старых данных
    g_PlayerZhId[client] = 0;
}

public void OnClientPostAdminCheck(int client)
{
    if (IsFakeClient(client)) return;
    
    char authId[32];
    if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId)) || StrEqual(authId, "STEAM_ID_PENDING") || StrEqual(authId, "STEAM_ID_LAN"))
    {
        // Игрок без Steam (или упал Steam-сервер авторизации). 
        // Здесь мы будем вызывать кастомную авторизацию по IP + Password / Token.
        LogMessage("[ZH-sys] Клиент %N подключился без валидного SteamID (%s). Ожидание кастомной авторизации...", client, authId);
    }
    else
    {
        // Обычная авторизация по SteamID
        AuthenticatePlayerBySteam(client, authId);
    }
}

// --- Работа с БД ---
void Database_Connect()
{
    if (SQL_CheckConfig("materialadmin"))
    {
        Database.Connect(SQL_OnConnect, "materialadmin");
    }
    else if (SQL_CheckConfig("zh_sys"))
    {
        Database.Connect(SQL_OnConnect, "zh_sys");
    }
    else
    {
        SetFailState("[ZH-sys] Не найдена конфигурация БД 'materialadmin' или 'zh_sys' в databases.cfg!");
    }
}

public void SQL_OnConnect(Database db, const char[] error, any data)
{
    if (db == null)
    {
        SetFailState("[ZH-sys] Ошибка подключения к БД: %s", error);
        return;
    }
    
    g_hDatabase = db;
    PrintToServer("[ZH-sys] Успешное подключение к БД!");
    
    // Создаем таблицу для аккаунтов ZH-sys, если ее нет
    // Мы храним auth_token для входа без Steam (IP или пароль)
    char query[512];
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `zh_accounts` (" ...
        "`zh_id` INT AUTO_INCREMENT PRIMARY KEY, " ...
        "`steamid` VARCHAR(32) NOT NULL DEFAULT '', " ...
        "`auth_token` VARCHAR(64) NOT NULL DEFAULT '', " ...
        "`name` VARCHAR(64) NOT NULL DEFAULT 'unnamed', " ...
        "`last_ip` VARCHAR(32) NOT NULL DEFAULT ''" ...
        ") DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
        
    g_hDatabase.Query(SQL_OnTableCreated, query);
}

public void SQL_OnTableCreated(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("[ZH-sys] Ошибка создания таблицы zh_accounts: %s", error);
    }
    else
    {
        PrintToServer("[ZH-sys] Таблица zh_accounts проверена/создана.");
    }
}

// --- Авторизация ---
void AuthenticatePlayerBySteam(int client, const char[] steamId)
{
    if (g_hDatabase == null) return;
    
    char safeSteam[32], safeName[64];
    g_hDatabase.Escape(steamId, safeSteam, sizeof(safeSteam));
    
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    g_hDatabase.Escape(name, safeName, sizeof(safeName));
    
    // Запрашиваем ID, и если его нет, создаем (UPSERT логика)
    char query[512];
    Format(query, sizeof(query), "SELECT `zh_id` FROM `zh_accounts` WHERE `steamid` = '%s'", safeSteam);
    
    // Передаем UserID, чтобы обезопасить себя от выхода клиента до завершения запроса
    g_hDatabase.Query(SQL_OnAuthSteam, query, GetClientUserId(client));
}

public void SQL_OnAuthSteam(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!client) return; // Игрок уже вышел
    
    if (results == null)
    {
        LogError("[ZH-sys] Ошибка проверки аккаунта: %s", error);
        return;
    }
    
    if (results.FetchRow())
    {
        g_PlayerZhId[client] = results.FetchInt(0);
        LogMessage("[ZH-sys] Клиент %N авторизован. ZH_ID: %d", client, g_PlayerZhId[client]);
    }
    else
    {
        // Игрок впервые на сервере, регистрируем его
        char authId[32], name[MAX_NAME_LENGTH], ip[32];
        GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
        GetClientName(client, name, sizeof(name));
        GetClientIP(client, ip, sizeof(ip));
        
        char query[512];
        Format(query, sizeof(query), 
            "INSERT INTO `zh_accounts` (`steamid`, `name`, `last_ip`) VALUES ('%s', '%s', '%s')", 
            authId, name, ip);
            
        g_hDatabase.Query(SQL_OnAccountCreated, query, userid);
    }
}

public void SQL_OnAccountCreated(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!client) return;
    
    if (results == null)
    {
        LogError("[ZH-sys] Ошибка создания аккаунта: %s", error);
        return;
    }
    
    g_PlayerZhId[client] = results.InsertId;
    LogMessage("[ZH-sys] Новый аккаунт зарегистрирован для %N. ZH_ID: %d", client, g_PlayerZhId[client]);
}

// --- Нативы ---
public any Native_RegisterModule(Handle plugin, int numParams)
{
    char moduleName[64];
    GetNativeString(1, moduleName, sizeof(moduleName));
    PrintToServer("[ZH-sys] Зарегистрирован модуль: %s", moduleName);
    return 0;
}

public any Native_GetPlayerId(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return 0;
        
    return g_PlayerZhId[client];
}
