local G = {}
BaziUI.Gathering = G

local callbacks = {}
local ns = { state = {}, L = {
    MATCH_LOOT = "Loot: %s", MATCH_NAME = "Name: %s", MATCH_TOOLTIP = "Tooltip: %s",
    MATCH_WORD = "Word: %s", VIA_DIRECT = "Direct", VIA_SWEEP = "Nameplate",
} }
G.vendor = ns

function ns.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function ns.SafeCall(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if ok and not ns.IsSecret(value) then return value end
end

function ns.OnSettings(callback)
    callbacks[#callbacks + 1] = callback
end

G.professionSpells = {ore = 2575, herb = 2366, skin = 8613}
G.professionPreviewColor = {r = 0.25, g = 0.85, b = 0.25}

G.categories = {
    {"ore", "Ore", "Copper Vein", 1, 0.57, 0.23},
    {"herb", "Herbs", "Peacebloom", 0.42, 0.91, 0.48},
    {"skin", "Skinning", "Skinnable", 0.95, 0.63, 0.38},
    {"quest", "Quests", "Quest object", 1, 0.81, 0.24},
    {"chest", "Chests", "Treasure Chest", 0.40, 0.77, 1},
    {"other", "Other", "World object", 0.85, 0.84, 0.90},
    {"bobber", "Bobber effect", "Fishing Bobber", 0.44, 0.77, 1},
}

function G:Settings()
    local profile = BaziUI.db.profile
    local db = profile.gathering
    if not db then
        db = { enabled = false, categories = {}, containers = {}, questObjects = {} }
        profile.gathering = db
    end
    if self.activeProfile ~= db then
        self.activeProfile = db
        for _, callback in ipairs(callbacks) do callback(db) end
    end
    for _, def in ipairs(self.categories) do
        local key = def[1]
        if not db.categories[key] then
            db.categories[key] = {
                enabled = key ~= "other", effect = "beam", size = 120, intensity = 100,
                y = -24, r = def[4], g = def[5], b = def[6],
            }
        end
        local look = db.categories[key]
        if look.showName == nil then look.showName = true end
        look.nameSize = look.nameSize or 14
        look.nameX = look.nameX or 0
        look.nameY = look.nameY or -16
    end
    if not db.fishing then
        db.fishing = {
            enabled = false, autoLoot = false, quietNames = false, focusAudio = false,
            volume = 100, hideBobberIcon = false,
        }
    end
    return db
end
