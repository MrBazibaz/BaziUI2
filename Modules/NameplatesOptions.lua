-- Bazi UI Nameplates: isolated settings page.
-- This file is deliberately not registered in BaziUI.toc yet.
-- Integration into Config/Options.lua requires explicit approval.
local addon = BaziUI
addon.NameplatesOptions = addon.NameplatesOptions or {}
local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"

local defaults = {
    friendlyIcon = "role", friendlyScope = "group", raidRoles = true,
    friendlyX = 0, friendlyY = 20, friendlySize = 28,
    enemyWidth = 160, enemyHeight = 16, enemyScale = 1,
    enemyName = true, enemyLevel = true, enemyQuest = true,
    enemyThreat = true, enemyDebuffs = true, enemyCastbar = true,
    enemyNameX = 0, enemyNameY = 0, enemyLevelX = 0, enemyLevelY = 0,
    enemyQuestX = 0, enemyQuestY = 0, enemyDebuffX = 0, enemyDebuffY = 0,
    enemyCastX = 0, enemyCastY = -20,
    enemyNameFont = "general", enemyLevelFont = "general",
    enemyCastFont = "general", enemyNameSize = 0, enemyLevelSize = 0,
    enemyCastSize = 0,
}
local function Settings()
    local profile = addon.db and addon.db.profile
    if not profile then return nil end
    if type(profile.nameplates) ~= "table" then profile.nameplates = {} end
    for key, value in pairs(defaults) do
        if profile.nameplates[key] == nil then profile.nameplates[key] = value end
    end
    return profile.nameplates
end
local function Label(parent, text, font)
    local obj = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    obj:SetText(text)
    return obj
end
local function Background(parent)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.25, 0.125, 0.055, 0.94)
    local art = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints()
    art:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    art:SetAlpha(0.20)
