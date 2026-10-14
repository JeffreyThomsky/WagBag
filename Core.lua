local ADDON_NAME, SB = ...

SB = SB or {}
_G.WagBag = SB

SB.VERSION="1.2.1"
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

SLASH_WAGBAG1 = "/wb"
SLASH_WAGBAG2 = "/wagbag"
SlashCmdList["WAGBAG"] = function(message)
    if SB.HandleSlashCommand then
        return SB:HandleSlashCommand(message)
    end
    SB:Print("Core initialization stopped before the command handler was ready.")
end

 
 
 
function SB:BagInteractionKey(frame)
    if type(frame) == "string" then return frame end
    if (type(frame) == "table" or type(frame) == "userdata")
        and type(frame.GetName) == "function" then
        return frame:GetName() or frame  
    end
    return nil
end

function SB:HideNativeBagFrames()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        ContainerFrameCombinedBags:Hide()
    end
    for i=1,(NUM_CONTAINER_FRAMES or 13) do
        local frame=_G["ContainerFrame"..i]
        if frame and frame:IsShown() then frame:Hide() end
    end
end

function SB:CloseForInteraction(frame)
    if not self.mainFrame then return end
    local key=self:BagInteractionKey(frame)
    if frame ~= nil and not key then return end
    if frame == nil or (key and self.bagAutoOwner == key) then
        self.bagAutoOwner=nil
        if self.mainFrame:IsShown() then self.mainFrame:Hide() end
    end
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

     
     
    if type(OpenAllBags) == "function" and not self.openAllBagsHookInstalled then
        hooksecurefunc("OpenAllBags", function(frame)
            if not UIParent:IsShown() then return end
            SB:HideNativeBagFrames()
            SB:OpenForInteraction(frame)
        end)
        self.openAllBagsHookInstalled=true
    end
    if type(CloseAllBags) == "function" and not self.closeAllBagsHookInstalled then
        hooksecurefunc("CloseAllBags", function(frame)
            SB:CloseForInteraction(frame)
        end)
        self.closeAllBagsHookInstalled=true
    end
    if type(ToggleAllBags) == "function" and not self.toggleAllBagsHookInstalled then
        hooksecurefunc("ToggleAllBags", function()
            if SB._handlingToggleAllBags or not UIParent:IsShown() then return end
            SB._handlingToggleAllBags=true
            SB:HideNativeBagFrames()
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

function SB:OpenForInteraction(frame)
    if not self.mainFrame then return end
    if not self.mainFrame:IsShown() then
         
         
        self.bagAutoOwner=self:BagInteractionKey(frame)
        self:ResetBagSearchOnToggle()
        self:BeginBagSession()
        self:RefreshBags("Core.lua:162")
        self.mainFrame:Show()
    else
        self:RefreshBags("Core.lua:165")
    end
end

 
 
 
function SB:QueueBankRefresh(reason)
    if not (self.bankAccessOpen and self.bankFrame and self.bankFrame:IsShown()) then return end
    if self.bankRefreshQueued then return end
    self.bankRefreshQueued = true
    local isWarband = self.isMainline and Enum and Enum.BankType
        and self.bankMode == Enum.BankType.Account
     
     
    C_Timer.After(isWarband and 0.10 or 0.05, function()
        SB.bankRefreshQueued = false
        if SB.bankAccessOpen and SB.bankFrame and SB.bankFrame:IsShown() then
            SB:RefreshBank("Core.lua:188")
        end
    end)
end

function SB:EndBankInteraction()
    local bankVisible = self.bankFrame and self.bankFrame:IsShown()
    if not self.bankAccessOpen and not bankVisible then return end

    self.bankAccessOpen = false
    self.bankOpenGeneration = (self.bankOpenGeneration or 0) + 1
    if bankVisible then self.bankFrame:Hide() end
    self:CloseForInteraction(_G.BankFrame or "BankFrame")
    self:CloseBank()
    if self.EndBankRecentSession then self:EndBankRecentSession() end
    if self.EndWarbandRecentSession then self:EndWarbandRecentSession() end
end

local function IsBankInteractionType(interactionType)
    local types = Enum and Enum.PlayerInteractionType
    if not types then return false end
    return (types.Banker ~= nil and interactionType == types.Banker)
        or (types.CharacterBanker ~= nil and interactionType == types.CharacterBanker)
        or (types.AccountBanker ~= nil and interactionType == types.AccountBanker)
end

local eventFrame = CreateFrame("Frame")

local function RegisterSupportedEvent(eventName)
    local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    if not ok then
        SB.unsupportedEvents = SB.unsupportedEvents or {}
        SB.unsupportedEvents[eventName] = tostring(err)
    end
end

for _, eventName in ipairs({
    "ADDON_LOADED", "BAG_UPDATE_DELAYED",
    "GET_ITEM_INFO_RECEIVED", "CURRENCY_DISPLAY_UPDATE", "ACCOUNT_MONEY",
    "UPDATE_BINDINGS", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_LOGIN", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
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
         
        SB:OpenForInteraction(_G.MerchantFrame or "MerchantFrame")
        return
    end
    if event == "MERCHANT_CLOSED" then
        SB:CloseForInteraction(_G.MerchantFrame or "MerchantFrame")
        return
    end
    if event == "BANKFRAME_OPENED" then
        SB.bankMode = nil
        SB.bankAccessOpen = true
        SB.bankOpenGeneration = (SB.bankOpenGeneration or 0) + 1
        local generation = SB.bankOpenGeneration
        SB:OpenForInteraction(_G.BankFrame or "BankFrame")

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
        SB:EndBankInteraction()
        return
    end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if IsBankInteractionType(...) then SB:EndBankInteraction() end
        return
    end
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_BankUI" then
            if SB.InstallBankHooks then SB:InstallBankHooks() end
            return
        end
        if addonName == "Blizzard_DressUpFrame" or addonName == "Blizzard_CharacterUI" then
            if SB.InstallDressUpHooks then SB:InstallDressUpHooks() end
            return
        end
        if addonName == "CanIMogIt" then
            if SB.InvalidateBagButtonCache then SB:InvalidateBagButtonCache() end
            if SB.bankFrame then SB.bankFrame._warbandAppearance = nil end
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
        SB:InstallUnitTooltipLayer()
        SB:CreateSettingsFrame()
        SB:CreateMinimapButton()
        SB:InitializeRecentTracking()
        SB:InstallBagHooks()
        if SB.InstallBankHooks then SB:InstallBankHooks() end
        if SB.InstallDressUpHooks then SB:InstallDressUpHooks() end

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
        end
        if SB.settingsFrame and SB.settingsFrame:IsShown() and SB.RefreshCurrencySettings then
            SB:RefreshCurrencySettings()
        end
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if SB.ExtendBankVisualSort then SB:ExtendBankVisualSort() end
        if SB.bankMode == ((Enum.BankType and Enum.BankType.Account) or 2) then
            if SB.QueueWarbandRecentTracking then SB:QueueWarbandRecentTracking() end
        else
            if SB.QueueBankRecentTracking then SB:QueueBankRecentTracking() end
        end
        SB:QueueBankRefresh(event)
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
        if SB.ExtendBankVisualSort then SB:ExtendBankVisualSort() end
        if SB.bankMode == ((Enum.BankType and Enum.BankType.Account) or 2) then
            if SB.QueueWarbandRecentTracking then SB:QueueWarbandRecentTracking() end
        else
            if SB.QueueBankRecentTracking then SB:QueueBankRecentTracking() end
        end
        SB:QueueBankRefresh(event)
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
                if SB.mainFrame and SB.mainFrame:IsShown() then
                    SB:RefreshBags("Core.lua:353")
                end
            end)
        end
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        if SB.InvalidateStaticItemInfo then SB:InvalidateStaticItemInfo((...)) end
        SB.bagScanCache=nil
        if SB.InvalidateBagButtonCache then SB:InvalidateBagButtonCache() end
        SB._bagSearchNeedsRefresh = true
        if SB.mainFrame and SB.mainFrame:IsShown() then SB:RefreshBags("Core.lua:364") end
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

end)

function SB:HandleSlashCommand(message)

    message = strtrim(string.lower(message or ""))


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

    if message == "settings" or message == "config" then
        SB:ToggleSettings()
        return
    end

    SB:Print(SB:T("COMMANDS"))
    SB:Print(SB:T("CMD_TOGGLE"))
    SB:Print(SB:T("CMD_SETTINGS"))
end
