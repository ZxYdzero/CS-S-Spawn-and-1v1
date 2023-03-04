//此插件1v1功能由Sparkle编写 数据库功能由Cialloo(达达)修复

//Includes:
#include <sourcemod>
#include <sdktools>
#include <events>
#include <cstrike>
#include <morecolors>
#include <float>
#include <smlib/math>
//初始化堆栈内存大小
#pragma dynamic 131072

//Misc:
static  MaxSpawns = 64;
//数据
int Attack;
int Died;
char Buffer[64];
char ChatC[128];
int TPLAYER[12];
int CTPLAYER[12];
int COUNT_T;
int COUNT_CT;
int arrayT[12];
int arrayCT[12];
int TPlus;
int CTPlus;
int Death = 0;
int Times;

//Spawns:
static Float:SpawnPoints[MAXPLAYERS + 1][2][3];
static bool:ValidSpawn[MAXPLAYERS + 1][2];

//Definitions:
#define MAINVERSION		"1.0"

//Database Sql:
static Handle:hDataBase = INVALID_HANDLE;

//Plugin Info:
public Plugin:myinfo =
{
	name = "Multi-1V1",
	author = "Cialloo & Sparkle)",
	description = "Using SQL save the spawnpoints and multi-1v1",
	version = MAINVERSION,
	url = ""
};

//Initation:
public OnPluginStart()
{
	//Print Server If Plugin Start:
	PrintToServer("SQL Spawn System Successfully Loaded (v%s)!", MAINVERSION);

	//Commands:
	RegAdminCmd("sm_createspawn", CommandCreateSpawn, ADMFLAG_ROOT, "<id> <Type> - Type = 0:Team 2, Type = 1:Team 3 Creates a spawn point");

	RegAdminCmd("sm_removespawn", CommandRemoveSpawn, ADMFLAG_ROOT, "<id> <Type> - Type = 0:Team 2, Type = 1:Team 3 Removes a spawn point");

	RegAdminCmd("sm_mapspawnlist", CommandMapSpawnList, ADMFLAG_SLAY, " <Map String> Lists all the Spawns in the database");

	RegAdminCmd("sm_spawnlist", CommandListSpawns, ADMFLAG_SLAY, " <No Args> Lists all the Spawns in the database");

	RegAdminCmd("sm_spawnlistall", CommandListSpawnsAll, ADMFLAG_SLAY, " <No Args> Lists all the Spawns in the database");

	RegConsoleCmd("kill", Cmd_Kill, "Block player suicide.");

	//Setup Sql Connection:
	initSQL();

	//Reset Spawns:
	ResetSpawns();

	//Initulize:
	MaxSpawns = MaxClients;

	//初始化数组值
	for(int i = 0; i < 12; i++)
	{
	CTPLAYER[i] = i;
	TPLAYER[i] = i;
	}

	//Timer:
	CreateTimer(0.1, CreateSQLdbSpawnPoints);


	//Event:
	HookEvent("round_start", round_start);
	HookEvent("player_death", round_tie);
	HookEvent("round_end", roundend);
}

public Action Cmd_Kill(int client, int args)
{
	return Plugin_Handled;
}


//Initation:
public OnMapStart()
{

	//SQL Load:
	CreateTimer(0.4, LoadSpawnPoints);
	// Reset the array at the beginning of each map
	for (int i = 0; i < 12; i++) 
	{
		arrayT[i] = 0;
		arrayCT[i] = 0;
    }

}

//Initation:
public OnEndStart()
{

	//Reset Spawns:
	ResetSpawns();
}

public ResetSpawns()
{

	//Loop:
	for(new Z = 0; Z < MaxSpawns + 1; Z++)
	{

		//Initulize:
		ValidSpawn[Z][0] = false;

		ValidSpawn[Z][1] = false;

		//Loop:
		for(new B = 0; B < 2; B++) for(new i = 0; i < 3; i++)
		{

			//Initulize:
			SpawnPoints[Z][B][i] = 69.0;
		}
	}
}

