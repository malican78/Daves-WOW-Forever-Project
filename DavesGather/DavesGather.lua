local addonName, addon = ...

-- =========================================================
-- Theme & Color Palette (Matched to Dave's Notes & Bags)
-- =========================================================
local WINDOW_COLOR = { 0.73, 0.60, 0.37 }
local WINDOW_BORDER_COLOR = { 0.48, 0.36, 0.22 }
local GOLD_TEXT_COLOR = { 1, 0.82, 0.30 }
local MUTED_GOLD_COLOR = { 0.95, 0.82, 0.48 }

-- Data persistence
local function GetFilters()
    DavesGatherDB = DavesGatherDB or {}
    DavesGatherDB.nodes = DavesGatherDB.nodes or {}
    if type(DavesGatherDB.filters) ~= "table" then
        DavesGatherDB.filters = {
            showPins = true,
            showHerb = true,
            showOre = true,
            showCloth = true,
            showLeather = true,
            showFishing = true,
            showOther = true
        }
    end
    return DavesGatherDB.filters
end

-- Tracking state
local lastGatherSpell = nil
local lastGatherTime = 0
local gatherWindow = nil
local nodeRows = {}

-- Filter & Search State
local selectedMapID = "ALL"
local selectedCategory = "ALL"
local currentSearchText = ""
local expandedItems = {}

-- Spells considered a node gather
local GATHER_SPELLS = {
    ["Herb Gathering"] = "Herbalism",
    ["Herbalism"] = "Herbalism",
    ["Mining"] = "Mining",
    ["Opening"] = "Treasure",
    ["Extract Gas"] = "Engineering",
    ["Skinning"] = "Skinning",
    ["Fishing"] = "Fishing",
    ["Mob Drop"] = "Mob Drop",
    ["Armor"] = "Armor",
    ["Weapon"] = "Weapon",
    ["Food"] = "Food",
    ["Potion"] = "Potion",
    ["Scroll"] = "Scroll",
}


-- Cloth items dropped by mobs to be monitored
local TRACKED_CLOTH = {
    ["Linen Cloth"] = true,
    ["Wool Cloth"] = true,
    ["Silk Cloth"] = true,
    ["Mageweave Cloth"] = true,
    ["Runecloth"] = true,
    ["Felcloth"] = true,
    ["Mooncloth"] = true,
    ["Netherweave Cloth"] = true,
    ["Frostweave Cloth"] = true,
    ["Embersilk Cloth"] = true,
    ["Windwool Cloth"] = true,
    ["Sumptuous Fur"] = true,
    ["Shal'dorei Silk"] = true,
    ["Tidespray Linen"] = true,
    ["Deep Sea Satin"] = true,
    ["Shrouded Cloth"] = true,
    ["Lightless Silk"] = true,
    ["Wildercloth"] = true,
    ["Weavercloth"] = true,
    ["Spool of Weavercloth"] = true,
    ["Duskweave"] = true,
    ["Spool of Duskweave"] = true,
    ["Dawnweave"] = true,
    ["Spool of Dawnweave"] = true,
}


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
    
    return {top, bottom, left, right}
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

local function makeDraggableRegion(region, window)
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnMouseDown", function() window:Raise() end)
    region:SetScript("OnDragStart", function() window:Raise(); window:StartMoving() end)
    region:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
end

-- =========================================================
-- Public Query API for Tooltips & External Addons
-- =========================================================
function DavesGather_GetLocationsForItem(itemName)
    if not itemName or not DavesGatherDB or not DavesGatherDB.nodes then return nil end
    local lowerQuery = string.lower(itemName)
    local results = {}

    for mapID, nodes in pairs(DavesGatherDB.nodes) do
        local mapInfo = C_Map.GetMapInfo(mapID)
        local zoneName = mapInfo and mapInfo.name or "Unknown Zone"

        for _, node in ipairs(nodes) do
            local nodeName = string.lower(node.name or "")
            local isMatch = (nodeName == lowerQuery) or string.find(nodeName, lowerQuery, 1, true) or string.find(lowerQuery, nodeName, 1, true)

            if not isMatch then
                local coreName = string.gsub(lowerQuery, " ore", "")
                if string.find(nodeName, coreName, 1, true) then
                    isMatch = true
                end
            end

            if isMatch then
                local locKey = zoneName .. ": " .. (node.subZone or "Wilderness")
                if not results[locKey] then
                    results[locKey] = {
                        zone = zoneName,
                        subZone = node.subZone or "Wilderness",
                        count = node.count or 1
                    }
                else
                    results[locKey].count = results[locKey].count + (node.count or 1)
                end
            end
        end
    end

    local list = {}
    for _, data in pairs(results) do
        table.insert(list, data)
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end

-- =========================================================
-- Dave's Notes Integration
-- =========================================================
local function ExportGroupedNodeToDavesNotes(itemData)
    if type(DavesNotes_AddItemInfo) ~= "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[Dave's Gather]|r Dave's Notes addon is not loaded.")
        return false
    end

    local title = string.format("Gathered Item: %s", itemData.name)
    local lines = {}
    table.insert(lines, string.format("Profession: %s", itemData.profession or "Gathering"))
    table.insert(lines, string.format("Total Gathered: %d", itemData.totalCount or 1))
    table.insert(lines, "Locations Found:")

    for _, loc in ipairs(itemData.locations) do
        table.insert(lines, string.format(" • %s: %s (x%d)", loc.zone, loc.subZone, loc.count))
    end

    local action = DavesNotes_AddItemInfo(title, table.concat(lines, "\n"))
    if action == "inserted" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Gather]|r Inserted " .. itemData.name .. " into active note.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Dave's Gather]|r Created note for " .. itemData.name .. ".")
    end
    return true
