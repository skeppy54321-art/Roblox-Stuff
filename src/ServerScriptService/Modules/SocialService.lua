--!strict
-- SocialService (ModuleScript) — ServerScriptService.Modules.SocialService
-- What players see of each other: Coins and Sold in the player list (leaderstats),
-- market news, cheering for someone else's shop, and the Market Stars board in the
-- plaza. Nothing here can change anyone's coins.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Guard = require(Modules:WaitForChild("Guard"))
local Net = require(Modules:WaitForChild("Net"))
local PlotService = require(Modules:WaitForChild("PlotService"))

type Plot = PlotService.Plot
type Data = PlayerData.Data

local P = Config.Palette
local S = Config.Tuning.Social
local FONT = Enum.Font.FredokaOne

local SocialService = {}

local cheered: { [Player]: { [number]: boolean } } = {} -- visitor -> owner user ids cheered this visit
local lastNews: { [Player]: number } = {}
local boardDirty = true

------------------------------------------------------------------
-- Player list
------------------------------------------------------------------

local function intValue(parent: Instance, name: string): IntValue
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent
	return value
end

local function updateLeaderstats(player: Player, data: Data)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "leaderstats"
		intValue(newFolder, "Coins")
		intValue(newFolder, "Sold")
		newFolder.Parent = player
		folder = newFolder
	end
	assert(folder, "leaderstats")
	intValue(folder, "Coins").Value = data.Coins
	intValue(folder, "Sold").Value = data.Stats.PotionsSold or 0
end

------------------------------------------------------------------
-- Cheers
------------------------------------------------------------------

local function cheerText(count: number): string
	return if count == 1 then "1 cheer" else `{Config.FormatNumber(count)} cheers`
end

