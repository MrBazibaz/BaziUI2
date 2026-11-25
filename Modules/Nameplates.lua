-- Friendly player nameplate icons. Based on MiniMarkers' nameplate event,
-- unit classification and role/class icon selection patterns.
-- Runtime is isolated; no Blizzard nameplate frame or UnitFrames code is replaced.
local addon = BaziUI
addon.Nameplates = addon.Nameplates or {}
local M = addon.Nameplates
local Enemy = addon.EnemyNameplates
local active = {}
local plateUnits, unitPlates = {}, {} -- Track both sides because removed tokens may no longer resolve.
-- Save original text presentation so disabling Bazi UI restores Blizzard styling.
local styledNames = {}
local hiddenUnitFrames = {} -- reversible alpha override for the nameplate test
local nativeNameTest = false -- session-only experiment; never saved to profile

-- World names shrink with distance. Prefer real coordinates if exposed by
-- this client; do not guess a precise distance from nameplate screen position.
local function UnitDistance(unit)
    -- Some Forever builds return zero for every nameplate unit. Treat that
    -- as unavailable unless the unit really is our own player.
    if type(UnitDistanceSquared) == "function" then
        local ok, squared = pcall(UnitDistanceSquared, unit)
        if ok and type(squared) == "number" and squared > 0 then
            return math.sqrt(squared)
        end
    end
    if type(UnitPosition) == "function" then
        local okA, x, y, _, map = pcall(UnitPosition, unit)
        local okB, px, py, _, pmap = pcall(UnitPosition, "player")
        if okA and okB and type(x) == "number" and type(y) == "number"
            and type(px) == "number" and type(py) == "number"
            and map and map == pmap then
            local dx, dy = x - px, y - py
            local squared = dx * dx + dy * dy
            if squared > 0 then return math.sqrt(squared) end
        end
    end
    return nil
end

-- Text is deliberately fixed-size; its anchor is independent of the icon.
local function PositionFriendlyText(plate, marker, cfg)
    marker.textAnchor:ClearAllPoints()
    marker.textAnchor:SetPoint("TOP", plate, "TOP",
        cfg.friendlyTextX or 0, 18 + (cfg.friendlyTextY or 0))
end

local function RestoreName(plate)
    local saved = styledNames[plate]
    if not saved then return end
    for fontString, original in pairs(saved) do
        if fontString and fontString.SetFont then
            if original.font then
                fontString:SetFont(original.font, original.size, original.flags)
            end
            fontString:SetTextColor(unpack(original.color))
            fontString:SetAlpha(original.alpha)
        end
    end
    styledNames[plate] = nil
end

local function StyleName(plate, unit)
    -- Nameplates on this client may nest the name FontString several frames
    -- below UnitFrame. Inspect descendants, not just direct regions.
    local unitName = UnitName(unit)
    if not unitName or not plate.UnitFrame then return end
    local seen, candidates = {}, {}
    local function Scan(frame, depth)
        if not frame or depth > 6 or seen[frame] then return end
        seen[frame] = true
        if frame.GetRegions then
            for _, region in ipairs({frame:GetRegions()}) do
                if region.IsObjectType and region:IsObjectType("FontString") then
                    candidates[#candidates + 1] = region
                end
            end
        end
        if frame.GetChildren then
            for _, child in ipairs({frame:GetChildren()}) do
                Scan(child, depth + 1)
            end
        end
    end
    Scan(plate.UnitFrame, 0)
    local saved = styledNames[plate] or {}
    for _, label in ipairs(candidates) do
        local value = label.GetText and label:GetText()
        -- A nameplate may append a realm; do not touch unrelated text.
        if type(value) == "string" and
            (value == unitName or value:match("^" .. unitName:gsub("(%W)", "%%%1") .. "%-")) then
            if not saved[label] then
                local font, size, flags = label:GetFont()
                saved[label] = {
                    font = font, size = size, flags = flags,
                    color = {label:GetTextColor()}, alpha = label:GetAlpha(),
                }
            end
            local font = saved[label].font
            if font then label:SetFont(font, 10, "") end
            label:SetTextColor(0.64, 0.64, 0.68, 0.88)
            label:SetAlpha(0.88)
        end
    end
    if next(saved) then styledNames[plate] = saved end
end
local eventFrame = CreateFrame("Frame")
-- An attack order can flag player combat before either unit actually fights.
local petCombatEngaged = false
-- UNIT_COMBAT reports actual combat interactions without accessing protected
-- combat-log payloads. It may not report an outgoing pet hit immediately.
local function PetUnitCombatInteraction(unit, action)
    if unit ~= "player" and unit ~= "pet" then return end
    if action == "WOUND" or action == "MISS" or action == "DODGE"
        or action == "PARRY" or action == "BLOCK" or action == "RESIST"
        or action == "IMMUNE" then
        petCombatEngaged = true
    end
end

local function Config()
    local profile = addon.db and addon.db.profile
    return profile and profile.nameplates
end

local function readable(value)
    return (not issecretvalue or not issecretvalue(value))
        and (not canaccessvalue or canaccessvalue(value))
end

local function groupFlag(value)
    return readable(value) and value
end

local function InGroup(unit)
    return groupFlag(UnitIsUnit(unit, "player")) or groupFlag(UnitInParty(unit)) or groupFlag(UnitInRaid(unit))
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
    if not groupFlag(UnitExists(unit)) or not groupFlag(UnitIsPlayer(unit)) then return false end
    if InGroup(unit) then return true end
    local enemy = UnitIsEnemy("player", unit)
    return groupFlag(UnitIsFriend("player", unit)) and readable(enemy) and not enemy
end

local ROLE_TEXTURES = {
    TANK = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Roles\\Role_Tank.tga",
    HEALER = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Roles\\Role_Healer.tga",
    DAMAGER = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Roles\\Role_DPS.tga",
}
local function RoleTexture(icon, role)
    local texture = ROLE_TEXTURES[role]
    if not texture then return false end
    icon:SetTexture(texture)
    icon:SetTexCoord(0, 1, 0, 1)
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

local function RestoreUnitFrame(plate)
    local frame = plate and plate.UnitFrame
    local original = hiddenUnitFrames[plate]
    if original ~= nil then
        hiddenUnitFrames[plate] = nil
        if frame and frame.SetAlpha then frame:SetAlpha(original) end
    end
end

local nonPlayerMarkers = {} -- separate, reversible pet/NPC overlays
function M.GetMoverFrame(npc)
    local markers = npc and nonPlayerMarkers or active
    for _, marker in pairs(markers) do
        if marker:IsVisible() and (not npc or marker.isNPC) then return marker end
    end
end
-- React immediately when Blizzard resets native plate opacity, instead of
-- waiting for the next marker update.
local nativeAlphaHooks = setmetatable({}, {__mode = "k"})
local nativeAlphaReentry = setmetatable({}, {__mode = "k"})
local function KeepNativePlateHidden(plate)
    local frame = plate and plate.UnitFrame
    if not frame or nativeAlphaHooks[frame] then return end
    if type(hooksecurefunc) ~= "function" then return end
    nativeAlphaHooks[frame] = true
    hooksecurefunc(frame, "SetAlpha", function(self)
        if nativeAlphaReentry[self] or self ~= plate.UnitFrame or hiddenUnitFrames[plate] == nil then return end
        local marker, player = nonPlayerMarkers[plate], active[plate]
        if not (marker and marker:IsShown() or player and player.textAnchor and player.textAnchor:IsShown()) then return end
        local unit = plateUnits[plate]
        if not unit or not groupFlag(UnitExists(unit)) then return end
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit) ~= plate then return end
        local alpha = self:GetAlpha()
        if readable(alpha) and alpha ~= 0 then
            nativeAlphaReentry[self] = true
            self:SetAlpha(0)
            nativeAlphaReentry[self] = nil
        end
    end)
