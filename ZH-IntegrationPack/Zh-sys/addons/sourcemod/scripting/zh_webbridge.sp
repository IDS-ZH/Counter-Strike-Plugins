#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <system2>
#include <zh_core>
#include <json>
// Optional: uncomment when sm-ext-websocket is built and websocket.inc is available.
//#include <websocket>

#define PLUGIN_VERSION "0.1.0-draft"

ConVar g_CvarMode;       // 0=REST only, 1=WebSocket
ConVar g_CvarEndpoint;   // REST endpoint base URL
ConVar g_CvarApiKey;     // Shared token
ConVar g_CvarWsUrl;      // WebSocket URL (if mode 1)
Handle g_HeartbeatTimer;

public Plugin myinfo =
{
    name = "ZH-sys WebBridge (draft)",
    author = "ZloyHohol integration workbench",
    description = "Placeholder bridge to web panel via REST/websocket.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    g_CvarMode = CreateConVar("zh_web_mode", "0", "0=REST (system2), 1=WebSocket (requires sm-ext-websocket).");
    g_CvarEndpoint = CreateConVar("zh_web_endpoint", "http://127.0.0.1/materialadmin/api", "Base URL for REST API.");
    g_CvarApiKey = CreateConVar("zh_web_apikey", "changeme", "API key/shared secret.");
    g_CvarWsUrl = CreateConVar("zh_web_wsurl", "ws://127.0.0.1:8080/ws", "WebSocket URL (if mode=1).");

    AutoExecConfig(true, "zh_webbridge", "sourcemod");

    ZH_RegisterModule("webbridge");

    g_HeartbeatTimer = CreateTimer(30.0, Timer_Heartbeat, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnPluginEnd()
{
    if (g_HeartbeatTimer != null)
    {
        CloseHandle(g_HeartbeatTimer);
    }
}

public Action Timer_Heartbeat(Handle timer)
{
    int mode = g_CvarMode.IntValue;
    if (mode == 0)
    {
        SendRestHeartbeat();
    }
#if defined _websocket_included
    else
    {
        SendWsHeartbeat();
    }
#endif
    return Plugin_Continue;
}

void SendRestHeartbeat()
{
    char url[256];
    g_CvarEndpoint.GetString(url, sizeof(url));
    if (url[0] == '\0')
    {
        return;
    }

    char full[512];
    Format(full, sizeof(full), "%s/heartbeat", url);

    System2HTTPRequest request = new System2HTTPRequest(OnRestCompleted, full);
    request.SetHeader("X-ZH-Key", GetApiKey());
    request.Timeout = 10;
    request.GET();
    delete request;
}

void OnRestCompleted(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    if (!success)
    {
        ZH_LogWarn("WebBridge REST failed: %s", error);
        return;
    }
    if (response.StatusCode != 200)
    {
        ZH_LogWarn("WebBridge REST status %d", response.StatusCode);
        return;
    }
    // TODO: parse response JSON when needed (system2 has no json parser; use simple commands).
}

#if defined _websocket_included
Handle g_Ws = null;

void SendWsHeartbeat()
{
    if (g_Ws == null)
    {
        ConnectWs();
    }
    if (g_Ws != null)
    {
        char msg[128];
        Format(msg, sizeof(msg), "{\"type\":\"heartbeat\",\"key\":\"%s\"}", GetApiKey());
        WebsocketSend(g_Ws, msg);
    }
}

void ConnectWs()
{
    char url[256];
    g_CvarWsUrl.GetString(url, sizeof(url));
    if (url[0] == '\0')
    {
        return;
    }
    g_Ws = WebsocketOpen(url, OnWsMessage, OnWsError, OnWsClose);
}

public void OnWsMessage(Handle ws, const char[] message, int size)
{
    // Parse and route commands from web panel
    ParseWebSocketMessage(message);
}

void ParseWebSocketMessage(const char[] message)
{
    // Parse the JSON message
    JSON_Object json = json_decode(message);
    if (json == null)
    {
        ZH_LogWarn("WebBridge: Failed to decode JSON message: %s", message);
        return;
    }

    char msgType[64];
    json_getstring(json, "type", msgType, sizeof(msgType));

    if (StrEqual(msgType, "command", false))
    {
        HandleCommandMessage(json);
    }
    else if (StrEqual(msgType, "cvar_set", false))
    {
        HandleCvarSetMessage(json);
    }
    else if (StrEqual(msgType, "config_reload", false))
    {
        HandleConfigReloadMessage(json);
    }
    else if (StrEqual(msgType, "server_command", false))
    {
        HandleServerCommandMessage(json);
    }
    else if (StrEqual(msgType, "broadcast", false))
    {
        HandleBroadcastMessage(json);
    }
    else
    {
        ZH_LogWarn("WebBridge: Unknown message type: %s", msgType);
    }

    json_cleanup(json);
}

void HandleCommandMessage(JSON_Object json)
{
    char command[256];
    json_getstring(json, "command", command, sizeof(command));

    // Validate and execute admin commands
    if (StrEqual(command, "map", false) ||
        StrEqual(command, "changelevel", false) ||
        StrEqual(command, "exec", false) ||
        StrEqual(command, "kick", false) ||
        StrEqual(command, "ban", false))
    {
        ZH_LogInfo("WebBridge: Executing command: %s", command);
        ServerCommand("%s", command);
    }
    else
    {
        ZH_LogWarn("WebBridge: Unauthorized command attempted: %s", command);
    }
}

void HandleCvarSetMessage(JSON_Object json)
{
    char cvarName[64];
    char cvarValue[256];

    json_getstring(json, "cvar", cvarName, sizeof(cvarName));
    json_getstring(json, "value", cvarValue, sizeof(cvarValue));

    // Validate cvar name to prevent unauthorized changes
    if (IsValidCvarForWebControl(cvarName))
    {
        ConVar convar = FindConVar(cvarName);
        if (convar != null)
        {
            // Check if it's a ZH-sys specific cvar or a server cvar
            if (StrContains(cvarName, "zh_", false) == 0)
            {
                // ZH-sys specific cvar - set directly
                convar.SetString(cvarValue);
                ZH_LogInfo("WebBridge: Set ZH-sys CVAR '%s' to '%s'", cvarName, cvarValue);
            }
            else
            {
                // Standard server cvar - validate further if needed
                convar.SetString(cvarValue);
                ZH_LogInfo("WebBridge: Set server CVAR '%s' to '%s'", cvarName, cvarValue);
            }

            // Fire a forward so other modules can react to CVAR changes
            Call_ZHCvarChangedForward(cvarName, cvarValue);
        }
        else
        {
            ZH_LogWarn("WebBridge: CVAR not found: %s", cvarName);
        }
    }
    else
    {
        ZH_LogWarn("WebBridge: Unauthorized CVAR change attempted: %s", cvarName);
    }
}

bool IsValidCvarForWebControl(const char[] cvarName)
{
    // ZH-sys specific CVARs
    if (StrContains(cvarName, "zh_", false) == 0)
    {
        return true;
    }

    // Read allowed CVARs from configuration file
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/ZH-sys/Tools/WebBridge/zh_web_cvar_config.cfg");

    if (FileExists(configPath))
    {
        KeyValues kv = new KeyValues("zh_web_cvar_config");
        if (kv.ImportFromFile(configPath))
        {
            // Navigate to the main section
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char allowedCvar[64];
                    kv.GetSectionName(allowedCvar, sizeof(allowedCvar));

                    if (StrEqual(cvarName, allowedCvar, false))
                    {
                        delete kv;
                        return true;
                    }
                }
                while (kv.GotoNextKey(false));
            }
        }
        delete kv;
    }

    return false;
}

