/// =============================================================================
// SM Skinchooser (CSS) v5.5.1 — Patched by Gemini
//
// Этот плагин позволяет игрокам выбирать себе модели (скины) из заранее
// определенного списка. Он поддерживает разделение моделей по командам,
// ограничение доступа к группам моделей по флагам администратора,
// а также автоматическую загрузку моделей и их материалов на клиенты.
//
// Ключевые исправления в этой версии:
// - Исправлена фильтрация меню по флагам.
// - Восстановлена навигация по меню и показ списка моделей.
// - Исправлена критическая ошибка, приводившая к "ERROR" моделям.
// - Восстановлена автоматическая загрузка материалов.
// - Исправлена логика сброса модели на стандартную.
// - Добавлены информативные сообщения в чат для игроков.
// =============================================================================

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors> // Добавлено для цветных сообщений
    #include <admin>       // Добавлено для работы с флагами администраторов
    #include <smlib/smlib>

#define PLUGIN_VERSION "5.5.1"
// --- Глобальные переменные ---

// Переменные для хранения значений консольных команд (CVars)
ConVar g_cvarEnabled;
ConVar g_cvarMapbased;
ConVar g_cvarAdminOnly;
ConVar g_cvarCloseMenuTimer;
ConVar g_cvarAutodisplay;
ConVar g_cvarDisplayTimer;
ConVar g_cvarMenuStartTime;
ConVar g_cvarForcePlayerSkin;
ConVar g_cvarForcePlayerSkinTimer;
ConVar g_cvarForcePlayerSkinTimerEnabled;
ConVar g_cvarSkinAdmin;
ConVar g_cvarSkinAdminTimer;
ConVar g_cvarSkinAdminTimerEnabled;
ConVar g_cvarSkinBots;
ConVar g_cvarSaveChoice; // Новый CVAR для контроля сохранения
ConVar g_cvarLoadChoice; // Новый CVAR для контроля загрузки

// "Handle" для работы с файлами конфигурации KeyValues
KeyValues g_hKVModels;        // Хранит структуру default_skins.ini
KeyValues g_hKVPlayerChoice;  // Хранит выбор моделей игроками

// Массивы для хранения информации об игроках
char g_authId[MAXPLAYERS+1][64];                // SteamID игроков
char g_originalModel[MAXPLAYERS+1][PLATFORM_MAX_PATH]; // Путь к стандартной модели игрока

// Массив со стандартными моделями для T и CT



// Массивы для хранения путей к моделям для принудительной установки
char g_ForcePlayerTeamT[128][PLATFORM_MAX_PATH];
char g_ForcePlayerTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForcePlayerCountT = 0;
int  g_ForcePlayerCountCT = 0;

char g_ForceAdminTeamT[128][PLATFORM_MAX_PATH];
char g_ForceAdminTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForceAdminCountT = 0;
int  g_ForceAdminCountCT = 0;

char g_ForceBotsTeamT[128][PLATFORM_MAX_PATH];
char g_ForceBotsTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForceBotsCountT = 0;
int  g_ForceBotsCountCT = 0;



// --- Информация о плагине ---

