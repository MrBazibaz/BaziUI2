local ns = BaziUI.Chat
local Theme = ns.Theme

local Scroll = {}
ns.Scroll = Scroll

-- The chat's own scroll bar, drawn in the game's colors, and a sign of
-- what's new below when reading something older. Blizzard's bar
-- (MinimalScrollBar: a track, a thumb, a stepper at each end, and the
-- chat's "back to the bottom" button under it) keeps all its behavior; only
-- its art changes. Its code sets its atlases again on every state change,
-- and the thumb reads its atlas to size itself, so Blizzard's textures stay
-- (at alpha 0) and ours are drawn over them: a dark, sunk groove, a
-- bronze-gold thumb (gold under the mouse and while dragged) and gold
-- chevrons, like the gold glyphs on Blizzard's chat buttons and Everchat's
-- rail (in the theme's metal: Theme.THUMB, Theme.GLYPH). States come from
-- HookScript on those buttons.
--
-- The bar is narrower than its buttons, as Blizzard's is (at their width it
-- looked heavy), and widens while the mouse is near it or the thumb is held,
-- as VS Code's and macOS's do: thin while reading, easy to grab when wanted.
-- It switches in one whole-pixel step on each side: an eased width that
-- grew from the center moved each edge by fractions of a pixel, and the two
-- edges snapped at different moments (the user saw it widen "in two steps").
--
-- While new lines arrived below what's on screen, the bottom button's
-- chevron turns bright gold on a soft glow that beats like a heart; its
-- tooltip says how many. A number on a badge was tried and dropped (the
-- user: the glow and the beat are enough), as was a pill over the messages
-- (it covered them). Blizzard's own flash on that button, which plays
-- whenever the chat isn't at the bottom, new lines or not, is emptied.
--
-- With the game's own art (Theme.GAME_ART, the classic style) the bar is
-- the game's again: Blizzard's textures back at full and ours hidden, and
-- the bottom button in its own art, glowing behind it only while there's
-- something new below (its own flash stays emptied).
--
-- Lines.lua tells of every line added; lines History brings back don't
-- count. Tabs open at the bottom, as Blizzard's do. Until 2026-10-11 a tab
-- that got more new lines than fit opened on the first of them (Discord's
-- way); the user dropped it: in a busy channel nobody reads them all, and it
-- was easy to miss that the view wasn't at the end of the conversation.

-- Screen pixels, times the art's scale on dense screens (Buttons.lua's
-- rule): the bar thin and wide, and its chevrons in interface units.
-- A hairline at rest and a rounded bar near the mouse (2026-10-11: at 4 and
-- 6 the change was a pixel a side, hard to see, and it snapped in place;
-- the user also wanted it thinner at rest). The two are separate shapes that
-- fade into each other, so nothing moves by fractions of a pixel.
local BAR_PIXELS = 2
local BAR_WIDE_PIXELS = 8
local WIDEN_TIME = 0.12
local SHRINK_DELAY = 0.25

-- The bar's relief, as the game's own thumb and track have it: the thumb
-- lit along its left side and shaded along its right, thin or wide, and the
-- wide groove in a dark rim a pixel outside it (along their straight sides;
-- the rounded ends stay plain). Light and shade are laid over the thumb, so
-- the shade always darkens it: colors of their own, a lighter and a darker
-- thumb, came out lighter than the thumb on both sides in game. The thin
-- line has the thumb's too, or the relief came and went as the bar widened.
local EDGE_LIGHT = CreateColor(1, 1, 1, 0.16)
local EDGE_DARK = CreateColor(0, 0, 0, 0.35)
local GROOVE_RIM = CreateColor(0, 0, 0, 0.3)

local GROOVE = CreateColor(0, 0, 0, 0.45)
local GLYPH = Theme.GLYPH
local GLYPH_HOVER = Theme.GLYPH_HOVER

-- The glow behind the bottom button while there's something new below:
-- two quick pulses every BEAT_PERIOD seconds, starting over with each new line.
local GLOW_PIXELS = 30
local GLOW_BASE = 0.2
local GLOW_BEAT = 0.75
local BEAT_PERIOD = 2.6
local HALO = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\Halo"
-- Everchat's gold chevron, the one that opens the list of tabs, and the same
-- over a bar for the button to the newest line (art/add-icons.py): the
-- game's thin chevron was flat beside the header's icons, and turned for the
-- top stepper it came out a row off on one side.
local CHEVRON = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconChevron"
local CHEVRON_END = "Interface\\AddOns\\BaziUI\\Assets\\Chat\\Everchat\\IconChevronEnd"

