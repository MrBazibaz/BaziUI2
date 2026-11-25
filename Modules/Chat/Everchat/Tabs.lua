local ns = BaziUI.Chat
local Theme = ns.Theme

local Tabs = {}
ns.Tabs = Tabs


-- Blizzard's tab art; the header replaces it.
local TAB_ART = {
	"Left", "Middle", "Right",
	"ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
}

-- Each tab owns its whole slice of the header. The active one is open into
-- the message area: its block runs from the header's color at its top to the
-- message area's at its bottom (the header's fill is open under it,
-- Skin.lua), so it melts into both at any opacity, framed by one line of the
-- theme's metal, light at the top and running down its sides into the
-- header's line, with a soft light under its top edge. In a theme without
-- metal (Theme.OPEN_TAB_MARK "line") only its name marks it, and the header's
-- line lit under it (Skin.lua). Tabs stand on the header's bottom edge, so
-- heights are measured up from the tab's bottom. The drag ghost and the
-- options window's page tabs stand on a fill that stays under them: their
-- blocks go from clear to the body's color.
local FILL_ALPHA = 0.95
local HOVER_ALPHA = 0.05
-- The frame's top, a little short of solid; its sides end in the line's own
-- color and strength (Theme.LINE, HEADER_LINE_ALPHA), so frame and line read
-- as one thread. Only the active tab has a frame: one around the whole chat
-- made it a separate box (the game's chat and other chat addons have none),
-- and three rings (a dark line around a light row and a deeper one) on a
-- near-opaque block weighed more than the chat around it.
local RIM_TOP_ALPHA = 0.9
-- The light under the frame's top edge: the metal's color, gone two fifths
-- of the way down.
local GLOW_ALPHA = 0.16
local GLOW_SHARE = 0.4
-- The frame's feet, in screen pixels: at the bottom each side curves out into
-- the header's line (Theme.TAB_FOOT), over the corner the curve leaves on the
-- tab's side, filled like the tab (Media/Notch, what a rounded corner leaves
-- out). The header's line opens around them (Tabs.OpenGap), its row inside
-- reaching SOFT_REACH pixels further, to the curve's inner side; the
-- header's fill reaches under the frame's sides, its runs' rounded corners
-- being the curves' other side.
local FOOT = Theme.TAB_FOOT
local SOFT_REACH = 1

-- Our state lives here, never as keys on Blizzard frames.
local tabParts = {}
-- The drag ghosts (Header.lua makes one).
local ghosts = {}

local function Framed()
	return Theme.OPEN_TAB_MARK == "frame"
end

-- The tabs' font: the chat's at the tab size (Fonts.lua), or the game's own
-- tabs' with their art (Theme.GAME_ART).
local function TabFont()
	if Theme.GAME_ART then
		return GameFontNormalSmall
	end
	return ns.Fonts.ForTabs()
end

-- A tab is a button, which puts its normal or highlight font object back on
-- its label as the mouse comes and goes, so those are set too.
local function SetLabelFont(text, tab)
	local font = TabFont()
	if tab then
		tab:SetNormalFontObject(font)
		tab:SetHighlightFontObject(font)
		tab:SetDisabledFontObject(font)
	end
	text:SetFontObject(font)
end

-- The feet's curves (and a side's straight end at the card's edge), in the
-- line's color and strength as the frame fades.
local function PaintFeet(look)
	local line = look.palette.LINE
	for _, ring in ipairs(look.rings) do
		ring:SetVertexColor(line.r, line.g, line.b)
		ring:SetAlpha(look.rimAlpha * look.palette.HEADER_LINE_ALPHA * look.lineFactor)
	end
end

-- The frame's sides end in the line's strength, which also follows the
-- window's background opacity (Skin.lua, `lineFactor`), so the frame never
-- meets a fainter line.
local function PaintLook(look, palette)
	look.palette = palette
	local top, line = palette.RIM_TOP, palette.LINE
	look.rimTop:SetRGBA(top.r, top.g, top.b, RIM_TOP_ALPHA)
	look.rimBottom:SetRGBA(line.r, line.g, line.b, palette.HEADER_LINE_ALPHA * look.lineFactor)
	look.rim:SetVerticalGradient(look.rimTop, look.rimBottom)
	look.glowTop:SetRGBA(top.r, top.g, top.b, GLOW_ALPHA)
	look.glowBottom:SetRGBA(top.r, top.g, top.b, 0)
	look.glow:SetFillGradient(look.glowTop, look.glowBottom, look.glowHeight)
	PaintFeet(look)
end

-- The block between the frame's sides, or under the left one too while it
-- runs down the card's edge. There its top-left corner is the card's own, so
-- it's rounded like the frame: square, the world showed through the frame's
-- curve with the block's corner standing past it.
local function PlaceBlock(look)
	local px = look.px
	local inset = look.feet and px or 0
	look.place(look.block, -px, look.leftFoot and inset or 0, inset)
	look.block:SetCornerRadius("TOPLEFT", look.feet and not look.leftFoot and Theme.TAB_RADIUS or nil)
end

