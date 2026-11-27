local addon, D = BaziUI, BaziUI.Dashboard
local inventory = addon.Inventory
local Stats = {}
addon.ActivityStats = Stats
local character, session, clock, money, level, xp, cap, instance
local skillRanks, chain, lastKill = {}, 0, nil
local leaving, inWorld
local window
local playedRequested, battlegroundGeneration
local reconnectWindow = 15 * 60
local function now() return time() end
local function day(at) return date("%Y-%m-%d", at) end
local function finite(value)
    return D.Read(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local trace, traceIndex, traceCount
local traceLimit = 48
local function describe(value)
    if not D.Read(value) then return "<restricted>" end
    return value == nil and "—" or tostring(value)
end

local function debugLog(event, ...)
    if not trace then return end
    local fields = {("%.2f %s"):format(GetTime(), event)}
    for i = 1, select("#", ...) do fields[#fields + 1] = describe(select(i, ...)) end
    traceIndex = traceIndex % traceLimit + 1
    trace[traceIndex] = table.concat(fields, " ")
    traceCount = math.min(traceCount + 1, traceLimit)
end

local function daily(at)
    local key = day(at)
    character.days[key] = character.days[key] or {}
    return character.days[key]
end

local function periods(at)
    return {session.totals, daily(at), character.lifetimeStats}
end

local function remember(totals, key, identity)
    totals.seen = totals.seen or {}
    local values = totals.seen[key] or {}
    totals.seen[key] = values
    if not values[identity] then
        values[identity] = true
        totals[key] = (totals[key] or 0) + 1
    end
end

local function addAbility(totals, id, delta)
    totals.abilityDamage = totals.abilityDamage or {}
    local value = (totals.abilityDamage[id] or 0) + delta
    totals.abilityDamage[id] = value
    if value > (totals.deadliestAbility or 0) or value == totals.deadliestAbility and id < totals.deadliestSpellID then
        totals.deadliestAbility, totals.deadliestSpellID = value, id
    end
end

local function betterLoot(item, best)
    return item and (not best or item.quality > best.quality
        or item.quality == best.quality and (item.vendor or 0) > (best.vendor or 0))
end

local maxStats = {streak = true, largestHit = true, largestHeal = true, toughestBattle = true, highestDPS = true}
local uniqueStats = {zones = true, recipes = true, discoveries = true}
local accountRecordMetrics = {
    {"damage", "Damage dealt", "Swords"}, {"honorableKills", "Honorable kills", "Skull"},
    {"streak", "Solo killstreak", "Skull"}, {"bosses", "Bosses defeated", "Laurel"},
    {"materials", "Materials gathered", "Sprig"}, {"crafted", "Items crafted", "AccountCrafting"},
    {"earned", "Money earned", "Coins"}, {"honor", "Honor gained", "Shield"},
    {"levels", "Levels gained", "ChevronUp"}, {"time", "Playtime", "Hourglass"},
}

local function saveSessionRecords(data, totals)
    if not totals then return end
    data.sessionRecords = data.sessionRecords or {}
    for _, metric in ipairs(accountRecordMetrics) do
        local key = metric[1]
        local value = totals[key]
        if finite(value) and value > (data.sessionRecords[key] or 0) then data.sessionRecords[key] = value end
    end
end

local function migrateLifetime(data, at)
    if data.lifetimeStats then return end
    local lifetime, first = {}, day(at)
    for dateKey, old in pairs(data.days or {}) do
        if type(dateKey) == "string" and next(old) and dateKey < first then first = dateKey end
        for key, value in pairs(old) do
            if finite(value) and not uniqueStats[key] and key ~= "deadliestAbility" and key ~= "deadliestSpellID" then
                if maxStats[key] then
                    if value > (lifetime[key] or 0) then
                        lifetime[key], lifetime[key .. "Spell"] = value, old[key .. "Spell"]
                    end
                elseif key == "survivedClosest" then
                    lifetime[key] = math.min(lifetime[key] or value, value)
                else
                    lifetime[key] = (lifetime[key] or 0) + value
                end
            end
        end
        for key, identities in pairs(old.seen or {}) do
            if uniqueStats[key] then
                for identity in pairs(identities) do remember(lifetime, key, identity) end
            end
        end
        for id, value in pairs(old.abilityDamage or {}) do
            if finite(id) and finite(value) and value > 0 then addAbility(lifetime, id, value) end
        end
        if betterLoot(old.bestLoot, lifetime.bestLoot) then lifetime.bestLoot = old.bestLoot end
        if old.valuableLoot and (old.valuableLoot.vendor or 0) > (lifetime.valuableLoot and lifetime.valuableLoot.vendor or 0) then
            lifetime.valuableLoot = old.valuableLoot
        end
    end
    data.lifetimeStats, data.lifetimeStarted = lifetime, first
end

local recordKeys = {kills = true, xp = true, quest = true, bosses = true, honorableKills = true, streak = true,
    net = true, largestHit = true, largestHeal = true, deadliestAbility = true, toughestBattle = true, highestDPS = true,
    gatheredValue = true, lootValue = true, honor = true, materials = true, crafted = true, profession = true,
    levels = true, spellsLearned = true, reputation = true, discoveries = true, flightPaths = true}

local function updatePersonalBest(key, value, today, dateKey)
    if not recordKeys[key] or value <= 0 then return end
    local best = character.records[key]
    if not best then
        character.records[key] = {value = value, baselineDay = dateKey}
    elseif value > best.value then
        best.value = value
        if best.baselineDay ~= dateKey then
            today.personalBests = today.personalBests or {}
            session.totals.personalBests = session.totals.personalBests or {}
            today.personalBests[key], session.totals.personalBests[key] = value, value
        end
    end
end

local function record(key, value, maximum)
    if not session or not finite(value) or value <= 0 then return end
    local at = now()
    local buckets = periods(at)
    local today = buckets[2]
    for _, totals in ipairs(buckets) do
        totals[key] = maximum and math.max(totals[key] or 0, value) or (totals[key] or 0) + value
    end
    if key == "earned" then updatePersonalBest("net", (today.earned or 0) - (today.spent or 0), today, day(at)) end
    updatePersonalBest(key, today[key], today, day(at))
end

local function checkpoint()
    if not session or not inWorld then return end
    local at = now()
    local seconds = math.max(0, math.min(20, at - clock))
    session.lastSeen = at
    session.totals.time = (session.totals.time or 0) + seconds
    character.lifetimeStats.time = (character.lifetimeStats.time or 0) + seconds
    if instance then
        session.totals.dungeonTime = (session.totals.dungeonTime or 0) + seconds
        local lifetime = character.lifetimeStats
        lifetime.dungeonTime = (lifetime.dungeonTime or 0) + seconds
    end
    -- A heartbeat can span local midnight, so assign each part to its actual day.
    for second = at - seconds, at - 1 do
        local totals = daily(second)
        totals.time = (totals.time or 0) + 1
        if instance then totals.dungeonTime = (totals.dungeonTime or 0) + 1 end
    end
    clock = at
    saveSessionRecords(character, session.totals)
end

local function sampleXP()
    local currentLevel, currentXP, currentCap = D.Call(UnitLevel, "player"),
        D.Call(UnitXP, "player"), D.Call(UnitXPMax, "player")
    if type(currentLevel) ~= "number" or type(currentXP) ~= "number" then return end
    if currentLevel == level then record("xp", currentXP - xp)
    elseif level and currentLevel > level then
        record("levels", currentLevel - level)
        if currentLevel == level + 1 then record("xp", (cap or xp) - xp + currentXP) end
    end
    level, xp, cap = currentLevel, currentXP, currentCap
end

local function sampleSkills(baseline)
    D.InvalidateSkills()
    for _, skill in ipairs(D.ReadSkills()) do
        local previous = skillRanks[skill.name]
        if previous and not baseline then
            record(skill.spell and "profession" or "skill", skill.rank - previous)
        end
        skillRanks[skill.name] = skill.rank
    end
end

local function sampleInstance()
    local _, kind, difficulty, _, _, _, _, id = D.Call(GetInstanceInfo)
    local current = kind == "party" and id and (id .. ":" .. (difficulty or 0)) or false
    if current and current ~= instance then record("dungeons", 1) end
    instance, session.instance = current, current
end

local function openSession()
    local key = addon.Database:CharacterKey()
    if not key then return end
    local db, at = addon.db, now()
    db.activityStats = db.activityStats or {}
    db.activityStats[key] = db.activityStats[key] or {days = {}}
    character = db.activityStats[key]
    migrateLifetime(character, at)
    saveSessionRecords(character, character.session and character.session.totals)
    if not character.records then
        character.records = {}
        for dateKey, totals in pairs(character.days) do
            for stat in pairs(recordKeys) do
                local value = stat == "net" and (totals.earned or 0) - (totals.spent or 0) or totals[stat]
                local best = character.records[stat]
                if value and value > 0 and (not best or value > best.value
                    or value == best.value and dateKey < best.baselineDay) then
                    character.records[stat] = {value = value, baselineDay = dateKey}
                end
            end
        end
    end
    session = character.session
    if not session or session.closed or at - (session.lastSeen or 0) > reconnectWindow then
        session = {totals = {}, lastSeen = at}
        character.session = session
    end
    clock, money, instance = at, D.Call(GetMoney), session.instance
    sampleXP()
    sampleSkills(true)
end

local function rememberUnique(key, identity)
    if not session or not identity then return end
    for _, totals in ipairs(periods(now())) do remember(totals, key, identity) end
end

local function visitZone()
    local id = D.Call(C_Map and C_Map.GetBestMapForUnit, "player")
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    if id and zoneType then
        for _ = 1, 6 do
            local map = D.Call(C_Map.GetMapInfo, id)
            if not map then break end
            if map.mapType == zoneType then rememberUnique("zones", id); return end
            if not map.parentMapID or map.parentMapID == 0 then break end
            id = map.parentMapID
        end
    end
    local name = D.Call(GetRealZoneText)
    if type(name) == "string" and name ~= "" then rememberUnique("zones", name) end
end

local itemQueue = {}
local function inspectLoot(item)
    local name, itemLink, quality, level, _, _, _, _, _, icon, vendor, class =
        D.Call(inventory.GetItemInfo, item.link or item.id)
    if not D.Read(name) or type(name) ~= "string" or not D.Read(quality) then return false end
    local effective = D.Call(C_Item and C_Item.GetDetailedItemLevelInfo, item.link or itemLink or item.id)
    if type(quality) ~= "number" then return false end
    vendor = finite(vendor) and vendor >= 0 and vendor or nil
    level = finite(effective) and effective or finite(level) and level or nil
    if not finite(class) then
        local _, _, _, _, fallback = D.Item(item.id)
        class = finite(fallback) and fallback or nil
    end
    local material = item.gathered or class == 7 or class == 5
    local loot = {id = item.id, link = item.link or itemLink, name = name, quality = quality,
        icon = icon, level = level, vendor = vendor}
    for _, totals in ipairs(item.buckets) do
        local key = quality == 1 and "common" or quality == 2 and "uncommon" or quality == 3 and "rare"
            or quality == 4 and "epic" or quality == 5 and "legendary"
        if key and not item.counted then totals[key] = (totals[key] or 0) + item.count end
        if material and not item.materialCounted then
            totals.materials = (totals.materials or 0) + item.count
            totals.materialCounts = totals.materialCounts or {}
            local previous = totals.materialCounts[item.id]
            local amount = (previous or 0) + item.count
            totals.materialCounts[item.id] = amount
            if not previous then totals.materialTypes = (totals.materialTypes or 0) + 1 end
            local top = totals.topMaterial
            if not top or amount > top.count or amount == top.count and item.id < top.id then
                totals.topMaterial = {id = loot.id, link = loot.link, name = loot.name, icon = loot.icon,
                    quality = loot.quality, count = amount}
            end
        end
        if vendor then
            local value = vendor * item.count
            totals.lootValue = (totals.lootValue or 0) + value
            totals.valuedLoot = (totals.valuedLoot or 0) + item.count
            if material then
                totals.gatheredValue = (totals.gatheredValue or 0) + value
                totals.valuedMaterials = (totals.valuedMaterials or 0) + item.count
            end
        end
        if betterLoot(loot, totals.bestLoot) then
            totals.bestLoot = loot
        end
        if vendor and vendor > 0 and (not totals.valuableLoot or vendor > (totals.valuableLoot.vendor or 0)) then
            totals.valuableLoot = loot
        end
    end
    if item.sessionTotals == session.totals then
        local today = item.buckets[2]
        for _, key in ipairs({"materials", "lootValue", "gatheredValue"}) do
            if today[key] then updatePersonalBest(key, today[key], today, item.date) end
        end
    end
    saveSessionRecords(character, item.sessionTotals)
    item.counted, item.materialCounted = true, material or item.materialCounted
    return vendor ~= nil
end

local function flushLoot(id, loaded)
    local pending = itemQueue[id]
    if not pending then return end
    itemQueue[id] = nil
    if loaded then
        for _, item in ipairs(pending) do inspectLoot(item) end
    end
end

local meterBase, spellBase, fight, finishingFight, eliteTarget = {}, nil, nil, nil, nil
local combatStats = {DamageDone = "damage", DamageTaken = "damageTaken", HealingDone = "healing", Interrupts = "interrupts"}
local function meterPlayer(data)
    local sources = type(data) == "table" and data.combatSources
    if not D.Read(sources) or type(sources) ~= "table" then return end
    local guid = D.Call(UnitGUID, "player")
    for _, source in ipairs(sources) do
        if D.Read(source.isLocalPlayer) and source.isLocalPlayer == true
            or guid and D.Read(source.sourceGUID) and source.sourceGUID == guid then
            return source, true
        end
        if not D.Read(source.isLocalPlayer) then return end
    end
    return nil, true
end

local function spellSnapshot(api, scope, mode, source)
    if not source then return {} end
    local guid, creature = source.sourceGUID, source.sourceCreatureID
    if not D.Read(guid) or not guid then guid = D.Call(UnitGUID, "player") end
    if not D.Read(creature) then creature = nil end
    if not guid and not creature then return end
    local data = D.Call(api.GetCombatSessionSourceFromType, scope, mode, guid, creature)
    local spells = type(data) == "table" and data.combatSpells
    if not D.Read(spells) or type(spells) ~= "table" then return end
    local totals = {}
    for _, spell in ipairs(spells) do
        local id, amount = spell.spellID, spell.totalAmount
        if not finite(id) or not finite(amount) or amount < 0 then return end
        totals[id] = (totals[id] or 0) + amount
    end
    return totals
end

local function tallySpells(current, baseline)
    if not current then
        if baseline then spellBase = nil end
        return
    end
    local previous = spellBase
    spellBase = current
    if baseline or not previous then return end
    for id, amount in pairs(previous) do
        if (current[id] or 0) < amount then return end
    end
    local at = now()
    local buckets = periods(at)
    local today = buckets[2]
    for id, amount in pairs(current) do
        local delta = amount - (previous[id] or 0)
        if delta > 0 then
            for _, totals in ipairs(buckets) do addAbility(totals, id, delta) end
        end
    end
    if today.deadliestAbility then updatePersonalBest("deadliestAbility", today.deadliestAbility, today, day(at)) end
end

local function sampleCombat(baseline)
    local api, types = C_DamageMeter, Enum and Enum.DamageMeterType
    local scope = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall
    if not (api and types and scope and api.GetCombatSessionFromType) then return end
    if D.Call(InCombatLockdown) then
        if baseline then meterBase, spellBase = {}, nil end
        return
    end
    for mode, stat in pairs(combatStats) do
        local data = types[mode] and D.Call(api.GetCombatSessionFromType, scope, types[mode])
        local source, readable = meterPlayer(data)
        if readable then
            local total = not source and 0 or finite(source.totalAmount) and source.totalAmount or nil
            if not baseline and total and meterBase[stat] and total >= meterBase[stat] then
                debugLog("Meter total delta", stat, total - meterBase[stat])
                record(stat, total - meterBase[stat])
            end
            if total or baseline then meterBase[stat] = total end
            if stat == "damage" then tallySpells(spellSnapshot(api, scope, types[mode], source), baseline) end
        elseif stat == "damage" and baseline then
            spellBase = nil
        end
    end
end

local function meterSessionIDs()
    local api = C_DamageMeter
    local sessions = D.Call(api and api.GetAvailableCombatSessions)
    if type(sessions) ~= "table" then return end
    local ids = {}
    for _, item in ipairs(sessions) do
        if not finite(item.sessionID) then return end
        ids[item.sessionID] = true
    end
    return ids
end

local function commitFight(completed)
    if finishingFight ~= completed then return end
    finishingFight = nil
    if completed.session ~= session then return end
    local survived = not completed.died and D.Call(UnitIsDeadOrGhost, "player") == false
    for _, totals in ipairs(completed.buckets) do
        totals.battles = (totals.battles or 0) + 1
        if survived then totals.battlesSurvived = (totals.battlesSurvived or 0) + 1 end
    end
    local ids, id = meterSessionIDs()
    if ids and completed.before then
        for candidate in pairs(ids) do
            if not completed.before[candidate] then
                if id then return end
                id = candidate
            end
        end
    end
    local api, types = C_DamageMeter, Enum and Enum.DamageMeterType
    if not (id and api and types) then return end
    local function battleRecord(key, value)
        if not finite(value) or value <= 0 then return end
        for _, totals in ipairs(completed.buckets) do
            totals[key] = math.max(totals[key] or 0, value)
        end
        updatePersonalBest(key, completed.today[key], completed.today, completed.date)
    end
    local outgoing = types.DamageDone and meterPlayer(D.Call(api.GetCombatSessionFromID, id, types.DamageDone))
    local dps = outgoing and outgoing.amountPerSecond
    battleRecord("highestDPS", dps)
    if survived then
        local incoming = types.DamageTaken and meterPlayer(D.Call(api.GetCombatSessionFromID, id, types.DamageTaken))
        local amount = incoming and incoming.totalAmount
        battleRecord("toughestBattle", amount)
        debugLog("Toughest Battle", "session ID", id, "damage taken", amount)
    end
    if Stats.RefreshReport then Stats.RefreshReport() end
end

local function closeFight()
    debugLog("Combat end")
    if not fight then return end
    local completed = fight
    local at = now()
    completed.session, completed.buckets, completed.date = session, periods(at), day(at)
    completed.today = completed.buckets[2]
    fight, finishingFight = nil, completed
    C_Timer.After(1.5, function()
        if not fight then
            sampleCombat(false)
            commitFight(completed)
            if Stats.RefreshReport then Stats.RefreshReport() end
        end
    end)
end

-- Only use individual combat events when the client actually exposes them.
local damageEvents = {SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true, SPELL_BUILDING_DAMAGE = true, DAMAGE_SHIELD = true, DAMAGE_SPLIT = true}

local function trackIndividualHit(value, crit, name, id, healing)
    if not finite(value) or value <= 0 then return end
    if not healing and D.Read(crit) and crit == true then record("criticals", 1) end
    local key = healing and "largestHeal" or "largestHit"
    local at = now()
    local buckets = periods(at)
    local today = buckets[2]
    local metadata
    for _, totals in ipairs(buckets) do
        if value > (totals[key] or 0) then
            if not metadata then
                local icon = id and D.Call(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, id)
                if not name and id then name = D.Call(C_Spell and C_Spell.GetSpellName, id) end
                metadata = {name = name, icon = icon}
            end
            totals[key], totals[key .. "Spell"] = value, metadata
        end
    end
    updatePersonalBest(key, today[key], today, day(at))
    debugLog(healing and "Largest Heal" or "Largest Hit", "today", today[key], "session", session.totals[key])
end

local function readCombatEvent()
    if not CombatLogGetCurrentEventInfo then return end
    local ok, _, event, _, source, _, _, _, target, _, _, _, first, second, third, amount, _, _, swingCrit, _, _, spellCrit =
        pcall(CombatLogGetCurrentEventInfo)
    if not ok or not D.Read(event) or type(event) ~= "string" then return end
    local guid = D.Call(UnitGUID, "player")
    if not guid then return end
    local outgoing = D.Read(source) and source == guid
    local incoming = D.Read(target) and target == guid
    if event == "PARTY_KILL" and eliteTarget and D.Read(target) and target == eliteTarget then
        if outgoing then record("eliteKills", 1) end
    elseif damageEvents[event] or event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
        local swing = event == "SWING_DAMAGE"
        local healing = event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL"
        local value = amount
        if swing then value = first end
        local crit
        if swing or healing then crit = swingCrit else crit = spellCrit end
        if outgoing or incoming then debugLog(outgoing and "Outgoing" or "Incoming", event, "amount", value, "critical", crit) end
        if not outgoing then return end
        local id = not swing and finite(first) and first or nil
        local name = swing and (ATTACK or "Melee") or D.Read(second) and type(second) == "string" and second or nil
        trackIndividualHit(value, crit, name, id, healing)
    end
end

local selfDamageMessages = {
    CHAT_MSG_COMBAT_SELF_HITS = {{"COMBATHITSELFOTHER", 2}, {"COMBATHITCRITSELFOTHER", 2, true}},
    CHAT_MSG_SPELL_SELF_DAMAGE = {{"SPELLLOGSELFOTHER", 3}, {"SPELLLOGCRITSELFOTHER", 3, true}},
}

local function readSelfDamage(event, message)
    if not D.Read(message) or type(message) ~= "string" then
        debugLog("Outgoing", event, "message", message)
        return
    end
    if message:find("|K", 1, true) then
        debugLog("Outgoing", event, "protected text")
        return
    end
    for _, format in ipairs(selfDamageMessages[event]) do
        local template = _G[format[1]]
        if template then
            local amount = D.MatchChatFormat(message, template, false, format[2])
            if amount then
                local melee = format[2] == 2
                local name = melee and (ATTACK or "Melee") or D.MatchChatFormat(message, template, false, 1)
                local info = not melee and D.Call(C_Spell and C_Spell.GetSpellInfo, name)
                debugLog("Outgoing", event, name, "amount", amount, "critical", format[3] or false)
                local id = type(info) == "table" and info.spellID
                trackIndividualHit(tonumber(amount), format[3], name, finite(id) and id or nil)
                return
            end
        end
    end
    debugLog("Outgoing", event, "no readable hit match")
end

local function scoreBattleground(winner)
    local api = C_PvP
    if not session or not D.Call(api and api.IsBattleground) or session.battlegroundScored then return end
    session.battlegroundScored = true
    record("battlegrounds", 1)
    local currentSession, at = session, now()
    local generation, totals = battlegroundGeneration, periods(at)
    local winningFaction = finite(winner) and winner or nil
    local function readScore()
        if session ~= currentSession or generation ~= battlegroundGeneration
            or not currentSession.battlegroundScored or not D.Call(api.IsBattleground) then return true end
        local guid = D.Call(UnitGUID, "player")
        local score = guid and D.Call(api.GetScoreInfoByPlayerGuid, guid)
        if type(score) ~= "table" or not finite(score.killingBlows) or not finite(score.deaths) then return false end
        for _, bucket in ipairs(totals) do
            bucket.scoredBattles = (bucket.scoredBattles or 0) + 1
            bucket.killingBlows = (bucket.killingBlows or 0) + score.killingBlows
            bucket.pvpDeaths = (bucket.pvpDeaths or 0) + score.deaths
            if (winningFaction == 0 or winningFaction == 1) and finite(score.faction)
                and (score.faction == 0 or score.faction == 1) then
                local key = winningFaction == score.faction and "bgWins" or "bgLosses"
                bucket[key] = (bucket[key] or 0) + 1
            end
        end
        if Stats.RefreshReport then Stats.RefreshReport() end
        return true
    end
    if not readScore() then
        C_Timer.After(1, readScore)
    end
end

local merchant
local function readBuybacks()
    local count = D.Call(GetNumBuybackItems)
    if type(count) ~= "number" then return end
    local entries = {}
    for i = 1, count do
        local name, _, value, stack = D.Call(GetBuybackItemInfo, i)
        local link = D.Call(GetBuybackItemLink, i) or name
        if type(link) ~= "string" or not D.Read(value) or type(value) ~= "number" or not D.Read(stack) then return end
        entries[i] = {key = link .. ":" .. tostring(stack) .. ":" .. value, value = value}
    end
    return entries
end

local function reconcileMerchant(state)
    if merchant ~= state then return end
    state.queued = false
    local entries, before = readBuybacks(), state.entries
    if entries and before and #entries >= #before then
        -- Buyback entries are ordered oldest to newest. Match the retained suffix.
        for drop = 0, #before do
            local kept = #before - drop
            local matching = kept <= #entries
            for i = 1, kept do
                if not matching or before[drop + i].key ~= entries[i].key then matching = false; break end
            end
            if matching and (kept > 0 or #before == 0) then
                local sold = 0
                for i = kept + 1, #entries do sold = sold + entries[i].value end
                if sold > 0 and sold == state.credits then record("vendor", sold) end
                break
            end
        end
    end
    if state.repairQuote and state.repairQuote == state.debits then record("repair", state.debits) end
    state.entries = entries or before
    state.cost = D.Call(GetRepairAllCost)
    state.credits, state.debits, state.repairQuote = 0, 0, nil
end

local function queueMerchant()
    local state = merchant
    if not state or state.queued then return end
    state.queued = true
    C_Timer.After(0.18, function() reconcileMerchant(state) end)
end

if RepairAllItems then
    hooksecurefunc("RepairAllItems", function(guildBank)
        if merchant and not guildBank and type(merchant.cost) == "number" and merchant.cost > 0 then
            merchant.repairQuote = merchant.cost
            queueMerchant()
        end
    end)
end

function Stats.RecordCleanupDiscard(count)
    record("discarded", count)
end

local function isGrouped()
    return IsInGroup and (IsInGroup() or LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE))
end

local function fmtTime(seconds)
    return ("%02d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function requestLifetime()
    if not character or playedRequested or type(RequestTimePlayed) ~= "function" then return end
    if character.lifetimeUpdated and now() - character.lifetimeUpdated < 12 * 3600 then return end
    playedRequested = true
    pcall(RequestTimePlayed)
end

local function fmtNet(copper)
    return (copper < 0 and "−" or "+") .. inventory.Money(math.abs(copper))
end

local function ratio(kills, deaths)
    if deaths > 0 then return ("%.2f"):format(kills / deaths) end
    if kills > 0 then return ("%d / 0"):format(kills) end
    return "0"
end

local assets = "Interface\\AddOns\\BaziUI\\Assets\\"
local art = assets .. "Icons\\Bazi\\"
local sections = {
    {"Combat", "Dagger", {{"Enemies killed", "kills"}, {"Deaths", "deaths"}, {"Kill/Death ratio", "kd"},
        {"Honorable kills", "honorableKills"}, {"Best solo killstreak", "streak"},
        {"PvP killing blows", "killingBlows"}, {"PvP deaths", "pvpDeaths"}, {"Battleground K/D", "pvpRatio"},
        {"Highest DPS", "highestDPS", function(value) return ("%.1f"):format(value) end},
        {"Damage dealt", "damage"}, {"Damage taken", "damageTaken"}, {"Healing done", "healing"},
        {"Interrupts", "interrupts"}, {"Elite kills", "eliteKills"}, {"Largest heal", "largestHeal"},
        {"Near-death experiences", "nearDeath"}, {"Combats finished", "battles"},
        {"Combats survived", "battlesSurvived"}, {"Kills per hour", "killsRate"}}},
    {"Gathering", "Sprig", {{"Veins mined", "veins"}, {"Herbs picked", "herbs"}, {"Creatures skinned", "skinned"},
        {"Materials gathered", "materials"}, {"Profession skill gains", "profession"},
        {"Gathering value", "gatheredValue", inventory.Money}, {"Most gathered", "topMaterial"},
        {"Gathering actions", "gatherActions"}, {"Material types tracked", "materialTypes"}, {"Materials per hour", "materialRate"}}},
    {"Progression", "ChevronUp", {{"Levels gained", "levels"}, {"Experience gained", "xp"}, {"Experience per hour", "xpPerHour"},
        {"Reputation gained", "reputation"},
        {"Recipes learned", "recipes"}, {"Spells learned", "spellsLearned"}, {"Items crafted", "crafted"},
        {"Combat skill gains", "skill"}, {"Honor gained", "honor"}}},
    {"Adventuring", "Pin", {{"Dungeons entered", "dungeons"}, {"Bosses defeated", "bosses"}, {"Zones visited", "zones"},
        {"Quests completed", "quest"}, {"New areas discovered", "discoveries"}, {"Flight paths unlocked", "flightPaths"},
        {"Battlegrounds played", "battlegrounds"}, {"Battlegrounds won", "bgWins"}, {"Battlegrounds lost", "bgLosses"},
        {"Battleground win rate", "winRate"}, {"Dungeon playtime", "dungeonTime", fmtTime},
        {"Quests per hour", "questRate"}, {"Bosses per hour", "bossRate"}}},
    {"Loot", "Chest", {{"Items looted", "looted"}, {"Total loot value", "lootValue", inventory.Money},
        {"Uncommon items", "uncommon"}, {"Rare items", "rare"}, {"Epic items", "epic"}, {"Legendary items", "legendary"},
        {"Best loot", "bestLoot"}, {"Most valuable loot", "valuableLoot", inventory.Money}, {"Common items", "common"},
        {"Items discarded via Cleanup", "discarded"}, {"Items looted per hour", "lootRate"}}},
    {"Economy", "Coins", {{"Money earned", "earned", inventory.Money}, {"Money spent", "spent", inventory.Money},
        {"Vendor sales", "vendor", inventory.Money}, {"Repair costs", "repair", inventory.Money},
        {"Quest money rewards", "questMoney", inventory.Money}, {"Looted money", "lootedMoney", inventory.Money},
        {"Net money", "net", fmtNet}, {"Net money per hour", "moneyPerHour", fmtNet}}},
}

local gatheringSpells = {
    [2575] = "veins", [2576] = "veins", [3564] = "veins", [10248] = "veins",
    [2366] = "herbs", [2368] = "herbs", [3570] = "herbs", [11993] = "herbs",
    [8613] = "skinned", [8617] = "skinned", [8618] = "skinned", [10768] = "skinned",
}
local lastGatherCast, lastVein

function Stats.Get(scope)
    if not session then return {} end
    checkpoint()
    if scope == "lifetime" then return character.lifetimeStats end
    return scope == "today" and daily(now()) or session.totals
end

local panelWidth, panelHeight = 984, 690
local exitPanels = {}
local activeExit, retainedExit, exitEscape
local scopeLabels = {session = "Session", today = "Today", lifetime = "Lifetime", account = "Account"}
local scopeOrder = {"session", "today", "lifetime", "account"}
local rowsPerCard = 8
local coreRows = {kills = true, deaths = true, kd = true, honorableKills = true, streak = true,
    veins = true, herbs = true, skinned = true, materials = true, profession = true,
    levels = true, xp = true, recipes = true, spellsLearned = true, crafted = true,
    dungeons = true, bosses = true, zones = true, quest = true,
    looted = true, lootValue = true, rare = true, epic = true, earned = true, spent = true, net = true}
local zeroRows = {kills = true, deaths = true, streak = true, veins = true, herbs = true, skinned = true,
    materials = true, profession = true, levels = true, xp = true, recipes = true, crafted = true, skill = true,
    dungeons = true, bosses = true, zones = true, quest = true, looted = true, uncommon = true, common = true,
    rare = true, epic = true, legendary = true, discarded = true, battles = true, battlesSurvived = true, materialTypes = true,
    dungeonTime = true, battlegrounds = true, honorableKills = true, honor = true, spellsLearned = true,
    earned = true, spent = true, net = true, vendor = true, repair = true, questMoney = true, lootedMoney = true}
local achievementMilestones = {
    {"quest", {50, 25, 10, 5}, "%s quests completed"},
    {"kills", {250, 100, 50, 25}, "%s enemies defeated"},
    {"profession", {100, 50, 25, 10}, "%s profession skill gains"},
}
local lifetimeMilestones = {
    {"quest", {1000, 500, 250, 100, 50, 10, 5}, "%s quests completed"},
    {"kills", {10000, 5000, 1000, 500, 250, 50, 25}, "%s enemies defeated"},
    {"profession", {500, 250, 100, 50, 25, 10}, "%s profession skill gains"},
}

local function numeral(n)
    if not finite(n) then return "—" end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

local rateFields = {xpPerHour = "xp", moneyPerHour = "net", killsRate = "kills", materialRate = "materials",
    questRate = "quest", bossRate = "bosses", lootRate = "looted"}

local function statValue(totals, key)
    if key == "bestLoot" then return totals.bestLoot and totals.bestLoot.name end
    if key == "topMaterial" then
        local item = totals.topMaterial
        if item then return item.name end
    end
    if key == "valuableLoot" then return totals.valuableLoot and totals.valuableLoot.vendor end
    if key == "kd" then return ratio(totals.kills or 0, totals.deaths or 0) end
    if key == "pvpRatio" then
        if (totals.scoredBattles or 0) > 0 and totals.scoredBattles == totals.battlegrounds then
            return ratio(totals.killingBlows or 0, totals.pvpDeaths or 0)
        end
    end
    if key == "bgWins" or key == "bgLosses" then
        if (totals.battlegrounds or 0) == 0 then return 0 end
    end
    if key == "winRate" then
        local wins, losses = totals.bgWins or 0, totals.bgLosses or 0
        if wins + losses > 0 and wins + losses == totals.battlegrounds then
            return ("%.0f%%"):format(wins * 100 / (wins + losses))
        end
    end
    if key == "gatherActions" then return (totals.veins or 0) + (totals.herbs or 0) + (totals.skinned or 0) end
    if key == "lootValue" or key == "gatheredValue" then
        local gathering = key == "gatheredValue"
        local count = (gathering and totals.materials or not gathering and totals.looted) or 0
        if count == 0 then return 0 end
        local priced = gathering and totals.valuedMaterials or not gathering and totals.valuedLoot
        if finite(totals[key]) and (priced or 0) < count then return "≥ " .. inventory.Money(totals[key]) end
    end
    local net = (totals.earned or 0) - (totals.spent or 0)
    if key == "net" then return net end
    local base = rateFields[key]
    if base then
        local total = base == "net" and net or totals[base] or 0
        if total == 0 then return 0 end
        return (totals.time or 0) >= 60 and math.floor(total * 3600 / totals.time) or "Collecting"
    end
    return totals[key] or (zeroRows[key] and 0 or nil)
end

local function qualityColor(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return color and color.r or 1, color and color.g or 0.83, color and color.b or 0.49
end

local function abilityInfo(id)
    local spell = C_Spell
    local name, icon
    if finite(id) then
        local lookup = id == 0 and 6603 or id
        local info = D.Call(spell and spell.GetSpellInfo, lookup)
        if type(info) == "table" then
            name = D.Read(info.name) and info.name
            icon = D.Read(info.iconID) and info.iconID
        elseif GetSpellInfo then
            local legacyName, _, legacyIcon = D.Call(GetSpellInfo, lookup)
            name, icon = legacyName, D.Read(legacyIcon) and legacyIcon
        end
        name = name or (id == 0 and (ATTACK or "Melee") or ("Spell #%d"):format(id))
    end
    return name, icon or nil
end

-- Each threshold is in the units of its statistic. Adjacent entries need not
-- share a category, and a record or a rare find can outrank the dominant activity.
local highlightRules = {
    {"quest", "Quests Completed", "Quest", "progress", 3, 32, "Quests turned in"},
    {"levels", "Levels Gained", "ChevronUp", "progress", 1, 46, "Character levels"},
    {"xp", "Experience Gained", "XP", "progress", 1000, 17, "Experience earned"},
    {"spellsLearned", "Spells Learned", "Quest", "progress", 3, 29, "Abilities and spell ranks"},
    {"reputation", "Reputation Gained", "Star", "progress", 250, 24, "Reputation points"},
    {"kills", "Enemies Defeated", "Swords", "combat", 20, 25, "XP-yielding enemies"},
    {"streak", "Best Killstreak", "Skull", "combat", 5, 38, "Consecutive solo kills"},
    {"deadliestAbility", "Deadliest Ability", "Swords", "combat", 150, 34, nil, "damage"},
    {"damage", "Damage Dealt", "Swords", "combat", 500, 15, "Total outgoing damage", "damage"},
    {"highestDPS", "Highest DPS", "Dagger", "combat", 10, 25, "Best completed fight"},
    {"toughestBattle", "Toughest Battle", "Shield", "combat", 100, 31, "Damage taken in a survived fight", "survival"},
    {"damageTaken", "Damage Taken", "Shield", "combat", 500, 10, "Total incoming damage", "survival"},
    {"healing", "Healing Done", "Heart", "combat", 350, 25, "Total healing"},
    {"largestHeal", "Largest Heal", "Heart", "combat", 200, 24, "Strongest individual heal"},
    {"interrupts", "Interrupts", "Shield", "combat", 3, 24, "Enemy casts stopped"},
    {"eliteKills", "Elites Defeated", "Skull", "combat", 2, 29, "Elite enemy kills"},
    {"honorableKills", "Honorable Kills", "Swords", "pvp", 5, 34, "Honorable kills earned"},
    {"honor", "Honor Gained", "Shield", "pvp", 50, 35, "Honor earned"},
    {"pvpRatio", "Battleground K/D", "Skull", "pvp", 3, 34, nil, "pvpKills"},
    {"killingBlows", "Killing Blows", "Dagger", "pvp", 3, 28, "Battleground killing blows", "pvpKills"},
    {"bgWins", "Battleground Wins", "Laurel", "pvp", 1, 39, "Matches won"},
    {"battlegrounds", "Battlegrounds", "Shield", "pvp", 2, 25, "Matches completed"},
    {"veins", "Veins Mined", "Sprig", "gathering", 4, 29, "Mining nodes"},
    {"herbs", "Herbs Picked", "Sprig", "gathering", 4, 29, "Herbalism nodes"},
    {"skinned", "Creatures Skinned", "Dagger", "gathering", 4, 29, "Skinning successes"},
    {"materials", "Materials Gathered", "Sprig", "gathering", 10, 34, "Materials collected"},
    {"gatherActions", "Gathering Actions", "Sprig", "gathering", 6, 27, "Mining, herbalism and skinning"},
    {"topMaterial", "Most Gathered", "Sprig", "gathering", 12, 27, nil},
    {"gatheredValue", "Gathering Value", "Coins", "gathering", 80, 29, "Vendor value of materials"},
    {"crafted", "Items Crafted", "Chest", "crafting", 5, 32, "Items produced"},
    {"recipes", "Recipes Learned", "Quest", "crafting", 2, 35, "New recipes"},
    {"profession", "Profession Gains", "Sprig", "crafting", 5, 35, "Profession skill points"},
    {"skill", "Combat Skill Gains", "Dagger", "progress", 8, 24, "Combat skill points"},
    {"bosses", "Bosses Defeated", "Laurel", "dungeon", 1, 42, "Successful encounters"},
    {"dungeons", "Dungeons Entered", "Pin", "dungeon", 2, 18, "Dungeon visits"},
    {"dungeonTime", "Dungeon Playtime", "Hourglass", "dungeon", 1200, 18, "Time in dungeon instances"},
    {"discoveries", "Areas Discovered", "Pin", "exploration", 2, 33, "New areas explored"},
    {"zones", "Zones Visited", "Pin", "exploration", 3, 19, "Distinct zones", "travel"},
    {"flightPaths", "Flight Paths Unlocked", "Pin", "exploration", 1, 36, "New flight points", "travel"},
    {"earned", "Money Earned", "Coins", "economy", 250, 24, "Gross money gained"},
    {"net", "Net Profit", "Coins", "economy", 200, 31, "Money earned minus spent"},
    {"vendor", "Vendor Earnings", "Coins", "economy", 150, 22, "Net vendor sales"},
    {"questMoney", "Quest Rewards", "Coins", "economy", 125, 25, "Money from quest turn-ins"},
    {"lootedMoney", "Money Looted", "Coins", "economy", 125, 25, "Coin collected from loot"},
    {"lootValue", "Total Loot Value", "Chest", "loot", 150, 28, "Vendor value of loot", "lootVolume"},
    {"looted", "Items Looted", "Chest", "loot", 12, 17, "Items collected", "lootVolume"},
    {"valuableLoot", "Most Valuable Loot", "Coins", "loot", 75, 29, "Vendor sell value"},
}

local moneyHighlights = {gatheredValue = true, earned = true, net = true, vendor = true, lootValue = true,
    valuableLoot = true, questMoney = true, lootedMoney = true}

local function highlights(totals, scope, records, limit)
    local candidates, activity = {}, {}
    local best = totals.bestLoot
    local valued = totals.valuableLoot
    local pvpKills, pvpDeaths = totals.killingBlows or 0, totals.pvpDeaths or 0
    local pvpReady = (totals.scoredBattles or 0) > 0 and totals.scoredBattles == totals.battlegrounds
    local function add(key, label, emblem, group, value, threshold, weight, detail, overlap)
        if not finite(value) or value <= 0 then return end
        if scope == "lifetime" and not maxStats[key] and key ~= "valuableLoot" then threshold = threshold * 12 end
        local relative = value / threshold
        local score = weight * math.min(1, relative) + math.min(18, math.floor(relative) * 3)
        activity[group] = math.max(activity[group] or 0, score)
        candidates[#candidates + 1] = {key = key, label = label, emblem = emblem, group = group, value = value,
            detail = detail, overlap = overlap, score = score,
            personal = records[key] ~= nil and (scope ~= "lifetime" or maxStats[key] and records[key] == value)}
    end
    for _, rule in ipairs(highlightRules) do
        local key = rule[1]
        local value = totals[key]
        if key == "pvpRatio" then value = pvpReady and pvpKills > 0 and pvpKills or nil end
        if key == "net" then value = (totals.earned or 0) - (totals.spent or 0) end
        if key == "valuableLoot" then value = valued and valued.vendor end
        if key == "gatherActions" then value = statValue(totals, key) end
        if key == "topMaterial" then value = totals.topMaterial and totals.topMaterial.count end
        local overlap = rule[8]
        if (key == "net" or key == "earned") and (totals.spent or 0) == 0 then overlap = "grossNet" end
        if (key == "lootValue" or key == "gatheredValue") and totals.lootValue == totals.gatheredValue
            and totals.looted == totals.materials then overlap = "lootVolume" end
        add(key, rule[2], rule[3], rule[4], value, rule[5], rule[6], rule[7], overlap)
    end
    if best and finite(best.quality) and best.quality >= 3 then
        candidates[#candidates + 1] = {key = "lucky", label = "Lucky Find", emblem = "Chest", group = "loot",
            item = best, value = best.quality, score = best.quality >= 4 and 134 + best.quality or 66}
    end
    for _, pick in ipairs(candidates) do
        pick.score = pick.score + math.min(13, (activity[pick.group] or 0) / 4) + (pick.personal and 180 or 0)
    end
    table.sort(candidates, function(a, b)
        if a.score == b.score then return a.key < b.key end
        return a.score > b.score
    end)
    local selected, used, shownItems = {}, {}, {}
    for _, pick in ipairs(candidates) do
        if pick.key == "valuableLoot" then pick.item = valued end
        if pick.key == "topMaterial" then pick.item = totals.topMaterial end
        local identity = pick.item and (pick.item.id or pick.item.link)
        if (not pick.overlap or not used[pick.overlap]) and (not identity or not shownItems[identity]) then
            if pick.overlap then used[pick.overlap] = true end
            if identity then shownItems[identity] = true end
            if pick.key == "deadliestAbility" then
                pick.name, pick.icon = abilityInfo(totals.deadliestSpellID)
                pick.detail = "Total Damage · " .. numeral(pick.value)
            elseif pick.key == "lucky" then
                pick.name, pick.icon, pick.quality = best.name, scope == "lifetime" and best.icon or nil, best.quality
                local quality = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[best.quality]
                pick.detail = (quality and quality.name or _G["ITEM_QUALITY" .. best.quality .. "_DESC"]) or "Rare or better loot"
            elseif pick.key == "pvpRatio" then
                pick.display = ratio(pvpKills, pvpDeaths)
                pick.detail = ("%d killing blows · %d deaths"):format(pvpKills, pvpDeaths)
            elseif pick.key == "highestDPS" then
                pick.display = ("%.1f"):format(pick.value)
            elseif pick.key == "dungeonTime" then
                pick.display = fmtTime(pick.value)
            elseif pick.key == "topMaterial" then
                pick.detail = pick.item.name
            elseif moneyHighlights[pick.key] then
                local shownValue = statValue(totals, pick.key)
                pick.display = type(shownValue) == "string" and shownValue or inventory.Money(pick.value)
                if pick.item then pick.detail = pick.item.name end
            end
            selected[#selected + 1] = pick
            if #selected == (limit or 3) then break end
        end
    end
    return selected
end

local function caption(parent, label, point, x, y, offset)
    local text = inventory.Label(parent)
    inventory.GeneralFont(text, offset, "", "ActivityStats")
    text:SetShadowColor(0, 0, 0, 0.54)
    text:SetShadowOffset(1, -1)
    text:SetPoint(point, x, y)
    text:SetText(label)
    return text
end

local media = assets .. "Activity\\"
local emblems = {Hourglass = 0, Quest = 1, XP = 2, Swords = 3, Skull = 4, Heart = 5, Sprig = 6,
    ChevronUp = 7, Pin = 8, Chest = 9, Coins = 10, Dagger = 11, Laurel = 12, Star = 13, Check = 14, Shield = 15}
local accountEmblems = {AccountRoster = true, AccountCrafting = true, AccountTotals = true}

local function surface(frame, name, layer, margin)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetTexture(media .. name .. ".tga")
    local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
    if mode and texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(margin, margin, margin, margin)
        texture:SetTextureSliceMode(mode)
    end
    return texture
end

local function paintedPanel(frame, outer)
    local background = surface(frame, "Panel", "BACKGROUND", 19)
    if outer then
        background:ClearAllPoints()
        background:SetPoint("TOPLEFT", 3, -3)
        background:SetPoint("BOTTOMRIGHT", -3, 3)
        background:SetVertexColor(0.85, 0.85, 0.88)
    end
    surface(frame, outer and "OuterFrame" or "CardFrame", "BORDER", outer and 22 or 16)
end

local function setEmblem(icon, name)
    local cell = emblems[name]
    if cell then
        local u, v = cell % 4 / 4, math.floor(cell / 4) / 4
        icon:SetTexture(media .. "Emblems.tga")
        icon:SetTexCoord(u + .002, u + .248, v + .002, v + .248)
    else
        icon:SetTexture((accountEmblems[name] and media or art) .. name .. ".tga")
        icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function iconAt(parent, name, size, point, x, y)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    setEmblem(icon, name)
    icon:SetSize(size, size)
    icon:SetPoint(point, x, y)
    return icon
end

local function seam(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 5, y)
    line:SetPoint("TOPRIGHT", -5, y)
    line:SetHeight(1)
    line:SetColorTexture(addon.Theme:AccentInk(0.50))
    return line
end

local function statRow(card, index, label)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", 6, -31 - (index - 1) * 18)
    row:SetPoint("TOPRIGHT", -6, -31 - (index - 1) * 18)
    row:SetHeight(18)
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(0.75, 0.73, 0.80, 0.075)
    local name = caption(row, label, "LEFT", 7, 0, -2)
    local value = caption(row, "", "RIGHT", -7, 0, 0)
    value:SetTextColor(1, 0.83, 0.49)
    return row, name, value, stripe
end

local function showLootTooltip(owner)
    local item = owner.item
    if not item then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if item.link then GameTooltip:SetHyperlink(item.link) else GameTooltip:SetItemByID(item.id) end
    if item.level and item.level > 0 then GameTooltip:AddLine("Item level " .. item.level, 0.9, 0.83, 0.67) end
    if item.vendor and item.vendor > 0 then GameTooltip:AddLine("Vendor value  " .. inventory.Money(item.vendor), 0.9, 0.83, 0.67) end
    GameTooltip:Show()
end

local function setLootTooltip(button)
    button:SetScript("OnEnter", showLootTooltip)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

local function makeHighlight(parent, index, width)
    local slot = CreateFrame("Frame", nil, parent)
    width = width or 194
    slot:SetSize(width, 80)
    slot:SetPoint("TOPLEFT", 10 + (index - 1) * (width + 4), -34)
    surface(slot, "Highlight", "BACKGROUND", 16)
    local glow = surface(slot, "RecordGlow", "ARTWORK", 18)
    glow:Hide()
    local animation = glow:CreateAnimationGroup()
    local pulse = animation:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.1)
    pulse:SetToAlpha(1)
    pulse:SetDuration(0.55)
    pulse:SetSmoothing("IN_OUT")
    animation:SetLooping("BOUNCE")
    slot.glow, slot.animation = glow, animation
    slot.emblem = iconAt(slot, "Laurel", 57, "LEFT", 1, 1)
    slot.label = caption(slot, "", "TOPLEFT", 59, -6, -1)
    slot.label:SetPoint("TOPRIGHT", -6, -6)
    slot.label:SetJustifyH("LEFT")
    slot.label:SetWordWrap(false)
    slot.value = caption(slot, "", "TOPLEFT", 59, -21, 18)
    slot.value:SetPoint("TOPRIGHT", -6, -21)
    slot.value:SetJustifyH("LEFT")
    slot.value:SetWordWrap(false)
    slot.namedValue = caption(slot, "", "TOPLEFT", 59, -25, 3)
    slot.namedValue:SetPoint("TOPRIGHT", -6, -25)
    slot.namedValue:SetJustifyH("LEFT")
    slot.namedValue:SetWordWrap(false)
    slot.detail = caption(slot, "", "TOPLEFT", 59, -52, -4)
    slot.detail:SetPoint("TOPRIGHT", -6, -52)
    slot.detail:SetJustifyH("LEFT")
    slot.detail:SetJustifyV("TOP")
    slot.detail:SetWordWrap(true)
    slot.record = caption(slot, "New personal best", "BOTTOMLEFT", 59, 5, -5)
    slot.record:SetTextColor(1, 0.79, 0.4)
    slot.spell = slot:CreateTexture(nil, "OVERLAY")
    slot.spell:SetSize(42, 42)
    slot.spell:SetPoint("CENTER", slot.emblem)
    slot.spell:SetTexCoord(.07, .93, .07, .93)
    slot:EnableMouse(true)
    slot:SetScript("OnEnter", function(self)
        if self.item then showLootTooltip(self); return end
        if not self.description or self.description == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.description, 1, .88, .65, true)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return slot
end

local function paintHighlights(slots, picks)
    for i, slot in ipairs(slots) do
        local pick = picks[i]
        local exceptional = pick and pick.quality and pick.quality >= 4
        local personal = pick and pick.personal or false
        local name = pick and pick.name
        local icon = pick and pick.icon
        local label = slot.label
        inventory.GeneralFont(label, -1, "", "ActivityStats")
        label:SetText(pick and pick.label or (i == 1 and "No activity yet" or ""))
        if label.GetUnboundedStringWidth then
            local width, textWidth = label:GetWidth(), label:GetUnboundedStringWidth()
            if finite(width) and width > 0 and finite(textWidth) and textWidth > width then
                local file, size, flags = label:GetFont()
                if file and finite(size) then label:SetFont(file, math.max(8, math.floor(size * width / textWidth)), flags) end
            end
        end
        slot.value:SetText(pick and (pick.display or numeral(pick.value)) or "")
        slot.value:SetTextColor(1, .88, .58)
        local compact = name or pick and (moneyHighlights[pick.key] or pick.key == "dungeonTime" or pick.key == "time")
        slot.value:SetShown(not compact)
        slot.namedValue:SetText(name or pick and pick.display or "")
        slot.namedValue:SetShown(not not compact)
        slot.namedValue:SetTextColor(qualityColor(pick and pick.quality))
        slot.spell:SetTexture(icon)
        slot.spell:SetShown(icon ~= nil)
        setEmblem(slot.emblem, pick and pick.emblem or "Laurel")
        slot.emblem:SetShown(pick ~= nil and icon == nil)
        slot.detail:SetHeight(personal and 13 or 24)
        slot.item = pick and pick.item
        slot.description = pick and (name and (name .. "\n" .. (pick.detail or "")) or pick.detail) or nil
        slot.detail:SetText(pick and pick.detail or "")
        slot.record:SetShown(personal)
        slot.glow:SetShown(personal or exceptional or false)
        if exceptional and not personal then
            local r, g, b = qualityColor(pick.quality)
            slot.glow:SetVertexColor(r, g, b, 0.42)
        else
            slot.glow:SetVertexColor(1, 1, 1, 1)
        end
        if personal and not slot.animation:IsPlaying() then slot.animation:Play()
        elseif not personal and slot.animation:IsPlaying() then slot.animation:Stop() end
    end
end

local function refreshHighlights(panel, totals, inspected)
    local snapshot = panel.highlightSnapshot
    local records = totals.personalBests or {}
    if panel.scope == "lifetime" then
        local data = inspected and inspected.stats or character
        local today = data and data.days and data.days[day(now())]
        records = today and today.personalBests or {}
    end
    local changed = panel.highlightSource ~= totals
    local function remember(key, value)
        if snapshot[key] ~= value then snapshot[key], changed = value, true end
    end
    for _, rule in ipairs(highlightRules) do
        local key = rule[1]
        remember(key, totals[key])
        remember(key .. "Record", records[key])
    end
    for _, key in ipairs({"bestLoot", "valuableLoot", "deadliestSpellID", "spent", "valuedLoot",
        "valuedMaterials", "pvpDeaths", "scoredBattles", "topMaterial", "veins", "herbs", "skinned"}) do remember(key, totals[key]) end
    if not changed then return end
    panel.highlightSource = totals
    paintHighlights(panel.highlights, highlights(totals, panel.scope, records))
end

local function showAchievements(panel)
    local entries, rows = panel.achievementEntries, #panel.achievements
    local offset = math.max(0, math.min(panel.achievementOffset or 0, #entries - rows))
    panel.achievementOffset = offset
    for i, text in ipairs(panel.achievements) do
        local entry = entries[offset + i]
        text:SetText(entry or "")
        panel.achievementIcons[i]:SetShown(entry ~= nil)
    end
    panel.emptyAchievements:SetShown(#entries == 0)
    panel.achievementRange:SetText(#entries > rows and ("%d–%d / %d"):format(offset + 1, offset + rows, #entries) or "")
    panel.achievementFrame:EnableMouseWheel(#entries > rows)
end

local function refreshAchievements(panel, totals)
    local entries = {}
    local milestones = panel.scope == "lifetime" and lifetimeMilestones or achievementMilestones
    for _, category in ipairs(milestones) do
        for _, threshold in ipairs(category[2]) do
            if (totals[category[1]] or 0) >= threshold then
                entries[#entries + 1] = category[3]:format(threshold)
                break
            end
        end
    end
    local records = 0
    for key in pairs(totals.personalBests or {}) do
        if recordKeys[key] then records = records + 1 end
    end
    if records > 0 then entries[#entries + 1] = records == 1 and "New personal record" or ("New personal records (%d)"):format(records) end
    if (totals.levels or 0) > 0 then entries[#entries + 1] = totals.levels == 1 and "Reached a new level" or ("Gained %d levels"):format(totals.levels) end
    if (totals.bosses or 0) > 0 then entries[#entries + 1] = totals.bosses == 1 and "Dungeon boss defeated" or ("%d bosses defeated"):format(totals.bosses) end
    if (totals.legendary or 0) > 0 then entries[#entries + 1] = "Found legendary loot"
    elseif (totals.epic or 0) > 0 then entries[#entries + 1] = "Found epic loot"
    elseif (totals.rare or 0) > 0 then entries[#entries + 1] = "Found rare loot" end
    if (totals.bgWins or 0) > 0 then entries[#entries + 1] = "Battleground victory" end
    if (totals.nearDeath or 0) > 0 then entries[#entries + 1] = "Survived with 10% health or less" end
    if panel.achievementScope ~= panel.scope then panel.achievementScope, panel.achievementOffset = panel.scope, 0 end
    panel.achievementEntries = entries
    showAchievements(panel)
end

local function traitSpecialization(traits)
    local configID = D.Call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    if not finite(configID) then return end
    local config = D.Call(traits.GetConfigInfo, configID)
    if type(config) ~= "table" or type(config.treeIDs) ~= "table" then return end
    local best, selected, tied = 0, nil, false
    for _, treeID in ipairs(config.treeIDs) do
        local groups = D.Call(traits.GetGroupDisplayInfoByTreeID, treeID)
        if type(groups) ~= "table" then return end
        local ids, byID = {}, {}
        for _, group in ipairs(groups) do
            ids[#ids + 1] = group.groupID
            byID[group.groupID] = group
        end
        if #ids > 0 then
            local currencies = D.Call(traits.GetGroupCurrencyInfo, configID, ids)
            if type(currencies) ~= "table" then return end
            for _, entry in ipairs(currencies) do
                local group, points = byID[entry.traitNodeGroupID], 0
                for _, currency in ipairs(entry.currencyInfos or {}) do
                    if not finite(currency.spent) then return end
                    points = points + currency.spent
                end
                if group and points > best then
                    best, selected, tied = points, group, false
                elseif group and points > 0 and points == best then
                    tied = true
                end
            end
        end
    end
    if selected and not tied and D.Read(selected.displayName) and type(selected.displayName) == "string" and selected.displayName ~= "" then
        return selected.displayName, D.Read(selected.icon) and selected.icon or nil
    end
end

local function specialization(classID)
    local traits = C_Traits
    if traits and traits.GetGroupDisplayInfoByTreeID and traits.GetGroupCurrencyInfo then
        return traitSpecialization(traits)
    end
    local api = C_SpecializationInfo
    local info = api and api.GetSpecializationInfo or GetSpecializationInfo
    if not info then return end
    local count = D.Call(api and api.GetNumSpecializationsForClassID, classID)
    local group = D.Call(api and api.GetActiveSpecGroup)
    local best, bestName, bestIcon, tied = 0, nil, nil, false
    for n = 1, finite(count) and count > 0 and count or 3 do
        local id, name, _, icon, _, _, points = D.Call(info, n, false, false, nil, nil, group)
        if finite(id) and id > 0 and finite(points) and D.Read(name) and type(name) == "string" and name ~= "" then
            if points > best then
                best, bestName, bestIcon, tied = points, name, D.Read(icon) and icon or nil, false
            elseif points == best and points > 0 then
                tied = true
            end
        end
    end
    if not tied then return bestName, bestIcon end
end

local function updateSpecialization(classID)
    local spec, icon = specialization(classID)
    if character then character.specialization, character.specializationIcon = spec, icon end
    return spec, icon
end

local function playerName()
    local first, surname = D.Call(UnitNameUnmodified or UnitName, "player")
    if first and D.Read(surname) and type(surname) == "string" and surname ~= "" then
        first = first .. " " .. surname
    end
    return first
end

local function characterRaceAtlas(race, sex)
    if D.Read(race) and type(race) == "string" and race ~= "" and D.Read(sex) and (sex == 2 or sex == 3) then
        return ("raceicon128-%s-%s"):format(race == "Scourge" and "undead" or race:lower(), sex == 3 and "female" or "male")
    end
end

local function saveIdentity()
    if not character then return end
    local info = character.identity or {}
    local class, token = D.Call(UnitClass, "player")
    local player = C_PlayerInfo
    local appearance = D.Call(player and player.GetPlayerCharacterData)
    local _, race = D.Call(UnitRace, "player")
    info.name = playerName() or info.name
    info.realm = D.Call(GetRealmName) or info.realm
    info.class, info.classToken = class or info.class, token or info.classToken
    info.level = D.Call(UnitLevel, "player") or info.level
    info.raceAtlas = characterRaceAtlas(race, D.Call(UnitSex, "player")) or info.raceAtlas
    if type(appearance) == "table" and D.Read(appearance.createScreenIconAtlas) and type(appearance.createScreenIconAtlas) == "string" then
        info.atlas = appearance.createScreenIconAtlas
    end
    character.identity = info
end

local function updateCharacterName(panel, otherName)
    local profiles = addon.db and addon.db.personalProfiles
    local profile = profiles and profiles[addon.Database:CharacterKey()]
    local name = otherName or playerName() or profile and profile.name or ""
    if panel.displayName == name then return end
    panel.displayName = name
    local label = panel.character
    inventory.GeneralFont(label, 7, "", "ActivityStats")
    label:SetText(name)
    if label.GetUnboundedStringWidth then
        local width, fitted = label:GetWidth(), label:GetUnboundedStringWidth()
        if finite(fitted) and finite(width) and width > 0 and fitted > width then
            local file, size, flags = label:GetFont()
            if file and finite(size) then label:SetFont(file, math.max(8, math.floor(size * width / fitted)), flags) end
        end
    end
end

local function paintCharacterPortrait(texture, entry)
    texture:SetTexCoord(0, 1, 0, 1)
    if not entry or entry.current then
        if SetPortraitTexture then SetPortraitTexture(texture, "player") end
    else
        -- An offline player's display ID does not carry the textures of a live unit portrait.
        local api = C_Texture and C_Texture.GetAtlasInfo
        if texture.SetAtlas and api then
            for _, atlas in ipairs({entry.atlas or false, entry.raceAtlas or false,
                entry.classToken and ("classicon-" .. entry.classToken:lower()) or false}) do
                if atlas and D.Call(api, atlas) then texture:SetAtlas(atlas); return end
            end
        end
        local coords = CLASS_ICON_TCOORDS and entry.classToken and CLASS_ICON_TCOORDS[entry.classToken]
        if coords then
            texture:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
            texture:SetTexCoord(unpack(coords))
        else
            texture:SetTexture(assets .. [[Icons\BaziUI_Emblem_256.png]])
        end
    end
end

local accountTotalMetrics = {
    {"kills", "Enemies killed", "Swords"}, {"deaths", "Deaths", "Skull"},
    {"honorableKills", "Honorable kills", "Dagger"}, {"honor", "Honor gained", "Shield"}, {"quest", "Quests completed", "Quest"},
    {"crafted", "Items crafted", "AccountCrafting"}, {"materials", "Materials gathered", "Sprig"}, {"earned", "Money earned", "Coins"},
    {"xp", "Experience gained", "XP"}, {"time", "Character playtime", "Hourglass"},
    {"damage", "Damage dealt", "Swords"}, {"damageTaken", "Damage taken", "Shield"}, {"healing", "Healing done", "Heart"},
    {"streak", "Solo killstreak", "Skull"}, {"highestDPS", "Highest DPS", "Dagger"}, {"toughestBattle", "Toughest battle", "Shield"},
    {"interrupts", "Interrupts", "Shield"}, {"bosses", "Bosses defeated", "Laurel"}, {"dungeons", "Dungeons entered", "Pin"},
    {"levels", "Levels gained", "ChevronUp"}, {"reputation", "Reputation gained", "Star"},
    {"recipes", "Recipes learned", "Quest"}, {"spellsLearned", "Spells learned", "Quest"},
    {"profession", "Profession skill gains", "Sprig"}, {"skill", "Combat skill gains", "Dagger"},
    {"veins", "Veins mined", "Sprig"}, {"herbs", "Herbs picked", "Sprig"}, {"skinned", "Creatures skinned", "Dagger"},
    {"looted", "Items looted", "Chest"}, {"rare", "Rare items", "Chest"}, {"epic", "Epic items", "Chest"},
    {"legendary", "Legendary items", "Chest"}, {"spent", "Money spent", "Coins"}, {"vendor", "Vendor sales", "Coins"},
    {"repair", "Repair costs", "Coins"}, {"lootValue", "Total loot value", "Coins"}, {"gatheredValue", "Gathering value", "Coins"},
    {"dungeonTime", "Dungeon playtime", "Hourglass"}, {"battlegrounds", "Battlegrounds played", "Shield"},
    {"bgWins", "Battlegrounds won", "Laurel"}, {"killingBlows", "PvP killing blows", "Swords"},
    {"zones", "Zones visited", "Pin"}, {"discoveries", "Areas discovered", "Pin"}, {"flightPaths", "Flight paths unlocked", "Pin"},
    {"largestHit", "Largest hit", "Swords"}, {"largestHeal", "Largest heal", "Heart"}, {"eliteKills", "Elite kills", "Skull"},
    {"nearDeath", "Near-death experiences", "Heart"}, {"battles", "Combats finished", "Swords"}, {"battlesSurvived", "Combats survived", "Shield"},
    {"common", "Common items", "Chest"}, {"uncommon", "Uncommon items", "Chest"}, {"discarded", "Items discarded via Cleanup", "Chest"},
    {"pvpDeaths", "PvP deaths", "Skull"}, {"bgLosses", "Battlegrounds lost", "Shield"},
    {"questMoney", "Quest money rewards", "Coins"}, {"lootedMoney", "Looted money", "Coins"}, {"net", "Net money", "Coins"},
}
local firstPerformers = {"damage", "honorableKills", "streak", "crafted", "materials", "earned"}

local function characterEntry(key, saved)
    local info = saved.identity or {}
    local profiles = addon.db.personalProfiles
    local profile = profiles and profiles[key] or {}
    local class, token, race, sex, name, realm, level
    if not info.class or not info.level or not (info.name or profile.name) or not info.raceAtlas then
        local localizedRace
        class, token, localizedRace, race, sex, name, realm, level = D.Call(GetPlayerInfoByGUID, key)
    end
    local tracked = saved.lifetimeStats.time or 0
    local hasPlayed = finite(saved.lifetime)
    local played = hasPlayed and saved.lifetime + math.max(0, tracked - (saved.lifetimeTrackedAtSample or tracked)) or tracked
    local spec = saved.specialization
    if spec == "Unspecialized" or spec == "Mixed talents" then spec = nil end
    return {key = key, name = saved.accountName or info.name or profile.name or name or "Unidentified character", realm = info.realm or profile.realm or realm,
        class = info.class or class, classToken = info.classToken or token, level = info.level or level, atlas = info.atlas,
        raceAtlas = info.raceAtlas or characterRaceAtlas(race, sex), current = saved == character, stats = saved, spec = spec, time = played,
        trackedOnly = not hasPlayed}
end

function Stats.SetAccountName(key, name)
    local data = addon.db.activityStats and addon.db.activityStats[key]
    if not data then return false end
    if name ~= nil then
        if type(name) ~= "string" then return false end
        name = name:match("^%s*(.-)%s*$")
        if name == "" or name:find("[|%c]") then return false end
    end
    data.accountName = name
    Stats.RefreshReport()
    return true
end

function Stats.SetAccountIncluded(key, included)
    local data = addon.db.activityStats and addon.db.activityStats[key]
    if not data then return end
    data.accountExcluded = not included or nil
    Stats.RefreshReport()
end

function Stats.GetAccount()
    checkpoint()
    local result = {characters = {}, archived = {}, totals = {}, records = {}, leaders = {}, recordTotals = {}}
    local seenNames = {}
    local function lead(board, key, value, entry)
        local existing = board[key]
        if finite(value) and value > 0 and (not existing or value > existing.value
            or value == existing.value and entry.key < existing.owner.key) then
            board[key] = {value = value, owner = entry}
        end
    end
    local function include(entry, data)
        local lifetime = data.lifetimeStats
        local latest = data.session and data.session.totals or {}
        seenNames[entry.name] = (seenNames[entry.name] or 0) + 1
        result.characters[#result.characters + 1] = entry
        for _, metric in ipairs(accountTotalMetrics) do
            local stat = metric[1]
            local value = stat == "time" and entry.time or lifetime[stat]
            if stat == "net" and (lifetime.earned or lifetime.spent) then value = (lifetime.earned or 0) - (lifetime.spent or 0) end
            if finite(value) then
                local total = result.totals[stat] or 0
                result.totals[stat] = maxStats[stat] and math.max(total, value) or total + value
                lead(result.leaders, stat, value, entry)
            end
        end
        for _, metric in ipairs(accountRecordMetrics) do
            local stat = metric[1]
            local stored = data.sessionRecords and data.sessionRecords[stat]
            local best = math.max(stored or 0, latest[stat] or 0)
            if stat == "streak" then best = math.max(best, lifetime.streak or 0) end
            lead(result.records, stat, best, entry)
        end
        if betterLoot(lifetime.bestLoot, result.totals.bestLoot) then
            result.totals.bestLoot, result.bestLootOwner = lifetime.bestLoot, entry
        end
        if lifetime.valuableLoot and (lifetime.valuableLoot.vendor or 0) > (result.totals.valuableLoot and result.totals.valuableLoot.vendor or 0) then
            result.totals.valuableLoot, result.valuableLootOwner = lifetime.valuableLoot, entry
        end
    end
    for key, data in pairs(addon.db.activityStats or {}) do
        migrateLifetime(data, now())
        local entry = characterEntry(key, data)
        if data.accountExcluded then result.archived[#result.archived + 1] = entry else include(entry, data) end
    end
    for stat, record in pairs(result.records) do result.recordTotals[stat] = record.value end
    for _, entry in ipairs(result.characters) do
        entry.displayName = seenNames[entry.name] > 1 and entry.realm and (entry.name .. " · " .. entry.realm) or entry.name
    end
    table.sort(result.characters, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        return a.key < b.key
    end)
    table.sort(result.archived, function(a, b) return a.key < b.key end)
    return result
end

local function accountValue(key, value)
    if not finite(value) then return "—" end
    if key == "time" or key == "dungeonTime" then return ("%dh %02dm"):format(math.floor(value / 3600), math.floor(value / 60) % 60) end
    if key == "net" then return fmtNet(value) end
    if moneyHighlights[key] or key == "spent" or key == "repair" then return inventory.Money(value) end
    if key == "highestDPS" then return ("%.1f"):format(value) end
    return numeral(value)
end

local function accountCard(parent, x, y, width, height, title, icon)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", x, -y)
    card:SetSize(width, height)
    paintedPanel(card)
    iconAt(card, icon, 26, "TOPLEFT", 7, -2)
    local heading = caption(card, title, "TOPLEFT", 36, -6, 3)
    heading:SetTextColor(1, 0.83, 0.49)
    seam(card, -29)
    return card, heading
end

local function accountRows(card, metrics, columns, width, scroll, owners)
    local parent = card
    local inset, top = 7, 35
    local perColumn = math.ceil(#metrics / columns)
    if scroll then
        parent = inventory.Scroll(card, -35, 8, "compact")
        parent:SetHeight(perColumn * 22)
        inset, top = 0, 0
        width = width - 20
    end
    local rows, stride = {}, (width - inset * 2) / columns
    for i, metric in ipairs(metrics) do
        local index = scroll and math.floor((i - 1) / columns) or (i - 1) % perColumn
        local column = scroll and (i - 1) % columns or math.floor((i - 1) / perColumn)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", inset + column * stride, -top - index * 22)
        row:SetSize(stride - 4, 21)
        if index % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(0.75, 0.73, 0.80, 0.075)
        end
        iconAt(row, metric[3], 19, "LEFT", 4, 0)
        local label = caption(row, metric[2], "LEFT", 27, 0, -2)
        local value = caption(row, "", "RIGHT", -6, 0, -1)
        label:SetWordWrap(false)
        label:SetJustifyH("LEFT")
        value:SetTextColor(1, 0.83, 0.49)
        local owner
        if owners then
            owner = caption(row, "", "RIGHT", -6, 0, -4)
            owner:SetWidth(82)
            owner:SetWordWrap(false)
            owner:SetJustifyH("LEFT")
            owner:SetTextColor(.85, .77, .66)
            value:ClearAllPoints()
            value:SetPoint("RIGHT", owner, "LEFT", -6, 0)
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                if not self.ownerEntry then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.ownerEntry.name)
                if self.ownerEntry.realm then GameTooltip:AddLine(self.ownerEntry.realm) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        end
        label:SetPoint("RIGHT", value, "LEFT", -6, 0)
        rows[i] = {frame = row, value = value, owner = owner, key = metric[1]}
    end
    return rows
end

local function makeAccountView(parent, inspect)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    local overview = accountCard(view, 0, 0, 950, 98, "Account Overview", "AccountRoster")
    view.overview = {}
    for i, metric in ipairs({{"characters", "Tracked characters", "AccountRoster"}, {"time", "Total Playtime", "Hourglass"},
        {"kills", "Enemies killed", "Swords"}, {"quest", "Quests completed", "Quest"}, {"earned", "Money earned", "Coins"}}) do
        local x = 11 + (i - 1) * 187
        if i > 1 then
            local divider = overview:CreateTexture(nil, "ARTWORK")
            divider:SetPoint("TOPLEFT", x, -41)
            divider:SetSize(1, 44)
            divider:SetColorTexture(.70, .48, .23, .8)
        end
        iconAt(overview, metric[3], 37, "TOPLEFT", x + 6, -43)
        local value = caption(overview, "", "TOPLEFT", x + 49, -40, 6)
        value:SetTextColor(1, .88, .62)
        local label = caption(overview, metric[2], "TOPLEFT", x + 49, -69, -2)
        view.overview[metric[1]] = {value = value, label = label}
    end
    local characters, heading = accountCard(view, 0, 108, 222, 309, "Characters", "AccountRoster")
    local roster, rosterViewport, rosterBar = inventory.Scroll(characters, -32, 7, "compact")
    rosterViewport:ClearAllPoints()
    rosterViewport:SetPoint("TOPLEFT", 7, -32)
    rosterViewport:SetPoint("BOTTOMRIGHT", -7, 7)
    rosterViewport:SetClipsChildren(true)
    view.characters = {}
    view.characterViewport, view.characterContent, view.characterScrollBar = rosterViewport, roster, rosterBar
    view.empty = caption(characters, "No tracked characters yet", "TOPLEFT", 11, -53, -2)

    local renameDialog, renameInput
    local function rename(entry)
        if not renameDialog then
            local dialog = CreateFrame("Frame", nil, view)
            dialog:SetFrameStrata("FULLSCREEN_DIALOG")
            dialog:SetSize(324, 126)
            dialog:SetPoint("CENTER")
            dialog:EnableMouse(true)
            addon.Theme:HelpPanel(dialog)
            caption(dialog, "Rename Account entry", "TOPLEFT", 14, -11, 2):SetTextColor(1, .83, .49)
            caption(dialog, "Changes the display name in Bazi UI only.", "TOPLEFT", 14, -34, -3)
            local input = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
            input:SetPoint("TOPLEFT", 20, -53)
            input:SetPoint("TOPRIGHT", -14, -53)
            input:SetHeight(23)
            input:SetMaxLetters(48)
            input:SetAutoFocus(false)
            local save = function()
                if Stats.SetAccountName(dialog.entry.key, input:GetText()) then dialog:Hide() end
            end
            local accept = inventory.Button(dialog, "Save", 72, save)
            accept:SetPoint("BOTTOMRIGHT", -14, 10)
            local cancel = inventory.Button(dialog, "Cancel", 72, function() dialog:Hide() end)
            cancel:SetPoint("RIGHT", accept, "LEFT", -7, 0)
            input:SetScript("OnEnterPressed", save)
            input:SetScript("OnEscapePressed", function() dialog:Hide() end)
            dialog:SetScript("OnHide", function() input:ClearFocus() end)
            view:HookScript("OnHide", function() dialog:Hide() end)
            renameDialog, renameInput = dialog, input
        end
        renameDialog.entry = entry
        renameDialog:Show()
        renameInput:SetText(entry.name)
        renameInput:SetFocus()
        renameInput:HighlightText()
    end

    local function entryMenu(menu, entry)
        menu:CreateButton("Rename entry", function() rename(entry) end)
        if entry.stats.accountName then
            menu:CreateButton("Use character name", function() Stats.SetAccountName(entry.key, nil) end)
        end
        if entry.stats.accountExcluded then
            menu:CreateButton("Restore to Account", function() Stats.SetAccountIncluded(entry.key, true) end)
        else
            menu:CreateButton("Remove from Account", function() Stats.SetAccountIncluded(entry.key, false) end)
        end
    end

    local manage = inventory.Button(characters, "", 24, function(owner)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local data = view.data
        MenuUtil.CreateContextMenu(owner, function(_, menu)
            if #data.characters + #data.archived > 12 and menu.SetScrollMode then menu:SetScrollMode(350) end
            local function append(title, entries)
                if #entries == 0 then return end
                menu:CreateTitle(title)
                for _, entry in ipairs(entries) do
                    local text = entry.realm and (entry.name .. " · " .. entry.realm) or entry.name
                    entryMenu(menu:CreateButton(text), entry)
                end
            end
            append("Tracked characters", data.characters)
            append("Removed characters", data.archived)
        end)
    end)
    manage:SetPoint("TOPRIGHT", -6, -3)
    iconAt(manage, "Settings", 15, "CENTER", 0, 0)
    manage:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Manage characters")
        GameTooltip:AddLine("Rename, remove, or restore entries. Removed characters keep their saved statistics.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    manage:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    heading:SetPoint("RIGHT", manage, "LEFT", -4, 0)
    heading:SetJustifyH("LEFT")
    heading:SetWordWrap(false)

    function view:CreateCharacterRow(i)
        local row = CreateFrame("Button", nil, self.characterContent)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 54)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * 54)
        row:SetHeight(52)
        row.selection = surface(row, "Highlight", "BACKGROUND", 16)
        local portrait = row:CreateTexture(nil, "ARTWORK")
        portrait:SetPoint("LEFT", 6, 0)
        portrait:SetSize(37, 37)
        if row.CreateMaskTexture then
            local mask = row:CreateMaskTexture()
            mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(portrait)
            portrait:AddMaskTexture(mask)
        end
        local ring = row:CreateTexture(nil, "OVERLAY")
        ring:SetPoint("CENTER", portrait, "CENTER")
        ring:SetSize(42, 42)
        ring:SetTexture(media .. "PortraitRing.tga")
        row.portrait = portrait
        row.name = caption(row, "", "TOPLEFT", 50, -6, -1)
        row.class = caption(row, "", "TOPLEFT", 50, -22, -4)
        row.spec = caption(row, "", "TOPLEFT", 50, -35, -5)
        row.spec:SetTextColor(addon.Theme:Accent())
        for _, label in ipairs({row.name, row.class, row.spec}) do
            label:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            label:SetWordWrap(false)
            label:SetJustifyH("LEFT")
        end
        row.playtime = caption(row, "", "BOTTOMRIGHT", -5, 4, -4)
        row.spec:SetPoint("RIGHT", row.playtime, "LEFT", -5, 0)
        row.playtime:SetTextColor(1, .83, .49)
        row:SetScript("OnClick", function(self, button)
            local entry = self.entry
            if not entry then return end
            if button == "RightButton" then
                if MenuUtil and MenuUtil.CreateContextMenu then
                    MenuUtil.CreateContextMenu(self, function(_, menu)
                        menu:CreateTitle(entry.name)
                        entryMenu(menu, entry)
                    end)
                end
            else inspect(entry.key) end
        end)
        row:SetScript("OnEnter", function(self)
            local entry = self.entry
            if not entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name)
            if entry.realm then GameTooltip:AddLine(entry.realm) end
            GameTooltip:AddLine((entry.trackedOnly and "Tracked playtime · " or "Character playtime · ") .. accountValue("time", entry.time))
            GameTooltip:AddLine("Left-click to inspect. Right-click to manage.", .9, .82, .64)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        return row
    end
    local featured = accountCard(view, 232, 108, 718, 123, "Account Highlights", "Laurel")
    view.highlights = {}
    for i = 1, 4 do view.highlights[i] = makeHighlight(featured, i, 171) end
    local records = accountCard(view, 232, 241, 718, 176, "Account Records · Single Session", "Laurel")
    view.records = accountRows(records, accountRecordMetrics, 2, 718, false, true)
    local totals = accountCard(view, 0, 427, 592, 197, "Account Statistics · Lifetime", "AccountTotals")
    local leaders = accountCard(view, 602, 427, 348, 197, "Top Performers · Lifetime", "Star")
    local ordered, used = {}, {}
    for _, key in ipairs(firstPerformers) do
        for _, metric in ipairs(accountTotalMetrics) do if metric[1] == key then ordered[#ordered + 1], used[key] = metric, true; break end end
    end
    for _, metric in ipairs(accountTotalMetrics) do if not used[metric[1]] then ordered[#ordered + 1] = metric end end
    view.totals = accountRows(totals, accountTotalMetrics, 2, 592, true)
    view.leaders = accountRows(leaders, ordered, 1, 348, true, true)
    return view
end

local function refreshAccount(view, data)
    view.data = data
    for key, stat in pairs(view.overview) do
        stat.value:SetText(accountValue(key, key == "characters" and #data.characters or data.totals[key]))
    end
    view.empty:SetText(#data.archived > 0 and "No characters included" or "No tracked characters yet")
    view.empty:SetShown(#data.characters == 0)
    for i = #view.characters + 1, #data.characters do view.characters[i] = view:CreateCharacterRow(i) end
    for i, row in ipairs(view.characters) do
        local entry = data.characters[i]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            row.selection:SetShown(entry.current)
            row.name:SetText(entry.displayName)
            row.class:SetText(entry.level and entry.class and ("Level %d · %s"):format(entry.level, entry.class) or entry.class or "")
            row.spec:SetText(entry.spec or "")
            row.playtime:SetText(accountValue("time", entry.time))
            local portraitKey = table.concat({entry.key, entry.atlas or "", entry.raceAtlas or "", entry.classToken or ""}, ":")
            if row.portraitKey ~= portraitKey then
                paintCharacterPortrait(row.portrait, entry)
                row.portraitKey = portraitKey
            end
        end
    end
    if view.rosterSize ~= #data.characters then
        view.rosterSize = #data.characters
        view.characterContent:SetHeight(math.max(1, #data.characters * 54))
        view.characterViewport:UpdateScrollChildRect()
        view.characterScrollBar:SyncRange()
    end
    for _, set in ipairs({{view.records, data.records}, {view.leaders, data.leaders}}) do
        for _, row in ipairs(set[1]) do
            local best = set[2][row.key]
            row.frame.ownerEntry = best and best.owner
            row.owner:SetText(best and best.owner.displayName or "")
            row.value:SetText(accountValue(row.key, best and best.value))
        end
    end
    for _, row in ipairs(view.totals) do row.value:SetText(accountValue(row.key, data.totals[row.key])) end
    local picks, used = {}, {}
    for _, metric in ipairs(accountRecordMetrics) do
        local key = metric[1]
        local best = data.records[key]
        if best then
            used[key] = true
            picks[#picks + 1] = {key = key, label = metric[2], emblem = metric[3], value = best.value,
                display = accountValue(key, best.value), detail = best.owner.displayName .. "\nSingle session"}
        end
    end
    local ranked = highlights(data.recordTotals, "account", {}, #accountRecordMetrics)
    local order = {}
    for i, pick in ipairs(ranked) do order[pick.key] = i end
    table.sort(picks, function(a, b)
        local ar, br = order[a.key] or math.huge, order[b.key] or math.huge
        return ar ~= br and ar < br or ar == br and a.key < b.key
    end)
    for i = #picks, #view.highlights + 1, -1 do picks[i] = nil end
    for _, pick in ipairs(highlights(data.totals, "lifetime", {}, #view.highlights)) do
        if #picks >= #view.highlights then break end
        if not used[pick.key] then
            local owner = pick.key == "lucky" and data.bestLootOwner or pick.key == "valuableLoot" and data.valuableLootOwner
            if not owner then owner = data.leaders[pick.key] and data.leaders[pick.key].owner end
            pick.detail = owner and (owner.displayName .. "\nLifetime") or "Lifetime"
            picks[#picks + 1] = pick
        end
    end
    paintHighlights(view.highlights, picks)
end

local function refreshRows(section, totals, choose)
    if choose then
        local candidates = {}
        for index, field in ipairs(section.fields) do
            local value = statValue(totals, field.key)
            if value ~= nil then
                local active = type(value) == "number" and value ~= 0 or type(value) == "string"
                    and value ~= "0" and value ~= "Collecting"
                candidates[#candidates + 1] = {field = field, index = index, priority = field.core and 3 or active and 2 or 1}
            end
        end
        table.sort(candidates, function(a, b)
            if a.priority == b.priority then return a.index < b.index end
            return a.priority > b.priority
        end)
        for _, field in ipairs(section.fields) do field.row:Hide() end
        local order = {}
        for i = 1, math.min(rowsPerCard, #candidates) do order[candidates[i].field] = true end
        section.visibleFields = {}
        for _, field in ipairs(section.fields) do
            if order[field] then
                local offset = #section.visibleFields
                field.row:ClearAllPoints()
                field.row:SetPoint("TOPLEFT", 6, -32 - offset * 18)
                field.row:SetPoint("TOPRIGHT", -6, -32 - offset * 18)
                field.stripe:SetShown(offset % 2 == 0)
                section.visibleFields[offset + 1] = field
                field.row:Show()
            end
        end
    end
    for _, field in ipairs(section.visibleFields) do
        local value = statValue(totals, field.key)
        local loot = totals[field.key]
        if field.key == "valuableLoot" or field.key == "bestLoot" or field.key == "topMaterial" then
            field.row.item = loot
        end
        local display = type(value) == "string" and value or finite(value)
            and (field.format and field.format(value) or numeral(value)) or ""
        field.text:SetText(display)
        if field.key == "bestLoot" or field.key == "topMaterial" then
            field.text:SetTextColor(qualityColor(loot and loot.quality))
        end
        if field.quantity then field.quantity:SetText(loot and finite(loot.count) and ("×" .. numeral(loot.count)) or "") end
    end
end

local function refreshPanel(panel)
    panel.renderedDay = day(now())
    local label = scopeLabels[panel.scope] or scopeLabels.today
    panel.title:SetText("Bazi UI – " .. label)
    if panel.selectedTab ~= panel.scope then
        for key, button in pairs(panel.tabs) do addon.Theme:SetButtonActive(button, key == panel.scope) end
        panel.selectedTab = panel.scope
    end
    if panel.scope == "account" then
        panel.reportBody:Hide()
        panel.accountView:Show()
        refreshAccount(panel.accountView, Stats.GetAccount())
        panel.period:SetText(fmtTime(Stats.Get("session").time or 0))
        if panel:IsShown() then panel.viewport:UpdateScrollChildRect() end
        return
    end
    if panel.accountView then panel.accountView:Hide() end
    panel.reportBody:Show()
    local inspected
    if panel.inspectKey then
        local saved = addon.db.activityStats and addon.db.activityStats[panel.inspectKey]
        if saved then inspected = characterEntry(panel.inspectKey, saved) end
    end
    local totals = inspected and inspected.stats.lifetimeStats or Stats.Get(panel.scope)
    local class, level, spec, specIcon
    if inspected then
        class, level = inspected.class, inspected.level
        spec, specIcon = inspected.spec, inspected.spec and inspected.stats.specializationIcon
    else
        local _, classID
        class, _, classID = D.Call(UnitClass, "player")
        level = D.Call(UnitLevel, "player")
        spec, specIcon = updateSpecialization(classID)
    end
    updateCharacterName(panel, inspected and inspected.name)
    panel.characterClass:SetText(level and class and ("Level %d · %s"):format(level, class) or class or "")
    panel.characterSpec:SetText(spec or "")
    panel.characterSpec:SetShown(spec ~= nil)
    panel.specIcon:SetTexture(specIcon)
    panel.specIcon:SetShown(specIcon ~= nil)
    panel.characterSpec:ClearAllPoints()
    panel.characterSpec:SetPoint("LEFT", panel.hero, "LEFT", specIcon and 115 or 99, -24)
    local portraitKey = inspected and inspected.key or "player"
    if panel.portraitKey ~= portraitKey or not inspected then
        paintCharacterPortrait(panel.portrait, inspected)
        panel.portraitKey = portraitKey
    end
    if panel.scope == "lifetime" then
        local owner = inspected and inspected.stats or character
        local period = owner and owner.lifetimeStarted and ("Since " .. owner.lifetimeStarted) or ""
        panel.period:SetText(inspected and inspected.realm and (inspected.realm .. " · " .. period) or period)
    else
        panel.period:SetText(panel.scope == "today" and day(now()) or fmtTime(totals.time or 0))
    end
    panel.playtime:SetText(fmtTime(totals.time or 0))
    local lifetime = inspected and inspected.stats.lifetime or not inspected and character and character.lifetime
    panel.lifetime:SetText(finite(lifetime) and ("Character: %dh %02dm"):format(math.floor(lifetime / 3600),
        math.floor(lifetime / 60) % 60) or "")
    panel.experience:SetText(numeral(totals.xp or 0))
    panel.quests:SetText(numeral(totals.quest or 0))
    panel.highlightsTitle:SetText(panel.scope == "today" and "Today’s Highlights" or label .. " Highlights")
    panel.timeLabel:SetText(panel.scope == "lifetime" and "Tracked playtime" or "Playtime")
    local choose = panel.rowSource ~= totals
    panel.rowSource = totals
    for _, section in ipairs(panel.sections) do
        refreshRows(section, totals, choose)
    end
    refreshHighlights(panel, totals, inspected)
    refreshAchievements(panel, totals)
    if panel:IsShown() then panel.viewport:UpdateScrollChildRect() end
end

local function selectPeriod(panel, scope, inspectKey)
    panel.scope = scope
    panel.inspectKey = inspectKey
    if scope == "account" and not panel.accountView then
        panel.accountView = makeAccountView(panel.content, function(key) selectPeriod(panel, "lifetime", key) end)
    end
    panel.rowSource = nil
    refreshPanel(panel)
    if panel.scrollBar then panel.scrollBar:SetValue(0) else panel.viewport:SetVerticalScroll(0) end
end

local function refreshWindow()
    if window and window:IsShown() then refreshPanel(window) end
    for _, panel in pairs(exitPanels) do
        if panel:IsVisible() then refreshPanel(panel) end
    end
end

local function refreshClocks()
    local dateKey = day(now())
    local function update(panel)
        if panel.scope == "account" or panel.inspectKey then refreshPanel(panel); return end
        if panel.scope ~= "session" and panel.renderedDay ~= dateKey then refreshPanel(panel); return end
        local text = fmtTime(Stats.Get(panel.scope).time or 0)
        panel.playtime:SetText(text)
        if panel.scope == "session" then panel.period:SetText(text) end
    end
    if window and window:IsShown() then update(window) end
    for _, panel in pairs(exitPanels) do if panel:IsVisible() then update(panel) end end
end

local function makePanel(parent, name)
    local panel = CreateFrame("Frame", name, parent)
    panel.highlightSnapshot = {}
    panel.accountView = false
    panel:SetSize(panelWidth, panelHeight)
    panel:SetScale(math.min(1, (UIParent:GetWidth() - 24) / panelWidth))
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    paintedPanel(panel, true)

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 7, -5)
    header:SetPoint("TOPRIGHT", -7, -5)
    header:SetHeight(42)
    local brand = iconAt(header, "Report", 43, "LEFT", 5, 0)
    brand:SetTexture(assets .. [[Icons\BaziUI_Emblem_256.png]])
    panel.title = caption(header, "", "LEFT", 52, 0, 9)
    panel.title:SetTextColor(1, 0.83, 0.49)
    panel.period = caption(header, "", "RIGHT", -14, 0, 0)
    panel.period:SetTextColor(1, 0.83, 0.49)
    seam(header, -42)
    panel.tabs = {}
    for index, key in ipairs(scopeOrder) do
        local button = addon.Theme:CreateButton(header, scopeLabels[key], 88, 25)
        button:SetPoint("LEFT", header, "LEFT", 345 + (index - 1) * 94, 0)
        button:SetScript("OnClick", function() selectPeriod(panel, key) end)
        panel.tabs[key] = button
    end

    local content, viewport, scrollBar = inventory.Scroll(panel, -52, 10, "compact")
    -- The three columns span 950 pixels, centered within the 984-pixel window.
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", 17, -52)
    viewport:SetPoint("BOTTOMRIGHT", -17, 10)
    viewport:SetClipsChildren(true)
    panel.content, panel.viewport, panel.scrollBar = content, viewport, scrollBar
    panel.reportBody = CreateFrame("Frame", nil, content)
    panel.reportBody:SetAllPoints()
    content = panel.reportBody
    local hero = CreateFrame("Frame", nil, content)
    hero:SetPoint("TOPLEFT", 0, 0)
    hero:SetPoint("TOPRIGHT", 0, 0)
    hero:SetHeight(106)
    panel.hero = hero
    paintedPanel(hero)
    local portrait = hero:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("LEFT", 15, 0)
    portrait:SetSize(69, 69)
    if hero.CreateMaskTexture then
        local mask = hero:CreateMaskTexture()
        mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(portrait)
        portrait:AddMaskTexture(mask)
    end
    local ring = hero:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    ring:SetSize(78, 78)
    ring:SetTexture(media .. "PortraitRing.tga")
    panel.portrait = portrait
    panel.character = caption(hero, "", "LEFT", 99, 17, 7)
    panel.characterClass = caption(hero, "", "LEFT", 99, -7, -1)
    panel.characterSpec = caption(hero, "", "LEFT", 99, -24, -2)
    panel.characterSpec:SetTextColor(addon.Theme:Accent())
    panel.specIcon = hero:CreateTexture(nil, "ARTWORK")
    panel.specIcon:SetSize(12, 12)
    panel.specIcon:SetPoint("LEFT", hero, "LEFT", 99, -24)
    for _, label in ipairs({panel.character, panel.characterClass, panel.characterSpec}) do
        label:SetWidth(180)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    end
    panel.characterSpec:SetWidth(159)
    local function metric(x, title, icon, subline)
        local bar = hero:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("LEFT", x, 0)
        bar:SetSize(1, 60)
        bar:SetColorTexture(0.70, 0.48, 0.23, 0.8)
        iconAt(hero, icon, 45, "LEFT", x + 9, 0)
        local value = caption(hero, "", "LEFT", x + 57, subline and 17 or 11, 13)
        value:SetTextColor(1, 0.88, 0.62)
        local label = caption(hero, title, "LEFT", x + 57, subline and -10 or -17, -1)
        return value, label
    end
    panel.playtime, panel.timeLabel = metric(287, "Playtime", "Hourglass", true)
    panel.lifetime = caption(hero, "", "LEFT", 344, -28, -3)
    panel.lifetime:SetTextColor(.83, .75, .64)
    panel.quests = metric(522, "Quests completed", "Quest")
    panel.experience = metric(712, "Experience gained", "XP")

    panel.sections, panel.values = {}, {}
    local cardHeight = 39 + rowsPerCard * 18
    for index, definition in ipairs(sections) do
        local name, icon, fields = unpack(definition)
        local card = CreateFrame("Frame", nil, content)
        card:SetSize(310, cardHeight)
        card:SetPoint("TOPLEFT", content, "TOPLEFT", ((index - 1) % 3) * 320,
            -118 - math.floor((index - 1) / 3) * (cardHeight + 10))
        paintedPanel(card)
        iconAt(card, icon, 28, "TOPLEFT", 7, -2)
        local title = caption(card, name, "TOPLEFT", 36, -6, 3)
        title:SetTextColor(1, 0.83, 0.49)
        seam(card, -29)
        local section = {frame = card, name = name, fields = {}}
        for i, spec in ipairs(fields) do
            local row, label, value, stripe = statRow(card, i, spec[1])
            local key = spec[2]
            local field = {row = row, text = value, stripe = stripe, key = key, format = spec[3], core = coreRows[key]}
            section.fields[i] = field
            if key == "valuableLoot" or key == "bestLoot" or key == "topMaterial" then
                row:EnableMouse(true)
                setLootTooltip(row)
            end
            if key == "bestLoot" or key == "topMaterial" then
                value:ClearAllPoints()
                value:SetPoint("LEFT", label, "RIGHT", 9, 0)
                value:SetJustifyH("RIGHT")
                value:SetWordWrap(false)
                if key == "topMaterial" then
                    field.quantity = caption(row, "", "RIGHT", -7, 0, 0)
                    field.quantity:SetTextColor(1, 0.83, 0.49)
                    value:SetPoint("RIGHT", field.quantity, "LEFT", -6, 0)
                else
                    value:SetPoint("RIGHT", row, "RIGHT", -7, 0)
                end
            end
            panel.values[#panel.values + 1] = value
            if key == "uncommon" or key == "rare" or key == "epic" or key == "legendary" then
                label:SetTextColor(qualityColor(key == "uncommon" and 2 or key == "rare" and 3 or key == "epic" and 4 or 5))
            end
        end
        panel.sections[#panel.sections + 1] = section
    end

    local footer = CreateFrame("Frame", nil, content)
    local footerY = 118 + 2 * (cardHeight + 10)
    footer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -footerY)
    footer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -footerY)
    local footerHeight = 120
    panel.content:SetHeight(footerY + footerHeight)
    footer:SetHeight(footerHeight)
    panel.footer = footer
    local highlightCard = CreateFrame("Frame", nil, footer)
    highlightCard:SetPoint("TOPLEFT")
    highlightCard:SetSize(630, 120)
    paintedPanel(highlightCard)
    iconAt(highlightCard, "Laurel", 28, "TOPLEFT", 7, -2)
    panel.highlightsTitle = caption(highlightCard, "", "TOPLEFT", 37, -7, 3)
    panel.highlightsTitle:SetTextColor(1, 0.83, 0.49)
    seam(highlightCard, -29)
    panel.highlights = {}
    for i = 1, 3 do panel.highlights[i] = makeHighlight(highlightCard, i) end
    local achievements = CreateFrame("Frame", nil, footer)
    panel.achievementFrame = achievements
    achievements:SetPoint("TOPLEFT", highlightCard, "TOPRIGHT", 10, 0)
    achievements:SetSize(310, 120)
    paintedPanel(achievements)
    iconAt(achievements, "Star", 28, "TOPLEFT", 7, -2)
    local heading = caption(achievements, "Achievements", "TOPLEFT", 37, -7, 3)
    heading:SetTextColor(1, 0.83, 0.49)
    seam(achievements, -29)
    panel.achievements, panel.achievementIcons = {}, {}
    for i = 1, 4 do
        local y = -36 - (i - 1) * 18
        panel.achievementIcons[i] = iconAt(achievements, "Check", 16, "TOPLEFT", 11, y + 2)
        panel.achievements[i] = caption(achievements, "", "TOPLEFT", 34, y, -1)
    end
    panel.achievementRange = caption(achievements, "", "TOPRIGHT", -9, -9, -4)
    panel.achievementRange:SetTextColor(0.76, 0.65, 0.80)
    achievements:SetScript("OnMouseWheel", function(_, delta)
        panel.achievementOffset = panel.achievementOffset - delta
        showAchievements(panel)
    end)
    panel.emptyAchievements = caption(achievements, "No milestones recorded yet.", "LEFT", 13, -12, -2)
    panel:Hide()
    return panel, header
end

Stats.RefreshReport = refreshWindow

function Stats.ResetSession()
    if not session then return end
    checkpoint()
    saveSessionRecords(character, session.totals)
    session.totals = {}
    fight, finishingFight = nil, nil
    chain, lastKill, lastVein = 0, nil, nil
    refreshWindow()
end

local campfirePrompt, campfireWait, campfireOffered, campfireGap

local function hideCampfirePrompt()
    if campfirePrompt then
        campfirePrompt:SetScript("OnUpdate", nil)
        campfirePrompt:Hide()
    end
end

local function showCampfirePrompt()
    if not campfirePrompt then
        local tip = CreateFrame("Frame", "BaziUICampfireSessionPrompt", UIParent)
        tip:SetWidth(360)
        tip:SetFrameStrata("HIGH")
        tip.card = addon.Theme:HelpPanel(tip)
        tip.body = inventory.Label(tip)
        tip.body:SetPoint("TOPLEFT", 17, -11)
        tip.body:SetPoint("TOPRIGHT", -34, -11)
        tip.body:SetJustifyH("LEFT")
        tip.body:SetWordWrap(true)
        tip.body:SetText("|cffffd18aBy the campfire|r\nWhile the fire warms you, take a moment to reflect on your adventures.")
        local button = inventory.Button(tip, "View statistics", 112, function() Stats.Open("session") end)
        button:SetPoint("BOTTOMRIGHT", -11, 9)
        local close = inventory.Button(tip, "×", 22, hideCampfirePrompt)
        close:SetPoint("TOPRIGHT", -6, -6)
        campfirePrompt = tip
    end
    local tip, db = campfirePrompt, inventory.Settings()
    addon.Theme:PaintWindowEdge(tip.card)
    tip.card:SetBackdropColor(0.045, 0.026, 0.012, (db.rollGuideOpacity or db.rollOpacity or db.opacity or 95) / 100)
    inventory.GeneralFont(tip.body, -2)
    tip:SetHeight(math.max(88, math.ceil(tip.body:GetStringHeight() or 0) + 49))
    tip:SetPoint("TOP", UIParent, "TOP", 0, 6)
    tip:SetAlpha(0)
    local elapsed = 0
    tip:SetScript("OnUpdate", function(self, delta)
        elapsed = math.min(elapsed + delta, 0.9)
        local fraction = 1 - (1 - elapsed / 0.9) ^ 3
        self:SetPoint("TOP", UIParent, "TOP", 0, 6 - 32 * fraction)
        self:SetAlpha(0.94 * fraction)
        if elapsed == 0.9 then self:SetScript("OnUpdate", nil) end
    end)
    tip:Show()
end

local function campfireAura()
    local api = C_UnitAuras
    if not api then return end
    local aura = D.Call(api.GetPlayerAuraBySpellID, 1229739) or D.Call(api.GetPlayerAuraBySpellID, 1289723)
    if aura then return aura end
    if api.GetAuraDataBySpellName then
        local name = D.Call(C_Spell and C_Spell.GetSpellName, 1289723)
            or D.Call(C_Spell and C_Spell.GetSpellName, 1229739) or "Welcoming Campfire"
        return D.Call(api.GetAuraDataBySpellName, "player", name, "HELPFUL")
    end
end

local function refreshCampfirePrompt()
    local aura = inWorld and campfireAura()
    if not aura then
        campfireWait = nil
        hideCampfirePrompt()
        if campfireOffered and not campfireGap then
            local gap = {}
            campfireGap = gap
            -- The timer aura can reappear after a short gap while the player is still at camp.
            C_Timer.After(9, function()
                if campfireGap ~= gap then return end
                campfireGap = nil
                if not campfireAura() then campfireOffered = nil end
            end)
        end
        return
    end
    if campfireWait or campfireOffered or D.Call(InCombatLockdown) or window and window:IsShown() then return end
    local ticket = {}
    campfireWait = ticket
    C_Timer.After(2.5, function()
        if campfireWait ~= ticket then return end
        campfireWait = nil
        if not inWorld or D.Call(InCombatLockdown) or window and window:IsShown() then return end
        local current = campfireAura()
        if not current then return end
        local expires = current.expirationTime
        if finite(expires) and expires > 0 and expires - GetTime() < 4 then return end
        campfireOffered = true
        showCampfirePrompt()
    end)
end

function Stats.Open(scope)
    hideCampfirePrompt()
    if exitEscape then exitEscape:Hide() end
    if not window then
        local header
        window, header = makePanel(UIParent, "BaziUIActivityStatistics")
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetMovable(true)
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function() window:StartMoving() end)
        header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "BaziUIActivityStatistics") end
    end
    window:SetHeight(math.min(panelHeight, UIParent:GetHeight() * 0.9 / window:GetScale()))
    requestLifetime()
    selectPeriod(window, scopeLabels[scope] and scope or "today")
    window:Show()
    window.viewport:UpdateScrollChildRect()
    window:Raise()
end

function Stats.ExitScope()
    local profile = addon.db.profile
    return profile.exitActivityScope or (profile.hideExitSessionSummary and "off" or "today")
end

function Stats.SetExitScope(scope)
    addon.db.profile.exitActivityScope = scope
    if scope == "off" then
        if exitEscape then exitEscape:Hide() end
        for _, panel in pairs(exitPanels) do panel:Hide() end
        activeExit, retainedExit = nil, nil
    end
end

function Stats.ShowExit(popup)
    leaving = true
    if not addon.db then return end
    local scope = Stats.ExitScope()
    if scope == "off" then return end
    if window and window:IsShown() then window:Hide() end
    if exitEscape then exitEscape:Hide() end
    local panel = exitPanels[popup]
    if not panel then
        panel = makePanel(UIParent)
        panel:SetFrameStrata(popup:GetFrameStrata())
        panel:SetFrameLevel(popup:GetFrameLevel() + 1)
        exitPanels[popup] = panel
        popup:HookScript("OnHide", function()
            C_Timer.After(0, function()
                if not popup:IsShown() and retainedExit ~= panel then
                    if activeExit == panel then activeExit = nil end
                    panel:Hide()
                end
            end)
        end)
    end
    local below = (popup:GetBottom() or 0) - (UIParent:GetBottom() or 0) - 10
    local above = (UIParent:GetTop() or 0) - (popup:GetTop() or 0) - 10
    local putBelow = below >= panelHeight or below >= above
    panel:ClearAllPoints()
    if putBelow then panel:SetPoint("TOP", popup, "BOTTOM", 0, -6)
    else panel:SetPoint("BOTTOM", popup, "TOP", 0, 6) end
    panel:SetHeight(math.max(100, math.min(panelHeight, putBelow and below or above)))
    selectPeriod(panel, scope)
    activeExit = panel
    panel:Show()
    -- Keep the measured screen position when Blizzard hides or recycles the logout dialog.
    local left, top, scale = panel:GetLeft(), panel:GetTop(), panel:GetEffectiveScale()
    local rootLeft, rootTop, rootScale = UIParent:GetLeft(), UIParent:GetTop(), UIParent:GetEffectiveScale()
    if finite(left) and finite(top) and finite(rootLeft) and finite(rootTop) and finite(scale) and scale > 0 and finite(rootScale) then
        local ratio = rootScale / scale
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - rootLeft * ratio, top - rootTop * ratio)
    end
    panel.viewport:UpdateScrollChildRect()
    inventory.ShowFirstUseGuide(panel, "hideExitActivityGuide", "Activity on logout",
        "Today is the default. Use the tabs to review your session or lifetime. You can change the default or hide this panel under General > Logout activity.")
end

local function retainCanceledExit()
    leaving = false
    local panel = activeExit
    if not panel or not panel:IsShown() or retainedExit == panel then return end
    retainedExit = panel
    C_Timer.After(0, function()
        if retainedExit ~= panel or leaving then return end
        if not exitEscape then
            exitEscape = CreateFrame("Frame", "BaziUIRetainedExitReport", UIParent)
            exitEscape:Hide()
            if UISpecialFrames then table.insert(UISpecialFrames, "BaziUIRetainedExitReport") end
            exitEscape:SetScript("OnHide", function()
                local report = retainedExit
                activeExit, retainedExit = nil, nil
                if report then report:Hide() end
            end)
        end
        exitEscape:Show()
    end)
end

SLASH_BAZIACTIVITYTODAY1 = "/today"
SLASH_BAZIACTIVITYSESSION1 = "/session"
SLASH_BAZIACTIVITYLIFETIME1 = "/lifetime"
SLASH_BAZIACTIVITYSTATS1 = "/statistics"
SlashCmdList.BAZIACTIVITYTODAY = function() Stats.Open("today") end
SlashCmdList.BAZIACTIVITYSESSION = function() Stats.Open("session") end
SlashCmdList.BAZIACTIVITYLIFETIME = function() Stats.Open("lifetime") end
SlashCmdList.BAZIACTIVITYSTATS = SlashCmdList.BAZIACTIVITYTODAY
SlashCmdList.BAZIACTIVITYACCOUNT = function() Stats.Open("account") end

local function registerAlias(command, global)
    for key, value in pairs(_G) do
        if type(key) == "string" and key:sub(1, 6) == "SLASH_" and key ~= global and type(value) == "string"
            and value:lower() == command then return end
    end
    _G[global] = command
end

local events = CreateFrame("Frame")
local version, build, _, interface
if GetBuildInfo then version, build, _, interface = GetBuildInfo() end
local modern = WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
    or interface and (interface >= 120000 or interface >= 16000 and interface < 17000)
local legacyLog = not modern and type(CombatLogGetCurrentEventInfo) == "function"
local selfDamageEvents = {}

SLASH_BAZISTATDEBUG1 = "/bazistatdebug"
SlashCmdList.BAZISTATDEBUG = function(input)
    local command = (input or ""):match("^%s*(%S*)"):lower()
    if command == "" then command = trace and "show" or "on" end
    if command == "on" then
        trace, traceIndex, traceCount = {}, 0, 0
        addon:Print("Activity trace started. Run /bazistatdebug show after a fight, then /bazistatdebug off.")
    elseif command == "off" then
        trace = nil
        addon:Print("Activity trace stopped.")
        return
    elseif command ~= "show" then
        addon:Print("/bazistatdebug on, show, or off")
        return
    end
    addon:Print(("Client %s (%s), exact combat log %s, self hit chat events %s"):format(
        version or "?", build or "?", legacyLog and "registered" or "unavailable",
        next(selfDamageEvents) and table.concat(selfDamageEvents, ", ") or "unavailable"))
    if command == "show" and trace then
        for offset = traceCount - 1, 0, -1 do addon:Print(trace[(traceIndex - offset - 1) % traceLimit + 1]) end
    end
    local today, total = Stats.Get("today"), Stats.Get("session")
    addon:Print(("Deadliest Ability today %s / session %s. Toughest Battle today %s / session %s."):format(
        describe(today.deadliestAbility), describe(total.deadliestAbility), describe(today.toughestBattle),
        describe(total.toughestBattle)))
end

for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "LOGOUT_CANCEL", "PLAYER_MONEY",
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "QUEST_TURNED_IN", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY",
    "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_HONOR_GAIN", "UNIT_SPELLCAST_SUCCEEDED", "SKILL_LINES_CHANGED", "ENCOUNTER_END",
    "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "NEW_RECIPE_LEARNED", "GET_ITEM_INFO_RECEIVED", "CHAT_MSG_SYSTEM",
    "CHAT_MSG_COMBAT_FACTION_CHANGE", "PVP_MATCH_ACTIVE", "PVP_MATCH_COMPLETE", "DAMAGE_METER_RESET",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UI_INFO_MESSAGE",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "LEARNED_SPELL_IN_SKILL_LINE", "TIME_PLAYED_MSG"}) do
    pcall(events.RegisterEvent, events, event)
end
if events.RegisterUnitEvent then
    pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "player", "target")
    pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
else
    pcall(events.RegisterEvent, events, "UNIT_COMBAT")
    pcall(events.RegisterEvent, events, "UNIT_AURA")
end
if legacyLog then
    legacyLog = pcall(events.RegisterEvent, events, "COMBAT_LOG_EVENT_UNFILTERED")
    pcall(events.RegisterEvent, events, "PLAYER_TARGET_CHANGED")
end
if not legacyLog then
    for event, formats in pairs(selfDamageMessages) do
        if _G[formats[1][1]] and D.Call(C_EventUtils and C_EventUtils.IsEventValid, event)
            and pcall(events.RegisterEvent, events, event) then
            selfDamageEvents[#selfDamageEvents + 1] = event
        end
    end
end
if Logout then hooksecurefunc("Logout", function() leaving = true end) end
if Quit then hooksecurefunc("Quit", function() leaving = true end) end
if ReloadUI then hooksecurefunc("ReloadUI", function() leaving = false end) end
if CancelLogout then hooksecurefunc("CancelLogout", retainCanceledExit) end
C_Timer.NewTicker(10, function() checkpoint(); refreshClocks() end)
local reportRefreshQueued
local function queueReportRefresh()
    if reportRefreshQueued then return end
    local visible = window and window:IsShown()
    if not visible then
        for _, panel in pairs(exitPanels) do if panel:IsVisible() then visible = true; break end end
    end
    if not visible then return end
    reportRefreshQueued = true
    C_Timer.After(window and window.scope == "account" and 0.5 or 0.12, function()
        reportRefreshQueued = nil
        refreshWindow()
    end)
end
events:SetScript("OnEvent", function(_, event, first, second, third, fourth, fifth)
    if event == "PLAYER_LOGIN" then
        registerAlias("/stats", "SLASH_BAZIACTIVITYSTATS2")
        registerAlias("/account", "SLASH_BAZIACTIVITYACCOUNT1")
    elseif event == "LOGOUT_CANCEL" then
        retainCanceledExit()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not session and addon.db then openSession(); sampleCombat(true) end
        if session then
            clock, inWorld = now(), true
            sampleInstance()
            visitZone()
            local _, _, classID = D.Call(UnitClass, "player")
            updateSpecialization(classID)
            saveIdentity()
            if not D.Call(C_PvP and C_PvP.IsBattleground) then session.battlegroundScored = nil end
            refreshCampfirePrompt()
        end
    elseif not session then return
    elseif event == "UNIT_AURA" then
        if first == "player" then refreshCampfirePrompt() end
        return
    elseif event == "TIME_PLAYED_MSG" then
        if finite(first) and first >= 0 then
            checkpoint()
            character.lifetime, character.lifetimeUpdated = first, now()
            character.lifetimeTrackedAtSample = character.lifetimeStats.time or 0
        end
    elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
        if inWorld and finite(first) and first > 0 and D.Read(third) and not third then
            character.learnedSpells = character.learnedSpells or {}
            if character.learnedSpells[first] then return end
            character.learnedSpells[first] = true
            record("spellsLearned", 1)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        local _, _, classID = D.Call(UnitClass, "player")
        updateSpecialization(classID)
        refreshWindow()
    elseif event == "PLAYER_LEAVING_WORLD" then
        if finishingFight then commitFight(finishingFight) end
        checkpoint()
        fight, inWorld = nil, false
        campfireWait, campfireOffered, campfireGap = nil, nil, nil
        hideCampfirePrompt()
    elseif event == "PLAYER_LOGOUT" then checkpoint(); saveIdentity(); session.closed = leaving or nil
    elseif event == "MERCHANT_SHOW" then
        merchant = {entries = readBuybacks(), cost = D.Call(GetRepairAllCost), credits = 0, debits = 0}
    elseif event == "MERCHANT_UPDATE" then queueMerchant()
    elseif event == "MERCHANT_CLOSED" then
        if merchant then reconcileMerchant(merchant); merchant = nil end
    elseif event == "PLAYER_MONEY" then
        local total = D.Call(GetMoney)
        if type(total) == "number" and type(money) == "number" then
            local change = total - money
            record(change > 0 and "earned" or "spent", math.abs(change))
            if merchant then
                if change > 0 then merchant.credits = merchant.credits + change
                else merchant.debits = merchant.debits - change end
                queueMerchant()
            end
        end
        money = total
    elseif event == "PLAYER_XP_UPDATE" and (not first or first == "player") or event == "PLAYER_LEVEL_UP" then
        sampleXP()
        if event == "PLAYER_LEVEL_UP" then saveIdentity() end
    elseif event == "PLAYER_DEAD" then
        local encounter = fight or finishingFight
        if encounter then encounter.died = true end
        debugLog("Player died")
        record("deaths", 1); chain, lastKill = 0, nil
    elseif event == "GROUP_ROSTER_UPDATE" then
        if isGrouped() then chain, lastKill = 0, nil end
    elseif event == "QUEST_TURNED_IN" then
        record("quest", 1)
        record("questMoney", third)
    elseif event == "CHAT_MSG_MONEY" then
        if D.ReadLootMoney then record("lootedMoney", D.ReadLootMoney(first)) end
    elseif event == "CHAT_MSG_LOOT" then
        local id, count, link = D.ReadSelfLoot(first)
        if id then
            record("looted", count)
            local at = now()
            local kind, skin
            if addon.Gathering and addon.Gathering.DashboardContext then kind, skin = addon.Gathering.DashboardContext() end
            local item = {id = id, count = count, link = link, gathered = skin or kind == "ore" or kind == "herb",
                buckets = periods(at), sessionTotals = session.totals, date = day(at)}
            if not inspectLoot(item) then
                local queued = itemQueue[id] or {}
                itemQueue[id] = queued
                queued[#queued + 1] = item
                if #queued == 1 then
                    D.Call(C_Item and C_Item.RequestLoadItemDataByID, id)
                    C_Timer.After(15, function()
                        if itemQueue[id] == queued then flushLoot(id, true); refreshWindow() end
                    end)
                end
            end
        else
            local crafted, amount = D.ReadSelfLoot(first, true)
            if crafted then record("crafted", amount) end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" and D.Read(first) then flushLoot(first, second)
    elseif event == "NEW_RECIPE_LEARNED" and D.Read(first) then rememberUnique("recipes", first)
    elseif event == "ZONE_CHANGED_NEW_AREA" then visitZone()
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" and D.Read(first) and type(first) == "string" then
        local amount = D.MatchChatFormat(first, FACTION_STANDING_INCREASED, false, 2)
            or D.MatchChatFormat(first, FACTION_STANDING_INCREASED_ACCOUNT_WIDE, false, 2)
        record("reputation", tonumber(amount))
    elseif D.Read(first) and type(first) == "string" and (event == "CHAT_MSG_SYSTEM"
        or event == "CHAT_MSG_COMBAT_XP_GAIN" and not D.IsKillMessage(first)) then
        local area = D.MatchChatFormat(first, EXPLOREXP_EARNED) or D.MatchChatFormat(first, ERR_ZONE_EXPLORED)
        if not area then return end
        rememberUnique("discoveries", area)
    elseif event == "UI_INFO_MESSAGE" and D.Read(second) and ERR_NEWTAXIPATH and second == ERR_NEWTAXIPATH then record("flightPaths", 1)
    elseif event == "PVP_MATCH_ACTIVE" then
        session.battlegroundScored = nil
        battlegroundGeneration = (battlegroundGeneration or 0) + 1
    elseif event == "PVP_MATCH_COMPLETE" then scoreBattleground(first)
    elseif event == "DAMAGE_METER_RESET" then
        fight, finishingFight = nil, nil
        sampleCombat(true)
        spellBase = spellBase or {}
    elseif event == "PLAYER_REGEN_DISABLED" then
        campfireWait = nil
        hideCampfirePrompt()
        if finishingFight then commitFight(finishingFight) end
        fight = {before = meterSessionIDs()}
        debugLog("Combat start")
    elseif event == "PLAYER_REGEN_ENABLED" then closeFight(); sampleCombat(false); refreshCampfirePrompt()
    elseif event == "UNIT_COMBAT" then
        if trace and D.Read(first) and (first == "player" or first == "target") then
            debugLog(first == "player" and "Incoming" or "Damage to target (source unknown)", "UNIT_COMBAT",
                second, "amount", fourth, "flag", third, "school", fifth)
        end
        return
    elseif selfDamageMessages[event] then readSelfDamage(event, first)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then readCombatEvent()
    elseif event == "PLAYER_TARGET_CHANGED" then
        local kind = D.Call(UnitClassification, "target")
        eliteTarget = (kind == "elite" or kind == "rareelite" or kind == "worldboss") and D.Call(UnitGUID, "target") or nil
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if D.Call(InCombatLockdown) then return end
        sampleCombat(false)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and first == "player" and D.Read(third) then
        local kind = gatheringSpells[third]
        if kind and (not D.Read(second) or not second or second ~= lastGatherCast) then
            lastGatherCast = D.Read(second) and second or nil
            local node = kind == "veins" and D.Call(UnitGUID, "softinteract")
            if type(node) ~= "string" or not node:match("^GameObject%-") then node = nil end
            if not node or node ~= lastVein then record(kind, 1) end
            if kind == "veins" then lastVein = node end
        else return end
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" and D.Read(first) and type(first) == "string" then
        local killed = D.MatchChatFormat(first, COMBATLOG_HONORGAIN, false, 3)
        if killed then
            record("honorableKills", 1)
            record("honor", tonumber(killed))
        else
            local amount = D.MatchChatFormat(first, COMBATLOG_HONORAWARD)
            record("honor", tonumber(amount))
        end
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and D.IsKillMessage(first) then
        record("kills", 1)
        if not isGrouped() then
            local at = GetTime()
            chain = (lastKill and at - lastKill < 20 and chain or 0) + 1
            lastKill = at
            record("streak", chain, true)
        end
    elseif event == "SKILL_LINES_CHANGED" then sampleSkills(false)
    elseif event == "ENCOUNTER_END" and D.Read(fifth) and fifth == 1 then record("bosses", 1)
    end
    queueReportRefresh()
end)
