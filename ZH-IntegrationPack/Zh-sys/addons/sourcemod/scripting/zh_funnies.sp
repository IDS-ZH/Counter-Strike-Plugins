#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zh_core>
#include <zh_webbridge> // для интеграции с веб-панелью

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "ZH-sys Funnies (unified funcommands/funvotes)",
	author = "ZloyHohol integration workbench",
	description = "Unified fun commands and votes with web control",
	version = PLUGIN_VERSION,
	url = ""
};

// Admin Menu
TopMenu hTopMenu;

// Sounds
char g_BlipSound[PLATFORM_MAX_PATH];
char g_BeepSound[PLATFORM_MAX_PATH];
char g_FinalSound[PLATFORM_MAX_PATH];
char g_BoomSound[PLATFORM_MAX_PATH];
char g_FreezeSound[PLATFORM_MAX_PATH];

// Following are model indexes for temp entities
int g_BeamSprite        = -1;
int g_BeamSprite2       = -1;
int g_HaloSprite        = -1;
int g_GlowSprite        = -1;
int g_ExplosionSprite   = -1;

// Basic color arrays for temp entities
int orangeColor[4]	= {255, 128, 0, 255};
int blueColor[4]	= {75, 75, 255, 255};
int whiteColor[4]	= {255, 255, 255, 255};
int greyColor[4]	= {128, 128, 128, 255};

int g_ExternalBeaconColor[4];
int g_Team1BeaconColor[4];
int g_Team2BeaconColor[4];
int g_Team3BeaconColor[4];
int g_Team4BeaconColor[4];
int g_TeamUnknownBeaconColor[4];

// UserMessageId for Fade.
UserMsg g_FadeUserMsgId;

// Serial Generator for Timer Safety
int g_Serial_Gen = 0;

EngineVersion g_GameEngine = Engine_Unknown;

// Flags used in various timers
#define DEFAULT_TIMER_FLAGS TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE

// ConVars for fun commands
ConVar g_Cvar_BeaconRadius;
ConVar g_Cvar_TimeBombTicks;
ConVar g_Cvar_TimeBombRadius;
ConVar g_Cvar_TimeBombMode;
ConVar g_Cvar_BurnDuration;
ConVar g_Cvar_FireBombTicks;
ConVar g_Cvar_FireBombRadius;
ConVar g_Cvar_FireBombMode;
ConVar g_Cvar_FreezeDuration;
ConVar g_Cvar_FreezeBombTicks;
ConVar g_Cvar_FreezeBombRadius;
ConVar g_Cvar_FreezeBombMode;

// ConVars for fun votes
#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

Menu g_hVoteMenu = null;

ConVar g_Cvar_VoteLimits[5] = {null, ...};
ConVar g_Cvar_Gravity;
ConVar g_Cvar_Alltalk;
ConVar g_Cvar_FF;

enum voteType
{
	gravity = 0,
	burn,
	slay,
	alltalk,
	ff
};

voteType g_voteType = gravity;

#define VOTE_NAME	0
#define VOTE_AUTHID	1
#define	VOTE_IP		2
char g_voteInfo[3][65];		/* Holds the target's name, authid, and IP */

// Include various commands and supporting functions
#include "zh_funnies/beacon.sp"
#include "zh_funnies/timebomb.sp"
#include "zh_funnies/fire.sp"
#include "zh_funnies/ice.sp"
#include "zh_funnies/gravity.sp"
#include "zh_funnies/blind.sp"
#include "zh_funnies/noclip.sp"
#include "zh_funnies/drug.sp"
#include "zh_funnies/votegravity.sp"
#include "zh_funnies/voteburn.sp"
#include "zh_funnies/voteslay.sp"
#include "zh_funnies/votealltalk.sp"
#include "zh_funnies/voteff.sp"

public void OnPluginStart()
{
	if (!LibraryExists(ZH_CORE_LIBRARY))
	{
		SetFailState("zh_core is required.");
	}

	LoadTranslations("common.phrases");
	LoadTranslations("funcommands.phrases");
	LoadTranslations("basevotes.phrases");
	LoadTranslations("funvotes.phrases");

	g_GameEngine = GetEngineVersion();
	g_FadeUserMsgId = GetUserMessageId("Fade");

	RegisterCvars();
	RegisterCmds();
	HookEvents();

	// Register with ZH-sys
	ZH_RegisterModule("funnies");

	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}

	// Register web handlers
	RegisterWebHandlers();
}

