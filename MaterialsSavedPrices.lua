--[[ MaterialsSavedPrices and its files © silvereyes
     Distributed under MIT license (see LICENSE) ]]


local addon = {
    name = "MaterialsSavedPrices",
    version = '1.0.0'
}

MaterialsSavedPrices = addon

local MAX_ITEM_ID   = 200000
local IDS_PER_LOOP  = 60
local LINK_FORMAT   = "|H%s:item:%s:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local OUTPUT_FORMAT = "[%s]=1,"
local SHORT_CODE    = "matprice"
local materialsItemIds

-- Create localized strings
for stringId, value in pairs(MATSAVPRC_STRINGS) do
    ZO_CreateStringId(stringId, value)
end
MATSAVPRC_STRINGS = nil

local basePriceFunction = LibPrice.Price
LibPrice.Price = function (sourceKey, itemLink)
    local self = addon
    local id = GetItemLinkItemId(itemLink)
    if sourceKey == SHORT_CODE then
        if self.data[id] then
            return {
                SuggestedPrice = self.data[id]
            }
        end
        return
    end
    local got = basePriceFunction(sourceKey, itemLink)
    if sourceKey == "npc" then
        if not got or not got.npcVendor
           or (materialsItemIds[id] > 0 and got.npcVendor < materialsItemIds[id])
        then
            return {
                npcVendor = materialsItemIds[id]
            }
        end
    end
    return got
end

local baseSourceListFunction = LibPrice.SourceList
LibPrice.SourceList = function()
    local sourceList = LibPrice.SOURCE_LIST
    if not sourceList then
        sourceList = baseSourceListFunction()
        local indexOfCrown
        for i, key in ipairs(sourceList) do
            if key == LibPrice.CROWN then
                indexOfCrown = i
                break
            end
        end
        table.insert(sourceList, indexOfCrown, SHORT_CODE)
    end
    return sourceList
end

local function expandSourceListAndCall(baseFunction, itemLink, ...)
    local sourceList = {...}
    local mmFound
    for _, source in ipairs(sourceList) do
        if source == "mm" then
            mmFound = true
            break
        end
    end
    if mmFound then
        table.insert(sourceList, SHORT_CODE)
    end
    return baseFunction(itemLink, unpack(sourceList))
end

local baseItemLinkToPriceGoldFunction = LibPrice.ItemLinkToPriceGold
LibPrice.ItemLinkToPriceGold = function(itemLink, ...)
    return expandSourceListAndCall(baseItemLinkToPriceGoldFunction, itemLink, ...)
end
local baseItemLinkToPriceDataFunction = LibPrice.ItemLinkToPriceData
LibPrice.ItemLinkToPriceData = function(itemLink, ...)
    return expandSourceListAndCall(baseItemLinkToPriceGoldFunction, itemLink, ...)
end

function addon:InitializeData()
    MaterialsSavedPrices_Data = {}
    setmetatable(MaterialsSavedPrices_Data, { __mode = "v" })
    self.data = MaterialsSavedPrices_Data
end

function addon.Save(itemId)
    local self = addon
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Save")
  
    if not itemId then
        d(GetString(SI_MATSAVPRC_SAVING))
        self:InitializeData()
    end
    
    local c = 0
    local id = itemId
    local itemLink, price, sourceKey
    while c < IDS_PER_LOOP do
        id = next(materialsItemIds, id)
        if id == nil then
            break
        end
        c = c + 1
        itemLink = string.format(LINK_FORMAT, LINK_STYLE_DEFAULT, id)
        price, sourceKey = LibPrice.ItemLinkToPriceGold(itemLink)
        if price and price > 0 
           and (sourceKey ~= "npc" or materialsItemIds[id] == 0)
        then
            local price = string.format("%.2f", price)
            local numericPrice = tonumber(price)
            if numericPrice == math.floor(numericPrice) then
                price = numericPrice
            end
            self.data[id] = price
        end
    end
    
    -- Done
    if id == nil then
        d(GetString(SI_GAMEPAD_CAMPAIGN_SCORING_DURATION_REMAINING_DONE))
        
    -- Go to next batch
    else
        EVENT_MANAGER:RegisterForUpdate(addon.name .. "Save", SCAN_TIMEOUT_MS,
            function() self.Save(id) end)
    end
