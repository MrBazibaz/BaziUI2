local addon, D = BaziUI, BaziUI.Dashboard
local widgetID = "recentActivity"
local notices, nextExpiry = {}, nil
local tracking, lastXP, lastLevel, lastCap, lastXPNotice
local filtersInstalled

local moneyFormats = {"YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD", "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT"}
local chatGroups = {CHAT_MSG_LOOT = "LOOT", CHAT_MSG_MONEY = "MONEY",
    CHAT_MSG_COMBAT_XP_GAIN = "COMBAT_XP_GAIN", CHAT_MSG_SYSTEM = "SYSTEM"}
local routeHistory

local function matchFormat(message, template)
    if type(template) ~= "string" then return end
    local pattern, positions, cursor = {"^"}, {}, 1
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
    pattern[#pattern + 1] = "$"
    local captures = {message:match(table.concat(pattern))}
    for index, position in ipairs(positions) do
        if position == 1 then return captures[index] end
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
        for _, key in ipairs(moneyFormats) do
            local amount = matchFormat(message, _G[key])
            if amount then return "money", amount end
        end
    end
end

local function addNotice(key, row, count)
    local now, duration = GetTime(), D.WidgetSettings(widgetID).duration
    for index = #notices, 1, -1 do
        local old = notices[index]
        if old.key == key then
            if count and now - old.time < duration then count = count + old.count end
            table.remove(notices, index)
        end
    end
    if count and count > 1 then row.value = "×" .. count end
    table.insert(notices, 1, {key = key, time = now, row = row, count = count})
    if #notices > 5 then table.remove(notices) end
end

local function xpNotice(amount)
    local now = GetTime()
    local recent = lastXPNotice and now - lastXPNotice < 0.4
    if not amount and recent then return end
    lastXPNotice = now
    addNotice("xp", {label = amount and "Experience" or "Experience gained", icon = 135932,
        value = amount and ("+" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(amount) or tostring(amount))) or nil})
    if not recent then D.Notify("dashboardXP", amount and ("Experience +" .. amount) or "Experience gained") end
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
        if amount and amount > 0 then xpNotice(amount)
        elseif level > lastLevel then xpNotice() end
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
        xpNotice()
    else
        local kind, first, count, link = classify(name, value)
        if kind then routeHistory(name, value) end
        if kind == "xp" then
            xpNotice(first)
        elseif kind == "item" then
            local label, icon, itemLink = D.Item(first)
            label = link and link:match("|h%[(.-)%]|h") or label
            addNotice("item:" .. first, {label = label, icon = icon, link = link or itemLink, itemID = first}, count)
            D.Notify("dashboardLoot", "Looted " .. (link or itemLink or label))
        elseif kind == "money" then
            addNotice("money:" .. first, {label = first, icon = 133784, tooltip = "Looted money"}, 1)
            D.Notify("dashboardMoney", "Looted " .. first)
        end
    end
end

local function rows(options)
    local now = GetTime()
    local result = {}
    nextExpiry = nil
    for index = #notices, 1, -1 do
        local expiry = notices[index].time + options.duration
        if now >= expiry then table.remove(notices, index)
        elseif not nextExpiry then nextExpiry = expiry end
    end
    for _, entry in ipairs(notices) do result[#result + 1] = entry.row end
    return D.Rows(result, #result > 0, #result > 0)
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
        lastXPNotice, nextExpiry = nil, nil
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
    events = {"PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "CHAT_MSG_COMBAT_XP_GAIN",
        "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY"}})
