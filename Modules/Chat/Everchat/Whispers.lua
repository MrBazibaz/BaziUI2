local ns = BaziUI.Chat
local Theme = ns.Theme
local L = ns.L

local Whispers = {}
ns.Whispers = Whispers

-- A notice for whispers that arrive while the chat isn't in use (Options >
-- Alerts > Whispers, on by default), over the chat by default. It grows with
-- the conversation up to three lines and no further: the newest at the
-- bottom, each new one rising in slowly, the mouse wheel going back to older
-- ones. Other people wait as small tabs in its header with what they've left
-- unread, and come in turn once the one in view is done. The mouse on it
-- stops its time. A message counts as read here once it has been in view a
-- moment (READ_AFTER), for the notice alone: a notice can come and go while
-- the player looks elsewhere, so the tab's dot stays until the tab is opened
-- (Alerts.lua), while reading it in the chat reaches the notice.
-- Its header moves it as the chat's header moves the chat: locked with the
-- chat (Shift still moves it), a Shift-click locking or unlocking both. Its
-- body opens the conversation: one of the game's secure action buttons lies
-- over it, and the player's own click on it clicks the conversation's tab by
-- the game's clean path (an addon selecting a tab, or setting the box's
-- whisper, would leave the send path tainted). Such a button can only be
-- anchored to the screen, and the game lets no addon set one up in combat:
-- it's placed where the body is, and put away as combat starts; the notice
-- still shows meanwhile, to read. A whisper the game hands over protected
-- (in instances) shows as "New whisper".

local WIDTH = 300
local PAD = 10
-- The scroll bar's column at the right of the lines.
local BAR_COLUMN = 15
local BAR_WIDTH = 10
-- Short enough to show where it is, long enough to read as a bar.
local THUMB_MIN = 20
local HEADER = 24
local FOOTER = 14
local TOP_GAP = 8
local VISIBLE = 3
local LINE_GAP = 3
-- Time in sight, from what there is to read: a moment to see it and a
-- little per word, within limits; times the player's choice (Options).
local BASE_SECONDS = 3
local WORD_SECONDS = 0.35
local MIN_SECONDS, MAX_SECONDS = 5, 20
local DURATIONS = { short = 0.7, normal = 1, long = 1.5 }
local READ_AFTER = 1.2
local SLIDE = 0.55
local WHEEL = 0.32
local FRESH = 1.5
local FADE_IN = 0.45
-- The notice coming into sight and going.
local APPEAR = 0.25
local LEAVE = 0.45
local CHIPS = 4
-- The other conversations' tabs: their light under the mouse, as the
-- chat's tabs have it.
local CHIP_HOVER = 0.05
local CHIP_FADE = 0.12
-- The close button: the game's, smaller than its usual 22 to sit in the
-- header, and resting dim until the mouse comes onto the notice.
local CLOSE_SIZE = 16
local CLOSE_REST = 0.4
local CLOSE_FADE = 0.12
local DOT_PIXELS = 6
local MEDIA = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\"
local DOT_GAP = 5
local RIM_ALPHA = 0.5
local BODY_HOVER_ALPHA = 0.05
-- The time left, a thin line in the theme's color.
local TIMER_ALPHA = 0.3
local TIMER_PAUSED = 0.12
local EVENTS = { CHAT_MSG_WHISPER = true, CHAT_MSG_BN_WHISPER = true }

local toast
local convs, active = {}, nil
local timeLeft, timeTotal = 0, 1
local byID = {}

local function Readable(value)
	return value ~= nil and canaccessvalue(value)
end

-- Where the game keeps chat from addons (encounters, Mythic+, PvP matches),
-- whispers come unreadable: the notice stays out there, and one on show
-- goes as that starts.
local function Restricted()
	return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function EaseOut(k)
	return 1 - (1 - k) ^ 3
end

local function Unread(conv)
	local count = 0
	for _, message in ipairs(conv.messages) do
		if not message.read then
			count = count + 1
		end
	end
	return count
end

