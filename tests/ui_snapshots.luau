--!nocheck
-- ui_snapshots.luau: plays a little and dumps the HUD's GUI tree at key moments, so
-- tests/preview/ui.html can draw it. Usage:
--   lune run tests/ui_snapshots.luau <place.rbxlx> <out_dir> <width> <height> <label>

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local task = require("@lune/task")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Engine = require("./engine")

local PLACE, OUT = process.args[1], process.args[2]
local WIDTH, HEIGHT = tonumber(process.args[3]) or 844, tonumber(process.args[4]) or 390
local LABEL = process.args[5] or "phone"

local game = roblox.deserializePlace(fs.readFile(PLACE))
Engine.game = game
Engine.viewport = roblox.Vector2.new(WIDTH, HEIGHT)
Engine.install(game, { client = true })

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

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

local camera = roblox.Instance.new("Camera")
camera.Parent = workspace
pcall(function()
	workspace.CurrentCamera = camera
end)
pcall(function()
	camera.ViewportSize = roblox.Vector2.new(WIDTH, HEIGHT)
end)
local RunService = game:GetService("RunService")
task.spawn(function()
	local elapsed = 0
	while true do
		local dt = task.wait(1 / 30)
		Engine.signal(RunService, "RenderStepped"):Fire(dt)
		Engine.signal(RunService, "Heartbeat"):Fire(dt)
		elapsed += dt
		if elapsed > 0.1 then
			elapsed = 0
			Engine.syncPositions(workspace)
		end
	end
end)

Engine.run(game:GetService("ServerScriptService"):FindFirstChild("Main"))
waitFor(5, function()
	return workspace:FindFirstChild("Market")
end)
Engine.syncPositions(workspace)

local player = roblox.Instance.new("Player")
player.Name = "Tester"
player.UserId = 1001
player.DisplayName = "Tester"
local playerGui = roblox.Instance.new("PlayerGui")
playerGui.Parent = player
player.Parent = Players
Engine.localPlayer = player
pcall(function()
	Players.LocalPlayer = player
end)
local character = roblox.Instance.new("Model")
character.Name = "Tester"
local root = roblox.Instance.new("Part")
root.Name = "HumanoidRootPart"
Engine.setCFrame(root, CFrame.new(0, 3, -20))
root.Parent = character
character.PrimaryPart = root
character.Parent = workspace
player.Character = character
Engine.signal(Players, "PlayerAdded"):Fire(player)
Engine.signal(player, "CharacterAdded"):Fire(character)
local plotName = waitFor(10, function()
	return player:GetAttribute("PlotName")
end)
local plot = workspace.Market:FindFirstChild(plotName)
Engine.run(game:GetService("StarterPlayer").StarterPlayerScripts.ClientMain)
local hud = waitFor(5, function()
	return playerGui:FindFirstChild("PotionHud")
end)
local ui = hud:FindFirstChild("Root")

local function snap(state)
	task.wait(0.6) -- let tweens settle
	local file = `{OUT}/ui_{LABEL}_{state}.json`
	fs.writeFile(file, serde.encode("json", { width = WIDTH, height = HEIGHT, tree = Engine.dumpGui(hud) }))
	print("snapshot " .. file)
end
local function goTo(part)
	Engine.setCFrame(root, CFrame.new(part.CFrame.Position + Vector3.new(0, 0, 3)))
end

local modules = game:GetService("ServerScriptService").Modules
local PlayerData = Engine.loaded(modules.PlayerData)
local UpgradeService = Engine.loaded(modules.UpgradeService)
local PlotService = Engine.loaded(modules.PlotService)
local data = waitFor(5, function()
	return PlayerData.Get(player)
end)

task.wait(0.8)
snap("start")

-- some progress: a few ingredients, potions and the Starflower Bed
data.Coins = 137
data.Ingredients.Moonberry = 3
data.Ingredients.Glowshroom = 1
data.Ingredients.Starflower = 1
data.Potions.GiantHead = 2
data.Potions.Rainbow = 1
data.Upgrades.StarflowerBed = 1
data.Upgrades.BrewSpeed = 1
data.Discovered.GiantHead = true
data.Discovered.Rainbow = true
data.Stats.PotionsSold = 3
UpgradeService.ApplyAll(PlotService.GetPlot(player), data.Upgrades)
PlayerData.Push(player)
goTo(plot.Cauldron.Hitbox)
waitFor(2, function()
	return ui.CauldronMenu.Visible
end)
snap("cauldron")

goTo(plot.Sources.Moonberry.Hitbox)
task.wait(0.3)
Engine.signal(ui.SideButtons.UpgradesButton.Face, "Activated"):Fire()
snap("upgrades")

Engine.signal(ui.SideButtons.RecipesButton.Face, "Activated"):Fire()
snap("recipes")

Engine.signal(ui.RecipeBook.Close.Face, "Activated"):Fire()
local Net = Engine.loaded(modules.Net)
Net.Notify(player, "+1 Moonberry", "info")
Net.Notify(player, "Your potion shelf is full! Sell some first.", "bad")
Net.Notify(player, "New recipe: Floaty Potion! +24 bonus coins", "good")
Net.Cue(player, "Discover", { Recipe = "Floaty", Bonus = 24 })
task.wait(0.1)
snap("celebrate")

print("done")
process.exit(0)
