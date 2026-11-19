-- Bazi UI Unit Frames, first opt-in runtime slice.
-- FlareUI layout reference; original implementation for Bazi UI.
-- Does not replace Blizzard frames until the replacement has been tested.
local addon = BaziUI
addon.UnitFrames = addon.UnitFrames or {}
local M = addon.UnitFrames
local function cfg()
    return addon.db and addon.db.profile and addon.db.profile.unitframes
end
local units = {
    player = {unit="player", x=-260, y=-180},
    target = {unit="target", x=260, y=-180},
    focus = {unit="focus", x=260, y=-250},
    pet = {unit="pet", x=-260, y=-250},
}
local frames = {}
local movers = {}
local moving = false
local previewIndicators = false
local previewPetCast = false
local auraPreview = {}
function M:SetAuraPreview(key, kind, enabled)
    if not units[key] or (kind ~= "buffs" and kind ~= "debuffs") then return end
    auraPreview[key] = auraPreview[key] or {}
    auraPreview[key][kind] = enabled == true
    self:Refresh()
end
function M:SetTargetAuraPreview(kind, enabled)
    self:SetAuraPreview("target", kind, enabled)
end
function M:ClearTargetAuraPreviews()
    self:SetAuraPreview("target", "buffs", false)
    self:SetAuraPreview("target", "debuffs", false)
end

local indicatorNames = {"pvpIcon", "leaderIcon", "raidIcon", "roleIcon", "classIcon", "happinessIcon"}
local indicatorFields = {"pvp", "leader", "raid", "role", "classification", "happiness"}
function M:SetIndicatorPreview(enabled)
    previewIndicators = enabled == true
    self:Refresh()
end
function M:SetPetCastPreview(enabled)
    previewPetCast = enabled == true
    self:Refresh()
end
local function position(settings, key)
    settings.frames = settings.frames or {}
    settings.frames[key] = settings.frames[key] or {}
    local own = settings.frames[key]
    local spec = units[key]
    if own.x == nil then own.x = spec.x end
    if own.y == nil then own.y = spec.y end
    return own
end
local function applyPosition(f, settings, key)
    local own = position(settings, key)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", own.x, own.y)
end
function M:SetPosition(key, x, y)
    local settings = cfg()
    if not settings or not units[key] or (InCombatLockdown and InCombatLockdown()) then return false end
    local own = position(settings, key)
    own.x = math.floor(tonumber(x) or own.x)
    own.y = math.floor(tonumber(y) or own.y)
    if frames[key] then applyPosition(frames[key], settings, key) end
    if movers[key] then movers[key]:ClearAllPoints(); movers[key]:SetPoint("CENTER", UIParent, "CENTER", own.x, own.y) end
    if self.onPositionChanged then self.onPositionChanged(key, own.x, own.y) end
    return true
end
function M:SetMoveMode(value)
    if InCombatLockdown and InCombatLockdown() then return false end
    moving = value == true
    self:Refresh()
    return true
end
function M:IsMoveMode() return moving end
local layoutKeys = {"indicatorSize", "indicatorX", "indicatorY","barWidth", "hpHeight", "powerHeight", "portraitSize", "portraitX", "portraitY", "flipPortrait", "showPvP", "showLeader", "showRaidMarker", "showRole", "showClassification", "showHappiness", "hpText", "powerText", "fontSize", "nameFontSize", "hpFontSize", "powerFontSize", "fontFace", "showName", "hpTextX", "hpTextY", "powerTextX", "powerTextY", "hpFontColor", "powerFontColor", "hpTextAnchor", "powerTextAnchor", "levelFontSize", "levelTextX", "levelTextY"}
local function unitSettings(settings, key)
    settings.frames = settings.frames or {}
    local own = settings.frames[key]
    if not own then
        own = {}
        settings.frames[key] = own
    end
    -- Migrate existing shared dimensions once per frame without losing saved values.
    for _, name in ipairs(layoutKeys) do
        if own[name] == nil then own[name] = settings[name] end
    end
    return own
end
-- Blizzard-managed aura containers. Never read protected aura payloads in addon code.
local auraAvailable
local function ensureAuraLibrary()
    if auraAvailable ~= nil then return auraAvailable end
    if C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer")
        and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    auraAvailable = true
    return true
end
local function styleAuraText(text, opt, field, fallback)
    local size = math.max(0, math.min(24, tonumber(opt[field]) or fallback))
    if size == 0 then text:SetAlpha(0); return end
    text:SetAlpha(1)
    local font = (GameFontNormalSmall and select(1, GameFontNormalSmall:GetFont())) or "Fonts\\FRIZQT__.TTF"
    text:SetFont(font, size, "OUTLINE")
    text:SetTextColor(1, 0.94, 0.72, 1)
end
local function addAuraBorder(parent)
    -- Thin inset frame, using the built-in nine-slice tooltip border.
    -- Unlike UI-Quickslot2 this does not draw a giant square over the icon.
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", parent, "TOPLEFT", -1.5, 1.5)
    border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1.5, -1.5)
    border:SetFrameLevel(parent:GetFrameLevel() + 1)
    border:EnableMouse(false)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 6,
        insets = {left=0, right=0, top=0, bottom=0},
    })
    border:SetBackdropBorderColor(0.48, 0.34, 0.18, 0.95)
    return border
