local ns = BaziUI.Chat

local Padlock = {}
ns.Padlock = Padlock

local Theme = ns.Theme

-- The moment the chat is locked or unlocked: a small tab rises from behind the
-- header, its padlock closes or opens with a sound, and it goes back. It stands
-- on the move grip's axis with its side on the card's, so the column of the
-- scroll bar and the grip goes on up through it; on a chat against the screen's
-- top it hangs under the header instead. Its frames are made the first time and
-- only run while it plays.

local MEDIA = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Sizes in screen pixels, times the art's scale.
local ART_BOX = 32          -- Media/IconLockBody and IconLockShackle (art/lock-icons.py)
local TAB_HEIGHT = 24
local MIN_WIDTH = 22        -- the padlock and some air, if the axis is that near the edge
local TRAVEL = 3            -- how far the shackle rises to open
local GLOW_BOX = 40
-- With no tab drawn behind the padlock (the style without a strip, the
-- game's art) the glow isn't held inside the tab, which showed it cut
-- square: it's smaller and free, fading out before the header's edge.
local LOOSE_GLOW_BOX = 24
local CLIP_MARGIN = 12      -- room for the tab's shadow inside the clipping frame
-- Over the docked tabs and the grip, under the game's windows.
local STRATA = "MEDIUM"
local LEVEL = 60

-- The open tab's own frame (Tabs.lua): the metal at its free end, fading down
-- its sides into the header line's color and strength; a light under that end.
local RIM_ALPHA = 0.9
local LIGHT_ALPHA = 0.16
local LIGHT_SHARE = 0.4

-- The timing, in seconds.
local RISE = 0.15
local BEAT = 0.09           -- the tab is up: a moment before the shackle moves
local SNAP_LOCK = 0.075
local SNAP_OPEN = 0.105
local OPEN_HIT = 0.015      -- opening is heard just after the shackle starts
local HOLD_END = 0.735
local FALL = 0.135
local DIP_DOWN = 0.0375     -- the padlock gives a pixel as the shackle lands
local DIP_BACK = 0.06
local GLOW_IN = 0.03
local GLOW_OUT = 0.27
local GLOW_PEAK = 0.55
local OVERSHOOT = 1.9
local TOTAL = HOLD_END + FALL
-- Where each sound's strike is in its file, so it lands with the shackle.
local LOCK_SOUND_STRIKE = 0.043
local OPEN_SOUND_STRIKE = 0.04

local function EaseOut(x)
	local rest = 1 - x
	return 1 - rest * rest * rest
end

local function EaseIn(x)
	return x * x * x
end

local function BackOut(x)
	local rest = x - 1
	return 1 + (OVERSHOOT + 1) * rest * rest * rest + OVERSHOOT * rest * rest
end

-- When the shackle lands (closing) or takes off (opening).
local function HitTime(locking)
	if locking then
		return RISE + BEAT + SNAP_LOCK
	end
	return RISE + BEAT + OPEN_HIT
end

-- The picture `t` seconds in: how far the tab is out (0 to 1), how far the
-- shackle is open (0 to 1, a little past on the way up), the padlock's dip in
-- pixels and the glow's alpha.
function Padlock.FrameAt(locking, t)
	local rise
	if t < RISE then
		rise = EaseOut(math.max(t, 0) / RISE)
	elseif t < HOLD_END then
		rise = 1
	else
		rise = math.max(0, 1 - EaseIn(math.min(1, (t - HOLD_END) / FALL)))
	end

	local from = RISE + BEAT
	local open, dip = 0, 0
	if locking then
		local landed = from + SNAP_LOCK
		if t < from then
			open = 1
		elseif t < landed then
			open = 1 - EaseIn((t - from) / SNAP_LOCK)
		elseif t < landed + DIP_DOWN then
			dip = (t - landed) / DIP_DOWN
		elseif t < landed + DIP_DOWN + DIP_BACK then
			dip = 1 - (t - landed - DIP_DOWN) / DIP_BACK
		end
	elseif t >= from + SNAP_OPEN then
		open = 1
	elseif t >= from then
		open = BackOut((t - from) / SNAP_OPEN)
	end

	local glow = 0
	local since = t - HitTime(locking)
	if since >= GLOW_OUT + GLOW_IN then
		glow = 0
	elseif since >= GLOW_IN then
		glow = 1 - (since - GLOW_IN) / GLOW_OUT
	elseif since >= 0 then
		glow = since / GLOW_IN
	end
	return rise, open, dip, glow * GLOW_PEAK
end

-- When its sound starts, seconds in.
function Padlock.SoundTime(locking)
	return HitTime(locking) - (locking and LOCK_SOUND_STRIKE or OPEN_SOUND_STRIKE)
end

Padlock.DURATION = TOTAL

local parts
local playing = false
local locking, elapsed, soundAt, soundKind = false, 0, nil, nil
local up = true
local tabHeight, hideBy, clipInset = 0, 0, 0
local unit = 1
local drawnRise, drawnOpen, drawnDip, drawnGlow, drawnCornered
local listeners = {}

local rimEnd, rimBase = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)
local lightEnd, lightGone = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 0)
local wedgeRimTop, wedgeRimBottom = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 0)

