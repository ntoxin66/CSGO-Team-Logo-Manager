#include <sourcemod>
#include <sdktools>
#include <cstrike>
#pragma semicolon 1
#pragma newdecls required

Handle g_hTeamLogos = null;
Handle g_hTeamLogo1 = null;
Handle g_hTeamLogo2 = null;
Handle g_hTeamName1 = null;
Handle g_hTeamName2 = null;

Handle g_hRandomLogos = null;
bool g_bRandomLogos = false;

Handle g_hDefaultTeams = null;
bool g_bDefaultTeams = false;

Handle g_hTeamNames = null;
bool g_bTeamNames = false;

Handle g_hHalftimeTeamswitch = null;
bool g_bHalftimeTeamswitch = false;

Handle g_hAutoLogos = null;
bool g_bAutoLogos = false;

public Plugin myinfo =
{
    name = "Team Logo Management",
    author = "Neuro Toxin",
    description = "",
    version = "1.4.1"
};

public void OnPluginStart()
{
	g_hTeamLogo1 = FindConVar("mp_teamlogo_1");
	if (g_hTeamLogo1 == null)
	{
		SetFailState("Unable to cache convar handle for 'mp_teamlogo_1'");
		return;
	}
	HookConVarChange(g_hTeamLogo1, OnConvarChanged);
	
	g_hTeamLogo2 = FindConVar("mp_teamlogo_2");
	if (g_hTeamLogo2 == null)
	{
		SetFailState("Unable to cache convar handle for 'mp_teamlogo_2'");
		return;
	}
	HookConVarChange(g_hTeamLogo2, OnConvarChanged);
	
	g_hTeamName1 = FindConVar("mp_teamname_1");
	if (g_hTeamName1 == null)
	{
		SetFailState("Unable to cache convar handle for 'mp_teamname_1'");
		return;
	}
	
	g_hTeamName2 = FindConVar("mp_teamname_2");
	if (g_hTeamName2 == null)
	{
		SetFailState("Unable to cache convar handle for 'mp_teamname_2'");
		return;
	}

	g_hRandomLogos = CreateConVar("teamlogo_randomlogos", "0", "Enables selection of random team logos on map load.");
	g_bRandomLogos = GetConVarBool(g_hRandomLogos);
	HookConVarChange(g_hRandomLogos, OnConvarChanged);
	
	g_hDefaultTeams = CreateConVar("teamlogo_defaultlogos", "0", "Adds the Valve default logos to the team logo list if 'teamlogo_randomlogo' is set to 1.");
	g_bDefaultTeams = GetConVarBool(g_hDefaultTeams);
	HookConVarChange(g_hDefaultTeams, OnConvarChanged);
	
	g_hTeamNames = CreateConVar("teamlogo_teamnames", "0", "Team names will be loaded from .cfg files with the same name and location as the logo file.");
	g_bTeamNames = GetConVarBool(g_hTeamNames);
	HookConVarChange(g_hTeamNames, OnConvarChanged);
	
	g_hHalftimeTeamswitch = CreateConVar("teamlogo_halftime_teamswitch", "0", "Plugin will switch team logos and names at half time.");
	g_bHalftimeTeamswitch = GetConVarBool(g_hHalftimeTeamswitch);
	HookConVarChange(g_hHalftimeTeamswitch, OnConvarChanged);
	
	g_hAutoLogos = CreateConVar("teamlogo_autologos", "0", "Plugin will auto-select team logos based on player clan tags.");
	g_bAutoLogos = GetConVarBool(g_hAutoLogos);
	HookConVarChange(g_hAutoLogos, OnConvarChanged);
	
	HookEvent("announce_phase_end", OnAnnouncePhaseEnd);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);
	HookEvent("player_team", OnPlayerTeam, EventHookMode_Post);
}

public void OnConvarChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	if (cvar == g_hRandomLogos)
	{
		g_bRandomLogos = StringToInt(newVal) == 0 ? false : true;
		OnMapStart();
	}
	else if (cvar == g_hDefaultTeams)
	{
		g_bDefaultTeams = StringToInt(newVal) == 0 ? false : true;
		OnMapStart();
	}
	else if (cvar == g_hTeamNames)
	{
		g_bTeamNames = StringToInt(newVal) == 0 ? false : true;
		OnMapStart();
	}
	else if (cvar == g_hTeamLogo1)
	{
		if (g_bTeamNames && !StrEqual(oldVal, newVal))
			SetTeamName(newVal, 1);
	}
	else if (cvar == g_hTeamLogo2)
	{
		if (g_bTeamNames && !StrEqual(oldVal, newVal))
			SetTeamName(newVal, 2);
	}
	else if (cvar == g_hHalftimeTeamswitch)
	{
		g_bHalftimeTeamswitch = StringToInt(newVal) == 0 ? false : true;
	}
	else if (cvar == g_hAutoLogos)
	{
		g_bAutoLogos = StringToInt(newVal) == 0 ? false : true;
		if (g_bAutoLogos)
		{
			SetTeamAutoLogo(CS_TEAM_CT);
			SetTeamAutoLogo(CS_TEAM_T);
		}
	}
}

