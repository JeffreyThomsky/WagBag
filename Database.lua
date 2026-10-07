local _, SB = ...

local defaults = {
    layout = { blocksPerRow=2, cellsPerRow=4, scale=1.0, backgroundAlpha=0.97, locked=false, growthAnchor="TOPLEFT", point=nil, relativePoint=nil, x=nil, y=nil },
    bankLayout = { blocksPerRow=2, cellsPerRow=18, separateMaterials=false, anchor="TOPLEFT", anchorModel=2, scale=1.0, backgroundAlpha=0.97, locked=false, point=nil, relativePoint=nil, x=nil, y=nil },
    items = { sortMode="default", recentTimerMinutes=0, showQualityBorder=true, itemLevel={enabled=true,fontSize=12}, stackCount={fontSize=12} },
    splitView = { enabled=false },
    currency = { selected={} },
    categories = { custom={}, assignments={}, hidden={}, nextCustomID=1, order={"weapon","equipment","consumable","reagent","recipe","decor","quest","container","misc"} },
}

local function DeepCopy(value)
    if type(value)~="table" then return value end
    local out={}
    for k,v in pairs(value) do out[DeepCopy(k)]=DeepCopy(v) end
    return out
end

local function CopyDefaults(source,destination)
    for key,value in pairs(source) do
        if type(value)=="table" then
            if type(destination[key])~="table" then destination[key]={} end
            CopyDefaults(value,destination[key])
        elseif destination[key]==nil then destination[key]=value end
    end
end

local function CharacterKey()
    local name=UnitName("player") or "Unknown"
    local realm=GetRealmName and GetRealmName() or ""
    realm=(realm or ""):gsub("%s+","")
    return realm~="" and (name.." - "..realm) or name
end

local function EnsureBuiltInCategories(profile)
    local order=profile.categories.order or {}
    local function has(key) for _,v in ipairs(order) do if v==key then return true end end return false end
    local function insertBefore(key,before)
        if has(key) then return end
        local at=#order+1
        for i,v in ipairs(order) do if v==before then at=i break end end
        table.insert(order,at,key)
    end
    insertBefore("decor","quest")
    insertBefore("junk","misc")
    profile.categories.order=order
    profile.categories.hidden=profile.categories.hidden or {}
end

local function RemoveLegacyCIMISetting(profile)
    if type(profile)=="table" and type(profile.items)=="table" then
        profile.items.canIMogIt=nil
    end
end

function SB:GetCharacterProfileKey() return CharacterKey() end
function SB:GetCurrentProfileName() return self.profileKey or (WagBagDB and WagBagDB.defaultProfile) or "Default" end

function SB:GetProfileNames()
    local names={}
    for name in pairs((WagBagDB and WagBagDB.profiles) or {}) do table.insert(names,name) end
    table.sort(names,function(a,b)
        if a=="Default" then return b~="Default" end
        if b=="Default" then return false end
        return a:lower()<b:lower()
    end)
    return names
end


local function PrepareProfile(profile)
    profile.bagBar=nil
    CopyDefaults(defaults,profile)
    EnsureBuiltInCategories(profile)
    RemoveLegacyCIMISetting(profile)
    return profile
end

function SB:InitializeDatabase()
    if type(WagBagDB)~="table" then WagBagDB={} end

    if type(WagBagDB.profiles)~="table" then
        local old=next(WagBagDB) and DeepCopy(WagBagDB) or nil
        WagBagDB={schema=2,profiles={},profileKeys={}}
        if old and old.layout then WagBagDB.profiles.Default=PrepareProfile(old) end
    end

    WagBagDB.profiles=WagBagDB.profiles or {}
    WagBagDB.profileKeys=WagBagDB.profileKeys or {}
    WagBagDB.minimap=WagBagDB.minimap or {}
    if WagBagDB.minimap.show==nil then WagBagDB.minimap.show=true end
    if WagBagDB.minimap.angle==nil then WagBagDB.minimap.angle=225 end
    for _,profile in pairs(WagBagDB.profiles) do
        if type(profile)=="table" then PrepareProfile(profile) end
    end

    local charKey=CharacterKey()
    local assigned=WagBagDB.profileKeys[charKey]

    if type(WagBagDB.profiles.Default)~="table" then
        WagBagDB.profiles.Default=PrepareProfile(DeepCopy(defaults))
    end
    WagBagDB.defaultProfile="Default"

    if not assigned or type(WagBagDB.profiles[assigned])~="table" then
        assigned=WagBagDB.defaultProfile
        WagBagDB.profileKeys[charKey]=assigned
    end

    self.profileKey=assigned
    self.db=PrepareProfile(WagBagDB.profiles[assigned])
    self.profilePersisted=true
    WagBagDB.schema=2
