--!strict
-- Hud (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.Hud
-- The always-on screen UI: coins, the goal banner, your basket (ingredients + potions),
-- the side buttons, toast messages and the big celebration banner.
-- Display only: it never changes coins or items.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

export type State = Config.State

local Hud = {}

-- Callbacks the rest of the client sets.
Hud.OnUpgradesPressed = nil :: (() -> ())?
Hud.OnRecipesPressed = nil :: (() -> ())?
Hud.OnMutePressed = nil :: (() -> ())?
Hud.OnGiftPressed = nil :: (() -> ())?
Hud.OnQuestsPressed = nil :: (() -> ())?
Hud.OnStudioCoins = nil :: (() -> ())?

local root: Frame
local coinsPill: Frame
local multiplierChip: TextLabel
local coinText: TextLabel
local goalFrame: Frame
local goalText: TextLabel
local saveChip: TextLabel
local basket: Frame
local ingredientRows: { [string]: { Row: Frame, Count: TextLabel } } = {}
local ingredientGrid: Frame
local ingredientChips: { [string]: { Chip: Frame, Count: TextLabel } } = {}
-- With more ingredients than this, the basket switches to a compact two-column grid
-- (dots and counts only) so it stays clear of the phone thumbstick.
local FULL_ROWS_UP_TO = 4
local potionTotal: TextLabel
local potionChips: Frame
local upgradesBadge: Frame
local recipesBadge: Frame
local muteFace: TextButton
local giftHolder: Frame
local giftFace: TextButton
local giftBadge: Frame
local questsHolder: Frame
local questsBadge: Frame
local toastList: Frame
local celebration: Frame

local shownCoins = 0
local coinTween: Tween? = nil
local coinValue: NumberValue

local function rowFrame(order: number, height: number): Frame
	return Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = basket,
	})
end

local function badge(parent: Instance, text: string, color: Color3): Frame
	local b = Ui.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(if #text > 1 then 44 else 26, 26),
		BackgroundColor3 = color,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, { Ui.round(), Ui.stroke(P.PanelLight, 2) })
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		ZIndex = 6,
		Parent = b,
	}, 16)
	return b
end

------------------------------------------------------------------
-- Build
------------------------------------------------------------------

