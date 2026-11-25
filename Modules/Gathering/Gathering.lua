local G = BaziUI.Gathering
local ns = G.vendor
local safe = ns.SafeCall
local media = "Interface\\AddOns\\BaziUI\\Assets\\Gathering\\Lueur\\"

local function skillTooLow(color)
    return color and color.r >= 0.65 and color.g <= 0.35 and color.b <= 0.35
end

function G:CreateEffect(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(1, 1)
    frame:Hide()
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = label:GetFont()
    local nameAnchor, nameX, nameY, nameSize, fontRevision
    local ring = frame:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(media .. "ring.tga")
    ring:SetBlendMode("ADD")
    ring:Hide()
    local holders, context = {}, {}
    local last, settings, phase = nil, nil, 0
    local ready, flash, effectColor = false, 0, nil
    frame:SetScript("OnUpdate", function(self, elapsed)
        elapsed = math.min(elapsed, 0.1)
        phase = (phase + elapsed * 3.5) % (math.pi * 200)
        flash = math.max(0, flash - elapsed / 0.42)
        local pulse = flash * flash
        local color = effectColor or settings
        local r, g, b = color.r, color.g, color.b
        context.frame, context.elapsed, context.size = last.frame, elapsed, settings.size
        context.alpha, context.ready, context.arrive = settings.intensity / 100 * (1 + 0.45 * pulse), 1, 1
        context.flash, context.locked, context.phase, context.spin = 0.75 * pulse, 0, phase, -phase * 0.45
        context.breath = 0.5 + 0.5 * math.sin(phase)
        context.twinkle = 0.5 + 0.5 * math.sin(phase * 2.3 + 1.3)
        context.r, context.g, context.b = r, g, b
        context.hr, context.hg, context.hb = 0.55 + r * 0.45, 0.55 + g * 0.45, 0.55 + b * 0.45
        context.wr, context.wg, context.wb = 0.75 + r * 0.25, 0.75 + g * 0.25, 0.75 + b * 0.25
        last.effect.Update(last.textures, context)
        if flash > 0 and settings.intensity > 0 then
            local progress = 1 - flash
            local width = (last.textures.waveSize or settings.size) * (1 + 0.65 * flash * flash)
            ring:SetSize(width, width * (last.effect.flat or 1))
            ring:SetPoint("CENTER", self, "CENTER", 0, last.textures.waveY or 0)
            ring:SetRotation(last.textures.waveAngle or 0)
            local alpha = math.min(1, settings.intensity / 100) * math.sin(math.pi * progress ^ 1.5)
            ring:SetVertexColor(context.hr, context.hg, context.hb, alpha)
            ring:Show()
        else
            ring:Hide()
        end
    end)
    function frame:Display(anchor, config, name, nameColor, inRange)
        if not anchor or not config then
            ready, flash = false, 0
            ring:Hide()
            self:Hide()
            return
        end
        if self.anchor ~= anchor or not inRange then flash = 0 end
        if inRange and (not ready or self.anchor ~= anchor) then flash = 1 end
        ready = inRange == true
        effectColor = skillTooLow(nameColor) and nameColor or nil
        local key = ns.EFFECTS[config.effect] and config.effect or "beam"
        if not holders[key] then
            local holder = CreateFrame("Frame", nil, self)
            holder:SetAllPoints()
            local effect, textures = ns.EFFECTS[key], {}
            effect.Build(textures, function(file, layer, sublevel, blend)
                local texture = holder:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
                texture:SetTexture(media .. file .. ".tga")
                texture:SetBlendMode(blend or "ADD")
                texture:SetPoint("CENTER", holder, "CENTER")
                texture:SetVertexColor(1, 1, 1, 0)
                return texture
            end)
            holders[key] = {frame = holder, effect = effect, textures = textures}
        end
        local nextEffect = holders[key]
        if last and last ~= nextEffect then last.frame:Hide() end
        last, settings = nextEffect, config
        last.frame:Show()
        if self.anchor ~= anchor or self.offset ~= config.y then
            self:ClearAllPoints()
            self:SetPoint("CENTER", anchor, "CENTER", 0, config.y)
            self.anchor, self.offset = anchor, config.y
        end
        local showName = config.showName and type(name) == "string" and name ~= ""
        if showName then
            if nameAnchor ~= anchor or nameX ~= config.nameX or nameY ~= config.nameY then
                label:ClearAllPoints()
                label:SetPoint("TOP", anchor, "CENTER", config.nameX, config.nameY)
                nameAnchor, nameX, nameY = anchor, config.nameX, config.nameY
            end
            if nameSize ~= config.nameSize or fontRevision ~= BaziUI.Typography.revision then
                BaziUI.Typography.Apply(label, "Gathering", font, config.nameSize, "OUTLINE", true)
                fontRevision = BaziUI.Typography.revision
                nameSize = config.nameSize
            end
            local color = nameColor or config
            label:SetTextColor(color.r, color.g, color.b)
            if label:GetText() ~= name then label:SetText(name) end
        end
        label:SetShown(not not showName)
        self:Show()
    end
    return frame
end

local detectionRange = 15
local desired = {
    SoftTargetInteract = "3", SoftTargetNameplateInteract = "1", SoftTargetIconInteract = "1",
    SoftTargetIconGameObject = "1", SoftTargetInteractRange = tostring(detectionRange),
    SoftTargetInteractArc = "2", SoftTargetInteractOnlyInRange = "0",
    SoftTargetInteractRangeIsHard = "0", nameplateGameObjectMaxDistance = tostring(detectionRange),
}
local original = {}
local function syncCVars(enabled)
    if InCombatLockdown() or not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    for name, value in pairs(desired) do
        local current = safe(C_CVar.GetCVar, name)
        local keepDistance = name == "nameplateGameObjectMaxDistance" and (tonumber(current) or 0) > detectionRange
        if enabled and current and current ~= value and not keepDistance then
            original[name] = original[name] or current
            safe(C_CVar.SetCVar, name, value)
        elseif not enabled and original[name] then
            if current == value then safe(C_CVar.SetCVar, name, original[name]) end
            original[name] = nil
        end
    end
end

local function controlsInteractionCVars()
    local lueurLoaded = C_AddOns and C_AddOns.IsAddOnLoaded("Lueur")
    return not (lueurLoaded and (not LueurDB or LueurDB.enabled ~= false))
end

local function tooltipLines(tooltip)
    local lines = type(tooltip) == "table" and tooltip.lines
    if not ns.IsSecret(lines) and type(lines) == "table" then return lines end
end

local function skinLine(text)
    return text == "Skinnable" or text == _G.UNIT_SKINNABLE_LEATHER
        or text == _G.UNIT_SKINNABLE or text == _G.SKINNABLE
end

local function isSkinnable(unit)
    if safe(UnitIsDead, unit) ~= true then return false end
    if safe(UnitIsSkinnable, unit) == true then return true end
    local _, cursor = ns.ReadCursor(unit)
    if cursor == "skin" then return true end
    local lines = C_TooltipInfo and tooltipLines(safe(C_TooltipInfo.GetUnit, unit))
    if not lines then return false end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if not ns.IsSecret(text) and type(text) == "string" and skinLine(text) then return true end
    end
    return false
end

local function visiblePlate(unit)
    local plate = ns.GetNamePlate(unit)
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then return plate end
end

local nearbyCorpseTokens = {"target", "mouseover"}
local function hasSkinning()
    if ns.Trained("skin") == true then return true end
    local info = C_TradeSkillUI and safe(C_TradeSkillUI.GetProfessionInfoBySkillLineID, 393)
    local rank = type(info) == "table" and info.skillLevel
    if not ns.IsSecret(rank) and type(rank) == "number" and rank > 0 then return true end
    local count = safe(GetNumSkillLines)
    if type(count) ~= "number" or not GetSkillLineInfo then return false end
    local name = C_Spell and safe(C_Spell.GetSpellName, G.professionSpells.skin) or "Skinning"
    for index = 1, count do
        local ok, skill, header, _, level = pcall(GetSkillLineInfo, index)
        if ok and not ns.IsSecret(skill) and not ns.IsSecret(header) and not ns.IsSecret(level)
            and skill == name and not header and type(level) == "number" and level > 0 then return true end
    end
    return false
end

local function hoveredSkinLine()
    if not (GameTooltip and GameTooltip:IsShown() and GameTooltip.GetUnit) then return end
    local ok, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if not ok or ns.IsSecret(unit) then return end
    if unit == nil and safe(UnitIsDead, "mouseover") == true then
        local title = _G.GameTooltipTextLeft1
        local name = safe(UnitName, "mouseover")
        if name and title and safe(title.GetText, title) == name then unit = "mouseover" end
    end
    if type(unit) ~= "string"
        or (unit ~= "mouseover" and safe(UnitIsUnit, unit, "mouseover") ~= true) then return end
    for i = 2, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and safe(line.GetText, line)
        if type(text) == "string" and skinLine(text) then
            local gotColor, r, g, b = pcall(line.GetTextColor, line)
            if gotColor and not ns.IsSecret(r) and not ns.IsSecret(g) and not ns.IsSecret(b) then
                return true, {r = r, g = g, b = b}
            end
            return true
        end
    end
end
local lastCorpseWithoutPlate
local function resolveCorpse()
    local soft = "softinteract"
    if isSkinnable(soft) then
        local plate = visiblePlate(soft)
        if plate then return soft, plate end
        for unit in pairs(ns.activeUnits) do
            if safe(UnitIsUnit, unit, soft) == true then
                plate = visiblePlate(unit)
                if plate then return soft, plate end
            end
        end
        local guid = safe(UnitGUID, soft) or soft
        if lastCorpseWithoutPlate ~= guid and not InCombatLockdown() and controlsInteractionCVars() then
            syncCVars(true)
            lastCorpseWithoutPlate = guid
        end
    else
        lastCorpseWithoutPlate = nil
    end
    for _, unit in ipairs(nearbyCorpseTokens) do
        local plate = visiblePlate(unit)
        if plate and safe(UnitIsInInteractRange, unit) == true and isSkinnable(unit) then return unit, plate end
    end
    local hovered, color = hoveredSkinLine()
    local plate = hovered and visiblePlate("mouseover")
    if plate then return "mouseover", plate, color end
end

local neutralNameColor = {r = 0.94, g = 0.93, b = 0.88}
local fallbackProfessionNames = {ore = "Mining", herb = "Herbalism", skin = "Skinning"}
local function difficultyFromLines(lines, profession, category)
    if not lines then return end
    for index = 2, #lines do
        local line = lines[index]
        local text = line.leftText
        if not ns.IsSecret(text) and type(text) == "string" and
            ((category == "skin" and skinLine(text)) or text:lower():find(profession, 1, true)) then
            local color = line.leftColor
            if not ns.IsSecret(color) and type(color) == "table" then
                local r, g, b = color.r, color.g, color.b
                if not ns.IsSecret(r) and not ns.IsSecret(g) and not ns.IsSecret(b)
                    and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                    return color
                end
            end
        end
    end
end

local function readDifficulty(unit, category, name)
    if not C_TooltipInfo then return neutralNameColor end
    local spell = G.professionSpells[category]
    local profession = C_Spell and safe(C_Spell.GetSpellName, spell)
    profession = (profession or fallbackProfessionNames[category]):lower()
    local getTooltip = category == "skin" and C_TooltipInfo.GetUnit
        or C_TooltipInfo.GetWorldLootObject or C_TooltipInfo.GetUnit
    local color = difficultyFromLines(tooltipLines(safe(getTooltip, unit)), profession, category)
    if not color and getTooltip ~= C_TooltipInfo.GetUnit then
        color = difficultyFromLines(tooltipLines(safe(C_TooltipInfo.GetUnit, unit)), profession, category)
    end
    if color then return color end
    local lines = tooltipLines(safe(C_TooltipInfo.GetWorldCursor))
    local title = lines and lines[1] and lines[1].leftText
    if name and not ns.IsSecret(title) and title == name then
        color = difficultyFromLines(lines, profession, category)
    end
    return color or neutralNameColor
end

local function unitPosition(unit)
    local ok, x, y, z, map = pcall(UnitPosition, unit)
    if ok and not ns.IsSecret(x) and not ns.IsSecret(y) and not ns.IsSecret(z) and not ns.IsSecret(map)
        and type(x) == "number" and type(y) == "number" and map then return x, y, z, map end
end

local function corpseInRange(unit, px, py, pz, playerMap, soft)
    local squared = safe(UnitDistanceSquared, unit)
    if type(squared) == "number" and squared > 0 then return squared <= detectionRange ^ 2 end
    if playerMap then
        local x, y, z, map = unitPosition(unit)
        if map == playerMap then
            local dx, dy = x - px, y - py
            local dz = type(z) == "number" and type(pz) == "number" and (z - pz) or 0
            if dx ~= 0 or dy ~= 0 or dz ~= 0 then
                return dx * dx + dy * dy + dz * dz <= detectionRange ^ 2
            end
        end
    end
    return soft == true or safe(UnitIsInInteractRange, unit) == true
end

local function seedVisiblePlates()
    local plates = C_NamePlate and safe(C_NamePlate.GetNamePlates)
    if type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        if not (plate.IsForbidden and plate:IsForbidden()) then
            local unit = plate.namePlateUnitToken
            if not ns.IsSecret(unit) and type(unit) == "string" and visiblePlate(unit) == plate then
                ns.activeUnits[unit] = true
            end
        end
    end
end

local corpseEffects, availableEffects = {}, {}
local updateID = 0
local function showCorpse(unit, plate, config, nameColor)
    local entry = corpseEffects[plate]
    if entry and entry.updateID == updateID then return end
    if not entry then
        entry = table.remove(availableEffects) or { effect = G:CreateEffect(UIParent) }
        corpseEffects[plate] = entry
    end
    entry.updateID = updateID
    if not nameColor then
        nameColor = readDifficulty(unit, "skin", safe(UnitName, unit))
    end
    local ready = not skillTooLow(nameColor) and safe(UnitIsInInteractRange, unit) == true
    entry.effect:Display(plate, config, _G.UNIT_SKINNABLE_LEATHER or "Skinnable", nameColor, ready)
end

local function refreshCorpses(config)
    updateID = updateID + 1
    if config and config.enabled and hasSkinning() then
        local unit, plate, color = resolveCorpse()

        local px, py, pz, map = unitPosition("player")
        if plate then
            local soft = unit == "softinteract" or safe(UnitIsUnit, unit, "softinteract") == true
            if corpseInRange(unit, px, py, pz, map, soft) then showCorpse(unit, plate, config, color) end
        end
        for token in pairs(ns.activeUnits) do
            if safe(UnitIsDead, token) == true and corpseInRange(token, px, py, pz, map) then
                local anchor = visiblePlate(token)
                local entry = anchor and corpseEffects[anchor]
                if anchor and (not entry or entry.updateID ~= updateID) and isSkinnable(token) then
                    showCorpse(token, anchor, config)
                end
            end
        end
    end
    for plate, entry in pairs(corpseEffects) do
        if entry.updateID ~= updateID then
            entry.effect:Display(nil)
            corpseEffects[plate] = nil
            availableEffects[#availableEffects + 1] = entry
        end
    end
end

local mutedIcon, mutedAlpha
local function interactionIcon(plate)
    local unitFrame = plate and plate.UnitFrame
    if ns.IsSecret(unitFrame) or (unitFrame and unitFrame.IsForbidden and unitFrame:IsForbidden()) then unitFrame = nil end
    local icon = unitFrame and unitFrame.SoftTargetFrame or (plate and plate.SoftTargetFrame)
    if ns.IsSecret(icon) or (icon and icon.IsForbidden and icon:IsForbidden()) then icon = nil end
    return icon
end

local function muteInteractionIcon(icon)
    if mutedIcon and mutedIcon ~= icon then
        local previous, alpha = mutedIcon, mutedAlpha
        mutedIcon, mutedAlpha = nil, nil
        safe(previous.SetAlpha, previous, alpha)
    end
    if not icon then return end
    local alpha = safe(icon.GetAlpha, icon)
    if type(alpha) == "number" and alpha > 0 and pcall(icon.SetAlpha, icon, 0) then
        mutedIcon, mutedAlpha = icon, alpha
    end
end

local driver = CreateFrame("Frame")
local worldEffect, ticker, currentObject, currentCategory
local iconUnits = setmetatable({}, {__mode = "k"})
local function suppressIconForUnit(icon, unit)
    if not ticker or not unit or safe(UnitIsGameObject, unit) ~= true then return end
    local db = G:Settings()
    if not db.enabled then return end
    local category = ns.Classify(unit, safe(UnitName, unit) or "")
    if category ~= "herb" and category ~= "ore" then return end
    local look = db.categories[category]
    if not look.enabled or ns.Trained(category) ~= true then muteInteractionIcon(icon) end
end

local function watchInteractionIcon(plate, unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local icon = interactionIcon(plate)
    if not icon then return end
    local entry = iconUnits[icon]
    if not entry then
        entry = {}
        iconUnits[icon] = entry
        if icon.HookScript then
            icon:HookScript("OnShow", function(self) suppressIconForUnit(self, entry.unit) end)
        end
        hooksecurefunc(icon, "SetAlpha", function(self, alpha)
            if mutedIcon == self and type(alpha) == "number" and not ns.IsSecret(alpha) and alpha > 0 then
                mutedAlpha = alpha
                safe(self.SetAlpha, self, 0)
            end
        end)
    end
    entry.unit = unit
    return icon
end

local function refresh()
    local db = G:Settings()
    if not db.enabled and not G.fishingInteraction then return end
    local unit, plate = ns.ResolveTarget()
    local category, name, nameColor, blocked
    currentObject, currentCategory = nil, nil
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then
        if not category and safe(UnitIsGameObject, unit) == true then
            name = safe(UnitName, unit) or ""

            local kind, cursorBlocked, _, id = ns.Classify(unit, name)
            blocked = cursorBlocked
            category = kind
            if category == "bobber" and name == "" then name = "Fishing Bobber" end
            currentObject, currentCategory = id, category
        end
    end
    local look = category and db.categories[category]
    if category == "bobber" then
        if not G.fishingInteraction then look = nil end
    elseif not db.enabled then
        look = nil
    end
    local isProfessionObject = category == "ore" or category == "herb"
    local hideProfessionObject = db.enabled and isProfessionObject and (not look.enabled or ns.Trained(category) ~= true)
    local hideBobberIcon = category == "bobber" and G.fishingInteraction and db.fishing.hideBobberIcon
    local icon = watchInteractionIcon(plate, unit)
    if plate then muteInteractionIcon((hideProfessionObject or hideBobberIcon) and icon or nil) end
    if hideProfessionObject then look = nil end
    if not nameColor and look and look.enabled and G.professionSpells[category] then
        nameColor = readDifficulty(unit, category, name)
    end
    local ready = category ~= "bobber" and look and look.enabled and not blocked and not skillTooLow(nameColor)
        and safe(UnitIsInInteractRange, unit) == true
    worldEffect:Display(look and look.enabled and plate, look, name, nameColor, ready)
    refreshCorpses(db.enabled and db.categories.skin or nil)
end

function G:ProbeCorpses()
    seedVisiblePlates()
    local px, py, pz, map = unitPosition("player")
    local anchored, nearby, skinnable, beams = 0, 0, 0, 0
    for unit in pairs(ns.activeUnits) do
        if visiblePlate(unit) and safe(UnitIsDead, unit) == true then
            anchored = anchored + 1
            if corpseInRange(unit, px, py, pz, map) then nearby = nearby + 1 end
            if worldEffect and isSkinnable(unit) then skinnable = skinnable + 1 end
        end
    end
    for _ in pairs(corpseEffects) do beams = beams + 1 end
    BaziUI:Print(("Skinning probe: %d corpse plates, %d confirmed nearby, %d skinnable, %d Beams. Soft target plate: %s."):format(
        anchored, nearby, skinnable, beams, visiblePlate("softinteract") and "yes" or "no"))
end

function G:Apply()
    local db = self:Settings()
    if not self.fishingInteraction then syncCVars(db.enabled and controlsInteractionCVars()) end
    if db.enabled or self.fishingInteraction then
        if not worldEffect then
            ns.PrepareCursors()
            worldEffect = self:CreateEffect(UIParent)
        end
        if not ticker then
            seedVisiblePlates()
            ticker = C_Timer.NewTicker(0.15, refresh)
        end
        refresh()
    else
        if ticker then ticker:Cancel(); ticker = nil end
        if worldEffect then worldEffect:Display(nil) end
        refreshCorpses(nil)
        muteInteractionIcon(nil)
    end
end

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED",
    "PLAYER_SOFT_INTERACT_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "QUEST_LOG_UPDATE", "LOOT_OPENED", "UPDATE_MOUSEOVER_UNIT",
}) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGOUT" then
        if G.Fishing then G.Fishing:RestoreCVars() end
        muteInteractionIcon(nil)
        syncCVars(false)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        G:Apply()
    elseif event == "QUEST_LOG_UPDATE" then
        ns.MarkQuests()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        ns.activeUnits[unit] = true
        if ticker then
            local icon = watchInteractionIcon(ns.GetNamePlate(unit), unit)
            if icon then suppressIconForUnit(icon, unit) end
            refresh()
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ns.activeUnits[unit] = nil
        for icon, entry in pairs(iconUnits) do
            if entry.unit == unit then
                entry.unit = nil
                if mutedIcon == icon then muteInteractionIcon(nil) end
            end
        end
        if ticker then refresh() end
    elseif ticker then
        if event == "LOOT_OPENED" then
            if currentObject and (currentCategory == "ore" or currentCategory == "herb") then
                ns.gathered[currentObject] = true
            end
            ns.LearnContainers()
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            ns.LearnFromTooltip()
            refresh()
        else
            refresh()
        end
    end
end)

