--!strict
-- Ui (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Ui
-- Small helpers every UI module uses, so all panels look like one set:
-- rounded parchment panels, chunky buttons that squish when pressed, potion icons.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local P = Config.Palette

local Ui = {}

Ui.FONT = Enum.Font.FredokaOne

-- Design size: layouts are drawn for this screen and scaled to fit the real one.
local DESIGN_WIDTH, DESIGN_HEIGHT = 1000, 560

-- Instance.new + properties + children. Parent is set last (cheaper).
function Ui.new(className: string, props: { [string]: any }, children: { any }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Ui.corner(radius: number): Instance
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Ui.round(): Instance
	return Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end

function Ui.stroke(color: Color3, thickness: number, transparency: number?): Instance
	return Ui.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(x: number, y: number?): Instance
	return Ui.new("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
	})
end

-- Scaled text that never grows past `maxSize`.
function Ui.label(props: { [string]: any }, maxSize: number?): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = Ui.FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or P.TextLight
	return Ui.new(
		"TextLabel",
		props,
		{ Ui.new("UITextSizeConstraint", { MaxTextSize = maxSize or 28, MinTextSize = 8 }) }
	)
end

-- Gives `gui` a UIScale (reused if it has one) for pop/press animations.
function Ui.scaler(gui: GuiObject): UIScale
	local existing = gui:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	return Ui.new("UIScale", { Scale = 1, Parent = gui })
end

-- Quick "boing": grows a little and settles back.
function Ui.pop(gui: GuiObject, amount: number?)
	local scale = Ui.scaler(gui)
	scale.Scale = 1 + (amount or 0.15)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- A chunky button: colored face over a darker "shadow" edge; squishes when pressed.
-- Returns the holder frame and the clickable face.
function Ui.button(props: {
	Name: string,
	Text: string,
	Color: Color3,
	Shade: Color3,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Parent: Instance?,
}): (Frame, TextButton)
	local holder = Ui.new("Frame", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Shade,
		Parent = props.Parent,
	}, { Ui.corner(14) })
	local face = Ui.new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = props.Color,
		AutoButtonColor = false,
		Font = Ui.FONT,
		Text = props.Text,
		TextColor3 = P.TextLight,
		TextScaled = true,
		TextStrokeTransparency = 0.6,
		Parent = holder,
	}, {
		Ui.corner(14),
		Ui.padding(10, 6),
		Ui.new("UITextSizeConstraint", { MaxTextSize = props.TextSize or 24, MinTextSize = 8 }),
	})
	local scale = Ui.scaler(holder)
	local function press(down: boolean)
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = if down then 0.93 else 1 }):Play()
	end
	face.MouseButton1Down:Connect(function()
		press(true)
	end)
	face.MouseButton1Up:Connect(function()
		press(false)
	end)
	face.MouseLeave:Connect(function()
		press(false)
	end)
	return holder, face
end

-- Recolors a button made by Ui.button (e.g. affordable = green, not = grey).
function Ui.setButtonColor(holder: Frame, color: Color3, shade: Color3)
	holder.BackgroundColor3 = shade
	local face = holder:FindFirstChild("Face")
	if face and face:IsA("GuiObject") then
		face.BackgroundColor3 = color
	end
end

-- A round colored dot (ingredient icon).
function Ui.dot(color: Color3, size: number): Frame
	return Ui.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
	}, { Ui.round(), Ui.stroke(P.TextDark, 2, 0.3) })
end

-- A little potion flask icon: round body, neck and cork. `size` = body diameter.
function Ui.bottle(color: Color3, size: number): Frame
	local holder = Ui.new("Frame", {
		Name = "Bottle",
		Size = UDim2.fromOffset(size, math.floor(size * 1.45)),
		BackgroundTransparency = 1,
	})
	Ui.new("Frame", {
		Name = "Neck",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, math.floor(size * 0.18)),
		Size = UDim2.fromOffset(math.floor(size * 0.38), math.floor(size * 0.4)),
		BackgroundColor3 = color,
		Parent = holder,
	}, { Ui.stroke(P.TextDark, 2, 0.2) })
	Ui.new("Frame", {
		Name = "Cork",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(math.floor(size * 0.46), math.floor(size * 0.22)),
		BackgroundColor3 = P.LightWood,
		ZIndex = 2,
		Parent = holder,
	}, { Ui.corner(3), Ui.stroke(P.TextDark, 2, 0.2) })
	Ui.new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = 2,
		Parent = holder,
	}, {
		Ui.round(),
		Ui.stroke(P.TextDark, 2, 0.2),
		Ui.new("Frame", { -- shine
			Position = UDim2.fromScale(0.2, 0.18),
			Size = UDim2.fromScale(0.22, 0.22),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			ZIndex = 3,
		}, { Ui.round() }),
	})
	return holder
end

-- A gold coin icon.
function Ui.coin(size: number): Frame
	return Ui.new("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = P.Gold,
	}, {
		Ui.round(),
		Ui.stroke(Color3.fromRGB(190, 130, 30), 2),
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.58, 0.58),
			BackgroundColor3 = Color3.fromRGB(255, 225, 120),
		}, { Ui.round() }),
	})
end

-- A full-screen container whose contents are scaled to fit the screen (phones get
-- smaller UI, big monitors a bit bigger). Returns the container.
function Ui.scaledRoot(screenGui: ScreenGui): Frame
	local root = Ui.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local scale = Ui.new("UIScale", { Scale = 1, Parent = root })
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local s = math.clamp(math.min(viewport.X / DESIGN_WIDTH, viewport.Y / DESIGN_HEIGHT), 0.62, 1.3)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCamera = workspace.CurrentCamera
		if newCamera then
			newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end)
	update()
	return root
end

-- A centered modal panel with a title and a close button. Returns (panel, body, closeButton).
function Ui.panel(
	parent: Instance,
	name: string,
	title: string,
	size: Vector2,
	accent: Color3
): (Frame, Frame, TextButton)
	local panel = Ui.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromScale(0.94, 0.8),
		BackgroundColor3 = P.PanelLight,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	}, {
		Ui.corner(20),
		Ui.stroke(P.DarkWood, 4),
		Ui.new("UISizeConstraint", { MaxSize = size }),
	})
	Ui.new("Frame", { -- title ribbon
		Name = "Ribbon",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = accent,
		ZIndex = 10,
		Parent = panel,
	}, { Ui.corner(20) })
	Ui.new("Frame", { -- squares off the ribbon's bottom corners
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = panel,
	})
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -90, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		Text = title,
		ZIndex = 11,
		Parent = panel,
	}, 34)
	local _, close = Ui.button({
		Name = "Close",
		Text = "X",
		Color = P.Danger,
		Shade = Color3.fromRGB(170, 50, 60),
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -10, 0, 5),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 26,
		Parent = panel,
	})
	local body = Ui.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = panel,
	})
	return panel, body, close
end

return Ui
