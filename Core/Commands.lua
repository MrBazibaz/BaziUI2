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

local function InspectBlizzardFrames()
    BaziUIDB = BaziUIDB or {}
    local lines = {}
    local function Add(value) lines[#lines + 1] = value end
    local function Scan(frame, path, depth)
        if not frame or depth > 4 or #lines > 650 then return end
        if frame.GetBackdrop then
            local ok, backdrop = pcall(frame.GetBackdrop, frame)
            if ok and backdrop then
                Add(path .. " BACKDROP edge=" .. tostring(backdrop.edgeFile)
                    .. " bg=" .. tostring(backdrop.bgFile)
                    .. " edgeSize=" .. tostring(backdrop.edgeSize))
            end
        end
        if frame.GetRegions then
            local regions = {frame:GetRegions()}
            for i, region in ipairs(regions) do
                if region.IsObjectType and region:IsObjectType("Texture") then
                    local texture = region.GetTexture and region:GetTexture()
                    if texture then
                        local layer = region.GetDrawLayer and region:GetDrawLayer() or "?"
                        Add(path .. "/region" .. i .. " name="
                            .. tostring(region.GetName and region:GetName())
                            .. " texture=" .. tostring(texture)
                            .. " layer=" .. tostring(layer))
                    end
                end
            end
        end
        if frame.GetChildren then
            local children = {frame:GetChildren()}
            for i, child in ipairs(children) do
                Scan(child, path .. "/" .. tostring(child.GetName and child:GetName() or ("child" .. i)), depth + 1)
            end
        end
    end
    local candidates = {
        "CharacterFrame", "PaperDollFrame", "SpellBookFrame",
        "WorldMapFrame", "EncounterJournal", "PVEFrame",
    }
    for _, name in ipairs(candidates) do
        local frame = _G[name]
        if frame then
            Add("=== " .. name .. " ===")
            Scan(frame, name, 0)
        else
            Add(name .. " not loaded")
        end
    end
    BaziUIDB.frameInspect = lines
    addon:Print("Frame inspection: " .. #lines .. " lines saved to BaziUIDB.frameInspect.")
    addon:Print("Open Character and Spellbook first, then /bazi inspect, /rl.")
    addon:Print("Share frameInspect from WTF/Account/<account>/SavedVariables/BaziUI.lua.")
end

local function InspectMapBorder()
    BaziUIDB = BaziUIDB or {}
    local lines = {}
    local function Add(line)
        if #lines < 350 then lines[#lines + 1] = line end
    end
    local function Scan(frame, path, depth)
        if not frame or depth > 7 or #lines >= 350 then return end
        if frame.GetBackdrop then
            local ok, bd = pcall(frame.GetBackdrop, frame)
            if ok and bd and bd.edgeFile then
                Add(path .. " BACKDROP edge=" .. tostring(bd.edgeFile)
                    .. " size=" .. tostring(bd.edgeSize))
            end
        end
        if frame.GetRegions then
            for i, region in ipairs({frame:GetRegions()}) do
                if region.IsObjectType and region:IsObjectType("Texture") then
                    local texture = region.GetTexture and region:GetTexture()
                    if texture then
                        local name = region.GetName and region:GetName()
                        local layer, sub = region:GetDrawLayer()
                        local w, h = region:GetSize()
                        local coord = region.GetTexCoord and {region:GetTexCoord()} or {}
                        local points = {}
                        if region.GetNumPoints then
                            for j = 1, math.min(region:GetNumPoints(), 2) do
                                local p, relative, rp, x, y = region:GetPoint(j)
                                points[#points + 1] = tostring(p) .. ":" ..
                                    tostring(relative and relative.GetName and relative:GetName() or "?") ..
                                    ":" .. tostring(rp) .. ":" .. tostring(x) .. "," .. tostring(y)
                            end
                        end
                        Add(path .. "/region" .. i .. " name=" .. tostring(name)
                            .. " texture=" .. tostring(texture)
                            .. " layer=" .. tostring(layer) .. "/" .. tostring(sub)
                            .. " size=" .. tostring(w) .. "x" .. tostring(h)
                            .. " texcoord=" .. table.concat(coord, ",")
                            .. " points=" .. table.concat(points, ";"))
                    end
                end
            end
        end
        if frame.GetChildren then
            for i, child in ipairs({frame:GetChildren()}) do
                local name = child.GetName and child:GetName() or ("child" .. i)
                Scan(child, path .. "/" .. tostring(name), depth + 1)
            end
        end
    end
    local candidates = {"WorldMapFrame", "WorldMapFrame.BorderFrame", "CharacterFrame", "SpellBookFrame"}
    for _, name in ipairs(candidates) do
        local frame = _G[name]
        if name == "WorldMapFrame.BorderFrame" then
            frame = _G.WorldMapFrame and _G.WorldMapFrame.BorderFrame
        end
        if frame then
            Add("=== " .. name .. " ===")
            Scan(frame, name, 0)
        else
            Add(name .. " not loaded")
        end
    end
    BaziUIDB.mapBorderInspect = lines
    addon:Print("Map border inspection: " .. #lines .. " lines saved.")
    addon:Print("Use /rl and share mapBorderInspect in SavedVariables/BaziUI.lua.")
end

-- Probe actual templates on this client without changing the options window.
local function InspectFrameTemplates()
    BaziUIDB = BaziUIDB or {}
    local report = {}
    local function Log(line) report[#report + 1] = line end
    Log("NineSlice global: " .. type(_G.NineSlice))
    Log("NineSliceUtil global: " .. type(_G.NineSliceUtil))
    Log("BackdropTemplateMixin global: " .. type(_G.BackdropTemplateMixin))
    Log("NineSlicePanelMixin global: " .. type(_G.NineSlicePanelMixin))
    local templates = {
        "ButtonFrameTemplate",
        "PortraitFrameTemplate",
        "BasicFrameTemplate",
        "NineSlicePanelTemplate",
        "BackdropTemplate",
    }
    for _, template in ipairs(templates) do
        local ok, frameOrError = pcall(CreateFrame, "Frame", nil, UIParent, template)
        if not ok or not frameOrError then
            Log(template .. ": FAILED " .. tostring(frameOrError))
        else
            local f = frameOrError
            f:Hide()
            Log(template .. ": CREATED")
            Log("  NineSlice=" .. tostring(f.NineSlice ~= nil)
                .. " SetBackdrop=" .. tostring(type(f.SetBackdrop))
                .. " SetPortraitToTexture=" .. tostring(type(f.SetPortraitToTexture)))
            local function Walk(node, prefix, depth)
                if depth > 2 then return end
                if node.GetRegions then
                    for _, region in ipairs({node:GetRegions()}) do
                        if region.IsObjectType and region:IsObjectType("Texture") then
                            local texture = region.GetTexture and region:GetTexture()
                            if texture then
                                Log("  " .. prefix .. " texture=" .. tostring(texture)
                                    .. " name=" .. tostring(region.GetName and region:GetName()))
                            end
                        end
                    end
                end
                if node.GetChildren then
                    for i, child in ipairs({node:GetChildren()}) do
                        Walk(child, prefix .. "/" .. tostring(child.GetName and child:GetName() or i), depth + 1)
                    end
                end
            end
            Walk(f, template, 0)
        end
    end
    for _, name in ipairs({"CharacterFrame", "SpellBookFrame", "WorldMapFrame"}) do
        local f = _G[name]
        Log(name .. ": " .. (f and ("present, NineSlice=" .. tostring(f.NineSlice ~= nil)) or "not loaded"))
    end
    BaziUIDB.templateInspect = report
    addon:Print("Template probe complete: " .. #report .. " lines in templateInspect.")
    addon:Print("Use /rl, then share BaziUI.lua SavedVariables.")
end

local function HandleCommand(message)
    local command, argument = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    argument = string.lower(argument or "")

    if command == "" then
        local ok, err = pcall(function() addon.Options:Open() end)
        if not ok then
            addon:Print("Options error: " .. tostring(err))
        end
    elseif command == "version" then
        addon:Print("version " .. addon.version)
    elseif command == "reload" then
        ReloadUI()
    elseif command == "inspecttemplates" then
        InspectFrameTemplates()
    elseif command == "inspectmap" then
        InspectMapBorder()
    elseif command == "inspect" then
        InspectBlizzardFrames()
    elseif command == "debugborder" then
        DebugBorder()
    elseif command == "reset" then
        StaticPopup_Show("BAZIUI_RESET_CONFIRM")
    else
        addon:Print("Commands: /bazi, /bazi version, /bazi reload, /bazi reset, /bazi debugborder, /bazi inspect, /bazi inspectmap, /bazi inspecttemplates")
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
