--!nocheck
-- server_test.luau: boots Brew a Potion's server from the built place file and plays a session.
-- Usage: lune run server_test.luau <place.rbxlx> <out_dir>

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local task = require("@lune/task")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Engine = require("./engine")

local PLACE, OUT = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(PLACE))
Engine.game = game
Engine.install(game, { client = false })

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
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
local function remoteCount(name, method)
	local n = 0
	for _, entry in Engine.log do
		if entry.remote == name and (method == nil or entry.method == method) then
			n += 1
		end
	end
	return n
end
local function lastRemote(name)
	for i = #Engine.log, 1, -1 do
		if Engine.log[i].remote == name then
			return Engine.log[i]
		end
	end
	return nil
end

-- Heartbeat for ProfileStore's autosave loop, and Position syncing for new/moved parts
task.spawn(function()
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

print("== boot ==")
Engine.run(game:GetService("ServerScriptService"):FindFirstChild("Main"))
local market = waitFor(5, function()
	return workspace:FindFirstChild("Market")
end)
check("Market folder exists", market ~= nil)
task.wait(0.5)
local plots = {}
for _, child in market:GetChildren() do
	if child:GetAttribute("IsPlot") then
		table.insert(plots, child)
	end
end
check("6 plots built", #plots == 6, #plots)
Engine.syncPositions(workspace)
local town = market:FindFirstChild("Town")
check("town built", town ~= nil)
local folk = town and town:FindFirstChild("Townsfolk")
check("6 townsfolk built", folk ~= nil and #folk:GetChildren() == 6, folk and #folk:GetChildren())
if folk then
	local quiet = true
	for _, d in folk:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			quiet = false
		end
	end
	check("townsfolk have no bubbles or prompts", quiet)
end
check("spawn exists", workspace:FindFirstChild("MarketSpawn") ~= nil)
local lighting = game:GetService("Lighting")
check("atmosphere set", lighting:FindFirstChildOfClass("Atmosphere") ~= nil)
check("clock time set", math.abs(lighting.ClockTime - 17.3) < 0.01, lighting.ClockTime)

-- world dump for the 3D preview
local parts, lights = Engine.dumpParts(workspace)
print(`  parts in world: {#parts}, lights: {#lights}`)
check("part count reasonable (< 6000)", #parts < 6000, #parts)
fs.writeFile(OUT .. "/parts.json", serde.encode("json", { parts = parts, lights = lights }))

print("== join ==")
local modules = game:GetService("ServerScriptService"):FindFirstChild("Modules")
local function newPlayer(name, userId)
	local player = roblox.Instance.new("Player")
	player.Name = name
	player.UserId = userId
	player.DisplayName = name
	player.Parent = Players
	Engine.signal(Players, "PlayerAdded"):Fire(player)
	local character = roblox.Instance.new("Model")
	character.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	Engine.setCFrame(root, CFrame.new(0, 3, -20))
	root.Parent = character
	character.PrimaryPart = root
	character.Parent = workspace
	player.Character = character
	Engine.signal(player, "CharacterAdded"):Fire(character)
	return player, root
end

local player, root = newPlayer("Tester", 1001)
local PlayerData = waitFor(3, function()
	return Engine.loaded(modules:FindFirstChild("PlayerData"))
end)
local data = waitFor(10, function()
	return PlayerData.Get(player)
end)
check("profile loaded", data ~= nil)
if not data then
	print("cannot continue without data")
	process.exit(1)
end
check("save mode attribute", player:GetAttribute("SaveMode") ~= nil, player:GetAttribute("SaveMode"))
local plotName = waitFor(2, function()
	return player:GetAttribute("PlotName")
end)
check("got a plot", plotName ~= nil)
local plot = market:FindFirstChild(plotName)
check("sign shows owner", (function()
	for _, d in plot:FindFirstChild("Sign"):GetDescendants() do
		if d:IsA("TextLabel") then
			return d.Text == "Tester's Potions"
		end
	end
	return false
end)())
task.wait(0.3)
check("moved into shop", (root.CFrame.Position - plot:FindFirstChild("SpawnPoint").CFrame.Position).Magnitude < 5, root.CFrame.Position)
check("starflower locked (not in shop)", plot.Sources:FindFirstChild("Starflower") == nil)
check("starflower lot shown", plot.Lots:FindFirstChild("StarflowerBedLot") ~= nil)
check("state pushed to client", remoteCount("StateUpdate") > 0)

local function goTo(part)
	Engine.setCFrame(root, CFrame.new(part.CFrame.Position + Vector3.new(0, 0, 3)))
end
local function trigger(prompt, who)
	Engine.signal(prompt, "Triggered"):Fire(who or player)
	task.wait(0.35) -- collect cooldown is 0.25s
end

print("== collect ==")
local bush = plot.Sources.Moonberry
goTo(bush.Hitbox)
trigger(bush.Hitbox.CollectPrompt)
check("collected a moonberry", (data.Ingredients.Moonberry or 0) == 1, data.Ingredients.Moonberry)
check("prompt text shows charges", bush.Hitbox.CollectPrompt.ObjectText:find("2/3") ~= nil, bush.Hitbox.CollectPrompt.ObjectText)
check("a berry disappeared", bush.Charge3.Transparency == 1 and bush.Charge1.Transparency == 0)
check("collect cue sent", remoteCount("Cue") > 0)
local shrooms = plot.Sources.Glowshroom
goTo(shrooms.Hitbox)
trigger(shrooms.Hitbox.CollectPrompt)
check("collected a glowshroom", (data.Ingredients.Glowshroom or 0) == 1)
-- too far away
Engine.setCFrame(root, CFrame.new(0, 5, 0))
trigger(shrooms.Hitbox.CollectPrompt)
check("far away collect rejected", data.Ingredients.Glowshroom == 1)
-- another player's prompt
local stranger = roblox.Instance.new("Player")
stranger.Name = "Stranger"
stranger.UserId = 2002
trigger(shrooms.Hitbox.CollectPrompt, stranger)
check("stranger can't collect", data.Ingredients.Glowshroom == 1)

print("== brew ==")
local cauldron = plot.Cauldron
goTo(cauldron.Hitbox)
task.wait(0.3)
check("suggested recipe set", cauldron:GetAttribute("SuggestedRecipe") == "GiantHead", cauldron:GetAttribute("SuggestedRecipe"))
check("prompt names suggestion", cauldron.Hitbox.BrewPrompt.ObjectText == "Giant Head Potion", cauldron.Hitbox.BrewPrompt.ObjectText)
trigger(cauldron.Hitbox.BrewPrompt)
check("brewing started", cauldron:GetAttribute("BrewRecipe") == "GiantHead")
check("ingredients taken", data.Ingredients.Moonberry == 0 and data.Ingredients.Glowshroom == 0)
check("liquid tinted", cauldron.Liquid.Color == roblox.Color3.fromRGB(255, 110, 200))
local endBefore = cauldron:GetAttribute("BrewEndTime")
trigger(cauldron.Hitbox.BrewPrompt)
check("stir moves end time earlier", cauldron:GetAttribute("BrewEndTime") < endBefore)
local brewed = waitFor(7, function()
	return (data.Potions.GiantHead or 0) == 1
end)
check("potion brewed", brewed)
check("discovered + bonus", data.Discovered.GiantHead == true and data.Coins == 10, data.Coins)
check("cauldron idle again", cauldron:GetAttribute("BrewRecipe") == "")
task.wait(0.1)
local slot1 = plot.Display.Slot1
check("potion shows on the counter", slot1.Body.Transparency == 0 and slot1.Body.Color == roblox.Color3.fromRGB(255, 110, 200))
check("only one bottle shows", plot.Display.Slot2.Body.Transparency == 1)

print("== customer ==")
local customer = waitFor(8, function()
	local c = plot:FindFirstChild("Customer")
	return c and c:GetAttribute("Phase") == "Waiting" and c
end)
check("customer arrived and waits", customer ~= nil)
if customer then
	check("first customer wants Giant Head", customer:GetAttribute("Wants") == "GiantHead", customer:GetAttribute("Wants"))
	check("walk-from on the plaza", typeof(customer:GetAttribute("WalkFrom")) == "Vector3")
	local sellPrompt = customer.Torso:FindFirstChild("SellPrompt")
	check("sell prompt exists", sellPrompt ~= nil)
	goTo(customer.Torso)
	Engine.signal(sellPrompt, "Triggered"):Fire(player)
	Engine.signal(sellPrompt, "Triggered"):Fire(player) -- double press
	task.wait(0.4)
	check("sold once for 10", data.Coins == 20 and data.Stats.PotionsSold == 1, `coins {data.Coins} sold {data.Stats.PotionsSold}`)
	check("sold bottle leaves the counter", plot.Display.Slot1.Body.Transparency == 1)
	check("effect fired to all", remoteCount("PlayEffect", "FireAllClients") == 1)
	check("customer reacting", customer:GetAttribute("Phase") == "Reacting")
	local left = waitFor(9, function()
		return customer.Parent == nil
	end)
	check("customer left and was removed", left)
	local next = waitFor(6, function()
		return plot:FindFirstChild("Customer")
	end)
	check("next customer came", next ~= nil)
end

print("== upgrades ==")
do
	local C = Engine.loaded(game:GetService("ReplicatedStorage").Config)
	local early = { BrewSpeed = 3, StarflowerBed = 1, Shelves = 2, GreenThumb = 2 }
	check("banner suggests a useful upgrade first", C.GetSuggestedUpgrade({}, 160) == "BrewSpeed")
	check("banner skips cosmetics while useful upgrades are left", C.GetSuggestedUpgrade(early, 160) == nil, C.GetSuggestedUpgrade(early, 160))
	local midway = { BrewSpeed = 2, StarflowerBed = 1, Shelves = 1, GreenThumb = 1, CounterSpace = 1 }
	check("banner saves up for the Frost Grotto before more boosts", C.GetSuggestedUpgrade(midway, 350) == nil and C.GetSuggestedUpgrade(midway, 400) == "FrostGrotto")
	local done = { BrewSpeed = 3, StarflowerBed = 1, Shelves = 2, GreenThumb = 2, CounterSpace = 1, FrostGrotto = 1, EmberGarden = 1, CloudGarden = 1 }
	check("banner suggests decor once nothing useful is left", C.GetSuggestedUpgrade(done, 160) == "CozyDecor")
end
local RequestUpgrade = game:GetService("ReplicatedStorage").Remotes.RequestUpgrade
local RequestBrew = game:GetService("ReplicatedStorage").Remotes.RequestBrew
Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, "BrewSpeed")
task.wait(0.5)
check("can't afford BrewSpeed at 20", (data.Upgrades.BrewSpeed or 0) == 0 and data.Coins == 20)
-- junk from a hacked client
for _, junk in { 123, "Nope", {}, "BrewSpeed\0", string.rep("x", 500) } do
	Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, junk)
	Engine.signal(RequestBrew, "OnServerEvent"):Fire(player, junk)
end
task.wait(0.6)
check("junk remotes ignored", data.Coins == 20)
data.Coins = 30000
Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, "FrostGrotto")
task.wait(0.5)
check("frost grotto needs starflower first", (data.Upgrades.FrostGrotto or 0) == 0)
local lot = plot.Lots:FindFirstChild("StarflowerBedLot")
goTo(lot.Hitbox)
trigger(lot.Hitbox.UnlockPrompt)
task.wait(0.2)
check("bought starflower bed from the lot", data.Upgrades.StarflowerBed == 1)
check("starflower planted", plot.Sources:FindFirstChild("Starflower") ~= nil)
check("lot hidden", plot.Lots:FindFirstChild("StarflowerBedLot") == nil)
Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, "CloudGarden")
task.wait(0.5)
check("cloud garden needs the ember garden first", (data.Upgrades.CloudGarden or 0) == 0)
for _, id in { "BrewSpeed", "BrewSpeed", "BrewSpeed", "Shelves", "Shelves", "GreenThumb", "GreenThumb", "CounterSpace", "FrostGrotto", "EmberGarden", "CloudGarden", "CozyDecor", "CozyDecor", "CozyDecor", "Familiar", "Familiar", "Familiar" } do
	Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, id)
	task.wait(0.45)
