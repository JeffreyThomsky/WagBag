local _, SB = ...

local BANK_CONTAINER = -1
local FIRST_BANK_BAG = 5
local MAX_BANK_BAGS = (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBankBagSlots) or 7
local BAG_BUTTON_SIZE, BAG_SPACING, BAG_PADDING = 34, 5, 7

local function Layout()
    local l=SB.db.bankLayout
    if l.scale==nil then l.scale=1 end
    if l.backgroundAlpha==nil then l.backgroundAlpha=.97 end
    if l.cellsPerRow==nil then l.cellsPerRow=18 end
    if l.blocksPerRow==nil then l.blocksPerRow=2 end
    if l.anchor==nil then l.anchor="TOPLEFT" end
    return l
end

local function PurchasedBankBagCount()
    if _G.GetNumBankSlots then
        local ok,n=pcall(_G.GetNumBankSlots)
        if ok and type(n)=="number" then return math.max(0,math.min(MAX_BANK_BAGS,n)) end
    end
    local n=0
    for i=0,MAX_BANK_BAGS-1 do
        if (C_Container.GetContainerNumSlots(FIRST_BANK_BAG+i) or 0)>0 then n=n+1 else break end
    end
    return n
end

local function BankBagIDs()
    local ids={BANK_CONTAINER}
    local purchased=PurchasedBankBagCount()
    for i=0,purchased-1 do ids[#ids+1]=FIRST_BANK_BAG+i end
    return ids
end

local function BankBagInventorySlot(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        local ok,id=pcall(C_Container.ContainerIDToInventoryID,bagID)
        if ok then return id end
    end
    if _G.ContainerIDToInventoryID then
        local ok,id=pcall(_G.ContainerIDToInventoryID,bagID)
        if ok then return id end
    end
end

local function PhysicalGroup(bagID,slotID,info)
    local itemID=info.itemID
    local _,_,_,equipLoc,_,classID,subClassID=C_Item.GetItemInfoInstant(itemID)
    return {key="wagbank:"..bagID..":"..slotID,itemID=itemID,
      itemName=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or C_Item.GetItemInfo(itemID),
      count=info.stackCount or 1,physicalSlots=1,itemLink=info.hyperlink,iconFileID=info.iconFileID,
      quality=info.quality,itemEquipLoc=equipLoc,classID=classID,subClassID=subClassID,
      slots={{bagID=bagID,slotID=slotID,stackCount=info.stackCount or 1}},
      nonStackableEquipment=SB:IsNonStackableEquipment(itemID),isBankItem=true}
end

local function ShowClassicBankItemTooltip(wrapper)
    local group=wrapper and wrapper.group
    local slot=group and group.slots and group.slots[1]
    if not slot then return end
    GameTooltip:SetOwner(wrapper.nativeButton or wrapper,"ANCHOR_RIGHT")
    local shown=false
    if GameTooltip.SetBagItem then
        local ok=pcall(GameTooltip.SetBagItem,GameTooltip,slot.bagID,slot.slotID)
        shown=ok and GameTooltip:NumLines()>0
    end
    if not shown and group.itemLink and GameTooltip.SetHyperlink then
        GameTooltip:ClearLines()
        local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,group.itemLink)
        shown=ok and GameTooltip:NumLines()>0
    end
    if not shown and group.itemID and GameTooltip.SetItemByID then
        GameTooltip:ClearLines()
        pcall(GameTooltip.SetItemByID,GameTooltip,group.itemID)
    end
    GameTooltip:Show()
end

local function BindClassicBankTooltip(wrapper)
    if wrapper._wagClassicTooltipBound then return end
    wrapper._wagClassicTooltipBound=true
    local button=wrapper.nativeButton
    button.UpdateTooltip=function()
        if GameTooltip:IsOwned(button) then ShowClassicBankItemTooltip(wrapper) end
    end
    button:HookScript("OnEnter",function() ShowClassicBankItemTooltip(wrapper) end)
    button:HookScript("OnLeave",GameTooltip_Hide)
end

local function DisableNativeBankMouseTree(frame)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
    local children={frame:GetChildren()}
    for i=1,#children do DisableNativeBankMouseTree(children[i]) end
end

function SB:SuppressNativeBank()
    local f=_G.BankFrame
    if not f then return end
    f:SetAlpha(0); DisableNativeBankMouseTree(f)
    if not self._nativeBankSuppressed then
        f:HookScript("OnShow",function(x) x:SetAlpha(0); DisableNativeBankMouseTree(x) end)
        self._nativeBankSuppressed=true
    end
end

local function StyleHeaderButton(button)
    button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    button:SetBackdropColor(.035,.035,.045,.96); button:SetBackdropBorderColor(.16,.16,.20,1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
end

local function ClassicBankSlotUsage()
    local used,total=0,0
    for _,bagID in ipairs(BankBagIDs()) do
        local slots=C_Container.GetContainerNumSlots(bagID) or 0
        total=total+slots
        for slotID=1,slots do
            if C_Container.GetContainerItemInfo(bagID,slotID) then used=used+1 end
        end
    end
    return used,total
end

local function CreateBankSlotCounter(f,frameLevel)
    local counter=CreateFrame("Frame",nil,f)
    counter:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",12,7)
    counter:SetSize(145,20)
    counter:SetFrameLevel(frameLevel)

    local icon=counter:CreateTexture(nil,"ARTWORK")
    icon:SetSize(18,18)
    icon:SetPoint("LEFT",0,0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")

    local text=counter:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetPoint("LEFT",icon,"RIGHT",3,0)
    text:SetJustifyH("LEFT")

    counter.text=text
    f.slotCounter=counter
end

local function RefreshBankSlotCounter(f)
    if not f or not f.slotCounter then return end
    local used,total=ClassicBankSlotUsage()
    f.slotCounter.text:SetText(used.."/"..total)
end

local function RefreshBankBagPanel()
    local f=SB.bankFrame
    if not f or not f.bankBagPanel then return end
    local panel=f.bankBagPanel
    local purchased=PurchasedBankBagCount()
    for i=1,MAX_BANK_BAGS do
        local b=panel.buttons[i]
        local bagID=FIRST_BANK_BAG+i-1
        if i<=purchased then
            local inv=BankBagInventorySlot(bagID)
            b.bagID=bagID; b.inventorySlot=inv
            b.icon:SetTexture((inv and GetInventoryItemTexture("player",inv)) or "Interface\\Icons\\INV_Misc_Bag_08")
            b:Show()
        else b:Hide() end
    end
    local visible=math.max(1,purchased)
    panel:SetWidth(BAG_PADDING*2+visible*BAG_BUTTON_SIZE+math.max(0,visible-1)*BAG_SPACING)
end

local function CreateBankBagPanel(f)
    local panel=CreateFrame("Frame",nil,f,"BackdropTemplate")
    panel:SetHeight(BAG_BUTTON_SIZE+BAG_PADDING*2); panel:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",-4,4)
    panel:SetFrameLevel(f:GetFrameLevel()+20)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    panel:SetBackdropColor(.02,.02,.025,.98); panel:SetBackdropBorderColor(.18,.18,.21,1)
    panel.buttons={}
    for i=1,MAX_BANK_BAGS do
        local b=CreateFrame("Button",nil,panel)
        b:SetSize(BAG_BUTTON_SIZE,BAG_BUTTON_SIZE); b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        local bg=b:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.035,.035,.04,.98)
        local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetPoint("TOPLEFT",2,-2); icon:SetPoint("BOTTOMRIGHT",-2,2); icon:SetTexCoord(.07,.93,.07,.93); b.icon=icon
        local border=b:CreateTexture(nil,"OVERLAY"); border:SetPoint("TOPLEFT",-1,1); border:SetPoint("BOTTOMRIGHT",1,-1); border:SetColorTexture(.32,.32,.36,.55)
        if i==1 then b:SetPoint("LEFT",panel,"LEFT",BAG_PADDING,0) else b:SetPoint("LEFT",panel.buttons[i-1],"RIGHT",BAG_SPACING,0) end
        b:SetScript("OnClick",function(x) if x.inventorySlot then PickupInventoryItem(x.inventorySlot) end end)
        b:SetScript("OnEnter",function(x)
            GameTooltip:SetOwner(x,"ANCHOR_RIGHT")
            if x.inventorySlot then GameTooltip:SetInventoryItem("player",x.inventorySlot) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",GameTooltip_Hide)
        panel.buttons[i]=b
    end
    panel:Hide(); f.bankBagPanel=panel
    RefreshBankBagPanel()
end

function SB:CreateBankFrame()
    if self.bankFrame then return self.bankFrame end
    local f=CreateFrame("Frame","WagBagBankFrame",UIParent,"BackdropTemplate")
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); f:SetBackdropBorderColor(.12,.12,.15,1)
    local l=Layout(); if l.anchorModel==2 then f:SetPoint("CENTER",-220,0) elseif l.point then f:SetPoint(l.point,UIParent,l.relativePoint or l.point,l.x or 0,l.y or 0) else f:SetPoint("CENTER",-220,0) end

    local shield=CreateFrame("Frame",nil,f)
    shield:SetAllPoints(f); shield:SetFrameLevel(f:GetFrameLevel()+1); shield:EnableMouse(true)
    if shield.SetMouseClickEnabled then shield:SetMouseClickEnabled(true) end
    if shield.SetMouseMotionEnabled then shield:SetMouseMotionEnabled(true) end
    if shield.SetPropagateMouseClicks then shield:SetPropagateMouseClicks(false) end
    if shield.SetPropagateMouseMotion then shield:SetPropagateMouseMotion(false) end
    shield:SetScript("OnEnter",function() GameTooltip:Hide() end)
    shield:SetScript("OnMouseDown",function() end)
    shield:SetScript("OnMouseUp",function(_,button)
        if (button=="LeftButton" or button=="RightButton") and CursorHasItem() and SB.bankAccessOpen and not SB.bankPlacementActive then
            if SB:DropCursorItemIntoBank() then C_Timer.After(0,function() if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank() end end) end
        end
    end)
    f.mouseShield=shield
    local contentLevel=f:GetFrameLevel()+2

    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",12,-12); title:SetText("WagBag — "..self:T("BANK"))

    local searchBox=CreateFrame("EditBox",nil,f,"BackdropTemplate")
    searchBox:SetSize(132,20); searchBox:SetPoint("LEFT",title,"RIGHT",8,0); searchBox:SetAutoFocus(false); searchBox:SetFontObject("GameFontHighlight"); searchBox:SetTextInsets(6,18,0,0); searchBox:EnableMouse(true); searchBox:SetFrameLevel(f:GetFrameLevel()+4)
    searchBox:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); searchBox:SetBackdropColor(.035,.035,.045,.96); searchBox:SetBackdropBorderColor(.16,.16,.20,1)
    local placeholder=searchBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); placeholder:SetPoint("LEFT",6,0); placeholder:SetText(self:T("SEARCH"))
    local clear=CreateFrame("Button",nil,searchBox); clear:SetSize(14,14); clear:SetPoint("RIGHT",-2,0); clear:SetFrameLevel(searchBox:GetFrameLevel()+1)
    local clearText=clear:CreateFontString(nil,"OVERLAY","GameFontNormal"); clearText:SetPoint("CENTER"); clearText:SetText("×"); clear:Hide()
    searchBox:SetScript("OnTextChanged",function(box) local text=box:GetText() or ""; placeholder:SetShown(text==""); clear:SetShown(text~=""); SB.bankSearchText=text; if f:IsShown() then SB:RefreshBank() end end)
    searchBox:SetScript("OnEscapePressed",function(box) box:ClearFocus() end); searchBox:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
    clear:SetScript("OnClick",function() searchBox:SetText(""); searchBox:ClearFocus() end); f.searchBox=searchBox

    local close=self:CreateHeaderCloseButton(f,function()
        if _G.CloseBankFrame then _G.CloseBankFrame() elseif f then f:Hide() end
    end)
    close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-3,-7)
    close:SetFrameLevel(contentLevel)
    f.closeButton=close

    local bags=CreateFrame("Button",nil,f,"BackdropTemplate")
    bags:SetSize(22,22); bags:SetFrameLevel(contentLevel); bags:SetPoint("RIGHT",close,"LEFT",-2,0); StyleHeaderButton(bags)
    local bi=bags:CreateTexture(nil,"ARTWORK"); bi:SetAllPoints(); bi:SetTexture("Interface\\Icons\\INV_Misc_Bag_08"); bi:SetTexCoord(.08,.92,.08,.92)
    bags:SetScript("OnClick",function() RefreshBankBagPanel(); f.bankBagPanel:SetShown(not f.bankBagPanel:IsShown()) end)
    bags:SetScript("OnEnter",function(x) GameTooltip:SetOwner(x,"ANCHOR_BOTTOM"); GameTooltip:SetText(SB:T("BAGS")); GameTooltip:Show() end); bags:SetScript("OnLeave",GameTooltip_Hide)
    f.bankBagsButton=bags

    local purchase=CreateFrame("Button",nil,f,"BackdropTemplate"); purchase:SetSize(22,22); purchase:SetFrameLevel(contentLevel); purchase:SetPoint("RIGHT",bags,"LEFT",-4,0); StyleHeaderButton(purchase)
    local purchaseIcon=purchase:CreateTexture(nil,"ARTWORK")
    purchaseIcon:SetAllPoints()
    purchaseIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    purchase:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    purchase:SetScript("OnClick",function()
        if _G.PurchaseSlot then _G.PurchaseSlot() end
        C_Timer.After(.1,function() if SB.bankFrame and SB.bankFrame:IsShown() then RefreshBankBagPanel(); SB:RefreshBank() end end)
    end)
    purchase:SetScript("OnEnter",function(x)
        GameTooltip:SetOwner(x,"ANCHOR_BOTTOM"); GameTooltip:SetText(SB:T("BUY_SLOT"))
        if _G.GetNumBankSlots and _G.GetBankSlotCost then
            local n,full=GetNumBankSlots(); if full then GameTooltip:AddLine(SB:T("BUY_SLOT"),.7,.7,.7)
            else local cost=GetBankSlotCost(n); if cost then GameTooltip:AddLine(GetCoinTextureString(cost),1,1,1) end end
        end
        GameTooltip:Show()
    end); purchase:SetScript("OnLeave",GameTooltip_Hide); f.purchaseButton=purchase

    CreateBankBagPanel(f)
    CreateBankSlotCounter(f,contentLevel)

    local mover=CreateFrame("Frame",nil,f,"BackdropTemplate"); mover:SetAllPoints(f); mover:SetFrameLevel(f:GetFrameLevel()+20)
    mover:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); mover:SetBackdropColor(.03,.20,.32,.32); mover:SetBackdropBorderColor(0,.65,1,1)
    mover:EnableMouse(true); mover:RegisterForDrag("LeftButton"); mover:SetScript("OnDragStart",function() if SB.bankPlacementActive then f:StartMoving() end end); mover:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    local mt=mover:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); mt:SetPoint("CENTER"); mt:SetText(self:T("BANK_MOVER")); mt:SetTextColor(1,.82,0,1); mover:Hide(); f.placementMover=mover

    f.itemButtons={}; f.bankButtonsBySlot={}; self.bankFrame=f
    return f
