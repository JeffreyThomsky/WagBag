local ADDON_NAME, SB = ...

SB = SB or {}
_G.WagBag = SB

SB.ADDON_NAME = ADDON_NAME
SB.VERSION="1.0.0"
SB.PREFIX = "|cff9b7cff[WagBag]|r"

function SB:Print(message)
    print(self.PREFIX .. " " .. tostring(message))
end

function SB:CreateHeaderCloseButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

SB.state = SB.state or {
    refreshPending = false,
}

SLASH_WAGBAG1 = "/wb"
SLASH_WAGBAG2 = "/wagbag"
SlashCmdList["WAGBAG"] = function(message)
    if SB.HandleSlashCommand then
        return SB:HandleSlashCommand(message)
    end
    SB:Print("Core initialization stopped before the command handler was ready.")
end

function SB:InstallBagHooks()
    if self.bagHooksInstalled then
        return
    end
    self.bagHooksInstalled = true

    local proxy = CreateFrame("Button", "WagBagBindingProxy", UIParent)
    proxy:SetScript("OnClick", function()
        SB:ToggleBags()
    end)
    self.bindingProxy = proxy

    local function BindCommand(command)
        local key1, key2 = GetBindingKey(command)
        if key1 then SetOverrideBindingClick(proxy, false, key1, "WagBagBindingProxy") end
        if key2 then SetOverrideBindingClick(proxy, false, key2, "WagBagBindingProxy") end
    end
    BindCommand("TOGGLEBACKPACK")
    BindCommand("OPENALLBAGS")

    if type(ToggleAllBags) == "function" and not self.toggleAllBagsHookInstalled then
        hooksecurefunc("ToggleAllBags", function()
            if SB._handlingToggleAllBags then return end
            SB._handlingToggleAllBags=true
            if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
                ContainerFrameCombinedBags:Hide()
            end
            for i=1,(NUM_CONTAINER_FRAMES or 13) do
                local f=_G["ContainerFrame"..i]
                if f and f:IsShown() then f:Hide() end
            end
            SB:ToggleBags()
            SB._handlingToggleAllBags=false
        end)
        self.toggleAllBagsHookInstalled=true
    end

    if MainMenuBarBackpackButton then
        MainMenuBarBackpackButton:SetScript("OnClick", function()
            SB:ToggleBags()
        end)
    end

    if type(ContainerFrame_GenerateFrame) == "function" then
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            if frame and frame:IsShown() then
                frame:Hide()
            end
        end)
    end
end

local BAG_CONFLICT_ADDONS = {
    "Bagnon", "AdiBags", "BetterBags", "ArkInventory", "Combuctor",
    "Inventorian", "Sorted", "BaudBag", "LiteBag",
}

function SB:IsElvUIBagModuleEnabled()
    local E = _G.ElvUI and _G.ElvUI[1]
    return E and E.private and E.private.bags and E.private.bags.enable == true
end

function SB:GetBagConflicts()
    local conflicts={}
    for _, addonName in ipairs(BAG_CONFLICT_ADDONS) do
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName) then
            table.insert(conflicts,{kind="addon",id=addonName,label=addonName})
        end
    end
    if self:IsElvUIBagModuleEnabled() then
        table.insert(conflicts,{kind="elvui",id="ElvUI_Bags",label="ElvUI Bags"})
    end
    return conflicts
end

function SB:DisableElvUIBags()
    local E = _G.ElvUI and _G.ElvUI[1]
    if not E or not E.private or not E.private.bags then return false end
    E.private.bags.enable=false
    return true
end

function SB:DisableAddonForCharacter(addonName)
    if C_AddOns and C_AddOns.DisableAddOn then
        C_AddOns.DisableAddOn(addonName, UnitName("player"))
        return true
    elseif DisableAddOn then
        DisableAddOn(addonName, UnitName("player"))
        return true
    end
    return false
end

