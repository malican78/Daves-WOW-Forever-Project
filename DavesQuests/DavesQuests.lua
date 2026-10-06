local addonName, addon = ...

-- =========================================================
-- Theme & Color Palette (Matched to Dave's AddOns)
-- =========================================================
local WINDOW_COLOR = { 0.73, 0.60, 0.37 }
local WINDOW_BORDER_COLOR = { 0.48, 0.36, 0.22 }
local GOLD_TEXT_COLOR = { 1, 0.82, 0.30 }
local MUTED_GOLD_COLOR = { 0.95, 0.82, 0.48 }

-- Native Blizzard in-line textures
local ICON_CHECK = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:15:15:0:0|t"
local ICON_UNCHECK = "|TInterface\\Buttons\\UI-CheckBox-Up:14:14:0:0|t"

-- Data persistence
DavesQuestsDB = DavesQuestsDB or {}
if DavesQuestsDB.x == nil then DavesQuestsDB.x = -20 end
if DavesQuestsDB.y == nil then DavesQuestsDB.y = -80 end
if DavesQuestsDB.point == nil then DavesQuestsDB.point = "TOPRIGHT" end
if DavesQuestsDB.hideBlizzTracker == nil then DavesQuestsDB.hideBlizzTracker = true end
if DavesQuestsDB.lockWindow == nil then DavesQuestsDB.lockWindow = false end
if DavesQuestsDB.isOpen == nil then DavesQuestsDB.isOpen = true end

local questRows = {}
local questWindow = nil

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
    
    return { top = top, bottom = bottom, left = left, right = right }
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

local function UpdateEscapeRegistration()
    if not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "DavesQuestsFrame" then
            table.remove(UISpecialFrames, i)
        end
    end
    if not DavesQuestsDB.lockWindow then
        table.insert(UISpecialFrames, "DavesQuestsFrame")
    end
end

-- =========================================================
-- Hide / Restore Blizzard's Default Objective Tracker
-- =========================================================
local function SuppressBlizzardTracker()
    local tracker = ObjectiveTrackerContainer or ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame
    if not tracker then return end

    local function ApplyTrackerVisibility(f, hide)
        if not f then return end
        if hide then
            f:SetAlpha(0)
            f:Hide()
            if f.EnableMouse then f:EnableMouse(false) end
        else
            f:SetAlpha(1)
            f:Show()
            if f.EnableMouse then f:EnableMouse(true) end
        end
    end

    ApplyTrackerVisibility(tracker, DavesQuestsDB.hideBlizzTracker)

    if ObjectiveTrackerFrame and ObjectiveTrackerFrame ~= tracker then
        ApplyTrackerVisibility(ObjectiveTrackerFrame, DavesQuestsDB.hideBlizzTracker)
    end
    if QuestWatchFrame and QuestWatchFrame ~= tracker then
        ApplyTrackerVisibility(QuestWatchFrame, DavesQuestsDB.hideBlizzTracker)
    end

    -- Hook tracker once to keep hidden if hideBlizzTracker is true
    if not tracker._davesQuestsHooked then
        tracker._davesQuestsHooked = true
        tracker:HookScript("OnShow", function(self)
            if DavesQuestsDB.hideBlizzTracker then
                self:Hide()
                self:SetAlpha(0)
            end
        end)
    end

    if QuestWatchFrame and not QuestWatchFrame._davesQuestsHooked then
        QuestWatchFrame._davesQuestsHooked = true
        QuestWatchFrame:HookScript("OnShow", function(self)
            if DavesQuestsDB.hideBlizzTracker then
                self:Hide()
                self:SetAlpha(0)
            end
        end)
    end
end

-- =========================================================
-- Dave's Notes Synergy
-- =========================================================
local function ExportQuestToDavesNotes(questData)
    if type(DavesNotes_AddItemInfo) ~= "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[Dave's Quests]|r Dave's Notes addon is not loaded.")
        return false
    end

    local title = string.format("Quest: %s", questData.title or "Quest Note")
    local lines = {}
    table.insert(lines, string.format("Zone/Header: %s", questData.header or "World"))
    table.insert(lines, "Objectives:")

    if questData.objectives and #questData.objectives > 0 then
        for _, obj in ipairs(questData.objectives) do
            local mark = obj.finished and "[x] " or "[ ] "
            table.insert(lines, mark .. (obj.text or "Objective"))
        end
    else
        local mark = questData.isComplete and "[x] Complete Quest" or "[ ] Complete Quest"
        table.insert(lines, mark)
    end

    local action = DavesNotes_AddItemInfo(title, table.concat(lines, "\n"))
    if action == "inserted" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r Inserted " .. questData.title .. " into active note.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r Created note for " .. questData.title .. ".")
    end
    return true
end