end
local function HidePlate(plate)
    RestoreUnitFrame(plate)
    local marker = active[plate]
    if marker then
        marker:Hide()
        if marker.textAnchor then marker.textAnchor:Hide() end
    end
    RestoreName(plate)
    if nonPlayerMarkers[plate] then nonPlayerMarkers[plate]:Hide() end
end

local function UpdateEnemyPlate(unit, plate, friendly)
    if friendly then Enemy:Remove(unit)
    else Enemy:Update(unit, plate) end
end

local UpdateNonPlayerPlate -- defined below; separate from approved Friendly Player logic
local function UpdatePlate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local previous = unitPlates[unit]
    if previous and previous ~= plate and plateUnits[previous] == unit then
        plateUnits[previous] = nil
        HidePlate(previous)
    end
    local previousUnit = plateUnits[plate]
    if previousUnit and previousUnit ~= unit then
        if unitPlates[previousUnit] == plate then unitPlates[previousUnit] = nil end
        Enemy:Remove(previousUnit)
        HidePlate(plate)
    end
    plateUnits[plate], unitPlates[unit] = unit, plate
    local friendly = Friendly(unit)
    UpdateEnemyPlate(unit, plate, friendly)
    local cfg = Config()
    local isPlayer = UnitIsPlayer(unit)
    if cfg and cfg.enabled and groupFlag(UnitExists(unit)) and readable(isPlayer) and not isPlayer then
        UpdateNonPlayerPlate(unit, plate, cfg)
        return
    end
    if not cfg or not cfg.enabled or cfg.friendlyIcon == "off" or not friendly then
        HidePlate(plate)
        if nonPlayerMarkers[plate] then nonPlayerMarkers[plate]:Hide() end
        return
    end

    -- Scope filters icons only. Keep the configured name/guild styling
    -- on every friendly player regardless of group membership.
    local staleNonPlayer = nonPlayerMarkers[plate]
    if staleNonPlayer then staleNonPlayer:Hide() end
    local showIcon = cfg.friendlyScope ~= "group" or InGroup(unit)
    local iconMode = cfg.friendlyIcon or "role"
    local role
    if IsRaid() then
        -- Raid always uses tank/healer role icons, but text stays visible.
        iconMode = "role"
        role = Role(unit)
        showIcon = showIcon and (role == "TANK" or role == "HEALER")
    end
    local marker = active[plate]
    if not marker then
        marker = CreateFrame("Frame", nil, plate)
        marker:SetFrameLevel(plate:GetFrameLevel() + 10)
        marker.icon = marker:CreateTexture(nil, "OVERLAY", nil, 2)
        marker.icon:SetPoint("CENTER", marker, "CENTER", 0, 0)
        -- MiniMarkers-style circular clipping with a subtle ring.
        -- Use Blizzard's built-in portrait mask to avoid shipping third-party artwork.
        marker.iconMask = marker:CreateMaskTexture()
        marker.iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        marker.iconMask:SetPoint("CENTER", marker, "CENTER", 0, 0)
        marker.icon:AddMaskTexture(marker.iconMask)
        -- Reuse the exact portrait ring atlas and crop used by UnitFrames.
        -- Keep the ring behind the icon, so the artwork is not obscured.
        marker.rim = marker:CreateTexture(nil, "OVERLAY", nil, 1)
        marker.rim:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
        marker.rim:SetTexCoord(252.78 / 384, 375 / 384, 1.67 / 134, 123.89 / 134)
        marker.rim:SetPoint("CENTER", marker, "CENTER")
        -- The portrait implementation also masks the ring itself.
        -- Without this, the atlas crop exposes a rectangular strip on the left.
        marker.rimMask = marker:CreateMaskTexture()
        marker.rimMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        marker.rimMask:SetPoint("CENTER", marker.rim, "CENTER")
        marker.rim:AddMaskTexture(marker.rimMask)
        marker.textAnchor = CreateFrame("Frame", nil, plate)
        -- Keep text fully opaque even when the nameplate fades at range.
        -- The icon remains a normal child and retains Blizzard fading.
        if marker.textAnchor.SetIgnoreParentAlpha then
            marker.textAnchor:SetIgnoreParentAlpha(true)
        end
        marker.textAnchor:SetSize(1, 1)
        marker.textAnchor:SetFrameLevel(plate:GetFrameLevel() + 11)
        marker.name = marker.textAnchor:CreateFontString(nil, "OVERLAY")
        marker.name:SetJustifyH("CENTER")
        marker.guild = marker.textAnchor:CreateFontString(nil, "OVERLAY")
        marker.guild:SetJustifyH("CENTER")
        active[plate] = marker
    end
    local valid = false
    if iconMode == "class" then
        valid = ClassTexture(marker.icon, unit)
    elseif iconMode == "role" then
        role = role or Role(unit)
        valid = RoleTexture(marker.icon, role)
    end
    showIcon = showIcon and valid
    -- Test: hide Blizzard nameplate presentation while keeping its parent
    -- visible as the marker anchor. Alpha is restored on disable/removal.
    local unitFrame = plate.UnitFrame
    if unitFrame and unitFrame.SetAlpha then
        if hiddenUnitFrames[plate] == nil then
            hiddenUnitFrames[plate] = unitFrame:GetAlpha()
        end
        KeepNativePlateHidden(plate)
        unitFrame:SetAlpha(0)
    end
    local anchor = plate
    marker:ClearAllPoints()
    marker:SetPoint("BOTTOM", anchor, "TOP", cfg.friendlyX or 0, cfg.friendlyY or 20)
    marker:SetSize(cfg.friendlySize or 28, cfg.friendlySize or 28)
    -- Keep the icon at its configured size but tuck the portrait rim closer
    -- to its edge, showing roughly half the previous visible gold border.
    local iconSize = cfg.friendlySize or 28
    local rimSize = iconSize * 1.08
    -- Class and role icons use the same center, size and circular mask.
    -- The artwork stays on sublevel 2, in front of the gold rim on sublevel 1.
    local visibleSize = iconSize * 0.95
    local artworkSize = iconMode == "role" and valid and (visibleSize * 1.0815) or visibleSize
    marker.icon:SetSize(artworkSize, artworkSize)
    marker.iconMask:SetSize(artworkSize, artworkSize)
    marker.rim:SetSize(rimSize, rimSize)
    marker.rimMask:SetSize(rimSize, rimSize)
    marker.rim:Show()
    -- Keep the approved single-layer appearance. The user selected size 20.
    -- FontString text inherits the nameplate's frame transforms.
    for _, label in ipairs({marker.name, marker.guild}) do
        local font, size, flags, shadow = addon.Typography.Resolve("Nameplates:Friendly",
            UNIT_NAME_FONT, cfg.friendlyTextSize or 20, "")
        local ok, applied = pcall(label.SetFont, label, font, size, flags)
        if not ok or applied == false then
            local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
            if fallback then pcall(label.SetFont, label, fallback, size, flags) end
        end
        label:SetTextColor(115 / 255, 115 / 255, 217 / 255, 1)
        label:SetShadowColor(0, 0, 0, 0.35)
        label:SetShadowOffset(0, 0)
        addon.Typography.Shadow(label, shadow)
    end
    PositionFriendlyText(plate, marker, cfg)
    marker.name:ClearAllPoints()
    marker.name:SetPoint("TOP", marker.textAnchor, "TOP", 0, 0)
    marker.guild:ClearAllPoints()
    marker.guild:SetPoint("TOP", marker.name, "BOTTOM", 0, 0)
    local displayName, surname = (UnitNameUnmodified or UnitName)(unit)
    local function readable(value)
        return (not issecretvalue or not issecretvalue(value))
            and (not canaccessvalue or canaccessvalue(value)) and type(value) == "string"
    end
    if readable(displayName) and readable(surname) and surname ~= "" then
        local constants = Constants and Constants.CharacterNameSeparatorConsts
        local separator = constants and constants.CHARACTERNAME_SURNAME_SEPARATOR or " "
        displayName = displayName .. separator .. surname
    end
    if marker.name then
        marker.name:SetText(displayName or "")
        marker.name:SetWidth(math.max(160, (cfg.friendlySize or 28) * 4))
        marker.name:Show()
    end
    if marker.guild then
        -- GetGuildInfo can be unavailable for units whose guild is not known
        -- to the client. Do not invent a guild or show an empty bracket line.
        local guildName = GetGuildInfo and GetGuildInfo(unit)
        if type(guildName) == "string" and guildName ~= "" then
            marker.guild:SetText("<" .. guildName .. ">")
            marker.guild:SetWidth(math.max(200, (cfg.friendlySize or 28) * 5))
            marker.guild:Show()
        else
            marker.guild:SetText("")
            marker.guild:Hide()
        end
    end
    -- Native-name experiment: keep the nameplate anchor and class icon,
    -- but remove all addon-generated text to reveal whether the engine
    -- renders its normal world-space player name independently.
    if nativeNameTest then
        if marker.name then marker.name:Hide() end
        if marker.guild then marker.guild:Hide() end
    end
    marker.textAnchor:SetScale(1)
    marker.textAnchor:SetAlpha(1)
    marker:SetShown(showIcon)
    marker.textAnchor:Show()
    -- Do not restyle hidden nameplate text in this experiment.
