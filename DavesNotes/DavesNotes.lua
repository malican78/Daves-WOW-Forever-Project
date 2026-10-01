local manager
local noteList
local noteRows = {}
local noteWindows = {}
local noteEditors = {}
local activeNote
local db
local refreshNoteList
local WINDOW_COLOR = { 0.73, 0.60, 0.37 }
local WINDOW_BORDER_COLOR = { 0.48, 0.36, 0.22 }

local function setTextureColor(texture, r, g, b, a)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r, g, b, a)
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

local function createPixelButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(text)
    return button
end

local function registerEscapeFrame(frameName)
    UISpecialFrames = UISpecialFrames or {}
    for index = 1, table.getn(UISpecialFrames) do
        if UISpecialFrames[index] == frameName then
            return
        end
    end
    table.insert(UISpecialFrames, frameName)
end

local function createPanel(name, width, height, backgroundColor, borderColor, x, y, escapeDismiss)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetFrameStrata("High")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    setTextureColor(frame.background, backgroundColor[1], backgroundColor[2], backgroundColor[3], 0.98)
    frame.background:SetAllPoints(frame)
    createBorder(frame, borderColor, 3)
    if escapeDismiss ~= false then
        registerEscapeFrame(name)
    end
    return frame
end

local function applyWindowBackground(frame)
    frame.background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    frame.background:SetAllPoints(frame)
    if frame.background.SetHorizTile then
        frame.background:SetHorizTile(true)
    end
    if frame.background.SetVertTile then
        frame.background:SetVertTile(true)
    end
end

local function savePosition(frame, record)
    local _, _, _, x, y = frame:GetPoint()
    record.x = x
    record.y = y
end

local function notePreview(text)
    local preview = string.gsub(text or "", "\n", " ")
    preview = string.gsub(preview, "\r", " ")
    if preview == "" then
        return "No text yet"
    end
    if string.len(preview) > 52 then
        return string.sub(preview, 1, 49) .. "..."
    end
    return preview
end

local function makeDraggableRegion(region, window, record)
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function()
        window:StartMoving()
    end)
    region:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        savePosition(window, record)
    end)
end

local function raiseNoteFrame(frame)
    local level = UIParent:GetFrameLevel() + 30
    if manager then
        level = math.max(level, manager:GetFrameLevel() + 20)
    end
    for _, otherFrame in pairs(noteWindows) do
        if otherFrame ~= frame and otherFrame:IsShown() then
            level = math.max(level, otherFrame:GetFrameLevel() + 10)
        end
    end
    frame:SetFrameLevel(level)
end

local function buildNote(note)
    local frameName = "DavesNotesNote" .. note.id
    local frame = createPanel(frameName, note.width or 350, note.height or 320, WINDOW_COLOR, WINDOW_BORDER_COLOR, note.x, note.y, false)
    frame:SetFrameStrata("DIALOG")
    raiseNoteFrame(frame)
    frame:SetResizable(true)
    applyWindowBackground(frame)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    header:SetHeight(34)
    makeDraggableRegion(header, frame, note)

    header.background = header:CreateTexture(nil, "BACKGROUND")
    applyWindowBackground(header)
    createBorder(header, WINDOW_BORDER_COLOR, 2)

    local title = CreateFrame("EditBox", nil, header)
    title:SetWidth(math.max(70, math.min(218, (note.width or 350) - 106)))
    title:SetHeight(24)
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetFontObject(GameFontNormal)
    title:SetTextColor(1, 0.82, 0.30)
    title:SetTextInsets(3, 3, 0, 0)
    title:SetAutoFocus(false)
    title:SetMaxLetters(48)
    makeDraggableRegion(title, frame, note)
    title:SetText(note.title or "Untitled")
    title:SetScript("OnTextChanged", function(self)
        note.title = self:GetText()
        if noteList then
            local row = noteRows[note.id]
            if row then
                row.title:SetText(note.title)
            end
        end
    end)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", -7, 0)
    close:SetScript("OnClick", function()
        savePosition(frame, note)
        frame:Hide()
    end)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -52)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 16)
    scroll.background = scroll:CreateTexture(nil, "BACKGROUND")
    setTextureColor(scroll.background, 0.99, 0.97, 0.88, 1)
    scroll.background:SetAllPoints(scroll)
    createBorder(scroll, { 0.68, 0.52, 0.29 })

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetWidth(math.max(200, (note.width or 350) - 80))
    edit:SetHeight(1000)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(20000)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextColor(0.15, 0.12, 0.08)
    edit:SetTextInsets(10, 10, 10, 10)
    edit:SetText(note.text or "")
    edit:SetScript("OnTextChanged", function(self)
        note.text = self:GetText()
        local row = noteRows[note.id]
        if row and row.preview then
            row.preview:SetText(notePreview(note.text))
        end
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        savePosition(frame, note)
    end)
    edit:SetScript("OnEditFocusGained", function()
        activeNote = note
    end)
    scroll:SetScrollChild(edit)
    noteEditors[note.id] = edit

    frame:SetScript("OnHide", function()
        if activeNote == note then
            activeNote = nil
        end
    end)

    frame:SetScript("OnSizeChanged", function(self, width, height)
        local boundedWidth = math.max(280, math.min(680, width))
        local boundedHeight = math.max(220, math.min(760, height))
        if boundedWidth ~= width or boundedHeight ~= height then
            self:SetWidth(boundedWidth)
            self:SetHeight(boundedHeight)
            return
        end
        note.width = width
        note.height = height
        title:SetWidth(math.max(70, math.min(218, width - 106)))
        edit:SetWidth(math.max(200, width - 80))
    end)

    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetWidth(16)
    resizeGrip:SetHeight(16)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    resizeGrip:EnableMouse(true)
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetScript("OnDragStart", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition(frame, note)
    end)

    resizeGrip.texture = resizeGrip:CreateTexture(nil, "OVERLAY")
    setTextureColor(resizeGrip.texture, 0.48, 0.34, 0.18, 1)
    resizeGrip.texture:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -1, 1)
    resizeGrip.texture:SetWidth(9)
    resizeGrip.texture:SetHeight(9)

    noteWindows[note.id] = frame
    return frame
