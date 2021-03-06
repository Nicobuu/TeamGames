bool:ExistMenuItemsConfigFile()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), MODULES_CONFIG);

	return FileExists(sPath);
}

CreateModulesConfigFileIfNotExist()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), MODULES_CONFIG);

	CreateDirectoryPath(sPath, 511, true);

	if (!FileExists(sPath, false)) {
		new Handle:hFile = OpenFile(sPath, "w");
		WriteFileLine(hFile, "\"Root\"");
		WriteFileLine(hFile, "{");
		WriteFileLine(hFile, "	\"%s\"", MODCONF_MENUITEMS);
		WriteFileLine(hFile, "	{");
		WriteFileLine(hFile, "		\"Core_TeamsMenu\"{}");
		WriteFileLine(hFile, "		\"Core_GamesMenu-TeamGame\"{}");
		WriteFileLine(hFile, "		\"Core_GamesMenu-RedOnly\"{}");
		WriteFileLine(hFile, "		\"Core_FencesMenu\"{}");
		WriteFileLine(hFile, "		\"Core_StopGame\"{\"separator\" \"prepend\"}");
		WriteFileLine(hFile, "		\"Core_GamesRoundLimitInfo\"{\"disabled\" \"1\"}");
		WriteFileLine(hFile, "		\"Core_Separator\"{}");
		WriteFileLine(hFile, "	}");
		WriteFileLine(hFile, "	\"%s\"{}", MODCONF_GAMES);
		WriteFileLine(hFile, "}");
		CloseHandle(hFile);
	}
}

SaveKvToFile(Handle:hKV, Handle:hFile, lvl = 0)
{
	decl String:sKey[512], String:sParentTabs[128];

	do {
		KvGetSectionName(hKV, sKey, sizeof(sKey));
		GetTabs(sParentTabs, sizeof(sParentTabs), lvl);

		if (KvGotoFirstSubKey(hKV, false)) {
			WriteFileLine(hFile, "%s\"%s\"", sParentTabs, sKey);
			WriteFileLine(hFile, "%s{", sParentTabs);

			SaveKvToFile(hKV, hFile, lvl + 1);
			KvGoBack(hKV);

			WriteFileLine(hFile, "%s}", sParentTabs);
		} else {
			decl String:sChildTabs[128];
			decl String:sKeyValue[512], String:sKeyName[512];

			GetTabs(sChildTabs, sizeof(sChildTabs), lvl);
			KvGetSectionName(hKV, sKeyName, sizeof(sKeyName));

			if (KvGetDataType(hKV, NULL_STRING) != KvData_None) {
				KvGetString(hKV, NULL_STRING, sKeyValue, sizeof(sKeyValue));
				WriteFileLine(hFile, "%s\"%s\"\t\"%s\"", sChildTabs, sKeyName, sKeyValue);
			} else {
				WriteFileLine(hFile, "%s\"%s\"{}", sParentTabs, sKeyName);
			}
		}
	}
	while (KvGotoNextKey(hKV, false));
}

GetTabs(String:sBuffer[], iSize, iCount)
{
	strcopy(sBuffer, iSize, "");

	for (new i = 0; i < iCount; i++)
		Format(sBuffer, iSize, "%s\t", sBuffer);
}

GetSeparatorType(const String:sSeparator[])
{
	if (strlen(sSeparator) == 0 || StrEqual(sSeparator, "none"))
		return 0;
	else if (StrEqual(sSeparator, "prepend", false))
		return -1;
	else if (StrEqual(sSeparator, "append", false))
		return 1;
	else if (StrEqual(sSeparator, "both", false))
		return 2;

	return 0;
}

