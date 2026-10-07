local addonName, addonTable = ...

-- Variables
local sessionStartMoney = 0
local currentMoney = 0
local initialized = false

-- Create main frame
local frame = CreateFrame("Frame", "DavesWalletFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(250, 80)
frame:SetPoint("CENTER", UIParent, "CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Title
frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
frame.title:SetText("Dave's Wallet")

-- Current Money Text
frame.currentText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.currentText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -30)
frame.currentText:SetText("Current: ")

-- Session Money Text
frame.sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.sessionText:SetPoint("TOPLEFT", frame.currentText, "BOTTOMLEFT", 0, -10)
frame.sessionText:SetText("Session: ")

-- Helper to format money into g s c
local function FormatMoney(copperAmount)
    local isNegative = copperAmount < 0
    local absAmount = math.abs(copperAmount)
    
    local gold = math.floor(absAmount / 10000)
    local silver = math.floor((absAmount % 10000) / 100)
    local copper = absAmount % 100
    
    local text = ""
    if isNegative then
        text = text .. "|cFFFF0000-|r" -- Red minus sign
    else
        text = text .. "|cFF00FF00+|r" -- Green plus sign
    end
    
    if gold > 0 then
        text = text .. gold .. "|cFFFFD700g|r "
    end
    if silver > 0 or gold > 0 then
        text = text .. silver .. "|cFFC0C0C0s|r "
    end
    text = text .. copper .. "|cFFCD7F32c|r"
    
    return text
end

local function UpdateMoneyDisplay()
    currentMoney = GetMoney()
    local sessionDiff = currentMoney - sessionStartMoney
    
    frame.currentText:SetText("Current: " .. GetCoinTextureString(currentMoney))
    
    if sessionDiff == 0 then
        frame.sessionText:SetText("Session: 0|cFFCD7F32c|r")
    else
        frame.sessionText:SetText("Session: " .. FormatMoney(sessionDiff))
    end
end

-- Event Handling
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_MONEY")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if not initialized then
            sessionStartMoney = GetMoney()
            initialized = true
        end
        UpdateMoneyDisplay()
    elseif event == "PLAYER_MONEY" then
        UpdateMoneyDisplay()
    end
end)

-- Slash Command to toggle visibility
SLASH_DAVESWALLET1 = "/dw"
SLASH_DAVESWALLET2 = "/daveswallet"
SlashCmdList["DAVESWALLET"] = function(msg)
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
