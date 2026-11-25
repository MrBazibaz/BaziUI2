local ns = BaziUI.Chat
local Theme = ns.Theme

local EditBox = {}
ns.EditBox = EditBox

-- Blizzard geometry (ChatFrameEditBox.xml, ChatFrameEditBox.lua): the edit box
-- is 32px tall and its text starts 15px in from its left edge and ends 13px
-- before its right one.
local TEXT_LEFT = 15
local TEXT_RIGHT = 13

-- The field inside the footer (Skin.CreateInset), the text 6px in. Its fill
-- is black at half, darker than the card and see-through like it (solid, it
-- was the heaviest piece of the chat), and fades with the chat's controls.
local FIELD_LEFT = 4
local FIELD_PADDING = 6
local FIELD_FILL = 0.5

local skinned = {}
-- Each window's check of whether its field shows (below), run again when a
-- window docks or undocks.
local presenceChecks = {}
local layoutUpdates = {}

function EditBox.RefreshLayout()
	for _, update in ipairs(layoutUpdates) do update() end
end

-- The game's own chat style (Options > Social > Chat Style): "im" shows the
-- box of the window typed in last, "classic" none until Enter.
local function ClassicStyle()
	return C_CVar.GetCVar("chatStyle") == "classic"
end

-- Blizzard draws the edit box and its header in ChatFontNormal (14) whatever
-- the window's size; here they follow it, like the footer's hint.
local function ApplyFont(chatFrame, hint)
	local font = ns.Fonts.ForFrame(chatFrame)
	local editBox = chatFrame.editBox
	editBox:SetFontObject(font)
	-- The font object's centered justification would come along.
	editBox:SetJustifyH("LEFT")
	for _, region in ipairs({ editBox.header, editBox.headerSuffix, editBox.languageHeader }) do
		region:SetFontObject(font)
	end
	hint:SetFontObject(font)
end

local function CreateField(chatFrame, skin)
	local field = ns.Skin.CreateInset(chatFrame, "BORDER", "ARTWORK")
	field.fill:SetColor(0, 0, 0, FIELD_FILL)
	field.box:SetPoint("LEFT", skin.footer, "LEFT", FIELD_LEFT, 0)
	field.box:SetPoint("RIGHT", skin.footer, "RIGHT", -ns.Resize.FOOTER_CONTROLS_WIDTH, 0)
	field.box:SetHeight(Theme.INSET_HEIGHT)
	table.insert(skin.chrome, field.fill)
	table.insert(skin.chrome, field.edge)
	return field
end

-- The game draws the edit box above other windows (its template's DIALOG
-- strata), so what is being typed stays in sight with a window over the
-- chat. The field around it is the card's, below those windows, so the text
-- and its "Say:" would float over the window without their box. While
-- typing, a copy of the field on the edit box's strata, just under the edit
-- box, takes the field's place: the whole box shows, as the game's own does.
local function CreateRaisedField(field)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetPoint("BOTTOMLEFT", field.box, "BOTTOMLEFT")
	frame:SetPoint("BOTTOMRIGHT", field.box, "BOTTOMRIGHT")
	frame:Hide()
	local raised = ns.Skin.CreateInset(frame, "BORDER", "ARTWORK")
	raised.fill:SetColor(0, 0, 0, FIELD_FILL)
	raised.box:SetAllPoints(field.box)
	raised.frame = frame
	return raised
end

-- The game's own box around the field (ChatFrameEditBoxTemplate's art), in a
-- theme with the game's art (Theme.GAME_ART): on the edit box itself while
-- typing (with its light while it has the focus, which the game shows), and
-- otherwise a copy of it that rests with the chat. The game leaves the edit
-- box shown at 35% while nobody types, so its own art would stay in sight
-- with the chat hidden at rest: it only has it while typing.
local GAME_BORDER = "Interface\\ChatFrame\\UI-ChatInputBorder"
local GAME_PIECES = {
	{ "Left", "-Left2", "focusLeft", "Focus-Left" },
	{ "Right", "-Right2", "focusRight", "Focus-Right" },
	{ "Mid", "-Mid2", "focusMid", "Focus-Mid" },
}

local function SetGameArt(editBox, shown)
	local name = editBox:GetName()
	for _, piece in ipairs(GAME_PIECES) do
		_G[name .. piece[1]]:SetTexture(shown and GAME_BORDER .. piece[2] or nil)
		editBox[piece[3]]:SetTexture(shown and GAME_BORDER .. piece[4] or nil)
	end
end

