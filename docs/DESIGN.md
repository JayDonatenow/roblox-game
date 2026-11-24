# Mutation Lab — Design

**One-line pitch:** Fuse creatures to discover new ones. Every recipe is the same for every player,
and the first person in the world to find a recipe gets credit forever.

## Why it can stand out
Most top simulators are "buy egg, hatch pet, repeat". Mutation Lab is a *discovery* game:
- Recipes are deterministic (same parents = same child, everywhere). Players share them on
  TikTok/YouTube/Discord ("Slime + Void = Rainbow Slioid!").
- Global **first-discoverer log**: bragging rights and a reason to come back each day.
- Combinatorial depth: 8 base species -> thousands of unique results, so there is always something new.

## Core loop (first 60 seconds)
1. Start with 4 creatures and 100 coins.
2. Fuse two (costs coins, takes a timer) -> reveal a new creature.
3. Place creatures in lab slots -> they earn coins per second.
4. Spend coins on better fusions and more slots. Repeat.

## Retention
- Timers (come back to claim). Event weekends with limited base species and boosted trait odds.
- Discovery log + collection book (planned).
- Daily rewards, friends' labs / gifting (planned).

## Monetization (cosmetic/convenience first, no hard pay-to-win)
| Item | Type | Notes |
|---|---|---|
| Starter Pack | Dev product (once) | coins + exclusive tier-3 Rainbow creature, shown after first fusion |
| Skip Timer | Dev product | instantly finish current fusion (cheap, impulse buy) |
| Coin Boost | Dev product | 15 min 2x coins |
| 2x Income | Game pass | permanent |
| Extra Slots | Game pass | +6 lab slots |
| Auto Fuse | Game pass | planned |
| Lab cosmetics | Dev products | planned: lab skins, creature auras |

Roblox rules: show odds if any paid item is random; we have none yet. Audience skews young, so avoid
predatory/loot-box mechanics.

## Not in v1 (planned order)
1. Real art/3D creatures and a designed UI
2. Collection book + recipe hints
3. Trading, friends' labs
4. Events, leaderboards, daily rewards
5. Offline earnings, auto-fuse pass

## Setup (no Rojo needed)
1. Download `MutationLab.rbxlx` from the repo and open it in Roblox Studio (File > Open from File).
2. Game Settings > Security > turn on "Enable Studio Access to API Services" (needed for saving).
3. Press Play.
4. Create game passes/dev products in the Creator Dashboard and put the IDs in `ReplicatedStorage > Shared > Config`.

Developers who prefer Rojo can use `default.project.json`. After editing anything in `src/`,
regenerate the place file with `python3 tools/build_rbxlx.py`.

## Status
v1 code is **untested**: written without Roblox Studio or a Luau runtime. Expect to fix small bugs
on first run. Next step is running it in Studio.
