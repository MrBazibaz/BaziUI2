local addon = BaziUI

addon.Options = addon.Options or {}

local optionsFrame
local contentFrame
local navButtons = {}
local pages = {}

local function CreateLabel(parent, text, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    if size then
        label:SetFont(STANDARD_TEXT_FONT, size)
    end
    if color then
        label:SetTextColor(unpack(color))
    end
    return label
end

local function CreateSection(parent, text, y)
    local heading = CreateLabel(parent, text, 16, addon.Theme.colors.gold)
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    return heading
end

local function CreateSlider(parent, labelText, minValue, maxValue, step, value, y, onValueChanged)
    local label = CreateLabel(parent, labelText, 12, addon.Theme.colors.text)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)

    local valueText = CreateLabel(parent, tostring(value), 12, addon.Theme.colors.gold)
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
        if name == pageName then
            button:SetAlpha(1)
        else
            button:SetAlpha(0.72)
        end
    end
end

local function CreateGeneralPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.General = page

    CreateSection(page, "General", -24)
    local intro = CreateLabel(page, "Global appearance and interface defaults.", 12, addon.Theme.colors.muted)
    intro:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -52)

    CreateSection(page, "Appearance", -92)

    local db = addon.db.profile
    CreateSlider(page, "UI Scale", 0.70, 1.20, 0.01, db.uiScale, -126, function(value)
        db.uiScale = value
        if optionsFrame then
            optionsFrame:SetScale(value)
        end
    end)

    CreateSlider(page, "Default Font Size", 10, 20, 1, db.fontSize, -220, function(value)
        db.fontSize = value
    end)

    local note = CreateLabel(page, "Changes are saved automatically. More global options will be added here.", 11, addon.Theme.colors.muted)
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -320)

    return page
end

local function CreatePlaceholderPage(name, description)
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages[name] = page

    local heading = CreateLabel(page, name, 16, addon.Theme.colors.gold)
    heading:SetPoint("TOPLEFT", page, "TOPLEFT", 22, -24)

    local message = CreateLabel(page, description or "Settings for this module will appear here.", 12, addon.Theme.colors.muted)
    message:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -54)

    return page
end

local function CreateNavigationButton(parent, name, label, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(142, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    button:SetText(label)
    addon.Theme:ApplyButton(button)
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
    optionsFrame:Hide()

    if optionsFrame.Title then
        optionsFrame.Title:SetText("BAZI UI")
    end

    local subtitle = CreateLabel(optionsFrame, "Configuration", 11, addon.Theme.colors.muted)
    subtitle:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 20, -34)

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -62)
    nav:SetSize(164, 380)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 184, -62)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

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
    -- The options window is created on first open to avoid unnecessary startup work.
end
