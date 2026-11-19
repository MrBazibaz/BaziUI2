-- Optional proportional resizing for selected Blizzard windows.
-- Scaling preserves the native layout; no protected frame is modified in combat.
local addon = BaziUI
addon.WindowResize = addon.WindowResize or {}
local M = addon.WindowResize

M.windows = {
    { key = "character", label = "Character Pane", frames = {"CharacterFrame"} },
    { key = "spellbook", label = "Spellbook", frames = {"SpellBookFrame"} },
    { key = "questlog", label = "Quest Log", frames = {"QuestLogFrame"} },
    { key = "dungeon", label = "Dungeon Journal", frames = {"EncounterJournal"} },
    { key = "talents", label = "Talents", frames = {"PlayerTalentFrame", "ClassTalentFrame", "PlayerSpellsFrame"} },
    { key = "guild", label = "Guild", frames = {"GuildFrame", "CommunitiesFrame"} },
    { key = "achievements", label = "Achievements", frames = {"AchievementFrame"} },
    { key = "collections", label = "Collections", frames = {"CollectionsJournal"} },
    { key = "friends", label = "Friends / Social", frames = {"FriendsFrame"} },
    { key = "professions", label = "Professions", frames = {"ProfessionsFrame", "TradeSkillFrame"} },
    { key = "bags", label = "Bags", frames = {"ContainerFrame1"} },
}
local installed = {}
local function settings(key)
    local qol = addon.db and addon.db.profile and addon.db.profile.qol
    if not qol then return nil end
    qol.resizeWindows = qol.resizeWindows or {}
    qol.resizeWindows[key] = qol.resizeWindows[key] or {enabled = false, draggable = true, scale = 1}
    return qol.resizeWindows[key]
end
local function clamp(value)
    return math.max(0.75, math.min(1.65, value))
end
local function update(entry)
    local frame = _G[entry.frameName]
    if not frame then return end
    local cfg = settings(entry.key)
    if not cfg then return end
    if InCombatLockdown and InCombatLockdown() then return end
    frame:SetScale(clamp(cfg.scale or 1))
    if cfg.position and cfg.position.x and cfg.position.y and not entry.positionApplied then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.position.x, cfg.position.y)
        entry.positionApplied = true
    end
    if entry.move then entry.move:SetShown(cfg.enabled and cfg.draggable ~= false and frame:IsShown()) end
    if entry.left then entry.left:SetShown(cfg.enabled and frame:IsShown()) end
    if entry.right then entry.right:SetShown(cfg.enabled and frame:IsShown()) end
