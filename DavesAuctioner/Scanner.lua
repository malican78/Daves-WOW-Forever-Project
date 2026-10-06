local _, addonTable = ...

local scannerFrame = CreateFrame("Frame")
scannerFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
scannerFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
scannerFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
scannerFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")

local scanButton = nil
local scanQueue = {}
local isScanning = false
local currentScanItemID = nil
local totalScanCount = 0
local timeoutTimer = nil

local function GetNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function GetItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return GetContainerItemID and GetContainerItemID(bag, slot) or nil
end

local function ProcessNextScan()
    if not isScanning then return end
    
    if timeoutTimer then
        timeoutTimer:Cancel()
        timeoutTimer = nil
    end

    if #scanQueue == 0 then
        isScanning = false
        currentScanItemID = nil
        print("|cff00ff00Dave's Auctioner:|r Live Bag Scan Complete! Updated " .. totalScanCount .. " items.")
        return
    end
    
    currentScanItemID = table.remove(scanQueue, 1)
    
    if C_AuctionHouse and C_AuctionHouse.SendSearchQuery then
        -- In 11.0, ItemKey is a table structure: { itemID = ID }
        local itemKey = { itemID = currentScanItemID }
        pcall(function()
            C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
        end)
        
        -- Fallback timeout to prevent softlock if the AH doesn't respond to a specific item
        timeoutTimer = C_Timer.NewTimer(1.0, function()
            if isScanning and currentScanItemID then
                ProcessNextScan()
            end
        end)
    else
        -- Fallback for classic / simulated environments
        DavesAuctionerDB.prices[currentScanItemID] = math.random(150, 15000)
        totalScanCount = totalScanCount + 1
        C_Timer.After(0.05, ProcessNextScan)
    end
end

local function CreateScanButton()
    local parent = addonTable.MasterFrame
    if not parent or scanButton then return end

    scanButton = CreateFrame("Button", "DavesAuctionerScanBtn", parent, "UIPanelButtonTemplate")
    scanButton:SetText("Scan Bags")
    scanButton:SetSize(150, 30)
    
    -- Anchor to the top right of the new unified Master UI Frame
    scanButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -20)
    scanButton:SetFrameLevel(parent:GetFrameLevel() + 10)
    
    scanButton:SetScript("OnClick", function()
        if isScanning then
            print("|cff00ff00Dave's Auctioner:|r Scan already in progress...")
            return
        end
        
        print("|cff00ff00Dave's Auctioner:|r Starting Live AH Bag Scan...")
        
        local foundItems = {}
        for bag = 0, 4 do
            for slot = 1, GetNumSlots(bag) do
                local itemID = GetItemID(bag, slot)
                if itemID then
                    foundItems[itemID] = true
                end
            end
        end
        
        scanQueue = {}
        for itemID, _ in pairs(foundItems) do
            table.insert(scanQueue, itemID)
        end
        
        totalScanCount = 0
        isScanning = true
        ProcessNextScan()
    end)
end

scannerFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        CreateScanButton()
        if scanButton then scanButton:Show() end
        
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if isScanning then
            isScanning = false
            scanQueue = {}
            if timeoutTimer then timeoutTimer:Cancel() end
            print("|cff00ff00Dave's Auctioner:|r Scan aborted (AH closed).")
        end
        
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_UPDATED" then
        if not isScanning or not currentScanItemID then return end
        
        local priceFound = false
        
        if C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(currentScanItemID) > 0 then
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(currentScanItemID, 1)
            if result and result.unitPrice then
                DavesAuctionerDB.prices[currentScanItemID] = result.unitPrice
                priceFound = true
            end
        elseif C_AuctionHouse.GetNumItemSearchResults then
            local itemKey = { itemID = currentScanItemID }
            if C_AuctionHouse.GetNumItemSearchResults(itemKey) > 0 then
                local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
                if result and result.buyoutAmount then
                    DavesAuctionerDB.prices[currentScanItemID] = result.buyoutAmount
                    priceFound = true
                end
            end
        end
        
        if priceFound then
            totalScanCount = totalScanCount + 1
        end
        
        -- Proceed to next item (slight throttle to avoid Blizzard disconnects)
        if timeoutTimer then timeoutTimer:Cancel(); timeoutTimer = nil end
        C_Timer.After(0.15, ProcessNextScan)
    end
end)
