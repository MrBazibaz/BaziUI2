local ns = BaziUI.Chat
local Theme = ns.Theme

local Resize = {}
ns.Resize = Resize

-- Every chat window gets a grip at its card's bottom-right corner. Docked
-- windows share the main window's size (Blizzard anchors them all to it), so
-- their grips resize the main window, as Blizzard's own grabber does. A
-- floating window's grip resizes that window and saves its size where
-- Blizzard's grabber does; that grabber steps aside for ours.
--
-- The docked chat moves by dragging the header's free space (Header.lua's
-- title bar, which calls StartMoving here), at any time except in combat.
-- Floating windows move by their tab, as Blizzard's do, and follow Blizzard's
-- own lock (tab menu) for their grips.
--
-- The docked chat can be locked (`lockChat`: a click on the header's move
-- grip, "Lock Window" in a docked tab's menu, or Options > Appearance), so it
-- isn't moved or resized by accident: its grips go, as the game takes the
-- grabber off its locked windows, and Shift brings them back while the mouse
-- is on the chat, to move or resize it anyway (as Shift picks up spells from
-- the game's locked action bars) or to unlock it with a click on the move
-- grip. Edit Mode still moves it.
--
-- The main window's size and position belong to Edit Mode. A size or place
-- set here is saved by Everchat and re-applied whenever Edit Mode applies its
-- layout; moving or resizing the chat in Edit Mode hands control back to Edit
-- Mode. Edit Mode's manager is never called (only asked whether it's active),
-- so its code isn't tainted.
local GRIP_SIZE = 20
local GRIP_INSET = 2
-- The grip's mark: three gold grooves across the corner (Media/
-- IconGripResize, art/add-icons.py, in the header icons' gold; 2026-10-11,
-- the user's pick: grooves here, studs on the header's move grip), glowing
-- under the mouse like Everchat's other gold glyphs. Before: a triangle of
-- flat gold dots; Blizzard's own grabber art (UI-ChatIM-SizeGrabber) read as
-- the 2004 game.
local GRIP_ICON = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconGripResize"
-- From the grip's corner to the icon's, in screen pixels.
local GRIP_ICON_INSET = 2

-- Above everything in the chat's own strata (the docked tabs included).
local CONTROL_STRATA = "MEDIUM"
local CONTROL_LEVEL = 60

-- The footer's right end taken by the grip; the edit box's field stops before it.
local GRIP_GAP = 4
-- The game's grabber (FloatingChatFrame.xml's ResizeButton).
local GAME_GRABBER_SIZE = 16
Resize.FOOTER_CONTROLS_WIDTH = GRIP_INSET + GRIP_SIZE + GRIP_GAP

-- How far the card reaches past the main window on each side (Blizzard's
-- Background offsets plus the header, footer and hairline), so moving keeps it
-- on screen.
local REACH_LEFT = 2 + Theme.PANEL_PAD_LEFT + Theme.EDGE_OUTSET
local REACH_RIGHT = 15 + Theme.EDGE_OUTSET
local REACH_TOP = 3 + Theme.HEADER_HEIGHT + Theme.EDGE_OUTSET
local REACH_BOTTOM = 6 + Theme.FOOTER_HEIGHT + Theme.EDGE_OUTSET

-- Grips by chat window; the grip and skin of a resize in progress; the
-- handle and window of a move, and whether the chat has moved yet.
local grips = {}
local sizingTarget, sizingGrip
local movingHandle, movingWindow, moved
-- A move starts once the cursor has gone this far (screen pixels), so a
-- click on the header doesn't nudge the chat.
local MOVE_THRESHOLD = 4
-- While locked, Shift held with the mouse on the chat shows the grips; locked
-- by a Shift-click, not until Shift is let go and pressed again.
local revealed, revealHeld = false, false
local lockListeners = {}

local function Clamp(value, low, high)
	return math.min(math.max(value, low), high)
end

local function IsEditing()
	return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

function Resize.IsMoving()
	return movingHandle ~= nil
end

