/**
 * \file   os_touchfile.c
 * \brief markes a file as modified without changing its contents.
 * \author Blizzard Entertainment (contact tvandijck@blizzard.com)
 * \author Copyright (c) 2015 Jason Perkins and the Premake project
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "premake.h"

#if PLATFORM_WINDOWS
	#include <io.h>
#else
	#include <unistd.h>
	#include <sys/types.h>
#endif

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

static int truncate_file(const char* fn)
{
	FILE* file = fopen(fn, "rb");
	size_t size;
	file = fopen(fn, "ab");
	if (file == NULL)
	{
		return FALSE;
	}
	fseek(file, 0, SEEK_END);
	size = ftell(file);
	// append a dummy space. There are better ways to do
	// a touch, however this is a rather simple
	// multiplatform method
	if (fwrite(" ", 1, 1, file) != 1)
	{
		fclose(file);
		return FALSE;
	}
#if PLATFORM_WINDOWS
	if (_chsize(_fileno(file), (long)size) != 0)
	{
		fclose(file);
		return FALSE;
	}
#endif
	fclose(file);
#if !PLATFORM_WINDOWS
	if (truncate(fn, (off_t)size) != 0)
	{
		return FALSE;
	}
#endif
	return TRUE;
}

int os_touchfile(lua_State* L)
{
	FILE* file;
	const char* dst     = luaL_checkstring(L, 1);

	// if destination exist, mark the file as modified
	if (do_isfile(dst))
	{
		if (truncate_file(dst))
		{
			lua_pushinteger(L, 0);
			return 1;
		} else {
			lua_pushinteger(L, -1);
			lua_pushfstring(L, "unable to touch file '%s'", dst);
			return 2;
		}
	}

	file = fopen(dst, "wb");
	if (file != NULL)
	{
		fclose(file);

		lua_pushinteger(L, 1);
		return 1;
	}

	lua_pushinteger(L, -1);
	lua_pushfstring(L, "unable to create file to '%s'", dst);
	return 2;
}
