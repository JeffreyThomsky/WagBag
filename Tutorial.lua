local _, SB = ...

local STEP_COUNT = 3
local SCREEN_MARGIN = 10

local function ResolveAnchor(step)
    if step==1 then return SB.tutorialModeAnchor end
    if step==2 then
        for _,category in ipairs(SB.categoryFrames or {}) do
            if category:IsShown() and category.titleHandle and category.titleHandle:IsShown()
                and category.categoryKey~="__recent" then
                return category.titleHandle
            end
        end
    end
    if step==3 then return SB.tutorialBroomAnchor end
    return SB.mainFrame
end

local function StepTitle(step)
    local key=(step==1 and "TUTORIAL_STEP_STACKS") or
        (step==2 and "TUTORIAL_STEP_CATEGORIES") or "TUTORIAL_STEP_BROOM"
    return SB:T(key)
end

 
 
 
local function HighlightTarget(target)
    if not target or not target.IsShown or not target:IsShown() or target==SB.mainFrame then
        if SB.tutorialTargetHighlight then SB.tutorialTargetHighlight:Hide() end
        return
    end
    local mark=SB.tutorialTargetHighlight
    if not mark then
        mark=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        mark:SetFrameStrata("TOOLTIP")
        mark:SetClampedToScreen(true)
        mark:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
        mark:SetBackdropBorderColor(1,.78,.08,1)
        mark:EnableMouse(false)
        SB.tutorialTargetHighlight=mark
    end
    mark:ClearAllPoints()
    mark:SetPoint("TOPLEFT",target,"TOPLEFT",-4,4)
    mark:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",4,-4)
    mark:Show()
end

local function TutorialText(step)
    if step==1 then return SB:T("TUTORIAL_STACKS") end
    if step==2 then return SB:T("TUTORIAL_CATEGORIES") end
    if step==3 then
        return SB:T(SB.isMainline and "TUTORIAL_RECENT_RETAIL" or "TUTORIAL_RECENT_CLASSIC")
    end
end

local function ScreenRect(region)
    if not region or not region.GetLeft then return end
    local left,right,top,bottom=region:GetLeft(),region:GetRight(),region:GetTop(),region:GetBottom()
    if not (left and right and top and bottom) then return end
    local uiScale=(UIParent:GetEffectiveScale() or 1)
    local scale=(region:GetEffectiveScale() or 1)/uiScale
    return left*scale,right*scale,top*scale,bottom*scale
end

function SB:StopTutorial()
    self.tutorialGeneration=(self.tutorialGeneration or 0)+1
    self.tutorialStep=nil
    if self.tutorialTipFrame then self.tutorialTipFrame:Hide() end
    if self.tutorialTargetHighlight then self.tutorialTargetHighlight:Hide() end
end

