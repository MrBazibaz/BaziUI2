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
    -- Translate the original UnitFrames schema into the separate group renderer.
    -- Never modify the original source tables.
    if sourceKind=="player" or sourceKind=="target" or sourceKind=="focus" or sourceKind=="pet" or sourceKind=="targettarget" then
        output.width = tonumber(source.barWidth) or tonumber(source.width) or 190
        output.height = math.max(22,(tonumber(source.hpHeight) or 23)+(tonumber(source.powerHeight) or 9)+12)
        output.fontSize = tonumber(source.nameFontSize) or tonumber(source.fontSize) or 11
        output.portraitSide = (source.flipPortrait == true) and
            ((sourceKind=="player" or sourceKind=="pet") and "RIGHT" or "LEFT") or
            ((sourceKind=="player" or sourceKind=="pet") and "LEFT" or "RIGHT")
        output.showPortrait = kind ~= "raid"
        output.showHealthPercent = source.hpText == "percent"
        output.showPowerPercent = source.powerText == "percent"
        output.hpText = source.hpText
        output.powerText = source.powerText
    end
    -- Copy visual settings only; preserve group geometry and unit identity.
    for _,field in ipairs({"x","y","spacing","columns","growth","anchor","enabled","showSolo","members","offsetX","offsetY"}) do output[field]=nil end
    local offsetX,offsetY=keep.offsetX,keep.offsetY
    for k in pairs(keep) do keep[k]=nil end
    for k,v in pairs(output) do keep[k]=clone(v) end
    keep.offsetX,keep.offsetY=offsetX,offsetY
    self:Refresh()
    if kind=="party" and addon.PartyFrames then addon.PartyFrames:Refresh() end
    return true
end
function M:ApplyToAll(kind,sourceIndex)
    if safeCombat() then return false end
    local opt=config(kind)
    if not opt then return false end
    local count=kind=="raid" and 40 or kind=="party" and 4 or 5
    local source=clone(effectiveOptions(opt,sourceIndex))
    for _,field in ipairs({"x","y","spacing","columns","growth","anchor","enabled","showSolo","members","offsetX","offsetY"}) do source[field]=nil end
    for i=1,count do
        if i~=sourceIndex then
            local target=memberOptions(opt,i)
            local offsetX,offsetY=target.offsetX,target.offsetY
            for k in pairs(target) do target[k]=nil end
            for k,v in pairs(source) do target[k]=clone(v) end
            target.offsetX,target.offsetY=offsetX,offsetY
        end
    end
    self:Refresh()
    if kind=="party" and addon.PartyFrames then addon.PartyFrames:Refresh() end
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
        local mask=frame:CreateMaskTexture()
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(portrait)
        portrait:AddMaskTexture(mask)
        local rim=frame:CreateTexture(nil,"OVERLAY")
        rim:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
        rim:SetTexCoord(252.78/384,375/384,1.67/134,123.89/134)
        rim:SetPoint("CENTER",portrait,"CENTER")
        frame.rim=rim
    end
    local hpText = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    hpText:SetPoint("RIGHT",hp,"RIGHT",-3,0)
    hpText:SetJustifyH("RIGHT")
    frame.hpText = hpText
    local powerText = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    powerText:SetPoint("RIGHT",power,"RIGHT",-3,0)
    powerText:SetJustifyH("RIGHT")
    frame.powerText = powerText
    -- Party-specific indicators; the established single-unit frames are untouched.
    if kind=="party" then
        frame.indicators={}
        local icons={
            pvp={"Interface\\TargetingFrame\\UI-PVP-FFA",0},
            leader={"Interface\\GroupFrame\\UI-Group-LeaderIcon",1},
            raid={"Interface\\TargetingFrame\\UI-RaidTargetingIcons",2},
            role={"Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",3},
        }
        for id,data in pairs(icons) do
            local icon=frame:CreateTexture(nil,"OVERLAY")
            icon:SetTexture(data[1])
            icon:SetSize(16,16)
            icon:SetPoint("TOPLEFT",frame,"TOPLEFT",6+data[2]*19,12)
            icon:Hide()
            frame.indicators[id]=icon
        end
        frame.indicators.raid:SetTexCoord(0,.25,0,.25)
    end
    if kind=="party" then
        local level=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        level:SetPoint("BOTTOM",frame,"TOP",0,1)
        frame.levelText=level
        local classification=frame:CreateTexture(nil,"OVERLAY")
        classification:SetSize(23,23)
        classification:SetPoint("TOPRIGHT",frame,"TOPRIGHT",6,10)
        classification:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged")
        classification:Hide()
        frame.classificationIcon=classification
    end
    frame.unitToken = unit
    frame.hp,frame.power,frame.label,frame.portrait = hp,power,name,portrait
    frame:Hide()
    return frame
