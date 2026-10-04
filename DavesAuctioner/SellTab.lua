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

local function BuildSellFrame(parent)
    if sellFrame then return end

    sellFrame = CreateFrame("Frame", "DavesAuctionerSellFrame", parent)
    sellFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -60)
    sellFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
    sellFrame:SetFrameStrata("HIGH")
    sellFrame:SetFrameLevel(parent:GetFrameLevel() + 50)
    sellFrame:Hide()

    -- Dark Background Overlay
    sellFrame.bg = sellFrame:CreateTexture(nil, "BACKGROUND")
    sellFrame.bg:SetAllPoints()
    sellFrame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Item Drop Area
    local dropBtn = CreateFrame("Button", nil, sellFrame, "UIPanelButtonTemplate")
    dropBtn:SetSize(72, 72)
    dropBtn:SetPoint("TOPLEFT", sellFrame, "TOPLEFT", 40, -40)
    
    dropBtn.icon = dropBtn:CreateTexture(nil, "ARTWORK")
    dropBtn.icon:SetAllPoints()
    dropBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    local dropLabel = sellFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dropLabel:SetPoint("TOPLEFT", dropBtn, "TOPRIGHT", 20, -10)
    dropLabel:SetText("Drag & Drop an item from your bags here")

    local priceLabel = sellFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    priceLabel:SetPoint("TOPLEFT", dropLabel, "BOTTOMLEFT", 0, -10)
    priceLabel:SetText("Auto-Undercut Price: N/A")

    local currentItemID = nil

    -- Drag & Drop Handlers
    dropBtn:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" then
            currentItemID = itemID
            local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
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
    postBtn:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -40)
    postBtn:SetText("Post Auction")
    postBtn:SetScript("OnClick", function()
        if currentItemID then
            print("|cff00ff00Dave's Auctioner:|r Successfully posted item! (Simulation)")
            -- Reset UI
            currentItemID = nil
            dropBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            dropLabel:SetText("Drag & Drop an item from your bags here")
            priceLabel:SetText("Auto-Undercut Price: N/A")
        else
            print("|cff00ff00Dave's Auctioner:|r You must drop an item in the slot first!")
        end
    end)
end

local function InjectToggleBtn()
    local parent = AuctionHouseFrame or AuctionFrame
    if not parent then return end

    if not toggleBtn then
        toggleBtn = CreateFrame("Button", "DavesAuctionerSellToggle", parent, "UIPanelButtonTemplate")
        toggleBtn:SetSize(120, 26)
        
        if AuctionHouseFrame then
            toggleBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 150, 20)
        else
            toggleBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 150, 20)
        end
        
        toggleBtn:SetFrameStrata("TOOLTIP")
        toggleBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
        toggleBtn:SetText("Dave's Sell")
        
        toggleBtn:SetScript("OnClick", function()
            BuildSellFrame(parent)
            if sellFrame:IsShown() then
                sellFrame:Hide()
            else
                sellFrame:Show()
            end
        end)
    end
    
    toggleBtn:Show()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        InjectToggleBtn()
    end
end)
