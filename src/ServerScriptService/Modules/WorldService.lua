--!strict
-- WorldService (ModuleScript) — ServerScriptService.Modules.WorldService
-- The golden-hour look: low warm sun, soft haze, sunset clouds, glowing neon.
-- Numbers live in Config.World.
--
-- Lighting.Technology can't be set by scripts. The place file sets it to Future
-- (default.project.json). In a hand-made place: Lighting > Technology > Future.

local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local W = Config.World

local WorldService = {}

-- Remove any existing instance of this class (the Baseplate template ships a few).
local function clear(parent: Instance, className: string)
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			child:Destroy()
		end
	end
end

function WorldService.Apply()
	local L = W.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.GeographicLatitude = L.GeographicLatitude
	Lighting.Brightness = L.Brightness
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.ColorShift_Top = L.ColorShiftTop
	Lighting.ColorShift_Bottom = L.ColorShiftBottom
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.ShadowSoftness = L.ShadowSoftness
	Lighting.GlobalShadows = true

	clear(Lighting, "Atmosphere")
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = W.Atmosphere.Density
	atmosphere.Offset = W.Atmosphere.Offset
	atmosphere.Color = W.Atmosphere.Color
	atmosphere.Decay = W.Atmosphere.Decay
	atmosphere.Glare = W.Atmosphere.Glare
	atmosphere.Haze = W.Atmosphere.Haze
	atmosphere.Parent = Lighting

	clear(Lighting, "Sky")
	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = W.Sky.SunAngularSize
	sky.MoonAngularSize = W.Sky.MoonAngularSize
	sky.StarCount = W.Sky.StarCount
	sky.Parent = Lighting

	clear(Lighting, "BloomEffect")
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = W.Bloom.Intensity
	bloom.Size = W.Bloom.Size
	bloom.Threshold = W.Bloom.Threshold
	bloom.Parent = Lighting

	clear(Lighting, "ColorCorrectionEffect")
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Brightness = W.ColorCorrection.Brightness
	grade.Contrast = W.ColorCorrection.Contrast
	grade.Saturation = W.ColorCorrection.Saturation
	grade.TintColor = W.ColorCorrection.TintColor
	grade.Parent = Lighting

	clear(Lighting, "SunRaysEffect")
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = W.SunRays.Intensity
	rays.Spread = W.SunRays.Spread
	rays.Parent = Lighting

	-- Blur and depth of field make small phone screens look muddy.
	clear(Lighting, "DepthOfFieldEffect")
	clear(Lighting, "BlurEffect")

	local terrain = workspace.Terrain
	clear(terrain, "Clouds")
	local clouds = Instance.new("Clouds")
	clouds.Cover = W.Clouds.Cover
	clouds.Density = W.Clouds.Density
	clouds.Color = W.Clouds.Color
	clouds.Parent = terrain
end

return WorldService
