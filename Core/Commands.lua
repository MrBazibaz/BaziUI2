local addon = BaziUI

addon.Commands = addon.Commands or {}

local function HandleCommand(message)
    local command, argument = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    argument = string.lower(argument or "")

    if command == "" then
        addon.Options:Open()
    elseif command == "version" then
        addon:Print("version " .. addon.version)
    elseif command == "reload" then
        ReloadUI()
    elseif command == "reset" then
        StaticPopup_Show("BAZIUI_RESET_CONFIRM")
    else
        addon:Print("Commands: /bazi, /bazi version, /bazi reload, /bazi reset")
    end
end

function addon.Commands:Initialize()
    SLASH_BAZI1 = "/bazi"
    SLASH_BAZI2 = "/bui"
    SlashCmdList.BAZI = HandleCommand

    if not StaticPopupDialogs["BAZIUI_RESET_CONFIRM"] then
        StaticPopupDialogs["BAZIUI_RESET_CONFIRM"] = {
            text = "Reset all Bazi UI settings to their defaults?",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                BaziUIDB = nil
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
end