-- The words a message says, without its codes (colors, links' data,
-- pictures).
local function Words(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
		:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	local count = 0
	for _ in text:gmatch("%S+") do
		count = count + 1
	end
	return count
end

-- How long the conversation stays in sight: for what's unread in it, or its
-- last message once all is read.
local function Duration(conv)
	local words = 0
	for _, message in ipairs(conv.messages) do
		if not message.read then
			words = words + Words(message.text)
		end
	end
	if words == 0 and conv.messages[1] then
		words = Words(conv.messages[#conv.messages].text)
	end
	local seconds = math.min(MAX_SECONDS, math.max(MIN_SECONDS, BASE_SECONDS + WORD_SECONDS * words))
	return seconds * (DURATIONS[ns.db.whisperDuration] or 1)
end

local function RestartTime(conv)
	timeTotal = Duration(conv)
	timeLeft = timeTotal
end

-- The window that shows a conversation, for Open: a whisper window of that
-- person, else a docked window showing whispers other than General, else
-- General.
-- The game keeps a whisper window's person upper-cased with their realm
-- ("LEEROY JENKINS-REALM"), a Battle.net friend's as their token: compared
-- by name alone, in any case.
local function SamePerson(target, sender)
	if target == sender then
		return true
	end
	local function Base(name)
		return (name:match("^([^%-]+)") or name):lower()
	end
	return Base(target) == Base(sender)
end

-- A person's own whisper window, open (a closed one keeps its old person
-- until it's reused).
local function PersonalTab(conv)
	if not conv.target then
		return nil
	end
	local chatType = conv.event == "CHAT_MSG_BN_WHISPER" and "BN_WHISPER" or "WHISPER"
	for _, name in ipairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		local target = chatFrame and chatFrame.isTemporary and chatFrame.inUse and chatFrame.chatTarget
		if target and chatFrame.chatType == chatType and Readable(target) and SamePerson(target, conv.target) then
			return _G[name .. "Tab"]
		end
	end
end

local function TabFor(conv)
	local own = PersonalTab(conv)
	if own then
		return own
	end
	for _, name in ipairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		if chatFrame and not chatFrame.isTemporary and chatFrame ~= DEFAULT_CHAT_FRAME and chatFrame ~= COMBATLOG
			and chatFrame.isDocked and chatFrame:IsEventRegistered(conv.event) then
			return _G[name .. "Tab"]
		end
	end
	return _G[DEFAULT_CHAT_FRAME:GetName() .. "Tab"]
end

-- What the notice would open, for /everchat whispers.
function Whispers.Report()
	print("Everchat whispers: whisperMode = " .. tostring(C_CVar.GetCVar("whisperMode")))
	for _, name in ipairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		if chatFrame and chatFrame.isTemporary then
			local tab = _G[name .. "Tab"]
			print(("  %s: type %s, target %s, inUse %s, docked %s, constrained %s"):format(name,
				tostring(chatFrame.chatType), Readable(chatFrame.chatTarget) and tostring(chatFrame.chatTarget) or "?",
				tostring(chatFrame.inUse), tostring(chatFrame.isDocked),
				tostring(tab and tab.HasAccessConstraints and tab:HasAccessConstraints())))
		end
	end
	for _, conv in ipairs(convs) do
		local tab = TabFor(conv)
		print(("  %s (%s): target %s -> %s"):format(tostring(conv.name), tostring(conv.event),
			tostring(conv.target), tab and tab:GetName() or "none"))
	end
	if toast then
		local clickbutton = toast.open:GetAttribute("clickbutton")
		print("  button: " .. (clickbutton and clickbutton:GetName() or "none")
			.. (toast.open:IsShown() and ", shown" or ", hidden"))
	end
end

-- The lines' font: the chat's at its main window's size.
local function LineFont()
	return ns.Fonts.ForSize(ns.Fonts.GetSize(DEFAULT_CHAT_FRAME))
end

-- One line's step, as the lines are laid out: a line's height as drawn
-- and the gap under it.
local function LineHeight()
	local measure = toast.measure
	measure:SetFontObject(LineFont())
	return measure:GetStringHeight() + LINE_GAP
end

local Render, Finish, PlaceOpen, Message

-- Where the notice stands: where the player put it, or over the chat. It
-- stands on its bottom, so it grows upwards.
local function Place()
	toast:ClearAllPoints()
	local pos = ns.db.whisperToastPos
	if pos then
		toast:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	else
		toast:SetPoint("BOTTOMLEFT", GENERAL_CHAT_DOCK, "TOPLEFT", 0, 10)
	end
end

-- A protected frame can only be anchored to the screen, not to the notice:
-- Open is placed over the notice's body, and again whenever the notice moves
-- or grows.
function Whispers.AnchorOpen()
	if not toast or InCombatLockdown() then
		return
	end
	local left, right = toast:GetLeft(), toast:GetRight()
	local top, bottom = toast:GetTop(), toast:GetBottom()
	if not (left and right and top and bottom) then
		return
	end
	-- Not over the scroll bar, which takes its own clicks.
	if toast.bar.shown then
		right = right - BAR_COLUMN + 2
	end
	local placed = toast.placed
	if placed[1] == left and placed[2] == right and placed[3] == top and placed[4] == bottom then
		return
	end
	placed[1], placed[2], placed[3], placed[4] = left, right, top, bottom
	local open = toast.open
	open:ClearAllPoints()
	open:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top - HEADER)
	open:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, bottom)
end

function Whispers.ResetPosition()
	ns.db.whisperToastPos = nil
	ns.Alerts.NotifySwitchChanged()
	if toast then
		Place()
		Whispers.AnchorOpen()
	end
end

-- The lines: stacked top down in a frame that grows with them, whose bottom
-- stands on the view's bottom, offset by the scroll and by the rise of a
-- line just come in.
local function SetContentY()
	toast.content:ClearAllPoints()
	local y = -toast.offset + toast.rise
	toast.content:SetPoint("BOTTOMLEFT", toast.clip, "BOTTOMLEFT", 0, y)
	toast.content:SetPoint("BOTTOMRIGHT", toast.clip, "BOTTOMRIGHT", 0, y)
end

local function ContentHeight()
	return toast.content:GetHeight()
end

-- The view: as tall as the conversation, up to VISIBLE lines exactly (what
-- those lines measure), so it doesn't move once it's full.
local function ClipHeight()
	local step = LineHeight()
	return math.max(step - LINE_GAP, math.min(ContentHeight(), VISIBLE * step - LINE_GAP))
end

local function SetClipHeight(height)
	toast.clip:SetHeight(height)
	toast:SetHeight(HEADER + TOP_GAP + height + FOOTER)
	Whispers.AnchorOpen()
end

local function MaxOffset()
	return math.max(0, ContentHeight() - toast.clip:GetHeight())
end

local function ScrollTo(offset, animate)
	offset = math.max(0, math.min(MaxOffset(), offset))
	if animate then
		toast.scroll = { from = toast.offset, to = offset, at = GetTime() }
	else
		toast.scroll = nil
		toast.offset = offset
		SetContentY()
	end
end

local function LayoutLines()
	local height = 0
	local previous
	for _, message in ipairs(active.messages) do
		local line = message.line
		line:ClearAllPoints()
		if previous then
			line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -LINE_GAP)
		else
			line:SetPoint("TOPLEFT", toast.content, "TOPLEFT")
		end
		line:SetPoint("RIGHT", toast.content, "RIGHT")
		height = height + line:GetStringHeight() + (previous and LINE_GAP or 0)
		previous = line
	end
	toast.content:SetHeight(math.max(1, height))
	-- The view's full height, past which the bar shows.
	toast.full = VISIBLE * LineHeight() - LINE_GAP
end

local function NewLine(message)
	local line = table.remove(toast.spare) or toast.content:CreateFontString(nil, "ARTWORK")
	line:SetParent(toast.content)
	line:SetFontObject(LineFont())
	line:SetJustifyH("LEFT")
	line:SetWordWrap(true)
	-- A wrapped line's rows as far apart as the lines: every row on one
	-- pitch, so the full view always ends on a whole row.
	line:SetSpacing(LINE_GAP)
	line:SetTextColor(ChatTypeInfo.WHISPER.r, ChatTypeInfo.WHISPER.g, ChatTypeInfo.WHISPER.b)
	line:SetText(ns.Timestamps.GreyCode() .. message.clock .. "|r " .. message.text)
	line:SetAlpha(1)
	line:Show()
	message.line = line
	return line
end

local function DropLines(conv)
	for _, message in ipairs(conv.messages) do
		if message.line then
			message.line:Hide()
			table.insert(toast.spare, message.line)
			message.line = nil
		end
	end
end

