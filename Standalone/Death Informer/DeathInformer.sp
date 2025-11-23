/****************************************************************
*****************************************************************
*                                                               *
*   Death Informer Enhanced                                     *
*                                                               *
*   Author: Qwen for ZloyHohol (Fixed by Gemini)                *
*                                                               *
*   Description:                                                *
*   An enhanced version of the Death Informer plugin with       *
*   improved damage tracking, proper shotgun damage             *
*   aggregation, protection against bypass, and configurable    *
*   display settings. This version uses translation files and   *
*   the multicolors library.                                    *
*                                                               *
*****************************************************************
****************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <string>
#include <multicolors>

#define MAX_HISTORY 20

// --- Enums for weapon types ---
enum WeaponType
{
    WEAPONTYPE_UNKNOWN,
    WEAPONTYPE_SHOTGUN,
    WEAPONTYPE_RIFLE,
    WEAPONTYPE_PISTOL,
    WEAPONTYPE_SNIPER,
    WEAPONTYPE_SMG,
    WEAPONTYPE_HEAVY,
    WEAPONTYPE_MELEE,
    WEAPONTYPE_GRENADE
};

// --- Global Variables ---

ConVar g_hHistoryTime;
ConVar g_hEnableDetailedInfo;
ConVar g_hEnableShotgunAggregation;

int g_iDamageHistory_Damage[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_HISTORY];
float g_fDamageHistory_Timestamp[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_HISTORY];
WeaponType g_eDamageHistory_Weapon[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_HISTORY];
int g_iDamageHistory_HitGroup[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_HISTORY];
int g_iDamageHistory_BeforeHealth[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_HISTORY];
bool g_bDamageHistory_Headshot[MAXPLAYERS + 1][MAXPLAYERS + 1][MAX_HISTORY];

int g_iDamageIndex[MAXPLAYERS + 1][MAXPLAYERS + 1];

// --- Plugin Info ---

public Plugin myinfo =
{
    name = "Death Informer Enhanced",
    author = "Qwen for ZloyHohol (Fixed by Gemini)",
    description = "Enhanced version of Death Informer with detailed damage tracking and shotgun aggregation.",
    version = "1.3"
};

// --- Plugin Forwards ---

public void OnPluginStart()
{
    g_hHistoryTime = CreateConVar("sm_deathinformer_history_time", "30.0", "How long (in seconds) to track damage history from an attacker before death. Min 10.0, Max 300.0", FCVAR_NONE, true, 10.0, true, 300.0);
    g_hEnableDetailedInfo = CreateConVar("sm_deathinformer_detail_info", "1", "Enable detailed information about hit locations and damage types (0 = off, 1 = on)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_hEnableShotgunAggregation = CreateConVar("sm_deathinformer_shotgun_agg", "1", "Enable aggregation of shotgun pellet damage from a single shot (0 = off, 1 = on)", FCVAR_NONE, true, 0.0, true, 1.0);

    if (!LoadTranslations("deathinformer.phrases.txt"))
    {
        LogError("Could not load translation file 'deathinformer.phrases.txt'. This plugin will not work correctly without it.");
    }

    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
}

public void OnMapStart()
{
    ClearAllDamageHistory();
}

// --- Helper Functions ---

WeaponType GetWeaponType(const char[] sWeapon)
{
    if (StrEqual(sWeapon, "m3") || StrEqual(sWeapon, "xm1014")) return WEAPONTYPE_SHOTGUN;
    if (StrEqual(sWeapon, "ak47") || StrEqual(sWeapon, "m4a1") || StrEqual(sWeapon, "galil") || StrEqual(sWeapon, "famas") || StrEqual(sWeapon, "sg552") || StrEqual(sWeapon, "aug")) return WEAPONTYPE_RIFLE;
    if (StrEqual(sWeapon, "glock") || StrEqual(sWeapon, "usp") || StrEqual(sWeapon, "p228") || StrEqual(sWeapon, "deagle") || StrEqual(sWeapon, "elite") || StrEqual(sWeapon, "fiveseven")) return WEAPONTYPE_PISTOL;
    if (StrEqual(sWeapon, "awp") || StrEqual(sWeapon, "scout") || StrEqual(sWeapon, "sg550") || StrEqual(sWeapon, "g3sg1")) return WEAPONTYPE_SNIPER;
    if (StrEqual(sWeapon, "mp5navy") || StrEqual(sWeapon, "tmp") || StrEqual(sWeapon, "p90") || StrEqual(sWeapon, "mac10") || StrEqual(sWeapon, "ump45")) return WEAPONTYPE_SMG;
    if (StrEqual(sWeapon, "m249")) return WEAPONTYPE_HEAVY;
    if (StrContains(sWeapon, "knife") != -1 || StrContains(sWeapon, "bayonet") != -1) return WEAPONTYPE_MELEE;
    if (StrContains(sWeapon, "hegrenade") != -1 || StrContains(sWeapon, "flashbang") != -1 || StrContains(sWeapon, "smokegrenade") != -1) return WEAPONTYPE_GRENADE;
    return WEAPONTYPE_UNKNOWN;
}

void GetHitGroupName(int client, int hitGroup, char[] buffer, int maxLen)
{
    if (hitGroup == 1) Format(buffer, maxLen, "%T", "hit_head", client);
    else if (hitGroup == 2) Format(buffer, maxLen, "%T", "hit_chest", client);
    else if (hitGroup == 3) Format(buffer, maxLen, "%T", "hit_stomach", client);
    else if (hitGroup == 4 || hitGroup == 5) Format(buffer, maxLen, "%T", "hit_arm", client);
    else if (hitGroup == 6 || hitGroup == 7) Format(buffer, maxLen, "%T", "hit_leg", client);
    else if (hitGroup == 8) Format(buffer, maxLen, "%T", "hit_neck", client);
    else Format(buffer, maxLen, "%T", "hit_body", client);
}

void RecordDamage(int iVictim, int iAttacker, int iDamage, WeaponType weaponType, int hitGroup, bool isHeadshot, int healthBefore)
{
    int iIndex = g_iDamageIndex[iVictim][iAttacker];
    int iPrevIndex = (iIndex - 1 + MAX_HISTORY) % MAX_HISTORY;

    bool shouldAggregate = g_hEnableShotgunAggregation.BoolValue &&
                          weaponType == WEAPONTYPE_SHOTGUN &&
                          g_eDamageHistory_Weapon[iVictim][iAttacker][iPrevIndex] == weaponType &&
                          (GetGameTime() - g_fDamageHistory_Timestamp[iVictim][iAttacker][iPrevIndex] < 0.01);

    if (shouldAggregate)
    {
        g_iDamageHistory_Damage[iVictim][iAttacker][iPrevIndex] += iDamage;
        g_bDamageHistory_Headshot[iVictim][iAttacker][iPrevIndex] = g_bDamageHistory_Headshot[iVictim][iAttacker][iPrevIndex] || isHeadshot;
    }
    else
    {
        g_iDamageHistory_Damage[iVictim][iAttacker][iIndex] = iDamage;
        g_fDamageHistory_Timestamp[iVictim][iAttacker][iIndex] = GetGameTime();
        g_eDamageHistory_Weapon[iVictim][iAttacker][iIndex] = weaponType;
        g_iDamageHistory_HitGroup[iVictim][iAttacker][iIndex] = hitGroup;
        g_iDamageHistory_BeforeHealth[iVictim][iAttacker][iIndex] = healthBefore;
        g_bDamageHistory_Headshot[iVictim][iAttacker][iIndex] = isHeadshot;
        g_iDamageIndex[iVictim][iAttacker] = (iIndex + 1) % MAX_HISTORY;
    }
}

void ClearAllDamageHistory()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        for (int j = 1; j <= MaxClients; j++)
        {
            g_iDamageIndex[i][j] = 0;
            for (int k = 0; k < MAX_HISTORY; k++)
            {
                g_fDamageHistory_Timestamp[i][j][k] = 0.0;
                g_iDamageHistory_Damage[i][j][k] = 0;
                g_eDamageHistory_Weapon[i][j][k] = WEAPONTYPE_UNKNOWN;
                g_iDamageHistory_HitGroup[i][j][k] = 0;
                g_iDamageHistory_BeforeHealth[i][j][k] = 0;
                g_bDamageHistory_Headshot[i][j][k] = false;
            }
        }
    }
}

// --- Event Handlers ---

public void OnRoundStart(Event event, const char[] name, bool silent)
{
    ClearAllDamageHistory();
}

public void OnPlayerHurt(Event event, const char[] name, bool silent)
{
    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

    if (iVictim > 0 && iAttacker > 0 && iVictim != iAttacker)
    {
        char sWeapon[64];
        event.GetString("weapon", sWeapon, sizeof(sWeapon));
        int iDamage = event.GetInt("dmg_health");

        if (iDamage > 0)
        {
            int hitGroup = event.GetInt("hitgroup");
            bool isHeadshot = event.GetBool("headshot");
            int healthBefore = event.GetInt("health") + iDamage;
            WeaponType weaponType = GetWeaponType(sWeapon);
            RecordDamage(iVictim, iAttacker, iDamage, weaponType, hitGroup, isHeadshot, healthBefore);
        }
    }
}

public void OnPlayerDeath(Event event, const char[] name, bool silent)
{
    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

    if (iVictim <= 0) return;

    if (iAttacker == 0 || iAttacker == iVictim)
    {
        CPrintToChat(iVictim, "{default}%T", "Suicide", iVictim);
        return;
    }

    if (iAttacker <= 0 || !IsClientInGame(iAttacker)) return;

    char sAttackerName[MAX_NAME_LENGTH];
    GetClientName(iAttacker, sAttackerName, sizeof(sAttackerName));

    if (sAttackerName[0] == '\0') return;

    int iAttackerHealth = GetClientHealth(iAttacker);
    int iAttackerArmor = GetClientArmor(iAttacker);
    int iAttackerTeam = GetClientTeam(iAttacker);
    char sAttackerColor[16];
    if (iAttackerTeam == 2) strcopy(sAttackerColor, sizeof(sAttackerColor), "{red}");
    else strcopy(sAttackerColor, sizeof(sAttackerColor), "{blue}");

    CPrintToChat(iVictim, " ");

    char sTranslated[128];
    Format(sTranslated, sizeof(sTranslated), "%T", "Killed by", iVictim);
    CPrintToChat(iVictim, "{default}%s %s%s", sTranslated, sAttackerColor, sAttackerName);

    char sHpText[64], sArmorText[64];
    Format(sHpText, sizeof(sHpText), "%T", "Attacker HP", iVictim);
    Format(sArmorText, sizeof(sArmorText), "%T", "Armor", iVictim);
    CPrintToChat(iVictim, "{default}%s {green}%d {default}| %s {lightgreen}%d", sHpText, iAttackerHealth, sArmorText, iAttackerArmor);

    float fHistoryTime = g_hHistoryTime.FloatValue;
    float fCurrentTime = GetGameTime();

    int iTotalDamage = 0;
    int iHitCount = 0;
    int iHeadshotCount = 0;
    int iChestHits = 0;
    int iStomachHits = 0;
    int iArmHits = 0;
    int iLegHits = 0;
    int iOtherHits = 0;
    int iMaxSingleDamage = 0;
    int iMaxHitGroup = 0;
    char sMaxHitGroupName[32];
    char sDamageList[512] = "";

    for (int i = 0; i < MAX_HISTORY; i++)
    {
        float fTimestamp = g_fDamageHistory_Timestamp[iVictim][iAttacker][i];
        if (fTimestamp > 0.0 && (fCurrentTime - fTimestamp) <= fHistoryTime)
        {
            int iDamage = g_iDamageHistory_Damage[iVictim][iAttacker][i];
            int iHitGroup = g_iDamageHistory_HitGroup[iVictim][iAttacker][i];

            iHitCount++;
            iTotalDamage += iDamage;

            switch (iHitGroup)
            {
                case 1: iHeadshotCount++;
                case 2: iChestHits++;
                case 3: iStomachHits++;
                case 4: iArmHits++;
                case 5: iArmHits++;
                case 6: iLegHits++;
                case 7: iLegHits++;
                default: iOtherHits++;
            }

            if (iDamage > iMaxSingleDamage)
            {
                iMaxSingleDamage = iDamage;
                iMaxHitGroup = iHitGroup;
                GetHitGroupName(iVictim, iMaxHitGroup, sMaxHitGroupName, sizeof(sMaxHitGroupName));
            }

            char sDamageEntry[64];
            if (g_hEnableDetailedInfo.BoolValue)
            {
                char sHitGroupName[32];
                GetHitGroupName(iVictim, iHitGroup, sHitGroupName, sizeof(sHitGroupName));
                Format(sDamageEntry, sizeof(sDamageEntry), "%d[%s]", iDamage, sHitGroupName);
            }
            else
            {
                Format(sDamageEntry, sizeof(sDamageEntry), "%d", iDamage);
            }

            if (sDamageList[0] == '\0')
            {
                strcopy(sDamageList, sizeof(sDamageList), sDamageEntry);
            }
            else
            {
                Format(sDamageList, sizeof(sDamageList), "%s, %s", sDamageList, sDamageEntry);
            }
        }
    }

    if (iHitCount > 0)
    {
        float fAvgDamage = float(iTotalDamage) / float(iHitCount);

        char sDmgStats[256];
        Format(sDmgStats, sizeof(sDmgStats), "%T", "Damage Stats", iVictim, iTotalDamage, iHitCount, fAvgDamage);
        CPrintToChat(iVictim, "{default}%s", sDmgStats);


        if (g_hEnableDetailedInfo.BoolValue)
        {
            int iTorsoHits = iChestHits + iStomachHits;
            if (iTorsoHits > 0)
            {
                char sTorsoHits[128];
                Format(sTorsoHits, sizeof(sTorsoHits), "%T", "Torso Hits", iVictim, iTorsoHits, iChestHits, iStomachHits);
                CPrintToChat(iVictim, "{lightgreen}%s", sTorsoHits);
            }
            if (iHeadshotCount > 0)
            {
                Format(sTranslated, sizeof(sTranslated), "%T", "Head Hits", iVictim);
                CPrintToChat(iVictim, "{green}%s %d", sTranslated, iHeadshotCount);
            }
            if (iArmHits > 0)
            {
                Format(sTranslated, sizeof(sTranslated), "%T", "Arm Hits", iVictim);
                CPrintToChat(iVictim, "{lightgreen}%s %d", sTranslated, iArmHits);
            }
            if (iLegHits > 0)
            {
                Format(sTranslated, sizeof(sTranslated), "%T", "Leg Hits", iVictim);
                CPrintToChat(iVictim, "{lightgreen}%s %d", sTranslated, iLegHits);
            }

            if (iMaxSingleDamage > 0)
            {
                char sMaxDmg[128], sTo[16];
                Format(sMaxDmg, sizeof(sMaxDmg), "%T", "Max Damage", iVictim);
                Format(sTo, sizeof(sTo), "%T", "to", iVictim);
                CPrintToChat(iVictim, "{default}%s {red}%d {default}%s %s", sMaxDmg, iMaxSingleDamage, sTo, sMaxHitGroupName);
            }
        }

        if (!g_hEnableDetailedInfo.BoolValue && strlen(sDamageList) > 0)
        {
            Format(sTranslated, sizeof(sTranslated), "%T", "Damage List", iVictim);
            CPrintToChat(iVictim, "{default}%s [{red}%s{default}]", sTranslated, sDamageList);
        }
    }
    CPrintToChat(iVictim, " ");
}
