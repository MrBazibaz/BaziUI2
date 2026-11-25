local module = BaziUI.ActionBars
local gradient = "Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziHealthGradientRight.tga"
local xpFill = "Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziXPFill.tga"
local restedMask = "Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziXPRestedEdge.tga"
local restedSeamTop, restedSeamBottom = 0, 0.94
local edge = "Interface\\Tooltips\\UI-Tooltip-Border"
local fonts = {friz="Fonts\\FRIZQT__.TTF", arial="Fonts\\ARIALN.TTF"}
local fillInset = 2
local xpColor = BaziUI.Theme.colors.experience
local restedColor = {0.08, 0.24, 0.53}
local restedPreviewColor = {0.18, 0.39, 0.71}
local questColor = {181 / 255, 138 / 255, 18 / 255}
local backgroundColor = {0.075, 0.048, 0.031}
local bar, options, reputationBar
function module.GetExperienceMoverFrame(reputation) return reputation and reputationBar or (not reputation and bar) end
local nativeBar, nativeAlpha
local nativeInput = {}
local nativeHooks = {}
local alphaHooks = {}
local questXP

local function completedQuestXP()
    if questXP then return questXP end
    questXP = 0
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and GetQuestLogRewardXP) then return questXP end
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        local id = info and not info.isHeader and info.questID
        if id and id > 0 and ((C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id))
            or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id))) then
            questXP = questXP + (GetQuestLogRewardXP(id) or 0)
        end
    end
    return questXP
end

local function nativeExperienceBar()
    for _, holder in pairs({MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer}) do
        local shown = holder.GetShownBar and holder:GetShownBar()
        if shown and shown.isExpBar then return holder end
    end
    if MainMenuExpBar then return MainMenuExpBar end
    for _, holder in pairs({MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer, StatusTrackingBarManager}) do
        for _, child in ipairs({holder:GetChildren()}) do
            if child.isExpBar then return child end
        end
    end
end

local function hideNativeBar(hide)
    local frame = hide and nativeExperienceBar() or nil
    if frame then
        local system = frame.Selection and frame or frame:GetParent()
        module:SuppressEditSelection(system, function()
            if not options or not bar:IsShown() then return false end
            local current = nativeExperienceBar()
            return current == system or (current and current:GetParent() == system)
        end)
    end
    if nativeBar and frame ~= nativeBar then
        local previous = nativeBar
        nativeBar = nil
        previous:SetAlpha(nativeAlpha)
        for region, state in pairs(nativeInput) do
            region:EnableMouse(state[1])
            if state[2] ~= nil then region:SetMouseClickEnabled(state[2]) end
            if state[3] ~= nil then region:SetMouseMotionEnabled(state[3]) end
        end
        wipe(nativeInput)
    end
    if frame and not (frame.IsForbidden and frame:IsForbidden()) then
        if frame ~= nativeBar then nativeBar, nativeAlpha = frame, frame:GetAlpha() end
        if not alphaHooks[frame] then
            alphaHooks[frame] = true
            hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                if self ~= nativeBar or alpha <= 0 then return end
                nativeAlpha = alpha
                if not InCombatLockdown() and nativeExperienceBar() == self then
                    self:SetAlpha(0)
                end
            end)
        end
        if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
        local function disableInput(region)
            if not nativeInput[region] then
                nativeInput[region] = {region:IsMouseEnabled(),
                    region.IsMouseClickEnabled and region:IsMouseClickEnabled(),
                    region.IsMouseMotionEnabled and region:IsMouseMotionEnabled()}
            end
            region:EnableMouse(false)
            if region.SetMouseClickEnabled then region:SetMouseClickEnabled(false) end
            if region.SetMouseMotionEnabled then region:SetMouseMotionEnabled(false) end
            for _, child in ipairs({region:GetChildren()}) do disableInput(child) end
        end
        disableInput(frame)
        local owner = GameTooltip and GameTooltip:GetOwner()
        if owner and nativeInput[owner] then GameTooltip:Hide() end
    end
end

local function refreshNativeBar()
    if options and bar:IsShown() and not InCombatLockdown() then hideNativeBar(true) end
