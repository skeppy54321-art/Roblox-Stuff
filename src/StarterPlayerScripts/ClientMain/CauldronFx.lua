--!strict
-- CauldronFx (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.CauldronFx
-- Your own cauldron: a progress bar with the potion's name while it brews, a bubbling
-- sound, a splash of bubbles every time you stir, and a bottle that pops out when a
-- potion is done.

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local P = Config.Palette

local CauldronFx = {}

local bar: BillboardGui
local fill: Frame
local nameLabel: TextLabel
local watched: Model? = nil
local watchConnection: RBXScriptConnection? = nil
local lastEndTime = 0
local bubbling = false

local function brewInfo(cauldron: Model): (number, number, string)
	local endTime = cauldron:GetAttribute("BrewEndTime")
	local duration = cauldron:GetAttribute("BrewDuration")
	local recipe = cauldron:GetAttribute("BrewRecipe")
	return if typeof(endTime) == "number" then endTime else 0,
		if typeof(duration) == "number" then duration else 0,
		if typeof(recipe) == "string" then recipe else ""
end

function CauldronFx.Init(playerGui: PlayerGui)
	bar = Instance.new("BillboardGui")
	bar.Name = "BrewBar"
	bar.Size = UDim2.fromOffset(190, 54)
	bar.StudsOffset = Vector3.new(0, 4.8, 0)
	bar.AlwaysOnTop = true
	bar.LightInfluence = 0
	bar.ResetOnSpawn = false
	bar.Enabled = false
	nameLabel = Ui.label({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = P.DarkWood,
		Parent = bar,
	}, 20)
	local back = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = P.PanelDark,
		Parent = bar,
	}, { Ui.round(), Ui.stroke(P.Gold, 2) })
	fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = P.Liquid,
		Parent = back,
	}, { Ui.round() })
	bar.Parent = playerGui

	RunService.RenderStepped:Connect(function()
		local cauldron = watched
		if not cauldron or not cauldron.Parent then
			bar.Enabled = false
			return
		end
		local endTime, duration, recipeId = brewInfo(cauldron)
		local now = workspace:GetServerTimeNow()
		local isBrewing = duration > 0 and endTime > now
		bar.Enabled = isBrewing
		if isBrewing then
			local recipe = Config.Recipes[recipeId]
			fill.Size = UDim2.fromScale(math.clamp(1 - (endTime - now) / duration, 0, 1), 1)
			if recipe then
				fill.BackgroundColor3 = recipe.Color
				nameLabel.Text = recipe.DisplayName
			end
		end
		if isBrewing ~= bubbling then
			bubbling = isBrewing
			local hitbox = cauldron:FindFirstChild("Hitbox")
			if isBrewing and hitbox and hitbox:IsA("BasePart") then
				Sfx.StartLoop("Cauldron", "Bubbling", hitbox)
			else
				Sfx.StopLoop("Cauldron")
			end
		end
	end)
end

local POP_SECONDS = 1.25
local BOTTLE_SIZE = Vector3.new(1.3, 0.85, 0.85) -- a cylinder's length runs along X
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function easeOutBack(t: number): number
	local c = 1.7
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

local function sparkle(position: Vector3, color: Color3)
	local holder = Instance.new("Part")
	holder.Name = "PopSparkle"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, P.Gold)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(26)
	Debris:AddItem(holder, 2)
end

-- A bottle of the finished potion jumps out of your cauldron, spins, and sparkles away
-- (the new bottle appears on your counter at the same time).
function CauldronFx.Pop(color: Color3)
	local cauldron = watched
	local liquid = if cauldron then cauldron:FindFirstChild("Liquid") else nil
	if not cauldron or not liquid or not liquid:IsA("BasePart") then
		return
	end
	local bubbles = cauldron:FindFirstChild("Bubbles", true)
	if bubbles and bubbles:IsA("ParticleEmitter") then
		bubbles:Emit(20)
	end
	local bottle = Instance.new("Part")
	bottle.Name = "PopBottle"
	bottle.Shape = Enum.PartType.Cylinder
	bottle.Size = BOTTLE_SIZE
	bottle.Material = Enum.Material.Neon
	bottle.Color = color
	bottle.Anchored = true
	bottle.CanCollide = false
	bottle.CanQuery = false
	bottle.CanTouch = false
	bottle.CastShadow = false
	local start = liquid.Position
	bottle.CFrame = CFrame.new(start) * UPRIGHT
	bottle.Parent = workspace
	task.spawn(function()
		local began = os.clock()
		while bottle.Parent do
			local t = os.clock() - began
			if t >= POP_SECONDS then
				break
			end
			local rise = 3.4 * easeOutBack(math.min(t / 0.45, 1))
			local shrink = if t > 0.95 then math.max(0, 1 - (t - 0.95) / (POP_SECONDS - 0.95)) else 1
			bottle.Size = BOTTLE_SIZE * math.max(shrink, 0.05)
			bottle.CFrame = CFrame.new(start + Vector3.new(0, rise, 0)) * CFrame.Angles(0, t * 9, 0) * UPRIGHT
			RunService.RenderStepped:Wait()
		end
		if bottle.Parent then
			sparkle(bottle.Position, color)
			bottle:Destroy()
		end
	end)
end

-- Follow the local player's own cauldron (nil when they have no shop).
function CauldronFx.Watch(cauldron: Model?)
	if cauldron == watched then
		return
	end
	if watchConnection then
		watchConnection:Disconnect()
		watchConnection = nil
	end
	watched = cauldron
	local hitbox = if cauldron then cauldron:FindFirstChild("Hitbox") else nil
	if hitbox and hitbox:IsA("BasePart") then
		bar.Adornee = hitbox
	end
	if not cauldron then
		return -- the bar hides itself while nothing is watched
	end
	lastEndTime = brewInfo(cauldron)
	watchConnection = cauldron:GetAttributeChangedSignal("BrewEndTime"):Connect(function()
		local endTime = brewInfo(cauldron)
		-- the end time moved earlier while brewing = a stir: splash some bubbles
		if endTime > 0 and lastEndTime > 0 and endTime < lastEndTime then
			local bubbles = cauldron:FindFirstChild("Bubbles", true)
			if bubbles and bubbles:IsA("ParticleEmitter") then
				bubbles:Emit(16)
			end
		end
		lastEndTime = endTime
	end)
end

return CauldronFx
