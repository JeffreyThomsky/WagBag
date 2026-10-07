local _, SB = ...

local CHARACTER = (Enum.BankType and Enum.BankType.Character) or 0
local ACCOUNT   = (Enum.BankType and Enum.BankType.Account) or 2
local MATERIALS = "materials"
local REAGENT_FLAG = (Enum.BagSlotFlags and Enum.BagSlotFlags.ClassReagents) or 0x80

local function FlatBankButton(parent,text,w)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(w or 82,22)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    b:SetBackdropColor(.045,.045,.055,.98)
    b:SetBackdropBorderColor(.20,.20,.24,1)
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    function b:SetText(v) self.text:SetText(v or "") end
    function b:SetActive(active)
        self._active=active and true or false
        self:SetBackdropColor(active and .12 or .045,active and .10 or .045,active and .035 or .055,1)
        self:SetBackdropBorderColor(active and 1 or .20,active and .72 or .20,active and .05 or .24,1)
        self.text:SetTextColor(active and 1 or .82,active and .82 or .82,active and .10 or .82)
    end
    b:SetScript("OnEnter",function(x) if not x._active then x:SetBackdropBorderColor(.62,.50,.10,1) end end)
    b:SetScript("OnLeave",function(x) if not x._active then x:SetBackdropBorderColor(.20,.20,.24,1) end end)
    b:SetActive(false)
    return b
end

local function Layout()
    local l=SB.db.bankLayout
    if l.scale==nil then l.scale=1 end
    if l.backgroundAlpha==nil then l.backgroundAlpha=.97 end
    if l.cellsPerRow==nil then l.cellsPerRow=18 end
    if l.blocksPerRow==nil then l.blocksPerRow=2 end
    if l.separateMaterials==nil then l.separateMaterials=false end
    if l.anchor==nil then l.anchor="TOPLEFT" end
    return l
end

local CHARACTER_TABS = {
    (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) or 6,
    (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_2) or 7,
    (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_3) or 8,
    (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_4) or 9,
    (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_5) or 10,
    (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_6) or 11,
}
local ACCOUNT_TABS = {
    (Enum.BagIndex and Enum.BagIndex.AccountBankTab_1) or 12,
    (Enum.BagIndex and Enum.BagIndex.AccountBankTab_2) or 13,
    (Enum.BagIndex and Enum.BagIndex.AccountBankTab_3) or 14,
    (Enum.BagIndex and Enum.BagIndex.AccountBankTab_4) or 15,
    (Enum.BagIndex and Enum.BagIndex.AccountBankTab_5) or 16,
}

