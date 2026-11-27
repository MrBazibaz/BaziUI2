local ns = BaziUI.Chat
local Theme = ns.Theme

local Header = {}
ns.Header = Header

-- The header. Everchat lays the docked tabs out itself, inside a frame that
-- clips them: the strip scrolls smoothly when the tabs don't fit, and a tab is
-- reordered by dragging it along the strip while the others slide to open a
-- gap. The "+" follows the last tab (pinned at the right, next to a chevron
-- listing every docked window, while the strip overflows). The header's free
-- space after the "+" moves the chat when dragged, like a window's title bar
-- (as does the move button in the footer, Resize.lua).
--
-- Everything that changes the dock stays Blizzard's. Selecting is the click on
-- a tab or on an entry of the chevron's list. Docked tabs don't start
-- Blizzard's drag, which undocks the window, unless Shift is held; undocking is
-- otherwise the tab menu's "Undock Window" (Firefox and ChatTabDockLock do the
-- same). Floating windows keep that drag: it moves them, and dropping one on
-- the strip docks it where the gap shows (while the cursor stays near the
-- strip the window is invisible and a ghost tab rides the cursor).
--
-- The order shown is Everchat's, saved per character: Blizzard keeps its own
-- (General and the combat log first, every other window after them).

-- Temporary (whisper) tabs may carry secret names, so they keep Blizzard's
-- widest fixed size, and the label width FCF_SetTabFixedWidth gives them
-- (CHAT_TAB_SIDES_PADDING is local there). Other tabs fit their names.
local TEMPORARY_TAB_WIDTH = 90
local TAB_SIDES_PADDING = 20
-- Blizzard's spacing between docked tabs.
-- Tabs touch: a 1-unit gap showed as a dark seam between a hovered tab
-- (lighter) and the active one, which looked like they overlapped.
local TAB_GAP = 0
-- Between the last tab and the "+".
local ADD_GAP = 2

local BUTTON_SIZE = 18
local BUTTON_INSET = 3
local BUTTON_GAP = 2
-- Free header always kept at the right for moving the chat: the strip
-- overflows (and the "+" and chevron pin beside it) before it would shrink
-- below. A grip of six gold studs (Media/IconGripMove, art/add-icons.py;
-- flat gold dots until 2026-10-11) marks it at the header's right end, a
-- little darker at rest like the header's icons and lit under the mouse.
local TITLE_BAR_MIN = 32
-- With the game's art the tabs stand on the edge the game draws around the
-- messages (Skin.lua), a pixel above the message area, so its dark line
-- seats them: standing on the message area they covered it, and 2 units up
-- a sliver of the world showed under them.
local GAME_TAB_LIFT = 1
-- The game's tab art reaches 2 units past the tab's left (ChatTabArtTemplate):
-- the strip starts that much earlier so it isn't cut, and the first tab's
-- art meets the card's edge as in the game.
local GAME_ART_OVERHANG = 2

local function TabLift()
	return Theme.GAME_ART and ns.Shapes.ArtPixels(GENERAL_CHAT_DOCK, GAME_TAB_LIFT) or 0
end

-- Where tabs start inside the strip.
local function StripInset()
	return Theme.GAME_ART and GAME_ART_OVERHANG or 0
end
local GRIP_ICON = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconGripMove"
local LIST_INSET = 4
-- Everchat's gold chevron (art/add-icons.py), of the "+"'s family and size:
-- Blizzard's thin one (uitools-icon-chevron-down) tinted gold looked of
-- another set beside the "+".
local CHEVRON_ICON = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconChevron"
-- How far left of a tab's right end its own unread dot is (Alerts.lua), to
-- tell whether that dot is in view.
local TAB_DOT_INSET = 4
-- Where unread dots sit on the chevron (by the end of its right arm, which
-- starts 4px down the icon) and on the rows of its list (in the left gutter
-- Blizzard keeps for an icon).
local CHEVRON_DOT_X = 1
local CHEVRON_DOT_Y = -2
local LIST_DOT_X = 10

-- Scrolling and sliding ease out exponentially (Blizzard's own tab scrolling
-- does the same); these are per second.
local SCROLL_SPEED = 14
local SLIDE_SPEED = 18
local SETTLE = 0.5
local WHEEL_STEP = 80
-- Room kept around the selected tab when scrolling it into view.
local REVEAL_MARGIN = 8
-- Shading over clipped tabs at the strip's left edge.
local EDGE_FADE = 14
-- While the strip overflows, the name of the tab cut at its right end fades
-- out letter by letter over its last stretch (Tabs.SetNameFade), with some
-- air before the "+" and the chevron, so they read as an area of their own
-- (as Firefox's and VS Code's tab bar buttons do). The letters themselves
-- fade, not a shade laid over them: at rest the header is see-through, and a
-- shade over it showed as a darker band ending square at the strip's end. A
-- line between them was tried: next to cut text it read as a text cursor.
local OVERFLOW_FADE = 24
local OVERFLOW_GAP = 8

-- How far the cursor travels before a press on a tab starts reordering it.
local DRAG_THRESHOLD = 5
-- How far above and below the strip a floating window's drop still docks
-- (Blizzard allows 10px on its own), and the edge zone that scrolls the strip.
local DRAG_BAND = 12
local AUTO_SCROLL_EDGE = 24
local AUTO_SCROLL_SPEED = 240

-- Frame levels above the strip.
local TAB_LEVEL = 2
local DRAGGED_LEVEL = 6
local FADE_LEVEL = 8
local GHOST_LEVEL = 10
-- Above the dock: over the strip's levels and the header's buttons.
local WHEEL_LEVEL = 40

local dock, strip, driver, fades, fadeLeft, ghost
local addButton, titleBar, titleGrip
-- With the game's art the grip is drawn as the tabs' letters are, and always
-- shows: with no strip behind the tabs nothing else marks the spot.
local gripLetter
-- Places the move grip (defined with it, below; the layout calls it).
local PlaceGrip
-- Everchat's regions on Blizzard's overflow button.
local chevron, chevronBack
-- Unread marks: on the chevron, and on its list's rows (by row).
local chevronMark
local listMarks = {}
local chevronHovered = false
-- The chat's fade (Skin.lua) and whether a hidden tab has unread messages.
local chatLit = 0
local chevronAlerting = false

-- Docked tabs in display order, and which are temporary windows.
local tabs, temporary = {}, {}
-- A docked tab kept out of the strip (the combat log's, when the player hides
-- it): parked on a hidden frame of ours, so the game's own showing of the tab
-- can't bring it back, and the window keeps working under it.
local parking
local parked = {}
-- Tabs whose scripts are hooked, and docked tabs whose drag is turned off.
local hooked, undraggable = {}, {}
-- Positions along the strip's content, and where each is on its way there.
local targetX, currentX = {}, {}
local contentWidth, viewport, maxScroll = 0, 0, 0
local scroll, targetScroll = 0, 0
local pinned = false
-- A press on a docked tab, until it travels far enough to become a reorder.
local press
-- The tab being reordered: tab, width, grab (cursor offset into the tab),
-- x (along the viewport), index (gap position among the other tabs).
local reorder
-- Blizzard's drag of a floating window: chatFrame, tab, width, grab, inBand,
-- ghostX (along the viewport), index (gap position).
local drag
-- The docked tab under the mouse, but for the open one (Tabs.lua).
local hoveredTab

