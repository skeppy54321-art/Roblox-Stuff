--!strict
-- UpgradeService (ModuleScript) — ServerScriptService.Modules.UpgradeService
-- Buying upgrades with coins, from the Upgrades panel (RequestUpgrade remote) or the
-- "for sale" signs in the shop. The client only ASKS; the server checks and decides.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local PlotService = require(Modules:WaitForChild("PlotService"))
local IngredientService = require(Modules:WaitForChild("IngredientService"))
local CustomerService = require(Modules:WaitForChild("CustomerService"))

type Plot = PlotService.Plot

local UpgradeService = {}

-- Makes the whole shop match the owner's upgrades (visuals, plants, counter spots).
function UpgradeService.ApplyAll(plot: Plot, upgrades: { [string]: number }?)
	PlotService.ApplyVisuals(plot, upgrades)
	IngredientService.ApplyOwner(plot, upgrades, false)
	if upgrades then
		CustomerService.UpdateSlots(plot, upgrades)
	end
end

function UpgradeService.Purchase(player: Player, upgradeId: unknown)
	if not Guard.IsId(upgradeId, Config.Upgrades) then
		return
	end
	local id = upgradeId :: string
	if not Guard.Cooldown(player, "Upgrade", 0.4) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local upgrade = Config.Upgrades[id]
	if not Config.IsUpgradeAvailable(data.Upgrades, id) then
		local required = Config.Upgrades[upgrade.Requires or ""]
		Net.Notify(player, `Buy {if required then required.DisplayName else "the one before it"} first!`, "bad")
		return
	end
	local level = Config.GetLevel(data.Upgrades, id)
	local cost = Config.GetNextUpgradeCost(id, level)
	if not cost then
		Net.Notify(player, `{upgrade.DisplayName} is maxed out!`)
		return
	end
	if data.Coins < cost then
		Net.Notify(player, `You need {cost - data.Coins} more coins.`, "bad")
		return
	end

	-- All checks passed.
	data.Coins -= cost
	data.Upgrades[id] = level + 1
	PlayerData.AddStat(data, "CoinsSpent", cost)
	local plot = PlotService.GetPlot(player)
	if plot then
		UpgradeService.ApplyAll(plot, data.Upgrades)
	end
	PlayerData.Push(player)
	Net.Cue(player, "Upgrade", { Upgrade = id, Level = level + 1 })
	local maxLevel = Config.GetMaxLevel(id)
	local suffix = if maxLevel > 1 then ` (level {level + 1})` else ""
	Net.Notify(player, `{upgrade.DisplayName}{suffix}!`, "good")
end

function UpgradeService.Init(plots: { Plot })
	Net.RequestUpgrade.OnServerEvent:Connect(UpgradeService.Purchase)
	-- "for sale" signs for locked plants
	for _, plot in plots do
		for upgradeId, lot in plot.Lots do
			local prompt = lot:FindFirstChild("UnlockPrompt", true)
			local hitbox = lot:FindFirstChild("Hitbox")
			if prompt and prompt:IsA("ProximityPrompt") and hitbox and hitbox:IsA("BasePart") then
				prompt.Triggered:Connect(function(player)
					if Guard.Owns(player, plot.Model) and Guard.Near(player, hitbox) then
						UpgradeService.Purchase(player, upgradeId)
					end
				end)
			end
		end
	end
end

return UpgradeService