end
local function initializeAuraButton(button, size, opt, entry)
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    addAuraBorder(button)
    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    styleAuraText(count, opt, "stackFontSize", 11)
    local duration = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    duration:SetPoint("CENTER")
    styleAuraText(duration, opt, "durationFontSize", 10)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetHideCountdownNumbers(true)
    pcall(button.SetIcon, button, icon)
    pcall(button.SetApplicationCount, button, count, {})
    if button.SetDurationText then pcall(button.SetDurationText, button, duration)
    elseif button.SetAuraDurationText then pcall(button.SetAuraDurationText, button, duration) end
    pcall(button.SetDurationCooldown, button, cooldown)
    entry.texts[#entry.texts + 1] = {duration=duration, count=count}
end

local function createLiveAuras(f)
    if f.liveAuras or not ensureAuraLibrary() then return end
    f.liveAuras = {}
    for _, kind in ipairs({"buffs", "debuffs"}) do
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
        if ok and container and type(container.AddAuraGroup) == "function" then
            container:SetSize(1, 1)
            container:SetFrameLevel(f:GetFrameLevel() + 10)
            container:Hide()
            local own = unitSettings(cfg() or {}, f.unit)
            local opt = own["aura_" .. kind] or {}
            local size = math.max(12, math.min(48, tonumber(opt.size) or 24))
            local gap = math.max(0, math.min(20, tonumber(opt.spacing) or 2))
            local count = math.max(1, math.min(40, tonumber(opt.count) or 12))
            local entry = {frame=container, size=size, gap=gap, count=count, texts={}}
            local options = {
                maxFrameCount = count, candidateFilters = {},
                initializeFrame = function(button) initializeAuraButton(button, size, opt, entry) end,
                layout = { elementWidth=size, elementHeight=size,
                    elementSpacing=gap, lineSpacing=gap, groupSpacing=gap, groupLineSpacing=gap },
            }
            local added = pcall(container.AddAuraGroup, container, kind,
                kind == "buffs" and "HELPFUL" or "HARMFUL", options)
            if added then
                pcall(container.SetUnit, container, f.unit)
                f.liveAuras[kind] = entry
            end
        end
    end
end
local function updateLiveAuras(f)
    if not f.liveAuras or (InCombatLockdown and InCombatLockdown()) then return end
    local own = unitSettings(cfg() or {}, f.unit)
    for _, kind in ipairs({"buffs", "debuffs"}) do
        local entry = f.liveAuras[kind]
        if entry then
            local c = entry.frame
            local opt = own["aura_" .. kind] or {}
            for _, texts in ipairs(entry.texts) do
                styleAuraText(texts.duration, opt, "durationFontSize", 10)
                styleAuraText(texts.count, opt, "stackFontSize", 11)
            end
            local enabled = opt.enabled
            if enabled == nil then enabled = f.unit ~= "player" end
            local size = math.max(12, math.min(48, tonumber(opt.size) or 24))
            local gap = math.max(0, math.min(20, tonumber(opt.spacing) or 2))
            local count = math.max(0, math.min(40, tonumber(opt.count) or 12))
            local horizontal = opt.horizontal == "left" and "LEFT" or "RIGHT"
            local vertical = opt.vertical == "up" and "UP" or "DOWN"
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", f, "TOPLEFT", tonumber(opt.x) or 0,
                tonumber(opt.y) or (kind == "buffs" and 32 or -58))
            if AnchorUtil and AnchorUtil.FlowDirection then
                pcall(c.SetFlowLayoutAxis, c, AnchorUtil.FlowLayoutAxis.Horizontal)
                pcall(c.SetFlowLayoutAnchorPoint, c, (vertical == "UP" and "BOTTOM" or "TOP") .. (horizontal == "LEFT" and "RIGHT" or "LEFT"))
                pcall(c.SetFlowLayoutGrowthDirection, c,
                    AnchorUtil.FlowDirection[horizontal == "LEFT" and "Left" or "Right"],
                    AnchorUtil.FlowDirection[vertical == "UP" and "Up" or "Down"])
            end
            pcall(c.SetFlowLayoutMaximumLineSize, c, math.max(size, (size + gap) * math.max(1, math.min(20, tonumber(opt.perRow) or 6)) - gap))
            if c.SetAuraGroupLayout then
                pcall(c.SetAuraGroupLayout, c, kind, {
                    elementWidth=size, elementHeight=size, elementSpacing=gap,
                    lineSpacing=gap, groupSpacing=gap, groupLineSpacing=gap })
            end
            -- Group count is fixed at creation. Hide zero-count groups without deleting them.
            local active = enabled and count > 0 and cfg() and cfg().enabled ~= false and cfg()[f.unit]
                and not (auraPreview[f.unit] and auraPreview[f.unit][kind])
            pcall(c.SetEnabled, c, active == true)
            c:SetShown(active == true)
            if active and c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
        end
    end