end

local function watchBlizzardContainers()
    for _, holder in pairs({MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer}) do
        if not nativeHooks[holder] then
            nativeHooks[holder] = true
            holder:HookScript("OnShow", refreshNativeBar)
            if holder.ApplyPendingBarToShow then
                hooksecurefunc(holder, "ApplyPendingBarToShow", refreshNativeBar)
            end
            if holder.Layout then hooksecurefunc(holder, "Layout", refreshNativeBar) end
            if holder.FadeInAnimation then
                holder.FadeInAnimation:HookScript("OnPlay", refreshNativeBar)
                holder.FadeInAnimation:HookScript("OnFinished", refreshNativeBar)
            end
        end
    end
end

local nativeLoader = CreateFrame("Frame")
nativeLoader:RegisterEvent("ADDON_LOADED")
nativeLoader:SetScript("OnEvent", function(self, _, name)
    if name ~= "Blizzard_StatusTrackingBar" then return end
    self:UnregisterEvent("ADDON_LOADED")
    watchBlizzardContainers()
    refreshNativeBar()
end)

local function updateTooltip()
    local xp, total, rested = bar.currentXP, bar.totalXP, bar.restedXP
    GameTooltip:SetOwner(bar, "ANCHOR_TOP")
    GameTooltip:SetText(XP or "Experience")
    GameTooltip:AddLine(string.format("%s / %s (%.1f%%)", BreakUpLargeNumbers(xp), BreakUpLargeNumbers(total), xp / total * 100), 1, 1, 1)
    if rested > 0 then
        GameTooltip:AddLine(string.format("Rested XP: %s", BreakUpLargeNumbers(rested)), 0.54, 0.77, 1)
    end
    if bar.questXP > 0 then
        GameTooltip:AddLine(string.format("Ready to turn in: %s XP", BreakUpLargeNumbers(bar.questXP)), 0.84, 0.71, 0.42)
        if xp + bar.questXP >= total then GameTooltip:AddLine("Enough XP for the next level", 0.84, 0.71, 0.42) end
    end
    GameTooltip:Show()
end

local function paintFades(frame, total, progress, rested, quest, height, width)
    for _, fade in ipairs(frame.fades) do fade:Hide() end
    local nextFade = 0
    local unit = width / total
    local function boundary(start, split, finish, from, to, top, bottom, pastSplit)
        if from == to then return end
        local span = math.min(4, (split - start) * unit / 2, (finish - split) * unit / 2)
        if span <= 0 or bottom <= top then return end
        nextFade = nextFade + 1
        local fade = frame.fades[nextFade]
        fade:ClearAllPoints()
        fade:SetPoint("TOPLEFT", frame.fill, "TOPLEFT", split * unit - span, -height * top)
        fade:SetSize(span * (1 + (pastSplit or 1)), height * (bottom - top))
        fade:SetTexCoord(0, 1, top, bottom)
        local right = to == backgroundColor and CreateColor(to[1], to[2], to[3], frame.background:GetAlpha())
            or CreateColor(unpack(to))
        fade:SetGradient("HORIZONTAL", CreateColor(unpack(from)), right)
        fade:Show()
    end
    local function lane(firstEnd, firstColor, secondEnd, secondColor, top, bottom, splitLane)
        if firstEnd <= progress then
            boundary(0, progress, total, frame.earnedColor, backgroundColor, top, bottom)
            return
        end
        local startTop = splitLane and 0 or top
        local startBottom = splitLane and (bottom == 1 and 1 or 0) or bottom
        local pastSplit = splitLane and ((rested >= total or rested > quest) and 0 or 0.35) or nil
        boundary(0, progress, firstEnd, frame.earnedColor, firstColor, startTop, startBottom, pastSplit)
        if secondEnd > firstEnd then
            local endTop = splitLane and (top == 0 and 0 or 1) or top
            local endBottom = bottom
            if splitLane then
                local fraction = (firstEnd - progress) / (secondEnd - progress)
                endBottom = top == 0 and (restedSeamTop + (restedSeamBottom - restedSeamTop) * fraction) or 1
            end
            boundary(progress, firstEnd, secondEnd, firstColor, secondColor, endTop, endBottom)
            if not splitLane or secondColor ~= restedPreviewColor then
                boundary(firstEnd, secondEnd, total, secondColor, backgroundColor, top, bottom)
            end
        elseif not (splitLane and firstEnd == rested and firstColor == restedPreviewColor) then
            boundary(progress, firstEnd, total, firstColor, backgroundColor, top, bottom)
        end
    end
    if rested > progress and quest > progress then
        lane(quest, questColor, rested, backgroundColor, 0, 0.5, true)
        lane(rested, restedPreviewColor, quest, questColor, 0.5, 1, true)
    elseif rested > progress then
        lane(rested, restedPreviewColor, rested, restedPreviewColor, 0, 1)
    else
        lane(quest, questColor, quest, questColor, 0, 1)
    end
