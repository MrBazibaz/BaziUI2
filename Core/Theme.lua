local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Keep Blizzard's relief and ornaments; purple belongs on controls only.
addon.Theme.colors = {
    purple = { 0.29, 0.12, 0.48, 1 },
    purpleHover = { 0.39, 0.19, 0.61, 1 },
    purplePressed = { 0.20, 0.08, 0.34, 1 },
    purpleDisabled = { 0.18, 0.13, 0.23, 0.82 },
}

local function Tint(texture, color)
    if texture and color then
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end
end

function addon.Theme:ApplyWindow(frame)
    -- Window art is supplied by UIPanelDialogTemplate on the parent frame.
    -- Do not cover it with a flat black rectangle or 1px custom borders.
end

function addon.Theme:CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 142, height or 28)
    button:SetText(label)

    -- Use Blizzard's shaped button artwork, not solid color textures.
    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local highlight = button:GetHighlightTexture()
    local disabled = button:GetDisabledTexture()

    if normal then Tint(normal, self.colors.purple) end
    if pushed then Tint(pushed, self.colors.purplePressed) end
    if highlight then
        highlight:SetBlendMode("ADD")
        Tint(highlight, self.colors.purpleHover)
    end
    if disabled then Tint(disabled, self.colors.purpleDisabled) end

    button:SetScript("OnEnter", function(self)
        if not self.isActive then Tint(self:GetNormalTexture(), addon.Theme.colors.purpleHover) end
    end)
    button:SetScript("OnLeave", function(self)
        Tint(self:GetNormalTexture(), self.isActive and addon.Theme.colors.purpleHover or addon.Theme.colors.purple)
    end)

    return button
end

function addon.Theme:SetButtonActive(button, active)
    if not button then return end
    button.isActive = active
    Tint(button:GetNormalTexture(), active and self.colors.purpleHover or self.colors.purple)
end

function addon.Theme:Initialize()
end
