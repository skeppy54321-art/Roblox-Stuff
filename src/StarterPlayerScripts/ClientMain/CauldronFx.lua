--!strict
-- CauldronFx (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.CauldronFx
-- Your own cauldron: a progress bar with the potion's name while it brews, a bubbling
-- sound, and a splash of bubbles every time you stir.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local P = Config.Palette

local CauldronFx = {}

local bar: BillboardGui
local fill: Frame
local nameLabel: TextLabel
local watched: Model? = nil
local watchConnection: RBXScriptConnection? = nil
local lastEndTime = 0
local bubbling = false

local function brewInfo(cauldron: Model): (number, number, string)
	local endTime = cauldron:GetAttribute("BrewEndTime")
	local duration = cauldron:GetAttribute("BrewDuration")
	local recipe = cauldron:GetAttribute("BrewRecipe")
	return if typeof(endTime) == "number" then endTime else 0,
		if typeof(duration) == "number" then duration else 0,
		if typeof(recipe) == "string" then recipe else ""
end

function CauldronFx.Init(playerGui: PlayerGui)
	bar = Instance.new("BillboardGui")
	bar.Name = "BrewBar"
	bar.Size = UDim2.fromOffset(190, 54)
	bar.StudsOffset = Vector3.new(0, 4.8, 0)
	bar.AlwaysOnTop = true
	bar.LightInfluence = 0
	bar.ResetOnSpawn = false
	bar.Enabled = false
	nameLabel = Ui.label({
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = P.DarkWood,
		Parent = bar,
	}, 20)
	local back = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = P.PanelDark,
		Parent = bar,
	}, { Ui.round(), Ui.stroke(P.Gold, 2) })
	fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = P.Liquid,
		Parent = back,
	}, { Ui.round() })
	bar.Parent = playerGui

	RunService.RenderStepped:Connect(function()
		local cauldron = watched
		if not cauldron or not cauldron.Parent then
			bar.Enabled = false
			return
		end
		local endTime, duration, recipeId = brewInfo(cauldron)
		local now = workspace:GetServerTimeNow()
		local isBrewing = duration > 0 and endTime > now
		bar.Enabled = isBrewing
		if isBrewing then
			local recipe = Config.Recipes[recipeId]
			fill.Size = UDim2.fromScale(math.clamp(1 - (endTime - now) / duration, 0, 1), 1)
			if recipe then
				fill.BackgroundColor3 = recipe.Color
				nameLabel.Text = recipe.DisplayName
			end
		end
		if isBrewing ~= bubbling then
			bubbling = isBrewing
			local hitbox = cauldron:FindFirstChild("Hitbox")
			if isBrewing and hitbox and hitbox:IsA("BasePart") then
				Sfx.StartLoop("Cauldron", "Bubbling", hitbox)
			else
				Sfx.StopLoop("Cauldron")
			end
		end
	end)
end

-- Follow the local player's own cauldron (nil when they have no shop).
function CauldronFx.Watch(cauldron: Model?)
	if cauldron == watched then
		return
	end
	if watchConnection then
		watchConnection:Disconnect()
		watchConnection = nil
	end
	watched = cauldron
	local hitbox = if cauldron then cauldron:FindFirstChild("Hitbox") else nil
	bar.Adornee = (if hitbox and hitbox:IsA("BasePart") then hitbox else nil) :: any -- nil clears it
	if not cauldron then
		return
	end
	lastEndTime = brewInfo(cauldron)
	watchConnection = cauldron:GetAttributeChangedSignal("BrewEndTime"):Connect(function()
		local endTime = brewInfo(cauldron)
		-- the end time moved earlier while brewing = a stir: splash some bubbles
		if endTime > 0 and lastEndTime > 0 and endTime < lastEndTime then
			local bubbles = cauldron:FindFirstChild("Bubbles", true)
			if bubbles and bubbles:IsA("ParticleEmitter") then
				bubbles:Emit(16)
			end
		end
		lastEndTime = endTime
	end)
end

return CauldronFx