-- The active look on a tab, the drag ghost or a page tab: the block, the
-- frame and the light under its top. `place(shape, bottom, left, right)`
-- anchors a shape to the header-tall box (`height`, the chat's header by
-- default), its bottom at `bottom` and its sides `left` and `right` in, and
-- can place it again. The block reaches
-- through the header's line (its last two rows, Skin.lua) to a pixel below
-- the box, square: at its top it has the header's color, and the frame draws
-- the round corners (rounded, its corners outside the curve let the world
-- show through the header's opening). `palette` holds the metal's colors.
-- With `feet` the frame's sides stop above the line and curve out into it,
-- standing on the header's fill, which reaches under them, so the block
-- stops inside them; a left side at the card's edge (Tabs.SetLeftFoot) runs
-- straight down it instead, over the block. Without (the drag ghost, over
-- the line), the sides run down through the line.
local function AddLook(owner, place, px, palette, feet, height)
	height = height or Theme.HEADER_HEIGHT
	local look = {
		place = place,
		px = px,
		height = height,
		glowHeight = height * GLOW_SHARE,
		feet = feet,
		leftFoot = feet,
		block = ns.Shapes.Fill(owner, "BACKGROUND", 0, Theme.TAB_RADIUS, "NONE"),
		rim = place(ns.Shapes.Outline(owner, "BORDER", 1, Theme.TAB_RADIUS, "TOP", "BOTTOM"), feet and FOOT * px or -px),
		glow = ns.Shapes.Fill(owner, "BACKGROUND", 1, Theme.TAB_RADIUS - 1, "TOP"),
		rings = {},
		notches = {},
		left = {},
		rimAlpha = 1,
		lineFactor = 1,
		blockHeight = height + px,
		blockTop = CreateColor(0, 0, 0, 0),
		blockBottom = CreateColor(0, 0, 0, 0),
		rimTop = CreateColor(1, 1, 1, 1),
		rimBottom = CreateColor(1, 1, 1, 1),
		glowTop = CreateColor(1, 1, 1, 1),
		glowBottom = CreateColor(1, 1, 1, 0),
	}
	PlaceBlock(look)
	look.glow:SetPoint("TOPLEFT", look.rim.box, "TOPLEFT", px, -px)
	look.glow:SetPoint("TOPRIGHT", look.rim.box, "TOPRIGHT", -px, -px)
	look.glow:SetHeight(look.glowHeight)
	look.pieces = { look.block, look.rim, look.glow }
	if feet then
		-- Each foot's square stands on the header's bottom, its inner column
		-- the frame's side: a curve from the side down into the line's row
		-- (Ring) over the corner under it (Notch), mirrored for each side.
		local function Foot(point, anchor, x, pieces)
			local notch = ns.Shapes.Corner(owner, "BACKGROUND", 0, "Notch", FOOT, point)
			local ring = ns.Shapes.Corner(owner, "BORDER", 1, "Ring", FOOT, point)
			for _, piece in ipairs({ notch, ring }) do
				piece:SetPoint(point, look.rim.box, anchor, x, -FOOT * px)
				table.insert(pieces, piece)
			end
			table.insert(look.rings, ring)
			table.insert(look.notches, notch)
		end
		Foot("BOTTOMLEFT", "BOTTOMRIGHT", -px, look.pieces)
		Foot("BOTTOMRIGHT", "BOTTOMLEFT", px, look.left)
		-- The left side's straight end, down the card's edge.
		look.tail = owner:CreateTexture(nil, "BORDER", nil, 1)
		look.tail:SetColorTexture(1, 1, 1, 1)
		look.tail:SetPoint("TOPLEFT", look.rim.box, "BOTTOMLEFT")
		look.tail:SetSize(px, FOOT * px)
		table.insert(look.rings, look.tail)
	end
	PaintLook(look, palette)
	return look
end

-- Where the header's line and fill open around an open tab spanning `left`
-- to `right` along the header (units, `px` a screen pixel), shown up to
-- `limit` (Skin.lua and the options' page tabs). The line opens to where the
-- feet's curves meet it, its row inside to their inner side; the fill to
-- under the frame's sides, its runs' ends rounded beside a foot. A side has
-- no foot at the header's left end (it's the card's edge) or cut off at
-- `limit`. The same table every time.
local opening = {}

function Tabs.OpenGap(left, right, px, limit)
	local foot, reach = FOOT * px, SOFT_REACH * px
	opening.leftFoot = left > 0
	if opening.leftFoot then
		opening.lineLeft = left + px - foot
		opening.softLeft = opening.lineLeft + reach
		opening.fillLeft = left + px
	else
		opening.lineLeft, opening.softLeft, opening.fillLeft = left, left, left
	end
	opening.rightFoot = not limit or right < limit
	if opening.rightFoot then
		opening.lineRight = right - px + foot
		opening.softRight = opening.lineRight - reach
		opening.fillRight = right - px
	else
		opening.lineRight, opening.softRight, opening.fillRight = right, right, right
	end
	return opening
end

-- A look's block from (tr, tg, tb, ta) at its top to (br, bg, bb, ba) at its
-- bottom, and the feet's corners in its colors at their rows.
local footTop, footBottom = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)

local function BlockAt(look, height, color)
	local t = 1 - height / look.height
	local top, bottom = look.blockTop, look.blockBottom
	color:SetRGBA(Lerp(top.r, bottom.r, t), Lerp(top.g, bottom.g, t), Lerp(top.b, bottom.b, t), Lerp(top.a, bottom.a, t))
end

local function PaintBlock(look, tr, tg, tb, ta, br, bg, bb, ba)
	look.blockTop:SetRGBA(tr, tg, tb, ta)
	look.blockBottom:SetRGBA(br, bg, bb, ba)
	look.block:SetFillGradient(look.blockTop, look.blockBottom, look.blockHeight)
	if look.feet then
		BlockAt(look, FOOT * look.px, footTop)
		BlockAt(look, 0, footBottom)
		for _, notch in ipairs(look.notches) do
			ns.Shapes.SetGradient(notch, "VERTICAL", footBottom, footTop)
		end
	end
end

-- A name cut at the strip's end fades out over the strip's last stretch. A
-- font string can't fade part of its text (SetAlphaGradient flickered on the
-- tabs as the game redrew them), and letters drawn one by one never sat
-- where the whole name puts them (the game draws text a little off its
-- measure, and each letter landed on a pixel of its own, opening gaps), so
-- while it's cut the name is drawn again in thin slices of the tab: frames
-- of our own, each clipping a copy of the label laid out exactly as the
-- label is, at its share of the name's alpha. The game's label is hidden
-- meanwhile. A name that can't be read (a secret whisper name) is just cut.
local SLICE = 2
-- Room before the tab's edge in the first slice, for a letter's overhang.
local SLICE_MARGIN = 4

-- The label's text, unless it's secret.
local function ReadableName(parts)
	local name = parts.text:GetText()
	if name and canaccessvalue(name) then
		return name
	end
end

local function Slice(parts, index)
	parts.slices = parts.slices or {}
	local slice = parts.slices[index]
	if not slice then
		local clip = CreateFrame("Frame", nil, parts.tab)
		clip:SetClipsChildren(true)
		local copy = clip:CreateFontString(nil, (parts.text:GetDrawLayer()))
		copy:SetIgnoreParentAlpha(true)
		copy:SetAllPoints(parts.text)
		slice = { clip = clip, copy = copy, share = 1 }
		parts.slices[index] = slice
	end
	return slice
end

-- The copies' alpha (each its share of the name's), as the name's own alpha
-- changes with the chat's fade: on every step of it, so nothing else here.
local function PaintNameFade(parts)
	local alpha = parts.textAlpha or 1
	if not parts.faded then
		-- While its color fills in, the name is drawn by copies (below).
		parts.text:SetAlpha(parts.inking and 0 or alpha)
		return
	end
	parts.text:SetAlpha(0)
	for index = 1, parts.faded do
		local slice = parts.slices[index]
		slice.copy:SetAlpha(alpha * slice.share)
	end
end

