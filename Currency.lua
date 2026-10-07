local _, SB = ...

SB.currencyButtons = SB.currencyButtons or {}

function SB:GetCharacterCurrencies()
    local result = {}
    local seen = {}

    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize then
        return result
    end

    local size = C_CurrencyInfo.GetCurrencyListSize()
    for index = 1, size do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(index)
        if listInfo and not listInfo.isHeader and listInfo.currencyID then
            local id = listInfo.currencyID
            if not seen[id] then
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                local name = (info and info.name) or listInfo.name
                local icon = (info and info.iconFileID) or listInfo.iconFileID
                local quantity = (info and info.quantity)
                if quantity == nil then quantity = listInfo.quantity end
                if name and icon then
                    seen[id] = true
                    table.insert(result, {
                        id = id,
                        name = name,
                        icon = icon,
                        quantity = tonumber(quantity) or 0,
                        discovered = (info and info.discovered ~= false) or (listInfo.discovered ~= false),
                    })
                end
            end
        end
    end

    table.sort(result, function(a,b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return result
end

function SB:GetSelectedCurrencies()
    local selected = self.db.currency and self.db.currency.selected or {}
    local currencies = self:GetCharacterCurrencies()
    local out, seen = {}, {}

    for _, currency in ipairs(currencies) do
        if selected[tostring(currency.id)] or selected[currency.id] then
            seen[currency.id]=true
            table.insert(out, currency)
        end
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        for key, enabled in pairs(selected) do
            if enabled then
                local id=tonumber(key)
                if id and not seen[id] then
                    local info=C_CurrencyInfo.GetCurrencyInfo(id)
                    if info and info.name and info.iconFileID then
                        seen[id]=true
                        table.insert(out,{
                            id=id,
                            name=info.name,
                            icon=info.iconFileID,
                            quantity=tonumber(info.quantity) or 0,
                            discovered=info.discovered~=false,
                        })
                    end
                end
            end
        end
    end

    table.sort(out,function(a,b) return string.lower(a.name)<string.lower(b.name) end)
    return out
end

local function FormatQuantity(value)
    value = tonumber(value) or 0
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000):gsub("%.0m","m")
    elseif value >= 10000 then
        return string.format("%.1fk", value / 1000):gsub("%.0k","k")
    end
    return tostring(value)
end

function SB:RefreshCurrencyBar()
    if not self.currencyBar or not self.mainFrame then return end
    local currencies = self:GetSelectedCurrencies()

    for _,button in ipairs(self.currencyButtons) do button:Hide() end
    if #currencies == 0 then
        self.currencyBar:Hide()
        return
    end

    local x = 0
    for i,currency in ipairs(currencies) do
        local button = self.currencyButtons[i]
        if not button then
            button = CreateFrame("Button", nil, self.currencyBar)
            button:SetHeight(20)
            local icon = button:CreateTexture(nil,"ARTWORK")
            icon:SetSize(16,16); icon:SetPoint("LEFT",0,0)
            icon:SetTexCoord(.07,.93,.07,.93); button.icon=icon
            local count = button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            count:SetPoint("LEFT",icon,"RIGHT",3,0); count:SetJustifyH("LEFT"); button.count=count
            button:SetScript("OnEnter",function(b)
                if not b.currencyID then return end
                GameTooltip:SetOwner(b,"ANCHOR_TOP")
                GameTooltip:SetCurrencyByID(b.currencyID)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave",GameTooltip_Hide)
            self.currencyButtons[i]=button
        end
        button.currencyID=currency.id
        button.icon:SetTexture(currency.icon)
        button.count:SetText(FormatQuantity(currency.quantity))
        local textWidth=math.ceil(button.count:GetStringWidth())
        button:SetWidth(16+3+textWidth)
        button:ClearAllPoints(); button:SetPoint("LEFT",self.currencyBar,"LEFT",x,0)
        x=x+button:GetWidth()+10
        button:Show()
    end
    self.currencyBar:SetWidth(math.max(1,x-10))
    self.currencyBar:Show()
end