end

-- Pet and NPC text-only plates. Friendly player rendering above is unchanged.
local function PetOwner(unit)
    if UnitIsUnit(unit, "pet") then return "player" end
    for i = 1, 4 do
        local owner = "party" .. i
        if UnitExists(owner .. "pet") and UnitIsUnit(unit, owner .. "pet") then return owner end
    end
    for i = 1, 40 do
        local owner = "raid" .. i
        if UnitExists(owner .. "pet") and UnitIsUnit(unit, owner .. "pet") then return owner end
    end
    if type(UnitCreator) == "function" then
        local ok, owner = pcall(UnitCreator, unit)
        if ok and type(owner) == "string" and UnitExists(owner) then return owner end
    end
    return nil
end

local function IsPetUnit(unit)
    if UnitIsUnit(unit, "pet") then return true end
    if type(UnitIsOtherPlayersPet) == "function" and UnitIsOtherPlayersPet(unit) then return true end
    if type(UnitPlayerControlled) == "function" and UnitPlayerControlled(unit) then return true end
    return PetOwner(unit) ~= nil
end

-- Blizzard nameplate FontString:GetText() can return protected secret strings.
-- Do not scan or compare those values from addon code. PetOwner() provides
-- the owner label when a safe unit token is available.
local function NativeOwnerLabel()
    return nil
end

