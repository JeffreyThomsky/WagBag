local _, SB = ...

local NON_STACKABLE_EQUIP_LOCS = {
    INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true,
    INVTYPE_BODY = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
    INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true, INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true, INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

 
 
 
local STATIC_ITEM_CACHE_LIMIT = 512
function SB:GetStaticItemInfo(itemID)
    local cache=self._staticItemInfoCache
    if not cache then cache={}; self._staticItemInfoCache=cache end
    local entry=cache[itemID]
    if entry then
        return entry
    end
    local _,_,_,equipLoc,_,classID,subClassID=C_Item.GetItemInfoInstant(itemID)
    entry={equipLoc=equipLoc,classID=classID,subClassID=subClassID,
        nonStackable=NON_STACKABLE_EQUIP_LOCS[equipLoc]==true,
        stackKey="item:"..itemID}
     
     
    if equipLoc~=nil and classID~=nil then
        if (self._staticItemInfoCount or 0)>=STATIC_ITEM_CACHE_LIMIT then
            cache={}; self._staticItemInfoCache=cache
            self._staticItemInfoCount=0
        end
        cache[itemID]=entry
        self._staticItemInfoCount=(self._staticItemInfoCount or 0)+1
    end
    return entry
end

function SB:InvalidateStaticItemInfo(itemID)
    local cache=self._staticItemInfoCache
    if not cache or not itemID or not cache[itemID] then return end
    cache[itemID]=nil
    self._staticItemInfoCount=math.max(0,(self._staticItemInfoCount or 1)-1)
end

function SB:IsNonStackableEquipment(itemID)
    return self:GetStaticItemInfo(itemID).nonStackable
end

function SB:GetGroupKey(itemID, bagID, slotID)
    local static=self:GetStaticItemInfo(itemID)
    if (self.db and self.db.splitView and self.db.splitView.enabled)
        or static.nonStackable then
        return "slot:" .. bagID .. ":" .. slotID
    end
    return static.stackKey
end

function SB:FindFirstEmptyCharacterSlot()
    for bagID=0,4 do
        local numSlots=C_Container.GetContainerNumSlots(bagID)
        for slotID=1,numSlots do
            if not C_Container.GetContainerItemInfo(bagID,slotID) then
                return bagID,slotID
            end
        end
    end
    return nil
end

function SB:DropCursorItemIntoBags()
    if not CursorHasItem() then return false end
    local bagID,slotID=self:FindFirstEmptyCharacterSlot()
    if not bagID then
        self:Print(self:T("NO_FREE_BAG_SLOT"))
        return false
    end
    C_Container.PickupContainerItem(bagID,slotID)
    return true
end

function SB:ScanBags()
    local groups = {}
    local totalSlots, usedSlots, totalItems = 0, 0, 0
    local normalTotal, normalUsed, reagentTotal, reagentUsed = 0, 0, 0, 0

    local bagIDs = self:GetCharacterBagIDs()
    local reagentBag = self.reagentBagID

    for _, bagID in ipairs(bagIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        totalSlots = totalSlots + numSlots
        local isReagentBag = (bagID == reagentBag)
        if isReagentBag then reagentTotal = reagentTotal + numSlots
        else normalTotal = normalTotal + numSlots end

        for slotID = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slotID)

            if info then
                usedSlots = usedSlots + 1
                if isReagentBag then reagentUsed = reagentUsed + 1
                else normalUsed = normalUsed + 1 end
                local itemID = info.itemID
                local stackCount = info.stackCount or 1
                totalItems = totalItems + stackCount

                if itemID then
                    local groupKey = self:GetGroupKey(itemID, bagID, slotID)

                    if not groups[groupKey] then
                        local static=self:GetStaticItemInfo(itemID)
                        local itemEquipLoc,classID,subClassID=static.equipLoc,static.classID,static.subClassID

                        local itemName = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
                        if not itemName then
                            itemName = C_Item.GetItemInfo(itemID)
                        end

                        groups[groupKey] = {
                            key = groupKey,
                            itemID = itemID,
                            itemName = itemName,
                            count = 0,
                            physicalSlots = 0,
                            itemLink = info.hyperlink,
                            iconFileID = info.iconFileID,
                            quality = info.quality,
                            itemEquipLoc = itemEquipLoc,
                            classID = classID,
                            subClassID = subClassID,
                            nonStackableEquipment = static.nonStackable,
                            slots = {},
                        }
                    end

                    local group = groups[groupKey]
                    group.count = group.count + stackCount
                    group.physicalSlots = group.physicalSlots + 1

                    local slots=group.slots
                    slots[#slots+1] = {
                        bagID = bagID,
                        slotID = slotID,
                        stackCount = stackCount,
                    }

                    if not group.itemLink and info.hyperlink then
                        group.itemLink = info.hyperlink
                    end
                    if not group.iconFileID and info.iconFileID then
                        group.iconFileID = info.iconFileID
                    end
                    if group.quality == nil and info.quality ~= nil then
                        group.quality = info.quality
                    end
                end
            end
        end
    end

    return groups, totalSlots, usedSlots, totalItems, normalTotal, normalUsed, reagentTotal, reagentUsed
end

function SB:GetFirstValidSlot(group)
    if not group or not group.slots then
        return nil
    end

    for _, slot in ipairs(group.slots) do
        local info = C_Container.GetContainerItemInfo(slot.bagID, slot.slotID)
        if info and info.itemID == group.itemID then
            return slot
        end
    end
end

function SB:GetGroupCurrentItemLevel(group)
    if not group then return nil end

    local slot = self:GetFirstValidSlot(group)
    if slot and ItemLocation and ItemLocation.CreateFromBagAndSlot
        and C_Item and C_Item.GetCurrentItemLevel then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(slot.bagID, slot.slotID)
        if itemLocation and itemLocation:IsValid() then
            local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
            if itemLevel and itemLevel > 0 then
                return itemLevel
            end
        end
    end

    if group.itemLink and C_Item and C_Item.GetDetailedItemLevelInfo then
        local itemLevel = C_Item.GetDetailedItemLevelInfo(group.itemLink)
        if itemLevel and itemLevel > 0 then
            return itemLevel
        end
    end

    return nil
end

function SB:BuildInventorySnapshot(groups)
    local snapshot = {}
    groups = groups or self:ScanBags()
    for key, group in pairs(groups) do
        snapshot[key] = {
            itemID = group.itemID,
            count = group.count or 0,
        }
    end
    return snapshot
end

function SB:StoreBagScanCache(groups,totalSlots,usedSlots,totalItems,normalTotal,normalUsed,reagentTotal,reagentUsed)
    self.bagScanCache = {
        groups=groups, totalSlots=totalSlots, usedSlots=usedSlots, totalItems=totalItems,
        normalTotal=normalTotal, normalUsed=normalUsed, reagentTotal=reagentTotal, reagentUsed=reagentUsed,
    }
    return self.bagScanCache
end

function SB:ScanAndCacheBags()
    local groups,totalSlots,usedSlots,totalItems,normalTotal,normalUsed,reagentTotal,reagentUsed=self:ScanBags()
    return self:StoreBagScanCache(groups,totalSlots,usedSlots,totalItems,normalTotal,normalUsed,reagentTotal,reagentUsed)
end

function SB:GetRecentTimerMinutes()
    return math.max(0, math.min(60, tonumber(self.db and self.db.items and self.db.items.recentTimerMinutes) or 0))
end

function SB:GetTimedRecentStore()
    if type(WagBagDB) ~= "table" then return nil end
    WagBagDB.recentItems = WagBagDB.recentItems or {}
    local charKey = self:GetCharacterProfileKey()
    WagBagDB.recentItems[charKey] = WagBagDB.recentItems[charKey] or {}
    return WagBagDB.recentItems[charKey]
end

function SB:ClearRecentItems()
    self.recentGroupKeys = {}
    self.pendingRecentGroupKeys = {}
    local store = self:GetTimedRecentStore()
    if store then wipe(store) end
    self._recentTimerToken = (self._recentTimerToken or 0) + 1
end

function SB:RefreshTimedRecent(groups)
    local minutes = self:GetRecentTimerMinutes()
    if minutes <= 0 then return end
    local store = self:GetTimedRecentStore()
    local now = GetServerTime()
    local active = {}
    local nearest
    for key, expiresAt in pairs(store or {}) do
        if type(expiresAt) ~= "number" or expiresAt <= now or (groups and not groups[key]) then
            store[key] = nil
        else
            active[key] = true
            if not nearest or expiresAt < nearest then nearest = expiresAt end
        end
    end
    self.recentGroupKeys = active
    self.pendingRecentGroupKeys = {}
    self._recentTimerToken = (self._recentTimerToken or 0) + 1
    local token = self._recentTimerToken
    if nearest and self.mainFrame and self.mainFrame:IsShown() and C_Timer and C_Timer.After then
        C_Timer.After(math.max(0.1, nearest - now + 0.1), function()
            if token ~= self._recentTimerToken then return end
            if not self.mainFrame or not self.mainFrame:IsShown() then return end
            local cache = self:ScanAndCacheBags()
            self:RefreshTimedRecent(cache.groups)
            self:ResetVisualSlotSession()
            self:RefreshBags("Inventory.lua:261")
        end)
    end
end

function SB:InitializeRecentTracking()
    local cache = self:ScanAndCacheBags()
    local groups = cache.groups
    self.inventorySnapshot = self:BuildInventorySnapshot(groups)
    self.pendingRecentGroupKeys = {}
    self.recentGroupKeys = nil
    if self:GetRecentTimerMinutes() > 0 then
        self:RefreshTimedRecent(groups)
    end
end

 
 
function SB:BuildInventoryItemTotals(snapshot)
    local totals = {}
    for _, entry in pairs(snapshot or {}) do
        if entry.itemID then
            totals[entry.itemID] = (totals[entry.itemID] or 0) + (entry.count or 0)
        end
    end
    return totals
end

 
 
 
function SB:BeginInventorySortTracking()
    local snapshot = self.inventorySnapshot or self:BuildInventorySnapshot(self:ScanBags())
    self.inventorySortTracking = { baseline = snapshot, generation = 0 }
    self:ScheduleInventorySortSettle()
end

function SB:ScheduleInventorySortSettle()
    local tracking = self.inventorySortTracking
    if not tracking then return end
    tracking.generation = tracking.generation + 1
    local generation = tracking.generation

    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(0.75, function()
        if self.inventorySortTracking ~= tracking or tracking.generation ~= generation then return end
        self.inventorySortTracking = nil
        self:TrackInventoryChanges(tracking.baseline)
         
         
        self:ResetVisualSlotSession()
        if self.mainFrame and self.mainFrame:IsShown() then
            self:RefreshBags("Inventory.lua:310")
        end
    end)
end

function SB:TrackInventoryChanges(baseline)
    local cache = self:ScanAndCacheBags()
    local groups = cache.groups

    if self.inventorySortTracking and not baseline then
        self:ScheduleInventorySortSettle()
        return
    end

     
     
     
    if CursorHasItem and CursorHasItem() then return end

    local old = baseline or self.inventorySnapshot or {}
    local oldTotals = self:BuildInventoryItemTotals(old)
    local currentTotals = self:BuildInventoryItemTotals(groups)
    local gained = {}
    for itemID, count in pairs(currentTotals) do
        local increase = count - (oldTotals[itemID] or 0)
        if increase > 0 then gained[itemID] = increase end
    end

    local minutes = self:GetRecentTimerMinutes()
    local target
    if minutes > 0 then
        target = self:GetTimedRecentStore()
    elseif self.mainFrame and self.mainFrame:IsShown() then
        self.recentGroupKeys = self.recentGroupKeys or {}
        target = self.recentGroupKeys
    else
        self.pendingRecentGroupKeys = self.pendingRecentGroupKeys or {}
        target = self.pendingRecentGroupKeys
    end

     
     
     
    local candidates = {}
    for key, group in pairs(groups) do
        local previous = old[key]
        local sameItem = previous and previous.itemID == group.itemID
        local added = (group.count or 0) - (sameItem and (previous.count or 0) or 0)
        if gained[group.itemID] and added > 0 then
            candidates[#candidates + 1] = {
                key = key, itemID = group.itemID, added = added,
                newSlot = not sameItem,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.newSlot ~= b.newSlot then return a.newSlot end
        return a.key < b.key
    end)

    local expiresAt = minutes > 0 and (GetServerTime() + minutes * 60) or nil
    for _, candidate in ipairs(candidates) do
        local remaining = gained[candidate.itemID] or 0
        if remaining > 0 then
            if target then target[candidate.key] = expiresAt or true end
            gained[candidate.itemID] = math.max(0, remaining - candidate.added)
        end
    end

    self.inventorySnapshot = self:BuildInventorySnapshot(groups)
    if minutes > 0 then self:RefreshTimedRecent(groups) end
end

function SB:ResetVisualSlotSession()
    self.visualSlotSession = {}
end

function SB:ApplyVisualSlotSession(categories)
     
     
     
    if self.inventorySortTracking then
        for _, category in ipairs(categories) do
            category.visualItems = category.items
        end
        return
    end
    self.visualSlotSession = self.visualSlotSession or {}

    for _, category in ipairs(categories) do
        local current = {}
        for _, group in ipairs(category.items or {}) do current[group.key] = group end

        local previous = self.visualSlotSession[category.key]
        local visual, seen = {}, {}

        if previous then
            for _, key in ipairs(previous) do
                if key == false then
                    table.insert(visual, false)
                elseif current[key] then
                    table.insert(visual, current[key])
                    seen[key] = true
                else
                    table.insert(visual, false)
                end
            end
        end

        for _, group in ipairs(category.items or {}) do
            if not seen[group.key] then table.insert(visual, group) end
        end

        category.visualItems = visual

        local keys = {}
        for _, value in ipairs(visual) do
            table.insert(keys, value and value.key or false)
        end
        self.visualSlotSession[category.key] = keys
    end
end

function SB:BeginBagSession()
    self:ResetVisualSlotSession()
    if self:GetRecentTimerMinutes() > 0 then
        local cache = self.bagScanCache or self:ScanAndCacheBags()
        self:RefreshTimedRecent(cache.groups)
        return
    end
    self.recentGroupKeys = {}
    for key in pairs(self.pendingRecentGroupKeys or {}) do
        self.recentGroupKeys[key] = true
    end
    self.pendingRecentGroupKeys = {}
end