end
check("brew speed maxed", data.Upgrades.BrewSpeed == 3, data.Upgrades.BrewSpeed)
check("shelves 2", data.Upgrades.Shelves == 2)
check("green thumb 2", data.Upgrades.GreenThumb == 2)
check("counter space", data.Upgrades.CounterSpace == 1)
check("frost grotto", data.Upgrades.FrostGrotto == 1)
check("decor 3", data.Upgrades.CozyDecor == 3)
check("ember + cloud gardens", data.Upgrades.EmberGarden == 1 and data.Upgrades.CloudGarden == 1)
check("ember peppers planted", plot.Sources:FindFirstChild("EmberPepper") ~= nil and plot.Lots:FindFirstChild("EmberGardenLot") == nil)
check("cloud puffs floating", plot.Sources:FindFirstChild("CloudPuff") ~= nil and plot.Lots:FindFirstChild("CloudGardenLot") == nil)
check("coins spent exactly", data.Coins == 30000 - (25 + 90 + 300 + 80 + 250 + 120 + 350 + 200 + 400 + 900 + 2500 + 150 + 500 + 1500 + 1500 + 5000 + 15000 + 60), data.Coins)
check("baby dragon familiar", data.Upgrades.Familiar == 3 and player:GetAttribute("Familiar") == 3, player:GetAttribute("Familiar"))
Engine.signal(RequestUpgrade, "OnServerEvent"):Fire(player, "BrewSpeed")
task.wait(0.5)
check("maxed upgrade not charged", data.Upgrades.BrewSpeed == 3)
check("shelf 3 visible", plot:FindFirstChild("Shelf3") ~= nil)
check("golden decor visible", plot:FindFirstChild("DecorGold") ~= nil)
check("golden cauldron", cauldron.Belly.Material == roblox.Enum.Material.Foil)
check("fire color level 3", cauldron:FindFirstChild("Flame").Color == roblox.Color3.fromRGB(90, 255, 140))
check("green thumb gives 5 charges", plot.Sources.Moonberry.Hitbox.CollectPrompt.ObjectText:find("/5") ~= nil, plot.Sources.Moonberry.Hitbox.CollectPrompt.ObjectText)
local two = waitFor(8, function()
	local n = 0
	for _, c in plot:GetChildren() do
		if c.Name == "Customer" then
			n += 1
		end
	end
	return n >= 2
end)
check("second counter spot brings a 2nd customer", two)