void RegisterCvars()
{
	// beacon
	g_Cvar_BeaconRadius = CreateConVar("zh_funnies_beacon_radius", "375", "Sets the radius for beacon's light rings.", 0, true, 50.0, true, 1500.0);

	// timebomb
	g_Cvar_TimeBombTicks = CreateConVar("zh_funnies_timebomb_ticks", "10.0", "Sets how long the timebomb fuse is.", 0, true, 5.0, true, 120.0);
	g_Cvar_TimeBombRadius = CreateConVar("zh_funnies_timebomb_radius", "600", "Sets the bomb blast radius.", 0, true, 50.0, true, 3000.0);
	g_Cvar_TimeBombMode = CreateConVar("zh_funnies_timebomb_mode", "0", "Who is killed by the timebomb? 0 = Target only, 1 = Target's team, 2 = Everyone", 0, true, 0.0, true, 2.0);

	// fire
	g_Cvar_BurnDuration = CreateConVar("zh_funnies_burn_duration", "20.0", "Sets the default duration of sm_burn and firebomb victims.", 0, true, 0.5, true, 20.0);
	g_Cvar_FireBombTicks = CreateConVar("zh_funnies_firebomb_ticks", "10.0", "Sets how long the FireBomb fuse is.", 0, true, 5.0, true, 120.0);
	g_Cvar_FireBombRadius = CreateConVar("zh_funnies_firebomb_radius", "600", "Sets the bomb blast radius.", 0, true, 50.0, true, 3000.0);
	g_Cvar_FireBombMode = CreateConVar("zh_funnies_firebomb_mode", "0", "Who is targetted by the FireBomb? 0 = Target only, 1 = Target's team, 2 = Everyone", 0, true, 0.0, true, 2.0);

	// ice
	g_Cvar_FreezeDuration = CreateConVar("zh_funnies_freeze_duration", "10.0", "Sets the default duration for sm_freeze and freezebomb victims", 0, true, 1.0, true, 120.0);
	g_Cvar_FreezeBombTicks = CreateConVar("zh_funnies_freezebomb_ticks", "10.0", "Sets how long the freezebomb fuse is.", 0, true, 5.0, true, 120.0);
	g_Cvar_FreezeBombRadius = CreateConVar("zh_funnies_freezebomb_radius", "600", "Sets the freezebomb blast radius.", 0, true, 50.0, true, 3000.0);
	g_Cvar_FreezeBombMode = CreateConVar("zh_funnies_freezebomb_mode", "0", "Who is targetted by the freezebomb? 0 = Target only, 1 = Target's team, 2 = Everyone", 0, true, 0.0, true, 2.0);

	// Vote limits
	g_Cvar_VoteLimits[0] = CreateConVar("zh_funnies_vote_gravity", "0.60", "percent required for successful gravity vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_VoteLimits[1] = CreateConVar("zh_funnies_vote_burn", "0.60", "percent required for successful burn vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_VoteLimits[2] = CreateConVar("zh_funnies_vote_slay", "0.60", "percent required for successful slay vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_VoteLimits[3] = CreateConVar("zh_funnies_vote_alltalk", "0.60", "percent required for successful alltalk vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_VoteLimits[4] = CreateConVar("zh_funnies_vote_ff", "0.60", "percent required for successful friendly fire vote.", 0, true, 0.05, true, 1.0);

	g_Cvar_Gravity = FindConVar("sv_gravity");
	g_Cvar_Alltalk = FindConVar("sv_alltalk");
	g_Cvar_FF = FindConVar("mp_friendlyfire");

	AutoExecConfig(true, "zh_funnies", "sourcemod");
}

void RegisterCmds()
{
	// Fun commands
	RegAdminCmd("sm_beacon", Command_Beacon, ADMFLAG_SLAY, "sm_beacon <#userid|name> [0/1]");
	RegAdminCmd("sm_timebomb", Command_TimeBomb, ADMFLAG_SLAY, "sm_timebomb <#userid|name> [0/1]");
	RegAdminCmd("sm_burn", Command_Burn, ADMFLAG_SLAY, "sm_burn <#userid|name> [time]");
	RegAdminCmd("sm_firebomb", Command_FireBomb, ADMFLAG_SLAY, "sm_firebomb <#userid|name> [0/1]");
	RegAdminCmd("sm_freeze", Command_Freeze, ADMFLAG_SLAY, "sm_freeze <#userid|name> [time]");
	RegAdminCmd("sm_freezebomb", Command_FreezeBomb, ADMFLAG_SLAY, "sm_freezebomb <#userid|name> [0/1]");
	RegAdminCmd("sm_gravity", Command_Gravity, ADMFLAG_SLAY, "sm_gravity <#userid|name> [amount] - Leave amount off to reset. Amount is 0.0 through 5.0");
	RegAdminCmd("sm_blind", Command_Blind, ADMFLAG_SLAY, "sm_blind <#userid|name> [amount] - Leave amount off to reset.");
	RegAdminCmd("sm_noclip", Command_NoClip, ADMFLAG_SLAY|ADMFLAG_CHEATS, "sm_noclip <#userid|name>");
	RegAdminCmd("sm_drug", Command_Drug, ADMFLAG_SLAY, "sm_drug <#userid|name> [0/1]");

	// Fun votes
	RegAdminCmd("sm_votegravity", Command_VoteGravity, ADMFLAG_VOTE, "sm_votegravity <amount> [amount2] ... [amount5]");
	RegAdminCmd("sm_voteburn", Command_VoteBurn, ADMFLAG_VOTE|ADMFLAG_SLAY, "sm_voteburn <player>");
	RegAdminCmd("sm_voteslay", Command_VoteSlay, ADMFLAG_VOTE|ADMFLAG_SLAY, "sm_voteslay <player>");
	RegAdminCmd("sm_votealltalk", Command_VoteAlltalk, ADMFLAG_VOTE, "sm_votealltalk");
	RegAdminCmd("sm_voteff", Command_VoteFF, ADMFLAG_VOTE, "sm_voteff");
}

void HookEvents()
{
	char folder[64];
	GetGameFolderName(folder, sizeof(folder));

	if (strcmp(folder, "tf") == 0)
	{
		HookEvent("teamplay_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("teamplay_restart_round", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	}
	else if (strcmp(folder, "nucleardawn") == 0)
	{
		HookEvent("round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
	}
	else
	{
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	}
}

public void OnMapStart()
{
	GameData gameConfig = new GameData("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	if (gameConfig.GetKeyValue("SoundBlip", g_BlipSound, sizeof(g_BlipSound)) && g_BlipSound[0])
	{
		PrecacheSound(g_BlipSound, true);
	}

	if (gameConfig.GetKeyValue("SoundBeep", g_BeepSound, sizeof(g_BeepSound)) && g_BeepSound[0])
	{
		PrecacheSound(g_BeepSound, true);
	}

	if (gameConfig.GetKeyValue("SoundFinal", g_FinalSound, sizeof(g_FinalSound)) && g_FinalSound[0])
	{
		PrecacheSound(g_FinalSound, true);
	}

	if (gameConfig.GetKeyValue("SoundBoom", g_BoomSound, sizeof(g_BoomSound)) && g_BoomSound[0])
	{
		PrecacheSound(g_BoomSound, true);
	}

	if (gameConfig.GetKeyValue("SoundFreeze", g_FreezeSound, sizeof(g_FreezeSound)) && g_FreezeSound[0])
	{
		PrecacheSound(g_FreezeSound, true);
	}

	char buffer[PLATFORM_MAX_PATH];
	if (gameConfig.GetKeyValue("SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}

	if (gameConfig.GetKeyValue("SpriteBeam2", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite2 = PrecacheModel(buffer);
	}

	if (gameConfig.GetKeyValue("SpriteExplosion", buffer, sizeof(buffer)) && buffer[0])
	{
		g_ExplosionSprite = PrecacheModel(buffer);
	}

	if (gameConfig.GetKeyValue("SpriteGlow", buffer, sizeof(buffer)) && buffer[0])
	{
		g_GlowSprite = PrecacheModel(buffer);
	}

	if (gameConfig.GetKeyValue("SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}

	if (gameConfig.GetKeyValue("ExternalBeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_ExternalBeaconColor = ParseColor(buffer);
	}

	if (gameConfig.GetKeyValue("Team1BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team1BeaconColor = ParseColor(buffer);
	}

	if (gameConfig.GetKeyValue("Team2BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team2BeaconColor = ParseColor(buffer);
	}

	if (gameConfig.GetKeyValue("Team3BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team3BeaconColor = ParseColor(buffer);
	}

	if (gameConfig.GetKeyValue("Team4BeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_Team4BeaconColor = ParseColor(buffer);
	}

	if (gameConfig.GetKeyValue("TeamUnknownBeaconColor", buffer, sizeof(buffer)) && buffer[0])
	{
		g_TeamUnknownBeaconColor = ParseColor(buffer);
	}

	delete gameConfig;
}

public void OnMapEnd()
{
	KillAllBeacons();
	KillAllTimeBombs();
	KillAllFireBombs();
	KillAllFreezes();
	KillAllDrugs();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	KillAllBeacons();
	KillAllTimeBombs();
	KillAllFireBombs();
	KillAllFreezes();
	KillAllDrugs();

	return Plugin_Continue;
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}

	/* Save the Handle */
	hTopMenu = topmenu;

	/* Find the "Player Commands" category */
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_beacon", AdminMenu_Beacon, player_commands, "sm_beacon", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_timebomb", AdminMenu_TimeBomb, player_commands, "sm_timebomb", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_burn", AdminMenu_Burn, player_commands, "sm_burn", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_firebomb", AdminMenu_FireBomb, player_commands, "sm_firebomb", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_freeze", AdminMenu_Freeze, player_commands, "sm_freeze", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_freezebomb", AdminMenu_FreezeBomb, player_commands, "sm_freezebomb", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_gravity", AdminMenu_Gravity, player_commands, "sm_gravity", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_blind", AdminMenu_Blind, player_commands, "sm_blind", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_noclip", AdminMenu_NoClip, player_commands, "sm_noclip", ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_drug", AdminMenu_Drug, player_commands, "sm_drug", ADMFLAG_SLAY);
	}

	/* Build the "Voting Commands" category */
	TopMenuObject voting_commands = hTopMenu.FindCategory(ADMINMENU_VOTINGCOMMANDS);

	if (voting_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_votegravity", AdminMenu_VoteGravity, voting_commands, "sm_votegravity", ADMFLAG_VOTE);
		hTopMenu.AddItem("sm_voteburn", AdminMenu_VoteBurn, voting_commands, "sm_voteburn", ADMFLAG_VOTE|ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_voteslay", AdminMenu_VoteSlay, voting_commands, "sm_voteslay", ADMFLAG_VOTE|ADMFLAG_SLAY);
		hTopMenu.AddItem("sm_votealltalk", AdminMenu_VoteAllTalk, voting_commands, "sm_votealltalk", ADMFLAG_VOTE);
		hTopMenu.AddItem("sm_voteff", AdminMenu_VoteFF, voting_commands, "sm_voteff", ADMFLAG_VOTE);
	}
}

void AddTranslatedMenuItem(Menu menu, const char[] opt, const char[] phrase, int client)
{
	char buffer[128];
	Format(buffer, sizeof(buffer), "%T", phrase, client);
	menu.AddItem(opt, buffer);
}

int[] ParseColor(const char[] buffer)
{
	char sColor[16][4];
	ExplodeString(buffer, ",", sColor, sizeof(sColor), sizeof(sColor[]));

	int iColor[4];
	iColor[0] = StringToInt(sColor[0]);
	iColor[1] = StringToInt(sColor[1]);
	iColor[2] = StringToInt(sColor[2]);
	iColor[3] = StringToInt(sColor[3]);

	return iColor;
}

// Web handler registration
void RegisterWebHandlers()
{
	// Register fun command handlers
	ZH_Web_RegisterHandler("funnies_beacon", HandleWebBeacon);
	ZH_Web_RegisterHandler("funnies_timebomb", HandleWebTimeBomb);
	ZH_Web_RegisterHandler("funnies_burn", HandleWebBurn);
	ZH_Web_RegisterHandler("funnies_firebomb", HandleWebFireBomb);
	ZH_Web_RegisterHandler("funnies_freeze", HandleWebFreeze);
	ZH_Web_RegisterHandler("funnies_freezebomb", HandleWebFreezeBomb);
	ZH_Web_RegisterHandler("funnies_gravity", HandleWebGravity);
	ZH_Web_RegisterHandler("funnies_blind", HandleWebBlind);
	ZH_Web_RegisterHandler("funnies_noclip", HandleWebNoClip);
	ZH_Web_RegisterHandler("funnies_drug", HandleWebDrug);

	// Register fun vote handlers
	ZH_Web_RegisterHandler("funnies_votegravity", HandleWebVoteGravity);
	ZH_Web_RegisterHandler("funnies_voteburn", HandleWebVoteBurn);
	ZH_Web_RegisterHandler("funnies_voteslay", HandleWebVoteSlay);
	ZH_Web_RegisterHandler("funnies_votealltalk", HandleWebVoteAllTalk);
	ZH_Web_RegisterHandler("funnies_voteff", HandleWebVoteFF);
}

// Placeholder functions for web handlers - to be implemented in includes
public int HandleWebBeacon(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebTimeBomb(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebBurn(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebFireBomb(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebFreeze(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebFreezeBomb(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebGravity(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebBlind(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebNoClip(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebDrug(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebVoteGravity(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebVoteBurn(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebVoteSlay(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebVoteAllTalk(const char[] data)
{
	// Implementation will be in include file
	return 0;
}

public int HandleWebVoteFF(const char[] data)
{
	// Implementation will be in include file
	return 0;
}