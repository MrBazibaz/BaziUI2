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
local layoutKeys = {"barWidth", "hpHeight", "powerHeight", "portraitSize", "portraitX", "portraitY", "portrait3D"}
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
    for _, name in ipairs(layoutKeys) do to[name] = from[name] end
    self:Refresh()
    return true
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
    local innerSize = portraitSize * 0.90
    f.portraitAnchor:ClearAllPoints()
    f.portraitAnchor:SetPoint(side, f, side, centreX, centreY)
    f.rim:SetSize(rimSize, rimSize)
    f.rimMask:SetSize(rimSize, rimSize)
    f.portrait:SetSize(innerSize, innerSize)
    f.portraitBack:SetSize(innerSize, innerSize)
    f.model:SetSize(innerSize, innerSize)
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
    f.value:SetText("")
    SetPortraitTexture(f.portrait, f.unit)
    local settings = cfg()
    local own = settings and unitSettings(settings, f.unit)
    if own and own.portrait3D then
        local ok = pcall(function()
            f.model:SetUnit(f.unit)
            f.model:SetPortraitZoom(1)
            f.model:SetCamDistanceScale(1)
        end)
        if ok then
            f.model:Show()
            f.portrait:Hide()
        else
            f.model:Hide()
            f.portrait:Show()
        end
    else
        f.model:Hide()
        f.portrait:Show()
    end
    if f.level then f.level:SetText(UnitLevel(f.unit)) end
    -- Pets have no player class colour.
    local _, class = UnitClass(f.unit)
    if f.unit == "pet" then class = nil end
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        f.health:SetStatusBarColor(color.r * 0.53, color.g * 0.53, color.b * 0.53)
    else
        f.health:SetStatusBarColor(0.40, 0.37, 0.29)
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
    portraitBack:SetColorTexture(0.075, 0.055, 0.035, 1)
    f.portraitBack = portraitBack
    local backMask = portraitLayer:CreateMaskTexture()
    backMask:SetTexture("Interface\\\\CHARACTERFRAME\\\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    backMask:SetAllPoints(portraitBack)
    portraitBack:AddMaskTexture(backMask)
    local portrait = portraitLayer:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(48,48)
    portrait:SetPoint("CENTER", portraitAnchor, "CENTER")
    local mask = portraitLayer:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    portraitBack:ClearAllPoints()
    portraitBack:SetPoint("CENTER", portrait, "CENTER")
    f.portrait = portrait
    -- 3D portrait trial; retain the masked 2D texture as fallback.
    local model = CreateFrame("PlayerModel", nil, portraitLayer)
    -- Keep the model disabled: PlayerModel can render beyond its viewport on Forever.
    model:SetSize(48, 48)
    model:SetPoint("CENTER", portraitAnchor, "CENTER")
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
    local pp = CreateFrame("StatusBar", nil, f)
    pp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
    pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
    pp:SetHeight(9)
    f.power = pp
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
        if not unit or unit == self.unit or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
            update(self)
        end
    end)
    frames[key] = f
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
