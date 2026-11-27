local ns = BaziUI.Chat
local Theme = ns.Theme

local Timestamps = {}
ns.Timestamps = Timestamps

-- Every message starts with its time, in a muted grey, where the game's own
-- timestamps go: always there, so each line says when it was written and a
-- pause shows as a jump in the times. (v0.26.0; before, only the first message
-- of each minute had it, and a divider marked long pauses: the user found it
-- ambiguous which lines a time belonged to.)
-- In the game clock's own format (the 24-hour clock option, and its
-- localized AM/PM otherwise).
local TIME_SEPARATOR = "  "

local function FormatClock(clock)
	return date("%H:%M", clock)
end

-- The last minute formatted, for the lines that keep coming in it (the
-- 24-hour option can change between them).
local lastMinute, lastMilitary, lastText

local function FormatTime(clock)
	local minute = math.floor(clock / 60)
	local military = C_CVar.GetCVar("timeMgrUseMilitaryTime")
	if minute ~= lastMinute or military ~= lastMilitary then
		lastMinute, lastMilitary, lastText = minute, military, FormatClock(clock)
	end
	return lastText
end

-- A time as the chat writes it (Whispers.lua's notice).
function Timestamps.FormatClock(clock)
	return FormatTime(clock)
end

-- A line's day and time for its time's tooltip (Links.lua), the day as the
-- game's calendar writes it ("Saturday, October 10"): History brings lines
-- back from the day before, whose time alone doesn't say which day.
function Timestamps.FullDate(clock)
	local fields = date("*t", clock)
	local day = CalendarUtil and CalendarUtil.FormatCalendarTimeWeekday
		and CalendarUtil.FormatCalendarTimeWeekday({ weekday = fields.wday, month = fields.month, monthDay = fields.day })
	return day and (day .. ", " .. FormatTime(clock)) or FormatTime(clock)
end

-- Line spacing (Options > Appearance, 2026-10-13, the user's call; Better
-- Forever Chat offers it too): the space between the wrapped lines of a
-- message (the frame's own spacing, a secure ScrollingMessageFrame setter,
-- over what it has on load) and the extra air between messages, in units.
-- "normal" is what Everchat always drew (v0.26.0's gap of 3), "compact" the
-- game's own; the combat log keeps the game's.
local SPACINGS = {
	compact = { lines = 0, messages = 0 },
	normal = { lines = 0, messages = 3 },
	wide = { lines = 2, messages = 6 },
}

local function Spacing()
	return SPACINGS[ns.db.lineSpacing] or SPACINGS.normal
end

-- More air between messages while a line separates them (Options >
-- Appearance > Accessibility), so it doesn't sit against the text.
local LINE_AIR = 3

-- The air between two messages, in units.
local function MessageGap()
	return Spacing().messages + (ns.db.messageSeparator == "line" and LINE_AIR or 0)
end

-- Chat frames set up, each with the spacing it had on load; never marked on
-- Blizzard frames.
local states = {}

-- Whether the game's own timestamps are on (Options > Social). Read from the
-- CVar: the Settings value ChatFrameUtil.GetTimestampFormat reads isn't loaded
-- yet for the first lines after login, which then got both times.
function Timestamps.GameShowsTimes()
	local value = C_CVar.GetCVar("showTimestamps")
	return value ~= nil and value ~= "" and value ~= "none"
end

local function IsEnabled()
	-- Defer to the game's own timestamps when the player has them enabled.
	return ns.db.timestamps and not Timestamps.GameShowsTimes()
end

local function Concat(prefix, message)
	return prefix .. message
end

local greyCode

-- The time's grey as a color code (notices take it too, Channels.lua).
function Timestamps.GreyCode()
	greyCode = greyCode or ("|cff%02x%02x%02x"):format(Theme.TIME.r * 255, Theme.TIME.g * 255, Theme.TIME.b * 255)
	return greyCode
end

local function Grey(text)
	return Timestamps.GreyCode() .. text .. "|r"
end

-- A line with its time in front (Lines.lua), or as it is while the times are
-- off. Concatenating works for secret messages too; if it ever fails, the
-- line is left as it is.
-- With `lineID` (Lines.lua, readable lines only) the time is a link: clicking
-- it opens the line as text, ready to copy (Links.lua), as BasicChatMods and
-- Prat let players do.
local LINE_LINK = "|Haddon:Everchat:line:%d|h%s|h"

function Timestamps.Prefix(text, clock, lineID)
	if not IsEnabled() then
		return text
	end
	local time = Grey(FormatTime(clock))
	if lineID then
		time = LINE_LINK:format(lineID, time)
	end
	local ok, prefixed = pcall(Concat, time .. TIME_SEPARATOR, text)
	return ok and prefixed or text
end

-- Blizzard shows one font string per message and chains each to the one below
-- in RefreshLayout; once the display is refreshed (which always follows a new
-- layout) they're re-anchored with more air between messages than between the
-- lines of one. The frame's own callback for addons (AddOnDisplayRefreshedCallback,
-- run through secureexecuterange) rather than a hook on its private methods.
-- Called with the window once its lines are in their places (Skin.lua).
local placedListeners = {}

function Timestamps.OnLinesPlaced(listener)
	table.insert(placedListeners, listener)
end

-- Where each message starts and ends, wrapped ones too (Options >
-- Appearance > Accessibility, `messageSeparator`): "bands", every other
-- message on a lighter ground, or "line", a thin neutral line across the
-- middle of the gap between two messages (one in the theme's gold read as
-- another header line). Drawn on a frame under
-- the lines, clipped where they're clipped. Which messages are lit stays put
-- as lines arrive and scroll: a message keeps the opposite of its
-- neighbor's, remembered by its history entry.
local BAND_ALPHA = 0.07
local LINE_ALPHA = 0.16
-- A single pixel, as Discord's old dividers between message groups were (the
-- ones its players with low vision asked to have back): a 2px line read as
-- heavy.
local LINE_PIXELS = 1
local bandFrames = {}
local lit = setmetatable({}, { __mode = "k" })

