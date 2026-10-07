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
local isCategoryView = true
local isShowingBank = false

-- Forward Declarations
local UpdateBagGrid
local SellAllJunk
local UpdateBagActionsMenu

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

-- Actions Dropdown Menu Button
local menuBtn = CreateFrame("Button", "DavesBagsMenuBtn", header, "UIPanelButtonTemplate")
menuBtn:SetSize(74, 22)
menuBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
menuBtn:SetText("Actions v")

-- Actions Dropdown Menu Frame
local bagActionsMenu = CreateFrame("Frame", nil, BagFrame)
bagActionsMenu:SetSize(165, 96)
bagActionsMenu:SetPoint("TOPRIGHT", menuBtn, "BOTTOMRIGHT", 0, -2)
bagActionsMenu:SetFrameStrata("FULLSCREEN_DIALOG")
bagActionsMenu:SetToplevel(true)
bagActionsMenu:SetFrameLevel(250)
bagActionsMenu:EnableMouse(true)

bagActionsMenu.solidBg = bagActionsMenu:CreateTexture(nil, "BACKGROUND", nil, -8)
setTextureColor(bagActionsMenu.solidBg, 0.98, 0.95, 0.86, 1.0)
bagActionsMenu.solidBg:SetAllPoints(bagActionsMenu)
createBorder(bagActionsMenu, WINDOW_BORDER_COLOR, 2)
bagActionsMenu:Hide()

local function CreateBagMenuItem(parent, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(155, 20)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    setTextureColor(btn.highlight, 0.85, 0.70, 0.40, 0.4)
    btn.highlight:SetAllPoints(btn)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetWordWrap(false)
    btn.text:SetTextColor(0.12, 0.09, 0.05)

    btn:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
    end)
    function btn:SetText(t)
        self.text:SetText(t)
    end
    function btn:GetText()
        return self.text:GetText()
    end
    return btn
end

local categoryToggleBtn = CreateBagMenuItem(bagActionsMenu, -5, function()
    isCategoryView = not isCategoryView
    DavesBagsDB.isCategoryView = isCategoryView
    bagActionsMenu:Hide()
    UpdateBagGrid()
    UpdateBagActionsMenu()
end)

local bankToggleBtn = CreateBagMenuItem(bagActionsMenu, -27, function()
    isShowingBank = not isShowingBank
    bagActionsMenu:Hide()
    UpdateBagGrid()
    UpdateBagActionsMenu()
end)

local trashGraysBtn = CreateBagMenuItem(bagActionsMenu, -49, function()
    bagActionsMenu:Hide()
    StaticPopup_Show("DAVESBAGS_CONFIRM_TRASH_GRAYS")
end)

trashGraysBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Trash Grays", 1, 1, 1)
    GameTooltip:AddLine("Permanently destroys all poor-quality (gray) items in your bags.", 1, 0.8, 0, true)
    GameTooltip:Show()
end)
trashGraysBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local sellJunkBtn = CreateBagMenuItem(bagActionsMenu, -71, function()
    bagActionsMenu:Hide()
    if SellAllJunk then SellAllJunk() end
end)

function UpdateBagActionsMenu()
    categoryToggleBtn.text:SetText(isCategoryView and "• Slot View" or "• Category View")
    bankToggleBtn.text:SetText(isShowingBank and "• View Bags" or "• View Bank")
    trashGraysBtn.text:SetText("• Trash Grays")

    local atMerchant = MerchantFrame and MerchantFrame:IsShown()
    if atMerchant then
        sellJunkBtn.text:SetText("|cff008800• Sell Junk (Vendor)|r")
        sellJunkBtn:Enable()
    else
        sellJunkBtn.text:SetText("|cff888888• Sell Junk (Vendor)|r")
        sellJunkBtn:Disable()
    end
end

menuBtn:SetScript("OnEnter", function()
    UpdateBagActionsMenu()
    bagActionsMenu:Show()
end)

bagActionsMenu:SetScript("OnUpdate", function(self)
    if not (self:IsMouseOver() or menuBtn:IsMouseOver()) then
        self:Hide()
    end
end)

