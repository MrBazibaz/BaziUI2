local addon = BaziUI
local inventory = addon.Inventory
local frame, content, historyButton, guide, guideFrame, emptyLabel, closeBar
local active, demo, history, rows = {}, {}, {}, {}
local historyMode, demoMode
local resultDuration = 5
local names = {[0] = "Pass", [1] = "Need", [2] = "Greed"}
local rollAtlases = {[0] = "lootroll-toast-icon-pass-up", [1] = "lootroll-toast-icon-need-up",
    [2] = "lootroll-toast-icon-greed-up"}
local historyStates = {[0] = "Need", [1] = "Off-spec Need", [2] = "Transmog",
    [3] = "Greed", [4] = "Deciding", [5] = "Pass"}
local stateChoices = {[0] = 1, [1] = 1, [3] = 2, [5] = 0, Need = 1, Greed = 2, Pass = 0}
local function safe(value)
    if not (issecretvalue and issecretvalue(value)) then return value end
end

local function removeExpired(now)
    local changed
    for id, drop in pairs(active) do
        if now >= (drop.showUntil or drop.deadline + resultDuration) then
            active[id], changed = nil, true
        end
    end
    return changed
end

local function winnerName(name)
    return name:match("^[^%s%-]+") or name
end

local function finishDemo(drop)
    local name, class, best
    local function consider(player, playerClass, choice, result)
        if choice ~= 1 and choice ~= 2 then return end
        local score = (choice == 1 and 100 or 0) + (result or 0)
        if not best or score > best then name, class, best = player, playerClass, score end
    end
    local player, realm = UnitFullName("player")
    consider(player and (realm and realm ~= "" and player .. "-" .. realm or player) or "You",
        select(2, UnitClass("player")), drop.choice, 64)
    for _, player in ipairs(drop.players) do
        consider(player.playerName, player.playerClass, stateChoices[player.state], player.roll)
    end
    drop.finished, drop.winner, drop.winnerClass = true, name, class
end

local function tooltip(row)
    local drop = row.drop
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    if drop.link then GameTooltip:SetHyperlink(drop.link) else GameTooltip:SetText(drop.name) end
    if drop.players and #drop.players > 0 then
        GameTooltip:AddLine(" ")
        for _, player in ipairs(drop.players) do
            local class = safe(player.playerClass)
            local color = class and RAID_CLASS_COLORS[class]
            local state = safe(player.state)
            local choice = historyStates[state] or tostring(state or "Deciding")
            GameTooltip:AddDoubleLine(safe(player.playerName) or "Unknown",
                choice .. (safe(player.roll) and "  " .. player.roll or ""),
                color and color.r or 1, color and color.g or 1, color and color.b or 1, 0.9, 0.85, 0.75)
        end
    end
    GameTooltip:Show()
end

