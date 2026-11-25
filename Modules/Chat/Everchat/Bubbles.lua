local ns = BaziUI.Chat

local Bubbles = {}
ns.Bubbles = Bubbles

-- What chat bubbles say, dressed as the chat's lines are (Options >
-- Appearance > Chat bubbles): an icon before each linked item or spell, the
-- links in their own colors, and the speaker's name over the text in their
-- class's color. The game writes a bubble's text itself, from the message,
-- so each new bubble is found right after its message (the bubbles the game
-- lets addons see, C_ChatBubbles.GetAllChatBubbles), known by its text and
-- given the dressed one; the bubble sizes itself to it. Inside dungeons,
-- raids, battlegrounds and arenas the game keeps its bubbles to itself, and
-- they stay as it draws them there. The bubbles' font, size and edge are
-- the font object's, everywhere (Fonts.lua).
local L = ns.L

-- The talk that shows in bubbles.
local EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY",
}
-- How long a message waits for its bubble.
local WAIT = 1

-- The widest a bubble grows for what's added to it (the game's own wrap
-- width for a long message is kept).
local MAX_WIDTH = 300

local pending = {}
-- The text each bubble was given, by the bubble (the game's frame, never
-- written to): a bubble the game reuses for another message has new text.
local dressed = setmetatable({}, { __mode = "k" })
local watcher = CreateFrame("Frame")
-- Measures the dressed text's lines (hidden: it's only for its widths).
local measure = watcher:CreateFontString(nil, "ARTWORK")
measure:Hide()

-- The game sized the bubble to its own text: one line keeps its width, which
-- the name over it or an icon would overflow (the name broke letter by
-- letter), so it takes the widest line now, up to MAX_WIDTH; a message the
-- game wrapped keeps the game's width.
local function Fit(label, before, lines)
	if lines > 1 then
		return
	end
	local font, height, flags = label:GetFont()
	measure:SetFont(font, height, flags or "")
	local widest = before
	for line in (label:GetText() .. "\n"):gmatch("(.-)\n") do
		measure:SetText(line)
		widest = math.max(widest, measure:GetUnboundedStringWidth())
	end
	label:SetWidth(math.min(math.ceil(widest) + 1, math.max(before, MAX_WIDTH)))
end

local function Readable(value)
	return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- A link's name as bubbles show it: without its brackets.
local function Bare(name)
	return (name:gsub("^%[(.*)%]$", "%1"))
end

-- The text without its codes, as the game writes it in a bubble: no colors
-- or pictures, links as their bare names.
local function Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
		:gsub("|H.-|h(.-)|h", Bare):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

local function Active()
	local db = ns.db
	return db.bubbleIcons or db.bubbleColors or db.bubbleNames
end

-- The message as the bubble shows it: each link's icon before its name, the
-- name in its color or plain, and the speaker's name over it.
local function Dress(message, sender, guid, fontHeight)
	local db = ns.db
	-- A link right after a word or another link gets a space before its
	-- icon, as in the chat, so the two don't run together.
	local text = message:gsub("()(|c[^|]-)|H((%a+):(%d+)[^|]*)|h(.-)|h|r", function(position, color, _, kind, id, name)
		name = Bare(name)
		local icon = db.bubbleIcons and ns.Channels.LinkIconMarkup(kind, id, fontHeight)
		local shown = db.bubbleColors and (color .. name .. "|r") or name
		if not icon then
			return shown
		end
		local before = position > 1 and message:sub(position - 1, position - 1) or " "
		local space = before:find("[%s%(%[{\"']") and "" or " "
		return space .. icon .. "\194\160" .. shown
	end)
	text = text:gsub("|H.-|h(.-)|h", Bare)
	if db.bubbleNames and sender and sender ~= "" then
		local name = Ambiguate(sender, "none")
		local class = guid and select(2, GetPlayerInfoByGUID(guid))
		local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
		name = color and color:WrapTextInColorCode(name) or name
		text = name .. "\n" .. text
	end
	return text
end

