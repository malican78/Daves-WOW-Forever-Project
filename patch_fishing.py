with open('DavesGather/DavesGather.lua', 'r') as f:
    content = f.read()

# 1. Add showFishing to GetFilters()
content = content.replace('''            showLeather = true,
            showOther = true''', '''            showLeather = true,
            showFishing = true,
            showOther = true''')

# 2. Add showFishing to RefreshWorldMapPins()
content = content.replace('''            elseif prof == "Skinning" then show = filters.showLeather
            else show = filters.showOther end''', '''            elseif prof == "Skinning" then show = filters.showLeather
            elseif prof == "Fishing" then show = filters.showFishing
            else show = filters.showOther end''')

# 3. Increase optionsMenu size
content = content.replace('optionsMenu:SetSize(165, 164)', 'optionsMenu:SetSize(165, 186)')

# 4. Add showFishing to ToggleAllFilters
content = content.replace('''        local anyOn = filters.showOre or filters.showHerb or filters.showCloth or filters.showLeather or filters.showOther''', '''        local anyOn = filters.showOre or filters.showHerb or filters.showCloth or filters.showLeather or filters.showFishing or filters.showOther''')

content = content.replace('''        filters.showLeather = newState
        filters.showOther = newState''', '''        filters.showLeather = newState
        filters.showFishing = newState
        filters.showOther = newState''')

# 5. Add toggleFishing
content = content.replace('''    local toggleLeather = CreateMenuItem(-93, function() ToggleFilter("showLeather") end)
    local toggleOther = CreateMenuItem(-115, function() ToggleFilter("showOther") end)
    local toggleAllBtn = CreateMenuItem(-137, ToggleAllFilters)''', '''    local toggleLeather = CreateMenuItem(-93, function() ToggleFilter("showLeather") end)
    local toggleFishing = CreateMenuItem(-115, function() ToggleFilter("showFishing") end)
    local toggleOther = CreateMenuItem(-137, function() ToggleFilter("showOther") end)
    local toggleAllBtn = CreateMenuItem(-159, ToggleAllFilters)''')

# 6. Update GetText for toggleFishing
content = content.replace('''        toggleLeather.text:SetText(GetText("showLeather", "Leather (Skinning)"))
        toggleOther.text:SetText(GetText("showOther", "Others (Fishing, etc)"))''', '''        toggleLeather.text:SetText(GetText("showLeather", "Leather (Skinning)"))
        toggleFishing.text:SetText(GetText("showFishing", "Fish (Fishing)"))
        toggleOther.text:SetText(GetText("showOther", "Others (Treasures, etc)"))''')

# 7. Update anyOn for text
content = content.replace('''        local anyOn = filters.showOre or filters.showHerb or filters.showCloth or filters.showLeather or filters.showOther''', '''        local anyOn = filters.showOre or filters.showHerb or filters.showCloth or filters.showLeather or filters.showFishing or filters.showOther''')

# 8. Add Fishing to Category Picker (OpenCategoryPicker)
content = content.replace('''            { id = "Skinning", name = "Leather (Skinning)" },
            { id = "Mob Drop", name = "Cloth (Mob Drops)" },''', '''            { id = "Skinning", name = "Leather (Skinning)" },
            { id = "Mob Drop", name = "Cloth (Mob Drops)" },
            { id = "Fishing", name = "Fish (Fishing)" },''')

# 9. Update "Other" fallback block in RefreshList
content = content.replace('''                            if prof == "Herbalism" or prof == "Mining" or prof == "Mob Drop" or prof == "Skinning" or prof == "Armor" or prof == "Weapon" or prof == "Food" or prof == "Potion" or prof == "Scroll" then''', '''                            if prof == "Herbalism" or prof == "Mining" or prof == "Mob Drop" or prof == "Skinning" or prof == "Fishing" or prof == "Armor" or prof == "Weapon" or prof == "Food" or prof == "Potion" or prof == "Scroll" then''')

with open('DavesGather/DavesGather.lua', 'w') as f:
    f.write(content)
