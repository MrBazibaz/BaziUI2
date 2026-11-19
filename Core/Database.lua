local addon = BaziUI

addon.Database = addon.Database or {}

local defaults = {
    profile = {
        uiScale = 1.0,
        fontSize = 14,
        font = "GameFontNormal",
        qol = { characterItemLevel = false, muteErrorSpeech = false, muteFailedSpellSounds = false },
        minimap = {
            enabled = false, style = "round", autoZoom = 0,
            ignoreIndoorZoom = false,
            iconScale = 1.5, mapScale = 1.0,
            microMenu = false, finderEye = false, showMinimapButton = true,
            coords = "off", fps = "off", latency = "off", clock = "always",
            hideAddonButtons = false, hideCalendar = false,
            hideTracking = false, hideZone = false, hideClock = false,
            hideCoordinates = false, hideSearch = false,
            zoneFont = {font = "GLOBAL", outline = "NONE", size = 12, shadow = true},
            clockFont = {font = "GLOBAL", outline = "NONE", size = 12, shadow = true},
            infoFont = {font = "GLOBAL", outline = "NONE", size = 11, shadow = true},
        },
        tooltip = {
            enabled = true, anchor = "corner", x = -30, y = 130,
            scale = 1, opacity = 1, healthBar = "below",
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

function addon.Database:Initialize()
    BaziUIDB = BaziUIDB or {}
    BaziUIDB = CopyDefaults(defaults, BaziUIDB)
    addon.db = BaziUIDB
end
