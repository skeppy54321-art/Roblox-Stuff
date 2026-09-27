--!strict
-- ClientMain (LocalScript) — StarterPlayer.StarterPlayerScripts.ClientMain
-- Builds the UI, hides other players' prompts, tells you the next thing to do,
-- plays sounds and cosmetic effects. It never changes coins or items itself:
-- every action is a request the server checks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Effects = require(ReplicatedStorage:WaitForChild("Effects"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Ui = require(script:WaitForChild("Ui"))
local Sfx = require(script:WaitForChild("Sfx"))
local Hud = require(script:WaitForChild("Hud"))
local UpgradesPanel = require(script:WaitForChild("UpgradesPanel"))
local RecipeBook = require(script:WaitForChild("RecipeBook"))
local CauldronMenu = require(script:WaitForChild("CauldronMenu"))
local CauldronFx = require(script:WaitForChild("CauldronFx"))
local PromptUi = require(script:WaitForChild("PromptUi"))
local Popups = require(script:WaitForChild("Popups"))
local GoalMarker = require(script:WaitForChild("GoalMarker"))
local CustomerAnimator = require(script:WaitForChild("CustomerAnimator"))
local Ambience = require(script:WaitForChild("Ambience"))
local DayCycle = require(script:WaitForChild("DayCycle"))
local Butterflies = require(script:WaitForChild("Butterflies"))
local Townsfolk = require(script:WaitForChild("Townsfolk"))
local Familiars = require(script:WaitForChild("Familiars"))
local Juice = require(script:WaitForChild("Juice"))

local StateUpdate = Remotes:WaitForChild("StateUpdate") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local Cue = Remotes:WaitForChild("Cue") :: RemoteEvent
local PlayEffect = Remotes:WaitForChild("PlayEffect") :: RemoteEvent
local RequestUpgrade = Remotes:WaitForChild("RequestUpgrade") :: RemoteEvent
local RequestBrew = Remotes:WaitForChild("RequestBrew") :: RemoteEvent
local GetState = Remotes:WaitForChild("GetState") :: RemoteFunction
local ClaimDaily = Remotes:WaitForChild("ClaimDaily") :: RemoteEvent
local RequestRebirth = Remotes:WaitForChild("RequestRebirth") :: RemoteEvent
local StudioCoins = Remotes:WaitForChild("StudioCoins") :: RemoteEvent
local RequestPaint = Remotes:WaitForChild("RequestPaint") :: RemoteEvent

local P = Config.Palette

local state: Config.State? = nil
local market = workspace:WaitForChild("Market")

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local screen = Ui.new("ScreenGui", {
	Name = "PotionHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	Parent = playerGui,
}) :: ScreenGui
local root = Ui.scaledRoot(screen)

Hud.Init(root)
UpgradesPanel.Init(root)
RecipeBook.Init(root)
CauldronMenu.Init(root)
CauldronFx.Init(playerGui)
Popups.Init(playerGui)
GoalMarker.Init(playerGui)
CustomerAnimator.Init()
Ambience.Init(market)
do -- the evening sky and the butterflies are only looks: a failure must never stop the game
	local ok, err = pcall(function(): any
		Butterflies.Init()
		DayCycle.Init(market)
		return nil
	end)
	if not ok then
		warn(`[ClientMain] evening sky disabled: {err}`)
	end
end
do -- pets are purely cosmetic: a failure here must never stop the game
	local ok, err = pcall(function(): any
		Familiars.Init()
		return nil
	end)
	if not ok then
		warn(`[ClientMain] familiars disabled: {err}`)
	end
end
task.spawn(function() -- waits for the villagers to replicate; purely cosmetic, so never fatal
	local ok, err = pcall(function(): any
		Townsfolk.Init(market)
		return nil
	end)
	if not ok then
		warn(`[ClientMain] townsfolk disabled: {err}`)
	end
end)

Effects.SetSoundPlayer(function(name, part)
	if part then
		Sfx.PlayAt(name, part)
	else
		Sfx.Play(name)
	end
end)
Sfx.Preload()
Sfx.StartMusic()
do -- the plaza fountain splashes quietly (you hear it more the closer you are)
	local town = market:WaitForChild("Town", 10)
	local fountain = town and town:FindFirstChild("Fountain")
	local basin = fountain and fountain:FindFirstChild("Basin")
	if basin and basin:IsA("BasePart") then
		Sfx.StartLoop("Fountain", "Fountain", basin)
	end
end

local function setPanel(which: string?)
	UpgradesPanel.SetOpen(which == "Upgrades")
	RecipeBook.SetOpen(which == "Recipes")
	if which then
		Sfx.Play("Open")
	end
end

local function toggleUpgrades()
	setPanel(if UpgradesPanel.IsOpen() then nil else "Upgrades")
end
local function toggleRecipes()
	setPanel(if RecipeBook.IsOpen() then nil else "Recipes")
end
local function toggleMute()
	Sfx.SetMuted(not Sfx.IsMuted())
	Hud.SetMuted(Sfx.IsMuted())
	Sfx.Play("Click")
end
Hud.OnUpgradesPressed = toggleUpgrades
Hud.OnRecipesPressed = toggleRecipes
Hud.OnMutePressed = toggleMute
Hud.OnGiftPressed = function()
	local s = state
	if not s then
		return
	end
	local ready, _, _, wait = Config.GetDailyGift(s.Daily, workspace:GetServerTimeNow())
	if ready then
		Sfx.Play("Click")
		ClaimDaily:FireServer()
	else
		Sfx.Play("Error")
		Hud.Toast(`Your next gift is ready in {Config.FormatDuration(wait)}.`, "info")
	end
end

-- Keep the gift button's badge and countdown current.
task.spawn(function()
	while true do
		local s = state
		if s then
			local ready, _, _, wait = Config.GetDailyGift(s.Daily, workspace:GetServerTimeNow())
			Hud.SetGift(ready, if ready then "GIFT" else Config.FormatDuration(wait))
		end
		task.wait(1)
	end
end)
UpgradesPanel.OnClose = function()
	setPanel(nil)
end
RecipeBook.OnClose = function()
	setPanel(nil)
end
if RunService:IsStudio() then -- testing aid; the server ignores it outside Studio too
	Hud.ShowStudioButton()
	Hud.OnStudioCoins = function()
		Sfx.Play("Coins")
		StudioCoins:FireServer()
	end
end
UpgradesPanel.OnPaint = function(themeIndex)
	Sfx.Play("Click")
	RequestPaint:FireServer(themeIndex)
end
UpgradesPanel.OnRebirth = function()
	Sfx.Play("Click")
	RequestRebirth:FireServer()
end
UpgradesPanel.OnBuy = function(upgradeId)
	Sfx.Play("Click")
	RequestUpgrade:FireServer(upgradeId)
end
CauldronMenu.OnBrew = function(recipeId)
	Sfx.Play("Click")
	RequestBrew:FireServer(recipeId)
end

------------------------------------------------------------------
-- Prompts: YOUR shop's prompts show, plus the Cheer stand on other players'
-- shops (prompts marked ForVisitors), all in the game's own style
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
		local owner = plot:GetAttribute("OwnerUserId")
		if prompt:GetAttribute("ForVisitors") then
			prompt.Enabled = typeof(owner) == "number" and owner ~= 0 and owner ~= player.UserId
		else
			prompt.Enabled = owner == player.UserId
		end
	end
end

local function adoptPrompt(prompt: ProximityPrompt)
	refreshPrompt(prompt)
	local ok, err = pcall(function(): any
		PromptUi.Adopt(prompt)
		return nil
	end)
	if not ok then
		warn(`[ClientMain] custom prompt failed, using default: {err}`)
	end
end

local okPromptUi, promptErr = pcall(function(): any
	PromptUi.Init(playerGui)
	return nil
end)
if not okPromptUi then
	warn(`[ClientMain] custom prompts disabled: {promptErr}`)
end

local function watchPlot(plot: Instance)
	if not plot:GetAttribute("IsPlot") then
		return
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, d in plot:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				refreshPrompt(d)
			end
		end
	end)
	CustomerAnimator.WatchPlot(plot)
end

for _, d in market:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		if okPromptUi then
			adoptPrompt(d)
		else
			refreshPrompt(d)
		end
	end
end
for _, plot in market:GetChildren() do
	watchPlot(plot)
end
market.ChildAdded:Connect(watchPlot)
market.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		if okPromptUi then
			adoptPrompt(d)
		else
			refreshPrompt(d)
		end
	end
end)

