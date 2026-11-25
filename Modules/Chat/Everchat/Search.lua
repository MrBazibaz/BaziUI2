local ns = BaziUI.Chat
local Theme = ns.Theme

local Search = {}
ns.Search = Search

-- Finding a line in the chat, in place (the user wanted it without another
-- window and in as few steps as possible): the rail's magnifier opens a
-- field at the top of the window on show, sliding in like a browser's find
-- bar, and as you type the window shows only the lines of that tab that
-- contain the text, newest at the bottom, the matches in gold. The field
-- stays open and keeps its text across tab switches (typed in the wrong
-- tab, switch and it's still there), filtering the new tab; Esc or the
-- cross closes it. Blizzard's own lines are hidden meanwhile (their
-- container, a child frame, and Channels' crests) and shown again on close;
-- the results are a ScrollingMessageFrame of our own with the chat's font,
-- so links still work: clicks go to the game's own handler (SetItemRef, as
-- the chat does) and hovers to Links.lua's tooltips. Searching touches no
-- Blizzard state beyond hiding and showing that container.
local FIELD_INSET = 6
local FIELD_TOP = 5
local ICON_SIZE = 14
local CLOSE_SIZE = 20
local RESULTS_GAP = 6
-- A compact field, like a browser's find bar, not the window's full width.
local FIELD_WIDTH = 260
-- Air between the field (and the results) and the chat's scroll bar.
local SCROLLBAR_GAP = 2
local MAX_RESULTS = 300
local SLIDE = 8
local OPEN_SECONDS = 0.16
local MATCH_COLOR = "|cffffd100"
local ICON = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconSearch"

local L = ns.L

local panel, field, icon, editBox, hint, count, close, results, driver
local target
local progress, opening = 0, false
local query = ""
local refreshPending = false

local function Lower(text)
	return string.lower(text)
end

-- The text with every match wrapped in gold, escape sequences (colors,
-- links, textures) left whole; a running color is put back after each
-- match so the rest of a colored span keeps its color.
local function Highlight(text, needle)
	local out = {}
	local pos, n = 1, #text
	local color
	local function visible(segment)
		if segment == "" then
			return
		end
		local lower = Lower(segment)
		local from = 1
		while true do
			local first, last = lower:find(needle, from, true)
			if not first then
				break
			end
			table.insert(out, segment:sub(from, first - 1))
			table.insert(out, MATCH_COLOR .. segment:sub(first, last) .. "|r" .. (color or ""))
			from = last + 1
		end
		table.insert(out, segment:sub(from))
	end
	while pos <= n do
		local bar = text:find("|", pos, true)
		if not bar then
			visible(text:sub(pos))
			break
		end
		visible(text:sub(pos, bar - 1))
		local kind = text:sub(bar + 1, bar + 1)
		local stop
		if kind == "c" then
			if text:sub(bar + 2, bar + 2) == "n" then
				stop = text:find(":", bar, true) or n
			else
				stop = bar + 9
			end
			color = text:sub(bar, stop)
		elseif kind == "r" then
			stop = bar + 1
			color = nil
		elseif kind == "H" then
			stop = (text:find("|h", bar, true) or n - 1) + 1
		elseif kind == "T" then
			stop = (text:find("|t", bar, true) or n - 1) + 1
		elseif kind == "A" then
			stop = (text:find("|a", bar, true) or n - 1) + 1
		elseif kind == "K" then
			stop = (text:find("|k", bar, true) or n - 1) + 1
		else
			-- "|h", "|n", "||".
			stop = bar + 1
		end
		table.insert(out, text:sub(bar, stop))
		pos = stop + 1
	end
	return table.concat(out)
end

-- Each entry's text as searched (plain, lower case), kept until the entry's
-- text changes (weak: gone with the entry). Every new line refreshes the
-- results, which used to strip every line of the history again.
local searchable = setmetatable({}, { __mode = "k" })

local function Searchable(entry)
	local text = entry.message
	local cached = searchable[entry]
	if cached and cached.source == text then
		return cached.text
	end
	cached = { source = text, text = Lower(ns.Lines.Plain(text)) }
	searchable[entry] = cached
	return cached.text
end

