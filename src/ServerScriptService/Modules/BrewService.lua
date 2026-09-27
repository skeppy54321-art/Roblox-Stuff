--!strict
-- BrewService (ModuleScript) — ServerScriptService.Modules.BrewService
-- Brewing at the cauldron. The server decides when a brew starts and finishes.
--   * Tap a potion in the cauldron menu (RequestBrew remote), or
--   * press the cauldron to brew the suggested potion (shown on the prompt).
-- While brewing, pressing the cauldron again = STIR (cuts the time a little).

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local PlotService = require(Modules:WaitForChild("PlotService"))
local CustomerService = require(Modules:WaitForChild("CustomerService"))

type Plot = PlotService.Plot
type Data = PlayerData.Data
type Brew = { Recipe: string, EndTime: number, Duration: number, Stirs: number, Plot: Plot }

local B = Config.Tuning.Brewing

local BrewService = {}

local brewing: { [Player]: Brew } = {}
local lastRecipe: { [Player]: string } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getPrompt(plot: Plot): ProximityPrompt?
	local prompt = plot.Cauldron:FindFirstChild("BrewPrompt", true)
	return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function getHitbox(plot: Plot): BasePart?
	local hitbox = plot.Cauldron:FindFirstChild("Hitbox")
	return if hitbox and hitbox:IsA("BasePart") then hitbox else nil
end

local function setLiquid(plot: Plot, color: Color3, bubbleRate: number)
	local liquid = plot.Cauldron:FindFirstChild("Liquid")
	if liquid and liquid:IsA("BasePart") then
		liquid.Color = color
	end
	local bubbles = plot.Cauldron:FindFirstChild("Bubbles", true)
	if bubbles and bubbles:IsA("ParticleEmitter") then
		bubbles.Color = ColorSequence.new(color)
		bubbles.Rate = bubbleRate
	end
end

-- Back to an idle cauldron.
function BrewService.ResetCauldron(plot: Plot)
	local cauldron = plot.Cauldron
	cauldron:SetAttribute("BrewEndTime", 0)
	cauldron:SetAttribute("BrewDuration", 0)
	cauldron:SetAttribute("BrewRecipe", "")
	cauldron:SetAttribute("SuggestedRecipe", "")
	setLiquid(plot, Config.Palette.Liquid, 3)
	local prompt = getPrompt(plot)
	if prompt then
		prompt.ActionText = "Brew"
		prompt.ObjectText = "Cauldron"
	end
end

-- What pressing the cauldron brews: a potion a customer is waiting for (and you don't
-- have yet), else the last one you brewed, else the priciest one you can make.
local function suggest(player: Player, data: Data, plot: Plot): string?
	local function canBrew(id: string): boolean
		return Config.IsRecipeUnlocked(data.Upgrades, id) and Config.HasIngredientsFor(data.Ingredients, id)
	end
	for _, id in CustomerService.GetWants(plot) do
		if (data.Potions[id] or 0) == 0 and canBrew(id) then
			return id
		end
	end
	local last = lastRecipe[player]
	if last and canBrew(last) then
		return last
	end
	local best: string? = nil
	local bestPrice = -1
	for _, id in Config.RecipeOrder do
		local price = Config.Recipes[id].SellPrice
		if price > bestPrice and canBrew(id) then
			best, bestPrice = id, price
		end
	end
	return best
end

-- Updates the suggested potion shown on the cauldron prompt and in the client's menu.
function BrewService.Refresh(player: Player)
	local plot = PlotService.GetPlot(player)
	local data = PlayerData.Get(player)
	if not plot or not data or brewing[player] then
		return
	end
	local id = suggest(player, data, plot)
	plot.Cauldron:SetAttribute("SuggestedRecipe", id or "")
	local prompt = getPrompt(plot)
	if prompt then
		prompt.ActionText = "Brew"
		prompt.ObjectText = if id then Config.Recipes[id].DisplayName else "Need ingredients"
	end
end

local function finish(player: Player, brew: Brew, quiet: boolean)
	if brewing[player] == brew then
		brewing[player] = nil
	end
	BrewService.ResetCauldron(brew.Plot)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local recipe = Config.Recipes[brew.Recipe]
	data.Potions[brew.Recipe] = (data.Potions[brew.Recipe] or 0) + 1
	PlayerData.AddStat(data, "PotionsBrewed", 1)
	local isNew = not data.Discovered[brew.Recipe]
	local bonus = 0
	if isNew then
		data.Discovered[brew.Recipe] = true
		bonus = recipe.SellPrice -- first time brewing a recipe pays a bonus
		data.Coins += bonus
		PlayerData.AddStat(data, "CoinsEarned", bonus)
	end
	if quiet then
		return
	end
	PlayerData.Push(player)
	if isNew then
		Net.Cue(player, "Discover", { Recipe = brew.Recipe, Bonus = bonus })
		Net.Notify(player, `New recipe: {recipe.DisplayName}! +{bonus} bonus coins`, "good")
	else
		Net.Cue(player, "PotionReady", { Recipe = brew.Recipe })
	end
