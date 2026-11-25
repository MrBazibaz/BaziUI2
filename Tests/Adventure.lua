local loadProject = LOAD_PROJECT or dofile
unpack = unpack or table.unpack
local now, server, bankOpen, combat, shift = 100, 1762000000, false, false, true
local timers, notices, painted, frames = {}, {}, 0, {}
local lastOpacity, exactOpacity, lastSound
local frame
local function noop() end
local handlers = {}
local index = {__index = function(_, key) return handlers[key] or noop end}
frame = function(_, _, parent)
    local widget = setmetatable({shown = true, scripts = {}, hooks = {}, events = {}, width = 500, height = 200,
        parent = type(parent) == "table" and parent or false, scale = 1}, index)
    frames[#frames + 1] = widget
    return widget
end
function handlers:SetScript(key, fn) self.scripts[key] = fn end
function handlers:RegisterEvent(name) self.events[name] = true end
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
function handlers:CreateFontString() return frame() end
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
    return item[1], "item:" .. id, item[7] or 3, 20, item[4], "Weapon", "Dagger", 1, item[2], 1, 150, item[6] or 2, 15, item[5] or 2
end
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
        CreateSettingsDropdown = frame, CreateCheckbox = frame, SetButtonActive = noop, SettingsHelp = noop,
        PaintQuestCard = function(_, _, opacity, exact)
            painted, lastOpacity, exactOpacity = painted + 1, opacity, exact
        end},
    Chat = {Alerts = {SOUNDS = {{key = "softDrop", label = "Soft Drop"}},
        Preview = function(key) lastSound = key end}},
    QuestTracker = {DashboardQuests = function() return {} end}, Gathering = {},
    Print = function(_, message) notices[#notices + 1] = message end,
}
for _, name in ipairs({"Dashboard", "DashboardProgress", "DashboardActivity", "DashboardNotices", "AdventureData", "AltManager",
    "Journey", "SmartAlerts", "LootUpgrades", "AdventureUI"}) do loadProject("Modules/" .. name .. ".lua") end
local A, D = BaziUI.Adventure, BaziUI.Dashboard
local M, J, S = BaziUI.AltManager, BaziUI.Journey, BaziUI.SmartAlerts
local function event(name, ...) A.events.scripts.OnEvent(A.events, name, ...) end

-- Preview and disabled modules must not record live data.
local shownHelpTip
TALENT_MICRO_BUTTON_UNSPENT_TALENTS = "You have unspent Talent points."
HelpTip = {Hide = function(_, parent, text)
    assert(parent == UIParent)
    if shownHelpTip == text then shownHelpTip = nil end
end}
MainMenuMicroButton_ShowAlert = function(_, text) shownHelpTip = text end
hooksecurefunc = function(name, callback)
    local original = _G[name]
    _G[name] = function(...)
        original(...)
        callback(...)
    end
end
event("PLAYER_LOGIN")
for _, widget in ipairs(frames) do
    if widget ~= A.events and widget.events.PLAYER_LOGIN then widget.scripts.OnEvent(widget, "PLAYER_LOGIN") end
