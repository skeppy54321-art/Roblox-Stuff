--!strict
-- Kit (ModuleScript) — ServerScriptService.Modules.Kit
-- Small helpers the builders use to make parts, lights and prompts.
-- Everything is anchored. Decoration never collides, is never touched or queried,
-- so it costs almost nothing for physics.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local Kit = {}

export type Props = { [string]: any }

-- Turns a cylinder (whose length runs along X) so it stands up along Y.
Kit.UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function apply(inst: Instance, props: Props?)
	if props then
		for key, value in props do
			(inst :: any)[key] = value
		end
	end
end

-- A solid, anchored part. Players can stand on it and bump into it.
function Kit.Part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: Props?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	apply(p, props)
	p.Parent = parent
	return p
end

-- Pure decoration: no collisions, no queries, no touch.
function Kit.Decor(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: Props?
): Part
	local p = Kit.Part(parent, name, size, cf, color, material, props)
	p.CanCollide = false
	p.CanQuery = false
	return p
end

-- Ball of `diameter` (decoration unless props say otherwise).
function Kit.Ball(
	parent: Instance,
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	props: Props?
): Part
	local p = Kit.Decor(parent, name, Vector3.one * diameter, CFrame.new(position), color, material)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * diameter -- set again: changing Shape can resize the part
	apply(p, props)
	return p
end

-- Upright cylinder centered on `cf` (height along Y). Decoration unless props say otherwise.
function Kit.Cylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: Props?
): Part
	local p = Kit.Decor(parent, name, Vector3.new(height, diameter, diameter), cf * Kit.UPRIGHT, color, material)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	apply(p, props)
	return p
end

-- Cylinder lying along the line from `a` to `b` (rods, ropes, logs).
function Kit.Rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	props: Props?
): Part
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	-- lookAt points -Z along the rod; turn it so the cylinder's X axis runs along the rod.
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = Kit.Decor(parent, name, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	apply(p, props)
	return p
end

function Kit.Wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: Props?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	apply(p, props)
	p.Parent = parent
	return p
end

-- Invisible box that holds a ProximityPrompt (and is what the server measures distance to).
function Kit.Hitbox(parent: Instance, size: Vector3, cf: CFrame, name: string?): Part
	local p = Kit.Part(parent, name or "Hitbox", size, cf, Color3.new(1, 1, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	return p
end

function Kit.Prompt(parent: Instance, name: string, actionText: string, objectText: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = actionText
	pp.ObjectText = objectText
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.Tuning.PromptDistance
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

function Kit.Light(part: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

function Kit.Model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

function Kit.Folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Gentle sparkles around a part (cheap: low rate, short life).
function Kit.Sparkles(part: BasePart, color: Color3, rate: number, name: string?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name or "Sparkles"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.1)
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = rate
	e.Parent = part
	return e
end

-- A billboard sign label, facing out of `face` of `part`.
function Kit.SurfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	pixelsPerStud: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return label
end

-- A little hanging lantern: metal cap, glowing glass, a warm light. `top` is where it hangs from.
function Kit.Lantern(parent: Instance, top: Vector3, scale: number?, lightRange: number?): Model
	local s = scale or 1
	local lantern = Kit.Model(parent, "Lantern")
	local P = Config.Palette
	local up = CFrame.new(top)
	Kit.Cylinder(lantern, "Hook", 0.5 * s, 0.12 * s, up * CFrame.new(0, -0.25 * s, 0), P.Metal, Enum.Material.Metal)
	Kit.Cylinder(lantern, "Cap", 0.3 * s, 0.9 * s, up * CFrame.new(0, -0.6 * s, 0), P.Metal, Enum.Material.Metal)
	local glass = Kit.Decor(
		lantern,
		"Glass",
		Vector3.new(0.7, 0.9, 0.7) * s,
		up * CFrame.new(0, -1.2 * s, 0),
		P.Lantern,
		Enum.Material.Neon,
		{ CastShadow = false }
	)
	Kit.Cylinder(lantern, "Base", 0.25 * s, 0.9 * s, up * CFrame.new(0, -1.75 * s, 0), P.Metal, Enum.Material.Metal)
	Kit.Light(glass, P.Lantern, lightRange or 14, 1.4)
	return lantern
end

-- Picks a slightly different shade of `color` so repeated props don't look copy-pasted.
function Kit.Vary(color: Color3, rng: Random, amount: number?): Color3
	local h, s, v = color:ToHSV()
	local a = amount or 0.06
	return Color3.fromHSV(
		(h + rng:NextNumber(-a, a) * 0.3) % 1,
		math.clamp(s + rng:NextNumber(-a, a), 0, 1),
		math.clamp(v + rng:NextNumber(-a, a), 0, 1)
	)
end

return Kit
