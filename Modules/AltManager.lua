local addon, A = BaziUI, BaziUI.Adventure
local call, read = A.Call, A.Read
local M = {}
addon.AltManager = M

function M.Characters()
    local data = A.Data()
    return data and data.characters or {}
end

local ownershipIndex = setmetatable({}, {__mode = "k"})
local function matching(snapshot, id)
    if not snapshot then return nil, 0 end
    local index = ownershipIndex[snapshot]
    if not index then
        index = {}
        for _, item in ipairs(snapshot.items or {}) do
            local counts = index[item.id] or {0, 0}
            counts[1] = counts[1] + item.count
            if item.bound == false then counts[2] = counts[2] + item.count end
            index[item.id] = counts
        end
        ownershipIndex[snapshot] = index
    end
    local counts = index[id]
    return counts and counts[1] or 0, counts and counts[2] or 0
end

local function eligible(a, b)
    return a and b and a.realm and a.faction and a.realm == b.realm and a.faction == b.faction
end
M.SameTransferGroup = eligible

function M.Ownership(id, sameRealm, characters, player)
    local matches, total = {}, 0
    player = player or A.current and A.current.identity
    for key, char in pairs(characters or M.Characters()) do
        local meta = char.identity
        if meta and (not sameRealm or player and player.realm and player.realm == meta.realm) then
            local bags, unboundBags = matching(char.bags, id)
            local bank, unboundBank = matching(char.bank, id)
            local sum = (bags or 0) + (bank or 0)
            if sum > 0 then
                total = total + sum
                matches[#matches + 1] = {identity = meta, key = key, bags = bags, bank = bank, count = sum,
                    bagTime = char.bags and char.bags.time, bankTime = char.bank and char.bank.time,
                    transferable = eligible(meta, player) and unboundBags + unboundBank or nil}
            end
        end
    end
    table.sort(matches, function(a, b)
        if a.count == b.count then return a.key < b.key end
        return a.count > b.count
    end)
    return matches, total
end

local function current()
    if not A.Settings("alts").enabled then return end
    local key = A.Key()
    return key and M.Characters()[key]
end

A.On("snapshot", function(snapshot, dirty)
    if not A.Settings("alts").enabled then return end
    local meta = snapshot.identity
    if not (meta and meta.key and meta.name and meta.realm) then return end
    local data = A.Data()
    if not data then return end
    local char = data.characters[meta.key] or {}
    data.characters[meta.key] = char
    if not char.login or not M.loginKey then char.login = A.Now(); M.loginKey = meta.key end
    if dirty.identity and char.identity and type(meta.money) == "number" and type(char.identity.money) == "number" then
        local change = meta.money - char.identity.money
        if change ~= 0 then char.goldChange = change end
    end
    char.identity, char.updated, char.free = meta, A.Now(), snapshot.free
    char.gear, char.bags, char.bank = snapshot.gear or char.gear, snapshot.bags or char.bags, snapshot.bank or char.bank
    if snapshot.skills and next(snapshot.skills) then char.skills = snapshot.skills end
    local advisor = addon.LootUpgrades
    if advisor and advisor.CurrentProfileKey and (dirty.identity or dirty.gear or dirty.skills or not char.gearProfile) then
        char.gearProfile = advisor.CurrentProfileKey()
    end
end)

for _, event in ipairs({"PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED"}) do
    A.On(event, function() if A.Settings("alts").enabled then A.Queue("identity") end end)
end

local function stage(fn)
    if not A.Settings("alts").enabled then return end
    local char = current()
    if char then fn(char) end
end

