local addon, D = BaziUI, BaziUI.Dashboard
local inventory = addon.Inventory
local Stats = {}
addon.ActivityStats = Stats
local character, session, clock, money, level, xp, cap, instance
local skillRanks, chain, lastKill = {}, 0, nil
local leaving, inWorld
local window
local reconnectWindow = 15 * 60
local function now() return time() end
local function day(at) return date("%Y-%m-%d", at) end

local function daily(at)
    local key = day(at)
    character.days[key] = character.days[key] or {}
    return character.days[key]
end

local function record(key, value, maximum)
    if not session or not value or value <= 0 then return end
    for _, totals in ipairs({session.totals, daily(now())}) do
        totals[key] = maximum and math.max(totals[key] or 0, value) or (totals[key] or 0) + value
    end
end

local function checkpoint()
    if not session or not inWorld then return end
    local at = now()
    local seconds = math.max(0, math.min(20, at - clock))
    session.lastSeen = at
    session.totals.time = (session.totals.time or 0) + seconds
    -- A heartbeat can span local midnight, so assign each part to its actual day.
    for second = at - seconds, at - 1 do
        local totals = daily(second)
        totals.time = (totals.time or 0) + 1
    end
    clock = at
end

local function sampleXP()
    local currentLevel, currentXP, currentCap = D.Call(UnitLevel, "player"),
        D.Call(UnitXP, "player"), D.Call(UnitXPMax, "player")
    if type(currentLevel) ~= "number" or type(currentXP) ~= "number" then return end
    if currentLevel == level then record("xp", currentXP - xp)
    elseif level and currentLevel == level + 1 then record("xp", (cap or xp) - xp + currentXP) end
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
    session = character.session
    if not session or session.closed or at - (session.lastSeen or 0) > reconnectWindow then
        session = {totals = {}, lastSeen = at}
        character.session = session
    end
    clock, money, instance = at, D.Call(GetMoney), session.instance
    sampleXP()
    sampleSkills(true)
end

local function isGrouped()
    return IsInGroup and (IsInGroup() or LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE))
end

local function fmtTime(seconds)
    return ("%dh %02dm %02ds"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function fmtNet(copper)
    return (copper < 0 and "−" or "+") .. inventory.Money(math.abs(copper))
end

local rows = {
    {"Items looted", "looted"}, {"Materials gathered", "materials"},
    {"Gold earned", "earned", inventory.Money}, {"Gold spent", "spent", inventory.Money},
    {"Net gold", "net", fmtNet}, {"Enemies killed", "kills"}, {"Deaths", "deaths"},
    {"Highest solo killstreak", "streak"}, {"Experience gained", "xp"}, {"Quests completed", "quest"},
    {"Profession skill gains", "profession"}, {"Combat skill gains", "skill"},
    {"Dungeon runs", "dungeons"}, {"Bosses defeated", "bosses"}, {"Playtime", "time", fmtTime},
}

function Stats.Get(scope)
    if not session then return {} end
    checkpoint()
    return scope == "today" and daily(now()) or session.totals
end

local function refreshWindow()
    if not window or not window:IsShown() then return end
    local totals = Stats.Get(window.scope)
    for i, spec in ipairs(rows) do
        local value = spec[2] == "net" and (totals.earned or 0) - (totals.spent or 0) or totals[spec[2]] or 0
        window.values[i]:SetText(spec[3] and spec[3](value) or tostring(value))
    end
end

function Stats.ResetSession()
    if not session then return end
    checkpoint()
    session.totals = {}
    chain, lastKill = 0, nil
    refreshWindow()
end

function Stats.Open(scope)
    if not window then
        window = CreateFrame("Frame", "BaziUIActivityStatistics", UIParent)
        window:SetSize(318, 376)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:EnableMouse(true)
        window:SetMovable(true)
        window:SetClampedToScreen(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        local background = addon.Theme:RoundedCard(window)
        background:SetAllPoints()
        addon.Theme:PaintQuestCard(background, 1, true)
        window.title = inventory.Label(window, "GameFontNormalLarge")
        window.title:SetPoint("TOPLEFT", 12, -11)
        local close = inventory.Button(window, "×", 27, function() window:Hide() end)
        close:SetPoint("TOPRIGHT", -6, -6)
        window.values = {}
        for i, spec in ipairs(rows) do
            local row = CreateFrame("Frame", nil, window)
            row:SetPoint("TOPLEFT", 10, -40 - (i - 1) * 22)
            row:SetPoint("TOPRIGHT", -10, -40 - (i - 1) * 22)
            row:SetHeight(20)
            if i % 2 == 1 then
                local card = addon.Theme:RoundedCard(row)
                card:SetAllPoints()
                addon.Theme:PaintQuestCard(card)
            end
            local label, value = inventory.Label(row), inventory.Label(row)
            label:SetPoint("LEFT", 6, 0)
            label:SetText(spec[1])
            value:SetPoint("RIGHT", -6, 0)
            window.values[i] = value
        end
    end
    window.scope = scope
    window.title:SetText(scope == "today" and "Today · " .. day(now()) or "Current session")
    window:Show()
    window:Raise()
    refreshWindow()
end

function Stats.ShowExit(popup)
    if not popup.baziSessionSummary then
        local card = CreateFrame("Frame", nil, popup)
        card:SetPoint("TOP", popup, "BOTTOM", 0, -4)
        card:SetSize(300, 69)
        local background = addon.Theme:RoundedCard(card)
        background:SetAllPoints()
        addon.Theme:PaintQuestCard(background, 1, true)
        local title = inventory.Label(card, "GameFontNormal")
        title:SetPoint("TOP", 0, -8)
        title:SetText("Session summary")
        card.label = inventory.Label(card)
        card.label:SetPoint("TOP", title, "BOTTOM", 0, -5)
        card.label:SetJustifyH("CENTER")
        popup.baziSessionSummary = card
        popup:HookScript("OnHide", function() card:Hide() end)
    end
    leaving = true
    local exitText = popup.baziSessionSummary.label
    local totals = Stats.Get("session")
    exitText:SetText(("%s  ·  %d XP  ·  %d kills\n%d quests  ·  %s"):format(fmtTime(totals.time or 0),
        totals.xp or 0, totals.kills or 0, totals.quest or 0, fmtNet((totals.earned or 0) - (totals.spent or 0))))
    popup.baziSessionSummary:Show()
end

SLASH_BAZIACTIVITYTODAY1 = "/today"
SLASH_BAZIACTIVITYSESSION1 = "/session"
SlashCmdList.BAZIACTIVITYTODAY = function() Stats.Open("today") end
SlashCmdList.BAZIACTIVITYSESSION = function() Stats.Open("session") end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "PLAYER_MONEY",
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "QUEST_TURNED_IN", "CHAT_MSG_LOOT",
    "CHAT_MSG_COMBAT_XP_GAIN", "SKILL_LINES_CHANGED", "ENCOUNTER_END", "GROUP_ROSTER_UPDATE"}) do
    pcall(events.RegisterEvent, events, event)
