--!strict
-- CustomerBuilder (ModuleScript) — ServerScriptService.Modules.CustomerBuilder
-- Builds a blocky customer out of parts with random skin, clothes, hair and hat,
-- so the market looks busy and varied. Visual only: no game rules live here.
--
-- Part names matter to the client:
--   HeadGroup (Model)          scaled by effects; its pivot is the bottom of the head
--   LegL/ShoeL, LegR/ShoeR     swing from the hips while walking
--   ArmL/HandL, ArmR/HandR     swing from the shoulders while walking
--   Torso                      PrimaryPart; holds the SellPrompt
--   Bubble (BillboardGui)      speech bubble on the head; its label is "Text"

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local P = Config.Palette
local BLACK = Color3.new(0.08, 0.06, 0.08)
local FLOWER_COLORS = { Color3.fromRGB(255, 130, 180), Color3.fromRGB(255, 245, 250), Color3.fromRGB(255, 215, 90) }

export type Options = {
	Vip: boolean,
	WantsText: string,
	WantsColor: Color3,
}

local CustomerBuilder = {}

type At = (x: number, y: number, z: number) -> CFrame

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

local function darker(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * (1 - amount))
end

------------------------------------------------------------------
-- Heads: hair, hats, faces (all inside HeadGroup)
------------------------------------------------------------------

local function buildFace(head: Model, at: At, skin: Color3, hair: Color3, rng: Random)
	for _, x in { -0.35, 0.35 } do
		Kit.Decor(head, "Eye", Vector3.new(0.25, 0.35, 0.05), at(x, 4.9, -0.77), BLACK)
		Kit.Decor(head, "EyeShine", Vector3.new(0.09, 0.09, 0.05), at(x + 0.05, 4.98, -0.8), Color3.new(1, 1, 1))
	end
	Kit.Decor(head, "Nose", Vector3.new(0.24, 0.24, 0.14), at(0, 4.62, -0.8), darker(skin, 0.1))
	Kit.Decor(head, "Mouth", Vector3.new(0.55, 0.11, 0.05), at(0, 4.36, -0.77), BLACK)
	if rng:NextNumber() < 0.5 then
		for _, x in { -0.52, 0.52 } do
			Kit.Decor(head, "Cheek", Vector3.new(0.3, 0.17, 0.05), at(x, 4.56, -0.77), Color3.fromRGB(255, 140, 150))
		end
	end
	if rng:NextNumber() < 0.2 then
		local lensTurn = CFrame.Angles(0, math.rad(90), 0) -- disc faces forward
		for _, x in { -0.35, 0.35 } do
			local lens = Kit.Decor(
				head,
				"Lens",
				Vector3.new(0.06, 0.55, 0.55),
				at(x, 4.9, -0.82) * lensTurn,
				BLACK,
				nil,
				{ Transparency = 0.35 }
			)
			lens.Shape = Enum.PartType.Cylinder
		end
		Kit.Decor(head, "GlassesBridge", Vector3.new(0.25, 0.07, 0.05), at(0, 4.95, -0.83), BLACK)
	end
	if rng:NextNumber() < 0.15 then
		Kit.Decor(head, "Beard", Vector3.new(1.3, 0.6, 0.2), at(0, 4.2, -0.78), hair)
		Kit.Decor(head, "Mustache", Vector3.new(0.8, 0.14, 0.08), at(0, 4.5, -0.83), hair)
	end
end

local function buildHair(head: Model, at: At, hair: Color3, rng: Random)
	local style = rng:NextInteger(1, 4)
	if style == 1 then
		return -- bald (hats still look fine)
	end
	Kit.Decor(head, "Hair", Vector3.new(1.6, 0.35, 1.6), at(0, 5.62, 0.02), hair)
	if style == 2 then -- short
		Kit.Decor(head, "HairBack", Vector3.new(1.6, 1, 0.3), at(0, 5.15, 0.78), hair)
	elseif style == 3 then -- long
		Kit.Decor(head, "HairBack", Vector3.new(1.6, 2, 0.35), at(0, 4.6, 0.8), hair)
		for _, x in { -0.8, 0.8 } do
			Kit.Decor(head, "HairSide", Vector3.new(0.2, 1.4, 1.2), at(x, 4.9, 0.2), hair)
		end
	else -- bun
		Kit.Decor(head, "HairBack", Vector3.new(1.6, 1, 0.3), at(0, 5.15, 0.78), hair)
		Kit.Ball(head, "Bun", 0.8, at(0, 5.95, 0.55).Position, hair, Enum.Material.SmoothPlastic)
	end
