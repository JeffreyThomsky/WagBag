local _, SB = ...

local WINDOW_PADDING = 12
local HEADER_HEIGHT = 32
local BLOCK_PADDING = 7
local BLOCK_TITLE_HEIGHT = 18
local BLOCK_GAP = 8

SB.itemButtons = SB.itemButtons or {}
SB.categoryFrames = SB.categoryFrames or {}

local function AcquireCategoryFrame(parent, index)
    local frame = SB.categoryFrames[index]
    if frame then
        frame:Show()
        return frame
    end

    frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
     
     
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
    frame._wagBankNoBackdrop = true

    frame.titleHandle = CreateFrame("Button", nil, frame)
    frame.titleHandle:SetPoint("TOPLEFT", 1, -1)
    frame.titleHandle:SetPoint("TOPRIGHT", -1, -1)
    frame.titleHandle:SetHeight(BLOCK_TITLE_HEIGHT)

    frame.title = frame.titleHandle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("LEFT", BLOCK_PADDING - 1, 0)
    frame.title:SetJustifyH("LEFT")

    frame.titleHandle:RegisterForDrag("LeftButton")
    frame.titleHandle:SetScript("OnDragStart", function(handle)
        if not SB.db.layout.locked and handle.categoryKey then
            SB:BeginCategoryOrderDrag(handle.categoryKey)
        end
    end)

    SB.categoryFrames[index] = frame
    return frame
end

local function UpdateRecentOverflowIndicators(block)
    if not block or not block.recentScroll then return end
    local topIndicator = block.recentTopIndicator
    local bottomIndicator = block.recentBottomIndicator
    if not topIndicator or not bottomIndicator then return end
    local scroll = block.recentScroll
    local range = block.recentExpectedScrollRange or 0
    local offset = scroll:GetVerticalScroll() or 0
    if range <= 1 then
        topIndicator:Hide()
        bottomIndicator:Hide()
        return
    end
    if offset > 1 then topIndicator:Show() else topIndicator:Hide() end
    if offset < range - 1 then bottomIndicator:Show() else bottomIndicator:Hide() end
end

function SB:GetActiveCategoryItemIDEditBox()
    local f = self.settingsFrame
    local p = f and f.categoriesPage
    local e = p and p.itemEdit
    if f and f:IsShown() and f.activeTab == "categories" and e then
        return e
    end
    return nil
end

local function SetCategoryDropVisual(frame, active)
    if not frame or not frame:IsShown() then return end
    if active then
        frame.title:SetTextColor(0.35, 0.78, 1.00, 1)
        frame.titleHandle._wagBagDropHighlight = true
    else
        frame.title:SetTextColor(1.00, 0.82, 0.00, 1)
        frame.titleHandle._wagBagDropHighlight = nil
    end
end

local function ForEachVisibleCategoryFrame(callback)
    for _, frame in ipairs(SB.categoryFrames or {}) do
        if frame:IsShown() then callback(frame) end
    end
    local bankFrame=SB.bankFrame
    if bankFrame and bankFrame:IsShown() then
        for _, frame in ipairs(bankFrame.categoryFrames or {}) do
            if frame:IsShown() then callback(frame) end
        end
    end
end

function SB:GetCategoryTitleUnderCursor()
    local rawX, rawY = GetCursorPosition()
    local found
    ForEachVisibleCategoryFrame(function(frame)
        if found or not frame.categoryKey or frame.categoryKey == "__recent" or not frame.titleHandle then return end
        local handle = frame.titleHandle
        local scale = handle:GetEffectiveScale()
        local x, y = rawX / scale, rawY / scale
        local l, r, b, t = handle:GetLeft(), handle:GetRight(), handle:GetBottom(), handle:GetTop()
        if l and r and b and t and x >= l and x <= r and y >= b and y <= t then found=frame end
    end)
    return found
end

function SB:ResetCategoryDropVisuals()
    ForEachVisibleCategoryFrame(function(frame) SetCategoryDropVisual(frame, false) end)
end

