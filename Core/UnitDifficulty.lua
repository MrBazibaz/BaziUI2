local addon = BaziUI
local skullTexture = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local skull = "|T" .. skullTexture .. ":0|t"

local function readable(value, kind)
    return not (issecretvalue and issecretvalue(value))
        and type(value) == kind and (not canaccessvalue or canaccessvalue(value))
end

function addon.GetUnitDifficulty(unit)
    local level = UnitLevel(unit)
    if not readable(level, "number") then return nil, nil, level end
    if level < 0 then return skull, nil, level end
    if level == 0 then return "", nil, level end
    if UnitEffectiveLevel then
        local effective = UnitEffectiveLevel(unit)
        if readable(effective, "number") and effective < 0 then return skull, nil, level end
    end
    local attackable = UnitCanAttack("player", unit)
    if readable(attackable, "boolean") and attackable then
        local playerLevel = UnitLevel("player")
        if readable(playerLevel, "number") and playerLevel > 0 and level - playerLevel >= 10 then
            return skull, nil, level
        end
    end
    local color
    if GetCreatureDifficultyColor then color = GetCreatureDifficultyColor(level)
    elseif GetQuestDifficultyColor then color = GetQuestDifficultyColor(level) end
    return tostring(level), color, level
end

function addon.SetUnitDifficulty(label, unit, badge)
    local text, color, raw = addon.GetUnitDifficulty(unit)
    if text == skull and badge then
        if not badge.baziDifficultySkull then
            local icon = badge:GetParent():CreateTexture(nil, "OVERLAY", nil, 5)
            icon:SetPoint("CENTER", badge, "CENTER")
            icon:SetTexture(skullTexture)
            badge.baziDifficultySkull = icon
        end
        local size = badge:GetWidth() * 0.53
        badge.baziDifficultySkull:SetSize(size, size)
        badge.baziDifficultySkull:Show()
        label:SetText("")
    else
        if badge and badge.baziDifficultySkull then badge.baziDifficultySkull:Hide() end
        label:SetText(text or raw)
    end
    if color then label:SetTextColor(color.r, color.g, color.b)
    elseif text == skull then label:SetTextColor(1, 1, 1)
    else label:SetTextColor(1, 0.82, 0) end
end
