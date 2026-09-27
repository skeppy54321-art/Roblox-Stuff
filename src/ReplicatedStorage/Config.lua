-- Config (ModuleScript) — ReplicatedStorage.Config
-- Every tunable number and name lives here. Server AND client read it.
-- PROTOTYPE values: expect to tune these after playtesting.

local Config = {}

-- PROTOTYPE: progress is kept in memory only and resets when you leave.
Config.SessionOnly = true

-- Where each shop plot is built (center of the plot floor, on the baseplate).
-- Two plots so you can test with 2 players in Studio.
Config.Plots = {
	Vector3.new(0, 0, -45),
	Vector3.new(45, 0, -45),
}

-- Server allows interactions from this far (a little more than the prompt range, for lag).
Config.InteractDistance = 14
Config.PromptDistance = 10

Config.StartingCoins = 0

Config.Ingredients = {
	Moonberry = {
		DisplayName = "Moonberry",
		Color = Color3.fromRGB(150, 95, 255),
		Where = "the purple bush",
	},
	Glowshroom = {
		DisplayName = "Glowshroom",
		Color = Color3.fromRGB(70, 235, 200),
		Where = "the glowing mushrooms",
	},
}
Config.IngredientOrder = { "Moonberry", "Glowshroom" }

Config.Sources = {
	MaxCharges = 3, -- how many you can grab before it needs to regrow
	RegenSeconds = 3, -- one charge regrows every N seconds
	CollectCooldown = 0.3,
}

Config.Storage = {
	MaxPerIngredient = 10,
	MaxPotions = 5,
}

Config.Recipes = {
	GiantHead = {
		DisplayName = "Giant Head Potion",
		Ingredients = { Moonberry = 1, Glowshroom = 1 },
		SellPrice = 10,
		Effect = "BigHead", -- name of a function in ReplicatedStorage.Effects
		Color = Color3.fromRGB(255, 110, 200),
	},
}
-- Prototype has one recipe; the cauldron always brews this.
Config.PrototypeRecipe = "GiantHead"

Config.Brewing = {
	BaseSeconds = 6,
	StirSeconds = 0.75, -- each stir cuts this much time
	MaxStirs = 3, -- stirs allowed per brew
	StirCooldown = 0.3,
}

Config.Customers = {
	FirstSpawnDelay = 1,
	RespawnSeconds = 2.5,
	EffectSeconds = 3.2, -- how long the customer stays after drinking
	SellCooldown = 0.5,
}

Config.Upgrades = {
	BrewSpeed = {
		DisplayName = "Faster Brewing",
		Description = "Potions brew faster. Your fire changes color!",
		Levels = {
			{ Cost = 25, BrewSeconds = 4, FireColor = Color3.fromRGB(80, 170, 255) },
			{ Cost = 60, BrewSeconds = 2.5, FireColor = Color3.fromRGB(200, 90, 255) },
		},
	},
}
Config.UpgradeOrder = { "BrewSpeed" }

-- Shared color palette so everything looks like one set.
Config.Palette = {
	Floor = Color3.fromRGB(196, 150, 100),
	Wood = Color3.fromRGB(150, 98, 58),
	DarkWood = Color3.fromRGB(96, 60, 36),
	AwningA = Color3.fromRGB(225, 80, 110),
	AwningB = Color3.fromRGB(255, 236, 200),
	Leaf = Color3.fromRGB(70, 150, 80),
	Dirt = Color3.fromRGB(110, 80, 60),
	Stem = Color3.fromRGB(240, 230, 210),
	Cauldron = Color3.fromRGB(45, 45, 58),
	Liquid = Color3.fromRGB(140, 255, 120),
	Fire = Color3.fromRGB(255, 140, 40),
	Gold = Color3.fromRGB(255, 200, 60),
	Skin = { Color3.fromRGB(255, 214, 170), Color3.fromRGB(205, 150, 110), Color3.fromRGB(140, 95, 65) },
	Shirts = {
		Color3.fromRGB(90, 150, 255),
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(120, 210, 110),
		Color3.fromRGB(240, 100, 160),
	},
	Bottles = {
		Color3.fromRGB(255, 110, 200),
		Color3.fromRGB(110, 200, 255),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(150, 255, 150),
		Color3.fromRGB(190, 120, 255),
	},
	PanelDark = Color3.fromRGB(45, 32, 55),
	PanelLight = Color3.fromRGB(255, 244, 222),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(60, 40, 30),
	Button = Color3.fromRGB(90, 200, 110),
	ButtonOff = Color3.fromRGB(130, 130, 140),
}

-- Brew time for a given BrewSpeed upgrade level (0 = no upgrade).
function Config.GetBrewSeconds(level: number): number
	local levels = Config.Upgrades.BrewSpeed.Levels
	if level <= 0 then
		return Config.Brewing.BaseSeconds
	end
	local entry = levels[math.min(level, #levels)]
	return entry.BrewSeconds
end

-- Cost of the next level, or nil if maxed.
function Config.GetNextUpgradeCost(upgradeId: string, level: number): number?
	local upgrade = Config.Upgrades[upgradeId]
	local nextLevel = upgrade and upgrade.Levels[level + 1]
	return nextLevel and nextLevel.Cost or nil
end

return Config
