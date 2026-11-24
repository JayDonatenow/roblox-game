# Mutation Lab

A Roblox simulator where players fuse creatures to discover new ones, built with AI assistance.
See [docs/DESIGN.md](docs/DESIGN.md) for the design, monetization plan and setup steps.

Layout (Rojo project, `default.project.json`):
- `src/shared` - config, creature data, deterministic fusion logic
- `src/server` - data saving, fusion/economy, discovery log, purchases
- `src/client` - minimal UI

Quick start: open `MutationLab.rbxlx` in Roblox Studio and press Play (see the design doc for setup).
Regenerate it after editing `src/` with `python3 tools/build_rbxlx.py`.
