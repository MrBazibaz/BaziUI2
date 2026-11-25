local addon = BaziUI
local fonts = {}
addon.Typography = fonts

fonts.choices = {
    {"GameFontNormal", "WoW Default"}, {"FRIZQT", "Friz Quadrata"},
    {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"},
    {"ABC2002", "ABC 2002"}, {"ABC2002B", "ABC 2002 Bold"},
}

fonts.groups = {
    {"ActionBars", "Action Bars", {{"Labels", "Button labels"}, {"Experience", "Experience bar"}}},
    {"Chat", "Chat", {{"Messages", "Messages"}, {"Tabs", "Tabs"}}},
    {"Combat", "Damage Meter", {{"Header", "Header"}, {"Rows", "Rows"}}},
    {"Dashboard", "Dashboard", {{"Title", "Window title"}, {"Header", "Widget titles"}, {"Body", "Row labels"}, {"Value", "Values"}}},
    {"Dialogue", "Dialogue", {{"Header", "Headings"}, {"Body", "Quest text"}, {"Options", "NPC options"}}},
    {"Gathering", "Gathering"},
    {"HUD", "HUD", {{"Bar", "Cast and timer text"}, {"Aura", "Aura duration"}, {"Ammo", "Ammunition"}}},
    {"Inventory", "Inventory", {{"Header", "Window text"}, {"Items", "Item labels"}, {"Capacity", "Bag capacity"}, {"Cleanup", "Cleanup items"}}},
    {"Map", "Map", {{"Header", "Header"}, {"Coordinates", "Coordinates"}}},
    {"Minimap", "Minimap", {{"Zone", "Zone name"}, {"Clock", "Clock"}, {"Info", "Coordinates and stats"}}},
    {"Nameplates", "Nameplates", {{"Friendly", "Friendly players"}, {"NPC", "NPCs"}, {"Enemy", "Enemies"}}},
    {"Quest", "Quest Tracker", {{"Header", "Header"}, {"Zone", "Zone headers"}, {"Objectives", "Quests and objectives"}}},
    {"Tooltip", "Tooltip", {{"Title", "Titles"}, {"Body", "Body text"}}},
    {"UnitFrames", "Unit Frames", {{"Name", "Names"}, {"Health", "Health"}, {"Power", "Power"}, {"Level", "Levels"}}},
}

local files = {
    FRIZQT = "Fonts\\FRIZQT__.TTF", ARIAL = "Fonts\\ARIALN.TTF", MORPHEUS = "Fonts\\MORPHEUS.TTF",
    ABC2002 = "Fonts\\2002.TTF", ABC2002B = "Fonts\\2002B.TTF",
}
local savedShadow = setmetatable({}, {__mode = "k"})

function fonts.Path(key)
    local named = key and _G[key]
    return files[key] or (named and named.GetFont and named:GetFont()) or GameFontNormal:GetFont()
end

function fonts.Values(key)
    local profile = addon.db.profile
    profile.moduleFonts = profile.moduleFonts or {}
    profile.moduleFonts[key] = profile.moduleFonts[key] or {}
    return profile.moduleFonts[key]
end

function fonts.BaseSize()
    local bundled = addon.Database and addon.Database.bundledDefaults
    return bundled and bundled.fontSize or 14
end

local function resolve(key, field)
    local profile = addon.db and addon.db.profile
    local values = profile and profile.moduleFonts
    if not values then return end
    local part = values[key]
    local parent = values[key:match("^[^:]+")]
    if part and part[field] ~= nil then return part[field] end
    return parent and parent[field]
end

function fonts.GeneralChanged(field)
    local profile = addon.db.profile
    profile.globalTypography = profile.globalTypography or {}
    profile.globalTypography[field] = {}
end

function fonts.ModuleChanged(key, field, keepCentral)
    local profile = addon.db.profile
    local allowed = profile.globalTypography and profile.globalTypography[field]
    if allowed then allowed[key] = true end
    if not keepCentral then
        for scope, settings in pairs(profile.moduleFonts or {}) do
            if scope == key or scope:sub(1, #key + 1) == key .. ":" then settings[field] = nil end
        end
        fonts.Values(key)[field] = false
    end
end

function fonts.Resolve(key, file, size, outline, inherits)
    local profile = addon.db and addon.db.profile
    if not profile then return file, size, outline end
    local group = key:match("^[^:]+")
    local global = profile.globalTypography
    local function localWins(field)
        local allowed = global and global[field]
        return allowed and (allowed[group] or allowed[key])
    end
    local choice = resolve(key, "font")
    if choice == "general" then inherits = true end
    if choice and choice ~= "general" then
        file = fonts.Path(choice)
        inherits = false
    elseif inherits then
        file = fonts.Path(profile.font)
    end

    local selectedSize = resolve(key, "size")
    if selectedSize and selectedSize > 0 then size = selectedSize
    elseif choice == "general" and not localWins("size") then size = profile.fontSize or size
    elseif inherits and size and not localWins("size") then
        local base = fonts.BaseSize()
        size = math.max(1, size + (profile.fontSize or base) - base)
    end
    if global and global.font and not localWins("font") then file = fonts.Path(profile.font) end
    if global and global.size and not localWins("size") then size = profile.fontSize or size end
    local edge = resolve(key, "outline")
    if edge == "general" or edge == nil and inherits then edge = profile.generalFontOutline end
    local shadow = resolve(key, "shadow")
    if shadow == "general" or shadow == nil and inherits then shadow = profile.generalFontShadow end
    return file, size, edge == nil and outline or edge, shadow
end

function fonts.Shadow(region, choice)
    if not region.SetShadowOffset then return end
    if choice == "on" or choice == "off" then
        if not savedShadow[region] then
            local r, g, b, a = region:GetShadowColor()
            local x, y = region:GetShadowOffset()
            savedShadow[region] = {r, g, b, a, x, y}
        end
        region:SetShadowColor(0, 0, 0, choice == "on" and 0.85 or 0)
        region:SetShadowOffset(choice == "on" and 1 or 0, choice == "on" and -1 or 0)
    elseif savedShadow[region] then
        local r, g, b, a, x, y = unpack(savedShadow[region])
        region:SetShadowColor(r, g, b, a)
        region:SetShadowOffset(x, y)
        savedShadow[region] = nil
    end
end

function fonts.Apply(region, key, file, size, outline, inherits)
    local newFile, newSize, flags, shadow = fonts.Resolve(key, file, size, outline, inherits)
    if not newFile or not newSize then return end
    region:SetFont(newFile, newSize, flags)
    fonts.Shadow(region, shadow)
end

function fonts.Refresh(group)
    fonts.revision = (fonts.revision or 0) + 1
    local function refresh(key, fn)
        if (not group or group == key) and fn then fn() end
    end
    local chat = addon.Chat
    refresh("Chat", chat and chat.active and chat.Fonts.Refresh)
    refresh("Quest", addon.QuestTracker and addon.QuestTracker.Refresh)
    refresh("Combat", addon.DamageMeter and addon.DamageMeter.Refresh)
    refresh("Dashboard", addon.Dashboard and addon.Dashboard.Render)
    refresh("Dialogue", addon.Dialogue and addon.Dialogue.Refresh)
    refresh("HUD", function()
        if addon.CastBars then addon.CastBars.Refresh() end
        if addon.HUDAuras then addon.HUDAuras.Refresh() end
        if addon.HUDAmmo then addon.HUDAmmo.Refresh() end
    end)
    refresh("Inventory", addon.Inventory and addon.Inventory.UpdateWindows)
    refresh("Tooltip", addon.TooltipFonts and addon.TooltipFonts.Apply)
    refresh("Map", addon.Map and addon.Map.Refresh)
    refresh("Minimap", addon.MinimapInfo and function() addon.MinimapInfo:ApplyFonts() end)
    refresh("Nameplates", addon.Nameplates and function() addon.Nameplates:Apply() end)
    refresh("ActionBars", addon.ActionBars and function() addon.ActionBars:Apply() end)
    refresh("UnitFrames", function()
        for _, name in ipairs({"UnitFrames", "PartyFrames", "RaidFrames", "BossFrames", "GroupFrames"}) do
            local module = addon[name]
            if module and module.Refresh then module:Refresh() end
        end
    end)
end

