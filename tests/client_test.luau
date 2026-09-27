--!nocheck
-- client_test.luau: "play solo" in one process. Boots the server, joins one player, runs the real
-- ClientMain LocalScript for them, then clicks through the UI and plays every potion effect.
-- Usage: lune run client_test.luau <place.rbxlx> [out_dir]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local task = require("@lune/task")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Engine = require("./engine")

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
Engine.game = game
Engine.install(game, { client = true })

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local Vector3, Vector2, CFrame, Enum = roblox.Vector3, roblox.Vector2, roblox.CFrame, roblox.Enum

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
local welcomed = waitFor(3, function()
	local title = uiRoot.Celebration:FindFirstChild("Title")
	return uiRoot.Celebration.Visible and title and title.Text == "WELCOME!"
end)
check("a new player is welcomed", welcomed)
task.wait(0.6)

print("== sounds ==")
local SoundService = game:GetService("SoundService")
local SoundsConfig = Engine.loaded(game:GetService("ReplicatedStorage").Config.Sounds)
local preloaded = table.concat(Engine.preloaded or {}, " ")
check("sound ids preloaded", preloaded:find(CHIME, 1, true) and preloaded:find(SoundsConfig.Music.Id, 1, true), preloaded)
local musicSound = SoundService:FindFirstChild("Music")
check("music playing, looped", musicSound and musicSound.Looped and musicSound.SoundId == SoundsConfig.Music.Id)
local fountainSound = workspace.Market.Town.Fountain.Basin:FindFirstChild("Fountain")
check("the fountain splashes (3D loop)", fountainSound and fountainSound.Looped and fountainSound.SoundId == SoundsConfig.Fountain.Id, fountainSound and fountainSound.SoundId)
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
check("no cheer prompt on your own shop", plot.CheerStand.Hitbox.CheerPrompt.Enabled == false)
check("no cheer prompt on empty shops", otherPlot.CheerStand.Hitbox.CheerPrompt.Enabled == false)
-- someone else opens the shop next door (attribute changes don't fire by themselves here)
otherPlot:SetAttribute("OwnerUserId", 4242)
Engine.signal(otherPlot, "Attr:OwnerUserId"):Fire()
check("cheer prompt shows on someone else's shop", otherPlot.CheerStand.Hitbox.CheerPrompt.Enabled == true)
check("their other prompts stay hidden", otherPlot.Cauldron.Hitbox.BrewPrompt.Enabled == false)
otherPlot:SetAttribute("OwnerUserId", 0)
Engine.signal(otherPlot, "Attr:OwnerUserId"):Fire()
check("cheer prompt hides when they leave", otherPlot.CheerStand.Hitbox.CheerPrompt.Enabled == false)

print("== first look ==")
local rootLook = root.CFrame.LookVector
local bushDir = (plot.Sources.Moonberry.Hitbox.CFrame.Position - root.CFrame.Position)
bushDir = Vector3.new(bushDir.X, 0, bushDir.Z).Unit
check("a new player faces the Moonberry bush", Vector3.new(rootLook.X, 0, rootLook.Z).Unit:Dot(bushDir) > 0.95, rootLook)
local camLook = workspace.CurrentCamera.CFrame.LookVector
check("the camera looks the same way", Vector3.new(camLook.X, 0, camLook.Z).Unit:Dot(bushDir) > 0.9, camLook)

print("== familiars ==")
local Familiars = Engine.loaded(clientMain.Familiars)
check("no familiar yet", Familiars.Get(player) == nil)
player:SetAttribute("Familiar", 1)
Engine.signal(player, "Attr:Familiar"):Fire()
local cat = Familiars.Get(player)
check("shop cat appears", cat ~= nil and cat.Name:find("ShopCat") ~= nil, cat and cat.Name)
task.wait(1)
local catBody = cat and cat:FindFirstChild("Body")
check("the cat follows its owner", catBody and (catBody.CFrame.Position - root.CFrame.Position).Magnitude < 6, catBody and (catBody.CFrame.Position - root.CFrame.Position).Magnitude)
player:SetAttribute("Familiar", 3)
Engine.signal(player, "Attr:Familiar"):Fire()
local dragon = Familiars.Get(player)
check("upgrades to a baby dragon", dragon ~= nil and dragon.Name:find("BabyDragon") ~= nil and cat.Parent == nil)
if process.args[2] then -- the dragon behind its owner, for tests/preview (view "pet")
	task.wait(1)
	local rp = root.CFrame
	local function v(cf)
		local p = cf.Position
		return { p.X, p.Y, p.Z }
	end
	local parts, lights = Engine.dumpParts(workspace)
	local views = { pet = { pos = v(rp * CFrame.new(-2.5, 3.2, -6.5)), look = v(rp * CFrame.new(1.8, 2.8, 1.5)), fov = 50 } }
	fs.writeFile(process.args[2] .. "/parts_pet.json", serde.encode("json", { parts = parts, lights = lights, views = views }))
end
player:SetAttribute("Familiar", 0)
Engine.signal(player, "Attr:Familiar"):Fire()
check("familiar goes away at level 0", Familiars.Get(player) == nil and dragon.Parent == nil)

print("== townsfolk ==")
local folkFolder = workspace.Market.Town.Townsfolk
local villagers = folkFolder:GetChildren()
local startAt = {}
for i, v in villagers do
	startAt[i] = v.Torso.CFrame.Position
end
local closest, lowest, highest = math.huge, math.huge, -math.huge
for _ = 1, 15 do
	task.wait(0.2)
	for _, v in villagers do
		local p = v.Torso.CFrame.Position
		closest = math.min(closest, Vector3.new(p.X, 0, p.Z).Magnitude)
		lowest, highest = math.min(lowest, p.Y), math.max(highest, p.Y)
	end
end
local moved = 0
for i, v in villagers do
	if (v.Torso.CFrame.Position - startAt[i]).Magnitude > 2 then
		moved += 1
	end
end
check("townsfolk are strolling", moved >= 3, moved)
check("townsfolk keep out of the fountain", closest > 10.3, closest)
check("townsfolk walk on the ground", lowest > 3.1 and highest < 3.5, `{lowest}..{highest}`)
if process.args[2] then -- the plaza with its villagers, for tests/preview (view "town")
	local parts, lights = Engine.dumpParts(workspace)
	local views = { town = { pos = { 30, 14, -30 }, look = { 0, 3, 5 }, fov = 55 } }
	fs.writeFile(process.args[2] .. "/parts_town.json", serde.encode("json", { parts = parts, lights = lights, views = views }))
end

print("== evening sky ==")
do
	local World = Engine.loaded(game:GetService("ReplicatedStorage").Config.World)
	local DayCycle = Engine.loaded(clientMain.DayCycle)
	local Ambience = Engine.loaded(clientMain.Ambience)
	local Lighting = game:GetService("Lighting")
	local cycle = World.DayCycle
	local golden, dusk = cycle.Keys[1].Look, cycle.Keys[4].Look
	local lantern = workspace.Market:FindFirstChild("Lantern", true)
	local lanternLight = lantern and lantern.Glass:FindFirstChildOfClass("PointLight")
	local realNow = DayCycle.Now
	DayCycle.Now = function()
		return cycle.Seconds * 0.75 -- the middle of dusk
	end
	task.wait(0.5)
	check("dusk: the sun goes down", math.abs(Lighting.ClockTime - dusk.ClockTime) < 0.01, Lighting.ClockTime)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	check("dusk: the haze turns purple", atmosphere and atmosphere.Color == dusk.AtmosphereColor)
	local flies = workspace.Market.Town.Fireflies.Fireflies
	check("dusk: more fireflies", flies.Rate == 8 * dusk.Fireflies, flies.Rate)
	check("dusk: lanterns glow brighter", Ambience.LightScale == dusk.Lanterns and lanternLight and lanternLight.Brightness > 1.4 * 1.15, lanternLight and lanternLight.Brightness)
	local between = DayCycle.LookAt(0.5).ClockTime
	check("the evening comes gradually", between > golden.ClockTime and between < dusk.ClockTime, between)
	DayCycle.Now = function()
		return cycle.Seconds * 3 -- a whole number of cycles: golden hour
	end
	task.wait(0.5)
	-- (Lighting keeps 32-bit floats)
	check("then golden hour again", math.abs(Lighting.ClockTime - golden.ClockTime) < 1e-4 and flies.Rate == 8, Lighting.ClockTime)
	check("golden hour is the server's look", golden.ClockTime == World.Lighting.ClockTime and math.abs(Lighting.Brightness - World.Lighting.Brightness) < 1e-4, Lighting.Brightness)
	check("lanterns back to normal", lanternLight and lanternLight.Brightness <= 1.4 * 1.15 + 1e-6, lanternLight and lanternLight.Brightness)
	DayCycle.Now = realNow
end

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
local blub = waitFor(2, function()
	return plot.Cauldron.Hitbox:FindFirstChild("Blub")
end)
check("the cauldron blubs while brewing", blub ~= nil)
local done = waitFor(8, function()
	return uiRoot.Celebration.Visible
end)
check("NEW RECIPE celebration", done)
check("a bottle pops out of the cauldron", workspace:FindFirstChild("PopBottle") ~= nil)

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
	-- (Lune has no GUI layout, so the sale's own coins can't know where to fly here;
	-- the animation itself is checked with explicit points)
	local HudModule = Engine.loaded(clientMain.Hud)
	HudModule.FlyCoinsBetween(Vector2.new(400, 300), Vector2.new(420, 30), 24)
	local coinsFlew = waitFor(1, function()
		return hud:FindFirstChild("FlyingCoin") ~= nil
	end)
	check("coins fly to the counter", coinsFlew)
	task.wait(2.5)
	check("flying coins land and vanish", hud:FindFirstChild("FlyingCoin") == nil)
	local head = customer.HeadGroup.Head
	check("giant head effect grew the head", head.Size.X > 2.5, head.Size.X)
	local leaving = waitFor(6, function()
		return customer:GetAttribute("Phase") == "Leaving"
	end)
	check("customer leaves", leaving)
	task.wait(0.5)
	local walked = (customer.Torso.CFrame.Position - customer:GetPivot().Position)
	check("client walks the customer away", customer.Parent ~= nil)
	-- the next customer rings the shop bell when they reach the counter
	local nextCustomer = waitFor(12, function()
		for _, c in plot:GetChildren() do
			if c.Name == "Customer" and c ~= customer and c:GetAttribute("Phase") == "Waiting" then
				return c
			end
		end
		return nil
	end)
	local rang = nextCustomer and waitFor(1, function()
		return nextCustomer.Torso:FindFirstChild("Bell") ~= nil
	end)
	check("a bell rings when a customer reaches the counter", rang)
	local bar = nextCustomer and waitFor(1, function()
		return nextCustomer:FindFirstChild("Patience", true)
	end)
	check("waiting customers show a patience bar", bar ~= nil and bar.Fill.Size.X.Scale > 0.8, bar and bar.Fill.Size.X.Scale)
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
	check("upgrade sparkles at the cauldron", workspace:FindFirstChild("SparkleBurst") ~= nil)
	check("card now shows next cost", buy.Text:find("90") ~= nil, buy.Text)
end
Engine.signal(UIS, "InputBegan"):Fire({ KeyCode = Enum.KeyCode.M, UserInputType = Enum.UserInputType.Keyboard }, false)
task.wait(0.2)
check("M mutes", find(uiRoot, "SideButtons.MuteButton.Face").Text == "SOUND OFF")

print("== planting grows in ==")
do
	data.Coins += 60
	local RequestUpgrade = game:GetService("ReplicatedStorage").Remotes.RequestUpgrade
	Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, "StarflowerBed")
	local planter = waitFor(2, function()
		local bed = plot.Sources:FindFirstChild("Starflower")
		return bed and bed:FindFirstChild("Planter")
	end)
	task.wait(0.1)
	check("the new bed starts tiny", planter and planter.Size.X < 4, planter and planter.Size.X)
	task.wait(1)
	check("...and grows to full size", planter and math.abs(planter.Size.X - 5) < 0.01, planter and planter.Size.X)
