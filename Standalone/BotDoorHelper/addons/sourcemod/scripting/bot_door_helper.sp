#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
    name = "Bot Door Helper",
    author = "Antigravity",
    description = "Helps bots open doors linked to buttons",
    version = PLUGIN_VERSION,
    url = ""
};

// Map of door targetname to button entity reference
StringMap g_DoorToButtonMap;
float g_LastDoorUse[2048]; // Cooldown per entity index

public void OnPluginStart()
{
    g_DoorToButtonMap = new StringMap();
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
    ParseBSPEntities();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Hook all doors
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "func_door")) != -1)
    {
        SDKHook(entity, SDKHook_Touch, OnDoorTouch);
    }
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "func_door_rotating")) != -1)
    {
        SDKHook(entity, SDKHook_Touch, OnDoorTouch);
    }
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != -1)
    {
        SDKHook(entity, SDKHook_Touch, OnDoorTouch);
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "func_door") || StrEqual(classname, "func_door_rotating") || StrEqual(classname, "prop_door_rotating"))
    {
        SDKHook(entity, SDKHook_Touch, OnDoorTouch);
    }
}

public Action OnDoorTouch(int door, int other)
{
    if (other < 1 || other > MaxClients || !IsClientInGame(other) || !IsFakeClient(other) || !IsPlayerAlive(other))
    {
        return Plugin_Continue;
    }

    float currentTime = GetGameTime();
    if (currentTime - g_LastDoorUse[door] < 3.0)
    {
        return Plugin_Continue; // Cooldown
    }

    char targetname[128];
    GetEntPropString(door, Prop_Data, "m_iName", targetname, sizeof(targetname));

    if (targetname[0] == '\0')
    {
        return Plugin_Continue;
    }

    int buttonRef = 0;
    if (g_DoorToButtonMap.GetValue(targetname, buttonRef))
    {
        int buttonEnt = EntRefToEntIndex(buttonRef);
        if (buttonEnt != -1 && IsValidEntity(buttonEnt))
        {
            AcceptEntityInput(buttonEnt, "Press", other, other);
            g_LastDoorUse[door] = currentTime;
        }
    }

    return Plugin_Continue;
}

void ParseBSPEntities()
{
    g_DoorToButtonMap.Clear();

    char mapName[128], path[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));
    Format(path, sizeof(path), "maps/%s.bsp", mapName);

    File bspFile = OpenFile(path, "rb");
    if (bspFile == null)
    {
        LogError("Could not open %s", path);
        return;
    }

    int magic;
    bspFile.ReadInt32(magic);
    if (magic != 0x50534256) // VBSP
    {
        LogError("Invalid BSP signature");
        delete bspFile;
        return;
    }

    int version;
    bspFile.ReadInt32(version);

    // Lump 0 is Entities
    int fileofs, filelen;
    bspFile.Seek(8, SEEK_SET);
    bspFile.ReadInt32(fileofs);
    bspFile.ReadInt32(filelen);

    bspFile.Seek(fileofs, SEEK_SET);
    
    // Very basic parsing for demo: reading chunk by chunk and looking for func_button
    // To do this robustly, we'd read the whole block.
    // In SourcePawn, max string size is a concern, so we read line by line.
    
    char line[512];
    bool inButton = false;
    char buttonName[128];
    char doorName[128];
    
    // Note: SourcePawn ReadLine reads until newline. BSP entities lump has newlines.
    while (!bspFile.EndOfFile())
    {
        if (!bspFile.ReadLine(line, sizeof(line)))
        {
            break;
        }
        
        if (StrContains(line, "\"classname\" \"func_button\"") != -1)
        {
            inButton = true;
            buttonName[0] = '\0';
        }
        else if (inButton && StrContains(line, "\"targetname\"") != -1)
        {
            ParseKeyValue(line, buttonName, sizeof(buttonName));
        }
        else if (inButton && (StrContains(line, "\"OnPressed\"") != -1 || StrContains(line, "\"OnIn\"") != -1))
        {
            // Example: "OnPressed" "door_name,Open,,0,-1"
            ParseOutputTarget(line, doorName, sizeof(doorName));
            
            if (buttonName[0] != '\0' && doorName[0] != '\0')
            {
                // Store mapping: DoorName -> Button TargetName
                // We will resolve this to an Entity Reference after entities are spawned
                g_DoorToButtonMap.SetString(doorName, buttonName);
            }
        }
        else if (inButton && StrContains(line, "}") != -1)
        {
            inButton = false;
        }
    }
    
    delete bspFile;
    
    // We actually need to map the string targetnames to Entity References so OnDoorTouch is fast.
    CreateTimer(1.0, Timer_ResolveEntities);
}

public Action Timer_ResolveEntities(Handle timer)
{
    // Resolve String -> String map into String -> EntRef map
    StringMapSnapshot keys = g_DoorToButtonMap.Snapshot();
    
    for (int i = 0; i < keys.Length; i++)
    {
        char doorName[128];
        keys.GetKey(i, doorName, sizeof(doorName));
        
        char buttonName[128];
        g_DoorToButtonMap.GetString(doorName, buttonName, sizeof(buttonName));
        
        int buttonEnt = -1;
        while ((buttonEnt = FindEntityByClassname(buttonEnt, "func_button")) != -1)
        {
            char currentName[128];
            GetEntPropString(buttonEnt, Prop_Data, "m_iName", currentName, sizeof(currentName));
            if (StrEqual(currentName, buttonName))
            {
                g_DoorToButtonMap.SetValue(doorName, EntIndexToEntRef(buttonEnt));
                break;
            }
        }
    }
    
    delete keys;
    return Plugin_Stop;
}

void ParseKeyValue(const char[] line, char[] value, int maxlen)
{
    // Quick parser for "key" "value"
    int firstQuote = StrContains(line, "\"");
    if (firstQuote == -1) return;
    int secondQuote = StrContains(line[firstQuote+1], "\"") + firstQuote + 1;
    int thirdQuote = StrContains(line[secondQuote+1], "\"") + secondQuote + 1;
    int fourthQuote = StrContains(line[thirdQuote+1], "\"") + thirdQuote + 1;
    
    if (fourthQuote > thirdQuote)
    {
        strcopy(value, maxlen, line[thirdQuote+1]);
        value[fourthQuote - thirdQuote - 1] = '\0';
    }
}

void ParseOutputTarget(const char[] line, char[] target, int maxlen)
{
    // "OnPressed" "target,input,param,delay,limit"
    char value[256];
    ParseKeyValue(line, value, sizeof(value)); // Just extracts the value part
    
    int comma = StrContains(value, ",");
    if (comma != -1)
    {
        strcopy(target, maxlen, value);
        target[comma] = '\0';
    }
    else
    {
        strcopy(target, maxlen, value);
    }
}
