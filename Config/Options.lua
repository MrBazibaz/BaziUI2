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

    CreateSection(page, "Bazi UI", -26)

    local intro = CreateLabel(page, "Your interface. Your rules.", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -58)

    CreateDivider(page, -88)

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

    CreateSection(page, name, -26)
    CreateDivider(page, -60)

    local message = CreateLabel(page, description or "Settings for this module will appear here.", "GameFontHighlight")
    message:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -88)

    return page
end

local function CreateNavigationButton(parent, name, label, y)
    local button = addon.Theme:CreateButton(parent, label, 142, 28)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
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
    optionsFrame = CreateFrame("Frame", "BaziUIOptionsFrame", UIParent, "UIPanelDialogTemplate")
    optionsFrame:SetSize(690, 470)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    addon.Theme:ApplyWindow(optionsFrame)
    optionsFrame:Hide()

    local title = CreateLabel(optionsFrame, "Bazi UI", "GameFontNormal")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 24, -18)

    local subtitle = CreateLabel(optionsFrame, "Interface settings", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 25, -42)

    local close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -4, -4)

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -72)
    nav:SetSize(164, 370)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 184, -72)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.55, 0.48, 0.62, 0.55)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", -10, 0)
    separator:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", -10, 0)

    CreateNavigationButton(nav, "General", "General", -8)
    CreateNavigationButton(nav, "UnitFrames", "UnitFrames", -42)
    CreateNavigationButton(nav, "Nameplates", "Nameplates", -76)
    CreateNavigationButton(nav, "ActionBars", "ActionBars", -110)
    CreateNavigationButton(nav, "Chat", "Chat", -144)
    CreateNavigationButton(nav, "Quest", "Quest", -178)
    CreateNavigationButton(nav, "Gathering", "Gathering", -212)
    CreateNavigationButton(nav, "Minimap", "Minimap", -246)
    CreateNavigationButton(nav, "Tooltip", "Tooltip", -280)
    CreateNavigationButton(nav, "Combat", "Combat", -314)
    CreateNavigationButton(nav, "BugTab", "BugTab", -348)

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
