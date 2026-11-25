local addon, A, D = BaziUI, BaziUI.Adventure, BaziUI.Dashboard
local call, read = A.Call, A.Read
local J = {categories = {"Character", "Exploration", "Questing", "Professions", "Equipment", "PvE", "PvP", "Notes"}}
addon.Journey = J
local current, skillBaseline, questNames, lastEncounter, runStarted, instanceKey, instanceKnown
local baseline, startedAt, lastSaved
local metrics = {"xp", "earned", "spent", "quest", "deaths", "looted", "materials"}
local sessionEvents = {PLAYER_LOGOUT = true, PLAYER_MONEY = true, PLAYER_XP_UPDATE = true, PLAYER_LEVEL_UP = true,
    QUEST_TURNED_IN = true, PLAYER_DEAD = true, CHAT_MSG_LOOT = true}

function J.Current(create)
    local key = A.Key()
    local data = A.Data()
    if not key or not data then return end
    local entry = data.journals[key]
    if not entry and create then
        entry = {entries = {}, sessions = {}, totals = {}, records = {}, seen = {}, first = A.Now()}
        data.journals[key] = entry
    end
    return entry
end

function J.Prune(journal, now)
    local cfg = A.Settings("journey")
    local cutoff = now - cfg.retention * 86400
    for index = #journal.entries, 1, -1 do
        local entry = journal.entries[index]
        if not entry.milestone and entry.at < cutoff then table.remove(journal.entries, index) end
    end
    while #journal.entries > cfg.limit do
        local remove
        for i, entry in ipairs(journal.entries) do if not entry.milestone then remove = i; break end end
        table.remove(journal.entries, remove or 1)
    end
    while #journal.sessions > 120 do table.remove(journal.sessions, 1) end
end

