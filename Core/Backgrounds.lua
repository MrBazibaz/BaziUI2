local addon = BaziUI
local backgrounds = {}
addon.Backgrounds = backgrounds

local layers = {}

function backgrounds.Get(key)
    local profile = addon.db and addon.db.profile
    local values = profile and profile.backgrounds
    return values and values[key]
end

function backgrounds.Track(key, texture, original)
    layers[key] = layers[key] or setmetatable({}, {__mode = "k"})
    layers[key][texture] = original or 1
    local value = backgrounds.Get(key)
    if value ~= nil then texture:SetAlpha(value / 100) end
end

function backgrounds.Set(key, value)
    local profile = addon.db.profile
    profile.backgrounds = profile.backgrounds or {}
    profile.backgrounds[key] = value
    for texture, original in pairs(layers[key] or {}) do
        texture:SetAlpha(value and value / 100 or original)
    end
end

function backgrounds.Options()
    local profile = addon.db.profile
    local quest, inventory, meter = addon.QuestTracker, addon.Inventory, addon.DamageMeter
    local bars, chat = addon.ActionBars, addon.Chat
    local options = {}
    local function row(label, read, write)
        options[#options + 1] = {label, read, write}
    end
    local function field(label, db, key, fallback, apply, factor)
        factor = factor or 1
        row(label, function()
            if db[key] ~= nil then return db[key] * factor end
            return type(fallback) == "function" and fallback() or fallback
        end,
            function(value)
                db[key] = value / factor
                return apply
            end)
    end
    local function layer(label, key, fallback)
        row(label, function() return backgrounds.Get(key) or fallback end, function(value)
            backgrounds.Set(key, value)
        end)
    end

    layer("Bazi UI settings", "settings", 100)
    field("Chat", chat.Settings(), "backgroundOpacity", 25, function() chat.Refresh("backgroundOpacity") end)
    field("Quest Tracker", quest.Settings(), "backgroundOpacity", 85, quest.Refresh)
    layer("Action bars", "actionBars", 48)
    field("Experience and reputation bars", bars:Settings().experience, "opacity", 100,
        function() bars:ApplyExperience(bars:Settings().experience) end)
    field("Damage Meter", meter.Settings(), "opacity", 70, meter.Refresh)
    if meter.Settings().second then field("Second Damage Meter", meter.Settings(2), "opacity", 70, meter.Refresh) end
    for _, entry in ipairs({{"player", "Player Cast Bar"}, {"target", "Target Cast Bar"},
        {"breath", "Breath Bar"}, {"fatigue", "Fatigue Bar"}}) do
        field(entry[2], addon.HUD.Settings(entry[1]), "opacity", 65, addon.CastBars.Refresh)
    end
    field("Dialogue", addon.Dialogue.Settings(), "opacity", 80, addon.Dialogue.Refresh)
    local bags = inventory.Settings()
    field("Inventory", bags, "opacity", 85, inventory.UpdateWindows)
    local function bagOpacity() return bags.opacity end
    field("Bank", bags, "bankOpacity", bagOpacity, inventory.UpdateWindows)
    field("Guild Bank", bags, "guildBankOpacity", bagOpacity, inventory.UpdateWindows)
    field("Inventory Cleanup", bags, "cleanupOpacity", 85, inventory.UpdateWindows)
    field("Loot Rolls", bags, "rollOpacity", 85, inventory.UpdateWindows)
    field("Loot", bags, "lootOpacity", 85, inventory.UpdateWindows)
    layer("World Map", "map", 100)
    layer("Minimap header", "minimap", 78)
    row("Minimap menu", function() return backgrounds.Get("minimapMenu") or 97 end, function(value)
        backgrounds.Set("minimapMenu", value)
        return addon.MinimapButtons and addon.MinimapButtons.RefreshBackground
    end)
    layer("Unit Frames", "unitFrames", 100)
    layer("Party Frames", "partyFrames", 100)
    layer("Raid Frames", "raidFrames", 100)
    layer("Boss Frames", "bossFrames", 100)
    layer("Enemy Nameplates", "nameplates", 95)
    field("Tooltip", profile.tooltip, "opacity", 100, function() addon.Tooltip:Apply() end, 100)
    layer("BugTab report", "bugReport", 100)
    return options
end
