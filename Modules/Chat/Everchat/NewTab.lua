local ns = BaziUI.Chat
local Theme = ns.Theme

local NewTab = {}
ns.NewTab = NewTab

-- The header's "+" and its menu of ready-made tabs. Windows are created with
-- Blizzard's own functions (FCF_OpenNewWindow and the frame's message group
-- methods), the way the game's "New chat window" popup and ElvUI's chat setup
-- do. CLAUDE.md records what running them from addon code implies.

local BUTTON_WIDTH = 24
-- The "+": Everchat's own icon (art/add-icons.py), a gold cross of the
-- game's kind, at Theme.ICON_PIXELS. The game's thin plus (uitools-icon-plus)
-- read as a typed character, two thick rounded bars as crossed band-aids, and
-- a thin ring around a plus as any website's "add".
local ICON = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconAdd"

local MENU_WIDTH = 200
local MENU_PADDING = 10
local ROW_HEIGHT = 20
local ROW_INSET = 4
local SECTION_GAP = 6
local EDIT_HEIGHT = 22
-- InputBoxTemplate's border reaches 5px left of the text.
local EDIT_INSET = 6
-- The highlight Blizzard's list of docked windows uses.
local ROW_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
-- Blizzard's limit for chat window names (the NAME_CHAT popup).
local MAX_NAME_LETTERS = 31

-- Trade's zone channel (ChatChannels.db2); the client gives its localized name.
local TRADE_CHANNEL_ID = 2

local L = ns.L

local button, glyph, hover, letter

-- The header's fade (Theme.REST_CONTROLS at rest), and the chat's.
local glyphAlpha = 1
local menu, title, edit, note
local rows = {}
local hovered = false

-- Each preset copies its groups (the main window keeps showing them too).
local function GetPresets()
	local presets = {
		{ name = L.newTabGuild, groups = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT" } },
		{ name = L.newTabGroup, groups = { "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" } },
		{ name = L.newTabWhispers, groups = { "WHISPER", "BN_WHISPER" } },
	}
	-- Trade, while the player is in that channel (cities), like Blizzard's
	-- "Move to new window" for a channel.
	local trade = C_ChatInfo.GetChannelShortcutForChannelID(TRADE_CHANNEL_ID)
	if trade and trade ~= "" then
		local id = GetChannelName(trade)
		if id and id > 0 then
			table.insert(presets, { name = trade, groups = { "CHANNEL" }, channels = { trade } })
		end
	end
	table.insert(presets, { name = L.newTabLoot, groups = { "LOOT", "MONEY", "CURRENCY" } })
	-- The combat log's hidden tab comes back from here too (it isn't made:
	-- the game's window is always there), by the window's own name.
	if ns.Header.IsCombatLogHidden() and COMBATLOG then
		local name = GetChatWindowInfo(COMBATLOG:GetID())
		table.insert(presets, { name = name ~= "" and name or COMBAT_LOG, restore = true })
	end
	return presets
end

-- Whether a window with this name is open (docked or floating). A preset
-- that's open isn't listed: a second Guild tab would only repeat the first
-- (and greyed-out "Open" rows read as clutter). Selecting the open one instead isn't an option; selecting a tab must
-- stay Blizzard's code answering a click (CLAUDE.md).
local function IsOpen(name)
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local frame = _G["ChatFrame" .. id]
		if frame and (frame.isDocked or frame:IsShown()) and GetChatWindowInfo(id) == name then
			return true
		end
	end
	return false
end

-- Without a preset, the window shows what Blizzard's own new windows show.
local function Create(name, groups, channels)
	if not FCF_CanOpenNewWindow() then
		return
	end
	local frame = FCF_OpenNewWindow(name, groups ~= nil)
	if not frame then
		return
	end
	FCF_CopyChatSettings(frame, DEFAULT_CHAT_FRAME)
	for _, group in ipairs(groups or {}) do
		frame:AddMessageGroup(group)
	end
	for _, channel in ipairs(channels or {}) do
		frame:AddChannel(channel)
	end
	FCF_DockUpdate()
	menu:Hide()
end

-- Like the chevron: brighter with a soft glow behind it under the mouse or
-- while its menu is open (the icon in the theme's metal; the glyphs' alphas).
local function UpdateButton()
	local lit = hovered or (menu and menu:IsShown())
	Theme.PaintArt(glyph, lit and 1 or Theme.ICON_REST)
	glyph:SetAlpha(glyphAlpha * (lit and Theme.GLYPH_HOVER or Theme.GLYPH).a)
	-- With the game's art, a "+" drawn as the tabs' letters are (Tabs.lua), in
	-- their gold, lighter under the mouse, with no glow.
	local game = Theme.GAME_ART
	glyph:SetShown(not game)
	letter:SetShown(game)
	if game then
		local color = lit and Theme.GLYPH_HOVER or Theme.TAB_TEXT
		letter:SetColor(color.r, color.g, color.b, glyphAlpha)
	end
	hover:SetShown(lit and not game)
	hover:SetAlpha(menu and menu:IsShown() and Theme.GLOW_OPEN_ALPHA or Theme.GLOW_HOVER_ALPHA)
end

-- What it does, in Everchat's small tooltip; not over its open menu.
local function ShowTooltip()
	ns.Links.ShowSmallTip(button, "ANCHOR_TOP", { { L.newTabTitle, HIGHLIGHT_FONT_COLOR } })
end

local function HideTooltip()
	ns.Links.HideSmallTip(button)
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, menu)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("RIGHT", menu, "RIGHT", -(MENU_PADDING - ROW_INSET), 0)
	row:SetHighlightTexture(ROW_HIGHLIGHT, "ADD")

	local label = row:CreateFontString(nil, "ARTWORK")
	label:SetPoint("LEFT", ROW_INSET, 0)
	label:SetPoint("RIGHT", -ROW_INSET, 0)
	row:SetFontString(label)
	row:SetNormalFontObject(GameFontHighlightLeft)
	row:SetHighlightFontObject(GameFontNormalLeft)
	row:SetDisabledFontObject(GameFontDisableLeft)

	row:SetScript("OnClick", function(self)
		Theme.PlaySound("check")
		if self.preset.restore then
			ns.Header.SetCombatLogHidden(false)
			ns.Alerts.NotifySwitchChanged()
			menu:Hide()
			return
		end
		Create(self.preset.name, self.preset.groups, self.preset.channels)
	end)
	rows[index] = row
	return row
