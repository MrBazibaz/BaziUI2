local ns = BaziUI.Chat

local Channels = {}
ns.Channels = Channels

-- Guild lines start with Blizzard's channel link, "|Hchannel:GUILD|h[Hermandad]|h"
-- (CHAT_GUILD_GET). The badge swaps the bracketed label for the guild's crest
-- and keeps the link, so clicking it still starts a guild message.
local GUILD_LABEL = "(|Hchannel:GUILD|h)%[[^%]]*%](|h)"

-- The badge is the guild's crest, as the Communities list draws it: the
-- banner tinted with the tabard's background color, the emblem in its color
-- on top, and the banner's border in the border color. The line holds its
-- place with an invisible square as tall as the font (a crop of the quest
-- mark file's transparent strip, like Gap's below), and a
-- crest frame that follows the line (position, scroll, fading) draws all
-- three over it. Drawn in the line, the banner
-- stood a few pixels higher than any frame placed from the line's top: a
-- picture as tall as the font rises above it.
local CREST_FILE = 1121272
local CREST_CROP = ":1024:1024:784:788:153:157"
local CREST_ESCAPE = "|T%d+:0:0:0:0" .. CREST_CROP:gsub("%p", "%%%0") .. "|t"
local BANNER_ATLAS = "communities-guildbanner-background"
local BORDER_ATLAS = "communities-guildbanner-border"
-- The banner's art is 74x69 with a soft shadow around the shield; the shield
-- sits in the 62x62 square starting 6px in.
local ART_WIDTH, ART_HEIGHT = 74, 69
local CROP_LEFT, CROP_SIZE = 6, 62
-- Texture coordinates in |T escapes are pixels of a declared size; any size works.
local TEXCOORD_SCALE = 1000

-- The emblem comes from one of the game's two sheets of them, which hold the
-- same emblems in the same order: the small one SetSmallGuildTabardTextures
-- uses (256x256, 16x16 icons in 18x18 cells, 14 columns), drawn simpler to
-- read at that size, and the large one SetLargeGuildTabardTextures uses
-- (1024x1024, 64x64 cells, 16 columns). The game samples a texture drawn
-- smaller from its full-size art, not its mipmaps, so the large art's thin
-- strokes vanish below about half its size and only its solid parts show:
-- crests under LARGE_SHEET_PIXELS screen pixels take the small sheet. Each
-- emblem is drawn 7/8 as wide as tall, as SetLargeGuildTabardTextures draws
-- them, its height a share of the crest's and its middle a little above the
-- shield's (the shield narrows to its tip). The large art has a transparent
-- margin around each emblem, so its cell is drawn taller than the crest, the
-- emblem itself staying on the shield and as big as the small sheet's.
local EMBLEM_SHEETS = {
	small = { file = "Interface\\GuildFrame\\GuildEmblems_01", cell = 18 / 256, columns = 14, inset = 1 / 256, height = 0.82, center = 0.46 },
	large = { file = "Interface\\GuildFrame\\GuildEmblemsLG_01", cell = 64 / 1024, columns = 16, inset = 0, height = 1.2, center = 0.45 },
}
local LARGE_SHEET_PIXELS = 28
local EMBLEM_ASPECT = 7 / 8
-- The border at half strength: at full, its light line outshone the names
-- down a busy guild chat.
local BORDER_ALPHA = 0.5

-- Message groups (a window's messageTypeList) where other players talk. A
-- window that gets guild chat and none of these (officer chat keeps its own
-- label) and no channels is the guild's own tab: there the label says
-- nothing, so it goes, badge and all.
local OTHER_TALK = {
	SAY = true, EMOTE = true, YELL = true,
	WHISPER = true, BN_WHISPER = true,
	PARTY = true, PARTY_LEADER = true,
	RAID = true, RAID_LEADER = true, RAID_WARNING = true,
	INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true,
	CHANNEL = true, COMMUNITIES_CHANNEL = true,
}

local hookedFrames = {}
-- Per chat frame: the crest overlay, its crests, the lines they sit on.
local overlays = {}

local function CropCoords(info)
	local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local function X(pixels)
		return l + (r - l) * pixels / ART_WIDTH
	end
	local function Y(pixels)
		return t + (b - t) * pixels / ART_HEIGHT
	end
	return X(CROP_LEFT), X(CROP_LEFT + CROP_SIZE), Y(0), Y(CROP_SIZE)
end

local function BadgeSize(chatFrame)
	local _, fontHeight = chatFrame:GetFont()
	return fontHeight or 14
end

-- The guild's tabard, when it has a design: the game tells one by its
-- emblem's file (SetGuildTabardTextures), since a tabard never designed still
-- comes with a default emblem number and colors.
local function DesignedTabard()
	local tabard = C_GuildInfo.GetGuildTabardInfo("player")
	if tabard and tabard.emblemFileID and tabard.emblemStyle then
		return tabard
	end
	return nil
end

-- The crest's place in a line, while the guild has a tabard to draw it from.
local function GuildBadge()
	if not DesignedTabard() or not C_Texture.GetAtlasInfo(BANNER_ATLAS) then
		return nil
	end
	return ("|T%d:0:0:0:0%s|t"):format(CREST_FILE, CREST_CROP)
end

-- For Search.lua's results, which have no overlay: the banner itself in the
-- line, in the tabard's background color.
local function InlineBanner()
	local tabard = DesignedTabard()
	local info = C_Texture.GetAtlasInfo(BANNER_ATLAS)
	if not tabard or not info then
		return ""
	end
	local left, right, top, bottom = CropCoords(info)
	local function Texel(coord)
		return math.floor(coord * TEXCOORD_SCALE + 0.5)
	end
	local r, g, b = tabard.backgroundColor:GetRGBAsBytes()
	return ("|T%s:0:0:0:0:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(
		info.file or info.filename, TEXCOORD_SCALE, TEXCOORD_SCALE,
		Texel(left), Texel(right), Texel(top), Texel(bottom), r, g, b)
end

-- What the badges are drawn from: the tabard's emblem and colors ("none"
-- without a guild or a designed tabard).
local function TabardKey()
	local tabard = DesignedTabard()
	if not tabard then
		return "none"
	end
	local parts = { tabard.emblemStyle }
	for _, color in ipairs({ tabard.backgroundColor, tabard.borderColor, tabard.emblemColor }) do
		local r, g, b = color:GetRGBAsBytes()
		table.insert(parts, ("%d,%d,%d"):format(r, g, b))
	end
	return table.concat(parts, ":")
end

-- Offsets and sizes in whole screen pixels: the measured text widths fall
-- between pixels, and a picture drawn half a pixel off is resampled a little
-- differently from its neighbours.
local function Snap(value, px)
	return math.floor(value / px + 0.5) * px
end

local function CountLines(text)
	local _, count = text:gsub("\n", "")
	return count
end