function Resize.IsLocked()
	return ns.db.lockChat and true or false
end

-- Whether the docked chat can be moved or resized now.
local function Free()
	return not ns.db.lockChat
end

-- Whether the docked chat's grips show: unlocked, revealed by Shift, or in
-- use (a grip hidden mid-drag would never hear the button go up).
function Resize.ShowsGrips()
	if ns.db.hideButtons then return false end
	return not ns.db.lockChat or movingHandle ~= nil or sizingGrip ~= nil
end

-- Called when the lock or the grips' visibility changes (Header.lua).
function Resize.OnLockChanged(listener)
	table.insert(lockListeners, listener)
end

-- The main window's size and place are saved per character, like the rest of
-- a character's interface: a new character keeps Edit Mode's layout (made to
-- fit the default action bars) until the player resizes or moves the chat.
local function CharacterKey()
	return ns.CharacterKey()
end

local function GetLayout()
	local layout = ns.db.chatLayouts and ns.db.chatLayouts[CharacterKey()]
	if layout ~= nil then return layout or nil end
	return ns.db.defaultLayout and CopyTable(ns.db.defaultLayout)
end

local function SetLayout(layout)
	ns.db.chatLayouts = ns.db.chatLayouts or {}
	ns.db.chatLayouts[CharacterKey()] = layout or false
	if layout then ns.db.defaultLayout = CopyTable(layout) end
end

-- Before v0.23.1 one layout served the whole account, so every character got
-- the first one's chat. It goes to the character with the most saved chat
-- (History), the one most played with Everchat; others start from Edit Mode.
local function AdoptAccountLayout()
	local layout = ns.db.chatLayout
	if not layout then
		return
	end
	ns.db.chatLayout = nil
	local owner, most = nil, 0
	for key, windows in pairs(BaziUI.db.chatHistory.history or {}) do
		local count = 0
		for _, lines in pairs(windows) do
			count = count + #lines
		end
		if count > most then
			owner, most = key, count
		end
	end
	if owner then
		ns.db.chatLayouts = ns.db.chatLayouts or {}
		ns.db.chatLayouts[owner] = ns.db.chatLayouts[owner] or layout
	end
end

-- The main window's saved size and place, over Edit Mode's.
local function Apply(chatFrame)
	local layout = GetLayout()
	if not layout or IsEditing() or movingWindow == chatFrame or sizingTarget == chatFrame
		or (InCombatLockdown() and chatFrame:IsProtected()) then
		return
	end
	-- The chat frame and its visible card have different edges. Let the numeric
	-- layout move the card flush with the screen without Blizzard moving it back.
	chatFrame:SetClampedToScreen(false)
	local anchor, parent, relative, x, y = chatFrame:GetPoint(1)
	if chatFrame:GetNumPoints() ~= 1 or anchor ~= "TOPLEFT" or parent ~= UIParent
		or relative ~= "BOTTOMLEFT" or x ~= layout.left or y ~= layout.top then
		chatFrame:ClearAllPoints()
		chatFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", layout.left, layout.top)
	end
	if chatFrame:GetWidth() ~= layout.width or chatFrame:GetHeight() ~= layout.height then
		chatFrame:SetSize(layout.width, layout.height)
	end
end

local function Save(chatFrame)
	if chatFrame == DEFAULT_CHAT_FRAME then
		SetLayout({
			left = chatFrame:GetLeft(),
			top = chatFrame:GetTop(),
			width = chatFrame:GetWidth(),
			height = chatFrame:GetHeight(),
		})
	else
		-- Where Blizzard keeps a floating window's size and place.
		FCF_SavePositionAndDimensions(chatFrame)
	end
end

-- Hands the main window's size and position back to Edit Mode.
function Resize.GetLayout()
	local frame = DEFAULT_CHAT_FRAME
	return GetLayout() or {left = frame:GetLeft() or 0, top = frame:GetTop() or 260,
		width = frame:GetWidth(), height = frame:GetHeight()}
end

