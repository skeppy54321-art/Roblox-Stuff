--!strict
-- CustomerService (ModuleScript) — ServerScriptService.Modules.CustomerService
-- Customers walk from the plaza to each owned shop's counter and ask for one potion.
-- Selling gives coins, every client plays that potion's funny effect, then the
-- customer walks away and a new one comes.
--
-- The server only decides phases and times (attributes on the customer model);
-- each client animates the walking itself, so it is smooth and costs no network.
--   Phase       "Arriving" | "Waiting" | "Reacting" | "Leaving"
--   PhaseStart  server time the phase started   PhaseEnd  server time it ends
--   WalkFrom    Vector3 on the plaza where the walk starts/ends
--   Wants       recipe id

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local Kit = require(Modules:WaitForChild("Kit"))
local PlotService = require(Modules:WaitForChild("PlotService"))
local CustomerBuilder = require(Modules:WaitForChild("CustomerBuilder"))

type Plot = PlotService.Plot
type Phase = "Empty" | "Arriving" | "Waiting" | "Reacting" | "Leaving"
type Slot = {
	Index: number,
	Token: number, -- bumped to cancel anything scheduled for this slot
	Phase: Phase,
	Model: Model?,
	Wants: string,
	Vip: boolean,
	WaitingSince: number, -- server time they reached the counter
}
type Entry = { Owner: Player, Slots: { Slot } }

local T = Config.Tuning.Customers

local CustomerService = {}

local byPlot: { [Plot]: Entry } = {}
local listeners: { (Plot) -> () } = {}
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function changed(plot: Plot)
	for _, listener in listeners do
		task.spawn(listener, plot)
	end
end

-- Where slot `index` stands when the shop serves `count` customers at once (feet, facing the plaza).
local function spotFor(plot: Plot, index: number, count: number): CFrame
	local offset = if count <= 1 then 0 else (index - 1.5) * 8
	return plot.CounterFront.CFrame * CFrame.new(offset, 0, 0)
end

local function shelfFull(data: PlayerData.Data): boolean
	return Config.PotionTotal(data.Potions) >= Config.GetMaxPotions(data.Upgrades)
end