-- The copies' color, the name's own (Blizzard's for a whisper window).
local function ColorNameFade(parts)
	if parts.faded then
		local r, g, b = parts.text:GetTextColor()
		for index = 1, parts.faded do
			parts.slices[index].copy:SetTextColor(r, g, b)
		end
	end
end

-- The slices along the tab: the name whole up to where the fade starts, then
-- thin slices fading to nothing where the strip ends.
local function LayoutNameFade(parts)
	local fade = parts.fade
	local used = 0
	if fade and fade.name then
		local label, tab = parts.text, parts.tab
		local previous
		local function Add(left, width, share)
			used = used + 1
			local slice = Slice(parts, used)
			local clip, copy = slice.clip, slice.copy
			clip:ClearAllPoints()
			if previous then
				-- Each starts where the last ends: no column is drawn twice or
				-- left out.
				clip:SetPoint("TOPLEFT", previous, "TOPRIGHT")
				clip:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT")
			else
				clip:SetPoint("TOPLEFT", tab, "TOPLEFT", left, 0)
				clip:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", left, 0)
			end
			clip:SetWidth(width)
			clip:Show()
			if slice.name ~= fade.name or slice.font ~= fade.font then
				slice.name, slice.font = fade.name, fade.font
				copy:SetFontObject(fade.font)
				copy:SetJustifyH(label:GetJustifyH())
				copy:SetJustifyV(label:GetJustifyV())
				copy:SetWordWrap(label:CanWordWrap())
				copy:SetNonSpaceWrap(label:CanNonSpaceWrap())
				copy:SetText(fade.name)
			end
			slice.share = share
			previous = clip
		end
		if fade.from > -SLICE_MARGIN then
			Add(-SLICE_MARGIN, fade.from + SLICE_MARGIN, 1)
		end
		local count = math.max(1, math.ceil((fade.to - fade.from) / SLICE))
		local width = (fade.to - fade.from) / count
		for index = 1, count do
			Add(fade.from, width, 1 - (index - 0.5) / count)
		end
		parts.faded = used
	else
		parts.faded = nil
	end
	for index, slice in ipairs(parts.slices or {}) do
		if index > used then
			slice.clip:Hide()
		end
	end
	ColorNameFade(parts)
	PaintNameFade(parts)
end

-- Where the name fades, along the tab from its left edge (Header.lua), or
-- nil while it isn't cut.
function Tabs.SetNameFade(tab, from, to)
	local parts = tabParts[tab]
	if not parts then
		return
	end
	local fade = parts.fade
	if from == nil then
		if fade then
			parts.fade = nil
			LayoutNameFade(parts)
		end
		return
	end
	local name, font = ReadableName(parts), parts.text:GetFontObject() or TabFont()
	if fade and fade.name == name and fade.font == font
		and math.abs(fade.from - from) < 0.25 and math.abs(fade.to - to) < 0.25 then
		return
	end
	parts.fade = { from = from, to = to, name = name, font = font }
	LayoutNameFade(parts)
end

-- The game's own tab art (ChatTabArtTemplate), on our own textures over the
-- tab's emptied ones: its dark top, lit on the open tab and under the mouse
-- in the tab's color, as FCFTab_UpdateColors paints them. Shown only in a
-- theme with the game's art (Theme.GAME_ART).
local GAME_TAB = "Interface\\ChatFrame\\ChatFrameTab-"
local GAME_TAB_ROWS = {
	{ key = "background", layer = "BACKGROUND", file = "BG" },
	{ key = "active", layer = "BORDER", file = "Selected", blend = "ADD" },
	{ key = "highlight", layer = "HIGHLIGHT", file = "Highlight", blend = "ADD" },
}

local function CreateGameArt(tab)
	local art = { all = {} }
	for _, row in ipairs(GAME_TAB_ROWS) do
		local layer = row.layer
		local left = tab:CreateTexture(nil, layer)
		left:SetTexture(GAME_TAB .. row.file .. "Left")
		left:SetSize(16, 32)
		left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", -2, 0)
		local right = tab:CreateTexture(nil, layer)
		right:SetTexture(GAME_TAB .. row.file .. "Right")
		right:SetSize(16, 32)
		right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 2, 0)
		local middle = tab:CreateTexture(nil, layer)
		middle:SetTexture(GAME_TAB .. row.file .. "Mid", "REPEAT", "CLAMP")
		middle:SetHorizTile(true)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
		local pieces = { left, middle, right }
		for _, piece in ipairs(pieces) do
			if row.blend then
				piece:SetBlendMode(row.blend)
			end
			piece:SetIgnoreParentAlpha(true)
			piece:Hide()
			table.insert(art.all, piece)
		end
		art[row.key] = pieces
	end
	return art
end

-- Which pieces show, their tint and their alpha: the whole tab rests as the
-- game's tabs rest (the open one at 40%, the others at 20%).
local function PaintGameArt(parts)
	local art, game = parts.art, Theme.GAME_ART
	local color = parts.tab.selectedColorTable or DEFAULT_TAB_SELECTED_COLOR_TABLE or NORMAL_FONT_COLOR
	local alpha = Theme.Rest(parts.selected and Theme.REST_OPEN_TAB or Theme.REST_TAB, parts.lit)
	for _, piece in ipairs(art.background) do
		piece:SetShown(game)
		piece:SetAlpha(alpha)
	end
	for _, key in ipairs({ "active", "highlight" }) do
		for _, piece in ipairs(art[key]) do
			piece:SetShown(game and (key == "highlight" or parts.selected))
			piece:SetVertexColor(color.r, color.g, color.b, alpha)
		end
	end
end

-- Glyphs drawn beside the game's tabs (Theme.GAME_ART: the "+" and the move
-- grip), sized and centered on the tabs' capitals, in their gold and with
-- their shadow, in whole screen pixels: the "+" a little taller than the
-- capitals, as a button beside text is, the grip as tall as them, both with
-- the letters' stroke. The font's own "+" was two thirds of a capital and
-- thinner than the letters. Measured on the game's tabs: capitals 0.74 of
-- the font's height, their middle a twentieth of it under the label's.
local CAP_HEIGHT = 0.74
local CAP_DROP = 0.05
local PLUS_EXTRA = 3

local LetterGlyphMixin = {}

-- A texture of the glyph's fill or of its shadow, from its own pool.
function LetterGlyphMixin:Texture(pool, index, sublevel)
	local texture = pool[index]
	if not texture then
		texture = self.parent:CreateTexture(nil, "ARTWORK", nil, sublevel)
		texture:SetColorTexture(1, 1, 1, 1)
		pool[index] = texture
	end
	return texture
end

-- Centered on `region`'s `point`, `x` and `y` from it, where the label's
-- middle would be.
function LetterGlyphMixin:SetPoint(region, point, x, y)
	self.region, self.point, self.x, self.y = region, point, x or 0, y or 0
	self:Layout()
end

-- Pixels from the capitals' middle, y growing down, each with how much of
-- the gold it takes. The game's letters aren't flat: a stroke is a column of
-- full gold, then one at about half (its antialiased edge) and the black
-- shadow right against it, which reads as a bevel. The "+" and the studs are
-- drawn the same way: each stroke's last row or column at half, and a stud
-- lit at its top left. Every pixel is a whole one.
local EDGE = 0.45
local STEM = 0.9

