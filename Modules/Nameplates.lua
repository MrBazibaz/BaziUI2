-- Friendly player nameplate icons. Based on MiniMarkers' nameplate event,
-- unit classification and role/class icon selection patterns.
-- Runtime is isolated; no Blizzard nameplate frame or UnitFrames code is replaced.
local addon = BaziUI
addon.Nameplates = addon.Nameplates or {}
local M = addon.Nameplates
local active = {}
local eventFrame = CreateFrame("Frame")

local function Config()
    local profile = addon.db and addon.db.profile
    return profile and profile.nameplates
end

local function InGroup(unit)
    return UnitIsUnit(unit, "player") or UnitInParty(unit) or UnitInRaid(unit)
end

local function IsRaid()
    return IsInRaid and IsInRaid()
end

local function Role(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if role and role ~= "NONE" then return role end
    -- Never invent a role for strangers. MiniMarkers uses its Inspector
    -- for this; we deliberately avoid guessing until that is integrated.
    return nil
end

local function Friendly(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    if InGroup(unit) then return true end
    return UnitIsFriend("player", unit) and not UnitIsEnemy("player", unit)
end

local function RoleTexture(icon, role)
    -- Same Blizzard role atlas and UVs as Bazi UI's GroupFrames.
    local coords = {
        TANK = {0, 0.25, 0.25, 0.5},
        HEALER = {0.25, 0.5, 0, 0.25},
        DAMAGER = {0.25, 0.5, 0.25, 0.5},
    }
    local uv = coords[role]
    if not uv then return false end
    icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    icon:SetTexCoord(unpack(uv))
    return true
end

local function ClassTexture(icon, unit)
    local _, class = UnitClass(unit)
    if not class then return false end
    local atlas = "classicon-" .. class:lower()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) and icon.SetAtlas then
        icon:SetAtlas(atlas)
        return true
    end
    -- Classic-compatible fallback for clients without class atlases.
    local uv = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not uv then return false end
    icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    icon:SetTexCoord(unpack(uv))
    return true
end

local function HidePlate(plate)
    local marker = active[plate]
    if marker then marker:Hide() end
end

local function UpdatePlate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local cfg = Config()
    if not cfg or not cfg.enabled or cfg.friendlyIcon == "off" or not Friendly(unit)
        or (cfg.friendlyScope == "group" and not InGroup(unit)) then
        HidePlate(plate)
        return
    end

    local iconMode = cfg.friendlyIcon or "role"
    local role
    if IsRaid() then
        -- Raid always uses roles, never class or DPS icons.
        iconMode = "role"
        role = Role(unit)
        if role ~= "TANK" and role ~= "HEALER" then
            HidePlate(plate)
            return
        end
    end
    local marker = active[plate]
    if not marker then
        marker = CreateFrame("Frame", nil, plate)
        marker:SetFrameLevel(plate:GetFrameLevel() + 10)
        marker.icon = marker:CreateTexture(nil, "OVERLAY")
        marker.icon:SetAllPoints()
        active[plate] = marker
    end
    local valid = false
    if iconMode == "class" then
        valid = ClassTexture(marker.icon, unit)
    elseif iconMode == "role" then
        role = role or Role(unit)
        valid = RoleTexture(marker.icon, role)
    end
    if not valid then marker:Hide(); return end
    local anchor = plate.UnitFrame and plate.UnitFrame:IsVisible() and plate.UnitFrame or plate
    marker:ClearAllPoints()
    marker:SetPoint("BOTTOM", anchor, "TOP", cfg.friendlyX or 0, cfg.friendlyY or 20)
    marker:SetSize(cfg.friendlySize or 28, cfg.friendlySize or 28)
    marker:Show()
end

function M:Apply()
    local cfg = Config()
    if not cfg or not cfg.enabled then
        for plate in pairs(active) do HidePlate(plate) end
        return
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate.namePlateUnitToken
            if unit then UpdatePlate(unit) else HidePlate(plate) end
        end
    end
end

function M:Initialize()
    if self.initialized then return end
    self.initialized = true
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            UpdatePlate(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
                local plate = C_NamePlate.GetNamePlateForUnit(unit)
                if plate then HidePlate(plate) end
            end
        else
            M:Apply()
        end
    end)
    self:Apply()
end
