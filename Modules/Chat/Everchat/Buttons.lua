local ns = BaziUI.Chat
local Theme = ns.Theme

local Buttons = {}
ns.Buttons = Buttons

-- The chat's own buttons (the social button at the top; the chat menu with
-- the channels button and, in a voice channel, the deafen and mute buttons
-- above it at the bottom) stand on a rail of their own beside the card, on the
-- side Blizzard puts its button column: a narrow strip in the header's color
-- with the card's corners, shadow and hairline, as tall as the card.
--
-- Their art keeps the game's gold in the Gold theme; in the others it's
-- turned grey and tinted with the theme's metal (Theme.PaintArt), squares
-- included, since the social button and the chat menu are one picture each,
-- square and icon. What says something by its color keeps it: the voice
-- buttons' muted states (their red slash) and the social button's quick
-- join picture (a group to join), which the game fades in over the friends
-- one, its alpha left to the game.
--
-- Every button is drawn at a whole multiple of its art's size in screen
-- pixels (32 for the social button and the chat menu's texture, 27x26 for the
-- channel and voice buttons), the multiple nearest to their usual size (1x at
-- 1440p with a 0.64 interface scale, 2x at 4K), and placed on whole pixels:
-- at their 32-unit size they were scaled by 1.2 there and looked soft. Only
-- sizes and anchors change: their parents, scripts, art and visibility stay
-- Blizzard's (the chat menu and channels button hide with General's button
-- frame while another tab is shown, as in the default UI).

-- In screen pixels at 1x. The buttons' visible squares are about 22.5px (the
-- rest of their art is transparent): a 32px rail, the social button's art,
-- leaves about 5px around each, as above and below (40px left 8.75 at the
-- sides against 5 at the top).
local RAIL_WIDTH = 32
local RAIL_GAP = 4
local SOCIAL_SIZE = 32
-- The chat menu's 32x32 texture wraps a 27x26 square, 3px in from top and bottom.
local MENU_SIZE = 32
local MENU_ART_PADDING = 3
local SQUARE_WIDTH, SQUARE_HEIGHT = 27, 26
local VOICE_ICON = 15
-- Space between the squares, and between the rail's edge and its buttons.
local GAP = 3
local EDGE = 6
local TOP_EDGE = 4

local rail, railFill, railShadow
-- Whether the rail's panel shows (Theme.RAIL_PANEL), once painted.
local railPanel
-- The side bar's alpha with its buttons, the game's among them.
local railAlpha = 1
local GAME_BUTTONS = {
	"QuickJoinToastButton", "ChatFrameMenuButton", "ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
}

-- Everchat's own buttons, each one optional (the options' "Side buttons"):
-- at the top, under the social button, what you do with the chat and with
-- people (search it, copy the chat on show, clear it, roll 1-100); at the bottom, right
-- above Blizzard's chat menu, Everchat's options, settings at the foot of the
-- rail as in most apps' sidebars. Blizzard's square (the channel button's art) with an
-- icon of our own: 16px white glyphs (Media/Icon*.tga, drawn by
-- art/rail-icons.py) tinted gold like Blizzard's chat button icons. They act
-- on the docked window on show. Opening the game's own panels (guild, group
-- finder, friends) was left out: calling them from addon code risks taint.
local ICON_SIZE = 16
local MEDIA = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\"
local railButtons = {}
-- The options' pictures of the rail's buttons, painted like them.
local pictures = {}

local function ShownWindow()
	return FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or DEFAULT_CHAT_FRAME
end