function Hud.Init(parent: Frame)
	root = parent

	-- Coins (top center)
	coinsPill = Ui.new("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(210, 54),
		BackgroundColor3 = P.PanelDark,
		Parent = root,
	}, { Ui.corner(27), Ui.stroke(P.Gold, 3) })
	local coinIcon = Ui.coin(34)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.new(0, 11, 0.5, 0)
	coinIcon.Parent = coinsPill
	coinText = Ui.label({
		Position = UDim2.fromOffset(54, 7),
		Size = UDim2.new(1, -66, 1, -14),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = coinsPill,
	}, 32)
	-- "x1.25" under the coins after a rebirth (every sale pays that much more)
	multiplierChip = Ui.label({
		Name = "Multiplier",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 1, -4),
		Size = UDim2.fromOffset(62, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = P.Gold,
		TextColor3 = P.TextDark,
		Text = "x1",
		Visible = false,
		ZIndex = 3,
		Parent = coinsPill,
	}, 17)
	Ui.corner(10).Parent = multiplierChip
	coinValue = Instance.new("NumberValue")
	coinValue.Changed:Connect(function(value)
		coinText.Text = Config.FormatNumber(value)
	end)

	-- Goal banner (under the coins)
	goalFrame = Ui.new("Frame", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.9, 0, 0, 46),
		BackgroundColor3 = P.PanelLight,
		Parent = root,
	}, {
		Ui.corner(14),
		Ui.stroke(P.DarkWood, 3),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(560, 46) }),
	})
	local bang = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = P.Gold,
		Parent = goalFrame,
	}, { Ui.round(), Ui.stroke(P.DarkWood, 2) })
	Ui.label({ Size = UDim2.fromScale(1, 1), Text = "!", TextColor3 = P.TextDark, Parent = bang }, 22)
	goalText = Ui.label({
		Position = UDim2.fromOffset(46, 5),
		Size = UDim2.new(1, -56, 1, -10),
		TextColor3 = P.TextDark,
		Text = "Loading your shop...",
		Parent = goalFrame,
	}, 22)

	-- Save status (only shown when progress is NOT being saved, e.g. an unpublished Studio test)
	saveChip = Ui.label({
		Name = "SaveChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 122),
		Size = UDim2.fromOffset(430, 24),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(200, 110, 40),
		Text = "Test mode: progress is not saved here",
		Visible = false,
		Parent = root,
	}, 16)
	Ui.corner(10).Parent = saveChip

	-- Basket (top left): ingredients and potions
	basket = Ui.new("Frame", {
		Name = "Basket",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(196, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = P.PanelDark,
		BackgroundTransparency = 0.12,
		Parent = root,
	}, {
		Ui.corner(16),
		Ui.stroke(P.PanelMid, 2),
		Ui.padding(10, 8),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, id in Config.IngredientOrder do
		local info = Config.Ingredients[id]
		local row = rowFrame(i, 28)
		local dot = Ui.dot(info.Color, 20)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.fromScale(0, 0.5)
		dot.Parent = row
		Ui.label({
			Position = UDim2.fromOffset(28, 3),
			Size = UDim2.new(1, -86, 1, -6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = info.DisplayName,
			Parent = row,
		}, 18)
		local count = Ui.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 3),
			Size = UDim2.new(0, 56, 1, -6),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "0",
			Parent = row,
		}, 18)
		ingredientRows[id] = { Row = row, Count = count }
	end
	ingredientGrid = Ui.new("Frame", {
		Name = "IngredientGrid",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 40,
		Visible = false,
		Parent = basket,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(85, 26),
			CellPadding = UDim2.fromOffset(6, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, id in Config.IngredientOrder do
		local chip = Ui.new("Frame", {
			Name = id,
			LayoutOrder = i,
			BackgroundColor3 = P.PanelMid,
			Parent = ingredientGrid,
		}, { Ui.corner(8) })
		local dot = Ui.dot(Config.Ingredients[id].Color, 16)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 6, 0.5, 0)
		dot.Parent = chip
		local count = Ui.label({
			Position = UDim2.fromOffset(28, 3),
			Size = UDim2.new(1, -34, 1, -6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "0",
			Parent = chip,
		}, 17)
		ingredientChips[id] = { Chip = chip, Count = count }
	end
	local divider = rowFrame(50, 2)
	divider.BackgroundTransparency = 0.6
	divider.BackgroundColor3 = P.PanelLight
	local potionRow = rowFrame(51, 30)
	local bottleIcon = Ui.bottle(P.Bottles[1], 16)
	bottleIcon.AnchorPoint = Vector2.new(0, 0.5)
	bottleIcon.Position = UDim2.new(0, 2, 0.5, 0)
	bottleIcon.Parent = potionRow
	Ui.label({
		Position = UDim2.fromOffset(28, 3),
		Size = UDim2.new(1, -86, 1, -6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Potions",
		Parent = potionRow,
	}, 18)
	potionTotal = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		Size = UDim2.new(0, 56, 1, -6),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0/5",
		Parent = potionRow,
	}, 18)
	potionChips = Ui.new("Frame", {
		Name = "PotionChips",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 52,
		Parent = basket,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(41, 28),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Side buttons (right middle)
	local column = Ui.new("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.45, 0), -- (clear of the top bar and the jump button)
		Size = UDim2.fromOffset(156, 312),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local gift, giftButtonFace = Ui.button({
		Name = "GiftButton",
		Text = "GIFT",
		Color = P.Gold,
		Shade = Color3.fromRGB(190, 140, 30),
		Size = UDim2.fromOffset(120, 52),
		TextSize = 20,
		Parent = column,
	})
	gift.LayoutOrder = 0
	giftHolder = gift
	giftFace = giftButtonFace
	giftBadge = badge(gift, "!", P.Danger)
	giftFace.Activated:Connect(function()
		if Hud.OnGiftPressed then
			Hud.OnGiftPressed()
		end
	end)
	local upgrades, upgradesFace = Ui.button({
		Name = "UpgradesButton",
		Text = "UPGRADES",
		Color = P.Button,
		Shade = P.ButtonDark,
		Size = UDim2.fromOffset(156, 60),
		Parent = column,
	})
	upgrades.LayoutOrder = 1
	upgradesBadge = badge(upgrades, "!", P.Danger)
	upgradesFace.Activated:Connect(function()
		if Hud.OnUpgradesPressed then
			Hud.OnUpgradesPressed()
		end
	end)
	local recipes, recipesFace = Ui.button({
		Name = "RecipesButton",
		Text = "RECIPES",
		Color = Color3.fromRGB(160, 100, 220),
		Shade = Color3.fromRGB(110, 60, 160),
		Size = UDim2.fromOffset(156, 60),
		Parent = column,
	})
	recipes.LayoutOrder = 2
	recipesBadge = badge(recipes, "NEW", P.Danger)
	recipesFace.Activated:Connect(function()
		if Hud.OnRecipesPressed then
			Hud.OnRecipesPressed()
		end
	end)
	local quests, questsFace = Ui.button({
		Name = "QuestsButton",
		Text = "QUESTS",
		Color = Color3.fromRGB(240, 130, 60),
		Shade = Color3.fromRGB(180, 85, 35),
		Size = UDim2.fromOffset(156, 56),
		Parent = column,
	})
	quests.LayoutOrder = 3
	quests.Visible = false -- until the daily quests start (after the tutorial)
	questsHolder = quests
	questsBadge = badge(quests, "3", P.Danger)
	questsFace.Activated:Connect(function()
		if Hud.OnQuestsPressed then
			Hud.OnQuestsPressed()
		end
	end)
	local mute, face = Ui.button({
		Name = "MuteButton",
		Text = "SOUND ON",
		Color = P.ButtonOff,
		Shade = P.ButtonOffDark,
		Size = UDim2.fromOffset(120, 44),
		TextSize = 16,
		Parent = column,
	})
	mute.LayoutOrder = 4
	muteFace = face
	muteFace.Activated:Connect(function()
		if Hud.OnMutePressed then
			Hud.OnMutePressed()
		end
	end)

	-- Toasts (stacked under the goal banner)
	toastList = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 152),
		Size = UDim2.fromOffset(420, 150),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Celebration banner (center)
	celebration = Ui.new("Frame", {
		Name = "Celebration",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(440, 110),
		BackgroundColor3 = P.PanelDark,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	}, { Ui.corner(22), Ui.stroke(P.Gold, 4) })
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(100, 12),
		Size = UDim2.new(1, -116, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.Gold,
		Text = "",
		ZIndex = 21,
		Parent = celebration,
	}, 38)
	Ui.label({
		Name = "Subtitle",
		Position = UDim2.fromOffset(100, 58),
		Size = UDim2.new(1, -116, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 21,
		Parent = celebration,
	}, 24)
end

------------------------------------------------------------------
-- Updates
------------------------------------------------------------------

function Hud.SetState(state: State)
	-- coins count up smoothly and the pill bounces when you earn some
	if state.Coins ~= shownCoins then
		local earned = state.Coins > shownCoins
		shownCoins = state.Coins
		if coinTween then
			coinTween:Cancel()
		end
		local tween =
			TweenService:Create(coinValue, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = state.Coins })
		coinTween = tween
		tween:Play()
		if earned then
			Ui.pop(coinsPill, 0.18)
		end
	end

	local multiplier = Config.GetCoinMultiplier(state.Rebirths)
	multiplierChip.Visible = multiplier > 1
	multiplierChip.Text = `x{string.format("%g", multiplier)}`

	local unlockedCount = 0
	for _, id in Config.IngredientOrder do
		if Config.IsIngredientUnlocked(state.Upgrades, id) then
			unlockedCount += 1
		end
	end
	local compact = unlockedCount > FULL_ROWS_UP_TO
	local maxEach = Config.Tuning.Storage.MaxPerIngredient
	ingredientGrid.Visible = compact
	for id, row in ingredientRows do
		local unlocked = Config.IsIngredientUnlocked(state.Upgrades, id)
		local count = state.Ingredients[id] or 0
		row.Row.Visible = unlocked and not compact
		row.Count.Text = `{count}/{maxEach}`
		local chip = ingredientChips[id]
		chip.Chip.Visible = unlocked
		chip.Count.Text = tostring(count)
		chip.Count.TextColor3 = if count >= maxEach then P.Gold else P.TextLight -- gold = full
	end

	local total = Config.PotionTotal(state.Potions)
	local maxPotions = Config.GetMaxPotions(state.Upgrades)
	potionTotal.Text = `{total}/{maxPotions}`
	potionTotal.TextColor3 = if total >= maxPotions then P.Danger else P.TextLight
	for _, child in potionChips:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, id in Config.RecipeOrder do
		local count = state.Potions[id] or 0
		if count > 0 then
			local chip = Ui.new("Frame", {
				Name = id,
				LayoutOrder = i,
				BackgroundColor3 = P.PanelMid,
				Parent = potionChips,
			}, { Ui.corner(8) })
			local icon = Ui.bottle(Config.Recipes[id].Color, 13)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 4, 0.5, 0)
			icon.Parent = chip
			Ui.label({
				Position = UDim2.fromOffset(19, 4),
				Size = UDim2.new(1, -21, 1, -8),
				Text = `x{count}`,
				Parent = chip,
			}, 15)
		end
	end

	-- badges: something affordable / a recipe you haven't brewed yet
	local canAfford = false
	for _, upgradeId in Config.UpgradeOrder do
		local cost = Config.GetNextUpgradeCost(upgradeId, Config.GetLevel(state.Upgrades, upgradeId))
		if cost and state.Coins >= cost and Config.IsUpgradeAvailable(state.Upgrades, upgradeId, state.Rebirths) then
			canAfford = true
			break
		end
	end
	upgradesBadge.Visible = canAfford
	local hasNew = false
	for _, recipeId in Config.RecipeOrder do
		if Config.IsRecipeUnlocked(state.Upgrades, recipeId) and not state.Discovered[recipeId] then
			hasNew = true
			break
		end
	end
	recipesBadge.Visible = hasNew
end

function Hud.SetGoal(text: string)
	if goalText.Text ~= text then
		goalText.Text = text
		Ui.pop(goalFrame, 0.06)
	end
end

function Hud.SetSaveMode(mode: string?)
	saveChip.Visible = mode ~= nil and mode ~= "Access"
end

-- Coins fly from `from` to `to` (both in the ScreenGui's own pixel space), then the coin
-- counter bounces.
function Hud.FlyCoinsBetween(from: Vector2, to: Vector2, amount: number)
	local layer = root.Parent
	if not layer then
		return
	end
	local scale = root:FindFirstChildOfClass("UIScale")
	local s = if scale then scale.Scale else 1
	local count = math.clamp(math.floor(amount / 12) + 3, 3, 8)
	for i = 1, count do
		local coin = Ui.coin(math.floor(26 * s))
		coin.Name = "FlyingCoin"
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		local start = from + Vector2.new(math.random(-18, 18), math.random(-12, 12)) * s
		coin.Position = UDim2.fromOffset(start.X, start.Y)
		coin.ZIndex = 30
		coin.Parent = layer
		task.delay((i - 1) * 0.06, function()
			local tween = TweenService:Create(
				coin,
				TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(to.X, to.Y) }
			)
			tween.Completed:Once(function()
				coin:Destroy()
				if i == count then
					Ui.pop(coinsPill, 0.14)
				end
			end)
			tween:Play()
		end)
	end
end

-- Coins fly from a screen point (Camera:WorldToScreenPoint, the same space as
-- AbsolutePosition) into the coin counter. Cosmetic: does nothing if layout isn't known.
function Hud.FlyCoins(from: Vector2, amount: number)
	local layer = root.Parent
	if not layer or not layer:IsA("GuiBase2d") then
		return
	end
	local ok, origin, target = pcall(function()
		return layer.AbsolutePosition, coinsPill.AbsolutePosition + coinsPill.AbsoluteSize / 2
	end)
	if ok then
		Hud.FlyCoinsBetween(from - origin, target - origin, amount)
	end
end

-- Studio play tests only: a small "+10K" button under the basket for trying the late game.
function Hud.ShowStudioButton()
	local button, face = Ui.button({
		Name = "StudioCoins",
		Text = "+10K (Studio)",
		Color = Color3.fromRGB(240, 140, 50),
		Shade = Color3.fromRGB(180, 90, 30),
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0, 12, 1, -150),
		TextSize = 16,
		Parent = root,
	})
	button.ZIndex = 5
	face.Activated:Connect(function()
		if Hud.OnStudioCoins then
			Hud.OnStudioCoins()
		end
	end)
end

-- The daily gift button: bright with a badge when ready, else the time left.
function Hud.SetGift(ready: boolean, label: string)
	giftFace.Text = label
	giftBadge.Visible = ready
	Ui.setButtonColor(
		giftHolder,
		if ready then P.Gold else P.ButtonOff,
		if ready then Color3.fromRGB(190, 140, 30) else P.ButtonOffDark
	)
end

-- The quests button: shown once there are daily quests; the badge counts the ones left.
function Hud.SetQuests(visible: boolean, left: number)
	questsHolder.Visible = visible
	questsBadge.Visible = visible and left > 0
	local label = questsBadge:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = tostring(left)
	end
end

function Hud.SetMuted(muted: boolean)
	muteFace.Text = if muted then "SOUND OFF" else "SOUND ON"
end

-- Short message under the goal banner. kind: "info" | "good" | "bad"
function Hud.Toast(text: string, kind: string?)
	local color = if kind == "good"
		then P.ButtonDark
		elseif kind == "bad" then Color3.fromRGB(190, 60, 70)
		elseif kind == "news" then P.News
		elseif kind == "heart" then P.Heart
		else P.PanelDark
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= 3 then
		toasts[1]:Destroy()
	end
	local toast = Ui.label({
		Name = "Toast",
		Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.08,
		LayoutOrder = math.floor(os.clock() * 1000),
		Text = text,
		Parent = toastList,
	}, 22)
	Ui.corner(12).Parent = toast
	Ui.padding(10, 4).Parent = toast
	Ui.pop(toast, 0.12)
	task.delay(2.4, function()
		if toast.Parent then
			local fade = TweenInfo.new(0.35)
			TweenService:Create(toast, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

-- Big banner in the middle of the screen for special moments.
local celebrationToken = 0
function Hud.Celebrate(title: string, subtitle: string, color: Color3)
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy() -- the banner says it all; don't stack messages under it
		end
	end
	celebrationToken += 1
	local token = celebrationToken
	local titleLabel = celebration:FindFirstChild("Title") :: TextLabel
	local subtitleLabel = celebration:FindFirstChild("Subtitle") :: TextLabel
	titleLabel.Text = title
	subtitleLabel.Text = subtitle
	local old = celebration:FindFirstChild("Bottle")
	if old then
		old:Destroy()
	end
	local icon = Ui.bottle(color, 58)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 22, 0.5, 0)
	icon.ZIndex = 21
	icon.Parent = celebration
	celebration.Visible = true
	Ui.pop(celebration, 0.35)
	task.delay(2.6, function()
		if celebrationToken == token then
			celebration.Visible = false
		end
	end)
end

function Hud.GetRoot(): Frame
	return root
end

return Hud
