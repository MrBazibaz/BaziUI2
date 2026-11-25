-- Bazi UI: standalone player tooltip item level.
-- Port of ilvl Forever PlayerTooltip.lua's lifecycle and inspect algorithm.
-- No dependency on Bazi UI's old tooltip engine or health bar.
local function TooltipEnabled()
  local db=BaziUI and BaziUI.db and BaziUI.db.profile and BaziUI.db.profile.tooltip
  return not db or (db.enabled ~= false and db.itemLevel ~= false)
end
local addon = BaziUI
local shared = _G.BaziIlvlShared or {}
_G.BaziIlvlShared = shared
local CACHE_TIME, REQUEST_GAP, REQUEST_TIMEOUT = 300, 1.5, 4
local cache, pending, lastRequest, added = {}, nil, 0, {}
local retryScheduled = false
local slots = {
    "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot",
    "ShirtSlot","TabardSlot","WristSlot","HandsSlot","WaistSlot",
    "LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
    "Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot",
}
local function secret(v)
    return issecretvalue and issecretvalue(v)
end
local function clean(v)
    if not secret(v) and type(v) == "string" and v ~= "" then return v end
end
local function num(v)
    return not secret(v) and type(v) == "number" and v > 0
end
local function guidOf(unit)
    return clean(UnitGUID(unit))
end
local function tooltipUnit(tooltip)
    if not tooltip.GetUnit then return end
    local _, unit = tooltip:GetUnit()
    return clean(unit)
end
local function player(unit)
    local v = UnitIsPlayer(unit)
    return not secret(v) and v == true
end
local function inspectOpen()
    return InspectFrame and InspectFrame:IsShown()
end
local function unitForGUID(guid)
    if UnitTokenFromGUID then
        local unit = clean(UnitTokenFromGUID(guid))
        if unit then return unit end
    end
    for _,unit in ipairs({"mouseover","target","focus"}) do
        if guidOf(unit) == guid then return unit end
    end
end
local function slotId(name)
    local ok, id = pcall(GetInventorySlotInfo, name)
    if ok and num(id) then return id end
end
local function itemLevel(link)
    if not clean(link) then return end
    local getter = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if getter then
        local ok, level = pcall(getter, link)
        if ok and num(level) then return math.floor(level + 0.5) end
    end
    local getterInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getterInfo then
        local ok, _, _, _, level = pcall(getterInfo, link)
        if ok and num(level) then return math.floor(level + 0.5) end
    end
end
local function equipLoc(link)
    local getter = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getter or not clean(link) then return end
    local ok, _, _, _, loc = pcall(getter, link)
    if ok and not secret(loc) then return loc end
end
local function averageFromSlots(unit, getLink)
    getLink = getLink or function(id)
        return clean(GetInventoryItemLink(unit, id))
    end
    local total, count = 0, 0
    for _,name in ipairs(slots) do
        local id = slotId(name)
        if id and id ~= 4 and id ~= 19 then
            count = count + 1
            local link = getLink(id)
            local level = link and itemLevel(link)
            if level then
                total = total + level
                if id == 16 and not getLink(17) and equipLoc(link) == "INVTYPE_2HWEAPON" then
                    total = total + level
                end
            end
        end
    end
    if count > 0 and total > 0 then return total / count end
end
local function ownAverage()
    if GetAverageItemLevel then
        local ok, overall, equipped = pcall(GetAverageItemLevel)
        if ok then
            if num(equipped) then return equipped end
            if num(overall) then return overall end
        end
    end
    return averageFromSlots("player")
end
local function addLine(tooltip, guid, value)
    if added[tooltip] == guid then return end
    added[tooltip] = guid
    local color = NORMAL_FONT_COLOR
    tooltip:AddLine(string.format("ilvl |cffffffff%.1f|r", value),
        color and color.r or 1, color and color.g or 0.82, color and color.b or 0)
    if addon.TooltipFonts then addon.TooltipFonts.Apply() end
end
local function store(guid, value)
    if not TooltipEnabled() then return end
    cache[guid] = {value=value,time=GetTime()}
    shared[guid] = value
    if shared.display then shared.display(guid, value) end
    local unit = tooltipUnit(GameTooltip)
    if GameTooltip:IsShown() and unit and guidOf(unit) == guid then
        -- The original port owns the only visible line.
    end
