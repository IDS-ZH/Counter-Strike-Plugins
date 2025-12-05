#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <system2>
#include <zh_core>
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
    // TODO: route commands from panel (e.g., run vote, send MOTD link, refresh configs).
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
