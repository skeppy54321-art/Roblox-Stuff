--!strict
-- PromptUi (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.PromptUi
-- Draws the game's proximity prompts ("[E] Collect Moonberry") in the game's own style
-- instead of Roblox's default grey box. Works with keyboard, gamepad and touch
-- (tap or click the prompt itself).
--
-- Safety: prompts only switch to the custom style through PromptUi.Adopt, which runs
-- after this module has loaded. If it ever fails, prompts keep the default style.

local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

local PromptUi = {}

PromptUi.OnTriggered = nil :: ((ProximityPrompt) -> ())?

local playerGui: PlayerGui
local shown: { [ProximityPrompt]: () -> () } = {} -- prompt -> cleanup

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	if text == "" then
		text = prompt.KeyboardKeyCode.Name
	end
	return string.upper(text)
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): () -> ()
	local adornee = prompt.Parent
	local connections: { RBXScriptConnection } = {}

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Prompt_" .. prompt.Name
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(250, 76)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.ResetOnSpawn = false
	if adornee and (adornee:IsA("BasePart") or adornee:IsA("Attachment")) then
		billboard.Adornee = adornee
	end

	local button = Ui.new("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = billboard,
	})
	local card = Ui.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -8),
		BackgroundColor3 = P.PanelDark,
		BackgroundTransparency = 0.05,
		Parent = button,
	}, { Ui.corner(18), Ui.stroke(P.Gold, 3) })
	local scale = Ui.scaler(card)

	local key = Ui.new("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = P.Gold,
		Parent = card,
	}, { Ui.corner(14), Ui.stroke(P.PanelLight, 2) })
	local keyLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = P.TextDark,
		Text = keyText(prompt, inputType),
		Parent = key,
	}, 26)
	local action = Ui.label({
		Position = UDim2.fromOffset(70, 8),
		Size = UDim2.new(1, -80, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = prompt.ActionText,
		Parent = card,
	}, 26)
	local object = Ui.label({
		Position = UDim2.fromOffset(70, 38),
		Size = UDim2.new(1, -80, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.PanelLight,
		Text = prompt.ObjectText,
		Parent = card,
	}, 18)
	local holdBar = Ui.new("Frame", {
		Name = "HoldBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 70, 1, -6),
		Size = UDim2.fromOffset(0, 5),
		BackgroundColor3 = P.Gold,
		Visible = prompt.HoldDuration > 0,
		Parent = card,
	}, { Ui.round() })

	-- pop in
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	table.insert(
		connections,
		prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
			action.Text = prompt.ActionText
		end)
	)
	table.insert(
		connections,
		prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
			object.Text = prompt.ObjectText
		end)
	)
	table.insert(
		connections,
		prompt.Triggered:Connect(function()
			scale.Scale = 1.15
			TweenService
				:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			if PromptUi.OnTriggered then
				PromptUi.OnTriggered(prompt)
			end
		end)
	)
	local holdTween: Tween? = nil
	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			if prompt.HoldDuration > 0 then
				holdBar.Size = UDim2.fromOffset(0, 5)
				local tween =
					TweenService:Create(holdBar, TweenInfo.new(prompt.HoldDuration), { Size = UDim2.new(1, -80, 0, 5) })
				holdTween = tween
				tween:Play()
			end
		end)
	)
	table.insert(
		connections,
		prompt.PromptButtonHoldEnded:Connect(function()
			if holdTween then
				holdTween:Cancel()
				holdTween = nil
			end
			holdBar.Size = UDim2.fromOffset(0, 5)
		end)
	)

	-- tap / click the prompt itself
	local holding = false
	table.insert(
		connections,
		button.InputBegan:Connect(function(input: InputObject)
			if isPointer(input) and input.UserInputState ~= Enum.UserInputState.Change and not holding then
				holding = true
				key.BackgroundColor3 = P.PanelLight
				prompt:InputHoldBegin()
			end
		end)
	)
	table.insert(
		connections,
		button.InputEnded:Connect(function(input: InputObject)
			if holding and isPointer(input) then
				holding = false
				key.BackgroundColor3 = P.Gold
				prompt:InputHoldEnd()
			end
		end)
	)

	billboard.Parent = playerGui
	keyLabel.Text = keyText(prompt, inputType)

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if holding then
			holding = false
			prompt:InputHoldEnd()
		end
		billboard:Destroy()
	end
end

local function hide(prompt: ProximityPrompt)
	local cleanup = shown[prompt]
	if cleanup then
		shown[prompt] = nil
		cleanup()
	end
end

function PromptUi.Init(gui: PlayerGui)
	playerGui = gui
	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
			if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
				return
			end
			hide(prompt)
			shown[prompt] = show(prompt, inputType)
		end
	)
	ProximityPromptService.PromptHidden:Connect(hide)
end

-- Switch a prompt to the custom look (call for every prompt the game owns).
function PromptUi.Adopt(prompt: ProximityPrompt)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Destroying:Connect(function()
		hide(prompt)
	end)
end

return PromptUi
