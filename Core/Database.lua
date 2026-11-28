local addon = BaziUI

addon.Database = addon.Database or {}

local defaults = {
    profile = {
        uiScale = 1.0,
        fontSize = 14,
        font = "GameFontNormal",
        qol = {
            characterItemLevel = false, muteErrorSpeech = false, muteFailedSpellSounds = false,
            hideCombatErrors = false, restoreGatheringTracking = false, resizeWindows = {},
            autoQuest = false, acceptSharedQuests = false, acceptSummon = false,
            acceptResurrection = false, releasePvP = false, sellJunk = true, repair = false,
            trainAll = true, easyDestroy = true,
        },
        minimap = {
            enabled = false, style = "round", autoZoom = 0,
            ignoreIndoorZoom = false,
            iconScale = 1.5, mapScale = 1.0,
            microMenu = true, finderEye = false, showMinimapButton = true,
            coords = "off", fps = "off", latency = "off", clock = "always",
            hideAddonButtons = false, hideCalendar = false,
            hideTracking = false, hideZone = false, hideClock = false,
            hideCoordinates = false, hideSearch = false,
            zoneFont = {font = "GLOBAL", outline = "NONE", size = 12, shadow = true},
            clockFont = {font = "GLOBAL", outline = "NONE", size = 12, shadow = true},
            infoFont = {font = "GLOBAL", outline = "NONE", size = 11, shadow = true},
        },
        unitframes = {enabled=true, player=false, target=false, focus=false, pet=false, targettarget=false, hideBlizzard=false, scale=1, barWidth=162, hpHeight=23, powerHeight=9, portraitSize=48, portraitX=0, portraitY=0, frames={player={}, target={}, focus={}, pet={}, targettarget={}}, groups={party={enabled=false,showSolo=false},raid={enabled=false,showSolo=false}}},
        tooltip = {
            enabled = true, anchor = "corner", x = -30, y = 130,
            scale = 1, opacity = 1, healthBar = "insideBottom", smart = true,
            guild = true, threat = true, ids = false, itemLevel = true,
            classNames = true, targetTarget = true, hideFaction = false,
            titleFont = {font = "GLOBAL", outline = "OUTLINE", size = 14, shadow = true},
            textFont = {font = "GLOBAL", outline = "NONE", size = 12, shadow = true},
        },
    },
}

local function CopyDefaults(source, target)
    if type(source) ~= "table" then
        return target
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local database = addon.Database
local initialProfile = "Default"
local activeCharacter

function database:CharacterKey()
    local ok, guid = pcall(UnitGUID, "player")
    if ok and (not issecretvalue or not issecretvalue(guid)) and type(guid) == "string" and guid ~= "" then
        return guid
    end
end