-- The small tabs of the others waiting, with what they've left unread.
local function RenderChips()
	local index = 0
	local anchor = toast.name
	for _, conv in ipairs(convs) do
		if conv ~= active and index < CHIPS then
			index = index + 1
			local chip = toast.chips[index]
			local unread = Unread(conv)
			chip.conv = conv
			chip.label:SetText(conv.short)
			-- Unread: the dot the chat's tabs have, in the whisper's color.
			local color = ChatTypeInfo[conv.event == "CHAT_MSG_BN_WHISPER" and "BN_WHISPER" or "WHISPER"]
			chip.dot:SetVertexColor(color.r, color.g, color.b)
			chip.dot:SetShown(unread > 0)
			chip:SetWidth(chip.label:GetUnboundedStringWidth() + 14 + (unread > 0 and DOT_GAP + chip.dot:GetWidth() or 0))
			chip:ClearAllPoints()
			chip:SetPoint("LEFT", anchor, "RIGHT", index == 1 and 8 or 4, 0)
			chip:Show()
			anchor = chip
		end
	end
	for rest = index + 1, CHIPS do
		toast.chips[rest]:Hide()
	end
end

-- `animate`: the notice is in sight, so it changes height smoothly and the
-- lines come in fading.
function Render(animate)
	local conv = active
	toast.name:SetText(conv.name)
	toast.name:SetTextColor(conv.color.r, conv.color.g, conv.color.b)
	local now = GetTime()
	for _, message in ipairs(conv.messages) do
		if not message.line then
			NewLine(message)
		end
		if animate then
			message.line:SetAlpha(0)
			message.enterAt = now
		end
	end
	LayoutLines()
	toast.rise, toast.riseAnim = 0, nil
	SetContentY()
	local target, current = ClipHeight(), toast.clip:GetHeight()
	if animate and math.abs(target - current) > 0.5 then
		toast.clipAnim = { from = current, to = target, at = now }
	else
		toast.clipAnim = nil
		SetClipHeight(target)
	end
	ScrollTo(0)
	RenderChips()
	PlaceOpen()
end

local function Freshen()
	toast.freshAt = GetTime()
end

local function FadeTo(alpha, duration)
	toast.alphaAnim = { from = toast:GetAlpha(), to = alpha, at = GetTime(), duration = duration }
end

-- The conversation going away as the notice fades out: its lines stay until
-- it's gone.
local function DropLeaving()
	if toast.leaving then
		DropLines(toast.leaving)
		toast.leaving = nil
	end
end

local function Show()
	if not toast:IsShown() then
		toast:SetAlpha(0)
		toast:Show()
		FadeTo(1, APPEAR)
	elseif toast.alphaAnim and toast.alphaAnim.to == 0 then
		FadeTo(1, APPEAR)
	end
	PlaceOpen()
end

local function SwitchTo(conv, animate)
	DropLeaving()
	if active and active ~= conv then
		DropLines(active)
	end
	active = conv
	RestartTime(conv)
	Render(animate)
end

function Finish(reason)
	local conv = active
	if not conv then
		return
	end
	if reason == "dismiss" or reason == "open" then
		for _, message in ipairs(conv.messages) do
			message.read = true
		end
	end
	for index, other in ipairs(convs) do
		if other == conv then
			table.remove(convs, index)
			break
		end
	end
	if convs[1] then
		DropLines(conv)
		active = nil
		SwitchTo(convs[1], true)
		return
	end
	-- The last one: the notice fades out with it.
	active = nil
	toast.leaving = conv
	if not InCombatLockdown() then
		toast.open:Hide()
	end
	toast.bodyLight:Hide()
	FadeTo(0, LEAVE)
end

-- Everything goes, unread: where whispers can't be shown (Restricted).
local function LeaveAll()
	DropLeaving()
	local conv = active
	convs = {}
	active = nil
	for id in pairs(byID) do
		byID[id] = nil
	end
	toast.leaving = conv
	if not InCombatLockdown() then
		toast.open:Hide()
	end
	toast.bodyLight:Hide()
	FadeTo(0, LEAVE)
end

local function Read(message)
	if message.read then
		return
	end
	message.read = true
end

-- The scroll bar, once there's more than fits: the chat's own (Scroll.lua),
-- a hairline that widens near the mouse.
local function PaintThumb(bar)
	local lit = bar.drag ~= nil or bar.thumb:IsMouseOver()
	if lit ~= bar.lit then
		bar.lit = lit
		bar.grip:SetColor((lit and Theme.THUMB_HOVER or Theme.THUMB):GetRGBA())
	end
end

local function UpdateBar(elapsed)
	local bar = toast.bar
	local max = MaxOffset()
	-- Only once there's more than the full view holds: not while the view
	-- is still growing to it.
	local shown = max > 0.5 and ContentHeight() > (toast.full or 0) + 0.5
	if shown ~= bar.shown then
		bar.shown = shown
		bar.track:SetShown(shown)
		if not shown then
			bar.drag = nil
		end
		Whispers.AnchorOpen()
	end
	if not shown then
		return
	end
	local trackHeight = bar.track:GetHeight()
	local content = ContentHeight()
	local view = toast.clip:GetHeight()
	local thumbHeight = math.max(THUMB_MIN, trackHeight * view / content)
	local room = trackHeight - thumbHeight
	if bar.drag and room > 0 then
		local _, y = GetCursorPosition()
		ScrollTo(bar.drag.offset + (y - bar.drag.y) / toast:GetEffectiveScale() * max / room)
	end
	local y = room * math.min(1, toast.offset / max)
	if thumbHeight ~= bar.thumbHeight or y ~= bar.thumbY then
		bar.thumbHeight, bar.thumbY = thumbHeight, y
		bar.thumb:SetHeight(thumbHeight)
		bar.thumb:SetPoint("BOTTOM", bar.track, "BOTTOM", 0, y)
	end
	PaintThumb(bar)
	local near = bar.drag or bar.track:IsMouseOver(0, 0, -8, 4)
	bar.away = near and 0 or (bar.away or 0) + elapsed
	local target = (near or bar.away < 0.25) and 1 or 0
	if bar.wideness ~= target then
		local step = elapsed / 0.12
		bar.wideness = target > bar.wideness and math.min(target, bar.wideness + step)
			or math.max(target, bar.wideness - step)
		bar.groove:SetWide(bar.wideness)
		bar.grip:SetWide(bar.wideness)
	end
end

