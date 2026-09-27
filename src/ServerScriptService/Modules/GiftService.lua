--!strict
-- GiftService (ModuleScript) — ServerScriptService.Modules.GiftService
-- The daily gift: once every CooldownHours, and more coins for every day in a row you come
-- back (see Config.Tuning.Daily). The server's own clock decides; the client only asks.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))

local GiftService = {}

-- Unix seconds. A function so tests can move time forward.
GiftService.Now = function(): number
	return os.time()
end

function GiftService.Claim(player: Player)
	if not Guard.Cooldown(player, "Daily", 1) then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local now = GiftService.Now()
	local ready, day, reward, wait = Config.GetDailyGift(data.Daily, now)
	if not ready then
		Net.Notify(player, `Your next gift is ready in {Config.FormatDuration(wait)}.`)
		return
	end

	-- All checks passed (no yields since reading the data, so it can't be claimed twice).
	data.Daily.Last = now
	data.Daily.Streak = day
	data.Coins += reward
	PlayerData.AddStat(data, "DailyGifts", 1)
	PlayerData.Push(player)
	Net.Cue(player, "Daily", { Amount = reward, Day = day })
end

function GiftService.Init()
	Net.ClaimDaily.OnServerEvent:Connect(GiftService.Claim)
end

return GiftService
