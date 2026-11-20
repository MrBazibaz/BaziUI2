local addon = BaziUI

addon.Options = addon.Options or {}

local optionsFrame
local contentFrame
local navButtons = {}
local pages = {}
local pageFactories = {}

local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"

local function CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text)
    return label
end

local function CreateDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(ASSET .. "Dividers\\Divider_Gold.png")
    line:SetVertexColor(0.90, 0.72, 0.49, 0.8)
    line:SetHeight(8)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    return line
end

local function CreateSection(parent, text, y)
    local heading = CreateLabel(parent, text, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    heading:SetTextColor(1, 0.79, 0.42, 1)
    return heading
end

local function CreatePanel(parent, top, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, top)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, top)
    panel:SetHeight(height)

    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(panel)
    fill:SetColorTexture(0.19, 0.105, 0.052, 0.97)
    local panelArt = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    panelArt:SetAllPoints(panel)
    panelArt:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    panelArt:SetAlpha(0.30)

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(0.76, 0.57, 0.29, 0.90)

    local topLine = panel:CreateTexture(nil, "BORDER")
    topLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.78, 0.59, 0.31, 0.45)
    return panel
end

local function CreateSlider(parent, labelText, description, minValue, maxValue, step, value, y, onValueChanged, compact)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, y)
    row:SetHeight(compact and 34 or 54)
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(row)
    fill:SetColorTexture(0.25, 0.125, 0.055, 0.96)
    local rowArt = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    rowArt:SetAllPoints(row)
    rowArt:SetTexture(ASSET .. "Panels\\Panel_Dark.png")
    rowArt:SetAlpha(0.20)
    local heading = CreateLabel(row, labelText, "GameFontNormal")
    heading:SetPoint("TOPLEFT", row, "TOPLEFT", 15, compact and -4 or -10)
    heading:SetTextColor(1, 0.78, 0.39)
    local hint = CreateLabel(row, description, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", row, "TOPLEFT", 15, compact and -19 or -30)
    hint:SetTextColor(0.91, 0.78, 0.61, 1)
    local valueText
    local valueBox
    if true then -- All numeric sliders support direct keyboard entry.
        valueBox = CreateFrame("EditBox", nil, row)
        valueBox:SetSize(36, 19)
        valueBox:SetPoint("RIGHT", row, "RIGHT", -13, 0)
        valueBox:SetAutoFocus(false)
        valueBox:SetFontObject("GameFontNormal")
        valueBox:SetTextColor(1, 0.81, 0.45)
        valueBox:SetJustifyH("CENTER")
        valueBox:SetMaxLetters(5)
        valueBox:SetTextInsets(2, 2, 0, 0)
        local boxFill = valueBox:CreateTexture(nil, "BACKGROUND")
        boxFill:SetAllPoints(valueBox)
        boxFill:SetColorTexture(0.12, 0.07, 0.045, 0.95)
        for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local border = valueBox:CreateTexture(nil, "ARTWORK")
            border:SetColorTexture(0.70, 0.50, 0.27, 0.85)
            if edge == "TOP" then
                border:SetPoint("TOPLEFT"); border:SetPoint("TOPRIGHT"); border:SetHeight(1)
            elseif edge == "BOTTOM" then
                border:SetPoint("BOTTOMLEFT"); border:SetPoint("BOTTOMRIGHT"); border:SetHeight(1)
            elseif edge == "LEFT" then
                border:SetPoint("TOPLEFT"); border:SetPoint("BOTTOMLEFT"); border:SetWidth(1)
            else
                border:SetPoint("TOPRIGHT"); border:SetPoint("BOTTOMRIGHT"); border:SetWidth(1)
            end
        end
        valueText = valueBox
    else
        valueText = CreateLabel(row, "", "GameFontNormal")
        valueText:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        valueText:SetTextColor(1, 0.81, 0.45)
    end
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(115, 18)
    slider:SetPoint("RIGHT", row, "RIGHT", -53, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(7)
    track:SetTexture(ASSET .. "Sliders\\Slider_Track.png")
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(24, 28)
    thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
    slider:SetThumbTexture(thumb)
    local progress = slider:CreateTexture(nil, "BORDER")
    progress:SetPoint("LEFT", track, "LEFT", 0, 0)
    progress:SetHeight(7)
    progress:SetTexture(ASSET .. "Sliders\\Slider_Fill_Gold.png")
    local function RefreshProgress(raw)
        local fraction = (raw - minValue) / (maxValue - minValue)
        progress:SetWidth(math.max(1, 115 * math.max(0, math.min(1, fraction))))
    end
    slider:SetScript("OnValueChanged", function(self, raw)
        local rounded = math.floor(raw / step + 0.5) * step
        if not valueBox or not valueBox:HasFocus() then
            valueText:SetText(string.format("%g", rounded))
        end
        RefreshProgress(rounded)
        if onValueChanged then onValueChanged(rounded) end
    end)
    slider:SetValue(value)
    if valueBox then
        if labelText == "WINDOW SCALE" then
            slider:SetScript("OnMouseUp", function()
                if optionsFrame and addon.db and addon.db.profile then
                    optionsFrame:SetScale(addon.db.profile.uiScale)
                end
            end)
        end
        local committing = false
        local function CommitValue()
            if committing then return end
            committing = true
            local input = valueBox:GetText() or ""
            local number = tonumber((input:gsub(",", ".")))
            if number then
                number = math.max(minValue, math.min(maxValue, number))
                number = math.floor(number / step + 0.5) * step
                -- SetValue updates the slider thumb and its OnValueChanged
                -- callback persists the new value to the profile.
                slider:SetValue(number)
                -- Force the saved value even when the slider was already there.
                if onValueChanged then onValueChanged(number) end
                if labelText == "WINDOW SCALE" and optionsFrame then
                    optionsFrame:SetScale(number)
                end
            end
            valueBox:SetText(string.format("%g", slider:GetValue()))
            valueBox:ClearFocus()
            committing = false
        end
        valueBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        valueBox:SetScript("OnEnterPressed", CommitValue)
        valueBox:SetScript("OnEditFocusLost", function()
            if not committing then CommitValue() end
        end)
        valueBox:SetScript("OnEscapePressed", function(self)
            self:SetText(string.format("%g", slider:GetValue()))
            self:ClearFocus()
        end)
    end
    RefreshProgress(value)
    valueText:SetText(string.format("%g", value))
    slider.valueBox = valueBox
    return slider
end

local function ShowPage(pageName)
    -- Build each settings page only when first selected. Existing page builders
    -- and module behavior remain unchanged; created pages are cached.
    if not pages[pageName] and pageFactories[pageName] then
        pageFactories[pageName]()
    end
    for name, page in pairs(pages) do
        page:SetShown(name == pageName)
    end

    for name, button in pairs(navButtons) do
        button.baziActive = (name == pageName)
        button.baziRefresh()
    end
end

local function CreateGeneralPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.General = page
    local introPanel = CreatePanel(page, -8, 66)
    CreateSection(introPanel, "GENERAL SETTINGS", -14)
    local intro = CreateLabel(page, "Adjust the Bazi UI window and default text size.", "GameFontHighlightSmall")
    intro:SetParent(introPanel)
    intro:SetPoint("TOPLEFT", introPanel, "TOPLEFT", 22, -39)
    intro:SetTextColor(0.96, 0.82, 0.63, 1)

    local appearancePanel = CreatePanel(page, -88, 242)
    CreateSection(appearancePanel, "APPEARANCE", -14)
    local db = addon.db.profile
    CreateSlider(page, "WINDOW SCALE", "Size of the Bazi UI settings window", 0.70, 1.50, 0.01, db.uiScale, -142, function(value)
        db.uiScale = value
        -- Apply scale on mouse release so the slider does not move under the cursor.
    end)
    CreateSlider(page, "FONT SIZE", "Default text size for supported modules", 10, 20, 1, db.fontSize, -204, function(value)
        db.fontSize = value
    end)
    return page
end

local function CreatePlaceholderPage(name, description)
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages[name] = page

    local placeholderPanel = CreatePanel(page, -12, 130)
    CreateSection(placeholderPanel, name, -14)
    CreateDivider(placeholderPanel, -48)

    local message = CreateLabel(page, description or "Settings for this module will appear here.", "GameFontHighlight")
    message:SetParent(placeholderPanel)
    message:SetPoint("TOPLEFT", placeholderPanel, "TOPLEFT", 22, -76)
    message:SetTextColor(0.96, 0.82, 0.63, 1)

    return page
end



local function CreateUnitFramesPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.UnitFrames = page
    local db = addon.db.profile.unitframes
    local activeTab = "General"
    local tabButtons, tabPanels = {}, {}
    local syncControls = {}

    local headingPanel = CreatePanel(page, -8, 76)
    CreateSection(headingPanel, "UNIT FRAMES", -12)
    local enabled = CreateFrame("CheckButton", nil, headingPanel, "UICheckButtonTemplate")
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    local enabledLabel = CreateLabel(headingPanel, "Enable Unit Frames", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        if addon.UnitFrames then addon.UnitFrames:Refresh() end
    end)

    local copyControls = {}
    local copyDropdowns = {}
    local copyHeader = CreateFrame("Frame", nil, headingPanel)
    copyHeader:SetPoint("TOPRIGHT", headingPanel, "TOPRIGHT", -16, -8)
    copyHeader:SetSize(360, 52)
    local main = CreatePanel(page, -100, 400)
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    if main.SetClipsChildren then main:SetClipsChildren(true) end

    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 261)
    local function RefreshTabs()
        copyHeader:SetShown(activeTab ~= "General")
        for _,dropdown in ipairs(copyDropdowns) do dropdown:Hide() end
        for name, controls in pairs(copyControls) do controls:SetShown(name == activeTab) end
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            button.fill:SetColorTexture(selected and 0.34 or 0.23,
                selected and 0.17 or 0.12, selected and 0.25 or 0.07, 0.98)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, panel in pairs(tabPanels) do panel:SetShown(name == activeTab) end
        if syncControls[activeTab] then syncControls[activeTab]() end
    end
    for i, name in ipairs({"General", "Player", "Target", "Focus", "Pet", "Target of Target", "Boss", "Party", "Raid"}) do
        local button = CreateFrame("Button", nil, tabBar)
        button:SetSize(108, 29)
        button:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -(i-1)*29)
        button.fill = button:CreateTexture(nil, "BACKGROUND")
        button.fill:SetAllPoints()
        button.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = button:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            button.edges[#button.edges+1] = edge
        end
        button.accent = button:CreateTexture(nil, "OVERLAY")
        button.accent:SetPoint("TOPRIGHT"); button.accent:SetPoint("BOTTOMRIGHT")
        button.accent:SetWidth(3)
        button.label = CreateLabel(button, name, "GameFontNormal")
        button.label:SetPoint("LEFT", button, "LEFT", 12, 0)
        button:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        button:SetScript("OnEnter", function()
            if activeTab ~= name then button.fill:SetColorTexture(0.28, 0.15, 0.085, 0.98) end
        end)
        button:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = button
    end

    for _, entry in ipairs({{"General",nil},{"Player","player"},{"Target","target"},{"Focus","focus"},{"Pet","pet"},{"Target of Target","targettarget"},{"Boss","boss"},{"Party","party"},{"Raid","raid"}}) do
        local name, key = entry[1], entry[2]
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetHeight(name == "General" and 480 or 490)
        panel:SetWidth(500)
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self) panel:SetWidth(math.max(1, self:GetWidth())) end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta*36)))
        end)
        tabPanels[name] = viewport
        if name == "General" then
            CreateSection(panel, "VISIBLE UNIT FRAMES", -12)
            CreateDivider(panel, -45)
            for i, item in ipairs({{"Player","player"},{"Target","target"},{"Focus","focus"},{"Pet","pet"},{"Target of Target","targettarget"}}) do
                local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60-(i-1)*36)
                local label = CreateLabel(panel, item[1], "GameFontHighlight")
                label:SetPoint("LEFT", check, "RIGHT", 5, 0)
                local key = item[2]
                check:SetScript("OnClick", function(self)
                    db[key] = not not self:GetChecked()
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                page:HookScript("OnShow", function() check:SetChecked(db[key] == true) end)
                check:SetChecked(db[key] == true)
            end
            db.groups = db.groups or {}
            local function enableGroup(kind, caption, y)
                db.groups[kind] = db.groups[kind] or {}
                local opt = db.groups[kind]
                local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",panel,"TOPLEFT",16,y)
                local label = CreateLabel(panel,caption,"GameFontHighlight")
                label:SetPoint("LEFT",check,"RIGHT",5,0)
                check:SetChecked(opt.enabled == true)
                check:SetScript("OnClick",function(self)
                    opt.enabled = self:GetChecked() == true
                    if addon.GroupFrames then addon.GroupFrames:Refresh() end
                end)
                page:HookScript("OnShow",function() check:SetChecked(opt.enabled == true) end)
            end
            enableGroup("boss","Enable Boss",-240)
            enableGroup("party","Enable Party",-276)
            enableGroup("raid","Enable Raid",-312)
            local move = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            move:SetSize(25,25)
            move:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -358)
            local moveLabel = CreateLabel(panel, "Move UnitFrames", "GameFontHighlight")
            moveLabel:SetPoint("LEFT", move, "RIGHT", 5, 0)
            move:SetScript("OnClick", function(self)
                local enabled=self:GetChecked()==true
                if not addon.UnitFrames:SetMoveMode(enabled) then
                    self:SetChecked(addon.UnitFrames:IsMoveMode())
                    addon:Print("Cannot move unit frames during combat.")
                    return
                end
                for _,module in ipairs({addon.BossFrames,addon.PartyFrames,addon.RaidFrames}) do
                    if module and module.SetMoveMode then module:SetMoveMode(enabled) end
                end
            end)
            page:HookScript("OnShow", function() move:SetChecked(addon.UnitFrames:IsMoveMode()) end)
        elseif (key == "party" or key == "boss") or key == "raid" or key == "boss" then
            db.groups = db.groups or {}
            db.groups[key] = db.groups[key] or {}
            local opt = db.groups[key]
            local function refreshGroup()
                if addon.GroupFrames then addon.GroupFrames:Refresh() end
                if key=="boss" and addon.BossFrames then addon.BossFrames:Refresh() end
                if key=="raid" and addon.RaidFrames then addon.RaidFrames:Refresh() end
            end
            local selectedMember = 1
            local memberRefreshers = {}
            local function memberSettings()
                opt.members = opt.members or {}
                opt.members[selectedMember] = opt.members[selectedMember] or {}
                return opt.members[selectedMember]
            end
            local function memberValue(field,default)
                local member=memberSettings()
                if member[field] ~= nil then return member[field] end
                if opt[field] ~= nil then return opt[field] end
                return default
            end
            local function refreshMemberControls()
                for _,refresh in ipairs(memberRefreshers) do refresh() end
            end
            local sourceKind, sourceIndex = "player", 1
            local memberCount = key=="raid" and 40 or (key=="party" and 4 or 5)
            local function headerButton(parent,label,x,width)
                local button=CreateFrame("Button",nil,parent)
                button:SetSize(width,28)
                button:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-4)
                local fill=button:CreateTexture(nil,"BACKGROUND")
                fill:SetAllPoints()
                fill:SetColorTexture(.24,.12,.06,.98)
                local edges={}
                for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
                    local line=button:CreateTexture(nil,"OVERLAY")
                    line:SetColorTexture(.72,.53,.29,.9)
                    if side=="TOP" then line:SetPoint("TOPLEFT");line:SetPoint("TOPRIGHT");line:SetHeight(1)
                    elseif side=="BOTTOM" then line:SetPoint("BOTTOMLEFT");line:SetPoint("BOTTOMRIGHT");line:SetHeight(1)
                    elseif side=="LEFT" then line:SetPoint("TOPLEFT");line:SetPoint("BOTTOMLEFT");line:SetWidth(1)
                    else line:SetPoint("TOPRIGHT");line:SetPoint("BOTTOMRIGHT");line:SetWidth(1) end
                    edges[#edges+1]=line
                end
                local caption=CreateLabel(button,label,"GameFontNormal")
                caption:SetPoint("CENTER")
                return button,caption
            end
            local memberButton,memberText=headerButton(copyHeader,"",0,104)
            local sourceButton,sourceText=headerButton(copyHeader,"",110,112)
            local copyButton=headerButton(copyHeader,"Copy settings",228,128)
            local applyButton=headerButton(headingPanel,"Apply to all",16,125)
            applyButton:ClearAllPoints()
            applyButton:SetPoint("TOPRIGHT",headingPanel,"TOPRIGHT",-388,-10)
            local sourceChoices={{"Player","player",1},{"Target","target",1},{"Focus","focus",1},{"Pet","pet",1},{"Target of Target","targettarget",1}}
            for _,kind in ipairs({"party","boss","raid"}) do
                local count=kind=="raid" and 40 or kind=="party" and 4 or 5
                for index=1,count do
                    sourceChoices[#sourceChoices+1]={string.upper(kind:sub(1,1))..kind:sub(2).." "..index,kind,index}
                end
            end
            local sourceCursor=1
            local function refreshHeader()
                memberText:SetText(key:sub(1,1):upper()..key:sub(2).." "..selectedMember.." / "..memberCount.."  v")
                sourceText:SetText("From: "..sourceChoices[sourceCursor][1].."  v")
            end
            -- Scrollable selection lists: never cycle through 40+ frames.
            local function makeDropdown(trigger,items,onSelect)
                local visible=math.min(9,#items)
                local popup=CreateFrame("Frame",nil,copyHeader)
                popup:SetSize(185,visible*26+8)
                popup:SetPoint("TOPLEFT",trigger,"BOTTOMLEFT",0,-3)
                popup:SetFrameStrata("FULLSCREEN_DIALOG")
                popup:SetFrameLevel(trigger:GetFrameLevel()+25)
                popup:EnableMouse(true)
                local bg=popup:CreateTexture(nil,"BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(.13,.075,.035,.98)
                local border=CreateFrame("Frame",nil,popup,"BackdropTemplate")
                border:SetAllPoints()
                border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
                border:SetBackdropBorderColor(.76,.56,.29,1)
                local offset=1
                local entries={}
                local function redraw()
                    for i,entry in ipairs(entries) do
                        local item=items[offset+i-1]
                        entry:SetShown(item~=nil)
                        if item then entry.text:SetText(item.label) end
                    end
                end
                for i=1,visible do
                    local entry=CreateFrame("Button",nil,popup)
                    entry:SetSize(173,25)
                    entry:SetPoint("TOPLEFT",popup,"TOPLEFT",6,-4-(i-1)*26)
                    local highlight=entry:CreateTexture(nil,"BACKGROUND")
                    highlight:SetAllPoints()
                    highlight:SetColorTexture(.32,.17,.09,.95)
                    highlight:Hide()
                    entry:SetScript("OnEnter",function() highlight:Show() end)
                    entry:SetScript("OnLeave",function() highlight:Hide() end)
                    entry.text=CreateLabel(entry,"","GameFontNormal")
                    entry.text:SetPoint("LEFT",entry,"LEFT",7,0)
                    entry:SetScript("OnClick",function()
                        local item=items[offset+i-1]
                        if item then onSelect(item);popup:Hide() end
                    end)
                    entries[i]=entry
                end
                popup:EnableMouseWheel(true)
                popup:SetScript("OnMouseWheel",function(_,delta)
                    offset=math.max(1,math.min(math.max(1,#items-visible+1),offset-delta))
                    redraw()
                end)
                popup:Hide()
                trigger:SetScript("OnClick",function()
                    local open=not popup:IsShown()
                    for _,other in ipairs(copyDropdowns) do other:Hide() end
                    if open then offset=1;redraw();popup:Show() end
                end)
                copyDropdowns[#copyDropdowns+1]=popup
                return popup
            end
            local memberItems={}
            for i=1,memberCount do
                memberItems[i]={label=key:sub(1,1):upper()..key:sub(2).." "..i,index=i}
            end
            local sourceItems={}
            for i,choice in ipairs(sourceChoices) do
                sourceItems[i]={label=choice[1],index=i}
            end
            local memberPopup=makeDropdown(memberButton,memberItems,function(item)
                selectedMember=item.index
                refreshHeader()
                refreshMemberControls()
            end)
            local sourcePopup=makeDropdown(sourceButton,sourceItems,function(item)
                sourceCursor=item.index
                sourceKind,sourceIndex=sourceChoices[sourceCursor][2],sourceChoices[sourceCursor][3]
                refreshHeader()
            end)
            copyButton:SetScript("OnClick",function()
                if addon.GroupFrames then addon.GroupFrames:CopyMember(key,sourceKind,sourceIndex,selectedMember) end
                refreshMemberControls()
            end)
            applyButton:SetScript("OnClick",function()
                if addon.GroupFrames then addon.GroupFrames:ApplyToAll(key,selectedMember) end
            end)
            refreshHeader()
            copyControls[name]={SetShown=function(_,shown) memberButton:SetShown(shown);sourceButton:SetShown(shown);copyButton:SetShown(shown);applyButton:SetShown(shown) end}
            local root = panel
            local sections = {}
            local sectionButtons = {}
            local function selectSection(selected)
                for label, canvas in pairs(sections) do canvas:SetShown(label == selected) end
                for label, button in pairs(sectionButtons) do
                    button.fill:SetColorTexture(label == selected and 0.36 or 0.25, label == selected and 0.20 or 0.13, label == selected and 0.28 or 0.07, 1)
                end
                root:SetHeight((key=="party" or key=="boss") and (selected=="Layout" and 1350 or selected=="Indicators" and 1350 or selected=="Bar Text" and 820 or selected=="Buffs / Debuffs" and 1230 or 580) or (key=="raid" and selected=="Layout" and 1350 or 610))
                viewport:SetVerticalScroll(0)
            end
            for i, label in ipairs({"Layout","Indicators","Bar Text","Fonts","Buffs / Debuffs"}) do
                local button = CreateFrame("Button",nil,root)
                button:SetSize(94,30)
                button:SetPoint("TOPLEFT",root,"TOPLEFT",12+(i-1)*96,-5)
                local bg=button:CreateTexture(nil,"BACKGROUND")
                bg:SetAllPoints()
                local title=CreateLabel(button,label,"GameFontNormal")
                title:SetPoint("CENTER")
                title:SetTextColor(1,0.82,0.52)
                button:SetScript("OnClick",function() selectSection(label) end)
                button.fill=bg
                sectionButtons[label] = button
                local canvas = CreateFrame("Frame",nil,root)
                canvas:SetPoint("TOPLEFT",root,"TOPLEFT",0,-48)
                canvas:SetPoint("TOPRIGHT",root,"TOPRIGHT",0,-48)
                canvas:SetHeight(540)
                canvas:Hide()
                sections[label] = canvas
            end
            panel = sections.Layout
            CreateSection(panel, string.upper(key) .. " LAYOUT", -12)
            CreateDivider(panel,-45)
            local function toggle(label, field, x, y)
                local check = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
                local caption = CreateLabel(panel,label,"GameFontHighlight")
                caption:SetPoint("LEFT",check,"RIGHT",5,0)
                check:SetChecked(opt[field] == true)
                check:SetScript("OnClick",function(self)
                    opt[field] = self:GetChecked() == true
                    refreshGroup()
                end)
                page:HookScript("OnShow",function() check:SetChecked(opt[field] == true) end)
            end
            toggle("Show when solo","showSolo",16,-62)
            local function setting(label,field,default,min,max,step,x,y,shared)
                local syncing=false
                local function current()
                    if shared then return tonumber(opt[field]) or default end
                    return tonumber(memberValue(field,default)) or default
                end
                local row = CreateSlider(panel,string.upper(label),label,min,max,step,current(),y,function(value)
                    if syncing then return end
                    if shared then opt[field]=value else memberSettings()[field]=value end
                    refreshGroup()
                end,false)
                local function refresh()
                    syncing=true
                    row:SetValue(current())
                    syncing=false
                end
                memberRefreshers[#memberRefreshers+1]=refresh
                page:HookScript("OnShow",refresh)
            end
            if (key=="party" or key=="boss") then
                local function nudge(label,field,x,y)
                    local caption=CreateLabel(panel,label,"GameFontNormal")
                    caption:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
                    local value=CreateLabel(panel,"0","GameFontHighlight")
                    value:SetPoint("LEFT",caption,"RIGHT",20,0)
                    local function redraw() value:SetText(tostring(tonumber(memberValue(field,0)) or 0)) end
                    for step,dx in pairs({[-1]=155,[1]=187}) do
                        local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
                        button:SetSize(29,24)
                        button:SetPoint("TOPLEFT",panel,"TOPLEFT",x+dx,y+5)
                        button:SetText(step<0 and "-" or "+")
                        button:SetScript("OnClick",function()
                            memberSettings()[field]=(tonumber(memberValue(field,0)) or 0)+step
                            redraw()
                            refreshGroup()
                        end)
                    end
                    memberRefreshers[#memberRefreshers+1]=redraw
                    redraw()
                end
            end
            if (key=="party" or key=="boss") then
                -- One full-width row per control, matching Player's layout.
                setting("HP / Mana Width","width",190,80,360,5,16,-125)
                setting("HP Height","hpHeight",23,12,45,1,16,-205)
                setting("Mana / Power Height","powerHeight",9,4,30,1,16,-285)
                setting("Portrait Size","portraitSize",60,36,90,1,16,-365)
                setting("Portrait X","portraitX",0,-40,40,1,16,-445)
                setting("Portrait Y","portraitY",0,-40,40,1,16,-525)
            else
                setting("Frame width","width",key~="raid" and 190 or 110,80,360,5,16,-125)
                setting("Frame height","height",key~="raid" and 48 or 30,22,90,1,270,-190)
                setting("Spacing","spacing",8,0,40,1,16,-255,true)
                setting("Name font size (0 hides)","nameFontSize",11,0,22,1,270,-320)
            end
            if key=="raid" then
                setting("Vertical spacing","verticalSpacing",8,0,80,1,270,-580,true)
                setting("Columns","columns",5,1,8,1,16,-385,true)
                setting("Horizontal offset","x",-380,-700,700,10,270,-450,true)
                setting("Vertical offset","y",-250,-500,500,10,16,-515,true)
                -- Raid group anchor: same dark/gold dropdown interaction as Tooltip.
                local choices={
                    {"TOPLEFT","Right / Down"},
                    {"TOPRIGHT","Left / Down"},
                    {"BOTTOMLEFT","Right / Up"},
                    {"BOTTOMRIGHT","Left / Up"},
                }
                local title=CreateLabel(panel,"GROUP ANCHOR","GameFontNormal")
                title:SetPoint("TOPLEFT",panel,"TOPLEFT",270,-655)
                title:SetTextColor(1,.79,.42)
                local anchorButton=CreateFrame("Button",nil,panel)
                anchorButton:SetSize(195,27)
                anchorButton:SetPoint("TOPLEFT",panel,"TOPLEFT",270,-677)
                local bg=anchorButton:CreateTexture(nil,"BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(.12,.07,.045,1)
                local border=anchorButton:CreateTexture(nil,"BORDER")
                border:SetPoint("TOPLEFT");border:SetPoint("TOPRIGHT");border:SetHeight(1)
                border:SetColorTexture(.75,.55,.29,1)
                local arrow=CreateLabel(anchorButton,"v","GameFontHighlightSmall")
                arrow:SetPoint("RIGHT",anchorButton,"RIGHT",-7,0)
                local valueText=CreateLabel(anchorButton,"","GameFontNormal")
                valueText:SetPoint("CENTER")
                valueText:SetTextColor(1,.79,.42)
                local menu=CreateFrame("Frame",nil,panel)
                menu:SetSize(195,#choices*24+4)
                menu:SetPoint("TOPLEFT",anchorButton,"BOTTOMLEFT",0,-2)
                menu:SetFrameStrata("FULLSCREEN_DIALOG")
                menu:SetFrameLevel(anchorButton:GetFrameLevel()+25)
                local menuBg=menu:CreateTexture(nil,"BACKGROUND")
                menuBg:SetAllPoints()
                menuBg:SetColorTexture(.12,.07,.045,1)
                local function redrawAnchor()
                    local selected=opt.anchor or "TOPLEFT"
                    for _,choice in ipairs(choices) do
                        if choice[1]==selected then valueText:SetText(choice[2]);return end
                    end
                    valueText:SetText("Right / Down")
                end
                for i,choice in ipairs(choices) do
                    local item=CreateFrame("Button",nil,menu)
                    item:SetPoint("TOPLEFT",menu,"TOPLEFT",2,-2-(i-1)*24)
                    item:SetPoint("TOPRIGHT",menu,"TOPRIGHT",-2,-2-(i-1)*24)
                    item:SetHeight(24)
                    local fill=item:CreateTexture(nil,"BACKGROUND")
                    fill:SetAllPoints()
                    fill:SetColorTexture(.12,.07,.045,1)
                    local itemText=CreateLabel(item,choice[2],"GameFontHighlightSmall")
                    itemText:SetPoint("LEFT",item,"LEFT",8,0)
                    item:SetScript("OnEnter",function() fill:SetColorTexture(.34,.18,.11,1) end)
                    item:SetScript("OnLeave",function() fill:SetColorTexture(.12,.07,.045,1) end)
                    item:SetScript("OnClick",function()
                        opt.anchor=choice[1]
                        menu:Hide()
                        redrawAnchor()
                        refreshGroup()
                    end)
                end
                anchorButton:SetScript("OnClick",function() menu:SetShown(not menu:IsShown()) end)
                page:HookScript("OnHide",function() menu:Hide() end)
                page:HookScript("OnShow",redrawAnchor)
                menu:Hide()
                redrawAnchor()
                -- Move the entire raid group, independently of per-member offsets.
                local function groupCoordinate(label,field,y)
                    local title=CreateLabel(panel,label,"GameFontNormal")
                    title:SetPoint("TOPLEFT",panel,"TOPLEFT",16,y)
                    title:SetTextColor(1,.79,.42)
                    local edit=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
                    edit:SetSize(76,24)
                    edit:SetPoint("TOPLEFT",panel,"TOPLEFT",16,y-22)
                    edit:SetAutoFocus(false)
                    edit:SetMaxLetters(9)
                    edit:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
                    local function current() return tonumber(opt[field]) or 0 end
                    local function redraw()
                        if not edit:HasFocus() then edit:SetText(tostring(current())) end
                    end
                    local function apply(value)
                        if InCombatLockdown and InCombatLockdown() then redraw();return end
                        if value==nil then redraw();return end
                        opt[field]=math.floor(value)
                        edit:ClearFocus()
                        redraw()
                        refreshGroup()
                    end
                    edit:SetScript("OnEnterPressed",function(self) apply(tonumber(self:GetText())) end)
                    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus();redraw() end)
                    edit:SetScript("OnEditFocusLost",redraw)
                    for i,delta in ipairs({1,-1}) do
                        local button=CreateFrame("Button",nil,panel)
                        button:SetSize(22,13)
                        button:SetPoint("TOPLEFT",edit,"TOPRIGHT",4,-(i-1)*13)
                        local bg=button:CreateTexture(nil,"BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(.23,.12,.065,1)
                        local buttonText=CreateLabel(button,delta==1 and "+" or "-","GameFontNormalSmall")
                        buttonText:SetPoint("CENTER")
                        buttonText:SetTextColor(1,.79,.42)
                        button:SetScript("OnClick",function() apply(current()+delta) end)
                    end
                    memberRefreshers[#memberRefreshers+1]=redraw
                    redraw()
                end
                groupCoordinate("RAID GROUP X","x",-755)
                groupCoordinate("RAID GROUP Y","y",-805)
                panel:SetHeight(1250)
                -- Explicit scroll control for Raid Layout, including when child controls capture the wheel.
                local function scrollRaid(delta)
                    local limit=math.max(0,root:GetHeight()-viewport:GetHeight())
                    viewport:SetVerticalScroll(math.max(0,math.min(limit,viewport:GetVerticalScroll()-delta*48)))
                end
                panel:EnableMouseWheel(true)
                panel:SetScript("OnMouseWheel",function(_,delta) scrollRaid(delta) end)
                local scrollUp=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
                scrollUp:SetSize(26,25)
                scrollUp:SetPoint("TOPRIGHT",main,"TOPRIGHT",-15,-52)
                scrollUp:SetText("▲")
                scrollUp:SetScript("OnClick",function() scrollRaid(1) end)
                local scrollDown=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
                scrollDown:SetSize(26,25)
                scrollDown:SetPoint("BOTTOMRIGHT",main,"BOTTOMRIGHT",-15,20)
                scrollDown:SetText("▼")
                scrollDown:SetScript("OnClick",function() scrollRaid(-1) end)
                page:HookScript("OnShow",function()
                    local shown=activeTab=="Raid"
                    scrollUp:SetShown(shown)
                    scrollDown:SetShown(shown)
                end)
            end
            local function groupRefresh()
                refreshGroup()
            end
            local function groupSlider(canvas,title,hint,field,min,max,default,y)
                local syncing=false
                local slider = CreateSlider(canvas,title,hint,min,max,1,memberValue(field,default),y,function(value)
                    if syncing then return end
                    memberSettings()[field] = value
                    groupRefresh()
                end,false)
                local function refresh()
                    syncing=true
                    slider:SetValue(memberValue(field,default))
                    syncing=false
                end
                memberRefreshers[#memberRefreshers+1]=refresh
                page:HookScript("OnShow",refresh)
            end
            local partyDropdown
            if (key=="party" or key=="boss") then
                -- Same compact edit field and stacked +/- controls as Player.
                local function coordinate(canvas,label,field,x,y,default)
                    local title=CreateLabel(canvas,label,"GameFontNormal")
                    title:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y)
                    title:SetTextColor(1,.79,.42)
                    local edit=CreateFrame("EditBox",nil,canvas,"InputBoxTemplate")
                    edit:SetSize(76,24)
                    edit:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y-22)
                    edit:SetAutoFocus(false)
                    edit:SetMaxLetters(9)
                    edit:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
                    local function current() return tonumber(memberValue(field,default or 0)) or (default or 0) end
                    local function redraw()
                        if not edit:HasFocus() then edit:SetText(tostring(current())) end
                    end
                    local function apply(value)
                        if not value then redraw();return end
                        memberSettings()[field]=math.floor(value)
                        edit:ClearFocus()
                        redraw()
                        groupRefresh()
                    end
                    edit:SetScript("OnEnterPressed",function(self) apply(tonumber(self:GetText())) end)
                    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus();redraw() end)
                    for i,delta in ipairs({1,-1}) do
                        local button=CreateFrame("Button",nil,canvas)
                        button:SetSize(22,13)
                        button:SetPoint("TOPLEFT",edit,"TOPRIGHT",4,-(i-1)*13)
                        local bg=button:CreateTexture(nil,"BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(.23,.12,.065,1)
                        local text=CreateLabel(button,delta==1 and "+" or "-","GameFontNormalSmall")
                        text:SetPoint("CENTER")
                        text:SetTextColor(1,.79,.42)
                        button:SetScript("OnClick",function() apply(current()+delta) end)
                    end
                    memberRefreshers[#memberRefreshers+1]=redraw
                    redraw()
                end
                -- Matching the dark-gold dropdown design already used by Player/Tooltip.
                partyDropdown = function(canvas,label,field,choices,x,y,width,default)
                    width=width or 170
                    local title=CreateLabel(canvas,label,"GameFontNormal")
                    title:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y)
                    title:SetTextColor(1,.79,.42)
                    local button=CreateFrame("Button",nil,canvas)
                    button:SetSize(width,27)
                    button:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y-22)
                    local bg=button:CreateTexture(nil,"BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(.12,.07,.045,1)
                    local border=button:CreateTexture(nil,"BORDER")
                    border:SetPoint("TOPLEFT");border:SetPoint("TOPRIGHT");border:SetHeight(1)
                    border:SetColorTexture(.75,.55,.29,1)
                    local arrow=CreateLabel(button,"v","GameFontHighlightSmall")
                    arrow:SetPoint("RIGHT",button,"RIGHT",-7,0)
                    local valueText=CreateLabel(button,"","GameFontNormal")
                    valueText:SetPoint("CENTER")
                    valueText:SetTextColor(1,.79,.42)
                    local menu=CreateFrame("Frame",nil,canvas)
                    menu:SetSize(width,#choices*24+4)
                    menu:SetPoint("TOPLEFT",button,"BOTTOMLEFT",0,-2)
                    menu:SetFrameStrata("FULLSCREEN_DIALOG")
                    menu:SetFrameLevel(button:GetFrameLevel()+25)
                    local menuBg=menu:CreateTexture(nil,"BACKGROUND")
                    menuBg:SetAllPoints()
                    menuBg:SetColorTexture(.12,.07,.045,1)
                    local function redraw()
                        local value=memberValue(field,default or choices[1][1])
                        for _,choice in ipairs(choices) do
                            if choice[1]==value then valueText:SetText(choice[2]);return end
                        end
                        valueText:SetText("Custom")
                    end
                    for i,choice in ipairs(choices) do
                        local item=CreateFrame("Button",nil,menu)
                        item:SetPoint("TOPLEFT",menu,"TOPLEFT",2,-2-(i-1)*24)
                        item:SetPoint("TOPRIGHT",menu,"TOPRIGHT",-2,-2-(i-1)*24)
                        item:SetHeight(24)
                        local fill=item:CreateTexture(nil,"BACKGROUND")
                        fill:SetAllPoints()
                        fill:SetColorTexture(.12,.07,.045,1)
                        local itemText=CreateLabel(item,choice[2],"GameFontHighlightSmall")
                        itemText:SetPoint("LEFT",item,"LEFT",8,0)
                        item:SetScript("OnEnter",function() fill:SetColorTexture(.34,.18,.11,1) end)
                        item:SetScript("OnLeave",function() fill:SetColorTexture(.12,.07,.045,1) end)
                        item:SetScript("OnClick",function()
                            memberSettings()[field]=choice[1]
                            menu:Hide()
                            redraw()
                            groupRefresh()
                        end)
                    end
                    button:SetScript("OnClick",function() menu:SetShown(not menu:IsShown()) end)
                    menu:Hide()
                    memberRefreshers[#memberRefreshers+1]=function() menu:Hide();redraw() end
                    redraw()
                end
                local function anchorButton(canvas,label,field,x,y)
                    partyDropdown(canvas,label,field,{{"LEFT","Left"},{"CENTER","Center"},{"RIGHT","Right"},{"HIDDEN","Hidden"}},x,y,190,"CENTER")
                end
                partyDropdown(sections.Layout,"PORTRAIT SIDE","portraitSide",{{"LEFT","Left"},{"RIGHT","Right"}},16,-730,190,selectedMember<=2 and "LEFT" or "RIGHT")
                if key~="boss" then coordinate(sections.Indicators,"ROLE PORTRAIT X","roleX",16,-910)
                coordinate(sections.Indicators,"ROLE PORTRAIT Y","roleY",260,-910)
                -- Existing profiles may store 1.5 instead of 150; normalize on edit.
                local roleSetting=memberSettings()
                if tonumber(roleSetting.rolePortraitScale) and tonumber(roleSetting.rolePortraitScale)<=5 then
                    roleSetting.rolePortraitScale=math.floor(roleSetting.rolePortraitScale*100+0.5)
                end
                coordinate(sections.Indicators,"ROLE SCALE %","rolePortraitScale",16,-995,150) end
                coordinate(sections.Layout,"FRAME X","offsetX",16,-670)
                coordinate(sections.Layout,"FRAME Y","offsetY",260,-670)
                coordinate(sections["Bar Text"],"NAME X","nameX",16,-470)
                coordinate(sections["Bar Text"],"NAME Y","nameY",260,-470)
                coordinate(sections["Bar Text"],"HP TEXT X","hpTextX",16,-560)
                coordinate(sections["Bar Text"],"HP TEXT Y","hpTextY",260,-560)
                coordinate(sections["Bar Text"],"POWER TEXT X","powerTextX",16,-650)
                coordinate(sections["Bar Text"],"POWER TEXT Y","powerTextY",260,-650)
                anchorButton(sections["Bar Text"],"Name anchor","nameAnchor",20,-310)
                anchorButton(sections["Bar Text"],"HP anchor","hpTextAnchor",270,-310)
                anchorButton(sections["Bar Text"],"Power anchor","powerTextAnchor",20,-385)
                for i,item in ipairs({{"PVP","pvp"},{"LEADER","leader"},{"RAID","raid"},{"ROLE","role"},{"CLASSIFICATION","classification"}}) do
                    coordinate(sections.Indicators,item[1].." X",item[2].."X",16,-430-(i-1)*90)
                    coordinate(sections.Indicators,item[1].." Y",item[2].."Y",260,-430-(i-1)*90)
                end
                local canvas=sections.Layout
                local check=CreateFrame("CheckButton",nil,canvas,"UICheckButtonTemplate")
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-810)
                local label=CreateLabel(canvas,"Show castbar","GameFontHighlight")
                label:SetPoint("LEFT",check,"RIGHT",5,0)
                local function syncCast() check:SetChecked(memberValue("showPartyCast",true)~=false) end
                check:SetScript("OnClick",function(self)
                    memberSettings().showPartyCast=self:GetChecked()==true
                    groupRefresh()
                end)
                memberRefreshers[#memberRefreshers+1]=syncCast
                syncCast()
                -- Castbar positioning is separate from cast spell text positioning.
                coordinate(canvas,"CASTBAR X","partyCastX",16,-860)
                coordinate(canvas,"CASTBAR Y","partyCastY",260,-860)
                coordinate(canvas,"CASTBAR WIDTH","partyCastWidth",16,-950,190)
                coordinate(canvas,"CASTBAR HEIGHT","partyCastHeight",260,-950,13)
                coordinate(canvas,"CAST TEXT X","partyCastTextX",16,-1040)
                coordinate(canvas,"CAST TEXT Y","partyCastTextY",260,-1040)
                groupSlider(sections.Fonts,"CASTBAR TEXT SIZE","Cast spell name font size","partyCastFontSize",0,24,10,-425)
            end
            panel=sections.Indicators
            if (key=="party" or key=="boss") then panel:SetHeight(1250) end
            CreateSection(panel,"INDICATORS",-12)
            CreateDivider(panel,-45)
            local function groupToggle(canvas,label,field,y)
                local check=CreateFrame("CheckButton",nil,canvas,"UICheckButtonTemplate")
                check:SetSize(25,25)
                check:SetPoint("TOPLEFT",canvas,"TOPLEFT",20,y)
                local text=CreateLabel(canvas,label,"GameFontHighlight")
                text:SetPoint("LEFT",check,"RIGHT",5,0)
                check:SetChecked(memberValue(field,true) ~= false)
                check:SetScript("OnClick",function(self) memberSettings()[field]=self:GetChecked()==true;groupRefresh() end)
                local function refresh() check:SetChecked(memberValue(field,true) ~= false) end
                memberRefreshers[#memberRefreshers+1]=refresh
                page:HookScript("OnShow",refresh)
            end
            if (key~="party" and key~="boss") then groupToggle(panel,"Show names","showName",-75) end
            if (key~="party" and key~="boss") then groupToggle(panel,"Show power bar","showPower",-115) end
            groupToggle(panel,"PvP indicator","showPvP",-155)
            groupToggle(panel,"Group leader indicator","showLeader",-195)
            groupToggle(panel,"Raid target marker","showRaidMarker",-235)
            groupToggle(panel,"Role indicator","showRole",-275)
            groupToggle(panel,"Classification indicator","showClassification",-315)
            groupToggle(panel,"Level label","showLevel",-355)
            panel=sections["Bar Text"]
            CreateSection(panel,"BAR TEXT",-12)
            CreateDivider(panel,-45)
            if (key=="party" or key=="boss") then
                groupToggle(panel,"Show names","showName",-245)
                local function textMode(label,field,y)
                    partyDropdown(panel,label.." TEXT",field,{
                        {"","Hidden"},
                        {"{current}","Current"},
                        {"{current} / {max}","Current / Max"},
                        {"{percent}","Percent"},
                        {"{current} ({percent})","Current (Percent)"}
                    },20,y,220,"{current} / {max}")
                end
                textMode("Health","hpText",-75)
                textMode("Power","powerText",-155)
            else
                groupToggle(panel,"Show health percentage","showHealthPercent",-75)
                groupToggle(panel,"Show power percentage","showPowerPercent",-115)
            end
            panel=sections.Fonts
            CreateSection(panel,"FONTS",-12)
            CreateDivider(panel,-45)
            if (key~="party" and key~="boss") then groupSlider(panel,"NAME FONT SIZE","Size of the unit name (0 hides it)","fontSize",0,22,11,-65) end
            if (key=="party" or key=="boss") then
                groupSlider(panel,"NAME FONT SIZE","Name text (0 hides)","nameFontSize",0,22,11,-65)
                groupSlider(panel,"HP FONT SIZE","HP value text","hpFontSize",0,24,12,-155)
                groupSlider(panel,"POWER FONT SIZE","Power value text","powerFontSize",0,24,11,-245)
                groupSlider(panel,"LEVEL FONT SIZE","Size of the level label","levelFontSize",0,22,11,-335)
            end
            panel=sections["Buffs / Debuffs"]
            CreateSection(panel,"BUFFS / DEBUFFS",-12)
            CreateDivider(panel,-45)
            if (key=="party" or key=="boss") then
                local function auraSettings(kind,x)
                    local label=CreateLabel(panel,string.upper(kind),"GameFontNormal")
                    label:SetPoint("TOPLEFT",panel,"TOPLEFT",x,kind=="buffs" and -65 or -460)
                    local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
                    check:SetSize(25,25)
                    check:SetPoint("TOPLEFT",panel,"TOPLEFT",x,kind=="buffs" and -100 or -495)
                    local text=CreateLabel(panel,"Enable "..kind,"GameFontHighlight")
                    text:SetPoint("LEFT",check,"RIGHT",5,0)
                    local function aura()
                        local member=memberSettings()
                        local field="aura_"..kind
                        member[field]=member[field] or {}
                        return member[field]
                    end
                    local function refresh()
                        check:SetChecked(aura().enabled==true)
                    end
                    check:SetScript("OnClick",function(self)
                        aura().enabled=self:GetChecked()==true
                        groupRefresh()
                    end)
                    memberRefreshers[#memberRefreshers+1]=refresh
                    page:HookScript("OnShow",refresh)
                    local function auraSlider(title,field,default,min,max,y)
                        local syncing=false
                        local slider=CreateSlider(panel,title,title,min,max,1,tonumber(aura()[field]) or default,y,function(value)
                            if syncing then return end
                            aura()[field]=value
                            groupRefresh()
                        end,false)
                        local function sync()
                            syncing=true
                            slider:SetValue(tonumber(aura()[field]) or default)
                            syncing=false
                        end
                        memberRefreshers[#memberRefreshers+1]=sync
                        page:HookScript("OnShow",sync)
                    end
                    auraSlider(string.upper(kind).." SIZE","size",24,12,48,kind=="buffs" and -155 or -550)
                    auraSlider(string.upper(kind).." COUNT","count",12,1,40,kind=="buffs" and -220 or -615)
                    auraSlider(string.upper(kind).." X","x",0,-250,250,kind=="buffs" and -285 or -680)
                    auraSlider(string.upper(kind).." Y","y",kind=="buffs" and 32 or -58,-250,250,kind=="buffs" and -350 or -745)
                end
                auraSettings("buffs",18)
                auraSettings("debuffs",18)
                panel:SetHeight(1160)
                root:SetHeight(1230)
            else
                local note=CreateLabel(panel,"Aura containers for this group type are not yet implemented.","GameFontHighlight")
                note:SetPoint("TOPLEFT",panel,"TOPLEFT",18,-72)
            end
            selectSection("Layout")
        else
            db.frames = db.frames or {}
            local own = db.frames[key] or {}
            db.frames[key] = own
            local refreshers = {}
            -- Compact subnavigation: each category has its own canvas.
            local rootPanel = panel
            local groups = {}
            for _, category in ipairs({"Layout", "Indicators", "Bar Text", "Fonts", "Buffs / Debuffs"}) do
                local canvas = CreateFrame("Frame", nil, rootPanel)
                canvas:SetPoint("TOPLEFT", rootPanel, "TOPLEFT", 0, -49)
                canvas:SetPoint("TOPRIGHT", rootPanel, "TOPRIGHT", 0, -49)
                canvas:SetHeight(category == "Indicators" and (name == "Pet" and 930 or 590) or (category == "Buffs / Debuffs" and 510 or 520))
                canvas:Hide()
                groups[category] = canvas
            end
            local activeGroup = "Layout"
            local groupButtons = {}
            local function selectGroup(category)
                activeGroup = category
                for label, canvas in pairs(groups) do canvas:SetShown(label == category) end
                for label, button in pairs(groupButtons) do
                    button.fill:SetColorTexture(label == category and 0.35 or 0.22,
                        label == category and 0.18 or 0.12,
                        label == category and 0.26 or 0.07, 1)
                end
                rootPanel:SetHeight(category == "Indicators" and (name == "Pet" and 950 or 610) or (category == "Buffs / Debuffs" and 550 or (category == "Layout" and 540 or 490)))
                viewport:SetVerticalScroll(0)
            end
            for i, category in ipairs({"Layout", "Indicators", "Bar Text", "Fonts", "Buffs / Debuffs"}) do
                local button = CreateFrame("Button", nil, rootPanel)
                button:SetSize(94, 30)
                button:SetPoint("TOPLEFT", rootPanel, "TOPLEFT", 12 + (i-1)*(96), -5)
                button.fill = button:CreateTexture(nil, "BACKGROUND")
                button.fill:SetAllPoints()
                local text = CreateLabel(button, category, "GameFontNormal")
                text:SetPoint("CENTER")
                text:SetTextColor(1, 0.81, 0.46)
                button:SetScript("OnClick", function() selectGroup(category) end)
                groupButtons[category] = button
            end
            panel = groups.Layout
            local settings = {
                {"barWidth","HP / MANA WIDTH","Width of health and resource bars",100,400},
                {"hpHeight","HP HEIGHT","Health bar height",12,45},
                {"powerHeight","MANA / POWER HEIGHT","Resource bar height",4,30},
                {"portraitSize","PORTRAIT SIZE","Portrait and ring size",36,90},
                {"portraitX","PORTRAIT X","Horizontal portrait offset",-80,80},
                {"portraitY","PORTRAIT Y","Vertical portrait offset",-80,80},
            }
            for i, setting in ipairs(settings) do
                local settingKey, title, hint, low, high = unpack(setting)
                local initial = own[settingKey]
                if initial == nil then initial = db[settingKey] or 0 end
                local slider = CreateSlider(panel, title, hint, low, high, 1, initial,
                    -12-(i-1)*53, function(value)
                        own[settingKey] = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, false)
                refreshers[#refreshers+1] = function()
                    local value = own[settingKey]
                    if value == nil then value = db[settingKey] or 0 end
                    slider:SetValue(value)
                end
            end
            local flip = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            flip:SetSize(25, 25)
            flip:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -330)
            local flipLabel = CreateLabel(panel, "Flip portrait horizontally", "GameFontHighlight")
            flipLabel:SetPoint("LEFT", flip, "RIGHT", 5, 0)
            flip:SetScript("OnClick", function(self)
                own.flipPortrait = self:GetChecked() == true
                if addon.UnitFrames then addon.UnitFrames:Refresh() end
            end)
            refreshers[#refreshers+1] = function() flip:SetChecked(own.flipPortrait == true) end
            syncControls[name] = function()
                for _, refresh in ipairs(refreshers) do refresh() end
            end
            -- Center-relative pixel coordinates, independent for each unit.
            local function coordField(axis, offset)
                local title = CreateLabel(panel, "FRAME " .. string.upper(axis), "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", offset, -385)
                title:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(82, 26)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", offset, -406)
                edit:SetAutoFocus(false)
                edit:SetNumeric(false)
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                local function commit(self)
                    local value = tonumber(self:GetText())
                    if value and addon.UnitFrames then
                        local x = own.x
                        local y = own.y
                        local defaults = {player={-260,-180}, target={260,-180}, focus={260,-250}, pet={-260,-250}}
                        x = x or defaults[key][1]
                        y = y or defaults[key][2]
                        if axis == "x" then x = value else y = value end
                        addon.UnitFrames:SetPosition(key, x, y)
                    end
                    self:ClearFocus()
                    self:SetText(tostring(own[axis] or 0))
                end
                -- Pixel nudges, placed immediately to the right of each coordinate field.
                local function nudgeButton(delta, yOffset, glyph)
                    local button = CreateFrame("Button", nil, panel)
                    button:SetSize(20, 13)
                    button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 5, -yOffset)
                    local background = button:CreateTexture(nil, "BACKGROUND")
                    background:SetAllPoints()
                    background:SetColorTexture(0.20, 0.10, 0.055, 0.98)
                    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    label:SetPoint("CENTER", button, "CENTER", 0, 0)
                    label:SetText(glyph)
                    label:SetTextColor(1, 0.78, 0.36)
                    button:SetScript("OnEnter", function()
                        background:SetColorTexture(0.35, 0.19, 0.10, 1)
                    end)
                    button:SetScript("OnLeave", function()
                        background:SetColorTexture(0.20, 0.10, 0.055, 0.98)
                    end)
                    button:SetScript("OnClick", function()
                        if not addon.UnitFrames then return end
                        local defaults = {player={-260,-180}, target={260,-180}, focus={260,-250}, pet={-260,-250}}
                        local x = own.x or defaults[key][1]
                        local y = own.y or defaults[key][2]
                        if axis == "x" then x = x + delta else y = y + delta end
                        if addon.UnitFrames:SetPosition(key, x, y) then
                            edit:SetText(tostring(own[axis]))
                            edit:ClearFocus()
                        end
                    end)
                end
                nudgeButton(1, 0, "+")
                nudgeButton(-1, 13, "-")
                edit:SetScript("OnEnterPressed", commit)
                edit:SetScript("OnEscapePressed", function(self)
                    self:ClearFocus()
                    self:SetText(tostring(own[axis] or 0))
                end)
                edit:SetScript("OnEditFocusLost", function(self)
                    self:SetText(tostring(own[axis] or 0))
                end)
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(tostring(own[axis] or 0)) end
                end
                return edit
            end
            local xField = coordField("x", 20)
            local yField = coordField("y", 140)
            local previousSync = syncControls[name]
            syncControls[name] = function()
                previousSync()
                xField:SetText(tostring(own.x or ({player=-260,target=260,focus=260,pet=-260})[key]))
                yField:SetText(tostring(own.y or ({player=-180,target=-180,focus=-250,pet=-250})[key]))
            end
            local choices = {}
            for _, candidate in ipairs({"Player","Target","Focus","Pet"}) do
                if candidate ~= name then choices[#choices+1] = candidate end
            end
            local function styleButton(button, title)
                local bg = button:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.23, 0.12, 0.065, 0.98)
                for _, edgeName in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
                    local edge = button:CreateTexture(nil, "BORDER")
                    edge:SetColorTexture(0.72, 0.52, 0.27, 0.95)
                    if edgeName == "TOP" then
                        edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
                    elseif edgeName == "BOTTOM" then
                        edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
                    elseif edgeName == "LEFT" then
                        edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
                    else
                        edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
                    end
                end
                local label = CreateLabel(button, title, "GameFontNormal")
                label:SetPoint("CENTER")
                label:SetTextColor(1, 0.79, 0.42)
                button:SetScript("OnEnter", function() bg:SetColorTexture(0.33, 0.18, 0.11, 0.98) end)
                button:SetScript("OnLeave", function() bg:SetColorTexture(0.23, 0.12, 0.065, 0.98) end)
                return label
            end
            local source = choices[1]
            local copyGroup = CreateFrame("Frame", nil, copyHeader)
            copyGroup:SetAllPoints(copyHeader)
            copyControls[name] = copyGroup
            local selector = CreateFrame("Button", nil, copyGroup)
            selector:SetSize(172, 28)
            selector:SetParent(copyGroup)
            selector:ClearAllPoints()
            selector:SetPoint("TOPLEFT", copyGroup, "TOPLEFT", 0, -3)
            local selectorText = styleButton(selector, "From: " .. source .. "  v")
            local dropdown = CreateFrame("Frame", nil, panel)
            dropdown:SetParent(copyGroup)
            dropdown:SetSize(172, #choices * 27)
            dropdown:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
            dropdown:SetFrameStrata("DIALOG")
            dropdown:SetFrameLevel(selector:GetFrameLevel() + 20)
            dropdown:Hide()
            for i, candidate in ipairs(choices) do
                local option = CreateFrame("Button", nil, dropdown)
                option:SetSize(172, 27)
                option:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, -(i-1)*27)
                styleButton(option, candidate)
                option:SetScript("OnClick", function()
                    source = candidate
                    selectorText:SetText("From: " .. source .. "  v")
                    dropdown:Hide()
                end)
            end
            selector:SetScript("OnClick", function() dropdown:SetShown(not dropdown:IsShown()) end)
            local copy = CreateFrame("Button", nil, panel)
            copy:SetParent(copyGroup)
            copy:ClearAllPoints()
            copy:SetSize(166, 28)
            copy:SetPoint("LEFT", selector, "RIGHT", 10, 0)
            styleButton(copy, "Copy settings")
            copy:SetScript("OnClick", function()
                dropdown:Hide()
                if addon.UnitFrames and addon.UnitFrames:CopyLayout(string.lower(source), key) then
                    syncControls[name]()
                end
            end)

            do
                panel = groups["Buffs / Debuffs"]
                -- Shared aura editor grid: three aligned columns, consistent row spacing.\n                -- Previews never modify real auras.
                local function auraPreviewControls(kind, top)
                    local title = CreateLabel(panel, string.upper(name .. " " .. kind), "GameFontNormal")
                    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
                    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
                    check:SetSize(24, 24)
                    check:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top - 24)
                    local label = CreateLabel(panel, "Preview " .. kind, "GameFontHighlight")
                    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
                    check:SetScript("OnClick", function(self)
                        if addon.UnitFrames then addon.UnitFrames:SetAuraPreview(key, kind, self:GetChecked() == true) end
                    end)
                    local opt = own["aura_" .. kind] or {}
                    if opt.enabled == nil then opt.enabled = name ~= "Player" end
                    own["aura_" .. kind] = opt
                    local enable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
                    enable:SetSize(24,24)
                    enable:SetPoint("TOPLEFT", panel, "TOPLEFT", 235, top - 24)
                    local enableLabel = CreateLabel(panel, "Enable " .. kind, "GameFontHighlight")
                    enableLabel:SetPoint("LEFT", enable, "RIGHT", 4, 0)
                    enable:SetChecked(opt.enabled)
                    enable:SetScript("OnClick", function(self)
                        opt.enabled = self:GetChecked() == true
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end)
                    local fields = {
                        {"size", "SIZE", 12, 48, 24}, {"count", "COUNT", 0, 40, 12},
                        {"perRow", "PER ROW", 1, 20, 6}, {"spacing", "GAP", 0, 20, 2},
                        {"x", "X", -250, 250, 0}, {"y", "Y", -250, 250, kind == "buffs" and 32 or -58},
                        {"durationFontSize", "NUMBER FONT", 0, 24, 12}, {"unitFontSize", "UNIT FONT", 0, 24, 7}, {"stackFontSize", "STACK FONT", 0, 24, 11},
                    }
                    for i, spec in ipairs(fields) do
                        local x = 20 + ((i-1) % 3) * 165
                        local y = top - 58 - math.floor((i-1)/3)*40
                        local caption = CreateLabel(panel, spec[2], "GameFontNormalSmall")
                        caption:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                        edit:SetSize(65, 22)
                        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y-17)
                        edit:SetAutoFocus(false)
                        edit:SetText(tostring(opt[spec[1]] == nil and spec[5] or opt[spec[1]]))
                        local function apply(value)
                            local n = tonumber(value)
                            if not n then n = opt[spec[1]] end
                            if n == nil then n = spec[5] end
                            opt[spec[1]] = math.max(spec[3], math.min(spec[4], math.floor(n)))
                            edit:SetText(tostring(opt[spec[1]]))
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end
                        for j, delta in ipairs({1, -1}) do
                            local button = CreateFrame("Button", nil, panel)
                            button:SetSize(18, 11)
                            button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 4, -(j-1)*11)
                            local background = button:CreateTexture(nil, "BACKGROUND")
                            background:SetAllPoints()
                            background:SetColorTexture(0.23, 0.12, 0.065, 1)
                            local glyph = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormalSmall")
                            glyph:SetPoint("CENTER")
                            button:SetScript("OnClick", function()
                                apply((opt[spec[1]] == nil and spec[5] or opt[spec[1]]) + delta)
                            end)
                        end
                        edit:SetScript("OnEnterPressed", function(self)
                            local value = tonumber(self:GetText()) or spec[5]
                            opt[spec[1]] = math.max(spec[3], math.min(spec[4], math.floor(value)))
                            self:SetText(tostring(opt[spec[1]]))
                            self:ClearFocus()
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end)
                    end
                    if key == "target" and kind == "debuffs" then
                        local mine = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
                        mine:SetSize(24, 24)
                        mine:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top - 219)
                        local mineLabel = CreateLabel(panel, "Show only my debuffs (requires /reload)", "GameFontHighlight")
                        mineLabel:SetPoint("LEFT", mine, "RIGHT", 4, 0)
                        mine:SetChecked(opt.onlyMine == true)
                        mine:SetScript("OnClick", function(self)
                            opt.onlyMine = self:GetChecked() == true
                        end)
                    end
                    local function direction(field, x)
                        local button = CreateFrame("Button", nil, panel)
                        button:SetSize(190, 24)
                        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top-190)
                        local bg = button:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(0.23, 0.12, 0.065, 1)
                        local text = CreateLabel(button, "", "GameFontNormalSmall")
                        text:SetPoint("CENTER")
                        local function refresh()
                            text:SetText(field .. ": " .. (opt[field] or (field == "horizontal" and "right" or "down")))
                        end
                        button:SetScript("OnClick", function()
                            local current = opt[field] or (field == "horizontal" and "right" or "down")
                            opt[field] = field == "horizontal" and (current == "right" and "left" or "right")
                                or (current == "down" and "up" or "down")
                            refresh()
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end)
                        refresh()
                    end
                    direction("horizontal", 20)
                    direction("vertical", 255)
                    viewport:HookScript("OnHide", function()
                        check:SetChecked(false)
                        if addon.UnitFrames then addon.UnitFrames:SetAuraPreview(key, kind, false) end
                    end)
                end
                auraPreviewControls("buffs", -20)
                auraPreviewControls("debuffs", -245)
            end
            panel = groups.Indicators
            -- Independent per-unit indicators, text templates and fonts.
            local function optionCheck(field, caption, x, y)
                local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
                check:SetSize(24, 24)
                check:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                local label = CreateLabel(panel, caption, "GameFontHighlight")
                label:SetPoint("LEFT", check, "RIGHT", 4, 0)
                check:SetScript("OnClick", function(self)
                    own[field] = self:GetChecked() == true
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                refreshers[#refreshers+1] = function() check:SetChecked(own[field] ~= false) end
            end
            local preview = CreateFrame("Button", nil, panel)
            preview:SetSize(170, 27)
            preview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -11)
            local previewText = styleButton(preview, "Preview indicators")
            local previewOn = false
            local function stopPreview()
                if not previewOn then return end
                previewOn = false
                previewText:SetText("Preview indicators")
                if addon.UnitFrames then addon.UnitFrames:SetIndicatorPreview(false) end
            end
            preview:SetScript("OnClick", function()
                previewOn = not previewOn
                previewText:SetText(previewOn and "Stop preview" or "Preview indicators")
                if addon.UnitFrames then addon.UnitFrames:SetIndicatorPreview(previewOn) end
            end)
            viewport:HookScript("OnHide", stopPreview)
            local indicators = CreateLabel(panel, "INDICATORS", "GameFontNormalLarge")
            indicators:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -16)
            indicators:SetTextColor(1, 0.79, 0.42)
            optionCheck("showPvP", "PvP flag", 20, -58)
            optionCheck("showLeader", "Group leader", 230, -58)
            optionCheck("showRaidMarker", "Raid marker", 20, -98)
            optionCheck("showRole", "Group / raid role", 230, -98)
            optionCheck("showClassification", "Elite / rare", 20, -138)

            optionCheck("showName", "Show name", 230, -138)
            if name == "Pet" then
                optionCheck("showHappiness", "Pet happiness", 20, -174)
                optionCheck("showPetXP", "Pet XP bar", 230, -174)
                optionCheck("showPetCast", "Pet castbar", 20, -204)
            end
            local iconSpecs = {
                {"pvp", "PvP flag"}, {"leader", "Group leader"},
                {"raid", "Raid marker"}, {"role", "Group / raid role"},
                {"classification", "Elite / rare"}
            }
            if name == "Pet" then iconSpecs[#iconSpecs + 1] = {"happiness", "Pet happiness"} end
            local function indicatorField(kind, field, x, y, caption)
                own[field] = own[field] or {}
                local label = CreateLabel(panel, caption, "GameFontNormalSmall")
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                label:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(43, 22)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 19)
                edit:SetAutoFocus(false)
                local function current()
                    return own[field][kind] or (field == "indicatorSize" and (kind == "classification" and 64 or 17) or 0)
                end
                local function apply(value)
                    local n = math.floor(tonumber(value) or current())
                    if field == "indicatorSize" then n = math.max(10, math.min(kind == "classification" and 120 or 48, n))
                    else n = math.max(-250, math.min(250, n)) end
                    own[field][kind] = n
                    edit:SetText(tostring(n))
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                edit:SetScript("OnEnterPressed", function(self) apply(self:GetText()); self:ClearFocus() end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(tostring(current())) end)
                edit:SetScript("OnEditFocusLost", function(self) self:SetText(tostring(current())) end)
                edit:SetText(tostring(current()))
                for i, delta in ipairs({1, -1}) do
                    local button = CreateFrame("Button", nil, panel)
                    button:SetSize(18, 12)
                    button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 3, -(i-1)*12)
                    local bg = button:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.23, 0.12, 0.065, 1)
                    local t = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormalSmall")
                    t:SetPoint("CENTER")
                    button:SetScript("OnClick", function() apply(current() + delta) end)
                end
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(tostring(current())) end
                end
            end
            for i, spec in ipairs(iconSpecs) do
                local rowY = (name == "Pet" and -240 or -200) - (i-1)*65
                local title = CreateLabel(panel, spec[2], "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, rowY)
                title:SetTextColor(1, 0.79, 0.42)
                indicatorField(spec[1], "indicatorSize", 215, rowY, "SIZE")
                indicatorField(spec[1], "indicatorX", 310, rowY, "X")
                indicatorField(spec[1], "indicatorY", 405, rowY, "Y")
            end
            if name == "Pet" then
                local function petBarControl(prefix, title, top)
                    local heading = CreateLabel(panel, title, "GameFontNormal")
                    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, top)
                    heading:SetTextColor(1, 0.79, 0.42)
                    for i, spec in ipairs({
                        {"Width", "WIDTH", 40, 400, 160},
                        {"Height", "HEIGHT", 4, 40, prefix == "petXP" and 9 or 13},
                        {"X", "X", -250, 250, 0},
                        {"Y", "Y", -250, 250, 0},
                        {"FontSize", "FONT", 0, 28, 10},
                    }) do
                        local field = prefix .. spec[1]
                        local x = 20 + (i-1) * 96
                        local caption = CreateLabel(panel, spec[2], "GameFontNormalSmall")
                        caption:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top - 23)
                        caption:SetTextColor(1, 0.79, 0.42)
                        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                        edit:SetSize(47, 22)
                        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top - 42)
                        edit:SetAutoFocus(false)
                        local function current() return tonumber(own[field]) or spec[5] end
                        local function apply(value)
                            own[field] = math.max(spec[3], math.min(spec[4], math.floor(tonumber(value) or current())))
                            edit:SetText(tostring(own[field]))
                            if addon.UnitFrames then addon.UnitFrames:Refresh() end
                        end
                        edit:SetScript("OnEnterPressed", function(self) apply(self:GetText()); self:ClearFocus() end)
                        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(tostring(current())) end)
                        edit:SetScript("OnEditFocusLost", function(self) self:SetText(tostring(current())) end)
                        for j, delta in ipairs({1, -1}) do
                            local btn = CreateFrame("Button", nil, panel)
                            btn:SetSize(18, 12)
                            btn:SetPoint("TOPLEFT", edit, "TOPRIGHT", 3, -(j-1)*12)
                            local bg = btn:CreateTexture(nil, "BACKGROUND")
                            bg:SetAllPoints()
                            bg:SetColorTexture(0.23, 0.12, 0.065, 1)
                            local glyph = CreateLabel(btn, delta == 1 and "+" or "-", "GameFontNormalSmall")
                            glyph:SetPoint("CENTER")
                            btn:SetScript("OnClick", function() apply(current() + delta) end)
                        end
                        refreshers[#refreshers+1] = function()
                            if not edit:HasFocus() then edit:SetText(tostring(current())) end
                        end
                    end
                end
                petBarControl("petCast", "PET CASTBAR", -640)
                -- Toggle a stationary castbar for layout work even when the pet cannot cast.
                local castPreview = CreateFrame("Button", nil, panel)
                castPreview:SetSize(125, 24)
                castPreview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -681)
                local castPreviewText = styleButton(castPreview, "Preview castbar")
                local castPreviewOn = false
                local function stopCastPreview()
                    if not castPreviewOn then return end
                    castPreviewOn = false
                    castPreviewText:SetText("Preview castbar")
                    if addon.UnitFrames then addon.UnitFrames:SetPetCastPreview(false) end
                end
                castPreview:SetScript("OnClick", function()
                    castPreviewOn = not castPreviewOn
                    castPreviewText:SetText(castPreviewOn and "Stop preview" or "Preview castbar")
                    if addon.UnitFrames then addon.UnitFrames:SetPetCastPreview(castPreviewOn) end
                end)
                viewport:HookScript("OnHide", stopCastPreview)

                -- Pet XP ring rotation: independent of segment width, sweep and
                -- portrait size. Numeric entry and +/- adjust by one degree.
                local rotationSlider = CreateSlider(panel, "PET XP RING ROTATION",
                    "Rotate the XP segments around the portrait (degrees)",
                    -180, 180, 1, tonumber(own.petXPRotation) or 0, -735,
                    function(value)
                        own.petXPRotation = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, true)
                -- Reserve room after the numeric value for the step buttons.
                local rotationRow = rotationSlider:GetParent()
                rotationSlider:ClearAllPoints()
                rotationSlider:SetPoint("RIGHT", rotationRow, "RIGHT", -111, 0)
                rotationSlider.valueBox:ClearAllPoints()
                rotationSlider.valueBox:SetPoint("RIGHT", rotationRow, "RIGHT", -71, 0)
                for i, delta in ipairs({1, -1}) do
                    local btn = CreateFrame("Button", nil, rotationRow)
                    btn:SetSize(21, 24)
                    btn:SetPoint("LEFT", rotationSlider.valueBox, "RIGHT", 5 + (i-1)*22, 0)
                    local bg = btn:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.23, 0.12, 0.065, 1)
                    local glyph = CreateLabel(btn, delta == 1 and "+" or "-", "GameFontNormal")
                    glyph:SetPoint("CENTER")
                    btn:SetScript("OnClick", function()
                        local nextValue = math.max(-180, math.min(180,
                            (tonumber(own.petXPRotation) or 0) + delta))
                        rotationSlider:SetValue(nextValue)
                    end)
                end
                refreshers[#refreshers+1] = function()
                    local value = tonumber(own.petXPRotation) or 0
                    if math.abs(rotationSlider:GetValue() - value) > 0.01 then
                        rotationSlider:SetValue(value)
                    end
                end
                local radiusSlider = CreateSlider(panel, "PET XP RING RADIUS",
                    "Move XP segments inward (-) or outward (+), in pixels",
                    -10, 10, 0.5, tonumber(own.petXPRadiusOffset) or 0, -785,
                    function(value)
                        own.petXPRadiusOffset = value
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, true)
                local radiusRow = radiusSlider:GetParent()
                radiusSlider:ClearAllPoints()
                radiusSlider:SetPoint("RIGHT", radiusRow, "RIGHT", -111, 0)
                radiusSlider.valueBox:ClearAllPoints()
                radiusSlider.valueBox:SetPoint("RIGHT", radiusRow, "RIGHT", -71, 0)
                for i, delta in ipairs({1, -1}) do
                    local btn = CreateFrame("Button", nil, radiusRow)
                    btn:SetSize(21, 24)
                    btn:SetPoint("LEFT", radiusSlider.valueBox, "RIGHT", 5 + (i-1)*22, 0)
                    local bg = btn:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.23, 0.12, 0.065, 1)
                    local glyph = CreateLabel(btn, delta == 1 and "+" or "-", "GameFontNormal")
                    glyph:SetPoint("CENTER")
                    btn:SetScript("OnClick", function()
                        local nextValue = math.max(-10, math.min(10,
                            (tonumber(own.petXPRadiusOffset) or 0) + delta * 0.5))
                        radiusSlider:SetValue(nextValue)
                    end)
                end
                refreshers[#refreshers+1] = function()
                    local value = tonumber(own.petXPRadiusOffset) or 0
                    if math.abs(radiusSlider:GetValue() - value) > 0.01 then
                        radiusSlider:SetValue(value)
                    end
                end
            end
            panel = groups["Bar Text"]
            local barTitle = CreateLabel(panel, "BAR TEXT", "GameFontNormalLarge")
            barTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -15)
            barTitle:SetTextColor(1, 0.79, 0.42)
            local function textField(field, caption, y)
                local label = CreateLabel(panel, caption, "GameFontNormal")
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
                label:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(280, 26)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, y + 4)
                edit:SetAutoFocus(false)
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                edit:SetScript("OnEnterPressed", function(self)
                    own[field] = self:GetText()
                    self:ClearFocus()
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(own[field] or "") end)
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(own[field] or "") end
                end
            end
            textField("hpText", "HP text", -55)
            textField("powerText", "Mana / Power text", -97)
            local hint = CreateLabel(panel, "Variables: {current}  {max}  {percent}   |   Blank = hidden", "GameFontHighlightSmall")
            hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -138)
            hint:SetTextColor(0.90, 0.75, 0.55)
            -- Separate text offsets for HP and Power, with one-pixel nudges.
            local function offsetEditor(field, caption, x, y)
                local title = CreateLabel(panel, caption, "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                title:SetTextColor(1, 0.79, 0.42)
                local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
                edit:SetSize(76, 24)
                edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 22)
                edit:SetAutoFocus(false)
                edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                local function apply(value)
                    own[field] = math.max(-300, math.min(300, math.floor(value)))
                    edit:SetText(tostring(own[field]))
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end
                edit:SetScript("OnEnterPressed", function(self)
                    local value = tonumber(self:GetText())
                    if value then apply(value) end
                    self:ClearFocus()
                end)
                edit:SetScript("OnEscapePressed", function(self)
                    self:ClearFocus()
                    self:SetText(tostring(own[field] or 0))
                end)
                for i, delta in ipairs({1, -1}) do
                    local button = CreateFrame("Button", nil, panel)
                    button:SetSize(22, 13)
                    button:SetPoint("TOPLEFT", edit, "TOPRIGHT", 4, -(i-1)*13)
                    local bg = button:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.23, 0.12, 0.065, 1)
                    local label = CreateLabel(button, delta == 1 and "+" or "-", "GameFontNormalSmall")
                    label:SetPoint("CENTER")
                    label:SetTextColor(1, 0.79, 0.42)
                    button:SetScript("OnClick", function() apply((own[field] or 0) + delta) end)
                end
                refreshers[#refreshers+1] = function()
                    if not edit:HasFocus() then edit:SetText(tostring(own[field] or 0)) end
                end
            end
            offsetEditor("hpTextX", "HP TEXT X", 20, -180)
            offsetEditor("hpTextY", "HP TEXT Y", 180, -180)
            offsetEditor("powerTextX", "POWER TEXT X", 20, -250)
            offsetEditor("powerTextY", "POWER TEXT Y", 180, -250)
            -- Styled dropdown shared by font, colors and bar text anchors.
            local function unitDropdown(field, caption, choices, x, y, width)
                local label = CreateLabel(panel, caption, "GameFontNormal")
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                label:SetTextColor(1, 0.79, 0.42)
                local button = CreateFrame("Button", nil, panel)
                button:SetSize(width or 145, 27)
                button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 22)
                local bg = button:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.12, 0.07, 0.045, 1)
                local border = button:CreateTexture(nil, "BORDER")
                border:SetPoint("TOPLEFT"); border:SetPoint("TOPRIGHT"); border:SetHeight(1)
                border:SetColorTexture(0.75, 0.55, 0.29)
                local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
                arrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
                local text = CreateLabel(button, "", "GameFontNormal")
                text:SetPoint("CENTER")
                text:SetTextColor(1, 0.79, 0.42)
                local menu = CreateFrame("Frame", nil, panel)
                menu:SetSize(width or 145, #choices * 24 + 4)
                local menuBg = menu:CreateTexture(nil, "BACKGROUND")
                menuBg:SetAllPoints()
                menuBg:SetColorTexture(0.12, 0.07, 0.045, 1)
                menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
                menu:SetFrameStrata("FULLSCREEN_DIALOG")
                menu:SetFrameLevel(button:GetFrameLevel() + 25)
                menu:Hide()
                local function refresh()
                    local current = own[field] or choices[1][1]
                    for _, choice in ipairs(choices) do
                        if choice[1] == current then text:SetText(choice[2]); return end
                    end
                    text:SetText(choices[1][2])
                end
                for i, choice in ipairs(choices) do
                    local item = CreateFrame("Button", nil, menu)
                    item:SetSize((width or 145) - 4, 24)
                    item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2-(i-1)*24)
                    local fill = item:CreateTexture(nil, "BACKGROUND")
                    fill:SetAllPoints()
                    fill:SetColorTexture(0.12, 0.07, 0.045, 1)
                    local captionText = CreateLabel(item, choice[2], "GameFontNormal")
                    captionText:SetPoint("CENTER")
                    captionText:SetTextColor(1, 0.79, 0.42)
                    item:SetScript("OnEnter", function() fill:SetColorTexture(0.34, 0.18, 0.11, 1) end)
                    item:SetScript("OnLeave", function() fill:SetColorTexture(0.12, 0.07, 0.045, 1) end)
                    item:SetScript("OnClick", function()
                        own[field] = choice[1]
                        menu:Hide()
                        refresh()
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end)
                end
                button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
                refreshers[#refreshers+1] = function() menu:Hide(); refresh() end
            end
            unitDropdown("hpTextAnchor", "HP TEXT ANCHOR", {{"RIGHT","Right"},{"CENTER","Center"},{"LEFT","Left"}}, 355, -180, 130)
            unitDropdown("powerTextAnchor", "POWER TEXT ANCHOR", {{"RIGHT","Right"},{"CENTER","Center"},{"LEFT","Left"}}, 355, -250, 130)
            unitDropdown("hpFontColor", "HP FONT COLOR", {{"gold","Gold"},{"white","White"},{"class","Class Color"}}, 20, -335, 150)
            unitDropdown("powerFontColor", "POWER FONT COLOR", {{"gold","Gold"},{"white","White"},{"class","Class Color"}}, 200, -335, 150)
            panel = groups.Fonts
            local fontTitle = CreateLabel(panel, "FONT", "GameFontNormalLarge")
            fontTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -15)
            fontTitle:SetTextColor(1, 0.79, 0.42)
            unitDropdown("fontFace", "FONT FAMILY", {{"general","General (Default)"},{"friz","Friz Quadrata"},{"arial","Arial Narrow"}}, 20, -42, 190)
            local fontSlider = CreateSlider(panel, "FONT SIZE", "Name, HP and Power text", 8, 28, 1,
                own.fontSize or 12, -116, function(v)
                    own.fontSize = v
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end, false)
            refreshers[#refreshers+1] = function() fontSlider:SetValue(own.fontSize or 12) end
            for i, spec in ipairs({
                {"nameFontSize", "NAME SIZE"},
                {"hpFontSize", "HP TEXT SIZE"},
                {"powerFontSize", "POWER TEXT SIZE"},
            }) do
                local field = spec[1]
                local slider = CreateSlider(panel, spec[2], "Independent text size", 8, 28, 1,
                    own[field] or own.fontSize or 12, -176 - (i-1)*57, function(v)
                        own[field] = v
                        if addon.UnitFrames then addon.UnitFrames:Refresh() end
                    end, false)
                refreshers[#refreshers+1] = function()
                    slider:SetValue(own[field] or own.fontSize or 12)
                end
            end

            local levelSlider = CreateSlider(panel, "LEVEL TEXT SIZE", "Level number only; badge ring stays fixed", 8, 28, 1,
                own.levelFontSize or 12, -355, function(v)
                    own.levelFontSize = v
                    if addon.UnitFrames then addon.UnitFrames:Refresh() end
                end, false)
            refreshers[#refreshers+1] = function() levelSlider:SetValue(own.levelFontSize or 12) end
            offsetEditor("levelTextX", "LEVEL TEXT X", 20, -435)
            offsetEditor("levelTextY", "LEVEL TEXT Y", 180, -435)

            panel = groups.Layout
            local note = CreateLabel(copyGroup, "Copies appearance only; position is preserved.", "GameFontHighlightSmall")
            note:SetTextColor(0.91, 0.78, 0.61, 1)
            note:SetPoint("TOPLEFT", copyGroup, "TOPLEFT", 0, -35)
            panel = rootPanel
            selectGroup("Layout")
        end
    end
    page:HookScript("OnShow", function()
        enabled:SetChecked(db.enabled ~= false)
        RefreshTabs()
    end)
    RefreshTabs()
    return page
end

local function CreateQoLPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages["Quality of Life"] = page
    local panel = CreatePanel(page, -12, 340)
    CreateSection(panel, "QUALITY OF LIFE", -14)
    CreateDivider(panel, -48)
    local toggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    toggle:SetSize(25,25)
    toggle:SetPoint("TOPLEFT",panel,"TOPLEFT",18,-72)
    toggle:SetChecked(addon.db.profile.qol.characterItemLevel)
    local label = CreateLabel(panel,"Character Item Level","GameFontHighlight")
    label:SetPoint("LEFT",toggle,"RIGHT",6,0)
    local description = CreateLabel(panel,
        "Show equipped item levels and average ilvl in the character window.",
        "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT",panel,"TOPLEFT",22,-115)
    description:SetTextColor(0.84,0.73,0.59)
    toggle:SetScript("OnClick",function(self)
        addon.db.profile.qol.characterItemLevel = not not self:GetChecked()
        if addon.ItemLevel then addon.ItemLevel:RefreshCharacter() end
    end)
    local soundsPanel = CreatePanel(page, -12, 340)
    soundsPanel:Hide()
    soundsPanel:ClearAllPoints()
    soundsPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
    soundsPanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -12)
    soundsPanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    CreateSection(soundsPanel, "SOUNDS", -14)
    CreateDivider(soundsPanel, -48)
    local function SoundCheck(title, descriptionText, key, y)
        local check = CreateFrame("CheckButton", nil, soundsPanel, "UICheckButtonTemplate")
        check:SetSize(25, 25)
        check:SetPoint("TOPLEFT", soundsPanel, "TOPLEFT", 18, y)
        check:SetChecked(addon.db.profile.qol[key])
        local caption = CreateLabel(soundsPanel, title, "GameFontHighlight")
        caption:SetPoint("LEFT", check, "RIGHT", 6, 0)
        local hint = CreateLabel(soundsPanel, descriptionText, "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, -5)
        hint:SetTextColor(0.84, 0.73, 0.59)
        check:SetScript("OnClick", function(self)
            addon.db.profile.qol[key] = not not self:GetChecked()
            if addon.QoLSounds then addon.QoLSounds:Apply() end
        end)
    end
    SoundCheck("Mute Character Error Speech",
        "Silence character voice errors, such as not enough mana.",
        "muteErrorSpeech", -72)
    SoundCheck("Mute Failed Spell Sounds",
        "Silence the sound played when a spell or ability fails.",
        "muteFailedSpellSounds", -152)
    -- Same right-side tabs used by Minimap and Tooltip.
    local resize = addon.WindowResize
    local resizePanel = CreatePanel(page, -12, 420)
    resizePanel:Hide()
    resizePanel:ClearAllPoints()
    resizePanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
    resizePanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -12)
    resizePanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    CreateSection(resizePanel, "RESIZE OPTIONS", -14)
    local help = CreateLabel(resizePanel, "Enable scaling, set a size, and choose whether corners can be dragged.", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", resizePanel, "TOPLEFT", 22, -47)
    help:SetTextColor(0.89, 0.73, 0.52)
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", resizePanel, "TOPRIGHT", 25, 0)
    tabBar:SetSize(108, 87)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    local tabs = {}
    local active = "General"
    local function selectTab(name)
        active = name
        panel:SetShown(name == "General")
        resizePanel:SetShown(name == "Resize Options")
        soundsPanel:SetShown(name == "Sounds")
        for key, button in pairs(tabs) do
            local selected = key == name
            button.fill:SetColorTexture(selected and 0.34 or 0.23, selected and 0.17 or 0.12,
                selected and 0.25 or 0.07, 0.98)
            button.label:SetTextColor(selected and 1 or 0.95, selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54, selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do edge:SetColorTexture(selected and 0.83 or 0.54, selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95) end
        end
    end
    for i, name in ipairs({"General", "Resize Options", "Sounds"}) do
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetSize(108, 29)
        tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -(i-1)*29)
        tab.fill = tab:CreateTexture(nil, "BACKGROUND")
        tab.fill:SetAllPoints()
        tab.text = CreateLabel(tab, name, "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = tab:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            tab.edges[#tab.edges+1] = edge
        end
        tab.accent = tab:CreateTexture(nil, "OVERLAY")
        tab.accent:SetPoint("TOPRIGHT"); tab.accent:SetPoint("BOTTOMRIGHT"); tab.accent:SetWidth(3)
        tab.label = tab.text
        tab.text:ClearAllPoints()
        tab.text:SetPoint("LEFT", tab, "LEFT", 12, 0)
        tab:SetScript("OnClick", function() selectTab(name) end)
        tab:SetScript("OnEnter", function() if active ~= name then tab.fill:SetColorTexture(0.28, 0.15, 0.085, 0.98) end end)
        tab:SetScript("OnLeave", function() selectTab(active) end)
        tabs[name] = tab
    end
    local viewport = CreateFrame("ScrollFrame", nil, resizePanel)
    viewport:SetPoint("TOPLEFT", resizePanel, "TOPLEFT", 12, -75)
    viewport:SetPoint("BOTTOMRIGHT", resizePanel, "BOTTOMRIGHT", -30, 12)
    viewport:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, viewport)
    content:SetWidth(700)
    content:SetHeight(#resize.windows * 57 + 10)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnSizeChanged", function(self)
        content:SetWidth(math.max(200, self:GetWidth()))
    end)
    local scrollbar = CreateFrame("Slider", nil, resizePanel)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetWidth(14)
    scrollbar:SetPoint("TOPRIGHT", resizePanel, "TOPRIGHT", -10, -75)
    scrollbar:SetPoint("BOTTOMRIGHT", resizePanel, "BOTTOMRIGHT", -10, 12)
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.12, 0.07, 0.04, 0.9)
    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(14, 38)
    thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
    scrollbar:SetThumbTexture(thumb)
    local sync = false
    local function refreshScroll()
        local limit = math.max(0, content:GetHeight() - viewport:GetHeight())
        scrollbar:SetMinMaxValues(0, math.max(1, limit))
        scrollbar:SetShown(limit > 1)
        if not sync then
            sync = true
            scrollbar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
            sync = false
        end
    end
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if sync then return end
        sync = true
        viewport:SetVerticalScroll(value)
        sync = false
    end)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        local limit = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 45)))
        refreshScroll()
    end)
    viewport:HookScript("OnVerticalScroll", refreshScroll)
    viewport:HookScript("OnSizeChanged", refreshScroll)
    resizePanel:HookScript("OnShow", function() resize:Refresh(); refreshScroll() end)
    for i, window in ipairs(resize.windows) do
        local key = window.key
        local cfg = resize:GetSetting(key)
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6 - (i-1)*57)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -6 - (i-1)*57)
        row:SetHeight(51)
        local fill = row:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.25, 0.125, 0.055, 0.65)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24,24)
        check:SetPoint("LEFT", row, "LEFT", 8, 0)
        check:SetChecked(cfg.enabled)
        local label = CreateLabel(row, window.label, "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 5, 0)
        label:SetTextColor(1, 0.8, 0.47)
        -- Editable window position (UIParent bottom-left coordinates).
        local coordinateBoxes = {}
        local function selectAllOnDoubleClick(edit)
            local lastClick = 0
            edit:HookScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" then return end
                local now = GetTime()
                if now - lastClick < 0.35 then
                    self:SetFocus()
                    self:HighlightText()
                end
                lastClick = now
            end)
        end
        for index, axis in ipairs({"X", "Y"}) do
            local offset = index == 1 and -257 or -158
            local coordLabel = CreateLabel(row, axis .. ":", "GameFontNormalSmall")
            coordLabel:SetPoint("RIGHT", row, "RIGHT", offset, 0)
            coordLabel:SetTextColor(0.96, 0.78, 0.53)
            local edit = CreateFrame("EditBox", nil, row)
            edit:SetSize(63, 24)
            edit:SetPoint("LEFT", coordLabel, "RIGHT", 5, 0)
            edit:SetAutoFocus(false)
            edit:SetNumeric(false)
            edit:SetMaxLetters(6)
            edit:SetFontObject("GameFontNormal")
            edit:SetTextColor(1, 0.81, 0.45)
            edit:SetJustifyH("CENTER")
            local background = edit:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints()
            background:SetColorTexture(0.11, 0.065, 0.04, 0.95)
            selectAllOnDoubleClick(edit)
            coordinateBoxes[axis] = edit
        end
        local function refreshCoordinates()
            local x, y = resize:GetPosition(key)
            if not coordinateBoxes.X:HasFocus() then
                coordinateBoxes.X:SetText(x and tostring(x) or "")
            end
            if not coordinateBoxes.Y:HasFocus() then
                coordinateBoxes.Y:SetText(y and tostring(y) or "")
            end
        end
        local function saveCoordinates()
            local x = tonumber(coordinateBoxes.X:GetText())
            local y = tonumber(coordinateBoxes.Y:GetText())
            if x and y then resize:SetPosition(key, x, y) end
            coordinateBoxes.X:ClearFocus()
            coordinateBoxes.Y:ClearFocus()
            refreshCoordinates()
        end
        for _, edit in pairs(coordinateBoxes) do
            edit:SetScript("OnEnterPressed", saveCoordinates)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshCoordinates() end)
        end
        local drag = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        drag:SetSize(23,23)
        drag:SetPoint("RIGHT", row, "RIGHT", -342, 0)
        drag:SetChecked(cfg.draggable ~= false)
        drag:SetEnabled(cfg.enabled)
        local dragLabel = CreateLabel(row, "Drag", "GameFontNormalSmall")
        dragLabel:SetPoint("RIGHT", drag, "LEFT", -4, 0)
        dragLabel:SetTextColor(0.96, 0.78, 0.53)
        local reset = CreateFrame("Button", nil, row)
        reset:SetSize(51, 24)
        reset:SetPoint("RIGHT", row, "RIGHT", -267, 0)
        local resetBg = reset:CreateTexture(nil, "BACKGROUND")
        resetBg:SetAllPoints()
        resetBg:SetColorTexture(0.17, 0.085, 0.045, 0.95)
        local resetLabel = CreateLabel(reset, "Reset", "GameFontNormalSmall")
        resetLabel:SetPoint("CENTER")
        resetLabel:SetTextColor(1, 0.81, 0.45)
        reset:SetScript("OnClick", function()
            if resize:ResetPosition(key) then
                refreshCoordinates()
            end
        end)
        local valueBox = CreateFrame("EditBox", nil, row)
        valueBox:SetSize(48, 24)
        valueBox:SetPoint("RIGHT", row, "RIGHT", -27, 0)
        valueBox:SetAutoFocus(false)
        valueBox:SetNumeric(true)
        valueBox:SetMaxLetters(3)
        valueBox:SetFontObject("GameFontNormal")
        valueBox:SetTextColor(1, 0.81, 0.45)
        valueBox:SetJustifyH("CENTER")
        selectAllOnDoubleClick(valueBox)
        local bg = valueBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.11, 0.065, 0.04, 0.95)
        local percent = CreateLabel(row, "%", "GameFontNormal")
        percent:SetPoint("LEFT", valueBox, "RIGHT", 3, 0)
        percent:SetTextColor(0.95, 0.77, 0.47)
        local function updateText()
            local setting = resize:GetSetting(key)
            if setting and not valueBox:HasFocus() then
                valueBox:SetText(tostring(math.floor((setting.scale or 1)*100+0.5)))
            end
        end
        check:SetScript("OnClick", function(self)
            local setting = resize:GetSetting(key)
            setting.enabled = not not self:GetChecked()
            drag:SetEnabled(setting.enabled)
            reset:SetEnabled(setting.enabled)
            resize:Refresh()
            refreshCoordinates()
        end)
        drag:SetScript("OnClick", function(self)
            local setting = resize:GetSetting(key)
            setting.draggable = not not self:GetChecked()
            resize:Refresh()
        end)
        local function commit()
            local value = tonumber(valueBox:GetText())
            if value then resize:SetScale(key, value) end
            valueBox:ClearFocus()
            updateText()
        end
        valueBox:SetScript("OnEnterPressed", commit)
        valueBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); updateText() end)
        valueBox:SetScript("OnEditFocusLost", updateText)
        resizePanel:HookScript("OnShow", function()
            local setting = resize:GetSetting(key)
            check:SetChecked(setting.enabled)
            drag:SetChecked(setting.draggable ~= false)
            drag:SetEnabled(setting.enabled)
            reset:SetEnabled(setting.enabled)
            updateText()
            refreshCoordinates()
        end)
        reset:SetEnabled(cfg.enabled)
        updateText()
        refreshCoordinates()
    end
    selectTab("General")
    page:HookScript("OnShow", function() selectTab("General") end)
    return page