end

local function ClearCell(w,bagID,slotID)
    w.group=nil; w:SetID(bagID); w.nativeButton:SetID(slotID); w.nativeButton:SetAlpha(1); w.icon:SetTexture(nil); w.icon:SetDesaturated(false)
    if w.countText then
        if not w.countText:GetFont() then w.countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE") end
        w.countText:SetText("")
    end
    if w.itemLevelText then
        if not w.itemLevelText:GetFont() then w.itemLevelText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE") end
        w.itemLevelText:SetText("")
    end
    if w.junkCoin then w.junkCoin:Hide() end
    if w.cooldownText then w.cooldownText:Hide() end; w.cooldownEnd=nil; w:SetScript("OnUpdate",nil)
    local overlay=w.CanIMogItOverlay or (w.nativeButton and w.nativeButton.CanIMogItOverlay); if overlay then overlay:Hide() end
    if w.background then w.background:SetColorTexture(.050,.050,.060,.92) end; if w.nativeButton then w.nativeButton:UnlockHighlight() end; w:SetAlpha(1); w:Show()
end

local BANK_BLOCK_PADDING = 8
local BANK_BLOCK_TITLE_HEIGHT = 20
local BANK_BLOCK_GAP = 8
local BANK_WINDOW_PADDING = 12

local function AcquireBankCategoryFrame(f,index)
    f.categoryFrames=f.categoryFrames or {}
    local block=f.categoryFrames[index]
    if block then block:Show(); return block end
    block=CreateFrame("Frame",nil,f,"BackdropTemplate")
    block:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    block:SetBackdropColor(.018,.018,.024,.72); block:SetBackdropBorderColor(.13,.13,.17,1); block:SetFrameLevel(f:GetFrameLevel()+2)
    local titleHandle=CreateFrame("Button",nil,block)
    titleHandle:SetPoint("TOPLEFT",1,-1); titleHandle:SetPoint("TOPRIGHT",-1,-1); titleHandle:SetHeight(BANK_BLOCK_TITLE_HEIGHT); titleHandle:RegisterForDrag("LeftButton")
    titleHandle:SetScript("OnDragStart",function(handle) if not SB.db.layout.locked and handle.categoryKey then SB:BeginCategoryOrderDrag(handle.categoryKey) end end)
    local title=titleHandle:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("LEFT",BANK_BLOCK_PADDING-1,0); title:SetTextColor(1,.82,0,1)
    block.titleHandle=titleHandle; block.title=title; f.categoryFrames[index]=block
    return block
