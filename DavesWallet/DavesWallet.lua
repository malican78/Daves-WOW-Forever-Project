local addonName, addonTable = ...

-- =========================================================
-- Theme & Color Palette (Matched to Dave's AddOns)
-- =========================================================
local WINDOW_COLOR = { 0.73, 0.60, 0.37 }
local WINDOW_BORDER_COLOR = { 0.48, 0.36, 0.22 }
local GOLD_TEXT_COLOR = { 1, 0.82, 0.30 }

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

-- Variables
local sessionStartMoney = 0
local sessionStartTime = 0
local currentMoney = 0
local initialized = false

local sessionBreakdown = {
    Vendor = 0,
    Trade = 0,
    Mail = 0,
    Auction = 0,
    Travel = 0,
    Trainer = 0,
    Other = 0,
}

local function DetermineMoneySource()
    if MerchantFrame and MerchantFrame:IsShown() then return "Vendor" end
    if TradeFrame and TradeFrame:IsShown() then return "Trade" end
    if MailFrame and MailFrame:IsShown() then return "Mail" end
    if (AuctionFrame and AuctionFrame:IsShown()) or (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return "Auction" end
    if TaxiFrame and TaxiFrame:IsShown() then return "Travel" end
    if FlightMapFrame and FlightMapFrame:IsShown() then return "Travel" end
    if ClassTrainerFrame and ClassTrainerFrame:IsShown() then return "Trainer" end
    return "Other"
end

-- Create main frame
local frame = CreateFrame("Frame", "DavesWalletFrame", UIParent)
frame:SetSize(250, 95)
frame:SetPoint("CENTER", UIParent, "CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
applyWindowBackground(frame)
createBorder(frame, WINDOW_BORDER_COLOR, 3)

frame:SetScript("OnMouseDown", function()
    frame:Raise()
end)

-- Header Panel
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
header:SetHeight(30)
applyWindowBackground(header)
createBorder(header, WINDOW_BORDER_COLOR, 2)

header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnMouseDown", function() frame:Raise() end)
header:SetScript("OnDragStart", function() frame:Raise(); frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

-- Title
frame.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", header, "TOPLEFT", 12, -8)
frame.title:SetText("Dave's Wallet")
frame.title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])

-- Close Button
local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
closeBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- Current Money Text
frame.currentText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.currentText:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -45)
frame.currentText:SetText("Current: ")

-- Session Money Text
frame.sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.sessionText:SetPoint("TOPLEFT", frame.currentText, "BOTTOMLEFT", 0, -10)
frame.sessionText:SetText("Session: ")

-- History Button
local historyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
historyBtn:SetSize(70, 22)
historyBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -38)
historyBtn:SetText("History")


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
    
    local coinString
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        coinString = C_CurrencyInfo.GetCoinTextureString(currentMoney)
    elseif GetCoinTextureString then
        coinString = GetCoinTextureString(currentMoney)
    else
        coinString = FormatMoney(currentMoney)
    end
    frame.currentText:SetText("Current: " .. coinString)
    
    if sessionDiff == 0 then
        frame.sessionText:SetText("Session: 0|cFFCD7F32c|r")
    else
        frame.sessionText:SetText("Session: " .. FormatMoney(sessionDiff))
    end
end