end
local function layoutMember(f, kind, index, opt)
    local width = math.max(80,math.min(400,tonumber(opt.width) or tonumber(opt.barWidth) or (kind=="party" and 190 or 110)))
    local height = math.max(22,math.min(90,tonumber(opt.height) or (kind=="party" and 48 or 30)))
    f:SetSize(width,height)
    local portrait = f.portrait
    local portraitSize=math.max(24,math.min(90,tonumber(opt.portraitSize) or (height-6)))
    local side = opt.portraitSide or (index <= 2 and "LEFT" or "RIGHT")
    if portrait then
        portrait:ClearAllPoints()
        local px=tonumber(opt.portraitX) or 0
        local py=tonumber(opt.portraitY) or 0
        portrait:SetPoint(side,f,side,(side=="LEFT" and 3 or -3)+px,py)
        portrait:SetSize(portraitSize,portraitSize)
        portrait:SetShown(opt.showPortrait ~= false)
        f.rim:SetSize(portraitSize*62/48,portraitSize*62/48)
        f.rim:SetShown(opt.showPortrait ~= false)
    end
    f.hp:ClearAllPoints()
    f.hp:SetPoint("TOPLEFT",f,"TOPLEFT",portrait and opt.showPortrait ~= false and (side=="LEFT" and portraitSize+6 or 5) or 5,-5)
    f.hp:SetPoint("TOPRIGHT",f,"TOPRIGHT",portrait and opt.showPortrait ~= false and (side=="RIGHT" and -(portraitSize+6) or -5) or -5,-5)
    f.hp:SetHeight(math.max(12,tonumber(opt.hpHeight) or (height-12)*.72))
    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT",f.hp,"BOTTOMLEFT",0,-2)
    f.power:SetPoint("TOPRIGHT",f.hp,"BOTTOMRIGHT",0,-2)
    f.power:SetHeight(math.max(4,tonumber(opt.powerHeight) or (height-12)*.28))
    f.label:ClearAllPoints()
    f.label:SetPoint("CENTER",f.hp,"CENTER")
    local font,size,flags = f.label:GetFont()
    if font then f.label:SetFont(font,math.max(1,tonumber(opt.fontSize) or 11),flags) end
    local hpMode=opt.hpText or (opt.showHealthPercent and "percent" or "none")
    local powerMode=opt.powerText or (opt.showPowerPercent and "percent" or "none")
    f.hpText:SetShown(hpMode~="none" and hpMode~="hide" and hpMode~="off")
    f.powerText:SetShown(powerMode~="none" and powerMode~="hide" and powerMode~="off" and opt.showPower~=false)
    if f.levelText then
        f.levelText:SetShown(opt.showLevel~=false)
        local font=select(1,f.levelText:GetFont())
        if font then f.levelText:SetFont(font,math.max(1,tonumber(opt.levelFontSize) or 11),"OUTLINE") end
    end
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
        f:SetPoint("TOPLEFT",UIParent,"TOP",-(total/2)+offset+(tonumber(opt.offsetX) or 0), (tonumber(opt.y) or -45)+(tonumber(opt.offsetY) or 0))
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
-- Blizzard's AuraContainer owns protected aura data. This code never inspects aura payloads.
local function ensureGroupAuras(f,kind,index)
    if kind~="party" or f.groupAuras then return end
    if C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer")
        and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn,"Blizzard_AuraContainer")
    end
    f.groupAuras={}
    for _,auraKind in ipairs({"buffs","debuffs"}) do
        local opt=effectiveOptions(config(kind),index)["aura_"..auraKind] or {}
        local ok,container=pcall(CreateFrame,"AuraContainer",nil,f,"CustomAuraContainerTemplate")
        if ok and container and type(container.AddAuraGroup)=="function" then
            local size=math.max(12,math.min(48,tonumber(opt.size) or 24))
            local gap=math.max(0,math.min(20,tonumber(opt.spacing) or 2))
            local count=math.max(1,math.min(40,tonumber(opt.count) or 12))
            local settings={
                maxFrameCount=count,candidateFilters={},
                initializeFrame=function(button)
                    button:SetSize(size,size)
                    local icon=button:CreateTexture(nil,"ARTWORK")
                    icon:SetAllPoints()
                    icon:SetTexCoord(.08,.92,.08,.92)
                    local border=CreateFrame("Frame",nil,button,"BackdropTemplate")
                    border:SetAllPoints()
                    border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=6})
                    border:SetBackdropBorderColor(.48,.34,.18,.95)
                    local countText=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                    countText:SetPoint("BOTTOMRIGHT",-1,1)
                    local duration=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                    duration:SetPoint("CENTER")
                    if auraKind=="buffs" then duration:SetAlpha(0) end
                    local cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
                    cooldown:SetAllPoints()
                    cooldown:SetHideCountdownNumbers(true)
                    if button.SetIcon then pcall(button.SetIcon,button,icon) end
                    if button.SetApplicationCount then pcall(button.SetApplicationCount,button,countText,{}) end
                    if button.SetDurationText then pcall(button.SetDurationText,button,duration) end
                    if button.SetDurationCooldown then pcall(button.SetDurationCooldown,button,cooldown) end
                end,
                layout={elementWidth=size,elementHeight=size,elementSpacing=gap,lineSpacing=gap,groupSpacing=gap,groupLineSpacing=gap},
            }
            local added=pcall(container.AddAuraGroup,container,auraKind,auraKind=="buffs" and "HELPFUL" or "HARMFUL",settings)
            if added then
                pcall(container.SetUnit,container,f.unitToken)
                f.groupAuras[auraKind]=container
            else
                container:Hide()
            end
        end
    end
