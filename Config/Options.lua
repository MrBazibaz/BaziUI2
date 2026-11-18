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
    p:SetSize(850,640)
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
    local row=Panel(parent,22,y,804,65)
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
    local hero=Panel(p,12,-8,824,112)
    local glow=Paint(hero,"BORDER",0.21,0.115,0.31,0.75,1,-1,-1,1)
    local crest=hero:CreateTexture(nil,"ARTWORK");crest:SetTexture(ASSET.."Icons\\BaziUI_Emblem_256.png")
    crest:SetSize(80,80);crest:SetPoint("RIGHT",hero,"RIGHT",-18,0);crest:SetAlpha(0.50)
    local h=Label(hero,"Realm Configuration","GameFontNormalHuge",1,0.83,0.52)
    h:SetPoint("TOPLEFT",hero,"TOPLEFT",23,-23)
    local sub=Label(hero,"Make Azeroth yours. Fine-tune your interface.","GameFontHighlight",0.85,0.76,0.81)
    sub:SetPoint("TOPLEFT",hero,"TOPLEFT",24,-67)
    local settings=Panel(p,12,-133,824,320)
    Section(settings,"Appearance",-19)
    local db=addon.db.profile
    Slider(settings,"Window Scale","Size of the Bazi UI settings window",-59,0.70,1.20,0.01,db.uiScale,function(v)
        db.uiScale=v;if frame then frame:SetScale(v);if frame.baziShadowFrame then frame.baziShadowFrame:SetScale(v) end end
    end)
    Slider(settings,"Font Size","Default text size for supported modules",-136,10,20,1,db.fontSize,function(v)db.fontSize=v end)
end
local function Placeholder(name,description)
    local p=Page(name)
    local panel=Panel(p,12,-8,824,168)
    Section(panel,name,-23)
    local txt=Label(panel,description or "Module settings will appear here as development continues.","GameFontHighlight",0.81,0.75,0.81)
    txt:SetPoint("TOPLEFT",panel,"TOPLEFT",25,-76)
