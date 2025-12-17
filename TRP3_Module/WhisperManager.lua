-- Copyright The Total RP 3 Authors
-- SPDX-License-Identifier: Apache-2.0
-- This file is intended to be installed in Total RP3 addon directory as shown below. This file is seperate to addon itself.
-- C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\totalRP3\Modules\ChatFrame\WhisperManager.lua

local TRP3_API = _G.TRP3_API;
if not TRP3_API then return end

local loc = TRP3_API.loc;

local function onStart()
	if not WhisperManager then
		return TRP3_API.module.status.MISSING_DEPENDENCY, loc.MO_ADDON_NOT_INSTALLED:format("WhisperManager");
	end

	local playerID = TRP3_API.globals.player_id;
	local getFullname = TRP3_API.chat.getFullnameForUnitUsingChatMethod;
	local showCustomColors = TRP3_API.chat.configShowNameCustomColors;
	local getData = TRP3_API.profile.getData;
	local getConfig = TRP3_API.configuration.getValue;
	local icon = TRP3_API.utils.str.icon;
	local playerName = TRP3_API.globals.player;
	local isOOC = TRP3_API.chat.disabledByOOC;

	local function GetRPName(charName)
		if not charName or charName == "" or isOOC() then return nil end
		
		local fullName = charName;
		if not fullName:find("-") then
			fullName = charName .. "-" .. GetRealmName():gsub("%s+", "");
		end

		local rpName = getFullname(fullName);
		if rpName and rpName ~= "" then
			local shortName = charName:match("^([^%-]+)") or charName;
			if rpName ~= shortName then return rpName end
		end
		return nil;
	end

	local function GetRPNameWithColor(charName)
		local rpName = GetRPName(charName);
		if not rpName then return nil end

		local fullName = charName;
		if not fullName:find("-") then
			fullName = charName .. "-" .. GetRealmName():gsub("%s+", "");
		end

		local color = TRP3_API.GetClassDisplayColor(UnitClassBase(fullName));
		
		if showCustomColors() then
			local profile = TRP3_API.register.getUnitProfile(fullName);
			if profile and profile.characteristics and profile.characteristics.CH then
				local customColor = TRP3_API.CreateColorFromHexString(profile.characteristics.CH);
				if customColor then color = customColor end
			end
		end

		if color then rpName = color:WrapTextInColorCode(rpName) end

		if getConfig("chat_show_icon") then
			local profile = TRP3_API.register.getUnitProfile(fullName);
			if profile and profile.characteristics and profile.characteristics.IC then
				rpName = icon(profile.characteristics.IC, 15) .. " " .. rpName;
			end
		end

		return rpName;
	end

	local function GetMyRPName()
		if isOOC() then return nil end

		local info = getData("player");
		local name = nil;
		local hasProfile = false;
		
		if info and info.characteristics then
			local firstName = info.characteristics.FN;
			local lastName = info.characteristics.LN;
			
			if firstName and firstName ~= "" then
				hasProfile = true;
				name = firstName;
				if lastName and lastName ~= "" then
					name = name .. " " .. lastName;
				end
			end
		end
		
		if hasProfile and name and name ~= "" then return name end
		
		if not name or name == "" then
			name = getFullname(playerID);
			if name and name ~= "" and name ~= playerName then return name end
		end
		
		return nil;
	end

	local function GetMyRPNameWithColor()
		local name = GetMyRPName();
		if not name then return nil end

		local color = TRP3_API.GetClassDisplayColor(UnitClassBase("player"));

		if showCustomColors() then
			local player = AddOn_TotalRP3.Player.GetCurrentUser();
			local customColor = player:GetCustomColorForDisplay();
			if customColor then color = customColor end
		end

		if color then name = color:WrapTextInColorCode(name) end

		if getConfig("chat_show_icon") then
			local info = getData("player");
			if info and info.characteristics and info.characteristics.IC then
				name = icon(info.characteristics.IC, 15) .. " " .. name;
			end
		end

		return name;
	end

	WhisperManager.TRP3_GetRPName = GetRPName;
	WhisperManager.TRP3_GetRPNameWithColor = GetRPNameWithColor;
	WhisperManager.TRP3_GetMyRPName = GetMyRPName;
	WhisperManager.TRP3_GetMyRPNameWithColor = GetMyRPNameWithColor;

	WhisperManager:Print("Total RP 3 integration loaded! RP names will appear in whisper windows.");
end-- Register a Total RP 3 module that can be disabled in the settings
TRP3_API.module.registerModule({
	["name"] = "WhisperManager",
	["description"] = loc.MO_CHAT_CUSTOMIZATIONS_DESCRIPTION:format("WhisperManager"),
	["version"] = 1.000,
	["id"] = "trp3_whispermanager",
	["onStart"] = onStart,
	["minVersion"] = 25,
	["requiredDeps"] = {
		{ "trp3_chatframes", 1.100 },
	}
});