local function EnsureTutorialFrame()
    if SB.tutorialTipFrame then return SB.tutorialTipFrame end
    local frame=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    frame:SetSize(318,151)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true)
     
     
     
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
    frame:SetBackdropColor(.085,.069,.023,.985)
    frame:SetBackdropBorderColor(1,.77,.07,1)
     
     
    local function AddInnerGlow(pointA,pointB,thickness,horizontal)
        local glow=frame:CreateTexture(nil,"BORDER")
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetVertexColor(1,.75,.12,.24)
        glow:SetPoint(pointA,frame,pointA,(pointA:find("LEFT") and 2 or (pointA:find("RIGHT") and -2 or 0)),(pointA:find("TOP") and -2 or (pointA:find("BOTTOM") and 2 or 0)))
        glow:SetPoint(pointB,frame,pointB,(pointB:find("LEFT") and 2 or (pointB:find("RIGHT") and -2 or 0)),(pointB:find("TOP") and -2 or (pointB:find("BOTTOM") and 2 or 0)))
        if horizontal then glow:SetHeight(thickness) else glow:SetWidth(thickness) end
        return glow
    end
    frame.glowTop=AddInnerGlow("TOPLEFT","TOPRIGHT",3,true)
    frame.glowBottom=AddInnerGlow("BOTTOMLEFT","BOTTOMRIGHT",3,true)
    frame.glowLeft=AddInnerGlow("TOPLEFT","BOTTOMLEFT",3,false)
    frame.glowRight=AddInnerGlow("TOPRIGHT","BOTTOMRIGHT",3,false)
    frame:EnableMouse(true)

     
     
    frame.pointer=frame:CreateTexture(nil,"OVERLAY")
    frame.pointer:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.pointer:SetVertexColor(1,.78,.08,1)
    frame.pointer:SetSize(2,2)
    frame.pointer:Hide()
    frame.pointerBridge=frame:CreateTexture(nil,"OVERLAY")
    frame.pointerBridge:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.pointerBridge:SetVertexColor(1,.78,.08,1)
    frame.pointerBridge:SetSize(2,2)
    frame.pointerBridge:Hide()

    frame.title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    frame.title:SetPoint("TOPLEFT",14,-12)
    frame.title:SetPoint("RIGHT",-37,0)
    frame.title:SetJustifyH("LEFT")
    frame.message=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
     
     
     
    frame.message:SetPoint("TOPLEFT",frame,"TOPLEFT",14,-38)
    frame.message:SetWidth(318-28)
    frame.message:SetJustifyH("LEFT")
    frame.message:SetJustifyV("TOP")
    frame.message:SetWordWrap(true)

    local function CreateAction(width,offset,callback)
        local button=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        button:SetSize(width,23)
        button:SetPoint("BOTTOMRIGHT",offset,10)
        button:SetScript("OnClick",callback)
        return button
    end
    frame.skip=CreateAction(90,-106,function() SB:StopTutorial() end)
    frame.next=CreateAction(90,-12,function() SB:NextTutorialStep() end)
    frame.close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    frame.close:SetSize(24,24)
    frame.close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-3)
    frame.close:SetScript("OnClick",function() SB:StopTutorial() end)
    SB.tutorialTipFrame=frame
    frame:Hide()
    return frame
end

local function PlaceTutorialOnScreen(frame,anchor)
    local uiWidth=UIParent:GetWidth() or 0
    local uiHeight=UIParent:GetHeight() or 0
    local scale=(frame:GetEffectiveScale() or 1)/(UIParent:GetEffectiveScale() or 1)
    local width=(frame:GetWidth() or 318)*scale
    local height=(frame:GetHeight() or 151)*scale
    local left,right,top,bottom=ScreenRect(anchor)
    if not left then left,right,top,bottom=ScreenRect(SB.mainFrame) end
    left=left or uiWidth/2
    right=right or left
    bottom=bottom or uiHeight/2
    top=top or uiHeight/2
    local center=(left+right)/2

     
     
    local x=math.max(SCREEN_MARGIN,math.min(center-width*.79,uiWidth-width-SCREEN_MARGIN))
    local gap=17
    local belowTop=bottom-gap
    local aboveTop=top+gap+height
    local side
    local y
    if belowTop-height>=SCREEN_MARGIN then
        y=belowTop;side="below"
    elseif aboveTop<=uiHeight-SCREEN_MARGIN then
        y=aboveTop;side="above"
    elseif bottom>(uiHeight-top) then
        y=belowTop;side="below"
    else
        y=aboveTop;side="above"
    end
    y=math.max(height+SCREEN_MARGIN,math.min(y,uiHeight-SCREEN_MARGIN))
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)

     
     
    local pointer=frame.pointer
    local bridge=frame.pointerBridge
    if pointer and bridge then
        pointer:Hide()
        bridge:Hide()
        pointer:ClearAllPoints()
        bridge:ClearAllPoints()
        if anchor and anchor~=SB.mainFrame and anchor.IsShown and anchor:IsShown() then
            local px=math.max(3,math.min(center-x,width-3))/scale
            local otherX=(center-x)/scale
            local distance
            local connectorEnd
            if side=="below" and y<=bottom-5 then
                distance=(bottom-y)/scale
                pointer:SetPoint("BOTTOM",frame,"TOPLEFT",px,0)
                connectorEnd="TOP"
            elseif side=="above" and y-height>=top+5 then
                distance=(y-height-top)/scale
                pointer:SetPoint("TOP",frame,"BOTTOMLEFT",px,0)
                connectorEnd="BOTTOM"
            end
            if distance and distance>0 then
                pointer:SetSize(2,distance)
                pointer:Show()
                local horizontalDelta=otherX-px
                if math.abs(horizontalDelta)>2 then
                    bridge:SetSize(math.abs(horizontalDelta)+1,2)
                    if horizontalDelta>0 then
                        bridge:SetPoint("LEFT",pointer,connectorEnd,0,0)
                    else
                        bridge:SetPoint("RIGHT",pointer,connectorEnd,0,0)
                    end
                    bridge:Show()
                end
            end
        end
    end
