
public Action Command_ReloadMst(int client, int args)
{
    LoadMstConfigs();
    if (ZH_IsValidClient(client))
    {
        ReplyToCommand(client, "[ZH-MST] Configs reloaded.");
    }
    return Plugin_Handled;
}

public Action Command_SetMode(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "Usage: sm_mst_mode <mode> <0/1> (modes: dm,tdm,gg,chicken,revive)");
        return Plugin_Handled;
    }

    char mode[16];
    GetCmdArg(1, mode, sizeof(mode));
    char valueStr[16];
    GetCmdArg(2, valueStr, sizeof(valueStr));
    int value = StringToInt(valueStr);

    if (StrEqual(mode, "dm", false))
    {
        g_CvarMstModeDM.SetInt(value);
    }
    else if (StrEqual(mode, "tdm", false))
    {
        g_CvarMstModeTDM.SetInt(value);
    }
    else if (StrEqual(mode, "gg", false))
    {
        g_CvarMstModeGG.SetInt(value);
    }
    else if (StrEqual(mode, "chicken", false))
    {
        g_CvarMstModeChicken.SetInt(value);
    }
    else if (StrEqual(mode, "revive", false))
    {
        g_CvarMstModeRevive.SetInt(value);
    }
    else
    {
        ReplyToCommand(client, "Unknown mode: %s", mode);
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[ZH-MST] %s set to %d", mode, value);
    return Plugin_Handled;
}

// Команды thirdperson
public Action Command_ThirdPerson(int client, int args)
{
    if (!g_CvarTpEnabled.BoolValue || !ZH_IsValidClient(client))
    {
        return Plugin_Handled;
    }

    ToggleClientThirdPersonMode(client, true);

    char modeName[32];
    GetThirdPersonModeName(g_ClientTpMode[client], modeName, sizeof(modeName));
    ReplyToCommand(client, "[ZH-MST-TP] Third-person mode changed to: %s", modeName);

    return Plugin_Handled;
}

public Action Command_ThirdPersonMode(int client, int args)
{
    if (!g_CvarTpEnabled.BoolValue || !ZH_IsValidClient(client))
    {
        return Plugin_Handled;
    }

    if (args == 0)
    {
        ReplyToCommand(client, "[ZH-MST-TP] Usage: sm_tp_mode <0|1|2> (0=firstperson, 1=thirdperson, 2=static thirdperson)");
        char modeName[32];
        GetThirdPersonModeName(g_ClientTpMode[client], modeName, sizeof(modeName));
        ReplyToCommand(client, "[ZH-MST-TP] Current mode: %d (%s)", g_ClientTpMode[client], modeName);
        return Plugin_Handled;
    }

    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));
    ThirdPersonMode mode = view_as<ThirdPersonMode>(StringToInt(arg));

    if (mode < ThirdPersonMode_FirstPerson || mode > ThirdPersonMode_ThirdPersonStatic)
    {
        ReplyToCommand(client, "[ZH-MST-TP] Invalid mode. Valid modes: 0=firstperson, 1=thirdperson, 2=static thirdperson");
        return Plugin_Handled;
    }

    SetClientThirdPersonMode(client, mode, true);

    char modeName[32];
    GetThirdPersonModeName(g_ClientTpMode[client], modeName, sizeof(modeName));
    ReplyToCommand(client, "[ZH-MST-TP] Third-person mode set to: %d (%s)", view_as<int>(mode), modeName);

    return Plugin_Handled;
}