-- Each frame while it shows: the view growing and the rise of a new line,
-- the wheel's scroll, the light of something new, what has been in view long
-- enough, and the time left (stopped under the mouse).
local function OnUpdate(_, elapsed)
	local now = GetTime()
	local fade = toast.alphaAnim
	if fade then
		local k = math.min(1, (now - fade.at) / fade.duration)
		-- Out slowly at first, in quickly at first.
		local eased = fade.to > fade.from and EaseOut(k) or k * k
		toast:SetAlpha(fade.from + (fade.to - fade.from) * eased)
		if k >= 1 then
			toast.alphaAnim = nil
			if fade.to == 0 then
				DropLeaving()
				toast:Hide()
				return
			end
		end
	end
	if not active then
		return
	end
	if Restricted() then
		LeaveAll()
		return
	end
	if toast.clipAnim then
		local k = math.min(1, (now - toast.clipAnim.at) / SLIDE)
		SetClipHeight(toast.clipAnim.from + (toast.clipAnim.to - toast.clipAnim.from) * EaseOut(k))
		if k >= 1 then
			toast.clipAnim = nil
		end
	end
	if toast.riseAnim then
		local k = math.min(1, (now - toast.riseAnim.at) / SLIDE)
		toast.rise = toast.riseAnim.from * (1 - EaseOut(k))
		SetContentY()
		if k >= 1 then
			toast.riseAnim = nil
		end
	end
	if toast.scroll then
		local k = math.min(1, (now - toast.scroll.at) / WHEEL)
		toast.offset = toast.scroll.from + (toast.scroll.to - toast.scroll.from) * EaseOut(k)
		SetContentY()
		if k >= 1 then
			toast.scroll = nil
		end
	end
	for _, message in ipairs(active.messages) do
		local line = message.line
		if line and message.enterAt then
			local k = math.min(1, math.max(0, (now - message.enterAt - 0.12) / FADE_IN))
			line:SetAlpha(k)
			if k >= 1 then
				message.enterAt = nil
			end
		end
	end
	local fresh = toast.freshAt and math.max(0, 1 - (now - toast.freshAt) / FRESH) or 0
	toast.rim:SetAlpha(RIM_ALPHA + (1 - RIM_ALPHA) * fresh)
	toast.light:SetAlpha(fresh)
	-- What shows now, read after a moment in view.
	local top, bottom = toast.clip:GetTop(), toast.clip:GetBottom()
	local changed, cut = false, false
	if top and bottom then
		for _, message in ipairs(active.messages) do
			local line = message.line
			local lineTop, lineBottom = line and line:GetTop(), line and line:GetBottom()
			if lineTop and lineBottom and lineTop > top + 0.5 and lineBottom < top - 0.5 then
				cut = true
			end
			if not message.read and line then
				if lineTop and lineBottom then
					if lineBottom < top - 3 and lineTop > bottom + 3 then
						message.seen = (message.seen or 0) + elapsed
						if message.seen >= READ_AFTER then
							Read(message)
							changed = true
						end
					end
				end
			end
		end
	end
	if changed then
		RenderChips()
	end
	UpdateBar(elapsed)
	-- Faded under the header only where a line is cut there.
	toast.fade:SetShown(cut)
	-- Open follows the body wherever it is now (a rect only known once laid
	-- out after showing, a scale change).
	Whispers.AnchorOpen()
	local hovered = toast:IsMouseOver()
	local closeAlpha = toast.close:GetAlpha()
	local closeTarget = hovered and 1 or CLOSE_REST
	if closeAlpha ~= closeTarget then
		local step = elapsed / CLOSE_FADE * (1 - CLOSE_REST)
		toast.close:SetAlpha(closeTarget > closeAlpha and math.min(closeTarget, closeAlpha + step)
			or math.max(closeTarget, closeAlpha - step))
	end
	-- Stopped under the mouse, and while the player is away: what came
	-- meanwhile waits for their return.
	if not hovered and not UnitIsAFK("player") then
		timeLeft = timeLeft - elapsed
		if timeLeft <= 0 then
			Finish("time")
			return
		end
	end
	toast.timer:SetWidth(math.max(0.01, (WIDTH - 2 * PAD) * timeLeft / timeTotal))
	-- Dim the countdown while it is paused.
	toast.timer:SetAlpha(hovered and TIMER_PAUSED or TIMER_ALPHA)
end

-- Moved by its header, as the chat by its own: locked with the chat (Shift
-- still moves it), a Shift-click locking or unlocking both.
local MOVE_THRESHOLD = 4

local function SavePosition()
	ns.db.whisperToastPos = { x = toast:GetLeft(), y = toast:GetBottom() }
	ns.Alerts.NotifySwitchChanged()
	Place()
end

-- What the header does, said after a moment over it (not over the tabs or
-- the close button, which have their own clicks), as the chat's header says
-- it: moved by dragging, locked with the chat.
local TIP_DELAY = 0.5

local function ShowGrabTip(grab)
	local lines
	if ns.Resize.IsLocked() then
		lines = {
			{ L.whisperLocked, HIGHLIGHT_FONT_COLOR, true },
			{ L.whisperShiftMove, GREEN_FONT_COLOR, true },
			{ L.whisperShiftUnlock, GREEN_FONT_COLOR, true },
		}
	else
		lines = { { L.whisperMoveHint, HIGHLIGHT_FONT_COLOR, true }, { L.whisperLockClick, GREEN_FONT_COLOR, true } }
	end
	ns.Links.ShowSmallTip(grab, "ANCHOR_TOP", lines)
	grab.tip = true
end

local function HideGrabTip(grab)
	if grab.tip then
		grab.tip = nil
		ns.Links.HideSmallTip(grab)
	end
end

local function CreateGrabber()
	local grab = CreateFrame("Frame", nil, toast)
	grab:SetPoint("TOPLEFT", toast, "TOPLEFT")
	grab:SetPoint("BOTTOMRIGHT", toast, "TOPRIGHT", 0, -HEADER)
	grab:EnableMouse(true)
	grab:SetFrameLevel(toast:GetFrameLevel() + 1)
	local downAt
	grab:SetScript("OnEnter", function()
		grab.hoverAt = GetTime()
	end)
	grab:SetScript("OnLeave", function()
		grab.hoverAt = nil
		HideGrabTip(grab)
	end)
	grab:SetScript("OnMouseDown", function(_, button)
		HideGrabTip(grab)
		grab.hoverAt = nil
		if button == "LeftButton" then
			downAt = { GetCursorPosition() }
		end
	end)
	grab:SetScript("OnUpdate", function()
		if grab.moving then
			Whispers.AnchorOpen()
			return
		end
		if grab.hoverAt and not grab.tip and GetTime() - grab.hoverAt >= TIP_DELAY then
			ShowGrabTip(grab)
		end
		if not downAt then
			return
		end
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		if math.abs(x - downAt[1]) / scale > MOVE_THRESHOLD or math.abs(y - downAt[2]) / scale > MOVE_THRESHOLD then
			if not ns.Resize.IsLocked() or IsShiftKeyDown() then
				grab.moving = true
				toast:StartMoving()
			end
		end
	end)
	grab:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then
			return
		end
		downAt = nil
		if grab.moving then
			grab.moving = nil
			toast:StopMovingOrSizing()
			SavePosition()
			Whispers.AnchorOpen()
		elseif IsShiftKeyDown() then
			ns.Resize.SetLocked(not ns.Resize.IsLocked(), true)
			grab.hoverAt = GetTime()
		end
	end)
	return grab
