local _, SB = ...

local CHARACTER = (Enum.BankType and Enum.BankType.Character) or 0
local ACCOUNT   = (Enum.BankType and Enum.BankType.Account) or 2
local MATERIALS = "materials"
local REAGENT_FLAG = (Enum.BagSlotFlags and Enum.BagSlotFlags.ClassReagents) or 0x80

local function BankIsUsable(bankType)
    if C_Bank and C_Bank.CanUseBank then
        local ok, usable = pcall(C_Bank.CanUseBank, bankType)
        if ok and type(usable) == "boolean" then return usable end
    end
    if C_Bank and C_Bank.FetchViewableBankTypes then
        local ok, types = pcall(C_Bank.FetchViewableBankTypes)
        if ok and type(types) == "table" then
            for _, value in ipairs(types) do
                if value == bankType then return true end
            end
            return false
        end
    end
    return nil
end

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
    if bankType==ACCOUNT and C_Bank and C_Bank.FetchPurchasedBankTabIDs then
        local ok,ids=pcall(C_Bank.FetchPurchasedBankTabIDs,bankType)
        if ok and type(ids)=="table" then
            local verified={}
            local seen={}
            for _,id in ipairs(ids) do
                if type(id)=="number" and not seen[id] then
                    for _,allowed in ipairs(ACCOUNT_TABS) do
                        if id==allowed then
                            verified[#verified+1]=id
                            seen[id]=true
                            break
                        end
                    end
                end
            end
            return verified
        end
    end
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

function SB:GetTrackedBankTabIDs()
    return TabIDs(CHARACTER)
end

function SB:GetTrackedWarbandTabIDs()
    return TabIDs(ACCOUNT)
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

local function RefreshBankSlotCounter(f,mode,accountUsed,accountTotal)
    if not f or not f.slotCounter then return end
    local counter=f.slotCounter
    if mode==ACCOUNT then
         
         
        local used,total=accountUsed,accountTotal
        if used==nil or total==nil then used,total=BankSlotUsage(TabIDs(ACCOUNT)) end
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

     
     
     
    if SB._selectedNativeBankType == realType
        and SB._selectedNativeBankTab == selected
        and SB._selectedNativeBankFrame == bankFrame
        and SB._selectedNativeBankPanel == panel
        and panel and panel:IsShown() then
        return selected
    end

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
    SB._selectedNativeBankType = realType
    SB._selectedNativeBankTab = selected
    SB._selectedNativeBankFrame = bankFrame
    SB._selectedNativeBankPanel = panel
    return selected
end

local function PhysicalGroup(bankType,bagID,slotID,info)
    local itemID=info.itemID
    local static=SB:GetStaticItemInfo(itemID)
    local equipLoc,classID,subClassID=static.equipLoc,static.classID,static.subClassID
    return {key="wagbank:"..bagID..":"..slotID,itemID=itemID,
      itemName=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or C_Item.GetItemInfo(itemID),
      count=info.stackCount or 1,physicalSlots=1,itemLink=info.hyperlink,iconFileID=info.iconFileID,
      quality=info.quality,itemEquipLoc=equipLoc,classID=classID,subClassID=subClassID,
      slots={{bagID=bagID,slotID=slotID,stackCount=info.stackCount or 1}},
      nonStackableEquipment=static.nonStackable,isBankItem=true,bankType=bankType}
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
                C_Timer.After(0,function() if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank("Bank_Mainline.lua:280") end end)
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
    searchBox:SetScript("OnTextChanged",function(box) local text=box:GetText() or ""; placeholder:SetShown(text==""); clear:SetShown(text~=""); if not SB._syncingItemSearch then SB:SetUnifiedItemSearch(text) end end)
    searchBox:SetScript("OnEscapePressed",function(box) box:ClearFocus() end); searchBox:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
    clear:SetScript("OnClick",function() searchBox:SetText(""); searchBox:ClearFocus() end); f.searchBox=searchBox; self.bankSearchBox=searchBox
     
    if self.searchText and self.searchText ~= "" then
        self._syncingItemSearch=true
        searchBox:SetText(self.searchText)
        self._syncingItemSearch=false
        placeholder:Hide()
        clear:Show()
    end

    local char=FlatBankButton(f,self:T("BANK"),82)
    char:SetFrameLevel(contentLevel); char:SetPoint("TOPLEFT",12,-36)
    local reagent=FlatBankButton(f,self:T("MATERIALS_BANK"),92)
    reagent:SetFrameLevel(contentLevel); reagent:SetPoint("LEFT",char,"RIGHT",5,0)
    local war=FlatBankButton(f,self:T("WARBAND"),82)
    war:SetFrameLevel(contentLevel); war:SetPoint("LEFT",reagent,"RIGHT",5,0)
    char:SetScript("OnClick",function()
        if SB.bankCharacterAvailable == false then return end
        SB.bankMode=CHARACTER
        SelectBlizzardBank(CHARACTER)
        SB:RefreshBank("Bank_Mainline.lua:338")
    end)
    reagent:SetScript("OnClick",function()
        if SB.bankCharacterAvailable == false then return end
        SB.bankMode=MATERIALS
        local tabs=MaterialTabIDs()
        SelectBlizzardBank(MATERIALS,tabs[1])
        SB:RefreshBank("Bank_Mainline.lua:344")
    end)
    war:SetScript("OnClick",function()
        if SB.bankAccountAvailable == false then return end
        SB.bankMode=ACCOUNT
         
         
        local tabs=TabIDs(ACCOUNT)
        SB.warbandSelectedTab=tabs[1]
        SelectBlizzardBank(ACCOUNT,tabs[1])
        SB:RefreshBank("Bank_Mainline.lua:349")
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
             
             
             
            if SB.ResetBankVisualSlotSession then SB:ResetBankVisualSlotSession() end
            if SB.BeginWarbandRecentSort then SB:BeginWarbandRecentSort()
            elseif SB.ClearWarbandRecent then SB:ClearWarbandRecent() end
            if SB.RefreshBank then SB:RefreshBank("Bank_Mainline.lua:WarbandBroom") end
             
             
            if not (SB.WarbandHasLockedItems and SB:WarbandHasLockedItems()) then
                if C_Container.SortBank then C_Container.SortBank(ACCOUNT)
                elseif C_Container.SortAccountBankBags then C_Container.SortAccountBankBags() end
            end
        else
            SB:SortCharacterBank()
        end
    end)
    sort:SetScript("OnEnter",function(x) GameTooltip:SetOwner(x,"ANCHOR_BOTTOM"); GameTooltip:SetText(self:T("SORT_BANK")); GameTooltip:Show() end)
    sort:SetScript("OnLeave",GameTooltip_Hide)
    f.sortButton=sort
    local bankModeButton=self:CreateBankModeButton(f)
    bankModeButton:SetFrameLevel(contentLevel)
    bankModeButton:SetPoint("RIGHT",sort,"LEFT",-4,0)
    f.bankModeButton=bankModeButton

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

    f.itemButtons={}; f.bankButtonsBySlot={}; f.categoryItemButtons={}; f.emptySlots={}
    self.bankFrame=f
    return f
end

 
 
local function UpdateWarbandTabBar(self,f,tabIDs)
    f.warbandTabButtons=f.warbandTabButtons or {}
    local labels={}
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        local ok,tabs=pcall(C_Bank.FetchPurchasedBankTabData,ACCOUNT)
        if ok and type(tabs)=="table" then
            for _,data in ipairs(tabs) do
                if data and type(data.ID)=="number" then labels[data.ID]=data end
            end
        end
    end
    for i,tabID in ipairs(tabIDs) do
        local b=f.warbandTabButtons[i]
        if not b then
            b=FlatBankButton(f,"",90)
            b:SetFrameLevel(f:GetFrameLevel()+5)
            b.text:ClearAllPoints()
            b.text:SetPoint("LEFT",b,"LEFT",22,0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWidth(64)
            local icon=b:CreateTexture(nil,"ARTWORK")
            icon:SetSize(15,15)
            icon:SetPoint("LEFT",b,"LEFT",4,0)
            b.tabIcon=icon
            b:SetScript("OnClick",function(button)
                if not SB.bankAccessOpen or InCombatLockdown() then return end
                if SB.bankMode~=ACCOUNT or SB.warbandSelectedTab==button.bankTabID then return end
                SB.warbandSelectedTab=button.bankTabID
                SelectBlizzardBank(ACCOUNT,button.bankTabID)
                SB:RefreshBank("Bank_Mainline.lua:WarbandTabClick")
            end)
            b:SetScript("OnEnter",function(button)
                GameTooltip:SetOwner(button,"ANCHOR_BOTTOM")
                GameTooltip:SetText(button.bankTabName or tostring(button.bankTabID))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",GameTooltip_Hide)
            f.warbandTabButtons[i]=b
        end
        b.bankTabID=tabID
        local data=labels[tabID]
        b.bankTabName=(data and data.name and data.name~="" and data.name) or tostring(i)
        b:SetText(b.bankTabName)
        b.tabIcon:SetTexture((data and data.icon) or "Interface\\Icons\\INV_Misc_Bag_08")
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",f,"TOPLEFT",12+(i-1)*95,-67)
        b:SetActive(self.warbandSelectedTab==tabID)
        b:Show()
    end
    for i=#tabIDs+1,#f.warbandTabButtons do f.warbandTabButtons[i]:Hide() end
end

local function HideWarbandTabBar(f)
    for _,b in ipairs(f.warbandTabButtons or {}) do b:Hide() end
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

 
 
local function EnsureWarbandScroll(f)
    if f.warbandScroll then return f.warbandScroll,f.warbandScrollChild end
    local scroll=CreateFrame("ScrollFrame",nil,f)
    scroll:SetFrameLevel(f:GetFrameLevel()+2)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll)
    child:SetSize(1,1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnMouseWheel",function(self,delta)
        local limit=math.max(0,(child:GetHeight() or 0)-(self:GetHeight() or 0))
        local nextY=math.max(0,math.min(limit,(self:GetVerticalScroll() or 0)-delta*55))
        self:SetVerticalScroll(nextY)
    end)
     
    scroll:SetScript("OnMouseUp",function(_,button)
        if (button=="LeftButton" or button=="RightButton") and CursorHasItem()
            and SB.bankAccessOpen and not SB.bankPlacementActive then
            if SB:DropCursorItemIntoBank() then
                C_Timer.After(0,function()
                    if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then
                        SB:RefreshBank("Bank_Mainline.lua:WarbandScrollDrop")
                    end
                end)
            end
        end
    end)
    f.warbandScroll=scroll
    f.warbandScrollChild=child
    return scroll,child
end

local function AcquireBankCategoryFrame(f,index,parent)
    f.categoryFrames=f.categoryFrames or {}
    local block=f.categoryFrames[index]
    if block then
        if block:GetParent()~=parent then block:SetParent(parent) end
        block:Show()
        return block
    end
    block=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    block:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
     
     
    block:SetBackdropColor(0,0,0,0)
    block:SetBackdropBorderColor(0,0,0,0)
    block._wagBankNoBackdrop = true
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

local function RenderCategorizedBankGroups(self,f,groups,l,isWarband)
    groups=self:BuildBankDisplayGroups(groups,isWarband and ACCOUNT or CHARACTER)
    local recent=isWarband and self:WarbandRecentKeys(groups) or self:BankRecentKeys(groups)
    local categories=self:BuildCategoryBuckets(groups,true,recent)
    if self.ApplyBankVisualSlotSession then
        self:ApplyBankVisualSlotSession(categories,isWarband and ACCOUNT or (self.bankMode or CHARACTER))
    end
    local requestedCells=math.max(6,math.min(30,math.floor(tonumber(l.cellsPerRow) or 18)))
    local blocks=math.max(1,math.min(4,math.floor(tonumber(l.blocksPerRow) or 2)))
    local scale=math.max(.5,math.min(2,tonumber(l.scale) or 1))
    local screenWidth=(UIParent:GetWidth() or 1280)/scale
    local step=self.SLOT_SIZE+self.SLOT_SPACING
    local maxCells=math.max(1,math.floor((screenWidth-64-2*BANK_BLOCK_PADDING+self.SLOT_SPACING)/step))
    local cells=math.min(requestedCells,maxCells)
    local recentColumns=math.min(cells*blocks,maxCells)
    local startY=isWarband and 0 or 70
    local normalStartY=startY
    local recentWidth=0
    local normalLayouts={}
    local categoryIndex=0
    local buttonIndex=0
    local scroll,scrollChild
    local blockParent=f
    if isWarband then
        scroll,scrollChild=EnsureWarbandScroll(f)
        blockParent=scrollChild
        scroll:Show()
    elseif f.warbandScroll then
        f.warbandScroll:Hide()
    end
    for _,category in ipairs(categories) do
        if category.key=="__recent" then
            local count=#(category.visualItems or category.items)
            if count>0 then
                local rows=math.ceil(count/recentColumns)
                local height=BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING*2
                    +rows*self.SLOT_SIZE+math.max(0,rows-1)*self.SLOT_SPACING
                normalStartY=startY+height+BANK_BLOCK_GAP
            end
            break
        end
    end

    for _,category in ipairs(categories) do
        local displayItems=category.visualItems or category.items
        local itemCount=#displayItems
        local pinnedRecent=category.key=="__recent"
        local renderColumns=pinnedRecent and recentColumns or cells
         
         
        local rows=itemCount>0 and math.ceil(itemCount/renderColumns) or 0
        local h=BANK_BLOCK_TITLE_HEIGHT+2
        if rows>0 then
            h=BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+rows*self.SLOT_SIZE
                +math.max(0,rows-1)*self.SLOT_SPACING+BANK_BLOCK_PADDING
        end
        categoryIndex=categoryIndex+1
        local block=AcquireBankCategoryFrame(f,categoryIndex,blockParent)
        block.categoryKey=category.noReorder and nil or category.key
        block.titleHandle.categoryKey=block.categoryKey
        block.title:SetText(category.name)
        local shownCells=math.min(renderColumns,math.max(1,itemCount))
        local itemsWidth=BANK_BLOCK_PADDING*2+shownCells*self.SLOT_SIZE
            +math.max(0,shownCells-1)*self.SLOT_SPACING
        local titleWidth=math.ceil(block.title:GetStringWidth() or 0)+BANK_BLOCK_PADDING*2+4
        local width=math.max(itemsWidth,titleWidth)
        if pinnedRecent then
            recentWidth=width
            block:ClearAllPoints()
            block:SetPoint("TOPLEFT",blockParent,"TOPLEFT",isWarband and 0 or BANK_WINDOW_PADDING,-startY)
        else
            normalLayouts[#normalLayouts+1]={frame=block,width=width,height=h}
        end
        block:SetSize(width,h)

        for itemIndex,group in ipairs(displayItems) do
            if group then
                buttonIndex=buttonIndex+1
                local w=f.categoryItemButtons[buttonIndex]
                if not w then
                    w=self:CreateBankItemButton(block)
                    w:SetFrameLevel(block:GetFrameLevel()+1)
                    if w.nativeButton then w.nativeButton:SetFrameLevel(w:GetFrameLevel()+1) end
                    f.categoryItemButtons[buttonIndex]=w
                    f.itemButtons[#f.itemButtons+1]=w
                else
                    w:SetParent(block)
                end
                w.disableCategoryDrag=false
                local col=(itemIndex-1)%renderColumns
                local row=math.floor((itemIndex-1)/renderColumns)
                w:ClearAllPoints()
                w:SetPoint("TOPLEFT",block,"TOPLEFT",
                    BANK_BLOCK_PADDING+col*(self.SLOT_SIZE+self.SLOT_SPACING),
                    -(BANK_BLOCK_TITLE_HEIGHT+BANK_BLOCK_PADDING+row*(self.SLOT_SIZE+self.SLOT_SPACING)))
                self:BindItemButton(w,group)
                local searching=strtrim(self.bankSearchText or "")~=""
                w:SetAlpha((not searching or self:GroupMatchesSearch(group,self.bankSearchText)) and 1 or .22)
                w:Show()
            end
        end
    end

    HideBankCategoryFrames(f,categoryIndex+1)
    for i=buttonIndex+1,#f.categoryItemButtons do f.categoryItemButtons[i]:Hide() end
    for _,w in pairs(f.bankButtonsBySlot) do w:Hide() end
    local heightLimit=(UIParent:GetHeight() or 768)*.75/scale
    local xOffset=isWarband and 0 or BANK_WINDOW_PADDING
    local availableWidth=math.max(1,screenWidth-2*BANK_WINDOW_PADDING-36)
    local positions,contentWidth,contentBottom=self:PlanBankCategoryColumns(
        normalLayouts,blocks,availableWidth,normalStartY,
        heightLimit-(isWarband and 100 or 20),BANK_BLOCK_GAP)
    for _,entry in ipairs(positions) do
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT",blockParent,"TOPLEFT",entry.x+xOffset,-entry.y)
    end
    contentWidth=math.max(contentWidth,recentWidth)
    contentBottom=math.max(startY,contentBottom,normalStartY-(normalStartY>startY and BANK_BLOCK_GAP or 0))
    if isWarband then
        local heightCap=math.max(110,heightLimit-100)
        local viewportHeight=math.max(110,math.min(heightCap,contentBottom))
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT",f,"TOPLEFT",BANK_WINDOW_PADDING,-75)
        local viewportWidth=math.max(470,contentWidth)
        scroll:SetSize(viewportWidth,viewportHeight)
        scrollChild:SetSize(viewportWidth,math.max(viewportHeight,contentBottom))
        local scrollMax=math.max(0,contentBottom-viewportHeight)
        if (scroll:GetVerticalScroll() or 0)>scrollMax then scroll:SetVerticalScroll(scrollMax) end
        f:SetSize(BANK_WINDOW_PADDING*2+viewportWidth,75+viewportHeight+26)
    else
        f:SetSize(math.max(390,contentWidth+BANK_WINDOW_PADDING*2),math.max(136,contentBottom+20))
    end
end

local function RefreshCategorizedCharacterBank(self,f,displayTabs,l)
    local groups={}
    for _,bagID in ipairs(displayTabs) do
        for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
            local info=C_Container.GetContainerItemInfo(bagID,slotID)
            if info and info.itemID then groups[#groups+1]=PhysicalGroup(CHARACTER,bagID,slotID,info) end
        end
    end
    RenderCategorizedBankGroups(self,f,groups,l,false)
end

local function RefreshCategorizedWarband(self,f,allTabs,l)
    local groups={}
    local used,total=0,0
    local pendingRecent=self.warbandRecentPending and self.warbandRecentSnapshot
    local recentSnapshot=pendingRecent and {slots={}, totals={}} or nil
     
     
    for _,bagID in ipairs(allTabs) do
        local slots=C_Container.GetContainerNumSlots(bagID) or 0
        total=total+slots
        for slotID=1,slots do
            local info=C_Container.GetContainerItemInfo(bagID,slotID)
            if info and info.itemID then
                used=used+1
                if recentSnapshot then
                    local count = info.stackCount or 1
                    local key = tostring(bagID) .. ":" .. tostring(slotID)
                    recentSnapshot.slots[key] = {itemID = info.itemID, count = count}
                    recentSnapshot.totals[info.itemID] = (recentSnapshot.totals[info.itemID] or 0) + count
                end
                groups[#groups+1]=PhysicalGroup(ACCOUNT,bagID,slotID,info)
            end
        end
    end
    f._warbandUsed=used
    f._warbandTotal=total
    if recentSnapshot then self:PreviewWarbandRecentFromSnapshot(recentSnapshot) end
    RenderCategorizedBankGroups(self,f,groups,l,true)
end

function SB:RefreshBankMoney()
    local f=self.bankFrame
    if not f or not f:IsShown() or (self.bankMode or CHARACTER)~=ACCOUNT then return end
    if C_Bank and C_Bank.FetchDepositedMoney then
        f.goldText:SetText(MoneyText(C_Bank.FetchDepositedMoney(ACCOUNT)))
    end
end

function SB:RefreshBank(source)
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
        self.warbandSelectedTab=displayTabs[1]
    end
    SelectBlizzardBank(mode,mode==ACCOUNT and self.warbandSelectedTab or displayTabs[1])
     
     
     
    if mode==ACCOUNT and not self.warbandRecentSnapshot and self.BeginWarbandRecentSession then
        self:BeginWarbandRecentSession()
    end
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

     
     
    HideWarbandTabBar(f)

    if mode==CHARACTER or mode==MATERIALS then
        RefreshCategorizedCharacterBank(self,f,displayTabs,l)
    elseif mode==ACCOUNT then
        RefreshCategorizedWarband(self,f,displayTabs,l)
    else
         
         
        HideBankCategoryFrames(f,1)
        for _,w in ipairs(f.categoryItemButtons) do w:Hide() end

        local cells=math.max(6,math.min(30,tonumber(l.cellsPerRow) or 18))
        local visual=0
        local occupied=0
        local generation=(f._warbandRenderGeneration or 0)+1
        f._warbandRenderGeneration=generation
        local search=self.bankSearchText or ""
        local searching=strtrim(search)~=""
         
         
        local opts=self.db.items
        local appearance=table.concat({
            tostring(opts.showQualityBorder),
            tostring(opts.stackCount.fontSize),
            tostring(opts.itemLevel.enabled),
            tostring(opts.itemLevel.fontSize),
        }, ":")
        local appearanceChanged=f._warbandAppearance~=appearance
        f._warbandAppearance=appearance
        for _,bagID in ipairs(displayTabs) do
            for slotID=1,(C_Container.GetContainerNumSlots(bagID) or 0) do
                visual=visual+1
                 
                 
                local key=bagID*1000+slotID
                local w=f.bankButtonsBySlot[key]
                if not w then
                    w=self:CreateBankItemButton(f)
                    w:SetFrameLevel(f:GetFrameLevel()+3)
                    if w.nativeButton then w.nativeButton:SetFrameLevel(w:GetFrameLevel()+1) end
                    f.bankButtonsBySlot[key]=w
                    f.itemButtons[#f.itemButtons+1]=w
                end
                w._warbandSeen=generation
                if w._warbandIndex~=visual or w._warbandCells~=cells then
                    local col=(visual-1)%cells
                    local row=math.floor((visual-1)/cells)
                    local x=12+col*(self.SLOT_SIZE+self.SLOT_SPACING)
                    local y=-(70+row*(self.SLOT_SIZE+self.SLOT_SPACING))
                    w:ClearAllPoints(); w:SetPoint("TOPLEFT",f,"TOPLEFT",x,y)
                    w._warbandIndex=visual; w._warbandCells=cells
                end

                local info=C_Container.GetContainerItemInfo(bagID,slotID)
                if info and info.itemID then
                    occupied=occupied+1
                     
                     
                     
                    local changed=appearanceChanged
                        or w._warbandItemID~=info.itemID
                        or w._warbandCount~=info.stackCount
                        or w._warbandLink~=info.hyperlink
                        or w._warbandIcon~=info.iconFileID
                        or w._warbandQuality~=info.quality
                        or w._warbandLocked~=info.isLocked
                    local searchChanged=w._warbandSearch~=search
                        or w._warbandFiltered~=info.isFiltered
                    if changed then
                        local overlay=w.CanIMogItOverlay or (w.nativeButton and w.nativeButton.CanIMogItOverlay)
                        if overlay then overlay:Hide() end
                        if w.nativeButton then w.nativeButton:UnlockHighlight() end
                        w:SetAlpha(1)
                        local group=PhysicalGroup(physicalMode,bagID,slotID,info)
                        self:BindItemButton(w,group)
                        if w.background then w.background:SetColorTexture(.08,.08,.08,.95) end
                    end
                    if changed or searchChanged then
                        local group=w.group
                        w:SetAlpha((not searching or self:GroupMatchesSearch(group,search)) and 1 or .22)
                    end
                    if not changed and self.UpdateItemCooldown and C_Container.GetContainerItemCooldown then
                         
                         
                         
                        local startTime,duration,enabled=C_Container.GetContainerItemCooldown(bagID,slotID)
                        startTime=tonumber(startTime) or 0
                        duration=tonumber(duration) or 0
                        local endTime=(enabled~=0 and startTime>0 and duration>1.5)
                            and (startTime+duration) or nil
                        if endTime~=w.cooldownEnd then self:UpdateItemCooldown(w,w.group) end
                    end
                    w._warbandItemID=info.itemID
                    w._warbandCount=info.stackCount
                    w._warbandLink=info.hyperlink
                    w._warbandIcon=info.iconFileID
                    w._warbandQuality=info.quality
                    w._warbandLocked=info.isLocked
                    w._warbandFiltered=info.isFiltered
                    w._warbandSearch=search
                    w:Show()
                else
                     
                    if w._warbandItemID~=false then ClearPhysicalBankCell(w,bagID,slotID) end
                    w._warbandItemID=false
                    w._warbandCount=nil; w._warbandLink=nil
                    w._warbandIcon=nil; w._warbandQuality=nil
                    w._warbandLocked=nil; w._warbandFiltered=nil
                    w._warbandSearch=search
                    w:Show()
                end
            end
        end

        for _,w in pairs(f.bankButtonsBySlot) do
            if w._warbandSeen~=generation then w:Hide() end
        end

        local rows=math.max(1,math.ceil(math.max(visual,1)/cells))
        f:SetSize(24+cells*self.SLOT_SIZE+(cells-1)*self.SLOT_SPACING,
                  82+rows*self.SLOT_SIZE+(rows-1)*self.SLOT_SPACING+24)
        f._warbandUsed=occupied
        f._warbandTotal=visual
    end
    local separateMaterials=Layout().separateMaterials and true or false
    if mode==MATERIALS and not separateMaterials then mode=CHARACTER; self.bankMode=CHARACTER end
    RefreshBankSlotCounter(f,mode,f._warbandUsed,f._warbandTotal)
    local canUseCharacter=self.bankCharacterAvailable ~= false
    local canUseAccount=self.bankAccountAvailable ~= false
    f.charButton:SetShown(canUseCharacter)
    f.charButton:SetActive(mode==CHARACTER)
    f.materialsViewButton:SetShown(canUseCharacter and separateMaterials)
    f.materialsViewButton:SetActive(mode==MATERIALS)
    f.materialsViewButton:ClearAllPoints()
    f.materialsViewButton:SetPoint("LEFT",f.charButton,"RIGHT",5,0)
    f.warButton:SetShown(canUseAccount)
    f.warButton:ClearAllPoints()
    if canUseCharacter then
        f.warButton:SetPoint("LEFT",separateMaterials and f.materialsViewButton or f.charButton,"RIGHT",5,0)
    else
        f.warButton:SetPoint("TOPLEFT",f,"TOPLEFT",12,-36)
    end
    f.warButton:SetActive(mode==ACCOUNT)

    local isAccount=mode==ACCOUNT
    local isMaterials=mode==MATERIALS
    if f.materialsButton then f.materialsButton:SetShown(mode==CHARACTER or isMaterials) end
    if f.sortButton then f.sortButton:SetShown(true) end
    if f.bankModeButton then
        f.bankModeButton:SetShown(true)
        f.bankModeButton:UpdateState()
    end

    if f.sortButton then
        f.sortButton:ClearAllPoints()
        f.sortButton:SetPoint("RIGHT",f.closeButton,"LEFT",-2,0)
    end
    if f.materialsButton then
        f.materialsButton:ClearAllPoints()
        f.materialsButton:SetShown(mode==CHARACTER or isMaterials)
        if f.materialsButton:IsShown() then f.materialsButton:SetPoint("RIGHT",f.bankModeButton,"LEFT",-4,0) end
    end
    if f.purchaseButton then
        f.purchaseButton:ClearAllPoints()
        local previous=(f.materialsButton and f.materialsButton:IsShown()) and f.materialsButton or
            ((f.bankModeButton and f.bankModeButton:IsShown()) and f.bankModeButton or f.sortButton)
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
    if self._wagDepositVisualBankMode ~= mode then
        self._wagDepositVisualBankMode = mode
        if self.RefreshBagBankDepositAppearance then self:RefreshBagBankDepositAppearance() end
    end
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
    local canUseCharacter=BankIsUsable(CHARACTER)
    local canUseAccount=BankIsUsable(ACCOUNT)
    if canUseCharacter == false and canUseAccount == false then
        local attempts=(self.bankAvailabilityAttempts or 0)+1
        self.bankAvailabilityAttempts=attempts
        if attempts <= 3 then
            local generation=self.bankOpenGeneration
            C_Timer.After(0.05,function()
                if SB.bankAccessOpen and SB.bankOpenGeneration == generation then SB:OpenBank() end
            end)
        end
        return
    end
    self.bankAvailabilityAttempts=nil
    self.bankCharacterAvailable=canUseCharacter ~= false
    self.bankAccountAvailable=canUseAccount ~= false
    if self.ResetBankVisualSlotSession then self:ResetBankVisualSlotSession() end
    self.bankMode=self.bankCharacterAvailable and CHARACTER or ACCOUNT
    local tabs=self.bankMode==ACCOUNT and TabIDs(ACCOUNT) or nil
    if self.bankMode==ACCOUNT then self.warbandSelectedTab=tabs[1] end
    SelectBlizzardBank(self.bankMode,tabs and tabs[1])
    if self.bankMode==ACCOUNT then
        if self.BeginWarbandRecentSession then self:BeginWarbandRecentSession() end
    elseif self.BeginBankRecentSession then
        self:BeginBankRecentSession()
    end
    self:RefreshBank("Bank_Mainline.lua:OpenBank")
    self.bankFrame:Show()
    if self.RefreshBagBankDepositAppearance then self:RefreshBagBankDepositAppearance() end
    if self.EnterBankSystemPanelMode then self:EnterBankSystemPanelMode() end
end
function SB:CloseBank()
    if self.CancelBankVisualSort then self:CancelBankVisualSort() end
    if self.ResetBankVisualSlotSession then self:ResetBankVisualSlotSession() end
    if self.bankPlacementActive then self:FinishBankPlacement() end
    self._selectedNativeBankType=nil
    self._selectedNativeBankTab=nil
    self._selectedNativeBankFrame=nil
    self._selectedNativeBankPanel=nil
    if self.bankFrame then self.bankFrame._warbandAppearance=nil end
    self.bankMode=nil
    self.bankCharacterAvailable=nil
    self.bankAccountAvailable=nil
    self.bankAvailabilityAttempts=nil
    self._wagDepositVisualBankMode=nil
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
    if self.bankAccessOpen then self:RefreshBank("Bank_Mainline.lua:1297") end
end

function SB:ApplyNativeBankAppearance() if self.bankFrame then self:RefreshBank("Bank_Mainline.lua:1300") end end

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
