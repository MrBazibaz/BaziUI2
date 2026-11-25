local ns = BaziUI.Chat

local Shapes = {}
ns.Shapes = Shapes

-- Rounded rectangles out of plain textures (WoW can't round a color
-- texture): a box the caller anchors, and pieces around it. Corners come from
-- Everchat's own art (Media/CornerN, Media/RingN: a 16x16 white texture whose
-- top-left NxN texels hold a corner of radius N, filled or as a 1px outline),
-- drawn at their size in screen pixels so they're as crisp as the 1px lines
-- next to them. Pieces are white, tinted with SetVertexColor.
local MEDIA = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ART_SIZE = 16

-- Texture coordinates for each corner, mirroring the top-left art.
local CORNERS = {
	TOPLEFT = { false, false },
	TOPRIGHT = { true, false },
	BOTTOMLEFT = { false, true },
	BOTTOMRIGHT = { true, true },
}

-- Which corners are round: "ALL", "TOP", "BOTTOM", one of the top two, or
-- "NONE" (a plain rectangle in rows, for a gradient).
local ROUNDED = {
	NONE = {},
	ALL = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
	TOP = { TOPLEFT = true, TOPRIGHT = true },
	BOTTOM = { BOTTOMLEFT = true, BOTTOMRIGHT = true },
	TOPLEFT = { TOPLEFT = true },
	TOPRIGHT = { TOPRIGHT = true },
}

-- A length in interface units rounded to whole screen pixels for a region.
-- Icons get these sizes: an icon whose size falls between pixels renders a
-- pixel wider or narrower depending on where it lands, and its strokes blur
-- (the "+" looked different following the tabs than pinned to the chevron).
function Shapes.WholePixels(region, units)
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, region)
	return math.max(1, math.floor(units / px + 0.5)) * px
end

-- `pixels` screen pixels times the art's scale (2 on dense screens, where
-- Everchat's 32px icons are drawn 1:1), in interface units.
function Shapes.ArtPixels(region, pixels)
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, region)
	return pixels * math.max(1, math.ceil(1 / px - 0.5)) * px
end

-- Every glow, to take a new theme's color.
local glows = {}

-- Its alpha stays (the vertex color's alpha is the texture's own, which
-- its owner sets as it lights).
local function PaintGlow(glow)
	local color = ns.Theme.GLOW
	glow:SetVertexColor(color.r, color.g, color.b, glow:GetAlpha())
end

-- A soft glow behind a glyph in the theme's color, gold in Gold (hidden
-- until the caller shows it).
function Shapes.Glow(owner, size)
	local glow = owner:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(ns.Theme.GLOW_TEXTURE)
	glow:SetBlendMode("ADD")
	local units = Shapes.WholePixels(glow, size or ns.Theme.GLOW_SIZE)
	glow:SetSize(units, units)
	glow:SetAlpha(1)
	PaintGlow(glow)
	glow:Hide()
	table.insert(glows, glow)
	return glow
end

ns.Theme.OnChanged(function()
	for _, glow in ipairs(glows) do
		PaintGlow(glow)
	end
end)

local ShapeMixin = {}

-- A texture's vertex color alpha is its alpha (SetAlpha sets the same
-- value, the last call wins), so the color's alpha is kept apart and the
-- pieces take it times the shape's: a fill at 50% stays at 50% of the chat's
-- fade instead of taking the fade's alpha.
function ShapeMixin:SetColor(r, g, b, a)
	self.colorAlpha = a or 1
	for _, piece in ipairs(self.pieces) do
		piece:SetVertexColor(r, g, b)
		piece:SetAlpha(self.colorAlpha * self.alpha)
	end
end

-- The game draws a gradient's colors as given: the texture's own alpha
-- (SetAlpha) and its frame's don't reach it. On a faded chat the header and
-- footer lines' fading ends, the active tab's sides and the shading at the
-- strip's edges stayed at full strength while the rest faded, so the lines
-- looked cut (2026-10-10). Gradients that fade carry the alpha in their
-- colors instead.
local gradientFrom, gradientTo = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)

