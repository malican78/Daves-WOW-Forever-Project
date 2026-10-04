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