end
local function layoutGroupAuras(f,kind,index,preview)
    if not f.groupAuras then return end
    local settings=effectiveOptions(config(kind),index)
    for _,auraKind in ipairs({"buffs","debuffs"}) do
        local container=f.groupAuras[auraKind]
        if container then
            local opt=settings["aura_"..auraKind] or {}
            local enabled=opt.enabled==true and not preview
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT",f,"TOPLEFT",tonumber(opt.x) or 0,tonumber(opt.y) or (auraKind=="buffs" and 32 or -58))
            if container.SetEnabled then pcall(container.SetEnabled,container,enabled) end
            container:SetShown(enabled)
            if enabled and container.UpdateAllAuras then pcall(container.UpdateAllAuras,container) end
        end
    end
end
-- Visual-only solo samples. Never reassign secure unit attributes or fabricate live auras.
local partySamples={
    {name="Ironshield",role="TANK",class="WARRIOR",hp=92,power=45,resource="RAGE",icon="Ability_Warrior_DefensiveStance",buffs={"Spell_Holy_DevotionAura","Ability_Warrior_BattleShout"},debuffs={}},
    {name="Lightweaver",role="HEALER",class="PRIEST",hp=68,power=82,resource="MANA",icon="Spell_Holy_GreaterHeal",buffs={"Spell_Holy_PowerWordShield","Spell_Holy_Renew"},debuffs={"Spell_Shadow_ShadowWordPain"}},
    {name="Shadowstep",role="DAMAGER",class="ROGUE",hp=100,power=35,resource="ENERGY",icon="Ability_Rogue_SinisterCalling",buffs={"Ability_Rogue_SliceDice"},debuffs={}},
    {name="Stormcaller",role="DAMAGER",class="MAGE",hp=43,power=61,resource="MANA",icon="Spell_Frost_FrostBolt02",buffs={"Spell_Holy_MagicalSentry"},debuffs={"Spell_Fire_Fireball02"}},
}
local function sampleFor(f)
    return partySamples[tonumber(f.unitToken:match("%d+")) or 1] or partySamples[1]
