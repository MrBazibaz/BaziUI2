local ns = BaziUI.Chat

local Lines = {}
ns.Lines = Lines

-- Everchat's touches on a chat line, composed in one place: short channel
-- names and the guild's coat of arms (Channels.lua), web links (Links.lua),
-- then the time in front (Timestamps.lua). As each message arrives
-- (AddMessage post-hook) its original text, event and time are remembered
-- with its entry, and the entry's text is composed from them. When an option
-- changes, every remembered line is composed again from its original, so the
-- change shows on what's already in the chat, both ways.
--
-- The entry's text is written directly, as Blizzard's own AddMessage just
-- stored it: TransformMessages would repackage the entry and stamp it with
-- the current time, waking up every faded line. Secret messages can't be read:
-- they only get the time (concatenation works on them), and keep it.
local hooked = {}
-- By entry (weak, so lines that scroll out of Blizzard's history go too).
local originals = setmetatable({}, { __mode = "k" })
-- The same originals by a number, for the time's link (weak: they go with
-- their entries).
local byID = setmetatable({}, { __mode = "v" })
-- By Blizzard's own line ID (eventArgs[11], the one in player links).
local byLineID = setmetatable({}, { __mode = "v" })
-- Told of every line added to a hooked window: fn(chatFrame, readable, replayed).
local listeners = {}
local lastID = 0
local latest = setmetatable({}, { __mode = "k" })
local fallbackTimes = setmetatable({}, { __mode = "k" })

local function Readable(message)
	return type(message) == "string" and (not canaccessvalue or canaccessvalue(message))
end

-- Whether a line shows nothing: spaces and colors at most (an addon's blank
-- separator, say). Such a line would only be an empty row pushing the chat up.
local function IsBlank(message)
	local text = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", ""):gsub("|n", ""):gsub("\194\160", "")
	return not text:find("%S")
end
Lines.IsBlank = IsBlank

-- The player's own lines in the color chosen (Options > Appearance >
-- Accessibility): theirs by the sender's GUID, and whispers sent, whose
-- sender fields name who they went to. Links and names keep their colors,
-- the chosen one coming back after each.
local SENT_EVENTS = { CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER_INFORM = true }

local function TintOwn(text, original)
	if not ns.db.ownColorOn or not (original.own or SENT_EVENTS[original.event]) then
		return text
	end
	local color = ns.db.ownColor or ns.defaults.ownColor
	local code = ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255)
	return code .. (text:gsub("|r", "|r" .. code)) .. "|r"
end

local function ColorSender(text, original)
	if not original.guid or not text:find("|Hplayer:", 1, true) then return text end
	local info = ns.Players.Info(original.guid)
	local color = info and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
	if not (color and color.colorStr) then return text end
	return (text:gsub("(|Hplayer:[^|]*|h)(.-)(|h)", function(open, name, close)
		if name:find("|c", 1, true) then return nil end
		return open .. "|c" .. color.colorStr .. name .. "|r" .. close
	end, 1))
end

local function Compose(chatFrame, original, entry)
	local text = ns.Names.Localize(original.message, entry)
	text = ns.Channels.AddIcons(text, original.event, chatFrame)
	text = ns.Channels.Decorate(text, chatFrame, original.event)
	text = ns.Names.AddIcons(text)
	text = ns.Channels.MarkPlayer(text, original.event, original.guid, chatFrame, original)
	text = ns.Channels.ShortNames(text)
	text = ColorSender(text, original)
	text = ns.Alerts.HighlightMentions(text, original.event, original.own)
	text = ns.Links.InviteLinks(text, original.event, original.own)
	text = ns.Links.Linkify(text, original.event)
	text = ns.Channels.MuteNotice(text, original.message, original.event)
	return TintOwn(text, original)
end

-- The lines as the game writes them, for a before-and-after picture of the
-- same lines (/everchat plain): nothing composed, no time. Not saved.
local plain = false

-- What a remembered line shows: composed, with its time, or as written.
local chatKinds = {
	PARTY = {"Group", PARTY}, PARTY_LEADER = {"Group", PARTY}, PARTY_GUIDE = {"Group", PARTY},
	INSTANCE_CHAT = {"Group", INSTANCE}, INSTANCE_CHAT_LEADER = {"Group", INSTANCE},
	RAID = {"Shield", RAID}, RAID_LEADER = {"Shield", RAID}, RAID_WARNING = {"Bell", RAID_WARNING},
	GUILD = {"Shield", GUILD}, OFFICER = {"Shield", OFFICER},
	WHISPER = {"Chat", WHISPER}, WHISPER_INFORM = {"Chat", WHISPER},
	BN_WHISPER = {"Chat", WHISPER}, BN_WHISPER_INFORM = {"Chat", WHISPER},
	SAY = {"Chat", SAY}, YELL = {"Bell", YELL}, CHANNEL = {"Broadcast"},
	MONSTER_SAY = {"Chat", SAY or "Say"}, MONSTER_YELL = {"Bell", YELL or "Yell"},
	MONSTER_WHISPER = {"Chat", WHISPER or "Whisper"},
}