end

local function paintFill(frame, total, progress, rested, quest, height, width)
    frame.progress:SetMinMaxValues(0, total)
    frame.progress:SetValue(progress)
    if frame.quest then
        frame.rested:SetMinMaxValues(0, total)
        frame.rested:SetValue(rested)
        frame.rested:SetShown(rested > progress and quest <= progress)
        frame.quest:SetHeight(height)
        frame.quest:SetMinMaxValues(0, total)
        frame.quest:SetValue(quest)
        frame.quest:SetShown(quest > progress)
        local split = progress / total * width
        local overlap = (math.min(rested, quest) - progress) / total * width
        frame.restedOverlap:SetShown(overlap > 0)
        if overlap > 0 then
            frame.restedOverlap:ClearAllPoints()
            frame.restedOverlap:SetPoint("BOTTOMLEFT", frame.fill, "BOTTOMLEFT", split, 0)
            local restedWidth = (rested - progress) / total * width
            frame.restedOverlap:SetSize(restedWidth, height)
            local mask = frame.restedOverlapMask
            mask:ClearAllPoints()
            mask:SetPoint("BOTTOMLEFT", frame.fill, "BOTTOMLEFT", split, 0)
            mask:SetSize(restedWidth, height)
        end
        paintFades(frame, total, progress, rested, quest, height, width)
    end
end

local function update(_, event)
    if not options then return end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" then
        questXP = nil
    end
    local total = UnitXPMax("player")
    if not total or total <= 0 or (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel())
        or (IsXPUserDisabled and IsXPUserDisabled()) then
        if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end
        bar:Hide()
        if not InCombatLockdown() then hideNativeBar(false) end
        return
    end
    local xp = math.min(UnitXP("player") or 0, total)
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    local questPercentMode = options.showText and options.textMode == "questPercent"
    local completed = (options.showQuestXP or questPercentMode) and completedQuestXP() or 0
    bar.currentXP, bar.totalXP, bar.restedXP = xp, total, rested
    bar.questXP = completed
    local color = rested > 0 and restedColor or xpColor
    if bar.earnedColor ~= color then
        bar.progress:SetStatusBarColor(unpack(color))
        bar.earnedColor = color
    end
    local restedEnd = options.showRested and math.min(xp + rested, total) or xp
    local questEnd = options.showQuestXP and math.min(xp + completed, total) or xp
    local fillHeight = math.max(1, options.height - 2 * fillInset)
    paintFill(bar, total, xp, restedEnd, questEnd, fillHeight, options.width - 2 * fillInset)
    if options.showText then
        local mode = options.textMode
        local caption
        if mode == "questPercent" then
            caption = string.format("%.1f%% |cffd6b56b(%.1f%%)|r", xp / total * 100, (xp + completed) / total * 100)
        elseif mode == "percent" then
            caption = string.format("%.1f%%", xp / total * 100)
        elseif mode == "remaining" then
            caption = string.format("%s XP to level", BreakUpLargeNumbers(total - xp))
        elseif mode == "progress" then
            caption = string.format("%s / %s", BreakUpLargeNumbers(xp), BreakUpLargeNumbers(total))
        else
            caption = string.format("%s / %s  (%.1f%%)", BreakUpLargeNumbers(xp), BreakUpLargeNumbers(total), xp / total * 100)
        end
        if mode ~= "questPercent" and options.showQuestText and completed > 0 then
            caption = caption .. "  |cffd6b56b+" .. BreakUpLargeNumbers(completed) .. " quest XP"
            if xp + completed >= total then caption = caption .. " (Level up)" end
            caption = caption .. "|r"
        end
        bar.text:SetText(caption)
    end
    bar:Show()
    if not InCombatLockdown() then hideNativeBar(true) end
    if GameTooltip:IsOwned(bar) then updateTooltip() end
