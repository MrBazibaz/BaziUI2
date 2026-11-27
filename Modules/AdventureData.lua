local addon, D = BaziUI, BaziUI.Dashboard
local A = {listeners = {}, slots = {}, events = CreateFrame("Frame")}
addon.Adventure = A
A.Call, A.Read = D.Call, D.Read
local call, read = A.Call, A.Read

local defaults = {
    alerts = {enabled = false, x = 360, y = 170, width = 290, scale = 100, opacity = 94, growUp = false,
        maximum = 4, duration = 8, animation = 15, free = 3, durability = 15, ammo = 200, criticalAmmo = 50,
        valuable = 0, dashboard = false, standalone = true, combat = true, peace = true, soundKey = "raidWarning"},
    journey = {enabled = false, retention = 90, limit = 800},
    alts = {enabled = false, tooltip = true, shift = true, sameRealm = true, individual = true, total = true},
}

function A.Settings(module)
    local profile = addon.db.profile
    profile.adventure = profile.adventure or {}
    local cfg = profile.adventure[module]
    if not cfg then cfg = {}; profile.adventure[module] = cfg end
    for key, value in pairs(defaults[module]) do if cfg[key] == nil then cfg[key] = value end end
    return cfg
end

function A.Now()
    return call(GetServerTime) or time()
end

function A.Key()
    return addon.Database:CharacterKey()
end

function A.Data()
    local store = addon.db.adventure
    if not store then
        store = {version = 1, characters = {}, journals = {}}
        addon.db.adventure = store
    end
    if store.version == 1 then return store end
end

function A.ID(item)
    if not read(item) then return end
    if type(item) == "number" then return item end
    if type(item) == "string" then return tonumber(item:match("item:(%d+)") or item) end
end

function A.ItemDetails(item)
    local name, _, quality, _, _, _, _, _, _, _, price, class, sub = call(addon.Inventory.GetItemInfo, item)
    if type(name) ~= "string" then return end
    return {name = name, quality = read(quality) and quality or nil, price = read(price) and price or nil,
        class = read(class) and class or nil, sub = read(sub) and sub or nil}
end

