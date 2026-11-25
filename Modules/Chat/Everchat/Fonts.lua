local ns = BaziUI.Chat

local Fonts = {}
ns.Fonts = Fonts

-- The chat's text is one of Everchat's fonts (Media, SIL OFL, made by
-- art/build-fonts.py with the symbols the game would otherwise draw as "?"):
-- Roboto Condensed by default (the game's Arial Narrow set some letter pairs
-- too tight once the chat went up to 16, and the game has no letter spacing
-- to loosen it), or one of four more, or the game's own, or one that another
-- addon shares through LibSharedMedia-3.0 (below).
-- The size stays Blizzard's per-window setting (right-click > Font Size, and
-- the options' table of tabs); Everchat only raises windows below a default
-- size to it, once per character, and makes its own text follow each
-- window's size: the messages, the edit box (Blizzard leaves it at
-- ChatFontNormal's 14 whatever the window's size), the "Press Enter" hint and
-- the fonts used to measure lines. Tab labels use the same font at one size.
--
-- Fonts are copies of ChatFontNormal's family with the chosen font as the
-- roman and Russian members (Roboto's Cyrillic stands in for a font without
-- it) and the other alphabets scaled alike, so Korean and Chinese text keeps
-- Blizzard's fonts for it (a single font file would turn them into "????").
local MEDIA = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\"
-- The fonts offered, in the options' order; `cyrillic` says whether the file
-- has Cyrillic (Atkinson Hyperlegible Next hasn't: its Russian lines are
-- Roboto's). The labels are the fonts' own names, as every font list in the
-- game's addons names fonts.
Fonts.FONTS = {
	{ key = "roboto", label = "Roboto Condensed", file = MEDIA .. "RobotoCondensed-Regular.ttf", cyrillic = true },
	{ key = "fira", label = "Fira Sans Condensed", file = MEDIA .. "FiraSansCondensed-Regular.ttf", cyrillic = true },
	{ key = "opensans", label = "Open Sans Condensed", file = MEDIA .. "OpenSans-Condensed.ttf", cyrillic = true },
	{ key = "noto", label = "Noto Sans SemiCondensed", file = MEDIA .. "NotoSans-SemiCondensed.ttf", cyrillic = true },
	{ key = "atkinson", label = "Atkinson Hyperlegible Next", file = MEDIA .. "AtkinsonHyperlegibleNext-Regular.ttf", cyrillic = false },
}
local BY_KEY = {}
for _, font in ipairs(Fonts.FONTS) do
	BY_KEY[font.key] = font
end
local DEFAULT_FONT = "roboto"
-- The default size is the smallest of Blizzard's menu sizes whose em is at
-- least MIN_PIXELS screen pixels, so it suits any resolution and interface
-- scale: 14 at 1440p with a 0.69 or a 0.64 scale, 18 at 1080p with a 0.71
-- one. About 17px (Discord's text is 16) keeps the letters' full height,
-- ascenders to descenders, above the Xbox Accessibility Guidelines' 18px for
-- PC; 16.5 rather than 17, since at 1440p and 0.64 size 14 is 16.8px and 16
-- looked oversized there (2026-10-08).
local MIN_PIXELS = 16.5
local MENU_SIZES = { 14, 16, 18 }
-- What v0.21 raised every window to, before the default followed the screen.
local OLD_DEFAULT = 16
-- ChatFontNormal's roman height, the size its members are drawn for.
local BASE_SIZE = 14
local ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }
-- Tab labels are part of the frame, like the 26px header they sit in: one
-- size, whatever the windows' text size (following the main window moved
-- every tab when only General changed, and shrank them to 11 at size 12).
local TAB_SIZE = 13

local families = {}
local listeners = {}

