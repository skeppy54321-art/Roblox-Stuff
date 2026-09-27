--!strict
-- Floaty (ModuleScript) — ReplicatedStorage.Effects.Floaty
-- Floaty Potion: the customer floats up like a balloon, sways, and drifts back down.

local Debris = game:GetService("Debris")
local Effects = require(script.Parent)

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local torso = customer.PrimaryPart
	fx.Sound("Whoosh", torso)

	local trail: ParticleEmitter? = nil
	if torso then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 236, 130))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 25
		emitter.Parent = torso
		trail = emitter
	end

	fx.Animate(customer, 3.1, function(alpha)
		local up = math.sin(alpha * math.pi) * 7
		local sway = math.sin(alpha * math.pi * 4) * 0.25
		customer:PivotTo(pivot * CFrame.new(0, up, 0) * CFrame.Angles(0, 0, sway))
	end)
	if customer.Parent then
		customer:PivotTo(pivot)
	end
	if trail then
		trail.Enabled = false
		Debris:AddItem(trail, 1.5)
	end
end