------------------------------------------------------------------
-- My shop
------------------------------------------------------------------
local function myPlot(): Instance?
	local plotName = player:GetAttribute("PlotName")
	return if typeof(plotName) == "string" then market:FindFirstChild(plotName) else nil
end

local function myCauldron(): Model?
	local plot = myPlot()
	local cauldron = plot and plot:FindFirstChild("Cauldron")
	return if cauldron and cauldron:IsA("Model") then cauldron else nil
end

local function isBrewing(cauldron: Model?): boolean
	local endTime = cauldron and cauldron:GetAttribute("BrewEndTime")
	return typeof(endTime) == "number" and endTime > workspace:GetServerTimeNow()
end

local function hitboxOf(model: Instance?): BasePart?
	local hitbox = model and model:FindFirstChild("Hitbox", true)
	return if hitbox and hitbox:IsA("BasePart") then hitbox else nil
end

type CustomerInfo = { Model: Model, Wants: string, Phase: string, Amount: number }

local function myCustomers(): { CustomerInfo }
	local list = {}
	local plot = myPlot()
	if plot then
		for _, child in plot:GetChildren() do
			if child.Name == "Customer" and child:IsA("Model") then
				local wants, phase = child:GetAttribute("Wants"), child:GetAttribute("Phase")
				local amount = child:GetAttribute("Amount")
				if typeof(wants) == "string" and typeof(phase) == "string" then
					local count = if typeof(amount) == "number" then amount else 1
					table.insert(list, { Model = child, Wants = wants, Phase = phase, Amount = count })
				end
			end
		end
	end
	return list
