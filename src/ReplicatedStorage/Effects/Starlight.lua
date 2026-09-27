--!strict
-- Starlight (ModuleScript) — ReplicatedStorage.Effects.Starlight
-- Starlight Potion (after a rebirth): the customer turns into a glowing night sky full of
-- twinkles, floats up and turns slowly inside a ring of circling stars, then comes back
-- down in a shower of stardust.

local Debris = game:GetService("Debris")
local Effects = require(script.Parent)

local NIGHT = Color3.fromRGB(45, 45, 130)
local STAR = Color3.fromRGB(240, 244, 255)
local DUST = Color3.fromRGB(150, 165, 255)
local STARS = 6

type Saved = { Color: Color3, Material: Enum.Material }

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local scale = customer:GetScale()
	local torso = customer.PrimaryPart

	local saved: { [BasePart]: Saved } = {}
	for _, part in fx.BodyParts(customer) do
		if part.Transparency < 1 then
			saved[part] = { Color = part.Color, Material = part.Material }
		end
	end
	local function paint(amount: number)
		for part, s in saved do
			part.Color = s.Color:Lerp(NIGHT, amount)
			part.Material = if amount > 0.5 then Enum.Material.Neon else s.Material
		end
	end

	-- twinkles all over them
	local twinkles: ParticleEmitter? = nil
	if torso then
		local e = Instance.new("ParticleEmitter")
		e.Texture = Effects.Textures.Sparkles
		e.Color = ColorSequence.new(STAR, DUST)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.4 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 30
		e.Parent = torso
		twinkles = e
	end

	-- a ring of stars (parented to the customer, so they go away with them)
	local ring: { Part } = {}
	for i = 1, STARS do
		local star = Instance.new("Part")
		star.Name = "OrbitStar"
		star.Anchored = true
		star.CanCollide = false
		star.CanQuery = false
		star.CanTouch = false
		star.CastShadow = false
		star.Material = Enum.Material.Neon
		star.Color = if i % 2 == 0 then STAR else DUST
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.one * 0.05
		star.CFrame = pivot
		star.Parent = customer
		table.insert(ring, star)
	end
	local turn = 0
	local function orbit(center: CFrame, size: number, radius: number, dt: number)
		turn += dt * 2.6
		for i, star in ring do
			local angle = turn + i * (math.pi * 2 / STARS)
			local height = math.sin(angle * 2 + i) * 0.9 * scale
			star.Size = Vector3.one * math.max(size, 0.05)
			star.CFrame = CFrame.new(
				center.Position + Vector3.new(math.cos(angle) * radius, 3 * scale + height, math.sin(angle) * radius)
			)
		end
	end

	fx.Sound("Twinkle", torso)

	-- turn into the night sky while the stars appear
	fx.Animate(customer, 0.5, function(alpha, dt)
		paint(alpha)
		orbit(customer:GetPivot(), 0.5 * scale * alpha, 2.3 * scale, dt)
	end)

	-- float and turn inside the ring
	fx.Animate(customer, 2.2, function(alpha, dt)
		local rise = math.sin(math.min(alpha / 0.35, 1) * math.pi / 2) * 1.6 * scale
		local bob = math.sin(alpha * math.pi * 4) * 0.2 * scale
		local here = pivot * CFrame.new(0, rise + bob, 0) * CFrame.Angles(0, alpha * math.pi, 0)
		customer:PivotTo(here)
		orbit(here, 0.5 * scale, 2.3 * scale, dt)
	end)

	-- back down; the stars fly out and fade, stardust everywhere
	local from = customer:GetPivot()
	if torso then
		fx.Burst(torso, DUST, 40, 9)
	end
	fx.Animate(customer, 0.6, function(alpha, dt)
		customer:PivotTo(from:Lerp(pivot, alpha))
		paint(1 - alpha)
		orbit(customer:GetPivot(), 0.5 * scale * (1 - alpha), (2.3 + alpha * 3) * scale, dt)
	end)

	for _, star in ring do
		star:Destroy()
	end
	if twinkles then
		twinkles.Enabled = false
		Debris:AddItem(twinkles, 1.2)
	end
	if customer.Parent then
		customer:PivotTo(pivot)
	end
	for part, s in saved do
		part.Color = s.Color
		part.Material = s.Material
	end
end