local L = ns.L

-- By chat frame: our art on its bar, lines not yet seen below, and whether
-- Search.lua has taken the window over.
local bars = {}
local unread = {}
local suspended = {}
local driver

local function Pixel(region)
	return PixelUtil.ConvertPixelsToUIForRegion(1, region)
end

-- 1 at the usual resolutions, 2 on 4K screens.
local function ArtScale(region)
	return math.max(1, math.ceil(1 / Pixel(region) - 0.5))
end

local function Tint(region, color, alpha)
	local r, g, b, a = color:GetRGBA()
	region:SetVertexColor(r, g, b, alpha or a)
end

-- A bar along a region's height in its two widths: a square hairline and a
-- wide one with round ends (Shapes has corner art for its radius), shown in
-- turn by SetWide (0 thin, 1 wide).
local BarMixin = {}

-- The hairline's alpha in its color: a vertex color's alpha is the
-- texture's own, which SetWide sets.
function BarMixin:SetColor(r, g, b, a)
	self.thin:SetColorTexture(r, g, b, a)
	self.wide:SetColor(r, g, b, a)
end

function BarMixin:SetWide(amount)
	self.thin:SetAlpha(1 - amount)
	self.thin:SetShown(amount < 1)
	self.wide:SetAlpha(amount)
	self.wide:SetShown(amount > 0)
	for _, edge in ipairs(self.wideEdges) do
		edge:SetAlpha(amount)
		edge:SetShown(amount > 0)
	end
	for _, edge in ipairs(self.thinEdges) do
		edge:SetAlpha(1 - amount)
		edge:SetShown(amount < 1)
	end
end

