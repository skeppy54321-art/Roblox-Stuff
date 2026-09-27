--!strict
-- Sounds (ModuleScript) — ReplicatedStorage.Config.Sounds
-- Every sound the game plays, by name. Clients play them; the server only names them.
--
-- `Id` is an audio asset ("rbxassetid://123456"). To use your own:
--   Studio > Toolbox > Audio, search the words in `Find`, right-click > Copy Asset ID.
-- If `Id` is "" (or fails to load), the `Builtin` sound is used instead: those ship
-- with every Roblox client, so they always work. If both are "", the sound is skipped.
--
-- The ids below come from Roblox's own tutorials on create.roblox.com/docs, which
-- use them as examples, so they're public and free to use in any experience:
--   CHIME     "simple chime" for collectables (Audio > In-game sounds tutorial)
--   JINGLE    "retro jingle" for a UI button (Audio > Add 2D audio tutorial)
--   CELEBRATE "cheerful, celebratory" button sound (Audio > Add 3D audio tutorial)
--   MUSIC     "upbeat" looping background track (Audio > Add 2D audio tutorial)
--   WATER     "waterfall ambience" loop (Audio > In-game sounds tutorial), quiet at the fountain

export type SoundDef = {
	Id: string,
	Builtin: string,
	Volume: number,
	Speed: number, -- playback speed; above 1 = higher pitch
	MaxSeconds: number, -- one-shot sounds fade out after this long (0 = play to the end)
	Duck: boolean, -- turn the music down while this plays
	Find: string, -- what to search for in the Toolbox
}

local CHIME = "rbxassetid://4110925712"
local JINGLE = "rbxassetid://3422389728"
local CELEBRATE = "rbxassetid://1846248593"
local MUSIC = "rbxassetid://1841461968"
local WATER = "rbxassetid://6564308795"

local TICK = "rbxasset://sounds/volume_slider.ogg"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local BOOM = "rbxasset://sounds/impact_explosion_03.mp3"

type Options = { Id: string?, MaxSeconds: number?, Duck: boolean? }

local function sound(builtin: string, volume: number, speed: number, find: string, options: Options?): SoundDef
	local o: Options = options or {}
	return {
		Id = o.Id or "",
		Builtin = builtin,
		Volume = volume,
		Speed = speed,
		MaxSeconds = o.MaxSeconds or 0,
		Duck = o.Duck == true,
		Find = find,
	}
end

local Sounds: { [string]: SoundDef } = {
	Click = sound(TICK, 0.45, 1.2, "ui click"),
	Open = sound(TICK, 0.4, 0.9, "ui pop open"),
	Error = sound(TICK, 0.5, 0.55, "error buzz"),
	Collect = sound(TICK, 0.5, 1.7, "bubble pop"),
	Plop = sound(SPLASH, 0.35, 1.5, "water plop"),
	Stir = sound(SPLASH, 0.25, 2.1, "water swirl"),
	Bubbling = sound("", 0.25, 1, "cauldron bubbling loop"),
	Blub = sound(SPLASH, 0.12, 2.8, "single bubble blub"), -- played now and then while brewing if Bubbling has no id
	PotionReady = sound(TICK, 0.6, 1, "magic chime", { Id = CHIME, MaxSeconds = 2.5 }),
	Discover = sound(TICK, 0.5, 1, "magic sparkle reveal", { Id = CELEBRATE, MaxSeconds = 4, Duck = true }),
	Coins = sound(TICK, 0.45, 1.5, "coins cash register", { Id = CHIME, MaxSeconds = 1.5 }),
	Upgrade = sound(SPLASH, 0.45, 1, "level up fanfare", { Id = JINGLE, MaxSeconds = 3.5, Duck = true }),
	Cheer = sound(TICK, 0.55, 1.25, "cheer sparkle", { Id = CHIME, MaxSeconds = 2 }),
	News = sound(TICK, 0.3, 1.9, "soft notification"),
	Bell = sound(TICK, 0.55, 3.2, "shop bell ding"), -- a customer reached your counter
	Poof = sound(BOOM, 0.12, 2.6, "cartoon poof"),
	Hop = sound(JUMP, 0.45, 1.3, "cartoon boing"),
	Ribbit = sound("", 0.6, 1, "frog ribbit"),
	Freeze = sound("", 0.5, 1, "ice freeze"),
	Whoosh = sound("", 0.4, 1, "magic whoosh"),
	Inflate = sound("", 0.5, 1, "balloon inflate"),
	Shrink = sound("", 0.5, 1, "cartoon shrink"),
	Fire = sound(BOOM, 0.16, 0.55, "dragon fire breath"),
	Pop = sound(TICK, 0.55, 2.3, "bubble pop"),
	Rocket = sound(BOOM, 0.22, 0.8, "rocket launch"),
	Disco = sound(TICK, 0.5, 1, "disco dance music", { Id = CELEBRATE, MaxSeconds = 3.2 }),
	Boo = sound("", 0.5, 1, "ghost boo"),
	Twinkle = sound(TICK, 0.5, 1.6, "magic twinkle stars", { Id = CHIME, MaxSeconds = 2 }),
	Music = sound("", 0.2, 1, "cozy fantasy village music", { Id = MUSIC }),
	Fountain = sound("", 0.3, 1, "fountain water loop", { Id = WATER }), -- 3D, at the plaza fountain
}

return Sounds