end

-- =========================================================
-- World Map Pins System
-- =========================================================
local mapPinsPool = {}
local mapPinsFrame = CreateFrame("Frame", "DavesGatherMapOverlay", WorldMapFrame:GetCanvas())
mapPinsFrame:SetAllPoints(WorldMapFrame:GetCanvas())
mapPinsFrame:SetFrameStrata("HIGH")

local function GetMapPin(index)
    if not mapPinsPool[index] then
        local pin = CreateFrame("Button", nil, mapPinsFrame)
        pin:SetSize(20, 20)
        pin:EnableMouse(true)

        -- Dark circular background backing
        pin.bg = pin:CreateTexture(nil, "BACKGROUND")
        pin.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        pin.bg:SetSize(20, 20)
        pin.bg:SetPoint("CENTER", pin, "CENTER", 0, 0)

        -- Item icon texture (nested neatly inside the circular ring)
        pin.texture = pin:CreateTexture(nil, "ARTWORK")
        pin.texture:SetSize(20, 20)
        pin.texture:SetPoint("CENTER", pin, "CENTER", 0, 0)

        -- Circular alpha mask for smooth round icon clipping
        if pin.CreateMaskTexture then
            local mask = pin:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(pin.texture)
            pin.texture:AddMaskTexture(mask)
            pin.mask = mask
        else
            pin.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        -- Golden tracking circle border, precisely centered over the icon
        pin.border = pin:CreateTexture(nil, "OVERLAY")
        pin.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        pin.border:SetSize(54, 54)
        pin.border:SetPoint("TOPLEFT", pin, "TOPLEFT", -6, 6)

        -- Subtle circular glow on hover
        pin.highlight = pin:CreateTexture(nil, "HIGHLIGHT")
        pin.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        pin.highlight:SetBlendMode("ADD")
        pin.highlight:SetSize(26, 26)
        pin.highlight:SetPoint("CENTER", pin, "CENTER", 0, 0)
        pin.highlight:SetVertexColor(1, 0.85, 0.30, 0.8)

        pin:SetScript("OnEnter", function(self)
            if not self.nodeData then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.nodeData.name, 1, 0.82, 0)
            if self.nodeData.subZone and self.nodeData.subZone ~= "" then
                GameTooltip:AddLine("Location: " .. self.nodeData.subZone, 0.95, 0.82, 0.48)
            end
            GameTooltip:AddLine(string.format("Coordinates: %.1f, %.1f", self.nodeData.x * 100, self.nodeData.y * 100), 1, 1, 1)
            GameTooltip:AddLine(string.format("Times Gathered: %d", self.nodeData.count or 1), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)

        pin:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        mapPinsPool[index] = pin
    end
    return mapPinsPool[index]
end

local function RefreshWorldMapPins()
    if not WorldMapFrame:IsShown() then return end
    local mapID = WorldMapFrame:GetMapID()
    if not mapID or not DavesGatherDB.nodes[mapID] then
        for _, pin in ipairs(mapPinsPool) do pin:Hide() end
        return
    end

    local nodes = DavesGatherDB.nodes[mapID]
    local canvas = WorldMapFrame:GetCanvas()
    local canvasWidth = canvas:GetWidth()
    local canvasHeight = canvas:GetHeight()

    if canvasWidth == 0 or canvasHeight == 0 then return end

    local activePinIndex = 1
    for i = 1, #nodes do
        local node = nodes[i]
        
        local prof = node.profession or "Gather"
        local filters = GetFilters()
        local show = filters.showPins
        if show then
            if prof == "Mining" then show = filters.showOre
            elseif prof == "Herbalism" then show = filters.showHerb
            elseif prof == "Mob Drop" then show = filters.showCloth
            elseif prof == "Skinning" then show = filters.showLeather
            elseif prof == "Fishing" then show = filters.showFishing
            else show = filters.showOther end
        end

        if show then
            local pin = GetMapPin(activePinIndex)
            pin.nodeData = node
            pin.texture:SetTexture(node.icon or 134400)

            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", node.x * canvasWidth, -node.y * canvasHeight)
            pin:Show()
            activePinIndex = activePinIndex + 1
        end
    end

    for i = activePinIndex, #mapPinsPool do
        mapPinsPool[i]:Hide()
    end
end

hooksecurefunc(WorldMapFrame, "OnMapChanged", RefreshWorldMapPins)
WorldMapFrame:HookScript("OnShow", RefreshWorldMapPins)

-- =========================================================
-- Map Pins Dropdown Menu (Shared)
-- =========================================================
local menuUpdateFuncs = {}
local function UpdateAllMenus()
    for _, func in ipairs(menuUpdateFuncs) do func() end
end