SaveMenuItemToConfig(const String:sID[TG_MODULE_ID_LENGTH], String:sName[TG_MODULE_NAME_LENGTH])
{
	#if defined DEBUG
	LogMessage("[TG DEBUG] SaveMenuItemToConfig(%s, %s)", sID, sName);
	#endif

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), MODULES_CONFIG);

	new Handle:hKV = CreateKeyValues("Root");
	FileToKeyValues(hKV, sPath);

	KvJumpToKey(hKV, MODCONF_MENUITEMS);

	KvJumpToKey(hKV, sID, true);
	KvSetString(hKV, "name", sName);

	if (!GetConVarBool(g_hModuleDefVisibility)) {
		KvSetNum(hKV, "visibility", 0);
	}

	KvRewind(hKV);

	new Handle:hFile = OpenFile(sPath, "w");
	SaveKvToFile(hKV, hFile);

	CloseHandle(hFile);
	CloseHandle(hKV);
}

SaveGameToConfig(const String:sID[TG_MODULE_ID_LENGTH], const String:sName[TG_MODULE_NAME_LENGTH], TG_GameType:iType, bool:bHealthBar)
{
	#if defined DEBUG
	LogMessage("[TG DEBUG] SaveGameToConfig(%s, %s)", sID, sName);
	#endif

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), MODULES_CONFIG);

	new Handle:hKV = CreateKeyValues("Root");
	FileToKeyValues(hKV, sPath);

	KvJumpToKey(hKV, MODCONF_GAMES);

	KvJumpToKey(hKV, sID, true);
	KvSetString(hKV, "name", sName);

	new String:sGameTypes[32];
	if (iType & TG_TeamGame) {
		strcopy(sGameTypes, sizeof(sGameTypes), "TeamGame, ");
	}
	if (iType & TG_RedOnly) {
		Format(sGameTypes, sizeof(sGameTypes), "%sRedOnly, ", sGameTypes);
	}
	sGameTypes[strlen(sGameTypes) - 2] = '\0';
	KvSetString(hKV, "gametypes", sGameTypes);

	if (!bHealthBar) {
		KvSetNum(hKV, "enemyhealthbar", 0);
	}

	if (!GetConVarBool(g_hModuleDefVisibility)) {
		KvSetNum(hKV, "visibility", 0);
	}

	KvRewind(hKV);

	new Handle:hFile = OpenFile(sPath, "w");
	SaveKvToFile(hKV, hFile);

	CloseHandle(hFile);
	CloseHandle(hKV);
}

LoadMenuItemsConfig()
{
	#if defined DEBUG
	LogMessage("[TG DEBUG] LoadMenuItemsConfig()");
	#endif
	g_iMenuItemListEnd = 0;

	decl String:sPath[PLATFORM_MAX_PATH], String:sKey[64];
	BuildPath(Path_SM, sPath, sizeof(sPath), MODULES_CONFIG);

	new Handle:hKV = CreateKeyValues("Root");

	if (!FileToKeyValues(hKV, sPath))
		return;

	KvJumpToKey(hKV, MODCONF_MENUITEMS);

	if (KvGotoFirstSubKey(hKV)) {
		new String:sID[TG_MODULE_ID_LENGTH];

		do {
			if (g_iMenuItemListEnd >= MAX_MENU_ITEMS)
				break;

			KvGetSectionName(hKV, sID, sizeof(sID));

			if (KvGetNum(hKV, "disabled", 0) == 1) {
				AddModuleToDisabledList(TG_MenuItem, sID);
				continue;
			}

			strcopy(g_MenuItemList[g_iMenuItemListEnd][Id], TG_MODULE_ID_LENGTH, sID);
			KvGetString(hKV, "separator", sKey, sizeof(sKey), "none");
			g_MenuItemList[g_iMenuItemListEnd][Separator] = GetSeparatorType(sKey);

			g_MenuItemList[g_iMenuItemListEnd][Visible] = bool:KvGetNum(hKV, "visibility", 1);

			if (StrContains(g_MenuItemList[g_iMenuItemListEnd][Id], "Core_", false) == 0)
				g_MenuItemList[g_iMenuItemListEnd][Used] = true;
			else
				g_MenuItemList[g_iMenuItemListEnd][Used] = false;

			#if defined DEBUG
			LogMessage("[TG DEBUG] \tAdded item(%d) sID = '%s', name = '%s', used = '%d'.", g_iMenuItemListEnd, g_MenuItemList[g_iMenuItemListEnd][Id], g_MenuItemList[g_iMenuItemListEnd][DefaultName], g_MenuItemList[g_iMenuItemListEnd][Used]);
			#endif

			g_iMenuItemListEnd++;
		}
		while (KvGotoNextKey(hKV));
	}

	CloseHandle(hKV);
}

