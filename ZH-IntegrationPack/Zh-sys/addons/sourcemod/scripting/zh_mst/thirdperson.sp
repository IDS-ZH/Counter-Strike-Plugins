
// --- ThirdPerson Functions ---

void SetClientViewMode(int client, ThirdPersonMode mode)
{
    if (!ZH_IsValidClient(client))
    {
        return;
    }

    switch (mode)
    {
        case ThirdPersonMode_FirstPerson:
        {
            // Включаем firstperson
            SetThirdPersonClient(client, false);
        }
        case ThirdPersonMode_ThirdPerson:
        {
            // Включаем thirdperson
            SetThirdPersonClient(client, true);
        }
        case ThirdPersonMode_ThirdPersonStatic:
        {
            // Включаем thirdperson и фиксируем угол (имитация thirdperson_mayamode)
            SetThirdPersonClient(client, true);
            // Пользовательский угол устанавливается отдельно
        }
    }
}

void SetThirdPersonClient(int client, bool enabled)
{
    // Устанавливаем клиентскую переменную для thirdperson
    // В CS:Source для этого нужно отправить клиентскую команду
    if (enabled)
    {
        // Включаем thirdperson
        ClientCommand(client, "cl_thirdperson 1");
    }
    else
    {
        // Выключаем thirdperson
        ClientCommand(client, "cl_thirdperson 0");
    }
}

void GetThirdPersonModeName(ThirdPersonMode mode, char[] buffer, int maxlen)
{
    switch (mode)
    {
        case ThirdPersonMode_FirstPerson:
            strcopy(buffer, maxlen, "First Person");
        case ThirdPersonMode_ThirdPerson:
            strcopy(buffer, maxlen, "Third Person");
        case ThirdPersonMode_ThirdPersonStatic:
            strcopy(buffer, maxlen, "Static Third Person");
        default:
            strcopy(buffer, maxlen, "Unknown");
    }
}

bool SetClientThirdPersonMode(int client, ThirdPersonMode mode, bool sendUpdate)
{
    if (!ZH_IsValidClient(client))
    {
        return false;
    }

    if (mode < ThirdPersonMode_FirstPerson || mode > ThirdPersonMode_ThirdPersonStatic)
    {
        return false;
    }

    g_ClientTpMode[client] = mode;

    if (sendUpdate)
    {
        SetClientViewMode(client, mode);
    }

    if (g_CvarTpEnabled != null && g_CvarTpEnabled.BoolValue && g_CvarMstDebug != null && g_CvarMstDebug.BoolValue)
    {
        ZH_LogInfo("Client %d set thirdperson mode to %d", client, view_as<int>(mode));
    }

    return true;
}

bool ToggleClientThirdPersonMode(int client, bool sendUpdate)
{
    if (!ZH_IsValidClient(client))
    {
        return false;
    }

    ThirdPersonMode mode = g_ClientTpMode[client] == ThirdPersonMode_FirstPerson
        ? ThirdPersonMode_ThirdPerson
        : ThirdPersonMode_FirstPerson;

    return SetClientThirdPersonMode(client, mode, sendUpdate);
}

// События для thirdperson
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_CvarTpEnabled.BoolValue || !g_CvarTpFreezeTime.BoolValue)
    {
        return;
    }

    // Включаем thirdperson для всех игроков на время freeze time
    for (int i = 1; i <= MaxClients; i++)
    {
        if (ZH_IsValidClient(i, false, true))
        {
            g_ClientTpMode[i] = ThirdPersonMode_ThirdPerson;
            SetClientViewMode(i, ThirdPersonMode_ThirdPerson);
        }
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // Отключаем thirdperson для всех игроков
    for (int i = 1; i <= MaxClients; i++)
    {
        if (ZH_IsValidClient(i, false, true) && g_ClientTpMode[i] != ThirdPersonMode_FirstPerson)
        {
            g_ClientTpMode[i] = ThirdPersonMode_FirstPerson;
            SetClientViewMode(i, ThirdPersonMode_FirstPerson);
        }
    }
}

public void Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_CvarTpEnabled.BoolValue || !g_CvarTpFreezeTimeEnd.BoolValue)
    {
        return;
    }

    // Отключаем thirdperson после окончания freeze time
    for (int i = 1; i <= MaxClients; i++)
    {
        if (ZH_IsValidClient(i, false, true) && g_ClientTpMode[i] == ThirdPersonMode_ThirdPerson)
        {
            g_ClientTpMode[i] = ThirdPersonMode_FirstPerson;
            SetClientViewMode(i, ThirdPersonMode_FirstPerson);
        }
    }
}