end

--[[
Note, the output of this scan can be copy/pasted directly into the source code at the bottom, but you'll
probably want to format it with the following NotePad++ find/replace:
* Enable regex and put cursor at the top of the copy/pasted text
* Find: [\r\n]+[^\r\n]*\[([0-9]+)\]=1,[\r\n]+[^\r\n]*\[([0-9]+)\]=1,[\r\n]+[^\r\n]*\[([0-9]+)\]=1,[\r\n]+[^\r\n]*\[([0-9]+)\]=1,[\r\n]+[^\r\n]*\[([0-9]+)\]=1,[\r\n]+[^\r\n]*\[([0-9]+)\]=1,
* Replace with: \r\n[\1]=0,[\2]=0,[\3]=0,[\4]=0,[\5]=0,[\6]=0,
]]--
function addon.Scan(itemId)
    EVENT_MANAGER:UnregisterForUpdate(addon.name .. "Scan")
  
    if not itemId then
        itemId = 171434
        d("materialsItemIds = {")
    end
    
    for id = itemId, itemId + IDS_PER_LOOP do
        
        if id == MAX_ITEM_ID then
            d("}")
            return
        end
        
        local itemLink = string.format(LINK_FORMAT, LINK_STYLE_DEFAULT, id)
        if CanItemLinkBeVirtual(itemLink) then
            d(string.format(OUTPUT_FORMAT, id))
        end
    end
    EVENT_MANAGER:RegisterForUpdate(addon.name .. "Scan", SCAN_TIMEOUT_MS,
        function() addon.Scan(itemId + IDS_PER_LOOP + 1) end)
end

function addon.SlashCommand(command)
    command = LocaleAwareToLower(command)
    if command == "save" then
        addon.Save()
    elseif command == "scan" then
        addon.Scan()
    end
end


function addon.InsertTooltipText(control, itemLink)
    if not CanItemLinkBeVirtual(itemLink) then
        return
    end
    local savedMatPrice = LibPrice.ItemLinkToPriceGold(itemLink, SHORT_CODE)
    if not savedMatPrice or savedMatPrice == 0 then
        return
    end
    control:AddLine("Saved Price: " .. ZO_CurrencyControl_FormatCurrency(tonumber(savedMatPrice)))
end

function addon.InitializeTooltips()
    local self = addon
    
    ZO_PostHook(ItemTooltip, "SetBagItem",
        function(control, bagId, slotIndex)
            self.InsertTooltipText(control, GetItemLink(bagId, slotIndex))
        end)
    ZO_PostHook(ItemTooltip, "SetLootItem",
        function(control, lootId)
            self.InsertTooltipText(control, GetLootItemLink(lootId))
        end)
    ZO_PostHook(PopupTooltip, "SetLink",
        function(control, itemLink)
            self.InsertTooltipText(control, itemLink)
        end)

    local function tradingHouseHook()
        ZO_PostHook(ItemTooltip, "SetTradingHouseItem",
            function(control, tradingHouseIndex)
                self.InsertTooltipText(control, GetTradingHouseSearchResultItemLink(tradingHouseIndex))
            end)
    end
    if AwesomeGuildStore then
        AwesomeGuildStore:RegisterCallback(AwesomeGuildStore.callback.AFTER_INITIAL_SETUP, tradingHouseHook)
    else
        tradingHouseHook()
    end
end

local function onAddonLoaded(event, name)
    local self = addon
    if name ~= self.name then
        return
    end
    SLASH_COMMANDS["/" .. SHORT_CODE] = self.SlashCommand
    self.data = MaterialsSavedPrices_Data
    if not self.data then
        self:InitializeData()
    end
    self:InitializeTooltips()
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, onAddonLoaded)

