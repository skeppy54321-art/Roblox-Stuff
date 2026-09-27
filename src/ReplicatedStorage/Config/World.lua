--!strict
-- World (ModuleScript) — ReplicatedStorage.Config.World
-- Market layout, the golden-hour lighting look and the evening cycle.

local rgb = Color3.fromRGB

local World = {}

-- Shops sit in a ring around the plaza, each facing the fountain.
-- Set the experience's Max Players to PlotCount (Game Settings > Places) so everyone gets a shop.
World.PlotCount = 6
World.Townsfolk = 6 -- villagers strolling around the plaza (visual only)
World.PlotSize = 30 -- square shop floor, in studs
World.PlotRingRadius = 60 -- plaza center to each shop's center
World.PlotAngleOffset = 0 -- turns the whole ring (radians)

World.PlazaRadius = 30
World.GroundSize = 560
World.GroundHeight = 0 -- top of the ground

-- Golden hour: warm low sun, soft haze, glowing lanterns and potions.
World.Lighting = {
	ClockTime = 17.3,
	GeographicLatitude = 25,
	Brightness = 2.6,
	ExposureCompensation = 0.1,
	Ambient = rgb(92, 78, 96),
	OutdoorAmbient = rgb(165, 142, 150),
	ColorShiftTop = rgb(255, 212, 168),
	ColorShiftBottom = rgb(40, 20, 50),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.4,
	ShadowSoftness = 0.3,
}

World.Atmosphere = {
	Density = 0.3,
	Offset = 0.22,
	Color = rgb(255, 208, 172),
	Decay = rgb(170, 118, 150),
	Glare = 0.35,
	Haze = 1.5,
}

World.Sky = {
	SunAngularSize = 18,
	MoonAngularSize = 9,
	StarCount = 2500,
}

World.Bloom = { Intensity = 0.7, Size = 28, Threshold = 1.35 }
World.ColorCorrection = { Brightness = 0.02, Contrast = 0.08, Saturation = 0.14, TintColor = rgb(255, 246, 234) }
World.SunRays = { Intensity = 0.05, Spread = 0.7 }
World.Clouds = { Cover = 0.5, Density = 0.55, Color = rgb(255, 230, 215) }

-- How the sky looks at one moment of the evening cycle (below).
export type SkyLook = {
	ClockTime: number,
	Brightness: number,
	Exposure: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	Haze: number,
	Glare: number,
	CloudColor: Color3,
	Tint: Color3,
	Lanterns: number, -- lantern, fire and fountain lights, times their normal brightness
	Fireflies: number, -- fireflies over the plaza, times the normal number
	Butterflies: number, -- share of the butterflies out (they fly off at dusk)
}

-- The golden-hour look above, as a SkyLook.
local golden: SkyLook = {
	ClockTime = World.Lighting.ClockTime,
	Brightness = World.Lighting.Brightness,
	Exposure = World.Lighting.ExposureCompensation,
	Ambient = World.Lighting.Ambient,
	OutdoorAmbient = World.Lighting.OutdoorAmbient,
	AtmosphereColor = World.Atmosphere.Color,
	AtmosphereDecay = World.Atmosphere.Decay,
	Haze = World.Atmosphere.Haze,
	Glare = World.Atmosphere.Glare,
	CloudColor = World.Clouds.Color,
	Tint = World.ColorCorrection.TintColor,
	Lanterns = 1,
	Fireflies = 1,
	Butterflies = 1,
}

-- The sun touches the rooftops: deep orange haze, pink clouds.
local sunset: SkyLook = {
	ClockTime = 17.95,
	Brightness = 2.1,
	Exposure = 0.12,
	Ambient = rgb(96, 76, 104),
	OutdoorAmbient = rgb(160, 132, 158),
	AtmosphereColor = rgb(255, 176, 150),
	AtmosphereDecay = rgb(160, 96, 150),
	Haze = 1.8,
	Glare = 0.45,
	CloudColor = rgb(255, 196, 186),
	Tint = rgb(255, 238, 232),
	Lanterns = 1.3,
	Fireflies = 1.5,
	Butterflies = 0.5,
}

-- Just after sunset: a purple sky with the first stars, lanterns and potions glowing.
-- Kept bright enough to play (the outdoor ambient light stays high).
local dusk: SkyLook = {
	ClockTime = 18.5,
	Brightness = 1.4,
	Exposure = 0.25,
	Ambient = rgb(104, 90, 132),
	OutdoorAmbient = rgb(136, 124, 178),
	AtmosphereColor = rgb(206, 158, 210),
	AtmosphereDecay = rgb(104, 78, 158),
	Haze = 2,
	Glare = 0.1,
	CloudColor = rgb(226, 178, 222),
	Tint = rgb(244, 236, 255),
	Lanterns = 1.8,
	Fireflies = 3,
	Butterflies = 0,
}

-- The evening cycle (client only: ClientMain.DayCycle). The market spends most of its time
-- in golden hour, then drifts through the sunset into dusk and back again. Every player
-- sees the same sky (it follows the server clock). `At` is the moment in the cycle (0 to
-- 1); between two keys the look blends smoothly. Enabled = false keeps golden hour.
World.DayCycle = {
	Enabled = true,
	Seconds = 480, -- one whole cycle
	Keys = {
		{ At = 0, Look = golden },
		{ At = 0.45, Look = golden },
		{ At = 0.56, Look = sunset },
		{ At = 0.64, Look = dusk },
		{ At = 0.86, Look = dusk },
		{ At = 1, Look = golden },
	},
}

-- Where shop `index` (1..PlotCount) sits. Its -Z side (the counter) faces the plaza.
function World.GetPlotCFrame(index: number): CFrame
	local angle = World.PlotAngleOffset + (index - 1) * (2 * math.pi / World.PlotCount)
	local position =
		Vector3.new(math.sin(angle) * World.PlotRingRadius, World.GroundHeight, math.cos(angle) * World.PlotRingRadius)
	local center = Vector3.new(0, World.GroundHeight, 0)
	return CFrame.lookAt(position, center)
end

return World