public Plugin myinfo = {
    name        = "SM Skinchooser (CSS - v5.5.1)",
    author      = "Andi67, Gemini",
    description = "Model menu for Counter-Strike: Source with flag restrictions",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

// --- Основные функции плагина ---

public void OnPluginStart()
{
    // Регистрация консольных команд (CVars) для управления плагином
    CreateConVar("sm_skinchooser_version", PLUGIN_VERSION, "SM Skinchooser version", FCVAR_NOTIFY | FCVAR_SPONLY);

    g_cvarEnabled = CreateConVar("sm_skinchooser_enabled", "1", "Включить/выключить плагин");
    g_cvarMapbased = CreateConVar("sm_skinchooser_mapbased", "0", "Использовать файлы выбора моделей для каждой карты отдельно (1) или один общий (0)");
    g_cvarAdminOnly = CreateConVar("sm_skinchooser_adminonly", "0", "Сделать меню доступным только для администраторов");
    g_cvarCloseMenuTimer = CreateConVar("sm_skinchooser_closemenutimer", "30", "Через сколько секунд автоматически закрывать меню");
    g_cvarAutodisplay = CreateConVar("sm_skinchooser_autodisplay", "1", "Автоматически показывать меню при входе в команду");
    g_cvarDisplayTimer = CreateConVar("sm_skinchooser_displaytimer", "0", "Использовать задержку перед показом меню");
    g_cvarMenuStartTime = CreateConVar("sm_skinchooser_menustarttime", "5.0", "Задержка в секундах перед автоматическим показом меню");

    g_cvarForcePlayerSkin = CreateConVar("sm_skinchooser_forceplayerskin", "0", "Принудительно устанавливать скины обычным игрокам");
    g_cvarForcePlayerSkinTimer = CreateConVar("sm_skinchooser_forceplayerskintimer", "0.3", "Задержка перед принудительной установкой скина");
    g_cvarForcePlayerSkinTimerEnabled = CreateConVar("sm_skinchooser_forceplayerskintimer_enabled", "0", "Использовать таймер для принудительной установки");

    g_cvarSkinAdmin = CreateConVar("sm_skinchooser_skinadmin", "0", "Принудительно устанавливать скины администраторам");
    g_cvarSkinAdminTimer = CreateConVar("sm_skinchooser_skinadmintimer", "0.3", "Задержка перед принудительной установкой скина админу");
    g_cvarSkinAdminTimerEnabled = CreateConVar("sm_skinchooser_skinadmintimer_enabled", "0", "Использовать таймер для админов");

    g_cvarSkinBots = CreateConVar("sm_skinchooser_skinbots", "0", "Принудительно устанавливать скины ботам");
    g_cvarSaveChoice = CreateConVar("sm_skinchooser_savechoice", "1", "Сохранять выбор игроков в файл (1 = да, 0 = нет)");
    g_cvarLoadChoice = CreateConVar("sm_skinchooser_loadchoice", "1", "Загружать сохраненный выбор игроков (1 = да, 0 = нет)");

    // Регистрация команды !models в чате
    RegConsoleCmd("sm_models", Command_Model, "Открыть меню выбора моделей");

    // Перехват игровых событий
    HookEvent("player_team",  Event_PlayerTeam, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    
    // Отслеживание изменений в CVars для перезагрузки конфигов "на лету"
    HookConVarChange(g_cvarForcePlayerSkin, OnForceCvarChanged);
    HookConVarChange(g_cvarSkinAdmin, OnForceCvarChanged);
    HookConVarChange(g_cvarSkinBots, OnForceCvarChanged);

    // Автоматическое выполнение конфигурационного файла плагина
    AutoExecConfig(true, "sm_skinchooser");
}

// Вызывается после загрузки всех конфигов на сервере
public void OnConfigsExecuted()
{
    LoadAllConfigs();
}

// Вызывается при изменении CVAR'ов принудительной установки скинов
public void OnForceCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    LoadAllConfigs();
}

// Вызывается при старте новой карты
public void OnMapStart()
{
    LoadAllConfigs();
}

// Вызывается при выгрузке плагина
public void OnPluginEnd()
{
    if (g_hKVModels != null) CloseHandle(g_hKVModels);
    if (g_hKVPlayerChoice != null) CloseHandle(g_hKVPlayerChoice);
}

/**
 * Читает default_skins_download_list.ini и добавляет все файлы и папки
 * в таблицу загрузок, используя smlib. Также прекеширует модели.
 */
void ProcessDownloadList()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/sm_skinchooser/default_skins_download_list.ini");

    if (!FileExists(path)) {
        PrintToServer("[SM_SKINCHOOSER] Файл 'default_skins_download_list.ini' не найден. Загрузка дополнительных материалов невозможна.");
        return;
    }

    File file = OpenFile(path, "r");
    if (file == null) {
        LogError("[SM_SKINCHOOSER] Не удалось открыть 'default_skins_download_list.ini'.");
        return;
    }

    char buffer[PLATFORM_MAX_PATH];
    while (!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer))) {
        TrimString(buffer);
        // Игнорируем пустые строки и комментарии
        if (buffer[0] == '\0' || buffer[0] == ';' || (buffer[0] == '/' && buffer[1] == '/')) {
            continue;
        }

        // Используем smlib для добавления файла или папки в таблицу загрузок
        File_AddToDownloadsTable(buffer, true);
    }

    delete file;
}

