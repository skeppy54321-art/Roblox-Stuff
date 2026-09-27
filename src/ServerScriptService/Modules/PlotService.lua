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
local marketParts: MarketBuilder.MarketParts? = nil
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

	marketParts = MarketBuilder.Build(market)
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

-- The plaza's parts (fountain statue, Market Stars board, spawn). Built by Init.
function PlotService.GetMarket(): MarketBuilder.MarketParts
	assert(marketParts, "PlotService.Init must run first")
	return marketParts
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

-- The owner's name on the sign, with their titles under it ("Master Brewer", "Rebirth 2").
function PlotService.RefreshSign(player: Player, data: Config.State)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local titles = {}
	if Config.IsMasterBrewer(data.Discovered) then
		table.insert(titles, "Master Brewer")
	end
	if (data.Rebirths or 0) > 0 then
		table.insert(titles, `Rebirth {data.Rebirths}`)
	end
	local name = `{player.DisplayName}'s Potions`
	setSign(plot, if #titles > 0 then `{name}\n{table.concat(titles, "  ")}` else name)
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
	PlotService.ShowStock(plot, nil)
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

-- Fills the counter display with one bottle per potion in stock (nil = empty shop).
function PlotService.ShowStock(plot: Plot, potions: { [string]: number }?)
	local colors: { Color3 } = {}
	if potions then
		for _, recipeId in Config.RecipeOrder do
			for _ = 1, potions[recipeId] or 0 do
				table.insert(colors, Config.Recipes[recipeId].Color)
			end
		end
	end
	for i, slot in plot.DisplaySlots do
		local color = colors[i]
		for _, part in slot:GetChildren() do
			if part:IsA("BasePart") then
				local transparency = if not color then 1 elseif part.Name == "Neck" then 0.3 else 0
				if part.Transparency ~= transparency then
					part.Transparency = transparency
				end
				if color and part.Name ~= "Cork" and part.Color ~= color then
					part.Color = color
				end
			end
		end
	end
end

-- Moves the character into the player's shop, facing the counter (or `face`, a point to
-- look at: new players face their first job, the Moonberry bush).
function PlotService.MoveToPlot(player: Player, character: Model, face: Vector3?)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.1) -- let the default spawn finish first
	if character.Parent and plotByPlayer[player] == plot then
		local at = plot.SpawnPoint.Position + Vector3.new(0, 3, 0)
		local target = if face then Vector3.new(face.X, at.Y, face.Z) else nil
		local pivot = if target and (target - at).Magnitude > 0.5
			then CFrame.lookAt(at, target)
			else plot.SpawnPoint.CFrame + Vector3.new(0, 3, 0)
		character:PivotTo(pivot)
	end
end

return PlotService
