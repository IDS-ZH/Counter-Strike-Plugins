#include "ws_server.h"

static WebSocketServer *GetWsServerPointer(IPluginContext *pContext, Handle_t Handle)
{
	HandleError err;
	HandleSecurity sec(pContext->GetIdentity(), myself->GetIdentity());

	WebSocketServer *server;
	if ((err = handlesys->ReadHandle(Handle, g_htWsServer, &sec, (void **)&server)) != HandleError_None)
	{
		pContext->ReportError("Invalid WebSocketServer handle %x (error %d)", Handle, err);
		return nullptr;
	}

	return server;
}

static cell_t ws_CreateWebSocketServer(IPluginContext *pContext, const cell_t *params)
{
	char *url;
	pContext->LocalToString(params[1], &url);

	WebSocketServer* pWebsocketServer = new WebSocketServer(url, params[2], params[3] ? AF_INET6 : AF_INET, params[4]);

	HandleError err;
	HandleSecurity sec(pContext->GetIdentity(), myself->GetIdentity());
	pWebsocketServer->m_webSocketServer_handle = handlesys->CreateHandleEx(g_htWsServer, pWebsocketServer, &sec, nullptr, &err);

	if (!pWebsocketServer->m_webSocketServer_handle)
	{
		pContext->ReportError("Could not create WebSocketServer handle (error %d)", err);
		return 0;
	}

	return pWebsocketServer->m_webSocketServer_handle;
}

static cell_t ws_SetMessageCallback(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer *pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pWebsocketServer->pMessageForward) {
		forwards->ReleaseForward(pWebsocketServer->pMessageForward);
	}

	pWebsocketServer->pMessageForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 6, nullptr, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String, Param_String);
	if (!pWebsocketServer->pMessageForward || !pWebsocketServer->pMessageForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create message forward.");
		return 0;
	}

	return 1;
}

static cell_t ws_SetOpenCallback(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer *pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pWebsocketServer->pOpenForward) {
		forwards->ReleaseForward(pWebsocketServer->pOpenForward);
	}

	pWebsocketServer->pOpenForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 3, nullptr, Param_Cell, Param_String, Param_String);
	if (!pWebsocketServer->pOpenForward || !pWebsocketServer->pOpenForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create open forward.");
		return 0;
	}

	return 1;
}

static cell_t ws_SetCloseCallback(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer *pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pWebsocketServer->pCloseForward) {
		forwards->ReleaseForward(pWebsocketServer->pCloseForward);
	}

	pWebsocketServer->pCloseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr, Param_Cell, Param_Cell, Param_String, Param_String, Param_String);
	if (!pWebsocketServer->pCloseForward || !pWebsocketServer->pCloseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create close forward.");
		return 0;
	}

	return 1;
}

static cell_t ws_SetErrorCallback(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer *pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pWebsocketServer->pErrorForward) {
		forwards->ReleaseForward(pWebsocketServer->pErrorForward);
	}

	pWebsocketServer->pErrorForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 4, nullptr, Param_Cell, Param_String, Param_String, Param_String);
	if (!pWebsocketServer->pErrorForward || !pWebsocketServer->pErrorForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create error forward.");
		return 0;
	}

	return 1;
}

static cell_t ws_Start(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	auto res = pWebsocketServer->m_webSocketServer.listen();

	if (!res.first)
	{
		pContext->ReportError("Initiating WebSocket Server failed: %s", res.second.c_str());
		return 0;
	}

	pWebsocketServer->m_webSocketServer.start();

	return 1;
}

static cell_t ws_Stop(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	pWebsocketServer->m_webSocketServer.stop();

	return 1;
}

static cell_t ws_SendMessageToClient(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	char *clientId, *msg;
	pContext->LocalToString(params[2], &clientId);
	pContext->LocalToString(params[3], &msg);

	return pWebsocketServer->sendToClient(clientId, msg);
}

static cell_t ws_DisconnectClient(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	char *clientId;
	pContext->LocalToString(params[2], &clientId);

	return pWebsocketServer->disconnectClient(clientId);
}

static cell_t ws_BroadcastMessage(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	char *msg;
	pContext->LocalToString(params[2], &msg);

	pWebsocketServer->broadcastMessage(msg);

	return 1;
}