local function GlyphPixels(kind, cap)
	local pixels = {}
	local function Set(x, y, cover)
		local key = y * 4096 + x
		if (pixels[key] or 0) < cover then
			pixels[key] = cover
		end
	end
	local stroke = math.max(2, math.floor(cap / 4.5 + 0.5))
	if kind == "plus" or kind == "minus" then
		-- Arms as long on each side of the 2-pixel stroke, the far end of the
		-- right and lower arms at half: their shadow runs on past them and made
		-- them look a pixel longer, and a pixel shorter they looked short. The
		-- "-" (a floating window's minimize button) is the bar across alone.
		stroke = stroke + stroke % 2
		local size = cap + PLUS_EXTRA
		size = size + size % 2
		local half, first = size / 2, -stroke / 2
		for along = -half, half - 1 do
			local reach = along == half - 1 and 0.5 or 1
			for across = 0, stroke - 1 do
				local edge = across == stroke - 1
				-- The bar across, full; the one down, as the letters' stems.
				Set(along, first + across, (edge and EDGE or 1) * reach)
				if kind == "plus" then
					Set(first + across, along, (edge and EDGE or STEM) * reach)
				end
			end
		end
		return pixels
	end
	-- The grip: two columns of three studs, as far apart as they're wide.
	local dot, gap = stroke, stroke
	if (2 * dot + gap) % 2 == 1 then
		gap = gap + 1
	end
	local width, height = 2 * dot + gap, 3 * dot + 2 * gap
	for row = 0, 2 do
		for column = 0, 1 do
			local left, top = -width / 2 + column * (dot + gap), -height / 2 + row * (dot + gap)
			for y = 0, dot - 1 do
				for x = 0, dot - 1 do
					local edge = (x == dot - 1) or (y == dot - 1)
					Set(left + x, top + y, edge and ((x == dot - 1 and y == dot - 1) and EDGE or STEM) or 1)
				end
			end
		end
	end
	return pixels
end

-- The glyph's pixels and its shadow's (a pixel right and down, where the
-- glyph isn't) as runs of one strength along each row: { left, top, width,
-- strength }. Seen through (the chat at rest), a pixel covered twice came
-- out brighter, so no pixel is drawn twice.
local function Runs(pixels)
	local shadow = {}
	local top, bottom, left, right = math.huge, -math.huge, math.huge, -math.huge
	for key in pairs(pixels) do
		local y = math.floor((key + 2048) / 4096)
		local x = key - y * 4096
		top, bottom = math.min(top, y), math.max(bottom, y + 1)
		left, right = math.min(left, x), math.max(right, x + 1)
		if not pixels[key + 4096 + 1] then
			shadow[key + 4096 + 1] = 1
		end
	end
	local function Rows(set)
		local runs = {}
		for y = top, bottom do
			local start, strength
			for x = left, right + 1 do
				local cover = set[y * 4096 + x]
				if start and cover ~= strength then
					table.insert(runs, { start, y, x - start, strength })
					start = nil
				end
				if cover and not start then
					start, strength = x, cover
				end
			end
		end
		return runs
	end
	return Rows(pixels), Rows(shadow)
end

local function PlaceRuns(self, pool, runs, sublevel, drop, px)
	for index, run in ipairs(runs) do
		local texture = self:Texture(pool, index, sublevel)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", self.region, self.point, self.x + run[1] * px, self.y - (run[2] + drop) * px)
		texture:SetSize(run[3] * px, px)
	end
	for index = #runs + 1, #pool do
		pool[index]:Hide()
	end
	return #runs
end

function LetterGlyphMixin:Layout()
	if not self.region then
		return
	end
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, self.parent)
	local _, size = GameFontNormalSmall:GetFont()
	size = size or 10
	local cap = math.max(5, math.floor(CAP_HEIGHT * size / px + 0.5))
	local drop = math.floor(CAP_DROP * size / px + 0.5)
	local fill, shadow = Runs(GlyphPixels(self.kind, cap))
	self.fillRuns = fill
	self.fillCount = PlaceRuns(self, self.fills, fill, 1, drop, px)
	self.shadowCount = PlaceRuns(self, self.shadows, shadow, 0, drop, px)
	self:SetShown(self.shown)
	if self.color then
		self:SetColor(unpack(self.color))
	end
end

function LetterGlyphMixin:SetShown(shown)
	self.shown = shown and true or false
	for index = 1, self.fillCount or 0 do
		self.fills[index]:SetShown(self.shown)
	end
	for index = 1, self.shadowCount or 0 do
		self.shadows[index]:SetShown(self.shown)
	end
end

function LetterGlyphMixin:SetColor(r, g, b, a)
	local color = self.color or {}
	color[1], color[2], color[3], color[4] = r, g, b, a
	self.color = color
	for index, texture in ipairs(self.fills) do
		local run = self.fillRuns and self.fillRuns[index]
		texture:SetVertexColor(r, g, b, a * (run and run[4] or 1))
	end
	for _, texture in ipairs(self.shadows) do
		texture:SetVertexColor(0, 0, 0, a)
	end
end

-- Laid out again in whole pixels when the interface's scale changes.
local letterGlyphs = {}
local scaleWatcher

-- `kind`: "plus", "minus" or "grip", drawn on `parent`.
function Tabs.CreateLetterGlyph(parent, kind)
	if not scaleWatcher then
		scaleWatcher = CreateFrame("Frame")
		scaleWatcher:RegisterEvent("UI_SCALE_CHANGED")
		scaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
		scaleWatcher:SetScript("OnEvent", function()
			for _, glyph in ipairs(letterGlyphs) do
				glyph:Layout()
			end
		end)
	end
	local glyph = CreateFromMixins(LetterGlyphMixin)
	glyph.parent, glyph.kind, glyph.fills, glyph.shadows, glyph.shown = parent, kind, {}, {}, false
	table.insert(letterGlyphs, glyph)
	return glyph
end

local function UpdateTextColor(tab, parts)
	-- Keep Blizzard's custom tab colors (e.g. whisper windows).
	local custom = tab.selectedColorTable
	local alert = not parts.selected and parts.alertColor
	local headerText = BaziUI.db.profile.classHeaderText and {BaziUI.Headers.Text("chat")}
		or BaziUI.Headers.Get("chat", "text")
	if parts.selected and not BaziUI.db.profile.classHeaderText then
		parts.text:SetTextColor(BaziUI.Theme:Accent())
	elseif headerText and not alert then
		parts.text:SetTextColor(unpack(headerText))

	elseif alert then
		parts.text:SetTextColor(alert.r, alert.g, alert.b)
	elseif custom then
		parts.text:SetTextColor(custom.r, custom.g, custom.b)

	else
		local rest, hover, fade = Theme.TAB_TEXT, Theme.TAB_TEXT_HOVER, parts.hoverFade
		parts.text:SetTextColor(Lerp(rest.r, hover.r, fade), Lerp(rest.g, hover.g, fade), Lerp(rest.b, hover.b, fade))
	end
	ColorNameFade(parts)
