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
    f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); f:SetBackdropBorderColor(.12,.12,.15,1)
    local l=Layout(); if l.point then f:SetPoint(l.point,UIParent,l.relativePoint or l.point,l.x or 0,l.y or 0) else f:SetPoint("CENTER",-220,0) end

    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",12,-12); title:SetText("WagBag — "..self:T("BANK"))

    local close=self:CreateHeaderCloseButton(f,function()
        if _G.CloseBankFrame then _G.CloseBankFrame() elseif f then f:Hide() end
    end)
    close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-3,-7)
    f.closeButton=close

    local bags=CreateFrame("Button",nil,f,"BackdropTemplate")
    bags:SetSize(22,22); bags:SetPoint("RIGHT",close,"LEFT",-2,0); StyleHeaderButton(bags)
    local bi=bags:CreateTexture(nil,"ARTWORK"); bi:SetAllPoints(); bi:SetTexture("Interface\\Icons\\INV_Misc_Bag_08"); bi:SetTexCoord(.08,.92,.08,.92)
    bags:SetScript("OnClick",function() RefreshBankBagPanel(); f.bankBagPanel:SetShown(not f.bankBagPanel:IsShown()) end)
    bags:SetScript("OnEnter",function(x) GameTooltip:SetOwner(x,"ANCHOR_BOTTOM"); GameTooltip:SetText(SB:T("BAGS")); GameTooltip:Show() end); bags:SetScript("OnLeave",GameTooltip_Hide)
    f.bankBagsButton=bags

    local purchase=CreateFrame("Button",nil,f,"BackdropTemplate"); purchase:SetSize(22,22); purchase:SetPoint("RIGHT",bags,"LEFT",-4,0); StyleHeaderButton(purchase)
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

function SB:RefreshBank()
    local f=self:CreateBankFrame(); local l=Layout(); f:SetScale(math.max(.5,math.min(2,tonumber(l.scale) or 1))); f:SetBackdropColor(.025,.025,.032,tonumber(l.backgroundAlpha) or .97)
    local purchased=PurchasedBankBagCount()
    local full=false
    if _G.GetNumBankSlots then local _,isFull=GetNumBankSlots(); full=isFull and true or false end
    f.purchaseButton:SetShown(not full and purchased<MAX_BANK_BAGS); RefreshBankBagPanel()
    local cells=math.max(6,math.min(30,tonumber(l.cellsPerRow) or 18)); local visual=0; local live={}
    for _,bagID in ipairs(BankBagIDs()) do
        local n=C_Container.GetContainerNumSlots(bagID) or 0
        for slotID=1,n do
            visual=visual+1; local col=(visual-1)%cells; local row=math.floor((visual-1)/cells); local key=bagID..":"..slotID; live[key]=true
            local w=f.bankButtonsBySlot[key]; if not w then w=self:CreateBankItemButton(f); f.bankButtonsBySlot[key]=w; f.itemButtons[#f.itemButtons+1]=w end
            w:ClearAllPoints(); w:SetPoint("TOPLEFT",f,"TOPLEFT",12+col*(self.SLOT_SIZE+self.SLOT_SPACING),-(48+row*(self.SLOT_SIZE+self.SLOT_SPACING))); w:SetID(bagID); w.nativeButton:SetID(slotID)
            local info=C_Container.GetContainerItemInfo(bagID,slotID)
            if info and info.itemID then self:BindItemButton(w,PhysicalGroup(bagID,slotID,info)); if w.background then w.background:SetColorTexture(.08,.08,.08,.95) end; w:Show() else ClearCell(w,bagID,slotID) end
        end
    end
    for key,w in pairs(f.bankButtonsBySlot) do if not live[key] then w:Hide() end end
    local rows=math.max(1,math.ceil(math.max(visual,1)/cells)); f:SetSize(24+cells*self.SLOT_SIZE+(cells-1)*self.SLOT_SPACING,60+rows*self.SLOT_SIZE+(rows-1)*self.SLOT_SPACING+12)
end

function SB:OpenBank() self:SuppressNativeBank(); self:RefreshBank(); self.bankFrame:Show() end
function SB:CloseBank() if self.bankFrame then self.bankFrame:Hide(); if self.bankFrame.bankBagPanel then self.bankFrame.bankBagPanel:Hide() end end end
function SB:InstallBankHooks() self:SuppressNativeBank() end
function SB:ApplyNativeBankAppearance() if self.bankFrame then self:RefreshBank() end end
function SB:RefreshBankMoney() end

function SB:ApplyBankAnchor(anchor)
    local f=self.bankFrame; if not f or not f:IsShown() then return end
    local l=Layout(); anchor=anchor or l.anchor or "TOPLEFT"; l.anchor=anchor
    local left,top,right,bottom=f:GetLeft(),f:GetTop(),f:GetRight(),f:GetBottom(); if not left then return end
    local uiScale=UIParent:GetEffectiveScale(); local fScale=f:GetEffectiveScale(); f:ClearAllPoints()
    if anchor=="TOPRIGHT" then f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",(right*fScale-UIParent:GetRight()*uiScale)/uiScale,(top*fScale-UIParent:GetTop()*uiScale)/uiScale)
    elseif anchor=="BOTTOMLEFT" then f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",(left*fScale-UIParent:GetLeft()*uiScale)/uiScale,(bottom*fScale-UIParent:GetBottom()*uiScale)/uiScale)
    elseif anchor=="BOTTOMRIGHT" then f:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",(right*fScale-UIParent:GetRight()*uiScale)/uiScale,(bottom*fScale-UIParent:GetBottom()*uiScale)/uiScale)
    else f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",(left*fScale-UIParent:GetLeft()*uiScale)/uiScale,(top*fScale-UIParent:GetTop()*uiScale)/uiScale) end
    local point,_,relativePoint,x,y=f:GetPoint(1); l.point=point; l.relativePoint=relativePoint; l.x=x; l.y=y
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
