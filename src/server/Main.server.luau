--!strict
-- Server entry point: remotes, economy loop, fusion, monetization.
-- The server is the ONLY authority on coins, creatures and timers. Clients just ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local PlayerData = require(script.Parent.PlayerData)
local DiscoveryLog = require(script.Parent.DiscoveryLog)

-- Remotes ---------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeEvent(name: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
	return e
end

local StateChanged = makeEvent("StateChanged") -- server -> client: full state snapshot
local Announce = makeEvent("Announce") -- server -> all clients: discovery messages
local FusionResult = makeEvent("FusionResult") -- server -> client: reveal animation data
local Action = Instance.new("RemoteFunction") -- client -> server: all requests
Action.Name = "Action"
Action.Parent = remotes

-- Helpers ---------------------------------------------------------------
local function incomeMultiplier(profile: PlayerData.Profile): number
	local m = 1
	if profile.passes.DoubleIncome then
		m *= 2
	end
	if os.time() < profile.boostUntil then
		m *= 2
	end
	return m
end

local function totalIncome(profile: PlayerData.Profile): number
	local sum = 0
	for _, id in profile.lab do
		local c = profile.known[id]
		if c then
			sum += Fusion.incomePerSecond(c)
		end
	end
	return sum * incomeMultiplier(profile)
end

local function maxSlots(profile: PlayerData.Profile): number
	local extra = if profile.passes.ExtraSlots then 6 else 0
	return math.min(profile.slots + extra, Config.MaxSlots + extra)
end

local function snapshot(profile: PlayerData.Profile)
	return {
		coins = profile.coins,
		slots = maxSlots(profile),
		known = profile.known,
		inventory = profile.inventory,
		lab = profile.lab,
		fusion = profile.fusion,
		income = totalIncome(profile),
		boostUntil = profile.boostUntil,
		serverTime = os.time(),
		slotCost = math.floor(Config.SlotBaseCost * Config.SlotCostGrowth ^ (profile.slots - Config.StartingSlots)),
		discoveredCount = (function()
			local n = 0
			for _ in profile.discovered do
				n += 1
			end
			return n
		end)(),
	}
end

local function push(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		StateChanged:FireClient(player, snapshot(profile))
	end
end

local function addToInventory(profile: PlayerData.Profile, c: Fusion.Creature, n: number)
	profile.known[c.id] = c
	profile.inventory[c.id] = (profile.inventory[c.id] or 0) + n
end

local function takeFromInventory(profile: PlayerData.Profile, id: string, n: number): boolean
	local have = profile.inventory[id] or 0
	if have < n then
		return false
	end
	profile.inventory[id] = if have == n then nil else have - n
	return true
end

-- Actions ---------------------------------------------------------------
local handlers: { [string]: (Player, PlayerData.Profile, any) -> (boolean, string?) } = {}

handlers.BuyBase = function(_, profile, args)
	local name = args and args.name
	local price = 25
	for _, s in Creatures.BaseSpecies do
		if s.name == name then
			if profile.coins < price then
				return false, "Not enough coins"
			end
			profile.coins -= price
			addToInventory(profile, Fusion.makeBase(s.name), 1)
			return true
		end
	end
	return false, "Unknown species"
end

handlers.Place = function(_, profile, args)
	local id = args and args.id
	if typeof(id) ~= "string" then
		return false, "Bad id"
	end
	if #profile.lab >= maxSlots(profile) then
		return false, "Lab is full"
	end
	if not takeFromInventory(profile, id, 1) then
		return false, "You don't have that"
	end
	table.insert(profile.lab, id)
	return true
end

handlers.Unplace = function(_, profile, args)
	local id = args and args.id
	local idx = if typeof(id) == "string" then table.find(profile.lab, id) else nil
	if not idx then
		return false, "Not in lab"
	end
	table.remove(profile.lab, idx)
	profile.inventory[id] = (profile.inventory[id] or 0) + 1
	return true
end

handlers.BuySlot = function(_, profile)
	if profile.slots >= Config.MaxSlots then
		return false, "Max slots"
	end
	local cost = math.floor(Config.SlotBaseCost * Config.SlotCostGrowth ^ (profile.slots - Config.StartingSlots))
	if profile.coins < cost then
		return false, "Not enough coins"
	end
	profile.coins -= cost
	profile.slots += 1
	return true
end

handlers.StartFusion = function(_, profile, args)
	if profile.fusion then
		return false, "Fusion already running"
	end
	local aId, bId = args and args.a, args and args.b
	if typeof(aId) ~= "string" or typeof(bId) ~= "string" then
		return false, "Bad ids"
	end
	local a, b = profile.known[aId], profile.known[bId]
	if not a or not b then
		return false, "Unknown creature"
	end
	-- need two distinct copies (or 2 of the same id)
	local needed = if aId == bId then 2 else 1
	if (profile.inventory[aId] or 0) < needed or (profile.inventory[bId] or 0) < needed then
		return false, "You need both creatures in your inventory"
	end
	local cost = Fusion.cost(a, b)
	if profile.coins < cost then
		return false, "Need " .. cost .. " coins"
	end
	profile.coins -= cost
	takeFromInventory(profile, aId, 1)
	takeFromInventory(profile, bId, 1)
	local result = Fusion.fuse(a, b)
	profile.fusion = {
		a = aId,
		b = bId,
		resultId = result.id,
		finishAt = os.time() + Fusion.seconds(a, b),
	}
	profile.known[result.id] = result -- stored now, but not revealed until claimed
	return true
end

local function finishFusion(player: Player, profile: PlayerData.Profile)
	local f = profile.fusion
	if not f then
		return false, "Nothing to claim"
	end
	local result = profile.known[f.resultId]
	local a, b = profile.known[f.a], profile.known[f.b]
	profile.fusion = nil
	addToInventory(profile, result, 1)

	local recipeKey = Fusion.recipeKey(a, b)
	local newForPlayer = not profile.discovered[recipeKey]
	profile.discovered[recipeKey] = true

	local first = false
	if newForPlayer then
		first = DiscoveryLog.claim(recipeKey, player.UserId, player.Name, result.name)
	end
	FusionResult:FireClient(player, {
		creature = result,
		parents = { a.name, b.name },
		isNewRecipe = newForPlayer,
		isWorldFirst = first,
		income = Fusion.incomePerSecond(result),
	})
	if first then
		Announce:FireAllClients(
			string.format("🧪 %s just discovered %s (%s)!", player.Name, result.name, Fusion.tierName(result.tier))
		)
	end
	return true
end

handlers.ClaimFusion = function(player, profile)
	local f = profile.fusion
	if not f then
		return false, "Nothing to claim"
	end
	if os.time() < f.finishAt then
		return false, "Still fusing"
	end
	return finishFusion(player, profile)
end

Action.OnServerInvoke = function(player: Player, name: any, args: any)
	local profile = PlayerData.get(player)
	local handler = if typeof(name) == "string" then handlers[name] else nil
	if not profile or not handler then
		return { ok = false, err = "Bad request" }
	end
	local ok, err = handler(player, profile, args)
	push(player)
	return { ok = ok, err = err }
end

-- Income loop -----------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for player, profile in PlayerData.all() do
			profile.coins += totalIncome(profile)
			push(player)
		end
	end
end)

-- Monetization ----------------------------------------------------------
local function refreshPasses(player: Player, profile: PlayerData.Profile)
	for name, id in Config.GamePasses do
		if id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok then
				profile.passes[name] = owns
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		local profile = PlayerData.get(player)
		if profile then
			refreshPasses(player, profile)
			push(player)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = PlayerData.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(info.PurchaseId)
	if profile.receipts[receiptId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end

	local id = info.ProductId
	if id == Config.DevProducts.SkipTimer and id ~= 0 then
		if profile.fusion then
			profile.fusion.finishAt = os.time()
		end
	elseif id == Config.DevProducts.StarterPack and id ~= 0 then
		if profile.starterPackBought then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		profile.starterPackBought = true
		profile.coins += Config.StarterPackCoins
		local c = Fusion.makeBase(Config.StarterPackCreature)
		c.tier = 3
		c.traits = { "Rainbow" }
		addToInventory(profile, c, 1)
	elseif id == Config.DevProducts.CoinBoost and id ~= 0 then
		profile.boostUntil = math.max(profile.boostUntil, os.time()) + 15 * 60
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.receipts[receiptId] = true
	PlayerData.save(player) -- save immediately after a purchase
	push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Player lifecycle ------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local profile = PlayerData.load(player)
	refreshPasses(player, profile)
	push(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		local profile = PlayerData.load(player)
		refreshPasses(player, profile)
		push(player)
	end)
end
