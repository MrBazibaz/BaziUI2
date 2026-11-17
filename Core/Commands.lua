local addon = BaziUI

addon.Commands = addon.Commands or {}

local function DebugBorder()
    local frame = _G.BaziUIOptionsFrame
    if not frame then
        addon.Options:Open()
        frame = _G.BaziUIOptionsFrame
    end
    if not frame then addon:Print("Options frame not found."); return end

    -- Save full findings to SavedVariables so chat truncation cannot lose them.
    BaziUIDB = BaziUIDB or {}
    local lines = {}
    local function Record(line)
        lines[#lines + 1] = line
    end
    local function DescribeRegion(region, owner, index)
        if not region or not region.IsObjectType or not region:IsObjectType("Texture") then return end
        local texture = region.GetTexture and region:GetTexture()
        local layer, sublayer = region:GetDrawLayer()
        local name = region.GetName and region:GetName() or "unnamed"
        Record(owner .. "[" .. index .. "] " .. tostring(name)
            .. " layer=" .. tostring(layer) .. "/" .. tostring(sublayer)
            .. " texture=" .. tostring(texture))
    end
    local function Scan(owner, label)
        if not owner or not owner.GetRegions then return end
        local regions = { owner:GetRegions() }
        for i, region in ipairs(regions) do DescribeRegion(region, label, i) end
        if owner.GetBackdrop then
            local backdrop = owner:GetBackdrop()
            if backdrop then
                Record(label .. " backdrop edge=" .. tostring(backdrop.edgeFile)
                    .. " bg=" .. tostring(backdrop.bgFile))
            end
        end
    end

    Scan(frame, "OptionsFrame")
    for i, child in ipairs({ frame:GetChildren() }) do
        local name = child.GetName and child:GetName() or "unnamed"
        local label = "Child" .. i .. ":" .. tostring(name)
        Scan(child, label)
        if child.GetChildren then
            for j, grandchild in ipairs({ child:GetChildren() }) do
                Scan(grandchild, label .. "/Child" .. j)
            end
        end
    end
    BaziUIDB.borderDebug = lines
    addon:Print("Border scan complete: " .. #lines .. " entries saved to BaziUIDB.borderDebug.")
    addon:Print("Use /rl, then open WTF/Account/<account>/SavedVariables/BaziUI.lua.")
    addon:Print("Search for borderDebug and share that section via GitHub.")
end

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
    elseif command == "debugborder" then
        DebugBorder()
    elseif command == "reset" then
        StaticPopup_Show("BAZIUI_RESET_CONFIRM")
    else
        addon:Print("Commands: /bazi, /bazi version, /bazi reload, /bazi reset, /bazi debugborder")
    end
end

function addon.Commands:Initialize()
    SLASH_BAZI1 = "/bazi"
    SLASH_BAZI2 = "/bui"
    SlashCmdList.BAZI = HandleCommand

    SLASH_BAZIUIRELOAD1 = "/rl"
    SlashCmdList.BAZIUIRELOAD = function()
        ReloadUI()
    end

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