BagFrame:HookScript("OnHide", function()
    bagActionsMenu:Hide()
end)
BagFrame:HookScript("OnMouseDown", function()
    bagActionsMenu:Hide()
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

-- =========================================================
-- Footer Menu Dock (Dave's Suite Shortcuts & Utilities)
-- =========================================================
local footerMenuButtons = {}
local activeFooterButtons = {}
local FOOTER_BTN_SIZE = 22
local FOOTER_BTN_SPACING = 5

function DavesBags_RegisterMenuButton(id, title, icon, toggleFunc, desc)
    for _, item in ipairs(footerMenuButtons) do
        if item.id == id then
            item.title = title
            item.icon = icon
            item.toggleFunc = toggleFunc
            item.desc = desc
            if BagFrame and BagFrame.UpdateFooterMenu then
                BagFrame:UpdateFooterMenu()
            end
            return
        end
    end

    table.insert(footerMenuButtons, {
        id = id,
        title = title,
        icon = icon,
        toggleFunc = toggleFunc,
        desc = desc
    })

    if BagFrame and BagFrame.UpdateFooterMenu then
        BagFrame:UpdateFooterMenu()
    end
end

-- Provide cross-addon compatibility with DavesMobileMenu
if not DavesMobileMenu_RegisterAddon then
    DavesMobileMenu_RegisterAddon = function(id, title, icon, toggleFunc, desc)
        if id ~= "DavesBags" then
            DavesBags_RegisterMenuButton(id, title, icon, toggleFunc, desc)
        end
    end
end

function BagFrame:UpdateFooterMenu()
    local leftOffset = 8
    for i = 1, #footerMenuButtons do
        local data = footerMenuButtons[i]
        local btn = activeFooterButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, footer)
            btn:SetSize(FOOTER_BTN_SIZE, FOOTER_BTN_SIZE)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(btn)

            btn.border = btn:CreateTexture(nil, "OVERLAY")
            btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            btn.border:SetBlendMode("ADD")
            btn.border:SetAlpha(0.6)
            btn.border:SetPoint("TOPLEFT", btn, -3, 3)
            btn.border:SetPoint("BOTTOMRIGHT", btn, 3, -3)

            btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(btn.highlight, 1, 0.82, 0.30, 0.25)
            btn.highlight:SetAllPoints(btn)

            btn:SetScript("OnEnter", function(self)
                if not self.data then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.data.title, 1, 0.82, 0)
                if self.data.desc and self.data.desc ~= "" then
                    GameTooltip:AddLine(self.data.desc, 0.95, 0.82, 0.48)
                end
                GameTooltip:AddLine("<Click to Open>", 0.5, 0.8, 1)
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            btn:SetScript("OnClick", function(self)
                if self.data and type(self.data.toggleFunc) == "function" then
                    self.data.toggleFunc()
                end
            end)

            activeFooterButtons[i] = btn
        end

        btn.data = data
        btn.icon:SetTexture(data.icon or 134400)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", footer, "LEFT", leftOffset, 0)
        btn:Show()

        leftOffset = leftOffset + FOOTER_BTN_SIZE + FOOTER_BTN_SPACING
    end

    for i = #footerMenuButtons + 1, #activeFooterButtons do
        activeFooterButtons[i]:Hide()
    end
end

local function RegisterDefaultFooterAddons()
    local function isLoaded(name)
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            return C_AddOns.IsAddOnLoaded(name)
        elseif IsAddOnLoaded then
            return IsAddOnLoaded(name)
        end
        return false
    end

    local function safeToggle(name, slashKey)
        if C_AddOns and C_AddOns.LoadAddOn and not (C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)) then
            pcall(C_AddOns.LoadAddOn, name)
        end
        if SlashCmdList and slashKey and SlashCmdList[slashKey] then
            SlashCmdList[slashKey]("")
        end
    end

    -- 1. Bag Cleanup / Auto-Sort
    DavesBags_RegisterMenuButton("SortBags", "Sort Bags", 133644, function()
        if InCombatLockdown and InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[Dave's Bags]|r Cannot sort bags while in combat.")
            return
        end
        if C_Container and C_Container.SortBags then
            C_Container.SortBags()
        elseif SortBags then
            SortBags()
        end
    end, "Organize and defragment all bag slots.")

    -- 2. Dave's Notes
    if isLoaded("DavesNotes") or (SlashCmdList and SlashCmdList["DAVESNOTES"]) then
        DavesBags_RegisterMenuButton("DavesNotes", "Dave's Notes", 134331, function()
            safeToggle("DavesNotes", "DAVESNOTES")
        end, "Open notepad and journal.")
    end

    -- 3. Dave's Gather
    if isLoaded("DavesGather") or (SlashCmdList and SlashCmdList["DAVESGATHER"]) then
        DavesBags_RegisterMenuButton("DavesGather", "Dave's Gather", 134440, function()
            safeToggle("DavesGather", "DAVESGATHER")
        end, "Open gathering tracker and hotspot browser.")
    end

    -- 4. Dave's Quests
    if isLoaded("DavesQuests") or (SlashCmdList and SlashCmdList["DAVESQUESTS"]) then
        DavesBags_RegisterMenuButton("DavesQuests", "Dave's Quests", 133872, function()
            safeToggle("DavesQuests", "DAVESQUESTS")
        end, "Open quest tracker settings.")
    end

    -- 5. Dave's Mobile Frames
    if isLoaded("DavesMobileFrames") or (SlashCmdList and SlashCmdList["DAVESMOBILEFRAMES"]) then
        DavesBags_RegisterMenuButton("DavesMobileFrames", "Dave's Mobile Frames", 132147, function()
            safeToggle("DavesMobileFrames", "DAVESMOBILEFRAMES")
        end, "Reset movable frame anchors.")
    end

    -- 6. Dave's Mobile Menu (if installed)
    if isLoaded("DavesMobileMenu") or (SlashCmdList and SlashCmdList["DAVESMOBILEMENU"]) then
        DavesBags_RegisterMenuButton("DavesMobileMenu", "Dave's Mobile Menu", 134939, function()
            safeToggle("DavesMobileMenu", "DAVESMOBILEMENU")
        end, "Toggle on-screen dock launcher.")
    end

    -- 7. Dave's Wallet
    if isLoaded("DavesWallet") or (SlashCmdList and SlashCmdList["DAVESWALLET"]) then
        DavesBags_RegisterMenuButton("DavesWallet", "Dave's Wallet", 133784, function()
            safeToggle("DavesWallet", "DAVESWALLET")
        end, "Track session incoming and outgoing gold/silver/copper.")
    end
end

function SellAllJunk()
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Bags]|r No grey items to sell.")
    end