// --- Загрузка и обработка конфигурационных файлов ---

/**
 * Главная функция, вызываемая при старте для загрузки всех конфигов.
 */
void LoadAllConfigs()
{
    // Шаг 1: Загружаем все файлы и модели из списка загрузок.
    // Это наша "единая точка правды" для всего, что нужно загрузить и прекешировать.
    ProcessDownloadList();

    // Шаг 2: Загружаем структуру меню из default_skins.ini.
    LoadMenuStructure();

    // Шаг 3: Загружаем списки для принудительной установки скинов.
    LoadForceConfigs();
}

/**
 * Загружает основной конфигурационный файл с моделями (default_skins.ini) для построения меню.
 * НЕ выполняет прекеш или загрузку.
 */
void LoadMenuStructure()
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));

    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/sm_skinchooser/maps/%s.ini", mapName);
    if (!FileExists(configPath)) {
        BuildPath(Path_SM, configPath, sizeof(configPath), "configs/sm_skinchooser/default_skins.ini");
    }

    if (g_hKVModels != null) CloseHandle(g_hKVModels);
    g_hKVModels = new KeyValues("Models");
    if (!g_hKVModels.ImportFromFile(configPath)) {
        LogError("[SM_SKINCHOOSER] Не удалось загрузить %s для построения меню.", configPath);
    }
    else {
        // Гарантируем, что все модели из меню будут предварительно кэшированы.
        PrecacheAllMenuModels(g_hKVModels);
    }
    
    // Загружаем выборы игроков
    char choicePath[PLATFORM_MAX_PATH];
    if (g_cvarMapbased.BoolValue) {
        BuildPath(Path_SM, choicePath, sizeof(choicePath), "data/skinchooser/%s_playermodels.ini", mapName);
    } else {
        BuildPath(Path_SM, choicePath, sizeof(choicePath), "data/skinchooser/skinchooser_playermodels.ini");
    }
    if (g_hKVPlayerChoice != null) CloseHandle(g_hKVPlayerChoice);
    g_hKVPlayerChoice = new KeyValues("Models");
    g_hKVPlayerChoice.ImportFromFile(choicePath);
}


/**
 * Проходит по всей структуре KeyValues, находит все пути к моделям
 * и предварительно кэширует их, чтобы избежать падения сервера.
 */
void PrecacheAllMenuModels(KeyValues kv) {
    if (kv == null) return;
    kv.Rewind();
    if (!kv.GotoFirstSubKey()) return; // Вход в первую группу

    do { // Итерация по группам ("CSGO_Models", "Etc")
        if (kv.JumpToKey("Team_T", false)) {
            if (kv.GotoFirstSubKey()) { // Вход в список моделей для Team_T
                do {
                    char path[PLATFORM_MAX_PATH];
                    kv.GetString("path", path, sizeof(path), "");
                    if (path[0] != '\0' && FileExists(path, true) && !IsModelPrecached(path)) {
                        PrecacheModel(path, true);
                        //PrintToServer("[SM_SKINCHOOSER] Precached menu model: %s", path); // DEBUG
                    }
                } while (kv.GotoNextKey());
                kv.GoBack();
            }
            kv.GoBack();
        }
        if (kv.JumpToKey("Team_CT", false)) {
            if (kv.GotoFirstSubKey()) { // Вход в список моделей для Team_CT
                do {
                    char path[PLATFORM_MAX_PATH];
                    kv.GetString("path", path, sizeof(path), "");
                    if (path[0] != '\0' && FileExists(path, true) && !IsModelPrecached(path)) {
                        PrecacheModel(path, true);
                        //PrintToServer("[SM_SKINCHOOSER] Precached menu model: %s", path); // DEBUG
                    }
                } while (kv.GotoNextKey());
                kv.GoBack();
            }
            kv.GoBack();
        }
    } while (kv.GotoNextKey());

    kv.Rewind(); // Сброс для последующего построения меню
}


