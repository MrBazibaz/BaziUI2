local addonName, namespace = ...

BaziUI = BaziUI or namespace or {}
local addon = BaziUI

addon.name = addonName or "BaziUI"
addon.version = "0.1.2"
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

    if self.Options and self.Options.Initialize then
        self.Options:Initialize()
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

    self:Print("loaded. Type /bazi or /bui to open settings.")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addon.name then
        addon:OnInitialize()
    end
end)
