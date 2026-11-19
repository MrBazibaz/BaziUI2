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
    {"Character", "CharacterMicroButton", "Interface\\Icons\\INV_Shirt_01"},
    {"Spellbook", "SpellbookMicroButton", "Interface\\Icons\\INV_Misc_Book_09"},
    {"Talents", "TalentMicroButton", "Interface\\Icons\\Ability_Marksmanship"},
    {"Quests", "QuestLogMicroButton", "Interface\\Icons\\INV_Misc_Note_01"},
    {"Guild", "GuildMicroButton", "Interface\\Icons\\INV_Banner_03"},
    {"Group Finder", "LFDMicroButton", "Interface\\Icons\\INV_Misc_GroupLooking"},
    {"Collections", "CollectionsMicroButton", "Interface\\Icons\\INV_Misc_Pet_01"},
    {"Adventure Guide", "EJMicroButton", "Interface\\Icons\\INV_Misc_Book_11"},
    {"Game Menu", "MainMenuMicroButton", "Interface\\Icons\\INV_Misc_Gear_01"},
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
    b:SetSize(24, 24)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(map:GetFrameLevel() + 16)
    -- The Bazi emblem already includes its own round gold ring.
    -- Render the complete asset instead of stacking a second, offset ring.
    local emblem = b:CreateTexture(nil, "ARTWORK")
    emblem:SetAllPoints(b)
    emblem:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\BaziUI_Emblem_64.png")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", toggleOptions)
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)
    b:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cfg = db()
        if cfg then
            local anchor = addon.Minimap and addon.Minimap.Border or map
            cfg.launcherX = self:GetLeft() - anchor:GetLeft()
            cfg.launcherY = self:GetTop() - anchor:GetBottom()
        end
    end)
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
    menu:SetSize(196, #entries * 31 + 12)
    local back = menu:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.14, 0.075, 0.035, 0.97)
    local border = menu:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", 1, -1)
    border:SetPoint("TOPRIGHT", -1, -1)
    border:SetHeight(2)
    border:SetColorTexture(0.80, 0.61, 0.32)
    for i, entry in ipairs(entries) do
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", 6, -6 - (i-1)*31)
        item:SetPoint("TOPRIGHT", -6, -6 - (i-1)*31)
        item:SetHeight(30)
        local label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local icon = item:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 4, 0)
        local source = _G[entry[2]]
        local normal = source and source.GetNormalTexture and source:GetNormalTexture()
        local texture = normal and normal.GetTexture and normal:GetTexture()
        if type(texture) == "string" or type(texture) == "number" then
            icon:SetTexture(texture)
        else
            icon:SetTexture(entry[3])
        end
        label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
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
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    table.insert(UISpecialFrames, "BaziUIMinimapMicroMenu")
    menu:RegisterEvent("PLAYER_REGEN_DISABLED")
    menu:SetScript("OnShow", function(self)
        -- Do not treat the middle click which opened the menu as an outside click.
        C_Timer.After(0.1, function()
            if self:IsShown() then self:RegisterEvent("GLOBAL_MOUSE_DOWN") end
        end)
    end)
    menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_DOWN" and self:IsMouseOver() then return end
        self:Hide()
    end)
    M.Menu = menu
end
-- Keep third-party addon buttons above the bronze frame and apply the
-- same hover setting. Never touch minimap pins, Blizzard controls or protected
-- frames in combat. This is deliberately narrower than FlareUI's drawer scanner.
local managed = setmetatable({}, {__mode = "k"})
local function isAddonButton(child)
    if not child or not child.IsObjectType or not child:IsObjectType("Button") then return false end
    if child == M.Launcher then return false end
    local name = child:GetName() or ""
    if name:find("^BaziUI") or name:find("^Minimap") or name:find("^MiniMap")
        or name:find("^GameTime") or name:find("^TimeManager")
        or name:find("^QueueStatus") or name:find("^AddonCompartment")
        or name:find("^Quest") or name:find("^HandyNotes")
        or name:find("^Gather") or name:find("^HereBeDragons") then return false end
    return name:find("^LibDBIcon") or name:find("MinimapButton")
        or name:find("MiniMapButton") or name:find("MinimapIcon")
end
local function refreshAddonButtons()
    local cfg = db()
    if not cfg or not cfg.enabled then return end
    local anchor = addon.Minimap and addon.Minimap.Border or map
    local hover = map:IsMouseOver() or (anchor and anchor:IsMouseOver())
    for child in pairs(managed) do
        if child:IsMouseOver() then hover = true end
    end
    local holder = M.ButtonHolder
    if not holder then
        holder = CreateFrame("Frame", nil, cluster or UIParent)
        holder:SetAllPoints(map)
        holder:SetFrameStrata("HIGH")
        holder:SetFrameLevel(math.max(map:GetFrameLevel() + 20, 25))
        M.ButtonHolder = holder
    end
    local function scan(parent)
        if not parent then return end
        for _, child in ipairs({parent:GetChildren()}) do
            if isAddonButton(child) then
                managed[child] = true
                if not (InCombatLockdown and InCombatLockdown()) then
                    if child:GetParent() ~= holder then child:SetParent(holder) end
                    child:SetFrameStrata("HIGH")
                    child:SetFrameLevel(holder:GetFrameLevel() + 1)
                end
            end
        end
    end
    scan(map)
    scan(_G.MinimapBackdrop)
    scan(cluster)
    for child in pairs(managed) do
        if not (InCombatLockdown and InCombatLockdown() and child.IsProtected and child:IsProtected()) then
            child:SetAlpha((not cfg.hideAddonButtons or hover) and 1 or 0)
            child:EnableMouse(not cfg.hideAddonButtons or hover)
        end
    end
    if M.Launcher then
        local show = cfg.showMinimapButton ~= false and (not cfg.hideAddonButtons or hover or M.Launcher:IsMouseOver())
        M.Launcher:SetShown(show)
    end