end

local function buildHat(head: Model, at: At, rng: Random)
	local color = pick(P.Bottles, rng)
	local style = rng:NextInteger(1, 5)
	if style == 1 then -- wizard hat
		Kit.Cylinder(head, "HatBrim", 0.15, 2.4, at(0, 5.55, 0), color)
		local tiers = { { 1.5, 5.9 }, { 1.1, 6.45 }, { 0.7, 7 }, { 0.35, 7.45 } }
		for _, tier in tiers do
			Kit.Cylinder(head, "HatTier", 0.6, tier[1], at(0, tier[2], 0), color)
		end
		Kit.Ball(
			head,
			"HatStar",
			0.4,
			at(0.35, 6.3, -0.55).Position,
			P.Gold,
			Enum.Material.Neon,
			{ CastShadow = false }
		)
	elseif style == 2 then -- top hat
		Kit.Cylinder(head, "HatBrim", 0.15, 2.2, at(0, 5.55, 0), BLACK)
		Kit.Cylinder(head, "HatCrown", 1.3, 1.4, at(0, 6.25, 0), BLACK)
		Kit.Cylinder(head, "HatBand", 0.25, 1.45, at(0, 5.8, 0), color)
	elseif style == 3 then -- beanie with a pom-pom
		Kit.Ball(head, "Beanie", 1.7, at(0, 5.35, 0.05).Position, color, Enum.Material.Fabric)
		Kit.Ball(head, "PomPom", 0.5, at(0, 6.25, 0.05).Position, P.PanelLight, Enum.Material.Fabric)
	elseif style == 4 then -- flower crown
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local position = at(math.cos(angle) * 0.8, 5.55, math.sin(angle) * 0.8).Position
			if i % 2 == 0 then
				Kit.Ball(head, "Leaf", 0.35, position, P.LeafLight, Enum.Material.SmoothPlastic)
			else
				Kit.Ball(head, "Flower", 0.45, position, pick(FLOWER_COLORS, rng), Enum.Material.SmoothPlastic)
			end
		end
	end
	-- style 5: no hat
end

local function buildCrown(head: Model, at: At)
	Kit.Cylinder(head, "CrownBand", 0.4, 1.75, at(0, 5.7, 0), P.Gold, Enum.Material.Foil)
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		Kit.Decor(
			head,
			"CrownSpike",
			Vector3.new(0.28, 0.5, 0.28),
			at(math.cos(angle) * 0.72, 6.1, math.sin(angle) * 0.72),
			P.Gold,
			Enum.Material.Foil
		)
	end
	local gems = { Color3.fromRGB(255, 70, 90), Color3.fromRGB(80, 170, 255), Color3.fromRGB(90, 230, 120) }
	for i, x in { -0.45, 0, 0.45 } do
		Kit.Ball(head, "Gem", 0.25, at(x, 5.7, -0.86).Position, gems[i], Enum.Material.Neon, { CastShadow = false })
	end
end

------------------------------------------------------------------
-- Speech bubble
------------------------------------------------------------------

local function buildBubble(headPart: BasePart, options: Options)
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromOffset(220, 58)
	bubble.StudsOffset = Vector3.new(0, 3.6, 0)
	bubble.MaxDistance = 80
	bubble.LightInfluence = 0
	bubble.Parent = headPart

	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.new(1, 0, 1, -8)
	frame.BackgroundColor3 = P.PanelCream
	frame.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = if options.Vip then P.Gold else P.TextDark
	stroke.Thickness = if options.Vip then 3 else 2
	stroke.Parent = frame

	-- little tail pointing down at the customer
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 1, -9)
	tail.Size = UDim2.fromOffset(14, 14)
	tail.Rotation = 45
	tail.BackgroundColor3 = P.PanelCream
	tail.BorderSizePixel = 0
	tail.ZIndex = 0
	tail.Parent = bubble

	-- potion swatch
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.AnchorPoint = Vector2.new(0, 0.5)
	swatch.Position = UDim2.new(0, 8, 0.5, 0)
	swatch.Size = UDim2.fromOffset(28, 28)
	swatch.BackgroundColor3 = options.WantsColor
	swatch.Parent = frame
	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(0.5, 0)
	swatchCorner.Parent = swatch
	local swatchStroke = Instance.new("UIStroke")
	swatchStroke.Color = P.TextDark
	swatchStroke.Thickness = 2
	swatchStroke.Parent = swatch

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(42, 4)
	label.Size = UDim2.new(1, -50, 1, -8)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = P.TextDark
	label.Text = options.WantsText
	label.Parent = frame

	if options.Vip then
		local vip = Instance.new("TextLabel")
		vip.Name = "VipTag"
		vip.AnchorPoint = Vector2.new(0.5, 0.5)
		vip.Position = UDim2.new(1, -6, 0, 2)
		vip.Size = UDim2.fromOffset(42, 20)
		vip.BackgroundColor3 = P.Gold
		vip.Font = Enum.Font.FredokaOne
		vip.TextScaled = true
		vip.TextColor3 = P.TextDark
		vip.Text = "VIP"
		vip.ZIndex = 2
		vip.Parent = frame
		local vipCorner = Instance.new("UICorner")
		vipCorner.CornerRadius = UDim.new(0.5, 0)
		vipCorner.Parent = vip
	end
