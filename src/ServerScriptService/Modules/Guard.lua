-- Guard (ModuleScript) — ServerScriptService.Modules.Guard
-- Server-side checks every action runs before changing anything:
-- ownership, distance, and per-action cooldowns (rate limiting).

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local Guard = {}

local lastUse: { [Player]: { [string]: number } } = {}

-- Returns true (and records the time) if enough time has passed since this action.
function Guard.Cooldown(player: Player, action: string, seconds: number): boolean
	local now = os.clock()
	local times = lastUse[player]
	if not times then
		times = {}
		lastUse[player] = times
	end
	local last = times[action]
	if last and now - last < seconds then
		return false
	end
	times[action] = now
	return true
end

-- Is the player's character close enough to this part?
function Guard.Near(player: Player, part: BasePart?, maxDistance: number?): boolean
	if not part then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - part.Position).Magnitude <= (maxDistance or Config.InteractDistance)
end

-- Does this player own this plot?
function Guard.Owns(player: Player, plot: Instance?): boolean
	return plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
end

function Guard.Clear(player: Player)
	lastUse[player] = nil
end

return Guard
