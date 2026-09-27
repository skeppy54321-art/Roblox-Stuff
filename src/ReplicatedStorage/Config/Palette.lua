--!strict
-- Palette (ModuleScript) — ReplicatedStorage.Config.Palette
-- Shared colors so the world and the UI look like one set.
-- Cozy magic market: warm wood, cream plaster, rose + gold accents, glowing potions.

local rgb = Color3.fromRGB

local Palette = {
	-- Wood + stone
	Floor = rgb(196, 150, 100),
	Wood = rgb(150, 98, 58),
	DarkWood = rgb(96, 60, 36),
	LightWood = rgb(214, 170, 118),
	Plaster = rgb(250, 232, 205),
	Stone = rgb(176, 164, 150),
	DarkStone = rgb(120, 110, 104),
	Cobble = rgb(186, 170, 150),
	Roof = rgb(170, 70, 80),

	-- Nature
	Grass = rgb(118, 176, 86),
	Leaf = rgb(70, 150, 80),
	LeafLight = rgb(120, 190, 90),
	LeafDark = rgb(45, 110, 70),
	Trunk = rgb(110, 76, 50),
	Dirt = rgb(110, 80, 60),
	Stem = rgb(240, 230, 210),
	Water = rgb(90, 210, 230),

	-- Shop
	AwningA = rgb(225, 80, 110),
	AwningB = rgb(255, 236, 200),
	-- Each shop in the ring gets its own awning stripes, so you can spot yours
	-- (owners can pick any of them with Shop Colors; ThemeNames go with them, in order).
	Awnings = {
		{ rgb(225, 80, 110), rgb(255, 236, 200) }, -- rose
		{ rgb(60, 165, 185), rgb(232, 250, 245) }, -- teal
		{ rgb(150, 100, 210), rgb(245, 235, 255) }, -- violet
		{ rgb(240, 150, 50), rgb(255, 245, 222) }, -- orange
		{ rgb(80, 165, 90), rgb(240, 255, 232) }, -- green
		{ rgb(75, 125, 220), rgb(235, 242, 255) }, -- blue
	},
	ThemeNames = { "Rose", "Teal", "Violet", "Orange", "Green", "Blue" },
	Cauldron = rgb(45, 45, 58),
	Liquid = rgb(140, 255, 120),
	Fire = rgb(255, 140, 40),
	Gold = rgb(255, 200, 60),
	Lantern = rgb(255, 196, 110),
	Metal = rgb(70, 70, 80),

	-- Customers
	Skin = { rgb(255, 214, 170), rgb(234, 184, 146), rgb(205, 150, 110), rgb(160, 110, 76), rgb(120, 80, 56) },
	Hair = {
		rgb(60, 40, 30),
		rgb(120, 70, 40),
		rgb(230, 190, 110),
		rgb(200, 90, 50),
		rgb(40, 40, 50),
		rgb(230, 230, 235),
	},
	Shirts = {
		rgb(90, 150, 255),
		rgb(255, 170, 60),
		rgb(120, 210, 110),
		rgb(240, 100, 160),
		rgb(160, 110, 240),
		rgb(250, 90, 90),
		rgb(80, 200, 200),
	},
	Pants = { rgb(70, 80, 120), rgb(96, 60, 36), rgb(60, 60, 70), rgb(120, 100, 80) },
	Bottles = {
		rgb(255, 110, 200),
		rgb(110, 200, 255),
		rgb(255, 220, 90),
		rgb(150, 255, 150),
		rgb(190, 120, 255),
	},

	-- UI
	PanelDark = rgb(45, 32, 55),
	PanelMid = rgb(80, 58, 92),
	PanelLight = rgb(255, 244, 222),
	PanelCream = rgb(255, 250, 240),
	TextLight = rgb(255, 255, 255),
	TextDark = rgb(60, 40, 30),
	TextMuted = rgb(140, 115, 100),
	Button = rgb(90, 200, 110),
	ButtonDark = rgb(50, 140, 70),
	ButtonOff = rgb(150, 145, 150),
	ButtonOffDark = rgb(110, 105, 112),
	Danger = rgb(235, 80, 90),
	Good = rgb(90, 220, 120),

	-- Social
	Heart = rgb(255, 95, 150),
	News = rgb(120, 80, 175),
	Medals = { rgb(255, 200, 60), rgb(200, 210, 225), rgb(215, 140, 80) }, -- gold, silver, bronze
}

return Palette