-- Pieces of a line are measured with their markup, as the line draws them.
-- Even so, with fonts that round their size to whole pixels (Roboto
-- Condensed, Open Sans Condensed, the game's Arial Narrow) the text after an
-- item's or a spell's icon is drawn a pixel or two wider than it measures,
-- more after each icon, so nothing is placed by measuring past those icons
-- (the crests and crowns come before them).
-- A line's markup, walked once: the spaces it shows (not those inside a
-- link's data or a picture's path), each with the color and the link open
-- there (their opening escapes), and the link still open at its end: its
-- opening, where that starts and whether anything of its text shows yet.
local function Spaces(text)
	local spaces = {}
	local color, link, linkStart, linkShown
	local i, n = 1, #text
	while i <= n do
		if text:byte(i) == 124 then
			local kind = text:sub(i + 1, i + 1)
			if kind == "c" then
				local code = text:match("^|cn[^:|]*:", i) or text:match("^|c%x%x%x%x%x%x%x%x", i)
				color = code or color
				i = i + (code and #code or 2)
			elseif kind == "r" then
				color = nil
				i = i + 2
			elseif kind == "H" then
				local close = text:find("|h", i + 2, true)
				if not close then
					break
				end
				link, linkStart, linkShown = text:sub(i, close + 1), i, false
				i = close + 2
			elseif kind == "h" then
				link = nil
				i = i + 2
			elseif kind == "T" or kind == "A" or kind == "K" then
				local close = text:find("|" .. kind:lower(), i + 2, true)
				if not close then
					break
				end
				linkShown = true
				i = close + 2
			else
				i = i + 2
			end
		else
			if text:byte(i) == 32 then
				table.insert(spaces, { at = i, color = color, link = link })
			end
			linkShown = true
			i = i + 1
		end
	end
	return spaces, link, linkStart, linkShown
end

-- A piece of a line ready to measure on its own: a link left open at its end
-- is closed, or left out while none of its text shows yet (the place of a
-- crest or a group icon starts the channel's link): the game measures an
-- empty link's markup as text.
local function Closed(piece)
	local _, link, linkStart, linkShown = Spaces(piece)
	if not link then
		return piece
	end
	if not linkShown then
		return piece:sub(1, linkStart - 1)
	end
	return piece .. "|h"
end

-- The window's font on the measuring string, set on the first measure of
-- each refresh.
local function MeasureFont(overlay)
	if overlay.measureFont then
		overlay.measure:SetFontObject(overlay.measureFont)
		overlay.measureFont = nil
	end
	return overlay.measure
end

-- Where the text before `start` ends on its row: the width it takes and how
-- many rows down it is (the line's own breaks).
local function MeasureBefore(overlay, text, start)
	local before = text:sub(1, start - 1)
	local measure = MeasureFont(overlay)
	measure:SetText(Closed(before:match("[^\n]*$")))
	return measure:GetUnboundedStringWidth(), CountLines(before)
end

-- Measures stay with their line (its history entry, weakly held) until its
-- text, the window's font or its width changes: display refreshes come with
-- every new message and every scroll step, and measuring every badge and
-- icon in view again on each showed as CPU spikes. A picture whose file
-- hasn't loaded yet can measure narrower than it's drawn (an invisible gap
-- of the quest mark's file measured no width at all), and a line is first
-- measured as it arrives, so its measures are taken again SETTLE seconds
-- after that, by then with its pictures loaded. PlaceMarks asks to be run
-- again then (overlay.settleAt) in case nothing else refreshes the window.
local SETTLE = { 0.5, 2 }

-- A font string that drew a secret message can go on answering with secret
-- measures, whatever it shows now: nothing can be placed from them, and tainted
-- code can't even compare them. Those lines go without their marks until then.
local function HasReadableMeasures(line)
	local left, top, width = line:GetLeft(), line:GetTop(), line:GetWidth()
	return type(left) == "number" and canaccessvalue(left)
		and type(top) == "number" and canaccessvalue(top)
		and type(width) == "number" and canaccessvalue(width)
end

local function LineCache(overlay, entry, text, width)
	local cache = overlay.layouts[entry]
	if cache and (cache.text ~= text or cache.font ~= overlay.fontKey or cache.width ~= width) then
		cache = nil
	end
	local now = GetTime()
	local born = cache and cache.born or now
	local stage = 0
	while SETTLE[stage + 1] and now >= born + SETTLE[stage + 1] do
		stage = stage + 1
	end
	if not cache or cache.stage < stage then
		cache = { text = text, font = overlay.fontKey, width = width, measures = {}, born = born, stage = stage }
		overlay.layouts[entry] = cache
	end
	local due = SETTLE[stage + 1]
	if due then
		overlay.settleAt = math.min(overlay.settleAt or math.huge, born + due)
	end
	return cache
end

local function MeasureCached(overlay, cache, text, start)
	local measure = cache.measures[start]
	if not measure then
		local x, rows = MeasureBefore(overlay, text, start)
		measure = { x = x, rows = rows }
		cache.measures[start] = measure
	end
	return measure.x, measure.rows
end

-- Lines fade without a display refresh; what's drawn over them follows their
-- alpha.
local function FollowLines(marks)
	for _, mark in ipairs(marks) do
		local line = mark.line
		if line then
			local alpha = 0
			if line:IsShown() then
				alpha = line:GetAlpha()
			end
			mark:SetAlpha(alpha)
		end
	end
end

local function SyncAlpha(overlay)
	if overlay.active then
		FollowLines(overlay.crests)
		FollowLines(overlay.crowns)
	end
end

local function CreateOverlay(chatFrame)
	-- Clipped where Blizzard's own line container clips its lines (Skin.lua
	-- lowers its top on a hidden chat at rest).
	local overlay = CreateFrame("Frame", nil, chatFrame)
	overlay:SetAllPoints(chatFrame.FontStringContainer or chatFrame)
	overlay:SetClipsChildren(true)
	overlay:SetFrameLevel(chatFrame.FontStringContainer:GetFrameLevel() + 1)
	overlay.crests = {}
	-- Group leaders' crowns (below, with the group icons).
	overlay.crowns = {}
	-- Only measures text; never shown.
	overlay.measure = overlay:CreateFontString()
	overlay.measure:Hide()
	-- Lays a message out again at the line's width, to find where it wraps.
	overlay.wrap = overlay:CreateFontString()
	overlay.wrap:SetWordWrap(true)
	overlay.wrap:SetNonSpaceWrap(true)
	overlay.wrap:SetJustifyH("LEFT")
	overlay.wrap:Hide()
	overlay.layouts = setmetatable({}, { __mode = "k" })
	overlay:SetScript("OnUpdate", ns.Guard("Channels.SyncAlpha", SyncAlpha))
	overlays[chatFrame] = overlay
end

-- The crests and crowns go out of sight while Search.lua shows its results
-- instead of the lines (they'd float over them).
function Channels.SetCrestsShown(chatFrame, shown)
	local overlay = overlays[chatFrame]
	if overlay then
		overlay:SetShown(shown)
	end
end

-- The crests and portraits fade with their lines when Skin.lua fades a
-- hidden chat's lines in.
function Channels.SetMarksAlpha(chatFrame, alpha)
	local overlay = overlays[chatFrame]
	if overlay then
		overlay:SetAlpha(alpha)
	end
end

-- Icons in the chat: an item's or a spell's icon right before its link, and
-- a skill's before its name when it goes up ("Your skill in Maces has
-- increased to 4."), at the line's height (|T with height 0 takes the
-- font's), cropped of the dark rim every icon file has so it reads as a clean
-- square next to the name, whose color already says the quality. In every
-- line (2026-10-12, the user; only items in Trade until then): guild, group,
-- whispers and loot link items too, and lines brought back by History get
-- them as well. Skills and spells joined them the same day (the user).
-- Texels of the 64x64 icon kept (the rim is the outer 5); also how the
-- overlay finds Everchat's icons in a line.
local ICON_CROP = ":64:64:5:59:5:59"
-- An icon in a line sits on its baseline, a font height tall, so it stood
-- higher than the text (2026-10-12, the user: "centrar verticalmente"):
-- lowered by 0.17 of the font height, its middle meets the middle of the item
-- link's brackets beside it (Roboto Condensed's "[" runs from 0.81 above the
-- baseline to 0.15 below), as Blizzard lowers its own icons in text
-- (MerchantFrame's "|T...:0:0:0:-1|t", a dialog's CreateTextureMarkup with
-- -2). In whole units, as Blizzard writes its own (%d).
local ICON_DROP = 0.17

-- An icon and the name it belongs to are one block. The game breaks a row at
-- spaces and between two pictures, never between a picture and the text
-- right after it, so the space after an icon is a no-break space. An
-- invisible picture a space wide, the gap until then, was a second picture:
-- the row could break between the icon and it, leaving the icon at the end
-- of a row and its name on the next.
local NO_BREAK_SPACE = "\194\160"

local function IconOffset(chatFrame)
	local _, fontHeight = chatFrame:GetFont()
	return tostring(-math.floor((fontHeight or 14) * ICON_DROP + 0.5))
end

-- Who is talking in public (numbered channels, say, yell): a small mark
-- before a friend's or a guild member's name, so they stand out in Trade or
-- General (Players.lua says which). A friend gets a heart; a guild member
-- the guild's own crest, drawn over its place like the guild label's
-- (PlaceCrests), or a green banner of the same shape while the guild has no
-- tabard designed. The heart and the banner are Everchat's own art with
-- their colors and shading baked in (art/marks.py); all at the font's height.
local MARK_EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true }
local MARKS = {
	friend = "|TInterface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconFriend32:0|t",
	guild = "|TInterface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconGuild32:0|t",
}

-- A mark in a line, lowered like the item icons so it sits on the text's middle.
local function MarkMarkup(kind, chatFrame)
	local mark = MARKS[kind]
	if not mark or not chatFrame then
		return mark
	end
	return (mark:gsub(":0|t$", ":0:0:0:" .. IconOffset(chatFrame) .. "|t"))
end

-- Who they are: the character's race and class before the name, in every
-- conversation channel, each its own option: the game's own square icons,
-- raceicon128-<race>-<sex> (the character list's faces) and classicon-<class>,
-- written into the line like the item icons, so they show wherever the line
-- does. The race and class come from the sender's GUID (Players.Info);
-- unknown, no icon.
local IDENTITY_EVENTS = {}
for _, kind in ipairs({ "SAY", "YELL", "CHANNEL", "WHISPER", "WHISPER_INFORM", "GUILD", "OFFICER",
	"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" }) do
	IDENTITY_EVENTS["CHAT_MSG_" .. kind] = true
end
-- The quest mark's file (QUEST_FILE below), fully transparent there.
-- The game's English race names that aren't its atlas names.
local RACE_ATLAS_NAMES = { Scourge = "undead" }
local CLASS_ATLAS = "classicon-%s"
-- Whether the game has an atlas, by name.
local atlasKnown = {}

local function KnownAtlas(name)
	local known = atlasKnown[name]
	if known == nil then
		known = C_Texture.GetAtlasInfo(name) ~= nil
		atlasKnown[name] = known
	end
	return known and name or nil
end

local function RaceAtlas(info)
	local race = RACE_ATLAS_NAMES[info.race] or info.race:lower()
	return KnownAtlas(("raceicon128-%s-%s"):format(race, info.sex == 3 and "female" or "male"))
end

local function ClassAtlas(info)
	return KnownAtlas(CLASS_ATLAS:format(info.class:lower()))
end

-- An icon in the line, as tall as the font and lowered like the item icons,
-- followed by a no-break space: the game never breaks a row there, so an icon
-- stays with what follows it.
local function IdentityIcon(atlas, chatFrame)
	local size = chatFrame and select(2, chatFrame:GetFont()) or 14
	size = math.floor(size + 0.5)
	local drop = chatFrame and tonumber(IconOffset(chatFrame)) or 0
	return CreateAtlasMarkup(atlas, size, size, 0, drop) .. NO_BREAK_SPACE
end

-- Forever's names have two words, a first name and a surname. The option
-- (`surnames`; 2026-10-12, the user, to save room) shows the surname whole,
-- as its initial with a stop ("Leeroy J.": still tells apart two players
-- of one first name) or not at all: the name inside a player link's brackets
-- is cut, color codes and realm kept, while the link itself keeps the full
-- name, so clicks, whispers, the name's tooltip and Copy chat (built from
-- the original text) still have it. One-word names and Battle.net links
-- stay. The initial is the surname's first letter, not its first byte (a
-- letter with an accent, Cyrillic or Chinese takes several).
local function PlayerShortName(data, display, mode)
	local full = data:match("^([^:]+)")
	if not full then
		return
	end
	full = full:gsub("%-.*$", "")
	local first, surname = full:match("^(%S+)%s+(%S.*)$")
	if not first then
		return
	end
	local start, stop = display:find(full, 1, true)
	if not start then
		return
	end
	local short = first
	if mode == "initial" then
		short = first .. " " .. surname:match("^[%z\1-\127\194-\244][\128-\191]*") .. "."
	end
	return display:sub(1, start - 1) .. short .. display:sub(stop + 1)
end

function Channels.ShortNames(text)
	local mode = ns.db.surnames
	if (mode ~= "initial" and mode ~= "hidden") or not text:find("|Hplayer:", 1, true) then
		return text
	end
	return (text:gsub("(|Hplayer:([^|]*)|h)(.-)(|h)", function(open, data, display, close)
		local short = PlayerShortName(data, display, mode)
		return short and (open .. short .. close) or nil
	end))
end

-- The marks before the sender's name, in this order: who they are to the
-- player (the heart or the coat of arms), their race, their class.
function Channels.MarkPlayer(text, event, guid, chatFrame, original)
	if not guid or not text:find("|Hplayer:", 1, true) then
		return text
	end
	local marks = ""
	if ns.db.socialMarks and MARK_EVENTS[event] then
		local relation = ns.Players.Relation(guid)
		if relation then
			marks = relation == "guild" and GuildBadge() or MarkMarkup(relation, chatFrame)
		end
	end
	if (ns.db.raceMarks or ns.db.classMarks) and IDENTITY_EVENTS[event] then
		-- Kept with the line once known, so composing it again later (a font
		-- change, a loading screen) never takes its icons away.
		local info = original and original.identity or ns.Players.Info(guid)
		if info then
			if original then
				original.identity = info
			end
			local race = ns.db.raceMarks and RaceAtlas(info)
			local class = ns.db.classMarks and ClassAtlas(info)
			if race then
				marks = marks .. IdentityIcon(race, chatFrame)
			end
			if class then
				marks = marks .. IdentityIcon(class, chatFrame)
			end
		end
	end
	if marks == "" then
		return text
	end
	return (text:gsub("|Hplayer:", marks .. "|Hplayer:", 1))
end

-- Reads the window's lists, never writes them.
local function IsGuildOnly(chatFrame)
	for _, group in pairs(chatFrame.messageTypeList or {}) do
		if OTHER_TALK[group] then
			return false
		end
	end
	return not next(chatFrame.channelList or {})
end

-- Numbered channels' labels, "[1. General - Zephras Isle]" in English and
-- "[1. General: Montañas Crestagrana]" in Spanish, inside Blizzard's channel
-- link. The short form keeps the channel's number and name and drops the
-- zone: "[1. General]", "[2. Trade]" (the number is what /1, /2 type to). The
-- link still works (clicking it starts a message to that channel).
local CHANNEL_LABEL = "(|Hchannel:[^|]*|h)%[([^%]]*)%](|h)"

-- A window that shows one channel and no other conversation (a Trade tab):
-- there the channel's label says nothing either, so it goes, as the guild's
-- does in the guild's own tab.
local function IsSingleChannel(chatFrame)
	local channels = chatFrame.channelList or {}
	if #channels ~= 1 then
		return false
	end
	for _, group in pairs(chatFrame.messageTypeList or {}) do
		if group ~= "CHANNEL" and (OTHER_TALK[group] or group == "GUILD" or group == "OFFICER") then
			return false
		end
	end
	return true
end

local function ShortName(label)
	local name = label:gsub("%s*[:%-]%s+.*$", "")
	if name == "" then
		return label
	end
	return name
end

-- A numbered channel's name alone, without its number or its zone ("2. Trade
-- - City" gives "Trade").
function Channels.BaseName(label)
	return (ShortName(label):gsub("^%d+%.%s*", ""))
end

-- The character's numbered channels by number, by the names the game lists
-- them under (GetChannelList), which are what their own names are kept by.
-- A line's label shows a channel's full name, which isn't always that one
-- ("Trade (Local) - City" for TradeLocal, "Defensa local: Mulgore" for
-- DefensaLocal), so a line finds its channel by the number in its link. Not
-- kept while empty: the channels are joined a moment after login.
local listedChannels

local function ListChannels()
	local listed = {}
	local list = { GetChannelList() }
	for index = 1, #list, 3 do
		local number, name = list[index], list[index + 1]
		-- In a battleground the game hands them out as secret values: a secret
		-- key would make the table one no addon may go through again.
		if canaccessvalue(number) and canaccessvalue(name) and type(number) == "number" and type(name) == "string" then
			listed[number] = name
		end
	end
	return listed
end

local function ListedChannels()
	if not listedChannels then
		local listed = ListChannels()
		listedChannels = next(listed) and listed or nil
		return listed
	end
	return listedChannels
end

-- Where a numbered channel's own name is kept: by the channel its number
-- stands for now, else (a channel left) by the name in its label.
local function ChannelKey(number, label)
	local listed = number and ListedChannels()[number]
	return Channels.NameKey(listed or Channels.BaseName(label))
end

local function LinkNumber(link)
	return tonumber(link:match("channel:(%d+)|h"))
end

-- A numbered channel's label (its link's opening and its text): its own
-- name, else the short one while that option is on, else the game's.
local function ChannelLabel(link, label)
	local own = Channels.OwnName(ChannelKey(LinkNumber(link), label))
	if own then
		return own
	end
	return ns.db.shortChannels and ShortName(label) or label