end

-- The rows follow what's available right now (Trade comes and goes).
local function Refresh()
	local free = FCF_CanOpenNewWindow()
	-- Only what can be added: a preset whose tab is open isn't listed.
	local presets = {}
	for _, preset in ipairs(GetPresets()) do
		if preset.restore or not IsOpen(preset.name) then
			table.insert(presets, preset)
		end
	end
	local previous = title
	for index, preset in ipairs(presets) do
		local row = rows[index] or CreateRow(index)
		row.preset = preset
		row:SetText(preset.name)
		row:SetEnabled(free or preset.restore)
		row:ClearAllPoints()
		row:SetPoint("RIGHT", menu, "RIGHT", -(MENU_PADDING - ROW_INSET), 0)
		if previous == title then
			row:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -ROW_INSET, -SECTION_GAP)
		else
			row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
		end
		row:Show()
		previous = row
	end
	for index = #presets + 1, #rows do
		rows[index]:Hide()
	end

	edit:SetEnabled(free)
	edit:ClearAllPoints()
	-- Rows sit ROW_INSET out from the title's column.
	local inset = previous == title and EDIT_INSET or ROW_INSET + EDIT_INSET
	edit:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", inset, -SECTION_GAP)
	edit:SetPoint("RIGHT", menu, "RIGHT", -MENU_PADDING, 0)
	note:SetShown(not free)

	-- Tall enough for everything, whatever the font sizes.
	local last = free and edit or note
	local top, bottom = menu:GetTop(), last:GetBottom()
	if top and bottom then
		menu:SetHeight(top - bottom + MENU_PADDING)
	end
end

-- Whether the mouse is on a button that takes clicks (the game's buttons make
-- their own sound).
local function OnButton()
	for _, focus in ipairs(GetMouseFoci()) do
		if not focus:IsForbidden() and focus:IsObjectType("Button") and focus:IsEnabled() then
			return true
		end
	end
	return false
end

