local addon = BaziUI
local data = addon.MapData
local map = {}
addon.Map = map

map.options = {
    {"reveal", "Show unexplored areas"},
    {"points", "Show points of interest"},
    {"levels", "Show zone levels"},
    {"coordinates", "Show coordinates"},
    {"hideTowns", "Hide town and city icons"},
    {"dungeons", "Show dungeon maps"},
    {"discovery", "Show discovery areas"},
    {"fishing", "Show fishing skill"},
    {"availableQuests", "Show available quests"},
}

local defaults = {
    enabled = true,
    reveal = true, points = true, levels = true, coordinates = true,
    hideTowns = false, dungeons = true, discovery = false, fishing = true, pointSize = 24,
}
map.pointOptions = {
    {"instances", "Show dungeons and raids"},
    {"flights", "Show flight points"},
    {"transport", "Show boats, zeppelins and trams"},
    {"portals", "Show portals"},
    {"crossings", "Show zone crossings"},
}
for _, option in ipairs(map.pointOptions) do defaults[option[1]] = true end
-- Rebuilt presentation layer. Blizzard owns map navigation, pins and layout.
local world, shell, title, coords
local function settings()
    local profile = addon.db.profile
    profile.worldMap = profile.worldMap or {}
    return profile.worldMap
end
function map.GetOption(key)
    local value = settings()[key]
    if value == nil then return defaults[key] end
    return value
end
function map.SetOption(key, value)
    settings()[key] = value
    if key ~= "enabled" then map.Refresh() end
end
local function canChange(frame)
    return not InCombatLockdown() or not frame:IsProtected()
end
function map.RefreshHeaderStyle()
    if not title then return end
    local chat = addon.Chat
    local r,g,b,a = 0.24,0.17,0.10,0.95
    if chat and chat.active and chat.Skin and chat.Skin.DockHeaderColor then
        r,g,b,a = chat.Skin.DockHeaderColor()
    end
    title:SetBackdropColor(r,g,b,a)
end
function map.Refresh()
    if not shell then return end
    coords:SetShown(map.GetOption("coordinates") == true)
    map.RefreshHeaderStyle()
end
local function install()
    if shell or not addon.db or not map.GetOption("enabled") then return end
    world = WorldMapFrame
    if not world or not world.ScrollContainer or not canChange(world) then return end
    -- Own decorative frames only. Never replace native scripts or reanchor native regions.
    shell = CreateFrame("Frame", nil, world, "BackdropTemplate")
    shell:SetAllPoints(world)
    shell:SetFrameLevel(world:GetFrameLevel())
    shell:EnableMouse(false)
    addon.Theme:CreateFrameBorder(shell, shell, shell)
    title = CreateFrame("Frame", nil, shell, "BackdropTemplate")
    title:SetPoint("TOPLEFT", world, "BOTTOMLEFT", 0, -2)
    title:SetPoint("TOPRIGHT", world, "BOTTOMRIGHT", 0, -2)
    title:SetHeight(22)
    title:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    title:EnableMouse(false)
    coords = title:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    coords:SetPoint("CENTER")
    local elapsed = 0
    shell:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.2 then return end
        elapsed = 0
        if not map.GetOption("coordinates") then return end
        local id = C_Map.GetBestMapForUnit("player")
        local pos = id and C_Map.GetPlayerMapPosition(id,"player")
        if pos then
            local x,y = pos:GetXY()
            coords:SetText(string.format("Player: %.1f, %.1f",x*100,y*100))
        else
            coords:SetText("Player: --")
        end
    end)
    map.Refresh()
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_,event,name)
    if event ~= "ADDON_LOADED" or name == "Blizzard_WorldMap" then install() end
end)
