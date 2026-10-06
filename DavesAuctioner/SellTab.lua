-- =========================================================
-- Dave's Auctioner - Sell Tab
-- =========================================================

local _, addonTable = ...

local sellFrame
local toggleBtn

-- Custom Money Formatter
local function FormatMoney(copperAmount)
    if not copperAmount or copperAmount == 0 then return "0c" end
    local g = math.floor(copperAmount / 10000)
    local s = math.floor((copperAmount % 10000) / 100)
    local c = copperAmount % 100
    
    local str = ""
    if g > 0 then str = str .. "|cffffd700" .. g .. "g|r " end
    if s > 0 then str = str .. "|cffc7c7cf" .. s .. "s|r " end
    if c > 0 or str == "" then str = str .. "|cffeda55f" .. c .. "c|r" end
    return str:match("^%s*(.-)%s*$")
end

local function InjectSellUI()
    local parent = addonTable.MasterFrame
    if not parent or sellFrame then return end

    sellFrame = CreateFrame("Frame", "DavesAuctionerSellFrame", parent)
    sellFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -50)
    sellFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    sellFrame:SetWidth(320)
    sellFrame:Show()
    
    sellFrame.bg = sellFrame:CreateTexture(nil, "BACKGROUND")
    sellFrame.bg:SetAllPoints()
    sellFrame.bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
    
    local title = sellFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", sellFrame, "TOP", 0, -20)
    title:SetText("Quick Sell Panel")

    -- Item Drop Area
    local dropBtn = CreateFrame("Button", nil, sellFrame, "UIPanelButtonTemplate")
    dropBtn:SetSize(72, 72)
    dropBtn:SetPoint("TOP", title, "BOTTOM", 0, -30)
    
    dropBtn.icon = dropBtn:CreateTexture(nil, "ARTWORK")
    dropBtn.icon:SetAllPoints()
    dropBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    local dropLabel = sellFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropLabel:SetPoint("TOP", dropBtn, "BOTTOM", 0, -15)
    dropLabel:SetText("Drag & Drop an item from your bags here")

    local priceLabel = sellFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    priceLabel:SetPoint("TOP", dropLabel, "BOTTOM", 0, -20)
    priceLabel:SetText("Auto-Undercut Price: N/A")

    local currentItemID = nil

    -- Drag & Drop Handlers
    dropBtn:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" then
            currentItemID = itemID
            local itemName, itemIcon
            if C_Item and C_Item.GetItemInfo then
                itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
            else
                itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
            end
            self.icon:SetTexture(itemIcon)
            dropLabel:SetText(itemLink or itemName)
            
            local savedPrice = DavesAuctionerDB.prices[itemID]
            if savedPrice and savedPrice > 0 then
                local undercut = math.max(1, savedPrice - 1) -- Undercut by 1 copper
                priceLabel:SetText("Auto-Undercut Price: " .. FormatMoney(undercut) .. " per unit")
            else
                priceLabel:SetText("Auto-Undercut Price: |cffff0000Unknown (Run 'Scan Bags' first)|r")
            end
            
            ClearCursor()
        end
    end)
    
    dropBtn:SetScript("OnClick", function(self)
        self:GetScript("OnReceiveDrag")(self)
    end)

    -- Post Button
    local postBtn = CreateFrame("Button", nil, sellFrame, "UIPanelButtonTemplate")
    postBtn:SetSize(200, 40)
    postBtn:SetPoint("TOP", priceLabel, "BOTTOM", 0, -30)
    postBtn:SetText("Post Auction")
    postBtn:SetScript("OnClick", function()
        if not currentItemID then
            print("|cff00ff00Dave's Auctioner:|r You must drop an item in the slot first!")
            return
        end
        
        local savedPrice = DavesAuctionerDB.prices[currentItemID]
        if not savedPrice or savedPrice <= 0 then
            print("|cff00ff00Dave's Auctioner:|r Cannot post. Unknown price. Run 'Scan Bags' first.")
            return
        end
        
        local undercut = math.max(1, savedPrice - 1)
        
        -- Find the exact bag and slot of the dragged item
        local foundBag, foundSlot, foundQty = nil, nil, 0
        for bag = 0, 4 do
            local numSlots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or (GetContainerNumSlots and GetContainerNumSlots(bag) or 0)
            for slot = 1, numSlots do
                local itemID = C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot) or (GetContainerItemID and GetContainerItemID(bag, slot))
                if itemID == currentItemID then
                    foundBag = bag
                    foundSlot = slot
                    local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                    foundQty = info and info.stackCount or 1
                    break
                end
            end
            if foundBag then break end
        end
        
        if not foundBag then
            print("|cff00ff00Dave's Auctioner:|r Could not locate that item in your bags.")
            return
        end

        if ItemLocation and ItemLocation.CreateFromBagAndSlot and C_AuctionHouse then
            local itemLoc = ItemLocation:CreateFromBagAndSlot(foundBag, foundSlot)
            
            -- Determine if commodity (stackable crafting mats) or regular item (gear/pets)
            local isCommodity = false
            if C_AuctionHouse.GetItemCommodityStatus then
                isCommodity = (C_AuctionHouse.GetItemCommodityStatus(itemLoc) == Enum.ItemCommodityStatus.Commodity)
            end
            
            local duration = 2 -- 1=12h, 2=24h, 3=48h
            
            -- Send to Blizzard Servers
            if isCommodity then
                C_AuctionHouse.PostCommodity(itemLoc, duration, foundQty, undercut)
            else
                C_AuctionHouse.PostItem(itemLoc, duration, foundQty, undercut, undercut)
            end
            
            local itemName = "Item"
            if C_Item and C_Item.GetItemInfo then
                itemName = C_Item.GetItemInfo(currentItemID) or "Item"
            elseif GetItemInfo then
                itemName = GetItemInfo(currentItemID) or "Item"
            end
            
            print(string.format("|cff00ff00Dave's Auctioner:|r Posting %dx %s for %s per unit!", foundQty, itemName, FormatMoney(undercut)))
        else
            print("|cff00ff00Dave's Auctioner:|r Classic AH posting is not yet wired.")
        end

        -- Reset UI
        currentItemID = nil
        dropBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        dropLabel:SetText("Drag & Drop an item from your bags here")
        priceLabel:SetText("Auto-Undercut Price: N/A")
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        InjectSellUI()
    end
end)