public void OnMapStart()
{
	if (g_hTeamLogos != null)
		CloseHandle(g_hTeamLogos);
	
	if (g_bRandomLogos)
		g_hTeamLogos = CreateArray(128);
		
	AddTeamLogosToDownloadTable();
	
	if (g_bDefaultTeams && g_bRandomLogos)
		AddDefaultTeamLogos();
}

public void OnConfigsExecuted()
{
	if (g_bRandomLogos)
	{
		int logocount = GetArraySize(g_hTeamLogos);
		if (logocount == 0)
		{
			PrintToServer("[SM] You can add team logos to 'resource/flash/econ/tournaments/teams/' or enable 'teamlogo_usedefaulticons'");
			return;	
		}
		
		SetTeamLogos(logocount);
	}
	
	if (g_bTeamNames)
		SetTeamNames();
}

stock void AddTeamLogosToDownloadTable()
{
	Handle dir = OpenDirectory("resource/flash/econ/tournaments/teams/");
	if (dir == null)
	{
		LogError("[SM] Unable to read directory: 'resource/flash/econ/tournaments/teams'");
		return;
	}
	
	FileType type;
	char filename[PLATFORM_MAX_PATH];
	char fullpath[PLATFORM_MAX_PATH];
	
	while (ReadDirEntry(dir, filename, sizeof(filename), type))
	{
		if (type != FileType_File)
			continue;
		
		if (!StrEqual(filename[strlen(filename) - 4], ".png"))
			continue;
		
		PrintToServer("[SM] Loading team logo: %s", filename);
		Format(fullpath, sizeof(fullpath), "resource/flash/econ/tournaments/teams/%s", filename);
		AddFileToDownloadsTable(fullpath);
		
		if (g_bRandomLogos)
		{
			filename[strlen(filename) - 4] = '\0';
			PushArrayString(g_hTeamLogos, filename);
		}
	}
	
	CloseHandle(dir);
}

stock void SetTeamLogos(int logocount)
{
	int team1logo; int team2logo;
	if (logocount == 1)
	{
		team1logo = 0;
		team2logo = 0;
	}
	else if (logocount == 2)
	{
		team1logo = GetRandomInt(0, 1);
		if (team1logo == 0)
			team2logo = 1;
		else
			team2logo = 0;
	}
	else
	{
		team1logo = GetRandomInt(0, logocount - 1);
		team2logo = GetRandomInt(0, logocount - 1);
		
		while (team1logo == team2logo)
			team2logo = GetRandomInt(0, logocount - 1);
	}

	char logo1[64]; char logo2[64];
	GetArrayString(g_hTeamLogos, team1logo, logo1, sizeof(logo1));
	GetArrayString(g_hTeamLogos, team2logo, logo2, sizeof(logo2));
	
	SetConVarString(g_hTeamLogo1, logo1);
	SetConVarString(g_hTeamLogo2, logo2);
	
	PrintToServer("[SM] mp_teamlogo_1 set to %s", logo1);
	PrintToServer("[SM] mp_teamlogo_2 set to %s", logo2);
}

