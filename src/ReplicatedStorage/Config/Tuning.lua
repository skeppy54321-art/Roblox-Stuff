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
	EffectSeconds = 3.6, -- how long the customer stays after drinking
	SellCooldown = 0.5,
	StockBias = 0.6, -- chance a customer asks for a potion you already have on your shelf
	VipChance = 0.12, -- chance a customer is a VIP (after VipMinSales sales)
	VipMinSales = 5,
	VipPriceMultiplier = 2,
}

-- The bouncing helper arrow shows until this many potions have been sold.
Tuning.GuideUntilSales = 8

Tuning.Social = {
	CheerCooldown = 1, -- seconds between cheer presses (each shop can be cheered once per visit)
	NewsGap = 3, -- at most one market news item per player this often
	BoardRefreshSeconds = 2, -- the Market Stars board redraws this often when something changed
}

return Tuning