-- Fills the results with the target's lines holding the query (all of its
-- lines while the query is empty), oldest first.
local function Refresh()
	refreshPending = false
	if not target or not results then
		return
	end
	results:Clear()
	local needle = Lower(query)
	local matches = {}
	for _, entry in target.historyBuffer:EnumerateIndexedEntries() do
		local text = entry.message
		if ns.Lines.Readable(text) and (needle == "" or Searchable(entry):find(needle, 1, true)) then
			table.insert(matches, entry)
			if #matches >= MAX_RESULTS then
				break
			end
		end
	end
	for index = #matches, 1, -1 do
		local entry = matches[index]
		-- The chat draws a leader's crown and the guild's crest over the line;
		-- here they go inline.
		local text = ns.Channels.InlineMarks(ns.Channels.InlineCrown(entry.message, entry, target))
		results:AddMessage(needle ~= "" and Highlight(text, needle) or text, entry.r, entry.g, entry.b)
	end
	results:ScrollToBottom()
	count:SetText(needle ~= "" and tostring(#matches) or "")
	hint:SetShown(query == "")
end

local function ScheduleRefresh()
	refreshPending = true
end

local function PlaceField()
	local lift = SLIDE * (1 - progress)
	field.box:ClearAllPoints()
	field.box:SetPoint("TOPLEFT", panel, "TOPLEFT", FIELD_INSET + Theme.PANEL_PAD_LEFT, -FIELD_TOP + lift)
	field.box:SetWidth(math.min(FIELD_WIDTH, math.max(120, panel:GetWidth() - FIELD_INSET - Theme.PANEL_PAD_LEFT)))
end

local function ApplyFont()
	local font = ns.Fonts.ForFrame(target)
	editBox:SetFontObject(font)
	editBox:SetJustifyH("LEFT")
	hint:SetFontObject(font)
	results:SetFontObject(font)
	results:SetJustifyH("LEFT")
	if target.GetSpacing then
		results:SetSpacing(target:GetSpacing())
	end
end

-- The window's own lines out of sight while the results are shown.
local function TakeOver(chatFrame, taken)
	chatFrame.FontStringContainer:SetShown(not taken)
	ns.Channels.SetCrestsShown(chatFrame, not taken)
	ns.Scroll.SetSuspended(chatFrame, taken)
	ns.Skin.HoldWindow(chatFrame, "search", taken)
end

local function Tick(_, elapsed)
	if target and not target:IsVisible() then
		Search.Close()
		return
	end
	local goal = opening and 1 or 0
	if progress ~= goal then
		local step = elapsed / OPEN_SECONDS
		progress = goal > progress and math.min(goal, progress + step) or math.max(goal, progress - step)
		-- Ease out: fast at first, settling at the end.
		local eased = 1 - (1 - progress) * (1 - progress)
		panel:SetAlpha(eased)
		PlaceField()
		if progress == 0 then
			panel:Hide()
			driver:SetScript("OnUpdate", nil)
			return
		end
	end
	if refreshPending then
		Refresh()
	end
end

local function Run()
	if not driver:GetScript("OnUpdate") then
		driver:SetScript("OnUpdate", ns.Guard("Search.Tick", Tick))
	end
end

local function CreatePanel()
	panel = CreateFrame("Frame", nil, UIParent)
	panel:SetFrameStrata("MEDIUM")
	panel:SetFrameLevel(10)
	panel:Hide()

	field = ns.Skin.CreateInset(panel, "BORDER", "ARTWORK")
	field.box:SetHeight(Theme.INSET_HEIGHT)

	icon = panel:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(ICON, nil, nil, "NEAREST")
	icon:SetVertexColor(Theme.TAB_TEXT:GetRGB())
	local size = ns.Shapes.WholePixels(icon, ICON_SIZE)
	icon:SetSize(size, size)
	icon:SetPoint("LEFT", field.box, "LEFT", 7, 0)

	close = CreateFrame("Button", nil, panel)
	close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
	close:SetPoint("RIGHT", field.box, "RIGHT", -2, 0)
	local cross = close:CreateFontString(nil, "OVERLAY")
	cross:SetFontObject(ns.Fonts.ForTabs())
	cross:SetText("×")
	cross:SetPoint("CENTER", 0, 1)
	cross:SetTextColor(Theme.TAB_TEXT:GetRGB())
	close:SetScript("OnEnter", function()
		cross:SetTextColor(Theme.TAB_TEXT_HOVER:GetRGB())
	end)
	close:SetScript("OnLeave", function()
		cross:SetTextColor(Theme.TAB_TEXT:GetRGB())
	end)
	close:SetScript("OnClick", function()
		Search.Close()
	end)

	count = panel:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(ns.Fonts.ForTabs())
	count:SetTextColor(Theme.TIME:GetRGB())
	count:SetPoint("RIGHT", close, "LEFT", -4, 0)

	-- Font strings and edit boxes need a font before any text; the window's
	-- own size comes in ApplyFont.
	local defaultFont = ns.Fonts.ForTabs()
	editBox = CreateFrame("EditBox", nil, panel)
	editBox:SetFontObject(defaultFont)
	editBox:SetAutoFocus(false)
	editBox:SetHeight(Theme.INSET_HEIGHT)
	editBox:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	editBox:SetPoint("RIGHT", count, "LEFT", -6, 0)
	editBox:SetTextColor(Theme.TAB_TEXT_HOVER:GetRGB())
	-- A new theme: the field's edge, its glyphs and its text in its colors.
	Theme.OnChanged(function()
		field:SetEdgeColor(Theme.FIELD_EDGE:GetRGBA())
		icon:SetVertexColor(Theme.TAB_TEXT:GetRGB())
		cross:SetTextColor((close:IsMouseOver() and Theme.TAB_TEXT_HOVER or Theme.TAB_TEXT):GetRGB())
		editBox:SetTextColor(Theme.TAB_TEXT_HOVER:GetRGB())
	end)
	editBox:SetScript("OnEscapePressed", function()
		Search.Close()
	end)
	editBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		if text ~= query then
			query = text
			ScheduleRefresh()
			Run()
		end
	end)

	hint = panel:CreateFontString(nil, "OVERLAY")
	hint:SetFontObject(defaultFont)
	hint:SetPoint("LEFT", editBox, "LEFT", 0, 0)
	hint:SetTextColor(Theme.TIME:GetRGB())
	hint:SetText(L.searchHint)

	-- An intrinsic frame type: the mixin comes with it, no template.
	results = CreateFrame("ScrollingMessageFrame", nil, panel)
	results:SetFontObject(defaultFont)
	results:SetPoint("TOPLEFT", field.box, "BOTTOMLEFT", 2, -RESULTS_GAP)
	results:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 2)
	results:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)
	results:SetMaxLines(MAX_RESULTS)
	results:SetFading(false)
	results:SetIndentedWordWrap(false)
	results:SetHyperlinksEnabled(true)
	results:EnableMouseWheel(true)
	results:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			self:ScrollUp()
		else
			self:ScrollDown()
		end
	end)
	results:SetScript("OnHyperlinkClick", function(_, link, text, button)
		if target then
			SetItemRef(link, text, button, target)
		end
	end)
	results:SetScript("OnHyperlinkEnter", function(self, link)
		ns.Links.OnHoverLink(self, link)
	end)
	results:SetScript("OnHyperlinkLeave", function(self)
		ns.Links.OnLeaveLink(self)
	end)

	driver = CreateFrame("Frame")
