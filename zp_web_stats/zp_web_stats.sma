/*
*	
*	[ZP] Web Stats 0.2.5
*	
*	(c) Copyright 2009 by PomanoB
*
*	This file is provided as is (no warranties)
*	
*	Description
*
*		Statistic Plugin for Zombie Plague 4.3
*		Includes Ammo Bank
*		
*	Modules
*
*		sqlx
*		hamasndwitch
*		fakemeta
*		
*	Admin Commands
*
*		zp_ammo <name|#userid|@Z|@H|@A> <count>
*			Give ammo to
*			@Z - All zombie
*			@H - All human
*			@A - All players
*
*	Client commands
*
*		say /hp
*			Display information about you killer
*		
*		say /me	
*			Display you information (kills ,infect, damage, last hit)
*		
*		say /rank [name|ip|steam_id]
*			Display you/player rank
*
*		say /stats [name|ip|steam_id]
*		say /rankstats [name|ip|steam_id]
*			Display you/player detail stats
*	
*		say /top[number]
*			Display 15 top players, ending with the specified value [number] 
*
*		say /donate <target> <count>
*			Present <count> ammo to <target>
*
*	CVAR's
*	
*		zp_stats_host - Database host
*		zp_stats_db - database
*		zp_stats_user - MySQL user
*		zp_stats_password - MySQL password
*
*		zp_stats_allow_hp - Allow client command say /hp
*		zp_stats_allow_me - Allow client command say /me
*		zp_stats_show_hit - If 1, display zombie hp when player hit
*		zp_stats_allow_donate - Allow client command say /donate		
*
*		zp_stats_max_inactive_day - Max inactive day to players in top
*		zp_stats_min_ammo - Min ammo to players in top
*		zp_stats_min_online - Min online to players in top		
*
*		zp_stats_store_class - If 1, players zombie class save in database
*		zp_class_store_ammo - If 1, players ammo save in database
*
*		zp_stats_limit_ammo - Limits for maximum ammo, 0 - disable
*
*		zp_stats_show_adv - If 1, show info about client command's
*		zp_stats_adv_time - Time to show adv.
*
*		zp_stats_show_best_players - Show the best players in round (default 1)
*		zp_stats_show_rank_on_round_start - Show rank(rank change) on round start (default 1)
*
*		zp_stats_auth_type 
*			1 - Steam ID
*			2 - IP Address
*			3 - Nickname
*			above - Steam ID/IP Adress
*		
*			default - 4
*		
*		zp_stats_ignore_nick - Tag, which does not take calculate statistics (default "[unreg]")
*
*		
*	Defines
*
*		Uncomment "//#define ZP_STATS_DEBUG" to detail log
*
*	Installation
*			
*		Copy the 'web/zp_stats' directory to your website
*		Use the file 'web/zp_stats.sql' to initialize the database
*			
*		Copy the 'addons' directory to your 'cstrike' folder
*		Add the plugin name to addons/amxmodx/configs/plugins.ini
*
*	Version History
*
*		0.1.0 - First public release
*		0.2.0 - Global update, change plugin name
*		0.2.1 - Optimisation
*		0.2.2 - Fixed small bag
*		0.2.3 - Fixed charset problem
*		0.2.4 - Added cvar "zp_stats_allow_donate"
*		0.2.5 - Fixed zp_class_store_ammo bug
*
*/

#include <amxmodx>
#include <amxmisc>
//#include <zombieplague>
#include <sqlx>
#include <hamsandwich>
#include <time>
#include <fakemeta>

#include <zp50_core>
#include <zp50_ammopacks>

#define LIBRARY_ZOMBIECLASSES "zp50_class_zombie"
#include <zp50_class_zombie>

#define LIBRARY_HUMANCLASSES "zp50_class_human"
#include <zp50_class_human>

#include <zp50_class_nemesis>
#include <zp50_class_survivor>

#pragma dynamic 16384

#define PLUGIN "[ZP] Web Stats"
#define VERSION "0.2.5"
#define AUTHOR "PomanoB"

#define ZP_STATS_DEBUG
 
#define column(%1) SQL_FieldNameToNum(query, %1)

enum 
{
	KILLER_ID,
	KILLER_HP,
	KILLER_ARMOUR,
	KILLER_NUM
}

enum 
{
	ME_DMG,
	ME_HIT,
	ME_INFECT,
	ME_KILLS,
	ME_NUM
}

new g_StartTime[33]
new g_UserIP[33][32], g_UserAuthID[33][32], g_UserName[33][32]
new g_UserDBId[33], g_TotalDamage[33]
new bool:g_UserPutInServer[33]

new g_UserAmmo[33], g_UserClass[33]

new Handle:g_SQL_Connection, Handle:g_SQL_Tuple

new g_Query[3024]

new g_CvarStartedAmmo

new g_CvarAllowHp, g_CvarAllowMe, g_CvarShowHit, g_CvarMinOnline
new g_CvarMaxInactive, g_CvarMinAmmo, g_CvarStoreClass, g_CvarStoreAmmo
new g_CvarLimitAmmo, g_CvarShowAdv, g_CvarAdvTime, g_CvarShowBest
new g_CvarHost, g_CvarUser, g_CvarPassword, g_CvarDB, g_CvarAllowDonate

new g_CvarAuthType, g_CvarShowRankOnRoundStart, g_CvarExcludingNick

new g_damagedealt[33]

enum _:
{
	PLAYER_BAD_EVENT = 0,
	PLAYER_FIRST_ZOMBIE,
	PLAYER_INFECT,
	PLAYER_HAS_BEEN_INFECTED,
	PLAYER_HAS_BEEN_NEMESIS,
	PLAYER_HAS_BEEN_SURV,
	PLAYER_KILL_ZOMBIE,
	PLAYER_KILL_HUMAN,
	PLAYER_KILL_NEMESIS,
	PLAYER_KILL_SURV,
	PLAYER_DEATH,
	PLAYER_SUICIDE
}
	
new g_Killers[33][KILLER_NUM]
new g_Me[33][ME_NUM]

new g_Hits[33][31][9], g_Kills[33][31]
new g_Weapon[33], g_OldWeapon[33], g_OldAmmo[33]

new g_OldRank[33]

new const g_HitsName[8][] = {"HIT_NONE", "HIT_HEAD", "HIT_CHEST", "HIT_STOMACH", "HIT_LEFTARM", "HIT_RIGHTARM", "HIT_LEFTLEG", "HIT_RIGHTLEG"}
	
new g_text[5096]	
	
new g_mapname[32]

enum _:
{
	WIN_NO_ONE = 0,
	WIN_ZOMBIES,
	WIN_HUMANS
}
new g_win_team[3][] = {"tie", "zombie_win", "human_win"}

new g_ServerString[25]