end
local function PanelArtwork(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(frame)
    fill:SetColorTexture(0.19, 0.105, 0.052, 0.97)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints(frame)
    art:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    art:SetAlpha(0.30)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(3)
    accent:SetColorTexture(0.76, 0.57, 0.29, 0.90)
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(0.78, 0.59, 0.31, 0.45)
end

local function Row(parent, text, y, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    frame:SetHeight(height or 43)
    Background(frame)
    local title = Label(frame, text)
    title:SetPoint("LEFT", 13, 0)
    title:SetTextColor(1, 0.78, 0.39)
    return frame
end
local function Notify()
    -- A single future hook for live application, not an invented dependency.
    if addon.Nameplates and addon.Nameplates.Apply then addon.Nameplates:Apply() end
end
local function NumberBox(parent, width, initial, commit)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetSize(width or 55, 23)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontNormal")
    edit:SetTextColor(1, 0.81, 0.45)
    edit:SetJustifyH("CENTER")
    edit:SetTextInsets(3, 3, 0, 0)
    Background(edit)
    edit:SetText(tostring(initial))
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local function Save()
        local n = tonumber((edit:GetText() or ""):gsub(",", "."))
        if n then commit(n) end
        edit:ClearFocus()
    end
    edit:SetScript("OnEnterPressed", Save)
    edit:SetScript("OnEditFocusLost", function()
        local n = tonumber((edit:GetText() or ""):gsub(",", "."))
        if n then commit(n) end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return edit
end
local function StepButton(parent, text, anchor, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(23, 23)
    b:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    Background(b)
    local glyph = Label(b, text, "GameFontNormalLarge")
    glyph:SetPoint("CENTER")
    glyph:SetTextColor(1, 0.82, 0.46)
    b:SetScript("OnClick", onClick)
    return b
end
local function Numeric(parent, title, y, db, key, low, high, step)
    local row = Row(parent, title, y)
    local function Clamp(v)
        return math.max(low, math.min(high, math.floor(v / step + 0.5) * step))
    end
    local box
    box = NumberBox(row, 54, db[key], function(value)
        db[key] = Clamp(value)
        box:SetText(string.format("%g", db[key]))
        Notify()
    end)
    box:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    local minus = StepButton(row, "-", box, function()
        db[key] = Clamp(db[key] - step)
        box:SetText(string.format("%g", db[key]))
        Notify()
    end)
    local plus = CreateFrame("Button", nil, row)
    plus:SetSize(23, 23)
    plus:SetPoint("RIGHT", minus, "LEFT", -4, 0)
    Background(plus)
    local sign = Label(plus, "+", "GameFontNormalLarge")
    sign:SetPoint("CENTER")
    sign:SetTextColor(1, 0.82, 0.46)
    plus:SetScript("OnClick", function()
        db[key] = Clamp(db[key] + step)
        box:SetText(string.format("%g", db[key]))
        Notify()
    end)
    return row
end
local function Toggle(parent, title, y, db, key)
    local row = Row(parent, title, y)
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetPoint("RIGHT", row, "RIGHT", -16, 0)
    check:SetChecked(db[key])
    check:SetScript("OnClick", function(self)
        db[key] = not not self:GetChecked()
        Notify()
    end)
    return row
end
local function Dropdown(parent, title, y, db, key, choices)
    local row = Row(parent, title, y)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(174, 25)
    button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    Background(button)
    local caption = Label(button, "")
    caption:SetPoint("LEFT", 9, 0)
    local arrow = Label(button, "v", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -8, 0)
    local menu = CreateFrame("Frame", nil, button)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(button:GetFrameLevel() + 20)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    menu:SetSize(174, #choices * 25 + 4)
    Background(menu)
    local function Refresh()
        for _, choice in ipairs(choices) do
            if db[key] == choice[1] then caption:SetText(choice[2]); return end
        end
        caption:SetText("Select...")
    end
    for i, choice in ipairs(choices) do
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 25)
        item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * 25)
        item:SetHeight(25)
        local text = Label(item, choice[2], "GameFontHighlightSmall")
        text:SetPoint("LEFT", 9, 0)
        item:SetScript("OnClick", function()
            db[key] = choice[1]
            Refresh()
            menu:Hide()
            Notify()
        end)
    end
    menu:Hide()
    button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    Refresh()
    return row
end
local function Slider(parent, title, y, db, key, low, high, step)
    local row = Row(parent, title, y, 50)
    local box
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(122, 18)
    slider:SetPoint("RIGHT", row, "RIGHT", -76, 0)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT")
    track:SetPoint("RIGHT", slider, "RIGHT")
    track:SetHeight(7)
    track:SetTexture(ASSET .. "Sliders\\Slider_Track.png")
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(24, 28)
    thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
    slider:SetThumbTexture(thumb)
    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetHeight(7)
    fill:SetTexture(ASSET .. "Sliders\\Slider_Fill_Gold.png")
    box = NumberBox(row, 51, db[key], function(value)
        slider:SetValue(math.max(low, math.min(high, value)))
    end)
    box:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    slider:SetScript("OnValueChanged", function(_, value)
        local n = math.max(low, math.min(high, math.floor(value / step + 0.5) * step))
        db[key] = n
        if not box:HasFocus() then box:SetText(string.format("%g", n)) end
        fill:SetWidth(math.max(1, 122 * (n - low) / (high - low)))
        Notify()
    end)
    slider:SetValue(db[key])
    return row
end
local function Heading(parent, title, y)
    local label = Label(parent, title, "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    label:SetTextColor(1, 0.79, 0.42)
end
local function ScrollPage(parent)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetPoint("TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", -18, 0)
    frame:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(610, 1300)
    frame:SetScrollChild(child)
    frame:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(math.max(1, w - 8))
    end)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 45)))
    end)
    return frame, child
