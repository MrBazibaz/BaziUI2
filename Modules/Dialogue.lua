local addon = BaziUI
local dialogue = {}
addon.Dialogue = dialogue

function dialogue.Settings()
    local profile = addon.db.profile
    profile.dialogue = profile.dialogue or {}
    local cfg = profile.dialogue
    if cfg.opacity == nil then cfg.opacity = 80 end
    if cfg.scale == nil then cfg.scale = 100 end
    if cfg.optionFontSize == nil then cfg.optionFontSize = 14 end
    if cfg.tint == nil then cfg.tint = true end
    if cfg.x == nil then cfg.x = -350 end
    if cfg.y == nil then cfg.y = 15 end
    if cfg.readerX == nil then cfg.readerX = 0 end
    if cfg.readerY == nil then cfg.readerY = -100 end
    if cfg.readerMaxHeight == nil then cfg.readerMaxHeight = 240 end
    return cfg
end

function dialogue.IsForeverQuest(id)
    if (issecretvalue and issecretvalue(id)) or type(id) ~= "number" or id <= 0 then return false end
    local ranges = addon.VanillaQuestRanges
    local low, high = 1, #ranges
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if id < ranges[mid][1] then high = mid - 1
        elseif id > ranges[mid][2] then low = mid + 1
        else return false end
    end
    return true
end