new g_graphDamage, g_graphKills, g_graphInfect, g_graphConnections

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_CvarHost = register_cvar("zp_stats_host", "127.0.0.1")
	g_CvarDB = register_cvar("zp_stats_db", "zp_stats")
	g_CvarUser = register_cvar("zp_stats_user", "root")
	g_CvarPassword = register_cvar("zp_stats_password", "")
	
	register_cvar("zp_web_stats_version", VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	
	g_CvarAllowHp = register_cvar("zp_stats_allow_hp", "1")
	g_CvarAllowMe = register_cvar("zp_stats_allow_me", "1")
	g_CvarShowHit = register_cvar("zp_stats_show_hit", "1")
	g_CvarAllowDonate = register_cvar("zp_stats_allow_donate", "1")

	g_CvarMaxInactive = register_cvar("zp_stats_max_inactive_day", "5")
	g_CvarMinAmmo = register_cvar("zp_stats_min_ammo", "100")
	g_CvarMinOnline = register_cvar("zp_stats_min_online", "240")
	
	g_CvarStoreClass = register_cvar("zp_stats_store_class", "1")
	g_CvarStoreAmmo = register_cvar("zp_stats_store_ammo", "1")
	
	g_CvarLimitAmmo = register_cvar("zp_stats_limit_ammo", "0")
	
	g_CvarShowAdv = register_cvar("zp_stats_show_adv", "1")
	g_CvarAdvTime = register_cvar("zp_stats_adv_time", "120.0")
	
	g_CvarShowBest = register_cvar("zp_stats_show_best_players", "1")
	g_CvarShowRankOnRoundStart = register_cvar("zp_stats_show_rank_on_round_start", "2")
	
	g_CvarAuthType = register_cvar("zp_stats_auth_type", "6")
		
	g_CvarExcludingNick = register_cvar("zp_stats_ignore_nick", "[unreg]")
	
	register_clcmd("say", "handleSay")
	register_clcmd("say_team", "handleSay")
	
	register_concmd("zp_ammo", "cmdAmmo", ADMIN_RCON, " <target> <count> - Give Ammo")	
	
	RegisterHam(Ham_Killed, "player", "fw_HamKilled")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage", 1)
	RegisterHam(Ham_CS_RoundRespawn, "player", "fw_CS_RoundRespawn", 1)
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack", 1)

	register_message(get_user_msgid("CurWeapon"), "msgCurWeapon")
	
	register_event("HLTV", "event_RoundStart", "a", "1=0", "2=0")
	
	register_dictionary("time.txt")
	register_dictionary("zp_web_stats.txt")
	
}

public plugin_cfg()
{
	
	new cfgdir[32]
	get_configsdir(cfgdir, charsmax(cfgdir))
	server_cmd("exec %s/zp_web_stats.cfg", cfgdir)
	server_exec()
	
	g_CvarStartedAmmo = get_cvar_pointer("zp_starting_ammo_packs")
	
	new host[32], db[32], user[32], password[32]
	get_pcvar_string(g_CvarHost, host, 31)
	get_pcvar_string(g_CvarDB, db, 31)
	get_pcvar_string(g_CvarUser, user, 31)
	get_pcvar_string(g_CvarPassword, password, 31)
	
	g_SQL_Tuple = SQL_MakeDbTuple(host,user,password,db)
	
	new err, error[256]
	g_SQL_Connection = SQL_Connect(g_SQL_Tuple, err, error, charsmax(error))
	
	if(g_SQL_Connection != Empty_Handle)
	{
		log_amx("%L",LANG_SERVER, "CONNECT_SUCSESSFUL")
		
		get_mapname(g_mapname, 31)
		SQL_QueryAndIgnore(g_SQL_Connection, "INSERT INTO `zp_maps` (`map`) VALUES ('%s') ON DUPLICATE KEY UPDATE `games` = `games` + 1", g_mapname)
	}
	else
	{
		log_amx("%L",LANG_SERVER, "CONNECT_ERROR", err, error)
		pause("a")
	}
	
	SQL_QueryAndIgnore(g_SQL_Connection, "SET NAMES utf8")
	
	if (get_pcvar_num(g_CvarShowAdv))
		set_task(get_pcvar_float(g_CvarAdvTime), "showAdv", _, _, _, "b")
		
	new buffer[25], len
	get_cvar_string("ip", buffer, 24)
	len = format(g_ServerString, 24, buffer)
	get_cvar_string("port", buffer, 24)
	format(g_ServerString[len], 24 - len, ":%s", buffer)
	format(g_Query, charsmax(g_Query), "DELETE FROM `zp_server_players` WHERE `server` = '%s'", g_ServerString)
	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
}

public plugin_natives()
{
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}

public module_filter(const module[])
{
	if (equal(module, LIBRARY_ZOMBIECLASSES) || equal(module, LIBRARY_HUMANCLASSES))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}


public plugin_end()
{
	
	SQL_QueryAndIgnore(g_SQL_Connection, "DELETE FROM `zp_server_players`")
	SQL_FreeHandle(g_SQL_Tuple)
	SQL_FreeHandle(g_SQL_Connection)
#if defined ZP_STATS_DEBUG
	log_amx("[ZP] Stats Debug: plugin end")
#endif
}

public event_RoundStart()
{
	new players[32], plNum, i, len = 0
	
	if (!get_pcvar_num(g_CvarShowRankOnRoundStart))
		return
	
	
	new activity = get_systime() - get_pcvar_num(g_CvarMaxInactive) * 24 * 60 * 60
	new min_ammo = get_pcvar_num(g_CvarMinAmmo)
	new min_online = get_pcvar_num(g_CvarMinOnline) * 60
	
	len = format(g_Query, charsmax(g_Query), "SELECT *,(SELECT COUNT(*) FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d) AS `total` FROM \
		(SELECT `id`, (@_c := @_c + 1) AS `rank`, \
		((`infect` + `zombiekills` + `humankills` + `nemkills`*4 + `survkills`*4)/(`suicide`*4+`death`+`infected` + 1)) AS `skill` ",
		activity, min_ammo, min_online)
	len += format(g_Query[len], charsmax(g_Query) - len, " FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d \
		ORDER BY `skill` DESC) AS `newtable` WHERE `id` IN (", 
		activity, min_ammo, min_online)
	
	get_players(players, plNum, "ch")
	for (i = 0; i < plNum; i++)
	{
		if (!g_UserDBId[players[i]])
			continue
		len += format(g_Query[len], charsmax(g_Query) - len, " %d,",  g_UserDBId[players[i]])
	}
	--len
	format(g_Query[len], charsmax(g_Query) - len, ")")
	
	SQL_QueryAndIgnore(g_SQL_Connection, "SET @_c = 0")
	new Handle:query = SQL_PrepareQuery(g_SQL_Connection, g_Query)
	SQL_Execute(query)
	
	new new_rank, id
	
	while (SQL_MoreResults(query))
	{
		new_rank = SQL_ReadResult(query, column("rank"))
		id = SQL_ReadResult(query, column("id"))
		for (i = 0; i < plNum; i++)
		{
			if (id == g_UserDBId[players[i]])
			{
				if (!g_OldRank[players[i]] || g_OldRank[players[i]] == new_rank)
					client_print(players[i], print_chat, "%L", players[i], "ROUND_RANK", new_rank)
				else
				if (g_OldRank[players[i]] > new_rank)
					client_print(players[i], print_chat, "%L", players[i], "ROUND_RANK_DOWN", g_OldRank[players[i]] - new_rank, new_rank)
				else
					client_print(players[i], print_chat, "%L", players[i], "ROUND_RANK_UP", new_rank - g_OldRank[players[i]], new_rank)
				
				g_OldRank[players[i]] = new_rank
			}
		}
		
		SQL_NextRow(query)
	}
}