end


local function IconMarkup(icon, offset)
	return "|T" .. icon .. ":0:0:0:" .. offset .. ICON_CROP .. "|t"
end

-- A link's icon is a link of its own to the same thing (Links.lua shows its
-- tooltip on hover and opens it on a click), so the mouse over the icon
-- shows what the name does. Not inside the game's link: shift-clicking that
-- one puts its text in the edit box, and an icon in it would make it a link
-- the game can't send.
Channels.ICON_LINK = "addon:Everchat:icon:"

local function IconLink(data, picture)
	return "|H" .. Channels.ICON_LINK .. data .. "|h" .. picture .. "|h"
end

-- Quest links get the "!" of the characters who give quests (2026-10-14, the
-- user, who found quest links confusing: the game colors them by difficulty,
-- red, orange, yellow, green, grey, nearly the items' quality colors, so an
-- orange quest read as a legendary item; of the game's quest marks, the user
-- chose this one over Forever's gold "!" from its quest button and the quest
-- log's book, which at line height read as an item icon). Drawn like a
-- typed "!": its yellow as tall as a capital (Roboto Condensed's 0.71 em,
-- the yellow being 49 of the art's 59 rows), its dot on the baseline (the
-- art's dark edge, 5 rows, below it), no frame (the frames are for square
-- icons). The atlas member "questnormal" (Forever has no -c60 of its own),
-- cut to the mark's rows and columns: texels 751-777 x 134-193 of its
-- 1024x1024 file, and 12 more transparent columns to its right as the gap
-- before the quest's name (about a space at this scale), so mark and quest
-- are one block the game never splits across rows. Sizes in whole units, as
-- markup numbers must be.
local QUEST_FILE = 1121272
local QUEST_CROP = ":1024:1024:751:789:134:193"
local QUEST_HEIGHT = 0.86
local QUEST_ART_WIDTH, QUEST_ART_HEIGHT, QUEST_ART_EDGE = 38, 59, 5

local function QuestMark(chatFrame)
	local _, fontHeight = chatFrame:GetFont()
	local height = math.floor((fontHeight or 14) * QUEST_HEIGHT + 0.5)
	local width = math.floor(height * QUEST_ART_WIDTH / QUEST_ART_HEIGHT + 0.5)
	local drop = math.floor(height * QUEST_ART_EDGE / QUEST_ART_HEIGHT + 0.5)
	return ("|T%d:%d:%d:0:%d%s|t"):format(QUEST_FILE, height, width, -drop, QUEST_CROP)
end

-- The game's stand-in for a missing icon (its logo, a gold "W"), which
-- Forever's profession recipes have as their spell's icon.
local PLACEHOLDER_ICON = 136235
local recipeIcons = {}

-- A recipe shows what it makes, as the game's crafting window does; a spell
-- with no icon of its own and nothing made gets none.
local function SpellIcon(id)
	local icon = C_Spell.GetSpellTexture(id)
	if icon ~= PLACEHOLDER_ICON then
		return icon
	end
	if recipeIcons[id] then
		return recipeIcons[id]
	end
	if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData) then
		return nil
	end
	local ok, output = pcall(C_TradeSkillUI.GetRecipeOutputItemData, id)
	if not ok or type(output) ~= "table" then
		return nil
	end
	icon = output.itemID and C_Item.GetItemIconByID(output.itemID) or output.icon
	if icon and icon ~= 0 and icon ~= PLACEHOLDER_ICON then
		recipeIcons[id] = icon
		return icon
	end