end
local function Nav(parent,name,icon,y)
    local b=CreateFrame("Button",nil,parent);b:SetSize(214,30)
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
    frame:SetSize(1140,740);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true);frame:SetMovable(true);frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton");frame:SetScript("OnDragStart",frame.StartMoving)
    frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    frame:SetScale(addon.db.profile.uiScale or 1)
    -- TEMP VISUAL TEST: show the known-working 9-slice shadow IN FRONT
    -- of Bazi UI, aligned with its frame bounds for easy inspection.
    local shadowFile=ASSET.."Effects\\Window_Shadow.png"
    local shadowSize=36
    local shadowFrame=CreateFrame("Frame","BaziUIWindowShadow",UIParent)
    shadowFrame:SetFrameStrata("TOOLTIP")
    shadowFrame:SetFrameLevel(100)
    shadowFrame:SetScale(frame:GetScale())
    shadowFrame:SetSize(1180,780)
    shadowFrame:SetPoint("CENTER",frame,"CENTER",0,0)
    shadowFrame:EnableMouse(false)
    local cuts={0,23/128,105/128,1}
    local shadowPieces={}
    for row=1,3 do
        shadowPieces[row]={}
        for col=1,3 do
            if row~=2 or col~=2 then
                local piece=shadowFrame:CreateTexture(nil,"ARTWORK")
                piece:SetTexture(shadowFile)
                piece:SetTexCoord(cuts[col],cuts[col+1],cuts[row],cuts[row+1])
                shadowPieces[row][col]=piece
            end
        end
    end
    -- Live calibration bounds relative to the Bazi UI frame center.
    -- Changes are temporary until the chosen values are committed.
    local shadowBounds={left=-590,right=590,top=390,bottom=-390}
    local function UpdateShadowBounds()
        local w=shadowBounds.right-shadowBounds.left
        local h=shadowBounds.top-shadowBounds.bottom
        if w<=shadowSize*2 or h<=shadowSize*2 then return false end
        shadowFrame:ClearAllPoints()
        shadowFrame:SetPoint("TOPLEFT",frame,"CENTER",shadowBounds.left,shadowBounds.top)
        shadowFrame:SetSize(w,h)
        local widths={shadowSize,w-2*shadowSize,shadowSize}
        local heights={shadowSize,h-2*shadowSize,shadowSize}
        local xs={0,shadowSize,w-shadowSize}
        local ys={0,shadowSize,h-shadowSize}
        for row=1,3 do
            for col=1,3 do
                local piece=shadowPieces[row][col]
                if piece then
                    piece:ClearAllPoints()
                    piece:SetPoint("TOPLEFT",shadowFrame,"TOPLEFT",xs[col],-ys[row])
                    piece:SetSize(widths[col],heights[row])
                end
            end
        end
        return true
    end
    frame.baziShadowBounds=shadowBounds
    frame.baziUpdateShadowBounds=UpdateShadowBounds
    UpdateShadowBounds()
    -- TEMP DIAGNOSTIC: cyan outline = actual shadow-frame bounds.
    -- Gold artwork remains unchanged. Remove after alignment is verified.
    local function ShadowGuide(pointA,pointB,width,height)
        local t=shadowFrame:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0,1,1,1)
        t:SetPoint(pointA,shadowFrame,pointA,0,0)
        t:SetPoint(pointB,shadowFrame,pointB,0,0)
        if width then t:SetWidth(width) else t:SetHeight(height) end
    end
    ShadowGuide("TOPLEFT","TOPRIGHT",nil,2)
    ShadowGuide("BOTTOMLEFT","BOTTOMRIGHT",nil,2)
    ShadowGuide("TOPLEFT","BOTTOMLEFT",2,nil)
    ShadowGuide("TOPRIGHT","BOTTOMRIGHT",2,nil)
    frame.baziShadowFrame=shadowFrame
    frame:HookScript("OnShow",function()shadowFrame:Show()end)
    frame:HookScript("OnHide",function()shadowFrame:Hide()end)
    shadowFrame:Hide()
    -- A fully opaque fill is essential: transparent ornamental corner TGAs
    -- must not reveal the game world through large square holes.
    Paint(frame,"BACKGROUND",0.055,0.043,0.074,1)
    -- The opaque window fill stops at the frame boundary. Extending it outward
    -- created the conspicuous plum rectangle visible behind the border.
    -- V7 modular ornamental frame: independent corners and stretchable edge tiles.
    -- Artwork is drawn above the panels but below interactive controls.
    local BORDER_ASSET = ASSET.."Borders"..string.char(92)
    local BORDER_OUTSET=0
    local function BorderAnchorOffset(point)
        local dx=point:find("LEFT") and -BORDER_OUTSET or (point:find("RIGHT") and BORDER_OUTSET or 0)
        local dy=point:find("TOP") and BORDER_OUTSET or (point:find("BOTTOM") and -BORDER_OUTSET or 0)
        return dx,dy
    end
    local function BorderPiece(file, width, height, point, x, y, secondPoint, x2, y2)
        local tex=frame:CreateTexture(nil,"OVERLAY",nil,1)
        tex:SetTexture(BORDER_ASSET..file)
        local dx,dy=BorderAnchorOffset(point)
        tex:SetPoint(point,frame,point,(x or 0)+dx,(y or 0)+dy)
        if secondPoint then
            local dx2,dy2=BorderAnchorOffset(secondPoint)
            tex:SetPoint(secondPoint,frame,secondPoint,(x2 or 0)+dx2,(y2 or 0)+dy2)
            if height then tex:SetHeight(height) else tex:SetWidth(width) end
        else
            tex:SetSize(width,height)
        end
        return tex
    end
    -- V7 border test: measured TGA geometry, fixed-size repeated tiles.
    -- Top corners: 8 UI outward; bottom corners: 10 UI outward.
    -- Edge placement is a test, not yet a verified final seam.
    local CORNER_TOP_OUTSET=8
    local CORNER_BOTTOM_OUTSET=10
    local EDGE_TOP_OUTSET=8
    local EDGE_BOTTOM_OUTSET=10
    local EDGE_SIDE_OUTSET=8
    local BORDER_TEST_TILE=112
    -- Live edge calibration, kept separate from the four corner textures.
    frame.baziEdgePieces={top={},bottom={},left={},right={}}
    local function RegisterEdge(side,texture,x,y)
        local pieces=frame.baziEdgePieces[side]
        pieces[#pieces+1]={texture=texture,x=x,y=y}
    end
    local function TiledHorizontal(side, file, y, fromX, toX, height)
        -- The new seamless horizontal TGAs are 32px wide; the legacy
        -- artwork was displayed as 112-unit tiles.
        local tileLength=(file=="Edge_Top.tga" or file=="Edge_Bottom.tga") and 32 or BORDER_TEST_TILE
        local count=math.ceil((toX-fromX)/tileLength)
        for i=0,count-1 do
            local x=fromX+i*tileLength
            local width=math.min(tileLength,toX-x)
            local t=frame:CreateTexture(nil,"OVERLAY",nil,0)
            t:SetTexture(BORDER_ASSET..file)
            t:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y)
            RegisterEdge(side,t,x,y)
            t:SetSize(width,height)
            -- Crop only the final partial tile, never stretch it.
            t:SetTexCoord(0,width/tileLength,0,1)
        end
    end
    local function TiledVertical(side, file, x, topY, bottomY, width)
        local total=topY-bottomY
        -- Seamless side strips are 16px tall. Keep each tile short so the
        -- artwork repeats without stretching a single strip over 112 units.
        local tileLength=(file=="Edge_Left.tga" or file=="Edge_Right.tga") and 16 or BORDER_TEST_TILE
        local count=math.ceil(total/tileLength)
        for i=0,count-1 do
            local y=topY-i*tileLength
            local height=math.min(tileLength,y-bottomY)
            local t=frame:CreateTexture(nil,"OVERLAY",nil,0)
            t:SetTexture(BORDER_ASSET..file)
            t:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y)
            RegisterEdge(side,t,x,y)
            t:SetSize(width,height)
            if tileLength==16 then
                -- Entire seamless texture; crop only the final partial tile.
                t:SetTexCoord(0,1,0,height/tileLength)
            else
                -- Legacy side art: crop the straight central portion.
                local u1,u2=0,0.5
                if file=="Edge_Right.tga" then u1,u2=0.5,1 end
                local v1=0.25
                local v2=v1+0.5*(height/tileLength)
                t:SetTexCoord(u1,u2,v1,v2)
            end
        end
    end
    -- Edges overlap corners by ~20 units; corners are drawn on top.
    -- The TGA vertical edges have only half their 32px width opaque.
    TiledHorizontal("top","Edge_Top.tga",EDGE_TOP_OUTSET-4,50,1090,8)
    TiledHorizontal("bottom","Edge_Bottom.tga",-740+EDGE_BOTTOM_OUTSET-8,40,1100,7)
    TiledVertical("left","Edge_Left.tga",-EDGE_SIDE_OUTSET+3, -35,-710,6)
    TiledVertical("right","Edge_Right.tga",1140-1, -35,-710,6)
    -- Footer and lower frame edge share one bottom-anchored container.
    -- No hardcoded top offset: resizing keeps the artwork on the actual edge.
    local footerChrome=CreateFrame("Frame",nil,frame)
    footerChrome:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    footerChrome:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    footerChrome:SetHeight(34)
    frame.baziFooterChrome=footerChrome
    -- Temporary visual diagnostics. Toggle with /bazidebug.
    local debugOverlay=CreateFrame("Frame",nil,frame)
    debugOverlay:SetAllPoints(frame)
    debugOverlay:SetFrameLevel(frame:GetFrameLevel()+20)
    debugOverlay:Hide()
    frame.baziDebugOverlay=debugOverlay
    local function DebugRule(parent,r,g,b,y,thickness)
        local t=parent:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(r,g,b,0.95)
        t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",0,y)
        t:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,y)
        t:SetHeight(thickness)
        return t
    end
    DebugRule(debugOverlay,0,1,0,0,3) -- GREEN: true frame bottom
    DebugRule(debugOverlay,1,0.15,0.15,34,3) -- RED: footer top
    local debugText=debugOverlay:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    debugText:SetPoint("BOTTOMLEFT",debugOverlay,"BOTTOMLEFT",12,48)
    debugText:SetText("|cff00ff00GREEN: frame bottom|r  |cffff3333RED: footer top|r")

    local footerDivider=footerChrome:CreateTexture(nil,"ARTWORK")
    footerDivider:SetPoint("TOPLEFT",footerChrome,"TOPLEFT",16,0)
    footerDivider:SetPoint("TOPRIGHT",footerChrome,"TOPRIGHT",-16,0)
    footerDivider:SetHeight(1)
    footerDivider:SetColorTexture(0.67,0.48,0.25,0.48)
    -- Alpha bounds measured from the actual 256x256 TGA files.
    -- Crop only empty pixels. Preserve the original artwork aspect ratio.
    -- Test size: 70 UI units wide; top 55, bottom 52 (rounded).
    local function CroppedCorner(file,point,w,h,u1,u2,v1,v2)
        local t=BorderPiece(file,w,h,point,0,0)
        t:SetTexCoord(u1,u2,v1,v2)
        return t
    end
    frame.baziCornerTextures = {
        TL=CroppedCorner("Corner_TL.tga","TOPLEFT",70,55,0,160/256,0,125/256),
        TR=CroppedCorner("Corner_TR.tga","TOPRIGHT",70,56,96/256,1,0,127/256),
        BL=CroppedCorner("Corner_BL.tga","BOTTOMLEFT",70,52,0,160/256,138/256,1),
        BR=CroppedCorner("Corner_BR.tga","BOTTOMRIGHT",70,52,96/256,1,138/256,1),
    }
    for _,entry in ipairs({
        {"TL","TOPLEFT",-CORNER_TOP_OUTSET,CORNER_TOP_OUTSET},
        {"TR","TOPRIGHT",CORNER_TOP_OUTSET,CORNER_TOP_OUTSET},
        {"BL","BOTTOMLEFT",-CORNER_BOTTOM_OUTSET,-CORNER_BOTTOM_OUTSET},
        {"BR","BOTTOMRIGHT",CORNER_BOTTOM_OUTSET,-CORNER_BOTTOM_OUTSET},
    }) do
        local t=frame.baziCornerTextures[entry[1]]
        t:ClearAllPoints()
        t:SetPoint(entry[2],frame,entry[2],entry[3],entry[4])
    end
    -- Keep the header continuous as well; corner artwork overlays it.
    local header=Paint(frame,"BORDER",0.09,0.063,0.11,0.99,3,-3,-3,3)
    local emblem=frame:CreateTexture(nil,"OVERLAY");emblem:SetTexture(ASSET.."Icons\\BaziUI_Emblem_256.png")
    emblem:SetSize(70,70);emblem:SetPoint("TOPLEFT",frame,"TOPLEFT",13,-6)
    local title=Label(frame,"Bazi UI","GameFontNormalHuge",1,0.83,0.53)
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",85,-16)
    local version=Label(frame,"BAZI UI  /  V0.1.0","GameFontNormalSmall",0.64,0.58,0.66)
    version:SetPoint("TOPLEFT",frame,"TOPLEFT",87,-45)
    local close=Button(frame,"X",1097,-12,28,27,function()frame:Hide()end)
    close:SetFrameLevel(frame:GetFrameLevel()+5)
    Line(frame,-93,11,-11)
    -- Fixed navigation: every category remains visible without scrolling.
    local sidebar=Panel(frame,10,-103,240,602)
    local navBody=CreateFrame("Frame",nil,sidebar)
    navBody:SetPoint("TOPLEFT",sidebar,"TOPLEFT",4,-7)
    navBody:SetSize(232,590)
    local function Category(name,y)
        local h=Label(navBody,name,"GameFontNormalSmall",0.83,0.62,0.34)
        h:SetPoint("TOPLEFT",navBody,"TOPLEFT",15,y)
    end
    Category("GENERAL",-9)
    Category("GAMEPLAY",-174)
    Category("INTERFACE",-337)
    content=CreateFrame("Frame",nil,frame);content:SetPoint("TOPLEFT",frame,"TOPLEFT",265,-104)
    content:SetSize(860,602)
    General()
    local others={"Profiles","Import / Export","What's New","Appearance","UnitFrames","Nameplates","ActionBars","Chat","Quest","Gathering","Minimap","Tooltip","Combat","BugTab","QoL Settings"}
    for _,name in ipairs(others) do Placeholder(name) end
    Tab(frame,"General",249,87);Tab(frame,"Profiles",340,86)
    Tab(frame,"Import / Export",430,121);Tab(frame,"What's New",555,102)
    Nav(navBody,"General","*", -32)
    Nav(navBody,"Appearance","o",-66)
    Nav(navBody,"QoL Settings","+",-100)
    Nav(navBody,"BugTab","*",-134)
    Nav(navBody,"ActionBars","#",-198)
    Nav(navBody,"Quest","?",-232)
    Nav(navBody,"Gathering","^",-266)
    Nav(navBody,"Combat","!",-300)
    Nav(navBody,"Chat",">",-361)
    Nav(navBody,"Minimap","@",-395)
    Nav(navBody,"Tooltip","i",-429)
    Nav(navBody,"UnitFrames","+",-463)
    Nav(navBody,"Nameplates","o",-497)
    local footer=Label(frame,"BAZI UI  |  Changes are saved automatically","GameFontNormalSmall",0.71,0.63,0.61)
    footer:SetPoint("BOTTOMLEFT",footerChrome,"BOTTOMLEFT",23,13)
    local stage=Label(frame,"DESIGN DEVELOPMENT  /  V0.1.0","GameFontNormalSmall",0.76,0.58,0.37)
    stage:SetPoint("BOTTOMRIGHT",footerChrome,"BOTTOMRIGHT",-20,13)
    Show("General")
    frame:Hide()
