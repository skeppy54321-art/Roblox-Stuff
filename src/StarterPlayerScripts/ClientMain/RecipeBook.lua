--!strict
-- RecipeBook (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.RecipeBook
-- Every potion: what it needs, what it does, what it sells for, whether you've brewed it,
-- and its mastery medal (sell enough of one potion and it sells for more).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

export type State = Config.State

type Card = { Frame: Frame, Tag: TextLabel, Info: TextLabel, Shade: Frame, Medal: TextLabel }

local RecipeBook = {}

RecipeBook.OnClose = nil :: (() -> ())?

local panel: Frame
local cards: { [string]: Card } = {}

function RecipeBook.Init(root: Frame)
	local body, close
	panel, body, close =
		Ui.panel(root, "RecipeBook", "Recipe Book", Vector2.new(620, 520), Color3.fromRGB(140, 80, 200))
	close.Activated:Connect(function()
		if RecipeBook.OnClose then
			RecipeBook.OnClose()
		end
	end)

	local list = Ui.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = P.DarkWood,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 10,
		Parent = body,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
	})

	for order, recipeId in Config.RecipeOrder do
		local recipe = Config.Recipes[recipeId]
		local card = Ui.new("Frame", {
			Name = recipeId,
			Size = UDim2.new(1, 0, 0, 112),
			BackgroundColor3 = P.PanelCream,
			LayoutOrder = order,
			ZIndex = 10,
			Parent = list,
		}, { Ui.corner(14), Ui.stroke(P.Stone, 2) })

		local icon = Ui.bottle(recipe.Color, 56)
		icon.Position = UDim2.fromOffset(18, 12)
		icon.ZIndex = 11
		for _, d in icon:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 10
			end
		end
		icon.Parent = card

		Ui.label({
			Position = UDim2.fromOffset(92, 8),
			Size = UDim2.new(1, -230, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = P.TextDark,
			Text = recipe.DisplayName,
			ZIndex = 11,
			Parent = card,
		}, 24)
		Ui.label({
			Position = UDim2.fromOffset(92, 38),
			Size = UDim2.new(1, -230, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = P.TextMuted,
			Text = recipe.Description,
			ZIndex = 11,
			Parent = card,
		}, 17)

		-- ingredient chips
		local chips = Ui.new("Frame", {
			Position = UDim2.fromOffset(92, 68),
			Size = UDim2.new(1, -230, 0, 30),
			BackgroundTransparency = 1,
			ZIndex = 11,
			Parent = card,
		}, {
			Ui.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})
		for i, ingredientId in Config.IngredientOrder do
			local amount = recipe.Ingredients[ingredientId]
			if amount then
				local info = Config.Ingredients[ingredientId]
				local chip = Ui.new("Frame", {
					Size = UDim2.fromOffset(0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = P.PanelLight,
					LayoutOrder = i,
					ZIndex = 11,
					Parent = chips,
				}, {
					Ui.corner(10),
					Ui.stroke(info.Color, 2),
					Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8) }),
					Ui.new("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 4),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
				})
				local dot = Ui.dot(info.Color, 16)
				dot.ZIndex = 12
				dot.Parent = chip
				local text = Ui.new("TextLabel", {
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Font = Ui.FONT,
					TextSize = 16,
					TextColor3 = P.TextDark,
					Text = `{amount} {info.DisplayName}`,
					ZIndex = 12,
				})
				text.Parent = chip
			end
		end

		-- right side: price, time, status tag
		local info = Ui.label({
			Name = "Info",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(124, 50),
			TextColor3 = P.TextDark,
			Text = "",
			ZIndex = 11,
			Parent = card,
		}, 20)
		local tag = Ui.label({
			Name = "Tag",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(124, 32),
			BackgroundTransparency = 0,
			BackgroundColor3 = P.Button,
			Text = "",
			ZIndex = 11,
			Parent = card,
		}, 18)
		Ui.corner(10).Parent = tag
		local shade = Ui.new("Frame", { -- greys out locked recipes
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = P.PanelLight,
			BackgroundTransparency = 0.45,
			Visible = false,
			ZIndex = 13,
			Parent = card,
		}, { Ui.corner(14) })
		local medal = Ui.label({ -- mastery: "+10%" on a bronze / silver / gold pill
			Name = "Medal",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(46, 92),
			Size = UDim2.fromOffset(56, 24),
			BackgroundTransparency = 0,
			BackgroundColor3 = P.Gold,
			TextColor3 = P.TextDark,
			Text = "",
			Visible = false,
			ZIndex = 12,
			Parent = card,
		}, 16)
		Ui.corner(12).Parent = medal
		Ui.stroke(P.TextDark, 2).Parent = medal
		cards[recipeId] = { Frame = card, Tag = tag, Info = info, Shade = shade, Medal = medal }
	end
end

function RecipeBook.SetState(state: State)
	for recipeId, card in cards do
		local seconds = Config.GetBrewSeconds(state.Upgrades, recipeId)
		local price = math.floor(Config.GetPotionPrice(state.Stats, recipeId) + 0.5)
		card.Info.Text = `{price} coins\n{seconds}s brew`
		local level, sold, nextAt, bonus = Config.GetMastery(state.Stats, recipeId)
		card.Medal.Visible = level > 0
		if level > 0 then
			card.Medal.Text = `+{math.floor(bonus * 100 + 0.5)}%`
			card.Medal.BackgroundColor3 = P.Medals[4 - level] -- (Medals is gold, silver, bronze)
		end
		if not Config.IsRecipeUnlocked(state.Upgrades, recipeId) then
			local unlockerId = Config.GetRecipeUnlocker(recipeId) or ""
			local unlocker = Config.Upgrades[unlockerId]
			card.Tag.Text = if Config.NeedsRebirth(unlockerId, state.Rebirths)
				then "Needs a Rebirth"
				elseif unlocker then `Needs {unlocker.DisplayName}`
				else "Locked"
			card.Tag.BackgroundColor3 = P.ButtonOff
			card.Tag.TextColor3 = P.TextLight
			card.Shade.Visible = true
		elseif state.Discovered[recipeId] then
			-- how far to the next medal
			card.Tag.Text = if nextAt then `Sold {Config.FormatNumber(sold)}/{Config.FormatNumber(nextAt)}` else "GOLD!"
			card.Tag.BackgroundColor3 = if nextAt then P.ButtonDark else P.Medals[1]
			card.Tag.TextColor3 = if nextAt then P.TextLight else P.TextDark
			card.Shade.Visible = false
		else
			card.Tag.Text = "NEW! Try it"
			card.Tag.BackgroundColor3 = P.Danger
			card.Tag.TextColor3 = P.TextLight
			card.Shade.Visible = false
		end
	end
end

function RecipeBook.SetOpen(open: boolean)
	panel.Visible = open
	if open then
		Ui.pop(panel, 0.06)
	end
end

function RecipeBook.IsOpen(): boolean
	return panel.Visible
end

return RecipeBook