end

-- Links with an icon, by type: items, spells, and the recipes professions
-- link (enchant:<spell>).
local LINK_ICONS = {
	item = function(id)
		return C_Item.GetItemIconByID(id)
	end,
	spell = SpellIcon,
	enchant = SpellIcon,
}

-- Skills' icons by skill line (SkillLine.db2 on wago.tools): professions and
-- secondary skills have their own; weapon skills and Defense have none (a
-- question mark), so they take the icon of the spell that teaches them (One-
-- Handed Maces' mace, Defense's shield). Forever's newer lines for the same
-- professions (29xx) share their icons.
local SKILL_ICONS = {
	-- Weapons and Defense.
	[43] = 132223, [44] = 132392, [45] = 135493, [46] = 135610, [54] = 133476,
	[55] = 132223, [95] = 132279, [136] = 135145, [160] = 133479, [162] = 132154,
	[172] = 132395, [173] = 132321, [176] = 135426, [226] = 135530, [228] = 132317,
	[229] = 135129, [473] = 132938, [3014] = 132276,
	-- Secondary skills.
	[40] = 136242, [129] = 135966, [185] = 133971, [356] = 136245, [633] = 136058,
	[3012] = 135933, [2939] = 133971, [2942] = 135966, [2943] = 136245, [2988] = 136242,
	-- Professions.
	[164] = 136241, [165] = 136247, [171] = 136240, [182] = 136246, [186] = 136248,
	[197] = 136249, [202] = 136243, [333] = 136244, [393] = 134366,
	[2937] = 136240, [2938] = 136241, [2940] = 136244, [2941] = 136243, [2944] = 136246,
	[2945] = 136247, [2946] = 136248, [2947] = 134366, [2948] = 136249,
}

-- The skills' names in the game's language, longest first ("Two-Handed
-- Maces" before "Maces"): a skill-up line is searched for them instead of
-- being read through its sentence, whose grammar differs by language
-- (German numbers its blanks, Russian declines the name). From the
-- character's own list and by ID; built again when the skills change.
local skillNames

local function SkillNames()
	if skillNames then
		return skillNames
	end
	skillNames = {}
	local function Add(name, icon)
		if type(name) == "string" and name ~= "" and icon then
			table.insert(skillNames, { name = name, icon = icon })
		end
	end
	if C_SkillInfo then
		for id, icon in pairs(SKILL_ICONS) do
			local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, id)
			Add(ok and info and info.name, icon)
		end
		for index = 1, C_SkillInfo.GetNumSkillLines() do
			local info = C_SkillInfo.GetSkillLineInfo(index)
			if info and not info.isHeader then
				Add(info.name, SKILL_ICONS[info.skillID])
			end
		end
	end
	if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
		for id, icon in pairs(SKILL_ICONS) do
			local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, id)
			Add(ok and name, icon)
		end
	end
	table.sort(skillNames, function(a, b)
		return #a.name > #b.name
	end)
	-- Skills not known yet (early at login): asked again next time.
	local names = skillNames
	if #names == 0 then
		skillNames = nil
	end
	return names
end

local function FindSkill(text)
	for _, skill in ipairs(SkillNames()) do
		local start = text:find(skill.name, 1, true)
		if start then
			return start, skill.icon
		end
	end
end

-- A skill not found may be new since the names were looked up: once more
-- with the names asked again.
local function AddSkillIcon(text, offset)
	local start, icon = FindSkill(text)
	if not start then
		skillNames = nil
		start, icon = FindSkill(text)
	end
	if not start then
		return text
	end
	return text:sub(1, start - 1) .. IconMarkup(icon, offset) .. NO_BREAK_SPACE .. text:sub(start)
end

-- Whether what comes before `position` lets a word start there without a
-- space: the line's start, a space, or an opening mark.
local OPENERS = { ["("] = true, ["["] = true, ["{"] = true, ['"'] = true, ["'"] = true }
local OPENERS_UTF8 = { ["¿"] = true, ["¡"] = true, ["«"] = true, ["“"] = true, ["„"] = true, ["‘"] = true }

local function OpensWord(text, position)
	if position <= 1 then
		return true
	end
	local before = text:sub(position - 1, position - 1)
	if before:find("%s") or OPENERS[before] then
		return true
	end
	return OPENERS_UTF8[text:sub(position - 2, position - 1)] or OPENERS_UTF8[text:sub(position - 3, position - 1)] or false
end

-- A link's icon as a picture at the height of the text it's in, lowered
-- like the chat's (Bubbles.lua), or nil for a link with none.
function Channels.LinkIconMarkup(kind, id, fontHeight)
	local Icon = LINK_ICONS[kind]
	local icon = Icon and Icon(tonumber(id))
	if not icon then
		return nil
	end
	return IconMarkup(icon, tostring(-math.floor((fontHeight or 14) * ICON_DROP + 0.5)))
end

-- For the window the line goes to (its font size sets how far icons drop).
function Channels.AddIcons(text, event, chatFrame)
	if not ns.db.itemIcons then
		return text
	end
	local offset = IconOffset(chatFrame)
	if event == "CHAT_MSG_SKILL" then
		text = AddSkillIcon(text, offset)
	end
	if not text:find("|H", 1, true) then
		return text
	end
	-- A link: its color, |H<type>:<id>...|h[Name]|h|r. A link written right
	-- after a word or another link ("FOR[Tharil'zun]", "[Goblin
	-- Mortar][Goblin Sapper Charge]") gets a space before its icon, so the icon
	-- doesn't stick to what's before it and the row can break there (2026-10-14,
	-- the user); not after a space or an opening mark ("(", "¿", quotes).
	local source = text
	text = text:gsub("()(|c[^|]-|H((%a+):(%d+)[^|]*)|h.-|h|r)", function(position, link, data, kind, id)
		local mark
		if kind == "quest" then
			mark = IconLink(data, QuestMark(chatFrame))
		else
			local Icon = LINK_ICONS[kind]
			local icon = Icon and Icon(tonumber(id))
			if not icon then
				return link
			end
			mark = IconLink(data, IconMarkup(icon, offset)) .. NO_BREAK_SPACE
		end
		return (OpensWord(source, position) and "" or " ") .. mark .. link
	end)
	return text
end

-- Group chat labels ("[Party]", "[Raid Leader]", "[Raid Warning]",
-- "[Instance]"...) become a small icon in the chat type's color (the player's
-- own chat colors: party blue, raid and instance orange): two figures for the
-- group, three for a raid, the front one wearing a crown for its leader, a
-- warning sign for raid warnings. A closed set, learned at a glance; numbered
-- channels keep their short text, since their number is what /1, /2 type to.
-- The icon stays inside Blizzard's channel link, so clicking it still starts
-- a message there. The label is found through Blizzard's own CHAT_<type>_GET
-- string (read, never changed), so it works in every language. `crown` is
-- where the front figure's head is, across the icon (PlaceCrowns).
local GROUP_ATLAS = { name = "socialqueuing-icon-group", width = 29, height = 26, crown = 0.39 }
local RAID_ICON = {
	file = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\Shield.tga", fileWidth = 32, width = 32, height = 32, crown = 0.48,
}
RAID_ICON.marker = "|T" .. RAID_ICON.file .. ":"
GROUP_ATLAS.marker = "|A:" .. GROUP_ATLAS.name .. ":"
local RAID_TYPES = { RAID = true, RAID_LEADER = true }
local LEADER_ATLAS = { name = "ui-hud-unitframe-player-group-leadericon", width = 16, height = 16 }
local WARNING_ATLAS = { name = "services-icon-warning", width = 42, height = 37 }
local GROUP_LABELS = {
	PARTY = "group", PARTY_LEADER = "leader", PARTY_GUIDE = "leader",
	RAID = "group", RAID_LEADER = "leader", RAID_WARNING = "warning",
	INSTANCE_CHAT = "group", INSTANCE_CHAT_LEADER = "leader",
}
local LEADER_EVENTS = {}
for chatType, kind in pairs(GROUP_LABELS) do
	if kind == "leader" then
		LEADER_EVENTS["CHAT_MSG_" .. chatType] = true
	end
end

-- The labels a player can rename or show as an icon (Options > Channels), in
-- the game's order: the guild's, the officers', then the groups'. A guide's
-- label goes with its party leader's.
Channels.LABEL_KINDS = {
	"GUILD", "OFFICER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
}
local KIND_OF = { PARTY_GUIDE = "PARTY_LEADER" }

local function KindOf(chatType)
	return KIND_OF[chatType] or chatType
