#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <geoip>

public Plugin myinfo =
{
	name = "[CSGO] Advanced Admin",
	author = "PeEzZ.[edit Cruze]", // Farbror Godis for curse command's code
	description = "Advanced commands for admins.",
	version = "2.1",
	url = "https://forums.alliedmods.net/showthread.php?t=285493"
};

#define CMD_PREFIX		"[SM] " //Prefix in admin activity messages
#define ROOT_PREFIX		"[R]" //Root admin's (ADMFLAG_ROOT) prefix in the !admins command, [R] is the default
#define ADMIN_PREFIX	"" //Simple admin's (ADMFLAG_GENERIC) prefix in the !admins command, [A] is the old

#define MODEL_CHICKEN "models/chicken/chicken.mdl"
#define MODEL_CHICKEN_ZOMBIE "models/chicken/chicken_zombie.mdl"
#define MODEL_BALL "models/props/de_dust/hr_dust/dust_soccerball/dust_soccer_ball001.mdl"

#define SOUND_RESPAWN "player/pl_respawn.wav" //Teleport and respawn sound, leave blank to disable
#define SOUND_CHICKEN "ambient/creatures/chicken_panic_03.wav" //Chicken spawn sound, leave blank to disable
#define SOUND_BURY "physics/concrete/boulder_impact_hard4.wav" //Bury sound, leave blank to disable

Handle CVAR_ADMINS = INVALID_HANDLE;
Handle CVAR_ANNOUNCE = INVALID_HANDLE;
Handle CVAR_SILENTADMINTEAMJOIN = INVALID_HANDLE;
Handle CVAR_INVALID = INVALID_HANDLE;
Handle CVAR_LOG = INVALID_HANDLE;
Handle CVAR_HealthRest;

float SaveVec[MAXPLAYERS + 1][2][3];

bool g_toggle[MAXPLAYERS+1];
bool g_toggle2[MAXPLAYERS+1];

char WeaponsList[][] = //VALID WEAPON NAMES HERE
{
	"c4", "knife", "knifegg", "taser", "healthshot", //misc
	"decoy", "flashbang", "hegrenade", "molotov", "incgrenade", "smokegrenade", "tagrenade", //grenades
	"usp_silencer", "glock", "tec9", "p250", "hkp2000", "cz75a", "deagle", "revolver", "fiveseven", "elite", //pistoles
	"nova", "xm1014", "sawedoff", "mag7", "m249", "negev", //heavy
	"mp9", "mp7", "ump45", "p90", "bizon", "mac10", "mp5sd", //smgs
	"ak47", "aug", "famas", "sg556", "galilar", "m4a1", "m4a1_silencer", //rifles
	"awp", "ssg08", "scar20", "g3sg1" //snipers
};
char ItemsList[][] = //VALID ITEM NAMES HERE, HEAVYASSAULTSUIT ONLY WORKS WHEN ITS ENABLED (mp_max_armor 3)
{
	"defuser", "cutters", //defuser and rescue kit
	"kevlar", "assaultsuit", "heavyassaultsuit", //armors
	"nvgs" //nightvision
};

