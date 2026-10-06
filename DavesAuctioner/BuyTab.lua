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
    
    local str = ""
    if g > 0 then str = str .. "|cffffd700" .. g .. "g|r " end
    if s > 0 then str = str .. "|cffc7c7cf" .. s .. "s|r " end
    if c > 0 or str == "" then str = str .. "|cffeda55f" .. c .. "c|r" end
    return str:match("^%s*(.-)%s*$")
end

local function InjectBuyUI()
    local parent = addonTable.MasterFrame
    if not parent or buyFrame then return end

    buyFrame = CreateFrame("Frame", "DavesAuctionerBuyFrame", parent)
    buyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    buyFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    buyFrame:SetWidth(450)
    buyFrame:Show()
    
    buyFrame.bg = buyFrame:CreateTexture(nil, "BACKGROUND")
    buyFrame.bg:SetAllPoints()
    buyFrame.bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)

    -- Search Input
    local searchBox = CreateFrame("EditBox", nil, buyFrame, "InputBoxTemplate")
    searchBox:SetSize(250, 30)
    searchBox:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 30, -30)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    
    local searchBtn = CreateFrame("Button", nil, buyFrame, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 26)
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    searchBtn:SetText("Search")

    -- Results Area
    local resultsTitle = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    resultsTitle:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -10, -20)
    resultsTitle:SetText("Shopping Results (Simulation)")

    local resultRows = {}
    local currentY = -100

    -- Create 10 reusable result rows
    for i = 1, 10 do
        local row = CreateFrame("Frame", nil, buyFrame)
        row:SetSize(600, 32)
        row:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 30, currentY)
        row:Hide()
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.nameLabel:SetWidth(200)
        row.nameLabel:SetJustifyH("LEFT")

        row.qtyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.qtyLabel:SetPoint("LEFT", row.nameLabel, "RIGHT", 10, 0)
        row.qtyLabel:SetWidth(50)

        row.priceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.priceLabel:SetPoint("LEFT", row.qtyLabel, "RIGHT", 10, 0)
        row.priceLabel:SetWidth(150)
        row.priceLabel:SetJustifyH("RIGHT")

        row.buyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.buyBtn:SetSize(70, 24)
        row.buyBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.buyBtn:SetText("Buyout")
        
        row.buyBtn:SetScript("OnClick", function()
            row:Hide()
            print("|cff00ff00Dave's Auctioner:|r Simulated purchase successful!")
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
                        row.qtyLabel:SetText("x" .. (results[i].totalQuantity or 1))
                        row.priceLabel:SetText(FormatMoney(results[i].minPrice or 0))
                        
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
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        InjectBuyUI()
    end
end)