end

-- The lines a label shows on: its kind's (a guide's with the party
-- leader's), or a numbered channel's holding its name. A label changed in
-- the options composes only those again (Lines.RefreshEvents).
local KIND_EVENTS = {}
for _, kind in ipairs(Channels.LABEL_KINDS) do
	KIND_EVENTS[kind] = { ["CHAT_MSG_" .. kind] = true }
end
KIND_EVENTS.PARTY_LEADER.CHAT_MSG_PARTY_GUIDE = true
local CHANNEL_EVENTS = { CHAT_MSG_CHANNEL = true }

local function RefreshLabel(key)
	local channel = key:match("^channel:(.+)$")
	if channel then
		-- The lines holding the link of the number it has now, if one
		-- channel has its name; else every channel's.
		local holding, count = nil, 0
		for number, name in pairs(ListedChannels()) do
			if name == channel then
				holding, count = "|Hchannel:channel:" .. number .. "|h", count + 1
			end
		end
		ns.Lines.RefreshEvents(CHANNEL_EVENTS, count == 1 and holding or nil)
	elseif KIND_EVENTS[key] then
		ns.Lines.RefreshEvents(KIND_EVENTS[key])
	else
		ns.Lines.Refresh()
	end
end

-- Whether a kind of label has an icon to show as: the guild's crest, the
-- groups' figures (the officers' has none).
function Channels.HasIcon(kind)
	return kind == "GUILD" or GROUP_LABELS[kind] ~= nil
end

function Channels.ShowsIcon(chatType)
	local kind = KindOf(chatType)
	if kind == "GUILD" then
		return ns.db.guildBadge and true or false
	end
	return GROUP_LABELS[kind] ~= nil and not (ns.db.groupIconsOff or {})[kind]
end

function Channels.SetShowsIcon(kind, shown)
	if kind == "GUILD" then
		ns.db.guildBadge = shown and true or false
	else
		ns.db.groupIconsOff = ns.db.groupIconsOff or {}
		ns.db.groupIconsOff[kind] = not shown or nil
	end
	RefreshLabel(kind)
end

-- A label's own name (Options > Channels), by kind ("GUILD") or by a
-- numbered channel's name as the game writes it ("channel:Trade"); nil while
-- it has none.
local NAME_LETTERS = 16
local LETTER = "[%z\1-\127\194-\244][\128-\191]*"

function Channels.NameKey(name)
	return "channel:" .. name
end

function Channels.OwnName(key)
	local name = ns.db.channelNames and ns.db.channelNames[key]
	if type(name) == "string" and name ~= "" then
		return name
	end
end

-- A typed name as it's kept: plain text, without the game's text codes,
-- which start with "|", nor brackets, which the label puts around it; spaces
-- trimmed, NAME_LETTERS letters at most.
function Channels.CleanName(text)
	text = (text or ""):gsub("[|%[%]]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	local letters = 0
	return (text:gsub(LETTER, function(letter)
		letters = letters + 1
		return letters <= NAME_LETTERS and letter or ""
	end))
end

Channels.NAME_LETTERS = NAME_LETTERS

function Channels.SetOwnName(key, name)
	name = Channels.CleanName(name)
	ns.db.channelNames = ns.db.channelNames or {}
	if (ns.db.channelNames[key] or "") == name then
		return
	end
	ns.db.channelNames[key] = name ~= "" and name or nil
	RefreshLabel(key)
end

-- A kind's label under its own name: the game's "[Guild]" (found as
-- Channels.GroupLabel finds it) inside its link, so a click on it still
-- starts a message there.
local function Rename(text, chatType)
	local own = Channels.OwnName(KindOf(chatType))
	local label = own and Channels.GroupLabel(chatType)
	if not label then
		return text
	end
	local first, last = text:find(label, 1, true)
	if not first then
		return text
	end
	return text:sub(1, first - 1) .. "[" .. own .. "]" .. text:sub(last + 1)
end

-- The leader's crown sits on the head of the icon's front figure (bottom
-- left in the group's art, in the middle of the raid's). A line only places
-- images side by side, so it's drawn over the line like the guild's crest;
-- beside the icon it read as a separate sign. Measured on the art, as
-- fractions of the line's height: the crown's square is 59% of it, centered
-- on that head (the figures' `crown`, across the icon), and its gold (which
-- ends 77% down the square) rests on the head's top, 32% down the line in
-- both icons. A dark copy a pixel larger all round sets it off the figures.
local CROWN_SIZE = 0.59
local CROWN_ART_BOTTOM = 0.775
local CROWN_SEAT = 0.32
local CROWN_SHADOW_ALPHA = 0.85
-- Search.lua's results have no overlay: there the crown follows the icon,
-- smaller than the line, as it used to.
local LEADER_SCALE = 0.75

local function AtlasMarkup(atlas, height, color)
	local width = math.floor(height * atlas.width / atlas.height + 0.5)
	if color then
		return CreateAtlasMarkup(atlas.name, width, height, 0, 0,
			math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255))
	end
	return CreateAtlasMarkup(atlas.name, width, height)
end

-- The icons are as tall as the line.
local function IconSize(chatFrame)
	return math.floor(BadgeSize(chatFrame) + 0.5)
end

-- A kind of group's figures: the raid's three, the others' two.
local function Figures(chatType)
	return RAID_TYPES[chatType] and RAID_ICON or GROUP_ATLAS
end

local function FiguresMarkup(figures, height, color)
	if not figures.file then
		return AtlasMarkup(figures, height, color)
	end
	local width = math.floor(height * figures.width / figures.height + 0.5)
	local r, g, b = 255, 255, 255
	if color then
		r, g, b = math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255)
	end
	return ("%s%d:%d:0:0:%d:%d:0:%d:0:%d:%d:%d:%d|t"):format(figures.marker, height, width,
		figures.fileWidth, figures.height, figures.width, figures.height, r, g, b)
end

-- The label's icon (a leader's crown is drawn over it, PlaceCrowns).
local function GroupIcon(chatType, kind, chatFrame)
	if kind == "warning" then
		return AtlasMarkup(WARNING_ATLAS, IconSize(chatFrame))
	end
	return FiguresMarkup(Figures(chatType), IconSize(chatFrame), ChatTypeInfo[chatType])
end

-- Notices in the time's grey (2026-10-14, the user's call): friends' and
-- guildmates' logins and logouts (the game's ERR_FRIEND_ONLINE_SS and
-- ERR_FRIEND_OFFLINE_S, system lines) and channel notices (joined, left,
-- changed), so the talk around them stands out, as Discord and Slack show
-- joins and leaves; no WoW chat addon found does it (they hide such lines or
-- move them elsewhere). The game's own "Guild Member Alert" (Options >
-- Social) takes the guild's away entirely.
local NOTICE_EVENTS = { CHAT_MSG_CHANNEL_NOTICE = true, CHAT_MSG_CHANNEL_NOTICE_USER = true }
local noticePatterns

-- One of the game's format strings as a pattern for its whole lines.
local function FormatPattern(format)
	local escaped = format:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	return "^" .. escaped:gsub("%%%d*%$?s", ".-") .. "$"
end

local function IsNotice(message, event)
	if NOTICE_EVENTS[event] then
		return true
	end
	if event ~= nil and event ~= "CHAT_MSG_SYSTEM" then
		return false
	end
	if not noticePatterns then
		noticePatterns = {}
		for _, name in ipairs({ "ERR_FRIEND_ONLINE_SS", "ERR_FRIEND_OFFLINE_S" }) do
			if type(_G[name]) == "string" then
				table.insert(noticePatterns, FormatPattern(_G[name]))
			end
		end
	end
	for _, pattern in ipairs(noticePatterns) do
		if message:find(pattern) then
			return true
		end
	end
	return false
end

-- Lines.lua, last: the composed line in grey if the original is a notice
-- (a color ending inside it gives way to the grey again).
function Channels.MuteNotice(text, message, event)
	if not ns.db.muteNotices or not IsNotice(message, event) then
		return text
	end
	local grey = ns.Timestamps.GreyCode()
	return grey .. (text:gsub("|r", "|r" .. grey)) .. "|r"
end

-- The bracketed label the game writes before a kind of line ("[Guild]",
-- "[Hermandad]"), or nil without one. The options name what they replace
-- with it, in the game's own words.
function Channels.GroupLabel(chatType)
	local format = _G["CHAT_" .. chatType .. "_GET"]
	return type(format) == "string" and format:match("%[[^%]]*%]") or nil
end

local function DecorateGroup(text, chatFrame, chatType)
	local kind = GROUP_LABELS[chatType]
	local label = kind and Channels.GroupLabel(chatType)
	if not label then
		return text
	end
	local first, last = text:find(label, 1, true)
	if not first then
		return text
	end
	return text:sub(1, first - 1) .. GroupIcon(chatType, kind, chatFrame) .. text:sub(last + 1)
end

local function CreateCrown(overlay)
	local crown = CreateFrame("Frame", nil, overlay)
	crown.shadow = crown:CreateTexture(nil, "ARTWORK")
	crown.shadow:SetAtlas(LEADER_ATLAS.name)
	crown.shadow:SetVertexColor(0, 0, 0, CROWN_SHADOW_ALPHA)
	crown.art = crown:CreateTexture(nil, "ARTWORK", nil, 1)
	crown.art:SetAtlas(LEADER_ATLAS.name)
	crown.art:SetAllPoints()
	return crown
