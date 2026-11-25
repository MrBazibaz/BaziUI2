local addon = BaziUI
local chat = addon.Chat

local tabs = {"Appearance", "Fonts", "Channels", "Alerts", "Layout"}

local function choices(...)
    local entries = {}
    for i = 1, select("#", ...), 2 do
        entries[#entries + 1] = {select(i, ...), select(i + 1, ...)}
    end
    return entries
end

function chat.CreatePage(parent, createSlider, artwork)
    local db = chat.Settings()
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT", 12, -8)
    header:SetPoint("TOPRIGHT", -12, -8)
    header:SetHeight(76)
    artwork(header)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -12)
    title:SetText("CHAT")
    title:SetTextColor(1, 0.79, 0.42)

    local function checkbox(owner, label, x, y, read, write)
        local control = addon.Theme:CreateCheckbox(owner)
        control:SetSize(25, 25)
        control:SetPoint("TOPLEFT", x, y)
        local text = control:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", control, "RIGHT", 5, 0)
        text:SetText(label)
        control:SetHitRectInsets(0, -text:GetStringWidth() - 5, 0, 0)
        control:SetChecked(read())
        control:SetScript("OnClick", function(self) write(not not self:GetChecked()) end)
    end
    local function setting(key, value)
        db[key] = value
        if key == "chatFont" then addon.Typography.ModuleChanged("Chat", "font") end
        if key == "fontSize" then addon.Typography.ModuleChanged("Chat:Messages", "size") end
        chat.Refresh(key)
    end
    checkbox(header, "Enable Chat (requires /reload)", 16, -40,
        function() return db.enabled end, function(value) setting("enabled", value) end)

    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -18)
    panel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 0)
    artwork(panel)
    local buttons, groups, bodies = {}, {}, {}
    function page:SelectSubpage(selected)
        if not groups[selected] then return end
        for name, group in pairs(groups) do
            group:SetShown(name == selected)
            local active = name == selected
            addon.Theme:StyleSettingsTab(buttons[name], active)
        end
    end

    for index, name in ipairs(tabs) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(92, 30)
        button.fill = button:CreateTexture(nil, "BACKGROUND")
        button.fill:SetAllPoints()
        local caption = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        caption:SetPoint("CENTER")
        caption:SetText(name)
        caption:SetTextColor(1, 0.81, 0.46)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + (index - 1) * 94, -14)
        button:SetScript("OnClick", function() page:SelectSubpage(name) end)
        buttons[name] = button
        local viewport = CreateFrame("ScrollFrame", nil, panel)
        viewport:SetPoint("TOPLEFT", 12, -56)
        viewport:SetPoint("BOTTOMRIGHT", -19, 10)
        viewport:SetClipsChildren(true)
        local group = CreateFrame("Frame", nil, viewport)
        group:SetSize(1, 360)
        viewport:SetScrollChild(group)
        local track = CreateFrame("Slider", nil, panel)
        track:SetOrientation("VERTICAL")
        track:SetWidth(12)
        track:SetPoint("TOPLEFT", viewport, "TOPRIGHT", 3, 0)
        track:SetPoint("BOTTOMLEFT", viewport, "BOTTOMRIGHT", 3, 0)
        local background = track:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        addon.Theme:Paint(background, "field", 0.9)
        local thumb = track:CreateTexture(nil, "OVERLAY")
        addon.Theme:StyleScrollThumb(thumb)
        thumb:SetSize(14, 38)
        track:SetThumbTexture(thumb)
        track:SetScript("OnValueChanged", function(_, value)
            if viewport:GetVerticalScroll() ~= value then viewport:SetVerticalScroll(value) end
        end)
        viewport:SetScript("OnVerticalScroll", function(_, offset)
            if track:GetValue() ~= offset then track:SetValue(offset) end
        end)
        viewport:EnableMouseWheel(true)
        viewport:SetScript("OnMouseWheel", function(_, delta)
            if track:IsShown() then track:SetValue(track:GetValue() - delta * 36) end
        end)
        local function refreshTrack()
            local range = math.max(0, group:GetHeight() - viewport:GetHeight())
            track:SetMinMaxValues(0, math.max(1, range))
            track:SetValue(math.min(range, viewport:GetVerticalScroll()))
            track:SetShown(viewport:IsShown() and range > 1)
        end
        viewport:HookScript("OnSizeChanged", function(self)
            group:SetWidth(math.max(1, self:GetWidth()))
            refreshTrack()
        end)
        viewport:HookScript("OnShow", refreshTrack)
        viewport:HookScript("OnHide", function() track:Hide() end)
        group:HookScript("OnSizeChanged", refreshTrack)
        refreshTrack()
        groups[name], bodies[name] = viewport, group
    end

    local group, y
    local function section(name)
        if group then group:SetHeight(-y + 8) end
        group, y = bodies[name], -6
    end
    local function toggle(label, key)
        checkbox(group, label, 16, y, function() return db[key] end,
            function(value) setting(key, value) end)
        y = y - 32
    end
    local function row(label)
        local band = group:CreateTexture(nil, "BACKGROUND")
        band:SetPoint("TOPLEFT", 24, y)
        band:SetPoint("TOPRIGHT", -24, y)
        band:SetHeight(34)
        addon.Theme:Paint(band, "row", 0.96)
        local text = group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", 39, y - 8)
        text:SetText(label)
        text:SetTextColor(1, 0.78, 0.39)
    end
    local function menu(label, provider, read, write)
        row(label)
        local button = addon.Theme:CreateSettingsDropdown(group)
        button:SetPoint("TOPRIGHT", -37, y - 3)
        button:SetSize(235, 27)
        -- Draw above the template label, which Blizzard refreshes on selection.
        local face = CreateFrame("Frame", nil, button)
        face:SetAllPoints()
        face:SetFrameLevel(button:GetFrameLevel() + 2)
        face:EnableMouse(false)
        local fill = face:CreateTexture(nil, "OVERLAY", nil, 4)
        fill:SetAllPoints()
        addon.Theme:Paint(fill, "field", 1)
        local border = face:CreateTexture(nil, "OVERLAY", nil, 5)
        border:SetPoint("TOPLEFT")
        border:SetPoint("TOPRIGHT")
        border:SetHeight(1)
        border:SetColorTexture(0.75, 0.55, 0.29)
        local arrow = face:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetDrawLayer("OVERLAY", 6)
        arrow:SetPoint("RIGHT", -7, 0)
        arrow:SetText("v")
        local caption = face:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        caption:SetDrawLayer("OVERLAY", 6)
        caption:SetPoint("LEFT", 12, 0)
        caption:SetPoint("RIGHT", -22, 0)
        caption:SetJustifyH("CENTER")
        caption:SetTextColor(1, 0.79, 0.42)
        local function update()
            local label = "Select"
            for _, entry in ipairs(provider()) do
                if read() == entry[1] then label = entry[2]; break end
            end
            button:SetText(label)
            caption:SetText(label)
        end
        button:SetupMenu(function(_, root)
            if root.SetScrollMode then root:SetScrollMode(320) end
            for _, entry in ipairs(provider()) do
                root:CreateRadio(entry[2], function() return read() == entry[1] end, function()
                    write(entry[1])
                    update()
                end)
            end
        end)
        button:HookScript("OnShow", update)
        update()
        y = y - 39
        return update
    end
    local function dropdown(label, key, list)
        return menu(label, function() return list end, function() return db[key] end,
            function(value) setting(key, value) end)
    end
    local function color(label, read, write)
        row(label)
        local swatch = addon.Theme:CreateColorSwatch(group, read, write)
        swatch:SetPoint("TOPRIGHT", -37, y - 5)
        swatch:HookScript("OnShow", swatch.Refresh)
        y = y - 39
        return swatch
    end
    local function slider(label, low, high, read, write, steps)
        local control = createSlider(group, label, "", low, high, 1, read(), y, write, true, true)
        control:HookScript("OnShow", function() control:DisplayValue(read()) end)
        if steps then
            local owner = control:GetParent()
            control:ClearAllPoints()
            control:SetPoint("RIGHT", owner, "RIGHT", -110, 0)
            control.valueBox:ClearAllPoints()
            control.valueBox:SetPoint("RIGHT", owner, "RIGHT", -68, 0)
            for i, delta in ipairs({-1, 1}) do
                local button = CreateFrame("Button", nil, owner)
                button:SetSize(22, 23)
                local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                glyph:SetPoint("CENTER")
                glyph:SetText(delta == 1 and "+" or "-")
                button:SetPoint("RIGHT", owner, "RIGHT", i == 1 and -40 or -16, 0)
                button:SetScript("OnClick", function()
                    control:SetValue(math.max(low, math.min(high, control:GetValue() + delta)))
                end)
            end
        end
        y = y - 45
    end

    section("Appearance")
    dropdown("Theme", "theme", choices("everchat", "Framed", "minimal", "Minimal", "classic", "Blizzard"))
    dropdown("Metal", "themeMetal", choices("gold", "Gold", "silver", "Silver", "bronze", "Bronze"))
    dropdown("When inactive", "chatRest", choices("faded", "Faded", "hidden", "Hidden", "always", "Always visible"))
    slider("Message visibility (seconds)", 1, 120, function() return db.hideAtRestSeconds end,
        function(value) setting("hideAtRestSeconds", value) end)
    toggle("Hide chat buttons", "hideButtons")
    color("Border color", function() return db.borderColor or addon.Theme.colors.frameBorder end,
        function(value) setting("borderColor", value) end)
    color("Background color", function() return db.backgroundColor or {chat.Theme.BODY:GetRGB()} end,
        function(value) setting("backgroundColor", value) end)
    slider("Background opacity (%)", 0, 100, function() return db.backgroundOpacity or 25 end,
        function(value) setting("backgroundOpacity", value) end)

    section("Fonts")
    local fonts = {{"general", "General (Default)"}}
    for _, font in ipairs(chat.Fonts.FONTS) do fonts[#fonts + 1] = {font.key, font.label} end
    dropdown("Font", "chatFont", fonts)
    slider("Font size", 8, 32, function() return db.fontSize or 14 end,
        function(value) setting("fontSize", value) end)
    slider("Channel name size (px)", 6, 32, function()
        local _, nameSize = DEFAULT_CHAT_FRAME:GetFont()
        return chat.Timestamps.ChannelSize(nameSize or db.fontSize or 14)
    end, function(value) setting("channelSize", value) end)
    dropdown("Outline", "fontOutline", choices("none", "None", "thin", "Thin", "thick", "Thick"))
    dropdown("Line spacing", "lineSpacing", choices("compact", "Compact", "normal", "Normal", "wide", "Wide"))
    toggle("Show time (24-hour)", "timestamps")
    toggle("Show lines between messages", "showSeparators")

    local channel, soundChannel
    local function channels()
        local list = choices("SAY", "Say", "YELL", "Yell", "EMOTE", "Emote", "GUILD", "Guild",
            "OFFICER", "Officer", "PARTY", "Party", "PARTY_LEADER", "Party Leader",
            "RAID", "Raid", "RAID_LEADER", "Raid Leader", "RAID_WARNING", "Raid Warning",
            "INSTANCE_CHAT", "Instance", "INSTANCE_CHAT_LEADER", "Instance Leader",
            "WHISPER", "Whisper", "BN_WHISPER", "Battle.net Whisper")
        local entries = {GetChannelList()}
        for i = 1, #entries, 3 do
            local number, name = entries[i], entries[i + 1]
            if (not canaccessvalue or (canaccessvalue(number) and canaccessvalue(name)))
                and type(number) == "number" and type(name) == "string" then
                list[#list + 1] = {"CHANNEL" .. number, number .. ". " .. name}
            end
        end
        return list
    end
    local function channelKey(channel)
        if channel and channel:match("^CHANNEL%d+$") then
            local id, name = GetChannelName(tonumber(channel:match("%d+$")))
            if (not canaccessvalue or (canaccessvalue(id) and canaccessvalue(name)))
                and id and id > 0 and name then return "CHANNEL:" .. name end
        end
        return channel
    end
    section("Channels")
    dropdown("Player names", "surnames", choices("full", "Full name", "hidden", "First name"))
    toggle("Show friend and guild badges", "socialMarks")
    toggle("Show class icons", "classMarks")
    toggle("Show race icons", "raceMarks")
    toggle("Show spell, item and quest link icons", "linkIcons")
    toggle("Shorten numbered channels", "shortChannels")
    toggle("Hide repeated ads", "hideRepeats")
    local messageColor
    channel = "SAY"
    menu("Channel or message type", channels, function() return channel end, function(value)
        channel = value
        messageColor:Refresh()
    end)
    messageColor = color("Message color", function()
        local native = ChatTypeInfo[channel]
        return (db.channelColors and db.channelColors[channelKey(channel)]) or
            (native and {native.r, native.g, native.b}) or {1, 1, 1}
    end, function(value)
        db.channelColors = db.channelColors or {}
        db.channelColors[channelKey(channel)] = value
        chat.ApplyChannelColors()
    end)

    section("Alerts")
    checkbox(group, "Move friend and recipe notifications", 16, y,
        function() return db.friendToastPosition end, function(value)
            db.friendToastPosition = value
            chat.FriendToasts.Refresh()
        end)
    y = y - 33
    for _, axis in ipairs({"X", "Y"}) do
        local field = "friendToast" .. axis
        slider("Notification " .. axis .. " offset", -1800, 1800,
            function() return db[field] or (axis == "X" and -380 or -205) end,
            function(value) db[field] = value; chat.FriendToasts.Refresh() end, true)
    end
    local friendPreview = addon.Theme:CreateButton(group, "Preview friend notification", 195, 25)
    friendPreview:SetPoint("TOPRIGHT", -37, y)
    friendPreview:SetScript("OnClick", function(self)
        self:SetText(chat.FriendToasts.Preview() and "Stop preview" or "Preview friend notification")
    end)
    groups.Alerts:HookScript("OnHide", function()
        chat.FriendToasts.Preview(false)
        friendPreview:SetText("Preview friend notification")
    end)
    y = y - 34

    dropdown("Unread tab indicator", "alertStyle", choices("dot", "Dot", "name", "Tab name", "flash", "Flash"))
    toggle("Highlight my name", "mentions")
    toggle("Play a sound when mentioned", "mentionSound")
    toggle("Show whisper popup", "whisperToasts")
    dropdown("Whisper popup duration", "whisperDuration", choices("short", "Short", "normal", "Normal", "long", "Long"))
    soundChannel = "SAY"
    local soundUpdate
    menu("Channel or message type", channels, function() return soundChannel end, function(value)
        soundChannel = value
        soundUpdate()
    end)
    local sounds = {{"none", "No sound"}, {"mentions", "Mentions only"}}
    for _, sound in ipairs(chat.Alerts.SOUNDS) do
        sounds[#sounds + 1] = {sound.key, sound.label or sound.key}
    end
    soundUpdate = menu("Channel sound", function() return sounds end,
        function()
            return chat.Alerts.ResolveSoundKey(db.channelSounds and db.channelSounds[channelKey(soundChannel)]) or "none"
        end,
        function(value)
            db.channelSounds = db.channelSounds or {}
            db.channelSounds[channelKey(soundChannel)] = value
            if value ~= "none" and value ~= "mentions" then chat.Alerts.Preview(value) end
        end)
    local preview = CreateFrame("Button", nil, group)
    preview:SetSize(170, 25)
    local previewFill = preview:CreateTexture(nil, "BACKGROUND")
    previewFill:SetAllPoints()
    addon.Theme:Paint(previewFill, "panel", 0.98)
    local previewLabel = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("CENTER")
    previewLabel:SetText("Preview whisper popup")
    previewLabel:SetTextColor(1, 0.79, 0.42)
    preview:SetPoint("TOPRIGHT", -37, y)
    y = y - 32
    preview:SetScript("OnClick", function()
        if chat.active then chat.Whispers.Preview() end
    end)
    section("Layout")
    toggle("Lock chat position", "lockChat")
    toggle("Scrollbar on the left", "scrollbarLeft")
    toggle("Keep chat across /reload", "keepHistory")
    dropdown("Typing box position", "inputPosition", choices("bottom", "Below chat", "top", "Above chat"))
    for _, entry in ipairs({{"Width", "width", 170, 2500}, {"Height", "height", 70, 1300},
        {"X position from left", "left", -80, 3000}, {"Y position from bottom", "bottom", -80, 2000}}) do
        local label, key, low, high = unpack(entry)
        slider(label, low, high, function()
                local layout = chat.Resize.GetLayout()
                return key == "bottom" and (layout.top - layout.height) or layout[key]
            end,
            function(value) chat.Resize.SetLayoutValue(key, value) end, true)
    end

    for _, entry in ipairs({
        {"Typing box X offset", "inputX", -600, 600},
        {"Typing box Y offset", "inputY", -600, 600},
        {"Typing box width (0 = auto)", "inputWidth", 0, 1600},
        {"Typing box height (0 = auto)", "inputHeight", 0, 100},
    }) do
        local label, key, low, high = unpack(entry)
        slider(label, low, high, function() return db[key] or 0 end,
            function(value) setting(key, value) end, true)
    end

    group:SetHeight(-y + 8)
    page:SelectSubpage("Appearance")
    return page
end

