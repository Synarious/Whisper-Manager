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
