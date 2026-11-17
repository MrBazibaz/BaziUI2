local addon = BaziUI

addon.Theme = addon.Theme or {}

addon.Theme.colors = {
    gold = { 0.90, 0.73, 0.39, 1 },
    bronze = { 0.48, 0.35, 0.19, 1 },
    text = { 0.91, 0.86, 0.74, 1 },
    muted = { 0.67, 0.61, 0.52, 1 },
    purple = { 0.36, 0.22, 0.55, 1 },
    purpleHover = { 0.49, 0.32, 0.70, 1 },
    purplePressed = { 0.25, 0.14, 0.39, 1 },
    error = { 0.80, 0.22, 0.20, 1 },
}

function addon.Theme:ApplyButton(button)
    if not button then
        return
    end

    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local highlight = button:GetHighlightTexture()

    if normal then
        normal:SetVertexColor(unpack(self.colors.purple))
    end
    if pushed then
        pushed:SetVertexColor(unpack(self.colors.purplePressed))
    end
    if highlight then
        highlight:SetVertexColor(unpack(self.colors.purpleHover))
    end

    local text = button:GetFontString()
    if text then
        text:SetTextColor(unpack(self.colors.text))
    end
end

function addon.Theme:Initialize()
    -- Keep Blizzard's native gold/bronze frame artwork.
    -- Purple is reserved for interactive controls and selected navigation.
end
