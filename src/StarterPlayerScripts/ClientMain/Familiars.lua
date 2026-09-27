--!strict
-- Familiars (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Familiars
-- Magic pets that float along behind their owner: 1 = Shop Cat, 2 = Wise Owl,
-- 3 = Baby Dragon (the Magic Familiar upgrade). The server only sets each player's
-- "Familiar" attribute; every client builds and moves everyone's pet itself, so they
-- follow smoothly and cost no network traffic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effects = require(ReplicatedStorage:WaitForChild("Effects"))

local FOLLOW = CFrame.new(2.6, 1.6, 2.4) -- behind the owner's right shoulder
local NEON = Enum.Material.Neon

type Pet = {
	Owner: Player,
	Level: number,
	Model: Model,
	Body: BasePart,
	Parts: { BasePart },
	Offsets: { CFrame }, -- each part relative to the body's CFrame
	Wings: { { Part: BasePart, Side: number, Offset: CFrame } },
	Mouth: Attachment?,
	At: CFrame,
	NextPuff: number,
}

local Familiars = {}

local pets: { [Player]: Pet } = {}
local folder: Folder

local function part(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	ball: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- Builds a pet at the origin, facing -Z. Returns the model, its body and any wings.
local function build(level: number): (Model, Part, { { Part: Part, Side: number } }, CFrame?)
	local model = Instance.new("Model")
	local wings: { { Part: Part, Side: number } } = {}
	local mouth: CFrame? = nil
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end
	local body: Part
	if level == 1 then -- Shop Cat: black, green eyes, a gold bell
		model.Name = "ShopCat"
		local fur = Color3.fromRGB(45, 40, 52)
		body = part(model, "Body", Vector3.new(1.1, 0.8, 1.4), fur)
		part(model, "Head", Vector3.one * 0.95, fur, nil, true).CFrame = at(0, 0.45, -0.75)
		for _, side in { -1, 1 } do
			local ear = Instance.new("WedgePart")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.12, 0.35, 0.3)
			ear.Color = fur
			ear.Anchored, ear.CanCollide, ear.CanQuery, ear.CanTouch, ear.CastShadow = true, false, false, false, false
			ear.CFrame = at(side * 0.25, 0.95, -0.75) * CFrame.Angles(0, math.rad(90), 0)
			ear.Parent = model
			part(model, "Eye", Vector3.one * 0.2, Color3.fromRGB(120, 255, 120), NEON, true).CFrame =
				at(side * 0.2, 0.52, -1.15)
		end
		for i = 1, 3 do -- a curly tail
			part(model, "Tail", Vector3.one * (0.3 - i * 0.04), fur, nil, true).CFrame =
				at(0, 0.15 + i * 0.28, 0.7 + i * 0.12)
		end
		part(model, "Bell", Vector3.one * 0.22, Color3.fromRGB(255, 205, 70), Enum.Material.Foil, true).CFrame =
			at(0, 0.08, -1.05)
	elseif level == 2 then -- Wise Owl: round and brown, big eyes, flapping wings
		model.Name = "WiseOwl"
		local feathers = Color3.fromRGB(135, 95, 60)
		body = part(model, "Body", Vector3.one * 1.3, feathers, nil, true)
		part(model, "Belly", Vector3.one * 0.95, Color3.fromRGB(235, 215, 180), nil, true).CFrame = at(0, -0.1, -0.3)
		for _, side in { -1, 1 } do
			part(model, "Eye", Vector3.one * 0.42, Color3.fromRGB(255, 255, 255), nil, true).CFrame =
				at(side * 0.27, 0.3, -0.52)
			part(model, "Pupil", Vector3.one * 0.2, Color3.fromRGB(255, 200, 40), NEON, true).CFrame =
				at(side * 0.27, 0.3, -0.72)
			-- flat wings sticking out sideways; they flap around their inner edge
			local wing = part(model, "Wing", Vector3.new(0.8, 0.12, 0.7), Color3.fromRGB(110, 75, 45))
			wing.CFrame = at(side * 1, 0.05, 0.05)
			table.insert(wings, { Part = wing, Side = side })
		end
		local beak = Instance.new("WedgePart")
		beak.Name = "Beak"
		beak.Size = Vector3.new(0.18, 0.2, 0.22)
		beak.Color = Color3.fromRGB(245, 160, 40)
		beak.Anchored, beak.CanCollide, beak.CanQuery, beak.CanTouch, beak.CastShadow = true, false, false, false, false
		beak.CFrame = at(0, 0.12, -0.72) * CFrame.Angles(math.rad(180), 0, 0)
		beak.Parent = model
	else -- Baby Dragon: purple scales, gold horns, bat wings, puffs of fire
		model.Name = "BabyDragon"
		local scales = Color3.fromRGB(140, 80, 210)
		body = part(model, "Body", Vector3.one * 1.3, scales, nil, true)
		part(model, "Belly", Vector3.one * 0.9, Color3.fromRGB(250, 210, 120), nil, true).CFrame = at(0, -0.2, -0.35)
		part(model, "Head", Vector3.one * 0.95, scales, nil, true).CFrame = at(0, 0.6, -0.75)
		part(model, "Snout", Vector3.new(0.6, 0.4, 0.5), scales).CFrame = at(0, 0.5, -1.25)
		for _, side in { -1, 1 } do
			local horn = Instance.new("WedgePart")
			horn.Name = "Horn"
			horn.Size = Vector3.new(0.14, 0.4, 0.3)
			horn.Color = Color3.fromRGB(255, 205, 70)
			horn.Anchored, horn.CanCollide, horn.CanQuery, horn.CanTouch, horn.CastShadow =
				true, false, false, false, false
			horn.CFrame = at(side * 0.28, 1.05, -0.6) * CFrame.Angles(0, math.rad(180), 0)
			horn.Parent = model
			part(model, "Eye", Vector3.one * 0.2, Color3.fromRGB(255, 230, 60), NEON, true).CFrame =
				at(side * 0.22, 0.72, -1.15)
			local wing = part(model, "Wing", Vector3.new(1.2, 0.1, 0.9), Color3.fromRGB(90, 200, 150))
			wing.CFrame = at(side * 1.2, 0.3, 0.15)
			table.insert(wings, { Part = wing, Side = side })
		end
		for i = 1, 3 do
			part(model, "Tail", Vector3.one * (0.55 - i * 0.12), scales, nil, true).CFrame =
				at(0, -0.1 - i * 0.12, 0.6 + i * 0.35)
		end
		mouth = at(0, 0.45, -1.5)
	end
	model.PrimaryPart = body
	return model, body, wings, mouth
end

local function remove(player: Player)
	local pet = pets[player]
	if pet then
		pets[player] = nil
		pet.Model:Destroy()
	end
end

local function refresh(player: Player)
	local value = player:GetAttribute("Familiar")
	local level = if typeof(value) == "number" then math.clamp(math.floor(value), 0, 3) else 0
	local current = pets[player]
	if current and current.Level == level then
		return
	end
	remove(player)
	if level == 0 then
		return
	end
	local model, body, wings, mouthAt = build(level)
	model.Name = `{model.Name}_{player.UserId}`
	local parts, offsets = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, body.CFrame:ToObjectSpace(d.CFrame))
		end
	end
	local wingList: { { Part: BasePart, Side: number, Offset: CFrame } } = {}
	for _, w in wings do
		local wingPart: BasePart = w.Part
		table.insert(wingList, { Part = wingPart, Side = w.Side, Offset = body.CFrame:ToObjectSpace(wingPart.CFrame) })
	end
	local mouth: Attachment? = nil
	if mouthAt then
		local a = Instance.new("Attachment")
		a.Name = "Mouth"
		a.CFrame = body.CFrame:ToObjectSpace(mouthAt) * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y points forward
		a.Parent = body
		mouth = a
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local start = if root and root:IsA("BasePart") then root.CFrame * FOLLOW else CFrame.new(0, -500, 0)
	model.Parent = folder
	pets[player] = {
		Owner = player,
		Level = level,
		Model = model,
		Body = body,
		Parts = parts,
		Offsets = offsets,
		Wings = wingList,
		Mouth = mouth,
		At = start,
		NextPuff = os.clock() + 4,
	}