local RAIL_BUTTONS = {
	{
		key = "railSearch", icon = "IconSearch", label = "railSearch", tip = "railSearchTip",
		run = function()
			ns.Search.Toggle(ShownWindow())
		end,
	},
	{
		key = "railCopy", icon = "IconCopy", label = "copyChat", tip = "railCopyTip",
		opens = true,
		run = function()
			ns.Links.ShowChat(ShownWindow())
		end,
	},
	{
		key = "railClear", icon = "IconClear", label = "railClear", tip = "railClearTip",
		run = function()
			local chatFrame = ShownWindow()
			-- A public ScrollingMessageFrame method (a secure barrier).
			chatFrame:Clear()
			ns.History.ClearWindow(chatFrame)
		end,
	},
	{
		key = "railRoll", icon = "IconRoll", label = "railRoll", tip = "railRollTip",
		run = function()
			RandomRoll(1, 100)
		end,
	},
	{
		key = "railOptions", icon = "IconOptions", label = "railOptions", tip = "railOptionsTip",
		opens = true,
		bottom = true,
		run = function()
			ns.Options.Toggle()
		end,
	},
	-- Mutes or brings back Everchat's audio alerts (2026-10-12, the user's
	-- idea): a bell, struck through with the game's red slash while they're
	-- muted (a gold slash was easy to miss); above the options gear, by the
	-- game's own audio switches (its voice buttons). On by default.
	{
		key = "railMute", icon = "IconBell", label = "railMute", tip = "railMuteTip",
		bottom = true,
		run = function()
			ns.Alerts.SetMuted(not ns.Alerts.IsMuted())
		end,
		-- Ticked in the "more" menu while the alerts sound.
		checked = function()
			return not ns.Alerts.IsMuted()
		end,
		-- The glyph, the tooltip's lines and whether the slash shows.
		state = function()
			local muted = ns.Alerts.IsMuted()
			return muted and "IconBellMuted" or "IconBell", {
				{ ns.L.railMute, HIGHLIGHT_FONT_COLOR },
				{ muted and ns.L.soundAlertsMuted or ns.L.soundAlertsOn, NORMAL_FONT_COLOR },
				{ muted and ns.L.clickUnmute or ns.L.clickMute, GREEN_FONT_COLOR },
			}, muted
		end,
	},
	-- The whisper notices (Whispers.lua) on or off: a speech bubble, struck
	-- through with the same red slash while they're off; above the bell.
	{
		key = "railWhispers", icon = "IconWhisper", label = "optionWhisperToasts", tip = "railWhispersTip",
		bottom = true,
		run = function()
			ns.Whispers.SetEnabled(not ns.db.whisperToasts)
		end,
		checked = function()
			return ns.db.whisperToasts
		end,
		state = function()
			local L, on = ns.L, ns.db.whisperToasts
			return on and "IconWhisper" or "IconWhisperOff", {
				{ L.optionWhisperToasts, HIGHLIGHT_FONT_COLOR },
				{ on and L.whisperToastsOn or L.whisperToastsOff, NORMAL_FONT_COLOR },
				{ on and L.clickWhispersOff or L.clickWhispersOn, GREEN_FONT_COLOR },
			}, not on
		end,
	},
	-- The chat at rest (the options' "Chat when idle", Skin.lua), each click the
	-- next of its three states: an eye half closed while the chat fades, open
	-- while it stays in sight, struck through with the same red slash while it
	-- hides; above the bell, with the other switch.
	{
		key = "railHide", icon = "IconEyeRest", label = "optionRest", tip = "railHideTip",
		bottom = true,
		run = function()
			ns.Skin.SetRestMode(ns.Skin.NextRest(ns.db.chatRest))
		end,
		choices = function()
			return ns.Skin.RestChoices()
		end,
		current = function()
			return ns.db.chatRest
		end,
		pick = function(mode)
			ns.Skin.SetRestMode(mode)
		end,
		state = function()
			local L, mode = ns.L, ns.db.chatRest
			local icon, name, click = "IconEyeRest", L.restFaded, L.clickHideChat
			if mode == "hidden" then
				icon, name, click = "IconEyeHidden", L.restHidden, L.clickShowChat
			elseif mode == "always" then
				icon, name, click = "IconEye", L.restAlways, L.clickFadeChat
			end
			return icon, {
				{ L.optionRest, HIGHLIGHT_FONT_COLOR },
				{ name, NORMAL_FONT_COLOR },
				{ click, GREEN_FONT_COLOR },
			}, mode == "hidden"
		end,
	},
}

-- The rail's own buttons, in the rail's order (Options.lua lists them).
Buttons.RAIL_BUTTONS = RAIL_BUTTONS

-- With the chat too short for every button (the rail's top and bottom stacks
-- would meet), the squares first close up (GAPS), then Everchat's buttons
-- fold, the least used first (FOLD_ORDER), into a "more" button at the end of
-- the top stack, whose menu holds them: the overflow of VS Code's activity
-- bar, Windows' tray or Chrome's extensions. The game's own buttons and
-- Everchat's options never fold.
local GAPS = { GAP, 2, 1 }
local FOLD_ORDER = { "railRoll", "railClear", "railHide", "railWhispers", "railCopy", "railMute", "railSearch" }
local folded, railGap = {}, GAP
local moreButton, moreMenu
-- The menu's icons, beside each name as the game's menus put theirs.
local MENU_ICON = 16

