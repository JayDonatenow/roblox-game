--!strict
-- Minimal programmatic UI (no Studio assets needed) so the prototype runs immediately.
-- Replace with a designed UI later; all logic lives on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Fusion)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
local Announce = remotes:WaitForChild("Announce") :: RemoteEvent
local FusionResult = remotes:WaitForChild("FusionResult") :: RemoteEvent
local Action = remotes:WaitForChild("Action") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "MutationLabUI"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Size, l.Position, l.Text = size, pos, text
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size, b.Position, b.Text = size, pos, text
	b.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Parent = parent
	Instance.new("UICorner").Parent = b
	b.Activated:Connect(onClick)
	return b
end

local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(0.5, 0.6)
panel.Position = UDim2.fromScale(0.25, 0.2)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local header = label(panel, "Coins: 0", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.02, 0.01))
header.TextXAlignment = Enum.TextXAlignment.Left
local incomeLabel = label(panel, "+0/s", UDim2.fromScale(0.3, 0.08), UDim2.fromScale(0.68, 0.01))
local fusionLabel = label(panel, "Pick two creatures to fuse", UDim2.fromScale(0.96, 0.07), UDim2.fromScale(0.02, 0.1))
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromScale(0.96, 0.55)
list.Position = UDim2.fromScale(0.02, 0.18)
list.BackgroundTransparency = 1
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = list

local banner = label(gui, "", UDim2.fromScale(0.6, 0.06), UDim2.fromScale(0.2, 0.02))
banner.TextColor3 = Color3.fromRGB(255, 220, 90)

local state: any = nil
local picks: { string } = {}
local clockOffset = 0

local function act(name: string, args: any?)
	local res = Action:InvokeServer(name, args)
	if not res.ok and res.err then
		banner.Text = res.err
		task.delay(3, function()
			if banner.Text == res.err then
				banner.Text = ""
			end
		end)
	end
end

local function describe(c: any): string
	local traits = if #c.traits > 0 then " [" .. table.concat(c.traits, ", ") .. "]" else ""
	return string.format("%s  T%d %s%s  (+%.1f/s)", c.name, c.tier, Fusion.tierName(c.tier), traits, Fusion.incomePerSecond(c))
end

local function render()
	if not state then
		return
	end
	header.Text = string.format("Coins: %d", math.floor(state.coins))
	incomeLabel.Text = string.format("+%.1f/s", state.income)

	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	if state.fusion then
		local left = state.fusion.finishAt - (os.time() + clockOffset)
		if left > 0 then
			fusionLabel.Text = string.format("Fusing... %ds left", left)
		else
			fusionLabel.Text = "Fusion ready!"
			button(list, "CLAIM RESULT", UDim2.new(1, 0, 0, 40), UDim2.new(), function()
				act("ClaimFusion")
			end).BackgroundColor3 = Color3.fromRGB(60, 190, 90)
		end
	else
		fusionLabel.Text = if #picks == 0 then "Pick two creatures to fuse" else "Picked: " .. table.concat(picks, " + ")
	end

	for id, count in state.inventory do
		local c = state.known[id]
		if c then
			button(list, string.format("%s  x%d", describe(c), count), UDim2.new(1, 0, 0, 36), UDim2.new(), function()
				table.insert(picks, id)
				if #picks == 2 then
					local a, b = picks[1], picks[2]
					picks = {}
					act("StartFusion", { a = a, b = b })
				else
					render()
				end
			end)
		end
	end

	for _, s in Creatures.BaseSpecies do
		button(list, string.format("Buy %s %s (25)", s.emoji, s.name), UDim2.new(1, 0, 0, 30), UDim2.new(), function()
			act("BuyBase", { name = s.name })
		end).BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end
end

StateChanged.OnClientEvent:Connect(function(newState)
	state = newState
	clockOffset = newState.serverTime - os.time()
	render()
end)

Announce.OnClientEvent:Connect(function(msg: string)
	banner.Text = msg
	task.delay(6, function()
		if banner.Text == msg then
			banner.Text = ""
		end
	end)
end)

FusionResult.OnClientEvent:Connect(function(r)
	local prefix = if r.isWorldFirst then "🌍 WORLD FIRST! " elseif r.isNewRecipe then "✨ New recipe! " else ""
	banner.Text = prefix .. r.parents[1] .. " + " .. r.parents[2] .. " = " .. r.creature.name
end)
