--!strict
-- DayCycle (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.DayCycle
-- The market's evening: golden hour slowly turns into a pink sunset and a purple dusk
-- (the first stars come out, lanterns glow brighter, the butterflies fly off and more
-- fireflies come out over the plaza), then the sun comes back. The looks and timing live
-- in Config.World.DayCycle.
--
-- Client only: the server's Lighting (WorldService) is the golden-hour look, and this
-- changes it locally, so it costs no network. Every client follows the server clock, so
-- everyone sees the same sky. Updates 5 times a second; the sky moves slowly enough.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ambience = require(script.Parent:WaitForChild("Ambience"))
local Butterflies = require(script.Parent:WaitForChild("Butterflies"))

local CYCLE = Config.World.DayCycle
local UPDATE_EVERY = 0.2 -- seconds

type SkyLook = typeof(CYCLE.Keys[1].Look)

local DayCycle = {}

-- The clock the cycle follows (tests replace it).
DayCycle.Now = function(): number
	return workspace:GetServerTimeNow()
end

local fireflies: ParticleEmitter? = nil -- the plaza's (MarketBuilder)
local fireflyRate = 0 -- its normal rate

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function blend(a: SkyLook, b: SkyLook, t: number): SkyLook
	local function n(x: number, y: number): number
		return x + (y - x) * t
	end
	return {
		ClockTime = n(a.ClockTime, b.ClockTime),
		Brightness = n(a.Brightness, b.Brightness),
		Exposure = n(a.Exposure, b.Exposure),
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, t),
		AtmosphereColor = a.AtmosphereColor:Lerp(b.AtmosphereColor, t),
		AtmosphereDecay = a.AtmosphereDecay:Lerp(b.AtmosphereDecay, t),
		Haze = n(a.Haze, b.Haze),
		Glare = n(a.Glare, b.Glare),
		CloudColor = a.CloudColor:Lerp(b.CloudColor, t),
		Tint = a.Tint:Lerp(b.Tint, t),
		Lanterns = n(a.Lanterns, b.Lanterns),
		Fireflies = n(a.Fireflies, b.Fireflies),
		Butterflies = n(a.Butterflies, b.Butterflies),
	}
end

-- The look at `phase` (0 to 1 through the cycle).
function DayCycle.LookAt(phase: number): SkyLook
	local keys = CYCLE.Keys
	local p = phase % 1
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if p <= b.At then
			local span = b.At - a.At
			local t = if span > 0 then math.clamp((p - a.At) / span, 0, 1) else 1
			return blend(a.Look, b.Look, smooth(t))
		end
	end
	return keys[#keys].Look
end

-- How far through the cycle the market is right now (0 to 1).
function DayCycle.Phase(): number
	return (DayCycle.Now() / CYCLE.Seconds) % 1
end

-- Shows the look at `phase` right away.
function DayCycle.Apply(phase: number)
	local look = DayCycle.LookAt(phase)
	Lighting.ClockTime = look.ClockTime
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.Exposure
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = look.AtmosphereColor
		atmosphere.Decay = look.AtmosphereDecay
		atmosphere.Haze = look.Haze
		atmosphere.Glare = look.Glare
	end
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grade then
		grade.TintColor = look.Tint
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Color = look.CloudColor
	end
	Ambience.LightScale = look.Lanterns
	Butterflies.Amount = look.Butterflies
	local emitter = fireflies
	if emitter then
		emitter.Rate = fireflyRate * look.Fireflies
	end
end

function DayCycle.Init(market: Instance)
	if not CYCLE.Enabled then
		return
	end
	local town = market:WaitForChild("Town", 10)
	local area = town and town:FindFirstChild("Fireflies")
	local emitter = area and area:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		fireflies = emitter
		fireflyRate = emitter.Rate
	end
	DayCycle.Apply(DayCycle.Phase())
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < UPDATE_EVERY then
			return
		end
		elapsed = 0
		DayCycle.Apply(DayCycle.Phase())
	end)
end

return DayCycle
