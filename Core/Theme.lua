local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Royal Purple is reserved for interactive controls.
-- Window artwork uses Blizzard's Character Pane background and native frame border.
addon.Theme.colors = {
    purple = { 0.47, 0.32, 0.66, 1 },
    purpleHover = { 0.57, 0.40, 0.77, 1 },
    purplePressed = { 0.34, 0.21, 0.50, 1 },
    purpleDisabled = { 0.25, 0.20, 0.31, 0.75 },
}

function addon.Theme:ApplyWindow(frame)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\CharacterFrame\\UI-CharacterFrame-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
end

local function SetTextureColor(texture, color)
    if texture and color then
        texture:SetColorTexture(unpack(color))
    end
end

function addon.Theme:CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 142, height or 28)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    SetTextureColor(background, self.colors.purple)
    button.background = background

    local borderColor = { 0.72, 0.62, 0.84, 0.9 }
    local border = {}
    border.top = button:CreateTexture(nil, "BORDER")
    border.bottom = button:CreateTexture(nil, "BORDER")
    border.left = button:CreateTexture(nil, "BORDER")
    border.right = button:CreateTexture(nil, "BORDER")

    border.top:SetPoint("TOPLEFT")
    border.top:SetPoint("TOPRIGHT")
    border.top:SetHeight(1)
    border.bottom:SetPoint("BOTTOMLEFT")
    border.bottom:SetPoint("BOTTOMRIGHT")
    border.bottom:SetHeight(1)
    border.left:SetPoint("TOPLEFT")
    border.left:SetPoint("BOTTOMLEFT")
    border.left:SetWidth(1)
    border.right:SetPoint("TOPRIGHT")
    border.right:SetPoint("BOTTOMRIGHT")
    border.right:SetWidth(1)

    for _, edge in pairs(border) do
        SetTextureColor(edge, borderColor)
    end

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText(label)
    button.label = text

    button:SetScript("OnEnter", function(self)
        SetTextureColor(self.background, addon.Theme.colors.purpleHover)
    end)
    button:SetScript("OnLeave", function(self)
        SetTextureColor(self.background, addon.Theme.colors.purple)
    end)
    button:SetScript("OnMouseDown", function(self)
        SetTextureColor(self.background, addon.Theme.colors.purplePressed)
    end)
    button:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            SetTextureColor(self.background, addon.Theme.colors.purpleHover)
        else
            SetTextureColor(self.background, addon.Theme.colors.purple)
        end
    end)
    button:SetScript("OnDisable", function(self)
        SetTextureColor(self.background, addon.Theme.colors.purpleDisabled)
        self.label:SetAlpha(0.55)
    end)
    button:SetScript("OnEnable", function(self)
        SetTextureColor(self.background, addon.Theme.colors.purple)
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
        SetTextureColor(button.background, self.colors.purpleHover)
        button.label:SetAlpha(1)
    else
        SetTextureColor(button.background, self.colors.purple)
        button.label:SetAlpha(0.88)
    end
end

function addon.Theme:Initialize()
    -- Theme assets are applied by the modules that create their own frames.
end
