-- PlotService (ModuleScript) — ServerScriptService.Modules.PlotService
-- Builds the market, gives each player a free plot, and moves them to it.

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local ShopBuilder = require(script.Parent:WaitForChild("ShopBuilder"))

local PlotService = {}

local market: Folder
local plots: { Model } = {}
local plotByPlayer: { [Player]: Model } = {}

local function setSign(plot: Model, text: string)
	local sign = plot:FindFirstChild("Sign")
	if not sign then
		return
	end
	for _, gui in sign:GetChildren() do
		local label = gui:FindFirstChild("SignLabel")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

function PlotService.Init()
	market = Instance.new("Folder")
	market.Name = "Market"
	market.Parent = workspace
	for i, center in Config.Plots do
		table.insert(plots, ShopBuilder.BuildPlot(i, center, market))
	end
end

function PlotService.GetPlots(): { Model }
	return plots
end

function PlotService.GetPlot(player: Player): Model?
	return plotByPlayer[player]
end

function PlotService.GetOwner(plot: Model): Player?
	local userId = plot:GetAttribute("OwnerUserId")
	if typeof(userId) ~= "number" or userId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

-- Gives the player the first empty plot. Returns nil if the market is full.
function PlotService.Assign(player: Player): Model?
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plotByPlayer[player] = plot
			player:SetAttribute("PlotName", plot.Name)
			setSign(plot, player.DisplayName .. "'s Potions")
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
	plot:SetAttribute("OwnerUserId", 0)
	setSign(plot, "Empty Shop")
end

-- Moves the character to the player's shop.
function PlotService.MoveToPlot(player: Player, character: Model)
	local plot = plotByPlayer[player]
	local spawnPoint = plot and plot:FindFirstChild("SpawnPoint")
	if not spawnPoint or not spawnPoint:IsA("BasePart") then
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.1) -- let the default spawn finish first
	if character.Parent then
		character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
	end
end

return PlotService
