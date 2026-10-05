local _, SB = ...

SB.Categories = {
    weapon =     { name = SB:T("CAT_WEAPON"),       order = 10 },
    equipment =  { name = SB:T("CAT_EQUIPMENT"),   order = 20 },
    consumable = { name = SB:T("CAT_CONSUMABLE"),  order = 30 },
    reagent =    { name = SB:T("CAT_REAGENT"),     order = 40 },
    recipe =     { name = SB:T("CAT_RECIPE"),      order = 50 },
    decor =      { name = SB:T("CAT_DECOR"),       order = 55 },
    quest =      { name = SB:T("CAT_QUEST"),      order = 60 },
    container =  { name = SB:T("CAT_CONTAINER"),   order = 70 },
    junk =       { name = SB:T("CAT_JUNK"),          order = 80 },
    misc =       { name = SB:T("CAT_MISC"),        order = 90 },
}

function SB:RefreshLocalizedCategoryNames()
    if not self.Categories then return end
    local keys = {
        weapon="CAT_WEAPON", equipment="CAT_EQUIPMENT", consumable="CAT_CONSUMABLE",
        reagent="CAT_REAGENT", recipe="CAT_RECIPE", decor="CAT_DECOR", quest="CAT_QUEST",
        container="CAT_CONTAINER", junk="CAT_JUNK", misc="CAT_MISC",
    }
    for categoryKey, localeKey in pairs(keys) do
        if self.Categories[categoryKey] then
            self.Categories[categoryKey].name = self:T(localeKey)
        end
    end
end

local ITEM_CLASS = Enum and Enum.ItemClass or {}

local CLASS = {
    CONSUMABLE      = ITEM_CLASS.Consumable      or 0,
    CONTAINER       = ITEM_CLASS.Container       or 1,
    WEAPON          = ITEM_CLASS.Weapon          or 2,
    GEM             = ITEM_CLASS.Gem             or 3,
    ARMOR           = ITEM_CLASS.Armor           or 4,
    REAGENT         = ITEM_CLASS.Reagent         or 5,
    TRADEGOODS      = ITEM_CLASS.Tradegoods      or 7,
    ITEM_ENHANCEMENT= ITEM_CLASS.ItemEnhancement or 8,
    RECIPE          = ITEM_CLASS.Recipe          or 9,
    QUEST           = ITEM_CLASS.Questitem       or 12,
    KEY             = ITEM_CLASS.Key             or 13,
    MISC            = ITEM_CLASS.Miscellaneous   or 15,
    GLYPH           = ITEM_CLASS.Glyph           or 16,
    BATTLEPET       = ITEM_CLASS.Battlepet       or 17,
    WOW_TOKEN       = ITEM_CLASS.WoWToken        or 18,
    PROFESSION      = ITEM_CLASS.Profession      or 20,
}

local EQUIPMENT_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_BODY = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_TABARD = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_PROFESSION_TOOL = true,
    INVTYPE_PROFESSION_GEAR = true,
}

function SB:GetAutomaticCategory(group)
    if not group then
        return "misc"
    end

    local classID = group.classID
    local equipLoc = group.itemEquipLoc

    if group.itemID and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, group.itemID)
        local decorType = Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Decor or 1
        if ok and info and info.entryType == decorType then
            return "decor"
        end
    end

    if classID == CLASS.CONTAINER or equipLoc == "INVTYPE_BAG" then
        return "container"
    end

    if classID == CLASS.WEAPON then
        return "weapon"
    end

    if classID == CLASS.ARMOR or EQUIPMENT_LOCS[equipLoc] then
        return "equipment"
    end

    if classID == CLASS.CONSUMABLE then
        return "consumable"
    end

    if classID == CLASS.REAGENT
        or classID == CLASS.TRADEGOODS
        or classID == CLASS.GEM
        or classID == CLASS.ITEM_ENHANCEMENT
        or classID == CLASS.PROFESSION
    then
        return "reagent"
    end

    if classID == CLASS.RECIPE then
        return "recipe"
    end

    if classID == CLASS.QUEST or classID == CLASS.KEY then
        return "quest"
    end

    return "misc"
end

function SB:GetCategoryForGroup(group)
    local assignments = self.db.categories.assignments or {}
    local assigned = assignments[tostring(group.itemID)] or assignments[group.itemID]

    if assigned then
        local isCustom = self.db.categories.custom
            and self.db.categories.custom[assigned] ~= nil
        local isBuiltIn = self.Categories[assigned] ~= nil

        if isCustom or isBuiltIn then
            return assigned
        end
    end

    return self:GetAutomaticCategory(group)
end