do
	-- show a stocked counter in the preview, then put the stock back
	local stock = table.clone(data.Potions)
	data.Potions = { GiantHead = 2, Rainbow = 1, Tiny = 1, Floaty = 1, Twirly = 1, Frosty = 1, Froggy = 1, FireBreath = 1, Rocket = 1 }
	PlayerData.Push(player)
	task.wait(0.1)
	check("full counter display", plot.Display.Slot10.Body.Transparency == 0 and plot.Display.Slot11.Body.Transparency == 1)
	local upgradedParts, upgradedLights = Engine.dumpParts(workspace)
	data.Potions = stock
	PlayerData.Push(player)
	fs.writeFile(OUT .. "/parts_upgraded.json", serde.encode("json", { parts = upgradedParts, lights = upgradedLights, plot = plotName }))
	print(`  upgraded world dumped ({#upgradedParts} parts), owner plot {plotName}`)
end

print("== customers give up ==")
local Config = Engine.loaded(game:GetService("ReplicatedStorage").Config)
local function waitingCustomer(except)
	for _, c in plot:GetChildren() do
		if c.Name == "Customer" and c ~= except and c:GetAttribute("Phase") == "Waiting" then
			return c
		end
	end
	return nil
end
local stuckOne = waitFor(12, function()
	return waitingCustomer()
end)
check("a customer is waiting", stuckOne ~= nil)
if stuckOne then
	local wants = stuckOne:GetAttribute("Wants")
	local other = if wants == "Tiny" then "Rainbow" else "Tiny"
	local stock = table.clone(data.Potions)
	local before = {}
	for _, c in plot:GetChildren() do
		before[c] = true
	end
	data.Potions = { [other] = Config.GetMaxPotions(data.Upgrades) }
	PlayerData.Push(player)
	local gone = waitFor(10, function()
		return stuckOne:GetAttribute("Phase") == "Leaving"
	end)
	check("shelf full without their potion: they give up", gone)
	local said = stuckOne:FindFirstChild("Text", true)
	check("...and say so", said and said.Text == "Oh, you're all out!", said and said.Text)
	local fresh = waitFor(12, function()
		for _, c in plot:GetChildren() do
			if c.Name == "Customer" and not before[c] then -- came after the shelf filled up
				return c
			end
		end
		return nil
	end)
	check("the next customer wants what's on the shelf", fresh and fresh:GetAttribute("Wants") == other, fresh and fresh:GetAttribute("Wants"))
	data.Potions = stock
	PlayerData.Push(player)
