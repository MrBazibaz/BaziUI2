local ns = BaziUI.Chat

local Filters = {}
ns.Filters = Filters

-- Lines written in an alphabet the player can't read, hidden in public talk
-- (2026-10-13, the user's call; declined on 2026-10-10 with the spam filters,
-- which Forever's dedicated filter addons do, and taken back: this isn't
-- spam but legibility, and the beta's General was full of Chinese). Off
-- until the player unticks a language (Options: Messages > Languages, where
-- a ticked box means shown).
-- Only public channels (General, Trade, LookingForGroup...), say and yell:
-- what's addressed to the player (whispers, guild, group, raid) never hides.
-- A line hides when most of its letters are in the chosen alphabets, so one
-- character ("WTS [Arcanite] 中") doesn't hide it; links don't count, their
-- names aren't the writer's words. A Chinese or Japanese character stands for
-- about a Latin word's three letters, a Hangul block for two. Through
-- Blizzard's message filters, like the repeated ads (Channels.lua): called
-- only for readable messages, once per window showing the line, so the
-- verdict is kept by line ID.
local EVENTS = { "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL" }

-- Each alphabet: its option, its letters' ranges, a letter's weight.
local SCRIPTS = {
	han = {
		option = "hideHan",
		weight = 3,
		ranges = {
			{ 0x3040, 0x30FF }, { 0x31F0, 0x31FF }, { 0x3400, 0x4DBF }, { 0x4E00, 0x9FFF },
			{ 0xF900, 0xFAFF }, { 0x20000, 0x2FFFF },
		},
	},
	hangul = {
		option = "hideHangul",
		weight = 2,
		ranges = { { 0x1100, 0x11FF }, { 0x3130, 0x318F }, { 0xAC00, 0xD7AF } },
	},
	cyrillic = {
		option = "hideCyrillic",
		weight = 1,
		ranges = { { 0x0400, 0x052F } },
	},
	latin = {
		option = "hideLatin",
		weight = 1,
		ranges = {
			{ 0x41, 0x5A }, { 0x61, 0x7A }, { 0xC0, 0xD6 }, { 0xD8, 0xF6 }, { 0xF8, 0x24F },
			{ 0x1E00, 0x1EFF },
		},
	},
}

-- The alphabets offered: the ones that aren't the client's own.
local OFFERED = {
	ruRU = { "han", "hangul", "latin" },
	koKR = { "han", "cyrillic", "latin" },
	zhCN = { "hangul", "cyrillic", "latin" },
	zhTW = { "hangul", "cyrillic", "latin" },
}
local DEFAULT_OFFERED = { "han", "hangul", "cyrillic" }

function Filters.Offered()
	return OFFERED[GetLocale()] or DEFAULT_OFFERED
end

function Filters.Option(key)
	return SCRIPTS[key].option
end

-- An alphabet by the language players know it from, in the game's words for
-- its Group Finder's language filter (LFG_LIST_LANGUAGE_*); Latin, which has
-- no one language, in Everchat's.
local NAMES = { han = "LFG_LIST_LANGUAGE_ZHCN", hangul = "LFG_LIST_LANGUAGE_KOKR", cyrillic = "LFG_LIST_LANGUAGE_RURU" }

function Filters.Name(key)
	return (NAMES[key] and _G[NAMES[key]]) or ns.L["language_" .. key]
end

-- A UTF-8 character's code point (nil if it's malformed).
local function CodePoint(char)
	local b1, b2, b3, b4 = char:byte(1, 4)
	if b1 < 0x80 then
		return b1
	elseif b1 < 0xE0 then
		return b2 and (b1 - 0xC0) * 0x40 + (b2 - 0x80)
	elseif b1 < 0xF0 then
		return b3 and ((b1 - 0xE0) * 0x40 + (b2 - 0x80)) * 0x40 + (b3 - 0x80)
	end
	return b4 and (((b1 - 0xF0) * 0x40 + (b2 - 0x80)) * 0x40 + (b3 - 0x80)) * 0x40 + (b4 - 0x80)
end

local function ScriptOf(codePoint)
	for key, script in pairs(SCRIPTS) do
		for _, range in ipairs(script.ranges) do
			if codePoint >= range[1] and codePoint <= range[2] then
				return key
			end
		end
	end
end

-- The writer's own words: links, textures, atlases, colors and raid target
-- codes ("{rt1}", "{skull}") out.
local function OwnWords(text)
	return (text:gsub("|H.-|h.-|h", ""):gsub("|[TA].-|[ta]", ""):gsub("|c%x%x%x%x%x%x%x%x", "")
		:gsub("|cn.-:", ""):gsub("|r", ""):gsub("{.-}", ""))
end

-- Whether a message is mostly in the alphabets the player hides.
function Filters.IsHidden(text)
	local hidden, total = 0, 0
	for char in OwnWords(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		local codePoint = CodePoint(char)
		local key = codePoint and ScriptOf(codePoint)
		if key then
			local script = SCRIPTS[key]
			total = total + script.weight
			if ns.db[script.option] then
				hidden = hidden + script.weight
			end
		end
	end
	return hidden > 0 and hidden * 2 > total
end

-- Whether any alphabet is hidden at all (most players: none).
local function AnyHidden()
	for _, key in ipairs(Filters.Offered()) do
		if ns.db[SCRIPTS[key].option] then
			return true
		end
	end
	return false
end

-- Verdicts by line ID, a ring of them to forget the oldest.
local MEMORY = 500
local verdicts, ring, last = {}, {}, 0

local function Filter(_, _, text, _, _, _, _, _, _, _, _, _, lineID, guid)
	if type(text) ~= "string" or not AnyHidden() then
		return false
	end
	if guid and guid == UnitGUID("player") then
		return false
	end
	if lineID and verdicts[lineID] ~= nil then
		return verdicts[lineID]
	end
	local hide = Filters.IsHidden(text)
	if lineID then
		verdicts[lineID] = hide
		last = last % MEMORY + 1
		if ring[last] ~= nil then
			verdicts[ring[last]] = nil
		end
		ring[last] = lineID
	end
	return hide
end

-- A choice changed: lines already judged are judged again as they come.
function Filters.Changed()
	wipe(verdicts)
end

function Filters.Init()
	for _, event in ipairs(EVENTS) do
		ChatFrameUtil.AddMessageEventFilter(event, Filter)
	end
end
