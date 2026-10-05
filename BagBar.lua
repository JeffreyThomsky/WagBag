local _, SB = ...

SB.BagBar = SB.BagBar or {}

local BAG_IDS = SB:GetEquippedBagIDs()
local BUTTON_SIZE = 34
local SPACING = 5
local PADDING = 7

local function GetBagInventorySlot(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(bagID)
    end
    return nil
end

local function UpdateButton(button, bagID)
    button.bagID = bagID

    local inventorySlot = GetBagInventorySlot(bagID)
    local texture = inventorySlot and GetInventoryItemTexture("player", inventorySlot)
    button.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Bag_08")
end

local function CreateBagButton(parent, bagID)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.035, 0.04, 0.98)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.32, 0.32, 0.36, 0.55)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        local inventorySlot = GetBagInventorySlot(selfButton.bagID)
        if inventorySlot then
            GameTooltip:SetInventoryItem("player", inventorySlot)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(selfButton)
        local inventorySlot = GetBagInventorySlot(selfButton.bagID)
        if inventorySlot then
            PickupInventoryItem(inventorySlot)
        end
    end)

    UpdateButton(button, bagID)
    return button
end

function SB:CreateBagBar(parent)
    if self.bagBarFrame then
        return self.bagBarFrame
    end

    local width =
        (PADDING * 2)
        + (#BAG_IDS * BUTTON_SIZE)
        + ((#BAG_IDS - 1) * SPACING)

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, BUTTON_SIZE + (PADDING * 2))
    panel:SetFrameStrata(parent:GetFrameStrata())
    panel:SetFrameLevel(parent:GetFrameLevel() + 20)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.02, 0.02, 0.025, 0.98)
    panel:SetBackdropBorderColor(0.18, 0.18, 0.21, 1)
    panel:Hide()

    panel.buttons = {}

    for index, bagID in ipairs(BAG_IDS) do
        local button = CreateBagButton(panel, bagID)

        if index == 1 then
            button:SetPoint("LEFT", panel, "LEFT", PADDING, 0)
        else
            button:SetPoint("LEFT", panel.buttons[index - 1], "RIGHT", SPACING, 0)
        end

        panel.buttons[index] = button
    end

    self.bagBarFrame = panel
    return panel
end

function SB:RefreshBagBar()
    if not self.bagBarFrame then
        return
    end

    for index, bagID in ipairs(BAG_IDS) do
        UpdateButton(self.bagBarFrame.buttons[index], bagID)
    end
end

function SB:ToggleBagBar()
    if not self.bagBarFrame then
        return
    end

    self:RefreshBagBar()
    self.bagBarFrame:SetShown(not self.bagBarFrame:IsShown())
end

function SB:HideBagBar()
    if self.bagBarFrame then
        self.bagBarFrame:Hide()
    end
end
