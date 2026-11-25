local ns = BaziUI.Chat

local History = {}
ns.History = History

-- The chat survives reloads and logins: each window's messages are kept per
-- character and added back when the game loads, with
-- their own times (Timestamps) and without lighting tabs (Alerts).
--
-- It can be turned off (/everchat history), which also deletes what's saved,
-- and cleared (/everchat history clear): whispers included, it's private chat
-- kept in a file on the player's computer.
--
-- Only the game's own chat messages are kept (AddMessage with an event):
-- never secret messages (they can't be read), Battle.net ones (their names are
-- per-session tokens that would come back as garbage), addon prints, the
-- combat log or temporary windows. Blizzard's own history table is never
-- touched: lines go back in through AddMessage, like any other.
--
-- A person's own whisper window (the game's "New whispers" in a tab of its
-- own) is gone after a reload, as the game never saves it: its lines are kept
-- by person, and when the game opens that person's window again they come
-- back in it before the new whisper. Battle.net whispers aren't kept.
-- As many lines per window as the game's chat windows hold (128, set in its
-- own code), at most a day old: raising a window's limit from addon code
-- leaves its history list tainted, and every line the game's own code adds
-- then runs tainted.
local MAX_LINES = 128
-- Trim in batches rather than on every message.
local TRIM_SLACK = 50
local MAX_AGE = 24 * 60 * 60

-- Fields of a saved line.
local TIME, MESSAGE, RED, GREEN, BLUE, EVENT, SENDER = 1, 2, 3, 4, 5, 6, 7

local hooked = {}
-- The saved time of the line being added back, while replaying.
local replayTime

local function GetStore()
	local key = ns.CharacterKey()
	local saved = BaziUI.db.chatHistory
	saved.history = saved.history or {}
	saved.history[key] = saved.history[key] or {}
	return saved.history[key]
end

-- Whispers by character and recipient.
local function GetPeople()
	local key = ns.CharacterKey()
	local saved = BaziUI.db.chatHistory
	saved.whisperHistory = saved.whisperHistory or {}
	saved.whisperHistory[key] = saved.whisperHistory[key] or {}
	return saved.whisperHistory[key]
end

-- The person a window is kept for: a player's own whisper window.
local function PersonOf(chatFrame)
	local target = chatFrame.isTemporary and chatFrame.chatType == "WHISPER" and chatFrame.chatTarget
	if type(target) ~= "string" or not canaccessvalue(target) or target == "" then
		return nil
	end
	return target:lower()
end

local function IsKept(chatFrame)
	return chatFrame ~= COMBATLOG and not chatFrame.isTemporary
		and chatFrame:GetID() <= Constants.ChatFrameConstants.MaxChatWindows
end

function History.ReplayTime()
	return replayTime
end

local function Accessible(value)
	return value == nil or not canaccessvalue or canaccessvalue(value)
end