end

local function Build()
	toast = CreateFrame("Frame", "BaziEverchatWhisperToast", UIParent)
	toast:SetWidth(WIDTH)
	toast:SetFrameStrata("HIGH")
	toast:SetClampedToScreen(true)
	toast:SetMovable(true)
	toast:EnableMouse(true)
	toast:Hide()
	toast.spare = {}
	-- Measures a line's height in the lines' font (LineHeight).
	toast.measure = toast:CreateFontString(nil, "ARTWORK")
	toast.measure:SetFontObject(LineFont())
	toast.measure:SetText("Ág")
	toast.measure:Hide()
	toast.placed = {}
	toast.offset, toast.rise = 0, 0

	local fill = ns.Shapes.Fill(toast, "BACKGROUND", 0, Theme.CARD_RADIUS)
	fill:SetPoint("TOPLEFT", toast, "TOPLEFT")
	fill:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT")
	fill:SetColor(0.19, 0.105, 0.052, 0.98)
	ns.Skin.CreateShadow(toast, fill.box, fill.box)
	local header = toast:CreateTexture(nil, "BACKGROUND", nil, 1)
	header:SetPoint("TOPLEFT", 2, -2)
	header:SetPoint("TOPRIGHT", -2, -2)
	header:SetHeight(HEADER - 2)
	header:SetColorTexture(unpack(BaziUI.Theme.colors.purple))
	local light = toast:CreateTexture(nil, "BACKGROUND", nil, 2)
	light:SetColorTexture(1, 1, 1, 1)
	light:SetPoint("TOPLEFT", toast, "TOPLEFT", 2, -2)
	light:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -2, -2)
	light:SetHeight(HEADER + 6)
	ns.Shapes.SetGradient(light, "VERTICAL", CreateColor(1, 0.9, 0.6, 0), CreateColor(1, 0.9, 0.6, 0.1), 1)
	light:SetAlpha(0)
	toast.light = light
	local rim = ns.Shapes.Outline(toast, "BORDER", 0, Theme.CARD_RADIUS)
	rim:SetPoint("TOPLEFT", toast, "TOPLEFT")
	rim:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT")
	rim:SetColor(unpack(BaziUI.Theme.colors.gold))
	rim:SetAlpha(RIM_ALPHA)
	toast.rim = rim

	toast.grab = CreateGrabber()

	local name = toast:CreateFontString(nil, "ARTWORK")
	name:SetFontObject(ns.Fonts.ForSize(ns.Fonts.GetSize(DEFAULT_CHAT_FRAME) + 1))
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetPoint("TOPLEFT", toast, "TOPLEFT", PAD + 2, -7)
	toast.name = name

	toast.chips = {}
	for index = 1, CHIPS do
		-- As the chat's tabs not on show: a muted name, lit with a soft light
		-- under the mouse.
		local chip = CreateFrame("Button", nil, toast)
		chip:SetHeight(18)
		chip:SetFrameLevel(toast:GetFrameLevel() + 3)
		local back = ns.Shapes.Fill(chip, "BACKGROUND", 0, 4)
		back:SetPoint("TOPLEFT", chip, "TOPLEFT")
		back:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT")
		back:SetColor(1, 1, 1, CHIP_HOVER)
		back:SetAlpha(0)
		chip.back = back
		chip.label = chip:CreateFontString(nil, "ARTWORK")
		chip.label:SetFontObject(LineFont())
		chip.label:SetPoint("LEFT", chip, "LEFT", 7, 0)
		local dot = chip:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(MEDIA .. "Dot")
		local dotSize = PixelUtil.ConvertPixelsToUIForRegion(DOT_PIXELS, chip)
		dot:SetSize(dotSize, dotSize)
		dot:SetPoint("LEFT", chip.label, "RIGHT", DOT_GAP, 0)
		dot:Hide()
		chip.dot = dot
		chip.lit = 0
		local function Paint(self)
			local color = self.lit > 0.5 and Theme.TAB_TEXT_HOVER or Theme.TAB_TEXT
			self.label:SetTextColor(color.r, color.g, color.b)
			self.back:SetAlpha(self.lit)
		end
		local function Glide(self, elapsed)
			local target = self:IsMouseOver() and 1 or 0
			local step = elapsed / CHIP_FADE
			self.lit = target > self.lit and math.min(1, self.lit + step) or math.max(0, self.lit - step)
			Paint(self)
			if self.lit == target then
				self:SetScript("OnUpdate", nil)
			end
		end
		chip:SetScript("OnEnter", function(self)
			self:SetScript("OnUpdate", Glide)
		end)
		chip:SetScript("OnLeave", function(self)
			self:SetScript("OnUpdate", Glide)
		end)
		Paint(chip)
		Theme.OnChanged(function()
			Paint(chip)
		end)
		chip:SetScript("OnClick", function(self)
			if self.conv then
				SwitchTo(self.conv, true)
			end
		end)
		chip:Hide()
		toast.chips[index] = chip
	end

	local close = CreateFrame("Button", nil, toast, "UIPanelCloseButtonNoScripts")
	close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
	close:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -(HEADER - CLOSE_SIZE) / 2, -(HEADER - CLOSE_SIZE) / 2)
	close:SetAlpha(CLOSE_REST)
	close:SetFrameLevel(toast:GetFrameLevel() + 4)
	close:SetScript("OnClick", function()
		Finish("dismiss")
	end)
	close:SetScript("OnEnter", function(self)
		ns.Links.ShowSmallTip(self, "ANCHOR_TOP", { { L.whisperDismissTip, HIGHLIGHT_FONT_COLOR } })
	end)
	close:SetScript("OnLeave", function(self)
		ns.Links.HideSmallTip(self)
	end)
	toast.close = close


	local clip = CreateFrame("Frame", nil, toast)
	clip:SetClipsChildren(true)
	clip:SetPoint("TOPLEFT", toast, "TOPLEFT", PAD + 2, -HEADER - TOP_GAP)
	clip:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -BAR_COLUMN, -HEADER - TOP_GAP)
	clip:SetHeight(LineHeight() - LINE_GAP)
	clip:EnableMouseWheel(true)
	clip:SetScript("OnMouseWheel", function(_, delta)
		ScrollTo((toast.scroll and toast.scroll.to or toast.offset) + delta * LineHeight(), true)
	end)
	toast.clip = clip
	local content = CreateFrame("Frame", nil, clip)
	content:SetHeight(1)
	toast.content = content
	SetContentY()
	-- Older lines fade out under the header while there are more above.
	local fade = toast:CreateTexture(nil, "ARTWORK", nil, 5)
	fade:SetColorTexture(1, 1, 1, 1)
	fade:SetPoint("TOPLEFT", clip, "TOPLEFT", -2, 0)
	fade:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 2, 0)
	fade:SetHeight(9)
	local body = Theme.BODY
	ns.Shapes.SetGradient(fade, "VERTICAL", CreateColor(body.r, body.g, body.b, 0), CreateColor(body.r, body.g, body.b, 0.95), 1)
	fade:Hide()
	toast.fade = fade
	local function Wheel(_, delta)
		ScrollTo((toast.scroll and toast.scroll.to or toast.offset) + delta * LineHeight(), true)
	end
	local bar = { wideness = 0 }
	local track = CreateFrame("Frame", nil, toast)
	track:SetWidth(BAR_WIDTH)
	track:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -3, -HEADER - TOP_GAP)
	track:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -3, FOOTER)
	track:SetFrameLevel(toast:GetFrameLevel() + 3)
	track:EnableMouse(true)
	track:EnableMouseWheel(true)
	track:SetScript("OnMouseWheel", Wheel)
	-- A click on the groove goes a view up or down, towards the click.
	track:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then
			return
		end
		local _, y = GetCursorPosition()
		local above = y / toast:GetEffectiveScale() > (bar.thumb:GetTop() or 0)
		local view = toast.clip:GetHeight()
		ScrollTo((toast.scroll and toast.scroll.to or toast.offset) + (above and view or -view), true)
	end)
	track:Hide()
	bar.track = track
	bar.groove = ns.Scroll.CreateBar(track, "BACKGROUND", "groove")
	bar.groove:SetColor(0, 0, 0, 0.45)
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetPoint("LEFT", track, "LEFT")
	thumb:SetPoint("RIGHT", track, "RIGHT")
	thumb:SetPoint("BOTTOM", track, "BOTTOM")
	thumb:SetHeight(8)
	thumb:EnableMouse(true)
	thumb:EnableMouseWheel(true)
	thumb:SetScript("OnMouseWheel", Wheel)
	thumb:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			local _, y = GetCursorPosition()
			toast.scroll = nil
			bar.drag = { y = y, offset = toast.offset }
		end
	end)
	thumb:SetScript("OnMouseUp", function()
		bar.drag = nil
	end)
	bar.thumb = thumb
	bar.grip = ns.Scroll.CreateBar(thumb, "OVERLAY", "thumb")
	Theme.OnChanged(function()
		bar.lit = nil
	end)
	toast.bar = bar

	-- The body lit under the mouse: it opens the conversation.
	local bodyLight = toast:CreateTexture(nil, "BACKGROUND", nil, 3)
	bodyLight:SetColorTexture(1, 1, 1, BODY_HOVER_ALPHA)
	bodyLight:SetPoint("TOPLEFT", toast, "TOPLEFT", 2, -HEADER)
	bodyLight:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -2, 2)
	bodyLight:Hide()
	toast.bodyLight = bodyLight

	local timer = toast:CreateTexture(nil, "ARTWORK")
	timer:SetColorTexture(unpack(BaziUI.Theme.colors.gold))
	timer:SetHeight(2)
	timer:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", PAD, 6)
	toast.timer = timer

	local open = CreateFrame("Button", "BaziEverchatWhisperOpen", UIParent, "SecureActionButtonTemplate")
	-- On release only: closing the notice as the button goes down would hide
	-- it before the release that clicks the tab.
	open:RegisterForClicks("AnyUp")
	-- A secure button acts on the press when the game's "cast on key down"
	-- is on (its default), and this one hears only the release.
	open:SetAttribute("useOnKeyDown", false)
	open:SetAttribute("type", "click")
	open:HookScript("PostClick", function()
		Finish("open")
	end)
	open:EnableMouseWheel(true)
	open:SetScript("OnMouseWheel", function(_, delta)
		ScrollTo((toast.scroll and toast.scroll.to or toast.offset) + delta * LineHeight(), true)
	end)
	open:SetScript("OnEnter", function(self)
		-- The person's window may have opened or closed since.
		if active and not InCombatLockdown() then
			self:SetAttribute("clickbutton", TabFor(active))
		end
		toast.bodyLight:Show()
		ns.Links.ShowSmallTip(self, "ANCHOR_BOTTOM", { { L.whisperOpenHint, GREEN_FONT_COLOR } })
	end)
	open:SetScript("OnLeave", function(self)
		toast.bodyLight:Hide()
		ns.Links.HideSmallTip(self)
	end)
	open:Hide()
	toast.open = open

	SetClipHeight(LineHeight() - LINE_GAP)
	toast:SetScript("OnUpdate", ns.Guard("Whispers.Update", OnUpdate))
	toast:SetScript("OnHide", function()
		if not InCombatLockdown() then
			toast.open:Hide()
		end
		toast.bodyLight:Hide()
		HideGrabTip(toast.grab)
	end)
	Place()
