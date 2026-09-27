--!strict
-- Recipes (ModuleScript) — ReplicatedStorage.Config.Recipes
-- Every potion. A recipe can be brewed once all its ingredients are unlocked.
-- `Effect` is the name of a child module of ReplicatedStorage.Effects.

export type Recipe = {
	Id: string,
	DisplayName: string,
	Description: string, -- what it does to the customer (shown in the recipe book)
	Reaction: string, -- what the customer shouts after drinking it
	Ingredients: { [string]: number },
	SellPrice: number,
	BrewMultiplier: number, -- fancier potions take longer: brew time = base time * this
	Effect: string,
	Color: Color3,
	Order: number,
}

local Recipes: { [string]: Recipe } = {
	GiantHead = {
		Id = "GiantHead",
		DisplayName = "Giant Head Potion",
		Description = "Their head puffs up like a balloon!",
		Reaction = "My head!!",
		Ingredients = { Moonberry = 1, Glowshroom = 1 },
		SellPrice = 10,
		BrewMultiplier = 1,
		Effect = "BigHead",
		Color = Color3.fromRGB(255, 110, 200),
		Order = 1,
	},
	Rainbow = {
		Id = "Rainbow",
		DisplayName = "Rainbow Potion",
		Description = "They glow every color of the rainbow!",
		Reaction = "So sparkly!",
		Ingredients = { Moonberry = 2 },
		SellPrice = 12,
		BrewMultiplier = 1,
		Effect = "Rainbow",
		Color = Color3.fromRGB(255, 90, 90),
		Order = 2,
	},
	Tiny = {
		Id = "Tiny",
		DisplayName = "Tiny Potion",
		Description = "They shrink down to pocket size!",
		Reaction = "Eek, I'm tiny!",
		Ingredients = { Glowshroom = 2 },
		SellPrice = 12,
		BrewMultiplier = 1,
		Effect = "Tiny",
		Color = Color3.fromRGB(90, 190, 255),
		Order = 3,
	},
	Floaty = {
		Id = "Floaty",
		DisplayName = "Floaty Potion",
		Description = "They float up into the sky like a balloon!",
		Reaction = "Wheee!",
		Ingredients = { Starflower = 1, Glowshroom = 1 },
		SellPrice = 24,
		BrewMultiplier = 1.2,
		Effect = "Floaty",
		Color = Color3.fromRGB(255, 236, 130),
		Order = 4,
	},
	Twirly = {
		Id = "Twirly",
		DisplayName = "Twirly Potion",
		Description = "They spin like a spinning top!",
		Reaction = "So dizzy!!",
		Ingredients = { Starflower = 1, Moonberry = 1 },
		SellPrice = 24,
		BrewMultiplier = 1.2,
		Effect = "Twirl",
		Color = Color3.fromRGB(255, 150, 50),
		Order = 5,
	},
	Frosty = {
		Id = "Frosty",
		DisplayName = "Frosty Potion",
		Description = "They freeze into an ice statue. Brrr!",
		Reaction = "Brrrr!",
		Ingredients = { FrostCrystal = 1, Glowshroom = 1 },
		SellPrice = 45,
		BrewMultiplier = 1.5,
		Effect = "Frosty",
		Color = Color3.fromRGB(175, 240, 255),
		Order = 6,
	},
	Froggy = {
		Id = "Froggy",
		DisplayName = "Froggy Potion",
		Description = "They turn into a frog. Ribbit!",
		Reaction = "Ribbit!",
		Ingredients = { FrostCrystal = 1, Moonberry = 1, Starflower = 1 },
		SellPrice = 70,
		BrewMultiplier = 1.8,
		Effect = "Froggy",
		Color = Color3.fromRGB(110, 220, 90),
		Order = 7,
	},
}

return Recipes
