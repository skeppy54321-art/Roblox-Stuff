-- ShopBuilder (ModuleScript) — ServerScriptService.Modules.ShopBuilder
-- Builds shop plots and customers out of simple parts, so no free models are needed.
-- Visual only: no game rules live here.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local P = Config.Palette
local ShopBuilder = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder so it stands up

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function hitbox(parent: Instance, size: Vector3, cf: CFrame): Part
	return part(parent, "Hitbox", size, cf, Color3.new(1, 1, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	})
end

local function prompt(parent: Instance, name: string, actionText: string, objectText: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = actionText
	pp.ObjectText = objectText
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.PromptDistance
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

-- Builds one plot. `center` is on top of the baseplate (y = 0).
function ShopBuilder.BuildPlot(index: number, center: Vector3, parent: Instance): Model
	local origin = CFrame.new(center)
	-- Local helper: x/z across the plot, y = height above the floor top.
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, 1 + y, z)
	end

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("IsPlot", true)
	plot:SetAttribute("OwnerUserId", 0)

	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor.Parent = plot

	-- Floor
	part(decor, "Floor", Vector3.new(30, 1, 30), origin * CFrame.new(0, 0.5, 0), P.Floor, Enum.Material.WoodPlanks)

	-- Counter (customers stand in front of it at z = -11.5)
	part(decor, "Counter", Vector3.new(16, 3.5, 2.5), at(0, 1.75, -8), P.Wood, Enum.Material.Wood)
	part(decor, "CounterTop", Vector3.new(16.6, 0.3, 3), at(0, 3.6, -8), P.DarkWood, Enum.Material.Wood)

	-- Stall posts + striped awning
	for _, x in { -8.2, 8.2 } do
		part(decor, "Post", Vector3.new(0.8, 10, 0.8), at(x, 5, -8), P.DarkWood, Enum.Material.Wood)
	end
	local stripes = 8
	local stripeWidth = 17.2 / stripes
	for i = 1, stripes do
		local x = -8.6 + stripeWidth * (i - 0.5)
		local color = (i % 2 == 0) and P.AwningB or P.AwningA
		part(decor, "Awning", Vector3.new(stripeWidth, 0.3, 5), at(x, 10.2, -8.5) * CFrame.Angles(math.rad(12), 0, 0), color, Enum.Material.Fabric)
	end

	-- Sign above the awning (text faces outward and inward)
	local sign = part(plot, "Sign", Vector3.new(11, 2.2, 0.4), at(0, 12, -8.2), P.DarkWood, Enum.Material.Wood)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignGui" .. face.Name
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Name = "SignLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = P.Gold
		label.Text = "Empty Shop"
		label.Parent = gui
	end

	-- Back wall with a shelf of glowing bottles
	part(decor, "BackWall", Vector3.new(26, 8, 1), at(0, 4, 13), P.Wood, Enum.Material.Wood)
	part(decor, "Shelf", Vector3.new(14, 0.4, 1.4), at(0, 4, 12.1), P.DarkWood, Enum.Material.Wood)
	for i, x in { -5, -2.5, 0, 2.5, 5 } do
		local color = P.Bottles[(i - 1) % #P.Bottles + 1]
		part(decor, "Bottle", Vector3.new(1.4, 0.9, 0.9), at(x, 4.9, 12.1) * UPRIGHT, color, Enum.Material.Neon, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.1,
			CanCollide = false,
		})
		part(decor, "Cork", Vector3.new(0.4, 0.3, 0.4), at(x, 5.75, 12.1), P.DarkWood, Enum.Material.Wood, { CanCollide = false })
	end

	-- Low side fences
	for _, x in { -14.5, 14.5 } do
		part(decor, "Fence", Vector3.new(1, 2, 22), at(x, 1, 2), P.Wood, Enum.Material.Wood)
	end

	-- Ingredient sources
	local sources = Instance.new("Folder")
	sources.Name = "Sources"
	sources.Parent = plot

	-- Moonberry bush (purple berries = charges)
	local bush = Instance.new("Model")
	bush.Name = "Moonberry"
	bush:SetAttribute("Ingredient", "Moonberry")
	bush.Parent = sources
	part(bush, "Bush", Vector3.new(4, 4, 4), at(-9, 1.8, 6), P.Leaf, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	local berryPositions = { Vector3.new(-10, 2.4, 4.3), Vector3.new(-8.2, 2.9, 4.4), Vector3.new(-9.1, 1.4, 4.1) }
	for i, pos in berryPositions do
		part(bush, "Charge" .. i, Vector3.new(0.9, 0.9, 0.9), at(pos.X, pos.Y, pos.Z), Config.Ingredients.Moonberry.Color, Enum.Material.Neon, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
	end
	local bushBox = hitbox(bush, Vector3.new(4.5, 4, 4.5), at(-9, 2, 6))
	prompt(bushBox, "CollectPrompt", "Collect", "Moonberry")

	-- Glowshroom patch (glowing caps = charges)
	local patch = Instance.new("Model")
	patch.Name = "Glowshroom"
	patch:SetAttribute("Ingredient", "Glowshroom")
	patch.Parent = sources
	part(patch, "Dirt", Vector3.new(4.5, 0.3, 4.5), at(9, 0.15, 6), P.Dirt, Enum.Material.Ground)
	local shroomPositions = { Vector3.new(8, 0, 5), Vector3.new(10.2, 0, 6.3), Vector3.new(8.7, 0, 7.4) }
	for i, pos in shroomPositions do
		part(patch, "Stem", Vector3.new(1.4, 0.5, 0.5), at(pos.X, 1, pos.Z) * UPRIGHT, P.Stem, nil, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		part(patch, "Charge" .. i, Vector3.new(0.6, 1.8, 1.8), at(pos.X, 1.85, pos.Z) * UPRIGHT, Config.Ingredients.Glowshroom.Color, Enum.Material.Neon, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
	end
	local patchBox = hitbox(patch, Vector3.new(4.5, 3, 4.5), at(9, 1.5, 6))
	prompt(patchBox, "CollectPrompt", "Collect", "Glowshroom")

	-- Cauldron
	local cauldron = Instance.new("Model")
	cauldron.Name = "Cauldron"
	cauldron:SetAttribute("BrewEndTime", 0)
	cauldron:SetAttribute("BrewDuration", 0)
	cauldron.Parent = plot
	for i = 1, 3 do
		local angle = math.rad(120 * i)
		part(cauldron, "Leg", Vector3.new(0.5, 0.8, 0.5), at(math.cos(angle) * 1.8, 0.4, 1 + math.sin(angle) * 1.8), P.Cauldron, Enum.Material.Metal)
	end
	local fire = part(cauldron, "Fire", Vector3.new(2.2, 0.6, 2.2), at(0, 0.4, 1), P.Fire, Enum.Material.Neon, { CanCollide = false })
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = P.Fire
	light.Range = 12
	light.Brightness = 2
	light.Parent = fire
	part(cauldron, "Pot", Vector3.new(3, 5, 5), at(0, 2.3, 1) * UPRIGHT, P.Cauldron, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(cauldron, "Rim", Vector3.new(0.4, 5.4, 5.4), at(0, 3.85, 1) * UPRIGHT, P.Cauldron, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(cauldron, "Liquid", Vector3.new(0.2, 4.4, 4.4), at(0, 3.95, 1) * UPRIGHT, P.Liquid, Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	local bubblePart = part(cauldron, "BubblePart", Vector3.new(3.5, 0.1, 3.5), at(0, 4.1, 1), P.Liquid, nil, {
		Transparency = 1,
		CanCollide = false,
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
	local cauldronBox = hitbox(cauldron, Vector3.new(5.5, 4.5, 5.5), at(0, 2.5, 1))
	prompt(cauldronBox, "BrewPrompt", "Brew", Config.Recipes[Config.PrototypeRecipe].DisplayName)

	-- Invisible markers
	part(plot, "CustomerSpot", Vector3.new(1, 1, 1), at(0, 0, -11.5), Color3.new(1, 1, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	part(plot, "SpawnPoint", Vector3.new(1, 1, 1), at(0, 0, 7), Color3.new(1, 1, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	plot.PrimaryPart = decor:FindFirstChild("Floor") :: BasePart
	plot.Parent = parent
	return plot
end

-- Builds a simple blocky customer standing at `spot`, facing the counter.
function ShopBuilder.BuildCustomer(spot: CFrame, wantsText: string): Model
	local base = spot * CFrame.Angles(0, math.pi, 0) -- face +Z (toward the counter)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local rng = Random.new()
	local shirt = P.Shirts[rng:NextInteger(1, #P.Shirts)]
	local skin = P.Skin[rng:NextInteger(1, #P.Skin)]
	local hatColor = P.Bottles[rng:NextInteger(1, #P.Bottles)]
	local noCollide = { CanCollide = false }

	local customer = Instance.new("Model")
	customer.Name = "Customer"
	customer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	part(customer, "LegL", Vector3.new(0.9, 2, 0.9), at(-0.5, 1, 0), P.DarkWood, nil, noCollide)
	part(customer, "LegR", Vector3.new(0.9, 2, 0.9), at(0.5, 1, 0), P.DarkWood, nil, noCollide)
	local torso = part(customer, "Torso", Vector3.new(2.2, 2, 1.1), at(0, 3, 0), shirt, nil, noCollide)
	part(customer, "ArmL", Vector3.new(0.8, 2, 0.8), at(-1.55, 3, 0), shirt, nil, noCollide)
	part(customer, "ArmR", Vector3.new(0.8, 2, 0.8), at(1.55, 3, 0), shirt, nil, noCollide)

	-- Head parts are grouped so effects can scale them together.
	local headGroup = Instance.new("Model")
	headGroup.Name = "HeadGroup"
	headGroup.Parent = customer
	local head = part(headGroup, "Head", Vector3.new(1.5, 1.5, 1.5), at(0, 4.75, 0), skin, nil, noCollide)
	part(headGroup, "EyeL", Vector3.new(0.25, 0.35, 0.05), at(-0.35, 4.9, -0.77), Color3.new(0, 0, 0), nil, noCollide)
	part(headGroup, "EyeR", Vector3.new(0.25, 0.35, 0.05), at(0.35, 4.9, -0.77), Color3.new(0, 0, 0), nil, noCollide)
	part(headGroup, "Mouth", Vector3.new(0.6, 0.12, 0.05), at(0, 4.4, -0.77), Color3.new(0, 0, 0), nil, noCollide)
	part(headGroup, "HatBrim", Vector3.new(1.8, 0.2, 1.8), at(0, 5.6, 0), hatColor, nil, noCollide)
	part(headGroup, "HatTop", Vector3.new(1.1, 0.8, 1.1), at(0, 6.1, 0), hatColor, nil, noCollide)
	headGroup.WorldPivot = at(0, 4, 0) -- bottom of the head, so it grows upward

	-- Speech bubble
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromOffset(180, 46)
	bubble.StudsOffset = Vector3.new(0, 3.4, 0)
	bubble.MaxDistance = 70
	bubble.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = P.PanelLight
	label.TextColor3 = P.TextDark
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = wantsText
	label.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label

	prompt(torso, "SellPrompt", "Sell Potion", "Customer")

	customer.PrimaryPart = torso
	return customer
end

return ShopBuilder
