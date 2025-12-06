#include "ws_server.h"
#include "ws_client.h"

WebSocketServer::WebSocketServer(const std::string& host, int port, int addressFamily, int pingInterval) : m_webSocketServer(
	port,
	host,
	ix::SocketServer::kDefaultTcpBacklog,
	ix::SocketServer::kDefaultMaxConnections,
	ix::WebSocketServer::kDefaultHandShakeTimeoutSecs,
	addressFamily,
	pingInterval)
{
	m_webSocketServer.setOnClientMessageCallback([this](std::shared_ptr<ix::ConnectionState> connectionState, ix::WebSocket& webSocket, const ix::WebSocketMessagePtr& msg) {
		switch (msg->type)
		{
			case ix::WebSocketMessageType::Open:
			{
				OnOpen(msg->openInfo, connectionState);
				break;
			}
			case ix::WebSocketMessageType::Message:
			{
				OnMessage(msg->str, connectionState, &webSocket);
				break;
			}
			case ix::WebSocketMessageType::Close:
			{
				OnClose(msg->closeInfo, connectionState);
				break;
			}
			case ix::WebSocketMessageType::Error:
			{
				OnError(msg->errorInfo, connectionState);
				break;
			}
		}
	});
}

WebSocketServer::~WebSocketServer()
{
	m_webSocketServer.stop();

	// Drain the queue for tasks belonging to this server
	ITaskContext* context = nullptr;
	std::vector<ITaskContext*> other_tasks;

	while (g_TaskQueue.TryPop(context)) {
		if (context && context->GetOwner() == this) {
			context->OnCompleted();
			delete context;
		} else if (context) {
			other_tasks.push_back(context);
		}
	}

	for (auto task : other_tasks) {
		g_TaskQueue.Push(task);
	}

	if (pMessageForward) forwards->ReleaseForward(pMessageForward);
	if (pOpenForward) forwards->ReleaseForward(pOpenForward);
	if (pCloseForward) forwards->ReleaseForward(pCloseForward);
	if (pErrorForward) forwards->ReleaseForward(pErrorForward);
}

void WebSocketServer::OnMessage(const std::string& message, std::shared_ptr<ix::ConnectionState> connectionState, ix::WebSocket* client)
{
	if (!pMessageForward || !pMessageForward->GetFunctionCount())
	{
		return;
	}

	WsServerMessageTaskContext *context = new WsServerMessageTaskContext(this, message, connectionState, client);
	g_TaskQueue.Push(context);
}

void WebSocketServer::OnOpen(ix::WebSocketOpenInfo openInfo, std::shared_ptr<ix::ConnectionState> connectionState)
{
	if (!pOpenForward || !pOpenForward->GetFunctionCount())
	{
		return;
	}

	WsServerOpenTaskContext *context = new WsServerOpenTaskContext(this, openInfo, connectionState);
	g_TaskQueue.Push(context);
}

void WebSocketServer::OnClose(ix::WebSocketCloseInfo closeInfo, std::shared_ptr<ix::ConnectionState> connectionState)
{
	if (!pCloseForward || !pCloseForward->GetFunctionCount())
	{
		return;
	}

	WsServerCloseTaskContext *context = new WsServerCloseTaskContext(this, closeInfo, connectionState);
	g_TaskQueue.Push(context);
}

void WebSocketServer::OnError(ix::WebSocketErrorInfo errorInfo, std::shared_ptr<ix::ConnectionState> connectionState)
{
	if (!pErrorForward || !pErrorForward->GetFunctionCount())
	{
		return;
	}

	WsServerErrorTaskContext *context = new WsServerErrorTaskContext(this, errorInfo, connectionState);
	g_TaskQueue.Push(context);
}

void WebSocketServer::broadcastMessage(const std::string& message) {
	auto clients = m_webSocketServer.getClients();

	for (const auto& client : clients)
	{
		client.first->send(message);
	}
}

bool WebSocketServer::sendToClient(const std::string& clientId, const std::string& message) {
	auto client = GetClientById(clientId);
	if (!client) return false;

	client->send(message);

	return true;
}

bool WebSocketServer::disconnectClient(const std::string& clientId) {
	auto client = GetClientById(clientId);
	if (!client) return false;

	client->stop();

	return true;
}

