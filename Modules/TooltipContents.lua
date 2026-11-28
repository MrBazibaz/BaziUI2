-- Bazi UI tooltip Contents: independent of ilvl and health-bar engines.
local addon = BaziUI
local tip = GameTooltip
local sellPriceType, unitThreatType
local function DB()
    local p = addon.db and addon.db.profile
    local db = p and p.tooltip
    return db and db.enabled and db
end
local function safe(v)
    return v ~= nil and (not issecretvalue or not issecretvalue(v))
        and (not canaccessvalue or canaccessvalue(v))
end
local function text(v)
    return safe(v) and type(v) == "string" and v ~= "" and v
end
local function unitOf(frame)
    local ok, _, unit = pcall(frame.GetUnit, frame)
    return ok and text(unit) and unit or nil
end
local function findLine(frame, needle)
    for i = 1, frame:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local s = fs and fs:GetText()
        if text(s) and s:find(needle, 1, true) then return true end
    end
end
local function removeMatching(frame, value, prefix)
    if not text(value) then return end
    for i = 2, frame:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local s = fs and fs:GetText()
        if text(s) and (s == value or prefix and s:sub(1, #value) == value) then fs:SetText(nil) end
    end
end

local function isPlayerUnit(unit)
    local player = UnitIsPlayer(unit)
    return safe(player) and player == true
end

local function unitTargetName(db, unit)
    return db.targetTarget and text(UnitName(unit .. "target"))
end

local function hasThreatLine(data)
    if not unitThreatType or not safe(data) or not safe(data.lines) then return false end
    for _, line in ipairs(data.lines) do
        if safe(line) and safe(line.type) and line.type == unitThreatType then return true end
    end
end

-- The item-level provider uses the same rule as the player tooltip.
function addon.TooltipUsesCompactUnitView(frame, unit)
    local db = DB()
    if not db or frame ~= tip or db.smart == false or IsShiftKeyDown() then return false end
    unit = unit or unitOf(frame)
    return unit and isPlayerUnit(unit) or false
end

local function unitContents(frame, data)
    local db = DB()
    if not db or frame ~= tip or (frame.IsForbidden and frame:IsForbidden()) then return end
    local unit = unitOf(frame)
    if not unit then return end
    local isPlayer = isPlayerUnit(unit)
    local targetName = unitTargetName(db, unit)
    local faction = isPlayer and not db.hideFaction and UnitFactionGroup(unit)
    local compact = db.smart ~= false and not IsShiftKeyDown()
        and (isPlayer or targetName and db.threat ~= false and hasThreatLine(data))
    if compact or db.guild == false then
        local ok, name = pcall(GetGuildInfo, unit)
        local guild = ok and name or nil
        if text(guild) then
            removeMatching(frame, guild)
            removeMatching(frame, "<" .. guild .. ">")
        end
    end
    if compact or db.hideFaction then
        removeMatching(frame, _G.FACTION_ALLIANCE)
        removeMatching(frame, _G.FACTION_HORDE)
    end
    if isPlayer then
        local className, class = UnitClass(unit)
        local title = _G.GameTooltipTextLeft1
        local color = text(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if db.classNames and color and title then title:SetTextColor(color.r, color.g, color.b) end
        local level, race = UnitLevel(unit), UnitRace(unit)
        local levelPrefix = (TOOLTIP_UNIT_LEVEL or "Level %s"):match("^(.-)%%") or "Level "
        if safe(level) and type(level) == "number" and level > 0 and text(race) and text(className) then
            for i = 2, frame:NumLines() do
                local row = _G["GameTooltipTextLeft" .. i]
                local current = row and row:GetText()
                if text(current) and (current:sub(1, #levelPrefix) == levelPrefix or current:find("(Player)", 1, true)) then
                    local classColor = color and color.colorStr
                    row:SetText(race .. "  ·  " .. (classColor and "|c" .. classColor .. className .. "|r" or className))
                    row:SetTextColor(0.84, 0.77, 0.67)
                    local levelLabel = _G["GameTooltipTextRight1"]
                    if levelLabel then
                        levelLabel:SetText(tostring(level))
                        levelLabel:SetTextColor(0.91, 0.74, 0.49)
                        levelLabel:Show()
                    end
                    removeMatching(frame, className)
                    break
                end
            end
        end
        if not compact and db.smart ~= false and not db.hideFaction then
            if text(faction) and not findLine(frame, faction) then
                frame:AddDoubleLine("Faction", faction, 0.87, 0.71, 0.50, 0.93, 0.88, 0.79)
            end
        elseif compact then
            removeMatching(frame, "Item Level", true)
            removeMatching(frame, PVP or "PvP")
        end
    elseif UnitClassification then
        local rare = addon.GetRareClassificationLabel(UnitClassification(unit))
        if rare then frame:AddLine(rare, 0.80, 0.86, 0.94) end
    end
    local targetPrefix = (_G.TARGET or "Target") .. ": "
    if compact then
        removeMatching(frame, targetPrefix, true)
        frame:AddLine("Shift for details", 0.83, 0.77, 0.67)
        addon.TooltipFonts.StyleDetailHint(_G["GameTooltipTextLeft" .. frame:NumLines()], db)
    end
    if not compact and targetName then
        if not findLine(frame, targetPrefix) then frame:AddLine(targetPrefix .. targetName, 0.95, 0.80, 0.5) end
    end
    addon.TooltipFonts.Apply()
end

local function idLine(frame, label, id)
    local db = DB()
    if not db or not db.ids or frame ~= tip then return end
    if not safe(id) or type(id) ~= "number" then return end
    if not findLine(frame, label) then
        frame:AddDoubleLine(label, tostring(id), 1, 0.79, 0.43, 1, 1, 1)
    end
end
local function thirdPartyVendor()
    local auction = _G.Auctionator
    local config = auction and auction.Config
    local key = config and config.Options and config.Options.VENDOR_TOOLTIPS
    return key and config.Get and config.Get(key)
end

local function validSellPrice(value)
    return safe(value) and type(value) == "number" and value > 0
end

local function itemContents(frame, data)
    if frame ~= tip or not DB() then return end
    local id = data and data.id
    if not safe(id) or type(id) ~= "number" then
        local ok, _, link = pcall(frame.GetItem, frame)
        if ok and text(link) then id = tonumber(link:match("item:(%d+)")) end
    end
    idLine(frame, "Item ID", id)
    if sellPriceType and not thirdPartyVendor() and not findLine(frame, "Vendor") and data and data.lines then
        for _, line in ipairs(data.lines) do
            if line.type == sellPriceType and validSellPrice(line.price) and not line.maxPrice then
                local money = addon.Inventory and addon.Inventory.Money
                if money then frame:AddDoubleLine("Vendor", money(line.price), 0.87, 0.71, 0.50, 1, 1, 1) end
                break
            end
        end
    end
    if safe(id) and type(id) == "number" and addon.Inventory and addon.Inventory.IsCleanupProtected
        and addon.Inventory.IsCleanupProtected(id) and not findLine(frame, "Protected from Cleanup") then
        frame:AddLine("Protected from Cleanup", addon.Theme:Accent())
    end
    if addon.AltManager and safe(id) and type(id) == "number" then
        addon.AltManager.AddTooltip(frame, id)
        -- Native modifier-driven tooltip rebuilds also need the bag upgrade details.
        local owner = frame.GetOwner and frame:GetOwner()
        local entries = owner and owner.altRecommendations
        if entries and #entries > 0 and IsShiftKeyDown() and not findLine(frame, "Alt Gear Upgrades") then
            frame:AddLine("Alt Gear Upgrades", 0.3, 0.65, 1)
            for _, entry in ipairs(entries) do
                local meta = entry.identity
                local color = RAID_CLASS_COLORS[meta.token]
                frame:AddLine(("%s - Level %d (%s)"):format(meta.name, meta.level, BaziUI.LootUpgrades.AltProfileLabel(meta, entry.profile)),
                    color and color.r or 1, color and color.g or 1, color and color.b or 1)
            end
        end
    end
end
local function spellContents(frame, data)
    idLine(frame, "Spell ID", data and data.id)
end
local function removeDuplicateVendor(frame)
    if frame ~= tip or not DB() then return end
    local label = (SELL_PRICE or "Sell Price"):match("^[^:]+")
    removeMatching(frame, label, true)
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        local name = child:GetName()
        if name and name:match("^GameTooltipMoneyFrame%d+$") then
            local prefix = child.PrefixText or _G[name .. "PrefixText"]
            local value = prefix and prefix.GetText and prefix:GetText()
            if text(value) and value:sub(1, #label) == label then child:Hide() end
        end
    end
end

local function hookAuctionVendor()
    local auction = _G.Auctionator
    local pricing = auction and auction.Tooltip
    if pricing and pricing.AddVendorTip and not pricing.baziVendorStyled then
        hooksecurefunc(pricing, "AddVendorTip", removeDuplicateVendor)
        pricing.baziVendorStyled = true
    end
end

local function init()
    hookAuctionVendor()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType) then return end
    local types = Enum.TooltipDataType
    local lineTypes = Enum.TooltipDataLineType
    if TooltipDataProcessor.AddLinePreCall and lineTypes and lineTypes.SellPrice then
        sellPriceType = lineTypes.SellPrice
        TooltipDataProcessor.AddLinePreCall(sellPriceType, function(frame, line)
            if frame == tip and DB() and validSellPrice(line.price) and not line.maxPrice then return true end
        end)
    end
    local add = TooltipDataProcessor.AddTooltipPostCall
    if types.Unit then add(types.Unit, unitContents) end
    if types.Item then add(types.Item, itemContents) end
    if types.Spell then add(types.Spell, spellContents) end
    if types.UnitAura then add(types.UnitAura, spellContents) end
    -- Blizzard threat lines can be filtered before they are laid out.
    unitThreatType = lineTypes and lineTypes.UnitThreat
    if TooltipDataProcessor.AddLinePreCall and unitThreatType then
        TooltipDataProcessor.AddLinePreCall(unitThreatType, function(frame)
            local db = DB()
            if not db or frame ~= tip then return end
            if db.threat == false then return true end
            if db.smart == false or IsShiftKeyDown() then return end
            local unit = unitOf(frame)
            if unit and not isPlayerUnit(unit) and unitTargetName(db, unit) then return true end
        end)
    end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        init()
    elseif name == "Auctionator" then
        hookAuctionVendor()
        self:UnregisterEvent(event)
    end
end)
