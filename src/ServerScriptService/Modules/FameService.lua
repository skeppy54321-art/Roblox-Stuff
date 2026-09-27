--!strict
-- FameService (ModuleScript) — ServerScriptService.Modules.FameService
-- The Hall of Fame board in the plaza: the top 10 brewers of all time, across every
-- server, by coins earned. Each player's total goes into an OrderedDataStore when they
-- leave and every few minutes while they play; the board reads the top 10 every minute.
-- Everything is best effort: if data stores aren't available (an unpublished place in
-- Studio) the board says so and nothing else is affected.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UserService = game:GetService("UserService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Modules = script.Parent
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local BoardKit = require(Modules:WaitForChild("BoardKit"))

local P = Config.Palette

local STORE_NAME = "HallOfFame_CoinsEarned_v1"
local ROWS = 10
local READ_EVERY = 60 -- seconds between board refreshes
local WRITE_EVERY = 180 -- seconds between saving the totals of everyone playing

local FameService = {}

type Row = { Frame: Frame, Rank: TextLabel, Name: TextLabel, Coins: TextLabel }

local store: OrderedDataStore? = nil
local rows: { Row } = {}
local note: TextLabel? = nil
local names: { [number]: string } = {}
local lastSaved: { [number]: number } = {}

------------------------------------------------------------------
-- Board
------------------------------------------------------------------

local function buildBoard(board: BasePart)
	local page = BoardKit.Page(board, "Hall of Fame", 50)
	BoardKit.Text(page, {
		Name = "Subtitle",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Most coins earned, all time, every market",
		TextColor3 = P.TextMuted,
	})
	local list = BoardKit.New("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 1, -90),
		BackgroundTransparency = 1,
		Parent = page,
	})
	BoardKit.New("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	for i = 1, ROWS do
		local frame = BoardKit.New("Frame", {
			Name = `Row{i}`,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 29),
			BackgroundColor3 = if i % 2 == 1 then P.PanelCream else P.PanelLight,
			BorderSizePixel = 0,
			Visible = false,
			Parent = list,
		})
		BoardKit.Corner(frame, 0.3)
		local medal = P.Medals[i]
		local badge = BoardKit.New("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(25, 25),
			BackgroundColor3 = medal or P.PanelMid,
			BorderSizePixel = 0,
			Parent = frame,
		})
		BoardKit.Corner(badge, 0.5)
		local rank = BoardKit.Text(badge, {
			Name = "Rank",
			Size = UDim2.fromScale(1, 0.72),
			Position = UDim2.fromScale(0, 0.14),
			Text = tostring(i),
			TextColor3 = if medal then P.TextDark else P.TextLight,
		})
		local name = BoardKit.Text(frame, {
			Name = "PlayerName",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 36, 0.5, 0),
			Size = UDim2.new(0.62, -40, 0.7, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local coinDot = BoardKit.New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.64, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = P.Gold,
			BorderSizePixel = 0,
			Parent = frame,
		})
		BoardKit.Corner(coinDot, 0.5)
		local coins = BoardKit.Text(frame, {
			Name = "Coins",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.64, 22, 0.5, 0),
			Size = UDim2.new(0.36, -24, 0.7, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		table.insert(rows, { Frame = frame, Rank = rank, Name = name, Coins = coins })
	end
	note = BoardKit.Text(list, {
		Name = "Note",
		LayoutOrder = 99,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "Loading the Hall of Fame...",
		TextColor3 = P.TextMuted,
	})
end

local function setNote(text: string?)
	local label = note
	if label then
		label.Visible = text ~= nil
		label.Text = text or ""
	end
end

------------------------------------------------------------------
-- Names (the store only keeps user ids)
------------------------------------------------------------------

local function resolveNames(userIds: { number })
	local missing: { number } = {}
	for _, id in userIds do
		if not names[id] then
			local online = Players:GetPlayerByUserId(id)
			if online then
				names[id] = online.DisplayName
			else
				table.insert(missing, id)
			end
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function(): any
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos :: { any } do
			if typeof(info) == "table" and typeof(info.Id) == "number" and typeof(info.DisplayName) == "string" then
				names[info.Id] = info.DisplayName
			end
		end
	end
	-- ids still missing (the lookup failed) show as "Brewer <id>" and are tried again next time
end

------------------------------------------------------------------
-- Reading and writing
------------------------------------------------------------------

-- Reads the top 10 and redraws the board. Yields.
function FameService.Refresh()
	local ordered = store
	if not ordered then
		setNote("The Hall of Fame fills up once the game is published.")
		return
	end
	local ok, result = pcall(function(): any
		return ordered:GetSortedAsync(false, ROWS):GetCurrentPage()
	end)
	if not ok or typeof(result) ~= "table" then
		setNote("The Hall of Fame fills up once the game is published.")
		return
	end
	local entries: { { UserId: number, Coins: number } } = {}
	for _, item in result :: { any } do
		local id = tonumber(item.key)
		if id and typeof(item.value) == "number" and item.value > 0 then
			table.insert(entries, { UserId = id, Coins = item.value })
		end
	end
	local ids = {}
	for _, entry in entries do
		table.insert(ids, entry.UserId)
	end
	resolveNames(ids)
	for i, row in rows do
		local entry = entries[i]
		row.Frame.Visible = entry ~= nil
		if entry then
			row.Name.Text = names[entry.UserId] or `Brewer {entry.UserId}`
			row.Coins.Text = Config.FormatNumber(entry.Coins)
		end
	end
	setNote(if #entries == 0 then "Be the first brewer in the Hall of Fame!" else nil)
end

-- Saves one player's all-time coins earned (skipped if unchanged). Yields.
function FameService.Save(player: Player, data: PlayerData.Data?)
	local ordered = store
	if not ordered or not data then
		return
	end
	local earned = math.floor(data.Stats.CoinsEarned or 0)
	if earned <= 0 or lastSaved[player.UserId] == earned then
		return
	end
	local ok = pcall(function(): any
		ordered:SetAsync(tostring(player.UserId), earned)
		return nil
	end)
	if ok then
		lastSaved[player.UserId] = earned
	end
end

function FameService.Init(board: BasePart)
	buildBoard(board)
	local ok, result = pcall(function(): any
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	store = if ok then result else nil
	task.spawn(function()
		task.wait(5)
		local sinceWrite = 0
		while true do
			FameService.Refresh()
			task.wait(READ_EVERY)
			sinceWrite += READ_EVERY
			if sinceWrite >= WRITE_EVERY then
				sinceWrite = 0
				for _, player in Players:GetPlayers() do
					FameService.Save(player, PlayerData.Get(player))
				end
			end
		end
	end)
end

return FameService
