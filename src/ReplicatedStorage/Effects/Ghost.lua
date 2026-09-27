--!strict
-- Ghost (ModuleScript) — ReplicatedStorage.Effects.Ghost
-- Ghost Potion: the customer turns pale and see-through, floats up and drifts about
-- with wisps trailing behind, then fades back to normal.

local Debris = game:GetService("Debris")
local Effects = require(script.Parent)

local GHOST = Color3.fromRGB(225, 235, 255)

type Saved = { Color: Color3, Transparency: number }

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local scale = customer:GetScale()
	local torso = customer.PrimaryPart

	local saved: { [BasePart]: Saved } = {}
	for _, part in fx.BodyParts(customer) do
		if part.Transparency < 1 then
			saved[part] = { Color = part.Color, Transparency = part.Transparency }
		end
	end
	local function blend(amount: number)
		for part, s in saved do
			part.Color = s.Color:Lerp(GHOST, amount * 0.75)
			part.Transparency = s.Transparency + (math.max(s.Transparency, 0.55) - s.Transparency) * amount
		end
	end

	local wisps: ParticleEmitter? = nil
	if torso then
		local e = Instance.new("ParticleEmitter")
		e.Texture = Effects.Textures.Smoke
		e.Color = ColorSequence.new(GHOST)
		e.LightEmission = 0.6
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2 * scale),
			NumberSequenceKeypoint.new(1, 2.4 * scale),
		})
		e.Lifetime = NumberRange.new(0.8, 1.3)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 18
		e.Parent = torso
		wisps = e
	end
	fx.Sound("Boo", torso)

	-- fade out
	fx.Animate(customer, 0.5, blend)

	-- float and drift
	fx.Animate(customer, 1.9, function(alpha)
		local rise = math.sin(math.min(alpha / 0.3, 1) * math.pi / 2) * 1.8 * scale
		local bob = math.sin(alpha * math.pi * 4) * 0.25 * scale
		local drift = math.sin(alpha * math.pi * 2) * 0.8 * scale
		local lean = math.sin(alpha * math.pi * 2) * 0.15
		customer:PivotTo(pivot * CFrame.new(drift, rise + bob, 0) * CFrame.Angles(0, 0, -lean))
	end)

	-- back down and solid again
	local from = customer:GetPivot()
	fx.Animate(customer, 0.5, function(alpha)
		customer:PivotTo(from:Lerp(pivot, alpha))
		blend(1 - alpha)
	end)
	if wisps then
		wisps.Enabled = false
		Debris:AddItem(wisps, 1.5)
	end
	if customer.Parent then
		customer:PivotTo(pivot)
	end
	for part, s in saved do
		part.Color = s.Color
		part.Transparency = s.Transparency
	end
end