function SB:GetCategoryName(key)
    if self.Categories[key] then
        return self.Categories[key].name
    end

    local custom = self.db.categories.custom[key]
    if custom then
        return custom.name
    end

    return key
end

function SB:GroupMatchesSearch(group, searchText)
    searchText = strtrim(string.lower(searchText or ""))
    if searchText == "" then
        return true
    end

    local name = group.itemName
    if not name and group.itemID then
        name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(group.itemID)
    end

    if name and string.find(string.lower(name), searchText, 1, true) then
        return true
    end

    return string.find(tostring(group.itemID or ""), searchText, 1, true) ~= nil
end

local function StableFallback(a, b)
    if a.itemID ~= b.itemID then
        return (a.itemID or 0) < (b.itemID or 0)
    end
    return (a.key or "") < (b.key or "")
end

local function SortGroupsDefault(a, b)
    local ac, bc = a.classID or 999, b.classID or 999
    if ac ~= bc then return ac < bc end
    local as, bs = a.subClassID or 999, b.subClassID or 999
    if as ~= bs then return as < bs end
    return StableFallback(a, b)
end

function SB:SortCategoryGroups(items)
    local mode = self.db.items.sortMode or "default"

    table.sort(items, function(a, b)
        if mode == "name" then
            local an = string.lower(a.itemName or (a.itemID and C_Item.GetItemNameByID(a.itemID)) or "")
            local bn = string.lower(b.itemName or (b.itemID and C_Item.GetItemNameByID(b.itemID)) or "")
            if an ~= bn then return an < bn end
        elseif mode == "quality" then
            local aq, bq = a.quality or -1, b.quality or -1
            if aq ~= bq then return aq > bq end
        elseif mode == "itemLevel" then
            local ai = self:GetGroupCurrentItemLevel(a) or 0
            local bi = self:GetGroupCurrentItemLevel(b) or 0
            if ai ~= bi then return ai > bi end
        else
            return SortGroupsDefault(a, b)
        end
        return StableFallback(a, b)
    end)
end

function SB:BuildCategoryBuckets(groups)
    local buckets = {}

    for _, group in pairs(groups) do
        local categoryKey
        if self.recentGroupKeys and self.recentGroupKeys[group.key] then
            categoryKey = "__recent"
        elseif group.quality == 0 then
            categoryKey = "junk"
        else
            categoryKey = self:GetCategoryForGroup(group)
        end

        local isTransient = categoryKey == "__recent"
        local isBuiltIn = self.Categories[categoryKey] ~= nil
        local isCustom = self.db.categories.custom
            and self.db.categories.custom[categoryKey] ~= nil

        if not isTransient and not isBuiltIn and not isCustom then
            categoryKey = "misc"
        end
        buckets[categoryKey] = buckets[categoryKey] or {}
        table.insert(buckets[categoryKey], group)
    end

    for _, items in pairs(buckets) do
        self:SortCategoryGroups(items)
    end

    if self.categoryDragGroup then
        for _, key in ipairs(self.db.categories.order or {}) do
            if self.Categories[key] or (self.db.categories.custom and self.db.categories.custom[key]) then
                buckets[key] = buckets[key] or {}
            end
        end
    end

    local result = {}
    local seen = {}

    if buckets.__recent and #buckets.__recent > 0 then
        table.insert(result, {
            key = "__recent",
            name = self:T("CAT_RECENT"),
            items = buckets.__recent,
            noDrop = true,
            noReorder = true,
        })
        seen.__recent = true
    end

    local hidden = self.db.categories.hidden or {}
    for _, key in ipairs(self.db.categories.order or {}) do
        if (not hidden[key] or self.categoryDragGroup) and buckets[key] and (#buckets[key] > 0 or self.categoryDragGroup) then
            table.insert(result, {
                key = key,
                name = self:GetCategoryName(key),
                items = hidden[key] and self.categoryDragGroup and {} or buckets[key],
                hiddenDuringDrag = hidden[key] and self.categoryDragGroup and true or nil,
            })
            seen[key] = true
        end
    end

    local remaining = {}
    for key, items in pairs(buckets) do
        if key ~= "__recent" and not hidden[key] and not seen[key] and #items > 0 then
            table.insert(remaining, key)
        end
    end
    table.sort(remaining, function(a, b)
        local ao = self.Categories[a] and self.Categories[a].order or 999
        local bo = self.Categories[b] and self.Categories[b].order or 999
        if ao == bo then return a < b end
        return ao < bo
    end)

    for _, key in ipairs(remaining) do
        table.insert(result, {
            key = key,
            name = self:GetCategoryName(key),
            items = buckets[key],
        })
    end

    return result
end
