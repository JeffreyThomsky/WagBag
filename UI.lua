local _, SB = ...

local WINDOW_PADDING = 12
local HEADER_HEIGHT = 32
local BLOCK_PADDING = 7
local BLOCK_TITLE_HEIGHT = 18
local BLOCK_GAP = 8

SB.itemButtons = SB.itemButtons or {}
SB.categoryFrames = SB.categoryFrames or {}
SB.dropTargets = SB.dropTargets or {}

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
    local baseAlpha = tonumber(SB.db and SB.db.layout and SB.db.layout.backgroundAlpha) or 0.97
    frame:SetBackdropColor(0.035, 0.035, 0.043, math.min(1, baseAlpha + 0.12))
    frame:SetBackdropBorderColor(0.14, 0.14, 0.17, math.min(1, baseAlpha + 0.28))

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

local function AcquireDropTarget(parent, index)
    local target = SB.dropTargets[index]
    if not target then
        target = CreateFrame("Button", nil, parent, "BackdropTemplate")
        target:SetSize(SB.SLOT_SIZE, SB.SLOT_SIZE)
        target:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        target:SetBackdropColor(0.05, 0.05, 0.06, 0.42)
        target:SetBackdropBorderColor(0.18, 0.18, 0.21, 0.9)

        local plus = target:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
        plus:SetPoint("CENTER")
        plus:SetText("+")
        target.plus = plus

        target:SetScript("OnEnter", function(t)
            if SB.categoryDragGroup then
                t:SetBackdropColor(0.16, 0.13, 0.03, 0.75)
                t:SetBackdropBorderColor(1, 0.82, 0, 1)
            end
        end)
        target:SetScript("OnLeave", function(t)
            t:SetBackdropColor(0.05, 0.05, 0.06, 0.42)
            t:SetBackdropBorderColor(0.18, 0.18, 0.21, 0.9)
        end)
        target:SetScript("OnClick", function()
            if SB.db.splitView and SB.db.splitView.enabled and CursorHasItem() then
                if SB:DropCursorItemIntoBags() then
                    C_Timer.After(0, function()
                        if SB.mainFrame and SB.mainFrame:IsShown() then SB:RefreshBags() end
                    end)
                end
            end
        end)
        SB.dropTargets[index] = target
    else
        target:SetParent(parent)
    end
    target:Show()
    return target
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

function SB:GetCategoryTitleUnderCursor()
    local rawX, rawY = GetCursorPosition()
    for _, frame in ipairs(self.categoryFrames) do
        if frame:IsShown() and frame.categoryKey and frame.categoryKey ~= "__recent" then
            local handle = frame.titleHandle
            local scale = handle:GetEffectiveScale()
            local x, y = rawX / scale, rawY / scale
            local l, r, b, t = handle:GetLeft(), handle:GetRight(), handle:GetBottom(), handle:GetTop()
            if l and r and b and t and x >= l and x <= r and y >= b and y <= t then
                return frame
            end
        end
    end
    return nil
end

function SB:ResetCategoryDropVisuals()
    for _, frame in ipairs(self.categoryFrames) do
        if frame:IsShown() then SetCategoryDropVisual(frame, false) end
    end
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
                for _, frame in ipairs(SB.categoryFrames) do
                    if frame:IsShown() then
                        SetCategoryDropVisual(frame, frame == SB.categoryDragHoverTarget)
                    end
                end
            else
                w:Hide()
                local target = SB.categoryDragHoverTarget
                SB.categoryDragHoverTarget = nil
                if target and target.categoryKey then
                    SB:DropGroupOnCategory(target.categoryKey)
                else
                    SB:EndCategoryDrag()
                    SB:RefreshBags()
                end
            end
        end)
        self.categoryDragWatcher = watcher
    end
    self.categoryDragWatcher:Show()

    self:RefreshBags()

    self:ResetCategoryDropVisuals()
end

function SB:GetDropTargetUnderCursor()
    local rawX, rawY = GetCursorPosition()

    for _, target in ipairs(self.dropTargets) do
        if target:IsShown() then
            local scale = target:GetEffectiveScale()
            local cursorX = rawX / scale
            local cursorY = rawY / scale

            local left = target:GetLeft()
            local right = target:GetRight()
            local bottom = target:GetBottom()
            local top = target:GetTop()

            if left and right and bottom and top
                and cursorX >= left and cursorX <= right
                and cursorY >= bottom and cursorY <= top
            then
                return target
            end
        end
    end
    return nil