local function TabIDs(bankType)
    local source = bankType == ACCOUNT and ACCOUNT_TABS or CHARACTER_TABS
    local purchased = #source
    if C_Bank and C_Bank.FetchNumPurchasedBankTabs then
        local ok,n=pcall(C_Bank.FetchNumPurchasedBankTabs,bankType)
        if ok and type(n)=="number" then purchased=math.min(#source,n) end
    end
    local out={}
    for i=1,purchased do out[#out+1]=source[i] end
    return out
end

local function HasFlag(value, flag)
    value=tonumber(value) or 0
    flag=tonumber(flag) or 0
    if bit and bit.band then return bit.band(value,flag)~=0 end
    if bit32 and bit32.band then return bit32.band(value,flag)~=0 end
    return value % (flag*2) >= flag
end

local function MaterialTabIDs()
    local out={}
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        local ok,data=pcall(C_Bank.FetchPurchasedBankTabData,CHARACTER)
        if ok and type(data)=="table" then
            for _,tab in ipairs(data) do
                if tab and tab.ID and HasFlag(tab.depositFlags,REAGENT_FLAG) then
                    out[#out+1]=tab.ID
                end
            end
        end
    end
    return out
end

local function NormalCharacterTabIDs()
    local material={}
    for _,id in ipairs(MaterialTabIDs()) do material[id]=true end
    local out={}
    for _,id in ipairs(TabIDs(CHARACTER)) do
        if not material[id] then out[#out+1]=id end
    end
    return out
end

local function BankSlotUsage(tabIDs)
    local used,total=0,0
    for _,bagID in ipairs(tabIDs or {}) do
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
    counter:SetSize(220,20)
    counter:SetFrameLevel(frameLevel)

    local bankIcon=counter:CreateTexture(nil,"ARTWORK")
    bankIcon:SetSize(18,18)
    bankIcon:SetPoint("LEFT",0,0)
    bankIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")

    local bankText=counter:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    bankText:SetPoint("LEFT",bankIcon,"RIGHT",3,0)
    bankText:SetJustifyH("LEFT")

    local materialIcon=counter:CreateTexture(nil,"ARTWORK")
    materialIcon:SetSize(18,18)
    materialIcon:SetPoint("LEFT",bankText,"RIGHT",9,0)
    materialIcon:SetTexture("Interface\\Icons\\INV_Enchant_DustIllusion")

    local materialText=counter:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    materialText:SetPoint("LEFT",materialIcon,"RIGHT",3,0)
    materialText:SetJustifyH("LEFT")

    counter.bankText=bankText
    counter.materialIcon=materialIcon
    counter.materialText=materialText
    f.slotCounter=counter
end

local function RefreshBankSlotCounter(f,mode)
    if not f or not f.slotCounter then return end
    local counter=f.slotCounter
    if mode==ACCOUNT then
        local used,total=BankSlotUsage(TabIDs(ACCOUNT))
        counter.bankText:SetText(used.."/"..total)
        counter.materialIcon:Hide()
        counter.materialText:Hide()
        return
    end

    local bankUsed,bankTotal=BankSlotUsage(NormalCharacterTabIDs())
    local materialTabs=MaterialTabIDs()
    local materialUsed,materialTotal=BankSlotUsage(materialTabs)
    counter.bankText:SetText(bankUsed.."/"..bankTotal)
    counter.materialIcon:SetShown(#materialTabs>0)
    counter.materialText:SetShown(#materialTabs>0)
    if #materialTabs>0 then counter.materialText:SetText(materialUsed.."/"..materialTotal) end
end

local function SelectBlizzardBank(bankType, selectedTabID)
    local realType = bankType == MATERIALS and CHARACTER or bankType
    local tabs = realType == ACCOUNT and ACCOUNT_TABS or CHARACTER_TABS
    local selected = selectedTabID or tabs[1]
    local bankFrame = _G.BankFrame
    local panel = _G.BankPanel

    if bankFrame and bankFrame.SetTab then
        local tabButtonID = realType == ACCOUNT and bankFrame.accountBankTabID or bankFrame.characterBankTabID
        if tabButtonID then pcall(bankFrame.SetTab, bankFrame, tabButtonID) end
    elseif panel and panel.SetBankType then
        pcall(panel.SetBankType, panel, realType)
    end

    if panel and selected then
        if panel.SetSelectedTabID then
            pcall(panel.SetSelectedTabID, panel, selected)
        else
            panel.selectedTabID = selected
        end
        if not panel:IsShown() then panel:Show() end
    end
    if SB and SB.SuppressNativeBank then SB:SuppressNativeBank() end
    return selected
end

local function PhysicalGroup(bankType,bagID,slotID,info)
    local itemID=info.itemID
    local _,_,_,equipLoc,_,classID,subClassID=C_Item.GetItemInfoInstant(itemID)
    return {key="wagbank:"..bagID..":"..slotID,itemID=itemID,
      itemName=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or C_Item.GetItemInfo(itemID),
      count=info.stackCount or 1,physicalSlots=1,itemLink=info.hyperlink,iconFileID=info.iconFileID,
      quality=info.quality,itemEquipLoc=equipLoc,classID=classID,subClassID=subClassID,
      slots={{bagID=bagID,slotID=slotID,stackCount=info.stackCount or 1}},
      nonStackableEquipment=SB:IsNonStackableEquipment(itemID),isBankItem=true,bankType=bankType}
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

    f:SetAlpha(0)
    DisableNativeBankMouseTree(f)

    if not self._nativeBankSuppressed then
        f:HookScript("OnShow",function(x)
            x:SetAlpha(0)
            DisableNativeBankMouseTree(x)
        end)
        self._nativeBankSuppressed=true
    end
end

local function MoneyText(copper)
    copper=tonumber(copper) or 0
    local g=math.floor(copper/10000)
    local sil=math.floor((copper%10000)/100)
    local c=copper%100
    return string.format("%d|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:0:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:0:0|t %d|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:0:0|t",g,sil,c)
end

function SB:CreateBankFrame()
    if self.bankFrame then return self.bankFrame end
    local f=CreateFrame("Frame","WagBagBankFrame",UIParent,"BackdropTemplate")
    f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:SetMovable(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropBorderColor(.12,.12,.15,1)
    local l=Layout()
    if l.anchorModel==2 then f:SetPoint("CENTER",-220,0)
    elseif l.point then f:SetPoint(l.point,UIParent,l.relativePoint or l.point,l.x or 0,l.y or 0)
    else f:SetPoint("CENTER",-220,0) end

    local shield=CreateFrame("Frame",nil,f)
    shield:SetAllPoints(f)
    shield:SetFrameLevel(f:GetFrameLevel()+1)
    shield:EnableMouse(true)
    if shield.SetMouseClickEnabled then shield:SetMouseClickEnabled(true) end
    if shield.SetMouseMotionEnabled then shield:SetMouseMotionEnabled(true) end
    if shield.SetPropagateMouseClicks then shield:SetPropagateMouseClicks(false) end
    if shield.SetPropagateMouseMotion then shield:SetPropagateMouseMotion(false) end
    shield:SetScript("OnEnter",function() GameTooltip:Hide() end)
    shield:SetScript("OnMouseDown",function() end)
    shield:SetScript("OnMouseUp",function(_,button)
        if (button=="LeftButton" or button=="RightButton") and CursorHasItem() and SB.bankAccessOpen and not SB.bankPlacementActive then
            if SB:DropCursorItemIntoBank() then
                C_Timer.After(0,function() if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank() end end)
            end
        end
    end)
    f.mouseShield=shield
    local contentLevel=f:GetFrameLevel()+2

    local mover=CreateFrame("Frame",nil,f,"BackdropTemplate")
    mover:SetAllPoints(f)
    mover:SetFrameLevel(f:GetFrameLevel()+20)
    mover:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    mover:SetBackdropColor(.03,.20,.32,.32)
    mover:SetBackdropBorderColor(0,.65,1,1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart",function()
        if SB.bankPlacementActive then f:StartMoving() end
    end)
    mover:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
    end)
    local moverText=mover:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    moverText:SetPoint("CENTER")
    moverText:SetText(self:T("BANK_MOVER"))
    moverText:SetTextColor(1,.82,0,1)
    mover:Hide()
    f.placementMover=mover

    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",12,-12); title:SetText("WagBag")

    local searchBox=CreateFrame("EditBox",nil,f,"BackdropTemplate")
    searchBox:SetSize(132,20); searchBox:SetPoint("LEFT",title,"RIGHT",8,0); searchBox:SetAutoFocus(false); searchBox:SetFontObject("GameFontHighlight"); searchBox:SetTextInsets(6,18,0,0); searchBox:EnableMouse(true); searchBox:SetFrameLevel(f:GetFrameLevel()+4)
    searchBox:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); searchBox:SetBackdropColor(.035,.035,.045,.96); searchBox:SetBackdropBorderColor(.16,.16,.20,1)
    local placeholder=searchBox:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); placeholder:SetPoint("LEFT",6,0); placeholder:SetText(self:T("SEARCH"))
    local clear=CreateFrame("Button",nil,searchBox); clear:SetSize(14,14); clear:SetPoint("RIGHT",-2,0); clear:SetFrameLevel(searchBox:GetFrameLevel()+1)
    local clearText=clear:CreateFontString(nil,"OVERLAY","GameFontNormal"); clearText:SetPoint("CENTER"); clearText:SetText("×"); clear:Hide()
    searchBox:SetScript("OnTextChanged",function(box) local text=box:GetText() or ""; placeholder:SetShown(text==""); clear:SetShown(text~=""); SB.bankSearchText=text; if f:IsShown() and SB.bankAccessOpen then SB:RefreshBank() end end)
    searchBox:SetScript("OnEscapePressed",function(box) box:ClearFocus() end); searchBox:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
    clear:SetScript("OnClick",function() searchBox:SetText(""); searchBox:ClearFocus() end); f.searchBox=searchBox

    local char=FlatBankButton(f,self:T("BANK"),82)
    char:SetFrameLevel(contentLevel); char:SetPoint("TOPLEFT",12,-36)
    local reagent=FlatBankButton(f,self:T("MATERIALS_BANK"),92)
    reagent:SetFrameLevel(contentLevel); reagent:SetPoint("LEFT",char,"RIGHT",5,0)
    local war=FlatBankButton(f,self:T("WARBAND"),82)
    war:SetFrameLevel(contentLevel); war:SetPoint("LEFT",reagent,"RIGHT",5,0)
    char:SetScript("OnClick",function()
        SB.bankMode=CHARACTER
        SelectBlizzardBank(CHARACTER)
        SB:RefreshBank()
    end)
    reagent:SetScript("OnClick",function()
        SB.bankMode=MATERIALS
        local tabs=MaterialTabIDs()
        SelectBlizzardBank(MATERIALS,tabs[1])
        SB:RefreshBank()
    end)
    war:SetScript("OnClick",function()
        SB.bankMode=ACCOUNT
        SelectBlizzardBank(ACCOUNT)
        SB:RefreshBank()
    end)

    local gold=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    gold:SetPoint("LEFT",war,"RIGHT",12,0); gold:Hide(); f.goldText=gold

    local deposit=FlatBankButton(f,self:T("DEPOSIT"),62)
    deposit:SetFrameLevel(contentLevel); deposit:SetPoint("LEFT",gold,"RIGHT",10,0)
    deposit:SetScript("OnClick",function()
        if SB.bankMode~=ACCOUNT or not C_Bank or not C_Bank.DepositMoney then return end
        StaticPopup_Show("WAGBAG_DEPOSIT_GOLD")
    end)
    local withdraw=FlatBankButton(f,self:T("WITHDRAW"),62)
    withdraw:SetFrameLevel(contentLevel); withdraw:SetPoint("LEFT",deposit,"RIGHT",4,0)
    withdraw:SetScript("OnClick",function()
        if SB.bankMode~=ACCOUNT or not C_Bank or not C_Bank.WithdrawMoney then return end
        StaticPopup_Show("WAGBAG_WITHDRAW_GOLD")
    end)
    f.charButton=char
    f.materialsViewButton=reagent
    f.warButton=war
    f.depositGold=deposit
    f.withdrawGold=withdraw

    local close=self:CreateHeaderCloseButton(f,function()
        if C_Bank and C_Bank.CloseBankFrame then C_Bank.CloseBankFrame()
        elseif _G.CloseBankFrame then _G.CloseBankFrame() end
    end)
    close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-3,-7)
    close:SetFrameLevel(contentLevel)
    f.closeButton=close

    local function StyleHeaderButton(button)
        if not button.SetBackdrop then
            Mixin(button, BackdropTemplateMixin)
        end
        button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        button:SetBackdropColor(.035,.035,.045,.96)
        button:SetBackdropBorderColor(.16,.16,.20,1)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    end

    local sort=CreateFrame("Button",nil,f,"BackdropTemplate")
    sort:SetSize(22,22); sort:SetFrameLevel(contentLevel); sort:SetPoint("RIGHT",close,"LEFT",-2,0)
    StyleHeaderButton(sort)
    local bh=sort:CreateTexture(nil,"ARTWORK")
    bh:SetTexture("Interface\\Buttons\\WHITE8X8"); bh:SetSize(3,17); bh:SetPoint("CENTER",2,1)
    bh:SetVertexColor(.72,.45,.16,1); bh:SetRotation(-.58)
    local bb=sort:CreateTexture(nil,"OVERLAY")
    bb:SetTexture("Interface\\Buttons\\WHITE8X8"); bb:SetSize(10,7); bb:SetPoint("CENTER",-4,-5)
    bb:SetVertexColor(1,.78,.05,1); bb:SetRotation(-.58)
    sort:SetScript("OnClick",function()
        local mode=SB.bankMode or CHARACTER
        if mode==ACCOUNT then
            if C_Container.SortBank then C_Container.SortBank(ACCOUNT)
            elseif C_Container.SortAccountBankBags then C_Container.SortAccountBankBags() end
        else
            if C_Container.SortBank then C_Container.SortBank(CHARACTER)
            elseif C_Container.SortBankBags then C_Container.SortBankBags() end
        end
    end)
    sort:SetScript("OnEnter",function(x) GameTooltip:SetOwner(x,"ANCHOR_BOTTOM"); GameTooltip:SetText(self:T("SORT_BANK")); GameTooltip:Show() end)
    sort:SetScript("OnLeave",GameTooltip_Hide)
    f.sortButton=sort

    local materials=CreateFrame("Button",nil,f,"BackdropTemplate")
    materials:SetSize(22,22); materials:SetFrameLevel(contentLevel); materials:SetPoint("RIGHT",sort,"LEFT",-4,0)
    StyleHeaderButton(materials)
    local materialsIcon=materials:CreateTexture(nil,"ARTWORK")
    materialsIcon:SetAllPoints()
    materialsIcon:SetTexture("Interface\\Icons\\INV_Enchant_DustIllusion")
    materials:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    materials:SetScript("OnClick",function()
        if C_Bank and C_Bank.AutoDepositItemsIntoBank then
            C_Bank.AutoDepositItemsIntoBank(CHARACTER)
        elseif _G.DepositReagentBank then
            _G.DepositReagentBank()
        end
    end)
    materials:SetScript("OnEnter",function(x)
        GameTooltip:SetOwner(x,"ANCHOR_BOTTOM")
        GameTooltip:SetText(self:T("DEPOSIT_REAGENTS"))
        GameTooltip:Show()
    end)
    materials:SetScript("OnLeave",GameTooltip_Hide)
    f.materialsButton=materials

    local purchase=CreateFrame("Button",nil,f,"BankPanelPurchaseButtonScriptTemplate,BackdropTemplate")
    purchase:SetSize(22,22); purchase:SetFrameLevel(contentLevel); purchase:SetPoint("RIGHT",materials,"LEFT",-4,0)
    StyleHeaderButton(purchase)
    local purchaseIcon=purchase:CreateTexture(nil,"ARTWORK")
    purchaseIcon:SetAllPoints()
    purchaseIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    purchase:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    purchase:SetScript("OnEnter",function(x)
        GameTooltip:SetOwner(x,"ANCHOR_BOTTOM")
        GameTooltip:SetText(self:T("BUY_SLOT"))
        GameTooltip:Show()
    end)
    purchase:SetScript("OnLeave",GameTooltip_Hide)
    f.purchaseButton=purchase
    CreateBankSlotCounter(f,contentLevel)

    f.itemButtons={}; f.bankButtonsBySlot={}; f.emptySlots={}
    self.bankFrame=f
    return f
end

local function GoldPopup(name,label,fn)
    StaticPopupDialogs[name]={
      text=label,button1=ACCEPT,button2=CANCEL,hasEditBox=true,
      OnShow=function(self) self.EditBox:SetText(""); self.EditBox:SetFocus() end,
      OnAccept=function(self)
        local gold=tonumber(self.EditBox:GetText())
        if gold and gold>0 then fn(math.floor(gold*10000)) end
      end,
      EditBoxOnEnterPressed=function(self)
        local p=self:GetParent(); local gold=tonumber(self:GetText())
        if gold and gold>0 then fn(math.floor(gold*10000)) end
        p:Hide()
      end,
      timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3}
end
GoldPopup("WAGBAG_DEPOSIT_GOLD",SB:T("DEPOSIT_GOLD_PROMPT"),function(v) C_Bank.DepositMoney(ACCOUNT,v) end)
GoldPopup("WAGBAG_WITHDRAW_GOLD",SB:T("WITHDRAW_GOLD_PROMPT"),function(v) C_Bank.WithdrawMoney(ACCOUNT,v) end)

local function ClearPhysicalBankCell(w,bagID,slotID)
    w.group=nil
    w:SetID(bagID); w.nativeButton:SetID(slotID)
    w.nativeButton:SetAlpha(1)
    w.icon:SetTexture(nil); w.icon:SetDesaturated(false)
    if w.countText then
        if not w.countText:GetFont() then w.countText:SetFont(STANDARD_TEXT_FONT,12,"OUTLINE") end
        w.countText:SetText("")
    end
    if w.itemLevelText then
        if not w.itemLevelText:GetFont() then w.itemLevelText:SetFont(STANDARD_TEXT_FONT,12,"OUTLINE") end
        w.itemLevelText:SetText("")
    end
    if w.junkCoin then w.junkCoin:Hide() end
    if w.cooldownText then w.cooldownText:Hide() end
    w.cooldownEnd=nil; w:SetScript("OnUpdate",nil)
    local overlay=w.CanIMogItOverlay or (w.nativeButton and w.nativeButton.CanIMogItOverlay)
    if overlay then overlay:Hide() end
    if w.background then w.background:SetColorTexture(.050,.050,.060,.92) end
    if w.qualityBorder then
        for _,tex in pairs(w.qualityBorder) do tex:SetColorTexture(0,0,0,0) end
    end
    if w.nativeButton then
        if w.nativeButton.IconBorder then w.nativeButton.IconBorder:Hide() end
        if w.nativeButton.NewItemTexture then w.nativeButton.NewItemTexture:Hide() end
        if w.nativeButton.BattlepayItemTexture then w.nativeButton.BattlepayItemTexture:Hide() end
        w.nativeButton:UnlockHighlight()
    end
    w:SetAlpha(1); w:Show()
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
    block:SetBackdropColor(.018,.018,.024,.72)
    block:SetBackdropBorderColor(.13,.13,.17,1)
    block:SetFrameLevel(f:GetFrameLevel()+2)
    local titleHandle=CreateFrame("Button",nil,block)
    titleHandle:SetPoint("TOPLEFT",1,-1)
    titleHandle:SetPoint("TOPRIGHT",-1,-1)
    titleHandle:SetHeight(BANK_BLOCK_TITLE_HEIGHT)
    titleHandle:RegisterForDrag("LeftButton")
    titleHandle:SetScript("OnDragStart",function(handle)
        if not SB.db.layout.locked and handle.categoryKey then SB:BeginCategoryOrderDrag(handle.categoryKey) end
    end)
    local title=titleHandle:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("LEFT",BANK_BLOCK_PADDING-1,0)
    title:SetTextColor(1,.82,0,1)
    block.titleHandle=titleHandle
    block.title=title
    f.categoryFrames[index]=block
    return block
end

local function HideBankCategoryFrames(f,fromIndex)
    if not f.categoryFrames then return end
    for i=fromIndex,#f.categoryFrames do f.categoryFrames[i]:Hide() end
end

local function FirstEmptyBankSlot(displayTabs)
    for _,bagID in ipairs(displayTabs) do
        for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
            if not C_Container.GetContainerItemInfo(bagID,slotID) then return bagID,slotID end
        end
    end
end

function SB:DropCursorItemIntoBank()
    if not self.bankAccessOpen or not CursorHasItem() then return false end
    local mode=self.bankMode or CHARACTER
    local displayTabs
    if mode==MATERIALS then
        displayTabs=MaterialTabIDs()
    elseif mode==CHARACTER then
        displayTabs=NormalCharacterTabIDs()
        if not Layout().separateMaterials then
            for _,id in ipairs(MaterialTabIDs()) do displayTabs[#displayTabs+1]=id end
        end
    else
        displayTabs=TabIDs(ACCOUNT)
    end
    local bagID,slotID=FirstEmptyBankSlot(displayTabs)
    if not bagID then return false end
    C_Container.PickupContainerItem(bagID,slotID)
    return true
end

local function RefreshCategorizedCharacterBank(self,f,displayTabs,l)
    local groups={}
    local live={}
    for _,bagID in ipairs(displayTabs) do
        for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
            local info=C_Container.GetContainerItemInfo(bagID,slotID)
            if info and info.itemID then groups[#groups+1]=PhysicalGroup(CHARACTER,bagID,slotID,info) end
        end
    end

    local categories=self:BuildCategoryBuckets(groups,true)
    local requestedCells=math.max(6,math.min(30,math.floor(tonumber(l.cellsPerRow) or 18)))
    local blocks=math.max(1,math.min(4,math.floor(tonumber(l.blocksPerRow) or 2)))
    local usableCells=requestedCells-(requestedCells%blocks)
    local cells=math.max(1,math.floor(usableCells/blocks))
    local blockWidth=BANK_BLOCK_PADDING*2+cells*self.SLOT_SIZE+math.max(0,cells-1)*self.SLOT_SPACING
    local scale=math.max(.5,math.min(2,tonumber(l.scale) or 1))
    local heightLimit=(UIParent:GetHeight() or 768)*.66/scale
    local startY=70
    local x=BANK_WINDOW_PADDING
    local y=startY
    local maxBottom=startY
    local maxRight=BANK_WINDOW_PADDING+blockWidth
    local categoryIndex=0
    local buttonIndex=0

    local emptyBag,emptySlot=FirstEmptyBankSlot(displayTabs)
    if #categories==0 and emptyBag then
        categories={{key="misc",name=self:GetCategoryName("misc"),items={}}}
    end

    for categoryPos,category in ipairs(categories) do
        local itemCount=#category.items
        local addEmpty=(categoryPos==#categories and emptyBag~=nil) and 1 or 0
        local visualCount=itemCount+addEmpty
        local rows=math.max(1,math.ceil(math.max(1,visualCount)/cells))
        local h=BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+rows*self.SLOT_SIZE+math.max(0,rows-1)*self.SLOT_SPACING+BANK_BLOCK_PADDING
        if y+h+12>heightLimit and y>startY then
            x=x+blockWidth+BANK_BLOCK_GAP
            y=startY
        end
        categoryIndex=categoryIndex+1
        local block=AcquireBankCategoryFrame(f,categoryIndex)
        block.categoryKey=category.noReorder and nil or category.key
        block.titleHandle.categoryKey=block.categoryKey
        block.title:SetText(category.name)
        block:SetSize(blockWidth,h)
        block:ClearAllPoints(); block:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y)

        for itemIndex,group in ipairs(category.items) do
            buttonIndex=buttonIndex+1
            local key=group.key
            live[key]=true
            local w=f.bankButtonsBySlot[key]
            if not w then
                w=self:CreateBankItemButton(block)
                w:SetFrameLevel(block:GetFrameLevel()+1)
                if w.nativeButton then w.nativeButton:SetFrameLevel(w:GetFrameLevel()+1) end
                f.bankButtonsBySlot[key]=w
                f.itemButtons[#f.itemButtons+1]=w
            else w:SetParent(block) end
            w.disableCategoryDrag=false
            local col=(itemIndex-1)%cells
            local row=math.floor((itemIndex-1)/cells)
            w:ClearAllPoints(); w:SetPoint("TOPLEFT",block,"TOPLEFT",BANK_BLOCK_PADDING+col*(self.SLOT_SIZE+self.SLOT_SPACING),-(BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+row*(self.SLOT_SIZE+self.SLOT_SPACING)))
            self:BindItemButton(w,group)
            local searching=strtrim(self.bankSearchText or "")~=""
            w:SetAlpha((not searching or self:GroupMatchesSearch(group,self.bankSearchText)) and 1 or .22)
            w:Show()
        end

        if addEmpty==1 then
            local key="empty:"..emptyBag..":"..emptySlot
            live[key]=true
            local w=f.bankButtonsBySlot[key]
            if not w then
                w=self:CreateBankItemButton(block)
                w:SetFrameLevel(block:GetFrameLevel()+1)
                if w.nativeButton then w.nativeButton:SetFrameLevel(w:GetFrameLevel()+1) end
                f.bankButtonsBySlot[key]=w
                f.itemButtons[#f.itemButtons+1]=w
            else w:SetParent(block) end
            w.disableCategoryDrag=true
            local itemIndex=itemCount+1
            local col=(itemIndex-1)%cells
            local row=math.floor((itemIndex-1)/cells)
            w:ClearAllPoints(); w:SetPoint("TOPLEFT",block,"TOPLEFT",BANK_BLOCK_PADDING+col*(self.SLOT_SIZE+self.SLOT_SPACING),-(BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+row*(self.SLOT_SIZE+self.SLOT_SPACING)))
            ClearPhysicalBankCell(w,emptyBag,emptySlot)
        end

        y=y+h+BANK_BLOCK_GAP
        maxBottom=math.max(maxBottom,y)
        maxRight=math.max(maxRight,x+blockWidth)
    end

    HideBankCategoryFrames(f,categoryIndex+1)
    for key,w in pairs(f.bankButtonsBySlot) do if not live[key] then w:Hide() end end
    f:SetSize(maxRight+BANK_WINDOW_PADDING,math.max(136,maxBottom+20))
end

function SB:RefreshBankMoney()
    local f=self.bankFrame
    if not f or not f:IsShown() or (self.bankMode or CHARACTER)~=ACCOUNT then return end
    if C_Bank and C_Bank.FetchDepositedMoney then
        f.goldText:SetText(MoneyText(C_Bank.FetchDepositedMoney(ACCOUNT)))
    end
end

function SB:RefreshBank()
    if not self.bankAccessOpen then return end
    local f=self:CreateBankFrame()
    local mode=self.bankMode or CHARACTER
    local physicalMode=(mode==MATERIALS) and CHARACTER or mode
    local displayTabs
    if mode==MATERIALS then
        displayTabs=MaterialTabIDs()
    elseif mode==CHARACTER then
        displayTabs=NormalCharacterTabIDs()
        if not Layout().separateMaterials then
            for _,id in ipairs(MaterialTabIDs()) do displayTabs[#displayTabs+1]=id end
        end
    else
        displayTabs=TabIDs(physicalMode)
    end
    SelectBlizzardBank(mode,displayTabs[1])
    purchase = f.purchaseButton
    if purchase then
        purchase:SetAttribute("overrideBankType",physicalMode)
        local canBuy=mode~=MATERIALS and C_Bank and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(physicalMode)
        local atMax=C_Bank and C_Bank.HasMaxBankTabs and C_Bank.HasMaxBankTabs(physicalMode)
        purchase:SetEnabled(canBuy and not atMax)
        purchase:SetAlpha((canBuy and not atMax) and 1 or .45)
    end
    local l=Layout()
    f:SetScale(math.max(.5,math.min(2,tonumber(l.scale) or 1)))
    f:SetBackdropColor(.025,.025,.032,tonumber(l.backgroundAlpha) or .97)

    if mode==CHARACTER or mode==MATERIALS then
        RefreshCategorizedCharacterBank(self,f,displayTabs,l)
    else
        HideBankCategoryFrames(f,1)

    local cells=math.max(6,math.min(30,tonumber(l.cellsPerRow) or 18))
    local visual=0
    local live={}
    for _,bagID in ipairs(displayTabs) do
        for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
            visual=visual+1
            local col=(visual-1)%cells
            local row=math.floor((visual-1)/cells)
            local x=12+col*(self.SLOT_SIZE+self.SLOT_SPACING)
            local y=-(70+row*(self.SLOT_SIZE+self.SLOT_SPACING))
            local key=tostring(bagID)..":"..tostring(slotID)
            live[key]=true

            local w=f.bankButtonsBySlot[key]
            if not w then
                w=self:CreateBankItemButton(f)
                w:SetFrameLevel(f:GetFrameLevel()+3)
                if w.nativeButton then w.nativeButton:SetFrameLevel(w:GetFrameLevel()+1) end
                f.bankButtonsBySlot[key]=w
                f.itemButtons[#f.itemButtons+1]=w
            end
            w:ClearAllPoints(); w:SetPoint("TOPLEFT",f,"TOPLEFT",x,y)
            w:SetID(bagID); w.nativeButton:SetID(slotID)

            local info=C_Container.GetContainerItemInfo(bagID,slotID)
            if info and info.itemID then
                local overlay=w.CanIMogItOverlay or (w.nativeButton and w.nativeButton.CanIMogItOverlay)
                if overlay then overlay:Hide() end
                if w.nativeButton then w.nativeButton:UnlockHighlight() end
                w:SetAlpha(1)
                local group=PhysicalGroup(physicalMode,bagID,slotID,info)
                self:BindItemButton(w,group)
                local searching=strtrim(self.bankSearchText or "")~=""
                w:SetAlpha((not searching or self:GroupMatchesSearch(group,self.bankSearchText)) and 1 or .22)
                w._bankSig=nil
                if w.background then w.background:SetColorTexture(.08,.08,.08,.95) end
                w:Show()
            else
                ClearPhysicalBankCell(w,bagID,slotID)
                w._bankSig=false
            end
        end
    end

    for key,w in pairs(f.bankButtonsBySlot) do if not live[key] then w:Hide() end end

    local rows=math.max(1,math.ceil(math.max(visual,1)/cells))
    f:SetSize(24+cells*self.SLOT_SIZE+(cells-1)*self.SLOT_SPACING,
              82+rows*self.SLOT_SIZE+(rows-1)*self.SLOT_SPACING+24)
    end
    local separateMaterials=Layout().separateMaterials and true or false
    if mode==MATERIALS and not separateMaterials then mode=CHARACTER; self.bankMode=CHARACTER end
    RefreshBankSlotCounter(f,mode)
    f.charButton:SetActive(mode==CHARACTER)
    f.materialsViewButton:SetShown(separateMaterials)
    f.materialsViewButton:SetActive(mode==MATERIALS)
    f.materialsViewButton:ClearAllPoints()
    f.materialsViewButton:SetPoint("LEFT",f.charButton,"RIGHT",5,0)
    f.warButton:ClearAllPoints()
    f.warButton:SetPoint("LEFT",separateMaterials and f.materialsViewButton or f.charButton,"RIGHT",5,0)
    f.warButton:SetActive(mode==ACCOUNT)

    local isAccount=mode==ACCOUNT
    local isMaterials=mode==MATERIALS
    if f.materialsButton then f.materialsButton:SetShown(mode==CHARACTER or isMaterials) end
    if f.sortButton then f.sortButton:SetShown(true) end

    if f.sortButton then
        f.sortButton:ClearAllPoints()
        f.sortButton:SetPoint("RIGHT",f.closeButton,"LEFT",-2,0)
    end
    if f.materialsButton then
        f.materialsButton:ClearAllPoints()
        f.materialsButton:SetShown(mode==CHARACTER or isMaterials)
        if f.materialsButton:IsShown() then f.materialsButton:SetPoint("RIGHT",f.sortButton,"LEFT",-4,0) end
    end
    if f.purchaseButton then
        f.purchaseButton:ClearAllPoints()
        local previous=(f.materialsButton and f.materialsButton:IsShown()) and f.materialsButton or f.sortButton
        if previous and previous:IsShown() then f.purchaseButton:SetPoint("RIGHT",previous,"LEFT",-4,0) end
    end

    f.goldText:SetShown(isAccount); f.depositGold:SetShown(isAccount); f.withdrawGold:SetShown(isAccount)
    if isAccount then self:RefreshBankMoney() end

    local canBuy=false
    if C_Bank and C_Bank.CanPurchaseBankTab then
        local ok,v=pcall(C_Bank.CanPurchaseBankTab,physicalMode); canBuy=mode~=MATERIALS and ok and v and true or false
    end
    f.purchaseButton:SetShown(canBuy)
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
    self:SuppressNativeBank()
    self.bankMode=CHARACTER
    local tabs=(self.bankMode==MATERIALS) and MaterialTabIDs() or nil
    SelectBlizzardBank(self.bankMode,tabs and tabs[1])
    self:RefreshBank(); self.bankFrame:Show()
    if self.EnterBankSystemPanelMode then self:EnterBankSystemPanelMode() end
end
function SB:CloseBank()
    if self.bankPlacementActive then self:FinishBankPlacement() end
    self.bankMode=nil
    if self.bankFrame then self.bankFrame:Hide() end
    if self.ExitBankSystemPanelMode then self:ExitBankSystemPanelMode() end

    C_Timer.After(0, function()
        if SB.bankAccessOpen then return end

        local panel=_G.BankPanel
        if panel and panel:IsShown() then panel:Hide() end
        local native=_G.BankFrame
        if native and native:IsShown() then native:Hide() end
    end)
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
    if self.bankAccessOpen then self:RefreshBank() end
end

function SB:ApplyNativeBankAppearance() if self.bankFrame then self:RefreshBank() end end

function SB:ApplyBankAnchor(anchor)
    local f=self.bankFrame
    if not f or not f:IsShown() then return end
    local l=Layout()
    anchor=anchor or l.anchor or "TOPLEFT"
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
            local function Offset(a)
                return a:find("RIGHT") and w or 0,a:find("TOP") and h or 0
            end
            local ox,oy=Offset(oldAnchor)
            local nx,ny=Offset(anchor)
            self:SetBankAnchorPosition(l.x+(nx-ox),l.y+(ny-oy))
        end
        l.anchor=anchor
        self:AttachBankFrameToAnchor(anchor)
        return
    end
    local x,y=self:GetBankFramePointInUIParent(anchor)
    if x==nil or y==nil then return end
    l.anchor=anchor
    self:SetBankAnchorPosition(x,y)
    self:AttachBankFrameToAnchor(anchor)
end


function SB:ToggleBankPlacement()
    if not self.bankAccessOpen or not self.bankFrame or not self.bankFrame:IsShown() then
        self:Print(self:T("OPEN_BANK_TO_MOVE"))
        return
    end
    local f=self.bankFrame
    if self.bankPlacementActive then
        f:StopMovingOrSizing()
        self:ApplyBankAnchor(Layout().anchor)
        self.bankPlacementActive=false
        if f.placementMover then f.placementMover:Hide() end
    else
        self.bankPlacementActive=true
        if f.placementMover then f.placementMover:Show() end
    end
    self:RefreshBankSettingsValues()
end

function SB:FinishBankPlacement()
    if not self.bankPlacementActive then return end
    local f=self.bankFrame
    self.bankPlacementActive=false
    if f then
        f:StopMovingOrSizing()
        if f:IsShown() then self:ApplyBankAnchor(Layout().anchor) end
        if f.placementMover then f.placementMover:Hide() end
    end
    self:RefreshBankSettingsValues()
end