end
-- patience runs out even when nothing is wrong
local patience = Config.Tuning.Customers.Patience
Config.Tuning.Customers.Patience = 2
local tired = waitFor(12, function()
	local c = waitingCustomer()
	return c and c:GetAttribute("Phase") == "Waiting" and c
end)
local left = tired and waitFor(6, function()
	return tired:GetAttribute("Phase") == "Leaving"
end)
check("customers stop waiting after a while", left)
check("...with a friendly goodbye", tired and tired:FindFirstChild("Text", true).Text == "Maybe next time!")
Config.Tuning.Customers.Patience = patience
-- some customers are kids (smaller, feet still on the ground)
local kidChance = Config.Tuning.Customers.KidChance
Config.Tuning.Customers.KidChance = 1
local seen = {}
for _, c in plot:GetChildren() do
	seen[c] = true
end
local kid = waitFor(15, function()
	for _, c in plot:GetChildren() do
		if c.Name == "Customer" and not seen[c] then
			return c
		end
	end
	return nil
end)
check("kid customers are smaller", kid and kid:GetAttribute("Kid") == true and math.abs(kid:GetScale() - Config.Tuning.Customers.KidScale) < 0.01, kid and kid:GetScale())
check("...and stand on the ground", kid and math.abs(kid:GetPivot().Position.Y - plot.CounterFront.CFrame.Position.Y) < 0.05)
Config.Tuning.Customers.KidChance = kidChance

