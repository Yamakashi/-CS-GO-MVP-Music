/* [ Includes ] */
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <clientprefs>

/* [ Compiler Options ] */
#pragma newdecls required
#pragma semicolon 1

/* [ Defines ] */
#define PluginTag 	"{darkred}[ {lightred}★{darkred} MVP Music {lightred}★ {darkred}]{default}"

/* [ Handles ] */
Handle g_hCookie, g_hCookie2, g_hCookie3, g_hCookie4;

/* [ Arrays ] */
ArrayList g_arSounds;

/* [ Chars ] */
char g_sLogFile[256];
char g_sMusicName[65][256];
char g_sFlag[65][128];
char g_sPlayerMusic[65][128];

/* [ Integers ] */
int g_iClientMusic[MAXPLAYERS + 1];
int g_iClientVolume[MAXPLAYERS + 1];
int g_iFirstConnect[MAXPLAYERS + 1];
int g_iMusics;

/* [ Floats ] */
float g_fClientVolume[MAXPLAYERS + 1];

/* [ Plugin Author and Information ] */
public Plugin myinfo = 
{
	name = "[CS:GO] MVP Music", 
	author = "Yamakashi", 
	description = "Plugin umożliwia ustawienie własnej muzyki MVP.", 
	version = "1.0", 
	url = "https://steamcommunity.com/id/yamakashisteam"
};

/* [ Plugin Startup ] */
public void OnPluginStart()
{
	/* [ Commands ] */
	RegConsoleCmd("sm_mvp", MvpMusic_CMD, "[MVP Music] Główne menu");
	RegConsoleCmd("sm_mvpmusic", MvpMusic_CMD, "[MVP Music] Główne menu");
	RegConsoleCmd("sm_music", MvpMusic_CMD, "[MVP Music] Główne menu");
	RegConsoleCmd("sm_muzyka", MvpMusic_CMD, "[MVP Music] Główne menu");
	RegConsoleCmd("sm_testmvp", TestMvp_CMD, "[MVP Music] Puszcza losową piosenkę");
	
	/* [ Cookies ] */
	g_hCookie = RegClientCookie("yamakashi_mvpmusic", "Głośność pisoenki", CookieAccess_Private);
	g_hCookie2 = RegClientCookie("yamakashi_mvpmusic2", "Wyświetlana głośność piosenki", CookieAccess_Private);
	g_hCookie3 = RegClientCookie("yamakashi_mvpmusic3", "Numer piosenki", CookieAccess_Private);
	g_hCookie4 = RegClientCookie("yamakashi_mvpmusic4", "Pierwsze połączenie", CookieAccess_Private);
	
	/* [ Hooks ] */
	HookEvent("round_mvp", Event_RoundMVP);
	
	/* [ Arrays ] */
	g_arSounds = new ArrayList(512);
	
	/* [ Check Player ] */
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			OnClientCookiesCached(i);
			
	/* [ LogFile ] */
	char sDate[16];
	FormatTime(sDate, sizeof(sDate), "%Y-%m-%d", GetTime());
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/yLogs/%s.log", sDate);
}

/* [ Standart Actions ] */
public void OnClientAuthorized(int client, const char[] sAuth)
{
	g_iClientMusic[client] = -1;
	g_iClientVolume[client] = 100;
	g_fClientVolume[client] = 1.0;
}

public void OnClientPutInServer(int client)
{
	g_iFirstConnect[client] = 1;
}

public void OnClientCookiesCached(int client)
{
	char sValue[16];
	GetClientCookie(client, g_hCookie4, sValue, sizeof(sValue));
	g_iFirstConnect[client] = StringToInt(sValue);
	if(!g_iFirstConnect[client])
	{
		g_iClientMusic[client] = -1;
		g_iClientVolume[client] = 100;
		g_fClientVolume[client] = 1.0;
		return;
	}	
	GetClientCookie(client, g_hCookie, sValue, sizeof(sValue));
	g_fClientVolume[client] = StringToFloat(sValue);
	GetClientCookie(client, g_hCookie2, sValue, sizeof(sValue));
	g_iClientVolume[client] = StringToInt(sValue);
	GetClientCookie(client, g_hCookie3, sValue, sizeof(sValue));
	g_iClientMusic[client] = StringToInt(sValue);
}

public void OnClientDisconnect(int client)
{
	if (AreClientCookiesCached(client))
	{
		char sValue[16];
		Format(sValue, sizeof(sValue), "%.2f", g_fClientVolume[client]);
		SetClientCookie(client, g_hCookie, sValue);
		Format(sValue, sizeof(sValue), "%d", g_iClientVolume[client]);
		SetClientCookie(client, g_hCookie2, sValue);
		Format(sValue, sizeof(sValue), "%d", g_iClientMusic[client]);
		SetClientCookie(client, g_hCookie3, sValue);
		Format(sValue, sizeof(sValue), "%d", g_iFirstConnect[client]);
		SetClientCookie(client, g_hCookie4, sValue);
	}
	g_iClientMusic[client] = -1;
	g_iClientVolume[client] = 100;
	g_fClientVolume[client] = 1.0;
	g_iFirstConnect[client] = 0;
}

