local addon = BaziUI

addon.Database = addon.Database or {}

local defaults = {
    profile = {
        uiScale = 1.0,
        fontSize = 14,
        font = "GameFontNormal",
        tooltip = {
            enabled = true, anchor = "corner", x = -30, y = 130,
            scale = 1, opacity = 1, healthBar = "below",
            guild = true, threat = true, ids = false, itemLevel = true,
            classNames = true, targetTarget = true, hideFaction = false,
            titleFont = {font = "FRIZQT", outline = "OUTLINE", size = 14, shadow = true},
            textFont = {font = "FRIZQT", outline = "NONE", size = 12, shadow = true},
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