end

function SB:PersistCurrentProfile()
    if not self.db or not self.profileKey then return end
    WagBagDB.profiles[self.profileKey]=self.db
    WagBagDB.profileKeys[CharacterKey()]=self.profileKey
    self.profilePersisted=true
end

function SB:ApplyActiveProfile()
    local layout=self.db and self.db.layout
    local frame=self.mainFrame
    if frame and layout then
        frame:SetScale(layout.scale or 1)
        frame:ClearAllPoints()
        if layout.point and layout.relativePoint and layout.x~=nil and layout.y~=nil then
            if layout.anchorModel==2 and self.bagAnchorFrame then
                self:SetBagAnchorPosition(layout.x,layout.y)
                self:AttachMainFrameToBagAnchor(layout.growthAnchor or "TOPLEFT")
            else
                frame:SetPoint(layout.point,UIParent,layout.relativePoint,layout.x,layout.y)
                local a,x,y=self:CaptureGrowthAnchorPosition(layout.growthAnchor or "TOPLEFT")
                if a then self:ApplyGrowthAnchorPosition(a,x,y) end
            end
        else
            frame:SetPoint("CENTER")
            local a,x,y=self:CaptureGrowthAnchorPosition(layout.growthAnchor or "TOPLEFT")
            if a then self:ApplyGrowthAnchorPosition(a,x,y) end
        end
        if frame.SetBackdropColor then frame:SetBackdropColor(.02,.02,.025,layout.backgroundAlpha or .97) end
    end

    if self.RefreshLocalizedCategoryNames then self:RefreshLocalizedCategoryNames() end
    if self.RefreshBags then self:RefreshBags() end
    if self.RefreshCurrencyBar then self:RefreshCurrencyBar() end

    if self.bankFrame then self.bankFrame._wagBankAnchorAttached=nil end
    if self.bankFrame and self.bankFrame:IsShown() then
        if self.ApplyNativeBankAppearance then self:ApplyNativeBankAppearance() end
        if self.ApplyStoredBankAnchor then self:ApplyStoredBankAnchor() end
    end
    if self.RefreshSettingsValues then self:RefreshSettingsValues() end
    if self.UpdateGrowthAnchorMarker then self:UpdateGrowthAnchorMarker() end
end

function SB:SelectProfile(profileKey)
    if not WagBagDB or type(WagBagDB.profiles[profileKey])~="table" then return false end
    self.profileKey=profileKey
    self.db=PrepareProfile(WagBagDB.profiles[profileKey])
    WagBagDB.profileKeys[CharacterKey()]=profileKey
    self.profilePersisted=true
    self:ApplyActiveProfile()
    return true
end

function SB:ProfileNameExists(name,excludeName)
    name=strtrim(name or "")
    if name=="" then return false end
    local lower=name:lower()
    for key in pairs((WagBagDB and WagBagDB.profiles) or {}) do
        if key~=excludeName and key:lower()==lower then return true end
    end
    return false
end

function SB:CreateProfile(profileName)
    profileName=strtrim(profileName or "")
    if profileName=="" then return false,"empty" end
    if self:ProfileNameExists(profileName) then return false,"exists" end
    WagBagDB.profiles[profileName]=PrepareProfile(DeepCopy(defaults))
    return true,nil,profileName
end

