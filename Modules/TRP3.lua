local addon = WhisperManager;

function addon:SetupTRP3Integration(TRP3_API)
    if not TRP3_API then
        self:DebugMessage("TRP3 API not provided to SetupTRP3Integration")
        return
    end

    self:DebugMessage("Setting up TRP3 integration with API access")

    -- Cache TRP3 API functions for performance
    local getCurrentUser = AddOn_TotalRP3.Player.GetCurrentUser
    local getFullname = TRP3_API.chat.getFullnameForUnitUsingChatMethod
    local showCustomColors = TRP3_API.chat.configShowNameCustomColors
    local getCharacterInfo = TRP3_API.utils.getCharacterInfoTab
    local getConfig = TRP3_API.configuration.getValue
    local icon = TRP3_API.utils.str.icon
    local isOOC = TRP3_API.chat.disabledByOOC
    local unitInfoToID = TRP3_API.utils.str.unitInfoToID
    local getPlayerCharacterData = TRP3_API.profile.getPlayerCharacter

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

        addon:DebugMessage("[TRP3:GetRPNameWithColor] unitID:", unitID, "rpName:", rpName)

        local color = nil
        
        -- Get custom color if enabled (with error protection)
        if showCustomColors() then
            addon:DebugMessage("[TRP3:GetRPNameWithColor] Custom colors enabled, creating player object")
            local success, player = pcall(AddOn_TotalRP3.Player.CreateFromCharacterID, unitID)
            addon:DebugMessage("[TRP3:GetRPNameWithColor] CreateFromCharacterID success:", success, "player:", player ~= nil)
            if success and player then
                local colorSuccess, customColor = pcall(player.GetCustomColorForDisplay, player)
                addon:DebugMessage("[TRP3:GetRPNameWithColor] GetCustomColorForDisplay success:", colorSuccess, "customColor:", customColor)
                if colorSuccess and customColor then 
                    color = customColor 
                    addon:DebugMessage("[TRP3:GetRPNameWithColor] Got custom color")
                end
            end
        end
        
        -- Fall back to class color if no custom color
        if not color then
            addon:DebugMessage("[TRP3:GetRPNameWithColor] No custom color, getting class from character data")
            -- Get class from TRP3 character data
            local characterData = TRP3_API.register.getUnitIDCharacter(unitID)
            if characterData and characterData.class then
                addon:DebugMessage("[TRP3:GetRPNameWithColor] Class from character data:", characterData.class)
                local success, classColor = pcall(TRP3_API.GetClassDisplayColor, characterData.class)
                addon:DebugMessage("[TRP3:GetRPNameWithColor] GetClassDisplayColor success:", success, "classColor:", classColor)
                if success and classColor then color = classColor end
            else
                addon:DebugMessage("[TRP3:GetRPNameWithColor] No character data or class found")
            end
        end

        if color then 
            addon:DebugMessage("[TRP3:GetRPNameWithColor] Wrapping name in color")
            rpName = color:WrapTextInColorCode(rpName) 
        else
            addon:DebugMessage("[TRP3:GetRPNameWithColor] No color found, returning plain name")
        end

        if getConfig("chat_show_icon") then
            local success, info = pcall(getCharacterInfo, unitID)
            if success and info and info.characteristics and info.characteristics.IC then
                rpName = icon(info.characteristics.IC, 15) .. " " .. rpName
            end
        end

        addon:DebugMessage("[TRP3:GetRPNameWithColor] Returning:", rpName)
        return rpName
    end

    --- Get player's own RP name (plain text, no color codes)
    local function GetMyRPName()
        addon:DebugMessage("[TRP3:GetMyRPName] Starting - isOOC:", isOOC())
        if isOOC() then 
            addon:DebugMessage("[TRP3:GetMyRPName] OOC mode is active, returning nil")
            return nil 
        end

        -- Use the current user Player object to get data
        local player = getCurrentUser()
        if not player then
            addon:DebugMessage("[TRP3:GetMyRPName] No current user object")
            return nil
        end

        -- Try to get first name + last name from profile
        local firstName = player:GetFirstName()
        local lastName = player:GetLastName()
        addon:DebugMessage("[TRP3:GetMyRPName] FirstName:", firstName, "LastName:", lastName)
        
        local name = nil
        if firstName and firstName ~= "" then
            name = firstName
            if lastName and lastName ~= "" then
                name = name .. " " .. lastName
            end
            addon:DebugMessage("[TRP3:GetMyRPName] Returning profile name:", name)
            return name
        end
        
        addon:DebugMessage("[TRP3:GetMyRPName] No valid RP name found, returning nil")
        return nil
    end

    --- Get player's own RP name with color coding and icon
    local function GetMyRPNameWithColor()
        local name = GetMyRPName()
        if not name then return nil end

        -- Use the current user Player object
        local player = getCurrentUser()
        if not player then return name end

        local color = nil
        
        -- Get custom color if enabled (with error protection)
        if showCustomColors() then
            local success, customColor = pcall(player.GetCustomColorForDisplay, player)
            if success and customColor then color = customColor end
        end
        
        -- Fall back to class color if no custom color
        if not color then
            local success, classColor = pcall(TRP3_API.GetClassDisplayColor, UnitClassBase("player"))
            if success and classColor then color = classColor end
        end

        if color then name = color:WrapTextInColorCode(name) end

        -- Add icon if enabled
        if getConfig("chat_show_icon") then
            local characterData = getPlayerCharacterData()
            if characterData and characterData.characteristics and characterData.characteristics.IC then
                name = icon(characterData.characteristics.IC, 15) .. " " .. name
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