materialsItemIds = {
[521]=0,[533]=0,[793]=0,[794]=0,[800]=0,[802]=0,
[803]=0,[808]=0,[810]=0,[811]=0,[812]=0,[813]=0,
[818]=0,[883]=0,[1187]=0,[4439]=0,[4442]=0,[4447]=0,
[4448]=0,[4456]=0,[4463]=0,[4464]=0,[4478]=0,[4482]=0,
[4486]=0,[4487]=0,[4570]=0,[5413]=0,[5820]=0,[6000]=0,
[6001]=0,[6020]=0,[16291]=0,[23095]=0,[23097]=0,[23099]=0,
[23100]=0,[23101]=0,[23103]=0,[23104]=0,[23105]=0,[23107]=0,
[23117]=0,[23118]=0,[23119]=0,[23121]=0,[23122]=0,[23123]=0,
[23125]=0,[23126]=0,[23127]=0,[23129]=0,[23130]=0,[23131]=0,
[23133]=0,[23134]=0,[23135]=0,[23137]=0,[23138]=0,[23142]=0,
[23143]=0,[23149]=0,[23165]=0,[23171]=0,[23173]=0,[23203]=0,
[23204]=0,[23219]=0,[23221]=0,[23265]=0,[23266]=0,[23267]=0,
[23268]=0,[26802]=0,[26954]=0,[27035]=0,[27043]=0,[27048]=0,
[27049]=0,[27052]=0,[27057]=0,[27058]=0,[27059]=0,[27063]=0,
[27064]=0,[27100]=0,[28603]=0,[28604]=0,[28609]=0,[28610]=0,
[28636]=0,[28639]=0,[28666]=0,[29030]=0,[30148]=0,[30149]=0,
[30151]=0,[30152]=0,[30153]=0,[30154]=0,[30155]=0,[30156]=0,
[30157]=0,[30158]=0,[30159]=0,[30160]=0,[30161]=0,[30162]=0,
[30163]=0,[30164]=0,[30165]=0,[30166]=0,[30219]=0,[30221]=0,
[33150]=15,[33194]=15,[33217]=0,[33218]=0,[33219]=0,[33220]=0,
[33251]=15,[33252]=15,[33253]=15,[33254]=15,[33255]=15,[33256]=15,
[33257]=15,[33258]=15,[33752]=0,[33753]=0,[33754]=0,[33755]=0,
[33756]=0,[33758]=0,[33768]=0,[33771]=0,[33772]=0,[33773]=0,
[33774]=0,[34305]=0,[34307]=0,[34308]=0,[34309]=0,[34311]=0,
[34321]=0,[34323]=0,[34324]=0,[34329]=0,[34330]=0,[34333]=0,
[34334]=0,[34335]=0,[34345]=0,[34346]=0,[34347]=0,[34348]=0,
[34349]=0,[42869]=0,[42870]=0,[42871]=0,[42872]=0,[42873]=0,
[42874]=0,[42875]=0,[42876]=0,[42877]=0,[45806]=54,[45807]=60,
[45808]=66,[45809]=72,[45810]=78,[45811]=84,[45812]=87,[45813]=93,
[45814]=96,[45815]=99,[45816]=105,[45817]=30,[45818]=42,[45819]=51,
[45820]=54,[45821]=60,[45822]=66,[45823]=72,[45824]=78,[45825]=84,
[45826]=87,[45827]=93,[45828]=96,[45829]=99,[45830]=105,[45831]=0,
[45832]=0,[45833]=0,[45834]=0,[45835]=0,[45836]=0,[45837]=0,
[45838]=0,[45839]=0,[45840]=0,[45841]=0,[45842]=0,[45843]=0,
[45844]=0,[45845]=0,[45846]=0,[45847]=0,[45848]=0,[45849]=0,
[45850]=0,[45851]=0,[45852]=0,[45853]=0,[45854]=0,[45855]=30,
[45856]=42,[45857]=51,[46127]=0,[46128]=0,[46129]=0,[46130]=0,
[46131]=0,[46132]=0,[46133]=0,[46134]=0,[46135]=0,[46136]=0,
[46137]=0,[46138]=0,[46139]=0,[46140]=0,[46141]=0,[46142]=0,
[46149]=0,[46150]=0,[46151]=0,[46152]=0,[54170]=0,[54171]=0,
[54172]=0,[54173]=0,[54174]=0,[54175]=0,[54176]=0,[54177]=0,
[54178]=0,[54179]=0,[54180]=0,[54181]=0,[56862]=0,[56863]=0,
[57587]=0,[57665]=0,[59922]=0,[59923]=0,[64222]=0,[64489]=0,
[64500]=0,[64501]=0,[64502]=0,[64504]=0,[64506]=0,[64508]=111,
[64509]=111,[64685]=0,[64687]=0,[64688]=0,[64689]=0,[64690]=0,
[64713]=0,[68340]=2508,[68341]=2508,[68342]=0,[69555]=0,[69556]=0,
[71198]=0,[71199]=0,[71200]=0,[71239]=0,[71538]=0,[71582]=0,
[71584]=0,[71668]=0,[71736]=0,[71738]=0,[71740]=0,[71742]=0,
[71766]=0,[75357]=0,[75358]=0,[75359]=0,[75360]=0,[75361]=0,
[75362]=0,[75363]=0,[75364]=0,[75365]=0,[75370]=0,[75371]=0,
[75373]=0,[76910]=0,[76911]=0,[76914]=0,[77581]=0,[77583]=0,
[77584]=0,[77585]=0,[77587]=0,[77589]=0,[77590]=0,[77591]=0,
[79304]=0,[79305]=0,[79672]=0,[81994]=0,[81995]=0,[81996]=0,
[81997]=0,[81998]=0,[82000]=0,[82002]=0,[82004]=0,[96388]=0,
[114283]=0,[114889]=0,[114890]=0,[114891]=0,[114892]=0,[114893]=0,
[114894]=0,[114895]=0,[114983]=0,[114984]=0,[115026]=0,[120078]=0,
[120894]=0,[121518]=0,[121519]=0,[121520]=0,[121521]=0,[121522]=0,
[121523]=0,[125476]=0,[126581]=0,[130058]=0,[130059]=0,[130060]=0,
[130061]=0,[130062]=0,[132617]=0,[132618]=0,[132619]=0,[132620]=0,
[134687]=0,[134798]=0,[135137]=0,[135138]=0,[135139]=0,[135140]=0,
[135141]=0,[135142]=0,[135143]=0,[135144]=0,[135145]=0,[135146]=0,
[135147]=0,[135148]=0,[135149]=0,[135150]=0,[135151]=0,[135152]=0,
[135153]=0,[135154]=0,[135155]=0,[135156]=0,[135157]=0,[135158]=0,
[135159]=0,[135160]=0,[135161]=0,[137951]=0,[137953]=0,[137955]=0,
[137957]=0,[137958]=0,[137961]=0,[138813]=0,[139019]=0,[139020]=0,
[139409]=0,[139410]=0,[139411]=0,[139412]=0,[139413]=0,[139414]=0,
[139415]=0,[139416]=0,[139417]=0,[139418]=0,[139419]=0,[139420]=0,
[140267]=0,[141740]=0,[141820]=0,[141821]=0,[145532]=0,[145533]=0,
[147288]=0,[150669]=0,[150670]=0,[150671]=0,[150672]=0,[150731]=0,
[150789]=0,[151621]=0,[151622]=0,[151907]=0,[151908]=0,[152235]=0,
[156571]=0,[156589]=0,[156606]=0,[156624]=0,[156643]=0,[157533]=0,
[158307]=0,[160509]=0,[160558]=0,[160575]=0,[160592]=0,[160609]=0,
[160626]=0,[166045]=0,[166988]=0,[167005]=0,[167286]=0,[167959]=0,
[167976]=0,[167993]=0,[171326]=0,[171328]=0,[171433]=0,
}
addon.materialsItemIds = materialsItemIds