-- The tooltip's second line is plain NPC title text on Forever.
-- Read it only for the matching mouseover unit; never inspect protected
-- Blizzard nameplate FontStrings or register unsupported tooltip scripts.
local npcTitles = {}
local npcScanTooltip
local function NPCSubtitle(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if not guid then return nil end
    -- Try the unit's tooltip data directly when its nameplate appears.
    -- This does not depend on mouseover and does not touch Blizzard plates.
    if not npcTitles[guid] and C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, title = pcall(function()
            local data = C_TooltipInfo.GetUnit(unit)
            local line = data and data.lines and data.lines[2]
            local value = line and line.leftText
            if type(value) ~= "string" then return nil end
            if issecretvalue and issecretvalue(value) then return nil end
            value = value:match("^%s*(.-)%s*$")
            if not value or value == "" or value:match("^Level%s")
                or value:match("^%d+%s") then return nil end
            return value:match("^<(.+)>$") and value or ("<" .. value .. ">")
        end)
        if ok and title then npcTitles[guid] = title end
    end
    -- Older clients may expose unit tooltip data only through SetUnit.
    -- Scan on nameplate activation; never do this in combat.
    if not npcTitles[guid] and not InCombatLockdown() then
        local ok, title = pcall(function()
            if not npcScanTooltip then
                npcScanTooltip = CreateFrame("GameTooltip", "BaziUINPCScanTooltip", UIParent, "GameTooltipTemplate")
                npcScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            end
            npcScanTooltip:ClearLines()
            npcScanTooltip:SetUnit(unit)
            local line = _G.BaziUINPCScanTooltipTextLeft2
            local value = line and line:GetText()
            if type(value) ~= "string" then return nil end
            if issecretvalue and issecretvalue(value) then return nil end
            value = value:match("^%s*(.-)%s*$")
            if not value or value == "" or value:match("^Level%s")
                or value:match("^%d+%s") then return nil end
            return value:match("^<(.+)>$") and value or ("<" .. value .. ">")
        end)
        if ok and title then npcTitles[guid] = title end
    end
    if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()
        and UnitExists("mouseover") and UnitIsUnit(unit, "mouseover") then
        local ok, title = pcall(function()
            local _, tooltipUnit = GameTooltip:GetUnit()
            if not tooltipUnit or not UnitIsUnit(tooltipUnit, unit) then return nil end
            local line = _G.GameTooltipTextLeft2
            local value = line and line:GetText()
            if type(value) ~= "string" then return nil end
            if issecretvalue and issecretvalue(value) then return nil end
            value = value:match("^%s*(.-)%s*$")
            if not value or value == "" or value:match("^Level%s")
                or value:match("^%d+%s") then return nil end
            return value:match("^<(.+)>$") and value or ("<" .. value .. ">")
        end)
        if ok and title then npcTitles[guid] = title end
    end
    return npcTitles[guid]
end

-- BaziUI's original 64x64 TGA NPC service artwork. Keep the approved
-- 28x28 presentation, icon positioning and pet/player nameplates unchanged.
local NPC_ICON_ROOT = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\NPC\\NPC_"
local function NPCIcon(name)
    return NPC_ICON_ROOT .. name .. ".tga"
end
local NPC_SERVICE_TEXTURES = {
    repair = NPCIcon("Repair"),
    flight = NPCIcon("FlightMaster"),
    inn = NPCIcon("Innkeeper"),
    bank = NPCIcon("Banker"),
    vendor = NPCIcon("Vendor"),
    trainer = NPCIcon("Trainer"), -- Shared class/profession trainer book.
    auction = NPCIcon("Auctioneer"),
    stable = NPCIcon("StableMaster"),
    battlemaster = NPCIcon("Battlemaster"),
    guild = NPCIcon("GuildMaster"),
    tabard = NPCIcon("TabardDesigner"),
    weapon = NPCIcon("WeaponMaster"),
    pet = NPCIcon("PetTrainer"),
    spirit = NPCIcon("SpiritHealer"),
    transmog = NPCIcon("Transmogrifier"),
    barber = NPCIcon("Barber"),
}
local function NPCServiceIcon(title, unit)
    local registry = BaziUI.NPCServices
    local roles = registry and registry.Get and registry:Get(unit)
    if roles then
        -- Specific services win over generic vendor flags. Some trainers,
        -- auctioneers and stable masters are also marked as vendors.
        for _, key in ipairs({"repair", "flight", "auction", "stable", "trainer",
            "inn", "bank", "vendor"}) do
            if roles[key] then return NPC_SERVICE_TEXTURES[key] end
        end
    end
    -- Subtitle fallback for services absent from the NPC-ID database.
    if type(title) ~= "string" then return nil end
    local value = title:lower()
    if value:find("flight master", 1, true) or value:find("gryphon master", 1, true)
        or value:find("hippogryph master", 1, true)
        or value:find("wind rider", 1, true) then return NPC_SERVICE_TEXTURES.flight end
    if value:find("innkeeper", 1, true) then return NPC_SERVICE_TEXTURES.inn end
    if value:find("auctioneer", 1, true) then return NPC_SERVICE_TEXTURES.auction end
    if value:find("stable master", 1, true) then return NPC_SERVICE_TEXTURES.stable end
    if value:find("banker", 1, true) then return NPC_SERVICE_TEXTURES.bank end
    if value:find("repair", 1, true) or value:find("blacksmith", 1, true)
        then return NPC_SERVICE_TEXTURES.repair end
    if value:find("battlemaster", 1, true) or value:find("battle master", 1, true)
        then return NPC_SERVICE_TEXTURES.battlemaster end
    if value:find("guild master", 1, true) or value:find("guild services", 1, true)
        then return NPC_SERVICE_TEXTURES.guild end
    if value:find("tabard", 1, true) then return NPC_SERVICE_TEXTURES.tabard end
    if value:find("weapon master", 1, true) then return NPC_SERVICE_TEXTURES.weapon end
    if value:find("pet trainer", 1, true) then return NPC_SERVICE_TEXTURES.pet end
    if value:find("spirit healer", 1, true) then return NPC_SERVICE_TEXTURES.spirit end
    if value:find("transmogrifier", 1, true) or value:find("transmogrification", 1, true)
        then return NPC_SERVICE_TEXTURES.transmog end
    if value:find("barber", 1, true) then return NPC_SERVICE_TEXTURES.barber end
    if value:find("trainer", 1, true) then return NPC_SERVICE_TEXTURES.trainer end
    return nil
end

local flightCheckAt, nearbyUndiscovered = 0, false
local function learnedFlights()
    local guid = UnitGUID("player")
    if type(guid) ~= "string" or not addon.db then return end
    addon.db.learnedFlights = addon.db.learnedFlights or {}
    local learned = addon.db.learnedFlights[guid] or {}
    addon.db.learnedFlights[guid] = learned
    return learned
end

local function rememberTaxiNodes()
    flightCheckAt = 0
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID) then return end
    local learned = learnedFlights()
    local map = GetTaxiMapID()
    if not learned or not map then return end
    local state = Enum and Enum.FlightPathState
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
        if node.nodeID and (node.state == (state and state.Current or 0)
            or node.state == (state and state.Reachable or 1)) then
            learned[node.nodeID] = true
        end
    end
end

local function unlearnedFlightNearby()
    local now = GetTime()
    if now < flightCheckAt then return nearbyUndiscovered end
    flightCheckAt, nearbyUndiscovered = now + 1, false
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and C_Map and C_Map.GetBestMapForUnit) then return false end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return false end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    local px, py
    if position then px, py = position:GetXY() end
    local named, namedCount, nearest, best = nil, 0, nil, 0.025 ^ 2
    local subzone = GetSubZoneText()
    for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
        local place = node.name and node.name:match("^([^,]+)")
        if place and place == subzone then named, namedCount = node, namedCount + 1 end
        if px and py and node.position then
            local x, y = node.position:GetXY()
            local distance = (x - px) ^ 2 + (y - py) ^ 2
            if distance < best then nearest, best = node, distance end
        end
    end
    local node = namedCount == 1 and named or nearest
    local learned = learnedFlights()
    nearbyUndiscovered = node ~= nil and node.isUndiscovered == true
        and not (learned and learned[node.nodeID])
    return nearbyUndiscovered
end

-- NPC labels are intentionally fixed at 16 UI points. Never compensate
-- for nameplate distance by changing their font size.
local NPC_FONT_SIZE = 16

