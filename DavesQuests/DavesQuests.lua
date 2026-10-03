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

-- Data persistence (Safely initialized & re-checked on ADDON_LOADED)
local function InitDB()
    DavesQuestsDB = DavesQuestsDB or {}
    if DavesQuestsDB.x == nil then DavesQuestsDB.x = -20 end
    if DavesQuestsDB.y == nil then DavesQuestsDB.y = -80 end
    if DavesQuestsDB.point == nil then DavesQuestsDB.point = "TOPRIGHT" end
    if DavesQuestsDB.hideBlizzTracker == nil then DavesQuestsDB.hideBlizzTracker = true end
    if DavesQuestsDB.showHUDTracker == nil then DavesQuestsDB.showHUDTracker = true end
    if DavesQuestsDB.showMapPane == nil then DavesQuestsDB.showMapPane = true end
    if DavesQuestsDB.revealAllMap == nil then DavesQuestsDB.revealAllMap = false end
    if DavesQuestsDB.hudX == nil then DavesQuestsDB.hudX = -15 end
    if DavesQuestsDB.hudY == nil then DavesQuestsDB.hudY = -180 end
    if DavesQuestsDB.hudPoint == nil then DavesQuestsDB.hudPoint = "TOPRIGHT" end
end
InitDB()

local questRows = {}
local questWindow = nil
local HUDTracker = nil
local hudRows = {}

-- Map, Zoom & Selection State
local selectedQuestID = nil
local currentMapID = nil
local zoomLevel = 1.0
local BASE_MAP_WIDTH = 418
local BASE_MAP_HEIGHT = 314

local mapTilePool = {}
local mapExplorationTilePool = {}
local questPinPool = {}
local gatherPinPool = {}
local playerPin = nil
local mapPanel = nil
local mapScrollFrame = nil
local mapCanvas = nil
local mapTitle = nil
local zoomText = nil
local btnUncover = nil
local mapDetailsText = nil
local mapFallbackBg = nil
local questAreaGlow = nil
local questAreaRing = nil
local questAreaDotted = nil
local questAreaMobTag = nil
local questAreaMobText = nil

-- Forward declarations
local ToggleQuestWindow
local OpenQuestWindow
local SelectQuest
local LoadZoneMap
local ZoomMap
local RefreshMapPins
local CreateQuestAreaGlow
local UpdateQuestAreaGlow
local SuppressBlizzardTracker
local BuildHUDTracker
local BuildQuestWindow
local UpdateWindowLayout

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
-- Robust Blizzard Tracker Suppression (Modern 11.0 & Classic)
-- =========================================================
local hiddenParent = CreateFrame("Frame", "DavesQuestsHiddenParent", UIParent)
hiddenParent:Hide()

local function SuppressTrackerFrame(frame)
    if not frame then return end

    if DavesQuestsDB.hideBlizzTracker then
        if not frame._davesOriginalParent then
            frame._davesOriginalParent = frame:GetParent() or UIParent
        end

        frame:SetAlpha(0)
        frame:Hide()
        if frame.EnableMouse then frame:EnableMouse(false) end
        if frame.SetCollapsed then pcall(frame.SetCollapsed, frame, true) end

        if not InCombatLockdown or not InCombatLockdown() then
            if not frame:IsProtected() or not InCombatLockdown() then
                frame:SetParent(hiddenParent)
            end
        end
    else
        if frame._davesOriginalParent then
            if not InCombatLockdown or not InCombatLockdown() then
                if not frame:IsProtected() or not InCombatLockdown() then
                    frame:SetParent(frame._davesOriginalParent)
                end
            end
        end
        frame:SetAlpha(1)
        frame:Show()
        if frame.EnableMouse then frame:EnableMouse(true) end
        if frame.SetCollapsed then pcall(frame.SetCollapsed, frame, false) end
    end

    if not frame._davesQuestsHooked then
        frame._davesQuestsHooked = true
        hooksecurefunc(frame, "Show", function(self)
            if DavesQuestsDB.hideBlizzTracker then
                self:Hide()
                self:SetAlpha(0)
                if self.EnableMouse then self:EnableMouse(false) end
            end
        end)
        hooksecurefunc(frame, "SetShown", function(self, show)
            if show and DavesQuestsDB.hideBlizzTracker then
                self:Hide()
                self:SetAlpha(0)
                if self.EnableMouse then self:EnableMouse(false) end
            end
        end)
    end
end

function SuppressBlizzardTracker()
    local targetNames = {
        "QuestWatchFrame",               -- Classic Era (1.15) / Vanilla
        "WatchFrame",                    -- Wrath (3.4) / Cataclysm (4.4) Classic
        "ObjectiveTrackerFrame",         -- Modern Retail (10.x, 11.x, 12.x)
        "ObjectiveTrackerContainer",     -- Modern Retail container
        "ObjectiveTrackerBlocksFrame",   -- Modern Retail blocks
        "QuestObjectiveTracker",         -- Modern Retail modular quest tracker
        "CampaignQuestObjectiveTracker", -- Modern Retail campaign tracker
        "AchievementObjectiveTracker",   -- Modern Retail achievement tracker
        "ProfessionsRecipeTracker",      -- Modern Retail recipe tracker
        "MonthlyActivitiesObjectiveTracker",
        "ScenarioObjectiveTracker",
        "UIWidgetObjectiveTracker",
        "WorldQuestObjectiveTracker",
        "BonusObjectiveTracker",
    }

    for _, name in ipairs(targetNames) do
        local f = _G[name]
        if f then
            SuppressTrackerFrame(f)
        end
    end

    if ObjectiveTrackerFrame then
        if ObjectiveTrackerFrame.BlocksFrame then SuppressTrackerFrame(ObjectiveTrackerFrame.BlocksFrame) end
        if ObjectiveTrackerFrame.HeaderMenu then SuppressTrackerFrame(ObjectiveTrackerFrame.HeaderMenu) end
    end
end

-- =========================================================
-- Cross-Expansion Quest Helper (Retail 11.0 & Classic Era / Cata)
-- =========================================================
local function GetAllQuests()
    local quests = {}

    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
        local currentHeader = "World"
        for index = 1, numEntries do
            local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(index)
            if info then
                if info.isHeader then
                    currentHeader = info.title or "World"
                elseif not info.isHidden then
                    local qID = info.questID
                    local isWatched = false
                    if C_QuestLog.IsQuestWatched then
                        isWatched = C_QuestLog.IsQuestWatched(qID)
                    elseif IsQuestWatched then
                        isWatched = IsQuestWatched(index)
                    end

                    local objectives = {}
                    if C_QuestLog.GetQuestObjectives then
                        local objs = C_QuestLog.GetQuestObjectives(qID)
                        if objs then
                            for _, o in ipairs(objs) do
                                table.insert(objectives, { text = o.text or "", finished = o.finished or false })
                            end
                        end
                    end

                    if #objectives == 0 and GetNumQuestLeaderBoards then
                        local numLeaderBoards = GetNumQuestLeaderBoards(index) or 0
                        for objIdx = 1, numLeaderBoards do
                            local desc, objType, done = GetQuestLogLeaderBoard(objIdx, index)
                            if desc then
                                table.insert(objectives, { text = desc, finished = done or false })
                            end
                        end
                    end

                    local isComplete = false
                    if C_QuestLog.IsComplete then
                        isComplete = C_QuestLog.IsComplete(qID)
                    elseif GetQuestLogTitle then
                        local _, _, _, _, _, comp = GetQuestLogTitle(index)
                        isComplete = (comp == 1 or comp == true)
                    end

                    table.insert(quests, {
                        questID = qID,
                        logIndex = index,
                        title = info.title or "Quest",
                        level = info.level or 0,
                        header = currentHeader,
                        isComplete = isComplete or false,
                        isWatched = isWatched or false,
                        objectives = objectives
                    })
                end
            end
        end
    elseif GetNumQuestLogEntries then
        local numEntries = GetNumQuestLogEntries() or 0
        local currentHeader = "World"
        for index = 1, numEntries do
            local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(index)
            if isHeader then
                currentHeader = title or "World"
            elseif title then
                local isWatched = IsQuestWatched and IsQuestWatched(index)
                local objectives = {}
                local numLeaderBoards = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(index) or 0
                for objIdx = 1, numLeaderBoards do
                    local desc, objType, done = GetQuestLogLeaderBoard(objIdx, index)
                    if desc then
                        table.insert(objectives, { text = desc, finished = done or false })
                    end
                end

                table.insert(quests, {
                    questID = questID or index,
                    logIndex = index,
                    title = title,
                    level = level or 0,
                    header = currentHeader,
                    isComplete = (isComplete == 1 or isComplete == true),
                    isWatched = isWatched or false,
                    objectives = objectives
                })
            end
        end
    end

    return quests
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

    if questData.objectives and #questData.objectives > 0 then
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
    GameTooltip:AddLine("<Left-Click: Open Quest Map/Log>", 0.5, 0.8, 1)
    GameTooltip:AddLine("<Alt + Right-Click: Export to Dave's Notes>", 0.48, 0.82, 0.48)
    GameTooltip:Show()
