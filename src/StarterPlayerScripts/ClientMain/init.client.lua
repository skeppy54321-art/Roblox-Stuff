-- ClientMain (LocalScript) — StarterPlayer.StarterPlayerScripts.ClientMain
-- Shows the UI, hides other players' prompts, draws the brew progress bar,
-- and plays cosmetic effects. It never changes coins or items itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Effects = require(ReplicatedStorage:WaitForChild("Effects"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Hud = require(script:WaitForChild("Hud"))

local StateUpdate = Remotes:WaitForChild("StateUpdate") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local PlayEffect = Remotes:WaitForChild("PlayEffect") :: RemoteEvent
local RequestUpgrade = Remotes:WaitForChild("RequestUpgrade") :: RemoteEvent
local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction

local hud = Hud.new(player:WaitForChild("PlayerGui"))
local state = nil
local market = workspace:WaitForChild("Market")

------------------------------------------------------------------
-- Only show prompts for YOUR shop
------------------------------------------------------------------
local function findPlot(inst: Instance): Instance?
	local node = inst.Parent
	while node and node ~= market do
		if node:GetAttribute("IsPlot") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function refreshPrompt(prompt: ProximityPrompt)
	local plot = findPlot(prompt)
	if plot then
		prompt.Enabled = plot:GetAttribute("OwnerUserId") == player.UserId
	end
end

local function refreshPlot(plot: Instance)
	for _, d in plot:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			refreshPrompt(d)
		end
	end
end

local function watchPlot(plot: Instance)
	if plot:GetAttribute("IsPlot") then
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshPlot(plot)
		end)
		refreshPlot(plot)
	end
end

for _, plot in market:GetChildren() do
	watchPlot(plot)
end
market.ChildAdded:Connect(watchPlot)
market.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		refreshPrompt(d)
	end
end)

------------------------------------------------------------------
-- My cauldron + brew progress bar
------------------------------------------------------------------
local function myCauldron(): Instance?
	local plotName = player:GetAttribute("PlotName")
	local plot = typeof(plotName) == "string" and market:FindFirstChild(plotName) or nil
	return plot and plot:FindFirstChild("Cauldron") or nil
end

local function isBrewing(): boolean
	local cauldron = myCauldron()
	local endTime = cauldron and cauldron:GetAttribute("BrewEndTime")
	return typeof(endTime) == "number" and endTime > workspace:GetServerTimeNow()
end

local bar = Instance.new("BillboardGui")
bar.Name = "BrewBar"
bar.Size = UDim2.fromOffset(160, 26)
bar.StudsOffset = Vector3.new(0, 4.5, 0)
bar.AlwaysOnTop = true
bar.Enabled = false
bar.Parent = player:WaitForChild("PlayerGui")
local barBack = Instance.new("Frame")
barBack.Size = UDim2.fromScale(1, 1)
barBack.BackgroundColor3 = Config.Palette.PanelDark
barBack.Parent = bar
Instance.new("UICorner").Parent = barBack
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Config.Palette.Liquid
barFill.Parent = barBack
Instance.new("UICorner").Parent = barFill

local watchedCauldron: Instance? = nil
local function attachBar()
	local cauldron = myCauldron()
	if cauldron == watchedCauldron then
		return
	end
	watchedCauldron = cauldron
	bar.Adornee = cauldron and cauldron:FindFirstChild("Hitbox") :: BasePart? or nil
	if cauldron then
		-- Little bubble burst whenever you stir (end time moves earlier)
		cauldron:GetAttributeChangedSignal("BrewEndTime"):Connect(function()
			local bubbles = cauldron:FindFirstChild("Bubbles", true)
			if bubbles and bubbles:IsA("ParticleEmitter") and isBrewing() then
				bubbles:Emit(12)
			end
		end)
	end
end
player:GetAttributeChangedSignal("PlotName"):Connect(attachBar)
attachBar()

RunService.RenderStepped:Connect(function()
	local cauldron = watchedCauldron
	if not cauldron then
		bar.Enabled = false
		return
	end
	local endTime = cauldron:GetAttribute("BrewEndTime")
	local duration = cauldron:GetAttribute("BrewDuration")
	local nowTime = workspace:GetServerTimeNow()
	if typeof(endTime) == "number" and typeof(duration) == "number" and duration > 0 and endTime > nowTime then
		bar.Enabled = true
		local progress = 1 - (endTime - nowTime) / duration
		barFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	else
		bar.Enabled = false
	end
end)

------------------------------------------------------------------
-- Goal banner: always tells you the next thing to do
------------------------------------------------------------------
local function goalText(): string
	if not state then
		return "Loading your shop..."
	end
	if not player:GetAttribute("PlotName") then
		return "The market is full. Try another server!"
	end
	local recipeId = Config.PrototypeRecipe
	local recipe = Config.Recipes[recipeId]
	if isBrewing() then
		return "Brewing! Press the cauldron to STIR, or grab more ingredients."
	end
	if (state.Potions[recipeId] or 0) > 0 then
		return "Sell your potion to the customer at the counter!"
	end
	local cost = Config.GetNextUpgradeCost("BrewSpeed", state.Upgrades.BrewSpeed or 0)
	if cost and state.Coins >= cost then
		return "You can afford Faster Brewing! Tap UPGRADES."
	end
	for _, id in Config.IngredientOrder do
		local need = recipe.Ingredients[id] or 0
		if (state.Ingredients[id] or 0) < need then
			local info = Config.Ingredients[id]
			return `Collect a {info.DisplayName} from {info.Where}.`
		end
	end
	return "Brew a potion at the cauldron!"
end

task.spawn(function()
	while true do
		hud:SetGoal(goalText())
		task.wait(0.25)
	end
end)

------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------
StateUpdate.OnClientEvent:Connect(function(newState)
	state = newState
	hud:SetState(state)
end)

Notify.OnClientEvent:Connect(function(text)
	if typeof(text) == "string" then
		hud:Toast(text)
	end
end)

PlayEffect.OnClientEvent:Connect(function(model, effectName)
	Effects.Play(effectName, model)
end)

hud.onUpgrade = function(upgradeId: string)
	RequestUpgrade:FireServer(upgradeId)
end

-- First load (in case the first StateUpdate arrived before we were listening)
task.spawn(function()
	while not state do
		local ok, result = pcall(function()
			return GetState:InvokeServer()
		end)
		if ok and result and not state then
			state = result
			hud:SetState(state)
		end
		if not state then
			task.wait(0.5)
		end
	end
end)
