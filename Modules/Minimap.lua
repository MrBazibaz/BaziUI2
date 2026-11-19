-- Bazi UI Minimap foundation.
-- Adapted from FlareUI Modules/Minimap.lua: native round map,
-- square mask and delayed auto zoom. No FlareUI artwork or dependencies.
local addon = BaziUI
addon.Minimap = addon.Minimap or {}
local MM = addon.Minimap
local map = _G.Minimap
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local timer, square
local function db()
    return addon.db and addon.db.profile and addon.db.profile.minimap
end
local function safe(v)
    return not issecretvalue or not issecretvalue(v)
end
local function setSquare()
    if not map or not map.SetMaskTexture then return end
    map:SetMaskTexture(SQUARE_MASK)
    _G.GetMinimapShape = function() return "SQUARE" end
    local hybrid = _G.HybridMinimap
    if hybrid and hybrid.CircleMask and hybrid.MapCanvas then
        hybrid.CircleMask:SetTexture(SQUARE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        hybrid.MapCanvas:SetMaskTexture(hybrid.CircleMask)
    end
end
local function onZoom(_, level)
    if timer then timer:Cancel(); timer = nil end
    local cfg = db()
    local delay = cfg and cfg.enabled and cfg.autoZoom or 0
    if safe(level) and type(level) == "number" and level > 0
        and type(delay) == "number" and delay > 0 and C_Timer and C_Timer.NewTimer then
        timer = C_Timer.NewTimer(delay, function()
            if cfg.enabled and map and not (InCombatLockdown and InCombatLockdown()) then
                pcall(map.SetZoom, map, 0)
            end
        end)
    end
end
function MM:Initialize()
    if self.initialized then return end
    self.initialized = true
    local cfg = db()
    if not cfg or not cfg.enabled or not map then return end
    square = cfg.style == "square"
    if square then setSquare() end
    if hooksecurefunc then hooksecurefunc(map, "SetZoom", onZoom) end
end
function MM:Apply()
    local cfg = db()
    if not cfg then return end
    -- Map mask and Blizzard header changes are latched at login.
    -- A reload is required after toggling or changing shape.
    if cfg.enabled and cfg.style == "square" and square then setSquare() end
end
