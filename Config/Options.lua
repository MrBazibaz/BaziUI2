local addon = BaziUI
addon.Options = addon.Options or {}
local ASSET = "Interface\\AddOns\\BaziUI\\Assets\\"
local frame, content, pages = nil, nil, {}
local pageScrolls = {}
local navigation, tabs = {}, {}
local GOLD = {0.87, 0.68, 0.38}
local function Paint(parent, layer, r,g,b,a, x1,y1,x2,y2)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND")
    t:SetColorTexture(r,g,b,a or 1)
    if x1 then t:SetPoint("TOPLEFT",parent,"TOPLEFT",x1,y1);t:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",x2,y2) else t:SetAllPoints(parent) end
    return t
end
local function Label(parent,text,size,r,g,b)
    local f=parent:CreateFontString(nil,"OVERLAY",size or "GameFontNormal")
    f:SetText(text);f:SetTextColor(r or GOLD[1],g or GOLD[2],b or GOLD[3]);f:SetJustifyH("LEFT")
    return f
end
local function Line(parent,top,xleft,xright)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",xleft or 0,top)
    t:SetPoint("TOPRIGHT",parent,"TOPRIGHT",xright or 0,top)
    t:SetHeight(1);t:SetColorTexture(0.67,0.48,0.25,0.48)
end
local function Panel(parent,x,y,w,h)
    local p=CreateFrame("Frame",nil,parent)
    p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);p:SetSize(w,h)
    Paint(p,"BACKGROUND",0.105,0.075,0.115,0.96)
    local art=p:CreateTexture(nil,"BORDER");art:SetAllPoints(p)
    art:SetTexture(ASSET.."Panels\\Panel_Dark.png");art:SetAlpha(0.14)
    Line(p,0,0,0)
    return p
end
local function Button(parent,text,x,y,w,h,action)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h)
    local bg=Paint(b,"BACKGROUND",0.17,0.105,0.19,0.92)
    local title=Label(b,text,"GameFontNormalSmall",0.87,0.78,0.64)
    title:SetPoint("CENTER")
    b:SetScript("OnEnter",function()bg:SetColorTexture(0.29,0.17,0.34,1);title:SetTextColor(1,0.85,0.53)end)
    b:SetScript("OnLeave",function()bg:SetColorTexture(0.17,0.105,0.19,0.92);title:SetTextColor(0.87,0.78,0.64)end)
    b:SetScript("OnClick",action)
    return b
end
local function Page(name)
    local viewport=CreateFrame("ScrollFrame",nil,content)
    viewport:SetAllPoints(content)
    viewport:EnableMouseWheel(true)
    local p=CreateFrame("Frame",nil,viewport)
    p:SetSize(730,600)
    viewport:SetScrollChild(p)
    viewport:SetScript("OnMouseWheel",function(self,delta)
        local maxScroll=math.max(0,p:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(maxScroll,self:GetVerticalScroll()-delta*38)))
    end)
    viewport:Hide()
    pages[name]=viewport
    pageScrolls[name]=p
    return p
end
local function Show(name)
    for k,p in pairs(pages) do p:SetShown(k==name); if k==name then p:SetVerticalScroll(0) end end
    for k,b in pairs(navigation) do
        b.bg:SetColorTexture(k==name and 0.31 or 0.13,k==name and 0.17 or 0.095,k==name and 0.35 or 0.15,0.98)
        b.accent:SetAlpha(k==name and 1 or 0)
        b.label:SetTextColor(k==name and 1 or 0.73,k==name and 0.83 or 0.69,k==name and 0.52 or 0.68)
    end
    for k,b in pairs(tabs) do b.active:SetAlpha(k==name and 1 or 0) end
end
local function Slider(parent,title,subtitle,y,minv,maxv,step,value,change)
    local row=Panel(parent,22,y,684,65)
    local name=Label(row,title,"GameFontNormal",0.94,0.81,0.58)
    name:SetPoint("TOPLEFT",row,"TOPLEFT",17,-12)
    local desc=Label(row,subtitle,"GameFontHighlightSmall",0.66,0.64,0.69)
    desc:SetPoint("TOPLEFT",row,"TOPLEFT",17,-35)
    local readout=Label(row,"","GameFontNormal",1,0.82,0.49)
    readout:SetPoint("RIGHT",row,"RIGHT",-17,0)
    local slider=CreateFrame("Slider",nil,row)
    slider:SetSize(148,20);slider:SetPoint("RIGHT",row,"RIGHT",-65,0)
    slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(minv,maxv);slider:SetValueStep(step)
    local track=slider:CreateTexture(nil,"BACKGROUND");track:SetTexture(ASSET.."Sliders\\Slider_Track.png")
    track:SetPoint("LEFT");track:SetPoint("RIGHT");track:SetHeight(8)
    local progress=slider:CreateTexture(nil,"BORDER");progress:SetTexture(ASSET.."Sliders\\Slider_Fill_Gold.png")
    progress:SetPoint("LEFT",slider,"LEFT",0,0);progress:SetHeight(8)
    local thumb=slider:CreateTexture(nil,"OVERLAY");thumb:SetTexture(ASSET.."Sliders\\Slider_Gem.png");thumb:SetSize(25,28)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged",function(_,raw)
        local v=math.floor(raw/step+0.5)*step
        readout:SetText(string.format("%g",v))
        progress:SetWidth(math.max(1,148*(v-minv)/(maxv-minv)))
        if change then change(v) end
    end)
    slider:SetValue(value)
