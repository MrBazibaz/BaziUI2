-- Player tooltip ilvl, ported from ilvl Forever/PlayerTooltip.lua (Vannx).
-- Original inspect/cache/tooltip lifecycle, with a private BaziUI namespace.
-- No dependency on BaziUI's disabled tooltip implementation.
local function TooltipEnabled()
  local db=BaziUI and BaziUI.db and BaziUI.db.profile and BaziUI.db.profile.tooltip
  return not db or (db.enabled ~= false and db.itemLevel ~= false)
end
local ns = {}
ns.db = { playerTooltip = true }
ns.L = { AVERAGE_ITEM_LEVEL = "Item Level: %s" }
ns.EQUIPMENT_SLOTS = {
  "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot",
  "ShirtSlot","TabardSlot","WristSlot","HandsSlot","WaistSlot",
  "LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
  "Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot"
}
function ns.IsSecret(v)
  return v ~= nil and ((issecretvalue and issecretvalue(v))
    or (canaccessvalue and not canaccessvalue(v)))
end
function ns.UsableNumber(v)
  return not ns.IsSecret(v) and type(v) == "number" and v > 0
end
function ns.CleanLink(v)
  if not ns.IsSecret(v) and type(v) == "string" and v ~= "" then return v end
end
function ns.SlotId(name)
  local ok,id = pcall(GetInventorySlotInfo,name)
  if ok and not ns.IsSecret(id) and type(id) == "number" then return id end
end
function ns.GetEquipLoc(link)
  if not ns.CleanLink(link) then return end
  local getter = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not getter then return end
  local ok,_,_,_,loc = pcall(getter,link)
  if ok and not ns.IsSecret(loc) and type(loc)=="string" then return loc end
end
function ns.GetItemLevel(link)
  if not ns.CleanLink(link) then return end
  local getter = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
  if getter then
    local ok,v = pcall(getter,link)
    if ok and ns.UsableNumber(v) then return math.floor(v+0.5) end
  end
  local getter2 = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getter2 then
    local ok,_,_,_,v = pcall(getter2,link)
    if ok and ns.UsableNumber(v) then return math.floor(v+0.5) end
  end
end
function ns.IsItemLoaded(link)
  local getter = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getter or not ns.CleanLink(link) then return false end
  local ok,v = pcall(getter,link)
  return ok and v ~= nil and not ns.IsSecret(v)
end
function ns.WhenItemLoaded(link,fn)
  if not (Item and Item.CreateFromItemLink and ns.CleanLink(link)) then return end
  local ok,item = pcall(Item.CreateFromItemLink,Item,link)
  if ok and item and not item:IsItemEmpty() then
    item:ContinueOnItemLoad(function() pcall(fn) end)
  end
end
function ns.AverageFromSlots(unit,getLink)
  getLink = getLink or function(id) return ns.CleanLink(GetInventoryItemLink(unit,id)) end
  local total,count=0,0
  for _,name in ipairs(ns.EQUIPMENT_SLOTS) do
    local id=ns.SlotId(name)
    if id and id~=4 and id~=19 then
      count=count+1
      local link=getLink(id)
      local level=link and ns.GetItemLevel(link)
      if level then
        total=total+level
        if id==16 and not getLink(17) and ns.GetEquipLoc(link)=="INVTYPE_2HWEAPON" then
          total=total+level
        end
      end
    end
  end
  if count>0 and total>0 then return total/count end
end
function ns.Debug() end
function ns.Safe(_,fn,...)
  local ok,err=pcall(fn,...)
  if not ok and BaziUI and BaziUI.Print then
    BaziUI:Print("ilvl Forever player tooltip: "..tostring(err))
  end
end
local resetCallbacks={}
function ns.OnTooltipReset(key,fn) resetCallbacks[key]=fn end
function ns.OnLoad(fn) ns._load=fn end

-- Original ilvl Forever PlayerTooltip.lua lifecycle and inspect handling.
local CACHE_TIME=300
-- Short cooldown between completed inspect requests; the pending request
-- guard still prevents overlapping inspect calls.
local REQUEST_GAP=1.5
local REQUEST_TIMEOUT=4
local cache={}
local shared = _G.BaziIlvlShared or {}
_G.BaziIlvlShared = shared
local pending
-- Allow the first inspect immediately, including right after /reload.
local lastRequest=-REQUEST_GAP
local added={}
local function CleanString(value)
  if not ns.IsSecret(value) and type(value)=="string" and value~="" then return value end
end
local function GUIDOf(unit) return CleanString(UnitGUID(unit)) end
local function TooltipUnit(tooltip)
  if not tooltip.GetUnit then return end
  local _,unit=tooltip:GetUnit()
  return CleanString(unit)
end
local function IsPlayer(unit)
  local v=UnitIsPlayer(unit)
  return not ns.IsSecret(v) and v==true
end
local function InspectWindowOpen()
  return InspectFrame~=nil and InspectFrame:IsShown()
end
local function UnitForGUID(guid)
  if UnitTokenFromGUID then
    local unit=CleanString(UnitTokenFromGUID(guid))
    if unit then return unit end
  end
  for _,unit in ipairs({"mouseover","target","focus"}) do
    if GUIDOf(unit)==guid then return unit end
  end