local function CreateMenu()
	-- The same tooltip frame as Blizzard's list of docked windows.
	menu = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:SetSize(MENU_WIDTH, 1)
	menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -ROW_INSET)
	menu:Hide()

	title = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	title:SetPoint("TOPLEFT", MENU_PADDING, -MENU_PADDING)
	title:SetPoint("RIGHT", -MENU_PADDING, 0)
	title:SetText(L.newTabTitle)

	-- Any other name: what Blizzard's own new windows show.
	edit = CreateFrame("EditBox", nil, menu, "InputBoxTemplate")
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(MAX_NAME_LETTERS)
	edit:SetHeight(EDIT_HEIGHT)
	local placeholder = edit:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	placeholder:SetPoint("LEFT", 0, 0)
	placeholder:SetPoint("RIGHT", 0, 0)
	placeholder:SetText(L.newTabOther)
	local function UpdatePlaceholder()
		placeholder:SetShown(edit:GetText() == "" and not edit:HasFocus())
	end
	edit:HookScript("OnTextChanged", UpdatePlaceholder)
	edit:HookScript("OnEditFocusGained", UpdatePlaceholder)
	edit:HookScript("OnEditFocusLost", UpdatePlaceholder)
	edit:SetScript("OnEnterPressed", function(self)
		local name = strtrim(self:GetText())
		if name ~= "" then
			Theme.PlaySound("check")
			Create(name)
		end
	end)

	note = menu:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetJustifyH("LEFT")
	note:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -EDIT_INSET, -SECTION_GAP)
	note:SetPoint("RIGHT", -MENU_PADDING, 0)
	note:SetText(L.newTabFull)

	-- Heard like the game's dropdowns: a click as it opens, its entries click
	-- when picked, and a lower click as it closes, from the "+" or from a click
	-- elsewhere. A button there (a chat tab, the chevron) clicks on its own, so
	-- the menu stays quiet then, and when a pick closes it.
	menu:SetScript("OnShow", function(self)
		Theme.PlaySound("check")
		Refresh()
		-- Clicking anywhere else closes it, like a menu.
		self:RegisterEvent("GLOBAL_MOUSE_DOWN")
		UpdateButton()
	end)
	menu:SetScript("OnHide", function(self)
		self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		edit:SetText("")
		edit:ClearFocus()
		UpdateButton()
	end)
	menu:SetScript("OnEvent", function(self)
		if not self:IsMouseOver() and not button:IsMouseOver() then
			if not OnButton() then
				Theme.PlaySound("uncheck")
			end
			self:Hide()
		end
	end)
end

-- The "+" after the last tab (or next to the chevron); the header places it.
function NewTab.CreateButton(parent)
	button = CreateFrame("Button", nil, parent)
	button:SetSize(BUTTON_WIDTH, Theme.HEADER_HEIGHT)
	button:SetFrameLevel(parent:GetFrameLevel() + 5)

	-- A soft glow behind the glyph under the mouse, like the chevron's.
	hover = ns.Shapes.Glow(button)
	hover:SetPoint("CENTER")

	-- In whole screen pixels, so the art's pixels land on the screen's (the
	-- 32px texture halves cleanly at 1x).
	glyph = button:CreateTexture(nil, "ARTWORK")
	glyph:SetTexture(ICON)
	glyph:SetPoint("CENTER")
	local size = ns.Shapes.ArtPixels(glyph, Theme.ICON_PIXELS)
	glyph:SetSize(size, size)
	glyphAlpha = Theme.REST_CONTROLS
	-- Centered on the header like the tabs' names.
	letter = ns.Tabs.CreateLetterGlyph(button, "plus")
	letter:SetPoint(button, "CENTER")

	button:SetScript("OnEnter", function()
		hovered = true
		UpdateButton()
		if not (menu and menu:IsShown()) then
			ShowTooltip()
		end
	end)
	button:SetScript("OnLeave", function()
		hovered = false
		UpdateButton()
		HideTooltip()
	end)
	button:SetScript("OnClick", function()
		if not menu then
			CreateMenu()
		end
		HideTooltip()
		if menu:IsShown() then
			Theme.PlaySound("uncheck")
		end
		menu:SetShown(not menu:IsShown())
	end)
	UpdateButton()
	-- A new theme: the "+" in its metal, or as the tabs' letters.
	Theme.OnChanged(function()
		letter:Layout()
		UpdateButton()
	end)
	return button
end

function NewTab.ApplyAlpha(lit)
	if glyph then
		glyphAlpha = Theme.Rest(Theme.REST_CONTROLS, lit)
		UpdateButton()
	end
end
