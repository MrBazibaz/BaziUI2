local addon = BaziUI
local bugs = {}
addon.BugTab = bugs
local BUGTAB_LINK = "addon:BaziUI:bugtab"
local TEST_ERROR = "[BugTab test]"
local testMessages = {
    "Missing quest data",
    "Invalid frame anchor",
    "Unexpected combat event",
    "Missing item icon",
    "Invalid profile value",
}
local testIndex = 0

local sounds = SOUNDKIT or {}
local gameSounds = {
    {8959, "Raid warning"},
    {sounds.TELL_MESSAGE or 3081, "Whisper"},
    {sounds.READY_CHECK or 8960, "Ready check"},
    {sounds.IG_MINIMAP_PING or 3175, "Map ping"},
}
local soundPath = "Interface\\AddOns\\BaziUI\\Assets\\Sounds\\"
bugs.revision = 0

local pending = {logs = {}}
local store = pending
local lastNotice = -math.huge
local forwarding = false
local grabber

function bugs.Settings()
    return store
end

function bugs.Clear()
    wipe(store.logs)
    bugs.revision = bugs.revision + 1
end

if EventRegistry then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link)
        if not (issecretvalue and issecretvalue(link)) and link == BUGTAB_LINK and addon.Options then
            addon.Options:OpenBugTab()
        end
    end, bugs)
end

