--!strict
-- UpgradesPanel (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.UpgradesPanel
-- A scrollable list of upgrade cards. Pressing Buy only ASKS the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

export type State = Config.State

type Card = {
	Frame: Frame,
	Order: number,
	Level: TextLabel,
	Summary: TextLabel,
	Pips: { Frame },
	Buy: Frame,
	BuyFace: TextButton,
}

local UpgradesPanel = {}

UpgradesPanel.OnBuy = nil :: ((upgradeId: string) -> ())?
UpgradesPanel.OnRebirth = nil :: (() -> ())?
UpgradesPanel.OnPaint = nil :: ((themeIndex: number) -> ())?
UpgradesPanel.OnClose = nil :: (() -> ())?

local panel: Frame
local cards: { [string]: Card } = {}

type RebirthCard = { Frame: Frame, Count: TextLabel, Summary: TextLabel, Button: Frame, Face: TextButton }
local rebirthCard: RebirthCard
local rebirthReady = false
local confirmUntil = 0
local lastState: State? = nil
local swatches: { UIStroke } = {}

local function buildRebirthCard(list: Instance)
	local R = Config.Tuning.Rebirth
	local card = Ui.new("Frame", {
		Name = "Rebirth",
		Size = UDim2.new(1, 0, 0, 118),
		BackgroundColor3 = P.PanelMid,
		LayoutOrder = 200,
		ZIndex = 10,
		Parent = list,
	}, { Ui.corner(14), Ui.stroke(P.Gold, 3) })
	local icon = Ui.new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = P.Gold,
		ZIndex = 11,
		Parent = card,
	}, { Ui.round(), Ui.stroke(P.TextDark, 2, 0.3) })
	local count = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = "0",
		TextColor3 = P.TextDark,
		ZIndex = 12,
		Parent = icon,
	}, 30)
	Ui.label({
		Position = UDim2.fromOffset(90, 8),
		Size = UDim2.new(1, -250, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.Gold,
		Text = "Rebirth",
		ZIndex = 11,
		Parent = card,
	}, 24)
	Ui.label({
		Position = UDim2.fromOffset(90, 38),
		Size = UDim2.new(1, -250, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = P.PanelLight,
		Text = `Start your shop over for +{math.floor(R.CoinBonus * 100)}% coins from every sale, forever. You keep your familiar, decor and recipes.`,
		ZIndex = 11,
		Parent = card,
	}, 15)
	local summary = Ui.label({
		Position = UDim2.fromOffset(90, 80),
		Size = UDim2.new(1, -250, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.TextLight,
		Text = "",
		ZIndex = 11,
		Parent = card,
	}, 17)
	local button, face = Ui.button({
		Name = "Buy",
		Text = "",
		Color = P.ButtonOff,
		Shade = P.ButtonOffDark,
		Size = UDim2.fromOffset(140, 62),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = 20,
		Parent = card,
	})
	button.ZIndex = 11
	face.ZIndex = 12
	face.Activated:Connect(function()
		if not rebirthReady then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			if UpgradesPanel.OnRebirth then
				UpgradesPanel.OnRebirth()
			end
			return
		end
		-- starting over is big: ask for a second tap
		confirmUntil = os.clock() + 3
		face.Text = "Tap again!"
		Ui.setButtonColor(button, P.Danger, Color3.fromRGB(170, 50, 60))
		task.delay(3.05, function()
			local s = lastState
			if s and os.clock() >= confirmUntil then
				UpgradesPanel.SetState(s)
			end
		end)
	end)
	rebirthCard = { Frame = card, Count = count, Summary = summary, Button = button, Face = face }
end

-- Shop Colors: six two-tone swatches; tap one to repaint your shop (free).
local function buildColorsCard(list: Instance)
	local card = Ui.new("Frame", {
		Name = "ShopColors",
		Size = UDim2.new(1, 0, 0, 118),
		BackgroundColor3 = P.PanelCream,
		LayoutOrder = 50, -- after the upgrades you can still buy, before the maxed ones
		ZIndex = 10,
		Parent = list,
	}, { Ui.corner(14), Ui.stroke(P.Stone, 2) })
	Ui.label({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.TextDark,
		Text = "Shop Colors",
		ZIndex = 11,
		Parent = card,
	}, 24)
	Ui.label({
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -32, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.TextMuted,
		Text = "Paint your awning, banners and rug. Free!",
		ZIndex = 11,
		Parent = card,
	}, 16)
	local row = Ui.new("Frame", {
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 46),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = card,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	for i, theme in P.Awnings do
		local swatch = Ui.new("TextButton", {
			Name = P.ThemeNames[i] or `Theme{i}`,
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = theme[1],
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			ZIndex = 12,
			Parent = row,
		}, { Ui.round() })
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.45, 0.45),
			BackgroundColor3 = theme[2],
			ZIndex = 13,
			Parent = swatch,
		}, { Ui.round() })
		local ring = Ui.stroke(P.Stone, 2) :: UIStroke
		ring.Parent = swatch
		table.insert(swatches, ring)
		swatch.Activated:Connect(function()
			if UpgradesPanel.OnPaint then
				UpgradesPanel.OnPaint(i)
			end
		end)
	end
end

-- Outlines the shop's current colors in gold.
function UpgradesPanel.SetTheme(themeIndex: number)
	for i, ring in swatches do
		ring.Color = if i == themeIndex then P.Gold else P.Stone
		ring.Thickness = if i == themeIndex then 4 else 2
	end
end

function UpgradesPanel.Init(root: Frame)
	local body, close
	panel, body, close = Ui.panel(root, "UpgradesPanel", "Upgrades", Vector2.new(620, 520), P.ButtonDark)
	close.Activated:Connect(function()
		if UpgradesPanel.OnClose then
			UpgradesPanel.OnClose()
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

	for order, upgradeId in Config.UpgradeOrder do
		local upgrade = Config.Upgrades[upgradeId]
		local card = Ui.new("Frame", {
			Name = upgradeId,
			Size = UDim2.new(1, 0, 0, 118),
			BackgroundColor3 = P.PanelCream,
			LayoutOrder = order,
			ZIndex = 10,
			Parent = list,
		}, { Ui.corner(14), Ui.stroke(P.Stone, 2) })

		-- colored badge with the level
		local icon = Ui.new("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(66, 66),
			BackgroundColor3 = upgrade.Color,
			ZIndex = 11,
			Parent = card,
		}, { Ui.corner(14), Ui.stroke(P.TextDark, 2, 0.3) })
		local levelLabel = Ui.label({
			Size = UDim2.fromScale(1, 1),
			Text = "0",
			TextStrokeTransparency = 0.4,
			ZIndex = 12,
			Parent = icon,
		}, 30)

		Ui.label({
			Position = UDim2.fromOffset(90, 8),
			Size = UDim2.new(1, -250, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = P.TextDark,
			Text = upgrade.DisplayName,
			ZIndex = 11,
			Parent = card,
		}, 24)
		Ui.label({
			Position = UDim2.fromOffset(90, 38),
			Size = UDim2.new(1, -250, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = P.TextMuted,
			Text = upgrade.Description,
			ZIndex = 11,
			Parent = card,
		}, 16)
		local summary = Ui.label({
			Position = UDim2.fromOffset(90, 78),
			Size = UDim2.new(1, -250, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = P.TextDark,
			Text = "",
			ZIndex = 11,
			Parent = card,
		}, 17)

		-- level pips under the badge
		local pips = {}
		local levels = #upgrade.Levels
		for i = 1, levels do
			local pip = Ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(45 + (i - (levels + 1) / 2) * 16, 88),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = P.ButtonOff,
				ZIndex = 11,
				Parent = card,
			}, { Ui.round() })
			table.insert(pips, pip)
		end

		local buy, buyFace = Ui.button({
			Name = "Buy",
			Text = "Buy",
			Color = P.Button,
			Shade = P.ButtonDark,
			Size = UDim2.fromOffset(140, 62),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 22,
			Parent = card,
		})
		buy.ZIndex = 11
		buyFace.ZIndex = 12
		buyFace.Activated:Connect(function()
			if UpgradesPanel.OnBuy then
				UpgradesPanel.OnBuy(upgradeId)
			end
		end)
		cards[upgradeId] = {
			Frame = card,
			Order = order,
			Level = levelLabel,
			Summary = summary,
			Pips = pips,
			Buy = buy,
			BuyFace = buyFace,
		}
	end
	buildRebirthCard(list)
	buildColorsCard(list)
end

function UpgradesPanel.SetState(state: State)
	lastState = state
	local rebirths = state.Rebirths or 0
	local ready, reason = Config.CanRebirth(state)
	rebirthReady = ready
	rebirthCard.Count.Text = tostring(rebirths)
	local multNow, multNext = Config.GetCoinMultiplier(rebirths), Config.GetCoinMultiplier(rebirths + 1)
	rebirthCard.Summary.Text = `Coins x{string.format("%g", multNow)}  ->  x{string.format("%g", multNext)}`
	rebirthCard.Frame.LayoutOrder = if ready then 0 else 200 -- on top when you can do it
	if os.clock() >= confirmUntil then
		rebirthCard.Face.Text = if ready then "REBIRTH" else reason or ""
		Ui.setButtonColor(
			rebirthCard.Button,
			if ready then P.Gold else P.ButtonOff,
			if ready then Color3.fromRGB(190, 140, 30) else P.ButtonOffDark
		)
	end
	for upgradeId, card in cards do
		local upgrade = Config.Upgrades[upgradeId]
		local level = Config.GetLevel(state.Upgrades, upgradeId)
		local entry = Config.GetLevelEntry(upgradeId, level)
		local nextEntry = upgrade.Levels[level + 1]
		card.Level.Text = if #upgrade.Levels > 1 then `Lv {level}` else (if level > 0 then "OK" else "-")
		for i, pip in card.Pips do
			pip.BackgroundColor3 = if i <= level then upgrade.Color else P.ButtonOff
		end
		local now = if entry then entry.Summary else upgrade.BaseSummary
		card.Summary.Text = if nextEntry then `{now}  ->  {nextEntry.Summary}` else now

		-- finished upgrades sink to the bottom, so what you can still buy is always on top
		card.Frame.LayoutOrder = card.Order + (if nextEntry then 0 else 100)
		if not nextEntry then
			card.BuyFace.Text = "MAXED"
			Ui.setButtonColor(card.Buy, P.Gold, Color3.fromRGB(190, 140, 30))
		elseif not Config.IsUpgradeAvailable(state.Upgrades, upgradeId) then
			local required = Config.Upgrades[upgrade.Requires or ""]
			card.BuyFace.Text = if required then `Needs {required.DisplayName}` else "Locked"
			Ui.setButtonColor(card.Buy, P.ButtonOff, P.ButtonOffDark)
		else
			card.BuyFace.Text = `{Config.FormatNumber(nextEntry.Cost)} coins`
			if state.Coins >= nextEntry.Cost then
				Ui.setButtonColor(card.Buy, P.Button, P.ButtonDark)
			else
				Ui.setButtonColor(card.Buy, P.ButtonOff, P.ButtonOffDark)
			end
		end
	end
end

function UpgradesPanel.SetOpen(open: boolean)
	panel.Visible = open
	if open then
		Ui.pop(panel, 0.06)
	end
end

function UpgradesPanel.IsOpen(): boolean
	return panel.Visible
end

-- Flash a card after buying it.
function UpgradesPanel.Flash(upgradeId: string)
	local card = cards[upgradeId]
	if card then
		Ui.pop(card.Buy, 0.2)
	end
end

return UpgradesPanel