-- Lines fade without a display refresh: what's drawn follows their alpha.
local function FollowLines(frame)
	for _, regions in ipairs({frame.marks, frame.clocks, frame.channels}) do
		for _, mark in ipairs(regions) do
			if mark.line then mark:SetAlpha(mark.line:IsShown() and mark.line:GetAlpha() or 0) end
		end
	end
end

local function BandFrame(chatFrame)
	local frame = bandFrames[chatFrame]
	if not frame then
		local container = chatFrame.FontStringContainer
		frame = CreateFrame("Frame", nil, chatFrame)
		frame:SetAllPoints(container)
		frame:SetClipsChildren(true)
		-- With the lines, above the card's fill (the chat frame's own
		-- regions); a faint light over a letter changes nothing that shows.
		frame:SetFrameLevel(container:GetFrameLevel())
		frame.marks = {}
		frame.clocks = {}
		frame.channels = {}
		frame:SetScript("OnUpdate", ns.Guard("Timestamps.FollowLines", FollowLines))
		bandFrames[chatFrame] = frame
	end
	return frame
end

local function Readable(value)
	return type(value) == "number" and canaccessvalue(value)
end

-- Which visible messages are lit: from one already known, every other.
local function LitMessages(lines)
	local known
	for index, line in ipairs(lines) do
		local entry = line:IsShown() and line.messageInfo
		if entry and lit[entry] ~= nil then
			known = index
			break
		end
	end
	if not known then
		local entry = lines[1] and lines[1]:IsShown() and lines[1].messageInfo
		if not entry then
			return
		end
		lit[entry], known = false, 1
	end
	local anchor = lines[known].messageInfo
	for index, line in ipairs(lines) do
		local entry = line:IsShown() and line.messageInfo
		if entry and lit[entry] == nil then
			lit[entry] = lit[anchor] ~= ((index - known) % 2 == 1)
		end
	end
end

local function Mark(frame, used)
	local mark = frame.marks[used]
	if not mark then
		mark = frame:CreateTexture(nil, "BACKGROUND")
		frame.marks[used] = mark
	end
	mark:ClearAllPoints()
	return mark