public void OnPluginStart()
{
	CVAR_ADMINS					= 	CreateConVar("sm_advadmin_admins",		"2",			"Settings of !admins command, 0 - disable, 1 - show fake message, 2 - show online admins", _, true, 0.0, true, 2.0);
	CVAR_ANNOUNCE					=	CreateConVar("sm_advadmin_announce",		"2",			"Join announce, 0 - disable, 1 - simple announce, 2 - announce with country name, 3 = no admin annouce", _, true, 0.0, true, 3.0);
	CVAR_SILENTADMINTEAMJOIN		=	CreateConVar("sm_advadmin_noteamjoinmsg",	"1",			"No Team join message for admin, 0 = disable, 1 = enable", _, true, 0.0, true, 1.0);
	CVAR_INVALID					= 	CreateConVar("sm_advadmin_invalid",		"1",			"Invalid given item will show for all players just for fun, 0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
	CVAR_LOG						= 	CreateConVar("sm_advadmin_log",			"1",			"Enable logging for plugin, 0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
	CVAR_HealthRest				=	CreateConVar("sm_advadmin_healthrest",	"1",			"Restrict health's value >= 0? (because Setting the health to 0 stops the player from any movement in CSGO) ", _, true, 0.0, true, 1.0);
	
	//-----//
	RegAdminCmd("sm_extend",		CMD_Extend,		ADMFLAG_CHANGEMAP,	"Extending the map");
	RegAdminCmd("sm_clearmap",		CMD_ClearMap,		ADMFLAG_GENERIC,	"Deleting dropped weapons, items and chickens without owner from the map");
	RegAdminCmd("sm_restartgame",	CMD_RestartGame,	ADMFLAG_GENERIC,	"Restarting the game after the specified seconds");
	RegAdminCmd("sm_rg",			CMD_RestartGame,	ADMFLAG_GENERIC,	"Restarting the game after the specified seconds");
	RegAdminCmd("sm_restartround",	CMD_RestartRound,	ADMFLAG_GENERIC,	"Restarting the round after the specified seconds");
	RegAdminCmd("sm_rr",			CMD_RestartRound,	ADMFLAG_GENERIC,	"Restarting the round after the specified seconds");
	RegAdminCmd("sm_equipments",	CMD_Equipments,	ADMFLAG_GENERIC,	"Showing the valid equipment names in the console");
	RegAdminCmd("sm_playsound",	CMD_PlaySound,	ADMFLAG_GENERIC,	"Playing a sound for the targets, with custom settings");
	//-----//
	RegAdminCmd("sm_teleport",		CMD_Teleport,		ADMFLAG_BAN,		"Teleporting the target to something");
	RegAdminCmd("sm_tele",			CMD_Teleport,		ADMFLAG_BAN,		"Teleporting the target to something");
	RegAdminCmd("sm_saveloc",		CMD_SaveVec,		ADMFLAG_BAN,		"Saving the current position for the teleport");
	RegAdminCmd("sm_savevec",		CMD_SaveVec,		ADMFLAG_BAN,		"Saving the current position for the teleport");
	//-----//
	RegAdminCmd("sm_team",			CMD_Team,			ADMFLAG_KICK,		"Set the targets team");
	RegAdminCmd("sm_swap",			CMD_Swap,			ADMFLAG_KICK,		"Swap the targets team");
	RegAdminCmd("sm_spec",			CMD_Spec,			ADMFLAG_KICK,		"Set the targets team to spectator");
	RegAdminCmd("sm_scramble",		CMD_Scramble,		ADMFLAG_KICK,		"Scramble the teams by scores");
	//-----//
	RegAdminCmd("sm_give",			CMD_Give,			ADMFLAG_BAN,		"Give something for the targets");
	RegAdminCmd("sm_equip",		CMD_Equip,			ADMFLAG_BAN,		"Equipping something for the targets");
	RegAdminCmd("sm_disarm",		CMD_Disarm,		ADMFLAG_BAN,		"Disarming the targets");
	//-----//
	RegAdminCmd("sm_respawn",		CMD_Respawn,		ADMFLAG_KICK,		"Respawning the targets");
	RegAdminCmd("sm_bury",			CMD_Bury,			ADMFLAG_KICK,		"Burying the targets");
	RegAdminCmd("sm_unbury",		CMD_UnBury,		ADMFLAG_KICK,		"Unburying the targets");
	//-----//
	RegAdminCmd("sm_speed",		CMD_Speed,			ADMFLAG_BAN,		"Set the speed multipiler of the targets");
	RegAdminCmd("sm_god",			CMD_God,			ADMFLAG_BAN,		"Set godmode for the targets");
	RegAdminCmd("sm_helmet",		CMD_Helmet,		ADMFLAG_KICK,		"Set helmet for the targets");
	//-----//
	RegAdminCmd("sm_hp",			CMD_Health,		ADMFLAG_KICK,		"Set the health for the targets");
	RegAdminCmd("sm_health",		CMD_Health,		ADMFLAG_KICK,		"Set the health for the targets");
	RegAdminCmd("sm_armor",		CMD_Armor,			ADMFLAG_KICK,		"Set the armor for the targetsr");
	RegAdminCmd("sm_cash",			CMD_Cash,			ADMFLAG_BAN,		"Set the cash for the targets");
	//-----//
	RegAdminCmd("sm_setstats",		CMD_SetStats,		ADMFLAG_BAN,		"Set the stats for the targets");
	RegAdminCmd("sm_teamscores",	CMD_TeamScores,	ADMFLAG_BAN,		"Set the teams scores");
	//-----//
	RegAdminCmd("sm_spawnchicken",	CMD_SpawnChicken,	ADMFLAG_GENERIC,	"Spawn one chicken on your aim position");
	RegAdminCmd("sm_sc",			CMD_SpawnChicken,	ADMFLAG_GENERIC,	"Spawn one chicken on your aim position");
	RegAdminCmd("sm_spawnball",	CMD_SpawnBall,	ADMFLAG_GENERIC,	"Spawn one ball on your aim position");
	RegAdminCmd("sm_curse", 		CMD_CURSE, 		ADMFLAG_SLAY, 		"sm_curse <#userid|name> [0/1]");
	
	RegConsoleCmd("sm_admins",	CMD_Admins,							"Showing the online admins");
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
	
	LoadTranslations("common.phrases");
	LoadTranslations("advadmin.phrases");
}
public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(g_toggle2[iClient]) 
	{
		vel[1] = -vel[1]; // Will always equal to the opposite value, according to rules of arithmetic.
			
		if(buttons & IN_MOVELEFT) // Fixes walking animations for CS:GO.
		{ 
			buttons &= ~IN_MOVELEFT;
			buttons |= IN_MOVERIGHT;
		} 
		else if(buttons & IN_MOVERIGHT) 
		{
			buttons &= ~IN_MOVERIGHT;
			buttons |= IN_MOVELEFT;
		}
		vel[0] = -vel[0];

		if(buttons & IN_FORWARD) 
		{
			buttons &= ~IN_FORWARD;
			buttons |= IN_BACK;
		} 
		else if(buttons & IN_BACK) 
		{
			buttons &= ~IN_BACK;
			buttons |= IN_FORWARD;
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	g_toggle2[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    for(int z = 1; z <= MaxClients; z++)
    {
        if(IsClientInGame(z) && GetConVarBool(CVAR_SILENTADMINTEAMJOIN))
        {
			if(GetUserAdmin(z) != INVALID_ADMIN_ID)
			{
				event.SetBool("silent", true); //Thanks Ilusion9
			}
		}
	}
}
public void OnMapStart()
{
	if(!StrEqual(SOUND_RESPAWN, "", false))
	{
		PrecacheSound(SOUND_RESPAWN, true);
	}
	if(!StrEqual(SOUND_BURY, "", false))
	{
		PrecacheSound(SOUND_BURY, true);
	}
	if(!StrEqual(SOUND_CHICKEN, "", false))
	{
		PrecacheSound(SOUND_CHICKEN, true);
	}
	
	PrecacheModel(MODEL_CHICKEN, true);
	PrecacheModel(MODEL_CHICKEN_ZOMBIE, true);
	PrecacheModel(MODEL_BALL, true);
}

//-----CLIENT_AUTHORIZED-----//
public void OnClientAuthorized(int client, const char[] auth)
{
	int announce = GetConVarInt(CVAR_ANNOUNCE);
	if(announce > 0)
	{
		char IP[64], country[64];
		
		if((announce) == 1)
		{
			PrintToChatAll("%t", "Player_Connected", client);
		}
		else if((announce == 2) && GetClientIP(client, IP, sizeof(IP)) && GeoipCountry(IP, country, sizeof(country)))
		{
			PrintToChatAll("%t", "Player_Connected_From", client, country);
		}
		else if((announce == 3) && GetClientIP(client, IP, sizeof(IP)) && GeoipCountry(IP, country, sizeof(country)))
		{
			if(GetUserAdmin(client) != INVALID_ADMIN_ID)
			{
				//
			}
			PrintToChatAll("%t", "Player_Connected_From", client, country);
		}
	}
}

//----------------------------//
//=====NON-ADMIN_COMMAND=====//
public Action CMD_Admins(int client, int args) //Showing all online admins for you. !!IF YOU ARE ADMIN, YOU ALWAYS GET THE TRUE, CURRENTLY ONLINE ADMINS! NO MATTER IF THE COMMAND IS DISABLED OR SET TO FAKE ADMINS!!
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC))
	{
		int value = GetConVarInt(CVAR_ADMINS);
		if(value == 0)
		{
			ReplyToCommand(client, "%t", "CMD_Disabled");
			return Plugin_Handled;
		}
		else if(value == 1)
		{
			ReplyToCommand(client, "%t", "CMD_Admins_Offline");
			return Plugin_Handled;
		}
	}
	
	char buffer[128], current[64];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			char flags = GetUserFlagBits(i);
			if(flags & ADMFLAG_GENERIC)
			{			
				Format(current, sizeof(current), "%s%N", (flags & ADMFLAG_ROOT) ? ROOT_PREFIX : ADMIN_PREFIX, i);
				if(StrEqual(buffer, "", false))
				{
					Format(buffer, sizeof(buffer), "%s", current);
				}
				else
				{
					Format(buffer, sizeof(buffer), "%s, %s", buffer, current);
				}
			}
		}
	}
	
	if(!StrEqual(buffer, "", false))
	{
		ReplyToCommand(client, "%t", "CMD_Admins_Online", buffer);
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Admins_Offline");
	}
	return Plugin_Handled;
}

