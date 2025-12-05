#ifndef _INCLUDE_SOURCEMOD_EXTENSION_PROPER_H_
#define _INCLUDE_SOURCEMOD_EXTENSION_PROPER_H_

#include "smsdk_ext.h"
#include <IJsonManager.h>
#include <IXWebSocket.h>
#include <IXWebSocketServer.h>
#include <IXHttpClient.h>
#include <queue.h>
#include <random>

class ITaskContext
{
public:
	virtual void OnCompleted() = 0;
	virtual void* GetOwner() { return nullptr; }  // Returns the owner object (e.g., WebSocketClient*)
	virtual ~ITaskContext() {}
};

class WebsocketExtension : public SDKExtension
{
public:
	virtual bool SDK_OnLoad(char *error, size_t maxlength, bool late);
	virtual void SDK_OnUnload();
	virtual void SDK_OnDependenciesDropped();
	IJsonManager* GetJsonManager();
};

class WsClientHandler : public IHandleTypeDispatch
{
public:
	void OnHandleDestroy(HandleType_t type, void *object);
};

class WsServerHandler : public IHandleTypeDispatch
{
public:
	void OnHandleDestroy(HandleType_t type, void *object);
};

class HttpHandler : public IHandleTypeDispatch
{
public:
	void OnHandleDestroy(HandleType_t type, void *object);
};

extern WebsocketExtension g_WebsocketExt;
extern HandleType_t g_htWsClient, g_htWsServer, g_htHttp;
extern WsClientHandler g_WsClientHandler;
extern WsServerHandler g_WsServerHandler;
extern HttpHandler g_HttpHandler;
extern ThreadSafeQueue<ITaskContext *> g_TaskQueue;
extern IJsonManager *g_pJsonManager;

extern const sp_nativeinfo_t ws_natives[];
extern const sp_nativeinfo_t ws_natives_server[];
extern const sp_nativeinfo_t http_natives[];

#endif // _INCLUDE_SOURCEMOD_EXTENSION_PROPER_H_
