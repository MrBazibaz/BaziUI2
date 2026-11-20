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
local function Row(parent, text, y, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    frame:SetHeight(height or 42)
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
    local tabs = {}
    local active
    for i, name in ipairs({"Friendly", "Enemy"}) do
        local button = CreateFrame("Button", nil, page)
        button:SetSize(135, 28)
        button:SetPoint("TOPLEFT", page, "TOPLEFT", 18 + (i - 1) * 143, -10)
        Background(button)
        local text = Label(button, name)
        text:SetPoint("CENTER")
        text:SetTextColor(1, 0.82, 0.46)
        tabs[name] = {button = button, text = text}
    end
    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -48)
    body:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 4)
    local panes = {}
    local function Pane(name)
        local frame, child = ScrollPage(body)
        panes[name] = frame
        frame:Hide()
        return child
    end
    local friendly = Pane("Friendly")
    friendly:SetHeight(650)
    Heading(friendly, "FRIENDLY NAMEPLATES", -12)
    Dropdown(friendly, "ICON TYPE", -48, db, "friendlyIcon", {
        {"off", "Disabled"}, {"class", "Class Icon"}, {"role", "Role Icon"},
    })
    Dropdown(friendly, "SHOW ICONS FOR", -96, db, "friendlyScope", {
        {"all", "All Friendly Players"}, {"group", "Group Members Only"},
    })
    Toggle(friendly, "RAID: TANK AND HEALER ONLY", -144, db, "raidRoles")
    Heading(friendly, "ICON LAYOUT", -206)
    Slider(friendly, "ICON SIZE", -242, db, "friendlySize", 12, 64, 1)
    Numeric(friendly, "ICON X OFFSET", -302, db, "friendlyX", -300, 300, 1)
    Numeric(friendly, "ICON Y OFFSET", -350, db, "friendlyY", -300, 300, 1)
    local note = Label(friendly, "Raid suppresses class icons and DPS icons. Role icons reuse UnitFrames assets.", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", friendly, "TOPLEFT", 26, -405)
    note:SetTextColor(0.91, 0.78, 0.61)
    local enemy = Pane("Enemy")
    enemy:SetHeight(1550)
    Heading(enemy, "ENEMY NAMEPLATES", -12)
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
    local function Show(name)
        active = name
        for key, pane in pairs(panes) do pane:SetShown(key == name) end
        for key, tab in pairs(tabs) do
            tab.text:SetTextColor(key == name and 1 or 0.76, key == name and 0.85 or 0.66, key == name and 0.55 or 0.48)
        end
    end
    for name, tab in pairs(tabs) do
        tab.button:SetScript("OnClick", function() Show(name) end)
    end
    Show("Friendly")
    return page
end
