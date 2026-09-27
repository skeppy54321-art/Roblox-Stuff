--!strict
-- Rainbow (ModuleScript) — ReplicatedStorage.Effects.Rainbow
-- Rainbow Potion: waves of color run up the customer while they glow, then they
-- keep their rainbow stripes as they walk away.

local Debris = game:GetService("Debris")
local Effects = require(script.Parent)

-- Face parts keep their colors so the customer still has a face.
local KEEP = { Eye = true, EyeShine = true, Mouth = true, Lens = true, GlassesBridge = true }

return function(customer: Model, fx: Effects.Helpers)
	local torso = customer.PrimaryPart
	local glowing: { [BasePart]: Enum.Material } = {}
	for _, part in fx.BodyParts(customer) do
		if part.Transparency < 1 and not KEEP[part.Name] then
			glowing[part] = part.Material
			part.Material = Enum.Material.Neon
		end
	end

	if torso then
		fx.Sound("Whoosh", torso)
		fx.Burst(torso, Color3.fromRGB(255, 255, 255), 30)
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
		})
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Lifetime = NumberRange.new(0.8, 1.2)
		sparkles.Speed = NumberRange.new(2, 5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rate = 30
		sparkles.Parent = torso
		Debris:AddItem(sparkles, 3.2)
	end

	fx.Animate(customer, 3, function()
		local t = os.clock()
		for part in glowing do
			part.Color = Color3.fromHSV((t * 0.8 + part.Position.Y * 0.12) % 1, 0.75, 1)
		end
	end)

	for part, material in glowing do
		part.Material = material -- keep the stripes, lose the glow
	end
end