function SB:BeginCategoryDrag(group)
    if not group or not group.itemID then return end

    if self.categoryDragReleaseFrame then
        self.categoryDragReleaseFrame:EnableMouse(false)
        self.categoryDragReleaseFrame:Hide()
        self.categoryDragReleaseFrame = nil
    end
    self.categoryDragGroup = group

    if not self.categoryDragGhost then
        local ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetSize(self.SLOT_SIZE, self.SLOT_SIZE)
        ghost:SetFrameStrata("TOOLTIP")
        local icon = ghost:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        ghost.icon = icon
        ghost:SetScript("OnUpdate", function(g)
            if not SB.categoryDragGroup then g:Hide(); return end
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            g:ClearAllPoints()
            g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 12)
        end)
        self.categoryDragGhost = ghost
    end
    self.categoryDragGhost.icon:SetTexture(group.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.categoryDragGhost:SetAlpha(0.75)
    self.categoryDragGhost:Show()

    if not self.categoryDragWatcher then
        local watcher = CreateFrame("Frame")
        watcher:Hide()
        watcher:SetScript("OnUpdate", function(w)
            if not SB.categoryDragGroup then
                SB.categoryDragHoverTarget = nil
                w:Hide()
                return
            end

            if IsMouseButtonDown("LeftButton") then
                SB.categoryDragHoverTarget = SB:GetCategoryTitleUnderCursor()
                ForEachVisibleCategoryFrame(function(frame)
                    SetCategoryDropVisual(frame, frame == SB.categoryDragHoverTarget)
                end)
            else
                w:Hide()
                local target = SB.categoryDragHoverTarget
                SB.categoryDragHoverTarget = nil
                if target and target.categoryKey then
                    SB:DropGroupOnCategory(target.categoryKey)
                else
                    SB:EndCategoryDrag()
                    SB:RefreshBags("UI.lua:154")
                    if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() and (SB.bankMode or 1) ~= 2 then SB:RefreshBank("UI.lua:155") end
                end
            end
        end)
        self.categoryDragWatcher = watcher
    end
    self.categoryDragWatcher:Show()

    self:RefreshBags("UI.lua:163")
    if self.bankAccessOpen and self.bankFrame and self.bankFrame:IsShown() and (self.bankMode or 1) ~= 2 then self:RefreshBank("UI.lua:164") end

    self:ResetCategoryDropVisuals()
end


function SB:EndCategoryDrag()
    self.categoryDragGroup = nil
    self.categoryDragHoverTarget = nil
    ClearCursor()
    if self.categoryDragGhost then self.categoryDragGhost:Hide() end
    if self.categoryDragWatcher then self.categoryDragWatcher:Hide() end
    self:ResetCategoryDropVisuals()
end

function SB:DropGroupOnCategory(categoryKey)
    local group = self.categoryDragGroup
    if not group or not group.itemID then
        self:EndCategoryDrag()
        return
    end

    local id = tostring(group.itemID)
    if self.db.categories.custom[categoryKey] or self.Categories[categoryKey] then
        self.db.categories.assignments[id] = categoryKey
        self.db.categories.assignments[group.itemID] = nil
        if self.PersistCurrentProfile then self:PersistCurrentProfile() end
    end

    self:EndCategoryDrag()
    self:RefreshBags("UI.lua:194")
    if self.bankAccessOpen and self.bankFrame and self.bankFrame:IsShown() then self:RefreshBank("UI.lua:195") end
    if self.settingsFrame and self.settingsFrame:IsShown() then
        self:RefreshCategorySettings()
    end
end

function SB:GetCategoryFrameUnderCursorForOrder(sourceKey)
    local rawX, rawY=GetCursorPosition()
    local found
    ForEachVisibleCategoryFrame(function(frame)
        if found or not frame.categoryKey or frame.categoryKey==sourceKey then return end
        local scale=frame:GetEffectiveScale()
        local x,y=rawX/scale,rawY/scale
        local l,r,b,t=frame:GetLeft(),frame:GetRight(),frame:GetBottom(),frame:GetTop()
        if l and r and b and t and x>=l and x<=r and y>=b and y<=t then found=frame end
    end)
    return found
end

function SB:SwapCategoryOrder(firstKey, secondKey)
    if not firstKey or not secondKey or firstKey==secondKey then return false end
    local order=self.db.categories.order or {}
    local a,b
    for i,key in ipairs(order) do
        if key==firstKey then a=i elseif key==secondKey then b=i end
    end
    if not a or not b then return false end
    order[a],order[b]=order[b],order[a]
    if self.PersistCurrentProfile then self:PersistCurrentProfile() end
    return true
end

function SB:ClearCategoryOrderHighlight()
    ForEachVisibleCategoryFrame(function(frame)
        if frame._wagBankNoBackdrop then
            frame:SetBackdropBorderColor(0,0,0,0)
        else
            frame:SetBackdropBorderColor(.14,.14,.17,1)
        end
    end)
end

function SB:BeginCategoryOrderDrag(categoryKey)
    if self.db.layout.locked or self.categoryDragGroup then return end
    self.categoryOrderDragKey=categoryKey
    self.categoryOrderLastSwap=nil

    if not self.categoryOrderGhost then
        local ghost=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        ghost:SetFrameStrata("TOOLTIP"); ghost:SetSize(150,24)
        ghost:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        ghost:SetBackdropColor(.03,.03,.04,.88); ghost:SetBackdropBorderColor(1,.82,0,1)
        ghost.text=ghost:CreateFontString(nil,"OVERLAY","GameFontNormal")
        ghost.text:SetPoint("CENTER")
        ghost:SetScript("OnUpdate",function(g)
            if not SB.categoryOrderDragKey then g:Hide(); return end
            local x,y=GetCursorPosition(); local scale=UIParent:GetEffectiveScale()
            g:ClearAllPoints(); g:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale+18,y/scale-16)
        end)
        self.categoryOrderGhost=ghost
    end
    local def=self.Categories[categoryKey] or (self.db.categories.custom and self.db.categories.custom[categoryKey])
    self.categoryOrderGhost.text:SetText((def and def.name) or categoryKey)
    self.categoryOrderGhost:Show()

    if not self.categoryOrderWatcher then
        local watcher=CreateFrame("Frame"); watcher:Hide()
        watcher:SetScript("OnUpdate",function(w)
            if not SB.categoryOrderDragKey then w:Hide(); return end

            local hovered=SB:GetCategoryFrameUnderCursorForOrder(SB.categoryOrderDragKey)
            SB:ClearCategoryOrderHighlight()
            if hovered then hovered:SetBackdropBorderColor(1,.82,0,1) end

            if hovered and hovered.categoryKey~=SB.categoryOrderLastSwap then
                local source=SB.categoryOrderDragKey
                local target=hovered.categoryKey
                if SB:SwapCategoryOrder(source,target) then
                    SB.categoryOrderLastSwap=target
                    SB:RefreshBags("UI.lua:268")
                     
                     
                    if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then
                        SB:RefreshBank("UI.lua:OrderDragSwap")
                    end
                end
            elseif not hovered then
                SB.categoryOrderLastSwap=nil
            end

            if not IsMouseButtonDown("LeftButton") then
                w:Hide()
                SB.categoryOrderDragKey=nil
                SB.categoryOrderLastSwap=nil
                if SB.categoryOrderGhost then SB.categoryOrderGhost:Hide() end
                SB:ClearCategoryOrderHighlight()
                SB:RefreshBags("UI.lua:280")
                if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank("UI.lua:281") end
            end
        end)
        self.categoryOrderWatcher=watcher
    end
    self.categoryOrderWatcher:Show()
end

function SB:UpdateLockVisual()
    if not self.lockButton then return end
    local b = self.lockButton

    if self.db.layout.locked then
        b.shackle:ClearAllPoints()
        b.shackle:SetPoint("BOTTOM", b.icon, "TOP", 0, -1)
        b.shackle:SetSize(9, 7)
        b.icon:SetVertexColor(1, .82, 0, 1)
        b.shackle:SetVertexColor(1, .82, 0, 1)
    else
        b.shackle:ClearAllPoints()
        b.shackle:SetPoint("BOTTOM", b.icon, "TOP", 3, -1)
        b.shackle:SetSize(7, 7)
        b.icon:SetVertexColor(1, .82, 0, 1)
        b.shackle:SetVertexColor(1, .82, 0, 1)
    end

    b.hole:SetVertexColor(.05, .05, .06, 1)
end

local VALID_GROWTH_ANCHORS = {
    TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true,
}

function SB:SetMainFrameEscapeEnabled(enabled)
    if not UISpecialFrames then return end
    for i=#UISpecialFrames,1,-1 do
        if UISpecialFrames[i]=="WagBagMainFrame" then table.remove(UISpecialFrames,i) end
    end
    if enabled then table.insert(UISpecialFrames,"WagBagMainFrame") end
end

function SB:GetGrowthAnchor()
    local anchor = self.db and self.db.layout and self.db.layout.growthAnchor or "TOPLEFT"
    if not VALID_GROWTH_ANCHORS[anchor] then anchor="TOPLEFT" end
    return anchor
end

