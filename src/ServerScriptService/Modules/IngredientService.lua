--!strict
-- IngredientService (ModuleScript) — ServerScriptService.Modules.IngredientService
-- Collecting ingredients from each shop's plants. Plants slowly regrow.
-- How many charges a plant holds and how fast it regrows depend on the owner's Green Thumb level.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local PlotService = require(Modules:WaitForChild("PlotService"))

type Plot = PlotService.Plot
type SourceState = {
	Model: Model,
	Plot: Plot,
	Ingredient: string,
	Hitbox: BasePart,
	Prompt: ProximityPrompt,
	Charges: number,
	MaxCharges: number,
	RegenSeconds: number,
	NextRegen: number,
}

local IngredientService = {}

local sources: { SourceState } = {}
local baseTransparency: { [BasePart]: number } = {}

-- Charges can be one part (a berry) or a model (a mushroom cap, a flower head).
local function setChargeVisible(charge: Instance, visible: boolean)
	local parts: { Instance } = if charge:IsA("BasePart") then { charge } else charge:GetDescendants()
	for _, part in parts do
		if part:IsA("BasePart") then
			if baseTransparency[part] == nil then
				baseTransparency[part] = part.Transparency
			end
			part.Transparency = if visible then baseTransparency[part] else 1
		end
	end
end

local function refresh(state: SourceState)
	for i = 1, Config.Tuning.Sources.ChargeSlots do
		local charge = state.Model:FindFirstChild("Charge" .. i)
		if charge then
			setChargeVisible(charge, i <= state.Charges)
		end
	end
	local name = Config.Ingredients[state.Ingredient].DisplayName
	state.Prompt.ObjectText = `{name}  ({state.Charges}/{state.MaxCharges})`
end

local function onCollect(player: Player, state: SourceState)
	if not Guard.Owns(player, state.Plot.Model) then
		return
	end
	if not Guard.Cooldown(player, "Collect", Config.Tuning.Sources.CollectCooldown) then
		return
	end
	if not Guard.Near(player, state.Hitbox) then
		return
	end
	local data = PlayerData.Get(player)
	if not data or not Config.IsIngredientUnlocked(data.Upgrades, state.Ingredient) then
		return
	end
	local name = Config.Ingredients[state.Ingredient].DisplayName
	if state.Charges <= 0 then
		Net.Notify(player, `The {name} is regrowing...`, "bad")
		return
	end
	local have = data.Ingredients[state.Ingredient] or 0
	if have >= Config.Tuning.Storage.MaxPerIngredient then
		Net.Notify(player, `Your {name} basket is full! Brew something first.`, "bad")
		return
	end

	-- All checks passed: change state (no yields between check and change).
	if state.Charges >= state.MaxCharges then
		state.NextRegen = os.clock() + state.RegenSeconds
	end
	state.Charges -= 1
	data.Ingredients[state.Ingredient] = have + 1
	refresh(state)
	PlayerData.Push(player)
	Net.Cue(player, "Collect", { Ingredient = state.Ingredient, Position = state.Hitbox.Position })
end

function IngredientService.Init(plots: { Plot })
	for _, plot in plots do
		for ingredientId, model in plot.Sources do
			local hitbox = model:FindFirstChild("Hitbox")
			local prompt = hitbox and hitbox:FindFirstChild("CollectPrompt")
			if not (hitbox and hitbox:IsA("BasePart") and prompt and prompt:IsA("ProximityPrompt")) then
				warn(`[IngredientService] {plot.Model.Name}.{ingredientId} has no Hitbox/CollectPrompt`)
				continue
			end
			local maxCharges, regenSeconds = Config.GetSourceStats(nil)
			local state: SourceState = {
				Model = model,
				Plot = plot,
				Ingredient = ingredientId,
				Hitbox = hitbox,
				Prompt = prompt,
				Charges = maxCharges,
				MaxCharges = maxCharges,
				RegenSeconds = regenSeconds,
				NextRegen = 0,
			}
			table.insert(sources, state)
			refresh(state)
			prompt.Triggered:Connect(function(player)
				onCollect(player, state)
			end)
		end
	end

	-- Regrow loop
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, state in sources do
				if state.Charges < state.MaxCharges and now >= state.NextRegen then
					state.Charges += 1
					state.NextRegen = now + state.RegenSeconds
					refresh(state)
				end
			end
		end
	end)
end

-- Applies the owner's Green Thumb level to a plot's plants (nil = no owner).
-- `refill` fills every plant up (used when a player gets the plot or leaves it).
function IngredientService.ApplyOwner(plot: Plot, upgrades: { [string]: number }?, refill: boolean)
	local maxCharges, regenSeconds = Config.GetSourceStats(upgrades)
	for _, state in sources do
		if state.Plot == plot then
			state.MaxCharges = maxCharges
			state.RegenSeconds = regenSeconds
			state.Charges = if refill then maxCharges else math.min(state.Charges, maxCharges)
			if state.Charges < maxCharges and state.NextRegen <= os.clock() then
				state.NextRegen = os.clock() + regenSeconds
			end
			refresh(state)
		end
	end
end

return IngredientService