LoadGamesMenuConfig()
{
	#if defined DEBUG
	LogMessage("[TG DEBUG] LoadGamesMenuConfig()");
	#endif
	g_iGameListEnd = 0;

	decl String:sPath[PLATFORM_MAX_PATH], String:sKey[64];
	BuildPath(Path_SM, sPath, sizeof(sPath), MODULES_CONFIG);

	new Handle:hKV = CreateKeyValues("Root");

	if (!FileToKeyValues(hKV, sPath))
		return;

	KvJumpToKey(hKV, MODCONF_GAMES);

	if (KvGotoFirstSubKey(hKV)) {
		do {
			if (g_iGameListEnd >= MAX_GAMES)
				break;

			if (KvGetNum(hKV, "disabled", 0) == 1)
				continue;

			KvGetString(hKV, "separator", sKey, sizeof(sKey), "none");
			g_GameList[g_iGameListEnd][Separator] = GetSeparatorType(sKey);

			g_GameList[g_iGameListEnd][Used] = false;
			KvGetSectionName(hKV, g_GameList[g_iGameListEnd][Id], TG_MODULE_ID_LENGTH);
			g_GameList[g_iGameListEnd][Visible] = bool:KvGetNum(hKV, "visibility", 1);

			g_GameList[g_iGameListEnd][HealthBarVisibility] = bool:KvGetNum(hKV, "enemyhealthbar", 1);

			#if defined DEBUG
			LogMessage("[TG DEBUG] \tAdded game(%d) sID = '%s', name = '%s'.", g_iGameListEnd, g_GameList[g_iGameListEnd][Id], g_GameList[g_iGameListEnd][DefaultName]);
			#endif

			g_iGameListEnd++;
		}
		while (KvGotoNextKey(hKV));
	}

	CloseHandle(hKV);
}

