--!strict
-- Global "first to discover" log. The first player in the world to make a recipe
-- is recorded forever, and shown to everyone ("Discovered by <name>!").
-- This is the social/viral hook: players brag about and share their finds.

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("MutationLab_Discoveries_v1")

local DiscoveryLog = {}

export type Entry = { userId: number, name: string, creature: string, at: number }

-- Returns (isFirstEver, entry). Safe to call on every fusion; only the first caller wins.
function DiscoveryLog.claim(recipeKey: string, userId: number, playerName: string, creatureName: string): (boolean, Entry?)
	local won = false
	local ok, result = pcall(function()
		return store:UpdateAsync(recipeKey, function(old)
			if old ~= nil then
				return nil -- cancel write, someone already discovered it
			end
			won = true
			return { userId = userId, name = playerName, creature = creatureName, at = os.time() }
		end)
	end)
	if not ok then
		warn("DiscoveryLog failed:", result)
		return false, nil
	end
	return won, result
end

function DiscoveryLog.lookup(recipeKey: string): Entry?
	local ok, result = pcall(function()
		return store:GetAsync(recipeKey)
	end)
	if ok then
		return result
	end
	return nil
end

return DiscoveryLog
