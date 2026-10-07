local addonName, addon = ...

-- =========================================================
-- Theme & Color Palette (Matched to Dave's AddOns)
-- =========================================================
local WINDOW_COLOR = { 0.73, 0.60, 0.37 }
local WINDOW_BORDER_COLOR = { 0.48, 0.36, 0.22 }
local GOLD_TEXT_COLOR = { 1, 0.82, 0.30 }

-- Database Defaults
DavesMobileMenuDB = DavesMobileMenuDB or {}
if DavesMobileMenuDB.showMenu == nil then DavesMobileMenuDB.showMenu = true end
if DavesMobileMenuDB.x == nil then DavesMobileMenuDB.x = 0 end
if DavesMobileMenuDB.y == nil then DavesMobileMenuDB.y = -200 end

-- Registry of installed launchers
local registeredButtons = {}
local activeDockButtons = {}

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

-- =========================================================
-- Main Frame Setup
-- =========================================================
local MenuFrame = CreateFrame("Frame", "DavesMobileMenuFrame", UIParent)
MenuFrame:SetFrameStrata("HIGH")
MenuFrame:SetClampedToScreen(true)
MenuFrame:SetMovable(true)
MenuFrame:EnableMouse(true)
MenuFrame:RegisterForDrag("LeftButton")
applyWindowBackground(MenuFrame)
createBorder(MenuFrame, WINDOW_BORDER_COLOR, 2)

-- Dragging & Position Saving
MenuFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

MenuFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    DavesMobileMenuDB.point = point
    DavesMobileMenuDB.relPoint = relPoint
    DavesMobileMenuDB.x = x
    DavesMobileMenuDB.y = y
end)

-- Layout Refresh
local BUTTON_SIZE = 28
local BUTTON_SPACING = 5
local PADDING = 6

