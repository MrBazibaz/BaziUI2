local addon = BaziUI

addon.Theme = addon.Theme or {}

-- Blizzard's Character Pane is the visual reference for panels and window
-- artwork. Do not replace its native frame textures with a separate palette.
-- Purple is reserved for interactive controls.
addon.Theme.colors = {
    gold = { 0.90, 0.73, 0.39, 1 },
    bronze = { 0.48, 0.35, 0.19, 1 },
    text = { 0.91, 0.86, 0.74, 1 },
    muted = { 0.67, 0.61, 0.52, 1 },

    -- Royal Purple button states.
    purple = { 0.36, 0.22, 0.55, 1 },
    purpleHover = { 0.49, 0.32, 0.70, 1 },
    purplePressed = { 0.25, 0.14, 0.39, 1 },
    purpleDisabled = { 0.25, 0.20, 0.31, 0.75 },

    error = { 0.80, 0.22, 0.20, 1 },
}

local function Tint(texture, color)
    if texture and color then
        texture:SetVertexColor(unpack(color))
    end
end

function addon.Theme:ApplyButton(button)
    if not button then
        return
    end

    -- Keep the Blizzard button textures and shape; only recolor their states.
    Tint(button:GetNormalTexture(), self.colors.purple)
    Tint(button:GetPushedTexture(), self.colors.purplePressed)
    Tint(button:GetHighlightTexture(), self.colors.purpleHover)
    Tint(button:GetDisabledTexture(), self.colors.purpleDisabled)

    local text = button:GetFontString()
    if text then
        text:SetTextColor(unpack(self.colors.text))
    end
end

function addon.Theme:SetButtonActive(button, active)
    if not button then
        return
    end

    if active then
        button:SetAlpha(1)
        Tint(button:GetNormalTexture(), self.colors.purpleHover)
    else
        button:SetAlpha(0.78)
        Tint(button:GetNormalTexture(), self.colors.purple)
    end
end

function addon.Theme:Initialize()
    -- Blizzard's native Character Pane artwork defines panel appearance.
    -- Royal Purple is applied only to interactive buttons.
end