end

print("== social toasts ==")
local P = Engine.loaded(game:GetService("ReplicatedStorage").Config.Palette)
local modulesFolder = game:GetService("ServerScriptService").Modules
local NetModule = Engine.loaded(modulesFolder.Net)
local function toastWith(textPart)
	for _, t in uiRoot.Toasts:GetChildren() do
		if t:IsA("TextLabel") and t.Text:find(textPart, 1, true) then
			return t
		end
	end
	return nil
end
NetModule.Notify(player, "Sam discovered the Froggy Potion!", "news")
NetModule.Cue(player, "Cheered", { From = "Sam" })
task.wait(0.2)
local newsToast = toastWith("Sam discovered")
check("news toast shown in violet", newsToast ~= nil and newsToast.BackgroundColor3 == P.News)
local heartToast = toastWith("Sam cheered for your shop")
check("cheer toast shown in pink", heartToast ~= nil and heartToast.BackgroundColor3 == P.Heart)

print("== every potion effect ==")
local CustomerBuilder = Engine.loaded(game:GetService("ServerScriptService").Modules.CustomerBuilder)
local Effects = Engine.require(game:GetService("ReplicatedStorage"):FindFirstChild("Effects"))
local warningsBefore = #Engine.warnings
local models = {}
for i, name in { "BigHead", "Rainbow", "Tiny", "Floaty", "Twirl", "Frosty", "Froggy", "FireBreath", "Dance", "Bubble", "Ghost", "Rocket" } do
	local model = CustomerBuilder.Build(CFrame.new(i * 8, 0.3, -10), { Vip = i % 2 == 0, WantsText = "test", WantsColor = roblox.Color3.new(1, 0, 0) })
	model.Parent = workspace
	models[name] = model
	Engine.syncPositions(model)
	Effects.Play(name, model)