public showAdv()
{
	static advNum
	new players[32], playersNum, i
	new advLangString[32]
	
	format(advLangString, 31, "ADV_STRING%d", (advNum++ % 3 + 1))
	
	get_players(players, playersNum, "ch")
	for (i = 0; i < playersNum; i++)
	{
		set_hudmessage(255, 0, 0, 0.02, 0.61, 0, 12.0, 12.0)
		show_hudmessage(players[i], "%L", players[i] , advLangString)
	}
}

public cmdAmmo(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED
		
	new arg1[24]
	read_argv(1, arg1, 23)
	
	new arg2[10]
	read_argv(2, arg2, 9)
	new count = str_to_num(arg2)
	
	if (!count)
	{
		console_print(id, "%L", id, "INVALID_AMMO")
		return PLUGIN_HANDLED
	}
	
	if (arg1[0] == '@')
	{
		new team = 0
		
		if (arg1[1] == 'Z' || arg1[1] == 'z')
			team = 1
		else
		if (arg1[1] == 'H' || arg1[1] == 'h')
			team = 2
			
		new players[32], num
		new zombie
		
		get_players(players, num)
		new i
		for (i=0; i<num; i++)
		{
			zombie = zp_core_is_zombie(id)
			if (!team || (zombie && team == 1)|| (!zombie && team == 2))
			{
				give_ammo(players[i], count)
			}
		}
	}
	else
	{
		new player = cmd_target(id, arg1, CMDTARGET_ALLOW_SELF)
		if (!player)
		{
			console_print(id, "%L", id, "CLIENT_NOT_FOUND", arg1)
			return PLUGIN_HANDLED
		}
		else
		{
			give_ammo(player, count)
		}
	}
	
	return PLUGIN_HANDLED	
}

public give_ammo(id, count)
{
	zp_ammopacks_set(id, zp_ammopacks_get(id) + count)
}

public client_authorized(id)
{
	g_UserPutInServer[id] = false
	
	g_graphConnections++
	
	fw_CS_RoundRespawn(id)
	
	g_StartTime[id] = get_systime()
	
	g_UserDBId[id] = 0
	g_UserAmmo[id] = 0
	g_UserClass[id] = 0
	
	g_TotalDamage[id] = 0
				
	g_OldRank[id] = 0			
	
	new unquoted_name[32], exluding_nick[32]
	get_user_name(id,unquoted_name,31)
	
	get_pcvar_string(g_CvarExcludingNick, exluding_nick, 31)
	if (exluding_nick[0] && containi(unquoted_name, exluding_nick) != -1)
		return
	
	SQL_QuoteString(g_SQL_Connection , g_UserName[id], 31, unquoted_name)
					
	get_user_authid(id,g_UserAuthID[id],31)
		
	get_user_ip(id,g_UserIP[id],31,1)
	
	g_damagedealt[id] = 0
	
	new i
	for (i = 0; i < 31; i++)
		arrayset(g_Hits[id][i], 0, 9)
	
	
	new uniqid[32]
	new whereis[10]
	new condition[40]
	
	new auth_type = get_pcvar_num(g_CvarAuthType)
	if (auth_type == 1)
	{
		copy(whereis,9,"steam_id")
		copy(uniqid,31,g_UserAuthID[id])
	}
	else
	if (auth_type == 2)
	{
		copy(whereis,9,"ip")
		copy(uniqid,31,g_UserIP[id])
	}
	else
	if (auth_type == 3)
	{
		copy(whereis,9,"nick")
		copy(uniqid,31,g_UserName[id])
	}
	else
	{
		if (equal(g_UserAuthID[id],"STEAM_0:",8))
		{
			copy(whereis,9,"steam_id")
			copy(uniqid,31,g_UserAuthID[id])
		}
		else
		{
			copy(whereis,9,"ip")
			copy(uniqid,31,g_UserIP[id])
			copy(condition, 39, " AND NOT (`steam_id` LIKE 'STEAM_0:%')")
		}
	}
	
	
	format(g_Query,charsmax(g_Query),"SELECT `id`, `ammo`, `class`, `server` FROM `zp_players` \
			LEFT JOIN `zp_server_players` \
			ON `zp_server_players`.`id_player` = `zp_players`.`id`\
			WHERE `%s`='%s' %s", whereis, uniqid, condition)
	
	new data[2]
	data[0] = id
	data[1] = get_user_userid(id)
	SQL_ThreadQuery(g_SQL_Tuple, "ClientAuthorized_QueryHandler", g_Query, data, 2)
	
#if defined ZP_STATS_DEBUG
	log_amx("[ZP] Stats Debug: client %d autorized (Name %s, IP %s, Steam ID %s)", id, g_UserName[id], g_UserIP[id], g_UserAuthID[id])
#endif

}

public client_putinserver(id)
{
	
#if defined ZP_STATS_DEBUG
	new name[32]
	get_user_name(id, name, 31)
	log_amx("[ZP] Stats Debug: client %s %d put in server (DB id %d)", name, id, g_UserDBId[id])
#endif
	if (g_UserDBId[id])
	{
		if (get_pcvar_num(g_CvarStoreAmmo))
			zp_ammopacks_set(id, g_UserAmmo[id])
		
		
		if (get_pcvar_num(g_CvarStoreClass))
			zp_class_zombie_set_next(id, g_UserClass[id])
		
		SQL_QueryAndIgnore(g_SQL_Connection, "INSERT INTO `zp_server_players` VALUES (%d, '%s')", g_UserDBId[id], g_ServerString)
		
	}
	
	g_UserPutInServer[id] = true
}

