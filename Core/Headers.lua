local addon = BaziUI
local headers = {}
addon.Headers = headers

local defaults, refreshers = {}, {}

local function values()
    local profile = addon.db and addon.db.profile
    return profile and profile.headers
end

function headers.Get(key, property)
    local settings = values()
    local entry = settings and settings[key]
    return entry and entry[property]
end

function headers.Set(key, property, value)
    local profile = addon.db.profile
    profile.headers = profile.headers or {}
    local entry = profile.headers[key] or {}
    entry[property] = value
    profile.headers[key] = next(entry) and entry or nil
end

function headers.RegisterRefresh(key, callback)
    refreshers[key] = callback
end

local function refreshInventory() addon.Inventory.UpdateWindows() end
local function refreshMeter() addon.DamageMeter.RefreshHeader() end
local function refreshChat()
    local chat = addon.Chat
    if not chat.active then return end
    chat.Refresh("backgroundOpacity")
    chat.Tabs.RefreshHeaderText()
end

local entries = {
    {"settings", "Bazi UI settings", {0.071, 0.055, 0.079, 1}},
    {"chat", "Chat", {0.20, 0.16, 0.10, 0.85}, refreshChat},
    {"quest", "Quest Tracker", {0.15, 0.15, 0.19, 0.85}, function() addon.QuestTracker.RefreshHeader() end},
    {"dialogue", "Dialogue", {0.15, 0.11, 0.15, 0.55}, function() addon.Dialogue.Refresh() end},
    {"meter", "Damage Meter", {0.15, 0.15, 0.19, 0.43}, refreshMeter},
    {"meter2", "Second Damage Meter", {0.15, 0.15, 0.19, 0.43}, refreshMeter},
    {"inventory", "Inventory", {0.24, 0.17, 0.10, 0.95}, refreshInventory},
    {"bank", "Bank", {0.24, 0.17, 0.10, 0.95}, refreshInventory},
    {"guildBank", "Guild Bank", {0.24, 0.17, 0.10, 0.95}, refreshInventory},
    {"cleanup", "Inventory Cleanup", {0.24, 0.17, 0.10, 0.95}, refreshInventory},
    {"rolls", "Loot Rolls", {0.24, 0.17, 0.10, 0.95}, refreshInventory},
    {"loot", "Loot", {0.24, 0.17, 0.10, 0.95}, refreshInventory},
    {"map", "World Map", {0.17, 0.114, 0.076, 1}, function() addon.Map.RefreshHeaderStyle() end},
    {"minimap", "Minimap", {0.17, 0.095, 0.045, 0.78}, function()
        addon.Minimap:RefreshHeaderStyle()
        addon.MinimapInfo:ApplyFonts()
    end},
    {"bugReport", "BugTab report", {0.071, 0.055, 0.079, 1}},
}
local byKey = {}
for _, entry in ipairs(entries) do byKey[entry[1]] = entry end
local inventoryKeys = {inventory = true, bank = true, guildBank = true, cleanup = true, rolls = true, loot = true}

function headers.Options(includeInactive)
    local available = {}
    for _, entry in ipairs(entries) do
        if includeInactive or entry[1] ~= "meter2" or addon.DamageMeter.HasSecondWindow() then
            available[#available + 1] = entry
        end
    end
    return available
end

function headers.Refresh(options)
    local called = {}
    for _, entry in ipairs(options) do
        local refresh = refreshers[entry[1]] or entry[4]
        if refresh and not called[refresh] then
            called[refresh] = true
            refresh()
        end
    end
end

function headers.Fill(key, r, g, b, alpha)
    local original = defaults[key]
    if not original then original = {}; defaults[key] = original end
    original[1], original[2], original[3], original[4] = r, g, b, alpha
    local color, opacity = headers.Get(key, "color"), headers.Get(key, "opacity")
    if color then r, g, b = unpack(color) end
    return r, g, b, opacity and opacity / 100 or alpha
end

function headers.Text(key, r, g, b)
    local color = headers.Get(key, "text")
    if color then return unpack(color) end
    return r, g, b
end

function headers.DisplayValue(key, property)
    local stored = headers.Get(key, property)
    if stored ~= nil then return stored end
    if property == "text" then
        if key == "meter" or key == "meter2" then
            return addon.DamageMeter.Settings(key == "meter2" and 2 or 1).headerTextColor
        end
        return addon.Theme.colors.headerText
    end
    local color = defaults[key]
    if not color and inventoryKeys[key] then color = {addon.Inventory.HeaderColor()} end
    if not color and key == "quest" then
        local db = addon.QuestTracker.Settings()
        if db.headerColor then color = {db.headerColor[1], db.headerColor[2], db.headerColor[3], db.opacity / 100} end
    end
    color = color or byKey[key][3]
    return property == "opacity" and math.floor(color[4] * 100 + 0.5) or color
end