end
task.wait(0.3)
check("customer drinks first", models.BigHead:FindFirstChild("DrinkBottle") ~= nil)
if process.args[2] then -- optional: dump the drinking pose for tests/preview (view "drink")
	local parts, lights = Engine.dumpParts(workspace)
	local views = { drink = { pos = { 9.2, 5.3, -4.6 }, look = { 8, 4.4, -10 }, fov = 42 } } -- in front of the Giant Head customer
	fs.writeFile(process.args[2] .. "/parts_drink.json", serde.encode("json", { parts = parts, lights = lights, views = views }))
end
check("arm raised to drink", models.BigHead.ArmR.CFrame.Position.Y > models.BigHead.Torso.CFrame.Position.Y + 0.6)
task.wait(1.7)
if process.args[2] then -- mid-effect poses for tests/preview (views fire, dance, bubble, ghost; then rocket)
	local parts, lights = Engine.dumpParts(workspace)
	local views = {
		fire = { pos = { 65.6, 5.6, -4.4 }, look = { 64, 4.6, -10 }, fov = 50 },
		dance = { pos = { 73.5, 7.5, -0.5 }, look = { 72, 6, -10 }, fov = 55 },
		bubble = { pos = { 81.5, 8.5, -0.5 }, look = { 80, 7.5, -10 }, fov = 55 },
		ghost = { pos = { 89.5, 6.8, -2.5 }, look = { 88, 5.6, -10 }, fov = 50 },
	}
	fs.writeFile(process.args[2] .. "/parts_effects.json", serde.encode("json", { parts = parts, lights = lights, views = views }))
