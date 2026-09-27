--!strict
-- Effects (ModuleScript) — ReplicatedStorage.Effects
-- Cosmetic customer effects. Runs ONLY on clients. Never touches coins or inventory.
-- Each child module is one effect: `return function(customer: Model, fx: Effects.Helpers)`.
-- Add a new potion effect by adding a child module named like Config.Recipes[...].Effect.
-- Effects should finish within Config.Tuning.Customers.EffectSeconds (the customer walks away after).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

export type Helpers = {
	-- Particles flying out of `part` once.
	Burst: (part: BasePart, color: Color3, count: number, speed: number?) -> (),
	-- A puff of smoke at `position`.
	Poof: (position: Vector3, color: Color3, size: number?) -> (),
	-- Tween a number and call onStep(value) as it changes (yields until done).
	TweenNumber: (from: number, to: number, info: TweenInfo, onStep: (number) -> ()) -> (),
	-- Calls onStep(alpha 0..1, dt) every frame for `seconds` (yields). Stops if the customer is removed.
	Animate: (customer: Model, seconds: number, onStep: (alpha: number, dt: number) -> ()) -> (),
	-- All the customer's own parts (not the speech bubble's).
	BodyParts: (customer: Model) -> { BasePart },
	-- Plays a sound from Config.Sounds at the customer.
	Sound: (name: string, part: BasePart?) -> (),
}

type EffectFn = (customer: Model, fx: Helpers) -> ()

local Effects = {}

local soundPlayer: ((name: string, part: BasePart?) -> ())? = nil

local function burst(part: BasePart, color: Color3, count: number, speed: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	local s = speed or 8
	emitter.Speed = NumberRange.new(s * 0.75, s * 1.25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(count)
	Debris:AddItem(emitter, 2)
end

local function poof(position: Vector3, color: Color3, size: number?)
	local holder = Instance.new("Part")
	holder.Name = "Poof"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * (size or 3)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(color)
	smoke.LightEmission = 0.3
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3.2),
	})
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.RotSpeed = NumberRange.new(-90, 90)
	smoke.Rate = 0
	smoke.Parent = holder
	smoke:Emit(18)
	Debris:AddItem(holder, 2)
end

local function tweenNumber(from: number, to: number, info: TweenInfo, onStep: (number) -> ())
	local value = Instance.new("NumberValue")
	value.Value = from
	local connection = value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, info, { Value = to })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	value:Destroy()
end

local function animate(customer: Model, seconds: number, onStep: (number, number) -> ())
	local start = os.clock()
	while customer.Parent do
		local dt = RunService.RenderStepped:Wait()
		local alpha = math.min((os.clock() - start) / seconds, 1)
		onStep(alpha, dt)
		if alpha >= 1 then
			break
		end
	end
end

local function bodyParts(customer: Model): { BasePart }
	local parts = {}
	for _, d in customer:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function sound(name: string, part: BasePart?)
	if soundPlayer then
		soundPlayer(name, part)
	end
end

local helpers: Helpers = {
	Burst = burst,
	Poof = poof,
	TweenNumber = tweenNumber,
	Animate = animate,
	BodyParts = bodyParts,
	Sound = sound,
}

-- ClientMain hands in its sound player (this module can't reach client-only modules).
function Effects.SetSoundPlayer(player: (name: string, part: BasePart?) -> ())
	soundPlayer = player
end

-- Safe entry point used by ClientMain: unknown names or missing models are ignored,
-- and a broken effect only prints a warning.
function Effects.Play(effectName: unknown, model: unknown)
	if typeof(effectName) ~= "string" or typeof(model) ~= "Instance" then
		return
	end
	local customer = model :: Instance
	if not customer:IsA("Model") or not customer.Parent then
		return
	end
	local moduleScript = script:FindFirstChild(effectName)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return
	end
	local ok, effect = pcall(function(): any
		return (require :: any)(moduleScript)
	end)
	if not ok or typeof(effect) ~= "function" then
		warn(`[Effects] {effectName} failed to load: {effect}`)
		return
	end
	local fn = effect :: EffectFn
	task.spawn(function()
		local success, err = pcall(function(): any
			fn(customer, helpers)
			return nil
		end)
		if not success then
			warn(`[Effects] {effectName} errored: {err}`)
		end
	end)
end

return Effects
