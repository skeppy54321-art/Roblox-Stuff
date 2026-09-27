--!strict
-- GoalMarker (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.GoalMarker
-- A bouncing gold arrow over the next thing to do ("Collect!", "Brew!", "Sell!").
-- Shown during the first few sales so new players learn the loop by doing it.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

local GoalMarker = {}

local billboard: BillboardGui
local label: TextLabel
local target: BasePart? = nil

local function bar(parent: Instance, rotation: number, x: number)
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, 56),
		Size = UDim2.fromOffset(14, 46),
		Rotation = rotation,
		BackgroundColor3 = P.Gold,
		Parent = parent,
	}, { Ui.round(), Ui.stroke(P.DarkWood, 3) })
end

function GoalMarker.Init(playerGui: PlayerGui)
	billboard = Instance.new("BillboardGui")
	billboard.Name = "GoalMarker"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(120, 110)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.ResetOnSpawn = false
	billboard.Enabled = false

	label = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(120, 30),
		TextColor3 = P.Gold,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = P.DarkWood,
		Text = "",
		Parent = billboard,
	}, 26)
	-- a "V" chevron made of two bars
	local arrow = Ui.new("Frame", {
		Name = "Arrow",
		Position = UDim2.fromOffset(20, 30),
		Size = UDim2.fromOffset(80, 80),
		BackgroundTransparency = 1,
		Parent = billboard,
	})
	bar(arrow, -45, 26)
	bar(arrow, 45, 54)
	billboard.Parent = playerGui

	RunService.RenderStepped:Connect(function()
		if billboard.Enabled then
			billboard.StudsOffset = Vector3.new(0, 4 + math.abs(math.sin(os.clock() * 4)) * 0.8, 0)
		end
	end)
end

-- Point at `part` with a short label, or hide (nil).
function GoalMarker.Set(part: BasePart?, text: string?)
	if part and part ~= target then
		target = part
		billboard.Adornee = part
	end
	billboard.Enabled = part ~= nil and part.Parent ~= nil
	label.Text = text or ""
end

return GoalMarker