local function NonPlayerMarker(plate)
    local marker = nonPlayerMarkers[plate]
    if marker then return marker end
    marker = CreateFrame("Frame", nil, plate)
    marker:SetFrameLevel(plate:GetFrameLevel() + 11)
    marker:SetSize(1, 1)
    if marker.SetIgnoreParentAlpha then marker:SetIgnoreParentAlpha(true) end
    marker.name = marker:CreateFontString(nil, "OVERLAY")
    marker.name:SetJustifyH("CENTER")
    marker.owner = marker:CreateFontString(nil, "OVERLAY")
    marker.owner:SetJustifyH("CENTER")
    marker.owner:SetPoint("TOP", marker.name, "BOTTOM", 0, 0)
    marker.iconAnchor = CreateFrame("Frame", nil, marker)
    marker.iconAnchor:SetPoint("BOTTOM", marker.name, "TOP", 0, 4)
    marker.icon = marker.iconAnchor:CreateTexture(nil, "OVERLAY", nil, 2)
    marker.icon:SetPoint("CENTER", marker.iconAnchor, "CENTER", 0, 0)
    marker.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
    marker.iconMask = marker.iconAnchor:CreateMaskTexture()
    marker.iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    marker.iconMask:SetPoint("CENTER", marker.iconAnchor, "CENTER", 0, 0)
    marker.icon:AddMaskTexture(marker.iconMask)
    marker.rim = marker.iconAnchor:CreateTexture(nil, "OVERLAY", nil, 1)
    marker.rim:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
    marker.rim:SetTexCoord(252.78 / 384, 375 / 384, 1.67 / 134, 123.89 / 134)
    marker.rim:SetPoint("CENTER", marker.iconAnchor, "CENTER", 0, 0)
    marker.rimMask = marker.iconAnchor:CreateMaskTexture()
    marker.rimMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    marker.rimMask:SetPoint("CENTER", marker.iconAnchor, "CENTER", 0, 0)
    marker.rim:AddMaskTexture(marker.rimMask)
    -- NPC service markers and the pet combat paw use unmasked artwork.
    marker.npcIcon = marker.iconAnchor:CreateTexture(nil, "OVERLAY", nil, 3)
    marker.npcIcon:SetPoint("CENTER", marker.iconAnchor, "CENTER")
    -- Blizzard tracking textures are complete icons, not cropped item portraits.
    marker.npcIcon:SetTexCoord(0, 1, 0, 1)
    marker.npcIcon:Hide()
    marker.flightAlert = marker.iconAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    marker.flightAlert:SetPoint("LEFT", marker.npcIcon, "RIGHT", -2, 0)
    marker.flightAlert:SetText("!")
    marker.flightAlert:SetTextColor(0.22, 1, 0.18)
    marker.flightAlert:SetShadowOffset(1, -1)
    marker.flightAlert:Hide()
    nonPlayerMarkers[plate] = marker
    -- Blizzard may reset UnitFrame alpha after NAME_PLATE_UNIT_ADDED.
    -- Reapply only for an actively styled pet/NPC, never for locked player plates.
    local elapsedSinceCheck = 0
    marker:SetScript("OnUpdate", function(self, elapsed)
        elapsedSinceCheck = elapsedSinceCheck + elapsed
        if elapsedSinceCheck < 0.05 then return end
        elapsedSinceCheck = 0
        if not self:IsShown() then return end
        local unit = plateUnits[plate]
        if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit) ~= plate then return end
        -- UNIT_COMBAT can arrive after PLAYER_REGEN_ENABLED. Clear stale
        -- engagement once neither the player nor their pet is fighting.
        if petCombatEngaged and not UnitAffectingCombat("player")
            and (not UnitExists("pet") or not UnitAffectingCombat("pet")) then
            petCombatEngaged = false
        end
        local cfg = Config()
        if self.isNPC and self:GetParent() == UIParent and (not addon.Movers or not addon.Movers.IsDragging(self)) then
            local ok, x, top = pcall(function()
                local centerX = plate:GetCenter()
                local plateTop = plate:GetTop()
                return centerX, plateTop
            end)
            if ok and type(x) == "number" and type(top) == "number" then
                local scale = UIParent:GetEffectiveScale()
                local plateScale = plate:GetEffectiveScale()
                if scale > 0 then
                    local offsetX = (cfg and cfg.friendlyTextX or 0)
                    local offsetY = 18 + (cfg and cfg.friendlyTextY or 0)
                    self:ClearAllPoints()
                    self:SetPoint("TOP", UIParent, "BOTTOMLEFT",
                        x * plateScale / scale + offsetX,
                        top * plateScale / scale + offsetY)
                end
            end
        end
        if self.isNPC and cfg and cfg.npcEnabled ~= false then
            local title = NPCSubtitle(unit)
            self.owner:SetText(title or "")
            self.owner:SetShown(title ~= nil)
            local texture = cfg.npcIcons and NPCServiceIcon(title, unit)
            if texture then self.npcIcon:SetTexture(texture) end
            self.npcIcon:SetShown(texture ~= nil)
            self.flightAlert:SetShown(texture == NPC_SERVICE_TEXTURES.flight and unlearnedFlightNearby())
            self.iconAnchor:SetShown(texture ~= nil)
        end
        if cfg and cfg.petIconVisibility == "combat" and self.isOwnPet then
            -- Combat begins on an actual attack or hit, not an attack order.
            self.iconAnchor:SetShown(cfg.petShowIcon == true
                and petCombatEngaged)
        end
        local frame = plate.UnitFrame
        if frame and frame.GetAlpha and frame.SetAlpha and frame:GetAlpha() ~= 0 then
            frame:SetAlpha(0)
        end
    end)
    return marker
end

