local loadProject = LOAD_PROJECT or dofile
local wall, monotonic, wallet, playerLevel, experience = 86395, 20, 1000, 5, 80
local grouped, dungeon, rank = false, false, 10
local driver
time = function() return wall end
date = function(_, at) return tostring(math.floor(at / 86400)) end
GetTime = function() return monotonic end
GetMoney = function() return wallet end
UnitLevel = function() return playerLevel end
UnitXP = function() return experience end
UnitXPMax = function() return 100 end
IsInGroup = function() return grouped end
GetInstanceInfo = function()
    if dungeon then return "Test dungeon", "party", 1, nil, nil, nil, nil, 10 end
end
CreateFrame = function()
    return {RegisterEvent = function() end, SetScript = function(_, _, handler) driver = handler end}
end
SlashCmdList = {}
C_Timer = {NewTicker = function() end}
BaziUI = {
    db = {}, Database = {CharacterKey = function() return "Tester" end},
    Inventory = {Money = tostring},
    Dashboard = {
        Call = function(fn, ...) if fn then return fn(...) end end,
        Read = function() return true end,
        ReadSkills = function() return {{name = "Mining", rank = rank, spell = 2575}} end,
        InvalidateSkills = function() end,
        ReadSelfLoot = function() return 1, 2 end,
        Item = function() return nil, nil, nil, nil, 7 end,
        IsKillMessage = function() return true end,
    },
}
local function fire(event, ...) driver(nil, event, ...) end
local function advance(seconds) wall, monotonic = wall + seconds, monotonic + seconds end
loadProject("Modules/ActivityStats.lua")
fire("PLAYER_ENTERING_WORLD")
wallet, playerLevel, experience, rank = 1120, 6, 15, 12
fire("PLAYER_MONEY")
fire("PLAYER_LEVEL_UP")
fire("PLAYER_XP_UPDATE", "player")
fire("CHAT_MSG_LOOT")
fire("SKILL_LINES_CHANGED")
fire("CHAT_MSG_COMBAT_XP_GAIN")
fire("CHAT_MSG_COMBAT_XP_GAIN")
local stats = BaziUI.ActivityStats
local totals = stats.Get("today")
assert(totals.xp == 35 and totals.earned == 120 and totals.looted == 2 and totals.materials == 2)
assert(totals.profession == 2 and totals.kills == 2 and totals.streak == 2)
advance(10)
local today = stats.Get("today")
assert(today.kills == nil and today.time == 5 and totals.time == 5)
assert(stats.Get("session").time == 10)
grouped = true
fire("GROUP_ROSTER_UPDATE")
fire("CHAT_MSG_COMBAT_XP_GAIN")
assert(today.kills == 1 and today.streak == nil)
dungeon = true
fire("PLAYER_LEAVING_WORLD")
fire("PLAYER_ENTERING_WORLD")
fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
assert(today.dungeons == 1 and today.bosses == 1)
fire("PLAYER_LOGOUT")
advance(30)
loadProject("Modules/ActivityStats.lua")
fire("PLAYER_ENTERING_WORLD")
stats = BaziUI.ActivityStats
assert(stats.Get("session").kills == 3 and stats.Get("session").dungeons == 1 and stats.Get("session").time == 10)
stats.ResetSession()
assert(stats.Get("session").kills == nil and stats.Get("today").kills == 1)
print("Activity totals, midnight rollover, and reload continuity passed.")
