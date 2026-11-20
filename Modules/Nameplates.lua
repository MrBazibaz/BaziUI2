-- Friendly player nameplate icons. Based on MiniMarkers' nameplate event,
-- unit classification and role/class icon selection patterns.
-- Runtime is isolated; no Blizzard nameplate frame or UnitFrames code is replaced.
local addon = BaziUI
addon.Nameplates = addon.Nameplates or {}
local M = addon.Nameplates
local active = {}
local plateUnits = {} -- NAME_PLATE_UNIT_ADDED is the reliable source of unit tokens.
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
    -- Match the full-size Dungeon Finder role portraits in PartyFrames.lua,
    -- not the low-resolution UI-LFG-ICON-PORTRAITROLES indicator sheet.
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then
        return false
    end
    local atlas
    if type(GetIconForRole) == "function" then
        local ok, value = pcall(GetIconForRole, role, false)
        if ok and type(value) == "string" then atlas = value end
    end
    if not atlas then
        local known = {
            TANK = "UI-LFG-RoleIcon-Tank",
            HEALER = "UI-LFG-RoleIcon-Healer",
            DAMAGER = "UI-LFG-RoleIcon-DPS",
        }
        atlas = known[role]
    end
    if type(GetAtlasInfo) == "function" then
        local ok, info = pcall(GetAtlasInfo, atlas)
        if not ok or not info then return false end
    end
    if not icon.SetAtlas then return false end
    local ok = pcall(icon.SetAtlas, icon, atlas, false)
    if not ok then return false end
    -- The Dungeon Finder artwork includes its own thick rim and four corner
    -- shadows. Crop those away so Bazi's existing portrait rim can be reused.
    -- Atlas UVs are texture-sheet coordinates, NOT always 0..1.
    local info
    if C_Texture and C_Texture.GetAtlasInfo then
        info = C_Texture.GetAtlasInfo(atlas)
    elseif type(GetAtlasInfo) == "function" then
        info = GetAtlasInfo(atlas)
    end
    if info and info.leftTexCoord and info.rightTexCoord
        and info.topTexCoord and info.bottomTexCoord then
        local inset = 0.18
        local l, r = info.leftTexCoord, info.rightTexCoord
        local t, b = info.topTexCoord, info.bottomTexCoord
        icon:SetTexCoord(l + (r-l)*inset, r - (r-l)*inset,
            t + (b-t)*inset, b - (b-t)*inset)
    end
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
        if frame and frame.SetAlpha then frame:SetAlpha(original) end
        hiddenUnitFrames[plate] = nil
    end
end

local function HidePlate(plate)
    RestoreUnitFrame(plate)
    local marker = active[plate]
    if marker then
        marker:Hide()
        if marker.textAnchor then marker.textAnchor:Hide() end
    end
    RestoreName(plate)
end

local function UpdatePlate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    plateUnits[plate] = unit
    local cfg = Config()
    if not cfg or not cfg.enabled or cfg.friendlyIcon == "off" or not Friendly(unit) then
        HidePlate(plate)
        return
    end

    -- Scope filters icons only. Keep the configured name/guild styling
    -- on every friendly player regardless of group membership.
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
    -- Restore original artwork size and center both artwork and mask.
    -- Dungeon Finder role atlases already contain their own circular gold rim.
    -- Draw them at the same outer diameter and center as class icons, without
    -- stacking Bazi's separate rim on top of the embedded role rim.
    local rolePortrait = iconMode == "role" and valid
    -- Both icon modes now share the same artwork size, mask and gold rim.
    marker.icon:SetSize(iconSize * 0.95, iconSize * 0.95)
    marker.iconMask:SetSize(iconSize * 0.95, iconSize * 0.95)
    marker.rim:SetSize(rimSize, rimSize)
    marker.rimMask:SetSize(rimSize, rimSize)
    marker.rim:Show()
    -- Keep the approved single-layer appearance. The user selected size 20.
    -- FontString text inherits the nameplate's frame transforms.
    for _, label in ipairs({marker.name, marker.guild}) do
        local font = UNIT_NAME_FONT
        local ok, applied = pcall(label.SetFont, label, font, cfg.friendlyTextSize or 20, "")
        if not ok or applied == false then
            local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
            if fallback then pcall(label.SetFont, label, fallback, cfg.friendlyTextSize or 20, "") end
        end
        label:SetTextColor(115 / 255, 115 / 255, 217 / 255, 1)
        label:SetShadowColor(0, 0, 0, 0.35)
        label:SetShadowOffset(0, 0)
    end
    PositionFriendlyText(plate, marker, cfg)
    marker.name:ClearAllPoints()
    marker.name:SetPoint("TOP", marker.textAnchor, "TOP", 0, 0)
    marker.guild:ClearAllPoints()
    marker.guild:SetPoint("TOP", marker.name, "BOTTOM", 0, 0)
    local displayName = UnitName(unit)
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

function M:Apply()
    local cfg = Config()
    if not cfg or not cfg.enabled then
        for plate in pairs(active) do HidePlate(plate) end
        for plate in pairs(styledNames) do RestoreName(plate) end
        for plate in pairs(hiddenUnitFrames) do RestoreUnitFrame(plate) end
        return
    end
    -- A nameplate frame does not reliably expose namePlateUnitToken on this
    -- client. Retain the token from NAME_PLATE_UNIT_ADDED instead of hiding
    -- existing markers whenever a setting changes.
    for plate, unit in pairs(plateUnits) do
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit) == plate then
            UpdatePlate(unit)
        else
            plateUnits[plate] = nil
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
                if plate then
                    plateUnits[plate] = nil
                    HidePlate(plate)
                end
            end
        else
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
    -- Sampling intentionally stays silent; /bazidistance status shows totals.
end