//------------------------//
//=====ADMIN_COMMANDS=====//
public Action CMD_Extend(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		ReplyToCommand(client, "%t", "CMD_Extend_Usage");
		return Plugin_Handled;
	}
	
	char buffer[6];
	GetCmdArg(1, buffer, sizeof(buffer));
	
	int value = StringToInt(buffer);
	ExtendMapTimeLimit(value * 60);
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Extend", value);
	LogActionEx(client, "%t", "CMD_Extend", value);
	return Plugin_Handled;
}
public Action CMD_ClearMap(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	char buffer[64];
	for(char entity = MaxClients; entity < GetMaxEntities(); entity++)
	{
		if(IsValidEntity(entity))
		{
			GetEntityClassname(entity, buffer, sizeof(buffer));
			if(((StrContains(buffer, "weapon_", false) != -1) && (GetEntProp(entity, Prop_Data, "m_iState") == 0) && (GetEntProp(entity, Prop_Data, "m_spawnflags") != 1)) || StrEqual(buffer, "item_defuser", false) || (StrEqual(buffer, "chicken", false) && (GetEntPropEnt(entity, Prop_Send, "m_leader") == -1)))
			{
				AcceptEntityInput(entity, "Kill");
			}
		}
	}
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_ClearMap");
	LogActionEx(client, "%t", "CMD_ClearMap");
	return Plugin_Handled;
}
public Action CMD_RestartGame(int client, int args)
{
	float time;
	if(args)
	{
		char buffer[2];
		GetCmdArg(1, buffer, sizeof(buffer));
		time = StringToFloat(buffer);
	}
	
	if(time > 0.0)
	{
		ServerCommand("mp_restartgame %i", time);
	}
	else
	{
		CS_TerminateRound(0.0, CSRoundEnd_GameStart);
	}
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_RestartGame");
	LogActionEx(client, "%t", "CMD_RestartGame");
	return Plugin_Handled;
}
public Action CMD_RestartRound(int client, int args)
{
	float time;
	if(args)
	{
		char buffer[2];
		GetCmdArg(1, buffer, sizeof(buffer));
		time = StringToFloat(buffer);
	}
	CS_TerminateRound(time, CSRoundEnd_Draw);
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_RestartRound");
	LogActionEx(client, "%t", "CMD_RestartRound");
	return Plugin_Handled;
}
public Action CMD_Equipments(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	char buffer[512];
	for(int i = 0; i < sizeof(WeaponsList); i++)
	{
		if(StrEqual(buffer, "", false))
		{
			Format(buffer, sizeof(buffer), "%s", WeaponsList[i]);
		}
		else
		{
			Format(buffer, sizeof(buffer), "%s, %s", buffer, WeaponsList[i]);
		}
	}
	PrintToConsole(client, "%t", "CMD_Equipments_Weapons", buffer);
	
	buffer = "";
	
	for(int i = 0; i < sizeof(ItemsList); i++)
	{
		if(StrEqual(buffer, "", false))
		{
			Format(buffer, sizeof(buffer), "%s", ItemsList[i]);
		}
		else
		{
			Format(buffer, sizeof(buffer), "%s, %s", buffer, ItemsList[i]);
		}
	}
	PrintToConsole(client, "%t", "CMD_Equipments_Items", buffer);
	ReplyToCommand(client, "%t", "CMD_Equipments_Printed");
	return Plugin_Handled;
}
public Action CMD_PlaySound(int client, int args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "%t", "CMD_PlaySound_Usage");
		return Plugin_Handled;
	}
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	GetCmdArg(1, buffer, sizeof(buffer));
	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int value[3];
	GetCmdArg(3, buffer, sizeof(buffer));
	value[0] = StringToInt(buffer);
	if((value[0] < 50) || (value[0] > 250))
	{
		value[0] = 100;
	}
	
	GetCmdArg(4, buffer, sizeof(buffer));
	value[1] = StringToInt(buffer);
	if((value[1] < 1) || (value[1] > 100))
	{
		value[1] = 100;
	}
	
	GetCmdArg(5, buffer, sizeof(buffer));
	value[2] = StringToInt(buffer);
	if((value[2] < 1) || (value[2] > 10))
	{
		value[2] = 1;
	}
	
	char file[512];
	GetCmdArg(2, buffer, sizeof(buffer));
	Format(file, sizeof(file), "sound/%s", buffer);
	if(!FileExists(file))
	{
		ReplyToCommand(client, "[SM] File is not exists: %s", buffer);
		return Plugin_Handled;
	}
	
	PrecacheSound(buffer, true);
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			for(int n = 0; n < value[2]; n++)
			{
				EmitSoundToClient(target_list[i], buffer, _, _, _, _, value[1] * 0.01, value[0]);
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_PlaySound", target_name, buffer, value[0], value[1], value[2]);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_PlaySound", "_s", target_name, buffer, value[0], value[1], value[2]);
	}
	return Plugin_Handled;
}