-- Event Handling
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_MONEY")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if not initialized then
            sessionStartMoney = GetMoney()
            sessionStartTime = time()
            initialized = true
        end
        UpdateMoneyDisplay()
    elseif event == "PLAYER_MONEY" then
        local newMoney = GetMoney()
        local diff = newMoney - currentMoney
        if diff ~= 0 and initialized then
            local source = DetermineMoneySource()
            sessionBreakdown[source] = sessionBreakdown[source] + diff
        end
        UpdateMoneyDisplay()
    elseif event == "PLAYER_LOGIN" then
        DavesWalletDB = DavesWalletDB or {}
        DavesWalletDB.history = DavesWalletDB.history or {}

        if DavesMobileMenu_RegisterAddon then
            DavesMobileMenu_RegisterAddon("DavesWallet", "Dave's Wallet", 133784, function()
                if frame:IsShown() then
                    frame:Hide()
                else
                    frame:Show()
                end
            end)
        end
        if DavesBags_RegisterMenuButton then
            DavesBags_RegisterMenuButton("DavesWallet", "Dave's Wallet", 133784, function()
                if frame:IsShown() then
                    frame:Hide()
                else
                    frame:Show()
                end
            end, "Track session incoming and outgoing gold/silver/copper.")
        end
    elseif event == "PLAYER_LOGOUT" then
        if initialized then
            local finalDiff = currentMoney - sessionStartMoney
            local endTime = time()
            local duration = endTime - sessionStartTime
            table.insert(DavesWalletDB.history, { 
                date = date("%Y-%m-%d"), 
                startTimeStr = date("%I:%M %p", sessionStartTime),
                endTimeStr = date("%I:%M %p", endTime),
                duration = duration,
                diff = finalDiff,
                breakdown = sessionBreakdown
            })
            if #DavesWalletDB.history > 100 then
                table.remove(DavesWalletDB.history, 1)
            end
        end
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

StaticPopupDialogs["DAVESWALLET_CONFIRM_PURGE"] = {
    text = "Are you sure you want to delete ALL Dave's Wallet history?\n\nType 'DELETE' below to confirm.",
    button1 = "Purge",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local btn1 = _G[self:GetName() .. "Button1"]
        if btn1 then btn1:Disable() end
        local editBox = _G[self:GetName() .. "EditBox"]
        if editBox then editBox:SetFocus() end
    end,
    EditBoxOnTextChanged = function(self)
        local text = self:GetText()
        local btn1 = _G[self:GetParent():GetName() .. "Button1"]
        if btn1 then
            if text == "DELETE" then
                btn1:Enable()
            else
                btn1:Disable()
            end
        end
    end,
    OnAccept = function(self)
        if DavesWalletDB then DavesWalletDB.history = {} end
        if historyFrame and historyFrame.dropdownMenu then historyFrame.dropdownMenu:Hide() end
        if historyFrame then
            historyFrame.currentPage = 1
            historyFrame.dropdownBtn:SetText("Select Range v")
            if historyFrame.bars then
                for _, bar in ipairs(historyFrame.bars) do bar:Hide() end
            end
            if historyFrame.statsPanel then
                local p = historyFrame.statsPanel
                p.stat1:SetText("Total Net Profit: 0c")
                p.stat2:SetText("Top Income: None (0c)")
                p.stat3:SetText("Top Expense: None (0c)")
                p.stat6:SetText("Total Time Played: 0m")
                p.stat4:SetText("Average Gold/Hr: 0c")
                p.stat5:SetText("Best Session: 0c")
                p.stat7:SetText("Biggest Loss: 0c")
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- =========================================================
-- History Frame (Pop-out Graph)
-- =========================================================
local historyFrame = CreateFrame("Frame", "DavesWalletHistoryFrame", UIParent)
historyFrame:SetSize(400, 400)
historyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
historyFrame:SetMovable(true)
historyFrame:EnableMouse(true)
historyFrame:SetClampedToScreen(true)
historyFrame:SetFrameStrata("DIALOG")
applyWindowBackground(historyFrame)
createBorder(historyFrame, WINDOW_BORDER_COLOR, 3)
historyFrame:Hide()

historyFrame:SetScript("OnMouseDown", function() historyFrame:Raise() end)

local histHeader = CreateFrame("Frame", nil, historyFrame)
histHeader:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 4, -4)
histHeader:SetPoint("TOPRIGHT", historyFrame, "TOPRIGHT", -4, -4)
histHeader:SetHeight(30)
applyWindowBackground(histHeader)
createBorder(histHeader, WINDOW_BORDER_COLOR, 2)

