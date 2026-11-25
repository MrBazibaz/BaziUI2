local addon = BaziUI
local inventory = addon.Inventory
local D = {widgets = {}, byID = {}, modes = {
    {"automatic", "Automatic"}, {"always", "Always"}, {"activity", "On activity"},
    {"combat", "In combat"}, {"peace", "Out of combat"}, {"instance", "In instance"},
    {"pvp", "In battleground"}, {"mouseover", "Mouseover"}, {"hidden", "Hidden"},
}}
addon.Dashboard = D

local activityDuration = 20
local defaults = {
    enabled = false, x = 330, y = -5, width = 192, maxHeight = 385, scale = 100, opacity = 85,
    growUp = false, spacing = 5, maxWidgets = 8, context = true, locked = false, border = true,
    showHeader = true, headers = true, barHeight = 3, iconSize = 14, rowSpacing = 5, fontSize = 12,
    autoHide = true, combat = "always", completedDuration = activityDuration, hideMaxed = true, afk = true, fade = true,
    hideActivityChat = false,
    showQuestItems = false, questItemSide = "right",
}
local frame, header, title, viewport, scrollChild, scrollbar
local headerPlacement
local contentInset, cardInset = 7, 7
local cards, savedRows, pending, eventOwners = {}, {}, {}, {}
local active, preview, layoutMode, clock, lastConfig
local heightAnimation
local motionInCombat = false
local events = CreateFrame("Frame")

