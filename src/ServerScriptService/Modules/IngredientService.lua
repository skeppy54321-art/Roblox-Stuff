-- IngredientService (ModuleScript) — ServerScriptService.Modules.IngredientService
-- Collecting ingredients from the bush / mushroom patch. Sources slowly regrow.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))

local IngredientService = {}

type SourceState = { Model: Model, Plot: Model, Ingredient: string, Charges: number, NextRegen: number }
local sources: { SourceState } = {}

local function refresh(state: SourceState)
	for i = 1, Config.Sources.MaxCharges do
		local charge = state.Model:FindFirstChild("Charge" .. i)
		if charge and charge:IsA("BasePart") then
			charge.Transparency = if i <= state.Charges then 0 else 1
		end
	end
	local hitbox = state.Model:FindFirstChild("Hitbox")
	local prompt = hitbox and hitbox:FindFirstChild("CollectPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		local name = Config.Ingredients[state.Ingredient].DisplayName
		prompt.ObjectText = `{name}  ({state.Charges}/{Config.Sources.MaxCharges})`
	end
end

local function onCollect(player: Player, state: SourceState)
	if not Guard.Owns(player, state.Plot) then
		return
	end
	if not Guard.Cooldown(player, "Collect", Config.Sources.CollectCooldown) then
		return
	end
	local hitbox = state.Model:FindFirstChild("Hitbox") :: BasePart?
	if not Guard.Near(player, hitbox) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local name = Config.Ingredients[state.Ingredient].DisplayName
	if state.Charges <= 0 then
		Net.Notify(player, `The {name} is regrowing...`)
		return
	end
	local have = data.Ingredients[state.Ingredient] or 0
	if have >= Config.Storage.MaxPerIngredient then
		Net.Notify(player, `Your {name} storage is full!`)
		return
	end

	-- All checks passed: change state (no yields between check and change).
	if state.Charges == Config.Sources.MaxCharges then
		state.NextRegen = os.clock() + Config.Sources.RegenSeconds
	end
	state.Charges -= 1
	data.Ingredients[state.Ingredient] = have + 1
	refresh(state)
	PlayerData.Push(player)
	Net.Notify(player, `+1 {name}`)
end

function IngredientService.Init(plots: { Model })
	for _, plot in plots do
		local folder = plot:FindFirstChild("Sources")
		if not folder then
			continue
		end
		for _, model in folder:GetChildren() do
			local ingredient = model:GetAttribute("Ingredient")
			if not model:IsA("Model") or typeof(ingredient) ~= "string" or not Config.Ingredients[ingredient] then
				continue
			end
			local state: SourceState = {
				Model = model,
				Plot = plot,
				Ingredient = ingredient,
				Charges = Config.Sources.MaxCharges,
				NextRegen = 0,
			}
			table.insert(sources, state)
			refresh(state)
			local prompt = model:FindFirstChild("CollectPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function(player)
					onCollect(player, state)
				end)
			end
		end
	end

	-- Regrow loop
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, state in sources do
				if state.Charges < Config.Sources.MaxCharges and now >= state.NextRegen then
					state.Charges += 1
					state.NextRegen = now + Config.Sources.RegenSeconds
					refresh(state)
				end
			end
		end
	end)
end

-- Refill a plot's sources (used when a player leaves).
function IngredientService.ResetPlot(plot: Model)
	for _, state in sources do
		if state.Plot == plot then
			state.Charges = Config.Sources.MaxCharges
			refresh(state)
		end
	end
end

return IngredientService