-- How the rail fits: the gap and the buttons folded, for `room` (the rail's
-- height in its art's pixels; 0 while it isn't laid out yet), the game's
-- squares at the bottom (nil while General's button frame is hidden, when
-- Everchat's take the menu's place), the shown buttons (keys to true) and
-- what shows under the social button (`topExtra`, art pixels).
function Buttons.Fit(room, gameSquares, shown, topExtra)
	local function Fits(gap, fold)
		local top = TOP_EDGE + SOCIAL_SIZE + (topExtra or 0) + gap - 2
		local bottom = EDGE
		if gameSquares then
			bottom = EDGE - MENU_ART_PADDING + MENU_SIZE - MENU_ART_PADDING + gap + gameSquares * (SQUARE_HEIGHT + gap)
		end
		local any = false
		for _, spec in ipairs(RAIL_BUTTONS) do
			if shown[spec.key] then
				if fold[spec.key] then
					any = true
				elseif spec.bottom then
					bottom = bottom + SQUARE_HEIGHT + gap
				else
					top = top + SQUARE_HEIGHT + gap
				end
			end
		end
		if any then
			top = top + SQUARE_HEIGHT + gap
		end
		return top + bottom <= room + gap
	end
	local none = {}
	if not room or room <= 0 then
		return GAP, none
	end
	for _, gap in ipairs(GAPS) do
		if Fits(gap, none) then
			return gap, none
		end
	end
	local gap, fold = GAPS[#GAPS], {}
	for _, key in ipairs(FOLD_ORDER) do
		if shown[key] then
			fold[key] = true
			if Fits(gap, fold) then
				break
			end
		end
	end
	return gap, fold
end

local function CreateRailButton(spec)
	local button = CreateFrame("Button", nil, rail)
	button:SetFrameStrata("MEDIUM")
	button:SetNormalAtlas("chatframe-button-up")
	button:SetPushedAtlas("chatframe-button-down")
	button:SetHighlightAtlas("chatframe-button-highlight", "ADD")
	local icon = button:CreateTexture(nil, "OVERLAY")
	-- Nearest filtering keeps the glyph crisp at 2x.
	icon:SetTexture(MEDIA .. spec.icon, nil, nil, "NEAREST")
	icon:SetVertexColor(Theme.RAIL_ICON:GetRGB())
	button.icon = icon
	-- A switch's slash, over its glyph cut to make room for it.
	if spec.state then
		local slash = button:CreateTexture(nil, "OVERLAY", nil, 1)
		slash:SetTexture(MEDIA .. "IconSlash", nil, nil, "NEAREST")
		slash:SetVertexColor(Theme.SLASH:GetRGB())
		slash:SetAllPoints(icon)
		slash:Hide()
		button.slash = slash
	end
	-- The sound of the game's own buttons on this rail (its channels button);
	-- a button that opens a window lets the window's opening sound instead.
	button:SetScript("OnClick", function(self)
		if not spec.opens then
			Theme.PlaySound("rail")
		end
		spec.run()
		-- A switch shows its new state at once, tooltip included.
		if spec.state and self:IsMouseOver() then
			self:GetScript("OnEnter")(self)
		end
	end)
	button:SetScript("OnMouseDown", function(self)
		self.icon:SetAlpha(0.75)
		if self.slash then
			self.slash:SetAlpha(0.75)
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		self.icon:SetAlpha(1)
		if self.slash then
			self.slash:SetAlpha(1)
		end
	end)
	-- In Everchat's small tooltip, like its other hints; a switch's says its
	-- state and what a click does.
	button:SetScript("OnEnter", function(self)
		local lines = {
			{ ns.L[spec.label], HIGHLIGHT_FONT_COLOR },
			{ ns.L[spec.tip], NORMAL_FONT_COLOR, true },
		}
		if spec.state then
			lines = select(2, spec.state())
		end
		ns.Links.ShowSmallTip(self, rail:GetLeft() < UIParent:GetWidth() / 2 and "ANCHOR_RIGHT" or "ANCHOR_LEFT", lines)
	end)
	button:SetScript("OnLeave", function(self)
		ns.Links.HideSmallTip(self)
	end)
	railButtons[spec.key] = button
end

-- The folded buttons' menu, beside the "more" button, in the game's own menus'
-- look: each one's name with its gold glyph at the right, where the game's
-- menus put their icons (its raid marks), and the switches as its
-- checkboxes; actions first, the switches under a divider. Each keeps its
-- tooltip.
local MENU_ICON_GAP = 10

local function AddMenuEntry(rootDescription, spec)
	local entry
	if spec.checked then
		entry = rootDescription:CreateCheckbox(ns.L[spec.label], spec.checked, spec.run)
	else
		entry = rootDescription:CreateButton(ns.L[spec.label], spec.run)
	end
	entry:AddInitializer(function(frame)
		local icon = frame:AttachTexture()
		icon:SetSize(MENU_ICON, MENU_ICON)
		icon:SetPoint("RIGHT")
		icon:SetTexture(MEDIA .. spec.icon, nil, nil, "NEAREST")
		icon:SetVertexColor(Theme.RAIL_ICON:GetRGB())
		local left = frame.leftTexture1 and frame.leftTexture1:GetWidth() + 7 or 0
		return left + frame.fontString:GetUnboundedStringWidth() + MENU_ICON_GAP + MENU_ICON, 20
	end)
	entry:SetOnEnter(function(frame)
		local lines = { { ns.L[spec.tip], NORMAL_FONT_COLOR, true } }
		if spec.state then
			lines = select(2, spec.state())
		end
		ns.Links.ShowSmallTip(frame, "ANCHOR_RIGHT", lines)
	end)
	entry:SetOnLeave(function(frame)
		ns.Links.HideSmallTip(frame)
	end)
end

-- A switch of several states (the eye): its name as a title, each state to
-- pick by its name, each with its own tooltip.
local function AddMenuChoices(rootDescription, spec)
	rootDescription:CreateTitle(ns.L[spec.label])
	for _, choice in ipairs(spec.choices()) do
		local value, name, tip = choice[1], choice[2], choice[3]
		local entry = rootDescription:CreateRadio(name, function()
			return spec.current() == value
		end, function()
			spec.pick(value)
		end)
		entry:SetOnEnter(function(frame)
			ns.Links.ShowSmallTip(frame, "ANCHOR_RIGHT", { { tip, NORMAL_FONT_COLOR, true } })
		end)
		entry:SetOnLeave(function(frame)
			ns.Links.HideSmallTip(frame)
		end)
	end
end

local function OpenMore(button)
	if moreMenu and moreMenu:IsShown() then
		Menu.GetManager():CloseMenus()
		Theme.PlaySound("uncheck")
		return
	end
	local root = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
	Menu.PopulateDescription(function(_, rootDescription)
		local actions, switches = false, false
		for _, spec in ipairs(RAIL_BUTTONS) do
			if folded[spec.key] then
				if spec.checked then
					switches = true
				elseif not spec.choices then
					actions = true
					AddMenuEntry(rootDescription, spec)
				end
			end
		end
		if switches then
			if actions then
				rootDescription:CreateDivider()
			end
			for _, spec in ipairs(RAIL_BUTTONS) do
				if folded[spec.key] and spec.checked then
					AddMenuEntry(rootDescription, spec)
				end
			end
		end
		for _, spec in ipairs(RAIL_BUTTONS) do
			if folded[spec.key] and spec.choices then
				if actions or switches then
					rootDescription:CreateDivider()
				end
				AddMenuChoices(rootDescription, spec)
			end
		end
	end, button, root)
	-- Over the chat, beside the button.
	local left = DEFAULT_CHAT_FRAME.buttonSide ~= "right"
	local anchor = AnchorUtil.CreateAnchor(left and "TOPLEFT" or "TOPRIGHT", button,
		left and "TOPRIGHT" or "TOPLEFT", left and 4 or -4, 0)
	moreMenu = Menu.GetManager():OpenMenu(button, root, anchor)
	if moreMenu then
		Theme.PlaySound("check")
	end
end

-- The "more" button: a square like the others with three gold dots.
local function CreateMoreButton()
	local button = CreateFrame("Button", nil, rail)
	button:SetFrameStrata("MEDIUM")
	button:SetNormalAtlas("chatframe-button-up")
	button:SetPushedAtlas("chatframe-button-down")
	button:SetHighlightAtlas("chatframe-button-highlight", "ADD")
	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(MEDIA .. "IconMore", nil, nil, "NEAREST")
	icon:SetVertexColor(Theme.RAIL_ICON:GetRGB())
	button.icon = icon
	button:SetScript("OnClick", OpenMore)
	button:SetScript("OnMouseDown", function(self)
		self.icon:SetAlpha(0.75)
	end)
	button:SetScript("OnMouseUp", function(self)
		self.icon:SetAlpha(1)
	end)
	button:SetScript("OnEnter", function(self)
		ns.Links.ShowSmallTip(self, rail:GetLeft() < UIParent:GetWidth() / 2 and "ANCHOR_RIGHT" or "ANCHOR_LEFT", {
			{ ns.L.railMore, HIGHLIGHT_FONT_COLOR },
			{ ns.L.railMoreTip, NORMAL_FONT_COLOR, true },
		})
	end)
	button:SetScript("OnLeave", function(self)
		ns.Links.HideSmallTip(self)
	end)
	button:Hide()
	-- Painted with the rail's own (PaintRail).
	railButtons.railMore = button
	return button
end

-- Whole screen pixels in interface units, and the art's scale for this screen.
local function Pixel()
	return PixelUtil.ConvertPixelsToUIForRegion(1, UIParent)
end

local function ArtScale()
	local pixelsPerUnit = 1 / Pixel()
	return math.max(1, math.ceil(pixelsPerUnit - 0.5))
end

local function CreateRail()
	rail = CreateFrame("Frame", nil, GENERAL_CHAT_DOCK)
	rail:SetFrameStrata("BACKGROUND")
	rail:SetFrameLevel(1)
	railFill = ns.Shapes.Fill(rail, "BACKGROUND", 0, Theme.CARD_RADIUS)
	railFill:SetAllPoints(rail)
	railFill:SetColor(Theme.HEADER:GetRGBA())
	railShadow = ns.Skin.CreateShadow(rail, railFill.box, railFill.box)
end

-- Beside the docked card: from the header's top (the dock) to the footer's
-- bottom, on Blizzard's button side.
local function PlaceRail(px, scale)
	local chatFrame = DEFAULT_CHAT_FRAME
	local gap = RAIL_GAP * scale * px
	rail:ClearAllPoints()
	rail:SetWidth(RAIL_WIDTH * scale * px)
	if chatFrame.buttonSide == "right" then
		rail:SetPoint("TOPLEFT", GENERAL_CHAT_DOCK, "TOPRIGHT", gap, 0)
		rail:SetPoint("BOTTOMLEFT", chatFrame.Background, "BOTTOMRIGHT", gap, -Theme.FOOTER_HEIGHT)
	else
		rail:SetPoint("TOPRIGHT", GENERAL_CHAT_DOCK, "TOPLEFT", -gap, 0)
		rail:SetPoint("BOTTOMRIGHT", chatFrame.Background, "BOTTOMLEFT", -Theme.PANEL_PAD_LEFT - gap, -Theme.FOOTER_HEIGHT)
	end
end

-- One of Everchat's buttons at a whole-pixel offset from the rail's top
-- (positive `top`) or bottom (`bottom`).
local function PlaceRailButton(button, px, scale, top, bottom)
	local width = RAIL_WIDTH * scale
	local square, squareHeight = SQUARE_WIDTH * scale, SQUARE_HEIGHT * scale
	local icon = ICON_SIZE * scale
	button:SetSize(square * px, squareHeight * px)
	button:ClearAllPoints()
	local left = math.floor((width - square) / 2) * px
	if top then
		button:SetPoint("TOPLEFT", rail, "TOPLEFT", left, -top * px)
	else
		button:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", left, bottom * px)
	end
	button.icon:SetSize(icon * px, icon * px)
	button.icon:ClearAllPoints()
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT",
		math.floor((square - icon) / 2) * px, -math.floor((squareHeight - icon) / 2) * px)