end

local function CreateMinimapPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Minimap = page
    local db = addon.db.profile.minimap
    local activeTab = "General"
    local tabButtons = {}
    local tabPanels = {}

    local headingPanel = CreatePanel(page, -8, 76)
    CreateSection(headingPanel, "MINIMAP", -12)
    local enabled = CreateFrame("CheckButton", nil, headingPanel, "UICheckButtonTemplate")
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    enabled:SetChecked(db.enabled)
    local enabledLabel = CreateLabel(headingPanel, "Enable Minimap", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        if addon.Minimap then addon.Minimap:Apply() end
    end)

    local main = CreatePanel(page, -100, 400)
    -- Reserve a separate strip outside the content panel for protruding tabs.
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    if main.SetClipsChildren then main:SetClipsChildren(true) end
    -- Text tabs use the same bronze borders and plum selection as categories.
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 145)

    local function RefreshTabs()
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            button.fill:SetColorTexture(selected and 0.34 or 0.23,
                selected and 0.17 or 0.12, selected and 0.25 or 0.07, 0.98)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, panel in pairs(tabPanels) do panel:SetShown(name == activeTab) end
        -- Fit each tab's background to its content, without escaping the window.
        local heights = {General = 430, ["Map Info"] = 352, Buttons = 265, Visibility = 335, Fonts = 545}
        local available = math.max(120, page:GetHeight() - 110)
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
        main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
        main:SetHeight(math.min(heights[activeTab] or 430, available))
        local viewport = tabPanels[activeTab]
        if viewport then viewport:SetVerticalScroll(0) end
    end

    page:SetScript("OnSizeChanged", function() RefreshTabs() end)

    for i, name in ipairs({"General", "Map Info", "Buttons", "Visibility", "Fonts"}) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(108, 29)
        b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -((i - 1) * 29))
        b.fill = b:CreateTexture(nil, "BACKGROUND")
        b.fill:SetAllPoints()
        b.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = b:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            b.edges[#b.edges + 1] = edge
        end
        -- Mirror the navigation accent: right edge for the right-side tabs.
        b.accent = b:CreateTexture(nil, "OVERLAY")
        b.accent:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
        b.accent:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.accent:SetWidth(3)
        b.label = CreateLabel(b, name, "GameFontNormal")
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        b:SetScript("OnEnter", function()
            if activeTab ~= name then b.fill:SetColorTexture(0.28, 0.15, 0.085, 0.98) end
        end)
        b:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = b
    end

    local function NewTab(name)
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
        if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetHeight(({General = 410, ["Map Info"] = 320, Buttons = 220, Visibility = 260, Fonts = 535})[name] or 400)
        panel:SetWidth(math.max(1, viewport:GetWidth()))
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self)
            panel:SetWidth(math.max(1, self:GetWidth()))
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(self:GetVerticalScroll(), limit))
        end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 36)))
        end)
        if name == "Fonts" then
            local bar = CreateFrame("Slider", nil, main)
            bar:SetOrientation("VERTICAL")
            bar:SetWidth(12)
            bar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -12)
            bar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
            bar:SetMinMaxValues(0, 1)
            bar:SetValueStep(1)
            local track = bar:CreateTexture(nil, "BACKGROUND")
            track:SetAllPoints()
            track:SetColorTexture(0.12, 0.07, 0.04, 0.9)
            local thumb = bar:CreateTexture(nil, "OVERLAY")
            thumb:SetSize(14, 38)
            thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
            bar:SetThumbTexture(thumb)
            viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
            local syncing = false
            local function RefreshScroll()
                local limit = math.max(0, panel:GetHeight() - viewport:GetHeight())
                bar:SetMinMaxValues(0, math.max(1, limit))
                bar:SetShown(limit > 1)
                if not syncing then
                    syncing = true
                    bar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
                    syncing = false
                end
            end
            bar:SetScript("OnValueChanged", function(_, value)
                if syncing then return end
                syncing = true
                viewport:SetVerticalScroll(value)
                syncing = false
            end)
            viewport:HookScript("OnVerticalScroll", RefreshScroll)
            viewport:HookScript("OnSizeChanged", RefreshScroll)
            viewport:HookScript("OnShow", RefreshScroll)
        end
        tabPanels[name] = viewport
        return panel
    end
    local general = NewTab("General")
    local mapInfo = NewTab("Map Info")
    local buttons = NewTab("Buttons")
    local visibility = NewTab("Visibility")
    local fonts = NewTab("Fonts")

    local function SimpleRow(parent, title, y)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(43)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.25, 0.125, 0.055, 0.9)
        local label = CreateLabel(row, title, "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 14, 0)
        label:SetTextColor(1, 0.78, 0.39)
        return row
    end
    local function Toggle(parent, title, y, key)
        local row = SimpleRow(parent, title, y)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        check:SetChecked(db[key])
        check:SetScript("OnClick", function(self)
            db[key] = not not self:GetChecked()
            if addon.Minimap then addon.Minimap:Apply() end
            if addon.MinimapInfo then addon.MinimapInfo:Apply() end
            if addon.MinimapButtons then addon.MinimapButtons:Apply() end
        end)
    end
    local function Select(parent, title, y, key, values)
        local row = SimpleRow(parent, title, y)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(156, 24)
        button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.12, 0.07, 0.045, 1)
        local text = CreateLabel(button, "", "GameFontNormal")
        text:SetPoint("CENTER")
        local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", -6, 0)
        local menu = CreateFrame("Frame", nil, button)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(button:GetFrameLevel() + 20)
        menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
        menu:SetSize(156, #values * 24 + 4)
        local background = menu:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.12, 0.07, 0.045, 1)
        local function display()
            for _, choice in ipairs(values) do
                if db[key] == choice[1] then text:SetText(choice[2]); return end
            end
            text:SetText("Select...")
        end
        for i, choice in ipairs(values) do
            local item = CreateFrame("Button", nil, menu)
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 24)
            item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * 24)
            item:SetHeight(24)
            local label = CreateLabel(item, choice[2], "GameFontHighlightSmall")
            label:SetPoint("LEFT", 8, 0)
            item:SetScript("OnClick", function()
                db[key] = choice[1]
                display()
                menu:Hide()
                if addon.Minimap then addon.Minimap:Apply() end
            end)
        end
        menu:Hide()
        button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
        display()
    end
    Select(general, "MAP SHAPE (RELOAD)", -4, "style",
        {{"round", "Round"}, {"square", "Square"}})
    Select(general, "AUTO ZOOM OUT", -49, "autoZoom",
        {{0, "Off"}, {5, "5 seconds"}, {10, "10 seconds"}, {30, "30 seconds"}})
    local indoorCheck = CreateFrame("CheckButton", nil, general, "UICheckButtonTemplate")
    indoorCheck:SetSize(25, 25)
    indoorCheck:SetPoint("TOPLEFT", general, "TOPLEFT", 16, -96)
    indoorCheck:SetChecked(db.ignoreIndoorZoom)
    local indoorLabel = CreateLabel(general, "Ignore Indoors", "GameFontHighlight")
    indoorLabel:SetPoint("LEFT", indoorCheck, "RIGHT", 7, 0)
    indoorLabel:SetTextColor(1, 0.78, 0.39)
    indoorCheck:SetScript("OnClick", function(self)
        db.ignoreIndoorZoom = not not self:GetChecked()
    end)
    CreateSlider(general, "MINIMAP ICON SCALE",
        "Scale player and tracking icons.",
        1.0, 2.5, 0.1, db.iconScale, -143, function(value)
            db.iconScale = value
            if addon.Minimap then addon.Minimap:Apply() end
        end)
    CreateSlider(general, "MINIMAP WINDOW SCALE",
        "Resize the entire minimap and its frame.",
        0.7, 1.5, 0.05, db.mapScale, -206, function(value)
            db.mapScale = value
            if addon.Minimap then addon.Minimap:Apply() end
        end)
    local note = CreateLabel(general,
        "Map shape and Enable Minimap require /reload to restore Blizzard's map safely.",
        "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", general, "TOPLEFT", 12, -282)
    note:SetWidth(340)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.66, 0.63, 0.59, 1)
    local function Planned(parent, title, description)
        local heading = CreateLabel(parent, title, "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 14, -12)
        local label = CreateLabel(parent, description, "GameFontHighlight")
        label:SetPoint("TOPLEFT", 14, -49)
        label:SetWidth(350)
        label:SetJustifyH("LEFT")
    end
    local modes = {{"off", "Never"}, {"hover", "On Mouseover"}, {"always", "Always"}}
    Select(mapInfo, "COORDINATES", -4, "coords", modes)
    Select(mapInfo, "FPS", -49, "fps", modes)
    Select(mapInfo, "LATENCY", -94, "latency", modes)
    Select(mapInfo, "CLOCK", -139, "clock", modes)
    local mapHint = CreateLabel(mapInfo,
        "Coordinates stay below the map. FPS and latency appear at its lower-right edge.",
        "GameFontHighlightSmall")
    mapHint:SetPoint("TOPLEFT", mapInfo, "TOPLEFT", 14, -200)
    mapHint:SetWidth(340)
    mapHint:SetJustifyH("LEFT")
    mapHint:SetTextColor(0.66, 0.63, 0.59, 1)
    Toggle(buttons, "MIDDLE CLICK MICRO MENU", -4, "microMenu")
    Toggle(buttons, "HIDE ADDON BUTTONS UNTIL HOVER", -49, "hideAddonButtons")
    Toggle(buttons, "SHOW BAZI UI MINIMAP BUTTON", -94, "showMinimapButton")
    local buttonsHint = CreateLabel(buttons,
        "Middle-click opens the micro menu outside combat.",
        "GameFontHighlightSmall")
    buttonsHint:SetPoint("TOPLEFT", buttons, "TOPLEFT", 14, -148)
    buttonsHint:SetWidth(345)
    buttonsHint:SetJustifyH("LEFT")
    buttonsHint:SetTextColor(0.66, 0.63, 0.59, 1)
    Toggle(visibility, "HIDE DAY / NIGHT", -4, "hideDayNight")
    Toggle(visibility, "HIDE TRACKING", -49, "hideTracking")
    Toggle(visibility, "HIDE ZONE LOCATION", -94, "hideZone")
    Toggle(visibility, "HIDE CLOCK", -139, "hideClock")
    Toggle(visibility, "HIDE CALENDAR", -184, "hideCalendar")
    local fontChoices = {{"GLOBAL", "Global"}, {"FRIZQT", "Friz Quadrata"},
        {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}}
    local outlineChoices = {{"NONE", "None"}, {"OUTLINE", "Outline"},
        {"THICKOUTLINE", "Thick"}}
    local function FontGroup(title, y, key)
        local cfg = db[key]
        -- Separate the three font settings visually without changing control positions.
        local groupBack = fonts:CreateTexture(nil, "BACKGROUND")
        groupBack:SetPoint("TOPLEFT", fonts, "TOPLEFT", 6, y + 12)
        groupBack:SetPoint("TOPRIGHT", fonts, "TOPRIGHT", -6, y + 12)
        groupBack:SetHeight(172)
        groupBack:SetColorTexture(0.18, 0.10, 0.065, 0.52)
        -- Thin bronze outline around each separate font category.
        local edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = fonts:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(0.68, 0.46, 0.24, 0.85)
            if side == "TOP" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetWidth(1)
            end
            edges[#edges + 1] = edge
        end
        local heading = CreateLabel(fonts, title, "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", fonts, "TOPLEFT", 14, y)
        heading:SetTextColor(1, 0.79, 0.42)
        -- A per-group proxy table lets Select use the same controls as General.
        -- The selection is copied into the real font configuration immediately.
        local function fontSelect(label, offset, field, choices)
            local row = CreateFrame("Frame", nil, fonts)
            row:SetPoint("TOPLEFT", fonts, "TOPLEFT", 0, offset)
            row:SetPoint("TOPRIGHT", fonts, "TOPRIGHT", 0, offset)
            row:SetHeight(28)
            local rowLabel = CreateLabel(row, label, "GameFontNormal")
            rowLabel:SetPoint("LEFT", row, "LEFT", 14, 0)
            rowLabel:SetTextColor(1, 0.78, 0.39)
            local b = CreateFrame("Button", nil, row)
            b:SetSize(156, 24)
            b:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            local bg = b:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.12, 0.07, 0.045, 1)
            local txt = CreateLabel(b, "", "GameFontNormal")
            txt:SetPoint("CENTER")
            local menu = CreateFrame("Frame", nil, b)
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetFrameLevel(b:GetFrameLevel() + 20)
            menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
            menu:SetSize(156, #choices * 24 + 4)
            local fill = menu:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            fill:SetColorTexture(0.12, 0.07, 0.045, 1)
            local function refresh()
                for _, choice in ipairs(choices) do
                    if cfg[field] == choice[1] then txt:SetText(choice[2]); break end
                end
            end
            for i, choice in ipairs(choices) do
                local item = CreateFrame("Button", nil, menu)
                item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2-(i-1)*24)
                item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2-(i-1)*24)
                item:SetHeight(24)
                local label = CreateLabel(item, choice[2], "GameFontHighlightSmall")
                label:SetPoint("LEFT", 8, 0)
                item:SetScript("OnClick", function()
                    cfg[field] = choice[1]
                    refresh()
                    menu:Hide()
                    if addon.MinimapInfo then addon.MinimapInfo:ApplyFonts() end
                end)
            end
            menu:Hide()
            b:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
            refresh()
        end
        fontSelect("FONT", y-20, "font", fontChoices)
        fontSelect("OUTLINE", y-49, "outline", outlineChoices)
        CreateSlider(fonts, "SIZE", "Text size", 8, 30, 1, cfg.size, y-79, function(value)
            cfg.size = value
            if addon.MinimapInfo then addon.MinimapInfo:ApplyFonts() end
        end, true)
        local shadow = CreateFrame("CheckButton", nil, fonts, "UICheckButtonTemplate")
        shadow:SetPoint("TOPLEFT", fonts, "TOPLEFT", 14, y-130)
        shadow:SetChecked(cfg.shadow)
        local label = CreateLabel(fonts, "Shadow", "GameFontNormal")
        label:SetPoint("LEFT", shadow, "RIGHT", 6, 0)
        label:SetTextColor(1, 0.79, 0.42)
        shadow:SetScript("OnClick", function(self)
            cfg.shadow = not not self:GetChecked()
            if addon.MinimapInfo then addon.MinimapInfo:ApplyFonts() end
        end)
    end
    FontGroup("ZONE TEXT", -10, "zoneFont")
    FontGroup("CLOCK", -185, "clockFont")
    FontGroup("INFO TEXT", -360, "infoFont")
    fonts:SetHeight(535)
    RefreshTabs()
    return page
