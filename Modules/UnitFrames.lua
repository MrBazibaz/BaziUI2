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
    local _, class = UnitClass(f.unit)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then f.health:SetStatusBarColor(color.r, color.g, color.b) else f.health:SetStatusBarColor(0.28, 0.68, 0.30) end
    local kind = UnitPowerType(f.unit)
    local c = PowerBarColor and PowerBarColor[kind]
    if c then f.power:SetStatusBarColor(c.r, c.g, c.b) else f.power:SetStatusBarColor(0.1, 0.45, 0.9) end
end
local function create(key, spec)
    if frames[key] or (InCombatLockdown and InCombatLockdown()) then return end
    local f = CreateFrame("Button", "BaziUI_Unit_" .. key, UIParent, "SecureUnitButtonTemplate")
    f:SetAttribute("unit", spec.unit)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:SetSize(208, 48)
    f:SetPoint("CENTER", UIParent, "CENTER", spec.x, spec.y)
    f:SetFrameStrata("MEDIUM")
    f.unit = spec.unit
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.065, 0.035, 0.95)
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14})
    border:SetBackdropBorderColor(0.8, 0.62, 0.33, 1)
    local portrait = f:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(44,44)
    portrait:SetPoint("LEFT", f, "LEFT", 2, 0)
    f.portrait = portrait
    local hp = CreateFrame("StatusBar", nil, f)
    hp:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    hp:SetPoint("TOPLEFT", f, "TOPLEFT", 49, -8)
    hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -7, -8)
    hp:SetHeight(21)
    f.health = hp
    local pp = CreateFrame("StatusBar", nil, f)
    pp:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -2)
    pp:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -2)
    pp:SetHeight(9)
    f.power = pp
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
function M:Refresh()
    local settings = cfg()
    if not settings then return end
    for key, spec in pairs(units) do
        if settings[key] then create(key, spec) end
        local f = frames[key]
        if f and not (InCombatLockdown and InCombatLockdown()) then
            f:SetShown(settings[key] == true)
            if settings.scale then f:SetScale(settings.scale) end
        end
    end
end
function M:Initialize()
    if self.initialized then return end
    self.initialized = true
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() M:Refresh() end)
    self:Refresh()
end
