--!strict
-- ShopBuilder (ModuleScript) — ServerScriptService.Modules.ShopBuilder
-- Builds one shop plot out of simple parts, so no free models are needed.
-- Visual only: no game rules live here.
--
-- Plot space: the plot's CFrame sits on the ground at the plot's center.
-- -Z is the front (counter side, facing the plaza), +Z is the back wall,
-- and every `y` below is height above the wooden floor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local P = Config.Palette
local CHARGE_SLOTS = Config.Tuning.Sources.ChargeSlots
local WOOD = Enum.Material.Wood
local NEON = Enum.Material.Neon

export type PlotParts = {
	Model: Model,
	Sources: { [string]: Model }, -- ingredient id -> source (charges, hitbox, CollectPrompt)
	Lots: { [string]: Model }, -- upgrade id -> "for sale" lot shown while that source is locked
	Features: { [string]: Model }, -- extra visuals switched on by upgrades
	SourcesFolder: Folder, -- where unlocked sources live
	LotsFolder: Folder, -- where "for sale" lots live
	Cauldron: Model,
	Sign: BasePart,
	CheerStand: Model, -- visitors cheer for the owner here (Hitbox + CheerPrompt, Hearts, CountLabel)
	DisplaySlots: { Model }, -- bottles on the counter showing the owner's potions (hidden when empty)
	CounterFront: BasePart,
	SpawnPoint: BasePart,
	GoldParts: { BasePart }, -- cauldron parts that turn gold with Cozy Decor level 3
	FireParts: { BasePart }, -- flames that change color with Faster Brewing
}

type At = (x: number, y: number, z: number) -> CFrame

local ShopBuilder = {}

-- Where each ingredient source sits (plot space x, z).
ShopBuilder.SourceSpots = {
	Moonberry = Vector3.new(-10.5, 0, 5),
	Glowshroom = Vector3.new(10.5, 0, 5),
	Starflower = Vector3.new(-10.5, 0, -3),
	FrostCrystal = Vector3.new(10.5, 0, -3),
	EmberPepper = Vector3.new(-10.5, 0, 10.5),
	CloudPuff = Vector3.new(10.5, 0, 10.5),
} :: { [string]: Vector3 }

-- Customers line up in front of the counter, this far out (plot space z).
ShopBuilder.CounterFrontZ = -11.5

