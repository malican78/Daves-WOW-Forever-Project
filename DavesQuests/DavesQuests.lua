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
if DavesQuestsDB.showHUDTracker == nil then DavesQuestsDB.showHUDTracker = true end
if DavesQuestsDB.hudX == nil then DavesQuestsDB.hudX = -15 end
if DavesQuestsDB.hudY == nil then DavesQuestsDB.hudY = -180 end
if DavesQuestsDB.hudPoint == nil then DavesQuestsDB.hudPoint = "TOPRIGHT" end

local questRows = {}
local questWindow = nil

-- =========================================================
-- Theme Helper Functions
-- =========================================================
local function setTextureColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a or 1)
    else
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(r, g, b, a or 1)
    end
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

-- =========================================================
-- Hide Blizzard's Default Objective Tracker (Edit Mode Safe)
-- =========================================================
local function SuppressBlizzardTracker()
    local trackers = {
        ObjectiveTrackerContainer,
        ObjectiveTrackerFrame,
        ObjectiveTrackerBlocksFrame,
        WatchFrame
    }

    for _, tracker in ipairs(trackers) do
        if tracker then
            if DavesQuestsDB.hideBlizzTracker then
                tracker:SetAlpha(0)
                tracker:Hide()
                if tracker.EnableMouse then tracker:EnableMouse(false) end
            else
                tracker:SetAlpha(1)
                tracker:Show()
                if tracker.EnableMouse then tracker:EnableMouse(true) end
            end

            -- Prevent Blizzard engine from forcing it visible on quest changes
            if not tracker._davesQuestsHooked then
                tracker._davesQuestsHooked = true
                tracker:HookScript("OnShow", function(self)
                    if DavesQuestsDB.hideBlizzTracker then
                        self:Hide()
                        self:SetAlpha(0)
                        if self.EnableMouse then self:EnableMouse(false) end
                    end
                end)
            end
        end
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
-- Main Quest Tracker Panel Setup
-- =========================================================
local function BuildQuestWindow()
    local frame = CreateFrame("Frame", "DavesQuestsFrame", UIParent)
    frame:SetSize(350, 500)
    frame:SetPoint(DavesQuestsDB.point or "TOPRIGHT", UIParent, DavesQuestsDB.point or "TOPRIGHT", DavesQuestsDB.x or -20, DavesQuestsDB.y or -80)
    
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    applyWindowBackground(frame)
    createBorder(frame, WINDOW_BORDER_COLOR, 3)
    registerEscapeFrame("DavesQuestsFrame")

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
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Options Bar: HUD Tracker & Default Tracker Toggles
    local optionsBar = CreateFrame("Frame", nil, frame)
    optionsBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    optionsBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    optionsBar:SetHeight(26)

    local hudCheck = CreateFrame("CheckButton", "DavesQuestsHUDCheck", optionsBar, "UICheckButtonTemplate")
    hudCheck:SetSize(22, 22)
    hudCheck:SetPoint("LEFT", optionsBar, "LEFT", 8, 0)
    _G[hudCheck:GetName() .. "Text"]:SetText("HUD Tracker")
    _G[hudCheck:GetName() .. "Text"]:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    hudCheck:SetChecked(DavesQuestsDB.showHUDTracker)
    hudCheck:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        DavesQuestsDB.showHUDTracker = isChecked
        if HUDTracker then
            if isChecked then
                HUDTracker:Refresh()
                HUDTracker:Show()
            else
                HUDTracker:Hide()
            end
        end
    end)

    local blizzCheck = CreateFrame("CheckButton", "DavesQuestsBlizzCheck", optionsBar, "UICheckButtonTemplate")
    blizzCheck:SetSize(22, 22)
    blizzCheck:SetPoint("LEFT", hudCheck, "RIGHT", 95, 0)
    _G[blizzCheck:GetName() .. "Text"]:SetText("Hide Default Tracker")
    _G[blizzCheck:GetName() .. "Text"]:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    blizzCheck:SetChecked(DavesQuestsDB.hideBlizzTracker)
    blizzCheck:SetScript("OnClick", function(self)
        DavesQuestsDB.hideBlizzTracker = self:GetChecked()
        SuppressBlizzardTracker()
    end)

    -- Scroll Area
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", optionsBar, "BOTTOMLEFT", 6, -4)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)

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
            row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
            row.title:SetJustifyH("LEFT")
            row.title:SetWordWrap(true)
            row.title:SetTextColor(0.50, 0.22, 0.02)

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

    function frame:RefreshQuests()
        local quests = {}
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        local currentHeader = "World"

        for index = 1, numEntries do
            local info = C_QuestLog.GetInfo(index)
            if info then
                if info.isHeader then
                    currentHeader = info.title or "World"
                elseif not info.isHidden then
                    local qID = info.questID
                    local objectives = C_QuestLog.GetQuestObjectives(qID)
                    local isComplete = C_QuestLog.IsComplete(qID)

                    table.insert(quests, {
                        questID = qID,
                        title = info.title,
                        level = info.level,
                        header = currentHeader,
                        isComplete = isComplete,
                        objectives = objectives
                    })
                end
            end
        end

        frame.subTitle:SetText(string.format("%d Active Quests", #quests))

        if #quests == 0 then
            frame.emptyText:Show()
        else
            frame.emptyText:Hide()
        end

        local currentY = 0
        for i = 1, #quests do
            local qData = quests[i]
            local row = GetQuestRow(i)
            row.questData = qData

            -- Build Title with level and completed checkmark
            local completedBadge = qData.isComplete and ("  " .. ICON_CHECK .. " |cff008800COMPLETED|r") or ""
            row.title:SetText(string.format("[%d] %s%s", qData.level or 0, qData.title or "Quest", completedBadge))

            -- Build Objective Lines
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

            row.title:SetWidth(286)
            row.objText:SetWidth(286)

            local titleHeight = row.title:GetStringHeight() or 18
            local objHeight = row.objText:GetStringHeight() or 22
            local totalCardHeight = titleHeight + objHeight + 24
            row:SetHeight(totalCardHeight)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -currentY)
            row:Show()

            currentY = currentY + totalCardHeight + 8
        end

        content:SetHeight(math.max(1, currentY))

        for i = #quests + 1, #questRows do
            questRows[i]:Hide()
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
    else
        questWindow:RefreshQuests()
        questWindow:Show()
    end
end

-- =========================================================
-- Transparent HUD Quest Tracker (Replaces Default Tracker)
-- =========================================================
local HUDTracker = nil
local hudRows = {}

local function BuildHUDTracker()
    if HUDTracker then return HUDTracker end

    local tracker = CreateFrame("Frame", "DavesQuestsHUDTracker", UIParent)
    tracker:SetSize(280, 450)
    tracker:SetPoint(DavesQuestsDB.hudPoint or "TOPRIGHT", UIParent, DavesQuestsDB.hudPoint or "TOPRIGHT", DavesQuestsDB.hudX or -15, DavesQuestsDB.hudY or -180)
    tracker:SetFrameStrata("LOW")
    tracker:SetClampedToScreen(true)
    tracker:SetMovable(true)

    -- Transparent Header (Draggable)
    local hudTitle = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudTitle:SetPoint("TOPLEFT", tracker, "TOPLEFT", 6, -2)
    hudTitle:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -6, -2)
    hudTitle:SetJustifyH("LEFT")
    hudTitle:SetText("Quests")
    hudTitle:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])
    hudTitle:SetShadowOffset(1, -1)
    hudTitle:SetShadowColor(0, 0, 0, 1)
    tracker.title = hudTitle

    local dragHandle = CreateFrame("Button", nil, tracker)
    dragHandle:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
    dragHandle:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT", 0, -22)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:RegisterForClicks("RightButtonUp")

    dragHandle:SetScript("OnDragStart", function() tracker:StartMoving() end)
    dragHandle:SetScript("OnDragStop", function()
        tracker:StopMovingOrSizing()
        local pt, _, relPt, x, y = tracker:GetPoint()
        DavesQuestsDB.hudPoint = pt
        DavesQuestsDB.hudX = x
        DavesQuestsDB.hudY = y
    end)

    dragHandle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Dave's Quests HUD Tracker", 1, 0.82, 0)
        GameTooltip:AddLine("Drag with Left-Click to reposition.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("<Right-Click to Open Quest Window>", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dragHandle:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ToggleQuestWindow()
        end
    end)

    local function GetHUDRow(index)
        if not hudRows[index] then
            local row = CreateFrame("Button", nil, tracker)
            row:SetWidth(276)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(row.highlight, 1, 0.82, 0.30, 0.15)
            row.highlight:SetAllPoints(row)

            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -2)
            row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -2)
            row.title:SetJustifyH("LEFT")
            row.title:SetWordWrap(true)
            row.title:SetTextColor(1, 0.85, 0.35)
            row.title:SetShadowOffset(1, -1)
            row.title:SetShadowColor(0, 0, 0, 1)

            row.objText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.objText:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
            row.objText:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -3)
            row.objText:SetJustifyH("LEFT")
            row.objText:SetWordWrap(true)
            row.objText:SetSpacing(3)
            row.objText:SetTextColor(0.92, 0.92, 0.92)
            row.objText:SetShadowOffset(1, -1)
            row.objText:SetShadowColor(0, 0, 0, 1)

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
                elseif button == "RightButton" then
                    ToggleQuestWindow()
                end
            end)

            hudRows[index] = row
        end
        return hudRows[index]
    end

    function tracker:Refresh()
        if not DavesQuestsDB.showHUDTracker then
            tracker:Hide()
            return
        end

        local quests = {}
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        local currentHeader = "World"

        for index = 1, numEntries do
            local info = C_QuestLog.GetInfo(index)
            if info then
                if info.isHeader then
                    currentHeader = info.title or "World"
                elseif not info.isHidden then
                    local qID = info.questID
                    local isWatched = C_QuestLog.IsQuestWatched and C_QuestLog.IsQuestWatched(qID)
                    local objectives = C_QuestLog.GetQuestObjectives(qID)
                    local isComplete = C_QuestLog.IsComplete(qID)

                    table.insert(quests, {
                        questID = qID,
                        title = info.title,
                        level = info.level,
                        header = currentHeader,
                        isComplete = isComplete,
                        isWatched = isWatched,
                        objectives = objectives
                    })
                end
            end
        end

        -- If specific quests are watched, prioritize watched quests
        local watched = {}
        for _, q in ipairs(quests) do
            if q.isWatched then
                table.insert(watched, q)
            end
        end

        local displayQuests = (#watched > 0) and watched or quests
        local currentY = 24

        for i = 1, #displayQuests do
            local qData = displayQuests[i]
            local row = GetHUDRow(i)
            row.questData = qData

            local completedBadge = qData.isComplete and (" |cff22dd22(Ready)|r") or ""
            row.title:SetText(string.format("|cffffd100[%d]|r %s%s", qData.level or 0, qData.title or "Quest", completedBadge))

            local objLines = {}
            if qData.isComplete then
                table.insert(objLines, ICON_CHECK .. " |cff22dd22Ready for turn-in!|r")
            elseif qData.objectives and #qData.objectives > 0 then
                for _, obj in ipairs(qData.objectives) do
                    if obj.finished then
                        table.insert(objLines, ICON_CHECK .. " |cff22dd22" .. (obj.text or "") .. "|r")
                    else
                        table.insert(objLines, ICON_UNCHECK .. " |cffffffff" .. (obj.text or "") .. "|r")
                    end
                end
            else
                table.insert(objLines, ICON_UNCHECK .. " |cffaaaaaaIn progress...|r")
            end

            row.objText:SetText(table.concat(objLines, "\n"))

            row.title:SetWidth(266)
            row.objText:SetWidth(266)

            local tHeight = row.title:GetStringHeight() or 14
            local oHeight = row.objText:GetStringHeight() or 14
            local rowHeight = tHeight + oHeight + 8

            row:SetSize(276, rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, -currentY)
            row:Show()

            currentY = currentY + rowHeight + 6
        end

        for i = #displayQuests + 1, #hudRows do
            hudRows[i]:Hide()
        end

        tracker:SetHeight(math.max(40, currentY))

        if #displayQuests == 0 then
            hudTitle:SetText("Quests (0 Tracked)")
        else
            hudTitle:SetText(string.format("Quests (%d)", #displayQuests))
        end

        tracker:Show()
    end

    HUDTracker = tracker
    return tracker
end

local function HandleSlashCmd(msg)
    local cmd = string.lower(strtrim(msg or ""))
    if cmd == "hud" then
        DavesQuestsDB.showHUDTracker = not DavesQuestsDB.showHUDTracker
        if not HUDTracker then BuildHUDTracker() end
        if DavesQuestsDB.showHUDTracker then
            HUDTracker:Refresh()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r HUD Tracker enabled.")
        else
            HUDTracker:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r HUD Tracker hidden.")
        end
    else
        ToggleQuestWindow()
    end
end

SLASH_DAVESQUESTS1 = "/dquests"
SLASH_DAVESQUESTS2 = "/davesquests"
SlashCmdList["DAVESQUESTS"] = HandleSlashCmd

-- =========================================================
-- Event Handling (Live Tracking & Edit Mode Suppression)
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        SuppressBlizzardTracker()

        if event == "PLAYER_LOGIN" then
            if not HUDTracker then
                BuildHUDTracker()
            end
            if DavesQuestsDB.showHUDTracker and HUDTracker then
                HUDTracker:Refresh()
            end

            if type(DavesMobileMenu_RegisterAddon) == "function" then
                DavesMobileMenu_RegisterAddon("DavesQuests", "Dave's Quests", 133872, ToggleQuestWindow)
            end
        end
    end

    if HUDTracker and DavesQuestsDB.showHUDTracker then
        HUDTracker:Refresh()
    end

    if questWindow and questWindow:IsShown() then
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