function SB:RenameProfile(oldName,newName)
    newName=strtrim(newName or "")
    if oldName=="Default" then return false,"default" end
    if not WagBagDB or type(WagBagDB.profiles[oldName])~="table" then return false,"source" end
    if newName=="" then return false,"empty" end
    if self:ProfileNameExists(newName,oldName) then return false,"exists" end
    if newName==oldName then return true,nil,newName end
    WagBagDB.profiles[newName]=WagBagDB.profiles[oldName]
    WagBagDB.profiles[oldName]=nil
    for char,key in pairs(WagBagDB.profileKeys or {}) do
        if key==oldName then WagBagDB.profileKeys[char]=newName end
    end
    if self.profileKey==oldName then self.profileKey=newName end
    return true,nil,newName
end

function SB:DeleteProfile(profileKey)
    if not WagBagDB or not WagBagDB.profiles or not WagBagDB.profiles[profileKey] then return false end
    if profileKey=="Default" then return false,"default" end
    if profileKey==self.profileKey then return false,"current" end
    WagBagDB.profiles[profileKey]=nil
    for char,key in pairs(WagBagDB.profileKeys or {}) do
        if key==profileKey then WagBagDB.profileKeys[char]="Default" end
    end
    WagBagDB.defaultProfile="Default"
    return true
end

local function Pack(v)
    local t=type(v)
    if t=="nil" then return "z" elseif t=="boolean" then return v and "b1" or "b0" elseif t=="number" then local s=tostring(v);return "n"..#s..":"..s
    elseif t=="string" then return "s"..#v..":"..v elseif t=="table" then
        local parts={"t"}; local keys={}
        for k in pairs(v) do if type(k)=="string" or type(k)=="number" then table.insert(keys,k) end end
        table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
        parts[#parts+1]=tostring(#keys)..":"
        for _,k in ipairs(keys) do parts[#parts+1]=Pack(k);parts[#parts+1]=Pack(v[k]) end
        return table.concat(parts)
    end
    return "z"
end
local function UnpackValue(s,pos)
    local tag=s:sub(pos,pos);pos=pos+1
    if tag=="z" then return nil,pos elseif tag=="b" then local c=s:sub(pos,pos);return c=="1",pos+1 end
    local colon=s:find(":",pos,true);if not colon then error("bad length") end
    local len=tonumber(s:sub(pos,colon-1));if not len then error("bad length") end;pos=colon+1
    if tag=="n" then local raw=s:sub(pos,pos+len-1);return tonumber(raw),pos+len end
    if tag=="s" then return s:sub(pos,pos+len-1),pos+len end
    if tag=="t" then local out={};for _=1,len do local k;k,pos=UnpackValue(s,pos);local v;v,pos=UnpackValue(s,pos);out[k]=v end;return out,pos end
    error("bad tag")
end
local function HexEncode(data)
    return (data:gsub(".",function(c)return string.format("%02X",string.byte(c))end))
end
local function HexDecode(data)
    if data=="" or (#data%2)~=0 or data:find("[^0-9A-Fa-f]") then error("bad hex") end
    return (data:gsub("..",function(cc)return string.char(tonumber(cc,16))end))
end
local function DecodeProfileString(text)
    text=strtrim(text or ""):gsub("%s+","")
    local payload=text:match("^WAGBAG2:(.+)$")
    if not payload then error("format") end
    local decoded=HexDecode(payload)
    local value,nextPos=UnpackValue(decoded,1)
    if type(value)~="table" or nextPos~=#decoded+1 then error("invalid data") end
    return value
end
function SB:ExportProfile()
    return "WAGBAG2:"..HexEncode(Pack(self.db))
end
function SB:ImportProfile(text,profileName)
    local ok,value=pcall(DecodeProfileString,text)
    if not ok or type(value)~="table" then return false,"data" end
    if type(value.layout)~="table" or type(value.items)~="table" or type(value.categories)~="table" or type(value.bankLayout)~="table" then return false,"data" end
    profileName=strtrim(profileName or CharacterKey())
    if profileName=="" then return false,"empty" end
    if self:ProfileNameExists(profileName) then return false,"exists",profileName end
    local candidate=PrepareProfile(DeepCopy(value))
    WagBagDB.profiles[profileName]=candidate
    return true,nil,profileName
end