end

-- =========================================================
-- Bank Snapshot Caching
-- =========================================================
local BANK_CONTAINERS = { -1, 6, 7, 8, 9, 10, 11, 12 }

local function CacheBankItems()
    local cache = {}
    local total = 0
    local free = 0

    for _, bagID in ipairs(BANK_CONTAINERS) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            local numFree = C_Container.GetContainerNumFreeSlots(bagID)
            free = free + (numFree or 0)

            for slotID = 1, numSlots do
                total = total + 1
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                local link = C_Container.GetContainerItemLink(bagID, slotID)

                if info then
                    table.insert(cache, {
                        bagID = bagID,
                        slotID = slotID,
                        link = link,
                        iconFileID = info.iconFileID,
                        stackCount = info.stackCount,
                        quality = info.quality,
                        itemID = info.itemID,
                        hasItem = true
                    })
                else
                    table.insert(cache, {
                        bagID = bagID,
                        slotID = slotID,
                        hasItem = false
                    })
                end
            end
        end
    end

    DavesBagsDB.bankCache = cache
    DavesBagsDB.bankTotalSlots = total
    DavesBagsDB.bankFreeSlots = free
    DavesBagsDB.bankLastUpdated = date("%m/%d/%y %H:%M")
end

-- =========================================================
-- Dave's Notes Item Exporter
-- =========================================================
local function ExportItemToDavesNotes(link, info)
    if type(DavesNotes_AddItemInfo) ~= "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[Dave's Bags]|r Dave's Notes addon is not loaded.")
        return false
    end

    if not link or not info then return false end

    local itemName, _, itemQuality, itemLevel, reqLevel, itemType, itemSubType, _, equipSlot, _, sellPrice = C_Item.GetItemInfo(link)
    local titleText = itemName or "Item Note"

    local details = {}
    table.insert(details, "Item: " .. link)
    if info.stackCount and info.stackCount > 1 then
        table.insert(details, "Count: " .. info.stackCount)
    end
    if itemLevel and itemLevel > 1 then
        table.insert(details, "iLvl: " .. itemLevel)
    end
    if itemType then
        local typeStr = itemType
        if itemSubType and itemSubType ~= "" then
            typeStr = typeStr .. " (" .. itemSubType .. ")"
        end
        table.insert(details, "Type: " .. typeStr)
    end
    if sellPrice and sellPrice > 0 then
        table.insert(details, "Sell Price: " .. FormatMoneyString(sellPrice))
    end

    local contentText = table.concat(details, "\n")
    local action = DavesNotes_AddItemInfo(titleText, contentText)

    if action == "inserted" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Bags]|r Inserted " .. link .. " into active note.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Bags]|r Created note for " .. link .. ".")
    end
    return true
