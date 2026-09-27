--!strict
-- Ambience (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Ambience
-- Small client-only touches that make the market feel alive: the giant potion on the
-- fountain slowly cycles through every potion color, and fires and lanterns flicker (and
-- glow brighter at dusk: see DayCycle).
-- Cheap: updates about 15 times a second and only touches lights and one part.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Ambience = {}

-- Every light here is shown at this times its normal brightness (DayCycle turns it up at dusk).
Ambience.LightScale = 1

local flickers: { [PointLight]: { Base: number, Seed: number } } = {} -- normal brightness + a random phase
local statue: BasePart? = nil
local statueLight: PointLight? = nil
local statueBrightness = 0

local function consider(inst: Instance)
	if inst:IsA("PointLight") and flickers[inst] == nil then
		flickers[inst] = { Base = inst.Brightness, Seed = math.random() * 100 }
		inst.Destroying:Connect(function()
			flickers[inst] = nil
		end)
	elseif inst:IsA("BasePart") and inst.Name == "PotionGlass" then
		statue = inst
		local light = inst:FindFirstChildOfClass("PointLight")
		statueLight = light
		statueBrightness = if light then light.Brightness else 0
	end
end

function Ambience.Init(market: Instance)
	for _, d in market:GetDescendants() do
		consider(d)
	end
	market.DescendantAdded:Connect(consider)

	local colors = {}
	for _, id in Config.RecipeOrder do
		table.insert(colors, Config.Recipes[id].Color)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 15 then
			return
		end
		elapsed = 0
		local t = os.clock()

		-- fountain potion: blend from one potion color to the next
		if statue and statue.Parent then
			local position = (t / 3) % #colors
			local index = math.floor(position)
			local color = colors[index + 1]:Lerp(colors[(index + 1) % #colors + 1], position - index)
			statue.Color = color
			if statueLight then
				statueLight.Color = color
				statueLight.Brightness = statueBrightness * Ambience.LightScale
			end
		end

		-- flicker (skipped for the statue, whose light is steady)
		local scale = Ambience.LightScale
		for light, info in flickers do
			if light ~= statueLight then
				light.Brightness = info.Base * scale * (0.85 + 0.3 * (math.noise(t * 3, info.Seed, 0) + 0.5))
			end
		end
	end)
end

return Ambience