end

player:GetAttributeChangedSignal("PlotName"):Connect(function()
	CauldronFx.Watch(myCauldron())
end)
CauldronFx.Watch(myCauldron())
player:GetAttributeChangedSignal("SaveMode"):Connect(function()
	local mode = player:GetAttribute("SaveMode")
	Hud.SetSaveMode(if typeof(mode) == "string" then mode else nil)
end)

------------------------------------------------------------------
-- Goal banner + helper arrow: always the next thing to do
------------------------------------------------------------------
local function sourcePart(ingredientId: string): BasePart?
	local plot = myPlot()
	local sources = plot and plot:FindFirstChild("Sources")
	return hitboxOf(sources and sources:FindFirstChild(ingredientId))
end

------------------------------------------------------------------
-- Camera: once the server has moved you into your shop, look the way you're facing
-- (you'd otherwise keep the view from the plaza spawn, maybe facing a wall)
------------------------------------------------------------------
local function settleCamera(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	local deadline = os.clock() + 10
	while os.clock() < deadline and character.Parent do
		local plot = myPlot()
		local spawnPoint = if plot then plot:FindFirstChild("SpawnPoint") else nil
		if spawnPoint and spawnPoint:IsA("BasePart") and (rootPart.Position - spawnPoint.Position).Magnitude < 8 then
			local camera = workspace.CurrentCamera
			local look = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
			if camera and look.Magnitude > 0.01 then
				local focus = rootPart.Position + Vector3.new(0, 1.5, 0)
				camera.CFrame = CFrame.lookAt(focus - look.Unit * 12 + Vector3.new(0, 5, 0), focus + look.Unit * 3)
			end
			return
		end
		task.wait(0.1)
	end
end
player.CharacterAdded:Connect(function(character)
	task.spawn(settleCamera, character)
end)
if player.Character then
	task.spawn(settleCamera, player.Character)
end

-- A little bell rings when a customer reaches your counter (handy while you're out back).
local rung: { [Model]: boolean } = {}
local function ringForNewCustomers()
	for _, c in myCustomers() do
		if c.Phase == "Waiting" and not rung[c.Model] then
			rung[c.Model] = true
			local torso = c.Model.PrimaryPart
			if torso then
				Sfx.PlayAt("Bell", torso)
			end
		end
	end
	for model in rung do
		if not model.Parent then
			rung[model] = nil
		end
	end
end

-- A thin bar along the bottom of each waiting customer's bubble shows the patience they
-- have left (they give up at zero): green, then yellow, then red.
local function updatePatienceBars()
	local now = workspace:GetServerTimeNow()
	for _, c in myCustomers() do
		local limit = c.Model:GetAttribute("Patience")
		local patience = if typeof(limit) == "number" then limit else Config.Tuning.Customers.Patience
		local card = c.Model:FindFirstChild("Card", true)
		if c.Phase == "Waiting" and card and card:IsA("Frame") then
			local bar = card:FindFirstChild("Patience")
			if not bar then
				bar = Ui.new("Frame", {
					Name = "Patience",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -2),
					Size = UDim2.new(1, -24, 0, 5),
					BackgroundColor3 = P.PanelMid,
					BackgroundTransparency = 0.4,
					Parent = card,
				}, {
					Ui.round(),
					Ui.new(
						"Frame",
						{ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.Good },
						{ Ui.round() }
					),
				})
			end
			local start = c.Model:GetAttribute("PhaseStart")
			local left = if typeof(start) == "number" then math.clamp(1 - (now - start) / patience, 0, 1) else 1
			local fill = bar and bar:FindFirstChild("Fill")
			if fill and fill:IsA("Frame") then
				fill.Size = UDim2.fromScale(left, 1)
				fill.BackgroundColor3 = if left > 0.5 then P.Good elseif left > 0.2 then P.Gold else P.Danger
			end
		end
	end
end

-- Returns the goal text, and optionally a part to point the arrow at with a short label.
local function nextGoal(): (string, BasePart?, string?)
	local s = state
	if not s then
		return "Loading your shop...", nil, nil
	end
	local plot = myPlot()
	if not plot then
		return "The market is full. Try another server!", nil, nil
	end
	local cauldron = myCauldron()
	local customers = myCustomers()

	-- a waiting customer wants something you have: go sell it
	for _, c in customers do
		if c.Phase == "Waiting" and (s.Potions[c.Wants] or 0) >= c.Amount then
			local recipe = Config.Recipes[c.Wants]
			local what = if c.Amount > 1 then `{c.Amount} {recipe.DisplayName}s` else `the {recipe.DisplayName}`
			return `Sell {what} to your customer!`, c.Model.PrimaryPart, "Sell!"
		end
	end
	if isBrewing(cauldron) then
		return "Brewing! Press the cauldron to STIR, or grab more ingredients.", nil, nil
	end
	-- something worth buying (after your first sale)
	if (s.Stats.PotionsSold or 0) > 0 then
		local upgradeId = Config.GetSuggestedUpgrade(s.Upgrades, s.Coins, s.Rebirths)
		if upgradeId then
			return `You can afford {Config.Upgrades[upgradeId].DisplayName}! Tap UPGRADES.`, nil, nil
		end
		if Config.CanRebirth(s) then
			local bonus = math.floor(Config.Tuning.Rebirth.CoinBonus * 100)
			return `You can REBIRTH for +{bonus}% coins forever! Tap UPGRADES.`, nil, nil
		end
	end
	if Config.PotionTotal(s.Potions) >= Config.GetMaxPotions(s.Upgrades) then
		return "Your shelf is full! Wait for a customer who wants one of your potions.", nil, nil
	end
	-- work toward what a customer wants (or the first recipe if nobody is here yet)
	local target = Config.RecipeOrder[1]
	for _, c in customers do
		if (s.Potions[c.Wants] or 0) < c.Amount then
			target = c.Wants
			break
		end
	end
	local recipe = Config.Recipes[target]
	if Config.HasIngredientsFor(s.Ingredients, target) then
		return `Brew a {recipe.DisplayName} at your cauldron!`, hitboxOf(cauldron), "Brew!"
	end
	for _, ingredientId in Config.IngredientOrder do
		local need = recipe.Ingredients[ingredientId] or 0
		if (s.Ingredients[ingredientId] or 0) < need then
			local info = Config.Ingredients[ingredientId]
			return `Collect a {info.DisplayName} from {info.Where}.`, sourcePart(ingredientId), "Collect!"
		end
	end
	return "Brew a potion at your cauldron!", hitboxOf(cauldron), "Brew!"
end

task.spawn(function()
	local warned = false
	while true do
		-- one bad frame must never freeze the goal banner for the rest of the session
		local ok, err = pcall(function()
			ringForNewCustomers()
			updatePatienceBars()
			local text, part, label = nextGoal()
			Hud.SetGoal(text)
			local s = state
			local guiding = s ~= nil and (s.Stats.PotionsSold or 0) < Config.Tuning.GuideUntilSales
			GoalMarker.Set(if guiding then part else nil, label)
		end)
		if not ok and not warned then
			warned = true
			warn(`[ClientMain] goal update failed: {err}`)
		end
		task.wait(0.25)
	end
end)

------------------------------------------------------------------
-- Cauldron menu: shows while you stand at your own idle cauldron
------------------------------------------------------------------
local MENU_RANGE = Config.Tuning.PromptDistance + 3
local menuElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	menuElapsed += dt
	if menuElapsed < 0.1 then
		return
	end
	menuElapsed = 0
	local cauldron = myCauldron()
	local hitbox = hitboxOf(cauldron)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local near = hitbox ~= nil
		and rootPart ~= nil
		and rootPart:IsA("BasePart")
		and (rootPart.Position - hitbox.Position).Magnitude <= MENU_RANGE
	local modalOpen = UpgradesPanel.IsOpen() or RecipeBook.IsOpen()
	local s = state
	local canBrewSomething = false
	if s and Config.PotionTotal(s.Potions) < Config.GetMaxPotions(s.Upgrades) then
		for _, recipeId in Config.RecipeOrder do
			if Config.IsRecipeUnlocked(s.Upgrades, recipeId) and Config.HasIngredientsFor(s.Ingredients, recipeId) then
				canBrewSomething = true
				break
			end
		end
	end
	-- only when there's a real choice to make (the goal banner explains everything else)
	local show = near and not modalOpen and not isBrewing(cauldron) and canBrewSomething
	if show and cauldron then
		local wants = {}
		for _, c in myCustomers() do
			table.insert(wants, c.Wants)
		end
		local suggested = cauldron:GetAttribute("SuggestedRecipe")
		CauldronMenu.Update(true, state, wants, if typeof(suggested) == "string" then suggested else "")
	else
		CauldronMenu.Update(false, nil, {}, "")
	end
end)

------------------------------------------------------------------
-- Keyboard shortcuts (phones use the buttons)
------------------------------------------------------------------
local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.U then
		toggleUpgrades()
	elseif key == Enum.KeyCode.R then
		toggleRecipes()
	elseif key == Enum.KeyCode.M then
		toggleMute()
	elseif key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB then
		setPanel(nil)
	elseif NUMBER_KEYS[key] then
		local recipeId = CauldronMenu.GetRecipeAt(NUMBER_KEYS[key])
		if recipeId and CauldronMenu.OnBrew then
			CauldronMenu.OnBrew(recipeId)
		end
	end
end)