end

-- Open, on the conversation's tab: set up out of combat only.
function PlaceOpen()
	if not toast or InCombatLockdown() then
		return
	end
	local open = toast.open
	local tab = active and toast:IsShown() and TabFor(active)
	if not tab then
		open:Hide()
		return
	end
	open:SetAttribute("clickbutton", tab)
	open:SetFrameStrata(toast:GetFrameStrata())
	open:SetFrameLevel(toast:GetFrameLevel() + 2)
	Whispers.AnchorOpen()
	open:Show()
end

-- A whisper comes in: into its conversation, and into view if it's the
-- one shown or nothing is.
local function Receive(conv, message)
	table.insert(conv.messages, message)
	if message.id then
		byID[message.id] = message
	end
	if not active then
		SwitchTo(conv, toast:IsShown())
		Show()
		Freshen()
		return
	end
	if conv ~= active then
		RenderChips()
		return
	end
	RestartTime(conv)
	Freshen()
	local line = NewLine(message)
	LayoutLines()
	local height = line:GetStringHeight() + LINE_GAP
	if toast.offset > 0 then
		-- Reading further up: what shows stays put.
		ScrollTo(toast.offset + height)
		return
	end
	-- The view grows to its three lines, and the conversation rises by the
	-- new line's height, slowly.
	local target = ClipHeight()
	local current = toast.clip:GetHeight()
	if math.abs(target - current) > 0.5 then
		toast.clipAnim = { from = current, to = target, at = GetTime() }
	end
	toast.riseAnim = { from = -height + toast.rise, at = GetTime() }
	toast.rise = -height
	SetContentY()
	line:SetAlpha(0)
	message.enterAt = GetTime()
