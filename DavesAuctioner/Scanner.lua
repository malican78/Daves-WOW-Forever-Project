local _, addonTable = ...

local scannerFrame = CreateFrame("Frame")
scannerFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
-- Some classic clients use different AH events, but AUCTION_HOUSE_SHOW is fairly standard.
if not AUCTION_HOUSE_SHOW then
    scannerFrame:RegisterEvent("TRADE_SKILL_SHOW") -- Just as a fallback to ensure we can test it somewhere if AH fails
end

local scanButton = nil

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

local function CreateScanButton()
    local parent = AuctionHouseFrame or AuctionFrame
    if not parent or scanButton then return end

    scanButton = CreateFrame("Button", "DavesAuctionerScanBtn", parent, "UIPanelButtonTemplate")
    scanButton:SetSize(120, 26)
    
    if AuctionHouseFrame then
        scanButton:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 20)
    else
        scanButton:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 20)
    end
    scanButton:SetFrameStrata("TOOLTIP")
    scanButton:SetFrameLevel(parent:GetFrameLevel() + 10)
    
    scanButton:SetText("Scan Bags")
    
    scanButton:SetScript("OnClick", function()
        print("|cff00ff00Dave's Auctioner:|r Starting bag scan...")
        
        local foundItems = {}
        for bag = 0, 4 do
            for slot = 1, GetNumSlots(bag) do
                local itemID = GetItemID(bag, slot)
                if itemID then
                    foundItems[itemID] = true
                end
            end
        end
        
        local count = 0
        for itemID, _ in pairs(foundItems) do
            count = count + 1
            -- Placeholder for actual AH API queries
            -- We simulate storing the lowest buyout price
            DavesAuctionerDB.prices[itemID] = math.random(150, 15000) 
        end
        
        print("|cff00ff00Dave's Auctioner:|r Scanned " .. count .. " unique items in your bags! Tooltips updated.")
    end)
end

scannerFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        CreateScanButton()
        if scanButton then scanButton:Show() end
    end
end)
