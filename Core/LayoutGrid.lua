local addon = BaziUI
local Grid = {}
addon.LayoutGrid = Grid
local owners, lines, frame = {}, {}, nil

function Grid.Spacing()
    local profile = addon.db and addon.db.profile
    return math.max(8, math.min(80, tonumber(profile and profile.gridSpacing) or 24))
end

function Grid.Refresh()
    if not frame or not frame:IsShown() then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    local spacing, count = Grid.Spacing(), 0
    local function draw(vertical, offset)
        count = count + 1
        local line = lines[count] or frame:CreateTexture(nil, "ARTWORK")
        lines[count] = line
        line:ClearAllPoints()
        local center = offset == 0
        if vertical then
            line:SetPoint("TOP", frame, "TOP", offset, 0)
            line:SetPoint("BOTTOM", frame, "BOTTOM", offset, 0)
            line:SetWidth(center and 2 or 1)
        else
            line:SetPoint("LEFT", frame, "LEFT", 0, offset)
            line:SetPoint("RIGHT", frame, "RIGHT", 0, offset)
            line:SetHeight(center and 2 or 1)
        end
        if center then line:SetColorTexture(1, 0.15, 0.15, 0.85)
        else line:SetColorTexture(0.94, 0.87, 0.74, 0.23) end
        line:Show()
    end
    for x = spacing, width / 2, spacing do draw(true, x); draw(true, -x) end
    for y = spacing, height / 2, spacing do draw(false, y); draw(false, -y) end
    draw(true, 0)
    draw(false, 0)
    for i = count + 1, #lines do lines[i]:Hide() end
end

function Grid.IsShown()
    return frame and frame:IsShown() or false
end

function Grid.Show(owner, enabled)
    owners[owner] = enabled and true or nil
    if next(owners) and not frame then
        frame = CreateFrame("Frame", "BaziUILayoutGrid", UIParent)
        frame:SetAllPoints(UIParent)
        frame:SetFrameStrata("LOW")
        frame:EnableMouse(false)
        frame:SetScript("OnSizeChanged", Grid.Refresh)
    end
    if not frame then return end
    frame:SetShown(next(owners) ~= nil)
    Grid.Refresh()
end

function Grid.Hide()
    wipe(owners)
    if frame then frame:Hide() end
end