end
local function whenLoaded(link, callback)
    if not Item or not Item.CreateFromItemLink then return end
    local item = Item:CreateFromItemLink(link)
    if item and not item:IsItemEmpty() then
        item:ContinueOnItemLoad(callback)
    end
end
local function loaded(link)
    local getter = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getter or not clean(link) then return false end
    local ok, name = pcall(getter, link)
    return ok and not secret(name) and name ~= nil
end
local function averageFromLinks(links, guid)
    for _,link in pairs(links) do
        if not loaded(link) then
            whenLoaded(link, function() averageFromLinks(links, guid) end)
            return
        end
    end
    local value = averageFromSlots(nil, function(id) return links[id] end)
    if value then store(guid, value) end
end
local retryCurrent
local function retryLater(wait)
    if retryScheduled or not (C_Timer and C_Timer.After) then return end
    retryScheduled = true
    C_Timer.After(math.max(wait, 0.1), function()
        retryScheduled = false
        local ok, err = pcall(retryCurrent)
        if not ok and addon.Print then addon:Print("ilvl retry: " .. tostring(err)) end
    end)
end
local function request(unit, guid)
    if not TooltipEnabled() then return end
    if not (NotifyInspect and CanInspect) or InCombatLockdown() or inspectOpen() then return end
    local now = GetTime()
    if pending and now - pending.time < REQUEST_TIMEOUT then
        retryLater(pending.time + REQUEST_TIMEOUT - now)
        return
    end
    if now - lastRequest < REQUEST_GAP then
        retryLater(lastRequest + REQUEST_GAP - now)
        return
    end
    local ok, can = pcall(CanInspect, unit)
    if not ok or secret(can) or not can then return end
    pending = {guid=guid,unit=unit,time=now}
    lastRequest = now
    NotifyInspect(unit)
end
retryCurrent = function()
    if not GameTooltip:IsShown() then return end
    local unit = tooltipUnit(GameTooltip)
    if not unit or not player(unit) then return end
    local guid = guidOf(unit)
    if not guid or guid == guidOf("player") then return end
    local cached = cache[guid]
    if cached and GetTime() - cached.time < CACHE_TIME then return end
    request(unit, guid)
end
local function inspectReady(guid)
    guid = clean(guid)
    if not pending or not guid or pending.guid ~= guid then return end
    pending = nil
    local unit = unitForGUID(guid)
    if unit then
        local value
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            local ok, result = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
            if ok and num(result) then value = result end
        end
        if value then
            store(guid, value)
        else
            local links = {}
            for _,name in ipairs(slots) do
                local id = slotId(name)
                if id then links[id] = clean(GetInventoryItemLink(unit, id)) end
            end
            averageFromLinks(links, guid)
        end
    end
    if ClearInspectPlayer and not inspectOpen() then ClearInspectPlayer() end
end
local function onUnit(tooltip, data)
    if not TooltipEnabled() then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    local unit = tooltipUnit(tooltip)
    if not unit or not player(unit) then return end
    local guid = clean(data and data.guid) or guidOf(unit)
    if not guid then return end
    local value
    if guid == guidOf("player") then
        value = ownAverage()
    else
        local cached = cache[guid]
        if cached and GetTime() - cached.time < CACHE_TIME then
            value = cached.value
        else
            request(unit, guid)
        end
    end
    if value then
        shared[guid] = value
        -- This worker supplies cached values; the original port renders.
    end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPreCall and TooltipDataProcessor.AllTypes then
    TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes, function(tooltip)
        added[tooltip] = nil
    end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("INSPECT_READY")
events:SetScript("OnEvent", function(_, _, guid)
    local ok, err = pcall(inspectReady, guid)
    if not ok and addon.Print then addon:Print("ilvl inspect: " .. tostring(err)) end
end)
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if TooltipDataProcessor and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            local ok, err = pcall(onUnit, tooltip, data)
            if not ok and addon.Print then addon:Print("ilvl tooltip: " .. tostring(err)) end
        end)
    end
end)