public DTC_OnFile(String:sFile[], String:sPrefixName[DTC_MAX_NAME_LEN], Handle:hArgs)
{
	decl String:m_sFile[PLATFORM_MAX_PATH];
	strcopy(m_sFile, sizeof(m_sFile), sFile);
	new bool:bKnown = true;

	#if defined DEBUG
	LogMessage("[TG DEBUG] Download '%s' '%s'", sPrefixName, sFile);
	#endif

	if (StrEqual(sPrefixName, "GamePrepare", false)) {
		new i = DTC_GetArgNum(hArgs, 1, 0);

		if (i > 0 || i < 6) {
			ReplaceStringEx(m_sFile, sizeof(m_sFile), "sound/", "");
			PrecacheSoundAny(m_sFile, true);
			strcopy(g_sGamePrepare[i], PLATFORM_MAX_PATH, m_sFile);
		}
	} else if (StrEqual(sPrefixName, "GameStart", false)) {
		ReplaceStringEx(m_sFile, sizeof(m_sFile), "sound/", "");
		PrecacheSoundAny(m_sFile, true);
		strcopy(g_sGameStart, PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "GameEnd", false)) {
		new TG_Team:iTeam = GetTGTeamFromDTCArg(hArgs, 1);

		if (iTeam == TG_ErrorTeam) {
			LogError("Bad file prefix argument \"%d\" (file: \"%s\", prefix: \"%s\") !", 1, m_sFile, sPrefixName);
			return;
		}

		ReplaceStringEx(m_sFile, sizeof(m_sFile), "sound/", "");
		PrecacheSoundAny(m_sFile, true);

		strcopy(g_sGameEnd[iTeam], PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "PlayerSkin", false)) {
		new TG_Team:iTeam = GetTGTeamFromDTCArg(hArgs, 1);

		if (iTeam == TG_ErrorTeam) {
			LogError("Bad file prefix argument \"%d\" (file: \"%s\", prefix: \"%s\") !", 1, m_sFile, sPrefixName);
			return;
		}

		PrecacheModel(m_sFile);
		strcopy(g_sTeamSkin[iTeam], PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "Mark", false)) {
		new TG_Team:iTeam = GetTGTeamFromDTCArg(hArgs, 1);

		if (iTeam == TG_ErrorTeam) {
			LogError("Bad file prefix argument \"%d\" (file: \"%s\", prefix: \"%s\") !", 1, m_sFile, sPrefixName);
			return;
		}

		PrecacheDecal(m_sFile);

		strcopy(g_Mark[iTeam][Sprite], PLATFORM_MAX_PATH, m_sFile);
		g_Mark[iTeam][High] = DTC_GetArgFloat(hArgs, 2, 12.0);
		g_Mark[iTeam][Scale] = DTC_GetArgFloat(hArgs, 3, 1.0);
		Format(g_Mark[iTeam][Color], PLATFORM_MAX_PATH, "%d %d %d", DTC_GetArgNum(hArgs, 4, 255), DTC_GetArgNum(hArgs, 5, 255), DTC_GetArgNum(hArgs, 6, 255));
		g_Mark[iTeam][Alpha] = DTC_GetArgNum(hArgs, 7, 255);
	} else if (StrEqual(sPrefixName, "MarkLaser", false)) {
		new TG_Team:iTeam = GetTGTeamFromDTCArg(hArgs, 1);

		if (iTeam == TG_ErrorTeam) {
			LogError("Bad file prefix argument \"%d\" (file: \"%s\", prefix: \"%s\") !", 1, m_sFile, sPrefixName);
			return;
		}

		g_Mark[iTeam][LaserSprite] = PrecacheModel(m_sFile);
		g_Mark[iTeam][LaserColor][0] = DTC_GetArgNum(hArgs, 2, 255);
		g_Mark[iTeam][LaserColor][1] = DTC_GetArgNum(hArgs, 3, 255);
		g_Mark[iTeam][LaserColor][2] = DTC_GetArgNum(hArgs, 4, 255);
		g_Mark[iTeam][LaserColor][3] = DTC_GetArgNum(hArgs, 5, 255);
		g_Mark[iTeam][LaserWidth] = DTC_GetArgFloat(hArgs, 6, 1.0);
	} else if (StrEqual(sPrefixName, "TeamOverlay", false)) {
		new TG_Team:iTeam = GetTGTeamFromDTCArg(hArgs, 1);

		if (iTeam == TG_ErrorTeam) {
			LogError("Bad file prefix argument \"%d\" (file: \"%s\", prefix: \"%s\") !", 1, m_sFile, sPrefixName);
			return;
		}

		ReplaceStringEx(m_sFile, sizeof(m_sFile), "materials/", "");
		PrecacheDecal(m_sFile);
		strcopy(g_Overlay[iTeam][OverlayName], PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "RebelSound", false)) {
		ReplaceStringEx(m_sFile, sizeof(m_sFile), "sound/", "");
		PrecacheSoundAny(m_sFile, true);
		strcopy(g_sRebelSound, PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "FenceCorner", false)) {
		if (GetConVarInt(g_hFenceType) == 0 || IsFenceDisabledOnCurrentMap()) {
			g_bFencesMenuMapVisibility = false;
			return;
		}

		g_bFencesMenuMapVisibility = true;

		PrecacheModel(m_sFile);
		strcopy(g_sFenceCornerModel, PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "FenceMaterial", false)) {
		if (GetConVarInt(g_hFenceType) == 0 || IsFenceDisabledOnCurrentMap()) {
			g_bFencesMenuMapVisibility = false;
			return;
		}

		g_bFencesMenuMapVisibility = true;

		g_fFenceWidth = DTC_GetArgFloat(hArgs, 1, 2.0);
		g_iFenceColor[0] = DTC_GetArgNum(hArgs, 2, 255);
		g_iFenceColor[1] = DTC_GetArgNum(hArgs, 3, 255);
		g_iFenceColor[2] = DTC_GetArgNum(hArgs, 4, 255);
		g_iFenceColor[3] = DTC_GetArgNum(hArgs, 5, 255);

		ReplaceStringEx(m_sFile, sizeof(m_sFile), "materials/", "");
		PrecacheModel(m_sFile);

		strcopy(g_sFenceMaterial, PLATFORM_MAX_PATH, m_sFile);
	} else if (StrEqual(sPrefixName, "HealthBar", false)) {
		new iHealth = DTC_GetArgNum(hArgs, 1, 0) / 10;

		if (iHealth >= 1 && iHealth <= 10) {
			strcopy(g_iHPBarTemplate[iHealth][Sprite], PLATFORM_MAX_PATH, sFile);
			PrecacheDecal(sFile);

			g_iHPBarTemplate[iHealth][Offset] = DTC_GetArgFloat(hArgs, 2, 12.0);
			g_iHPBarTemplate[iHealth][Scale] = DTC_GetArgFloat(hArgs, 3, 1.0);
			Format(g_iHPBarTemplate[iHealth][Color], 12, "%d %d %d", DTC_GetArgNum(hArgs, 4, 255), DTC_GetArgNum(hArgs, 5, 255), DTC_GetArgNum(hArgs, 6, 255));
			g_iHPBarTemplate[iHealth][Alpha] = DTC_GetArgNum(hArgs, 7, 255);

			g_iHPBarTemplate[iHealth][Used] = true;
			bKnown = true;
		} else {
			LogError("Bad file prefix argument \"1\" (file: \"%s\", prefix: \"%s\") !", sFile, sPrefixName);
		}
	} else {
		bKnown = false;
	}

	if (!Call_OnDownloadFile(m_sFile, sPrefixName, hArgs, bKnown) && sPrefixName[0] != '\0')
		LogError("Unknown file prefix \"%s\" (file: \"%s\") !", sPrefixName, m_sFile);
}

