local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Character Pane is the visual reference for window materials.
-- Royal Purple is reserved for interactive controls.
addon.Theme.colors = {
    purple = { 0.29, 0.12, 0.48, 1 },
    purpleHover = { 0.39, 0.19, 0.61, 1 },
    purplePressed = { 0.20, 0.08, 0.34, 1 },
    purpleDisabled = { 0.18, 0.13, 0.23, 0.82 },
    frameEdge = { 0.20, 0.16, 0.23, 1 },
}

local function SetColor(texture, color)
    if texture and color then
        texture:SetColorTexture(unpack(color))
    end
end

function addon.Theme:ApplyWindow(frame)
    if not frame then
        return
    end

    -- Do not rely on BackdropTemplate: the Forever client may not provide
    -- the same backdrop mixin as newer retail clients.
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetTexture("Interface\\CharacterFrame\\UI-CharacterFrame-Background")
    background:SetTexCoord(0, 1, 0, 1)
    frame.backgroundTexture = background

    -- A restrained custom edge replaces the gray Blizzard dialog border.
    local edge = self.colors.frameEdge
    local borders = {}
    borders.top = frame:CreateTexture(nil, "BORDER")
    borders.bottom = frame:CreateTexture(nil, "BORDER")
    borders.left = frame:CreateTexture(nil, "BORDER")
    borders.right = frame:CreateTexture(nil, "BORDER")

    borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    borders.top:SetHeight(1)
    borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    borders.bottom:SetHeight(1)
    borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    borders.left:SetWidth(1)
    borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    borders.right:SetWidth(1)

    for _, texture in pairs(borders) do
        SetColor(texture, edge)
    end
    frame.customBorders = borders
end

function addon.Theme:CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 142, height or 28)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    SetColor(background, self.colors.purple)
    button.background = background

    -- Slight inset and a quiet edge keep the controls from looking like flat
    -- square color swatches.
    local edgeColor = { 0.48, 0.34, 0.62, 0.95 }
    local edge = {}
    edge.top = button:CreateTexture(nil, "BORDER")
    edge.bottom = button:CreateTexture(nil, "BORDER")
    edge.left = button:CreateTexture(nil, "BORDER")
    edge.right = button:CreateTexture(nil, "BORDER")

    edge.top:SetPoint("TOPLEFT")
    edge.top:SetPoint("TOPRIGHT")
    edge.top:SetHeight(1)
    edge.bottom:SetPoint("BOTTOMLEFT")
    edge.bottom:SetPoint("BOTTOMRIGHT")
    edge.bottom:SetHeight(1)
    edge.left:SetPoint("TOPLEFT")
    edge.left:SetPoint("BOTTOMLEFT")
    edge.left:SetWidth(1)
    edge.right:SetPoint("TOPRIGHT")
    edge.right:SetPoint("BOTTOMRIGHT")
    edge.right:SetWidth(1)
    for _, texture in pairs(edge) do
        SetColor(texture, edgeColor)
    end

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText(label)
    button.label = text

    button:SetScript("OnEnter", function(self)
        SetColor(self.background, addon.Theme.colors.purpleHover)
    end)
    button:SetScript("OnLeave", function(self)
        SetColor(self.background, addon.Theme.colors.purple)
    end)
    button:SetScript("OnMouseDown", function(self)
        SetColor(self.background, addon.Theme.colors.purplePressed)
    end)
    button:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            SetColor(self.background, addon.Theme.colors.purpleHover)
        else
            SetColor(self.background, addon.Theme.colors.purple)
        end
    end)
    button:SetScript("OnDisable", function(self)
        SetColor(self.background, addon.Theme.colors.purpleDisabled)
        self.label:SetAlpha(0.55)
    end)
    button:SetScript("OnEnable", function(self)
        SetColor(self.background, addon.Theme.colors.purple)
        self.label:SetAlpha(1)
    end)

    return button
end

function addon.Theme:SetButtonActive(button, active)
    if not button then
        return
    end

    button.isActive = active
    if active then
        SetColor(button.background, self.colors.purpleHover)
        button.label:SetAlpha(1)
    else
        SetColor(button.background, self.colors.purple)
        button.label:SetAlpha(0.88)
    end
end

function addon.Theme:Initialize()
end