-- =========================================================
-- Dave's Gather Synergy (Tooltip Scan for Objectives)
-- =========================================================
local function ShowQuestObjectiveTooltip(frame, questData)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine(questData.title, 1, 0.82, 0)
    GameTooltip:AddLine(questData.header or "General", 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")

    if questData.objectives then
        for _, obj in ipairs(questData.objectives) do
            local mark = obj.finished and (ICON_CHECK .. " |cff008800") or (ICON_UNCHECK .. " |cffffffff")
            GameTooltip:AddLine(mark .. (obj.text or "") .. "|r")

            if type(DavesGather_GetLocationsForItem) == "function" and not obj.finished then
                local spots = DavesGather_GetLocationsForItem(obj.text or "")
                if spots and #spots > 0 then
                    for i = 1, math.min(2, #spots) do
                        GameTooltip:AddLine(string.format("   |cffffd100[Gather]|r %s: %s (x%d)", spots[i].zone, spots[i].subZone, spots[i].count), 0.85, 0.75, 0.5)
                    end
                end
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("<Left-Click: Open Quest Map>", 0.5, 0.8, 1)
    GameTooltip:AddLine("<Alt + Right-Click: Export to Dave's Notes>", 0.48, 0.82, 0.48)
    GameTooltip:Show()
end

-- =========================================================
-- Pin Logic Helper
-- =========================================================
local function GetPinnedIndex(qID)
    if not DavesQuestsDB.pinnedOrder then return nil end
    for i, id in ipairs(DavesQuestsDB.pinnedOrder) do
        if id == qID then return i end
    end
    return nil
end

local function SetQuestPinned(qID, state)
    if not qID then return end
    DavesQuestsDB.pinnedQuests = DavesQuestsDB.pinnedQuests or {}
    DavesQuestsDB.pinnedOrder = DavesQuestsDB.pinnedOrder or {}
    
    if state then
        if not DavesQuestsDB.pinnedQuests[qID] then
            DavesQuestsDB.pinnedQuests[qID] = true
            table.insert(DavesQuestsDB.pinnedOrder, qID)
        end
    else
        DavesQuestsDB.pinnedQuests[qID] = nil
        local idx = GetPinnedIndex(qID)
        if idx then table.remove(DavesQuestsDB.pinnedOrder, idx) end
    end
end

local questContextMenu

-- =========================================================
-- Main Quest Tracker Panel Setup
-- =========================================================
local function BuildQuestWindow()
    if not questContextMenu then
        questContextMenu = CreateFrame("Frame", "DavesQuestsContextMenu", UIParent)
        questContextMenu:SetSize(180, 50)
        questContextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        questContextMenu:SetClampedToScreen(true)
        questContextMenu:EnableMouse(true)
        questContextMenu:Hide()
        
        local cmBg = questContextMenu:CreateTexture(nil, "BACKGROUND")
        cmBg:SetAllPoints()
        cmBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
        questContextMenu.borders = createBorder(questContextMenu, {0.6, 0.5, 0.2}, 1)
        
        local pinOpt = CreateFrame("Button", nil, questContextMenu)
        pinOpt:SetSize(170, 20)
        pinOpt:SetPoint("TOP", questContextMenu, "TOP", 0, -5)
        pinOpt.text = pinOpt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        pinOpt.text:SetPoint("LEFT", 5, 0)
        local pinHl = pinOpt:CreateTexture(nil, "HIGHLIGHT")
        pinHl:SetColorTexture(1, 0.8, 0, 0.3)
        pinHl:SetAllPoints()
        questContextMenu.pinOpt = pinOpt
        
        local closeOpt = CreateFrame("Button", nil, questContextMenu)
        closeOpt:SetSize(170, 20)
        closeOpt:SetPoint("TOP", pinOpt, "BOTTOM", 0, -5)
        closeOpt.text = closeOpt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        closeOpt.text:SetPoint("LEFT", 5, 0)
        closeOpt.text:SetText("Cancel")
        local closeHl = closeOpt:CreateTexture(nil, "HIGHLIGHT")
        closeHl:SetColorTexture(1, 0.8, 0, 0.3)
        closeHl:SetAllPoints()
        closeOpt:SetScript("OnClick", function() questContextMenu:Hide() end)
        
        questContextMenu:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
                self:Hide()
            end
        end)
    end
    local frame = CreateFrame("Frame", "DavesQuestsFrame", UIParent)
    frame:SetSize(350, DavesQuestsDB.height or 480)
    frame:SetPoint(DavesQuestsDB.point or "TOPRIGHT", UIParent, DavesQuestsDB.point or "TOPRIGHT", DavesQuestsDB.x or -20, DavesQuestsDB.y or -80)
    
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetMinResize then frame:SetMinResize(350, 200) end
    if frame.SetMaxResize then frame:SetMaxResize(350, 1200) end
    
    applyWindowBackground(frame)
    frame.blackBg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.blackBg:SetAllPoints(frame)
    frame.blackBg:SetColorTexture(0, 0, 0, DavesQuestsDB.bgOpacity or 0.0)
    frame.borders = createBorder(frame, WINDOW_BORDER_COLOR, 3)
    UpdateEscapeRegistration()

    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function(self)
        frame:StartSizing("BOTTOM")
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        frame:StopMovingOrSizing()
        DavesQuestsDB.height = frame:GetHeight()
    end)

    -- Header Panel
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    header:SetHeight(36)
    applyWindowBackground(header)
    header.borders = createBorder(header, WINDOW_BORDER_COLOR, 2)
    frame.header = header

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local pt, _, relPt, x, y = frame:GetPoint()
        DavesQuestsDB.point = pt
        DavesQuestsDB.x = x
        DavesQuestsDB.y = y
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -5)
    title:SetText("Dave's Quests")
    title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])

    frame.subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subTitle:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 10, 4)
    frame.subTitle:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    close:SetScript("OnClick", function() frame:Hide(); DavesQuestsDB.isOpen = false end)

    -- Options Dropdown Menu Button
    local optionsBtn = CreateFrame("Button", "DavesQuestsOptionsBtn", header, "UIPanelButtonTemplate")
    optionsBtn:SetSize(75, 22)
    optionsBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
    optionsBtn:SetText("Options v")

    -- Options Dropdown Menu Frame
    local optionsMenu = CreateFrame("Frame", nil, frame)
    optionsMenu:SetSize(225, 54)
    optionsMenu:SetPoint("TOPRIGHT", optionsBtn, "BOTTOMRIGHT", 0, 0)
    optionsMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    optionsMenu:SetToplevel(true)
    optionsMenu:SetFrameLevel(250)
    optionsMenu:EnableMouse(true)

    optionsMenu.solidBg = optionsMenu:CreateTexture(nil, "BACKGROUND", nil, -8)
    setTextureColor(optionsMenu.solidBg, 0.98, 0.95, 0.86, 1.0)
    optionsMenu.solidBg:SetAllPoints(optionsMenu)
    createBorder(optionsMenu, WINDOW_BORDER_COLOR, 2)
    optionsMenu:Hide()

    local function CreateQuestMenuItem(parent, yOffset, onClick)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(215, 20)
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
        return btn
    end

    local UpdateOptionsMenu

    optionsMenu:SetSize(225, 170)

    local trackerOpt = CreateQuestMenuItem(optionsMenu, -5, function()
        DavesQuestsDB.hideBlizzTracker = not DavesQuestsDB.hideBlizzTracker
        SuppressBlizzardTracker()
        UpdateOptionsMenu()
    end)

    local lockOpt = CreateQuestMenuItem(optionsMenu, -27, function()
        DavesQuestsDB.lockWindow = not DavesQuestsDB.lockWindow
        UpdateEscapeRegistration()
        UpdateOptionsMenu()
    end)

    local autoOpenOpt = CreateQuestMenuItem(optionsMenu, -49, function()
        DavesQuestsDB.preventAutoOpen = not DavesQuestsDB.preventAutoOpen
        UpdateOptionsMenu()
    end)

    local autoPinOpt = CreateQuestMenuItem(optionsMenu, -71, function()
        DavesQuestsDB.preventAutoPin = not DavesQuestsDB.preventAutoPin
        UpdateOptionsMenu()
    end)
    
    local nativeTrackerOpt = CreateQuestMenuItem(optionsMenu, -93, function()
        DavesQuestsDB.nativeTrackerStyle = not DavesQuestsDB.nativeTrackerStyle
        UpdateOptionsMenu()
        if questWindow then questWindow:RefreshQuests() end
    end)
    
    local opacitySlider = CreateFrame("Slider", "DavesQuestsOpacitySlider", optionsMenu, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOP", optionsMenu, "TOP", 0, -135)
    opacitySlider:SetWidth(180)
    opacitySlider:SetMinMaxValues(0, 1)
    opacitySlider:SetValueStep(0.05)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider:SetValue(DavesQuestsDB.bgOpacity or 0.0)
    
    _G[opacitySlider:GetName() .. "Low"]:SetText("0%")
    _G[opacitySlider:GetName() .. "High"]:SetText("100%")
    _G[opacitySlider:GetName() .. "Text"]:SetText("Tracker Background Opacity")
    
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        DavesQuestsDB.bgOpacity = value
        if questWindow and questWindow.blackBg then
            questWindow.blackBg:SetColorTexture(0, 0, 0, value)
        end
    end)

    function UpdateOptionsMenu()
        if DavesQuestsDB.hideBlizzTracker then
            trackerOpt.text:SetText("|cff888888[ ]|r In-Game Tracker (Hidden)")
        else
            trackerOpt.text:SetText("|cff008800[x]|r In-Game Tracker (Shown)")
        end

        if DavesQuestsDB.lockWindow then
            lockOpt.text:SetText("|cff008800[x]|r Lock Window (ESC ignores)")
        else
            lockOpt.text:SetText("|cff888888[ ]|r Lock Window (ESC closes)")
        end
        
        if DavesQuestsDB.preventAutoOpen then
            autoOpenOpt.text:SetText("|cff888888[ ]|r Auto-Open Window (Disabled)")
        else
            autoOpenOpt.text:SetText("|cff008800[x]|r Auto-Open Window (Enabled)")
        end

        if DavesQuestsDB.preventAutoPin then
            autoPinOpt.text:SetText("|cff888888[ ]|r Auto-Pin Quests (Disabled)")
        else
            autoPinOpt.text:SetText("|cff008800[x]|r Auto-Pin Quests (Enabled)")
        end
        
        if DavesQuestsDB.nativeTrackerStyle then
            nativeTrackerOpt.text:SetText("|cff008800[x]|r Native Tracker Style (Enabled)")
        else
            nativeTrackerOpt.text:SetText("|cff888888[ ]|r Native Tracker Style (Disabled)")
        end
    end

    optionsBtn:SetScript("OnEnter", function()
        UpdateOptionsMenu()
        optionsMenu:Show()
    end)
    
    optionsBtn:SetScript("OnClick", function()
        if optionsMenu:IsShown() then
            optionsMenu:Hide()
        else
            UpdateOptionsMenu()
            optionsMenu:Show()
        end
    end)
    
    optionsMenu:SetScript("OnUpdate", function(self)
        if not optionsBtn:IsMouseOver() and not self:IsMouseOver() then
            self:Hide()
        end
    end)

    frame:HookScript("OnHide", function()
        optionsMenu:Hide()
    end)

    -- Scroll Area
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 8) -- Reclaimed 22px from missing scrollbar
    scroll:HookScript("OnMouseDown", function()
        optionsMenu:Hide()
    end)
    
    -- Native mouse wheel scrolling
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local curY = self:GetVerticalScroll()
        local maxY = self:GetVerticalScrollRange()
        local newY = curY - (delta * 40)
        if newY < 0 then newY = 0 end
        if newY > maxY then newY = maxY end
        self:SetVerticalScroll(newY)
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(330, 1)
    scroll:SetScrollChild(content)

    frame.emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.emptyText:SetPoint("CENTER", scroll, "CENTER", 0, 0)
    frame.emptyText:SetWidth(260)
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetText("No active quests tracked.")
    frame.emptyText:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])

    -- Row Generator
    local function GetQuestRow(index)
        if not questRows[index] then
            local row = CreateFrame("Button", nil, content)
            row:SetWidth(330)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            -- Solid Parchment Card Background
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            setTextureColor(row.bg, 0.99, 0.98, 0.94, 1.0)
            row.bg:SetAllPoints(row)
            row.borders = createBorder(row, { 0.45, 0.32, 0.18 }, 1)

            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(row.highlight, 1, 0.85, 0.40, 0.35)
            row.highlight:SetAllPoints(row)

            -- Quest Title
            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
            row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -125, -8)
            row.title:SetJustifyH("LEFT")
            row.title:SetWordWrap(true)
            row.title:SetTextColor(0.50, 0.22, 0.02)
            
            row.pinBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.pinBtn:SetSize(110, 22)
            row.pinBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -6)
            
            row.pinBtn:SetScript("OnClick", function(self)
                local qID = row.questData and row.questData.questID
                if not qID then return end
                DavesQuestsDB.pinnedQuests = DavesQuestsDB.pinnedQuests or {}
                SetQuestPinned(qID, not DavesQuestsDB.pinnedQuests[qID])
                if questWindow then questWindow:RefreshQuests() end
            end)

            row.itemBtn = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
            row.itemBtn:SetSize(28, 28)
            row.itemBtn:SetPoint("TOPRIGHT", row.pinBtn, "BOTTOMRIGHT", -2, -4)
            row.itemBtn:SetAttribute("type", "item")
            
            row.itemBtn.icon = row.itemBtn:CreateTexture(nil, "BACKGROUND")
            row.itemBtn.icon:SetAllPoints()
            
            local itemNormalTex = row.itemBtn:CreateTexture(nil, "OVERLAY")
            itemNormalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            itemNormalTex:SetSize(46, 46)
            itemNormalTex:SetPoint("CENTER", 0, 0)
            row.itemBtn:SetNormalTexture(itemNormalTex)
            
            row.itemBtn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
            row.itemBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            
            local itemGlow = row.itemBtn:CreateTexture(nil, "OVERLAY")
            itemGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            itemGlow:SetBlendMode("ADD")
            itemGlow:SetSize(52, 52)
            itemGlow:SetPoint("CENTER", 0, 0)
            itemGlow:SetVertexColor(1, 0.85, 0.1, 0.8)
            
            local glowAnim = itemGlow:CreateAnimationGroup()
            glowAnim:SetLooping("BOUNCE")
            local alphaAnim = glowAnim:CreateAnimation("Alpha")
            alphaAnim:SetFromAlpha(0.2)
            alphaAnim:SetToAlpha(1.0)
            alphaAnim:SetDuration(0.8)
            glowAnim:Play()
            
            row.itemBtn.glow = itemGlow
            
            row.itemBtn:SetScript("OnEnter", function(self)
                if self.itemLink then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self.itemLink)
                end
            end)
            row.itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            row:SetMovable(true)
            row:RegisterForDrag("LeftButton")
            
            row:SetScript("OnDragStart", function(self)
                local qID = self.questData and self.questData.questID
                if not qID then return end
                
                local currentIdx = GetPinnedIndex(qID)
                if not currentIdx then return end

                self.isDragging = true
                self.originalLevel = self:GetFrameLevel()
                self:SetFrameLevel(self.originalLevel + 50)
                self:ClearAllPoints()
                self:StartMoving()
            end)
            
            row:SetScript("OnDragStop", function(self)
                if not self.isDragging then return end
                self.isDragging = false
                self:StopMovingOrSizing()
                if self.originalLevel then self:SetFrameLevel(self.originalLevel) end
                
                local qID = self.questData.questID
                local currentIndex = GetPinnedIndex(qID)
                
                local dropTargetQuestID = nil
                for _, otherRow in pairs(questRows) do
                    if otherRow:IsShown() and otherRow ~= self and otherRow.questData then
                        local otherQID = otherRow.questData.questID
                        if GetPinnedIndex(otherQID) and otherRow:IsMouseOver() then
                            dropTargetQuestID = otherQID
                            break
                        end
                    end
                end
                
                if dropTargetQuestID then
                    table.remove(DavesQuestsDB.pinnedOrder, currentIndex)
                    local newIndex = GetPinnedIndex(dropTargetQuestID)
                    table.insert(DavesQuestsDB.pinnedOrder, newIndex, qID)
                end
                
                if questWindow then questWindow:RefreshQuests() end
            end)

            -- Objective Summary Lines
            row.objText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.objText:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -6)
            row.objText:SetWidth(286)
            row.objText:SetJustifyH("LEFT")
            row.objText:SetWordWrap(true)
            row.objText:SetSpacing(4)
            row.objText:SetTextColor(0.10, 0.08, 0.06)

            row:SetScript("OnEnter", function(self)
                if self.questData then
                    ShowQuestObjectiveTooltip(self, self.questData)
                end
            end)

            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            row:SetScript("OnClick", function(self, button)
                if not self.questData then return end
                if button == "RightButton" then
                    if IsAltKeyDown() then
                        ExportQuestToDavesNotes(self.questData)
                    elseif DavesQuestsDB.nativeTrackerStyle then
                        questContextMenu.owner = self
                        local qID = self.questData.questID
                        local isPinned = DavesQuestsDB.pinnedQuests[qID]
                        
                        if isPinned then
                            questContextMenu.pinOpt.text:SetText("Unpin from In Progress")
                        else
                            questContextMenu.pinOpt.text:SetText("Pin to In Progress")
                        end
                        
                        questContextMenu.pinOpt:SetScript("OnClick", function()
                            SetQuestPinned(qID, not isPinned)
                            if questWindow then questWindow:RefreshQuests() end
                            questContextMenu:Hide()
                        end)
                        
                        local x, y = GetCursorPosition()
                        local scale = UIParent:GetEffectiveScale()
                        questContextMenu:ClearAllPoints()
                        questContextMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x/scale, y/scale)
                        questContextMenu:Show()
                    end
                elseif button == "LeftButton" then
                    if QuestMapFrame_OpenToQuestDetails then
                        QuestMapFrame_OpenToQuestDetails(self.questData.questID)
                    elseif ShowUIPanel and QuestLogFrame then
                        ShowUIPanel(QuestLogFrame)
                    end
                end
            end)

            questRows[index] = row
        end
        return questRows[index]
    end

    local sectionHeaders = {}
    local function GetSectionHeader(index)
        if not sectionHeaders[index] then
            local header = CreateFrame("Frame", nil, content)
            header:SetSize(306, 24)
            local text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", header, "LEFT", 10, 0)
            text:SetTextColor(0.95, 0.82, 0.48)
            header.text = text
            
            local line = header:CreateTexture(nil, "ARTWORK")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0.48, 0.36, 0.22, 0.5)
            line:SetHeight(1)
            line:SetPoint("LEFT", text, "RIGHT", 10, 0)
            line:SetPoint("RIGHT", header, "RIGHT", -10, 0)
            
            sectionHeaders[index] = header
        end
        return sectionHeaders[index]
    end

    local function UpdateNativeStyle()
        local isNative = DavesQuestsDB.nativeTrackerStyle
        if not questWindow then return end

        if isNative then
            if questWindow.background then questWindow.background:Hide() end
            if questWindow.borders then for _, t in pairs(questWindow.borders) do t:Hide() end end
            if questWindow.header then
                if questWindow.header.background then questWindow.header.background:Hide() end
                if questWindow.header.borders then for _, t in pairs(questWindow.header.borders) do t:Hide() end end
            end
        else
            if questWindow.background then questWindow.background:Show() end
            if questWindow.borders then for _, t in pairs(questWindow.borders) do t:Show() end end
            if questWindow.header then
                if questWindow.header.background then questWindow.header.background:Show() end
                if questWindow.header.borders then for _, t in pairs(questWindow.header.borders) do t:Show() end end
            end
        end

        for _, row in pairs(questRows) do
            if isNative then
                if row.bg then row.bg:Hide() end
                if row.highlight then row.highlight:Hide() end
                if row.borders then for _, t in pairs(row.borders) do t:Hide() end end
                if row.title then
                    row.title:SetTextColor(1, 0.82, 0)
                    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -40, -8)
                end
                if row.pinBtn then row.pinBtn:Hide() end
                if row.itemBtn then
                    row.itemBtn:ClearAllPoints()
                    row.itemBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -5)
                end
            else
                if row.bg then row.bg:Show() end
                if row.highlight then row.highlight:Show() end
                if row.borders then for _, t in pairs(row.borders) do t:Show() end end
                if row.title then
                    row.title:SetTextColor(0.50, 0.22, 0.02)
                    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -125, -8)
                end
                if row.pinBtn then row.pinBtn:Show() end
                if row.itemBtn then
                    row.itemBtn:ClearAllPoints()
                    row.itemBtn:SetPoint("TOPRIGHT", row.pinBtn, "BOTTOMRIGHT", -2, -4)
                end
            end
        end
    end

    function frame:RefreshQuests()
        local buckets = { current = {}, completed = {}, normal = {} }
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        local currentHeader = "World"
        DavesQuestsDB.pinnedQuests = DavesQuestsDB.pinnedQuests or {}
        DavesQuestsDB.pinnedOrder = DavesQuestsDB.pinnedOrder or {}
        
        -- Migrate any quests that were pinned before the ordering system was added
        for qID, isPinned in pairs(DavesQuestsDB.pinnedQuests) do
            if isPinned and not GetPinnedIndex(qID) then
                table.insert(DavesQuestsDB.pinnedOrder, qID)
            end
        end
        
        local totalCount = 0

        for index = 1, numEntries do
            local info = C_QuestLog.GetInfo(index)
            if info then
                if info.isHeader then
                    currentHeader = info.title or "World"
                elseif not info.isHidden then
                    local qID = info.questID
                    local objectives = C_QuestLog.GetQuestObjectives(qID)
                    local isComplete = C_QuestLog.IsComplete(qID)
                    
                    local itemLink, itemIcon
                    if GetQuestLogSpecialItemInfo then
                        local link, texture, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(index)
                        if link and texture then
                            itemLink = link
                            itemIcon = texture
                        end
                    end

                    local qData = {
                        questID = qID,
                        title = info.title,
                        level = info.level,
                        header = currentHeader,
                        isComplete = isComplete,
                        objectives = objectives,
                        itemLink = itemLink,
                        itemIcon = itemIcon
                    }
                    totalCount = totalCount + 1
                    
                    if isComplete then
                        if DavesQuestsDB.pinnedQuests[qID] then
                            SetQuestPinned(qID, false)
                        end
                        table.insert(buckets.completed, qData)
                    elseif DavesQuestsDB.pinnedQuests[qID] then
                        table.insert(buckets.current, qData)
                    else
                        table.insert(buckets.normal, qData)
                    end
                end
            end
        end

        frame.subTitle:SetText(string.format("%d Active Quests", totalCount))

        if totalCount == 0 then
            frame.emptyText:Show()
        else
            frame.emptyText:Hide()
        end

        local currentY = 0
        local activeHeaderIndex = 1
        local activeRowIndex = 1

        local function RenderSection(title, qList)
            if #qList == 0 then return end
            
            local header = GetSectionHeader(activeHeaderIndex)
            header.text:SetText(title)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -currentY)
            header:Show()
            activeHeaderIndex = activeHeaderIndex + 1
            currentY = currentY + 30
            
            for i = 1, #qList do
                local qData = qList[i]
                local row = GetQuestRow(activeRowIndex)
                row.questData = qData

                local completedBadge = qData.isComplete and ("  " .. ICON_CHECK .. " |cff008800COMPLETED|r") or ""
                row.title:SetText(string.format("[%d] %s%s", qData.level or 0, qData.title or "Quest", completedBadge))
                
                if DavesQuestsDB.pinnedQuests[qData.questID] then
                    row.pinBtn:SetText("Remove")
                    row.pinBtn:GetFontString():SetTextColor(0.95, 0.82, 0.48)
                else
                    row.pinBtn:SetText("Set In Progress")
                    row.pinBtn:GetFontString():SetTextColor(0.95, 0.82, 0.48)
                end

                local isNative = DavesQuestsDB.nativeTrackerStyle
                local colorComplete = isNative and "|cff888888" or "|cff007700"
                local colorIncomplete = isNative and "|cffcccccc" or "|cff111111"
                local colorProgress = isNative and "|cffcccccc" or "|cff444444"

                local objLines = {}
                if qData.isComplete then
                    table.insert(objLines, ICON_CHECK .. " " .. colorComplete .. "Ready for turn-in!|r")
                elseif qData.objectives and #qData.objectives > 0 then
                    for _, obj in ipairs(qData.objectives) do
                        if obj.finished then
                            table.insert(objLines, ICON_CHECK .. " " .. colorComplete .. (obj.text or "") .. "|r")
                        else
                            table.insert(objLines, ICON_UNCHECK .. " " .. colorIncomplete .. (obj.text or "") .. "|r")
                        end
                    end
                else
                    table.insert(objLines, ICON_UNCHECK .. " " .. colorProgress .. "Quest in progress...|r")
                end

                local formattedObjs = table.concat(objLines, "\n")
                row.objText:SetText(formattedObjs)
                
                if qData.itemIcon then
                    row.itemBtn:Show()
                    row.itemBtn.icon:SetTexture(qData.itemIcon)
                    row.itemBtn.itemLink = qData.itemLink
                    if not InCombatLockdown() then
                        row.itemBtn:SetAttribute("item", qData.itemLink)
                    end
                    row.objText:SetWidth(isNative and 275 or 250)
                else
                    row.itemBtn:Hide()
                    row.itemBtn.itemLink = nil
                    if not InCombatLockdown() then
                        row.itemBtn:SetAttribute("item", nil)
                    end
                    row.objText:SetWidth(isNative and 310 or 286)
                end

                local titleHeight = row.title:GetStringHeight() or 18
                local objHeight = row.objText:GetStringHeight() or 22
                local totalCardHeight = titleHeight + objHeight + 24
                if qData.itemIcon then
                    totalCardHeight = math.max(totalCardHeight, 60)
                end
                row:SetHeight(totalCardHeight)

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -currentY)
                row:Show()

                activeRowIndex = activeRowIndex + 1
                currentY = currentY + totalCardHeight + 8
            end
            currentY = currentY + 8
        end
        
        table.sort(buckets.current, function(a, b)
            local idxA = GetPinnedIndex(a.questID) or 999
            local idxB = GetPinnedIndex(b.questID) or 999
            return idxA < idxB
        end)
        
        RenderSection("In Progress", buckets.current)
        RenderSection("Completed Quests", buckets.completed)
        RenderSection("Active Quests", buckets.normal)
        
        UpdateNativeStyle()

        content:SetHeight(math.max(1, currentY))

        for i = activeRowIndex, #questRows do
            questRows[i]:Hide()
        end
        for i = activeHeaderIndex, #sectionHeaders do
            sectionHeaders[i]:Hide()
        end
    end

    frame:Hide()
    questWindow = frame
    return frame