/**
 * Загружает списки моделей для принудительной установки.
 */
void LoadForceConfigs()
{
    g_ForcePlayerCountT = g_ForcePlayerCountCT = 0;
    g_ForceAdminCountT  = g_ForceAdminCountCT  = 0;
    g_ForceBotsCountT   = g_ForceBotsCountCT   = 0;

    if (g_cvarForcePlayerSkin.BoolValue) {
        g_ForcePlayerCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/player_t.ini",  g_ForcePlayerTeamT,  sizeof(g_ForcePlayerTeamT));
        g_ForcePlayerCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/player_ct.ini", g_ForcePlayerTeamCT, sizeof(g_ForcePlayerTeamCT));
    }
    if (g_cvarSkinAdmin.BoolValue) {
        g_ForceAdminCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/admin_t.ini",  g_ForceAdminTeamT,  sizeof(g_ForceAdminTeamT));
        g_ForceAdminCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/admin_ct.ini", g_ForceAdminTeamCT, sizeof(g_ForceAdminTeamCT));
    }
    if (g_cvarSkinBots.BoolValue) {
        g_ForceBotsCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/bots_t.ini",  g_ForceBotsTeamT,  sizeof(g_ForceBotsTeamT));
        g_ForceBotsCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/bots_ct.ini", g_ForceBotsTeamCT, sizeof(g_ForceBotsTeamCT));
    }
}

/**
 * Вспомогательная функция, читает простой текстовый файл, где каждая
 * строка - путь к модели, и добавляет их в массив. НЕ делает прекеш.
 */
int LoadSimpleModelList(const char[] iniPath, char[][] outArray, int outArraySize)
{
    int count = 0;
    char file[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file, sizeof(file), iniPath);

    File fh = OpenFile(file, "r");
    if (fh == null) return 0;

    char line[PLATFORM_MAX_PATH];
    while (fh.ReadLine(line, sizeof(line))) {
        TrimString(line);
        if (line[0] == '\0' || (line[0] == '/' && line[1] == '/')) continue;

        // Просто проверяем, что модель существует. Прекеш и загрузка делаются в ProcessDownloadList
        if (!FileExists(line, true)) {
            PrintToServer("[SM_SKINCHOOSER] Модель из списка принудительной установки не найдена: %s", line);
            continue;
        }

        // Надежно кэшируем модель, чтобы избежать падений
        if (!IsModelPrecached(line)) {
            PrecacheModel(line, true);
        }

        if (count < (outArraySize / PLATFORM_MAX_PATH)) {
            strcopy(outArray[count], PLATFORM_MAX_PATH, line);
            count++;
        } else {
            break;
        }
    }
    delete fh;
    return count;
}

// --- Логика меню ---

/**
 * Создает и отображает главное меню выбора групп моделей.
 */
