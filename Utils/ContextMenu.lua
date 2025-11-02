-- ============================================================================
-- ContextMenu.lua - Player context menu functionality
-- ============================================================================
-- This module handles right-click context menus for player names.
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- Context Menu Functions
-- ============================================================================

--- Open a context menu for a player
-- @param owner table Optional frame to anchor menu to
-- @param playerName string Full player name (with realm)
-- @param displayName string Display name to show in menu
-- @param isBNet boolean Whether this is a BNet player
-- @param bnSenderID number BNet sender ID (if BNet player)
function addon:OpenPlayerContextMenu(owner, playerName, displayName, isBNet, bnSenderID)
    -- Support legacy signature where owner isn't provided
    if type(owner) == "string" or owner == nil then
        owner, playerName, displayName, isBNet, bnSenderID = nil, owner, playerName, displayName, isBNet
    end
    
    addon:DebugMessage("=== OpenPlayerContextMenu START ===")
    addon:DebugMessage("playerName:", playerName)
    addon:DebugMessage("displayName:", displayName)
    addon:DebugMessage("isBNet:", isBNet)
    addon:DebugMessage("bnSenderID:", bnSenderID)

    if not playerName and not isBNet then 
        addon:DebugMessage("ERROR: No playerName and not BNet, returning")
        return 
    end

    addon:DebugMessage("MenuUtil available:", MenuUtil ~= nil)
    addon:DebugMessage("MenuUtil.CreateContextMenu available:", MenuUtil and MenuUtil.CreateContextMenu ~= nil)

    -- Menu generator function
    local function menuGenerator(ownerFrame, rootDescription)
        local label = displayName or addon.StripRealmFromName(playerName) or playerName
        if label and label ~= "" then
            rootDescription:CreateTitle(label)
        end

        if not isBNet and playerName and playerName ~= "" then
            rootDescription:CreateButton(WHISPER, function() ChatFrame_SendTell(playerName) end)
            rootDescription:CreateButton(INVITE, function() C_PartyInfo.InviteUnit(playerName) end)
            local raidTargetButton = rootDescription:CreateButton(RAID_TARGET_ICON)
            raidTargetButton:CreateButton(RAID_TARGET_NONE, function() SetRaidTarget(playerName, 0) end)
            for i = 1, 8 do
                raidTargetButton:CreateButton(_G["RAID_TARGET_" .. i], function() SetRaidTarget(playerName, i) end)
            end
            rootDescription:CreateButton(ADD_FRIEND, function() C_FriendList.AddFriend(playerName) end)
            rootDescription:CreateButton(PLAYER_REPORT, function()
                local guid = C_PlayerInfo.GUIDFromPlayerName(playerName)
                if guid then C_ReportSystem.OpenReportPlayerDialog(guid, playerName) end
            end)
        elseif isBNet and bnSenderID then
            if ChatFrame_SendBNetTell then
                rootDescription:CreateButton(WHISPER, function() ChatFrame_SendBNetTell(displayName or playerName) end)
            end
            if BNInviteFriend then
                rootDescription:CreateButton(INVITE, function() BNInviteFriend(bnSenderID) end)
            end
        end

        rootDescription:CreateButton(CANCEL, function() end)
    end

    -- Attempt to create and show the modern MenuUtil menu
    local createOwner = owner or UIParent
    local menu = nil
    local ok1, err1 = pcall(function() menu = MenuUtil.CreateContextMenu(createOwner, menuGenerator) end)
    addon:DebugMessage("Menu create (owner) pcall ok:", ok1, "owner:", createOwner and createOwner:GetName() or "UIParent", "menu created:", menu ~= nil, "err:", err1)

    local shown = false
    if menu and type(menu.Show) == "function" then
        local okShow = pcall(function() menu:Show() end)
        shown = okShow
        addon:DebugMessage("Called menu:Show(), success:", okShow)
    end

    -- Try creating with mouse owner if not shown
    if not shown then
        local ok2, mouseFrame = pcall(function() return GetMouseFocus() end)
        if ok2 and mouseFrame then
            local altMenu = nil
            local ok3, err3 = pcall(function() altMenu = MenuUtil.CreateContextMenu(mouseFrame, menuGenerator) end)
            addon:DebugMessage("Menu create (mouse owner) pcall ok:", ok3, "altMenu created:", altMenu ~= nil, "err:", err3)
            if altMenu and type(altMenu.Show) == "function" then
                local okShow2 = pcall(function() altMenu:Show() end)
                shown = okShow2
                addon:DebugMessage("Called altMenu:Show(), success:", okShow2)
            end
        else
            addon:DebugMessage("GetMouseFocus not available or returned nil; owner fallback skipped")
        end
    end

    -- Fallback to EasyMenu if modern menu didn't show
    if not shown then
        addon:DebugMessage("Modern menu not shown; attempting EasyMenu fallback")
        if type(EasyMenu) == "function" then
            local menuList = {}
            if not isBNet and playerName and playerName ~= "" then
                table.insert(menuList, { text = WHISPER, func = function() ChatFrame_SendTell(playerName) end })
                table.insert(menuList, { text = INVITE, func = function() C_PartyInfo.InviteUnit(playerName) end })
                table.insert(menuList, { text = ADD_FRIEND, func = function() C_FriendList.AddFriend(playerName) end })
            elseif isBNet and bnSenderID then
                if ChatFrame_SendBNetTell then
                    table.insert(menuList, { text = WHISPER, func = function() ChatFrame_SendBNetTell(displayName or playerName) end })
                end
            end
            table.insert(menuList, { text = CANCEL, func = function() end })
            if not _G.WhisperManager_EasyMenuFrame then
                _G.WhisperManager_EasyMenuFrame = CreateFrame("Frame", "WhisperManager_EasyMenuFrame", UIParent, "UIDropDownMenuTemplate")
            end
            EasyMenu(menuList, _G.WhisperManager_EasyMenuFrame, "cursor", 0, 0, "MENU")
            addon:DebugMessage("EasyMenu displayed (fallback)")
        else
            addon:DebugMessage("EasyMenu not available; cannot show fallback menu")
        end
    end

    addon:DebugMessage("=== OpenPlayerContextMenu END ===")
end