local function CreateMapPinsDropdown(parent, anchorFrame, anchorPoint, anchorRel, x, y, level)
    local optionsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    optionsBtn:SetSize(85, 22)
    optionsBtn:SetPoint(anchorPoint, anchorFrame, anchorRel, x, y)
    optionsBtn:SetText("Map Pins v")
    if level then optionsBtn:SetFrameLevel(level) end

    local optionsMenu = CreateFrame("Frame", nil, parent)
    optionsMenu:SetSize(165, 186)
    optionsMenu:SetPoint("TOPRIGHT", optionsBtn, "BOTTOMRIGHT", 0, -2)
    optionsMenu:SetFrameStrata("TOOLTIP")
    optionsMenu:SetToplevel(true)
    optionsMenu:SetFrameLevel(250)
    optionsMenu:EnableMouse(true)
    
    optionsMenu.solidBg = optionsMenu:CreateTexture(nil, "BACKGROUND", nil, -8)
    setTextureColor(optionsMenu.solidBg, 0.98, 0.95, 0.86, 1.0)
    optionsMenu.solidBg:SetAllPoints(optionsMenu)
    createBorder(optionsMenu, WINDOW_BORDER_COLOR, 2)
    optionsMenu:Hide()

    local function CreateMenuItem(yOffset, onClick)
        local btn = CreateFrame("Button", nil, optionsMenu)
        btn:SetSize(155, 20)
        btn:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", 5, yOffset)

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

    local function ToggleFilter(key)
        local filters = GetFilters()
        filters[key] = not filters[key]
        UpdateAllMenus()
        if RefreshWorldMapPins then RefreshWorldMapPins() end
    end

    local function ToggleAllFilters()
        local filters = GetFilters()
        local anyOn = filters.showOre or filters.showHerb or filters.showCloth or filters.showLeather or filters.showFishing or filters.showOther
        local newState = not anyOn
        
        filters.showOre = newState
        filters.showHerb = newState
        filters.showCloth = newState
        filters.showLeather = newState
        filters.showFishing = newState
        filters.showOther = newState
        if newState then filters.showPins = true end
        
        UpdateAllMenus()
        if RefreshWorldMapPins then RefreshWorldMapPins() end
    end

    local toggleMaster = CreateMenuItem(-5, function() ToggleFilter("showPins") end)
    local toggleOre = CreateMenuItem(-27, function() ToggleFilter("showOre") end)
    local toggleHerb = CreateMenuItem(-49, function() ToggleFilter("showHerb") end)
    local toggleCloth = CreateMenuItem(-71, function() ToggleFilter("showCloth") end)
    local toggleLeather = CreateMenuItem(-93, function() ToggleFilter("showLeather") end)
    local toggleFishing = CreateMenuItem(-115, function() ToggleFilter("showFishing") end)
    local toggleOther = CreateMenuItem(-137, function() ToggleFilter("showOther") end)
    local toggleAllBtn = CreateMenuItem(-159, ToggleAllFilters)
    
    toggleAllBtn.text:SetTextColor(0.85, 0.70, 0.40) -- Gold-ish color to stand out

    local function UpdateMenu()
        local filters = GetFilters()
        local function GetText(key, label)
            return (filters[key] and "|cff008800[x]|r " or "|cff888888[ ]|r ") .. label
        end
        toggleMaster.text:SetText(GetText("showPins", "Show Map Pins"))
        toggleOre.text:SetText(GetText("showOre", "Ore (Mining)"))
        toggleHerb.text:SetText(GetText("showHerb", "Flowers (Herbalism)"))
        toggleCloth.text:SetText(GetText("showCloth", "Cloth (Mob Drops)"))
        toggleLeather.text:SetText(GetText("showLeather", "Leather (Skinning)"))
        toggleFishing.text:SetText(GetText("showFishing", "Fish (Fishing)"))
        toggleOther.text:SetText(GetText("showOther", "Others (Treasures, etc)"))

        local anyOn = filters.showOre or filters.showHerb or filters.showCloth or filters.showLeather or filters.showFishing or filters.showOther
        toggleAllBtn.text:SetText(anyOn and "   [ Deselect All Categories ]" or "   [ Select All Categories ]")
    end
    table.insert(menuUpdateFuncs, UpdateMenu)

    local function CheckHoverStatus()
        if not optionsBtn:IsMouseOver() and not optionsMenu:IsMouseOver() then
            optionsMenu:Hide()
        end
    end

    optionsBtn:SetScript("OnEnter", function()
        UpdateMenu()
        optionsMenu:Show()
    end)
    optionsBtn:SetScript("OnLeave", function()
        C_Timer.After(0.1, CheckHoverStatus)
    end)
    
    optionsMenu:SetScript("OnLeave", function()
        C_Timer.After(0.1, CheckHoverStatus)
    end)
    return optionsBtn, optionsMenu
end

-- Hook up map pins dropdown to World Map
local function InitWorldMapDropdown()
    local anchor = WorldMapFrameMaximizeMinimizeButton or WorldMapFrameSizeDownButton or WorldMapFrameCloseButton
    local parent = anchor and anchor:GetParent() or WorldMapFrame
    local btn, menu
    if anchor then
        btn, menu = CreateMapPinsDropdown(parent, anchor, "RIGHT", "LEFT", -80, 0, 9000)
    else
        btn, menu = CreateMapPinsDropdown(parent, WorldMapFrame, "TOPRIGHT", "TOPRIGHT", -145, -4, 9000)
    end
    
    -- Ensure the button draws fully above the map's artwork
    btn:SetFrameStrata("TOOLTIP")
    
    WorldMapFrame:HookScript("OnHide", function() menu:Hide() end)
    WorldMapFrame:HookScript("OnMouseDown", function() menu:Hide() end)
end
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", InitWorldMapDropdown)

