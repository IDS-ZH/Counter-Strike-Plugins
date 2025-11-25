#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <easy_hudmessage>
#include <clientprefs>

#define PROJECT_FULLNAME "ShowDamage_MultiColour"

Handle g_hCookie;
char StyleShowDamage[MAXPLAYERS + 1][64];

public Plugin myinfo = { name = PROJECT_FULLNAME, author = "Ravskiy1 & Gemini", version = "0.2", };

public void OnPluginStart()
{
    g_hCookie = RegClientCookie("SSD", "Style ShowDamage", CookieAccess_Private);
    
    RegConsoleCmd("sm_sd", ShowDamageMenu);
    RegConsoleCmd("sm_showdamage", ShowDamageMenu);
    RegConsoleCmd("sm_С<Р?", ShowDamageMenu);
    RegConsoleCmd("sm_С<С?С%С┼Р?С"С?С"РїС?", ShowDamageMenu);
    
    for (int i; ++i <= MaxClients;)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
            continue;

        OnClientCookiesCached(i);
    }
    
    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
}

public Action ShowDamageMenu(int iClient, int args)
{
    if (iClient > 0 && args < 1) StyleShowDamageMenu(iClient);
    return Plugin_Handled;
}

public void OnClientCookiesCached(int iClient)
{
    char szValue[64];
    GetClientCookie(iClient, g_hCookie, szValue, sizeof(szValue));
    if(szValue[0])
    {
        strcopy(StyleShowDamage[iClient], sizeof(StyleShowDamage[]), szValue);
    }
    else
    {
        strcopy(StyleShowDamage[iClient], sizeof(StyleShowDamage[]), "NewStyle");
    }
}

public void OnClientDisconnect(int iClient) {
    SetClientCookie(iClient, g_hCookie, StyleShowDamage[iClient]);
    StyleShowDamage[iClient][0] = 0;
}

public void OnPlayerHurt(Event hEvent, const char[] sEvName, bool dDontBroadcast)
{
    int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
    int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
    int iDamage = hEvent.GetInt("dmg_health");
    int iHealth = GetClientHealth(iVictim);
    int iArmor = GetClientArmor(iVictim);
    char cHealth[32];
    char cArmor[32];
    
    if (0 < iAttacker <= MaxClients && !IsFakeClient(iAttacker))
    {
        int iVictimTeam = (iVictim > 0 && IsClientInGame(iVictim)) ? GetClientTeam(iVictim) : 0;
        int hudColor;
        const int HUD_CHANNEL = 6; // dedicated channel to avoid conflicts with other HUD messages

        char victimName[MAX_NAME_LENGTH];
        if (iVictim > 0 && IsClientInGame(iVictim))
        {
            GetClientName(iVictim, victimName, sizeof(victimName));
        }
        else
        {
            strcopy(victimName, sizeof(victimName), "Unknown target");
        }

        if (iAttacker == iVictim)
        {
            hudColor = 0xFFFFFFFF; // White for suicide/self-harm
        }
        else if (iVictimTeam == CS_TEAM_T) // Terrorist
        {
            hudColor = 0xFF0000FF; // Red
        }
        else if (iVictimTeam == CS_TEAM_CT) // Counter-Terrorist
        {
            hudColor = 0x007FFFFF; // Blue (original)
        }
        else // Other cases (e.g. hostages, turrets, world, etc.)
        {
            hudColor = 0x808080FF; // Gray for other entities/targets
        }

        if(iHealth > 0) FormatEx(cHealth, sizeof(cHealth), "%i", iHealth);
        else FormatEx(cHealth, sizeof(cHealth), "0");

        if(iArmor > 0) FormatEx(cArmor, sizeof(cArmor), "%i", iArmor);
        else FormatEx(cArmor, sizeof(cArmor), "0");

        if(StrEqual(StyleShowDamage[iAttacker], "NewStyle")) 
        {
            char sHudMessage[256];
            FormatEx(sHudMessage, sizeof(sHudMessage), "%s\nDamage -%i | HP %s | Armor %s", victimName, iDamage, cHealth, cArmor);
            SendHudMessage(iAttacker, HUD_CHANNEL, -1.0, -0.6, hudColor, 0x333333FF, 0, 0.3, 1.0, 1.0, 2.0, sHudMessage);
        }
        else if (StrEqual(StyleShowDamage[iAttacker], "OldStyle")) 
        {
            PrintCenterText(iAttacker, "\nDamage -%i | HP %s | Armor %s", iDamage, cHealth, cArmor);
        }
    }
} 
public void StyleShowDamageMenu(int iClient)
{
    Menu hStyleShowDamageMenu = new Menu(MenuHandler_hStyleShowDamageMenu);
    
    hStyleShowDamageMenu.ExitBackButton = false;
    hStyleShowDamageMenu.ExitButton = true;
    
    hStyleShowDamageMenu.SetTitle("✖ Style Show Damage ✖\n ");
    
    if (StrEqual(StyleShowDamage[iClient], "NewStyle", false)) hStyleShowDamageMenu.AddItem("", "Новый [✓]", ITEMDRAW_DISABLED);
    else hStyleShowDamageMenu.AddItem("", "Новый [✕]", ITEMDRAW_DEFAULT);
    
    if (StrEqual(StyleShowDamage[iClient], "OldStyle", false)) hStyleShowDamageMenu.AddItem("", "Старый [✓]", ITEMDRAW_DISABLED);
    else hStyleShowDamageMenu.AddItem("", "Старый [✕]", ITEMDRAW_DEFAULT);
    
    if (StrEqual(StyleShowDamage[iClient], "OffStyle", false)) hStyleShowDamageMenu.AddItem("", "Отключить [✓]", ITEMDRAW_DISABLED);
    else hStyleShowDamageMenu.AddItem("", "Отключить [✕]", ITEMDRAW_DEFAULT);
    
    hStyleShowDamageMenu.Display(iClient, 30);
}

public int MenuHandler_hStyleShowDamageMenu(Menu hStyleShowDamageMenu, MenuAction action, int iClient, int iItem)
{
    switch(action)
    {
        case MenuAction_End: { delete hStyleShowDamageMenu; }
        case MenuAction_Select:
        {
            switch(iItem)
            {
                 case 0: { SetClientCookie(iClient, g_hCookie, "NewStyle"); SendHudMessage(iClient, 6, -1.0, -0.6, 0x007FFFFF, 0x333333FF, 0, 0.3, 1.0, 1.0, 2.0, "%N\nDamage -%i | HP %i/Armor", iClient, GetRandomInt(1, 100)); }
                 case 1: { SetClientCookie(iClient, g_hCookie, "OldStyle"); PrintCenterText(iClient, "Damage -%i | HP %i/Armor", GetRandomInt(1, 100), GetRandomInt(1, 100)); }
                 case 2: SetClientCookie(iClient, g_hCookie, "OffStyle"); 
            }
            OnClientCookiesCached(iClient);
            StyleShowDamageMenu(iClient);
        }
    }
    return 0;
}
