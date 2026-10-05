local _, SB = ...

SB.SLOT_SIZE = 40
SB.SLOT_SPACING = 5

local function CreateBorder(button)
    local border = {}

    border.top = button:CreateTexture(nil, "OVERLAY", nil, 7)
    border.top:SetPoint("TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", 0, 0)
    border.top:SetHeight(2)

    border.bottom = button:CreateTexture(nil, "OVERLAY", nil, 7)
    border.bottom:SetPoint("BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(2)

    border.left = button:CreateTexture(nil, "OVERLAY", nil, 7)
    border.left:SetPoint("TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", 0, 0)
    border.left:SetWidth(2)

    border.right = button:CreateTexture(nil, "OVERLAY", nil, 7)
    border.right:SetPoint("TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(2)

    button.qualityBorder = border
end

local function SetBorderColor(button, r, g, b, a)
    for _, texture in pairs(button.qualityBorder) do
        texture:SetColorTexture(r, g, b, a or 1)
    end
end

local function CreateSlotBorder(button)
    local border = {}
    local thickness = 2
    local inset = 1

    local function PrepareTexture(tex)
        tex:SetColorTexture(0.24, 0.24, 0.28, 0.52)
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    end

    local function Horizontal(point, y)
        local tex = button:CreateTexture(nil, "OVERLAY", nil, 3)
        PrepareTexture(tex)
        tex:SetPoint(point .. "LEFT", button, point .. "LEFT", inset, y)
        tex:SetPoint(point .. "RIGHT", button, point .. "RIGHT", -inset, y)
        tex:SetHeight(thickness)
        return tex
    end

    local function Vertical(side, x)
        local tex = button:CreateTexture(nil, "OVERLAY", nil, 3)
        PrepareTexture(tex)
        tex:SetPoint("TOP" .. side, button, "TOP" .. side, x, -inset)
        tex:SetPoint("BOTTOM" .. side, button, "BOTTOM" .. side, x, inset)
        tex:SetWidth(thickness)
        return tex
    end

    border.top = Horizontal("TOP", -inset)
    border.bottom = Horizontal("BOTTOM", inset)
    border.left = Vertical("LEFT", inset)
    border.right = Vertical("RIGHT", -inset)
    button.slotBorder = border
end

local function HideBlizzardNewItemGlow(button)
    if button.NewItemTexture then
        button.NewItemTexture:Hide()
    end

    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:Hide()
    end

    if button.flashAnim and button.flashAnim:IsPlaying() then
        button.flashAnim:Stop()
    end

    if button.newitemglowAnim and button.newitemglowAnim:IsPlaying() then
        button.newitemglowAnim:Stop()
    end
end

function SB:CreateItemButton(parent)
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(self.SLOT_SIZE, self.SLOT_SIZE)

    local button = CreateFrame(
        "ItemButton",
        nil,
        wrapper,
        "ContainerFrameItemButtonTemplate"
    )

    button:SetAllPoints(wrapper)
    button:Show()

    button:SetAlpha(1)

    HideBlizzardNewItemGlow(button)

    local nativeIcon = button.icon or button.Icon
    if nativeIcon and nativeIcon.SetAlpha then nativeIcon:SetAlpha(0) end
    if button.Count and button.Count.SetAlpha then button.Count:SetAlpha(0) end
    if button.IconBorder and button.IconBorder.SetAlpha then button.IconBorder:SetAlpha(0) end
    if button.JunkIcon and button.JunkIcon.SetAlpha then button.JunkIcon:SetAlpha(0) end

    local highlightTexture = button:GetHighlightTexture()
    if highlightTexture then highlightTexture:SetAlpha(0) end

    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetAlpha(0)
    end

    local pushedTexture = button:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetAlpha(0)
    end

    local background = wrapper:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.95)
    wrapper.background = background

    local icon = wrapper:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    wrapper.icon = icon

    CreateSlotBorder(wrapper)
    CreateBorder(wrapper)

    local hover = wrapper:CreateTexture(nil, "OVERLAY", nil, 6)
    hover:SetPoint("TOPLEFT", 2, -2)
    hover:SetPoint("BOTTOMRIGHT", -2, 2)
    hover:SetColorTexture(1, 1, 1, 0.18)
    hover:Hide()
    wrapper.hoverHighlight = hover

    local dropHighlight = wrapper:CreateTexture(nil, "OVERLAY", nil, 6)
    dropHighlight:SetPoint("TOPLEFT", 2, -2)
    dropHighlight:SetPoint("BOTTOMRIGHT", -2, 2)
    dropHighlight:SetColorTexture(1, 1, 1, 0.24)
    dropHighlight:Hide()
    wrapper.dropHighlight = dropHighlight

    button:HookScript("OnEnter", function()
        if CursorHasItem and CursorHasItem() then
            wrapper.hoverHighlight:Hide()
            wrapper.dropHighlight:Show()
        elseif wrapper.group then
            wrapper.dropHighlight:Hide()
            wrapper.hoverHighlight:Show()
        end
    end)
    button:HookScript("OnLeave", function()
        wrapper.hoverHighlight:Hide()
        wrapper.dropHighlight:Hide()
    end)

    local count = wrapper:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -3, 3)
    count:SetJustifyH("RIGHT")
    wrapper.countText = count

    local itemLevel = wrapper:CreateFontString(nil, "OVERLAY")
    itemLevel:SetPoint("BOTTOMLEFT", 3, 3)
    itemLevel:SetJustifyH("LEFT")
    itemLevel:SetTextColor(1, 1, 1, 1)
    itemLevel:SetShadowOffset(1, -1)
    itemLevel:SetShadowColor(0, 0, 0, 1)
    wrapper.itemLevelText = itemLevel

    local junkCoin = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
    junkCoin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    junkCoin:SetSize(13,13)
    junkCoin:SetPoint("TOPLEFT",2,-2)
    junkCoin:Hide()
    wrapper.junkCoin = junkCoin

    local cooldownText = wrapper:CreateFontString(nil, "OVERLAY")
    cooldownText:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
    cooldownText:SetWidth(SB.SLOT_SIZE + 8)
    cooldownText:SetHeight(SB.SLOT_SIZE)
    cooldownText:SetJustifyH("CENTER")
    cooldownText:SetJustifyV("MIDDLE")
    cooldownText:SetTextColor(1, 0.82, 0.05, 1)
    cooldownText:SetShadowOffset(1, -1)
    cooldownText:SetShadowColor(0, 0, 0, 1)
    cooldownText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    cooldownText:Hide()
    wrapper.cooldownText = cooldownText
    wrapper.cooldownEnd = nil

    wrapper.nativeButton = button

    button:HookScript("OnDragStart", function()
        if IsShiftKeyDown() and wrapper.group and SB.BeginCategoryDrag then
            ClearCursor()
            SB:BeginCategoryDrag(wrapper.group)
        end
    end)

    button:HookScript("OnClick", function(_, mouseButton)
        if mouseButton ~= "LeftButton" or not IsShiftKeyDown() then return end
        local edit = SB.GetActiveCategoryItemIDEditBox and SB:GetActiveCategoryItemIDEditBox()
        local group = wrapper.group
        if not edit or not group or not group.itemID then return end

        edit:SetText(tostring(group.itemID))
        edit:SetCursorPosition(#tostring(group.itemID))
        edit:SetFocus()
        edit:HighlightText(0, 0)
    end)

    return wrapper
end

function SB:UpdateQualityBorder(wrapper, group)
    if not self.db.items.showQualityBorder then
        SetBorderColor(wrapper, 0.18, 0.18, 0.18, 1)
        return
    end

    local quality = group.quality
    if quality == nil and group.itemLink then
        local _, _, q = C_Item.GetItemInfo(group.itemLink)
        quality = q
    end

    if quality == 0 or quality == 1 then
        SetBorderColor(wrapper, 0, 0, 0, 0)
    else
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then
            SetBorderColor(wrapper, color.r, color.g, color.b, 1)
        else
            SetBorderColor(wrapper, 0.18, 0.18, 0.18, 1)
        end
    end
end

function SB:UpdateItemLevel(wrapper, group)
    local config = self.db.items.itemLevel
    wrapper.itemLevelText:SetFont(
        "Fonts\\FRIZQT__.TTF",
        tonumber(config.fontSize) or 12,
        "OUTLINE"
    )

    if not config.enabled or not group.nonStackableEquipment then
        wrapper.itemLevelText:SetText("")
        return
    end

    local itemLevel = self:GetGroupCurrentItemLevel(group)

    if not itemLevel or itemLevel <= 0 then
        wrapper.itemLevelText:SetText("")
        return
    end

    wrapper.itemLevelText:SetText(itemLevel)
end

local function WagBag_HasCIMI()
    return type(CIMI_AddToFrame) == "function"
        and type(CIMI_SetIcon) == "function"
        and type(CanIMogIt) == "table"
        and type(CanIMogIt.GetTooltipText) == "function"
end

local function WagBag_GetCIMIWrapper(cimiFrame)
    if not cimiFrame then return nil end
    local parent = cimiFrame:GetParent()
    if not parent then return nil end
    return parent.wagBagWrapper or parent
end

local function WagBag_CIMIUpdateIcon(cimiFrame)
    if not cimiFrame then return end

    if type(CIMI_CheckOverlayIconEnabled) == "function"
        and not CIMI_CheckOverlayIconEnabled()
    then
        if cimiFrame.CIMIIconTexture then
            cimiFrame.CIMIIconTexture:SetShown(false)
        end
        cimiFrame:SetScript("OnUpdate", nil)
        return
    end

    local wrapper = WagBag_GetCIMIWrapper(cimiFrame)
    if not wrapper then return end

    local bagID = wrapper.wagBagID
    local slotID = wrapper.wagSlotID
    if bagID == nil or slotID == nil then
        if cimiFrame.CIMIIconTexture then
            cimiFrame.CIMIIconTexture:SetShown(false)
        end
        return
    end

    C_Timer.After(0, function()
        if not cimiFrame or not cimiFrame:GetParent() then return end
        local currentWrapper = WagBag_GetCIMIWrapper(cimiFrame)
        if not currentWrapper then return end
        local currentBagID = currentWrapper.wagBagID
        local currentSlotID = currentWrapper.wagSlotID
        if currentBagID == nil or currentSlotID == nil then return end

        local itemLink = C_Container.GetContainerItemLink(currentBagID, currentSlotID)
        if not itemLink then
            if cimiFrame.CIMIIconTexture then
                cimiFrame.CIMIIconTexture:SetShown(false)
            end
            return
        end

        if CanIMogIt
            and type(CanIMogIt.GetTooltipText) == "function"
            and type(CIMI_SetIcon) == "function"
        then
            local okText, tooltipText, unmodifiedText = pcall(CanIMogIt.GetTooltipText, CanIMogIt, nil, currentBagID, currentSlotID)
            if okText then
                pcall(CIMI_SetIcon, cimiFrame, WagBag_CIMIUpdateIcon, tooltipText, unmodifiedText)
            end
        end
    end)
end

function SB:EnsureCanIMogItOverlay(wrapper)
    if not WagBag_HasCIMI() then return nil end
    if not wrapper.nativeButton then return nil end

    local button = wrapper.nativeButton
    button.wagBagWrapper = wrapper

    if not button.CanIMogItOverlay then
        self.cimiOverlayCounter = (self.cimiOverlayCounter or 0) + 1
        local ok = pcall(
            CIMI_AddToFrame,
            button,
            WagBag_CIMIUpdateIcon,
            "WagBag." .. self.cimiOverlayCounter
        )
        if not ok then return nil end
    end

    local overlay = button.CanIMogItOverlay
    if overlay then
        overlay:SetFrameLevel(button:GetFrameLevel() + 10)
        overlay:SetAlpha(1)
        overlay:Show()
        if overlay.CIMIIconTexture then
            overlay.CIMIIconTexture:SetDrawLayer("OVERLAY", 7)
            overlay.CIMIIconTexture:SetAlpha(1)
        end
    end
    wrapper.CanIMogItOverlay = overlay
    return overlay
end

function SB:UpdateCanIMogIt(wrapper, group)
    local slot = self:GetFirstValidSlot(group)
    wrapper.wagBagID = slot and slot.bagID or nil
    wrapper.wagSlotID = slot and slot.slotID or nil
    if wrapper.nativeButton then
        wrapper.nativeButton.wagBagWrapper = wrapper
    end

    if not WagBag_HasCIMI() then
        local old = wrapper.CanIMogItOverlay or (wrapper.nativeButton and wrapper.nativeButton.CanIMogItOverlay)
        if old then old:Hide() end
        if old and old.CIMIIconTexture then old.CIMIIconTexture:SetShown(false) end
        return
    end

    local overlay = self:EnsureCanIMogItOverlay(wrapper)
    if overlay then
        overlay:Show()
        WagBag_CIMIUpdateIcon(overlay)
    end
end

local function FormatCooldownSeconds(seconds)
    if seconds <= 0 then return "" end
    if seconds >= 60 then
        return tostring(math.max(1, math.ceil(seconds / 60))) .. "m"
    end
    return tostring(math.max(1, math.ceil(seconds))) .. "s"
end

function SB:UpdateItemCooldown(wrapper, group)
    if not wrapper.cooldownText then return end
    local slot=self:GetFirstValidSlot(group)
    if not slot then
        wrapper.cooldownText:Hide()
        wrapper.cooldownEnd=nil
        wrapper:SetScript("OnUpdate",nil)
        return
    end

    local startTime,duration,enabled=C_Container.GetContainerItemCooldown(slot.bagID,slot.slotID)
    startTime=tonumber(startTime) or 0
    duration=tonumber(duration) or 0

    if enabled==0 or startTime<=0 or duration<=1.5 then
        wrapper.cooldownText:Hide()
        wrapper.cooldownEnd=nil
        wrapper:SetScript("OnUpdate",nil)
        return
    end

    wrapper.cooldownEnd=startTime+duration
    wrapper.cooldownText:Show()

    local function Tick(self)
        local remaining=(self.cooldownEnd or 0)-GetTime()
        if remaining<=0 then
            self.cooldownText:Hide()
            self.cooldownEnd=nil
            self:SetScript("OnUpdate",nil)
            return
        end

        local text
        if remaining >= 60 then
            text=tostring(math.ceil(remaining/60)).."m"
        else
            text=tostring(math.max(1,math.ceil(remaining))).."s"
        end

        local chars=#text
        local size=17
        if chars==4 then size=15
        elseif chars>=5 then size=13 end
        self.cooldownText:SetFont("Fonts\\FRIZQT__.TTF",size,"OUTLINE")
        self.cooldownText:SetText(text)
    end

    Tick(wrapper)
    wrapper.cooldownElapsed=0
    wrapper:SetScript("OnUpdate",function(self,elapsed)
        self.cooldownElapsed=(self.cooldownElapsed or 0)+elapsed
        if self.cooldownElapsed < .20 then return end
        self.cooldownElapsed=0
        Tick(self)
    end)
end

function SB:CreateBankItemButton(parent)
    local wrapper = self:CreateItemButton(parent)
    wrapper.isPhysicalBankButton = true
    return wrapper
end

local function NormalizeNativeHitLayer(button)
    if not button then return end
    button:SetAlpha(1)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local regions = { button:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end
    HideBlizzardNewItemGlow(button)
end

function SB:NormalizeNativeItemButton(wrapper)
    if wrapper and wrapper.nativeButton then
        NormalizeNativeHitLayer(wrapper.nativeButton)
    end
end

function SB:BindItemButton(wrapper, group)
    wrapper.group = group

    local slot = self:GetFirstValidSlot(group)
    if not slot then
        wrapper._wagBindSig=nil
        wrapper:Hide()
        return
    end

    wrapper._wagBindSig=nil
    wrapper:SetID(slot.bagID)
    wrapper.nativeButton:SetID(slot.slotID)

    NormalizeNativeHitLayer(wrapper.nativeButton)

    wrapper.icon:SetTexture(
        group.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark"
    )
    local quality=group.quality
    if quality==nil and group.itemLink then
        local _,_,q=C_Item.GetItemInfo(group.itemLink)
        quality=q
    end
    wrapper.icon:SetDesaturated(quality==0)
    if wrapper.junkCoin then wrapper.junkCoin:SetShown(quality==0) end

    wrapper.countText:SetFont(
        "Fonts\\FRIZQT__.TTF",
        tonumber(self.db.items.stackCount.fontSize) or 12,
        "OUTLINE"
    )

    if group.count > 1 and not group.nonStackableEquipment then
        wrapper.countText:SetText(group.count)
    else
        wrapper.countText:SetText("")
    end

    self:UpdateQualityBorder(wrapper, group)
    self:UpdateItemLevel(wrapper, group)
    self:UpdateCanIMogIt(wrapper, group)
    self:UpdateItemCooldown(wrapper, group)

    local searching = strtrim(self.searchText or "") ~= ""
    local matches = (not searching) or self:GroupMatchesSearch(group, self.searchText)
    wrapper:SetAlpha(matches and 1 or 0.22)

end

function SB:ResetItemButton(wrapper)
    wrapper:SetAlpha(1)
    if wrapper.hoverHighlight then wrapper.hoverHighlight:Hide() end
    wrapper:Hide()
    wrapper.group = nil
    wrapper.countText:SetText("")
    wrapper.itemLevelText:SetText("")
    if wrapper.junkCoin then wrapper.junkCoin:Hide() end
    if wrapper.cooldownText then wrapper.cooldownText:Hide() end
    wrapper.cooldownEnd=nil
    wrapper:SetScript("OnUpdate",nil)

    local overlay = wrapper.CanIMogItOverlay
        or (wrapper.nativeButton and wrapper.nativeButton.CanIMogItOverlay)

    if overlay then
        overlay:Hide()
    end
end
