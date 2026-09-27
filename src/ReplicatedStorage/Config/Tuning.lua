--!strict
-- Tuning (ModuleScript) — ReplicatedStorage.Config.Tuning
-- Gameplay numbers: distances, cooldowns, timings, storage.
-- Expect to tune these after playtesting.

local Tuning = {}

-- Server allows interactions from this far (a little more than the prompt range, for lag).
Tuning.InteractDistance = 14
Tuning.PromptDistance = 10

Tuning.StartingCoins = 0

Tuning.Sources = {
	MaxCharges = 3, -- how many you can grab before it needs to regrow (Green Thumb raises it)
	RegenSeconds = 3, -- one charge regrows every N seconds (Green Thumb lowers it)
	CollectCooldown = 0.25,
	ChargeSlots = 5, -- charge parts built on each source = the highest MaxCharges any level gives
}

Tuning.Storage = {
	MaxPerIngredient = 10,
	MaxPotions = 5, -- Bigger Shelves raises it
}

Tuning.Brewing = {
	BaseSeconds = 6, -- Faster Brewing lowers it; each recipe multiplies it
	StirSeconds = 0.75, -- each stir cuts this much time
	MaxStirs = 3, -- stirs allowed per brew
	StirCooldown = 0.3,
	MinRemaining = 0.3, -- a stir never finishes a brew instantly
}

Tuning.Customers = {
	FirstSpawnDelay = 1,
	RespawnSeconds = 1.5, -- gap between one customer leaving and the next arriving
	WalkSpeed = 8, -- studs per second walking to and from the counter
	WalkDistance = 20, -- how far out on the plaza they start walking from
	EffectSeconds = 4.4, -- how long the customer stays after buying (drinking ~0.8s + the effect)
	SellCooldown = 0.5,
	Patience = 45, -- a waiting customer gives up and leaves after this long
	TipWindow = 8, -- serve a customer this soon after they reach the counter for a tip
	TipShare = 0.2, -- the tip, as a share of the price (rounded up)
	StuckPatience = 6, -- ...or after this long if your shelf is full and none of their potion is on it
	StockBias = 0.6, -- chance a customer asks for a potion you already have on your shelf
	BigOrderChance = 0.12, -- chance a customer wants several of one potion (after BigOrderMinSales sales)
	BigOrderMinSales = 20,
	BigOrderSize = 3,
	BigOrderBonus = 1.5, -- big orders pay this much more per potion
	BigOrderPatience = 2, -- ...and wait this many times longer
	KidChance = 0.2, -- chance a customer is a kid (a bit smaller)
	KidScale = 0.78,
	VipChance = 0.12, -- chance a customer is a VIP (after VipMinSales sales)
	VipMinSales = 5,
	VipPriceMultiplier = 2,
}

-- The bouncing helper arrow shows until this many potions have been sold.
Tuning.GuideUntilSales = 8

-- The order the goal banner suggests upgrades in. Each entry means "the next level of
-- this upgrade" (the 2nd "Shelves" is Shelves level 2). New potions come early, then the
-- boosts. The banner waits (you save up) until the next step is affordable; after the
-- path, it suggests anything useful that's left, and cosmetics last.
Tuning.UpgradePath = {
	"BrewSpeed",
	"StarflowerBed",
	"Shelves",
	"BrewSpeed",
	"GreenThumb",
	"CounterSpace",
	"StarWell", -- (only after a rebirth; skipped before)
	"FrostGrotto",
	"Shelves",
	"BrewSpeed",
	"GreenThumb",
	"EmberGarden",
	"CloudGarden",
}

Tuning.Rebirth = {
	Requires = "CloudGarden", -- you can rebirth once you've bought this
	BaseCost = 5000, -- coins for the first rebirth
	CostStep = 5000, -- each rebirth after that costs this much more
	CoinBonus = 0.25, -- +25% coins from every sale, per rebirth
	Keep = { "CozyDecor", "Familiar" }, -- upgrades you keep (everything else starts over)
}

-- Daily quests (QuestService): a few small goals a day that pay coins when done. The
-- tables are how many it takes at tier 1 / 2 / 3 (the priciest potion you can make:
-- up to 24 coins, up to 70, more).
Tuning.Quests = {
	UnlockSales = 8, -- quests start after this many sales (the tutorial comes first)
	Count = 3, -- quests a day
	Sell = { 6, 10, 15 },
	Brew = { 6, 10, 14 },
	Collect = { 15, 25, 40 },
	Speedy = { 3, 5, 6 },
}

Tuning.Daily = {
	CooldownHours = 20, -- a new gift this long after the last one
	StreakHours = 48, -- come back within this long to keep your streak going
	Rewards = { 30, 50, 80, 120, 160, 220, 300 }, -- coins on day 1..7 of a streak; later days repeat the last
}

Tuning.Social = {
	CheerCooldown = 1, -- seconds between cheer presses (each shop can be cheered once per visit)
	NewsGap = 3, -- at most one market news item per player this often
	BoardRefreshSeconds = 2, -- the Market Stars board redraws this often when something changed
}

return Tuning