end

local function PlaceGroupRails(frame, lines, fromTop, used, left, px)
	if not Readable(left) then return used end
	local first, last
	local r, g, b = BaziUI.Theme:Accent()
	local function flush()
		if not first then return end
		local firstLeft, lastLeft = first:GetLeft(), last:GetLeft()
		if Readable(firstLeft) and Readable(lastLeft) then
			used = used + 1
			local accent = Mark(frame, used)
			accent:SetColorTexture(r, g, b, 0.90)
			accent:SetPoint("TOPLEFT", first, "TOPLEFT", left - firstLeft + px, -px)
			accent:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", left - lastLeft + px, px)
			accent:SetWidth(2 * px)
			accent.line = first
			accent:SetAlpha(first:GetAlpha())
			accent:Show()
		end
		first, last = nil, nil
	end
	local start, finish, step = 1, #lines, 1
	if not fromTop then start, finish, step = finish, start, -1 end
	for i = start, finish, step do
		local line = lines[i]
		local entry = line:IsShown() and line.messageInfo
		local continued, speaker = ns.Lines.GroupInfo(entry)
		if not speaker or not continued then flush() end
		if speaker then
			first = first or line
			last = line
		end
	end
	flush()
	return used
end

local function PlaceGroupClocks(frame, lines, right)
	local used = 0
	if (ns.db.timestamps or Timestamps.GameShowsTimes()) and Readable(right) then
		for _, line in ipairs(lines) do
			local continued, _, clock = ns.Lines.GroupInfo(line:IsShown() and line.messageInfo)
			local edge = not continued and clock and line:GetRight()
			if Readable(edge) then
				used = used + 1
				local label = frame.clocks[used]
				if not label then
					label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					label:SetTextColor(0.71, 0.66, 0.60)
					label:SetJustifyH("RIGHT")
					frame.clocks[used] = label
				end
				label:ClearAllPoints()
				label:SetPoint("TOPRIGHT", line, "TOPRIGHT", right - edge - 1, 0)
				label:SetText(FormatTime(clock))
				label.line = line
				label:SetAlpha(line:GetAlpha())
				label:Show()
			end
		end
	end
	for i = used + 1, #frame.clocks do
		frame.clocks[i]:Hide()
		frame.clocks[i].line = nil
	end
end

function Timestamps.ChannelSize(nameSize)
	return math.max(6, math.min(32, ns.db.channelSize or (nameSize - 2)))
end

local channelArt = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\"
local function PlaceChannelLabels(frame, lines)
	local used = 0
	for _, line in ipairs(lines) do
		local sender, channel, icon = ns.Lines.ChannelLabel(line:IsShown() and line.messageInfo)
		if sender then
			local file, nameSize, flags = line:GetFont()
			local lineWidth = line:GetWidth()
			if file and Readable(nameSize) and Readable(lineWidth) then
				local measure = frame.nameMeasure
				if not measure then
					measure = frame:CreateFontString(nil, "OVERLAY")
					measure:Hide()
					frame.nameMeasure = measure
				end
				measure:SetFont(file, nameSize, flags)
				measure:SetText(sender)
				local x = measure:GetStringWidth() + 7
				if x < lineWidth then
					used = used + 1
					local label = frame.channels[used]
					if not label then
						label = frame:CreateFontString(nil, "OVERLAY")
						label:SetTextColor(0.73, 0.68, 0.62)
						label:SetJustifyH("LEFT")
						label:SetWordWrap(false)
						frame.channels[used] = label
					end
					local size = Timestamps.ChannelSize(nameSize)
					local iconSize = math.max(6, math.floor(size - 1))
					label:SetFont(file, size, flags)
					label:ClearAllPoints()
					label:SetPoint("TOPLEFT", line, "TOPLEFT", x, 0)
					label:SetWidth(lineWidth - x)
					label:SetText(("|T%s%s.tga:%d:%d|t %s"):format(channelArt, icon, iconSize, iconSize, channel))
					label.line = line
					label:SetAlpha(line:GetAlpha())
					label:Show()
				end
			end
		end
	end
	for i = used + 1, #frame.channels do
		frame.channels[i]:Hide()
		frame.channels[i].line = nil
	end