end

local function ToggleQuestWindow()
    if not questWindow then
        BuildQuestWindow()
    end

    if questWindow:IsShown() then
        questWindow:Hide()
        DavesQuestsDB.isOpen = false
        DavesQuestsDB.hideBlizzTracker = false
    else
        questWindow:RefreshQuests()
        questWindow:Show()
        DavesQuestsDB.isOpen = true
        DavesQuestsDB.hideBlizzTracker = true
    end
    
    SuppressBlizzardTracker()
    if type(UpdateOptionsMenu) == "function" then
        UpdateOptionsMenu()
    end
end

SLASH_DAVESQUESTS1 = "/dquests"
SLASH_DAVESQUESTS2 = "/davesquests"
SlashCmdList["DAVESQUESTS"] = ToggleQuestWindow

-- =========================================================
-- Event Handling (Live Tracking & Edit Mode Suppression)
-- =========================================================
local function FocusQuestInDavesQuests(qID)
    if not qID then return end
    
    if not questWindow then BuildQuestWindow() end
    
    -- Check user preference before automatically popping the window open
    if not DavesQuestsDB.preventAutoOpen then
        if not questWindow:IsShown() then
            questWindow:Show()
            DavesQuestsDB.isOpen = true
        end
    end
    
    if not DavesQuestsDB.preventAutoPin then
        SetQuestPinned(qID, true)
    end
    
    if questWindow:IsShown() then
        questWindow:RefreshQuests()
        
        for _, row in pairs(questRows) do
            if row:IsShown() and row.questData and row.questData.questID == qID then
                local flash = row.flashTex
                if not flash then
                    flash = row:CreateTexture(nil, "OVERLAY")
                    flash:SetAllPoints(row)
                    flash:SetColorTexture(0.2, 1, 0.2, 0.5)
                    row.flashTex = flash
                end
                
                flash:Show()
                flash:SetAlpha(0.6)
                if UIFrameFadeOut then
                    UIFrameFadeOut(flash, 2.0, 0.6, 0)
                end
                break
            end
        end
    end