local function marker(parent: Instance, name: string, cf: CFrame): Part
	return Kit.Part(parent, name, Vector3.one, cf, Color3.new(1, 1, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

------------------------------------------------------------------
-- Props
------------------------------------------------------------------

-- A potion bottle standing on `base` (a CFrame on the shelf's top surface).
local function bottle(parent: Instance, base: CFrame, color: Color3, kind: number)
	local glow = { Transparency = 0.1, CastShadow = false }
	if kind == 1 then -- round flask
		Kit.Ball(parent, "Bottle", 1, (base * CFrame.new(0, 0.5, 0)).Position, color, NEON, glow)
		Kit.Cylinder(
			parent,
			"Neck",
			0.45,
			0.32,
			base * CFrame.new(0, 1.12, 0),
			color,
			Enum.Material.Glass,
			{ Transparency = 0.3 }
		)
		Kit.Cylinder(parent, "Cork", 0.25, 0.36, base * CFrame.new(0, 1.45, 0), P.LightWood, WOOD)
	elseif kind == 2 then -- tall bottle
		Kit.Cylinder(parent, "Bottle", 1.3, 0.75, base * CFrame.new(0, 0.65, 0), color, NEON, glow)
		Kit.Cylinder(
			parent,
			"Neck",
			0.4,
			0.32,
			base * CFrame.new(0, 1.5, 0),
			color,
			Enum.Material.Glass,
			{ Transparency = 0.3 }
		)
		Kit.Cylinder(parent, "Cork", 0.22, 0.36, base * CFrame.new(0, 1.81, 0), P.LightWood, WOOD)
	else -- square jar
		Kit.Decor(parent, "Jar", Vector3.new(0.9, 0.85, 0.9), base * CFrame.new(0, 0.425, 0), color, NEON, glow)
		Kit.Decor(parent, "Lid", Vector3.new(1, 0.16, 1), base * CFrame.new(0, 0.93, 0), P.DarkWood, WOOD)
	end
end

-- A shelf plank on the back wall with a row of bottles.
local function shelf(parent: Instance, at: At, y: number, rng: Random)
	Kit.Part(parent, "Shelf", Vector3.new(16, 0.35, 1.5), at(0, y, 12.3), P.DarkWood, WOOD)
	for _, x in { -7.5, 7.5 } do
		Kit.Decor(parent, "Bracket", Vector3.new(0.3, 0.8, 1.2), at(x, y - 0.55, 12.4), P.DarkWood, WOOD)
	end
	for i, x in { -6, -3, 0, 3, 6 } do
		local color = P.Bottles[rng:NextInteger(1, #P.Bottles)]
		local base = at(x + rng:NextNumber(-0.5, 0.5), y + 0.175, 12.3)
		bottle(parent, base, color, (i + rng:NextInteger(0, 2)) % 3 + 1)
	end
end

local function barrel(parent: Instance, cf: CFrame)
	Kit.Cylinder(parent, "Barrel", 2.6, 2.1, cf, P.Wood, WOOD, { CanCollide = true, CanQuery = true })
	for _, y in { -0.8, 0.8 } do
		Kit.Cylinder(parent, "Band", 0.22, 2.2, cf * CFrame.new(0, y, 0), P.Metal, Enum.Material.Metal)
	end
end

-- Little flowers in a window box. `cf` = center of the box's bottom.
local function flowerBox(parent: Instance, cf: CFrame, length: number, rng: Random)
	Kit.Decor(parent, "FlowerBox", Vector3.new(1.1, 0.7, length), cf * CFrame.new(0, 0.35, 0), P.Wood, WOOD)
	Kit.Decor(
		parent,
		"Leaves",
		Vector3.new(0.9, 0.3, length - 0.2),
		cf * CFrame.new(0, 0.8, 0),
		P.LeafLight,
		Enum.Material.Grass
	)
	local colors = {
		Color3.fromRGB(255, 130, 180),
		Color3.fromRGB(255, 240, 250),
		Color3.fromRGB(255, 210, 90),
		Color3.fromRGB(190, 140, 255),
	}
	local count = math.floor(length / 0.8)
	for i = 1, count do
		local z = -length / 2 + (i - 0.5) * (length / count)
		local position = (cf * CFrame.new(rng:NextNumber(-0.2, 0.2), 1.05, z)).Position
		Kit.Ball(parent, "Flower", 0.55, position, colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic)
	end
end

------------------------------------------------------------------
-- Ingredient sources (each has Charge1..ChargeN + Hitbox + CollectPrompt)
------------------------------------------------------------------

local function sourceModel(parent: Instance, ingredientId: string): Model
	local model = Kit.Model(parent, ingredientId)
	model:SetAttribute("Ingredient", ingredientId)
	return model
end

local function collectPrompt(model: Model, size: Vector3, cf: CFrame, ingredientId: string)
	local box = Kit.Hitbox(model, size, cf)
	Kit.Prompt(box, "CollectPrompt", "Collect", Config.Ingredients[ingredientId].DisplayName)
end

-- Moonberry bush: three leafy balls, glowing purple berries = charges.
local function buildMoonberry(parent: Instance, at: At): Model
	local bush = sourceModel(parent, "Moonberry")
	local c = ShopBuilder.SourceSpots.Moonberry
	local function pos(x: number, y: number, z: number): Vector3
		return at(c.X + x, y, c.Z + z).Position
	end
	Kit.Ball(bush, "Leaves", 4.2, pos(0, 1.9, 0.6), P.Leaf, Enum.Material.Grass, { CanCollide = true, CanQuery = true })
	Kit.Ball(bush, "Leaves", 3.2, pos(1.2, 1.4, -0.8), P.LeafLight, Enum.Material.Grass)
	Kit.Ball(bush, "Leaves", 3, pos(-1.1, 1.3, -0.9), P.LeafDark, Enum.Material.Grass)
	local berries = {
		Vector3.new(1.56, 2.84, -0.44),
		Vector3.new(0.42, 3.67, -0.44),
		Vector3.new(2.16, 1.72, -2.04),
		Vector3.new(2.65, 1.88, -0.32),
		Vector3.new(-0.95, 1.9, -2.27),
	}
	for i = 1, CHARGE_SLOTS do
		local o = berries[i]
		Kit.Ball(
			bush,
			"Charge" .. i,
			0.9,
			pos(o.X, o.Y, o.Z),
			Config.Ingredients.Moonberry.Color,
			NEON,
			{ CastShadow = false }
		)
	end
	collectPrompt(bush, Vector3.new(5.5, 4.5, 5.5), at(c.X, 2.2, c.Z), "Moonberry")
	return bush
end

-- Glowshroom patch: mushrooms on a dirt mound; the glowing caps = charges.
local function buildGlowshroom(parent: Instance, at: At): Model
	local patch = sourceModel(parent, "Glowshroom")
	local c = ShopBuilder.SourceSpots.Glowshroom
	Kit.Cylinder(patch, "Dirt", 0.4, 5.2, at(c.X, 0.2, c.Z), P.Dirt, Enum.Material.Ground)
	local shrooms = {
		{ -1.3, -1.1, 1.2 },
		{ 0.4, -1.5, 1.6 },
		{ 1.4, 0.3, 1.1 },
		{ -0.3, 0.9, 1.8 },
		{ -1.7, 0.8, 0.9 },
	}
	local color = Config.Ingredients.Glowshroom.Color
	for i = 1, CHARGE_SLOTS do
		local x, z, h = c.X + shrooms[i][1], c.Z + shrooms[i][2], shrooms[i][3]
		Kit.Cylinder(patch, "Stem", h, 0.45, at(x, 0.4 + h / 2, z), P.Stem)
		local cap = Kit.Model(patch, "Charge" .. i)
		Kit.Cylinder(cap, "Cap", 0.35, 1.7, at(x, 0.5 + h, z), color, NEON, { CastShadow = false })
		Kit.Ball(cap, "Dome", 1.15, at(x, 0.85 + h, z).Position, color, NEON, { CastShadow = false })
	end
	collectPrompt(patch, Vector3.new(5.5, 3.5, 5.5), at(c.X, 1.75, c.Z), "Glowshroom")
	return patch
end

-- Starflower bed: a planter of sparkly star flowers; the flower heads = charges.
local function buildStarflower(parent: Instance, at: At): Model
	local bed = sourceModel(parent, "Starflower")
	local c = ShopBuilder.SourceSpots.Starflower
	Kit.Part(bed, "Planter", Vector3.new(5, 1, 4), at(c.X, 0.5, c.Z), P.Wood, WOOD)
	Kit.Decor(bed, "Soil", Vector3.new(4.5, 0.1, 3.5), at(c.X, 1.02, c.Z), P.Dirt, Enum.Material.Ground)
	local flowers = {
		{ -1.5, -0.9, 1.3 },
		{ 0, -1.1, 1.7 },
		{ 1.5, -0.8, 1.2 },
		{ -0.8, 0.9, 1.5 },
		{ 1, 1, 1.4 },
	}
	local color = Config.Ingredients.Starflower.Color
	for i = 1, CHARGE_SLOTS do
		local x, z, h = c.X + flowers[i][1], c.Z + flowers[i][2], flowers[i][3]
		Kit.Cylinder(bed, "Stem", h, 0.18, at(x, 1 + h / 2, z), P.LeafDark)
		local head = Kit.Model(bed, "Charge" .. i)
		for k = 0, 1 do
			Kit.Decor(
				head,
				"Petal",
				Vector3.new(1.4, 0.14, 0.36),
				at(x, 1 + h, z) * CFrame.Angles(0, math.rad(45 + 90 * k), 0),
				color,
				NEON,
				{ CastShadow = false }
			)
		end
		Kit.Ball(
			head,
			"Center",
			0.5,
			at(x, 1.05 + h, z).Position,
			Color3.fromRGB(255, 160, 60),
			NEON,
			{ CastShadow = false }
		)
	end
	collectPrompt(bed, Vector3.new(5.5, 4, 4.5), at(c.X, 2, c.Z), "Starflower")
	return bed
end

-- Frost grotto: icy crystals growing out of blue-grey rocks; the crystals = charges.
local function buildFrostCrystal(parent: Instance, at: At): Model
	local grotto = sourceModel(parent, "FrostCrystal")
	local c = ShopBuilder.SourceSpots.FrostCrystal
	local rock = Color3.fromRGB(122, 132, 152)
	local bigRock = Kit.Part(
		grotto,
		"Rock",
		Vector3.new(3.2, 1.6, 2.6),
		at(c.X + 0.6, 0.8, c.Z + 0.5) * CFrame.Angles(0, 0.4, 0.15),
		rock,
		Enum.Material.Slate
	)
	Kit.Ball(
		grotto,
		"Rock",
		2.4,
		at(c.X - 0.9, 0.6, c.Z - 0.4).Position,
		Color3.fromRGB(135, 145, 165),
		Enum.Material.Slate
	)
	Kit.Ball(
		grotto,
		"Rock",
		1.6,
		at(c.X + 1.4, 0.4, c.Z - 1.3).Position,
		Color3.fromRGB(110, 120, 140),
		Enum.Material.Slate
	)
	local crystals = {
		{ -1.2, 0.6, 2.6, 0.25, -0.2 },
		{ 0.2, 1, 3.2, -0.1, 0.1 },
		{ 1.4, 0.3, 2.2, 0.2, 0.3 },
		{ -0.3, -0.9, 1.8, -0.3, -0.1 },
		{ 1, -1.1, 1.5, 0.1, 0.35 },
	}
	local color = Config.Ingredients.FrostCrystal.Color
	for i = 1, CHARGE_SLOTS do
		local d = crystals[i]
		local cf = at(c.X + d[1], 0.4 + d[3] / 2, c.Z + d[2]) * CFrame.Angles(d[4], math.rad(45), d[5])
		local crystal = Kit.Model(grotto, "Charge" .. i)
		Kit.Decor(
			crystal,
			"Crystal",
			Vector3.new(0.75, d[3], 0.75),
			cf,
			color,
			Enum.Material.Glass,
			{ Transparency = 0.25 }
		)
		Kit.Decor(crystal, "Core", Vector3.new(0.32, d[3] * 0.8, 0.32), cf, color, NEON, { CastShadow = false })
	end
	Kit.Light(bigRock, color, 10, 0.8)
	collectPrompt(grotto, Vector3.new(5, 4.5, 5), at(c.X, 2.2, c.Z), "FrostCrystal")
	return grotto
end

-- Ember garden: a stone planter on glowing coals, chili plants; the peppers = charges.
local function buildEmberPepper(parent: Instance, at: At): Model
	local garden = sourceModel(parent, "EmberPepper")
	local c = ShopBuilder.SourceSpots.EmberPepper
	local planter =
		Kit.Part(garden, "Planter", Vector3.new(5, 1, 3.8), at(c.X, 0.5, c.Z), P.DarkStone, Enum.Material.Brick)
	Kit.Decor(
		garden,
		"Coals",
		Vector3.new(4.5, 0.1, 3.3),
		at(c.X, 1.02, c.Z),
		Color3.fromRGB(255, 90, 30),
		NEON,
		{ CastShadow = false }
	)
	for _, bushAt in { Vector3.new(-1.2, 0, 0.3), Vector3.new(1.1, 0, -0.2) } do
		Kit.Cylinder(garden, "Stem", 1.2, 0.25, at(c.X + bushAt.X, 1.6, c.Z + bushAt.Z), P.LeafDark)
		Kit.Ball(garden, "Leaves", 1.9, at(c.X + bushAt.X, 2.5, c.Z + bushAt.Z).Position, P.Leaf, Enum.Material.Grass)
	end
	-- peppers hang just outside the two plants' leaves, tips pointing down
	local peppers = {
		{ -2.3, 2, 0.6, 0.4 },
		{ -1, 1.95, -0.75, -0.3 },
		{ -0.6, 2, 1.2, 0.25 },
		{ 2.2, 2, 0, -0.35 },
		{ 1, 1.95, -1.25, 0.3 },
	}
	local color = Config.Ingredients.EmberPepper.Color
	for i = 1, CHARGE_SLOTS do
		local d = peppers[i]
		local cf = at(c.X + d[1], d[2], c.Z + d[3]) * CFrame.Angles(0, 0, d[4])
		local pepper = Kit.Model(garden, "Charge" .. i)
		Kit.Decor(pepper, "Pepper", Vector3.new(0.55, 1.2, 0.55), cf, color, NEON, { CastShadow = false })
		Kit.Decor(
			pepper,
			"Tip",
			Vector3.new(0.3, 0.3, 0.3),
			cf * CFrame.new(0, -0.62, 0),
			color,
			NEON,
			{ CastShadow = false }
		)
		Kit.Decor(
			pepper,
			"Cap",
			Vector3.new(0.55, 0.2, 0.55),
			cf * CFrame.new(0, 0.62, 0),
			P.LeafDark,
			Enum.Material.Grass
		)
	end
	Kit.Light(planter, Color3.fromRGB(255, 120, 50), 10, 0.9)
	Kit.Sparkles(planter, Color3.fromRGB(255, 150, 60), 3, "Embers")
	collectPrompt(garden, Vector3.new(5.5, 4, 4.5), at(c.X, 2, c.Z), "EmberPepper")
	return garden
end

-- Cloud garden: a stone basin with fluffy clouds floating above it; the clouds = charges.
local function buildCloudPuff(parent: Instance, at: At): Model
	local garden = sourceModel(parent, "CloudPuff")
	local c = ShopBuilder.SourceSpots.CloudPuff
	local basin = Kit.Cylinder(garden, "Basin", 1.2, 4.4, at(c.X, 0.6, c.Z), P.Stone, Enum.Material.Marble, {
		CanCollide = true,
		CanQuery = true,
	})
	Kit.Cylinder(
		garden,
		"Sky",
		0.1,
		3.9,
		at(c.X, 1.22, c.Z),
		Color3.fromRGB(120, 190, 255),
		NEON,
		{ CastShadow = false }
	)
	local clouds = {
		{ -1.2, 2.4, -0.6 },
		{ 0.3, 3.1, -1 },
		{ 1.3, 2.3, 0.2 },
		{ -0.6, 3.3, 0.9 },
		{ 0.8, 2.6, 1.3 },
	}
	local color = Config.Ingredients.CloudPuff.Color
	for i = 1, CHARGE_SLOTS do
		local d = clouds[i]
		local center = at(c.X + d[1], d[2], c.Z + d[3])
		local puff = Kit.Model(garden, "Charge" .. i)
		Kit.Ball(puff, "Puff", 1, center.Position, color, Enum.Material.SmoothPlastic, { CastShadow = false })
		Kit.Ball(
			puff,
			"Puff",
			0.75,
			(center * CFrame.new(-0.55, -0.12, 0.1)).Position,
			color,
			Enum.Material.SmoothPlastic,
			{
				CastShadow = false,
			}
		)
		Kit.Ball(
			puff,
			"Puff",
			0.7,
			(center * CFrame.new(0.55, -0.15, -0.05)).Position,
			color,
			Enum.Material.SmoothPlastic,
			{
				CastShadow = false,
			}
		)
	end
	Kit.Light(basin, Color3.fromRGB(170, 210, 255), 9, 0.7)
	Kit.Sparkles(basin, Color3.fromRGB(200, 230, 255), 3)
	collectPrompt(garden, Vector3.new(5, 4.5, 5), at(c.X, 2.2, c.Z), "CloudPuff")
	return garden
end

-- "For sale" lot shown where a locked source will be planted.
-- `faceX` = +1 turns the sign toward +X (the shop's middle), -1 toward -X.
local function buildLot(parent: Instance, at: At, upgradeId: string, spot: Vector3, faceX: number): Model
	local upgrade = Config.Upgrades[upgradeId]
	local cost = upgrade.Levels[1].Cost
	local lot = Kit.Model(parent, upgradeId .. "Lot")
	lot:SetAttribute("Upgrade", upgradeId)
	local dirt =
		Kit.Decor(lot, "Dirt", Vector3.new(4.6, 0.1, 3.8), at(spot.X, 0.05, spot.Z), P.Dirt, Enum.Material.Ground)
	Kit.Sparkles(dirt, upgrade.Color, 3)
	-- little stakes at the corners
	for _, corner in
		{ Vector3.new(-2.2, 0, -1.8), Vector3.new(2.2, 0, -1.8), Vector3.new(-2.2, 0, 1.8), Vector3.new(2.2, 0, 1.8) }
	do
		Kit.Decor(
			lot,
			"Stake",
			Vector3.new(0.25, 1, 0.25),
			at(spot.X + corner.X, 0.5, spot.Z + corner.Z),
			P.LightWood,
			WOOD
		)
	end
	local face = CFrame.Angles(0, math.rad(-90 * faceX), 0)
	local base = at(spot.X, 0, spot.Z)
	Kit.Decor(lot, "SignPost", Vector3.new(0.3, 2.8, 0.3), base * CFrame.new(0, 1.4, 0), P.DarkWood, WOOD)
	local board =
		Kit.Decor(lot, "SignBoard", Vector3.new(3.6, 1.9, 0.2), base * CFrame.new(0, 2.9, 0) * face, P.LightWood, WOOD)
	local label = Kit.SurfaceText(board, Enum.NormalId.Front, `{upgrade.DisplayName}\n{cost} coins`, P.TextDark, 60)
	label.Name = "LotLabel"
	local box = Kit.Hitbox(lot, Vector3.new(4.6, 4.5, 3.8), at(spot.X, 2.25, spot.Z))
	Kit.Prompt(box, "UnlockPrompt", "Unlock", `{upgrade.DisplayName} ({cost} coins)`)
	return lot
end

------------------------------------------------------------------
-- Potion display: one bottle per potion in stock, along the back of the counter
------------------------------------------------------------------

-- One slot for every potion the biggest shelves can hold.
local function mostPotions(): number
	local most = Config.Tuning.Storage.MaxPotions
	for _, level in Config.Upgrades.Shelves.Levels do
		most = math.max(most, level.MaxPotions or 0)
	end
	return most
end
ShopBuilder.DisplaySlotCount = mostPotions()

local function buildDisplay(plot: Model, at: At): { Model }
	local display = Kit.Model(plot, "Display")
	local slots: { Model } = {}
	local hidden = { Transparency = 1, CastShadow = false }
	for i = 1, ShopBuilder.DisplaySlotCount do
		local slot = Kit.Model(display, `Slot{i}`)
		local x = i - (ShopBuilder.DisplaySlotCount + 1) / 2 -- centered, 1 stud apart
		local base = at(x, 3.85, -7.3)
		Kit.Cylinder(slot, "Body", 1, 0.7, base * CFrame.new(0, 0.5, 0), P.Liquid, NEON, hidden)
		Kit.Cylinder(slot, "Neck", 0.35, 0.3, base * CFrame.new(0, 1.17, 0), P.Liquid, Enum.Material.Glass, hidden)
		Kit.Cylinder(slot, "Cork", 0.2, 0.34, base * CFrame.new(0, 1.44, 0), P.LightWood, WOOD, hidden)
		table.insert(slots, slot)
	end
	return slots
end

------------------------------------------------------------------
-- Cheer stand (front right, outside the counter)
------------------------------------------------------------------

-- A flat heart facing the plaza: two round lobes and a diamond tip.
local function heart(parent: Instance, cf: CFrame, size: number, color: Color3)
	local facing = CFrame.Angles(math.rad(90), 0, 0) -- cylinders face along Z
	local depth = 0.35 * size
	for _, side in { -1, 1 } do
		Kit.Cylinder(
			parent,
			"HeartLobe",
			depth,
			1.1 * size,
			cf * CFrame.new(side * 0.32 * size, 0.18 * size, 0) * facing,
			color,
			NEON,
			{
				CastShadow = false,
			}
		)
	end
	Kit.Decor(
		parent,
		"HeartTip",
		Vector3.new(0.95 * size, 0.95 * size, depth),
		cf * CFrame.new(0, -0.2 * size, 0) * CFrame.Angles(0, 0, math.rad(45)),
		color,
		NEON,
		{ CastShadow = false }
	)
end

local function buildCheerStand(plot: Model, at: At): Model
	local stand = Kit.Model(plot, "CheerStand")
	local x, z = 10.6, -10.8
	Kit.Part(stand, "Post", Vector3.new(0.35, 3.4, 0.35), at(x, 1.7, z), P.DarkWood, WOOD)
	Kit.Decor(stand, "Foot", Vector3.new(1.2, 0.25, 1.2), at(x, 0.125, z), P.DarkWood, WOOD)
	local board = Kit.Decor(stand, "CountBoard", Vector3.new(2.4, 0.9, 0.2), at(x, 2.1, z - 0.25), P.LightWood, WOOD)
	local label = Kit.SurfaceText(board, Enum.NormalId.Front, "0 cheers", P.TextDark, 60)
	label.Name = "CountLabel"
	heart(stand, at(x, 3.95, z), 1.1, P.Heart)
	-- hearts burst out of here (the server switches the emitter on for a moment)
	local burst = Kit.Decor(stand, "Burst", Vector3.new(1, 1, 1), at(x, 3.95, z), P.Heart, nil, {
		Transparency = 1,
		CastShadow = false,
	})
	local hearts = Kit.Sparkles(burst, P.Heart, 45, "Hearts")
	hearts.Enabled = false
	hearts.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	hearts.Speed = NumberRange.new(5, 9)
	hearts.SpreadAngle = Vector2.new(40, 40)
	hearts.EmissionDirection = Enum.NormalId.Top
	hearts.Acceleration = Vector3.new(0, -6, 0)
	hearts.Lifetime = NumberRange.new(0.9, 1.4)
	local hitbox = Kit.Hitbox(stand, Vector3.new(2.6, 4.6, 2.6), at(x, 2.3, z))
	local prompt = Kit.Prompt(hitbox, "CheerPrompt", "Cheer", "Shop")
	prompt:SetAttribute("ForVisitors", true) -- clients show it on other players' shops only
	return stand
end

------------------------------------------------------------------
-- Cauldron
------------------------------------------------------------------

local function buildCauldron(plot: Model, at: At, gold: { BasePart }, fire: { BasePart }): Model
	local cauldron = Kit.Model(plot, "Cauldron")
	cauldron:SetAttribute("BrewEndTime", 0)
	cauldron:SetAttribute("BrewDuration", 0)
	cauldron:SetAttribute("BrewRecipe", "")
	cauldron:SetAttribute("SuggestedRecipe", "")
	local cz = 1

	for i = 1, 3 do
		local angle = math.rad(120 * i + 30)
		local leg = Kit.Cylinder(
			cauldron,
			"Leg",
			1.4,
			0.5,
			at(math.cos(angle) * 1.6, 0.7, cz + math.sin(angle) * 1.6),
			P.Cauldron,
			Enum.Material.Metal
		)
		table.insert(gold, leg)
	end
	Kit.Rod(cauldron, "Log", at(-1.3, 0.25, cz - 0.6).Position, at(1.3, 0.25, cz + 0.6).Position, 0.5, P.Trunk, WOOD)
	Kit.Rod(cauldron, "Log", at(-1.3, 0.25, cz + 0.6).Position, at(1.3, 0.25, cz - 0.6).Position, 0.5, P.Trunk, WOOD)
	local flames = { { 0, 0.75, 0, 0.95 }, { 0.6, 0.55, 0.4, 0.7 }, { -0.55, 0.5, -0.35, 0.65 } }
	for _, f in flames do
		local flame =
			Kit.Ball(cauldron, "Flame", f[4], at(f[1], f[2], cz + f[3]).Position, P.Fire, NEON, { CastShadow = false })
		table.insert(fire, flame)
	end
	local fireLight = Kit.Light(fire[1], P.Fire, 12, 2)
	fireLight.Name = "FireLight"

	local belly = Kit.Ball(
		cauldron,
		"Belly",
		4.4,
		at(0, 2.6, cz).Position,
		P.Cauldron,
		Enum.Material.Metal,
		{ CanCollide = true, CanQuery = true }
	)
	local neck = Kit.Cylinder(cauldron, "Neck", 0.9, 4, at(0, 4.45, cz), P.Cauldron, Enum.Material.Metal)
	local rim = Kit.Cylinder(cauldron, "Rim", 0.35, 4.6, at(0, 4.95, cz), P.Cauldron, Enum.Material.Metal)
	table.insert(gold, belly)
	table.insert(gold, neck)
	table.insert(gold, rim)
	Kit.Cylinder(cauldron, "Liquid", 0.1, 3.8, at(0, 5.13, cz), P.Liquid, NEON, { CastShadow = false })

	local bubblePart = Kit.Decor(cauldron, "BubblePart", Vector3.new(3.2, 0.1, 3.2), at(0, 5.2, cz), P.Liquid, nil, {
		Transparency = 1,
		CastShadow = false,
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Color = ColorSequence.new(P.Liquid)
	bubbles.LightEmission = 0.6
	bubbles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	bubbles.Lifetime = NumberRange.new(0.6, 1.1)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.SpreadAngle = Vector2.new(15, 15)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Rate = 3
	bubbles.Parent = bubblePart
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	steam.LightEmission = 0.2
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	steam.Lifetime = NumberRange.new(1.5, 2.5)
	steam.Speed = NumberRange.new(1.5, 2.5)
	steam.SpreadAngle = Vector2.new(10, 10)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Rate = 2
	steam.Parent = bubblePart

	Kit.Rod(
		cauldron,
		"Ladle",
		at(0.6, 4.6, cz + 0.5).Position,
		at(1.9, 7.2, cz + 1.5).Position,
		0.25,
		P.LightWood,
		WOOD
	)
	Kit.Ball(cauldron, "LadleKnob", 0.45, at(1.9, 7.2, cz + 1.5).Position, P.DarkWood, WOOD)

	local box = Kit.Hitbox(cauldron, Vector3.new(5.5, 5.5, 5.5), at(0, 2.75, cz))
	Kit.Prompt(box, "BrewPrompt", "Brew", "Cauldron")
	return cauldron
end

------------------------------------------------------------------
-- Upgrade visuals (built once, shown/hidden by PlotService)
------------------------------------------------------------------

local function buildDecorLights(plot: Model, at: At, rng: Random): Model
	local group = Kit.Model(plot, "DecorLights")
	-- string lights sagging along the front edge of the awning
	local count = 12
	local left, right = at(-8.6, 9, -11.6).Position, at(8.6, 9, -11.6).Position
	local previous: Vector3? = nil
	local bulbColors = { Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 150, 190), Color3.fromRGB(150, 220, 255) }
	for i = 0, count do
		local t = i / count
		local point = left:Lerp(right, t) - Vector3.new(0, 0.9 * 4 * t * (1 - t), 0)
		if previous then
			Kit.Rod(group, "Wire", previous, point, 0.08, P.DarkWood)
		end
		if i > 0 and i < count then
			Kit.Ball(
				group,
				"Bulb",
				0.42,
				point - Vector3.new(0, 0.25, 0),
				bulbColors[i % #bulbColors + 1],
				NEON,
				{ CastShadow = false }
			)
		end
		previous = point
	end
	-- flower boxes on the side walls
	for _, x in { -14.5, 14.5 } do
		for _, z in { -4, 7 } do
			flowerBox(group, at(x, 2.5, z), 4.5, rng)
		end
	end
	return group
end

local function buildDecorBanners(plot: Model, at: At, theme: { Color3 }): Model
	local group = Kit.Model(plot, "DecorBanners")
	for _, x in { -7.2, 7.2 } do
		Kit.Decor(group, "Banner", Vector3.new(1.6, 4.2, 0.12), at(x, 6.6, -8.9), theme[1], Enum.Material.Fabric)
		Kit.Decor(group, "BannerTrim", Vector3.new(1.6, 0.3, 0.14), at(x, 4.6, -8.9), P.Gold, Enum.Material.Foil)
		Kit.Ball(group, "Emblem", 0.7, at(x, 7.2, -9).Position, P.Gold, NEON, { CastShadow = false })
	end
	-- potted plants at the front corners
	for _, x in { -12.8, 12.8 } do
		Kit.Cylinder(
			group,
			"Pot",
			1.4,
			1.6,
			at(x, 0.7, -12.8),
			Color3.fromRGB(190, 100, 70),
			Enum.Material.Plaster,
			{ CanCollide = true, CanQuery = true }
		)
		Kit.Ball(group, "Plant", 2.2, at(x, 2.2, -12.8).Position, P.LeafLight, Enum.Material.Grass)
		Kit.Ball(
			group,
			"Blossom",
			0.6,
			at(x + 0.5, 2.9, -13.4).Position,
			Color3.fromRGB(255, 130, 180),
			Enum.Material.SmoothPlastic
		)
	end
	-- glowing backing behind the shop sign
	Kit.Decor(group, "SignGlow", Vector3.new(12, 3.3, 0.1), at(0, 11.7, -7.8), P.Gold, NEON, { CastShadow = false })
	return group
end

local function buildDecorGold(plot: Model, at: At): Model
	local group = Kit.Model(plot, "DecorGold")
	-- star on top of the sign beam
	local star = Kit.Ball(group, "Star", 1, at(0, 14.2, -8).Position, P.Gold, NEON, { CastShadow = false })
	for k = 0, 1 do
		Kit.Decor(
			group,
			"StarPoint",
			Vector3.new(2.2, 0.35, 0.2),
			at(0, 14.2, -8) * CFrame.Angles(0, 0, math.rad(45 + 90 * k)),
			P.Gold,
			NEON,
			{
				CastShadow = false,
			}
		)
	end
	Kit.Sparkles(star, P.Gold, 4)
	-- gold trim along the counter
	Kit.Decor(group, "CounterTrim", Vector3.new(16.9, 0.2, 0.2), at(0, 3.5, -9.62), P.Gold, Enum.Material.Foil)
	-- sparkles rising from the cauldron
	local glitter = Kit.Decor(
		group,
		"Glitter",
		Vector3.new(4, 0.2, 4),
		at(0, 5.3, 1),
		P.Gold,
		nil,
		{ Transparency = 1, CastShadow = false }
	)
	Kit.Sparkles(glitter, P.Gold, 6)
	return group
end

local function buildShelfLevel(plot: Model, at: At, name: string, y: number, rng: Random): Model
	local group = Kit.Model(plot, name)
	shelf(group, at, y, rng)
	return group
end

------------------------------------------------------------------
-- The whole plot
------------------------------------------------------------------

function ShopBuilder.BuildPlot(index: number, origin: CFrame, parent: Instance): PlotParts
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, 1 + y, z)
	end
	local rng = Random.new(index * 7919)
	local theme = P.Awnings[(index - 1) % #P.Awnings + 1]

	local plot = Kit.Model(nil, "Plot" .. index)
	plot:SetAttribute("IsPlot", true)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("PlotIndex", index)

	local decor = Kit.Model(plot, "Decor")

	-- Floor on a cobblestone foundation
	Kit.Part(
		decor,
		"Foundation",
		Vector3.new(31, 0.8, 31),
		origin * CFrame.new(0, 0.4, 0),
		P.DarkStone,
		Enum.Material.Cobblestone
	)
	local floor = Kit.Part(
		decor,
		"Floor",
		Vector3.new(29, 1, 29),
		origin * CFrame.new(0, 0.5, 0),
		P.Floor,
		Enum.Material.WoodPlanks
	)
	Kit.Decor(decor, "Rug", Vector3.new(7.4, 0.06, 4.8), at(0, 0.03, 7), P.PanelLight, Enum.Material.Carpet)
	Kit.Decor(decor, "RugInner", Vector3.new(6.4, 0.07, 3.8), at(0, 0.04, 7), theme[1], Enum.Material.Carpet)

	-- Counter (customers stand in front of it)
	Kit.Part(decor, "Counter", Vector3.new(16, 3.5, 2.5), at(0, 1.75, -8), P.Wood, WOOD)
	Kit.Part(decor, "CounterTop", Vector3.new(16.8, 0.35, 3.2), at(0, 3.675, -8), P.DarkWood, WOOD)
	for i = -3, 3 do
		Kit.Decor(decor, "Slat", Vector3.new(0.35, 2.9, 0.2), at(i * 2.2, 1.75, -9.3), P.LightWood, WOOD)
	end
	bottle(decor, at(-6.8, 3.85, -8), P.Bottles[1], 1)
	bottle(decor, at(6.6, 3.85, -8.2), P.Bottles[2], 2)

	-- Stall posts, sign beam, striped awning with pom-pom trim
	for _, x in { -8.4, 8.4 } do
		Kit.Part(decor, "Post", Vector3.new(0.8, 13.5, 0.8), at(x, 6.75, -8), P.DarkWood, WOOD)
		Kit.Decor(decor, "LanternArm", Vector3.new(0.2, 0.2, 0.9), at(x, 8.7, -8.8), P.Metal, Enum.Material.Metal)
		Kit.Lantern(decor, at(x, 8.6, -9.15).Position, 0.9, 16)
	end
	Kit.Decor(decor, "SignBeam", Vector3.new(17.6, 0.6, 0.7), at(0, 13.2, -8), P.DarkWood, WOOD)
	local stripes = 8
	local width = 17.2
	local stripeWidth = width / stripes
	local tilt = CFrame.Angles(math.rad(-14), 0, 0)
	for i = 1, stripes do
		local x = -width / 2 + stripeWidth * (i - 0.5)
		local color = if i % 2 == 0 then theme[2] else theme[1]
		Kit.Decor(
			decor,
			"Awning",
			Vector3.new(stripeWidth, 0.25, 5.4),
			at(x, 10.2, -8.6) * tilt,
			color,
			Enum.Material.Fabric
		)
		Kit.Ball(
			decor,
			"Pompom",
			0.6,
			at(x, 9.35, -11.3).Position,
			if i % 2 == 0 then theme[1] else theme[2],
			Enum.Material.Fabric
		)
	end

	-- Shop sign (PlotService writes the owner's name on it)
	local sign =
		Kit.Part(plot, "Sign", Vector3.new(11, 2.4, 0.4), at(0, 11.7, -8.1), P.DarkWood, WOOD, { CanCollide = false })
	Kit.Decor(decor, "SignTrim", Vector3.new(11.4, 2.8, 0.3), at(0, 11.7, -8.1), P.Gold, Enum.Material.Foil)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.SurfaceText(sign, face, "Empty Shop", P.Gold, 40)
	end

	-- Back wall: timber frame, plaster, a little tiled roof
	Kit.Part(decor, "BackWall", Vector3.new(27, 9, 1), at(0, 4.5, 13.5), P.Plaster, Enum.Material.Plaster)
	Kit.Decor(decor, "Beam", Vector3.new(27.4, 0.7, 1.2), at(0, 0.35, 13.5), P.DarkWood, WOOD)
	Kit.Decor(decor, "TopBeam", Vector3.new(27.4, 1.6, 1.2), at(0, 9.7, 13.5), P.DarkWood, WOOD)
	for _, x in { -13.3, -8.6, 8.6, 13.3 } do
		Kit.Decor(decor, "Beam", Vector3.new(0.7, 9, 1.2), at(x, 4.5, 13.5), P.DarkWood, WOOD)
	end
	Kit.Decor(
		decor,
		"Roof",
		Vector3.new(28.4, 0.45, 5.2),
		at(0, 10.4, 13.2) * CFrame.Angles(math.rad(-25), 0, 0),
		P.Roof,
		Enum.Material.ClayRoofTiles
	)
	shelf(decor, at, 2.8, rng)

	-- Low stone side walls with a wooden cap
	for _, x in { -14.5, 14.5 } do
		Kit.Part(decor, "SideWall", Vector3.new(1, 2.2, 22), at(x, 1.1, 2), P.Stone, Enum.Material.Cobblestone)
		Kit.Decor(decor, "WallCap", Vector3.new(1.3, 0.3, 22.3), at(x, 2.35, 2), P.DarkWood, WOOD)
	end

	-- A barrel and crates in the front corners, beside the counter (the back corners grow
	-- the Ember and Cloud gardens)
	barrel(decor, at(-12.4, 1.3, -6.6))
	Kit.Part(
		decor,
		"Crate",
		Vector3.new(2, 2, 2),
		at(12.3, 1, -6.6) * CFrame.Angles(0, 0.3, 0),
		P.LightWood,
		Enum.Material.WoodPlanks
	)
	Kit.Part(
		decor,
		"Crate",
		Vector3.new(1.3, 1.3, 1.3),
		at(12.2, 2.65, -6.4) * CFrame.Angles(0, -0.4, 0),
		P.LightWood,
		Enum.Material.WoodPlanks
	)

	-- Ingredient sources
	local sourcesFolder = Kit.Folder(plot, "Sources")
	local sources: { [string]: Model } = {
		Moonberry = buildMoonberry(sourcesFolder, at),
		Glowshroom = buildGlowshroom(sourcesFolder, at),
		Starflower = buildStarflower(sourcesFolder, at),
		FrostCrystal = buildFrostCrystal(sourcesFolder, at),
		EmberPepper = buildEmberPepper(sourcesFolder, at),
		CloudPuff = buildCloudPuff(sourcesFolder, at),
	}

	-- "For sale" lots for the sources that start locked
	local lotsFolder = Kit.Folder(plot, "Lots")
	local lots: { [string]: Model } = {}
	for ingredientId, spot in ShopBuilder.SourceSpots do
		local upgradeId = Config.Ingredients[ingredientId].UnlockedBy
		if upgradeId then
			lots[upgradeId] = buildLot(lotsFolder, at, upgradeId, spot, if spot.X < 0 then 1 else -1)
		end
	end

	-- Cauldron
	local goldParts: { BasePart } = {}
	local fireParts: { BasePart } = {}
	local cauldron = buildCauldron(plot, at, goldParts, fireParts)

	-- Upgrade visuals
	local features: { [string]: Model } = {
		DecorLights = buildDecorLights(plot, at, rng),
		DecorBanners = buildDecorBanners(plot, at, theme),
		DecorGold = buildDecorGold(plot, at),
		Shelf2 = buildShelfLevel(plot, at, "Shelf2", 5.1, rng),
		Shelf3 = buildShelfLevel(plot, at, "Shelf3", 7.4, rng),
	}

	local cheerStand = buildCheerStand(plot, at)
	local displaySlots = buildDisplay(plot, at)

	-- Invisible markers
	local counterFront = marker(plot, "CounterFront", at(0, 0, ShopBuilder.CounterFrontZ))
	local spawnPoint = marker(plot, "SpawnPoint", at(0, 0, 7))

	plot.PrimaryPart = floor
	plot.Parent = parent

	return {
		Model = plot,
		Sources = sources,
		Lots = lots,
		Features = features,
		SourcesFolder = sourcesFolder,
		LotsFolder = lotsFolder,
		Cauldron = cauldron,
		Sign = sign,
		CheerStand = cheerStand,
		DisplaySlots = displaySlots,
		CounterFront = counterFront,
		SpawnPoint = spawnPoint,
		GoldParts = goldParts,
		FireParts = fireParts,
	}
end

return ShopBuilder