local function recordMail()
    stage(function(char)
        local shown, total = call(GetInboxNumItems)
        if type(shown) ~= "number" then return end
        local mail = {}
        for i = 1, math.min(50, shown) do
            local _, _, sender, subject, money, cod, days, items = call(GetInboxHeaderInfo, i)
            if read(subject) and type(subject) == "string" and read(sender) and read(money) and read(cod) and read(days) and read(items) then
                mail[#mail + 1] = {sender = sender, title = subject, money = money, cod = cod, days = days, items = items}
            end
        end
        char.mail = {time = A.Now(), total = read(total) and total or shown, entries = mail}
    end)
end
A.On("MAIL_SHOW", recordMail)
A.On("MAIL_INBOX_UPDATE", recordMail)

local auctionOpen
A.On("AUCTION_HOUSE_SHOW", function() auctionOpen = true end)
A.On("AUCTION_HOUSE_CLOSED", function() auctionOpen = false end)
A.On("OWNED_AUCTIONS_UPDATED", function()
    if not auctionOpen then return end
    stage(function(char)
        local list = call(C_AuctionHouse and C_AuctionHouse.GetOwnedAuctions)
        if type(list) ~= "table" then return end
        local entries = {}
        for i, auction in ipairs(list) do
            if i > 100 then break end
            if read(auction.itemLink) and read(auction.quantity) and read(auction.timeLeftSeconds) then
                entries[#entries + 1] = {link = auction.itemLink, count = auction.quantity, seconds = auction.timeLeftSeconds}
            end
        end
        char.auctions = {time = A.Now(), total = #list, entries = entries}
    end)
end)

A.On("UPDATE_INSTANCE_INFO", function()
    stage(function(char)
        local total = call(GetNumSavedInstances)
        if type(total) ~= "number" then return end
        local raids = {}
        for i = 1, math.min(100, total) do
            local name, id, reset, difficulty, locked, extended, _, raid, capacity, mode, bosses, killed = call(GetSavedInstanceInfo, i)
            if read(locked) and read(extended) and (locked or extended) and type(name) == "string"
                and read(id) and read(reset) and read(mode) and read(bosses) and read(killed) then
                raids[#raids + 1] = {name = name, id = id, reset = type(reset) == "number" and A.Now() + reset,
                    mode = mode, killed = killed, bosses = bosses}
            end
        end
        char.lockouts = {time = A.Now(), entries = raids}
    end)
end)

local function recordProfessions()
    stage(function(char)
        local skill = C_TradeSkillUI
        if not skill then return end
        local info = call(skill.GetBaseProfessionInfo)
        local ids = call(skill.GetAllRecipeIDs)
        if type(info) ~= "table" or not read(info.professionName) or type(info.professionName) ~= "string"
            or type(ids) ~= "table" or (skill.IsTradeSkillLinked and call(skill.IsTradeSkillLinked) ~= false)
            or (skill.IsTradeSkillGuild and call(skill.IsTradeSkillGuild) ~= false) then return end
        char.recipes = char.recipes or {}
        local result = {time = A.Now(), entries = {}}
        for _, id in ipairs(ids) do
            local recipe = call(skill.GetRecipeInfo, id)
            if type(recipe) == "table" and read(recipe.learned) and recipe.learned == true and read(recipe.name) then
                local schematic = call(skill.GetRecipeSchematic, id, false)
                local materials = {}
                local output = type(schematic) == "table" and schematic.outputItemID
                if type(schematic) == "table" then
                    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
                        local choices = slot.reagents
                        local qty = slot.quantityRequired
                        if slot.required and type(choices) == "table" and #choices == 1 and type(qty) == "number" then
                            local item = choices[1].itemID
                            if type(item) == "number" then materials[item] = (materials[item] or 0) + qty end
                        end
                    end
                end
                result.entries[id] = {name = recipe.name, materials = materials, output = type(output) == "number" and output or nil}
            end
        end
        if next(result.entries) then char.recipes[info.professionName] = result end
    end)
end
A.On("snapshot", function(_, dirty) if dirty.skills and M.recipePending then M.recipePending = nil; recordProfessions() end end)
A.On("TRADE_SKILL_LIST_UPDATE", function() M.recipePending = true end)
A.On("NEW_RECIPE_LEARNED", function() M.recipePending = true; A.Queue("skills") end)

function M.Goals(key)
    local all = addon.db.dashboardCharacters
    return all and all[key] and all[key].goals or {}
end

function M.UsefulFor(id, includeCurrent, goalsOnly)
    local needs = {}
    for key, char in pairs(M.Characters()) do
        if includeCurrent or key ~= A.Key() then
            local count = matching(char.bags, id)
            local required, recipe
            for _, goal in pairs(M.Goals(key)) do
                local quantity = goal.materials and goal.materials[id]
                if type(quantity) == "number" then required = (required or 0) + quantity * goal.amount end
            end
            if not goalsOnly then
                for name, known in pairs(char.recipes or {}) do
                    for _, entry in pairs(known.entries) do
                        if entry.materials[id] then recipe = name; break end
                    end
                    if recipe then break end
                end
            end
            if required or recipe then needs[#needs + 1] = {identity = char.identity, have = count, need = required, profession = recipe} end
        end
    end
    return needs
end

function M.AddTooltip(frame, id)
    local cfg = A.Settings("alts")
    if not (cfg.enabled and cfg.tooltip and id) or cfg.shift and not IsShiftKeyDown() then return end
    local entries, total = M.Ownership(id, cfg.sameRealm)
    if total > 0 and cfg.total then frame:AddDoubleLine("Account owned (recorded)", tostring(total), 0.79, 0.66, 0.87, 1, 1, 1) end
    if cfg.individual then
        for index, entry in ipairs(entries) do
            if index > 5 then break end
            local amount = tostring(entry.count)
            if cfg.breakdown then
                amount = ("%s bags · %s bank"):format(entry.bags or "?", entry.bank or "?")
            end
            if cfg.lastUpdated and entry.bankTime then amount = amount .. " · bank " .. date("%d %b", entry.bankTime) end
            frame:AddDoubleLine(entry.identity.name .. " · " .. entry.identity.realm, amount, 0.91, 0.81, 0.66, 1, 1, 1)
        end
    end
    if cfg.materials then
        for index, entry in ipairs(M.UsefulFor(id)) do
            if index > 3 then break end
            local value = entry.need and (tostring(entry.have or "?") .. " / " .. entry.need) or entry.profession
            frame:AddDoubleLine(entry.identity.name .. (entry.need and " · crafting goal" or ""), value, 0.79, 0.66, 0.87, 1, 1, 1)
        end
    end
end

A.On("loot", function(id, _, link)
    if not A.Settings("alts").enabled then return end
    for _, entry in ipairs(M.UsefulFor(id, false, true)) do
        if entry.need and (not entry.have or entry.have < entry.need) then
            A.Emit("altMaterial", id, link, entry)
            break
        end
    end
end)


local recentMaterial
A.On("altMaterial", function(id, link, entry)
    recentMaterial = {time = GetTime(), link = link, id = id, entry = entry}
    BaziUI.Dashboard.Invalidate("altGoals")
end)
BaziUI.Dashboard.Register({id = "altGoals", label = "Alt crafting materials", priority = 85, tick = true, read = function(options)
    local rows = {}
    local latest = recentMaterial
    if A.Settings("alts").enabled and latest and GetTime() - latest.time < options.duration then
        local D = BaziUI.Dashboard
        local name, icon = D.Item(latest.id)
        local entry = latest.entry
        rows[1] = {label = name, value = tostring(entry.have or "?") .. " / " .. entry.need, link = latest.link,
            icon = icon, tooltip = entry.identity.name .. " · recorded crafting goal"}
    end
    return BaziUI.Dashboard.Rows(rows, #rows > 0, #rows > 0)
end})