end
if Logout then hooksecurefunc("Logout", function() leaving = true end) end
if Quit then hooksecurefunc("Quit", function() leaving = true end) end
if ReloadUI then hooksecurefunc("ReloadUI", function() leaving = false end) end
if CancelLogout then hooksecurefunc("CancelLogout", function() leaving = false end) end
C_Timer.NewTicker(10, function() checkpoint(); refreshWindow() end)
events:SetScript("OnEvent", function(_, event, first, _, _, _, success)
    if event == "PLAYER_ENTERING_WORLD" then
        if not session and addon.db then openSession() end
        if session then clock, inWorld = now(), true; sampleInstance() end
    elseif not session then return
    elseif event == "PLAYER_LEAVING_WORLD" then checkpoint(); inWorld = false
    elseif event == "PLAYER_LOGOUT" then checkpoint(); session.closed = leaving or nil
    elseif event == "PLAYER_MONEY" then
        local total = D.Call(GetMoney)
        if type(total) == "number" and type(money) == "number" then
            local change = total - money
            record(change > 0 and "earned" or "spent", math.abs(change))
        end
        money = total
    elseif event == "PLAYER_XP_UPDATE" and (not first or first == "player") or event == "PLAYER_LEVEL_UP" then
        sampleXP()
    elseif event == "PLAYER_DEAD" then record("deaths", 1); chain, lastKill = 0, nil
    elseif event == "GROUP_ROSTER_UPDATE" then
        if isGrouped() then chain, lastKill = 0, nil end
    elseif event == "QUEST_TURNED_IN" then record("quest", 1)
    elseif event == "CHAT_MSG_LOOT" then
        local id, count = D.ReadSelfLoot(first)
        if id then
            record("looted", count)
            local _, _, _, _, class = D.Item(id)
            local kind, skin
            if addon.Gathering and addon.Gathering.DashboardContext then kind, skin = addon.Gathering.DashboardContext() end
            if class == 7 or class == 5 or skin or kind == "ore" or kind == "herb" then record("materials", count) end
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
    elseif event == "ENCOUNTER_END" and D.Read(success) and success == 1 then record("bosses", 1)
    end
    refreshWindow()
end)
