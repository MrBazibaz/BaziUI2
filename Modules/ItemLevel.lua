-- Bazi UI item-level integration, adapted from ilvl Forever's inspect workflow.
-- Uses our own labels and no third-party artwork.
local addon = BaziUI
addon.ItemLevel = addon.ItemLevel or {}
local M = addon.ItemLevel
local slots = {"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot",
    "WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot",
    "Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot",
    "MainHandSlot","SecondaryHandSlot","RangedSlot"}
local cache, pending, lastRequest = {}, nil, -10
local retryScheduled = false
local added = {}
local labels, averageLabel = {}, nil
local REQUEST_GAP, REQUEST_TIMEOUT, CACHE_TIME = 1.5, 4, 300
local eventFrame = CreateFrame("Frame")
local function usable(v)
    return v ~= nil and (not issecretvalue or not issecretvalue(v))
        and (not canaccessvalue or canaccessvalue(v))
end
local function number(v)
    return usable(v) and type(v) == "number"
end
local function stringValue(v)
    return usable(v) and type(v) == "string" and v ~= ""
end
local function settings()
    return addon.db and addon.db.profile
end
local function tooltipEnabled()
    local p = settings()
    return p and p.tooltip and p.tooltip.enabled and p.tooltip.itemLevel
end
local function characterEnabled()
    local p = settings()
    return p and p.qol and p.qol.characterItemLevel
end
local function getLevel(link)
    if not stringValue(link) then return end
    local getter = GetDetailedItemLevelInfo or (C_Item and C_Item.GetDetailedItemLevelInfo)
    if not getter then return end
    local ok, level = pcall(getter, link)
    if ok and number(level) and level > 0 then return level end
end
local function ownAverage()
    if not GetAverageItemLevel then return end
    local ok, overall, equipped = pcall(GetAverageItemLevel)
    if ok then
        if number(equipped) and equipped > 0 then return equipped end
        if number(overall) and overall > 0 then return overall end
    end
