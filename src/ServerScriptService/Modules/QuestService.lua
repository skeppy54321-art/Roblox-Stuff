--!strict
-- QuestService (ModuleScript) — ServerScriptService.Modules.QuestService
-- Daily quests: a few small goals a day ("Sell 10 potions", "Get 5 speedy tips") that pay
-- their coins the moment they're done. They start after the tutorial
-- (Tuning.Quests.UnlockSales sales), are picked for the player's progress
-- (Config.MakeQuests) and change at midnight UTC. The other services report what happened
-- with QuestService.Progress; the server's clock decides the day.

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Net = require(Modules:WaitForChild("Net"))

local QuestService = {}

-- The clock quests follow (Unix seconds). Tests replace it.
QuestService.Now = function(): number
	return os.time()
end

-- Gives the player today's quests if they don't have them yet (and have finished the
-- tutorial). Returns true if the quests changed. Doesn't push.
function QuestService.Ensure(player: Player, data: PlayerData.Data): boolean
	if (data.Stats.PotionsSold or 0) < Config.Tuning.Quests.UnlockSales then
		return false
	end
	local day = Config.QuestDay(QuestService.Now())
	if data.Quests.Day == day then
		return false
	end
	data.Quests = { Day = day, List = Config.MakeQuests(data, day, player.UserId) }
	return true
end

-- Something happened that quests may count: "Sell" (amount = potions, `recipe` = which),
-- "Brew", "Collect", "Speedy", "Vip", "BigOrder" or "Earn" (amount = coins). A quest that
-- gets done pays out right away. The caller pushes the state afterwards.
function QuestService.Progress(player: Player, kind: string, amount: number, recipe: string?)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	if QuestService.Ensure(player, data) then
		Net.Cue(player, "NewQuests", {})
	end
	for _, quest in data.Quests.List do
		if not quest.Done and quest.Kind == kind and (quest.Recipe == "" or quest.Recipe == recipe) then
			quest.Have = math.min(quest.Need, quest.Have + amount)
			if quest.Have >= quest.Need then
				quest.Done = true
				data.Coins += quest.Reward
				PlayerData.AddStat(data, "CoinsEarned", quest.Reward)
				PlayerData.AddStat(data, "QuestsDone", 1)
				Net.Cue(player, "Quest", { Text = Config.DescribeQuest(quest), Reward = quest.Reward })
			end
		end
	end
end

function QuestService.Init()
	-- new quests at midnight for everyone who's playing
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)
				if data and QuestService.Ensure(player, data) then
					PlayerData.Push(player)
					Net.Cue(player, "NewQuests", {})
				end
			end
		end
	end)
end

return QuestService
