
void PushUniqueString(ArrayList list, const char[] value)
{
    char existing[PLATFORM_MAX_PATH];
    for (int i = 0; i < list.Length; i++)
    {
        list.GetString(i, existing, sizeof(existing));
        if (StrEqual(existing, value, false))
        {
            return;
        }
    }
    list.PushString(value);
}

void PrecacheRegisteredResources()
{
    char path[PLATFORM_MAX_PATH];

    for (int i = 0; i < g_DownloadModels.Length; i++)
    {
        g_DownloadModels.GetString(i, path, sizeof(path));
        if (path[0] == '\0')
        {
            continue;
        }
        PrecacheModel(path, true);
        AddFileToDownloadsTable(path);
    }

    for (int j = 0; j < g_DownloadSounds.Length; j++)
    {
        g_DownloadSounds.GetString(j, path, sizeof(path));
        if (path[0] == '\0')
        {
            continue;
        }
        PrecacheSound(path, true);
        AddFileToDownloadsTable(path);
    }
}
