-- Minimap launch button and middle-click micro menu.
-- All micro actions use Blizzard's own micro buttons; no protected action
-- is attempted during combat.
local addon = BaziUI
addon.MinimapButtons = addon.MinimapButtons or {}
local M = addon.MinimapButtons
local map = _G.Minimap
local cluster = _G.MinimapCluster
local function db()
    return addon.db and addon.db.profile and addon.db.profile.minimap
end
local entries = {
    {"Character", "CharacterMicroButton"},
    {"Spellbook", "SpellbookMicroButton"},
    {"Talents", "TalentMicroButton"},
    {"Quests", "QuestLogMicroButton"},
    {"Guild", "GuildMicroButton"},
    {"Group Finder", "LFDMicroButton"},
    {"Collections", "CollectionsMicroButton"},
    {"Adventure Guide", "EJMicroButton"},
    {"Game Menu", "MainMenuMicroButton"},
}
local function toggleOptions()
    local frame = _G.BaziUIOptionsFrame
    if frame and frame:IsShown() then
        frame:Hide()
    elseif addon.Options then
        addon.Options:Open()
    end
end
local function makeLauncher()
    if M.Launcher or not map then return end
    local parent = cluster or map
    local b = CreateFrame("Button", "BaziUIMinimapButton", parent)
    b:SetSize(28, 28)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(map:GetFrameLevel() + 16)
    local rim = b:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(0.58, 0.39, 0.17, 0.96)
    local inset = b:CreateTexture(nil, "ARTWORK")
    inset:SetPoint("TOPLEFT", 2, -2)
    inset:SetPoint("BOTTOMRIGHT", -2, 2)
    inset:SetColorTexture(0.24, 0.10, 0.27, 0.98)
    local glyph = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    glyph:SetPoint("CENTER", 0, 0)
    glyph:SetText("B")
    glyph:SetTextColor(1, 0.82, 0.40)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", toggleOptions)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Bazi UI")
        GameTooltip:AddLine("Click to open settings", 1, 0.82, 0.4)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    M.Launcher = b
end
local function makeMenu()
    if M.Menu or not map then return end
    local parent = UIParent
    local menu = CreateFrame("Frame", "BaziUIMinimapMicroMenu", parent)
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(150, #entries * 25 + 12)
    local back = menu:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.14, 0.075, 0.035, 0.97)
    local border = menu:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", 1, -1)
    border:SetPoint("TOPRIGHT", -1, -1)
    border:SetHeight(1)
    border:SetColorTexture(0.80, 0.61, 0.32)
    for i, entry in ipairs(entries) do
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", 6, -6 - (i-1)*25)
        item:SetPoint("TOPRIGHT", -6, -6 - (i-1)*25)
        item:SetHeight(24)
        local label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 6, 0)
        label:SetText(entry[1])
        label:SetTextColor(1, 0.80, 0.44)
        local highlight = item:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.43, 0.21, 0.36, 0.72)
        item:SetScript("OnClick", function()
            menu:Hide()
            if InCombatLockdown and InCombatLockdown() then
                addon:Print("Micro menu actions are unavailable in combat.")
                return
            end
            local micro = _G[entry[2]]
            if micro and micro.Click and micro:IsEnabled() then
                micro:Click()
            end
        end)
    end
    menu:Hide()
    M.Menu = menu
end
function M:Apply()
    local cfg = db()
    if not cfg or not map then return end
    makeLauncher()
    if M.Launcher then
        M.Launcher:ClearAllPoints()
        local anchor = addon.Minimap and addon.Minimap.Border or map
        M.Launcher:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -11, -8)
        M.Launcher:SetShown(cfg.enabled and cfg.showMinimapButton ~= false)
    end
    if M.Menu and not cfg.microMenu then M.Menu:Hide() end
end
function M:Initialize()
    if self.initialized or not map then return end
    self.initialized = true
    makeMenu()
    map:HookScript("OnMouseUp", function(_, button)
        local cfg = db()
        if button ~= "MiddleButton" or not cfg or not cfg.enabled or not cfg.microMenu then return end
        if InCombatLockdown and InCombatLockdown() then return end
        if M.Menu:IsShown() then M.Menu:Hide(); return end
        M.Menu:ClearAllPoints()
        M.Menu:SetPoint("TOPLEFT", map, "TOPRIGHT", 8, 0)
        M.Menu:Show()
    end)
    self:Apply()
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    M:Initialize()
end)