end

-- =========================================================
-- Category Header Labels Pool
-- =========================================================
local categoryHeaders = {}

local function GetCategoryHeader(index)
    if not categoryHeaders[index] then
        local fs = BagFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])
        fs:SetJustifyH("LEFT")
        categoryHeaders[index] = fs
    end
    return categoryHeaders[index]
end

-- =========================================================
-- Item Button Factory
-- =========================================================
local itemButtons = {}

local function CreateBagButton(index)
    local btn = CreateFrame("ItemButton", "DavesBagsItemSlot" .. index, BagFrame, "ContainerFrameItemButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(BagFrame:GetFrameLevel() + 5)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:HookScript("PreClick", function(self, button)
        if isShowingBank and not (BankFrame and BankFrame:IsShown()) then
            if button == "RightButton" and IsAltKeyDown() and self._cachedLink then
                ExportItemToDavesNotes(self._cachedLink, self._cachedInfo)
            end
            self._prevSlotID = self:GetID()
            self:SetID(0)
            return
        end

        if button == "RightButton" and IsAltKeyDown() then
            local bagID = self:GetBagID()
            local slotID = self:GetID()
            if bagID and slotID then
                local link = C_Container.GetContainerItemLink(bagID, slotID)
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                local success = ExportItemToDavesNotes(link, info)
                if success then
                    self._prevSlotID = slotID
                    self:SetID(0)
                end
            end
        end
    end)

    btn:HookScript("OnClick", function(self, button)
        if self._prevSlotID then
            self:SetID(self._prevSlotID)
            self._prevSlotID = nil
        end
    end)

    btn:HookScript("OnEnter", function(self)
        if isShowingBank and not (BankFrame and BankFrame:IsShown()) and self._cachedLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self._cachedLink)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("<Bank Snapshot (Cached)>", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)

    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
    if btn.flashAnim then btn.flashAnim:Stop() end
    if btn.newitemglowAnim then btn.newitemglowAnim:Stop() end
    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end

    return btn
end

-- =========================================================
-- Category Evaluation Order
-- =========================================================
local CATEGORY_ORDER = {
    "Equipment",
    "Consumables",
    "Trade Goods",
    "Quest",
    "Junk",
    "Miscellaneous",
    "Empty Slots"
}

local function CategorizeItem(info)
    if not info or not info.hasItem then
        return "Empty Slots"
    end
    if info.quality == Enum.ItemQuality.Poor or info.quality == 0 then
        return "Junk"
    end

    local _, _, _, _, _, itemClassID = C_Item.GetItemInfoInstant(info.itemID)
    if itemClassID == Enum.ItemClass.Weapon or itemClassID == Enum.ItemClass.Armor then
        return "Equipment"
    elseif itemClassID == Enum.ItemClass.Consumable then
        return "Consumables"
    elseif itemClassID == Enum.ItemClass.Tradegoods or itemClassID == Enum.ItemClass.Profession or itemClassID == Enum.ItemClass.Reagent then
        return "Trade Goods"
    elseif itemClassID == Enum.ItemClass.Questitem then
        return "Quest"
    end

    return "Miscellaneous"
end