public ClientAuthorized_QueryHandler(FailState, Handle:query, error[], err, data[], size, Float:querytime)
{
	if(FailState != TQUERY_SUCCESS)
	{
		log_amx("[ZP] Stats error %d, %s", err, error)
		return
	}
	
	new id = data[0]
	
	if (data[1] != get_user_userid(id))
		return
	
	new ammo = get_pcvar_num(g_CvarStartedAmmo)
	
	new server[32]
	
	if(SQL_NumResults(query))
	{
		SQL_ReadResult(query, column("server"), server, 31)
		
		if (server[0])
		{
#if defined ZP_STATS_DEBUG
			log_amx("[ZP] Stats Debug: client %d already in the server %s!", id, server)
#endif			
			g_UserClass[id] = 0
			return
		}
		
		ammo = SQL_ReadResult(query, column("ammo"))
		g_UserDBId[id] = SQL_ReadResult(query, column("id"))
		g_UserClass[id] = SQL_ReadResult(query, column("class"))
		
	}
	else
	{
		format(g_Query,charsmax(g_Query),"INSERT INTO `zp_players` SET\
					`ammo`=%d, `total_ammo`=%d, \
					`nick`='%s',\
					`ip`='%s', `steam_id`='%s', `last_join` = %d;",
					ammo, ammo,
					g_UserName[id], g_UserIP[id], g_UserAuthID[id], g_StartTime[id])

		new Handle:queryyy = SQL_PrepareQuery(g_SQL_Connection, g_Query)
		SQL_Execute(queryyy)
		g_UserDBId[id] = SQL_GetInsertId(queryyy)
		SQL_FreeHandle(queryyy)
	}
	
	
	g_UserAmmo[id] = ammo
	
	if (g_UserPutInServer[id])
	{
		if (get_pcvar_num(g_CvarStoreAmmo))
			zp_ammopacks_set(id, g_UserAmmo[id])
		if (get_pcvar_num(g_CvarStoreClass))	
			zp_class_zombie_set_next(id, g_UserClass[id])
		SQL_QueryAndIgnore(g_SQL_Connection, "INSERT INTO `zp_server_players` VALUES (%d, '%s')", g_UserDBId[id], g_ServerString)
	}
	
#if defined ZP_STATS_DEBUG
	new name[32]
	get_user_name(id, name, 31)
	log_amx("[ZP] Stats Debug: client %s %d Query Handler (ammo %d, class %d, server %s, db id %d)", name, id, g_UserAmmo[id], g_UserClass[id], server, g_UserDBId[id])
#endif	
}

public client_disconnect(id)
{
	
	if (!g_UserDBId[id] || !g_UserPutInServer[id])	
		return
	
	
	SQL_QueryAndIgnore(g_SQL_Connection, "set profiling=1")
	
	new unquoted_name[32], name[32]
	get_user_name(id,unquoted_name,31)
	SQL_QuoteString(g_SQL_Connection , name, 31, unquoted_name)
	
	setc(g_UserName[id], 31, 0)
	
	new current_time = get_systime()
	new max_len =  charsmax(g_Query)
	
	new ammo = zp_ammopacks_get(id), max_ammo = get_pcvar_num(g_CvarLimitAmmo)
	if (max_ammo && ammo > max_ammo)
		ammo = max_ammo
		
	format(g_Query, max_len, "UPDATE `zp_players` SET \
		`ammo`=%d, `nick`='%s', \
		`total_damage`=`total_damage` + %d, `last_join`=%d, \
		`last_leave`=%d, `online` = `online` + %d, `class` = %d WHERE `id`=%d", 
		ammo, name, 
		g_TotalDamage[id], g_StartTime[id], current_time, (current_time - g_StartTime[id]), zp_class_zombie_get_next(id), g_UserDBId[id])

	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
	
	new i, len
	
	len = format(g_Query, max_len, "INSERT INTO `zp_shoots` VALUES")
			
	for (i = 1; i < 31; i++)
	{
		if (i != 4 && i != 6 && i!= 9 && i != 25 && i != 29)
		{
			if (g_Hits[id][i][0])
			{
				len += format(g_Query[len], max_len - len,
					" ('%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d'),",
					i,
					g_UserDBId[id],
					g_Hits[id][i][0], 
					g_Hits[id][i][1], 
					g_Hits[id][i][2], 
					g_Hits[id][i][3], 
					g_Hits[id][i][4], 
					g_Hits[id][i][5], 
					g_Hits[id][i][6], 
					g_Hits[id][i][7], 
					g_Hits[id][i][8], 
					g_Kills[id][i])	
			}
		}
	}
	

	g_Query[--len] = 0
	
	len += format(g_Query[len], max_len - len, " ON DUPLICATE KEY UPDATE \
		`shoot` = `shoot` + VALUES(`shoot`), \
		`hit_head` = `hit_head` + VALUES(`hit_head`),")
		
	len += format(g_Query[len], max_len - len, "`hit_chest` = `hit_chest` + VALUES(`hit_chest`), \
		`hit_stomach` = `hit_stomach` + VALUES(`hit_stomach`), \
		`hit_leftarm` = `hit_leftarm` + VALUES(`hit_leftarm`), ")
		
	len += format(g_Query[len], max_len - len, 
		"`hit_rightarm` = `hit_rightarm` + VALUES(`hit_rightarm`), \
		`hit_leftleg` = `hit_leftleg` + VALUES(`hit_leftleg`), \
		`hit_rightleg` = `hit_rightleg` + VALUES(`hit_rightleg`), \
		`hit_shield` = `hit_shield` + VALUES(`hit_shield`), \
		`kills` = `kills` + VALUES(`kills`)")
		
	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
	
	format(g_Query, max_len, "DELETE FROM `zp_server_players` WHERE `id_player` = %d", g_UserDBId[id])
	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
	
	g_UserDBId[id] = 0
	
#if defined ZP_STATS_DEBUG
	log_amx("[ZP] Stats Debug: client %s - %d disconnect, ammo %d", unquoted_name, id, ammo)
#endif
	
	new Handle:query = SQL_PrepareQuery(g_SQL_Connection, "show profiles")
	SQL_Execute(query)
	
	new Duration[20]
	while(SQL_MoreResults(query))
	{
		SQL_ReadResult(query, 1, Duration, 19)
		SQL_ReadResult(query, 2, g_Query, max_len)
		
		log_to_file("disconnect.log", "Duration %s, query %s", Duration, g_Query)
		
		SQL_NextRow(query)
	}
	
	SQL_QueryAndIgnore(g_SQL_Connection, "set profiling=0")
}

public zp_fw_core_infect_post(id, infector)
{
	new nemesis = zp_class_nemesis_get(id)
	if (infector && infector != id)
	{
		recordPlayerEvent(id, PLAYER_HAS_BEEN_INFECTED)
		
		if (g_UserDBId[infector])
		{
			recordPlayerEvent(infector, PLAYER_INFECT)
			g_Me[infector][ME_INFECT]++
		}
		
		g_graphInfect++
			
	}
	else if (!nemesis)
	{
		if (zp_core_is_first_zombie(id))
			recordPlayerEvent(id, PLAYER_FIRST_ZOMBIE)
	}
	else
		recordPlayerEvent(id, PLAYER_HAS_BEEN_NEMESIS)
}

public zp_fw_core_cure_post(id, attacker)
{
	new survivor = zp_class_survivor_get(id)
	if (survivor)
		recordPlayerEvent(id, PLAYER_HAS_BEEN_SURV)
}