local function BuildPanel(tab, px, standing)
	local rounded, open = standing and "TOP" or "BOTTOM", standing and "BOTTOM" or "TOP"
	local outer = rounded
	local panel = {}
	-- Its free end and its sides: the other end is behind the card.
	panel.shadow = ns.Skin.BoxShadow(tab, "tab", "BACKGROUND", 0, rounded)

	local radius = Theme.TAB_RADIUS
	panel.fill = ns.Shapes.Fill(tab, "BACKGROUND", 1, radius, rounded)
	panel.fill:SetAllPoints(tab)
	panel.light = ns.Shapes.Fill(tab, "BACKGROUND", 2, radius - 1, rounded)
	panel.light:SetPoint(outer .. "LEFT", tab, outer .. "LEFT", px, standing and -px or px)
	panel.light:SetPoint(outer .. "RIGHT", tab, outer .. "RIGHT", -px, standing and -px or px)
	panel.hair = ns.Shapes.Outline(tab, "BORDER", 0, radius + 1, rounded, open)
	panel.hair:SetPoint("TOPLEFT", tab, "TOPLEFT", -px, standing and px or 0)
	panel.hair:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", px, standing and 0 or -px)
	panel.rim = ns.Shapes.Outline(tab, "BORDER", 1, radius, rounded, open)
	panel.rim:SetAllPoints(tab)
	return panel
end

local function Finish()
	if not playing then
		return
	end
	playing = false
	parts.root:SetScript("OnUpdate", nil)
	parts.root:Hide()
	for _, listener in ipairs(listeners) do
		listener()
	end
end

-- Only what moved since the last frame: most of its time the tab stands still.
local function Draw()
	local rise, open, dip, glow = Padlock.FrameAt(locking, elapsed)
	if rise ~= drawnRise then
		drawnRise = rise
		local hidden = (1 - rise) * hideBy
		if up then
			parts.tab:SetPoint("BOTTOMRIGHT", parts.clip, "BOTTOMRIGHT", -clipInset, -hidden)
		else
			parts.tab:SetPoint("TOPRIGHT", parts.clip, "TOPRIGHT", 0, hidden)
		end
		-- The card's round corner under the tab's side: it fills what the curve
		-- leaves out, as soon as the tab is above the card.
		local cornered = up and hidden < tabHeight
		if cornered ~= drawnCornered then
			drawnCornered = cornered
			parts.wedge:SetShown(cornered)
			parts.wedgeRim:SetShown(cornered and parts.framed)
		end
	end
	if dip ~= drawnDip then
		drawnDip = dip
		parts.art:SetPoint("BOTTOM", parts.tab, "BOTTOM", 0, -dip * unit)
	end
	if open ~= drawnOpen then
		drawnOpen = open
		parts.shackle:SetPoint("BOTTOM", parts.art, "BOTTOM", 0, open * TRAVEL * unit)
	end
	if glow ~= drawnGlow then
		drawnGlow = glow
		parts.glow:SetShown(glow > 0)
		parts.glow:SetAlpha(glow)
	end