end

function Tabs.RefreshHeaderText()
	for tab, parts in pairs(tabParts) do UpdateTextColor(tab, parts) end
end

function Tabs.RefreshQuestAccent()
	for tab, parts in pairs(tabParts) do
		if parts.selected then UpdateTextColor(tab, parts) end
	end
end

-- A tab under the mouse lights up over a moment, and goes back the same way
-- (the scroll bar widens as briefly): its name, and in a framed theme its
-- light block (without a frame its stretch of the header's line, Skin.lua).
-- `item.hoverFade` runs to `item.hoverTarget`; `item.paintHover()` shows it.
local HOVER_TIME = 0.12
local fading = {}
local fader = CreateFrame("Frame")

local function StepHovers(_, elapsed)
	local step = elapsed / HOVER_TIME
	for item in pairs(fading) do
		if item.hoverTarget > item.hoverFade then
			item.hoverFade = math.min(item.hoverTarget, item.hoverFade + step)
		else
			item.hoverFade = math.max(item.hoverTarget, item.hoverFade - step)
		end
		item.paintHover()
		if item.hoverFade == item.hoverTarget then
			fading[item] = nil
		end
	end
	if not next(fading) then
		fader:SetScript("OnUpdate", nil)
	end
end

local function FadeHover(item, target)
	item.hoverTarget = target
	if item.hoverFade == target then
		fading[item] = nil
		item.paintHover()
		return
	end
	fading[item] = true
	fader:SetScript("OnUpdate", ns.Guard("Tabs.StepHovers", StepHovers))
end

-- The chat's fade (Skin.lua): at rest the open tab's frame and name as the
-- game's open tab rests, the other names as its other tabs, or at full while
-- they have unread messages, as its alerting tabs. The light under the frame
-- goes. The open tab's block follows the fade in its colors
-- (Tabs.SetBlockColors): at rest the header and the message area look alike,
-- and so does the block, with no box left. `lineFactor`: how much of the
-- header's line the window's background opacity shows (kept when omitted).
function Tabs.ApplyAlpha(parts, lit, lineFactor)
	if not parts then
		return
	end
	parts.lit = lit
	local look = parts.look
	local open = Theme.Rest(Theme.REST_OPEN_TAB, lit)
	if lineFactor and lineFactor ~= look.lineFactor then
		look.lineFactor = lineFactor
		look.stale = true
	end
	look.rimAlpha = open
	-- Only the open tab shows its look; the others are painted when opened
	-- (UpdateSelection), not on every frame of the chat's fade.
	if parts.selected and Framed() then
		if look.stale then
			look.stale = nil
			PaintLook(look, look.palette)
		end
		look.rim:SetAlpha(open)
		PaintFeet(look)
		look.glow:SetAlpha(lit)
	end
	if Theme.GAME_ART then
		PaintGameArt(parts)
	end
	local rest = parts.alerting and Theme.REST_ALERT or Theme.REST_TAB
	parts.textAlpha = parts.selected and open or Theme.Rest(rest, lit)
	PaintNameFade(parts)
	-- The unread dot stays whole, save while the chat hides at rest.
	ns.Alerts.SetTabFade(parts.tab, Theme.Rest(1, lit))
end

-- Whether the tab has unread messages (Alerts.lua lights its dot).
function Tabs.SetAlerting(tab, alerting)
	local parts = tabParts[tab]
	if not parts or parts.alerting == alerting then
		return
	end
	parts.alerting = alerting
	Tabs.ApplyAlpha(parts, parts.lit)
end

-- The open tab's look, its left side curving into the header's line or
-- running down the card's edge (a floating window's tab is always at its
-- card's edge).
local function ShowLook(parts)
	local look = parts.look
	local leftFoot = parts.leftFoot and parts.chatFrame.isDocked or false
	if look.leftFoot ~= leftFoot then
		look.leftFoot = leftFoot
		PlaceBlock(look)
	end
	local shown = parts.selected and Framed()
	-- Its colors as the chat's fade last set them (Tabs.SetBlockColors).
	if shown and parts.blockColors then
		PaintBlock(look, unpack(parts.blockColors))
	end
	for _, region in ipairs(look.pieces) do
		region:SetShown(shown)
	end
	for _, region in ipairs(look.left) do
		region:SetShown(shown and leftFoot)
	end
	look.tail:SetShown(shown and not leftFoot)
	PaintGameArt(parts)
end

function Tabs.UpdateSelection(tab, selected)
	local parts = tabParts[tab]
	if not parts then
		return
	end
	parts.selected = selected
	ShowLook(parts)
	UpdateTextColor(tab, parts)
	-- A framed theme lightens the tab under the mouse; without a frame its
	-- stretch of the header's line lights up (Header.lua, Skin.lua). The open
	-- tab has neither.
	if selected then
		parts.hoverFade = 0
	end
	FadeHover(parts, (parts.hovered and not selected) and 1 or 0)
	ns.Header.SetHovered(tab, parts.hovered and not selected)
	Tabs.ApplyAlpha(parts, parts.lit)
end

-- Whether a docked tab's left side curves into the header's line, or runs
-- straight down the card's edge (the first tab, scrolled to the start;
-- Header.lua, for every docked tab as it's placed).
function Tabs.SetLeftFoot(tab, foot)
	local parts = tabParts[tab]
	if parts and parts.leftFoot ~= foot then
		parts.leftFoot = foot
		ShowLook(parts)
	end
end

-- Moves the label left by `shift` (0 puts it back). A tab with an unread dot
-- (Alerts.lua) centers its name and the dot together, so the dot isn't
-- squeezed against the next tab (it sat 4px from an active neighbour's edge);
-- the tab keeps its width, so nothing else moves.
function Tabs.SetLabelShift(tab, shift)
	local parts = tabParts[tab]
	if not parts or parts.shift == shift then
		return
	end
	parts.shift = shift
	local point, relativeTo, relativePoint, x, y = unpack(parts.anchor)
	parts.text:ClearAllPoints()
	parts.text:SetPoint(point, relativeTo, relativePoint, x - shift, y)
end

-- Unread messages in the tab's name (Alerts.lua's "name" style): the name
-- takes their color, filling in from the left, then a light runs across it,
-- as across a new item in the bags, and runs again with each reminder
-- (Tabs.ShineName). Both are copies of the label, laid out as it is, inside
-- frames of our own that clip them (as the cut names' slices, above). While
-- the color fills in, the label is hidden and drawn by two copies, the part
-- already in the new color and the rest in the old one: a copy laid over
-- the label would double its shadow and thicken the letters. The light has
-- no shadow of its own, so it only brightens them. A name that can't be
-- read, or one drawn in slices, just takes the color.
local INK_TIME = 0.35
local SHINE_TIME = 0.6
local SHINE_SLICE = 2
local SHINE_SHARES = { 0.25, 0.6, 0.85, 0.6, 0.25 }
local SHINE_COLOR = CreateColor(1, 0.97, 0.86)
-- Room past the name's ends, for a letter's overhang.
local EFFECT_MARGIN = 4

local effects = {}
local effectDriver = CreateFrame("Frame")

local function EffectCopy(parts)
	local clip = CreateFrame("Frame", nil, parts.tab)
	clip:SetClipsChildren(true)
	clip:Hide()
	local copy = clip:CreateFontString(nil, (parts.text:GetDrawLayer()))
	copy:SetIgnoreParentAlpha(true)
	copy:SetAllPoints(parts.text)
	return { clip = clip, copy = copy, share = 1 }
end

-- A copy as the label is now: font, text, color; the light without shadow.
local function Dress(parts, piece, name, r, g, b, share, shadowless)
	piece.copy:SetFontObject(parts.text:GetFontObject() or TabFont())
	piece.copy:SetJustifyH(parts.text:GetJustifyH())
	piece.copy:SetText(name)
	piece.copy:SetTextColor(r, g, b)
	if shadowless then
		piece.copy:SetShadowColor(0, 0, 0, 0)
	end
	piece.share = share
	piece.copy:SetAlpha((parts.textAlpha or 1) * share)
	piece.clip:Show()
end

local function PlaceClip(parts, piece, x, width)
	piece.clip:ClearAllPoints()
	piece.clip:SetPoint("TOPLEFT", parts.text, "TOPLEFT", x, EFFECT_MARGIN)
	piece.clip:SetPoint("BOTTOMLEFT", parts.text, "BOTTOMLEFT", x, -EFFECT_MARGIN)
	piece.clip:SetWidth(math.max(width, 0.01))
end

local function EndInk(parts)
	if parts.inking then
		parts.inking = nil
		parts.effectInk.clip:Hide()
		parts.effectRest.clip:Hide()
		PaintNameFade(parts)
	end
end

local function StopEffects(parts)
	effects[parts] = nil
	EndInk(parts)
	for _, piece in ipairs(parts.effectShine or {}) do
		piece.clip:Hide()
	end
end

local function StepEffects()
	local now = GetTime()
	for parts, effect in pairs(effects) do
		local alpha = parts.textAlpha or 1
		local width = parts.text:GetStringWidth() + 2 * EFFECT_MARGIN
		local done = true
		if effect.ink then
			local k = (now - effect.start) / INK_TIME
			if k >= 1 then
				effect.ink = nil
				parts.alertColor = effect.color
				UpdateTextColor(parts.tab, parts)
				EndInk(parts)
			else
				local filled = width * k
				parts.effectInk.copy:SetAlpha(alpha)
				parts.effectRest.copy:SetAlpha(alpha)
				PlaceClip(parts, parts.effectInk, -EFFECT_MARGIN, filled)
				PlaceClip(parts, parts.effectRest, -EFFECT_MARGIN + filled, width - filled)
				done = false
			end
		end
		if effect.shine then
			local k = (now - effect.shine) / SHINE_TIME
			if k >= 1 then
				effect.shine = nil
				for _, piece in ipairs(parts.effectShine) do
					piece.clip:Hide()
				end
			elseif k >= 0 then
				-- Eased in and out, from before the name to past its end.
				local eased = k < 0.5 and 2 * k * k or 1 - (-2 * k + 2) ^ 2 / 2
				local band = #SHINE_SHARES * SHINE_SLICE
				local x = -EFFECT_MARGIN - band + (width + band) * eased
				for index, piece in ipairs(parts.effectShine) do
					piece.copy:SetAlpha(alpha * piece.share)
					PlaceClip(parts, piece, x + (index - 1) * SHINE_SLICE, SHINE_SLICE)
				end
				done = false
			else
				done = false
			end
		end
		if done then
			effects[parts] = nil
		end
	end
	if not next(effects) then
		effectDriver:SetScript("OnUpdate", nil)
	end
end

local function StartEffect(parts, effect)
	if not parts.effectInk then
		parts.effectInk, parts.effectRest, parts.effectShine = EffectCopy(parts), EffectCopy(parts), {}
		for _ = 1, #SHINE_SHARES do
			table.insert(parts.effectShine, EffectCopy(parts))
		end
	end
	effects[parts] = effect
	effectDriver:SetScript("OnUpdate", ns.Guard("Tabs.StepEffects", StepEffects))
end

local function Shine(parts, delay, name)
	for index, piece in ipairs(parts.effectShine) do
		Dress(parts, piece, name, SHINE_COLOR.r, SHINE_COLOR.g, SHINE_COLOR.b, SHINE_SHARES[index], true)
		PlaceClip(parts, piece, -EFFECT_MARGIN - 2 * #SHINE_SHARES * SHINE_SLICE, SHINE_SLICE)
	end
	effects[parts].shine = GetTime() + delay
end

-- The name in `color` (nil gives it its own back); `animate` fills it in
-- and runs the light across it, for a tab that just got its first one.
function Tabs.SetAlertColor(tab, color, animate)
	local parts = tabParts[tab]
	if not parts then
		return
	end
	local name = ReadableName(parts)
	StopEffects(parts)
	if animate and color and name and not parts.faded and not parts.selected then
		StartEffect(parts, { start = GetTime(), color = color, ink = true })
		local r, g, b = parts.text:GetTextColor()
		Dress(parts, parts.effectInk, name, color.r, color.g, color.b, 1)
		Dress(parts, parts.effectRest, name, r, g, b, 1)
		PlaceClip(parts, parts.effectInk, -EFFECT_MARGIN, 0)
		PlaceClip(parts, parts.effectRest, -EFFECT_MARGIN, parts.text:GetStringWidth() + 2 * EFFECT_MARGIN)
		parts.inking = true
		PaintNameFade(parts)
		Shine(parts, INK_TIME, name)
		return
	end
	parts.alertColor = color
	UpdateTextColor(tab, parts)
end

-- The light across a name in its unread color again (the reminder).
function Tabs.ShineName(tab)
	local parts = tabParts[tab]
	local name = parts and ReadableName(parts)
	if not (name and parts.alertColor) or parts.faded or parts.selected or effects[parts] then
		return
	end
	StartEffect(parts, {})
	Shine(parts, 0, name)
end

-- The open tab's block, from the header's look at its top to the message
-- area's at its bottom (Skin.lua, at every step of the chat's fade). Kept,
-- and painted while it shows.
function Tabs.SetBlockColors(parts, tr, tg, tb, ta, br, bg, bb, ba)
	local r, g, b = BaziUI.Theme:Accent()
	tr, tg, tb = tr * 0.55 + r * 0.45, tg * 0.55 + g * 0.45, tb * 0.55 + b * 0.45
	if not (parts and parts.look) then
		return
	end
	local colors = parts.blockColors or {}
	colors[1], colors[2], colors[3], colors[4], colors[5], colors[6], colors[7], colors[8] = tr, tg, tb, ta, br, bg, bb, ba
	parts.blockColors = colors
	if parts.selected and Framed() then
		PaintBlock(parts.look, tr, tg, tb, ta, br, bg, bb, ba)
	end
end

-- The drag ghost's block in the body's color (Header.lua, the window it
-- stands for): clear at its top, over the header's own fill.
function Tabs.SetFillColor(parts, r, g, b)
	if parts and parts.look then
		PaintBlock(parts.look, r, g, b, 0, r, g, b, FILL_ALPHA)
	end
end

-- A floating window's tab fits its name, as the docked ones do (Header.lua):
-- the game sizes it to a text width it measured before Everchat's font was
-- on (`textWidth`), which cut longer names ("Hermand..."), and does so on
-- paths of its own (undocking, loading the windows), so the tab is fitted
-- again whenever its size changes. A secret name keeps the game's width.
local fitting = false

local function FitFloatingTab(chatFrame)
	if fitting or not chatFrame or chatFrame.isDocked then
		return
	end
	if FCF_HasSecretName and FCF_HasSecretName(chatFrame) then
		return
	end
	local tab = _G[chatFrame:GetName() .. "Tab"]
	local name = tab and tab:GetText()
	if name and canaccessvalue(name) then
		fitting = true
		PanelTemplates_TabResize(tab, tab.sizePadding or 0)
		fitting = false
	end
end

function Tabs.Skin(tab, chatFrame)
	for _, key in ipairs(TAB_ART) do
		tab[key]:SetTexture(nil)
	end
	-- Blizzard's own alert (a light along the tab's bottom it flashes for
	-- whispers) gives way to Everchat's dot (Alerts.lua): its texture is
	-- emptied, Blizzard only plays and recolors it.
	if tab.glow then
		tab.glow:SetTexture(nil)
	end

	-- Blizzard fades tabs down to 20%; the label and our pieces opt out of the
	-- tab's alpha so ApplyAlpha can keep them readable.
	local text = tab:GetFontString()
	SetLabelFont(text, tab)
	text:SetIgnoreParentAlpha(true)

	-- Center the label in the header. Blizzard puts it 11px above the tab's
	-- bottom (and further down on temporary windows); only the height changes.
	local point, relativeTo, relativePoint, x = text:GetPoint(1)
	local anchor = { point, relativeTo or tab, relativePoint, x, Theme.HEADER_HEIGHT / 2 - tab:GetHeight() / 2 }
	text:ClearAllPoints()
	text:SetPoint(unpack(anchor))
	-- Blizzard's tab is taller than the header, bottoms aligned: only its
	-- part over the header takes the mouse, so nothing unseen above the card
	-- catches a click.
	tab:SetHitRectInsets(0, 0, math.max(0, tab:GetHeight() - Theme.HEADER_HEIGHT), 0)
	-- Flat tabs: the label doesn't sink while pressed. A button shifts its
	-- label by the pushed offset on press and back on release; a label
	-- re-anchored in between (a tab's unread dot clears as the click opens it)
	-- was left 1.5 units off, up and to the left.
	tab:SetPushedTextOffset(0, 0)

	local px = PixelUtil.ConvertPixelsToUIForRegion(1, tab)
	local function Place(shape, bottom, left, right)
		shape:ClearAllPoints()
		shape:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", left or 0, bottom)
		shape:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", -(right or 0), Theme.HEADER_HEIGHT)
		shape:SetIgnoreParentAlpha(true)
		return shape
	end

	local look = AddLook(tab, Place, px, Theme, true)
	look.glow:SetIgnoreParentAlpha(true)
	for _, pieces in ipairs({ look.pieces, look.left, { look.tail } }) do
		for _, piece in ipairs(pieces) do
			piece:SetIgnoreParentAlpha(true)
		end
	end

	local hover = Place(ns.Shapes.Fill(tab, "BACKGROUND", 0, Theme.TAB_RADIUS, "TOP"), 0)
	hover:SetColor(1, 1, 1, HOVER_ALPHA)
	hover:Hide()

	local parts = {
		tab = tab, text = text, anchor = anchor, shift = 0, look = look, hover = hover, chatFrame = chatFrame,
		selected = false, hovered = false, lit = 1, hoverFade = 0, hoverTarget = 0, leftFoot = false,
		art = CreateGameArt(tab), font = TabFont(),
	}
	function parts.paintHover()
		hover:SetShown(parts.hoverFade > 0 and Framed())
		hover:SetAlpha(parts.hoverFade)
		UpdateTextColor(tab, parts)
	end
	tabParts[tab] = parts

	local function SetHovered(hovered)
		parts.hovered = hovered
		FadeHover(parts, (hovered and not parts.selected) and 1 or 0)
		ns.Header.SetHovered(tab, hovered and not parts.selected)
	end
	tab:HookScript("OnEnter", function()
		SetHovered(true)
	end)
	tab:HookScript("OnLeave", function()
		SetHovered(false)
	end)

	tab:HookScript("OnSizeChanged", function()
		FitFloatingTab(chatFrame)
	end)

	-- Same rule FCF uses when it calls FCFTab_UpdateColors.
	Tabs.UpdateSelection(tab, not chatFrame.isDocked or chatFrame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK))
	return parts
end

-- The tabs' look on another button (Options.lua's page tabs): the active
-- block in its gold frame whatever the chat's theme (the options window keeps
-- the game's gold), open into what's below, and the hover light. The button
-- stands on its row's bottom edge, like a chat tab, the row `height` tall.
function Tabs.CreateLook(button, height)
	height = height or Theme.HEADER_HEIGHT
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, button)
	-- The block and the gold sides end flush with the line's lowest row, as
	-- they show on the chat's header (there they reach a pixel below it on
	-- paper; on the options window's whole-pixel row that pixel showed).
	local function Place(shape, bottom, left, right)
		shape:ClearAllPoints()
		shape:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", left or 0, math.max(bottom, 0))
		shape:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -(right or 0), height)
		return shape
	end
	local active = AddLook(button, Place, px, Theme.GAME, true, height)
	PaintBlock(active, Theme.BODY.r, Theme.BODY.g, Theme.BODY.b, 0, Theme.BODY.r, Theme.BODY.g, Theme.BODY.b, FILL_ALPHA)
	active.tail:Hide()
	for _, piece in ipairs(active.left) do
		table.insert(active.pieces, piece)
	end
	local hover = Place(ns.Shapes.Fill(button, "BACKGROUND", 0, Theme.TAB_RADIUS, "TOP"), 0)
	hover:SetColor(1, 1, 1, HOVER_ALPHA)
	hover:Hide()
	local look = { active = active.pieces, hover = hover, hoverFade = 0, hoverTarget = 0 }
	function look.paintHover()
		hover:SetShown(look.hoverFade > 0)
		hover:SetAlpha(look.hoverFade)
	end
	function look:SetSelected(selected)
		for _, region in ipairs(self.active) do
			region:SetShown(selected)
		end
		self.selected = selected
		if selected then
			self.hoverFade = 0
		end
		FadeHover(self, (self.hovered and not selected) and 1 or 0)
	end
	function look:SetHovered(hovered)
		self.hovered = hovered
		FadeHover(self, (hovered and not self.selected) and 1 or 0)
	end
	look:SetSelected(false)
	return look
