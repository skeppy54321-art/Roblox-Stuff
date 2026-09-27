-- Net (ModuleScript) — ServerScriptService.Modules.Net
-- Creates all RemoteEvents/RemoteFunctions and wraps sending to clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local function remote(className: string, name: string)
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = folder
	return inst
end

Net.StateUpdate = remote("RemoteEvent", "StateUpdate") :: RemoteEvent -- server -> client: full player state
Net.NotifyRemote = remote("RemoteEvent", "Notify") :: RemoteEvent -- server -> client: short message
Net.PlayEffect = remote("RemoteEvent", "PlayEffect") :: RemoteEvent -- server -> all: cosmetic effect
Net.RequestUpgrade = remote("RemoteEvent", "RequestUpgrade") :: RemoteEvent -- client -> server
Net.GetState = remote("RemoteFunction", "GetState") :: RemoteFunction -- client -> server on join

function Net.Notify(player: Player, text: string)
	Net.NotifyRemote:FireClient(player, text)
end

return Net
