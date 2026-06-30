
// --- SDKHooks for updating gloves when player changes weapons ---
// Эти хуки работают только при наличии viewmodel-ов и только для перчаток

// Хук при экипировке оружия
public void OnWeaponEquipPost(int client, int weapon)
{
    if (!ZH_IsValidClient(client) || !g_ConfigsLoaded)
        return;

    // Обновляем перчатки при смене оружия
    UpdateGlovesForClient(client);
}

// Хук при переключении оружия
public void OnWeaponSwitchPost(int client, int weapon)
{
    if (!ZH_IsValidClient(client) || !g_ConfigsLoaded)
        return;

    // Обновляем перчатки при переключении оружия
    UpdateGlovesForClient(client);
}

// Обновление перчаток на viewmodel-е
void UpdateGlovesForClient(int client)
{
    if (!ZH_IsValidClient(client) || !g_ConfigsLoaded)
        return;

    int clientClass = g_ClientClass[client];
    if (clientClass == -1)
        return;

    // Получаем информацию о перчатках для текущего класса
    char gloveModel[PLATFORM_MAX_PATH];
    int gloveSkin;
    GetGloveInfoForClass(clientClass, gloveModel, sizeof(gloveModel), gloveSkin);

    if (gloveModel[0] == '\0')
        return; // Нет модели перчаток для этого класса

    // Обновляем перчатки на обоих viewmodel-ах
    UpdateGloveOnViewModel(client, 0, gloveModel, gloveSkin);
    UpdateGloveOnViewModel(client, 1, gloveModel, gloveSkin);
}

void UpdateGloveOnViewModel(int client, int viewModelIndex, const char[] gloveModel, int gloveSkin)
{
    // Получаем viewmodel игрока
    int viewModel = GetEntPropEnt(client, Prop_Data, viewModelIndex == 0 ? "m_hViewModel[0]" : "m_hViewModel[1]");
    if (viewModel == -1 || !IsValidEntity(viewModel))
        return;

    // Устанавливаем модель перчаток
    SetVariantString(gloveModel);
    AcceptEntityInput(viewModel, "SetModel");

    // Устанавливаем скин перчаток (если модель поддерживает)
    if (gloveSkin >= 0)
    {
        SetEntProp(viewModel, Prop_Send, "m_nSkin", gloveSkin);
    }
}

// Хуки для отслеживания создания viewmodel-ов
public void OnEntitySpawned(const char[] output, int caller, int activator, float delay)
{
    // Проверяем, является ли entity viewmodel-ом
    char className[64];
    GetEntityClassname(caller, className, sizeof(className));

    if (StrEqual(className, "viewmodel", false))
    {
        // Проверяем, принадлежит ли viewmodel игроку
        int owner = GetEntPropEnt(caller, Prop_Send, "m_hOwner");
        if (owner > 0 && owner <= MaxClients && IsClientInGame(owner))
        {
            // Получаем текущий класс игрока и обновляем перчатки на этом viewmodel-е
            int clientClass = g_ClientClass[owner];
            if (clientClass != -1)
            {
                char gloveModel[PLATFORM_MAX_PATH];
                int gloveSkin;
                GetGloveInfoForClass(clientClass, gloveModel, sizeof(gloveModel), gloveSkin);

                if (gloveModel[0] != '\0')
                {
                    SetVariantString(gloveModel);
                    AcceptEntityInput(caller, "SetModel");
                }
            }
        }
    }
}

// Событие при спауне игрока
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!ZH_IsValidClient(client))
        return;

    // Обновляем перчатки после спауна игрока
    UpdateGlovesForClient(client);
}