end

local hookedMapFuncs = false
local function TryHookMapFuncs()
    if hookedMapFuncs then return end
    
    if type(QuestMapFrame_OpenToQuestDetails) == "function" then
        hooksecurefunc("QuestMapFrame_OpenToQuestDetails", FocusQuestInDavesQuests)
        hookedMapFuncs = true
    end
    if type(QuestMapFrame_ShowQuestDetails) == "function" then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", FocusQuestInDavesQuests)
        hookedMapFuncs = true
    end
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", FocusQuestInDavesQuests)
        hookedMapFuncs = true
    end
    if type(QuestPOI_SelectButton) == "function" then
        hooksecurefunc("QuestPOI_SelectButton", function(poiButton)
            if poiButton and poiButton.questID then
                FocusQuestInDavesQuests(poiButton.questID)
            end
        end)
        hookedMapFuncs = true
    end
    if type(QuestLog_SetSelection) == "function" then
        hooksecurefunc("QuestLog_SetSelection", function(questLogIndex)
            if not C_QuestLog then return end
            local info = C_QuestLog.GetInfo(questLogIndex)
            if info and info.questID then
                FocusQuestInDavesQuests(info.questID)
            end
        end)
        hookedMapFuncs = true
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

local objectiveCache = {}
local function CheckForQuestProgress()
    if not C_QuestLog then return false end
    local progressDetected = false

    local questsToCheck = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and not info.isHidden then
            questsToCheck[info.questID] = true
        end
    end
    
    for qID in pairs(objectiveCache) do
        questsToCheck[qID] = true
    end

    for qID in pairs(questsToCheck) do
        if not C_QuestLog.GetLogIndexForQuestID(qID) then
            objectiveCache[qID] = nil
        else
            local objectives = C_QuestLog.GetQuestObjectives(qID)
            local currentCount = 0
            if objectives then
                for _, obj in ipairs(objectives) do
                    currentCount = currentCount + (obj.numFulfilled or 0)
                    if obj.finished then currentCount = currentCount + 1000 end
                end
            end
            
            local isComplete = C_QuestLog.IsComplete(qID)
            if isComplete then currentCount = 99999 end

            if objectiveCache[qID] then
                if currentCount > objectiveCache[qID] then
                    if not isComplete then
                        SetQuestPinned(qID, true)
                        progressDetected = true
                    end
                end
            end
            objectiveCache[qID] = currentCount
        end
    end
    
    return progressDetected