public zp_fw_gamemodes_end(game_mode_id)
{
	if (get_playersnum())
	{
		new winTeam = WIN_NO_ONE
		if (zp_core_get_zombie_count())
			winTeam = WIN_ZOMBIES
		else
		if (zp_core_get_human_count())
			winTeam = WIN_HUMANS

		format(g_Query, charsmax(g_Query), "UPDATE `zp_maps` SET `%s` = `%s` + 1 WHERE `map` = '%s'", g_win_team[winTeam], g_win_team[winTeam], g_mapname)
		SQL_ThreadQuery(g_SQL_Tuple, "threadQueryHandler", g_Query)
		
		if (get_pcvar_num(g_CvarShowBest))
		{
			new players[32], playersNum, i, maxInfectId = 0, maxDmgId = 0, maxKillsId = 0
			new message[200], len
			new maxInfectName[32], maxDmgName[32], maxKillsName[32]
			get_players(players, playersNum, "ch")
			for (i = 0; i < playersNum; i++)
			{
				if (g_Me[players[i]][ME_INFECT] > g_Me[players[maxInfectId]][ME_INFECT])
					maxInfectId = i
				if (g_Me[players[i]][ME_DMG] > g_Me[players[maxDmgId]][ME_DMG])
					maxDmgId = i
				if (g_Me[players[i]][ME_KILLS] > g_Me[players[maxKillsId]][ME_KILLS])
					maxKillsId = i	
			}
			get_user_name(players[maxInfectId], maxInfectName, 31)
			get_user_name(players[maxDmgId], maxDmgName, 31)
			get_user_name(players[maxKillsId], maxKillsName, 31)
			
			if (g_Me[players[maxInfectId]][ME_INFECT] || 
				g_Me[players[maxKillsId]][ME_KILLS] ||
				g_Me[players[maxDmgId]][ME_DMG])
			{
				for (i = 0; i < playersNum; i++)
				{
					len = format(message, charsmax(message), "%L", players[i], "BEST_TITLE")
					if (g_Me[players[maxInfectId]][ME_INFECT])
						len += format(message[len], charsmax(message) - len, 
							"^n%L", players[i], "BEST_INFECT", 
							maxInfectName, g_Me[players[maxInfectId]][ME_INFECT])
					
					if (g_Me[players[maxKillsId]][ME_KILLS])
						len += format(message[len], charsmax(message) - len, 
							"^n%L", players[i], "BEST_KILLS", 
							maxKillsName, g_Me[players[maxKillsId]][ME_KILLS])
					
					if (g_Me[players[maxDmgId]][ME_DMG])
						len += format(message[len], charsmax(message) - len, 
							"^n%L", players[i], "BEST_DMG", 
							maxDmgName, g_Me[players[maxDmgId]][ME_DMG])
									
					set_hudmessage(100, 200, 0, 0.05, 0.55, 0, 0.02, 6.0, 0.0, 1.0)
					show_hudmessage(players[i], message)
				}
			}
		}
	}
	update_zp_graph()
}

public fw_HamKilled(id, attacker, shouldgib)
{
	if (is_user_alive(attacker) && g_UserDBId[attacker])
	{
		if (is_user_connected(attacker))
		{
			g_Killers[id][KILLER_ID] = attacker
			g_Killers[id][KILLER_HP] = get_user_health(attacker)
			g_Killers[id][KILLER_ARMOUR] = get_user_armor(attacker)
			g_Me[attacker][ME_KILLS] ++
		}
	}
	
	g_graphKills++
	
	new type = PLAYER_BAD_EVENT, player = attacker
	
	recordPlayerEvent(id, PLAYER_DEATH)

	if (id == attacker || !is_user_connected(attacker))
	{
		type = PLAYER_SUICIDE
		player = id
	}
	else
	if (zp_core_is_zombie(attacker))
	{
		if (zp_class_survivor_get(id))
			type = PLAYER_KILL_SURV
		else
			type = PLAYER_KILL_HUMAN
	}
	else
	{
		if (zp_class_nemesis_get(id))
			type = PLAYER_KILL_NEMESIS
		else if (g_UserDBId[id])
			type = PLAYER_KILL_ZOMBIE
	}
	
	if ((type == PLAYER_KILL_HUMAN || type == PLAYER_KILL_ZOMBIE) && g_UserDBId[attacker])
		g_Kills[attacker][g_Weapon[attacker]]++
	
	recordPlayerEvent(player, type)
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if (victim == attacker || !is_user_alive(attacker) || !is_user_connected(victim))
		return
	
	g_graphDamage += floatround(damage)
	
	
	if (get_pcvar_num(g_CvarShowHit))
			
	
	if (is_user_alive(attacker) && g_UserDBId[attacker])
		g_TotalDamage[attacker] += floatround(damage)
		
	if (!get_pcvar_num(g_CvarShowHit))
		return
	
	new victim_hp = get_user_health(victim)
	new armor = get_user_armor(victim)
	if (victim_hp < 0)
		victim_hp = 0
	
	if (zp_core_is_zombie(victim) || armor <= 0)
		client_print(attacker, print_center, "%L", attacker, "HP_INDICATOR", victim_hp)
	else
		client_print(attacker, print_center, "%L", attacker, "ARMOR_INDICATOR", armor)
}

public fw_CS_RoundRespawn(id)
{
	new i
	for (i = 0; i < KILLER_NUM; i++)
		g_Killers[id][i] = 0
	for (i = 0; i < ME_NUM; i++)
		g_Me[id][i] = 0
	
}

public fw_TraceAttack(id, idattacker, Float:damage, Float:direction[3], traceresult, damagebits)
{
	if (is_user_alive(idattacker) && g_UserDBId[idattacker])
	{
		new hit = get_tr2(traceresult, TR_iHitgroup)
		g_Hits[idattacker][g_Weapon[idattacker]][hit] ++
		g_Me[idattacker][ME_DMG] += floatround(damage)
		g_Me[idattacker][ME_HIT] = hit
	}
}

public update_zp_graph()
{	
	new current_time = get_systime()
	new bdTime = current_time - (current_time % 3600)
	format(g_Query, charsmax(g_Query), "INSERT INTO `zp_graph` \
		VALUES('%d', '%d', '%d', '%d', '%d') \
		ON DUPLICATE KEY UPDATE \
		`connections` = `connections` + VALUES(`connections`), \
		`kills` = `kills` + VALUES(`kills`), \
		`infects` = `infects` + VALUES(`infects`), \
		`damage` = `damage` + VALUES(`damage`)", 
		bdTime, g_graphConnections, g_graphKills, g_graphInfect, g_graphDamage)
	SQL_ThreadQuery(g_SQL_Tuple, "threadQueryHandler", g_Query)
	
	g_graphConnections = 0
	g_graphKills = 0
	g_graphInfect = 0
	g_graphDamage = 0
}