print("== social ==")
local SocialService = Engine.loaded(modules.SocialService)
local function notesTo(who)
	local texts = {}
	for _, entry in Engine.log do
		if entry.remote == "Notify" and entry.player == who then
			table.insert(texts, { text = entry.args[1], kind = entry.args[2] })
		end
	end
	return texts
end
local function cuesTo(who, cueName)
	local n = 0
	for _, entry in Engine.log do
		if entry.remote == "Cue" and entry.player == who and entry.args[1] == cueName then
			n += 1
		end
	end
	return n
end
local stats = player:FindFirstChild("leaderstats")
check("leaderstats made", stats ~= nil and stats:FindFirstChild("Coins") ~= nil and stats:FindFirstChild("Sold") ~= nil)
if stats then
	check("leaderstats coins match", stats.Coins.Value == data.Coins, `{stats.Coins.Value} vs {data.Coins}`)
	check("leaderstats sold match", stats.Sold.Value == (data.Stats.PotionsSold or 0), stats.Sold.Value)
end

local friend, friendRoot = newPlayer("Friend", 2002)
local friendData = waitFor(10, function()
	return PlayerData.Get(friend)
end)
check("second player loaded", friendData ~= nil)
-- a brand-new player whose shelf is already full must still get a customer they can serve
friendData.Potions = { Rainbow = Config.GetMaxPotions(friendData.Upgrades) }
local friendPlot = market:FindFirstChild(friend:GetAttribute("PlotName") or "")
local firstVisitor = waitFor(6, function()
	return friendPlot and friendPlot:FindFirstChild("Customer")
end)
check("new player with a full shelf: first customer wants what's on it", firstVisitor and firstVisitor:GetAttribute("Wants") == "Rainbow", firstVisitor and firstVisitor:GetAttribute("Wants"))
friendData.Potions = {}
check("second player got another shop", friendPlot ~= nil and friendPlot ~= plot)
local myStand = plot.CheerStand
check("cheer stand names the owner", myStand.Hitbox.CheerPrompt.ObjectText == "Tester's shop", myStand.Hitbox.CheerPrompt.ObjectText)
check("empty shop's stand says so", market.Plot6.CheerStand.Hitbox.CheerPrompt.ObjectText == "Empty shop")