public void OnMapStart()
{
	MVP_LoadMusic();
	MVP_Initialize_Items();
	MVP_LoadTestMvp(g_arSounds);
}

/* [ Events ] */
public Action Event_RoundMVP(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if(g_iClientMusic[client] > -1)
	{
		CPrintToChatAll("%s {lime}Aktualnie leci piosenka: {lightred}%s{lime}, która należy do gracza {lightred}%N{lime}.", PluginTag, g_sMusicName[g_iClientMusic[client]], client);
		for(int i = 1; i < MaxClients; i++)
			if (IsValidClient(i))
			{
				PrecacheSound(g_sPlayerMusic[g_iClientMusic[client]]);
				ClientCommand(i, "playgamesound Music.StopAllMusic");
				EmitSoundToClient(i, g_sPlayerMusic[g_iClientMusic[client]], _, _, _, _, g_fClientVolume[i]);
			}
	}
	return Plugin_Continue;
}

/* [ Commands ] */
public Action MvpMusic_CMD(int client, int args)
{
	char sBuffer[512];
	Menu mvp = new Menu(MvpMusic_Handler);
	
	Format(sBuffer, sizeof(sBuffer), "[ # MVP Music :: Główne Menu # ]\n");
	if (g_iClientMusic[client] == -1)
		Format(sBuffer, sizeof(sBuffer), "%s\nAktualna piosenka: Brak\n", sBuffer);
	else
		Format(sBuffer, sizeof(sBuffer), "%s\nAktualna piosenka: %s\n", sBuffer, g_sMusicName[g_iClientMusic[client]]);
	Format(sBuffer, sizeof(sBuffer), "%s\nAktualna głośność: %d%%%", sBuffer, g_iClientVolume[client]);
	mvp.SetTitle(sBuffer);
	mvp.AddItem("1", "»Wybierz muzykę.");
	mvp.AddItem("2", "»Dostosuj głośność");
	mvp.Display(client, MENU_TIME_FOREVER);
}

public int MvpMusic_Handler(Menu menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char sItem[32];
		menu.GetItem(position, sItem, sizeof(sItem));
		if (StrEqual(sItem, "1"))
			ShowMvpList(client);
		else if (StrEqual(sItem, "2"))
			Mvp_ChangeVolume(client);
	}
	else if (action == MenuAction_End)
		menu.Close();
}

public void ShowMvpList(int client)
{
	char sNumber[128], sText[512];
	Menu mvp_music = new Menu(ShowMvpList_Handler);
	mvp_music.SetTitle("[ # MVP Music :: Wybierz Piosenkę # ]");
	if(g_iClientMusic[client] > -1)
		mvp_music.AddItem("default", "Usuń piosenkę");
	for(int i = 0; i < g_iMusics; i++)
	{
		Format(sNumber, sizeof(sNumber), "%d", i);
		if(g_iClientMusic[client] == i)
		{
			Format(sText, sizeof(sText), "%s | [ # Aktualna # ]", g_sMusicName[i]);
			mvp_music.AddItem(sNumber, sText, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(sText, sizeof(sText), "%s", g_sMusicName[i]);
			mvp_music.AddItem(sNumber, sText, CheckFlags(client, g_sFlag[i]));
		}
	}
	mvp_music.Display(client, MENU_TIME_FOREVER);
}

public int ShowMvpList_Handler(Menu menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char sItem[512];
		menu.GetItem(position, sItem, sizeof(sItem));
		int music = StringToInt(sItem);
		
		if(StrEqual(sItem, "default"))
		{
			g_iClientMusic[client] = -1;
			CPrintToChat(client, "%s Usunąłeś swoją piosenkę.", PluginTag);
		}
		else
		{
			g_iClientMusic[client] = music;
			CPrintToChat(client, "%s Ustawiłeś piosenkę: {lime}%s{default} .", PluginTag, g_sMusicName[g_iClientMusic[client]]);
		}
		ShowMvpList(client);
	}
	else if (action == MenuAction_End)
		menu.Close();
}

public void Mvp_ChangeVolume(int client)
{
	char sBuffer[512];
	Menu volume = new Menu(ChangeVolume_Handler);
	Format(sBuffer, sizeof(sBuffer), "[ # MVP Music :: Zmiana głośności # ]");
	Format(sBuffer, sizeof(sBuffer), "%s\nAktualna głośność: %d%%%", sBuffer, g_iClientVolume[client]);
	Format(sBuffer, sizeof(sBuffer), "%s\nAby przetestować głośność wpisz !testmvp\n ", sBuffer);
	volume.SetTitle(sBuffer);
	volume.AddItem("1", "Pogłoś o 10%");
	volume.AddItem("2", "Ścisz o 10%");
	volume.AddItem("3", "Wycisz");
	volume.Display(client, MENU_TIME_FOREVER);
}

