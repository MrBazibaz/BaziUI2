local addon = BaziUI
local dialogue, voice = addon.Dialogue, addon.Dialogue.Voice
local main, reader, current, hidden, preview
function dialogue.GetMoverFrame(compact) return compact and reader or (not compact and main) end
local queueIndex = 1
local refreshQueued, elapsed, readerAfter = nil, nil, 0
local interactionTypes = Enum and Enum.PlayerInteractionType
local nativeAlpha, watchedNative = {}, {}
local iconPath = "Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\"
local questStates = {
    available = {icon = iconPath .. "QuestAvailable.tga", label = "Available", color = {1, 0.82, 0.49}},
    active = {icon = iconPath .. "QuestProgress.tga", label = "In progress", color = {0.78, 0.74, 0.69}},
    ready = {icon = iconPath .. "QuestTurnIn.tga", label = "Ready to turn in", color = {0.62, 0.91, 0.56}},
}

local function text(parent, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetTextColor(unpack(color or {0.94, 0.91, 0.87}))
    label.baziSize = size
    return label
end

local function style(view, cfg)
    view:SetScale(cfg.scale / 100)
    view:ClearAllPoints()
    if view == reader then
        local edge = cfg.readerGrowUp and "BOTTOM" or "TOP"
        view:SetPoint(edge, UIParent, "CENTER", cfg.readerX, cfg.readerY)
        view.band:ClearAllPoints()
        view.band:SetPoint(edge .. "LEFT", 3, cfg.readerGrowUp and 3 or -3)
        view.band:SetPoint(edge .. "RIGHT", -3, cfg.readerGrowUp and 3 or -3)
        view.progress:ClearAllPoints()
        local line = cfg.readerGrowUp and "TOP" or "BOTTOM"
        view.progress:SetPoint(line .. "LEFT", view.band, line .. "LEFT", 9, 0)
        view.progress:SetPoint(line .. "RIGHT", view.band, line .. "RIGHT", -9, 0)
        view.progress:SetStatusBarColor(addon.Theme:Accent())
        view.bodyHost:ClearAllPoints()
        local artHeight = view.bannerHeight or 0
        local top = cfg.readerGrowUp and -12 or -51
        view.bodyHost:SetPoint("TOPLEFT", artHeight > 0 and 6 or 50, top - artHeight)
        view.bodyHost:SetPoint("BOTTOMRIGHT", -4, cfg.readerGrowUp and 50 or 11)
        view.banner:ClearAllPoints()
        view.banner:SetPoint("TOPLEFT", view, "TOPLEFT", 3, top + 7)
        view.banner:SetPoint("TOPRIGHT", view, "TOPRIGHT", -3, top + 7)
        view.banner:SetHeight(math.max(1, artHeight))
    else
        view:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
    end
    view.fill:SetColorTexture(0.024, 0.022, 0.028, cfg.opacity / 100)
    view.band:SetColorTexture(addon.Headers.Fill("dialogue", 0.17, 0.13, 0.15, 0.7))
    view.title:SetTextColor(addon.Headers.Text("dialogue", 1, 0.82, 0.49))
    local file = addon.Typography.Path(addon.db.profile.font)
    for _, label in ipairs({view.title, view.body, view.byline or view.measure}) do
        addon.Typography.Apply(label, label == view.title and "Dialogue:Header" or "Dialogue:Body", file, label.baziSize, "", true)
    end
end

local function shell(width, height, strata)
    local view = CreateFrame("Frame", nil, UIParent)
    view:SetFrameStrata(strata)
    view:SetSize(width, height)
    view:SetClampedToScreen(true)
    view:EnableMouse(true)
    view:Hide()
    view.fill = view:CreateTexture(nil, "BACKGROUND")
    view.fill:SetPoint("TOPLEFT", 2, -2)
    view.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    view.band = view:CreateTexture(nil, "BORDER")
    view.band:SetPoint("TOPLEFT", 3, -3)
    view.band:SetPoint("TOPRIGHT", -3, -3)
    view.band:SetHeight(39)
    view.tint = view:CreateTexture(nil, "BACKGROUND", nil, 1)
    view.tint:SetAllPoints(view.fill)
    view.tint:Hide()
    addon.Theme:CreateFrameBorder(view, view, view)
    addon.Theme:AddDropShadow("Dialogue", view)
    return view
end

local function button(parent, title, width, height, action)
    local control = addon.Theme:CreateButton(parent, title, width, height)
    control:SetScript("OnClick", action)
    return control
end

local function controlIcon(control, name)
    if not control.icon then
        control.icon = control:CreateTexture(nil, "OVERLAY")
        control.icon:SetSize(15, 15)
        control.icon:SetPoint("CENTER")
    end
    control.icon:SetTexture(iconPath .. name .. ".tga")
    control.icon:SetVertexColor(1, 0.83, 0.56)
end

local function divider(parent, relative, gap)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", relative, "BOTTOMLEFT", 0, -gap)
    line:SetWidth(parent:GetWidth())
    line:SetHeight(1)
    line:SetColorTexture(0.59, 0.46, 0.31, 0.48)
    return line
end

local function maskNative(frame)
    if nativeAlpha[frame] == nil then nativeAlpha[frame] = frame:GetAlpha() end
    if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
end

local function restoreNative(frame)
    local alpha = nativeAlpha[frame]
    if alpha == nil then return end
    nativeAlpha[frame] = nil
    frame:SetAlpha(alpha)
end

local function buryNative(frame)
    if frame then maskNative(frame) end
    if hidden and hidden.frame == frame then return end
    if hidden then
        for region, mouse in pairs(hidden.mouse) do region:EnableMouse(mouse) end
        hidden = nil
    end
    if not frame then return end
    hidden = {frame = frame, mouse = {}}
    local function muteMouse(region)
        if region.IsMouseEnabled and region:IsMouseEnabled() and not region:IsProtected() then
            hidden.mouse[region] = true
            region:EnableMouse(false)
        end
        for _, child in ipairs({region:GetChildren()}) do muteMouse(child) end
    end
    muteMouse(frame)
end

local function closePage(page)
    if page.native == _G.GossipFrame and C_GossipInfo and C_GossipInfo.CloseGossip then C_GossipInfo.CloseGossip()
    else CloseQuest() end
end

local function report(page)
    for _, action in ipairs(page and page.clip and page.clip.present and page.clip.present.actions or {}) do
        if action.id == "report" and action.onClick then action.onClick(page.clip); return end
    end
    if _G.Spoken and Spoken.OpenSettings then Spoken:OpenSettings() end
end

local function playerControls(view, resolve)
    local previous
    local function control(icon, tip, action)
        local item = button(view, "", 28, 28, action)
        controlIcon(item, icon)
        if previous then item:SetPoint("RIGHT", previous, "LEFT", -7, 0)
        else item:SetPoint("RIGHT", view.close, "LEFT", -8, 0) end
        previous = item
        item:SetScript("OnClick", action)
        item:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tip)
            GameTooltip:Show()
        end)
        item:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return item
    end
    local controls = {}
    controls.report = control("Report", "Report voice issue", function() report(resolve()) end)
    controls.skip = control("Next", "Skip", function() voice.Skip(resolve()) end)
    controls.previous = control("Skip", "Previous line", function() if _G.Spoken then Spoken:Previous() end end)
    controls.play = control("Play", "Listen / pause", function() voice.Play(resolve(), view == main) end)
    controls.first = previous
    return controls
