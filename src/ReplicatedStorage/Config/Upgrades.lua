--!strict
-- Upgrades (ModuleScript) — ReplicatedStorage.Config.Upgrades
-- Everything coins can buy. Level 0 = not bought. Each entry in `Levels` is the
-- next level's cost plus the numbers that level switches on.
--   Unlocks  = ingredient id whose source gets planted at level 1
--   Requires = upgrade id that must be bought first

export type UpgradeLevel = {
	Cost: number,
	Summary: string, -- what this level gives, shown on the upgrade card
	BrewSeconds: number?, -- BrewSpeed
	FireColor: Color3?, -- BrewSpeed
	MaxPotions: number?, -- Shelves
	MaxCharges: number?, -- GreenThumb
	RegenSeconds: number?, -- GreenThumb
	CustomerSlots: number?, -- CounterSpace
}

export type Upgrade = {
	Id: string,
	DisplayName: string,
	Description: string,
	BaseSummary: string, -- shown for level 0
	Color: Color3, -- card accent
	Levels: { UpgradeLevel },
	Unlocks: string?,
	Requires: string?,
	Announce: string?, -- told to the whole market when someone buys it: "<name> <Announce>!"
	Order: number,
}

local Upgrades: { [string]: Upgrade } = {
	BrewSpeed = {
		Id = "BrewSpeed",
		DisplayName = "Faster Brewing",
		Description = "Hotter fire, faster potions. Your fire changes color!",
		BaseSummary = "Brew time 6s",
		Color = Color3.fromRGB(255, 140, 40),
		Levels = {
			{ Cost = 25, Summary = "Brew time 4.5s", BrewSeconds = 4.5, FireColor = Color3.fromRGB(80, 170, 255) },
			{ Cost = 90, Summary = "Brew time 3.5s", BrewSeconds = 3.5, FireColor = Color3.fromRGB(200, 90, 255) },
			{ Cost = 300, Summary = "Brew time 2.5s", BrewSeconds = 2.5, FireColor = Color3.fromRGB(90, 255, 140) },
		},
		Order = 1,
	},
	StarflowerBed = {
		Id = "StarflowerBed",
		DisplayName = "Starflower Bed",
		Description = "Plant glowing Starflowers. Unlocks Floaty and Twirly potions!",
		BaseSummary = "Not planted",
		Color = Color3.fromRGB(255, 212, 70),
		Levels = {
			{ Cost = 60, Summary = "Starflowers planted" },
		},
		Unlocks = "Starflower",
		Announce = "planted a Starflower Bed",
		Order = 2,
	},
	Shelves = {
		Id = "Shelves",
		DisplayName = "Bigger Shelves",
		Description = "Store more potions at once.",
		BaseSummary = "Holds 5 potions",
		Color = Color3.fromRGB(190, 130, 80),
		Levels = {
			{ Cost = 80, Summary = "Holds 8 potions", MaxPotions = 8 },
			{ Cost = 250, Summary = "Holds 12 potions", MaxPotions = 12 },
		},
		Order = 3,
	},
	GreenThumb = {
		Id = "GreenThumb",
		DisplayName = "Green Thumb",
		Description = "Your plants grow more and regrow faster.",
		BaseSummary = "3 per plant, regrow 3s",
		Color = Color3.fromRGB(110, 200, 90),
		Levels = {
			{ Cost = 120, Summary = "4 per plant, regrow 2.4s", MaxCharges = 4, RegenSeconds = 2.4 },
			{ Cost = 350, Summary = "5 per plant, regrow 1.8s", MaxCharges = 5, RegenSeconds = 1.8 },
		},
		Order = 4,
	},
	CounterSpace = {
		Id = "CounterSpace",
		DisplayName = "Second Counter Spot",
		Description = "Serve two customers at the same time!",
		BaseSummary = "1 customer at a time",
		Color = Color3.fromRGB(90, 150, 255),
		Levels = {
			{ Cost = 200, Summary = "2 customers at a time", CustomerSlots = 2 },
		},
		Announce = "opened a second counter spot",
		Order = 5,
	},
	FrostGrotto = {
		Id = "FrostGrotto",
		DisplayName = "Frost Grotto",
		Description = "Grow magic Frost Crystals. Unlocks Frosty and Froggy potions!",
		BaseSummary = "Not built",
		Color = Color3.fromRGB(140, 215, 255),
		Levels = {
			{ Cost = 400, Summary = "Frost Crystals growing" },
		},
		Unlocks = "FrostCrystal",
		Requires = "StarflowerBed",
		Announce = "found a Frost Grotto",
		Order = 6,
	},
	EmberGarden = {
		Id = "EmberGarden",
		DisplayName = "Ember Garden",
		Description = "Grow fiery Ember Peppers. Unlocks Fire Breath and Dance potions!",
		BaseSummary = "Not planted",
		Color = Color3.fromRGB(255, 110, 50),
		Levels = {
			{ Cost = 900, Summary = "Ember Peppers growing" },
		},
		Unlocks = "EmberPepper",
		Requires = "FrostGrotto",
		Announce = "planted an Ember Garden",
		Order = 7,
	},
	CloudGarden = {
		Id = "CloudGarden",
		DisplayName = "Cloud Garden",
		Description = "Catch fluffy Cloud Puffs. Unlocks Bubble, Ghost and Rocket potions!",
		BaseSummary = "Not built",
		Color = Color3.fromRGB(150, 190, 255),
		Levels = {
			{ Cost = 1600, Summary = "Cloud Puffs floating" },
		},
		Unlocks = "CloudPuff",
		Requires = "EmberGarden",
		Announce = "grew a Cloud Garden",
		Order = 8,
	},
	CozyDecor = {
		Id = "CozyDecor",
		DisplayName = "Cozy Decor",
		Description = "Make your shop the fanciest in the market!",
		BaseSummary = "Plain shop",
		Color = Color3.fromRGB(240, 100, 160),
		Levels = {
			{ Cost = 150, Summary = "String lights + flower boxes" },
			{ Cost = 500, Summary = "Banners + magic sign" },
			{ Cost = 1500, Summary = "Golden cauldron!" },
		},
		Order = 9,
	},
}

return Upgrades
