--!strict
-- Tiny (ModuleScript) — ReplicatedStorage.Effects.Tiny
-- Tiny Potion: poof! The customer shrinks to pocket size and does two happy hops.

local Effects = require(script.Parent)

return function(customer: Model, fx: Effects.Helpers)
	local torso = customer.PrimaryPart
	local pivot = customer:GetPivot()
	fx.Poof(pivot.Position + Vector3.new(0, 2.5, 0), Color3.fromRGB(150, 210, 255), 4)
	fx.Sound("Shrink", torso)

	fx.TweenNumber(1, 0.35, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), function(value)
		if customer.Parent then
			customer:ScaleTo(value)
		end
	end)

	for _ = 1, 2 do
		fx.Sound("Hop", torso)
		fx.Animate(customer, 0.35, function(alpha)
			customer:PivotTo(pivot + Vector3.new(0, math.sin(alpha * math.pi) * 1.2, 0))
		end)
		task.wait(0.15)
	end
	if customer.Parent then
		customer:PivotTo(pivot)
	end
end