function Resize.SetLayoutValue(key, value)
	local layout = Resize.GetLayout()
	if key == "height" then layout.top = layout.top - layout.height + value end
	if key == "bottom" then
		layout.top = value + layout.height
	else
		layout[key] = value
	end
	SetLayout(layout)
	if ns.active then Apply(DEFAULT_CHAT_FRAME) end
end

function Resize.Forget()
	SetLayout(nil)
end

-- The top-left corner stays put and the bottom-right one follows the cursor.
-- Sizes follow the cursor's movement, not its position, so the grip can sit
-- anywhere near the corner without the window jumping.
local function StartSizing(grip, chatFrame, skin)
	local target = chatFrame.isDocked and GENERAL_CHAT_DOCK.primary or chatFrame
	if target == DEFAULT_CHAT_FRAME and (IsEditing() or not Free()) then
		return
	end
	sizingTarget, sizingGrip = target, grip
	-- Stay lit while resizing: the cursor leaves the chat, which would fade it.
	ns.Skin.Hold(skin, "resizing", true)

	local scale = target:GetEffectiveScale()
	local startX, startY = GetCursorPosition()
	local startWidth, startHeight = target:GetWidth(), target:GetHeight()
	local minWidth, minHeight, maxWidth, maxHeight = target:GetResizeBounds()
	if not maxWidth or maxWidth <= 0 then
		maxWidth = math.huge
	end
	if not maxHeight or maxHeight <= 0 then
		maxHeight = math.huge
	end

	local left, top = target:GetLeft(), target:GetTop()
	target:ClearAllPoints()
	target:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

	grip:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		local width = Clamp(startWidth + (x - startX) / scale, minWidth, maxWidth)
		local height = Clamp(startHeight - (y - startY) / scale, minHeight, maxHeight)
		target:SetSize(math.floor(width), math.floor(height))
	end)
end

local function StopSizing(grip, skin)
	if grip == sizingGrip then
		grip:SetScript("OnUpdate", nil)
		Save(sizingTarget)
		sizingTarget, sizingGrip = nil, nil
		ns.Skin.Hold(skin, "resizing", false)
		Resize.UpdateLock()
	end
end

-- Moves the docked chat (the main window) by the cursor's movement, once it
-- has gone MOVE_THRESHOLD.
function Resize.StartMoving(handle)
	local target = DEFAULT_CHAT_FRAME
	if movingHandle or IsEditing() or InCombatLockdown() or not Free() then
		return
	end
	movingHandle, moved = handle, false
	movingWindow = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
	ns.Skin.HoldWindow(movingWindow, "moving", true)

	local scale = target:GetEffectiveScale()
	local startX, startY = GetCursorPosition()
	local left, top = target:GetLeft(), target:GetTop()
	local width, height = target:GetWidth(), target:GetHeight()
	-- The buttons' rail (Buttons.lua) reaches further on its side.
	local railLeft, railRight = ns.Buttons.Reach()
	local reachLeft, reachRight = REACH_LEFT + railLeft, REACH_RIGHT + railRight
	local maxLeft = UIParent:GetWidth() - width - reachRight
	local maxTop = UIParent:GetHeight() - REACH_TOP
	handle:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		if not moved then
			if math.abs(x - startX) < MOVE_THRESHOLD and math.abs(y - startY) < MOVE_THRESHOLD then
				return
			end
			moved = true
		end
		local newLeft = Clamp(left + (x - startX) / scale, reachLeft, math.max(reachLeft, maxLeft))
		local newTop = Clamp(top + (y - startY) / scale, height + REACH_BOTTOM, math.max(height + REACH_BOTTOM, maxTop))
		target:ClearAllPoints()
		target:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", math.floor(newLeft), math.floor(newTop))
	end)
end