function D.Read(value)
    return not (issecretvalue and issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

function D.Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(fn, ...)
    if ok and D.Read(a) then return a, b, c, d, e, f, g, h, i, j, k, l, m, n end
end

function D.Settings()
    local profile = addon.db.profile
    profile.dashboard = profile.dashboard or {widgets = {}, thresholds = {}, status = {}}
    local cfg = profile.dashboard
    if lastConfig == cfg then return cfg end
    lastConfig = cfg
    cfg.widgets, cfg.thresholds, cfg.status = cfg.widgets or {}, cfg.thresholds or {}, cfg.status or {}
    if not cfg.activityDurationUpdated then
        local legacyDurations = {gathering = 120, recentActivity = 7}
        for id, options in pairs(cfg.widgets) do
            if options.duration == (legacyDurations[id] or 60) then options.duration = activityDuration end
        end
        if cfg.completedDuration == 15 then cfg.completedDuration = activityDuration end
        cfg.activityDurationUpdated = true
    end
    if not cfg.compactLayout then
        if cfg.width == 210 then cfg.width = defaults.width end
        cfg.compactLayout = true
    end
    for key, value in pairs(defaults) do if cfg[key] == nil then cfg[key] = value end end
    return cfg
end

local lastNotificationSound
function D.NotificationSettings(key)
    local cfg = D.Settings()
    cfg.notifications = cfg.notifications or {}
    if not cfg.notifications[key] then
        cfg.notifications[key] = {sound = key == "upgrade" and "alertRetroBonk" or "none", chat = false}
    end
    return cfg.notifications[key]
end

function D.Notify(key, message, delivered)
    local cfg = D.NotificationSettings(key)
    local now = GetTime()
    local alerts = addon.SmartAlerts
    if alerts and cfg.sound and cfg.sound ~= "none" and not (delivered and delivered.sound)
        and (not lastNotificationSound or now - lastNotificationSound >= 1.5) then
        alerts.PlaySound(cfg.sound)
        lastNotificationSound = now
    end
    if cfg.chat and not (delivered and delivered.chatWarning) then addon:Print(message) end
end

function D.Tracking()
    local db = addon.db
    db.dashboardCharacters = db.dashboardCharacters or {}
    local key = addon.Database:CharacterKey()
    if not key then return end
    local data = db.dashboardCharacters[key]
    if not data then
        data = {items = {}, goals = {}, quests = {}, skills = {}, professions = {}, factions = {}, supplies = {}, materials = {}}
        db.dashboardCharacters[key] = data
    end
    data.materials = data.materials or {}
    return data
end

function D.WidgetSettings(id)
    local settings = D.Settings().widgets
    local widget = D.byID[id]
    if not settings[id] then
        settings[id] = {enabled = true, mode = "automatic", duration = activityDuration,
            priority = widget.priority, order = widget.order, background = 85}
    end
    return settings[id]
end

function D.Register(widget)
    assert(not D.byID[widget.id], "Duplicate Dashboard widget ID")
    D.widgets[#D.widgets + 1] = widget
    D.byID[widget.id] = widget
    widget.order = #D.widgets
end

function D.Value(label, count, maximum, detail)
    return {label = label, value = maximum and ("%s / %s"):format(count, maximum) or tostring(count),
        progress = maximum and maximum > 0 and math.max(0, math.min(1, count / maximum)) or nil,
        done = maximum and maximum > 0 and count >= maximum or nil, tooltip = detail}
end

function D.Item(id)
    local name, link, _, _, _, _, _, _, _, icon, price, class, subclass = D.Call(inventory.GetItemInfo, id)
    return name or ("Item #%d"):format(id), icon, link, price, class, subclass
end

function D.Count(id)
    local count = D.Call(C_Item and C_Item.GetItemCount or GetItemCount, id)
    return type(count) == "number" and count or nil
end

local function rowClick(self, button)
    local row = self.data
    if not row or preview or layoutMode then return end
    if button == "RightButton" and row.pin then
        if not InCombatLockdown() then row.pin(); D.Invalidate(self.widget) end
    elseif row.click and not InCombatLockdown() then
        row.click()
    end
end

local function rowTooltip(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.link and not preview then GameTooltip:SetHyperlink(row.link) else GameTooltip:SetText(row.label) end
    if row.tooltip then GameTooltip:AddLine(row.tooltip, 0.9, 0.85, 0.74, true) end
    if row.pin and not preview then GameTooltip:AddLine("Right-click to toggle tracking", 0.68, 0.63, 0.57) end
    GameTooltip:Show()
end

local function makeRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", rowClick)
    row:SetScript("OnEnter", rowTooltip)
    row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT")
    row.label = inventory.Label(row)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.value = inventory.Label(row)
    row.value:SetPoint("TOPRIGHT")
    row.label:SetPoint("TOPRIGHT", row.value, "TOPLEFT", -7, 0)
    row.track = row:CreateTexture(nil, "BACKGROUND")
    row.track:SetPoint("BOTTOMLEFT")
    row.track:SetPoint("BOTTOMRIGHT")
    row.track:SetColorTexture(0.22, 0.19, 0.16, 0.9)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("BOTTOMLEFT")
    return row
end

local function makeCard(id)
    local card = addon.Theme:RoundedCard(scrollChild)
    card.title = inventory.Label(card)
    card.title:SetPoint("TOPLEFT", cardInset, -5)
    card.title:SetPoint("TOPRIGHT", -cardInset, -5)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.rows = {}
    cards[id] = card
    return card
end

local function setHeight(height)
    frame:SetHeight(height)
    viewport:UpdateScrollChildRect()
    scrollbar:SyncRange()
end

local function resizeHeight(target, animate, hide)
    local current = frame:GetHeight()
    if not animate or math.abs(current - target) < 0.5 then
        heightAnimation = nil
        if current ~= target then setHeight(target) end
        if hide then frame:Hide() end
        return
    end
    if heightAnimation and heightAnimation.target == target and heightAnimation.hide == hide then return end
    heightAnimation = {start = current, target = target, elapsed = 0, hide = hide}
end

local function makeFrame()
    frame, header, title = inventory.Window("BaziUIDashboard", "Dashboard", defaults.width, 38)
    frame:SetClampedToScreen(false)
    frame.headerStyleKey = "dashboard"
    frame:SetFrameStrata("MEDIUM")
    title:SetPoint("RIGHT", frame.closeButton, "LEFT", -4, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    frame.baziFade = frame:CreateAnimationGroup()
    local fade = frame.baziFade:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.35)
    fade:SetToAlpha(1)
    fade:SetDuration(0.16)
    fade:SetSmoothing("OUT")
    local setStyle = frame.ApplyStyle
    function frame:ApplyStyle()
        setStyle(self)
        local cfg = D.Settings()
        local typography = addon.Typography
        typography.Apply(title, "Dashboard:Title", typography.Path(addon.db.profile.font), typography.BaseSize(), "OUTLINE", true)
        self.border:SetShown(cfg.border)
    end
    scrollChild, viewport, scrollbar = inventory.Scroll(frame, -32, 6, "compact")
    viewport:SetClipsChildren(true)
    frame:SetScript("OnEnter", function() D.Render(true) end)
    frame:SetScript("OnLeave", function() C_Timer.After(0, function() D.Render(true) end) end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        local motion = heightAnimation
        if not motion or self.baziMoving == true or addon.Movers and addon.Movers.IsDragging(self) then return end
        motion.elapsed = motion.elapsed + elapsed
        local progress = math.min(1, motion.elapsed / 0.20)
        setHeight(motion.start + (motion.target - motion.start) * (1 - (1 - progress)^3))
        if progress == 1 then
            heightAnimation = nil
            if motion.hide then self:Hide() end
        end
    end)
    frame.closeButton:SetScript("OnClick", function()
        if preview then D.Preview(nil) else D.Settings().enabled = false; D.Refresh() end
    end)
    header:SetScript("OnDragStart", function()
        if D.Settings().locked or InCombatLockdown() then return end
        frame.baziMoving = true
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        if not frame.baziMoving then return end
        frame:StopMovingOrSizing()
        frame.baziMoving = nil
        if InCombatLockdown() then D.Render(); return end
        local cfg = D.Settings()
        local x = frame:GetLeft()
        local y = cfg.growUp and frame:GetBottom() or frame:GetTop()
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y then
            cfg.x, cfg.y = math.floor(x * ratio - UIParent:GetWidth() / 2 + 0.5),
                math.floor(y * ratio - UIParent:GetHeight() / 2 + 0.5)
            D.Render()
        end
    end)
    frame:HookScript("OnHide", function()
        heightAnimation = nil
        if frame.baziMoving then frame:StopMovingOrSizing(); frame.baziMoving = nil end
    end)
    return frame
end

local function sortedWidgets()
    local cfg = D.Settings()
    local result, mouseover = {}, false
    local _, zoneType = IsInInstance()
    local hovered = frame and frame:IsShown() and frame:IsMouseOver()
    for _, widget in ipairs(D.widgets) do
        local options = D.WidgetSettings(widget.id)
        local data
        if preview then data = D.PreviewData and D.PreviewData(preview, widget.id)
        else data = savedRows[widget.id] end
        local mode = options.mode
        if data and (#data.rows > 0 or data.questItems) and (preview or options.enabled and mode ~= "hidden") then
            if not preview and mode == "mouseover" then mouseover = true end
            local contextual = data.active or not cfg.context or not cfg.autoHide
            local matches = preview or options.pinned or mode == "always"
                or mode == "automatic" and contextual or mode == "activity" and data.activity
                or mode == "combat" and motionInCombat or mode == "peace" and not motionInCombat
                or mode == "instance" and (zoneType == "party" or zoneType == "raid")
                or mode == "pvp" and (zoneType == "pvp" or zoneType == "arena")
                or mode == "mouseover" and hovered
            if matches then result[#result + 1] = {widget = widget, options = options, data = data} end
        end
    end
    table.sort(result, function(a, b)
        local aLocal = a.widget.id == "quests"
        local bLocal = b.widget.id == "quests"
        if aLocal ~= bLocal then return aLocal end
        if not not a.options.pinned ~= not not b.options.pinned then return not not a.options.pinned end
        if a.options.priority ~= b.options.priority then return a.options.priority > b.options.priority end
        if a.options.order ~= b.options.order then return a.options.order < b.options.order end
        return a.widget.order < b.widget.order
    end)
    if not preview then
        local recent, gatheringIndex
        for index, entry in ipairs(result) do
            if index > cfg.maxWidgets then break end
            if entry.widget.id == "recentActivity" then recent = entry.data.rows end
            if entry.widget.id == "gathering" then gatheringIndex = index end
        end
        if recent and gatheringIndex then
            local looted, rows = {}, {}
            for _, row in ipairs(recent) do if row.itemID then looted[row.itemID] = true end end
            local entry = result[gatheringIndex]
            for _, row in ipairs(entry.data.rows) do
                if not looted[row.itemID] then rows[#rows + 1] = row end
            end
            if #rows == 0 then table.remove(result, gatheringIndex)
            else entry.data = D.Rows(rows, entry.data.active, entry.data.activity, entry.data.title) end
        end
    end
    return result, mouseover
end

function D.Render(animate)
    if not addon.db or not (active or preview or layoutMode) then if frame then frame:Hide() end; return end
    if frame and (frame.baziMoving == true or addon.Movers and addon.Movers.IsDragging(frame)) then return end
    local cfg = D.Settings()
    animate = animate and not (preview or layoutMode)
    if not preview and not layoutMode and ((cfg.combat == "hide" and motionInCombat) or (cfg.combat == "only" and not motionInCombat)) then
        if frame then frame:Hide() end
        return
    end
    local widgets, mouseover = sortedWidgets()
    if #widgets == 0 and not (preview or layoutMode or mouseover) then
        if frame and frame:IsShown() then
            if D.ShowQuestItems then D.ShowQuestItems(frame, viewport) end
            local shell = cfg.showHeader and header:GetHeight() + 5 + contentInset + 2 or 2 * contentInset + 2
            resizeHeight(math.min(shell, frame:GetHeight()), animate, true)
        end
        return
    end
    local window = frame or makeFrame()
    local width = cfg.width - 2 * contentInset
    local typography = addon.Typography
    local font = typography.Path(addon.db.profile.font)
    local _, labelSize = typography.Resolve("Dashboard:Body", font, cfg.fontSize, "", true)
    local _, valueSize = typography.Resolve("Dashboard:Value", font, cfg.fontSize, "", true)
    local _, titleSize = typography.Resolve("Dashboard:Title", font, typography.BaseSize(), "OUTLINE", true)
    local fontSize = math.max(labelSize, valueSize)
    local r, g, b = addon.Theme:Accent()
    if cfg.accent then r, g, b = unpack(cfg.accent) end
    local style = table.concat({tostring(font), labelSize, valueSize, cfg.fontSize, cfg.iconSize, cfg.barHeight,
        r, g, b, width, addon.Typography.revision or 0}, "\31")
    local y = 0
    local questCard, questItems
    local used = {}
    for i, entry in ipairs(widgets) do
        if i > cfg.maxWidgets then break end
        local widget, options, data = entry.widget, entry.options, entry.data
        local card = cards[widget.id] or makeCard(widget.id)
        if widget.id == "quests" and cfg.showQuestItems then questCard, questItems = card, data.questItems end
        used[widget.id] = true
        local showCardTitle = cfg.headers and options.showHeader ~= false
        addon.Theme:PaintQuestCard(card, (options.background or 85) * cfg.opacity / 10000)
        card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        card:SetWidth(width)
        card.title:SetText(data.title or widget.label)
        addon.Typography.Apply(card.title, "Dashboard:Header", font, cfg.fontSize + 1, "", true)
        card.title:SetTextColor(addon.Headers.Text("dashboard", 1, 0.82, 0.49))
        card.title:SetShown(showCardTitle)
        local offset = showCardTitle and math.max(0, card.title:GetStringHeight()) + 10 or 5
        for index, value in ipairs(data.rows) do
            local row = card.rows[index]
            if not row then row = makeRow(card); card.rows[index] = row end
            row.data, row.widget = value, widget.id
            if row.offset ~= offset then
                row:SetPoint("TOPLEFT", card, "TOPLEFT", cardInset, -offset)
                row.offset = offset
            end
            local body = math.max(fontSize + 3, value.icon and cfg.iconSize or 0)
            local hasProgress = value.progress ~= nil
            local dataStyle = table.concat({tostring(value.label), tostring(value.value), tostring(value.icon),
                tostring(value.progress), tostring(value.done), tostring(value.warning), tostring(value.highlight),
                value.labelColor and table.concat(value.labelColor, ",") or ""}, "\31")
            if row.style ~= style or row.dataStyle ~= dataStyle then
                row.style, row.dataStyle = style, dataStyle
                row:SetWidth(width - 2 * cardInset)
                row:SetHeight(body + (hasProgress and cfg.barHeight + 3 or 0))
                row.icon:SetSize(cfg.iconSize, cfg.iconSize)
                row.icon:SetTexture(value.icon)
                row.icon:SetShown(value.icon ~= nil)
                row.label:SetPoint("TOPLEFT", value.icon and cfg.iconSize + 5 or 0, 0)
                addon.Typography.Apply(row.label, "Dashboard:Body", font, cfg.fontSize, "", true)
                addon.Typography.Apply(row.value, "Dashboard:Value", font, cfg.fontSize, "", true)
                row.label:SetText(value.label)
                if value.labelColor then row.label:SetTextColor(unpack(value.labelColor))
                else row.label:SetTextColor(1, 1, 1) end
                row.value:SetText(value.value or "")
                if value.warning then row.value:SetTextColor(1, 0.48, 0.42)
                elseif value.done then row.value:SetTextColor(0.62, 0.89, 0.59)
                elseif value.highlight then row.value:SetTextColor(r, g, b)
                else row.value:SetTextColor(0.91, 0.80, 0.64) end
                row.track:SetShown(hasProgress)
                row.bar:SetShown(hasProgress and value.progress > 0)
                if hasProgress then
                    row.track:SetHeight(cfg.barHeight)
                    row.bar:SetSize(math.max(0.01, (width - 2 * cardInset) * value.progress), cfg.barHeight)
                    if value.done then row.bar:SetColorTexture(0.40, 0.72, 0.39, 1)
                    else row.bar:SetColorTexture(r, g, b, 1) end
                end
            end
            row:Show()
            offset = offset + row:GetHeight() + cfg.rowSpacing
        end
        for index = #data.rows + 1, #card.rows do card.rows[index]:Hide() end
        card:SetHeight(math.max(12, offset + 5 - cfg.rowSpacing))
        card:Show()
        y = y + card:GetHeight() + cfg.spacing
    end
    for id, card in pairs(cards) do if not used[id] then card:Hide() end end
    local contentHeight = math.max(1, y - cfg.spacing)
    local placement = cfg.showHeader and (cfg.growUp and "BOTTOM" or "TOP") or "HIDDEN"
    local headerHeight = math.max(27, titleSize + 8)
    local layoutChanged = placement ~= headerPlacement or (cfg.showHeader and header:GetHeight() ~= headerHeight)
    local topInset = placement == "TOP" and headerHeight + 5 or contentInset
    local bottomInset = placement == "BOTTOM" and headerHeight + 5 or contentInset
    if layoutChanged then
        headerPlacement = placement
        header:SetShown(cfg.showHeader)
        if cfg.showHeader then
            header:SetHeight(headerHeight)
            local inset = placement == "BOTTOM" and 3 or -3
            header:ClearAllPoints()
            header:SetPoint(placement .. "LEFT", window, placement .. "LEFT", 3, inset)
            header:SetPoint(placement .. "RIGHT", window, placement .. "RIGHT", -3, inset)
        end
        viewport:ClearAllPoints()
        viewport:SetPoint("TOPLEFT", window, "TOPLEFT", contentInset, -topInset)
        viewport:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -contentInset, bottomInset)
    end
    local height = math.min(cfg.maxHeight, math.max(layoutMode and 38 or 1, contentHeight + topInset + bottomInset + 1))
    local opening = not window:IsShown()
    local needsScrollLayout = layoutChanged or window:GetWidth() ~= cfg.width
        or scrollChild:GetHeight() ~= contentHeight
    if scrollChild:GetHeight() ~= contentHeight then scrollChild:SetHeight(contentHeight) end
    if window:GetWidth() ~= cfg.width then window:SetWidth(cfg.width) end
    if window:GetScale() ~= cfg.scale / 100 then window:SetScale(cfg.scale / 100) end
    local ratio = UIParent:GetEffectiveScale() / window:GetEffectiveScale()
    local anchor = cfg.growUp and "BOTTOMLEFT" or "TOPLEFT"
    local point, parent, relative, x, yOffset = window:GetPoint(1)
    if point ~= anchor or parent ~= UIParent or relative ~= "CENTER" or x ~= cfg.x * ratio or yOffset ~= cfg.y * ratio then
        window:ClearAllPoints()
        window:SetPoint(anchor, UIParent, "CENTER", cfg.x * ratio, cfg.y * ratio)
    end
    window.baziOpacity = cfg.opacity
    window:ApplyStyle()
    window.border:SetShown(cfg.border)
    title:SetText(preview and "Dashboard preview" or "Dashboard")
    if opening and animate then setHeight(math.min(height, topInset + bottomInset + 2)) end
    resizeHeight(height, animate and (opening or not layoutChanged))
    if needsScrollLayout then viewport:UpdateScrollChildRect(); scrollbar:SyncRange() end
    window:Show()
    if D.ShowQuestItems then D.ShowQuestItems(window, viewport, questCard, questItems, preview or layoutMode) end
    if opening and cfg.fade and not layoutMode then window.baziFade:Play() end
end

function D.IsPreview() return preview end
function D.Preview(scenario) preview = scenario; D.Render() end
function D.GetFrame() return frame end
function D.LayoutMode(enabled) layoutMode = enabled; D.Render() end

function D.IsShowingRow(id, label)
    local card = cards[id]
    if not active or preview or layoutMode or not (frame and frame:IsVisible() and card and card:IsVisible()) then return false end
    for _, row in ipairs(card.rows) do
        if row:IsShown() and row.data and row.data.label == label then return true end
    end
    return false
end

local function rebuild()
    pending.timer = nil
    if not active then return end
    for _, widget in ipairs(D.widgets) do
        if pending[widget.id] then
            pending[widget.id] = nil
            if D.WidgetSettings(widget.id).enabled then
                local ok, data = pcall(widget.read, D.WidgetSettings(widget.id))
                if ok then savedRows[widget.id] = data
                else
                    savedRows[widget.id] = nil
                    if not widget.error then addon:Print(widget.label .. ": " .. tostring(data)); widget.error = true end
                end
            else savedRows[widget.id] = nil end
        end
    end
    D.Render(true)
end

function D.Invalidate(id)
    if not active then D.Render(); return end
    if id then pending[id] = true
    else for _, widget in ipairs(D.widgets) do pending[widget.id] = true end end
    if not pending.timer then pending.timer = C_Timer.NewTimer(0.08, rebuild) end
end

function D.Refresh()
    if not addon.db then return end
    local cfg = D.Settings()
    D.RefreshActivityNotices(cfg)
    if cfg.enabled ~= active then
        active = cfg.enabled
        events:UnregisterAllEvents()
        if clock then clock:Cancel(); clock = nil end
        if pending.timer then pending.timer:Cancel(); pending.timer = nil end
        wipe(eventOwners)
        wipe(pending)
        if active then
            motionInCombat = InCombatLockdown() == true
            for _, widget in ipairs(D.widgets) do if widget.resync then widget.resync() end end
            for _, event in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA"}) do
                events:RegisterEvent(event)
            end
        else wipe(savedRows) end
    end
    if active then
        -- Only events used by an enabled widget stay subscribed.
        local needed = {}
        for _, widget in ipairs(D.widgets) do
            if D.WidgetSettings(widget.id).enabled then
                for _, event in ipairs(widget.events or {}) do
                    needed[event] = needed[event] or {}
                    needed[event][#needed[event] + 1] = widget
                end
            end
        end
        for event in pairs(eventOwners) do
            if not needed[event] and event ~= "PLAYER_ENTERING_WORLD" and event ~= "ZONE_CHANGED_NEW_AREA"
                and event ~= "PLAYER_REGEN_ENABLED" and event ~= "PLAYER_REGEN_DISABLED" then events:UnregisterEvent(event) end
        end
        for event in pairs(needed) do if not eventOwners[event] then pcall(events.RegisterEvent, events, event) end end
        eventOwners = needed
        if not clock then
            clock = C_Timer.NewTicker(2, function()
                for _, widget in ipairs(D.widgets) do
                    local settings = D.WidgetSettings(widget.id)
                    if settings.enabled and widget.tick and (widget.tick == true or widget.tick(settings)) then D.Invalidate(widget.id) end
                end
            end)
        end
        D.Invalidate()
    else D.Render() end
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        motionInCombat = event == "PLAYER_REGEN_DISABLED"
        D.Render()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then D.Invalidate() end
    local dispatched = {}
    for _, widget in ipairs(eventOwners[event] or {}) do
        if widget.event and not dispatched[widget.event] then
            dispatched[widget.event] = true
            local ok, errorText = pcall(widget.event, event, ...)
            if not ok and not widget.error then addon:Print(widget.label .. ": " .. tostring(errorText)); widget.error = true end
        end
        D.Invalidate(widget.id)
    end
end)