//=========CLIENT=========//
public Action CMD_Teleport(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Teleport_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	GetCmdArg(1, buffer, sizeof(buffer));
	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	float vec[2][3];
	GetCmdArg(2, buffer, sizeof(buffer));
	if(!StrEqual(buffer, "", false))
	{
		if(StrEqual(buffer, "@blink", false))
		{
			GetClientEyePosition(client, vec[0]);
			GetClientEyeAngles(client, vec[1]);
			
			Handle trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);
			if(!TR_DidHit(trace))
			{
				return Plugin_Handled;
			}
			TR_GetEndPosition(vec[0], trace);
			CloseHandle(trace);
			
			vec[1][0] = 0.0;
			
			if(tn_is_ml)
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Blink", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Blink", target_name);
			}
			else
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Blink", "_s", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Blink", "_s", target_name);
			}
		}
		else
		{
			char target = FindTarget(client, buffer, false, false);
			if(!IsClientValid(target) || !IsClientInGame(target))
			{
				return Plugin_Handled;
			}
			
			GetClientAbsOrigin(target, vec[0]);
			GetClientEyeAngles(target, vec[1]);
			
			if(tn_is_ml)
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Player", target_name, target);
				LogActionEx(client, "%t", "CMD_Teleport_To_Player", target_name, target);
			}
			else
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Player", "_s", target_name, target);
				LogActionEx(client, "%t", "CMD_Teleport_To_Player", "_s", target_name, target);
			}
		}
	}
	else
	{
		if((SaveVec[client][0][0] + SaveVec[client][0][1] + SaveVec[client][0][2]) == 0)
		{
			ReplyToCommand(client, "%t", "CMD_Teleport_NoSaved");
			return Plugin_Handled;
		}
		else
		{
			vec[0] = SaveVec[client][0];
			vec[1] = SaveVec[client][1];
			
			if(tn_is_ml)
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Saved", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Saved", target_name);
			}
			else
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Saved", "_s", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Saved", "_s", target_name);
			}
		}
	}
	
	vec[0][2] = vec[0][2] + 2.0;
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			TeleportEntity(target_list[i], vec[0], vec[1], view_as<float>({0.0, 0.0, 0.0}));
		}
	}
	
	if(!StrEqual(SOUND_RESPAWN, "", false))
	{
		EmitSoundToAll(SOUND_RESPAWN, target_list[target_count - 1]);
	}
	return Plugin_Handled;
}
public Action CMD_SaveVec(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	GetClientAbsOrigin(client, SaveVec[client][0]);
	GetClientEyeAngles(client, SaveVec[client][1]);
	ReplyToCommand(client, "%t", "CMD_SaveVec");
	return Plugin_Handled;
}

