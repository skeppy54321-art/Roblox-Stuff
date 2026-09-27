-- Hud (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Hud
-- Builds the on-screen UI in code. Big buttons, few panels, works on phones.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local P = Config.Palette
local FONT = Enum.Font.FredokaOne

local Hud = {}
Hud.__index = Hud

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
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

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function textLabel(props: { [string]: any }, maxSize: number?): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or P.TextLight
	return new("TextLabel", props, { new("UITextSizeConstraint", { MaxTextSize = maxSize or 28 }) })
end

local function dot(color: Color3, size: number): Frame
	return new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
	}, { corner(size // 2) })
end

function Hud.new(playerGui: PlayerGui)
	local self = setmetatable({}, Hud)
	self.onUpgrade = nil :: ((string) -> ())?
	self.state = nil
	self.toastToken = 0

	local gui = new("ScreenGui", {
		Name = "PotionHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = playerGui,
	})
	self.gui = gui

	-- Coins (top center)
	local coinScale = new("UIScale", { Scale = 1 })
	local coins = new("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = P.PanelDark,
		Parent = gui,
	}, {
		corner(23),
		coinScale,
		new("UIStroke", { Color = P.Gold, Thickness = 2 }),
	})
	local coinDot = dot(P.Gold, 26)
	coinDot.Position = UDim2.new(0, 12, 0.5, -13)
	coinDot.Parent = coins
	self.coinText = textLabel({
		Position = UDim2.new(0, 46, 0, 6),
		Size = UDim2.new(1, -58, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = coins,
	}, 30)
	self.coinScale = coinScale

	-- Goal banner (under coins)
	local goal = new("Frame", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.new(0.92, 0, 0, 44),
		BackgroundColor3 = P.PanelLight,
		Parent = gui,
	}, {
		corner(12),
		new("UISizeConstraint", { MaxSize = Vector2.new(480, 44) }),
	})
	self.goalText = textLabel({
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 1, -10),
		TextColor3 = P.TextDark,
		Text = "Loading...",
		Parent = goal,
	}, 22)

	if Config.SessionOnly then
		textLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 105),
			Size = UDim2.fromOffset(320, 18),
			TextTransparency = 0.25,
			TextStrokeTransparency = 0.5,
			Text = "PROTOTYPE - progress resets when you leave",
			Parent = gui,
		}, 14)
	end

	-- Inventory (left middle)
	local inv = new("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.45, 0),
		Size = UDim2.fromOffset(160, 132),
		BackgroundColor3 = P.PanelDark,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		corner(14),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self.rows = {}
	local function row(key: string, color: Color3, order: number)
		local r = new("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = inv,
		})
		local d = dot(color, 20)
		d.Position = UDim2.new(0, 0, 0.5, -10)
		d.Parent = r
		self.rows[key] = textLabel({
			Position = UDim2.fromOffset(28, 4),
			Size = UDim2.new(1, -28, 1, -8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = r,
		}, 20)
	end
	for i, id in Config.IngredientOrder do
		row(id, Config.Ingredients[id].Color, i)
	end
	row("Potions", Config.Recipes[Config.PrototypeRecipe].Color, #Config.IngredientOrder + 1)

	-- Upgrades button (right middle)
	local upgradeButton = new("TextButton", {
		Name = "UpgradesButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.45, 0),
		Size = UDim2.fromOffset(140, 54),
		BackgroundColor3 = P.Button,
		Font = FONT,
		Text = "UPGRADES",
		TextColor3 = P.TextLight,
		TextScaled = true,
		AutoButtonColor = true,
		Parent = gui,
	}, {
		corner(14),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		new("UITextSizeConstraint", { MaxTextSize = 24 }),
		new("UIStroke", { Color = P.TextDark, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local badge = dot(Color3.fromRGB(255, 70, 70), 22)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Visible = false
	badge.Parent = upgradeButton
	self.badge = badge

	-- Upgrades panel (center, hidden)
	local panel = new("Frame", {
		Name = "UpgradePanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.9, 0, 0, 220),
		BackgroundColor3 = P.PanelLight,
		Visible = false,
		Parent = gui,
	}, {
		corner(18),
		new("UISizeConstraint", { MaxSize = Vector2.new(380, 220) }),
		new("UIStroke", { Color = P.DarkWood, Thickness = 3 }),
	})
	self.panel = panel
	textLabel({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.TextDark,
		Text = "Upgrades",
		Parent = panel,
	}, 30)
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = P.AwningA,
		Font = FONT,
		Text = "X",
		TextColor3 = P.TextLight,
		TextSize = 26,
		Parent = panel,
	}, { corner(12) })
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	upgradeButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	-- One card per upgrade (prototype has one)
	self.cards = {}
	for i, upgradeId in Config.UpgradeOrder do
		local upgrade = Config.Upgrades[upgradeId]
		local card = new("Frame", {
			Position = UDim2.new(0, 14, 0, 58 + (i - 1) * 150),
			Size = UDim2.new(1, -28, 0, 146),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Parent = panel,
		}, { corner(12) })
		textLabel({
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = P.TextDark,
			Text = upgrade.DisplayName,
			Parent = card,
		}, 24)
		local info = textLabel({
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -24, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = P.TextDark,
			TextWrapped = true,
			Text = upgrade.Description,
			Parent = card,
		}, 16)
		local buy = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -24, 0, 50),
			BackgroundColor3 = P.Button,
			Font = FONT,
			Text = "Buy",
			TextColor3 = P.TextLight,
			TextScaled = true,
			Parent = card,
		}, {
			corner(12),
			new("UITextSizeConstraint", { MaxTextSize = 24 }),
			new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		})
		buy.Activated:Connect(function()
			if self.onUpgrade then
				self.onUpgrade(upgradeId)
			end
		end)
		self.cards[upgradeId] = { info = info, buy = buy, description = upgrade.Description }
	end

	-- Toast (short messages)
	self.toast = textLabel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		Size = UDim2.fromOffset(340, 42),
		BackgroundColor3 = P.PanelDark,
		BackgroundTransparency = 0.1,
		Text = "",
		Visible = false,
		Parent = gui,
	}, 22)
	corner(12).Parent = self.toast

	return self