-- Returns whether the chat moved (a click on the header doesn't, and isn't
-- saved: the chat stays Edit Mode's).
function Resize.StopMoving(handle)
	if handle ~= movingHandle then
		return false
	end
	handle:SetScript("OnUpdate", nil)
	movingHandle = nil
	ns.Skin.HoldWindow(movingWindow, "moving", false)
	movingWindow = nil
	if moved then
		Save(DEFAULT_CHAT_FRAME)
		-- What's drawn over the lines sits on whole pixels where they were.
		ns.Channels.Realign()
	end
	Resize.UpdateLock()
	return moved
end

-- Docked windows show their grips unless the chat is locked; floating
-- windows' grips follow Blizzard's rule for its grabber
-- (FCF_UpdateResizeButton).
local function UpdateControls(chatFrame)
	local grip = grips[chatFrame]
	if not grip then
		return
	end
	local free
	if chatFrame.isDocked then
		free = Resize.ShowsGrips()
	else
		free = not chatFrame.isLocked
	end
	grip:SetShown(free and not chatFrame.isUninteractable)
end

-- Every grip as the lock and Shift say, and the listeners told.
function Resize.UpdateLock()
	for chatFrame in pairs(grips) do
		UpdateControls(chatFrame)
	end
	for _, listener in ipairs(lockListeners) do
		listener()
	end
end

-- Shift held over the locked chat: watched each frame only while Shift is
-- down, since the mouse can come onto the chat with Shift already held.
local revealWatcher = CreateFrame("Frame")

local function OverChat()
	return ns.Skin.IsMouseOverCard(FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK))
end

local function SetRevealed(shown)
	if revealed ~= shown then
		revealed = shown
		Resize.UpdateLock()
	end
end

local function WatchReveal()
	SetRevealed(OverChat() and true or false)
end

-- Not while typing: Shift there is for capitals, with the mouse anywhere.
local function UpdateReveal()
	revealHeld = revealHeld and IsShiftKeyDown()
	local watching = ns.db.lockChat and IsShiftKeyDown() and not revealHeld and not GetCurrentKeyBoardFocus()
	revealWatcher:SetScript("OnUpdate", watching and ns.Guard("Resize.WatchReveal", WatchReveal) or nil)
	if watching then
		WatchReveal()
	else
		SetRevealed(false)
	end
end

-- `withSound`: the padlock's sound, for a click that has none of its own.
function Resize.SetLocked(locked, withSound)
	ns.db.lockChat = locked and true or false
	revealed = false
	-- The grips go at once, though Shift is still down from the click.
	revealHeld = ns.db.lockChat and IsShiftKeyDown()
	-- First: the listeners below ask whether it's playing.
	ns.Padlock.Play(ns.db.lockChat, withSound)
	UpdateReveal()
	Resize.UpdateLock()
	ns.Alerts.NotifySwitchChanged()
end