function bugs.SoundChoices()
    local choices = {}
    for _, entry in ipairs(gameSounds) do choices[#choices + 1] = entry end
    local alerts = addon.Chat and addon.Chat.Alerts
    for _, sound in ipairs(alerts and alerts.SOUNDS or {}) do
        choices[#choices + 1] = {soundPath .. sound.file .. ".ogg", sound.label or sound.file}
    end
    return choices
end

function bugs.SelectedSound()
    local sound = store.sound
    if type(sound) == "string" and sound:find("Everchat\\Sounds\\", 1, true) then
        return soundPath .. "Urgent.ogg"
    end
    if type(sound) == "string" then
        local old = sound:match("([^\\/]+)%.ogg$")
        local alerts = addon.Chat and addon.Chat.Alerts
        if old and alerts then
            local mapped = alerts.ResolveSoundKey(old:lower())
            if mapped ~= old:lower() then
                for _, choice in ipairs(alerts.SOUNDS) do
                    if choice.key == mapped then return soundPath .. choice.file .. ".ogg" end
                end
            end
        end
    end
    return sound or gameSounds[1][1]
end

function bugs.PreviewSound()
    local sound = bugs.SelectedSound()
    if type(sound) == "string" then
        PlaySoundFile(sound)
    else
        PlaySound(sound)
    end
end

function bugs.TestError()
    testIndex = testIndex % #testMessages + 1
    error(TEST_ERROR .. " " .. testMessages[testIndex])
end

local function sourceOf(value)
    return value:gsub("\\", "/"):match("[Aa]dd[Oo]ns/([^/\n]+)")
end

local function capture(message, stack, eventSource, context)
    if type(message) ~= "string" or (issecretvalue and issecretvalue(message)) then return end
    if type(stack) ~= "string" or (issecretvalue and issecretvalue(stack)) then stack = "" end
    local source = eventSource or sourceOf(message) or sourceOf(stack) or "WoW / Unknown"
    local location = stack:match("[^\n]*[Aa]dd[Oo]ns[^\n]*") or ""
    local key = message .. "\n" .. location
    local logs = store.logs
    local entry
    for i, candidate in ipairs(logs) do
        if candidate.key == key then
            entry = table.remove(logs, i)
            break
        end
    end
    local isNew = not entry
    entry = entry or {key = key, source = source, message = message, count = 0}
    entry.count = entry.count + 1
    entry.time = context and context.time or time()
    entry.context = context
    entry.stack = stack
    table.insert(logs, 1, entry)
    if #logs > 100 then table.remove(logs) end
    bugs.revision = bugs.revision + 1
    local isTest = message:find(TEST_ERROR, 1, true)
    if store ~= pending and (isNew or isTest) and GetTime() - lastNotice >= 5 then
        lastNotice = GetTime()
        if store.chat ~= false and DEFAULT_CHAT_FRAME then
            local prefix = eventSource and "Blocked interface action attributed to "
                or isTest and "Test Lua error in " or "Lua error in "
            addon:Print(prefix
                .. source .. ". Click |cffffd36a|H" .. BUGTAB_LINK .. "|h[here]|h|r to view.")
        end
        if store.audio ~= false then bugs.PreviewSound() end
    end
    return true
end

local previous
local function onError(message)
    if forwarding then return end
    forwarding = true
    local ok, captured
    if not grabber then
        local stack = debugstack(2)
        ok, captured = pcall(capture, message, stack)
    end
    if previous and not (ok and captured) then
        pcall(previous, message)
    end
    forwarding = false
end

local function install()
    if not grabber and geterrorhandler() ~= onError then
        previous = geterrorhandler()
        seterrorhandler(onError)
    end
end

local function connectGrabber()
    local provider = _G.BugGrabber
    if grabber or type(provider) ~= "table" then return end
    local function receive(_, payload)
        if type(payload) == "string" and provider.GetErrorByID then
            local ok, result = pcall(provider.GetErrorByID, provider, payload)
            if not ok then return end
            payload = result
        end
        if type(payload) == "table" then pcall(capture, payload.message, payload.stack) end
    end
    if provider.GetErrorByID and EventRegistry then
        EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", receive, bugs)
    elseif provider.RegisterCallback then
        provider.RegisterCallback(bugs, "BugGrabber_BugGrabbed", receive)
    else
        return
    end
    grabber = provider
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(_, event, name, action)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if issecretvalue and (issecretvalue(name) or issecretvalue(action)) then return end
        local source = type(name) == "string" and name ~= "" and name or "WoW / Unknown"
        local operation = type(action) == "string" and action ~= "" and action or "Unknown action"
        -- Capture the event context before leaving the blocked call's stack.
        local stack = debugstack(2)
        local character = UnitName("player")
        local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addon.name, "Version")
        local context = {time = time(), combat = InCombatLockdown() and true or false,
            character = type(character) == "string" and not (issecretvalue and issecretvalue(character)) and character or "Unknown",
            version = type(version) == "string" and version or "Unknown"}
        C_Timer.After(0, function()
            capture(event .. ": " .. operation .. " (" .. source .. ")", stack, source, context)
        end)
        return
    end
    if event == "ADDON_LOADED" and name == addon.name then
        BaziUIBugLog = type(BaziUIBugLog) == "table" and BaziUIBugLog or {}
        BaziUIBugLog.logs = type(BaziUIBugLog.logs) == "table" and BaziUIBugLog.logs or {}
        for i = #pending.logs, 1, -1 do
            local entry = pending.logs[i]
            for j, old in ipairs(BaziUIBugLog.logs) do
                if old.key == entry.key then
                    entry.count = entry.count + old.count
                    table.remove(BaziUIBugLog.logs, j)
                    break
                end
            end
            table.insert(BaziUIBugLog.logs, 1, entry)
        end
        for i = #BaziUIBugLog.logs, 101, -1 do BaziUIBugLog.logs[i] = nil end
        store = BaziUIBugLog
    end
    connectGrabber()
    if event == "PLAYER_LOGIN" then install() end
end)
connectGrabber()
install()

function bugs.Report(entry)
    local context = entry.context
    local details = context and ("\nCharacter: %s\nCombat: %s\nVersion: %s"):format(
        context.character or "Unknown", context.combat and "Yes" or "No", context.version or "Unknown") or ""
    return ("Addon: %s\nMessage: %s\nTime: %s\nCount: %d%s\nStack:\n%s"):format(
        entry.source, entry.message, date("%Y-%m-%d %H:%M:%S", entry.time), entry.count, details, entry.stack)
end
