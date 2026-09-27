--!strict
-- CauldronMenu (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.CauldronMenu
-- Pops up at the bottom of the screen while you stand at your own idle cauldron.
-- Tap a potion to brew it (keys 1-7 work too). It only ASKS the server to brew.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

export type State = Config.State

type Card = {
	Holder: Frame,
	Face: TextButton,
	Status: TextLabel,
	Wanted: Frame,
	Glow: UIStroke,
	Counts: { [string]: TextLabel },
}

local CauldronMenu = {}

CauldronMenu.OnBrew = nil :: ((recipeId: string) -> ())?

local frame: Frame
local hint: TextLabel
local cards: { [string]: Card } = {}
local order: { string } = {} -- recipe ids of the cards currently shown, left to right
local wasVisible = false

local function makeCard(parent: Instance, recipeId: string, layoutOrder: number): Card
	local recipe = Config.Recipes[recipeId]
	local holder = Ui.new("Frame", {
		Name = recipeId,
		Size = UDim2.fromOffset(104, 124),
		BackgroundColor3 = P.PanelCream,
		LayoutOrder = layoutOrder,
		Parent = parent,
	}, { Ui.corner(14) })
	local glow = Ui.stroke(P.Stone, 2) :: UIStroke
	glow.Parent = holder
	local face = Ui.new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	})

	local icon = Ui.bottle(recipe.Color, 26)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 6)
	icon.Parent = holder
	Ui.label({
		Position = UDim2.fromOffset(5, 46),
		Size = UDim2.new(1, -10, 0, 28),
		TextColor3 = P.TextDark,
		TextWrapped = true,
		Text = recipe.DisplayName,
		Parent = holder,
	}, 15)

	-- ingredient dots with "have/need" counts
	local row = Ui.new("Frame", {
		Position = UDim2.fromOffset(3, 76),
		Size = UDim2.new(1, -6, 0, 16),
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local counts: { [string]: TextLabel } = {}
	for i, ingredientId in Config.IngredientOrder do
		if recipe.Ingredients[ingredientId] then
			local dot = Ui.dot(Config.Ingredients[ingredientId].Color, 12)
			dot.LayoutOrder = i * 2
			dot.Parent = row
			local count = Ui.new("TextLabel", {
				Size = UDim2.fromOffset(24, 16),
				BackgroundTransparency = 1,
				Font = Ui.FONT,
				TextSize = 13,
				TextColor3 = P.TextDark,
				Text = "",
				LayoutOrder = i * 2 + 1,
				Parent = row,
			})
			counts[ingredientId] = count
		end
	end

	local status = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -10, 0, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = P.Button,
		Text = "BREW",
		Parent = holder,
	}, 16)
	Ui.corner(8).Parent = status

	local wanted = Ui.new("Frame", {
		Name = "Wanted",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(82, 20),
		BackgroundColor3 = P.Gold,
		Visible = false,
		ZIndex = 3,
		Parent = holder,
	}, { Ui.corner(8), Ui.stroke(P.DarkWood, 2) })
	Ui.label(
		{ Size = UDim2.fromScale(1, 1), Text = "WANTED", TextColor3 = P.TextDark, ZIndex = 4, Parent = wanted },
		14
	)

	face.Activated:Connect(function()
		Ui.pop(holder, 0.1)
		if CauldronMenu.OnBrew then
			CauldronMenu.OnBrew(recipeId)
		end
	end)
	return { Holder = holder, Face = face, Status = status, Wanted = wanted, Glow = glow, Counts = counts }
end

function CauldronMenu.Init(root: Frame)
	frame = Ui.new("Frame", {
		Name = "CauldronMenu",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0.6, 0, 0, 170),
		BackgroundColor3 = P.PanelLight,
		Visible = false,
		Parent = root,
	}, {
		Ui.corner(18),
		Ui.stroke(P.DarkWood, 3),
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(300, 170), MaxSize = Vector2.new(600, 170) }),
	})
	Ui.label({
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(0.5, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.TextDark,
		Text = "Brew a potion",
		Parent = frame,
	}, 20)
	hint = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.new(0.5, -20, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = P.Danger,
		Text = "",
		Parent = frame,
	}, 16)
	local list = Ui.new("ScrollingFrame", {
		Name = "Cards",
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = P.DarkWood,
		Parent = frame,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Ui.new(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4) }
		),
	})
	for i, recipeId in Config.RecipeOrder do
		cards[recipeId] = makeCard(list, recipeId, i)
	end
end

-- wants = potions customers are asking for; suggested = what pressing the cauldron brews.
function CauldronMenu.Update(visible: boolean, state: State?, wants: { string }, suggested: string)
	if not visible or not state then
		frame.Visible = false
		wasVisible = false
		return
	end
	frame.Visible = true
	if not wasVisible then
		Ui.pop(frame, 0.08)
		wasVisible = true
	end

	local shelfFull = Config.PotionTotal(state.Potions) >= Config.GetMaxPotions(state.Upgrades)
	hint.Text = if shelfFull then "Shelf full! Sell potions first." else "Tap a potion to brew it"
	hint.TextColor3 = if shelfFull then P.Danger else P.TextMuted

	table.clear(order)
	for _, recipeId in Config.RecipeOrder do
		local card = cards[recipeId]
		local unlocked = Config.IsRecipeUnlocked(state.Upgrades, recipeId)
		card.Holder.Visible = unlocked
		if not unlocked then
			continue
		end
		table.insert(order, recipeId)
		local recipe = Config.Recipes[recipeId]
		local missing: string? = nil
		for ingredientId, need in recipe.Ingredients do
			local have = state.Ingredients[ingredientId] or 0
			local count = card.Counts[ingredientId]
			if count then
				count.Text = `{math.min(have, need)}/{need}`
				count.TextColor3 = if have >= need then P.TextDark else P.Danger
			end
			if have < need and not missing then
				missing = Config.Ingredients[ingredientId].DisplayName
			end
		end
		local canBrew = missing == nil and not shelfFull
		card.Status.Text = if shelfFull then "SHELF FULL" elseif missing then `Need {missing}` else `BREW  [{#order}]`
		card.Status.BackgroundColor3 = if canBrew then P.Button else P.ButtonOff
		card.Holder.BackgroundColor3 = if canBrew then P.PanelCream else Color3.fromRGB(232, 226, 220)
		card.Wanted.Visible = table.find(wants, recipeId) ~= nil
		local isSuggested = recipeId == suggested and canBrew
		card.Glow.Color = if isSuggested then P.Gold else P.Stone
		card.Glow.Thickness = if isSuggested then 4 else 2
	end
end

-- The recipe on the nth visible card (for number keys).
function CauldronMenu.GetRecipeAt(index: number): string?
	if not frame.Visible then
		return nil
	end
	return order[index]
end

return CauldronMenu