local function makeRow(i)
    local row = CreateFrame("Frame", nil, content)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 46)
    row:SetPoint("RIGHT", content, "RIGHT")
    row:SetHeight(43)
    row:EnableMouse(true)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.29, 0.17, 0.09, 0.65)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(31, 31)
    row.icon:SetPoint("LEFT", 5, 0)
    row.title = inventory.Label(row)
    row.title:SetPoint("TOPLEFT", 42, -5)
    row.title:SetPoint("RIGHT", -104, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.winner = inventory.Label(row)
    row.winner:SetPoint("RIGHT", row, "RIGHT", -106, 0)
    row.winner:SetWidth(88)
    row.winner:SetJustifyH("RIGHT")
    row.winner:SetWordWrap(false)
    row.result = inventory.Label(row)
    row.result:SetPoint("BOTTOMLEFT", 42, 6)
    row.mine = row:CreateTexture(nil, "OVERLAY")
    row.mine:SetSize(20, 20)
    row.mine:SetPoint("LEFT", row.result, "RIGHT", 9, 0)
    row.timer = CreateFrame("StatusBar", nil, row)
    row.timer:SetPoint("BOTTOMLEFT")
    row.timer:SetPoint("BOTTOMRIGHT")
    row.timer:SetHeight(2)
    row.timer:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.timer:SetStatusBarColor(0.79, 0.58, 0.25)
    row:SetScript("OnEnter", tooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.buttons = {}
    for index, choice in ipairs({1, 2, 0}) do
        local button = CreateFrame("Button", nil, row)
        button:SetSize(29, 29)
        button:SetPoint("RIGHT", -5 - (3 - index) * 32, 0)
        local function art()
            local texture = button:CreateTexture()
            texture:SetAllPoints()
            texture:SetAtlas(rollAtlases[choice])
            return texture
        end
        button:SetNormalTexture(art())
        local disabled = art()
        disabled:SetDesaturated(true)
        disabled:SetAlpha(0.45)
        button:SetDisabledTexture(disabled)
        local highlight = art()
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.35)
        button:SetHighlightTexture(highlight)
        button:SetScript("OnClick", function()
            local drop = row.drop
            if not drop or drop.choice or drop.finished then return end
            if not drop.demo then
                if (safe(GetLootRollTimeLeft(drop.id)) or 0) <= 0 then return end
                RollOnLoot(drop.id, choice)
            end
            drop.choice = choice
            inventory.RefreshRolls()
        end)
        button:SetScript("OnEnter", function(self)
            local db = inventory.Settings()
            if db.rollGlow then self:LockHighlight() end
            if db.rollTips then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(names[choice])
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function(self)
            self:UnlockHighlight()
            GameTooltip:Hide()
        end)
        row.buttons[choice] = button
    end
    rows[i] = row
    return row
end

local function build()
    local header
    frame, header = inventory.Window("BaziUIInventoryRolls", "Loot Rolls", 425, 310, nil, nil, "rollOpacity")
    frame.lootLinked = true
    frame.closeButton:Hide()
    historyButton = inventory.Button(header, "History", 67, function()
        historyMode = not historyMode
        inventory.RefreshRolls()
    end)
    historyButton:SetPoint("RIGHT", -4, 0)
    guideFrame = CreateFrame("Frame", nil, frame)
    guideFrame:SetPoint("TOPLEFT", 9, -31)
    guideFrame:SetPoint("TOPRIGHT", -10, -31)
    guideFrame:SetHeight(67)
    guide = inventory.Label(guideFrame)
    guide:SetPoint("TOPLEFT", 0, -1)
    guide:SetPoint("TOPRIGHT", 0, -1)
    guide:SetJustifyH("LEFT")
    guide:SetText("|cffffd366Need|r · Main spec upgrade.\n|cffffd366Greed|r · Off-spec or something you might use.\n|cffffd366Pass|r · Let someone else have it. Need beats Greed.")
    local dismiss = addon.Theme:CreateCheckbox(guideFrame)
    dismiss:SetSize(20, 20)
    dismiss:SetScript("OnClick", function(self)
        inventory.Settings().hideRollGuide = not not self:GetChecked()
        inventory.RefreshRolls()
    end)
    dismiss:SetPoint("BOTTOMLEFT", -3, 0)
    local hint = inventory.Label(guideFrame)
    hint:SetPoint("LEFT", dismiss, "RIGHT", 3, 0)
    hint:SetText("Don't show again")
    closeBar = CreateFrame("StatusBar", nil, frame)
    closeBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    closeBar:SetStatusBarColor(0.90, 0.60, 0.22)
    closeBar:SetPoint("BOTTOMLEFT", 6, 4)
    closeBar:SetPoint("BOTTOMRIGHT", -6, 4)
    closeBar:SetHeight(3)
    closeBar:SetMinMaxValues(0, resultDuration)
    closeBar:Hide()
    local scroll
    content, scroll = inventory.Scroll(frame, -83, 8)
    frame.scroll = scroll
    emptyLabel = inventory.Label(content)
    emptyLabel:SetPoint("TOPLEFT", 5, -4)
    emptyLabel:SetText("No loot rolls")
    frame:SetScript("OnUpdate", function(_, delta)
        local now = GetTime()
        if frame.closeAt then closeBar:SetValue(resultDuration - math.max(0, frame.closeAt - now)) end
        frame.elapsed = (frame.elapsed or 0) + delta
        if frame.elapsed < 0.1 then return end
        frame.elapsed = 0
        local changed = false
        if demoMode then
            for _, drop in ipairs(demo) do
                if not drop.visible and now >= drop.start then drop.visible, changed = true, true end
                for _, player in ipairs(drop.players) do
                    if player.revealAt and now >= player.revealAt then
                        player.state, player.roll, player.revealAt = player.answer, player.result, nil
                        changed = true
                    end
                end
                local waiting = false
                for _, player in ipairs(drop.players) do
                    if player.revealAt then waiting = true; break end
                end
                if not drop.finished and (now >= drop.start + drop.duration / 1000
                    or drop.choice ~= nil and not waiting) then
                    finishDemo(drop)
                    changed = true
                end
            end
        end
        for _, row in ipairs(rows) do
            local drop = row.drop
            if row:IsShown() and drop and not drop.finished then
                local left = drop.demo and math.max(0, drop.duration - (now - drop.start) * 1000)
                    or (safe(GetLootRollTimeLeft(drop.id)) or math.max(0, (drop.deadline - now) * 1000))
                row.timer:SetValue(left)
                if left <= 0 then drop.finished, drop.showUntil, changed = true, now + resultDuration, true end
            end
        end
        changed = removeExpired(now) or changed
        if changed then inventory.RefreshRolls() end
    end)
end

function inventory.RefreshRolls()
    if not frame or not frame:IsShown() then return end
    local db = inventory.Settings()
    if not demoMode and (not db.enabled or not db.rolls) then frame:Hide(); return end
    frame:ApplyStyle()
    guideFrame:SetShown(not db.hideRollGuide)
    local inset = db.hideRollGuide and 34 or 103
    frame.scroll:SetPoint("TOPLEFT", 8, -inset)
    historyButton:SetText(historyMode and "Active" or "History")
    local drops = {}
    if historyMode then
        drops = history
    else
        local now = GetTime()
        for _, drop in pairs(active) do
            if not drop.finished or (drop.showUntil or 0) > now then drops[#drops + 1] = drop end
        end
        table.sort(drops, function(a, b) return a.id < b.id end)
        if demoMode then
            for _, drop in ipairs(demo) do if drop.visible then drops[#drops + 1] = drop end end
        end
    end
    if #drops == 0 and not historyMode and not demoMode and frame.autoClose then
        frame.autoClose = nil
        frame:Hide()
        return
    end
    local closeAt
    if frame.autoClose and not historyMode and #drops > 0 then
        for _, drop in ipairs(drops) do
            if not drop.finished then closeAt = nil; break end
            closeAt = math.max(closeAt or 0, drop.showUntil or 0)
        end
    end
    frame.closeAt = closeAt
    closeBar:SetShown(closeAt ~= nil)
    if closeAt then closeBar:SetValue(resultDuration - math.max(0, closeAt - GetTime())) end
    for i, drop in ipairs(drops) do
        local row = rows[i] or makeRow(i)
        local new = row.drop ~= drop
        row.drop = drop
        row.icon:SetTexture(drop.icon)
        row.title:SetText(drop.name or drop.link or "Loot")
        row.winner:SetText(drop.winner and winnerName(drop.winner) or "")
        inventory.GeneralFont(row.winner, -2)
        local winnerColor = drop.winnerClass and RAID_CLASS_COLORS[drop.winnerClass]
        if winnerColor then row.winner:SetTextColor(winnerColor.r, winnerColor.g, winnerColor.b)
        else row.winner:SetTextColor(1, 1, 1) end
        row.winner:SetShown(drop.winner ~= nil)
        row.title:SetPoint("RIGHT", drop.winner and -196 or -104, 0)
        local color = ITEM_QUALITY_COLORS[drop.quality or 1] or ITEM_QUALITY_COLORS[1]
        row.title:SetTextColor(color.r, color.g, color.b)
        local totals = {[0] = 0, [1] = 0, [2] = 0}
        local ownChoice = drop.choice
        for _, player in ipairs(drop.players or {}) do
            local state = stateChoices[safe(player.state)]
            if state ~= nil then
                totals[state] = totals[state] + 1
                if safe(player.isSelf) then ownChoice = state end
            end
        end
        if drop.demo and ownChoice ~= nil then totals[ownChoice] = totals[ownChoice] + 1 end
        local summary = {}
        for _, choice in ipairs({1, 2, 0}) do
            summary[#summary + 1] = ("|A:%s:14:14|a %d"):format(rollAtlases[choice], totals[choice])
        end
        row.result:SetText(table.concat(summary, "   "))
        row.mine:SetShown(ownChoice ~= nil)
        if ownChoice ~= nil then row.mine:SetAtlas(rollAtlases[ownChoice]) end
        for choice, button in pairs(row.buttons) do
            button:SetShown(not historyMode)
            button:GetHighlightTexture():SetAlpha(db.rollGlow and 0.35 or 0)
            button:SetEnabled(not not (not drop.choice and not drop.finished
                and (choice == 0 or choice == 1 and drop.canNeed or choice == 2 and drop.canGreed)))
        end
        row.timer:SetMinMaxValues(0, math.max(1, drop.duration or 1))
        local left = 0
        if not drop.finished then
            left = drop.demo and math.max(0, drop.duration - (GetTime() - drop.start) * 1000)
                or (safe(GetLootRollTimeLeft(drop.id)) or math.max(0, (drop.deadline - GetTime()) * 1000))
        end
        row.timer:SetValue(left)
        row.timer:SetShown(not historyMode)
        row:Show()
        if new and db.rollAnimations then
            if not row.appear then
                row.appear = row:CreateAnimationGroup()
                local fade = row.appear:CreateAnimation("Alpha")
                fade:SetFromAlpha(0.35)
                fade:SetToAlpha(1)
                fade:SetDuration(0.22)
            end
            row.appear:Play()
        end
    end
    for i = #drops + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(1, #drops * 46))
    emptyLabel:SetShown(#drops == 0)
    frame:SetHeight(inset + 8 + math.max(26, math.min(6, #drops) * 46))
end

function inventory.OpenRolls(test, automatic)
    local db = inventory.Settings()
    if not test and (not db.enabled or not db.rolls) then return end
    if not frame then build() end
    if not frame:IsShown() and not inventory.VisibleLoot() then inventory.ResetLootPosition() end
    removeExpired(GetTime())
    demoMode = not not test
    frame:SetFrameStrata(test and "FULLSCREEN_DIALOG" or "DIALOG")
    frame.autoClose = not demoMode and (automatic or next(active) ~= nil)
    if test then
        demo = {}
        local now = GetTime()
        for i, item in ipairs({{"Training Shield", 134952}, {"Training Bow", 135499}, {"Training Blade", 135328}}) do
            local start = now + (i - 1) * 0.65
            demo[i] = {demo = true, visible = i == 1, start = start,
                name = item[1], icon = item[2], quality = i + 1, duration = 25000,
                canNeed = true, canGreed = true, players = {
                    {playerName = "Thistle Ironbranch", playerClass = "WARRIOR", answer = "Need", result = 71, revealAt = start + 2},
                    {playerName = "Elowen Moonleaf", playerClass = "DRUID", answer = i == 3 and "Pass" or "Greed",
                        result = i ~= 3 and 43 or nil, revealAt = start + 4},
                }}
        end
    end
    historyMode = false
    frame:Show()
    frame:Raise()
    inventory.RefreshRolls()
end

function inventory.CloseRollPreview()
    if demoMode and frame then demoMode = nil; frame:Hide() end
end

function inventory.ToggleRolls(test)
    if frame and frame:IsShown() and not not test == demoMode then
        if not test and next(active) then return end
        frame:Hide()
        return
    end
    inventory.OpenRolls(test)
end

local recorded = {}
local function updateDrop(encounter, key)
    if not C_LootHistory or not C_LootHistory.GetSortedInfoForDrop then return end
    local data = C_LootHistory.GetSortedInfoForDrop(encounter, key)
    local link = data and safe(data.itemHyperlink)
    if not link then return end
    local drop
    for _, candidate in pairs(active) do
        if candidate.historyKey == key and candidate.encounter == encounter then drop = candidate; break end
        if candidate.link == link and not candidate.historyKey then drop = candidate end
    end
    if drop then
        drop.historyKey, drop.encounter, drop.players = key, encounter, data.rollInfos
    end
    local winner = safe(data.winner)
    if winner or safe(data.allPassed) then
        local historyKey = tostring(encounter) .. ":" .. tostring(key)
        if recorded[historyKey] then return end
        recorded[historyKey] = true
        local name, _, quality, _, _, _, _, _, _, icon = inventory.GetItemInfo(link)
        local entry = drop or {link = link, name = name, quality = quality, icon = icon, players = data.rollInfos}
        entry.finished = true
        entry.winner = type(winner) == "table" and safe(winner.playerName) or nil
        entry.winnerClass = type(winner) == "table" and safe(winner.playerClass) or nil
        local guid = type(winner) == "table" and safe(winner.playerGUID)
        if guid and GetPlayerInfoByGUID then
            local ok, _, class, _, _, _, fullName, realm = pcall(GetPlayerInfoByGUID, guid)
            fullName, realm = safe(fullName), safe(realm)
            if ok and not entry.winnerClass then entry.winnerClass = safe(class) end
            if ok and fullName and (not entry.winner or fullName:find(entry.winner, 1, true) == 1) then
                entry.winner = realm and realm ~= "" and fullName .. "-" .. realm or fullName
            end
        end
        if drop then drop.showUntil = GetTime() + resultDuration end
        table.insert(history, 1, entry)
        if #history > 100 then table.remove(history) end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "LOOT_HISTORY_UPDATE_DROP"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, id, duration)
    local db = inventory.Settings()
    if not db.enabled or not db.rolls then return end
    if event == "START_LOOT_ROLL" then
        for key, drop in pairs(active) do
            if drop.finished then active[key] = nil end
        end
        local icon, name, _, quality, _, need, greed = GetLootRollItemInfo(id)
        duration = safe(duration) or safe(GetLootRollTimeLeft(id)) or 0
        active[id] = {id = id, duration = duration, icon = safe(icon), name = safe(name), quality = safe(quality),
            deadline = GetTime() + duration / 1000,
            canNeed = safe(need), canGreed = safe(greed), link = safe(GetLootRollItemLink(id))}
        if db.openRoll then inventory.OpenRolls(false, true)
        elseif frame and frame:IsShown() and not demoMode then frame.autoClose = true end
    elseif event == "CANCEL_LOOT_ROLL" then
        if active[id] then
            active[id].finished = true
            active[id].showUntil = GetTime() + resultDuration
        end
    else
        updateDrop(id, duration)
    end
    inventory.RefreshRolls()
end)
