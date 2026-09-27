-- Main (Script) — ServerScriptService.Main
-- Starts every server module and handles players joining/leaving.

local Players = game:GetService("Players")

local Modules = script.Parent:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net")) -- creates the Remotes folder first
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local PlotService = require(Modules:WaitForChild("PlotService"))
local IngredientService = require(Modules:WaitForChild("IngredientService"))
local BrewService = require(Modules:WaitForChild("BrewService"))
local CustomerService = require(Modules:WaitForChild("CustomerService"))
local UpgradeService = require(Modules:WaitForChild("UpgradeService"))

PlotService.Init()
local plots = PlotService.GetPlots()
IngredientService.Init(plots)
BrewService.Init(plots)
UpgradeService.Init()

Net.GetState.OnServerInvoke = function(player: Player)
	if not Guard.Cooldown(player, "GetState", 0.2) then
		return nil
	end
	return PlayerData.Get(player)
end

local function onPlayerAdded(player: Player)
	PlayerData.Create(player)
	local plot = PlotService.Assign(player)
	if plot then
		UpgradeService.ApplyVisuals(plot, 0)
		CustomerService.StartPlot(plot)
	else
		Net.Notify(player, "The market is full right now. Try another server!")
	end

	player.CharacterAdded:Connect(function(character)
		PlotService.MoveToPlot(player, character)
	end)
	if player.Character then
		task.spawn(PlotService.MoveToPlot, player, player.Character)
	end
	PlayerData.Push(player)
end

local function onPlayerRemoving(player: Player)
	BrewService.Clear(player)
	local plot = PlotService.GetPlot(player)
	if plot then
		CustomerService.StopPlot(plot)
		IngredientService.ResetPlot(plot)
		UpgradeService.ApplyVisuals(plot, 0)
	end
	PlotService.Release(player)
	PlayerData.Remove(player) -- PROTOTYPE: session-only, nothing is saved
	Guard.Clear(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[Brew a Potion] Server started (PROTOTYPE, session-only progress)")
