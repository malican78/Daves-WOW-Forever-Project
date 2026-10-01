local addonName, addon = ...

-- =========================================================
-- Theme & Color Palette (Matched to Dave's Notes)
-- =========================================================
local WINDOW_COLOR = { 0.73, 0.60, 0.37 }
local WINDOW_BORDER_COLOR = { 0.48, 0.36, 0.22 }
local GOLD_TEXT_COLOR = { 1, 0.82, 0.30 }
local MUTED_GOLD_COLOR = { 0.95, 0.82, 0.48 }

local BUTTON_SIZE = 37
local BUTTON_SPACING = 4
local COLS = 10
local PADDING = 12
local HEADER_HEIGHT = 38
local FOOTER_HEIGHT = 32 -- Increased from 24 to fit suite shortcuts nicely
local SECTION_HEADER_HEIGHT = 18

-- View States
local isCategoryView = false
local isShowingBank = false

-- Database Initialization
DavesBagsDB = DavesBagsDB or {}
DavesBagsDB.bankCache = DavesBagsDB.bankCache or {}

-- =========================================================
-- Theme Helper Functions
-- =========================================================
local function setTextureColor(texture, r, g, b, a)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r, g, b, a or 1)
end

local function createBorder(frame, color, thickness)
    thickness = thickness or 2
    local top = frame:CreateTexture(nil, "BORDER")
    setTextureColor(top, color[1], color[2], color[3], 1)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT")
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    top:SetHeight(thickness)

    local bottom = frame:CreateTexture(nil, "BORDER")
    setTextureColor(bottom, color[1], color[2], color[3], 1)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    bottom:SetHeight(thickness)

    local left = frame:CreateTexture(nil, "BORDER")
    setTextureColor(left, color[1], color[2], color[3], 1)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    left:SetWidth(thickness)

    local right = frame:CreateTexture(nil, "BORDER")
    setTextureColor(right, color[1], color[2], color[3], 1)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    right:SetWidth(thickness)
end

local function applyWindowBackground(frame)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    frame.background:SetAllPoints(frame)
    if frame.background.SetHorizTile then frame.background:SetHorizTile(true) end
    if frame.background.SetVertTile then frame.background:SetVertTile(true) end
end

local function registerEscapeFrame(frameName)
    UISpecialFrames = UISpecialFrames or {}
    for index = 1, #UISpecialFrames do
        if UISpecialFrames[index] == frameName then return end
    end
    table.insert(UISpecialFrames, frameName)
end

local function FormatMoneyString(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    elseif GetMoneyString then
        return GetMoneyString(copper, true)
    end

    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%dg %ds %dc", g, s, c)
end

-- =========================================================================
-- Dave's Bags: Trash Grays Core Logic & Confirmation Popup
-- =========================================================================
local function DeleteAllGrayItems()
    local deletedCount = 0

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and (info.quality == Enum.ItemQuality.Poor or info.quality == 0) and not info.isLocked then
                C_Container.PickupContainerItem(bag, slot)
                DeleteCursorItem()
                deletedCount = deletedCount + 1
            end
        end
    end

    if deletedCount > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[Dave's Bags]|r Trashed %d gray item(s).", deletedCount))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[Dave's Bags]|r No gray items found.")
    end
end

StaticPopupDialogs["DAVESBAGS_CONFIRM_TRASH_GRAYS"] = {
    text = "Are you sure you want to delete ALL gray items in your bags?\n|cffff2020This cannot be undone!|r",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        DeleteAllGrayItems()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- =========================================================
-- Main Frame Setup
-- =========================================================
local BagFrame = CreateFrame("Frame", "DavesBagsFrame", UIParent)
BagFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
BagFrame:SetFrameStrata("DIALOG")
BagFrame:SetToplevel(true)
BagFrame:SetMovable(true)
BagFrame:EnableMouse(true)
BagFrame:SetClampedToScreen(true)
BagFrame:Hide()

applyWindowBackground(BagFrame)
createBorder(BagFrame, WINDOW_BORDER_COLOR, 3)
registerEscapeFrame("DavesBagsFrame")

BagFrame:SetScript("OnMouseDown", function()
    BagFrame:Raise()
end)

-- Header Panel
local header = CreateFrame("Frame", nil, BagFrame)
header:SetPoint("TOPLEFT", BagFrame, "TOPLEFT", 4, -4)
header:SetPoint("TOPRIGHT", BagFrame, "TOPRIGHT", -4, -4)
header:SetHeight(HEADER_HEIGHT)
applyWindowBackground(header)
createBorder(header, WINDOW_BORDER_COLOR, 2)

header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnMouseDown", function() BagFrame:Raise() end)
header:SetScript("OnDragStart", function() BagFrame:Raise(); BagFrame:StartMoving() end)
header:SetScript("OnDragStop", function() BagFrame:StopMovingOrSizing() end)

-- Title
local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", header, "TOPLEFT", 12, -6)
title:SetText("Dave's Bags")
title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])