end
local function install(key, name)
    if installed[name] then return end
    local frame = _G[name]
    if not frame or not frame.GetScale or not frame.SetScale then return end
    installed[name] = true
    local entry = {key=key, frameName=name}
    local function handle(side)
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(28, 28)
        grip:SetFrameStrata("TOOLTIP")
        grip:SetFrameLevel(frame:GetFrameLevel() + 25)
        grip:SetPoint(side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", frame,
            side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", side == "LEFT" and -5 or 5, -5)
        grip:EnableMouse(true)
        grip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
        local lines = grip:CreateTexture(nil, "OVERLAY")
        lines:SetAllPoints()
        lines:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        lines:SetVertexColor(1, 0.82, 0.38, 1)
        if side == "LEFT" then
            lines:SetTexCoord(1, 0, 0, 1)
        end
        grip:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" or (InCombatLockdown and InCombatLockdown()) then return end
            local cfg = settings(key)
            if not cfg or not cfg.enabled then return end
            self.dragging = true
            self.startX, self.startY = GetCursorPosition()
            self.startScale = clamp(cfg.scale or 1)
            self.startWidth = math.max(200, frame:GetWidth())
            self.startHeight = math.max(150, frame:GetHeight())
            self:SetScript("OnUpdate", function(g)
                if not g.dragging then return end
                if InCombatLockdown and InCombatLockdown() then
                    g.dragging = false
                    g:SetScript("OnUpdate", nil)
                    return
                end
                local x, y = GetCursorPosition()
                local direction = side == "LEFT" and -1 or 1
                local delta = ((x - g.startX) * direction + (g.startY - y)) / 2
                local scale = clamp(g.startScale + delta / (g.startWidth * 0.75))
                cfg.scale = math.floor(scale * 100 + 0.5) / 100
                frame:SetScale(cfg.scale)
            end)
        end)
        grip:SetScript("OnMouseUp", function(self)
            self.dragging = false
            self:SetScript("OnUpdate", nil)
        end)
        grip:SetScript("OnHide", function(self)
            self.dragging = false
            self:SetScript("OnUpdate", nil)
        end)
        grip:Hide()
        return grip
    end
    entry.left, entry.right = handle("LEFT"), handle("RIGHT")
    -- Header overlay is a move handle. Leave room for Blizzard close/buttons
    -- on the right; resizing remains independent of the Drag setting.
    local move = CreateFrame("Button", nil, frame)
    move:SetHeight(20)
    move:SetPoint("TOPLEFT", frame, "TOPLEFT", 55, -4)
    move:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -65, -4)
    move:SetFrameLevel(frame:GetFrameLevel() + 18)
    move:RegisterForDrag("LeftButton")
    move:SetScript("OnDragStart", function()
        local cfg = settings(key)
        if not cfg or not cfg.enabled or cfg.draggable == false then return end
        if InCombatLockdown and InCombatLockdown() then return end
        if frame.IsProtected and frame:IsProtected() then return end
        frame:SetMovable(true)
        frame:StartMoving()
    end)
    move:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local cfg = settings(key)
        if cfg and cfg.enabled then
            local left, top = frame:GetLeft(), frame:GetTop()
            if left and top then
                local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                cfg.position = {x = math.floor(left * scale + 0.5), y = math.floor(top * scale + 0.5)}
                entry.positionApplied = true
            end
        end
    end)
    move:Hide()
    entry.move = move

    frame:HookScript("OnShow", function() update(entry) end)
    frame:HookScript("OnSizeChanged", function() update(entry) end)
    update(entry)
    M.entries = M.entries or {}
    M.entries[#M.entries+1] = entry
end
function M:Refresh()
    for _, window in ipairs(self.windows) do
        for _, name in ipairs(window.frames) do install(window.key, name) end
    end
    for _, entry in ipairs(self.entries or {}) do update(entry) end
end
function M:Initialize()
    if self.started then return end
    self.started = true
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() M:Refresh() end)
    self:Refresh()
end
function M:GetSetting(key)
    return settings(key)
end
function M:SetScale(key, percent)
    local cfg = settings(key)
    local value = tonumber(percent)
    if not cfg or not value then return false end
    cfg.scale = math.floor(clamp(value / 100) * 100 + 0.5) / 100
    self:Refresh()
    return true
end

-- Coordinates use UIParent units, measured from its bottom-left corner.
-- Y represents the window's top edge. Saved values are applied on the next
-- refresh and whenever a window is loaded later.
function M:GetPosition(key)
    local cfg = settings(key)
    if not cfg then return nil end
    if cfg.position then return cfg.position.x, cfg.position.y end
    for _, entry in ipairs(self.entries or {}) do
        if entry.key == key then
            local frame = _G[entry.frameName]
            if frame and frame:GetLeft() and frame:GetTop() then
                local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                return math.floor(frame:GetLeft() * scale + 0.5),
                    math.floor(frame:GetTop() * scale + 0.5)
            end
        end
    end
    return nil
end
function M:SetPosition(key, x, y)
    local cfg = settings(key)
    if not cfg or not cfg.enabled then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    cfg.position = {x = math.floor(x + 0.5), y = math.floor(y + 0.5)}
    for _, entry in ipairs(self.entries or {}) do
        if entry.key == key then entry.positionApplied = false end
    end
    self:Refresh()
    return true
end