end
local function Section(parent,name,y)
    local h=Label(parent,name,"GameFontNormalLarge",0.98,0.80,0.47)
    h:SetPoint("TOPLEFT",parent,"TOPLEFT",24,y)
    Line(parent,y-26,22,-22)
end
local function General()
    local p=Page("General")
    local hero=Panel(p,12,-8,704,112)
    local glow=Paint(hero,"BORDER",0.21,0.115,0.31,0.75,1,-1,-1,1)
    local crest=hero:CreateTexture(nil,"ARTWORK");crest:SetTexture(ASSET.."Icons\\BaziUI_Emblem_256.png")
    crest:SetSize(80,80);crest:SetPoint("RIGHT",hero,"RIGHT",-18,0);crest:SetAlpha(0.50)
    local h=Label(hero,"Realm Configuration","GameFontNormalHuge",1,0.83,0.52)
    h:SetPoint("TOPLEFT",hero,"TOPLEFT",23,-23)
    local sub=Label(hero,"Make Azeroth yours. Fine-tune your interface.","GameFontHighlight",0.85,0.76,0.81)
    sub:SetPoint("TOPLEFT",hero,"TOPLEFT",24,-67)
    local settings=Panel(p,12,-133,704,320)
    Section(settings,"Appearance",-19)
    local db=addon.db.profile
    Slider(settings,"Window Scale","Size of the Bazi UI settings window",-59,0.70,1.20,0.01,db.uiScale,function(v)
        db.uiScale=v;if frame then frame:SetScale(v) end
    end)
    Slider(settings,"Font Size","Default text size for supported modules",-136,10,20,1,db.fontSize,function(v)db.fontSize=v end)
end
local function Placeholder(name,description)
    local p=Page(name)
    local panel=Panel(p,12,-8,704,168)
    Section(panel,name,-23)
    local txt=Label(panel,description or "Module settings will appear here as development continues.","GameFontHighlight",0.81,0.75,0.81)
    txt:SetPoint("TOPLEFT",panel,"TOPLEFT",25,-76)
end
local function Nav(parent,name,icon,y)
    local b=CreateFrame("Button",nil,parent);b:SetSize(206,30)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",9,y)
    b.bg=Paint(b,"BACKGROUND",0.13,0.095,0.15,0.98)
    b.accent=Paint(b,"ARTWORK",0.91,0.66,0.30,1)
    b.accent:ClearAllPoints();b.accent:SetPoint("TOPLEFT");b.accent:SetPoint("BOTTOMLEFT");b.accent:SetWidth(3)
    b.label=Label(b,icon.."  "..name,"GameFontNormal",0.73,0.69,0.68)
    b.label:SetPoint("LEFT",b,"LEFT",15,0)
    b:SetScript("OnEnter",function()if not pages[name]:IsShown() then b.bg:SetColorTexture(0.24,0.14,0.27,1)end end)
    b:SetScript("OnLeave",function()if not pages[name]:IsShown() then b.bg:SetColorTexture(0.13,0.095,0.15,0.98)end end)
    b:SetScript("OnClick",function()Show(name)end)
    navigation[name]=b
end
local function Tab(parent,name,x,w)
    local b=CreateFrame("Button",nil,parent);b:SetSize(w,35)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-51)
    local label=Label(b,name,"GameFontNormalSmall",0.87,0.78,0.67);label:SetPoint("CENTER")
    b.active=Paint(b,"ARTWORK",0.90,0.66,0.33,1)
    b.active:ClearAllPoints();b.active:SetPoint("BOTTOMLEFT");b.active:SetPoint("BOTTOMRIGHT");b.active:SetHeight(2)
    b:SetScript("OnClick",function()Show(name)end);tabs[name]=b
