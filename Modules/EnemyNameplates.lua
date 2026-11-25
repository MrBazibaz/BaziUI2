-- Enemy-only presentation. Blizzard retains nameplate positioning and hit testing.
local addon = BaziUI
local M = {}
addon.EnemyNameplates = M

M.defaults = {
    enemyEnabled = false, enemyWidth = 160, enemyHeight = 16, enemyScale = 1,
    enemyPlateX = 0, enemyPlateY = 0,
    enemyName = true, enemyLevel = true, enemyHealth = false,
    enemyQuest = true, enemyClassification = true, enemyThreat = true,
    enemyDebuffs = true, enemyCastbar = true, enemyTarget = true, enemyRaid = true,
    enemyFaction = false, enemyFactionSize = 19, enemyFactionX = 0, enemyFactionY = 0,
    enemyCombo = false, enemyComboStyle = "orb", enemyComboSize = 12, enemyComboX = 0, enemyComboY = 0,
    enemyTargetGlowWidth = 6,
    enemyRange = true, enemyRangeAlpha = 70, enemyRangeSpell = 0, enemyTapped = true,
    enemyThreatRole = "auto", enemyThreatWarning = 80, enemyQuestStyle = "glow",
    enemyNameX = 0, enemyNameY = 0, enemyLevelX = 0, enemyLevelY = 0,
    enemyHealthX = 0, enemyHealthY = 0,
    enemyNameAnchor = "DEFAULT", enemyLevelAnchor = "DEFAULT", enemyHealthAnchor = "DEFAULT",
    enemyCastTextAnchor = "DEFAULT", enemyCastTextX = 0, enemyCastTextY = 0,
    enemyCastTimer = true, enemyCastTimeAnchor = "RIGHT", enemyCastTimeX = -4, enemyCastTimeY = 0,
    enemyCastTimeSize = 10, enemyCastTimeFont = "general",
    enemyDebuffTimer = true, enemyDebuffTimeAnchor = "CENTER", enemyDebuffTimeX = 0, enemyDebuffTimeY = 0,
    enemyDebuffTimeSize = 10, enemyDebuffTimeFont = "general",
    enemyDebuffStacks = true,
    enemyQuestX = 0, enemyQuestY = 0, enemyClassificationX = 0, enemyClassificationY = 0,
    enemyRaidX = 0, enemyRaidY = 0, enemyDebuffX = 0, enemyDebuffY = 0,
    enemyCastX = 0, enemyCastY = -20, enemyCastHeight = 12, enemyCastWidth = 0, enemyDebuffSize = 20,
    enemyNameFont = "general", enemyLevelFont = "general", enemyHealthFont = "general",
    enemyCastFont = "general",
    enemyNameSize = 0, enemyLevelSize = 0, enemyHealthSize = 0,
    enemyCastSize = 0, enemyClassificationIconSize = 27,
    enemyQuestSize = 18, enemyRaidSize = 18,
}

