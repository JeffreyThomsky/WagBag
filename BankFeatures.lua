local _, SB = ...

 
function SB:IsBankSplitView(bankType)
    local layout=self.db and self.db.bankLayout
    if not layout then return true end
    if bankType==((Enum.BankType and Enum.BankType.Account) or 2) then
        return layout.warbandSplitViewEnabled ~= false
    end
    return layout.splitViewEnabled ~= false
end

function SB:BuildBankDisplayGroups(physical,bankType)
    if self:IsBankSplitView(bankType) then return physical end
    local merged, result = {}, {}
    for _, group in ipairs(physical) do
        if group.nonStackableEquipment then
            result[#result+1] = group
        else
            local key = "bankitem:" .. group.itemID
            local aggregate = merged[key]
            if not aggregate then
                aggregate = {}
                for field, value in pairs(group) do aggregate[field] = value end
                aggregate.key = key
                aggregate.count = 0
                aggregate.physicalSlots = 0
                aggregate.slots = {}
                merged[key] = aggregate
                result[#result+1] = aggregate
            end
            aggregate.count = aggregate.count + group.count
            aggregate.physicalSlots = aggregate.physicalSlots + group.physicalSlots
            for _, slot in ipairs(group.slots) do
                aggregate.slots[#aggregate.slots+1] = slot
            end
        end
    end
    return result
end

 
 
 
 
 
function SB:ResetBankVisualSlotSession(bankMode)
    if bankMode == nil then
        self.bankVisualSlotSessions = {}
    else
        self.bankVisualSlotSessions = self.bankVisualSlotSessions or {}
        self.bankVisualSlotSessions[tostring(bankMode) .. ":physical"] = nil
        self.bankVisualSlotSessions[tostring(bankMode) .. ":merged"] = nil
    end
end

 
 
 
 
function SB:BeginBankVisualSort(bankMode)
    local mode = bankMode or self.bankMode or ((Enum and Enum.BankType and Enum.BankType.Character) or 0)
    self:ResetBankVisualSlotSession(mode)
    self.bankVisualSortGeneration = (self.bankVisualSortGeneration or 0) + 1
    local generation = self.bankVisualSortGeneration
    local state = {mode = mode, deadline = GetTime() + 1.0, generation = generation}
    self.bankVisualSortState = state
    if not C_Timer or not C_Timer.After then return end
    local function Settle()
        if self.bankVisualSortState ~= state or not self.bankAccessOpen then return end
        if (CursorHasItem and CursorHasItem()) or GetTime() < state.deadline then
            C_Timer.After(0.2, Settle)
            return
        end
        self.bankVisualSortState = nil
        self:ResetBankVisualSlotSession(mode)
        if self.bankMode == mode and self.bankFrame and self.bankFrame:IsShown() then
            self:RefreshBank("BankFeatures.lua:BankVisualSortSettled")
        end
    end
    C_Timer.After(0.2, Settle)
end

function SB:ExtendBankVisualSort()
    local state = self.bankVisualSortState
    if state and self.bankAccessOpen and self.bankMode == state.mode then
        state.deadline = GetTime() + 1.0
    end
end

function SB:CancelBankVisualSort()
    self.bankVisualSortState = nil
    self.bankVisualSortGeneration = (self.bankVisualSortGeneration or 0) + 1
end

function SB:ApplyBankVisualSlotSession(categories, bankMode)
     
     
     
    local account = (Enum and Enum.BankType and Enum.BankType.Account) or 2
    if (self.bankVisualSortState and self.bankVisualSortState.mode == bankMode)
        or (bankMode == account and self.warbandRecentSortPending) then
        for _, category in ipairs(categories) do
            category.visualItems = category.items
        end
        return
    end
    self.bankVisualSlotSessions = self.bankVisualSlotSessions or {}
    local context = tostring(bankMode) .. ":" ..
        (self:IsBankSplitView(bankMode) and "physical" or "merged")
    local session = self.bankVisualSlotSessions[context]
    if not session then
        session = {}
        self.bankVisualSlotSessions[context] = session
    end

    for _, category in ipairs(categories) do
        local current = {}
        for _, group in ipairs(category.items or {}) do
            current[group.key] = group
        end
        local visual, seen = {}, {}
        for _, key in ipairs(session[category.key] or {}) do
            if key ~= false and current[key] then
                visual[#visual + 1] = current[key]
                seen[key] = true
            else
                visual[#visual + 1] = false
            end
        end
        for _, group in ipairs(category.items or {}) do
            if not seen[group.key] then
                visual[#visual + 1] = group
            end
        end
        category.visualItems = visual
        local keys = {}
        for i, group in ipairs(visual) do
            keys[i] = group and group.key or false
        end
        session[category.key] = keys
    end
end

function SB:BankRecentSettings()
    local layout = self.db and self.db.bankLayout or {}
    return layout.recentEnabled == true,
        math.max(0, math.min(60, tonumber(layout.recentTimerMinutes) or 0))
end

function SB:GetBankRecentStore()
    if type(WagBagDB) ~= "table" then return nil end
    WagBagDB.bankRecentItems = WagBagDB.bankRecentItems or {}
    local key = self:GetCharacterProfileKey()
    WagBagDB.bankRecentItems[key] = WagBagDB.bankRecentItems[key] or {}
    return WagBagDB.bankRecentItems[key]
end

local function PhysicalSlotKey(bagID, slotID)
    return tostring(bagID) .. ":" .. tostring(slotID)
end

local function ScanRecentSlots(tabIDs)
    local snapshot = {slots = {}, totals = {}}
    for _, bagID in ipairs(tabIDs or {}) do
        for slotID = 1, (C_Container.GetContainerNumSlots(bagID) or 0) do
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info and info.itemID then
                local count = info.stackCount or 1
                snapshot.slots[PhysicalSlotKey(bagID, slotID)] = {itemID = info.itemID, count = count}
                snapshot.totals[info.itemID] = (snapshot.totals[info.itemID] or 0) + count
            end
        end
    end
    return snapshot
end

local function RecentCandidates(previous, current)
    local gained, candidates, keys = {}, {}, {}
    for itemID, count in pairs(current.totals) do
        local increase = count - ((previous and previous.totals[itemID]) or 0)
        if increase > 0 then gained[itemID] = increase end
    end
    for key, slot in pairs(current.slots) do
        local old = previous and previous.slots[key]
        local sameItem = old and old.itemID == slot.itemID
        local added = slot.count - (sameItem and old.count or 0)
        if gained[slot.itemID] and added > 0 then
            candidates[#candidates + 1] = {
                key = key, itemID = slot.itemID, added = added,
                newSlot = not sameItem,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.newSlot ~= b.newSlot then return a.newSlot end
        return a.key < b.key
    end)
    for _, candidate in ipairs(candidates) do
        local remaining = gained[candidate.itemID] or 0
        if remaining > 0 then
            keys[candidate.key] = candidate.itemID
            gained[candidate.itemID] = math.max(0, remaining - candidate.added)
        end
    end
    return keys
end

local function RecoverRecentMarks(store, snapshot, now)
    local active = {}
    for key, mark in pairs(store or {}) do
        local slot = snapshot.slots[key]
        if type(key) == "string" and type(mark) == "table"
            and type(mark.itemID) == "number" and type(mark.expiresAt) == "number"
            and mark.expiresAt > now and slot and slot.itemID == mark.itemID then
            active[key] = {itemID = mark.itemID, expiresAt = mark.expiresAt}
        end
    end
    return active
end

local function SaveRecentMarks(store, marks, now)
    if not store then return end
    wipe(store)
    for key, mark in pairs(marks or {}) do
        if type(mark.expiresAt) == "number" and mark.expiresAt > now then
            store[key] = {itemID = mark.itemID, expiresAt = mark.expiresAt}
        end
    end
end

local function ExpireRecentMarks(marks, enabled, minutes, snapshot)
    if not marks then return end
    if not enabled then wipe(marks); return end
    local now = GetServerTime()
    for key, mark in pairs(marks) do
        local slot = snapshot and snapshot.slots[key]
        if (snapshot and (not slot or slot.itemID ~= mark.itemID))
            or (minutes > 0 and (type(mark.expiresAt) ~= "number" or mark.expiresAt <= now)) then
            marks[key] = nil
        end
    end
end

local function MarkRecentCandidates(marks, candidates, minutes)
    local expiry = minutes > 0 and (GetServerTime() + minutes * 60) or true
    for key, itemID in pairs(candidates) do
        marks[key] = {itemID = itemID, expiresAt = expiry}
    end
end

local function RecentGroupKeys(groups, marks, preview)
    local keys = {}
    for _, group in ipairs(groups) do
        for _, slot in ipairs(group.slots or {}) do
            local key = PhysicalSlotKey(slot.bagID, slot.slotID)
            local mark = marks and marks[key]
            if (mark and mark.itemID == group.itemID)
                or (preview and preview[key] == group.itemID) then
                keys[group.key] = true
                break
            end
        end
    end
    return keys
end

function SB:ScanTrackedBankRecentSnapshot()
    return ScanRecentSlots(self.GetTrackedBankTabIDs and self:GetTrackedBankTabIDs() or {})
end

function SB:ExpireBankRecent()
    local enabled, minutes = self:BankRecentSettings()
    if self.bankRecentIDs then
        ExpireRecentMarks(self.bankRecentIDs, enabled, minutes)
    end
end

function SB:BeginBankRecentSession()
    self.bankRecentSnapshot = self:ScanTrackedBankRecentSnapshot()
    self.bankRecentDeadline = nil
    self.bankRecentPolling = nil
    self.bankRecentPreviewIDs = nil
    self.bankRecentSession = (self.bankRecentSession or 0) + 1
    self.bankRecentIDs = {}
    local enabled, minutes = self:BankRecentSettings()
    if enabled and minutes > 0 then
        local store = self:GetBankRecentStore()
        self.bankRecentIDs = RecoverRecentMarks(store, self.bankRecentSnapshot, GetServerTime())
        SaveRecentMarks(store, self.bankRecentIDs, GetServerTime())
        self:ScheduleBankRecentExpiration()
    end
end

function SB:EndBankRecentSession()
    self.bankRecentSnapshot = nil
    self.bankRecentDeadline = nil
    self.bankRecentPolling = nil
    self.bankRecentPreviewIDs = nil
    self.bankRecentSession = (self.bankRecentSession or 0) + 1
    self.bankRecentIDs = nil
    self.bankRecentExpiryToken = (self.bankRecentExpiryToken or 0) + 1
end

function SB:ClearBankRecent()
    self.bankRecentExpiryToken = (self.bankRecentExpiryToken or 0) + 1
    self.bankRecentIDs = {}
    self.bankRecentPreviewIDs = nil
    local store = self:GetBankRecentStore()
    if store then wipe(store) end
    if self.bankAccessOpen then self.bankRecentSnapshot = self:ScanTrackedBankRecentSnapshot() end
end

function SB:QueueBankRecentTracking()
    if not self.bankAccessOpen or not self.bankRecentSnapshot then return end
    local enabled = self:BankRecentSettings()
    if not enabled then return end
    local state = self.bankVisualSortState
    if state and state.mode == self.bankMode then
        state.deadline = GetTime() + 1.0
        self.bankRecentSnapshot = self:ScanTrackedBankRecentSnapshot()
        return
    end
    self.bankRecentDeadline = GetTime() + 0.8
    local current = self:ScanTrackedBankRecentSnapshot()
    self.bankRecentPreviewIDs = RecentCandidates(self.bankRecentSnapshot, current)
    if self.bankRecentPolling then return end
    self.bankRecentPolling = true
    local session = self.bankRecentSession
    local function Check()
        if session ~= self.bankRecentSession or not self.bankAccessOpen then return end
        if CursorHasItem and CursorHasItem() then
            C_Timer.After(0.5, Check)
            return
        end
        if GetTime() < (self.bankRecentDeadline or 0) then
            C_Timer.After(0.2, Check)
            return
        end
        self.bankRecentPolling = nil
        self.bankRecentPreviewIDs = nil
        local previous = self.bankRecentSnapshot
        local settled = self:ScanTrackedBankRecentSnapshot()
        self.bankRecentSnapshot = settled
        local _, minutes = self:BankRecentSettings()
        self.bankRecentIDs = self.bankRecentIDs or {}
        MarkRecentCandidates(self.bankRecentIDs, RecentCandidates(previous, settled), minutes)
        ExpireRecentMarks(self.bankRecentIDs, true, minutes, settled)
        if minutes > 0 then SaveRecentMarks(self:GetBankRecentStore(), self.bankRecentIDs, GetServerTime()) end
        self:ScheduleBankRecentExpiration()
        if self.bankFrame and self.bankFrame:IsShown() and self.RefreshBank then
            self:RefreshBank("BankFeatures.lua:BankRecentConfirmed")
        end
    end
    C_Timer.After(0.2, Check)
end

function SB:BankRecentKeys(groups)
    local enabled, minutes = self:BankRecentSettings()
    if not enabled then return {} end
    if self.bankRecentIDs then
        ExpireRecentMarks(self.bankRecentIDs, enabled, minutes)
    end
    return RecentGroupKeys(groups, self.bankRecentIDs, self.bankRecentPreviewIDs)
end

local ACCOUNT_BANK_TYPE = (Enum.BankType and Enum.BankType.Account) or 2

function SB:GetWarbandRecentStore()
    if type(WagBagDB) ~= "table" then return nil end
    WagBagDB.warbandRecentItems = WagBagDB.warbandRecentItems or {}
    return WagBagDB.warbandRecentItems
end

function SB:ScanWarbandRecentSnapshot()
    return ScanRecentSlots(self:GetTrackedWarbandTabIDs() or {})
end

function SB:ExpireWarbandRecent()
    if not self.warbandRecentIDs then return end
    local enabled, minutes = self:BankRecentSettings()
    ExpireRecentMarks(self.warbandRecentIDs, enabled, minutes)
end

function SB:SaveWarbandRecent()
    SaveRecentMarks(self:GetWarbandRecentStore(), self.warbandRecentIDs, GetServerTime())
end

function SB:ScheduleWarbandRecentExpiration()
    local enabled, minutes = self:BankRecentSettings()
    if not enabled or minutes <= 0 or not self.bankAccessOpen then return end
    local now, earliest = GetServerTime(), nil
    for _, mark in pairs(self.warbandRecentIDs or {}) do
        local expiry = mark.expiresAt
        if type(expiry) == "number" and expiry > now then
            if not earliest or expiry < earliest then earliest = expiry end
        end
    end
    if not earliest then return end
    self.warbandRecentExpiryToken = (self.warbandRecentExpiryToken or 0) + 1
    local token, session = self.warbandRecentExpiryToken, self.warbandRecentSession
    C_Timer.After(math.max(.1, earliest - now + .1), function()
        if token ~= self.warbandRecentExpiryToken or session ~= self.warbandRecentSession
            or not self.bankAccessOpen then return end
        self:ExpireWarbandRecent()
        self:SaveWarbandRecent()
        if self.bankMode == ACCOUNT_BANK_TYPE and self.bankFrame and self.bankFrame:IsShown() then
            self:RefreshBank("BankFeatures.lua:WarbandRecentExpiry")
        end
        self:ScheduleWarbandRecentExpiration()
    end)
end

function SB:BeginWarbandRecentSession()
    self.warbandRecentSession = (self.warbandRecentSession or 0) + 1
    self.warbandRecentDeadline = nil
    self.warbandRecentPolling = nil
    self.warbandRecentPending = nil
    self.warbandRecentPreviewIDs = nil
    self.warbandRecentSnapshot = self:ScanWarbandRecentSnapshot()
    self.warbandRecentIDs = {}
    self.warbandRecentExpiryToken = (self.warbandRecentExpiryToken or 0) + 1
    local enabled, minutes = self:BankRecentSettings()
    if enabled and minutes > 0 then
        self.warbandRecentIDs = RecoverRecentMarks(self:GetWarbandRecentStore(), self.warbandRecentSnapshot, GetServerTime())
        self:SaveWarbandRecent()
        self:ScheduleWarbandRecentExpiration()
    end
end

function SB:EndWarbandRecentSession()
    self.warbandRecentSortToken = (self.warbandRecentSortToken or 0) + 1
    self.warbandRecentSortPending = nil
    self.warbandRecentSortDeadline = nil
    self.warbandRecentSession = (self.warbandRecentSession or 0) + 1
    self.warbandRecentExpiryToken = (self.warbandRecentExpiryToken or 0) + 1
    self.warbandRecentSnapshot = nil
    self.warbandRecentDeadline = nil
    self.warbandRecentPolling = nil
    self.warbandRecentPending = nil
    self.warbandRecentPreviewIDs = nil
    self.warbandRecentIDs = nil
end

function SB:ClearWarbandRecent()
    self.warbandRecentSortToken = (self.warbandRecentSortToken or 0) + 1
    self.warbandRecentSortPending = nil
    self.warbandRecentSortDeadline = nil
    self.warbandRecentExpiryToken = (self.warbandRecentExpiryToken or 0) + 1
    self.warbandRecentIDs = {}
    self.warbandRecentPreviewIDs = nil
    self.warbandRecentPending = nil
    self.warbandRecentSession = (self.warbandRecentSession or 0) + 1
    self.warbandRecentPolling = nil
    local store = self:GetWarbandRecentStore()
    if store then wipe(store) end
    if self.bankAccessOpen and self.bankMode == ACCOUNT_BANK_TYPE then
        self.warbandRecentSnapshot = self:ScanWarbandRecentSnapshot()
    else
        self.warbandRecentSnapshot = nil
    end
end

function SB:BeginWarbandRecentSort()
    self:ClearWarbandRecent()
    if not self.bankAccessOpen or self.bankMode ~= ACCOUNT_BANK_TYPE then return end
    self.warbandRecentSortPending = true
    self.warbandRecentSortDeadline = GetTime() + 1.0
    self.warbandRecentSortToken = (self.warbandRecentSortToken or 0) + 1
    local token, session = self.warbandRecentSortToken, self.warbandRecentSession
    local function Settle()
        if token ~= self.warbandRecentSortToken or session ~= self.warbandRecentSession
            or not self.bankAccessOpen then return end
        if (CursorHasItem and CursorHasItem()) or GetTime() < (self.warbandRecentSortDeadline or 0) then
            C_Timer.After(0.2, Settle)
            return
        end
        self.warbandRecentSortPending = nil
        self.warbandRecentSortDeadline = nil
        self:ResetBankVisualSlotSession(ACCOUNT_BANK_TYPE)
        self.warbandRecentSnapshot = self:ScanWarbandRecentSnapshot()
        if self.bankMode == ACCOUNT_BANK_TYPE and self.bankFrame and self.bankFrame:IsShown() then
            self:RefreshBank("BankFeatures.lua:WarbandSortSettled")
        end
    end
    C_Timer.After(0.2, Settle)
end

function SB:WarbandHasLockedItems()
    if not C_Container then return false end
    for _, bagID in ipairs(self:GetTrackedWarbandTabIDs() or {}) do
        for slotID = 1, (C_Container.GetContainerNumSlots(bagID) or 0) do
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info and info.isLocked then return true end
        end
    end
    return false
end

function SB:PreviewWarbandRecentFromSnapshot(snapshot)
    if self.warbandRecentSortPending or not self.warbandRecentPending
        or not self.warbandRecentSnapshot then return end
    self.warbandRecentPreviewIDs = RecentCandidates(self.warbandRecentSnapshot, snapshot)
end

function SB:QueueWarbandRecentTracking()
    if not self.bankAccessOpen or not self.warbandRecentSnapshot then return end
    if self.warbandRecentSortPending then
        self.warbandRecentSortDeadline = GetTime() + 1.0
        return
    end
    local enabled = self:BankRecentSettings()
    if not enabled then return end
    self.warbandRecentPending = true
    self.warbandRecentDeadline = GetTime() + 0.8
    if self.warbandRecentPolling then return end
    self.warbandRecentPolling = true
    local session = self.warbandRecentSession
    local function Check()
        if session ~= self.warbandRecentSession or not self.bankAccessOpen then return end
        if (CursorHasItem and CursorHasItem()) or GetTime() < (self.warbandRecentDeadline or 0) then
            C_Timer.After(0.2, Check)
            return
        end
        self.warbandRecentPolling = nil
        self.warbandRecentPending = nil
        self.warbandRecentPreviewIDs = nil
        local previous = self.warbandRecentSnapshot
        local settled = self:ScanWarbandRecentSnapshot()
        self.warbandRecentSnapshot = settled
        local _, minutes = self:BankRecentSettings()
        self.warbandRecentIDs = self.warbandRecentIDs or {}
        MarkRecentCandidates(self.warbandRecentIDs, RecentCandidates(previous, settled), minutes)
        ExpireRecentMarks(self.warbandRecentIDs, true, minutes, settled)
        if minutes > 0 then self:SaveWarbandRecent() end
        self:ScheduleWarbandRecentExpiration()
        if self.bankMode == ACCOUNT_BANK_TYPE and self.bankFrame and self.bankFrame:IsShown() then
            self:RefreshBank("BankFeatures.lua:WarbandRecentConfirmed")
        end
    end
    C_Timer.After(0.2, Check)
end

function SB:WarbandRecentKeys(groups)
    if self.warbandRecentSortPending then return {} end
    local enabled, minutes = self:BankRecentSettings()
    if not enabled then return {} end
    if self.warbandRecentIDs then
        ExpireRecentMarks(self.warbandRecentIDs, enabled, minutes)
    end
    return RecentGroupKeys(groups, self.warbandRecentIDs, self.warbandRecentPreviewIDs)
end

function SB:ToggleBankSplitView()
    local account=(Enum.BankType and Enum.BankType.Account) or 2
    if self.bankMode==account then
        self.db.bankLayout.warbandSplitViewEnabled=not self:IsBankSplitView(account)
    else
        self.db.bankLayout.splitViewEnabled=not self:IsBankSplitView()
    end
    if self.bankAccessOpen and self.RefreshBank then self:RefreshBank("BankFeatures.lua:206") end
end

 
 
function SB:SortCharacterBank()
    if not self.bankAccessOpen then return false end
    local containers = C_Container
    local sorter = containers and (containers.SortBank or containers.SortBankBags)
    if type(sorter) ~= "function" and type(_G.SortBankBags) ~= "function" then return false end
    self:ClearBankRecent()
    local mode = self.bankMode or ((Enum and Enum.BankType and Enum.BankType.Character) or 0)
    if self.BeginBankVisualSort then self:BeginBankVisualSort(mode)
    elseif self.ResetBankVisualSlotSession then self:ResetBankVisualSlotSession(mode) end
    local ok
    if containers.SortBank then
        local bankType = (Enum.BankType and Enum.BankType.Character) or 0
        ok = pcall(containers.SortBank, bankType)
    elseif containers and type(containers.SortBankBags)=="function" then
        ok = pcall(containers.SortBankBags)
    else
        ok = pcall(_G.SortBankBags)
    end
    if not ok and self.CancelBankVisualSort then
        self:CancelBankVisualSort()
        self:ResetBankVisualSlotSession(mode)
    end
    if self.RefreshBank then self:RefreshBank("BankFeatures.lua:226") end
    return ok
end

 
 
function SB:CreateBankModeButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(20,20)
    button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    local left=button:CreateTexture(nil,"ARTWORK")
    local right=button:CreateTexture(nil,"OVERLAY")
    for _, icon in ipairs({left,right}) do
        icon:SetTexture("Interface\\Buttons\\WHITE8X8")
        icon:SetSize(8,8)
    end
    button:SetScript("OnClick",function()
        self:ToggleBankSplitView()
    end)
    function button:UpdateState()
        local split=SB:IsBankSplitView(SB.bankMode)
        left:ClearAllPoints(); right:ClearAllPoints()
        if split then
            left:SetPoint("LEFT",self,"LEFT",2,0)
            right:SetPoint("RIGHT",self,"RIGHT",-2,0)
            left:SetVertexColor(.82,.82,.82,1)
            right:SetVertexColor(1,1,1,1)
            self:SetBackdropColor(.025,.025,.025,.96)
            self:SetBackdropBorderColor(.72,.72,.72,1)
        else
            left:SetPoint("CENTER",self,"CENTER",-2,2)
            right:SetPoint("CENTER",self,"CENTER",2,-2)
            left:SetVertexColor(.58,.58,.58,1)
            right:SetVertexColor(.88,.70,.08,1)
            self:SetBackdropColor(.035,.035,.04,.95)
            self:SetBackdropBorderColor(.22,.22,.25,1)
        end
    end
    button:SetScript("OnEnter",function(x)
        GameTooltip:SetOwner(x,"ANCHOR_BOTTOM")
        GameTooltip:SetText(SB:IsBankSplitView(SB.bankMode) and SB:T("SPLIT_STACKS") or SB:T("MERGED_STACKS"))
        GameTooltip:AddLine(SB:T("STACK_MODE_DESC"),1,1,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",GameTooltip_Hide)
    button:UpdateState()
    return button
end

 
 
function SB:ScheduleBankRecentExpiration()
    local enabled, minutes = self:BankRecentSettings()
    if not enabled or minutes <= 0 or not self.bankAccessOpen then return end
    local now = GetServerTime()
    local earliest
    for _, mark in pairs(self.bankRecentIDs or {}) do
        local expiry = mark.expiresAt
        if type(expiry) == "number" and expiry > now then
            if not earliest or expiry < earliest then earliest = expiry end
        end
    end
    if not earliest then return end
    self.bankRecentExpiryToken = (self.bankRecentExpiryToken or 0) + 1
    local token, session = self.bankRecentExpiryToken, self.bankRecentSession
    C_Timer.After(math.max(.1, earliest - now + .1), function()
        if token ~= self.bankRecentExpiryToken or session ~= self.bankRecentSession
            or not self.bankAccessOpen then return end
        self:ExpireBankRecent()
        SaveRecentMarks(self:GetBankRecentStore(), self.bankRecentIDs, GetServerTime())
        if self.bankFrame and self.bankFrame:IsShown() then
            self:RefreshBank("BankFeatures.lua:BankRecentExpiry")
        end
        self:ScheduleBankRecentExpiration()
    end)
end

function SB:PlanBankCategoryColumns(entries, requested, maxWidth, startY, heightLimit, gap)
    if #entries==0 then return {},0,startY,0 end
    local maxColumns=math.min(4,#entries)
    local plans={}
    for count=1,maxColumns do
        local heights={}
        local widths={}
        local placements={}
        for col=1,count do heights[col]=startY; widths[col]=0 end
        for _,entry in ipairs(entries) do
            local col=1
            for candidate=2,count do
                if heights[candidate]<heights[col] then col=candidate end
            end
            placements[#placements+1]={frame=entry.frame,column=col,y=heights[col]}
            heights[col]=heights[col]+entry.height+gap
            widths[col]=math.max(widths[col],entry.width)
        end
        local width=0
        local bottom=startY
        for col=1,count do
            if col>1 then width=width+gap end
            width=width+widths[col]
            if heights[col]>startY then bottom=math.max(bottom,heights[col]-gap) end
        end
        plans[count]={positions=placements,widths=widths,width=width,bottom=bottom,columns=count}
    end
    local selected=plans[1]
    for count=2,math.min(maxColumns,requested) do
        if plans[count].width<=maxWidth then selected=plans[count] end
    end
    if selected.bottom>heightLimit then
        for count=selected.columns+1,maxColumns do
            local nextPlan=plans[count]
            if nextPlan.width<=maxWidth and nextPlan.bottom<selected.bottom then
                selected=nextPlan
                if selected.bottom<=heightLimit then break end
            end
        end
    end
    local columnX={}
    local x=0
    for col=1,selected.columns do
        columnX[col]=x
        x=x+selected.widths[col]+gap
    end
    for _,entry in ipairs(selected.positions) do entry.x=columnX[entry.column] end
    return selected.positions,selected.width,selected.bottom,selected.columns
end
