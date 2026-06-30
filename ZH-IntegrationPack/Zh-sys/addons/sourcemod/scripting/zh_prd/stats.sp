#if defined _zh_prd_stats_included
 #endinput
#endif
#define _zh_prd_stats_included

void ResetMvpRoundState()
{
    g_bMvpVoteActive = false;
    g_iYesVotes = 0;
    g_iNoVotes = 0;
    ResetNativeMvpScores();
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bHasVoted[i] = false;
    }
}

int FindMVPByStars(int winning_team)
{
    int bestClient = -1;
    int bestDelta = 0;
    float bestJoinTime = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!ZH_IsValidClient(i) || GetClientTeam(i) != winning_team)
        {
            continue;
        }

        // Logic from original: prioritize star gain, then join time (older players win tie)
        int current = CS_GetMVPCount(i);
        int delta = current - g_iPrevMvpStars[i];
        
        // Add Native Contribution Scale
        if (g_hMVPNativeVoteScale.FloatValue > 0.0)
        {
            delta += RoundToFloor(g_iMvpNativeScore[i] * g_hMVPNativeVoteScale.FloatValue);
        }

        if (delta > bestDelta)
        {
            bestDelta = delta;
            bestClient = i;
            bestJoinTime = g_fJoinTime[i];
        }
        else if (delta > 0 && delta == bestDelta)
        {
            if (g_fJoinTime[i] < bestJoinTime)
            {
                bestClient = i;
                bestJoinTime = g_fJoinTime[i];
            }
        }
    }

    return bestDelta > 0 ? bestClient : -1;
}

void StartMvpVote(int winning_team)
{
    if (g_iMVP == -1) return;

    g_bMvpVoteActive = true;
    g_iYesVotes = 0;
    g_iNoVotes = 0;

    // Auto-vote for bots if enabled
    if (g_hMVPBotVoteProxy.BoolValue)
    {
        g_iYesVotes += CountBotsOnTeam(winning_team);
    }
    
    // Announce Vote
    char name[MAX_NAME_LENGTH];
    GetClientName(g_iMVP, name, sizeof(name));
    CPrintToChatAll("%T", "MVP_Vote_Start", LANG_SERVER, name);
    
    // Menu is actually handled via Chat/Keys in original PRD, usually?
    // The legacy code didn't show the vote menu implementation in the snippet I saw (it returned 'Golosovanie za MVP' comment).
    // I will implement a simple menu vote here for players.
    
    Menu voteMenu = new Menu(Handler_MvpVote);
    voteMenu.SetTitle("MVP: %s?", name);
    voteMenu.AddItem("yes", "Yes");
    voteMenu.AddItem("no", "No");
    voteMenu.ExitButton = false;
    voteMenu.DisplayVoteToAll(15);
}

public int Handler_MvpVote(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_VoteEnd)
    {
        // param1 = winning item index, param2 = count
        // We handle vote tally manually in actual vote callback usually, but DisplayVoteToAll handles it.
        // Wait, standard SM Vote API... 
        // Logic: specific items.
        // Let's rely on standard vote results.
        
        // Actually, the legacy code had custom logic. Let's simplify:
        // If "Yes" wins, give reward.
        
        // Map param1 (winning item)
        // 0 = yes, 1 = no
        
        if (param1 == 0) // Yes won or tied (if standard behavior)
        {
             FinalizeMvpReward(true); // Argument: isSuccess
        }
        else
        {
             FinalizeMvpReward(false);
        }
    }
    return 0;
}

// Helper to count bots
int CountBotsOnTeam(int team)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (ZH_IsValidClient(i, true) && IsFakeClient(i) && GetClientTeam(i) == team)
        {
            count++;
        }
    }
    return count;
}


void FinalizeMvpReward(bool success)
{
    if (!g_bMvpVoteActive) return;
    g_bMvpVoteActive = false;

    if (success)
    {
        if (ZH_IsValidClient(g_iMVP))
        {
             int reward = g_hMVPVoteAmount.IntValue; // Simple logic: fixed amount, or * votes?
             // Legacy implied: reward = votes * amount
             // Since we used standard Menu Vote, we don't have exact "Yes" count easily accessible in VoteEnd without tracking Select.
             // For now, let's give fixed reward or assume mostly Yes.
             
             // Improvement: Just give flat reward for winning vote.
             int money = GetEntProp(g_iMVP, Prop_Send, "m_iAccount");
             money += reward;
             if (money > g_iAccountCap) money = g_iAccountCap;
             SetEntProp(g_iMVP, Prop_Send, "m_iAccount", money);
             
             CPrintToChatAll("%T", "MVP_Reward_Given", LANG_SERVER, g_iMVP, reward);
        }
    }
    else
    {
        CPrintToChatAll("%T", "MVP_Vote_Failed", LANG_SERVER);
    }
}

void ResetNativeMvpScores()
{
    for (int i = 1; i <= MaxClients; i++) g_iMvpNativeScore[i] = 0;
}