-- =========================================================
-- Gathering & Node Recording Logic
-- =========================================================
local function RecordGatheredNode(targetName, targetIcon)
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end

    local x, y = pos:GetXY()
    if not x or not y or (x == 0 and y == 0) then return end

    local subZone = GetSubZoneText()
    if not subZone or subZone == "" then
        subZone = GetZoneText()
    end

    DavesGatherDB.nodes[mapID] = DavesGatherDB.nodes[mapID] or {}
    local zoneNodes = DavesGatherDB.nodes[mapID]

    local existing = nil
    for _, n in ipairs(zoneNodes) do
        local dx = n.x - x
        local dy = n.y - y
        local distSq = (dx * dx) + (dy * dy)
        if distSq < 0.0003 and n.name == targetName then
            existing = n
            break
        end
    end

    if existing then
        existing.count = (existing.count or 1) + 1
        existing.lastSeen = date("%m/%d/%y")
        existing.lastSeenTime = time()
        if (not existing.subZone or existing.subZone == "") and subZone then
            existing.subZone = subZone
        end
    else
        table.insert(zoneNodes, {
            name = targetName,
            icon = targetIcon or 134400,
            x = x,
            y = y,
            subZone = subZone or "Wilderness",
            profession = GATHER_SPELLS[lastGatherSpell] or "Gather",
            count = 1,
            firstSeen = date("%m/%d/%y"),
            lastSeenTime = time()
        })
    end

    RefreshWorldMapPins()
    if gatherWindow and gatherWindow:IsShown() then
        gatherWindow:RefreshList()
    end
end

