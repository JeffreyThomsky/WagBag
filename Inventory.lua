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

function SB:IsNonStackableEquipment(itemID)
    local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(itemID)
    return NON_STACKABLE_EQUIP_LOCS[itemEquipLoc] == true
end

function SB:GetGroupKey(itemID, bagID, slotID)
    if (self.db and self.db.splitView and self.db.splitView.enabled)
        or self:IsNonStackableEquipment(itemID)
    then
        return "slot:" .. bagID .. ":" .. slotID
    end
    return "item:" .. itemID
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
                        local _, _, _, itemEquipLoc, _, classID, subClassID =
                            C_Item.GetItemInfoInstant(itemID)

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
                            nonStackableEquipment = self:IsNonStackableEquipment(itemID),
                            slots = {},
                        }
                    end

                    local group = groups[groupKey]
                    group.count = group.count + stackCount
                    group.physicalSlots = group.physicalSlots + 1

                    table.insert(group.slots, {
                        bagID = bagID,
                        slotID = slotID,
                        stackCount = stackCount,
                    })

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

function SB:PrintScan()
    local groups, totalSlots, usedSlots, totalItems = self:ScanBags()
    local groupCount = 0
    for _ in pairs(groups) do groupCount = groupCount + 1 end

    self:Print("Scan complete.")
    self:Print("Slots: " .. usedSlots .. "/" .. totalSlots
        .. " | Items: " .. totalItems
        .. " | Virtual groups: " .. groupCount)
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
            self:RefreshBags()
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

function SB:TrackInventoryChanges()
    local cache = self:ScanAndCacheBags()
    local groups = cache.groups
    local old = self.inventorySnapshot or {}
    local minutes = self:GetRecentTimerMinutes()
    local target
    local store

    if minutes > 0 then
        store = self:GetTimedRecentStore()
        target = store
    elseif self.mainFrame and self.mainFrame:IsShown() then
        self.recentGroupKeys = self.recentGroupKeys or {}
        target = self.recentGroupKeys
    else
        self.pendingRecentGroupKeys = self.pendingRecentGroupKeys or {}
        target = self.pendingRecentGroupKeys
    end

    for key, group in pairs(groups) do
        local previous = old[key]
        if not previous
            or previous.itemID ~= group.itemID
            or (group.count or 0) > (previous.count or 0)
        then
            if minutes > 0 then target[key] = GetServerTime() + minutes * 60
            else target[key] = true end
        end
    end

    self.inventorySnapshot = self:BuildInventorySnapshot(groups)
    if minutes > 0 then self:RefreshTimedRecent(groups) end
end

function SB:ResetVisualSlotSession()
    self.visualSlotSession = {}
end

function SB:ApplyVisualSlotSession(categories)
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
