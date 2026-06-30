# Source Dedicated Server (SRCDS) Command-Line Options

URL: https://developer.valvesoftware.com/wiki/Command_line_options#Source_Games

Command-line arguments for the Source Dedicated Server executable (`srcds.exe`, `srcds_linux`, `srcds_run`).

## Command-Line Parameters

| Argument | Description |
| :--- | :--- |
| `-allowdebug` | (Same as `-debug` ?) |
| `-autoupdate` | **[Linux]** Autoupdate the game. Requires `-steam_dir` and `-steamcmd_script` to be set. |
| `-binary <binary>` | **[Linux]** Use the specified binary (no auto detection). |
| `-console` | **[Windows]** SrcDS will run in console mode. On Linux, this is often used with `srcds_run`. |
| `-debug` | Run debugging on failed servers if possible. Requires `-gdb` to be set. |
| `-debuglog <logname>` | **[Linux]** Log debug output to this file. |
| `-dev` | Show developer messages. Enables developer mode which outputs extensive engine information. |
| `-fork <number>` | **[Linux]** Starts up the specified number of instances as subprocesses at once. They will each use the first available port number at 27015 or above. Substitutions like `autoexec##.cfg` can be used. |
| `-game <game or path>`| Specifies which game/mod to run. Accepts either a path to a `gameinfo.txt`, or one of the pre-set values (e.g. `cstrike`). |
| `-gdb <gdb>` | **[Linux]** Use `<dbg>` as the debugger of failed servers. |
| `-help` | **[Linux]** Prints command line help. |
| `-insecure` | Starts the server without Valve Anti-Cheat (VAC). |
| `-ignoresigint` | **[Linux]** Ignore signal INT (prevents CTRL+C quitting). |
| `-ip <address>` | Specifies the address to use for the `bind(2)` syscall, controlling which IP addresses the program is reachable on. Use `0.0.0.0` for all interfaces. |
| `-maxplayers <number>`| Specifies how many player slots the server can contain. |
| `-netconport <port>` | Creates a remotely accessible server console on the specified port (accessible via telnet). |
| `-netconpassword <pw>`| If set, users must type `PASS "password"` to use the remote console described above. |
| `-nobots` | Disable bots entirely. |
| `-nohltv` | Disables SourceTV and closes its port (usually 27020). |
| `-norestart` | Won't attempt to restart failed servers. |
| `-notrap` | **[Linux]** Don't use trap. This prevents automatic removal of old lock files. |
| `-port <number>` | The port the server advertises to clients (default 27015). |
| `-steam` | Use this (along with `-console`) when you are running the version of SRCDS downloaded through Steam. |
| `-steamcmd_script` | **[Linux]** Path to the steam script to execute. Example: `~/Steam/hl2_ds.txt`. |
| `-steamerr` | **[Linux]** Quit on steam update failure. |
| `-steamuser` | **[Linux]** Steam user ID. |
| `-steampass` | **[Linux]** Steam Login Password. |
| `-steam_dir <path>` | **[Linux]** Dir that steam.sh resides in. Example: `~/Steam` |
| `-tickrate <number>` | Specifies Server-Tickrate. Cannot be altered on standard newer CSS (locked to 66), but works on 2007/older builds. |
| `-timeout <number>` | Sleep for `<number>` seconds before restarting a failed server. |
| `-dumplongticks` | Generate minidumps when there are long server frames. |
| `-condebug` | Logs all console output into `cstrike/console.log`. |
| `+log on` | Enables saving standard server events to `cstrike/logs/`. |

---
*Примечание: Документ был очищен от веб-разметки и переведен в легковесный Markdown для корректного индексирования RAG-базой ZH-sys.*