local function OnAddMessage(chatFrame, message, r, g, b, _, _, _, event, eventArgs)
	if not ns.db.keepHistory or replayTime then
		return
	end
	if type(event) ~= "string" or strsub(event, 1, 12) == "CHAT_MSG_BN_" then
		return
	end
	if type(message) ~= "string" or not Accessible(message) or message:find("|K", 1, true) or ns.Lines.IsBlank(message) then
		return
	end
	if not (Accessible(r) and Accessible(g) and Accessible(b)) then
		return
	end

	local store, id
	if chatFrame.isTemporary then
		id = PersonOf(chatFrame)
		if not id then
			return
		end
		store = GetPeople()
	else
		store, id = GetStore(), chatFrame:GetID()
	end
	local lines = store[id]
	if not lines then
		lines = {}
		store[id] = lines
	end
	-- The sender's GUID (when readable): lines brought back keep their marks
	-- and their name's tooltip (Players.lua).
	local guid = eventArgs and eventArgs[12]
	if guid ~= nil and not (Accessible(guid) and type(guid) == "string" and guid ~= "") then
		guid = nil
	end
	table.insert(lines, { time(), message, r, g, b, event, guid })
	if #lines > MAX_LINES + TRIM_SLACK then
		-- A copy of the newest MAX_LINES (no unpack: too many values).
		local kept = {}
		for index = #lines - MAX_LINES + 1, #lines do
			kept[#kept + 1] = lines[index]
		end
		store[id] = kept
	end
end

-- Lines older than a day go for every character at login, not only this
-- one: a character that isn't played would otherwise keep its last day of
-- chat in the saved file for good, and the file grows with each alt.
local function PruneStores(stores, cutoff)
	for key, store in pairs(stores or {}) do
		for id, lines in pairs(store) do
			local kept = {}
			for _, line in ipairs(lines) do
				if line[TIME] >= cutoff then
					kept[#kept + 1] = line
				end
			end
			store[id] = #kept > 0 and kept or nil
		end
		if next(store) == nil then
			stores[key] = nil
		end
	end
end

local function PruneAll(cutoff)
	local saved = BaziUI.db.chatHistory
	PruneStores(saved.history, cutoff)
	PruneStores(saved.whisperHistory, cutoff)
end

-- A saved line's kind of chat as the game colors it (ChatTypeInfo): its
-- event's ("GUILD", "WHISPER_INFORM"...), a numbered channel's by the number
-- in its link ("CHANNEL2"). A community's lines take their club's color.
local function ChatTypeOf(line)
	local chatType = strsub(line[EVENT], 10)
	if chatType == "COMMUNITIES_CHANNEL" then
		return nil
	end
	if strsub(chatType, 1, 7) == "CHANNEL" then
		local number = line[MESSAGE]:match("|Hchannel:%a*:?(%d+)|h")
		if number then
			return "CHANNEL" .. number
		end
	end
	return chatType
end

-- The game sets every chat type white until the player's chat colors load.
local function ColorsLoaded()
	for _, info in pairs(ChatTypeInfo) do
		if info.r ~= 1 or info.g ~= 1 or info.b ~= 1 then
			return true
		end
	end
	return false
end

-- Adds a window's saved lines back, oldest first, through AddMessage: the
-- other hooks see them as they did the first time (a fresh eventArgs table
-- stands in for the event's, which only Channels compares, by identity).
-- Each comes back in its kind's color as it is now (the one it was saved
-- with until the colors load) and with its kind's ID, which the game
-- recolors lines by when a color changes or loads (UpdateColorByID).
local function Restore(chatFrame, lines, before)
	local cutoff = time() - MAX_AGE
	local kept = {}
	for index = math.max(1, #lines - MAX_LINES + 1), #lines do
		local line = lines[index]
		if line[TIME] >= cutoff then
			table.insert(kept, line)
		end
	end
	local loaded = ColorsLoaded()
	for _, line in ipairs(kept) do
		if before and line[TIME] >= before then
			break
		end
		local r, g, b = line[RED], line[GREEN], line[BLUE]
		local info = ChatTypeInfo[ChatTypeOf(line) or ""]
		if info and loaded then
			r, g, b = info.r, info.g, info.b
		end
		replayTime = line[TIME]
		chatFrame:AddMessage(line[MESSAGE], r, g, b, info and info.id, nil, nil, line[EVENT], { [12] = line[SENDER] })
	end
	replayTime = nil
	return kept
end

local function Setup(chatFrame)
	if hooked[chatFrame] or not (IsKept(chatFrame) or chatFrame.isTemporary) or ns.SkipsHook("history") then
		return
	end
	hooked[chatFrame] = true
	hooksecurefunc(chatFrame, "AddMessage", ns.Guard("History.OnAddMessage", OnAddMessage))
end

local function SetupAllChatFrames()
	for _, name in pairs(CHAT_FRAMES) do
		Setup(_G[name])
	end
end

-- Deletes one window's saved chat (Buttons.lua's "Clear chat").
function History.ClearWindow(chatFrame)
	if chatFrame.isTemporary then
		local person = PersonOf(chatFrame)
		if person then
			GetPeople()[person] = nil
		end
		return
	end
	GetStore()[chatFrame:GetID()] = nil
end

-- Deletes this character's saved chat (Conflicts.lua: lines saved while
-- another chat addon was rewriting them carry its formatting, like Prat's
-- "[S]" and "[1:Name]", and would come back after it's gone).
function History.ClearCharacter()
	local saved, key = BaziUI.db.chatHistory, ns.CharacterKey()
	if saved.history then
		saved.history[key] = nil
	end
	if saved.whisperHistory then
		saved.whisperHistory[key] = nil
	end
end

-- A person's whisper window opened by the game: what was said with them
-- comes back first. One opened from another window already has this
-- session's lines, copied by the game, so only older ones come back then.
local sessionStart = time()

local function OnTemporaryWindow(chatFrame, sourceChatFrame)
	if not chatFrame then
		return
	end
	Setup(chatFrame)
	local person = ns.db.keepHistory and PersonOf(chatFrame)
	local lines = person and GetPeople()[person]
	if lines then
		GetPeople()[person] = Restore(chatFrame, lines, sourceChatFrame and sessionStart)
	end
end

-- After the other modules hook AddMessage, so the lines come back dressed.
function History.Init()
	if not ns.db.keepHistory then
		History.ClearCharacter()
	end
	PruneAll(time() - MAX_AGE)
	local store = GetStore()
	for id, lines in pairs(store) do
		local chatFrame = _G["ChatFrame" .. id]
		if chatFrame and IsKept(chatFrame) then
			store[id] = Restore(chatFrame, lines)
		else
			store[id] = nil
		end
	end
	SetupAllChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", SetupAllChatFrames)
	-- A closed window's ID may come back as another window.
	hooksecurefunc("FCF_Close", function(frame, fallback)
		local closed = fallback or frame or FCF_GetCurrentChatFrame()
		if not closed then
			return
		end
		if closed.isTemporary then
			local person = PersonOf(closed)
			if person then
				GetPeople()[person] = nil
			end
		else
			GetStore()[closed:GetID()] = nil
		end
	end)
	-- The window the game just opened: the one in use for that type and
	-- person (a post-hook doesn't see what the function returned).
	hooksecurefunc("FCF_OpenTemporaryWindow", function(chatType, chatTarget, sourceChatFrame)
		for _, name in ipairs(CHAT_FRAMES) do
			local chatFrame = _G[name]
			if chatFrame and chatFrame.isTemporary and chatFrame.inUse and chatFrame.chatType == chatType
				and chatFrame.chatTarget == chatTarget then
				OnTemporaryWindow(chatFrame, sourceChatFrame)
				return
			end
		end
	end)
end