stock void AddDefaultTeamLogos()
{
	PushArrayString(g_hTeamLogos, "3dm");
	PushArrayString(g_hTeamLogos, "ad");
	PushArrayString(g_hTeamLogos, "bravg");
	PushArrayString(g_hTeamLogos, "c9");
	PushArrayString(g_hTeamLogos, "cm");
	PushArrayString(g_hTeamLogos, "col");
	PushArrayString(g_hTeamLogos, "cw");
	PushArrayString(g_hTeamLogos, "dat");
	PushArrayString(g_hTeamLogos, "dig");
	PushArrayString(g_hTeamLogos, "eps");
	PushArrayString(g_hTeamLogos, "esc");
	PushArrayString(g_hTeamLogos, "flip");
	PushArrayString(g_hTeamLogos, "fntc");
	PushArrayString(g_hTeamLogos, "hlr");
	PushArrayString(g_hTeamLogos, "ibp");
	PushArrayString(g_hTeamLogos, "indw");
	PushArrayString(g_hTeamLogos, "lc");
	PushArrayString(g_hTeamLogos, "ldlc");
	PushArrayString(g_hTeamLogos, "lgb");
	PushArrayString(g_hTeamLogos, "mss");
	PushArrayString(g_hTeamLogos, "myxmg");
	PushArrayString(g_hTeamLogos, "navi");
	PushArrayString(g_hTeamLogos, "nip");
	PushArrayString(g_hTeamLogos, "penta");
	PushArrayString(g_hTeamLogos, "pkd");
	PushArrayString(g_hTeamLogos, "r");
	PushArrayString(g_hTeamLogos, "rgg");
	PushArrayString(g_hTeamLogos, "tit");
	PushArrayString(g_hTeamLogos, "v");
	PushArrayString(g_hTeamLogos, "v2");
	PushArrayString(g_hTeamLogos, "ve");
	PushArrayString(g_hTeamLogos, "vg");
	PushArrayString(g_hTeamLogos, "vp");
}

stock void SetTeamName(const char[] logo, int team)
{
	char cfgpath[PLATFORM_MAX_PATH]; char teamname[128];
	Format(cfgpath, sizeof(cfgpath), "resource/flash/econ/tournaments/teams/%s.cfg", logo);
	Handle cfgstream = OpenFile(cfgpath, "r");
	
	if (cfgstream == INVALID_HANDLE)
	{
		LogError("Teamname config not found for logo '%s'", logo);
		return;
	}
	
	if (ReadFileString(cfgstream, teamname, sizeof(teamname)) > 0)
	{
		if (team == 1)
			SetConVarString(g_hTeamName1, teamname);
		else
			SetConVarString(g_hTeamName2, teamname);
	}
	
	CloseHandle(cfgstream);
}

stock void SetTeamNames()
{
	char logo[128];
	GetConVarString(g_hTeamLogo1, logo, sizeof(logo));
	if (!StrEqual(logo, ""))
		SetTeamName(logo, 1);
	
	GetConVarString(g_hTeamLogo2, logo, sizeof(logo));
	if (!StrEqual(logo, ""))
		SetTeamName(logo, 2);
}

public Action OnAnnouncePhaseEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bTeamNames || !g_bHalftimeTeamswitch)
		return Plugin_Continue;
		
	char logo1[128]; char logo2[128];
	
	GetConVarString(g_hTeamLogo1, logo1, sizeof(logo1));
	if (StrEqual(logo1, ""))
		return Plugin_Continue;

	GetConVarString(g_hTeamLogo2, logo2, sizeof(logo2));
	if (StrEqual(logo2, ""))
		return Plugin_Continue;
		
	SetConVarString(g_hTeamLogo1, logo2);
	SetConVarString(g_hTeamLogo2, logo1);
	return Plugin_Continue;
}


public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bAutoLogos)
		return Plugin_Continue;
		
	SetTeamAutoLogo(CS_TEAM_T);
	SetTeamAutoLogo(CS_TEAM_CT);
	return Plugin_Continue;
}

public Action OnPlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bAutoLogos)
		return Plugin_Continue;
		
	SetTeamAutoLogo(CS_TEAM_T);
	SetTeamAutoLogo(CS_TEAM_CT);
	return Plugin_Continue;
}

public Action OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bAutoLogos)
		return Plugin_Continue;
		
	SetTeamAutoLogo(CS_TEAM_T);
	SetTeamAutoLogo(CS_TEAM_CT);
	return Plugin_Continue;
}

public void SetTeamAutoLogo(int team)
{
	char name[128];
	bool found = false;
	bool match = true;
	
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		if (GetClientTeam(i) != team)
			continue;
			
		char newname[128];
		CS_GetClientClanTag(i, newname, sizeof(newname));
		if (newname[0] != EOS)
		{
			if (found) {
				if (!StrEqual(name, newname))
				{
					match = false;
					return;
				}
			}
			else
			{
				found = true;
				strcopy(name, sizeof(name), newname);
			}
		}
	}
	
	if (team == CS_TEAM_CT)
		team = 1;
	else if (team == CS_TEAM_T)
		team = 2;
	
	if (found && match)
	{
		char logo[6];
		int j=0;
		for (int i=0; i<= 64; i++)
		{
			if (name[i] == EOS || j == 5)
			{
				logo[j] = EOS;
				break;
			}
			else if (IsCharAlpha(name[i]) || IsCharNumeric(name[i])) {
				logo[j] = name[i];
				j++;
			}
		}
		ServerCommand("mp_teamlogo_%d \"%s\"", team, logo);
	}
}