-- The hairline is one plain texture, and the wide bar's corners leave a real
-- strip between them: Shapes pieces of size 0 (a radius-0 shape, or two 4px
-- corners on an 8px bar) were drawn as wide square bands and a light stripe
-- down the middle (2026-10-11).
-- `relief`: "thumb" (lit left, shaded right) or "groove" (a dark rim
-- outside the wide bar).
local function Bar(owner, layer, relief)
	local scale, px = ArtScale(owner), Pixel(owner)
	local bar = CreateFromMixins(BarMixin)
	local thin = owner:CreateTexture(nil, layer)
	thin:SetColorTexture(1, 1, 1, 1)
	thin:SetPoint("TOP", owner, "TOP")
	thin:SetPoint("BOTTOM", owner, "BOTTOM")
	thin:SetWidth(BAR_PIXELS * scale * px)
	bar.thin = thin
	local radius = math.min(7, (BAR_WIDE_PIXELS / 2 - 1) * scale)
	local wide = ns.Shapes.Fill(owner, layer, 0, radius)
	wide.box:SetPoint("TOP", owner, "TOP")
	wide.box:SetPoint("BOTTOM", owner, "BOTTOM")
	wide.box:SetWidth(BAR_WIDE_PIXELS * scale * px)
	bar.wide = wide
	-- Along the straight sides (the wide bar's between its rounded ends), a
	-- column of `scale` pixels, over the bar.
	local width = scale * px
	local function Edge(list, box, inset, point, relativePoint, color)
		local edge = owner:CreateTexture(nil, layer, nil, 1)
		edge:SetPoint("TOP" .. point, box, "TOP" .. relativePoint, 0, -inset)
		edge:SetPoint("BOTTOM" .. point, box, "BOTTOM" .. relativePoint, 0, inset)
		edge:SetWidth(width)
		edge:SetColorTexture(color:GetRGBA())
		table.insert(list, edge)
	end
	bar.wideEdges, bar.thinEdges = {}, {}
	local inset = radius * px
	if relief == "groove" then
		Edge(bar.wideEdges, wide.box, inset, "RIGHT", "LEFT", GROOVE_RIM)
		Edge(bar.wideEdges, wide.box, inset, "LEFT", "RIGHT", GROOVE_RIM)
	elseif relief == "thumb" then
		Edge(bar.wideEdges, wide.box, inset, "LEFT", "LEFT", EDGE_LIGHT)
		Edge(bar.wideEdges, wide.box, inset, "RIGHT", "RIGHT", EDGE_DARK)
		Edge(bar.thinEdges, thin, 0, "LEFT", "LEFT", EDGE_LIGHT)
		Edge(bar.thinEdges, thin, 0, "RIGHT", "RIGHT", EDGE_DARK)
	end
	bar:SetWide(0)
	return bar
end

-- The same bar for Everchat's other scrolling views (Whispers.lua).
Scroll.CreateBar = Bar

-- At the header's icons' size, on whole pixels; the top one flipped (turned,
-- the art's pixels fell a row off on one side).
local function Chevron(parent, up, file, pixels)
	local glyph = parent:CreateTexture(nil, "ARTWORK")
	glyph:SetTexture(file or CHEVRON)
	local size = ns.Shapes.ArtPixels(glyph, pixels or Theme.ICON_PIXELS)
	glyph:SetSize(size, size)
	if up then
		glyph:SetTexCoord(0, 1, 1, 0)
	end
	return glyph
end

-- Gold art as the header's icons are painted: a little darker at rest,
-- full under the mouse, in the theme's metal.
-- A bar of the options window keeps the game's gold (`art.look`
-- Theme.GAME, as the window does): the art as drawn, never tinted.
local function PaintGlyph(glyph, lit, alpha, look)
	local shade = lit and 1 or Theme.ICON_REST
	if look and look ~= Theme then
		glyph:SetDesaturated(false)
		glyph:SetVertexColor(shade, shade, shade, alpha)
		return
	end
	Theme.PaintArt(glyph, shade, alpha)
end

-- A stepper: our chevron, brighter under the mouse, dim while disabled.
-- `art.paints` gathers what to paint again for a new theme.
local function StyleStepper(stepper, up, art)
	if not stepper then
		return
	end
	local glyph = Chevron(stepper, up, nil, art.glyphPixels)
	glyph:SetPoint("CENTER")
	table.insert(art.ours, glyph)
	if stepper.Texture then
		table.insert(art.games, stepper.Texture)
	end
	local look = art.look
	local function Update()
		if not stepper:IsEnabled() then
			PaintGlyph(glyph, false, 0.3, look)
		else
			local lit = stepper:IsMouseOver()
			PaintGlyph(glyph, lit, (lit and look.GLYPH_HOVER or look.GLYPH).a, look)
		end
	end
	for _, script in ipairs({ "OnEnter", "OnLeave", "OnEnable", "OnDisable" }) do
		stepper:HookScript(script, Update)
	end
	Update()
	table.insert(art.paints, Update)
	return glyph
end

local function StyleThumb(thumb, art)
	for _, key in ipairs({ "Begin", "Middle", "End" }) do
		if thumb[key] then
			table.insert(art.games, thumb[key])
		end
	end
	local grip = Bar(thumb, "OVERLAY", "thumb")
	art.grip = grip
	local function Update()
		local held = art.held or thumb:IsMouseOver()
		grip:SetColor((held and (art.thumbHover or art.look.THUMB_HOVER) or art.thumbRest or art.look.THUMB):GetRGBA())
	end
	table.insert(art.paints, Update)
	thumb:HookScript("OnEnter", Update)
	thumb:HookScript("OnLeave", Update)
	thumb:HookScript("OnMouseDown", function()
		art.held = true
		Update()
	end)
	thumb:HookScript("OnMouseUp", function()
		art.held = false
		Update()
	end)
	Update()
end

local function StyleTrack(track, art)
	for _, key in ipairs({ "Begin", "Middle", "End" }) do
		if track[key] then
			table.insert(art.games, track[key])
		end
	end
	local groove = Bar(track, "BACKGROUND", "groove")
	groove:SetColor(GROOVE:GetRGBA())
	art.groove = groove
	art.wideness = 0
	art.awayTime = SHRINK_DELAY
end

-- Wide while the mouse is near the bar (a good way to its left, where it
-- comes from) or the thumb is held; thin again a moment after it leaves.
-- The change fades over WIDEN_TIME.
local function Widen(scrollBar, art, elapsed)
	local near = art.held or scrollBar:IsMouseOver(0, 0, -12, 6)
	art.awayTime = near and 0 or art.awayTime + elapsed
	local target = (near or art.awayTime < SHRINK_DELAY) and 1 or 0
	if art.wideness == target then
		return
	end
	local step = elapsed / WIDEN_TIME
	art.wideness = target > art.wideness and math.min(target, art.wideness + step)
		or math.max(target, art.wideness - step)
	art.groove:SetWide(art.wideness)
	art.grip:SetWide(art.wideness)
end

-- A heartbeat over one period: a pulse, then a smaller one.
local function Beat(t)
	local function Pulse(center, width)
		local d = (t - center) / width
		return math.exp(-d * d)
	end
	return math.max(Pulse(0.18, 0.09), 0.7 * Pulse(0.46, 0.11))
end

-- In Everchat's small tooltip, like its other hints.
local function ShowBottomTip(button)
	local art = bars[button:GetParent()]
	local lines
	if art and art.count > 0 then
		lines = {
			{ L.scrollNewMessages:format(art.count), HIGHLIGHT_FONT_COLOR },
			{ L.scrollBottomHint, GREEN_FONT_COLOR },
		}
	else
		lines = { { L.scrollBottom, HIGHLIGHT_FONT_COLOR } }
	end
	ns.Links.ShowSmallTip(button, "ANCHOR_LEFT", lines)
end

-- The bottom button: a chevron over a bar ("to the end", one picture),
-- glowing while there's something new below.
local function StyleBottomButton(button, art)
	-- Its art, kept to be put back with the game's art; emptied otherwise.
	art.buttonArt = {}
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture(), button:GetDisabledTexture() }) do
		table.insert(art.buttonArt, { texture = texture, atlas = texture:GetAtlas(), file = texture:GetTextureFileID() })
	end
	if button.Flash then
		button.Flash:SetTexture(nil)
	end
	local px, scale = Pixel(button), ArtScale(button)
	local glyph = Chevron(button, false, CHEVRON_END)
	glyph:SetPoint("CENTER")
	-- Blizzard anchors this button to the resize grabber, not the bar, and
	-- its center fell a pixel off the steppers' (user, 2026-10-11; centering
	-- on the bar with a rounded offset missed the other way): the glyph takes
	-- the down stepper's center exactly, once positions are known
	-- (Scroll.Update), so both snap alike.
	art.alignGlyph = function()
		local stepperX = art.forward and art.forward:GetCenter()
		local buttonX = button:GetCenter()
		if not stepperX or not buttonX then
			return false
		end
		glyph:ClearAllPoints()
		glyph:SetPoint("CENTER", button, "CENTER", stepperX - buttonX, 0)
		return true
	end
	local glow = button:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(HALO)
	glow:SetBlendMode("ADD")
	glow:SetSize(GLOW_PIXELS * scale * px, GLOW_PIXELS * scale * px)
	glow:SetPoint("CENTER", glyph, "CENTER")
	Tint(glow, Theme.GLOW, 1)
	glow:Hide()
	table.insert(art.paints, function()
		Tint(glow, Theme.GLOW, 1)
		-- The chevron and its bar take the new colors on the next update.
		art.shownLit = nil
	end)

	art.glyph, art.glow = glyph, glow
	table.insert(art.ours, glyph)
	art.count = 0
	button:HookScript("OnEnter", function(self)
		art.hover = true
		ShowBottomTip(self)
	end)
	button:HookScript("OnLeave", function(self)
		art.hover = false
		ns.Links.HideSmallTip(self)
	end)