UpdateNonPlayerPlate = function(unit, plate, cfg)
    local pet = IsPetUnit(unit)
    if (pet and cfg.petEnabled == false) or (not pet and cfg.npcEnabled == false)
        or not UnitIsFriend("player", unit) or UnitIsEnemy("player", unit) then
        HidePlate(plate)
        local previous = nonPlayerMarkers[plate]
        if previous then previous:Hide() end
        return
    end
    -- Never treat a non-player as a friendly player: the player path is locked.
    local previous = active[plate]
    if previous then
        previous:Hide()
        if previous.textAnchor then previous.textAnchor:Hide() end
    end
    RestoreName(plate)
    local marker = NonPlayerMarker(plate)
    local sourceName = UnitName(unit) or ""
    local owner = pet and PetOwner(unit) or nil
    local ownerText = pet and NativeOwnerLabel(plate, sourceName) or NPCSubtitle(unit)
    if pet and not ownerText and owner then
        local ownerName = UnitName(owner)
        if ownerName and ownerName ~= "" then
            ownerText = "<" .. ownerName .. "'s Pet>"
        end
    end
    local frame = plate.UnitFrame
    if frame and frame.SetAlpha then
        if hiddenUnitFrames[plate] == nil then hiddenUnitFrames[plate] = frame:GetAlpha() end
        KeepNativePlateHidden(plate)
        frame:SetAlpha(0)
    end
    local size = cfg.friendlyTextSize or NPC_FONT_SIZE
    for _, label in ipairs({marker.name, marker.owner}) do
        local font, height, flags, shadow = addon.Typography.Resolve("Nameplates:NPC", UNIT_NAME_FONT, size, "")
        local ok, applied = pcall(label.SetFont, label, font, height, flags)
        if not ok or applied == false then
            local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
            if fallback then pcall(label.SetFont, label, fallback, height, flags) end
        end
        if pet then
            label:SetTextColor(115 / 255, 115 / 255, 217 / 255, 1)
        else
            label:SetTextColor(0, 1, 0, 1)
        end
        label:SetShadowColor(0, 0, 0, 0.35)
        label:SetShadowOffset(0, 0)
        addon.Typography.Shadow(label, shadow)
    end
    marker:ClearAllPoints()
    if pet then
        marker:SetPoint("TOP", plate, "TOP", cfg.friendlyTextX or 0,
            18 + (cfg.friendlyTextY or 0))
    else
        -- Seed a visible position before the OnUpdate screen-space tracking.
        -- Anchoring at (0,0) could make IsShown() false and stop the updater.
        marker:SetPoint("TOP", plate, "TOP", cfg.friendlyTextX or 0,
            18 + (cfg.friendlyTextY or 0))
    end
    marker.name:ClearAllPoints()
    marker.name:SetPoint("TOP", marker, "TOP", 0, 0)
    marker.name:SetWidth(math.max(160, (cfg.friendlySize or 28) * 4))
    marker.name:SetText(sourceName)
    marker.owner:SetWidth(math.max(200, (cfg.friendlySize or 28) * 5))
    marker.owner:SetText(ownerText or "")
    marker.owner:SetShown(ownerText ~= nil and ownerText ~= "")
    -- Only the player's own pet can ever display a portrait-style icon.
    local myPet = pet and UnitIsUnit(unit, "pet")
    marker.isOwnPet = myPet
    marker.isNPC = not pet
    -- NPC presentation lives on UIParent so distance scaling of the native
    -- nameplate does not magnify the text or service icon. Its anchor still
    -- follows the nameplate's position. Pets retain their approved parent.
    local parent = pet and plate or UIParent
    if marker:GetParent() ~= parent then marker:SetParent(parent) end
    -- Keep NPC presentation at UIParent's fixed scale, not nameplate distance.
    if not pet and marker:GetScale() ~= 1 then marker:SetScale(1) end
    if not pet then
        marker:SetFrameStrata("LOW")
        marker:SetFrameLevel(100)
    else
        marker:SetFrameStrata(plate:GetFrameStrata())
        marker:SetFrameLevel(plate:GetFrameLevel() + 11)
    end
    local iconVisible = myPet and cfg.petShowIcon == true
        and (cfg.petIconVisibility ~= "combat" or petCombatEngaged)
    marker.iconAnchor:SetSize(cfg.friendlySize or 28, cfg.friendlySize or 28)
    marker.icon:SetSize((cfg.friendlySize or 28) * 0.95, (cfg.friendlySize or 28) * 0.95)
    marker.iconMask:SetSize((cfg.friendlySize or 28) * 0.95, (cfg.friendlySize or 28) * 0.95)
    marker.rim:SetSize((cfg.friendlySize or 28) * 1.08, (cfg.friendlySize or 28) * 1.08)
    marker.rimMask:SetSize((cfg.friendlySize or 28) * 1.08, (cfg.friendlySize or 28) * 1.08)
    if not pet then
        -- Keep all pet-only circular portrait artwork hidden on NPC plates.
        marker.icon:Hide()
        marker.rim:Hide()
        local texture = cfg.npcIcons and NPCServiceIcon(ownerText, unit)
        if texture then marker.npcIcon:SetTexture(texture) end
        marker.npcIcon:SetSize(36, 36)
        marker.npcIcon:SetAlpha(1)
        marker.npcIcon:SetShown(texture ~= nil)
        marker.flightAlert:SetShown(texture == NPC_SERVICE_TEXTURES.flight and unlearnedFlightNearby())
        iconVisible = texture ~= nil
    else
        marker.flightAlert:Hide()
        local combatPaw = cfg.petIconVisibility == "combat"
        marker.icon:SetShown(not combatPaw)
        marker.rim:SetShown(not combatPaw)
        if combatPaw then
            marker.npcIcon:SetTexture(NPC_SERVICE_TEXTURES.pet)
            local pawSize = (cfg.friendlySize or 28) * 0.8
            marker.npcIcon:SetSize(pawSize, pawSize)
            marker.npcIcon:SetAlpha(0.85)
        else
            marker.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
        end
        marker.npcIcon:SetShown(combatPaw)
    end
    marker.iconAnchor:SetShown(iconVisible)
    -- NPC icons use only known service titles, not inferred unit names.
    marker:Show()
end

-- Session-only visual preview. These are UI frames, not spoofed unit nameplates.
local friendlyPreviewEnabled = false
local friendlyPreview = {}
local function RefreshFriendlyPreview()
    local cfg = Config()
    if not friendlyPreviewEnabled or not cfg or not cfg.enabled then
        for _, frame in ipairs(friendlyPreview) do frame:Hide() end
        return
    end
    local size = cfg.friendlySize or 28
    for i, role in ipairs({"TANK", "HEALER", "DAMAGER", "CLASS"}) do
        local frame = friendlyPreview[i]
        if not frame then
            frame = CreateFrame("Frame", nil, UIParent)
            frame:SetFrameStrata("DIALOG")
            frame.icon = frame:CreateTexture(nil, "ARTWORK", nil, 2)
            frame.icon:SetPoint("CENTER")
            frame.mask = frame:CreateMaskTexture()
            frame.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            frame.mask:SetPoint("CENTER")
            frame.icon:AddMaskTexture(frame.mask)
            frame.rim = frame:CreateTexture(nil, "ARTWORK", nil, 1)
            frame.rim:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
            frame.rim:SetTexCoord(252.78/384, 375/384, 1.67/134, 123.89/134)
            frame.rim:SetPoint("CENTER")
            frame.rimMask = frame:CreateMaskTexture()
            frame.rimMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            frame.rimMask:SetPoint("CENTER")
            frame.rim:AddMaskTexture(frame.rimMask)
            frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -3)
            friendlyPreview[i] = frame
        end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER",
            (i-2.5)*math.max(85,size*2.5)+(cfg.friendlyX or 0),
            115+(cfg.friendlyY or 20))
        frame:SetSize(size,size)
        -- Compare roles against the exact class artwork sizing used by live plates.
        local artworkSize = role == "CLASS" and size*.95 or size*.95*1.0815
        frame.icon:SetSize(artworkSize,artworkSize)
        frame.mask:SetSize(artworkSize,artworkSize)
        frame.rim:SetSize(size*1.08,size*1.08)
        frame.rimMask:SetSize(size*1.08,size*1.08)
        if role == "CLASS" then
            ClassTexture(frame.icon,"player")
        else
            RoleTexture(frame.icon,role)
        end
        frame.label:SetText(role == "DAMAGER" and "DPS" or role)
        frame:Show()
    end
end
-- Raw texture diagnostic, deliberately outside the nameplate mask/rim.
-- /bazinptexture displays one Blizzard control and all three addon TGAs.
local textureDiagnostic
SLASH_BAZINPTEXTURE1 = "/bazinptexture"
SlashCmdList.BAZINPTEXTURE = function()
    if textureDiagnostic then
        textureDiagnostic:Hide()
        textureDiagnostic = nil
        addon:Print("Nameplate texture diagnostic OFF")
        return
    end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetSize(360, 125)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    local paths = {
        {"BLIZZARD", "Interface\\Icons\\INV_Misc_QuestionMark"},
        {"TANK", ROLE_TEXTURES.TANK},
        {"HEALER", ROLE_TEXTURES.HEALER},
        {"DPS", ROLE_TEXTURES.DAMAGER},
    }
    for i, item in ipairs(paths) do
        local icon = panel:CreateTexture(nil, "ARTWORK")
        icon:SetSize(64,64)
        icon:SetPoint("TOPLEFT", panel, "TOPLEFT", (i-1)*90+12, -8)
        icon:SetTexture(item[2])
        icon:SetTexCoord(0,1,0,1)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", icon, "BOTTOM", 0, -5)
        label:SetText(item[1])
    end
    textureDiagnostic = panel
    addon:Print("Texture diagnostic ON: Blizzard control + 3 raw TGA textures, no masks.")
end

SLASH_BAZINPTEST1 = "/bazinptest"
SlashCmdList.BAZINPTEST = function()
    friendlyPreviewEnabled = not friendlyPreviewEnabled
    RefreshFriendlyPreview()
    addon:Print("Friendly nameplate role preview " .. (friendlyPreviewEnabled and "ON" or "OFF"))
