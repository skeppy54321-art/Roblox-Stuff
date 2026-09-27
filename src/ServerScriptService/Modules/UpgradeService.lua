-- UpgradeService (ModuleScript) — ServerScriptService.Modules.UpgradeService
-- Buying upgrades with coins. Client only ASKS; server checks and decides.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local PlotService = require(Modules:WaitForChild("PlotService"))

local UpgradeService = {}

-- Visible change: the cauldron fire changes color with each BrewSpeed level.
function UpgradeService.ApplyVisuals(plot: Model, brewSpeedLevel: number)
	local cauldron = plot:FindFirstChild("Cauldron")
	local fire = cauldron and cauldron:FindFirstChild("Fire")
	if not fire or not fire:IsA("BasePart") then
		return
	end
	local levels = Config.Upgrades.BrewSpeed.Levels
	local color = Config.Palette.Fire
	if brewSpeedLevel > 0 then
		color = levels[math.min(brewSpeedLevel, #levels)].FireColor
	end
	fire.Color = color
	local light = fire:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
	end
end

local function onRequest(player: Player, upgradeId: unknown)
	if typeof(upgradeId) ~= "string" then
		return
	end
	local upgrade = Config.Upgrades[upgradeId]
	if not upgrade then
		return
	end
	if not Guard.Cooldown(player, "Upgrade", 0.5) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local level = data.Upgrades[upgradeId] or 0
	local cost = Config.GetNextUpgradeCost(upgradeId, level)
	if not cost then
		Net.Notify(player, `{upgrade.DisplayName} is maxed out!`)
		return
	end
	if data.Coins < cost then
		Net.Notify(player, `You need {cost - data.Coins} more coins.`)
		return
	end

	-- All checks passed.
	data.Coins -= cost
	data.Upgrades[upgradeId] = level + 1
	local plot = PlotService.GetPlot(player)
	if plot and upgradeId == "BrewSpeed" then
		UpgradeService.ApplyVisuals(plot, level + 1)
	end
	PlayerData.Push(player)
	Net.Notify(player, `{upgrade.DisplayName} upgraded to level {level + 1}!`)
end

function UpgradeService.Init()
	Net.RequestUpgrade.OnServerEvent:Connect(onRequest)
end

return UpgradeService