end

-- How much of each window's bottom button shows: all of it, save while the
-- chat hides at rest (Skin.lua), when the game may still leave the button
-- itself in sight (it keeps a flashing one at full).
local fades = {}

function Scroll.SetFade(chatFrame, fade)
	if fades[chatFrame] ~= fade then
		fades[chatFrame] = fade
		local art = bars[chatFrame]
		if art then
			-- Painted again on the next update.
			art.shownLit = nil
		end
	end
end

-- What the bottom button shows for the lines below.
function Scroll.Update(chatFrame)
	local art = bars[chatFrame]
	if not art or not art.glyph then
		return
	end
	if not art.aligned and art.alignGlyph then
		art.aligned = art.alignGlyph()
	end
	local offset = chatFrame:GetScrollOffset()
	if offset == 0 then
		unread[chatFrame] = nil
	end
	local count = suspended[chatFrame] and 0 or math.min(offset, unread[chatFrame] or 0)
	-- A new line (or the first) starts the beat over.
	if count > art.count then
		art.beatStart = GetTime()
	end
	art.count = count
	local new = count > 0
	-- Called every frame for the window on show: the art only changes with
	-- the state; the beat below is the only thing that moves.
	local lit = new or art.hover or false
	local fade = fades[chatFrame] or 1
	if art.shownNew ~= new or art.shownLit ~= lit then
		art.shownNew, art.shownLit = new, lit
		art.glow:SetShown(new and fade > 0)
		local color = lit and GLYPH_HOVER or GLYPH
		PaintGlyph(art.glyph, lit, color.a * fade)
		-- The game's art, gone with the chat hidden at rest.
		if art.game then
			for _, entry in ipairs(art.buttonArt) do
				entry.texture:SetAlpha(fade)
			end
		end
	end
	if new and fade > 0 then
		art.glow:SetAlpha(fade * (GLOW_BASE + GLOW_BEAT * Beat((GetTime() - art.beatStart) % BEAT_PERIOD)))
	end
