local addon = BaziUI
local tracker = {}
addon.QuestTracker = tracker

local frame, header, title, headerArrow, accent, scroll, content, summary, limit
local border, body, itemScroll, itemContent
local rows = {}
local distanceTicker
local native = {}
local completedObjectiveColor = {0x83 / 255, 0xcf / 255, 0x83 / 255}
local objectiveColor = {0xe9 / 255, 0xdf / 255, 0xd0 / 255}

function tracker.Settings()
    local profile = addon.db.profile
    profile.questTracker = profile.questTracker or {}
    local db = profile.questTracker
    if db.skin == nil then db.skin = "Modern" end
    if db.opacity == nil then db.opacity = 85 end
    if db.backgroundOpacity == nil then db.backgroundOpacity = db.opacity end
    if db.accent == nil then db.accent = {0.83, 0.63, 0.30} end
    if db.border == nil then db.border = {unpack(addon.Theme.colors.frameBorder)} end
    if db.sort == nil then db.sort = "distance" end
    if db.showLevels == nil then db.showLevels = true end
    if db.showReadyCount == nil then db.showReadyCount = true end
    if db.showReadyXP == nil then db.showReadyXP = true end
    if db.groupZones == nil then db.groupZones = true end
    if db.progressBars == nil then db.progressBars = true end
    db.progressThickness = math.max(1, math.min(10, tonumber(db.progressThickness) or 2))
    if db.showItems == nil then db.showItems = true end
    if db.headerFont == nil then db.headerFont = "general" end
    if db.questFont == nil then db.questFont = "general" end
    if db.width == nil then db.width = 270 end
    if db.maxHeight == nil then db.maxHeight = 455 end
    if db.showTimers == nil then db.showTimers = true end
    db.timerWidth = db.timerWidth or 250
    db.timerHeight = db.timerHeight or 22
    db.timerOpacity = db.timerOpacity or 80
    return db
end

local function suppressNative(window)
    if not (window and window.GetAlpha) then return end
    if not native[window] then
        native[window] = {alpha = window:GetAlpha(), mouse = window.IsMouseEnabled and window:IsMouseEnabled()}
    end
    window:SetAlpha(0)
    if window.EnableMouse then window:EnableMouse(false) end
end

local function syncNative(owned)
    if not owned then
        for window, state in pairs(native) do
            window:SetAlpha(state.alpha)
            if window.EnableMouse then window:EnableMouse(state.mouse) end
            native[window] = nil
        end
        return
    end
    suppressNative(_G.QuestObjectiveTracker)
    suppressNative(_G.CampaignQuestObjectiveTracker)
    if C_QuestLog and C_QuestLog.GetTimeAllowed then suppressNative(_G.QuestTimerFrame) end
    local original = _G.ObjectiveTrackerFrame
    if original then
        suppressNative(original.Header)
        suppressNative(original.HeaderMenu)
        suppressNative(original.Selection)
    end
end

local function relativePosition(growUp, x, y, width)
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local right = x + width / 2 > screenWidth / 2
    local top = y > screenHeight / 2
    local side = right and "RIGHT" or "LEFT"
    local anchor = (growUp and "BOTTOM" or "TOP") .. side
    local relative = (top and "TOP" or "BOTTOM") .. side
    return {anchor, relative, right and math.min(0, x + width - screenWidth) or math.max(0, x),
        top and y - screenHeight or y}
end

function tracker.PortablePosition(db)
    local position = db.position
    if position and (position[1] == "BOTTOMLEFT" or position[1] == "TOPLEFT") and position[2] == "BOTTOMLEFT" then
        return relativePosition(position[1] == "BOTTOMLEFT", position[3], position[4], db.width or 270)
    end
    return position
end

local function applyPosition(db)
    frame:ClearAllPoints()
    local position = tracker.PortablePosition(db)
    if position then
        frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -35, -192)
    end
end

local function openQuest(questID)
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questID)
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