Menu BuildMainMenu(int client)
{
    if (g_hKVModels == null) return null;
    g_hKVModels.Rewind();
    if (!g_hKVModels.GotoFirstSubKey()) return null;

    Menu menu = new Menu(Menu_Group);
    menu.SetTitle("Выбор группы моделей");

    int playerFlags = GetUserFlagBits(client);

    // Проходим по всем группам в конфиге
    do {
        char groupName[64];
        g_hKVModels.GetSectionName(groupName, sizeof(groupName));

        // Проверяем, есть ли у группы ограничение по флагам (поддерживаем оба ключа: "Admin" и "Flags")
        char sFlags[32];
        g_hKVModels.GetString("Admin", sFlags, sizeof(sFlags), "");
        if (sFlags[0] == '\0') {
            g_hKVModels.GetString("Flags", sFlags, sizeof(sFlags), "");
        }

        bool bHasAccess = false;
        if (sFlags[0] == '\0') { // Если флагов нет, группа общедоступна
            bHasAccess = true;
        } else {
            int requiredFlags = ReadFlagString(sFlags);
            if ((playerFlags & requiredFlags) == requiredFlags) {
                bHasAccess = true;
            }
        }

        if (bHasAccess) {
            // Если провека прошла, добавляем группу в меню
            menu.AddItem(groupName, groupName);
        }
    } while (g_hKVModels.GotoNextKey());

    menu.AddItem("reset", "[Вернуть стандартную модель]");

    g_hKVModels.Rewind(); // Возвращаем указатель в начало для следующих операций
    return menu;
}

/**
 * Обработчик главного меню. Вызывается, когда игрок выбирает группу.
 */
public void Menu_Group(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select) {
        char group[64];
        menu.GetItem(param2, group, sizeof(group));

        // Обработка выбора пункта сброса модели.
        if (StrEqual(group, "reset")) {
            ResetToDefaultModel(client);
            SavePlayerChoice(client, "");
            CPrintToChat(client, "{green}[SM] {default}Вернул стандартную модель.");
            return;
        }

        // Переходим в выбранную игроком группу
        g_hKVModels.JumpToKey(group);

        // Определяем команду игрока и переходим в соответствующую подсекцию
        if (GetClientTeam(client) == CS_TEAM_T) {
            g_hKVModels.JumpToKey("Team_T");
        } else if (GetClientTeam(client) == CS_TEAM_CT) {
            g_hKVModels.JumpToKey("Team_CT");
        } else {
            g_hKVModels.Rewind(); // Если наблюдатель, выходим
            return;
        }

        // Пытаемся войти в список моделей
        if (!g_hKVModels.GotoFirstSubKey()) {
            g_hKVModels.Rewind();
            // Сообщаем игроку, что в группе нет моделей для его команды
            CPrintToChat(client, "{red}[SM] {default}Не удалось прочесть модели внутри группы {yellow}%s{default}.", group);
            return;
        }

        // Создаем подменю для отображения моделей
        Menu sub = new Menu(Menu_Model);
        sub.SetTitle(group);
        char entryName[64], path[PLATFORM_MAX_PATH];
        int modelCount = 0; // Счетчик валидных моделей

        // Проходим по всем моделям в секции
        do {
            g_hKVModels.GetSectionName(entryName, sizeof(entryName));
            g_hKVModels.GetString("path", path, sizeof(path), "");

            // Проверяем, что модель существует
            if (path[0] != '\0' && FileExists(path, true)) {
                sub.AddItem(path, entryName);
                modelCount++; // Увеличиваем счетчик
            }
        } while (g_hKVModels.GotoNextKey());

        // Если найдены модели, показываем меню
        if (modelCount > 0) {
            CPrintToChat(client, "{green}[SM] {default}Доступно моделей: {yellow}%d", modelCount);
            sub.Display(client, g_cvarCloseMenuTimer.IntValue);
        } else {
            // Иначе сообщаем, что моделей нет
            CPrintToChat(client, "{red}[SM] {default}В группе {yellow}%s{default} нет доступных моделей.", group);
        }
        
        // ВАЖНО: всегда сбрасываем указатель в начало файла после завершения операции,
        // чтобы следующий вызов меню работал корректно.
        g_hKVModels.Rewind();
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
}

