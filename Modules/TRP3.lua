-- ============================================================================
-- TRP3.lua - Total RP 3 Integration
-- ============================================================================
-- This module handles integration with Total RP 3 addon for displaying
-- roleplay names and custom colors in whisper windows.
--
-- This module runs in WhisperManager's context and has access to TRP3_API
-- passed from the TRP3 module loader.
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- TRP3 Integration
-- ============================================================================

--- Setup TRP3 integration with the provided API
-- This is called by the TRP3 module loader in TRP3_Module/WhisperManager.lua
-- @param TRP3_API table The Total RP 3 API object
function addon:SetupTRP3Integration(TRP3_API)
    if not TRP3_API then
        self:DebugMessage("TRP3 API not provided to SetupTRP3Integration")
        return
    end

    self:DebugMessage("Setting up TRP3 integration with API access")

    -- Cache TRP3 API functions for performance
    local getPlayerID = function() return TRP3_API.globals.player_id end  -- Get dynamically
    local getFullname = TRP3_API.chat.getFullnameForUnitUsingChatMethod
    local showCustomColors = TRP3_API.chat.configShowNameCustomColors
    local getCharacterInfo = TRP3_API.utils.getCharacterInfoTab
    local getConfig = TRP3_API.configuration.getValue
    local icon = TRP3_API.utils.str.icon
    local playerName = TRP3_API.globals.player
    local isOOC = TRP3_API.chat.disabledByOOC
    local unitInfoToID = TRP3_API.utils.str.unitInfoToID

    self:DebugMessage("TRP3 globals.player_id:", TRP3_API.globals.player_id)
    self:DebugMessage("TRP3 globals.player:", TRP3_API.globals.player)

    --- Get RP name for a character (plain text, no color codes)
    local function GetRPName(charName)
        if not charName or charName == "" or isOOC() then return nil end
        
        -- Parse name and realm from input
        local name, realm = charName:match("^([^%-]+)%-?(.*)$")
        if not name or name == "" then return nil end
        
        -- Use unitInfoToID to properly format the unit ID
        local unitID = unitInfoToID(name, realm ~= "" and realm or nil)
        if not unitID or unitID == "" then return nil end

        -- Protected call to getFullname to catch any TRP3 errors
        local success, rpName = pcall(getFullname, unitID)
        if success and rpName and rpName ~= "" then
            local shortName = name
            if rpName ~= shortName then return rpName end
        end
        return nil
    end

    --- Get RP name for a character with color coding and icon
    local function GetRPNameWithColor(charName)
        local rpName = GetRPName(charName)
        if not rpName then return nil end

        -- Parse name and realm from input
        local name, realm = charName:match("^([^%-]+)%-?(.*)$")
        if not name or name == "" then return nil end
        
        -- Use unitInfoToID to properly format the unit ID
        local unitID = unitInfoToID(name, realm ~= "" and realm or nil)
        if not unitID or unitID == "" then return nil end

        local color = nil
        
        -- Get custom color if enabled (with error protection)
        if showCustomColors() then
            local success, player = pcall(AddOn_TotalRP3.Player.CreateFromCharacterID, unitID)
            if success and player then
                local colorSuccess, customColor = pcall(player.GetCustomColorForDisplay, player)
                if colorSuccess and customColor then color = customColor end
            end
        end
        
        -- Fall back to class color if no custom color
        if not color then
            local success, classColor = pcall(TRP3_API.GetClassDisplayColor, UnitClassBase(unitID))
            if success and classColor then color = classColor end
        end

        if color then rpName = color:WrapTextInColorCode(rpName) end

        if getConfig("chat_show_icon") then
            local success, info = pcall(getCharacterInfo, unitID)
            if success and info and info.characteristics and info.characteristics.IC then
                rpName = icon(info.characteristics.IC, 15) .. " " .. rpName
            end
        end

        return rpName
    end

    --- Get player's own RP name (plain text, no color codes)
    local function GetMyRPName()
        local playerID = getPlayerID()
        addon:DebugMessage("[TRP3:GetMyRPName] Starting - isOOC:", isOOC(), "playerID:", playerID)
        if isOOC() then 
            addon:DebugMessage("[TRP3:GetMyRPName] OOC mode is active, returning nil")
            return nil 
        end
        if not playerID or playerID == "" then 
            addon:DebugMessage("[TRP3:GetMyRPName] No playerID, returning nil")
            return nil 
        end

        local success, info = pcall(getCharacterInfo, playerID)
        addon:DebugMessage("[TRP3:GetMyRPName] getCharacterInfo success:", success, "has info:", info ~= nil)
        local name = nil
        local hasProfile = false
        
        if success and info and info.characteristics then
            local firstName = info.characteristics.FN
            local lastName = info.characteristics.LN
            addon:DebugMessage("[TRP3:GetMyRPName] FirstName:", firstName, "LastName:", lastName)
            
            if firstName and firstName ~= "" then
                hasProfile = true
                name = firstName
                if lastName and lastName ~= "" then
                    name = name .. " " .. lastName
                end
            end
        end
        
        if hasProfile and name and name ~= "" then 
            addon:DebugMessage("[TRP3:GetMyRPName] Returning profile name:", name)
            return name 
        end
        
        if not name or name == "" then
            local fullnameSuccess, fullname = pcall(getFullname, playerID)
            addon:DebugMessage("[TRP3:GetMyRPName] getFullname success:", fullnameSuccess, "fullname:", fullname, "playerName:", playerName)
            if fullnameSuccess and fullname and fullname ~= "" and fullname ~= playerName then
                addon:DebugMessage("[TRP3:GetMyRPName] Returning fullname:", fullname)
                return fullname
            end
        end
        
        addon:DebugMessage("[TRP3:GetMyRPName] No valid RP name found, returning nil")
        return nil
    end

    --- Get player's own RP name with color coding and icon
    local function GetMyRPNameWithColor()
        local name = GetMyRPName()
        if not name then return nil end

        local playerID = getPlayerID()
        local color = nil
        
        -- Get custom color if enabled (with error protection)
        if showCustomColors() then
            local success, player = pcall(AddOn_TotalRP3.Player.GetCurrentUser)
            if success and player then
                local colorSuccess, customColor = pcall(player.GetCustomColorForDisplay, player)
                if colorSuccess and customColor then color = customColor end
            end
        end
        
        -- Fall back to class color if no custom color
        if not color then
            local success, classColor = pcall(TRP3_API.GetClassDisplayColor, UnitClassBase("player"))
            if success and classColor then color = classColor end
        end

        if color then name = color:WrapTextInColorCode(name) end

        if getConfig("chat_show_icon") and playerID and playerID ~= "" then
            local success, info = pcall(getCharacterInfo, playerID)
            if success and info and info.characteristics and info.characteristics.IC then
                name = icon(info.characteristics.IC, 15) .. " " .. name
            end
        end

        return name
    end

    -- Register the functions globally on WhisperManager
    self.TRP3_GetRPName = GetRPName
    self.TRP3_GetRPNameWithColor = GetRPNameWithColor
    self.TRP3_GetMyRPName = GetMyRPName
    self.TRP3_GetMyRPNameWithColor = GetMyRPNameWithColor

    self:Print("Total RP 3 integration loaded! RP names will appear in whisper windows.")
    self:DebugMessage("TRP3 integration functions registered successfully")
end

--- Legacy initialization method (for backwards compatibility)
-- Tries to access TRP3_API from global namespace
function addon:InitializeTRP3Integration()
    local TRP3_API = _G.TRP3_API
    if not TRP3_API then
        self:DebugMessage("TRP3 not detected, skipping integration")
        return
    end

    self:DebugMessage("TRP3 detected via legacy method, calling SetupTRP3Integration")
    self:SetupTRP3Integration(TRP3_API)
end