end

local function Tick(_, elapsed)
	for chatFrame, art in pairs(bars) do
		if chatFrame:IsVisible() then
			Scroll.Update(chatFrame)
			if art.groove and art.grip and not art.game then
				Widen(chatFrame.ScrollBar, art, elapsed)
			end
		end
	end
end

-- A line added to a window: new while the window is out of sight or
-- scrolled up.
local function OnLineAdded(chatFrame, _, replayed)
	if replayed or not bars[chatFrame] then
		return
	end
	if not chatFrame:IsVisible() or chatFrame:GetScrollOffset() > 0 then
		unread[chatFrame] = (unread[chatFrame] or 0) + 1
	end
end

-- Everchat's art on the bar, or the game's (Theme.GAME_ART).
local function ShowArt(art)
	local game = Theme.GAME_ART and not art.fixed
	if art.game == game then
		return
	end
	art.game = game
	if art.placeButton then
		art.placeButton()
		art.aligned = false
	end
	for _, texture in ipairs(art.games) do
		texture:SetAlpha(game and 1 or 0)
	end
	for _, region in ipairs(art.ours) do
		region:SetShown(not game)
	end
	if art.groove then
		art.wideness = 0
		for _, bar in ipairs({ art.groove, art.grip }) do
			bar:SetWide(0)
			bar.thin:SetShown(not game)
			for _, edge in ipairs(bar.thinEdges) do
				edge:SetShown(not game)
			end
		end
	end
	for _, entry in ipairs(art.buttonArt or {}) do
		local texture = entry.texture
		if not game then
			texture:SetTexture(nil)
		elseif entry.atlas then
			texture:SetAtlas(entry.atlas)
		else
			texture:SetTexture(entry.file)
		end
	end
	art.shownLit = nil
end

local function PlaceScrollbar(chatFrame, art)
	local bar = chatFrame.ScrollBar
	if art.placeButton then art.placeButton() end
	if not bar then return end
	if ns.db.scrollbarLeft then
		if not art.rightAnchors then
			art.rightAnchors = {}
			for i = 1, bar:GetNumPoints() do
				art.rightAnchors[i] = {bar:GetPoint(i)}
			end
		end
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", chatFrame, "TOPLEFT", -ns.Theme.PANEL_PAD_LEFT - 2, 0)
		local button = chatFrame ~= COMBATLOG and chatFrame.ScrollToBottomButton
		if button and art.placeButton then
			button:ClearAllPoints()
			button:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMLEFT", -ns.Theme.PANEL_PAD_LEFT - 2, 0)
			bar:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT")
		else
			bar:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMLEFT", -ns.Theme.PANEL_PAD_LEFT - 2, 0)
		end
	elseif art.rightAnchors then
		bar:ClearAllPoints()
		for _, point in ipairs(art.rightAnchors) do bar:SetPoint(unpack(point, 1, 5)) end
		art.rightAnchors = nil
	end
	art.aligned = false