end

local function ready(button, enabled)
    if button:IsEnabled() == not not enabled then return end
    if enabled then button:Enable() else button:Disable() end
end

local function refreshControls(view, page)
    local api = _G.Spoken
    local playing = voice.IsPlaying(page)
    local controls = view.controls
    controlIcon(controls.play, playing and "Pause" or "Play")
    ready(controls.play, api and (page.clip or view == main))
    ready(controls.previous, api and api.CanPrevious and api:CanPrevious())
    ready(controls.skip, api and api.GetCurrent and api:GetCurrent())
    ready(controls.report, api ~= nil)
end

local function makeMain()
    if main then return main end
    local view = shell(555, 515, "FULLSCREEN_DIALOG")
    main = view
    view.close = button(view, "", 28, 28, function()
        if current and current.native then closePage(current) else dialogue.Preview(nil) end
    end)
    controlIcon(view.close, "Cross")
    view.close:SetPoint("TOPRIGHT", -13, -7)
    view.controls = playerControls(view, function() return current end)
    view.portrait = view:CreateTexture(nil, "ARTWORK")
    view.portrait:SetSize(54, 54)
    view.portrait:SetPoint("TOPLEFT", 24, -53)
    local mask = view:CreateMaskTexture()
    mask:SetAllPoints(view.portrait)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    view.portrait:AddMaskTexture(mask)
    view.title = text(view, 25)
    view.title:SetPoint("TOPLEFT", view.portrait, "TOPRIGHT", 13, -18)
    view.title:SetWidth(430)
    view.title:SetWordWrap(false)
    view.byline = text(view, 13, {0.76, 0.70, 0.62})
    view.byline:SetPoint("TOPLEFT", view.portrait, "TOPRIGHT", 13, -1)
    local bodyHost = CreateFrame("Frame", nil, view)
    bodyHost:SetPoint("TOPLEFT", 19, -121)
    bodyHost:SetPoint("BOTTOMRIGHT", -8, 63)
    local content, scroll = addon.Inventory.Scroll(bodyHost, 0, 0)
    content:SetWidth(496)
    view.content, view.scroll = content, scroll
    view.body = text(content, 16)
    view.body:SetPoint("TOPLEFT", 0, -2)
    view.body:SetPoint("TOPRIGHT", 0, -2)
    view.body:SetJustifyV("TOP")
    view.body:SetSpacing(4)
    view.rows = {}
    view.primary = button(view, "Accept", 242, 34, function()
        if current and current.action then current.action(current) end
    end)
    view.primary:SetPoint("BOTTOMLEFT", 24, 17)
    view.cancel = button(view, CANCEL or "Cancel", 242, 34, function() view.close:Click() end)
    view.cancel:SetPoint("BOTTOMRIGHT", -24, 17)
    return view