function SB:UpdateGrowthAnchorMarker()
    if not self.mainFrame then return end
    local marker=self.growthAnchorMarker
    if not marker then
        marker=CreateFrame("Frame",nil,self.mainFrame)
        marker:SetSize(42,42)
        marker:SetFrameStrata("TOOLTIP")
        marker:SetFrameLevel((self.mainFrame:GetFrameLevel() or 1)+50)
        marker:EnableMouse(false)

        local horizontal=marker:CreateTexture(nil,"OVERLAY")
        horizontal:SetColorTexture(0.1,1.0,0.2,0.95)
        horizontal:SetSize(38,4)
        horizontal:SetPoint("CENTER")

        local vertical=marker:CreateTexture(nil,"OVERLAY")
        vertical:SetColorTexture(0.1,1.0,0.2,0.95)
        vertical:SetSize(4,38)
        vertical:SetPoint("CENTER")

        self.growthAnchorMarker=marker
    end

    marker:ClearAllPoints()
    local anchor=self:GetGrowthAnchor()
    marker:SetPoint("CENTER",self.mainFrame,anchor,0,0)
    if self.settingsFrame and self.settingsFrame:IsShown() then marker:Show() else marker:Hide() end
end

function SB:GetFramePointInUIParent(anchor)
    if not self.mainFrame then return nil end
    anchor=VALID_GROWTH_ANCHORS[anchor] and anchor or self:GetGrowthAnchor()
    local px=anchor:find("RIGHT") and self.mainFrame:GetRight() or self.mainFrame:GetLeft()
    local py=anchor:find("TOP") and self.mainFrame:GetTop() or self.mainFrame:GetBottom()
    if not px or not py then return nil end
    local frameScale=self.mainFrame:GetEffectiveScale() or 1
    local parentScale=UIParent:GetEffectiveScale() or 1
    local ratio=frameScale/parentScale
    return px*ratio,py*ratio
end

function SB:EnsureBagAnchorFrame()
    if self.bagAnchorFrame then return self.bagAnchorFrame end
    local anchorFrame=CreateFrame("Frame",nil,UIParent)
    anchorFrame:SetSize(1,1)
    anchorFrame:SetScale(1)
    anchorFrame:EnableMouse(false)
    self.bagAnchorFrame=anchorFrame
    return anchorFrame
end

function SB:SetBagAnchorPosition(x,y)
    if x==nil or y==nil then return end
    local anchorFrame=self:EnsureBagAnchorFrame()
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
    local layout=self.db and self.db.layout
    if layout then
        layout.point="BOTTOMLEFT"
        layout.relativePoint="BOTTOMLEFT"
        layout.x=x
        layout.y=y
        layout.anchorModel=2
    end
end

function SB:AttachMainFrameToBagAnchor(anchor)
    if not self.mainFrame then return end
    anchor=VALID_GROWTH_ANCHORS[anchor] and anchor or self:GetGrowthAnchor()
    local anchorFrame=self:EnsureBagAnchorFrame()
    self.mainFrame:ClearAllPoints()
    self.mainFrame:SetPoint(anchor,anchorFrame,"CENTER",0,0)
end

function SB:CaptureGrowthAnchorPosition(anchor)
    anchor=VALID_GROWTH_ANCHORS[anchor] and anchor or self:GetGrowthAnchor()
    local x,y=self:GetFramePointInUIParent(anchor)
    if x==nil or y==nil then return nil end
    return anchor,x,y
end

function SB:ApplyGrowthAnchorPosition(anchor,x,y)
    if not self.mainFrame or not anchor or x==nil or y==nil then return end
    self:SetBagAnchorPosition(x,y)
    self:AttachMainFrameToBagAnchor(anchor)
end

function SB:SaveCurrentPositionForGrowthAnchor()
    local anchor,x,y=self:CaptureGrowthAnchorPosition()
    if not anchor then return end
    self:SetBagAnchorPosition(x,y)
    self:AttachMainFrameToBagAnchor(anchor)
    if self.PersistCurrentProfile then self:PersistCurrentProfile() end
end

function SB:SetGrowthAnchor(anchor)
    if not VALID_GROWTH_ANCHORS[anchor] then return end
    local layout=self.db.layout
    local oldAnchor=self:GetGrowthAnchor()
    if self.mainFrame and layout.anchorModel==2 and layout.x~=nil and layout.y~=nil then
        local scale=(self.mainFrame:GetEffectiveScale() or 1)/(UIParent:GetEffectiveScale() or 1)
        local w=(self.mainFrame:GetWidth() or 0)*scale
        local h=(self.mainFrame:GetHeight() or 0)*scale
        local function cornerOffset(a)
            local x=a:find("RIGHT") and w or 0
            local y=a:find("TOP") and h or 0
            return x,y
        end
        local ox,oy=cornerOffset(oldAnchor)
        local nx,ny=cornerOffset(anchor)
        self:SetBagAnchorPosition(layout.x+(nx-ox),layout.y+(ny-oy))
        layout.growthAnchor=anchor
        self:AttachMainFrameToBagAnchor(anchor)
        if self.PersistCurrentProfile then self:PersistCurrentProfile() end
    else
        layout.growthAnchor=anchor
    end
    if self.UpdateGrowthAnchorMarker then self:UpdateGrowthAnchorMarker() end
    if self.RefreshSettingsValues then self:RefreshSettingsValues() end
end

