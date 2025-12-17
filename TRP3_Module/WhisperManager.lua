-- Copyright The Total RP 3 Authors
-- SPDX-License-Identifier: Apache-2.0
-- ============================================================================
-- TRP3 Module Loader for WhisperManager
-- ============================================================================
-- This file should be installed in the Total RP 3 addon directory at:
-- <WoW Install>\Interface\AddOns\totalRP3\Modules\ChatFrame\WhisperManager.lua
--
-- This is a minimal loader that registers WhisperManager as a TRP3 module
-- and calls back to WhisperManager to set up the integration.
-- The actual integration logic lives in WhisperManager's TRP3.lua module
-- where it has access to all player data.
-- ============================================================================

local TRP3_API = _G.TRP3_API;
if not TRP3_API then return end

local loc = TRP3_API.loc;

local function onStart()
	-- Check if WhisperManager addon is loaded
	if not WhisperManager then
		return TRP3_API.module.status.MISSING_DEPENDENCY, loc.MO_ADDON_NOT_INSTALLED:format("WhisperManager");
	end

	-- Call WhisperManager to set up the TRP3 integration
	-- This allows WhisperManager to access TRP3_API and register the functions
	if WhisperManager.SetupTRP3Integration then
		WhisperManager:SetupTRP3Integration(TRP3_API);
	else
		-- Fallback: try old initialization method
		if WhisperManager.InitializeTRP3Integration then
			WhisperManager:InitializeTRP3Integration();
		end
	end
end

-- Register WhisperManager as a Total RP 3 module
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
