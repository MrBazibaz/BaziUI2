-- Bazi UI group frames. Isolated from the established single-unit renderer.
local addon = BaziUI
addon.GroupFrames = addon.GroupFrames or {}
local M = addon.GroupFrames
local groups = {}
local function config(kind)
    local db = addon.db and addon.db.profile and addon.db.profile.unitframes
    if not db then return nil end
    db.groups = db.groups or {}
    db.groups[kind] = db.groups[kind] or {}
    return db.groups[kind]
end
local function safeCombat()
    return InCombatLockdown and InCombatLockdown()
end
local function memberOptions(opt,index)
    opt.members = opt.members or {}
    opt.members[index] = opt.members[index] or {}
    return opt.members[index]
end
local function effectiveOptions(opt,index)
    local merged = {}
    for k,v in pairs(opt) do merged[k]=v end
    for k,v in pairs(memberOptions(opt,index)) do merged[k]=v end
    return merged
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k,v in pairs(value) do result[k]=clone(v) end
    return result
end
function M:CopyMember(kind,sourceKind,sourceIndex,targetIndex)
    if safeCombat() then return false end
    local db=addon.db and addon.db.profile and addon.db.profile.unitframes
    if not db then return false end
    local target=config(kind)
    if not target then return false end
    local source
    if sourceKind=="player" or sourceKind=="target" or sourceKind=="focus" or sourceKind=="pet" or sourceKind=="targettarget" then
        source=db.frames and db.frames[sourceKind]
    else
        local sourceGroup=config(sourceKind)
        source=sourceGroup and effectiveOptions(sourceGroup,sourceIndex)
    end
    if not source then return false end
    local keep=memberOptions(target,targetIndex)
    local output=clone(source)
    -- Copy visual settings only; preserve group geometry and unit identity.
    for _,field in ipairs({"x","y","spacing","columns","growth","anchor","enabled","showSolo","members"}) do output[field]=nil end
    for k,v in pairs(output) do keep[k]=v end
    self:Refresh()
    return true
end
function M:ApplyToAll(kind,sourceIndex)
    if safeCombat() then return false end
    local opt=config(kind)
    if not opt then return false end
    local count=kind=="raid" and 40 or kind=="party" and 4 or 5
    local source=clone(effectiveOptions(opt,sourceIndex))
    for _,field in ipairs({"x","y","spacing","columns","growth","anchor","enabled","showSolo","members"}) do source[field]=nil end
    for i=1,count do
        if i~=sourceIndex then
            local target=memberOptions(opt,i)
            for k in pairs(target) do target[k]=nil end
            for k,v in pairs(source) do target[k]=clone(v) end
        end
    end
    self:Refresh()
    return true
end
local function createMember(kind, index)
    local unit = kind .. index
    local frame = CreateFrame("Button", "BaziUI_" .. kind .. index, UIParent, "SecureUnitButtonTemplate")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("type1", "target")
    frame:SetAttribute("type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
    frame:SetSize(kind ~= "raid" and 190 or 110, kind ~= "raid" and 48 or 30)
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
    border:SetBackdropBorderColor(.90,.72,.42,1)
    local hp = CreateFrame("StatusBar",nil,frame)
    hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hp:SetStatusBarColor(.33,.53,.34)
    local power = CreateFrame("StatusBar",nil,frame)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetStatusBarColor(.29,.43,.70)
    local name = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    name:SetJustifyH("CENTER")
    local portrait
    if kind ~= "raid" then
        portrait = frame:CreateTexture(nil,"ARTWORK")
        portrait:SetSize(42,42)
    end
    local hpText = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    hpText:SetPoint("RIGHT",hp,"RIGHT",-3,0)
    frame.hpText = hpText
    local powerText = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    powerText:SetPoint("RIGHT",power,"RIGHT",-3,0)
    frame.powerText = powerText
    frame.unitToken = unit
    frame.hp,frame.power,frame.label,frame.portrait = hp,power,name,portrait
    frame:Hide()
    return frame
end
local function layoutMember(f, kind, index, opt)
    local width = math.max(80,math.min(360,tonumber(opt.width) or (kind=="party" and 190 or 110)))
    local height = math.max(22,math.min(90,tonumber(opt.height) or (kind=="party" and 48 or 30)))
    f:SetSize(width,height)
    local portrait = f.portrait
    local side = index <= 2 and "LEFT" or "RIGHT"
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint(side,f,side,side=="LEFT" and 3 or -3,0)
        portrait:SetSize(height-6,height-6)
    end
    f.hp:ClearAllPoints()
    f.hp:SetPoint("TOPLEFT",f,"TOPLEFT",portrait and (side=="LEFT" and height or 5) or 5,-5)
    f.hp:SetPoint("TOPRIGHT",f,"TOPRIGHT",portrait and (side=="RIGHT" and -height or -5) or -5,-5)
    f.hp:SetHeight((height-12)*.72)
    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT",f.hp,"BOTTOMLEFT",0,-2)
    f.power:SetPoint("TOPRIGHT",f.hp,"BOTTOMRIGHT",0,-2)
    f.power:SetHeight((height-12)*.28)
    f.label:ClearAllPoints()
    f.label:SetPoint("CENTER",f.hp,"CENTER")
    local font,size,flags = f.label:GetFont()
    if font then f.label:SetFont(font,math.max(0,tonumber(opt.fontSize) or 11),flags) end
    f.hpText:SetShown(opt.showHealthPercent == true)
    f.powerText:SetShown(opt.showPowerPercent == true and opt.showPower ~= false)
    f.label:SetShown(opt.showName ~= false and (tonumber(opt.fontSize) or 11)>0)
    f.power:SetShown(opt.showPower ~= false)
    local gap = tonumber(opt.spacing) or 8
    f:ClearAllPoints()
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