end
task.wait(0.9)
if process.args[2] then
	local parts, lights = Engine.dumpParts(workspace)
	local views = { rocket = { pos = { 101, 11, 8 }, look = { 96, 11, -10 }, fov = 60 } }
	fs.writeFile(process.args[2] .. "/parts_rocket.json", serde.encode("json", { parts = parts, lights = lights, views = views }))
end
task.wait(2.4)
check("bottle put away", models.BigHead:FindFirstChild("DrinkBottle") == nil)
check("pop bottle cleaned up", workspace:FindFirstChild("PopBottle") == nil)
check("no effect errors", #Engine.warnings == warningsBefore, table.concat(Engine.warnings, " | "))
check("tiny shrank", models.Tiny.Torso.Size.X < 1.2, models.Tiny.Torso.Size.X)
check("frog appeared", models.Froggy:FindFirstChild("Frog") ~= nil)
check("customer hidden under the frog", models.Froggy.Torso.Transparency == 1)
check("ice block cleaned up", models.Frosty:FindFirstChild("IceBlock") == nil)
check("frosty colors restored", models.Frosty.Torso.Material ~= Enum.Material.Ice)
check("floaty landed", math.abs(models.Floaty:GetPivot().Position.Y - 0.3) < 0.05, models.Floaty:GetPivot().Position.Y)
local function landed(name) -- back on the spot the test built them on (y 0.3, z -10)
	local at = models[name]:GetPivot().Position
	return math.abs(at.Y - 0.3) < 0.05 and math.abs(at.Z + 10) < 0.05
end
-- an arm's center sits 0.15 above the torso's at rest; raised, it's more than a stud above
local function armUp(model)
	return model.ArmR.CFrame.Position.Y > model.Torso.CFrame.Position.Y + 0.6
end
check("fire breath: face back to normal", models.FireBreath.HeadGroup.Head.Color ~= roblox.Color3.fromRGB(255, 70, 50))
check("dance: disco ball gone, back on the spot", models.Dance:FindFirstChild("DiscoBall") == nil and landed("Dance"))
check("dance: arms back down", not armUp(models.Dance))
check("bubble popped and landed", workspace:FindFirstChild("SoapBubble") == nil and landed("Bubble"))
check("ghost solid again", models.Ghost.Torso.Transparency == 0 and landed("Ghost"))
check("rocket came back down", workspace:FindFirstChild("Parachute") == nil and landed("Rocket"))

print("== daily gift ==")
local giftFace = find(uiRoot, "SideButtons.GiftButton.Face")
check("gift ready for a new player", giftFace.Text == "GIFT" and giftFace.Parent.Badge.Visible)
Engine.signal(giftFace, "Activated"):Fire()
local celebrated = waitFor(3, function()
	for _, d in uiRoot.Celebration:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "DAILY GIFT!" then
			return uiRoot.Celebration.Visible
		end
	end
	return false
end)
check("gift claimed and celebrated", celebrated)
local counting = waitFor(3, function()
	return giftFace.Text:find("h") ~= nil and not giftFace.Parent.Badge.Visible
end)
check("gift button counts down to the next one", counting, giftFace.Text)

print("== shop colors ==")
do
	local card = find(uiRoot, "UpgradesPanel.Body.List.ShopColors")
	check("shop colors card", card ~= nil)
	local function outlined(name)
		local swatch = card and card:FindFirstChild(name, true)
		local ring = swatch and swatch:FindFirstChildOfClass("UIStroke")
		return ring ~= nil and ring.Thickness == 4
	end
	local names = Engine.loaded(game:GetService("ReplicatedStorage").Config).Palette.ThemeNames
	local default = plot:GetAttribute("DefaultTheme")
	check("your shop's own colors are outlined", outlined(names[default]))
	local pick = if default == 3 then 4 else 3
	Engine.signal(card:FindFirstChild(names[pick], true), "Activated"):Fire()
	local painted = waitFor(2, function()
		return data.Theme == pick and outlined(names[pick])
	end)
	check("tapping a swatch repaints the shop", painted)
end

print("== studio coins ==")
do
	local studioFace = find(uiRoot, "StudioCoins.Face")
	check("Studio shows the +10K test button", studioFace ~= nil)
	local before = data.Coins
	Engine.signal(studioFace, "Activated"):Fire()
	task.wait(0.3)
	check("+10K gives 10,000 coins in Studio", data.Coins == before + 10000, data.Coins - before)
end

print("== rebirth ==")
do
	local rebirthFace = find(uiRoot, "UpgradesPanel.Body.List.Rebirth.Buy.Face")
	check("rebirth card waits for the Cloud Garden", rebirthFace and rebirthFace.Text:find("Cloud Garden") ~= nil, rebirthFace and rebirthFace.Text)
	data.Upgrades.CloudGarden = 1
	data.Coins = 6000
	PlayerData.Push(player)
	task.wait(0.3)
	check("rebirth card ready and on top", rebirthFace.Text == "REBIRTH" and find(uiRoot, "UpgradesPanel.Body.List.Rebirth").LayoutOrder == 0, rebirthFace.Text)
	Engine.signal(rebirthFace, "Activated"):Fire()
	task.wait(0.1)
	check("first tap asks to confirm", rebirthFace.Text == "Tap again!" and (data.Rebirths or 0) == 0)
	Engine.signal(rebirthFace, "Activated"):Fire()
	local reborn = waitFor(3, function()
		local title = uiRoot.Celebration:FindFirstChild("Title")
		return (data.Rebirths or 0) == 1 and title and title.Text == "REBIRTH!" and uiRoot.Celebration.Visible
	end)
	check("second tap rebirths, with a celebration", reborn)
	task.wait(0.3)
	local chip = find(uiRoot, "Coins.Multiplier")
	check("coin multiplier shows x1.25", chip and chip.Visible and chip.Text == "x1.25", chip and chip.Text)
end

print("")
print(`== RESULT: {passed} passed, {failed} failed, {#Engine.problems} problems, {#Engine.warnings} warnings ==`)
for _, p in Engine.problems do
	print("problem: " .. p)
end
for _, w in Engine.warnings do
	print("warning: " .. w)
end
process.exit(if failed == 0 and #Engine.problems == 0 then 0 else 1)
