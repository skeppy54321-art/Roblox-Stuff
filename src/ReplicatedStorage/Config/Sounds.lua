--!strict
-- Sounds (ModuleScript) — ReplicatedStorage.Config.Sounds
-- Every sound the game plays, by name. Clients play them; the server only names them.
--
-- `Id` is YOUR audio asset ("rbxassetid://123456"). Leave it "" until you pick one:
--   Studio > Toolbox > Audio, search the words in `Find`, copy the asset id.
-- While `Id` is "", the `Builtin` sound is used (these ship with every Roblox client,
-- so they always load). If both are "", the sound is skipped silently.

export type SoundDef = {
	Id: string,
	Builtin: string,
	Volume: number,
	Speed: number, -- playback speed; above 1 = higher pitch
	Find: string, -- what to search for in the Toolbox
}

local TICK = "rbxasset://sounds/volume_slider.ogg"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local BOOM = "rbxasset://sounds/impact_explosion_03.mp3"

local function sound(builtin: string, volume: number, speed: number, find: string): SoundDef
	return { Id = "", Builtin = builtin, Volume = volume, Speed = speed, Find = find }
end

local Sounds: { [string]: SoundDef } = {
	Click = sound(TICK, 0.45, 1.2, "ui click"),
	Open = sound(TICK, 0.4, 0.9, "ui pop open"),
	Error = sound(TICK, 0.5, 0.55, "error buzz"),
	Collect = sound(TICK, 0.5, 1.7, "bubble pop"),
	Plop = sound(SPLASH, 0.35, 1.5, "water plop"),
	Stir = sound(SPLASH, 0.25, 2.1, "water swirl"),
	Bubbling = sound("", 0.25, 1, "cauldron bubbling loop"),
	PotionReady = sound(TICK, 0.55, 2, "magic chime"),
	Discover = sound(TICK, 0.6, 2.4, "magic sparkle reveal"),
	Coins = sound(TICK, 0.6, 2.6, "coins cash register"),
	Upgrade = sound(SPLASH, 0.35, 0.8, "level up fanfare"),
	Poof = sound(BOOM, 0.12, 2.6, "cartoon poof"),
	Hop = sound(JUMP, 0.45, 1.3, "cartoon boing"),
	Ribbit = sound("", 0.6, 1, "frog ribbit"),
	Freeze = sound("", 0.5, 1, "ice freeze"),
	Whoosh = sound("", 0.4, 1, "magic whoosh"),
	Inflate = sound("", 0.5, 1, "balloon inflate"),
	Shrink = sound("", 0.5, 1, "cartoon shrink"),
	Music = sound("", 0.18, 1, "cozy fantasy village music"),
}

return Sounds