-- Gathering tracking is a QoL option independent of the world effects.
local gatheringTrackers = {[2383] = "herb", [8387] = "herb", [2580] = "ore", [8388] = "ore"}
local preferredTracking, trackingPending, trackingQueued
local function trackingState()
    local api = C_Minimap
    local count = api and safe(api.GetNumTrackingTypes)
    if type(count) ~= "number" then return end
    local indexes, active = {}
    for index = 1, count do
        local info = safe(api.GetTrackingInfo, index)
        if type(info) == "table" and not ns.IsSecret(info.spellID) and not ns.IsSecret(info.active) then
            local kind = gatheringTrackers[info.spellID]
            if kind then
                indexes[kind] = index
                if info.active == true or info.active == 1 then active = kind end
            end
        end
    end
    return indexes, active
end

local function restoreTrackingEnabled()
    local profile = BaziUI.db and BaziUI.db.profile
    return profile and profile.qol and profile.qol.restoreGatheringTracking
end

local function playerDead()
    return safe(UnitIsDeadOrGhost, "player") == true
end

local function queueTrackingRestore(delay, retry)
    if trackingQueued or not trackingPending then return end
    trackingQueued = true
    C_Timer.After(delay, function()
        trackingQueued = false
        if not restoreTrackingEnabled() then trackingPending = false; return end
        if not trackingPending or playerDead() or InCombatLockdown() then return end
        local indexes, active = trackingState()
        if active then
            preferredTracking, trackingPending = active, false
            return
        end
        local index = indexes and (indexes[preferredTracking] or indexes.herb or indexes.ore)
        if index and C_Minimap.SetTracking then safe(C_Minimap.SetTracking, index, true) end
        if retry then queueTrackingRestore(1, false)
        else trackingPending = false end
    end)
end

local trackingEvents = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE",
    "PLAYER_REGEN_ENABLED", "MINIMAP_UPDATE_TRACKING"}) do
    pcall(trackingEvents.RegisterEvent, trackingEvents, event)
end
trackingEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" or (event == "PLAYER_ENTERING_WORLD" and playerDead()) then
        trackingPending = restoreTrackingEnabled()
    elseif event == "MINIMAP_UPDATE_TRACKING" or event == "PLAYER_ENTERING_WORLD" then
        if not playerDead() then
            local _, active = trackingState()
            if active then preferredTracking = active end
        end
    else
        queueTrackingRestore(0.25, true)
    end
end)
