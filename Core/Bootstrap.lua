local addonName, namespace = ...

BaziUI = BaziUI or namespace or {}
local addon = BaziUI

addon.name = addonName or "BaziUI"
addon.version = "1.1.3"
addon.modules = addon.modules or {}

function addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd36aBazi UI:|r " .. tostring(message))
end

function addon:OnInitialize()
    if self.initialized then
        return
    end

    self.initialized = true

    if self.Database and self.Database.Initialize then
        self.Database:Initialize()
    end

    if self.Theme and self.Theme.Initialize then
        self.Theme:Initialize()
    end

    -- Register slash commands before optional modules: a module error must not
    -- make /bazi disappear and leave the user without access to settings.
    if self.Commands and self.Commands.Initialize then
        self.Commands:Initialize()
    end

    if self.WindowResize and self.WindowResize.Initialize then
        local ok, err = pcall(function() self.WindowResize:Initialize() end)
        if not ok then self:Print("Window Resize initialization failed: " .. tostring(err)) end
    end

    if self.Options and self.Options.Initialize then
        self.Options:Initialize()
    end

    if self.Minimap and self.Minimap.Initialize then
        local ok, err = pcall(function() self.Minimap:Initialize() end)
        if not ok then self:Print("Minimap initialization failed: " .. tostring(err)) end
    end

    if self.UnitFrames and self.UnitFrames.Initialize then
        local ok, err = pcall(function() self.UnitFrames:Initialize() end)
        if not ok then self:Print("Unit Frames initialization failed: " .. tostring(err)) end
    end

    if self.Nameplates and self.Nameplates.Initialize then
        local ok, err = pcall(function() self.Nameplates:Initialize() end)
        if not ok then self:Print("Nameplates initialization failed: " .. tostring(err)) end
    end

    if self.ActionBars then
        local ok, err = pcall(self.ActionBars.Initialize, self.ActionBars)
        if not ok then self:Print("Action Bars initialization failed: " .. tostring(err)) end
    end

    if self.ItemLevel and self.ItemLevel.Initialize then
        local ok, err = pcall(function() self.ItemLevel:Initialize() end)
        if not ok then self:Print("Item Level initialization failed: " .. tostring(err)) end
    end

    if self.Tooltip and self.Tooltip.Initialize then
        local ok, err = pcall(function() self.Tooltip:Initialize() end)
        if not ok then
            self:Print("Tooltip initialization failed: " .. tostring(err))
        end
    end

    if self.Dashboard then self.Dashboard.Refresh() end

    self:Print("loaded. Type /bazi or /bui to open settings.")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
local savedVariablesLoaded
loader:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= addon.name then return end
        savedVariablesLoaded = true
        self:UnregisterEvent("ADDON_LOADED")
        if not addon.Database:CharacterKey() then return end
    end
    if not savedVariablesLoaded then return end
    self:UnregisterEvent("PLAYER_LOGIN")
    addon:OnInitialize()
end)
