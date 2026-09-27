--!strict
-- Net (ModuleScript) — ServerScriptService.Modules.Net
-- Creates every RemoteEvent/RemoteFunction and wraps sending to clients.
-- Client -> server remotes only ASK; the server checks everything before acting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Remotes"
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
end
assert(folder, "Remotes folder")

local function remote(className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = folder
	return inst
end

-- server -> client
Net.StateUpdate = remote("RemoteEvent", "StateUpdate") :: RemoteEvent -- (state) the player's full progress
Net.NotifyRemote = remote("RemoteEvent", "Notify") :: RemoteEvent -- (text, kind) short message (see NotifyKind)
Net.CueRemote = remote("RemoteEvent", "Cue") :: RemoteEvent -- (cue, data) feedback moment for sounds/popups
Net.PlayEffect = remote("RemoteEvent", "PlayEffect") :: RemoteEvent -- (customer, effectName) to everyone
-- client -> server
Net.RequestUpgrade = remote("RemoteEvent", "RequestUpgrade") :: RemoteEvent -- (upgradeId)
Net.RequestBrew = remote("RemoteEvent", "RequestBrew") :: RemoteEvent -- (recipeId)
Net.GetState = remote("RemoteFunction", "GetState") :: RemoteFunction -- () -> state or nil while loading
Net.ClaimDaily = remote("RemoteEvent", "ClaimDaily") :: RemoteEvent -- () the daily gift
Net.RequestRebirth = remote("RemoteEvent", "RequestRebirth") :: RemoteEvent -- () start the shop over for a bonus
Net.StudioCoins = remote("RemoteEvent", "StudioCoins") :: RemoteEvent -- () Studio play tests only: +10,000 coins
Net.RequestPaint = remote("RemoteEvent", "RequestPaint") :: RemoteEvent -- (themeIndex) repaint your shop

-- "news" = something another player did; "heart" = a cheer
export type NotifyKind = "info" | "good" | "bad" | "news" | "heart"

function Net.Notify(player: Player, text: string, kind: NotifyKind?)
	Net.NotifyRemote:FireClient(player, text, kind or "info")
end

-- Tells everyone in the server except `except`.
function Net.NotifyOthers(except: Player, text: string, kind: NotifyKind?)
	for _, other in Players:GetPlayers() do
		if other ~= except then
			Net.NotifyRemote:FireClient(other, text, kind or "info")
		end
	end
end

-- Cues: "Collect", "BrewStart", "Stir", "PotionReady", "Discover", "Sale", "Upgrade",
-- "Cheered" (someone cheered your shop), "CheerSent" (you cheered someone's), "Daily" (gift claimed),
-- "Master" (brewed every potion), "Rebirth" (started over with a bonus).
function Net.Cue(player: Player, cue: string, data: { [string]: any }?)
	Net.CueRemote:FireClient(player, cue, data or {})
end

return Net