local function Scan()
	local now = GetTime()
	for index = #pending, 1, -1 do
		if now - pending[index].at > WAIT then
			table.remove(pending, index)
		end
	end
	if #pending == 0 then
		watcher:SetScript("OnUpdate", nil)
		return
	end
	for _, bubble in ipairs(C_ChatBubbles.GetAllChatBubbles(false)) do
		local holder = bubble:GetChildren()
		local label = holder and not holder:IsForbidden() and holder.String
		local text = label and label:GetText()
		if Readable(text) and dressed[holder] ~= text then
			local plain = Plain(text)
			if Bubbles.debug and not Bubbles.debug[text] then
				Bubbles.debug[text] = true
				print("|cffff7f00bubble|r " .. text:gsub("|", "||") .. " => " .. plain:gsub("|", "||"))
				for _, message in ipairs(pending) do
					print("|cffff7f00message|r " .. message.text:gsub("|", "||") .. " => " .. message.plain:gsub("|", "||"))
				end
			end
			for index, message in ipairs(pending) do
				if message.plain == plain then
					local _, fontHeight = label:GetFont()
					local before, lines = label:GetWidth(), label:GetNumLines()
					label:SetText(Dress(message.text, message.sender, message.guid, fontHeight))
					Fit(label, before, lines)
					dressed[holder] = label:GetText()
					table.remove(pending, index)
					break
				end
			end
		end
	end
end

local function OnEvent(_, _, message, sender, ...)
	if not Active() or not (Readable(message) and Readable(sender)) then
		return
	end
	local guid = select(10, ...)
	if not Readable(guid) or guid == "" then
		guid = nil
	end
	-- Only what something here changes: a link, or a name to put over it.
	if not ns.db.bubbleNames and not message:find("|H", 1, true) then
		return
	end
	table.insert(pending, { text = message, plain = Plain(message), sender = sender, guid = guid, at = GetTime() })
	watcher:SetScript("OnUpdate", ns.Guard("Bubbles.Scan", Scan))
end

-- The options' example bubble: a sample line with a link in color, dressed
-- as the bubbles are now, the player's name over it. The link is the
-- player's own: an item from the bags of uncommon quality or better, or else
-- one of the class's spells (their links are always colored), or else any
-- item from the bags.
local function BagLink()
	if not (C_Container and C_Container.GetContainerNumSlots) then
		return nil, nil
	end
	local first
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local link = C_Container.GetContainerItemLink(bag, slot)
			if link then
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and info.quality and info.quality >= 2 then
					return link, first
				end
				first = first or link
			end
		end
	end
	return nil, first
end

local function SpellLink()
	local book = C_SpellBook
	if not (book and book.GetNumSpellBookSkillLines and C_Spell and C_Spell.GetSpellLink and Enum.SpellBookSpellBank) then
		return nil
	end
	-- The class's spells first (the second line of the book), then the rest.
	local lines = book.GetNumSpellBookSkillLines()
	for _, index in ipairs({ 2, 1, 3, 4, 5 }) do
		local line = index <= lines and book.GetSpellBookSkillLineInfo(index)
		if line then
			for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
				local info = book.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
				if info and info.spellID and not info.isPassive and info.itemType == Enum.SpellBookItemType.Spell then
					local link = C_Spell.GetSpellLink(info.spellID)
					if link then
						return link
					end
				end
			end
		end
	end
end

local function SampleLink()
	local good, any = BagLink()
	return good or SpellLink() or any
end

-- A link of the player's own for examples (Whispers.lua too).
Bubbles.SampleLink = SampleLink

function Bubbles.Sample(fontHeight)
	local db = ns.db
	local text = L.bubbleSample
	local link = SampleLink()
	if link then
		text = Dress(text .. " " .. link, nil, nil, fontHeight)
	end
	local name = db.bubbleNames and UnitName("player")
	if name then
		local _, class = UnitClass("player")
		local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
		text = (color and color:WrapTextInColorCode(name) or name) .. "\n" .. text
	end
	return text
end

function Bubbles.Init()
	if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then
		return
	end
	for _, event in ipairs(EVENTS) do
		watcher:RegisterEvent(event)
	end
	watcher:SetScript("OnEvent", OnEvent)
end