end

local function HideBankCategoryFrames(f,fromIndex)
    if not f.categoryFrames then return end
    for i=fromIndex,#f.categoryFrames do f.categoryFrames[i]:Hide() end
end

local function FirstEmptyBankSlot()
    for _,bagID in ipairs(BankBagIDs()) do
        for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
            if not C_Container.GetContainerItemInfo(bagID,slotID) then return bagID,slotID end
        end
    end
end

function SB:DropCursorItemIntoBank()
    if not self.bankAccessOpen or not CursorHasItem() then return false end
    local bagID,slotID=FirstEmptyBankSlot()
    if not bagID then return false end
    C_Container.PickupContainerItem(bagID,slotID)
    return true
end

function SB:RefreshBank()
    if not self.bankAccessOpen then return end
    local f=self:CreateBankFrame(); local l=Layout()
    f:SetScale(math.max(.5,math.min(2,tonumber(l.scale) or 1))); f:SetBackdropColor(.025,.025,.032,tonumber(l.backgroundAlpha) or .97)
    local purchased=PurchasedBankBagCount(); local full=false
    if _G.GetNumBankSlots then local _,isFull=GetNumBankSlots(); full=isFull and true or false end
    f.purchaseButton:SetShown(not full and purchased<MAX_BANK_BAGS); RefreshBankBagPanel(); RefreshBankSlotCounter(f)

    local groups={}; local live={}
    for _,bagID in ipairs(BankBagIDs()) do
        for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
            local info=C_Container.GetContainerItemInfo(bagID,slotID)
            if info and info.itemID then groups[#groups+1]=PhysicalGroup(bagID,slotID,info) end
        end
    end

    local categories=self:BuildCategoryBuckets(groups,true)
    local requestedCells=math.max(6,math.min(30,math.floor(tonumber(l.cellsPerRow) or 18)))
    local blocks=math.max(1,math.min(4,math.floor(tonumber(l.blocksPerRow) or 2)))
    local usableCells=requestedCells-(requestedCells%blocks)
    if usableCells<blocks then usableCells=blocks end
    local cells=math.max(1,math.floor(usableCells/blocks))
    local blockWidth=BANK_BLOCK_PADDING*2+cells*self.SLOT_SIZE+math.max(0,cells-1)*self.SLOT_SPACING
    local scale=math.max(.5,math.min(2,tonumber(l.scale) or 1))
    local heightLimit=(UIParent:GetHeight() or 768)*.66/scale
    local startY=48; local x=BANK_WINDOW_PADDING; local y=startY; local maxBottom=startY; local maxRight=BANK_WINDOW_PADDING+blockWidth; local categoryIndex=0

    for _,category in ipairs(categories) do
        local itemCount=#category.items; local rows=math.max(1,math.ceil(math.max(1,itemCount)/cells))
        local h=BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+rows*self.SLOT_SIZE+math.max(0,rows-1)*self.SLOT_SPACING+BANK_BLOCK_PADDING
        if y+h+12>heightLimit and y>startY then x=x+blockWidth+BANK_BLOCK_GAP; y=startY end
        categoryIndex=categoryIndex+1
        local block=AcquireBankCategoryFrame(f,categoryIndex); block.categoryKey=category.noReorder and nil or category.key; block.titleHandle.categoryKey=block.categoryKey; block.title:SetText(category.name)
        block:SetSize(blockWidth,h); block:ClearAllPoints(); block:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y)
        for itemIndex,group in ipairs(category.items) do
            local key=group.key; live[key]=true; local w=f.bankButtonsBySlot[key]
            if not w then w=self:CreateBankItemButton(block); w:SetFrameLevel(block:GetFrameLevel()+1); if w.nativeButton then w.nativeButton:SetFrameLevel(w:GetFrameLevel()+1) end; f.bankButtonsBySlot[key]=w; f.itemButtons[#f.itemButtons+1]=w else w:SetParent(block) end
            BindClassicBankTooltip(w)
            w.disableCategoryDrag=false
            local col=(itemIndex-1)%cells; local row=math.floor((itemIndex-1)/cells)
            w:ClearAllPoints(); w:SetPoint("TOPLEFT",block,"TOPLEFT",BANK_BLOCK_PADDING+col*(self.SLOT_SIZE+self.SLOT_SPACING),-(BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+row*(self.SLOT_SIZE+self.SLOT_SPACING)))
            self:BindItemButton(w,group)
            local searching=strtrim(self.bankSearchText or "")~=""; w:SetAlpha((not searching or self:GroupMatchesSearch(group,self.bankSearchText)) and 1 or .22); w:Show()
        end
        y=y+h+BANK_BLOCK_GAP; maxBottom=math.max(maxBottom,y); maxRight=math.max(maxRight,x+blockWidth)
    end
    HideBankCategoryFrames(f,categoryIndex+1)
    for key,w in pairs(f.bankButtonsBySlot) do if not live[key] then w:Hide() end end
    f:SetSize(maxRight+BANK_WINDOW_PADDING,math.max(136,maxBottom+20))
    if not f._wagBankAnchorAttached then self:ApplyStoredBankAnchor() end
end

local SYSTEM_PANEL_GAP=10
local SYSTEM_PANEL_TOP_OFFSET=80
local SYSTEM_PANEL_NAMES={"CharacterFrame","DressUpFrame"}

local function ScaleToUIParent(frame)
    local parentScale=(UIParent and UIParent:GetEffectiveScale()) or 1
    local frameScale=(frame and frame:GetEffectiveScale()) or parentScale
    if parentScale==0 then parentScale=1 end
    return frameScale/parentScale
end

local function PanelRect(frame)
    if not frame or not frame:IsShown() then return end
    local l,r,b,t=frame:GetLeft(),frame:GetRight(),frame:GetBottom(),frame:GetTop()
    if not l or not r or not b or not t then return end
    local scale=ScaleToUIParent(frame)
    return l*scale,r*scale,b*scale,t*scale
end

local function PanelSize(frame)
    if not frame then return end
    local scale=ScaleToUIParent(frame)
    local width=(frame:GetWidth() or 0)*scale
    local height=(frame:GetHeight() or 0)*scale
    if width<=0 or height<=0 then return end
    return width,height,scale
end

local function RectsOverlap(aL,aR,aB,aT,bL,bR,bB,bT)
    return aR>bL and aL<bR and aT>bB and aB<bT
end

local function AddObstacle(list,frame,except)
    if not frame or frame==except or not frame:IsShown() then return end
    local l,r,b,t=PanelRect(frame)
    if l then list[#list+1]={l,r,b,t} end
end

local function CaptureSystemPanel(frame)
    if not frame then return false end
    if not frame._wagPanelStateSaved then
        local info=UIPanelWindows and UIPanelWindows[frame:GetName()]
        if frame:GetAttribute("UIPanelLayout-defined") then
            frame._wagOriginalPanelArea=frame:GetAttribute("UIPanelLayout-area")
        else
            frame._wagOriginalPanelArea=info and info.area or nil
        end
        frame._wagOriginalStrata=frame:GetFrameStrata()
        frame._wagPanelStateSaved=true
    end
    return true
end

local function DetachSystemPanel(frame)
    if not frame then return false end
    if frame._wagBankDetached then
        frame:SetFrameStrata("DIALOG")
        return true
    end
    if type(SetUIPanelAttribute)~="function" or not UIPanelWindows or not UIPanelWindows[frame:GetName()] then return false end
    CaptureSystemPanel(frame)
    SetUIPanelAttribute(frame,"area",nil)
    frame._wagBankDetached=true
    frame:SetFrameStrata("DIALOG")
    return true
end

local function RestoreSystemPanel(frame)
    if not frame or not frame._wagBankDetached then return end
    if type(SetUIPanelAttribute)=="function" then
        SetUIPanelAttribute(frame,"area",frame._wagOriginalPanelArea)
    end
    if frame._wagOriginalStrata then frame:SetFrameStrata(frame._wagOriginalStrata) end
    frame._wagBankDetached=nil
    frame._wagBankPreferredTop=nil
    frame._wagOriginalPanelArea=nil
    frame._wagOriginalStrata=nil
    frame._wagPanelStateSaved=nil
end

local function DefaultPanelTop(frame)
    local screenT=(UIParent:GetTop() or UIParent:GetHeight() or 0)
    if frame._wagBankPreferredTop then return frame._wagBankPreferredTop end
    if not frame._wagHadCustomPoint then
        local _,_,_,top=PanelRect(frame)
        if top then
            frame._wagBankPreferredTop=top
            return top
        end
    end
    frame._wagBankPreferredTop=screenT-SYSTEM_PANEL_TOP_OFFSET
    return frame._wagBankPreferredTop
end

local function BuildCandidates(frame,bank,other,ignoreBag)
    local width,height=PanelSize(frame)
    if not width then return end
    local screenL=UIParent:GetLeft() or 0
    local screenR=UIParent:GetRight() or UIParent:GetWidth()
    local screenB=UIParent:GetBottom() or 0
    local screenT=UIParent:GetTop() or UIParent:GetHeight()
    local obstacles={}
    AddObstacle(obstacles,bank,frame)
    if not ignoreBag then AddObstacle(obstacles,SB.mainFrame,frame) end
    AddObstacle(obstacles,other,frame)
    local xCandidates={}
    local function AddX(value)
        if value then xCandidates[#xCandidates+1]=value end
    end
    local bL,bR=PanelRect(bank)
    if bL then
        AddX(bR+SYSTEM_PANEL_GAP)
        AddX(bL-SYSTEM_PANEL_GAP-width)
    end
    if SB.mainFrame and SB.mainFrame:IsShown() then
        local mL,mR=PanelRect(SB.mainFrame)
        if mL then
            AddX(mR+SYSTEM_PANEL_GAP)
            AddX(mL-SYSTEM_PANEL_GAP-width)
        end
    end
    if other and other:IsShown() then
        local oL,oR=PanelRect(other)
        if oL then
            AddX(oR+SYSTEM_PANEL_GAP)
            AddX(oL-SYSTEM_PANEL_GAP-width)
        end
    end
    AddX(screenL)
    AddX(screenR-width)
    local preferredTop=DefaultPanelTop(frame)
    local yCandidates={preferredTop,screenT-SYSTEM_PANEL_TOP_OFFSET}
    local _,_,_,bankTop=PanelRect(bank)
    if bankTop then yCandidates[#yCandidates+1]=bankTop end
    if other and other:IsShown() then
        local _,_,_,otherTop=PanelRect(other)
        if otherTop then yCandidates[#yCandidates+1]=otherTop end
    end
    local seen={}
    for _,topValue in ipairs(yCandidates) do
        local top=math.min(topValue,screenT)
        if top-height<screenB then top=screenB+height end
        for _,leftValue in ipairs(xCandidates) do
            local left=math.floor(leftValue+0.5)
            local key=tostring(left)..":"..tostring(math.floor(top+0.5))
            if not seen[key] then
                seen[key]=true
                local right,bottom=left+width,top-height
                if left>=screenL and right<=screenR and bottom>=screenB and top<=screenT then
                    local blocked=false
                    for _,o in ipairs(obstacles) do
                        if RectsOverlap(left,right,bottom,top,o[1],o[2],o[3],o[4]) then blocked=true break end
                    end
                    if not blocked then return left,top end
                end
            end
        end
    end
end

local function PlacePanelAt(frame,left,top)
    if not frame or not left or not top then return false end
    local _,_,scale=PanelSize(frame)
    if not scale or scale==0 then return false end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left/scale,top/scale)
    frame._wagHadCustomPoint=true
    return true
end

local function PlaceSystemPanel(frame,bank,other,ignoreBag)
    local left,top=BuildCandidates(frame,bank,other,ignoreBag)
    if not left then return false end
    frame:SetFrameStrata("DIALOG")
    return PlacePanelAt(frame,left,top)
end

function SB:ArrangeBankSystemPanels(trigger)
    local bank=self.bankFrame
    if not self._bankSystemPanelMode or not self.bankAccessOpen or not bank or not bank:IsShown() or not trigger or not trigger:IsShown() or not trigger._wagBankDetached then return end
    local character=_G.CharacterFrame
    local dress=_G.DressUpFrame
    local other
    if trigger==character then other=dress elseif trigger==dress then other=character else return end
    trigger:SetFrameStrata("DIALOG")
    if other and other:IsShown() then
        if PlaceSystemPanel(trigger,bank,other,false) then return end
        if PlaceSystemPanel(trigger,bank,other,true) then return end
        if HideUIPanel then HideUIPanel(other) else other:Hide() end
    end
    if PlaceSystemPanel(trigger,bank,nil,false) then return end
    if PlaceSystemPanel(trigger,bank,nil,true) then return end
    local width,height,scale=PanelSize(trigger)
    if not width then return end
    local screenL=UIParent:GetLeft() or 0
    local screenR=UIParent:GetRight() or UIParent:GetWidth()
    local screenB=UIParent:GetBottom() or 0
    local screenT=UIParent:GetTop() or UIParent:GetHeight()
    local top=math.min(DefaultPanelTop(trigger),screenT)
    if top-height<screenB then top=screenB+height end
    local bankLeft=PanelRect(bank)
    local left=math.max(screenL,math.min(bankLeft or screenL,screenR-width))
    PlacePanelAt(trigger,left,top)
end

function SB:InstallDressUpHooks()
    for _,name in ipairs(SYSTEM_PANEL_NAMES) do
        local frame=_G[name]
        if frame and not frame._wagBankPanelHooked then
            frame._wagBankPanelHooked=true
            frame:HookScript("OnShow",function(x)
                SB._lastSystemPanelShown=x
                if not SB._bankSystemPanelMode or not SB.bankAccessOpen then
                    x._wagHadCustomPoint=nil
                    return
                end
                if not x._wagBankDetached then return end
                SB:ArrangeBankSystemPanels(x)
            end)
        end
        if frame and self._bankSystemPanelMode and not frame._wagBankDetached then
            local wasShown=frame:IsShown()
            local _,_,_,top=PanelRect(frame)
            if top then frame._wagBankPreferredTop=top end
            if wasShown then
                if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
            end
            if DetachSystemPanel(frame) and wasShown then
                if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
            end
        end
    end
end

function SB:EnterBankSystemPanelMode()
    if self._bankSystemPanelMode then return end
    if type(SetUIPanelAttribute)~="function" or type(ShowUIPanel)~="function" or type(HideUIPanel)~="function" then return end
    self:InstallDressUpHooks()
    self._bankSystemPanelMode=true
    local frames={}
    local shown={}
    for _,name in ipairs(SYSTEM_PANEL_NAMES) do
        local frame=_G[name]
        if frame then
            frames[#frames+1]=frame
            CaptureSystemPanel(frame)
            if frame:IsShown() then
                shown[frame]=true
                local _,_,_,top=PanelRect(frame)
                if top then frame._wagBankPreferredTop=top end
            end
        end
    end
    for _,frame in ipairs(frames) do
        if shown[frame] then HideUIPanel(frame) end
    end
    for _,frame in ipairs(frames) do DetachSystemPanel(frame) end
    local character=_G.CharacterFrame
    local dress=_G.DressUpFrame
    if shown[character] and shown[dress] then
        local last=self._lastSystemPanelShown
        local first=(last==character) and dress or character
        local second=(last==character) and character or dress
        ShowUIPanel(first)
        ShowUIPanel(second)
    else
        for _,frame in ipairs(frames) do
            if shown[frame] then ShowUIPanel(frame) end
        end
    end
end

function SB:ExitBankSystemPanelMode()
    if not self._bankSystemPanelMode then return end
    local frames={}
    local shown={}
    for _,name in ipairs(SYSTEM_PANEL_NAMES) do
        local frame=_G[name]
        if frame then
            frames[#frames+1]=frame
            shown[frame]=frame:IsShown()
        end
    end
    self._bankSystemPanelMode=false
    for _,frame in ipairs(frames) do
        if shown[frame] then frame:Hide() end
    end
    for _,frame in ipairs(frames) do RestoreSystemPanel(frame) end
    local character=_G.CharacterFrame
    local dress=_G.DressUpFrame
    if shown[character] and shown[dress] then
        local last=self._lastSystemPanelShown
        local first=(last==character) and dress or character
        local second=(last==character) and character or dress
        ShowUIPanel(first)
        ShowUIPanel(second)
        if shown[first] then first._wagHadCustomPoint=nil end
        if shown[second] then second._wagHadCustomPoint=nil end
    else
        for _,frame in ipairs(frames) do
            if shown[frame] then
                ShowUIPanel(frame)
                frame._wagHadCustomPoint=nil
            end
        end
    end
end

function SB:OpenBank()
    self:SuppressNativeBank(); self:RefreshBank(); self.bankFrame:Show(); if self.EnterBankSystemPanelMode then self:EnterBankSystemPanelMode() end
end
function SB:CloseBank()
    if self.bankFrame then self.bankFrame:Hide(); if self.bankFrame.bankBagPanel then self.bankFrame.bankBagPanel:Hide() end end
    if self.ExitBankSystemPanelMode then self:ExitBankSystemPanelMode() end
end
function SB:InstallBankHooks() self:SuppressNativeBank() end

function SB:EnsureBankAnchorFrame()
    if self.bankAnchorFrame then return self.bankAnchorFrame end
    local anchorFrame=CreateFrame("Frame",nil,UIParent)
    anchorFrame:SetSize(1,1)
    anchorFrame:SetScale(1)
    anchorFrame:EnableMouse(false)
    self.bankAnchorFrame=anchorFrame
    return anchorFrame
end

function SB:GetBankFramePointInUIParent(anchor)
    local f=self.bankFrame
    if not f then return nil end
    anchor=anchor or Layout().anchor or "TOPLEFT"
    local px=anchor:find("RIGHT") and f:GetRight() or f:GetLeft()
    local py=anchor:find("TOP") and f:GetTop() or f:GetBottom()
    if not px or not py then return nil end
    local frameScale=f:GetEffectiveScale() or 1
    local parentScale=UIParent:GetEffectiveScale() or 1
    if parentScale==0 then parentScale=1 end
    local ratio=frameScale/parentScale
    return px*ratio,py*ratio
end

function SB:SetBankAnchorPosition(x,y)
    if x==nil or y==nil then return end
    local anchorFrame=self:EnsureBankAnchorFrame()
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
    local l=Layout()
    l.point="BOTTOMLEFT"
    l.relativePoint="BOTTOMLEFT"
    l.x=x
    l.y=y
    l.anchorModel=2
end

function SB:AttachBankFrameToAnchor(anchor)
    local f=self.bankFrame
    if not f then return end
    anchor=anchor or Layout().anchor or "TOPLEFT"
    local anchorFrame=self:EnsureBankAnchorFrame()
    f:ClearAllPoints()
    f:SetPoint(anchor,anchorFrame,"CENTER",0,0)
    f._wagBankAnchorAttached=true
end

function SB:ApplyStoredBankAnchor()
    local f=self.bankFrame
    if not f then return end
    local l=Layout()
    local anchor=l.anchor or "TOPLEFT"
    if l.anchorModel==2 and l.x~=nil and l.y~=nil then
        self:SetBankAnchorPosition(l.x,l.y)
        self:AttachBankFrameToAnchor(anchor)
        return
    end
    local x,y=self:GetBankFramePointInUIParent(anchor)
    if x~=nil and y~=nil then
        self:SetBankAnchorPosition(x,y)
        self:AttachBankFrameToAnchor(anchor)
    end
end

function SB:SetBankScale(value)
    local l=Layout()
    local newScale=math.max(.5,math.min(2,tonumber(value) or 1))
    local f=self.bankFrame
    if not f or not f:IsShown() then l.scale=newScale return end
    local anchor=l.anchor or "TOPLEFT"
    local anchorFrame=self:EnsureBankAnchorFrame()
    local point,relativeTo=f:GetPoint(1)
    local attached=l.anchorModel==2 and l.x~=nil and l.y~=nil and relativeTo==anchorFrame
    local x,y
    if not attached then x,y=self:GetBankFramePointInUIParent(anchor) end
    l.scale=newScale
    f:SetScale(newScale)
    if not attached and x~=nil and y~=nil then
        self:SetBankAnchorPosition(x,y)
        self:AttachBankFrameToAnchor(anchor)
    elseif attached and point~=anchor then
        self:AttachBankFrameToAnchor(anchor)
    end
    self:RefreshBank()
end

function SB:ApplyNativeBankAppearance() if self.bankFrame then self:RefreshBank() end end
function SB:RefreshBankMoney() end

function SB:ApplyBankAnchor(anchor)
    local f=self.bankFrame; if not f or not f:IsShown() then return end
    local l=Layout(); anchor=anchor or l.anchor or "TOPLEFT"
    local anchorFrame=self:EnsureBankAnchorFrame()
    local oldAnchor,relativeTo=f:GetPoint(1)
    local attached=l.anchorModel==2 and l.x~=nil and l.y~=nil and relativeTo==anchorFrame
    if attached and oldAnchor then
        if oldAnchor~=anchor then
            local parentScale=UIParent:GetEffectiveScale() or 1
            if parentScale==0 then parentScale=1 end
            local scale=(f:GetEffectiveScale() or parentScale)/parentScale
            local w=(f:GetWidth() or 0)*scale
            local h=(f:GetHeight() or 0)*scale
            local function Offset(a) return a:find("RIGHT") and w or 0,a:find("TOP") and h or 0 end
            local ox,oy=Offset(oldAnchor); local nx,ny=Offset(anchor)
            self:SetBankAnchorPosition(l.x+(nx-ox),l.y+(ny-oy))
        end
        l.anchor=anchor
        self:AttachBankFrameToAnchor(anchor)
        return
    end
    local x,y=self:GetBankFramePointInUIParent(anchor); if x==nil or y==nil then return end
    l.anchor=anchor
    self:SetBankAnchorPosition(x,y)
    self:AttachBankFrameToAnchor(anchor)
end

function SB:ToggleBankPlacement()
    local f=self.bankFrame; if not f or not f:IsShown() then self.bankPlacementActive=false; self:Print(self:T("OPEN_BANK_TO_MOVE")); if self.RefreshBankSettingsValues then self:RefreshBankSettingsValues() end; return end
    local l=Layout(); if self.bankPlacementActive then f:StopMovingOrSizing(); f:SetMovable(false); self.bankPlacementActive=false; if f.placementMover then f.placementMover:Hide() end; self:ApplyBankAnchor(l.anchor) else f:SetMovable(true); self.bankPlacementActive=true; if f.placementMover then f.placementMover:Show() end end
    if self.RefreshBankSettingsValues then self:RefreshBankSettingsValues() end
end
function SB:FinishBankPlacement()
    if not self.bankPlacementActive then return end; local f=self.bankFrame; self.bankPlacementActive=false
    if f and f:IsShown() then f:StopMovingOrSizing(); f:SetMovable(false); if f.placementMover then f.placementMover:Hide() end; self:ApplyBankAnchor(Layout().anchor) end
    if self.RefreshBankSettingsValues then self:RefreshBankSettingsValues() end
end