end

local function IsRailButtonShown(spec)
	return ns.db[spec.key] and true or false
end

-- The column's buttons, offsets in whole pixels from the rail's bottom-left
-- (left edges rounded down where an odd width can't be centered).
local function PlaceStack(px, scale)
	local width = RAIL_WIDTH * scale
	local function Place(button, buttonWidth, buttonHeight, bottom)
		button:SetSize(buttonWidth * px, buttonHeight * px)
		button:ClearAllPoints()
		button:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", math.floor((width - buttonWidth) / 2) * px, bottom * px)
	end
	local square = SQUARE_WIDTH * scale
	local squareHeight = SQUARE_HEIGHT * scale
	-- The menu's square sits EDGE above the rail's bottom, like its sides.
	local menuBottom = (EDGE - MENU_ART_PADDING) * scale
	Place(ChatFrameMenuButton, MENU_SIZE * scale, MENU_SIZE * scale, menuBottom)
	-- The squares above follow the menu's square with GAP between them: the
	-- game's channels button and, in voice, its deafen and mute buttons, then
	-- Everchat's bottom buttons (its options) on top of them (2026-10-12, the
	-- user's call; they were between the menu and channels). Only the shown
	-- ones take room, so Everchat's sit right above whatever the game shows.
	-- While another tab is shown Blizzard hides General's button frame, and
	-- with it all of these: Everchat's then take the menu's place at the
	-- rail's foot instead of floating above a gap.
	local bottom = menuBottom + (MENU_SIZE - MENU_ART_PADDING) * scale + railGap * scale
	for _, button in ipairs({ ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton }) do
		Place(button, square, squareHeight, bottom)
		if button.Icon then
			button.Icon:SetSize(VOICE_ICON * scale * px, VOICE_ICON * scale * px)
		end
		if button:IsShown() then
			bottom = bottom + squareHeight + railGap * scale
		end
	end
	if not DEFAULT_CHAT_FRAME.buttonFrame:IsShown() then
		bottom = EDGE * scale
	end
	for _, spec in ipairs(RAIL_BUTTONS) do
		if spec.bottom and IsRailButtonShown(spec) and not folded[spec.key] then
			PlaceRailButton(railButtons[spec.key], px, scale, nil, bottom)
			bottom = bottom + (SQUARE_HEIGHT + railGap) * scale
		end
	end
end

-- What the container stacks under the social button: its alerts go by
-- priority, and the social button shares 0 with the text-to-speech button's
-- frame (26 units, shown even while its button is hidden) and the delves
-- toast, in an order a re-sort can change (voice notifications set
-- priorities); one of them ending up below it pushed it above the rail.
-- From the anchors (each alert by a bottom corner on the top corner of the
-- one below, the first on the container's own bottom corner) and heights:
-- the height below it and the part of that which shows (a frame whose
-- button is hidden shows nothing). Nil if laid out otherwise.
local function StackBelow(frame, depth)
	depth = depth or 0
	local point, relativeTo, relativePoint, _, y = frame:GetPoint(1)
	if depth > 8 or not (point and relativeTo and relativePoint) or not point:find("^BOTTOM") then
		return nil
	end
	if relativeTo == ChatAlertFrame then
		if point == relativePoint then
			return y or 0, 0
		end
		return nil
	end
	if not relativePoint:find("^TOP") then
		return nil
	end
	local below, shown = StackBelow(relativeTo, depth + 1)
	if not below then
		return nil
	end
	local height = relativeTo:GetHeight()
	local shows = relativeTo:IsShown() and not (relativeTo.Button and not relativeTo.Button:IsShown())
	return below + height + (y or 0), shown + (shows and height or 0)
end

-- What the social button stood on when placed, to notice when the game lays
-- the stack out anew, and how often that's looked at (seconds).
local placedAnchor
local STACK_CHECK = 0.5

-- What shows under the social button (the text-to-speech button while it's
-- on), in whole art pixels times the scale: the rail's own buttons start
-- below it.
Buttons.StackBelow = StackBelow

local function SocialExtra(px)
	local _, shown = StackBelow(QuickJoinToastButton)
	return math.ceil((shown or 0) / px)
end

-- The top ones, from the social button down, the gap apart like the squares
-- at the bottom, then the "more" button while some are folded.
local function PlaceTopRailButtons(px, scale)
	-- The social button's art has more transparent margin than the squares'.
	local top = (TOP_EDGE + SOCIAL_SIZE + railGap - 2) * scale + SocialExtra(px)
	for _, spec in ipairs(RAIL_BUTTONS) do
		local button = railButtons[spec.key]
		local shown = IsRailButtonShown(spec) and not folded[spec.key]
		button:SetShown(shown)
		if shown and not spec.bottom then
			PlaceRailButton(button, px, scale, top)
			top = top + (SQUARE_HEIGHT + railGap) * scale
		end
	end
	moreButton:SetShown(next(folded) ~= nil)
	if moreButton:IsShown() then
		PlaceRailButton(moreButton, px, scale, top)
	elseif moreMenu and moreMenu:IsShown() then
		Menu.GetManager():CloseMenus()
	end
end

-- Which buttons fold for the rail's height now.
local function Fold(px, scale)
	local extra = SocialExtra(px) / scale
	local shown = {}
	for _, spec in ipairs(RAIL_BUTTONS) do
		shown[spec.key] = IsRailButtonShown(spec) or nil
	end
	local squares
	if DEFAULT_CHAT_FRAME.buttonFrame:IsShown() then
		squares = 0
		for _, button in ipairs({ ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton }) do
			if button and button:IsShown() then
				squares = squares + 1
			end
		end
	end
	railGap, folded = Buttons.Fit(rail:GetHeight() / (px * scale), squares, shown, extra)
end

-- The social button lives in Blizzard's chat alert container (with the quick
-- join, delves and text-to-speech toasts), which lays it out inside itself:
-- as its first sub-system it's anchored by a bottom corner to the
-- container's same corner, on the side of its justification
-- (AlertContainerMixin), and the container goes where that anchor puts the
-- button TOP_EDGE below the rail's top, centered. Read from the anchor, not
-- from measured rectangles, which can still hold the old positions while the
-- resolution changes: measuring then once sent the button above the rail.
-- Measuring stays for a button laid out otherwise (another alert below it).
local function PlaceSocial(px, scale)
	local size = SOCIAL_SIZE * scale
	QuickJoinToastButton:SetSize(size * px, size * px)
	local left = math.floor((RAIL_WIDTH * scale - size) / 2) * px
	local top = -TOP_EDGE * scale * px
	local point, relativeTo = QuickJoinToastButton:GetPoint(1)
	local below = StackBelow(QuickJoinToastButton)
	placedAnchor = relativeTo
	if below and (point == "BOTTOMLEFT" or point == "BOTTOMRIGHT") then
		local cornerX = point == "BOTTOMLEFT" and left or left + size * px
		ChatAlertFrame:ClearAllPoints()
		ChatAlertFrame:SetPoint(point, rail, "TOPLEFT", cornerX, top - size * px - below)
		return
	end
	ChatAlertFrame:ClearAllPoints()
	ChatAlertFrame:SetPoint("TOPLEFT", rail, "TOPLEFT", left, top)
	local frameLeft, frameTop = ChatAlertFrame:GetLeft(), ChatAlertFrame:GetTop()
	local buttonLeft, buttonTop = QuickJoinToastButton:GetLeft(), QuickJoinToastButton:GetTop()
	if not (frameLeft and frameTop and buttonLeft and buttonTop) then
		return
	end
	ChatAlertFrame:ClearAllPoints()
	ChatAlertFrame:SetPoint("TOPLEFT", rail, "TOPLEFT", left - (buttonLeft - frameLeft), top + (frameTop - buttonTop))
end

-- The buttons on the rail as it is (also as it changes height).
local function PlaceButtons()
	local px, scale = Pixel(), ArtScale()
	Fold(px, scale)
	if ChatAlertFrame and QuickJoinToastButton then
		PlaceSocial(px, scale)
	end
	if ChatFrameMenuButton and ChatFrameChannelButton and ChatFrameToggleVoiceDeafenButton and ChatFrameToggleVoiceMuteButton then
		PlaceStack(px, scale)
	end
	PlaceTopRailButtons(px, scale)
end

local function Layout()
	rail:SetShown(not ns.db.hideButtons)
	PlaceRail(Pixel(), ArtScale())
	PlaceButtons()
end

-- The options' switches for Everchat's buttons.
-- A picture of one of the rail's buttons (the same square and gold glyph, at
-- the rail's pixel size): the settings page's hint points at the options
-- one, the options window's Buttons page shows each next to its switch.
function Buttons.CreatePicture(parent, iconFile)
	local px, scale = Pixel(), ArtScale()
	local picture = CreateFrame("Frame", nil, parent)
	picture:SetSize(SQUARE_WIDTH * scale * px, SQUARE_HEIGHT * scale * px)
	local square = picture:CreateTexture(nil, "ARTWORK")
	square:SetAtlas("chatframe-button-up")
	square:SetAllPoints()
	Theme.PaintArt(square)
	local icon = picture:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(MEDIA .. iconFile, nil, nil, "NEAREST")
	icon:SetVertexColor(Theme.RAIL_ICON:GetRGB())
	table.insert(pictures, { square = square, icon = icon })
	local size = ICON_SIZE * scale
	icon:SetSize(size * px, size * px)
	icon:SetPoint("TOPLEFT", picture, "TOPLEFT",
		math.floor((SQUARE_WIDTH * scale - size) / 2) * px, -math.floor((SQUARE_HEIGHT * scale - size) / 2) * px)
	return picture
end

function Buttons.Refresh()
	if rail then
		rail:SetShown(not ns.db.hideButtons)
		Layout()
	end
end

-- A button's square (its normal and pushed art), in the theme's metal.
local function PaintSquare(button)
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture() }) do
		Theme.PaintArt(texture)
	end