//玩家重生事件，判断是否为人机 并且传送
public Action:round_start(Event event, const char[] name, bool dontBroadcast) 
{
	//数据
	COUNT_T = GetTeamClientCount(2);
	COUNT_CT =  GetTeamClientCount(3);
  	TPlus = 0;
	CTPlus = 0;
	Times = ((GetTeamClientCount(2) + GetTeamClientCount(3)) / 2);

	//传送循环
	for (int i = 0; i < COUNT_T; i++)
	{
        arrayT[i] = i + 1;


    }
	for (int i = 0; i < COUNT_CT; i++) 
	{
        arrayCT[i] = i + 1;

		
    }
	for (int i = 1; i <= 25; i++)
    {
		if(IsClientConnected(i) && !IsFakeClient(i) && IsClientInGame(i))
		{
	 		PrintToConsole(i,"[Multi-1v1]传送成功");
			if(GetClientTeam(i) == 2)
			{
				InitSpawnPos(i, (arrayT[(i-1)]));
			}
			else if(GetClientTeam(i) == 3)
			{
				InitSpawnPos(i, (arrayCT[(i-1)]));
			}
        }
	}
}

//重生函数
public InitSpawnPos(Client, COUNT)
{
	//Get Job Type:
	new Type;
    
	//检查队伍
	if(GetClientTeam(Client) == 2)
	{

		//宣告:
		Type = 1;
		OneByOneSpawn(Client, Type, (arrayT[TPlus]));
		++TPlus;
	}
	else
	{

		//宣告:
		Type = 0;
		OneByOneSpawn(Client, Type, (arrayCT[CTPlus]));
		++CTPlus;
	}


}

//传送:
public Action:OneByOneSpawn(Client, SpawnType, COUNT)
{   
	TeleportEntity(Client, SpawnPoints[COUNT][SpawnType], NULL_VECTOR, NULL_VECTOR);
	//设置标签
	Format(Buffer, 64, "| %d 竞技场|", COUNT);
	CS_SetClientClanTag(Client, Buffer);
	Format(ChatC, 128, "{green}[Multi-1v1]{lightgreen}你现在位于 {gold}%d {lightgreen}竞技场中", COUNT);
	CPrintToChat(Client, ChatC);
}

//回合结束的事件，双方平局
public Action:round_tie(Event event, const char[] name, bool dontBroadcast)
{

	//下面那个函数所用的数值
	Died = GetClientOfUserId(GetEventInt(event, "userid"));
	Attack = GetClientOfUserId(GetEventInt(event, "attacker"));

    //被杀者与杀手之间的信息打印 且包括击杀次数的上涨
	if(Died == 0 || Attack == 0)
	{
		return Plugin_Continue
	}

	if(Died == Attack)
	{
		CPrintToChat(Died, "{green}[Multi-1v1]{lightgreen}你自杀了");
	}
	if(Died != Attack)
	{
		CPrintToChat(Attack, "{green}[Multi-1v1]{lightgreen}你赢了, 如果想要观看别人请控制台输入KILL");
		CPrintToChat(Died, "{green}[Multi-1v1]{lightgreen}你输了");
		Death++;
	}
    //结束回合
	PrintToServer("[Multi-1v1]目前服务器Death数量为%d", Death);
	PrintToServer("[Multi-1v1]目前服务器Times数量为%d", Times);
	if(Death >= Times)
	{
		PrintToServer("[Multi-1v1]目前Death数量为%d", Death);
		PrintToServer("[Multi-1v1]目前Times数量为%d", Times);
		CS_TerminateRound(1.0, CSRoundEnd_Draw, false);
	}

}

//回合结束重置所有数组和某些特殊数据
public roundend(Event event, const char[] name, bool dontBroadcast)
{
    // Reset the array at the end of each round
	PrintToServer("[Multi-1v1]数组重置成功");
	for (int i = 0; i < 12; i++) 
	{
		arrayT[i] = 0;
		arrayCT[i] = 0; 
    }
	//重置数据
	Death = 0;
	Times = 0;
}

