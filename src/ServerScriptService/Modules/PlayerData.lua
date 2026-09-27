-- PlayerData (ModuleScript) — ServerScriptService.Modules.PlayerData
-- PROTOTYPE: SESSION-ONLY. Data lives in memory and is lost when the player leaves.
-- Milestone 3 swaps the inside of this module for ProfileStore; the functions stay the same
-- so the other modules don't need to change.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Net = require(script.Parent:WaitForChild("Net"))

export type Data = {
	Coins: number,
	Ingredients: { [string]: number },
	Potions: { [string]: number },
	Upgrades: { [string]: number },
	Discovered: { [string]: boolean },
	Stats: { PotionsBrewed: number, PotionsSold: number },
}

local PlayerData = {}

local store: { [Player]: Data } = {}

local function newData(): Data
	local ingredients = {}
	for id in Config.Ingredients do
		ingredients[id] = 0
	end
	local potions = {}
	for id in Config.Recipes do
		potions[id] = 0
	end
	local upgrades = {}
	for id in Config.Upgrades do
		upgrades[id] = 0
	end
	return {
		Coins = Config.StartingCoins,
		Ingredients = ingredients,
		Potions = potions,
		Upgrades = upgrades,
		Discovered = {},
		Stats = { PotionsBrewed = 0, PotionsSold = 0 },
	}
end

function PlayerData.Create(player: Player): Data
	local data = newData()
	store[player] = data
	return data
end

function PlayerData.Get(player: Player): Data?
	return store[player]
end

function PlayerData.Remove(player: Player)
	store[player] = nil
end

-- Send the player's full state to their client. Call after every change.
function PlayerData.Push(player: Player)
	local data = store[player]
	if data then
		Net.StateUpdate:FireClient(player, data)
	end
end

function PlayerData.PotionTotal(data: Data): number
	local total = 0
	for _, count in data.Potions do
		total += count
	end
	return total
end

return PlayerData