-- Which potion the next customer asks for.
local function pickWants(data: PlayerData.Data, taken: { [string]: boolean }): string
	if (data.Stats.PotionsSold or 0) == 0 and not taken.GiantHead then
		return "GiantHead" -- the very first customer asks for the first recipe
	end
	if shelfFull(data) then
		-- nothing more can be brewed: ask for something on the shelf, so the shop never gets stuck
		local onShelf = {}
		for _, id in Config.RecipeOrder do
			if (data.Potions[id] or 0) > 0 and not taken[id] then
				table.insert(onShelf, id)
			end
		end
		if #onShelf == 0 then
			for _, id in Config.RecipeOrder do
				if (data.Potions[id] or 0) > 0 then
					table.insert(onShelf, id)
				end
			end
		end
		if #onShelf > 0 then
			return onShelf[rng:NextInteger(1, #onShelf)]
		end
	end
	local unlocked, inStock = {}, {}
	for _, id in Config.RecipeOrder do
		if Config.IsRecipeUnlocked(data.Upgrades, id) and not taken[id] then
			table.insert(unlocked, id)
			if (data.Potions[id] or 0) > 0 then
				table.insert(inStock, id)
			end
		end
	end
	if #unlocked == 0 then
		for _, id in Config.RecipeOrder do
			if Config.IsRecipeUnlocked(data.Upgrades, id) then
				table.insert(unlocked, id)
			end
		end
	end
	if #inStock > 0 and rng:NextNumber() < T.StockBias then
		return inStock[rng:NextInteger(1, #inStock)]
	end
	return unlocked[rng:NextInteger(1, #unlocked)]
end

local scheduleSpawn -- forward declaration

local function setPhase(model: Model, phase: Phase, seconds: number)
	local start = now()
	model:SetAttribute("Phase", phase)
	model:SetAttribute("PhaseStart", start)
	model:SetAttribute("PhaseEnd", start + seconds)
end

local function walkSeconds(model: Model): number
	local from = model:GetAttribute("WalkFrom")
	if typeof(from) ~= "Vector3" then
		return 0
	end
	return (from - model:GetPivot().Position).Magnitude / T.WalkSpeed
end

local function leave(plot: Plot, slot: Slot, model: Model)
	local seconds = walkSeconds(model)
	slot.Phase = "Leaving"
	setPhase(model, "Leaving", seconds)
	changed(plot)
	local token = slot.Token
	task.delay(seconds, function()
		if slot.Token ~= token or slot.Model ~= model then
			return
		end
		model:Destroy()
		slot.Model = nil
		slot.Phase = "Empty"
		scheduleSpawn(plot, slot, T.RespawnSeconds)
	end)
end

local function sell(player: Player, plot: Plot, slot: Slot, model: Model)
	if slot.Model ~= model or slot.Phase ~= "Waiting" then
		return
	end
	if not Guard.Owns(player, plot.Model) then
		return
	end
	if not Guard.Cooldown(player, "Sell", T.SellCooldown) then
		return
	end
	local torso = model.PrimaryPart
	if not torso or not Guard.Near(player, torso) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local recipe = Config.Recipes[slot.Wants]
	local have = data.Potions[slot.Wants] or 0
	if have < 1 then
		Net.Notify(player, `They want a {recipe.DisplayName}. Brew one at your cauldron!`, "bad")
		return
	end

	-- All checks passed: change state immediately so a double-press can't sell twice.
	slot.Phase = "Reacting"
	local price = recipe.SellPrice * (if slot.Vip then T.VipPriceMultiplier else 1)
	data.Potions[slot.Wants] = have - 1
	data.Coins += price
	PlayerData.AddStat(data, "PotionsSold", 1)
	PlayerData.AddStat(data, "CoinsEarned", price)
	if slot.Vip then
		PlayerData.AddStat(data, "VipServed", 1)
	end

	local prompt = model:FindFirstChild("SellPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	local text = model:FindFirstChild("Text", true)
	if text and text:IsA("TextLabel") then
		text.Text = recipe.Reaction
	end
	setPhase(model, "Reacting", T.EffectSeconds)

	PlayerData.Push(player)
	Net.Cue(player, "Sale", { Recipe = slot.Wants, Amount = price, Vip = slot.Vip, Position = torso.Position })
	Net.PlayEffect:FireAllClients(model, recipe.Effect)
	changed(plot)

	local token = slot.Token
	task.delay(T.EffectSeconds, function()
		if slot.Token == token and slot.Model == model then
			leave(plot, slot, model)
		end
	end)
end

local function spawnCustomer(plot: Plot, entry: Entry, slot: Slot)
	local data = PlayerData.Get(entry.Owner)
	if not data then
		return
	end
	local taken: { [string]: boolean } = {}
	for _, other in entry.Slots do
		if other ~= slot and other.Phase ~= "Empty" then
			taken[other.Wants] = true
		end
	end
	local wants = pickWants(data, taken)
	local recipe = Config.Recipes[wants]
	local vip = (data.Stats.PotionsSold or 0) >= T.VipMinSales and rng:NextNumber() < T.VipChance
	local spot = spotFor(plot, slot.Index, #entry.Slots)
	local model = CustomerBuilder.Build(spot, {
		Vip = vip,
		WantsText = `I want a {recipe.DisplayName}!`,
		WantsColor = recipe.Color,
	})
	local start = (spot * CFrame.new(rng:NextNumber(-3, 3), 0, -T.WalkDistance)).Position
	model:SetAttribute("WalkFrom", Vector3.new(start.X, Config.World.GroundHeight + 0.3, start.Z))
	model:SetAttribute("Wants", wants)
	local seconds = walkSeconds(model)
	setPhase(model, "Arriving", seconds)
	model.Parent = plot.Model

	slot.Model = model
	slot.Wants = wants
	slot.Vip = vip
	slot.Phase = "Arriving"
	changed(plot)

	local token = slot.Token
	task.delay(seconds, function()
		if slot.Token ~= token or slot.Model ~= model or slot.Phase ~= "Arriving" then
			return
		end
		slot.Phase = "Waiting"
		slot.WaitingSince = now()
		setPhase(model, "Waiting", 0)
		local torso = model.PrimaryPart
		if torso then
			local objectText = if vip
				then `{recipe.DisplayName} (VIP pays x{T.VipPriceMultiplier}!)`
				else recipe.DisplayName
			local prompt = Kit.Prompt(torso, "SellPrompt", "Sell", objectText)
			prompt.Triggered:Connect(function(player)
				sell(player, plot, slot, model)
			end)
		end
		changed(plot)
	end)
end

-- Spawn a customer in `slot` after `delay` seconds, unless the plot was reset meanwhile.
scheduleSpawn = function(plot: Plot, slot: Slot, delay: number)
	local token = slot.Token
	task.delay(delay, function()
		local entry = byPlot[plot]
		if entry and slot.Token == token and slot.Phase == "Empty" and table.find(entry.Slots, slot) then
			spawnCustomer(plot, entry, slot)
		end
	end)
end

local function addSlot(plot: Plot, entry: Entry)
	local index = #entry.Slots + 1
	local slot: Slot =
		{ Index = index, Token = 1, Phase = "Empty", Model = nil, Wants = "", Vip = false, WaitingSince = 0 }
	table.insert(entry.Slots, slot)
	scheduleSpawn(plot, slot, T.FirstSpawnDelay + (index - 1) * 2.5)
end

-- Start customers at a plot (a player got it).
function CustomerService.StartPlot(plot: Plot, owner: Player)
	CustomerService.StopPlot(plot)
	local entry: Entry = { Owner = owner, Slots = {} }
	byPlot[plot] = entry
	local data = PlayerData.Get(owner)
	for _ = 1, Config.GetCustomerSlots(if data then data.Upgrades else nil) do
		addSlot(plot, entry)
	end
end

-- Add counter spots after the Second Counter Spot upgrade.
function CustomerService.UpdateSlots(plot: Plot, upgrades: { [string]: number })
	local entry = byPlot[plot]
	if not entry then
		return
	end
	while #entry.Slots < Config.GetCustomerSlots(upgrades) do
		addSlot(plot, entry)
	end
end

-- Remove all customers from a plot (its player left).
function CustomerService.StopPlot(plot: Plot)
	local entry = byPlot[plot]
	if not entry then
		return
	end
	byPlot[plot] = nil
	for _, slot in entry.Slots do
		slot.Token += 1
		if slot.Model then
			slot.Model:Destroy()
			slot.Model = nil
		end
		slot.Phase = "Empty"
	end
	changed(plot)
end

-- Potions the customers at this plot want (waiting ones first).
function CustomerService.GetWants(plot: Plot): { string }
	local wants = {}
	local entry = byPlot[plot]
	if entry then
		for _, phase in { "Waiting", "Arriving" } do
			for _, slot in entry.Slots do
				if slot.Phase == phase then
					table.insert(wants, slot.Wants)
				end
			end
		end
	end
	return wants
end

-- Called whenever a customer arrives, is served or leaves.
function CustomerService.OnChanged(listener: (Plot) -> ())
	table.insert(listeners, listener)
end

-- A customer who waited too long (or can't be served: the shelf is full and their potion
-- isn't on it) gives up and walks away, and a new one comes.
local function giveUp(plot: Plot, slot: Slot, model: Model, words: string)
	local prompt = model:FindFirstChild("SellPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	local text = model:FindFirstChild("Text", true)
	if text and text:IsA("TextLabel") then
		text.Text = words
	end
	leave(plot, slot, model)
end

local function checkPatience()
	local t = now()
	for plot, entry in byPlot do
		local data = PlayerData.Get(entry.Owner)
		for _, slot in entry.Slots do
			local model = slot.Model
			if slot.Phase == "Waiting" and model and data then
				local waited = t - slot.WaitingSince
				local stuck = shelfFull(data) and (data.Potions[slot.Wants] or 0) == 0
				if stuck and waited >= T.StuckPatience then
					giveUp(plot, slot, model, "Oh, you're all out!")
				elseif waited >= T.Patience then
					giveUp(plot, slot, model, "Maybe next time!")
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(function(): any
			checkPatience()
			return nil
		end)
		if not ok then
			warn("[CustomerService] patience check failed:", err)
		end
	end
end)

return CustomerService