end

local function Retarget(chatFrame)
	if target == chatFrame then
		return
	end
	if target then
		TakeOver(target, false)
	end
	target = chatFrame
	TakeOver(chatFrame, true)
	-- On the message area itself, as far as Blizzard's Background reaches
	-- around it (FloatingChatFrame_UpdateBackgroundAnchors), except at the
	-- top, where the combat log's Background also covers its filter bar,
	-- and at the right, where the scroll bar stands.
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -2 - Theme.PANEL_PAD_LEFT, 3)
	panel:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -SCROLLBAR_GAP, -6)
	ApplyFont()
	PlaceField()
	ScheduleRefresh()
	Run()
end

function Search.IsOpen()
	return opening
end

function Search.Open(chatFrame)
	if not panel then
		CreatePanel()
	end
	opening = true
	panel:Show()
	Retarget(chatFrame)
	PlaceField()
	editBox:SetFocus()
	Run()
end

function Search.Close()
	if not opening then
		return
	end
	opening = false
	editBox:ClearFocus()
	editBox:SetText("")
	query = ""
	if target then
		TakeOver(target, false)
		target = nil
	end
	Run()
end

function Search.Toggle(chatFrame)
	if opening and target == chatFrame then
		Search.Close()
	else
		Search.Open(chatFrame)
	end
end

function Search.Init()
	-- The field follows the tab on show.
	hooksecurefunc("FCFDock_SelectWindow", function(dock, chatFrame)
		if opening and dock == GENERAL_CHAT_DOCK and chatFrame then
			Retarget(chatFrame)
		end
	end)
	-- New lines reach the results as they come.
	ns.Lines.AddListener(function(chatFrame)
		if opening and chatFrame == target then
			ScheduleRefresh()
			Run()
		end
	end)
	ns.Fonts.OnSizeChanged(function()
		if opening and target then
			ApplyFont()
		end
	end)
end
