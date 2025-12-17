-- ============================================================================
-- TRP3.lua - Total RP 3 Integration
-- ============================================================================
-- This module handles integration with Total RP 3 addon for displaying
-- roleplay names and custom colors in whisper windows.
-- ============================================================================

local addon = WhisperManager;

-- ============================================================================
-- TRP3 Integration
-- ============================================================================

--- Initialize Total RP 3 integration if the addon is available
function addon:InitializeTRP3Integration()
    -- Check if TRP3 is loaded
    local TRP3_API = _G.TRP3_API
    if not TRP3_API then
        self:DebugMessage("TRP3 not detected, skipping integration")
        return
    end

    self:DebugMessage("TRP3 detected, setting up integration functions")

    local playerID = TRP3_API.globals.player_id
    local getFullname = TRP3_API.chat.getFullnameForUnitUsingChatMethod
    local showCustomColors = TRP3_API.chat.configShowNameCustomColors
    local getData = TRP3_API.profile.getData
    local getConfig = TRP3_API.configuration.getValue
    local icon = TRP3_API.utils.str.icon
    local playerName = TRP3_API.globals.player
    local isOOC = TRP3_API.chat.disabledByOOC

    --- Get RP name for a character (without color)
    local function GetRPName(charName)
        if not charName or charName == "" or isOOC() then return nil end
        
        local fullName = charName
        if not fullName:find("-") then
            fullName = charName .. "-" .. GetRealmName():gsub("%s+", "")
        end

        local rpName = getFullname(fullName)
        if rpName and rpName ~= "" then
            local shortName = charName:match("^([^%-]+)") or charName
            if rpName ~= shortName then return rpName end
        end
        return nil
    end

    --- Get RP name for a character with color coding
    local function GetRPNameWithColor(charName)
        local rpName = GetRPName(charName)
        if not rpName then return nil end

        local fullName = charName
        if not fullName:find("-") then
            fullName = charName .. "-" .. GetRealmName():gsub("%s+", "")
        end

        local color = TRP3_API.GetClassDisplayColor(UnitClassBase(fullName))
        
        if showCustomColors() then
            local profile = TRP3_API.register.getUnitProfile(fullName)
            if profile and profile.characteristics and profile.characteristics.CH then
                local customColor = TRP3_API.CreateColorFromHexString(profile.characteristics.CH)
                if customColor then color = customColor end
            end
        end

        if color then rpName = color:WrapTextInColorCode(rpName) end

        if getConfig("chat_show_icon") then
            local profile = TRP3_API.register.getUnitProfile(fullName)
            if profile and profile.characteristics and profile.characteristics.IC then
                rpName = icon(profile.characteristics.IC, 15) .. " " .. rpName
            end
        end

        return rpName
    end

    --- Get player's own RP name (without color)
    local function GetMyRPName()
        if isOOC() then return nil end

        local info = getData("player")
        local name = nil
        local hasProfile = false
        
        if info and info.characteristics then
            local firstName = info.characteristics.FN
            local lastName = info.characteristics.LN
            
            if firstName and firstName ~= "" then
                hasProfile = true
                name = firstName
                if lastName and lastName ~= "" then
                    name = name .. " " .. lastName
                end
            end
        end
        
        if hasProfile and name and name ~= "" then return name end
        
        if not name or name == "" then
            name = getFullname(playerID)
            if name and name ~= "" and name ~= playerName then return name end
        end
        
        return nil
    end

    --- Get player's own RP name with color coding
    local function GetMyRPNameWithColor()
        local name = GetMyRPName()
        if not name then return nil end

        local color = TRP3_API.GetClassDisplayColor(UnitClassBase("player"))

        if showCustomColors() then
            local player = AddOn_TotalRP3.Player.GetCurrentUser()
            local customColor = player:GetCustomColorForDisplay()
            if customColor then color = customColor end
        end

        if color then name = color:WrapTextInColorCode(name) end

        if getConfig("chat_show_icon") then
            local info = getData("player")
            if info and info.characteristics and info.characteristics.IC then
                name = icon(info.characteristics.IC, 15) .. " " .. name
            end
        end

        return name
    end

    -- Register the functions on the addon
    self.TRP3_GetRPName = GetRPName
    self.TRP3_GetRPNameWithColor = GetRPNameWithColor
    self.TRP3_GetMyRPName = GetMyRPName
    self.TRP3_GetMyRPNameWithColor = GetMyRPNameWithColor

    self:Print("Total RP 3 integration loaded! RP names will appear in whisper windows.")
end