function Resize.Attach(chatFrame, skin)
	local grip = CreateFrame("Button", nil, chatFrame)
	grip:SetSize(GRIP_SIZE, GRIP_SIZE)
	-- At the footer's end, after the field; with the game's art, whose field
	-- runs the card's whole width, or with no footer (a floating window
	-- without its field, Skin.SetFooterShown), where the game's own grabber
	-- is, at the message area's bottom-right corner.
	local function Place()
		grip:ClearAllPoints()
		if Theme.GAME_ART or not ns.Skin.IsFooterShown(chatFrame) then
			grip:SetPoint("BOTTOMRIGHT", chatFrame.Background, "BOTTOMRIGHT")
		else
			grip:SetPoint("BOTTOMRIGHT", skin.footer, "BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
		end
	end
	Place()
	Theme.OnChanged(Place)
	ns.Skin.OnFooterChanged(function(changed)
		if changed == chatFrame then
			Place()
		end
	end)
	grip:SetFrameStrata(CONTROL_STRATA)
	grip:SetFrameLevel(CONTROL_LEVEL)
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, grip)
	local icon = grip:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(GRIP_ICON)
	local size = ns.Shapes.ArtPixels(icon, Theme.ICON_PIXELS)
	icon:SetSize(size, size)
	icon:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -GRIP_ICON_INSET * px, GRIP_ICON_INSET * px)
	local glow = ns.Shapes.Glow(grip)
	glow:SetPoint("CENTER", icon, "CENTER")
	-- With the game's art, the game's own grabber (its size and textures, in
	-- the corner where the game has it): up, lit under the mouse, down while
	-- held.
	local gameArt = {}
	for _, state in ipairs({ "Up", "Highlight", "Down" }) do
		local texture = grip:CreateTexture(nil, "ARTWORK")
		texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-" .. state)
		texture:SetSize(GAME_GRABBER_SIZE, GAME_GRABBER_SIZE)
		texture:SetPoint("BOTTOMRIGHT")
		-- A button's highlight texture is drawn added over its normal one.
		if state == "Highlight" then
			texture:SetBlendMode("ADD")
		end
		gameArt[state] = texture
	end
	-- Darker at rest like the header's icons, full and glowing under the
	-- mouse and while resizing.
	local hovered, held = false, false
	local function Update()
		local lit = hovered or held
		local game = Theme.GAME_ART
		gameArt.Up:SetShown(game and not held)
		gameArt.Highlight:SetShown(game and hovered and not held)
		gameArt.Down:SetShown(game and held)
		icon:SetShown(not game)
		Theme.PaintArt(icon, lit and 1 or Theme.ICON_REST, (lit and Theme.GLYPH_HOVER or Theme.GLYPH).a)
		glow:SetShown(lit and not game)
		glow:SetAlpha(held and Theme.GLOW_OPEN_ALPHA or Theme.GLOW_HOVER_ALPHA)
	end
	-- A new theme: the grip in its metal.
	Theme.OnChanged(Update)
	grip:SetScript("OnEnter", function()
		hovered = true
		Update()
	end)
	grip:SetScript("OnLeave", function()
		hovered = false
		Update()
	end)
	grip:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			held = true
			Update()
			StartSizing(self, chatFrame, skin)
		end
	end)
	grip:SetScript("OnMouseUp", function(self)
		held = false
		Update()
		StopSizing(self, skin)
	end)
	Update()
	table.insert(skin.controls, grip)
	grips[chatFrame] = grip


	-- Blizzard's grabber (shown on unlocked floating windows) stays in place,
	-- out of sight and out of the way.
	chatFrame.ResizeButton:SetAlpha(0)
	chatFrame.ResizeButton:EnableMouse(false)

	UpdateControls(chatFrame)
end

-- Whether the main window sits where the saved layout puts it.
function Resize.Init()
	local primary = DEFAULT_CHAT_FRAME
	-- Edit Mode puts its own layout back when it loads its layouts and when it
	-- closes (reverting unsaved changes); ours goes back on top right after.
	-- Events and EventRegistry callbacks rather than hooks on the chat frame's
	-- Edit Mode methods: under Forever's addon restrictions (instances,
	-- combat), Blizzard's own calls to a method an addon hooked on an object
	-- fail ("attempt to call a nil value").
	local function ApplySoon()
		C_Timer.After(0, function()
			Apply(primary)
		end)
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	events:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
	for _, event in ipairs({"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED"}) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "MODIFIER_STATE_CHANGED" then
			UpdateReveal()
			return
		end
		ApplySoon()
		if event == "PLAYER_LEVEL_UP" or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
			C_Timer.After(0.25, function() Apply(primary) end)
		end
	end)
	EventRegistry:RegisterCallback("EditMode.Exit", ApplySoon, Resize)
	-- The player saved Edit Mode with the chat somewhere else (moved, resized
	-- or set in its settings there): that's the size and place now.
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", ApplySoon, Resize)
	-- Locking, docking and undocking all end here.
	hooksecurefunc("FCF_UpdateResizeButton", UpdateControls)
	events:RegisterEvent("MODIFIER_STATE_CHANGED")
	AdoptAccountLayout()
	if not GetLayout() and primary:GetTop() then Save(primary) end
	if not ns.db.defaultLayout and GetLayout() then ns.db.defaultLayout = CopyTable(GetLayout()) end
	local selection = primary.Selection
	if selection then
		selection:HookScript("OnShow", function(self) self:Hide() end)
		selection:Hide()
	end
	Apply(primary)
end
