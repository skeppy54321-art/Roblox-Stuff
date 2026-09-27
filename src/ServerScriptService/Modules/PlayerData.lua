--!strict
-- PlayerData (ModuleScript) — ServerScriptService.Modules.PlayerData
-- The only module that loads and saves progress. Other modules call Get/Push and
-- change the returned table directly (server only), just like the prototype did.
--
-- Saving uses ProfileStore (by loleris): session locking (no duping between servers),
-- autosave every 5 minutes, and a final save when the player leaves or the server shuts down.
--
-- Studio: data only saves if the place is published AND
-- Game Settings > Security > "Enable Studio Access to API Services" is on.
-- Otherwise ProfileStore runs in mock mode and prints "data will not be saved".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local Net = require(Modules:WaitForChild("Net"))
local ProfileStore = require(Modules:WaitForChild("ProfileStore"))

export type Data = Config.State

-- Changing STORE_NAME starts everyone from scratch. Change SCHEMA_VERSION (and add a
-- step to `migrate`) when the shape of saved data changes instead.
local STORE_NAME = "PlayerData"
local SCHEMA_VERSION = 2
-- true = Studio play tests never touch real saves, even with API access on.
local USE_MOCK_IN_STUDIO = false

local TEMPLATE: Data = {
	SchemaVersion = SCHEMA_VERSION,
	Coins = Config.Tuning.StartingCoins,
	Ingredients = {},
	Potions = {},
	Upgrades = {},
	Discovered = {},
	Stats = {},
	Daily = { Last = 0, Streak = 0 },
}

-- The parts of a ProfileStore profile this module uses.
type Profile = {
	Data: Data,
	AddUserId: (self: Profile, userId: number) -> (),
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> any },
}
type Listener = (player: Player, data: Data) -> ()

local PlayerData = {}

local store = ProfileStore.New(STORE_NAME, TEMPLATE)
local sessions = if USE_MOCK_IN_STUDIO and RunService:IsStudio() then store.Mock else store

local profiles: { [Player]: Profile } = {}
local sessionEndConnections: { [Player]: any } = {}
local listeners: { Listener } = {}

------------------------------------------------------------------
-- Loaded data is never trusted blindly
------------------------------------------------------------------

local function isNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Keeps only known ids with whole, non-negative counts.
local function cleanCounts(map: unknown, known: { [string]: any }): { [string]: number }
	local clean: { [string]: number } = {}
	if typeof(map) == "table" then
		for id, count in map :: { [any]: any } do
			if typeof(id) == "string" and known[id] ~= nil and isNumber(count) then
				local whole = math.max(0, math.floor(count))
				if whole > 0 then
					clean[id] = whole
				end
			end
		end
	end
	return clean
end

-- Upgrades data from older versions. Each step handles exactly one version.
local function migrate(data: Data)
	local version = if isNumber(data.SchemaVersion) then data.SchemaVersion else 0
	if version < 1 then
		-- 0 -> 1: first saved version, nothing to convert.
		version = 1
	end
	if version < 2 then
		-- 1 -> 2: the daily gift. Reconcile already added Daily from the template; a
		-- returning player starts a fresh streak with a gift ready.
		version = 2
	end
	data.SchemaVersion = version
end

local function sanitize(data: Data)
	data.Coins = if isNumber(data.Coins) then math.max(0, math.floor(data.Coins)) else 0
	data.Ingredients = cleanCounts(data.Ingredients, Config.Ingredients)
	data.Potions = cleanCounts(data.Potions, Config.Recipes)
	data.Upgrades = cleanCounts(data.Upgrades, Config.Upgrades)
	for id, level in data.Upgrades do
		data.Upgrades[id] = math.min(level, Config.GetMaxLevel(id))
	end
	local discovered: { [string]: boolean } = {}
	if typeof(data.Discovered) == "table" then
		for id, value in data.Discovered :: { [any]: any } do
			if typeof(id) == "string" and Config.Recipes[id] and value == true then
				discovered[id] = true
			end
		end
	end
	data.Discovered = discovered
	local stats: { [string]: number } = {}
	if typeof(data.Stats) == "table" then
		for key, value in data.Stats :: { [any]: any } do
			if typeof(key) == "string" and isNumber(value) then
				stats[key] = math.max(0, value)
			end
		end
	end
	data.Stats = stats
	local daily: any = data.Daily
	local last = if typeof(daily) == "table" and isNumber(daily.Last) then math.max(0, math.floor(daily.Last)) else 0
	local streak = if typeof(daily) == "table" and isNumber(daily.Streak)
		then math.clamp(math.floor(daily.Streak), 0, 100000)
		else 0
	data.Daily = { Last = last, Streak = streak }
end

------------------------------------------------------------------
-- Sessions
------------------------------------------------------------------

-- Loads the player's saved progress. Yields. Returns nil if the player left while
-- loading, or if it failed (the player is kicked so they can't play unsaved).
function PlayerData.Load(player: Player): Data?
	local profile: Profile? = (sessions :: any):StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		if player.Parent == Players then
			player:Kick("Your potion shop couldn't load. Please rejoin!")
		end
		return nil
	end

	profile:AddUserId(player.UserId) -- lets Roblox erase this data if the user asks (GDPR)
	profile:Reconcile() -- fills in anything new from TEMPLATE
	migrate(profile.Data)
	sanitize(profile.Data)

	-- Only fires on its own if another server takes the session (Release disconnects it first).
	sessionEndConnections[player] = profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		sessionEndConnections[player] = nil
		if player.Parent == Players and not ProfileStore.IsClosing then
			player:Kick("Your shop was opened on another server. Please rejoin!")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return nil
	end

	profiles[player] = profile
	player:SetAttribute("SaveMode", ProfileStore.DataStoreState) -- "Access" = saving for real
	return profile.Data
end

-- Ends the session: final save, then the data is released for other servers.
function PlayerData.Release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	local connection = sessionEndConnections[player]
	sessionEndConnections[player] = nil
	if connection then
		connection:Disconnect() -- a normal leave is not "opened on another server"
	end
	if profile then
		profile:EndSession()
	end
end

function PlayerData.Get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Send the player's full state to their client. Call after every change.
function PlayerData.Push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Net.StateUpdate:FireClient(player, profile.Data)
	for _, listener in listeners do
		task.spawn(listener, player, profile.Data)
	end
end

-- Called (after Push) whenever a player's data changes.
function PlayerData.OnChanged(listener: Listener)
	table.insert(listeners, listener)
end

function PlayerData.AddStat(data: Data, key: string, amount: number)
	data.Stats[key] = (data.Stats[key] or 0) + amount
end

return PlayerData