end

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        TryHookMapFuncs()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        SuppressBlizzardTracker()

        if event == "PLAYER_LOGIN" then
            TryHookMapFuncs()
            if type(DavesMobileMenu_RegisterAddon) == "function" then
                DavesMobileMenu_RegisterAddon("DavesQuests", "Dave's Quests", 134442, ToggleQuestWindow)
            end
            if DavesQuestsDB.isOpen then
                if not questWindow then BuildQuestWindow() end
                questWindow:RefreshQuests()
                questWindow:Show()
            end
        end
        CheckForQuestProgress() -- Initialize cache on login/enter world
    else
        if event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" or event == "QUEST_ACCEPTED" then
            local progressed = CheckForQuestProgress()
            if progressed and not DavesQuestsDB.preventAutoOpen then
                if questWindow and not questWindow:IsShown() then
                    questWindow:Show()
                    DavesQuestsDB.isOpen = true
                    DavesQuestsDB.hideBlizzTracker = true
                    SuppressBlizzardTracker()
                    if type(UpdateOptionsMenu) == "function" then UpdateOptionsMenu() end
                end
            end
        end
        if questWindow and questWindow:IsShown() then
            questWindow:RefreshQuests()
        end
    end
end)

eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- =========================================================
-- Public API: Check if an item is needed for active quests
-- =========================================================
function DavesQuests_GetItemQuestRequirements(itemName)
    if not itemName or itemName == "" then return nil end
    local lowerItem = string.lower(itemName)
    local results = {}

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and not info.isHidden then
            local qID = info.questID
            local objectives = C_QuestLog.GetQuestObjectives(qID)
            if objectives then
                for _, obj in ipairs(objectives) do
                    local objText = obj.text or ""
                    local lowerObj = string.lower(objText)
                    -- Check if the objective text mentions this item
                    if string.find(lowerObj, lowerItem, 1, true) then
                        table.insert(results, {
                            questTitle = info.title or "Quest",
                            questLevel = info.level or 0,
                            objectiveText = objText,
                            finished = obj.finished or false,
                        })
                    end
                end
            end
        end
    end

    return #results > 0 and results or nil
