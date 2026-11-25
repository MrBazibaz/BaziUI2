local ns = BaziUI.Chat

local Players = {}
ns.Players = Players

-- Who is talking: whether a sender is a friend or a guild member (a mark
-- before their name in public channels, Channels.lua), and what the game
-- already knows about them for the tooltip on their name (Links.lua): class
-- and race (GetPlayerInfoByGUID, for anyone seen recently), and, for friends
-- and guild members, level, zone, rank and note from the friend list, the
-- Battle.net account and the guild roster. /who isn't asked: SendWho is
-- restricted to Blizzard's UI. Only readable GUIDs (eventArgs[12]) are
-- looked up; secret ones give nothing.
local L = ns.L

-- The guild roster by GUID: { level, rank, zone, note }, from the game's
-- roster updates; and GUIDs by name (with and without the realm).
local roster = {}
local rosterNames = {}
-- Other players' guilds by GUID (false: none), this session. The game only
-- tells a player's guild while it has them as a unit (under the mouse,
-- targeted, a nameplate, in the group): seen once, their name in the chat
-- shows it later. /who (SendWho) is restricted to Blizzard's UI.
local guildOf = {}
-- Players remembered; past GUILD_MEMORY the memory starts over.
local guildCount = 0
local GUILD_MEMORY = 5000

local function Learn(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end
	local guid = UnitGUID(unit)
	if not guid or not canaccessvalue(guid) then
		return
	end
	local guildName = GetGuildInfo(unit)
	if guildName == nil or canaccessvalue(guildName) then
		if guildOf[guid] == nil then
			guildCount = guildCount + 1
			if guildCount > GUILD_MEMORY then
				wipe(guildOf)
				guildCount = 1
			end
		end
		guildOf[guid] = guildName or false
	end
end

-- A player's guild: from their unit if the game has one for them now,
-- else as last seen.
local function GuildOf(guid)
	local unit = UnitTokenFromGUID and UnitTokenFromGUID(guid)
	if unit and canaccessvalue(unit) then
		Learn(unit)
	end
	return guildOf[guid] or nil
end

local function Readable(value)
	return value ~= nil and canaccessvalue(value)
end

local function IsBattleNetFriend(guid)
	return C_BattleNet and C_BattleNet.GetAccountInfoByGUID and C_BattleNet.GetAccountInfoByGUID(guid) ~= nil
end

local function IsCharacterFriend(guid)
	if not C_FriendList or not C_FriendList.IsFriend then
		return false
	end
	if C_FriendList.IsLegacyFriendSystemEnabled and not C_FriendList.IsLegacyFriendSystemEnabled() then
		return false
	end
	return C_FriendList.IsFriend(guid)
end

-- What the game knows of a player by GUID: class, race and sex, in the
-- game's English names (GetPlayerInfoByGUID: "PRIEST", "Scourge" for the
-- undead, sex 2 male and 3 female), for the race and class icons before names
-- (Channels.lua). Kept once known, in a bounded memory like the guilds. A
-- player the client hasn't met gives nothing the first time (the game asks
-- the server then); a later line finds them.
local infos = {}
local infoCount = 0

function Players.Info(guid)
	if not Readable(guid) then
		return nil
	end
	local info = infos[guid]
	if info then
		return info
	end
	local _, englishClass, _, englishRace, sex = GetPlayerInfoByGUID(guid)
	-- Not known yet (empty) or not readable: asked again by a later line, and
	-- never kept, so a player isn't left without icons for the session.
	if not Readable(englishClass) or not Readable(englishRace) or not Readable(sex)
		or type(englishClass) ~= "string" or type(englishRace) ~= "string"
		or englishClass == "" or englishRace == "" then
		return nil
	end
	if infoCount >= GUILD_MEMORY then
		wipe(infos)
		infoCount = 0
	end
	infoCount = infoCount + 1
	info = { class = englishClass, race = englishRace, sex = sex }
	infos[guid] = info
	return info
end

-- "friend", "guild" or nil. A friend in the guild counts as a friend.
function Players.Relation(guid)
	if not Readable(guid) or guid == UnitGUID("player") then
		return nil
	end
	if IsBattleNetFriend(guid) or IsCharacterFriend(guid) then
		return "friend"
	end
	if IsGuildMember and IsGuildMember(guid) then
		return "guild"
	end
	return nil
end

-- The game updates the roster every few seconds; it's rebuilt only when
-- something reads it (a tooltip).
local rosterDirty = true

local function RebuildRoster()
	if not rosterDirty then
		return
	end
	rosterDirty = false
	wipe(roster)
	wipe(rosterNames)
	if not IsInGuild() then
		return
	end
	for index = 1, GetNumGuildMembers() do
		local name, rank, _, level, _, zone, note, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(index)
		if guid then
			roster[guid] = { level = level, rank = rank, zone = zone, note = note, online = online }
			if name then
				rosterNames[name] = guid
				rosterNames[name:match("^([^%-]+)") or name] = guid
			end
		end
	end
end

local function ClassColor(englishClass)
	local color = englishClass and (C_ClassColor and C_ClassColor.GetClassColor(englishClass) or RAID_CLASS_COLORS and RAID_CLASS_COLORS[englishClass])
	return color or HIGHLIGHT_FONT_COLOR