end

-- =========================================================
-- Quest Map Helpers (POI coordinates & Map Layers)
-- =========================================================
local function GetMapForQuest(questID)
    if not questID then return nil end
    if C_QuestLog and C_QuestLog.GetMapForQuestPOIs then
        local mID = C_QuestLog.GetMapForQuestPOIs(questID)
        if mID and mID > 0 then return mID end
    end
    if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
        local mID = C_TaskQuest.GetQuestZoneID(questID)
        if mID and mID > 0 then return mID end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function GetQuestsOnCurrentMap(mapID)
    local results = {}
    if not mapID then return results end

    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local onMap = C_QuestLog.GetQuestsOnMap(mapID)
        if onMap then
            for _, q in ipairs(onMap) do
                table.insert(results, {
                    questID = q.questID,
                    x = q.x,
                    y = q.y,
                })
            end
        end
    end

    -- Legacy Classic POI fallback
    if #results == 0 and QuestPOIGetIconInfo then
        local allQuests = GetAllQuests()
        for _, q in ipairs(allQuests) do
            if q.questID then
                local completed, x, y = QuestPOIGetIconInfo(q.questID)
                if x and y and x > 0 and y > 0 then
                    table.insert(results, {
                        questID = q.questID,
                        x = x,
                        y = y,
                        completed = completed
                    })
                end
            end
        end
    end

    return results
end

local function GetActiveQuestMapIDs()
    local mapSet = {}
    local mapList = {}

    -- Player's current map first
    if C_Map and C_Map.GetBestMapForUnit then
        local pMap = C_Map.GetBestMapForUnit("player")
        if pMap and pMap > 0 then
            mapSet[pMap] = true
            table.insert(mapList, pMap)
        end
    end

    -- Maps for active quests
    local allQuests = GetAllQuests()
    for _, q in ipairs(allQuests) do
        local mID = GetMapForQuest(q.questID)
        if mID and mID > 0 and not mapSet[mID] then
            mapSet[mID] = true
            table.insert(mapList, mID)
        end
    end

    return mapList
end

