--!strict
-- Townsfolk (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Townsfolk
-- Villagers who stroll around the fountain, stop to admire it, and window-shop at the
-- stalls (players' shops first), now and then saying something nice. Visual only: the
-- server builds them once (MarketBuilder) and each client walks its own copy, so they
-- cost no network traffic and never touch the game.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local CustomerAnimator = require(script.Parent:WaitForChild("CustomerAnimator"))

local W = Config.World
local P = Config.Palette

local WALK_SPEED = 4.5 -- studs per second (customers walk at 8; townsfolk are in no hurry)
local RING = 20 -- they stroll around the fountain at this distance from the center
local FOUNTAIN_STOP = 10.8 -- just outside the fountain's lip
local SHOP_STOP = 40 -- how far out along a shop's path they stop to look (customers stand at 48.5)
local GROUND = 0.3
local STEP = math.rad(30) -- walk around the ring in steps this big, so they never cut across

local LINES = {
	"Ooh, potions!",
	"What a cozy shop!",
	"So many colors!",
	"I want a Froggy one!",
	"Smells like magic!",
	"What a pretty fountain!",
	"Are those ember peppers?",
	"Best market in town!",
	"I heard about the Rocket Potion...",
	"Look at those bottles!",
}

type Stop = { At: Vector3, Look: Vector3?, Wait: number, Say: boolean }

type Walker = {
	Rig: CustomerAnimator.Rig,
	Position: Vector3,
	Facing: Vector3,
	Route: { Stop },
	Index: number,
	Waiting: number,
	Travelled: number,
	Angle: number, -- where on the ring they are (radians)
	Rng: Random,
	Bubble: BillboardGui?,
}

local Townsfolk = {}

local walkers: { Walker } = {}
local market: Instance? = nil

local function onRing(angle: number, radius: number): Vector3
	return Vector3.new(math.sin(angle) * radius, GROUND, math.cos(angle) * radius)
end

local function plotAngle(index: number): number
	return W.PlotAngleOffset + (index - 1) * (2 * math.pi / W.PlotCount)
end

-- Ring stops from `from` to `to` (radians), going the short way round in small steps.
local function alongRing(route: { Stop }, from: number, to: number)
	local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
	local steps = math.max(1, math.ceil(math.abs(delta) / STEP))
	for i = 1, steps do
		table.insert(route, { At = onRing(from + delta * i / steps, RING), Wait = 0, Say = false })
	end
end

-- Shops with an owner in this server come first: that's where the action is.
local function pickShop(rng: Random): number
	local owned: { number } = {}
	local root = market
	if root then
		for _, child in root:GetChildren() do
			local index = child:GetAttribute("PlotIndex")
			local owner = child:GetAttribute("OwnerUserId")
			if typeof(index) == "number" and typeof(owner) == "number" and owner ~= 0 then
				table.insert(owned, index)
			end
		end
	end
	if #owned > 0 and rng:NextNumber() < 0.75 then
		return owned[rng:NextInteger(1, #owned)]
	end
	return rng:NextInteger(1, W.PlotCount)
end

local function planRoute(walker: Walker)
	local rng = walker.Rng
	local route: { Stop } = {}
	local roll = rng:NextNumber()
	if roll < 0.45 then
		-- window-shop: round the ring to a shop's path, out to look, and back
		local shop = pickShop(rng)
		local angle = plotAngle(shop)
		alongRing(route, walker.Angle, angle)
		local front = onRing(angle, SHOP_STOP)
		table.insert(route, {
			At = front,
			Look = onRing(angle, SHOP_STOP + 10),
			Wait = rng:NextNumber(2.5, 5),
			Say = rng:NextNumber() < 0.5,
		})
		table.insert(route, { At = onRing(angle, RING), Wait = 0, Say = false })
		walker.Angle = angle
	elseif roll < 0.65 then
		-- admire the fountain (from a path's direction, where no bench is in the way)
		local angle = plotAngle(rng:NextInteger(1, W.PlotCount))
		alongRing(route, walker.Angle, angle)
		table.insert(route, {
			At = onRing(angle, FOUNTAIN_STOP),
			Look = Vector3.new(0, GROUND, 0),
			Wait = rng:NextNumber(2, 4),
			Say = rng:NextNumber() < 0.3,
		})
		table.insert(route, { At = onRing(angle, RING), Wait = 0, Say = false })
		walker.Angle = angle
	else
		-- a stroll around the ring, then a little rest
		local angle = walker.Angle + (if rng:NextNumber() < 0.5 then -1 else 1) * STEP * rng:NextInteger(1, 3)
		alongRing(route, walker.Angle, angle)
		route[#route].Wait = rng:NextNumber(1, 3)
		walker.Angle = angle
	end
	walker.Route = route
	walker.Index = 1
end

local function say(walker: Walker)
	local old = walker.Bubble
	if old then
		old:Destroy()
	end
	local head = walker.Rig.Model:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then
		return
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Chatter"
	bubble.Size = UDim2.fromOffset(170, 40)
	bubble.StudsOffset = Vector3.new(0, 3.2, 0)
	bubble.MaxDistance = 45
	bubble.LightInfluence = 0
	bubble.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = P.PanelCream
	label.BackgroundTransparency = 0.05
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = P.TextDark
	label.Text = LINES[walker.Rng:NextInteger(1, #LINES)]
	label.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = label
	bubble.Parent = head
	walker.Bubble = bubble
	task.delay(2.6, function()
		if walker.Bubble == bubble then
			walker.Bubble = nil
		end
		bubble:Destroy()
	end)
end

local function step(walker: Walker, dt: number)
	local stop = walker.Route[walker.Index]
	if not stop then
		planRoute(walker)
		return
	end
	local stride = 0
	if walker.Waiting > 0 then
		walker.Waiting -= dt
		if walker.Waiting <= 0 then
			walker.Index += 1
		end
	else
		local offset = stop.At - walker.Position
		local distance = offset.Magnitude
		local move = WALK_SPEED * dt
		if distance <= move then
			walker.Position = stop.At
			local look = stop.Look
			if look then
				local flat = Vector3.new(look.X - stop.At.X, 0, look.Z - stop.At.Z)
				if flat.Magnitude > 0.01 then
					walker.Facing = flat.Unit
				end
			end
			if stop.Wait > 0 then
				walker.Waiting = stop.Wait
				if stop.Say then
					say(walker)
				end
			else
				walker.Index += 1
			end
		else
			local direction = offset / distance
			walker.Position += direction * move
			-- turn smoothly toward where they're going (straight there if it's right behind them)
			local turned = walker.Facing:Lerp(direction, math.min(dt * 8, 1))
			walker.Facing = if turned.Magnitude > 0.05 then turned.Unit else direction
			walker.Travelled += move
			stride = math.sin(walker.Travelled * 1.6) * math.rad(28)
		end
	end
	local bob = math.abs(math.sin(walker.Travelled * 1.6)) * (if stride ~= 0 then 0.1 else 0)
	local position = walker.Position + Vector3.new(0, bob, 0)
	CustomerAnimator.PoseRig(walker.Rig, CFrame.lookAt(position, position + walker.Facing), stride)
end

function Townsfolk.Init(marketFolder: Instance)
	market = marketFolder
	local town = marketFolder:WaitForChild("Town", 10)
	local folder = if town then town:WaitForChild("Townsfolk", 10) else nil
	if not folder then
		return
	end
	for i, villager in folder:GetChildren() do
		if villager:IsA("Model") then
			villager:WaitForChild("Torso", 3)
			local rig = CustomerAnimator.NewRig(villager)
			local start = rig.Rest.Position
			local angle = math.atan2(start.X, start.Z)
			local here = onRing(angle, RING)
			local walker: Walker = {
				Rig = rig,
				Position = here,
				Facing = Vector3.new(math.cos(angle), 0, -math.sin(angle)), -- along the ring
				Route = { { At = here, Wait = 0.2 + (i - 1) * 0.7, Say = false } }, -- don't all set off at once
				Index = 1,
				Waiting = 0,
				Travelled = 0,
				Angle = angle,
				Rng = Random.new(i * 97 + math.floor(os.clock() * 1000) % 1000),
				Bubble = nil,
			}
			table.insert(walkers, walker)
		end
	end
	RunService.RenderStepped:Connect(function(dt: number)
		for _, walker in walkers do
			if walker.Rig.Model.Parent then
				step(walker, math.min(dt, 0.1))
			end
		end
	end)
end

return Townsfolk