local positionDirty
function tracker.GetPosition()
    local db = tracker.Settings()
    local position = tracker.PortablePosition(db)
    local height = frame and frame:GetHeight() or 35
    if not position then
        return UIParent:GetWidth() - db.width - 35, UIParent:GetHeight() - 192 - (db.growUp and height or 0)
    end
    local anchor, relative, x, y = unpack(position)
    local function offset(point, first, last, size)
        if point:find(first, 1, true) then return 0 end
        if point:find(last, 1, true) then return size end
        return size / 2
    end
    local left = x + offset(relative, "LEFT", "RIGHT", UIParent:GetWidth())
        - offset(anchor, "LEFT", "RIGHT", db.width)
    local bottom = y + offset(relative, "BOTTOM", "TOP", UIParent:GetHeight())
        - offset(anchor, "BOTTOM", "TOP", height)
    return left, db.growUp and bottom or bottom + height
end

function tracker.SetPosition(axis, value)
    local x, y = tracker.GetPosition()
    if axis == "x" then x = value else y = value end
    tracker.SetCoordinates(x, y)
end

function tracker.SetCoordinates(x, y)
    local db = tracker.Settings()
    db.position = relativePosition(db.growUp, x, y, db.width)
    tracker.RefreshPosition()
end

function tracker.RefreshPosition()
    positionDirty = true
    tracker.Refresh()
    if tracker.OnPositionChanged then tracker.OnPositionChanged() end
end

local function build()
    frame = CreateFrame("Frame", "BaziUIQuestTracker", UIParent)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -35, -192)
    frame:SetSize(300, 35)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:Hide()
    body = frame:CreateTexture(nil, "BACKGROUND")
    border = addon.Theme:CreateFrameBorder(frame, frame, frame)
    addon.Theme:AddDropShadow("Quest", frame, border)

    header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 3, -3)
    header:SetPoint("TOPRIGHT", -3, -3)
    header:SetHeight(29)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnClick", function()
        local db = tracker.Settings()
        db.collapsed = not db.collapsed
        tracker.Refresh()
    end)
    header:SetScript("OnEnter", function(self)
        if not tracker.Settings().currentRegionOnly or not self.trackedQuests or self.shownQuests == self.trackedQuests then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Only quests in the current region")
        GameTooltip:AddLine(("%d shown here · %d tracked in total"):format(self.shownQuests, self.trackedQuests), 1, 1, 1)
        GameTooltip:AddLine("Change the region filter in Bazi UI / Quest / Tracking.", 0.78, 0.72, 0.62)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    header:SetScript("OnDragStart", function()
        if not tracker.Settings().locked then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local db = tracker.Settings()
        local x = frame:GetLeft()
        local y = db.growUp and frame:GetBottom() or frame:GetTop()
        if x and y then
            db.position = relativePosition(db.growUp, x, y, db.width)
            applyPosition(db)
            if tracker.OnPositionChanged then tracker.OnPositionChanged() end
        end
    end)
    header.fill = header:CreateTexture(nil, "BACKGROUND")
    header.fill:SetAllPoints()
    title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    headerArrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerArrow:SetPoint("LEFT", title, "RIGHT", 7, 0)
    summary = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", headerArrow, "RIGHT", 7, 0)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(false)
    limit = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    limit:SetPoint("RIGHT", -8, 0)
    summary:SetPoint("RIGHT", limit, "LEFT", -7, 0)
    accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 2, -4)
    accent:SetPoint("BOTTOMLEFT", 2, 4)
    accent:SetWidth(3)

    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 11, -39)
    scroll:SetPoint("BOTTOMRIGHT", -11, 9)
    scroll:SetClipsChildren(true)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 35)))
    end)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(278, 1)
    scroll:SetScrollChild(content)
    itemScroll = CreateFrame("ScrollFrame", nil, frame)
    itemScroll:SetWidth(22)
    itemScroll:SetClipsChildren(true)
    itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetSize(22, 1)
    itemScroll:SetScrollChild(itemContent)
    scroll:HookScript("OnVerticalScroll", function(_, offset) itemScroll:SetVerticalScroll(offset) end)
end

