local ns = BaziUI.Chat

-- Shared look ("Forever sutil" in the look book).
local Theme = {}
ns.Theme = Theme

-- The game's gold: what the chat says in gold (mentions, links, unread
-- marks of several kinds) keeps it in every theme.
Theme.GOLD = CreateColor(1, 0.82, 0) -- NORMAL_FONT_COLOR
-- Message area. The header holding the tabs (Theme.HEADER, below) is
-- lighter: it has to read as a bar above the messages (with nearly the
-- body's color, 30/24/17, and a 14% line, messages scrolling under it looked
-- cut off against nothing). A shade over the messages under it was tried and
-- dropped: on the faded, see-through card it doubled the darkness into a band.
Theme.BODY = CreateColor(12 / 255, 10 / 255, 8 / 255, 0.89)
-- Warm grey: present but quieter than any chat color.
Theme.TIME = CreateColor(0.55, 0.52, 0.48)

-- The chat's look, chosen in the options (Appearance > Window: Theme and
-- Minimal style): the open tab's metal frame, the lines where the header and
-- footer meet the messages, the tab names, Everchat's glyphs and the rail's
-- buttons, and the header's color. Gold is the game's own; Silver and Bronze
-- are the same pieces in another metal. The minimal style, in any of them,
-- has no frame: the open tab is marked by its name and by the header's line,
-- faint elsewhere and lit under it (MINIMAL). What the game sets (the
-- background's color and opacity, in each tab's menu), the messages, the
-- unread dots and the crest look the same in every theme, and the options
-- window keeps the game's gold (Theme.GAME), like the game's own settings.
--
-- Gold's colors:
-- HEADER: the header (and footer and rail) fill.
-- LINE and its two alphas: the line on the strip's last row and the fainter
-- row inside it that softens it (a lone 1px line looked ruled, "web").
-- TAB_TEXT, _HOVER, TAB_OPEN: tab names at rest a muted gold (a warm tan
-- read less like the game), lighter under the mouse, the open tab's in gold.
-- GLYPH, _HOVER: Everchat's glyphs on the chat (the "+", the chevrons, the
-- grips, the scroll bar), like the glyphs on Blizzard's chat buttons,
-- brighter under the mouse, with a soft glow (GLOW, Media/Halo) behind them
-- instead of a lighter square. The current game's look: flat surfaces, gold
-- accents, thin metal lines and glows, not 2004's textures and bevels.
-- RAIL_ICON: Everchat's white rail glyphs tinted like the game's gold ones.
-- THUMB, _HOVER: the scroll bar's thumb, bronze-gold, gold under the mouse.
-- RIM_TOP: the open tab's frame at its top, light metal; down its sides it
-- turns into the header's line (LINE at HEADER_LINE_ALPHA) where they meet
-- (Tabs.lua).
-- ART: art drawn in gold (the header's icons, the grips, the game's chat
-- buttons) is shown as drawn in Gold; in the other themes it's turned grey
-- and tinted with ART (Theme.PaintArt), no other art needed.
-- FIELD_EDGE: the edit box's field's edge; FIELD_EDGE_REST, how much of it
-- shows while nobody types (while typing it takes the chat type's color).
-- HAIRLINE: a faint light line 1px outside the card.
-- OPEN_TAB_MARK: "frame" (the open tab's block in its metal frame, the
-- header's line open under it), "line" (no block; the line under the open
-- tab lit, LINE_LIT_ALPHA and _SOFT_ALPHA, LINE_LIT_INSET units in from its
-- sides) or "game" (the game's own tab art, GAME_ART).
-- LINE_HOVER_ALPHA and _SOFT_ALPHA: a tab under the mouse lights its stretch
-- of the line (only without a frame; a framed theme lightens the tab).
-- STRIP_AS_BODY: the header and footer drawn as the message area, one
-- surface (otherwise in HEADER, a lighter strip). RAIL_PANEL: the side
-- bar's panel behind its buttons. CARD_SHADOW: the card's shadow and the
-- light line around it. STRIP_HIDDEN: no header or footer fill at all, the
-- tabs and the field standing over the world.
-- GAME_ART: the game's own tabs, tab font and field box instead of
-- Everchat's (Tabs.lua, EditBox.lua); the minimal style doesn't apply.
local PALETTES = {
	gold = {
		HEADER = { 42 / 255, 34 / 255, 24 / 255, 0.93 },
		LINE = { 1, 0.82, 0 },
		HEADER_LINE_ALPHA = 0.30,
		HEADER_LINE_SOFT_ALPHA = 0.10,
		TAB_TEXT = { 0.80, 0.69, 0.43 },
		TAB_TEXT_HOVER = { 0.96, 0.86, 0.58 },
		TAB_OPEN = { 1, 0.82, 0 },
		GLYPH = { 1, 0.82, 0, 0.8 },
		GLYPH_HOVER = { 1, 0.93, 0.6, 1 },
		GLOW = { 1, 0.82, 0 },
		RAIL_ICON = { 1, 0.82, 0 },
		THUMB = { 0.78, 0.6, 0.3, 0.9 },
		THUMB_HOVER = { 1, 0.82, 0, 1 },
		RIM_TOP = { 1, 0.886, 0.588 },
		ART = { 1, 1, 1 },
		ART_TINTED = false,
		FIELD_EDGE = { 0.67, 0.55, 0.35, 0.6 },
		HAIRLINE = { 1, 0.93, 0.75, 0.1 },
		OPEN_TAB_MARK = "frame",
		LINE_LIT_ALPHA = 0,
		LINE_LIT_SOFT_ALPHA = 0,
		LINE_HOVER_ALPHA = 0,
		LINE_HOVER_SOFT_ALPHA = 0,
		FIELD_EDGE_REST = 1,
		STRIP_AS_BODY = false,
		RAIL_PANEL = true,
		CARD_SHADOW = true,
		STRIP_HIDDEN = false,
		GAME_ART = false,
	},
	-- Gold's pieces in cool silver, the header a little colder.
	silver = {
		HEADER = { 33 / 255, 34 / 255, 39 / 255, 0.93 },
		LINE = { 0.80, 0.84, 0.90 },
		HEADER_LINE_ALPHA = 0.30,
		HEADER_LINE_SOFT_ALPHA = 0.10,
		TAB_TEXT = { 0.66, 0.69, 0.75 },
		TAB_TEXT_HOVER = { 0.88, 0.90, 0.95 },
		TAB_OPEN = { 0.93, 0.95, 1 },
		GLYPH = { 0.80, 0.84, 0.90, 0.8 },
		GLYPH_HOVER = { 0.94, 0.96, 1, 1 },
		GLOW = { 0.75, 0.82, 0.95 },
		RAIL_ICON = { 0.80, 0.84, 0.90 },
		THUMB = { 0.64, 0.67, 0.72, 0.9 },
		THUMB_HOVER = { 0.88, 0.91, 0.97, 1 },
		RIM_TOP = { 0.86, 0.886, 0.957 },
		ART = { 0.93, 0.96, 1 },
		ART_TINTED = true,
		FIELD_EDGE = { 0.55, 0.58, 0.64, 0.6 },
		HAIRLINE = { 0.88, 0.92, 1, 0.1 },
		OPEN_TAB_MARK = "frame",
		LINE_LIT_ALPHA = 0,
		LINE_LIT_SOFT_ALPHA = 0,
		LINE_HOVER_ALPHA = 0,
		LINE_HOVER_SOFT_ALPHA = 0,
		FIELD_EDGE_REST = 1,
		STRIP_AS_BODY = false,
		RAIL_PANEL = true,
		CARD_SHADOW = true,
		STRIP_HIDDEN = false,
		GAME_ART = false,
	},
	-- Gold's pieces in bronze: quieter, less shine.
	bronze = {
		HEADER = { 44 / 255, 32 / 255, 26 / 255, 0.93 },
		LINE = { 0.80, 0.60, 0.36 },
		HEADER_LINE_ALPHA = 0.30,
		HEADER_LINE_SOFT_ALPHA = 0.10,
		TAB_TEXT = { 0.72, 0.58, 0.43 },
		TAB_TEXT_HOVER = { 0.90, 0.76, 0.58 },
		TAB_OPEN = { 0.92, 0.70, 0.42 },
		GLYPH = { 0.80, 0.60, 0.36, 0.8 },
		GLYPH_HOVER = { 0.95, 0.78, 0.55, 1 },
		GLOW = { 1, 0.68, 0.38 },
		RAIL_ICON = { 0.80, 0.60, 0.36 },
		THUMB = { 0.64, 0.48, 0.29, 0.9 },
		THUMB_HOVER = { 0.92, 0.70, 0.42, 1 },
		RIM_TOP = { 1, 0.815, 0.549 },
		ART = { 0.98, 0.76, 0.48 },
		ART_TINTED = true,
		FIELD_EDGE = { 0.62, 0.48, 0.32, 0.6 },
		HAIRLINE = { 1, 0.90, 0.78, 0.1 },
		OPEN_TAB_MARK = "frame",
		LINE_LIT_ALPHA = 0,
		LINE_LIT_SOFT_ALPHA = 0,
		LINE_HOVER_ALPHA = 0,
		LINE_HOVER_SOFT_ALPHA = 0,
		FIELD_EDGE_REST = 1,
		STRIP_AS_BODY = false,
		RAIL_PANEL = true,
		CARD_SHADOW = true,
		STRIP_HIDDEN = false,
		GAME_ART = false,
	},
	-- The chat as the game drew it before Everchat: its own tabs (their
	-- dark tops, the open one lit, the light under the mouse) in its font and
	-- gold, floating over the messages with no strip behind them, no line,
	-- shadow or side bar panel, and its own box around the field.
	classic = {
		HEADER = { 42 / 255, 34 / 255, 24 / 255, 0 },
		LINE = { 1, 0.82, 0 },
		HEADER_LINE_ALPHA = 0,
		HEADER_LINE_SOFT_ALPHA = 0,
		TAB_TEXT = { 1, 0.82, 0 },
		TAB_TEXT_HOVER = { 1, 0.82, 0 },
		TAB_OPEN = { 1, 0.82, 0 },
		GLYPH = { 1, 0.82, 0, 0.8 },
		GLYPH_HOVER = { 1, 0.93, 0.6, 1 },
		GLOW = { 1, 0.82, 0 },
		RAIL_ICON = { 1, 0.82, 0 },
		THUMB = { 0.78, 0.6, 0.3, 0.9 },
		THUMB_HOVER = { 1, 0.82, 0, 1 },
		RIM_TOP = { 1, 0.886, 0.588 },
		ART = { 1, 1, 1 },
		ART_TINTED = false,
		FIELD_EDGE = { 0.67, 0.55, 0.35, 0.6 },
		HAIRLINE = { 1, 0.93, 0.75, 0.1 },
		OPEN_TAB_MARK = "game",
		LINE_LIT_ALPHA = 0,
		LINE_LIT_SOFT_ALPHA = 0,
		LINE_HOVER_ALPHA = 0,
		LINE_HOVER_SOFT_ALPHA = 0,
		FIELD_EDGE_REST = 0,
		STRIP_AS_BODY = false,
		RAIL_PANEL = false,
		CARD_SHADOW = false,
		STRIP_HIDDEN = true,
		GAME_ART = true,
	},
}

-- The minimal style over a theme: no frame on the open tab, the header's
-- line faint and lit under the open tab. As thin as the frame's lines, and
-- quieter than the tab's name (a 2px bar under it weighed more than the name
-- itself). A tab under the mouse lights its own stretch of the line, about
-- half as much, instead of a lighter block. The card is one surface: the
-- header and footer take the message area's color and see-through, the
-- side bar's buttons stand on their own as the game's chat buttons do, with
-- no panel behind them, the card lies flat (no shadow or light line around
-- it), and the field shows its edge only while typing.
local MINIMAL = {
	OPEN_TAB_MARK = "line",
	HEADER_LINE_ALPHA = 0.1,
	HEADER_LINE_SOFT_ALPHA = 0,
	LINE_LIT_ALPHA = 0.55,
	LINE_LIT_SOFT_ALPHA = 0.15,
	LINE_HOVER_ALPHA = 0.28,
	LINE_HOVER_SOFT_ALPHA = 0.08,
	FIELD_EDGE_REST = 0,
	STRIP_AS_BODY = true,
	RAIL_PANEL = false,
	CARD_SHADOW = false,
}

-- The themes, in the options' order. Each palette must name every color, and
-- the minimal style only names some of them: one left out would keep the
-- previous theme's (tools/theme_test.lua checks).
Theme.THEMES = { "gold", "silver", "bronze", "classic" }
-- What the options offer: a style (Everchat's own look, its minimal one or
-- the game's) and, but for the game's, its metal (a palette).
Theme.STYLES = { "everchat", "minimal", "classic" }
Theme.METALS = { "gold", "silver", "bronze" }
Theme.PALETTES = PALETTES
Theme.MINIMAL = MINIMAL
Theme.LINE_LIT_INSET = 3

local function Build(palette)
	local set = {}
	for name, value in pairs(palette) do
		if type(value) == "table" then
			set[name] = CreateColor(value[1], value[2], value[3], value[4] or 1)
		else
			set[name] = value
		end
	end
	return set
end

-- Gold, fixed: the options window's look.
Theme.GAME = Build(PALETTES.gold)
for name, value in pairs(Build(PALETTES.gold)) do
	Theme[name] = value
end
Theme.current = "gold"
Theme.minimal = false

local listeners = {}

-- `listener()` runs after every change of theme.
function Theme.OnChanged(listener)
	table.insert(listeners, listener)
end

local function Copy(values)
	for name, value in pairs(values) do
		if type(value) == "table" then
			Theme[name]:SetRGBA(value[1], value[2], value[3], value[4] or 1)
		else
			Theme[name] = value
		end
	end
end

-- Makes `key` the chat's theme (gold for an unknown one), in the minimal
-- style with `minimal`: its colors go into the live color objects, then the
-- listeners repaint.
function Theme.Set(key, minimal)
	Theme.current = PALETTES[key] and key or "gold"
	Theme.minimal = minimal and true or false
	Copy(PALETTES[Theme.current])
	if Theme.minimal and not Theme.GAME_ART then
		Copy(MINIMAL)
	end
	local border = ns.db and ns.db.borderColor
	if border and Theme.LINE then Theme.LINE:SetRGBA(border[1], border[2], border[3], Theme.LINE.a) end
	for _, listener in ipairs(listeners) do
		listener()
	end
end

-- The palette for a style and its metal (the options' choices): the classic
-- style has its own, the others take the metal.
function Theme.PaletteFor(style, metal)
	if style == "classic" then
		return "classic"
	end
	return metal
end

-- Whether a style is the minimal one.
function Theme.IsMinimal(style)
	return style == "minimal"
end

-- Art drawn in gold, as the theme shows it: as drawn in Gold, otherwise grey
-- tinted with the theme's metal. `shade` darkens it (1 under the mouse). A
-- texture's vertex alpha is its alpha (SetAlpha sets the same value), so
-- without `alpha` the texture keeps the one it has: the game fades some of
-- its buttons' pictures in and out that way.
function Theme.PaintArt(texture, shade, alpha)
	local art = Theme.ART
	shade = shade or 1
	texture:SetDesaturated(Theme.ART_TINTED)
	texture:SetVertexColor(shade * art.r, shade * art.g, shade * art.b, alpha or texture:GetAlpha())
end

-- The red slash over a muted switch's glyph, the game's own (its muted voice
-- icons on the chat's rail, chatframe-button-icon-mic-off).
Theme.SLASH = CreateColor(238 / 255, 8 / 255, 0)
-- The header's gold icons (the "+", the chevron; art/add-icons.py): 16
-- screen pixels (times the art's scale), a little darker at rest.
Theme.ICON_PIXELS = 16
Theme.ICON_REST = 0.85
Theme.GLOW_TEXTURE = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\Halo"
Theme.GLOW_SIZE = 26
Theme.GLOW_HOVER_ALPHA = 0.35
Theme.GLOW_OPEN_ALPHA = 0.5

-- The chat at rest (the mouse away, nobody typing), against 1 under the
-- mouse, as the game's own chat rests (FloatingChatFrame.lua): the open tab's
-- name at 40% and the others at 20%, the controls ("+", chevron, grips, the
-- field) with the open tab. The header, footer and side bar take the message
-- area's color and alpha, so the card rests as one plain shape, without its
-- gold lines and shadow; the message area keeps some of its fill so the text
-- reads on bright ground, and never less than the window's own opacity
-- (Skin.lua).
Theme.REST_BODY = 0.45
Theme.REST_OPEN_TAB = CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA or 0.4
Theme.REST_TAB = CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA or 0.2
-- A tab with unread messages keeps its name at full, as the game's alerting
-- tabs do, in its usual muted color and without the open tab's frame: easy to
-- read at a glance, not taken for the open one (2026-10-12, the user: at 20%
-- the name beside its dot was hard to read).
Theme.REST_ALERT = CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA or 1
Theme.REST_CONTROLS = Theme.REST_OPEN_TAB

-- Hidden at rest (chatRest = "hidden", Skin.lua): every
-- piece rests at nothing, and the alerts that always show go too.
Theme.hiddenAtRest = false

-- An alpha between its resting value (lit 0) and full (lit 1).
function Theme.Rest(rest, lit)
	if Theme.hiddenAtRest then
		return lit
	end
	return rest + (1 - rest) * lit
end

-- Blizzard leaves the chat text 2px from its Background; the panel reaches further left.
Theme.PANEL_PAD_LEFT = 6
-- Header above the message area, a little taller than the game's own tabs
-- (Blizzard's dock, the frame that holds the docked tabs and that paints the
-- header for docked windows, is set to it: Tabs.lua).
Theme.HEADER_HEIGHT = 23
-- The hairline (Theme.HAIRLINE) lies 1px outside the card (the shadow
-- reaches further, but it may go off screen).
Theme.EDGE_OUTSET = 1
-- Footer holding the edit box's field.
Theme.FOOTER_HEIGHT = 34
-- The field: darker than the card, with its edge (Theme.FIELD_EDGE).
Theme.FIELD = CreateColor(0, 0, 0, 0.5)
Theme.FIELD_HOVER = CreateColor(0.16, 0.13, 0.09, 0.6)
-- Corner radii in screen pixels (Media has art for 3, 4, 5, 6 and 7): the
-- card, the boxes in the footer and the tabs. Tabs start at the card's edge,
-- so the first one's corner is the card's own. The open tab's sides curve
-- into the header's line with a small radius, just enough to take the edge
-- off the corner (Tabs.lua's feet).
Theme.CARD_RADIUS = 6
Theme.INSET_RADIUS = 4
Theme.TAB_RADIUS = Theme.CARD_RADIUS
Theme.TAB_FOOT = 3
-- Height of the boxes in the footer (the field, the padlock button).
Theme.INSET_HEIGHT = 24


-- The game's own interface sounds, where its panels play them: a checkbox
-- ticked or cleared (its settings), a page tab (its settings' tabs), a
-- panel's button (its game menu), a button on the chat's side bar (its
-- channels button), and a window opening and closing (its game menu).
-- Dropdowns and their menus play theirs already.
local SOUNDS = {
	check = "IG_MAINMENU_OPTION_CHECKBOX_ON",
	uncheck = "IG_MAINMENU_OPTION_CHECKBOX_OFF",
	tab = "IG_CHARACTER_INFO_TAB",
	button = "IG_MAINMENU_OPTION",
	rail = "IG_CHAT_EMOTE_BUTTON",
	open = "IG_MAINMENU_OPEN",
	close = "IG_MAINMENU_CLOSE",
	lock = "UI_70_ARTIFACT_FORGE_APPEARANCE_LOCKED",
	unlock = "KEY_RING_OPEN",
}

function Theme.PlaySound(kind)
	local id = SOUNDS[kind] and SOUNDKIT[SOUNDS[kind]]
	if id then
		PlaySound(id)
	end
end

-- A checkbox's sound for the state it just took.
function Theme.PlayCheck(checked)
	Theme.PlaySound(checked and "check" or "uncheck")
end

-- A window of ours sounds as it opens and closes.
function Theme.SoundOnShow(frame)
	frame:HookScript("OnShow", function()
		Theme.PlaySound("open")
	end)
	frame:HookScript("OnHide", function()
		Theme.PlaySound("close")
	end)
end