public DTC_OnCreateConfig(String:sConfigPath[], Handle:hConfigFile)
{
	WriteFileLine(hConfigFile, "// Everything here will player download");
	WriteFileLine(hConfigFile, "// comment");
	WriteFileLine(hConfigFile, "# comment");
	WriteFileLine(hConfigFile, "; comment");
	WriteFileLine(hConfigFile, "// <team> = {RedTeam, Red, 1} | {BlueTeam, Blue, 2} | {NoneTeam, None, 0}\n");
	WriteFileLine(hConfigFile, "// [GamePrepare <time left>]				// Sound hFile played in preparation (<time left> sec. left) for game. (*.wav or *.mp3) (<time left> = 1|2|3|4|5)");
	WriteFileLine(hConfigFile, "// [GameStart] 								// Sound hFile played on game start. (*.wav or *.mp3)");
	WriteFileLine(hConfigFile, "// [GameEnd <team>] 						// Sound hFile played on game end when <team> win. (*.wav or *.mp3)");
	WriteFileLine(hConfigFile, "// [PlayerSkin <team>] 						// Model hFile used for <team> skin. (*.mdl)");
	WriteFileLine(hConfigFile, "// [Mark <team> <vertical offset> <scale>] 	// Material hFile used for <team> mark. (*.vmt), <offset> = +Z coordinate (float), <scale> = material scale - 1.0 = normal (float)\n");
}

TG_Team:GetTGTeamFromDTCArg(Handle:hArgs, iArg)
{
	if (hArgs == INVALID_HANDLE) {
		return TG_Team:TG_ErrorTeam;
	} else {
		decl String:sTeam[24];
		DTC_GetArg(hArgs, iArg, sTeam, sizeof(sTeam), "ERROR");
		return TG_GetTeamFromString(sTeam);
	}
}

static bool:IsFenceDisabledOnCurrentMap()
{
	decl String:sMap[64], String:sPath[PLATFORM_MAX_PATH];
	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "%s/%s.disabled", FENCES_CONFIGS, sMap);
	return FileExists(sPath, false);
}
