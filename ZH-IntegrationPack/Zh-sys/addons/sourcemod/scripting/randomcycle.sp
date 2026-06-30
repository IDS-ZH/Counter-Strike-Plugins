/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Random Map Cycle Plugin
 * Randomly picks a map from the mapcycle.
 *
 * SourceMod (C)2004-2021 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

public Plugin myinfo =
{
	name = "RandomCycle",
	author = "AlliedModders LLC",
	description = "Randomly chooses the next map.",
	version = SOURCEMOD_VERSION,
	url = "http://www.sourcemod.net/"
};

ConVar g_Cvar_ExcludeMaps;
ConVar g_CvarMapcycleFile;
ConVar g_CvarMapcyclePool;

ArrayList g_MapList = null;
ArrayList g_OldMapList = null;
int g_mapListSerial = -1;

static const char ZH_MAPCYCLE_PRIMARY[] = "cfg/mapcycle.txt";
static const char ZH_MAPCYCLE_FALLBACK[] = "addons/sourcemod/configs/ZH-sys/Tools/MapCycle/zh_mapcycle.cfg";
static const char ZH_MAPCYCLE_POOLS[] = "configs/ZH-sys/Tools/MapCycle/zh_mapcycle_pools.cfg";

public void OnPluginStart()
{
	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);	
	g_MapList = new ArrayList(arraySize);
	g_OldMapList = new ArrayList(arraySize);

	g_Cvar_ExcludeMaps = CreateConVar("sm_randomcycle_exclude", "5", "Specifies how many past maps to exclude from the vote.", _, true, 0.0);
	g_CvarMapcycleFile = FindConVar("mapcyclefile");
	g_CvarMapcyclePool = FindConVar("zh_mapcycle_pool");
	if (g_CvarMapcyclePool == null)
	{
		g_CvarMapcyclePool = CreateConVar("zh_mapcycle_pool", "", "Mapcycle pool key from configs/ZH-sys/Tools/MapCycle/zh_mapcycle_pools.cfg.", 0);
	}
	
	AutoExecConfig(true, "randomcycle");
}

public void OnConfigsExecuted()
{
	EnsureMapcycleFile();

	if (ReadMapList(g_MapList, 
					g_mapListSerial, 
					"randomcycle", 
					MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER)
		== null)
	{
		if (g_mapListSerial == -1)
		{
			LogError("Unable to create a valid map list.");
		}
	}
	
	CreateTimer(5.0, Timer_RandomizeNextmap, _, TIMER_FLAG_NO_MAPCHANGE); // Small delay to give Nextmap time to complete OnMapStart()
}

public Action Timer_RandomizeNextmap(Handle timer)
{
	char map[PLATFORM_MAX_PATH];
	char resolvedMap[PLATFORM_MAX_PATH];

	bool oldMaps = false;
	if (g_Cvar_ExcludeMaps.IntValue && g_MapList.Length > g_Cvar_ExcludeMaps.IntValue)
	{
		oldMaps = true;
	}
	
	do
	{
		int b = GetRandomInt(0, g_MapList.Length - 1);
		g_MapList.GetString(b, map, sizeof(map));
		FindMap(map, resolvedMap, sizeof(resolvedMap));
	} while (oldMaps && g_OldMapList.FindString(resolvedMap) != -1);
	
	g_OldMapList.PushString(resolvedMap);
	SetNextMap(map);

	if (g_OldMapList.Length > g_Cvar_ExcludeMaps.IntValue)
	{
		g_OldMapList.Erase(0);
	}

	LogAction(-1, -1, "RandomCycle has chosen %s for the nextmap.", map);	

	return Plugin_Stop;
}

bool ApplyMapcyclePoolOverride(bool hasCurrent, bool isDefault)
{
	if (g_CvarMapcyclePool == null || g_CvarMapcycleFile == null)
	{
		return false;
	}

	char requested[64];
	g_CvarMapcyclePool.GetString(requested, sizeof(requested));
	TrimString(requested);

	bool allowDefault = (!hasCurrent || isDefault);
	if (requested[0] == '\0' && !allowDefault)
	{
		return false;
	}

	char configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof(configPath), ZH_MAPCYCLE_POOLS);
	if (!FileExists(configPath))
	{
		if (requested[0] != '\0')
		{
			LogError("Mapcycle pools config not found: %s", configPath);
		}
		return false;
	}

	KeyValues kv = new KeyValues("ZH_MapCyclePools");
	if (!kv.ImportFromFile(configPath))
	{
		delete kv;
		LogError("Mapcycle pools config failed to parse: %s", configPath);
		return false;
	}

	char selected[64];
	if (requested[0] != '\0')
	{
		strcopy(selected, sizeof(selected), requested);
	}
	else
	{
		if (!kv.JumpToKey("settings"))
		{
			delete kv;
			return false;
		}

		kv.GetString("default_pool", selected, sizeof(selected), "");
		kv.Rewind();
		if (selected[0] == '\0')
		{
			delete kv;
			return false;
		}
	}

	if (!kv.JumpToKey("pools"))
	{
		delete kv;
		LogError("Mapcycle pools missing 'pools' section in %s", configPath);
		return false;
	}

	if (!kv.JumpToKey(selected))
	{
		delete kv;
		if (requested[0] != '\0')
		{
			LogError("Mapcycle pool '%s' not found in %s", selected, configPath);
		}
		return false;
	}

	char poolFile[PLATFORM_MAX_PATH];
	kv.GetString("file", poolFile, sizeof(poolFile), "");
	delete kv;

	TrimString(poolFile);
	if (poolFile[0] == '\0')
	{
		LogError("Mapcycle pool '%s' missing file path in %s", selected, configPath);
		return false;
	}

	if (!FileExists(poolFile))
	{
		LogError("Mapcycle pool '%s' file not found: %s", selected, poolFile);
		return false;
	}

	g_CvarMapcycleFile.SetString(poolFile);
	return true;
}

void EnsureMapcycleFile()
{
	if (g_CvarMapcycleFile == null)
	{
		return;
	}

	char current[PLATFORM_MAX_PATH];
	g_CvarMapcycleFile.GetString(current, sizeof(current));

	bool hasCurrent = (current[0] != '\0' && FileExists(current));
	bool isDefault = StrEqual(current, "mapcycle.txt", false) || StrEqual(current, ZH_MAPCYCLE_PRIMARY, false);

	if (ApplyMapcyclePoolOverride(hasCurrent, isDefault))
	{
		return;
	}

	if (FileExists(ZH_MAPCYCLE_PRIMARY))
	{
		if (!hasCurrent || isDefault)
		{
			g_CvarMapcycleFile.SetString(ZH_MAPCYCLE_PRIMARY);
			return;
		}

		if (hasCurrent)
		{
			return;
		}
	}

	if (hasCurrent)
	{
		return;
	}

	if (FileExists(ZH_MAPCYCLE_FALLBACK))
	{
		g_CvarMapcycleFile.SetString(ZH_MAPCYCLE_FALLBACK);
		return;
	}

	LogError("No mapcycle file found. Checked: %s, %s", ZH_MAPCYCLE_PRIMARY, ZH_MAPCYCLE_FALLBACK);
}
