local function UpdateNativeStyle()
    local isNative = DavesQuestsDB.nativeTrackerStyle
    if not questWindow then return end

    if isNative then
        questWindow.background:Hide()
        if questWindow.borders then for _, t in pairs(questWindow.borders) do t:Hide() end end
        if questWindow.header then
            questWindow.header.background:Hide()
            if questWindow.header.borders then for _, t in pairs(questWindow.header.borders) do t:Hide() end end
        end
    else
        questWindow.background:Show()
        if questWindow.borders then for _, t in pairs(questWindow.borders) do t:Show() end end
        if questWindow.header then
            questWindow.header.background:Show()
            if questWindow.header.borders then for _, t in pairs(questWindow.header.borders) do t:Show() end end
        end
    end

    for _, row in pairs(questRows) do
        if isNative then
            row.bg:Hide()
            row.highlight:Hide()
            if row.borders then for _, t in pairs(row.borders) do t:Hide() end end
            row.title:SetTextColor(1, 0.82, 0)
        else
            row.bg:Show()
            row.highlight:Show()
            if row.borders then for _, t in pairs(row.borders) do t:Show() end end
            row.title:SetTextColor(0.50, 0.22, 0.02)
        end
    end
end