end
-- Live shadow edge calibration, without /reload or file changes.
-- /bazishadow left -5 moves only the left edge 5 UI units left.
-- /bazishadow reset restores the original 1180 x 780 test bounds.
SLASH_BAZISHADOW1="/bazishadow"
SlashCmdList["BAZISHADOW"]=function(msg)
    if not frame or not frame.baziShadowBounds then
        print("Bazi UI: open /bazi first.")
        return
    end
    local bounds=frame.baziShadowBounds
    local edge,value=(msg or ""):match("^%s*(%a+)%s+([%+%-]?[%d%.]+)%s*$")
    local command=(msg or ""):match("^%s*(%a+)%s*$")
    if command=="reset" then
        bounds.left,bounds.right,bounds.top,bounds.bottom=-590,590,390,-390
        frame.baziUpdateShadowBounds()
    elseif edge and bounds[edge] and tonumber(value) then
        local delta=tonumber(value)
        if math.abs(delta)>100 then
            print("Bazi UI: max 100 UI units per adjustment.")
            return
        end
        local old=bounds[edge]
        bounds[edge]=old+delta
        if not frame.baziUpdateShadowBounds() then
            bounds[edge]=old
            frame.baziUpdateShadowBounds()
            print("Bazi UI: shadow bounds too small.")
            return
        end
    elseif command~="show" then
        print("Usage: /bazishadow left|right|top|bottom DELTA ; /bazishadow show ; /bazishadow reset")
        print("Positive = right/up; negative = left/down. Values are temporary.")
        return
    end
    print(string.format("Bazi shadow: L %.1f R %.1f T %.1f B %.1f | size %.1f x %.1f",
        bounds.left,bounds.right,bounds.top,bounds.bottom,
        bounds.right-bounds.left,bounds.top-bounds.bottom))