public msgCurWeapon(msgid, dest, id)
{
	if (get_msg_arg_int(1))
	{
		static wId, ammo
		wId = get_msg_arg_int(2)
		ammo = get_msg_arg_int(3)
		g_Weapon[id] = wId
		switch(wId)
		{
			case CSW_KNIFE:
			{
				g_OldWeapon[id] = wId 
				return PLUGIN_CONTINUE
			}
			case CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE, CSW_C4: 
				return PLUGIN_CONTINUE
		}
		if (wId == g_OldWeapon[id] && g_OldAmmo[id] > ammo)
		{
			if (wId == CSW_XM1014)
				g_Hits[id][wId][0]+=6
			else
			if (wId == CSW_M3)
				g_Hits[id][wId][0]+=9
			else
				g_Hits[id][wId][0]++
		}
		g_OldWeapon[id] = wId
		g_OldAmmo[id] = ammo
	}
	return PLUGIN_CONTINUE
}

public handleSay(id)
{
	new args[64]
	
	read_args(args, charsmax(args))
	remove_quotes(args)
	
	new arg1[16]
	new arg2[32]
	
	strbreak(args, arg1, charsmax(arg1), arg2, charsmax(arg2))
	if (get_pcvar_num(g_CvarAllowHp) && equal(arg1,"/hp"))
		show_hp(id)
	else
	if (get_pcvar_num(g_CvarAllowMe) && equal(arg1,"/me"))
		show_me(id)	
	else
	if (equal(arg1,"/rank"))
		show_rank(id,arg2)
	else
	if (equal(arg1, "/rankstats") || equal(arg1, "/stats"))
		show_stats(id, arg2)
	else
	if (equal(arg1,"/top", 4))
	{
		if (arg1[4])
			show_top(id, str_to_num(arg1[4]))
		else
			show_top(id, 15)
	}
	else
	if (get_pcvar_num(g_CvarAllowDonate) && equal(arg1,"/donate", 7))
		donate(id, arg2)
	
}

public donate(id, arg[])
{
	new to[32], count[10]
	strbreak(arg, to, 31, count, 9)
	
	if (!to[0] || !count[0])
	{
		client_print(id, print_chat, "%L", id, "DONATE_USAGE")
		return
	}
	new ammo_sender = zp_ammopacks_get(id)
	new ammo
	if (equal(count, "all"))
		ammo = ammo_sender
	else
		ammo = str_to_num(count)
	if (ammo <= 0)
	{
		client_print(id, print_chat, "%L", id, "INVALID_AMMO")
		return
	}
	ammo_sender -= ammo
	if (ammo_sender < 0)
	{
		ammo+=ammo_sender
		ammo_sender = 0
		
	}
	new reciever = cmd_target(id, to, (CMDTARGET_OBEY_IMMUNITY|CMDTARGET_ALLOW_SELF))
	if (!reciever || reciever == id)
	{
		client_print(id, print_chat, "%L", id, "CLIENT_NOT_FOUND", to)
		return
	}
	
	zp_ammopacks_set(reciever, zp_ammopacks_get(reciever) + ammo)
	zp_ammopacks_set(id, ammo_sender)
	new aName[32], vName[32]
	
	get_user_name(id, aName, 31)
	get_user_name(reciever, vName, 31)
	
	set_hudmessage(255, 0, 0, -1.0, 0.3, 0, 6.0, 6.0)
	show_hudmessage(id, "%L", id, "DONATE", aName, ammo, vName)
	
}

public show_hp(id)
{
	if (g_Killers[id][KILLER_ID])
	{
		new name[32]
		get_user_name(g_Killers[id][KILLER_ID], name, 31)
		client_print(id, print_chat, "%L", id, "HP_MESSAGE",
			name, g_Killers[id][KILLER_HP],
			g_Killers[id][KILLER_ARMOUR])
		
	}
	else
		client_print(id, print_chat, "%L", id, "HP_NO_KILLER")
}

public show_me(id)
{
	if (g_Me[id][ME_DMG] || g_Me[id][ME_KILLS] || g_Me[id][ME_INFECT])
	{
		new hit[32]
		format(hit, 31, "%L", id, g_HitsName[g_Me[id][ME_HIT]])
		client_print(id, print_chat, "%L", id, "ME_MESSAGE", g_Me[id][ME_INFECT], g_Me[id][ME_KILLS], g_Me[id][ME_DMG], hit)
	}
	else
		client_print(id, print_chat, "%L", id, "HIT_NONE")
}

public show_rank(id, unquoted_whois[])
{
	
	new whois[1024]
	SQL_QuoteString(g_SQL_Connection , whois, 1023, unquoted_whois)
	
	new total_ammo, infect
	new death, rank, total
	
	new name[32]
	
	new activity = get_systime() - get_pcvar_num(g_CvarMaxInactive) * 24 * 60 * 60
	new min_ammo = get_pcvar_num(g_CvarMinAmmo)
	new min_online = get_pcvar_num(g_CvarMinOnline) * 60
	
	format(g_Query, charsmax(g_Query), "SET @_c = 0")
	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
	
	new Handle:query
	
	if (!whois[0])
	{
		format(g_Query, charsmax(g_Query), "SELECT *,(SELECT COUNT(*) FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d) AS `total` FROM \
			(SELECT *, (@_c := @_c + 1) AS `rank`, \
			((`infect` + `zombiekills` + `humankills` + `nemkills`*4 + `survkills`*4)/(`suicide`*4+`death`+`infected` + 1)) AS `skill` ",
			activity, min_ammo, min_online)
		query = SQL_PrepareQuery(g_SQL_Connection, "%s FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d \
			ORDER BY `skill` DESC) AS `newtable` WHERE `id`='%d';", 
			g_Query, activity, min_ammo, min_online, g_UserDBId[id])
		
	}
	else
	{
		format(g_Query, charsmax(g_Query), "SELECT *,(SELECT COUNT(*) FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d) AS `total` FROM \
			(SELECT *, (@_c := @_c + 1) AS `rank`, \
			((`infect` + `zombiekills` + `humankills` + `nemkills`*4 + `survkills`*4)/(`suicide`*4+`death`+`infected` + 1)) AS `skill` ",
			activity, min_ammo, min_online)
		query = SQL_PrepareQuery(g_SQL_Connection, "%s FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d ORDER BY `skill` DESC) AS `newtable` \
			WHERE `nick` LIKE '%%%s%%' OR `ip` LIKE '%%%s%%' \
			LIMIT 1", 
			g_Query, activity, min_ammo, min_online, whois, whois)
	
	}
	
	SQL_Execute(query)
	
	if (SQL_MoreResults(query))
	{
	
		total_ammo = SQL_ReadResult(query, column("total_ammo"))
		SQL_ReadResult(query, column("nick"), name, 31)
		infect = SQL_ReadResult(query, column("infect"))
		death = SQL_ReadResult(query, column("death"))
		rank = SQL_ReadResult(query, column("rank"))
		total = SQL_ReadResult(query, column("total"))
			
		client_print(id, print_chat, "%L", id, "RANK",  name, rank, total, infect, death, total_ammo)
	} 
	else
		client_print(id, print_chat, "%L", id, "NOT_RANKED", whois)
			
	SQL_FreeHandle(query)
}