std::vector<std::string> WebSocketServer::getClientIds() {
	std::vector<std::string> clientIds;

	auto clients = m_webSocketServer.getClients();

	for (const auto& client : clients) {
		clientIds.push_back(client.second);
	}

	return clientIds;
}

bool WebSocketServer::getClientHeaders(const std::string& clientId, ix::WebSocketHttpHeaders& outHeaders)
{
	auto client = GetClientById(clientId);
	if (!client)
		return false;

	std::lock_guard<std::mutex> lock(m_headersMutex);
	auto it = m_connectionHeaders.find(clientId);
	if (it != m_connectionHeaders.end())
	{
		outHeaders = it->second;
		return true;
	}

	return false;
}

void WsServerMessageTaskContext::OnCompleted()
{
	HandleError err;
	HandleSecurity sec(nullptr, myself->GetIdentity());

	WebSocketClient* pWebSocketClient = new WebSocketClient(m_client);

	pWebSocketClient->m_websocket_handle = handlesys->CreateHandleEx(g_htWsClient, pWebSocketClient, &sec, nullptr, &err);
	if (!pWebSocketClient->m_websocket_handle) return;
	pWebSocketClient->m_keepConnecting = true;

	{
		std::lock_guard<std::mutex> lock(m_server->m_headersMutex);
		auto it = m_server->m_connectionHeaders.find(m_connectionState->getId());
		if (it != m_server->m_connectionHeaders.end()) {
			pWebSocketClient->m_headers = it->second;
		}
	}

	std::string remoteAddress = WebSocketServer::GetRemoteAddress(m_connectionState);
	m_server->pMessageForward->PushCell(m_server->m_webSocketServer_handle);
	m_server->pMessageForward->PushCell(pWebSocketClient->m_websocket_handle);
	m_server->pMessageForward->PushString(m_message.c_str());
	m_server->pMessageForward->PushCell(m_message.length() + 1);
	m_server->pMessageForward->PushString(remoteAddress.c_str());
	m_server->pMessageForward->PushString(m_connectionState->getId().c_str());
	m_server->pMessageForward->Execute(nullptr);

	handlesys->FreeHandle(pWebSocketClient->m_websocket_handle, nullptr);
}

void WsServerOpenTaskContext::OnCompleted()
{
	{
		std::lock_guard<std::mutex> lock(m_server->m_headersMutex);
		m_server->m_connectionHeaders[m_connectionState->getId()] = m_openInfo.headers;
	}

	std::string remoteAddress = WebSocketServer::GetRemoteAddress(m_connectionState);
	m_server->pOpenForward->PushCell(m_server->m_webSocketServer_handle);
	m_server->pOpenForward->PushString(remoteAddress.c_str());
	m_server->pOpenForward->PushString(m_connectionState->getId().c_str());
	m_server->pOpenForward->Execute(nullptr);
}

void WsServerCloseTaskContext::OnCompleted()
{
	{
		std::lock_guard<std::mutex> lock(m_server->m_headersMutex);
		m_server->m_connectionHeaders.erase(m_connectionState->getId());
	}

	std::string remoteAddress = WebSocketServer::GetRemoteAddress(m_connectionState);
	m_server->pCloseForward->PushCell(m_server->m_webSocketServer_handle);
	m_server->pCloseForward->PushCell(m_closeInfo.code);
	m_server->pCloseForward->PushString(m_closeInfo.reason.c_str());
	m_server->pCloseForward->PushString(remoteAddress.c_str());
	m_server->pCloseForward->PushString(m_connectionState->getId().c_str());
	m_server->pCloseForward->Execute(nullptr);
}

void WsServerErrorTaskContext::OnCompleted()
{
	{
		std::lock_guard<std::mutex> lock(m_server->m_headersMutex);
		auto it = m_server->m_connectionHeaders.find(m_connectionState->getId());
		if (it != m_server->m_connectionHeaders.end()) {
			m_server->m_connectionHeaders.erase(it);
		}
	}

	std::string remoteAddress = WebSocketServer::GetRemoteAddress(m_connectionState);
	m_server->pErrorForward->PushCell(m_server->m_webSocketServer_handle);
	m_server->pErrorForward->PushString(m_errorInfo.reason.c_str());
	m_server->pErrorForward->PushString(remoteAddress.c_str());
	m_server->pErrorForward->PushString(m_connectionState->getId().c_str());
	m_server->pErrorForward->Execute(nullptr);
}