local function getRow(index)
    local row = rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, content)
    row:SetScript("OnClick", function(self) openQuest(self.questID) end)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(0.42, 0.25, 0.17, 0.24)
    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetPoint("BOTTOMLEFT", 1, 1)
    row.divider:SetPoint("BOTTOMRIGHT", -1, 1)
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(0.90, 0.84, 0.73, 0.24)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zone:SetPoint("TOPLEFT", 1, -1)
    row.zoneCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zoneCount:SetPoint("TOPRIGHT", -2, -1)
    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.levelFill = row:CreateTexture(nil, "ARTWORK")
    row.levelFill:SetPoint("TOPLEFT", row.level, "TOPLEFT", 0, 2)
    row.levelFill:SetPoint("BOTTOMRIGHT", row.level, "BOTTOMRIGHT", 0, -2)
    row.level:SetTextColor(0.05, 0.04, 0.035)
    row.name:SetPoint("TOPLEFT")
    row.name:SetPoint("TOPRIGHT")
    row.name:SetJustifyH("LEFT")
    rows[index] = row
    return row
end

local function watchedQuests()
    local result = {}
    local q = C_QuestLog
    if not q then return result end
    if q.GetNumQuestWatches and q.GetQuestIDForQuestWatchIndex then
        for i = 1, q.GetNumQuestWatches() do
            local id = q.GetQuestIDForQuestWatchIndex(i)
            if id then result[#result + 1] = id end
        end
    elseif q.GetNumQuestLogEntries and q.GetInfo and q.GetQuestWatchType then
        for i = 1, q.GetNumQuestLogEntries() do
            local info = q.GetInfo(i)
            if info and not info.isHeader and info.questID and q.GetQuestWatchType(info.questID) then
                result[#result + 1] = info.questID
            end
        end
    end
    return result
end

local function questLogEntries()
    local q, entries, zone = C_QuestLog, {}, nil
    if not (q and q.GetInfo and q.GetNumQuestLogEntries) then return entries end
    for i = 1, q.GetNumQuestLogEntries() do
        local info = q.GetInfo(i)
        if info then
            if info.isHeader then zone = info.title
            elseif info.questID then entries[info.questID] = {info = info, zone = zone, index = i} end
        end
    end
    return entries
end

local function readableNumber(value)
    return (not canaccessvalue or canaccessvalue(value)) and type(value) == "number"
end

local function currentRegion()
    local names, quests = {}, {}
    local function addName(name)
        if type(name) == "string" and name ~= "" then names[name] = true end
    end
    addName(GetRealZoneText())
    if GetZoneText then addName(GetZoneText()) end
    if GetSubZoneText then addName(GetSubZoneText()) end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return names, quests end
    local mapID = C_Map.GetBestMapForUnit("player")
    local map = mapID and C_Map.GetMapInfo(mapID)
    local zone = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    while map and readableNumber(map.mapType) and map.mapType >= zone do
        addName(map.name)
        if C_QuestLog and C_QuestLog.GetQuestsOnMap then
            for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
                if readableNumber(poi.questID) then quests[poi.questID] = true end
            end
        end
        if map.mapType == zone or not map.parentMapID or map.parentMapID == mapID then break end
        mapID = map.parentMapID
        map = C_Map.GetMapInfo(mapID)
    end
    return names, quests
end

function tracker.DashboardQuests()
    local names, mapped = currentRegion()
    local entries, watched = questLogEntries(), {}
    for _, id in ipairs(watchedQuests()) do watched[id] = true end
    return entries, names, mapped, watched
end

tracker.OpenQuest = openQuest

local function questDistance(id)
    if C_QuestLog.GetDistanceSqToQuest then
        local squared, sameContinent = C_QuestLog.GetDistanceSqToQuest(id)
        if (not canaccessvalue or canaccessvalue(sameContinent)) and sameContinent ~= false
            and readableNumber(squared) and squared >= 0 then return squared end
    end
    return math.huge
end

local function objectiveRow(row, index)
    row.details = row.details or {}
    local detail = row.details[index]
    if detail then return detail end
    detail = CreateFrame("Frame", nil, row)
    detail:SetHeight(17)
    detail.text = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.text:SetPoint("TOPLEFT")
    detail.text:SetPoint("TOPRIGHT", -38, 0)
    detail.text:SetJustifyH("LEFT")
    detail.count = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.count:SetPoint("TOPRIGHT")
    detail.check = detail:CreateTexture(nil, "OVERLAY")
    detail.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    detail.check:SetDesaturated(true)
    detail.check:SetVertexColor(unpack(completedObjectiveColor))
    detail.check:SetPoint("TOPRIGHT", 0, 2)
    detail.check:SetSize(16, 16)
    detail.bar = CreateFrame("StatusBar", nil, detail)
    detail.bar:SetPoint("BOTTOMLEFT")
    detail.bar:SetPoint("BOTTOMRIGHT")
    detail.bar:SetHeight(2)
    detail.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local track = detail.bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.15)
    row.details[index] = detail
    return detail
end

local fontFiles = {
    FRIZQT = "Fonts\\FRIZQT__.TTF",
    ARIAL = "Fonts\\ARIALN.TTF",
    MORPHEUS = "Fonts\\MORPHEUS.TTF",
}

local function applyFont(region, key, size, flags, part)
    local profile = addon.db.profile
    local selected = key == "general" and profile.font or key
    local global = selected and _G[selected]
    local path = fontFiles[selected] or (global and global.GetFont and global:GetFont()) or GameFontNormal:GetFont()
    addon.Typography.Apply(region, "Quest:" .. (part or "Objectives"), path,
        size and size > 0 and size or addon.Typography.BaseSize(), flags, key == "general")
end

local timerFrame, timerTicker, timerPreview
local timerRows, timedQuests = {}, {}

local function remainingTime(id)
    local total, elapsed = C_QuestLog.GetTimeAllowed(id)
    if readableNumber(total) and readableNumber(elapsed) and total > 0 and elapsed < total then
        return total - elapsed, total
    end
end

local function makeTimerFrame()
    local window = CreateFrame("Frame", "BaziUIQuestTimers", UIParent)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = nil
        local db = tracker.Settings()
        local x, y = self:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if x and y and cx and cy then
            db.timerX, db.timerY = math.floor(x - cx + 0.5), math.floor(y - cy + 0.5)
        end
    end)
    window.fill = window:CreateTexture(nil, "BACKGROUND")
    window.fill:SetAllPoints()
    window.heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.heading:SetPoint("TOPLEFT", 9, -6)
    window.heading:SetText("Quest timers")
    window.border = addon.Theme:CreateFrameBorder(window, window, window)
    addon.Theme:AddDropShadow("Quest", window, window.border)
    return window
