local addon, D = BaziUI, BaziUI.Dashboard
local call, rowsResult = D.Call, D.Rows
local loot, reputation = {}, {}
local factionSnapshot
local function factionEvent() factionSnapshot = nil end
local session, run, battleground, playedTotal
local lootEvent

local function trackedID(value)
    local id = tonumber(value) or type(value) == "string" and tonumber(value:match("item:(%d+)"))
    return id and id > 0 and id <= 99999999 and id == math.floor(id) and id or nil
end

local function elapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function money()
    return call(GetMoney) or 0
end

local function xp()
    return call(UnitLevel, "player") or 0, call(UnitXP, "player") or 0, call(UnitXPMax, "player") or 0
end

local function ensureSession()
    if not session then
        local level, current, cap = xp()
        session = {since = GetTime(), last = GetTime(), money = money(), level = level, currentXP = current,
            levelCap = cap, xp = 0, earned = 0, spent = 0, quest = 0, deaths = 0, looted = 0, materials = 0, time = 0}
        local tracking = D.Settings().persistSession and D.Tracking()
        local saved = tracking and tracking.session
        if saved then
            for _, key in ipairs({"xp", "earned", "spent", "quest", "deaths", "looted", "materials", "time"}) do
                if type(saved[key]) == "number" then session[key] = saved[key] end
            end
            session.since = session.last - (tonumber(saved.duration) or 0)
        end
    end
    return session
end

function D.ResetSession()
    if addon.Journey and addon.db then addon.Journey.Save() end
    session = nil
    local tracking = D.Tracking()
    if tracking then tracking.session = nil end
    wipe(loot)
    wipe(reputation)
    factionSnapshot = nil
    if D.ResetSkills then D.ResetSkills() end
    ensureSession()
    D.Invalidate()
end

function D.GetSessionMetrics()
    local state = ensureSession()
    return {xp = state.xp, quest = state.quest, deaths = state.deaths, earned = state.earned, spent = state.spent,
        looted = state.looted, materials = state.materials}
end

local function sessionEvent(event, ...)
    if addon.Adventure and addon.Adventure.SessionDriver then return end
    D.RecordSessionEvent(event, ...)
end

function D.RecordSessionEvent(event, ...)
    local state = ensureSession()
    if event == "PLAYER_LOGOUT" then
        local tracking = D.Tracking()
        if tracking then
            tracking.session = D.Settings().persistSession and {
                duration = GetTime() - state.since, xp = state.xp, earned = state.earned, spent = state.spent,
                quest = state.quest, deaths = state.deaths, looted = state.looted, materials = state.materials, time = state.time,
            } or nil
        end
    elseif event == "PLAYER_MONEY" then
        local now = money()
        local change = now - state.money
        if change > 0 then state.earned = state.earned + change else state.spent = state.spent - change end
        state.money = now
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        local level, current, cap = xp()
        if level == state.level then state.xp = state.xp + math.max(0, current - state.currentXP)
        elseif level == state.level + 1 then
            state.xp = state.xp + math.max(0, state.levelCap - state.currentXP + current)
            state.levelUp = GetTime()
        end
        state.level, state.currentXP, state.levelCap = level, current, cap
    elseif event == "QUEST_TURNED_IN" then state.quest = state.quest + 1
    elseif event == "PLAYER_DEAD" then state.deaths = state.deaths + 1
    elseif event == "CHAT_MSG_LOOT" and (addon.Adventure and addon.Adventure.SessionDriver or not D.WidgetSettings("gathering").enabled) then lootEvent(event, ...) end
end

