local addon, D = BaziUI, BaziUI.Dashboard
local widgetID = "recentActivity"
local notices, nextExpiry = {}, nil
local tracking, lastXP, lastLevel, lastCap
local streaks = {}
local activityTime, lootedItems = nil, {}
local filtersInstalled

local moneyFormats = {"YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD", "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT"}
local chatGroups = {CHAT_MSG_LOOT = "LOOT", CHAT_MSG_MONEY = "MONEY",
    CHAT_MSG_COMBAT_XP_GAIN = "COMBAT_XP_GAIN", CHAT_MSG_SYSTEM = "SYSTEM"}
local routeHistory
local function grouped()
    return IsInGroup and (IsInGroup() or LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE))
end
local killFormats = {"COMBATLOG_XPGAIN_FIRSTPERSON",
    "COMBATLOG_XPGAIN_FIRSTPERSON_GROUP", "COMBATLOG_XPGAIN_FIRSTPERSON_RAID",
    "COMBATLOG_XPGAIN_EXHAUSTION1", "COMBATLOG_XPGAIN_EXHAUSTION2",
    "COMBATLOG_XPGAIN_EXHAUSTION4", "COMBATLOG_XPGAIN_EXHAUSTION5",
    "COMBATLOG_XPGAIN_EXHAUSTION1_GROUP", "COMBATLOG_XPGAIN_EXHAUSTION1_RAID",
    "COMBATLOG_XPGAIN_EXHAUSTION2_GROUP", "COMBATLOG_XPGAIN_EXHAUSTION2_RAID",
    "COMBATLOG_XPGAIN_EXHAUSTION4_GROUP", "COMBATLOG_XPGAIN_EXHAUSTION4_RAID",
    "COMBATLOG_XPGAIN_EXHAUSTION5_GROUP", "COMBATLOG_XPGAIN_EXHAUSTION5_RAID"}
local milestones = {
    {at = 3, title = "On a roll", color = {0.73, 0.58, 0.96}},
    {at = 5, title = "Killing spree", color = {0.96, 0.69, 0.39}},
    {at = 10, title = "Rampage", color = {1, 0.46, 0.34}},
    {at = 20, title = "Unstoppable", color = {1, 0.79, 0.33}},
}