end

function M:ApplyEnemy()
    Enemy:Prepare()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    for plate, unit in pairs(plateUnits) do
        if C_NamePlate.GetNamePlateForUnit(unit) == plate then
            UpdateEnemyPlate(unit, plate, Friendly(unit))
        else
            Enemy:Remove(unit)
        end
    end
end

function M:Apply()
    RefreshFriendlyPreview()
    local cfg = Config()
    if not cfg or not cfg.enabled then
        Enemy:Clear()
        for plate in pairs(active) do HidePlate(plate) end
        for plate in pairs(styledNames) do RestoreName(plate) end
        for plate in pairs(hiddenUnitFrames) do RestoreUnitFrame(plate) end
        return
    end
    -- A nameplate frame does not reliably expose namePlateUnitToken on this
    -- client. Retain the token from NAME_PLATE_UNIT_ADDED instead of hiding
    -- existing markers whenever a setting changes.
    Enemy:Prepare()
    for plate, unit in pairs(plateUnits) do
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit) == plate then
            UpdatePlate(unit)
        else
            plateUnits[plate] = nil
            if unitPlates[unit] == plate then
                unitPlates[unit] = nil
                Enemy:Remove(unit)
            end
            HidePlate(plate)
        end
    end
    -- Also discover plates that existed before this module initialized.
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if not plateUnits[plate] then
                local unit = plate.namePlateUnitToken
                if unit then UpdatePlate(unit) end
            end
        end
    end
end

local pendingPlayers = {}
local function queueFriendlyPlate(unit)
    pendingPlayers[unit] = true
    if eventFrame:GetScript("OnUpdate") then return end
    eventFrame:SetScript("OnUpdate", function(self)
        local start = debugprofilestop and debugprofilestop()
        for _ = 1, 4 do
            local token = next(pendingPlayers)
            if not token then break end
            pendingPlayers[token] = nil
            UpdatePlate(token)
            if start and debugprofilestop() - start >= 1.2 then break end
        end
        if not next(pendingPlayers) then self:SetScript("OnUpdate", nil) end
    end)
end

function M:Initialize()
    if self.initialized then return end
    self.initialized = true
    Enemy:Initialize()
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("TAXIMAP_OPENED")
    -- Unlike COMBAT_LOG_EVENT_UNFILTERED, UNIT_COMBAT does not require protected log data.
    eventFrame:RegisterEvent("UNIT_COMBAT")
    eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if event == "TAXIMAP_OPENED" then
            rememberTaxiNodes()
            return
        elseif event == "UNIT_COMBAT" then
            PetUnitCombatInteraction(unit, ...)
            return
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Pet overlays update their icon in OnUpdate. Avoid a full plate
            -- rebuild at combat end, which can briefly reveal Blizzard's plate.
            petCombatEngaged = false
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            petCombatEngaged = false
        end
        if event == "NAME_PLATE_UNIT_ADDED" then
            local cfg = Config()
            if cfg and cfg.enabled and cfg.friendlyIcon ~= "off" and Friendly(unit) then
                queueFriendlyPlate(unit)
            else
                UpdatePlate(unit)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            pendingPlayers[unit] = nil
            Enemy:Remove(unit)
            local plate = unitPlates[unit]
            unitPlates[unit] = nil
            if plate and plateUnits[plate] == unit then
                plateUnits[plate] = nil
                HidePlate(plate)
            end
        elseif event ~= "UNIT_PET" or unit == "player" or (unit and InGroup(unit)) then
            M:Apply()
        end
    end)
    self:Apply()
end


