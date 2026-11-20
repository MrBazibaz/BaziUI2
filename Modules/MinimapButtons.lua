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
    b:SetSize(32, 32)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(map:GetFrameLevel() + 16)
    -- Standard minimap-button proportions: 32px button, 25px emblem,
    -- and Blizzard's round tracking border (rather than a square highlight).
    local emblem = b:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(25, 25)
    -- Blizzard's TrackingBorder has asymmetrical transparent padding.
    -- The visible ring sits about 4px right and 1px above the button center.
    -- Share one visual anchor for the emblem and hover highlight.
    local visualCenter = CreateFrame("Frame", nil, b)
    visualCenter:SetSize(1, 1)
    visualCenter:SetPoint("CENTER", b, "CENTER", 4, 1)
    emblem:SetPoint("CENTER", visualCenter, "CENTER", 0, 0)
    emblem:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\BaziUI_Emblem_64.png")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(52, 52)
    -- Blizzard's 52px tracking-border texture has off-center visible artwork.
    -- Shift only the ring; the approved emblem and hover highlight stay put.
    border:SetPoint("CENTER", visualCenter, "CENTER", 16, -16)
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetSize(32, 32)
    glow:SetPoint("CENTER", visualCenter, "CENTER", 0, 0)
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
-- FlareUI Minimap.lua: secure micro menu rows and dismissal behavior.
local function makeMenu()
    if M.Menu or not map then return end
    local menu = CreateFrame("Frame", "BaziUIMinimapMicroMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    menu:SetBackdropColor(0.14,0.075,0.035,0.97)
    menu:SetBackdropBorderColor(0.8,0.61,0.32,1)
    local rows, width = 0, 0
    for _, entry in ipairs(entries) do
        if _G[entry[2]] then
            rows = rows + 1
            local button = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
            button:SetHeight(22)
            button:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -8-(rows-1)*22)
            button:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -8, -8-(rows-1)*22)
            local icon = button:CreateTexture(nil,"ARTWORK")
            icon:SetSize(16,16)
            icon:SetPoint("LEFT",2,0)
            icon:SetTexture(entry[3])
            local label = button:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            label:SetPoint("LEFT",icon,"RIGHT",6,0)
            label:SetText(entry[1])
            width = math.max(width,label:GetStringWidth()+28)
            button:RegisterForClicks("AnyUp","AnyDown")
            button:SetAttribute("type","macro")
            button:SetAttribute("macrotext","/click "..entry[2])
            local highlight = button:CreateTexture(nil,"HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1,1,1,0.08)
            button:HookScript("PostClick",function()
                C_Timer.After(0,function()
                    if menu:IsShown() and not InCombatLockdown() then menu:Hide() end
                end)
            end)
        end
    end
    menu:SetSize(width+16,rows*22+16)
    menu:Hide()
    table.insert(UISpecialFrames,"BaziUIMinimapMicroMenu")
    menu:RegisterEvent("PLAYER_REGEN_DISABLED")
    menu:SetScript("OnShow",function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnHide",function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnEvent",function(self,event)
        if event=="GLOBAL_MOUSE_DOWN" and self:IsMouseOver() then return end
        if not InCombatLockdown() then self:Hide() end
    end)
    M.Menu=menu
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
    if M.UpdateMapMouse then M.UpdateMapMouse() end
    if M.Menu and not cfg.microMenu then M.Menu:Hide() end
end
function M:Initialize()
    if self.initialized or not map then return end
    self.initialized = true
    makeLauncher()
    makeMenu()
    -- FlareUI Modules/Minimap.lua: map mouse system, ported as a unit.
    -- Only the database accessor and menu construction differ.
    local MinimapFrame = _G.Minimap
    local squareStyle = (db() or {}).style == "square"
    local surface
    local function HideMenu()
        if M.Menu and M.Menu:IsShown() and not InCombatLockdown() then M.Menu:Hide() end
    end
    local function ToggleMenu()
        local settings = db()
        if not (settings and settings.microMenu) then return end
        if InCombatLockdown() then
            if UIErrorsFrame then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Can't do that in combat", 1, 0.25, 0.25) end
            return
        end
        local menu = M.Menu
        if not menu then return end
        if menu:IsShown() then menu:Hide() return end
        local x, y = GetCursorPosition()
        local scale = menu:GetEffectiveScale()
        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        menu:Show()
    end
    local function InBattleground()
        local inInstance, kind = IsInInstance()
        return inInstance and kind == "pvp" or false
    end
    local function UpdateMapMouse()
        if not surface then return end
        local settings = db()
        local menu = settings and settings.microMenu and true or false
        local ownPings = squareStyle and not InBattleground()
        -- The overlay covered the entire minimap and intercepted Blizzard's
        -- quest-blob hover hit testing. Native map handles clicks and hover;
        -- our middle-click menu already uses GLOBAL_MOUSE_DOWN below.
        surface:EnableMouse(false)
        if surface.SetPassThroughButtons and not InCombatLockdown() then
            local through = { "Button4", "Button5" }
            if not ownPings then through[#through + 1] = "LeftButton"; through[#through + 1] = "RightButton" end
            through[#through + 1] = "MiddleButton"
            surface:SetPassThroughButtons(unpack(through))
        end
    end
    local function Ping()
        local x, y = GetCursorPosition()
        local scale = MinimapFrame:GetEffectiveScale()
        local cx, cy = MinimapFrame:GetCenter()
        if not cx then return end
        x, y = x / scale - cx, y / scale - cy
        if not squareStyle and math.sqrt(x * x + y * y) >= MinimapFrame:GetWidth() / 2 then return end
        pcall(MinimapFrame.PingLocation, MinimapFrame, x, y)
    end
    -- Do not create an invisible full-minimap overlay. Blizzard owns
    -- quest-area hover hit testing, map zoom and ordinary mouse input.
    -- The micro menu uses GLOBAL_MOUSE_DOWN independently below.
    M.UpdateMapMouse = function() end

    -- Temporary isolated diagnostics. /bazimouse reports runtime state;
    -- /bazimouse menu tests the menu without relying on mouse events.
    SLASH_BAZIMOUSE1 = "/bazimouse"
    SlashCmdList.BAZIMOUSE = function(arg)
        local cfg = db()
        if arg == "menu" then
            addon:Print("Diagnostic: direct menu toggle requested")
            ToggleMenu()
            addon:Print("Menu visible=" .. tostring(M.Menu and M.Menu:IsShown()))
            return
        end
        addon:Print("Mouse diagnostic: enabled=" .. tostring(cfg and cfg.enabled)
            .. " microMenu=" .. tostring(cfg and cfg.microMenu)
            .. " surface=" .. tostring(surface ~= nil)
            .. " mouse=" .. tostring(surface and surface:IsMouseEnabled())
            .. " shown=" .. tostring(surface and surface:IsShown())
            .. " mapLevel=" .. tostring(map:GetFrameLevel())
            .. " surfaceLevel=" .. tostring(surface and surface:GetFrameLevel()))
    end
    if surface then
        surface:HookScript("OnMouseDown", function(_, button)
            if button == "MiddleButton" then addon:Print("Diagnostic: surface mouse DOWN") end
        end)
        surface:HookScript("OnMouseUp", function(_, button)
            if button == "MiddleButton" then addon:Print("Diagnostic: surface mouse UP") end
        end)
    end
    -- The runtime diagnostic proved GLOBAL_MOUSE_DOWN reaches the map while
    -- the FlareUI-style overlay never receives OnMouseDown/OnMouseUp here.
    -- Use the observed working event for the micro menu exclusively.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
    watcher:SetScript("OnEvent", function(_, _, button)
        if button ~= "MiddleButton" or not map:IsMouseOver() then return end
        local settings = db()
        if not settings or not settings.enabled or not settings.microMenu then return end
        if InCombatLockdown and InCombatLockdown() then return end
        local wasOpen = M.Menu and M.Menu:IsShown()
        -- Defer until the current GLOBAL_MOUSE_DOWN dispatch has completed,
        -- otherwise the menu's own outside-click handler can immediately hide it.
        C_Timer.After(0, function()
            if not M.Menu then return end
            if wasOpen then
                M.Menu:Hide()
            elseif not M.Menu:IsShown() then
                ToggleMenu()
            end
        end)
    end)

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