end
function addon.Options:Create()
    frame=CreateFrame("Frame","BaziUIOptionsFrame",UIParent)
    frame:SetSize(1020,680);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true);frame:SetMovable(true);frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton");frame:SetScript("OnDragStart",frame.StartMoving)
    frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    frame:SetScale(addon.db.profile.uiScale or 1)
    Paint(frame,"BACKGROUND",0.055,0.043,0.074,0.99)
    -- V7 modular ornamental frame: independent corners and stretchable edge tiles.
    -- Artwork is drawn above the panels but below interactive controls.
    local BORDER_ASSET = ASSET.."Borders"..string.char(92)
    local function BorderPiece(file, width, height, point, x, y, secondPoint, x2, y2)
        local tex=frame:CreateTexture(nil,"OVERLAY",nil,1)
        tex:SetTexture(BORDER_ASSET..file)
        tex:SetPoint(point,frame,point,x or 0,y or 0)
        if secondPoint then
            tex:SetPoint(secondPoint,frame,secondPoint,x2 or 0,y2 or 0)
            if height then tex:SetHeight(height) else tex:SetWidth(width) end
        else
            tex:SetSize(width,height)
        end
        return tex
    end
    -- Straight edge pieces are stretched between the corner ornaments.
    BorderPiece("Edge_Top_Tile.tga",nil,12,"TOPLEFT",44,0,"TOPRIGHT",-44,0)
    BorderPiece("Edge_Bottom_Tile.tga",nil,12,"BOTTOMLEFT",44,0,"BOTTOMRIGHT",-44,0)
    BorderPiece("Edge_Left.tga",12,nil,"TOPLEFT",0,-44,"BOTTOMLEFT",0,44)
    BorderPiece("Edge_Right.tga",12,nil,"TOPRIGHT",0,-44,"BOTTOMRIGHT",0,44)
    BorderPiece("Corner_TL.tga",44,44,"TOPLEFT",0,0)
    BorderPiece("Corner_TR.tga",44,44,"TOPRIGHT",0,0)
    BorderPiece("Corner_BL.tga",44,44,"BOTTOMLEFT",0,0)
    BorderPiece("Corner_BR.tga",44,44,"BOTTOMRIGHT",0,0)
    local header=Paint(frame,"BORDER",0.09,0.063,0.11,0.99,3,-3,-3,-93)
    local emblem=frame:CreateTexture(nil,"OVERLAY");emblem:SetTexture(ASSET.."Icons\\BaziUI_Emblem_256.png")
    emblem:SetSize(70,70);emblem:SetPoint("TOPLEFT",frame,"TOPLEFT",13,12)
    local title=Label(frame,"Bazi UI","GameFontNormalHuge",1,0.83,0.53)
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",85,-16)
    local version=Label(frame,"REFORGED  /  V7 PREVIEW","GameFontNormalSmall",0.64,0.58,0.66)
    version:SetPoint("TOPLEFT",frame,"TOPLEFT",87,-45)
    local close=Button(frame,"X",977,-12,28,27,function()frame:Hide()end)
    close:SetFrameLevel(frame:GetFrameLevel()+5)
    Line(frame,-93,11,-11)
    -- Fixed navigation: every category remains visible without scrolling.
    local sidebar=Panel(frame,10,-103,230,542)
    local navBody=CreateFrame("Frame",nil,sidebar)
    navBody:SetPoint("TOPLEFT",sidebar,"TOPLEFT",4,-7)
    navBody:SetSize(222,530)
    local function Category(name,y)
        local h=Label(navBody,name,"GameFontNormalSmall",0.83,0.62,0.34)
        h:SetPoint("TOPLEFT",navBody,"TOPLEFT",15,y)
    end
    Category("GENERAL",-9)
    Category("GAMEPLAY",-153)
    Category("INTERFACE",-323)
    content=CreateFrame("Frame",nil,frame);content:SetPoint("TOPLEFT",frame,"TOPLEFT",255,-104)
    content:SetSize(748,542)
    General()
    local others={"Profiles","Import / Export","What's New","Appearance","Char","UnitFrames","Nameplates","ActionBars","Chat","Quest","Gathering","Minimap","Tooltip","Combat","BugTab","QoL Settings"}
    for _,name in ipairs(others) do Placeholder(name) end
    Tab(frame,"General",249,87);Tab(frame,"Profiles",340,86)
    Tab(frame,"Import / Export",430,121);Tab(frame,"What's New",555,102)
    Nav(navBody,"General","*", -30)
    Nav(navBody,"Appearance","o",-61)
    Nav(navBody,"QoL Settings","+",-92)
    Nav(navBody,"BugTab","*",-123)
    Nav(navBody,"ActionBars","#",-175)
    Nav(navBody,"Chat",">",-206)
    Nav(navBody,"Quest","?",-237)
    Nav(navBody,"Gathering","^",-268)
    Nav(navBody,"Combat","!",-299)
    Nav(navBody,"Char","@",-350)
    Nav(navBody,"Minimap","@",-381)
    Nav(navBody,"Tooltip","i",-412)
    Nav(navBody,"UnitFrames","+",-443)
    Nav(navBody,"Nameplates","o",-474)
    Line(frame,-650,16,-16)
    local footer=Label(frame,"BAZI UI  |  Changes are saved automatically","GameFontNormalSmall",0.71,0.63,0.61)
    footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",23,15)
    local stage=Label(frame,"V7 DEVELOPMENT BUILD","GameFontNormalSmall",0.76,0.58,0.37)
    stage:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-20,15)
    Show("General")
    frame:Hide()
end
function addon.Options:Open()
    if not frame then self:Create() end
    frame:Show();frame:Raise()
end
function addon.Options:Initialize() end