end

-- A crown over the group icon of every visible line its leader wrote (the
-- line's event, from Lines.lua). Returns how many it placed.
local function PlaceCrowns(chatFrame, overlay, px, fontHeight)
	local used = 0
	local size = IconSize(chatFrame)
	local crownSize = Snap(size * CROWN_SIZE, px)
	for _, line in ipairs(chatFrame.visibleLines) do
		local entry = line:IsShown() and line.messageInfo
		local text = entry and entry.message
		local event = entry and ns.Lines.EventOf(entry)
		if type(text) == "string" and canaccessvalue(text) and LEADER_EVENTS[event] and Channels.ShowsIcon(event:sub(10)) then
			local figures = Figures(event:sub(10))
			local start = text:find(figures.marker, 1, true)
			if start and HasReadableMeasures(line) then
				local x, rows = MeasureCached(overlay, LineCache(overlay, entry, text, line:GetWidth()), text, start)
				local iconWidth = math.floor(size * figures.width / figures.height + 0.5)
				used = used + 1
				local crown = overlay.crowns[used] or CreateCrown(overlay)
				overlay.crowns[used] = crown
				crown:SetSize(crownSize, crownSize)
				crown.shadow:ClearAllPoints()
				crown.shadow:SetPoint("TOPLEFT", -px, px)
				crown.shadow:SetPoint("BOTTOMRIGHT", px, -px)
				crown:ClearAllPoints()
				crown:SetPoint("TOPLEFT", line, "TOPLEFT",
					Snap(x + iconWidth * figures.crown - crownSize / 2, px),
					-Snap(rows * (fontHeight + line:GetSpacing()) + size * CROWN_SEAT - crownSize * CROWN_ART_BOTTOM, px))
				crown.line = line
				crown:SetAlpha(line:GetAlpha())
				crown:Show()
			end
		end
	end
	for index = used + 1, #overlay.crowns do
		overlay.crowns[index]:Hide()
		overlay.crowns[index].line = nil
	end
	return used
end

-- The wrapping measure in the window's font and the line's spacing, and the
-- step from one row of a message to the next (measured on the user's
-- screenshot: rows 20px apart, every row alike).
local function PrepareWrap(overlay, line)
	local wrap = overlay.wrap
	if wrap.fontKey ~= overlay.fontKey then
		wrap:SetFontObject(overlay.font)
		wrap:SetSpacing(line:GetSpacing())
		wrap:SetWidth(1000)
		wrap:SetText("X")
		local one = wrap:GetStringHeight()
		wrap:SetText("X\nX")
		overlay.rowStep = wrap:GetStringHeight() - one
		wrap.fontKey = overlay.fontKey
	end
	return wrap
end

-- Where each picture of a line matching `pattern` (the crest's or a
-- place holder: a font height square) lands: its
-- row and its x on that row, and where its markup is. On the first row the
-- width of the text before it says. Further down, the text before it is laid
-- out again at the line's width, where it wraps the same way: the picture is
-- on the last of those rows, which starts at the first word that reaches it
-- (found by halving over the spaces the line shows). Once per message and
-- kind: the results stay in its cache under `key`.
local function Spots(overlay, cache, text, line, pattern, key)
	if cache[key] then
		return cache[key]
	end
	cache.spaces = cache.spaces or Spaces(text)
	local spots = {}
	local from = 1
	while true do
		local first, last = text:find(pattern, from)
		if not first then
			break
		end
		from = last + 1
		local x, newlines = MeasureCached(overlay, cache, text, first)
		-- A line broken by hand: the rows can't be told apart from the wraps.
		if newlines > 0 then
			break
		end
		-- The picture wraps as one block with what's glued to it (the name's
		-- first word), up to the next space.
		local stop = #text + 1
		local cuts = {}
		for _, space in ipairs(cache.spaces) do
			if space.at > last then
				stop = space.at
				break
			end
			if space.at < first then
				table.insert(cuts, space)
			end
		end
		local block = Closed(text:sub(1, stop - 1))
		local measure = MeasureFont(overlay)
		measure:SetText(block)
		if measure:GetUnboundedStringWidth() <= cache.width then
			table.insert(spots, { x = x, row = 0, first = first, last = last })
		else
			local wrap = PrepareWrap(overlay, line)
			wrap:SetWidth(cache.width)
			wrap:SetText(block)
			local rows = wrap:GetNumLines()
			-- The first word to reach the picture's row.
			local low, high, found = 1, #cuts, nil
			while low <= high do
				local middle = math.floor((low + high) / 2)
				wrap:SetText(Closed(text:sub(1, cuts[middle].at - 1)))
				if wrap:GetNumLines() >= rows then
					found = middle
					high = middle - 1
				else
					low = middle + 1
				end
			end
			-- The row starts after the space before that word (or after the
			-- last one, when the picture's own word starts it), in the color
			-- and the link open there.
			local cut = cuts[found and found - 1 or #cuts]
			local rowX = 0
			if cut then
				measure:SetText(Closed((cut.color or "") .. (cut.link or "") .. text:sub(cut.at + 1, first - 1)))
				rowX = measure:GetUnboundedStringWidth()
			end
			table.insert(spots, { x = rowX, row = rows - 1, first = first, last = last })
		end
	end
	cache[key] = spots
	return spots
end

-- On whole screen pixels, worked out the way the game puts text on them: a
-- line rarely starts on a pixel, its text (pictures included) goes to the
-- pixel up and to the left, while a frame placed between pixels goes to the
-- nearest, so half the time it sat a pixel right or low. What's drawn over a
-- picture goes where the picture is, on whole pixels.
local EPSILON = 0.01

-- Where the picture at `spot` starts, from its line's top left: the line's
-- top, where the text's rows start. A picture as tall as the font standing
-- on the baseline rises a little above it without moving the line (its rows
-- keep their place), so what's drawn over a font height square from there
-- sits centered on the text.
local function SpotOffset(overlay, line, spot, px)
	local lineLeft, lineTop = line:GetLeft() / px, line:GetTop() / px
	local left = math.floor(lineLeft + EPSILON) + math.floor(spot.x / px + EPSILON)
	local top = math.ceil(lineTop - EPSILON)
		- (spot.row > 0 and math.floor(spot.row * overlay.rowStep / px + EPSILON) or 0)
	return (left - lineLeft) * px, (top - lineTop) * px
end

-- The guild's crest over its place in a line (GuildBadge): the banner in the
-- tabard's background color, the emblem in its color, the border over both.
local function SetAtlasCrop(texture, atlas)
	local info = C_Texture.GetAtlasInfo(atlas)
	if info then
		texture:SetTexture(info.file or info.filename)
		texture:SetTexCoord(CropCoords(info))
	end
end

local function CreateCrest(overlay)
	local crest = CreateFrame("Frame", nil, overlay)
	crest.banner = crest:CreateTexture(nil, "ARTWORK")
	crest.banner:SetAllPoints()
	SetAtlasCrop(crest.banner, BANNER_ATLAS)
	crest.emblem = crest:CreateTexture(nil, "ARTWORK", nil, 1)
	crest.border = crest:CreateTexture(nil, "OVERLAY")
	crest.border:SetAllPoints()
	SetAtlasCrop(crest.border, BORDER_ATLAS)
	return crest
end

-- In whole screen pixels, the emblem's width of the crest's parity, so the
-- margins on its two sides are equal.
local function DressCrest(crest, pixels, tabard, px)
	crest:SetSize(pixels * px, pixels * px)
	crest.banner:SetVertexColor(tabard.backgroundColor:GetRGB())
	local sheet = pixels < LARGE_SHEET_PIXELS and EMBLEM_SHEETS.small or EMBLEM_SHEETS.large
	local index = tabard.emblemStyle
	local x = (index % sheet.columns) * sheet.cell
	local y = math.floor(index / sheet.columns) * sheet.cell
	crest.emblem:SetTexture(sheet.file)
	crest.emblem:SetTexCoord(x + sheet.inset, x + sheet.cell - sheet.inset, y + sheet.inset, y + sheet.cell - sheet.inset)
	local height = math.floor(pixels * sheet.height + 0.5)
	local parity = pixels % 2
	local width = math.floor((height * EMBLEM_ASPECT - parity) / 2 + 0.5) * 2 + parity
	crest.emblem:SetSize(width * px, height * px)
	crest.emblem:ClearAllPoints()
	crest.emblem:SetPoint("TOPLEFT", crest, "TOPLEFT", (pixels - width) / 2 * px,
		-math.floor(pixels * sheet.center - height / 2 + 0.5) * px)
	crest.emblem:SetVertexColor(tabard.emblemColor:GetRGB())
	local r, g, b = tabard.borderColor:GetRGB()
	crest.border:SetVertexColor(r, g, b, BORDER_ALPHA)
end

-- Lines whose text is secret are never read. Returns how many it placed.
local function PlaceCrests(chatFrame, overlay, px, fontHeight)
	local used = 0
	-- The tabard is only looked up once a line has a crest.
	local tabard
	local pixels = math.floor(fontHeight / px + 0.5)
	for _, line in ipairs(chatFrame.visibleLines) do
		local entry = line:IsShown() and line.messageInfo
		local text = entry and entry.message
		if type(text) == "string" and canaccessvalue(text) and text:find(CREST_CROP, 1, true) and HasReadableMeasures(line) then
			if tabard == nil then
				tabard = DesignedTabard() or false
			end
			if tabard then
				local cache = LineCache(overlay, entry, text, line:GetWidth())
				for _, spot in ipairs(Spots(overlay, cache, text, line, CREST_ESCAPE, "crests")) do
					used = used + 1
					local crest = overlay.crests[used] or CreateCrest(overlay)
					overlay.crests[used] = crest
					DressCrest(crest, pixels, tabard, px)
					crest:ClearAllPoints()
					crest:SetPoint("TOPLEFT", line, "TOPLEFT", SpotOffset(overlay, line, spot, px))
					crest.line = line
					crest:SetAlpha(line:GetAlpha())
					crest:Show()
				end
			end
		end
	end
	for index = used + 1, #overlay.crests do
		overlay.crests[index]:Hide()
		overlay.crests[index].line = nil
	end
	return used
end

-- After each display refresh, and when the chat stops moving (its lines move
-- without one, and the frames' whole pixels were worked out where they were):
-- the crests and crowns over the lines.
local function PlaceMarks(chatFrame)
	local overlay = overlays[chatFrame]
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, overlay)
	local _, fontHeight = chatFrame:GetFont()
	overlay.font = ns.Fonts.ForFrame(chatFrame)
	overlay.measureFont = overlay.font
	overlay.fontKey = tostring(fontHeight) .. tostring(overlay.font)
	overlay.settleAt = nil
	local used = PlaceCrests(chatFrame, overlay, px, fontHeight)
	used = used + PlaceCrowns(chatFrame, overlay, px, fontHeight)
	overlay.active = used > 0
	-- Lines in view still to be measured again (LineCache).
	if overlay.settleAt and not overlay.settling then
		overlay.settling = true
		C_Timer.After(math.max(0, overlay.settleAt - GetTime()) + 0.05, function()
			overlay.settling = false
			if chatFrame:IsVisible() then
				PlaceMarks(chatFrame)
			end
		end)
	end
end

-- The chat stopped moving (Resize.lua).
function Channels.Realign()
	for chatFrame in pairs(overlays) do
		if chatFrame:IsVisible() then
			PlaceMarks(chatFrame)
		end
	end
end

-- For Search.lua's results, plain copies of the lines without the overlay:
-- a leader's line gets its crown back inline, after the icon's link.
function Channels.InlineCrown(text, entry, chatFrame)
	local event = ns.Lines.EventOf(entry)
	if type(text) ~= "string" or not canaccessvalue(text) or not LEADER_EVENTS[event]
		or not Channels.ShowsIcon(event:sub(10)) then
		return text
	end
	local crown = AtlasMarkup(LEADER_ATLAS, math.floor(IconSize(chatFrame) * LEADER_SCALE + 0.5))
	local figures = Figures(event:sub(10))
	local close = figures.file and "|t|h" or "|a|h"
	return (text:gsub("(" .. figures.marker:gsub("%p", "%%%0") .. "[^|]*" .. close .. ")", "%1" .. crown, 1))
end

-- ...and the crest's place holder becomes its banner.
function Channels.InlineMarks(text)
	if type(text) ~= "string" or not canaccessvalue(text) then
		return text
	end
	if text:find(CREST_CROP, 1, true) then
		local banner = InlineBanner()
		text = text:gsub(CREST_ESCAPE, function()
			return banner
		end)
	end
	return text
end

-- For copying (Lines.PlainText): the labels' names as shown, but always some
-- label (even in a one-channel tab, or where an icon shows): pasted
-- elsewhere, a line needs to say where it came from.
function Channels.ShortLabel(text, event)
	if event == "CHAT_MSG_CHANNEL" then
		return (text:gsub(CHANNEL_LABEL, function(open, label, close)
			return open .. "[" .. ChannelLabel(open, label) .. "]" .. close
		end, 1))
	end
	local chatType = type(event) == "string" and event:sub(10) or nil
	if chatType and (GROUP_LABELS[chatType] or chatType == "GUILD" or chatType == "OFFICER")
		and not Channels.ShowsIcon(chatType) then
		return Rename(text, chatType)
	end
	return text
end

-- Use the channel name in the edit box, including any user-defined name.
function Channels.HeaderText(chatType, channelName, current, number)
	if type(current) ~= "string" or current == "" then
		return nil
	end
	if chatType == "CHANNEL" then
		local listed = number and ListedChannels()[number]
		if type(channelName) ~= "string" or channelName == "" then
			channelName = listed or current:match("%[(.-)%]")
		end
		if not channelName or channelName == "" then return nil end
		local name = Channels.OwnName(ChannelKey(number, channelName)) or Channels.BaseName(listed or channelName)
		if name == "" then return nil end
		return name .. (current:match("%s*:%s*$") or ": ")
	end
	if not (GROUP_LABELS[chatType] or chatType == "GUILD" or chatType == "OFFICER") or Channels.ShowsIcon(chatType) then
		return nil
	end
	local own = Channels.OwnName(KindOf(chatType))
	local send = _G["CHAT_" .. chatType .. "_SEND"]
	local colon = type(send) == "string" and send:match("%s*:%s*$")
	if own and colon and current == send then
		return own .. colon
	end
	return nil
end

-- A line's labels as the options want them (Lines.lua composes the line):
-- the channel's short name (no label at all in a one-channel tab), group
-- chat icons, and the guild's coat of arms (no label at all in the guild's
-- own tab).
function Channels.Decorate(text, chatFrame, event)
	local chatType = type(event) == "string" and event:sub(10) or nil
	if chatType and GROUP_LABELS[chatType] then
		if Channels.ShowsIcon(chatType) then
			return DecorateGroup(text, chatFrame, chatType)
		end
		return Rename(text, chatType)
	end
	if event == "CHAT_MSG_CHANNEL" then
		if ns.db.shortChannels and IsSingleChannel(chatFrame) then
			return (text:gsub(CHANNEL_LABEL .. " ?", "", 1))
		end
		return (text:gsub(CHANNEL_LABEL, function(open, label, close)
			return open .. "[" .. ChannelLabel(open, label) .. "]" .. close
		end, 1))
	end
	-- The guild's crest, while its box is ticked: then the guild's own name
	-- isn't used. A guild without a designed tabard shows the green banner
	-- its members' marks have then (MARKS.guild).
	if chatType == "GUILD" and ns.db.guildBadge then
		if IsGuildOnly(chatFrame) then
			return (text:gsub(GUILD_LABEL .. " ?", "", 1))
		end
		return (text:gsub(GUILD_LABEL, "%1" .. (GuildBadge() or MarkMarkup("guild", chatFrame)) .. "%2", 1))
	end
	if chatType == "GUILD" or chatType == "OFFICER" then
		return Rename(text, chatType)
	end
	return text
end

-- Repeated ads in numbered channels (Trade, General, LookingForGroup...): a
-- message identical to one the same player sent to the same channel less
-- than REPEAT_SECONDS ago is hidden, so an ad posted every minute shows at
-- most once every five. Only numbered channels: in guild, group, whispers or
-- say people repeat on purpose ("inv", "ready?"). Never the player's own.
-- Through Blizzard's message filters (ChatFrameUtil.AddMessageEventFilter,
-- kept in a secure registry and called only for readable messages), which run
-- once per window showing the message: the verdict is kept by line ID so
-- every window agrees.
local REPEAT_SECONDS = 300
-- Remembered ads and verdicts are pruned past this many.
local REPEAT_MEMORY = 2000