function Shapes.SetGradient(texture, orientation, from, to, alpha)
	alpha = alpha or 1
	gradientFrom:SetRGBA(from.r, from.g, from.b, (from.a or 1) * alpha)
	gradientTo:SetRGBA(to.r, to.g, to.b, (to.a or 1) * alpha)
	texture:SetGradient(orientation, gradientFrom, gradientTo)
end

-- An outline's gradient at the shape's alpha: the sides carry it in their
-- colors (their own alpha stays 1); the top and bottom pieces take their
-- color's alpha times the shape's (a vertex color's alpha is the texture's
-- own, so it goes on after the color).
local function PaintEnds(pieces, color, alpha)
	for _, piece in ipairs(pieces) do
		piece:SetVertexColor(color.r, color.g, color.b)
		piece:SetAlpha(alpha * (color.a or 1))
	end
end

local function PaintGradient(shape)
	local gradient = shape.gradient
	for _, piece in ipairs(shape.sides) do
		piece:SetAlpha(1)
		Shapes.SetGradient(piece, "VERTICAL", gradient.bottom, gradient.top, shape.alpha)
	end
	PaintEnds(shape.tops, gradient.top, shape.alpha)
	PaintEnds(shape.bottoms, gradient.bottom, shape.alpha)
end

-- An outline lit from above, like the game's metal: its top (edge and
-- corners) in `top`, its bottom in `bottom`, its sides fading between them.
-- Colors with alpha: the color's alpha is part of the gradient.
function ShapeMixin:SetVerticalGradient(top, bottom)
	self.gradient = { top = top, bottom = bottom }
	PaintGradient(self)
end

-- A fill's colors down its height, from `top` to `bottom` (colors with
-- alpha), its box `height` units tall: each of its three rows of pieces
-- takes its stretch of the gradient.
local rowTop, rowBottom = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)
local stops = {}

local function GradientAt(gradient, y, color)
	local t = y / gradient.height
	local top, bottom = gradient.top, gradient.bottom
	color:SetRGBA(Lerp(top.r, bottom.r, t), Lerp(top.g, bottom.g, t), Lerp(top.b, bottom.b, t),
		Lerp(top.a or 1, bottom.a or 1, t))
end

local function PaintFillGradient(shape)
	local gradient = shape.fillGradient
	local height = gradient.height
	local radius = math.min(shape.radius, height / 2)
	stops[1], stops[2], stops[3], stops[4] = 0, radius, height - radius, height
	for index, row in ipairs(shape.rows) do
		GradientAt(gradient, stops[index], rowTop)
		GradientAt(gradient, stops[index + 1], rowBottom)
		for _, piece in ipairs(row) do
			piece:SetAlpha(1)
			Shapes.SetGradient(piece, "VERTICAL", rowBottom, rowTop, shape.alpha)
		end
	end
end

function ShapeMixin:SetFillGradient(top, bottom, height)
	local gradient = self.fillGradient or {}
	gradient.top, gradient.bottom, gradient.height = top, bottom, height
	self.fillGradient = gradient
	PaintFillGradient(self)
end

function ShapeMixin:SetAlpha(alpha)
	self.alpha = alpha
	if self.fillGradient then
		PaintFillGradient(self)
		return
	end
	for _, piece in ipairs(self.pieces) do
		piece:SetAlpha(alpha * (self.colorAlpha or 1))
	end
	if self.gradient then
		PaintGradient(self)
	end
end

function ShapeMixin:SetShown(shown)
	for _, piece in ipairs(self.pieces) do
		piece:SetShown(shown)
	end
end

function ShapeMixin:Show()
	self:SetShown(true)
end

function ShapeMixin:Hide()
	self:SetShown(false)
end