function SB:CreateMainFrame()
    local frame = CreateFrame(
        "Frame", "WagBagMainFrame", UIParent, "BackdropTemplate"
    )

    local layout = self.db.layout
    if layout.anchorModel==2 then
        frame:SetPoint("CENTER")
    elseif layout.point and layout.relativePoint and layout.x and layout.y then
        frame:SetPoint(layout.point, UIParent, layout.relativePoint, layout.x, layout.y)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetSize(400, 200)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.025, 0.025, 0.032, tonumber(self.db.layout.backgroundAlpha) or 0.97)
    frame:SetBackdropBorderColor(0.18, 0.18, 0.22, 1)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(selfFrame)
        if not self.db.layout.locked then selfFrame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        if not self.db.layout.locked then
            self:SaveCurrentPositionForGrowthAnchor()
        end
    end)
    frame:SetScript("OnMouseUp", function(_,button)
        if (button=="LeftButton" or button=="RightButton") and CursorHasItem() then
            if self:DropCursorItemIntoBags() then C_Timer.After(0,function() if self.mainFrame and self.mainFrame:IsShown() then self:RefreshBags("UI.lua:488") end end) end
        end
    end)

    local broomButton = CreateFrame("Button", nil, frame)
    broomButton:SetSize(20, 20)
    broomButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, -9)
    local broomHandle = broomButton:CreateTexture(nil, "ARTWORK")
    broomHandle:SetTexture("Interface\\Buttons\\WHITE8X8")
    broomHandle:SetSize(3, 17)
    broomHandle:SetPoint("CENTER", 2, 1)
    broomHandle:SetVertexColor(.72, .45, .16, 1)
    broomHandle:SetRotation(-0.58)

    local broomBrush = broomButton:CreateTexture(nil, "OVERLAY")
    broomBrush:SetTexture("Interface\\Buttons\\WHITE8X8")
    broomBrush:SetSize(10, 7)
    broomBrush:SetPoint("CENTER", -4, -5)
    broomBrush:SetVertexColor(1, .78, .05, 1)
    broomBrush:SetRotation(-0.58)
    broomButton:SetScript("OnClick", function()
         
         
        if self.isMainline and C_Container and C_Container.SortBags then
            self:ClearRecentItems()
            self:ResetVisualSlotSession()
            self:BeginInventorySortTracking()
            C_Container.SortBags()
            self:RefreshBags("UI.lua:516")
            return
        end
         
        self:ClearRecentItems()
        self:ResetVisualSlotSession()
        local groups = self:ScanBags()
        self.inventorySnapshot = self:BuildInventorySnapshot(groups)
        self:RefreshBags("UI.lua:524")
    end)
    broomButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        if self.isMainline and C_Container and C_Container.SortBags then
            GameTooltip:SetText(self:T("SORT_STACKS"))
            GameTooltip:AddLine(self:T("SORT_STACKS_DESC"),1,1,1)
        else
            GameTooltip:SetText(self:T("CLEAR_RECENT"))
            GameTooltip:AddLine(self:T("CLEAR_RECENT_DESC"),1,1,1)
        end
        GameTooltip:Show()
    end)
    broomButton:SetScript("OnLeave", GameTooltip_Hide)
    broomButton:Show()

    local headerTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", WINDOW_PADDING, -12)
    headerTitle:SetText("WagBag")
    self.mainHeaderTitle=headerTitle

    local searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    searchBox:SetSize(132, 20)
    searchBox:SetPoint("LEFT", headerTitle, "RIGHT", 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlight")
    searchBox:SetTextInsets(6, 18, 0, 0)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(0.035, 0.035, 0.045, 0.96)
    searchBox:SetBackdropBorderColor(0.16, 0.16, 0.20, 1)

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText(self:T("SEARCH"))
    searchBox.placeholder = placeholder

    local clearSearch = CreateFrame("Button", nil, searchBox)
    clearSearch:SetSize(14, 14)
    clearSearch:SetPoint("RIGHT", -2, 0)
    local clearText = clearSearch:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clearText:SetPoint("CENTER")
    clearText:SetText("×")
    clearSearch:Hide()

    local function UpdateSearchState()
        local text = searchBox:GetText() or ""
        placeholder:SetShown(text == "")
        clearSearch:SetShown(text ~= "")
        if not self._syncingItemSearch then
            self:SetUnifiedItemSearch(text)
        end
    end

    self.mainSearchBox = searchBox
    searchBox:SetScript("OnTextChanged", UpdateSearchState)
    searchBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    clearSearch:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)


    local bagCounter = CreateFrame("Frame", nil, frame)
    bagCounter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", WINDOW_PADDING, 7)
    bagCounter:SetSize(145, 20)

    local bagIcon = bagCounter:CreateTexture(nil, "ARTWORK")
    bagIcon:SetSize(18,18)
    bagIcon:SetPoint("LEFT",0,0)
    bagIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")

    local normalText = bagCounter:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    normalText:SetPoint("LEFT",bagIcon,"RIGHT",3,0)
    normalText:SetJustifyH("LEFT")

    local reagentIcon = bagCounter:CreateTexture(nil, "ARTWORK")
    reagentIcon:SetSize(18,18)
    reagentIcon:SetPoint("LEFT",normalText,"RIGHT",9,0)
    reagentIcon:SetTexture("Interface\\Icons\\INV_Enchant_DustIllusion")

    local reagentText = bagCounter:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reagentText:SetPoint("LEFT",reagentIcon,"RIGHT",3,0)
    reagentText:SetJustifyH("LEFT")

    bagCounter.normalText=normalText
    bagCounter.reagentText=reagentText
    bagCounter.reagentIcon=reagentIcon
    if not self.hasReagentBag then
        reagentIcon:Hide()
        reagentText:Hide()
    end

    local closeButton = self:CreateHeaderCloseButton(frame)
    closeButton:SetPoint("TOPRIGHT", -4, -8)

    local bagBar = self:CreateBagBar(frame)
    bagBar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -4, 4)

    local lockButton = CreateFrame("Button", nil, frame)
    lockButton:SetSize(20, 20)
    lockButton:SetPoint("RIGHT", closeButton, "LEFT", -1, 0)

    local lockBody = lockButton:CreateTexture(nil, "ARTWORK")
    lockBody:SetTexture("Interface\\Buttons\\WHITE8X8")
    lockBody:SetSize(13, 10)
    lockBody:SetPoint("CENTER", 0, -3)

    local lockShackle = lockButton:CreateTexture(nil, "ARTWORK")
    lockShackle:SetTexture("Interface\\Buttons\\WHITE8X8")
    lockShackle:SetSize(9, 7)
    lockShackle:SetPoint("BOTTOM", lockBody, "TOP", 0, -1)

    local lockHole = lockButton:CreateTexture(nil, "OVERLAY")
    lockHole:SetTexture("Interface\\Buttons\\WHITE8X8")
    lockHole:SetSize(3, 5)
    lockHole:SetPoint("TOP", lockShackle, "TOP", 0, -2)

    lockButton.icon = lockBody
    lockButton.shackle = lockShackle
    lockButton.hole = lockHole
    lockButton:SetScript("OnClick", function()
        self.db.layout.locked = not self.db.layout.locked
        if self.PersistCurrentProfile then self:PersistCurrentProfile() end
        self:UpdateLockVisual()
    end)
    lockButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.db.layout.locked and self:T("UNLOCK_BAGS") or self:T("LOCK_BAGS"))
        GameTooltip:AddLine(self:T("LOCK_BAGS_DESC"), 1, 1, 1)
        GameTooltip:Show()
    end)
    lockButton:SetScript("OnLeave", GameTooltip_Hide)
    self.lockButton = lockButton


    local bagButton = CreateFrame("Button", nil, frame)
    bagButton:SetSize(20, 20)
    bagButton:SetPoint("RIGHT", lockButton, "LEFT", -3, 0)
    local bagIcon = bagButton:CreateTexture(nil, "ARTWORK")
    bagIcon:SetAllPoints()
    bagIcon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    bagIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bagButton:SetScript("OnClick", function() self:ToggleBagBar() end)
    bagButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self:T("BAGS"))
        GameTooltip:AddLine(self:T("BAGS_DESC"), 1, 1, 1)
        GameTooltip:Show()
    end)
    bagButton:SetScript("OnLeave", GameTooltip_Hide)
    bagButton:Show()

    local modeButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    modeButton:SetSize(20,20)
    modeButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})

    local modeCellA=modeButton:CreateTexture(nil,"ARTWORK")
    local modeCellB=modeButton:CreateTexture(nil,"OVERLAY")
    modeCellA:SetTexture("Interface\\Buttons\\WHITE8X8")
    modeCellB:SetTexture("Interface\\Buttons\\WHITE8X8")
    modeCellA:SetSize(8,8)
    modeCellB:SetSize(8,8)
    modeButton.cellA=modeCellA
    modeButton.cellB=modeCellB

    local function UpdateModeVisual()
        local split=self.db.splitView and self.db.splitView.enabled
        modeCellA:ClearAllPoints(); modeCellB:ClearAllPoints()
        if split then
            modeCellA:SetPoint("LEFT",modeButton,"LEFT",2,0)
            modeCellB:SetPoint("RIGHT",modeButton,"RIGHT",-2,0)
            modeCellA:SetVertexColor(.82,.82,.82,1)
            modeCellB:SetVertexColor(1,1,1,1)
            modeButton:SetBackdropColor(.025,.025,.025,.96)
            modeButton:SetBackdropBorderColor(.72,.72,.72,1)
        else
            modeCellA:SetPoint("CENTER",modeButton,"CENTER",-2,2)
            modeCellB:SetPoint("CENTER",modeButton,"CENTER",2,-2)
            modeCellA:SetVertexColor(.58,.58,.58,1)
            modeCellB:SetVertexColor(.88,.70,.08,1)
            modeButton:SetBackdropColor(.035,.035,.04,.95)
            modeButton:SetBackdropBorderColor(.22,.22,.25,1)
        end
    end
    modeButton:SetScript("OnClick",function()
        self.db.splitView.enabled=not self.db.splitView.enabled
        if self.PersistCurrentProfile then self:PersistCurrentProfile() end

        self.recentGroupKeys={}
        self.pendingRecentGroupKeys={}
        self:ResetVisualSlotSession()
        self.bagScanCache=nil

        local cache=self:ScanAndCacheBags()
        self.inventorySnapshot=self:BuildInventorySnapshot(cache.groups)

        UpdateModeVisual()
        self:RefreshBags("UI.lua:729")
    end)
    modeButton:SetScript("OnEnter",function(button)
        GameTooltip:SetOwner(button,"ANCHOR_BOTTOM")
        GameTooltip:SetText((self.db.splitView and self.db.splitView.enabled) and self:T("SPLIT_STACKS") or self:T("MERGED_STACKS"))
        GameTooltip:AddLine(self:T("STACK_MODE_DESC"),1,1,1)
        GameTooltip:Show()
    end)
    modeButton:SetScript("OnLeave",GameTooltip_Hide)
    UpdateModeVisual()

    closeButton:ClearAllPoints(); closeButton:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-7)
    lockButton:ClearAllPoints(); lockButton:SetPoint("RIGHT",closeButton,"LEFT",-2,0)
    bagButton:ClearAllPoints(); bagButton:SetPoint("RIGHT",lockButton,"LEFT",-3,0)
    modeButton:SetPoint("RIGHT",bagButton,"LEFT",-3,0)
    broomButton:ClearAllPoints(); broomButton:SetPoint("RIGHT",modeButton,"LEFT",-3,0)

    self:UpdateLockVisual()

    frame:Hide()

    frame:SetScript("OnHide", function()
        if self.ResetBagSearchOnToggle then self:ResetBagSearchOnToggle() end
        self:HideBagBar()
        self:EndCategoryDrag()
        self.recentGroupKeys = nil
    end)

    self:SetMainFrameEscapeEnabled(true)

    local currencyBar = CreateFrame("Frame", nil, frame)
    currencyBar:SetHeight(20)
    currencyBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", WINDOW_PADDING, 30)
    currencyBar:Hide()
    self.currencyBar = currencyBar

    local moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moneyText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -WINDOW_PADDING, 12)
    moneyText:SetJustifyH("RIGHT")
    self.moneyText = moneyText

    self.mainFrame = frame
    self.tutorialModeAnchor = modeButton
    self.tutorialBroomAnchor = broomButton
    frame:HookScript("OnShow", function()
        if self.TutorialOnBagShown then self:TutorialOnBagShown() end
    end)
    frame:HookScript("OnHide", function()
        if self.StopTutorial then self:StopTutorial() end
    end)

    local growthAnchor=self:GetGrowthAnchor()
    if layout.anchorModel==2 and layout.x~=nil and layout.y~=nil then
        self:SetBagAnchorPosition(layout.x,layout.y)
        self:AttachMainFrameToBagAnchor(growthAnchor)
    else
        local anchorX,anchorY=self:GetFramePointInUIParent(growthAnchor)
        if anchorX~=nil and anchorY~=nil then
            self:SetBagAnchorPosition(anchorX,anchorY)
            self:AttachMainFrameToBagAnchor(growthAnchor)
        end
    end
    self.bagCounter = bagCounter
    return frame