end

local function watch(player: Player, brew: Brew)
	while brewing[player] == brew do
		if now() >= brew.EndTime then
			finish(player, brew, false)
			return
		end
		task.wait(0.1)
	end
end

local function stir(player: Player, brew: Brew)
	if brew.Stirs >= B.MaxStirs then
		Net.Notify(player, "It's bubbling nicely! Go grab more ingredients.")
		return
	end
	brew.Stirs += 1
	brew.EndTime = math.max(now() + B.MinRemaining, brew.EndTime - B.StirSeconds)
	brew.Plot.Cauldron:SetAttribute("BrewEndTime", brew.EndTime)
	Net.Cue(player, "Stir", { Stirs = brew.Stirs, MaxStirs = B.MaxStirs })
end

local function startBrew(player: Player, plot: Plot, data: Data, recipeId: string)
	local recipe = Config.Recipes[recipeId]
	if not Config.IsRecipeUnlocked(data.Upgrades, recipeId) then
		Net.Notify(player, `Unlock more ingredients to brew {recipe.DisplayName}.`, "bad")
		return
	end
	if Config.PotionTotal(data.Potions) >= Config.GetMaxPotions(data.Upgrades) then
		Net.Notify(player, "Your potion shelf is full! Sell some first.", "bad")
		return
	end
	if not Config.HasIngredientsFor(data.Ingredients, recipeId) then
		Net.Notify(player, `{recipe.DisplayName} needs {Config.DescribeIngredients(recipeId)}.`, "bad")
		return
	end

	-- All checks passed: take the ingredients and start (no yields before this point).
	for ingredientId, amount in recipe.Ingredients do
		data.Ingredients[ingredientId] -= amount
	end
	local duration = Config.GetBrewSeconds(data.Upgrades, recipeId)
	local brew: Brew = { Recipe = recipeId, EndTime = now() + duration, Duration = duration, Stirs = 0, Plot = plot }
	brewing[player] = brew
	lastRecipe[player] = recipeId

	local cauldron = plot.Cauldron
	cauldron:SetAttribute("BrewRecipe", recipeId)
	cauldron:SetAttribute("BrewDuration", duration)
	cauldron:SetAttribute("BrewEndTime", brew.EndTime)
	setLiquid(plot, recipe.Color, 25)
	local prompt = getPrompt(plot)
	if prompt then
		prompt.ActionText = "Stir"
		prompt.ObjectText = `Brewing {recipe.DisplayName}...`
	end

	PlayerData.Push(player)
	Net.Cue(player, "BrewStart", { Recipe = recipeId })
	task.spawn(watch, player, brew)
end

-- Pressing the cauldron: stir if brewing, otherwise brew the suggested potion.
local function onPrompt(player: Player, plot: Plot)
	if not Guard.Owns(player, plot.Model) then
		return
	end
	if not Guard.Cooldown(player, "Cauldron", B.StirCooldown) then
		return
	end
	if not Guard.Near(player, getHitbox(plot)) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local current = brewing[player]
	if current then
		stir(player, current)
		return
	end
	local id = suggest(player, data, plot)
	if not id then
		local first = Config.Recipes[Config.RecipeOrder[1]]
		Net.Notify(player, `You need ingredients! Try {Config.DescribeIngredients(first.Id)}.`, "bad")
		return
	end
	startBrew(player, plot, data, id)
end

-- The cauldron menu asks for a specific potion.
local function onRequest(player: Player, recipeId: unknown)
	if not Guard.IsId(recipeId, Config.Recipes) then
		return
	end
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	if not Guard.Cooldown(player, "Cauldron", B.StirCooldown) then
		return
	end
	if not Guard.Near(player, getHitbox(plot), Config.Tuning.InteractDistance + 4) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if brewing[player] then
		Net.Notify(player, "Your cauldron is busy! Press it to stir.", "bad")
		return
	end
	startBrew(player, plot, data, recipeId :: string)
end

function BrewService.Init(plots: { Plot })
	for _, plot in plots do
		BrewService.ResetCauldron(plot)
		local prompt = getPrompt(plot)
		if prompt then
			prompt.Triggered:Connect(function(player)
				onPrompt(player, plot)
			end)
		end
	end
	Net.RequestBrew.OnServerEvent:Connect(onRequest)
end

function BrewService.IsBrewing(player: Player): boolean
	return brewing[player] ~= nil
end

-- Player is leaving: a brew in progress finishes instantly so the potion isn't lost.
function BrewService.Clear(player: Player)
	local brew = brewing[player]
	if brew then
		finish(player, brew, true)
	end
	brewing[player] = nil
	lastRecipe[player] = nil
end

return BrewService
