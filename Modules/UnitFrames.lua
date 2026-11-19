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
local indicatorNames = {"pvpIcon", "leaderIcon", "raidIcon", "roleIcon", "classIcon"}
local indicatorFields = {"pvp", "leader", "raid", "role", "classification"}
function M:SetIndicatorPreview(enabled)
    previewIndicators = enabled == true
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
local layoutKeys = {"indicatorSize", "indicatorX", "indicatorY","barWidth", "hpHeight", "powerHeight", "portraitSize", "portraitX", "portraitY", "flipPortrait", "showPvP", "showLeader", "showRaidMarker", "showRole", "showClassification", "hpText", "powerText", "fontSize", "nameFontSize", "hpFontSize", "powerFontSize", "fontFace", "showName", "hpTextX", "hpTextY", "powerTextX", "powerTextY", "hpFontColor", "powerFontColor", "hpTextAnchor", "powerTextAnchor", "levelFontSize", "levelTextX", "levelTextY"}
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
    local classification = UnitClassification and readable(UnitClassification(unit))
    f.classIcon:SetShown(own.showClassification ~= false and
        (previewIndicators or classification == "elite" or classification == "rare" or classification == "rareelite" or classification == "worldboss"))
end

local function layout(f, settings)
    local width = math.max(100, math.min(400, tonumber(settings.barWidth) or 162))
    local hpHeight = math.max(12, math.min(45, tonumber(settings.hpHeight) or 23))
    local powerHeight = math.max(4, math.min(30, tonumber(settings.powerHeight) or 9))
    local side = f.portraitSide
    local portraitSize = math.max(36, math.min(90, tonumber(settings.portraitSize) or 48))
    -- Shared centre for portrait, ring, mask and model.
    local centreX = (side == "LEFT" and -5 or 5) + (tonumber(settings.portraitX) or 0)
    local centreY = tonumber(settings.portraitY) or 0
    local rimSize = portraitSize * 62 / 48
    -- FlareUI UnitFramesRing.lua: portrait is 86% of ring diameter; backing 94%.
    local innerSize = rimSize * 0.86
    local backSize = rimSize * 0.94
    f.portraitAnchor:ClearAllPoints()
    f.portraitAnchor:SetPoint(side, f, side, centreX, centreY)
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
            local size = math.max(10, math.min(48, tonumber(settings.indicatorSize and settings.indicatorSize[field]) or 17))
            local x = (icon.baseX or 0) + (tonumber(settings.indicatorX and settings.indicatorX[field]) or 0)
            local y = (icon.baseY or 0) + (tonumber(settings.indicatorY and settings.indicatorY[field]) or 0)
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", f.portraitAnchor, "CENTER", x, y)
        end
    end
    f.levelDisc:SetSize(portraitSize / 2, portraitSize / 2)
    f.levelDisc:ClearAllPoints()
    f.levelDisc:SetPoint("BOTTOM", f.portrait, "BOTTOM", side == "LEFT" and -portraitSize * 17 / 48 or portraitSize * 17 / 48, -portraitSize * 9 / 48)
    f:SetSize(width + 62, math.max(48, hpHeight + powerHeight + 16))
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
            curve:AddPoint(0.30, CreateColor(0.95, 0.36, 0.07))
            curve:AddPoint(0.55, CreateColor(0.98, 0.78, 0.12))
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
            {0, 0.80, 0.08, 0.06}, {0.30, 0.95, 0.36, 0.07},
            {0.55, 0.98, 0.78, 0.12}, {0.79, 0.98, 0.78, 0.12},
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
    -- Dark backing plate: remains visible behind the model and inside the bronze ring.
    local portraitAnchor = CreateFrame("Frame", nil, portraitLayer)
    portraitAnchor:SetSize(1, 1)
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
    portrait:SetPoint("CENTER", portraitAnchor, "CENTER", -1, 2)
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
    model:SetPoint("CENTER", portraitAnchor, "CENTER", -1, 2)
    model:SetFrameLevel(portraitLayer:GetFrameLevel() + 1)
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
    -- Use Blizzard's original elite dragon artwork instead of the skull marker.
    f.classIcon = icon(-26, -23, "Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
    -- Indicators are layered above the portrait rim and badge.
    local indicatorLayer = CreateFrame("Frame", nil, portraitLayer)
    indicatorLayer:SetAllPoints(portraitLayer)
    indicatorLayer:SetFrameLevel(badgeLayer:GetFrameLevel() + 2)
    for _, iconName in ipairs(indicatorNames) do
        f[iconName]:SetParent(indicatorLayer)
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
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, event, unit)
        if not unit or unit == self.unit or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" or event == "GROUP_ROSTER_UPDATE" or event == "RAID_TARGET_UPDATE" then
            update(self)
        end
    end)
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
    layout(f, unitSettings(cfg() or {}, key))
    update(f)
end
-- Reversible, opt-in suppression of Blizzard's original frames.
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
    local hide = settings.hideBlizzard == true and settings[key] == true
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
        syncOriginal(key, settings.enabled == false and {hideBlizzard=false} or settings)
        local f = frames[key]
        if f and not (InCombatLockdown and InCombatLockdown()) then
            layout(f, unitSettings(settings, key))
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
