local objectiveCache = {}

local function CheckForQuestProgress()
    if not C_QuestLog then return end
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    local progressDetected = false

    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and not info.isHidden then
            local qID = info.questID
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