local function Sender(text, event)
	local prefix, link, body = text:match("^(.-)(|Hplayer:[^|]*|h.-|h)(.*)$")
	if not link then prefix, link, body = text:match("^(.-)(|HBNplayer:[^|]*|h.-|h)(.*)$") end
	if not link then
		local kind = event and event:match("^CHAT_MSG_MONSTER_(.+)$")
		if kind and chatKinds["MONSTER_" .. kind] then
			local name, suffix = text:match("^([^:]+):%s*(.+)$")
			if name then
				local _, verb = (_G["CHAT_MONSTER_" .. kind .. "_GET"] or ""):match("^(.-)%%s(.-):")
				if verb and verb ~= "" and name:sub(-#verb) == verb then name = name:sub(1, -#verb - 1) end
				name = name:gsub(" yells$", ""):gsub(" says$", ""):gsub(" whispers$", "")
				return name, suffix, ""
			end
		end
		return
	end
	body = body:gsub("^|r", "")
	body = body:match("^%s*:%s*(.*)$") or body:match("^%s+[^:]+:%s*(.*)$")
	if body then return link, body, prefix end
end

local function stripNativeClock(message)
	if not ns.Timestamps.GameShowsTimes or not ns.Timestamps.GameShowsTimes() then return message end
	local function strip(text)
		return (text:gsub("^%[?%d%d?:%d%d:?%d?%d?%]?|?r?%s+", "", 1))
	end
	local bare = message:gsub("^|c%x%x%x%x%x%x%x%x(%[?%d%d?:%d%d:?%d?%d?%]?|r%s+)", "%1", 1)
	return strip(bare)
end

local function channelNotice(message)
	local line = message:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("^|cn[^:|]+:", "")
	local link, name, body = line:match("^(|Hchannel:[^|]+|h)%[%d+%.%s*(.-)%]|h%s*:?%s*(.+)$")
	if not name then name, body = line:match("^%[%d+%.%s*(.-)%]%s*:?%s*(.+)$") end
	if body then
		body = body:gsub("^|r%s*:?%s*", "")
		local label = link and link .. name .. "|h" or name
		return "|TInterface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\Broadcast.tga:12:12|t " .. label .. "|n" .. body
	end
end

local function Shown(chatFrame, original, entry)
	original.senderLabel, original.channelLabel, original.channelIcon = nil, nil, nil
	if plain then
		return original.message
	end
	local composed = stripNativeClock(Compose(chatFrame, original, entry))
	local kind = original.event and chatKinds[original.event:sub(10)]
	local sender, body, prefix
	if kind then sender, body, prefix = Sender(composed, original.event) end
	if not sender then
		local notice = channelNotice(composed)
		if notice then original.speaker = true end
		return notice or composed
	end
	if original.guid then sender = ColorSender(sender, original) end
	sender = sender:gsub("^(|H[^|]+|h)(.-)(|h)$", function(open, label, close)
		label = label:gsub("%[", "", 1):gsub("%](|r)$", "%1"):gsub("%]$", "")
		return open .. label .. close
	end)
	body = TintOwn(body, original)
	if original.continued then return body end
	local icon, channel = kind[1], kind[2]
	if original.event == "CHAT_MSG_CHANNEL" then
		channel = prefix:match("|Hchannel:[^|]*|h%[?(.-)%]?|h") or original.channel or "Channel"
		channel = channel:gsub("^%d+[%. ]+", "")
	end
	original.senderLabel, original.channelLabel, original.channelIcon = sender, channel or icon, icon
	return sender .. "|n" .. body
end

-- A blank line just added goes again, as if it never came. Reading further up,
-- AddMessage scrolled a row for it, which is undone too.
local function RemoveBlank(chatFrame, message)
	chatFrame:RemoveMessagesByPredicate(function(text)
		return Readable(text) and text == message
	end)
	-- ScrollDown: no number of ours reaches the frame's own scroll offset,
	-- which the game reads whenever it adds a line.
	if chatFrame:GetScrollOffset() > 0 then
		chatFrame:ScrollDown()
	end
end

local function OnAddMessage(chatFrame, message, _, _, _, _, _, _, event, eventArgs)
	if Readable(message) and IsBlank(message) then
		RemoveBlank(chatFrame, message)
		return
	end
	-- AddMessage just pushed this message to the front of the history.
	local entry = chatFrame.historyBuffer:GetEntryAtIndex(1)
	if not entry then
		return
	end
	-- Lines added back from History keep their own time.
	local clock = ns.History.ReplayTime() or time()
	if Readable(message) then
		-- The player's own lines never highlight their name (the sender's GUID
		-- may be a secret value).
		local guid = eventArgs and eventArgs[12]
		if guid ~= nil and canaccessvalue and not canaccessvalue(guid) then
			guid = nil
		end
		local own = guid ~= nil and guid == UnitGUID("player")
		local lineID = eventArgs and eventArgs[11]
		if lineID ~= nil and canaccessvalue and not canaccessvalue(lineID) then
			lineID = nil
		end
		lastID = lastID + 1
		local channel = eventArgs and eventArgs[9]
		if not Readable(channel) then channel = nil end
		local kind = event and chatKinds[event:sub(10)]
		local link, _, prefix
		if kind then link, _, prefix = Sender(stripNativeClock(message), event) end
		local sender = link and (link:match("^|H([^:]+:[^:|]+)") or link)
		if kind and not sender and Readable(eventArgs and eventArgs[2]) then sender = eventArgs[2] end
		if event == "CHAT_MSG_CHANNEL" then
			channel = channel or prefix and prefix:match("|Hchannel:([^|]+)|h")
		end
		local previous = latest[chatFrame]
		latest[chatFrame] = sender and {sender = sender, event = event, channel = channel} or nil
		local continued = sender and previous and previous.sender == sender and previous.event == event
			and previous.channel == channel
		local original = { continued = continued, channel = channel, speaker = link ~= nil, id = lastID, message = message, event = event, clock = clock, own = own, guid = guid, chatFrame = chatFrame }
		originals[entry] = original
		byID[lastID] = original
		if type(lineID) == "number" and lineID > 0 then
			byLineID[lineID] = original
		end
		entry.message = Shown(chatFrame, original, entry)
	else
		latest[chatFrame] = nil
		fallbackTimes[entry] = clock
		entry.message = message
	end
	local replayed = ns.History.ReplayTime() ~= nil
	for _, listener in ipairs(listeners) do
		listener(chatFrame, originals[entry] ~= nil, replayed)
	end
