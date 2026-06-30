#if defined _zh_prd_menu_included
 #endinput
#endif
#define _zh_prd_menu_included

void ShowPunishmentMenu(int victim, int attacker)
{
    if (!ZH_IsValidClient(victim)) return;

    // Verify attacker is still valid/ingame, but they might have disconnected
    // If disconnected, show message
    if (!ZH_IsValidClient(attacker))
    {
        CPrintToChat(victim, "%T", "TKAggressorLeft", victim);
        return;
    }

    g_iTeamkillAttacker[victim] = attacker;

    char sName[MAX_NAME_LENGTH];
    GetClientName(attacker, sName, sizeof(sName));

    Menu menu = new Menu(MenuHandler_TeamkillPunishment);
    char title[128];
    Format(title, sizeof(title), "%T", "TKMenuTitle", victim, sName);
    menu.SetTitle(title);

    char forgiveText[64];
    Format(forgiveText, sizeof(forgiveText), "%T", "TKMenuForgive", victim);
    menu.AddItem("forgive", forgiveText);

    if (g_hPunishments != null)
    {
        for (int i = 0; i < g_hPunishments.Length; i++)
        {
            KeyValues p = g_hPunishments.Get(i);
            char p_name[32], p_translation[64];
            p.GetSectionName(p_name, sizeof(p_name));
            p.GetString("translation", p_translation, sizeof(p_translation));
            
            // Translate the option name
            char displayOption[128];
            Format(displayOption, sizeof(displayOption), "%T", p_translation, victim);
            
            menu.AddItem(p_name, displayOption);
        }
    }

    menu.Display(victim, MENU_TIME_FOREVER);
}

public int MenuHandler_TeamkillPunishment(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (!ZH_IsValidClient(client)) return 0;

        int attacker = g_iTeamkillAttacker[client];
        if (!ZH_IsValidClient(attacker))
        {
            CPrintToChat(client, "%T", "TKAggressorLeft", client);
            return 0;
        }

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "forgive"))
        {
            CPrintToChatAll("%t", "Teamkill_Forgive", client, attacker);
        }
        else
        {
            // Find selected punishment
            for (int i = 0; i < g_hPunishments.Length; i++)
            {
                KeyValues p = g_hPunishments.Get(i);
                char p_name[32];
                p.GetSectionName(p_name, sizeof(p_name));
                if (StrEqual(info, p_name))
                {
                    ApplyPunishmentAction(client, attacker, p);
                    break;
                }
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
        if (ZH_IsValidClient(client))
        {
            g_iTeamkillAttacker[client] = 0;
        }
    }
    return 0;
}

void ApplyPunishmentAction(int victim, int attacker, KeyValues p)
{
    char command[256], translation[64], type[32];
    p.GetString("command", command, sizeof(command));
    p.GetString("translation", translation, sizeof(translation));
    p.GetString("type", type, sizeof(type)); // 'mst', 'rha', 'cmd'

    if (StrEqual(type, "mst"))
    {
        // Integration: MST
        // command might be "chicken" or "clown"
        // Since we don't have natives yet, we use ServerCommand fallback or placeholder
        // TODO: Call ZH_MST_SetPunishmentSkin(attacker, command);
        ZH_Log(ZH_LOG_DEBUG, "MST Punishment requested: %s for %N", command, attacker);
        ServerCommand("sm_mst_skin %d %s", GetClientUserId(attacker), command); 
    }
    else if (StrEqual(type, "rha"))
    {
        // Integration: RHA
        int amount = p.GetNum("amount", -50);
        // TODO: Call ZH_RHA_TakeHealth(attacker, amount);
        SetEntityHealth(attacker, GetClientHealth(attacker) + amount); // Fallback
    }
    else
    {
         // Default: Command execution
        char formatted_command[256];
        FormatEx(formatted_command, sizeof(formatted_command), command, GetClientUserId(attacker)); // Assuming command uses #userid
        ServerCommand(formatted_command);
    }

    CPrintToChatAll("%t", translation, victim, attacker);
}