histHeader:EnableMouse(true)
histHeader:RegisterForDrag("LeftButton")
histHeader:SetScript("OnMouseDown", function() historyFrame:Raise() end)
histHeader:SetScript("OnDragStart", function() historyFrame:Raise(); historyFrame:StartMoving() end)
histHeader:SetScript("OnDragStop", function() historyFrame:StopMovingOrSizing() end)

historyFrame.title = histHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
historyFrame.title:SetPoint("TOPLEFT", histHeader, "TOPLEFT", 12, -8)
historyFrame.title:SetText("Dave's Wallet - Session History")
historyFrame.title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])

local histCloseBtn = CreateFrame("Button", nil, histHeader, "UIPanelCloseButton")
histCloseBtn:SetPoint("RIGHT", histHeader, "RIGHT", -2, 0)
histCloseBtn:SetScript("OnClick", function() historyFrame:Hide() end)

local purgeBtn = CreateFrame("Button", nil, histHeader, "UIPanelButtonTemplate")
purgeBtn:SetSize(60, 22)
purgeBtn:SetPoint("RIGHT", histCloseBtn, "LEFT", -4, 0)
purgeBtn:SetText("Purge")
purgeBtn:SetScript("OnClick", function()
    StaticPopup_Show("DAVESWALLET_CONFIRM_PURGE")
end)

historyFrame.currentPage = 1

local dropdownBtn = CreateFrame("Button", nil, historyFrame, "UIPanelButtonTemplate")
dropdownBtn:SetSize(225, 22)
dropdownBtn:SetPoint("TOP", historyFrame, "TOP", 0, -35)
dropdownBtn:SetText("Select Range v")
historyFrame.dropdownBtn = dropdownBtn

local dropdownMenu = CreateFrame("Frame", nil, historyFrame)
dropdownMenu:SetSize(225, 100)
dropdownMenu:SetPoint("TOP", dropdownBtn, "BOTTOM", 0, -2)
dropdownMenu:SetFrameStrata("DIALOG")
dropdownMenu:SetToplevel(true)
dropdownMenu:SetFrameLevel(250)
dropdownMenu:EnableMouse(true)
dropdownMenu.solidBg = dropdownMenu:CreateTexture(nil, "BACKGROUND", nil, -8)
setTextureColor(dropdownMenu.solidBg, 0.98, 0.95, 0.86, 1.0)
dropdownMenu.solidBg:SetAllPoints(dropdownMenu)
createBorder(dropdownMenu, WINDOW_BORDER_COLOR, 2)
dropdownMenu:Hide()

local function CheckDropdownHover()
    if not dropdownBtn:IsMouseOver() and not dropdownMenu:IsMouseOver() then
        dropdownMenu:Hide()
    end
end

dropdownBtn:SetScript("OnEnter", function() dropdownMenu:Show() end)
dropdownBtn:SetScript("OnLeave", function() C_Timer.After(0.1, CheckDropdownHover) end)
dropdownMenu:SetScript("OnLeave", function() C_Timer.After(0.1, CheckDropdownHover) end)

historyFrame.menuItems = {}
historyFrame.dropdownMenu = dropdownMenu

local leftBtn = CreateFrame("Button", nil, historyFrame)
leftBtn:SetSize(24, 24)
leftBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
leftBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
leftBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
leftBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
leftBtn:SetPoint("RIGHT", dropdownBtn, "LEFT", -4, 0)
historyFrame.leftBtn = leftBtn

local rightBtn = CreateFrame("Button", nil, historyFrame)
rightBtn:SetSize(24, 24)
rightBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
rightBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
rightBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
rightBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
rightBtn:SetPoint("LEFT", dropdownBtn, "RIGHT", 4, 0)
historyFrame.rightBtn = rightBtn

local function ShortMoney(copperAmount)
    local isNegative = copperAmount < 0
    local absAmount = math.abs(copperAmount)
    local gold = math.floor(absAmount / 10000)
    local silver = math.floor((absAmount % 10000) / 100)
    local copper = absAmount % 100
    local prefix = isNegative and "-" or "+"
    if gold > 0 then return prefix .. gold .. "g" end
    if silver > 0 then return prefix .. silver .. "s" end
    return prefix .. copper .. "c"
