--!strict
-- World (ModuleScript) — ReplicatedStorage.Config.World
-- Market layout and the golden-hour lighting look.

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

-- Where shop `index` (1..PlotCount) sits. Its -Z side (the counter) faces the plaza.
function World.GetPlotCFrame(index: number): CFrame
	local angle = World.PlotAngleOffset + (index - 1) * (2 * math.pi / World.PlotCount)
	local position =
		Vector3.new(math.sin(angle) * World.PlotRingRadius, World.GroundHeight, math.cos(angle) * World.PlotRingRadius)
	local center = Vector3.new(0, World.GroundHeight, 0)
	return CFrame.lookAt(position, center)
end

return World