end
local function guidOf(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and stringValue(guid) then return guid end
end
local function tooltipUnit()
    local _, unit = GameTooltip:GetUnit()
    return stringValue(unit) and unit or nil
end
local function hasLevelLine()
    for i = 2, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if stringValue(value) and value:find("Item Level:", 1, true) then return true end
    end
end
local function addLevel(guid, level)
    if not tooltipEnabled() or not number(level) then return end
    local unit = tooltipUnit()
    if not unit or guidOf(unit) ~= guid or added[GameTooltip] == guid then return end
    if hasLevelLine() then added[GameTooltip] = guid; return end
    GameTooltip:AddLine(string.format("Item Level: %.1f", level), 1, 0.79, 0.43)
    added[GameTooltip] = guid
end
function M:ResetTooltipRow(frame)
    added[frame or GameTooltip] = nil
end
local function inspectOpen()
    return InspectFrame and InspectFrame:IsShown()
end
local function findUnit(guid)
    if UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and stringValue(unit) then return unit end
    end
    for _, unit in ipairs({"mouseover","target","focus"}) do
        if guidOf(unit) == guid then return unit end
    end
end
local function averageFromInspect(unit)
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, level = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and number(level) and level > 0 then return level end
    end
    -- Fallback: average equipped items, excluding shirt and tabard.
    local total, count = 0, 0
    for _, name in ipairs(slots) do
        local id = GetInventorySlotInfo(name)
        if number(id) then
            local ok, link = pcall(GetInventoryItemLink, unit, id)
            local level = ok and getLevel(link)
            if level then total, count = total + level, count + 1 end
        end
    end
    -- Do not show a misleading average when inspect inventory is incomplete.
    if count >= 8 then return total / count end
end
local function request(unit, guid)
    if not NotifyInspect or not CanInspect or InCombatLockdown() or inspectOpen() then return end
    local now = GetTime()
    local wait
    if pending and now - pending.time < REQUEST_TIMEOUT then
        wait = pending.time + REQUEST_TIMEOUT - now
    elseif now - lastRequest < REQUEST_GAP then
        wait = lastRequest + REQUEST_GAP - now
    end
    if wait then
        if not retryScheduled and C_Timer and C_Timer.After then
            retryScheduled = true
            C_Timer.After(math.max(wait, 0.1), function()
                retryScheduled = false
                if tooltipEnabled() and GameTooltip:IsShown() then M:OnUnit() end
            end)
        end
        return
    end
    local ok, can = pcall(CanInspect, unit)
    if not ok or not usable(can) or not can then return end
    pending = {guid=guid,time=now}
    lastRequest = now
    local sent = pcall(NotifyInspect, unit)
    if not sent then pending = nil end
end
function M:OnUnit()
    if not tooltipEnabled() then return end
    local unit = tooltipUnit()
    if not unit then return end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or not usable(isPlayer) or not isPlayer then return end
    local guid = guidOf(unit)
    if not guid then return end
    if guid == guidOf("player") then
        addLevel(guid, ownAverage())
    else
        local entry = cache[guid]
        if entry and GetTime() - entry.time < CACHE_TIME then
            addLevel(guid, entry.value)
        else
            request(unit, guid)
        end
    end
end
local function onInspectReady(guid)
    if not pending or not stringValue(guid) or pending.guid ~= guid then return end
    pending = nil
    local unit = findUnit(guid)
    if unit then
        local level = averageFromInspect(unit)
        if number(level) then
            cache[guid] = {value=level,time=GetTime()}
            -- Do not append text to an already-laid-out tooltip. Ask
            -- Blizzard to rebuild through the same post-call used by cache hits.
            if GameTooltip:IsShown() and tooltipUnit()
                and guidOf(tooltipUnit()) == guid and GameTooltip.RefreshData then
                pcall(GameTooltip.RefreshData, GameTooltip)
            end
        end
    end
    if ClearInspectPlayer and not inspectOpen() then pcall(ClearInspectPlayer) end
end
local function createCharacterLabels()
    if not PaperDollFrame then return end
    for _, name in ipairs(slots) do
        if not labels[name] then
            local button = _G["Character"..name]
            if button then
                local holder = CreateFrame("Frame", nil, button)
                holder:SetAllPoints(button)
                holder:SetFrameLevel(button:GetFrameLevel()+2)
                local label = holder:CreateFontString(nil,"OVERLAY","NumberFontNormal")
                label:SetPoint("TOPRIGHT", -2, -2)
                label:Hide()
                labels[name] = label
            end
        end
    end
    if not averageLabel and CharacterLevelText then
        local parent = CharacterLevelText:GetParent() or PaperDollFrame
        local holder = CreateFrame("Frame",nil,parent)
        holder:SetAllPoints(parent)
        holder:SetFrameLevel(parent:GetFrameLevel()+10)
        averageLabel = holder:CreateFontString(nil,"OVERLAY","GameFontNormal")
        averageLabel:SetPoint("LEFT",CharacterLevelText,"RIGHT",8,0)
        averageLabel:Hide()
    end
end
function M:RefreshCharacter()
    createCharacterLabels()
    local enabled = characterEnabled()
    for name,label in pairs(labels) do
        local level
        if enabled then
            local id = GetInventorySlotInfo(name)
            if number(id) then
                local ok,link = pcall(GetInventoryItemLink,"player",id)
                if ok then level=getLevel(link) end
            end
        end
        if level then
            label:SetText(math.floor(level+0.5))
            label:SetTextColor(1,0.82,0.48)
            label:Show()
        else
            label:Hide()
        end
    end
    if averageLabel then
        local value = enabled and ownAverage()
        if value then
            averageLabel:SetText(string.format("ilvl %.1f",value))
            averageLabel:SetTextColor(1,0.79,0.43)
            averageLabel:Show()
        else
            averageLabel:Hide()
        end
    end
end
function M:Initialize()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPreCall
        and TooltipDataProcessor.AllTypes then
        TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes,
            function(frame) if frame == GameTooltip then M:ResetTooltipRow(frame) end end)
    end
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    pcall(eventFrame.RegisterEvent,eventFrame,"PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:SetScript("OnEvent",function(_,event,guid)
        if event=="INSPECT_READY" then onInspectReady(guid)
        else M:RefreshCharacter() end
    end)
    if PaperDollFrame_SetLevel then
        hooksecurefunc("PaperDollFrame_SetLevel",function() M:RefreshCharacter() end)
    end
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow",function() M:RefreshCharacter() end)
    end
end
