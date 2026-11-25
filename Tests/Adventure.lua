local loadProject = LOAD_PROJECT or dofile
unpack = unpack or table.unpack
local now, server, bankOpen, combat, shift = 100, 1762000000, false, false, true
local timers, notices = {}, {}
local frame
local function noop() end
local handlers = {}
local index = {__index = function(_, key) return handlers[key] or noop end}
frame = function(_, _, parent)
    return setmetatable({shown = true, scripts = {}, hooks = {}, width = 500, height = 200,
        parent = type(parent) == "table" and parent or false, scale = 1}, index)
end
function handlers:SetScript(key, fn) self.scripts[key] = fn end
function handlers:HookScript(key, fn)
    self.hooks[key] = self.hooks[key] or {}
    self.hooks[key][#self.hooks[key] + 1] = fn
end
function handlers:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
    for _, fn in ipairs(self.hooks.OnShow or {}) do fn(self) end
end
function handlers:Hide() self.shown = false end
function handlers:IsShown() return self.shown end
function handlers:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function handlers:SetShown(value) if value then self:Show() else self:Hide() end end
function handlers:SetSize(w, h) self.width, self.height = w, h end
function handlers:SetHeight(h) self.height = h end
function handlers:SetWidth(w) self.width = w end
function handlers:GetHeight() return self.height end
function handlers:GetWidth() return self.width end
function handlers:SetScale(s) self.scale = s end
function handlers:GetEffectiveScale() return self.scale end
function handlers:CreateTexture() return frame() end
function handlers:CreateAnimationGroup() return frame() end
function handlers:CreateAnimation() return frame() end
function handlers:SetText(text) self.text = text end
function handlers:GetText() return self.text end
function handlers:SetChecked(value) self.checked = value end
function handlers:GetChecked() return self.checked end
function handlers:HasFocus() return false end

CreateFrame = frame
UIParent = frame()
GetTime = function() return now end
GetServerTime = function() return server + math.floor(now) end
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return shift end
time, date = os.time, os.date
function wipe(tbl) for k in pairs(tbl) do tbl[k] = nil end end
C_Timer = {}
function C_Timer.NewTimer(delay, callback)
    local timer = {at = now + delay, callback = callback, Cancel = function(self) self.cancelled = true end}
    timers[#timers + 1] = timer
    return timer
end
C_Timer.After = C_Timer.NewTimer
function C_Timer.NewTicker() return {Cancel = noop} end
local function advance(seconds)
    local finish = now + seconds
    while true do
        local pick, at
        for i, timer in ipairs(timers) do
            if not timer.cancelled and timer.at <= finish and (not at or timer.at < at) then pick, at = i, timer.at end
        end
        if not pick then break end
        now = at
        table.remove(timers, pick).callback()
    end
    now = finish
end

LOOT_ITEM_SELF = "You receive loot: %s."
UnitName = function() return "Player" end
GetRealmName = function() return "Realm" end
GetRealZoneText = function() return "Zone" end
UnitFactionGroup = function() return "Alliance" end
UnitClass = function() return "Rogue", "ROGUE", 4 end
UnitLevel = function() return 20 end
UnitXP = function() return 100 end
UnitXPMax = function() return 300 end
GetMoney = function() return 80100 end
GetInventorySlotInfo = function(name) return name end
GetInventoryItemID = function(_, name) return name == "MainHandSlot" and 11 or name == "SecondaryHandSlot" and 12 or nil end
GetInventoryItemLink = function(unit, name)
    local id = GetInventoryItemID(unit, name)
    return id and "item:" .. id
end
GetInventoryItemDurability = function(name) if name == "MainHandSlot" then return 10, 100 end end
local counts = {[0] = 5, [-1] = 4}
C_Container = {
    GetContainerNumSlots = function(bag) return (bag == 0 or bankOpen) and counts[bag] or 0 end,
    GetContainerNumFreeSlots = function(bag) return bag == 0 and 1 or 3, 0 end,
    GetContainerItemInfo = function(bag, slot)
        if slot > 1 then return end
        return {itemID = 100, hyperlink = "item:100", stackCount = bag == 0 and 12 or 80, quality = 1,
            isBound = bag ~= 0}
    end,
}
local items = {
    [11] = {"Worn dagger", "INVTYPE_WEAPON", 5, 10},
    [12] = {"Off-hand dagger", "INVTYPE_WEAPON", 4, 10},
    [13] = {"New dagger", "INVTYPE_WEAPON", 11, 15},
    [14] = {"Two-hand sword", "INVTYPE_2HWEAPON", 12, 15},
    [15] = {"Future dagger", "INVTYPE_WEAPON", 12, 22},
    [16] = {"Bound dagger", "INVTYPE_WEAPON", 16, 15, 1},
    [100] = {"Copper Ore", "", 0, 0},
}
local function itemID(link) return tonumber(link) or tonumber(link:match("item:(%d+)")) end
function GetItemInfo(link)
    local id = itemID(link)
    local item = items[id]
    if not item then return end
    return item[1], "item:" .. id, 3, 20, item[4], "Weapon", "Dagger", 1, item[2], 1, 150, 2, 15, item[5] or 2
end
GetItemStats = function(link)
    local item = items[itemID(link)]
    return item and {ITEM_MOD_AGILITY_SHORT = item[3]}
end
IsUsableItem = function(link) return itemID(link) ~= 15 end
local skill = 50
GetNumSkillLines = function() return 1 end
GetSkillLineInfo = function() return "Daggers", false, false, skill, 0, 0, 75 end
C_Item = {GetItemCount = function(id) return id == 100 and 12 or 0 end}
C_QuestLog = {IsComplete = function() return false end, GetTitleForQuestID = function() return "Quest mock" end}
BaziUI = {
    db = {profile = {}}, Database = {CharacterKey = function() return "player" end},
    Inventory = {BagIDs = function() return {0} end, GetItemInfo = GetItemInfo, GeneralFont = noop, Label = frame,
        Money = tostring, Scroll = function(parent) return frame(nil, nil, parent), frame(nil, nil, parent), frame() end,
        Window = function(...) local f = frame(); f:Hide(); return f end},
    Theme = {RoundedCard = function(_, parent) return frame(nil, nil, parent) end, Accent = function() return 0.6, 0.4, 0.9 end,
        AccentInk = function() return 0.6, 0.4, 0.9, 0.25 end, CreateButton = frame,
        CreateSettingsDropdown = frame, CreateCheckbox = frame, SetButtonActive = noop},
    QuestTracker = {DashboardQuests = function() return {} end}, Gathering = {},
    Print = function(_, message) notices[#notices + 1] = message end,
}
for _, name in ipairs({"Dashboard", "DashboardProgress", "DashboardActivity", "AdventureData", "AltManager",
    "EquipmentAdvisor", "Journey", "SmartAlerts", "AdventureUI"}) do loadProject("Modules/" .. name .. ".lua") end
local A, D = BaziUI.Adventure, BaziUI.Dashboard
local M, E, J, S = BaziUI.AltManager, BaziUI.EquipmentAdvisor, BaziUI.Journey, BaziUI.SmartAlerts
local function event(name, ...) A.events.scripts.OnEvent(A.events, name, ...) end

-- Preview and disabled modules must not record live data.
event("PLAYER_LOGIN")
S.Preview("all")
assert(A.current == nil and BaziUI.db.adventure == nil and #S.history == 0)
S.Preview(nil)
for _, id in ipairs({"alts", "journey", "advisor", "alerts"}) do A.Settings(id).enabled = true end
A.Refresh()
advance(1)
assert(M.Characters().player.bags.items[1].count == 12)
assert(M.Characters().player.bank == nil)
assert(S.active.bags and S.active["durability:MainHand"])
assert(J.Current().entries[1].title == "First recorded login")

bankOpen = true
event("BANKFRAME_OPENED")
advance(1)
bankOpen = false
event("BANKFRAME_CLOSED")
event("BAG_UPDATE_DELAYED")
advance(1)
assert(M.Characters().player.bank.items[1].count == 80)
local existing, total = M.Ownership(100, true)
assert(#existing == 1 and total == 92 and existing[1].transferable == 12)
local ask = {}
local tip = {AddDoubleLine = function(_, title, value) ask[#ask + 1] = title .. " " .. value end}
shift = false
M.AddTooltip(tip, 100)
assert(#ask == 0)
shift = true
M.AddTooltip(tip, 100)
assert(#ask == 2)

local profile = E.CharacterProfile("player", nil, true)
profile.weights.ITEM_MOD_AGILITY_SHORT = 1
local duo = E.ForPlayer(E.Item("item:13"))
assert(#duo == 2 and duo[1].score == 7 and duo[1].slot == "SecondaryHand")
local two = E.ForPlayer(E.Item("item:14"))
assert(#two[1].removed == 2 and two[1].score == 3)
local future = E.ForPlayer(E.Item("item:15"))
assert(future[1].label == "Future comparison")
assert(E.Item("12345") == nil)
assert(#E.ForAlts(E.Item(16), false) == 0)
local alt = {identity = {name = "Alt", key = "alt", realm = "Realm", faction = "Alliance", level = 25}, gear = A.current.gear}
M.Characters().alt = alt
E.CharacterProfile("alt", nil, true).weights.ITEM_MOD_AGILITY_SHORT = 1
assert(#E.ForAlts(E.Item(13), true) == 1)
alt.identity.realm = "Different realm"
assert(#E.ForAlts(E.Item(13), true) == 0)

local n = #S.history
S.Set("test", "bags", "Inventory", "warning", "Low")
S.Set("test", "bags", "Inventory", "warning", "Lower")
assert(#S.history == n + 1 and S.active.test.title == "Lower")
advance(9)
assert(not S.active.test and #S.history == n + 1)
S.Set("stable", "bags", "Inventory", "critical", "Full", nil, true)
advance(20)
assert(S.active.stable)
S.Set("stable", "bags", "Inventory", "critical", nil)
assert(not S.active.stable and S.history[#S.history].resolved)
combat = true
A.Settings("alerts").combat = false
assert(#S.Visible() == 0)
combat = false

event("QUEST_TURNED_IN", 123)
event("PLAYER_DEAD")
event("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:13|h[New dagger]|h|r.")
skill = 51
event("SKILL_LINES_CHANGED")
advance(1)
event("PLAYER_LOGOUT")
local journal = J.Current()
assert(journal.totals.quest == 1 and journal.totals.deaths == 1 and journal.totals.looted == 1)
assert(D.GetSessionMetrics().quest == 1)
assert(journal.seen["quality:3"])
local entries = #journal.entries
J.Record("Character", "Duplicate", true, "login")
assert(#journal.entries == entries)
A.Settings("journey").limit = 3
J.Prune(journal, GetServerTime())
assert(#journal.entries <= 3)

-- The window and settings constructors share the native style APIs.
for _, kind in ipairs({"alerts", "journey", "alts", "advisor"}) do
    BaziUI.AdventureUI.Open(kind)
    BaziUI.AdventureUI.Settings(kind, frame(), {panel = frame, section = noop, label = frame, slider = noop})
end
for _, report in ipairs(notices) do assert(not report:find("Progression", 1, true), report) end
print("Adventure checks passed")
