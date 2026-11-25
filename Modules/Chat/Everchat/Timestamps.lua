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
	for _, mark in ipairs(frame.marks) do
		if mark.line then
			mark:SetAlpha(mark.line:IsShown() and mark.line:GetAlpha() or 0)
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

local function PlaceSeparators(chatFrame)
	local mode = ns.db.messageSeparator
	local frame = bandFrames[chatFrame]
	if mode ~= "bands" and mode ~= "line" then
		if frame then
			frame:Hide()
		end
		return
	end
	frame = BandFrame(chatFrame)
	frame:Show()
	local lines = chatFrame.visibleLines
	local left, right = frame:GetLeft(), frame:GetRight()
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, chatFrame)
	if mode == "bands" then
		LitMessages(lines)
	end
	local used = 0
	for index, line in ipairs(lines) do
		local entry = line:IsShown() and line.messageInfo
		local lineLeft = entry and line:GetLeft()
		-- Half the gap to the next message, above and below.
		local half = (MessageGap() + line:GetSpacing()) / 2
		if entry and Readable(left) and Readable(right) and Readable(lineLeft) then
			local mark
			if mode == "bands" and lit[entry] then
				used = used + 1
				mark = Mark(frame, used)
				mark:SetColorTexture(1, 1, 1, BAND_ALPHA)
				mark:SetPoint("TOPLEFT", line, "TOPLEFT", left - lineLeft, half)
				mark:SetPoint("BOTTOMRIGHT", line, "BOTTOMLEFT", right - lineLeft, -half)
			elseif mode == "line" and index > 1 and Readable(line:GetBottom()) then
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
	for index = used + 1, #frame.marks do
		frame.marks[index]:Hide()
		frame.marks[index].line = nil
	end
end

local function OnDisplayRefreshed(chatFrame)
	local lines = chatFrame.visibleLines
	local fromTop = chatFrame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
	for index = 2, #lines do
		local line, previous = lines[index], lines[index - 1]
		local gap = line:GetSpacing() + MessageGap()
		if fromTop then
			line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -gap)
		else
			line:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, gap)
		end
	end
	PlaceSeparators(chatFrame)
	for _, listener in ipairs(placedListeners) do
		listener(chatFrame)
	end
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
	chatFrame:AddOnDisplayRefreshedCallback(ns.Guard("Timestamps.OnDisplayRefreshed", OnDisplayRefreshed))
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