local function CreateGameBorder(chatFrame)
	local editBox = chatFrame.editBox
	local left = chatFrame:CreateTexture(nil, "BORDER")
	left:SetTexture(GAME_BORDER .. "-Left2")
	left:SetSize(32, 32)
	left:SetPoint("LEFT", editBox, "LEFT")
	local right = chatFrame:CreateTexture(nil, "BORDER")
	right:SetTexture(GAME_BORDER .. "-Right2")
	right:SetSize(32, 32)
	right:SetPoint("RIGHT", editBox, "RIGHT")
	local middle = chatFrame:CreateTexture(nil, "BORDER")
	middle:SetTexture(GAME_BORDER .. "-Mid2", "REPEAT", "CLAMP")
	middle:SetHorizTile(true)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	return { left, middle, right }
end

function EditBox.Skin(chatFrame, skin)
	local editBox = chatFrame.editBox
	if not editBox or skinned[editBox] then
		return
	end

	-- The game's box goes (SetGameArt puts it back in a theme with its art).
	SetGameArt(editBox, false)

	local field = CreateField(chatFrame, skin)
	local raised = CreateRaisedField(field)
	local topField = CreateFrame("Frame", nil, raised.frame, "BackdropTemplate")
	topField:SetPoint("BOTTOMLEFT", raised.frame, "BOTTOMLEFT")
	topField:SetPoint("BOTTOMRIGHT", raised.frame, "BOTTOMRIGHT")
	topField:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
	topField:SetBackdropBorderColor(0.62, 0.49, 0.30, 1)
	local topFill = topField:CreateTexture(nil, "BACKGROUND")
	topFill:SetPoint("TOPLEFT", 2, -2)
	topFill:SetPoint("BOTTOMRIGHT", -2, 2)
	topField:Hide()
	local border = CreateGameBorder(chatFrame)
	for _, piece in ipairs(border) do
		table.insert(skin.chrome, piece)
	end

	-- The edit box spans the field, its text FIELD_PADDING in from each side.
	-- With the game's art it stands as the game stands it under its chat
	-- (FloatingChatFrame.xml): 3 units past the card on each side, its top 4
	-- above the message area's bottom, so its box lines up with the card.
	-- Only anchored in FloatingChatFrame.xml; Blizzard never moves it afterwards.
	local originalHeight = editBox:GetHeight()
	local function PlaceEditBox()
		local db = ns.db
		local x, y = db.inputX or 0, db.inputY or 0
		local width, height = db.inputWidth or 0, db.inputHeight or 0
		local above = db.inputPosition == "top"
		local leftEdge, rightEdge = above and "TOPLEFT" or "LEFT", above and "TOPRIGHT" or "RIGHT"
		local leftPoint, rightPoint = above and "BOTTOMLEFT" or "LEFT", above and "BOTTOMRIGHT" or "RIGHT"
		local anchor = above and chatFrame or skin.footer
		local vertical = y + (above and 32 or 0)
		local rightInset = above and 4 or ns.Resize.FOOTER_CONTROLS_WIDTH
		editBox:ClearAllPoints()
		field.box:ClearAllPoints()
		local fieldHeight = height > 0 and math.max(16, height) or Theme.INSET_HEIGHT
		field.box:SetHeight(fieldHeight)
		raised.frame:SetHeight(fieldHeight)
		topField:SetHeight(fieldHeight)
		if width > 0 then
			field.box:SetWidth(math.max(80, width))
			field.box:SetPoint(above and "BOTTOM" or "CENTER", anchor, above and "TOP" or "CENTER", x, vertical)
		else
			field.box:SetPoint(leftPoint, anchor, leftEdge, FIELD_LEFT + x, vertical)
			field.box:SetPoint(rightPoint, anchor, rightEdge, x - rightInset, vertical)
		end
		if originalHeight > 0 then
			editBox:SetHeight(height > 0 and math.max(16, height) or originalHeight)
		end
		if Theme.GAME_ART and not above and width == 0 and height == 0 then
			editBox:SetPoint("TOPLEFT", skin.footer, "TOPLEFT", x - 3, y + 4)
			editBox:SetPoint("TOPRIGHT", skin.footer, "TOPRIGHT", x + 3, y + 4)
		elseif height > 0 then
			editBox:SetPoint("TOPLEFT", field.box, "TOPLEFT", FIELD_PADDING - TEXT_LEFT, 0)
			editBox:SetPoint("BOTTOMRIGHT", field.box, "BOTTOMRIGHT", TEXT_RIGHT - FIELD_PADDING, 0)
		else
			editBox:SetPoint("LEFT", field.box, "LEFT", FIELD_PADDING - TEXT_LEFT, 0)
			editBox:SetPoint("RIGHT", field.box, "RIGHT", TEXT_RIGHT - FIELD_PADDING, 0)
		end
	end
	skin.placeEditBox = PlaceEditBox
	PlaceEditBox()

	-- Where the text will start, while the edit box is hidden.
	local hint = chatFrame:CreateFontString(nil, "ARTWORK")
	hint:SetFontObject(ns.Fonts.ForFrame(chatFrame))
	hint:SetTextColor(Theme.TIME:GetRGB())
	hint:SetText(ns.L.typeHint)
	-- Where the edit box's text starts.
	hint:SetPoint("LEFT", editBox, "LEFT", TEXT_LEFT, 0)
	skin.hint = hint
	-- It rests with the field (Skin.lua's fade).
	table.insert(skin.chrome, hint)
	ApplyFont(chatFrame, hint)
	ns.Fonts.OnSizeChanged(function(changed)
		if changed == chatFrame then
			ApplyFont(chatFrame, hint)
		end
	end)

	-- While the player types, the field's edge takes the chat type's color
	-- (Blizzard's UpdateHeader gives the edit box's text that color on every
	-- type change), the whole chat lights up and the hint hides. Read from the
	-- edit box each frame by a frame of our own: under Forever's addon
	-- restrictions (instances, combat), Blizzard's own calls to an edit box
	-- method an addon hooked fail ("attempt to call a nil value"), which is how
	-- hooks on SetFocusRegionsShown/SetFocusRegionVertexColors broke opening
	-- the chat in a dungeon.
	-- The watcher is the edit box's child, so it only ticks while the box is
	-- shown (one per window; parented to UIParent they all ticked, every
	-- frame), and it reads the color only while typing.
	local typing, r, g, b = false, nil, nil, nil
	local function SetEdgeColor(...)
		field:SetEdgeColor(...)
		raised:SetEdgeColor(...)
	end
	-- Nobody typing: the theme's edge, as much as the style shows of it.
	local function RestEdge()
		local edge = Theme.FIELD_EDGE
		SetEdgeColor(edge.r, edge.g, edge.b, edge.a * Theme.FIELD_EDGE_REST)
	end
	-- The game shows one edit box, the one of the window typed in last (its
	-- "IM" chat style; none at rest in its classic style), and hides the
	-- others: Enter types there. A window shows its field only while the
	-- game shows its box, so a second window for guild or party talk has no
	-- field of its own (asked for in a CurseForge comment). A floating
	-- window without it has no footer; a docked one keeps its footer, empty,
	-- so the main card and its side bar keep their shape (always showing its
	-- field there showed two, one of them where Enter didn't type).
	local present = true
	-- Everchat's field, or the game's box, resting or raised while typing.
	local shownGameArt = false
	local function ShowField()
		local above = ns.db.inputPosition == "top"
		local useBaziBorder = above or (ns.db.inputHeight or 0) > 0
		local game = Theme.GAME_ART and not useBaziBorder
		if shownGameArt ~= (typing and game) then
			shownGameArt = typing and game
			SetGameArt(editBox, shownGameArt)
		end
		raised.frame:SetShown(typing and not game)
		raised.fill:SetShown(not useBaziBorder)
		raised.edge:SetShown(not useBaziBorder)
		topField:SetShown(useBaziBorder and typing)
		if useBaziBorder and typing then topFill:SetColorTexture(ns.Skin.InputBackground(chatFrame)) end
		field.fill:SetShown(not above and present and not typing and not game)
		field.edge:SetShown(not above and present and not typing and not game)
		for _, piece in ipairs(border) do
			piece:SetShown(present and not typing and game)
		end
	end
	local function CheckPresence()
		-- In the classic style the game shows no box at rest and Enter
		-- always opens the main window's, at the dock: the docked card keeps
		-- its field there.
		local now = (editBox:IsShown() or chatFrame.isDocked and ClassicStyle()) and true or false
		ns.Skin.SetFooterShown(skin, now or chatFrame.isDocked, now)
		if now ~= present then
			present = now
			ShowField()
		end
	end
	editBox:HookScript("OnShow", CheckPresence)
	editBox:HookScript("OnHide", CheckPresence)
	table.insert(presenceChecks, CheckPresence)
	local function SetTyping(focused)
		typing = focused
		ns.Skin.SetTyping(skin, focused)
		ShowField()
		if not focused then
			r, g, b = nil, nil, nil
			RestEdge()
		end
	end
	-- Kept just under the edit box, which rises as it takes the focus.
	local function PlaceRaised()
		local strata, level = editBox:GetFrameStrata(), math.max(editBox:GetFrameLevel() - 1, 0)
		local frame = raised.frame
		if frame:GetFrameStrata() ~= strata or frame:GetFrameLevel() ~= level then
			frame:SetFrameStrata(strata)
			frame:SetFrameLevel(level)
		end
	end
	-- The header ("[1. General: Elwynn Forest]: ", "Guild: ") under the name
	-- the lines show (Channels.HeaderText), laid out as UpdateHeader lays out
	-- the game's: half the box at most, the text after it. Read and written
	-- from the watcher, like the color; `shownHeader` is the header last seen
	-- or written, so a new one from the game is caught in the frame it comes.
	local header, headerSuffix, languageHeader = editBox.header, editBox.headerSuffix, editBox.languageHeader
	local shownHeader
	local function NameHeader()
		local current = header:GetText()
		if current == shownHeader or not canaccessvalue(current) then
			return
		end
		shownHeader = current
		local chatType = editBox:GetAttribute("chatType")
		local number, channelName
		if chatType == "CHANNEL" then
			number, channelName = GetChannelName(editBox:GetAttribute("channelTarget"))
			if not canaccessvalue(number) or not canaccessvalue(channelName) then
				number, channelName = nil, nil
			end
		end
		local text = ns.Channels.HeaderText(chatType, channelName, current, number)
		if not text then
			return
		end
		header:SetWidth(0)
		header:SetText(text)
		local half = editBox:GetWidth() / 2
		headerSuffix:SetShown(header:GetStringWidth() > half)
		if headerSuffix:IsShown() then
			header:SetWidth(half)
		end
		local languageWidth = languageHeader and languageHeader:IsShown() and languageHeader:GetWidth() or 0
		editBox:SetTextInsets(TEXT_LEFT + header:GetWidth() + (headerSuffix:IsShown() and headerSuffix:GetWidth() or 0)
			+ languageWidth, TEXT_RIGHT, 0, 0)
		shownHeader = text
	end
	-- The box types at its window's size (ApplyFont). Anything else that gives
	-- it another (another chat addon's input bar) is undone while typing, and
	-- /everchat font says what it was. Should putting it back not take, it's
	-- left alone rather than tried on every frame.
	local keepFont = true
	local function KeepFont()
		local _, height = editBox:GetFont()
		local _, expected = ns.Fonts.ForFrame(chatFrame):GetFont()
		if not (keepFont and height and expected and math.abs(height - expected) > 0.5) then
			return
		end
		ns.Fonts.NoteForeignFont(editBox)
		ApplyFont(chatFrame, hint)
		local _, now = editBox:GetFont()
		keepFont = now ~= nil and math.abs(now - expected) <= 0.5
	end
	local watcher = CreateFrame("Frame", nil, editBox)
	watcher:SetScript("OnUpdate", ns.Guard("EditBox.Watcher", function()
		local focused = editBox:HasFocus()
		if not focused then
			if typing then
				SetTyping(false)
				shownHeader = nil
			end
			return
		end
		if not typing then
			SetTyping(true)
		end
		PlaceRaised()
		KeepFont()
		NameHeader()
		local nr, ng, nb = editBox:GetTextColor()
		if nr ~= r or ng ~= g or nb ~= b then
			r, g, b = nr, ng, nb
			SetEdgeColor(r, g, b, 1)
		end
	end))
	-- Hidden mid-typing (the window closed or undocked): back to rest.
	watcher:SetScript("OnHide", function()
		if typing then
			SetTyping(false)
		end
		shownHeader = nil
	end)
	-- A new theme: the resting edge in its color (while typing it's the
	-- chat type's), and Everchat's field or the game's box.
	local function ApplyTheme()
		PlaceEditBox()
		ShowField()
		if not typing then
			RestEdge()
		end
	end
	table.insert(layoutUpdates, ApplyTheme)
	Theme.OnChanged(ApplyTheme)
	ApplyTheme()
	CheckPresence()

	skinned[editBox] = true
end

-- Docking and undocking change which windows keep their field.
function EditBox.Init()
	local function CheckAll()
		for _, check in ipairs(presenceChecks) do
			check()
		end
	end
	hooksecurefunc("FCFDock_AddChatFrame", CheckAll)
	hooksecurefunc("FCFDock_RemoveChatFrame", CheckAll)
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("CVAR_UPDATE")
	watcher:SetScript("OnEvent", function(_, _, name)
		if type(name) == "string" and name:lower() == "chatstyle" then
			CheckAll()
		end
	end)
end
