--!strict
-- Dance (ModuleScript) — ReplicatedStorage.Effects.Dance
-- Dance Potion: a disco ball drops in above the customer, colored lights swirl, and
-- they bounce, twist and point at the sky, one arm then the other.

local Effects = require(script.Parent)

local SECONDS = 3
local SHOULDERS: { [string]: Vector3 } = { L = Vector3.new(-1.55, 3.9, 0), R = Vector3.new(1.55, 3.9, 0) } -- see CustomerBuilder

type Arm = { Parts: { BasePart }, Rest: { CFrame }, Shoulder: Vector3, Side: number }

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local scale = customer:GetScale()

	-- arms, relative to the customer's pivot, so they can be posed every frame
	local arms: { Arm } = {}
	for side, shoulder in SHOULDERS do
		local list, rest = {}, {}
		for _, name in { "Arm" .. side, "Hand" .. side } do
			local p = customer:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				table.insert(list, p)
				table.insert(rest, pivot:ToObjectSpace(p.CFrame))
			end
		end
		table.insert(
			arms,
			{ Parts = list, Rest = rest, Shoulder = shoulder * scale, Side = if side == "L" then -1 else 1 }
		)
	end

	-- the disco ball on a string
	local top = pivot * CFrame.new(0, 7.8 * scale, 0)
	local ball = part("DiscoBall", Vector3.one * 1.5 * scale, Color3.fromRGB(215, 220, 235), Enum.Material.Foil)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.5 * scale
	ball.Reflectance = 0.4
	ball.CFrame = top * CFrame.new(0, 4 * scale, 0)
	ball.Parent = customer
	local cord =
		part("Cord", Vector3.new(0.08, 3, 0.08) * scale, Color3.fromRGB(60, 60, 70), Enum.Material.SmoothPlastic)
	cord.Parent = customer
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 3
	light.Parent = ball
	local glitter = Instance.new("ParticleEmitter")
	glitter.Texture = Effects.Textures.Sparkles
	glitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 90)),
	})
	glitter.LightEmission = 1
	glitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	glitter.Lifetime = NumberRange.new(0.8, 1.3)
	glitter.Speed = NumberRange.new(4, 7)
	glitter.SpreadAngle = Vector2.new(180, 180)
	glitter.Acceleration = Vector3.new(0, -6, 0)
	glitter.Rate = 40
	glitter.Parent = ball
	fx.Sound("Disco", customer.PrimaryPart)

	fx.Animate(customer, SECONDS, function(alpha)
		local t = alpha * SECONDS
		-- the ball drops in, spins, and the light cycles through the rainbow
		local drop = math.min(t / 0.35, 1)
		local ballAt = top * CFrame.new(0, 4 * scale * (1 - drop) ^ 2, 0)
		ball.CFrame = ballAt * CFrame.Angles(0, t * 4, 0)
		cord.CFrame = ballAt * CFrame.new(0, 2.2 * scale, 0)
		light.Color = Color3.fromHSV((t * 0.9) % 1, 0.7, 1)

		-- bounce to the beat and twist side to side
		local beat = t * math.pi * 2 * 2.2
		local bounce = math.abs(math.sin(beat)) * 0.45 * scale
		local twist = math.sin(beat / 2) * math.rad(28)
		local now = pivot * CFrame.new(0, bounce, 0) * CFrame.Angles(0, twist, 0)
		customer:PivotTo(now)

		-- point at the sky: the arms take turns
		local turn = math.floor(t / 0.55) % 2
		local ease = math.min(alpha / 0.1, 1) * math.min((1 - alpha) / 0.1, 1) -- start and end at rest
		for _, arm in arms do
			local up = if (arm.Side == 1) == (turn == 0) then 1 else 0.25
			local shoulder = now * CFrame.new(arm.Shoulder)
			local swing = shoulder * CFrame.Angles(0, 0, arm.Side * math.rad(160) * up * ease) * shoulder:Inverse()
			for i, p in arm.Parts do
				p.CFrame = swing * now * arm.Rest[i]
			end
		end
	end)

	-- tidy up: back to the spot, arms down, the ball pops away
	if customer.Parent then
		customer:PivotTo(pivot)
		for _, arm in arms do
			for i, p in arm.Parts do
				p.CFrame = pivot * arm.Rest[i]
			end
		end
	end
	-- (nothing extra may stay inside the customer: they walk away with every part they have)
	fx.Poof(ball.Position, Color3.fromRGB(255, 200, 255), 2)
	ball:Destroy()
	cord:Destroy()
end