function ShapeMixin:SetIgnoreParentAlpha(ignore)
	for _, piece in ipairs(self.pieces) do
		piece:SetIgnoreParentAlpha(ignore)
	end
end

-- Placing the shape places its box.
for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight" }) do
	ShapeMixin[method] = function(self, ...)
		self.box[method](self.box, ...)
	end
end

local function NewShape(owner, layer, sublevel)
	local shape = CreateFromMixins(ShapeMixin)
	-- Draws nothing; only holds the shape's rect.
	shape.box = owner:CreateTexture(nil, layer, nil, sublevel)
	shape.box:SetColorTexture(0, 0, 0, 0)
	shape.pieces = {}
	shape.alpha = 1
	shape.layer, shape.sublevel = layer, sublevel
	shape.px = PixelUtil.ConvertPixelsToUIForRegion(1, owner)
	shape.owner = owner
	return shape
end

local function AddPiece(shape, file)
	local piece = shape.owner:CreateTexture(nil, shape.layer, nil, shape.sublevel)
	piece:SetTexture(file or WHITE)
	table.insert(shape.pieces, piece)
	return piece
end

-- Radii drawn with the art of twice their size, halved: bilinear filtering
-- at half size averages texels exactly like the supersampling that made the
-- art (art/corners.py), so it's the same corner without another file (not
-- for a ring, whose line would be half a pixel).
local HALVED = { [2] = 4 }

