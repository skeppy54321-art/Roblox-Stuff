-- Effects (ModuleScript) — ReplicatedStorage.Effects
-- Cosmetic customer effects. Runs ONLY on clients. Never touches coins or inventory.
-- Add a new effect by adding a function with the same name used in Config.Recipes[...].Effect

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Effects = {}

local function burst(part: BasePart, color: Color3, count: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(count)
	Debris:AddItem(emitter, 2)
end

-- Tween a number and call onStep(value) every frame it changes.
local function tweenNumber(from: number, to: number, info: TweenInfo, onStep: (number) -> ())
	local value = Instance.new("NumberValue")
	value.Value = from
	local conn = value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, info, { Value = to })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	value:Destroy()
end

-- Customer's head inflates like a balloon, wobbles, then stays big.
function Effects.BigHead(customer: Model)
	local head = customer:FindFirstChild("HeadGroup")
	if not head or not head:IsA("Model") then
		return
	end
	local headPart = head:FindFirstChild("Head")
	if headPart and headPart:IsA("BasePart") then
		burst(headPart, Color3.fromRGB(255, 120, 210), 25)
	end

	local function setScale(v: number)
		if head.Parent then
			head:ScaleTo(math.max(v, 0.1))
		end
	end

	tweenNumber(1, 2.4, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), setScale)
	for _ = 1, 2 do
		if not head.Parent then
			return
		end
		tweenNumber(2.4, 2.15, TweenInfo.new(0.18, Enum.EasingStyle.Sine), setScale)
		tweenNumber(2.15, 2.4, TweenInfo.new(0.18, Enum.EasingStyle.Sine), setScale)
	end
end

-- Safe entry point used by ClientMain.
function Effects.Play(effectName: string, model: Instance?)
	if typeof(effectName) ~= "string" or effectName == "Play" then
		return
	end
	local fn = Effects[effectName]
	if typeof(fn) ~= "function" then
		return
	end
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then
		return
	end
	task.spawn(fn, model)
end

return Effects