-- Free Slots / Capacity Label
local slotCountLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
slotCountLabel:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 12, 5)
slotCountLabel:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])

-- Close Button
local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
closeBtn:SetScript("OnClick", function() BagFrame:Hide() end)

-- "Sell Junk" Button (Visible only at merchants)
local sellJunkBtn = CreateFrame("Button", "DavesBagsSellJunkBtn", header, "UIPanelButtonTemplate")
sellJunkBtn:SetSize(70, 22)
sellJunkBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
sellJunkBtn:SetText("Sell Junk")
sellJunkBtn:Hide()

-- "Category View" Toggle Button
local categoryToggleBtn = CreateFrame("Button", "DavesBagsCategoryBtn", header, "UIPanelButtonTemplate")
categoryToggleBtn:SetSize(92, 22)
categoryToggleBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
categoryToggleBtn:SetText("Category View")

-- "View Bank" / "View Bags" Toggle Button
local bankToggleBtn = CreateFrame("Button", "DavesBagsBankBtn", header, "UIPanelButtonTemplate")
bankToggleBtn:SetSize(80, 22)
bankToggleBtn:SetPoint("RIGHT", categoryToggleBtn, "LEFT", -4, 0)
bankToggleBtn:SetText("View Bank")

-- "Trash Grays" Button
local trashGraysBtn = CreateFrame("Button", "DavesBagsTrashGraysBtn", header, "UIPanelButtonTemplate")
trashGraysBtn:SetSize(80, 22)
trashGraysBtn:SetPoint("RIGHT", bankToggleBtn, "LEFT", -4, 0)
trashGraysBtn:SetText("Trash Grays")

trashGraysBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Trash Grays", 1, 1, 1)
    GameTooltip:AddLine("Permanently destroys all poor-quality (gray) items in your bags.", 1, 0.8, 0, true)
    GameTooltip:Show()
end)

trashGraysBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

trashGraysBtn:SetScript("OnClick", function()
    StaticPopup_Show("DAVESBAGS_CONFIRM_TRASH_GRAYS")
end)

-- =========================================================
-- Footer & Money Balance Display
-- =========================================================
local footer = CreateFrame("Frame", nil, BagFrame)
footer:SetPoint("BOTTOMLEFT", BagFrame, "BOTTOMLEFT", 4, 4)
footer:SetPoint("BOTTOMRIGHT", BagFrame, "BOTTOMRIGHT", -4, 4)
footer:SetHeight(FOOTER_HEIGHT)
applyWindowBackground(footer)
createBorder(footer, WINDOW_BORDER_COLOR, 2)

local moneyText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
moneyText:SetPoint("RIGHT", footer, "RIGHT", -10, 0)
moneyText:SetJustifyH("RIGHT")

local function UpdateMoneyDisplay()
    local copper = GetMoney() or 0
    moneyText:SetText(FormatMoneyString(copper))
end

local function SellAllJunk()
    local totalProfit = 0
    local soldCount = 0

    for bagID = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slotID = 1, numSlots do
            local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if containerInfo and not containerInfo.isLocked then
                if containerInfo.quality == Enum.ItemQuality.Poor or containerInfo.quality == 0 then
                    local itemPrice = select(11, C_Item.GetItemInfo(containerInfo.itemID)) or 0
                    if itemPrice > 0 then
                        C_Container.UseContainerItem(bagID, slotID)
                        totalProfit = totalProfit + (itemPrice * (containerInfo.stackCount or 1))
                        soldCount = soldCount + 1
                    end
                end
            end
        end
    end

    if soldCount > 0 and totalProfit > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Bags]|r Sold " .. soldCount .. " junk items for " .. FormatMoneyString(totalProfit) .. ".")
    elseif soldCount == 0 then