function J.Record(category, title, milestone, key)
    if not A.Settings("journey").enabled or type(title) ~= "string" or title == "" then return end
    local journal = J.Current(true)
    if not journal then return end
    if key and journal.seen[key] then return end
    if key then
        local size = 0
        for _ in pairs(journal.seen) do size = size + 1 end
        if size >= 2400 then return end
        journal.seen[key] = true
    end
    journal.entries[#journal.entries + 1] = {category = category, title = title, milestone = milestone, at = A.Now()}
    J.Prune(journal, A.Now())
    A.Emit("journal")
end

local function begin()
    if not A.Settings("journey").enabled then return end
    local journal = J.Current(true)
    if not journal then return end
    if current == journal then return current end
    current = journal
    local now = A.Now()
    baseline, startedAt, lastSaved = D.GetSessionMetrics(), GetTime(), 0
    local previous = journal.sessions[#journal.sessions]
    if previous and now >= previous.last and now - previous.last <= 300 then
        journal.active = previous
    else
        local session = {at = now, last = now, seconds = 0}
        journal.sessions[#journal.sessions + 1] = session
        journal.active = session
    end
    J.Record("Character", "First recorded login", true, "login")
    return journal
end

local function increment(journal, key, amount)
    journal.totals[key] = (journal.totals[key] or 0) + amount
    journal.active[key] = (journal.active[key] or 0) + amount
end

local function save(force)
    if not current then return end
    local now = GetTime()
    if not force and now - lastSaved < 15 then return end
    local journal, state = current, D.GetSessionMetrics()
    for _, key in ipairs(metrics) do
        local delta = state[key] - (baseline[key] or 0)
        if delta > 0 then increment(journal, key, delta) end
        baseline[key] = state[key]
    end
    increment(journal, "seconds", math.max(0, math.floor(now - startedAt)))
    journal.active.last, startedAt, lastSaved = A.Now(), now, now
    local active, records = journal.active, journal.records
    records.quests = math.max(records.quests or 0, active.quest or 0)
    if active.seconds >= 900 then
        records.xpHour = math.max(records.xpHour or 0, math.floor((active.xp or 0) * 3600 / active.seconds))
        records.goldHour = math.max(records.goldHour or 0, math.floor((active.earned or 0) * 3600 / active.seconds))
    end
    J.Prune(journal, A.Now())
end

function J.Save()
    if A.Settings("journey").enabled then begin(); save(true) end
end

function J.Reset()
    local data, key = A.Data(), A.Key()
    if data and key then
        data.journals[key] = nil
        current, skillBaseline = nil, nil
        if A.Settings("journey").enabled then begin() end
        A.Emit("journal")
    end
end

A.On("settings", function()
    if A.Settings("journey").enabled then begin()
    elseif current then save(true); current, skillBaseline = nil, nil end
end)
A.On("PLAYER_LOGIN", begin)
A.On("sessionEvent", function(event, ...)
    if not (A.Settings("journey").enabled and sessionEvents[event] and begin()) then return end
    -- A turn-in or level event owns its timeline entry, while Dashboard supplies the counters.
    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        if read(level) and type(level) == "number" then
            increment(current, "levels", 1)
            J.Record("Character", "Reached level " .. level, true, "level:" .. level)
        end
    elseif event == "PLAYER_DEAD" then
        J.Record("Character", "First recorded death", true, "death")
    elseif event == "QUEST_TURNED_IN" then
        local id = ...
        if read(id) and type(id) == "number" then
            local title = call(C_QuestLog and C_QuestLog.GetTitleForQuestID, id) or questNames and questNames[id] or ("Quest #%d"):format(id)
            J.Record("Questing", "Turned in " .. title)
        end
    end
    save(event == "PLAYER_LOGOUT")
end)

A.On("snapshot", function(snapshot, dirty)
    if not (A.Settings("journey").enabled and begin()) then return end
    local meta = snapshot.identity
    if dirty.identity and meta and meta.zone and meta.zone ~= "" then
        current.identity = meta
        J.Record("Exploration", "Visited " .. meta.zone, true, "zone:" .. meta.zone)
        if meta.subzone and meta.subzone ~= "" and meta.subzone ~= meta.zone then
            J.Record("Exploration", "Visited " .. meta.subzone, true, "subzone:" .. meta.zone .. "/" .. meta.subzone)
        end
        local name, kind, difficulty, _, _, _, _, id = call(GetInstanceInfo)
        if read(kind) and read(id) and read(difficulty) and (kind == "party" or kind == "raid" or kind == "pvp") then
            local key = tostring(id) .. ":" .. tostring(difficulty)
            if key ~= instanceKey then
                instanceKey, runStarted, lastEncounter = key, instanceKnown and GetTime() or nil, {}
                J.Record(kind == "pvp" and "PvP" or "PvE", "Entered " .. (name or kind), true, "instance:" .. key)
            end
        else instanceKey, runStarted, lastEncounter = nil, nil, nil end
        instanceKnown = true
    end
    if dirty.quests and addon.QuestTracker and addon.QuestTracker.DashboardQuests then
        local log = addon.QuestTracker.DashboardQuests()
        questNames = {}
        for id, row in pairs(log or {}) do
            if type(id) == "number" and row.info and read(row.info.title) then questNames[id] = row.info.title end
        end
    end
    if dirty.skills and snapshot.skills and next(snapshot.skills) then
        if skillBaseline then
            for name, skill in pairs(snapshot.skills) do
                local old = skillBaseline[name]
                if old and skill.rank > old.rank then
                    if skill.profession then increment(current, "skillPoints", skill.rank - old.rank) end
                    local title = name .. " reached " .. skill.rank
                    local cap = skill.maximum == skill.rank
                    J.Record("Professions", title, cap)
                elseif not old then
                    J.Record("Professions", "First observed " .. name, true, "skill:" .. name)
                end
            end
        end
        skillBaseline = snapshot.skills
    end
    save(false)
end)

A.On("factionAdvanced", function(id, title, rank)
    J.Record("Character", title, true, "faction:" .. id .. ":" .. rank)
end)

A.On("NEW_RECIPE_LEARNED", function(id)
    if not read(id) or type(id) ~= "number" then return end
    local info = call(C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo, id)
    if type(info) == "table" and read(info.name) and type(info.name) == "string" then
        J.Record("Professions", "Learned " .. info.name, true, "recipe:" .. id)
    end
end)

A.On("lootDetails", function(_, _, _, item)
    if not begin() then return end
    if type(item.quality) == "number" and item.quality >= 2 and item.quality <= 5 then
        local quality = ({[2] = "uncommon", [3] = "rare", [4] = "epic", [5] = "legendary"})[item.quality]
        J.Record("Equipment", "First recorded " .. quality .. " item · " .. item.name, true, "quality:" .. item.quality)
    end
    local record = current.records.vendor
    if type(item.price) == "number" and item.price > (record and record.value or 0) then
        current.records.vendor = {value = item.price, name = item.name}
    end
end)

A.On("ENCOUNTER_END", function(id, name, _, _, success)
    if not (read(id) and read(name) and read(success) and success == 1 and type(id) == "number" and type(name) == "string") then return end
    local log = begin()
    if not log then return end
    lastEncounter = lastEncounter or {}
    if lastEncounter[id] and GetTime() - lastEncounter[id] < 10 then return end
    lastEncounter[id] = GetTime()
    increment(log, "bosses", 1)
    local key = "boss:" .. id
    J.Record("PvE", (log.seen[key] and "Defeated " or "First recorded defeat of ") .. name, not log.seen[key], not log.seen[key] and key or nil)
end)

local function completeDungeon(name)
    local log = begin()
    if not log or not instanceKey or log.lastDungeonAt and A.Now() - log.lastDungeonAt < 30 then return end
    log.lastDungeonAt = A.Now()
    local elapsed = runStarted and math.floor(GetTime() - runStarted)
    increment(log, "dungeons", 1)
    J.Record("PvE", "Completed " .. name)
    if elapsed and elapsed >= 60 and (not log.records.fastest or elapsed < log.records.fastest.seconds) then
        log.records.fastest = {name = name, seconds = elapsed}
    end
end
A.On("CHALLENGE_MODE_COMPLETED", function()
    local name = call(GetInstanceInfo)
    if type(name) == "string" then completeDungeon(name) end
end)
A.On("LFG_COMPLETION_REWARD", function()
    local name, kind = call(GetInstanceInfo)
    if read(kind) and kind == "party" and type(name) == "string" then completeDungeon(name) end
end)

A.On("PVP_MATCH_COMPLETE", function(winner)
    if not read(winner) or type(winner) ~= "number" then return end
    local log = begin()
    if not log or log.lastMatch and A.Now() - log.lastMatch < 20 then return end
    log.lastMatch = A.Now()
    local team = call(C_PvP and C_PvP.GetActiveMatchFaction)
    local win = type(team) == "number" and winner == team
    increment(log, "matches", 1)
    if win then increment(log, "wins", 1) end
    local name = call(GetInstanceInfo) or "PvP match"
    J.Record("PvP", (win and "Won " or "Completed ") .. name)
end)