/**
 * Обработчик подменю. Вызывается, когда игрок выбирает конкретную модель.
 */
public void Menu_Model(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select) {
        char path[PLATFORM_MAX_PATH];
        menu.GetItem(param2, path, sizeof(path));

        CacheClientAuthId(client);

        // Снова исправленная проверка на существование файла
        if (!FileExists(path, true)) {
            CPrintToChat(client, "{red}[SM] {default}Ошибка: файл модели не найден: {yellow}%s", path);
            return;
        }

        // Устанавливаем модель игроку и сохраняем его выбор
        SetEntityModel(client, path);
        SavePlayerChoice(client, path);
        CPrintToChat(client, "{green}[SM] {default}Установлена модель: {yellow}%s", path);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
}

// --- Команды и События ---

public Action Command_Model(int client, int args)
{
    if (!g_cvarEnabled.BoolValue || !IsValidClient(client) || IsFakeClient(client)) {
        return Plugin_Handled;
    }

    if (g_cvarAdminOnly.BoolValue) {
        AdminId adm = GetUserAdmin(client);
        if (adm == INVALID_ADMIN_ID || !adm.HasFlag(Admin_Generic)) {
            CPrintToChat(client, "{red}[SM] {default}Меню доступно только админам.");
            return Plugin_Handled;
        }
    }

    Menu menu = BuildMainMenu(client);
    if (menu == null) {
        CPrintToChat(client, "{red}[SM] {default}Ошибка генерации меню.");
        return Plugin_Handled;
    }

    menu.Display(client, g_cvarCloseMenuTimer.IntValue);
    return Plugin_Handled;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvarEnabled.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client)) return;

    CacheClientAuthId(client);

    if (g_cvarAutodisplay.BoolValue && (event.GetInt("team") >= CS_TEAM_T)) {
        if (g_cvarDisplayTimer.BoolValue) {
            CreateTimer(g_cvarMenuStartTime.FloatValue, Timer_ShowMenuDelayed, GetClientUserId(client));
        } else {
            Command_Model(client, 0);
        }
    }
}

public void Timer_ShowMenuDelayed(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client) && !IsFakeClient(client)) {
        Command_Model(client, 0);
    }
}





public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)

{

    if (!g_cvarEnabled.BoolValue) return;



    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(client)) return;



    // Запоминаем стандартную модель при КАЖДОМ возрождении, как в v5.5

    GetEntPropString(client, Prop_Data, "m_ModelName", g_originalModel[client], sizeof(g_originalModel[]));



    // Применяем скин, который игрок выбрал ранее

    ApplySavedChoiceIfAny(client);



    // Логика принудительной установки скинов

    if (IsFakeClient(client)) {

        if (g_cvarSkinBots.BoolValue) ForceBotSkinNow(client);

    } else {

        AdminId adm = GetUserAdmin(client);

        if (adm != INVALID_ADMIN_ID && g_cvarSkinAdmin.BoolValue) {

             if (g_cvarSkinAdminTimerEnabled.BoolValue) {

                CreateTimer(g_cvarSkinAdminTimer.FloatValue, Timer_ForceAdminSkin, GetClientUserId(client));

            } else {

                ForceAdminSkinNow(client);

            }

        } else if (adm == INVALID_ADMIN_ID && g_cvarForcePlayerSkin.BoolValue) {

            if (g_cvarForcePlayerSkinTimerEnabled.BoolValue) {

                CreateTimer(g_cvarForcePlayerSkinTimer.FloatValue, Timer_ForcePlayerSkin, GetClientUserId(client));

            } else {

                ForcePlayerSkinNow(client);

            }

        }

    }

}



// --- Вспомогательные функции ---







void CacheClientAuthId(int client)

{

    if (g_authId[client][0] == '\0') {

        GetClientAuthId(client, AuthId_Steam2, g_authId[client], sizeof(g_authId[]));

    }

}



