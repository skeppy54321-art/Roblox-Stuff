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
}

return Ingredients
