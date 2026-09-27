--!strict
-- Rocket (ModuleScript) — ReplicatedStorage.Effects.Rocket
-- Rocket Potion: the customer rumbles, blasts off on a jet of fire, bursts into
-- fireworks at the top, and floats back down under a little parachute.

local Debris = game:GetService("Debris")
local Effects = require(script.Parent)

local HEIGHT = 24
local CHUTE_COLORS = { Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 240, 220) }

local function part(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
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
	p.Parent = parent
	return p
end

local function fireworks(position: Vector3, scale: number)
	local holder = part(workspace, "Fireworks", Vector3.one, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)
	for _, color in { Color3.fromRGB(255, 90, 200), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 225, 80) } do
		local e = Instance.new("ParticleEmitter")
		e.Texture = Effects.Textures.Sparkles
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Lifetime = NumberRange.new(0.7, 1.1)
		e.Speed = NumberRange.new(14, 20)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 3
		e.Acceleration = Vector3.new(0, -8, 0)
		e.Rate = 0
		e.Parent = holder
		e:Emit(22)
	end
	Debris:AddItem(holder, 2)
end

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local scale = customer:GetScale()
	local torso = customer.PrimaryPart
	if not torso then
		return
	end

	-- a jet of fire and smoke out of their feet (the attachment's +Y points down)
	local nozzle = Instance.new("Attachment")
	nozzle.Name = "Nozzle"
	nozzle.CFrame = CFrame.new(0, -2.9 * scale, 0) * CFrame.Angles(math.pi, 0, 0)
	nozzle.Parent = torso
	local flame = Instance.new("ParticleEmitter")
	flame.Texture = Effects.Textures.Fire
	flame.EmissionDirection = Enum.NormalId.Top
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 90, 30))
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4 * scale),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	flame.Lifetime = NumberRange.new(0.25, 0.4)
	flame.Speed = NumberRange.new(14, 18)
	flame.SpreadAngle = Vector2.new(8, 8)
	flame.Rate = 0
	flame.Parent = nozzle
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = Effects.Textures.Smoke
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Color = ColorSequence.new(Color3.fromRGB(235, 230, 225))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 * scale),
		NumberSequenceKeypoint.new(1, 3.5 * scale),
	})
	smoke.Lifetime = NumberRange.new(0.9, 1.5)
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.Rate = 25
	smoke.Parent = nozzle

	-- rumble...
	fx.Sound("Rocket", torso)
	fx.Animate(customer, 0.45, function(alpha)
		local shake = math.sin(alpha * 90) * 0.08 * scale
		customer:PivotTo(pivot * CFrame.new(shake, 0, 0))
	end)

	-- ...blast off!
	flame.Rate = 90
	smoke.Rate = 45
	fx.Animate(customer, 0.8, function(alpha)
		customer:PivotTo(pivot * CFrame.new(0, HEIGHT * scale * alpha * alpha, 0))
	end)
	flame.Enabled = false
	smoke.Enabled = false
	Debris:AddItem(nozzle, 1.6)
	if not customer.Parent then
		return
	end
	fireworks(torso.Position + Vector3.new(0, 3 * scale, 0), scale)
	fx.Sound("Poof", torso)

	-- a parachute pops open and they drift down, swaying
	local chute = Instance.new("Model")
	chute.Name = "Parachute"
	chute.Parent = workspace -- not inside the customer: they walk away with every part they have
	-- a squashed dome: ball parts are always round, so this is a block with a sphere mesh
	local canopy = part(chute, "Canopy", Vector3.new(5, 1.6, 5) * scale, CHUTE_COLORS[1], Enum.Material.Fabric)
	local dome = Instance.new("SpecialMesh")
	dome.MeshType = Enum.MeshType.Sphere
	dome.Parent = canopy
	local band = part(chute, "Band", Vector3.new(5.1, 0.4, 5.1) * scale, CHUTE_COLORS[2], Enum.Material.Fabric)
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.4, 5.1, 5.1) * scale
	local lines: { Part } = {}
	for _ = 1, 4 do
		local line = part(
			chute,
			"Line",
			Vector3.new(0.06, 3, 0.06) * scale,
			Color3.fromRGB(80, 80, 90),
			Enum.Material.SmoothPlastic
		)
		table.insert(lines, line)
	end
	local top = HEIGHT * scale
	fx.Animate(customer, 1.7, function(alpha)
		local down = 1 - (1 - alpha) ^ 2
		local sway = math.sin(alpha * math.pi * 3) * 0.18 * (1 - alpha)
		local at = pivot * CFrame.new(0, top * (1 - down), 0) * CFrame.Angles(0, 0, sway)
		customer:PivotTo(at)
		local open = math.min(alpha / 0.15, 1)
		local chuteAt = at * CFrame.new(0, 9.2 * scale, 0)
		canopy.CFrame = chuteAt
		canopy.Size = Vector3.new(5 * open + 0.2, 1.6, 5 * open + 0.2) * scale
		band.CFrame = chuteAt * CFrame.new(0, -0.2 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2)
		band.Size = Vector3.new(0.4, 5.1 * open + 0.2, 5.1 * open + 0.2) * scale
		-- lines from the rim of the canopy down to the nearer shoulder
		for i, line in lines do
			local angle = (i - 0.5) * math.pi / 2
			local rim = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.3 * scale * open
			local shoulder = Vector3.new(if rim.X < 0 then -1.55 else 1.55, 3.9, 0) * scale
			local a = (at * CFrame.new(rim + Vector3.new(0, 8.9 * scale, 0))).Position
			local b = (at * CFrame.new(shoulder)).Position
			line.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.pi / 2, 0, 0)
			line.Size = Vector3.new(0.06 * scale, (b - a).Magnitude, 0.06 * scale)
		end
	end)
	fx.Poof(canopy.Position, CHUTE_COLORS[1], 2)
	chute:Destroy()
	if customer.Parent then
		customer:PivotTo(pivot)
	end
end