function SB:CheckBagConflict()
    local conflicts=self:GetBagConflicts()
    if #conflicts==0 then return end

    local labels={}
    for _,entry in ipairs(conflicts) do table.insert(labels,entry.label) end
    local conflictText=table.concat(labels,", ")

    StaticPopupDialogs["WAGBAG_BAG_CONFLICT"]={
        text=SB:T("BAG_CONFLICT", conflictText),
        button1="WagBag",
        button2=(#conflicts==1 and conflicts[1].label or SB:T("OTHER_BAG")),
        OnAccept=function()
            for _,entry in ipairs(conflicts) do
                if entry.kind=="elvui" then
                    SB:DisableElvUIBags()
                else
                    SB:DisableAddonForCharacter(entry.id)
                end
            end
            ReloadUI()
        end,
        OnCancel=function()
            SB:DisableAddonForCharacter(ADDON_NAME)
            ReloadUI()
        end,
        timeout=0,
        whileDead=true,
        hideOnEscape=false,
        preferredIndex=3,
    }
    StaticPopup_Show("WAGBAG_BAG_CONFLICT",conflictText)
end

function SB:OpenForInteraction()
    if self.sessionDisabled or not self.mainFrame then return end
    if not self.mainFrame:IsShown() then
        self:BeginBagSession()
        self:RefreshBags()
        self.mainFrame:Show()
    else
        self:RefreshBags()
    end
end

local eventFrame = CreateFrame("Frame")
SB.eventFrame = eventFrame

local function RegisterSupportedEvent(eventName)
    local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    if not ok then
        SB.unsupportedEvents = SB.unsupportedEvents or {}
        SB.unsupportedEvents[eventName] = tostring(err)
    end
end

for _, eventName in ipairs({
    "ADDON_LOADED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED",
    "GET_ITEM_INFO_RECEIVED", "CURRENCY_DISPLAY_UPDATE", "ACCOUNT_MONEY",
    "UPDATE_BINDINGS", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "MERCHANT_SHOW", "PLAYER_LOGIN", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
    "ITEM_LOCK_CHANGED",
}) do
    RegisterSupportedEvent(eventName)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SB.loginInventoryBaselinePending = true
        SB.pendingRecentGroupKeys = {}
        SB.recentGroupKeys = nil
        SB:ResetVisualSlotSession()
        C_Timer.After(0.5, function() SB:CheckBagConflict() end)
        return
    end

    if event == "MERCHANT_SHOW" then
        SB:OpenForInteraction()
        return
    end
    if event == "BANKFRAME_OPENED" then
        SB.bankAccessOpen = true
        SB.bankOpenGeneration = (SB.bankOpenGeneration or 0) + 1
        local generation = SB.bankOpenGeneration
        SB:OpenForInteraction()

        if SB.bankFirstOpenSettled then
            if SB.bankAccessOpen and SB.bankOpenGeneration == generation then
                SB:OpenBank()
            end
        else
            C_Timer.After(0, function()
                SB.bankFirstOpenSettled = true
                if SB.bankAccessOpen and SB.bankOpenGeneration == generation then
                    SB:OpenBank()
                end
            end)
        end
        return
    end
    if event == "BANKFRAME_CLOSED" then
        SB.bankAccessOpen = false
        SB.bankOpenGeneration = (SB.bankOpenGeneration or 0) + 1
        SB:CloseBank()
        return
    end
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_BankUI" then
            if SB.InstallBankHooks then SB:InstallBankHooks() end
            return
        end
        if addonName ~= ADDON_NAME then
            return
        end

        SB:InitializeDatabase()
        SB.localeOverride = SB.db and SB.db.devLocaleOverride or nil
        SB:SetLocale(SB.localeOverride)
        if SB.RefreshLocalizedCategoryNames then SB:RefreshLocalizedCategoryNames() end
        SB:CreateMainFrame()
        SB:InitializeRecentTracking()
        SB:InstallBagHooks()
        if SB.InstallBankHooks then SB:InstallBankHooks() end

        SB:Print("Loaded v" .. SB.VERSION)
        SB:Print("Use /wb or /wagbag to open WagBag.")
        return
    end

    if event == "ACCOUNT_MONEY" then
        if SB.RefreshBankMoney then SB:RefreshBankMoney() end
        return
    end

    if event == "CURRENCY_DISPLAY_UPDATE" then
        if SB.mainFrame and SB.mainFrame:IsShown() and SB.RefreshCurrencyBar then
            SB:RefreshCurrencyBar()
            SB._currencyBarInitialized=true
        end
        if SB.settingsFrame and SB.settingsFrame:IsShown() and SB.RefreshCurrencySettings then
            SB:RefreshCurrencySettings()
        end
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if SB.bankFrame and SB.bankFrame:IsShown() and not SB.bankRefreshQueued then
            SB.bankRefreshQueued=true
            C_Timer.After(0.05,function()
                SB.bankRefreshQueued=false
                if SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank() end
            end)
        end
        return
    end

    if event == "ITEM_LOCK_CHANGED" then
        if SB.itemButtonPool and SB.NormalizeNativeItemButton then
            for _, wrapper in ipairs(SB.itemButtonPool) do
                if wrapper and wrapper:IsShown() then
                    SB:NormalizeNativeItemButton(wrapper)
                end
            end
        end
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        if SB.loginInventoryBaselinePending then
            SB:InitializeRecentTracking()
            SB.loginInventoryBaselinePending = false
        else
            SB:TrackInventoryChanges()
        end

        if not SB.bagRefreshQueued then
            SB.bagRefreshQueued=true
            C_Timer.After(0.05,function()
                SB.bagRefreshQueued=false
                if SB.mainFrame and SB.mainFrame:IsShown() then SB:RefreshBags() end
                if SB.bankFrame and SB.bankFrame:IsShown() then SB:RefreshBank() end
            end)
        end
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        SB.bagScanCache=nil
        if SB.mainFrame and SB.mainFrame:IsShown() then SB:RefreshBags() end
        if SB.settingsFrame and SB.settingsFrame:IsShown() and SB.settingsFrame.categoriesPage and SB.RefreshCategorySettings then
            SB:RefreshCategorySettings()
        end
        return
    end

    if event == "UPDATE_BINDINGS" then
        if SB.bindingProxy and not InCombatLockdown() then
            ClearOverrideBindings(SB.bindingProxy)
            local function Rebind(command)
                local key1,key2=GetBindingKey(command)
                if key1 then SetOverrideBindingClick(SB.bindingProxy,true,key1,"WagBagBindingProxy") end
                if key2 then SetOverrideBindingClick(SB.bindingProxy,true,key2,"WagBagBindingProxy") end
            end
            Rebind("TOGGLEBACKPACK")
            Rebind("OPENALLBAGS")
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if SB.state.refreshPending
            and SB.mainFrame
            and SB.mainFrame:IsShown()
        then
            SB:RefreshBags()
        end
    end
end)

