--!strict
-- Bubble (ModuleScript) — ReplicatedStorage.Effects.Bubble
-- Bubble Potion: a giant soap bubble grows around the customer and floats them up,
-- bobbing gently... until it pops and they drop back down.

local Effects = require(script.Parent)

local BUBBLE = Color3.fromRGB(190, 230, 255)

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local scale = customer:GetScale()
	local center = CFrame.new(0, 3.1 * scale, 0)
	local size = 7.2 * scale

	local bubble = Instance.new("Part")
	bubble.Name = "SoapBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Material = Enum.Material.Glass
	bubble.Color = BUBBLE
	bubble.Transparency = 0.6
	bubble.Reflectance = 0.25
	bubble.Size = Vector3.one * 0.1
	bubble.CFrame = pivot * center
	bubble.Parent = workspace -- not inside the customer: they walk away with every part they have
	local shine = Instance.new("ParticleEmitter")
	shine.Texture = Effects.Textures.Sparkles
	shine.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 190, 240))
	shine.LightEmission = 1
	shine.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	shine.Lifetime = NumberRange.new(0.6, 1)
	shine.Speed = NumberRange.new(0.2, 0.6)
	shine.SpreadAngle = Vector2.new(180, 180)
	shine.Rate = 10
	shine.Parent = bubble
	fx.Sound("Whoosh", customer.PrimaryPart)

	-- the bubble grows around them
	fx.Animate(customer, 0.4, function(alpha)
		local grow = 1 - (1 - alpha) ^ 3
		bubble.Size = Vector3.one * math.max(size * grow, 0.1)
	end)

	-- up they go, bobbing and swaying
	local height = 0
	fx.Animate(customer, 2, function(alpha)
		height = math.min(alpha / 0.55, 1)
		height = (1 - (1 - height) ^ 2) * 5 * scale + math.sin(alpha * math.pi * 3) * 0.3 * scale
		local sway = math.sin(alpha * math.pi * 2.5) * 0.12
		local at = pivot * CFrame.new(0, height, 0) * CFrame.Angles(0, 0, sway)
		customer:PivotTo(at)
		bubble.CFrame = at * center
	end)

	-- pop!
	local popAt = bubble.Position
	bubble:Destroy()
	if not customer.Parent then
		return
	end
	fx.Sound("Pop", customer.PrimaryPart)
	fx.Poof(popAt, BUBBLE, 2.5 * scale)

	-- and they drop back down
	local from = height
	fx.Animate(customer, 0.35, function(alpha)
		customer:PivotTo(pivot * CFrame.new(0, from * (1 - alpha * alpha), 0))
	end)
	if customer.Parent then
		customer:PivotTo(pivot)
	end
end