end

function Lines.GroupInfo(entry)
	local original = entry and originals[entry]
	if plain or not entry then return end
	if not original then return nil, nil, fallbackTimes[entry] end
	return original.continued, original.speaker, original.clock
end

function Lines.ChannelLabel(entry)
	local original = not plain and entry and originals[entry]
	if original then return original.senderLabel, original.channelLabel, original.channelIcon end
end

function Lines.AddListener(fn)
	table.insert(listeners, fn)
end

-- The event of a history entry Everchat composed (nil for the others).
function Lines.EventOf(entry)
	local original = entry and originals[entry]
	return original and original.event
end

-- The sender's GUID of a history entry Everchat composed, when it was readable
-- (the crests and crowns, Channels.lua).
function Lines.GuidOf(entry)
	local original = entry and originals[entry]
	return original and original.guid
end

-- The sender's GUID of the line with Blizzard's line ID (player links carry
-- it), when it was readable.
function Lines.SenderOf(lineID)
	local original = lineID and byLineID[lineID]
	if original and original.guid then
		return original.guid
	end
	-- Blizzard keeps the lines of this session (secret while chat is locked
	-- down).
	if lineID and lineID > 0 and C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID then
		local guid = C_ChatInfo.GetChatLineSenderGUID(lineID)
		if guid and canaccessvalue(guid) and guid ~= "" then
			return guid
		end
	end
	return nil
end

-- Composes every remembered line again, with the options as they are now.
function Lines.Refresh()
	for chatFrame in pairs(hooked) do
		for _, entry in chatFrame.historyBuffer:EnumerateIndexedEntries() do
			local original = originals[entry]
			if original then
				entry.message = Shown(chatFrame, original, entry)
			end
		end
		chatFrame:MarkDisplayDirty()
	end
end