end

local function createFill(frame, content, isReputation)
    local background = content:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(content)
    background:SetColorTexture(backgroundColor[1], backgroundColor[2], backgroundColor[3], 0.97)
    frame.background = background

    if not isReputation then
        frame.rested = CreateFrame("StatusBar", nil, content)
        frame.rested:SetAllPoints(content)
        frame.rested:SetStatusBarTexture(xpFill)
        frame.rested:SetStatusBarColor(unpack(restedPreviewColor))
        frame.quest = CreateFrame("StatusBar", nil, content)
        frame.quest:SetPoint("TOPLEFT")
        frame.quest:SetPoint("TOPRIGHT")
        frame.quest:SetFrameLevel(frame.rested:GetFrameLevel() + 1)
        frame.quest:SetStatusBarTexture(xpFill)
        frame.quest:SetStatusBarColor(unpack(questColor))
    end
    frame.progress = CreateFrame("StatusBar", nil, content)
    frame.progress:SetAllPoints(content)
    frame.progress:SetFrameLevel(content:GetFrameLevel() + 3)
    frame.progress:SetStatusBarTexture(isReputation and gradient or xpFill)
    if isReputation then
        frame.progress:SetStatusBarColor(0.38, 0.58, 0.31)
    end
end

local function createBar(isReputation)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:EnableMouse(true)
    local fill = CreateFrame("Frame", nil, frame)
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", fillInset, -fillInset)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -fillInset, fillInset)
    frame.fill = fill

    createFill(frame, fill, isReputation)

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 10)
    border:SetBackdrop({edgeFile=edge, edgeSize=12})
    BaziUI.Theme:AddDropShadow("ActionBars", frame, border)
    if isReputation then border:SetBackdropBorderColor(0.90, 0.72, 0.42, 1)
    else border:SetBackdropBorderColor(0.62, 0.49, 0.30, 1) end
    local dividerLayer = CreateFrame("Frame", nil, fill)
    dividerLayer:SetAllPoints(fill)
    dividerLayer:SetFrameLevel(frame.progress:GetFrameLevel() + 1)
    frame.dividerLayer = dividerLayer
    frame.dividers = {}
    for index = 1, 19 do
        local divider = dividerLayer:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(0, 0, 0, 1)
        divider:SetWidth(1)
        if divider.SetSnapToPixelGrid then divider:SetSnapToPixelGrid(false) end
        if divider.SetTexelSnappingBias then divider:SetTexelSnappingBias(0) end
        frame.dividers[index] = divider
    end
    if not isReputation then
        local overlap = dividerLayer:CreateTexture(nil, "BACKGROUND")
        overlap:SetTexture(xpFill)
        overlap:SetVertexColor(unpack(restedPreviewColor))
        overlap:Hide()
        frame.restedOverlap = overlap
        local mask = dividerLayer:CreateMaskTexture()
        mask:SetTexture(restedMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        overlap:AddMaskTexture(mask)
        frame.restedOverlapMask = mask
        frame.fades = {}
        for index = 1, 6 do
            local fade = dividerLayer:CreateTexture(nil, "BORDER")
            fade:SetTexture(xpFill)
            fade:Hide()
            frame.fades[index] = fade
        end
    end
    frame.text = border:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("CENTER")
    frame.text:SetPoint("LEFT", border, "LEFT", 5, 0)
    frame.text:SetPoint("RIGHT", border, "RIGHT", -5, 0)
    frame.text:SetWordWrap(false)

    if not isReputation then
        frame:SetScript("OnEvent", update)
        frame:SetScript("OnEnter", updateTooltip)
    end
    frame:SetScript("OnLeave", function()
        if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    end)
    return frame
end

local function layout(frame, settings, y)
    frame:SetSize(settings.width, settings.height)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.x, y)
    for _, divider in ipairs(frame.dividers) do divider:SetShown(settings.segmented) end
    if settings.segmented then
        local width = settings.width - 2 * fillInset
        local left = frame:GetLeft()
        left = left and left + fillInset or 0
        local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor
            and PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale() or 1
        for index, divider in ipairs(frame.dividers) do
            local x = math.floor((left + width * index / 20) / pixel + 0.5) * pixel - left
            divider:ClearAllPoints()
            divider:SetWidth(pixel)
            divider:SetPoint("TOPLEFT", frame.fill, "TOPLEFT", x, 0)
            divider:SetPoint("BOTTOMLEFT", frame.fill, "BOTTOMLEFT", x, 0)
        end
    end
    local font = fonts[settings.font] or GameFontNormal:GetFont()
    BaziUI.Typography.Apply(frame.text, "ActionBars:Experience", font, settings.textSize, "OUTLINE", settings.font == "general")
    frame.text:SetShown(settings.showText)
    frame.background:SetAlpha(math.max(0, math.min(100, tonumber(settings.opacity) or 100)) / 100)