end
A.Settings("alerts").opacity = 100
S.Preview("all")
assert(lastOpacity == 1 and exactOpacity == true, "Smart Alerts passes full opacity to the quest card painter")
assert(painted >= 5, "Preview cards use quest card styling")
assert(A.current == nil and BaziUI.db.adventure == nil and #S.history == 0)
S.Preview(nil)
local unspentTalentPoints = 2
GetNumTalentPoints = function() return unspentTalentPoints end
TalentMicroButtonAlert = frame()
TalentMicroButtonAlert.Text = frame()
TalentMicroButtonAlert.Text:SetText(TALENT_MICRO_BUTTON_UNSPENT_TALENTS)
assert(TalentMicroButtonAlert:IsShown())
for _, id in ipairs({"alts", "journey", "alerts"}) do A.Settings(id).enabled = true end
A.Refresh()
assert(S.active.talent.title == "Unspent talent points · 2", "Existing unspent points are picked up when enabled")
assert(not TalentMicroButtonAlert:IsShown(), "Smart Alerts replaces the native reminder")
local alertConfig = A.Settings("alerts")
alertConfig.dashboard, alertConfig.standalone = true, false
local alertRow = D.byID.smartAlerts.read().rows[1]
assert(D.byID.smartAlerts.label == "Alerts" and alertRow.label == S.active.talent.title)
assert(alertRow.labelColor == S.colors[S.active.talent.severity])
alertConfig.dashboard, alertConfig.standalone = false, true
unspentTalentPoints = 1
event("PLAYER_TALENT_UPDATE")
assert(S.active.talent.title == "Unspent talent points · 1")
unspentTalentPoints = 0
event("CHARACTER_POINTS_CHANGED")
assert(not S.active.talent, "Spending the last point clears the reminder")
local foreverPoints = 1
C_ClassTalents = {HasUnspentTalentPoints = function()
    return foreverPoints > 0, foreverPoints, 0
end}
MainMenuMicroButton_ShowAlert(frame(), TALENT_MICRO_BUTTON_UNSPENT_TALENTS)
assert(S.active.talent.title == "Unspent talent points · 1" and not shownHelpTip)
MainMenuMicroButton_ShowAlert(frame(), "Other help tip")
assert(shownHelpTip == "Other help tip")
foreverPoints = 0
event("TRAIT_CONFIG_UPDATED")
assert(not S.active.talent, "Applying the talent clears the Forever notification")
local hasChatSound, available = false, {}
for _, entry in ipairs(S.SoundChoices()) do
    available[entry[1]] = true
    if entry[1] == "softDrop" then hasChatSound = true end
end
assert(hasChatSound and available.alertFeltTap and available.alertGlassDrop and available.alertTwinBell and available.alertSoftKnock)
local popupFile
PlaySoundFile = function(path, channel)
    assert(channel == "Master")
    popupFile = path
end
S.PlaySound("alertTwinBell")
assert(popupFile:match("AlertTwinBell%.ogg$"))
for _, variant in ipairs({"RetroBonk", "RetroBlip"}) do
    assert(available["alert" .. variant])
    S.PlaySound("alert" .. variant)
    assert(popupFile:match("Alert" .. variant .. "%.ogg$"))
end
alertConfig.sound, alertConfig.soundKey = true, "softDrop"
S.Set("sound-test", "level", "Progress", "progress", "Test alert")
assert(lastSound == "softDrop")
S.Set("sound-test", "level", "Progress", "progress")
alertConfig.sound = false
alertConfig.dashboard, alertConfig.sound, alertConfig.chat = true, true, true
D.Settings().enabled = true
local chatBefore = #notices
popupFile = nil
S.Set("embedded-durability", "durability", "Equipment", "warning", "Low durability test")
assert(not popupFile and #notices == chatBefore)
local upgradeSettings = D.NotificationSettings("upgrade")
assert(upgradeSettings.sound == "alertRetroBonk" and not upgradeSettings.chat)
upgradeSettings.sound, upgradeSettings.chat = "alertRetroBlip", true
S.Set("embedded-upgrade", "upgrade", "Equipment", "progress", "Equipment upgrade test")
assert(popupFile:match("AlertRetroBlip%.ogg$") and notices[#notices] == "Equipment upgrade test")
S.Set("embedded-upgrade", "upgrade", "Equipment", "progress", "Equipment upgrade test")
assert(#notices == chatBefore + 1)
alertConfig.dashboard, alertConfig.sound, alertConfig.chat = false, false, false
D.Settings().enabled = false
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

assert(A.ItemDetails("item:13").name == "New dagger")
assert(A.ItemDetails(12345) == nil)
local alt = {identity = {name = "Alt", key = "alt", realm = "Different realm", faction = "Alliance", level = 25},
    bags = {items = {{id = 100, count = 9, bound = false}}}}
M.Characters().alt = alt
local _, allRealms = M.Ownership(100, false)
assert(allRealms == 101)
local sameRealm, realmTotal = M.Ownership(100, true)
assert(#sameRealm == 1 and realmTotal == 92)

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

local U = BaziUI.LootUpgrades
local stats = {
    [11] = {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5}, [12] = {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4},
    [13] = {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 11}, [14] = {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6},
    [15] = {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12},
    [17] = {ITEM_MOD_SPELL_HEALING_DONE_SHORT = 10},
    [18] = {ITEM_MOD_STRENGTH_SHORT = 6},
}
items[17] = {"Healing ring", "INVTYPE_FINGER", 0, 10, nil, 4}
items[18] = {"Strength ring", "INVTYPE_FINGER", 0, 10, nil, 4}
items[19] = {"Plain dagger", "INVTYPE_WEAPON", 0, 1}
C_Item.GetItemStats = function(link) return stats[itemID(link)] end
C_Item.IsUsableItem = function() return true end
DPS_TEMPLATE = "(%.1f damage per second)"
C_TooltipInfo = {GetHyperlink = function(link)
    if itemID(link) == 19 then return {lines = {{leftText = "(8.5 damage per second)"}}} end
end}
local bagItem
C_Container.GetContainerItemLink = function(bag, slot) if bag == 0 and slot == 2 then return bagItem end end
assert(U.Compare("item:13", A.current).slot == "MainHand")
assert(U.Compare("item:19", A.current), "Plain weapons can be compared by their reported damage per second")
assert(not U.Compare("item:14", A.current), "A two-handed weapon must also beat the off-hand it removes")
assert(not U.Compare("item:15", A.current), "An unmet level requirement must suppress the suggestion")
local spec = 65
C_SpecializationInfo = {GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return spec end}
local paladin = {identity = {token = "PALADIN", level = 20}, gear = {Finger0 = {id = 18, link = "item:18"}}}
assert(U.Compare("item:17", paladin))
spec = 70
assert(not U.Compare("item:17", paladin))
C_SpecializationInfo = nil
local revealed
BaziUI.Inventory.RevealUpgrade = function(link) revealed = link end
event("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:13|h[New dagger]|h|r.")
assert(not S.active["upgrade:item:13"])
bagItem = "item:13"
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(U.Mark({bag = 0, slot = 2, hyperlink = bagItem}))
local upgrade = assert(S.active["upgrade:item:13"])
upgrade.action()
assert(revealed == bagItem)
bagItem = nil
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(not S.active["upgrade:item:13"] and not U.Mark({bag = 0, slot = 2, hyperlink = "item:13"}))
items[21] = {"Worn cloak", "INVTYPE_CLOAK", 0, 1, nil, 4}
items[22] = {"New cloak", "INVTYPE_CLOAK", 0, 1, nil, 4}
stats[21] = {RESISTANCE0_NAME = 6, ITEM_MOD_AGILITY_SHORT = 1}
stats[22] = {RESISTANCE0_NAME = 8, ITEM_MOD_AGILITY_SHORT = 1}
local inventoryItemBeforeCloak = GetInventoryItemID
GetInventoryItemID = function(unit, slot)
    if slot == "BackSlot" then return 21 end
    return inventoryItemBeforeCloak(unit, slot)
end
event("PLAYER_EQUIPMENT_CHANGED")
advance(0.5)
assert(U.Compare("item:22", A.current).slot == "Back", "A small armor gain with the same agility is still an upgrade")
assert(not U.Compare("item:21", A.current), "An identical cloak is not an upgrade")
event("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:22|h[New cloak]|h|r.")
bagItem = "item:22"
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(U.Mark({bag = 0, slot = 2, hyperlink = bagItem}))
assert(S.active["upgrade:item:22"]).action()
assert(revealed == bagItem)
items[23] = {"Frayed cloak", "INVTYPE_CLOAK", 0, 0, nil, 4, 0}
items[24] = {"Sturdy gray cloak", "INVTYPE_CLOAK", 0, 0, nil, 4, 0}
items[25] = {"Restricted cloak", "INVTYPE_CLOAK", 0, 0, nil, 4, 0}
ARMOR_TEMPLATE = "%d Armor"
local previousTooltip, previousUsable = C_TooltipInfo.GetHyperlink, C_Item.IsUsableItem
C_TooltipInfo.GetHyperlink = function(link)
    local id = itemID(link)
    if id < 23 or id > 25 then return previousTooltip(link) end
    local lines = {{leftText = items[id][1]}, {leftText = id == 23 and "6 Armor" or "9 Armor"}}
    if id == 25 then lines[3] = {leftText = "Requires faction standing", leftColor = {r=1, g=0.1, b=0.1}} end
    return {lines = lines}
end
C_Item.IsEquippableItem = function(link) return itemID(link) >= 23 and itemID(link) <= 25 end
C_Item.IsUsableItem = function(link)
    if C_Item.IsEquippableItem(link) then return false end
    return previousUsable(link)
end
GetInventoryItemID = function(unit, slot)
    if slot == "BackSlot" then return 23 end
    return inventoryItemBeforeCloak(unit, slot)
end
event("PLAYER_EQUIPMENT_CHANGED")
advance(0.5)
assert(U.Compare("item:24", A.current).slot == "Back", "A gray leveling cloak can be evaluated from its armor line")
assert(not U.Compare("item:25", A.current), "A red equip requirement still blocks the recommendation")
event("CHAT_MSG_LOOT", "You receive loot: |cff9d9d9d|Hitem:24|h[Sturdy gray cloak]|h|r.")
bagItem = "item:24"
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(U.Mark({bag = 0, slot = 2, hyperlink = "|cff9d9d9d|Hitem:24|h[Sturdy gray cloak]|h|r"}))
assert(not U.Mark({bag = 0, slot = 2, hyperlink = "item:24:1"}), "A different item variant must not inherit the arrow")
assert(S.active["upgrade:item:24"])
alertConfig.dashboard, alertConfig.standalone = true, true
local function dashboardCloak()
    for _, row in ipairs(D.byID.smartAlerts.read().rows) do
        if row.label == "Equip Sturdy gray cloak" then return row end
    end
end
assert(dashboardCloak(), "An embedded upgrade is visible alongside standalone alerts")
advance(alertConfig.duration + 0.1)
assert(not S.active["upgrade:item:24"], "The standalone loot popup expires normally")
assert(dashboardCloak()).click()
assert(revealed == "item:24")
bagItem = nil
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(not dashboardCloak(), "Removing the item clears the embedded upgrade")
bagItem = "item:24"
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(dashboardCloak() and not S.active["upgrade:item:24"], "Gear already in the bags does not need a loot event")
alertConfig.dashboard = false
C_TooltipInfo.GetHyperlink, C_Item.IsUsableItem, C_Item.IsEquippableItem = previousTooltip, previousUsable, nil
GetInventoryItemID, bagItem = inventoryItemBeforeCloak, nil
event("PLAYER_EQUIPMENT_CHANGED")
event("BAG_UPDATE_DELAYED")
advance(0.5)

items[26] = {"Sharpened Letter Opener", "INVTYPE_WEAPON", 0, 2}
items[27] = {"Camping Knife", "INVTYPE_WEAPON", 0, 0, nil, 2, 1}
items[28] = {"Wolf Handler Gloves", "INVTYPE_HAND", 0, 0, nil, 4, 1}
items[29] = {"Driving Gloves", "INVTYPE_HAND", 0, 0, nil, 4, 1}
local originalClass, originalBagLink = UnitClass, C_Container.GetContainerItemLink
UnitClass = function() return "Hunter", "HUNTER", 3 end
GetInventoryItemID = function(unit, slot)
    if slot == "MainHandSlot" then return 26 end
    if slot == "HandsSlot" then return 28 end
    return inventoryItemBeforeCloak(unit, slot)
end
C_Item.IsUsableItem = function() return false end
C_Item.IsEquippableItem = function(link) return itemID(link) >= 26 and itemID(link) <= 29 end
C_TooltipInfo.GetHyperlink = function(link)
    local id = itemID(link)
    local values = {[26]="(2.1 damage per second)", [27]="(3.2 damage per second)", [28]="21 Armor", [29]="30 Armor"}
    if values[id] then return {lines = {{leftText = items[id][1]}, {leftText = values[id]}}} end
    return previousTooltip(link)
end
local showRewards = false
C_Container.GetContainerItemLink = function(bag, slot)
    if showRewards and bag == 0 then
        if slot == 2 then return "item:27" end
        if slot == 3 then return "item:29" end
    end
end
local maxAlerts = alertConfig.maximum
alertConfig.dashboard, alertConfig.standalone, alertConfig.maximum = true, false, 10
event("PLAYER_ENTERING_WORLD")
advance(0.5)
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
event("CHAT_MSG_LOOT", "You receive item: |cffffffff|Hitem:27|h[Camping Knife]|h|r.")
event("CHAT_MSG_LOOT", "You receive item: |cffffffff|Hitem:29|h[Driving Gloves]|h|r.")
showRewards = true
event("BAG_UPDATE_DELAYED")
advance(0.5)
assert(U.Compare("item:27", A.current).slot == "MainHand", "Hunter notices a stronger melee weapon")
assert(U.Compare("item:29", A.current).slot == "Hands", "Armor-only gloves can use tooltip data")
assert(U.Mark({bag = 0, slot = 2, hyperlink = "item:27"}))
assert(U.Mark({bag = 0, slot = 3, hyperlink = "item:29"}))
assert(S.active["upgrade:item:27"] and S.active["upgrade:item:29"])
local dashboardEquipment = {}
for _, row in ipairs(D.byID.smartAlerts.read().rows) do dashboardEquipment[row.label] = true end
assert(dashboardEquipment["Equip Camping Knife"] and dashboardEquipment["Equip Driving Gloves"])
alertConfig.dashboard, alertConfig.standalone, alertConfig.maximum = false, true, maxAlerts
UnitClass, GetInventoryItemID, C_Container.GetContainerItemLink = originalClass, inventoryItemBeforeCloak, originalBagLink
C_TooltipInfo.GetHyperlink, C_Item.IsUsableItem, C_Item.IsEquippableItem = previousTooltip, previousUsable, nil
event("PLAYER_ENTERING_WORLD")
advance(0.5)

-- The window and settings constructors share the native style APIs.
for _, kind in ipairs({"alerts", "journey", "alts"}) do
    BaziUI.AdventureUI.Open(kind)
    BaziUI.AdventureUI.Settings(kind, frame(), {panel = frame, section = noop, label = frame, slider = noop})
end
local ammoCount, ammoSound = 538, 0
local previousInventoryItem = GetInventoryItemID
GetInventoryItemID = function(unit, slot)
    if slot == "AmmoSlot" then return 515 end
    return previousInventoryItem(unit, slot)
end
UnitClass = function() return "Hunter", "HUNTER" end
local previousCount = C_Item.GetItemCount
C_Item.GetItemCount = function(id) return id == 515 and ammoCount or previousCount(id) end
local watch = {enabled = true, low = 600, critical = 200, sound = true, lowSound = "raidWarning",
    criticalSound = "raidWarning", chatWarning = true, width = 104, height = 35, iconSize = 23, scale = 100, x = 0, y = 0}
BaziUI.HUD = {Settings = function() return watch end}
BaziUI.Theme.CreateFrameBorder, BaziUI.Theme.AddDropShadow = noop, noop
BaziUI.Typography = {Apply = noop, Path = noop}
GetInventoryItemTexture = function() return 123 end
BreakUpLargeNumbers = tostring
GameTooltip = {IsOwned = function() return false end}
PlaySound = function() ammoSound = ammoSound + 1 end
local alertCfg = A.Settings("alerts")
alertCfg.enabled, alertCfg.chat, alertCfg.sound, alertCfg.dnd = true, true, true, false
loadProject("Modules/HUDAmmo.lua")
local ammoEvents = frames[#frames]
local beforeAmmo = #notices
ammoEvents.scripts.OnEvent(ammoEvents, "PLAYER_LOGIN")
ammoEvents.scripts.OnEvent(ammoEvents, "PLAYER_ENTERING_WORLD")
assert(#notices == beforeAmmo and ammoSound == 0)
S.RefreshAmmo()
assert(S.active.ammo.title == "Low ammunition · 538" and #notices == beforeAmmo and ammoSound == 0)
advance(0.6)
assert(#notices == beforeAmmo + 1 and notices[#notices]:find("538") and ammoSound == 1)
ammoCount = 190
ammoEvents.scripts.OnEvent(ammoEvents, "PLAYER_AMMO_CHANGED")
assert(S.active.ammo.severity == "critical" and ammoSound == 2)
ammoCount = 601
ammoEvents.scripts.OnEvent(ammoEvents, "BAG_UPDATE_DELAYED")
assert(not S.active.ammo)
watch.enabled, ammoCount = false, 538
S.RefreshAmmo({identity = {token = "HUNTER"}})
assert(not S.active.ammo, "Standalone Smart Alerts keeps its own ammunition thresholds")
local dashboardHasDefense = true
local originalShowingRow = D.IsShowingRow
D.IsShowingRow = function(widget, label) return widget == "skills" and label == "Defense" and dashboardHasDefense end
D.Settings().enabled = true
for rank = 37, 38 do
    A.Emit("snapshot", {skills = {Defense = {rank = rank, maximum = 40}}}, {skills = true})
end
advance(0.3)
assert(not S.active["skill:Defense"])
dashboardHasDefense = false
A.Emit("snapshot", {skills = {Defense = {rank = 39, maximum = 40}}}, {skills = true})
advance(0.3)
assert(S.active["skill:Defense"].title == "Defense reached 39")
D.IsShowingRow = originalShowingRow
for _, report in ipairs(notices) do assert(not report:find("Progression", 1, true), report) end
print("Adventure checks passed")