local lastShown, lastShownCount = {}, 0
-- Verdicts by line ID, and a ring of the IDs to forget the oldest.
local verdicts, verdictRing, verdictLast = {}, {}, 0

local function PruneShown(now)
	if lastShownCount < REPEAT_MEMORY then
		return
	end
	lastShownCount = 0
	for key, shown in pairs(lastShown) do
		if now - shown >= REPEAT_SECONDS then
			lastShown[key] = nil
		else
			lastShownCount = lastShownCount + 1
		end
	end
end

local function Remember(lineID, hide)
	verdicts[lineID] = hide
	verdictLast = verdictLast % REPEAT_MEMORY + 1
	local forgotten = verdictRing[verdictLast]
	if forgotten ~= nil then
		verdicts[forgotten] = nil
	end
	verdictRing[verdictLast] = lineID
end

local function FilterRepeats(_, _, text, sender, _, _, _, _, _, channelIndex, _, _, lineID, guid)
	if not ns.db.hideRepeats or type(text) ~= "string" or type(sender) ~= "string" then
		return false
	end
	if guid and guid == UnitGUID("player") then
		return false
	end
	if lineID and verdicts[lineID] ~= nil then
		return verdicts[lineID]
	end
	-- Same words, whatever the spacing or capitals.
	local words = text:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	local key = sender .. "\0" .. tostring(channelIndex) .. "\0" .. words
	local now = GetTime()
	local shown = lastShown[key]
	local hide = shown ~= nil and now - shown < REPEAT_SECONDS
	if not hide then
		if not shown then
			lastShownCount = lastShownCount + 1
		end
		lastShown[key] = now
		PruneShown(now)
	end
	if lineID then
		Remember(lineID, hide)
	end
	return hide