-- Temporary read-only diagnostic. Kept in Nameplates so locked Commands.lua
-- and the other modules are untouched. Usage: /bazinpd
function M:DebugNameplates()
    local lines, plateCount, fontCount = {}, 0, 0
    local function Add(message)
        if #lines < 350 then lines[#lines + 1] = message end
    end
    local function Scan(frame, path, depth, visited)
        if not frame or depth > 8 or visited[frame] or #lines >= 350 then return end
        visited[frame] = true
        if frame.GetRegions then
            local regions = {frame:GetRegions()}
            for i, region in ipairs(regions) do
                if region.IsObjectType and region:IsObjectType("FontString") then
                    fontCount = fontCount + 1
                    local font, size, flags = region:GetFont()
                    local r, g, b, a = region:GetTextColor()
                    local value = region:GetText()
                    Add(path .. "/region" .. i .. " FontString"
                        .. " name=" .. tostring(region:GetName())
                        .. " text=" .. tostring(value)
                        .. " font=" .. tostring(font)
                        .. " size=" .. tostring(size)
                        .. " flags=" .. tostring(flags)
                        .. " rgba=" .. string.format("%.2f,%.2f,%.2f,%.2f", r or 0, g or 0, b or 0, a or 0)
                        .. " alpha=" .. tostring(region:GetAlpha())
                        .. " shown=" .. tostring(region:IsShown()))
                end
            end
        end
        if frame.GetChildren then
            for i, child in ipairs({frame:GetChildren()}) do
                Scan(child, path .. "/child" .. i .. "(" .. tostring(child:GetName()) .. ")", depth + 1, visited)
            end
        end
    end
    for plate, unit in pairs(plateUnits) do
        if plateCount >= 5 then break end
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit) == plate and Friendly(unit) then
            plateCount = plateCount + 1
            Add("=== plate " .. plateCount .. " unit=" .. tostring(unit)
                .. " name=" .. tostring(UnitName(unit))
                .. " unitFrame=" .. tostring(plate.UnitFrame) .. " ===")
            local visited = {}
            Scan(plate, "plate", 0, visited)
        end
    end
    BaziUIDB = BaziUIDB or {}
    BaziUIDB.nameplateDebug = lines
    addon:Print("Nameplate debug: " .. plateCount .. " friendly plates, "
        .. fontCount .. " text regions; " .. #lines .. " lines saved.")
    addon:Print("Run /reload, then share nameplateDebug from WTF/Account/<account>/SavedVariables/BaziUI.lua.")
    if plateCount == 0 then
        addon:Print("No tracked friendly nameplates. Stand near players with friendly plates enabled and retry.")
    end
end

SLASH_BAZINPDEBUG1 = "/bazinpd"
SlashCmdList.BAZINPDEBUG = function()
    local ok, err = pcall(function() M:DebugNameplates() end)
    if not ok then addon:Print("Nameplate debug failed: " .. tostring(err)) end
end


-- Read-only diagnostic for native world names (pet) versus addon FontStrings.
-- World-space names are rendered by the game engine and are generally not
-- exposed as FontString objects. This command reports what Lua can actually see.
-- Usage: /baziname
function M:DebugWorldName()
    local lines = {}
    local function Add(value)
        lines[#lines + 1] = tostring(value)
        addon:Print(tostring(value))
    end
    Add("World name diagnostic (pet vs addon)")
    local pet = "pet"
    Add("pet exists=" .. tostring(UnitExists(pet))
        .. " name=" .. tostring(UnitName(pet))
        .. " visible=" .. tostring(UnitIsVisible and UnitIsVisible(pet)))
    local nameCVars = {
        "UnitNameOwn", "UnitNameFriendlyPetName", "UnitNameFriendlyPlayerName",
        "UnitNameFriendlyNPCName", "UnitNameEnemyPetName",
        "nameplateShowFriends", "nameplateShowFriendlyPets",
        "nameplateMaxDistance",
    }
    for _, key in ipairs(nameCVars) do
        local ok, value = pcall(function() return GetCVar and GetCVar(key) end)
        Add("CVar " .. key .. "=" .. (ok and tostring(value) or "unavailable"))
    end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit(pet)
    Add("pet nameplate=" .. tostring(plate))
    Add("native world name FontString=not exposed by this addon/API")
    local markerCount = 0
    for frame, marker in pairs(active) do
        if marker:IsShown() and marker.name then
            markerCount = markerCount + 1
            local font, size, flags = marker.name:GetFont()
            local r, g, b, a = marker.name:GetTextColor()
            Add("Bazi name=" .. tostring(marker.name:GetText())
                .. " font=" .. tostring(font)
                .. " size=" .. tostring(size)
                .. " flags=" .. tostring(flags)
                .. " rgba=" .. string.format("%.2f,%.2f,%.2f,%.2f", r or 0, g or 0, b or 0, a or 0))
            if markerCount >= 3 then break end
        end
    end
    Add("Bazi visible markers inspected=" .. markerCount)
    -- Saved variables are flushed on reload/logout.
    BaziUIDB = BaziUIDB or {}
    BaziUIDB.worldNameDebug = lines
    Add("Saved in BaziUIDB.worldNameDebug (run /reload to write file)")
end

SLASH_BAZIWORLDNAME1 = "/baziname"
SlashCmdList.BAZIWORLDNAME = function()
    local ok, err = pcall(function() M:DebugWorldName() end)
    if not ok then addon:Print("World name diagnostic failed: " .. tostring(err)) end
end


-- Temporary, reversible native world-name visibility experiment.
-- /bazinative toggles addon text without changing any saved settings.
-- A nameplate may suppress the engine's native world name regardless of
-- UnitFrame alpha. This test deliberately does not claim otherwise.
SLASH_BAZINATIVENAME1 = "/bazinative"
SlashCmdList.BAZINATIVENAME = function()
    nativeNameTest = not nativeNameTest
    M:Apply()
    addon:Print("Native-name test " .. (nativeNameTest and "ON: addon name/guild hidden; icon and nameplate anchor retained." or "OFF: addon name/guild restored."))
    if nativeNameTest then
        addon:Print("Compare nearby friendly players with your pet. If player names disappear, native names are suppressed by active nameplates.")
    end
end


-- Read-only font-source diagnostic for the native world-name comparison.
-- /bazifont saves client globals and effective font paths in SavedVariables.
SLASH_BAZIFONT1 = "/bazifont"
SlashCmdList.BAZIFONT = function()
    local lines = {}
    local function Add(line)
        lines[#lines + 1] = tostring(line)
    end
    for _, key in ipairs({"UNIT_NAME_FONT", "STANDARD_TEXT_FONT", "NAMEPLATE_FONT"}) do
        local value = _G[key]
        Add(key .. " type=" .. type(value) .. " value=" .. tostring(value))
    end
    for _, key in ipairs({"SystemFont_NamePlate", "SystemFont_NamePlateFixed", "GameFontNormal"}) do
        local obj = _G[key]
        if obj and obj.GetFont then
            local ok, path, size, flags = pcall(obj.GetFont, obj)
            Add(key .. " font=" .. (ok and tostring(path) or "unavailable")
                .. " size=" .. tostring(size) .. " flags=" .. tostring(flags))
        end
    end
    for _, marker in pairs(active) do
        if marker.name and marker.name.GetFont then
            local path, size, flags = marker.name:GetFont()
            Add("Bazi actual font=" .. tostring(path) .. " size=" .. tostring(size)
                .. " flags=" .. tostring(flags))
            break
        end
    end
    BaziUIDB = BaziUIDB or {}
    BaziUIDB.worldFontDebug = lines
    addon:Print("Font debug saved to BaziUIDB.worldFontDebug; run /reload to write it.")
end

-- Capture distance samples silently in SavedVariables for later inspection.
-- /bazidistance [clear|status|show] prioritizes target, otherwise tracks up to 3 plates.
local distanceLog = {}
local distanceSamples = 0
local function SaveDistanceLog()
    BaziUIDB = BaziUIDB or {}
    BaziUIDB.nameplateDistanceLog = distanceLog
end
local function CaptureDistance(plate, unit)
    if not plate or not unit or not UnitExists(unit) then return false end
    local marker = active[plate]
    local distance = UnitDistance(unit)
    local squared
    if type(UnitDistanceSquared) == "function" then
        local ok, value = pcall(UnitDistanceSquared, unit)
        if ok then squared = value end
    end
    local x, y, z, map
    if type(UnitPosition) == "function" then
        local ok, a, b, c, d = pcall(UnitPosition, unit)
        if ok then x, y, z, map = a, b, c, d end
    end
    local name = UnitName(unit) or "unknown"
    distanceSamples = distanceSamples + 1
    distanceLog[#distanceLog + 1] = {
        sample = distanceSamples, time = GetTime(), name = name,
        guid = UnitGUID and UnitGUID(unit) or nil,
        unit = unit, distance = distance, squared = squared,
        x = x, y = y, z = z, map = map,
        plateScale = plate:GetScale(),
        plateEffectiveScale = plate:GetEffectiveScale(),
        markerScale = marker and marker:GetScale() or nil,
        textScale = marker and marker.textAnchor and marker.textAnchor:GetScale() or nil,
    }
    -- Bound the memory footprint when repeatedly testing.
    if #distanceLog > 200 then table.remove(distanceLog, 1) end
    SaveDistanceLog()
    return true
end
SLASH_BAZIDISTANCE1 = "/bazidistance"
SlashCmdList.BAZIDISTANCE = function(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "clear" then
        distanceLog = {}
        distanceSamples = 0
        SaveDistanceLog()
        addon:Print("Distance log cleared.")
        return
    elseif arg == "status" or arg == "show" then
        addon:Print("Distance samples saved: " .. #distanceLog
            .. ". SavedVariables: BaziUIDB.nameplateDistanceLog")
        return
    end
    local count = 0
    if UnitExists("target") and Friendly("target")
        and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local plate = C_NamePlate.GetNamePlateForUnit("target")
        if plate and active[plate] and CaptureDistance(plate, "target") then count = 1 end
    end
    if count == 0 then
        for plate, unit in pairs(plateUnits) do
            if count >= 3 then break end
            if unit and Friendly(unit) and C_NamePlate and C_NamePlate.GetNamePlateForUnit
                and C_NamePlate.GetNamePlateForUnit(unit) == plate
                and CaptureDistance(plate, unit) then count = count + 1 end
        end
    end
    addon:Print("Distance: captured " .. count .. " nameplate(s). Total samples: "
        .. #distanceLog .. ". Use /bazidistance status to check saved data.")
end