end

local function ConversationFor(key, name, short, color, event, target)
	for _, conv in ipairs(convs) do
		if conv.key == key then
			return conv
		end
	end
	local conv = { key = key, name = name, short = short, color = color, event = event, target = target, messages = {} }
	table.insert(convs, conv)
	return conv
end

-- Who it's from: a player's name in their class color, a Battle.net friend's
-- in the Battle.net whisper color.
local function Sender(event, sender, guid)
	if event == "CHAT_MSG_BN_WHISPER" then
		local info = ChatTypeInfo.BN_WHISPER
		return sender, sender, CreateColor(info.r, info.g, info.b), sender
	end
	local name = Ambiguate(sender, "none")
	local color = ChatTypeInfo.WHISPER
	local class = guid and select(2, GetPlayerInfoByGUID(guid))
	if class and C_ClassColor then
		color = C_ClassColor.GetClassColor(class) or color
	end
	local short = name:match("^(%S+)") or name
	return name, short, CreateColor(color.r, color.g, color.b), sender
end

-- A message as the chat shows it: links named in the client's language,
-- icons before them, the player's name in gold. A link's name the client
-- hasn't loaded comes later, and the line is written again.
local function Compose(message, refresh)
	local text = ns.Names.Localize(message.raw, message, refresh or Whispers.RefreshMessage)
	text = ns.Channels.AddIcons(text, "CHAT_MSG_WHISPER", DEFAULT_CHAT_FRAME)
	return ns.Alerts.HighlightMentions(text, "CHAT_MSG_WHISPER", false)
end

function Message(raw, clock, id)
	local message = { raw = raw, clock = clock, id = id, read = false, seen = 0 }
	message.text = Compose(message)
	return message
end

function Whispers.RefreshMessage(message)
	message.text = Compose(message)
	local line = message.line
	if not (line and active) then
		return
	end
	line:SetText(ns.Timestamps.GreyCode() .. message.clock .. "|r " .. message.text)
	LayoutLines()
	if not toast.clipAnim then
		SetClipHeight(ClipHeight())
	end
	ScrollTo(toast.offset)
end

local function OnWhisper(event, args)
	if Restricted() then
		return
	end
	local message, sender = args[1], args[2]
	if not Readable(sender) or sender == "" then
		return
	end
	local guid = args[12]
	if not Readable(guid) or guid == "" then
		guid = nil
	end
	local id = args[11]
	if not Readable(id) or id == 0 then
		id = nil
	end
	-- Not while the player is looking at it in the chat.
	if ns.Alerts.SeenInUse(event, args) then
		return
	end
	if not Readable(message) then
		return
	end
	if not toast then
		Build()
	end
	local name, short, color, target = Sender(event, sender, guid)
	local key = (event == "CHAT_MSG_BN_WHISPER" and "bn:" or "") .. (args[13] and Readable(args[13]) and tostring(args[13]) or sender)
	local conv = ConversationFor(key, name, short, color, event, target)
	Receive(conv, Message(message, ns.Timestamps.FormatClock(time()), id))
end

-- Read in the chat: read here too; a conversation read through goes.
local function OnSeen(id)
	local message = byID[id]
	if not message then
		return
	end
	byID[id] = nil
	message.read = true
	for _, conv in ipairs(convs) do
		if Unread(conv) == 0 and conv ~= active then
			for index, other in ipairs(convs) do
				if other == conv then
					table.remove(convs, index)
					break
				end
			end
			break
		end
	end
	if toast and toast:IsShown() then
		RenderChips()
	end
end

-- Someone the player knows, for the examples: a friend or a guildmate,
-- those online first, else the player; with their class color.
local function SamplePerson()
	local found = {}
	local function Add(name, classFile, online)
		if type(name) == "string" and Readable(name) and name ~= "" then
			table.insert(found, { name = Ambiguate(name, "none"), class = classFile, online = online and true or false })
		end
	end
	if C_FriendList and C_FriendList.GetNumFriends then
		for index = 1, C_FriendList.GetNumFriends() or 0 do
			local info = C_FriendList.GetFriendInfoByIndex(index)
			local guid = info and info.guid
			local class = guid and Readable(guid) and select(2, GetPlayerInfoByGUID(guid))
			Add(info and info.name, class, info and info.connected)
		end
	end
	if IsInGuild() then
		local me = UnitGUID("player")
		for index = 1, GetNumGuildMembers() or 0 do
			local name, _, _, _, _, _, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(index)
			if guid ~= me then
				Add(name, class, online)
			end
		end
	end
	local person = found[1]
	for _, candidate in ipairs(found) do
		if candidate.online then
			person = candidate
			break
		end
	end
	if not person then
		person = { name = ns.PlayerName(), class = select(2, UnitClass("player")) }
	end
	local color = person.class and C_ClassColor.GetClassColor(person.class) or ChatTypeInfo.WHISPER
	return person.name, person.name:match("^(%S+)") or person.name, CreateColor(color.r, color.g, color.b)
end

-- An example for the options (where it stands, how it looks): two lines
-- from the player and one from someone else.
function Whispers.Preview()
	if not toast then
		Build()
	end
	local sample = L.whisperSample
	local me = ns.PlayerName()
	local _, class = UnitClass("player")
	local color = C_ClassColor.GetClassColor(class) or ChatTypeInfo.WHISPER
	local conv = ConversationFor("preview", me, me:match("^(%S+)") or me, CreateColor(color.r, color.g, color.b),
		"CHAT_MSG_WHISPER", nil)
	local otherName, otherShort, otherColor = SamplePerson()
	local other = ConversationFor("preview2", otherName, otherShort, otherColor,
		"CHAT_MSG_WHISPER", nil)
	local clock = ns.Timestamps.FormatClock(time())
	Receive(conv, Message(sample[1], clock))
	C_Timer.After(0.8, function()
		Receive(conv, Message(sample[2], clock))
	end)
	-- With a link of the player's own, as a whisper's links show here.
	local link = ns.Bubbles.SampleLink()
	Receive(other, Message(link and (sample[3] .. " " .. link) or sample[3], clock))