-- Only the remembered lines of some events (a set by event name) and, with
-- `holding`, only those whose original text holds it (plain): a label renamed
-- or recolored (Channels.lua) touches no other line, so typing a channel's
-- name doesn't compose the whole chat again.
function Lines.RefreshEvents(events, holding)
	for chatFrame in pairs(hooked) do
		local changed = false
		for _, entry in chatFrame.historyBuffer:EnumerateIndexedEntries() do
			local original = originals[entry]
			if original and events[original.event] and (not holding or original.message:find(holding, 1, true)) then
				entry.message = Shown(chatFrame, original, entry)
				changed = true
			end
		end
		if changed then
			chatFrame:MarkDisplayDirty()
		end
	end
end

-- Only the player's own remembered lines (their color changed, live while
-- the color picker moves, as the game recolors a channel's lines).
function Lines.RefreshOwn()
	for chatFrame in pairs(hooked) do
		local changed = false
		for _, entry in chatFrame.historyBuffer:EnumerateIndexedEntries() do
			local original = originals[entry]
			if original and (original.own or SENT_EVENTS[original.event]) then
				entry.message = Shown(chatFrame, original, entry)
				changed = true
			end
		end
		if changed then
			chatFrame:MarkDisplayDirty()
		end
	end
end

-- One remembered line composed again (a link's name arrived, Names.lua).
function Lines.RefreshEntry(entry)
	local original = originals[entry]
	if not original then
		return
	end
	entry.message = Shown(original.chatFrame, original, entry)
	original.chatFrame:MarkDisplayDirty()
end

function Lines.IsPlain()
	return plain
end

function Lines.SetPlain(on)
	plain = on and true or false
	Lines.Refresh()
end

-- A line as plain text, for copying: no colors, links reduced to what they
-- show, no inline textures or atlases (the guild's badge, group icons).
-- Battle.net names are per-session tokens that can't be turned into text.
local function Plain(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	text = text:gsub("|K.-|k", "?")
	text = text:gsub("|n", " "):gsub("||", "|")
	return text
end
Lines.Plain = Plain

-- Whether a history entry's text can be read (Search.lua).
Lines.Readable = Readable

-- A window's lines as plain text, oldest first (Links.lua's copy window).
-- Lines Everchat composed are taken from their original text with their time
-- and the channel's short name as shown ("[2. Trade]", not "[2. Trade -
-- English]"), but every label kept: "[Guild]" rather than the badge, a
-- channel's label even in its own tab. Secret messages can't be read and are
-- left out.
function Lines.PlainText(chatFrame)
	local lines = {}
	for _, entry in chatFrame.historyBuffer:EnumerateIndexedEntries() do
		local original = originals[entry]
		local text
		if original then
			text = ns.Timestamps.Prefix(ns.Channels.ShortLabel(original.message, original.event), original.clock)
		elseif Readable(entry.message) then
			text = entry.message
		end
		if text then
			-- Index 1 is the newest.
			table.insert(lines, 1, Plain(text))
		end
	end
	return lines
end

-- One line as plain text, by the number in its time's link (nil once it has
-- scrolled out of the chat's history).
-- When a line came in (its time's tooltip).
function Lines.ClockOf(id)
	local original = id and byID[id]
	return original and original.clock
end

function Lines.PlainLine(id)
	local original = byID[id]
	if not original then
		return nil
	end
	return Plain(ns.Timestamps.Prefix(ns.Channels.ShortLabel(original.message, original.event), original.clock))
end

local function SetupAllChatFrames()
	if ns.SkipsHook("lines") then
		return
	end
	for _, name in pairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		-- The combat log has its own timestamp option and no chat to touch.
		if not hooked[chatFrame] and chatFrame ~= COMBATLOG then
			hooked[chatFrame] = true
			hooksecurefunc(chatFrame, "AddMessage", ns.Guard("Lines.OnAddMessage", OnAddMessage))
		end
	end
end

-- Before History adds the saved lines back.
function Lines.Init()
	SetupAllChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", SetupAllChatFrames)
	hooksecurefunc("FCF_OpenTemporaryWindow", SetupAllChatFrames)
	-- Icons are sized and lowered for the window's font size: a new size
	-- composes the lines again (before, they kept the old size until a reload),
	-- once for all the windows told in the same frame (the game font option
	-- tells every window at once).
	local pending = false
	local function QueueRefresh()
		if not pending then
			pending = true
			C_Timer.After(0, function()
				pending = false
				Lines.Refresh()
			end)
		end
	end
	ns.Fonts.OnSizeChanged(QueueRefresh)
	-- The game gives each window its saved size on UPDATE_CHAT_WINDOWS (a
	-- SetFont of its own, at login after the lines brought back from the last
	-- session were composed at the size the window had then).
	local windows = CreateFrame("Frame")
	windows:RegisterEvent("UPDATE_CHAT_WINDOWS")
	windows:SetScript("OnEvent", QueueRefresh)
end