end
local function previewAuras(f,kind,index,enabled)
    if kind~="party" then return end
    if not f.sampleAuras then
        f.sampleAuras={}
        for _,auraKind in ipairs({"buffs","debuffs"}) do
            local tiles={}
            for i=1,5 do
                local icon=f:CreateTexture(nil,"OVERLAY")
                icon:SetTexCoord(.08,.92,.08,.92)
                icon:Hide()
                tiles[i]=icon
            end
            f.sampleAuras[auraKind]=tiles
        end
    end
    local sample=partySamples[index]
    local settings=effectiveOptions(config(kind),index)
    for _,auraKind in ipairs({"buffs","debuffs"}) do
        local opt=settings["aura_"..auraKind] or {}
        local tiles=f.sampleAuras[auraKind]
        local icons=sample[auraKind]
        local size=math.max(12,math.min(48,tonumber(opt.size) or 24))
        local gap=math.max(0,math.min(20,tonumber(opt.spacing) or 2))
        for i,tile in ipairs(tiles) do
            local visible=enabled and opt.enabled~=false and i<=math.min(tonumber(opt.count) or 12,#icons)
            if visible then
                tile:SetTexture("Interface\\Icons\\"..icons[i])
                tile:SetSize(size,size)
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT",f,"TOPLEFT",(tonumber(opt.x) or 0)+(i-1)*(size+gap),(tonumber(opt.y) or (auraKind=="buffs" and 32 or -58)))
            end
            tile:SetShown(visible)
        end
    end
end
local function updatePartyIndicators(f,preview)
    if not f.indicators then return end
    local unit=f.unitToken
    local opt=effectiveOptions(config("party"),tonumber(unit:match("%d+")) or 1)
    local function safe(value)
        if issecretvalue and issecretvalue(value) then return nil end
        return value
    end
    local sample=preview and sampleFor(f)
    local marker=not preview and GetRaidTargetIndex and safe(GetRaidTargetIndex(unit))
    f.indicators.raid:SetShown(opt.showRaidMarker~=false and (preview or type(marker)=="number"))
    if type(marker)=="number" and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(f.indicators.raid,marker)
    end
    f.indicators.pvp:SetShown(opt.showPvP~=false and not preview and safe(UnitIsPVP(unit))==true)
    f.indicators.leader:SetShown(opt.showLeader~=false and ((preview and tonumber(unit:match("%d+"))==1) or (not preview and UnitIsGroupLeader and safe(UnitIsGroupLeader(unit))==true)))
    local role=preview and sample.role or (UnitGroupRolesAssigned and safe(UnitGroupRolesAssigned(unit)))
    f.indicators.role:SetShown(opt.showRole~=false and (role=="TANK" or role=="HEALER" or role=="DAMAGER"))
    if preview then
        local coords={TANK={0,.25,.25,.5},HEALER={.25,.5,0,.25},DAMAGER={.25,.5,.25,.5}}
        local c=coords[role]
        if c then f.indicators.role:SetTexCoord(c[1],c[2],c[3],c[4]) end
    end
    if f.classificationIcon then
        local classification=not preview and UnitClassification and safe(UnitClassification(unit))
        local special=classification=="elite" or classification=="rare" or classification=="rareelite" or classification=="worldboss"
        f.classificationIcon:SetShown(opt.showClassification~=false and special)
    end
end
local function updateMember(f, preview)
    updatePartyIndicators(f,preview)
    if preview then
        local sample=sampleFor(f)
        f.hp:SetMinMaxValues(0,100)
        f.hp:SetValue(sample.hp)
        f.power:SetMinMaxValues(0,100)
        f.power:SetValue(sample.power)
        f.label:SetText(sample.name)
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[sample.class] then
            local c=RAID_CLASS_COLORS[sample.class]
            f.label:SetTextColor(c.r,c.g,c.b)
        else f.label:SetTextColor(1,.82,0) end
        if f.levelText then f.levelText:SetText("60") end
        local opt=effectiveOptions(config("party"),tonumber(f.unitToken:match("%d+")) or 1)
        f.hpText:SetText(sample.hp.."%")
        f.powerText:SetText(sample.power.."%")
        f.power:SetStatusBarColor(sample.resource=="RAGE" and .85 or .2,sample.resource=="ENERGY" and .8 or .4,sample.resource=="MANA" and .9 or .2)
        if f.portrait then f.portrait:SetTexture("Interface\\Icons\\"..sample.icon) end
        return
    end
    if not UnitExists(f.unitToken) then return end
    f.label:SetTextColor(1,.82,0)
    f.power:SetStatusBarColor(.29,.43,.70)
    f.hp:SetMinMaxValues(0,UnitHealthMax(f.unitToken))
    f.hp:SetValue(UnitHealth(f.unitToken))
    f.power:SetMinMaxValues(0,UnitPowerMax(f.unitToken))
    f.power:SetValue(UnitPower(f.unitToken))
    f.label:SetText(UnitName(f.unitToken) or "")
    if f.levelText then f.levelText:SetText(UnitLevel(f.unitToken)) end
    -- Forward protected numbers directly to Blizzard StatusBars. Never calculate with secrets.
    -- Text remains hidden unless an unprotected numeric value can be read safely.
    local index=tonumber(f.unitToken:match("%d+"))
    local opt=index and effectiveOptions(config("party"),index) or {}
    local function textFor(mode,current,maximum)
        if issecretvalue and (issecretvalue(current) or issecretvalue(maximum)) then return "" end
        if type(current)~="number" or type(maximum)~="number" then return "" end
        if mode=="percent" then return maximum>0 and (math.floor(current/maximum*100+.5).."%") or "0%" end
        if mode=="current" or mode=="value" then return tostring(math.floor(current)) end
        if mode=="currentmax" or mode=="current/max" then return math.floor(current).."/"..math.floor(maximum) end
        return ""
    end
    f.hpText:SetText(textFor(opt.hpText or (opt.showHealthPercent and "percent"),UnitHealth(f.unitToken),UnitHealthMax(f.unitToken)))
    f.powerText:SetText(textFor(opt.powerText or (opt.showPowerPercent and "percent"),UnitPower(f.unitToken),UnitPowerMax(f.unitToken)))
    if f.portrait then SetPortraitTexture(f.portrait,f.unitToken) end
end
function M:Refresh()
    if addon.PartyFrames then addon.PartyFrames:Refresh() end
    if safeCombat() then return end
    for _,kind in ipairs({"raid","boss"}) do
        local opt = config(kind)
        if opt then
            groups[kind] = groups[kind] or {}
            local count = kind=="party" and 4 or (kind=="boss" and 5 or 40)
            if opt.enabled then
                for i=1,count do
                    local f = groups[kind][i]
                    if not f then f=createMember(kind,i);groups[kind][i]=f end
                    layoutMember(f,kind,i,effectiveOptions(opt,i))
                    if kind=="party" then ensureGroupAuras(f,kind,i) end
                    local preview = opt.showSolo and (kind=="boss" or not IsInGroup())
                    local exists = UnitExists(f.unitToken)
                    -- Secure unit frames are not reconfigured in combat.
                    f:SetShown(preview or exists == true)
                    if preview or exists == true then updateMember(f,preview) end
                    if kind=="party" then
                        layoutGroupAuras(f,kind,i,preview)
                        previewAuras(f,kind,i,preview)
                    end
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
    if addon.PartyFrames then addon.PartyFrames:Initialize() end
    local events=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PLAYER_REGEN_ENABLED","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_NAME_UPDATE","UNIT_AURA","RAID_TARGET_UPDATE","PLAYER_ROLES_ASSIGNED","UNIT_FLAGS"}) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent",function() M:Refresh() end)
    self:Refresh()
end
