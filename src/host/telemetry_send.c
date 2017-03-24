/**
 * \file   telemetry_send.c
 * \brief  Send some telemetry to a http server.
 * \author Copyright (c) 2002-2008 Jason Perkins and the Premake project
 */
#ifdef PREMAKE_CURL

#include "premake.h"
#include "curl_utils.h"
#include <stdlib.h>

#if defined(_WIN32)
#   include <process.h>
typedef HANDLE ThreadID;
#else
#   include <pthread.h>
typedef pthread_t ThreadID;
#endif

typedef struct
{
	curl_state state;
	CURL*      curl;
	CURLcode   code;
	long       responseCode;
	ThreadID   threadHandle;
} Telemetry;


#if defined(_WIN32)
static DWORD __stdcall _threadFunc(void* context)
#else
static void* _threadFunc(void* context)
#endif
{
	Telemetry* T = (Telemetry*)context;
	CURL* curl = T->curl;

	curl_easy_setopt(curl, CURLOPT_POST, 1);
	T->code = curl_easy_perform(curl);
	curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &T->responseCode);
	curlCleanup(curl, &T->state);

	return 0;
}


int telemetry_send(lua_State* L)
{
	Telemetry* t = (Telemetry*)malloc(sizeof(Telemetry));

	// telemetry.send(url, { headers })
	t->curl = curlRequest(L, &t->state, 0, 0, 2);
	t->code = CURLE_FAILED_INIT;
	t->responseCode = 0;

#if defined(_WIN32)
	t->threadHandle = CreateThread(NULL, 0, _threadFunc, t, 0, NULL);
	if (t->threadHandle == NULL)
	{
		buffer_destroy(&t->state.S);
		free(t);
		return 0;
	}

#else
	if (pthread_create(&t->threadHandle, NULL, _threadFunc, t) != 0)
	{
		buffer_destroy(&t->state.S);
		free(t);
		return 0;
	}
#endif

	lua_pushlightuserdata(L, t);
	return 1;
}


int telemetry_wait(lua_State* L)
{
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	Telemetry* t = (Telemetry*)lua_touserdata(L, 1);
	if (t != NULL)
	{
#if defined(_WIN32)
		WaitForSingleObject(t->threadHandle, INFINITE);
		CloseHandle(t->threadHandle);
#else
		pthread_join(t->threadHandle, NULL);
		pthread_detach(t->threadHandle);
#endif

		if (t->code != CURLE_OK)
		{
			char errorBuf[1024];

			lua_pushnil(L);
			snprintf(errorBuf, sizeof(errorBuf) - 1, "%s\n%s\n", curl_easy_strerror(t->code), t->state.errorBuffer);
			lua_pushstring(L, errorBuf);
		}
		else
		{
			lua_pushlstring(L, t->state.S.data, t->state.S.length);
			lua_pushstring(L, "OK");
		}

		buffer_destroy(&t->state.S);
		lua_pushnumber(L, t->responseCode);
		free(t);
		return 3;
	}

	return 0;
}

#endif // PREMAKE_CURL
