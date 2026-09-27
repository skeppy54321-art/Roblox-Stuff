--!strict
-- Main (Script) — ServerScriptService.Main
-- Starts every server module and handles players joining/leaving.

local Players = game:GetService("Players")

local Modules = script.Parent:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net")) -- creates the Remotes folder first
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local WorldService = require(Modules:WaitForChild("WorldService"))
local PlotService = require(Modules:WaitForChild("PlotService"))
local IngredientService = require(Modules:WaitForChild("IngredientService"))
local BrewService = require(Modules:WaitForChild("BrewService"))
local CustomerService = require(Modules:WaitForChild("CustomerService"))
local UpgradeService = require(Modules:WaitForChild("UpgradeService"))
local SocialService = require(Modules:WaitForChild("SocialService"))

WorldService.Apply()
PlotService.Init()
local plots = PlotService.GetPlots()
IngredientService.Init(plots)
BrewService.Init(plots)
UpgradeService.Init(plots)
SocialService.Init(plots)

-- Keep the cauldron's suggested potion, the player list and the Market Stars board fresh.
PlayerData.OnChanged(function(player, data)
	BrewService.Refresh(player)
	SocialService.Update(player, data)
end)
CustomerService.OnChanged(function(plot)
	local owner = PlotService.GetOwner(plot)
	if owner then
		BrewService.Refresh(owner)
	end
end)

Net.GetState.OnServerInvoke = function(player: Player)
	if not Guard.Cooldown(player, "GetState", 0.2) then
		return nil
	end
	return PlayerData.Get(player)
end

local function onPlayerAdded(player: Player)
	local data = PlayerData.Load(player) -- yields; nil = left or kicked
	if not data then
		return
	end

	local plot = PlotService.Assign(player)
	if plot then
		UpgradeService.ApplyAll(plot, data.Upgrades)
		IngredientService.ApplyOwner(plot, data.Upgrades, true)
		CustomerService.StartPlot(plot, player)
	else
		Net.Notify(player, "The market is full right now. Try another server!", "bad")
	end

	SocialService.PlayerJoined(player, data, plot)

	player.CharacterAdded:Connect(function(character)
		PlotService.MoveToPlot(player, character)
	end)
	if player.Character then
		task.spawn(PlotService.MoveToPlot, player, player.Character)
	end
	PlayerData.Push(player)
end

local function onPlayerRemoving(player: Player)
	BrewService.Clear(player) -- a brew in progress finishes so the potion is saved
	local plot = PlotService.GetPlot(player)
	if plot then
		CustomerService.StopPlot(plot)
		BrewService.ResetCauldron(plot)
		IngredientService.ApplyOwner(plot, nil, true)
	end
	SocialService.PlayerLeft(player, plot)
	PlotService.Release(player) -- also resets the shop's visuals
	PlayerData.Release(player) -- final save
	Guard.Clear(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[Brew a Potion] Server started")
