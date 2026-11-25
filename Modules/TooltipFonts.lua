-- Tooltip fonts only. No tooltip text, inspect, anchor or health-bar changes.
local addon = BaziUI
local tooltip = GameTooltip
addon.TooltipFonts = addon.TooltipFonts or {}
local fonts = {
    FRIZQT = "Fonts\\FRIZQT__.TTF",
    ARIAL = "Fonts\\ARIALN.TTF",
    MORPHEUS = "Fonts\\MORPHEUS.TTF",
}
local function valid(v)
    return v ~= nil and (not issecretvalue or not issecretvalue(v))
        and (not canaccessvalue or canaccessvalue(v))
end
local function settings()
    local p = addon.db and addon.db.profile
    local db = p and p.tooltip
    if not db or not db.enabled then return end
    return p, db
end
local function resolveFont(key, profile)
    if key == "GLOBAL" then
        local global = profile.font
        if fonts[global] then return fonts[global] end
        if valid(global) and type(global) == "string" and _G[global]
            and _G[global].GetFont then
            local path = _G[global]:GetFont()
            if valid(path) and type(path) == "string" then return path end
        end
        return fonts.FRIZQT
    end
    return fonts[key] or fonts.FRIZQT
end
local function applyLine(fs, config, profile, key)
    if not fs or not config then return end
    if fs.IsForbidden and fs:IsForbidden() then return end
    local path = resolveFont(config.font, profile)
    local size = config.size
    if not valid(size) or type(size) ~= "number" then size = 12 end
    local flags = config.outline
    if flags ~= "OUTLINE" and flags ~= "THICKOUTLINE" then flags = "" end
    local shadow
    path, size, flags, shadow = addon.Typography.Resolve(key, path, size, flags, config.font == "GLOBAL")
    local ok, currentPath, currentSize, currentFlags = pcall(fs.GetFont, fs)
    if issecretvalue and issecretvalue(currentFlags) then return end
    if not ok or not valid(currentPath) or not valid(currentSize) or (currentFlags ~= nil and not valid(currentFlags)) then return end
    currentFlags = currentFlags or ""
    if currentPath ~= path or currentSize ~= size or currentFlags ~= flags then
        pcall(fs.SetFont, fs, path, size, flags)
    end
    if shadow == "on" or shadow ~= "off" and config.shadow then
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end
function addon.TooltipFonts.GetDetailFont(db)
    local value = db.healthPercentSize
    local size = valid(value) and tonumber(value) or 10
    size = math.floor(math.max(7, math.min(24, size)))
    local font = GameFontHighlightSmall:GetFont()
    return font, size, "OUTLINE"
end

function addon.TooltipFonts.StyleDetailHint(line, db)
    if not line or (line.IsForbidden and line:IsForbidden()) then return end
    pcall(line.SetFont, line, addon.TooltipFonts.GetDetailFont(db))
    line:SetShadowColor(0, 0, 0, 0.85)
    line:SetShadowOffset(1, -1)
end

local function apply()
    local profile, db = settings()
    if not db or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    for i = 1, tooltip:NumLines() do
        local config = i == 1 and db.titleFont or db.textFont
        local left = _G["GameTooltipTextLeft" .. i]
        local text = left and (not left.IsForbidden or not left:IsForbidden()) and left:GetText()
        if valid(text) and text == "Shift for details" then
            addon.TooltipFonts.StyleDetailHint(left, db)
        else
            applyLine(left, config, profile, i == 1 and "Tooltip:Title" or "Tooltip:Body")
        end
        applyLine(_G["GameTooltipTextRight" .. i], config, profile, i == 1 and "Tooltip:Title" or "Tooltip:Body")
    end
end
addon.TooltipFonts.Apply = apply
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    tooltip:HookScript("OnShow", apply)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and TooltipDataProcessor.AllTypes then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes,
            function(frame)
                if frame == tooltip then apply() end
            end)
    end
end)
