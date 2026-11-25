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

local function InspectGameMenu()
    local menu = _G.GameMenuFrame
    if not menu then addon:Print("GameMenuFrame is not loaded."); return end
    BaziUIDB = BaziUIDB or {}
    local report = {}
    local function Add(line) report[#report + 1] = line end
    local function DescribeRegion(region, prefix)
        if not region or not region.IsObjectType or not region:IsObjectType("Texture") then return end
        local ok, texture = pcall(region.GetTexture, region)
        local atlas = region.GetAtlas and region:GetAtlas()
        local layer = region:GetDrawLayer()
        Add(prefix .. " name=" .. tostring(region:GetName()) ..
            " texture=" .. tostring(ok and texture or "error") ..
            " atlas=" .. tostring(atlas) .. " layer=" .. tostring(layer) ..
            " shown=" .. tostring(region:IsShown()))
    end
    for _, button in ipairs({menu:GetChildren()}) do
        if button.IsObjectType and button:IsObjectType("Button") then
            Add("BUTTON " .. tostring(button:GetName()) ..
                " styled=" .. tostring(button.baziHoverStyled) ..
                " mouseover=" .. tostring(button:IsMouseOver()))
            DescribeRegion(button:GetNormalTexture(), " normal")
            DescribeRegion(button:GetHighlightTexture(), " highlight")
            DescribeRegion(button:GetPushedTexture(), " pushed")
            for i, region in ipairs({button:GetRegions()}) do
                DescribeRegion(region, " region" .. i)
            end
        end
    end
    BaziUIDB.gameMenuInspect = report
    addon:Print("Game Menu scan saved: " .. #report .. " lines. Type /reload, then share BaziUI.lua from SavedVariables.")
end

-- Measure the real on-screen geometry rather than guessing offsets.
local function InspectOptionsLayout()
    local frame = _G.BaziUIOptionsFrame
    if not frame then addon.Options:Open(); frame = _G.BaziUIOptionsFrame end
    if not frame then addon:Print("Options frame unavailable."); return end
    BaziUIDB = BaziUIDB or {}
    local lines = {}
    local function Add(t) if #lines < 160 then lines[#lines + 1] = t end end
    local function Num(v) return v and string.format("%.2f", v) or "nil" end
    local function Box(obj, label)
        if not obj then return end
        Add(label .. " name=" .. tostring(obj.GetName and obj:GetName()) ..
            " level=" .. tostring(obj.GetFrameLevel and obj:GetFrameLevel()) ..
            " scale=" .. Num(obj.GetEffectiveScale and obj:GetEffectiveScale()) ..
            " left=" .. Num(obj:GetLeft()) .. " right=" .. Num(obj:GetRight()) ..
            " top=" .. Num(obj:GetTop()) .. " bottom=" .. Num(obj:GetBottom()) ..
            " w=" .. Num(obj:GetWidth()) .. " h=" .. Num(obj:GetHeight()))
        if obj.GetTexture then
            Add(label .. " texture=" .. tostring(obj:GetTexture()) ..
                " atlas=" .. tostring(obj.GetAtlas and obj:GetAtlas()))
        end
    end
    Box(frame, "options")
    local function Walk(node, label, depth)
        if depth > 3 or #lines >= 150 then return end
        for i, region in ipairs({node:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                local tex = region:GetTexture()
                local atlas = region.GetAtlas and region:GetAtlas()
                if tex or atlas then Box(region, label .. "/tex" .. i) end
            end
        end
        for i, child in ipairs({node:GetChildren()}) do
            local childLabel = label .. "/child" .. i
            local name = child.GetName and child:GetName()
            local isClose = child.IsObjectType and child:IsObjectType("Button")
            local isEmblem = child.GetWidth and child:GetWidth() >= 45 and child:GetWidth() <= 70
                and child:GetHeight() >= 45 and child:GetHeight() <= 70
            if isClose or isEmblem or depth == 0 then Box(child, childLabel) end
            Walk(child, childLabel, depth + 1)
        end
    end
    Walk(frame, "options", 0)
    BaziUIDB.optionsLayoutInspect = lines
    addon:Print("Options geometry saved (" .. #lines .. " lines). /reload then share SavedVariables/BaziUI.lua.")
end

local function InspectUIControls()
    local frame = _G.BaziUIOptionsFrame
    if not frame then addon.Options:Open(); frame = _G.BaziUIOptionsFrame end
    if not frame then addon:Print("Bazi UI frame not found."); return end
    BaziUIDB = BaziUIDB or {}
    local lines = {}
    local function Info(label, obj)
        if not obj then lines[#lines+1] = label .. ": missing"; return end
        local function V(n) return n and string.format("%.1f", n) or "nil" end
        local alpha = obj.GetEffectiveAlpha and obj:GetEffectiveAlpha()
            or (obj.GetAlpha and obj:GetAlpha())
        lines[#lines+1] = label .. " shown=" .. tostring(obj:IsShown()) ..
            " visible=" .. tostring(obj:IsVisible()) ..
            " alpha=" .. V(alpha) ..
            " level=" .. tostring(obj.GetFrameLevel and obj:GetFrameLevel()) ..
            " strata=" .. tostring(obj.GetFrameStrata and obj:GetFrameStrata()) ..
            " left=" .. V(obj:GetLeft()) .. " top=" .. V(obj:GetTop()) ..
            " width=" .. V(obj:GetWidth()) .. " height=" .. V(obj:GetHeight())
        if obj.GetTexture then
            lines[#lines+1] = label .. " texture=" .. tostring(obj:GetTexture()) ..
                " atlas=" .. tostring(obj.GetAtlas and obj:GetAtlas())
        end
    end
    Info("frame", frame)
    Info("emblemHost", frame.baziEmblemHost)
    Info("emblemTexture", frame.baziEmblem)
    Info("close", frame.baziClose)
    if frame.baziClose then
        Info("closeNormal", frame.baziClose:GetNormalTexture())
    end
    BaziUIDB.uiControlInspect = lines
    addon:Print("UI control inspection saved. /reload, then upload BaziUI.lua.")
end

local stopCombatProbe
local function ProbeCombat()
    if stopCombatProbe then stopCombatProbe(true); return end
    if not debugprofilestop then addon:Print("Combat probe requires debugprofilestop."); return end

    local frame = CreateFrame("Frame")
    local methods, timings = {}, {}
    local combatSeen = InCombatLockdown and InCombatLockdown()
    local endedAt, peakAt
    local peak = 0
    local function stop(cancelled)
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        frame:SetScript("OnEvent", nil)
        for _, entry in ipairs(methods) do
            if entry.module[entry.method] == entry.wrapper then
                entry.module[entry.method] = entry.original
            end
        end
        stopCombatProbe = nil
        if cancelled then addon:Print("Combat probe cancelled."); return end
        addon:Print(string.format("Combat probe: longest frame %.1f ms at +%.0f ms.", peak, peakAt - endedAt))
        for _, entry in ipairs(methods) do
            local sample = timings[entry.name]
            if sample then
                addon:Print(string.format("%s: %d calls, %.1f ms total, peak %.1f ms at %+.0f ms.",
                    entry.name, sample.count, sample.total, sample.peak, sample.time - endedAt))
            end
        end
    end

    for _, name in ipairs({"UnitFrames", "GroupFrames", "PartyFrames", "BossFrames", "RaidFrames", "WindowResize", "Nameplates"}) do
        local module = addon[name]
        local method = name == "Nameplates" and "Apply" or "Refresh"
        local original = module and module[method]
        if type(original) == "function" then
            local function wrapper(self, ...)
                if not combatSeen or (InCombatLockdown and InCombatLockdown()) then
                    return original(self, ...)
                end
                local started = debugprofilestop()
                original(self, ...)
                local duration = debugprofilestop() - started
                local sample = timings[name]
                if not sample then
                    sample = {count = 0, total = 0, peak = -1}
                    timings[name] = sample
                end
                sample.count = sample.count + 1
                sample.total = sample.total + duration
                if duration > sample.peak then
                    sample.peak, sample.time = duration, started
                end
            end
            methods[#methods + 1] = {module = module, method = method, original = original, wrapper = wrapper, name = name}
            module[method] = wrapper
        end
    end

    stopCombatProbe = stop
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            combatSeen = true
            endedAt, peakAt, peak = nil, nil, 0
            timings = {}
            frame:SetScript("OnUpdate", nil)
            return
        end
        endedAt = debugprofilestop()
        frame:SetScript("OnUpdate", function(_, elapsed)
            local now = debugprofilestop()
            if not peakAt or elapsed * 1000 > peak then peak, peakAt = elapsed * 1000, now end
            if now - endedAt >= 3000 then stop(false) end
        end)
    end)
    addon:Print("Combat probe armed. The report appears three seconds after leaving combat.")
end

local playerProbe
local function ProbePlayerPlate()
    if playerProbe then playerProbe(); return end
    if not debugprofilestop then addon:Print("Player probe requires debugprofilestop."); return end

    local frame = CreateFrame("Frame")
    local startedAt, peakAt, peak, players = nil, nil, 0, 0
    local function stop()
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        frame:SetScript("OnUpdate", nil)
        playerProbe = nil
    end
    playerProbe = function()
        stop()
        addon:Print("Player probe cancelled.")
    end
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:SetScript("OnEvent", function(_, _, unit)
        if not UnitIsPlayer(unit) then return end
        players = players + 1
        if startedAt then return end
        startedAt = debugprofilestop()
        frame:SetScript("OnUpdate", function(_, elapsed)
            local now = debugprofilestop()
            if not peakAt or elapsed * 1000 > peak then peak, peakAt = elapsed * 1000, now end
            if now - startedAt < 3000 then return end
            stop()
            addon:Print(string.format("Player probe: %d player plates, longest frame %.1f ms at +%.0f ms.",
                players, peak, peakAt - startedAt))
        end)
    end)
    addon:Print("Player probe armed. Move toward a player with nameplates enabled.")
end

local function HandleCommand(message)
    local command, argument = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    argument = string.lower(argument or "")

    if command == "" then
        local ok, err = pcall(function()
            addon.Options:Open()
        end)
        if not ok then
            addon:Print("Options error: " .. tostring(err))
        end
    elseif command == "move" then
        addon.Movers.Open()
    elseif command == "help" then
        addon:Print("Commands: /bazi (open settings), /bazi move, /bazi help, /bazi version, /bazi reload, /bazi reset")
        addon:Print("Diagnostics: /bazi inspect, /bazi inspectmap, /bazi inspecttemplates, /bazi inspectoptions, /bazi inspectuicontrols, /bazi inspectgamemenu, /bazi debugborder")
    elseif command == "version" then
        addon:Print("version " .. addon.version)
    elseif command == "reload" then
        ReloadUI()
    elseif command == "chatsound" or command == "soundtrace" then
        if addon.Chat then addon.Chat.ToggleSoundTrace() end
    elseif command == "inspectuicontrols" then
        InspectUIControls()
    elseif command == "inspectoptions" then
        InspectOptionsLayout()
    elseif command == "inspectgamemenu" then
        InspectGameMenu()
    elseif command == "inspecttemplates" then
        InspectFrameTemplates()
    elseif command == "inspectmap" then
        InspectMapBorder()
    elseif command == "inspect" then
        InspectBlizzardFrames()
    elseif command == "gatheringprobe" then
        addon.Gathering:ProbeCorpses()
    elseif command == "swingprobe" then
        addon.ActionBars:ProbeQueuedAction()
    elseif command == "playerprobe" then
        ProbePlayerPlate()
    elseif command == "combatprobe" then
        ProbeCombat()
    elseif command == "debugborder" then
        DebugBorder()
    elseif command == "reset" then
        StaticPopup_Show("BAZIUI_RESET_CONFIRM")
    else
        addon:Print("Commands: /bazi, /bazi version, /bazi reload, /bazi reset, /bazi debugborder, /bazi inspect, /bazi inspectmap, /bazi inspecttemplates")
    end
end

local dialogAssets = "Interface\\AddOns\\BaziUI\\Assets\\"
local function StyleDialogBackground(frame)
    if frame.baziDialogBackground then return end
    if frame.NineSlice and frame.NineSlice.Center then frame.NineSlice.Center:SetAlpha(0) end
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, 5)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    background:SetColorTexture(0.12, 0.075, 0.044, 0.98)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
    art:SetAllPoints(background)
    art:SetTexture(dialogAssets .. "Panels\\Panel_Dark.png")
    art:SetAlpha(0.30)
    frame.baziDialogBackground, frame.baziDialogArt = background, art
end

local function HideNativeButtonArt(frame, nativeArt)
    if frame.IsForbidden and frame:IsForbidden() then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region:IsObjectType("Texture") then
            nativeArt[#nativeArt + 1] = region
            region:SetAlpha(0)
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if not child:IsObjectType("Button") then
            HideNativeButtonArt(child, nativeArt)
        end
    end
end

function addon.Commands:StyleDialogButton(button, freshTextures)
    if button.IsForbidden and button:IsForbidden() then return end
    if button.baziDialogButton then
        if button.baziOldDialogArt then
            for _, region in ipairs(button.baziOldDialogArt) do region:SetAlpha(0) end
        end
        return
    end
    button.baziDialogButton = true
    for _, key in ipairs({"Left", "Middle", "Right"}) do
        local part = button[key]
        if part then
            part:SetAlpha(0)
            if hooksecurefunc then
                hooksecurefunc(part, "SetAlpha", function(texture, alpha)
                    if alpha ~= 0 then texture:SetAlpha(0) end
                end)
            end
        end
    end
    local root = dialogAssets .. "Buttons\\Button_"
    if freshTextures then
        local nativeArt = {}
        HideNativeButtonArt(button, nativeArt)
        button.baziOldDialogArt = nativeArt
        -- Game Menu's pooled buttons can retain the old atlas tint and UVs.
        -- Start with clean regions so the same artwork looks like Quick Keybind.
        for _, spec in ipairs({
            {"GetNormalTexture", "SetNormalTexture", "Normal", "ARTWORK"},
            {"GetPushedTexture", "SetPushedTexture", "Pressed", "ARTWORK"},
            {"GetDisabledTexture", "SetDisabledTexture", "Disabled", "ARTWORK"},
            {"GetHighlightTexture", "SetHighlightTexture", "Hover", "HIGHLIGHT"},
        }) do
            local previous = button[spec[1]](button)
            if previous then previous:SetAlpha(0) end
            local region = button:CreateTexture(nil, spec[4])
            region:SetAllPoints(button)
            region:SetTexture(root .. spec[3] .. ".png")
            region:SetBlendMode("BLEND")
            button[spec[2]](button, region)
        end
    else
        button:SetNormalTexture(root .. "Normal.png")
        button:SetPushedTexture(root .. "Pressed.png")
        button:SetDisabledTexture(root .. "Disabled.png")
        button:SetHighlightTexture(root .. "Hover.png", "BLEND")
    end
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    local text = button:GetFontString()
    if text then text:SetTextColor(1, 0.81, 0.45) end
end

local function StyleQuickKeybind(frame)
    if frame.baziQuickKeybindStyled or (InCombatLockdown and InCombatLockdown()) then return end
    local instructions, cancelText, output = frame.InstructionText, frame.CancelDescriptionText, frame.OutputText
    local okay, defaults, cancel = frame.OkayButton, frame.DefaultsButton, frame.CancelButton
    local character = frame.UseCharacterBindingsButton
    if not (instructions and cancelText and output and okay and defaults and cancel and character) then return end
    frame.baziQuickKeybindStyled = true
    if frame.BG then frame.BG:SetAlpha(0) end
    StyleDialogBackground(frame)
    local edge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    edge:SetAllPoints(frame)
    edge:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12})
    edge:SetBackdropBorderColor(0.90, 0.72, 0.42, 1)
    edge:EnableMouse(false)
    frame:SetSize(424, 200)
    local function PlaceText(text, y, height)
        text:ClearAllPoints()
        text:SetPoint("TOP", frame, "TOP", 0, y)
        text:SetSize(390, height)
        text:SetDrawLayer("OVERLAY", 6)
    end
    PlaceText(instructions, -27, 42)
    PlaceText(cancelText, -73, 28)
    PlaceText(output, -101, 20)
    character:ClearAllPoints()
    character:SetPoint("TOP", frame, "TOP", -87, -124)
    for i, button in ipairs({okay, defaults, cancel}) do
        button:ClearAllPoints()
        button:SetPoint("BOTTOM", frame, "BOTTOM", (i - 2) * 126, 12)
        button:SetSize(i == 2 and 134 or 110, 28)
        addon.Commands:StyleDialogButton(button)
    end
end

local function HookQuickKeybindStyle()
    local frame = _G.QuickKeybindFrame
    if not frame or frame.baziQuickKeybindHooked then return end
    frame.baziQuickKeybindHooked = true
    frame:HookScript("OnShow", StyleQuickKeybind)
    if frame:IsShown() then StyleQuickKeybind(frame) end
end

local function StyleGameMenu()
    local menu = _G.GameMenuFrame
    if not menu then return end
    StyleDialogBackground(menu)
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for button in menu.buttonPool:EnumerateActive() do addon.Commands:StyleDialogButton(button, true) end
    end
    for _, button in ipairs({menu:GetChildren()}) do
        local name = button.GetName and button:GetName()
        if button.IsObjectType and button:IsObjectType("Button")
            and name and name:match("^GameMenuButton") then addon.Commands:StyleDialogButton(button, true) end
    end
end

local function StyleExitPopup(which)
    if which ~= "CAMP" and which ~= "QUIT" then return end
    for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local frame = _G["StaticPopup" .. index]
        if frame and frame.which == which and frame:IsShown() and not frame.baziExitActive then
            local center = frame.NineSlice and frame.NineSlice.Center
            local centerAlpha = center and center:GetAlpha()
            StyleDialogBackground(frame)
            frame.baziDialogBackground:Show()
            frame.baziDialogArt:Show()
            if center then center:SetAlpha(0) end
            local restore = {}
            for _, region in pairs({frame.NineSlice, frame.BG or frame.Bg or frame.BgTexture}) do
                local alpha = region:GetAlpha()
                region:SetAlpha(0)
                restore[#restore + 1] = function() region:SetAlpha(alpha) end
            end
            if not frame.baziExitBorder then
                local menu = _G.GameMenuFrame
                local backdrop = menu and menu.GetBackdrop and menu:GetBackdrop()
                local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
                border:SetAllPoints(frame)
                border:SetBackdrop({
                    edgeFile = backdrop and backdrop.edgeFile or "Interface\\DialogFrame\\UI-DialogBox-Border",
                    edgeSize = backdrop and backdrop.edgeSize or 24,
                })
                if backdrop and menu.GetBackdropBorderColor then
                    border:SetBackdropBorderColor(menu:GetBackdropBorderColor())
                end
                frame.baziExitBorder = border
            end
            frame.baziExitBorder:Show()
            frame.baziExitTextures = frame.baziExitTextures or {}
            for slot = 1, 4 do
                local button = (frame.GetButton and frame:GetButton(slot))
                    or frame["button" .. slot] or _G["StaticPopup" .. index .. "Button" .. slot]
                if button and button:IsShown() then
                    local root = dialogAssets .. "Buttons\\Button_"
                    local textures = frame.baziExitTextures[button] or {}
                    frame.baziExitTextures[button] = textures
                    for _, spec in ipairs({
                        {"Normal", "Normal", "ARTWORK"}, {"Pushed", "Pressed", "ARTWORK"},
                        {"Disabled", "Disabled", "ARTWORK"}, {"Highlight", "Hover", "HIGHLIGHT"},
                    }) do
                        local state, art, layer = unpack(spec)
                        local setter = button["Set" .. state .. "Texture"]
                        local old = button["Get" .. state .. "Texture"](button)
                        local alpha = old and old:GetAlpha()
                        local texture = textures[state]
                        if not texture then
                            texture = button:CreateTexture(nil, layer)
                            texture:SetAllPoints(button)
                            texture:SetTexture(root .. art .. ".png")
                            textures[state] = texture
                        end
                        if old then old:SetAlpha(0) end
                        setter(button, texture)
                        restore[#restore + 1] = function()
                            setter(button, old)
                            texture:Hide()
                            if old then old:SetAlpha(alpha) end
                        end
                    end
                    for _, key in ipairs({"Left", "Middle", "Right"}) do
                        local region = button[key]
                        if region then
                            local alpha = region:GetAlpha()
                            region:SetAlpha(0)
                            restore[#restore + 1] = function() region:SetAlpha(alpha) end
                        end
                    end
                end
            end
            frame.baziExitActive = function()
                frame.baziExitBorder:Hide()
                frame.baziDialogBackground:Hide()
                frame.baziDialogArt:Hide()
                if center then center:SetAlpha(centerAlpha) end
                for _, undo in ipairs(restore) do undo() end
            end
            if not frame.baziExitHooked then
                frame.baziExitHooked = true
                frame:HookScript("OnHide", function(self)
                    if self.baziExitActive then self.baziExitActive(); self.baziExitActive = nil end
                end)
            end
        end
    end
end

function addon.Commands:Initialize()
    if hooksecurefunc and StaticPopup_Show then hooksecurefunc("StaticPopup_Show", StyleExitPopup) end
    HookQuickKeybindStyle()
    if not _G.QuickKeybindFrame then
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, _, name)
            if name == "Blizzard_QuickKeybind" then
                self:UnregisterEvent("ADDON_LOADED")
                HookQuickKeybindStyle()
            end
        end)
    end
    if _G.GameMenuFrame then
        StyleGameMenu()
        _G.GameMenuFrame:HookScript("OnShow", StyleGameMenu)
        if hooksecurefunc and _G.GameMenuFrame.InitButtons then
            hooksecurefunc(_G.GameMenuFrame, "InitButtons", StyleGameMenu)
        end
    end
    SLASH_BAZICHECK1 = "/bic"
    SlashCmdList.BAZICHECK = InspectUIControls

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