/*
————————————————————这下面所有代码请不要修改——————————————————————
*/
//Setup Sql Connection:
initSQL()
{
	SQL_TConnect(DBConnect, "Spawns");

}

public DBConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Is Valid Handle:
	if(hndl == INVALID_HANDLE)
	{
#if defined DEBUG
		//Log Message:
		LogError("|DataBase| : %s", error);
#endif
		//Return:
		return false;
	}

	//Override:
	else
	{

		//Copy Handle:
		hDataBase = hndl;

		//Declare:
		decl String:SQLDriver[32];

		new bool:iSqlite = true;

		//Read SQL Driver
		SQL_ReadDriver(hndl, SQLDriver, sizeof(SQLDriver));

		//MYSQL
		if(strcmp(SQLDriver, "mysql", false)==0)
		{

			//Thread Query:
			SQL_TQuery(hDataBase, SQLErrorCheckCallback, "SET NAMES \"UTF8\"");

			//Initulize:
			iSqlite = false;
		}

		//Is Sqlite:
		if(iSqlite)
		{

			//Print:
			PrintToServer("|DataBase| Connected to SQLite Database. Version %s", MAINVERSION);
		}

		//Override:
		else
		{

			//Print:
			PrintToServer("|DataBase| Connected to MySQL Database I.e External Config. Version %s.", MAINVERSION);
		}
	}

	//Return:
	return true;
}

public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Is Error:
	if(hndl == INVALID_HANDLE)
	{
#if defined DEBUG
		//Log Message:
		LogError("[Spawns] SQLErrorCheckCallback: Query failed! %s", error);
#endif
	}
}

//Create Database:
public Handle:GetGlobalSQL()
{

	//Return:
	return hDataBase;
}

//Create Database:
public Action:CreateSQLdbSpawnPoints(Handle:Timer)
{

	//Declare:
	new len = 0;
	decl String:query[512];

	//Sql String:
	len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `SpawnPoints`");

	len += Format(query[len], sizeof(query)-len, " (`Map` varchar(32) NOT NULL, `Type` int(12) NULL,");

	len += Format(query[len], sizeof(query)-len, " `SpawnId` int(12) NULL, `Position` varchar(32) NOT NULL);");

	//Thread query:
	SQL_TQuery(GetGlobalSQL(), SQLErrorCheckCallback, query);
}

//Create Database:
public Action:LoadSpawnPoints(Handle:Timer)
{

	//Declare:
	decl String:query[512];

	//Format:
	Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Map = '%s';", ServerMap());

	//Not Created Tables:
	SQL_TQuery(GetGlobalSQL(), T_DBLoadSpawnPoints, query);
}

public T_DBLoadSpawnPoints(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Invalid Query:
	if (hndl == INVALID_HANDLE)
	{

		//Logging:
		LogError("[Spawns] T_DBLoadSpawnPoints: Query failed! %s", error);
	}

	//Override:
	else 
	{

		//Not Player:
		if(!SQL_GetRowCount(hndl))
		{

			//Print:
			PrintToServer("[SM] - No Spawns Found in DB!");

			//Return:
			return;
		}

		//Declare:
		new Type, SpawnId; decl String:Buffer[64];

		//Override
		while(SQL_FetchRow(hndl))
		{

			//Database Field Loading String:
			SQL_FetchString(hndl, 3, Buffer, 64);

			//Database Field Loading Intiger:
			SpawnId = SQL_FetchInt(hndl, 2);

			//Database Field Loading Intiger:
			Type = SQL_FetchInt(hndl, 1);

			//Declare:
			decl String:Dump[3][64]; new Float:Position[3];

			//Database Field Loading String:
			SQL_FetchString(hndl, 3, Buffer, 64);

			//Convert:
			ExplodeString(Buffer, "^", Dump, 3, 64);

			//Loop:
			for(new X = 0; X <= 2; X++)
			{

				//Initulize:
				Position[X] = StringToFloat(Dump[X]);
			}

			//Initulize:
			SpawnPoints[SpawnId][Type] = Position;

			ValidSpawn[SpawnId][Type] = true;
		}

		//Print:
		PrintToServer("[SM] - Spawns Loaded!");
	}
}

