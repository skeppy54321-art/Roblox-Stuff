--!strict
-- Config (ModuleScript) — ReplicatedStorage.Config
-- One place for every tunable number and name. Server AND client read it.
-- The numbers live in the child modules. This module adds the shared rules
-- (what is unlocked, what can be brewed, what an upgrade costs) so the server
-- and the UI always agree. The server is still the one that decides.

local Tuning = require(script:WaitForChild("Tuning"))
local Ingredients = require(script:WaitForChild("Ingredients"))
local Recipes = require(script:WaitForChild("Recipes"))
local Upgrades = require(script:WaitForChild("Upgrades"))
local Palette = require(script:WaitForChild("Palette"))
local Sounds = require(script:WaitForChild("Sounds"))
local World = require(script:WaitForChild("World"))

export type Ingredient = Ingredients.Ingredient
export type Recipe = Recipes.Recipe
export type Upgrade = Upgrades.Upgrade
export type UpgradeLevel = Upgrades.UpgradeLevel
export type SoundDef = Sounds.SoundDef

-- Player progress. The server owns it, saves it, and sends a copy to the client.
export type State = {
	SchemaVersion: number,
	Coins: number,
	Ingredients: { [string]: number },
	Potions: { [string]: number },
	Upgrades: { [string]: number },
	Discovered: { [string]: boolean },
	Stats: { [string]: number },
	Daily: DailyState,
}

-- The daily gift: when it was last claimed (Unix seconds) and how many days in a row.
export type DailyState = { Last: number, Streak: number }

type Levels = { [string]: number }?

local Config = {}

Config.Tuning = Tuning
Config.Ingredients = Ingredients
Config.Recipes = Recipes
Config.Upgrades = Upgrades
Config.Palette = Palette
Config.Sounds = Sounds
Config.World = World

local function sortedIds<T>(map: { [string]: T }, getOrder: (T) -> number): { string }
	local ids = {}
	for id in map do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return getOrder(map[a]) < getOrder(map[b])
	end)
	return ids
end

Config.IngredientOrder = sortedIds(Ingredients, function(ingredient: Ingredient)
	return ingredient.Order
end)
Config.RecipeOrder = sortedIds(Recipes, function(recipe: Recipe)
	return recipe.Order
end)
Config.UpgradeOrder = sortedIds(Upgrades, function(upgrade: Upgrade)
	return upgrade.Order
end)

------------------------------------------------------------------
-- Upgrade levels
------------------------------------------------------------------

-- Current level of an upgrade (0 = not bought).
function Config.GetLevel(upgrades: Levels, upgradeId: string): number
	local level = if upgrades then upgrades[upgradeId] else nil
	return if typeof(level) == "number" then level else 0
end