end

------------------------------------------------------------------
-- Whole customer
------------------------------------------------------------------

-- Builds a customer standing at `spot` (feet on it), facing +Z of the spot (toward the counter).
function CustomerBuilder.Build(spot: CFrame, options: Options): Model
	local rng = Random.new()
	local base = spot * CFrame.Angles(0, math.pi, 0)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local skin = pick(P.Skin, rng)
	local shirt = pick(P.Shirts, rng)
	local pants = pick(P.Pants, rng)
	local hair = pick(P.Hair, rng)

	local customer = Kit.Model(nil, "Customer")
	customer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	customer:SetAttribute("Vip", options.Vip)

	-- legs + shoes
	for _, side in { { Name = "L", X = -0.5 }, { Name = "R", X = 0.5 } } do
		Kit.Decor(customer, "Leg" .. side.Name, Vector3.new(0.9, 1.8, 0.9), at(side.X, 1.2, 0), pants)
		Kit.Decor(
			customer,
			"Shoe" .. side.Name,
			Vector3.new(0.95, 0.4, 1.15),
			at(side.X, 0.2, -0.1),
			darker(pants, 0.45)
		)
	end
	-- torso, belt, arms, hands
	local torso = Kit.Decor(customer, "Torso", Vector3.new(2.2, 2, 1.1), at(0, 3, 0), shirt)
	Kit.Decor(customer, "Belt", Vector3.new(2.25, 0.3, 1.15), at(0, 2.2, 0), darker(pants, 0.3))
	Kit.Decor(customer, "Collar", Vector3.new(1.2, 0.2, 1.15), at(0, 3.92, 0), darker(shirt, 0.2))
	for _, side in { { Name = "L", X = -1.55 }, { Name = "R", X = 1.55 } } do
		Kit.Decor(customer, "Arm" .. side.Name, Vector3.new(0.8, 1.7, 0.8), at(side.X, 3.15, 0), shirt)
		Kit.Decor(customer, "Hand" .. side.Name, Vector3.new(0.7, 0.55, 0.7), at(side.X, 2.05, 0), skin)
	end
	if options.Vip then
		Kit.Decor(
			customer,
			"Sash",
			Vector3.new(2.7, 0.35, 0.06),
			at(0, 3, -0.58) * CFrame.Angles(0, 0, math.rad(38)),
			P.Gold,
			Enum.Material.Foil
		)
		Kit.Sparkles(torso, P.Gold, 3)
	end

	-- head: grouped so effects can scale it (pivot = bottom of the head, so it grows upward)
	local headGroup = Kit.Model(customer, "HeadGroup")
	local head = Kit.Decor(headGroup, "Head", Vector3.new(1.5, 1.5, 1.5), at(0, 4.75, 0), skin)
	buildFace(headGroup, at, skin, hair, rng)
	buildHair(headGroup, at, hair, rng)
	if options.Vip then
		buildCrown(headGroup, at)
	else
		buildHat(headGroup, at, rng)
	end
	headGroup.WorldPivot = at(0, 4, 0)

	buildBubble(head, options)

	customer.PrimaryPart = torso
	customer.WorldPivot = base -- feet on the spot, facing the same way as the body (toward the counter)
	return customer
end

return CustomerBuilder
