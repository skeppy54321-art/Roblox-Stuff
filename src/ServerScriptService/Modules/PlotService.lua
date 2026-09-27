--!strict
-- PlotService (ModuleScript) — ServerScriptService.Modules.PlotService
-- Builds the market and the shop plots, gives each player a free shop, moves them
-- into it, and shows each shop's upgrades (planted sources, shelves, decor, fire color).

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local ShopBuilder = require(Modules:WaitForChild("ShopBuilder"))
local MarketBuilder = require(Modules:WaitForChild("MarketBuilder"))

export type Plot = ShopBuilder.PlotParts

local P = Config.Palette

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local stashes: { [Plot]: Folder } = {} -- hidden (not yet bought) parts of each plot, kept on the server only

local function setSign(plot: Plot, text: string)
	for _, d in plot.Sign:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = text
		end
	end
end

-- Shows `inst` under `home`, or hides it in the plot's stash.
local function show(plot: Plot, inst: Instance, visible: boolean, home: Instance)
	local target = if visible then home else stashes[plot]
	if inst.Parent ~= target then
		inst.Parent = target
	end
end

function PlotService.Init()
	local market = Instance.new("Folder")
	market.Name = "Market"
	market.Parent = workspace
	local stashRoot = Instance.new("Folder")
	stashRoot.Name = "PlotStash"
	stashRoot.Parent = ServerStorage

	MarketBuilder.Build(market)
	for i = 1, Config.World.PlotCount do
		local plot = ShopBuilder.BuildPlot(i, Config.World.GetPlotCFrame(i), market)
		local stash = Instance.new("Folder")
		stash.Name = plot.Model.Name
		stash.Parent = stashRoot
		stashes[plot] = stash
		table.insert(plots, plot)
		PlotService.ApplyVisuals(plot, nil)
	end
end

function PlotService.GetPlots(): { Plot }
	return plots
end

function PlotService.GetPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.GetOwner(plot: Plot): Player?
	local userId = plot.Model:GetAttribute("OwnerUserId")
	if typeof(userId) ~= "number" or userId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

-- Gives the player the first empty plot. Returns nil if the market is full.
function PlotService.Assign(player: Player): Plot?
	local existing = plotByPlayer[player]
	if existing then
		return existing
	end
	for _, plot in plots do
		if plot.Model:GetAttribute("OwnerUserId") == 0 then
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plotByPlayer[player] = plot
			player:SetAttribute("PlotName", plot.Model.Name)
			setSign(plot, `{player.DisplayName}'s Potions`)
			return plot
		end
	end
	return nil
end

function PlotService.Release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	setSign(plot, "Empty Shop")
	PlotService.ApplyVisuals(plot, nil)
end

-- Makes the shop look like its owner's upgrades (nil = a fresh, empty shop).
function PlotService.ApplyVisuals(plot: Plot, upgrades: { [string]: number }?)
	for ingredientId, source in plot.Sources do
		local unlocked = Config.IsIngredientUnlocked(upgrades, ingredientId)
		show(plot, source, unlocked, plot.SourcesFolder)
		local upgradeId = Config.Ingredients[ingredientId].UnlockedBy
		local lot = if upgradeId then plot.Lots[upgradeId] else nil
		if lot then
			show(plot, lot, not unlocked, plot.LotsFolder)
		end
	end

	local shelves = Config.GetLevel(upgrades, "Shelves")
	show(plot, plot.Features.Shelf2, shelves >= 1, plot.Model)
	show(plot, plot.Features.Shelf3, shelves >= 2, plot.Model)

	local decor = Config.GetLevel(upgrades, "CozyDecor")
	show(plot, plot.Features.DecorLights, decor >= 1, plot.Model)
	show(plot, plot.Features.DecorBanners, decor >= 2, plot.Model)
	show(plot, plot.Features.DecorGold, decor >= 3, plot.Model)
	for _, part in plot.GoldParts do
		part.Color = if decor >= 3 then P.Gold else P.Cauldron
		part.Material = if decor >= 3 then Enum.Material.Foil else Enum.Material.Metal
	end

	local fire = Config.GetFireColor(upgrades)
	for _, part in plot.FireParts do
		part.Color = fire
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = fire
		end
	end
end

-- Moves the character into the player's shop, facing the counter.
function PlotService.MoveToPlot(player: Player, character: Model)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.1) -- let the default spawn finish first
	if character.Parent and plotByPlayer[player] == plot then
		character:PivotTo(plot.SpawnPoint.CFrame + Vector3.new(0, 3, 0))
	end
end

return PlotService