//==========//
public Action CMD_Team(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 2) && (args != 3))
	{
		ReplyToCommand(client, "%t", "CMD_Team_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int team;
	GetCmdArg(2, buffer, sizeof(buffer));
	if(StrEqual(buffer, "spectator", false) || StrEqual(buffer, "spec", false) || StrEqual(buffer, "1", false))
	{
		team = CS_TEAM_SPECTATOR;
		if(tn_is_ml)
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", target_name);
			LogActionEx(client, "%t", "CMD_Team_Spec", target_name);
		}
		else
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", "_s", target_name);
			LogActionEx(client, "%t", "CMD_Team_Spec", "_s", target_name);
		}
	}
	else if(StrEqual(buffer, "t", false) || StrEqual(buffer, "2", false))
	{
		team = CS_TEAM_T;
		if(tn_is_ml)
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_T", target_name);
			LogActionEx(client, "%t", "CMD_Team_T", target_name);
		}
		else
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_T", "_s", target_name);
			LogActionEx(client, "%t", "CMD_Team_T", "_s", target_name);
		}
	}
	else if(StrEqual(buffer, "ct", false) || StrEqual(buffer, "3", false))
	{
		team = CS_TEAM_CT;
		if(tn_is_ml)
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_CT", target_name);
			LogActionEx(client, "%t", "CMD_Team_CT", target_name);
		}
		else
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_CT", "_s", target_name);
			LogActionEx(client, "%t", "CMD_Team_CT", "_s", target_name);
		}
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Invalid_Team");
		return Plugin_Handled;
	}
	
	GetCmdArg(3, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(value == 1)
			{
				if(team != 1)
				{
					CS_SwitchTeam(target_list[i], team);
					if(IsPlayerAlive(target_list[i]))
					{
						CS_RespawnPlayer(target_list[i]);
					}
				}
				else
				{
					ChangeClientTeam(target_list[i], team);
				}
			}
			else
			{
				SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", team);
				int frags = GetClientFrags(target_list[i]) +1;
				int deaths = GetClientDeaths(target_list[i])-1;
				int score = CS_GetClientContributionScore(target_list[i])+2;
				SetEntProp(target_list[i], Prop_Data, "m_iFrags", frags);
				SetEntProp(target_list[i], Prop_Data, "m_iDeaths", deaths);
				CS_SetClientContributionScore(target_list[i], score);
			}
		}
	}
	return Plugin_Handled;
}
public Action CMD_Swap(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Swap_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
		
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "@spec", false) || StrEqual(buffer, "@spectator", false))
	{
		ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
		return Plugin_Handled;
	}
	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer), team;
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			team = GetClientTeam(target_list[i]);
			if(team >= 2)
			{
				if(value == 1)
				{
					if(team == CS_TEAM_T)
					{
						CS_SwitchTeam(target_list[i], CS_TEAM_CT);
					}
					else
					{
						CS_SwitchTeam(target_list[i], CS_TEAM_T);
					}
					if(IsPlayerAlive(target_list[i]))
					{
						CS_RespawnPlayer(target_list[i]);
					}
				}
				else
				{
					if(team == CS_TEAM_T)
					{
						SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_CT);
						int frags = GetClientFrags(target_list[i]) +1;
						int deaths = GetClientDeaths(target_list[i])-1;
						int score = CS_GetClientContributionScore(target_list[i])+2;
						SetEntProp(target_list[i], Prop_Data, "m_iFrags", frags);
						SetEntProp(target_list[i], Prop_Data, "m_iDeaths", deaths);
						CS_SetClientContributionScore(target_list[i], score);
					}
					else
					{
						SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_T);
						int frags = GetClientFrags(target_list[i]) +1;
						int deaths = GetClientDeaths(target_list[i])-1;
						int score = CS_GetClientContributionScore(target_list[i])+2;
						SetEntProp(target_list[i], Prop_Data, "m_iFrags", frags);
						SetEntProp(target_list[i], Prop_Data, "m_iDeaths", deaths);
						CS_SetClientContributionScore(target_list[i], score);
					}
				}
			}
			else if(!tn_is_ml)
			{
				ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
				return Plugin_Handled;
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Swap", target_name);
		LogActionEx(client, "%t", "CMD_Swap", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Swap", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Swap", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action CMD_Spec(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Team_Spec_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
		
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(value == 1)
			{
				ChangeClientTeam(target_list[i], CS_TEAM_SPECTATOR);
			}
			else
			{
				SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_SPECTATOR);
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", target_name);
		LogActionEx(client, "%t", "CMD_Team_Spec", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Team_Spec", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action CMD_Scramble(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	ServerCommand("mp_scrambleteams");
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Scramble");
	LogActionEx(client, "%t", "CMD_Scramble");
	return Plugin_Handled;
}

//==========//
public Action CMD_Give(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Give_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	if(StrEqual(buffer, "", false))
	{
		Format(buffer, sizeof(buffer), "knife");
	}
	
	char type = ItemType(buffer);
	if(!type)
	{
		if(GetConVarBool(CVAR_INVALID))
		{
			if(tn_is_ml)
			{
				PrintToChatAll("%s%t", CMD_PREFIX, "CMD_Give", target_name, buffer);
			}
			else
			{
				PrintToChatAll("%s%t", CMD_PREFIX, "CMD_Give", "_s", target_name, buffer);
			}
		}
		ReplyToCommand(client, "%t", "CMD_Invalid_Weapon");
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		if(StrEqual(buffer, "knife", false) && !GetConVarBool(FindConVar("mp_drop_knife_enable")))
		{
			int knife = -1;
			while((knife = GetPlayerWeaponSlot(target_list[i], 2)) != -1)
			{
				if(IsValidEntity(knife))
				{
					RemovePlayerItem(target_list[i], knife);
				}
			}
		}
		GivePlayerWeapon(target_list[i], buffer, type);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Give", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Give", target_name, buffer);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Give", "_s", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Give", "_s", target_name, buffer);
	}
	return Plugin_Handled;
}
public Action CMD_Equip(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Equip_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
		
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	if(StrEqual(buffer, "", false))
	{
		Format(buffer, sizeof(buffer), "knife");
	}
	
	char type = ItemType(buffer);
	if(!type)
	{
		if(GetConVarBool(CVAR_INVALID))
		{
			if(tn_is_ml)
			{
				PrintToChatAll("%s%t", CMD_PREFIX, "CMD_Equip", target_name, buffer);
			}
			else
			{
				PrintToChatAll("%s%t", CMD_PREFIX, "CMD_Equip", "_s", target_name, buffer);
			}
		}
		ReplyToCommand(client, "%t", "CMD_Invalid_Weapon");
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		DisarmPlayer(target_list[i]);
		GivePlayerWeapon(target_list[i], buffer, type);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Equip", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Equip", target_name, buffer);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Equip", "_s", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Equip", "_s", target_name, buffer);
	}
	return Plugin_Handled;
}
public Action CMD_Disarm(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		ReplyToCommand(client, "%t", "CMD_Disarm_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		DisarmPlayer(target_list[i]);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Disarm", target_name);
		LogActionEx(client, "%t", "CMD_Disarm", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Disarm", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Disarm", "_s", target_name);
	}
	return Plugin_Handled;
}