function D.ReadSelfLoot(message)
    if not D.Read(message) or type(message) ~= "string" then return end
    local pattern = _G.LOOT_ITEM_SELF
    local prefix = type(pattern) == "string" and pattern:match("^(.-)%%")
    local id = tonumber(message:match("|Hitem:(%d+)"))
    if not id or not prefix or prefix == "" or message:sub(1, #prefix) ~= prefix then return end
    local suffix = message:match("|h[^|]*|h|r(.*)$") or message:match("|h[^|]*|h(.*)$") or ""
    local amount = tonumber(suffix:match("[x×]%s*(%d+)")) or 1
    return id, amount, message:match("(|c%x+|Hitem:.-|h.-|h|r)") or message:match("(|Hitem:.-|h.-|h)")
end

lootEvent = function(event, message)
    if event ~= "CHAT_MSG_LOOT" then return end
    local id, amount = D.ReadSelfLoot(message)
    if not id then return end
    local state = ensureSession()
    state.looted = state.looted + amount
    local _, _, _, _, class = D.Item(id)
    local kind, skin
    if addon.Gathering.DashboardContext then kind, skin = addon.Gathering.DashboardContext() end
    local material = class == 7 or class == 5 or skin or kind == "ore" or kind == "herb"
    if not material then D.Invalidate("session"); return end
    local record = loot[id]
    if not record then
        if not D.HasRoom(loot) then
            local oldestID, oldest
            for key, entry in pairs(loot) do if not oldest or entry.last < oldest then oldestID, oldest = key, entry.last end end
            if oldestID then loot[oldestID] = nil end
        end
        record = {gained = 0, since = GetTime()}
        loot[id] = record
    end
    record.last, record.gained = GetTime(), record.gained + amount
    state.materials = state.materials + amount
    D.Invalidate("session")
end

local function gathering(options)
    local rows, recent = {}, false
    local time = GetTime()
    local data = D.Tracking()
    local tracking = data and data.materials or {}
    local ids = {}
    for id in pairs(loot) do ids[id] = true end
    for id in pairs(tracking) do ids[id] = true end
    for id in pairs(ids) do
        local record = loot[id]
        local active = record and time - record.last < options.duration
        if tracking[id] or options.pinned or options.mode == "always" or active then
            local name, icon, link, price = D.Item(id)
            local gained = record and record.gained or 0
            local tooltip = ("%d looted this session"):format(gained)
            local duration = record and time - record.since or 0
            if duration >= 120 then tooltip = tooltip .. ("\n~%.0f per hour"):format(gained * 3600 / duration) end
            if type(price) == "number" and price > 0 then tooltip = tooltip .. "\nVendor value " .. addon.Inventory.Money(price * gained) end
            local count = D.Count(id)
            rows[#rows + 1] = {label = name, icon = icon, link = link, tooltip = tooltip,
                value = count and ("%d (+%d)"):format(count, gained) or ("+%d"):format(gained), pin = D.Pin("materials", id)}
            recent = recent or active
        end
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    return rowsResult(rows, recent or next(tracking) ~= nil, recent)
end
D.Register({id = "gathering", label = "Gathering", priority = 60, duration = 120, tick = true, read = gathering,
    event = function(...)
        if not (addon.Adventure and addon.Adventure.SessionDriver) then lootEvent(...) end
    end, events = {"CHAT_MSG_LOOT", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED"}})

function D.TrackMaterial(item)
    local id = trackedID(item)
    local data = D.Tracking()
    if not id or not data or InCombatLockdown() or not data.materials[id] and not D.HasRoom(data.materials) then return false end
    data.materials[id] = true
    D.Invalidate("gathering")
    return true
end

function D.TrackRecipe(recipe, amount)
    if InCombatLockdown() then return false, "Tracking is available outside combat." end
    local id = trackedID(recipe) or type(recipe) == "string" and tonumber(recipe:match("spell:(%d+)"))
    amount = tonumber(amount)
    if not id or not amount or amount < 1 or amount > 99999 or amount ~= math.floor(amount) then return false, "Enter a recipe ID and quantity." end
    local api = C_TradeSkillUI
    local schematic = call(api and api.GetRecipeSchematic, id, false)
    local info = call(api and api.GetRecipeInfo, id)
    local materials = {}
    if type(schematic) == "table" then
        for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
            if slot.required and (slot.quantityRequired or 0) > 0 then
                local reagent = type(slot.reagents) == "table" and #slot.reagents == 1 and slot.reagents[1]
                if not reagent or not reagent.itemID then return false, "This recipe has multiple material choices." end
                materials[reagent.itemID] = (materials[reagent.itemID] or 0) + slot.quantityRequired
            end
        end
    end
    local data = D.Tracking()
    if not data or not next(materials) then return false, "Material data is unavailable for this recipe." end
    if not data.goals[id] and not D.HasRoom(data.goals) then return false, "The crafting list is full." end
    data.goals[id] = {name = type(info) == "table" and info.name or call(C_Spell and C_Spell.GetSpellName, id) or "Recipe #" .. id,
        amount = amount, materials = materials}
    D.Invalidate("crafting")
    return true
end

function D.TrackSelectedRecipe(amount)
    local page = _G.ProfessionsFrame
    local form = page and page.CraftingPage and page.CraftingPage.SchematicForm
    local recipe = form and (form.currentRecipeInfo or call(form.GetRecipeInfo, form))
    if type(recipe) == "table" and recipe.recipeID then return D.TrackRecipe(recipe.recipeID, amount) end
    local index = call(GetTradeSkillSelectionIndex)
    local name = index and call(GetTradeSkillInfo, index)
    local count = index and call(GetTradeSkillNumReagents, index)
    amount = tonumber(amount)
    if not amount or amount < 1 or amount > 99999 or amount ~= math.floor(amount) or InCombatLockdown() then return false, "Enter a quantity outside combat." end
    if type(name) ~= "string" or type(count) ~= "number" or count < 1 then return false, "Open a profession and select a recipe." end
    local materials = {}
    for slot = 1, count do
        local item = trackedID(call(GetTradeSkillReagentItemLink, index, slot))
        local _, _, quantity = call(GetTradeSkillReagentInfo, index, slot)
        if not item or not D.Read(quantity) or type(quantity) ~= "number" or quantity <= 0 then
            return false, "Some recipe materials are still loading."
        end
        materials[item] = (materials[item] or 0) + quantity
    end
    local data = D.Tracking()
    if not data or not data.goals[name] and not D.HasRoom(data.goals) then return false, "The crafting list is full." end
    data.goals[name] = {name = name, amount = amount, materials = materials}
    D.Invalidate("crafting")
    return true
end

local function crafting(options)
    local rows, keys = {}, {}
    local data = D.Tracking()
    local goals = data and data.goals or {}
    for key in pairs(goals) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        local goal = goals[key]
        local canCraft, materialRows = math.huge, {}
        for id, count in pairs(goal.materials) do
            local have = D.Count(id)
            local name, icon, link = D.Item(id)
            canCraft = math.min(canCraft, have and math.floor(have / count) or -1)
            local required = count * goal.amount
            local row = have and D.Value(name, have, required, ("%d missing"):format(math.max(0, required - have)))
                or {label = name, value = "? / " .. required}
            row.icon, row.link = icon, link
            materialRows[#materialRows + 1] = row
        end
        local ready = canCraft >= goal.amount
        if not ready or not options.hideCompleted then
            rows[#rows + 1] = {label = ("%s ×%d"):format(goal.name, goal.amount),
                done = ready, value = ready and "Ready to craft" or (canCraft >= 0 and ("%d craftable"):format(canCraft) or ""),
                tooltip = "Amounts are based on materials in your bags.",
                pin = function() goals[key] = nil end}
            table.sort(materialRows, function(a, b) return a.label < b.label end)
            for _, row in ipairs(materialRows) do rows[#rows + 1] = row end
        end
    end
    return rowsResult(rows, #rows > 0)
end
D.Register({id = "crafting", label = "Crafting goals", priority = 60, read = crafting,
    events = {"BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "TRADE_SKILL_LIST_UPDATE"}})

local function freeBags()
    local count
    for _, bag in ipairs(addon.Inventory.BagIDs()) do
        local free, family = call(C_Container and C_Container.GetContainerNumFreeSlots, bag)
        if type(free) == "number" and D.Read(family) and (not family or family == 0) then count = (count or 0) + free end
    end
    return count
end
local function durability()
    local lowest
    for slot = 1, 18 do
        local current, total = call(GetInventoryItemDurability, slot)
        if D.Read(total) and type(current) == "number" and type(total) == "number" and total > 0 then
            lowest = math.min(lowest or 100, math.floor(current * 100 / total))
        end
    end
    return lowest
end

function D.TrackSupply(item, minimum)
    local id, amount = trackedID(item), tonumber(minimum)
    local data = D.Tracking()
    if not id or not data or not amount or amount < 0 or amount > 99999 or amount ~= math.floor(amount) or InCombatLockdown() then return false end
    if not data.supplies[id] and not D.HasRoom(data.supplies) then return false end
    data.supplies[id] = amount
    D.Invalidate("supplies")
    return true
end

local function supplies(options)
    local rows, low = {}, false
    local cfg = D.Settings().thresholds
    local function add(name, count, minimum, suffix)
        if type(count) ~= "number" then return end
        local warning = count < minimum
        low = low or warning
        if warning or options.pinned or options.mode ~= "automatic" or not D.Settings().context then
            rows[#rows + 1] = {label = name, value = tostring(count) .. (suffix or ""), warning = warning}
            return rows[#rows]
        end
    end
    add("Free bag slots", freeBags(), cfg.slots or 3)
    add("Durability", durability(), cfg.durability or 20, "%")
    local _, class = call(UnitClass, "player")
    local slot = call(GetInventorySlotInfo, "AmmoSlot")
    local ammo = class == "HUNTER" and slot and call(GetInventoryItemID, "player", slot)
    if type(ammo) == "number" then
        local name, icon, link = D.Item(ammo)
        local row = add(name, D.Count(ammo), cfg.ammo or addon.HUD.Settings("ammo").low)
        if row then row.icon, row.link = icon, link end
    end
    local data = D.Tracking()
    for id, amount in pairs(data and data.supplies or {}) do
        local name, icon, link = D.Item(id)
        local row = add(name, D.Count(id), amount)
        if row then row.icon, row.link, row.pin = icon, link, function() data.supplies[id] = nil end end
    end
    return rowsResult(rows, low, low)
end
D.Register({id = "supplies", label = "Supplies", priority = 100, read = supplies,
    events = {"BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED"}})

local function status(options)
    local cfg = D.Settings().status
    local rows = {}
    local function add(key, label, value)
        if cfg[key] ~= false and value ~= nil then rows[#rows + 1] = {label = label, value = tostring(value)} end
    end
    add("gold", "Money", addon.Inventory.Money(money()))
    add("bags", "Free bag slots", freeBags())
    local wear = durability()
    add("durability", "Durability", wear and wear .. "%")
    local fps = call(GetFramerate)
    add("fps", "FPS", fps and math.floor(fps + 0.5))
    local _, _, home, world = call(GetNetStats)
    if D.Read(home) and D.Read(world) then add("latency", "Latency", world and ("%d ms"):format(world) or home) end
    add("zone", call(GetRealZoneText) or "Zone", "")
    local mapID = call(C_Map and C_Map.GetBestMapForUnit, "player")
    local pos = mapID and call(C_Map.GetPlayerMapPosition, mapID, "player")
    if pos and pos.GetXY then
        local x, y = call(pos.GetXY, pos)
        if type(x) == "number" and D.Read(y) and type(y) == "number" then add("coordinates", "Position", ("%.1f, %.1f"):format(x * 100, y * 100)) end
    end
    if call(HasNewMail) then add("mail", "New mail", "") end
    local rested = call(GetXPExhaustion)
    if type(rested) == "number" and rested > 0 then add("rested", "Rested XP", rested) end
    if playedTotal then add("played", "Time played", elapsed(playedTotal)) end
    return rowsResult(rows, options.pinned or false)
end
D.Register({id = "status", label = "Character status", priority = 40, read = status, tick = true,
    event = function(event, total)
        if event == "TIME_PLAYED_MSG" and D.Read(total) and type(total) == "number" then playedTotal = total end
    end,
    events = {"BAG_UPDATE_DELAYED", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY", "UPDATE_PENDING_MAIL", "PLAYER_UPDATE_RESTING", "TIME_PLAYED_MSG"}})

local function sessionRows(options)
    local state = ensureSession()
    local time = GetTime()
    local delta = math.max(0, math.min(5, time - state.last))
    if not D.Settings().afk or not call(UnitIsAFK, "player") then state.time = state.time + delta end
    state.last = time
    local rows = {
        {label = "Duration", value = elapsed(time - state.since)},
        {label = "XP gained", value = tostring(state.xp)},
        {label = "Money gained", value = addon.Inventory.Money(state.earned)},
        {label = "Money spent", value = addon.Inventory.Money(state.spent)},
        {label = "Net money", value = (state.earned < state.spent and "-" or "+") .. addon.Inventory.Money(math.abs(state.earned - state.spent))},
        {label = "Quests turned in", value = tostring(state.quest)},
        {label = "Deaths", value = tostring(state.deaths)},
        {label = "Items looted", value = tostring(state.looted)},
        {label = "Materials looted", value = tostring(state.materials)},
    }
    if state.time >= 120 and state.xp > 0 then
        rows[#rows + 1] = {label = "XP per hour (est.)", value = ("%d"):format(math.floor(state.xp * 3600 / state.time))}
        if state.levelCap > state.currentXP then
            rows[#rows + 1] = {label = "Next level (est.)", value = elapsed((state.levelCap - state.currentXP) * state.time / state.xp)}
        end
    end
    local levelUp = state.levelUp and time - state.levelUp < options.duration
    if levelUp then table.insert(rows, 1, {label = "Level reached", value = tostring(state.level), highlight = true}) end
    return rowsResult(rows, levelUp, levelUp)
end
D.Register({id = "session", label = "Session", priority = 50, read = sessionRows, tick = true, event = sessionEvent,
    events = {"PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_DEAD", "CHAT_MSG_LOOT", "PLAYER_LOGOUT"}})

local function scanFactions()
    if factionSnapshot then return factionSnapshot end
    local factions, time = {}, GetTime()
    local api = C_Reputation
    local count = call(api and api.GetNumFactions or GetNumFactions) or 0
    for index = 1, count do
        local raw = call(api and api.GetFactionDataByIndex, index)
        local id, name, rank, low, high, current
        if type(raw) == "table" and D.Read(raw.isHeader) and not raw.isHeader then
            id, name, rank = raw.factionID, raw.name, raw.reaction
            low, high, current = raw.currentReactionThreshold, raw.nextReactionThreshold, raw.currentStanding
        elseif type(raw) ~= "table" and GetFactionInfo then
            local n, _, reaction, a, b, value, _, _, isHeader, _, _, _, _, factionID = call(GetFactionInfo, index)
            if D.Read(isHeader) and not isHeader then id, name, rank, low, high, current = factionID, n, reaction, a, b, value end
        end
        if D.Read(id) and D.Read(current) and D.Read(low) and D.Read(high) and D.Read(name) and D.Read(rank)
            and type(id) == "number" and type(name) == "string"
            and type(current) == "number" and type(low) == "number" and type(high) == "number" then
            local entry = reputation[id] or {start = current}
            reputation[id] = entry
            if entry.last and current > entry.last then entry.activity = time end
            entry.last = current
            local standing = rank and _G["FACTION_STANDING_LABEL" .. rank] or ""
            local remaining = math.max(0, high - current)
            local detail = ("%s\n%d to next standing\n%+d this session"):format(standing, remaining, current - entry.start)
            local row = D.Value(name, math.max(0, current - low), high > low and high - low or nil, detail)
            if high <= low then row.value = standing end
            row.pin = D.Pin("factions", id)
            factions[#factions + 1] = {id = id, activity = entry.activity, rank = rank, standing = standing, row = row}
        end
    end
    factionSnapshot = factions
    return factions
end
D.ReadFactions = scanFactions
D.InvalidateFactions = factionEvent
local nextFactionExpiry
local function factionRows(options)
    local data = D.Tracking()
    local pinned = data and data.factions or {}
    local rows, time, awake = {}, GetTime(), false
    nextFactionExpiry = nil
    for _, entry in ipairs(scanFactions()) do
        local recent = entry.activity and time - entry.activity < options.duration
        if recent then
            awake = true
            nextFactionExpiry = math.min(nextFactionExpiry or math.huge, entry.activity + options.duration)
        end
        if recent or pinned[entry.id] or options.pinned or options.mode == "always" then
            entry.row.highlight = recent
            rows[#rows + 1] = entry.row
        end
    end
    local relevant = awake
    for id in pairs(pinned) do if reputation[id] then relevant = true; break end end
    return rowsResult(rows, relevant, awake)
end
D.Register({id = "reputation", label = "Reputation", priority = 60, read = factionRows,
    resync = factionEvent, event = factionEvent, tick = function() return nextFactionExpiry and GetTime() >= nextFactionExpiry end,
    events = {"UPDATE_FACTION", "PLAYER_ENTERING_WORLD"}})

local function currentRun()
    local name, kind, difficulty, _, _, _, _, instanceID = call(GetInstanceInfo)
    if not D.Read(kind) or not D.Read(difficulty) or not D.Read(instanceID) or (kind ~= "party" and kind ~= "raid") then
        run = nil
        return
    end
    if not run or run.instanceID ~= instanceID or run.difficulty ~= difficulty or run.name ~= name then
        run = {instanceID = instanceID, name = name, kind = kind, difficulty = difficulty, start = GetTime(),
            kills = {}, attempts = 0, wipes = 0, deaths = 0}
    end
    return run
end

local function encounterEvent(event, id, name, _, _, success)
    local instance = currentRun()
    if not instance then return end
    if event == "PLAYER_DEAD" then instance.deaths = instance.deaths + 1
    elseif D.Read(id) and type(id) == "number" and D.Read(name) and type(name) == "string" then
        if event == "ENCOUNTER_START" then
            if instance.encounterID ~= id then instance.attempts = instance.attempts + 1 end
            instance.encounterID, instance.encounterName, instance.encounterStart = id, name, GetTime()
        elseif event == "ENCOUNTER_END" and D.Read(success) then
            if success == 1 or success == true then instance.kills[name] = true
            elseif instance.encounterID == id and (success == 0 or success == false) then instance.wipes = instance.wipes + 1 end
            instance.encounterID, instance.encounterName, instance.encounterStart = nil, nil, nil
        end
    end
end

local function nativeBosses(instance)
    local total = call(GetNumSavedInstances) or 0
    for index = 1, total do
        local name, _, reset, difficulty, locked, extended, _, raid, _, _, encounters = call(GetSavedInstanceInfo, index)
        if D.Read(difficulty) and D.Read(locked) and D.Read(extended) and D.Read(raid) and D.Read(encounters)
            and name == instance.name and difficulty == instance.difficulty and (locked or extended)
            and (instance.kind == "raid") == not not raid and type(encounters) == "number" and encounters > 0 then
            local bosses = {}
            for n = 1, encounters do
                local boss, _, defeated = call(GetSavedInstanceEncounterInfo, index, n)
                if not (boss and D.Read(defeated)) then return end
                bosses[#bosses + 1] = {label = boss, done = defeated == true or instance.kills[boss]}
            end
            return bosses, reset
        end
    end
end

local function instanceRows(kind)
    local instance = currentRun()
    if not instance or instance.kind ~= kind then return end
    local rows = {{label = "Time in instance", value = elapsed(GetTime() - instance.start)}}
    local bosses, reset = nativeBosses(instance)
    if bosses then
        local count = 0
        for _, row in ipairs(bosses) do if row.done then count = count + 1 end end
        rows[#rows + 1] = D.Value("Bosses defeated", count, #bosses)
        if D.Read(reset) and type(reset) == "number" and reset > 0 then
            rows[#rows + 1] = {label = "Lockout resets in", value = elapsed(reset)}
        end
    else
        bosses = {}
        for name in pairs(instance.kills) do bosses[#bosses + 1] = {label = name, done = true} end
        table.sort(bosses, function(a, b) return a.label < b.label end)
        rows[#rows + 1] = {label = "Confirmed boss kills", value = tostring(#bosses)}
    end
    for _, row in ipairs(bosses) do row.value = row.done and "Defeated" or ""; rows[#rows + 1] = row end
    if instance.encounterName then
        rows[#rows + 1] = {label = instance.encounterName, value = elapsed(GetTime() - instance.encounterStart), highlight = true}
    end
    if instance.attempts > 0 then rows[#rows + 1] = {label = "Attempts / wipes", value = ("%d / %d"):format(instance.attempts, instance.wipes)} end
    if instance.deaths > 0 then rows[#rows + 1] = {label = "Deaths", value = tostring(instance.deaths)} end
    return rowsResult(rows, true, instance.encounterName ~= nil, instance.name)
end

local instanceEvents = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "UPDATE_INSTANCE_INFO", "PLAYER_DEAD"}
D.Register({id = "dungeon", label = "Dungeon", priority = 90, read = function() return instanceRows("party") end,
    tick = true, event = encounterEvent, events = instanceEvents})
D.Register({id = "raid", label = "Raid", priority = 90, read = function() return instanceRows("raid") end,
    tick = true, event = encounterEvent, events = instanceEvents})

local function pvpRows()
    local name, kind = call(GetInstanceInfo)
    if not D.Read(kind) or (kind ~= "pvp" and kind ~= "arena") then
        if battleground and battleground.finishedAt and GetTime() - battleground.finishedAt <= 25 then
            return battleground.summary
        end
        battleground = nil
        return
    end
    if not battleground or battleground.name ~= name then battleground = {name = name, start = GetTime()} end
    local rows = {{label = "Match duration", value = elapsed(GetTime() - battleground.start)}}
    local function row(label, value)
        if D.Read(value) and type(value) == "number" then rows[#rows + 1] = {label = label, value = tostring(value)} end
    end
    local api = C_PvP
    local guid = call(UnitGUID, "player")
    local score = guid and call(api and api.GetScoreInfoByPlayerGuid, guid)
    if type(score) == "table" then
        row("Killing blows", score.killingBlows)
        row("Honorable kills", score.honorableKills)
        row("Deaths", score.deaths)
        row("Honor gained", score.honorGained)
    elseif GetBattlefieldScore then
        local player, realm = call(UnitFullName or UnitName, "player")
        local full = player and type(realm) == "string" and realm ~= "" and (player .. "-" .. realm) or player
        for index = 1, call(GetNumBattlefieldScores) or 0 do
            local unit, kills, honorable, deaths, honor = call(GetBattlefieldScore, index)
            if unit and (unit == full or unit == player) then
                row("Killing blows", kills); row("Honorable kills", honorable); row("Deaths", deaths); row("Honor gained", honor)
                break
            end
        end
    end
    local summary = rowsResult(rows, true, true, name)
    battleground.summary = summary
    local winner = call(GetBattlefieldWinner)
    if winner ~= nil then battleground.finishedAt = battleground.finishedAt or GetTime() end
    return summary
end
D.Register({id = "pvp", label = "Battleground", priority = 90, tick = true, read = pvpRows,
    events = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_BATTLEFIELD_SCORE", "PVP_MATCH_COMPLETE"}})
