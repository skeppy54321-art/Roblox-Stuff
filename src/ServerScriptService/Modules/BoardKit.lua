--!strict
-- BoardKit (ModuleScript) — ServerScriptService.Modules.BoardKit
-- Little helpers for the notice boards in the plaza (Market Stars, Hall of Fame):
-- building SurfaceGui content from plain property tables.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local P = Config.Palette

local BoardKit = {}

BoardKit.FONT = Enum.Font.FredokaOne

-- Instance.new with properties (Parent is set last).
function BoardKit.New(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

function BoardKit.Corner(parent: Instance, scale: number)
	BoardKit.New("UICorner", { CornerRadius = UDim.new(scale, 0), Parent = parent })
end

-- A transparent, scaled text label (dark text unless TextColor3 is given).
function BoardKit.Text(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = BoardKit.FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or P.TextDark
	props.Parent = parent
	return BoardKit.New("TextLabel", props)
end

-- The board's page: a SurfaceGui on the front of `board` with a cream page and a title bar.
-- Returns the page frame (padded) to put rows into.
function BoardKit.Page(board: BasePart, title: string, pixelsPerStud: number): Frame
	local gui = BoardKit.New("SurfaceGui", {
		Name = "BoardGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = pixelsPerStud,
		LightInfluence = 0,
		Parent = board,
	})
	local page = BoardKit.New("Frame", {
		Name = "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.PanelLight,
		BorderSizePixel = 0,
		Parent = gui,
	})
	BoardKit.New("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		Parent = page,
	})
	local bar = BoardKit.New("Frame", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = P.PanelDark,
		BorderSizePixel = 0,
		Parent = page,
	})
	BoardKit.Corner(bar, 0.3)
	BoardKit.Text(bar, {
		Name = "Label",
		Size = UDim2.fromScale(1, 0.78),
		Position = UDim2.fromScale(0, 0.11),
		Text = title,
		TextColor3 = P.Gold,
	})
	return page
end

return BoardKit