end

function SB:FinishCategoryDragAtCursor()
    if not self.categoryDragGroup then return end
    local target = self:GetCategoryTitleUnderCursor()
    if target and target.categoryKey then
        self:DropGroupOnCategory(target.categoryKey)
    else
        self:EndCategoryDrag()
        self:RefreshBags()
    end
end

function SB:EndCategoryDrag()
    local hadDrag = self.categoryDragGroup ~= nil
    self.categoryDragGroup = nil
    self.categoryDragHoverTarget = nil
    ClearCursor()
    if self.categoryDragGhost then self.categoryDragGhost:Hide() end
    if self.categoryDragWatcher then self.categoryDragWatcher:Hide() end
    self:ResetCategoryDropVisuals()
    for _, target in ipairs(self.dropTargets) do
        target:SetBackdropColor(0.05, 0.05, 0.06, 0.42)
        target:SetBackdropBorderColor(0.18, 0.18, 0.21, 0.9)
        target.plus:SetTextColor(0.5, 0.5, 0.5, 1)
    end
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
    self:RefreshBags()
    if self.settingsFrame and self.settingsFrame:IsShown() then
        self:RefreshCategorySettings()
    end
end

function SB:GetCategoryFrameUnderCursorForOrder(sourceKey)
    local rawX, rawY=GetCursorPosition()
    for _,frame in ipairs(self.categoryFrames) do
        if frame:IsShown() and frame.categoryKey and frame.categoryKey~=sourceKey then
            local scale=frame:GetEffectiveScale()
            local x,y=rawX/scale,rawY/scale
            local l,r,b,t=frame:GetLeft(),frame:GetRight(),frame:GetBottom(),frame:GetTop()
            if l and r and b and t and x>=l and x<=r and y>=b and y<=t then
                return frame
            end
        end
    end
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
    for _,frame in ipairs(self.categoryFrames) do
        if frame:IsShown() then frame:SetBackdropBorderColor(.14,.14,.17,1) end
    end
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
                    SB:RefreshBags()
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
                SB:RefreshBags()
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
    if self.mainFrame then
        local x,y=self:GetFramePointInUIParent(anchor)
        self.db.layout.growthAnchor=anchor
        if x~=nil and y~=nil then
            self:SetBagAnchorPosition(x,y)
            self:AttachMainFrameToBagAnchor(anchor)
        end
        if self.PersistCurrentProfile then self:PersistCurrentProfile() end
    else
        self.db.layout.growthAnchor=anchor
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
        self:ClearRecentItems()
        self:ResetVisualSlotSession()
        if self.db.splitView and self.db.splitView.enabled then
            if C_Container and C_Container.SortBags then
                C_Container.SortBags()
            end
            return
        end
        local groups = self:ScanBags()
        self.inventorySnapshot = self:BuildInventorySnapshot(groups)
        self:RefreshBags()
    end)
    broomButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        if self.db.splitView and self.db.splitView.enabled then
            GameTooltip:SetText(self:T("SORT_STACKS"))
            GameTooltip:AddLine(self:T("SORT_STACKS_DESC"),1,1,1)
        else
            GameTooltip:SetText(self:T("CLEAR_RECENT"))
            GameTooltip:AddLine(self:T("CLEAR_RECENT_DESC"),1,1,1)
        end
        GameTooltip:Show()
    end)
    broomButton:SetScript("OnLeave", GameTooltip_Hide)
    broomButton:SetShown(self.isMainline ~= false)
    self.broomButton = broomButton

    local headerTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", WINDOW_PADDING, -12)
    headerTitle:SetText("WagBag")
    self.headerTitle = headerTitle

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
        self.searchText = text
        if frame:IsShown() and not InCombatLockdown() then
            self:RefreshBags()
        end
    end

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

    self.searchBox = searchBox

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
    self.bagBarToggleButton = bagButton
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
        self:RefreshBags()
    end)
    modeButton:SetScript("OnEnter",function(button)
        GameTooltip:SetOwner(button,"ANCHOR_BOTTOM")
        GameTooltip:SetText((self.db.splitView and self.db.splitView.enabled) and self:T("SPLIT_STACKS") or self:T("MERGED_STACKS"))
        GameTooltip:AddLine(self:T("STACK_MODE_DESC"),1,1,1)
        GameTooltip:Show()
    end)
    modeButton:SetScript("OnLeave",GameTooltip_Hide)
    self.stackModeButton=modeButton
    UpdateModeVisual()

    closeButton:ClearAllPoints(); closeButton:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-7)
    lockButton:ClearAllPoints(); lockButton:SetPoint("RIGHT",closeButton,"LEFT",-2,0)
    bagButton:ClearAllPoints(); bagButton:SetPoint("RIGHT",lockButton,"LEFT",-3,0)
    modeButton:SetPoint("RIGHT",bagButton,"LEFT",-3,0)
    broomButton:ClearAllPoints(); broomButton:SetPoint("RIGHT",modeButton,"LEFT",-3,0)

    self:UpdateLockVisual()

    frame:Hide()

    frame:SetScript("OnHide", function()
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

function SB:RefreshBags()
    if not self.mainFrame then return end

    self.state.refreshPending = false

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

    local bgAlpha=tonumber(self.db.layout.backgroundAlpha) or 0.97
    local blockAlpha=math.min(1,bgAlpha+0.12)
    local blockBorderAlpha=math.min(1,bgAlpha+0.28)
    for _,frame in ipairs(self.categoryFrames) do
        frame:SetBackdropColor(0.035,0.035,0.043,blockAlpha)
        frame:SetBackdropBorderColor(0.14,0.14,0.17,blockBorderAlpha)
        frame:Hide()
    end
    for _,target in ipairs(self.dropTargets) do target:Hide() end

    local scale=math.max(0.5,math.min(2.0,tonumber(self.db.layout.scale) or 1.0))
    self.mainFrame:SetScale(scale)
    local cellsPerRow=math.max(2,math.min(10,tonumber(self.db.layout.cellsPerRow) or 4))
    local configuredBlocksPerRow=math.max(1,math.min(4,tonumber(self.db.layout.blocksPerRow) or 2))
    local blocksPerRow=configuredBlocksPerRow
    local blockWidth=BLOCK_PADDING*2+cellsPerRow*self.SLOT_SIZE+math.max(0,cellsPerRow-1)*self.SLOT_SPACING
    local maxVisualColumns=math.max(configuredBlocksPerRow,3)
    local columnHeightLimit=(UIParent:GetHeight() or 768)*(2/3)/scale
    local fullWidth=configuredBlocksPerRow*blockWidth+math.max(0,configuredBlocksPerRow-1)*BLOCK_GAP

    local buttonIndex=0
    local categoryFrameIndex=0
    local normalIndex=0
    local normalLayouts={}
    local recentHeight=0
    local placementY={}

    local function PopulateBlock(block,category,columns,allowDrop)
        local displayItems=category.visualItems or category.items
        local itemCount=#displayItems
        local splitDrop=(self.db.splitView and self.db.splitView.enabled)
        local showDropTarget=allowDrop and splitDrop and not self.categoryDragGroup
        local visualCellCount=itemCount+(showDropTarget and 1 or 0)
        local itemRows
        local blockHeight
        if itemCount == 0 and self.categoryDragGroup then
            itemRows = 0
            blockHeight = BLOCK_TITLE_HEIGHT + 2
        else
            itemRows=math.max(1,math.ceil(math.max(1,visualCellCount)/columns))
            blockHeight=BLOCK_TITLE_HEIGHT+BLOCK_PADDING+itemRows*self.SLOT_SIZE+math.max(0,itemRows-1)*self.SLOT_SPACING+BLOCK_PADDING
        end

        for itemIndex,group in ipairs(displayItems) do
            if group then
                buttonIndex=buttonIndex+1
                local button=self.itemButtons[buttonIndex]
                if not button then button=self:CreateItemButton(block); self.itemButtons[buttonIndex]=button else button:SetParent(block) end
                local column=(itemIndex-1)%columns
                local row=math.floor((itemIndex-1)/columns)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT",block,"TOPLEFT",BLOCK_PADDING+column*(self.SLOT_SIZE+self.SLOT_SPACING),-(BLOCK_TITLE_HEIGHT+BLOCK_PADDING+row*(self.SLOT_SIZE+self.SLOT_SPACING)))
                self:BindItemButton(button,group)
                button:Show()
            end
        end

        if showDropTarget then
            local target=AcquireDropTarget(block,categoryFrameIndex)
            target.categoryKey=category.key
            local targetIndex=itemCount+1
            local targetColumn=(targetIndex-1)%columns
            local targetRow=math.floor((targetIndex-1)/columns)
            target:ClearAllPoints()
            target:SetPoint("TOPLEFT",block,"TOPLEFT",BLOCK_PADDING+targetColumn*(self.SLOT_SIZE+self.SLOT_SPACING),-(BLOCK_TITLE_HEIGHT+BLOCK_PADDING+targetRow*(self.SLOT_SIZE+self.SLOT_SPACING)))
        end
        return blockHeight
    end

    for _,category in ipairs(categories) do
        if category.key=="__recent" then
            categoryFrameIndex=categoryFrameIndex+1
            local block=AcquireCategoryFrame(self.mainFrame,categoryFrameIndex)
            block.title:SetText(category.name)
            block.categoryKey=category.key
            block.titleHandle.categoryKey=nil
            local fullColumns=math.max(cellsPerRow,cellsPerRow*blocksPerRow)
            recentHeight=PopulateBlock(block,category,fullColumns,(self.db.splitView and self.db.splitView.enabled))
            block:SetSize(fullWidth,recentHeight)
            block:ClearAllPoints()
            block:SetPoint("TOPLEFT",self.mainFrame,"TOPLEFT",WINDOW_PADDING,-HEADER_HEIGHT)
            break
        end
    end

    for _,category in ipairs(categories) do
        if category.key~="__recent" then
            categoryFrameIndex=categoryFrameIndex+1
            normalIndex=normalIndex+1
            local block=AcquireCategoryFrame(self.mainFrame,categoryFrameIndex)
            block.title:SetText(category.name)
            block.categoryKey=category.key
            block.titleHandle.categoryKey=category.noReorder and nil or category.key
            local h=PopulateBlock(block,category,cellsPerRow,true)
            block:SetSize(blockWidth,h)
            local col=(normalIndex-1)%configuredBlocksPerRow
            local startY=HEADER_HEIGHT+(recentHeight>0 and (recentHeight+BLOCK_GAP) or 0)
            for c=0,maxVisualColumns-1 do
                if placementY[c]==nil then placementY[c]=startY end
            end
            if placementY[col]+h>columnHeightLimit and col+1<maxVisualColumns then
                col=col+1
                while col+1<maxVisualColumns and placementY[col]+h>columnHeightLimit do
                    col=col+1
                end
            end
            normalLayouts[#normalLayouts+1]={frame=block,column=col,height=h}
            placementY[col]=placementY[col]+h+BLOCK_GAP
        end
    end

    local normalStart=HEADER_HEIGHT
    if recentHeight>0 then normalStart=normalStart+recentHeight+BLOCK_GAP end

    local columnY={}
    for col=0,maxVisualColumns-1 do columnY[col]=normalStart end

    for _,layout in ipairs(normalLayouts) do
        local y=columnY[layout.column] or normalStart
        layout.frame:ClearAllPoints()
        layout.frame:SetPoint(
            "TOPLEFT",
            self.mainFrame,
            "TOPLEFT",
            WINDOW_PADDING+layout.column*(blockWidth+BLOCK_GAP),
            -y
        )
        columnY[layout.column]=y+layout.height+BLOCK_GAP
    end

    for i=buttonIndex+1,#self.itemButtons do
        self:ResetItemButton(self.itemButtons[i])
    end

    local normalCount=#normalLayouts
    local highestColumn=0
    for _,layout in ipairs(normalLayouts) do highestColumn=math.max(highestColumn,layout.column) end
    local visibleColumns=math.max(1,highestColumn+1)
    if normalCount==0 and recentHeight>0 then
        visibleColumns=configuredBlocksPerRow
    end
    local contentWidth=WINDOW_PADDING*2+visibleColumns*blockWidth+math.max(0,visibleColumns-1)*BLOCK_GAP
    local infoCounterWidth=145
    local infoMoneyWidth=190
    local infoGap=12
    local minimumInfoWidth=WINDOW_PADDING*2+infoCounterWidth+infoGap+infoMoneyWidth
    local windowWidth=math.max(contentWidth,minimumInfoWidth)
    if recentLayout then
        recentLayout.frame:SetWidth(visibleColumns*blockWidth+math.max(0,visibleColumns-1)*BLOCK_GAP)
    end

    self:RefreshCurrencyBar()
    self._currencyBarInitialized=true
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
    self._lastRenderedBagRevision=self.bagScanRevision or 0
end

function SB:ToggleBags()
    if not self.mainFrame then return end

    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
        return
    end

    self:BeginBagSession()
    self:RefreshBags()
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