end

-- Tabs start at the panel's left edge. Docked tabs hang from the dock, which
-- Blizzard anchors to the primary window's Background in FCFDock_SetPrimary;
-- undocked tabs are placed by FCF_SetTabPosition. Both get the panel's offset.
-- The dock is the docked windows' header, so it takes the header's height
-- (its template's is the game's).
local function AlignDock(dock, primary)
	dock:SetPoint("BOTTOMLEFT", primary.Background, "TOPLEFT", -Theme.PANEL_PAD_LEFT, 0)
	dock:SetHeight(Theme.HEADER_HEIGHT)
end

function Tabs.AlignTab(chatFrame, x)
	local tab = _G[chatFrame:GetName() .. "Tab"]
	tab:ClearAllPoints()
	tab:SetPoint("BOTTOMLEFT", chatFrame.Background, "TOPLEFT", (x or 0) - Theme.PANEL_PAD_LEFT, 0)
	FitFloatingTab(chatFrame)
end

-- The ghost in the theme: its frame or its lit line, and its name's color.
local function PaintGhost(ghost)
	local framed = Framed()
	PaintLook(ghost.look, Theme)
	for _, region in ipairs(ghost.look.pieces) do
		region:SetShown(framed)
	end
	local color = Theme.LINE
	for index, row in ipairs(ghost.lit) do
		row:SetColorTexture(color.r, color.g, color.b, index == 1 and Theme.LINE_LIT_ALPHA or Theme.LINE_LIT_SOFT_ALPHA)
		row:SetShown(not framed)
	end
	ghost.text:SetTextColor(Theme.TAB_OPEN:GetRGB())
