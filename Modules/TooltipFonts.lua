-- Tooltip fonts only. No tooltip text, inspect, anchor or health-bar changes.
local addon = BaziUI
local tooltip = GameTooltip
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
    if not ok or not valid(currentPath) or not valid(currentSize) or not valid(currentFlags) then return end
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
local function apply()
    local profile, db = settings()
    if not db then return end
    for i = 1, tooltip:NumLines() do
        local config = i == 1 and db.titleFont or db.textFont
        applyLine(_G["GameTooltipTextLeft" .. i], config, profile, i == 1 and "Tooltip:Title" or "Tooltip:Body")
        applyLine(_G["GameTooltipTextRight" .. i], config, profile, i == 1 and "Tooltip:Title" or "Tooltip:Body")
    end
end
addon.TooltipFonts = addon.TooltipFonts or {}
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
