local ns = BaziUI.Chat
local Theme = ns.Theme

local Links = {}
ns.Links = Links

-- Web addresses in chat become links; clicking one opens a small window with
-- the address selected, ready for Ctrl+C (the game can't open a browser).
-- The link is an addon hyperlink (|Haddon:Everchat:url:...|h), which Blizzard
-- hands to addons through EventRegistry's "SetItemRef" event without running
-- any of its own link code. Lines.lua applies it to each line it can read
-- (secret messages pass untouched). Text already inside a link (items,
-- players, the game's own web links) is left alone.
local LINK_PREFIX = "addon:Everchat:url:"
-- The time at the start of a line (Timestamps.lua): opens that line as text.
local LINE_PREFIX = "addon:Everchat:line:"
-- Everchat's links in a line (web addresses, "inv") are in the game's gold
-- and in brackets (2026-10-13, the user): brackets are how the game's chat
-- shows what can be clicked, and players' addresses aren't links in the game,
-- so without them nothing said this one was; the game's own web link in a
-- message is gold in brackets too ("[Click Here]",
-- TOKEN_REDEEM_BALANCE_ERROR_CAP_FORMAT). Until then addresses were light
-- blue, the color of spell links and almost that of a party leader's lines.
local LINK_COLOR = "ffffd100"
-- Punctuation that ends a sentence rather than an address.
local TRAILING = "[%.,;:!%?%)%]'\"]+$"

local WIDTH = 420
local PADDING = 14

local dialog

local function Wrap(url)
	local trailing = url:match(TRAILING) or ""
	url = url:sub(1, #url - #trailing)
	if url == "" then
		return trailing
	end
	return ("|c%s|H%s%s|h[%s]|h|r%s"):format(LINK_COLOR, LINK_PREFIX, url, url, trailing)
end

-- Endings a bare domain takes ("ruinnation.com"): the common ones only, so
-- "e.g." or a name like "Mr.Smith" never turn into links.
local DOMAINS = {
	com = true, net = true, org = true, gg = true, tv = true, io = true, eu = true, info = true, app = true,
	dev = true, xyz = true, co = true, me = true, ly = true, es = true, de = true, fr = true, it = true,
	pt = true, br = true, ru = true, uk = true,
}

-- Addresses in text outside links: http(s)://..., www...., and since
-- 2026-10-14 a domain with a path ("discord.gg/RUIN", "youtube.com/RUIN",
-- which the user's guild message of the day had and no link came of) or a
-- bare domain with a common ending. Each kind is set aside as found (\1n\2)
-- so the next can't take a piece of it, and a domain right after "@" is an
-- e-mail's, left alone.
local function LinkifyPlain(text)
	local found = {}
	local function Keep(url)
		table.insert(found, url)
		return "\1" .. #found .. "\2"
	end
	local function KeepDomain(position, domain, ending)
		if text:sub(position - 1, position - 1) == "@" or (ending and not DOMAINS[ending:lower()]) then
			return nil
		end
		return Keep(domain)
	end
	text = text:gsub("https?://[^%s|]+", Keep)
	text = text:gsub("%f[%S]www%.[%w%-]+%.[^%s|]+", Keep)
	text = text:gsub("()(%f[%w][%w%-]+%.[%w%.%-]*%a%a+/[^%s|]*)", function(position, domain)
		return KeepDomain(position, domain)
	end)
	text = text:gsub("()(%f[%w][%w%-]+%.[%w%.%-]*%f[%a](%a%a+))%f[^%w%-]", KeepDomain)
	return (text:gsub("\1(%d+)\2", function(index)
		return Wrap(found[tonumber(index)])
	end))
end

-- Lines.lua composes each line through this. Not in public numbered channels
-- (Trade, General...): there web addresses are mostly gold sellers' and
-- scams (Forever's spam filters treat them as a spam sign), and a link would
-- only make them stand out; Copy chat still has them as text.
function Links.Linkify(text, event)
	if event == "CHAT_MSG_CHANNEL" then
		return text
	end
	-- Most lines hold no dot before two letters, and go back at once.
	if not text:find("%.%a%a") then
		return text
	end
	local parts, position = {}, 1
	while true do
		local first, last = text:find("|H.-|h.-|h", position)
		table.insert(parts, LinkifyPlain(text:sub(position, (first or 0) - 1)))
		if not first then
			break
		end
		table.insert(parts, text:sub(first, last))
		position = last + 1
	end
	return table.concat(parts)
end

-- "inv" in a whisper or a guild line from someone else invites them with a
-- click (2026-10-12, the user's call after the research on other addons:
-- Prat's and BasicChatMods' keyword links ran in every channel, a faulty
-- rewrite hid whispers that held the word, and in "LFM, whisper inv" it's the
-- reader asking, so the link invited the wrong way round; BasicChatMods
-- dropped them for Alt+click on names, which Forever leaves no clean way to
-- add: any click on a name but Shift's opens a whisper, and stopping that would
-- touch the edit box from addon code). Here only whispers and guild, where
-- "inv" means "invite me"; the word stays as written, only made a link; the
-- name is the one in the line's own player link, the way the game's
-- right-click Invite takes it (Prat added the realm and invited "Unknown");
-- Battle.net whispers carry no character name and are left alone. In the
-- game's gold like the web links, and in brackets: gold without them is how
-- Everchat marks a mention, which can't be clicked (2026-10-13, the user:
-- the first build's light blue looked worse; Prat's were yellow, ffff00).
local INVITE_PREFIX = "addon:Everchat:inv:"
local INVITE_EVENTS = { CHAT_MSG_WHISPER = true, CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true }
-- Only the short forms players type to ask, as whole words: full words
-- ("invite", "invita", "инвайт") also come up in conversation and in
-- recruiters' offers ("want an invite?"), and the first build linked the
-- "invite" in a guildmate's story quoting one ("invite on the way", 2026-10-13,
-- the user). Lua lowers only ASCII, hence the Cyrillic cases.
local INVITE_WORDS = { inv = true, invi = true, ["инв"] = true, ["Инв"] = true, ["ИНВ"] = true }
-- Punctuation that, in UTF-8, the word pattern below takes for letters
-- ("¡inv!", "«inv»"): taken off a word's ends before looking it up.
local WORD_MARKS = { "¡", "¿", "«", "»", "“", "”", "„", "‘", "’", "…" }
-- Quotes on both sides of the word: it's mentioned, not said ("whisper me
-- "inv" to check").
local QUOTES = { ['"'] = true, ["'"] = true, ["«"] = true, ["»"] = true, ["“"] = true, ["”"] = true, ["„"] = true, ["‘"] = true, ["’"] = true }

-- The word without a mark at one end, and the mark; or the word as it was.
local function TakeMark(word, atEnd)
	for _, mark in ipairs(WORD_MARKS) do
		if #word > #mark and (atEnd and word:sub(-#mark) or word:sub(1, #mark)) == mark then
			return atEnd and word:sub(1, -#mark - 1) or word:sub(#mark + 1), mark
		end
	end
	return word
end

-- Text outside escape sequences (links whole, textures, atlases, Battle.net
-- names, colors) through fn; the escapes as they are. A texture's path may
-- hold "INV" (Interface\Icons\INV_...), and cutting into one would break it.
local ESCAPE_ENDS = { H = "|h.-|h", T = "|t", A = "|a", K = "|k" }

local function OutsideEscapes(text, fn)
	local parts, position = {}, 1
	while true do
		local first = text:find("|", position, true)
		if not first then
			table.insert(parts, fn(text:sub(position)))
			break
		end
		table.insert(parts, fn(text:sub(position, first - 1)))
		local code = text:sub(first + 1, first + 1)
		local last
		if ESCAPE_ENDS[code] then
			local _, stop = text:find(ESCAPE_ENDS[code], first + 2)
			last = stop or #text
		elseif code == "c" then
			-- |cAARRGGBB, or the newer |cn<name>: colors.
			last = text:sub(first + 2, first + 2) == "n" and (text:find(":", first + 3, true) or #text) or first + 9
		else
			last = first + 1
		end
		table.insert(parts, text:sub(first, last))
		position = last + 1
	end
	return table.concat(parts)
end

-- Lines.lua composes each line through this, with whether the player wrote it.
function Links.InviteLinks(text, event, own)
	if not ns.db.inviteLinks or own or not INVITE_EVENTS[event] then
		return text
	end
	-- Most lines hold neither, and go back untouched at once.
	local name = text:match("|Hplayer:([^:|]+)")
	if not name or not (text:lower():find("inv", 1, true) or text:find("нв", 1, true) or text:find("НВ", 1, true)) then
		return text
	end
	return OutsideEscapes(text, function(part)
		return (part:gsub("()([%a\128-\255]+)()", function(first, word, last)
			if not (word:lower():find("inv", 1, true) or word:find("нв", 1, true) or word:find("НВ", 1, true)) then
				return nil
			end
			-- The marks around the word, and what touches it on each side.
			local lead, trail, before, after = "", "", part:sub(first - 1, first - 1), part:sub(last, last)
			local mark
			repeat
				word, mark = TakeMark(word, false)
				if mark then
					lead, before = lead .. mark, mark
				end
			until not mark
			repeat
				word, mark = TakeMark(word, true)
				if mark then
					trail, after = mark .. trail, mark
				end
			until not mark
			if not (INVITE_WORDS[word] or INVITE_WORDS[word:lower()]) or (QUOTES[before] and QUOTES[after])
				or (after == "'" and part:sub(last + 1, last + 1):find("%a")) then
				-- Not a request, mentioned, or a contraction ("inv'd").
				return nil
			end
			return lead .. ("|c%s|H%s%s|h[%s]|h|r"):format(LINK_COLOR, INVITE_PREFIX, name, word) .. trail
		end))
	end)
end

-- Copying itself has to be the player's Ctrl+C: CopyToClipboard is
-- restricted to Blizzard's UI (an addon calling it gets blocked), which is why
-- every addon shows the address in a box instead of a copy button (Prat in
-- a popup, ElvUI in the chat's edit box). Ctrl+C confirms ("Copied"); the
-- window stays until the player closes it. In Everchat's window look, like
-- the options window (Options.CreateWindow).
local function CreateDialog()
	dialog = ns.Options.CreateWindow(WIDTH, ns.L.linkTitle)
	dialog:SetPoint("TOP", UIParent, "TOP", 0, -UIParent:GetHeight() / 4)
	local top = dialog.titleHeight

	local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
	edit:SetAutoFocus(false)
	edit:SetHeight(22)
	edit:SetPoint("TOPLEFT", dialog, "TOPLEFT", PADDING + 6, -(top + PADDING))
	edit:SetPoint("RIGHT", dialog, "RIGHT", -PADDING, 0)
	dialog.edit = edit

	-- Silent: the window sounds as it closes.
	local close = ns.Options.CreateTextButton(dialog, ns.L.linkClose, function()
		dialog:Hide()
	end, false, true)
	close:SetPoint("TOPRIGHT", edit, "BOTTOMRIGHT", 0, -10)

	local hint = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("LEFT", edit, "LEFT", -6, 0)
	hint:SetPoint("TOP", close, "TOP")
	hint:SetPoint("BOTTOM", close, "BOTTOM")
	dialog.hint = hint

	dialog:SetHeight(top + PADDING + 22 + 10 + close:GetHeight() + PADDING)

	-- Read-only: typing puts the address back, selected.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(dialog.text)
			self:HighlightText()
		end
	end)
	edit:SetScript("OnKeyDown", function(_, key)
		if key == "C" and IsControlKeyDown() then
			hint:SetText(ns.L.linkCopied)
			hint:SetTextColor(Theme.GOLD:GetRGB())
		end
	end)
	edit:SetScript("OnEscapePressed", function()
		dialog:Hide()
	end)
	edit:SetScript("OnEnterPressed", function()
		dialog:Hide()
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	dialog:HookScript("OnHide", function()
		edit:ClearFocus()
	end)
end

-- A web address, or one chat line (its time was clicked), selected for Ctrl+C.
local function ShowText(title, text)
	if not dialog then
		CreateDialog()
	end
	dialog:SetTitle(title)
	dialog.text = text
	dialog.hint:SetText(ns.L.linkHint)
	dialog.hint:SetTextColor(Theme.TIME:GetRGB())
	dialog:Show()
	dialog.edit:SetText(text)
	dialog.edit:SetCursorPosition(0)
	dialog.edit:SetFocus()
	dialog.edit:HighlightText()
end

-- A tab's chat as text, to copy (the tab menu's "Copy chat"): the native chat
-- can't be selected in Forever (EnableMouse on chat frames is protected), so
-- like ElvUI's copy button the lines go into a window of our own, plain text
-- (Lines.PlainText), oldest first and scrolled to the newest, all selected
-- for Ctrl+C; a part can be selected with the mouse. Read-only, closed by
-- Close or Esc, dragged by its title.
local CHAT_WIDTH = 560
local CHAT_HEIGHT = 360
local SCROLLBAR_GAP = 8

local chatDialog

local function SelectAllChat()
	chatDialog.box:GetEditBox():HighlightText()
end

local function CreateChatDialog()
	chatDialog = ns.Options.CreateWindow(CHAT_WIDTH)
	chatDialog:SetHeight(CHAT_HEIGHT)
	chatDialog:SetPoint("CENTER")
	local top = chatDialog.titleHeight

	-- Silent: the window sounds as it closes.
	local close = ns.Options.CreateTextButton(chatDialog, ns.L.linkClose, function()
		chatDialog:Hide()
	end, false, true)
	close:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

	local hint = chatDialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("LEFT", PADDING, 0)
	hint:SetPoint("TOP", close, "TOP")
	hint:SetPoint("BOTTOM", close, "BOTTOM")
	chatDialog.hint = hint

	local scrollBar = CreateFrame("EventFrame", nil, chatDialog, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", chatDialog, "TOPRIGHT", -PADDING, -(top + PADDING))
	scrollBar:SetPoint("BOTTOMRIGHT", close, "TOPRIGHT", 0, 10)

	local box = CreateFrame("Frame", nil, chatDialog, "ScrollingEditBoxTemplate")
	box:SetPoint("TOPLEFT", chatDialog, "TOPLEFT", PADDING, -(top + PADDING))
	box:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -SCROLLBAR_GAP, 0)
	-- The chat's font. The template's edit box puts its own font object back
	-- whenever its text is set (fontName), and a font object brings its
	-- justification (the family's is centered): both are kept on our box.
	local font = ns.Fonts.ForSize(ns.Fonts.GetSize(DEFAULT_CHAT_FRAME))
	local editBox = box:GetEditBox()
	editBox.fontName, editBox.defaultFontName = font, font
	box:SetFontObject(font)
	hooksecurefunc(editBox, "SetFontObject", function(self)
		self:SetJustifyH("LEFT")
	end)
	editBox:SetJustifyH("LEFT")
	ScrollUtil.RegisterScrollBoxWithScrollBar(box:GetScrollBox(), scrollBar)
	chatDialog.box = box

	-- Read-only: typing puts the text back, all selected.
	box:RegisterCallback("OnTextChanged", function(_, _, userChanged)
		if userChanged then
			box:SetText(chatDialog.text)
			SelectAllChat()
		end
	end, chatDialog)
	box:RegisterCallback("OnKeyDown", function(_, _, key)
		if key == "C" and IsControlKeyDown() then
			hint:SetText(ns.L.linkCopied)
			hint:SetTextColor(Theme.GOLD:GetRGB())
		end
	end, chatDialog)
	box:RegisterCallback("OnEscapePressed", function()
		chatDialog:Hide()
	end, chatDialog)
	chatDialog:HookScript("OnHide", function()
		box:ClearFocus()
	end)
end

function Links.ShowChat(chatFrame)
	if not chatDialog then
		CreateChatDialog()
	end
	chatDialog:SetTitle(ns.L.copyTitle:format(chatFrame.name or ""))
	chatDialog.text = table.concat(ns.Lines.PlainText(chatFrame), "\n")
	chatDialog.hint:SetText(ns.L.linkHint)
	chatDialog.hint:SetTextColor(Theme.TIME:GetRGB())
	chatDialog:Show()
	chatDialog.box:SetText(chatDialog.text)
	chatDialog.box:GetScrollBox():ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
	chatDialog.box:SetFocus()
	SelectAllChat()
end

-- The tab menu's "Copy chat" (Alerts.lua puts it in the menu, after
-- Everchat's alerts section).
function Links.CreateCopyEntry(chatFrame)
	return MenuUtil.CreateButton(ns.L.copyChat, function()
		Links.ShowChat(chatFrame)
	end)
end

local function OnLinkClicked(_, link, _, button, chatFrame)
	if type(link) ~= "string" then
		return
	end
	local iconLink = ns.Channels.ICON_LINK
	if link:sub(1, #iconLink) == iconLink then
		-- An item's, spell's or quest's icon (Channels.AddIcons): a plain
		-- click opens what the name opens, the game's own sticky tooltip. A
		-- modified click (shift to link it in the chat, ctrl to try it on)
		-- needs the name's full link, which the icon doesn't carry: those are
		-- left to the name.
		if button == "LeftButton" and not IsModifiedClick() then
			local thing = link:sub(#iconLink + 1)
			SetItemRef(thing, thing, button, chatFrame)
		end
	elseif link:sub(1, #LINK_PREFIX) == LINK_PREFIX then
		ShowText(ns.L.linkTitle, link:sub(#LINK_PREFIX + 1))
	elseif link:sub(1, #INVITE_PREFIX) == INVITE_PREFIX then
		-- The left button only, what the hint says. The name as the link
		-- holds it, as the game's right-click Invite passes it
		-- (FriendsFrame_ShowDropdown's contextData.name to InviteUnit). Not
		-- restricted for addons (no HasRestrictions); the game says whether
		-- it worked.
		if button == "LeftButton" and C_PartyInfo and C_PartyInfo.InviteUnit then
			C_PartyInfo.InviteUnit(link:sub(#INVITE_PREFIX + 1))
		end
	elseif link:sub(1, #LINE_PREFIX) == LINE_PREFIX then
		local text = ns.Lines.PlainLine(tonumber(link:sub(#LINE_PREFIX + 1)))
		if text then
			ShowText(ns.L.copyLineTitle, text)
		end
	end
end

-- Hovering an item, spell, achievement or quest link in the chat shows its
-- tooltip, as hovering one anywhere else in the game does (the chat only
-- shows it on click). Through the chat's own "ChatFrame.OnHyperlinkEnter"
-- event, which Blizzard triggers for addons; nothing else listens to it.
local HOVER_TYPES = { item = true, spell = true, enchant = true, achievement = true, quest = true, currency = true }
local hoverOwner, hoverTip
local smallTip

-- Everchat's hints (its controls, the tabs, a line's time) use a small
-- tooltip: at the game's tooltip size they were bigger than the chat they
-- explain ("New tab" over the 13px tabs, a line's date). The options window
-- uses the same frame at the game's size, laid out as its settings' tooltips
-- (the first line in the header font). A tooltip of our own, so
-- GameTooltip's fonts are never changed; one frame for both sizes, so every
-- line's font is set each time. Each line is { text, color, wrap }; x and y
-- offset the anchor. Returns the tooltip, shown.
local function ShowTip(owner, anchor, lines, x, y, small)
	if not smallTip then
		smallTip = CreateFrame("GameTooltip", "BaziEverchatSmallTooltip", UIParent, "GameTooltipTemplate")
	end
	smallTip:SetOwner(owner, anchor, x or 0, y or 0)
	for _, line in ipairs(lines) do
		local r, g, b = line[2]:GetRGB()
		smallTip:AddLine(line[1], r, g, b, line[3])
	end
	local font = small and (GameTooltipTextSmall or GameFontHighlightSmall) or GameTooltipText
	for index = 1, smallTip:NumLines() do
		local header = not small and index == 1 and GameTooltipHeaderText
		_G["BaziEverchatSmallTooltipTextLeft" .. index]:SetFontObject(header or font)
	end
	smallTip:Show()
	return smallTip
end

function Links.ShowSmallTip(owner, anchor, lines, x, y)
	return ShowTip(owner, anchor, lines, x, y, true)
end

function Links.ShowTip(owner, anchor, lines, x, y)
	return ShowTip(owner, anchor, lines, x, y, false)
end

function Links.HideSmallTip(owner)
	if smallTip and smallTip:IsOwned(owner) then
		smallTip:Hide()
	end
end

-- The mouse over a link in a chat window (or Search.lua's results).
function Links.OnHoverLink(owner, link)
	if type(link) ~= "string" or not canaccessvalue(link) then
		return
	end
	-- An icon before a link stands for the same thing (Channels.AddIcons).
	local iconLink = ns.Channels.ICON_LINK
	if link:sub(1, #iconLink) == iconLink then
		link = link:sub(#iconLink + 1)
	end
	-- A web address or an "inv": what a click does.
	local hint = (link:sub(1, #LINK_PREFIX) == LINK_PREFIX and ns.L.linkHoverHint)
		or (link:sub(1, #INVITE_PREFIX) == INVITE_PREFIX and ns.L.inviteHint)
	if hint then
		hoverOwner, hoverTip = owner, Links.ShowSmallTip(owner, "ANCHOR_CURSOR", { { hint, GREEN_FONT_COLOR } })
		return
	end
	-- A line's time: its full date, and that a click copies the line (the
	-- user doubted players would find it otherwise).
	if link:sub(1, #LINE_PREFIX) == LINE_PREFIX then
		local clock = ns.Lines.ClockOf(tonumber(link:sub(#LINE_PREFIX + 1)))
		local lines = {}
		if clock then
			table.insert(lines, { ns.Timestamps.FullDate(clock), Theme.GAME.TAB_TEXT_HOVER })
		end
		table.insert(lines, { ns.L.copyLineHint, GREEN_FONT_COLOR })
		hoverOwner, hoverTip = owner, Links.ShowSmallTip(owner, "ANCHOR_CURSOR", lines)
		return
	end
	local linkType = link:match("^(%a+):")
	-- A player's name: what the game knows about them (Players.lua). The
	-- link carries Blizzard's line ID, which finds the line and its sender.
	if linkType == "player" then
		local name, lineID = link:match("^player:([^:]+):?(%d*)")
		if not name then
			return
		end
		GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
		if ns.Players.FillTooltip(GameTooltip, name, ns.Lines.SenderOf(tonumber(lineID))) then
			GameTooltip:Show()
			hoverOwner, hoverTip = owner, GameTooltip
		else
			GameTooltip:Hide()
		end
		return
	end
	if not HOVER_TYPES[linkType] then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
	GameTooltip:SetHyperlink(link)
	GameTooltip:Show()
	hoverOwner, hoverTip = owner, GameTooltip
end

function Links.OnLeaveLink(owner)
	if hoverOwner == owner and hoverTip and hoverTip:IsOwned(owner) then
		hoverTip:Hide()
	end
	hoverOwner, hoverTip = nil, nil
end

local function OnHyperlinkEnter(_, chatFrame, link)
	Links.OnHoverLink(chatFrame, link)
end

local function OnHyperlinkLeave(_, chatFrame)
	Links.OnLeaveLink(chatFrame)
end

function Links.Init()
	EventRegistry:RegisterCallback("SetItemRef", OnLinkClicked, Links)
	EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", OnHyperlinkEnter, Links)
	EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnHyperlinkLeave, Links)
end