end

local function setReaderVisible(visible, immediate)
    if not reader then return end
    local target = visible and 1 or 0
    if reader.fadeTarget == target and (not immediate or reader:GetAlpha() == target and reader:IsShown() == visible) then return end
    reader.fadeTarget = target
    if immediate then
        reader:SetScript("OnUpdate", nil)
        reader:SetAlpha(target)
        reader:SetShown(visible)
        return
    end
    if visible and not reader:IsShown() then reader:Show() end
    local start, time = reader:GetAlpha(), 0
    local duration = visible and 0.20 or 0.26
    reader:SetScript("OnUpdate", function(self, delta)
        time = math.min(duration, time + delta)
        local progress = time / duration
        local eased = progress * progress * (3 - 2 * progress)
        self:SetAlpha(start + (target - start) * eased)
        if time == duration then
            self:SetScript("OnUpdate", nil)
            if not visible then self:Hide() end
        end
    end)
end

local function readerProgress(page)
    local api = _G.Spoken
    local caption = api and api.GetCaption and api:GetCaption()
    if page and caption and caption.clip == page.clip and type(caption.progress) == "number" then
        return caption.progress
    end
end

local function makeReader()
    if reader then return reader end
    local view = shell(465, 114, "DIALOG")
    reader = view
    view:SetAlpha(0)
    view.fadeTarget = 0
    view.close = button(view, "", 28, 28, function()
        if preview == "reader" then dialogue.Preview(nil); return end
        if view.page and view.page.standalone then
            view.dismissedClip = view.page.clip
        elseif voice.queue[queueIndex] then table.remove(voice.queue, queueIndex) end
        queueIndex = 1
        setReaderVisible(false)
    end)
    controlIcon(view.close, "Cross")
    view.close:SetPoint("RIGHT", view.band, "RIGHT", -9, 0)
    view.controls = playerControls(view, function() return view.page end)
    local titleButton = CreateFrame("Button", nil, view)
    titleButton:SetPoint("LEFT", view.band, "LEFT", 15, 0)
    titleButton:SetPoint("RIGHT", view.controls.first, "LEFT", -7, 0)
    titleButton:SetHeight(25)
    titleButton:SetScript("OnClick", function()
        if #voice.queue > 1 then queueIndex = queueIndex % #voice.queue + 1 end
    end)
    view.title = text(view, 18)
    view.title:SetPoint("LEFT", titleButton, "LEFT")
    view.count = text(view, 13, {0.83, 0.69, 0.48})
    view.count:SetPoint("RIGHT", titleButton, "RIGHT")
    view.title:SetPoint("RIGHT", view.count, "LEFT", -5, 0)
    view.title:SetWordWrap(false)
    local host = CreateFrame("Frame", nil, view)
    view.bodyHost = host
    view.progress = CreateFrame("StatusBar", nil, view)
    view.progress:SetHeight(2)
    view.progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    view.progress:SetMinMaxValues(0, 1)
    view.progress:EnableMouse(false)
    view.progress:SetScript("OnUpdate", function(bar)
        local progress = readerProgress(view.page)
        if progress then bar:SetValue(progress) end
    end)
    view.speaker = text(host, 12, {0.73, 0.65, 0.55})
    view.speaker:SetPoint("TOPLEFT")
    view.speaker:SetPoint("TOPRIGHT", -9, 0)
    view.speaker:SetWordWrap(false)
    view.art = view:CreateTexture(nil, "ARTWORK")
    view.art:SetSize(30, 30)
    view.art:SetPoint("TOPRIGHT", host, "TOPLEFT", -9, 0)
    view.banner = view:CreateTexture(nil, "ARTWORK")
    local fade = view:CreateMaskTexture()
    fade:SetAllPoints(view.banner)
    fade:SetTexture(iconPath .. "BannerFade.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    view.banner:AddMaskTexture(fade)
    view.banner:Hide()
    local content, scroll, scrollbar = addon.Inventory.Scroll(host, -17, 0)
    content:SetWidth(398)
    view.content, view.scroll, view.scrollbar = content, scroll, scrollbar
    scrollbar:SetWidth(5)
    local thumb = scrollbar:GetThumbTexture()
    thumb:SetSize(5, 22)
    thumb:SetColorTexture(0.65, 0.51, 0.33, 0.9)
    scroll:HookScript("OnMouseWheel", function() view.manualScroll = true end)
    scrollbar:HookScript("OnMouseDown", function() view.manualScroll = true end)
    view.body = text(content, 15)
    view.body:SetPoint("TOPLEFT", 0, 0)
    view.body:SetPoint("TOPRIGHT", 0, 0)
    view.body:SetJustifyV("TOP")
    view.body:SetSpacing(2)
    view.body:SetWordWrap(true)
    view.measure = text(content, 15)
    view.measure:SetSpacing(2)
    view.measure:SetWordWrap(true)
    view.measure:Hide()
    return view
end

local function tint(view, page, cfg)
    local marked = cfg.tint and dialogue.IsForeverQuest(page.questID)
    view.tint:SetShown(marked)
    if marked then
        local r, g, b = addon.Theme:Accent()
        view.tint:SetColorTexture(1, 1, 1, 1)
        view.tint:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.15))
    end