-- =========================================================
-- Transparent HUD Quest Tracker (Replaces Default Tracker)
-- =========================================================
function BuildHUDTracker()
    if HUDTracker then return HUDTracker end

    local tracker = CreateFrame("Frame", "DavesQuestsHUDTracker", UIParent)
    tracker:SetSize(280, 450)
    tracker:SetPoint(DavesQuestsDB.hudPoint or "TOPRIGHT", UIParent, DavesQuestsDB.hudPoint or "TOPRIGHT", DavesQuestsDB.hudX or -15, DavesQuestsDB.hudY or -180)
    tracker:SetFrameStrata("MEDIUM")
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
        GameTooltip:AddLine("Left-Click a quest to view on Quest Map.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Drag with Left-Click to reposition.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("<Right-Click: Toggle Quest Window>", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dragHandle:SetScript("OnClick", function(self, button)
        if button == "RightButton" and type(ToggleQuestWindow) == "function" then
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
                    -- Open Dave's Quests with this quest focused on the map
                    OpenQuestWindow(self.questData.questID)
                elseif button == "RightButton" and type(ToggleQuestWindow) == "function" then
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

        local quests = GetAllQuests()

        local watched = {}
        for _, q in ipairs(quests) do
            if q.isWatched then
                table.insert(watched, q)
            end
        end

        local displayQuests = (#watched > 0) and watched or quests
        local maxDisplay = math.min(#displayQuests, 15)
        local currentY = 24

        for i = 1, maxDisplay do
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

        for i = maxDisplay + 1, #hudRows do
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

-- =========================================================
-- Main Quest Window GUI (Dave's Warm Parchment Theme & Map)
-- =========================================================
local function GetMapTileTexture(index)
    if not mapTilePool[index] then
        local t = mapCanvas:CreateTexture(nil, "BACKGROUND", nil, -5)
        mapTilePool[index] = t
    end
    return mapTilePool[index]
end

local function GetExplorationTileTexture(index)
    if not mapExplorationTilePool[index] then
        local t = mapCanvas:CreateTexture(nil, "BACKGROUND", nil, -4)
        mapExplorationTilePool[index] = t
    end
    return mapExplorationTilePool[index]
end

-- Completely Round Quest Pin Generator
local function GetQuestPin(index)
    if not questPinPool[index] then
        local pin = CreateFrame("Button", nil, mapCanvas)
        pin:SetSize(24, 24)
        pin:SetFrameLevel(mapCanvas:GetFrameLevel() + 6)

        -- Round background using native RadioButton circle
        pin.bg = pin:CreateTexture(nil, "BACKGROUND")
        pin.bg:SetTexture("Interface\\Buttons\\UI-RadioButton")
        pin.bg:SetTexCoord(0, 0.25, 0, 1) -- Smooth circular radio button outline & fill
        pin.bg:SetAllPoints(pin)

        -- Smooth circular alpha mask when supported
        if pin.CreateMaskTexture then
            local mask = pin:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(pin)
            pin.bg:AddMaskTexture(mask)
            pin.mask = mask
        end

        -- Round glowing highlight ring
        pin.highlight = pin:CreateTexture(nil, "OVERLAY")
        pin.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        pin.highlight:SetBlendMode("ADD")
        pin.highlight:SetVertexColor(1, 0.85, 0.20, 0.95)
        pin.highlight:SetAllPoints(pin)
        pin.highlight:Hide()

        pin.numText = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pin.numText:SetPoint("CENTER", pin, "CENTER", 0, 0)
        pin.numText:SetTextColor(1, 0.85, 0.35)

        pin:SetScript("OnEnter", function(self)
            if self.questData then
                ShowQuestObjectiveTooltip(self, self.questData)
            end
        end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pin:SetScript("OnClick", function(self)
            if self.questID then
                SelectQuest(self.questID)
            end
        end)

        questPinPool[index] = pin
    end
    return questPinPool[index]
end

-- Completely Round Gather Pin Generator
local function GetGatherPin(index)
    if not gatherPinPool[index] then
        local pin = CreateFrame("Button", nil, mapCanvas)
        pin:SetSize(16, 16)
        pin:SetFrameLevel(mapCanvas:GetFrameLevel() + 4)

        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints(pin)

        if pin.CreateMaskTexture then
            local mask = pin:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(pin)
            pin.icon:AddMaskTexture(mask)
        end

        pin.border = pin:CreateTexture(nil, "OVERLAY")
        pin.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        pin.border:SetSize(28, 28)
        pin.border:SetPoint("CENTER", pin, "CENTER", 6, -5)
        pin.border:SetVertexColor(0.2, 0.9, 0.2, 0.85)

        pin:SetScript("OnEnter", function(self)
            if self.nodeData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("|cffffd100[Gather]|r " .. (self.nodeData.name or "Resource"), 1, 0.82, 0)
                GameTooltip:AddLine(string.format("%s: %s (x%d)", self.nodeData.zone or "", self.nodeData.subZone or "", self.nodeData.count or 1), 0.9, 0.9, 0.9)
                GameTooltip:Show()
            end
        end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

        gatherPinPool[index] = pin
    end
    return gatherPinPool[index]
end

local function RefreshGatherPins(canvasW, canvasH)
    if not DavesGatherDB or not DavesGatherDB.nodes or not currentMapID or not DavesGatherDB.nodes[currentMapID] then
        for _, p in ipairs(gatherPinPool) do p:Hide() end
        return
    end

    local nodes = DavesGatherDB.nodes[currentMapID]
    local pinIdx = 1
    local maxGatherPins = 35

    -- Check if selected quest has an objective mentioning gather resources or drops
    local activeMatchText = nil
    if selectedQuestID then
        local allQuests = GetAllQuests()
        for _, q in ipairs(allQuests) do
            if q.questID == selectedQuestID and q.objectives then
                for _, obj in ipairs(q.objectives) do
                    if not obj.finished and obj.text then
                        activeMatchText = string.lower(obj.text)
                        break
                    end
                end
                break
            end
        end
    end

    for i = 1, math.min(#nodes, maxGatherPins) do
        local node = nodes[i]
        if node.x and node.y and node.x > 0 and node.y > 0 then
            local p = GetGatherPin(pinIdx)
            p.nodeData = node
            p.icon:SetTexture(node.icon or 134400)
            p:ClearAllPoints()
            p:SetPoint("CENTER", mapCanvas, "TOPLEFT", node.x * canvasW, -node.y * canvasH)

            -- Highlight node if matching active quest objective
            local isMatch = false
            if activeMatchText and node.name then
                local nodeName = string.lower(node.name)
                if string.find(activeMatchText, nodeName, 1, true) or string.find(nodeName, activeMatchText, 1, true) then
                    isMatch = true
                end
            end

            if isMatch then
                p:SetSize(22, 22)
                p.border:SetVertexColor(1.0, 0.85, 0.20, 1.0)
            else
                p:SetSize(16, 16)
                p.border:SetVertexColor(0.2, 0.9, 0.2, 0.85)
            end

            p:Show()
            pinIdx = pinIdx + 1
        end
    end

    for i = pinIdx, #gatherPinPool do
        gatherPinPool[i]:Hide()
    end
end

function CreateQuestAreaGlow()
    if questAreaGlow then return end

    -- 1. Inner glowing core beacon
    questAreaGlow = mapCanvas:CreateTexture(nil, "BACKGROUND", nil, -3)
    questAreaGlow:SetTexture("Interface\\Calendar\\EventNotificationGlow")
    questAreaGlow:SetBlendMode("ADD")
    questAreaGlow:SetVertexColor(0.20, 0.65, 1.0, 0.65)
    questAreaGlow:SetSize(114, 114)
    questAreaGlow:Hide()

    -- 2. Outer mob objective territory perimeter ring
    questAreaRing = mapCanvas:CreateTexture(nil, "BACKGROUND", nil, -2)
    questAreaRing:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    questAreaRing:SetBlendMode("ADD")
    questAreaRing:SetVertexColor(0.35, 0.85, 1.0, 0.90)
    questAreaRing:SetSize(124, 124)
    questAreaRing:Hide()

    -- 3. Dotted boundary radar border
    questAreaDotted = mapCanvas:CreateTexture(nil, "BACKGROUND", nil, -2)
    questAreaDotted:SetTexture("Interface\\Buttons\\UI-RadioButton")
    questAreaDotted:SetTexCoord(0, 0.25, 0, 1)
    questAreaDotted:SetBlendMode("ADD")
    questAreaDotted:SetVertexColor(0.50, 0.90, 1.0, 0.45)
    questAreaDotted:SetSize(132, 132)
    questAreaDotted:Hide()

    -- 4. Objective Mob Tag Badge (shows mob or objective name beneath the territory outline)
    questAreaMobTag = CreateFrame("Frame", nil, mapCanvas)
    questAreaMobTag:SetSize(130, 20)
    questAreaMobTag:SetFrameLevel(mapCanvas:GetFrameLevel() + 5)

    questAreaMobTag.bg = questAreaMobTag:CreateTexture(nil, "BACKGROUND")
    setTextureColor(questAreaMobTag.bg, 0.12, 0.09, 0.06, 0.85)
    questAreaMobTag.bg:SetAllPoints(questAreaMobTag)
    createBorder(questAreaMobTag, { 0.48, 0.36, 0.22 }, 1)

    questAreaMobText = questAreaMobTag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    questAreaMobText:SetPoint("CENTER", questAreaMobTag, "CENTER", 0, 0)
    questAreaMobText:SetTextColor(1, 0.85, 0.35)
    questAreaMobTag:Hide()
end

function UpdateQuestAreaGlow(pin, questData)
    CreateQuestAreaGlow()
    if not pin or not questData then
        if questAreaGlow then questAreaGlow:Hide() end
        if questAreaRing then questAreaRing:Hide() end
        if questAreaDotted then questAreaDotted:Hide() end
        if questAreaMobTag then questAreaMobTag:Hide() end
        return
    end

    local baseSize = 114 * math.min(1.8, math.max(1.0, zoomLevel * 0.85))

    -- Anchor directly to pin center: prevents drift regardless of zoom level, scroll, or resize
    questAreaGlow:ClearAllPoints()
    questAreaGlow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    questAreaGlow:SetSize(baseSize, baseSize)

    questAreaRing:ClearAllPoints()
    questAreaRing:SetPoint("CENTER", pin, "CENTER", 0, 0)
    questAreaRing:SetSize(baseSize + 10, baseSize + 10)

    questAreaDotted:ClearAllPoints()
    questAreaDotted:SetPoint("CENTER", pin, "CENTER", 0, 0)
    questAreaDotted:SetSize(baseSize + 18, baseSize + 18)

    questAreaMobTag:ClearAllPoints()
    questAreaMobTag:SetPoint("TOP", pin, "BOTTOM", 0, -(baseSize * 0.5) - 4)

    if questData.isComplete then
        questAreaGlow:SetVertexColor(0.20, 0.95, 0.35, 0.65)
        questAreaRing:SetVertexColor(0.35, 1.0, 0.45, 0.90)
        questAreaDotted:SetVertexColor(0.50, 1.0, 0.60, 0.45)
        questAreaMobText:SetText(ICON_CHECK .. " |cff55ff55Ready for turn-in!|r")
    else
        questAreaGlow:SetVertexColor(0.20, 0.65, 1.0, 0.65)
        questAreaRing:SetVertexColor(0.35, 0.85, 1.0, 0.90)
        questAreaDotted:SetVertexColor(0.50, 0.90, 1.0, 0.45)

        local mobDesc = nil
        if questData.objectives and #questData.objectives > 0 then
            for _, obj in ipairs(questData.objectives) do
                if not obj.finished and obj.text and obj.text ~= "" then
                    mobDesc = obj.text
                    break
                end
            end
            if not mobDesc and questData.objectives[1] then
                mobDesc = questData.objectives[1].text
            end
        end

        if not mobDesc or mobDesc == "" then
            mobDesc = questData.title or "Quest Objective"
        end

        if #mobDesc > 26 then
            mobDesc = string.sub(mobDesc, 1, 24) .. "..."
        end
        questAreaMobText:SetText(string.format("|cffffd100%s|r", mobDesc))
    end

    local textW = questAreaMobText:GetStringWidth() or 90
    questAreaMobTag:SetWidth(math.max(110, textW + 16))

    questAreaGlow:Show()
    questAreaRing:Show()
    questAreaDotted:Show()
    questAreaMobTag:Show()
end

function RefreshMapPins()
    if not currentMapID or not mapCanvas or not mapCanvas:IsShown() then return end

    local canvasW = mapCanvas:GetWidth()
    local canvasH = mapCanvas:GetHeight()
    if canvasW <= 0 or canvasH <= 0 then return end

    local mapQuests = GetQuestsOnCurrentMap(currentMapID)
    local allActiveQuests = GetAllQuests()
    local questLookup = {}
    for idx, q in ipairs(allActiveQuests) do
        questLookup[q.questID] = { data = q, number = idx }
    end

    local pinIdx = 1
    local selectedPin = nil
    local selectedPinData = nil

    for _, mq in ipairs(mapQuests) do
        local qInfo = questLookup[mq.questID]
        local pin = GetQuestPin(pinIdx)
        pin.questID = mq.questID
        pin.questData = qInfo and qInfo.data

        local num = qInfo and qInfo.number or pinIdx
        if qInfo and qInfo.data and qInfo.data.isComplete then
            pin.numText:SetText(ICON_CHECK)
        else
            pin.numText:SetText(tostring(num))
        end

        pin:ClearAllPoints()
        pin:SetPoint("CENTER", mapCanvas, "TOPLEFT", mq.x * canvasW, -mq.y * canvasH)

        if selectedQuestID and selectedQuestID == mq.questID then
            pin.highlight:Show()
            pin:SetSize(28, 28)
            selectedPin = pin
            selectedPinData = qInfo and qInfo.data
        else
            pin.highlight:Hide()
            pin:SetSize(22, 22)
        end

        pin:Show()
        pinIdx = pinIdx + 1
    end

    for i = pinIdx, #questPinPool do
        questPinPool[i]:Hide()
    end

    -- Update Quest Mob Area Glow & Perimeter Ring (anchored firmly to selectedPin)
    if selectedPin and selectedPinData then
        UpdateQuestAreaGlow(selectedPin, selectedPinData)
    else
        UpdateQuestAreaGlow(nil, nil)
    end

    -- Update Player Position Pin
    if C_Map and C_Map.GetPlayerMapPosition then
        local playerPos = C_Map.GetPlayerMapPosition(currentMapID, "player")
        if playerPos and playerPin then
            local px, py = playerPos:GetXY()
            if px and py and px > 0 and py > 0 then
                playerPin:ClearAllPoints()
                playerPin:SetPoint("CENTER", mapCanvas, "TOPLEFT", px * canvasW, -py * canvasH)
                if GetPlayerFacing then
                    playerPin.arrow:SetRotation(GetPlayerFacing() or 0)
                end
                playerPin:Show()
            else
                playerPin:Hide()
            end
        elseif playerPin then
            playerPin:Hide()
        end
    elseif playerPin then
        playerPin:Hide()
    end

    -- Gather Synergy Pins
    RefreshGatherPins(canvasW, canvasH)
end

function ZoomMap(newZoom, targetNormX, targetNormY)
    newZoom = math.max(1.0, math.min(3.0, math.floor(newZoom * 100 + 0.5) / 100))
    local oldZoom = zoomLevel
    zoomLevel = newZoom

    if zoomText then
        zoomText:SetText(string.format("%d%%", math.floor(zoomLevel * 100)))
    end

    local newW = BASE_MAP_WIDTH * zoomLevel
    local newH = BASE_MAP_HEIGHT * zoomLevel
    mapCanvas:SetSize(newW, newH)

    if currentMapID then
        LoadZoneMap(currentMapID, true)
    end

    if mapScrollFrame then
        local maxScrollX = math.max(0, newW - mapScrollFrame:GetWidth())
        local maxScrollY = math.max(0, newH - mapScrollFrame:GetHeight())

        if zoomLevel == 1.0 then
            mapScrollFrame:SetHorizontalScroll(0)
            mapScrollFrame:SetVerticalScroll(0)
        else
            if not targetNormX and selectedQuestID and currentMapID then
                local mapQuests = GetQuestsOnCurrentMap(currentMapID)
                for _, mq in ipairs(mapQuests) do
                    if mq.questID == selectedQuestID then
                        targetNormX = mq.x
                        targetNormY = mq.y
                        break
                    end
                end
            end

            if targetNormX and targetNormY then
                local targetScrollX = math.max(0, math.min(maxScrollX, targetNormX * newW - mapScrollFrame:GetWidth() / 2))
                local targetScrollY = math.max(0, math.min(maxScrollY, targetNormY * newH - mapScrollFrame:GetHeight() / 2))
                mapScrollFrame:SetHorizontalScroll(targetScrollX)
                mapScrollFrame:SetVerticalScroll(targetScrollY)
            else
                local ratio = zoomLevel / math.max(1.0, oldZoom)
                local curScrollX = mapScrollFrame:GetHorizontalScroll()
                local curScrollY = mapScrollFrame:GetVerticalScroll()
                local newScrollX = math.max(0, math.min(maxScrollX, (curScrollX + mapScrollFrame:GetWidth() / 2) * ratio - mapScrollFrame:GetWidth() / 2))
                local newScrollY = math.max(0, math.min(maxScrollY, (curScrollY + mapScrollFrame:GetHeight() / 2) * ratio - mapScrollFrame:GetHeight() / 2))
                mapScrollFrame:SetHorizontalScroll(newScrollX)
                mapScrollFrame:SetVerticalScroll(newScrollY)
            end
        end
    end
end

function LoadZoneMap(mapID, keepZoom)
    if not mapID or mapID <= 0 then return end
    currentMapID = mapID

    if not keepZoom and zoomLevel ~= 1.0 then
        ZoomMap(1.0)
    end

    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or "Zone Map"
    if mapTitle then
        mapTitle:SetText(string.format("|cffffd100%s|r", zoneName))
    end

    local loadedTiles = false
    local canvasW = mapCanvas:GetWidth()
    local canvasH = mapCanvas:GetHeight()
    local layerW = 1002
    local layerH = 668

    -- 1. Base detail tiles
    if C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures and mapCanvas then
        local layers = C_Map.GetMapArtLayers(mapID)
        if layers and layers[1] then
            local lInfo = layers[1]
            layerW = (lInfo.layerWidth and lInfo.layerWidth > 0) and lInfo.layerWidth or 1002
            layerH = (lInfo.layerHeight and lInfo.layerHeight > 0) and lInfo.layerHeight or 668
            local rows = lInfo.numDetailTilesRows or 3
            local cols = lInfo.numDetailTilesCols or 4
            local textures = C_Map.GetMapArtLayerTextures(mapID, 1)

            if textures and #textures > 0 then
                local tileW = canvasW / cols
                local tileH = canvasH / rows

                local idx = 1
                for r = 0, rows - 1 do
                    for c = 0, cols - 1 do
                        if textures[idx] then
                            local t = GetMapTileTexture(idx)
                            t:ClearAllPoints()
                            t:SetPoint("TOPLEFT", mapCanvas, "TOPLEFT", c * tileW, -r * tileH)
                            t:SetSize(tileW, tileH)
                            t:SetTexture(textures[idx])
                            t:Show()
                        end
                        idx = idx + 1
                    end
                end

                for i = idx, #mapTilePool do
                    mapTilePool[i]:Hide()
                end

                loadedTiles = true
            end
        end
    end

    -- 2. Exploration / Uncovered Overlay Tiles (Reveals uncovered subzones on the map)
    local expIdx = 1
    if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures and mapCanvas then
        local scaleX = canvasW / layerW
        local scaleY = canvasH / layerH

        -- Render player's explored/uncovered subzones
        local okExp, exploredTextures = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
        if okExp and exploredTextures and #exploredTextures > 0 then
            for _, exp in ipairs(exploredTextures) do
                local texID = exp.fileDataID or exp.textureFileID or exp.texture or exp.textureID
                if texID then
                    local t = GetExplorationTileTexture(expIdx)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", mapCanvas, "TOPLEFT", (exp.offsetX or 0) * scaleX, -(exp.offsetY or 0) * scaleY)
                    t:SetSize((exp.textureWidth or 256) * scaleX, (exp.textureHeight or 256) * scaleY)
                    t:SetTexture(texID)
                    t:SetAlpha(1.0)
                    t:Show()
                    expIdx = expIdx + 1
                    loadedTiles = true
                end
            end
        end

        -- If full map reveal is toggled on, also render unexplored tiles
        if DavesQuestsDB.revealAllMap and C_MapExplorationInfo.GetUnexploredMapTextures then
            local okUnexp, unexploredTextures = pcall(C_MapExplorationInfo.GetUnexploredMapTextures, mapID)
            if okUnexp and unexploredTextures and #unexploredTextures > 0 then
                for _, unexp in ipairs(unexploredTextures) do
                    local texID = unexp.fileDataID or unexp.textureFileID or unexp.texture or unexp.textureID
                    if texID then
                        local t = GetExplorationTileTexture(expIdx)
                        t:ClearAllPoints()
                        t:SetPoint("TOPLEFT", mapCanvas, "TOPLEFT", (unexp.offsetX or 0) * scaleX, -(unexp.offsetY or 0) * scaleY)
                        t:SetSize((unexp.textureWidth or 256) * scaleX, (unexp.textureHeight or 256) * scaleY)
                        t:SetTexture(texID)
                        t:SetAlpha(0.60)
                        t:Show()
                        expIdx = expIdx + 1
                    end
                end
            end
        end
    end

    -- Hide unused exploration overlay tiles
    for i = expIdx, #mapExplorationTilePool do
        mapExplorationTilePool[i]:Hide()
    end

    if mapFallbackBg then
        if not loadedTiles then
            for _, t in ipairs(mapTilePool) do t:Hide() end
            for _, t in ipairs(mapExplorationTilePool) do t:Hide() end
            mapFallbackBg:Show()
        else
            mapFallbackBg:Hide()
        end
    end

    RefreshMapPins()
end

function SelectQuest(questID)
    selectedQuestID = questID

    local allQuests = GetAllQuests()
    local selectedData = nil
    for _, q in ipairs(allQuests) do
        if q.questID == questID then
            selectedData = q
            break
        end
    end

    if selectedData then
        local qMap = GetMapForQuest(questID)
        if qMap and qMap > 0 and qMap ~= currentMapID then
            LoadZoneMap(qMap)
        else
            RefreshMapPins()
        end

        -- Auto-center on quest coordinates if zoomed in
        local mapQuests = GetQuestsOnCurrentMap(currentMapID)
        local targetX, targetY = nil, nil
        for _, mq in ipairs(mapQuests) do
            if mq.questID == questID then
                targetX = mq.x
                targetY = mq.y
                break
            end
        end

        if targetX and targetY and zoomLevel > 1.0 then
            ZoomMap(zoomLevel, targetX, targetY)
        end

        -- Update bottom card details
        if mapDetailsText then
            local objLines = {}
            if selectedData.isComplete then
                table.insert(objLines, ICON_CHECK .. " |cff008800Ready for turn-in!|r")
            elseif selectedData.objectives and #selectedData.objectives > 0 then
                for _, obj in ipairs(selectedData.objectives) do
                    local mark = obj.finished and ICON_CHECK or ICON_UNCHECK
                    local col = obj.finished and "|cff008800" or "|cff222222"
                    table.insert(objLines, string.format("%s %s%s|r", mark, col, obj.text or ""))
                end
            else
                table.insert(objLines, ICON_UNCHECK .. " |cff666666In progress...|r")
            end

            mapDetailsText:SetText(string.format("|cff552200[%d] %s|r\n%s", selectedData.level or 0, selectedData.title or "Quest", table.concat(objLines, "\n")))
        end
    end

    if questWindow and questWindow.RefreshQuests then
        questWindow:RefreshQuests()
    end
end

function BuildQuestWindow()
    if questWindow then return questWindow end

    local frame = CreateFrame("Frame", "DavesQuestsFrame", UIParent)
    frame:SetSize(790, 530)
    frame:SetPoint(DavesQuestsDB.point or "TOPRIGHT", UIParent, DavesQuestsDB.point or "TOPRIGHT", DavesQuestsDB.x or -20, DavesQuestsDB.y or -80)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)

    applyWindowBackground(frame)
    createBorder(frame, WINDOW_BORDER_COLOR, 3)
    registerEscapeFrame("DavesQuestsFrame")

    -- Draggable Header
    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    header:SetHeight(48)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")

    applyWindowBackground(header)
    createBorder(header, WINDOW_BORDER_COLOR, 2)

    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local pt, _, relPt, x, y = frame:GetPoint()
        DavesQuestsDB.point = pt
        DavesQuestsDB.x = x
        DavesQuestsDB.y = y
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 12, -8)
    title:SetText("Dave's Quests")
    title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])

    local subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subTitle:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 12, 6)
    subTitle:SetText("Quest Log & Live Map")
    subTitle:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    frame.subTitle = subTitle

    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Option Toggles Bar
    local optionsBar = CreateFrame("Frame", nil, frame)
    optionsBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    optionsBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    optionsBar:SetHeight(26)

    -- Toggle 1: Quest Map Pane
    local mapCheck = CreateFrame("CheckButton", "DavesQuestsMapCheck", optionsBar, "UICheckButtonTemplate")
    mapCheck:SetSize(22, 22)
    mapCheck:SetPoint("LEFT", optionsBar, "LEFT", 8, 0)
    _G[mapCheck:GetName() .. "Text"]:SetText("Quest Map")
    _G[mapCheck:GetName() .. "Text"]:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    mapCheck:SetChecked(DavesQuestsDB.showMapPane == true)
    mapCheck:SetScript("OnClick", function(self)
        DavesQuestsDB.showMapPane = self:GetChecked()
        UpdateWindowLayout()
    end)

    -- Toggle 2: HUD Tracker
    local hudCheck = CreateFrame("CheckButton", "DavesQuestsHUDCheck", optionsBar, "UICheckButtonTemplate")
    hudCheck:SetSize(22, 22)
    hudCheck:SetPoint("LEFT", mapCheck, "RIGHT", 85, 0)
    _G[hudCheck:GetName() .. "Text"]:SetText("HUD Tracker")
    _G[hudCheck:GetName() .. "Text"]:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    hudCheck:SetChecked(DavesQuestsDB.showHUDTracker == true)
    hudCheck:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        DavesQuestsDB.showHUDTracker = isChecked
        if not HUDTracker then BuildHUDTracker() end
        if isChecked then
            HUDTracker:Refresh()
            HUDTracker:Show()
        else
            HUDTracker:Hide()
        end
    end)

    -- Toggle 3: Hide Default Tracker
    local blizzCheck = CreateFrame("CheckButton", "DavesQuestsBlizzCheck", optionsBar, "UICheckButtonTemplate")
    blizzCheck:SetSize(22, 22)
    blizzCheck:SetPoint("LEFT", hudCheck, "RIGHT", 95, 0)
    _G[blizzCheck:GetName() .. "Text"]:SetText("Hide Default Tracker")
    _G[blizzCheck:GetName() .. "Text"]:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    blizzCheck:SetChecked(DavesQuestsDB.hideBlizzTracker == true)
    blizzCheck:SetScript("OnClick", function(self)
        DavesQuestsDB.hideBlizzTracker = self:GetChecked()
        SuppressBlizzardTracker()
    end)

    -- Toggle 4: Reveal Entire Map
    local revealCheck = CreateFrame("CheckButton", "DavesQuestsRevealCheck", optionsBar, "UICheckButtonTemplate")
    revealCheck:SetSize(22, 22)
    revealCheck:SetPoint("LEFT", blizzCheck, "RIGHT", 130, 0)
    _G[revealCheck:GetName() .. "Text"]:SetText("Reveal Entire Map")
    _G[revealCheck:GetName() .. "Text"]:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])
    revealCheck:SetChecked(DavesQuestsDB.revealAllMap == true)
    revealCheck:SetScript("OnClick", function(self)
        DavesQuestsDB.revealAllMap = self:GetChecked()
        if btnUncover and btnUncover.UpdateText then
            btnUncover:UpdateText()
        end
        if currentMapID then
            LoadZoneMap(currentMapID, true)
        end
    end)

    -- =========================================================
    -- Left Pane: Quest Map Panel with Zooming & Panning
    -- =========================================================
    mapPanel = CreateFrame("Frame", nil, frame)
    mapPanel:SetPoint("TOPLEFT", optionsBar, "BOTTOMLEFT", 8, -4)
    mapPanel:SetSize(420, 444)

    -- Map Navigation & Zoom Bar
    local mapTopBar = CreateFrame("Frame", nil, mapPanel)
    mapTopBar:SetPoint("TOPLEFT", mapPanel, "TOPLEFT", 0, 0)
    mapTopBar:SetPoint("TOPRIGHT", mapPanel, "TOPRIGHT", 0, 0)
    mapTopBar:SetHeight(26)

    local btnPrev = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnPrev:SetSize(20, 20)
    btnPrev:SetPoint("LEFT", mapTopBar, "LEFT", 0, 0)
    btnPrev:SetText("<")
    btnPrev:SetScript("OnClick", function()
        local maps = GetActiveQuestMapIDs()
        if #maps == 0 then return end
        local idx = 1
        for i, m in ipairs(maps) do
            if m == currentMapID then idx = i break end
        end
        local prevIdx = (idx > 1) and (idx - 1) or #maps
        LoadZoneMap(maps[prevIdx])
    end)

    local btnNext = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnNext:SetSize(20, 20)
    btnNext:SetPoint("LEFT", btnPrev, "RIGHT", 2, 0)
    btnNext:SetText(">")
    btnNext:SetScript("OnClick", function()
        local maps = GetActiveQuestMapIDs()
        if #maps == 0 then return end
        local idx = 1
        for i, m in ipairs(maps) do
            if m == currentMapID then idx = i break end
        end
        local nextIdx = (idx < #maps) and (idx + 1) or 1
        LoadZoneMap(maps[nextIdx])
    end)

    local btnFullMap = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnFullMap:SetSize(58, 20)
    btnFullMap:SetPoint("RIGHT", mapTopBar, "RIGHT", 0, 0)
    btnFullMap:SetText("Full Map")
    btnFullMap:SetScript("OnClick", function()
        if ToggleWorldMap then
            ToggleWorldMap()
            if WorldMapFrame and WorldMapFrame.SetMapID and currentMapID then
                WorldMapFrame:SetMapID(currentMapID)
            end
        end
    end)

    local btnMyZone = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnMyZone:SetSize(58, 20)
    btnMyZone:SetPoint("RIGHT", btnFullMap, "LEFT", -2, 0)
    btnMyZone:SetText("My Zone")
    btnMyZone:SetScript("OnClick", function()
        if C_Map and C_Map.GetBestMapForUnit then
            local pMap = C_Map.GetBestMapForUnit("player")
            if pMap then LoadZoneMap(pMap) end
        end
    end)

    -- Map Uncovered / Exploration Toggle Button
    btnUncover = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnUncover:SetSize(68, 20)
    btnUncover:SetPoint("RIGHT", btnMyZone, "LEFT", -2, 0)

    function btnUncover:UpdateText()
        if DavesQuestsDB.revealAllMap then
            self:SetText("|cff00ff00All Map|r")
        else
            self:SetText("Uncovered")
        end
    end
    btnUncover:UpdateText()

    btnUncover:SetScript("OnClick", function(self)
        DavesQuestsDB.revealAllMap = not DavesQuestsDB.revealAllMap
        self:UpdateText()
        local chk = _G["DavesQuestsRevealCheck"]
        if chk then chk:SetChecked(DavesQuestsDB.revealAllMap) end
        if currentMapID then
            LoadZoneMap(currentMapID, true)
        end
    end)

    btnUncover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Map Exploration Toggle", 1, 0.82, 0)
        GameTooltip:AddLine("Mode: " .. (DavesQuestsDB.revealAllMap and "|cff00ff00All Map Revealed|r" or "|cffffd100Uncovered Areas Only|r"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Click to toggle between showing only your discovered uncovered areas vs revealing the full zone map.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btnUncover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Zoom Controls: [-] [100%] [+]
    local btnZoomIn = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnZoomIn:SetSize(18, 20)
    btnZoomIn:SetPoint("RIGHT", btnUncover, "LEFT", -4, 0)
    btnZoomIn:SetText("+")
    btnZoomIn:SetScript("OnClick", function()
        ZoomMap(zoomLevel + 0.25)
    end)

    zoomText = mapTopBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoomText:SetPoint("RIGHT", btnZoomIn, "LEFT", -2, 0)
    zoomText:SetSize(32, 20)
    zoomText:SetJustifyH("CENTER")
    zoomText:SetText("100%")

    local btnZoomOut = CreateFrame("Button", nil, mapTopBar, "UIPanelButtonTemplate")
    btnZoomOut:SetSize(18, 20)
    btnZoomOut:SetPoint("RIGHT", zoomText, "LEFT", -2, 0)
    btnZoomOut:SetText("-")
    btnZoomOut:SetScript("OnClick", function()
        ZoomMap(zoomLevel - 0.25)
    end)

    mapTitle = mapTopBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapTitle:SetPoint("LEFT", btnNext, "RIGHT", 6, 0)
    mapTitle:SetPoint("RIGHT", btnZoomOut, "LEFT", -4, 0)
    mapTitle:SetJustifyH("LEFT")
    mapTitle:SetText("Zone Map")

    -- ScrollFrame Viewport for Zoomable & Pannable Map
    mapScrollFrame = CreateFrame("ScrollFrame", "DavesQuestsMapScrollFrame", mapPanel)
    mapScrollFrame:SetPoint("TOPLEFT", mapTopBar, "BOTTOMLEFT", 0, -2)
    mapScrollFrame:SetSize(BASE_MAP_WIDTH, BASE_MAP_HEIGHT)
    mapScrollFrame:EnableMouse(true)
    mapScrollFrame:EnableMouseWheel(true)
    mapScrollFrame:SetClipsChildren(true)
    createBorder(mapScrollFrame, WINDOW_BORDER_COLOR, 2)

    -- Map Canvas Viewport (ScrollChild)
    mapCanvas = CreateFrame("Frame", nil, mapScrollFrame)
    mapCanvas:SetSize(BASE_MAP_WIDTH, BASE_MAP_HEIGHT)
    mapScrollFrame:SetScrollChild(mapCanvas)

    mapFallbackBg = mapCanvas:CreateTexture(nil, "BACKGROUND")
    setTextureColor(mapFallbackBg, 0.90, 0.85, 0.72, 1.0)
    mapFallbackBg:SetAllPoints(mapCanvas)

    -- Interactive Mouse Wheel Zooming
    mapScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            ZoomMap(zoomLevel + 0.25)
        else
            ZoomMap(zoomLevel - 0.25)
        end
    end)

    -- Drag to Pan Map Viewport when Zoomed
    local isDragging = false
    local startCursorX, startCursorY = 0, 0
    local startScrollX, startScrollY = 0, 0

    mapScrollFrame:SetScript("OnMouseDown", function(self, button)
        if (button == "LeftButton" or button == "RightButton") and zoomLevel > 1.0 then
            isDragging = true
            local scale = self:GetEffectiveScale()
            startCursorX, startCursorY = GetCursorPosition()
            startCursorX = startCursorX / scale
            startCursorY = startCursorY / scale
            startScrollX = self:GetHorizontalScroll()
            startScrollY = self:GetVerticalScroll()
        end
    end)

    mapScrollFrame:SetScript("OnMouseUp", function()
        isDragging = false
    end)

    mapScrollFrame:SetScript("OnUpdate", function(self)
        if isDragging and zoomLevel > 1.0 then
            local scale = self:GetEffectiveScale()
            local curX, curY = GetCursorPosition()
            curX = curX / scale
            curY = curY / scale

            local deltaX = startCursorX - curX
            local deltaY = curY - startCursorY

            local maxScrollX = math.max(0, mapCanvas:GetWidth() - self:GetWidth())
            local maxScrollY = math.max(0, mapCanvas:GetHeight() - self:GetHeight())

            local newScrollX = math.max(0, math.min(maxScrollX, startScrollX + deltaX))
            local newScrollY = math.max(0, math.min(maxScrollY, startScrollY + deltaY))

            self:SetHorizontalScroll(newScrollX)
            self:SetVerticalScroll(newScrollY)
        end
    end)

    -- Player Location Pin with Heading Arrow
    playerPin = CreateFrame("Frame", nil, mapCanvas)
    playerPin:SetSize(22, 22)
    playerPin:SetFrameLevel(mapCanvas:GetFrameLevel() + 10)

    playerPin.arrow = playerPin:CreateTexture(nil, "OVERLAY")
    playerPin.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    playerPin.arrow:SetAllPoints(playerPin)
    playerPin:Hide()

    -- Live GPS updater & Glowing Area Pulse Animation
    local updateTimer = 0
    mapCanvas:SetScript("OnUpdate", function(self, elapsed)
        -- Glowing quest mob area pulsating radar animation
        if questAreaGlow and questAreaGlow:IsShown() then
            local t = GetTime() * 3.2
            local pulseAlpha = 0.45 + 0.35 * math.sin(t)
            questAreaGlow:SetAlpha(pulseAlpha)

            if questAreaRing and questAreaRing:IsShown() then
                local ringScale = 1.0 + 0.08 * math.sin(t)
                local baseSize = 114 * math.min(1.8, math.max(1.0, zoomLevel * 0.85))
                questAreaRing:SetSize((baseSize + 10) * ringScale, (baseSize + 10) * ringScale)

                if questAreaDotted and questAreaDotted:IsShown() then
                    local dotScale = 1.0 - 0.06 * math.sin(t)
                    questAreaDotted:SetSize((baseSize + 18) * dotScale, (baseSize + 18) * dotScale)
                end
            end
        end

        -- GPS Player Position Update
        updateTimer = updateTimer + elapsed
        if updateTimer >= 0.25 then
            updateTimer = 0
            if currentMapID and C_Map and C_Map.GetPlayerMapPosition then
                local pos = C_Map.GetPlayerMapPosition(currentMapID, "player")
                if pos and playerPin then
                    local px, py = pos:GetXY()
                    if px and py and px > 0 and py > 0 then
                        local cw = self:GetWidth()
                        local ch = self:GetHeight()
                        playerPin:ClearAllPoints()
                        playerPin:SetPoint("CENTER", self, "TOPLEFT", px * cw, -py * ch)
                        if GetPlayerFacing then
                            playerPin.arrow:SetRotation(GetPlayerFacing() or 0)
                        end
                        playerPin:Show()
                    else
                        playerPin:Hide()
                    end
                elseif playerPin then
                    playerPin:Hide()
                end
            elseif playerPin then
                playerPin:Hide()
            end
        end
    end)

    -- Map Bottom Details Card
    local detailsCard = CreateFrame("Frame", nil, mapPanel)
    detailsCard:SetPoint("TOPLEFT", mapScrollFrame, "BOTTOMLEFT", 0, -4)
    detailsCard:SetPoint("BOTTOMRIGHT", mapPanel, "BOTTOMRIGHT", 0, 0)

    detailsCard.bg = detailsCard:CreateTexture(nil, "BACKGROUND")
    setTextureColor(detailsCard.bg, 0.99, 0.98, 0.94, 1.0)
    detailsCard.bg:SetAllPoints(detailsCard)
    createBorder(detailsCard, { 0.45, 0.32, 0.18 }, 1)

    mapDetailsText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapDetailsText:SetPoint("TOPLEFT", detailsCard, "TOPLEFT", 8, -6)
    mapDetailsText:SetPoint("BOTTOMRIGHT", detailsCard, "BOTTOMRIGHT", -8, 6)
    mapDetailsText:SetJustifyH("LEFT")
    mapDetailsText:SetJustifyV("TOP")
    mapDetailsText:SetWordWrap(true)
    mapDetailsText:SetText("|cff664422Select a quest on the right or a pin on the map to inspect.|r")

    -- =========================================================
    -- Right Pane: Scrollable Quest Log List
    -- =========================================================
    local scroll = CreateFrame("ScrollFrame", "DavesQuestsScrollFrame", frame, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)

    frame.emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.emptyText:SetPoint("CENTER", scroll, "CENTER", 0, 0)
    frame.emptyText:SetWidth(260)
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetText("No active quests tracked.")
    frame.emptyText:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])

    -- Layout Switcher (Two-Pane Map vs Single-Pane Compact)
    function UpdateWindowLayout()
        if DavesQuestsDB.showMapPane then
            frame:SetSize(790, 530)
            mapPanel:Show()
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT", mapPanel, "TOPRIGHT", 10, 0)
            scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)
            content:SetWidth(320)
            if not currentMapID then
                local pMap = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 1
                LoadZoneMap(pMap)
            else
                LoadZoneMap(currentMapID)
            end
        else
            frame:SetSize(350, 530)
            mapPanel:Hide()
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT", optionsBar, "BOTTOMLEFT", 6, -4)
            scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)
            content:SetWidth(306)
        end
        if frame.RefreshQuests then frame:RefreshQuests() end
    end

    -- Quest Row Generator
    local function GetQuestRow(index)
        if not questRows[index] then
            local row = CreateFrame("Button", nil, content)
            row:SetWidth(310)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            setTextureColor(row.bg, 0.99, 0.98, 0.94, 1.0)
            row.bg:SetAllPoints(row)
            createBorder(row, { 0.45, 0.32, 0.18 }, 1)

            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(row.highlight, 1, 0.85, 0.40, 0.35)
            row.highlight:SetAllPoints(row)

            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
            row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
            row.title:SetJustifyH("LEFT")
            row.title:SetWordWrap(true)
            row.title:SetTextColor(0.50, 0.22, 0.02)

            row.objText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.objText:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -6)
            row.objText:SetWidth(290)
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
                    SelectQuest(self.questData.questID)
                end
            end)

            questRows[index] = row
        end
        return questRows[index]
    end

    function frame:RefreshQuests()
        local quests = GetAllQuests()

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

            local isSelected = (selectedQuestID and selectedQuestID == qData.questID)
            if isSelected then
                setTextureColor(row.bg, 1.0, 0.98, 0.90, 1.0)
                createBorder(row, { 1, 0.82, 0.30 }, 2)
            else
                setTextureColor(row.bg, 0.99, 0.98, 0.94, 1.0)
                createBorder(row, { 0.45, 0.32, 0.18 }, 1)
            end

            local completedBadge = qData.isComplete and (" |cff008800(Complete)|r") or ""
            row.title:SetText(string.format("[%d] %s%s", i, qData.title or "Quest", completedBadge))

            local objLines = {}
            if qData.isComplete then
                table.insert(objLines, ICON_CHECK .. " |cff008800Ready for turn-in!|r")
            elseif qData.objectives and #qData.objectives > 0 then
                for _, obj in ipairs(qData.objectives) do
                    if obj.finished then
                        table.insert(objLines, ICON_CHECK .. " |cff008800" .. (obj.text or "") .. "|r")
                    else
                        table.insert(objLines, ICON_UNCHECK .. " |cff222222" .. (obj.text or "") .. "|r")
                    end
                end
            else
                table.insert(objLines, ICON_UNCHECK .. " |cff666666In progress...|r")
            end

            row.objText:SetText(table.concat(objLines, "\n"))

            local cardW = DavesQuestsDB.showMapPane and 318 or 306
            row:SetWidth(cardW)
            row.title:SetWidth(cardW - 20)
            row.objText:SetWidth(cardW - 20)

            local tHeight = row.title:GetStringHeight() or 16
            local oHeight = row.objText:GetStringHeight() or 16
            local rowHeight = tHeight + oHeight + 22

            row:SetSize(cardW, rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -currentY)
            row:Show()

            currentY = currentY + rowHeight + 8
        end

        for i = #quests + 1, #questRows do
            questRows[i]:Hide()
        end

        content:SetHeight(math.max(1, currentY))
    end

    UpdateWindowLayout()

    questWindow = frame
    return frame
