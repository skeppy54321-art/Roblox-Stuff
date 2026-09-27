--!strict
-- Ingredients (ModuleScript) — ReplicatedStorage.Config.Ingredients
-- Every ingredient a shop can grow. `UnlockedBy` names the upgrade that plants
-- its source; nil means every shop has it from the start.

export type Ingredient = {
	Id: string,
	DisplayName: string,
	Color: Color3,
	Where: string, -- finishes the goal banner: "Collect a Moonberry from the purple bush."
	UnlockedBy: string?,
	Order: number,
}

local Ingredients: { [string]: Ingredient } = {
	Moonberry = {
		Id = "Moonberry",
		DisplayName = "Moonberry",
		Color = Color3.fromRGB(150, 95, 255),
		Where = "the purple bush",
		Order = 1,
	},
	Glowshroom = {
		Id = "Glowshroom",
		DisplayName = "Glowshroom",
		Color = Color3.fromRGB(70, 235, 200),
		Where = "the glowing mushrooms",
		Order = 2,
	},
	Starflower = {
		Id = "Starflower",
		DisplayName = "Starflower",
		Color = Color3.fromRGB(255, 212, 70),
		Where = "the starflower bed",
		UnlockedBy = "StarflowerBed",
		Order = 3,
	},
	FrostCrystal = {
		Id = "FrostCrystal",
		DisplayName = "Frost Crystal",
		Color = Color3.fromRGB(140, 215, 255),
		Where = "the frost grotto",
		UnlockedBy = "FrostGrotto",
		Order = 4,
	},
	EmberPepper = {
		Id = "EmberPepper",
		DisplayName = "Ember Pepper",
		Color = Color3.fromRGB(255, 95, 45),
		Where = "the ember garden",
		UnlockedBy = "EmberGarden",
		Order = 5,
	},
	CloudPuff = {
		Id = "CloudPuff",
		DisplayName = "Cloud Puff",
		Color = Color3.fromRGB(225, 240, 255),
		Where = "the cloud garden",
		UnlockedBy = "CloudGarden",
		Order = 6,
	},
	Stardust = { -- only after a rebirth (the Star Well needs one)
		Id = "Stardust",
		DisplayName = "Stardust",
		Color = Color3.fromRGB(150, 165, 255),
		Where = "the star well",
		UnlockedBy = "StarWell",
		Order = 7,
	},
}

return Ingredients
