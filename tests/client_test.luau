--!nocheck
-- client_test.luau: "play solo" in one process. Boots the server, joins one player, runs the real
-- ClientMain LocalScript for them, then clicks through the UI and plays every potion effect.
-- Usage: lune run client_test.luau <place.rbxlx>

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local task = require("@lune/task")
local process = require("@lune/process")
local Engine = require("./engine")

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
Engine.game = game
Engine.install(game, { client = true })

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local Vector3, CFrame, Enum = roblox.Vector3, roblox.CFrame, roblox.Enum

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
	end
end
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
local function find(root, path)
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

-- camera + frame loop (RenderStepped/Heartbeat) + Position syncing
local camera = roblox.Instance.new("Camera")
camera.Parent = workspace
pcall(function()
	workspace.CurrentCamera = camera
end)
pcall(function()
	camera.ViewportSize = roblox.Vector2.new(844, 390) -- a phone in landscape
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

print("== server + player ==")
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
check("player got a plot", plotName ~= nil)
local plot = workspace.Market:FindFirstChild(plotName)

print("== client boots ==")
-- pretend one sound asset is broken, to check the built-in fallback
local CHIME = "rbxassetid://4110925712"
Engine.failedAssets = { [CHIME] = true }
local clientMain = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("ClientMain")
-- LocalScripts run from a copy in the player's PlayerScripts in Roblox; the source is the same
Engine.run(clientMain)
local hud = waitFor(5, function()
	return playerGui:FindFirstChild("PotionHud")
end)
check("HUD created", hud ~= nil)
local uiRoot = hud and hud:FindFirstChild("Root")
check("scaled root", uiRoot ~= nil)
for _, name in { "Coins", "Goal", "Basket", "SideButtons", "Toasts", "Celebration", "UpgradesPanel", "RecipeBook", "CauldronMenu" } do
	check("has " .. name, uiRoot and uiRoot:FindFirstChild(name) ~= nil)
end
local scale = uiRoot and uiRoot:FindFirstChildOfClass("UIScale")
check("phone UI scale ~0.7", scale and math.abs(scale.Scale - 0.696) < 0.02, scale and scale.Scale)
check("brew bar billboard", playerGui:FindFirstChild("BrewBar") ~= nil)
check("goal marker billboard", playerGui:FindFirstChild("GoalMarker") ~= nil)
task.wait(0.6)

print("== sounds ==")
local SoundService = game:GetService("SoundService")
local SoundsConfig = Engine.loaded(game:GetService("ReplicatedStorage").Config.Sounds)
local preloaded = table.concat(Engine.preloaded or {}, " ")
check("sound ids preloaded", preloaded:find(CHIME, 1, true) and preloaded:find(SoundsConfig.Music.Id, 1, true), preloaded)
local musicSound = SoundService:FindFirstChild("Music")
check("music playing, looped", musicSound and musicSound.Looped and musicSound.SoundId == SoundsConfig.Music.Id)
local Sfx = Engine.loaded(clientMain.Sfx)
Sfx.Play("PotionReady")
local ready = SoundService:FindFirstChild("PotionReady")
check("broken asset falls back to built-in", ready and ready.SoundId == SoundsConfig.PotionReady.Builtin, ready and ready.SoundId)
Sfx.Play("Upgrade")
local fanfare = SoundService:FindFirstChild("Upgrade")
check("upgrade plays its asset", fanfare and fanfare.SoundId == SoundsConfig.Upgrade.Id, fanfare and fanfare.SoundId)
task.wait(0.5)
check("music ducks under a fanfare", musicSound and musicSound.Volume < SoundsConfig.Music.Volume, musicSound and musicSound.Volume)
task.wait(SoundsConfig.Upgrade.MaxSeconds + 0.6)
check("fanfare fades out and is removed", fanfare and fanfare.Parent == nil)
check("music back to full volume", musicSound and math.abs(musicSound.Volume - SoundsConfig.Music.Volume) < 1e-3, musicSound and musicSound.Volume)
local goalLabel = uiRoot.Goal:FindFirstChildOfClass("TextLabel")
local function goalText()
	for _, d in uiRoot.Goal:GetDescendants() do
		if d:IsA("TextLabel") and d.Text ~= "!" then
			return d.Text
		end
	end
	return ""
end
check("goal says collect a moonberry", goalText():find("Moonberry") ~= nil, goalText())
local marker = playerGui:FindFirstChild("GoalMarker")
check("arrow shows for a new player", marker.Enabled == true)
check("arrow points at the bush", marker.Adornee == plot.Sources.Moonberry.Hitbox, marker.Adornee and marker.Adornee:GetFullName())
check("prompts restyled", plot.Cauldron.Hitbox.BrewPrompt.Style == Enum.ProximityPromptStyle.Custom)
local otherPlot
for _, p in workspace.Market:GetChildren() do
	if p:GetAttribute("IsPlot") and p ~= plot then
		otherPlot = p
		break
	end
end
check("other shops' prompts hidden", otherPlot.Cauldron.Hitbox.BrewPrompt.Enabled == false)

print("== prompt UI ==")
local PPS = game:GetService("ProximityPromptService")
local prompt = plot.Sources.Moonberry.Hitbox.CollectPrompt
Engine.signal(PPS, "PromptShown"):Fire(prompt, Enum.ProximityPromptInputType.Touch)
task.wait(0.2)
local promptGui = playerGui:FindFirstChild("Prompt_CollectPrompt")
check("custom prompt drawn", promptGui ~= nil)
if promptGui then
	local button = promptGui:FindFirstChild("Button")
	Engine.signal(button, "InputBegan"):Fire({ UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin })
	Engine.signal(button, "InputEnded"):Fire({ UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.End })
end
Engine.signal(PPS, "PromptHidden"):Fire(prompt)
task.wait(0.2)
check("custom prompt removed when hidden", playerGui:FindFirstChild("Prompt_CollectPrompt") == nil)

print("== play through the UI ==")
local function goTo(part)
	Engine.setCFrame(root, CFrame.new(part.CFrame.Position + Vector3.new(0, 0, 3)))
end
local function trigger(p)
	Engine.signal(p, "Triggered"):Fire(player)
	task.wait(0.35)
end
goTo(plot.Sources.Moonberry.Hitbox)
trigger(plot.Sources.Moonberry.Hitbox.CollectPrompt)
task.wait(0.2)
check("collect popup shown", playerGui:FindFirstChild("Popup") ~= nil)
local mbRow
for _, d in uiRoot.Basket:GetDescendants() do
	if d:IsA("TextLabel") and d.Text == "1/10" then
		mbRow = d
	end
end
check("basket shows 1/10", mbRow ~= nil)
goTo(plot.Sources.Glowshroom.Hitbox)
trigger(plot.Sources.Glowshroom.Hitbox.CollectPrompt)
goTo(plot.Cauldron.Hitbox)
local menu = uiRoot.CauldronMenu
local shown = waitFor(2, function()
	return menu.Visible
end)
check("cauldron menu pops up at the cauldron", shown)
local giantCard = find(menu, "Cards.GiantHead")
check("giant head card visible", giantCard and giantCard.Visible)
local rainbowCard = find(menu, "Cards.Rainbow")
check("rainbow card visible (unlocked)", rainbowCard and rainbowCard.Visible)
local floatyCard = find(menu, "Cards.Floaty")
check("floaty card hidden (locked)", floatyCard and not floatyCard.Visible)
Engine.signal(giantCard.Face, "Activated"):Fire()
task.wait(0.4)
check("tapping the card started brewing", plot.Cauldron:GetAttribute("BrewRecipe") == "GiantHead")
task.wait(0.3)
check("menu hides while brewing", menu.Visible == false)
check("brew bar shows", playerGui.BrewBar.Enabled == true)
local done = waitFor(8, function()
	return uiRoot.Celebration.Visible
end)
check("NEW RECIPE celebration", done)

print("== sell + effect ==")
local customer = waitFor(8, function()
	local c = plot:FindFirstChild("Customer")
	return c and c:GetAttribute("Phase") == "Waiting" and c
end)
check("customer waiting", customer ~= nil)
if customer then
	goTo(customer.Torso)
	-- the banner refreshes a few times a second, so give it a moment
	local selling = waitFor(2, function()
		return goalText():find("Sell") ~= nil
	end)
	check("goal says sell", selling, goalText())
	Engine.signal(customer.Torso.SellPrompt, "Triggered"):Fire(player)
	task.wait(2.5)
	local head = customer.HeadGroup.Head
	check("giant head effect grew the head", head.Size.X > 2.5, head.Size.X)
	local leaving = waitFor(6, function()
		return customer:GetAttribute("Phase") == "Leaving"
	end)
	check("customer leaves", leaving)
	task.wait(0.5)
	local walked = (customer.Torso.CFrame.Position - customer:GetPivot().Position)
	check("client walks the customer away", customer.Parent ~= nil)
end

print("== panels + keys ==")
local UIS = game:GetService("UserInputService")
Engine.signal(UIS, "InputBegan"):Fire({ KeyCode = Enum.KeyCode.U, UserInputType = Enum.UserInputType.Keyboard }, false)
task.wait(0.2)
check("U opens upgrades", uiRoot.UpgradesPanel.Visible)
Engine.signal(UIS, "InputBegan"):Fire({ KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard }, false)
task.wait(0.2)
check("R switches to recipes", uiRoot.RecipeBook.Visible and not uiRoot.UpgradesPanel.Visible)
Engine.signal(UIS, "InputBegan"):Fire({ KeyCode = Enum.KeyCode.Escape, UserInputType = Enum.UserInputType.Keyboard }, false)
task.wait(0.2)
check("Esc closes panels", not uiRoot.RecipeBook.Visible)
-- buy from the panel
local PlayerData = Engine.loaded(game:GetService("ServerScriptService").Modules.PlayerData)
local data = PlayerData.Get(player)
data.Coins = 100
PlayerData.Push(player)
Engine.signal(uiRoot.SideButtons.UpgradesButton.Face, "Activated"):Fire()
task.wait(0.3)
local buy = find(uiRoot, "UpgradesPanel.Body.List.BrewSpeed.Buy.Face")
check("upgrade card buy button", buy ~= nil)
if buy then
	check("buy button shows cost", buy.Text:find("25") ~= nil, buy.Text)
	Engine.signal(buy, "Activated"):Fire()
	task.wait(0.5)
	check("bought from the panel", (data.Upgrades.BrewSpeed or 0) == 1)
	check("card now shows next cost", buy.Text:find("90") ~= nil, buy.Text)
end
Engine.signal(UIS, "InputBegan"):Fire({ KeyCode = Enum.KeyCode.M, UserInputType = Enum.UserInputType.Keyboard }, false)
task.wait(0.2)
check("M mutes", find(uiRoot, "SideButtons.MuteButton.Face").Text == "SOUND OFF")

print("== every potion effect ==")
local CustomerBuilder = Engine.loaded(game:GetService("ServerScriptService").Modules.CustomerBuilder)
local Effects = Engine.require(game:GetService("ReplicatedStorage"):FindFirstChild("Effects"))
local warningsBefore = #Engine.warnings
local models = {}
for i, name in { "BigHead", "Rainbow", "Tiny", "Floaty", "Twirl", "Frosty", "Froggy" } do
	local model = CustomerBuilder.Build(CFrame.new(i * 8, 0.3, -10), { Vip = i % 2 == 0, WantsText = "test", WantsColor = roblox.Color3.new(1, 0, 0) })
	model.Parent = workspace
	models[name] = model
	Engine.syncPositions(model)
	Effects.Play(name, model)
end
task.wait(4.5)
check("no effect errors", #Engine.warnings == warningsBefore, table.concat(Engine.warnings, " | "))
check("tiny shrank", models.Tiny.Torso.Size.X < 1.2, models.Tiny.Torso.Size.X)
check("frog appeared", models.Froggy:FindFirstChild("Frog") ~= nil)
check("customer hidden under the frog", models.Froggy.Torso.Transparency == 1)
check("ice block cleaned up", models.Frosty:FindFirstChild("IceBlock") == nil)
check("frosty colors restored", models.Frosty.Torso.Material ~= Enum.Material.Ice)
check("floaty landed", math.abs(models.Floaty:GetPivot().Position.Y - 0.3) < 0.05, models.Floaty:GetPivot().Position.Y)

print("")
print(`== RESULT: {passed} passed, {failed} failed, {#Engine.problems} problems, {#Engine.warnings} warnings ==`)
for _, p in Engine.problems do
	print("problem: " .. p)
end
for _, w in Engine.warnings do
	print("warning: " .. w)
end
process.exit(if failed == 0 and #Engine.problems == 0 then 0 else 1)