end

local function updateReputation(frame)
    local name, standing, low, high, value
    local data = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if data then
        name, standing = data.name, data.reaction
        low, high, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
    elseif GetWatchedFactionInfo then
        name, standing, low, high, value = GetWatchedFactionInfo()
    end
    if not name or not low or not high or not value then
        if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        frame:Hide()
        return
    end
    local full = high <= low or standing == 8 and value >= high
    local total = math.max(1, high - low)
    local progress = full and total or math.max(0, math.min(total, value - low))
    paintFill(frame, total, progress)
    local reaction = standing and _G["FACTION_STANDING_LABEL" .. standing]
    local caption = full and (reaction or "Max reputation")
        or string.format("%s / %s (%.1f%%)", BreakUpLargeNumbers(progress), BreakUpLargeNumbers(total), progress / total * 100)
    frame.factionName, frame.factionProgress = name, caption
    frame.text:SetFormattedText("%s  ·  %s", name, caption)
    frame:Show()
    if GameTooltip:IsOwned(frame) then frame:GetScript("OnEnter")(frame) end
end

local function applyReputation(settings)
    if not settings.showReputation then
        if reputationBar then
            reputationBar:UnregisterAllEvents()
            if GameTooltip:IsOwned(reputationBar) then GameTooltip:Hide() end
            reputationBar:Hide()
        end
        return
    end
    if not reputationBar then
        reputationBar = createBar(true)
        reputationBar:SetScript("OnEvent", updateReputation)
        reputationBar:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_TOP")
            GameTooltip:SetText(frame.factionName)
            GameTooltip:AddLine(frame.factionProgress, 1, 1, 1)
            GameTooltip:Show()
        end)
    end
    reputationBar:RegisterEvent("UPDATE_FACTION")
    reputationBar:RegisterEvent("PLAYER_ENTERING_WORLD")
    layout(reputationBar, settings, settings.reputationY)
    updateReputation(reputationBar)
end

function module:ApplyExperience(settings)
    applyReputation(settings)
    if not settings.enabled then
        if bar and options then
            options = nil
            bar:UnregisterAllEvents()
            if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end
            bar:Hide()
            hideNativeBar(false)
        end
        return
    end
    if not bar then bar = createBar() end
    if not options then
        for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP",
            "PLAYER_MAX_LEVEL_UPDATE", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "QUEST_LOG_UPDATE",
            "QUEST_TURNED_IN", "PLAYER_REGEN_ENABLED"}) do
            pcall(bar.RegisterEvent, bar, event)
        end
        questXP = nil
    end
    options = settings
    watchBlizzardContainers()
    layout(bar, settings, settings.y)
    update()
end
