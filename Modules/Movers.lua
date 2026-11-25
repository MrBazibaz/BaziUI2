local addon = BaziUI
local M = {entries = {}, layouts = {}}
addon.Movers = M

local panel, list, fields, overlays, dragChecks, selection, drag, changes
local reopen, active, syncElapsed
local driver = CreateFrame("Frame")
local unavailableGeometry = setmetatable({}, {__mode = "k"})

function M.Register(spec)
    M.entries[#M.entries + 1] = spec
end

function M.RegisterLayout(fn)
    M.layouts[#M.layouts + 1] = fn
end

function M.IsDragging(frame)
    return drag and frame and drag.moving[frame]
end

function M.IsActive()
    return active == true
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function beginChange(spec)
    if changes[spec] then return end
    local cfg = spec.settings()
    if not cfg then return end
    local snapshot = {}
    local function snapshotKey(key)
        snapshot[#snapshot + 1] = {key, copy(cfg[key])}
    end
    for _, key in ipairs(spec.saved or {spec.x or "x", spec.y or "y"}) do snapshotKey(key) end
    for _, field in ipairs(spec.fields or {}) do snapshotKey(field[1]) end
    changes[spec] = {cfg = cfg, values = snapshot}
end

local function round(value) return math.floor(value + 0.5) end
local function getPosition(spec)
    if spec.position then return spec.position() end
    local cfg = spec.settings()
    return cfg and tonumber(cfg[spec.x or "x"]) or 0, cfg and tonumber(cfg[spec.y or "y"]) or 0
end

local function setPosition(spec, x, y)
    if not active or InCombatLockdown() then return end
    local cfg = spec.settings()
    if not cfg then return end
    x, y = math.max(-10000, math.min(10000, x)), math.max(-10000, math.min(10000, y))
    beginChange(spec)
    if spec.setPosition then spec.setPosition(round(x), round(y))
    else
        cfg[spec.x or "x"], cfg[spec.y or "y"] = round(x), round(y)
        spec.apply(cfg)
    end
end

local function readable(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

local function unrestricted(frame, method)
    if not frame[method] then return true end
    local ok, result = pcall(frame[method], frame)
    return ok and readable(result) and not result
end

function M.CanMeasure(frame)
    return frame and not unavailableGeometry[frame]
        and unrestricted(frame, "IsForbidden") and unrestricted(frame, "HasAnyForbiddenAspects")
        and unrestricted(frame, "HasAccessConstraints") and unrestricted(frame, "IsAnchoringSecret")
        and unrestricted(frame, "IsAnchoringRestricted")
end

local function getFrame(spec, hidden)
    if spec.positionOnly then return end
    local frame = spec.frame and spec.frame()
    if M.CanMeasure(frame) and (hidden or frame:IsVisible()) then return frame end
end

local function button(parent, label, width, fn)
    local control = addon.Theme:CreateButton(parent, label, width, 24)
    control:SetScript("OnClick", fn)
    return control
end

local function field(parent, index)
    if fields[index] then return fields[index] end
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(27)
    row:SetPoint("TOPLEFT", 183, -95 - (index - 1) * 27)
    row:SetPoint("TOPRIGHT", -12, -95 - (index - 1) * 27)
    row.label = addon.Inventory.Label(row)
    row.label:SetPoint("LEFT")
    row.label:SetTextColor(0.93, 0.79, 0.52)
    row.edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.edit:SetSize(65, 22)
    row.edit:SetAutoFocus(false)
    row.edit:SetPoint("RIGHT", -4, 0)
    row.edit:SetMaxLetters(8)
    local function apply(self)
        local value = tonumber(self:GetText())
        if value and row.write then row.write(value) end
        if row.read then self:SetText(tostring(row.read())) end
    end
    row.edit:SetScript("OnEnterPressed", function(self) apply(self); self:ClearFocus() end)
    row.edit:SetScript("OnTabPressed", function(self) apply(self); self:ClearFocus() end)
    row.edit:SetScript("OnEscapePressed", function(self)
        if row.read then self:SetText(tostring(row.read())) end
        self:ClearFocus()
    end)
    row.edit:SetScript("OnEditFocusLost", apply)
    fields[index] = row
    return row
end

local function refreshInspector()
    local spec = selection
    panel.selected:SetText(spec and spec.label or "Select a module")
    local accessible = spec and overlays[spec] and overlays[spec].liveFrame
    panel.visibility:SetText(spec and not accessible and "Position shown while inactive" or "")
    local count = 0
    if spec then
        local cfg = spec.settings()
        if cfg then
            local function add(label, read, write)
                count = count + 1
                local row = field(panel, count)
                row.label:SetText(label)
                row.read, row.write = read, write
                if not row.edit:HasFocus() then row.edit:SetText(tostring(read())) end
                row:Show()
            end
            add("X", function() return round(getPosition(spec)) end, function(value)
                local _, y = getPosition(spec); setPosition(spec, value, y)
            end)
            add("Y", function() local _, y = getPosition(spec); return round(y) end, function(value)
                local x = getPosition(spec); setPosition(spec, x, value)
            end)
            for _, entry in ipairs(spec.fields or {}) do
                local key, label, minimum, maximum, factor = unpack(entry)
                factor = factor or 1
                if cfg[key] ~= nil then
                    add(label, function() return round(cfg[key] * factor) end, function(value)
                        if not active or InCombatLockdown() then return end
                        beginChange(spec)
                        local nextValue = math.min(maximum, math.max(minimum, round(value))) / factor
                        if cfg[key] ~= nextValue then cfg[key] = nextValue; spec.apply(cfg) end
                    end)
                end
            end
        end
    end
    for i = count + 1, #fields do fields[i]:Hide(); fields[i].read, fields[i].write = nil, nil end
    for _, arrow in ipairs(panel.arrows) do arrow:SetEnabled(count > 0) end
end

local function selectEntry(spec)
    local previous = selection and overlays[selection]
    if previous then previous:SetFrameLevel(previous.moverLevel) end
    selection = spec
    local selected = spec and overlays[spec]
    if selected then selected:SetFrameLevel(selected.moverLevel + 10) end
    for _, item in ipairs(panel.items) do addon.Theme:SetButtonActive(item, item.spec == spec) end
    refreshInspector()
end

local function overlayPosition(overlay, frame)
    local anchor = overlay.spec.bounds and overlay.spec.bounds(frame) or frame
    if not (M.CanMeasure(anchor) and anchor.GetRect) then return end
    local ok, left, bottom, width, height = pcall(anchor.GetRect, anchor)
    if not ok then unavailableGeometry[anchor] = true; return end
    if not (readable(left) and readable(bottom) and readable(width) and readable(height)) then return end
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then return end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
    overlay:SetSize(width * ratio, height * ratio)
    return true
end

local function placeInactive(overlay, spec)
    local cfg = spec.settings()
    if not cfg then return end
    local scale = spec.scaled and (tonumber(cfg.scale) or 1) or 1
    if scale > 10 then scale = scale / 100 end
    if scale <= 0 then scale = 1 end
    local x, y = getPosition(spec)
    local point, relative = "CENTER", "CENTER"
    if spec.inactiveAnchor then point, relative = spec.inactiveAnchor(cfg) end
    overlay:ClearAllPoints()
    overlay:SetPoint(point, UIParent, relative, (tonumber(x) or 0) * scale,
        (tonumber(y) or 0) * scale * (spec.invertY and -1 or 1))
    overlay:SetSize(math.max(44, (tonumber(cfg.width or cfg.barWidth) or 125) * scale),
        math.max(23, (tonumber(cfg.height or cfg.barHeight or cfg.hpHeight) or 28) * scale))
    overlay.positionScale = scale
    return true
end

local function startDrag(overlay)
    local spec = overlay.spec
    if not active or drag or InCombatLockdown() or not spec.settings() then return end
    selectEntry(spec)
    if not dragChecks[spec] or not dragChecks[spec]:GetChecked() then return end
    local frame = overlay.liveFrame and getFrame(spec)
    if frame and spec.canDrag and not spec.canDrag() then frame = nil end
    local anchors = {}
    local function capture(target)
        if anchors[target] or not M.CanMeasure(target) then return end
        local points = {}
        for index = 1, target:GetNumPoints() do
            local ok, point, relative, alignment, x, y = pcall(target.GetPoint, target, index)
            if not ok or not (readable(point) and readable(relative) and readable(alignment) and readable(x) and readable(y)) then return end
            points[index] = {point, relative, alignment, x, y}
        end
        if #points > 0 then anchors[target] = points end
    end
    local target = frame or overlay
    capture(target)
    if not anchors[target] then return end
    if frame and spec.related then
        for _, candidate in ipairs(spec.related()) do capture(candidate) end
    end
    local x, y = GetCursorPosition()
    local settingX, settingY = getPosition(spec)
    local scale = frame and frame:GetEffectiveScale() or UIParent:GetEffectiveScale() * (overlay.positionScale or 1)
    drag = {spec = spec, frame = frame, overlay = overlay, moving = anchors, cursorX = x, cursorY = y,
        scale = spec.scaled and scale or UIParent:GetEffectiveScale(), x = settingX or 0, y = settingY or 0, dx = 0, dy = 0}
end

local function stopDrag()
    local motion = drag
    if not motion then return end
    drag = nil
    setPosition(motion.spec, motion.x + motion.dx / motion.scale, motion.y + motion.dy / motion.scale * (motion.spec.invertY and -1 or 1))
    refreshInspector()
end

local function makeOverlay(spec)
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    if spec.overlayWhenSelected then frame:SetFrameLevel(frame:GetFrameLevel() + 5) end
    frame.moverLevel = frame:GetFrameLevel()
    if selection == spec then frame:SetFrameLevel(frame.moverLevel + 10) end
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame:SetBackdropColor(0.08, 0.035, 0.11, 0.10)
    local label = addon.Inventory.Label(frame)
    label:SetPoint("CENTER")
    label:SetText(spec.label)
    label:SetWordWrap(false)
    frame:SetScript("OnClick", function() selectEntry(spec) end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", startDrag)
    frame:SetScript("OnDragStop", stopDrag)
    frame.spec = spec
    frame:Hide()
    return frame
end

local function syncOverlays()
    for _, spec in ipairs(M.entries) do
        local frame = getFrame(spec)
        local overlay = overlays[spec]
        local allowed = not spec.canDrag or spec.canDrag()
        if (frame or spec.settings()) and (not spec.overlayWhenSelected or selection == spec) then
            if not overlay then overlay = makeOverlay(spec); overlays[spec] = overlay end
            local source = allowed and (frame or getFrame(spec, true)) or nil
            local measured = source and overlayPosition(overlay, source)
            overlay.liveFrame = measured and frame or nil
            overlay.positionScale = measured and source:GetEffectiveScale() / UIParent:GetEffectiveScale() or nil
            local positioned = measured or placeInactive(overlay, spec)
            overlay:SetShown(not not positioned)
            overlay:SetBackdropColor(0.08, 0.035, 0.11, overlay.liveFrame and 0.10 or 0.32)
            overlay:SetBackdropBorderColor(addon.Theme:AccentInk(selection == spec and 0.95 or overlay.liveFrame and 0.48 or 0.34))
        elseif overlay then overlay:Hide() end
    end
end

local function prepareRows()
    for index = #panel.items + 1, #M.entries do
        local spec = M.entries[index]
        local row = button(list, spec.label, 114, function() selectEntry(spec) end)
        row.spec = spec
        row:SetPoint("TOPLEFT", 23, -25 * (index - 1))
        local check = addon.Theme:CreateCheckbox(list)
        check:SetSize(20, 20)
        check:SetPoint("RIGHT", row, "LEFT", -2, 0)
        addon.Theme:SettingsHelp(check, "Unlock " .. spec.label, "Allows you to drag this frame until Movers closes.")
        dragChecks[spec] = check
        panel.items[index] = row
    end
    for _, check in pairs(dragChecks) do check:SetChecked(false) end
    list:SetHeight(math.max(1, 25 * #panel.items))
end

local function makePanel()
    fields, overlays, dragChecks = {}, {}, {}
    panel = CreateFrame("Frame", "BaziUIMovers", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("TOOLTIP")
    panel:SetSize(416, 375)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -22)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    panel:SetBackdropColor(0.071, 0.048, 0.076, 0.97)
    panel:SetBackdropBorderColor(0.82, 0.65, 0.43, 1)
    panel:EnableMouse(true)
    local handle = CreateFrame("Frame", "BaziUIMoversDragHandle", panel)
    handle:SetPoint("TOPLEFT", 4, -4)
    handle:SetPoint("TOPRIGHT", -85, -4)
    handle:SetHeight(46)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() panel:StartMoving(); panel.moving = true end)
    local function stopMoving()
        if panel.moving then panel:StopMovingOrSizing(); panel.moving = nil end
    end
    handle:SetScript("OnDragStop", stopMoving)
    panel:HookScript("OnHide", stopMoving)
    local label = addon.Inventory.Label(handle, "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", 13, -10)
    label:SetText("Movers")
    local note = addon.Inventory.Label(handle)
    note:SetPoint("TOPLEFT", 14, -33)
    note:SetText("Check a module to drag it. Click to fine-tune.")
    local check = addon.Theme:CreateCheckbox(panel)
    check:SetSize(22, 22)
    check:SetPoint("TOPRIGHT", -12, -8)
    local gridLabel = addon.Inventory.Label(panel)
    gridLabel:SetPoint("RIGHT", check, "LEFT", -5, 0)
    gridLabel:SetText("Grid")
    check:SetScript("OnClick", function(self)
        if self:GetChecked() then addon.LayoutGrid.Show("movers", true)
        else addon.LayoutGrid.Hide() end
    end)
    panel.gridCheck = check
    panel.selected = addon.Inventory.Label(panel, "GameFontNormal")
    panel.selected:SetPoint("TOPLEFT", 183, -61)
    panel.visibility = addon.Inventory.Label(panel)
    panel.visibility:SetPoint("TOPLEFT", 183, -79)
    panel.visibility:SetTextColor(0.79, 0.72, 0.65)
    local listHost = CreateFrame("Frame", nil, panel)
    listHost:SetPoint("TOPLEFT", 6, -54)
    listHost:SetPoint("BOTTOMLEFT", 6, 39)
    listHost:SetWidth(170)
    list = addon.Inventory.Scroll(listHost, 0, 0)
    panel.items = {}
    panel.arrows = {}
    for index, direction in ipairs({{"<", -1, 0}, {"^", 0, 1}, {"v", 0, -1}, {">", 1, 0}}) do
        local arrow = button(panel, direction[1], 25, function()
            if not selection then return end
            local x, y = getPosition(selection)
            local step = IsShiftKeyDown() and 10 or 1
            setPosition(selection, x + direction[2] * step, y + direction[3] * step * (selection.invertY and -1 or 1))
            refreshInspector()
        end)
        arrow:SetPoint("BOTTOMLEFT", 183 + (index - 1) * 28, 40)
        panel.arrows[index] = arrow
    end
    button(panel, "Cancel", 72, function() M.Finish(false) end):SetPoint("BOTTOMLEFT", 183, 9)
    button(panel, "Apply", 100, function() M.Finish(true) end):SetPoint("BOTTOMRIGHT", -10, 9)
end

local function update(_, elapsed)
    if InCombatLockdown() then return end
    if drag then
        if not IsMouseButtonDown("LeftButton") then stopDrag(); return end
        local motion = drag
        local x, y = GetCursorPosition()
        local dx, dy = x - motion.cursorX, y - motion.cursorY
        if motion.dx == dx and motion.dy == dy then return end
        motion.dx, motion.dy = dx, dy
        for object, points in pairs(motion.moving) do
            local scale = object:GetEffectiveScale()
            object:ClearAllPoints()
            for _, point in ipairs(points) do
                object:SetPoint(point[1], point[2], point[3], (point[4] or 0) + motion.dx / scale,
                    (point[5] or 0) + motion.dy / scale)
            end
        end
        if motion.frame then overlayPosition(motion.overlay, motion.frame) end
        return
    end
    syncElapsed = syncElapsed + elapsed
    if syncElapsed >= 0.15 then syncElapsed = 0; syncOverlays() end
end

function M.Finish(apply, combat)
    if not active then return end
    if drag and not combat then stopDrag() end
    if apply and not combat then
        for _, row in ipairs(fields) do if row.edit:HasFocus() then row.edit:ClearFocus() end end
    end
    local interrupted = combat and drag
    active, drag = false, nil
    driver:SetScript("OnUpdate", nil)
    panel:Hide()
    for _, overlay in pairs(overlays) do overlay:Hide() end
    if interrupted then driver.interrupted = interrupted end
    if not apply and not combat then
        for spec, change in pairs(changes) do
            local cfg = spec.settings() or change.cfg
            for _, setting in ipairs(change.values) do cfg[setting[1]] = setting[2] end
            change.cfg = cfg
        end
        for spec, change in pairs(changes) do spec.apply(change.cfg) end
    end
    changes = nil
    addon.LayoutGrid.Show("movers", false)
    addon.Dashboard.LayoutMode(false)
    if addon.SmartAlerts then addon.SmartAlerts.LayoutMode(false) end
    for _, layout in ipairs(M.layouts) do layout(false) end
    if reopen and not combat and addon.Options then addon.Options:Open() end
    reopen = nil
end

function M.Open(options, selected)
    if active then M.Finish(true); return false end
    if InCombatLockdown() then addon:Print("Movers is available outside combat."); return false end
    if not panel then makePanel() end
    reopen, active, changes, syncElapsed = options, true, {}, 0
    prepareRows()
    addon.Dashboard.LayoutMode(true)
    if addon.SmartAlerts then addon.SmartAlerts.LayoutMode(true) end
    for _, layout in ipairs(M.layouts) do layout(true) end
    panel.gridCheck:SetChecked(addon.LayoutGrid.IsShown())
    panel:Show()
    if selected then
        for _, spec in ipairs(M.entries) do if spec.label == selected then selection = spec; break end end
    end
    syncOverlays()
    selectEntry(selection)
    driver:SetScript("OnUpdate", update)
    return true
end

driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then M.Finish(true, true)
    elseif self.interrupted then
        local previous = self.interrupted
        self.interrupted = nil
        for frame, points in pairs(previous.moving) do
            if M.CanMeasure(frame) then
                frame:ClearAllPoints()
                for _, point in ipairs(points) do frame:SetPoint(unpack(point, 1, 5)) end
            end
        end
        previous.spec.apply()
    end
end)
