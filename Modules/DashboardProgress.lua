local addon, D = BaziUI, BaziUI.Dashboard
local call, read = D.Call, D.Read
local objectiveState, questSnapshot, nextCompletion = {}, nil, nil
local function questEvent() questSnapshot = nil end
local function rowsResult(rows, active, activity, title)
    return {rows = rows, active = active, activity = activity, title = title}
end
D.Rows = rowsResult

function D.Pin(kind, key)
    return function()
        local tracking = D.Tracking()
        if tracking then tracking[kind][key] = not tracking[kind][key] or nil end
    end
end

local function smartQuests(options)
    local tracker = addon.QuestTracker
    local q = C_QuestLog
    if not (tracker and q and q.GetQuestObjectives) then return end
    if not questSnapshot then questSnapshot = {tracker.DashboardQuests()} end
    local log, names, mapped, watched = unpack(questSnapshot)
    local tracking = D.Tracking()
    local rows, kept, time = {}, {}, GetTime()
    local duration = D.Settings().completedDuration
    nextCompletion = nil
    for id, entry in pairs(log) do
        if read(id) and type(id) == "number" then
            local localQuest = mapped[id] or entry.zone and names[entry.zone] or not entry.zone and watched[id]
            entry.dashboardObjectives = entry.dashboardObjectives or call(q.GetQuestObjectives, id) or {}
            for index, objective in ipairs(entry.dashboardObjectives) do
                local key = id .. ":" .. index
                local pinned = tracking and tracking.quests[key]
                local label, have, need = objective.text, objective.numFulfilled, objective.numRequired
                local done = read(objective.finished) and objective.finished == true
                if read(label) and type(label) == "string" and label ~= "" then
                    local counted = read(have) and read(need) and type(have) == "number" and type(need) == "number" and need > 0
                    done = done or counted and have >= need
                    local state = objectiveState[key]
                    if done and state and not state.done then state.finishedAt = time end
                    if not state then state = {}; objectiveState[key] = state end
                    state.done, kept[key] = done, true
                    local recent = state.finishedAt and time - state.finishedAt < duration
                    if recent then nextCompletion = math.min(nextCompletion or math.huge, state.finishedAt + duration) end
                    if (localQuest or pinned or options.pinned and watched[id]) and (not done or recent or pinned or options.keepCompleted) then
                        label = label:gsub("^%d+/%d+%s+", ""):gsub("%s*:%s*%d+/%d+$", "")
                        local detail = entry.info.title
                        if counted then detail = ("%s\n%d remaining"):format(detail or "", math.max(0, need - have)) end
                        local row = counted and D.Value(label, have, need, detail)
                            or {label = label, value = done and "Done" or "", tooltip = detail}
                        local itemID = objective.itemID
                        if read(itemID) and type(itemID) == "number" and itemID > 0 then
                            local _, icon, link = D.Item(itemID)
                            row.icon, row.link = icon, link
                        end
                        row.done, row.highlight, row.key = done, recent, key
                        row.pin, row.click = D.Pin("quests", key), function() tracker.OpenQuest(id) end
                        rows[#rows + 1] = row
                    end
                end
            end
        end
    end
    for key in pairs(objectiveState) do if not kept[key] then objectiveState[key] = nil end end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return rowsResult(rows, #rows > 0, #rows > 0, call(GetRealZoneText))
end
D.Register({id = "quests", label = "Local objectives", priority = 80, read = smartQuests, event = questEvent, resync = questEvent,
    tick = function() return nextCompletion and GetTime() >= nextCompletion end,
    events = {"QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED"}})

-- Classic skill-line IDs and the known spell for each profession's window.
local professions = {
    [171] = 2259, [164] = 2018, [185] = 2550, [333] = 7411, [202] = 4036,
    [129] = 3273, [356] = 7620, [182] = 2366, [165] = 2108, [186] = 2575,
    [393] = 8613, [197] = 3908,
}
local skillRecords, skillRows = {}, {}
local skillDirty = true
function D.ResetSkills() wipe(skillRecords); skillDirty = true end
local function skillEvent() skillDirty = true end
local function skillLocale()
    local map = {}
    for id, spell in pairs(professions) do
        local name = call(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spell)
        if type(name) == "string" then map[name] = id end
    end
    return map
end
local function scanSkills()
    if not skillDirty then return skillRows end
    skillDirty = false
    local result, time, locale = {}, GetTime(), skillLocale()
    local function append(id, name, rank, maximum)
        if not (read(name) and read(rank) and read(maximum)) or type(name) ~= "string"
            or type(rank) ~= "number" or type(maximum) ~= "number" or maximum <= 0 or rank <= 0 then return end
        local skillID = professions[id] and id or locale[name]
        local profession = professions[skillID]
        local record = skillRecords[name]
        if not record then record = {start = rank}; skillRecords[name] = record end
        if record.rank and rank > record.rank then record.activity = time end
        record.rank, record.maximum, record.name, record.spell, record.id = rank, maximum, name, profession, skillID
        result[#result + 1] = record
    end
    local api = C_SkillInfo
    local count = call(api and api.GetNumSkillLines) or 0
    if count > 0 then
        for i = 1, count do
            local info = call(api.GetSkillLineInfo, i)
            if type(info) == "table" and read(info.isHeader) and not info.isHeader and read(info.skillID)
                and read(info.currentRank) and read(info.skillRank) and read(info.rank) then
                append(info.skillID, info.name, info.currentRank or info.skillRank or info.rank, info.maxRank)
            end
        end
    end
    if #result == 0 then
        local total = call(GetNumSkillLines) or 0
        for i = 1, total do
            local name, header, _, rank, _, _, maximum = call(GetSkillLineInfo, i)
            if read(header) and not header then append(nil, name, rank, maximum) end
        end
    end
    -- The profession API can expose skill totals even when the skill list is collapsed.
    if #result == 0 then
        for id in pairs(professions) do
            local info = call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
            if type(info) == "table" then append(id, info.professionName, info.skillLevel, info.maxSkillLevel) end
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    skillRows = result
    return result
end

D.ReadSkills = scanSkills
D.InvalidateSkills = skillEvent

local function skills(isProfession, options)
    local rows, relevant, recently, time = {}, false, false, GetTime()
    local tracking = D.Tracking()
    local tracked = tracking and tracking[isProfession and "professions" or "skills"] or {}
    local category, skin
    if isProfession and addon.Gathering.DashboardContext then category, skin = addon.Gathering.DashboardContext() end
    local contextSpell = skin and 8613 or category == "ore" and 2575 or category == "herb" and 2366
    for _, record in ipairs(scanSkills()) do
        if (record.spell ~= nil) == isProfession then
            local pin = tracked[record.name]
            local timely = record.activity and time - record.activity < options.duration
            local nearby = contextSpell and record.spell == contextSpell
            if pin or timely or nearby or isProfession or not D.Settings().hideMaxed or record.rank < record.maximum then
                local row = D.Value(record.name, record.rank, record.maximum)
                local gained = math.max(0, record.rank - record.start)
                if gained > 0 then row.value = row.value .. (" (+%d)"):format(gained) end
                row.highlight = timely or nearby
                row.pin = D.Pin(isProfession and "professions" or "skills", record.name)
                if record.spell then
                    local spell, id = record.spell, record.id
                    row.icon = call(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, spell)
                    if spell ~= 8613 and spell ~= 2366 and spell ~= 7620 and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
                        row.click = function() call(C_TradeSkillUI.OpenTradeSkill, id) end
                    end
                end
                rows[#rows + 1] = row
                relevant, recently = relevant or pin or timely or nearby, recently or timely
            end
        end
    end
    if relevant and options.mode == "automatic" and not options.pinned then
        local shown = {}
        for _, row in ipairs(rows) do if row.highlight or tracked[row.label] then shown[#shown + 1] = row end end
        rows = shown
    end
    return rowsResult(rows, relevant, recently)
end
local skillEvents = {"SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "TRADE_SKILL_LIST_UPDATE"}
D.Register({id = "professions", label = "Professions", priority = 70, tick = true, event = skillEvent, resync = skillEvent, events = skillEvents,
    read = function(options) return skills(true, options) end})
D.Register({id = "skills", label = "Combat skills", priority = 70, tick = true, event = skillEvent, resync = skillEvent, events = skillEvents,
    read = function(options) return skills(false, options) end})

local function validID(value) return type(value) == "number" and value > 0 and value <= 99999999 and value == math.floor(value) end
local function mustBeOutOfCombat() return not InCombatLockdown() end
local itemBaselines = {}

function D.TrackItem(item, target)
    local id = tonumber(item) or type(item) == "string" and tonumber(item:match("item:(%d+)"))
    target = tonumber(target)
    local data = D.Tracking()
    if not data or not validID(id) or not validID(target) or not mustBeOutOfCombat() then return false end
    if not data.items[id] and not D.HasRoom(data.items) then return false end
    data.items[id] = target
    D.Invalidate("items")
    return true
end

function D.HasRoom(entries)
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return count < 30
end

local function items(options)
    local data = D.Tracking()
    local rows = {}
    for id, goal in pairs(data and data.items or {}) do
        local quantity = D.Count(id)
        if quantity ~= nil and (quantity < goal or not options.hideCompleted) then
            itemBaselines[id] = itemBaselines[id] or quantity
            local name, icon, link = D.Item(id)
            local row = D.Value(name, quantity, goal, ("%d remaining, %+d since tracking started"):
                format(math.max(0, goal - quantity), quantity - itemBaselines[id]))
            row.icon, row.link = icon, link
            row.pin = function() data.items[id] = nil; itemBaselines[id] = nil end
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    return rowsResult(rows, true, true)
end
D.Register({id = "items", label = "Tracked items", priority = 50, read = items,
    events = {"BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED"}})
