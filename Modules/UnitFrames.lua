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
    if f.model then
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
    f:SetPoint("CENTER", UIParent, "CENTER", spec.x, spec.y)
    f:SetFrameStrata("MEDIUM")
    f.unit = spec.unit
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", (key == "player" or key == "pet") and 49 or 4, -4)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", (key == "player" or key == "pet") and -4 or -49, 4)
    bg:SetColorTexture(0.10, 0.065, 0.035, 0.95)
    -- FlareUI-style composition: compact bronze plate, circular portrait on the outer side.
    -- Uses Blizzard's own ring atlas and portrait mask, not FlareUI's excluded artwork.
    local side = (key == "player" or key == "pet") and "LEFT" or "RIGHT"
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetAllPoints(bg)
    border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=10})
    border:SetBackdropBorderColor(0.38, 0.30, 0.19, 1)
    local portraitLayer = CreateFrame("Frame", nil, f)
    portraitLayer:SetAllPoints(f)
    portraitLayer:SetFrameLevel(f:GetFrameLevel() + 8)
    local portrait = portraitLayer:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(48,48)
    portrait:SetPoint(side, f, side, side == "LEFT" and -5 or 5, 0)
    local mask = portraitLayer:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    f.portrait = portrait
    -- 3D portrait trial; retain the masked 2D texture as fallback.
    local model = CreateFrame("PlayerModel", nil, portraitLayer)
    model:SetSize(43, 43)
    model:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    model:SetFrameLevel(portraitLayer:GetFrameLevel() + 1)
    model:Hide()
    f.model = model
    local rim = portraitLayer:CreateTexture(nil, "OVERLAY")
    rim:SetSize(62,62)
    rim:SetPoint("CENTER", portrait, "CENTER")
    rim:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
    rim:SetTexCoord(252.78/384, 375/384, 1.67/134, 123.89/134)
    local rimMask = portraitLayer:CreateMaskTexture()
    rimMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    rimMask:SetSize(66, 66)
    rimMask:SetPoint("CENTER", rim, "CENTER", side == "LEFT" and -2 or 2, 0)
    rim:AddMaskTexture(rimMask)
    if side == "LEFT" then rim:SetTexCoord(375/384, 252.78/384, 1.67/134, 123.89/134) end
    local badgeLayer = CreateFrame("Frame", nil, portraitLayer)
    badgeLayer:SetAllPoints(portraitLayer)
    badgeLayer:SetFrameLevel(portraitLayer:GetFrameLevel() + 2)
    local disc = badgeLayer:CreateTexture(nil, "OVERLAY")
    disc:SetSize(24,24)
    disc:SetPoint("BOTTOM", portrait, "BOTTOM", side == "LEFT" and -17 or 17, -9)
    disc:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    local level = badgeLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    level:SetPoint("CENTER", disc, "CENTER", 0, 0)
    f.level = level
    local hp = CreateFrame("StatusBar", nil, f)
    hp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    hp:SetPoint("TOPLEFT", f, "TOPLEFT", side == "LEFT" and 49 or 6, -5)
    hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", side == "LEFT" and -6 or -49, -5)
    hp:SetHeight(26)
    f.health = hp
    local pp = CreateFrame("StatusBar", nil, f)
    pp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
    pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
    pp:SetHeight(11)
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
        if settings[key] then create(key, spec) end
        syncOriginal(key, settings)
        local f = frames[key]
        if f and not (InCombatLockdown and InCombatLockdown()) then
            if settings[key] then
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
    end
end
function M:Initialize()
    if self.initialized then return end
    self.initialized = true
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function() M:Refresh() end)
    self:Refresh()
end
