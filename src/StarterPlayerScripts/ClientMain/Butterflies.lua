--!strict
-- Butterflies (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Butterflies
-- A few butterflies flutter around the plaza in golden hour and fly off as dusk falls
-- (the fireflies take over; DayCycle sets Butterflies.Amount). Client only and cheap:
-- three parts each, all moved with one BulkMoveTo 30 times a second.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local W = Config.World
local COUNT = 8
local UPDATE_EVERY = 1 / 30
local WANDER = 9 -- how far they drift from home (studs)
local FLY_OFF = 3 -- seconds to fly away at dusk (or come back)

local COLORS = {
	Color3.fromRGB(255, 165, 60), -- orange
	Color3.fromRGB(255, 232, 110), -- lemon
	Color3.fromRGB(150, 200, 255), -- sky blue
	Color3.fromRGB(255, 160, 210), -- pink
	Color3.fromRGB(245, 245, 255), -- white
	Color3.fromRGB(190, 150, 255), -- lilac
}

type Butterfly = {
	Body: Part,
	Left: Part,
	Right: Part,
	Home: Vector3,
	Seed: number,
	Facing: Vector3,
	Away: number, -- 0 = here, 1 = flown off
}

local Butterflies = {}

-- How many are out, 0 to 1 (DayCycle turns it down at dusk).
Butterflies.Amount = 1

local list: { Butterfly } = {}

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Where butterfly `b` is at time `t` (seconds).
function Butterflies.PositionAt(b: Butterfly, t: number): Vector3
	local s = b.Seed
	return b.Home
		+ Vector3.new(
			math.noise(t * 0.22, s, 0.5) * WANDER,
			math.noise(s, t * 0.35, 0.5) * 1.6 + math.sin(t * 5 + s) * 0.12 + b.Away * 30,
			math.noise(0.5, s, t * 0.22) * WANDER
		)
end

function Butterflies.Get(): { Butterfly }
	return list
end

local function update(t: number, dt: number)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for i, b in list do
		local out = i <= math.floor(Butterflies.Amount * COUNT + 0.5)
		b.Away = math.clamp(b.Away + (if out then -dt else dt) / FLY_OFF, 0, 1)
		local hidden = b.Away >= 1
		local transparency = if hidden then 1 else 0
		if b.Body.Transparency ~= transparency then
			for _, p in { b.Body, b.Left, b.Right } do
				p.Transparency = transparency
			end
		end
		if not hidden then
			local position = Butterflies.PositionAt(b, t)
			local ahead = Butterflies.PositionAt(b, t + 0.1) - position
			local flat = Vector3.new(ahead.X, 0, ahead.Z)
			if flat.Magnitude > 0.01 then
				b.Facing = flat.Unit
			end
			local body = CFrame.lookAt(position, position + b.Facing)
			local flap = math.sin(t * 17 + b.Seed) * 1.05
			table.insert(parts, b.Body)
			table.insert(cframes, body)
			table.insert(parts, b.Left)
			table.insert(cframes, body * CFrame.Angles(0, 0, flap) * CFrame.new(-0.27, 0, 0))
			table.insert(parts, b.Right)
			table.insert(cframes, body * CFrame.Angles(0, 0, -flap) * CFrame.new(0.27, 0, 0))
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Butterflies.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Butterflies"
	folder.Parent = workspace
	local rng = Random.new(7)
	for i = 1, COUNT do
		-- homes spread around the plaza, over the planters and benches
		local angle = (i / COUNT) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local radius = rng:NextNumber(W.PlazaRadius * 0.5, W.PlazaRadius * 1.1)
		local color = COLORS[(i - 1) % #COLORS + 1]
		local wing = Vector3.new(0.5, 0.04, 0.42)
		local b: Butterfly = {
			Body = newPart(folder, "Body", Vector3.new(0.1, 0.1, 0.42), Color3.fromRGB(60, 45, 40)),
			Left = newPart(folder, "Wing", wing, color),
			Right = newPart(folder, "Wing", wing, color),
			Home = Vector3.new(
				math.sin(angle) * radius,
				W.GroundHeight + rng:NextNumber(1.8, 3.2),
				math.cos(angle) * radius
			),
			Seed = rng:NextNumber(0, 100),
			Facing = Vector3.new(0, 0, 1),
			Away = 0,
		}
		table.insert(list, b)
	end
	update(os.clock(), 0)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < UPDATE_EVERY then
			return
		end
		update(os.clock(), elapsed)
		elapsed = 0
	end)
end

return Butterflies