//==========//
public Action CMD_Respawn(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		ReplyToCommand(client, "%t", "CMD_Respawn_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "@spec", false) || StrEqual(buffer, "@spectator", false))
	{
		ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
		return Plugin_Handled;
	}
	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(GetClientTeam(target_list[i]) >= 2)
			{
				CS_RespawnPlayer(target_list[i]);
				if(!StrEqual(SOUND_RESPAWN, "", false))
				{
					EmitSoundToAll(SOUND_RESPAWN, target_list[i]);
				}
			}
			else if(!tn_is_ml)
			{
				ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
				return Plugin_Handled;
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Respawn", target_name);
		LogActionEx(client, "%t", "CMD_Respawn", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Respawn", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Respawn", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action CMD_Bury(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	float pos[3];
	for(int i = 0; i < target_count; i++)
	{
		GetClientAbsOrigin(target_list[i], pos);
		pos[2] -= 36.5;
		TeleportEntity(target_list[i], pos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		if(!StrEqual(SOUND_BURY, "", false))
		{
			EmitSoundToAll(SOUND_BURY, target_list[i]);
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Bury", target_name);
		LogActionEx(client, "%t", "CMD_Bury", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Bury", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Bury", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action CMD_UnBury(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	float pos[3];
	for(int i = 0; i < target_count; i++)
	{
		GetClientAbsOrigin(target_list[i], pos);
		pos[2] += 36.5;
		TeleportEntity(target_list[i], pos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		if(!StrEqual(SOUND_BURY, "", false))
		{
			EmitSoundToAll(SOUND_BURY, target_list[i]);
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_UnBury", target_name);
		LogActionEx(client, "%t", "CMD_UnBury", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_UnBury", "_s", target_name);
		LogActionEx(client, "%t", "CMD_UnBury", "_s", target_name);
	}
	return Plugin_Handled;
}
//==========//
public Action CMD_Speed(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Speed_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	float value = StringToFloat(buffer);
	if((value < 0.0) || (value > 500.0))
	{
		ReplyToCommand(client, "%t", "CMD_Speed_Usage");
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		SetEntPropFloat(target_list[i], Prop_Data, "m_flLaggedMovementValue", value);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Speed", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Speed", target_name, buffer);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Speed", "_s", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Speed", "_s", target_name, buffer);
	}
	return Plugin_Handled;
}
public Action CMD_God(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		ReplyToCommand(client, "%t", "CMD_God_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		if(g_toggle[target_list[i]])
		{
			g_toggle[target_list[i]] = false;
			SetEntProp(target_list[i], Prop_Data, "m_takedamage", 2, 1);
		}
		else
		{
			g_toggle[target_list[i]] = true;

			SetEntProp(target_list[i], Prop_Data, "m_takedamage", 1, 1);
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_God", target_name);
		LogActionEx(client, "%t", "CMD_God", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_God", "_s", target_name);
		LogActionEx(client, "%t", "CMD_God", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action CMD_Helmet(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Helmet_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	
	if((value != 0) && (value != 1))
	{
		ReplyToCommand(client, "%t", "CMD_Helmet_Usage");
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Send, "m_bHasHelmet", value);
	}

	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Helmet", target_name, value);
		LogActionEx(client, "%t", "CMD_Helmet", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Helmet", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Helmet", "_s", target_name, value);
	}
	return Plugin_Handled;
}

//==========//
public Action CMD_Health(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Health_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	
	int iHealthRestriction = GetConVarBool(CVAR_HealthRest);
	
	if (value <= 0 && iHealthRestriction)
	{
		ReplyToCommand(client, "%t", "CMD_Health_Rest");
		return Plugin_Handled;
	}
			
	for(int i = 0; i < target_count; i++)
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetEntProp(target_list[i], Prop_Data, "m_iHealth");
		}
		SetEntProp(target_list[i], Prop_Data, "m_iHealth", value);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Health", target_name, value);
		LogActionEx(client, "%t", "CMD_Health", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Health", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Health", "_s", target_name, value);
	}
	return Plugin_Handled;
}
public Action CMD_Armor(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Armor_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	
	for(int i = 0; i < target_count; i++)
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetEntProp(target_list[i], Prop_Send, "m_ArmorValue");
		}
		SetEntProp(target_list[i], Prop_Send, "m_ArmorValue", value);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Armor", target_name, value);
		LogActionEx(client, "%t", "CMD_Armor", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Armor", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Armor", "_s", target_name, value);
	}
	return Plugin_Handled;
}
public Action CMD_Cash(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Cash_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if((buffer[0] == '+') || (buffer[0] == '-'))
			{
				value = value + GetEntProp(target_list[i], Prop_Send, "m_iAccount");
			}
			SetEntProp(target_list[i], Prop_Send, "m_iAccount", value);
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Cash", target_name, value);
		LogActionEx(client, "%t", "CMD_Cash", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Cash", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Cash", "_s", target_name, value);
	}
	return Plugin_Handled;
}
//==========//
public Action CMD_SetStats(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 3)
	{
		ReplyToCommand(client, "%t", "CMD_SetStats_Usage");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH], buffer[2][512];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, buffer[0], sizeof(buffer[]));
	if((target_count = ProcessTargetString(buffer[0], client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer[0], sizeof(buffer[]));
	GetCmdArg(3, buffer[1], sizeof(buffer[]));
	int value = StringToInt(buffer[1]);
	
	for(int i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(StrEqual(buffer[0], "kills"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + GetEntProp(target_list[i], Prop_Data, "m_iFrags");
				}
				SetEntProp(target_list[i], Prop_Data, "m_iFrags", value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "assists"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + CS_GetClientAssists(target_list[i]);
				}
				CS_SetClientAssists(target_list[i], value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "deaths"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + GetEntProp(target_list[i], Prop_Data, "m_iDeaths");
				}
				SetEntProp(target_list[i], Prop_Data, "m_iDeaths", value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "mvps"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + CS_GetMVPCount(target_list[i]);
				}
				CS_SetMVPCount(target_list[i], value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "scores"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + CS_GetClientContributionScore(target_list[i]);
				}
				CS_SetClientContributionScore(target_list[i], value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "clan"))
			{
				CS_SetClientClanTag(target_list[i], buffer[1]);
			}
			else
			{
				ReplyToCommand(client, "%t", "CMD_SetStats_Values");
				return Plugin_Handled;
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SetStats", target_name, buffer[0], buffer[1]);
		LogActionEx(client, "%t", "CMD_SetStats", target_name, buffer[0], buffer[1]);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SetStats", "_s", target_name, buffer[0], buffer[1]);
		LogActionEx(client, "%t", "CMD_SetStats", "_s", target_name, buffer[0], buffer[1]);
	}
	return Plugin_Handled;
}
public Action CMD_TeamScores(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_TeamScores_Usage");
		return Plugin_Handled;
	}
	
	char team[8], buffer[64];
	
	GetCmdArg(1, team, sizeof(team));
	GetCmdArg(2, buffer, sizeof(buffer));
	int value = StringToInt(buffer);
	
	if(StrEqual(team, "t", false) || StrEqual(team, "2", false))
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetTeamScore(CS_TEAM_T);
		}
		SetTeamScore(CS_TEAM_T, value);
		
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_TeamScores_T", value);
		LogActionEx(client, "%t", "CMD_TeamScores_T", value);
	}
	else if(StrEqual(team, "ct", false) || StrEqual(team, "3", false))
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetTeamScore(CS_TEAM_CT);
		}
		SetTeamScore(CS_TEAM_CT, value);
		
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_TeamScores_CT", value);
		LogActionEx(client, "%t", "CMD_TeamScores_CT", value);
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Invalid_Team");
	}
	return Plugin_Handled;
}
public Action CMD_SpawnChicken(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	float vec[2][3];
	GetClientEyePosition(client, vec[0]);
	GetClientEyeAngles(client, vec[1]);
	
	Handle trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);
	if(!TR_DidHit(trace))
	{
		return Plugin_Handled;
	}
	TR_GetEndPosition(vec[0], trace);
	CloseHandle(trace);
	
	char buffer[6][4];
	char values[6];
	
	for(int i = 0; i <= 5; i++)
	{
		GetCmdArg(i + 1, buffer[i], sizeof(buffer[]));
		values[i] = StringToInt(buffer[i]);
	}
	
	if(((values[0] < 0) || (values[0] > 6)) || ((values[1] < -1) || (values[1] > 9999)) || ((values[2] < 0) || (values[2] > 255)) || ((values[3] < 0) || (values[3] > 255)) || ((values[4] < 0) || (values[4] > 255)) || ((values[5] < 0) || (values[5] > 3)))
	{
		ReplyToCommand(client, "%t", "CMD_SpawnChicken_Usage");
		return Plugin_Handled;
	}
	
	char chicken = CreateEntityByName("chicken");
	if(!IsValidEntity(chicken))
	{
		return Plugin_Handled;
	}
	
	char color[16];
	Format(color, sizeof(color), "%s %s %s", buffer[2], buffer[3], buffer[4]);
	DispatchKeyValue(chicken, "glowcolor", color);
	DispatchKeyValue(chicken, "glowdist", "640");
	DispatchKeyValue(chicken, "glowstyle", buffer[5]);
	DispatchKeyValue(chicken, "glowenabled", "1");
	DispatchKeyValue(chicken, "ExplodeDamage", buffer[1]);
	DispatchKeyValue(chicken, "ExplodeRadius", "0");
	DispatchSpawn(chicken);
	
	if(values[1] < 0)
	{
		SetEntProp(chicken, Prop_Data, "m_takedamage", 0);
	}
	
	if(values[0] == 6)
	{
		SetEntityModel(chicken, MODEL_CHICKEN_ZOMBIE);
	}
	else
	{
		SetEntProp(chicken, Prop_Data, "m_nSkin", GetRandomInt(0, 1));
		SetEntProp(chicken, Prop_Data, "m_nBody", values[0]);
	}
	
	vec[0][2] = vec[0][2] + 10.0;
	TeleportEntity(chicken, vec[0], NULL_VECTOR, NULL_VECTOR);
	
	if(!StrEqual(SOUND_CHICKEN, "", false))
	{
		EmitSoundToAll(SOUND_CHICKEN, chicken);
	}
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SpawnChicken", values[0], values[1], values[2], values[3], values[4], values[5]);
	LogActionEx(client, "%t", "CMD_SpawnChicken", values[0], values[1], values[2], values[3], values[4], values[5]);
	return Plugin_Handled;
}
public Action CMD_SpawnBall(int client, int args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	float vec[2][3];
	GetClientEyePosition(client, vec[0]);
	GetClientEyeAngles(client, vec[1]);
	
	Handle trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);
	if(!TR_DidHit(trace))
	{
		return Plugin_Handled;
	}
	TR_GetEndPosition(vec[0], trace);
	CloseHandle(trace);
	
	char ball = CreateEntityByName("prop_physics_multiplayer");
	if(!IsValidEntity(ball))
	{
		return Plugin_Handled;
	}
	
	DispatchKeyValue(ball, "model", MODEL_BALL);
	DispatchKeyValue(ball, "physicsmode", "2");
	DispatchSpawn(ball);
	
	vec[0][2] = vec[0][2] + 16.0;
	TeleportEntity(ball, vec[0], NULL_VECTOR, NULL_VECTOR);
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SpawnBall");
	LogActionEx(client, "%t", "CMD_SpawnBall");
	return Plugin_Handled;
}
public Action CMD_CURSE(int client, int args) 
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	if(args != 1) 
	{
		ReplyToCommand(client, "[SM] Usage: sm_curse <#userid|name>");
		return Plugin_Handled;
	}
	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0) 
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++) 
	{
		if(g_toggle2[target_list[i]])
		{
			g_toggle2[target_list[i]] = false;
		}
		else
		{
			g_toggle2[target_list[i]] = true;
		}
	}

	if(tn_is_ml) 
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "Toggled curse on target", target_name);
	} 
	else 
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "Toggled curse on target", "_s", target_name);
	}

	return Plugin_Handled;
}


