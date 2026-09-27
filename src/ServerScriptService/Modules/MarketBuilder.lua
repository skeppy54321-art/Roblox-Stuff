--!strict
-- MarketBuilder (ModuleScript) — ServerScriptService.Modules.MarketBuilder
-- Builds everything around the shops: grass, the cobblestone plaza, the potion
-- fountain, lamp posts with string lights, benches, trees and distant hills.
-- Visual only: no game rules live here.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local CustomerBuilder = require(script.Parent:WaitForChild("CustomerBuilder"))

local P = Config.Palette
local W = Config.World
local WOOD = Enum.Material.Wood
local NEON = Enum.Material.Neon

local MarketBuilder = {}

local PLANTER_FLOWERS = {
	Color3.fromRGB(255, 130, 180),
	Color3.fromRGB(255, 240, 250),
	Color3.fromRGB(255, 215, 90),
	Color3.fromRGB(190, 140, 255),
}

export type MarketParts = {
	Model: Model,
	Spawn: SpawnLocation,
	Statue: BasePart, -- the giant glowing potion on the fountain (clients cycle its color)
	Board: BasePart, -- the Market Stars board (SocialService draws on its front)
}

local function flat(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	top: number,
	color: Color3,
	material: Enum.Material
): Part
	return Kit.Cylinder(parent, name, height, diameter, CFrame.new(0, top - height / 2, 0), color, material, {
		CanCollide = true,
		CanQuery = true,
	})
end

-- Angle (radians) of shop `index` around the plaza, measured the same way World.GetPlotCFrame does.
local function plotAngle(index: number): number
	return W.PlotAngleOffset + (index - 1) * (2 * math.pi / W.PlotCount)
end

local function polar(angle: number, radius: number, y: number): Vector3
	return Vector3.new(math.sin(angle) * radius, y, math.cos(angle) * radius)
end

------------------------------------------------------------------
-- Ground (reuses the template Baseplate if there is one)
------------------------------------------------------------------

local function prepareGround(market: Model)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = P.Grass
		baseplate.Material = Enum.Material.Grass
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end
	else
		Kit.Part(
			market,
			"Ground",
			Vector3.new(W.GroundSize, 2, W.GroundSize),
			CFrame.new(0, W.GroundHeight - 1, 0),
			P.Grass,
			Enum.Material.Grass
		)
	end
	-- The template's own spawn pad would sit inside the fountain: switch it off.
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child.Name ~= "MarketSpawn" then
			child.Enabled = false
			child.Transparency = 1
			child.CanCollide = false
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal:Destroy()
				end
			end
		end
	end
end

------------------------------------------------------------------
-- Plaza + paths
------------------------------------------------------------------

local function buildPlaza(market: Model)
	local plaza = Kit.Model(market, "Plaza")
	local r = W.PlazaRadius
	flat(plaza, "Plaza", r * 2, 0.3, 0.3, P.Cobble, Enum.Material.Cobblestone)
	flat(plaza, "PlazaBand", 34, 0.31, 0.31, P.DarkStone, Enum.Material.Cobblestone)
	flat(plaza, "PlazaInner", 31, 0.32, 0.32, P.Stone, Enum.Material.Pavement)
	-- a path from the plaza to every shop's counter
	for i = 1, W.PlotCount do
		local angle = plotAngle(i)
		local from, to = polar(angle, r - 2, 0.145), polar(angle, W.PlotRingRadius - W.PlotSize / 2 + 1, 0.145)
		local length = (to - from).Magnitude
		local cf = CFrame.lookAt((from + to) / 2, to)
		Kit.Part(plaza, "Path", Vector3.new(11, 0.29, length), cf, P.Cobble, Enum.Material.Cobblestone)
		for _, side in { -1, 1 } do
			Kit.Decor(
				plaza,
				"PathEdge",
				Vector3.new(0.8, 0.36, length),
				cf * CFrame.new(side * 5.8, 0.03, 0),
				P.DarkStone,
				Enum.Material.Cobblestone
			)
			-- flower planters where the path meets the plaza
			local planter = CFrame.lookAt(polar(angle, r + 1.5, 0), Vector3.zero) * CFrame.new(side * 8.2, 0, 0)
			Kit.Part(
				plaza,
				"Planter",
				Vector3.new(3.2, 1.2, 3.2),
				planter * CFrame.new(0, 0.6, 0),
				P.Wood,
				Enum.Material.WoodPlanks
			)
			Kit.Decor(
				plaza,
				"PlanterSoil",
				Vector3.new(2.8, 0.1, 2.8),
				planter * CFrame.new(0, 1.22, 0),
				P.Dirt,
				Enum.Material.Ground
			)
			Kit.Ball(
				plaza,
				"PlanterBush",
				2.4,
				(planter * CFrame.new(0, 1.9, 0)).Position,
				P.LeafLight,
				Enum.Material.Grass
			)
			for k, color in PLANTER_FLOWERS do
				local a = k * math.pi / 2 + angle
				local position = (planter * CFrame.new(math.cos(a) * 0.9, 2.6, math.sin(a) * 0.9)).Position
				Kit.Ball(plaza, "Flower", 0.55, position, color, Enum.Material.SmoothPlastic)
			end
		end
	end
	return plaza