end

-- The notice as an example on the options page: one message from someone
-- else, drawn as the notice draws it, its time line running down at the
-- chosen length and starting over, stopped under the mouse. Greyed while
-- the notices are off.
local SAMPLE_REST = 0.8
local SAMPLE_OFF_ALPHA = 0.35

function Whispers.CreateSample(parent)
	local card = CreateFrame("Frame", nil, parent)
	card:SetWidth(WIDTH)
	local fill = ns.Shapes.Fill(card, "BACKGROUND", 0, Theme.CARD_RADIUS)
	fill:SetPoint("TOPLEFT", card, "TOPLEFT")
	fill:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT")
	fill:SetColor(Theme.BODY.r, Theme.BODY.g, Theme.BODY.b, 0.95)
	local rim = ns.Shapes.Outline(card, "BORDER", 0, Theme.CARD_RADIUS)
	rim:SetPoint("TOPLEFT", card, "TOPLEFT")
	rim:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT")
	local function PaintRim()
		rim:SetColor(Theme.RIM_TOP.r, Theme.RIM_TOP.g, Theme.RIM_TOP.b, 1)
	end
	PaintRim()
	Theme.OnChanged(PaintRim)
	rim:SetAlpha(RIM_ALPHA)

	local name = card:CreateFontString(nil, "ARTWORK")
	name:SetFontObject(ns.Fonts.ForSize(ns.Fonts.GetSize(DEFAULT_CHAT_FRAME) + 1))
	name:SetJustifyH("LEFT")
	name:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + 2, -7)

	local close = CreateFrame("Button", nil, card, "UIPanelCloseButtonNoScripts")
	close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
	close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(HEADER - CLOSE_SIZE) / 2, -(HEADER - CLOSE_SIZE) / 2)
	close:EnableMouse(false)
	close:SetAlpha(CLOSE_REST)

	local line = card:CreateFontString(nil, "ARTWORK")
	line:SetFontObject(LineFont())
	line:SetJustifyH("LEFT")
	line:SetWordWrap(true)
	line:SetSpacing(LINE_GAP)
	line:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + 2, -HEADER - TOP_GAP)
	line:SetPoint("RIGHT", card, "RIGHT", -BAR_COLUMN, 0)

	local timer = card:CreateTexture(nil, "ARTWORK")
	timer:SetColorTexture(1, 1, 1, 1)
	timer:SetHeight(1)
	timer:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", PAD, 6)

	local message = { clock = ns.Timestamps.FormatClock(time()), read = false }
	local total, left, wait = 1, 1, 0
	local enabled = true

	local function Layout()
		local who, _, color = SamplePerson()
		name:SetText(who)
		name:SetTextColor(color.r, color.g, color.b)
		local link = ns.Bubbles.SampleLink()
		message.raw = link and (L.whisperSample[3] .. " " .. link) or L.whisperSample[3]
		message.text = Compose(message, Layout)
		name:SetFontObject(ns.Fonts.ForSize(ns.Fonts.GetSize(DEFAULT_CHAT_FRAME) + 1))
		line:SetFontObject(LineFont())
		line:SetTextColor(ChatTypeInfo.WHISPER.r, ChatTypeInfo.WHISPER.g, ChatTypeInfo.WHISPER.b)
		line:SetText(ns.Timestamps.GreyCode() .. message.clock .. "|r " .. message.text)
		card:SetHeight(HEADER + TOP_GAP + line:GetStringHeight() + FOOTER)
		total = Duration({ messages = { message } })
		left = total
		wait = 0
	end

	-- Off: everything greyed and still.
	function card.Refresh()
		enabled = ns.db.whisperToasts and true or false
		Layout()
		card:SetAlpha(enabled and 1 or SAMPLE_OFF_ALPHA)
		close:SetAlpha(CLOSE_REST)
	end

	card:SetScript("OnUpdate", function(_, elapsed)
		local hovered = enabled and card:IsMouseOver()
		local alpha = close:GetAlpha()
		local target = hovered and 1 or CLOSE_REST
		if alpha ~= target then
			local step = elapsed / CLOSE_FADE * (1 - CLOSE_REST)
			close:SetAlpha(target > alpha and math.min(target, alpha + step) or math.max(target, alpha - step))
		end
		if enabled and not hovered then
			if left > 0 then
				left = math.max(0, left - elapsed)
			else
				wait = wait + elapsed
				if wait >= SAMPLE_REST then
					left, wait = total, 0
				end
			end
		end
		local color = Theme.LINE
		timer:SetColorTexture(color.r, color.g, color.b, (hovered or not enabled) and TIMER_PAUSED or TIMER_ALPHA)
		timer:SetWidth(math.max(0.01, (WIDTH - 2 * PAD) * left / total))
		timer:SetShown(left > 0)
	end)
	card.Refresh()
	return card
end

-- Whether the notice was moved from its place over the chat.
function Whispers.IsMoved()
	return ns.db.whisperToastPos ~= nil
end

function Whispers.SetEnabled(enabled)
	ns.db.whisperToasts = enabled and true or false
	if not enabled and toast then
		DropLeaving()
		if active then
			DropLines(active)
		end
		convs, active = {}, nil
		toast.alphaAnim = nil
		toast:Hide()
	end
	ns.Alerts.NotifySwitchChanged()
end

function Whispers.Init()
	local events = CreateFrame("Frame")
	for event in pairs(EVENTS) do
		events:RegisterEvent(event)
	end
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- A person's window opening or closing changes where Open leads.
	local function Replace()
		C_Timer.After(0, PlaceOpen)
	end
	hooksecurefunc("FCF_OpenTemporaryWindow", Replace)
	hooksecurefunc("FCF_Close", Replace)
	-- After the chat windows have the whisper (they took the event first):
	-- whether one in use shows it is known then.
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "PLAYER_REGEN_DISABLED" then
			-- The last moment the secure button can be put away.
			if toast then
				toast.open:Hide()
				toast.open:ClearAllPoints()
				toast.placed = {}
				toast.bodyLight:Hide()
			end
			return
		end
		if event == "PLAYER_REGEN_ENABLED" then
			PlaceOpen()
			return
		end
		if not ns.db.whisperToasts then
			return
		end
		local args = { ... }
		C_Timer.After(0, function()
			OnWhisper(event, args)
		end)
	end)
	ns.Alerts.OnSeen(OnSeen)
end