end

local function openNote(note)
    local frame = noteWindows[note.id]
    if not frame then
        frame = buildNote(note)
    end
    frame:Show()
    if noteEditors[note.id] then
        noteEditors[note.id]:SetFocus()
    end
end

local function removeNote(noteID)
    for index = 1, table.getn(db.notes) do
        if db.notes[index].id == noteID then
            table.remove(db.notes, index)
            break
        end
    end
    if noteWindows[noteID] then
        noteWindows[noteID]:Hide()
        noteWindows[noteID] = nil
    end
    if noteList then
        local row = noteRows[noteID]
        if row then
            row:Hide()
            noteRows[noteID] = nil
        end
        refreshNoteList()
    end
end

refreshNoteList = function()
    if not noteList then
        return
    end

    local count = table.getn(db.notes)
    noteList:SetHeight(math.max(1, count * 72))
    if manager and manager.countLabel then
        manager.countLabel:SetText(count .. (count == 1 and " saved note" or " saved notes"))
    end
    if manager and manager.emptyText then
        if count == 0 then
            manager.emptyText:Show()
        else
            manager.emptyText:Hide()
        end
    end

    for index = 1, count do
        local note = db.notes[index]
        local row = noteRows[note.id]
        if not row then
            row = CreateFrame("Button", nil, noteList)
            row:SetWidth(310)
            row:SetHeight(64)
            row:RegisterForClicks("LeftButtonUp")
            row.background = row:CreateTexture(nil, "BACKGROUND")
            setTextureColor(row.background, 0.98, 0.95, 0.82, 1)
            row.background:SetAllPoints(row)

            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            setTextureColor(row.highlight, 1, 0.82, 0.30, 0.18)
            row.highlight:SetAllPoints(row)

            row.accent = row:CreateTexture(nil, "ARTWORK")
            setTextureColor(row.accent, 0.61, 0.43, 0.22, 1)
            row.accent:SetPoint("TOPLEFT", row, "TOPLEFT")
            row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
            row.accent:SetWidth(4)

            row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -9)
            row.title:SetWidth(230)
            row.title:SetJustifyH("LEFT")

            row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.preview:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
            row.preview:SetWidth(230)
            row.preview:SetJustifyH("LEFT")
            row.preview:SetTextColor(0.34, 0.28, 0.20)

            row.delete = createPixelButton(row, 48, 24, "Delete")
            row.delete:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            noteRows[note.id] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", noteList, "TOPLEFT", 0, -(index - 1) * 72)
        row.title:SetText(note.title or "Untitled")
        row.preview:SetText(notePreview(note.text))
        row:SetScript("OnClick", function()
            openNote(note)
        end)
        row.delete:SetScript("OnClick", function()
            removeNote(note.id)
        end)
        row:Show()
    end
end

local function createNote(title, text)
    local id = db.nextID
    db.nextID = id + 1
    local note = {
        id = id,
        title = title or ("Note " .. id),
        text = text or "",
        x = (id - 1) * 24,
        y = -(id - 1) * 24,
    }
    table.insert(db.notes, note)
    refreshNoteList()
    openNote(note)
    if noteEditors[note.id] then
        noteEditors[note.id]:SetFocus()
        noteEditors[note.id]:SetCursorPosition(string.len(note.text))
    end
    return note