local function RefreshMenuLayout()
    local count = #registeredButtons
    local totalWidth = PADDING + (count * BUTTON_SIZE) + (math.max(0, count - 1) * BUTTON_SPACING) + PADDING
    local totalHeight = BUTTON_SIZE + (PADDING * 2)

    MenuFrame:SetSize(math.max(50, totalWidth), totalHeight)

    for i = 1, count do
        local data = registeredButtons[i]
        local btn = activeDockButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, MenuFrame)
            btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(btn)

            btn.border = btn:CreateTexture(nil, "OVERLAY")
            btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            btn.border:SetBlendMode("ADD")
            btn.border:SetAlpha(0.6)
            btn.border:SetPoint("TOPLEFT", btn, -4, 4)
            btn.border:SetPoint("BOTTOMRIGHT", btn, 4, -4)

            btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(btn.highlight, 1, 0.82, 0.30, 0.25)
            btn.highlight:SetAllPoints(btn)

            btn:SetScript("OnEnter", function(self)
                if not self.data then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.data.title, 1, 0.82, 0)
                GameTooltip:AddLine("Click to toggle", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            activeDockButtons[i] = btn
        end

        btn.data = data
        btn.icon:SetTexture(data.icon or 134400)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", MenuFrame, "LEFT", PADDING + ((i - 1) * (BUTTON_SIZE + BUTTON_SPACING)), 0)

        btn:SetScript("OnClick", function(self)
            if self.data and type(self.data.toggleFunc) == "function" then
                self.data.toggleFunc()
            end
        end)

        btn:Show()
    end

    for i = count + 1, #activeDockButtons do
        activeDockButtons[i]:Hide()
    end

    if DavesMobileMenuDB.showMenu then
        MenuFrame:Show()
    else
        MenuFrame:Hide()
    end
end

-- =========================================================
-- Public Addon Registration Function
-- =========================================================
function DavesMobileMenu_RegisterAddon(id, title, icon, toggleFunc)
    for _, item in ipairs(registeredButtons) do
        if item.id == id then
            item.title = title
            item.icon = icon
            item.toggleFunc = toggleFunc
            RefreshMenuLayout()
            return
        end
    end

    table.insert(registeredButtons, {
        id = id,
        title = title,
        icon = icon,
        toggleFunc = toggleFunc
    })

    RefreshMenuLayout()
end

--- =========================================================
-- Built-In Registrations for Dave's AddOns (Dynamic Check)
-- =========================================================
local function RegisterDefaultAddons()
    local function isLoaded(name)
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            return C_AddOns.IsAddOnLoaded(name)
        elseif IsAddOnLoaded then
            return IsAddOnLoaded(name)
        end
        return false
    end

    -- 1. Dave's Notes (Only shows if DavesNotes is active)
    if isLoaded("DavesNotes") then
        DavesMobileMenu_RegisterAddon("DavesNotes", "Dave's Notes", 134331, function()
            if SlashCmdList and SlashCmdList["DAVESNOTES"] then
                SlashCmdList["DAVESNOTES"]("")
            end
        end)
    end

    -- 2. Dave's Bags (Only shows if DavesBags is active)
    if isLoaded("DavesBags") then
        DavesMobileMenu_RegisterAddon("DavesBags", "Dave's Bags", "Interface\\Buttons\\Button-Backpack-Up", function()
            if SlashCmdList and SlashCmdList["DAVESBAGS"] then
                SlashCmdList["DAVESBAGS"]("")
            end
        end)
    end

    -- 3. Dave's Gather (Only shows if DavesGather is active)
    if isLoaded("DavesGather") then
        DavesMobileMenu_RegisterAddon("DavesGather", "Dave's Gather", 134440, function()
            if SlashCmdList and SlashCmdList["DAVESGATHER"] then
                SlashCmdList["DAVESGATHER"]("")
            end
        end)
    end

    -- 4. Dave's Pac (Only shows if DavesPac is active)
    if isLoaded("DavesPac") then
        DavesMobileMenu_RegisterAddon("DavesPac", "Dave's Pac", 133872, function()
            if SlashCmdList and SlashCmdList["DAVESPAC"] then
                SlashCmdList["DAVESPAC"]("")
            end
        end)
    end

    -- 5. Dave's Wallet (Only shows if DavesWallet is active)
    if isLoaded("DavesWallet") then
        DavesMobileMenu_RegisterAddon("DavesWallet", "Dave's Wallet", 133784, function()
            if SlashCmdList and SlashCmdList["DAVESWALLET"] then
                SlashCmdList["DAVESWALLET"]("")
            end
        end)
    end
end

-- =========================================================
-- Modern WoW Options Menu Integration
-- =========================================================
local function BuildSettingsPanel()
    local panel = CreateFrame("Frame", "DavesMobileMenuSettingsPanel")
    panel.name = "Dave's Mobile Menu"

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    header:SetText("Dave's Mobile Menu Configuration")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure the on-screen utility dock for all Dave's AddOns.")

    -- Checkbox: Show / Hide Menu
    local checkBtn = CreateFrame("CheckButton", "DavesMobileMenuShowCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    checkBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -16)
    _G[checkBtn:GetName() .. "Text"]:SetText("Display On-Screen Menu")

    checkBtn:SetScript("OnShow", function(self)
        self:SetChecked(DavesMobileMenuDB.showMenu)
    end)

    checkBtn:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        DavesMobileMenuDB.showMenu = isChecked
        if isChecked then
            MenuFrame:Show()
        else
            MenuFrame:Hide()
        end
    end)

    -- Reset Position Button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 24)
    resetBtn:SetPoint("TOPLEFT", checkBtn, "BOTTOMLEFT", 0, -16)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        DavesMobileMenuDB.point = "CENTER"
        DavesMobileMenuDB.relPoint = "CENTER"
        DavesMobileMenuDB.x = 0
        DavesMobileMenuDB.y = -200
        MenuFrame:ClearAllPoints()
        MenuFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end)

    -- Modern Settings API registration
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Dave's Mobile Menu")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- =========================================================
-- Initialization
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- Restore saved position
    local pt = DavesMobileMenuDB.point or "CENTER"
    local rpt = DavesMobileMenuDB.relPoint or "CENTER"
    local x = DavesMobileMenuDB.x or 0
    local y = DavesMobileMenuDB.y or -200
    MenuFrame:ClearAllPoints()
    MenuFrame:SetPoint(pt, UIParent, rpt, x, y)

    RegisterDefaultAddons()
    BuildSettingsPanel()
    RefreshMenuLayout()
end)

SLASH_DAVESMOBILEMENU1 = "/dmenu"
SLASH_DAVESMOBILEMENU2 = "/davesmenu"
SlashCmdList["DAVESMOBILEMENU"] = function()
    DavesMobileMenuDB.showMenu = not DavesMobileMenuDB.showMenu
    if DavesMobileMenuDB.showMenu then
        MenuFrame:Show()
    else
        MenuFrame:Hide()
    end
end