end

function SB:RefreshBags(source)
    if not self.mainFrame then return end

    self.mainFrame:SetBackdropColor(0.025,0.025,0.032,tonumber(self.db.layout.backgroundAlpha) or 0.97)

    local cache=self.bagScanCache
    if not cache then
        cache=self:ScanAndCacheBags()
    end
    local groups=cache.groups
    local totalSlots,usedSlots=cache.totalSlots,cache.usedSlots
    local normalTotal,normalUsed=cache.normalTotal,cache.normalUsed
    local reagentTotal,reagentUsed=cache.reagentTotal,cache.reagentUsed
    local categories=self:BuildCategoryBuckets(groups)
    self:ApplyVisualSlotSession(categories)
    self.bagCounter.normalText:SetText((normalUsed or 0).."/"..(normalTotal or 0))
    if self.hasReagentBag then
        self.bagCounter.reagentText:SetText((reagentUsed or 0).."/"..(reagentTotal or 0))
    else
        self.bagCounter.reagentText:SetText("")
    end
    if self.moneyText then
        local copper=GetMoney() or 0
        local gold=math.floor(copper/10000)
        local silver=math.floor((copper%10000)/100)
        local coin=copper%100
        self.moneyText:SetText(string.format("%d|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:0:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:0:0|t %d|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:0:0|t",gold,silver,coin))
    end
    self:RefreshBagBar()

     
     
    for _,frame in ipairs(self.categoryFrames) do
        frame:SetBackdropColor(0,0,0,0)
        frame:SetBackdropBorderColor(0,0,0,0)
        frame:Hide()
    end

    local scale=math.max(0.5,math.min(2.0,tonumber(self.db.layout.scale) or 1.0))
    self.mainFrame:SetScale(scale)
    local cellsPerRow=math.max(2,math.min(10,tonumber(self.db.layout.cellsPerRow) or 4))
    local configuredBlocksPerRow=math.max(1,math.min(4,tonumber(self.db.layout.blocksPerRow) or 2))
    local maxVisualColumns=math.max(configuredBlocksPerRow,3)
    local columnHeightLimit=(UIParent:GetHeight() or 768)*(2/3)/scale

    local buttonIndex=0
    local categoryFrameIndex=0
    local normalIndex=0
    local normalLayouts={}
    local recentHeight=0
    local recentWidth=0

    local function BlockHeight(category,columns)
        local displayItems=category.visualItems or category.items
        local itemCount=#displayItems
        local itemRows=itemCount>0 and math.ceil(itemCount/columns) or 0
        if itemRows>0 then
            return BLOCK_TITLE_HEIGHT+BLOCK_PADDING+itemRows*self.SLOT_SIZE+math.max(0,itemRows-1)*self.SLOT_SPACING+BLOCK_PADDING
        end
        return BLOCK_TITLE_HEIGHT+2
    end

    local function BlockWidth(category,columns,title)
        local displayItems=category.visualItems or category.items
        local shownColumns=math.min(columns,math.max(1,#displayItems))
        local itemsWidth=BLOCK_PADDING*2+shownColumns*self.SLOT_SIZE+math.max(0,shownColumns-1)*self.SLOT_SPACING
        local titleWidth=math.ceil(title:GetStringWidth() or 0)+BLOCK_PADDING*2+4
        return math.max(itemsWidth,titleWidth)
    end

    local function PopulateBlock(block,category,columns,itemParent,itemTopOffset)
        local displayItems=category.visualItems or category.items
        local blockHeight=BlockHeight(category,columns)
        local blockWidth=BlockWidth(category,columns,block.title)
        local parent=itemParent or block
        local topOffset=itemTopOffset or BLOCK_TITLE_HEIGHT

        for itemIndex,group in ipairs(displayItems) do
            if group then
                buttonIndex=buttonIndex+1
                local button=self.itemButtons[buttonIndex]
                if not button then button=self:CreateItemButton(parent); self.itemButtons[buttonIndex]=button else button:SetParent(parent) end
                local column=(itemIndex-1)%columns
                local row=math.floor((itemIndex-1)/columns)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT",parent,"TOPLEFT",BLOCK_PADDING+column*(self.SLOT_SIZE+self.SLOT_SPACING),-(topOffset+BLOCK_PADDING+row*(self.SLOT_SIZE+self.SLOT_SPACING)))
                self:BindBagItemButton(button,group)
                button:Show()
            end
        end
        return blockHeight,blockWidth
    end

    local recentCategory
    for _,category in ipairs(categories) do
        if category.key=="__recent" then
            recentCategory=category
            break
        end
    end

    self:RefreshCurrencyBar()
    local infoCounterWidth=math.max(145,self.bagCounter:GetWidth() or 145)
    local infoMoneyWidth=math.max(190,math.ceil(self.moneyText:GetStringWidth() or 0))
    local minimumInfoWidth=WINDOW_PADDING*2+infoCounterWidth+12+infoMoneyWidth
    local currencyWidth=self.currencyBar and self.currencyBar:IsShown() and (self.currencyBar:GetWidth()+WINDOW_PADDING*2) or 0

    local measureTitle=self._bagLayoutMeasureTitle
    if not measureTitle then
        measureTitle=self.mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
        measureTitle:Hide()
        self._bagLayoutMeasureTitle=measureTitle
    end

    local function PlanNormalLayout(recentReserveHeight)
        local start=HEADER_HEIGHT+(recentReserveHeight>0 and (recentReserveHeight+BLOCK_GAP) or 0)
        local placementY={}
        local columns={}
        local widths={}
        local index=0
        local highest=-1
        local maxBottom=start
        for _,category in ipairs(categories) do
            if category.key~="__recent" then
                index=index+1
                local col=(index-1)%configuredBlocksPerRow
                local height=BlockHeight(category,cellsPerRow)
                for c=0,maxVisualColumns-1 do
                    if placementY[c]==nil then placementY[c]=start end
                end
                if placementY[col]+height>columnHeightLimit and col+1<maxVisualColumns then
                    col=col+1
                    while col+1<maxVisualColumns and placementY[col]+height>columnHeightLimit do
                        col=col+1
                    end
                end
                columns[index]=col
                highest=math.max(highest,col)
                measureTitle:SetText(category.name)
                widths[col]=math.max(widths[col] or 0,BlockWidth(category,cellsPerRow,measureTitle))
                maxBottom=math.max(maxBottom,placementY[col]+height)
                placementY[col]=placementY[col]+height+BLOCK_GAP
            end
        end
        local width=0
        for col=0,highest do width=width+(widths[col] or 0)+BLOCK_GAP end
        if highest>=0 then width=width-BLOCK_GAP end
        return columns,width,maxBottom-start
    end

    local minimumBlockWidth=BLOCK_PADDING*2+cellsPerRow*self.SLOT_SIZE+(cellsPerRow-1)*self.SLOT_SPACING

    local function RecentColumnsForWidth(width)
        local capacity=math.floor((width-BLOCK_PADDING*2+self.SLOT_SPACING)/(self.SLOT_SIZE+self.SLOT_SPACING))
        return math.max(cellsPerRow,capacity)
    end

    local function VisibleRecentHeight(category,columns,normalHeight)
        local count=#(category.visualItems or category.items)
        local rows=math.max(1,math.ceil(count/columns))
        local screenHeight=(UIParent:GetHeight() or 768)/scale
        local currencyFooter=self.currencyBar and self.currencyBar:IsShown() and 23 or 0
        local available=screenHeight*0.90-HEADER_HEIGHT-normalHeight-(normalHeight>0 and BLOCK_GAP or 0)-2*WINDOW_PADDING-27-currencyFooter-BLOCK_TITLE_HEIGHT
        local viewportLimit=math.min(screenHeight*0.50,available)
        local maxRows=math.max(1,math.floor((viewportLimit-BLOCK_PADDING*2+self.SLOT_SPACING)/(self.SLOT_SIZE+self.SLOT_SPACING)))
        local visibleRows=math.min(rows,maxRows)
        local viewportHeight=BLOCK_PADDING*2+visibleRows*self.SLOT_SIZE+math.max(0,visibleRows-1)*self.SLOT_SPACING
        return BLOCK_TITLE_HEIGHT+viewportHeight
    end

    local plannedColumns,naturalNormalWidth,naturalNormalHeight=PlanNormalLayout(0)
    local headerTextWidth=math.ceil(self.mainHeaderTitle and self.mainHeaderTitle:GetStringWidth() or 48)
    local minimumHeaderWidth=WINDOW_PADDING+headerTextWidth+64+125
    local minimumWindowWidth=math.max(minimumBlockWidth+WINDOW_PADDING*2,minimumInfoWidth,minimumHeaderWidth,currencyWidth)
    local recentColumns=0
    local recentTargetWidth=math.max(minimumBlockWidth,naturalNormalWidth,minimumWindowWidth-WINDOW_PADDING*2)
    if recentCategory then
        recentColumns=RecentColumnsForWidth(recentTargetWidth)
        recentHeight=VisibleRecentHeight(recentCategory,recentColumns,naturalNormalHeight)
    end

    if recentCategory then
        categoryFrameIndex=categoryFrameIndex+1
        local block=AcquireCategoryFrame(self.mainFrame,categoryFrameIndex)
        block.title:SetText(recentCategory.name)
        block.categoryKey=recentCategory.key
        block.titleHandle.categoryKey=nil
        if not block.recentScroll then
            local viewport=CreateFrame("ScrollFrame",nil,block)
            local content=CreateFrame("Frame",nil,viewport)
            content:SetSize(1,1)
            viewport:SetScrollChild(content)
            viewport:EnableMouseWheel(true)
            viewport:SetScript("OnMouseWheel",function(scroll,direction)
                local range=block.recentExpectedScrollRange or 0
                if range<=1 then
                    scroll:SetVerticalScroll(0)
                else
                    local offset=scroll:GetVerticalScroll()-direction*(self.SLOT_SIZE+self.SLOT_SPACING)*3
                    scroll:SetVerticalScroll(math.max(0,math.min(range,offset)))
                end
                UpdateRecentOverflowIndicators(block)
            end)
            viewport:SetScript("OnVerticalScroll",function()
                UpdateRecentOverflowIndicators(block)
            end)
            viewport:SetScript("OnScrollRangeChanged",function()
                UpdateRecentOverflowIndicators(block)
            end)
            block.recentScroll=viewport
            block.recentContent=content
            local function CreateHint(texture,anchor,offset)
                local indicator=CreateFrame("Frame",nil,block,"BackdropTemplate")
                indicator:SetSize(20,20)
                indicator:SetFrameLevel(viewport:GetFrameLevel()+20)
                indicator:EnableMouse(false)
                indicator:SetPoint(anchor,viewport,anchor,0,offset)
                indicator:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
                indicator:SetBackdropColor(0,0,0,0.30)
                indicator:SetBackdropBorderColor(1.00,0.90,0.35,0.45)
                local glow=indicator:CreateTexture(nil,"BACKGROUND")
                glow:SetAllPoints()
                glow:SetTexture("Interface\\Buttons\\WHITE8X8")
                glow:SetVertexColor(1.00,0.90,0.35,0.10)
                local icon=indicator:CreateTexture(nil,"OVERLAY")
                icon:SetPoint("TOPLEFT",1,-1)
                icon:SetPoint("BOTTOMRIGHT",-1,1)
                icon:SetTexture(texture)
                icon:SetTexCoord(0.25,0.75,0.25,0.75)
                icon:SetAlpha(1)
                indicator:Hide()
                return indicator
            end
            block.recentTopIndicator=CreateHint("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up","TOP",-2)
            block.recentBottomIndicator=CreateHint("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up","BOTTOM",2)
        end
        local fullHeight
        fullHeight,recentWidth=PopulateBlock(block,recentCategory,recentColumns,block.recentContent,0)
        recentWidth=math.max(recentWidth,recentTargetWidth)
        block.recentContent:SetSize(recentWidth,math.max(1,fullHeight-BLOCK_TITLE_HEIGHT))
        block.recentExpectedScrollRange=math.max(0,fullHeight-recentHeight)
        block.recentScroll:ClearAllPoints()
        block.recentScroll:SetPoint("TOPLEFT",block,"TOPLEFT",0,-BLOCK_TITLE_HEIGHT)
        block.recentScroll:SetSize(recentWidth,recentHeight-BLOCK_TITLE_HEIGHT)
        local recentRange=block.recentExpectedScrollRange
        if recentRange<=1 then
            block.recentScroll:SetVerticalScroll(0)
        else
            block.recentScroll:SetVerticalScroll(math.max(0,math.min(block.recentScroll:GetVerticalScroll(),recentRange)))
        end
        block.recentScroll:Show()
        block:SetSize(recentWidth,recentHeight)
        UpdateRecentOverflowIndicators(block)
        block:ClearAllPoints()
        block:SetPoint("TOPLEFT",self.mainFrame,"TOPLEFT",WINDOW_PADDING,-HEADER_HEIGHT)
    end

    for _,category in ipairs(categories) do
        if category.key~="__recent" then
            categoryFrameIndex=categoryFrameIndex+1
            normalIndex=normalIndex+1
            local block=AcquireCategoryFrame(self.mainFrame,categoryFrameIndex)
            block.title:SetText(category.name)
            if block.recentScroll then block.recentScroll:Hide() end
            block.recentExpectedScrollRange=0
            if block.recentTopIndicator then block.recentTopIndicator:Hide() end
            if block.recentBottomIndicator then block.recentBottomIndicator:Hide() end
            block.categoryKey=category.key
            block.titleHandle.categoryKey=category.noReorder and nil or category.key
            local h,w=PopulateBlock(block,category,cellsPerRow)
            block:SetSize(w,h)
            normalLayouts[#normalLayouts+1]={frame=block,column=plannedColumns[normalIndex],height=h,width=w}
        end
    end

    local normalStart=HEADER_HEIGHT
    if recentHeight>0 then normalStart=normalStart+recentHeight+BLOCK_GAP end

    local columnY={}
    local columnWidths={}
    for col=0,maxVisualColumns-1 do columnY[col]=normalStart end
    local highestColumn=-1
    for _,layout in ipairs(normalLayouts) do
        local col=layout.column
        highestColumn=math.max(highestColumn,col)
        columnWidths[col]=math.max(columnWidths[col] or 0,layout.width)
    end
    local columnX={}
    local nextX=WINDOW_PADDING
    for col=0,highestColumn do
        columnX[col]=nextX
        nextX=nextX+(columnWidths[col] or 0)+BLOCK_GAP
    end
    local normalWidth=highestColumn>=0 and (nextX-WINDOW_PADDING-BLOCK_GAP) or 0

    for _,layout in ipairs(normalLayouts) do
        local y=columnY[layout.column] or normalStart
        layout.frame:ClearAllPoints()
        layout.frame:SetPoint("TOPLEFT",self.mainFrame,"TOPLEFT",columnX[layout.column],-y)
        columnY[layout.column]=y+layout.height+BLOCK_GAP
    end

    for i=buttonIndex+1,#self.itemButtons do
        self:ResetItemButton(self.itemButtons[i])
    end

    local normalCount=#normalLayouts
    local contentWidth=WINDOW_PADDING*2+math.max(normalWidth,recentWidth)
    local windowWidth=math.max(contentWidth,minimumWindowWidth)
    if self.mainSearchBox then self.mainSearchBox:SetWidth(132) end
    self.bagCounter:ClearAllPoints()
    self.bagCounter:SetPoint("BOTTOMLEFT",self.mainFrame,"BOTTOMLEFT",WINDOW_PADDING,7)
    self.moneyText:ClearAllPoints()
    self.moneyText:SetPoint("BOTTOMRIGHT",self.mainFrame,"BOTTOMRIGHT",-WINDOW_PADDING,12)
    if self.currencyBar then
        self.currencyBar:ClearAllPoints()
        self.currencyBar:SetPoint("BOTTOMLEFT",self.mainFrame,"BOTTOMLEFT",WINDOW_PADDING,30)
    end
    local staticInfoFooter=27
    local currencyFooter=self.currencyBar and self.currencyBar:IsShown() and 23 or 0
    local contentBottom
    if normalCount>0 then
        contentBottom=normalStart
        for col=0,maxVisualColumns-1 do
            local bottom=(columnY[col] or normalStart)
            if bottom>normalStart then bottom=bottom-BLOCK_GAP end
            contentBottom=math.max(contentBottom,bottom)
        end
    elseif recentHeight>0 then contentBottom=HEADER_HEIGHT+recentHeight
    else contentBottom=HEADER_HEIGHT+self.SLOT_SIZE end
    local windowHeight=WINDOW_PADDING+contentBottom+WINDOW_PADDING+staticInfoFooter+currencyFooter
    self.mainFrame:SetSize(windowWidth,windowHeight)
    self._bagSearchNeedsRefresh = false
end

function SB:InstallUnitTooltipLayer()
    if self.unitTooltipLayerInstalled or not GameTooltip then return end
    self.unitTooltipLayerInstalled = true

    local tooltip = GameTooltip
    local originalStrata
    local lowered = false

    local function RestoreTooltipLayer()
        if not lowered then return end
        lowered = false
        local strata = originalStrata
        originalStrata = nil
        if strata then tooltip:SetFrameStrata(strata) end
    end

    local function LowerUnitTooltip(currentTooltip)
        if currentTooltip ~= tooltip or not self.mainFrame or not self.mainFrame:IsShown() then return end
        if not lowered then
            originalStrata = tooltip:GetFrameStrata()
            lowered = true
        end
        tooltip:SetFrameStrata("MEDIUM")
    end

    hooksecurefunc(tooltip, "SetOwner", RestoreTooltipLayer)
    tooltip:HookScript("OnHide", RestoreTooltipLayer)
    self.mainFrame:HookScript("OnHide", RestoreTooltipLayer)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, LowerUnitTooltip)
    elseif tooltip.HasScript and tooltip:HasScript("OnTooltipSetUnit") then
        tooltip:HookScript("OnTooltipSetUnit", LowerUnitTooltip)
    end
end

function SB:ToggleBags()
    if not self.mainFrame then return end
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
        return
    end

    self:ResetBagSearchOnToggle()
    self:BeginBagSession()
    self:RefreshBags("UI.lua:1025")
    self.mainFrame:Show()
end

function SB:UpdateMinimapButtonPosition()
    local b=self.minimapButton
    if not b or not Minimap then return end
    local angle=((WagBagDB and WagBagDB.minimap and WagBagDB.minimap.angle) or 225)*math.pi/180
    local radius=80
    b:ClearAllPoints()
    b:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*radius,math.sin(angle)*radius)
end

function SB:UpdateMinimapButtonVisibility()
    if not self.minimapButton then return end
    self.minimapButton:SetShown(not WagBagDB or not WagBagDB.minimap or WagBagDB.minimap.show~=false)
end

function SB:CreateMinimapButton()
    if self.minimapButton or not Minimap then return self.minimapButton end
    local b=CreateFrame("Button","LibDBIcon10_WagBag",Minimap)
    b:SetSize(31,31);b:SetFrameStrata("MEDIUM");b:SetFrameLevel(8);b:RegisterForClicks("LeftButtonUp");b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background=b:CreateTexture(nil,"BACKGROUND")
    background:SetSize(20,20);background:SetPoint("TOPLEFT",7,-5);background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon=b:CreateTexture(nil,"ARTWORK")
    icon:SetSize(20,20);icon:SetPoint("TOPLEFT",7,-5);icon:SetTexture("Interface\\AddOns\\WagBag\\WagBagIcon");icon:SetTexCoord(.08,.92,.08,.92)
    if icon.AddMaskTexture then
        local mask=b:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end

    local border=b:CreateTexture(nil,"OVERLAY")
    border:SetSize(53,53);border:SetPoint("TOPLEFT");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnClick",function() if not b._dragged then SB:OpenSettings() end;b._dragged=nil end)
    b:SetScript("OnEnter",function(x) GameTooltip:SetOwner(x,"ANCHOR_LEFT");GameTooltip:SetText("WagBag");GameTooltip:AddLine(SB:T("SETTINGS"),1,1,1);GameTooltip:Show() end)
    b:SetScript("OnLeave",GameTooltip_Hide)
    b:SetScript("OnDragStart",function(x) x._dragged=true;x:SetScript("OnUpdate",function()
        local mx,my=Minimap:GetCenter();local cx,cy=GetCursorPosition();local scale=Minimap:GetEffectiveScale();cx,cy=cx/scale,cy/scale
        local angle=math.deg(math.atan2(cy-my,cx-mx))
        WagBagDB.minimap=WagBagDB.minimap or {};WagBagDB.minimap.angle=angle;SB:UpdateMinimapButtonPosition()
    end) end)
    b:SetScript("OnDragStop",function(x) x:SetScript("OnUpdate",nil) end)
    self.minimapButton=b
    self:UpdateMinimapButtonPosition();self:UpdateMinimapButtonVisibility()
    return b
end
