#ifndef WEBSOCKETEXTENSION_WS_SERVER_H
#define WEBSOCKETEXTENSION_WS_SERVER_H

#include "extension.h"

class WebSocketServer
{
public:
	WebSocketServer(const std::string& host, int port, int addressFamily, int pingInterval);
	~WebSocketServer();

public:
	void OnMessage(const std::string &message, std::shared_ptr<ix::ConnectionState> connectionState, ix::WebSocket* client);
	void OnOpen(ix::WebSocketOpenInfo openInfo, std::shared_ptr<ix::ConnectionState> connectionState);
	void OnClose(ix::WebSocketCloseInfo closeInfo, std::shared_ptr<ix::ConnectionState> connectionState);
	void OnError(ix::WebSocketErrorInfo errorInfo, std::shared_ptr<ix::ConnectionState> connectionState);
	void broadcastMessage(const std::string& message);
	bool sendToClient(const std::string& clientId, const std::string& message);
	bool disconnectClient(const std::string& clientId);
	std::vector<std::string> getClientIds();
	bool getClientHeaders(const std::string& clientId, ix::WebSocketHttpHeaders& outHeaders);

	ix::WebSocketServer m_webSocketServer;
	Handle_t m_webSocketServer_handle = BAD_HANDLE;

	std::mutex m_headersMutex;
	std::unordered_map<std::string, ix::WebSocketHttpHeaders> m_connectionHeaders;

	IChangeableForward *pMessageForward = nullptr;
	IChangeableForward *pOpenForward = nullptr;
	IChangeableForward *pCloseForward = nullptr;
	IChangeableForward *pErrorForward = nullptr;

	std::shared_ptr<ix::WebSocket> GetClientById(const std::string& clientId)
	{
		for (const auto& [websocket, id] : m_webSocketServer.getClients())
		{
			if (id == clientId) return websocket;
		}

		return nullptr;
	}

	static std::string GetRemoteAddress(const std::shared_ptr<ix::ConnectionState>& connectionState) {
		return connectionState->getRemoteIp() + ":" + std::to_string(connectionState->getRemotePort());
	}
};

class WsServerMessageTaskContext : public ITaskContext
{
public:
	WsServerMessageTaskContext(WebSocketServer* server, const std::string& message,
		std::shared_ptr<ix::ConnectionState> connectionState, ix::WebSocket* client)
		: m_server(server), m_message(message), m_connectionState(connectionState), m_client(client) {}

	virtual void OnCompleted() override;
	virtual void* GetOwner() override { return m_server; }

private:
	WebSocketServer* m_server;
	std::string m_message;
	std::shared_ptr<ix::ConnectionState> m_connectionState;
	ix::WebSocket* m_client;
};

class WsServerOpenTaskContext : public ITaskContext
{
public:
	WsServerOpenTaskContext(WebSocketServer* server, ix::WebSocketOpenInfo openInfo,
		std::shared_ptr<ix::ConnectionState> connectionState)
		: m_server(server), m_openInfo(openInfo), m_connectionState(connectionState) {}

	virtual void OnCompleted() override;
	virtual void* GetOwner() override { return m_server; }

private:
	WebSocketServer* m_server;
	ix::WebSocketOpenInfo m_openInfo;
	std::shared_ptr<ix::ConnectionState> m_connectionState;
};

class WsServerCloseTaskContext : public ITaskContext
{
public:
	WsServerCloseTaskContext(WebSocketServer* server, ix::WebSocketCloseInfo closeInfo,
		std::shared_ptr<ix::ConnectionState> connectionState)
		: m_server(server), m_closeInfo(closeInfo), m_connectionState(connectionState) {}

	virtual void OnCompleted() override;
	virtual void* GetOwner() override { return m_server; }

private:
	WebSocketServer* m_server;
	ix::WebSocketCloseInfo m_closeInfo;
	std::shared_ptr<ix::ConnectionState> m_connectionState;
};

class WsServerErrorTaskContext : public ITaskContext
{
public:
	WsServerErrorTaskContext(WebSocketServer* server, ix::WebSocketErrorInfo errorInfo,
		std::shared_ptr<ix::ConnectionState> connectionState)
		: m_server(server), m_errorInfo(errorInfo), m_connectionState(connectionState) {}

	virtual void OnCompleted() override;
	virtual void* GetOwner() override { return m_server; }

private:
	WebSocketServer* m_server;
	ix::WebSocketErrorInfo m_errorInfo;
	std::shared_ptr<ix::ConnectionState> m_connectionState;
};
#endif // WEBSOCKETEXTENSION_WS_SERVER_H