end

local function FitTutorialToText(frame,anchor,uiHeight,scale)
     
     
    local textHeight=math.max(frame.message:GetStringHeight() or 0,52)
    local preferredHeight=math.max(137,85+textHeight)
    local maxHeight=math.max(1,(uiHeight-2*SCREEN_MARGIN)/scale)
    frame:SetHeight(math.min(preferredHeight,maxHeight))
    PlaceTutorialOnScreen(frame,anchor)
end

local function ShowTutorial(step)
    local frame=EnsureTutorialFrame()
    local uiWidth=UIParent:GetWidth() or 800
    local uiHeight=UIParent:GetHeight() or 600
    local scale=(frame:GetEffectiveScale() or 1)/(UIParent:GetEffectiveScale() or 1)
    local availableWidth=math.max(1,uiWidth-2*SCREEN_MARGIN)
    frame:SetWidth(math.min(318,availableWidth/scale))
     
     
    frame.message:SetWidth(math.max(1,frame:GetWidth()-28))
    frame.title:SetText(string.format("%s (%d/%d)",StepTitle(step),step,STEP_COUNT))
    frame.message:SetText(TutorialText(step))
    frame.skip:SetText(SB:T("TUTORIAL_SKIP"))
    frame.next:SetText(SB:T(step==STEP_COUNT and "TUTORIAL_DONE" or "TUTORIAL_NEXT"))

    local anchor=ResolveAnchor(step) or SB.mainFrame
    local maxHeight=math.max(1,(uiHeight-2*SCREEN_MARGIN)/scale)
     
     
     
    frame:SetHeight(math.min(215,maxHeight))
    frame:SetAlpha(0)
    frame:Show()
    PlaceTutorialOnScreen(frame,anchor)
    local generation=SB.tutorialGeneration
    C_Timer.After(0,function()
         
        if SB.tutorialGeneration~=generation or SB.tutorialStep~=step
            or not frame:IsShown() then return end
        FitTutorialToText(frame,ResolveAnchor(step) or SB.mainFrame,
            UIParent:GetHeight() or uiHeight,
            (frame:GetEffectiveScale() or 1)/(UIParent:GetEffectiveScale() or 1))
        frame:SetAlpha(1)
    end)
end

function SB:ShowTutorialStep()
    if not self.tutorialStep then return end
    if not self.mainFrame or not self.mainFrame:IsShown() then self:StopTutorial(); return end
    local step=self.tutorialStep
    HighlightTarget(ResolveAnchor(step))
    ShowTutorial(step)
end

function SB:NextTutorialStep()
    if not self.tutorialStep then return end
    local nextStep=self.tutorialStep+1
    self:StopTutorial()
    if nextStep<=STEP_COUNT and self.mainFrame and self.mainFrame:IsShown() then
        self.tutorialStep=nextStep
        self:ShowTutorialStep()
    end
end

function SB:StartTutorial(manual)
    if not self.mainFrame then return end
    if manual and WagBagDB then WagBagDB.tutorialSeen=true end
    if not manual then
        if not WagBagDB or WagBagDB.tutorialSeen~=false then return end
         
        WagBagDB.tutorialSeen=true
    end
    if self.settingsFrame and self.settingsFrame:IsShown() then self.settingsFrame:Hide() end
    self:StopTutorial()
    if not self.mainFrame:IsShown() then self:ToggleBags() end
    if not self.mainFrame:IsShown() then return end
    self.tutorialStep=1
    self:ShowTutorialStep()
end

function SB:TutorialOnBagShown()
    if not WagBagDB or WagBagDB.tutorialSeen~=false then return end
    C_Timer.After(0,function()
        if SB.mainFrame and SB.mainFrame:IsShown() and
            WagBagDB and WagBagDB.tutorialSeen==false then
            SB:StartTutorial(false)
        end
    end)
end
