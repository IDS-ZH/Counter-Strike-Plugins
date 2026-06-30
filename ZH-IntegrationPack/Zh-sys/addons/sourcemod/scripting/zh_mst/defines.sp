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
    ClassSkinType            // Тип скина
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
ArrayList g_DownloadModels;
ArrayList g_DownloadSounds;

// Трекинг viewmodel-ов для обновления перчаток
int g_ClientViewModels[MAXPLAYERS + 1][2];  // Хранит оба viewmodel-а игрока

// Трекинг состояния thirdperson для каждого игрока
ThirdPersonMode g_ClientTpMode[MAXPLAYERS + 1];

// Таймер для автоматического отключения thirdperson после freeze time
Handle g_FreezeEndTimer[MAXPLAYERS + 1];

Handle g_fwdClassChanged;