-- =========================================================
-- Grid Update & Layout
-- =========================================================
function UpdateBagGrid()
    local totalSlots = 0
    local freeSlots = 0
    local rawSlots = {}

    if not isShowingBank then
        title:SetText("Dave's Bags")
        for bagID = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            local numFree = C_Container.GetContainerNumFreeSlots(bagID)
            freeSlots = freeSlots + (numFree or 0)

            for slotID = 1, numSlots do
                totalSlots = totalSlots + 1
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                table.insert(rawSlots, {
                    bagID = bagID,
                    slotID = slotID,
                    hasItem = (info ~= nil),
                    iconFileID = info and info.iconFileID,
                    stackCount = info and info.stackCount,
                    quality = info and info.quality,
                    isLocked = info and info.isLocked,
                    itemID = info and info.itemID
                })
            end
        end
        slotCountLabel:SetText(string.format("%d / %d slots free", freeSlots, totalSlots))
    else
        local updatedText = DavesBagsDB.bankLastUpdated and (" (" .. DavesBagsDB.bankLastUpdated .. ")") or ""
        title:SetText("Dave's Bank" .. updatedText)

        local cache = DavesBagsDB.bankCache or {}
        totalSlots = #cache
        freeSlots = DavesBagsDB.bankFreeSlots or 0
        rawSlots = cache

        if totalSlots == 0 then
            slotCountLabel:SetText("No bank cache yet. Visit a banker.")
        else
            slotCountLabel:SetText(string.format("%d / %d slots free", freeSlots, totalSlots))
        end
    end

    for i = #itemButtons + 1, totalSlots do
        itemButtons[i] = CreateBagButton(i)
    end

    for _, fs in ipairs(categoryHeaders) do
        fs:Hide()
    end

    local gridWidth = (PADDING * 2) + (COLS * BUTTON_SIZE) + ((COLS - 1) * BUTTON_SPACING)
    local buttonIndex = 1

    if not isCategoryView then
        local filledSlots = {}
        local emptySlots = {}

        for _, item in ipairs(rawSlots) do
            if item.hasItem then
                table.insert(filledSlots, item)
            else
                table.insert(emptySlots, item)
            end
        end

        local orderedSlots = {}
        for _, item in ipairs(filledSlots) do table.insert(orderedSlots, item) end
        for _, item in ipairs(emptySlots) do table.insert(orderedSlots, item) end

        local rows = math.max(1, math.ceil(totalSlots / COLS))
        local totalHeight = (PADDING * 2) + HEADER_HEIGHT + FOOTER_HEIGHT + (rows * BUTTON_SIZE) + ((rows - 1) * BUTTON_SPACING) + 8
        BagFrame:SetSize(gridWidth, totalHeight)

        for i = 1, totalSlots do
            local item = orderedSlots[i]
            local btn = itemButtons[i]
            btn:SetID(item.slotID or 0)
            btn:SetBagID(item.bagID or 0)

            btn._cachedLink = item.link
            btn._cachedInfo = item

            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            local x = PADDING + (col * (BUTTON_SIZE + BUTTON_SPACING))
            local y = -(PADDING + HEADER_HEIGHT + 2) - (row * (BUTTON_SIZE + BUTTON_SPACING))

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", BagFrame, "TOPLEFT", x, y)

            if item.hasItem then
                SetItemButtonTexture(btn, item.iconFileID)
                SetItemButtonCount(btn, item.stackCount)
                SetItemButtonDesaturated(btn, item.isLocked)

                if item.quality and item.quality > 1 and btn.IconBorder then
                    local r, g, b = C_Item.GetItemQualityColor(item.quality)
                    btn.IconBorder:SetVertexColor(r, g, b, 1)
                    btn.IconBorder:Show()
                elseif btn.IconBorder then
                    btn.IconBorder:Hide()
                end
            else
                SetItemButtonTexture(btn, nil)
                SetItemButtonCount(btn, 0)
                if btn.IconBorder then btn.IconBorder:Hide() end
            end

            if btn.NewItemTexture then btn.NewItemTexture:Hide() end
            if btn.flashAnim and btn.flashAnim:IsPlaying() then btn.flashAnim:Stop() end
            if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then btn.newitemglowAnim:Stop() end
            if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end

            btn:Show()
        end
    else
        local groups = {}
        for _, cat in ipairs(CATEGORY_ORDER) do groups[cat] = {} end

        for _, item in ipairs(rawSlots) do
            local cat = CategorizeItem(item)
            table.insert(groups[cat], item)
        end

        local currentY = PADDING + HEADER_HEIGHT + 4
        local headerIdx = 1

        for _, catName in ipairs(CATEGORY_ORDER) do
            local itemsInCat = groups[catName]
            if #itemsInCat > 0 then
                local catLabel = GetCategoryHeader(headerIdx)
                headerIdx = headerIdx + 1
                catLabel:ClearAllPoints()
                catLabel:SetPoint("TOPLEFT", BagFrame, "TOPLEFT", PADDING + 2, -currentY)
                catLabel:SetText(string.format("%s (%d)", catName, #itemsInCat))
                catLabel:Show()

                currentY = currentY + SECTION_HEADER_HEIGHT

                for idx, item in ipairs(itemsInCat) do
                    local btn = itemButtons[buttonIndex]
                    btn:SetID(item.slotID or 0)
                    btn:SetBagID(item.bagID or 0)

                    btn._cachedLink = item.link
                    btn._cachedInfo = item

                    local col = (idx - 1) % COLS
                    local row = math.floor((idx - 1) / COLS)
                    local x = PADDING + (col * (BUTTON_SIZE + BUTTON_SPACING))
                    local y = -currentY - (row * (BUTTON_SIZE + BUTTON_SPACING))

                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", BagFrame, "TOPLEFT", x, y)

                    if item.hasItem then
                        SetItemButtonTexture(btn, item.iconFileID)
                        SetItemButtonCount(btn, item.stackCount)
                        SetItemButtonDesaturated(btn, item.isLocked)

                        if item.quality and item.quality > 1 and btn.IconBorder then
                            local r, g, b = C_Item.GetItemQualityColor(item.quality)
                            btn.IconBorder:SetVertexColor(r, g, b, 1)
                            btn.IconBorder:Show()
                        elseif btn.IconBorder then
                            btn.IconBorder:Hide()
                        end
                    else
                        SetItemButtonTexture(btn, nil)
                        SetItemButtonCount(btn, 0)
                        if btn.IconBorder then btn.IconBorder:Hide() end
                    end

                    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
                    if btn.flashAnim and btn.flashAnim:IsPlaying() then btn.flashAnim:Stop() end
                    if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then btn.newitemglowAnim:Stop() end
                    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end

                    btn:Show()
                    buttonIndex = buttonIndex + 1
                end

                local catRows = math.ceil(#itemsInCat / COLS)
                currentY = currentY + (catRows * BUTTON_SIZE) + ((catRows - 1) * BUTTON_SPACING) + 8
            end
        end

        local totalHeight = currentY + PADDING + FOOTER_HEIGHT + 4
        BagFrame:SetSize(gridWidth, totalHeight)
    end

    for i = totalSlots + 1, #itemButtons do
        itemButtons[i]:Hide()
    end

    UpdateMoneyDisplay()
end

-- =========================================================
-- Event Handling (General, Merchant, Bank, Money)
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

local isBankOpen = false

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "DavesBags" then
            if DavesBagsDB.isCategoryView ~= nil then
                isCategoryView = DavesBagsDB.isCategoryView
            end
        end
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
        RegisterDefaultFooterAddons()
        if BagFrame and BagFrame.UpdateFooterMenu then
            BagFrame:UpdateFooterMenu()
        end
        UpdateMoneyDisplay()
        UpdateBagActionsMenu()

    elseif event == "PLAYER_MONEY" then
        UpdateMoneyDisplay()

    elseif event == "BANKFRAME_OPENED" then
        isBankOpen = true
        CacheBankItems()
        if not BagFrame:IsShown() then
            UpdateBagGrid()
            BagFrame:Show()
            BagFrame:Raise()
        elseif isShowingBank then
            UpdateBagGrid()
        end
        UpdateBagActionsMenu()

    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if isBankOpen then
            CacheBankItems()
            if isShowingBank and BagFrame:IsShown() then
                UpdateBagGrid()
            end
        end

    elseif event == "BANKFRAME_CLOSED" then
        if isBankOpen then
            CacheBankItems()
        end
        isBankOpen = false

        if BagFrame:IsShown() and not (MerchantFrame and MerchantFrame:IsShown()) then
            isShowingBank = false
            BagFrame:Hide()
        end
        UpdateBagActionsMenu()

    elseif event == "BAG_UPDATE_DELAYED" then
        if isBankOpen then
            CacheBankItems()
        end
        if BagFrame:IsShown() then
            UpdateBagGrid()
        end

    elseif event == "MERCHANT_SHOW" then
        if not BagFrame:IsShown() then
            isShowingBank = false
            UpdateBagGrid()
            BagFrame:Show()
            BagFrame:Raise()
        end
        UpdateBagActionsMenu()

    elseif event == "MERCHANT_CLOSED" then
        UpdateBagActionsMenu()

    elseif BagFrame:IsShown() then
        UpdateBagGrid()
    end
end)

-- =========================================================
-- Toggle Logic & Instant Zero-Flicker Suppression Hooks
-- =========================================================
local function SuppressFrame(frame)
    if not frame or frame._davesBagsHooked then return end
    frame._davesBagsHooked = true

    frame:HookScript("OnShow", function(self)
        self:Hide()
    end)

    if frame:IsShown() then
        frame:Hide()
    end
end

local function InitializeBagSuppression()
    if ContainerFrameCombinedBags then
        SuppressFrame(ContainerFrameCombinedBags)
    end

    if NUM_CONTAINER_FRAMES then
        for i = 1, NUM_CONTAINER_FRAMES do
            local f = _G["ContainerFrame" .. i]
            if f then
                SuppressFrame(f)
            end
        end
    end
end

local function ToggleUnifiedBag()
    if BagFrame:IsShown() then
        BagFrame:Hide()
    else
        isShowingBank = false
        UpdateBagActionsMenu()
        UpdateBagGrid()
        if BagFrame and BagFrame.UpdateFooterMenu then
            BagFrame:UpdateFooterMenu()
        end
        BagFrame:Show()
        BagFrame:Raise()
    end
end

SLASH_DAVESBAGS1 = "/dbags"
SLASH_DAVESBAGS2 = "/davesbags"
SlashCmdList["DAVESBAGS"] = ToggleUnifiedBag

hooksecurefunc("ToggleBackpack", function()
    ToggleUnifiedBag()
end)

hooksecurefunc("ToggleAllBags", function()
    ToggleUnifiedBag()
end)

hooksecurefunc("OpenAllBags", function()
    if not BagFrame:IsShown() then
        ToggleUnifiedBag()
    end
end)

if MainMenuBarBackpackButton then
    MainMenuBarBackpackButton:HookScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ToggleUnifiedBag()
        end
    end)
end

if BagBarExpandButton then
    BagBarExpandButton:HookScript("OnClick", function()
        ToggleUnifiedBag()
    end)
end

InitializeBagSuppression()

-- =========================================================
-- Tooltip Integrations (Dave's Gather & Dave's Quests)
-- =========================================================
local TOOLTIP_CHECK = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14:0:0|t"
local TOOLTIP_NEED  = "|TInterface\\Buttons\\UI-CheckBox-Up:13:13:0:0|t"

local function AppendDavesSuiteTooltipInfo(tooltip, data)
    if not tooltip or tooltip:IsForbidden() then return end

    local itemName = nil
    if data and data.lines and data.lines[1] then
        itemName = data.lines[1].leftText
    end

    if not itemName then return end

    -- 1. Dave's Quests Requirement Check
    if type(DavesQuests_GetItemQuestRequirements) == "function" then
        local questReqs = DavesQuests_GetItemQuestRequirements(itemName)
        if questReqs and #questReqs > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Active Quest Requirement (Dave's Quests):", 1, 0.82, 0.30)
            for _, req in ipairs(questReqs) do
                local icon = req.finished and (TOOLTIP_CHECK .. " |cff00cc00") or (TOOLTIP_NEED .. " |cffffd100")
                tooltip:AddLine(string.format(" %s[%d] %s:|r |cffffffff%s|r", icon, req.questLevel, req.questTitle, req.objectiveText), 0.95, 0.85, 0.65)
            end
        end
    end

    -- 2. Dave's Gather Hotspot Check
    if type(DavesGather_GetLocationsForItem) == "function" then
        local locations = DavesGather_GetLocationsForItem(itemName)
        if locations and #locations > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Gather Locations (Dave's Gather):", 1, 0.82, 0.30)
            local maxShow = math.min(3, #locations)
            for i = 1, maxShow do
                local loc = locations[i]
                tooltip:AddLine(string.format(" • %s: %s (|cffffd100x%d|r)", loc.zone, loc.subZone, loc.count), 0.90, 0.85, 0.70)
            end
            if #locations > maxShow then
                tooltip:AddLine(string.format("   ...and %d more spots (see /dgather)", #locations - maxShow), 0.6, 0.6, 0.6)
            end
        end
    end

    tooltip:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AppendDavesSuiteTooltipInfo)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        local _, link = self:GetItem()
        if link then
            local name = C_Item.GetItemInfo(link)
            if name then
                AppendDavesSuiteTooltipInfo(self, { lines = { { leftText = name } } })
            end
        end
    end)
end