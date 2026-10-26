local addon = WhisperManager;

function addon:SetupTRP3Integration(TRP3_API)
    if not TRP3_API then
        self:DebugMessage("TRP3 API not provided to SetupTRP3Integration")
        return
    end

    self:DebugMessage("Setting up TRP3 integration with API access")

    -- NOTE: TRP3 temporarily removed TRP3_API.utils.str.unitInfoToID (taint
    -- containment, Midnight/12.x). Never depend on it. Build unit IDs locally
    -- with pure Lua so we can't taint (or break on) TRP3's secure path.
    -- Cache TRP3 API functions defensively: anything may be nil/stubbed while
    -- TRP3 works through taint issues.
    local function safeFn(fn)
        return (type(fn) == "function") and fn or nil
    end

    local getCurrentUser = AddOn_TotalRP3 and AddOn_TotalRP3.Player and safeFn(AddOn_TotalRP3.Player.GetCurrentUser)
    local getFullname = TRP3_API.chat and safeFn(TRP3_API.chat.getFullnameForUnitUsingChatMethod)
    local showCustomColors = TRP3_API.chat and safeFn(TRP3_API.chat.configShowNameCustomColors)
    local getCharacterInfo = TRP3_API.utils and safeFn(TRP3_API.utils.getCharacterInfoTab)
    local getConfig = TRP3_API.configuration and safeFn(TRP3_API.configuration.getValue)
    local icon = TRP3_API.utils and TRP3_API.utils.str and safeFn(TRP3_API.utils.str.icon)
    local isOOC = TRP3_API.chat and safeFn(TRP3_API.chat.disabledByOOC)
    local getPlayerCharacterData = TRP3_API.profile and safeFn(TRP3_API.profile.getPlayerCharacter)
    local getUnitIDCharacter = TRP3_API.register and safeFn(TRP3_API.register.getUnitIDCharacter)
    local getClassDisplayColor = safeFn(TRP3_API.GetClassDisplayColor)
    local createFromCharacterID = AddOn_TotalRP3 and AddOn_TotalRP3.Player and safeFn(AddOn_TotalRP3.Player.CreateFromCharacterID)

    self:DebugMessage("TRP3 globals.player_id:", TRP3_API.globals.player_id)
    self:DebugMessage("TRP3 globals.player:", TRP3_API.globals.player)

    --- Taint-free local replacement for removed TRP3_API.utils.str.unitInfoToID.
    -- Pure Lua + Blizzard name APIs only; never touches TRP3, so it cannot
    -- pick up or spread taint, and it keeps working while TRP3 has the helper
    -- pulled. Mirrors TRP3's RealmQualified behaviour: "Name-Realm", realm
    -- normalized (spaces/dots/dashes stripped), missing realm defaults to
    -- the player's normalized realm.
    local function BuildUnitID(name, realm)
        if not name or name == "" then return nil end
        name = name:match("^%s*(.-)%s*$")
        if not name or name == "" then return nil end
        -- Capitalize first letter like the game does (TRP3 does the same).
        -- Keep it cheap and nil-safe.
        if realm then
            realm = tostring(realm):match("^%s*(.-)%s*$")
            -- Strip spaces/dots/dashes to match TRP3_NameUtil.NormalizeRealmName
            realm = realm:gsub("[%s%.%-]", "")
            if realm == "" then realm = nil end
        end
        if not realm then
            -- Prefer TRP3's own pure helper when present (pcall-guarded), else Blizzard.
            local nameUtil = _G.TRP3_NameUtil
            if nameUtil and type(nameUtil.ComposeQualifiedName) == "function" then
                local ok, qualified = pcall(nameUtil.ComposeQualifiedName, name, nil)
                if ok and qualified and qualified ~= "" then return qualified end
            end
            if type(GetNormalizedRealmName) == "function" then
                local ok, r = pcall(GetNormalizedRealmName)
                if ok and r and r ~= "" then realm = r end
            end
            if not realm and type(GetRealmName) == "function" then
                local ok, r = pcall(GetRealmName)
                if ok and r and r ~= "" then realm = r:gsub("[%s%.%-]", "") end
            end
        end
        if realm and realm ~= "" then
            return name .. "-" .. realm
        end
        return name
    end

    local function SafeIsOOC()
        if not isOOC then return false end
        local ok, val = pcall(isOOC)
        if ok then return val and true or false end
        return false
    end

    --- Get RP name for a character (plain text, no color codes)
    local function GetRPName(charName)
        if not charName or charName == "" or SafeIsOOC() then return nil end
        if not getFullname then return nil end
        
        -- Parse name and realm from input
        local name, realm = charName:match("^([^%-]+)%-?(.*)$")
        if not name or name == "" then return nil end
        
        -- Local taint-free unit-ID construction (unitInfoToID removed by TRP3).
        local unitID = BuildUnitID(name, realm ~= "" and realm or nil)
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
        
        -- Local taint-free unit-ID construction (unitInfoToID removed by TRP3).
        local unitID = BuildUnitID(name, realm ~= "" and realm or nil)
        if not unitID or unitID == "" then return nil end

        addon:DebugMessage("[TRP3:GetRPNameWithColor] unitID:", unitID, "rpName:", rpName)

        -- During combat, skip Player-object creation entirely: TRP3's Player
        -- layer is the taint-sensitive part. Plain RP name is taint-free.
        if type(InCombatLockdown) == "function" then
            local ok, inCombat = pcall(InCombatLockdown)
            if ok and inCombat then
                addon:DebugMessage("[TRP3:GetRPNameWithColor] In combat, returning plain name")
                return rpName
            end
        end

        local color = nil

        -- Get custom color if enabled (with error protection)
        -- Every TRP3 call is nil-guarded + pcall'd: while TRP3 iterates on its
        -- taint fix, any of these may be temporarily stubbed out.
        if showCustomColors and createFromCharacterID then
            local okShow, show = pcall(showCustomColors)
            if okShow and show then
                addon:DebugMessage("[TRP3:GetRPNameWithColor] Custom colors enabled, creating player object")
                local success, player = pcall(createFromCharacterID, unitID)
                addon:DebugMessage("[TRP3:GetRPNameWithColor] CreateFromCharacterID success:", success, "player:", player ~= nil)
                if success and player and type(player.GetCustomColorForDisplay) == "function" then
                    local colorSuccess, customColor = pcall(player.GetCustomColorForDisplay, player)
                    addon:DebugMessage("[TRP3:GetRPNameWithColor] GetCustomColorForDisplay success:", colorSuccess, "customColor:", customColor)
                    if colorSuccess and customColor then
                        color = customColor
                        addon:DebugMessage("[TRP3:GetRPNameWithColor] Got custom color")
                    end
                end
            end
        end

        -- Fall back to class color if no custom color
        if not color then
            addon:DebugMessage("[TRP3:GetRPNameWithColor] No custom color, getting class from character data")
            -- Get class from TRP3 character data
            if getUnitIDCharacter then
                local okData, characterData = pcall(getUnitIDCharacter, unitID)
                if okData and characterData and characterData.class then
                    addon:DebugMessage("[TRP3:GetRPNameWithColor] Class from character data:", characterData.class)
                    if getClassDisplayColor then
                        local success, classColor = pcall(getClassDisplayColor, characterData.class)
                        addon:DebugMessage("[TRP3:GetRPNameWithColor] GetClassDisplayColor success:", success, "classColor:", classColor)
                        if success and classColor then color = classColor end
                    end
                else
                    addon:DebugMessage("[TRP3:GetRPNameWithColor] No character data or class found")
                end
            else
                addon:DebugMessage("[TRP3:GetRPNameWithColor] getUnitIDCharacter unavailable (TRP3 taint-safe stub?), skipping class color")
            end
        end

        if color then
            local okWrap, wrapped = pcall(color.WrapTextInColorCode, color, rpName)
            if okWrap and wrapped then
                rpName = wrapped
                addon:DebugMessage("[TRP3:GetRPNameWithColor] Wrapping name in color")
            else
                addon:DebugMessage("[TRP3:GetRPNameWithColor] Color wrap failed, returning plain name")
            end
        else
            addon:DebugMessage("[TRP3:GetRPNameWithColor] No color found, returning plain name")
        end

        if getConfig and getCharacterInfo and icon then
            local okCfg, showIcon = pcall(getConfig, "chat_show_icon")
            if okCfg and showIcon then
                local success, info = pcall(getCharacterInfo, unitID)
                if success and info and info.characteristics and info.characteristics.IC then
                    local okIcon, iconText = pcall(icon, info.characteristics.IC, 15)
                    if okIcon and iconText then
                        rpName = iconText .. " " .. rpName
                    end
                end
            end
        end

        addon:DebugMessage("[TRP3:GetRPNameWithColor] Returning:", rpName)
        return rpName
    end

    --- Get player's own RP name (plain text, no color codes)
    local function GetMyRPName()
        addon:DebugMessage("[TRP3:GetMyRPName] Starting - isOOC:", SafeIsOOC())
        if SafeIsOOC() then
            addon:DebugMessage("[TRP3:GetMyRPName] OOC mode is active, returning nil")
            return nil
        end
        if not getCurrentUser then
            addon:DebugMessage("[TRP3:GetMyRPName] TRP3 Player API unavailable (taint-safe stub?), returning nil")
            return nil
        end

        -- Use the current user Player object to get data
        local okUser, player = pcall(getCurrentUser)
        if not okUser or not player then
            addon:DebugMessage("[TRP3:GetMyRPName] No current user object")
            return nil
        end

        -- Try to get first name + last name from profile
        local okFirst, firstName = pcall(player.GetFirstName, player)
        local okLast, lastName = pcall(player.GetLastName, player)
        if not okFirst then firstName = nil end
        if not okLast then lastName = nil end
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
        if not getCurrentUser then return name end

        -- Use the current user Player object
        local okUser, player = pcall(getCurrentUser)
        if not okUser or not player then return name end

        local color = nil

        -- Get custom color if enabled (with error protection)
        if showCustomColors and type(player.GetCustomColorForDisplay) == "function" then
            local okShow, show = pcall(showCustomColors)
            if okShow and show then
                local success, customColor = pcall(player.GetCustomColorForDisplay, player)
                if success and customColor then color = customColor end
            end
        end

        -- Fall back to class color if no custom color
        if not color and getClassDisplayColor and type(UnitClassBase) == "function" then
            local okClass, class = pcall(UnitClassBase, "player")
            if okClass and class then
                local success, classColor = pcall(getClassDisplayColor, class)
                if success and classColor then color = classColor end
            end
        end

        if color and type(color.WrapTextInColorCode) == "function" then
            local okWrap, wrapped = pcall(color.WrapTextInColorCode, color, name)
            if okWrap and wrapped then name = wrapped end
        end

        -- Add icon if enabled
        if getConfig and getPlayerCharacterData and icon then
            local okCfg, showIcon = pcall(getConfig, "chat_show_icon")
            if okCfg and showIcon then
                local okChar, characterData = pcall(getPlayerCharacterData)
                if okChar and characterData and characterData.characteristics and characterData.characteristics.IC then
                    local okIcon, iconText = pcall(icon, characterData.characteristics.IC, 15)
                    if okIcon and iconText then
                        name = iconText .. " " .. name
                    end
                end
            end
        end

        return name
    end

    -- Register the functions globally on WhisperManager
    self.TRP3_GetRPName = GetRPName
    self.TRP3_GetRPNameWithColor = GetRPNameWithColor
    self.TRP3_GetMyRPName = GetMyRPName
    self.TRP3_GetMyRPNameWithColor = GetMyRPNameWithColor
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