end
-- Interactive border calibration. Changes are temporary and reset on /reload.
-- Example: /baziedge bottom 0 -2
-- dx: positive right, dy: positive up. Both in WoW UI units.
SLASH_BAZIEDGE1="/baziedge"
SlashCmdList["BAZIEDGE"]=function(msg)
    if not frame or not frame:IsShown() or not frame.baziEdgePieces then
        print("Bazi UI V7: open /bazi first.")
        return
    end
    local side,sx,sy=(msg or ""):match("^%s*(%a+)%s+([%+%-]?[%d%.]+)%s+([%+%-]?[%d%.]+)%s*$")
    local dx,dy=tonumber(sx),tonumber(sy)
    local pieces=side and frame.baziEdgePieces[side]
    if not pieces or not dx or not dy or math.abs(dx)>30 or math.abs(dy)>30 then
        print("Usage: /baziedge top|bottom|left|right DX DY (-30..30). Positive DX=right, DY=up. /reload resets.")
        return
    end
    for _,entry in ipairs(pieces) do
        entry.texture:ClearAllPoints()
        entry.texture:SetPoint("TOPLEFT",frame,"TOPLEFT",entry.x+dx,entry.y+dy)
    end
    print(string.format("Bazi UI V7: %s edge offset DX %.1f DY %.1f (temporary)",side,dx,dy))