-- A corner's art on a texture: "Corner" (filled), "Ring" (its 1px outline)
-- or "Notch" (the square's corner the curve leaves out; only radius 3),
-- radius in screen pixels, mirrored for `point`. The texture is `size`
-- screen pixels square (by default the radius): past the curve the art goes
-- on as the edges and the fill do, so a fill's corner piece can hold a
-- smaller curve.
local function DressCorner(texture, art, radius, point, px, size)
	size = size or radius
	local artRadius = HALVED[radius] or radius
	texture:SetTexture(MEDIA .. art .. artRadius)
	local edge = size * artRadius / radius / ART_SIZE
	local flipX, flipY = unpack(CORNERS[point])
	local left, right = 0, edge
	local top, bottom = 0, edge
	if flipX then
		left, right = right, left
	end
	if flipY then
		top, bottom = bottom, top
	end
	texture:SetTexCoord(left, right, top, bottom)
	texture:SetSize(size * px, size * px)
end

-- A corner piece of the given art, size in screen pixels, at the box's corner.
local function AddCorner(shape, art, radius, point)
	local piece = AddPiece(shape)
	DressCorner(piece, art, radius, point, shape.px)
	piece:SetPoint(point, shape.box, point)
	return piece
end

-- A lone corner piece, for the caller to anchor and color (the open tab's
-- feet, Tabs.lua).
function Shapes.Corner(owner, layer, sublevel, art, radius, point)
	local texture = owner:CreateTexture(nil, layer, nil, sublevel)
	DressCorner(texture, art, radius, point, PixelUtil.ConvertPixelsToUIForRegion(1, owner))
	return texture
end

-- A filled rectangle with the given corners rounded (radius in screen pixels):
-- four corner pieces, four edge strips and the middle. Square corners are
-- plain pieces, so the same nine always tile the box without overlapping.
function Shapes.Fill(owner, layer, sublevel, radius, rounded)
	local shape = NewShape(owner, layer, sublevel)
	local round = ROUNDED[rounded or "ALL"]
	local corners = {}
	for point in pairs(CORNERS) do
		if round[point] then
			corners[point] = AddCorner(shape, "Corner", radius, point)
		else
			local piece = AddPiece(shape)
			piece:SetSize(radius * shape.px, radius * shape.px)
			piece:SetPoint(point, shape.box, point)
			corners[point] = piece
		end
	end
	local function Strip(topLeft, topLeftPoint, bottomRight, bottomRightPoint)
		local piece = AddPiece(shape)
		piece:SetPoint("TOPLEFT", topLeft, topLeftPoint)
		piece:SetPoint("BOTTOMRIGHT", bottomRight, bottomRightPoint)
		return piece
	end
	local top = Strip(corners.TOPLEFT, "TOPRIGHT", corners.TOPRIGHT, "BOTTOMLEFT")
	local bottom = Strip(corners.BOTTOMLEFT, "TOPRIGHT", corners.BOTTOMRIGHT, "BOTTOMLEFT")
	local left = Strip(corners.TOPLEFT, "BOTTOMLEFT", corners.BOTTOMLEFT, "TOPRIGHT")
	local right = Strip(corners.TOPRIGHT, "BOTTOMLEFT", corners.BOTTOMRIGHT, "TOPRIGHT")
	local middle = Strip(corners.TOPLEFT, "BOTTOMRIGHT", corners.BOTTOMRIGHT, "TOPLEFT")
	shape.corners = corners
	shape.cornerRadius = radius
	-- Its rows, top to bottom (SetFillGradient).
	shape.rows = {
		{ corners.TOPLEFT, top, corners.TOPRIGHT },
		{ left, middle, right },
		{ corners.BOTTOMLEFT, bottom, corners.BOTTOMRIGHT },
	}
	shape.radius = radius * shape.px
	return shape
end

-- Rounds one of a fill's corners with `radius` screen pixels, up to the
-- fill's own, or squares it (nil): a header's run beside the open tab,
-- rounded into the tab's foot, square where the tab is cut off.
function ShapeMixin:SetCornerRadius(point, radius)
	local piece = self.corners[point]
	if radius then
		DressCorner(piece, "Corner", radius, point, self.px, self.cornerRadius)
	else
		piece:SetTexture(WHITE)
		piece:SetTexCoord(0, 1, 0, 1)
	end
end

-- A 1px outline just inside the box, rounded like Shapes.Fill. `open` leaves
-- one side out ("BOTTOM": a tab standing on the header's edge).
function Shapes.Outline(owner, layer, sublevel, radius, rounded, open)
	local shape = NewShape(owner, layer, sublevel)
	-- Which pieces are its top, bottom and sides (SetVerticalGradient).
	shape.tops, shape.bottoms, shape.sides = {}, {}, {}
	local round = ROUNDED[rounded or "ALL"]
	local inset = {}
	for point in pairs(CORNERS) do
		if round[point] then
			local corner = AddCorner(shape, "Ring", radius, point)
			table.insert(point:find("^TOP") and shape.tops or shape.bottoms, corner)
			inset[point] = radius * shape.px
		else
			inset[point] = 0
		end
	end
	local px = shape.px
	local function Line(from, to, horizontal, fromInset, toInset)
		local piece = AddPiece(shape)
		if horizontal then
			piece:SetPoint(from, shape.box, from, fromInset, 0)
			piece:SetPoint(to, shape.box, to, -toInset, 0)
			piece:SetHeight(px)
		else
			piece:SetPoint(from, shape.box, from, 0, -fromInset)
			piece:SetPoint(to, shape.box, to, 0, toInset)
			piece:SetWidth(px)
		end
		return piece
	end
	if open ~= "TOP" then
		table.insert(shape.tops, Line("TOPLEFT", "TOPRIGHT", true, inset.TOPLEFT, inset.TOPRIGHT))
	end
	if open ~= "BOTTOM" then
		table.insert(shape.bottoms, Line("BOTTOMLEFT", "BOTTOMRIGHT", true, inset.BOTTOMLEFT, inset.BOTTOMRIGHT))
	end
	table.insert(shape.sides, Line("TOPLEFT", "BOTTOMLEFT", false, inset.TOPLEFT, inset.BOTTOMLEFT))
	table.insert(shape.sides, Line("TOPRIGHT", "BOTTOMRIGHT", false, inset.TOPRIGHT, inset.BOTTOMRIGHT))
	return shape
end