end

local function ShortDuration(duration)
    if not duration then return "" end
    local hours = math.floor(duration / 3600)
    local mins = math.floor((duration % 3600) / 60)
    if hours > 0 then return string.format("%dh", hours) else return string.format("%dm", mins) end
end

-- Graph drawing logic
local function DrawGraph()
    if historyFrame.bars then
        for _, bar in ipairs(historyFrame.bars) do
            bar:Hide()
        end
    end
    historyFrame.bars = historyFrame.bars or {}
    
    local history = DavesWalletDB and DavesWalletDB.history or {}
    local numSessions = #history
    if numSessions == 0 then return end
    
    local maxBars = 10
    local numPages = math.ceil(numSessions / maxBars)
    if numPages == 0 then numPages = 1 end
    
    if historyFrame.currentPage > numPages then historyFrame.currentPage = numPages end
    if historyFrame.currentPage < 1 then historyFrame.currentPage = 1 end
    
    historyFrame.leftBtn:SetScript("OnClick", function()
        if historyFrame.currentPage < numPages then
            historyFrame.currentPage = historyFrame.currentPage + 1
            DrawGraph()
        end
    end)
    
    historyFrame.rightBtn:SetScript("OnClick", function()
        if historyFrame.currentPage > 1 then
            historyFrame.currentPage = historyFrame.currentPage - 1
            DrawGraph()
        end
    end)
    
    historyFrame.leftBtn:SetEnabled(historyFrame.currentPage < numPages)
    historyFrame.rightBtn:SetEnabled(historyFrame.currentPage > 1)
    
    local optionsHeight = numPages * 22
    historyFrame.dropdownMenu:SetHeight(10 + optionsHeight)
    
    for i=1, numPages do
        local btn = historyFrame.menuItems[i]
        if not btn then
            btn = CreateFrame("Button", nil, historyFrame.dropdownMenu)
            btn:SetHeight(20)
            btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(btn.highlight, 0.85, 0.70, 0.40, 0.4)
            btn.highlight:SetAllPoints(btn)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
            btn.text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            btn.text:SetJustifyH("LEFT")
            historyFrame.menuItems[i] = btn
        end
        
        local pStart = math.max(1, numSessions - (i * maxBars) + 1)
        local pEnd = numSessions - ((i - 1) * maxBars)
        local sDate = history[pStart] and history[pStart].date or ""
        local eDate = history[pEnd] and history[pEnd].date or ""
        
        if historyFrame.currentPage == i then
            btn.text:SetText("|cff008800[x]|r " .. sDate .. " to " .. eDate)
            btn.text:SetTextColor(0.12, 0.09, 0.05)
        else
            btn.text:SetText("|cff888888[ ]|r " .. sDate .. " to " .. eDate)
            btn.text:SetTextColor(0.12, 0.09, 0.05)
        end
        
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", historyFrame.dropdownMenu, "TOPLEFT", 5, -5 - ((i-1)*22))
        btn:SetPoint("RIGHT", historyFrame.dropdownMenu, "RIGHT", -5, 0)
        btn:SetScript("OnClick", function()
            historyFrame.currentPage = i
            historyFrame.dropdownMenu:Hide()
            DrawGraph()
        end)
        btn:Show()
    end
    
    for i=numPages+1, #(historyFrame.menuItems) do
        historyFrame.menuItems[i]:Hide()
    end
    
    local startIdx = math.max(1, numSessions - (historyFrame.currentPage * maxBars) + 1)
    local endIdx = numSessions - ((historyFrame.currentPage - 1) * maxBars)
    
    local sDate = history[startIdx] and history[startIdx].date or ""
    local eDate = history[endIdx] and history[endIdx].date or ""
    
    historyFrame.dropdownBtn:SetText(sDate .. " to " .. eDate .. " v")
    
    local displaySessions = {}
    local maxVal = 0
    for i = startIdx, endIdx do
        table.insert(displaySessions, history[i])
        local absVal = math.abs(history[i].diff)
        if absVal > maxVal then maxVal = absVal end
    end
    if maxVal == 0 then maxVal = 1 end
    
    local graphWidth = 360
    local graphHeight = 160
    local startX = 20
    local startY = -100
    
    if not historyFrame.zeroLine then
        historyFrame.zeroLine = historyFrame:CreateTexture(nil, "ARTWORK")
        setTextureColor(historyFrame.zeroLine, 1, 1, 1, 0.3)
        historyFrame.zeroLine:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", startX, startY - graphHeight/2)
        historyFrame.zeroLine:SetSize(graphWidth, 1)
    end
    
    local barWidth = graphWidth / maxBars
    local padding = 4
    
    for i, entry in ipairs(displaySessions) do
        local bar = historyFrame.bars[i]
        if not bar then
            bar = CreateFrame("Frame", nil, historyFrame)
            bar.tex = bar:CreateTexture(nil, "ARTWORK")
            bar.tex:SetAllPoints()
            
            bar.profitText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            bar.profitText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
            
            bar.durationText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            bar.durationText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
            bar.durationText:SetTextColor(0.8, 0.8, 0.8)
            
            bar:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                local data = self.data
                if data then
                    GameTooltip:AddLine("Session: " .. (data.date or "Unknown"), 1, 0.82, 0)
                    if data.startTimeStr and data.endTimeStr then
                        GameTooltip:AddLine("Time of Day: " .. data.startTimeStr .. " - " .. data.endTimeStr, 1, 1, 1)
                    end
                    if data.duration then
                        local hours = math.floor(data.duration / 3600)
                        local mins = math.floor((data.duration % 3600) / 60)
                        GameTooltip:AddLine(string.format("Time Played: %dh %dm", hours, mins), 1, 1, 1)
                    end
                    local diffText = FormatMoney(data.diff)
                    GameTooltip:AddLine("Profit/Loss: " .. diffText, 1, 1, 1)
                    
                    if data.breakdown then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Source Breakdown:", 1, 0.82, 0)
                        for k, v in pairs(data.breakdown) do
                            if v ~= 0 then
                                GameTooltip:AddDoubleLine("- " .. k, FormatMoney(v), 1, 1, 1)
                            end
                        end
                    end
                end
                GameTooltip:Show()
            end)
            
            bar:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            historyFrame.bars[i] = bar
        end
        bar.data = entry
        
        local isPositive = entry.diff >= 0
        local barHeight = (math.abs(entry.diff) / maxVal) * (graphHeight / 2)
        if barHeight < 1 then barHeight = 1 end
        
        bar:SetSize(barWidth - padding, barHeight)
        bar:ClearAllPoints()
        
        bar.profitText:SetText(ShortMoney(entry.diff))
        bar.durationText:SetText(ShortDuration(entry.duration))
        bar.profitText:ClearAllPoints()
        bar.durationText:ClearAllPoints()
        
        if isPositive then
            setTextureColor(bar.tex, 0.2, 0.8, 0.2, 0.8)
            bar.profitText:SetTextColor(0.2, 1, 0.2)
            bar:SetPoint("BOTTOMLEFT", historyFrame, "TOPLEFT", startX + (i-1)*barWidth, startY - graphHeight/2)
            bar.profitText:SetPoint("BOTTOM", bar, "TOP", 0, 2)
            bar.durationText:SetPoint("TOP", bar, "BOTTOM", 0, -2)
        else
            setTextureColor(bar.tex, 0.8, 0.2, 0.2, 0.8)
            bar.profitText:SetTextColor(1, 0.2, 0.2)
            bar:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", startX + (i-1)*barWidth, startY - graphHeight/2)
            bar.profitText:SetPoint("TOP", bar, "BOTTOM", 0, -2)
            bar.durationText:SetPoint("BOTTOM", bar, "TOP", 0, 2)
        end
        bar:Show()
    end

    -- ==========================================
    -- Summary Stats Panel
    -- ==========================================
    local bestGain = 0
    local biggestLoss = 0
    local totalNet = 0
    local totalTime = 0
    
    local aggIncome = {}
    local aggExpense = {}

    for _, entry in ipairs(displaySessions) do
        totalNet = totalNet + entry.diff
        if entry.duration then
            totalTime = totalTime + entry.duration
        end
        if entry.diff > bestGain then bestGain = entry.diff end
        if entry.diff < biggestLoss then biggestLoss = entry.diff end
        
        if entry.breakdown then
            for k, v in pairs(entry.breakdown) do
                if v > 0 then
                    aggIncome[k] = (aggIncome[k] or 0) + v
                elseif v < 0 then
                    aggExpense[k] = (aggExpense[k] or 0) + v
                end
            end
        end
    end
    
    local bestIncomeSource, bestIncomeVal = "None", 0
    for k, v in pairs(aggIncome) do
        if v > bestIncomeVal then
            bestIncomeVal = v
            bestIncomeSource = k
        end
    end
    
    local worstExpenseSource, worstExpenseVal = "None", 0
    for k, v in pairs(aggExpense) do
        if v < worstExpenseVal then
            worstExpenseVal = v
            worstExpenseSource = k
        end
    end
    
    local gph = 0
    if totalTime > 0 then
        gph = math.floor(totalNet / (totalTime / 3600))
    end

    if not historyFrame.statsPanel then
        local panel = CreateFrame("Frame", nil, historyFrame)
        panel:SetPoint("BOTTOMLEFT", historyFrame, "BOTTOMLEFT", 12, 12)
        panel:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -12, 12)
        panel:SetHeight(90)
        
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        setTextureColor(panel.bg, 0, 0, 0, 0.2)
        panel.bg:SetAllPoints()
        createBorder(panel, WINDOW_BORDER_COLOR, 1)
        historyFrame.statsPanel = panel
        
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
        title:SetText("Recent Sessions Summary:")
        title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])
        
        panel.stat1 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        
        panel.stat2 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat2:SetPoint("TOPLEFT", panel.stat1, "BOTTOMLEFT", 0, -4)

        panel.stat3 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat3:SetPoint("TOPLEFT", panel.stat2, "BOTTOMLEFT", 0, -4)
        
        panel.stat6 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat6:SetPoint("TOPLEFT", panel.stat3, "BOTTOMLEFT", 0, -4)
        
        panel.stat4 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat4:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 190, -8)
        
        panel.stat5 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat5:SetPoint("TOPLEFT", panel.stat4, "BOTTOMLEFT", 0, -4)
        
        panel.stat7 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.stat7:SetPoint("TOPLEFT", panel.stat5, "BOTTOMLEFT", 0, -4)
    end
    
    local p = historyFrame.statsPanel
    p.stat1:SetText("Total Net Profit: " .. FormatMoney(totalNet))
    p.stat2:SetText("Top Income: " .. bestIncomeSource .. " (" .. FormatMoney(bestIncomeVal) .. ")")
    p.stat3:SetText("Top Expense: " .. worstExpenseSource .. " (" .. FormatMoney(worstExpenseVal) .. ")")
    p.stat6:SetText("Total Time Played: " .. ShortDuration(totalTime))
    
    p.stat4:SetText("Average Gold/Hr: " .. FormatMoney(gph))
    p.stat5:SetText("Best Session: " .. FormatMoney(bestGain))
    p.stat7:SetText("Biggest Loss: " .. FormatMoney(biggestLoss))
end

historyFrame:SetScript("OnShow", DrawGraph)

historyBtn:SetScript("OnClick", function()
    if historyFrame:IsShown() then
        historyFrame:Hide()
    else
        historyFrame:Show()
    end
end)
