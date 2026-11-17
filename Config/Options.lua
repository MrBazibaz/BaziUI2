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
    heading:SetTextColor(1, 0.79, 0.42, 1)
    return heading
end

local function CreatePanel(parent, top, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, top)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, top)
    panel:SetHeight(height)

    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(panel)
    fill:SetColorTexture(0.19, 0.105, 0.052, 0.97)

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(0.76, 0.57, 0.29, 0.90)

    local topLine = panel:CreateTexture(nil, "BORDER")
    topLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.78, 0.59, 0.31, 0.45)
    return panel
end

local function CreateSlider(parent, labelText, description, minValue, maxValue, step, value, y, onValueChanged)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, y)
    row:SetHeight(54)
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(row)
    fill:SetColorTexture(0.25, 0.125, 0.055, 0.96)
    local heading = CreateLabel(row, labelText, "GameFontNormal")
    heading:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -10)
    heading:SetTextColor(1, 0.78, 0.39)
    local hint = CreateLabel(row, description, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -30)
    hint:SetTextColor(0.91, 0.78, 0.61, 1)
    local valueText = CreateLabel(row, "", "GameFontNormal")
    valueText:SetPoint("RIGHT", row, "RIGHT", -15, 0)
    valueText:SetTextColor(1, 0.81, 0.45)
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(115, 18)
    slider:SetPoint("RIGHT", row, "RIGHT", -53, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(7)
    track:SetColorTexture(0.09, 0.055, 0.045, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(13, 19)
    thumb:SetColorTexture(0.34, 0.17, 0.25, 1)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged", function(self, raw)
        local rounded = math.floor(raw / step + 0.5) * step
        valueText:SetText(string.format("%g", rounded))
        if onValueChanged then onValueChanged(rounded) end
    end)
    slider:SetValue(value)
    valueText:SetText(string.format("%g", value))
    return slider
end

local function ShowPage(pageName)
    for name, page in pairs(pages) do
        page:SetShown(name == pageName)
    end

    for name, button in pairs(navButtons) do
        button.baziActive = (name == pageName)
        button.baziRefresh()
    end
end

local function CreateGeneralPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.General = page
    local introPanel = CreatePanel(page, -10, 66)
    CreateSection(introPanel, "REALM CONFIGURATION", -14)
    local intro = CreateLabel(page, "Make Azeroth yours. Fine-tune your interface.", "GameFontHighlightSmall")
    intro:SetParent(introPanel)
    intro:SetPoint("TOPLEFT", introPanel, "TOPLEFT", 22, -39)
    intro:SetTextColor(0.96, 0.82, 0.63, 1)

    local appearancePanel = CreatePanel(page, -88, 242)
    CreateSection(appearancePanel, "APPEARANCE", -14)
    local db = addon.db.profile
    CreateSlider(page, "WINDOW SCALE", "Size of the Bazi UI settings window", 0.70, 1.20, 0.01, db.uiScale, -142, function(value)
        db.uiScale = value
        if optionsFrame then optionsFrame:SetScale(value) end
    end)
    CreateSlider(page, "FONT SIZE", "Default text size for supported modules", 10, 20, 1, db.fontSize, -204, function(value)
        db.fontSize = value
    end)
    local note = CreateLabel(page, "Changes are saved automatically.", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -352)
    note:SetTextColor(0.90, 0.76, 0.55, 1)
    return page
end

local function CreatePlaceholderPage(name, description)
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages[name] = page

    local placeholderPanel = CreatePanel(page, -12, 130)
    CreateSection(placeholderPanel, name, -14)
    CreateDivider(placeholderPanel, -48)

    local message = CreateLabel(page, description or "Settings for this module will appear here.", "GameFontHighlight")
    message:SetParent(placeholderPanel)
    message:SetPoint("TOPLEFT", placeholderPanel, "TOPLEFT", 22, -76)
    message:SetTextColor(0.96, 0.82, 0.63, 1)

    return page
end

local function CreateNavigationButton(parent, name, label, y)
    -- Custom flat navigation: the active page gets purple, not every button.
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(170, 34)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, y)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(button)
    local stripe = button:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    stripe:SetWidth(3)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", button, "LEFT", 17, 0)
    text:SetText(label)
    text:SetJustifyH("LEFT")
    button.baziActive = false
    button.baziHover = false
    button.baziRefresh = function()
        if button.baziActive then
            fill:SetColorTexture(0.34, 0.17, 0.25, 0.98)
            stripe:SetColorTexture(0.83, 0.63, 0.30, 1)
            text:SetTextColor(1, 0.85, 0.55)
        elseif button.baziHover then
            fill:SetColorTexture(0.28, 0.15, 0.085, 0.96)
            stripe:SetColorTexture(0.57, 0.42, 0.26, 0.8)
            text:SetTextColor(0.95, 0.87, 0.73)
        else
            fill:SetColorTexture(0.18, 0.095, 0.05, 0.94)
            stripe:SetColorTexture(0.54, 0.35, 0.19, 0.75)
            text:SetTextColor(0.87, 0.74, 0.56)
        end
    end
    button:SetScript("OnEnter", function(self) self.baziHover = true; self.baziRefresh() end)
    button:SetScript("OnLeave", function(self) self.baziHover = false; self.baziRefresh() end)
    button:SetScript("OnClick", function() ShowPage(name) end)
    button.baziRefresh()
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
    -- Blizzard-style decorative corner caps. Keep all border edges as
    -- simple solid strips; never stretch a corner atlas across an edge.
    local function Edge(pointA, pointB, ax, ay, bx, by, thickness, vertical, color)
        local t = optionsFrame:CreateTexture(nil, "OVERLAY")
        t:SetPoint(pointA, optionsFrame, pointA, ax, ay)
        t:SetPoint(pointB, optionsFrame, pointB, bx, by)
        if vertical then t:SetWidth(thickness) else t:SetHeight(thickness) end
        t:SetColorTexture(unpack(color))
    end
    local gold = {0.69, 0.48, 0.26, 1}
    local highlight = {0.88, 0.69, 0.40, 1}
    local shadow = {0.19, 0.10, 0.055, 1}
    local cap = 22
    -- Edges stop short of the corners so they cannot make square corners.
    Edge("TOPLEFT", "TOPRIGHT", cap, -2, -cap, -2, 4, false, gold)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", cap, 2, -cap, 2, 4, false, gold)
    Edge("TOPLEFT", "BOTTOMLEFT", 2, -cap, 2, cap, 4, true, gold)
    Edge("TOPRIGHT", "BOTTOMRIGHT", -2, -cap, -2, cap, 4, true, gold)
    Edge("TOPLEFT", "TOPRIGHT", cap, -6, -cap, -6, 1, false, highlight)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", cap, 6, -cap, 6, 1, false, highlight)
    Edge("TOPLEFT", "BOTTOMLEFT", 6, -cap, 6, cap, 1, true, highlight)
    Edge("TOPRIGHT", "BOTTOMRIGHT", -6, -cap, -6, cap, 1, true, highlight)

    local function Corner(point, flipX, flipY)
        local t = optionsFrame:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetTexture("Interface\\\\DialogFrame\\\\UI-DialogBox-Corner")
        t:SetSize(32, 32)
        t:SetPoint(point, optionsFrame, point, flipX and 0 or 0, flipY and 0 or 0)
        t:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1,
                      flipY and 1 or 0, flipY and 0 or 1)
        t:SetVertexColor(0.95, 0.78, 0.54, 1)
    end
    Corner("TOPLEFT", false, false)
    Corner("TOPRIGHT", true, false)
    Corner("BOTTOMLEFT", false, true)
    Corner("BOTTOMRIGHT", true, true)
    optionsFrame:SetSize(900, 555)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    -- Ease into 75% opacity during movement; restore instantly on stopping.
    local displayedAlpha = 1
    local fadeSeconds = 0.65
    optionsFrame:SetScript("OnShow", function(self)
        displayedAlpha = 1
        self:SetAlpha(1)
    end)
    optionsFrame:SetScript("OnUpdate", function(self, elapsed)
        local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
        if speed > 0 then
            displayedAlpha = math.max(0.75, displayedAlpha - elapsed * (0.25 / fadeSeconds))
        else
            displayedAlpha = 1
        end
        if self:GetAlpha() ~= displayedAlpha then
            self:SetAlpha(displayedAlpha)
        end
    end)
    local backdrop = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    backdrop:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 7, -7)
    backdrop:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -7, 7)
    backdrop:SetColorTexture(0.12, 0.075, 0.044, 0.98)
    local header = optionsFrame:CreateTexture(nil, "BORDER")
    header:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -8, -8)
    header:SetHeight(48)
    header:SetColorTexture(0.22, 0.12, 0.065, 0.98)
    local headerLine = optionsFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 8, -56)
    headerLine:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -8, -56)
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.76, 0.55, 0.28, 0.75)
    optionsFrame:Hide()

    local title = CreateLabel(optionsFrame, "BAZI UI", "GameFontNormal")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -18)
    title:SetFontObject("GameFontNormalLarge")
    title:SetJustifyH("CENTER")

    local subtitle = CreateLabel(optionsFrame, "INTERFACE SETTINGS", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 23, -26)

    local close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -4, -4)

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -78)
    local navBackground = nav:CreateTexture(nil, "BACKGROUND")
    navBackground:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 10)
    navBackground:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, -4)
    navBackground:SetColorTexture(0.105, 0.063, 0.038, 0.96)
    nav:SetSize(180, 430)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 204, -78)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.72, 0.49, 0.25, 0.65)
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
