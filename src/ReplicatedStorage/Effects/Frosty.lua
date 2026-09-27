--!strict
-- Frosty (ModuleScript) — ReplicatedStorage.Effects.Frosty
-- Frosty Potion: the customer freezes solid inside a block of ice, the ice cracks,
-- and they shiver back to normal.

local Effects = require(script.Parent)

local ICE = Color3.fromRGB(175, 225, 255)

type Saved = { Color: Color3, Material: Enum.Material }

return function(customer: Model, fx: Effects.Helpers)
	local torso = customer.PrimaryPart
	local pivot = customer:GetPivot()
	fx.Sound("Freeze", torso)

	local saved: { [BasePart]: Saved } = {}
	for _, part in fx.BodyParts(customer) do
		if part.Transparency < 1 then
			saved[part] = { Color = part.Color, Material = part.Material }
		end
	end

	-- frost creeps over them
	fx.Animate(customer, 0.4, function(alpha)
		for part, s in saved do
			part.Color = s.Color:Lerp(ICE, alpha)
		end
	end)
	for part in saved do
		part.Material = Enum.Material.Ice
	end

	-- a block of ice around them
	local scale = customer:GetScale()
	local block = Instance.new("Part")
	block.Name = "IceBlock"
	block.Anchored = true
	block.CanCollide = false
	block.CanQuery = false
	block.CanTouch = false
	block.Material = Enum.Material.Glass
	block.Color = ICE
	block.Transparency = 0.5
	block.Size = Vector3.new(3.6, 6.4, 2.6) * scale
	block.CFrame = pivot * CFrame.new(0, 3.1 * scale, 0)
	block.Parent = customer
	local frost = Instance.new("ParticleEmitter")
	frost.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	frost.LightEmission = 0.5
	frost.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	frost.Lifetime = NumberRange.new(0.8, 1.4)
	frost.Speed = NumberRange.new(0.3, 1)
	frost.SpreadAngle = Vector2.new(180, 180)
	frost.Rate = 12
	frost.Parent = block
	fx.Burst(block, Color3.fromRGB(255, 255, 255), 25, 6)

	task.wait(1.8)
	if not customer.Parent then
		return
	end

	-- crack!
	fx.Burst(block, ICE, 40, 12)
	fx.Sound("Poof", block)
	block:Destroy()

	-- shiver and thaw
	fx.Animate(customer, 0.8, function(alpha)
		local shake = math.sin(alpha * 60) * 0.12 * (1 - alpha)
		customer:PivotTo(pivot * CFrame.new(shake, 0, 0))
		for part, s in saved do
			part.Color = ICE:Lerp(s.Color, alpha)
		end
	end)
	if customer.Parent then
		customer:PivotTo(pivot)
	end
	for part, s in saved do
		part.Color = s.Color
		part.Material = s.Material
	end
end