end

-- A voice button's icon: in the theme's metal, but a muted state's (its
-- atlas says "off" or "silenced") keeps its red slash.
local function PaintVoiceIcon(button)
	local icon = button.Icon
	if not icon then
		return
	end
	local atlas = icon:GetAtlas() or ""
	if atlas:find("off") or atlas:find("silenced") then
		icon:SetDesaturated(false)
		icon:SetVertexColor(1, 1, 1, icon:GetAlpha())
	else
		Theme.PaintArt(icon)
	end
end

local VOICE_BUTTONS = { "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }

-- Everything on the rail in the theme: Everchat's buttons and pictures, and
-- the game's (the social button's friends picture, the chat menu's, the
-- channel and voice buttons' squares and icons).
local function PaintRail()
	for _, button in pairs(railButtons) do
		PaintSquare(button)
		button.icon:SetVertexColor(Theme.RAIL_ICON:GetRGB())
	end
	for _, picture in ipairs(pictures) do
		Theme.PaintArt(picture.square)
		picture.icon:SetVertexColor(Theme.RAIL_ICON:GetRGB())
	end
	local social = QuickJoinToastButton
	if social and social.FriendsButton then
		Theme.PaintArt(social.FriendsButton)
	end
	if ChatFrameMenuButton then
		PaintSquare(ChatFrameMenuButton)
	end
	for _, name in ipairs(VOICE_BUTTONS) do
		local button = not ns.SkipsHook("voice") and _G[name]
		if button then
			PaintSquare(button)
			PaintVoiceIcon(button)
		end
	end
end

-- How far the rail reaches past the card on the left and on the right, in
-- interface units (Resize.lua keeps it on screen while moving the chat).
function Buttons.Reach()
	if not rail then
		return 0, 0
	end
	local reach = (RAIL_WIDTH + RAIL_GAP) * ArtScale() * Pixel()
	if DEFAULT_CHAT_FRAME.buttonSide == "right" then
		return 0, reach
	end
	return reach, 0
end

-- With the docked chat's chrome (Skin.lua's fades).
-- The rail's fill and shadow follow the docked chat's Background color and
-- opacity (Skin.lua), like its header.
-- How much of the shadow shows for the window's Background opacity.
local railOverlay = 1
function Buttons.SetOverlay(overlayFactor)
	railOverlay = overlayFactor