end

local function CreateTooltipPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages.Tooltip = page
    local db = addon.db.profile.tooltip
    local activeTab = "General"
    local tabButtons = {}
    local tabPanels = {}

    local headingPanel = CreatePanel(page, -8, 76)
    CreateSection(headingPanel, "TOOLTIP", -12)
    local enabled = CreateFrame("CheckButton", nil, headingPanel, "UICheckButtonTemplate")
    enabled:SetSize(25, 25)
    enabled:SetPoint("TOPLEFT", headingPanel, "TOPLEFT", 16, -41)
    enabled:SetChecked(db.enabled)
    local enabledLabel = CreateLabel(headingPanel, "Enable Tooltip", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 0)
    enabled:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        if addon.Tooltip then addon.Tooltip:Apply() end
    end)

    local main = CreatePanel(page, -100, 400)
    -- Reserve a separate strip outside the content panel for protruding tabs.
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -100)
    main:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -100)
    main:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    if main.SetClipsChildren then main:SetClipsChildren(true) end
    -- Text tabs use the same bronze borders and plum selection as categories.
    local tabBar = CreateFrame("Frame", nil, page)
    tabBar:SetPoint("TOPLEFT", main, "TOPRIGHT", 25, 0)
    tabBar:SetFrameStrata("FULLSCREEN_DIALOG")
    tabBar:SetSize(108, 87)

    local function RefreshTabs()
        for name, button in pairs(tabButtons) do
            local selected = name == activeTab
            button.fill:SetColorTexture(selected and 0.34 or 0.23,
                selected and 0.17 or 0.12, selected and 0.25 or 0.07, 0.98)
            button.label:SetTextColor(selected and 1 or 0.95,
                selected and 0.85 or 0.80, selected and 0.55 or 0.66)
            button.accent:SetColorTexture(selected and 0.83 or 0.54,
                selected and 0.63 or 0.37, selected and 0.30 or 0.20, selected and 1 or 0.8)
            for _, edge in ipairs(button.edges) do
                edge:SetColorTexture(selected and 0.83 or 0.54,
                    selected and 0.63 or 0.37, selected and 0.30 or 0.20, 0.95)
            end
        end
        for name, panel in pairs(tabPanels) do panel:SetShown(name == activeTab) end
    end

    for i, name in ipairs({"General", "Contents", "Fonts"}) do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetSize(108, 29)
        b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, -((i - 1) * 29))
        b.fill = b:CreateTexture(nil, "BACKGROUND")
        b.fill:SetAllPoints()
        b.edges = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = b:CreateTexture(nil, "OVERLAY")
            if side == "TOP" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
            end
            b.edges[#b.edges + 1] = edge
        end
        -- Mirror the navigation accent: right edge for the right-side tabs.
        b.accent = b:CreateTexture(nil, "OVERLAY")
        b.accent:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
        b.accent:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.accent:SetWidth(3)
        b.label = CreateLabel(b, name, "GameFontNormal")
        b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
        b:SetScript("OnClick", function() activeTab = name; RefreshTabs() end)
        b:SetScript("OnEnter", function()
            if activeTab ~= name then b.fill:SetColorTexture(0.28, 0.15, 0.085, 0.98) end
        end)
        b:SetScript("OnLeave", RefreshTabs)
        tabButtons[name] = b
    end

    local function NewTab(name)
        local viewport = CreateFrame("ScrollFrame", nil, main)
        viewport:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -12)
        viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
        if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
        viewport:EnableMouseWheel(true)
        local panel = CreateFrame("Frame", nil, viewport)
        panel:SetHeight(name == "Fonts" and 490 or (name == "Contents" and 420 or 390))
        panel:SetWidth(math.max(1, viewport:GetWidth()))
        viewport:SetScrollChild(panel)
        viewport:SetScript("OnSizeChanged", function(self)
            panel:SetWidth(math.max(1, self:GetWidth()))
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(self:GetVerticalScroll(), limit))
        end)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, panel:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 36)))
        end)
        if name == "Fonts" then
            local bar = CreateFrame("Slider", nil, main)
            bar:SetOrientation("VERTICAL")
            bar:SetWidth(12)
            bar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -12)
            bar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 12)
            bar:SetMinMaxValues(0, 1)
            bar:SetValueStep(1)
            local track = bar:CreateTexture(nil, "BACKGROUND")
            track:SetAllPoints()
            track:SetColorTexture(0.12, 0.07, 0.04, 0.9)
            local thumb = bar:CreateTexture(nil, "OVERLAY")
            thumb:SetSize(14, 38)
            thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
            bar:SetThumbTexture(thumb)
            viewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -19, 10)
            local syncing = false
            local function RefreshScroll()
                local limit = math.max(0, panel:GetHeight() - viewport:GetHeight())
                bar:SetMinMaxValues(0, math.max(1, limit))
                bar:SetShown(limit > 1)
                if not syncing then
                    syncing = true
                    bar:SetValue(math.min(limit, viewport:GetVerticalScroll()))
                    syncing = false
                end
            end
            bar:SetScript("OnValueChanged", function(_, value)
                if syncing then return end
                syncing = true
                viewport:SetVerticalScroll(value)
                syncing = false
            end)
            viewport:HookScript("OnVerticalScroll", RefreshScroll)
            viewport:HookScript("OnSizeChanged", RefreshScroll)
            viewport:HookScript("OnShow", RefreshScroll)
        end
        tabPanels[name] = viewport
        return panel
    end
    local general = NewTab("General")
    local contents = NewTab("Contents")
    local fonts = NewTab("Fonts")

    local function Row(parent, text, y, description)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(description and 55 or 42)
        local fill = row:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        -- Font categories already have a single framed background.
        -- Avoid opaque per-control rows that visually cut through the border.
        if parent == fonts then
            fill:SetColorTexture(0.25, 0.125, 0.055, 0)
        else
            fill:SetColorTexture(0.25, 0.125, 0.055, 0.90)
        end
        local label = CreateLabel(row, text, "GameFontNormal")
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 14, description and -10 or -12)
        label:SetTextColor(1, 0.78, 0.39)
        if description then
            local hint = CreateLabel(row, description, "GameFontHighlightSmall")
            hint:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -30)
            hint:SetTextColor(0.91, 0.78, 0.61)
        end
        return row, label
    end
    local function Update() if addon.Tooltip then addon.Tooltip:Apply() end end
    local function Choice(parent, text, y, getValue, setValue, choices)
        local row = Row(parent, text, y)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(154, 23)
        button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.12, 0.07, 0.045, 1)
        local border = button:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT"); border:SetPoint("TOPRIGHT"); border:SetHeight(1)
        border:SetColorTexture(0.75, 0.55, 0.29)
        local label = CreateLabel(button, "", "GameFontNormal")
        label:SetPoint("CENTER", button, "CENTER", -5, 0)
        local arrow = CreateLabel(button, "v", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        local menu = CreateFrame("Frame", nil, button)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(button:GetFrameLevel() + 20)
        menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
        menu:SetSize(154, #choices * 24 + 4)
        local bg = menu:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.07, 0.045, 1)
        local function Display()
            for _, choice in ipairs(choices) do
                if choice[1] == getValue() then label:SetText(choice[2]); return end
            end
            label:SetText("Select...")
        end
        for i, choice in ipairs(choices) do
            local option = CreateFrame("Button", nil, menu)
            option:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i-1)*24)
            option:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i-1)*24)
            option:SetHeight(24)
            local t = CreateLabel(option, choice[2], "GameFontHighlightSmall")
            t:SetPoint("LEFT", option, "LEFT", 8, 0)
            option:SetScript("OnEnter", function() t:SetTextColor(1, 0.78, 0.39) end)
            option:SetScript("OnLeave", function() t:SetTextColor(1, 1, 1) end)
            option:SetScript("OnClick", function()
                setValue(choice[1]); Display(); menu:Hide(); Update()
            end)
        end
        menu:Hide()
        button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
        Display()
        return row
    end
    local function Number(parent, text, y, getValue, setValue, min, max, step)
        local row = Row(parent, text, y)
        local edit = CreateFrame("EditBox", nil, row)
        edit:SetSize(42, 20)
        edit:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontNormal")
        edit:SetTextColor(1, 0.81, 0.45)
        edit:SetJustifyH("CENTER")
        local bg = edit:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.07, 0.045, 1)
        local slider = CreateFrame("Slider", nil, row)
        slider:SetOrientation("HORIZONTAL")
        slider:SetSize(115, 18)
        slider:SetPoint("RIGHT", edit, "LEFT", -10, 0)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        local track = slider:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(7)
        track:SetTexture(ASSET .. "Sliders\\Slider_Track.png")
        local progress = slider:CreateTexture(nil, "ARTWORK")
        progress:SetTexture("Interface\\Buttons\\WHITE8X8")
        progress:SetVertexColor(0.94, 0.67, 0.25)
        progress:SetHeight(3)
        progress:SetPoint("LEFT", slider, "LEFT", 0, 0)
        local function RefreshProgress(value)
            local fraction = math.max(0, math.min(1, (value - min) / (max - min)))
            progress:SetWidth(math.max(0.1, 12 + 91 * fraction))
        end
        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(24, 28)
        thumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
        slider:SetThumbTexture(thumb)
        local function Commit(v)
            v = tonumber(v)
            if not v then v = getValue() end
            v = math.max(min, math.min(max, v))
            v = math.floor(v / step + 0.5) * step
            v = tonumber(string.format("%.3f", v))
            setValue(v); slider:SetValue(v); RefreshProgress(v); edit:SetText(string.format("%g", v)); Update()
        end
        slider:SetScript("OnValueChanged", function(_, value)
            local v = tonumber(string.format("%.3f", math.floor(value / step + 0.5) * step))
            setValue(v)
            RefreshProgress(v)
            if not edit:HasFocus() then edit:SetText(string.format("%g", v)) end
            Update()
        end)
        slider:SetValue(getValue())
        RefreshProgress(getValue())
        edit:SetText(string.format("%g", getValue()))
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        edit:SetScript("OnEnterPressed", function(self)
            Commit((self:GetText() or ""):gsub(",", ".")); self:ClearFocus()
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText(string.format("%g", getValue())); self:ClearFocus()
        end)
        edit:SetScript("OnEditFocusLost", function(self)
            Commit((self:GetText() or ""):gsub(",", "."))
        end)
        return row
    end
    local function Check(parent, text, y, getValue, setValue)
        local row = Row(parent, text, y)
        local b = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        b:SetSize(25, 25)
        b:SetPoint("RIGHT", row, "RIGHT", -19, 0)
        b:SetChecked(getValue())
        b:SetScript("OnClick", function(self)
            setValue(not not self:GetChecked()); Update()
        end)
    end
    local anchorRow, anchorRowLabel = Row(general, "EDIT ANCHOR POSITION", -54)
    local editAnchor = CreateFrame("CheckButton", nil, anchorRow, "UICheckButtonTemplate")
    editAnchor:SetSize(25, 25)
    editAnchor:SetPoint("RIGHT", anchorRow, "RIGHT", -19, 0)
    local anchorText = CreateLabel(anchorRow, "Edit Position", "GameFontHighlight")
    anchorText:SetPoint("RIGHT", editAnchor, "LEFT", -8, 0)
    local cursorChoice
    local function RefreshAnchorMode()
        local isMouse = db.anchor == "mouse"
        editAnchor:SetShown(not isMouse)
        anchorText:SetShown(not isMouse)
        anchorRowLabel:SetShown(not isMouse)
        if isMouse then
            if not cursorChoice then
                cursorChoice = Choice(general, "CURSOR POSITION", -54,
                    function()
                        local p = db.cursorPosition
                        return (p == "TOPLEFT" or p == "LEFT" or p == "BOTTOMLEFT") and "LEFT" or "RIGHT"
                    end,
                    function(v) db.cursorPosition = v end,
                    {{"LEFT", "Left"}, {"RIGHT", "Right"}})
            end
            cursorChoice:Show()
        elseif cursorChoice then
            cursorChoice:Hide()
        end
        if isMouse and addon.Tooltip then addon.Tooltip:SetEditAnchor(false) end
        if isMouse then editAnchor:SetChecked(false) end
    end
    Choice(general, "ANCHOR POINT", -4, function() return db.anchor end,
        function(v) db.anchor = v; RefreshAnchorMode() end,
        {{"corner", "Static"}, {"mouse", "Mouse Cursor"}})
    editAnchor:SetScript("OnClick", function(self)
        if addon.Tooltip then addon.Tooltip:SetEditAnchor(not not self:GetChecked()) end
    end)
    RefreshAnchorMode()
    Number(general, "SCALE", -104, function() return db.scale end,
        function(v) db.scale = v end, 0.5, 1.5, 0.01)
    Number(general, "FRAME OPACITY", -154, function() return db.opacity end,
        function(v) db.opacity = v end, 0.1, 1, 0.01)

    local contentOptions = {
        {"GUILD NAME", "guild"}, {"THREAT", "threat"}, {"SHOW IDS", "ids"},
        {"SHOW ITEM LEVEL", "itemLevel"}, {"CLASS COLORED NAMES", "classNames"},
        {"SHOW TARGET'S TARGET", "targetTarget"}, {"HIDE FACTION", "hideFaction"}
    }
    for i, entry in ipairs(contentOptions) do
        local key = entry[2]
        local y = -4 - (i-1)*43
        if entry[3] then
            Choice(contents, entry[1], y, function() return db[key] end,
                function(v) db[key] = v end, entry[3])
        else
            Check(contents, entry[1], y, function() return db[key] end,
                function(v) db[key] = v end)
        end
    end

    local function FontGroup(config, offset, title)
        local groupBack = fonts:CreateTexture(nil, "BACKGROUND")
        groupBack:SetPoint("TOPLEFT", fonts, "TOPLEFT", 6, offset + 12)
        groupBack:SetPoint("TOPRIGHT", fonts, "TOPRIGHT", -6, offset + 12)
        groupBack:SetHeight(232)
        groupBack:SetColorTexture(0.18, 0.10, 0.065, 0.52)
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = fonts:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(0.68, 0.46, 0.24, 0.85)
            if side == "TOP" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetHeight(1)
            elseif side == "BOTTOM" then
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetHeight(1)
            elseif side == "LEFT" then
                edge:SetPoint("TOPLEFT", groupBack, "TOPLEFT")
                edge:SetPoint("BOTTOMLEFT", groupBack, "BOTTOMLEFT")
                edge:SetWidth(1)
            else
                edge:SetPoint("TOPRIGHT", groupBack, "TOPRIGHT")
                edge:SetPoint("BOTTOMRIGHT", groupBack, "BOTTOMRIGHT")
                edge:SetWidth(1)
            end
        end
        local titleLabel = CreateLabel(fonts, title, "GameFontNormalLarge")
        titleLabel:SetPoint("TOPLEFT", fonts, "TOPLEFT", 14, offset)
        titleLabel:SetTextColor(1, 0.79, 0.42)
        Choice(fonts, "FONT", offset-30, function() return config.font end,
            function(v) config.font = v; if BaziUI.TooltipFonts then BaziUI.TooltipFonts.Apply() end end,
            {{"GLOBAL", "Global"}, {"FRIZQT", "Friz Quadrata"}, {"ARIAL", "Arial Narrow"}, {"MORPHEUS", "Morpheus"}})
        Choice(fonts, "OUTLINE", offset-78, function() return config.outline end,
            function(v) config.outline = v; if BaziUI.TooltipFonts then BaziUI.TooltipFonts.Apply() end end,
            {{"NONE", "None"}, {"OUTLINE", "Outline"}, {"THICKOUTLINE", "Thick Outline"}})
        Number(fonts, "SIZE", offset-126, function() return config.size end,
            function(v) config.size = v; if BaziUI.TooltipFonts then BaziUI.TooltipFonts.Apply() end end, 8, 30, 1)
        Check(fonts, "SHADOW", offset-174, function() return config.shadow end,
            function(v) config.shadow = v; if BaziUI.TooltipFonts then BaziUI.TooltipFonts.Apply() end end)
    end
    FontGroup(db.titleFont, -4, "TITLE TEXT")
    FontGroup(db.textFont, -248, "BODY TEXT")
    fonts:SetHeight(490)
    RefreshTabs()
    return page