-- =========================================================
-- Browser Window (Consolidated Item List)
-- =========================================================
local function BuildGatherWindow()
    local function UpdateNativeStyle()
        local isNative = DavesGatherDB.filters and DavesGatherDB.filters.nativeTrackerStyle
        if not gatherWindow then return end

        if isNative then
            if gatherWindow.background then gatherWindow.background:Hide() end
            if gatherWindow.borders then for _, t in pairs(gatherWindow.borders) do t:Hide() end end
            if gatherWindow.header then
                if gatherWindow.header.background then gatherWindow.header.background:Hide() end
                if gatherWindow.header.borders then for _, t in pairs(gatherWindow.header.borders) do t:Hide() end end
            end
            if gatherWindow.filterBar then gatherWindow.filterBar:Hide() end
            if gatherWindow.scroll then gatherWindow.scroll:SetPoint("TOPLEFT", gatherWindow.header, "BOTTOMLEFT", 8, -6) end
            if gatherWindow.subTitle then gatherWindow.subTitle:Hide() end
        else
            if gatherWindow.background then gatherWindow.background:Show() end
            if gatherWindow.borders then for _, t in pairs(gatherWindow.borders) do t:Show() end end
            if gatherWindow.header then
                if gatherWindow.header.background then gatherWindow.header.background:Show() end
                if gatherWindow.header.borders then for _, t in pairs(gatherWindow.header.borders) do t:Show() end end
            end
            if gatherWindow.filterBar then gatherWindow.filterBar:Show() end
            if gatherWindow.scroll then gatherWindow.scroll:SetPoint("TOPLEFT", gatherWindow.filterBar, "BOTTOMLEFT", 8, -6) end
            if gatherWindow.subTitle then gatherWindow.subTitle:Show() end
        end

        for _, row in pairs(nodeRows) do
            if isNative then
                if row.bg then row.bg:Hide() end
                if row.highlight then row.highlight:Hide() end
                if row.borders then for _, t in pairs(row.borders) do t:Hide() end end
                if row.name then row.name:SetTextColor(1, 0.82, 0) end
                if row.locations then row.locations:SetTextColor(0.8, 0.8, 0.8) end
                if row.totalCount then row.totalCount:SetTextColor(0.8, 0.8, 0.8) end
            else
                if row.bg then row.bg:Show() end
                if row.highlight then row.highlight:Show() end
                if row.borders then for _, t in pairs(row.borders) do t:Show() end end
                if row.name then row.name:SetTextColor(0.50, 0.22, 0.02) end
                if row.locations then row.locations:SetTextColor(0.18, 0.15, 0.10) end
                if row.totalCount then row.totalCount:SetTextColor(0.35, 0.25, 0.15) end
            end
        end
    end
    local frame = CreateFrame("Frame", "DavesGatherFrame", UIParent)
    frame:SetSize(420, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 50, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    applyWindowBackground(frame)
    frame.borders = createBorder(frame, WINDOW_BORDER_COLOR, 3)
    registerEscapeFrame("DavesGatherFrame")

    frame:SetScript("OnMouseDown", function() frame:Raise() end)

    -- Header Panel
    local header = CreateFrame("Frame", nil, frame)
    frame.header = header
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    header:SetHeight(38)
    applyWindowBackground(header)
    header.borders = createBorder(header, WINDOW_BORDER_COLOR, 2)
    makeDraggableRegion(header, frame)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 12, -6)
    title:SetText("Dave's Gather")
    title:SetTextColor(GOLD_TEXT_COLOR[1], GOLD_TEXT_COLOR[2], GOLD_TEXT_COLOR[3])

    frame.subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subTitle:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 12, 5)
    frame.subTitle:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    close:SetScript("OnClick", function() frame:Hide() end)

    local optionsBtn, optionsMenu = CreateMapPinsDropdown(frame, close, "RIGHT", "LEFT", -4, 0)
    optionsBtn:SetParent(header)

    local nativeBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    nativeBtn:SetSize(85, 22)
    nativeBtn:SetPoint("RIGHT", optionsBtn, "LEFT", -4, 0)
    nativeBtn:SetText("Native Style")
    nativeBtn:SetScript("OnClick", function()
        DavesGatherDB.filters = DavesGatherDB.filters or {}
        DavesGatherDB.filters.nativeTrackerStyle = not DavesGatherDB.filters.nativeTrackerStyle
        UpdateNativeStyle()
    end)

    frame:HookScript("OnHide", function() optionsMenu:Hide() end)
    header:HookScript("OnMouseDown", function() optionsMenu:Hide() end)

    -- Filter Bar
    local filterBar = CreateFrame("Frame", nil, frame)
    frame.filterBar = filterBar
    filterBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    filterBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    filterBar:SetHeight(32)

    local zoneDropdownBtn = CreateFrame("Button", "DavesGatherZoneDropdownBtn", filterBar, "UIPanelButtonTemplate")
    zoneDropdownBtn:SetHeight(24)
    zoneDropdownBtn:SetPoint("LEFT", filterBar, "LEFT", 10, 0)

    local function SetZoneButtonText(text)
        local btnText = zoneDropdownBtn:GetFontString()
        if btnText then btnText:SetWordWrap(false) end
        zoneDropdownBtn:SetText(text)
        local textWidth = (btnText and btnText:GetStringWidth()) or 80
        zoneDropdownBtn:SetWidth(math.max(120, math.min(175, textWidth + 24)))
    end
    SetZoneButtonText("All Zones")

    local searchBox = CreateFrame("EditBox", "DavesGatherSearchBox", filterBar, "SearchBoxTemplate")
    local categoryDropdownBtn = CreateFrame("Button", "DavesGatherCategoryDropdownBtn", filterBar, "UIPanelButtonTemplate")
    categoryDropdownBtn:SetHeight(24)
    categoryDropdownBtn:SetPoint("LEFT", zoneDropdownBtn, "RIGHT", 4, 0)
    categoryDropdownBtn:SetWidth(105)
    categoryDropdownBtn:SetText("All Categories")
    searchBox:SetHeight(24)
    searchBox:SetPoint("LEFT", categoryDropdownBtn, "RIGHT", 8, 0)
    searchBox:SetPoint("RIGHT", filterBar, "RIGHT", -10, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(30)

    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        currentSearchText = string.lower(strtrim(self:GetText() or ""))
        if frame.RefreshList then frame:RefreshList() end
    end)

    -- Zone Picker Pop-up Menu
    local zonePicker = CreateFrame("Frame", nil, frame)
    zonePicker:SetSize(210, 210)
    zonePicker:SetPoint("TOPLEFT", zoneDropdownBtn, "BOTTOMLEFT", 0, -2)
    zonePicker:SetFrameStrata("FULLSCREEN_DIALOG")
    zonePicker:SetToplevel(true)
    zonePicker:SetFrameLevel(250)
    zonePicker:EnableMouse(true)

    zonePicker.solidBg = zonePicker:CreateTexture(nil, "BACKGROUND", nil, -8)
    setTextureColor(zonePicker.solidBg, 0.98, 0.95, 0.86, 1.0)
    zonePicker.solidBg:SetAllPoints(zonePicker)
    createBorder(zonePicker, WINDOW_BORDER_COLOR, 2)
    zonePicker:Hide()

    local pickerScroll = CreateFrame("ScrollFrame", nil, zonePicker)
    pickerScroll:SetPoint("TOPLEFT", zonePicker, "TOPLEFT", 6, -6)
    pickerScroll:SetPoint("BOTTOMRIGHT", zonePicker, "BOTTOMRIGHT", -6, 6)
    pickerScroll:SetFrameLevel(zonePicker:GetFrameLevel() + 2)

    pickerScroll:EnableMouseWheel(true)
    pickerScroll:SetScript("OnMouseWheel", function(self, delta)
        local curY = self:GetVerticalScroll()
        local maxY = self:GetVerticalScrollRange()
        local newY = curY - (delta * 22)
        if newY < 0 then newY = 0 end
        if newY > maxY then newY = maxY end
        self:SetVerticalScroll(newY)
    end)

    local pickerContent = CreateFrame("Frame", nil, pickerScroll)
    pickerContent:SetSize(198, 1)
    pickerContent:SetFrameLevel(pickerScroll:GetFrameLevel() + 1)
    pickerScroll:SetScrollChild(pickerContent)

    local pickerButtons = {}

    local function CloseZonePicker()
        zonePicker:Hide()
    end

    local function OpenZonePicker()
        if zonePicker:IsShown() then
            return
        end

        zonePicker:SetFrameStrata("FULLSCREEN_DIALOG")
        zonePicker:SetFrameLevel(250)
        zonePicker:Raise()

        local options = {}
        table.insert(options, { id = "ALL", name = "All Zones" })

        local currentMapID = C_Map.GetBestMapForUnit("player")
        if currentMapID then
            local curInfo = C_Map.GetMapInfo(currentMapID)
            if curInfo and curInfo.name then
                table.insert(options, { id = currentMapID, name = "Current: " .. curInfo.name })
            end
        end

        local discovered = {}
        for mapID, nodes in pairs(DavesGatherDB.nodes) do
            if #nodes > 0 and mapID ~= currentMapID then
                local info = C_Map.GetMapInfo(mapID)
                if info and info.name then
                    table.insert(discovered, { id = mapID, name = info.name })
                end
            end
        end
        table.sort(discovered, function(a, b) return a.name < b.name end)

        for _, d in ipairs(discovered) do
            table.insert(options, d)
        end

        pickerContent:SetHeight(#options * 22)

        for i = 1, #options do
            local opt = options[i]
            local btn = pickerButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, pickerContent)
                btn:SetSize(198, 20)
                btn:SetFrameLevel(pickerContent:GetFrameLevel() + 1)

                btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                setTextureColor(btn.highlight, 0.85, 0.70, 0.40, 0.4)
                btn.highlight:SetAllPoints(btn)

                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
                btn.text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                btn.text:SetJustifyH("LEFT")
                btn.text:SetWordWrap(false)
                pickerButtons[i] = btn
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", pickerContent, "TOPLEFT", 0, -(i - 1) * 22)
            btn.text:SetText(opt.name)

            if selectedMapID == opt.id then
                btn.text:SetTextColor(0.85, 0.40, 0.05)
            else
                btn.text:SetTextColor(0.12, 0.09, 0.05)
            end

            btn:SetScript("OnClick", function()
                selectedMapID = opt.id
                local btnText = zoneDropdownBtn:GetFontString()
                if btnText then btnText:SetWordWrap(false) end
                zoneDropdownBtn:SetText(opt.id == "ALL" and "All Zones" or opt.name)
                local textWidth = (btnText and btnText:GetStringWidth()) or 80
                zoneDropdownBtn:SetWidth(math.max(120, math.min(175, textWidth + 24)))
                CloseZonePicker()
                frame:RefreshList()
            end)

            btn:Show()
        end

        for i = #options + 1, #pickerButtons do
            pickerButtons[i]:Hide()
        end

        zonePicker:Show()
    end

    local function CheckHoverStatus()
        if not zoneDropdownBtn:IsMouseOver() and not zonePicker:IsMouseOver() then
            CloseZonePicker()
        end
    end

    zoneDropdownBtn:SetScript("OnEnter", OpenZonePicker)
    zoneDropdownBtn:SetScript("OnLeave", function() C_Timer.After(0.1, CheckHoverStatus) end)
    zonePicker:SetScript("OnLeave", function() C_Timer.After(0.1, CheckHoverStatus) end)

    -- Category Picker Pop-up Menu
    local categoryPicker = CreateFrame("Frame", nil, frame)
    categoryPicker:SetSize(160, 210)
    categoryPicker:SetPoint("TOPLEFT", categoryDropdownBtn, "BOTTOMLEFT", 0, -2)
    categoryPicker:SetFrameStrata("FULLSCREEN_DIALOG")
    categoryPicker:SetToplevel(true)
    categoryPicker:SetFrameLevel(250)
    categoryPicker:EnableMouse(true)

    categoryPicker.solidBg = categoryPicker:CreateTexture(nil, "BACKGROUND", nil, -8)
    setTextureColor(categoryPicker.solidBg, 0.98, 0.95, 0.86, 1.0)
    categoryPicker.solidBg:SetAllPoints(categoryPicker)
    createBorder(categoryPicker, WINDOW_BORDER_COLOR, 2)
    categoryPicker:Hide()

    local catPickerScroll = CreateFrame("ScrollFrame", nil, categoryPicker)
    catPickerScroll:SetPoint("TOPLEFT", categoryPicker, "TOPLEFT", 6, -6)
    catPickerScroll:SetPoint("BOTTOMRIGHT", categoryPicker, "BOTTOMRIGHT", -6, 6)
    catPickerScroll:SetFrameLevel(categoryPicker:GetFrameLevel() + 2)

    catPickerScroll:EnableMouseWheel(true)
    catPickerScroll:SetScript("OnMouseWheel", function(self, delta)
        local curY = self:GetVerticalScroll()
        local maxY = self:GetVerticalScrollRange()
        local newY = curY - (delta * 22)
        if newY < 0 then newY = 0 end
        if newY > maxY then newY = maxY end
        self:SetVerticalScroll(newY)
    end)

    local catPickerContent = CreateFrame("Frame", nil, catPickerScroll)
    catPickerContent:SetSize(148, 1)
    catPickerContent:SetFrameLevel(catPickerScroll:GetFrameLevel() + 1)
    catPickerScroll:SetScrollChild(catPickerContent)

    local catPickerButtons = {}

    local function CloseCategoryPicker()
        categoryPicker:Hide()
    end

    local function OpenCategoryPicker()
        if categoryPicker:IsShown() then
            return
        end

        categoryPicker:SetFrameStrata("FULLSCREEN_DIALOG")
        categoryPicker:SetFrameLevel(250)
        categoryPicker:Raise()

        local options = {
            { id = "ALL", name = "All Categories" },
            { id = "Herbalism", name = "Herbalism" },
            { id = "Mining", name = "Mining" },
            { id = "Skinning", name = "Leather (Skinning)" },
            { id = "Mob Drop", name = "Cloth (Mob Drops)" },
            { id = "Fishing", name = "Fish (Fishing)" },
            { id = "Armor", name = "Armor" },
            { id = "Weapon", name = "Weapons" },
            { id = "Food", name = "Food & Drink" },
            { id = "Potion", name = "Potions" },
            { id = "Scroll", name = "Scrolls" },
            { id = "Other", name = "Other" }
        }

        catPickerContent:SetHeight(#options * 22)

        for i = 1, #options do
            local opt = options[i]
            local btn = catPickerButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, catPickerContent)
                btn:SetSize(148, 20)
                btn:SetFrameLevel(catPickerContent:GetFrameLevel() + 1)

                btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                setTextureColor(btn.highlight, 0.85, 0.70, 0.40, 0.4)
                btn.highlight:SetAllPoints(btn)

                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
                btn.text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                btn.text:SetJustifyH("LEFT")
                btn.text:SetWordWrap(false)
                catPickerButtons[i] = btn
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", catPickerContent, "TOPLEFT", 0, -(i - 1) * 22)
            btn.text:SetText(opt.name)

            if selectedCategory == opt.id then
                btn.text:SetTextColor(0.85, 0.40, 0.05)
            else
                btn.text:SetTextColor(0.12, 0.09, 0.05)
            end

            btn:SetScript("OnClick", function()
                selectedCategory = opt.id
                categoryDropdownBtn:SetText(opt.id == "ALL" and "All Categories" or opt.name)
                CloseCategoryPicker()
                frame:RefreshList()
            end)

            btn:Show()
        end

        for i = #options + 1, #catPickerButtons do
            catPickerButtons[i]:Hide()
        end

        categoryPicker:Show()
    end

    local function CheckCatHoverStatus()
        if not categoryDropdownBtn:IsMouseOver() and not categoryPicker:IsMouseOver() then
            CloseCategoryPicker()
        end
    end

    categoryDropdownBtn:SetScript("OnEnter", OpenCategoryPicker)
    categoryDropdownBtn:SetScript("OnLeave", function() C_Timer.After(0.1, CheckCatHoverStatus) end)
    categoryPicker:SetScript("OnLeave", function() C_Timer.After(0.1, CheckCatHoverStatus) end)

    frame:HookScript("OnHide", function() 
        CloseZonePicker()
        CloseCategoryPicker() 
    end)

    -- Scroll Area
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    frame.scroll = scroll
    scroll:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 12)
    scroll:HookScript("OnMouseDown", CloseZonePicker)

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
    content:SetSize(395, 1)
    scroll:SetScrollChild(content)

    frame.emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.emptyText:SetPoint("CENTER", scroll, "CENTER", 0, 10)
    frame.emptyText:SetWidth(300)
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetText("No nodes found matching your criteria.")
    frame.emptyText:SetTextColor(MUTED_GOLD_COLOR[1], MUTED_GOLD_COLOR[2], MUTED_GOLD_COLOR[3])

    -- Row Constructor
    local function GetRow(index)
        if not nodeRows[index] then
            local row = CreateFrame("Button", nil, content)
            row:SetWidth(395)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            setTextureColor(row.bg, 0.98, 0.95, 0.86, 1.0)
            row.bg:SetAllPoints(row)
            row.borders = createBorder(row, { 0.55, 0.42, 0.25 }, 1)

            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(row.highlight, 1, 0.82, 0.30, 0.2)
            row.highlight:SetAllPoints(row)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(34, 34)
            row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 0)
            row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -80, 0)
            row.name:SetJustifyH("LEFT")
            row.name:SetTextColor(0.50, 0.22, 0.02)

            row.totalCount = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.totalCount:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
            row.totalCount:SetTextColor(0.35, 0.25, 0.15)

            -- Locations block
            row.locations = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.locations:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
            row.locations:SetWidth(320)
            row.locations:SetJustifyH("LEFT")
            row.locations:SetWordWrap(true)
            row.locations:SetSpacing(3)
            row.locations:SetTextColor(0.18, 0.15, 0.10)

            nodeRows[index] = row
        end
        return nodeRows[index]
    end

    function frame:RefreshList()
        -- Aggregate duplicate items into single entries with multiple locations
        local groupedMap = {}

        for mapID, nodes in pairs(DavesGatherDB.nodes) do
            if selectedMapID == "ALL" or selectedMapID == mapID then
                local mapInfo = C_Map.GetMapInfo(mapID)
                local zoneName = mapInfo and mapInfo.name or "Unknown Zone"

                for _, node in ipairs(nodes) do
                    local nodeName = node.name or "Unknown Node"
                    local subZone = node.subZone or "Wilderness"
                    local prof = node.profession or "Gather"

                    -- Category filter
                    local match = true
                    if selectedCategory ~= "ALL" then
                        if selectedCategory == "Other" then
                            if prof == "Herbalism" or prof == "Mining" or prof == "Mob Drop" or prof == "Skinning" or prof == "Fishing" or prof == "Armor" or prof == "Weapon" or prof == "Food" or prof == "Potion" or prof == "Scroll" then
                                match = false
                            end
                        else
                            if prof ~= selectedCategory then match = false end
                        end
                    end

                    -- Search text filtering
                    if match and currentSearchText ~= "" then
                        local lName = string.lower(nodeName)
                        local lSub = string.lower(subZone)
                        local lZone = string.lower(zoneName)
                        if not string.find(lName, currentSearchText, 1, true) and
                           not string.find(lSub, currentSearchText, 1, true) and
                           not string.find(lZone, currentSearchText, 1, true) then
                            match = false
                        end
                    end

                    if match then
                        if not groupedMap[nodeName] then
                            groupedMap[nodeName] = {
                                name = nodeName,
                                icon = node.icon or 134400,
                                profession = node.profession or "Gather",
                                totalCount = 0,
                                locationCounts = {}
                            }
                        end

                        local g = groupedMap[nodeName]
                        local count = node.count or 1
                        g.totalCount = g.totalCount + count

                        local locKey = zoneName .. "::" .. subZone
                        if not g.locationCounts[locKey] then
                            g.locationCounts[locKey] = {
                                zone = zoneName,
                                subZone = subZone,
                                count = count,
                                lastSeenTime = node.lastSeenTime or 0
                            }
                        else
                            g.locationCounts[locKey].count = g.locationCounts[locKey].count + count
                            g.locationCounts[locKey].lastSeenTime = math.max(g.locationCounts[locKey].lastSeenTime or 0, node.lastSeenTime or 0)
                        end
                    end
                end
            end
        end

        -- Convert map to sortable table
        local itemList = {}
        for _, item in pairs(groupedMap) do
            local locList = {}
            for _, loc in pairs(item.locationCounts) do
                table.insert(locList, loc)
            end
            table.sort(locList, function(a, b) if (a.lastSeenTime or 0) == (b.lastSeenTime or 0) then return a.count > b.count else return (a.lastSeenTime or 0) > (b.lastSeenTime or 0) end end)
            item.locations = locList
            table.insert(itemList, item)
        end

        table.sort(itemList, function(a, b) return a.name < b.name end)

        frame.subTitle:SetText(string.format("Tracking %d Unique Gathered Items", #itemList))

        if #itemList == 0 then
            frame.emptyText:Show()
        else
            frame.emptyText:Hide()
        end

        local currentY = 0
        for i = 1, #itemList do
            local itemData = itemList[i]
            local row = GetRow(i)
            row.itemData = itemData

            row.icon:SetTexture(itemData.icon)
            row.name:SetText(itemData.name)
            row.totalCount:SetText(string.format("|cffffd100x%d Total|r", itemData.totalCount))

            -- Build location string list
            local isExpanded = expandedItems[itemData.name]
            local locLines = {}
            for idx, loc in ipairs(itemData.locations) do
                if idx > 1 and not isExpanded then break end

                local prefix = "• "
                if idx == 1 and not isExpanded and #itemData.locations > 1 then
                    prefix = "• |cff4488ff[+]|r "
                elseif idx == 1 and isExpanded and #itemData.locations > 1 then
                    prefix = "• |cff884444[-]|r "
                end

                if selectedMapID == "ALL" then
                    table.insert(locLines, string.format("%s|cff664422%s:|r %s (|cff111111x%d|r)", prefix, loc.zone, loc.subZone, loc.count))
                else
                    table.insert(locLines, string.format("%s%s (|cff111111x%d|r)", prefix, loc.subZone, loc.count))
                end
            end

            row.locations:SetText(table.concat(locLines, "\n"))
            row.locations:SetWidth(320)

            -- Dynamically scale card height to fit all location lines
            local locHeight = row.locations:GetStringHeight() or 18
            local cardHeight = math.max(48, 12 + 18 + locHeight + 10)
            row:SetHeight(cardHeight)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -currentY)

            row:SetScript("OnClick", function(self, button)
                if button == "RightButton" and IsAltKeyDown() then
                    ExportGroupedNodeToDavesNotes(self.itemData)
                elseif button == "LeftButton" then
                    expandedItems[self.itemData.name] = not expandedItems[self.itemData.name]
                    frame:RefreshList()
                end
            end)

            row:Show()
            currentY = currentY + cardHeight + 6
        end

        UpdateNativeStyle()
        content:SetHeight(math.max(1, currentY))

        for i = #itemList + 1, #nodeRows do
            nodeRows[i]:Hide()
        end
    end

    frame:Hide()
    gatherWindow = frame
    return frame
end

local function ToggleGatherWindow()
    if not gatherWindow then
        BuildGatherWindow()
    end

    if gatherWindow:IsShown() then
        gatherWindow:Hide()
    else
        gatherWindow:RefreshList()
        gatherWindow:Show()
        gatherWindow:Raise()
    end
end

SLASH_DAVESGATHER1 = "/dgather"
SLASH_DAVESGATHER2 = "/davesgather"
SlashCmdList["DAVESGATHER"] = ToggleGatherWindow

-- =========================================================
-- Event Interception
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "UNIT_SPELLCAST_SENT" and unit == "player" then
        local target, castGUID, spellID = ...
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        local spellName = spellInfo and spellInfo.name
        if spellName and GATHER_SPELLS[spellName] then
            lastGatherSpell = spellName
            lastGatherTime = GetTime()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        local castGUID, spellID = ...
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        local spellName = spellInfo and spellInfo.name
        if spellName and GATHER_SPELLS[spellName] then
            lastGatherTime = GetTime()
        end

    elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
        local maxWait = (lastGatherSpell == "Fishing") and 22 or 3.5
        
        -- Scenario A: Standard node gather logic
        if lastGatherSpell and (GetTime() - lastGatherTime) < maxWait then
            local numItems = GetNumLootItems()
            for i = 1, numItems do
                local icon, name = GetLootSlotInfo(i)
                if name and name ~= "" then
                    RecordGatheredNode(name, icon)
                    break
                end
            end
            lastGatherSpell = nil
            
        -- Scenario B: Check for dropped items from regular mob kills
        else
            local numItems = GetNumLootItems()
            for i = 1, numItems do
                local icon, name = GetLootSlotInfo(i)
                local link = GetLootSlotLink(i)
                if name and link then
                    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
                    local _, _, _, _, _, itemType, itemSubType, _, _, _, _, classID, subclassID = getInfo(link)
                    local trackAs = nil
                    
                    if classID == 2 then
                        trackAs = "Weapon"
                    elseif classID == 4 then
                        trackAs = "Armor"
                    elseif classID == 0 then
                        if itemSubType == "Food & Drink" or string.find(name, "Food") then
                            trackAs = "Food"
                        elseif itemSubType == "Potion" or string.find(name, "Potion") then
                            trackAs = "Potion"
                        elseif itemSubType == "Scroll" or string.find(name, "Scroll") then
                            trackAs = "Scroll"
                        end
                    end
                    
                    if not trackAs and (TRACKED_CLOTH[name] or (string.find(name, "Cloth") and not (string.find(name, "Boots") or string.find(name, "Robe") or string.find(name, "Belt") or string.find(name, "Vest") or string.find(name, "Pants") or string.find(name, "Gloves")))) then
                        trackAs = "Mob Drop"
                    end
                    
                    if trackAs then
                        lastGatherSpell = trackAs
                        RecordGatheredNode(name, icon)
                        lastGatherSpell = nil
                    end
                end
            end
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        RefreshWorldMapPins()
        if gatherWindow and gatherWindow:IsShown() then
            gatherWindow:RefreshList()
        end
    end
end)
