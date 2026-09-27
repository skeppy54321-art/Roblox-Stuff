-- BrewService (ModuleScript) — ServerScriptService.Modules.BrewService
-- Brewing at the cauldron. Server decides when a brew starts and finishes.
-- While brewing, pressing the cauldron again = STIR (cuts the time a little).

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local PlotService = require(Modules:WaitForChild("PlotService"))

local BrewService = {}

type Brew = { Recipe: string, EndTime: number, Stirs: number, Cauldron: Model }
local brewing: { [Player]: Brew } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getPrompt(cauldron: Model): ProximityPrompt?
	local prompt = cauldron:FindFirstChild("BrewPrompt", true)
	return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function setIdle(cauldron: Model)
	cauldron:SetAttribute("BrewEndTime", 0)
	cauldron:SetAttribute("BrewDuration", 0)
	local prompt = getPrompt(cauldron)
	if prompt then
		prompt.ActionText = "Brew"
		prompt.ObjectText = Config.Recipes[Config.PrototypeRecipe].DisplayName
	end
	local bubbles = cauldron:FindFirstChild("Bubbles", true)
	if bubbles and bubbles:IsA("ParticleEmitter") then
		bubbles.Rate = 3
	end
end

local function setBrewing(cauldron: Model, endTime: number, duration: number)
	cauldron:SetAttribute("BrewEndTime", endTime)
	cauldron:SetAttribute("BrewDuration", duration)
	local prompt = getPrompt(cauldron)
	if prompt then
		prompt.ActionText = "Stir"
		prompt.ObjectText = "Brewing..."
	end
	local bubbles = cauldron:FindFirstChild("Bubbles", true)
	if bubbles and bubbles:IsA("ParticleEmitter") then
		bubbles.Rate = 25
	end
end

local function finish(player: Player, brew: Brew)
	brewing[player] = nil
	setIdle(brew.Cauldron)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local recipe = Config.Recipes[brew.Recipe]
	data.Potions[brew.Recipe] = (data.Potions[brew.Recipe] or 0) + 1
	data.Stats.PotionsBrewed += 1
	if not data.Discovered[brew.Recipe] then
		data.Discovered[brew.Recipe] = true
		Net.Notify(player, `New recipe discovered: {recipe.DisplayName}!`)
	else
		Net.Notify(player, `{recipe.DisplayName} is ready!`)
	end
	PlayerData.Push(player)
end

local function watch(player: Player, brew: Brew)
	while brewing[player] == brew do
		if now() >= brew.EndTime then
			finish(player, brew)
			return
		end
		task.wait(0.1)
	end
end

local function stir(player: Player, brew: Brew)
	if brew.Stirs >= Config.Brewing.MaxStirs then
		Net.Notify(player, "It's bubbling nicely! Go grab more ingredients.")
		return
	end
	brew.Stirs += 1
	brew.EndTime = math.max(now() + 0.3, brew.EndTime - Config.Brewing.StirSeconds)
	brew.Cauldron:SetAttribute("BrewEndTime", brew.EndTime)
	Net.Notify(player, `Stir! ({brew.Stirs}/{Config.Brewing.MaxStirs})`)
end

local function onUse(player: Player, plot: Model, cauldron: Model)
	if not Guard.Owns(player, plot) then
		return
	end
	if not Guard.Cooldown(player, "Cauldron", Config.Brewing.StirCooldown) then
		return
	end
	if not Guard.Near(player, cauldron:FindFirstChild("Hitbox") :: BasePart?) then
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

	local recipeId = Config.PrototypeRecipe
	local recipe = Config.Recipes[recipeId]
	if PlayerData.PotionTotal(data) >= Config.Storage.MaxPotions then
		Net.Notify(player, "Potion shelf is full! Sell some first.")
		return
	end
	for ingredient, amount in recipe.Ingredients do
		if (data.Ingredients[ingredient] or 0) < amount then
			local parts = {}
			for id, need in recipe.Ingredients do
				table.insert(parts, `{need} {Config.Ingredients[id].DisplayName}`)
			end
			Net.Notify(player, "You need " .. table.concat(parts, " + "))
			return
		end
	end

	-- All checks passed: take ingredients and start (no yields before this point).
	for ingredient, amount in recipe.Ingredients do
		data.Ingredients[ingredient] -= amount
	end
	local duration = Config.GetBrewSeconds(data.Upgrades.BrewSpeed or 0)
	local brew: Brew = { Recipe = recipeId, EndTime = now() + duration, Stirs = 0, Cauldron = cauldron }
	brewing[player] = brew
	setBrewing(cauldron, brew.EndTime, duration)
	PlayerData.Push(player)
	Net.Notify(player, "Brewing! Press again to stir.")
	task.spawn(watch, player, brew)
end

function BrewService.Init(plots: { Model })
	for _, plot in plots do
		local cauldron = plot:FindFirstChild("Cauldron")
		if not cauldron or not cauldron:IsA("Model") then
			continue
		end
		setIdle(cauldron)
		local prompt = getPrompt(cauldron)
		if prompt then
			prompt.Triggered:Connect(function(player)
				onUse(player, plot, cauldron)
			end)
		end
	end
end

function BrewService.IsBrewing(player: Player): boolean
	return brewing[player] ~= nil
end

-- Cancel any brew (player left). Ingredients are not refunded in the prototype.
function BrewService.Clear(player: Player)
	local brew = brewing[player]
	brewing[player] = nil
	if brew then
		setIdle(brew.Cauldron)
	else
		local plot = PlotService.GetPlot(player)
		local cauldron = plot and plot:FindFirstChild("Cauldron")
		if cauldron and cauldron:IsA("Model") then
			setIdle(cauldron)
		end
	end
end

return BrewService