//Create NPC:
public Action:CommandCreateSpawn(Client, Args)
{

	//Is Colsole:
	if(Client == 0)
	{

		//Print:
		PrintToServer("[SM] - This command can only be used ingame.");

		//Return:
		return Plugin_Handled;
	}

	//No Valid Charictors:
	if(Args < 2)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_createspawn <id> <type>");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	decl String:SpawnId[32], String:sType[32];

	//Initialize:
	GetCmdArg(1, SpawnId, sizeof(SpawnId));

	GetCmdArg(2, sType, sizeof(sType));

	//Declare:
	new Spawn = StringToInt(SpawnId);

	//No Valid Charictors:
	if(Spawn < 1 && Spawn > MaxSpawns)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_createspawn <1-%i> <type>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	new Type = StringToInt(sType);

	//No Valid Charictors:
	if(Type != 1 && Type != 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_createspawn <1-%i> <1 = Team 2, 0 = Team 3>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	new Float:ClientOrigin[3]; decl String:query[512], String:Position[32];

	//Initialize:
	GetClientAbsOrigin(Client, ClientOrigin);

	//Sql String:
	Format(Position, sizeof(Position), "%f^%f^%f", ClientOrigin[0], ClientOrigin[1], ClientOrigin[2]);

	//Spawn Already Created:
	if(ValidSpawn[Spawn][Type] == true)
	{

		//Format:
		Format(query, sizeof(query), "UPDATE SpawnPoints SET Position = '%s' WHERE Map = '%s' AND Type = %i AND SpawnId = %i;", Position, ServerMap(), Type, Spawn);
	}

	//Override:
	else
	{

		//Format:
		Format(query, sizeof(query), "INSERT INTO SpawnPoints (`Map`,`Type`,`SpawnId`,`Position`) VALUES ('%s',%i,%i,'%s');", ServerMap(), Type, Spawn, Position);
	}

	//Initulize:
	SpawnPoints[Spawn][Type] = ClientOrigin;

	ValidSpawn[Spawn][Type] = true;

	//Not Created Tables:
	SQL_TQuery(GetGlobalSQL(), SQLErrorCheckCallback, query);

	//Print:
	PrintToChat(Client, "[SM] - Created spawn #%s <%f, %f, %f>", SpawnId, ClientOrigin[0], ClientOrigin[1], ClientOrigin[2]);

	//Return:
	return Plugin_Handled;
}

//Remove Spawn:
public Action:CommandRemoveSpawn(Client, Args)
{

	//No Valid Charictors:
	if(Args < 2)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <id> <Type>");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	decl String:SpawnId[32], String:sType[32];

	//Initialize:
	GetCmdArg(1, SpawnId, sizeof(SpawnId));

	GetCmdArg(2, sType, sizeof(sType));

	//Declare:
	new Spawn = StringToInt(SpawnId);

	//No Valid Charictors:
	if(Spawn < 1 && Spawn > MaxSpawns)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <1-%i> <type>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	new Type = StringToInt(sType);

	//No Valid Charictors:
	if(Type != 1 && Type != 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <1-%i> <1-%i> <1 = Team 2, 0 = Team 3>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//No Spawn:
	if(ValidSpawn[Spawn][Type] == true)
	{

		//Print:
		PrintToChat(Client, "[SM] - There is no spawnpoint found in the db. (ID #%s TYPE #%s)", SpawnId, Type);

		//Return:
		return Plugin_Handled;
	}

	//Loop:
	for(new i = 0; i < 3; i++)
	{

		//Initulize:
		SpawnPoints[Spawn][Type][i] = 69.0;

		ValidSpawn[Spawn][Type] = false;
	}

	//Declare:
	decl String:query[512];

	//Sql String:
	Format(query, sizeof(query), "DELETE FROM SpawnPoints WHERE SpawnId = %i AND Type = %i AND Map = '%s';", Spawn, Type, ServerMap());

	//Not Created Tables:
	SQL_TQuery(GetGlobalSQL(), SQLErrorCheckCallback, query);

	//Print:
	PrintToChat(Client, "[SM] - Removed Spawn (ID #%s TYPE #%s)", SpawnId, Type);

	//Return:
	return Plugin_Handled;
}

//List Spawns:
public Action:CommandMapSpawnList(Client, Args)
{

	//No Valid Charictors:
	if(Args < 2)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <id> <Type>");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	decl String:Map[64];

	//Initialize:
	GetCmdArg(1, Map, sizeof(Map));

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - press essape for more infomation");

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 3 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 3 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X <= MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Map = '%s' AND SpawnId = %i;", Map, X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}

	//Return:
	return Plugin_Handled;
}

//List Spawns:
public Action:CommandListSpawns(Client, Args)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - press essape for more infomation");

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 3 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 3 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X <= MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 0 AND Map = '%s' AND SpawnId = %i;", ServerMap(), X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}

	//Timer:
	CreateTimer(1.5, List, Client);

	//Return:
	return Plugin_Handled;
}

//Load Spawn:
public Action:List(Handle:Timer, any:Client)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 2 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 2 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X < MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 1 AND Map = '%s' AND SpawnId = %i;", ServerMap(), X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}
}

