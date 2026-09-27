--!strict
-- Popups (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Popups
-- Floating text in the world ("+1 Moonberry", "+10") that rises and fades.

local TweenService = game:GetService("TweenService")
local Ui = require(script.Parent:WaitForChild("Ui"))

local Popups = {}

local playerGui: PlayerGui

function Popups.Init(gui: PlayerGui)
	playerGui = gui
end

function Popups.Show(position: Vector3, text: string, color: Color3, big: boolean?)
	local anchor = Instance.new("Attachment")
	anchor.Name = "PopupAnchor"
	anchor.Parent = workspace.Terrain
	anchor.WorldPosition = position

	local size = if big then Vector2.new(260, 64) else Vector2.new(200, 44)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Popup"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(size.X, size.Y)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(40, 25, 20),
		Parent = billboard,
	}, if big then 48 else 30)
	billboard.Parent = playerGui

	Ui.pop(label, 0.4)
	local rise = TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 4, 0),
	})
	rise:Play()
	task.delay(0.7, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		billboard:Destroy()
		anchor:Destroy()
	end)
end

return Popups