end
-- Temporary V7 geometry diagnostics. Run /baziframe with the options window open.
-- Values use UI coordinates; comparing frame and footer positions isolates
-- artwork padding from layout/scale problems.
SLASH_BAZIDEBUG1 = "/bazidebug"
SlashCmdList["BAZIDEBUG"] = function()
    if not frame then print("Bazi UI V7: open /bazi first.");return end
    if frame.baziDebugOverlay:IsShown() then
        frame.baziDebugOverlay:Hide()
        print("Bazi UI V7: debug overlay OFF")
    else
        frame.baziDebugOverlay:Show()
        print("Bazi UI V7: debug overlay ON. GREEN = frame bottom; RED = footer top.")
    end
end
-- Live corner-outset calibration. Changes only the four corner anchors.
-- Usage: /bazicorneroffset 0 (baseline), or a positive UI-unit value outward.
SLASH_BAZICORNEROFFSET1 = "/bazicorneroffset"
SlashCmdList["BAZICORNEROFFSET"] = function(msg)
    if not frame or not frame:IsShown() or not frame.baziCornerTextures then
        print("Bazi UI V7: open /bazi first.")
        return
    end
    local n=tonumber(msg)
    if not n or n < -30 or n > 30 then
        print("Usage: /bazicorneroffset NUMBER (-30 to 30 UI units). 0 = original placement.")
        return
    end
    for _,entry in ipairs({
        {"TL","TOPLEFT",-1,1},
        {"TR","TOPRIGHT",1,1},
        {"BL","BOTTOMLEFT",-1,-1},
        {"BR","BOTTOMRIGHT",1,-1},
    }) do
        local t=frame.baziCornerTextures[entry[1]]
        t:ClearAllPoints()
        t:SetPoint(entry[2],frame,entry[2],entry[3]*n,entry[4]*n)
    end
    print(string.format("Bazi UI V7: corners moved %.1f UI units outward (all four). Reset: /bazicorneroffset 0",n))
