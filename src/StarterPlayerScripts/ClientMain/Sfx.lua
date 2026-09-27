--!strict
-- Sfx (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Sfx
-- Plays the sounds named in Config.Sounds on this client only.
-- Asset ids are preloaded once; any that fail to load fall back to their built-in
-- sound. A sound with nothing to play is skipped silently.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Sfx = {}

local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DUCK_LEVEL = 0.35 -- music volume multiplier while a fanfare plays

local muted = false
local music: Sound? = nil
local loops: { [string]: Sound } = {}
local failed: { [string]: boolean } = {}
local duckUntil = 0

local function pickId(name: string): string
	local def = Config.Sounds[name]
	if not def then
		return ""
	end
	if def.Id ~= "" and not failed[def.Id] then
		return def.Id
	end
	return def.Builtin
end

local function soundFor(name: string): Sound?
	local def = Config.Sounds[name]
	local id = pickId(name)
	if not def or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Speed
	return sound
end

local function fadeOut(sound: Sound)
	if not sound.Parent then
		return
	end
	local tween = TweenService:Create(sound, FADE, { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- Turns the music down for a moment so a fanfare can be heard.
local function duck(seconds: number)
	local current = music
	if not current then
		return
	end
	duckUntil = math.max(duckUntil, os.clock() + seconds)
	TweenService:Create(current, FADE, { Volume = Config.Sounds.Music.Volume * DUCK_LEVEL }):Play()
	task.delay(seconds, function()
		if music == current and os.clock() >= duckUntil - 0.05 then
			TweenService:Create(current, FADE, { Volume = Config.Sounds.Music.Volume }):Play()
		end
	end)
end

local function playOnce(name: string, sound: Sound, parent: Instance)
	local def = Config.Sounds[name]
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	local limit = if def and def.MaxSeconds > 0 then def.MaxSeconds else 10
	task.delay(limit, fadeOut, sound)
	if def and def.Duck then
		duck(if def.MaxSeconds > 0 then def.MaxSeconds else 2)
	end
end

-- A 2D sound: same volume wherever you are (your own actions, UI).
function Sfx.Play(name: string, pitch: number?)
	if muted then
		return
	end
	local sound = soundFor(name)
	if sound then
		sound.PlaybackSpeed *= pitch or 1
		playOnce(name, sound, SoundService)
	end
end

-- A 3D sound coming from a part in the world (quieter the farther away you are).
function Sfx.PlayAt(name: string, part: BasePart, pitch: number?)
	if muted or not part.Parent then
		return
	end
	local sound = soundFor(name)
	if sound then
		sound.PlaybackSpeed *= pitch or 1
		sound.RollOffMaxDistance = 90
		sound.RollOffMinDistance = 8
		playOnce(name, sound, part)
	end
end

-- A looping 3D sound (e.g. bubbling). Call StopLoop with the same key to stop it.
function Sfx.StartLoop(key: string, name: string, part: BasePart)
	Sfx.StopLoop(key)
	local sound = soundFor(name)
	if not sound then
		return
	end
	sound.Looped = true
	sound.RollOffMaxDistance = 60
	sound.RollOffMinDistance = 6
	sound.Parent = part
	loops[key] = sound
	if not muted then
		sound:Play()
	end
end

function Sfx.StopLoop(key: string)
	local sound = loops[key]
	if sound then
		loops[key] = nil
		sound:Destroy()
	end
end

-- Background music, if Config.Sounds.Music has something to play.
function Sfx.StartMusic()
	if music then
		return
	end
	local sound = soundFor("Music")
	if sound then
		sound.Looped = true
		sound.Parent = SoundService
		music = sound
		if not muted then
			sound:Play()
		end
	end
end

local function stopMusic()
	if music then
		music:Destroy()
		music = nil
	end
end

-- Loads every asset id up front. Ids that fail (deleted, private, blocked) are
-- remembered so their built-in sound plays instead.
function Sfx.Preload()
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, def in Config.Sounds do
		if def.Id ~= "" and not seen[def.Id] then
			seen[def.Id] = true
			table.insert(ids, def.Id)
		end
	end
	if #ids == 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(ids, function(contentId: string, status: Enum.AssetFetchStatus)
				if status ~= Enum.AssetFetchStatus.Success then
					failed[contentId] = true
				end
			end)
		end)
		if not ok then
			warn("[Sfx] preload failed:", err)
			return
		end
		local musicId = Config.Sounds.Music.Id
		if music and musicId ~= "" and failed[musicId] then
			stopMusic() -- the music never loaded; fall back to its built-in (if any)
			Sfx.StartMusic()
		end
	end)
end

function Sfx.IsMuted(): boolean
	return muted
end

function Sfx.SetMuted(value: boolean)
	muted = value
	if music then
		if muted then
			music:Pause()
		else
			music:Resume()
		end
	end
	for _, sound in loops do
		if muted then
			sound:Pause()
		else
			sound:Resume()
		end
	end
end

return Sfx