public int ChangeVolume_Handler(Menu menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char sItem[32];
		menu.GetItem(position, sItem, sizeof(sItem));
		if (StrEqual(sItem, "1"))
		{
			g_fClientVolume[client] = g_fClientVolume[client] + 0.1;
			g_iClientVolume[client] += 10;
			if (g_fClientVolume[client] > 1.0)
			{
				g_fClientVolume[client] = 1.0;
				g_iClientVolume[client] = 100;
			}
		}
		else if (StrEqual(sItem, "2"))
		{
			g_fClientVolume[client] = g_fClientVolume[client] - 0.1;
			g_iClientVolume[client] -= 10;
			if(g_fClientVolume[client] < 0.0)
			{
				g_fClientVolume[client] = 0.0;
				g_iClientVolume[client] = 0;
			}
		}
		else if(StrEqual(sItem, "3"))
		{
			g_fClientVolume[client] = 0.0;
			g_iClientVolume[client] = 0;
		}
		
		Mvp_ChangeVolume(client);
		
	}
	else if (action == MenuAction_End)
		menu.Close();
}

public Action TestMvp_CMD(int client, int args)
{
	char szSound[512] = "mvp_yamakashi/";
	GetSound(g_arSounds, szSound, sizeof(szSound));
	
	ClientCommand(client, "playgamesound Music.StopAllMusic");
	EmitSoundToClient(client, szSound, _, _, _, _, g_fClientVolume[client]);
}

/* [ Config ] */
public void MVP_LoadMusic()
{
	int Music_ID;
	KeyValues kv = CreateKeyValues("MVP Musics");
	char sPathMusicsCfg[256], stPathMusicsCfg[256];
	
	Format(stPathMusicsCfg, sizeof(stPathMusicsCfg), "configs/MvpMusics.cfg");
	BuildPath(Path_SM, sPathMusicsCfg, sizeof(sPathMusicsCfg), stPathMusicsCfg);

	kv.ImportFromFile(sPathMusicsCfg);
	if (!kv.GotoFirstSubKey())
	{
		LogError("[X MVP MUSIC X]	Nie znaleziono piosenek.");
		SetFailState("[X MVP MUSIC X]	Nie znaleziono piosenek.");
		return;
	}
	do
	{
		char sFlag[128];
		kv.GetSectionName(g_sMusicName[Music_ID], 512);
		kv.GetString("song_file", g_sPlayerMusic[Music_ID], 255);
		kv.GetString("flag", sFlag, sizeof(sFlag));
		strcopy(g_sFlag[Music_ID], sizeof(g_sFlag[]), sFlag);
		Music_ID++;
	} while (kv.GotoNextKey());
	delete kv;
	g_iMusics = Music_ID;
	LogMessage("[✔ MVP MUSIC ✔]	| Załadowano %i piosenek z configu!", Music_ID);
	return;
}

public void MVP_Initialize_Items()
{
	KeyValues kv = CreateKeyValues("MVP Musics");
	if (!kv.ImportFromFile("configs/MvpMusics.cfg"))return;
	if (!kv.GotoFirstSubKey())return;
	do
	{
		char sMp3Path[128];
		kv.GetString("mp3", sMp3Path, sizeof(sMp3Path));
		
		char sBuffer[512];
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sMp3Path);
		AddFileToDownloadsTable(sBuffer);
		PrecacheSound(sMp3Path, true);
		
	} while (kv.GotoNextKey());
	delete kv;
}

/* [ Helpers ] */
int MVP_LoadTestMvp(ArrayList arraySounds)
{
	arraySounds.Clear();
	char soundPathFull[PLATFORM_MAX_PATH];
	Format(soundPathFull, sizeof(soundPathFull), "sound/mvp_yamakashi/");
	DirectoryListing pluginsDir = OpenDirectory(soundPathFull);
	
	if (pluginsDir != null)
	{
		char fileName[128];
		while (pluginsDir.GetNext(fileName, sizeof(fileName)))
		{
			int extPosition = strlen(fileName) - 4;
			if (StrContains(fileName, ".mp3", false) == extPosition)
			{
				char soundName[512];
				Format(soundName, sizeof(soundName), "sound/mvp_yamakashi/%s", fileName);
				AddFileToDownloadsTable(soundName);
				
				Format(soundName, sizeof(soundName), "mvp_yamakashi/%s", fileName);
				PrecacheSound(soundName, true);
				arraySounds.PushString(soundName);
			}
		}
	}
	return arraySounds.Length;
}

bool GetSound(ArrayList arraySounds, char[] szSound, int soundSize)
{
	if (arraySounds.Length <= 0)return false;
	
	int soundToPlay = GetRandomInt(0, arraySounds.Length - 1);
	
	arraySounds.GetString(soundToPlay, szSound, soundSize);
	
	if (arraySounds.Length == 0)
		MVP_LoadTestMvp(arraySounds);
	
	return true;
}

public int CheckFlags(int client, const char[] sFlag)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT) return ITEMDRAW_DEFAULT;
	if(GetUserFlagBits(client) & ReadFlagString(sFlag)) return ITEMDRAW_DEFAULT;
	if(StrEqual(sFlag, "")) return ITEMDRAW_DEFAULT;
	
	return ITEMDRAW_DISABLED;
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	if(IsFakeClient(client)) return false;
	return IsClientInGame(client);
}