local texture = "Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziGradientRight.tga"
local white = "Interface\\Buttons\\WHITE8X8"
local fonts = {friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF"}
local overlays, units = {}, {}
function M.GetMoverFrame()
    for _, frame in pairs(units) do if frame:IsVisible() then return frame end end
end
local preview
local nativeOwners, nativeHooks = {}, setmetatable({}, {__mode = "k"})
local configured
local tanks = {}
local rangeTicker, rangeCursor, playerClass
local spellNames = {}
local classSpells = {
    WARRIOR = {78, 100}, ROGUE = {1752, 2764}, HUNTER = {75, 2973},
    PALADIN = {20271, 853}, PRIEST = {585, 589}, SHAMAN = {403, 8042},
    MAGE = {133, 116, 2136}, WARLOCK = {686, 348}, DRUID = {5176, 8921},
    DRUID_MELEE = {1082, 6807},
}
local function readable(value)
    return (not issecretvalue or not issecretvalue(value))
        and (not canaccessvalue or canaccessvalue(value))
end

local function isDead(unit)
    local dead = UnitIsDead(unit)
    return readable(dead) and dead == true
end

local function settings()
    local profile = addon.db and addon.db.profile
    local db = profile and profile.nameplates
    if not db or not db.enabled or not db.enemyEnabled then return end
    if configured ~= db then
        for key, value in pairs(M.defaults) do
            if db[key] == nil then db[key] = value end
        end
        configured = db
    end
    return db
end

local function bar(parent)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetStatusBarTexture(texture)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg = background
    background:SetAllPoints()
    background:SetColorTexture(0.09, 0.035, 0.025, 1)
    background:SetAlpha(0.95)
    addon.Backgrounds.Track("nameplates", background, 0.95)
    return frame
end

local function label(parent)
    return parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end

local function position(region, parent, point, relativePoint, db, key, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relativePoint, x + db[key .. "X"], y + db[key .. "Y"])
end

local textAnchors = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
local function positionText(region, bar, db, key, point, relativePoint, x, y)
    local anchor = db[key .. "Anchor"]
    if textAnchors[anchor] then
        position(region, bar, anchor, anchor, db, key, 0, 0)
    else
        position(region, bar, point, relativePoint, db, key, x, y)
    end
end

local function font(region, db, key)
    local general, size = GameFontNormal:GetFont()
    local chosen = db[key .. "Size"]
    local profile = addon.db.profile
    local selected = db[key .. "Font"]
    addon.Typography.Apply(region, "Nameplates:Enemy", fonts[selected] or general,
        chosen > 0 and chosen or profile.fontSize or size or 12, "OUTLINE", selected == "general" or selected == "GLOBAL")
end

local function updateHealth(f)
    local currentOK, hp = pcall(UnitHealth, f.unit)
    local maximumOK, maximum = pcall(UnitHealthMax, f.unit)
    if not currentOK or not maximumOK then
        M:Remove(f.unit)
        return false
    end
    f.hp:SetMinMaxValues(0, maximum)
    f.hp:SetValue(hp)
    if f.db.enemyHealth and readable(hp) and readable(maximum) and maximum > 0 then
        f.health:SetFormattedText("%.0f%%", hp / maximum * 100)
    elseif f.db.enemyHealth and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local ok, percent = pcall(UnitHealthPercent, f.unit, true, CurveConstants.ScaleTo100)
        if ok then f.health:SetFormattedText("%.0f%%", percent) else f.health:SetText("") end
    else
        f.health:SetText("")
    end
    return true
end

local healthColors = addon.Theme.colors
M.colorOptions = {
    {"neutral", "Neutral out of combat", {0.90, 0.81, 0.16}},
    {"hostile", "Hostile out of combat", {0.86, 0.21, 0.17}},
    {"tapped", "Tagged by another player", {0.47, 0.47, 0.47}},
    {"tank", "Tank holding aggro", {0.34, 0.17, 0.25}},
    {"pet", "Pet holding aggro", {0.34, 0.17, 0.25}},
    {"losing", "Tank losing aggro", healthColors.healthWarning},
    {"otherTank", "Another tank holding aggro", {1, 0.44, 0.51}},
    {"tankNoAggro", "Tank without aggro", healthColors.healthCritical},
    {"aggro", "DPS / healer holding aggro", healthColors.healthCritical},
    {"warning", "DPS / healer close to pulling", healthColors.healthWarning},
    {"safe", "DPS / healer without aggro", {0.60, 0.19, 0.15}},
    {"cast", "Interruptible cast", {0.83, 0.53, 0.19}},
    {"lockedCast", "Uninterruptible cast", {0.48, 0.43, 0.57}},
    {"combat", "Combat with threat colors disabled", {0.74, 0.20, 0.15}},
    {"target", "Target glow", {1, 0.78, 0.25}},
    {"border", "Health bar border", {0.90, 0.72, 0.42}},
    {"targetBorder", "Target border", {1, 0.91, 0.66}},
    {"nameText", "Name text", {1, 1, 1}},
    {"castText", "Cast text and timer", {1, 1, 1}},
    {"questText", "Gold quest exclamation", {1, 0.90, 0.40}},
}
local defaultColors = {}
for _, option in ipairs(M.colorOptions) do defaultColors[option[1]] = option[3] end

function M:GetColor(db, key)
    return (db and db.enemyColors and db.enemyColors[key]) or defaultColors[key]
end

local function setBarColor(bar, db, key)
    bar:SetStatusBarColor(unpack(M:GetColor(db, key)))
end

local function updateTanks()
    wipe(tanks)
    if not UnitGroupRolesAssigned then return end
    local raid = IsInRaid()
    local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i = 1, count do
        local unit = (raid and "raid" or "party") .. i
        local role = UnitGroupRolesAssigned(unit)
        local player = UnitIsUnit(unit, "player")
        if readable(role) and role == "TANK" and readable(player) and not player then
            tanks[#tanks + 1] = unit
        end
    end
end

local function tankMode(db)
    if db.enemyThreatRole ~= "auto" then return db.enemyThreatRole == "tank" end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    return readable(role) and role == "TANK"
end

local function otherTankHasUnit(unit)
    for _, tank in ipairs(tanks) do
        local matches = UnitIsUnit(unit .. "target", tank)
        if readable(matches) and matches then return true end
    end
    return false
end

local function applyThreatColor(f, isTank, hasAggro, status, percent, otherTank, petHasAggro)
    local closingIn = percent and percent > 0 and percent >= f.db.enemyThreatWarning
        or (not percent or percent == 0) and status == 1
    if isTank then
        if hasAggro then
            if status == 2 then setBarColor(f.hp, f.db, "losing")
            else setBarColor(f.hp, f.db, "tank") end
        elseif petHasAggro then
            setBarColor(f.hp, f.db, closingIn and "warning" or "pet")
        elseif otherTank then
            setBarColor(f.hp, f.db, "otherTank")
        else
            setBarColor(f.hp, f.db, "tankNoAggro")
        end
    elseif hasAggro then
        setBarColor(f.hp, f.db, "aggro")
    elseif closingIn then
        setBarColor(f.hp, f.db, "warning")
    elseif petHasAggro then
        setBarColor(f.hp, f.db, "pet")
    else
        setBarColor(f.hp, f.db, "safe")
    end
end

local function petHoldsThreat(unit)
    if not UnitExists("pet") then return false end
    if UnitDetailedThreatSituation then
        local ok, holds = pcall(UnitDetailedThreatSituation, "pet", unit)
        if ok and readable(holds) and holds == true then return true end
    end
    local targetIsPet = UnitIsUnit(unit .. "target", "pet")
    return readable(targetIsPet) and targetIsPet == true
end

local function updateThreat(f)
    local player = UnitIsPlayer(f.unit)
    local faction, own
    if readable(player) and player then faction, own = UnitFactionGroup(f.unit), UnitFactionGroup("player") end
    if readable(faction) and faction and readable(own) and own and faction ~= own then
        local _, class = UnitClass(f.unit)
        local color = readable(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then
            if not f.playerGradient then f.hp:SetStatusBarTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziHealthGradientRight.tga") end
            f.playerGradient = true
            f.hp:SetStatusBarColor(color.r, color.g, color.b)
            f.hp.bg:SetColorTexture(0.32, 0.04, 0.04, 0.85)
            return
        end
    end
    if f.playerGradient then
        f.hp:SetStatusBarTexture(texture)
        f.hp.bg:SetColorTexture(0.09, 0.035, 0.025, 1)
        f.playerGradient = nil
    end
    local tapped = f.db.enemyTapped and UnitIsTapDenied and UnitIsTapDenied(f.unit)
    if readable(tapped) and tapped then
        setBarColor(f.hp, f.db, "tapped")
        return
    end
    local tanking, status, percent, rawPercent
    if UnitDetailedThreatSituation then
        local ok, holding, detailed, scaled, raw = pcall(UnitDetailedThreatSituation, "player", f.unit)
        if ok then tanking, status, percent, rawPercent = holding, detailed, scaled, raw end
    end
    status = readable(status) and type(status) == "number" and status or nil
    if not status and UnitThreatSituation then
        local ok, fallback = pcall(UnitThreatSituation, "player", f.unit)
        if ok and readable(fallback) and type(fallback) == "number" then status = fallback end
    end
    percent = readable(percent) and type(percent) == "number" and percent or nil
    local scaledPercent = percent
    if (not percent or percent == 0) and readable(rawPercent) and type(rawPercent) == "number" then percent = rawPercent end
    local reaction = UnitReaction("player", f.unit)
    local engaged = status ~= nil or (percent and percent > 0)
    local combat = f.db.enemyThreat and UnitAffectingCombat and UnitAffectingCombat(f.unit)
    local petHasAggro = f.db.enemyThreat and petHoldsThreat(f.unit)
    local hasAggro = (readable(tanking) and tanking == true) or (status and status >= 2)
        or (not petHasAggro and status == nil and scaledPercent and scaledPercent >= 100)
    petHasAggro = petHasAggro and not hasAggro
    if not (f.db.enemyThreat and (engaged or petHasAggro or (readable(combat) and combat))) then
        if engaged then
            setBarColor(f.hp, f.db, "combat")
        else
            setBarColor(f.hp, f.db, readable(reaction) and reaction == 4 and "neutral" or "hostile")
        end
        return
    end
    local isTank = tankMode(f.db)
    applyThreatColor(f, isTank, hasAggro, status, percent,
        isTank and not hasAggro and not petHasAggro and otherTankHasUnit(f.unit), petHasAggro)
end

local function updateRange(f)
    if not f.db.enemyRange or not (C_Spell and C_Spell.IsSpellInRange) then f:SetAlpha(1); return end
    local alpha = f.db.enemyRangeAlpha / 100
    if not playerClass then
        local _, class = UnitClass("player")
        playerClass = class
    end
    local override = f.db.enemyRangeSpell
    local ids = classSpells[playerClass]
    if override > 0 then
        if f.rangeOverride ~= override then
            f.rangeOverride, f.rangeSpells = override, {override}
        end
        ids = f.rangeSpells
    elseif playerClass == "DRUID" and GetShapeshiftFormID then
        local form = GetShapeshiftFormID()
        if form == 1 or form == 5 or form == 8 then ids = classSpells.DRUID_MELEE end
    end
    if not ids then f:SetAlpha(1); return end
    local outside, restricted, hasRestricted
    for _, id in ipairs(ids) do
        if spellNames[id] == nil then
            spellNames[id] = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or id
        end
        local ok, result = pcall(C_Spell.IsSpellInRange, spellNames[id], f.unit)
        if ok then
            if not readable(result) then
                if not hasRestricted then restricted, hasRestricted = result, true end
            elseif result == true then
                f:SetAlpha(1)
                return
            elseif result == false then
                outside = true
            end
        end
    end
    if hasRestricted and f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, restricted, 1, alpha) then return end
    f:SetAlpha(outside and alpha or 1)
end

local function updateRangeTicker()
    local _, first = next(units)
    if first and first.db.enemyRange and C_Spell and C_Spell.IsSpellInRange and C_Timer and C_Timer.NewTicker then
        if rangeTicker then return end
        rangeTicker = C_Timer.NewTicker(0.1, function()
            local firstUnit
            for _ = 1, 6 do
                local unit, f = next(units, units[rangeCursor] and rangeCursor or nil)
                if not unit then unit, f = next(units) end
                if not unit or unit == firstUnit then return end
                firstUnit = firstUnit or unit
                rangeCursor = unit
                if not f.dead then updateRange(f) end
            end
        end)
    elseif rangeTicker then
        rangeTicker:Cancel()
        rangeTicker, rangeCursor = nil, nil
    end
end

local function updateQuest(f)
    f.quest:Hide()
    if not f.db.enemyQuest then return end
    local unit = f.unit
    local lineTypes = Enum and Enum.TooltipDataLineType
    local objective = lineTypes and lineTypes.QuestObjective
    if not objective or not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or not readable(data) or not data or not readable(data.lines) then return end
    local questID
    for _, line in ipairs(data.lines or {}) do
        if readable(line) and readable(line.type) then
            if line.type == lineTypes.QuestTitle then
                questID = readable(line.id) and line.id or nil
            elseif line.type == objective and readable(line.completed) and not line.completed then
                local id = readable(line.questID) and line.questID or questID
                local complete = type(id) == "number" and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
                local text = line.leftText
                local current, required
                if readable(text) and type(text) == "string" then
                    current, required = text:match("(%d+)%s*/%s*(%d+)")
                end
                if readable(complete) and not complete
                    and (not current or tonumber(current) < tonumber(required)) then
                    f.quest:Show()
                    return
                end
            end
        end
    end
end

local classes = {elite = true, rare = true, rareelite = true, worldboss = true}
local function updateDragon(f, class, unit)
    local dragon = f.classification
    if not f.db.enemyClassification or not f.db.enemyLevel or not readable(class) or not classes[class] then
        dragon:Hide()
        return
    end
    local atlas
    if unit and GetBossPortraitFrameData then
        local ok, result = pcall(GetBossPortraitFrameData, unit, class)
        if ok then atlas = result end
    end
    atlas = atlas or (class == "rare" and "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged"
        or "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged")
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        dragon:SetAtlas(atlas, false)
        dragon:SetTexCoord(0, 1, 0, 1)
        dragon:Show()
    else
        dragon:Hide()
    end
end

local function setFactionBadge(f, faction)
    local valid = readable(faction) and (faction == "Alliance" or faction == "Horde")
    f.faction:SetShown(valid)
    if valid then f.faction:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction) end
end

local markerStyles = {star = 1, skull = 8, moon = 5}
local gemStyles = {goldGem = "Gem_Gold", silverGem = "Gem_Silver", plumGem = "Gem_Plum"}

local function updateIdentity(f)
    local name = UnitName(f.unit)
    f.name:SetText(name)
    local faction, own
    if f.db.enemyFaction and UnitIsPlayer and UnitFactionGroup then
        local player = UnitIsPlayer(f.unit)
        if readable(player) and player then faction, own = UnitFactionGroup(f.unit), UnitFactionGroup("player") end
    end
    setFactionBadge(f, readable(faction) and readable(own) and own and faction ~= own and faction or nil)
    BaziUI.SetUnitDifficulty(f.level, f.unit)
    updateDragon(f, UnitClassification(f.unit), f.unit)
end

local icons = {
    diamond = "Diamond", dagger = "Dagger", claw = "Claw",
    venom = "ComboVenom", runestone = "ComboRunestone", ember = "ComboEmber",
    thorn = "ComboThorn", eye = "ComboEye", crescent = "ComboCrescent", steelKnife = "ComboSteelKnife",
}
local function updateComboPulse(f)
    local pulse = f.comboPulse
    if f:IsVisible() and f.comboCount and f.comboCount >= #f.combo then
        if not pulse:IsPlaying() then pulse:Play() end
    elseif pulse:IsPlaying() then
        pulse:Stop()
    end
end

local function setComboPoints(f, count, visible)
    if not readable(count) or type(count) ~= "number" then count = 0 end
    local style = f.db.enemyComboStyle
    local old = f.comboCount or 0
    f.comboCount = visible and count or 0
    for i, pip in ipairs(f.combo) do
        pip:SetTexCoord(0, 1, 0, 1)
        if icons[style] then
            pip:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\Bazi\\" .. icons[style] .. ".tga")
        elseif style == "square" then pip:SetColorTexture(1, 0.62, 0.10)
        elseif markerStyles[style] and SetRaidTargetIconTexture then
            pip:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            SetRaidTargetIconTexture(pip, markerStyles[style])
        elseif gemStyles[style] then
            pip:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Icons\\" .. gemStyles[style] .. ".png")
        else pip:SetTexture("Interface\\COMMON\\Indicator-Yellow") end
        pip:SetShown(visible == true)
        pip:SetDesaturated(i > count)
        pip:SetAlpha(i <= count and 1 or 0.26)
        if visible and count < #f.combo and i > old and i <= count then pip.flash:Play() end
    end
    updateComboPulse(f)
end

local function updateCombo(f)
    local _, class = UnitClass("player")
    local eligible = class == "ROGUE" or (class == "DRUID" and GetShapeshiftFormID and GetShapeshiftFormID() == (CAT_FORM or 1))
    local count = f.db.enemyCombo and eligible and GetComboPoints and GetComboPoints("player", f.unit)
    local target = UnitIsUnit(f.unit, "target")
    local visible = f.db.enemyCombo and eligible and ((readable(count) and type(count) == "number" and count > 0)
        or (readable(target) and target)) or false
    setComboPoints(f, count, visible)
end

local function positionCombo(f)
    local db = f.db
    if not db then return end
    local bar = f.hp
    local size = db.enemyComboSize
    for i, pip in ipairs(f.combo) do
        pip:SetSize(size, size)
        position(pip, bar, "TOP", "BOTTOM", db, "enemyCombo", (i - (#f.combo + 1) / 2) * (size + 3), -2)
    end
end

local function updateBorder(f, selected)
    f.targetBorder:SetShown(selected)
    if selected then
        f.border:SetBackdropBorderColor(unpack(M:GetColor(f.db, "targetBorder")))
    else
        f.border:SetBackdropBorderColor(unpack(M:GetColor(f.db, "border")))
    end
end

local function addTargetHalo(target, bar)
    local strips = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local glow = target:CreateTexture(nil, "BACKGROUND")
        strips[side] = glow
        glow:SetTexture(white)
        glow:SetBlendMode("ADD")
        if side == "TOP" then
            glow:SetPoint("BOTTOMLEFT", bar, "TOPLEFT")
            glow:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT")
        elseif side == "BOTTOM" then
            glow:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
            glow:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
        elseif side == "LEFT" then
            glow:SetPoint("TOPRIGHT", bar, "TOPLEFT")
            glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT")
        else
            glow:SetPoint("TOPLEFT", bar, "TOPRIGHT")
            glow:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT")
        end
    end
    -- The same radial fade is flipped into each corner so it meets both straight edges.
    for _, spec in ipairs({
        {"TOPLEFT", "BOTTOMRIGHT", 1, 0, 1, 0},
        {"TOPRIGHT", "BOTTOMLEFT", 0, 1, 1, 0},
        {"BOTTOMLEFT", "TOPRIGHT", 1, 0, 0, 1},
        {"BOTTOMRIGHT", "TOPLEFT", 0, 1, 0, 1},
    }) do
        local corner = target:CreateTexture(nil, "BACKGROUND")
        corner:SetTexture("Interface\\AddOns\\BaziUI\\Assets\\Bars\\BaziTargetGlowCorner.tga")
        corner:SetBlendMode("ADD")
        corner:SetTexCoord(spec[3], spec[4], spec[5], spec[6])
        corner:SetPoint(spec[2], bar, spec[1])
        strips[spec[1]] = corner
    end
    return strips
end

local function layoutTargetHalo(strips, width)
    for side, glow in pairs(strips) do
        if width > 0 then
            if side == "TOP" or side == "BOTTOM" then
                glow:SetHeight(width)
            elseif side == "LEFT" or side == "RIGHT" then
                glow:SetWidth(width)
            else
                glow:SetSize(width, width)
            end
        end
        glow:SetShown(width > 0)
    end
end

local function updateMarkers(f)
    local target = UnitIsUnit(f.unit, "target")
    updateBorder(f, f.db.enemyTarget and readable(target) and target == true)
    local marker = GetRaidTargetIndex and GetRaidTargetIndex(f.unit)
    if f.db.enemyRaid and readable(marker) and marker and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(f.raid, marker)
        f.raid:Show()
    else
        f.raid:Hide()
    end
end

local castFormatter
local function bindCastTime(cast, duration)
    if not cast.timerBinding and not cast.timerAttempted then
        cast.timerAttempted = true
        if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
            local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
            if ok and binding and pcall(binding.SetFontString, binding, cast.time) then
                cast.timerBinding = binding
                if castFormatter == nil then
                    castFormatter = false
                    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
                        local created, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
                        if created and formatter
                            and pcall(formatter.SetBreakpoints, formatter, {{threshold = 0, format = "%.1f"}}) then
                            castFormatter = formatter
                        end
                    end
                end
                if castFormatter then pcall(binding.SetFormatter, binding, castFormatter) end
                pcall(binding.SetZeroDurationText, binding, "")
                pcall(binding.SetUpdateInterval, binding, 0.05)
            end
        end
    end
    local binding = cast.timerBinding
    return binding and pcall(binding.SetDuration, binding, duration) and pcall(binding.Enable, binding)
end

local function stopCastTime(cast)
    if cast.timerBinding then pcall(cast.timerBinding.Disable, cast.timerBinding) end
    cast.time:SetText("")
end

local function updateCast(f)
    local cast, unit = f.cast, f.unit
    cast:SetScript("OnUpdate", nil)
    if not f.db.enemyCastbar then cast:Hide(); return end
    local name, _, icon, first, last, _, _, locked = UnitCastingInfo(unit)
    local channel = readable(name) and name == nil
    if channel then
        name, _, icon, first, last, _, locked = UnitChannelInfo(unit)
    end
    if readable(name) and not name then cast:Hide(); return end
    local durationFn = UnitCastingDuration
    if channel then durationFn = UnitChannelDuration end
    local directions = Enum and Enum.StatusBarTimerDirection
    local interpolation = Enum and Enum.StatusBarInterpolation
    local nativeTimer = durationFn and cast.SetTimerDuration and directions and interpolation
    local readableTimes = readable(first) and readable(last) and type(first) == "number" and type(last) == "number"
    local bound
    if nativeTimer then
        local duration = durationFn(unit)
        if readable(duration) and not duration then cast:Hide(); return end
        cast:SetTimerDuration(duration, interpolation.Immediate,
            channel and directions.RemainingTime or directions.ElapsedTime)
        if f.db.enemyCastTimer then bound = bindCastTime(cast, duration) end
    elseif readableTimes and last > first then
        cast:SetMinMaxValues(0, last - first)
    else
        cast:Hide()
        return
    end
    if not bound then stopCastTime(cast) end
    if readableTimes and (not nativeTimer or (f.db.enemyCastTimer and not bound)) then
        local nextTextAt = 0
        local function tick(self)
            local now = GetTime() * 1000
            if now >= last then self:Hide(); self:SetScript("OnUpdate", nil); return end
            if not nativeTimer then self:SetValue(channel and last - now or now - first) end
            if f.db.enemyCastTimer and now >= nextTextAt then
                self.time:SetFormattedText("%.1f", (last - now) / 1000)
                nextTextAt = now + 50
            end
        end
        cast:SetScript("OnUpdate", tick)
    end
    cast.text:SetText(name)
    cast.icon:SetTexture(icon)
    if readable(locked) and locked == false then
        setBarColor(cast, f.db, "cast")
    else
        setBarColor(cast, f.db, "lockedCast")
    end
    cast:Show()
    local tick = cast:GetScript("OnUpdate")
    if tick then tick(cast) end
end

local function prepareAuras()
    if C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer")
        and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer")
    end
    return true
end

function M:Prepare()
    local db = settings()
    if db and db.enemyDebuffs then prepareAuras() end
end

local function layoutDebuffTime(text, tile, db)
    font(text, db, "enemyDebuffTime")
    positionText(text, tile, db, "enemyDebuffTime", "CENTER", "CENTER", 0, 0)
    text:SetAlpha(db.enemyDebuffTimer and 1 or 0)
end

local function layoutDebuffStacks(text, tile, db)
    text:ClearAllPoints()
    text:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 1)
    local general = GameFontNormal:GetFont()
    text:SetFont(general, math.max(8, math.min(14, db.enemyDebuffSize * 0.36)), "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetAlpha(db.enemyDebuffStacks and 1 or 0)
end

local function styleLiveDebuffText(layoutText, text, tile, db)
    -- Blizzard can make pooled aura tiles and their children forbidden after binding.
    if (tile.IsForbidden and tile:IsForbidden()) or (text.IsForbidden and text:IsForbidden()) then return end
    -- Some client builds only report restricted access when a setter is called.
    pcall(layoutText, text, tile, db)
end

local function makeAuras(f)
    if f.auras or f.auraAttempted or not prepareAuras() then return end
    f.auraAttempted = true
    local ok, auras = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
    if not ok or not auras then return end
    auras:Hide()
    if not (auras.AddAuraGroup and auras.SetUnit and auras.SetEnabled) then return end
    local timers = {}
    local function initializeButton(button)
        local db = f.db or M.defaults
        button:SetSize(db.enemyDebuffSize, db.enemyDebuffSize)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        if button.SetIcon then pcall(button.SetIcon, button, icon) end
        local duration = label(button)
        duration:SetTextColor(1, 1, 1)
        styleLiveDebuffText(layoutDebuffTime, duration, button, db)
        local bind = button.SetDurationText or button.SetAuraDurationText
        if bind then pcall(bind, button, duration) end
        local timer = {text = duration, tile = button}
        timers[#timers + 1] = timer
        if button.SetApplicationCount then
            local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
            styleLiveDebuffText(layoutDebuffStacks, count, button, db)
            if pcall(button.SetApplicationCount, button, count, {}) then timer.count = count end
        end
    end
    local filter = "HARMFUL|PLAYER"
    if AuraUtil and AuraUtil.AuraFilters and AuraUtil.AuraFilters.IncludeNameplateOnly then
        filter = filter .. "|" .. AuraUtil.AuraFilters.IncludeNameplateOnly
    end
    local added = pcall(auras.AddAuraGroup, auras, "enemyDebuffs", filter, {
        maxFrameCount = 8, candidateFilters = {},
        layout = {elementWidth = 20, elementHeight = 20, elementSpacing = 2},
        initializeFrame = function(button)
            if not (button.IsForbidden and button:IsForbidden()) then pcall(initializeButton, button) end
        end,
    })
    if not added then return end
    auras:SetSize(1, 1)
    auras:SetFrameLevel(f:GetFrameLevel() + 10)
    f.auras = auras
    f.auraTimers = timers
end

local function layout(f)
    local db = f.db
    f:SetSize(db.enemyWidth, db.enemyHeight)
    f:SetScale(db.enemyScale)
    position(f, f:GetParent(), "CENTER", "CENTER", db, "enemyPlate", 0, 0)
    f.hp:SetAllPoints()
    f.name:SetTextColor(unpack(M:GetColor(db, "nameText")))
    f.cast.text:SetTextColor(unpack(M:GetColor(db, "castText")))
    f.cast.time:SetTextColor(unpack(M:GetColor(db, "castText")))
    f.quest.glyph:SetTextColor(unpack(M:GetColor(db, "questText")))
    layoutTargetHalo(f.targetHalo, db.enemyTargetGlowWidth)
    local glowColor = M:GetColor(db, "target")
    if f.targetGlowColor ~= glowColor then
        f.targetGlowColor = glowColor
        local r, g, b = unpack(glowColor)
        local bright = CreateColor and CreateColor(r, g, b, 0.65)
        local clear = CreateColor and CreateColor(r, g, b, 0)
        for side, glow in pairs(f.targetHalo) do
            if bright and glow.SetGradient and #side <= 6 then
                local reverse = side == "LEFT" or side == "BOTTOM"
                local axis = (side == "TOP" or side == "BOTTOM") and "VERTICAL" or "HORIZONTAL"
                glow:SetGradient(axis, reverse and clear or bright, reverse and bright or clear)
            else
                glow:SetVertexColor(r, g, b, bright and 0.65 or 0.22)
            end
        end
    end
    positionText(f.name, f.hp, db, "enemyName", "BOTTOM", "TOP", 0, 6)
    positionText(f.level, f.hp, db, "enemyLevel", "LEFT", "RIGHT", 5, 0)
    positionText(f.health, f.hp, db, "enemyHealth", "CENTER", "CENTER", 0, 0)
    position(f.classification, f.level, "CENTER", "CENTER", db, "enemyClassification", 0, 1)
    f.classification:SetSize(db.enemyClassificationIconSize, db.enemyClassificationIconSize)
    position(f.quest, f, "RIGHT", "LEFT", db, "enemyQuest", -5, 0)
    position(f.raid, f, "BOTTOMLEFT", "TOPLEFT", db, "enemyRaid", 0, 2)
    position(f.cast, f, "TOP", "BOTTOM", db, "enemyCast", 0, 0)
    position(f.faction, f.hp, "BOTTOMLEFT", "TOPRIGHT", db, "enemyFaction", 5, 2)
    f.faction:SetSize(db.enemyFactionSize, db.enemyFactionSize)
    positionCombo(f)
    positionText(f.cast.text, f.cast, db, "enemyCastText", "CENTER", "CENTER", 0, 0)
    positionText(f.cast.time, f.cast, db, "enemyCastTime", "RIGHT", "RIGHT", 0, 0)
    f.quest:SetSize(db.enemyQuestSize * f.questRatio, db.enemyQuestSize)
    f.quest.glyph:SetFont("Fonts\\FRIZQT__.TTF", db.enemyQuestSize, "OUTLINE")
    f.quest.glyph:SetShown(db.enemyQuestStyle == "glow")
    f.quest.icon:SetShown(db.enemyQuestStyle ~= "glow")
    f.raid:SetSize(db.enemyRaidSize, db.enemyRaidSize)
    f.cast:SetSize(db.enemyCastWidth > 0 and db.enemyCastWidth or db.enemyWidth, db.enemyCastHeight)
    f.cast.icon:SetSize(db.enemyCastHeight, db.enemyCastHeight)
    font(f.name, db, "enemyName")
    font(f.level, db, "enemyLevel")
    if f.unit then BaziUI.SetUnitDifficulty(f.level, f.unit) end
    font(f.health, db, "enemyHealth")
    font(f.cast.text, db, "enemyCast")
    font(f.cast.time, db, "enemyCastTime")
    f.cast.time:SetShown(db.enemyCastTimer)
    f.name:SetShown(db.enemyName)
    f.level:SetShown(db.enemyLevel)
    f.health:SetShown(db.enemyHealth)
    if db.enemyDebuffs and f.unit then makeAuras(f) end
    if f.auras then
        local auras, size = f.auras, db.enemyDebuffSize
        position(auras, f, "BOTTOMLEFT", "TOPLEFT", db, "enemyDebuff", 0, 21)
        if AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowDirection then
            pcall(auras.SetFlowLayoutAxis, auras, AnchorUtil.FlowLayoutAxis.Horizontal)
            pcall(auras.SetFlowLayoutAnchorPoint, auras, "BOTTOMLEFT")
            pcall(auras.SetFlowLayoutGrowthDirection, auras, AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
            pcall(auras.SetFlowLayoutMaximumLineSize, auras, 8 * (size + 2))
        end
        if auras.SetAuraGroupLayout then
            pcall(auras.SetAuraGroupLayout, auras, "enemyDebuffs", {
                elementWidth = size, elementHeight = size, elementSpacing = 2,
            })
        end
        local refresh = db.enemyDebuffs and f.auraUnit ~= f.unit
        if refresh then auras:SetUnit(f.unit) end
        auras:SetEnabled(db.enemyDebuffs)
        auras:SetShown(db.enemyDebuffs)
        f.auraUnit = db.enemyDebuffs and f.unit or nil
        if refresh and auras.UpdateAllAuras then pcall(auras.UpdateAllAuras, auras) end
        for _, timer in ipairs(f.auraTimers) do
            styleLiveDebuffText(layoutDebuffTime, timer.text, timer.tile, db)
            if timer.count then styleLiveDebuffText(layoutDebuffStacks, timer.count, timer.tile, db) end
        end
    end
end

local handlers = {
    UNIT_HEALTH = updateHealth, UNIT_MAXHEALTH = updateHealth,
    UNIT_NAME_UPDATE = updateIdentity, UNIT_LEVEL = updateIdentity,
    UNIT_FACTION = updateThreat, UNIT_FLAGS = updateThreat, UNIT_TARGET = updateThreat,
    UNIT_THREAT_LIST_UPDATE = updateThreat, UNIT_THREAT_SITUATION_UPDATE = updateThreat,
    UNIT_SPELLCAST_START = updateCast, UNIT_SPELLCAST_STOP = updateCast,
    UNIT_SPELLCAST_FAILED = updateCast, UNIT_SPELLCAST_INTERRUPTED = updateCast,
    UNIT_SPELLCAST_DELAYED = updateCast, UNIT_SPELLCAST_INTERRUPTIBLE = updateCast,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = updateCast, UNIT_SPELLCAST_CHANNEL_START = updateCast,
    UNIT_SPELLCAST_CHANNEL_UPDATE = updateCast, UNIT_SPELLCAST_CHANNEL_STOP = updateCast,
    UNIT_SPELLCAST_EMPOWER_START = updateCast, UNIT_SPELLCAST_EMPOWER_UPDATE = updateCast,
    UNIT_SPELLCAST_EMPOWER_STOP = updateCast,
}

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:Hide()
    f:EnableMouse(false)
    f.hp, f.cast = bar(f), bar(f)
    setBarColor(f.hp, f.db, "combat")
    f.name, f.level, f.health = label(f.hp), label(f.hp), label(f.hp)
    f.name:SetTextColor(1, 1, 1)
    f.faction = f.hp:CreateTexture(nil, "OVERLAY")
    f.faction:Hide()
    f.combo = {}
    f.comboLayer = CreateFrame("Frame", nil, f)
    f.comboLayer:SetAllPoints()
    f.comboLayer:EnableMouse(false)
    f.comboPulse = f.comboLayer:CreateAnimationGroup()
    f.comboPulse:SetLooping("BOUNCE")
    local pulse = f.comboPulse:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.50)
    pulse:SetDuration(0.40)
    pulse:SetSmoothing("IN_OUT")
    f:HookScript("OnShow", updateComboPulse)
    f:HookScript("OnHide", function(self) self.comboPulse:Stop() end)
    for i = 1, 5 do
        local pip = f.comboLayer:CreateTexture(nil, "OVERLAY")
        pip:Hide()
        pip.flash = pip:CreateAnimationGroup()
        local flash = pip.flash:CreateAnimation("Alpha")
        flash:SetFromAlpha(0.4)
        flash:SetToAlpha(1)
        flash:SetDuration(0.27)
        f.combo[i] = pip
    end
    f.classification = f.hp:CreateTexture(nil, "ARTWORK", nil, 2)
    f.cast.text = label(f.cast)
    f.cast.text:SetTextColor(1, 1, 1)
    f.cast.time = label(f.cast)
    f.cast.time:SetTextColor(1, 1, 1)
    f.cast:HookScript("OnHide", stopCastTime)
    f.cast.icon = f.cast:CreateTexture(nil, "ARTWORK")
    f.cast.icon:SetPoint("RIGHT", f.cast, "LEFT", -2, 0)
    f.quest = CreateFrame("Frame", nil, f.hp)
    f.quest.icon = f.quest:CreateTexture(nil, "ARTWORK")
    f.quest.icon:SetAllPoints(f.quest)
    f.quest.glyph = label(f.quest)
    f.quest.glyph:SetPoint("CENTER")
    f.quest.glyph:SetText("!")
    f.quest.glyph:SetTextColor(1, 0.90, 0.40)
    local questAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal")
    f.questRatio = 1
    if questAtlas then
        f.quest.icon:SetAtlas("QuestNormal", false)
        if questAtlas.width and questAtlas.height and questAtlas.height > 0 then
            f.questRatio = questAtlas.width / questAtlas.height
        end
    else
        f.quest.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    f.raid = f.hp:CreateTexture(nil, "OVERLAY")
    f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetPoint("TOPLEFT", f.hp, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", 2, -2)
    border:SetFrameLevel(f:GetFrameLevel() + 5)
    border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    border:EnableMouse(false)
    f.border = border
    BaziUI.Theme:TrackWindowBorder(border)
    BaziUI.Theme:AddDropShadow("Nameplates", f, border)
    local targetBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    targetBorder:SetPoint("TOPLEFT", border, "TOPLEFT", -1.5, 1.5)
    targetBorder:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 1.5, -1.5)
    targetBorder:SetFrameLevel(border:GetFrameLevel() - 1)
    targetBorder:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    targetBorder:SetBackdropBorderColor(1, 0.82, 0.43, 0.85)
    f.targetHalo = addTargetHalo(targetBorder, f.hp)
    targetBorder:EnableMouse(false)
    targetBorder:Hide()
    f.targetBorder = targetBorder
    f.cast:SetFrameLevel(border:GetFrameLevel() + 1)
    f.comboLayer:SetFrameLevel(f.cast:GetFrameLevel() + 6)
    f:SetScript("OnEvent", function(self, event)
        local unit = self.unit
        if not unit then return end
        if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
            if isDead(unit) then
                if not self.dead then
                    self.dead = true
                    self.cast:Hide()
                    self:Hide()
                end
                return
            elseif self.dead then
                M:Update(unit, self:GetParent())
                return
            end
        end
        if not self.dead then handlers[event](self) end
    end)
    return f
end

function M:RefreshPreview()
    if not preview or not preview:IsShown() then return end
    local f, db = preview, preview.db
    layout(f)
    f.cast:SetShown(db.enemyCastbar)
    local own = UnitFactionGroup and UnitFactionGroup("player")
    setFactionBadge(f, db.enemyFaction and (readable(own) and own == "Horde" and "Alliance" or "Horde"))
    setComboPoints(f, #f.combo, db.enemyCombo == true)
    f.cast.time:SetText("1.4")
    if db.enemyThreat then
        applyThreatColor(f, tankMode(db), false, 1, 90, false)
    else
        setBarColor(f.hp, f.db, "combat")
    end
    local colorKey = f.colorKey
    if colorKey and (colorKey == "neutral" or colorKey == "hostile" or colorKey == "tapped" or colorKey == "tank"
        or colorKey == "pet" or colorKey == "losing" or colorKey == "otherTank" or colorKey == "tankNoAggro"
        or colorKey == "aggro" or colorKey == "warning" or colorKey == "safe" or colorKey == "combat") then
        setBarColor(f.hp, db, colorKey)
    end
    setBarColor(f.cast, db, colorKey == "lockedCast" and "lockedCast" or "cast")
    updateDragon(f, "rareelite")
    f.quest:SetShown(db.enemyQuest)
    f.raid:SetShown(db.enemyRaid and SetRaidTargetIconTexture ~= nil)
    updateBorder(f, db.enemyTarget)
    position(f.sampleDebuffs, f, "BOTTOMLEFT", "TOPLEFT", db, "enemyDebuff", 0, 21)
    f.sampleDebuffs:SetShown(db.enemyDebuffs)
    local size = db.enemyDebuffSize
    for i, tile in ipairs(f.sampleDebuffs.tiles) do
        tile:SetSize(size, size)
        tile:ClearAllPoints()
        tile:SetPoint("BOTTOMLEFT", f.sampleDebuffs, "BOTTOMLEFT", (i - 1) * (size + 2), 0)
        layoutDebuffTime(tile.time, tile, db)
        layoutDebuffStacks(tile.count, tile, db)
    end
end

function M:SetPreview(db, colorKey)
    if not db then
        if preview then preview:Hide(); preview.db = nil end
        return
    end
    if not preview then
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(1, 1)
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -125)
        anchor:SetFrameStrata("FULLSCREEN_DIALOG")
        preview = create(anchor)
        preview.hp:SetMinMaxValues(0, 100)
        preview.hp:SetValue(68)
        preview.name:SetText("Bristleback Hexcaller")
        preview.level:SetText("60")
        preview.health:SetText("68%")
        preview.cast:SetMinMaxValues(0, 100)
        preview.cast:SetValue(58)
        preview.cast.text:SetText("Fireball")
        preview.cast.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
        setBarColor(preview.cast, db, "cast")
        if SetRaidTargetIconTexture then SetRaidTargetIconTexture(preview.raid, 8) end
        local debuffs = CreateFrame("Frame", nil, preview)
        debuffs:SetSize(1, 1)
        debuffs.tiles = {}
        for i, icon in ipairs({"Spell_Fire_Immolation", "Spell_Shadow_AbominationExplosion", "Ability_Rogue_Rupture"}) do
            local tile = CreateFrame("Frame", nil, debuffs)
            local sample = tile:CreateTexture(nil, "ARTWORK")
            sample:SetAllPoints(tile)
            sample:SetTexture("Interface\\Icons\\" .. icon)
            tile.time = label(tile)
            tile.time:SetTextColor(1, 1, 1)
            tile.time:SetText(tostring(5 + i * 3))
            tile.count = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal", 2)
            tile.count:SetText(i == 1 and "" or tostring(i + 1))
            debuffs.tiles[i] = tile
        end
        preview.sampleDebuffs = debuffs
    end
    preview.db = db
    preview.colorKey = colorKey
    preview:Show()
    self:RefreshPreview()
end

function M:Remove(unit)
    local f = units[unit]
    if not f then return end
    units[unit] = nil
    f.comboCount = nil
    f:UnregisterAllEvents()
    f.cast:SetScript("OnUpdate", nil)
    f.cast:Hide()
    if f.auras then
        f.auras:SetEnabled(false)
        f.auras:Hide()
        f.auraUnit = nil
    end
    f:Hide()
    if f.native then
        nativeOwners[f.native] = nil
        local alpha = f.native:GetAlpha()
        if readable(alpha) and alpha == 0 then f.native:SetAlpha(f.nativeAlpha) end
    end
    f.unit, f.native, f.nativeAlpha, f.db, f.dead = nil, nil, nil, nil, nil
    updateRangeTicker()
end

function M:Clear()
    for unit in pairs(units) do self:Remove(unit) end
end

function M:Update(unit, plate)
    local db = settings()
    local native = plate.UnitFrame
    local attackable = db and UnitCanAttack("player", unit)
    local dead = db and isDead(unit)
    if not db or not native or (native.IsForbidden and native:IsForbidden())
        or (not (dead and units[unit]) and (not readable(attackable) or not attackable)) then
        self:Remove(unit)
        return
    end
    local f = overlays[plate]
    if units[unit] and (units[unit] ~= f or f.native ~= native) then self:Remove(unit) end
    if f and f.unit and f.unit ~= unit then self:Remove(f.unit) end
    if not f then
        f = create(plate)
        overlays[plate] = f
    end
    local fresh = not f.unit
    if fresh then
        local alpha = native:GetAlpha()
        if not readable(alpha) then f:Hide(); return end
        f.nativeAlpha = alpha
    end
    f.unit, f.native, f.db = unit, native, db
    f.dead = dead
    units[unit] = f
    if f.dead then
        f.cast:Hide()
    else
        layout(f)
        updateIdentity(f)
        updateCombo(f)
        if not updateHealth(f) then return end
        updateThreat(f)
        updateRange(f)
        updateRangeTicker()
        if fresh or f.questEnabled ~= db.enemyQuest then
            f.questEnabled = db.enemyQuest
            updateQuest(f)
        end
        updateMarkers(f)
        updateCast(f)
    end
    if fresh then
        for event in pairs(handlers) do
            if event == "UNIT_THREAT_SITUATION_UPDATE" then
                pcall(f.RegisterUnitEvent, f, event, unit, "player")
            else
                pcall(f.RegisterUnitEvent, f, event, unit)
            end
        end
    end
    native:SetAlpha(0)
    nativeOwners[native] = f
    if hooksecurefunc and not nativeHooks[native] then
        nativeHooks[native] = true
        hooksecurefunc(native, "SetAlpha", function(self)
            local owner = nativeOwners[self]
            if not owner or owner:GetParent().UnitFrame ~= self then return end
            local alpha = self:GetAlpha()
            if readable(alpha) and alpha ~= 0 then
                owner.nativeAlpha = alpha
                self:SetAlpha(0)
            end
        end)
    end
    f:SetShown(not f.dead)
end

function M:Initialize()
    self:Prepare()
    updateTanks()
    local events = CreateFrame("Frame")
    local questQueued
    for _, event in ipairs({"PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_TURNED_IN",
        "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "SPELLS_CHANGED", "UPDATE_SHAPESHIFT_FORM"}) do
        events:RegisterEvent(event)
    end
    pcall(events.RegisterEvent, events, "COMBO_TARGET_CHANGED")
    pcall(events.RegisterEvent, events, "UNIT_POWER_UPDATE")
    pcall(events.RegisterUnitEvent, events, "UNIT_THREAT_SITUATION_UPDATE", "pet")
    pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
    events:SetScript("OnEvent", function(_, event, unit, power)
        if event == "UNIT_POWER_UPDATE" and (unit ~= "player" or power ~= "COMBO_POINTS") then return end
        if event == "UPDATE_SHAPESHIFT_FORM" or event == "COMBO_TARGET_CHANGED" or event == "UNIT_POWER_UPDATE" or event == "PLAYER_TARGET_CHANGED" then
            for _, f in pairs(units) do if not f.dead and f.db.enemyCombo then updateCombo(f) end end
            if event ~= "PLAYER_TARGET_CHANGED" then return end
        end
        local update = updateMarkers
        if event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" or event == "QUEST_TURNED_IN" then
            if not questQueued then
                questQueued = true
                C_Timer.After(0, function()
                    questQueued = nil
                    for _, f in pairs(units) do
                        if not f.dead then updateQuest(f) end
                    end
                end)
            end
            return
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            updateTanks()
            update = updateThreat
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_PET" then
            update = updateThreat
        elseif event == "SPELLS_CHANGED" then
            wipe(spellNames)
            return
        end
        for _, f in pairs(units) do if not f.dead then update(f) end end
    end)
end
