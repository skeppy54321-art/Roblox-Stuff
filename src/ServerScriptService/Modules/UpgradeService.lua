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
local SocialService = require(Modules:WaitForChild("SocialService"))
local BrewService = require(Modules:WaitForChild("BrewService"))

type Plot = PlotService.Plot

local UpgradeService = {}

-- Things that follow the player rather than the shop: their familiar (clients draw it).
function UpgradeService.ApplyPlayer(player: Player, upgrades: { [string]: number })
	player:SetAttribute("Familiar", Config.GetLevel(upgrades, "Familiar"))
end

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
	UpgradeService.ApplyPlayer(player, data.Upgrades)
	PlayerData.Push(player)
	Net.Cue(player, "Upgrade", { Upgrade = id, Level = level + 1 }) -- the client celebrates
	if upgrade.Announce then
		SocialService.Announce(player, `{player.DisplayName} {upgrade.Announce}!`)
	end
end

-- Rebirth: start the shop over (coins, ingredients, potions, useful upgrades) for a
-- permanent coin bonus. Cosmetics (Tuning.Rebirth.Keep), recipes and stats are kept.
function UpgradeService.Rebirth(player: Player)
	if not Guard.Cooldown(player, "Rebirth", 2) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local ok, reason = Config.CanRebirth(data)
	if not ok then
		Net.Notify(player, `Not yet: {reason or "keep going"}.`, "bad")
		return
	end
	if BrewService.IsBrewing(player) then
		Net.Notify(player, "Finish your brew first!", "bad")
		return
	end

	-- All checks passed (no yields since reading the data).
	local kept: { [string]: number } = {}
	for _, id in Config.Tuning.Rebirth.Keep do
		local level = data.Upgrades[id]
		if level then
			kept[id] = level
		end
	end
	data.Coins = 0
	data.Ingredients = {}
	data.Potions = {}
	data.Upgrades = kept
	data.Rebirths += 1
	local plot = PlotService.GetPlot(player)
	if plot then
		UpgradeService.ApplyAll(plot, data.Upgrades)
		IngredientService.ApplyOwner(plot, data.Upgrades, true)
		CustomerService.StartPlot(plot, player) -- one counter spot again, fresh customers
	end
	UpgradeService.ApplyPlayer(player, data.Upgrades)
	PlotService.RefreshSign(player, data)
	PlayerData.Push(player)
	Net.Cue(player, "Rebirth", { Rebirths = data.Rebirths, Multiplier = Config.GetCoinMultiplier(data.Rebirths) })
	SocialService.Announce(player, `{player.DisplayName} started their shop over for Rebirth {data.Rebirths}!`)
end

-- Shop Colors: pick one of the awning themes for your shop (free, saved).
function UpgradeService.Paint(player: Player, themeIndex: unknown)
	if typeof(themeIndex) ~= "number" or themeIndex ~= math.floor(themeIndex) then
		return
	end
	if themeIndex < 1 or themeIndex > #Config.Palette.Awnings then
		return
	end
	if not Guard.Cooldown(player, "Paint", 0.5) then
		return
	end
	local data = PlayerData.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then
		return
	end
	data.Theme = themeIndex
	PlotService.ApplyTheme(plot, themeIndex)
	PlayerData.Push(player)
	Net.Cue(player, "Paint", { Theme = themeIndex })
end

function UpgradeService.Init(plots: { Plot })
	Net.RequestUpgrade.OnServerEvent:Connect(UpgradeService.Purchase)
	Net.RequestPaint.OnServerEvent:Connect(UpgradeService.Paint)
	Net.RequestRebirth.OnServerEvent:Connect(UpgradeService.Rebirth)
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