public show_stats(id, unquoted_whois[])
{
	
	new total_ammo, infect, zombiekills, nemkills, humankills, damage, online
	new survkills, death, infected, rank, total, Float:skill, first_zombie, join, leave, suicide
	new survivor, nemesis
	
	
	new whois[1024]
	SQL_QuoteString(g_SQL_Connection , whois, 1023, unquoted_whois)
	
	new name[32], ip[32], steam_id[32]
	
	new len
	
	new join_str[32], leave_str[32], time_str[64]
	
	new activity = get_systime() - get_pcvar_num(g_CvarMaxInactive) * 24 * 60 * 60
	new min_ammo = get_pcvar_num(g_CvarMinAmmo)
	new min_online = get_pcvar_num(g_CvarMinOnline)	* 60	
			
	format(g_Query, charsmax(g_Query), "SET @_c = 0")
	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
	
	new Handle:query	
	if (!whois[0])
	{
		format(g_Query, charsmax(g_Query), "SELECT *,(SELECT COUNT(*) FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d) AS `total` FROM \
			(SELECT *, (@_c := @_c + 1) AS `rank`, \
			((`infect` + `zombiekills` + `humankills` + `nemkills`*4 + `survkills`*4)/(`suicide`*4+`death`+`infected` + 1)) AS `skill` ",
			activity, min_ammo, min_online)
		query = SQL_PrepareQuery(g_SQL_Connection, "%s FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d \
			ORDER BY `skill` DESC) AS `newtable` WHERE `id`='%d';", 
			g_Query, activity, min_ammo, min_online, g_UserDBId[id])
	}
	else
	{
		format(g_Query, charsmax(g_Query), "SELECT *,(SELECT COUNT(*) FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d) AS `total` FROM \
			(SELECT *, (@_c := @_c + 1) AS `rank`, \
			((`infect` + `zombiekills` + `humankills` + `nemkills`*4 + `survkills`*4)/(`suicide`*4+`death`+`infected` + 1)) AS `skill` ",
			activity, min_ammo, min_online)
		query = SQL_PrepareQuery(g_SQL_Connection, "%s FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d ORDER BY `skill` DESC) AS `newtable` \
			WHERE `nick` LIKE '%%%s%%' OR `ip` LIKE '%%%s%%' \
			LIMIT 1", 
			g_Query, activity, min_ammo, min_online, whois, whois)
	}
	SQL_Execute(query)
	
	if (SQL_MoreResults(query))
	{
	
		total_ammo = SQL_ReadResult(query, column("total_ammo"))
		SQL_ReadResult(query, column("nick"), name, 31)
		SQL_ReadResult(query, column("ip"), ip, 31)
		SQL_ReadResult(query, column("steam_id"), steam_id, 31)
		damage = SQL_ReadResult(query, column("total_damage"))
		join = SQL_ReadResult(query, column("last_join"))
		leave = SQL_ReadResult(query, column("last_leave"))
		first_zombie = SQL_ReadResult(query, column("first_zombie"))
		infect = SQL_ReadResult(query, column("infect"))
		zombiekills = SQL_ReadResult(query, column("zombiekills"))
		humankills = SQL_ReadResult(query, column("humankills"))
		nemkills = SQL_ReadResult(query, column("nemkills"))
		survkills = SQL_ReadResult(query, column("survkills"))
		suicide = SQL_ReadResult(query, column("suicide"))
		death = SQL_ReadResult(query, column("death"))
		infected = SQL_ReadResult(query, column("infected"))
		online = SQL_ReadResult(query, column("online"))
		survivor = SQL_ReadResult(query, column("survivor"))
		nemesis = SQL_ReadResult(query, column("nemesis"))
		rank = SQL_ReadResult(query, column("rank"))
		SQL_ReadResult(query, column("skill"), skill)		
		total = SQL_ReadResult(query, column("total"))
		
		replace_all(name, 32, ">", "gt;")
		replace_all(name, 32, "<", "lt;")
		
		new lStats[32]
		format(lStats, 31, "%L", id, "STATS")
		new lRank[32]
		format(lRank, 31, "%L", id, "RANK_STATS")
		new lInfect[32]
		format(lInfect, 31, "%L", id, "INFECT_STATS")
		new lZKills[32]
		format(lZKills, 31, "%L", id, "ZKILLS_STATS")
		new lHKills[32]
		format(lHKills, 31, "%L", id, "HKILLS_STATS")
		new lNKills[32]
		format(lNKills, 31, "%L", id, "NKILLS_STATS")
		new lSKills[32]
		format(lSKills, 31, "%L", id, "SKILLS_STATS")
		new lDeath[32]
		format(lDeath, 31, "%L", id, "DEATH")
		new lInfected[32]
		format(lInfected, 31, "%L", id, "INFECTED")
		new lTotalAmmo[32]
		format(lTotalAmmo, 31, "%L", id, "TOTALAMMO")
		new lTotalDamage[32]
		format(lTotalDamage, 31, "%L", id, "TOTALDAMAGE")
		new lFirstZombie[32]
		format(lFirstZombie, 31, "%L", id, "FIRST_ZOMBIE")
		new lSuicide[32]
		format(lSuicide, 31, "%L", id, "SUICIDE")
		new lLastGame[32]
		format(lLastGame, 31, "%L", id, "LAST_GAME")
		new lOnline[32]
		format(lOnline, 31, "%L", id, "ONLINE")
		new lSurvivor[32]
		format(lSurvivor, 31, "%L", id, "SURVIVOR")
		new lNemesis[32]
		format(lNemesis, 31, "%L", id, "NEMESIS")
			
		new max_len = charsmax(g_text)
		len = format(g_text, max_len, "<html><head><meta http-equiv=^"Content-Type^" content=^"text/html; charset=utf-8^" /></head><body bgcolor=#000000>")
		len += format(g_text[len], max_len - len, "%s %s:<table style=^"color: #FFB000^"><tr><td>%s</td><td>%d/%d</td></tr><tr><td>%s</td><td>%d</td>",
			lStats, name, lRank, rank, total, lInfect, infect)
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%d</td></tr><tr><td>%s</td><td>%d</td></tr>",
			lZKills, zombiekills, lHKills, humankills)
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%d</td></tr><tr><td>%s</td><td>%d</td></tr>",
			lNKills, nemkills, lSKills, survkills)
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%d</td></tr><tr><td>%s</td><td>%d</td></tr>",
			lDeath, death, lInfected, infected)
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%d</td></tr><tr><td>%s</td><td>%d</td></tr>",
			lTotalAmmo, total_ammo, lTotalDamage, damage)
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%d</td></tr><tr><td>%s</td><td>%d</td></tr>",
			lFirstZombie, first_zombie, lSuicide, suicide)
		
		format_time(join_str, 32, "%c", join) 	
		format_time(leave_str, 32, "%c", leave) 	
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%s - %s</td></tr>",
			lLastGame, join_str, leave_str)
		
		
		get_time_length(0, online, timeunit_seconds, time_str, 63)
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%s</td></tr>",
			lOnline, time_str)
		
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%s</td></tr><tr><td>%s</td><td>%s</td></tr>",
			"IP", ip, "Steam ID", steam_id)
		
		len += format(g_text[len], max_len - len, "<tr><td>%s</td><td>%d</td></tr><tr><td>%s</td><td>%d</td></tr>",
			lSurvivor, survivor, lNemesis, nemesis)
		
		len += format(g_text[len], max_len - len, "</table></body></html>")
			
		show_motd(id, g_text, "Stats")
		
		setc(g_text, max_len, 0)
	} 
	else
		client_print(id, print_chat, "%L", id, "NOT_RANKED", whois)
			
	SQL_FreeHandle(query)
}