end

local function CreateVersionHistoryPage()
    local page = CreateFrame("Frame", nil, contentFrame)
    page:SetAllPoints(contentFrame)
    pages["Version History"] = page

    local panel = CreatePanel(page, -10, 200)
    CreateSection(panel, "VERSION HISTORY", -14)

    local current = CreateLabel(panel, "v" .. (addon.version or "0.2.1"), "GameFontNormalLarge")
    current:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -56)
    current:SetTextColor(1, 0.81, 0.45)
    local currentNotes = CreateLabel(panel,
        "Tooltip release: anchor, scale, opacity, contents, ilvl and fonts.",
        "GameFontHighlightSmall")
    currentNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -83)
    currentNotes:SetTextColor(0.92, 0.79, 0.65)

    local previous = CreateLabel(panel, "v0.1.2", "GameFontNormalLarge")
    previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -119)
    previous:SetTextColor(1, 0.81, 0.45)
    local previousNotes = CreateLabel(panel,
        "Tooltip development: positioning, appearance and content controls.",
        "GameFontHighlightSmall")
    previousNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -146)
    previousNotes:SetTextColor(0.92, 0.79, 0.65)

    local original = CreateLabel(panel, "v0.1.0", "GameFontNormalLarge")
    original:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -182)
    original:SetTextColor(1, 0.81, 0.45)
    local originalNotes = CreateLabel(panel,
        "Original options menu, settings and module placeholders.",
        "GameFontHighlightSmall")
    originalNotes:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -209)
    originalNotes:SetTextColor(0.92, 0.79, 0.65)
    return page