local function matchFormat(message, template, partial, argument)
    if type(template) ~= "string" then return end
    local pattern, positions, cursor = {partial and "" or "^"}, {}, 1
    while true do
        local first, last, position, kind = template:find("%%(%d*%$?)([sd])", cursor)
        local literal = template:sub(cursor, first and first - 1 or #template)
        pattern[#pattern + 1] = literal:gsub("%%%%", "%%"):gsub("([^%w])", "%%%1")
        if not first then break end
        pattern[#pattern + 1] = kind == "s" and "(.+)" or "(%d+)"
        positions[#positions + 1] = tonumber(position:match("%d+")) or #positions + 1
        cursor = last + 1
    end
    if #positions == 0 then return end
    if not partial then pattern[#pattern + 1] = "$" end
    local captures = {message:match(table.concat(pattern))}
    for index, position in ipairs(positions) do
        if position == (argument or 1) then return captures[index] end
    end
end

D.MatchChatFormat = matchFormat

local coinValues = {GOLD = 10000, SILVER = 100, COPPER = 1}
local function readCoins(text)
    local total = 0
    for denomination, multiplier in pairs(coinValues) do
        local amount = tonumber(matchFormat(text, _G[denomination .. "_AMOUNT"], true)
            or matchFormat(text, _G[denomination .. "_AMOUNT_TEXTURE"], true))
        if amount then total = total + amount * multiplier end
    end
    return total > 0 and total or nil
end

function D.ReadLootMoney(message)
    if not D.Read(message) or type(message) ~= "string" then return end
    for _, key in ipairs(moneyFormats) do
        local amount = matchFormat(message, _G[key])
        local copper = amount and readCoins(amount)
        if copper then return copper end
    end
end

local function classify(event, message)
    if not D.Read(message) or type(message) ~= "string" then return end
    if event == "CHAT_MSG_COMBAT_XP_GAIN" then
        return "xp"
    elseif event == "CHAT_MSG_SYSTEM" then
        local amount = tonumber(matchFormat(message, ERR_QUEST_REWARD_EXP_I))
        if amount then return "xp", amount end
    elseif event == "CHAT_MSG_LOOT" then
        local id, count, link = D.ReadSelfLoot(message)
        if id then return "item", id, count, link end
    elseif event == "CHAT_MSG_MONEY" then
        local copper = D.ReadLootMoney(message)
        if copper then return "money", copper end
    end
end

local function expireActivity(now, duration)
    if activityTime and now - activityTime >= duration then
        activityTime = nil
        notices.xp, notices.money = nil, nil
        streaks.xp, streaks.loot, streaks.money = nil, nil, nil
        wipe(lootedItems)
    end
end

local function accumulate(key, amount)
    local now = GetTime()
    local duration = D.WidgetSettings(widgetID).duration
    if key ~= "kills" then
        expireActivity(now, duration)
        activityTime = now
    end
    local previous = streaks[key]
    local total = amount + (previous and (key ~= "kills" or now - previous.time < duration) and previous.total or 0)
    streaks[key] = {time = now, total = total}
    local character = D.Tracking()
    if not character then return total, total end
    character.activityRecords = character.activityRecords or {}
    local best = math.max(total, character.activityRecords[key] or 0)
    character.activityRecords[key] = best
    return total, best
end

local function xpNotice(amount)
    local total, best = accumulate("xp", amount)
    notices.xp = {label = "Experience", icon = 135932,
        value = "+" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(total) or total),
        tooltip = ("Personal best: +%d XP"):format(best)}
    D.Notify("dashboardXP", "Experience +" .. amount)
end

function D.IsKillMessage(message)
    if not D.Read(message) or type(message) ~= "string" then return false end
    for _, key in ipairs(killFormats) do
        local amount = matchFormat(message, _G[key], false, 2)
        local xp = tonumber(amount)
        if xp and xp > 0 then return true end
    end
    return false
end

local function killNotice(message)
    if not grouped() and D.IsKillMessage(message) then
        local total, best = accumulate("kills", 1)
        local tier = 0
        for index, milestone in ipairs(milestones) do if total >= milestone.at then tier = index end end
        local milestone = milestones[tier]
        notices.kills = {label = milestone and milestone.title or "Kill streak", icon = 132338,
            value = tostring(total), tooltip = ("Personal best: %d kills"):format(best),
            labelColor = milestone and milestone.color, streakTier = tier, streakCount = total}
    end
end

local function readXP()
    local xp, level = D.Call(UnitXP, "player"), D.Call(UnitLevel, "player")
    if type(xp) == "number" and type(level) == "number" and level > 0 then
        return xp, level, D.Call(UnitXPMax, "player")
    end
end

local function updateXP()
    local xp, level, cap = readXP()
    if not xp then return end
    local amount
    if lastXP then
        if level == lastLevel then amount = xp - lastXP
        elseif level == lastLevel + 1 and type(lastCap) == "number" and lastCap > 0 then amount = lastCap - lastXP + xp end
        if amount and amount > 0 then xpNotice(amount) end
    end
    lastXP, lastLevel, lastCap = xp, level, cap
end

local function event(name, value)
    if name == "PLAYER_ENTERING_WORLD" then
        lastXP, lastLevel, lastCap = readXP()
    elseif name == "PLAYER_XP_UPDATE" and (not value or value == "player") then
        updateXP()
    elseif name == "PLAYER_LEVEL_UP" then
        updateXP()
    elseif name == "PLAYER_DEAD" or name == "GROUP_ROSTER_UPDATE" then
        if name == "PLAYER_DEAD" or grouped() then streaks.kills, notices.kills = nil, nil end
    else
        local kind, first, count, link = classify(name, value)
        if kind then routeHistory(name, value) end
        if kind == "xp" then
            updateXP()
            if name == "CHAT_MSG_COMBAT_XP_GAIN" then killNotice(value) end
        elseif kind == "item" then
            local label, icon, itemLink = D.Item(first)
            label = link and link:match("|h%[(.-)%]|h") or label
            count = count or 1
            local _, best = accumulate("loot", count)
            local item = lootedItems[first] or {count = 0}
            item.label, item.icon, item.link, item.count = label, icon, link or itemLink, item.count + count
            item.value = item.count > 1 and "×" .. item.count or ""
            item.tooltip = ("Personal best: %d items looted in one streak"):format(best)
            lootedItems[first] = item
            D.Notify("dashboardLoot", "Looted " .. (link or itemLink or label))
        elseif kind == "money" then
            local total, best = accumulate("money", first)
            local money = addon.Inventory.Money
            notices.money = {label = "Coins", icon = 133784, value = money(total), tooltip = "Personal best: " .. money(best)}
            D.Notify("dashboardMoney", "Looted " .. money(first))
        end
    end
end

local function rows(options)
    local now = GetTime()
    local result = {}
    local duration = options.duration
    expireActivity(now, duration)
    local killTime = streaks.kills and streaks.kills.time
    if killTime and now - killTime >= duration then
        killTime, streaks.kills, notices.kills = nil, nil, nil
    end
    local start = killTime or activityTime
    local first = start and math.min(start, activityTime or start)
    nextExpiry = first and first + duration
    for _, key in ipairs({"kills", "xp", "money"}) do
        if notices[key] then result[#result + 1] = notices[key] end
    end
    local items = {}
    for _, item in pairs(lootedItems) do items[#items + 1] = item end
    table.sort(items, function(a, b) return a.label < b.label end)
    for _, item in ipairs(items) do result[#result + 1] = item end
    local data = D.Rows(result, #result > 0, #result > 0)
    if start then data.countdown = {start = start, duration = duration} end
    return data
end

local function lootTab()
    if not GetChatWindowInfo then return end
    local localized = addon.Chat and addon.Chat.L and addon.Chat.L.newTabLoot
    local max = Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS or 10
    for id = 1, max do
        local frame = _G["ChatFrame" .. id]
        if frame and frame ~= DEFAULT_CHAT_FRAME and frame ~= COMBATLOG and not frame:IsForbidden()
            and (frame.isDocked or frame:IsShown()) then
            local name = GetChatWindowInfo(id)
            if type(name) == "string" and (name == localized or name == LOOT or name:lower() == "loot") then return frame end
        end
    end
end

local function historyDestination(eventName)
    if not tracking or not filtersInstalled or not D.Settings().hideActivityChat
        or D.WidgetSettings(widgetID).mode == "hidden" then return end
    local history = lootTab()
    if not history then return end
    local group = chatGroups[eventName]
    for _, current in pairs(history.messageTypeList or {}) do
        if current == group then return history end -- Blizzard already delivers it to this tab.
    end
    local info = ChatTypeInfo and ChatTypeInfo[group]
    if info then return history, info end
end

routeHistory = function(eventName, message)
    local history, info = historyDestination(eventName)
    if info then history:AddMessage(message, info.r, info.g, info.b, info.id) end
end

local function filter(frame, eventName, message)
    if frame == DEFAULT_CHAT_FRAME and historyDestination(eventName) then return classify(eventName, message) ~= nil end
end

function D.RefreshActivityNotices(cfg)
    local enabled = cfg.enabled and D.WidgetSettings(widgetID).enabled or false
    if tracking ~= enabled then
        tracking = enabled
        wipe(notices)
        lastXP, lastLevel, lastCap = readXP()
        wipe(streaks)
        wipe(lootedItems)
        nextExpiry, activityTime = nil, nil
    end
    if enabled and cfg.hideActivityChat and not filtersInstalled then
        local register = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
        if not register then return end
        for chatEvent in pairs(chatGroups) do register(chatEvent, filter) end
        filtersInstalled = true
    end
end

D.Register({id = widgetID, label = "Recent activity", priority = 105, read = rows, event = event,
    tick = function() return nextExpiry and GetTime() >= nextExpiry end,
    events = {"PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "GROUP_ROSTER_UPDATE", "CHAT_MSG_COMBAT_XP_GAIN",
        "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY"}})