function database:ListProfiles()
    local names = {}
    for name in pairs(BaziUIDB.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function database:ActiveProfile()
    local profile = activeCharacter and BaziUIDB.personalProfiles[activeCharacter]
    return profile and profile.name or "Character"
end
function database:DefaultProfile() return BaziUIDB.defaultProfile end

function database:PendingSetup()
    local current = activeCharacter and BaziUIDB.personalProfiles[activeCharacter]
    return current and current.setupPending
end

function database:FinishSetup(preset, modules)
    local current = activeCharacter and BaziUIDB.personalProfiles[activeCharacter]
    if not current or not current.setupPending then return end
    if not preset then current.setupPending = nil; return end
    if InCombatLockdown() then return false end
    local source = BaziUIDB.profiles[preset] or BaziUIDB.profiles[BaziUIDB.defaultProfile]
    local settings = CopyDefaults(source or current.settings, {})
    settings.chat = settings.chat or {}
    settings.chat.hideCombatLogTab = true
    settings.chat.applyProfileTabs = settings.chat.profileTabs ~= nil or nil
    for key, enabled in pairs(modules or {}) do
        if key == "cleanup" or key == "rolls" then
            settings.inventory = settings.inventory or {}
            settings.inventory[key] = enabled
        else
            settings[key] = settings[key] or {}
            settings[key].enabled = enabled
        end
    end
    current.settings, current.setupPreset, current.setupPending = settings, preset, nil
    ReloadUI()
    return true
end

function database:CopySources()
    local choices = {}
    for _, name in ipairs(self:ListProfiles()) do
        choices[#choices + 1] = {"template:" .. name, name}
    end
    local characters = {}
    for key, profile in pairs(BaziUIDB.personalProfiles) do
        if key ~= activeCharacter then
            characters[#characters + 1] = {"character:" .. key,
                profile.name .. (profile.realm and (" · " .. profile.realm) or " (character)")}
        end
    end
    table.sort(characters, function(a, b) return a[2] < b[2] end)
    for _, entry in ipairs(characters) do choices[#choices + 1] = entry end
    return choices
end

function database:SetDefaultProfile(name)
    if not BaziUIDB.profiles[name] then return false end
    BaziUIDB.defaultProfile = name
    return true
end

function database:DeleteProfile(name)
    if name == initialProfile or not BaziUIDB.profiles[name] then return false end
    BaziUIDB.profiles[name] = nil
    if BaziUIDB.defaultProfile == name then BaziUIDB.defaultProfile = initialProfile end
    return true
end

local privateChatFields = {
    "history", "whisperHistory", "chatLayouts", "tabSetups", "tabOrder",
    "fontSized", "alerts", "tabSounds", "tabSoundChoices",
    "applyProfileTabs",
}

local function WriteLua(value, depth, lines, prefix)
    local kind = type(value)
    if kind == "string" then
        lines[#lines + 1] = prefix .. string.format("%q", value) .. ","
    elseif kind == "boolean" or kind == "number" and value == value and math.abs(value) < math.huge then
        lines[#lines + 1] = prefix .. tostring(value) .. ","
    elseif kind == "table" then
        local keys = {}
        for key in pairs(value) do
            if type(key) == "string" or type(key) == "number" then keys[#keys + 1] = key end
        end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        lines[#lines + 1] = prefix .. "{"
        local indent = string.rep("    ", depth + 1)
        for _, key in ipairs(keys) do
            local serializedKey = type(key) == "string" and string.format("%q", key) or tostring(key)
            WriteLua(value[key], depth + 1, lines, indent .. "[" .. serializedKey .. "] = ")
        end
        lines[#lines + 1] = string.rep("    ", depth) .. "},"
    end
end

function database:ExportDefaults(name)
    local profile = BaziUIDB.profiles[name]
    if not profile then return end
    local settings = CopyDefaults(profile, {})
    if settings.questTracker and addon.QuestTracker then
        settings.questTracker.position = addon.QuestTracker.PortablePosition(settings.questTracker)
    end
    if settings.chat then
        for _, key in ipairs(privateChatFields) do settings.chat[key] = nil end
    end
    local lines = {}
    WriteLua(settings, 0, lines, "BaziUI.Database.bundledDefaults = ")
    lines[#lines] = "}"
    return table.concat(lines, "\n") .. "\n"
end

function database:CreateProfile(name, copyCurrent)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" or (strlenutf8 or string.len)(name) > 48 or name:find("[%c|]") then
        return nil, "Enter a profile name up to 48 characters."
    end
    for existing in pairs(BaziUIDB.profiles) do
        if existing:lower() == name:lower() then return nil, "A profile with that name already exists." end
    end
    if copyCurrent and addon.Chat and addon.Chat.active then addon.Chat.TabCopy.Snapshot() end
    BaziUIDB.profiles[name] = CopyDefaults(copyCurrent and addon.db.profile or defaults.profile, {})
    return name
end

function database:CopyProfile(source)
    local target = activeCharacter and BaziUIDB.personalProfiles[activeCharacter]
    if not target then return false, "Character information is still loading." end
    if InCombatLockdown() then return false, "Copy profiles after combat." end
    local kind, key
    if type(source) == "string" then kind, key = source:match("^([^:]+):(.+)$") end
    local sourceCharacter = kind == "character" and key ~= activeCharacter and BaziUIDB.personalProfiles[key]
    local settings = kind == "template" and BaziUIDB.profiles[key] or sourceCharacter and sourceCharacter.settings
    if not settings then return false, "Select a saved template or another character." end
    -- The live profile keeps its references until the reload writes the copy.
    target.settings = CopyDefaults(settings, {})
    local chat = target.settings.chat
    if chat then
        -- Everchat stores layout and window preferences by full name and realm,
        -- independently of the GUID-keyed personal profile.
        local destination = target.name and target.realm and (target.name .. "-" .. target.realm)
        local origin = sourceCharacter and sourceCharacter.name and sourceCharacter.realm
            and (sourceCharacter.name .. "-" .. sourceCharacter.realm)
        if origin and destination then
            for _, field in ipairs({"chatLayouts", "tabSetups", "tabOrder", "fontSized",
                "fontRaised", "alerts", "tabSounds", "tabSoundChoices"}) do
                local store = chat[field]
                if type(store) == "table" then
                    local value = store[origin]
                    store[destination] = type(value) == "table" and CopyDefaults(value, {}) or value
                end
            end
            local setup = chat.tabSetups and chat.tabSetups[origin]
            if setup then chat.profileTabs = CopyDefaults(setup, {}) end
        end
        -- History is account-managed separately; never import legacy history.
        chat.history, chat.whisperHistory = nil, nil
        chat.applyProfileTabs = chat.profileTabs ~= nil or nil
        chat.hideCombatLogTab = true
    end
    ReloadUI()
    return true
end

local function MoveChatHistory(saved, profile)
    if not profile.chat then return end
    for _, field in ipairs({"history", "whisperHistory"}) do
        local oldHistory = profile.chat[field]
        if type(oldHistory) == "table" then
            local history = saved.chatHistory[field] or {}
            for key, messages in pairs(oldHistory) do
                if history[key] == nil then history[key] = messages end
            end
            saved.chatHistory[field] = history
            profile.chat[field] = nil
        end
    end
end

local function MigrateSharedDefault(saved, character)
    if saved.characterProfiles then return end
    local hadNamedProfiles = next(saved.profiles) ~= nil
    local previous = saved.profiles[initialProfile] or saved.profile
    if type(previous) == "table" and next(previous) then
        local name, suffix = "Previous settings", 1
        while saved.profiles[name] do
            suffix = suffix + 1
            name = "Previous settings " .. suffix
        end
        MoveChatHistory(saved, previous)
        saved.profiles[name] = previous
        -- Pre-profile saves belonged to the character migrating them.
        -- Existing Default assignments are ambiguous and start fresh instead.
        if character and not hadNamedProfiles then saved.profileKeys[character] = name end
    end
    saved.profiles[initialProfile] = CopyDefaults(database.bundledDefaults or {}, {})
    saved.characterProfiles = {}
end

function database:Initialize()
    local saved = type(BaziUIDB) == "table" and BaziUIDB or {}
    BaziUIDB = saved
    saved.profiles = saved.profiles or {}
    saved.profileKeys = saved.profileKeys or {}
    saved.chatHistory = saved.chatHistory or {}
    saved.personalProfiles = saved.personalProfiles or {}
    local character = self:CharacterKey()
    activeCharacter = character
    MigrateSharedDefault(saved, character)
    if not saved.profiles[initialProfile] then
        saved.profiles[initialProfile] = CopyDefaults(self.bundledDefaults or {}, {})
    end
    saved.profile = nil
    if not saved.profiles[saved.defaultProfile] then
        saved.defaultProfile = initialProfile
    end
    local personal = character and saved.personalProfiles[character]
    if not personal then
        local formerName = character and saved.profileKeys[character]
        local formerCopies = character and saved.characterProfiles[character]
        local source = formerCopies and formerCopies[formerName] or saved.profiles[formerName]
            or saved.profiles[saved.defaultProfile]
        MoveChatHistory(saved, source)
        personal = {settings = CopyDefaults(source, {}), setupPending = not formerName and true or nil}
        if personal.settings.chat and personal.settings.chat.profileTabs then personal.settings.chat.applyProfileTabs = true end
        if character then saved.personalProfiles[character] = personal end
    end
    local function readable(text)
        return (not issecretvalue or not issecretvalue(text)) and type(text) == "string" and text ~= ""
    end
    local ok, first, surname = pcall(UnitNameUnmodified or UnitName, "player")
    if ok and readable(first) then
        personal.name = readable(surname) and (first .. " " .. surname) or first
    end
    personal.name = personal.name or "Character"
    local realmOK, realm = pcall(GetRealmName)
    if realmOK and readable(realm) then personal.realm = realm end
    personal.settings = CopyDefaults(defaults.profile, personal.settings)
    MoveChatHistory(saved, personal.settings)
    addon.db = setmetatable({profile = personal.settings}, {__index = saved, __newindex = saved})
end