end

local function PlaceSeparators(chatFrame)
	local mode = ns.db.messageSeparator
	local frame = BandFrame(chatFrame)
	frame:Show()
	local lines = chatFrame.visibleLines
	local container = chatFrame.FontStringContainer
	local left, right = container:GetLeft(), container:GetRight()
	local edge = chatFrame:GetRight()
	if Readable(right) and Readable(edge) then
		frame:SetPoint("TOPLEFT", container, "TOPLEFT")
		frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", edge - right, 0)
	end
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, chatFrame)
	local fromTop = chatFrame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
	if mode == "bands" then
		LitMessages(lines)
	end
	local used = 0
	for index, line in ipairs(lines) do
		local entry = line:IsShown() and line.messageInfo
		local nextLine = lines[index + (fromTop and 1 or -1)]
		local nextContinued = nextLine and ns.Lines.GroupInfo(nextLine.messageInfo)
		local lineLeft = entry and line:GetLeft()
		-- Half the gap to the next message, above and below.
		local half = (MessageGap() + 3 + line:GetSpacing()) / 2
		if entry and Readable(left) and Readable(right) and Readable(lineLeft) then
			local mark
			if mode == "bands" and lit[entry] then
				used = used + 1
				mark = Mark(frame, used)
				mark:SetColorTexture(1, 1, 1, BAND_ALPHA)
				mark:SetPoint("TOPLEFT", line, "TOPLEFT", left - lineLeft, half)
				mark:SetPoint("BOTTOMRIGHT", line, "BOTTOMLEFT", right - lineLeft, -half)
			elseif mode == "line" and nextLine and not nextContinued and Readable(line:GetBottom()) then
				-- Under every message but the newest, in the middle of the gap.
				used = used + 1
				mark = Mark(frame, used)
				mark:SetColorTexture(1, 1, 1, LINE_ALPHA)
				local bottom = line:GetBottom()
				local top = math.floor((bottom - half) / px + 0.5) * px
				local snappedLeft = math.floor(left / px + 0.5) * px
				local snappedRight = math.floor(right / px + 0.5) * px
				mark:SetPoint("TOPLEFT", line, "BOTTOMLEFT", snappedLeft - lineLeft, top - bottom)
				mark:SetPoint("TOPRIGHT", line, "BOTTOMLEFT", snappedRight - lineLeft, top - bottom)
				mark:SetHeight(LINE_PIXELS * px)
			end
			if mark then
				mark.line = line
				mark:SetAlpha(line:GetAlpha())
				mark:Show()
			end
		end
	end
	used = PlaceGroupRails(frame, lines, fromTop, used, left, px)
	PlaceGroupClocks(frame, lines, edge)
	PlaceChannelLabels(frame, lines)
	for index = used + 1, #frame.marks do
		frame.marks[index]:Hide()
		frame.marks[index].line = nil
	end
end

local function OnDisplayRefreshed(chatFrame)
	local lines = chatFrame.visibleLines
	local fromTop = chatFrame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
	local container = chatFrame.FontStringContainer
	local left = container and container:GetLeft()
	local available = container and container:GetWidth()
	local timestamps = ns.db.timestamps or Timestamps.GameShowsTimes()
	local function indent(line)
		local continued, speaker, clock = ns.Lines.GroupInfo(line.messageInfo)
		local inset = speaker and 9 or 0
		if Readable(available) and line.SetWidth then
			local width = math.max(40, available - inset - (timestamps and clock and not continued and 44 or 0))
			local oldWidth = line:GetWidth()
			if Readable(oldWidth) and oldWidth ~= width then line:SetWidth(width) end
		end
		return inset
	end
	local first = lines[1]
	local previousInset = first and indent(first) or 0
	if first and Readable(left) then
		local point, relative, edge, _, y = first:GetPoint(1)
		local anchorLeft = relative and relative:GetLeft()
		if (point == "TOPLEFT" or point == "BOTTOMLEFT") and (edge == "TOPLEFT" or edge == "BOTTOMLEFT")
			and Readable(anchorLeft) and Readable(y) then
			first:SetPoint(point, relative, edge, left + previousInset - anchorLeft, y)
		else
			previousInset = 0
		end
	else
		previousInset = 0
	end
	for index = 2, #lines do
		local line, previous = lines[index], lines[index - 1]
		local newer = fromTop and line or previous
		local continued = ns.Lines.GroupInfo(newer.messageInfo)
		local gap = line:GetSpacing() + (continued and 2 or MessageGap() + 3)
		local inset = indent(line)
		if fromTop then
			line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", inset - previousInset, -gap)
		else
			line:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", inset - previousInset, gap)
		end
		previousInset = inset
	end
	PlaceSeparators(chatFrame)
	for _, listener in ipairs(placedListeners) do
		listener(chatFrame)
	end