-- The level entry that is active at `level`, or nil at level 0.
function Config.GetLevelEntry(upgradeId: string, level: number): UpgradeLevel?
	local upgrade = Upgrades[upgradeId]
	if not upgrade or level <= 0 then
		return nil
	end
	return upgrade.Levels[math.min(level, #upgrade.Levels)]
end

function Config.GetMaxLevel(upgradeId: string): number
	local upgrade = Upgrades[upgradeId]
	return if upgrade then #upgrade.Levels else 0
end

-- Cost of the next level, or nil if maxed (or unknown).
function Config.GetNextUpgradeCost(upgradeId: string, level: number): number?
	local upgrade = Upgrades[upgradeId]
	local nextLevel = if upgrade then upgrade.Levels[level + 1] else nil
	return if nextLevel then nextLevel.Cost else nil
end

-- Has the upgrade this one depends on been bought?
function Config.IsUpgradeAvailable(upgrades: Levels, upgradeId: string): boolean
	local upgrade = Upgrades[upgradeId]
	if not upgrade then
		return false
	end
	return upgrade.Requires == nil or Config.GetLevel(upgrades, upgrade.Requires) >= 1
end

------------------------------------------------------------------
-- Numbers that depend on upgrades
------------------------------------------------------------------

-- Seconds to brew `recipeId` (before stirring).
function Config.GetBrewSeconds(upgrades: Levels, recipeId: string): number
	local entry = Config.GetLevelEntry("BrewSpeed", Config.GetLevel(upgrades, "BrewSpeed"))
	local base = if entry and entry.BrewSeconds then entry.BrewSeconds else Tuning.Brewing.BaseSeconds
	local recipe = Recipes[recipeId]
	local multiplier = if recipe then recipe.BrewMultiplier else 1
	return math.floor(base * multiplier * 10 + 0.5) / 10
end

function Config.GetFireColor(upgrades: Levels): Color3
	local entry = Config.GetLevelEntry("BrewSpeed", Config.GetLevel(upgrades, "BrewSpeed"))
	return if entry and entry.FireColor then entry.FireColor else Palette.Fire
end

function Config.GetMaxPotions(upgrades: Levels): number
	local entry = Config.GetLevelEntry("Shelves", Config.GetLevel(upgrades, "Shelves"))
	return if entry and entry.MaxPotions then entry.MaxPotions else Tuning.Storage.MaxPotions
end

-- Charges per plant and seconds per regrow.
function Config.GetSourceStats(upgrades: Levels): (number, number)
	local entry = Config.GetLevelEntry("GreenThumb", Config.GetLevel(upgrades, "GreenThumb"))
	local maxCharges = if entry and entry.MaxCharges then entry.MaxCharges else Tuning.Sources.MaxCharges
	local regenSeconds = if entry and entry.RegenSeconds then entry.RegenSeconds else Tuning.Sources.RegenSeconds
	return math.min(maxCharges, Tuning.Sources.ChargeSlots), regenSeconds
end

function Config.GetCustomerSlots(upgrades: Levels): number
	local entry = Config.GetLevelEntry("CounterSpace", Config.GetLevel(upgrades, "CounterSpace"))
	return if entry and entry.CustomerSlots then entry.CustomerSlots else 1
end

------------------------------------------------------------------
-- Unlocks and recipes
------------------------------------------------------------------

function Config.IsIngredientUnlocked(upgrades: Levels, ingredientId: string): boolean
	local ingredient = Ingredients[ingredientId]
	if not ingredient then
		return false
	end
	local unlockedBy = ingredient.UnlockedBy
	return unlockedBy == nil or Config.GetLevel(upgrades, unlockedBy) >= 1
end

-- A recipe is unlocked once every one of its ingredients is.
function Config.IsRecipeUnlocked(upgrades: Levels, recipeId: string): boolean
	local recipe = Recipes[recipeId]
	if not recipe then
		return false
	end
	for ingredientId in recipe.Ingredients do
		if not Config.IsIngredientUnlocked(upgrades, ingredientId) then
			return false
		end
	end
	return true
end

-- Which upgrade unlocks this recipe (nil if it is unlocked from the start).
function Config.GetRecipeUnlocker(recipeId: string): string?
	local recipe = Recipes[recipeId]
	if not recipe then
		return nil
	end
	for ingredientId in recipe.Ingredients do
		local ingredient = Ingredients[ingredientId]
		if ingredient and ingredient.UnlockedBy then
			return ingredient.UnlockedBy
		end
	end
	return nil
end

function Config.HasIngredientsFor(inventory: { [string]: number }, recipeId: string): boolean
	local recipe = Recipes[recipeId]
	if not recipe then
		return false
	end
	for ingredientId, amount in recipe.Ingredients do
		if (inventory[ingredientId] or 0) < amount then
			return false
		end
	end
	return true
end

-- "1 Moonberry + 1 Glowshroom", in ingredient order.
function Config.DescribeIngredients(recipeId: string): string
	local recipe = Recipes[recipeId]
	if not recipe then
		return ""
	end
	local parts = {}
	for _, ingredientId in Config.IngredientOrder do
		local amount = recipe.Ingredients[ingredientId]
		if amount then
			table.insert(parts, `{amount} {Ingredients[ingredientId].DisplayName}`)
		end
	end
	return table.concat(parts, " + ")
end

function Config.PotionTotal(potions: { [string]: number }): number
	local total = 0
	for _, count in potions do
		total += count
	end
	return total
end

-- 1234567 -> "1,234,567"
-- The upgrade the goal banner should suggest buying now, or nil (keep playing / save up).
-- Follows Tuning.UpgradePath; after it, the first affordable useful upgrade, and a
-- cosmetic one only when no useful upgrade is left to work toward.
function Config.GetSuggestedUpgrade(upgrades: Levels, coins: number): string?
	local seen: { [string]: number } = {}
	for _, id in Tuning.UpgradePath do
		seen[id] = (seen[id] or 0) + 1
		if Config.GetLevel(upgrades, id) < seen[id] then
			-- the next step on the path
			local cost = Config.GetNextUpgradeCost(id, Config.GetLevel(upgrades, id))
			if cost and coins >= cost and Config.IsUpgradeAvailable(upgrades, id) then
				return id
			end
			return nil
		end
	end
	local cosmetic: string? = nil
	local usefulLeft = false
	for _, id in Config.UpgradeOrder do
		local cost = Config.GetNextUpgradeCost(id, Config.GetLevel(upgrades, id))
		if cost and Config.IsUpgradeAvailable(upgrades, id) then
			local isCosmetic = Upgrades[id].Cosmetic == true
			if not isCosmetic then
				usefulLeft = true
			end
			if coins >= cost then
				if not isCosmetic then
					return id
				end
				cosmetic = cosmetic or id
			end
		end
	end
	return if usefulLeft then nil else cosmetic
end

-- The daily gift right now: can it be claimed, which day of the streak it is (or will be),
-- its coins, and the seconds until it's ready (0 = ready). `now` is Unix time:
-- os.time() on the server, workspace:GetServerTimeNow() on clients.
function Config.GetDailyGift(daily: DailyState?, now: number): (boolean, number, number, number)
	local D = Tuning.Daily
	local last = if daily then daily.Last else 0
	local streak = if daily then daily.Streak else 0
	local since = now - last
	local ready = last <= 0 or since >= D.CooldownHours * 3600
	local day = if last > 0 and since < D.StreakHours * 3600 then streak + 1 else 1
	local reward = D.Rewards[math.clamp(day, 1, #D.Rewards)]
	local wait = if ready then 0 else math.ceil(D.CooldownHours * 3600 - since)
	return ready, day, reward, wait
end

-- "5h 20m", "12m", "40s".
function Config.FormatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return `{math.floor(s / 3600)}h {math.floor((s % 3600) / 60)}m`
	elseif s >= 60 then
		return `{math.floor(s / 60)}m`
	end
	return `{s}s`
end

function Config.FormatNumber(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return if value < 0 then "-" .. formatted else formatted
end

return Config
