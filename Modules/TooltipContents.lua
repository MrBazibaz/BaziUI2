-- Bazi UI tooltip Contents: independent of ilvl and health-bar engines.
local addon = BaziUI
local tip = GameTooltip
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
local function removeMatching(frame, value)
    if not text(value) then return end
    for i = 2, frame:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local s = fs and fs:GetText()
        if text(s) and s == value then fs:SetText("") end
    end
end
local function unitContents(frame)
    local db = DB()
    if not db or frame ~= tip then return end
    local unit = unitOf(frame)
    if not unit then return end
    if db.guild == false then
        local ok, guild = pcall(GetGuildInfo, unit)
        if ok and text(guild) then
            removeMatching(frame, guild)
            removeMatching(frame, "<" .. guild .. ">")
        end
    end
    if db.hideFaction then
        removeMatching(frame, _G.FACTION_ALLIANCE)
        removeMatching(frame, _G.FACTION_HORDE)
    end
    if db.classNames then
        local ok, player = pcall(UnitIsPlayer, unit)
        if ok and safe(player) and player then
            local classOK, _, class = pcall(UnitClass, unit)
            local color = classOK and text(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            local title = _G.GameTooltipTextLeft1
            if color and title then title:SetTextColor(color.r, color.g, color.b) end
        end
    end
    if db.targetTarget then
        local target = unit .. "target"
        local ok, exists = pcall(UnitExists, target)
        if ok and safe(exists) and exists then
            local nameOK, name = pcall(UnitName, target)
            local prefix = (_G.TARGET or "Target") .. ": "
            if nameOK and text(name) and not findLine(frame, prefix) then
                frame:AddLine(prefix .. name, 0.95, 0.80, 0.5)
            end
        end
    end
end
local function idLine(frame, label, id)
    local db = DB()
    if not db or not db.ids or frame ~= tip then return end
    if not safe(id) or type(id) ~= "number" then return end
    if not findLine(frame, label) then
        frame:AddDoubleLine(label, tostring(id), 1, 0.79, 0.43, 1, 1, 1)
    end
end
local function itemContents(frame, data)
    local id = data and data.id
    if not safe(id) or type(id) ~= "number" then
        local ok, _, link = pcall(frame.GetItem, frame)
        if ok and text(link) then id = tonumber(link:match("item:(%d+)")) end
    end
    idLine(frame, "Item ID", id)
    if frame == tip and DB() and addon.AltManager and safe(id) and type(id) == "number" then
        addon.AltManager.AddTooltip(frame, id)
        local ok, _, link = pcall(frame.GetItem, frame)
        addon.EquipmentAdvisor.AddTooltip(frame, ok and text(link) and link or id)
    end
end
local function spellContents(frame, data)
    idLine(frame, "Spell ID", data and data.id)
end
local function init()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType) then return end
    local types = Enum.TooltipDataType
    local add = TooltipDataProcessor.AddTooltipPostCall
    if types.Unit then add(types.Unit, unitContents) end
    if types.Item then add(types.Item, itemContents) end
    if types.Spell then add(types.Spell, spellContents) end
    if types.UnitAura then add(types.UnitAura, spellContents) end
    -- Blizzard threat lines can be filtered before they are laid out.
    if TooltipDataProcessor.AddLinePreCall and Enum.TooltipDataLineType
        and Enum.TooltipDataLineType.UnitThreat then
        TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.UnitThreat, function()
            local db = DB()
            if db and db.threat == false then return true end
        end)
    end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    init()
end)
