--!strict
-- Pure, deterministic fusion logic shared by server (authority) and client (preview).
--
-- KEY DESIGN RULE: the same two parents ALWAYS give the same result, for every
-- player on every server. That makes recipes discoverable and shareable
-- ("Slime + Void = Shiny Voidslime!") which is the whole viral hook.

local Config = require(script.Parent.Config)
local Creatures = require(script.Parent.Creatures)

export type Creature = {
	id: string,
	name: string,
	tier: number,
	traits: { string },
	parents: { string }?, -- ids of the two parents, nil for base species
}

local Fusion = {}

-- 32-bit FNV-1a. Deterministic across platforms.
local function hash(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

-- Small deterministic PRNG (xorshift) so we do not depend on Random's seeding.
local function makeRng(seed: number)
	local state = if seed == 0 then 1 else seed
	return function(): number -- returns [0, 1)
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296
	end
end

function Fusion.makeBase(speciesName: string): Creature
	return { id = speciesName, name = speciesName, tier = 1, traits = {} }
end

function Fusion.recipeKey(a: Creature, b: Creature): string
	if a.id <= b.id then
		return a.id .. "+" .. b.id
	end
	return b.id .. "+" .. a.id
end

local function blendName(a: string, b: string, rng: () -> number): string
	-- first half of one name + second half of the other, e.g. Slime+Void -> "Slioid"
	local first, second = a, b
	if rng() < 0.5 then
		first, second = b, a
	end
	local cutA = math.max(2, math.ceil(#first / 2))
	local cutB = math.max(2, math.floor(#second / 2))
	local name = string.sub(first, 1, cutA) .. string.lower(string.sub(second, -cutB))
	return name
end

-- Deterministic result of fusing a and b.
function Fusion.fuse(a: Creature, b: Creature): Creature
	local key = Fusion.recipeKey(a, b)
	local h = hash(key)
	local rng = makeRng(h)

	local tier = math.max(a.tier, b.tier)
	if rng() < Config.TierUpChance and tier < Config.MaxTier then
		tier += 1
	end

	local traitList = {}
	-- inherit up to one trait from parents, then maybe roll a new one
	local pool: { string } = {}
	for _, t in a.traits do
		table.insert(pool, t)
	end
	for _, t in b.traits do
		table.insert(pool, t)
	end
	if #pool > 0 and rng() < 0.5 then
		table.insert(traitList, pool[math.floor(rng() * #pool) + 1])
	end
	if rng() < 0.45 then
		local t = Creatures.Traits[math.floor(rng() * #Creatures.Traits) + 1].name
		if not table.find(traitList, t) then
			table.insert(traitList, t)
		end
	end

	local name = blendName(a.name, b.name, rng)
	return {
		id = string.format("%s-%08x", name, h),
		name = name,
		tier = tier,
		traits = traitList,
		parents = { a.id, b.id },
	}
end

local function traitBonus(traitName: string): number
	for _, t in Creatures.Traits do
		if t.name == traitName then
			return t.bonus
		end
	end
	return 0
end

function Fusion.incomePerSecond(c: Creature): number
	local mult = 1
	for _, t in c.traits do
		mult += traitBonus(t)
	end
	return Config.TierBaseIncome * 2 ^ (c.tier - 1) * mult
end

function Fusion.cost(a: Creature, b: Creature): number
	local tier = math.max(a.tier, b.tier)
	return math.floor(Config.FusionBaseCost * Config.FusionCostPerTier ^ (tier - 1))
end

function Fusion.seconds(a: Creature, b: Creature): number
	local tier = math.max(a.tier, b.tier)
	return math.floor(Config.FusionBaseSeconds * Config.FusionTimePerTier ^ (tier - 1))
end

function Fusion.tierName(tier: number): string
	return Creatures.TierNames[tier] or "Unknown"
end

return Fusion