function A.On(event, fn)
    local list = A.listeners[event] or {}
    A.listeners[event] = list
    list[#list + 1] = fn
end

local errors = {}
function A.Emit(event, ...)
    for _, fn in ipairs(A.listeners[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and not errors[fn] then
            errors[fn] = true
            addon:Print("Progression (" .. event .. "): " .. tostring(err))
        end
    end
end

local names = {"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
    "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged"}
local slotNames = {Finger0 = "Ring 1", Finger1 = "Ring 2", Trinket0 = "Trinket 1", Trinket1 = "Trinket 2",
    MainHand = "Main hand", SecondaryHand = "Off hand"}
A.SlotNames = slotNames

local function slotID(name)
    local id = A.slots[name]
    if not id then
        id = call(GetInventorySlotInfo, name .. "Slot")
        A.slots[name] = id
    end
    return id
end
A.SlotID = slotID

local function equipment()
    local result = {}
    for _, name in ipairs(names) do
        local slot = slotID(name)
        if slot then
            local link = call(GetInventoryItemLink, "player", slot)
            local item = call(GetInventoryItemID, "player", slot)
            local current, maximum = call(GetInventoryItemDurability, slot)
            result[name] = {link = link, id = item or A.ID(link), current = current, maximum = read(maximum) and maximum or nil}
        end
    end
    return result
end

local function identity()
    local class, token, classID = call(UnitClass, "player")
    return {key = A.Key(), name = call(UnitName, "player"), realm = call(GetRealmName), class = class,
        token = token, classID = classID, race = call(UnitRace, "player"), faction = call(UnitFactionGroup, "player"),
        level = call(UnitLevel, "player"), zone = call(GetRealZoneText), subzone = call(GetSubZoneText),
        money = call(GetMoney), rested = call(GetXPExhaustion)}
end

function A.EquipmentSnapshot()
    return {identity = identity(), gear = equipment()}
end

local function freeSlots()
    local free, known = 0, false
    for _, bag in ipairs(addon.Inventory.BagIDs()) do
        local count, family = call(C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots, bag)
        if type(count) == "number" and read(family) then
            known = true
            if (family or 0) == 0 then free = free + count end
        end
    end
    return known and free or nil
end

local function bankIDs()
    local ids = {}
    local index = Enum and Enum.BagIndex
    if index and index.CharacterBankTab_1 then
        for i = 1, 9 do
            if index["CharacterBankTab_" .. i] then ids[#ids + 1] = index["CharacterBankTab_" .. i] end
        end
    else
        ids[1] = index and index.Bank or BANK_CONTAINER or -1
        local first = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
        local count = call(GetNumBankSlots) or NUM_BANKBAGSLOTS or 7
        for i = 1, count do ids[#ids + 1] = first + i end
    end
    return ids
end

function A.ScanItems(bank)
    local api = C_Container
    local countSlots = api and api.GetContainerNumSlots or GetContainerNumSlots
    if not countSlots then return end
    local ids = bank and bankIDs() or addon.Inventory.BagIDs(true)
    local items, free, total, known = {}, 0, 0, false
    for _, bag in ipairs(ids) do
        local count = call(countSlots, bag)
        if type(count) == "number" and count > 0 then
            known = true
            local available, family = call(api and api.GetContainerNumFreeSlots or GetContainerNumFreeSlots, bag)
            if type(available) ~= "number" or not read(family) then
                free = nil
            elseif free and (family == nil or family == 0) then
                free = free + available
            end
            total = total + count
            for slot = 1, count do
                local info = call(api and api.GetContainerItemInfo, bag, slot)
                local id, link, amount, quality, bound
                if type(info) == "table" and read(info.itemID) and read(info.hyperlink) and read(info.stackCount) then
                    id, link, amount = info.itemID, info.hyperlink, info.stackCount
                    quality, bound = read(info.quality) and info.quality or nil, read(info.isBound) and info.isBound
                    if not read(info.isBound) or type(info.isBound) ~= "boolean" then
                        local location = ItemLocation and call(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
                        bound = location and call(C_Item and C_Item.IsBound, location)
                    end
                elseif not (api and api.GetContainerItemInfo) then
                    link = call(GetContainerItemLink, bag, slot)
                    id = A.ID(link)
                    local _, stack, _, rarity = call(GetContainerItemInfo, bag, slot)
                    amount, quality = read(stack) and stack or nil, read(rarity) and rarity or nil
                end
                if type(id) == "number" and type(amount) == "number" and amount > 0 then
                    items[#items + 1] = {id = id, link = link, count = amount, quality = quality, bound = bound, bag = bag, slot = slot}
                end
            end
        end
    end
    if known then return {items = items, time = A.Now(), free = free, total = total} end
end

local queue, timer, bankOpen, logged = {}, nil, false, false
local function flush()
    timer = nil
    local dirty = queue
    queue = {}
    local current = A.current or {}
    A.current = current
    if dirty.skills and D.InvalidateSkills then D.InvalidateSkills() end
    if dirty.identity or not current.identity then current.identity = identity() end
    if dirty.gear then current.gear = equipment() end
    if dirty.skills and D.ReadSkills then
        current.skills = {}
        for _, entry in ipairs(D.ReadSkills()) do
            current.skills[entry.name] = {rank = entry.rank, maximum = entry.maximum, profession = entry.spell ~= nil}
        end
    end
    if dirty.reputation and D.ReadFactions then
        D.InvalidateFactions()
        current.factions = D.ReadFactions()
    end
    if dirty.bags then
        if A.Settings("alts").enabled then current.bags = A.ScanItems(false) end
        current.free = current.bags and current.bags.free or freeSlots()
    end
    if dirty.bank and bankOpen and A.Settings("alts").enabled then current.bank = A.ScanItems(true) or current.bank end
    A.Emit("snapshot", current, dirty)
end

function A.Queue(key)
    queue[key] = true
    if not timer then timer = C_Timer.NewTimer(0.15, flush) end
end

local function enabled()
    return A.Settings("alerts").enabled or A.Settings("journey").enabled or A.Settings("alts").enabled
end

function A.Refresh()
    if not logged then return end
    A.SessionDriver = A.Settings("journey").enabled
    if not enabled() then A.Emit("settings"); return end
    for _, key in ipairs({"identity", "gear", "skills", "bags", "quests", "class", "mail", "reputation"}) do A.Queue(key) end
    if bankOpen then A.Queue("bank") end
    A.Emit("settings")
end

local dirtyEvents = {
    BAG_UPDATE_DELAYED = "bags", PLAYER_EQUIPMENT_CHANGED = "gear", UPDATE_INVENTORY_DURABILITY = "gear",
    SKILL_LINES_CHANGED = "skills", CHAT_MSG_SKILL = "skills", TRADE_SKILL_LIST_UPDATE = "skills",
    PLAYER_LEVEL_UP = "identity", PLAYER_MONEY = "identity", UPDATE_EXHAUSTION = "identity",
    ZONE_CHANGED = "identity", ZONE_CHANGED_INDOORS = "identity", ZONE_CHANGED_NEW_AREA = "identity",
    QUEST_LOG_UPDATE = "quests", QUEST_WATCH_UPDATE = "quests", UPDATE_PENDING_MAIL = "mail",
    UNIT_PET = "class", UNIT_AURA = "class", PET_UI_UPDATE = "class", UPDATE_FACTION = "reputation",
    PLAYER_AMMO_CHANGED = "class", UNIT_INVENTORY_CHANGED = "class", SPELLS_CHANGED = "class", WEAPON_ENCHANT_CHANGED = "class",
    MINIMAP_UPDATE_TRACKING = "class", PLAYER_ALIVE = "class", PLAYER_UNGHOST = "class", PLAYER_DEAD = "class",
    PLAYER_REGEN_DISABLED = "class", PLAYER_REGEN_ENABLED = "class",
}
local extraEvents = {"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "QUEST_TURNED_IN", "QUEST_COMPLETE", "CHAT_MSG_LOOT", "UNIT_SPELLCAST_SUCCEEDED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "UPDATE_INSTANCE_INFO", "NEW_RECIPE_LEARNED",
    "ENCOUNTER_END", "LFG_COMPLETION_REWARD", "CHALLENGE_MODE_COMPLETED", "PVP_MATCH_COMPLETE", "PLAYER_XP_UPDATE", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
    "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED"}
for event in pairs(dirtyEvents) do
    if event == "UNIT_AURA" and A.events.RegisterUnitEvent then
        pcall(A.events.RegisterUnitEvent, A.events, event, "player", "pet")
    else pcall(A.events.RegisterEvent, A.events, event) end
end
for _, event in ipairs(extraEvents) do pcall(A.events.RegisterEvent, A.events, event) end

local awaitingLoot = {}
local function resolveLoot(id, count, link)
    if not (A.Settings("alerts").enabled or A.Settings("journey").enabled) then return end
    local item = A.ItemDetails(link or id)
    if item then
        awaitingLoot[id] = nil
        A.Emit("lootDetails", id, count, link, item)
    else
        if not D.HasRoom(awaitingLoot) then wipe(awaitingLoot) end
        awaitingLoot[id] = {count = count, link = link, untilTime = GetTime() + 8}
    end
end

A.events:SetScript("OnEvent", function(_, event, ...)
    if not addon.db then return end
    if event == "PLAYER_LOGIN" then logged = true end
    if not logged then return end
    if event == "BANKFRAME_OPENED" then bankOpen = true end
    if event == "BANKFRAME_CLOSED" then bankOpen = false end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spell = ...
        if unit == "player" and read(spell) and type(spell) == "number" then
            A.Emit("playerSpellCast", spell)
            if A.Settings("alerts").enabled then A.Queue("class") end
        end
        return
    end
    if not enabled() then
        if event == "PLAYER_LOGIN" then A.Emit("ready") end
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then A.Refresh() end
    local dirty = dirtyEvents[event]
    if dirty == "class" and event == "UNIT_AURA" and (...) ~= "player" and (...) ~= "pet" then return end
    if dirty then A.Queue(dirty) end
    if bankOpen and (dirty == "bags" or event == "BANKFRAME_OPENED") then A.Queue("bank") end
    if event == "PLAYER_LOGOUT" and timer then timer:Cancel(); flush() end
    if A.SessionDriver and (event == "PLAYER_LOGOUT" or event == "PLAYER_MONEY" or event == "PLAYER_XP_UPDATE"
        or event == "PLAYER_LEVEL_UP" or event == "QUEST_TURNED_IN" or event == "PLAYER_DEAD" or event == "CHAT_MSG_LOOT") then
        D.RecordSessionEvent(event, ...)
    end
    A.Emit("sessionEvent", event, ...)
    if event == "CHAT_MSG_LOOT" then
        local id, count, link = D.ReadSelfLoot(...)
        if id then
            A.Emit("loot", id, count, link)
            resolveLoot(id, count, link)
            if A.Settings("alts").enabled then A.Queue("bags") end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id, success = ...
        if read(id) and type(id) == "number" and awaitingLoot[id] then
            local pending = awaitingLoot[id]
            awaitingLoot[id] = nil
            if read(success) and success and pending.untilTime >= GetTime() then resolveLoot(id, pending.count, pending.link) end
        end
    end
    A.Emit(event, ...)
end)
