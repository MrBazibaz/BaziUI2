local addon = BaziUI
local chat = addon.Chat
local toasts = {}
chat.FriendToasts = toasts
local preview, frame, original, positioning, queued
function toasts.GetMoverFrame() return frame end
local recipeSystem
local movedRecipes = setmetatable({}, {__mode = "k"})
local friendOnline, friendOffline = 1, 2
local onlineHeight = 63

local function position(region, verticalOffset)
    local cfg = chat.Settings()
    local x, y = cfg.friendToastX or -380, cfg.friendToastY or -205
    local ratio = UIParent:GetEffectiveScale() / region:GetEffectiveScale()
    x, y = x * ratio, (y + (verticalOffset or 0)) * ratio
    local point, parent, relative, oldX, oldY = region:GetPoint(1)
    if region:GetNumPoints() ~= 1 or point ~= "CENTER" or parent ~= UIParent
        or relative ~= "CENTER" or oldX ~= x or oldY ~= y then
        region:ClearAllPoints()
        region:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

local function positionRecipes()
    if not addon.db or not recipeSystem then return end
    local pool = recipeSystem.alertFramePool
    if not (pool and pool.EnumerateActive) then return end
    if not chat.Settings().friendToastPosition then
        local restore
        for recipe in pool:EnumerateActive() do
            if movedRecipes[recipe] then recipe:ClearAllPoints(); restore = true end
        end
        wipe(movedRecipes)
        if restore and AlertFrame and AlertFrame.UpdateAnchors then AlertFrame:UpdateAnchors() end
        return
    end
    local scale = UIParent:GetEffectiveScale()
    local offset = 0
    if frame and frame:IsShown() and (frame.toastType == friendOnline or frame.toastType == friendOffline) then
        offset = frame:GetHeight() / 2 * frame:GetEffectiveScale() / scale + 6
    end
    for recipe in pool:EnumerateActive() do
        local height = recipe:GetHeight() * recipe:GetEffectiveScale() / scale
        position(recipe, offset > 0 and offset + height / 2 or 0)
        offset = offset > 0 and offset + height + 6 or height / 2 + 6
        movedRecipes[recipe] = true
    end
end

function toasts.Refresh()
    if not addon.db or positioning then return end
    local cfg = chat.Settings()
    positioning = true
    local kind = frame and frame.toastType
    if kind == friendOnline and frame:IsShown() then onlineHeight = frame:GetHeight() end
    if frame and cfg.friendToastPosition and (kind == friendOnline or kind == friendOffline) then
        if not original and frame:GetNumPoints() > 0 then
            original = {}
            for i = 1, frame:GetNumPoints() do original[i] = {frame:GetPoint(i)} end
        end
        position(frame)
    elseif frame and original then
        frame:ClearAllPoints()
        for _, point in ipairs(original) do frame:SetPoint(unpack(point, 1, 5)) end
        original = nil
        if ChatAlertFrame and ChatAlertFrame.UpdateAnchors then ChatAlertFrame:UpdateAnchors() end
    end
    if preview and preview:IsShown() then
        preview:SetScale(frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
        preview:SetSize(frame:GetWidth(), onlineHeight)
        position(preview)
    end
    positionRecipes()
    positioning = false
end

function toasts.Preview(enabled)
    if enabled == nil then enabled = not (preview and preview:IsShown()) end
    if enabled and not preview then
        if not frame then return false end
        preview = CreateFrame("Button", "BaziUIFriendToastPreview", UIParent, "SocialToastTemplate")
        preview:SetFrameStrata("FULLSCREEN_DIALOG")
        preview:EnableMouse(false)
        preview.CloseButton:EnableMouse(false)

        local icon = preview:CreateTexture(nil, "BORDER")
        icon:SetTexture(frame.IconTexture:GetTexture())
        icon:SetTexCoord(0, 0.25, 0.5, 1)
        icon:SetSize(frame.IconTexture:GetSize())
        icon:SetPoint("LEFT", 4, 0)

        local friend = preview:CreateFontString(nil, "BORDER", "FriendsFont_Normal")
        friend:SetPoint("TOPLEFT", 44, -10)
        friend:SetHeight(10)
        friend:SetText(FRIENDS_BNET_NAME_COLOR:WrapTextInColorCode("Example friend"))
        local character = preview:CreateFontString(nil, "BORDER", "FriendsFont_Normal")
        character:SetPoint("TOPLEFT", friend, "BOTTOMLEFT", 0, -4)
        character:SetHeight(10)
        character:SetText(FRIENDS_BNET_NAME_COLOR:WrapTextInColorCode("Example character"))
        local status = preview:CreateFontString(nil, "BORDER", "FriendsFont_Normal")
        status:SetPoint("TOPLEFT", character, "BOTTOMLEFT", 0, -4)
        status:SetHeight(10)
        status:SetText(FRIENDS_GRAY_COLOR:WrapTextInColorCode(BN_TOAST_ONLINE))
    end
    if preview then preview:SetShown(enabled) end
    toasts.Refresh()
    return enabled
end

local function queue()
    if queued or positioning or not addon.db then return end
    if not chat.Settings().friendToastPosition and not (preview and preview:IsShown()) then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        toasts.Refresh()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function()
    if not frame and BNToastFrame then
        frame = BNToastFrame
        frame:HookScript("OnShow", queue)
        frame:HookScript("OnHide", queue)
        if frame.ShowToast then hooksecurefunc(frame, "ShowToast", queue) end
        hooksecurefunc(frame, "SetPoint", queue)
    end
    if not recipeSystem and NewRecipeLearnedAlertSystem and NewRecipeLearnedAlertSystem.AdjustAnchors then
        recipeSystem = NewRecipeLearnedAlertSystem
        hooksecurefunc(recipeSystem, "AdjustAnchors", positionRecipes)
    end
    if frame and recipeSystem then events:UnregisterAllEvents() end
    queue()
end)