end
function addon.NameplatesOptions:CreatePage(parent)
    local db = Settings()
    if not db then return nil end
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    -- Match Minimap's two-panel structure and right-hand navigation.
    local headingPanel = CreateFrame("Frame", nil, page)
    headingPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -8)
    headingPanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -8)
    headingPanel:SetHeight(76)
    PanelArtwork(headingPanel)
    local heading = Label(headingPanel, "NAMEPLATES", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 22, -12)
    heading:SetTextColor(1, 0.79, 0.42)

    local main = CreateFrame("Frame", nil, page)
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    PanelArtwork(main)
    if main.SetClipsChildren then main:SetClipsChildren(true) end

    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 58)
    local tabButtons, tabPanels = {}, {}
    local activeTab = "Friendly"

    local function RefreshTabs()
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            button.fill:SetColorTexture(selected and 0.34 or 0.23,
                selected and 0.17 or 0.12, selected and 0.25 or 0.07, 0.98)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, viewport in pairs(tabPanels) do viewport:SetShown(name == activeTab) end
        local available = math.max(120, page:GetHeight() - 110)
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
        main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
        main:SetHeight(math.min(activeTab == "Friendly" and 430 or 650, available))
        local viewport = tabPanels[activeTab]
        if viewport then viewport:SetVerticalScroll(0) end
    end

    for i, name in ipairs({"Friendly", "Enemy"}) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(108, 29)
        b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -(i - 1) * 29)
        b.fill = b:CreateTexture(nil, "BACKGROUND")
        b.fill:SetAllPoints()
        b.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = b:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            b.edges[#b.edges + 1] = edge
        end
        b.accent = b:CreateTexture(nil, "OVERLAY")
        b.accent:SetPoint("TOPRIGHT"); b.accent:SetPoint("BOTTOMRIGHT")
        b.accent:SetWidth(3)
        b.label = Label(b, name)
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        b:SetScript("OnEnter", function()
            if activeTab ~= name then b.fill:SetColorTexture(0.28, 0.15, 0.085, 0.98) end
        end)
        b:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = b
    end

    local function NewTab(name, height)
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
        if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetSize(500, height)
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self)
            panel:SetWidth(math.max(1, self:GetWidth()))
        end)
        local scrollbar = CreateFrame("Slider", nil, main)
        scrollbar:SetOrientation("VERTICAL")
        scrollbar:SetWidth(12)
        scrollbar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -12)
        scrollbar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
        scrollbar:SetMinMaxValues(0, 1)
        scrollbar:SetValueStep(1)
        local track = scrollbar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        track:SetColorTexture(0.12, 0.07, 0.04, 0.9)
        local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(14, 38)
        thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
        scrollbar:SetThumbTexture(thumb)
        local syncing = false
        local function RefreshScroll()
            local limit = math.max(0, panel:GetHeight() - viewport:GetHeight())
            scrollbar:SetMinMaxValues(0, math.max(1, limit))
            scrollbar:SetShown(viewport:IsShown() and limit > 1)
            if not syncing then
                syncing = true
                scrollbar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
                syncing = false
            end
        end
        scrollbar:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            syncing = true
            viewport:SetVerticalScroll(value)
            syncing = false
        end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 36)))
            RefreshScroll()
        end)
        viewport:HookScript("OnVerticalScroll", RefreshScroll)
        viewport:HookScript("OnSizeChanged", RefreshScroll)
        viewport:HookScript("OnShow", RefreshScroll)
        viewport:HookScript("OnHide", function() scrollbar:Hide() end)
        tabPanels[name] = viewport
        return panel
    end

    local friendly = NewTab("Friendly", 450)
    Dropdown(friendly, "ICON TYPE", -4, db, "friendlyIcon", {
        {"off", "Disabled"}, {"class", "Class Icon"}, {"role", "Role Icon"},
    })
    Dropdown(friendly, "SHOW ICONS FOR", -49, db, "friendlyScope", {
        {"all", "All Friendly Players"}, {"group", "Group Members Only"},
    })
    Toggle(friendly, "RAID: TANK AND HEALER ONLY", -94, db, "raidRoles")
    Heading(friendly, "ICON LAYOUT", -159)
    Slider(friendly, "ICON SIZE", -195, db, "friendlySize", 12, 64, 1)
    Numeric(friendly, "ICON X OFFSET", -255, db, "friendlyX", -300, 300, 1)
    Numeric(friendly, "ICON Y OFFSET", -303, db, "friendlyY", -300, 300, 1)
    local note = Label(friendly,
        "In raids: only tank and healer role icons. Class icons and DPS icons are hidden.",
        "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", friendly, "TOPLEFT", 14, -365)
    note:SetWidth(400)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.66, 0.63, 0.59, 1)

    local enemy = NewTab("Enemy", 1530)
    Heading(enemy, "HEALTH BARS", -12)
    Slider(enemy, "HEALTH WIDTH", -48, db, "enemyWidth", 80, 300, 1)
    Slider(enemy, "HEALTH HEIGHT", -106, db, "enemyHeight", 6, 45, 1)
    Slider(enemy, "NAMEPLATE SCALE", -164, db, "enemyScale", 0.5, 2, 0.05)
    Heading(enemy, "TEXT AND FONTS", -232)
    Toggle(enemy, "SHOW NAME", -266, db, "enemyName")
    Dropdown(enemy, "NAME FONT", -314, db, "enemyNameFont", {
        {"general", "General (Default)"}, {"friz", "Friz Quadrata"}, {"arial", "Arial Narrow"},
    })
    Slider(enemy, "NAME SIZE (0 = GENERAL)", -362, db, "enemyNameSize", 0, 32, 1)
    Numeric(enemy, "NAME X OFFSET", -420, db, "enemyNameX", -300, 300, 1)
    Numeric(enemy, "NAME Y OFFSET", -468, db, "enemyNameY", -300, 300, 1)
    Toggle(enemy, "SHOW LEVEL", -516, db, "enemyLevel")
    Dropdown(enemy, "LEVEL FONT", -564, db, "enemyLevelFont", {
        {"general", "General (Default)"}, {"friz", "Friz Quadrata"}, {"arial", "Arial Narrow"},
    })
    Slider(enemy, "LEVEL SIZE (0 = GENERAL)", -612, db, "enemyLevelSize", 0, 32, 1)
    Numeric(enemy, "LEVEL X OFFSET", -670, db, "enemyLevelX", -300, 300, 1)
    Numeric(enemy, "LEVEL Y OFFSET", -718, db, "enemyLevelY", -300, 300, 1)
    Heading(enemy, "INDICATORS", -776)
    Toggle(enemy, "QUEST OBJECTIVE ICON", -810, db, "enemyQuest")
    Numeric(enemy, "QUEST ICON X", -858, db, "enemyQuestX", -300, 300, 1)
    Numeric(enemy, "QUEST ICON Y", -906, db, "enemyQuestY", -300, 300, 1)
    Toggle(enemy, "THREAT INDICATOR", -954, db, "enemyThreat")
    Toggle(enemy, "MY DEBUFFS", -1002, db, "enemyDebuffs")
    Numeric(enemy, "DEBUFF X", -1050, db, "enemyDebuffX", -300, 300, 1)
    Numeric(enemy, "DEBUFF Y", -1098, db, "enemyDebuffY", -300, 300, 1)
    Heading(enemy, "CASTBAR", -1156)
    Toggle(enemy, "SHOW CASTBAR", -1190, db, "enemyCastbar")
    Dropdown(enemy, "CASTBAR FONT", -1238, db, "enemyCastFont", {
        {"general", "General (Default)"}, {"friz", "Friz Quadrata"}, {"arial", "Arial Narrow"},
    })
    Slider(enemy, "CASTBAR TEXT SIZE (0 = GENERAL)", -1286, db, "enemyCastSize", 0, 32, 1)
    Numeric(enemy, "CASTBAR X OFFSET", -1344, db, "enemyCastX", -300, 300, 1)
    Numeric(enemy, "CASTBAR Y OFFSET", -1392, db, "enemyCastY", -300, 300, 1)

    page:HookScript("OnShow", RefreshTabs)
    page:HookScript("OnSizeChanged", RefreshTabs)
    RefreshTabs()
    return page
end