end
local function updateAuraPreview(f)
    if not f then return end
    if not f.auraPreview then
        f.auraPreview = {}
        for _, kind in ipairs({"buffs", "debuffs"}) do
            local group = CreateFrame("Frame", nil, f)
            group:SetSize(200, 90)
            group:EnableMouse(false)
            group:SetFrameLevel(f:GetFrameLevel() + 9)
            group.tiles = {}
            for i = 1, 20 do
                local tile = group:CreateTexture(nil, "ARTWORK")
                tile:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                tile:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                -- Use a real nine-slice border rather than stretching the
                -- entire tooltip texture over the preview icon.
                local border = CreateFrame("Frame", nil, group, "BackdropTemplate")
                border:SetPoint("TOPLEFT", tile, "TOPLEFT", -1.5, 1.5)
                border:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", 1.5, -1.5)
                border:SetFrameLevel(group:GetFrameLevel() + 1)
                border:EnableMouse(false)
                border:SetBackdrop({
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 6,
                    insets = {left=0, right=0, top=0, bottom=0},
                })
                border:SetBackdropBorderColor(0.48, 0.34, 0.18, 0.95)
                group.tiles[i] = tile
                group.tiles[i .. "_border"] = border
            end
            f.auraPreview[kind] = group
        end
    end
    local own = unitSettings(cfg() or {}, f.unit)
    for _, kind in ipairs({"buffs", "debuffs"}) do
        local group = f.auraPreview[kind]
        local opt = own["aura_" .. kind] or {}
        local size = math.max(12, math.min(48, tonumber(opt.size) or 24))
        local count = math.max(0, math.min(40, tonumber(opt.count) or 12))
        local perRow = math.max(1, math.min(20, tonumber(opt.perRow) or 6))
        local spacing = math.max(0, math.min(20, tonumber(opt.spacing) or 2))
        group:ClearAllPoints()
        local horizontalLeft = opt.horizontal == "left"
        local verticalUp = opt.vertical == "up"
        -- Match the live container origin exactly; do not anchor the preview\n        -- by its opposite corner (which shifts it by the whole group size).\n        -- The live container is hidden while preview is enabled. Anchoring
        -- to that hidden frame also hides the preview through frame hierarchy.
        -- Use the same unit-frame origin and offsets as the live container.
        group:SetPoint("TOPLEFT", f, "TOPLEFT", tonumber(opt.x) or 0,
            tonumber(opt.y) or (kind == "buffs" and 32 or -58))
        group:SetShown(auraPreview[f.unit] and auraPreview[f.unit][kind] == true)
        for i, tile in ipairs(group.tiles) do
            group.tiles[i .. "_border"]:SetShown(auraPreview[f.unit] and auraPreview[f.unit][kind] == true and i <= math.min(count, #group.tiles))
            tile:SetShown(auraPreview[f.unit] and auraPreview[f.unit][kind] == true and i <= math.min(count, #group.tiles))
            tile:SetSize(size, size)
            tile:ClearAllPoints()
            local col, row = (i-1) % perRow, math.floor((i-1)/perRow)
            local dx = col * (size + spacing) * (opt.horizontal == "left" and -1 or 1)
            local dy = row * (size + spacing) * (opt.vertical == "up" and 1 or -1)
            tile:SetPoint("TOPLEFT", group, "TOPLEFT", dx, dy)
        end
    end
end

function M:CopyLayout(source, destination)
    local settings = cfg()
    if not settings or not units[source] or not units[destination] or source == destination then return false end
    local from = unitSettings(settings, source)
    local to = unitSettings(settings, destination)
    for _, name in ipairs(layoutKeys) do
        if type(from[name]) == "table" then
            to[name] = {}
            for k, v in pairs(from[name]) do to[name][k] = v end
        else
            to[name] = from[name]
        end
    end
    self:Refresh()
    return true
end

-- Pass secret unit values directly to Blizzard's FontString formatter.
-- Never do Lua arithmetic or string concatenation with secret numbers.
local function setBarText(fontString, unit, template, health)
    if not template or template == "" then fontString:SetText(""); return end
    local current = health and UnitHealth(unit) or UnitPower(unit)
    local maximum = health and UnitHealthMax(unit) or UnitPowerMax(unit)
    local percent
    if health and UnitHealthPercent then
        percent = UnitHealthPercent(unit)
    elseif not health and UnitPowerPercent then
        percent = UnitPowerPercent(unit)
    end
    local args = {}
    local fmt = template:gsub("{([%a]+)}", function(tag)
        if tag == "current" then args[#args + 1] = current; return "%s" end
        if tag == "max" then args[#args + 1] = maximum; return "%s" end
        if tag == "percent" then
            args[#args + 1] = percent or "?"; return "%s"
        end
        return "{" .. tag .. "}"
    end)
    -- SetFormattedText is implemented by WoW and accepts secret numeric arguments.
    fontString:SetFormattedText(fmt, unpack(args))
end
local function updateExtras(f, own)
    local unit = f.unit
    local function readable(v) return not (issecretvalue and issecretvalue(v)) and v end
    f.pvpIcon:SetShown(own.showPvP ~= false and (previewIndicators or readable(UnitIsPVP(unit)) == true or readable(UnitIsPVPFreeForAll(unit)) == true))
    f.leaderIcon:SetShown(own.showLeader ~= false and (previewIndicators or (UnitIsGroupLeader and readable(UnitIsGroupLeader(unit)) == true)))
    local marker = GetRaidTargetIndex(unit)
    if issecretvalue and issecretvalue(marker) then marker = nil end
    f.raidIcon:SetShown(own.showRaidMarker ~= false and (previewIndicators or type(marker) == "number"))
    if previewIndicators then SetRaidTargetIconTexture(f.raidIcon, 1)
    elseif type(marker) == "number" then SetRaidTargetIconTexture(f.raidIcon, marker) end
    local role = UnitGroupRolesAssigned and readable(UnitGroupRolesAssigned(unit))
    f.roleIcon:SetShown(own.showRole ~= false and (previewIndicators or role == "TANK" or role == "HEALER" or role == "DAMAGER"))
    if role == "TANK" then f.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
    elseif role == "HEALER" then f.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
    else f.roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64) end
    -- Pet happiness is only exposed on clients with the classic hunter-pet API.
    local happiness
    if unit == "pet" then
        if C_PetInfo and type(C_PetInfo.GetPetHappiness) == "function" then
            happiness = readable(C_PetInfo.GetPetHappiness())
        elseif type(GetPetHappiness) == "function" then
            happiness = readable(GetPetHappiness())
        end
    end
    f.happinessIcon:SetShown(unit == "pet" and own.showHappiness ~= false and
        (previewIndicators or type(happiness) == "number"))
    -- Blizzard's happiness atlas is a single icon; don't crop the old sprite sheet.
    if f.happinessIcon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-PetHappiness") then
        f.happinessIcon:SetAtlas("UI-PetHappiness", false)
    else
        local index = type(happiness) == "number" and (math.max(1, math.min(3, happiness)) - 1) or 2
        f.happinessIcon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
        f.happinessIcon:SetTexCoord(index / 3, (index + 1) / 3, 0, 1)
    end
    local classification = UnitClassification and readable(UnitClassification(unit))
    f.classIcon:SetShown(own.showClassification ~= false and
        (previewIndicators or classification == "elite" or classification == "rare" or classification == "rareelite" or classification == "worldboss"))
    -- FlareUI uses Blizzard's native boss-portrait atlas, which is higher quality
    -- than the tiny world-quest dragon marker.
    local atlas
    if type(GetBossPortraitFrameData) == "function" then
        local ok, result = pcall(GetBossPortraitFrameData, unit, classification)
        if ok then atlas = result end
    end
    if not atlas then
        atlas = classification == "rare" and "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged"
            or "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged"
    end
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        f.classIcon:SetAtlas(atlas, false)
        f.classIcon:SetTexCoord(0, 1, 0, 1)
    end
end

local function layout(f, settings)
    local width = math.max(100, math.min(400, tonumber(settings.barWidth) or 162))
    local hpHeight = math.max(12, math.min(45, tonumber(settings.hpHeight) or 23))
    local powerHeight = math.max(4, math.min(30, tonumber(settings.powerHeight) or 9))
    local side = f.portraitSide
    local portraitSize = math.max(36, math.min(90, tonumber(settings.portraitSize) or 48))
    f.petXPSettings = settings
    -- Shared centre for portrait, ring, mask and model.
    local centreX = (side == "LEFT" and -5 or 5) + (tonumber(settings.portraitX) or 0)
    local centreY = tonumber(settings.portraitY) or 0
    local rimSize = portraitSize * 62 / 48
    -- FlareUI UnitFramesRing.lua: portrait is 86% of ring diameter; backing 94%.
    local innerSize = rimSize * 0.90
    local backSize = innerSize -- matching portrait and background masks avoid a transparent gap
    f.portraitAnchor:ClearAllPoints()
    f.portraitAnchor:SetPoint(side, f, side, centreX, centreY)
    -- Extend the secure click region ONLY where the portrait protrudes.
    -- Expanding all four sides made huge invisible targeting rectangles.
    local frameHeight = math.max(48, hpHeight + powerHeight + 16)
    local halfRim = rimSize / 2
    local leftExtra = side == "LEFT" and math.max(0, halfRim - centreX) or 0
    local rightExtra = side == "RIGHT" and math.max(0, halfRim + centreX) or 0
    local topExtra = math.max(0, halfRim + centreY - frameHeight / 2)
    local bottomExtra = math.max(0, halfRim - centreY - frameHeight / 2)
    f:SetHitRectInsets(-math.ceil(leftExtra), -math.ceil(rightExtra),
        -math.ceil(topExtra), -math.ceil(bottomExtra))
    if f.petXPRing then
        -- Radial tick marks: the long axis points towards the portrait centre.
        -- Keep each tick separated to avoid opaque quads merging into a disc.
        -- Match the visible outer edge of the gold portrait ring. Keep
        -- tick depth modest so the XP track hugs the rim instead of floating.
        -- The XP marks sit INSIDE the bronze rim's annulus, not outside it.
        -- Their radial thickness scales with the portrait ring itself.
        local tickHeight = rimSize * 0.085
        -- The gold atlas rim has a narrower visible annulus at small
        -- portrait sizes. Inset the XP ticks at 36, blending back to the
        -- approved geometry at 60+. Rotation and tick width stay unchanged.
        local smallInset = 2 * math.max(0, math.min(1, (60 - portraitSize) / 24))
        local radius = rimSize * 0.445 - smallInset + (tonumber(settings.petXPRadiusOffset) or 0)
        local count = #f.petXPRing.segments
        -- Calculate the badge position from its actual anchor rather than
        -- guessing a fixed angle. Its centre is offset from the portrait's
        -- bottom edge by the atlas badge placement.
        -- Match the level badge's actual SetPoint below. Both offsets must
        -- scale with portraitSize, especially at the minimum size of 36.
        local badgeX = (side == "LEFT" and -1 or 1) * portraitSize * 17 / 48
        local badgeY = -portraitSize * (1 / 4 + 9 / 48)
        local badgeAngle = math.atan2(badgeY, badgeX)
        local gapHalf = math.rad(36)
        local sweep = 2 * math.pi - math.rad(47) -- extend endpoint another 15 degrees; start fixed
        local step = sweep / math.max(1, count - 1)
        -- Start at the upper edge of the level badge opening. Clockwise
        -- movement uses decreasing polar angles, ending below the badge.
        -- User-adjustable rotation, in degrees. Zero preserves the current
        -- orientation; this must not change tick width, sweep or XP values.
        local rotation = math.max(-180, math.min(180, tonumber(settings.petXPRotation) or 0))
        local startAngle = badgeAngle - gapHalf - math.rad(5) - math.rad(rotation)
        local tickWidth = math.min(rimSize * 0.048, radius * step * 0.78)
        -- Do not impose a pixel minimum: it made ticks disproportionately large at portrait size 36.
        for i, segment in ipairs(f.petXPRing.segments) do
            local angle = startAngle - (i - 1) * step
            local x, y = math.cos(angle) * radius, math.sin(angle) * radius
            local background = f.petXPRing.backgrounds[i]
            for _, tile in ipairs({background, segment}) do
                tile:ClearAllPoints()
                tile:SetPoint("CENTER", f.portraitAnchor, "CENTER", x, y)
                tile:SetSize(tickWidth, tickHeight)
                tile:SetRotation(angle + math.pi / 2)
            end
        end
    end
    f.rim:SetSize(rimSize, rimSize)
    -- Restore the last clean circular ring crop; asymmetric mask exposed
    -- a rectangular section of Blizzard's atlas behind the portrait.
    f.rimMask:SetSize(rimSize, rimSize)
    f.rimMask:ClearAllPoints()
    f.rimMask:SetPoint("CENTER", f.rim, "CENTER")
    f.portrait:SetSize(innerSize, innerSize)
    f.portraitBack:SetSize(backSize, backSize)
    -- The model is a genuine 3D render surface, not a masked texture.
    -- Keep its viewport within the ring while we investigate clipping.
    f.model:SetSize(innerSize * 0.72, innerSize * 0.72)
    f.portraitMask:SetSize(innerSize, innerSize)
    f.backMask:SetSize(backSize, backSize)
    for i, name in ipairs(indicatorNames) do
        local icon = f[name]
        if icon then
            local field = indicatorFields[i]
            local size = math.max(10, math.min(field == "classification" and 120 or 48, tonumber(settings.indicatorSize and settings.indicatorSize[field]) or (field == "classification" and 64 or 17)))
            local x = (icon.baseX or 0) + (tonumber(settings.indicatorX and settings.indicatorX[field]) or 0)
            local y = (icon.baseY or 0) + (tonumber(settings.indicatorY and settings.indicatorY[field]) or 0)
            -- The dragon is a portrait decoration: scale its size and default
            -- attachment point with the portrait. Manual X/Y stay pixel offsets.
            local drawSize, drawX, drawY = size, x, y
            if field == "classification" then
                local factor = portraitSize / 48
                drawSize = size * factor
                -- User X/Y adjustments must scale with the portrait too.
                -- Preserve the existing alignment at portrait size 60, then
                -- scale the entire offset about the portrait's centre.
                local referenceFactor = 60 / 48
                local relativeScale = portraitSize / 60
                drawX = ((icon.baseX or 0) * referenceFactor + (tonumber(settings.indicatorX and settings.indicatorX[field]) or 0)) * relativeScale
                drawY = ((icon.baseY or 0) * referenceFactor + (tonumber(settings.indicatorY and settings.indicatorY[field]) or 0)) * relativeScale
            end
            icon:SetSize(drawSize, drawSize)
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", f.portraitAnchor, "CENTER", drawX, drawY)
        end
    end
    f.levelDisc:SetSize(portraitSize / 2, portraitSize / 2)
    f.levelDisc:ClearAllPoints()
    f.levelDisc:SetPoint("BOTTOM", f.portrait, "BOTTOM", side == "LEFT" and -portraitSize * 17 / 48 or portraitSize * 17 / 48, -portraitSize * 9 / 48)
    f:SetSize(width + 62, math.max(48, hpHeight + powerHeight + 16))
    if f.petXP then
        local extraWidth = math.max(100, width)
        f.petXP:SetWidth(extraWidth)
        f.petCast:SetWidth(extraWidth)
        for _, spec in ipairs({{"petXP", "petXP", -5, 9}, {"petCast", "petCast", -20, 13}}) do
            local bar = f[spec[1]]
            bar:SetWidth(math.max(40, tonumber(settings[spec[2] .. "Width"]) or extraWidth))
            bar:SetHeight(math.max(4, tonumber(settings[spec[2] .. "Height"]) or spec[4]))
            bar:ClearAllPoints()
            if spec[1] == "petCast" then
                -- Freely positioned overlay relative to the health bar; no underlying bars are hidden.
                bar:SetPoint("TOPLEFT", f.health, "TOPLEFT",
                    tonumber(settings.petCastX) or 0,
                    tonumber(settings.petCastY) or 0)
            else
                bar:SetPoint("TOPLEFT", f.power, "BOTTOMLEFT",
                    tonumber(settings[spec[2] .. "X"]) or 0,
                    spec[3] + (tonumber(settings[spec[2] .. "Y"]) or 0))
            end
            local label = spec[1] == "petXP" and bar.text or bar.label
            local fontSize = tonumber(settings[spec[2] .. "FontSize"]) or 10
            if fontSize <= 0 then
                label:Hide()
            else
                label:SetFont((GameFontNormal and select(1, GameFontNormal:GetFont())) or "Fonts\\FRIZQT__.TTF",
                    math.max(7, fontSize), "OUTLINE")
                label:Show()
            end
        end
    end
    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", side == "LEFT" and 53 or 9, -8)
    f.health:SetSize(width, hpHeight)
    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -1)
    f.power:SetSize(width, powerHeight)
    local font = settings.fontFace == "arial" and "Fonts\\ARIALN.TTF" or settings.fontFace == "friz" and "Fonts\\FRIZQT__.TTF" or (GameFontNormal and select(1, GameFontNormal:GetFont())) or "Fonts\\FRIZQT__.TTF"
    local size = math.max(8, math.min(28, tonumber(settings.fontSize) or 12))
    f.level:SetFont(font, math.max(8, math.min(28, tonumber(settings.levelFontSize) or 12)), "OUTLINE")
    f.level:ClearAllPoints()
    f.level:SetPoint("CENTER", f.levelDisc, "CENTER", tonumber(settings.levelTextX) or 0, tonumber(settings.levelTextY) or 0)
    f.name:SetFont(font, tonumber(settings.nameFontSize) or size, "OUTLINE")
    f.value:SetFont(font, tonumber(settings.hpFontSize) or size, "OUTLINE")
    f.powerText:SetFont(font, tonumber(settings.powerFontSize) or size, "OUTLINE")
    f.name:SetShown(settings.showName ~= false)
    local function anchorText(text, bar, anchor, x, y)
        local point = anchor == "LEFT" and "LEFT" or anchor == "CENTER" and "CENTER" or "RIGHT"
        local inset = point == "LEFT" and 4 or point == "RIGHT" and -4 or 0
        text:ClearAllPoints()
        text:SetPoint(point, bar, point, (tonumber(x) or 0) + inset, tonumber(y) or 0)
        text:SetJustifyH(point)
    end
    anchorText(f.value, f.health, settings.hpTextAnchor, settings.hpTextX, settings.hpTextY)
    anchorText(f.powerText, f.power, settings.powerTextAnchor, settings.powerTextX, settings.powerTextY)
    local function tint(fontString, mode)
        if mode == "gold" then fontString:SetTextColor(1, 0.80, 0.38)
        elseif mode == "white" then fontString:SetTextColor(1, 1, 1)
        elseif mode == "class" then
            local _, class = UnitClass(f.unit)
            local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then fontString:SetTextColor(c.r, c.g, c.b)
            else fontString:SetTextColor(1, 0.80, 0.38) end
        else fontString:SetTextColor(1, 0.80, 0.38) end
    end
    tint(f.value, settings.hpFontColor)
    tint(f.powerText, settings.powerFontColor)
    f.barBorder:ClearAllPoints()
    f.barBorder:SetPoint("TOPLEFT", f.health, "TOPLEFT", -2, 2)
    f.barBorder:SetPoint("BOTTOMRIGHT", f.power, "BOTTOMRIGHT", 2, -2)
end
local updatePetExtras
local function update(f)
    if not f or not UnitExists(f.unit) then
        if f then f.health:SetValue(0); f.power:SetValue(0); f.name:SetText("") end
        return
    end
    local health, maximum = UnitHealth(f.unit), UnitHealthMax(f.unit)
    local power, powerMax = UnitPower(f.unit), UnitPowerMax(f.unit)
    f.health:SetMinMaxValues(0, maximum)
    f.health:SetValue(health)
    f.power:SetMinMaxValues(0, powerMax)
    f.power:SetValue(power)
    f.name:SetText(UnitName(f.unit) or "")
    -- UnitHealth can be a secret number in Forever. Do not compare or calculate it in Lua.
    local own = unitSettings(cfg() or {}, f.unit)
    setBarText(f.value, f.unit, own.hpText or "", true)
    setBarText(f.powerText, f.unit, own.powerText or "", false)
    updateExtras(f, own)
    if f.unit == "pet" then updatePetExtras(f) end
    -- FlareUI's so-called "3d" mode is a Blizzard-rendered static portrait.
    -- Keep one masked texture in both modes; optional zoom changes its crop.
    SetPortraitTexture(f.portrait, f.unit, true)
    f.portrait:SetTexCoord(own.flipPortrait and 1 or 0, own.flipPortrait and 0 or 1, 0, 1)
    f.model:Hide()
    f.portrait:Show()
    if f.level then f.level:SetText(UnitLevel(f.unit)) end
    -- Smooth health coloring through Blizzard's native color curves.
    -- UnitHealthPercent accepts a curve without exposing protected HP numbers to Lua.
    local _, class = UnitClass(f.unit)
    if f.unit == "pet" then class = nil end
    local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local cr, cg, cb = 0.40, 0.37, 0.29
    if classColor then
        cr, cg, cb = classColor.r * 0.53, classColor.g * 0.53, classColor.b * 0.53
    end
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType and CreateColor and UnitHealthPercent then
        if not f.healthCurve or f.healthCurveClass ~= class then
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Linear)
            curve:AddPoint(0, CreateColor(0.80, 0.08, 0.06))
            curve:AddPoint(0.25, CreateColor(0.80, 0.08, 0.06))
            curve:AddPoint(0.45, CreateColor(0.95, 0.36, 0.07))
            curve:AddPoint(0.65, CreateColor(0.98, 0.78, 0.12))
            curve:AddPoint(0.79, CreateColor(0.98, 0.78, 0.12))
            curve:AddPoint(0.80, CreateColor(cr, cg, cb))
            curve:AddPoint(1, CreateColor(cr, cg, cb))
            f.healthCurve = curve
            f.healthCurveClass = class
        end
        local color = UnitHealthPercent(f.unit, false, f.healthCurve)
        f.health:GetStatusBarTexture():SetVertexColor(color:GetRGB())
    elseif not (issecretvalue and (issecretvalue(health) or issecretvalue(maximum))) then
        local ratio = maximum > 0 and math.max(0, math.min(1, health / maximum)) or 0
        local points = {
            {0, 0.80, 0.08, 0.06}, {0.25, 0.80, 0.08, 0.06},
            {0.45, 0.95, 0.36, 0.07},
            {0.65, 0.98, 0.78, 0.12}, {0.79, 0.98, 0.78, 0.12},
            {0.80, cr, cg, cb}, {1, cr, cg, cb},
        }
        for i = 2, #points do
            local hi, lo = points[i], points[i-1]
            if ratio <= hi[1] then
                local t = (ratio - lo[1]) / (hi[1] - lo[1])
                f.health:SetStatusBarColor(lo[2]+(hi[2]-lo[2])*t, lo[3]+(hi[3]-lo[3])*t, lo[4]+(hi[4]-lo[4])*t)
                break
            end
        end
    else
        -- Older clients without ColorCurve cannot safely inspect secret HP.
        f.health:SetStatusBarColor(cr, cg, cb)
    end
    local kind = UnitPowerType(f.unit)
    local c = PowerBarColor and PowerBarColor[kind]
    if c then f.power:SetStatusBarColor(c.r * 0.56, c.g * 0.56, c.b * 0.56) else f.power:SetStatusBarColor(0.10, 0.30, 0.58) end
end
-- Pet-only experience and casting overlays. These are decorative and do not
-- intercept clicks on the secure pet unit button.
updatePetExtras = function(f)
    if not f or not f.petXP then return end
    local own = unitSettings(cfg() or {}, "pet")
    local xp, xpMax
    if type(GetPetExperience) == "function" then xp, xpMax = GetPetExperience() end
    local hasXP = xp ~= nil and xpMax ~= nil
    if hasXP and not (issecretvalue and (issecretvalue(xp) or issecretvalue(xpMax))) then
        hasXP = xpMax > 0
    end
    -- XP is relevant only while the pet can gain levels. Checkbox cannot override this.
    local petLevel, playerLevel = UnitLevel("pet"), UnitLevel("player")
    if not (issecretvalue and (issecretvalue(petLevel) or issecretvalue(playerLevel))) then
        hasXP = hasXP and petLevel > 0 and petLevel < playerLevel
    else
        hasXP = false
    end
    -- The circular track replaces the old straight XP bar.
    f.petXP:Hide()
    local showRing = own.showPetXP ~= false and hasXP
    if f.petXPRing then
        f.petXPRing:SetShown(showRing)
        if showRing and not (issecretvalue and (issecretvalue(xp) or issecretvalue(xpMax))) then
            local fraction = xpMax > 0 and math.max(0, math.min(1, xp / xpMax)) or 0
            local count = #f.petXPRing.segments
            for i, segment in ipairs(f.petXPRing.segments) do
                segment:SetShown(i <= math.floor(fraction * count + 0.5))
            end
        end
    end
    if hasXP then
        f.petXP:SetMinMaxValues(0, xpMax)
        f.petXP:SetValue(xp)
        f.petXP.text:SetFormattedText("%s / %s", xp, xpMax)
    end
    local name, _, texture, startTime, endTime, _, _, notInterruptible
    local channel = false
    if type(UnitCastingInfo) == "function" then
        name, _, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo("pet")
    end
    if not name and type(UnitChannelInfo) == "function" then
        name, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo("pet")
        channel = true
    end
    local casting = name ~= nil and startTime ~= nil and endTime ~= nil
    local showCast = own.showPetCast ~= false and (casting or previewPetCast)
    f.petCast:SetShown(showCast)
    if previewPetCast and not casting then
        f.petCast.startTime = nil
        f.petCast.endTime = nil
        f.petCast:SetMinMaxValues(0, 1)
        f.petCast:SetValue(0.65)
        f.petCast.label:SetText("Pet Cast Preview")
        f.petCast:SetStatusBarColor(0.72, 0.43, 0.20)
    end
    if casting then
        f.petCast.startTime = startTime
        f.petCast.endTime = endTime
        f.petCast.channel = channel
        f.petCast:SetMinMaxValues(0, 1)
        f.petCast.label:SetText(name)
        f.petCast:SetStatusBarColor(notInterruptible and 0.55 or 0.72, notInterruptible and 0.46 or 0.43, 0.20)
    end
end
local function createPetExtras(f)
    local function bar(y, color)
        local holder = CreateFrame("StatusBar", nil, f)
        holder:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        holder:SetStatusBarColor(unpack(color))
        holder:SetSize(160, 9)
        holder:SetPoint("TOPLEFT", f.power, "BOTTOMLEFT", 0, y)
        holder:EnableMouse(false)
        local bg = holder:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.07, 0.05, 0.035, 0.95)
        local border = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", 2, -2)
        border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8})
        border:SetBackdropBorderColor(0.75, 0.56, 0.29, 1)
        border:EnableMouse(false)
        return holder
    end
    local xp = bar(-5, {0.53, 0.31, 0.72})
    xp.text = xp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xp.text:SetPoint("CENTER")
    xp.text:SetTextColor(1, 0.9, 0.72)
    f.petXP = xp
    -- Draw XP marks above the bronze rim texture but below the level badge
    -- and other indicators. Otherwise the opaque rim hides almost all ticks.
    local ring = CreateFrame("Frame", nil, f.portraitAnchor:GetParent())
    ring:SetAllPoints(f.portraitAnchor)
    ring:SetFrameLevel(f.portraitAnchor:GetParent():GetFrameLevel() + 1)
    ring:EnableMouse(false)
    ring.segments = {}
    ring.backgrounds = {}
    for i = 1, 36 do
        local background = ring:CreateTexture(nil, "ARTWORK")
        background:SetColorTexture(0, 0, 0, 0)
        ring.backgrounds[i] = background
        local segment = ring:CreateTexture(nil, "OVERLAY")
        segment:SetColorTexture(0.73, 0.14, 0.80, 1)
        ring.segments[i] = segment
    end
    f.petXPRing = ring
    ring:Hide()
    -- The XP ring is decorative: do not steal secure unit clicks.
    -- Only show its tooltip when the cursor is actually on the circular track,
    -- not when hovering the health/power bars or portrait interior.
    f:HookScript("OnUpdate", function(self)
        local ring = self.petXPRing
        local overRing = false
        if ring and ring:IsShown() then
            local cx, cy = self.portraitAnchor:GetCenter()
            if cx and cy then
                local scale = self.portraitAnchor:GetEffectiveScale()
                local mx, my = GetCursorPosition()
                local dx, dy = mx / scale - cx, my / scale - cy
                local radius = (self.rim:GetWidth() or 0) * 0.445 - 2 * math.max(0, math.min(1, (60 - (tonumber(self.petXPSettings and self.petXPSettings.portraitSize) or 60)) / 24)) + (tonumber(self.petXPSettings and self.petXPSettings.petXPRadiusOffset) or 0)
                local distance = math.sqrt(dx * dx + dy * dy)
                overRing = distance >= radius - 7 and distance <= radius + 7
            end
        end
        if overRing == self.xpTooltipActive then return end
        self.xpTooltipActive = overRing
        if not overRing then
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            return
        end
        local current, maximum = GetPetExperience()
        if type(current) ~= "number" or type(maximum) ~= "number"
            or (issecretvalue and (issecretvalue(current) or issecretvalue(maximum)))
            or maximum <= 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine("Pet Experience", 1, 0.82, 0.25)
        GameTooltip:AddDoubleLine("XP", string.format("%d / %d", current, maximum), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Remaining", tostring(math.max(0, maximum - current)), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Progress", string.format("%.1f%%", current / maximum * 100), 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function(self)
        self.xpTooltipActive = false
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    local cast = bar(-20, {0.72, 0.43, 0.20})
    cast:SetHeight(13)
    cast.label = cast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cast.label:SetPoint("CENTER")
    cast.label:SetTextColor(1, 0.9, 0.72)
    cast:SetScript("OnUpdate", function(self)
        if not self:IsShown() or not self.startTime or not self.endTime then return end
        local duration = self.endTime - self.startTime
        if duration <= 0 then return end
        local now = GetTime() * 1000
        local progress = (now - self.startTime) / duration
        if self.channel then progress = 1 - progress end
        self:SetValue(math.max(0, math.min(1, progress)))
    end)
    f.petCast = cast
    -- Draw above the shared bar border while remaining below the portrait.
    cast:SetFrameLevel(f.barBorder:GetFrameLevel() + 1)
    xp:Hide()
    cast:Hide()
end
local function create(key, spec)
    if frames[key] or (InCombatLockdown and InCombatLockdown()) then return end
    local f = CreateFrame("Button", "BaziUI_Unit_" .. key, UIParent, "SecureUnitButtonTemplate")
    f:SetAttribute("unit", spec.unit)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:SetSize(224, 48)
    applyPosition(f, cfg() or {}, key)
    f:SetFrameStrata("MEDIUM")
    f.unit = spec.unit
    f.portraitSide = (key == "player" or key == "pet") and "LEFT" or "RIGHT"
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", (key == "player" or key == "pet") and 49 or 4, -4)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", (key == "player" or key == "pet") and -4 or -49, 4)
    -- Keep the square backing fully transparent: its corners otherwise show outside the rim.
    bg:SetColorTexture(0.10, 0.065, 0.035, 0)
    -- FlareUI-style composition: compact bronze plate, circular portrait on the outer side.
    -- Uses Blizzard's own ring atlas and portrait mask, not FlareUI's excluded artwork.
    local side = (key == "player" or key == "pet") and "LEFT" or "RIGHT"
    -- Use the same Blizzard tooltip border texture, but at a slimmer edge size.
    -- Keep the existing bar geometry and portrait layering unchanged.
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetAllPoints(bg)
    f.barBorder = border
    border:SetFrameLevel(f:GetFrameLevel() + 5)
    border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12})
    border:SetBackdropBorderColor(0.90, 0.72, 0.42, 1)
    local portraitLayer = CreateFrame("Frame", nil, f)
    portraitLayer:SetAllPoints(f)
    portraitLayer:SetFrameLevel(f:GetFrameLevel() + 8)
    portraitLayer:EnableMouse(false)
    -- Dark backing plate: remains visible behind the model and inside the bronze ring.
    local portraitAnchor = CreateFrame("Frame", nil, portraitLayer)
    portraitAnchor:SetSize(1, 1)
    portraitAnchor:EnableMouse(false)
    f.portraitAnchor = portraitAnchor
    local portraitBack = portraitLayer:CreateTexture(nil, "BACKGROUND")
    portraitBack:SetSize(55, 55)
    portraitBack:SetPoint("CENTER", portraitAnchor, "CENTER")
    -- Original dark backing from before the purple/class-color experiments.
    portraitBack:SetColorTexture(0.075, 0.055, 0.035, 1)
    f.portraitBack = portraitBack
    local backMask = portraitLayer:CreateMaskTexture()
    backMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    backMask:SetAllPoints(portraitBack)
    portraitBack:AddMaskTexture(backMask)
    f.backMask = backMask
    local portrait = portraitLayer:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(48,48)
    portrait:SetPoint("CENTER", portraitAnchor, "CENTER", -1, 0)
    local mask = portraitLayer:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    f.portraitMask = mask
    portraitBack:ClearAllPoints()
    portraitBack:SetPoint("CENTER", portrait, "CENTER")
    f.portrait = portrait
    -- 3D portrait trial; retain the masked 2D texture as fallback.
    local model = CreateFrame("PlayerModel", nil, portraitLayer)
    -- Keep the model disabled: PlayerModel can render beyond its viewport on Forever.
    model:SetSize(48, 48)
    model:SetPoint("CENTER", portraitAnchor, "CENTER", -1, 0)
    model:SetFrameLevel(portraitLayer:GetFrameLevel() + 1)
    model:EnableMouse(false)
    model:Hide()
    f.model = model
    local rim = portraitLayer:CreateTexture(nil, "OVERLAY")
    rim:SetSize(62,62)
    f.rim = rim
    rim:SetPoint("CENTER", portraitAnchor, "CENTER")
    rim:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
    rim:SetTexCoord(252.78/384, 375/384, 1.67/134, 123.89/134)
    local rimMask = portraitLayer:CreateMaskTexture()
    rimMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    rimMask:SetSize(62, 62)
    rimMask:SetPoint("CENTER", rim, "CENTER")
    rim:AddMaskTexture(rimMask)
    f.rimMask = rimMask
    -- Do not mirror cropped atlas UVs; mirroring exposes the straight crop edge.
    local badgeLayer = CreateFrame("Frame", nil, portraitLayer)
    badgeLayer:SetAllPoints(portraitLayer)
    badgeLayer:SetFrameLevel(portraitLayer:GetFrameLevel() + 2)
    badgeLayer:EnableMouse(false)
    local disc = badgeLayer:CreateTexture(nil, "OVERLAY")
    disc:SetSize(24,24)
    f.levelDisc = disc
    disc:SetPoint("BOTTOM", portrait, "BOTTOM", side == "LEFT" and -17 or 17, -9)
    disc:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    local level = badgeLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    level:SetPoint("CENTER", disc, "CENTER", 0, 0)
    f.level = level
    local hp = CreateFrame("StatusBar", nil, f)
    hp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    -- Inset the actual bar fills inside the thin tooltip-style border.
    -- Moving the border alone leaves square statusbar corners exposed.
    hp:SetPoint("TOPLEFT", f, "TOPLEFT", side == "LEFT" and 53 or 9, -8)
    hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", side == "LEFT" and -9 or -53, -8)
    hp:SetHeight(23)
    f.health = hp
    local hpBackground = hp:CreateTexture(nil, "BACKGROUND")
    hpBackground:SetAllPoints(hp)
    hpBackground:SetColorTexture(0.085, 0.065, 0.045, 1)
    f.hpBackground = hpBackground
    local pp = CreateFrame("StatusBar", nil, f)
    pp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
    pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
    pp:SetHeight(9)
    f.power = pp
    local powerBackground = pp:CreateTexture(nil, "BACKGROUND")
    powerBackground:SetAllPoints(pp)
    powerBackground:SetColorTexture(0.065, 0.055, 0.075, 1)
    f.powerBackground = powerBackground
    local divider = border:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(0.22, 0.16, 0.10, 1)
    divider:SetHeight(2)
    divider:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, -1)
    divider:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", 0, -1)
    local name = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", hp, "LEFT", 4, 0)
    name:SetJustifyH("LEFT")
    f.name = name
    local value = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value:SetPoint("RIGHT", hp, "RIGHT", -4, 0)
    f.value = value
    local powerText = pp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    powerText:SetPoint("RIGHT", pp, "RIGHT", -4, 0)
    f.powerText = powerText
    local function icon(x, y, texture)
        local t = portraitLayer:CreateTexture(nil, "OVERLAY")
        t:SetSize(17, 17)
        t:SetPoint("CENTER", portraitAnchor, "CENTER", x, y)
        t:SetTexture(texture)
        t.baseX, t.baseY = x, y
        return t
    end
    f.pvpIcon = icon(25, 25, "Interface\\TargetingFrame\\UI-PVP-FFA")
    f.leaderIcon = icon(-25, 25, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    f.raidIcon = icon(0, 33, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.roleIcon = icon(26, -23, "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    -- Native Blizzard boss portrait decoration, selected per classification.
    f.classIcon = icon(-26, -23, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.happinessIcon = icon(24, -3, "Interface\\PetPaperDollFrame\\UI-PetHappiness")
    -- Elite/rare decoration is above the portrait rim, but must stay below
    -- the level badge and every other indicator.
    local dragonLayer = CreateFrame("Frame", nil, portraitLayer)
    dragonLayer:SetAllPoints(portraitLayer)
    dragonLayer:SetFrameLevel(portraitLayer:GetFrameLevel() + 1)
    dragonLayer:EnableMouse(false)
    f.classIcon:SetParent(dragonLayer)
    local indicatorLayer = CreateFrame("Frame", nil, portraitLayer)
    indicatorLayer:SetAllPoints(portraitLayer)
    indicatorLayer:SetFrameLevel(badgeLayer:GetFrameLevel() + 2)
    indicatorLayer:EnableMouse(false)
    for _, iconName in ipairs(indicatorNames) do
        if iconName ~= "classIcon" then
            f[iconName]:SetParent(indicatorLayer)
        end
    end
    f:RegisterEvent("UNIT_FLAGS")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("RAID_TARGET_UPDATE")
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_MAXHEALTH")
    f:RegisterEvent("UNIT_POWER_UPDATE")
    f:RegisterEvent("UNIT_MAXPOWER")
    f:RegisterEvent("UNIT_DISPLAYPOWER")
    f:RegisterEvent("UNIT_NAME_UPDATE")
    f:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    f:RegisterEvent("UNIT_PET")
    f:RegisterEvent("UNIT_HAPPINESS")
    if key == "pet" then
        for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_PET_EXPERIENCE", "PET_XP_UPDATE"}) do
            pcall(f.RegisterEvent, f, event)
        end
    end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, event, unit)
        if not unit or unit == self.unit or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" or event == "GROUP_ROSTER_UPDATE" or event == "RAID_TARGET_UPDATE" then
            update(self)
        end
    end)
    if key == "pet" then
        createPetExtras(f)
        updatePetExtras(f)
    end
    frames[key] = f
    local mover = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    mover:SetSize(224, 48)
    mover:SetFrameStrata("DIALOG")
    mover:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12})
    mover:SetBackdropColor(0.22, 0.10, 0.32, 0.65)
    mover:SetBackdropBorderColor(0.85, 0.65, 0.35, 1)
    local title = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText("Move " .. key)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:StartMoving()
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if x and y and cx and cy then
            M:SetPosition(key, math.floor(x - cx + 0.5), math.floor(y - cy + 0.5))
        end
    end)
    mover:Hide()
    movers[key] = mover
    createLiveAuras(f)
    layout(f, unitSettings(cfg() or {}, key))
    update(f)