end
local function AddLine(tooltip,guid,value)
  if not TooltipEnabled() then return end
  if added[tooltip]==guid then return end
  added[tooltip]=guid
  local c=NORMAL_FONT_COLOR
  tooltip:AddLine(string.format(ns.L.AVERAGE_ITEM_LEVEL,string.format("|cffffffff%.1f|r",value)),
    c and c.r or 1,c and c.g or 0.82,c and c.b or 0)
end
shared.display = function(guid, value)
  local unit=TooltipUnit(GameTooltip)
  if GameTooltip:IsShown() and unit and GUIDOf(unit)==guid then
    AddLine(GameTooltip,guid,value)
    GameTooltip:Show()
  end
end
local function OwnAverage()
  if not GetAverageItemLevel then return ns.AverageFromSlots("player") end
  local overall,equipped=GetAverageItemLevel()
  if ns.UsableNumber(equipped) then return equipped end
  if ns.UsableNumber(overall) then return overall end
end
local function Store(guid,value)
  cache[guid]={value=value,time=GetTime()}
  shared[guid]=value
  local unit=TooltipUnit(GameTooltip)
  if ns.db.playerTooltip and GameTooltip:IsShown() and unit and GUIDOf(unit)==guid then
    AddLine(GameTooltip,guid,value)
    GameTooltip:Show()
  end
end
local RetryCurrent
local retryScheduled=false
local function RetryLater(wait)
  if retryScheduled or not (C_Timer and C_Timer.After) then return end
  retryScheduled=true
  C_Timer.After(math.max(wait,0.1),function()
    retryScheduled=false
    ns.Safe("player tooltip",RetryCurrent)
  end)
end
local function Request(unit,guid)
  if not TooltipEnabled() then return end
  if not (NotifyInspect and CanInspect) then return end
  if InCombatLockdown() or InspectWindowOpen() then return end
  local now=GetTime()
  if pending and now-pending.time<REQUEST_TIMEOUT then
    RetryLater(pending.time+REQUEST_TIMEOUT-now)
    return
  end
  if now-lastRequest<REQUEST_GAP then
    RetryLater(lastRequest+REQUEST_GAP-now)
    return
  end
  local ok,can=pcall(CanInspect,unit)
  if not ok or ns.IsSecret(can) or not can then return end
  pending={guid=guid,unit=unit,time=now}
  lastRequest=now
  NotifyInspect(unit)
end
function RetryCurrent()
  if not ns.db.playerTooltip or not GameTooltip:IsShown() then return end
  local unit=TooltipUnit(GameTooltip)
  if not unit or not IsPlayer(unit) then return end
  local guid=GUIDOf(unit)
  if not guid or guid==GUIDOf("player") then return end
  local cached=cache[guid]
  if cached and GetTime()-cached.time<CACHE_TIME then return end
  Request(unit,guid)
end
local function AverageFromLinks(links,guid)
  for _,link in pairs(links) do
    if not ns.IsItemLoaded(link) then
      ns.WhenItemLoaded(link,function() AverageFromLinks(links,guid) end)
      return
    end
  end
  local value=ns.AverageFromSlots(nil,function(id) return links[id] end)
  if value then Store(guid,value) end
end
local function OnInspectReady(guid)
  guid=CleanString(guid)
  if not pending or not guid or guid~=pending.guid then return end
  pending=nil
  local unit=UnitForGUID(guid)
  if unit then
    local value
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
      local ok,result=pcall(C_PaperDollInfo.GetInspectItemLevel,unit)
      if ok and ns.UsableNumber(result) then value=result end
    end
    if value then
      Store(guid,value)
    else
      local links={}
      for _,name in ipairs(ns.EQUIPMENT_SLOTS) do
        local id=ns.SlotId(name)
        if id then links[id]=ns.CleanLink(GetInventoryItemLink(unit,id)) end
      end
      AverageFromLinks(links,guid)
    end
  end
  if ClearInspectPlayer and not InspectWindowOpen() then ClearInspectPlayer() end
end
ns.OnTooltipReset("player tooltip",function(tooltip) added[tooltip]=nil end)
local function OnUnit(tooltip,data)
  if not TooltipEnabled() then return end
  if not ns.db.playerTooltip then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  local unit=TooltipUnit(tooltip)
  if not unit or not IsPlayer(unit) then return end
  local guid=CleanString(data and data.guid) or GUIDOf(unit)
  if not guid then return end
  local value
  if guid==GUIDOf("player") then
    value=OwnAverage()
  else
    local cached=cache[guid]
    if shared[guid] then value=shared[guid]
    elseif cached and GetTime()-cached.time<CACHE_TIME then
      value=cached.value
    else
      Request(unit,guid)
    end
  end
  if value then AddLine(tooltip,guid,value) end
end
local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,_,guid)
  ns.Safe("player tooltip",OnInspectReady,guid)
end)
ns.OnLoad(function()
  if not (TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit) then return end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(tooltip,data)
    ns.Safe("player tooltip",OnUnit,tooltip,data)
  end)
  events:RegisterEvent("INSPECT_READY")
end)
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPreCall
    and TooltipDataProcessor.AllTypes then
  TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes,function(tooltip)
    for tag,fn in pairs(resetCallbacks) do ns.Safe(tag,fn,tooltip) end
  end)
end
ns._load()