-- Fonts other addons share through LibSharedMedia-3.0 (SharedMedia packs,
-- ElvUI, Details...) are offered after Everchat's own, stored as "lsm:" and
-- the font's name. Everchat doesn't carry the library: it's looked for as
-- Everchat loads and after each addon that loads later, until one brings it.
-- A stored font that no addon shares now (its pack turned off) leaves the
-- chat in the default font and stays stored, so it comes back with its pack;
-- one shared only after login is put on as the library announces it.
local SHARED = "lsm:"
local sharedMedia
-- Set once the chat has its fonts (Fonts.Init).
local ready

local function SharedName(key)
	if type(key) == "string" and key:sub(1, #SHARED) == SHARED then
		return key:sub(#SHARED + 1)
	end
end

-- Font files are tried out on a Font object of their own before use: the
-- game raises an error for a file it doesn't have. The answer is kept per
-- file.
local probeFont = CreateFont("BaziEverchatFontProbe")
local loads = {}

local function Loads(file)
	if loads[file] == nil then
		loads[file] = pcall(probeFont.SetFont, probeFont, file, BASE_SIZE, "")
	end
	return loads[file]
end

-- A shared font's file by its name, while some addon shares it and the file
-- loads.
local function SharedFile(name)
	local files = name and sharedMedia and sharedMedia:HashTable("font")
	local file = files and files[name]
	if type(file) == "string" and Loads(file) then
		return file
	end
end

-- The options' list leaves out the game's own files, which the library
-- lists on its own (Arial Narrow among them, offered already), Everchat's
-- fonts as shared below, and another copy of one of Everchat's fonts under
-- the same name.
local OWN_NAMES, OWN_FILES = {}, {}

local function NormalPath(file)
	return (file:lower():gsub("/", "\\"))
end

for _, font in ipairs(Fonts.FONTS) do
	OWN_NAMES[font.label:lower()] = true
	OWN_FILES[NormalPath(font.file)] = true
end

-- The fonts other addons share, for the options' list ({ key, label }), in
-- the library's order.
function Fonts.Shared()
	local list = {}
	local files = sharedMedia and sharedMedia:HashTable("font")
	if not files then
		return list
	end
	for _, name in ipairs(sharedMedia:List("font")) do
		local file = files[name]
		if type(file) == "string" then
			local path = NormalPath(file)
			if not path:find("^fonts\\") and not OWN_FILES[path] and not OWN_NAMES[name:lower()] and Loads(file) then
				table.insert(list, { key = SHARED .. name, label = name })
			end
		end
	end
	return list
end

-- Everchat's fonts are shared too, for other addons' font lists, each under
-- a name of its own ("Roboto Condensed (Everchat)"): they are Everchat's
-- builds of those fonts, and the library keeps the first file registered
-- under a name, so the plain name would either hand Everchat's build to
-- another addon that ships the original or lose to it. Each one says which
-- languages it draws: the library leaves a font out on a client whose
-- language it doesn't claim.
local function ShareOwnFonts(media)
	local western, russian = media.LOCALE_BIT_western, media.LOCALE_BIT_ruRU
	for _, font in ipairs(Fonts.FONTS) do
		media:Register(media.MediaType.FONT, font.label .. " (Everchat)", font.file,
			font.cyrillic and western + russian or western)
	end
end

local function OnShared(_, mediaType, name)
	if ready and mediaType == "font" and SharedName(ns.db.chatFont) == name then
		Fonts.Refresh()
	end
end

-- Other parts of Everchat that use the library (the sounds) hear when it's
-- found.
local sharedListeners = {}

-- Calls `fn(library)` once the library is found, at once if it already is.
function Fonts.WhenSharedMedia(fn)
	if sharedMedia then
		fn(sharedMedia)
	else
		table.insert(sharedListeners, fn)
	end
end

local function FindSharedMedia()
	if not sharedMedia and LibStub then
		sharedMedia = LibStub("LibSharedMedia-3.0", true)
		if sharedMedia then
			ShareOwnFonts(sharedMedia)
			sharedMedia.RegisterCallback(Fonts, "LibSharedMedia_Registered", OnShared)
			for _, fn in ipairs(sharedListeners) do
				fn(sharedMedia)
			end
			sharedListeners = {}
		end
	end
	return sharedMedia
end

if not FindSharedMedia() then
	local finder = CreateFrame("Frame")
	finder:RegisterEvent("ADDON_LOADED")
	finder:SetScript("OnEvent", function(self)
		if FindSharedMedia() then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end

-- The key of the font chosen (Options > Appearance): one of Fonts.FONTS,
-- "general" for the Bazi UI profile font, or a shared font while available.
function Fonts.Current()
	local key = ns.db.chatFont
	if key == "general" or BY_KEY[key] or SharedFile(SharedName(key)) then
		return key
	end
	return DEFAULT_FONT
end

-- The alphabet of the client's language. On a Russian, Korean or Chinese
-- client the library only lists fonts that claim to draw that language.
local CLIENT_ALPHABET = ({
	koKR = "korean",
	zhCN = "simplifiedchinese",
	zhTW = "traditionalchinese",
	ruRU = "russian",
})[GetLocale()] or "roman"

-- A member of ChatFontNormal's family: its file, height and flags, or the
-- chosen font in its place. A line takes the font of the alphabet its text
-- uses, the time included (a Cyrillic or Korean name switches the whole
-- line). Everchat's fonts draw Latin and, but for Atkinson, Cyrillic; a
-- shared font draws Latin and the client's language. Nothing says whether
-- a shared font has Cyrillic on any other client, and the game draws the
-- letters a font lacks as boxes, so there its Russian lines are Roboto
-- Condensed's, as Atkinson's are. Korean and Chinese otherwise keep
-- Blizzard's fonts, whose wider Latin letters can't be helped without
-- bundling a CJK font. With the game's font chosen (Prat's lesson: players
-- hated a font they couldn't turn back), every member is the game's.
local function OwnFile(alphabet)
	local key = Fonts.Current()
	if key == "general" then
		if alphabet ~= "roman" then return end
		return BaziUI.Typography.Path(BaziUI.db.profile.font)
	end
	local font = BY_KEY[key]
	if font then
		if alphabet == "roman" then
			return font.file
		elseif alphabet == "russian" then
			return font.cyrillic and font.file or BY_KEY[DEFAULT_FONT].file
		end
		return nil
	end
	local file = SharedFile(SharedName(key))
	if not file then
		return nil
	end
	if alphabet == "roman" or alphabet == CLIENT_ALPHABET then
		return file
	elseif alphabet == "russian" then
		return BY_KEY[DEFAULT_FONT].file
	end
end

local function MemberFont(alphabet)
	local member = ChatFontNormal.GetFontObjectForAlphabet and ChatFontNormal:GetFontObjectForAlphabet(alphabet)
	local file, height, flags = (member or ChatFontNormal):GetFont()
	local own = OwnFile(alphabet)
	if own then
		file, height = own, BASE_SIZE
	end
	return file, height or BASE_SIZE, flags or ""
end

-- The letters' edge (Options > Appearance, 2026-10-14, the user's call):
-- the chat's drop shadow, as the game's, or a dark outline, thin or thick,
-- which reads better over bright ground while the chat rests see-through
-- (snow, the Barrens); chat addons offer it (Better Forever Chat, Prat,
-- ElvUI). An outline goes without the shadow. The tabs' labels keep the
-- shadow: they're part of the frame.
local OUTLINES = { none = "", thin = "OUTLINE", thick = "THICKOUTLINE" }

local function Outline(plain)
	return plain and "" or OUTLINES[ns.db.fontOutline] or ""
end

-- Puts a family's members (and the family) at their files, sizes, edge and
-- shadow, for a family just made or after a change of font or edge.
local function Dress(family, size, plain)
	local key = plain and "Chat:Tabs" or "Chat:Messages"
	local _, resolvedSize, outline, choice = BaziUI.Typography.Resolve(key, nil, size, Outline(plain), ns.db.chatFont == "general")
	local shadow = (choice == "on" or choice ~= "off" and outline == "") and 1 or 0
	for _, alphabet in ipairs(ALPHABETS) do
		local member = family:GetFontObjectForAlphabet(alphabet)
		if member then
			local file, height = MemberFont(alphabet)
			if alphabet == "roman" then
				file = BaziUI.Typography.Resolve(key, file, size, outline, ns.db.chatFont == "general")
			end
			member:SetFont(file, height * resolvedSize / BASE_SIZE, outline)
			member:SetShadowOffset(shadow, -shadow)
			member:SetShadowColor(0, 0, 0, 1)
		end
	end
	family:SetShadowOffset(shadow, -shadow)
	family:SetShadowColor(0, 0, 0, 1)
end

local function BuildFamily(name, size, plain)
	local members = {}
	for _, alphabet in ipairs(ALPHABETS) do
		local file, height = MemberFont(alphabet)
		if file then
			table.insert(members, {
				alphabet = alphabet,
				file = file,
				height = height * size / BASE_SIZE,
				flags = Outline(plain),
			})
		end
	end
	local family = CreateFontFamily(name, members)
	Dress(family, size, plain)
	return family
end

-- ChatFontNormal's family at another size, made once per size.
function Fonts.ForSize(size)
	size = math.floor(size + 0.5)
	if not families[size] then
		families[size] = BuildFamily("BaziEverchatChatFont" .. size, size)
	end
	return families[size]
end

-- The family for the tabs' labels and the small text beside them: the
-- chat's font at the tab size, always with its shadow.
local tabFamily

function Fonts.ForTabs()
	if not tabFamily then
		tabFamily = BuildFamily("BaziEverchatTabFont", TAB_SIZE, true)
	end
	return tabFamily
end


-- A window's message size, as Blizzard set it.
function Fonts.GetSize(chatFrame)
	if ns.db.fontSize then return ns.db.fontSize end
	local _, size = chatFrame:GetFont()
	return size or BASE_SIZE
end

-- The family at a window's message size.
function Fonts.ForFrame(chatFrame)
	return Fonts.ForSize(Fonts.GetSize(chatFrame))
end

function Fonts.GetTabSize()
	return TAB_SIZE
end

-- The fonts the options offer for the chat, each as a font object at the
-- chat's base size, made when first asked for: the options' font dropdown
-- names each in its own font, as font pickers do.
local samples = {}
local sampleCount = 0

-- The game's chat font file, the one Everchat's takes the place of
-- (ChatFontNormal's Latin member; its Cyrillic one is the same file).
local function GameFont()
	local member = ChatFontNormal.GetFontObjectForAlphabet and ChatFontNormal:GetFontObjectForAlphabet("roman")
	return (member or ChatFontNormal):GetFont()
end

-- The game's chat font by its name, as every font list names fonts
-- (LibSharedMedia's in ElvUI, Prat, Details; Baganator's "EXPRESSWAY"):
-- Arial Narrow (Fonts\\ARIALN.TTF in Blizzard_Fonts_Shared), or the file's
-- own name should another font be in its place. "The game's" read as cheap
-- next to Roboto Condensed (2026-10-13, the user).
local FONT_NAMES = { arialn = "Arial Narrow", frizqt__ = "Friz Quadrata" }

function Fonts.GameFontName()
	local base = (GameFont() or ""):match("([^\\/]+)%.%w+$") or ""
	return FONT_NAMES[base:lower()] or base
end

-- A font object in one of the fonts offered, by key (the game's for a
-- shared font no addon shares now).
function Fonts.Sample(key)
	local font = BY_KEY[key]
	local file = font and font.file or SharedFile(SharedName(key))
	if not file then
		key = "game"
	end
	if not samples[key] then
		local gameFile, _, flags = GameFont()
		sampleCount = sampleCount + 1
		local sample = CreateFont("BaziEverchatFontSample" .. sampleCount)
		sample:CopyFontObject(GameFontHighlight)
		sample:SetFont(file or gameFile, BASE_SIZE, flags or "")
		-- A font object brings its own justification to what takes it.
		sample:SetJustifyH("LEFT")
		samples[key] = sample
	end
	return samples[key]
end

-- Called with the window whose size changed (and once per window at login).
function Fonts.OnSizeChanged(listener)
	table.insert(listeners, listener)
end

local function Notify(chatFrame)
	for _, listener in ipairs(listeners) do
		listener(chatFrame)
	end
end

-- A window's text laid out anew for another reason than its size (the line
-- spacing, Timestamps.lua): what was measured on it goes.
function Fonts.Changed(chatFrame)
	Notify(chatFrame)
end

local function DefaultSize()
	local _, physicalHeight = GetPhysicalScreenSize()
	local pixelsPerUnit = physicalHeight / UIParent:GetHeight()
	for _, size in ipairs(MENU_SIZES) do
		if size * pixelsPerUnit >= MIN_PIXELS then
			return size
		end
	end
	return MENU_SIZES[#MENU_SIZES]
end

-- Once per character: windows still below the default are raised to it
-- (Blizzard saves the size per window and character), and windows left at
-- v0.21's fixed 16 take the default for this screen. Later choices in
-- Blizzard's menu are the player's and stay.
local function SetDefaultOnce()
	local key = ns.CharacterKey()
	ns.db.fontSized = ns.db.fontSized or {}
	if ns.db.fontSized[key] then
		return
	end
	local raisedBefore = ns.db.fontRaised and ns.db.fontRaised[key]
	local default = DefaultSize()
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local chatFrame = _G["ChatFrame" .. id]
		local _, size = GetChatWindowInfo(id)
		if chatFrame and size and (size < default or (raisedBefore and size == OLD_DEFAULT)) then
			FCF_SetChatWindowFontSize(nil, chatFrame, default)
		end
	end
	ns.db.fontSized[key] = default
	if ns.db.fontRaised then
		ns.db.fontRaised[key] = nil
	end
end

-- A window's messages in Everchat's font at its size. A public
-- ScrollingMessageFrame setter: runs as a secure barrier. A font object brings
-- its own justification (CreateFontFamily's is centered), so the messages get
-- back the left one Blizzard gives them on load (ChatFrameMixin:OnLoad).
local function ApplyToChat(chatFrame)
	chatFrame:SetFontObject(Fonts.ForFrame(chatFrame))
	chatFrame:SetJustifyH("LEFT")
end

local function ApplyToAll()
	for _, name in pairs(CHAT_FRAMES) do
		ApplyToChat(_G[name])
	end
end

-- The options' font or edge changed: every family already made gets the new
-- files and edge for its members (font objects update whatever uses them), then the chat
-- windows lay their lines out again and the listeners (edit boxes, hints)
-- re-measure.
-- Chat bubbles (Options > Appearance > Chat bubbles): their font and size. The game draws every bubble in one font family, ChatBubbleFont,
-- whose Latin member is Friz Quadrata at 13 (its other members drawn about
-- that size), so its members are all there is to set, and that reaches
-- every bubble, those in instances too, where the bubbles themselves are
-- protected. Friz lacks letters other Latin languages need (Turkish ş ğ ı
-- İ, many Polish, Czech or Romanian ones) and can't be extended; the chat's
-- fonts have them. A chosen font takes the Latin member, and the Russian
-- one when it draws Cyrillic; the others keep the game's files. The size
-- scales every member as the game sizes them against Friz's 13.
local BUBBLE_BASE = 13
Fonts.BUBBLE_SIZES = { 10, 11, 12, 13, 14, 15, 16, 18, 20 }
local bubbleOriginals
local bubbleSample

local function BubbleMembers()
	local family = _G.ChatBubbleFont
	if not (family and family.GetFontObjectForAlphabet) then
		return nil
	end
	if not bubbleOriginals then
		bubbleOriginals = {}
		for _, alphabet in ipairs(ALPHABETS) do
			local member = family:GetFontObjectForAlphabet(alphabet)
			if member then
				local file, height, flags = member:GetFont()
				local x, y = member:GetShadowOffset()
				bubbleOriginals[alphabet] = { member = member, file = file, height = height, flags = flags or "", x = x, y = y }
			end
		end
	end
	return bubbleOriginals
end

-- The bubbles' font, by the keys the chat's fonts go by; "friz", the game's
-- own, by default.
function Fonts.BubbleFont()
	local key = ns.db.bubbleFont
	if type(key) ~= "string" or key == "friz" then
		return "friz"
	end
	if key == "game" or BY_KEY[key] or SharedFile(SharedName(key)) then
		return key
	end
	return "friz"
end

local function BubbleFile(key, alphabet)
	local font = BY_KEY[key]
	if alphabet == "roman" then
		if font then
			return font.file
		elseif key == "game" then
			return (GameFont())
		end
		return SharedFile(SharedName(key))
	elseif alphabet == "russian" and font and font.cyrillic then
		return font.file
	end
end

function Fonts.ApplyBubbles()
	local members = BubbleMembers()
	if not members then
		return
	end
	local key = Fonts.BubbleFont()
	local size = tonumber(ns.db.bubbleSize) or BUBBLE_BASE
	for alphabet, original in pairs(members) do
		local file = key ~= "friz" and BubbleFile(key, alphabet) or original.file
		original.member:SetFont(file, original.height * size / BUBBLE_BASE, original.flags)
	end
end

-- A font object in a bubble font offered, for its name in the options' list
-- (Friz Quadrata in its own file).
function Fonts.BubbleSample(key)
	if key ~= "friz" then
		return Fonts.Sample(key)
	end
	if not bubbleSample then
		local members = BubbleMembers()
		local original = members and members.roman
		bubbleSample = CreateFont("BaziEverchatFontSampleFriz")
		bubbleSample:CopyFontObject(GameFontHighlight)
		if original then
			bubbleSample:SetFont(original.file, BASE_SIZE, "")
		end
		bubbleSample:SetJustifyH("LEFT")
	end
	return bubbleSample
end

function Fonts.Refresh()
	for size, family in pairs(families) do
		Dress(family, size)
	end
	if tabFamily then
		Dress(tabFamily, TAB_SIZE, true)
	end
	ApplyToAll()
	for _, name in pairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		chatFrame:MarkLayoutDirty()
		Notify(chatFrame)
	end
	-- Tab widths follow their labels.
	ns.Header.Relayout()
	Fonts.ApplyBubbles()
end

-- Sets every window to the default size for this screen now (/everchat font
-- reset): for windows another addon left small (Prat's Font module sets all to
-- 12 through Blizzard's function, which saves it per window).
function Fonts.ResetSizes()
	local default = DefaultSize()
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local chatFrame = _G["ChatFrame" .. id]
		if chatFrame then
			FCF_SetChatWindowFontSize(nil, chatFrame, default)
		end
	end
	ns.db.fontSized = ns.db.fontSized or {}
	ns.db.fontSized[ns.CharacterKey()] = default
	return default
end

-- The one-time default runs again on the next load (Conflicts.lua, when the
-- other chat addon is disabled: it may have overridden Everchat's sizes).
function Fonts.Rearm()
	if ns.db.fontSized then
		ns.db.fontSized[ns.CharacterKey()] = nil
	end
end

-- An edit box found with a font other than its window's, this session
-- (EditBox.lua puts the window's back): what it had, for /everchat font.
local foreignFont

function Fonts.NoteForeignFont(editBox)
	local file, height = editBox:GetFont()
	local object = editBox:GetFontObject()
	foreignFont = ("%s: %s at %.1f, font object %s, %s"):format(editBox:GetName() or "?",
		tostring(file and file:match("[^\\/]+$")), height or 0,
		tostring(object and object:GetName()), date("%H:%M:%S"))
end

-- For /everchat font: what the screen and each open window say.
-- Measures text for the report; never shown.
local reportProbe

function Fonts.Report()
	local _, physicalHeight = GetPhysicalScreenSize()
	local key = ns.CharacterKey()
	ns.Print(("Screen %dpx tall, interface scale %.2f, %.2f px per unit; default size %d (applied once: %s)."):format(
		physicalHeight, UIParent:GetEffectiveScale(), physicalHeight / UIParent:GetHeight(), DefaultSize(),
		tostring(ns.db.fontSized and ns.db.fontSized[key])))
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local chatFrame = _G["ChatFrame" .. id]
		local name, size = GetChatWindowInfo(id)
		if chatFrame and (chatFrame.isDocked or chatFrame:IsShown()) then
			local file, height = chatFrame:GetFont()
			ns.Print(("  %s: menu size %s, font %s at %.1f"):format(
				name or "?", tostring(size), tostring(file and file:match("[^\\/]+$")), height or 0))
		end
	end
	-- The space between words as the game lays it out, in screen pixels: it
	-- draws each glyph a whole number of pixels wide (art/font-spacing.py:
	-- Everchat's retouched Roboto gives 3 at size 14 on a 1440p screen, 4
	-- before; only a full restart loads a changed font file).
	reportProbe = reportProbe or UIParent:CreateFontString()
	local probe = reportProbe
	probe:Hide()
	probe:SetFontObject(Fonts.ForFrame(DEFAULT_CHAT_FRAME))
	probe:SetText("n n")
	local spaced = probe:GetUnboundedStringWidth()
	probe:SetText("nn")
	local space = spaced - probe:GetUnboundedStringWidth()
	ns.Print(("  Space between words: %.1f px."):format(space / PixelUtil.ConvertPixelsToUIForRegion(1, probe)))
	if foreignFont then
		ns.Print("  Typing box found in another font (put back): " .. foreignFont)
	end
end

-- Before the skins: they read the sizes.
function Fonts.Init()
	SetDefaultOnce()
	ApplyToAll()
	Fonts.ApplyBubbles()
	-- Blizzard sets a size by SetFont with the window's current font file
	-- (just ours, without the other alphabets): put the whole family back.
	hooksecurefunc("FCF_SetChatWindowFontSize", function(_, chatFrame)
		chatFrame = chatFrame or FCF_GetCurrentChatFrame()
		if chatFrame then
			ApplyToChat(chatFrame)
			Notify(chatFrame)
		end
	end)
	hooksecurefunc("FCF_OpenTemporaryWindow", ApplyToAll)
	-- The game's "reset chat windows" puts every window at the game's default
	-- size, too big on a 1440p screen: the player asked for defaults, so they
	-- get this screen's default. FCF_ResetChatWindows ends by resetting the
	-- saved settings (ResetChatWindows), which the windows load back on the
	-- next UPDATE_CHAT_WINDOWS, after this hook: the sizes go on after that
	-- (a second later at the latest).
	local afterReset = CreateFrame("Frame")
	local function ApplyAfterReset()
		if afterReset:IsEventRegistered("UPDATE_CHAT_WINDOWS") then
			afterReset:UnregisterEvent("UPDATE_CHAT_WINDOWS")
			Fonts.ResetSizes()
		end
	end
	afterReset:SetScript("OnEvent", ApplyAfterReset)
	hooksecurefunc("FCF_ResetChatWindows", function()
		afterReset:RegisterEvent("UPDATE_CHAT_WINDOWS")
		C_Timer.After(1, ApplyAfterReset)
	end)
	ready = true
end