void SavePlayerChoice(int client, const char[] modelPath)

{

    if (g_hKVPlayerChoice == null || !g_cvarSaveChoice.BoolValue) return;



    CacheClientAuthId(client);

    g_hKVPlayerChoice.JumpToKey(g_authId[client], true);



    int team = GetClientTeam(client);

    if (team == CS_TEAM_T) {

        g_hKVPlayerChoice.SetString("Team_T", modelPath);

    }

    else if (team == CS_TEAM_CT) {

        g_hKVPlayerChoice.SetString("Team_CT", modelPath);

    }



    g_hKVPlayerChoice.GoBack();



    char mapName[64], filePath[PLATFORM_MAX_PATH];

    GetCurrentMap(mapName, sizeof(mapName));



    if (g_cvarMapbased.BoolValue) {

        BuildPath(Path_SM, filePath, sizeof(filePath), "data/skinchooser/%s_playermodels.ini", mapName);

    } else {

        BuildPath(Path_SM, filePath, sizeof(filePath), "data/skinchooser/skinchooser_playermodels.ini");

    }



    g_hKVPlayerChoice.ExportToFile(filePath);

}



void ApplySavedChoiceIfAny(int client)

{

    if (g_hKVPlayerChoice == null || !g_cvarLoadChoice.BoolValue) return;



    CacheClientAuthId(client);

    if (!g_hKVPlayerChoice.JumpToKey(g_authId[client])) return;



    char path[PLATFORM_MAX_PATH];

    int team = GetClientTeam(client);



    if (team == CS_TEAM_T) {

        g_hKVPlayerChoice.GetString("Team_T", path, sizeof(path));

    }

    else if (team == CS_TEAM_CT) {

        g_hKVPlayerChoice.GetString("Team_CT", path, sizeof(path));

    }

    else {

        path[0] = '\0';

    }

    

    g_hKVPlayerChoice.GoBack();



    if (path[0] == '\0' || !FileExists(path, true)) {

        return; // Нет выбранной модели для применения

    }



    // Дополнительная проверка: есть ли у игрока все еще доступ к этой модели?

    char groupName[64];

    if (FindGroupForModel(path, groupName, sizeof(groupName))) {

        g_hKVModels.Rewind();

        g_hKVModels.JumpToKey(groupName);

                char sFlags[32];

                int iFlags = 0;

                g_hKVModels.GetString("Admin", sFlags, sizeof(sFlags)); // Ищем ключ "Admin"

        if (sFlags[0] == '\0') {

            g_hKVModels.GetString("Flags", sFlags, sizeof(sFlags), "");

        }



        if (sFlags[0] != '\0') {

            iFlags = ReadFlagString(sFlags);

            if ((GetUserFlagBits(client) & iFlags) != iFlags) {

                return; // Доступ запрещен, модель не применяем

            }

        }

        g_hKVModels.Rewind();

    }



    if (!IsModelPrecached(path)) PrecacheModel(path, true);

    SetEntityModel(client, path);

}



/**

 * Ищет, к какой группе принадлежит указанный файл модели.

 * Необходимо для проверки, есть ли у игрока до сих пор доступ к модели.

 */

bool FindGroupForModel(const char[] modelPath, char[] groupBuffer, int bufferSize)