function SB:HandleSlashCommand(message)

    message = strtrim(string.lower(message or ""))

    if message == "scan" then
        SB:PrintScan()
        return
    end

    local localeArg = message:match("^locale%s*(.-)%s*$")
    if localeArg ~= nil then
        if localeArg == "" then
            local suffix = SB.localeOverride and SB:T("LOCALE_OVERRIDE") or ""
            SB:Print(SB:T("LOCALE_STATUS", SB.clientLocale or "?", SB.localeCode or "?", suffix))
            return
        end
        if localeArg == "auto" then
            SB.localeOverride = nil
            if SB.db then SB.db.devLocaleOverride = nil end
            ReloadUI()
            return
        end
        local normalized = ({ruru="ruRU", enus="enUS", engb="enGB", dede="deDE", frfr="frFR", eses="esES", esmx="esMX", itit="itIT", ptbr="ptBR", kokr="koKR", zhcn="zhCN", zhtw="zhTW"})[localeArg]
        if not normalized then
            SB:Print(SB:T("LOCALE_UNKNOWN", localeArg))
            return
        end
        SB.localeOverride = normalized
        if SB.db then SB.db.devLocaleOverride = normalized end
        ReloadUI()
        return
    end

    if message == "" then
        SB:ToggleBags()
        return
    end

    if message == "cats" then
        local groups = SB:ScanBags()
        local buckets = SB:BuildCategoryBuckets(groups)
        SB:Print(SB:T("AUTO_CATEGORIES"))
        for _, bucket in ipairs(buckets) do
            SB:Print(SB:T("VIRTUAL_GROUPS", bucket.name, #bucket.items))
        end
        return
    end

    if message == "settings" or message == "config" then
        SB:ToggleSettings()
        return
    end

    SB:Print(SB:T("COMMANDS"))
    SB:Print(SB:T("CMD_TOGGLE"))
    SB:Print(SB:T("CMD_SCAN"))
    SB:Print(SB:T("CMD_SETTINGS"))
end
