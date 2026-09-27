--!strict
-- Sfx (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Sfx
-- Plays the sounds named in Config.Sounds on this client only.
-- A sound with no asset id and no built-in fallback is skipped silently.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Sfx = {}

local muted = false
local music: Sound? = nil
local loops: { [string]: Sound } = {}

local function soundFor(name: string): Sound?
	local def = Config.Sounds[name]
	if not def then
		return nil
	end
	local id = if def.Id ~= "" then def.Id else def.Builtin
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Speed
	return sound
end

local function playOnce(sound: Sound, parent: Instance)
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- A 2D sound: same volume wherever you are (your own actions, UI).
function Sfx.Play(name: string, pitch: number?)
	if muted then
		return
	end
	local sound = soundFor(name)
	if sound then
		sound.PlaybackSpeed *= pitch or 1
		playOnce(sound, SoundService)
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
		playOnce(sound, part)
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

-- Background music, if Config.Sounds.Music has an asset id.
function Sfx.StartMusic()
	if music or Config.Sounds.Music.Id == "" then
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
