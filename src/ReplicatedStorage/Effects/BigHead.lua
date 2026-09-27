--!strict
-- BigHead (ModuleScript) — ReplicatedStorage.Effects.BigHead
-- Giant Head Potion: the head inflates like a balloon, wobbles, and stays big.

local Effects = require(script.Parent)

return function(customer: Model, fx: Effects.Helpers)
	local head = customer:FindFirstChild("HeadGroup")
	if not head or not head:IsA("Model") then
		return
	end
	local headPart = head:FindFirstChild("Head")
	if headPart and headPart:IsA("BasePart") then
		fx.Burst(headPart, Color3.fromRGB(255, 120, 210), 25)
		fx.Sound("Inflate", headPart)
	end

	local base = head:GetScale() -- relative, so it works on kids too
	local function setScale(value: number)
		if head.Parent then
			head:ScaleTo(math.max(base * value, 0.1))
		end
	end

	fx.TweenNumber(1, 2.4, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), setScale)
	for _ = 1, 2 do
		if not head.Parent then
			return
		end
		fx.TweenNumber(2.4, 2.15, TweenInfo.new(0.18, Enum.EasingStyle.Sine), setScale)
		fx.TweenNumber(2.15, 2.4, TweenInfo.new(0.18, Enum.EasingStyle.Sine), setScale)
	end
end
