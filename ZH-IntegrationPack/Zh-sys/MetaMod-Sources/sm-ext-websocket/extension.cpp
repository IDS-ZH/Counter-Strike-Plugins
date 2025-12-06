#include "extension.h"
#include <ws_client.h>
#include <ws_server.h>
#include <http_request.h>

#define MAX_PROCESS 10

WebsocketExtension g_WebsocketExt;
SMEXT_LINK(&g_WebsocketExt);

HandleType_t g_htWsClient, g_htWsServer, g_htHttp;
WsClientHandler g_WsClientHandler;
WsServerHandler g_WsServerHandler;
HttpHandler g_HttpHandler;

ThreadSafeQueue<ITaskContext *> g_TaskQueue;
IJsonManager* g_pJsonManager = nullptr;

static void OnGameFrame(bool simulating) {
	int count = 0;
	ITaskContext *context = nullptr;

	while (count < MAX_PROCESS) {
		if (!g_TaskQueue.TryPop(context)) {
			break;
		}

		if (context) {
			context->OnCompleted();
			delete context;
			count++;
		}
	}
}

bool WebsocketExtension::SDK_OnLoad(char* error, size_t maxlen, bool late)
{
	sharesys->AddDependency(myself, "json.ext", false, true);

	sharesys->AddNatives(myself, ws_natives);
	sharesys->AddNatives(myself, ws_natives_server);
	sharesys->AddNatives(myself, http_natives);
	sharesys->RegisterLibrary(myself, "websocket");

	HandleAccess haDefaults;
	handlesys->InitAccessDefaults(nullptr, &haDefaults);
	haDefaults.access[HandleAccess_Delete] = 0;
	g_htWsClient = handlesys->CreateType("WebSocket", &g_WsClientHandler, 0, nullptr, &haDefaults, myself->GetIdentity(), nullptr);
	g_htWsServer = handlesys->CreateType("WebSocketServer", &g_WsServerHandler, 0, nullptr, &haDefaults, myself->GetIdentity(), nullptr);
	g_htHttp = handlesys->CreateType("HttpRequest", &g_HttpHandler, 0, nullptr, &haDefaults, myself->GetIdentity(), nullptr);

	smutils->AddGameFrameHook(&OnGameFrame);
	return true;
}

void WebsocketExtension::SDK_OnDependenciesDropped()
{
	g_pJsonManager = nullptr;
}

IJsonManager* WebsocketExtension::GetJsonManager()
{
	if (!g_pJsonManager)
	{
		SM_GET_LATE_IFACE(JSONMANAGER, g_pJsonManager);
	}
	return g_pJsonManager;
}

void WebsocketExtension::SDK_OnUnload()
{
	handlesys->RemoveType(g_htWsClient, myself->GetIdentity());
	handlesys->RemoveType(g_htWsServer, myself->GetIdentity());
	handlesys->RemoveType(g_htHttp, myself->GetIdentity());

	smutils->RemoveGameFrameHook(&OnGameFrame);
}

void WsClientHandler::OnHandleDestroy(HandleType_t type, void *object)
{
	delete (WebSocketClient *)object;
}

void WsServerHandler::OnHandleDestroy(HandleType_t type, void *object)
{
	delete (WebSocketServer *)object;
}

void HttpHandler::OnHandleDestroy(HandleType_t type, void *object)
{
	delete (HttpRequest *)object;
}