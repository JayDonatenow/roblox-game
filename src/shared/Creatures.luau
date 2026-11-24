--!strict
-- Base (tier 1) species. Everything else in the game is discovered by fusing these.

export type Species = {
	name: string,
	emoji: string,
}

local Creatures = {}

Creatures.BaseSpecies = {
	{ name = "Slime", emoji = "🟢" },
	{ name = "Ember", emoji = "🔥" },
	{ name = "Frost", emoji = "❄️" },
	{ name = "Spark", emoji = "⚡" },
	{ name = "Moss", emoji = "🌿" },
	{ name = "Void", emoji = "🌑" },
	{ name = "Crystal", emoji = "💎" },
	{ name = "Gloom", emoji = "👻" },
} :: { Species }

-- Traits are random rolls on a fusion result. bonus is added to the income multiplier.
Creatures.Traits = {
	{ name = "Glowing", bonus = 0.25 },
	{ name = "Giant", bonus = 0.40 },
	{ name = "Tiny", bonus = 0.10 },
	{ name = "Shiny", bonus = 0.60 },
	{ name = "Spiky", bonus = 0.20 },
	{ name = "Rainbow", bonus = 1.00 },
}

Creatures.TierNames = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Cosmic",
	"Impossible",
}

return Creatures