end

function Scroll.RefreshSide()
	for chatFrame, art in pairs(bars) do PlaceScrollbar(chatFrame, art) end
end

local function Setup(chatFrame)
	if bars[chatFrame] then
		return
	end
	local bar = chatFrame.ScrollBar
	local art = { paints = {}, games = {}, ours = {}, look = Theme }
	bars[chatFrame] = art
	if bar and bar.Track and bar.Track.Thumb then
		StyleTrack(bar.Track, art)
		StyleThumb(bar.Track.Thumb, art)
		StyleStepper(bar.Back, true, art)
		art.forward = StyleStepper(bar.Forward, false, art)
	end
	-- The combat log keeps its scroll bar's new look but counts nothing.
	if chatFrame ~= COMBATLOG and chatFrame.ScrollToBottomButton then
		-- Blizzard stacks it on its resize grabber (16 units, invisible here:
		-- Resize.lua), which left a gap under it; at the grabber's foot the
		-- bar, anchored to the button, reaches down too.
		-- With the game's art, or with no footer, it goes back on the grabber,
		-- where the game has it, since Everchat's size grip takes the
		-- grabber's place then (Resize.lua).
		local button, grabber = chatFrame.ScrollToBottomButton, chatFrame.ResizeButton
		if grabber then
			art.placeButton = function()
				button:ClearAllPoints()
				if Theme.GAME_ART or not ns.Skin.IsFooterShown(chatFrame) then
					button:SetPoint("BOTTOMRIGHT", grabber, "TOPRIGHT", -2, -2)
				else
					button:SetPoint("BOTTOMRIGHT", grabber, "BOTTOMRIGHT", -2, 2)
				end
			end
		end
		StyleBottomButton(button, art)
	end
	PlaceScrollbar(chatFrame, art)
	ShowArt(art)
end

-- Another window's MinimalScrollBar (the options window's) in Everchat's
-- look, in the game's gold whatever the chat's theme, as that window keeps
-- it: always wide (a bar there is for using, and in no one's way), its
-- chevrons the size of the game's own bar's.
local WINDOW_GLYPH_PIXELS = 20
-- Its thumb quieter than the chat's: on the window's opaque body the chat's
-- bronze-gold stood out (the user); lit, it takes the chat's at rest.
local WINDOW_THUMB = CreateColor(0.78, 0.6, 0.3, 0.5)

function Scroll.StyleBar(scrollBar)
	local art = {
		paints = {}, games = {}, ours = {}, look = Theme.GAME, fixed = true, glyphPixels = WINDOW_GLYPH_PIXELS,
		thumbRest = WINDOW_THUMB, thumbHover = Theme.GAME.THUMB,
	}
	StyleTrack(scrollBar.Track, art)
	StyleThumb(scrollBar.Track.Thumb, art)
	StyleStepper(scrollBar.Back, true, art)
	StyleStepper(scrollBar.Forward, false, art)
	ShowArt(art)
	art.groove:SetWide(1)
	art.grip:SetWide(1)
end

local function SetupAllChatFrames()
	for _, name in pairs(CHAT_FRAMES) do
		Setup(_G[name])
	end
end

-- While Search.lua shows its results, nothing counts as new below.
function Scroll.SetSuspended(chatFrame, isSuspended)
	suspended[chatFrame] = isSuspended or nil
end

function Scroll.Init()
	SetupAllChatFrames()
	hooksecurefunc("FCF_OpenNewWindow", SetupAllChatFrames)
	hooksecurefunc("FCF_OpenTemporaryWindow", SetupAllChatFrames)
	ns.Lines.AddListener(OnLineAdded)
	ns.Skin.OnFooterChanged(function(chatFrame)
		local art = bars[chatFrame]
		if art then PlaceScrollbar(chatFrame, art) end
	end)
	driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", ns.Guard("Scroll.Tick", Tick))
	-- A new theme: every bar in its colors.
	Theme.OnChanged(function()
		for _, art in pairs(bars) do
			for _, paint in ipairs(art.paints) do
				paint()
			end
			ShowArt(art)
		end
	end)
end
