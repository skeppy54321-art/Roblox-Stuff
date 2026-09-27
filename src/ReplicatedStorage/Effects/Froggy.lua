--!strict
-- Froggy (ModuleScript) — ReplicatedStorage.Effects.Froggy
-- Froggy Potion: poof! The customer turns into a frog, hops around ribbiting,
-- and stays a frog as they leave. The frog only exists on this client.

local Effects = require(script.Parent)

local GREEN = Color3.fromRGB(90, 190, 80)
local LIGHT = Color3.fromRGB(175, 232, 125)
local DARK = Color3.fromRGB(40, 60, 40)

-- Builds the frog standing at `base` (feet), facing the same way as the customer.
local function buildFrog(parent: Instance, base: CFrame, scale: number): Model
	local frog = Instance.new("Model")
	frog.Name = "Frog"
	local function part(name: string, shape: Enum.PartType, size: Vector3, offset: Vector3, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size * scale
		p.CFrame = base * CFrame.new(offset * scale)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = frog
	end
	local ball, block = Enum.PartType.Ball, Enum.PartType.Block
	part("Body", ball, Vector3.one * 2.6, Vector3.new(0, 1.3, 0.2), GREEN)
	part("Belly", ball, Vector3.one * 2, Vector3.new(0, 1.1, -0.45), LIGHT)
	part("Head", ball, Vector3.one * 2.1, Vector3.new(0, 2.5, -0.3), GREEN)
	for _, x in { -0.55, 0.55 } do
		part("Eye", ball, Vector3.one * 0.8, Vector3.new(x, 3.35, -0.55), Color3.new(1, 1, 1))
		part("Pupil", ball, Vector3.one * 0.38, Vector3.new(x, 3.4, -0.9), DARK)
		part("Cheek", ball, Vector3.one * 0.4, Vector3.new(x * 1.45, 2.3, -1.05), Color3.fromRGB(255, 150, 160))
	end
	part("Mouth", block, Vector3.new(1.1, 0.1, 0.1), Vector3.new(0, 2.25, -1.33), DARK)
	for _, x in { -1.2, 1.2 } do
		part("BackLeg", block, Vector3.new(0.8, 0.5, 1.6), Vector3.new(x, 0.25, 0.3), GREEN)
	end
	for _, x in { -0.8, 0.8 } do
		part("FrontLeg", block, Vector3.new(0.4, 0.9, 0.4), Vector3.new(x, 0.45, -0.9), GREEN)
	end
	frog.WorldPivot = base
	frog.Parent = parent
	return frog
end

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local torso = customer.PrimaryPart
	fx.Poof(pivot.Position + Vector3.new(0, 2.5, 0), Color3.fromRGB(120, 220, 100), 4.5)
	fx.Sound("Poof", torso)

	for _, part in fx.BodyParts(customer) do
		part.Transparency = 1
	end
	local frog = buildFrog(customer, pivot, customer:GetScale())
	local body = frog:FindFirstChild("Body")
	local bodyPart = if body and body:IsA("BasePart") then body else nil

	for i = 1, 3 do
		fx.Sound(if i == 2 then "Ribbit" else "Hop", bodyPart)
		fx.Animate(customer, 0.4, function(alpha)
			local lift = math.sin(alpha * math.pi)
			frog:PivotTo(pivot * CFrame.new(0, lift * 1.4, 0) * CFrame.Angles(-lift * 0.25, 0, 0))
		end)
		task.wait(0.25)
	end
	if frog.Parent then
		frog:PivotTo(pivot)
	end
end