end
-- Reversible suppression of Blizzard frames whenever their Bazi replacements are enabled.
-- Do not unregister events or reparent protected frames.
local originals = {
    player = "PlayerFrame",
    target = "TargetFrame",
    focus = "FocusFrame",
    pet = "PetFrame",
}
local originalState = {}
local function syncOriginal(key, settings)
    local name = originals[key]
    local frame = name and _G[name]
    if not frame or (InCombatLockdown and InCombatLockdown()) then return end
    local state = originalState[key]
    local hide = settings.enabled ~= false and settings[key] == true
    if hide then
        if not state then
            state = {alpha = frame:GetAlpha(), mouse = frame:IsMouseEnabled()}
            originalState[key] = state
        end
        frame:SetAlpha(0)
        frame:EnableMouse(false)
    elseif state then
        frame:SetAlpha(state.alpha)
        frame:EnableMouse(state.mouse)
        originalState[key] = nil
    end
end
function M:Refresh()
    local settings = cfg()
    if not settings then return end
    for key, spec in pairs(units) do
        if settings.enabled ~= false and settings[key] then create(key, spec) end
        syncOriginal(key, settings)
        local f = frames[key]
        if f and not (InCombatLockdown and InCombatLockdown()) then
            layout(f, unitSettings(settings, key))
            updateAuraPreview(f)
            updateLiveAuras(f)
            update(f)
            applyPosition(f, settings, key)
            if settings.enabled ~= false and settings[key] then
                if key == "focus" or key == "target" or key == "pet" then
                    if not f.visibilityRegistered and RegisterStateDriver then
                        RegisterStateDriver(f, "visibility", "[@" .. key .. ",exists] show; hide")
                        f.visibilityRegistered = true
                    end
                    if not f.visibilityRegistered then f:SetShown(UnitExists(key) == true) end
                else
                    f:Show()
                end
            else
                if f.visibilityRegistered and UnregisterStateDriver then
                    UnregisterStateDriver(f, "visibility")
                    f.visibilityRegistered = false
                end
                f:Hide()
            end
            f:SetScale(1.15 * (settings.scale or 1))
        end
        local mover = movers[key]
        if mover then
            local own = position(settings, key)
            mover:ClearAllPoints()
            mover:SetPoint("CENTER", UIParent, "CENTER", own.x, own.y)
            if f then mover:SetSize(f:GetWidth() * f:GetEffectiveScale() / UIParent:GetEffectiveScale(), f:GetHeight() * f:GetEffectiveScale() / UIParent:GetEffectiveScale()) end
            mover:SetShown(moving and settings.enabled ~= false and settings[key] == true)
        end
    end
end
function M:Initialize()
    if self.initialized then return end
    self.initialized = true
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(eventFrame, event)
        if event == "PLAYER_REGEN_ENABLED" then M:Refresh() else M:Refresh() end
    end)
    self:Refresh()
end
