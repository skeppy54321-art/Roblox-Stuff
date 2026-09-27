--!strict
-- Twirl (ModuleScript) — ReplicatedStorage.Effects.Twirl
-- Twirly Potion: the customer spins like a top (speeds up, then slows down).

local Effects = require(script.Parent)

local TURNS = 5

return function(customer: Model, fx: Effects.Helpers)
	local pivot = customer:GetPivot()
	local torso = customer.PrimaryPart
	fx.Sound("Whoosh", torso)
	if torso then
		fx.Burst(torso, Color3.fromRGB(255, 170, 60), 20, 10)
	end

	fx.Animate(customer, 2.8, function(alpha)
		local eased = alpha * alpha * (3 - 2 * alpha) -- smooth start and stop
		local angle = eased * TURNS * math.pi * 2
		local hop = math.sin(alpha * math.pi) * 0.8
		customer:PivotTo(pivot * CFrame.new(0, hop, 0) * CFrame.Angles(0, angle, 0))
	end)
	if customer.Parent then
		customer:PivotTo(pivot)
	end
end
