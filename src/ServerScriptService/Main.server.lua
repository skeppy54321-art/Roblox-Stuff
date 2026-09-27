--!strict
-- Main (Script) — ServerScriptService.Main
-- Starts every server module and handles players joining/leaving.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
local GiftService = require(Modules:WaitForChild("GiftService"))

WorldService.Apply()
PlotService.Init()
local plots = PlotService.GetPlots()
IngredientService.Init(plots)
BrewService.Init(plots)
UpgradeService.Init(plots)
SocialService.Init(plots)
GiftService.Init()

-- Keep the cauldron's suggested potion, the counter display, the player list and the
-- Market Stars board fresh.
PlayerData.OnChanged(function(player, data)
	BrewService.Refresh(player)
	local plot = PlotService.GetPlot(player)
	if plot then
		PlotService.ShowStock(plot, data.Potions)
	end
	SocialService.Update(player, data)
end)
CustomerService.OnChanged(function(plot)
	local owner = PlotService.GetOwner(plot)
	if owner then
		BrewService.Refresh(owner)
	end
end)

-- Testing aid: in Studio play tests only, the client's "+10K" button gives coins so the
-- late game (familiars, rebirth) can be tried quickly. Live servers ignore it completely.
if RunService:IsStudio() then
	Net.StudioCoins.OnServerEvent:Connect(function(player: Player)
		local data = PlayerData.Get(player)
		if data and Guard.Cooldown(player, "StudioCoins", 0.5) then
			data.Coins += 10000
			PlayerData.Push(player)
		end
	end)
end

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
	UpgradeService.ApplyPlayer(player, data.Upgrades)
	PlotService.RefreshSign(player, data)

	-- new players face their first job (the Moonberry bush); everyone else faces the counter
	local function facing(): Vector3?
		local now = PlayerData.Get(player)
		local bush = if plot then plot.Sources.Moonberry else nil
		local hitbox = if bush then bush:FindFirstChild("Hitbox") else nil
		if now and (now.Stats.PotionsSold or 0) == 0 and hitbox and hitbox:IsA("BasePart") then
			return hitbox.Position
		end
		return nil
	end
	player.CharacterAdded:Connect(function(character)
		PlotService.MoveToPlot(player, character, facing())
	end)
	if player.Character then
		task.spawn(PlotService.MoveToPlot, player, player.Character, facing())
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
