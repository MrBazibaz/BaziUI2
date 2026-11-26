-- Run from the repository root with Lua. LOAD_PROJECT may supply a sandboxed loader.
local loadProject = LOAD_PROJECT or dofile
local frames, timers, ticks = {}, {}, {}
local time, cursorX, cursorY, combat, down = 100, 0, 0, false, false
local methods = {}
local function noop() end
local prototype = {__index = function(_, key) return methods[key] or noop end}
local function frame(_, name)
    local f = setmetatable({shown = true, width = 250, height = 50, scale = 1, points = {}, scripts = {}, events = {}}, prototype)
    frames[#frames + 1] = f
    if type(name) == "string" then _G[name] = f end
    return f
end
function methods:SetPoint(point, parent, relative, x, y)
    if type(parent) == "number" then x, y, parent, relative = parent, relative, UIParent, point end
    self.points[1] = {point, parent or UIParent, relative or point, x or 0, y or 0}
end
function methods:ClearAllPoints() self.points = {} end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(i) return unpack(self.points[i] or {}) end
function methods:GetRect() return 25, 25, self.width, self.height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetLeft() return 25 end
function methods:GetRight() return 25 + self.width end
function methods:GetTop() return 125 end
function methods:GetBottom() return 25 end
function methods:SetHeight(v) self.height = v end
function methods:SetWidth(v) self.width = v end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetScale(scale) self.scale = scale end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return rawget(self, "level") or 1 end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked == true end
function methods:StartMoving() self.isMoving = true end
function methods:StopMovingOrSizing() self.isMoving = false end
function methods:GetEffectiveScale() return self.scale end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = not not value end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:IsForbidden() return false end
function methods:HasFocus() return false end
function methods:IsMouseOver() return self.hovered end
function methods:CreateTexture() return frame() end
function methods:CreateAnimationGroup() return frame() end
function methods:CreateAnimation() return frame() end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:GetStringHeight() return 12 end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:SetAttribute(key, value)
    assert(not combat)
    self.attributes = rawget(self, "attributes") or {}
    self.attributes[key] = value
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:UnregisterAllEvents() self.events = {} end
function methods:HookScript() end
local function timer(queue, callback)
    local entry = {callback = callback, Cancel = function(self) self.cancelled = true end}
    queue[#queue + 1] = entry
    return entry
end
local function flush()
    while #timers > 0 do
        local batch = timers
        timers = {}
        for _, entry in ipairs(batch) do if not entry.cancelled then entry.callback() end end
    end
end
local function event(name, ...)
    for _, object in ipairs(frames) do
        if object.events[name] then object.scripts.OnEvent(object, name, ...) end
    end
    flush()
end
local function advance(seconds)
    time = time + seconds
    for _, ticker in ipairs(ticks) do if not ticker.cancelled then ticker.callback() end end
    flush()
end

unpack = unpack or table.unpack
function wipe(t) for k in pairs(t) do t[k] = nil end end
CreateFrame = frame
function CreateColor(...) return {...} end
UIParent = frame()
GameTooltip = {IsOwned = function() return false end}
RegisterStateDriver, UnregisterStateDriver = noop, noop
UIParent:SetSize(1000, 700)
C_Timer = {
    After = function(_, cb) return timer(timers, cb) end,
    NewTimer = function(_, cb) return timer(timers, cb) end,
    NewTicker = function(_, cb) return timer(ticks, cb) end,
}
function GetCursorPosition() return cursorX, cursorY end
function IsMouseButtonDown() return down end
function IsShiftKeyDown() return false end
function InCombatLockdown() return combat end
function GetTime() return time end
local zoneType, zone, key = "none", "Redridge Mountains", "Character-1"
function IsInInstance() return zoneType ~= "none", zoneType end
function GetInstanceInfo() return "The Deadmines", zoneType, 1, "", 5, false, false, 36 end
function GetRealZoneText() return zone end
function GetMoney() return 100 end
local questCount, skill, profession, bagFree, faction = 1, 20, 60, 10, 120
local items = {[100] = 4, [101] = 1}
LOOT_ITEM_SELF = "You receive loot: %s."
YOU_LOOT_MONEY = "You loot %s"
LOOT_MONEY_SPLIT_GUILD = "%2$s to the guild. Your share is %1$s."
GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
ERR_QUEST_REWARD_EXP_I = "Experience gained: %d."
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
local xp, level = 100, 10
function UnitXP() return xp end
function UnitXPMax() return 200 end
function UnitLevel() return level end
local filters, history = {}, {}
ChatFrameUtil = {AddMessageEventFilter = function(name, callback) filters[name] = callback end}
DEFAULT_CHAT_FRAME, ChatFrame3 = frame(), frame()
ChatFrame3.isDocked, ChatFrame3.messageTypeList = true, {"LOOT", "MONEY"}
ChatFrame3.AddMessage = function(_, message) history[#history + 1] = message end
ChatTypeInfo = {COMBAT_XP_GAIN = {}, SYSTEM = {}}
function GetChatWindowInfo(id) if id == 3 then return "Loot" end end
C_QuestLog = {GetQuestObjectives = function(id)
    if id == 43 then return {{text = "Blackrock Champion", numFulfilled = 1, numRequired = 15}} end
    return {{text = "Tarantula Egg", numFulfilled = questCount, numRequired = 3, finished = questCount >= 3, itemID = 100}}
end}
C_SkillInfo = {GetNumSkillLines = function() return 2 end, GetSkillLineInfo = function(index)
    return index == 1 and {name = "Daggers", currentRank = skill, maxRank = 30, skillID = 173}
        or {name = "Mining", currentRank = profession, maxRank = 75, skillID = 186}
end}
C_Item = {GetItemCount = function(id) return items[id] or 0 end}
C_Reputation = {GetNumFactions = function() return 1 end, GetFactionDataByIndex = function()
    return {factionID = 72, name = "Stormwind", reaction = 5, currentReactionThreshold = 0,
        nextReactionThreshold = 3000, currentStanding = faction}
end}
C_Container = {GetContainerNumFreeSlots = function() return bagFree, 0 end}
C_TradeSkillUI = {
    GetRecipeInfo = function() return {name = "Test recipe"} end,
    GetRecipeSchematic = function() return {reagentSlotSchematics = {{required = true, quantityRequired = 2, reagents = {{itemID = 100}}}}} end,
}
local warnings, panels, fontSizes = {}, {}, {}
local moverChecks = {}
local inside = {[42] = true}
C_Minimap = {IsInsideQuestBlob = function(id) return inside[id] end}
local characterClass = "ROGUE"
UnitClass = function() return "Test", characterClass end
GetInventorySlotInfo = function() return 0 end
GetInventoryItemID = function() return 102 end
BaziUI = {
    db = {profile = {}},
    Print = function(_, msg) warnings[#warnings + 1] = msg end,
    Database = {CharacterKey = function() return key end},
    Theme = {RoundedCard = frame, PaintQuestCard = noop, SetButtonActive = noop, CreateFrameBorder = noop,
        CreateCheckbox = function() return frame() end,
        SettingsHelp = function(_, check, title) moverChecks[title] = check end,
        Accent = function() return 0.7, 0.3, 0.8 end, AccentInk = function() return 0.7, 0.3, 0.8, 1 end,
        CreateButton = function(_, _, label) local f = frame(); f:SetText(label); return f end},
    Typography = {Path = function() return "font" end, BaseSize = function() return 14 end, Apply = noop,
        Resolve = function(key, _, size) return "font", fontSizes[key] or size end},
    Headers = {Text = function() return 1, 1, 1 end},
    Inventory = {
        Window = function(name)
            local f = frame()
            f:SetClampedToScreen(true)
            f:Hide()
            f.border, f.closeButton = frame(), frame()
            panels[name] = f
            f.header = frame()
            return f, f.header, frame()
        end,
        Scroll = function(parent, _, _, style)
            if parent == panels.BaziUIDashboard then assert(style == "compact") end
            return frame(), frame(), frame()
        end,
        Label = frame,
        BagIDs = function() return {0} end,
        Capacity = function() return {general = {free = bagFree, total = 16}, ammo = {free = 1, total = 8}} end,
        capacityOrder = {"general", "ammo", "reagent"},
        capacityLabels = {general = "Bags", ammo = "Quiver / ammo pouch", reagent = "Reagent bag"},
        Money = tostring,
        GetItemInfo = function(id) return "Item " .. id, "item:" .. id, nil, nil, nil, nil, nil, nil, nil, 123, 1, id == 102 and 6 or 7 end,
    },
    Gathering = {DashboardContext = function() return "ore", false end},
    HUD = {Settings = function() return {low = 30} end},
    QuestTracker = {
        DashboardQuests = function() return {
            [42] = {zone = "Redridge Mountains", info = {title = "Alther's Mill"}},
            [43] = {zone = "Redridge Mountains", info = {title = "Blackrock Bounty"}},
        } end,
        OpenQuest = noop,
    },
}
for _, file in ipairs({"Dashboard", "DashboardProgress", "DashboardQuestItems", "DashboardActivity", "DashboardNotices", "DashboardPreview", "Movers"}) do
    loadProject("Modules/" .. file .. ".lua")
end
loadProject("Core/LayoutGrid.lua")
local D, M = BaziUI.Dashboard, BaziUI.Movers
local function model(id)
    return D.byID[id].read(D.WidgetSettings(id))
end
assert(#D.widgets == 14)
assert(D.PreviewData("dungeon", "dungeon") and not D.PreviewData("dungeon", "raid"))
assert(not D.Settings().enabled and D.Settings().width == 192)
D.Settings().enabled = true
D.Refresh()
flush()
assert(panels.BaziUIDashboard:IsShown() and #warnings == 0)
assert(model("quests").rows[1].value == "1 / 3")
questCount = 3
event("QUEST_LOG_UPDATE")
assert(model("quests").rows[1].done)
advance(21)
assert(#model("quests").rows == 0)
questCount = 2
event("QUEST_LOG_UPDATE")
D.Tracking().quests["42:1"] = true
D.WidgetSettings("quests").pinned = true
D.WidgetSettings("quests").mode = "always"
inside[42] = false
event("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED", 42, false)
assert(#model("quests").rows == 0, "Quest area exit hides it even while pinned and in the same map zone")
local questInvalidations = 0
local invalidate = D.Invalidate
D.Invalidate = function(id)
    if id == "quests" then questInvalidations = questInvalidations + 1 end
    return invalidate(id)
end
inside[43] = true
advance(2)
assert(questInvalidations == 1, "Entering a quest area without a boundary event is detected by the ticker")
advance(2)
assert(questInvalidations == 1, "Remaining in the same area does not repeatedly invalidate quest progress")
local objectives = model("quests").rows
assert(#objectives == 1 and objectives[1].label == "Blackrock Champion")
inside[42], inside[43] = true, false
event("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED", 42, true)
objectives = model("quests").rows
assert(#objectives == 1 and objectives[1].label == "Tarantula Egg" and objectives[1].value == "2 / 3")
local minimap = C_Minimap
C_Minimap = nil
event("ZONE_CHANGED_NEW_AREA")
assert(#model("quests").rows == 0, "Unavailable area data must keep quest objectives hidden")
C_Minimap, D.Invalidate = minimap, invalidate
event("ZONE_CHANGED_NEW_AREA")
D.WidgetSettings("quests").mode, D.WidgetSettings("quests").pinned = "automatic", false

local dashboard = panels.BaziUIDashboard
assert(dashboard.clamped == false, "Dashboard can extend beyond the screen")
local previousX = D.Settings().x
D.Settings().x = UIParent:GetWidth() / 2 + 25
D.Render()
local _, _, _, outsideX = dashboard:GetPoint(1)
assert(outsideX == D.Settings().x)
D.Settings().x = previousX
D.Render()
assert(dashboard.header:IsShown() and dashboard.header:GetPoint(1) == "TOPRIGHT")
D.Settings().growUp = true
D.Settings().x, D.Settings().y = 120, -90
D.Render()
local anchor, _, _, x, y = dashboard:GetPoint(1)
assert(anchor == "BOTTOMLEFT" and x == 120 and y == -90)
assert(dashboard.header:IsShown() and dashboard.header:GetPoint(1) == "BOTTOMRIGHT")
local fullHeight = dashboard:GetHeight()
fontSizes["Dashboard:Title"] = 32
D.Render()
assert(dashboard.header:GetHeight() == 40 and dashboard:GetHeight() == fullHeight + 13)
fontSizes["Dashboard:Title"] = nil
fontSizes["Dashboard:Value"] = 26
D.Render()
assert(dashboard:GetHeight() > fullHeight, "Bigger values reserve additional row height")
fontSizes["Dashboard:Value"] = nil
D.Render()
assert(dashboard:GetHeight() == fullHeight)
D.Settings().showHeader = false
D.Render()
assert(not dashboard.header:IsShown() and dashboard:GetHeight() == fullHeight - 25)
D.Settings().showHeader, D.Settings().growUp = true, false
D.Render()

characterClass = "HUNTER"
D.WidgetSettings("supplies").mode = "always"
assert(D.TrackSupply(102, 5))
assert(D.TrackSupply(100, 5))
local supplyRows = model("supplies").rows
assert(#supplyRows == 3 and supplyRows[1].label == "Free bag slots" and supplyRows[2].value == "1"
    and supplyRows[3].label == "Item 100")
D.Tracking().supplies[100] = nil
D.WidgetSettings("supplies").mode = "automatic"
skill, profession, faction, bagFree = 21, 61, 170, 0
event("SKILL_LINES_CHANGED")
event("UPDATE_FACTION")
event("BAG_UPDATE_DELAYED")
assert(model("skills").rows[1].value == "21 / 30 (+1)")
assert(D.IsShowingRow("skills", "Daggers"))
assert(model("professions").rows[1].value == "61 / 75 (+1)")
assert(model("reputation").active and model("supplies").active)
assert(model("reputation").rows[1].value == "|cff92d785+50|r  170 / 3000")
local wear = 1
GetInventoryItemDurability = function(slot) if slot == 16 then return wear, 150 end end
GetInventoryItemLink = function(_, slot) if slot == 16 then return "item:101" end end
local equippedWear = model("supplies").rows[3]
assert(equippedWear.label == "Durability" and equippedWear.value == "1%" and equippedWear.link == "item:101")
wear = 0
assert(model("supplies").rows[3].value == "0%")
GetInventoryItemDurability, GetInventoryItemLink = nil, nil
advance(61)
assert(not model("skills").active and not model("reputation").active)
D.WidgetSettings("reputation").mode = "always"
assert(model("reputation").rows[1].value == "170 / 3000")
D.WidgetSettings("reputation").mode = "automatic"

assert(D.TrackItem("item:100", 6))
assert(D.TrackRecipe(99, 2))
assert(model("items").rows[1].value == "4 / 6")
assert(model("craftingGoals").rows[1].done)
items[100] = 3
event("BAG_UPDATE_DELAYED")
assert(not model("craftingGoals").rows[1].done)
key = "Character-2"
assert(not next(D.Tracking().goals) and not next(D.Tracking().items))
key = "Character-1"
assert(D.Tracking().goals[99])
event("BAG_UPDATE_DELAYED")
assert(not D.byID.gathering and #model("crafting").rows == 0)
event("CHAT_MSG_LOOT", "You receive loot: |cff33ff00|Hitem:101:0|h[Ore]|h|rx2.")
assert(D.GetSessionMetrics().materials == 2)
assert(D.TrackMaterial("item:101"))
assert(model("items").rows[2].value == "1")
zoneType = "party"
event("PLAYER_ENTERING_WORLD")
event("ENCOUNTER_START", 7, "Test boss", 1, 5)
event("ENCOUNTER_END", 7, "Test boss", 1, 5, 0)
event("ENCOUNTER_START", 7, "Test boss", 1, 5)
event("ENCOUNTER_END", 7, "Test boss", 1, 5, 1)
event("ENCOUNTER_END", 7, "Test boss", 1, 5, 1)
local dungeon = model("dungeon")
assert(dungeon.rows[2].value == "1" and dungeon.rows[3].label == "Test boss" and dungeon.rows[4].value == "2 / 1")
zoneType = "none"
event("ZONE_CHANGED_NEW_AREA")
assert(not model("dungeon"))
zoneType = "party"
event("PLAYER_ENTERING_WORLD")
assert(model("dungeon").rows[2].value == "0")
zoneType = "none"
event("PLAYER_ENTERING_WORLD")
assert(#warnings == 0)
D.Settings().enabled = false
D.Refresh()
flush()
assert(not panels.BaziUIDashboard:IsShown())
for _, object in ipairs(frames) do assert(not object.events.BAG_UPDATE_DELAYED) end
D.Preview("pvp")
assert(panels.BaziUIDashboard:IsShown())
D.Preview(nil)

loadProject("Modules/AdventureData.lua")
loadProject("Modules/SmartAlerts.lua")
local S = BaziUI.SmartAlerts
local register = M.Register
M.Register = function(spec)
    if spec.label == "Dashboard" or spec.label == "Smart Alerts" then register(spec) end
end
BaziUI.ActionBars = {bars = {}}
for _, module in ipairs({"HUDAmmo", "HUDAuras", "CastBars", "DamageMeter", "Map", "Dialogue", "EnemyNameplates"}) do
    BaziUI[module] = {}
end
BaziUI.Chat = {FriendToasts = {}, Whispers = {}, Resize = {}}
loadProject("Modules/MoverModules.lua")
M.Register = register

local cfg, alerts = D.Settings(), S.Settings()
cfg.showHeader, cfg.locked = false, true
alerts.standalone = false
for _, entry in ipairs({{"Dashboard", D.GetFrame, cfg}, {"Smart Alerts", S.GetFrame, alerts}}) do
    local label, getFrame, settings = unpack(entry)
    assert(M.Open(false, label))
    local target = getFrame()
    local handle, moverDriver
    for _, object in ipairs(frames) do
        local spec = rawget(object, "spec")
        if spec and spec.label == label and object.scripts.OnDragStart then handle = object end
        if object.events.PLAYER_REGEN_DISABLED and object.scripts.OnUpdate then moverDriver = object end
    end
    assert(handle and handle:IsShown() and target:IsShown() and target:GetHeight() >= 36)
    local initialX = settings.x
    local check = assert(moverChecks["Unlock " .. label])
    assert(not check:GetChecked())
    check:SetChecked(true)
    handle.scripts.OnDragStart(handle)
    cursorX, down = cursorX + 12, true
    moverDriver.scripts.OnUpdate(moverDriver, 0.016)
    local _, _, _, liveX = target:GetPoint(1)
    assert(liveX == (initialX + 12) / target:GetEffectiveScale())
    down = false
    handle.scripts.OnDragStop()
    assert(settings.x == initialX + 12)
    local apply = label == "Smart Alerts"
    M.Finish(apply)
    assert(settings.x == (apply and initialX + 12 or initialX) and not target:IsShown())
end
cfg.showHeader, cfg.locked = true, false
alerts.standalone = true
cursorX, cursorY = 0, 0

local real = frame()
local coordinates = {x = 10, y = 15}
local function apply() real:SetPoint("CENTER", UIParent, "CENTER", coordinates.x, coordinates.y) end
apply()
local spec = {label = "Real frame", frame = function() return real end, settings = function() return coordinates end, apply = apply}
M.Register(spec)
local restricted = frame()
local restrictedMeasured = false
restricted.IsAnchoringRestricted = function() return true end
restricted.GetRect = function() restrictedMeasured = true; error("Restricted frame") end
local blockedPosition = {x = 80, y = 90}
local blocked = {label = "Restricted frame", frame = function() return restricted end,
    settings = function() return blockedPosition end, apply = noop}
M.Register(blocked)
assert(M.Open(false))
local overlay, driver, blockedOverlay
for _, f in ipairs(frames) do
    if f.spec == spec and f.scripts.OnDragStart then overlay = f end
    if f.spec == blocked and f.scripts.OnDragStart then blockedOverlay = f end
    if f.events.PLAYER_REGEN_DISABLED and f.scripts.OnUpdate then driver = f end
end
assert(overlay and driver)
assert(blockedOverlay and blockedOverlay:IsShown() and not rawget(blockedOverlay, "liveFrame") and not restrictedMeasured)
assert(BaziUIMovers.clamped)
BaziUIMoversDragHandle.scripts.OnDragStart()
assert(BaziUIMovers.isMoving)
BaziUIMoversDragHandle.scripts.OnDragStop()
assert(not BaziUIMovers.isMoving)
BaziUIMovers.gridCheck:SetChecked(true)
BaziUIMovers.gridCheck.scripts.OnClick(BaziUIMovers.gridCheck)
assert(BaziUI.LayoutGrid.IsShown())
local realCheck = assert(moverChecks["Unlock Real frame"])
local blockedCheck = assert(moverChecks["Unlock Restricted frame"])
assert(not realCheck:GetChecked() and not blockedCheck:GetChecked())
blockedCheck:SetChecked(true)
blockedOverlay.scripts.OnDragStart(blockedOverlay)
cursorX, down = 11, true
driver.scripts.OnUpdate(driver, 0.016)
down = false
blockedOverlay.scripts.OnDragStop()
assert(blockedPosition.x == 91)
cursorX = 0
overlay.scripts.OnDragStart(overlay)
cursorX, down = 20, true
driver.scripts.OnUpdate(driver, 0.016)
assert(not M.IsDragging(real) and select(4, real:GetPoint(1)) == 10)
cursorX, down = 0, false
realCheck:SetChecked(true)
overlay.scripts.OnDragStart(overlay)
cursorX, cursorY, down = 20, -18, true
driver.scripts.OnUpdate(driver, 0.016)
local _, _, _, x, y = real:GetPoint(1)
assert(x == 30 and y == -3 and coordinates.x == 10)
down = false
overlay.scripts.OnDragStop()
assert(coordinates.x == 30 and coordinates.y == -3)
M.Finish(false)
assert(coordinates.x == 10 and coordinates.y == 15)
assert(blockedPosition.x == 80 and not BaziUI.LayoutGrid.IsShown())
M.Open(false)
assert(not realCheck:GetChecked() and not blockedCheck:GetChecked())
realCheck:SetChecked(true)
overlay.scripts.OnDragStart(overlay)
cursorX, down = 40, true
driver.scripts.OnUpdate(driver, 0.016)
combat = true
event("PLAYER_REGEN_DISABLED")
combat = false
event("PLAYER_REGEN_ENABLED")
local _, _, _, restoredX = real:GetPoint(1)
assert(restoredX == 10 and coordinates.x == 10)
D.Settings().enabled = true
D.Refresh()
flush()
assert(D.PreviewData("activity", "recentActivity") and #model("recentActivity").rows == 0)
assert(D.WidgetSettings("recentActivity").duration == 20 and D.WidgetSettings("crafting").duration == 20)
assert(D.WidgetSettings("session").duration == 120)
event("PLAYER_XP_UPDATE", "player")
assert(#model("recentActivity").rows == 0)
D.Render()
local heightBeforeXP = dashboard:GetHeight()
xp = 150
event("PLAYER_XP_UPDATE", "player")
local activity = model("recentActivity").rows
assert(activity[1].label == "Experience" and activity[1].value == "+50")
assert(dashboard:GetHeight() == heightBeforeXP, "Activity begins resizing from the current height")
dashboard.scripts.OnUpdate(dashboard, 0.10)
local heightDuringXP = dashboard:GetHeight()
dashboard.scripts.OnUpdate(dashboard, 0.10)
assert(heightBeforeXP < heightDuringXP and heightDuringXP < dashboard:GetHeight(),
    "Activity expands over successive frames")
local gathered = "You receive loot: |Hitem:100|h[Tarantula Egg]|hx2."
event("CHAT_MSG_LOOT", gathered)
event("CHAT_MSG_LOOT", "Other receives loot: |Hitem:100|h[Tarantula Egg]|h.")
event("CHAT_MSG_MONEY", "You loot 5 Copper")
event("CHAT_MSG_MONEY", "4 Copper to the guild. Your share is 1 Silver 5 Copper.")
event("CHAT_MSG_LOOT", "You receive loot: |Hitem:101|h[Spider Fang]|h.")
event("CHAT_MSG_LOOT", gathered)
local recent = model("recentActivity")
activity = recent.rows
assert(#activity == 4 and activity[1].value == "+50" and activity[2].label == "Coins" and activity[2].value == "110")
assert(activity[3].label == "Spider Fang" and activity[3].value == "")
assert(activity[4].label == "Tarantula Egg" and activity[4].value == "×4")
assert(recent.countdown.duration == 20 and recent.countdown.start == GetTime())
local activityBar
for _, object in ipairs(frames) do
    if rawget(object, "tip") then activityBar = object end
end
assert(activityBar)
D.Settings().hideActivityChat = true
D.Refresh()
flush()
assert(filters.CHAT_MSG_LOOT(DEFAULT_CHAT_FRAME, "CHAT_MSG_LOOT", gathered) and #history == 0)
assert(not filters.CHAT_MSG_LOOT(ChatFrame3, "CHAT_MSG_LOOT", gathered))
assert(not filters.CHAT_MSG_LOOT(DEFAULT_CHAT_FRAME, "CHAT_MSG_LOOT", "Other receives loot"))
assert(not filters.CHAT_MSG_SYSTEM(DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", "Quest completed."))
assert(filters.CHAT_MSG_SYSTEM(DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", "Experience gained: 80."))
assert(filters.CHAT_MSG_COMBAT_XP_GAIN(DEFAULT_CHAT_FRAME, "CHAT_MSG_COMBAT_XP_GAIN", "You gain 12 experience."))
event("CHAT_MSG_SYSTEM", "Experience gained: 80.")
event("CHAT_MSG_COMBAT_XP_GAIN", "You gain 12 experience.")
assert(history[1] == "Experience gained: 80." and history[2] == "You gain 12 experience.")
ChatFrame3.isDocked = false
ChatFrame3:Hide()
assert(not filters.CHAT_MSG_LOOT(DEFAULT_CHAT_FRAME, "CHAT_MSG_LOOT", gathered))
advance(19.01)
assert(#model("recentActivity").rows == 4)
dashboard.scripts.OnUpdate(dashboard, 0.02)
local size = activityBar.fill:GetWidth() + activityBar.tip:GetWidth()
assert(math.abs(size - activityBar:GetWidth() * 0.99 / 20) < 0.001)
advance(0.02)
dashboard.scripts.OnUpdate(dashboard, 0.02)
assert(activityBar.fill:GetWidth() + activityBar.tip:GetWidth() < size)
local heightBeforeExpiry = dashboard:GetHeight()
advance(2)
assert(#model("recentActivity").rows == 0)
dashboard.scripts.OnUpdate(dashboard, 0.10)
local heightDuringExpiry = dashboard:GetHeight()
dashboard.scripts.OnUpdate(dashboard, 0.10)
assert(heightBeforeExpiry > heightDuringExpiry and heightDuringExpiry > dashboard:GetHeight(),
    "Expired activity shrinks over successive frames")
level, xp = 11, 20
event("PLAYER_XP_UPDATE", "player")
event("PLAYER_LEVEL_UP")
assert(#model("recentActivity").rows == 1 and model("recentActivity").rows[1].value == "+70")
for i = 1, 5 do
    xp = xp + 10
    event("CHAT_MSG_COMBAT_XP_GAIN", "Spider dies, you gain 10 experience.")
    event("PLAYER_XP_UPDATE", "player")
    if i < 5 then advance(5) end
end
local streak = model("recentActivity").rows
assert(streak[1].label == "Killing spree" and streak[1].value == "5" and streak[1].streakTier == 2)
assert(streak[2].value == "+120")
assert(model("recentActivity").countdown.start == GetTime())
assert(D.Tracking().activityRecords.kills == 5 and D.Tracking().activityRecords.xp == 120)
local inGroup = true
IsInGroup = function() return inGroup end
event("GROUP_ROSTER_UPDATE")
event("CHAT_MSG_COMBAT_XP_GAIN", "Spider dies, you gain 10 experience.")
assert(model("recentActivity").rows[1].label == "Experience")
inGroup = false
event("GROUP_ROSTER_UPDATE")
event("CHAT_MSG_COMBAT_XP_GAIN", "Spider dies, you gain 10 experience.")
assert(model("recentActivity").rows[1].value == "1")
event("PLAYER_DEAD")
assert(model("recentActivity").rows[1].label == "Experience")
assert(D.Tracking().activityRecords.kills == 5)
advance(21)
assert(model("session").rows[1].label == "Level reached")
assert(#warnings == 0)
GetQuestLogSpecialItemInfo = function(index)
    if index == 5 then return "|Hitem:200|h[Quest device]|h", 133469 end
    if index == 6 then return "|Hitem:201|h[Second quest item]|h", 133470 end
end
C_QuestLog.GetLogIndexForQuestID = function(id) return ({[42] = 5, [43] = 6})[id] end
assert(not model("quests").questItems)
D.Settings().showQuestItems = true
event("QUEST_LOG_UPDATE")
local questItem = assert(model("quests").questItems)[1]
assert(questItem.id == "200" and questItem.icon == 133469)
local questButton
for _, object in ipairs(frames) do
    local attrs = rawget(object, "attributes")
    if attrs and attrs.item == "item:200" then questButton = object; break end
end
assert(questButton and questButton.attributes.type == "item" and questButton:GetPoint(1) == "TOPLEFT")
D.Settings().questItemSide = "left"
D.Render()
local side, holder = questButton:GetPoint(1)
assert(side == "TOPRIGHT" and holder:IsShown())
D.Settings().questItemSide = "top"
inside[43] = true
event("QUEST_LOG_UPDATE")
local topAnchor, _, _, topX, topY = holder:GetPoint(1)
local dash = D.GetFrame()
assert(topAnchor == "BOTTOM" and topX == dash:GetLeft() + dash:GetWidth() / 2 and topY == dash:GetTop() + 4)
local _, _, _, firstOffset = questButton:GetPoint(1)
assert(firstOffset == -15.5)
for _, object in ipairs(frames) do
    local attrs = rawget(object, "attributes")
    if attrs and attrs.item == "item:201" then
        local _, _, _, secondOffset = object:GetPoint(1)
        assert(secondOffset == -firstOffset)
        firstOffset = nil
        break
    end
end
assert(firstOffset == nil)
local questTitle
for _, object in ipairs(frames) do
    local cardTitle = rawget(object, "title")
    if cardTitle and cardTitle.text == "Redridge Mountains" then questTitle = cardTitle; break end
end
assert(questTitle and questTitle:IsShown())
local questCard
for _, object in ipairs(frames) do
    if rawget(object, "title") == questTitle then questCard = object; break end
end
D.Settings().growUp = true
D.WidgetSettings("supplies").pinned = true
D.Render()
local _, _, _, _, questOffset = questCard:GetPoint(1)
assert(questOffset < 0, "A recent level-up stays above the local objectives")
advance(120)
D.Invalidate("session")
D.Render()
local _, _, _, _, expiredOffset = questCard:GetPoint(1)
assert(expiredOffset == 0, "Local objectives return to the top when the level-up expires")
D.WidgetSettings("quests").showHeader = false
D.Render()
assert(not questTitle:IsShown() and questButton:IsShown())
D.WidgetSettings("quests").showHeader = true
D.Render()
assert(questTitle:IsShown())
combat = true
D.Render()
assert(questButton.attributes.item == "item:200")
combat = false
inside[42], inside[43] = false, false
event("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED", 42, false)
assert(not model("quests").questItems, "Quest items are shown only in their own objective areas")
assert(not holder:IsShown())
local firstAidRank = 1
C_SkillInfo = {
    GetNumSkillLines = function() return 2 end,
    GetSkillLineInfo = function(index)
        return {skillID = 129, name = "First Aid", currentRank = index == 1 and firstAidRank or 1, maxRank = 75}
    end,
}
D.WidgetSettings("professions").mode = "always"
D.InvalidateSkills()
assert(#model("professions").rows == 1)
firstAidRank = 3
D.InvalidateSkills()
local firstAid = model("professions").rows
assert(#firstAid == 1 and firstAid[1].label == "First Aid" and firstAid[1].value == "3 / 75 (+2)")
advance(21)
D.InvalidateSkills()
assert(not model("professions").activity, "A stale duplicate cannot renew the profession timer")
LOOT_ITEM_CREATED_SELF = "You create: %s."
wipe(D.Tracking().goals)
event("CHAT_MSG_LOOT", "You create: |Hitem:101|h[Crafted item]|hx2.")
local crafting = model("crafting")
assert(#crafting.rows == 1
    and crafting.rows[1].label == "Crafted item" and crafting.rows[1].value == "×2")
assert(#model("recentActivity").rows == 0, "Crafted items have their own card")
event("CHAT_MSG_LOOT", "You receive loot: |Hitem:101|h[Ore]|h.")
assert(D.IsShowingRow("recentActivity", "Ore"))
assert(not D.IsShowingRow("crafting", "Ore"))
advance(21)
assert(#model("crafting").rows == 0)
print("Dashboard providers, settings, previews, combat lifecycle and live Movers passed.")