end

local function section(view, index, y, title)
    local row = view.rows[index]
    if not row then row = {}; view.rows[index] = row end
    if not row.label then row.label = text(view.content, 15, {0.88, 0.72, 0.47}) end
    local label = row.label
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", view.content, "TOPLEFT", 0, -y)
    label:SetText(title)
    label:Show()
    if not row.rule then row.rule = divider(view.content, label, 4) end
    row.rule:Show()
end

local function rowButton(view, index, left, y, width, item, height, optionSize)
    local row = view.rows[index]
    if not row then row = {}; view.rows[index] = row end
    local control = row.control
    if not control then
        control = CreateFrame("Button", nil, view.content)
        row.control = control
        control.fill = control:CreateTexture(nil, "BACKGROUND")
        control.fill:SetAllPoints()
        local highlight = control:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.85, 0.61, 0.32, 0.20)
        control:SetHighlightTexture(highlight)
        control.selection = CreateFrame("Frame", nil, control, "BackdropTemplate")
        control.selection:SetAllPoints()
        control.selection:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
        control.selection:SetBackdropBorderColor(1, 0.78, 0.35, 1)
        control.selection:EnableMouse(false)
        control.icon = control:CreateTexture(nil, "ARTWORK")
        control.icon:SetSize(34, 34)
        control.icon:SetPoint("LEFT", 4, 0)
        control.upgrade = control:CreateTexture(nil, "OVERLAY")
        control.upgrade:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\ChevronUp.tga")
        control.upgrade:SetVertexColor(0.36, 1, 0.43)
        control.upgrade:SetSize(15, 15)
        control.upgrade:SetPoint("TOPRIGHT", control.icon, "TOPRIGHT", 1, 0)
        control.label = text(control, 14)
        control.label:SetWordWrap(false)
        control:SetScript("OnClick", function(self) if self.item.action then self.item.action() end end)
        control:SetScript("OnEnter", function(self)
            if self.item.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.item.link)
            end
        end)
        control:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    control.item = item
    control:SetSize(width, height)
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", view.content, "TOPLEFT", left, -y)
    if item.selected then
        control.fill:SetColorTexture(0.36, 0.23, 0.10, 0.94)
    else
        control.fill:SetColorTexture(0.15, 0.12, 0.11, 0.52)
    end
    control.selection:SetShown(item.selected == true)
    control.fill:SetShown(item.icon ~= nil or item.action ~= nil)
    control:GetHighlightTexture():SetShown(item.action ~= nil)
    control:EnableMouse(item.action ~= nil or item.link ~= nil)
    control.icon:SetTexture(item.icon)
    control.upgrade:SetShown(item.upgrade == true)
    control.icon:SetShown(item.icon ~= nil)
    control.label:SetText(item.label)
    local typography = addon.Typography
    typography.Apply(control.label, item.action and "Dialogue:Options" or "Dialogue:Body",
        typography.Path(addon.db.profile.font), item.action and optionSize or 14, "", true)
    control.label:ClearPoint("LEFT")
    control.label:SetPoint("LEFT", item.icon and 46 or 3, 0)
    control.label:ClearPoint("RIGHT")
    local state = item.questState
    if state then
        if not control.questStatus then
            control.questStatus = text(control, 12)
            control.questStatus:SetPoint("RIGHT", -10, 0)
        end
        local status = control.questStatus
        typography.Apply(status, "Dialogue:Options", typography.Path(addon.db.profile.font),
            math.max(9, optionSize - 2), "", true)
        status:SetText(state.label)
        status:SetTextColor(unpack(state.color))
        status:Show()
        control.label:SetPoint("RIGHT", status, "LEFT", -10, 0)
    else
        if control.questStatus then control.questStatus:Hide() end
        control.label:SetPoint("RIGHT", -7, 0)
    end
    control:Show()
end