end

function OpenQuestWindow(questID)
    if not questWindow then
        BuildQuestWindow()
    end

    if not questWindow:IsShown() then
        questWindow:Show()
    end
    questWindow:Raise()

    if questID then
        SelectQuest(questID)
    else
        questWindow:RefreshQuests()
        if DavesQuestsDB.showMapPane and not currentMapID then
            local pMap = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 1
            LoadZoneMap(pMap)
        end
    end
end

function ToggleQuestWindow()
    if not questWindow then
        BuildQuestWindow()
    end

    if questWindow:IsShown() then
        questWindow:Hide()
    else
        OpenQuestWindow(selectedQuestID)
    end
end

-- =========================================================
-- Slash Commands
-- =========================================================
local function HandleSlashCmd(msg)
    local cmd = string.lower(strtrim(msg or ""))
    if cmd == "hud" then
        DavesQuestsDB.showHUDTracker = not DavesQuestsDB.showHUDTracker
        if not HUDTracker then BuildHUDTracker() end
        if DavesQuestsDB.showHUDTracker then
            HUDTracker:Refresh()
            HUDTracker:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r HUD Tracker enabled.")
        else
            HUDTracker:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Dave's Quests]|r HUD Tracker disabled.")
        end
        if DavesQuestsHUDCheck then
            DavesQuestsHUDCheck:SetChecked(DavesQuestsDB.showHUDTracker == true)
        end
    elseif cmd == "blizz" then
        DavesQuestsDB.hideBlizzTracker = not DavesQuestsDB.hideBlizzTracker
        SuppressBlizzardTracker()
        if DavesQuestsBlizzCheck then
            DavesQuestsBlizzCheck:SetChecked(DavesQuestsDB.hideBlizzTracker == true)
        end
        if DavesQuestsDB.hideBlizzTracker then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r Default Blizzard tracker hidden.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Dave's Quests]|r Default Blizzard tracker restored.")
        end
    elseif cmd == "map" then
        DavesQuestsDB.showMapPane = not DavesQuestsDB.showMapPane
        if DavesQuestsMapCheck then
            DavesQuestsMapCheck:SetChecked(DavesQuestsDB.showMapPane == true)
        end
        if UpdateWindowLayout then UpdateWindowLayout() end
        if DavesQuestsDB.showMapPane then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Quests]|r Quest Map pane shown.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Dave's Quests]|r Quest Map pane hidden.")
        end
    else
        ToggleQuestWindow()
    end
