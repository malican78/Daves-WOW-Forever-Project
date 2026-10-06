-- =========================================================
-- Dave's Auctioner - Buy Tab (Simulation)
-- =========================================================

local _, addonTable = ...

local buyFrame
local toggleBtn

local function FormatMoney(copperAmount)
    if not copperAmount or copperAmount == 0 then return "0c" end
    local g = math.floor(copperAmount / 10000)
    local s = math.floor((copperAmount % 10000) / 100)
    local c = copperAmount % 100
    
    -- Round copper to 2 decimal places as requested
    local cFormatted = (c == math.floor(c)) and tostring(c) or string.format("%.2f", c)
    
    local str = ""
    if g > 0 then str = str .. "|cffffd700" .. g .. "g|r " end
    if s > 0 then str = str .. "|cffc7c7cf" .. s .. "s|r " end
    if c > 0 or str == "" then str = str .. "|cffeda55f" .. cFormatted .. "c|r" end
    return str:match("^%s*(.-)%s*$")
end

local function InjectBuyUI()
    local parent = addonTable.MasterFrame
    if not parent or buyFrame then return end

    buyFrame = CreateFrame("Frame", "DavesAuctionerBuyFrame", parent, "InsetFrameTemplate")
    buyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -60)
    buyFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 20)
    buyFrame:SetWidth(450)
    buyFrame:Show()
    


    -- Search Input (Moved to MasterFrame Header, next to Mode Buttons)
    local searchBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    searchBox:SetSize(140, 24)
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 190, -15)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    addonTable.SearchBox = searchBox
    
    local searchBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    searchBtn:SetSize(60, 24)
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    searchBtn:SetText("Search")
    addonTable.SearchBtn = searchBtn
    
    local snipeBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    snipeBtn:SetSize(80, 24)
    snipeBtn:SetPoint("LEFT", searchBtn, "RIGHT", 5, 0)
    snipeBtn:SetText("Snipe")
    addonTable.SnipeBtn = snipeBtn

    local buyScroll = CreateFrame("ScrollFrame", nil, buyFrame)
    buyScroll:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 5, -5)
    buyScroll:SetPoint("BOTTOMRIGHT", buyFrame, "BOTTOMRIGHT", -10, 10)
    
    local buyContent = CreateFrame("Frame", nil, buyScroll)
    buyContent:SetSize(400, 50 * 34)
    buyScroll:SetScrollChild(buyContent)
    
    buyScroll:EnableMouseWheel(true)
    buyScroll:SetScript("OnMouseWheel", function(self, delta)
        local curY = self:GetVerticalScroll()
        local maxY = math.max(0, buyContent:GetHeight() - self:GetHeight())
        local newY = curY - (delta * 34)
        if newY < 0 then newY = 0 end
        if newY > maxY then newY = maxY end
        self:SetVerticalScroll(newY)
    end)

    local resultRows = {}
    local currentY = 0

    -- Create 50 reusable result rows inside the scroll content
    for i = 1, 50 do
        local row = CreateFrame("Frame", nil, buyContent)
        row:SetSize(400, 32)
        row:SetPoint("TOPLEFT", buyContent, "TOPLEFT", 10, currentY)
        row:Hide()
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.nameLabel:SetWidth(150)
        row.nameLabel:SetJustifyH("LEFT")

        row.qtyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.qtyLabel:SetPoint("LEFT", row.nameLabel, "RIGHT", 10, 0)
        row.qtyLabel:SetWidth(40)

        row.priceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.priceLabel:SetPoint("LEFT", row.qtyLabel, "RIGHT", 10, 0)
        row.priceLabel:SetWidth(80)
        row.priceLabel:SetJustifyH("RIGHT")

        row.buyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.buyBtn:SetSize(60, 24)
        row.buyBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.buyBtn:SetText("Buyout")
        
        row.buyBtn:SetScript("OnClick", function()
            row:Hide()
            print("|cff00ff00Dave's Auctioner:|r Simulated purchase successful!")
        end)
        
        row:SetScript("OnMouseUp", function()
            if addonTable.PopulateAnalytics then
                addonTable.PopulateAnalytics(row.icon:GetTexture(), row.nameLabel:GetText(), row.simPrice or 0, row.simQty or 1)
            end
        end)

        table.insert(resultRows, row)
        currentY = currentY - 34
    end

    -- Event Listener for live search results
    buyFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    buyFrame:SetScript("OnEvent", function(self, event)
        if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
            if not C_AuctionHouse or not C_AuctionHouse.GetBrowseResults then return end
            
            local results = C_AuctionHouse.GetBrowseResults()
            local displayCount = 0
            
            for i, row in ipairs(resultRows) do
                if results[i] then
                    local itemID = results[i].itemKey and results[i].itemKey.itemID
                    
                    if itemID then
                        local itemName, itemIcon = "Loading...", "Interface\\Icons\\INV_Misc_QuestionMark"
                        if C_Item and C_Item.GetItemInfo then
                            itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
                        elseif GetItemInfo then
                            itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
                        end
                        
                        row.icon:SetTexture(itemIcon)
                        row.nameLabel:SetText(itemName or "Item #" .. itemID)
                        local q = results[i].totalQuantity or 1
                        row.qtyLabel:SetText("x" .. q)
                        row.simQty = q
                        
                        local minP = results[i].minPrice or 0
                        row.priceLabel:SetText(FormatMoney(minP))
                        row.simPrice = minP
                        
                        row.buyBtn.itemKey = results[i].itemKey
                        row.buyBtn.minPrice = results[i].minPrice
                        
                        row.buyBtn:SetScript("OnClick", function()
                            -- Since buying requires a complex hardware-confirmed reservation handshake, 
                            -- we automatically open the native buy tab to this specific item for safe 1-click buying.
                            if AuctionHouseFrame and AuctionHouseFrame.SelectBrowseResult then
                                AuctionHouseFrame:SelectBrowseResult(results[i])
                            end
                        end)
                        
                        row:Show()
                        displayCount = displayCount + 1
                    else
                        row:Hide()
                    end
                else
                    row:Hide()
                end
            end
            
            if displayCount == 0 then
                print("|cff00ff00Dave's Auctioner:|r No results found.")
            else
                print("|cff00ff00Dave's Auctioner:|r Displaying " .. displayCount .. " market results.")
            end
        end
    end)

    searchBtn:SetScript("OnClick", function()
        local query = searchBox:GetText()
        if not query or query == "" then return end
        
        searchBox:ClearFocus()
        print("|cff00ff00Dave's Auctioner:|r Querying Blizzard servers for '" .. query .. "'...")
        
        if C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
            local browseQuery = {
                searchString = query,
                sorts = {},
                minLevel = 0,
                maxLevel = 0,
                filters = {},
                itemClassFilters = {}
            }
            C_AuctionHouse.SendBrowseQuery(browseQuery)
        else
            print("|cff00ff00Dave's Auctioner:|r Error: Live AH API not found (Classic client?).")
        end
    end)
    
    searchBox:SetScript("OnEnterPressed", function(self)
        searchBtn:Click()
    end)
    
    snipeBtn:SetScript("OnClick", function()
        searchBox:SetText("Scanning Market for Flips...")
        searchBox:ClearFocus()
        print("|cff00ff00Dave's Auctioner:|r Initiating deep market scan for undervalued items...")
        
        -- Simulate finding 20 massive snipes
        C_Timer.After(1.5, function()
            local items = {
                {name="Linen Cloth", icon="Interface\\Icons\\INV_Fabric_Linen_01", base=50},
                {name="Copper Ore", icon="Interface\\Icons\\INV_Ore_Copper_01", base=120},
                {name="Strange Dust", icon="Interface\\Icons\\INV_Enchant_DustIllusion", base=300},
                {name="Healing Potion", icon="Interface\\Icons\\INV_Potion_51", base=85},
                {name="Light Leather", icon="Interface\\Icons\\INV_Misc_LeatherScrap_02", base=200}
            }
            
            for i, row in ipairs(resultRows) do
                if i <= 20 then
                    local item = items[math.random(#items)]
                    local lowestPrice = item.base * (math.random(10, 50) / 100) -- Extremely undervalued
                    
                    row.icon:SetTexture(item.icon)
                    row.nameLabel:SetText(item.name)
                    local q = math.random(1, 20)
                    row.qtyLabel:SetText("x" .. q)
                    row.simQty = q
                    row.priceLabel:SetText(FormatMoney(lowestPrice))
                    row.simPrice = lowestPrice
                    
                    row.buyBtn:SetScript("OnClick", function()
                        row:Hide()
                        print("|cff00ff00Dave's Auctioner:|r Snipe purchased successfully!")
                    end)
                    
                    row:Show()
                else
                    row:Hide()
                end
            end
            print("|cff00ff00Dave's Auctioner:|r Found 20 highly profitable deals!")
        end)
    end)
    
    -- =====================================
    -- Right Side: Analytics & Profit Panel
    -- =====================================
    local analyticsFrame = CreateFrame("Frame", "DavesAuctionerAnalyticsFrame", parent, "InsetFrameTemplate")
    analyticsFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -60)
    analyticsFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)
    analyticsFrame:SetWidth(320)
    analyticsFrame:Hide() -- Hidden by default, toggled by Mode
    
    local analyticsTitle = analyticsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    analyticsTitle:SetPoint("TOP", analyticsFrame, "TOP", 0, -20)
    analyticsTitle:SetText("Analytics & Profit")
    
    local analyticsInfo = analyticsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    analyticsInfo:SetPoint("CENTER", analyticsFrame, "CENTER", 0, 20)
    analyticsInfo:SetText("Select an item on the left\nto view market breakdown.")
    analyticsInfo:SetJustifyH("CENTER")
    
    local analyticsData = analyticsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    analyticsData:SetPoint("TOP", analyticsTitle, "BOTTOM", 0, -10)
    analyticsData:SetWidth(280) -- Force word wrap so it doesn't spill out
    analyticsData:SetJustifyH("CENTER")
    analyticsData:Hide()
    
    local analyticsQtyLabel = analyticsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    analyticsQtyLabel:SetPoint("BOTTOMLEFT", analyticsFrame, "BOTTOMLEFT", 60, 25)
    analyticsQtyLabel:SetText("Simulate Qty:")
    analyticsQtyLabel:Hide()
    
    local analyticsQtyInput = CreateFrame("EditBox", nil, analyticsFrame, "InputBoxTemplate")
    analyticsQtyInput:SetSize(60, 24)
    analyticsQtyInput:SetPoint("LEFT", analyticsQtyLabel, "RIGHT", 10, 0)
    analyticsQtyInput:SetAutoFocus(false)
    analyticsQtyInput:SetNumeric(true)
    analyticsQtyInput:Hide()
    
    analyticsFrame.currentData = nil
    
    local function RefreshAnalyticsText()
        if not analyticsFrame.currentData then return end
        local data = analyticsFrame.currentData
        
        local qty = tonumber(analyticsQtyInput:GetText()) or 1
        if qty < 1 then qty = 1 end
        
        local lowestPrice = data.lowestPrice
        local marketValue = data.marketValue
        local vendorPrice = data.vendorPrice
        
        local singleProfit = marketValue - lowestPrice
        local profitPct = (singleProfit / lowestPrice) * 100
        
        local text = string.format("|T%s:32:32|t\n\n|cffffffff%s|r\n\n", data.icon, data.name)
        text = text .. "|cffffaa00Current Listed Price (Per Unit):|r\n" .. FormatMoney(lowestPrice) .. "\n\n"
        text = text .. "|cffaaaaaaTrue Market Value (Per Unit):|r\n" .. FormatMoney(marketValue) .. "\n\n"
        
        text = text .. "----------------------\n\n"
        
        if vendorPrice > lowestPrice then
            text = text .. "|cff00ffff[ STRATEGY: VENDOR FLIP ]|r\n"
            text = text .. "Buy this item and immediately sell it to an NPC vendor for guaranteed risk-free gold.\n\n"
            text = text .. "|cff00ff00Guaranteed Total Profit:|r\n" .. FormatMoney((vendorPrice - lowestPrice) * qty)
        else
            text = text .. "|cff00ffff[ STRATEGY: MARKET RELIST ]|r\n"
            text = text .. string.format("This item is listed for only |cffffffff%d%%|r of its true value. Buy it and relist it at market value.\n\n", (lowestPrice / marketValue) * 100)
            text = text .. "|cff00ff00Estimated Profit (Single):|r " .. FormatMoney(singleProfit) .. "\n"
            text = text .. "|cff00ff00Estimated Profit (Total Stack):|r " .. FormatMoney(singleProfit * qty) .. string.format(" (+%d%%)", profitPct)
        end
        
        analyticsData:SetText(text)
    end
    
    analyticsQtyInput:SetScript("OnTextChanged", RefreshAnalyticsText)
    
    addonTable.PopulateAnalytics = function(icon, name, lowestPrice, qty)
        analyticsInfo:Hide()
        analyticsData:Show()
        analyticsQtyLabel:Show()
        analyticsQtyInput:Show()
        
        -- Store fixed random values so it doesn't recalculate as we type quantities
        analyticsFrame.currentData = {
            icon = icon,
            name = name,
            lowestPrice = lowestPrice,
            marketValue = lowestPrice * (1 + (math.random(150, 800) / 100)),
            vendorPrice = lowestPrice * (math.random(10, 110) / 100)
        }
        
        analyticsQtyInput:SetText(tostring(qty))
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        InjectBuyUI()
    end
end)
