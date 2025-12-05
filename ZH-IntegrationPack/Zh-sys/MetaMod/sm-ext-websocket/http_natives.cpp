#include "http_request.h"

static HttpRequest *GetHttpPointer(IPluginContext *pContext, Handle_t Handle)
{
	HandleError err;
	HandleSecurity sec(pContext->GetIdentity(), myself->GetIdentity());

	HttpRequest *httpClient;
	if ((err = handlesys->ReadHandle(Handle, g_htHttp, &sec, (void **)&httpClient)) != HandleError_None)
	{
		pContext->ReportError("Invalid httpClient handle %x (error %d)", Handle, err);
		return nullptr;
	}

	return httpClient;
}

static cell_t http_CreateRequest(IPluginContext *pContext, const cell_t *params)
{
	char *url;
	pContext->LocalToString(params[1], &url);

	HttpRequest* pHttpRequest = new HttpRequest(url);

	HandleError err;
	HandleSecurity sec(pContext->GetIdentity(), myself->GetIdentity());
	pHttpRequest->m_httpclient_handle = handlesys->CreateHandleEx(g_htHttp, pHttpRequest, &sec, nullptr, &err);

	if (pHttpRequest->m_httpclient_handle == BAD_HANDLE)
	{
		pContext->ReportError("Could not create HttpRequest handle (error %d)", err);
		return BAD_HANDLE;
	}

	return pHttpRequest->m_httpclient_handle;
}

static cell_t http_Get(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pHttpRequest->pResponseForward) {
		forwards->ReleaseForward(pHttpRequest->pResponseForward);
	}

	pHttpRequest->pResponseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	if (!pHttpRequest->pResponseForward || !pHttpRequest->pResponseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create response forward.");
		return 0;
	}

	cell_t value = params[3];
	return pHttpRequest->Get(callback, value);
}

static cell_t http_PostJson(IPluginContext *pContext, const cell_t *params)
{
	IJsonManager* pJsonManager = g_WebsocketExt.GetJsonManager();
	if (!pJsonManager)
	{
		return pContext->ThrowNativeError("JSON extension not loaded");
	}

	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	JsonValue *pJsonValue = pJsonManager->GetValueFromHandle(pContext, params[2]);

	if (!pHttpRequest || !pJsonValue) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[3]);

	if (pHttpRequest->pResponseForward) {
		forwards->ReleaseForward(pHttpRequest->pResponseForward);
	}

	pHttpRequest->pResponseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr,
		Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	if (!pHttpRequest->pResponseForward || !pHttpRequest->pResponseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create response forward.");
		return 0;
	}

	cell_t value = params[4];
	return pHttpRequest->PostJson(pJsonValue, callback, value);
}

static cell_t http_AppendFormParam(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	char *key, *value;
	pContext->LocalToString(params[2], &key);
	pContext->LocalToString(params[3], &value);

	pHttpRequest->AppendFormParam(key, value);
	return 1;
}

static cell_t http_PostForm(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pHttpRequest->pResponseForward) {
		forwards->ReleaseForward(pHttpRequest->pResponseForward);
	}

	pHttpRequest->pResponseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr,
		Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	if (!pHttpRequest->pResponseForward || !pHttpRequest->pResponseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create response forward.");
		return 0;
	}

	cell_t value = params[3];
	return pHttpRequest->PostForm(callback, value);
}

static cell_t http_PutJson(IPluginContext *pContext, const cell_t *params)
{
	IJsonManager* pJsonManager = g_WebsocketExt.GetJsonManager();
	if (!pJsonManager)
	{
		return pContext->ThrowNativeError("JSON extension not loaded");
	}

	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	JsonValue *pJsonValue = pJsonManager->GetValueFromHandle(pContext, params[2]);

	if (!pHttpRequest || !pJsonValue) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[3]);

	if (pHttpRequest->pResponseForward) {
		forwards->ReleaseForward(pHttpRequest->pResponseForward);
	}

	pHttpRequest->pResponseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr,
		Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	if (!pHttpRequest->pResponseForward || !pHttpRequest->pResponseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create response forward.");
		return 0;
	}

	cell_t value = params[4];
	return pHttpRequest->PutJson(pJsonValue, callback, value);
}

static cell_t http_PatchJson(IPluginContext *pContext, const cell_t *params)
{
	IJsonManager* pJsonManager = g_WebsocketExt.GetJsonManager();
	if (!pJsonManager)
	{
		return pContext->ThrowNativeError("JSON extension not loaded");
	}

	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	JsonValue *pJsonValue = pJsonManager->GetValueFromHandle(pContext, params[2]);

	if (!pHttpRequest || !pJsonValue) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[3]);

	if (pHttpRequest->pResponseForward) {
		forwards->ReleaseForward(pHttpRequest->pResponseForward);
	}

	pHttpRequest->pResponseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr,
		Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	if (!pHttpRequest->pResponseForward || !pHttpRequest->pResponseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create response forward.");
		return 0;
	}

	cell_t value = params[4];
	return pHttpRequest->PatchJson(pJsonValue, callback, value);
}

