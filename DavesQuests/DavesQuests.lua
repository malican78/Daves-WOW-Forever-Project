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

-- =========================================================
-- Main Quest Tracker Panel Setup
-- =========================================================
local function BuildQuestWindow()
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
    createBorder(frame, WINDOW_BORDER_COLOR, 3)
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
    createBorder(header, WINDOW_BORDER_COLOR, 2)

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
    optionsMenu:SetPoint("TOPRIGHT", optionsBtn, "BOTTOMRIGHT", 0, -2)
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
    end

    optionsBtn:SetScript("OnClick", function()
        if optionsMenu:IsShown() then
            optionsMenu:Hide()
        else
            UpdateOptionsMenu()
            optionsMenu:Show()
        end
    end)

    frame:HookScript("OnHide", function()
        optionsMenu:Hide()
    end)

    -- Scroll Area
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)
    scroll:HookScript("OnMouseDown", function()
        optionsMenu:Hide()
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(310, 1)
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
            row:SetWidth(306)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            -- Solid Parchment Card Background
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            setTextureColor(row.bg, 0.99, 0.98, 0.94, 1.0)
            row.bg:SetAllPoints(row)
            createBorder(row, { 0.45, 0.32, 0.18 }, 1)

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
                if button == "RightButton" and IsAltKeyDown() then
                    ExportQuestToDavesNotes(self.questData)
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

                    local qData = {
                        questID = qID,
                        title = info.title,
                        level = info.level,
                        header = currentHeader,
                        isComplete = isComplete,
                        objectives = objectives
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

                local objLines = {}
                if qData.isComplete then
                    table.insert(objLines, ICON_CHECK .. " |cff007700Ready for turn-in!|r")
                elseif qData.objectives and #qData.objectives > 0 then
                    for _, obj in ipairs(qData.objectives) do
                        if obj.finished then
                            table.insert(objLines, ICON_CHECK .. " |cff007700" .. (obj.text or "") .. "|r")
                        else
                            table.insert(objLines, ICON_UNCHECK .. " |cff111111" .. (obj.text or "") .. "|r")
                        end
                    end
                else
                    table.insert(objLines, ICON_UNCHECK .. " |cff444444Quest in progress...|r")
                end

                local formattedObjs = table.concat(objLines, "\n")
                row.objText:SetText(formattedObjs)
                
                -- row.title width handled via anchors now
                row.objText:SetWidth(286)

                local titleHeight = row.title:GetStringHeight() or 18
                local objHeight = row.objText:GetStringHeight() or 22
                local totalCardHeight = titleHeight + objHeight + 24
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
        
        RenderSection("Current Quests", buckets.current)
        RenderSection("Completed Quests", buckets.completed)
        RenderSection("Active Quests", buckets.normal)

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
    else
        questWindow:RefreshQuests()
        questWindow:Show()
        DavesQuestsDB.isOpen = true
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
    if not questWindow:IsShown() then
        questWindow:Show()
        DavesQuestsDB.isOpen = true
    end
    
    SetQuestPinned(qID, true)
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
    elseif questWindow and questWindow:IsShown() then
        questWindow:RefreshQuests()
    end
end)

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