{

    if (g_hKVModels == null) return false;

    g_hKVModels.Rewind();

    if (!g_hKVModels.GotoFirstSubKey()) return false;



    do {

        g_hKVModels.GetSectionName(groupBuffer, bufferSize);

        if (g_hKVModels.JumpToKey("Team_T", false)) {

            if (g_hKVModels.GotoFirstSubKey()) {

                do {

                    char path[PLATFORM_MAX_PATH];

                    g_hKVModels.GetString("path", path, sizeof(path));

                    if (StrEqual(path, modelPath)) {

                        g_hKVModels.Rewind();

                        return true;

                    }

                } while (g_hKVModels.GotoNextKey());

                g_hKVModels.GoBack();

            }

            g_hKVModels.GoBack();

        }

        if (g_hKVModels.JumpToKey("Team_CT", false)) {

            if (g_hKVModels.GotoFirstSubKey()) {

                do {

                    char path[PLATFORM_MAX_PATH];

                    g_hKVModels.GetString("path", path, sizeof(path));

                    if (StrEqual(path, modelPath)) {

                        g_hKVModels.Rewind();

                        return true;

                    }

                } while (g_hKVModels.GotoNextKey());

                g_hKVModels.GoBack();

            }

            g_hKVModels.GoBack();

        }

    } while (g_hKVModels.GotoNextKey());



    g_hKVModels.Rewind();

    return false;

}



void ResetToDefaultModel(int client)

{

    // Устанавливаем модель, которая была у игрока при последнем спавне

    if (g_originalModel[client][0] != '\0') {

        SetEntityModel(client, g_originalModel[client]);

    }



    // Очищаем сохраненный выбор, только если сохранение включено

    if (g_hKVPlayerChoice == null || !g_cvarSaveChoice.BoolValue) return;



    CacheClientAuthId(client);

    if (!g_hKVPlayerChoice.JumpToKey(g_authId[client])) return;



    int team = GetClientTeam(client);

    if (team == CS_TEAM_T) {

        g_hKVPlayerChoice.SetString("Team_T", ""); // Очищаем выбор

    }

    else if (team == CS_TEAM_CT) {

        g_hKVPlayerChoice.SetString("Team_CT", ""); // Очищаем выбор

    }

    g_hKVPlayerChoice.GoBack();



    char mapName[64], filePath[PLATFORM_MAX_PATH];

    GetCurrentMap(mapName, sizeof(mapName));



    if (g_cvarMapbased.BoolValue) {

        BuildPath(Path_SM, filePath, sizeof(filePath), "data/skinchooser/%s_playermodels.ini", mapName);

    } else {

        BuildPath(Path_SM, filePath, sizeof(filePath), "data/skinchooser/skinchooser_playermodels.ini");

    }



    g_hKVPlayerChoice.ExportToFile(filePath);

}



public void Timer_ForceAdminSkin(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client)) ForceAdminSkinNow(client);
}
public void Timer_ForcePlayerSkin(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client)) ForcePlayerSkinNow(client);
}

void ForceAdminSkinNow(int client)
{
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T && g_ForceAdminCountT > 0) {
        SetEntityModel(client, g_ForceAdminTeamT[GetRandomInt(0, g_ForceAdminCountT - 1)]);
    } else if (team == CS_TEAM_CT && g_ForceAdminCountCT > 0) {
        SetEntityModel(client, g_ForceAdminTeamCT[GetRandomInt(0, g_ForceAdminCountCT - 1)]);
    }
}

void ForcePlayerSkinNow(int client)
{
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T && g_ForcePlayerCountT > 0) {
        SetEntityModel(client, g_ForcePlayerTeamT[GetRandomInt(0, g_ForcePlayerCountT - 1)]);
    } else if (team == CS_TEAM_CT && g_ForcePlayerCountCT > 0) {
        SetEntityModel(client, g_ForcePlayerTeamCT[GetRandomInt(0, g_ForcePlayerCountCT - 1)]);
    }
}

void ForceBotSkinNow(int client)
{
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T && g_ForceBotsCountT > 0) {
        SetEntityModel(client, g_ForceBotsTeamT[GetRandomInt(0, g_ForceBotsCountT - 1)]);
    } else if (team == CS_TEAM_CT && g_ForceBotsCountCT > 0) {
        SetEntityModel(client, g_ForceBotsTeamCT[GetRandomInt(0, g_ForceBotsCountCT - 1)]);
    }
}

stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}