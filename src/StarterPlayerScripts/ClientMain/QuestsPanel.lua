--!strict
-- QuestsPanel (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.QuestsPanel
-- Today's quests: what to do, a progress bar, the coins each one pays (paid automatically
-- when it's done) and when the next ones come. The server keeps score (QuestService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local P = Config.Palette

export type State = Config.State

type Row = {
	Frame: Frame,
	Title: TextLabel,
	Fill: Frame,
	Count: TextLabel,
	Reward: Frame,
	RewardText: TextLabel,
	Done: TextLabel,
}

local QuestsPanel = {}

QuestsPanel.OnClose = nil :: (() -> ())?

local panel: Frame
local list: Frame
local footer: TextLabel
local rows: { Row } = {}
local shownKey = "" -- which quests the rows were built for

local SYMBOLS: { [string]: { Text: string, Color: Color3 } } = {
	Collect = { Text = "+1", Color = P.Good },
	Speedy = { Text = "!", Color = P.Gold },
	Vip = { Text = "VIP", Color = P.Gold },
	BigOrder = { Text = "x3", Color = Color3.fromRGB(90, 190, 255) },
}

-- A round badge showing what kind of quest it is.
local function icon(quest: Config.Quest): Frame
	local recipe = Config.Recipes[quest.Recipe]
	if quest.Kind == "Sell" or quest.Kind == "Brew" then
		local color = if recipe then recipe.Color elseif quest.Kind == "Brew" then P.Liquid else P.Heart
		return Ui.bottle(color, 34)
	elseif quest.Kind == "Earn" then
		return Ui.coin(44)
	end
	local symbol = SYMBOLS[quest.Kind] or { Text = "?", Color = P.PanelMid }
	local circle = Ui.new("Frame", {
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = symbol.Color,
	}, { Ui.round(), Ui.stroke(P.TextDark, 2) })
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = symbol.Text,
		TextColor3 = P.TextDark,
		Parent = circle,
	}, 22)
	return circle
end

local function lift(gui: GuiObject, by: number)
	gui.ZIndex += by
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += by
		end
	end
end

local function buildRow(quest: Config.Quest, order: number): Row
	local frame = Ui.new("Frame", {
		Name = `Quest{order}`,
		Size = UDim2.new(1, 0, 0, 88),
		BackgroundColor3 = P.PanelCream,
		LayoutOrder = order,
		ZIndex = 10,
		Parent = list,
	}, { Ui.corner(14), Ui.stroke(P.Stone, 2) })
	local badge = icon(quest)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromOffset(40, 44)
	lift(badge, 11)
	badge.Parent = frame
	local title = Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(76, 10),
		Size = UDim2.new(1, -220, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.TextDark,
		Text = Config.DescribeQuest(quest),
		ZIndex = 11,
		Parent = frame,
	}, 24)
	local bar = Ui.new("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(76, 50),
		Size = UDim2.new(1, -220, 0, 20),
		BackgroundColor3 = P.PanelMid,
		ZIndex = 11,
		Parent = frame,
	}, { Ui.round() })
	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = P.Good,
		ZIndex = 12,
		Parent = bar,
	}, { Ui.round() })
	local count = Ui.label({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextStrokeTransparency = 0.4,
		ZIndex = 13,
		Parent = bar,
	}, 16)
	local reward = Ui.new("Frame", {
		Name = "Reward",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(118, 46),
		BackgroundColor3 = P.PanelDark,
		ZIndex = 11,
		Parent = frame,
	}, { Ui.corner(12) })
	local coin = Ui.coin(24)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 10, 0.5, 0)
	lift(coin, 12)
	coin.Parent = reward
	local rewardText = Ui.label({
		Name = "Amount",
		Position = UDim2.fromOffset(40, 8),
		Size = UDim2.new(1, -48, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = P.Gold,
		Text = `+{Config.FormatNumber(quest.Reward)}`,
		ZIndex = 12,
		Parent = reward,
	}, 22)
	local done = Ui.label({
		Name = "Done",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(118, 46),
		BackgroundTransparency = 0,
		BackgroundColor3 = P.ButtonDark,
		Text = "DONE!",
		Visible = false,
		ZIndex = 12,
		Parent = frame,
	}, 22)
	Ui.corner(12).Parent = done
	return {
		Frame = frame,
		Title = title,
		Fill = fill,
		Count = count,
		Reward = reward,
		RewardText = rewardText,
		Done = done,
	}
end

function QuestsPanel.Init(root: Frame)
	local body, close
	panel, body, close =
		Ui.panel(root, "QuestsPanel", "Daily Quests", Vector2.new(600, 430), Color3.fromRGB(240, 130, 60))
	close.Activated:Connect(function()
		if QuestsPanel.OnClose then
			QuestsPanel.OnClose()
		end
	end)
	list = Ui.new("Frame", {
		Name = "List",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 1, -56),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = body,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	footer = Ui.label({
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -40, 0, 30),
		TextColor3 = P.TextMuted,
		Text = "",
		ZIndex = 11,
		Parent = body,
	}, 20)
end

function QuestsPanel.SetState(state: State)
	local quests = state.Quests.List
	local key = tostring(state.Quests.Day)
	for _, quest in quests do
		key ..= `|{quest.Kind}{quest.Recipe}{quest.Need}`
	end
	if key ~= shownKey then
		shownKey = key
		for _, row in rows do
			row.Frame:Destroy()
		end
		rows = {}
		for i, quest in quests do
			table.insert(rows, buildRow(quest, i))
		end
	end
	for i, quest in quests do
		local row = rows[i]
		row.Fill.Size = UDim2.fromScale(math.clamp(quest.Have / quest.Need, 0, 1), 1)
		row.Count.Text = `{Config.FormatNumber(quest.Have)}/{Config.FormatNumber(quest.Need)}`
		row.Reward.Visible = not quest.Done
		row.Done.Visible = quest.Done
		row.Frame.BackgroundColor3 = if quest.Done then Color3.fromRGB(215, 240, 205) else P.PanelCream
	end
end

-- Keeps the "new quests in ..." line current (call once a second).
function QuestsPanel.Tick(now: number)
	footer.Text = `New quests in {Config.FormatDuration(Config.QuestTimeLeft(now))}`
end

function QuestsPanel.SetOpen(open: boolean)
	panel.Visible = open
	if open then
		Ui.pop(panel, 0.06)
	end
end

function QuestsPanel.IsOpen(): boolean
	return panel.Visible
end

return QuestsPanel
