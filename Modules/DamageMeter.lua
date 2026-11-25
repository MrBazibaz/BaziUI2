local addon = BaziUI
local meter = {}
addon.DamageMeter = meter

meter.modes = {
    {"DamageDone", "Damage done"},
    {"HealingDone", "Healing done"},
    {"DamageTaken", "Damage taken"},
    {"Absorbs", "Absorbs"},
    {"Overhealing", "Overhealing"},
    {"HealingTaken", "Healing received"},
}
local defaults = {
    enabled = false, mode = "DamageDone", rows = 5, width = 340, barHeight = 22,
    x = 320, y = -180, opacity = 70, header = true, gradient = "Right",
    font = "general", fontSize = 0, outline = "OUTLINE", hoverSpells = true,
    textColorMode = "class", showRanks = true,
    showAmount = true, showRate = true, showPercent = true,
    headerFont = "general", headerFontSize = 0, headerOutline = "OUTLINE",
}

function meter.Settings(index)
    local profile = addon.db.profile
    profile.damageMeter = profile.damageMeter or {}
    local settings = profile.damageMeter
    if index == 2 then
        if not settings.second then settings.second = {mode = "HealingDone", x = settings.x or 320, y = (settings.y or -180) - 180} end
        settings = settings.second
    end
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end
    if not settings.textColor then settings.textColor = {1, 1, 1} end
    if not settings.headerTextColor then settings.headerTextColor = {1, 0.82, 0.49} end
    return settings
end

