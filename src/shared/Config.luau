--!strict
-- Central tuning values. Change numbers here, not in the services.

local Config = {}

Config.StartingCoins = 100
Config.StartingSlots = 4
Config.MaxSlots = 24
Config.SlotBaseCost = 250 -- cost of slot N = SlotBaseCost * SlotCostGrowth^(N - StartingSlots - 1)
Config.SlotCostGrowth = 1.9

Config.MaxTier = 8
Config.FusionBaseCost = 50 -- coins; multiplied by FusionCostPerTier^tier of the higher parent
Config.FusionCostPerTier = 2.2
Config.FusionBaseSeconds = 10 -- timer; multiplied by FusionTimePerTier^tier
Config.FusionTimePerTier = 1.8
Config.TierUpChance = 0.35 -- chance a fusion produces a creature one tier above its best parent

-- Income per second for a creature = TierBaseIncome * 2^(tier-1) * (1 + sum of trait bonuses)
Config.TierBaseIncome = 1

Config.SkipTimerRobuxPerMinute = 5 -- only used to scale the dev-product tiers below

-- Fill these with real IDs after creating products in the Creator Dashboard.
-- Game passes: https://create.roblox.com -> your experience -> Monetization
Config.GamePasses = {
	AutoFuse = 0, -- 2x speed + auto re-fuse a favorite recipe
	DoubleIncome = 0, -- permanent 2x coins
	ExtraSlots = 0, -- +6 lab slots
}

Config.DevProducts = {
	SkipTimer = 0, -- instantly finish one fusion
	StarterPack = 0, -- one time: coins + exclusive "Prototype" creature
	CoinBoost = 0, -- 15 min of 2x coins
}

Config.StarterPackCoins = 1000
Config.StarterPackCreature = "Prototype Blob"

return Config