end

-- The chat's fade (Skin.lua): the rail in the header's color as painted (at
-- rest the message area's), its shadow with the card's. The buttons never
-- fade, like the game's own beside its docked chat. The minimal style has no
-- panel: the buttons stand on their own, as the game's chat buttons do.
function Buttons.ApplyAlpha(lit, r, g, b, a)
	if rail then
		-- Without a panel (the minimal style) nothing here shows.
		if railPanel ~= Theme.RAIL_PANEL then
			railPanel = Theme.RAIL_PANEL
			railFill:SetShown(railPanel)
			railShadow:SetShown(railPanel)
		end
		if railPanel then
			railFill:SetColor(r, g, b, a)
			railShadow:SetAlpha(lit * railOverlay)
		end
		-- The buttons never fade, save while the chat hides at rest: then the
		-- whole side bar goes with it, the game's buttons on it too.
		local alpha = ns.db.hideButtons and 0 or Theme.Rest(1, lit)
		if alpha ~= railAlpha then
			railAlpha = alpha
			rail:SetAlpha(alpha)
			for _, name in ipairs(GAME_BUTTONS) do
				local button = _G[name]
				if button then
					button:SetAlpha(alpha)
					if button.IsMouseEnabled and button.EnableMouse then
						if ns.db.hideButtons and button.baziChatMouse == nil then
							button.baziChatMouse = button:IsMouseEnabled()
							button:EnableMouse(false)
						elseif not ns.db.hideButtons and button.baziChatMouse ~= nil then
							button:EnableMouse(button.baziChatMouse)
							button.baziChatMouse = nil
						end
					end
				end
			end
		end
	end
end

-- Whether the mouse is over the side bar (Skin.lua keeps a hidden chat in
-- sight then).
function Buttons.IsMouseOver()
	return rail ~= nil and rail:IsVisible() and rail:IsMouseOver() or false
end

function Buttons.Init()
	CreateRail()
	for _, spec in ipairs(RAIL_BUTTONS) do
		CreateRailButton(spec)
	end
	moreButton = CreateMoreButton()
	Layout()
	-- The chat resized: the buttons fold or unfold to fit.
	rail:SetScript("OnSizeChanged", PlaceButtons)
	-- The game re-sorts and re-stacks its alerts without a word (a voice
	-- notification, an alert shown or gone): twice a second, one look at what
	-- the social button stands on (a single anchor read, nothing made or
	-- drawn), and the rail laid out again only when that changed. The
	-- text-to-speech button tells when it shows or hides by itself.
	if QuickJoinToastButton and ChatAlertFrame then
		C_Timer.NewTicker(STACK_CHECK, ns.Guard("Buttons.StackCheck", function()
			local _, relativeTo = QuickJoinToastButton:GetPoint(1)
			if relativeTo ~= placedAnchor then
				PlaceButtons()
			end
		end))
		local speech = _G.TextToSpeechButtonFrame and _G.TextToSpeechButtonFrame.Button
		if speech then
			speech:HookScript("OnShow", PlaceButtons)
			speech:HookScript("OnHide", PlaceButtons)
		end
	end
	-- Switches follow their state wherever it changes (the options too).
	local function ShowStates()
		for _, spec in ipairs(RAIL_BUTTONS) do
			if spec.state then
				local button = railButtons[spec.key]
				local icon, _, struck = spec.state()
				button.icon:SetTexture(MEDIA .. icon, nil, nil, "NEAREST")
				button.slash:SetShown(struck and true or false)
			end
		end
	end
	ns.Alerts.OnSwitchChanged(ShowStates)
	ShowStates()
	PaintRail()
	Theme.OnChanged(PaintRail)
	-- A voice button's icon changes with its state (events, clicks).
	for _, name in ipairs(VOICE_BUTTONS) do
		local button = _G[name]
		if button then
			button:HookScript("OnEvent", PaintVoiceIcon)
			button:HookScript("OnShow", PaintVoiceIcon)
			button:HookScript("OnClick", PaintVoiceIcon)
		end
	end
	-- Whole pixels change with the interface scale or the resolution; laid out
	-- again on the next frame too, once everything else has settled.
	local events = CreateFrame("Frame")
	events:RegisterEvent("UI_SCALE_CHANGED")
	events:RegisterEvent("DISPLAY_SIZE_CHANGED")
	events:SetScript("OnEvent", function()
		Layout()
		C_Timer.After(0, Layout)
	end)
	-- General's button frame shows and hides with the tab on show.
	DEFAULT_CHAT_FRAME.buttonFrame:HookScript("OnShow", Layout)
	DEFAULT_CHAT_FRAME.buttonFrame:HookScript("OnHide", Layout)
	-- The voice buttons come and go with voice chat; Everchat's sit above them.
	for _, button in ipairs({ ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton }) do
		if button then
			button:HookScript("OnShow", Layout)
			button:HookScript("OnHide", Layout)
		end
	end
	-- The social button can only be measured once it's laid out and shown.
	if QuickJoinToastButton then
		QuickJoinToastButton:HookScript("OnShow", Layout)
	end
	-- Blizzard's button side can change (chat settings).
	hooksecurefunc("FCF_SetButtonSide", function(chatFrame)
		if chatFrame == DEFAULT_CHAT_FRAME then
			Layout()
		end
	end)
end
