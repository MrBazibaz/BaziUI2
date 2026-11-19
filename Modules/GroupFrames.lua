    if kind=="boss" then
        f:SetPoint("TOPLEFT",UIParent,"CENTER",tonumber(opt.x) or 300,(tonumber(opt.y) or 180)-(index-1)*(height+gap))
    elseif kind=="party" then
        local base=config("party")
        local widths={}
        local total=gap*3
        for i=1,4 do
            widths[i]=math.max(80,math.min(360,tonumber(effectiveOptions(base,i).width) or 190))
            total=total+widths[i]
        end
        local offset=0
        for i=1,index-1 do offset=offset+widths[i]+gap end
        f:SetPoint("TOPLEFT",UIParent,"TOP",-(total/2)+offset,tonumber(opt.y) or -45)
    else
        local cols = math.max(1,math.min(8,tonumber(opt.columns) or 5))
        local col = (index-1)%cols
        local row = math.floor((index-1)/cols)
        local down = opt.growth ~= "up"
        local right = opt.anchor ~= "TOPRIGHT" and opt.anchor ~= "BOTTOMRIGHT"
        local originX = tonumber(opt.x) or -380
        local originY = tonumber(opt.y) or -250
        f:SetPoint("TOPLEFT",UIParent,"CENTER",originX+(right and col or -col)*(width+gap),originY+(down and -row or row)*(height+gap))
    end
end
local function updateMember(f, preview)
    if preview then
        f.hp:SetMinMaxValues(0,100)
        f.hp:SetValue(75)
        f.power:SetMinMaxValues(0,100)
        f.power:SetValue(60)
        f.label:SetText("Preview " .. f.unitToken)
        f.hpText:SetText("75%")
        f.powerText:SetText("60%")
        if f.portrait then f.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
        return
    end
    if not UnitExists(f.unitToken) then return end
    f.hp:SetMinMaxValues(0,UnitHealthMax(f.unitToken))
    f.hp:SetValue(UnitHealth(f.unitToken))
    f.power:SetMinMaxValues(0,UnitPowerMax(f.unitToken))
    f.power:SetValue(UnitPower(f.unitToken))
    f.label:SetText(UnitName(f.unitToken) or "")
    -- Health and power values can be protected in Forever; do not perform Lua arithmetic on them.
    f.hpText:SetText("")
    f.powerText:SetText("")
    if f.portrait then SetPortraitTexture(f.portrait,f.unitToken) end
end
function M:Refresh()
    if safeCombat() then return end
    for _,kind in ipairs({"party","raid","boss"}) do
        local opt = config(kind)
        if opt then
            groups[kind] = groups[kind] or {}
            local count = kind=="party" and 4 or (kind=="boss" and 5 or 40)
            if opt.enabled then
                for i=1,count do
                    local f = groups[kind][i]
                    if not f then f=createMember(kind,i);groups[kind][i]=f end
                    layoutMember(f,kind,i,effectiveOptions(opt,i))
                    local preview = opt.showSolo and (kind=="boss" or not IsInGroup())
                    local exists = UnitExists(f.unitToken)
                    -- Secure unit frames are not reconfigured in combat.
                    f:SetShown(preview or exists == true)
                    if preview or exists == true then updateMember(f,preview) end
                end
            else
                for _,f in ipairs(groups[kind]) do f:Hide() end
            end
        end
    end
end
function M:Initialize()
    if self.initialized then return end
    self.initialized=true
    local events=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PLAYER_REGEN_ENABLED","UNIT_HEALTH","UNIT_POWER_UPDATE","UNIT_NAME_UPDATE"}) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent",function() M:Refresh() end)
    self:Refresh()
end
