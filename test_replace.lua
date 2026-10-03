    function frame:RefreshQuests()
        local buckets = { current = {}, completed = {}, normal = {} }
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        local currentHeader = "World"
        DavesQuestsDB.pinnedQuests = DavesQuestsDB.pinnedQuests or {}
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
                    
                    if DavesQuestsDB.pinnedQuests[qID] then
                        table.insert(buckets.current, qData)
                    elseif isComplete then
                        table.insert(buckets.completed, qData)
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
                    row.pinBtn:SetText("[ Unpin ]")
                    row.pinBtn:GetFontString():SetTextColor(0.95, 0.82, 0.48)
                else
                    row.pinBtn:SetText("[ Pin ]")
                    row.pinBtn:GetFontString():SetTextColor(0.6, 0.6, 0.6)
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