//List Spawns:
public Action:CommandListSpawnsAll(Client, Args)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - press essape for more infomation");

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 3 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 3 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X <= MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 0 AND SpawnId = %i;", X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}

	//Timer:
	CreateTimer(2.5, ListAll, Client);
		
	//Return:
	return Plugin_Handled;
}

//Load Spawn:
public Action:ListAll(Handle:Timer, any:Client)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 2 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 2 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X < MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 1 AND SpawnId = %i", X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}
}

public T_DBPrintSpawnList(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Declare:
	new Client;

	//Is Client:
	if(data != 0 && (Client = GetClientOfUserId(data)) == 0)
	{

		//Return:
		return;
	}

	//Invalid Query:
	if (hndl == INVALID_HANDLE)
	{

		//Logging:
		LogError("[Spawns] T_DBPrintSpawnList: Query failed! %s", error);
	}

	//Override:
	else 
	{

		//Not Player:
		if(!SQL_GetRowCount(hndl))
		{

			//Print:
			if(Client > 0)
			{

				//Print:
				PrintToChat(Client, "[SM] - Invalid Map");
			}

			//Override:
			else
			{

				//Print:
				PrintToServer("Invalid Map");
			}

			//Return:
			return;
		}

		//Declare:
		new SpawnId, String:Buffer[64], String:Map[64];

		//Database Row Loading INTEGER:
		while(SQL_FetchRow(hndl))
		{

			//Database Field Loading String:
			SQL_FetchString(hndl, 0, Map, 64);

			//Database Field Loading Intiger:
			SpawnId = SQL_FetchInt(hndl, 2);

			//Database Field Loading String:
			SQL_FetchString(hndl, 3, Buffer, 64);

			//Print:
			if(Client > 0)
			{

				//Print:
				PrintToConsole(Client, "%s: %i <%s>", Map, SpawnId, Buffer);
			}

			//Override:
			else
			{

				//Print:
				PrintToServer("%s %i <%s>", Map, SpawnId, Buffer);
			}
		}
	}
}

String:ServerMap()
{

	//Declare:
	decl String:Map[64];

	//Initialize:
	GetCurrentMap(Map, sizeof(Map));

	//Return
	return Map;
}