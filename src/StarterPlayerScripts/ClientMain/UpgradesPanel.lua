--!strict
-- UpgradesPanel (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.UpgradesPanel
-- A scrollable list of upgrade cards. Pressing Buy only ASKS the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

export type State = Config.State

type Card = {
	Level: TextLabel,
	Summary: TextLabel,
	Pips: { Frame },
	Buy: Frame,
	BuyFace: TextButton,
}

local UpgradesPanel = {}

UpgradesPanel.OnBuy = nil :: ((upgradeId: string) -> ())?
UpgradesPanel.OnClose = nil :: (() -> ())?

local panel: Frame
local cards: { [string]: Card } = {}

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
		cards[upgradeId] = { Level = levelLabel, Summary = summary, Pips = pips, Buy = buy, BuyFace = buyFace }
	end
end

function UpgradesPanel.SetState(state: State)
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
