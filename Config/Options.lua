local addon = BaziUI

addon.Options = addon.Options or {}

local optionsFrame
local contentFrame
local navButtons = {}
local pages = {}

local function CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text)
    return label
end

local function CreateDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.57, 0.42, 0.23, 0.55)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    return line
end

local function CreateSection(parent, text, y)
    local heading = CreateLabel(parent, text, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    return heading
end

local function CreatePanel(parent, top, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, top)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, top)
    panel:SetHeight(height)

    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(panel)
    fill:SetColorTexture(0.12, 0.075, 0.15, 0.82)

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(0.52, 0.24, 0.72, 1)

    local topLine = panel:CreateTexture(nil, "BORDER")
    topLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.78, 0.59, 0.31, 0.45)
    return panel
end

local function CreateSlider(parent, labelText, minValue, maxValue, step, value, y, onValueChanged)
    local label = CreateLabel(parent, labelText, "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)

    local valueText = CreateLabel(parent, tostring(value), "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, y)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, y - 30)
    slider:SetWidth(300)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetValue(value)
    slider:SetObeyStepOnDrag(true)

    local name = slider:GetName()
    if name then
        local low = _G[name .. "Low"]
        local high = _G[name .. "High"]
        local text = _G[name .. "Text"]
        if low then low:SetText(tostring(minValue)) end
        if high then high:SetText(tostring(maxValue)) end
        if text then text:SetText("") end
    end

    slider:SetScript("OnValueChanged", function(self, newValue)
        newValue = math.floor((newValue / step) + 0.5) * step
        valueText:SetText(string.format("%g", newValue))
        if onValueChanged then
            onValueChanged(newValue)
        end
    end)

    return slider
end

local function ShowPage(pageName)
    for name, page in pairs(pages) do
        page:SetShown(name == pageName)
    end

    for name, button in pairs(navButtons) do
        addon.Theme:SetButtonActive(button, name == pageName)
    end
end

local function CreateGeneralPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.General = page

    CreatePanel(page, -12, 75)
    CreateSection(page, "Bazi UI", -24)

    local intro = CreateLabel(page, "Your interface. Your rules.", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -58)

    CreateDivider(page, -88)

    CreatePanel(page, -100, 230)
    CreateSection(page, "Appearance", -112)

    local db = addon.db.profile
    CreateSlider(page, "Options Window Scale", 0.70, 1.20, 0.01, db.uiScale, -152, function(value)
        db.uiScale = value
        if optionsFrame then
            optionsFrame:SetScale(value)
        end
    end)

    CreateSlider(page, "Default Font Size", 10, 20, 1, db.fontSize, -246, function(value)
        db.fontSize = value
    end)

    local note = CreateLabel(page, "Changes are saved automatically.", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -350)

    return page
end

local function CreatePlaceholderPage(name, description)
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages[name] = page

    CreatePanel(page, -12, 130)
    CreateSection(page, name, -26)
    CreateDivider(page, -60)

    local message = CreateLabel(page, description or "Settings for this module will appear here.", "GameFontHighlight")
    message:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -88)

    return page
end

local function CreateNavigationButton(parent, name, label, y)
    local button = addon.Theme:CreateButton(parent, label, 150, 32)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    local font = button:GetFontString()
    if font then font:SetFontObject("GameFontNormalLarge") end
    button:SetScript("OnClick", function()
        ShowPage(name)
    end)
    navButtons[name] = button
end

function addon.Options:Open()
    if not optionsFrame then
        self:Create()
    end

    optionsFrame:Show()
    optionsFrame:Raise()
end

function addon.Options:Create()
    optionsFrame = CreateFrame("Frame", "BaziUIOptionsFrame", UIParent)
    -- Use textures rather than SetBackdrop: some Forever frame builds do not expose it.
    local rimColor = { 0.72, 0.53, 0.29, 0.95 }
    local function AddRim(anchor1, anchor2, width, height)
        local line = optionsFrame:CreateTexture(nil, "BORDER")
        line:SetPoint(anchor1, optionsFrame, anchor1, 0, 0)
        if anchor2 then line:SetPoint(anchor2, optionsFrame, anchor2, 0, 0) end
        if width then line:SetWidth(width) end
        if height then line:SetHeight(height) end
        line:SetColorTexture(unpack(rimColor))
    end
    AddRim("TOPLEFT", "TOPRIGHT", nil, 2)
    AddRim("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    AddRim("TOPLEFT", "BOTTOMLEFT", 2, nil)
    AddRim("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    optionsFrame:SetSize(690, 505)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    local backdrop = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    backdrop:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 7, -7)
    backdrop:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -7, 7)
    backdrop:SetColorTexture(0.07, 0.045, 0.10, 0.93)
    local header = optionsFrame:CreateTexture(nil, "BORDER")
    header:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -8, -8)
    header:SetHeight(48)
    header:SetColorTexture(0.15, 0.075, 0.22, 0.90)
    local headerLine = optionsFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 8, -56)
    headerLine:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -8, -56)
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.76, 0.55, 0.28, 0.75)
    optionsFrame:Hide()

    local title = CreateLabel(optionsFrame, "Bazi UI", "GameFontNormal")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 25, -19)
    title:SetFontObject("GameFontNormalLarge")
    title:SetJustifyH("CENTER")

    local subtitle = CreateLabel(optionsFrame, "INTERFACE SETTINGS", "GameFontDisableSmall")
    subtitle:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -55, -24)

    local close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -4, -4)

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -78)
    local navBackground = nav:CreateTexture(nil, "BACKGROUND")
    navBackground:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 10)
    navBackground:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, -4)
    navBackground:SetColorTexture(0.045, 0.03, 0.065, 0.86)
    nav:SetSize(164, 420)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 184, -78)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.72, 0.54, 0.30, 0.50)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", -10, 0)
    separator:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", -10, 0)

    CreateNavigationButton(nav, "General", "General", -8)
    CreateNavigationButton(nav, "UnitFrames", "UnitFrames", -45)
    CreateNavigationButton(nav, "Nameplates", "Nameplates", -82)
    CreateNavigationButton(nav, "ActionBars", "ActionBars", -119)
    CreateNavigationButton(nav, "Chat", "Chat", -156)
    CreateNavigationButton(nav, "Quest", "Quest", -193)
    CreateNavigationButton(nav, "Gathering", "Gathering", -230)
    CreateNavigationButton(nav, "Minimap", "Minimap", -267)
    CreateNavigationButton(nav, "Tooltip", "Tooltip", -304)
    CreateNavigationButton(nav, "Combat", "Combat", -341)
    CreateNavigationButton(nav, "BugTab", "BugTab", -378)

    CreateGeneralPage()
    CreatePlaceholderPage("UnitFrames")
    CreatePlaceholderPage("Nameplates")
    CreatePlaceholderPage("ActionBars")
    CreatePlaceholderPage("Chat")
    CreatePlaceholderPage("Quest")
    CreatePlaceholderPage("Gathering")
    CreatePlaceholderPage("Minimap")
    CreatePlaceholderPage("Tooltip")
    CreatePlaceholderPage("Combat")
    CreatePlaceholderPage("BugTab")

    ShowPage("General")
end

function addon.Options:Initialize()
    -- Created on first open.
end
