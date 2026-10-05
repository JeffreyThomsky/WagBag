local _, SB = ...

local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE
local WOW_PROJECT_MISTS_CLASSIC = _G.WOW_PROJECT_MISTS_CLASSIC

SB.isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
SB.isClassic = not SB.isMainline
SB.classicFlavor = (WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC) and "Mists" or nil

SB.hasReagentBag = SB.isMainline
SB.reagentBagID = SB.hasReagentBag and ((Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5) or nil

function SB:GetCharacterBagIDs()
    local ids = {0, 1, 2, 3, 4}
    if self.reagentBagID then ids[#ids + 1] = self.reagentBagID end
    return ids
end

function SB:GetEquippedBagIDs()
    local ids = {1, 2, 3, 4}
    if self.reagentBagID then ids[#ids + 1] = self.reagentBagID end
    return ids
end