local function Clamp(value, low, high)
	return math.min(math.max(value, low), high)
end

local function Approach(current, target, factor)
	local next = current + (target - current) * factor
	if math.abs(target - next) < SETTLE then
		return target
	end
	return next
end

local function TabOf(chatFrame)
	return _G[chatFrame:GetName() .. "Tab"]
end

local function CursorX()
	return GetCursorPosition() / strip:GetEffectiveScale()
end

local function Run()
	if not driver:GetScript("OnUpdate") then
		driver:SetScript("OnUpdate", ns.Guard("Header.Tick", Header.Tick))
	end
end

-- Docked tabs start Blizzard's drag (which undocks) only while Shift is held.
local function UpdateDragRegistration()
	local shift = IsShiftKeyDown()
	for _, tab in ipairs(tabs) do
		if shift then
			tab:RegisterForDrag("LeftButton")
		else
			tab:RegisterForDrag()
		end
		undraggable[tab] = true
	end
end

local OnTabDragStart, FinishReorder

local function OnTabMouseDown(tab, button)
	if button == "LeftButton" and not IsShiftKeyDown() and not (drag or reorder) and targetX[tab] then
		press = { tab = tab, x = CursorX() }
		Run()
	end
end

-- Before Blizzard's OnClick, which selects the tab if it's still under the
-- cursor: dragging a tab also selects it.
local function OnTabMouseUp(tab)
	press = nil
	if reorder and reorder.tab == tab then
		FinishReorder()
	end
end

-- What the strip does that the game doesn't, told in the tab's own tooltip in
-- Blizzard's style (green, in angle brackets, like its right-click line).
local L = ns.L

-- After Blizzard's OnEnter has built its tooltip (the tab's name and the
-- right-click line): the same in Everchat's small tooltip, like the "+" and
-- the free space next to it, plus reordering while there's more than one tab
-- and scrolling while some are out of view. A name that can't be read (a
-- whisper's, in chat lockdown) keeps Blizzard's tooltip.
local function OnTabEnter(tab)
	local name = tab:GetText()
	if reorder or not GameTooltip:IsOwned(tab) or not canaccessvalue(name) or not name then
		return
	end
	local lines = {
		{ CHAT_TAB_NAME:format(name), HIGHLIGHT_FONT_COLOR },
		{ CHAT_TAB_RIGHT_CLICK, GREEN_FONT_COLOR },
	}
	-- Floating windows' tabs (out of the strip) don't reorder or scroll.
	if tab:GetParent() == strip then
		if #tabs > 1 then
			table.insert(lines, { L.tabReorder, GREEN_FONT_COLOR })
		end
		if maxScroll > 0 then
			table.insert(lines, { L.tabScroll, GREEN_FONT_COLOR })
		end
	end
	GameTooltip:Hide()
	-- Tabs are taller than the header (Blizzard's 32 units, bottoms
	-- aligned): from the header's top, like the "+" and the free space.
	local lift = math.max(0, tab:GetHeight() - Theme.HEADER_HEIGHT)
	ns.Links.ShowSmallTip(tab, "ANCHOR_TOP", lines, 0, -lift)
end

local function OnTabLeave(tab)
	ns.Links.HideSmallTip(tab)
end