-- the owner can't cheer their own shop
goTo(myStand.Hitbox)
trigger(myStand.Hitbox.CheerPrompt, player)
check("can't cheer your own shop", (data.Stats.Cheers or 0) == 0, data.Stats.Cheers)
-- too far away
Engine.setCFrame(friendRoot, CFrame.new(0, 3, 0))
trigger(myStand.Hitbox.CheerPrompt, friend)
check("can't cheer from across the plaza", (data.Stats.Cheers or 0) == 0, data.Stats.Cheers)
-- the friend walks over and cheers
Engine.setCFrame(friendRoot, CFrame.new(myStand.Hitbox.CFrame.Position + Vector3.new(0, 0, 3)))
task.wait(1.1) -- cheer cooldown
Engine.signal(myStand.Hitbox.CheerPrompt, "Triggered"):Fire(friend)
task.wait(0.1)
check("cheer counted", (data.Stats.Cheers or 0) == 1, data.Stats.Cheers)
check("hearts burst", myStand.Burst.Hearts.Enabled == true)
check("stand shows the count", myStand.CountBoard:FindFirstChildWhichIsA("SurfaceGui", true).CountLabel.Text == "1 cheer")
check("owner told", cuesTo(player, "Cheered") == 1)
check("cheerer thanked", cuesTo(friend, "CheerSent") == 1)
task.wait(0.6)
check("hearts stop", myStand.Burst.Hearts.Enabled == false)
task.wait(0.6)
trigger(myStand.Hitbox.CheerPrompt, friend)
check("only one cheer per visit", (data.Stats.Cheers or 0) == 1, data.Stats.Cheers)
local friendNotes = notesTo(friend)
check("second cheer explained", #friendNotes > 0 and friendNotes[#friendNotes].text:find("already") ~= nil)

-- market news: the friend discovers a recipe, the tester hears about it
friendData.Ingredients.Moonberry = 1
friendData.Ingredients.Glowshroom = 1
Engine.setCFrame(friendRoot, CFrame.new(friendPlot.Cauldron.Hitbox.CFrame.Position + Vector3.new(0, 0, 3)))
Engine.signal(RequestBrew, "OnServerEvent"):Fire(friend, "GiantHead")
local heard = waitFor(9, function()
	for _, note in notesTo(player) do
		if note.kind == "news" and note.text:find("Friend discovered the Giant Head Potion") then
			return true
		end
	end
	return false
end)
check("market news reaches others", heard)
local selfNews = false
for _, note in notesTo(friend) do
	if note.kind == "news" then
		selfNews = true
	end
end
check("no news about yourself", not selfNews)

-- Market Stars board
SocialService.RedrawBoard()
local rowsFolder = town.MarketStars.StarsBoard.BoardGui.Page.Rows
check("board row 1 is the top earner", rowsFolder.Row1.Visible and rowsFolder.Row1.PlayerName.Text == "Tester", rowsFolder.Row1.PlayerName.Text)
check("board row 2 is the friend", rowsFolder.Row2.Visible and rowsFolder.Row2.PlayerName.Text == "Friend", rowsFolder.Row2.PlayerName.Text)
check("board shows recipes found", rowsFolder.Row2.RecipesValue.Text == "1/12", rowsFolder.Row2.RecipesValue.Text)
check("board shows cheers", rowsFolder.Row1.CheersValue.Text == "1", rowsFolder.Row1.CheersValue.Text)
check("unused rows hidden", not rowsFolder.Row3.Visible)
check("empty note hidden", not rowsFolder.Empty.Visible)
do -- for tests/preview/ui.html: the board is 11 x 7.2 studs at 50 pixels per stud
	local gui = town.MarketStars.StarsBoard.BoardGui
	fs.writeFile(OUT .. "/ui_board.json", serde.encode("json", { width = 550, height = 360, device = "surface", tree = Engine.dumpGui(gui) }))
end

-- the friend leaves
Engine.signal(Players, "PlayerRemoving"):Fire(friend)
task.wait(0.3)
friend.Parent = nil
SocialService.RedrawBoard()
check("board drops players who left", not rowsFolder.Row2.Visible and rowsFolder.Row1.PlayerName.Text == "Tester")
check("left shop's stand resets", friendPlot.CheerStand.Hitbox.CheerPrompt.ObjectText == "Empty shop")

print("== hall of fame ==")
do
	local FameService = Engine.loaded(modules.FameService)
	local fameRows = town.HallOfFame.FameBoard.BoardGui.Page.Rows
	local store = Engine.orderedStores.HallOfFame_CoinsEarned_v1
	check("friend's total saved when they left", store["2002"] ~= nil, store["2002"])
	table.clear(store) -- start from an empty hall
	FameService.Refresh()
	check("hall of fame starts empty", fameRows.Note.Visible and fameRows.Note.Text:find("first") ~= nil, fameRows.Note.Text)
	FameService.Save(player, data)
	check("coins earned saved to the ordered store", store and store["1001"] == data.Stats.CoinsEarned, store and store["1001"])
	store["999"] = 50000 -- someone from another server
	FameService.Refresh()
	check("top brewer first", fameRows.Row1.Visible and fameRows.Row1.PlayerName.Text == "User999" and fameRows.Row1.Coins.Text == "50,000", fameRows.Row1.PlayerName.Text)
	check("online players listed by display name", fameRows.Row2.PlayerName.Text == "Tester", fameRows.Row2.PlayerName.Text)
	check("note hidden once there are entries", not fameRows.Note.Visible)
	do -- for tests/preview/ui.html: 11 x 8.6 studs at 50 pixels per stud
		for i = 1, 6 do
			store[tostring(3000 + i)] = 40000 - i * 5500
		end
		FameService.Refresh()
		local gui = town.HallOfFame.FameBoard.BoardGui
		fs.writeFile(OUT .. "/ui_fame.json", serde.encode("json", { width = 550, height = 430, device = "surface", tree = Engine.dumpGui(gui) }))
	end
	Engine.orderedStoreFails = true
	FameService.Refresh()
	check("unpublished place: the board says so", fameRows.Note.Visible and fameRows.Note.Text:find("published") ~= nil)
	Engine.orderedStoreFails = false
	FameService.Refresh()
end

print("== daily gift ==")
local GiftService = Engine.loaded(modules.GiftService)
local ClaimDaily = game:GetService("ReplicatedStorage").Remotes.ClaimDaily
local realNow = GiftService.Now
local giftStart = data.Coins
local function claim(hoursLater)
	GiftService.Now = function()
		return realNow() + hoursLater * 3600
	end
	task.wait(1.05) -- the claim remote's cooldown
	Engine.signal(ClaimDaily, "OnServerEvent"):Fire(player)
	task.wait(0.15)
end
check("new players start with no streak", data.Daily and data.Daily.Last == 0 and data.Daily.Streak == 0)
claim(0)
check("first gift: day 1, +30", data.Coins == giftStart + 30 and data.Daily.Streak == 1, `{data.Coins - giftStart} day {data.Daily.Streak}`)
check("gift celebrated", cuesTo(player, "Daily") == 1)
claim(1)
check("can't claim twice in a day", data.Coins == giftStart + 30)
claim(21)
check("next day: day 2, +50", data.Coins == giftStart + 80 and data.Daily.Streak == 2, `{data.Coins - giftStart} day {data.Daily.Streak}`)
claim(21 + 20 + 60)
check("missing days resets the streak", data.Coins == giftStart + 110 and data.Daily.Streak == 1, `{data.Coins - giftStart} day {data.Daily.Streak}`)
GiftService.Now = realNow

print("== master brewer ==")
do
	local stock = table.clone(data.Potions)
	data.Potions = {}
	for _, id in Config.RecipeOrder do
		data.Discovered[id] = id ~= "Tiny" or nil
	end
	data.Ingredients.Glowshroom = 2
	goTo(cauldron.Hitbox)
	local mastersBefore = cuesTo(player, "Master")
	Engine.signal(RequestBrew, "OnServerEvent"):Fire(player, "Tiny")
	local mastered = waitFor(6, function()
		return cuesTo(player, "Master") > mastersBefore
	end)
	check("brewing the last new potion makes you a Master Brewer", mastered)
	local signText = plot.Sign:FindFirstChildWhichIsA("SurfaceGui", true):FindFirstChildWhichIsA("TextLabel").Text
	check("the sign says so", signText:find("Master Brewer") ~= nil, signText)
	SocialService.RedrawBoard()
	local firstRow = town.MarketStars.StarsBoard.BoardGui.Page.Rows.Row1.PlayerName
	check("gold name on the Market Stars board", firstRow.TextColor3 ~= Config.Palette.TextDark)
	data.Potions = stock
	PlayerData.Push(player)
end

print("== brew a specific recipe ==")
data.Ingredients.Starflower = 1
data.Ingredients.Glowshroom = 1
goTo(cauldron.Hitbox)
Engine.signal(RequestBrew, "OnServerEvent"):Fire(player, "Floaty")
task.wait(0.4)
check("floaty brewing", cauldron:GetAttribute("BrewRecipe") == "Floaty")
local floatyTime = cauldron:GetAttribute("BrewDuration")
check("floaty time uses level 3 speed", math.abs(floatyTime - 3) < 0.05, floatyTime)
Engine.signal(RequestBrew, "OnServerEvent"):Fire(player, "GiantHead")
task.wait(0.4)
check("can't start a second brew", cauldron:GetAttribute("BrewRecipe") == "Floaty")

print("== leave mid-brew ==")
local floatyBefore = data.Potions.Floaty or 0
Engine.signal(Players, "PlayerRemoving"):Fire(player)
task.wait(0.3)
player.Parent = nil
check("potion kept on leave", (data.Potions.Floaty or 0) == floatyBefore + 1, data.Potions.Floaty)
check("plot released", plot:GetAttribute("OwnerUserId") == 0)
check("customers removed", plot:FindFirstChild("Customer") == nil)
check("plot visuals reset", plot.Sources:FindFirstChild("Starflower") == nil and plot:FindFirstChild("DecorGold") == nil)
check("cauldron back to black", cauldron.Belly.Material == roblox.Enum.Material.Metal)
check("counter display emptied", plot.Display.Slot1.Body.Transparency == 1)
check("hall of fame saved on leave", Engine.orderedStores.HallOfFame_CoinsEarned_v1["1001"] == data.Stats.CoinsEarned)
local savedCoins = data.Coins
task.wait(1.5)

print("== rejoin (mock save) ==")
local player2, root2 = newPlayer("Tester", 1001)
local data2 = waitFor(10, function()
	return PlayerData.Get(player2)
end)
check("profile reloaded", data2 ~= nil)
if data2 then
	check("coins restored", data2.Coins == savedCoins, `{data2.Coins} vs {savedCoins}`)
	check("upgrades restored", data2.Upgrades.CozyDecor == 3)
	check("discoveries restored", data2.Discovered.GiantHead == true)
	check("daily streak restored", data2.Daily.Streak == 1 and data2.Daily.Last > 0)
	local plot2sign = market:FindFirstChild(player2:GetAttribute("PlotName")).Sign
	local signText2 = plot2sign:FindFirstChildWhichIsA("SurfaceGui", true):FindFirstChildWhichIsA("TextLabel").Text
	check("Master Brewer title back on the sign after rejoining", signText2:find("Master Brewer") ~= nil, signText2)
	local plot2 = market:FindFirstChild(player2:GetAttribute("PlotName"))
	task.wait(0.3)
	check("upgrades shown again", plot2 and plot2:FindFirstChild("DecorGold") ~= nil)
end

print("== rebirth ==")
if data2 then
	local plotB = market:FindFirstChild(player2:GetAttribute("PlotName"))
	local cauldronB = plotB.Cauldron
	Engine.setCFrame(root2, CFrame.new(cauldronB.Hitbox.CFrame.Position + Vector3.new(0, 0, 3)))
	local RequestRebirth = game:GetService("ReplicatedStorage").Remotes.RequestRebirth
	data2.Coins = 100
	Engine.signal(RequestRebirth, "OnServerEvent"):Fire(player2)
	task.wait(0.2)
	check("rebirth needs enough coins", (data2.Rebirths or 0) == 0 and data2.Coins == 100)
	task.wait(2.1) -- the rebirth remote's cooldown
	data2.Coins = 6000
	data2.Potions = { Rainbow = 2 }
	data2.Ingredients = { Moonberry = 3 }
	Engine.signal(RequestRebirth, "OnServerEvent"):Fire(player2)
	task.wait(0.3)
	check("rebirth happened", data2.Rebirths == 1, data2.Rebirths)
	check("coins, potions and ingredients start over", data2.Coins == 0 and next(data2.Potions) == nil and next(data2.Ingredients) == nil)
	check("useful upgrades reset, cosmetics kept", data2.Upgrades.CloudGarden == nil and data2.Upgrades.BrewSpeed == nil and data2.Upgrades.CozyDecor == 3 and data2.Upgrades.Familiar == 3)
	check("recipes kept", data2.Discovered.GiantHead == true and data2.Discovered.Rocket == true)
	check("the shop is back to basics", plotB.Sources:FindFirstChild("Starflower") == nil and plotB.Lots:FindFirstChild("StarflowerBedLot") ~= nil)
	local signB = plotB.Sign:FindFirstChildWhichIsA("SurfaceGui", true):FindFirstChildWhichIsA("TextLabel").Text
	check("the sign shows the rebirth", signB:find("Rebirth 1") ~= nil, signB)
	check("familiar kept", player2:GetAttribute("Familiar") == 3)
	-- sales now pay 25% more
	local waitingB = waitFor(10, function()
		for _, c in plotB:GetChildren() do
			if c.Name == "Customer" and c:GetAttribute("Phase") == "Waiting" then
				return c
			end
		end
		return nil
	end)
	check("customers come back after a rebirth", waitingB ~= nil)
	if waitingB then
		local wants = waitingB:GetAttribute("Wants")
		data2.Potions = { [wants] = 1 }
		local before = data2.Coins
		Engine.setCFrame(root2, CFrame.new(waitingB.Torso.CFrame.Position + Vector3.new(0, 0, 3)))
		task.wait(0.1)
		Engine.signal(waitingB.Torso.SellPrompt, "Triggered"):Fire(player2)
		task.wait(0.3)
		local price = Config.Recipes[wants].SellPrice
		local vip = waitingB:FindFirstChild("VipTag", true) ~= nil
		local expected = math.floor(price * (if vip then 2 else 1) * 1.25 + 0.5)
		check("sales pay 25% more after a rebirth", data2.Coins - before == expected, `{data2.Coins - before} vs {expected}`)
	end
end

print("")
print(`== RESULT: {passed} passed, {failed} failed, {#Engine.problems} problems, {#Engine.warnings} warnings ==`)
for _, p in Engine.problems do
	print("problem: " .. p)
end
process.exit(if failed == 0 and #Engine.problems == 0 then 0 else 1)
