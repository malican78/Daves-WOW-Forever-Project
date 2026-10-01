local addonName, ns = ...

-- List of standard frames and load-on-demand Blizzard modules
local targetFrames = {
    -- Core UI
    "CharacterFrame",
    "SpellBookFrame",
    "FriendsFrame",
    "PVEFrame",
    "MerchantFrame",
    "MailFrame",
    "BankFrame",
    "GossipFrame",
    "QuestFrame",
    "QuestLogPopupDetailFrame",
    "TradeFrame",
    "ItemSocketingFrame",
    "DressUpFrame",

    -- On-Demand Blizzard Addons
    "Blizzard_MacroUI",
    "Blizzard_Professions",
    "Blizzard_Communities",
    "Blizzard_ClassTalentUI",
    "Blizzard_AuctionHouseUI",
    "Blizzard_TradeSkillUI",
}

local addonToFrame = {
    ["Blizzard_MacroUI"] = "MacroFrame",
    ["Blizzard_Professions"] = "ProfessionsFrame",
    ["Blizzard_Communities"] = "CommunitiesFrame",
    ["Blizzard_ClassTalentUI"] = "ClassTalentFrame",
    ["Blizzard_AuctionHouseUI"] = "AuctionHouseFrame",
    ["Blizzard_TradeSkillUI"] = "TradeFrame",
}

-- Restore saved positions cleanly
local function RestoreFramePosition(frame)
    local name = frame:GetName()
    if not name or not DavesMobileFramesDB or not DavesMobileFramesDB[name] then return end

    local pos = DavesMobileFramesDB[name]
    frame.isSettingPoint = true
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    frame.isSettingPoint = false
end

-- Save current position
local function SaveFramePosition(frame)
    local name = frame:GetName()
    if not name or not DavesMobileFramesDB then return end

    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        DavesMobileFramesDB[name] = {
            point = point,
            relPoint = relPoint,
            x = math.floor(x + 0.5),
            y = math.floor(y + 0.5),
        }
    end
end

-- Make the frame draggable and lock its position instantly
local function EnableDragging(frame)
    if not frame or frame.isDaveMovable then return end

    local name = frame:GetName()
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    -- Favor TitleContainer for dragging; fall back to frame itself
    local dragHandle = frame.TitleContainer or frame
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")

    dragHandle:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not frame.isMoving then
            frame:StartMoving()
            frame.isMoving = true
        end
    end)

    dragHandle:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and frame.isMoving then
            frame:StopMovingOrSizing()
            frame.isMoving = false
            SaveFramePosition(frame)
        end
    end)

    -- Only override SetPoint if a custom position was actually saved
    hooksecurefunc(frame, "SetPoint", function(self)
        if self.isSettingPoint then return end
        if DavesMobileFramesDB and name and DavesMobileFramesDB[name] then
            RestoreFramePosition(self)
        end
    end)

    -- If the frame is currently visible and has a saved position, apply it
    if DavesMobileFramesDB and name and DavesMobileFramesDB[name] and frame:IsShown() then
        RestoreFramePosition(frame)
    end

    frame.isDaveMovable = true
end

-- Event Handling
local eventHandler = CreateFrame("Frame")
eventHandler:RegisterEvent("ADDON_LOADED")
eventHandler:RegisterEvent("PLAYER_LOGIN")
eventHandler:RegisterEvent("TRADE_SHOW")

eventHandler:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            DavesMobileFramesDB = DavesMobileFramesDB or {}
        end

        local targetName = addonToFrame[arg1] or arg1
        if _G[targetName] then
            EnableDragging(_G[targetName])
        end

    elseif event == "PLAYER_LOGIN" then
        for _, name in ipairs(targetFrames) do
            if _G[name] then
                EnableDragging(_G[name])
            end
        end

    elseif event == "TRADE_SHOW" then
        -- Catch TradeFrame dynamically when a trade initiates
        if TradeFrame then
            EnableDragging(TradeFrame)
            if DavesMobileFramesDB and DavesMobileFramesDB["TradeFrame"] then
                RestoreFramePosition(TradeFrame)
            end
        end
    end
end)

-- Slash command to reset all positions
SLASH_DAVESMOBILEFRAMES1 = "/dmfreset"
SlashCmdList["DAVESMOBILEFRAMES"] = function()
    DavesMobileFramesDB = {}
    print("|cff00ccff[Dave's Mobile Frames]|r All frame positions reset. Type /reload to apply defaults.")
end