end

local followTimers = setmetatable({}, {__mode = "k"})
local function scheduleTail(chatFrame, reset)
	local existing = followTimers[chatFrame]
	local offset = chatFrame:GetScrollOffset()
	if type(offset) ~= "number" or (issecretvalue and issecretvalue(offset)) or (canaccessvalue and not canaccessvalue(offset)) then return end
	if existing and (reset or offset == 0) then
		existing:Cancel()
		followTimers[chatFrame] = nil
	end
	if offset <= 0 or followTimers[chatFrame] then return end
	followTimers[chatFrame] = C_Timer.NewTimer(15, function()
		followTimers[chatFrame] = nil
		if ns.active and chatFrame.ScrollToBottom then chatFrame:ScrollToBottom() end
	end)
end

local function Setup(chatFrame)
	-- The combat log has its own timestamp option.
	if states[chatFrame] or chatFrame == COMBATLOG then
		return
	end

	states[chatFrame] = chatFrame:GetSpacing() or 0

	-- Wrapped lines start flush with the message.
	if chatFrame:GetIndentedWordWrap() then
		chatFrame:SetIndentedWordWrap(false)
	end
	if Spacing().lines ~= 0 then
		chatFrame:SetSpacing(states[chatFrame] + Spacing().lines)
	end
	chatFrame:AddOnDisplayRefreshedCallback(ns.Guard("Timestamps.OnDisplayRefreshed", function(window)
		scheduleTail(window, false)
		OnDisplayRefreshed(window)
	end))
	if chatFrame.SetScrollOffset then
		hooksecurefunc(chatFrame, "SetScrollOffset", function() scheduleTail(chatFrame, true) end)
	else
		for _, method in ipairs({"ScrollUp", "ScrollDown", "PageUp", "PageDown", "ScrollToTop", "ScrollToBottom"}) do
			if chatFrame[method] then hooksecurefunc(chatFrame, method, function() scheduleTail(chatFrame, true) end) end
		end
		chatFrame:HookScript("OnMouseWheel", function() scheduleTail(chatFrame, true) end)
	end
	chatFrame:MarkLayoutDirty()
end

local function SetupAllChatFrames()
	for _, name in pairs(CHAT_FRAMES) do
		Setup(_G[name])
	end
end

-- Call after choosing how messages are told apart: every window lays its
-- lines out again.
function Timestamps.RefreshSeparators()
	for chatFrame in pairs(states) do
		chatFrame:MarkLayoutDirty()
		ns.Fonts.Changed(chatFrame)
	end
end

-- Call after turning the times on or off: every line is composed again.
function Timestamps.Refresh()
	ns.Lines.Refresh()
end

-- Call after changing the line spacing: every window lays its lines out
-- again (the display refresh re-anchors the messages with the new air), and
-- what was measured on them goes.
function Timestamps.ApplySpacing()
	for chatFrame, base in pairs(states) do
		chatFrame:SetSpacing(base + Spacing().lines)
		chatFrame:MarkLayoutDirty()
		ns.Fonts.Changed(chatFrame)
	end
end

function Timestamps.Init()
	SetupAllChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", SetupAllChatFrames)
	hooksecurefunc("FCF_OpenTemporaryWindow", SetupAllChatFrames)
end
