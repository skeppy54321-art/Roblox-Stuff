--!strict
-- Juice (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Juice
-- Small one-off world effects on this client only: sparkle bursts, and new things
-- growing in from the ground (a freshly planted garden).

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effects = require(ReplicatedStorage:WaitForChild("Effects"))

local Juice = {}

-- A burst of sparkles at `position`.
function Juice.Sparkle(position: Vector3, color: Color3, count: number?)
	local holder = Instance.new("Part")
	holder.Name = "SparkleBurst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Effects.Textures.Sparkles
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 240, 170))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count or 30)
	Debris:AddItem(holder, 2)
end

local function easeOutBack(t: number): number
	local c = 1.6
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

-- Grows `model` up out of the ground at `base` (a point under it), with a little
-- overshoot, then puts every part back exactly as it was.
function Juice.GrowIn(model: Model, base: Vector3, seconds: number?)
	local duration = seconds or 0.6
	local origin = CFrame.new(base)
	local parts: { BasePart } = {}
	local sizes: { Vector3 } = {}
	local offsets: { CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(sizes, d.Size)
			table.insert(offsets, origin:ToObjectSpace(d.CFrame))
		end
	end
	local function pose(scale: number)
		for i, p in parts do
			local rel = offsets[i]
			p.Size = sizes[i] * scale
			p.CFrame = origin * CFrame.new(rel.Position * scale) * rel.Rotation
		end
	end
	pose(0.05)
	task.spawn(function()
		local start = os.clock()
		while model.Parent do
			local t = math.min((os.clock() - start) / duration, 1)
			pose(math.max(0.05, easeOutBack(t)))
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		pose(1)
	end)
end

return Juice