end

local function Step(_, delta)
	elapsed = elapsed + delta
	if soundAt and elapsed >= soundAt then
		soundAt = nil
		Theme.PlaySound(soundKind)
	end
	if elapsed >= TOTAL then
		Finish()
		return
	end
	Draw()
end

-- Made anew if the interface's scale changed: every piece is sized in pixels.
local function Ensure()
	local dock = GENERAL_CHAT_DOCK
	local px = PixelUtil.ConvertPixelsToUIForRegion(1, dock)
	if parts and parts.px == px then
		return
	end
	if parts then
		parts.root:SetScript("OnHide", nil)
		parts.root:Hide()
	end
	local root = CreateFrame("Frame", nil, dock)
	root:SetFrameStrata(STRATA)
	root:SetFrameLevel(LEVEL)
	root:SetAllPoints(dock)
	root:Hide()
	root:SetScript("OnHide", Finish)

	local clip = CreateFrame("Frame", nil, root)
	clip:SetClipsChildren(true)
	local tab = CreateFrame("Frame", nil, clip)

	local inside = CreateFrame("Frame", nil, tab)
	inside:SetClipsChildren(true)
	inside:SetPoint("TOPLEFT", tab, "TOPLEFT", px, -px)
	inside:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -px, px)
	local art = CreateFrame("Frame", nil, tab)
	art:SetFrameLevel(inside:GetFrameLevel() + 1)
	local tabGlow = ns.Shapes.Glow(inside, GLOW_BOX * ns.Shapes.ArtPixels(dock, 1))
	tabGlow:SetPoint("CENTER", art, "CENTER")
	local looseGlow = ns.Shapes.Glow(art, LOOSE_GLOW_BOX * ns.Shapes.ArtPixels(dock, 1))
	looseGlow:SetPoint("CENTER", art, "CENTER")

	local shackle = art:CreateTexture(nil, "ARTWORK", nil, 0)
	shackle:SetTexture(MEDIA .. "IconLockShackle")
	local body = art:CreateTexture(nil, "ARTWORK", nil, 1)
	body:SetTexture(MEDIA .. "IconLockBody")
	body:SetAllPoints(art)

	local wedge = ns.Shapes.Corner(root, "ARTWORK", 0, "Notch", Theme.CARD_RADIUS, "TOPRIGHT")
	wedge:SetPoint("TOPRIGHT", dock, "TOPRIGHT")
	local wedgeRim = root:CreateTexture(nil, "ARTWORK", nil, 1)
	wedgeRim:SetTexture(WHITE)
	wedgeRim:SetPoint("TOPRIGHT", dock, "TOPRIGHT")
	wedgeRim:SetSize(px, Theme.CARD_RADIUS * px)

	parts = {
		px = px, root = root, clip = clip, tab = tab, art = art, tabGlow = tabGlow, looseGlow = looseGlow,
		shackle = shackle, body = body, wedge = wedge, wedgeRim = wedgeRim,
		panels = {},
	}
end

local function PanelFor(standing)
	local panel = parts.panels[standing]
	if not panel then
		panel = BuildPanel(parts.tab, parts.px, standing)
		parts.panels[standing] = panel
	end
	return panel
end

local function SetPanelShown(panel, shown, framed, shadowed)
	panel.fill:SetShown(shown)
	panel.rim:SetShown(shown and framed)
	panel.light:SetShown(shown and framed)
	panel.hair:SetShown(shown and shadowed)
	panel.shadow:SetShown(shown and shadowed)
end

