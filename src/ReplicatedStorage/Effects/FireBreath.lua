--!strict
-- FireBreath (ModuleScript) — ReplicatedStorage.Effects.FireBreath
-- Fire Breath Potion: their face turns red, steam puffs out of their ears, then they
-- breathe a long jet of fire like a dragon and cool back down.

local Debris = game:GetService("Debris")
local Effects = require(script.Parent)

local HOT = Color3.fromRGB(255, 70, 50)

local function emitter(parent: Attachment, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Top
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

return function(customer: Model, fx: Effects.Helpers)
	local headGroup = customer:FindFirstChild("HeadGroup")
	local head = if headGroup then headGroup:FindFirstChild("Head") else nil
	if not head or not head:IsA("BasePart") then
		return
	end
	local scale = customer:GetScale()
	local pivot = customer:GetPivot()
	local skin = head.Color

	-- face goes red
	fx.Animate(customer, 0.45, function(alpha)
		head.Color = skin:Lerp(HOT, alpha)
	end)

	-- steam out of both ears
	local ears: { Attachment } = {}
	for _, side in { -1, 1 } do
		local ear = Instance.new("Attachment")
		ear.Name = "Ear"
		ear.CFrame = CFrame.new(0.78 * scale * side, 0.1 * scale, 0) * CFrame.Angles(0, 0, -side * math.rad(70))
		ear.Parent = head
		emitter(ear, {
			Texture = Effects.Textures.Smoke,
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3 * scale),
				NumberSequenceKeypoint.new(1, 1.2 * scale),
			}),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(3, 5),
			SpreadAngle = Vector2.new(15, 15),
			Rate = 35,
		})
		table.insert(ears, ear)
	end
	fx.Sound("Fire", head)

	-- the fire jet comes out of the mouth, pointing forward (the face is the head's -Z side)
	local mouth = Instance.new("Attachment")
	mouth.Name = "Mouth"
	mouth.CFrame = CFrame.new(0, -0.3 * scale, -0.8 * scale) * CFrame.Angles(-math.pi / 2, 0, 0)
	mouth.Parent = head
	local fire = emitter(mouth, {
		Texture = Effects.Textures.Fire,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 30)),
		}),
		LightEmission = 1,
		LightInfluence = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * scale),
			NumberSequenceKeypoint.new(1, 2.6 * scale),
		}),
		Lifetime = NumberRange.new(0.4, 0.65),
		Speed = NumberRange.new(16 * scale, 22 * scale),
		SpreadAngle = Vector2.new(9, 9),
		RotSpeed = NumberRange.new(-120, 120),
		Rotation = NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1.5,
		Rate = 140,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 14
	light.Brightness = 3
	light.Parent = mouth

	-- breathe, shaking with the effort
	fx.Animate(customer, 1.6, function(alpha)
		local shake = math.sin(alpha * 70) * 0.06 * scale
		customer:PivotTo(pivot * CFrame.new(shake, 0, 0))
	end)
	fire.Enabled = false
	light:Destroy()
	for _, ear in ears do
		for _, child in ear:GetChildren() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		Debris:AddItem(ear, 1.2)
	end
	Debris:AddItem(mouth, 1)
	if not customer.Parent then
		return
	end
	customer:PivotTo(pivot)

	-- cool back down
	fx.Animate(customer, 0.6, function(alpha)
		head.Color = HOT:Lerp(skin, alpha)
	end)
	head.Color = skin
end