-- The combat log's filter bar (My actions, What happened to me?...) hangs
-- from its tab (Blizzard_CombatLog parents it there to share the tab's alpha)
-- and sits above the window, outside the tab: inside the clipping strip it
-- disappeared. It goes to the window instead (same anchors; Blizzard shows and
-- hides it with the window), in Blizzard's strata; Skin.lua fades it with the
-- open tab, as the tab's alpha did.
local function FreeFilterBar(tab)
	local chatFrame = _G["ChatFrame" .. tab:GetID()]
	local bar = chatFrame and chatFrame.CombatLogQuickButtonFrame
	if bar and bar:GetParent() ~= chatFrame then
		bar:SetParent(chatFrame)
		bar:SetFrameStrata("MEDIUM")
	end
end

-- A tab joins the strip: parented into it, clipped with it, sized.
local function Adopt(tab)
	if tab:GetParent() ~= strip then
		tab:SetParent(strip)
	end
	FreeFilterBar(tab)
	tab:SetFrameStrata(strip:GetFrameStrata())
	if not (reorder and reorder.tab == tab) then
		tab:SetFrameLevel(strip:GetFrameLevel() + TAB_LEVEL)
	end
	if temporary[tab] then
		tab.Text:SetWidth(TEMPORARY_TAB_WIDTH - TAB_SIDES_PADDING - (tab.sizePadding or 0))
		tab:SetWidth(TEMPORARY_TAB_WIDTH)
	else
		-- Blizzard sizes every window but General and the combat log like a
		-- temporary one; here they all fit their names.
		PanelTemplates_TabResize(tab, tab.sizePadding or 0)
	end
	if not hooked[tab] then
		hooked[tab] = true
		tab:HookScript("OnDragStart", OnTabDragStart)
		tab:HookScript("OnMouseDown", OnTabMouseDown)
		tab:HookScript("OnMouseUp", OnTabMouseUp)
		tab:HookScript("OnEnter", OnTabEnter)
		tab:HookScript("OnLeave", OnTabLeave)
	end
end

-- The player's order for this character's docked windows, by window ID.
local function GetOrder()
	local key = ns.CharacterKey()
	ns.db.tabOrder = ns.db.tabOrder or {}
	ns.db.tabOrder[key] = ns.db.tabOrder[key] or {}
	return ns.db.tabOrder[key]
end

-- Who wants to know when the docked windows, their order or their names
-- change (the options window's tabs table).
local tabListeners = {}

function Header.OnTabsChanged(listener)
	table.insert(tabListeners, listener)
end

local function TabsChanged()
	for _, listener in ipairs(tabListeners) do
		listener()
	end
end

-- The docked windows' IDs in the strip's order.
function Header.Order()
	local ids = {}
	for _, tab in ipairs(tabs) do
		table.insert(ids, tab:GetID())
	end
	return ids
end

-- A parked tab keeps its place, for when it shows again.
local function SaveOrder()
	local order = GetOrder()
	local kept = {}
	for index, id in ipairs(order) do
		for tab in pairs(parked) do
			if tab:GetID() == id then
				table.insert(kept, { index = index, id = id })
			end
		end
	end
	wipe(order)
	for _, tab in ipairs(tabs) do
		table.insert(order, tab:GetID())
	end
	for _, entry in ipairs(kept) do
		table.insert(order, math.min(entry.index, #order + 1), entry.id)
	end
	TabsChanged()
end

local function Forget(id)
	local order = GetOrder()
	for index = #order, 1, -1 do
		if order[index] == id then
			table.remove(order, index)
		end
	end
end

-- The combat log's tab, hidden by the player, stays out of the strip. Hidden
-- while open, the window stays on show until another tab is clicked
-- (selecting is the game's click).
local function IsParked(chatFrame)
	return ns.db.hideCombatLogTab ~= false and chatFrame == COMBATLOG
end

local function Park(tab)
	FreeFilterBar(tab)
	if tab:GetParent() ~= parking then
		tab:SetParent(parking)
	end
	parked[tab] = true
end

-- The windows the player placed, then any other in Blizzard's order.
local function Collect()
	local rank = {}
	for position, id in ipairs(GetOrder()) do
		rank[id] = position
	end
	local entries = {}
	wipe(parked)
	for index, chatFrame in ipairs(FCFDock_GetChatFrames(dock)) do
		if IsParked(chatFrame) then
			Park(TabOf(chatFrame))
		else
			table.insert(entries, {
				tab = TabOf(chatFrame),
				key = rank[chatFrame:GetID()] or (10000 + (chatFrame.isStaticDocked and 0 or 1000) + index),
				temporary = chatFrame.isTemporary,
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.key < b.key
	end)
	wipe(tabs)
	wipe(temporary)
	for _, entry in ipairs(entries) do
		table.insert(tabs, entry.tab)
		temporary[entry.tab] = entry.temporary or nil
	end

	local present = {}
	for _, tab in ipairs(tabs) do
		present[tab] = true
		Adopt(tab)
	end
	for item in pairs(currentX) do
		if item ~= addButton and not present[item] then
			currentX[item], targetX[item] = nil, nil
		end
	end
	-- A tab that left the dock gets Blizzard's drag back: it moves floating
	-- windows and docks them again.
	for tab in pairs(undraggable) do
		if not present[tab] then
			tab:RegisterForDrag("LeftButton")
			undraggable[tab] = nil
		end
	end
	UpdateDragRegistration()
	if reorder and not present[reorder.tab] then
		reorder = nil
	end
end

-- The tab under the mouse's span along the header, where it's in view: in a
-- theme without a frame its stretch of the line lights up (Skin.lua).
local function UpdateHover()
	local x = hoveredTab and targetX[hoveredTab] and (currentX[hoveredTab] or 0) - scroll
	if reorder or drag or not x then
		ns.Skin.SetHeaderHover(nil)
		return
	end
	ns.Skin.SetHeaderHover(math.max(x, 0), math.min(x + hoveredTab:GetWidth(), viewport))
end

-- A tab under the mouse or not (Tabs.lua; never the open one).
function Header.SetHovered(tab, hovered)
	if hovered then
		hoveredTab = tab
	elseif hoveredTab == tab then
		hoveredTab = nil
	else
		return
	end
	UpdateHover()
end

-- The tab cut at the strip's right end: its name fades out over the last
-- stretch before the strip's end (Tabs.SetNameFade draws it, from and to
-- along the tab from its left edge). `cutNames` holds the tabs whose names
-- fade, by the pass that last saw them.
local cutNames, cutPass = {}, 0

local function FadeCutNames()
	cutPass = cutPass + 1
	local zone = (maxScroll - scroll > SETTLE) and viewport - OVERFLOW_FADE
	for _, tab in ipairs(tabs) do
		local x = (reorder and reorder.tab == tab) and reorder.x or (currentX[tab] or 0) - scroll
		if zone and x + tab:GetWidth() > zone and x < viewport then
			ns.Tabs.SetNameFade(tab, zone - x, viewport - x)
			cutNames[tab] = cutPass
		elseif cutNames[tab] then
			ns.Tabs.SetNameFade(tab, nil)
			cutNames[tab] = nil
		end
	end
	-- A tab gone from the strip (undocked, closed) shows its name whole.
	for tab, pass in pairs(cutNames) do
		if pass ~= cutPass then
			ns.Tabs.SetNameFade(tab, nil)
			cutNames[tab] = nil
		end
	end
end

local function ApplyPositions()
	for _, tab in ipairs(tabs) do
		local x
		if reorder and reorder.tab == tab then
			x = reorder.x
		else
			x = (currentX[tab] or 0) - scroll + StripInset()
		end
		tab:ClearAllPoints()
		tab:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, TabLift())
		-- At the strip's start its left side is the card's edge.
		ns.Tabs.SetLeftFoot(tab, x > StripInset())
	end
	if drag and drag.inBand then
		ghost:ClearAllPoints()
		ghost:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", drag.ghostX, TabLift())
	end
	if not pinned and currentX[addButton] then
		addButton:ClearAllPoints()
		addButton:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", currentX[addButton] - scroll + StripInset(), TabLift())
	end
	fadeLeft:SetShown(scroll > SETTLE)
	FadeCutNames()

	-- The header's line opens under the open tab where it's in view (the
	-- strip starts at the dock's left end and is `viewport` wide), so the tab
	-- stays open into the messages at rest too (Skin.lua's trim).
	local selectedFrame = FCFDock_GetSelectedWindow(dock)
	local selected = selectedFrame and TabOf(selectedFrame)
	local gapLeft, gapRight
	if selected and targetX[selected] then
		local x = (reorder and reorder.tab == selected) and reorder.x or (currentX[selected] or 0) - scroll
		gapLeft, gapRight = math.max(x, 0), math.min(x + selected:GetWidth(), viewport)
	end
	ns.Skin.SetHeaderGap(gapLeft, gapRight, viewport)
	UpdateHover()
end

-- Unread messages in tabs the strip doesn't show: a dot on the chevron (in
-- their color, gold when they're of several kinds), and the same dot on each
-- unread row of its list, which says which ones; picking one there selects it
-- as Blizzard's list always has. (The chevron lighting up in v0.31 didn't say
-- which; a mark at the strip's edge in v0.33 read as a stray pixel on the
-- card's corner.)
local function GetUnreadColor(tab)
	local color = ns.Alerts and ns.Alerts.GetColor(tab)
	-- Retail's UI no longer has it (12.1.5); Forever's still does.
	if not color and ChatFrameUtil.IsTabAlerting and ChatFrameUtil.IsTabAlerting(tab) then
		color = Theme.GOLD
	end
	return color
end

local function ShowMark(mark, color)
	if color then
		mark:Light(color)
	else
		mark:Clear()
	end
end

-- A row of Blizzard's list, as FCFDockOverflowListButton_SetValue fills it.
local function MarkListRow(button, chatFrame)
	local mark = listMarks[button]
	if not mark then
		mark = ns.Alerts.CreateMark(button)
		mark.dot:SetPoint("CENTER", button, "LEFT", LIST_DOT_X, 0)
		listMarks[button] = mark
		-- Blizzard's own flash under the row (whispers only) gives way to the
		-- dot; SetValue only recolors it, so an empty texture stays empty.
		button.glow:SetTexture(nil)
	end
	ShowMark(mark, GetUnreadColor(TabOf(chatFrame)))
end

-- At rest the chevron rests with the controls, or at full while a tab out of
-- view has unread messages, like those tabs' names (Tabs.lua).
local function ApplyChevronAlpha()
	if chevron then
		local rest = chevronAlerting and Theme.REST_ALERT or Theme.REST_CONTROLS
		chevron:SetAlpha(Theme.Rest(rest, chatLit))
	end
end

local function UpdatePulse()
	if not chevronMark then
		return
	end
	local hidden
	for _, tab in ipairs(tabs) do
		local x = targetX[tab]
		local color = x and GetUnreadColor(tab)
		if color then
			-- Where the tab's own dot sits, near its right end.
			local dotX = x + tab:GetWidth() - TAB_DOT_INSET
			if dotX < targetScroll or dotX > targetScroll + viewport then
				if hidden and (hidden.r ~= color.r or hidden.g ~= color.g or hidden.b ~= color.b) then
					color = Theme.GOLD
				end
				hidden = color
			end
		end
	end
	ShowMark(chevronMark, hidden)
	if chevronAlerting ~= (hidden ~= nil) then
		chevronAlerting = hidden ~= nil
		ApplyChevronAlpha()
	end
	for button, mark in pairs(listMarks) do
		if button:IsShown() and button.chatFrame then
			ShowMark(mark, GetUnreadColor(TabOf(button.chatFrame)))
		end
	end
end
Header.UpdatePulse = UpdatePulse

local function DismissScrollTip()
    local inventory = BaziUI.Inventory
    if inventory and not inventory.Settings().hideChatTabScrollGuide then
        inventory.Settings().hideChatTabScrollGuide = true
        inventory.RefreshFirstUseGuides()
    end
end

local function UpdateScrollTip()
    local inventory = BaziUI.Inventory
    if not inventory then return end
    local settings = inventory.Settings()
    if settings.hideChatTabScrollGuide == nil then
        settings.hideChatTabScrollGuide = not not ns.db.tipScrollShown
    end
    if maxScroll > 0 then
        inventory.ShowFirstUseGuide(strip, "hideChatTabScrollGuide", nil, L.tipScroll)
    else
        inventory.HideFirstUseGuide(strip, "hideChatTabScrollGuide")
    end
end

-- Lays the tabs out from `tabs` (with a gap where a dragged tab would land),
-- decides whether the strip overflows, and places the controls on the right.
-- `followSelection` scrolls the selected tab into view.
local function Arrange(followSelection)
	local dockWidth = dock:GetWidth()
	-- Not laid out yet (e.g. while the game window resizes).
	if not dockWidth or dockWidth <= 0 then
		return
	end

	local gapIndex, gapWidth
	if reorder then
		gapIndex, gapWidth = reorder.index, reorder.width
	elseif drag and drag.inBand and drag.index then
		gapIndex, gapWidth = drag.index, drag.width
	end
	local x, position = 0, 0
	for _, tab in ipairs(tabs) do
		if not (reorder and reorder.tab == tab) then
			position = position + 1
			if position == gapIndex then
				x = x + gapWidth + TAB_GAP
			end
			targetX[tab] = x
			currentX[tab] = currentX[tab] or x
			x = x + tab:GetWidth() + TAB_GAP
		end
	end
	if gapIndex and gapIndex > position then
		x = x + gapWidth + TAB_GAP
	end
	contentWidth = math.max(0, x - TAB_GAP)

	-- From the right: the free space that moves the chat (its grip at the
	-- end), then, while the strip overflows, the chevron and the "+" together;
	-- otherwise the "+" follows the last tab.
	addButton:SetShown(not ns.db.hideButtons)
	local addWidth = ns.db.hideButtons and 0 or addButton:GetWidth()
	pinned = contentWidth + ADD_GAP + addWidth + ADD_GAP + TITLE_BAR_MIN > dockWidth - BUTTON_INSET

	-- A pixel above the header too: the active tab's dark outline (Tabs.lua)
	-- sits just outside it.
	strip:ClearAllPoints()
	strip:SetPoint("TOPLEFT", dock, "TOPLEFT", -StripInset(), PixelUtil.ConvertPixelsToUIForRegion(1, dock) + TabLift())
	strip:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT")
	dock.overflowButton:SetShown(pinned)
	titleBar:ClearAllPoints()
	titleBar:SetPoint("TOPLEFT", addButton, "TOPRIGHT", ADD_GAP, 0)
	titleBar:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT")
	if pinned then
		dock.overflowButton:ClearAllPoints()
		dock.overflowButton:SetPoint("RIGHT", dock, "RIGHT", -TITLE_BAR_MIN, 0)
		addButton:ClearAllPoints()
		addButton:SetPoint("RIGHT", dock.overflowButton, "LEFT", -BUTTON_GAP, TabLift())
		strip:SetPoint("RIGHT", addButton, "LEFT", -OVERFLOW_GAP, 0)
		titleBar:ClearAllPoints()
		titleBar:SetPoint("TOPLEFT", dock.overflowButton, "TOPRIGHT", 0, (Theme.HEADER_HEIGHT - BUTTON_SIZE) / 2)
		titleBar:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT")
		viewport = dockWidth - (TITLE_BAR_MIN + BUTTON_SIZE + BUTTON_GAP + addWidth + OVERFLOW_GAP)
		currentX[addButton], targetX[addButton] = nil, nil
	else
		strip:SetPoint("RIGHT", dock, "RIGHT", -BUTTON_INSET, 0)
		viewport = dockWidth - BUTTON_INSET
		targetX[addButton] = contentWidth + ADD_GAP
		currentX[addButton] = currentX[addButton] or targetX[addButton]
	end
	maxScroll = math.max(0, contentWidth - viewport)
	UpdateScrollTip()
	PlaceGrip()

	if followSelection then
		local selectedFrame = FCFDock_GetSelectedWindow(dock)
		local selected = selectedFrame and TabOf(selectedFrame)
		if selected and targetX[selected] then
			local left = targetX[selected] - REVEAL_MARGIN
			local right = targetX[selected] + selected:GetWidth() + REVEAL_MARGIN
			if left < targetScroll then
				targetScroll = left
			elseif right > targetScroll + viewport then
				targetScroll = right - viewport
			end
		end
	end
	targetScroll = Clamp(targetScroll, 0, maxScroll)

	-- Anchors set now, so Blizzard's own layout never shows for a frame.
	ApplyPositions()
	UpdatePulse()
	Run()
end

-- Where a dragged tab goes, among the tabs other than `skip`: in front of the
-- first one whose middle is right of the cursor (Blizzard's own rule), else
-- last. Uses the tabs' rects as they slide, the way the player sees them.
local function InsertIndex(cursorX, skip)
	local position = 0
	for _, tab in ipairs(tabs) do
		if tab ~= skip then
			position = position + 1
			local left, right = tab:GetLeft(), tab:GetRight()
			if left and right and cursorX < (left + right) / 2 then
				return position
			end
		end
	end
	return position + 1
end

-- Near either end of an overflowing strip, a drag scrolls it.
local function AutoScroll(cursorX, stripLeft, elapsed)
	if maxScroll <= 0 then
		return
	end
	if cursorX < stripLeft + AUTO_SCROLL_EDGE then
		targetScroll = Clamp(targetScroll - AUTO_SCROLL_SPEED * elapsed, 0, maxScroll)
	elseif cursorX > stripLeft + viewport - AUTO_SCROLL_EDGE then
		targetScroll = Clamp(targetScroll + AUTO_SCROLL_SPEED * elapsed, 0, maxScroll)
	end
end

local function StartReorder(tab)
	local cursorX = CursorX()
	local position = 0
	for _, other in ipairs(tabs) do
		if other == tab then
			break
		end
		position = position + 1
	end
	reorder = {
		tab = tab,
		width = tab:GetWidth(),
		grab = cursorX - (tab:GetLeft() or cursorX),
		x = (tab:GetLeft() or 0) - (strip:GetLeft() or 0),
		index = position + 1,
	}
	-- Above the others while it travels, without its tooltip.
	tab:SetFrameLevel(strip:GetFrameLevel() + DRAGGED_LEVEL)
	ns.Links.HideSmallTip(tab)
	Arrange(false)
end

FinishReorder = function()
	local tab, index = reorder.tab, reorder.index
	-- Slides from where it was dropped into its place.
	currentX[tab] = reorder.x + scroll
	reorder = nil
	tab:SetFrameLevel(strip:GetFrameLevel() + TAB_LEVEL)
	tDeleteItem(tabs, tab)
	table.insert(tabs, math.min(index, #tabs + 1), tab)
	SaveOrder()
	Arrange(false)
end

local function UpdateReorder(elapsed)
	if not IsMouseButtonDown("LeftButton") then
		FinishReorder()
		return
	end
	local cursorX = CursorX()
	local stripLeft = strip:GetLeft() or 0
	local inset = StripInset()
	reorder.x = Clamp(cursorX - reorder.grab - stripLeft, inset, math.max(inset, viewport + inset - reorder.width))
	AutoScroll(cursorX, stripLeft, elapsed)
	local index = InsertIndex(cursorX, reorder.tab)
	if index ~= reorder.index then
		reorder.index = index
		Arrange(false)
	end
end

-- Shows or hides a floating window being dragged without touching its
-- visibility, which Blizzard manages. The combat log's filter bar hangs from
-- its tab rather than the window, so it goes along.
local function ShowWindow(chatFrame, shown)
	chatFrame:SetAlpha(shown and 1 or 0)
	if chatFrame.CombatLogQuickButtonFrame then
		chatFrame.CombatLogQuickButtonFrame:SetAlpha(shown and ns.Skin.OpenTabAlpha(chatFrame) or 0)
	end
end

local function StashTab(tab)
	tab:ClearAllPoints()
	tab:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
end

-- Blizzard's drag handler ran (a floating window, or a docked tab dragged with
-- Shift): the window is undocked and following the cursor.
OnTabDragStart = function(tab)
	-- Blizzard hides its tooltip here; ours goes too.
	ns.Links.HideSmallTip(tab)
	local chatFrame = _G["ChatFrame" .. tab:GetID()]
	if drag or MOVING_CHATFRAME ~= chatFrame then
		return
	end
	local width = tab:GetWidth()
	ghost:SetWidth(width)
	ghost.text:SetText(tab:GetText())
	ns.Tabs.SetFillColor(ghost, ns.Skin.BodyColor(chatFrame))
	local cursorX = CursorX()
	drag = {
		chatFrame = chatFrame,
		tab = tab,
		width = width,
		grab = cursorX - (tab:GetLeft() or cursorX),
		ghostX = 0,
	}
	Run()
end

local function EndDrag()
	local chatFrame, tab = drag.chatFrame, drag.tab
	local inBand, ghostX, index = drag.inBand, drag.ghostX, drag.index
	drag = nil
	ghost:Hide()
	ShowWindow(chatFrame, true)
	if chatFrame.isDocked then
		-- Blizzard docked it in its own order; the strip shows it where the
		-- gap was, and slides it on from where the ghost was.
		if index then
			tDeleteItem(tabs, tab)
			table.insert(tabs, math.min(index, #tabs + 1), tab)
			SaveOrder()
		end
		if inBand then
			currentX[tab] = ghostX + scroll
		end
	else
		Forget(chatFrame:GetID())
		if inBand then
			-- Dropped outside after all: the tab goes back onto its window.
			ns.Tabs.AlignTab(chatFrame, 0)
		end
	end
	Arrange(true)
end

local function UpdateDrag(elapsed)
	local chatFrame = drag.chatFrame
	if MOVING_CHATFRAME ~= chatFrame then
		EndDrag()
		return
	end

	-- Blizzard's own drop test, so the preview and the drop always agree.
	local inBand = dock:IsMouseOver(10, -10, 0, 10)
	if inBand ~= drag.inBand then
		drag.inBand = inBand
		if inBand then
			ShowWindow(chatFrame, false)
			StashTab(drag.tab)
			ghost:Show()
		else
			ShowWindow(chatFrame, true)
			ns.Tabs.AlignTab(chatFrame, 0)
			ghost:Hide()
			drag.index = nil
			Arrange(false)
		end
	end
	if not inBand then
		return
	end

	local cursorX = CursorX()
	local stripLeft = strip:GetLeft() or 0
	local inset = StripInset()
	drag.ghostX = Clamp(cursorX - drag.grab - stripLeft, inset, math.max(inset, viewport + inset - drag.width))
	AutoScroll(cursorX, stripLeft, elapsed)
	local index = InsertIndex(cursorX)
	if index ~= drag.index then
		drag.index = index
		Arrange(false)
	end
end

function Header.Tick(_, elapsed)
	if press and not reorder then
		if not IsMouseButtonDown("LeftButton") then
			press = nil
		elseif math.abs(CursorX() - press.x) > DRAG_THRESHOLD then
			local tab = press.tab
			press = nil
			if targetX[tab] then
				StartReorder(tab)
			end
		end
	end
	if reorder then
		UpdateReorder(elapsed)
	end
	if drag then
		UpdateDrag(elapsed)
	end

	local settled = true
	scroll = Approach(scroll, targetScroll, 1 - math.exp(-SCROLL_SPEED * elapsed))
	if scroll ~= targetScroll then
		settled = false
	end
	local factor = 1 - math.exp(-SLIDE_SPEED * elapsed)
	local function Slide(item)
		local target = targetX[item]
		if target and currentX[item] then
			currentX[item] = Approach(currentX[item], target, factor)
			if currentX[item] ~= target then
				settled = false
			end
		end
	end
	for _, tab in ipairs(tabs) do
		Slide(tab)
	end
	if not pinned then
		Slide(addButton)
	end
	ApplyPositions()

	if settled and not (press or reorder or drag) then
		driver:SetScript("OnUpdate", nil)
		UpdatePulse()
	end
end

-- Blizzard's dock was updated: a window was selected, added, closed, docked,
-- renamed or resized.
-- What the strip last laid out: the docked windows in order and the selected
-- one.
local lastDocked, lastSelected

-- Whether Blizzard's update changed anything: its real updates put the tabs
-- back in its own frames (the dock, its scroll child). Calls that changed
-- nothing come every frame while Blizzard's dock OnUpdate retries
-- FCFDockScrollFrame_JumpToTab, which keeps failing in some states (an
-- alerting tab without a valid rect); laying out and revealing the selected
-- tab on each of those fought the mouse wheel.
local function DockChanged()
	local names = {}
	for _, chatFrame in ipairs(FCFDock_GetChatFrames(dock)) do
		table.insert(names, chatFrame:GetName())
		if TabOf(chatFrame):GetParent() ~= (IsParked(chatFrame) and parking or strip) then
			return true
		end
	end
	local docked = table.concat(names, ",")
	if docked ~= lastDocked then
		lastDocked = docked
		return true
	end
	return false
end

-- `force`: something only Everchat knows changed (a tab's name).
local function OnDockUpdated(force)
	local selected = FCFDock_GetSelectedWindow(dock)
	local selectionChanged = selected ~= lastSelected
	local dockChanged = DockChanged()
	if not (dockChanged or selectionChanged or force) then
		return
	end
	lastSelected = selected
	Collect()
	if dockChanged or force then
		TabsChanged()
	end
	-- The dragged window docked (the drop went through Blizzard's update).
	if drag and drag.tab:GetParent() == strip then
		EndDrag()
	else
		-- Only a new selection is scrolled into view, so the wheel isn't undone.
		Arrange(selectionChanged)
	end
end

-- The combat log's tab shown or hidden (its tab menu, the options).
function Header.SetCombatLogHidden(hidden)
	ns.db.hideCombatLogTab = not not hidden
	Header.Relayout()
end

function Header.IsCombatLogHidden()
	return ns.db.hideCombatLogTab ~= false
end

-- Something that changes the tabs' widths outside the dock (the options'
-- font switch): sized and laid out again.
function Header.Relayout()
	if dock then
		OnDockUpdated(true)
	end
end

-- Like the "+": brighter with a soft glow behind it under the mouse or while
-- its list is open.
local function UpdateChevron()
	if not chevron then
		return
	end
	local open = dock.overflowButton.list:IsShown()
	local lit = open or chevronHovered
	Theme.PaintArt(chevron, lit and 1 or Theme.ICON_REST, (lit and Theme.GLYPH_HOVER or Theme.GLYPH).a)
	chevronBack:SetShown(lit)
	chevronBack:SetAlpha(open and Theme.GLOW_OPEN_ALPHA or Theme.GLOW_HOVER_ALPHA)
end

-- Blizzard's list of docked windows, in the strip's order. Only its buttons'
-- anchors change (the same offsets FCFDockOverflowList_Update uses).
local function OrderList(list)
	local position = {}
	for index, tab in ipairs(tabs) do
		position[tab:GetID()] = index
	end
	local buttons = {}
	for _, button in ipairs(list.buttons) do
		if button:IsShown() and button.chatFrame then
			if parked[TabOf(button.chatFrame)] then
				-- A hidden tab isn't listed either (the list's height and
				-- count as Blizzard's would be without it).
				button:Hide()
				list:SetHeight(list:GetHeight() - button:GetHeight() - 3)
			else
				table.insert(buttons, button)
			end
		end
	end
	list.numTabs:SetFormattedText(CHAT_WINDOWS_COUNT, #buttons)
	table.sort(buttons, function(a, b)
		return (position[a.chatFrame:GetID()] or math.huge) < (position[b.chatFrame:GetID()] or math.huge)
	end)
	for index, button in ipairs(buttons) do
		button:ClearAllPoints()
		if index == 1 then
			button:SetPoint("TOPLEFT", list, "TOPLEFT", 5, -19)
		else
			button:SetPoint("TOPLEFT", buttons[index - 1], "BOTTOMLEFT", 0, -3)
		end
	end
end

-- Blizzard's button stays the thing that's clicked (its list selects windows
-- securely); Everchat swaps its art for a chevron and opens the list down
-- into the chat instead of out to the side.
local function StyleChevron()
	local button = dock.overflowButton
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	-- Blizzard's arrow and its highlight (which Blizzard also flashes and
	-- recolors on UPDATE_CHAT_COLOR, bringing it back) give way to ours: the
	-- highlight's texture is emptied, so nothing it does to it shows.
	button:GetNormalTexture():SetAlpha(0)
	button:GetHighlightTexture():SetTexture(nil)

	chevronBack = ns.Shapes.Glow(button)
	chevronBack:SetPoint("CENTER")
	chevronBack:SetIgnoreParentAlpha(true)

	chevron = button:CreateTexture(nil, "ARTWORK")
	chevron:SetTexture(CHEVRON_ICON)
	local chevronSize = ns.Shapes.ArtPixels(chevron, Theme.ICON_PIXELS)
	chevron:SetSize(chevronSize, chevronSize)
	chevron:SetPoint("CENTER")
	-- Blizzard fades the button itself; ApplyAlpha fades it with the "+".
	chevron:SetIgnoreParentAlpha(true)
	chevron:SetAlpha(Theme.REST_CONTROLS)

	button:HookScript("OnEnter", function()
		chevronHovered = true
		UpdateChevron()
	end)
	button:HookScript("OnLeave", function()
		chevronHovered = false
		UpdateChevron()
	end)
	chevronMark = ns.Alerts.CreateMark(button)
	chevronMark.dot:SetPoint("CENTER", chevron, "TOPRIGHT", CHEVRON_DOT_X, CHEVRON_DOT_Y)

	button.list:HookScript("OnShow", UpdateChevron)
	button.list:HookScript("OnHide", UpdateChevron)
	UpdateChevron()
	-- A new theme: the chevron in its metal.
	Theme.OnChanged(UpdateChevron)

	-- Above the messages (the chat frame shares the dock's strata).
	button.list:SetFrameStrata("DIALOG")
	button.list:ClearAllPoints()
	button.list:SetPoint("TOPRIGHT", dock, "BOTTOMRIGHT", -LIST_INSET, -LIST_INSET)
end

-- The mouse wheel anywhere on the header scrolls the tabs; it's taken even
-- when there's nothing to scroll, so it never falls through to the game's own
-- bindings (Shift+wheel turns the main action bar's page, the wheel zooms the
-- camera).
local function OnHeaderWheel(_, delta)
	if maxScroll > 0 then
		DismissScrollTip()
		targetScroll = Clamp(targetScroll - delta * WHEEL_STEP, 0, maxScroll)
		Run()
	end
end

-- The shading's color: the header's as painted (the shown window's
-- Background setting, Skin.lua), at the header's fade, which a gradient
-- carries in its colors (Shapes.SetGradient).
local fadeSolid = CreateColor(Theme.HEADER.r, Theme.HEADER.g, Theme.HEADER.b, 1)
local fadeClear = CreateColor(Theme.HEADER.r, Theme.HEADER.g, Theme.HEADER.b, 0)
local fadeAlpha = 1

local function PaintFades()
	if fadeLeft then
		ns.Shapes.SetGradient(fadeLeft, "HORIZONTAL", fadeSolid, fadeClear, fadeAlpha)
	end
end

function Header.SetFadeColor(r, g, b)
	fadeSolid:SetRGBA(r, g, b, 1)
	fadeClear:SetRGBA(r, g, b, 0)
	PaintFades()
end

-- The chat's fade (Skin.lua): the controls rest with the open tab (the
-- chevron at full while it flags unread messages), and the edge shading takes
-- the header's color and alpha as painted, which at rest are the message
-- area's.
function Header.ApplyAlpha(lit, r, g, b, shadeAlpha)
	chatLit = lit
	ApplyChevronAlpha()
	if chevronMark then
		chevronMark:SetFade(Theme.Rest(1, lit))
	end
	if chevron then
		fadeAlpha = shadeAlpha
		Header.SetFadeColor(r, g, b)
	end
	if titleGrip then
		titleGrip:SetAlpha(Theme.Rest(Theme.REST_CONTROLS, lit))
	end
	ns.NewTab.ApplyAlpha(lit)
end

local function CreateStrip()
	strip = CreateFrame("Frame", nil, dock)
	strip:SetClipsChildren(true)
	strip:SetScript("OnSizeChanged", function()
		Arrange(true)
	end)

	-- Shading over the clipped tabs at either edge, in the header's color:
	-- the header only, without the strip's pixel above it, and above the
	-- line along its bottom (Skin.lua's trim, two rows), which runs on
	-- under the clipped tabs (shaded, it looked cut there).
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, dock)
	fades = CreateFrame("Frame", nil, strip)
	fades:SetPoint("TOPLEFT", dock, "TOPLEFT")
	fades:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 2 * px)
	fades:SetFrameLevel(strip:GetFrameLevel() + FADE_LEVEL)
	fadeLeft = fades:CreateTexture(nil, "OVERLAY")
	fadeLeft:SetPoint("TOPLEFT")
	fadeLeft:SetPoint("BOTTOMLEFT")
	fadeLeft:SetWidth(EDGE_FADE)
	fadeLeft:SetColorTexture(1, 1, 1, 1)
	PaintFades()

	ghost = ns.Tabs.CreateGhost(strip)
	ghost:SetFrameLevel(strip:GetFrameLevel() + GHOST_LEVEL)

	driver = CreateFrame("Frame")
end

-- The header's free space, from just after the "+" (which follows the last
-- tab, eased) to the header's right end or the chevron, never narrower than
-- TITLE_BAR_MIN: dragging it moves the chat, like a window's title bar. No
-- marks; a tooltip says what it does. Below the tabs, the "+" and the
-- chevron, so they keep their own clicks. (Arrange anchors it.) A
-- Shift-click on it locks the chat (Resize.lua): its grip goes, shows off
-- under the mouse, and lights while Shift is held over the chat, to move it
-- anyway or unlock it the same way.
local function ShowTitleBarTip(self)
	-- It would go over the padlock, which stands right above; it waits.
	if ns.Padlock.IsPlaying() then
		return
	end
	local lines
	if InCombatLockdown() then
		lines = { { L.moveCombat, HIGHLIGHT_FONT_COLOR, true } }
	elseif ns.Resize.IsLocked() then
		lines = {
			{ L.lockedChat, HIGHLIGHT_FONT_COLOR, true },
			{ L.lockShiftMove, GREEN_FONT_COLOR, true },
			{ L.lockShiftUnlock, GREEN_FONT_COLOR, true },
		}
	else
		lines = { { L.moveHint, HIGHLIGHT_FONT_COLOR, true }, { L.lockClick, GREEN_FONT_COLOR, true } }
	end
	ns.Links.ShowSmallTip(self, "ANCHOR_TOP", lines)
end

-- The locked grip under the mouse: grey, at the strength design systems give
-- a disabled control (Material's 38%).
local GRIP_OFF_ALPHA = 0.38
local GAME_GRIP_OFF_ALPHA = 0.6
-- The game's gold made grey, as Everchat's grip is (desaturated).
local GAME_GRIP_OFF_GREY = 0.78

-- The grip sits on the axis of the scroll bar below it (its arrows, its bar,
-- the button to the end), so the chat's right edge reads as one column, on
-- whole pixels. The distance holds while the chat moves or resizes: it's
-- measured again only when the interface's scale changes.
local gripOffset, placedOffset

-- Where the grip stands, from the free space's right end (Padlock.lua).
function Header.GripAxis()
	return gripOffset or -TITLE_BAR_MIN / 2
end

function PlaceGrip()
	if not titleGrip then
		return
	end
	if not gripOffset then
		local bar = DEFAULT_CHAT_FRAME.ScrollBar
		local center, right = bar and bar:GetCenter(), titleBar:GetRight()
		if center and right then
			local px = PixelUtil.ConvertPixelsToUIForRegion(1, titleBar)
			gripOffset = math.floor((center - right) / px + 0.5) * px
		end
	end
	local offset = gripOffset or -TITLE_BAR_MIN / 2
	if offset ~= placedOffset then
		placedOffset = offset
		titleGrip:ClearAllPoints()
		titleGrip:SetPoint("CENTER", titleBar, "RIGHT", offset, 0)
		-- On the header's middle, where the tabs' labels are, also while the
		-- free space starts lower (beside the chevron).
		gripLetter:SetPoint(dock, "BOTTOMRIGHT", offset, Theme.HEADER_HEIGHT / 2 + TabLift())
	end
end

local function CreateGrip()
	local grip = CreateFrame("Frame", nil, titleBar)
	local size = ns.Shapes.ArtPixels(grip, Theme.ICON_PIXELS)
	grip:SetSize(size, size)
	grip:SetPoint("CENTER", titleBar, "RIGHT", -TITLE_BAR_MIN / 2, 0)
	local icon = grip:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(GRIP_ICON)
	icon:SetAllPoints()
	local glow = ns.Shapes.Glow(grip)
	glow:SetPoint("CENTER")
	return grip, glow, icon
end

local function CreateTitleBar()
	titleBar = CreateFrame("Frame", nil, dock)
	titleBar:SetFrameLevel(dock:GetFrameLevel() + 1)
	titleBar:EnableMouse(true)
	local glow, icon
	titleGrip, glow, icon = CreateGrip()
	gripLetter = ns.Tabs.CreateLetterGlyph(titleGrip, "grip")
	gripLetter:SetPoint(dock, "BOTTOMRIGHT", -TITLE_BAR_MIN / 2, Theme.HEADER_HEIGHT / 2 + TabLift())
	local titleLit, hovered = false, false
	local function Light(lit)
		titleLit = lit
		local game = Theme.GAME_ART
		icon:SetShown(not game)
		gripLetter:SetShown(game)
		if game then
			glow:Hide()
			-- The colors of Everchat's own grip: a little darker gold at
			-- rest, lighter under the mouse, grey while locked (there at a
			-- disabled control's strength and only under the mouse; here it
			-- always shows, so stronger, with nothing else marking the spot).
			if not ns.Resize.ShowsGrips() then
				gripLetter:SetColor(GAME_GRIP_OFF_GREY, GAME_GRIP_OFF_GREY, GAME_GRIP_OFF_GREY, GAME_GRIP_OFF_ALPHA)
			else
				local color, shade = lit and Theme.GLYPH_HOVER or Theme.GLYPH, lit and 1 or Theme.ICON_REST
				gripLetter:SetColor(shade * color.r, shade * color.g, shade * color.b, 1)
			end
			return
		end
		-- Locked: the grip off, in grey at a disabled control's strength,
		-- without its glow (UpdateGrip shows it only under the mouse).
		if not ns.Resize.ShowsGrips() then
			icon:SetDesaturated(true)
			icon:SetVertexColor(1, 1, 1, GRIP_OFF_ALPHA)
			glow:Hide()
			return
		end
		Theme.PaintArt(icon, lit and 1 or Theme.ICON_REST, (lit and Theme.GLYPH_HOVER or Theme.GLYPH).a)
		glow:SetShown(lit)
		glow:SetAlpha(ns.Resize.IsMoving() and Theme.GLOW_OPEN_ALPHA or Theme.GLOW_HOVER_ALPHA)
	end
	-- Locked, the grip shows only under the mouse, off (the spot still says
	-- what it is), and lit while Shift makes it work (Resize.lua). With the
	-- game's art it always shows.
	local function UpdateGrip()
		titleGrip:SetShown(ns.Resize.ShowsGrips() or hovered or Theme.GAME_ART)
		Light(titleLit)
	end
	Light(false)
	-- A new theme: the grip in its metal, or as the tabs' letters.
	Theme.OnChanged(function()
		placedOffset = nil
		PlaceGrip()
		gripLetter:Layout()
		UpdateGrip()
	end)
	titleBar:SetScript("OnEnter", function(self)
		hovered = true
		Light(true)
		UpdateGrip()
		ShowTitleBarTip(self)
	end)
	titleBar:SetScript("OnLeave", function(self)
		hovered = false
		if not ns.Resize.IsMoving() then
			Light(false)
		end
		UpdateGrip()
		ns.Links.HideSmallTip(self)
	end)
	-- The lock or Shift changed: the grip and the tooltip follow.
	ns.Resize.OnLockChanged(function()
		UpdateGrip()
		if ns.Padlock.IsPlaying() then
			ns.Links.HideSmallTip(titleBar)
		elseif titleBar:IsMouseOver() and not ns.Resize.IsMoving() then
			ShowTitleBarTip(titleBar)
		end
	end)
	ns.Padlock.OnFinished(function()
		if titleBar:IsMouseOver() and not ns.Resize.IsMoving() then
			ShowTitleBarTip(titleBar)
		end
	end)
	UpdateGrip()
	local shiftClick = false
	titleBar:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			-- Only a Shift-click locks or unlocks, anywhere on the free space
			-- (where the tooltip says so): a plain click does nothing of the kind.
			shiftClick = IsShiftKeyDown()
			ns.Resize.StartMoving(self)
			if ns.Resize.IsMoving() then
				ns.Links.HideSmallTip(self)
				Light(true)
			end
		end
	end)
	-- A Shift-click that didn't move the chat locks it, or unlocks it.
	titleBar:SetScript("OnMouseUp", function(self, button)
		local moved = ns.Resize.StopMoving(self)
		Light(self:IsMouseOver())
		if button == "LeftButton" and shiftClick and not moved then
			ns.Resize.SetLocked(not ns.Resize.IsLocked(), true)
		end
		shiftClick = false
	end)
	titleBar:SetScript("OnHide", function(self)
		ns.Resize.StopMoving(self)
	end)
end

-- The mouse wheel anywhere on the header scrolls the tabs: one frame over
-- all of it (the tabs, the "+", the chevron, the gaps between them and the
-- free space) that takes only the wheel, so clicks and hovers go through to
-- whatever is below. Until 2026-10-10 the strip and the free space took it
-- each, and with the tabs overflowing, the gap, the "+" and the chevron let
-- it fall through to the game's bindings: Shift+wheel there (the usual
-- sideways scroll elsewhere) turned the main action bar's page.
local function CreateWheelCatcher()
	local wheel = CreateFrame("Frame", nil, dock)
	wheel:SetAllPoints(dock)
	wheel:SetFrameLevel(dock:GetFrameLevel() + WHEEL_LEVEL)
	wheel:EnableMouse(false)
	wheel:EnableMouseWheel(true)
	wheel:SetScript("OnMouseWheel", OnHeaderWheel)
end

function Header.Init()
	dock = GENERAL_CHAT_DOCK
	CreateStrip()
	parking = CreateFrame("Frame", nil, dock)
	parking:Hide()
	addButton = ns.NewTab.CreateButton(dock)
	CreateTitleBar()
	-- Whole pixels change with the interface scale or the resolution.
	local scaleEvents = CreateFrame("Frame")
	scaleEvents:RegisterEvent("UI_SCALE_CHANGED")
	scaleEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
	scaleEvents:SetScript("OnEvent", function()
		gripOffset = nil
		PlaceGrip()
	end)
	StyleChevron()
	CreateWheelCatcher()
	-- A drop a little further from the strip still docks, and Blizzard's own
	-- insertion marker stays out of sight: the gap shows the spot.
	dock:SetHitRectInsets(0, 0, -DRAG_BAND, -DRAG_BAND)
	dock.insertHighlight:SetAlpha(0)

	hooksecurefunc("FCFDock_UpdateTabs", function(updatedDock)
		if updatedDock == dock then
			OnDockUpdated()
		end
	end)
	-- Renaming resizes the tab but only marks the dock for a later update.
	hooksecurefunc("FCF_SetWindowName", function(chatFrame)
		if chatFrame.isDocked then
			OnDockUpdated(true)
		end
	end)
	hooksecurefunc("FCF_StartAlertFlash", UpdatePulse)
	hooksecurefunc("FCF_StopAlertFlash", UpdatePulse)
	hooksecurefunc("FCFDockOverflowList_Update", OrderList)
	hooksecurefunc("FCFDockOverflowListButton_SetValue", MarkListRow)
	-- A closed window gives its place up (its ID may come back as another).
	hooksecurefunc("FCF_Close", function(frame, fallback)
		local closed = fallback or frame or FCF_GetCurrentChatFrame()
		if closed then
			Forget(closed:GetID())
		end
	end)

	local events = CreateFrame("Frame")
	events:RegisterEvent("MODIFIER_STATE_CHANGED")
	events:SetScript("OnEvent", UpdateDragRegistration)

	-- Temporary windows never outlive a reload.
	local order = GetOrder()
	for index = #order, 1, -1 do
		if order[index] > Constants.ChatFrameConstants.MaxChatWindows then
			table.remove(order, index)
		end
	end
	OnDockUpdated(true)
end