//-----STOCKS-----//
stock char GivePlayerWeapon(int client, char[] weapon, int type)
{
	char buffer[64];
	if(type == 1)
	{
		Format(buffer, sizeof(buffer), "weapon_%s", weapon);
	}
	else
	{
		Format(buffer, sizeof(buffer), "item_%s", weapon);
	}
	return GivePlayerItem(client, buffer);
}

stock int DisarmPlayer(int client)
{
	for(int i = 0; i < 5; i++)
	{
		char weapon = -1;
		while((weapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			if(IsValidEntity(weapon))
			{
				RemovePlayerItem(client, weapon);
			}
		}
	}
	SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
	SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", 0);
	SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
	SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
}

stock char LogActionEx(int client, char[] message, any ...)
{
	if(GetConVarBool(CVAR_LOG))
	{
		char buffer1337[256];
		SetGlobalTransTarget(LANG_SERVER);
		VFormat(buffer1337, sizeof(buffer1337), message, 3);
		LogMessage("%N: %s", client, buffer1337);
	}
}

bool IsClientValid(int client)
{
	return ((client > 0) && (client <= MaxClients));
}

stock char ItemType(const char[] itemname)
{
	for(int i = 0; i < sizeof(WeaponsList); i++)
	{
		if(StrEqual(itemname, WeaponsList[i], false))
		{
			return 1;
		}
	}
	for(int i = 0; i < sizeof(ItemsList); i++)
	{
		if(StrEqual(itemname, ItemsList[i], false))
		{
			return 2;
		}
	}
	return 0;
}

//-----FILTERS-----//
public bool Filter_ExcludePlayers(int entity, int contentsMask, any data)
{
	return !((entity > 0) && (entity <= MaxClients));
}
