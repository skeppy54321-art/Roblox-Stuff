--!nocheck
-- pacing_bot.luau: plays Brew a Potion like a quick, focused player, in real time, through
-- the real server scripts, and prints a timeline: first brew, first sale, every upgrade and
-- coins earned per minute. Use it to check the economy after changing numbers in Config.
-- Usage: lune run tests/pacing_bot.luau <place.rbxlx> [minutes]   (default 8)
--
-- The bot walks at Roblox's default speed, pauses a moment between actions, stirs every
-- brew, sells across the counter, and buys whatever the goal banner would suggest.

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local task = require("@lune/task")
local process = require("@lune/process")
local Engine = require("./engine")

local MINUTES = tonumber(process.args[2]) or 8
local WALK_SPEED = 16 -- studs per second (Roblox's default)
local THINK = 0.35 -- seconds between actions
local PRESS_GAP = 0.3 -- between repeated presses of the same prompt

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
Engine.game = game
Engine.install(game, { client = false })

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

task.spawn(function() -- heartbeat + position sync, like the server test
	local rs = game:GetService("RunService")
	local elapsed = 0
	while true do
		local dt = task.wait(1 / 30)
		Engine.signal(rs, "Heartbeat"):Fire(dt)
		elapsed += dt
		if elapsed > 0.1 then
			elapsed = 0
			Engine.syncPositions(workspace)
		end
	end
end)

local function waitFor(seconds, predicate)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(0.05)
	end
	return nil
end

Engine.run(game:GetService("ServerScriptService"):FindFirstChild("Main"))
local market = waitFor(5, function()
	return workspace:FindFirstChild("Market")
end)
task.wait(0.5)
Engine.syncPositions(workspace)

local player = roblox.Instance.new("Player")
player.Name = "Bot"
player.UserId = 4242
player.DisplayName = "Bot"
player.Parent = Players
Engine.signal(Players, "PlayerAdded"):Fire(player)
local character = roblox.Instance.new("Model")
character.Name = "Bot"
local root = roblox.Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(2, 2, 1)
Engine.setCFrame(root, CFrame.new(0, 3, -20))
root.Parent = character
character.PrimaryPart = root
character.Parent = workspace
player.Character = character
Engine.signal(player, "CharacterAdded"):Fire(character)

local modules = game:GetService("ServerScriptService").Modules
local PlayerData = waitFor(3, function()
	return Engine.loaded(modules.PlayerData)
end)
local data = waitFor(10, function()
	return PlayerData.Get(player)
end)
local plot = market:FindFirstChild(waitFor(3, function()
	return player:GetAttribute("PlotName")
end))
local Config = Engine.loaded(game:GetService("ReplicatedStorage").Config)
local remotes = game:GetService("ReplicatedStorage").Remotes
task.wait(0.5)

local started = os.clock()
local function stamp(): string
	local t = os.clock() - started
	return string.format("%2d:%02d", math.floor(t / 60), math.floor(t % 60))
end
local function log(text)
	print(`[{stamp()}] {text}  (coins {data.Coins})`)
end

-- walking takes as long as it would in the game
local center = plot.PrimaryPart.CFrame.Position
local function walkTo(target: Vector3)
	local from = root.CFrame.Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	task.wait(flat.Magnitude / WALK_SPEED + THINK)
	Engine.setCFrame(root, CFrame.new(Vector3.new(target.X, 3, target.Z)))
	Engine.syncPositions(character)
end
local function toward(part, distance)
	local p = part.CFrame.Position
	local inward = Vector3.new(center.X - p.X, 0, center.Z - p.Z)
	return p + inward.Unit * distance
end
local function press(prompt)
	Engine.signal(prompt, "Triggered"):Fire(player)
	task.wait(PRESS_GAP)
end

local function unlocked(recipeId)
	return Config.IsRecipeUnlocked(data.Upgrades, recipeId)
end
local function waitingCustomers()
	local list = {}
	for _, c in plot:GetChildren() do
		if c.Name == "Customer" and c:GetAttribute("Phase") == "Waiting" then
			table.insert(list, c)
		end
	end
	return list
end

-- the potion to work on: one a customer is waiting for, else the priciest we can make
local function target(): string?
	for _, c in waitingCustomers() do
		local wants = c:GetAttribute("Wants")
		if (data.Potions[wants] or 0) == 0 and unlocked(wants) then
			return wants
		end
	end
	local best, bestPrice = nil, -1
	for _, id in Config.RecipeOrder do
		if unlocked(id) and Config.Recipes[id].SellPrice > bestPrice then
			best, bestPrice = id, Config.Recipes[id].SellPrice
		end
	end
	return best
end

local firstSale, sales, lastMinute, earnedAtMinute = nil, 0, 0, 0
local timeline = {}
local function cauldronBusy()
	return (plot.Cauldron:GetAttribute("BrewRecipe") or "") ~= ""
end

while os.clock() - started < MINUTES * 60 do
	-- per-minute report
	local minute = math.floor((os.clock() - started) / 60)
	if minute > lastMinute then
		local earned = (data.Stats.CoinsEarned or 0) - earnedAtMinute
		print(`   minute {minute}: +{earned} coins earned, {sales} sales so far`)
		earnedAtMinute = data.Stats.CoinsEarned or 0
		lastMinute = minute
	end

	-- 1. sell to a waiting customer if we have what they want
	local sold = false
	for _, c in waitingCustomers() do
		local wants = c:GetAttribute("Wants")
		if (data.Potions[wants] or 0) > 0 then
			walkTo(toward(c.Torso, 6))
			local before = data.Stats.PotionsSold or 0
			press(c.Torso.SellPrompt)
			if (data.Stats.PotionsSold or 0) > before then
				sales += 1
				if not firstSale then
					firstSale = os.clock() - started
					log(`FIRST SALE: {wants}`)
					table.insert(timeline, `first sale {stamp()}`)
				end
			end
			sold = true
			break
		end
	end
	if sold then
		continue
	end

	-- 2. buy what the goal banner would suggest (after the first sale)
	if (data.Stats.PotionsSold or 0) > 0 then
		local bought = false
		local id = Config.GetSuggestedUpgrade(data.Upgrades, data.Coins)
		if id then
			local level = Config.GetLevel(data.Upgrades, id)
			local cost = Config.GetNextUpgradeCost(id, level)
			Engine.signal(remotes.RequestUpgrade, "OnServerEvent"):Fire(player, id)
			task.wait(0.5)
			if Config.GetLevel(data.Upgrades, id) > level then
				log(`bought {id} level {level + 1} for {cost}`)
				table.insert(timeline, `{id} {level + 1} at {stamp()}`)
				bought = true
			end
		end
		if bought then
			continue
		end
	end

	-- 3. brew when we can, then stir it three times
	local shelfFull = Config.PotionTotal(data.Potions) >= Config.GetMaxPotions(data.Upgrades)
	local goal = target()
	if not cauldronBusy() and not shelfFull and goal and Config.HasIngredientsFor(data.Ingredients, goal) then
		walkTo(toward(plot.Cauldron.Hitbox, 3))
		Engine.signal(remotes.RequestBrew, "OnServerEvent"):Fire(player, goal)
		task.wait(THINK)
		if cauldronBusy() then
			if (data.Stats.PotionsBrewed or 0) == 0 then
				log(`first brew: {goal}`)
			end
			for _ = 1, Config.Tuning.Brewing.MaxStirs do
				press(plot.Cauldron.Hitbox.BrewPrompt)
			end
		end
		continue
	end

	-- 4. collect what the next potion needs (or wait for customers if the shelf is full)
	if shelfFull or not goal then
		task.wait(0.5)
		continue
	end
	local collected = false
	for _, ingredientId in Config.IngredientOrder do
		local need = Config.Recipes[goal].Ingredients[ingredientId] or 0
		if (data.Ingredients[ingredientId] or 0) < need then
			local source = plot.Sources:FindFirstChild(ingredientId)
			if source then
				walkTo(toward(source.Hitbox, 3))
				local before = data.Ingredients[ingredientId] or 0
				press(source.Hitbox.CollectPrompt)
				if (data.Ingredients[ingredientId] or 0) == before then
					task.wait(0.5) -- out of charges: wait for it to regrow
				end
				collected = true
			end
			break
		end
	end
	if not collected then
		task.wait(0.3)
	end
end

print("")
print(`== after {MINUTES} minutes: {data.Coins} coins, {data.Stats.CoinsEarned or 0} earned, {sales} sales ==`)
print("timeline: " .. table.concat(timeline, ", "))
local owned = {}
for _, id in Config.UpgradeOrder do
	table.insert(owned, `{id} {Config.GetLevel(data.Upgrades, id)}`)
end
print("upgrades: " .. table.concat(owned, ", "))
process.exit(0)