-- The tab in the theme and the window's background, as it is now.
local function Paint()
	local framed, shadowed = Theme.OPEN_TAB_MARK == "frame", Theme.CARD_SHADOW and true or false
	parts.framed = framed
	parts.glow = Theme.STRIP_HIDDEN and parts.looseGlow or parts.tabGlow
	local unused = parts.glow == parts.looseGlow and parts.tabGlow or parts.looseGlow
	unused:Hide()
	local panel = PanelFor(up)
	local r, g, b, a = ns.Skin.DockHeaderColor()
	panel.fill:SetColor(r, g, b, a)
	parts.wedge:SetVertexColor(r, g, b, a)
	local metal, line = Theme.RIM_TOP, Theme.LINE
	rimEnd:SetRGBA(metal.r, metal.g, metal.b, RIM_ALPHA)
	rimBase:SetRGBA(line.r, line.g, line.b, Theme.HEADER_LINE_ALPHA)
	panel.rim:SetVerticalGradient(up and rimEnd or rimBase, up and rimBase or rimEnd)
	lightEnd:SetRGBA(metal.r, metal.g, metal.b, LIGHT_ALPHA)
	lightGone:SetRGBA(metal.r, metal.g, metal.b, 0)
	local lightHeight = tabHeight * LIGHT_SHARE
	panel.light:SetHeight(lightHeight)
	panel.light:SetFillGradient(up and lightEnd or lightGone, up and lightGone or lightEnd, lightHeight)
	panel.hair:SetColor(Theme.HAIRLINE:GetRGBA())
	wedgeRimTop:SetRGBA(line.r, line.g, line.b, Theme.HEADER_LINE_ALPHA)
	wedgeRimBottom:SetRGBA(line.r, line.g, line.b, 0)
	ns.Shapes.SetGradient(parts.wedgeRim, "VERTICAL", wedgeRimBottom, wedgeRimTop)
	Theme.PaintArt(parts.body, 1, 1)
	Theme.PaintArt(parts.shackle, 1, 1)
	panel.shadow:Layout(parts.tab:GetSize())
	SetPanelShown(panel, true, framed, shadowed)
	local other = parts.panels[not up]
	if other then
		SetPanelShown(other, false)
	end
end

local function Place()
	local dock = GENERAL_CHAT_DOCK
	unit = ns.Shapes.ArtPixels(dock, 1)
	tabHeight = TAB_HEIGHT * unit
	hideBy = tabHeight + unit
	local margin = CLIP_MARGIN * unit
	-- Standing needs the room above the header; without it, it hangs below.
	local room = UIParent:GetTop() * UIParent:GetEffectiveScale() - dock:GetTop() * dock:GetEffectiveScale()
	up = room >= (tabHeight + parts.px) * dock:GetEffectiveScale()

	local width = math.max(2 * math.abs(ns.Header.GripAxis()), MIN_WIDTH * unit)
	local clip, tab, art = parts.clip, parts.tab, parts.art
	tab:SetSize(width, tabHeight)
	tab:ClearAllPoints()
	clip:ClearAllPoints()
	if up then
		clipInset = margin
		clip:SetPoint("BOTTOMRIGHT", dock, "TOPRIGHT", margin, 0)
		clip:SetSize(width + 2 * margin, tabHeight + margin)
	else
		clipInset = 0
		clip:SetPoint("TOPRIGHT", dock, "BOTTOMRIGHT")
		clip:SetSize(width + margin, tabHeight + margin)
	end
	art:SetSize(ART_BOX * unit, ART_BOX * unit)
	parts.shackle:SetSize(ART_BOX * unit, ART_BOX * unit)
end

function Padlock.IsPlaying()
	return playing
end

-- Called when it has gone back (Header.lua's tooltip waits for it).
function Padlock.OnFinished(listener)
	table.insert(listeners, listener)
end

-- `locked`: the state the chat just took. `withSound`: the click that did it
-- has no sound of its own (a window's checkbox does).
function Padlock.Play(locked, withSound)
	if not GENERAL_CHAT_DOCK:IsVisible() or ns.Skin.IsChatHidden() then
		return
	end
	Ensure()
	playing = true
	locking = locked and true or false
	elapsed = 0
	soundAt = withSound and Padlock.SoundTime(locking) or nil
	soundKind = locking and "lock" or "unlock"
	Place()
	Paint()
	drawnRise, drawnOpen, drawnDip, drawnGlow, drawnCornered = nil, nil, nil, nil, nil
	Draw()
	parts.root:Show()
	parts.root:SetScript("OnUpdate", ns.Guard("Padlock.Step", Step))
end