end

function DavesNotes_AddNote(title, text)
    if not db then
        return false
    end

    createNote(title, text)
    return true
end

function DavesNotes_AddItemInfo(title, text)
    if not db then
        return false
    end

    local note = activeNote
    local editor = note and noteEditors[note.id]
    local frame = note and noteWindows[note.id]
    if editor and frame and frame:IsShown() then
        local currentText = editor:GetText() or ""
        local cursor = editor:GetCursorPosition()
        if type(cursor) ~= "number" then
            cursor = string.len(currentText)
        end
        cursor = math.max(0, math.min(cursor, string.len(currentText)))

        local before = string.sub(currentText, 1, cursor)
        local after = string.sub(currentText, cursor + 1)
        local block = (title or "Item information") .. "\n" .. (text or "")
        if before ~= "" and string.sub(before, -1) ~= "\n" then
            before = before .. "\n"
        end
        if after ~= "" and string.sub(after, 1, 1) ~= "\n" then
            block = block .. "\n"
        end

        editor:SetText(before .. block .. after)
        editor:SetCursorPosition(string.len(before) + string.len(block))
        editor:SetFocus()
        return "inserted"
    end

    createNote(title, text)
    return "created"
end

local function buildManager()
    manager = createPanel("DavesNotesFrame", 380, 430, WINDOW_COLOR, WINDOW_BORDER_COLOR, db.x, db.y)
    manager:SetFrameLevel(UIParent:GetFrameLevel() + 10)
    applyWindowBackground(manager)

    local header = CreateFrame("Frame", nil, manager)
    header:SetPoint("TOPLEFT", manager, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -4, -4)
    header:SetHeight(42)
    makeDraggableRegion(header, manager, db)
    header.background = header:CreateTexture(nil, "BACKGROUND")
    applyWindowBackground(header)
    createBorder(header, WINDOW_BORDER_COLOR, 2)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 14, -7)
    title:SetText("Dave's Notes")
    title:SetTextColor(1, 0.82, 0.30)

    manager.countLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    manager.countLabel:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 14, 5)
    manager.countLabel:SetTextColor(0.95, 0.82, 0.48)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    close:SetScript("OnClick", function()
        savePosition(manager, db)
        manager:Hide()
    end)
    local newButton = createPixelButton(manager, 104, 26, "New note")
    newButton:SetPoint("TOPLEFT", manager, "TOPLEFT", 16, -56)
    newButton:SetScript("OnClick", function()
        createNote()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, manager, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", manager, "TOPLEFT", 16, -94)
    scroll:SetPoint("BOTTOMRIGHT", manager, "BOTTOMRIGHT", -30, 16)

    noteList = CreateFrame("Frame", nil, scroll)
    noteList:SetWidth(310)
    noteList:SetHeight(1)
    scroll:SetScrollChild(noteList)

    manager.emptyText = manager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    manager.emptyText:SetPoint("CENTER", scroll, "CENTER", 0, 10)
    manager.emptyText:SetWidth(280)
    manager.emptyText:SetJustifyH("CENTER")
    manager.emptyText:SetText("No notes yet. Create one to get started.")
    manager.emptyText:SetTextColor(0.95, 0.82, 0.48)

    refreshNoteList()
    manager:Hide()
end

local function toggleWindow()
    if not manager then
        buildManager()
    end

    if manager:IsShown() then
        savePosition(manager, db)
        manager:Hide()
    else
        manager:Show()
    end
end

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function()
    if type(DavesNotesDB) ~= "table" then
        DavesNotesDB = {}
    end
    db = DavesNotesDB
    db.notes = type(db.notes) == "table" and db.notes or {}
    db.nextID = tonumber(db.nextID) or 1

    if table.getn(db.notes) == 0 and type(db.text) == "string" and db.text ~= "" then
        db.notes[1] = { id = db.nextID, title = "Note 1", text = db.text }
        db.nextID = db.nextID + 1
    end
    db.text = nil

    for index = 1, table.getn(db.notes) do
        local note = db.notes[index]
        note.id = tonumber(note.id) or index
        note.title = type(note.title) == "string" and note.title or ("Note " .. note.id)
        note.text = type(note.text) == "string" and note.text or ""
        if note.id >= db.nextID then
            db.nextID = note.id + 1
        end
    end

    SLASH_DAVESNOTES1 = "/dnotes"
    SLASH_DAVESNOTES2 = "/davesnotes"
    SlashCmdList.DAVESNOTES = toggleWindow
end)