end

function Hud:SetState(state)
	local previousCoins = self.state and self.state.Coins
	self.state = state
	self.coinText.Text = tostring(state.Coins)
	if previousCoins and state.Coins > previousCoins then
		self.coinScale.Scale = 1.2
		TweenService:Create(self.coinScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	for _, id in Config.IngredientOrder do
		self.rows[id].Text = `{Config.Ingredients[id].DisplayName}: {state.Ingredients[id] or 0}/{Config.Storage.MaxPerIngredient}`
	end
	local potionTotal = 0
	for _, count in state.Potions do
		potionTotal += count
	end
	self.rows.Potions.Text = `Potions: {potionTotal}/{Config.Storage.MaxPotions}`

	local canAfford = false
	for upgradeId, card in self.cards do
		local level = state.Upgrades[upgradeId] or 0
		local cost = Config.GetNextUpgradeCost(upgradeId, level)
		local maxLevel = #Config.Upgrades[upgradeId].Levels
		if upgradeId == "BrewSpeed" then
			local nowSec = Config.GetBrewSeconds(level)
			if cost then
				card.info.Text = `Level {level}/{maxLevel}. Brew time {nowSec}s -> {Config.GetBrewSeconds(level + 1)}s`
			else
				card.info.Text = `Level {level}/{maxLevel}. Brew time {nowSec}s`
			end
		end
		if cost then
			card.buy.Text = `Buy - {cost} coins`
			local affordable = state.Coins >= cost
			card.buy.BackgroundColor3 = if affordable then P.Button else P.ButtonOff
			canAfford = canAfford or affordable
		else
			card.buy.Text = "MAXED"
			card.buy.BackgroundColor3 = P.ButtonOff
		end
	end
	self.badge.Visible = canAfford
end

function Hud:SetGoal(text: string)
	if self.goalText.Text ~= text then
		self.goalText.Text = text
	end
end

function Hud:Toast(text: string)
	self.toastToken += 1
	local token = self.toastToken
	self.toast.Text = text
	self.toast.Visible = true
	task.delay(2, function()
		if self.toastToken == token then
			self.toast.Visible = false
		end
	end)
end

return Hud