local function showMain(page, cfg)
    local view = makeMain()
    if view.pageKey ~= page.key then
        view.pageKey = page.key
        view.scroll:SetVerticalScroll(0)
    end
    style(view, cfg)
    tint(view, page, cfg)
    view.title:SetText(page.title)
    view.byline:SetText(page.byline or "")
    view.body:SetText(page.text)
    if page.native and UnitExists("npc") then SetPortraitTexture(view.portrait, "npc")
    else view.portrait:SetTexture(134939) end
    view.primary:SetShown(page.primary ~= nil)
    view.primary:SetText(page.primary or "")
    ready(view.primary, page.action ~= nil)
    for _, row in ipairs(view.rows) do
        if row.label then row.label:Hide(); row.rule:Hide() end
        if row.control then row.control:Hide() end
    end
    view:Show()
    local typography = addon.Typography
    local file = typography.Path(addon.db.profile.font)
    local _, optionSize = typography.Resolve("Dialogue:Options", file, cfg.optionFontSize, "", true)
    local _, bodySize = typography.Resolve("Dialogue:Body", file, 14, "", true)
    local y, rowIndex = math.ceil(view.body:GetStringHeight()) + 19, 1
    for _, list in ipairs(page.sections) do
        section(view, rowIndex, y, list.title)
        rowIndex, y = rowIndex + 1, y + 28
        local width = math.max(220, view.content:GetWidth())
        local columns = list.columns or 1
        local tile = (width - (columns - 1) * 8) / columns
        local height = list.plain and math.max(22, bodySize + 5) or math.max(40, optionSize + 12)
        local stride = height + (list.plain and 1 or 5)
        for index, item in ipairs(list) do
            rowButton(view, rowIndex, ((index - 1) % columns) * (tile + 8), y + math.floor((index - 1) / columns) * stride, tile, item, height, cfg.optionFontSize)
            rowIndex = rowIndex + 1
        end
        y = y + math.ceil(#list / columns) * stride + 10
    end
    view.content:SetHeight(math.max(1, y))
end

local function shown(frame)
    return frame and frame:IsShown()
end

local function addSection(page, title, columns)
    local list = {title = title, columns = columns}
    page.sections[#page.sections + 1] = list
    return list
end

local function itemList(page, label, kind, count, markValue)
    if not count or count < 1 then return end
    local items = addSection(page, label, 2)
    local mostValuable, bestValue = nil, 0
    local rewardGear = kind == "choice" and addon.Adventure and addon.Adventure.EquipmentSnapshot()
    for index = 1, count do
        local name, icon, amount, _, _, itemID = GetQuestItemInfo(kind, index)
        local ok, link = pcall(GetQuestItemLink, kind, index)
        local entry = {label = (name or "…") .. (amount and amount > 1 and " ×" .. amount or ""), icon = icon,
            link = ok and link or nil}
        if markValue and entry.link then
            local info = C_Item and C_Item.GetItemInfo or GetItemInfo
            local price = select(11, info(entry.link))
            local total = (price or 0) * (amount or 1)
            if total > bestValue then mostValuable, bestValue = entry, total end
        end
        if kind == "choice" and page.phase == "reward" then
            local upgrades = addon.LootUpgrades
            local candidate = entry.link or itemID
            local result = upgrades and candidate and upgrades.Compare(candidate, rewardGear)
            entry.upgrade = result ~= nil
            entry.action = function()
                page.reward = index
                for pick, item in ipairs(items) do item.selected = pick == index end
                showMain(page, dialogue.Settings())
            end
        end
        items[#items + 1] = entry
    end
    if mostValuable then
        mostValuable.label = mostValuable.label .. "  |TInterface\\MoneyFrame\\UI-GoldIcon:13:13|t"
    end
end

local function objectives(page, description)
    local list = C_QuestLog and C_QuestLog.GetQuestObjectives and page.questID > 0 and C_QuestLog.GetQuestObjectives(page.questID)
    if (not list or #list == 0) and (not description or description == "") then return end
    local section = addSection(page, QUEST_OBJECTIVES or "Objectives")
    section.plain = true
    for _, objective in ipairs(list or {}) do
        local mark = objective.finished and "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0|t  " or "-  "
        section[#section + 1] = {label = mark .. (objective.text or "")}
    end
    if #section == 0 then
        for line in description:gmatch("[^\r\n]+") do section[#section + 1] = {label = line} end
    end
end

local function gossipQuest(title, action, active, complete)
    local ready = not (issecretvalue and issecretvalue(complete)) and (complete == true or complete == 1)
    local state = active and (ready and questStates.ready or questStates.active) or questStates.available
    return {label = title, icon = state.icon, questState = state, action = action}
end

local function gossip(page, classic)
    local api = C_GossipInfo
    local list = addSection(page, QUESTS_LABEL or "Quests and conversation")
    if classic then
        for index = 1, GetNumActiveQuests and GetNumActiveQuests() or 0 do
            local title, complete = GetActiveTitle(index)
            list[#list + 1] = gossipQuest(title, function() SelectActiveQuest(index) end, true, complete)
        end
        for index = 1, GetNumAvailableQuests and GetNumAvailableQuests() or 0 do
            list[#list + 1] = gossipQuest(GetAvailableTitle(index), function() SelectAvailableQuest(index) end)
        end
    elseif api then
        for _, quest in ipairs(api.GetActiveQuests() or {}) do
            list[#list + 1] = gossipQuest(quest.title, function() api.SelectActiveQuest(quest.questID) end, true, quest.isComplete)
        end
        for _, quest in ipairs(api.GetAvailableQuests() or {}) do
            list[#list + 1] = gossipQuest(quest.title, function() api.SelectAvailableQuest(quest.questID) end)
        end
        for _, option in ipairs(api.GetOptions() or {}) do
            list[#list + 1] = {label = option.name, icon = option.icon,
                action = function() api.SelectOption(option.gossipOptionID) end}
        end
    end
    if #list == 0 then table.remove(page.sections) end
end

local function clickNative(name, fallback, ...)
    local control = _G[name]
    if control and control:IsShown() and control:IsEnabled() then control:Click()
    elseif not control and fallback then fallback(...) end
end

local function capture()
    local native, phase
    if shown(_G.QuestFrame) then
        native = QuestFrame
        if shown(_G.QuestFrameProgressPanel) then phase = "progress"
        elseif shown(_G.QuestFrameRewardPanel) then phase = "reward"
        elseif shown(_G.QuestFrameDetailPanel) then phase = "detail"
        elseif shown(_G.QuestFrameGreetingPanel) then phase = "greeting" end
    elseif shown(_G.GossipFrame) then native, phase = GossipFrame, "gossip" end
    if not phase then return end
    local npc = UnitName("npc") or ""
    local quest = phase ~= "gossip" and phase ~= "greeting"
    local page = {native = native, phase = phase, questID = quest and tonumber(GetQuestID()) or 0,
        guid = UnitGUID("npc"), byline = npc, title = quest and GetTitleText() or npc, text = "", sections = {}}
    if phase == "detail" then
        page.text = GetQuestText() or ""
        objectives(page, GetObjectiveText())
        local choices = GetNumQuestChoices()
        itemList(page, QUEST_REWARDS or "Rewards", "reward", GetNumQuestRewards(), choices == 0)
        itemList(page, QUEST_CHOOSE_REWARD or "Choose a reward", "choice", choices, true)
        page.primary = ACCEPT or "Accept"
        page.action = function()
            if addon.Inventory.NoteQuestTurnIn then addon.Inventory.NoteQuestTurnIn(page.questID, 0, true) end
            clickNative("QuestFrameAcceptButton", AcceptQuest)
        end
    elseif phase == "progress" then
        page.text = GetProgressText() or ""
        itemList(page, "Requirements", "required", GetNumQuestItems())
        objectives(page)
        local complete = IsQuestCompletable()
        page.primary = complete and (CONTINUE or "Continue") or "Incomplete"
        if complete then
            page.action = function()
                if addon.Inventory.NoteQuestTurnIn then addon.Inventory.NoteQuestTurnIn(page.questID, 0) end
                clickNative("QuestFrameCompleteButton", CompleteQuest)
            end
        end
    elseif phase == "reward" then
        page.text = GetRewardText() or ""
        local choices = GetNumQuestChoices()
        itemList(page, QUEST_REWARDS or "Rewards", "reward", GetNumQuestRewards(), choices == 0)
        itemList(page, "Choose a reward", "choice", choices, true)
        page.primary = COMPLETE_QUEST or "Complete Quest"
        page.action = function(self)
            if choices > 1 and not self.reward then
                UIErrorsFrame:AddMessage("Choose a quest reward first.", 1, 0.3, 0.2)
            else
                local choice = self.reward or choices
                if addon.Inventory.NoteQuestTurnIn then addon.Inventory.NoteQuestTurnIn(page.questID, choice) end
                GetQuestReward(choice)
            end
        end
    else
        page.byline = "Conversation"
        page.text = (phase == "gossip" and C_GossipInfo and C_GossipInfo.GetText() or GetGreetingText and GetGreetingText()) or ""
        gossip(page, phase == "greeting")
    end
    page.key = table.concat({phase, page.questID, page.guid or "", page.title or "", page.text}, "\31")
    return page
end

local masked = {}
local watchedNarrator = setmetatable({}, {__mode = "k"})
local function maskFrame(frame)
    if not frame or masked[frame] then return end
    local state = {alpha = frame:GetAlpha()}
    masked[frame] = state
    if not watchedNarrator[frame] then
        watchedNarrator[frame] = true
        hooksecurefunc(frame, "SetAlpha", function(self, alpha)
            local currentMask = masked[self]
            if not currentMask or currentMask.applying then return end
            currentMask.alpha = alpha
            if alpha > 0 then
                currentMask.applying = true
                self:SetAlpha(0)
                currentMask.applying = nil
            end
        end)
    end
    if state.alpha > 0 then
        state.applying = true
        frame:SetAlpha(0)
        state.applying = nil
    end
end

local function maskSubtitle(active)
    if active then
        maskFrame(_G.SpokenSubtitleFrame)
        local api = _G.Spoken
        if api and api.GetPlayerFrame then maskFrame(api:GetPlayerFrame()) end
    else
        for frame, state in pairs(masked) do
            masked[frame] = nil
            frame:SetAlpha(state.alpha)
        end
    end
end

function dialogue.Refresh()
    if not addon.db then return end
    local cfg = dialogue.Settings()
    if not cfg.enabled then
        buryNative(nil)
        for frame in pairs(nativeAlpha) do restoreNative(frame) end
        if main then main:Hide() end
        setReaderVisible(false, true)
        maskSubtitle(false)
        current, preview = nil, nil
        return
    end
    -- Pre-hide closed Blizzard panels so their next Show does not paint native art.
    if _G.QuestFrame and not QuestFrame:IsShown() then maskNative(QuestFrame) end
    if _G.GossipFrame and not GossipFrame:IsShown() then maskNative(GossipFrame) end
    local page = capture()
    if current and current.native and (not page or page.native ~= current.native) then
        voice.Remember(current)
        queueIndex = 1
        readerAfter = GetTime() + 0.15
    end
    if page then
        setReaderVisible(false, true)
        for index, entry in ipairs(voice.queue) do
            if page.key == entry.key then
                page.clip = entry.clip
                table.remove(voice.queue, index)
                queueIndex = 1
                break
            end
        end
        if current and current.key == page.key then
            page.clip, page.reward = current.clip or page.clip, current.reward
            if page.reward then
                for _, list in ipairs(page.sections) do
                    for index, entry in ipairs(list) do
                        if entry.action then entry.selected = page.reward == index end
                    end
                end
            end
        end
        preview = nil
        current = page
        buryNative(page.native)
        showMain(page, cfg)
    elseif preview == "main" then
        showMain(current, cfg)
    else
        current = nil
        buryNative(nil)
        if main then main:Hide() end
    end
    if reader then style(reader, cfg) end
end

local function npcTransition()
    if GetTime() < readerAfter or shown(_G.QuestFrame) or shown(_G.GossipFrame) then return true end
    local api = C_PlayerInteractionManager
    if not interactionTypes or not api or not api.IsInteractingWithNpcOfType then return false end
    return api.IsInteractingWithNpcOfType(interactionTypes.Gossip)
        or api.IsInteractingWithNpcOfType(interactionTypes.QuestGiver)
end

local function updateReader(cfg)
    voice.CleanQueue()
    if queueIndex > #voice.queue then queueIndex = 1 end
    local standalone, waitingForNPC = voice.Standalone()
    local saved = voice.queue[queueIndex]
    local page = voice.IsCurrent(saved) and saved or standalone or (not waitingForNPC and saved)
    if preview == "reader" then page = dialogue.previewPage end
    if not preview and npcTransition() then
        setReaderVisible(false, true)
        return voice.IsCurrent(page) or voice.OwnsHead()
    end
    if not page or not (page.clip or preview == "reader") or (main and main:IsShown()) then
        setReaderVisible(false, main and main:IsShown())
        return voice.IsCurrent(page) or waitingForNPC
    end
    local view = makeReader()
    if page.clip and page.clip == view.dismissedClip then
        setReaderVisible(false)
        return voice.IsCurrent(page)
    end
    if view.page ~= page or not view:IsShown() then
        view.page = page
        view:SetFrameStrata(page.selfTest and "FULLSCREEN_DIALOG" or "DIALOG")
        tint(view, page, cfg)
        view.title:SetText(page.title)
        local clip = page.clip
        local present = clip and clip.present or {}
        local portrait = present.portrait or {}
        local api = _G.Spoken
        view.speaker:SetText(present.header or page.byline or "")
        local artwork = portrait.kind == "texture" and portrait.texture
        local place = clip and clip.source and clip.source.key == "places"
        local picture = place and present.picture and present.picture.file
        local banner = picture or (place and artwork)
        view.bannerHeight = banner and 96 or 0
        view.banner:SetShown(not not banner)
        if banner then
            local coords = not picture and portrait.texCoord
            local left, right, top, bottom = 0, 1, 0, 1
            if coords and #coords == 4 then left, right, top, bottom = unpack(coords) end
            local center = (top + bottom) / 2
            local half = (bottom - top) * (picture and 0.23 or 0.12)
            view.banner:SetTexture(banner)
            view.banner:SetTexCoord(left, right, center - half, center + half)
        end
        style(view, cfg)
        view.art:SetTexture(artwork or iconPath .. "Chat.tga")
        view.art:SetTexCoord(unpack(artwork and portrait.texCoord or {0, 1, 0, 1}))
        if not view.face and api and api.CreateSpeakerFace then
            view.face = api:CreateSpeakerFace(view, 34)
            view.face:SetPoint("CENTER", view.art)
        end
        local creatureID = portrait.creatureID or (type(page.guid) == "string" and tonumber((select(6, strsplit("-", page.guid)))))
        local hasFace = view.face and creatureID
        if view.face then
            view.face:SetShown(not not hasFace)
            if hasFace then view.face:SetSpeaker({creatureID = creatureID, displayID = portrait.displayID,
                guid = portrait.guid or page.guid, bullet = present.bullet}) end
        end
        view.art:SetShown(not hasFace and not banner)
        view.manualScroll = nil
        view.scrollbar:SetValue(0)
    end
    local waiting = voice.Waiting(page)
    view.count:SetText(waiting > 0 and ("+%d"):format(waiting) or "")
    local line, activeByte = voice.Update(page)
    if view.body:GetText() ~= line then view.body:SetText(line) end
    local progress = readerProgress(page)
    view.progress:SetShown(progress ~= nil)
    if progress then view.progress:SetValue(progress) end
    setReaderVisible(true)
    local contentHeight = math.max(18, math.ceil(view.body:GetStringHeight()) + 2)
    local scale = view:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local space = UIParent:GetHeight() / (2 * scale) + (cfg.readerGrowUp and -cfg.readerY or cfg.readerY)
    local chromeHeight = 79 + (view.bannerHeight or 0)
    local maxHeight = math.max(220, math.min(600, tonumber(cfg.readerMaxHeight) or 240))
    local height = math.min(chromeHeight + contentHeight, maxHeight, math.max(chromeHeight + 26, space - 16))
    if view:GetHeight() ~= height then view:SetHeight(height) end
    if view.content:GetHeight() ~= contentHeight then view.content:SetHeight(contentHeight) end
    if activeByte and not view.manualScroll and height < chromeHeight + contentHeight then
        view.measure:SetWidth(view.content:GetWidth())
        view.measure:SetText(page.text:sub(1, activeByte - 1))
        local lineY = view.measure:GetStringHeight()
        local offset = view.scroll:GetVerticalScroll()
        if lineY < offset or lineY > offset + height - chromeHeight - 12 then
            view.scrollbar:SetValue(math.max(0, math.min(view.scroll:GetVerticalScrollRange(), lineY - 22)))
        end
    end
    refreshControls(view, page)
    return voice.IsCurrent(page) or waitingForNPC
end

function dialogue.Preview(which)
    if not which or preview == which then
        preview = nil
    else
        preview = which
        dialogue.previewPage = {questID = 0, title = "Dialogue preview", byline = "Bazi UI",
            text = "Use the position controls to move this window.", sections = {}, primary = "Continue"}
        if which == "main" then current = dialogue.previewPage end
    end
    dialogue.Refresh()
    if addon.db and dialogue.Settings().enabled then updateReader(dialogue.Settings()) end
end

local events = CreateFrame("Frame")
local playbackWatched
local readerTransitions = {GOSSIP_SHOW = true, QUEST_GREETING = true, QUEST_DETAIL = true,
    QUEST_PROGRESS = true, QUEST_COMPLETE = true, QUEST_FINISHED = true, GOSSIP_CLOSED = true}
local function scheduleRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function() refreshQueued = nil; dialogue.Refresh() end)
end

local function dialogueEnabled()
    local cfg = addon.db and addon.db.profile.dialogue
    return cfg and cfg.enabled
end

local function watchNative(frame)
    if not frame or watchedNative[frame] then return end
    watchedNative[frame] = true
    local opening = 0
    local function onShow(self)
        if not dialogueEnabled() then return end
        opening = opening + 1
        local generation = opening
        maskNative(self)
        setReaderVisible(false, true)
        scheduleRefresh()
        C_Timer.After(0.25, function()
            if generation == opening and dialogueEnabled() and self:IsShown() and (not current or current.native ~= self) then
                -- A panel Bazi cannot render remains usable through Blizzard's window.
                restoreNative(self)
            end
        end)
    end
    frame:HookScript("OnShow", onShow)
    frame:HookScript("OnHide", function(self)
        if not dialogueEnabled() then return end
        maskNative(self)
        scheduleRefresh()
    end)
    if dialogueEnabled() then
        if frame:IsShown() then onShow(frame) else maskNative(frame) end
    end
end

local function refreshSoon(_, event, interaction)
    if event == "GET_ITEM_INFO_RECEIVED" and (not current or (current.phase ~= "detail" and current.phase ~= "reward")) then return end
    if event == "QUEST_LOG_UPDATE" and (not current or (current.phase ~= "gossip" and current.phase ~= "greeting")) then return end
    watchNative(_G.QuestFrame)
    watchNative(_G.GossipFrame)
    local api = _G.Spoken
    if not playbackWatched and api and api.RegisterCallback then
        playbackWatched = true
        api:RegisterCallback("CLIP_STARTED", function()
            if not addon.db or not dialogue.Settings().enabled or not voice.OwnsHead() then return end
            if npcTransition() then setReaderVisible(false, true) end
            maskSubtitle(true)
            elapsed = 0.06
        end)
    end
    local interactionEvent = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE"
    if interactionEvent and (not interactionTypes or (interaction ~= interactionTypes.Gossip and interaction ~= interactionTypes.QuestGiver)) then return end
    if interactionEvent or readerTransitions[event] then
        readerAfter = GetTime() + 0.25
        setReaderVisible(false, true)
        if addon.db and dialogue.Settings().enabled and voice.HasNPCHead() then maskSubtitle(true) end
    end
    if event ~= "ADDON_LOADED" then scheduleRefresh() end
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_GREETING", "QUEST_FINISHED", "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", refreshSoon)
watchNative(_G.QuestFrame)
watchNative(_G.GossipFrame)
events:SetScript("OnUpdate", function(_, delta)
    if not addon.db or not addon.db.profile.dialogue or not addon.db.profile.dialogue.enabled then return end
    elapsed = (elapsed or 0) + delta
    if elapsed < 0.06 then return end
    elapsed = 0
    local playing
    if current and current.native and not shown(current.native) then dialogue.Refresh() end
    if main and main:IsShown() and current then
        local line = voice.Update(current)
        if main.body:GetText() ~= line then main.body:SetText(line) end
        refreshControls(main, current)
        playing = voice.IsCurrent(current) or voice.OwnsHead()
    else
        local pendingPage = voice.queue[queueIndex]
        if pendingPage and not pendingPage.clip then voice.Update(pendingPage) end
        playing = updateReader(dialogue.Settings())
    end
    maskSubtitle(playing)
end)