end

local function timerRow(index)
    if timerRows[index] then return timerRows[index] end
    local row = CreateFrame("StatusBar", nil, timerFrame)
    row:SetStatusBarTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziHealthGradientRight.tga")
    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetAllPoints()
    row.fill:SetColorTexture(0, 0, 0, 0.48)
    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.time:SetPoint("RIGHT", -5, 0)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetPoint("LEFT", 5, 0)
    row.title:SetPoint("RIGHT", row.time, "LEFT", -5, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    timerRows[index] = row
    return row
end

local function updateTimers()
    local db = tracker.Settings()
    local count = 0
    local function show(name, left, total)
        count = count + 1
        timerFrame = timerFrame or makeTimerFrame()
        local row = timerRow(count)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", timerFrame, "TOPLEFT", 5, -26 - (count - 1) * (db.timerHeight + 3))
        row:SetPoint("TOPRIGHT", timerFrame, "TOPRIGHT", -5, -26 - (count - 1) * (db.timerHeight + 3))
        row:SetHeight(db.timerHeight)
        row:SetMinMaxValues(0, total)
        row:SetValue(left)
        row:SetStatusBarColor(unpack(db.accent))
        applyFont(row.title, db.questFont, db.questSize, "OUTLINE")
        applyFont(row.time, db.questFont, db.questSize, "OUTLINE")
        row.title:SetText(name)
        local seconds = math.ceil(left)
        row.time:SetFormattedText("%d:%02d", math.floor(seconds / 60), seconds % 60)
        row:Show()
    end
    if db.enabled and db.showTimers then
        for _, quest in ipairs(timedQuests) do
            local left, total = remainingTime(quest.id)
            if left then show(quest.name, left, total) end
        end
    end
    local running = count > 0
    if timerPreview and not running then show("Timed quest preview", 78, 120) end
    if timerTicker and not running then timerTicker:Cancel(); timerTicker = nil end
    if not timerFrame then return end
    for i = count + 1, #timerRows do timerRows[i]:Hide() end
    if count == 0 then timerFrame:Hide(); return end
    applyFont(timerFrame.heading, db.headerFont, db.headerSize, "OUTLINE", "Header")
    timerFrame.heading:SetTextColor(addon.Headers.Text("quest", 1, 0.82, 0.49))
    timerFrame.fill:SetColorTexture(0.075, 0.062, 0.047, db.timerOpacity / 100)
    timerFrame.border:SetBackdropBorderColor(unpack(db.border))
    timerFrame:SetSize(db.timerWidth, 29 + count * (db.timerHeight + 3))
    timerFrame:Show()
    return running
end

function tracker.RefreshTimers()
    if not addon.db then return end
    local db = tracker.Settings()
    timedQuests = {}
    if db.enabled and db.showTimers and C_QuestLog and C_QuestLog.GetTimeAllowed then
        for id, entry in pairs(questLogEntries()) do
            if remainingTime(id) then timedQuests[#timedQuests + 1] = {id = id, name = entry.info.title, index = entry.index} end
        end
        table.sort(timedQuests, function(a, b) return a.index < b.index end)
    end
    local running = updateTimers()
    if timerFrame and timerFrame:IsShown() and not timerFrame.dragging then
        timerFrame:ClearAllPoints()
        timerFrame:SetPoint("CENTER", UIParent, "CENTER", db.timerX or 320, db.timerY or 145)
    end
    if running and not timerTicker then timerTicker = C_Timer.NewTicker(0.5, updateTimers) end
end

function tracker.ToggleTimerPreview(enabled)
    if enabled == nil then enabled = not timerPreview end
    timerPreview = enabled
    tracker.RefreshTimers()
    return timerPreview
end

function tracker.RefreshHeader()
    if not header then return end
    local db = tracker.Settings()
    local chat = addon.Chat
    local r, g, b, alpha = 0.15, 0.15, 0.19, db.skin == "Modern" and db.opacity / 200 or 0
    if db.matchChatHeader and chat and chat.active and chat.Skin and chat.Skin.DockHeaderColor then
        r, g, b, alpha = chat.Skin.DockHeaderColor()
    elseif db.headerColor then
        r, g, b, alpha = db.headerColor[1], db.headerColor[2], db.headerColor[3], db.opacity / 100
    end
    header.fill:SetColorTexture(addon.Headers.Fill("quest", r, g, b, alpha))
    local tr, tg, tb = addon.Headers.Text("quest", 1, 0.82, 0.49)
    title:SetTextColor(tr, tg, tb)
    limit:SetTextColor(tr, tg, tb)
    headerArrow:SetTextColor(tr, tg, tb)
    local caption = summary:GetText() or ""
    if caption ~= "" then
        caption = caption:gsub("^|cff83cf83(.*)|r$", "%1")
        local color = addon.Headers.Get("quest", "text")
        summary:SetText(color and caption or ("|cff83cf83" .. caption .. "|r"))
        summary:SetTextColor(tr, tg, tb)
    end
end

local itemButtonsCreated
local function applyQuestItem(row, record, offset)
    local item = row.item
    if record.itemLink then
        if not item then
            item = CreateFrame("Button", nil, itemContent, "SecureActionButtonTemplate")
            item:RegisterForClicks("AnyUp", "AnyDown")
            item:SetAttribute("type", "item")
            item:SetSize(22, 22)
            item.icon = item:CreateTexture(nil, "ARTWORK")
            item.icon:SetAllPoints()
            addon.Theme:CreateFrameBorder(item, item, item)
            item:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
            end)
            item:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
            row.item = item
            itemButtonsCreated = true
        end
        local id = record.itemLink:match("|Hitem:(%d+)")
        item:SetAttribute("item", id and ("item:" .. id) or record.itemLink)
        item.link = record.itemLink
        item.icon:SetTexture(record.itemIcon)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", itemContent, "TOPLEFT", 0, -offset)
        item:Show()
        return true
    end
    if item then item:Hide() end
    return false
end

local pendingRefresh
function tracker.Refresh()
    local db = tracker.Settings()
    tracker.RefreshTimers()
    if InCombatLockdown and InCombatLockdown() and (itemButtonsCreated or (db.enabled and db.showItems)) then
        pendingRefresh = true
        return
    end
    pendingRefresh = false
    if not db.enabled then
        if distanceTicker then distanceTicker:Cancel(); distanceTicker = nil end
        syncNative(false)
        if frame then frame:Hide() end
        return
    end

    if (db.sort == "distance" or db.showDistance) and not distanceTicker then
        distanceTicker = C_Timer.NewTicker(3, function()
            if frame and frame:IsShown() and not tracker.Settings().collapsed then tracker.Refresh() end
        end)
    elseif db.sort ~= "distance" and not db.showDistance and distanceTicker then
        distanceTicker:Cancel()
        distanceTicker = nil
    end
    if not frame then
        build()
        applyPosition(db)
        if db.position then frame.growUp = db.growUp end
    end

    if positionDirty then
        applyPosition(db)
        frame.growUp = db.growUp
        positionDirty = false
    end
    frame:SetWidth(db.width)
    content:SetWidth(db.width - 22)
    if frame.growUp ~= db.growUp then
        local left, bottom, top = frame:GetLeft(), frame:GetBottom(), frame:GetTop()
        if left and bottom and top then
            local y = db.growUp and bottom or top
            db.position = relativePosition(db.growUp, left, y, db.width)
            applyPosition(db)
            frame.growUp = db.growUp
            if tracker.OnPositionChanged then tracker.OnPositionChanged() end
        end
    end
    header:ClearAllPoints()
    scroll:ClearAllPoints()
    body:ClearAllPoints()
    if db.growUp then
        header:SetPoint("BOTTOMLEFT", 3, 3)
        header:SetPoint("BOTTOMRIGHT", -3, 3)
        scroll:SetPoint("TOPLEFT", 11, -9)
        scroll:SetPoint("BOTTOMRIGHT", -11, 39)
        body:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        body:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT", 1, 0)
    else
        header:SetPoint("TOPLEFT", 3, -3)
        header:SetPoint("TOPRIGHT", -3, -3)
        scroll:SetPoint("TOPLEFT", 11, -39)
        scroll:SetPoint("BOTTOMRIGHT", -11, 9)
        body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -1, 0)
        body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    end

    local modern, classic = db.skin == "Modern", db.skin == "Classic"
    local opacity = db.backgroundOpacity / 100
    if classic then
        body:SetColorTexture(0.16, 0.092, 0.045, opacity)
    else
        body:SetColorTexture(0.085, 0.085, 0.105, opacity)
    end
    border:SetBackdropBorderColor(unpack(db.border))
    border:SetShown(modern or classic)
    tracker.RefreshHeader()
    accent:SetColorTexture(db.accent[1], db.accent[2], db.accent[3], 1)
    accent:SetShown(not classic)
    local outline = modern and "OUTLINE" or ""
    applyFont(title, db.headerFont, db.headerSize, outline, "Header")
    applyFont(headerArrow, db.headerFont, db.headerSize, outline, "Header")
    applyFont(summary, db.headerFont, db.headerSize, outline, "Header")
    applyFont(limit, db.headerFont, db.headerSize, outline, "Header")

    local log, records, groups, order = questLogEntries(), {}, {}, {}
    local ready, xp = 0, 0
    local watched = watchedQuests()
    local regionNames, regionQuests
    if db.currentRegionOnly then regionNames, regionQuests = currentRegion() end
    for _, id in ipairs(watched) do
        local entry = log[id] or {}
        local info = entry.info or {}
        local name = info.title or (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id))
        if name and (not regionNames or regionNames[entry.zone] or regionQuests[id]) then
            local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
            local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id) or {}
            local progress = 0
            for _, objective in ipairs(objectives) do
                local current, maximum = objective.numFulfilled, objective.numRequired
                if objective.finished then progress = progress + 1
                elseif readableNumber(current) and readableNumber(maximum) and maximum > 0 then
                    progress = progress + math.min(1, current / maximum)
                end
            end
            local level = readableNumber(info.level) and info.level or 0
            local record = {id = id, name = name, level = level, done = not not done, index = #records + 1,
                objectives = objectives, progress = done and 1 or progress / math.max(1, #objectives),
                distance = (db.sort == "distance" or db.showDistance) and questDistance(id) or math.huge}
            if not (done and db.hideCompleted) then
                if db.showItems and GetQuestLogSpecialItemInfo then
                    local index = entry.index or (C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id))
                    if index then
                        local link, icon = GetQuestLogSpecialItemInfo(index)
                        if (not canaccessvalue or canaccessvalue(link)) and type(link) == "string" and icon then
                            record.itemLink, record.itemIcon = link, icon
                        end
                    end
                end
                records[#records + 1] = record
                local zone = modern and db.groupZones and (entry.zone or "Quests") or ""
                if not groups[zone] then groups[zone] = {}; order[#order + 1] = zone end
                table.insert(groups[zone], record)
            end
            if done then
                ready = ready + 1
                local reward = db.showReadyXP and GetQuestLogRewardXP and GetQuestLogRewardXP(id)
                if readableNumber(reward) then xp = xp + reward end
            end
        end
    end
    local function before(a, b)
        if db.readyFirst and a.done ~= b.done then return a.done end
        if db.sort == 'progress' and a.progress ~= b.progress then return a.progress > b.progress end
        if db.sort == 'level' and (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        if db.sort == "distance" and a.distance ~= b.distance then return a.distance < b.distance end
        return a.index < b.index
    end
    for _, group in pairs(groups) do table.sort(group, before) end
    table.sort(order, function(a, b) return before(groups[a][1], groups[b][1]) end)
    local y, used, hasItems = 0, 0, false
    for _, zone in ipairs(order) do
        for i, record in ipairs(groups[zone]) do
            used = used + 1
            local row = getRow(used)
            row.questID = record.id
            row:ClearAllPoints()
            row:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
            row:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, -y)
            local showZone = i == 1 and zone ~= ''
            row.zone:SetText(zone:upper())
            row.zoneCount:SetText(tostring(#groups[zone]))
            row.zone:SetShown(showZone)
            row.zoneCount:SetShown(showZone)
            local inset = showZone and 22 or 2
            local level = record.level
            local showLevel = db.showLevels and readableNumber(level) and level > 0
            local color = showLevel and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            local r, g, b = 1, 0.82, 0.46
            if color then
                r, g, b = color.r, color.g, color.b
            elseif showLevel and UnitLevel then
                local difference = level - UnitLevel("player")
                if difference >= 5 then r, g, b = 1, 0.28, 0.23
                elseif difference >= 3 then r, g, b = 1, 0.56, 0.22
                elseif difference >= -2 then r, g, b = 1, 0.90, 0.28
                elseif difference >= -6 then r, g, b = 0.40, 0.83, 0.38
                else r, g, b = 0.72, 0.72, 0.72 end
            end
            local item = applyQuestItem(row, record, y + inset)
            hasItems = hasItems or item
            local left, right = 1, -1
            row.divider:SetShown(used < #records)
            row.level:SetText(showLevel and tostring(level) or '')
            row.level:ClearAllPoints()
            row.level:SetPoint('TOPLEFT', left, -inset)
            row.level:SetShown(showLevel)
            row.levelFill:SetColorTexture(r, g, b, 1)
            row.levelFill:SetShown(showLevel)
            applyFont(row.name, db.questFont, db.questSize, outline)
            local badgeWidth, badgeHeight = 0, 0
            if showLevel then
                local font, size = row.name:GetFont()
                row.level:SetFont(font, size, "")
                badgeWidth = math.max(27, math.ceil(row.level:GetStringWidth()) + 8)
                badgeHeight = row.level:GetStringHeight() + 2
                row.level:SetWidth(badgeWidth)
            end
            row.name:ClearAllPoints()
            row.name:SetPoint('TOPLEFT', showLevel and left + badgeWidth + 5 or left, -inset)
            row.name:SetPoint('TOPRIGHT', right, -inset)
            local distance = db.showDistance and record.distance < math.huge
                and (' |cffb0adb6(%d yd)|r'):format(math.floor(math.sqrt(record.distance) + 0.5)) or ''
            row.name:SetText(record.name .. distance)
            row.name:SetTextColor(r, g, b)
            local height, detailCount = inset + math.max(row.name:GetStringHeight(), badgeHeight, item and 22 or 0) + 4, 0
            local objectives = record.objectives
            if record.done then objectives = {{text = 'Ready for turn-in', finished = true}} end
            for _, objective in ipairs(objectives or {}) do
                if type(objective.text) == 'string' and objective.text ~= '' then
                    detailCount = detailCount + 1
                    local detail = objectiveRow(row, detailCount)
                    local have, need = objective.numFulfilled, objective.numRequired
                    local counted = readableNumber(have) and readableNumber(need) and need > 0
                    local finished = objective.finished or counted and have >= need
                    local text = objective.text
                    if counted then
                        text = text:gsub('^%d+/%d+%s+', ''):gsub('%s*:%s*%d+/%d+$', '')
                    end
                    applyFont(detail.text, db.questFont, db.questSize, outline)
                    applyFont(detail.count, db.questFont, db.questSize, outline)
                    detail.text:SetTextColor(unpack(finished and completedObjectiveColor or objectiveColor))
                    detail.text:SetText(text)
                    detail.count:SetText(counted and not finished and (have .. '/' .. need) or '')
                    detail.check:SetShown(not not finished)
                    local bar = modern and db.progressBars and counted and not finished
                    detail.bar:SetShown(bar)
                    if bar then
                        detail.bar:SetHeight(db.progressThickness)
                        detail.bar:SetMinMaxValues(0, need)
                        detail.bar:SetValue(have)
                        detail.bar:SetStatusBarColor(db.accent[1], db.accent[2], db.accent[3])
                    end
                    detail:ClearAllPoints()
                    detail:SetPoint('TOPLEFT', row, 'TOPLEFT', 3, -height)
                    detail:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -2, -height)
                    local size = math.max(14, detail.text:GetStringHeight()) + (bar and db.progressThickness + 3 or 1)
                    detail:SetHeight(size)
                    detail:Show()
                    height = height + size
                end
            end
            for j = detailCount + 1, #(row.details or {}) do row.details[j]:Hide() end
            row:SetHeight(height + 5)
            row:Show()
            y = y + height + 5
        end
    end
    for i = used + 1, #rows do
        rows[i]:Hide()
        if rows[i].item then rows[i].item:Hide() end
    end
    local count = #records
    title:SetText("Quests")
    headerArrow:SetText(db.collapsed and "v" or "^")
    headerArrow:SetPoint("LEFT", title, "RIGHT", 7, db.collapsed and 0 or -3)
    local headerParts = {}
    if db.showReadyCount and ready > 0 then headerParts[#headerParts + 1] = ready .. " ready" end
    if db.showReadyXP and xp > 0 then headerParts[#headerParts + 1] = xp .. " XP" end
    local caption = table.concat(headerParts, "  ·  ")
    local textColor = addon.Headers.Get("quest", "text")
    summary:SetText(caption ~= "" and (textColor and caption or ("|cff83cf83" .. caption .. "|r")) or "")
    local cap = Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES
    header.shownQuests, header.trackedQuests = count, #watched
    limit:SetText(tostring(db.currentRegionOnly and count or #watched) .. (cap and ("/" .. cap) or ""))
    content:SetHeight(math.max(1, y))
    itemContent:SetHeight(math.max(1, y))
    local headerOnly = db.collapsed or (db.currentRegionOnly and count == 0)
    scroll:SetShown(not headerOnly)
    itemScroll:ClearAllPoints()
    local itemTop, itemBottom = db.growUp and -9 or -39, db.growUp and 39 or 9
    if db.itemsLeft then
        itemScroll:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, itemTop)
        itemScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -4, itemBottom)
    else
        itemScroll:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, itemTop)
        itemScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 4, itemBottom)
    end
    itemScroll:SetShown(not headerOnly and hasItems)
    body:SetShown(not headerOnly)
    frame:SetHeight(headerOnly and (header:GetHeight() + 6) or 48 + math.min(y, db.maxHeight))
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
    itemScroll:SetVerticalScroll(scroll:GetVerticalScroll())
    frame:SetShown(count > 0 or #watched > 0)
    syncNative(true)
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED"}) do
    events:RegisterEvent(event)
end
local queued, editLayoutChanged
local function requestRefresh(event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingRefresh then return end
    if event == "EDIT_MODE_LAYOUTS_UPDATED" then editLayoutChanged = true end
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        if not addon.db then return end
        tracker.Refresh()
        if editLayoutChanged and not pendingRefresh then
            editLayoutChanged = false
            if frame and tracker.Settings().enabled then applyPosition(tracker.Settings()) end
        end
    end)
end

events:SetScript("OnEvent", function(_, event) requestRefresh(event) end)
if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function() requestRefresh("EDIT_MODE_LAYOUTS_UPDATED") end, tracker)
    EventRegistry:RegisterCallback("EditMode.Exit", function() requestRefresh("EDIT_MODE_LAYOUTS_UPDATED") end, tracker)
end