local function setCheerCount(plot: Plot, count: number)
	local label = plot.CheerStand:FindFirstChild("CountLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = cheerText(count)
	end
end

local function setCheerPrompt(plot: Plot, ownerName: string?)
	local prompt = plot.CheerStand:FindFirstChild("CheerPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ObjectText = if ownerName then `{ownerName}'s shop` else "Empty shop"
	end
end

local function burstHearts(plot: Plot)
	local hearts = plot.CheerStand:FindFirstChild("Hearts", true)
	if hearts and hearts:IsA("ParticleEmitter") then
		hearts.Enabled = true -- a property change reaches every client, so everyone sees the burst
		task.delay(0.45, function()
			hearts.Enabled = false
		end)
	end
end

local function onCheer(visitor: Player, plot: Plot)
	local owner = PlotService.GetOwner(plot)
	if not owner or owner == visitor then
		return
	end
	if not Guard.Cooldown(visitor, "Cheer", S.CheerCooldown) then
		return
	end
	local hitbox = plot.CheerStand:FindFirstChild("Hitbox")
	if not Guard.Near(visitor, if hitbox and hitbox:IsA("BasePart") then hitbox else nil) then
		return
	end
	local done = cheered[visitor]
	if done and done[owner.UserId] then
		Net.Notify(visitor, `You already cheered for {owner.DisplayName}'s shop!`)
		return
	end
	local data = PlayerData.Get(owner)
	if not data then
		return
	end

	-- All checks passed.
	if not done then
		done = {}
		cheered[visitor] = done
	end
	assert(done, "cheered")
	done[owner.UserId] = true
	PlayerData.AddStat(data, "Cheers", 1)
	setCheerCount(plot, data.Stats.Cheers or 0)
	burstHearts(plot)
	PlayerData.Push(owner)
	Net.Cue(owner, "Cheered", { From = visitor.DisplayName })
	Net.Cue(visitor, "CheerSent", { To = owner.DisplayName })
end

------------------------------------------------------------------
-- Market news
------------------------------------------------------------------

-- Tells everyone else in the market about something `player` did.
function SocialService.Announce(player: Player, text: string)
	local now = os.clock()
	if now - (lastNews[player] or -math.huge) < S.NewsGap then
		return
	end
	lastNews[player] = now
	Net.NotifyOthers(player, text, "news")
end

------------------------------------------------------------------
-- Market Stars board
------------------------------------------------------------------

type Row = {
	Frame: Frame,
	Badge: Frame,
	Rank: TextLabel,
	Name: TextLabel,
	Coins: TextLabel,
	Recipes: TextLabel,
	Cheers: TextLabel,
}

-- The stat columns on each row: where they start and how wide they are (fractions of the board).
local COLUMNS = {
	{ X = 0.5, Width = 0.21, Heading = "coins earned" },
	{ X = 0.72, Width = 0.14, Heading = "recipes" },
	{ X = 0.87, Width = 0.13, Heading = "cheers" },
}

local rows: { Row } = {}
local emptyLabel: TextLabel? = nil

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(parent: Instance, scale: number)
	new("UICorner", { CornerRadius = UDim.new(scale, 0), Parent = parent })
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or P.TextDark
	props.Parent = parent
	return new("TextLabel", props)
end

-- A small icon + number column in a row, starting `x` (scale) across, `width` wide.
local function stat(parent: Instance, name: string, x: number, width: number, icon: Color3, round: boolean): TextLabel
	local dot = new("Frame", {
		Name = name .. "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(x, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = icon,
		BorderSizePixel = 0,
		Parent = parent,
	})
	corner(dot, if round then 0.5 else 0.25)
	return text(parent, {
		Name = name .. "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(x, 24, 0.5, 0),
		Size = UDim2.new(width, -24, 0.62, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function buildBoard(board: BasePart)
	local gui = new("SurfaceGui", {
		Name = "StarsGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0,
		Parent = board,
	})
	local page = new("Frame", {
		Name = "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.PanelLight,
		BorderSizePixel = 0,
		Parent = gui,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		Parent = page,
	})
	local title = new("Frame", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = P.PanelDark,
		BorderSizePixel = 0,
		Parent = page,
	})
	corner(title, 0.3)
	text(title, {
		Name = "Label",
		Size = UDim2.fromScale(1, 0.78),
		Position = UDim2.fromScale(0, 0.11),
		Text = "Market Stars",
		TextColor3 = P.Gold,
	})
	-- column headings
	local heading = new("Frame", {
		Name = "Heading",
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = page,
	})
	for _, column in COLUMNS do
		local label = text(heading, {
			Position = UDim2.fromScale(column.X, 0),
			Size = UDim2.fromScale(column.Width, 1),
			Text = column.Heading,
			TextColor3 = P.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.TextScaled = false
		label.TextSize = 15
	end
	local list = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 1, -114),
		BackgroundTransparency = 1,
		Parent = page,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	for i = 1, Config.World.PlotCount do
		local frame = new("Frame", {
			Name = `Row{i}`,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 37),
			BackgroundColor3 = if i % 2 == 1 then P.PanelCream else P.PanelLight,
			BorderSizePixel = 0,
			Visible = false,
			Parent = list,
		})
		corner(frame, 0.3)
		local medal = P.Medals[i]
		local badge = new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(31, 31),
			BackgroundColor3 = medal or P.PanelMid,
			BorderSizePixel = 0,
			Parent = frame,
		})
		corner(badge, 0.5)
		local rank = text(badge, {
			Name = "Rank",
			Size = UDim2.fromScale(1, 0.72),
			Position = UDim2.fromScale(0, 0.14),
			Text = tostring(i),
			TextColor3 = if medal then P.TextDark else P.TextLight,
		})
		local name = text(frame, {
			Name = "PlayerName",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 44, 0.5, 0),
			Size = UDim2.new(COLUMNS[1].X, -50, 0.66, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		table.insert(rows, {
			Frame = frame,
			Badge = badge,
			Rank = rank,
			Name = name,
			Coins = stat(frame, "Coins", COLUMNS[1].X, COLUMNS[1].Width, P.Gold, true),
			Recipes = stat(frame, "Recipes", COLUMNS[2].X, COLUMNS[2].Width, P.Bottles[5], false),
			Cheers = stat(frame, "Cheers", COLUMNS[3].X, COLUMNS[3].Width, P.Heart, true),
		})
	end
	local tip = text(page, {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Visit a friend's shop and press the pink heart to cheer!",
		TextColor3 = P.TextMuted,
	})
	tip.TextScaled = false
	tip.TextSize = 17
	emptyLabel = text(list, {
		Name = "Empty",
		LayoutOrder = 99,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "Open a shop to be a star!",
		TextColor3 = P.TextMuted,
	})
end

type Entry = { Name: string, Earned: number, Recipes: number, Cheers: number }

local function redrawBoard()
	local entries: { Entry } = {}
	for _, plot in PlotService.GetPlots() do
		local owner = PlotService.GetOwner(plot)
		local data = if owner then PlayerData.Get(owner) else nil
		if owner and data then
			local recipes = 0
			for _ in data.Discovered do
				recipes += 1
			end
			table.insert(entries, {
				Name = owner.DisplayName,
				Earned = data.Stats.CoinsEarned or 0,
				Recipes = recipes,
				Cheers = data.Stats.Cheers or 0,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.Earned ~= b.Earned then
			return a.Earned > b.Earned
		end
		return a.Name < b.Name
	end)
	local total = #Config.RecipeOrder
	for i, row in rows do
		local entry = entries[i]
		row.Frame.Visible = entry ~= nil
		if entry then
			row.Name.Text = entry.Name
			row.Coins.Text = Config.FormatNumber(entry.Earned)
			row.Recipes.Text = `{entry.Recipes}/{total}`
			row.Cheers.Text = Config.FormatNumber(entry.Cheers)
		end
	end
	local empty = emptyLabel
	if empty then
		empty.Visible = #entries == 0
	end
end

------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------

function SocialService.Init(plots: { Plot })
	for _, plot in plots do
		setCheerCount(plot, 0)
		setCheerPrompt(plot, nil)
		local prompt = plot.CheerStand:FindFirstChild("CheerPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onCheer(player, plot)
			end)
		end
	end
	buildBoard(PlotService.GetMarket().Board)
	redrawBoard()
	task.spawn(function()
		while true do
			task.wait(S.BoardRefreshSeconds)
			if boardDirty then
				boardDirty = false
				local ok, err = pcall(function(): any
					redrawBoard()
					return nil
				end)
				if not ok then
					warn("[SocialService] board redraw failed:", err)
				end
			end
		end
	end)
end

-- After the player's data loaded and they got a shop (plot may be nil if the market is full).
function SocialService.PlayerJoined(player: Player, data: Data, plot: Plot?)
	updateLeaderstats(player, data)
	if plot then
		setCheerCount(plot, data.Stats.Cheers or 0)
		setCheerPrompt(plot, player.DisplayName)
	end
	boardDirty = true
end

-- Every time the player's data changes.
function SocialService.Update(player: Player, data: Data)
	updateLeaderstats(player, data)
	boardDirty = true
end

-- Before the player's shop is released.
function SocialService.PlayerLeft(player: Player, plot: Plot?)
	if plot then
		setCheerCount(plot, 0)
		setCheerPrompt(plot, nil)
	end
	cheered[player] = nil
	lastNews[player] = nil
	boardDirty = true
end

-- For tests: redraw the board right now.
function SocialService.RedrawBoard()
	boardDirty = false
	redrawBoard()
end

return SocialService