end

-- A little puff of fire from the dragon's mouth.
local function puff(mouth: Attachment)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Effects.Textures.Fire
	e.EmissionDirection = Enum.NormalId.Top
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 80, 30))
	e.LightEmission = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(5, 8)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Rate = 0
	e.Parent = mouth
	e:Emit(14)
	Debris:AddItem(e, 1)
end

local function update(pet: Pet, dt: number, t: number)
	local character = pet.Owner.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	-- glide toward the spot behind the owner's shoulder, facing where they face
	local goal = root.CFrame * FOLLOW
	local distance = (goal.Position - pet.At.Position).Magnitude
	if distance > 60 then
		pet.At = goal -- teleported: catch up at once
	else
		pet.At = pet.At:Lerp(goal, 1 - math.exp(-dt * 5))
	end
	local bob = math.sin(t * 2.4 + pet.Owner.UserId % 7) * 0.22
	local tilt = math.sin(t * 1.3) * 0.08
	local bodyAt = pet.At * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, tilt)
	local cframes = table.create(#pet.Parts)
	for i, offset in pet.Offsets do
		cframes[i] = bodyAt * offset
	end
	-- wings flap around their inner edge
	local flap = math.sin(t * (if pet.Level == 3 then 9 else 12)) * math.rad(35)
	for _, wing in pet.Wings do
		local hinge = wing.Offset * CFrame.new(-wing.Side * wing.Part.Size.X * 0.5, 0, 0)
		local turned = hinge * CFrame.Angles(0, 0, wing.Side * flap) * hinge:Inverse() * wing.Offset
		local index = table.find(pet.Parts, wing.Part)
		if index then
			cframes[index] = bodyAt * turned
		end
	end
	workspace:BulkMoveTo(pet.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	-- the dragon puffs a little fire now and then
	local mouth = pet.Mouth
	if mouth and os.clock() >= pet.NextPuff then
		pet.NextPuff = os.clock() + 5 + math.random() * 4
		puff(mouth)
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Familiar"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function()
		local pet = pets[player]
		if pet then
			pet.At = CFrame.new(0, -500, 0) -- far away: snaps to the new character next frame
		end
	end)
	refresh(player)
end

function Familiars.Init()
	folder = Instance.new("Folder")
	folder.Name = "Familiars"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(remove)
	local start = os.clock()
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - start
		for _, pet in pets do
			update(pet, math.min(dt, 0.1), t)
		end
	end)
end

-- For tests: the pet model following `player`, if any.
function Familiars.Get(player: Player): Model?
	local pet = pets[player]
	return if pet then pet.Model else nil
end

return Familiars