end

-- Fills the tooltip for a player link: the name in their class color, race
-- and class with the level when known, then what their friendship or guild
-- says. Returns false when nothing is known (the tooltip is left alone).
-- A friend's or a guild member's GUID from their name (lines whose sender
-- isn't known any more).
local function GUIDFromName(name)
	RebuildRoster()
	local friend = C_FriendList and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name)
	if friend and friend.guid then
		return friend.guid
	end
	return rosterNames[name] or rosterNames[name:match("^([^%-]+)") or name]
end

function Players.FillTooltip(tooltip, name, guid)
	RebuildRoster()
	if not Readable(guid) then
		guid = GUIDFromName(name)
	end
	local localizedClass, englishClass, localizedRace, _, _, _, _, level
	if Readable(guid) then
		localizedClass, englishClass, localizedRace, _, _, _, _, level = GetPlayerInfoByGUID(guid)
	end
	local relation = Players.Relation(guid)
	local friend = relation == "friend" and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name)
	local account = relation == "friend" and C_BattleNet and C_BattleNet.GetAccountInfoByGUID and C_BattleNet.GetAccountInfoByGUID(guid)
	local member = relation == "guild" and roster[guid]
	if not localizedClass and not relation and not (Readable(guid) and GuildOf(guid)) then
		return false
	end

	local shortName = name:match("^([^%-]+)") or name
	GameTooltip_SetTitle(tooltip, shortName, ClassColor(englishClass))
	local game = account and account.gameAccountInfo
	level = level or (friend and friend.level) or (member and member.level) or (game and game.characterLevel)
	if localizedClass then
		local who = (localizedRace or "") .. " " .. localizedClass
		GameTooltip_AddHighlightLine(tooltip, level and level > 0 and L.playerLevel:format(level, who) or who)
	end
	-- Their guild, as a unit tooltip writes it; one's own guild gets its rank below.
	local guildName = relation ~= "guild" and Readable(guid) and GuildOf(guid)
	if guildName then
		GameTooltip_AddHighlightLine(tooltip, "<" .. guildName .. ">")
	end
	if relation == "friend" then
		if account then
			GameTooltip_AddNormalLine(tooltip, L.playerBattleNetFriend:format(account.accountName or account.battleTag or ""))
		else
			GameTooltip_AddNormalLine(tooltip, L.playerFriend)
		end
		local note = friend and friend.notes or account and account.note
		if note and note ~= "" then
			GameTooltip_AddColoredLine(tooltip, note, ns.Theme.TIME)
		end
		local zone = friend and friend.connected and friend.area or game and game.areaName
		if zone and zone ~= "" then
			GameTooltip_AddHighlightLine(tooltip, zone)
		end
	elseif relation == "guild" then
		-- The guild's name as a unit tooltip writes it, in gold for one's own
		-- ("Your guild" while the game hasn't told it yet), with their rank.
		local rank = member and member.rank
		local suffix = rank and rank ~= "" and (" · " .. rank) or ""
		local ownGuild = GetGuildInfo("player")
		if Readable(ownGuild) and ownGuild ~= "" then
			GameTooltip_AddNormalLine(tooltip, "<" .. ownGuild .. ">" .. suffix)
		else
			GameTooltip_AddNormalLine(tooltip, L.playerGuildMember:format(suffix))
		end
		if member and member.note and member.note ~= "" then
			GameTooltip_AddColoredLine(tooltip, member.note, ns.Theme.TIME)
		end
		if member and member.online and member.zone and member.zone ~= "" then
			GameTooltip_AddHighlightLine(tooltip, member.zone)
		end
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	GameTooltip_AddColoredLine(tooltip, L.playerHint, GREEN_FONT_COLOR)
	return true
end

function Players.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("GUILD_ROSTER_UPDATE")
	events:RegisterEvent("PLAYER_GUILD_UPDATE")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_GUILD_UPDATE" and C_GuildInfo and C_GuildInfo.GuildRoster then
			C_GuildInfo.GuildRoster()
		end
		rosterDirty = true
	end)
	-- Players the game shows us: their guild for later.
	if ns.SkipsHook("players") then
		return
	end
	local seen = CreateFrame("Frame")
	seen:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	seen:RegisterEvent("PLAYER_TARGET_CHANGED")
	seen:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	seen:RegisterEvent("GROUP_ROSTER_UPDATE")
	seen:SetScript("OnEvent", function(_, event, unit)
		if event == "UPDATE_MOUSEOVER_UNIT" then
			Learn("mouseover")
		elseif event == "PLAYER_TARGET_CHANGED" then
			Learn("target")
		elseif event == "NAME_PLATE_UNIT_ADDED" then
			Learn(unit)
		else
			local prefix, count = IsInRaid() and "raid" or "party", GetNumGroupMembers()
			for index = 1, count do
				Learn(prefix .. index)
			end
		end
	end)
	-- The roster comes on its own soon after login; this asks once in case
	-- it hasn't.
	C_Timer.After(8, function()
		if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
			C_GuildInfo.GuildRoster()
		end
	end)
end