void HandleConfigReloadMessage(JSON_Object json)
{
    char configType[64];
    json_getstring(json, "config", configType, sizeof(configType));

    if (StrEqual(configType, "zh_mst", false))
    {
        // Reload MST configuration
        ServerCommand("sm_mst_reload");
        ZH_LogInfo("WebBridge: Reloaded MST configuration");
    }
    else if (StrEqual(configType, "zh_modes", false))
    {
        // Reload modes configuration
        ServerCommand("exec sourcemod/sm_mode_dm.cfg"); // or appropriate config
        ZH_LogInfo("WebBridge: Reloaded modes configuration");
    }
    else
    {
        ZH_LogWarn("WebBridge: Unknown config type for reload: %s", configType);
    }
}

void HandleServerCommandMessage(JSON_Object json)
{
    char command[256];
    json_getstring(json, "cmd", command, sizeof(command));

    // Execute server command - restricted to safe commands
    if (IsValidServerCommand(command))
    {
        ServerCommand(command);
        ZH_LogInfo("WebBridge: Executed server command: %s", command);
    }
    else
    {
        ZH_LogWarn("WebBridge: Unauthorized server command attempted: %s", command);
    }
}

bool IsValidServerCommand(const char[] command)
{
    // List of allowed server commands
    char allowedCommands[][] = {
        "exec", "map", "changelevel", "sm_", "say", "say_team", "kickid", "addip", "removeip"
    };

    for (int i = 0; i < sizeof(allowedCommands); i++)
    {
        if (StrContains(command, allowedCommands[i], false) == 0)
        {
            return true;
        }
    }

    return false;
}

void HandleBroadcastMessage(JSON_Object json)
{
    char message[512];
    json_getstring(json, "msg", message, sizeof(message));

    // Broadcast message to all players
    PrintToChatAll("[ZH-Web] %s", message);
    PrintToServer("[ZH-Web] %s", message);
}

// Forward for other modules to react to CVAR changes from web panel
void Call_ZHCvarChangedForward(const char[] cvarName, const char[] cvarValue)
{
    static GlobalForward hCvarChangedForward = null;
    if (hCvarChangedForward == null)
    {
        hCvarChangedForward = CreateGlobalForward("ZH_WebCvarChanged", ET_Ignore, Param_String, Param_String);
    }

    Call_StartForward(hCvarChangedForward);
    Call_PushString(cvarName);
    Call_PushString(cvarValue);
    Call_Finish();
}

public void OnWsError(Handle ws, const char[] error)
{
    ZH_LogWarn("WebBridge WS error: %s", error);
    g_Ws = null;
}

public void OnWsClose(Handle ws, int code, const char[] reason)
{
    ZH_LogInfo("WebBridge WS closed: %d %s", code, reason);
    g_Ws = null;
}
#endif

char[] GetApiKey()
{
    static char key[128];
    g_CvarApiKey.GetString(key, sizeof(key));
    return key;
}