end
-- =========================================================
-- Minimap Button
-- =========================================================
local minimapBtn = CreateFrame("Button", "DavesQuestsMinimapBtn", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 6, -6)
icon:SetTexture("Interface\\Icons\\INV_Misc_Book_08") -- Quest book icon

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT", 0, 0)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapButtonPosition()
    local angle = math.rad(DavesQuestsDB.minimapAngle or 200)
    -- Calculate radius dynamically so it perfectly hugs the outside edge regardless of minimap size
    local radius = (Minimap:GetWidth() / 2) + (minimapBtn:GetWidth() / 2)
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapBtn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then return end
    ToggleQuestWindow()
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Dave's Quests")
    GameTooltip:AddLine("Left-Click to toggle tracker.", 1, 1, 1)
    GameTooltip:AddLine("Right-Click and drag to move.", 1, 1, 1)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

minimapBtn:RegisterForDrag("RightButton")
local isDragging = false
minimapBtn:SetScript("OnDragStart", function(self) isDragging = true end)
minimapBtn:SetScript("OnDragStop", function(self) isDragging = false end)

minimapBtn:SetScript("OnUpdate", function(self)
    if isDragging then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        if not DavesQuestsDB then return end
        DavesQuestsDB.minimapAngle = angle
        UpdateMinimapButtonPosition()
    end
end)

-- Delay initial positioning until DB is loaded
local minimapLoader = CreateFrame("Frame")
minimapLoader:RegisterEvent("PLAYER_LOGIN")
minimapLoader:SetScript("OnEvent", function()
    UpdateMinimapButtonPosition()
end)