static cell_t ws_GetClientsCount(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	return pWebsocketServer->m_webSocketServer.getClients().size();
}

static cell_t ws_SetOrGetPongEnable(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	if (params[0] == 2) {
		params[2] ? pWebsocketServer->m_webSocketServer.enablePong() : pWebsocketServer->m_webSocketServer.disablePong();
		return 1;
	}

	return pWebsocketServer->m_webSocketServer.isPongEnabled();
}

static cell_t ws_DisableDeflate(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	if (!pWebsocketServer->m_webSocketServer.isPerMessageDeflateEnabled())
	{
		pContext->ReportError("Per Message Deflate not enabled!");
		return 0;
	}

	pWebsocketServer->m_webSocketServer.disablePerMessageDeflate();
	return 1;
}

static cell_t ws_IsDeflateEnabled(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	return pWebsocketServer->m_webSocketServer.isPerMessageDeflateEnabled();
}

static cell_t ws_GetHeader(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer* pWebsocketServer = GetWsServerPointer(pContext, params[1]);

	if (!pWebsocketServer) return 0;

	char *clientId, *headerKey;
	pContext->LocalToString(params[2], &clientId);
	pContext->LocalToString(params[3], &headerKey);

	ix::WebSocketHttpHeaders headers;
	if (!pWebsocketServer->getClientHeaders(clientId, headers))
	{
		return 0;
	}

	auto it = headers.find(headerKey);
	if (it == headers.end())
	{
		return 0;
	}

	pContext->StringToLocal(params[4], params[5], it->second.c_str());

	return 1;
}

static cell_t ws_GetClientIdByIndex(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer *pWebsocketServer = GetWsServerPointer(pContext, params[1]);
	if (!pWebsocketServer) return 0;

	cell_t index = params[2];
	const auto& ids = pWebsocketServer->getClientIds();

	if (index < 0 || static_cast<size_t>(index) >= ids.size())
	{
		return 0;
	}

	pContext->StringToLocal(params[3], params[4], ids[index].c_str());

	return 1;
}

static cell_t ws_GetMaxClientIdLength(IPluginContext *pContext, const cell_t *params)
{
	WebSocketServer *pWebsocketServer = GetWsServerPointer(pContext, params[1]);
	if (!pWebsocketServer)
	{
		return 0;
	}

	const auto& ids = pWebsocketServer->getClientIds();
	size_t maxLen = 0;

	for (const auto& id : ids)
	{
		if (id.length() > maxLen)
			maxLen = id.length();
	}

	return static_cast<cell_t>(maxLen + 1);
}

const sp_nativeinfo_t ws_natives_server[] =
{
	{"WebSocketServer.WebSocketServer",        ws_CreateWebSocketServer},
	{"WebSocketServer.SetMessageCallback",     ws_SetMessageCallback},
	{"WebSocketServer.SetOpenCallback",        ws_SetOpenCallback},
	{"WebSocketServer.SetCloseCallback",       ws_SetCloseCallback},
	{"WebSocketServer.SetErrorCallback",       ws_SetErrorCallback},
	{"WebSocketServer.Start",                  ws_Start},
	{"WebSocketServer.Stop",                   ws_Stop},
	{"WebSocketServer.BroadcastMessage",       ws_BroadcastMessage},
	{"WebSocketServer.SendMessageToClient",    ws_SendMessageToClient},
	{"WebSocketServer.DisconnectClient",       ws_DisconnectClient},
	{"WebSocketServer.GetHeader",              ws_GetHeader},
	{"WebSocketServer.ClientsCount.get",       ws_GetClientsCount},
	{"WebSocketServer.EnablePong.get",         ws_SetOrGetPongEnable},
	{"WebSocketServer.EnablePong.set",         ws_SetOrGetPongEnable},
	{"WebSocketServer.GetClientIdByIndex",     ws_GetClientIdByIndex},
	{"WebSocketServer.MaxClientIdLength.get",  ws_GetMaxClientIdLength},
	{"WebSocketServer.DisableDeflate",         ws_DisableDeflate},
	{"WebSocketServer.IsDeflateEnabled",       ws_IsDeflateEnabled},
	{nullptr, nullptr}
};