------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------
local function applyState(newState: Config.State)
	state = newState
	Hud.SetState(newState)
	UpgradesPanel.SetState(newState)
	RecipeBook.SetState(newState)
	-- the swatch to outline: your pick, or your shop's own colors
	local plot = myPlot()
	local default = if plot then plot:GetAttribute("DefaultTheme") else nil
	local theme = if (newState.Theme or 0) > 0 then newState.Theme else default
	UpgradesPanel.SetTheme(if typeof(theme) == "number" then theme else 0)
end

StateUpdate.OnClientEvent:Connect(function(newState)
	if typeof(newState) == "table" then
		applyState(newState)
	end
end)

Notify.OnClientEvent:Connect(function(text, kind)
	if typeof(text) ~= "string" then
		return
	end
	local k = if typeof(kind) == "string" then kind else "info"
	Hud.Toast(text, k)
	if k == "bad" then
		Sfx.Play("Error")
	elseif k == "news" then
		Sfx.Play("News")
	end
end)

Cue.OnClientEvent:Connect(function(cue, data)
	if typeof(cue) ~= "string" or typeof(data) ~= "table" then
		return
	end
	if cue == "Collect" then
		local info = Config.Ingredients[data.Ingredient]
		Sfx.Play("Collect", 0.9 + math.random() * 0.25)
		if info and typeof(data.Position) == "Vector3" then
			Popups.Show(data.Position + Vector3.new(0, 2, 0), `+1 {info.DisplayName}`, info.Color)
		end
	elseif cue == "BrewStart" then
		Sfx.Play("Plop")
	elseif cue == "Stir" then
		Sfx.Play("Stir", 1 + (tonumber(data.Stirs) or 0) * 0.1)
	elseif cue == "PotionReady" then
		Sfx.Play("PotionReady")
		local recipe = Config.Recipes[data.Recipe]
		if recipe then
			CauldronFx.Pop(recipe.Color)
		end
		local hitbox = hitboxOf(myCauldron())
		if recipe and hitbox then
			Popups.Show(hitbox.Position + Vector3.new(0, 4, 0), `{recipe.DisplayName}!`, recipe.Color)
		end
	elseif cue == "Discover" then
		Sfx.Play("Discover")
		local recipe = Config.Recipes[data.Recipe]
		if recipe then
			CauldronFx.Pop(recipe.Color)
			Hud.Celebrate("NEW RECIPE!", `{recipe.DisplayName}  +{tonumber(data.Bonus) or 0} coins`, recipe.Color)
		end
	elseif cue == "Sale" then
		Sfx.Play("Coins", if data.Vip then 1.2 else 1)
		if typeof(data.Position) == "Vector3" then
			local text = if data.Vip then `VIP! +{data.Amount}` else `+{data.Amount}`
			Popups.Show(data.Position + Vector3.new(0, 3, 0), text, P.Gold, true)
			local tip = tonumber(data.Tip) or 0
			if tip > 0 then
				task.delay(0.35, function()
					Popups.Show(data.Position + Vector3.new(1.5, 4.5, 0), `Speedy! +{tip} tip`, P.Good, true)
				end)
			end
			local camera = workspace.CurrentCamera
			if camera then
				local point, onScreen = camera:WorldToScreenPoint(data.Position + Vector3.new(0, 2, 0))
				if onScreen then
					Hud.FlyCoins(
						Vector2.new(point.X, point.Y),
						(tonumber(data.Amount) or 10) + (tonumber(data.Tip) or 0)
					)
				end
			end
		end
	elseif cue == "Cheered" then
		Sfx.Play("Cheer")
		Hud.Toast(`{tostring(data.From)} cheered for your shop!`, "heart")
	elseif cue == "CheerSent" then
		Sfx.Play("Cheer", 1.15)
		Hud.Toast(`You cheered for {tostring(data.To)}'s shop!`, "heart")
	elseif cue == "Master" then
		task.delay(3.2, function() -- after the NEW RECIPE banner
			Sfx.Play("Upgrade")
			Hud.Celebrate("MASTER BREWER!", "You've brewed every potion!", P.Gold)
		end)
	elseif cue == "Rebirth" then
		Sfx.Play("Discover")
		local multiplier = tonumber(data.Multiplier) or 1
		Hud.Celebrate("REBIRTH!", `Fresh start, now x{string.format("%g", multiplier)} coins forever!`, P.Gold)
		setPanel(nil)
		-- golden sparkles all over the shop as it starts over
		local plot = myPlot()
		local floor = if plot and plot:IsA("Model") then plot.PrimaryPart else nil
		if floor then
			local center = floor.CFrame
			for _, offset in
				{ Vector3.new(0, 4, 1), Vector3.new(-9, 3, 5), Vector3.new(9, 3, 5), Vector3.new(0, 5, -8) }
			do
				Juice.Sparkle((center * CFrame.new(offset)).Position, P.Gold, 35)
			end
		end
	elseif cue == "Paint" then
		Sfx.Play("Open", 1.3)
		local plot = myPlot()
		local floor = if plot and plot:IsA("Model") then plot.PrimaryPart else nil
		local theme = P.Awnings[tonumber(data.Theme) or 1]
		if floor and theme then
			Juice.Sparkle((floor.CFrame * CFrame.new(0, 10, -9)).Position, theme[1], 30)
		end
	elseif cue == "Daily" then
		Sfx.Play("Discover")
		Hud.Celebrate("DAILY GIFT!", `Day {tonumber(data.Day) or 1}: +{tonumber(data.Amount) or 0} coins`, P.Gold)
	elseif cue == "Upgrade" then
		Sfx.Play("Upgrade")
		local upgrade = Config.Upgrades[data.Upgrade]
		if upgrade then
			UpgradesPanel.Flash(data.Upgrade)
			local level = tonumber(data.Level) or 1
			local entry = Config.GetLevelEntry(data.Upgrade, level)
			Hud.Celebrate("UPGRADE!", if entry then entry.Summary else upgrade.DisplayName, upgrade.Color)
			-- a newly planted garden grows up out of the ground; anything else sparkles
			local plot = myPlot()
			local sources = if plot then plot:FindFirstChild("Sources") else nil
			local planted = if upgrade.Unlocks and sources then sources:FindFirstChild(upgrade.Unlocks) else nil
			local box = if planted then planted:FindFirstChild("Hitbox") else nil
			if planted and planted:IsA("Model") and box and box:IsA("BasePart") then
				local center = box.CFrame.Position
				Juice.GrowIn(planted, center - Vector3.new(0, box.Size.Y / 2, 0))
				Juice.Sparkle(center, upgrade.Color, 40)
			else
				local cauldronBox = hitboxOf(myCauldron())
				if cauldronBox then
					Juice.Sparkle(cauldronBox.CFrame.Position + Vector3.new(0, 2, 0), upgrade.Color, 30)
				end
			end
		end
	end
end)

PlayEffect.OnClientEvent:Connect(function(model, effectName)
	if typeof(model) == "Instance" and model:IsA("Model") then
		CustomerAnimator.Freeze(model) -- rest pose first, so the effect starts from a clean pose
	end
	Effects.Play(effectName, model)
end)

-- First load (in case the first StateUpdate arrived before we were listening)
task.spawn(function()
	while not state do
		local ok, result = pcall(function()
			return GetState:InvokeServer()
		end)
		if ok and typeof(result) == "table" and not state then
			applyState(result)
		end
		if not state then
			task.wait(0.5)
		end
	end
	local mode = player:GetAttribute("SaveMode")
	Hud.SetSaveMode(if typeof(mode) == "string" then mode else nil)
	-- a brand-new shopkeeper gets a short welcome (it never blocks anything)
	local s = state
	if s and (s.Stats.PotionsBrewed or 0) == 0 and (s.Stats.PotionsSold or 0) == 0 and myPlot() then
		task.wait(1)
		Sfx.Play("Open")
		Hud.Celebrate("WELCOME!", "This potion shop is all yours!", P.Gold)
	end
end)