end

SLASH_DAVESQUESTS1 = "/davesquests"
SLASH_DAVESQUESTS2 = "/dquests"
SLASH_DAVESQUESTS3 = "/dq"
SlashCmdList["DAVESQUESTS"] = HandleSlashCmd

-- =========================================================
-- Event Handling (Live Tracking & Suppression)
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            InitDB()
            if DavesQuestsHUDCheck then
                DavesQuestsHUDCheck:SetChecked(DavesQuestsDB.showHUDTracker == true)
            end
            if DavesQuestsBlizzCheck then
                DavesQuestsBlizzCheck:SetChecked(DavesQuestsDB.hideBlizzTracker == true)
            end
            if DavesQuestsMapCheck then
                DavesQuestsMapCheck:SetChecked(DavesQuestsDB.showMapPane == true)
            end
            if not HUDTracker then
                BuildHUDTracker()
            end
            if DavesQuestsDB.showHUDTracker and HUDTracker then
                HUDTracker:Refresh()
            end
            SuppressBlizzardTracker()
        elseif arg1 == "Blizzard_ObjectiveTracker" then
            SuppressBlizzardTracker()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        InitDB()
        if not HUDTracker then
            BuildHUDTracker()
        end
        if DavesQuestsDB.showHUDTracker and HUDTracker then
            HUDTracker:Refresh()
        end
        SuppressBlizzardTracker()

        if type(DavesMobileMenu_RegisterAddon) == "function" then
            DavesMobileMenu_RegisterAddon("DavesQuests", "Dave's Quests", 133872, ToggleQuestWindow)
        end
        return
    end

    SuppressBlizzardTracker()

    if HUDTracker and DavesQuestsDB.showHUDTracker then
        HUDTracker:Refresh()
    end

    if questWindow and questWindow:IsShown() then
        questWindow:RefreshQuests()
        if DavesQuestsDB.showMapPane then
            RefreshMapPins()
        end
    end
end)

-- =========================================================
-- Public API: Check if an item is needed for active quests
-- =========================================================
function DavesQuests_GetItemQuestRequirements(itemName)
    if not itemName or itemName == "" then return nil end
    local lowerItem = string.lower(itemName)
    local results = {}

    local quests = GetAllQuests()
    for _, q in ipairs(quests) do
        if not q.isComplete and q.objectives then
            for _, obj in ipairs(q.objectives) do
                if not obj.finished and obj.text and string.find(string.lower(obj.text), lowerItem, 1, true) then
                    table.insert(results, {
                        questID = q.questID,
                        title = q.title,
                        objectiveText = obj.text
                    })
                end
            end
        end
    end

    return #results > 0 and results or nil
end

-- Initialize components immediately on file load
BuildHUDTracker()
SuppressBlizzardTracker()