end

-- A stand-in for a tab being dragged along the header: the active tab's look
-- (it's selected once dropped) with the tab's label. The caller sizes it.
function Tabs.CreateGhost(parent)
	local ghost = CreateFrame("Frame", nil, parent)
	ghost:SetHeight(Theme.HEADER_HEIGHT)
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, ghost)

	local function Place(shape, bottom, left, right)
		shape:ClearAllPoints()
		shape:SetPoint("TOPLEFT", ghost, "TOPLEFT", left or 0, 0)
		shape:SetPoint("BOTTOMRIGHT", ghost, "BOTTOMRIGHT", -(right or 0), bottom)
		return shape
	end
	-- Like a skinned tab's, for Tabs.SetFillColor.
	ghost.look = AddLook(ghost, Place, px, Theme)
	Tabs.SetFillColor(ghost, Theme.BODY.r, Theme.BODY.g, Theme.BODY.b)

	local text = ghost:CreateFontString(nil, "ARTWORK")
	SetLabelFont(text)
	text:SetPoint("CENTER")
	ghost.text = text
	-- Without metal, the header line's two rows lit under it, as under the
	-- open tab (Skin.lua's trim).
	ghost.lit = {}
	for index = 1, 2 do
		local row = ghost:CreateTexture(nil, "ARTWORK")
		row:SetHeight(px)
		local y = (index - 1) * px
		row:SetPoint("BOTTOMLEFT", ghost, "BOTTOMLEFT", Theme.LINE_LIT_INSET, y)
		row:SetPoint("BOTTOMRIGHT", ghost, "BOTTOMRIGHT", -Theme.LINE_LIT_INSET, y)
		ghost.lit[index] = row
	end
	table.insert(ghosts, ghost)
	PaintGhost(ghost)
	ghost:Hide()
	return ghost
end

-- A new theme: the tabs' metal or the game's art, their names and font, and
-- how the open one is marked.
local function Repaint()
	local font, resized = TabFont(), false
	for tab, parts in pairs(tabParts) do
		if parts.font ~= font then
			parts.font = font
			SetLabelFont(parts.text, tab)
			resized = true
		end
		PaintLook(parts.look, Theme)
		Tabs.UpdateSelection(tab, parts.selected)
	end
	for _, ghost in ipairs(ghosts) do
		SetLabelFont(ghost.text)
		PaintGhost(ghost)
	end
	-- Another font, other widths.
	if resized then
		ns.Header.Relayout()
	end
end

-- A whisper tab's bubble beside the name: the game lowers it for its own
-- taller tabs, and on the header's line of text the bubble sat low, its tail
-- under the letters.
local CONVERSATION_ICON_RISE = 1

local function AlignConversationIcon(chatFrame)
	local tab = chatFrame and _G[chatFrame:GetName() .. "Tab"]
	local icon = tab and tab.conversationIcon
	local info = icon and icon.iconDisplayInfo
	if not info then
		return
	end
	icon:ClearAllPoints()
	icon:SetPoint("RIGHT", tab:GetFontString(), "LEFT", info.xOffset or 0, (info.yOffset or 0) + CONVERSATION_ICON_RISE)
end

function Tabs.Init()
	AlignDock(GENERAL_CHAT_DOCK, GENERAL_CHAT_DOCK.primary)
	for _, name in pairs(CHAT_FRAMES) do
		local chatFrame = _G[name]
		if not chatFrame.isDocked then
			Tabs.AlignTab(chatFrame, 0)
		end
	end
	hooksecurefunc("FCFDock_SetPrimary", AlignDock)
	hooksecurefunc("FCF_SetTabPosition", Tabs.AlignTab)
	hooksecurefunc("FCFDock_RemoveChatFrame", function(_, chatFrame)
		FitFloatingTab(chatFrame)
	end)
	hooksecurefunc("FCF_SetWindowName", function(chatFrame)
		FitFloatingTab(chatFrame)
	end)
	hooksecurefunc("FCFTab_UpdateColors", Tabs.UpdateSelection)
	hooksecurefunc("FCF_SetTemporaryWindowType", AlignConversationIcon)
	for _, name in pairs(CHAT_FRAMES) do
		if _G[name].isTemporary then
			AlignConversationIcon(_G[name])
		end
	end
	Theme.OnChanged(Repaint)

end
