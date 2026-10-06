local _, SB = ...

SB.Settings = SB.Settings or {}

local PANEL_WIDTH, PANEL_HEIGHT = 650, 650
local NAV_WIDTH = 142
local CONTENT_LEFT = NAV_WIDTH + 28
local CONTENT_RIGHT = 22
local ROW_H = 42

local function Apply()
    if SB.PersistCurrentProfile then SB:PersistCurrentProfile() end
    if SB.mainFrame and SB.mainFrame:IsShown() then
        if SB.RefreshCurrencyBar then SB:RefreshCurrencyBar() end
        SB:RefreshBags()
    end
    if SB.RefreshSettingsValues then SB:RefreshSettingsValues() end
end

local function Backdrop(frame, bg, border)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(unpack(bg or {.045,.045,.055,1}))
    frame:SetBackdropBorderColor(unpack(border or {.18,.18,.22,1}))
end

local function Label(parent,text,x,y,font)
    local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y); f:SetText(text); return f
end

local function Section(parent,text,y)
    local t=Label(parent,text,0,y,"GameFontNormal")
    local line=parent:CreateTexture(nil,"ARTWORK")
    line:SetColorTexture(.20,.20,.24,1); line:SetHeight(1)
    line:SetPoint("LEFT",t,"RIGHT",10,0); line:SetPoint("RIGHT",0,0)
    return y-28
end

local function Button(parent,text,w)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(w or 120,26); Backdrop(b,{.055,.055,.065,1},{.28,.28,.33,1})
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.text:SetPoint("CENTER"); b.text:SetText(text or "")
    b:SetScript("OnEnter",function(x)x:SetBackdropBorderColor(.85,.68,.08,1)end)
    b:SetScript("OnLeave",function(x)x:SetBackdropBorderColor(.28,.28,.33,1)end)
    function b:SetText(v) self.text:SetText(v or "") end
    return b
end

local function Check(parent,text,getter,setter)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate"); b:SetSize(20,20); Backdrop(b,{.035,.035,.04,1},{.32,.32,.36,1})
    local mark=b:CreateTexture(nil,"OVERLAY")
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetSize(24,24); mark:SetPoint("CENTER"); b.mark=mark
    local label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); label:SetPoint("LEFT",b,"RIGHT",8,0); label:SetText(text); b.label=label
    b._getter=getter
    function b:SetChecked(v) self.mark:SetShown(v and true or false) end
    b:SetScript("OnClick",function(x) setter(not getter()); Apply() end)
    return b
end

local function Slider(parent,label,y,minv,maxv,step,getter,setter,formatter)
    local row=CreateFrame("Frame",nil,parent); row:SetPoint("TOPLEFT",0,y); row:SetPoint("TOPRIGHT",0,y); row:SetHeight(ROW_H)
    local l=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); l:SetPoint("LEFT",0,0); l:SetText(label)
    local value=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); value:SetPoint("RIGHT",0,0); value:SetWidth(58); value:SetJustifyH("RIGHT")
    local slider=CreateFrame("Slider",nil,row,"OptionsSliderTemplate"); slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minv,maxv); slider:SetValueStep(step); slider:SetObeyStepOnDrag(true)
    slider:SetPoint("LEFT",205,0); slider:SetPoint("RIGHT",value,"LEFT",-12,0); slider:SetHeight(18)
    if slider.Low then slider.Low:Hide() end; if slider.High then slider.High:Hide() end; if slider.Text then slider.Text:Hide() end
    slider._getter=getter; slider._setter=setter; slider._format=formatter or tostring
    slider:SetScript("OnValueChanged",function(x,v,user)
        if x._sync then return end
        if step>=1 then v=math.floor(v+.5) else v=math.floor(v/step+.5)*step end
        value:SetText(x._format(v))
        if user then setter(v); Apply() end
    end)
    function slider:Sync()
        self._sync=true; local v=getter(); self:SetValue(v); value:SetText(self._format(v)); self._sync=false
    end
    row.slider=slider; row.value=value
    return slider
end

