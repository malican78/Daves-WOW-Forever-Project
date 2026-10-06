-- =========================================================
-- Dave's Auctioner - Core & Database
-- =========================================================

local addonName, addonTable = ...

-- Initialize Database
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        DavesAuctionerDB = DavesAuctionerDB or {}
        DavesAuctionerDB.prices = DavesAuctionerDB.prices or {}
        
        -- Add to Dave's Mobile Menu if it exists
        if type(DavesMobileMenu_RegisterAddon) == "function" then
            -- Icon 133784 is typically a coin/gold icon in WoW
            DavesMobileMenu_RegisterAddon("DavesAuctioner", "Dave's Auctioner", 133784, function()
                print("|cff00ff00Dave's Auctioner:|r Open the Auction House to use scanning features!")
            end)
        end
    end
end)

-- Slash Commands
SLASH_DAVESAUCTIONER1 = "/dauction"
SlashCmdList["DAVESAUCTIONER"] = function(msg)
    if msg == "test" then
        DavesAuctionerDB = DavesAuctionerDB or {}
        DavesAuctionerDB.prices = DavesAuctionerDB.prices or {}
        DavesAuctionerDB.prices[2770] = 10545 -- Copper Ore = 1g 05s 45c
        DavesAuctionerDB.prices[2589] = 25000 -- Linen Cloth = 2g 50s 00c
        print("|cff00ff00Dave's Auctioner:|r Added test prices for Copper Ore and Linen Cloth.")
    else
        print("|cff00ff00Dave's Auctioner:|r Try '/dauction test' to insert test data.")
    end
end

-- Expose addonTable for internal file sharing
_G.DavesAuctioner = addonTable

