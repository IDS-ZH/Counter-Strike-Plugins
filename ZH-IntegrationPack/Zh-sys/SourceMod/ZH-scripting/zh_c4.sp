#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <zh_core>

#define PLUGIN_VERSION "0.2.0-draft"

ConVar g_CvarAnnounce;
ConVar g_CvarBotHint;
ConVar g_CvarMultiBomb;

public Plugin myinfo =
{
    name = "ZH-sys C4 tools (draft)",
    author = "ZloyHohol integration workbench",
    description = "C4 site announce + bot hint placeholder.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    if (!LibraryExists(ZH_CORE_LIBRARY))
    {
        SetFailState("zh_core is required.");
    }

    g_CvarAnnounce = CreateConVar("zh_c4_announce", "1", "Announce planted site via HUD/audio.");
    g_CvarBotHint = CreateConVar("zh_c4_bot_hint", "1", "Send bot hint towards planted site (experimental).");
    g_CvarMultiBomb = CreateConVar("zh_c4_multibomb", "0", "Allow multiple C4 placements (map plugins may override).");
    AutoExecConfig(true, "zh_c4", "sourcemod");

    HookEvent("bomb_planted", Event_BombPlanted, EventHookMode_Post);
    HookEvent("bomb_defused", Event_Reset, EventHookMode_Post);
    HookEvent("bomb_exploded", Event_Reset, EventHookMode_Post);

    ZH_RegisterModule("c4");
}

public void OnMapEnd()
{
    // Cleanup state if needed.
}

void Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
    if (g_CvarAnnounce.BoolValue)
    {
        int site = event.GetInt("site");
        AnnounceSite(site);
    }

    if (!g_CvarMultiBomb.BoolValue)
    {
        // Optional: could disable other bomb sites via ent flags; skip for now.
    }

    if (g_CvarBotHint.BoolValue)
    {
        int site = event.GetInt("site");
        HintBots(site);
    }
}

void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
    // TODO: clear markers/hints.
}

void AnnounceSite(int site)
{
    char msg[64];
    Format(msg, sizeof(msg), "Bomb planted at site %c", 'A' + site);
    PrintCenterTextAll(msg);
    PrintToChatAll("[C4] %s", msg);
    // TODO: hook SoundManifest/voice lines here.
}

void HintBots(int site)
{
    // TODO: integrate with bot navigation (beacons, removed zones, CCSBot detours) when extensions are ready.
    ZH_LogInfo("Bot hint to site %c (stub)", 'A' + site);
}