local ANCHORS={"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}
local function AnchorSelector(parent,label,y,getter,setter)
    local row=CreateFrame("Frame",nil,parent)
    row:SetPoint("TOPLEFT",0,y); row:SetPoint("TOPRIGHT",0,y); row:SetHeight(68)
    local l=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    l:SetPoint("LEFT",0,0); l:SetText(label)
    row.buttons={}
    local pos={
        TOPLEFT={205,-4}, TOPRIGHT={245,-4},
        BOTTOMLEFT={205,-34}, BOTTOMRIGHT={245,-34},
    }
    local rotation={
        TOPLEFT=math.rad(-45), TOPRIGHT=math.rad(45),
        BOTTOMLEFT=math.rad(-135), BOTTOMRIGHT=math.rad(135),
    }
    for _,a in ipairs(ANCHORS) do
        local b=Button(row,"",34); b:SetSize(34,26)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",pos[a][1],pos[a][2])
        local icon=b:CreateTexture(nil,"ARTWORK")
        icon:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        icon:SetSize(27,27); icon:SetPoint("CENTER")
        if icon.SetRotation then icon:SetRotation(rotation[a]) end
        b.icon=icon
        b:SetScript("OnClick",function() setter(a); Apply() end)
        b.anchor=a; row.buttons[a]=b
    end
    row.Sync=function()
        local active=getter()
        for a,b in pairs(row.buttons) do
            if a==active then
                b:SetBackdropBorderColor(1,.75,.05,1)
                if b.icon then b.icon:SetVertexColor(1,.82,.1,1) end
            else
                b:SetBackdropBorderColor(.28,.28,.33,1)
                if b.icon then b.icon:SetVertexColor(1,1,1,1) end
            end
        end
    end
    row:HookScript("OnShow",row.Sync)
    return row
end

local function Edit(parent,w)
    local e=CreateFrame("EditBox",nil,parent,"BackdropTemplate")
    e:SetSize(w,24); e:SetAutoFocus(false); e:SetFontObject("GameFontHighlight"); e:SetTextInsets(7,7,0,0)
    e:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    e:SetBackdropColor(.025,.025,.03,.90); e:SetBackdropBorderColor(.20,.20,.24,1)
    e:SetScript("OnEditFocusGained",function(x)x:SetBackdropBorderColor(.45,.45,.52,1)end)
    e:SetScript("OnEditFocusLost",function(x)x:SetBackdropBorderColor(.20,.20,.24,1)end)
    e:SetScript("OnEscapePressed",function(x)x:ClearFocus()end); e:SetScript("OnEnterPressed",function(x)x:ClearFocus()end); return e
end

function SB:SelectSettingsTab(tab)
    local f=self.settingsFrame; if not f then return end
    f.activeTab=tab
    f.bagsPage:SetShown(tab=="bags"); f.categoriesPage:SetShown(tab=="categories"); f.currencyPage:SetShown(tab=="currency"); f.bankPage:SetShown(tab=="bank"); f.profilesPage:SetShown(tab=="profiles")
    for key,b in pairs(f.navButtons) do
        local active=key==tab; b:SetBackdropColor(active and .12 or .045,active and .10 or .045,active and .035 or .055,1)
        b:SetBackdropBorderColor(active and 1 or .20,active and .72 or .20,active and .05 or .24,1)
        b.text:SetTextColor(active and 1 or .82,active and .82 or .82,active and .10 or .82)
    end
    if tab=="categories" then self:RefreshCategorySettings()
    elseif tab=="currency" then self:RefreshCurrencySettings()
    elseif tab=="bank" then self:RefreshBankSettingsValues()
    elseif tab=="profiles" then
        f.profilesPage.selectedProfile=self:GetCurrentProfileName()
        self:RefreshProfilesSettings()
    end
end

function SB:CreateBagsSettings(parent)
    local BAG_ROW_H=38
    local page=CreateFrame("Frame",nil,parent); page:SetPoint("TOPLEFT",CONTENT_LEFT,-58); page:SetPoint("BOTTOMRIGHT",-CONTENT_RIGHT,18)
    local y=0
    y=Section(page,SB:T("LAYOUT"),y)
    page.blocksSlider=Slider(page,SB:T("BLOCKS_PER_ROW"),y,1,4,1,function()return SB.db.layout.blocksPerRow or 2 end,function(v)SB.db.layout.blocksPerRow=v end); y=y-BAG_ROW_H
    page.cellsSlider=Slider(page,SB:T("CELLS_PER_BLOCK_ROW"),y,2,10,1,function()return SB.db.layout.cellsPerRow or 4 end,function(v)SB.db.layout.cellsPerRow=v end); y=y-BAG_ROW_H
    page.scaleSlider=Slider(page,SB:T("WINDOW_SCALE"),y,.5,2,.05,function()return SB.db.layout.scale or 1 end,function(v)
        SB.db.layout.scale=v
        if SB.mainFrame then SB.mainFrame:SetScale(v) end
    end,function(v)return math.floor(v*100+.5).."%" end); y=y-BAG_ROW_H
    page.alphaSlider=Slider(page,SB:T("BACKGROUND_ALPHA"),y,0,1,.05,function()return SB.db.layout.backgroundAlpha or .97 end,function(v)SB.db.layout.backgroundAlpha=v end,function(v)return math.floor(v*100+.5).."%" end); y=y-BAG_ROW_H
    page.recentTimerSlider=Slider(page,SB:T("RECENT_TIMER"),y,0,60,1,function()return SB.db.items.recentTimerMinutes or 0 end,function(v)
        SB.db.items.recentTimerMinutes=v
        SB:ClearRecentItems()
        local cache=SB:ScanAndCacheBags()
        SB.inventorySnapshot=SB:BuildInventorySnapshot(cache.groups)
    end,function(v)return math.floor(v+.5).." "..SB:T("MINUTES_SHORT") end); y=y-BAG_ROW_H
    page.anchorSelector=AnchorSelector(page,SB:T("GROWTH_ANCHOR"),y,function()return SB.db.layout.growthAnchor or "TOPLEFT" end,function(v)SB:SetGrowthAnchor(v)end); y=y-82

    y=Section(page,SB:T("ITEMS"),y)
    local sortLabel=Label(page,SB:T("ITEM_SORT"),0,y-8)
    page.sortButton=Button(page,"",175); page.sortButton:SetPoint("TOPLEFT",205,y)
    page.sortNames={default=SB:T("SORT_TYPE"),name=SB:T("SORT_NAME"),quality=SB:T("SORT_QUALITY"),itemLevel=SB:T("SORT_ITEM_LEVEL")}
    local order={"default","name","quality","itemLevel"}
    page.sortButton:SetScript("OnClick",function()
        local cur=SB.db.items.sortMode or "default"; local idx=1
        for i,k in ipairs(order)do if k==cur then idx=i break end end
        SB.db.items.sortMode=order[idx%#order+1]
        if SB.ResetVisualSlotSession then SB:ResetVisualSlotSession() end
        Apply()
    end); y=y-42

    page.qualityCheck=Check(page,SB:T("QUALITY_BORDER"),function()return SB.db.items.showQualityBorder end,function(v)SB.db.items.showQualityBorder=v end); page.qualityCheck:SetPoint("TOPLEFT",0,y);
    page.ilvlCheck=Check(page,SB:T("SHOW_ITEM_LEVEL"),function()return SB.db.items.itemLevel.enabled end,function(v)SB.db.items.itemLevel.enabled=v end); page.ilvlCheck:SetPoint("TOPLEFT",245,y); y=y-30
    page.ilvlSlider=Slider(page,SB:T("ITEM_LEVEL_SIZE"),y,8,30,1,function()return SB.db.items.itemLevel.fontSize or 12 end,function(v)SB.db.items.itemLevel.fontSize=v end); y=y-BAG_ROW_H
    page.stackSlider=Slider(page,SB:T("STACK_COUNT_SIZE"),y,8,30,1,function()return SB.db.items.stackCount.fontSize or 12 end,function(v)SB.db.items.stackCount.fontSize=v end); y=y-BAG_ROW_H
    page.minimapCheck=Check(page,SB:T("SHOW_MINIMAP_BUTTON"),function()return WagBagDB.minimap and WagBagDB.minimap.show~=false end,function(v)
        WagBagDB.minimap=WagBagDB.minimap or {}
        WagBagDB.minimap.show=v and true or false
        if SB.UpdateMinimapButtonVisibility then SB:UpdateMinimapButtonVisibility() end
    end); page.minimapCheck:SetPoint("TOPLEFT",0,y); y=y-34

    page.reset=Button(page,SB:T("RESET_SETTINGS"),155); page.reset:SetPoint("TOPLEFT",0,y+8)
    page.reset:SetScript("OnClick",function()
        SB.db.layout.blocksPerRow=2;SB.db.layout.cellsPerRow=4;SB.db.layout.scale=1;SB.db.layout.backgroundAlpha=.97;SB.db.layout.growthAnchor="TOPLEFT"
        SB.db.items.recentTimerMinutes=0;SB:ClearRecentItems()
        SB.db.items.showQualityBorder=true;SB.db.items.itemLevel.enabled=true;SB.db.items.itemLevel.fontSize=12;SB.db.items.stackCount.fontSize=12
        Apply()
        if SB.UpdateGrowthAnchorMarker then SB:UpdateGrowthAnchorMarker() end
    end)
    parent.bagsPage=page
end

function SB:CreateCategoriesSettings(parent)
    local page=CreateFrame("Frame",nil,parent); page:SetPoint("TOPLEFT",CONTENT_LEFT,-58); page:SetPoint("BOTTOMRIGHT",-CONTENT_RIGHT,18)
    local gap,leftW=18,220
    local rightW=220
    local rightX=leftW+gap

    Label(page,SB:T("CUSTOM_CATEGORIES"),0,0,"GameFontNormal")
    local left=CreateFrame("Frame",nil,page,"BackdropTemplate")
    left:SetPoint("TOPLEFT",0,-28); left:SetSize(leftW,210); Backdrop(left,{.025,.025,.03,.65},{.16,.16,.19,1})
    local scroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",6,-6);scroll:SetPoint("BOTTOMRIGHT",-28,6)
    local list=CreateFrame("Frame",nil,scroll);list:SetSize(leftW-38,190);scroll:SetScrollChild(list);page.listFrame=list;page.rows={}

    page.nameEdit=Edit(page,leftW);page.nameEdit:SetPoint("TOPLEFT",0,-248);page.nameEdit:SetMaxLetters(32)
    local add=Button(page,SB:T("ADD"),68);add:SetPoint("TOPLEFT",0,-282)
    local rename=Button(page,SB:T("RENAME"),94);rename:SetPoint("LEFT",add,"RIGHT",5,0);page.renameButton=rename
    local del=Button(page,SB:T("DELETE"),48);del:SetPoint("LEFT",rename,"RIGHT",5,0);page.deleteButton=del
    local hide=Button(page,SB:T("HIDE"),leftW);hide:SetPoint("TOPLEFT",0,-316);page.hideButton=hide

    Label(page,SB:T("CATEGORY_CONTENTS"),rightX,0,"GameFontNormal")
    local right=CreateFrame("Frame",nil,page,"BackdropTemplate")
    right:SetPoint("TOPLEFT",rightX,-28);right:SetPoint("TOPRIGHT",0,-28);right:SetHeight(210);Backdrop(right,{.025,.025,.03,.65},{.16,.16,.19,1})
    local cs=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate")
    cs:SetPoint("TOPLEFT",6,-6);cs:SetPoint("BOTTOMRIGHT",-28,6)
    local content=CreateFrame("Frame",nil,cs);content:SetSize(200,190);cs:SetScrollChild(content);page.contentFrame=content;page.contentRows={}

    Label(page,SB:T("ASSIGN_ITEM"),rightX,-248,"GameFontNormal")
    Label(page,SB:T("ITEM_ID_HINT"),rightX,-269,"GameFontDisableSmall")
    page.itemEdit=Edit(page,rightW);page.itemEdit:SetPoint("TOPLEFT",rightX,-292);page.itemEdit:SetNumeric(true)
    local assign=Button(page,SB:T("ASSIGN"),106);assign:SetPoint("TOPLEFT",rightX,-326)
    local remove=Button(page,SB:T("REMOVE"),106);remove:SetPoint("LEFT",assign,"RIGHT",8,0);page.removeAssignedButton=remove

    add:SetScript("OnClick",function()local name=strtrim(page.nameEdit:GetText()or"");if name==""then name=SB:T("NEW_CATEGORY")end;local id=SB.db.categories.nextCustomID or 1;local key="custom_"..id;SB.db.categories.nextCustomID=id+1;SB.db.categories.custom[key]={name=name};table.insert(SB.db.categories.order,key);page.selectedKey=key;page.nameEdit:SetText("");SB:RefreshCategorySettings();Apply()end)
    rename:SetScript("OnClick",function()local k=page.selectedKey;local d=k and SB.db.categories.custom[k];local n=strtrim(page.nameEdit:GetText()or"");if d and n~=""then d.name=n;page.nameEdit:SetText("");SB:RefreshCategorySettings();Apply()end end)
    del:SetScript("OnClick",function()local k=page.selectedKey;if not k or not SB.db.categories.custom[k]then return end;SB.db.categories.custom[k]=nil;SB.db.categories.hidden[k]=nil;for id,a in pairs(SB.db.categories.assignments or{})do if a==k then SB.db.categories.assignments[id]=nil end end;for i=#SB.db.categories.order,1,-1 do if SB.db.categories.order[i]==k then table.remove(SB.db.categories.order,i)end end;page.selectedKey=nil;page.selectedContentItemID=nil;page.nameEdit:SetText("");SB:RefreshCategorySettings();Apply()end)
    hide:SetScript("OnClick",function()
        local k=page.selectedKey
        if not k or not SB.db.categories.custom[k] then return end
        SB.db.categories.hidden=SB.db.categories.hidden or {}
        SB.db.categories.hidden[k]=not SB.db.categories.hidden[k] or nil
        SB:RefreshCategorySettings();Apply()
    end)
    assign:SetScript("OnClick",function()local k=page.selectedKey;local id=tonumber(page.itemEdit:GetText());if not k or not (SB.db.categories.custom[k] or SB.Categories[k]) then SB:Print(SB:T("SELECT_CUSTOM_CATEGORY"));return end;if not id then SB:Print(SB:T("INVALID_ITEM_ID"));return end;SB.db.categories.assignments[tostring(id)]=k;SB.db.categories.assignments[id]=nil;if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end;page.itemEdit:SetText("");page.selectedContentItemID=id;SB:RefreshCategorySettings();Apply()end)
    remove:SetScript("OnClick",function()local id=page.selectedContentItemID;if not id then return end;SB.db.categories.assignments[tostring(id)]=nil;SB.db.categories.assignments[id]=nil;page.selectedContentItemID=nil;SB:RefreshCategorySettings();Apply()end)
    parent.categoriesPage=page
end

function SB:RefreshCategorySettings()
    local f=self.settingsFrame
    if not f or not f.categoriesPage then return end
    local p=f.categoriesPage
    local keys={}
    self.db.categories.hidden=self.db.categories.hidden or {}
    for key in pairs(self.db.categories.hidden) do
        if not self.db.categories.custom[key] then self.db.categories.hidden[key]=nil end
    end
    for _,key in ipairs(self.db.categories.order or {}) do
        if self.db.categories.custom[key] then table.insert(keys,key) end
    end

    for i,key in ipairs(keys) do
        local row=p.rows[i]
        if not row then
            row=Button(p.listFrame,"",p.listFrame:GetWidth() > 0 and p.listFrame:GetWidth() or 182)
            row:SetScript("OnClick",function(button)
                if button.categoryKey then
                    p.selectedKey=button.categoryKey
                    p.selectedContentItemID=nil
                    local custom=self.db.categories.custom[button.categoryKey]
                    p.nameEdit:SetText(custom and custom.name or "")
                    self:RefreshCategorySettings()
                end
            end)
            p.rows[i]=row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",0,-(i-1)*27)
        row:SetPoint("TOPRIGHT",0,-(i-1)*27)
        row.categoryKey=key
        local hidden=self.db.categories.hidden and self.db.categories.hidden[key]
        local label=self:GetCategoryName(key)
        if hidden then label=label.."  ["..self:T("HIDDEN_MARK").."]" end
        row:SetText(((p.selectedKey==key) and "• " or "")..label)
        row:Show()
    end
    for i=#keys+1,#p.rows do p.rows[i]:Hide(); p.rows[i].categoryKey=nil end
    p.listFrame:SetHeight(math.max(86,#keys*27))

    local selected=p.selectedKey
    local isCustom=selected and self.db.categories.custom[selected]~=nil
    if p.hideButton then
        p.hideButton:SetEnabled(isCustom and true or false)
        p.hideButton:SetText((isCustom and self.db.categories.hidden and self.db.categories.hidden[selected]) and self:T("UNHIDE") or self:T("HIDE"))
    end
    p.nameEdit:SetEnabled(true)
    if p.renameButton then p.renameButton:SetEnabled(isCustom and true or false) end
    if p.deleteButton then p.deleteButton:SetEnabled(isCustom and true or false) end

    local assigned={}
    if p.selectedKey then
        for itemID,key in pairs(self.db.categories.assignments or {}) do
            if key==p.selectedKey then
                local id=tonumber(itemID)
                if id then
                    local name=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (C_Item.GetItemInfo and C_Item.GetItemInfo(id))
                    if not name then
                        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
                        name="Item "..id
                    end
                    table.insert(assigned,{id=id,name=name})
                end
            end
        end
    end
    table.sort(assigned,function(a,b) return a.name<b.name end)

    for i,item in ipairs(assigned) do
        local row=p.contentRows[i]
        if not row then
            row=CreateFrame("Button",nil,p.contentFrame,"BackdropTemplate")
            row:SetHeight(23); row:SetPoint("LEFT"); row:SetPoint("RIGHT")
            Backdrop(row,{0,0,0,0},{0,0,0,0})
            local icon=row:CreateTexture(nil,"ARTWORK"); icon:SetSize(20,20); icon:SetPoint("LEFT",1,0); row.icon=icon
            local text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",icon,"RIGHT",6,0); text:SetPoint("RIGHT",-4,0); text:SetJustifyH("LEFT"); row.text=text
            row:SetScript("OnClick",function(button)
                p.selectedContentItemID=button.itemID
                SB:RefreshCategorySettings()
            end)
            p.contentRows[i]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*23); row:SetPoint("TOPRIGHT",0,-(i-1)*23)
        row.itemID=item.id
        row.icon:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText(item.name.."  ["..item.id.."]")
        local selectedItem=p.selectedContentItemID==item.id
        row:SetBackdropColor(selectedItem and .07 or 0,selectedItem and .16 or 0,selectedItem and .22 or 0,selectedItem and .72 or 0)
        row:SetBackdropBorderColor(selectedItem and .20 or 0,selectedItem and .62 or 0,selectedItem and .82 or 0,selectedItem and 1 or 0)
        row:Show()
    end
    for i=#assigned+1,#p.contentRows do p.contentRows[i]:Hide() end
    if p.selectedContentItemID then
        local found=false
        for _,item in ipairs(assigned) do if item.id==p.selectedContentItemID then found=true break end end
        if not found then p.selectedContentItemID=nil end
    end
    if p.removeAssignedButton then p.removeAssignedButton:SetEnabled(p.selectedContentItemID and true or false) end
    p.contentFrame:SetHeight(math.max(74,#assigned*23))
end

function SB:CreateCurrencySettings(parent)
    local page=CreateFrame("Frame",nil,parent);page:SetPoint("TOPLEFT",CONTENT_LEFT,-58);page:SetPoint("BOTTOMRIGHT",-CONTENT_RIGHT,18)
    Label(page,SB:T("CHARACTER_CURRENCY"),0,0,"GameFontNormal")
    Label(page,SB:T("CURRENCY_DESC"),0,-22,"GameFontDisableSmall")
    local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",0,-52);scroll:SetPoint("BOTTOMRIGHT",-18,0)
    local list=CreateFrame("Frame",nil,scroll);list:SetSize(1,400);scroll:SetScrollChild(list);page.listFrame=list;page.rows={};parent.currencyPage=page
end

local function CurrencyRowTooltip(row)
    if not row.currencyID then return end
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    if GameTooltip.SetCurrencyByID then
        GameTooltip:SetCurrencyByID(row.currencyID)
    end
    GameTooltip:Show()
end

function SB:RefreshCurrencySettings()
    local f=self.settingsFrame
    if not f or not f.currencyPage then return end

    local p=f.currencyPage
    local currencies=self:GetCharacterCurrencies()
    local selected=self.db.currency.selected

    local columns=2
    local rowHeight=30
    local columnGap=12
    local listWidth=math.max(300,(p.listFrame:GetParent():GetWidth() or 350)-4)
    local columnWidth=math.floor((listWidth-columnGap)/columns)

    for i,currency in ipairs(currencies) do
        local row=p.rows[i]
        if not row then
            row=CreateFrame("Button",nil,p.listFrame)
            row:SetHeight(rowHeight)
            row:RegisterForClicks("LeftButtonUp")

            local box=row:CreateTexture(nil,"ARTWORK")
            box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            box:SetSize(22,22)
            box:SetPoint("LEFT",-1,0)
            row.box=box

            local check=row:CreateTexture(nil,"OVERLAY")
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            check:SetSize(22,22)
            check:SetPoint("CENTER",box)
            row.check=check

            local icon=row:CreateTexture(nil,"ARTWORK")
            icon:SetSize(20,20)
            icon:SetPoint("LEFT",box,"RIGHT",4,0)
            icon:SetTexCoord(.07,.93,.07,.93)
            row.icon=icon

            local label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            label:SetPoint("LEFT",icon,"RIGHT",6,0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            row.label=label

            row:SetScript("OnClick",function(b)
                if not b.currencyID then return end
                local key=tostring(b.currencyID)
                if selected[key] or selected[b.currencyID] then
                    selected[key]=nil
                    selected[b.currencyID]=nil
                else
                    selected[key]=true
                end
                SB:RefreshCurrencySettings()
                Apply()
            end)
            row:SetScript("OnEnter",CurrencyRowTooltip)
            row:SetScript("OnLeave",GameTooltip_Hide)
            p.rows[i]=row
        end

        local col=(i-1)%columns
        local line=math.floor((i-1)/columns)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",col*(columnWidth+columnGap),-line*rowHeight)
        row:SetSize(columnWidth,rowHeight)

        row.currencyID=currency.id
        row.icon:SetTexture(currency.icon)

        local labelRightPadding=4
        local labelWidth=math.max(20,columnWidth-(22+4+20+6)-labelRightPadding)
        row.label:SetWidth(labelWidth)
        row.label:SetText(currency.name)

        local isChecked=selected[tostring(currency.id)] or selected[currency.id] or false
        row.check:SetShown(isChecked)
        row.box:SetVertexColor(1,1,1,1)
        row:Show()
    end

    for i=#currencies+1,#p.rows do
        p.rows[i]:Hide()
        p.rows[i].currencyID=nil
    end

    local lines=math.ceil(#currencies/columns)
    p.listFrame:SetWidth(listWidth)
    p.listFrame:SetHeight(math.max(360,lines*rowHeight))
end

function SB:CreateBankSettings(parent)
    local page=CreateFrame("Frame",nil,parent);page:SetPoint("TOPLEFT",CONTENT_LEFT,-58);page:SetPoint("BOTTOMRIGHT",-CONTENT_RIGHT,18)
    local y=0
    y=Section(page,SB:T("BANK_WINDOW"),y)
    page.placeButton=Button(page,SB:T("BANK_POSITION"),190);page.placeButton:SetPoint("TOPLEFT",0,y);page.placeButton:SetScript("OnClick",function()SB:ToggleBankPlacement()end);y=y-42
    page.scaleSlider=Slider(page,SB:T("BANK_SCALE"),y,.5,2,.05,function()return SB.db.bankLayout.scale or 1 end,function(v)if not SB.bankPlacementActive then SB.db.bankLayout.scale=v;if SB.bankFrame and SB.bankFrame:IsShown() then SB:ApplyNativeBankAppearance() end end end,function(v)return math.floor(v*100+.5).."%"end);y=y-ROW_H
    page.columnsSlider=Slider(page,SB:T("CELLS_PER_ROW"),y,6,30,1,function()return SB.db.bankLayout.cellsPerRow or 18 end,function(v)if not SB.bankPlacementActive then SB.db.bankLayout.cellsPerRow=v;if SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank() end end end);y=y-ROW_H
    page.alphaSlider=Slider(page,SB:T("WINDOW_ALPHA"),y,.15,1,.05,function()return SB.db.bankLayout.backgroundAlpha or .92 end,function(v)if not SB.bankPlacementActive then SB.db.bankLayout.backgroundAlpha=v;if SB.bankFrame and SB.bankFrame:IsShown() then SB:ApplyNativeBankAppearance() end end end,function(v)return math.floor(v*100+.5).."%"end);y=y-ROW_H
    page.anchorSelector=AnchorSelector(page,SB:T("BANK_ANCHOR"),y,function()return SB.db.bankLayout.anchor or "TOPLEFT"end,function(v)if not SB.bankPlacementActive then SB.db.bankLayout.anchor=v;if SB.bankFrame and SB.bankFrame:IsShown() then SB:ApplyBankAnchor(v) end end end); y=y-82
    page.reset=Button(page,SB:T("RESET_SETTINGS"),155); page.reset:SetPoint("TOPLEFT",0,y)
    page.reset:SetScript("OnClick",function()
        if SB.bankPlacementActive then SB:FinishBankPlacement() end
        SB.db.bankLayout.scale=1
        SB.db.bankLayout.cellsPerRow=18
        SB.db.bankLayout.backgroundAlpha=.92
        SB.db.bankLayout.anchor="TOPLEFT"
        if SB.bankFrame and SB.bankFrame:IsShown() then
            SB:ApplyNativeBankAppearance()
            SB:ApplyBankAnchor("TOPLEFT")
            SB:RefreshBank()
        end
        SB:RefreshBankSettingsValues()
    end)
    parent.bankPage=page
end

function SB:RefreshBankSettingsValues()
    local f=self.settingsFrame;if not f or not f.bankPage then return end
    local p=f.bankPage
    for _,x in ipairs({p.scaleSlider,p.columnsSlider,p.alphaSlider})do if x then x:Sync();x:SetEnabled(not self.bankPlacementActive);x:SetAlpha(self.bankPlacementActive and .4 or 1)end end
    if p.anchorSelector then p.anchorSelector:Sync();p.anchorSelector:SetAlpha(self.bankPlacementActive and .4 or 1);p.anchorSelector:EnableMouse(not self.bankPlacementActive)end
    if p.placeButton then p.placeButton:SetText(self.bankPlacementActive and SB:T("LOCK_POSITION") or SB:T("BANK_POSITION"))end
end

function SB:ShowProfileExportModal(text)
    local f=self.profileExportModal
    if not f then
        f=CreateFrame("Frame","WagBagProfileExportModal",UIParent,"BackdropTemplate")
        f:SetSize(560,250);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true);f:EnableKeyboard(true)
        if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
        Backdrop(f,{.018,.018,.024,.995},{.22,.22,.27,1})
        f.title=Label(f,self:T("PROFILE_EXPORT_TITLE"),18,-18,"GameFontNormalLarge")
        f.hint=Label(f,self:T("PROFILE_EXPORT_HINT"),18,-48,"GameFontDisableSmall")
        f.clip=CreateFrame("Frame",nil,f,"BackdropTemplate")
        f.clip:SetPoint("TOPLEFT",18,-72);f.clip:SetPoint("BOTTOMRIGHT",-18,58)
        Backdrop(f.clip,{.01,.01,.014,.98},{.30,.30,.35,1})
        f.scroll=CreateFrame("ScrollFrame",nil,f.clip,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",7,-7);f.scroll:SetPoint("BOTTOMRIGHT",-27,7)
        f.box=CreateFrame("EditBox",nil,f.scroll)
        f.box:SetMultiLine(true);f.box:SetAutoFocus(false);f.box:SetFontObject("GameFontHighlightSmall");f.box:SetWidth(490);f.box:SetHeight(1200);f.box:SetTextInsets(2,2,2,2);f.box:SetJustifyH("LEFT");f.box:SetJustifyV("TOP")
        f.scroll:SetScrollChild(f.box)
        f.cancel=Button(f,self:T("CANCEL"),150);f.cancel:SetPoint("BOTTOMRIGHT",-18,16)
        f.cancel:SetScript("OnClick",function() f:Hide() end)
        f.box:SetScript("OnEscapePressed",function() f:Hide() end)
        f:SetScript("OnKeyDown",function(_,key) if key=="ESCAPE" then f:Hide() end end)
        f:SetScript("OnShow",function() f.scroll:SetVerticalScroll(0);f.box:SetFocus();f.box:HighlightText() end)
        self.profileExportModal=f
    end
    f.title:SetText(self:T("PROFILE_EXPORT_TITLE"));f.hint:SetText(self:T("PROFILE_EXPORT_HINT"));f.cancel:SetText(self:T("CANCEL"))
    local display=(text or ""):gsub("(.{80})","%1\n")
    f.box:SetText(display);f.box:SetCursorPosition(0);f:Show();f:Raise();f.box:SetFocus();f.box:HighlightText()
end

function SB:CreateProfilesSettings(parent)
    local page=CreateFrame("Frame",nil,parent);page:SetPoint("TOPLEFT",CONTENT_LEFT,-58);page:SetPoint("BOTTOMRIGHT",-CONTENT_RIGHT,18)
    local y=0
    y=Section(page,SB:T("PROFILES"),y)
    page.current=Label(page,"",0,y,"GameFontHighlight"); y=y-38
    Label(page,SB:T("PROFILE_SOURCE"),0,y-4)

    page.profileDrop=Button(page,"",285); page.profileDrop:SetPoint("TOPLEFT",145,y-2)
    page.profileDrop.text:ClearAllPoints(); page.profileDrop.text:SetPoint("LEFT",10,0); page.profileDrop.text:SetPoint("RIGHT",-24,0); page.profileDrop.text:SetJustifyH("LEFT")
    page.profileDrop.arrow=page.profileDrop:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");page.profileDrop.arrow:SetPoint("RIGHT",-8,0);page.profileDrop.arrow:SetText("v")
    page.profileMenu=CreateFrame("Frame",nil,page,"BackdropTemplate");page.profileMenu:SetPoint("TOPLEFT",page.profileDrop,"BOTTOMLEFT",0,-2);page.profileMenu:SetWidth(285);page.profileMenu:SetFrameStrata("TOOLTIP");page.profileMenu:Hide();Backdrop(page.profileMenu,{.025,.025,.032,.99},{.28,.28,.33,1});page.profileMenu.rows={}
    page.profileDrop:SetScript("OnClick",function() page.profileMenu:SetShown(not page.profileMenu:IsShown()) end)
    y=y-38
    page.load=Button(page,SB:T("PROFILE_USE"),90);page.load:SetPoint("TOPLEFT",145,y)
    page.copy=Button(page,SB:T("PROFILE_COPY"),120);page.copy:SetPoint("LEFT",page.load,"RIGHT",8,0)
    page.delete=Button(page,SB:T("PROFILE_DELETE"),90);page.delete:SetPoint("LEFT",page.copy,"RIGHT",8,0);y=y-48

    y=Section(page,SB:T("PROFILE_TRANSFER"),y)
    Label(page,SB:T("PROFILE_STRING"),0,y-4)

    page.transferBox=CreateFrame("Frame",nil,page,"BackdropTemplate")
    page.transferBox:SetPoint("TOPLEFT",0,y-26);page.transferBox:SetSize(430,112)
    Backdrop(page.transferBox,{.015,.015,.02,.92},{.32,.32,.36,1})
    page.transferScroll=CreateFrame("ScrollFrame",nil,page.transferBox,"UIPanelScrollFrameTemplate")
    page.transferScroll:SetPoint("TOPLEFT",7,-7);page.transferScroll:SetPoint("BOTTOMRIGHT",-27,7)
    page.transfer=CreateFrame("EditBox",nil,page.transferScroll)
    page.transfer:SetMultiLine(true);page.transfer:SetAutoFocus(false);page.transfer:SetFontObject("GameFontHighlightSmall")
    page.transfer:SetWidth(390);page.transfer:SetHeight(96);page.transfer:SetTextInsets(2,2,2,2)
    page.transfer:SetBlinkSpeed(0.5)
    page.transfer:SetTextColor(1,1,1,1)

    page.transferCaret=page.transfer:CreateTexture(nil,"OVERLAY")
    page.transferCaret:SetColorTexture(1,1,1,1)
    page.transferCaret:SetSize(1,12)
    page.transferCaret:Hide()
    local caretClock=0
    local function ShowTransferCaret(x,y,h)
        local c=page.transferCaret
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT",page.transfer,"TOPLEFT",(x or 0)+2,(y or 0)-2)
        c:SetHeight(math.max(10,math.min(14,h or 12)))
        c:Show(); c:SetAlpha(1); caretClock=0
    end
    page.transfer:SetScript("OnCursorChanged",function(x,cx,cy,cw,ch)
        if x:HasFocus() then ShowTransferCaret(cx,cy,ch) end
    end)
    page.transfer:SetScript("OnUpdate",function(x,elapsed)
        if not x:HasFocus() then page.transferCaret:Hide(); return end
        caretClock=caretClock+elapsed
        page.transferCaret:SetAlpha((caretClock % 1.0)<0.5 and 1 or 0)
    end)
    page.transfer:SetJustifyH("LEFT")
    page.transfer:SetJustifyV("TOP")
    page.transfer:SetScript("OnMouseDown",function(x)
        x:SetFocus()
        if x:GetText()=="" then x:SetCursorPosition(0) end
    end)
    page.transfer:SetScript("OnEditFocusGained",function(x)
        if x:GetText()=="" then x:SetCursorPosition(0) end
        ShowTransferCaret(0,0,12)
    end)
    page.transfer:SetScript("OnEditFocusLost",function() page.transferCaret:Hide() end)
    page.transfer:SetScript("OnEscapePressed",function(x)x:ClearFocus()end)
    page.transfer:SetScript("OnTextChanged",function(x)
        if x:GetHeight() < 96 then x:SetHeight(96) end
        page.transferScroll:UpdateScrollChildRect()
    end)
    page.transferScroll:SetScrollChild(page.transfer)

    page.export=Button(page,SB:T("PROFILE_EXPORT"),150);page.export:SetPoint("TOPLEFT",page.transferBox,"BOTTOMLEFT",0,-10)
    page.import=Button(page,SB:T("PROFILE_IMPORT"),150);page.import:SetPoint("LEFT",page.export,"RIGHT",10,0)

    page.load:SetScript("OnClick",function()
        local key=page.selectedProfile
        if not key then SB:Print(SB:T("PROFILE_NOT_FOUND"));return end
        if SB:SelectProfile(key) then SB:Print(SB:T("PROFILE_LOADED",key));SB:RefreshProfilesSettings();Apply() end
    end)
    page.copy:SetScript("OnClick",function()
        local key=page.selectedProfile
        if not key then SB:Print(SB:T("PROFILE_NOT_FOUND"));return end
        local ok,reason,target=SB:CreateCharacterProfileCopy(key)
        if ok then
            SB:Print(SB:T("PROFILE_COPIED",target,key))
            page.selectedProfile=target
            SB:RefreshProfilesSettings()
            Apply()
        elseif reason=="exists" then
            SB:Print(SB:T("PROFILE_COPY_EXISTS",target))
        end
    end)
    page.delete:SetScript("OnClick",function()
        local key=page.selectedProfile
        if not key then SB:Print(SB:T("PROFILE_NOT_FOUND"));return end
        if key==SB:GetCurrentProfileName() then SB:Print(SB:T("PROFILE_DELETE_CURRENT"));return end
        StaticPopupDialogs["WAGBAG_DELETE_PROFILE"]={text=SB:T("PROFILE_DELETE_CONFIRM",key),button1=SB:T("DELETE"),button2=SB:T("CANCEL"),OnAccept=function()if SB:DeleteProfile(key) then SB:Print(SB:T("PROFILE_DELETED",key));page.selectedProfile=nil;SB:RefreshProfilesSettings()end end,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3}
        StaticPopup_Show("WAGBAG_DELETE_PROFILE")
    end)
    page.export:SetScript("OnClick",function()SB:ShowProfileExportModal(SB:ExportProfile())end)
    page.import:SetScript("OnClick",function()local ok=SB:ImportProfile(page.transfer:GetText());if ok then SB:Print(SB:T("PROFILE_IMPORTED"));SB:RefreshProfilesSettings();Apply()else SB:Print(SB:T("PROFILE_IMPORT_ERROR"))end end)
    parent.profilesPage=page
end

function SB:RefreshProfilesSettings()
    local f=self.settingsFrame;if not f or not f.profilesPage then return end
    local p=f.profilesPage
    p.current:SetText(SB:T("PROFILE_CURRENT",self.profilePersisted and self:GetCurrentProfileName() or SB:T("PROFILE_UNSAVED")))
    local names=self:GetProfileNames()
    if p.selectedProfile and not (WagBagDB.profiles and WagBagDB.profiles[p.selectedProfile]) then p.selectedProfile=nil end
    if not p.selectedProfile then
        for _,name in ipairs(names) do if name~=self:GetCurrentProfileName() then p.selectedProfile=name;break end end
        if not p.selectedProfile then p.selectedProfile=names[1] end
    end
    p.profileDrop:SetText(p.selectedProfile or SB:T("PROFILE_SELECT"))
    for _,row in ipairs(p.profileMenu.rows) do row:Hide() end
    for i,name in ipairs(names) do
        local row=p.profileMenu.rows[i]
        if not row then
            row=Button(p.profileMenu,"",281);row:SetHeight(24);row:SetPoint("TOPLEFT",2,-2-(i-1)*24);row.text:ClearAllPoints();row.text:SetPoint("LEFT",8,0);row.text:SetJustifyH("LEFT");p.profileMenu.rows[i]=row
        end
        row.profileName=name;row:SetText(name);row:SetScript("OnClick",function(b)
            p.selectedProfile=b.profileName
            p.profileDrop:SetText(b.profileName)
            p.profileMenu:Hide()
            local isCurrent=b.profileName==SB:GetCurrentProfileName()
            local target=SB:GetCharacterProfileKey()
            local canCopy=not (WagBagDB.profiles and WagBagDB.profiles[target])
            p.load:SetEnabled(true);p.load:SetAlpha(1)
            p.copy:SetEnabled(canCopy);p.copy:SetAlpha(canCopy and 1 or .45)
            local canDelete=not isCurrent and b.profileName~="Default"
            p.delete:SetEnabled(canDelete);p.delete:SetAlpha(canDelete and 1 or .45)
        end);row:Show()
    end
    p.profileMenu:SetHeight(math.max(4,#names*24+4))
    local hasSelection=p.selectedProfile~=nil
    local target=self:GetCharacterProfileKey()
    local canCopy=hasSelection and not (WagBagDB.profiles and WagBagDB.profiles[target])
    local canDelete=hasSelection and p.selectedProfile~=self:GetCurrentProfileName() and p.selectedProfile~="Default"
    p.load:SetEnabled(hasSelection);p.load:SetAlpha(hasSelection and 1 or .45)
    p.copy:SetEnabled(canCopy);p.copy:SetAlpha(canCopy and 1 or .45)
    p.delete:SetEnabled(canDelete);p.delete:SetAlpha(canDelete and 1 or .45)
end

function SB:CreateSettingsFrame()
    if self.settingsFrame then return self.settingsFrame end
    local f=CreateFrame("Frame","WagBagSettingsPanel")
    f:SetSize(820,620)
    f.activeTab="bags"

    local nav=CreateFrame("Frame",nil,f,"BackdropTemplate")
    nav:SetPoint("TOPLEFT",8,-8);nav:SetPoint("BOTTOMLEFT",8,8);nav:SetWidth(NAV_WIDTH)
    Backdrop(nav,{.025,.025,.032,.55},{.12,.12,.15,1})
    f.navButtons={}
    local tabs={{"bags",SB:T("TAB_BAGS")},{"bank",SB:T("TAB_BANK")},{"currency",SB:T("TAB_CURRENCY")},{"categories",SB:T("TAB_CATEGORIES")},{"profiles",SB:T("TAB_PROFILES")}}
    local prev
    for _,d in ipairs(tabs) do
        local b=Button(nav,d[2],NAV_WIDTH-12);b:SetHeight(34)
        if prev then b:SetPoint("TOPLEFT",prev,"BOTTOMLEFT",0,-6) else b:SetPoint("TOPLEFT",6,-6) end
        b:SetScript("OnClick",function() SB:SelectSettingsTab(d[1]) end)
        f.navButtons[d[1]]=b;prev=b
    end

    self:CreateBagsSettings(f);self:CreateCategoriesSettings(f);self:CreateCurrencySettings(f);self:CreateBankSettings(f);self:CreateProfilesSettings(f)
    f:SetScript("OnShow",function()
        SB:SelectSettingsTab(f.activeTab or "bags")
        SB:RefreshSettingsValues()
        if SB.UpdateGrowthAnchorMarker then SB:UpdateGrowthAnchorMarker() end
    end)
    f:SetScript("OnHide",function()
        if f.profilesPage and f.profilesPage.transfer then
            f.profilesPage.transfer:SetText("")
            f.profilesPage.transfer:ClearFocus()
        end
        if SB.growthAnchorMarker then SB.growthAnchorMarker:Hide() end
        if SB.bankPlacementActive then SB:FinishBankPlacement() end
    end)

    self.settingsFrame=f
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category=Settings.RegisterCanvasLayoutCategory(f,"WagBag")
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory=category
        self.settingsCategoryID=category.GetID and category:GetID() or category.ID or "WagBag"
    end
    return f
end

function SB:OpenSettings()
    self:CreateSettingsFrame()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategoryID or "WagBag")
    end
end

function SB:RefreshSettingsValues()
    local f=self.settingsFrame;if not f or not self.db then return end
    local p=f.bagsPage
    for _,x in ipairs({p.blocksSlider,p.cellsSlider,p.scaleSlider,p.alphaSlider,p.recentTimerSlider,p.ilvlSlider,p.stackSlider})do if x then x:Sync()end end
    p.sortButton:SetText(p.sortNames[self.db.items.sortMode or "default"]or SB:T("SORT_TYPE"))
    p.anchorSelector:Sync()
    p.qualityCheck:SetChecked(self.db.items.showQualityBorder and true or false);p.ilvlCheck:SetChecked(self.db.items.itemLevel.enabled and true or false)
    if p.minimapCheck then p.minimapCheck:SetChecked(WagBagDB.minimap and WagBagDB.minimap.show~=false) end
    self:RefreshBankSettingsValues()
end

function SB:ToggleSettings()
    self:OpenSettings()
end