end

local function CreateNavigationButton(parent, name, label, y)
    -- Custom flat navigation: the active page gets purple, not every button.
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(164, 29)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(button)
    -- Straight bronze edges to match the rectangular fill.
    local edges = {}
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local line = button:CreateTexture(nil, "ARTWORK")
        if edge == "TOP" then
            line:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            line:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            line:SetHeight(1)
        elseif edge == "BOTTOM" then
            line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            line:SetHeight(1)
        elseif edge == "LEFT" then
            line:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
            line:SetWidth(1)
        else
            line:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            line:SetWidth(1)
        end
        edges[#edges + 1] = line
    end
    local function TintEdges(r, g, b, a)
        for _, line in ipairs(edges) do line:SetColorTexture(r, g, b, a) end
    end
    local stripe = button:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    stripe:SetWidth(3)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", button, "LEFT", 17, 0)
    text:SetText(label)
    text:SetJustifyH("LEFT")
    button.baziActive = false
    button.baziHover = false
    button.baziRefresh = function()
        if button.baziActive then
            TintEdges(0.83, 0.63, 0.30, 0.88)
            fill:SetColorTexture(0.34, 0.17, 0.25, 0.98)
            stripe:SetColorTexture(0.83, 0.63, 0.30, 1)
            text:SetTextColor(1, 0.85, 0.55)
        elseif button.baziHover then
            TintEdges(0.72, 0.53, 0.31, 0.72)
            fill:SetColorTexture(0.28, 0.15, 0.085, 0.96)
            stripe:SetColorTexture(0.57, 0.42, 0.26, 0.8)
            text:SetTextColor(0.95, 0.87, 0.73)
        else
            TintEdges(0.50, 0.34, 0.19, 0.55)
            fill:SetColorTexture(0.18, 0.095, 0.05, 0.94)
            stripe:SetColorTexture(0.54, 0.35, 0.19, 0.75)
            text:SetTextColor(0.87, 0.74, 0.56)
        end
    end
    button:SetScript("OnEnter", function(self) self.baziHover = true; self.baziRefresh() end)
    button:SetScript("OnLeave", function(self) self.baziHover = false; self.baziRefresh() end)
    button:SetScript("OnClick", function() ShowPage(name) end)
    button.baziRefresh()
    navButtons[name] = button
end

function addon.Options:Open()
    if not optionsFrame then
        self:Create()
    end

    optionsFrame:Show()
    optionsFrame:Raise()
 end

function addon.Options:Create()
    local db = addon.db and addon.db.profile
    if not db then
        print("Bazi UI: Settings database is not initialized.")
        return
    end
    optionsFrame = CreateFrame("Frame", "BaziUIOptionsFrame", UIParent)
    -- Native bronze Blizzard frame, verified visually on Forever.
    local borderHost = CreateFrame("Frame", nil, optionsFrame, "ButtonFrameTemplate")
    borderHost:SetAllPoints(optionsFrame)
    borderHost:EnableMouse(false)
    for _, child in ipairs({borderHost:GetChildren()}) do
        if child ~= borderHost.NineSlice then
            child:Hide()
        end
    end
    for _, region in ipairs({borderHost:GetRegions()}) do
        region:Hide()
    end
    if borderHost.NineSlice then
        borderHost.NineSlice:Show()
    end
    -- Remove portrait-only art without touching the bronze NineSlice border.
    -- Forever's character frame inspection identifies 130924 as portrait trim.
    local function HidePortraitArt(frame, depth)
        if depth > 4 then return end
        for _, region in ipairs({frame:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                local texture = region:GetTexture()
                if texture == 130924 or texture == 626000 then
                    region:Hide()
                    region:SetAlpha(0)
                end
            end
        end
        for _, child in ipairs({frame:GetChildren()}) do
            HidePortraitArt(child, depth + 1)
        end
    end
    HidePortraitArt(borderHost, 0)

    -- The native portrait ring is part of the frame design. Keep it and
    -- insert the Bazi emblem in its centre (asset supplied in this repo).
    -- Put the emblem on a frame above the template artwork, not underneath it.
    -- Keep the emblem attached to the options window: a separate UIParent
    -- overlay did not render reliably on the Forever client.
    local emblemHost = CreateFrame("Frame", nil, borderHost.NineSlice or optionsFrame)
    emblemHost:SetSize(66, 66)
    -- The emblem graphic is slightly asymmetric inside its transparent image.
    -- A tiny optical correction centers the visible B over the native ring.
    emblemHost:SetPoint("CENTER", optionsFrame, "TOPLEFT", 24, -21)
    emblemHost:SetFrameStrata("FULLSCREEN_DIALOG")
    emblemHost:SetFrameLevel(math.max(borderHost:GetFrameLevel(), borderHost.NineSlice and borderHost.NineSlice:GetFrameLevel() or 0) + 30)
    emblemHost:EnableMouse(false)
    optionsFrame.baziEmblemHost = emblemHost
    local emblem = emblemHost:CreateTexture(nil, "OVERLAY")
    emblem:SetAllPoints(emblemHost)
    emblem:SetTexture(ASSET .. "Icons\\BaziUI_Emblem_256.png")
    optionsFrame.baziEmblem = emblem

    -- Always open at the default dimensions, regardless of the last resize.
    optionsFrame:SetSize(900, 555)
    optionsFrame:SetResizable(true)
    -- WoW Forever may expose SetResizeBounds instead of the legacy
    -- SetMinResize / SetMaxResize methods. Never call an absent API.
    if optionsFrame.SetResizeBounds then
        optionsFrame:SetResizeBounds(760, 350, 1500, 1000)
    else
        if optionsFrame.SetMinResize then
            optionsFrame:SetMinResize(760, 350)
        end
        if optionsFrame.SetMaxResize then
            optionsFrame:SetMaxResize(1500, 1000)
        end
    end
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)

    -- Same drag-to-resize interaction as the archived V7 implementation.
    -- Native NineSlice frame artwork remains untouched.
    local function ResizeGrip(anchor)
        local grip = CreateFrame("Button", nil, optionsFrame)
        grip:SetSize(35, 35)
        grip:SetPoint(anchor, optionsFrame, anchor, 0, 0)
        grip:SetFrameLevel(optionsFrame:GetFrameLevel() + 35)
        grip:EnableMouse(true)
        -- Two visible bronze diagonals inside each corner, without changing
        -- the approved outer NineSlice border artwork.
        for i = 0, 0 do
            local stroke = grip:CreateTexture(nil, "OVERLAY")
            stroke:SetColorTexture(0.90, 0.69, 0.38, 0.95)
            stroke:SetSize(13 - i * 4, 1.5)
            local offset = 10 + i * 5
            stroke:SetPoint("CENTER", grip, "BOTTOMLEFT",
                anchor == "BOTTOMLEFT" and offset or (35 - offset), offset)
            if stroke.SetRotation then
                stroke:SetRotation(anchor == "BOTTOMLEFT" and -math.pi / 4 or math.pi / 4)
            end
        end
        grip:RegisterForDrag("LeftButton")
        grip:SetScript("OnDragStart", function()
            if not InCombatLockdown or not InCombatLockdown() then
                optionsFrame:StartSizing(anchor)
            end
        end)
        grip:SetScript("OnDragStop", function()
            optionsFrame:StopMovingOrSizing()
            -- Resize applies only to the current opening of the window.
        end)
        return grip
    end
    ResizeGrip("BOTTOMLEFT")
    ResizeGrip("BOTTOMRIGHT")
    -- Ease into 75% opacity during movement; restore instantly on stopping.
    local displayedAlpha = 1
    local fadeSeconds = 0.65
    optionsFrame:SetScript("OnShow", function(self)
        self:SetSize(900, 555)
        -- Saved scale must be reapplied after /reload and on every open.
        local profile = addon.db and addon.db.profile
        local savedScale = profile and tonumber(profile.uiScale) or 1
        self:SetScale(math.max(0.70, math.min(1.50, savedScale)))
        displayedAlpha = 1
        self:SetAlpha(1)
    end)
    optionsFrame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        self:SetSize(900, 555)
    end)
    optionsFrame:SetScript("OnUpdate", function(self, elapsed)
        local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
        if type(speed) == "number" and (not issecretvalue or not issecretvalue(speed))
            and (not canaccessvalue or canaccessvalue(speed)) and speed > 0 then
            displayedAlpha = math.max(0.75, displayedAlpha - elapsed * (0.25 / fadeSeconds))
        else
            displayedAlpha = 1
        end
        if self:GetAlpha() ~= displayedAlpha then
            self:SetAlpha(displayedAlpha)
        end
    end)
    local backdrop = optionsFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    backdrop:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 2, -2)
    backdrop:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -2, 2)
    backdrop:SetColorTexture(0.12, 0.075, 0.044, 1)
    -- The native bronze frame already provides the header border.

    optionsFrame:Hide()

    -- The title must render above the native top border, not underneath it.
    local titleHost = CreateFrame("Frame", nil, optionsFrame)
    titleHost:SetSize(180, 28)
    titleHost:SetPoint("BOTTOM", optionsFrame, "TOP", 0, -26)
    titleHost:SetFrameStrata("FULLSCREEN_DIALOG")
    titleHost:SetFrameLevel(borderHost:GetFrameLevel() + 31)
    local title = CreateLabel(titleHost, "Bazi UI", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleHost, "CENTER", 0, 0)
    title:SetJustifyH("CENTER")

    local close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    -- Keep the close button inside the header border.
    close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -3, 2)
    close:SetFrameStrata("FULLSCREEN_DIALOG")
    close:SetFrameLevel(borderHost:GetFrameLevel() + 20)
    optionsFrame.baziClose = close

    local nav = CreateFrame("Frame", nil, optionsFrame)
    nav:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -49)
    local navBackground = nav:CreateTexture(nil, "BACKGROUND")
    navBackground:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 2, -55)
    navBackground:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMLEFT", 190, 12)
    navBackground:SetColorTexture(0.105, 0.063, 0.038, 0.96)
    nav:SetWidth(180)
    nav:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 12, 22)

    -- Small category search, kept entirely inside the existing sidebar.
    local search = CreateFrame("EditBox", nil, nav)
    search:SetPoint("TOPLEFT", nav, "TOPLEFT", 14, -6)
    search:SetSize(164, 17)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetTextInsets(27, 9, 0, 0)
    search:SetTextColor(0.96, 0.85, 0.66, 1)
    search:SetMaxLetters(50)
    local searchBackground = search:CreateTexture(nil, "BACKGROUND")
    searchBackground:SetAllPoints(search)
    searchBackground:SetColorTexture(0.10, 0.06, 0.04, 0.96)
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local line = search:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.67, 0.48, 0.26, 0.7)
        if edge == "TOP" then
            line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
        elseif edge == "BOTTOM" then
            line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
        elseif edge == "LEFT" then
            line:SetPoint("TOPLEFT"); line:SetPoint("BOTTOMLEFT"); line:SetWidth(1)
        else
            line:SetPoint("TOPRIGHT"); line:SetPoint("BOTTOMRIGHT"); line:SetWidth(1)
        end
    end
    -- Hint must be a child of the EditBox: the previous sibling was hidden
    -- behind the edit box background, making the field appear empty.
    local searchIcon = search:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(15, 15)
    searchIcon:SetPoint("LEFT", search, "LEFT", 7, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.88, 0.73, 0.49, 0.9)
    local searchHint = CreateLabel(search, "Search...", "GameFontHighlightSmall")
    searchHint:SetPoint("LEFT", search, "LEFT", 27, 0)
    searchHint:SetTextColor(0.83, 0.72, 0.57, 0.9)
    local searchEmpty = CreateLabel(nav, "No matching categories", "GameFontHighlightSmall")
    searchEmpty:SetPoint("TOPLEFT", nav, "TOPLEFT", 9, -40)
    searchEmpty:SetTextColor(0.77, 0.65, 0.51)
    searchEmpty:Hide()
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    contentFrame = CreateFrame("Frame", nil, optionsFrame)
    contentFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 204, -49)
    contentFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 18)

    local separator = contentFrame:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.72, 0.49, 0.25, 0.65)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 190, -55)
    separator:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 190, 3)

    -- Scrollable categories, with a fixed footer and search box.
    local scrollFrame = CreateFrame("ScrollFrame", nil, nav)
    scrollFrame:SetPoint("TOPLEFT", nav, "TOPLEFT", 14, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -2, 53)
    scrollFrame:EnableMouseWheel(true)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(164, 377)
    scrollFrame:SetScrollChild(scrollChild)
    local scrollBar = CreateFrame("Slider", nil, nav)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(10)
    scrollBar:SetPoint("TOPLEFT", nav, "TOPLEFT", 2, -32)
    scrollBar:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 2, 53)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(15)
    local barTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    barTrack:SetAllPoints(scrollBar)
    barTrack:SetColorTexture(0.38, 0.27, 0.16, 0.85)
    local barThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    barThumb:SetSize(14, 38)
    barThumb:SetTexture(ASSET .. "Sliders\\Slider_Gem.png")
    scrollBar:SetThumbTexture(barThumb)
    local function RefreshScroll()
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetShown(maxScroll > 0)
        if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
        scrollFrame:SetVerticalScroll(scrollBar:GetValue())
    end
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollBar:EnableMouse(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(math.max(0, scrollBar:GetValue() - delta * 38))
    end)
    scrollFrame:SetScript("OnSizeChanged", RefreshScroll)

    CreateNavigationButton(scrollChild, "General", "General", 0)
    CreateNavigationButton(scrollChild, "Quality of Life", "Quality of Life", -29)
    CreateNavigationButton(scrollChild, "Profiles", "Profiles", -58)
    CreateNavigationButton(scrollChild, "UnitFrames", "UnitFrames", -87)
    CreateNavigationButton(scrollChild, "Nameplates", "Nameplates", -116)
    CreateNavigationButton(scrollChild, "ActionBars", "ActionBars", -145)
    CreateNavigationButton(scrollChild, "Chat", "Chat", -174)
    CreateNavigationButton(scrollChild, "Quest", "Quest", -203)
    CreateNavigationButton(scrollChild, "Gathering", "Gathering", -232)
    CreateNavigationButton(scrollChild, "Minimap", "Minimap", -261)
    CreateNavigationButton(scrollChild, "Tooltip", "Tooltip", -290)
    CreateNavigationButton(scrollChild, "Combat", "Combat", -319)
    CreateNavigationButton(scrollChild, "BugTab", "BugTab", -348)

    local historyButton = CreateFrame("Button", nil, nav)
    historyButton:SetSize(170, 18)
    historyButton:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 4, 27)
    local historyLabel = CreateLabel(historyButton, "Version History  |  v" .. (addon.version or "0.1.1"), "GameFontHighlightSmall")
    historyLabel:SetPoint("LEFT", historyButton, "LEFT", 8, 0)
    historyLabel:SetTextColor(0.62, 0.58, 0.53)
    historyButton:SetScript("OnClick", function() ShowPage("Version History") end)
    historyButton:SetScript("OnEnter", function() historyLabel:SetTextColor(0.92, 0.80, 0.60) end)
    historyButton:SetScript("OnLeave", function() historyLabel:SetTextColor(0.62, 0.58, 0.53) end)
    local helpLabel = CreateLabel(nav, "Type /bazi help for commands", "GameFontHighlightSmall")
    helpLabel:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 12, 8)
    helpLabel:SetTextColor(0.64, 0.59, 0.53)

    local navigationOrder = {"General", "Quality of Life", "Profiles", "UnitFrames", "Nameplates", "ActionBars", "Chat", "Quest", "Gathering", "Minimap", "Tooltip", "Combat", "BugTab"}
    local function UpdateSearch()
        local query = string.lower(search:GetText() or "")
        local shown = 0
        searchHint:SetShown(query == "" and not search:HasFocus())
        for _, name in ipairs(navigationOrder) do
            local button = navButtons[name]
            if string.find(string.lower(name), query, 1, true) then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -shown * 29)
                button:Show()
                shown = shown + 1
            else
                button:Hide()
            end
        end
        scrollChild:SetHeight(math.max(1, shown * 29))
        scrollBar:SetValue(0)
        RefreshScroll()
        searchEmpty:SetShown(shown == 0)
        historyButton:SetShown(query == "")
        helpLabel:SetShown(query == "")
    end
    search:SetScript("OnTextChanged", UpdateSearch)
    search:SetScript("OnEditFocusGained", UpdateSearch)
    search:SetScript("OnEditFocusLost", UpdateSearch)
    UpdateSearch()

    -- Only General is built for the initial /bazi open. All other pages are
    -- created on first selection, then retained for the rest of the session.
    pageFactories.General = CreateGeneralPage
    pageFactories["Version History"] = CreateVersionHistoryPage
    pageFactories["Quality of Life"] = CreateQoLPage
    pageFactories.Profiles = function()
        CreatePlaceholderPage("Profiles", "Profile management is not implemented yet. Your current settings are preserved.")
    end
    pageFactories.UnitFrames = CreateUnitFramesPage
    pageFactories.Nameplates = function()
        if addon.NameplatesOptions and addon.NameplatesOptions.CreatePage then
            pages.Nameplates = addon.NameplatesOptions:CreatePage(contentFrame)
        else
            CreatePlaceholderPage("Nameplates")
        end
    end
    pageFactories.ActionBars = function() CreatePlaceholderPage("ActionBars") end
    pageFactories.Chat = function() CreatePlaceholderPage("Chat") end
    pageFactories.Quest = function() CreatePlaceholderPage("Quest") end
    pageFactories.Gathering = function() CreatePlaceholderPage("Gathering") end
    pageFactories.Minimap = CreateMinimapPage
    pageFactories.Tooltip = CreateTooltipPage
    pageFactories.Combat = function() CreatePlaceholderPage("Combat") end
    pageFactories.BugTab = function() CreatePlaceholderPage("BugTab") end

    ShowPage("General")
end

function addon.Options:Initialize()
    -- Created on first open.
end