public show_top(id, top)
{
	new count, Handle:query
	new len
	
	new zombiekills, humankills, death, infected, infect, total_ammo, name[32], rank
	
	new activity = get_systime() - get_pcvar_num(g_CvarMaxInactive) * 24 * 60 * 60
	new min_ammo = get_pcvar_num(g_CvarMinAmmo)
	new min_online = get_pcvar_num(g_CvarMinOnline) * 60
	
	new max_len = charsmax(g_text)
		
	query = SQL_PrepareQuery(g_SQL_Connection, "SELECT COUNT(*) FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d", activity, min_ammo, min_online)
	SQL_Execute(query)
	if(SQL_MoreResults(query))
		count = SQL_ReadResult(query, 0)
	else
	{
		client_print(id, print_chat, "%L", id, "STATS_NULL")
		return
	}
	
	new lTop[32]
	format(lTop, 31, "%L", id, "TOP")
	
	new lLooserTop[32]
	format(lLooserTop, 31, "%L", id, "TOP_LOOSERS")
	
	new title[32]
	if (top <= 15)
		format(title, 31, "%s %d", lTop, top)
	else
	if (top < count)
		format(title, 31, "%s %d - %d", lTop, top - 14, top)
	else
	{
		top = count
		format(title, 31, "%s", lLooserTop)
	}
	
	setc(g_text, max_len, 0)
	
	format(g_Query, charsmax(g_Query), "SET @_c = 0")
	SQL_QueryAndIgnore(g_SQL_Connection, g_Query)
	
	query = SQL_PrepareQuery(g_SQL_Connection, "SELECT `nick`, `zombiekills`, `humankills`, \
			`infect`, `death`, `infected`, `total_ammo`, `rank` FROM \
			(SELECT *, (@_c := @_c + 1) AS `rank`, \
			((`infect` + `zombiekills` + `humankills` + `nemkills`*4 + `survkills`*4)/(`suicide`*4+`death`+`infected` + 1)) AS `skill` \
			FROM `zp_players` WHERE `last_join` > %d AND `total_ammo` >= %d AND `online` >= %d \
			ORDER BY `skill` DESC) AS `newtable` WHERE `rank` <= '%d' ORDER BY `rank` DESC LIMIT 15", 
			activity, min_ammo, min_online, top)
			
	SQL_Execute(query)
	
	while (SQL_MoreResults(query))
	{
		SQL_ReadResult(query, column("nick"), name, 31)
		zombiekills = SQL_ReadResult(query, column("zombiekills"))
		humankills = SQL_ReadResult(query, column("humankills"))
		infect = SQL_ReadResult(query, column("infect"))
		death = SQL_ReadResult(query, column("death"))
		infected = SQL_ReadResult(query, column("infected"))
		total_ammo = SQL_ReadResult(query, column("total_ammo"))
		rank = SQL_ReadResult(query, column("rank"))
		
		format(g_text, max_len, "<tr><td>%d<td>%s<td>%d<td>%d<td>%d<td>%d<td>%d<td>%d%s",
			rank, name, zombiekills, humankills, infect, death, infected, total_ammo, g_text)
		
		SQL_NextRow(query)
	}
	
	SQL_FreeHandle(query)
	
	new lInfect[32]
	format(lInfect, 31, "%L", id, "INFECT_STATS")
	new lZKills[32]
	format(lZKills, 31, "%L", id, "ZKILLS_STATS")
	new lHKills[32]
	format(lHKills, 31, "%L", id, "HKILLS_STATS")
	new lDeath[32]
	format(lDeath, 31, "%L", id, "DEATH")
	new lInfected[32]
	format(lInfected, 31, "%L", id, "INFECTED")
	new lTotalAmmo[32]
	format(lTotalAmmo, 31, "%L", id, "TOTALAMMO")
	new lNick[32]
	format(lNick, 31, "%L", id, "NICK")
	
	len = format(g_text, max_len, "<html><head><meta http-equiv=^"Content-Type^" content=^"text/html; charset=utf-8^" /></head><body bgcolor=#000000><table style=^"color: #FFB000^"><tr><td>%s<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s%s","#", lNick, lZKills, lHKills, lInfect, lDeath, lInfected, lTotalAmmo, g_text)
	format(g_text[len], max_len - len, "</table></body></html>")	
	
	show_motd(id, g_text, title)
	
	setc(g_text, max_len, 0)
}

public threadQueryHandler(FailState, Handle:Query, error[], err, data[], size, Float:querytime)
{
	static queryString[2014]
	SQL_GetQueryString(Query, queryString, charsmax(queryString))
	log_amx("TQUERY FINISH %s", queryString)
	if(FailState != TQUERY_SUCCESS)
	{
		log_amx("[ZP] Stats: sql error: %d (%s)", err, error)
		return
	}
		
}

recordPlayerEvent(id, event, count = 1)
{
	static const eventTypes[][] = {
		"",
		"first_zombie", 
		"infect", 
		"infected", 
		"nemesis", 
		"survivor",
		"zombiekills", 
		"humankills", 
		"nemkills", 
		"survkills", 
		"death",
		"suicide"
	}

	if (!g_UserDBId[id])
		return

	if (event <= 0 || event >= sizeof eventTypes)
	{
		log_amx("[ZP STATS] Bad event type!")
		return
	}
	
	format(g_Query, charsmax(g_Query), "UPDATE `zp_players` SET `%s` = `%s` + %d WHERE `id` = %d", 
		eventTypes[event], eventTypes[event], count, g_UserDBId[id])
	SQL_ThreadQuery(g_SQL_Tuple, "threadQueryHandler", g_Query)	
}