end
-- Read-only corner geometry inspection. Does not change artwork or anchors.
SLASH_BAZICORNERS1 = "/bazicorners"
SlashCmdList["BAZICORNERS"] = function()
    if not frame or not frame:IsShown() or not frame.baziCornerTextures then
        print("Bazi UI V7: open /bazi before /bazicorners.")
        return
    end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local scale = frame:GetEffectiveScale() or 1
    if not left or not bottom then
        print("Bazi UI V7: frame coordinates unavailable.")
        return
    end
    print(string.format("Bazi UI V7 corners | frame %.1f x %.1f | effective scale %.3f",frame:GetWidth(),frame:GetHeight(),scale))
    for _,key in ipairs({"TL","TR","BL","BR"}) do
        local t=frame.baziCornerTextures[key]
        local l,r,top,b=t:GetLeft(),t:GetRight(),t:GetTop(),t:GetBottom()
        if l and r and top and b then
            print(string.format("%s texture: x %.1f..%.1f, y %.1f..%.1f (from frame bottom), size %.1fx%.1f",key,l-left,r-left,b-bottom,top-bottom,t:GetWidth(),t:GetHeight()))
        else
            print(key.." texture: coordinates unavailable")
        end
    end
    print("These are TEXTURE rectangles, not visible-gold alpha bounds.")
end
SLASH_BAZIFRAME1 = "/baziframe"
SlashCmdList["BAZIFRAME"] = function()
    if not frame then
        print("|cffffcc66Bazi UI V7:|r Open /bazi first.")
        return
    end
    local scale=frame:GetEffectiveScale() or 1
    local left,right,top,bottom=frame:GetLeft(),frame:GetRight(),frame:GetTop(),frame:GetBottom()
    print(string.format("|cffffcc66Bazi UI V7 geometry:|r frame %.0f x %.0f, scale %.3f",frame:GetWidth(),frame:GetHeight(),scale))
    if left and right and top and bottom then
        print(string.format("Frame edges: L %.1f R %.1f T %.1f B %.1f (UI units)",left,right,top,bottom))
    end
    if frame.baziFooterChrome then
        local foot=frame.baziFooterChrome
        local fb=foot:GetBottom()
        print(string.format("Footer bottom: %s | offset from frame: %s",fb and string.format("%.1f",fb) or "unknown",(fb and bottom) and string.format("%.1f",fb-bottom) or "unknown"))
    end
    print("If the visible purple background extends below Frame B, report that with a screenshot.")
end
function addon.Options:Open()
    if not frame then self:Create() end
    frame:Show();frame:Raise()
end
function addon.Options:Initialize() end