static cell_t http_Delete(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	IPluginFunction *callback = pContext->GetFunctionById(params[2]);

	if (pHttpRequest->pResponseForward) {
		forwards->ReleaseForward(pHttpRequest->pResponseForward);
	}

	pHttpRequest->pResponseForward = forwards->CreateForwardEx(nullptr, ET_Ignore, 5, nullptr, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	if (!pHttpRequest->pResponseForward || !pHttpRequest->pResponseForward->AddFunction(callback))
	{
		pContext->ReportError("Could not create response forward.");
		return 0;
	}

	cell_t value = params[3];
	return pHttpRequest->Delete(callback, value);
}

static cell_t http_SetBody(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	char *body;
	pContext->LocalToString(params[2], &body);
	pHttpRequest->SetBody(body);
	return 1;
}

static cell_t http_SetJsonBody(IPluginContext *pContext, const cell_t *params)
{
	IJsonManager* pJsonManager = g_WebsocketExt.GetJsonManager();
	if (!pJsonManager)
	{
		return pContext->ThrowNativeError("JSON extension not loaded");
	}

	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	JsonValue *pJsonValue = pJsonManager->GetValueFromHandle(pContext, params[2]);

	if (!pHttpRequest || !pJsonValue) return 0;

	pHttpRequest->SetJsonBody(pJsonValue);
	return 1;
}

static cell_t http_AddHeader(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	char *key, *value;
	pContext->LocalToString(params[2], &key);
	pContext->LocalToString(params[3], &value);

	pHttpRequest->AddHeader(key, value);
	return 1;
}

static cell_t http_GetResponseHeader(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	char *key;
	pContext->LocalToString(params[2], &key);

	const std::string& value = pHttpRequest->GetResponseHeader(key);
	pContext->StringToLocalUTF8(params[3], params[4], value.c_str(), nullptr);

	return !value.empty();
}

static cell_t http_HasResponseHeader(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	char *key;
	pContext->LocalToString(params[2], &key);

	return pHttpRequest->HasResponseHeader(key);
}

static cell_t http_GetTimeout(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	return pHttpRequest->GetTimeout();
}

static cell_t http_SetTimeout(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	pHttpRequest->SetTimeout(params[2]);
	return 1;
}

static cell_t http_GetFollowRedirect(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	return pHttpRequest->GetFollowRedirect();
}

static cell_t http_SetFollowRedirect(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	pHttpRequest->SetFollowRedirect(params[2]);
	return 1;
}

static cell_t http_GetCompression(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	return pHttpRequest->GetCompression();
}

static cell_t http_SetCompression(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	pHttpRequest->SetCompression(params[2]);

	return 1;
}

static cell_t http_GetMaxRedirects(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	return pHttpRequest->GetMaxRedirects();
}

static cell_t http_SetMaxRedirects(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	pHttpRequest->SetMaxRedirects(params[2]);

	return 1;
}

static cell_t http_GetVerbose(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	return pHttpRequest->GetVerbose();
}

static cell_t http_SetVerbose(IPluginContext *pContext, const cell_t *params)
{
	HttpRequest *pHttpRequest = GetHttpPointer(pContext, params[1]);
	if (!pHttpRequest) return 0;

	pHttpRequest->SetVerbose(params[2]);

	return 1;
}

const sp_nativeinfo_t http_natives[] =
{
	{"HttpRequest.HttpRequest", http_CreateRequest},
	{"HttpRequest.Get", http_Get},
	{"HttpRequest.PostJson", http_PostJson},
	{"HttpRequest.PostForm", http_PostForm},
	{"HttpRequest.PutJson", http_PutJson},
	{"HttpRequest.PatchJson", http_PatchJson},
	{"HttpRequest.Delete", http_Delete},
	{"HttpRequest.AppendFormParam", http_AppendFormParam},
	{"HttpRequest.SetBody", http_SetBody},
	{"HttpRequest.SetJsonBody", http_SetJsonBody},
	{"HttpRequest.AddHeader", http_AddHeader},
	{"HttpRequest.GetResponseHeader", http_GetResponseHeader},
	{"HttpRequest.HasResponseHeader", http_HasResponseHeader},
	{"HttpRequest.Timeout.get", http_GetTimeout},
	{"HttpRequest.Timeout.set", http_SetTimeout},
	{"HttpRequest.FollowRedirect.get", http_GetFollowRedirect},
	{"HttpRequest.FollowRedirect.set", http_SetFollowRedirect},
	{"HttpRequest.Compression.get", http_GetCompression},
	{"HttpRequest.Compression.set", http_SetCompression},
	{"HttpRequest.MaxRedirects.get", http_GetMaxRedirects},
	{"HttpRequest.MaxRedirects.set", http_SetMaxRedirects},
	{"HttpRequest.Verbose.get", http_GetVerbose},
	{"HttpRequest.Verbose.set", http_SetVerbose},
	{nullptr, nullptr}
};