local function readable(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

local function number(value)
    if readable(value) and type(value) == "number" then return value end
end

local function call(fn, ...)
    if not fn then return end
    local ok, result = pcall(fn, ...)
    if ok then return result end
end

local numberScales = {{1e9, "b"}, {1e6, "m"}, {1e3, "k"}}
local function abbreviate(value)
    if not readable(value) then
        local text = call(AbbreviateNumbers, value)
        if not readable(text) or text ~= nil then return text end
        return call(AbbreviateLargeNumbers, value)
    end
    if type(value) ~= "number" then return end
    for _, scale in ipairs(numberScales) do
        if math.abs(value) >= scale[1] then
            return ("%.1f"):format(value / scale[1]):gsub("%.0$", "") .. scale[2]
        end
    end
    return ("%.0f"):format(value)
end

local suffixes = {FRIZQT = "FRIZQT__.TTF", ARIAL = "ARIALN.TTF", MORPHEUS = "MORPHEUS.TTF"}
local function fontPath(selected)
    local key = selected == "general" and addon.db.profile.font or selected
    if suffixes[key] then return "Fonts\\" .. suffixes[key] end
    local object = key and _G[key]
    if object and object.GetFont then return object:GetFont() end
    return GameFontNormal:GetFont()
end

local function applyFont(region, db, isHeader)
    local override = isHeader and db.headerFontSize or db.fontSize
    local size = override > 0 and override or addon.Typography.BaseSize()
    local path = fontPath(isHeader and db.headerFont or db.font)
    local outline = isHeader and db.headerOutline or db.outline
    local selected = isHeader and db.headerFont or db.font
    local shadow
    path, size, outline, shadow = addon.Typography.Resolve(isHeader and "Combat:Header" or "Combat:Rows",
        path, size, outline, selected == "general")
    addon.Typography.Shadow(region, shadow)
    if region.meterFont ~= path or region.meterSize ~= size or region.meterOutline ~= outline then
        region:SetFont(path, size, outline)
        region.meterFont, region.meterSize, region.meterOutline = path, size, outline
    end
end

local roster = {}
local rosterReady

local function updateRoster()
    rosterReady = true
    wipe(roster)
    local guid = UnitGUID("player")
    if readable(guid) and guid then roster[guid] = true end
    local inRaid = IsInRaid()
    local prefix = inRaid and "raid" or "party"
    local size = inRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i = 1, size do
        local member = UnitGUID(prefix .. i)
        if readable(member) and member then roster[member] = true end
    end
end

local function inGroup(source)
    local guid = source.sourceGUID
    if not readable(guid) or type(guid) ~= "string" or not guid:match("^Player%-") then
        return true
    end
    local isPlayer = source.isLocalPlayer
    return roster[guid] == true or (readable(isPlayer) and isPlayer == true)
end

local function modeInfo(db)
    for _, mode in ipairs(meter.modes) do
        if db.mode == mode[1] and Enum and Enum.DamageMeterType and Enum.DamageMeterType[mode[1]] ~= nil then
            return mode
        end
    end
    return meter.modes[1]
end

function meter.Available()
    return C_DamageMeter and C_DamageMeter.GetCombatSessionFromType
        and Enum and Enum.DamageMeterSessionType and Enum.DamageMeterType
end

local windows = {}
local previews = {}
local lastGroup, lastInstance, pendingReset
local overallGeneration, currentRevision = 0, {}

local function reset()
    if not (C_DamageMeter and C_DamageMeter.ResetAllCombatSessions) then return end
    local ok = pcall(C_DamageMeter.ResetAllCombatSessions)
    if not ok then
        addon:Print("WoW could not reset the damage meter right now.")
        return
    end
    for _, window in pairs(windows) do window.ClearSelection() end
    meter.Refresh()
end

function meter.ConfirmReset()
    if not (C_DamageMeter and C_DamageMeter.ResetAllCombatSessions) then return end
    StaticPopupDialogs.BAZIUI_DAMAGE_METER_RESET = StaticPopupDialogs.BAZIUI_DAMAGE_METER_RESET or {
        text = "Reset all WoW damage meter sessions?", button1 = RESET, button2 = CANCEL,
        OnAccept = reset, timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("BAZIUI_DAMAGE_METER_RESET")
end

local function createWindow(index)
    local frame, heading, header, emptyText, mainPanel, ticker
    local rows = {}
    local selected, lastSession, lastMode, currentReady
    local savedOverall, currentBaseline, savedGeneration
    local transition, transitionAnimation
    local scrollOffset = 0
    local rail, railThumb, sliderThumb, sizingRail, ornament
    local hoveredRow
    local window = {}
    function window.ClearSelection()
        selected, scrollOffset = nil, 0
    end

    local function hideHover(row)
        if hoveredRow == row then
            hoveredRow = nil
            if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        end
    end

    local function clickRow(row, button)
        hideHover(row)
        if button == "RightButton" then
            if selected then
                selected, scrollOffset = nil, 0
                window.Refresh()
            end
        elseif not selected and row.source then
            local source = row.source
            local guid, creature = source.sourceGUID, source.sourceCreatureID
            if not readable(guid) then guid = nil end
            if not readable(creature) then creature = nil end
            if guid == nil and creature == nil then
                addon:Print("WoW has hidden this player's spell details for now.")
                return
            end
            selected = {guid = guid, creature = creature, name = source.name, class = source.classFilename,
                preview = source.preview, totalAmount = source.totalAmount}
            scrollOffset = 0
            window.Refresh()
        end
    end

    function window.RefreshHeader()
        if not header then return end
        local r, g, b, opacity = 0.15, 0.15, 0.19, 0.43
        local chat = addon.Chat
        if chat and chat.active and chat.Skin and chat.Skin.DockHeaderColor then
            r, g, b, opacity = chat.Skin.DockHeaderColor()
        else
            local quest = addon.db.profile.questTracker
            local color = quest and quest.headerColor
            if color then
                r, g, b, opacity = color[1], color[2], color[3], (quest.opacity or 85) / 100
            end
        end
        local key = index == 2 and "meter2" or "meter"
        r, g, b, opacity = addon.Headers.Fill(key, r, g, b, opacity)
        header.fill:SetColorTexture(r, g, b, opacity)
        heading:SetTextColor(addon.Headers.Text(key, unpack(meter.Settings(index).headerTextColor)))
        return r, g, b
    end

    local function ornamentInset()
        local tracker = addon.QuestTracker
        local quest, track
        if tracker and tracker.GetAccentTrack then quest, track = tracker.GetAccentTrack() end
        if not quest or math.abs(quest:GetWidth() - frame:GetWidth()) > 1 then return 6 end
        local left, right = track:GetLeft(), frame:GetLeft()
        local top, bottom = frame:GetTop(), frame:GetBottom()
        local questTop, questBottom = quest:GetTop(), quest:GetBottom()
        if not (left and right and top and bottom and questTop and questBottom) then return 6 end
        if math.min(math.abs(top - questBottom), math.abs(questTop - bottom)) > 10 then return 6 end
        local inset = left - right
        if math.abs(inset - 6) > 4 then return 6 end
        return inset
    end

    local function build()
        frame = CreateFrame("Frame", index == 1 and "BaziUIDamageMeter" or "BaziUIDamageMeter2", UIParent)
        frame:Hide()
        frame:SetSize(340, 155)
        frame:EnableMouse(true)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, delta)
            scrollOffset = math.max(0, scrollOffset - delta)
            window.Refresh()
        end)
        frame:SetScript("OnMouseUp", function(_, button) clickRow(frame, button) end)

        frame.fill = frame:CreateTexture(nil, "BACKGROUND")
        frame.border = addon.Theme:CreateFrameBorder(frame, frame, frame)
        addon.Theme:AddDropShadow("Combat", frame, frame.border)
        header = CreateFrame("Frame", nil, frame)
        header:SetPoint("TOPLEFT", 3, -2)
        header:SetPoint("TOPRIGHT", -3, -2)
        header:SetHeight(30)
        header.fill = header:CreateTexture(nil, "BACKGROUND")
        header.fill:SetAllPoints()
        heading = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("LEFT", 14, 0)
        heading:SetJustifyH("LEFT")
        heading:SetWordWrap(false)

        local modeButton = CreateFrame("Button", nil, header)
        modeButton:SetSize(21, 22)
        modeButton:SetPoint("RIGHT", -3, 0)
        local arrow = modeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrow:SetPoint("CENTER")
        arrow:SetText("v")
        modeButton:SetScript("OnClick", function(owner)
            if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
            MenuUtil.CreateContextMenu(owner, function(_, menu)
                for _, mode in ipairs(meter.modes) do
                    if Enum.DamageMeterType[mode[1]] ~= nil then
                        menu:CreateRadio(mode[2], function() return meter.Settings(index).mode == mode[1] end,
                            function() meter.SetMode(mode[1], index) end)
                    end
                end
            end)
        end)
        heading:SetPoint("RIGHT", modeButton, "LEFT", -3, 0)

        mainPanel = CreateFrame("Frame", nil, frame)
        mainPanel:SetPoint("BOTTOMLEFT", 5, 5)
        rail = CreateFrame("Slider", nil, frame)
        rail:SetOrientation("VERTICAL")
        rail:SetWidth(8)
        sliderThumb = rail:CreateTexture(nil, "BACKGROUND")
        sliderThumb:SetSize(8, 1)
        sliderThumb:SetColorTexture(0, 0, 0, 0)
        rail:SetThumbTexture(sliderThumb)
        railThumb = rail:CreateTexture(nil, "OVERLAY")
        railThumb:SetWidth(4)
        rail:SetValueStep(1)
        rail:SetScript("OnValueChanged", function(_, value)
            if sizingRail then return end
            scrollOffset = math.floor(value + 0.5)
            window.Refresh()
        end)
        local ornamentLayer = CreateFrame("Frame", nil, frame)
        ornamentLayer:SetAllPoints()
        ornamentLayer:SetFrameLevel(frame:GetFrameLevel() + 25)
        ornamentLayer:EnableMouse(false)
        ornament = addon.Theme:RailOrnament(ornamentLayer, frame, 6)
        rail:SetFrameLevel(ornamentLayer:GetFrameLevel() + 1)
        mainPanel:SetPoint("BOTTOMRIGHT", -5, 5)
        frame.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
        frame.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
        local messageLayer = CreateFrame("Frame", nil, mainPanel)
        messageLayer:SetAllPoints()
        messageLayer:SetFrameLevel(mainPanel:GetFrameLevel() + 12)
        emptyText = messageLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        emptyText:SetPoint("CENTER")
        emptyText:SetWidth(265)

        transition = messageLayer:CreateTexture(nil, "OVERLAY")
        transition:SetAllPoints()
        transition:Hide()
        transitionAnimation = transition:CreateAnimationGroup()
        local fade = transitionAnimation:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(0.32)
        fade:SetSmoothing("OUT")
        transitionAnimation:SetScript("OnFinished", function() transition:Hide() end)
    end

    local function rowAt(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Button", nil, mainPanel)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", clickRow)
        row:SetScript("OnEnter", function(self)
            if self.source and meter.Settings(index).hoverSpells then
                hoveredRow = self
                window.Refresh()
            end
        end)
        row:SetScript("OnLeave", hideHover)
        row:SetScript("OnHide", hideHover)
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetAllPoints()
        local background = row.bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        row.background = background
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.11)
        row.values = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.values:SetPoint("RIGHT", -5, 0)
        row.name = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", 5, 0)
        row.name:SetPoint("RIGHT", row.values, "LEFT", -6, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        rows[index] = row
        return row
    end

    local function measure(entries)
        local maximum, total, readableTotal = 0, 0, true
        for _, entry in ipairs(entries) do
            local value = number(entry.totalAmount)
            if value then
                maximum = math.max(maximum, value)
                total = total + value
            else
                readableTotal = false
            end
        end
        return maximum, readableTotal and total or nil
    end

    local function spellName(entry)
        if entry.name then return entry.name end
        local id = number(entry.spellID)
        local name = id and C_Spell and call(C_Spell.GetSpellName, id)
        if not readable(name) or name then return name end
        return id and ("Spell " .. id) or "Unknown spell"
    end

    local function paintRow(row, entry, db, maxValue, total, duration, rank, soleSource)
        local value = entry.totalAmount
        local numeric = number(value)
        local rate = entry.amountPerSecond
        if readable(rate) and rate == nil and numeric and duration and duration > 0 then rate = numeric / duration end
        local class = selected and selected.class or entry.classFilename
        local tint = readable(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        local r, g, b = 0.73, 0.57, 0.35
        if tint then r, g, b = tint.r, tint.g, tint.b end
        local texture = "Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziHealthGradient" .. db.gradient .. ".tga"
        if row.texture ~= texture then row.bar:SetStatusBarTexture(texture); row.texture = texture end
        -- Same class-color multiplier as the UnitFrames health bar.
        row.bar:SetStatusBarColor(r * 0.53, g * 0.53, b * 0.53, 0.96)
        local tr, tg, tb = 1, 1, 1
        if db.textColorMode == "custom" then
            tr, tg, tb = unpack(db.textColor)
        elseif db.textColorMode == "class" then
            tr, tg, tb = r * 0.82, g * 0.82, b * 0.82
        end
        row.name:SetTextColor(tr, tg, tb)
        row.values:SetTextColor(tr, tg, tb)
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        local scale = number(maxValue)
        if not scale or scale > 0 then
            if pcall(row.bar.SetMinMaxValues, row.bar, 0, maxValue) then
                pcall(row.bar.SetValue, row.bar, value)
            end
        end

        applyFont(row.name, db)
        applyFont(row.values, db)
        local name = entry.name
        if selected then
            name = spellName(entry)
        elseif readable(name) and (type(name) ~= "string" or name == "") then
            name = "Unknown"
        end
        if not selected and db.showRanks then
            if not pcall(row.name.SetFormattedText, row.name, "%d. %s", rank, name) then row.name:SetText(name) end
        else
            row.name:SetText(name)
        end
        local formats, values, fallback = {}, {}, {}
        local function add(format, text, unavailable)
            formats[#formats + 1] = format
            values[#values + 1] = text
            fallback[#fallback + 1] = unavailable
        end
        if db.showAmount then
            local text = abbreviate(value)
            if readable(text) and text == nil and not readable(value) then
                add("%.0f", value, "—")
            else
                if readable(text) and text == nil then text = "—" end
                add("%s", text, readable(text) and text or "—")
            end
        end
        if db.showRate and not selected then
            if not readable(rate) then
                add("%.0f", rate, "—")
            else
                local text = type(rate) == "number" and ("%.0f"):format(rate) or "—"
                add("%s", text, text)
            end
        end
        if db.showPercent then
            local text = soleSource and not selected and "100%"
                or numeric and total and total > 0 and ("%.0f%%"):format(numeric * 100 / total)
            if text then add("%s", text, text) end
        end
        if #formats == 0 or not pcall(row.values.SetFormattedText, row.values, table.concat(formats, " - "), unpack(values)) then
            row.values:SetText(table.concat(fallback, " - "))
        end
        row.source = not selected and entry or nil
    end

    local function spellData(source, sessionType, mode)
        if source.preview then
            local total = source.totalAmount
            return {combatSpells = {
                {name = "Opening strike", totalAmount = math.floor(total * 0.55)},
                {name = "Follow-up", totalAmount = math.floor(total * 0.30)},
                {name = "Finisher", totalAmount = math.floor(total * 0.15)},
            }}
        end
        local guid, creature = source.sourceGUID, source.sourceCreatureID
        if readable(guid) and guid == nil then guid = source.guid end
        if readable(creature) and creature == nil then creature = source.creature end
        if not readable(guid) then guid = nil end
        if not readable(creature) then creature = nil end
        if guid == nil and creature == nil then return end
        return call(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, mode, guid, creature)
    end

    local function petSource(spell)
        local creature = spell.creatureName
        local details = spell.combatSpellDetails
        local pet = readable(details) and type(details) == "table" and details.isPet
        if readable(creature) and type(creature) == "string" and creature ~= "" then return true, creature end
        if readable(pet) and pet == true then return true, "Pet" end
        if not readable(creature) or not readable(pet) then return nil end
        return false
    end

    local function updateHover(row, sessionType, mode)
        if not row.source or not meter.Settings(index).hoverSpells or not GameTooltip or (GameTooltip.IsForbidden and GameTooltip:IsForbidden()) then
            hideHover(row)
            return
        end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        local source = row.source
        pcall(GameTooltip.AddLine, GameTooltip, source.name, 1, 0.82, 0.48)
        local data = spellData(source, sessionType, mode)
        local spells = data and data.combatSpells or {}
        local _, total = measure(spells)
        local split = Enum and Enum.DamageMeterType and mode == Enum.DamageMeterType.DamageDone
        if split then
            local player, pets, hasPet, known = 0, 0, false, true
            for _, spell in ipairs(spells) do
                local pet = petSource(spell)
                local value = number(spell.totalAmount)
                if pet then hasPet = true end
                if pet == nil or value == nil then
                    known = false
                elseif pet then
                    pets = pets + value
                else
                    player = player + value
                end
            end
            if hasPet and known then
                GameTooltip:AddDoubleLine("Player damage", abbreviate(player), 0.85, 0.85, 0.85, 1, 0.85, 0.62)
                GameTooltip:AddDoubleLine("Pet damage", abbreviate(pets), 0.85, 0.85, 0.85, 1, 0.85, 0.62)
                GameTooltip:AddLine(" ")
            end
        end
        for i = 1, math.min(8, #spells) do
            local spell = spells[i]
            local raw = number(spell.totalAmount)
            local value = abbreviate(spell.totalAmount)
            if readable(value) then
                value = (value or "—") .. (raw and total and total > 0 and ("  ·  %.0f%%"):format(raw * 100 / total) or "")
            end
            local name = spellName(spell)
            if split then
                local pet, petName = petSource(spell)
                if pet and readable(name) then name = name .. " (" .. petName .. ")" end
            end
            pcall(GameTooltip.AddDoubleLine, GameTooltip, name, value, 1, 1, 1, 1, 0.85, 0.62)
        end
        if #spells == 0 then GameTooltip:AddLine("Spell details unavailable", 0.75, 0.75, 0.75) end
        if #spells > 8 then GameTooltip:AddLine("Click to see all spells", 0.75, 0.75, 0.75) end
        GameTooltip:Show()
    end

    local previewClasses = {"WARRIOR", "HUNTER", "MAGE", "PRIEST", "ROGUE", "DRUID", "PALADIN", "WARLOCK"}
    local previewNames = {"Bran Ironhand", "Ayla Foxtrail", "Orrin Brightspark", "Mira Dawnlight",
        "Nessa Shade", "Tarin Mosswood", "Edda Goldcrest", "Kellan Ashfall"}
    local function readRanking(sessionType, mode)
        if previews[index] then
            local entries = {}
            local now = GetTime and GetTime() or 0
            for i, name in ipairs(previewNames) do
                local amount = math.floor(21800 * (1.12 - i * 0.115) + 130 * math.sin(now + i))
                entries[i] = {name = name, classFilename = previewClasses[i], sourceGUID = "preview-" .. i,
                    totalAmount = amount, amountPerSecond = amount / 14, preview = true}
            end
            return {durationSeconds = 14}, entries
        end
        local data = call(C_DamageMeter.GetCombatSessionFromType, sessionType, mode)
        local entries = {}
        for _, entry in ipairs(data and data.combatSources or {}) do
            if inGroup(entry) then entries[#entries + 1] = entry end
        end
        return data, entries
    end

    function window.Refresh()
        local db = meter.Settings(index)
        local arranging = addon.Movers and addon.Movers.IsActive()
        if not db.enabled and not previews[index] and not arranging then
            if hoveredRow then hideHover(hoveredRow) end
            if ticker then ticker:Cancel(); ticker = nil end
            if frame then frame:Hide() end
            currentReady, lastSession = nil, nil
            return
        end
        if not frame then build() end
        if not ticker then ticker = C_Timer.NewTicker(0.30, window.Refresh) end

        local fighting = UnitAffectingCombat("player")
        local playerInCombat = previews[index] or (InCombatLockdown and InCombatLockdown()) or (readable(fighting) and fighting == true)
        local sessions = Enum and Enum.DamageMeterSessionType
        local info = modeInfo(db)
        local mode = meter.Available() and Enum.DamageMeterType[info[1]]
        if savedGeneration ~= overallGeneration or lastMode ~= mode then
            savedOverall, currentBaseline, currentReady = nil, nil, false
            savedGeneration = overallGeneration
        end
        local sessionType = sessions and sessions.Overall
        local data, entries
        if previews[index] then
            sessionType = sessions and sessions.Current
            data, entries = readRanking(sessionType, mode)
        elseif not playerInCombat and sessions and mode ~= nil then
            currentReady = false
            data, entries = readRanking(sessions.Overall, mode)
            local _, total = measure(entries)
            if total then savedOverall = {data = data, entries = entries} end
            currentBaseline = currentRevision[mode] or 0
        elseif playerInCombat and sessions and mode ~= nil then
            local fight, sources = readRanking(sessions.Current, mode)
            if not currentReady and (currentRevision[mode] or 0) > (currentBaseline or 0) then
                for _, source in ipairs(sources) do
                    local value = source.totalAmount
                    if not readable(value) or (number(value) or 0) > 0 then
                        currentReady = true
                        break
                    end
                end
            end
            if currentReady then
                sessionType, data, entries = sessions.Current, fight, sources
            elseif savedOverall then
                data, entries = savedOverall.data, savedOverall.entries
            else
                entries = {}
            end
        end
        local switched = lastSession ~= nil and lastSession ~= sessionType
        if lastSession ~= sessionType or lastMode ~= mode then
            selected, scrollOffset = nil, 0
            lastSession, lastMode = sessionType, mode
        end
        if selected then
            data = spellData(selected, sessionType, mode)
            entries = data and data.combatSpells or {}
        elseif not entries and sessionType ~= nil and mode ~= nil then
            data, entries = readRanking(sessionType, mode)
        end
        entries = entries or {}
        local maximum, total = measure(entries)
        if data and not selected and #entries > 0 then
            local nativeMaximum = data.maxAmount
            if not readable(nativeMaximum) or (maximum == 0 and number(nativeMaximum)) then maximum = nativeMaximum end
            if not total and data.combatSources and #entries == #data.combatSources then total = number(data.totalAmount) end
        end
        if selected and not readable(entries[1] and entries[1].totalAmount) then maximum = entries[1].totalAmount end
        if readable(maximum) and maximum <= 0 then maximum = 1 end
        scrollOffset = math.min(math.max(0, #entries - db.rows), scrollOffset)
        local count = math.min(db.rows, #entries)
        local unavailable = mode == nil or (C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable
            and call(C_DamageMeter.IsDamageMeterAvailable) == false)
        local showEmpty = count == 0 and (selected ~= nil or (db.header and unavailable))
        local area = db.rows * (db.barHeight + 2)
        if not (addon.Movers and addon.Movers.IsDragging(frame)) then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
        end
        frame:SetSize(db.width, area + (db.header and 39 or 10))
        frame.fill:SetColorTexture(0, 0, 0, db.opacity / 100)
        local headerR, headerG, headerB = window.RefreshHeader()
        mainPanel:SetHeight(area)
        local extra = math.max(0, #entries - db.rows)
        local step = db.barHeight + 2
        sizingRail = true
        rail:SetMinMaxValues(0, math.max(1, extra))
        rail:SetValue(scrollOffset)
        sizingRail = nil
        local inset = ornamentInset()
        mainPanel:SetPoint("BOTTOMLEFT", math.max(5, inset + (extra > 0 and 4 or 2)), 5)
        ornament.track:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -6)
        ornament.track:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, 6)
        addon.Theme:ColorRailOrnament(ornament, true, true)
        rail:ClearAllPoints()
        if db.header then
            rail:SetPoint("TOP", header, "BOTTOMLEFT", inset - 2.5, -1)
        else
            rail:SetPoint("TOP", ornament.track, "TOP", 0, -ornament.capThickness)
        end
        rail:SetPoint("BOTTOM", ornament.track, "BOTTOM", 0, ornament.capThickness)
        rail:SetShown(extra > 0)
        rail:EnableMouse(extra > 0)
        if extra > 0 then
            railThumb:SetColorTexture(addon.Theme:AccentInk(0.9))
            addon.Theme:PlaceRailThumb(rail, railThumb, sliderThumb, area, extra * step, scrollOffset / extra)
        end
        header:SetShown(db.header)
        frame:Show()
        if switched and count > 0 then
            transitionAnimation:Stop()
            transition:SetColorTexture(headerR * 0.8 + 0.2, headerG * 0.8 + 0.2, headerB * 0.8 + 0.2, 0.30)
            transition:Show()
            transitionAnimation:Play()
        end
        emptyText:SetWidth(db.width - 20)
        emptyText:SetShown(showEmpty)
        if showEmpty then
            emptyText:SetText(selected and "Spell details unavailable · Right-click to go back"
                or "WoW’s damage meter is unavailable.")
        end
        applyFont(heading, db, true)
        if selected then
            heading:SetText(selected.name)
        else
            heading:SetText(info[2] .. "  ·  " .. (previews[index] and "Preview" or currentReady and "Current fight" or "Overall"))
        end
        for i = 1, db.rows do
            local row = rowAt(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", mainPanel, "TOPLEFT", 0, -(i - 1) * (db.barHeight + 2))
            row:SetPoint("TOPRIGHT", mainPanel, "TOPRIGHT", 0, -(i - 1) * (db.barHeight + 2))
            row:SetHeight(db.barHeight)
            row.background:SetColorTexture(1, 1, 1, db.opacity / 1000)
            local entry = entries[i + scrollOffset]
            if entry then
                paintRow(row, entry, db, maximum, total, data and number(data.durationSeconds), i + scrollOffset, #entries == 1)
            else
                row.source = nil
                row.name:SetText("")
                row.values:SetText("")
                row.bar:SetMinMaxValues(0, 1)
                row.bar:SetValue(0)
            end
            row:EnableMouse(entry ~= nil)
            row:Show()
        end
        for i = db.rows + 1, #rows do
            rows[i].source = nil
            rows[i]:Hide()
        end
        if hoveredRow then updateHover(hoveredRow, sessionType, mode) end
    end
    return window
end

function meter.HasSecondWindow()
    return meter.Settings().second ~= nil
end

function meter.AddWindow()
    meter.Settings(2).enabled = true
    meter.Refresh()
end

function meter.IsPreview(index)
    return previews[index] == true
end

function meter.SetPreview(index, enabled)
    previews[index] = enabled and true or nil
    if windows[index] then windows[index].ClearSelection() end
    meter.Refresh()
end

function meter.SetMode(mode, index)
    index = index or 1
    meter.Settings(index).mode = mode
    if windows[index] then windows[index].ClearSelection() end
    meter.Refresh()
end

function meter.RefreshHeader()
    for _, window in pairs(windows) do window.RefreshHeader() end
end

function meter.Refresh()
    if not rosterReady then updateRoster() end
    local first = meter.Settings()
    local second = first.second
    if not first.enabled and not (second and second.enabled) then pendingReset = nil end
    for i = 1, second and 2 or 1 do
        if not windows[i] then windows[i] = createWindow(i) end
        windows[i].Refresh()
    end
end

local function checkResetTrigger(event, initialLogin, reloading)
    local db = meter.Settings()
    local grouped = IsInGroup()
    local _, instanceType, difficulty, _, _, _, _, mapID = GetInstanceInfo()
    local instance = instanceType and instanceType ~= "none" and (instanceType .. ":" .. tostring(mapID) .. ":" .. tostring(difficulty)) or false
    local joined = lastGroup == false and grouped
    local entered = lastInstance ~= nil and instance and instance ~= lastInstance
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then lastGroup = grouped end
    if event == "PLAYER_ENTERING_WORLD" then lastInstance = instance end
    if initialLogin or reloading or not (db.enabled or (db.second and db.second.enabled)) then return end
    if ((event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD") and joined and db.resetOnGroup)
        or (event == "PLAYER_ENTERING_WORLD" and entered
            and ((instanceType == "party" and db.resetOnDungeon) or (instanceType == "raid" and db.resetOnRaid)
                or ((instanceType == "pvp" or instanceType == "arena") and db.resetOnPvP))) then
        pendingReset = true
    end
    if pendingReset and not InCombatLockdown() then
        pendingReset = nil
        reset()
    end
end

local watcher = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    watcher:RegisterEvent(event)
end
pcall(watcher.RegisterEvent, watcher, "DAMAGE_METER_RESET")
pcall(watcher.RegisterEvent, watcher, "DAMAGE_METER_COMBAT_SESSION_UPDATED")
watcher:SetScript("OnEvent", function(_, event, initialLogin, reloading)
    if not addon.db then return end
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if number(initialLogin) then currentRevision[initialLogin] = (currentRevision[initialLogin] or 0) + 1 end
        return
    end
    if event == "DAMAGE_METER_RESET" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        overallGeneration = overallGeneration + 1
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        checkResetTrigger(event, event == "PLAYER_ENTERING_WORLD" and initialLogin, event == "PLAYER_ENTERING_WORLD" and reloading)
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then updateRoster() end
    meter.Refresh()
end)