end

local function HookAllChatFrames()
	for _, name in pairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		if not hookedFrames[chatFrame] and chatFrame ~= COMBATLOG then
			CreateOverlay(chatFrame)
			-- The frame's own callback for addons, after each display refresh.
			chatFrame:AddOnDisplayRefreshedCallback(ns.Guard("Channels.PlaceMarks", PlaceMarks))
			hookedFrames[chatFrame] = true
		end
	end
end

-- The icon a kind of label shows as, drawn as the chat draws it, for the
-- options' rows: the guild's crest, or the green banner while the guild (or
-- the character) has none designed; the groups' figures in the chat's color
-- with a leader's crown, the raid warning's sign. `icon:Paint()` draws it
-- again (a new color, the tabard).
function Channels.CreateLabelIcon(parent, kind, height)
	local icon = CreateFrame("Frame", nil, parent)
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, parent)
	local pixels = math.floor(height / px + 0.5)
	local size = pixels * px
	icon:SetSize(size, size)
	if kind == "GUILD" then
		local crest = CreateCrest(icon)
		crest:SetPoint("CENTER")
		local banner = icon:CreateTexture(nil, "ARTWORK")
		banner:SetTexture(MARKS.guild:match("^|T([^:]+)"))
		banner:SetAllPoints()
		function icon.Paint()
			local tabard = DesignedTabard()
			crest:SetShown(tabard and true or false)
			banner:SetShown(not tabard)
			if tabard then
				DressCrest(crest, pixels, tabard, px)
			end
		end
	else
		local figures = GROUP_LABELS[kind] == "warning" and WARNING_ATLAS or Figures(kind)
		local art = icon:CreateTexture(nil, "ARTWORK")
		if figures.file then
			art:SetTexture(figures.file)
			art:SetTexCoord(0, figures.width / figures.fileWidth, 0, 1)
		else
			art:SetAtlas(figures.name)
		end
		local width = math.floor(pixels * figures.width / figures.height + 0.5) * px
		art:SetSize(width, size)
		art:SetPoint("LEFT")
		icon:SetWidth(width)
		if GROUP_LABELS[kind] == "leader" then
			local crown = CreateCrown(icon)
			local crownSize = Snap(size * CROWN_SIZE, px)
			crown:SetSize(crownSize, crownSize)
			crown.shadow:SetPoint("TOPLEFT", -px, px)
			crown.shadow:SetPoint("BOTTOMRIGHT", px, -px)
			crown:SetPoint("TOPLEFT", icon, "TOPLEFT", Snap(width * figures.crown - crownSize / 2, px),
				-Snap(size * CROWN_SEAT - crownSize * CROWN_ART_BOTTOM, px))
		end
		function icon.Paint()
			local info = figures ~= WARNING_ATLAS and ChatTypeInfo[kind]
			if info then
				art:SetVertexColor(info.r, info.g, info.b)
			end
		end
	end
	icon.Paint()
	return icon
end

-- The group icons carry their chat's color in the line, so their lines are
-- composed again once a color stops changing (the color picker changes it
-- as the cursor moves), each kind's only.
local recolorTimer
local recolorKinds = {}

local function QueueRecolor(chatType)
	recolorKinds[KindOf(chatType)] = true
	if recolorTimer then
		recolorTimer:Cancel()
	end
	recolorTimer = C_Timer.NewTimer(0.2, function()
		recolorTimer = nil
		for kind in pairs(recolorKinds) do
			RefreshLabel(kind)
		end
		wipe(recolorKinds)
	end)
end

-- A label's color is the game's for its kind of chat (ChatTypeInfo; a
-- numbered channel's by its number, "CHANNEL2"), and is written as the
-- game's own chat settings write it: the game repaints its lines itself.
function Channels.ColorOf(chatType)
	local info = ChatTypeInfo[chatType]
	if info then
		return info.r, info.g, info.b
	end
end

function Channels.SetColor(chatType, r, g, b)
	ChangeChatColor(chatType, r, g, b)
	if GROUP_LABELS[chatType] and Channels.ShowsIcon(chatType) then
		QueueRecolor(chatType)
	end
end

-- The game's chat colors on a new character, as bytes, to put a label's
-- back: the game has no kind's default to read, it only resets them all at
-- once (ResetChatColors). Every numbered channel starts pink.
local DEFAULT_COLORS = {
	GUILD = { 64, 255, 64 }, OFFICER = { 64, 192, 64 },
	PARTY = { 170, 170, 255 }, PARTY_LEADER = { 118, 200, 255 },
	RAID = { 255, 127, 0 }, RAID_LEADER = { 255, 72, 9 }, RAID_WARNING = { 255, 72, 0 },
	INSTANCE_CHAT = { 255, 127, 0 }, INSTANCE_CHAT_LEADER = { 255, 72, 9 },
	CHANNEL = { 255, 192, 192 },
}

local function DefaultColor(chatType)
	if type(chatType) ~= "string" then
		return nil
	end
	return DEFAULT_COLORS[chatType] or (chatType:match("^CHANNEL%d+$") and DEFAULT_COLORS.CHANNEL) or nil
end

local function IsDefaultColor(chatType)
	local default = DefaultColor(chatType)
	local r, g, b = Channels.ColorOf(chatType or "")
	if not (default and r) then
		return true
	end
	return math.floor(r * 255 + 0.5) == default[1] and math.floor(g * 255 + 0.5) == default[2]
		and math.floor(b * 255 + 0.5) == default[3]
end

-- Whether a label shows as the game's (Options > Channels): no name of its
-- own, its icon (where it has one) shown, its color the game's.
function Channels.IsDefault(key, kind, chatType)
	return not Channels.OwnName(key) and not (kind and Channels.HasIcon(kind) and not Channels.ShowsIcon(kind))
		and IsDefaultColor(chatType)
end

-- Puts a label back as the game shows it.
function Channels.ResetLabel(key, kind, chatType)
	if ns.db.channelNames then
		ns.db.channelNames[key] = nil
	end
	if kind == "GUILD" then
		ns.db.guildBadge = true
	elseif kind and ns.db.groupIconsOff then
		ns.db.groupIconsOff[kind] = nil
	end
	RefreshLabel(key)
	if not IsDefaultColor(chatType) then
		local default = DefaultColor(chatType)
		Channels.SetColor(chatType, default[1] / 255, default[2] / 255, default[3] / 255)
	end
end

function Channels.Init()
	ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_CHANNEL", FilterRepeats)
	HookAllChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", HookAllChatFrames)
	hooksecurefunc("FCF_OpenTemporaryWindow", HookAllChatFrames)
	-- A new font size or font: what was measured goes.
	ns.Fonts.OnSizeChanged(function(chatFrame)
		local overlay = overlays[chatFrame]
		if overlay then
			wipe(overlay.layouts)
		end
	end)
	-- Skills learned, raised or forgotten: their names are looked up again.
	-- The guild's tabard: a line holds the crest's place only while the guild
	-- has a tabard designed, and the game gives a guild joined during the
	-- session its tabard a moment after its first lines, so the lines are
	-- composed and drawn again whenever the tabard changes.
	local tabardKey = TabardKey()
	local refreshQueued = false
	local events = CreateFrame("Frame")
	events:RegisterEvent("SKILL_LINES_CHANGED")
	events:RegisterEvent("PLAYER_GUILD_UPDATE")
	events:RegisterEvent("GUILDTABARD_UPDATE")
	events:RegisterEvent("GUILD_ROSTER_UPDATE")
	-- A group's color changed: in the game's chat settings, or loaded at login
	-- after the lines brought back from the last session were composed (in
	-- the white every kind has until then).
	events:RegisterEvent("UPDATE_CHAT_COLOR")
	-- Channels joined or left: the numbers lines find their channels by
	-- (ListedChannels), and the lines of channels with names of their own.
	events:RegisterEvent("CHANNEL_UI_UPDATE")
	events:SetScript("OnEvent", function(_, event, chatType)
		if event == "SKILL_LINES_CHANGED" then
			skillNames = nil
			return
		end
		if event == "CHANNEL_UI_UPDATE" then
			local listed, changed = ListChannels(), false
			local before = listedChannels or {}
			for number, name in pairs(listed) do
				changed = changed or before[number] ~= name
			end
			for number in pairs(before) do
				changed = changed or listed[number] == nil
			end
			if changed then
				listedChannels = next(listed) and listed or nil
				for key in pairs(ns.db.channelNames or {}) do
					if key:find("^channel:") then
						ns.Lines.RefreshEvents(CHANNEL_EVENTS)
						break
					end
				end
			end
			return
		end
		if event == "UPDATE_CHAT_COLOR" then
			if type(chatType) == "string" and GROUP_LABELS[chatType:upper()] then
				QueueRecolor(chatType:upper())
			end
			return
		end
		if refreshQueued then
			return
		end
		refreshQueued = true
		C_Timer.After(0, function()
			refreshQueued = false
			local key = TabardKey()
			if key ~= tabardKey then
				tabardKey = key
				ns.Lines.Refresh()
			end
		end)
	end)
end
