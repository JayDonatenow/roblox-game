--!strict
-- Loads/saves each player's profile. v1 uses plain DataStore (no session locking);
-- swap in ProfileService/ProfileStore before launch if you expect lots of server hopping.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Fusion = require(game.ReplicatedStorage.Shared.Fusion)
local Creatures = require(game.ReplicatedStorage.Shared.Creatures)

export type Profile = {
	coins: number,
	slots: number,
	known: { [string]: Fusion.Creature }, -- every creature the player has ever owned/discovered
	inventory: { [string]: number }, -- id -> count (not placed in lab)
	lab: { string }, -- ids placed in lab slots, earning income
	discovered: { [string]: boolean }, -- recipe keys the player has discovered
	fusion: { a: string, b: string, resultId: string, finishAt: number }?,
	boostUntil: number, -- os.time() when CoinBoost ends
	passes: { [string]: boolean }, -- cached game pass ownership
	receipts: { [string]: boolean },
	starterPackBought: boolean,
}

local store = DataStoreService:GetDataStore("MutationLab_v1")
local profiles: { [Player]: Profile } = {}
local failedLoad: { [Player]: boolean } = {}

local PlayerData = {}

local function newProfile(): Profile
	local known = {}
	local inventory = {}
	for _, name in { "Slime", "Ember" } do
		known[name] = Fusion.makeBase(name)
		inventory[name] = 2
	end
	return {
		coins = Config.StartingCoins,
		slots = Config.StartingSlots,
		known = known,
		inventory = inventory,
		lab = {},
		discovered = {},
		fusion = nil,
		boostUntil = 0,
		passes = {},
		receipts = {},
		starterPackBought = false,
	}
end

local function key(player: Player): string
	return "Player_" .. player.UserId
end

function PlayerData.load(player: Player): Profile
	local ok, data = pcall(function()
		return store:GetAsync(key(player))
	end)
	local profile = newProfile()
	if ok and typeof(data) == "table" then
		-- merge saved values over defaults so new fields added later don't break old saves
		for k, v in data do
			(profile :: any)[k] = v
		end
	elseif not ok then
		warn("DataStore load failed for", player.Name, data)
		-- Never save over a real profile we failed to load.
		failedLoad[player] = true
		if not RunService:IsStudio() then
			player:Kick("Could not load your data. Please rejoin in a minute.")
		end
	end
	profiles[player] = profile
	return profile
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or failedLoad[player] then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), profile)
	end)
	if not ok then
		warn("DataStore save failed for", player.Name, err)
	end
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.all(): { [Player]: Profile }
	return profiles
end

-- autosave every 2 minutes
task.spawn(function()
	while true do
		task.wait(120)
		for player in profiles do
			PlayerData.save(player)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)

return PlayerData
