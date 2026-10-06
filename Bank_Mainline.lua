local ADDON_NAME, SB = ...

local CHARACTER = (Enum.BankType and Enum.BankType.Character) or 0
local ACCOUNT   = (Enum.BankType and Enum.BankType.Account) or 2
local MATERIALS = "materials"
local REAGENT_FLAG = (Enum.BagSlotFlags and Enum.BagSlotFlags.ClassReagents) or 0x80

local function Layout()
    local l=SB.db.bankLayout
    if l.scale==nil then l.scale=1 end
    if l.backgroundAlpha==nil then l.backgroundAlpha=.97 end
    if l.cellsPerRow==nil then l.cellsPerRow=18 end
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
    f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropBorderColor(.12,.12,.15,1)
    local l=Layout()
    if l.point then f:SetPoint(l.point,UIParent,l.relativePoint or l.point,l.x or 0,l.y or 0)
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
    shield:SetScript("OnMouseUp",function() end)
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
    searchBox:SetScript("OnTextChanged",function(box) local text=box:GetText() or ""; placeholder:SetShown(text==""); clear:SetShown(text~=""); SB.bankSearchText=text; if f:IsShown() then SB:RefreshBank() end end)
    searchBox:SetScript("OnEscapePressed",function(box) box:ClearFocus() end); searchBox:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
    clear:SetScript("OnClick",function() searchBox:SetText(""); searchBox:ClearFocus() end); f.searchBox=searchBox

    local char=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    char:SetSize(82,22); char:SetFrameLevel(contentLevel) char:SetPoint("TOPLEFT",12,-36); char:SetText(self:T("BANK"))
    local reagent=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    reagent:SetSize(92,22); reagent:SetFrameLevel(contentLevel); reagent:SetPoint("LEFT",char,"RIGHT",5,0); reagent:SetText(self:T("MATERIALS_BANK"))
    local war=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    war:SetSize(82,22); war:SetFrameLevel(contentLevel); war:SetPoint("LEFT",reagent,"RIGHT",5,0); war:SetText(self:T("WARBAND"))
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

    local deposit=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    deposit:SetSize(62,22); deposit:SetFrameLevel(contentLevel) deposit:SetPoint("LEFT",gold,"RIGHT",10,0); deposit:SetText(self:T("DEPOSIT"))
    deposit:SetScript("OnClick",function()
        if SB.bankMode~=ACCOUNT or not C_Bank or not C_Bank.DepositMoney then return end
        StaticPopup_Show("WAGBAG_DEPOSIT_GOLD")
    end)
    local withdraw=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    withdraw:SetSize(62,22); withdraw:SetFrameLevel(contentLevel) withdraw:SetPoint("LEFT",deposit,"RIGHT",4,0); withdraw:SetText(self:T("WITHDRAW"))
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

function SB:RefreshBankMoney()
    local f=self.bankFrame
    if not f or not f:IsShown() or (self.bankMode or CHARACTER)~=ACCOUNT then return end
    if C_Bank and C_Bank.FetchDepositedMoney then
        f.goldText:SetText(MoneyText(C_Bank.FetchDepositedMoney(ACCOUNT)))
    end
end

function SB:RefreshBank()
    local f=self:CreateBankFrame()
    local mode=self.bankMode or CHARACTER
    local physicalMode=(mode==MATERIALS) and CHARACTER or mode
    local displayTabs
    if mode==MATERIALS then
        displayTabs=MaterialTabIDs()
    elseif mode==CHARACTER then
        displayTabs=NormalCharacterTabIDs()
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
              82+rows*self.SLOT_SIZE+(rows-1)*self.SLOT_SPACING+12)
    f.charButton:SetEnabled(mode~=CHARACTER)
    f.materialsViewButton:SetEnabled(mode~=MATERIALS)
    f.warButton:SetEnabled(mode~=ACCOUNT)

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
end

function SB:OpenBank()
    self._nativePurchaseMode=false
    self:SuppressNativeBank()
    self.bankMode=CHARACTER
    local tabs=(self.bankMode==MATERIALS) and MaterialTabIDs() or nil
    SelectBlizzardBank(self.bankMode,tabs and tabs[1])
    self:RefreshBank(); self.bankFrame:Show()
end
function SB:CloseBank()
    self.bankMode=nil
    if self.bankFrame then self.bankFrame:Hide() end

    C_Timer.After(0, function()
        if SB.bankAccessOpen then return end

        local panel=_G.BankPanel
        if panel and panel:IsShown() then panel:Hide() end
        local native=_G.BankFrame
        if native and native:IsShown() then native:Hide() end
    end)
end
function SB:InstallBankHooks() self:SuppressNativeBank() end
function SB:ApplyNativeBankAppearance() if self.bankFrame then self:RefreshBank() end end

function SB:ApplyBankAnchor(anchor)
    local f=self.bankFrame
    if not f or not f:IsShown() then return end
    local l=Layout()
    anchor=anchor or l.anchor or "TOPLEFT"
    l.anchor=anchor

    local left,top,right,bottom=f:GetLeft(),f:GetTop(),f:GetRight(),f:GetBottom()
    if not left or not top or not right or not bottom then return end
    local uiScale=UIParent:GetEffectiveScale()
    local fScale=f:GetEffectiveScale()
    f:ClearAllPoints()
    if anchor=="TOPRIGHT" then
        local x=(right*fScale-UIParent:GetRight()*uiScale)/uiScale
        local y=(top*fScale-UIParent:GetTop()*uiScale)/uiScale
        f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",x,y)
    elseif anchor=="BOTTOMLEFT" then
        local x=(left*fScale-UIParent:GetLeft()*uiScale)/uiScale
        local y=(bottom*fScale-UIParent:GetBottom()*uiScale)/uiScale
        f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
    elseif anchor=="BOTTOMRIGHT" then
        local x=(right*fScale-UIParent:GetRight()*uiScale)/uiScale
        local y=(bottom*fScale-UIParent:GetBottom()*uiScale)/uiScale
        f:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",x,y)
    else
        local x=(left*fScale-UIParent:GetLeft()*uiScale)/uiScale
        local y=(top*fScale-UIParent:GetTop()*uiScale)/uiScale
        f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,y)
    end
    local point,_,relativePoint,x,y=f:GetPoint(1)
    l.point=point; l.relativePoint=relativePoint; l.x=x; l.y=y
end

function SB:ToggleBankPlacement()
    local f=self.bankFrame
    if not f or not f:IsShown() then
        self.bankPlacementActive=false
        self:Print(self:T("OPEN_BANK_TO_MOVE"))
        self:RefreshBankSettingsValues()
        return
    end
    local l=Layout()
    if self.bankPlacementActive then
        f:StopMovingOrSizing(); f:SetMovable(false)
        self.bankPlacementActive=false
        if f.placementMover then f.placementMover:Hide() end
        self:ApplyBankAnchor(l.anchor)
    else
        f:SetMovable(true); self.bankPlacementActive=true
        if f.placementMover then f.placementMover:Show() end
    end
    self:RefreshBankSettingsValues()
end

function SB:FinishBankPlacement()
    if not self.bankPlacementActive then return end
    local f=self.bankFrame
    self.bankPlacementActive=false
    if not f or not f:IsShown() then
        self:RefreshBankSettingsValues()
        return
    end
    f:StopMovingOrSizing(); f:SetMovable(false)
    if f.placementMover then f.placementMover:Hide() end
    self:ApplyBankAnchor(Layout().anchor)
    self:RefreshBankSettingsValues()
end