end
function M:Apply()
    local cfg = db()
    if not cfg or not map then return end
    makeLauncher()
    if M.Launcher then
        M.Launcher:ClearAllPoints()
        local anchor = addon.Minimap and addon.Minimap.Border or map
        if cfg.launcherX and cfg.launcherY then
            M.Launcher:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", cfg.launcherX, cfg.launcherY)
        else
            M.Launcher:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -11, -8)
        end
        local show = cfg.enabled and cfg.showMinimapButton ~= false
        if show and cfg.hideAddonButtons then
            show = (map.IsMouseOver and map:IsMouseOver())
                or (anchor.IsMouseOver and anchor:IsMouseOver())
                or M.Launcher:IsMouseOver()
        end
        M.Launcher:SetShown(show)
    end
    if M.MouseSurface then
        local active = cfg.enabled and cfg.microMenu
        M.MouseSurface:EnableMouse(active)
        if M.MouseSurface.SetMouseClickEnabled then
            M.MouseSurface:SetMouseClickEnabled(active)
        end
        -- Match FlareUI: pass the middle button through only when the menu is disabled.
        -- Changing pass-through buttons is restricted during combat.
        if M.MouseSurface.SetPassThroughButtons and not (InCombatLockdown and InCombatLockdown()) then
            if active then
                M.MouseSurface:SetPassThroughButtons("LeftButton", "RightButton", "Button4", "Button5")
            else
                M.MouseSurface:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
            end
        end
    end
    if M.Menu and not cfg.microMenu then M.Menu:Hide() end
end
function M:Initialize()
    if self.initialized or not map then return end
    self.initialized = true
    makeLauncher()
    makeMenu()
    -- FlareUI uses a separate mouse surface above the map. Hooking the
    -- Blizzard map directly does not reliably receive middle clicks.
    local surface = CreateFrame("Frame", nil, map)
    surface:SetAllPoints(map)
    surface:SetFrameStrata("HIGH")
    surface:SetFrameLevel(map:GetFrameLevel() + 30)
    if surface.SetMouseMotionEnabled then surface:SetMouseMotionEnabled(false) end
    if surface.SetPropagateMouseMotion then surface:SetPropagateMouseMotion(true) end
    surface:EnableMouse(true)
    if surface.SetMouseClickEnabled then surface:SetMouseClickEnabled(true) end
    -- Apply() configures button pass-through based on the current menu setting.
    M.MouseSurface = surface
    local mouseEvents = CreateFrame("Frame")
    mouseEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    mouseEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    mouseEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    mouseEvents:SetScript("OnEvent", function() M:Apply() end)
    -- Both the overlay and Minimap can receive the same physical click.
    -- Handle mouse-down and deduplicate it rather than toggling twice on mouse-up.
    local lastMiddleClick = -1
    local function OnMinimapMiddleClick(_, button)
        local cfg = db()
        if button ~= "MiddleButton" or not cfg or not cfg.enabled or not cfg.microMenu then return end
        if InCombatLockdown and InCombatLockdown() then return end
        local now = GetTime()
        if now - lastMiddleClick < 0.25 then return end
        lastMiddleClick = now
        if M.Menu:IsShown() then M.Menu:Hide(); return end
        M.Menu:ClearAllPoints()
        local x, y = GetCursorPosition()
        local scale = M.Menu:GetEffectiveScale()
        M.Menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        M.Menu:Show()
    end
    surface:SetScript("OnMouseDown", OnMinimapMiddleClick)
    map:HookScript("OnMouseDown", OnMinimapMiddleClick)
    if M.Launcher then
        M.Launcher:HookScript("OnEnter", function() M:Apply() end)
        M.Launcher:HookScript("OnLeave", function() M:Apply() end)
    end
    map:HookScript("OnEnter", function() M:Apply() end)
    map:HookScript("OnLeave", function() M:Apply() end)
    if addon.Minimap and addon.Minimap.Border then
        addon.Minimap.Border:HookScript("OnEnter", function() M:Apply() end)
        addon.Minimap.Border:HookScript("OnLeave", function() M:Apply() end)
    end
    -- Hide Blizzard's separate addon compartment button, not the calendar.
    local compartment = _G.AddonCompartmentFrame
    if compartment then
        compartment:Hide()
        compartment:HookScript("OnShow", function(self) self:Hide() end)
    end
    self:Apply()
    if C_Timer and C_Timer.NewTicker then
        M.ButtonTicker = C_Timer.NewTicker(0.25, refreshAddonButtons)
    end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    M:Initialize()
end)