end

------------------------------------------------------------------
-- Fountain with a giant potion on top
------------------------------------------------------------------

local function buildFountain(market: Model): BasePart
	local fountain = Kit.Model(market, "Fountain")
	local stone = Color3.fromRGB(214, 204, 190)
	flat(fountain, "Basin", 18, 1.6, 1.6, stone, Enum.Material.Marble)
	Kit.Cylinder(
		fountain,
		"Water",
		0.1,
		16.8,
		CFrame.new(0, 1.62, 0),
		P.Water,
		Enum.Material.Glass,
		{ Transparency = 0.35 }
	)
	for i = 1, 20 do
		local angle = (i / 20) * math.pi * 2
		Kit.Decor(
			fountain,
			"Lip",
			Vector3.new(2.6, 0.5, 1.2),
			CFrame.lookAt(polar(angle, 8.7, 1.85), Vector3.new(0, 1.85, 0)),
			stone,
			Enum.Material.Marble
		)
	end
	Kit.Cylinder(
		fountain,
		"Pillar",
		3,
		3.4,
		CFrame.new(0, 3, 0),
		stone,
		Enum.Material.Marble,
		{ CanCollide = true, CanQuery = true }
	)
	Kit.Cylinder(fountain, "UpperBasin", 0.8, 8, CFrame.new(0, 4.6, 0), stone, Enum.Material.Marble)
	Kit.Cylinder(
		fountain,
		"UpperWater",
		0.1,
		7.2,
		CFrame.new(0, 5.03, 0),
		P.Water,
		Enum.Material.Glass,
		{ Transparency = 0.35 }
	)
	Kit.Cylinder(fountain, "StatueBase", 0.8, 2.6, CFrame.new(0, 5.4, 0), stone, Enum.Material.Marble)

	-- the giant potion
	local statue = Kit.Ball(fountain, "PotionGlass", 4.6, Vector3.new(0, 7.9, 0), Color3.fromRGB(230, 110, 255), NEON, {
		Transparency = 0.08,
		CastShadow = false,
	})
	Kit.Cylinder(
		fountain,
		"PotionNeck",
		1.8,
		1.6,
		CFrame.new(0, 10.7, 0),
		Color3.fromRGB(200, 230, 255),
		Enum.Material.Glass,
		{ Transparency = 0.3 }
	)
	Kit.Cylinder(fountain, "PotionCork", 1, 1.9, CFrame.new(0, 11.9, 0), P.LightWood, WOOD)
	Kit.Light(statue, Color3.fromRGB(230, 130, 255), 26, 2.2)
	Kit.Sparkles(statue, Color3.fromRGB(255, 230, 255), 6)

	-- water spraying up from the upper basin and falling back down
	local spout = Kit.Decor(fountain, "Spout", Vector3.new(6, 0.2, 6), CFrame.new(0, 5.1, 0), P.Water, nil, {
		Transparency = 1,
		CastShadow = false,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(190, 240, 255))
	spray.LightEmission = 0.4
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	spray.Lifetime = NumberRange.new(0.7, 1)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Rate = 40
	spray.Parent = spout
	return statue
end

------------------------------------------------------------------
-- Lamp posts, string lights, benches
------------------------------------------------------------------

local function buildLampPost(parent: Instance, base: Vector3): Vector3
	local post = Kit.Model(parent, "LampPost")
	local cf = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
	Kit.Cylinder(
		post,
		"Foot",
		0.7,
		1.4,
		cf * CFrame.new(0, 0.35, 0),
		P.Metal,
		Enum.Material.Metal,
		{ CanCollide = true, CanQuery = true }
	)
	Kit.Cylinder(
		post,
		"Pole",
		9.5,
		0.45,
		cf * CFrame.new(0, 5, 0),
		P.Metal,
		Enum.Material.Metal,
		{ CanCollide = true, CanQuery = true }
	)
	Kit.Ball(post, "Knob", 0.7, base + Vector3.new(0, 9.9, 0), P.Metal, Enum.Material.Metal)
	Kit.Decor(post, "Arm", Vector3.new(0.25, 0.25, 1.8), cf * CFrame.new(0, 9.3, -0.8), P.Metal, Enum.Material.Metal)
	Kit.Lantern(post, (cf * CFrame.new(0, 9.2, -1.6)).Position, 1.3, 20)
	return base + Vector3.new(0, 9.8, 0) -- where string lights attach
end

local function stringLights(parent: Instance, a: Vector3, b: Vector3, sag: number, spacing: number)
	local count = math.max(2, math.floor((b - a).Magnitude / spacing))
	local colors = {
		Color3.fromRGB(255, 210, 120),
		Color3.fromRGB(255, 150, 190),
		Color3.fromRGB(150, 220, 255),
		Color3.fromRGB(190, 255, 150),
	}
	local previous = a
	for i = 1, count do
		local t = i / count
		local point = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		Kit.Rod(parent, "Wire", previous, point, 0.08, P.DarkWood)
		if i < count then
			Kit.Ball(
				parent,
				"Bulb",
				0.5,
				point - Vector3.new(0, 0.3, 0),
				colors[i % #colors + 1],
				NEON,
				{ CastShadow = false }
			)
		end
		previous = point
	end
end

local function buildBench(parent: Instance, cf: CFrame)
	local bench = Kit.Model(parent, "Bench")
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(4.4, 0.35, 1.4)
	seat.CFrame = cf * CFrame.new(0, 1.3, 0)
	seat.Color = P.LightWood
	seat.Material = WOOD
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = bench
	Kit.Decor(
		bench,
		"Back",
		Vector3.new(4.4, 1.2, 0.25),
		cf * CFrame.new(0, 2.1, 0.62) * CFrame.Angles(math.rad(-10), 0, 0),
		P.LightWood,
		WOOD
	)
	for _, x in { -1.8, 1.8 } do
		Kit.Decor(bench, "Leg", Vector3.new(0.3, 1.2, 1.2), cf * CFrame.new(x, 0.6, 0), P.Metal, Enum.Material.Metal)
	end
end

------------------------------------------------------------------
-- Nature
------------------------------------------------------------------

local function roundTree(parent: Instance, base: Vector3, scale: number, rng: Random)
	local tree = Kit.Model(parent, "Tree")
	local height = 6 * scale
	Kit.Cylinder(tree, "Trunk", height, 1.3 * scale, CFrame.new(base + Vector3.new(0, height / 2, 0)), P.Trunk, WOOD, {
		CanCollide = true,
		CanQuery = true,
	})
	local greens = { P.Leaf, P.LeafLight, P.LeafDark }
	local blobs = {
		{ 0, height + 1.5 * scale, 0, 6.5 },
		{ 1.8, height + 0.5 * scale, 1, 4.6 },
		{ -1.7, height + 0.8 * scale, -0.8, 4.8 },
		{ 0.4, height + 3.2 * scale, -0.6, 4 },
	}
	for _, b in blobs do
		local offset = Vector3.new(b[1] * scale, b[2], b[3] * scale)
		Kit.Ball(
			tree,
			"Leaves",
			b[4] * scale,
			base + offset,
			Kit.Vary(greens[rng:NextInteger(1, #greens)], rng),
			Enum.Material.Grass
		)
	end
end

local function pineTree(parent: Instance, base: Vector3, scale: number, rng: Random)
	local tree = Kit.Model(parent, "Pine")
	Kit.Cylinder(
		tree,
		"Trunk",
		3 * scale,
		1 * scale,
		CFrame.new(base + Vector3.new(0, 1.5 * scale, 0)),
		P.Trunk,
		WOOD,
		{
			CanCollide = true,
			CanQuery = true,
		}
	)
	local color = Kit.Vary(P.LeafDark, rng)
	local tiers = { { 7, 2.2, 3.2 }, { 5.4, 2, 5.2 }, { 3.6, 1.8, 7 }, { 1.8, 1.6, 8.6 } }
	for _, t in tiers do
		Kit.Cylinder(
			tree,
			"Needles",
			t[2] * scale,
			t[1] * scale,
			CFrame.new(base + Vector3.new(0, t[3] * scale, 0)),
			color,
			Enum.Material.Grass
		)
	end
end

local function bush(parent: Instance, base: Vector3, rng: Random)
	local size = rng:NextNumber(2, 3.2)
	Kit.Ball(
		parent,
		"Bush",
		size,
		base + Vector3.new(0, size * 0.35, 0),
		Kit.Vary(P.LeafLight, rng),
		Enum.Material.Grass
	)
	if rng:NextNumber() < 0.6 then
		local flowerColors =
			{ Color3.fromRGB(255, 130, 180), Color3.fromRGB(255, 240, 250), Color3.fromRGB(255, 215, 90) }
		for _ = 1, 3 do
			local offset = Vector3.new(
				rng:NextNumber(-0.6, 0.6),
				size * 0.35 + rng:NextNumber(0.3, 0.8),
				rng:NextNumber(-0.6, 0.6)
			)
			Kit.Ball(
				parent,
				"Flower",
				0.45,
				base + offset,
				flowerColors[rng:NextInteger(1, #flowerColors)],
				Enum.Material.SmoothPlastic
			)
		end
	end
end

-- True if `position` is clear of the plaza, the paths and every shop (with `margin` studs to spare).
local function isClear(position: Vector3, margin: number): boolean
	local flatPos = Vector3.new(position.X, 0, position.Z)
	if flatPos.Magnitude < W.PlazaRadius + margin then
		return false
	end
	for i = 1, W.PlotCount do
		local local_ = W.GetPlotCFrame(i):PointToObjectSpace(flatPos)
		local half = W.PlotSize / 2 + margin
		if math.abs(local_.X) < half and local_.Z > -W.PlotRingRadius - margin and local_.Z < half then
			return false -- inside the shop, or on the path between the shop and the plaza
		end
	end
	return true
end

local function buildNature(market: Model, rng: Random)
	local nature = Kit.Model(market, "Nature")
	-- one big tree between each pair of shops
	for i = 1, W.PlotCount do
		local angle = plotAngle(i) + math.pi / W.PlotCount
		roundTree(nature, polar(angle, W.PlotRingRadius - 4, 0), rng:NextNumber(1.05, 1.25), rng)
		bush(nature, polar(angle + 0.05, W.PlazaRadius + 3, 0), rng)
		bush(nature, polar(angle - 0.06, W.PlazaRadius + 4, 0), rng)
	end
	-- a forest ring beyond the shops
	local placed = 0
	local tries = 0
	while placed < 34 and tries < 400 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(W.PlotRingRadius + 24, W.PlotRingRadius + 75)
		local position = polar(angle, radius, 0)
		if isClear(position, 6) then
			placed += 1
			if rng:NextNumber() < 0.45 then
				pineTree(nature, position, rng:NextNumber(0.9, 1.5), rng)
			else
				roundTree(nature, position, rng:NextNumber(0.9, 1.4), rng)
			end
		end
	end
	-- rolling hills on the horizon
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local size = rng:NextNumber(70, 110)
		local position = polar(angle, W.PlotRingRadius + 150 + rng:NextNumber(0, 40), -size * 0.3)
		Kit.Ball(nature, "Hill", size, position, Kit.Vary(P.Grass, rng, 0.05), Enum.Material.Grass)
	end
end

------------------------------------------------------------------
-- The whole market (except the shops)
------------------------------------------------------------------

function MarketBuilder.Build(parent: Instance): MarketParts
	local rng = Random.new(20260927)
	local market = Kit.Model(nil, "Town")
	prepareGround(market)
	buildPlaza(market)
	local statue = buildFountain(market)

	-- lamp posts between the paths, joined by string lights
	local lights = Kit.Model(market, "Lights")
	local tops = {}
	for i = 1, W.PlotCount do
		local angle = plotAngle(i) + math.pi / W.PlotCount
		table.insert(tops, buildLampPost(lights, polar(angle, W.PlazaRadius - 1.5, 0.3)))
	end
	for i, top in tops do
		stringLights(lights, top, tops[i % #tops + 1], 2.2, 2.6)
	end

	-- benches facing the fountain
	for i = 1, W.PlotCount do
		local angle = plotAngle(i) + math.pi / W.PlotCount
		local position = polar(angle, 14, 0.32)
		buildBench(market, CFrame.lookAt(position, Vector3.new(0, 0.32, 0)))
	end

	-- welcome sign by the spawn
	local gapAngle = plotAngle(4) + math.pi / W.PlotCount
	local signCf = CFrame.lookAt(polar(gapAngle, 25, 0.3), Vector3.new(0, 0.3, 0))
	for _, x in { -3.2, 3.2 } do
		Kit.Part(market, "SignPost", Vector3.new(0.6, 7, 0.6), signCf * CFrame.new(x, 3.5, 0), P.DarkWood, WOOD)
	end
	local board =
		Kit.Part(market, "WelcomeSign", Vector3.new(8, 2.6, 0.4), signCf * CFrame.new(0, 5.6, 0), P.DarkWood, WOOD)
	Kit.Decor(
		market,
		"WelcomeTrim",
		Vector3.new(8.4, 3, 0.3),
		signCf * CFrame.new(0, 5.6, 0),
		P.Gold,
		Enum.Material.Foil
	)
	Kit.SurfaceText(board, Enum.NormalId.Front, "Potion Market", P.Gold, 40)
	Kit.SurfaceText(board, Enum.NormalId.Back, "Potion Market", P.Gold, 40)

	-- Market Stars board, across the plaza from the welcome sign
	local boardAngle = plotAngle(1) + math.pi / W.PlotCount
	local boardCf = CFrame.lookAt(polar(boardAngle, 24, 0.3), Vector3.new(0, 0.3, 0))
	local stars = Kit.Model(market, "MarketStars")
	for _, x in { -5.9, 5.9 } do
		Kit.Part(stars, "BoardPost", Vector3.new(0.7, 10.2, 0.7), boardCf * CFrame.new(x, 5.1, 0.1), P.DarkWood, WOOD)
		Kit.Lantern(stars, (boardCf * CFrame.new(x, 9.9, -0.9)).Position, 0.8, 14)
	end
	Kit.Decor(stars, "BoardFrame", Vector3.new(11.8, 8, 0.4), boardCf * CFrame.new(0, 5.6, 0.15), P.DarkWood, WOOD)
	local starsBoard = Kit.Part(
		stars,
		"StarsBoard",
		Vector3.new(11, 7.2, 0.3),
		boardCf * CFrame.new(0, 5.6, 0),
		P.PanelLight,
		Enum.Material.SmoothPlastic
	)
	Kit.Decor(
		stars,
		"BoardRoof",
		Vector3.new(13, 0.35, 2.2),
		boardCf * CFrame.new(0, 10.1, -0.2) * CFrame.Angles(math.rad(-12), 0, 0),
		P.Roof,
		Enum.Material.ClayRoofTiles
	)
	Kit.Decor(
		stars,
		"BoardArm",
		Vector3.new(12.6, 0.3, 0.3),
		boardCf * CFrame.new(0, 9.75, -0.9),
		P.Metal,
		Enum.Material.Metal
	)

	-- fireflies drifting over the plaza
	local fireflyBox = Kit.Decor(
		market,
		"Fireflies",
		Vector3.new(W.PlazaRadius * 2, 6, W.PlazaRadius * 2),
		CFrame.new(0, 4, 0),
		P.Gold,
		nil,
		{
			Transparency = 1,
			CastShadow = false,
		}
	)
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Fireflies"
	fireflies.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.22),
		NumberSequenceKeypoint.new(0.8, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Speed = NumberRange.new(0.4, 1.2)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.RotSpeed = NumberRange.new(-40, 40)
	fireflies.Rate = 8
	fireflies.Parent = fireflyBox

	-- townsfolk: built once here, then every client walks them around (ClientMain.Townsfolk)
	local folk = Kit.Folder(market, "Townsfolk")
	for i = 1, W.Townsfolk do
		local angle = (i / W.Townsfolk) * math.pi * 2 + 0.35
		local spot = CFrame.lookAt(polar(angle, 20, 0.3), Vector3.new(0, 0.3, 0))
		local villager =
			CustomerBuilder.Build(spot, { Vip = false, WantsText = "", WantsColor = P.Gold, Bubble = false })
		villager.Name = "Villager"
		villager.Parent = folk
	end

	-- nature last (it checks what is already taken)
	buildNature(market, rng)

	-- where players appear before being moved into their shop
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MarketSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(polar(gapAngle, 20, -0.2), Vector3.new(0, -0.2, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	market.Parent = parent
	return { Model = market, Spawn = spawn, Statue = statue, Board = starsBoard }
end

return MarketBuilder
