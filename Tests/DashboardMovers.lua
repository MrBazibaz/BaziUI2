-- Run from the repository root with Lua. LOAD_PROJECT may supply a sandboxed loader.
local loadProject = LOAD_PROJECT or dofile
local frames, timers, ticks = {}, {}, {}
local time, cursorX, cursorY, combat, down = 100, 0, 0, false, false
local methods = {}
local function noop() end
local prototype = {__index = function(_, key) return methods[key] or noop end}
local function frame()
    local f = setmetatable({shown = true, width = 250, height = 50, scale = 1, points = {}, scripts = {}, events = {}}, prototype)
    frames[#frames + 1] = f
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
function methods:SetHeight(v) self.height = v end
function methods:SetWidth(v) self.width = v end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetScale(scale) self.scale = scale end
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
UIParent = frame()
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
C_QuestLog = {GetQuestObjectives = function()
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
local warnings, panels = {}, {}
BaziUI = {
    db = {profile = {}},
    Print = function(_, msg) warnings[#warnings + 1] = msg end,
    Database = {CharacterKey = function() return key end},
    Theme = {RoundedCard = frame, PaintWindowEdge = noop, SetButtonActive = noop,
        Accent = function() return 0.7, 0.3, 0.8 end, AccentInk = function() return 0.7, 0.3, 0.8, 1 end,
        CreateButton = function(_, _, label) local f = frame(); f:SetText(label); return f end},
    Typography = {Path = function() return "font" end, Apply = noop, Resolve = function() return "font", 12 end},
    Headers = {Text = function() return 1, 1, 1 end},
    Inventory = {
        Window = function(name)
            local f = frame()
            f:Hide()
            f.border, f.closeButton = frame(), frame()
            panels[name] = f
            return f, frame(), frame()
        end,
        Scroll = function() return frame(), frame(), frame() end,
        Label = frame,
        BagIDs = function() return {0} end,
        Money = tostring,
        GetItemInfo = function(id) return "Item " .. id, "item:" .. id, nil, nil, nil, nil, nil, nil, nil, 123, 1, 7 end,
    },
    Gathering = {DashboardContext = function() return "ore", false end},
    HUD = {Settings = function() return {low = 30} end},
    QuestTracker = {
        DashboardQuests = function() return {[42] = {zone = "Redridge Mountains", info = {title = "Capture Eggs"}}},
            {[zone] = true}, {}, {[42] = true} end,
        OpenQuest = noop,
    },
}
for _, file in ipairs({"Dashboard", "DashboardProgress", "DashboardActivity", "DashboardPreview", "Movers"}) do
    loadProject("Modules/" .. file .. ".lua")
end
local D, M = BaziUI.Dashboard, BaziUI.Movers
local function model(id)
    return D.byID[id].read(D.WidgetSettings(id))
end
assert(#D.widgets == 13)
assert(D.PreviewData("dungeon", "dungeon") and not D.PreviewData("dungeon", "raid"))
assert(not D.Settings().enabled)
D.Settings().enabled = true
D.Refresh()
flush()
assert(panels.BaziUIDashboard:IsShown() and #warnings == 0)
assert(model("quests").rows[1].value == "1 / 3")
questCount = 3
event("QUEST_LOG_UPDATE")
assert(model("quests").rows[1].done)
advance(16)
assert(#model("quests").rows == 0)
questCount = 2
zone = "Westfall"
event("ZONE_CHANGED_NEW_AREA")
assert(#model("quests").rows == 0)
zone = "Redridge Mountains"
event("ZONE_CHANGED_NEW_AREA")
skill, profession, faction, bagFree = 21, 61, 170, 0
event("SKILL_LINES_CHANGED")
event("UPDATE_FACTION")
event("BAG_UPDATE_DELAYED")
assert(model("skills").rows[1].value == "21 / 30 (+1)")
assert(model("professions").rows[1].value == "61 / 75 (+1)")
assert(model("reputation").active and model("supplies").active)
advance(61)
assert(not model("skills").active and not model("reputation").active)

assert(D.TrackItem("item:100", 6))
assert(D.TrackRecipe(99, 2))
assert(model("items").rows[1].value == "4 / 6")
assert(model("crafting").rows[1].done)
items[100] = 3
event("BAG_UPDATE_DELAYED")
assert(not model("crafting").rows[1].done)
key = "Character-2"
assert(not next(D.Tracking().goals) and not next(D.Tracking().items))
key = "Character-1"
assert(D.Tracking().goals[99])
event("BAG_UPDATE_DELAYED")
assert(#model("gathering").rows == 0)
event("CHAT_MSG_LOOT", "You receive loot: |cff33ff00|Hitem:101:0|h[Ore]|h|rx2.")
assert(model("gathering").rows[1].value == "1 (+2)")
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

local real = frame()
local coordinates = {x = 10, y = 15}
local function apply() real:SetPoint("CENTER", UIParent, "CENTER", coordinates.x, coordinates.y) end
apply()
local spec = {label = "Real frame", frame = function() return real end, settings = function() return coordinates end, apply = apply}
M.Register(spec)
assert(M.Open(false))
local overlay, driver
for _, f in ipairs(frames) do
    if f.spec == spec and f.scripts.OnDragStart then overlay = f end
    if f.events.PLAYER_REGEN_DISABLED then driver = f end
end
assert(overlay and driver)
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
M.Open(false)
overlay.scripts.OnDragStart(overlay)
cursorX, down = 40, true
driver.scripts.OnUpdate(driver, 0.016)
combat = true
event("PLAYER_REGEN_DISABLED")
combat = false
event("PLAYER_REGEN_ENABLED")
local _, _, _, restoredX = real:GetPoint(1)
assert(restoredX == 10 and coordinates.x == 10)
print("Dashboard providers, settings, previews, combat lifecycle and live Movers passed.")
