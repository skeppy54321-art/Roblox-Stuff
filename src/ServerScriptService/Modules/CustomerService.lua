-- CustomerService (ModuleScript) — ServerScriptService.Modules.CustomerService
-- One customer waits at each owned shop's counter. Selling gives coins,
-- then every client plays the funny effect, then a new customer arrives.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local ShopBuilder = require(Modules:WaitForChild("ShopBuilder"))

local CustomerService = {}

type Slot = { Token: number, State: "Empty" | "Waiting" | "Reacting", Model: Model?, Wants: string }
local slots: { [Model]: Slot } = {}

local sell -- forward declaration

local function despawn(slot: Slot)
	if slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
	end
	slot.State = "Empty"
end

local function spawnCustomer(plot: Model, slot: Slot)
	local spot = plot:FindFirstChild("CustomerSpot")
	if not spot or not spot:IsA("BasePart") then
		return
	end
	local wants = Config.PrototypeRecipe
	local recipe = Config.Recipes[wants]
	local model = ShopBuilder.BuildCustomer(spot.CFrame, `I want a {recipe.DisplayName}!`)
	model.Parent = plot
	slot.Model = model
	slot.Wants = wants
	slot.State = "Waiting"

	local prompt = model:FindFirstChild("SellPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			sell(player, plot, slot)
		end)
	end
end

-- Spawn a new customer after `delay` seconds, unless the plot was reset meanwhile.
local function scheduleSpawn(plot: Model, slot: Slot, delay: number)
	local token = slot.Token
	task.delay(delay, function()
		if slots[plot] == slot and slot.Token == token and slot.State == "Empty" then
			spawnCustomer(plot, slot)
		end
	end)
end

sell = function(player: Player, plot: Model, slot: Slot)
	if slot.State ~= "Waiting" or not slot.Model then
		return
	end
	if not Guard.Owns(player, plot) then
		return
	end
	if not Guard.Cooldown(player, "Sell", Config.Customers.SellCooldown) then
		return
	end
	if not Guard.Near(player, slot.Model.PrimaryPart) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local recipe = Config.Recipes[slot.Wants]
	if (data.Potions[slot.Wants] or 0) < 1 then
		Net.Notify(player, `You need a {recipe.DisplayName}. Brew one at the cauldron!`)
		return
	end

	-- All checks passed: change state immediately so a double-press can't sell twice.
	slot.State = "Reacting"
	data.Potions[slot.Wants] -= 1
	data.Coins += recipe.SellPrice
	data.Stats.PotionsSold += 1

	local model = slot.Model
	local prompt = model:FindFirstChild("SellPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	local text = model:FindFirstChild("Text", true)
	if text and text:IsA("TextLabel") then
		text.Text = "WHOA!!"
	end

	PlayerData.Push(player)
	Net.Notify(player, `+{recipe.SellPrice} coins!`)
	Net.PlayEffect:FireAllClients(model, recipe.Effect)

	local token = slot.Token
	task.delay(Config.Customers.EffectSeconds, function()
		if slots[plot] ~= slot or slot.Token ~= token then
			return
		end
		despawn(slot)
		scheduleSpawn(plot, slot, Config.Customers.RespawnSeconds)
	end)
end

-- Start customers at a plot (player got the plot).
function CustomerService.StartPlot(plot: Model)
	CustomerService.StopPlot(plot)
	local slot: Slot = { Token = 1, State = "Empty", Model = nil, Wants = Config.PrototypeRecipe }
	slots[plot] = slot
	scheduleSpawn(plot, slot, Config.Customers.FirstSpawnDelay)
end

-- Remove customers from a plot (player left).
function CustomerService.StopPlot(plot: Model)
	local slot = slots[plot]
	if slot then
		slot.Token += 1
		despawn(slot)
		slots[plot] = nil
	end
end

return CustomerService
