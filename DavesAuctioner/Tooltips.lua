-- =========================================================
-- Dave's Auctioner - Item Tooltips
-- =========================================================

local addonName, addonTable = ...

-- Custom Money Formatter for clean display
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
    return str:match("^%s*(.-)%s*$") -- Trim whitespace
end

-- Core Tooltip Logic
local function OnTooltipSetItem(tooltip, data)
    if not DavesAuctionerDB or not DavesAuctionerDB.prices then return end

    local itemID
    if data and data.id then
        itemID = data.id
    elseif tooltip and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if link then
            itemID = tonumber(link:match("item:(%d+)"))
        end
    end

    if not itemID then return end

    local price = DavesAuctionerDB.prices[itemID]
    if price and price > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("|cff44ff44Dave's AH Price:|r", FormatMoney(price))
    end
end

-- Hooking into the game's tooltip system
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    -- Modern WoW API (Dragonflight/The War Within)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        OnTooltipSetItem(tooltip, data)
    end)
else
    -- Classic / Older WoW API fallback
    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) OnTooltipSetItem(tooltip) end)
    end
    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip) OnTooltipSetItem(tooltip) end)
    end
end
