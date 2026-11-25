local addon = BaziUI
local database = addon.Database
local presets = {"2560 x 1440", "1920 x 1080", "1920 x 1080 Zoomed"}
local modules = {{"inventory", "Inventory"}, {"cleanup", "Cleanup"}, {"rolls", "Loot rolls"},
    {"chat", "Chat"}, {"questTracker", "Quest tracker"}, {"dialogue", "NPC dialogue"}}
local window

local function label(parent, caption, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetText(caption)
    return text
end

local function build()
    local frame = CreateFrame("Frame", "BaziUIFirstSetup", UIParent)
    frame:SetSize(680, 304)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.085, 0.055, 0.085, 0.98)
    addon.Theme:CreateFrameBorder(frame, frame, frame)
    label(frame, "Choose your Bazi UI layout", "GameFontNormalLarge"):SetPoint("TOPLEFT", 24, -22)
    local help = label(frame, "", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 24, -54)
    help:SetText("Choose a layout, then optionally select the modules you want.")
    local cards, choices = {}, CreateFrame("Frame", nil, frame)
    choices:SetAllPoints()
    local selected, overrides
    local function finish(useOptions)
        if not database:FinishSetup(selected, useOptions and overrides or nil) then
            help:SetText("Finish setup after combat.")
        end
    end
    local function selectPreset(preset)
        selected, overrides = preset, {}
        for _, card in ipairs(cards) do card:Hide() end
        choices:Show()
        local settings = BaziUIDB.profiles[preset] or addon.db.profile
        help:SetText(BaziUIDB.profiles[preset] and preset or (preset .. " · Uses the current default template"))
        for i, entry in ipairs(modules) do
            local key = entry[1]
            local check = choices[i]
            local config = settings[key]
            if key == "cleanup" or key == "rolls" then config = settings.inventory or {} end
            local enabled = config and (key == "cleanup" or key == "rolls") and config[key]
            if key == "cleanup" or key == "rolls" then enabled = enabled ~= false
            else enabled = config and config.enabled == true end
            check:SetChecked(not not enabled)
            overrides[key] = not not enabled
        end
    end
    for i, preset in ipairs(presets) do
        local card = addon.Theme:CreateButton(frame, preset, 201, 31)
        card:SetPoint("TOPLEFT", 24 + (i - 1) * 216, -197)
        local layout = card:CreateTexture(nil, "ARTWORK")
        layout:SetSize(i == 3 and 170 or 188, 91)
        layout:SetPoint("BOTTOM", card, "TOP", 0, 7)
        layout:SetColorTexture(0.28, 0.16, 0.22, 1)
        card:SetHitRectInsets(0, 0, -98, 0)
        card:SetScript("OnClick", function() selectPreset(preset) end)
        cards[i] = card
    end
    for i, entry in ipairs(modules) do
        local key, caption = unpack(entry)
        local check = addon.Theme:CreateCheckbox(choices)
        check:SetSize(23, 23)
        check:SetPoint("TOPLEFT", 27 + (i - 1) % 2 * 252, -90 - math.floor((i - 1) / 2) * 37)
        label(check, caption):SetPoint("LEFT", check, "RIGHT", 5, 0)
        check:SetScript("OnClick", function(self) overrides[key] = not not self:GetChecked() end)
        choices[i] = check
    end
    local apply = addon.Theme:CreateButton(choices, "Apply selected modules", 180, 28)
    apply:SetPoint("BOTTOMRIGHT", -22, 18)
    apply:SetScript("OnClick", function() finish(true) end)
    local useTemplate = addon.Theme:CreateButton(choices, "Use template as-is", 168, 28)
    useTemplate:SetPoint("RIGHT", apply, "LEFT", -8, 0)
    useTemplate:SetScript("OnClick", function() finish(false) end)
    local back = addon.Theme:CreateButton(choices, "Back", 77, 28)
    back:SetPoint("BOTTOMLEFT", 22, 18)
    back:SetScript("OnClick", function()
        choices:Hide()
        for _, card in ipairs(cards) do card:Show() end
        help:SetText("Choose a layout, then optionally select the modules you want.")
    end)
    choices:Hide()
    local skip = addon.Theme:CreateButton(frame, "×", 28, 28)
    skip:SetPoint("TOPRIGHT", -14, -14)
    skip:SetScript("OnClick", function() database:FinishSetup(); frame:Hide() end)
    return frame
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self)
    if not addon.db or not database:PendingSetup() or InCombatLockdown() then return end
    self:UnregisterAllEvents()
    window = window or build()
    window:Show()
end)