-- Master UI Frame (Option 1 - Native Blizzard Tab Integration)
local ahEventFrame = CreateFrame("Frame")
ahEventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
ahEventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        local parent = AuctionHouseFrame or AuctionFrame
        if not parent or addonTable.MasterFrame then return end
        
        -- Create Master Frame Content Pane (Hides over default content)
        local masterFrame = CreateFrame("Frame", "DavesAuctionerMasterFrame", parent)
        masterFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -60)
        masterFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 30)
        masterFrame:SetFrameStrata("HIGH")
        masterFrame:SetFrameLevel(parent:GetFrameLevel() + 50)
        
        masterFrame:Hide()
        addonTable.MasterFrame = masterFrame
        
        -- Dave's AH Mode Switches
        local buyModeBtn = CreateFrame("Button", "DavesAuctionerBuyModeBtn", masterFrame, "UIPanelButtonTemplate")
        buyModeBtn:SetSize(80, 24)
        buyModeBtn:SetPoint("TOPLEFT", masterFrame, "TOPLEFT", 15, -15)
        buyModeBtn:SetText("Buy Mode")
        
        local sellModeBtn = CreateFrame("Button", "DavesAuctionerSellModeBtn", masterFrame, "UIPanelButtonTemplate")
        sellModeBtn:SetSize(80, 24)
        sellModeBtn:SetPoint("LEFT", buyModeBtn, "RIGHT", 5, 0)
        sellModeBtn:SetText("Sell Mode")
        
        addonTable.SetMode = function(mode)
            if mode == "BUY" then
                buyModeBtn:LockHighlight()
                sellModeBtn:UnlockHighlight()
                if addonTable.SearchBox then addonTable.SearchBox:Show() end
                if addonTable.SearchBtn then addonTable.SearchBtn:Show() end
                if addonTable.SnipeBtn then addonTable.SnipeBtn:Show() end
                if DavesAuctionerBuyFrame then DavesAuctionerBuyFrame:Show() end
                if DavesAuctionerAnalyticsFrame then DavesAuctionerAnalyticsFrame:Show() end
                if DavesAuctionerSellFrame then DavesAuctionerSellFrame:Hide() end
                if DavesAuctionerListingsFrame then DavesAuctionerListingsFrame:Hide() end
            else
                sellModeBtn:LockHighlight()
                buyModeBtn:UnlockHighlight()
                if addonTable.SearchBox then addonTable.SearchBox:Hide() end
                if addonTable.SearchBtn then addonTable.SearchBtn:Hide() end
                if addonTable.SnipeBtn then addonTable.SnipeBtn:Hide() end
                if DavesAuctionerBuyFrame then DavesAuctionerBuyFrame:Hide() end
                if DavesAuctionerAnalyticsFrame then DavesAuctionerAnalyticsFrame:Hide() end
                if DavesAuctionerSellFrame then DavesAuctionerSellFrame:Show() end
                if DavesAuctionerListingsFrame then DavesAuctionerListingsFrame:Show() end
            end
        end
        
        buyModeBtn:SetScript("OnClick", function() addonTable.SetMode("BUY") end)
        sellModeBtn:SetScript("OnClick", function() addonTable.SetMode("SELL") end)
        
        masterFrame:SetScript("OnShow", function()
            addonTable.SetMode("BUY") -- Default to Buy Mode
        end)
        
        -- Create a faux-tab button that works on all client versions without crashing
        local masterTab = CreateFrame("Button", "DavesAuctionerMasterTab", parent, "UIPanelButtonTemplate")
        masterTab:SetSize(100, 24)
        masterTab:SetText("Dave's AH")
        
        -- Anchor to the last known Retail AH tab, or fallback
        if parent.AuctionsTab then
            masterTab:SetPoint("LEFT", parent.AuctionsTab, "RIGHT", 5, 0)
        else
            masterTab:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 300, -28)
        end
        
        masterTab:SetScript("OnClick", function(self)
            -- Toggle functionality: If Dave's AH is already open, go back to default UI
            if masterFrame:IsShown() then
                masterFrame:Hide()
                
                -- Restore Retail UI
                if parent.BrowseResultsFrame then parent.BrowseResultsFrame:Show() end
                if parent.SearchBar then parent.SearchBar:Show() end
                if parent.CategoriesList then parent.CategoriesList:Show() end
                
                -- Restore Classic UI
                if AuctionFrameBrowse then AuctionFrameBrowse:Show() end
                
                -- Fire the script just in case to update state
                local firstTab = _G[parent:GetName() .. "Tab1"]
                if firstTab then
                    local onClick = firstTab:GetScript("OnClick")
                    if onClick then onClick(firstTab) end
                elseif parent.BuyTab then
                    local onClick = parent.BuyTab:GetScript("OnClick")
                    if onClick then onClick(parent.BuyTab) end
                end
                return
            end

            -- Hide standard Retail/Classic AH views when our tab is clicked
            if parent.BrowseResultsFrame then parent.BrowseResultsFrame:Hide() end
            if parent.ItemSellFrame then parent.ItemSellFrame:Hide() end
            if parent.CommoditiesSellFrame then parent.CommoditiesSellFrame:Hide() end
            if parent.AuctionsFrame then parent.AuctionsFrame:Hide() end
            if parent.BuyDialog then parent.BuyDialog:Hide() end
            
            -- Retail UI specific floating panels
            if parent.SearchBar then parent.SearchBar:Hide() end
            if parent.CategoriesList then parent.CategoriesList:Hide() end
            
            -- Classic AH frames
            if AuctionFrameBrowse then AuctionFrameBrowse:Hide() end
            if AuctionFrameBid then AuctionFrameBid:Hide() end
            if AuctionFrameAuctions then AuctionFrameAuctions:Hide() end
            
            -- Show our frame
            masterFrame:Show()
        end)
        
        -- Hook standard Retail AH tabs to hide our frame when clicked
        if parent.BuyTab then parent.BuyTab:HookScript("OnClick", function() masterFrame:Hide() end) end
        if parent.SellTab then parent.SellTab:HookScript("OnClick", function() masterFrame:Hide() end) end
        if parent.AuctionsTab then parent.AuctionsTab:HookScript("OnClick", function() masterFrame:Hide() end) end
        
        -- Hook standard Classic AH tabs
        for i = 1, 4 do
            local tab = _G[parent:GetName() .. "Tab" .. i]
            if tab and tab ~= masterTab then
                tab:HookScript("OnClick", function()
                    masterFrame:Hide()
                end)
            end
        end
        
    end
end)
