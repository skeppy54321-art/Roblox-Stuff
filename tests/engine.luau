--!nocheck
-- engine.luau: the fake Roblox engine pieces the game's scripts need, on top of Lune's
-- @lune/roblox instance model. Loads a real place file and runs its scripts unmodified.

local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Engine = {}

function Engine.traceback(err)
	return debug.traceback(tostring(err), 2)
end

Engine.problems = {}
Engine.warnings = {}
Engine.log = {} -- remote traffic: { remote, method, args }

function Engine.problem(msg)
	table.insert(Engine.problems, msg)
	print("PROBLEM: " .. msg)
end

------------------------------------------------------------------
-- Signals
------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new(name)
	return setmetatable({ Name = name, Conns = {} }, Signal)
end

function Signal:Connect(fn)
	local conn = { Connected = true, Fn = fn }
	function conn:Disconnect()
		self.Connected = false
	end
	table.insert(self.Conns, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	local args = table.pack(...)
	for _, conn in table.clone(self.Conns) do
		if conn.Connected then
			task.spawn(function()
				local ok, err = xpcall(conn.Fn, Engine.traceback, table.unpack(args, 1, args.n))
				if not ok then
					Engine.problem(`error in {self.Name} handler: {err}`)
				end
			end)
		end
	end
end

Engine.Signal = Signal

local signals = {}
function Engine.signal(inst, name)
	local byName = signals[inst]
	if not byName then
		byName = {}
		signals[inst] = byName
	end
	local s = byName[name]
	if not s then
		s = Signal.new(`{inst.Name}.{name}`)
		byName[name] = s
	end
	return s
end

------------------------------------------------------------------
-- CFrame with Roblox's lookAt (Lune's points away from the target)
------------------------------------------------------------------
local function lookAt(at, target, up)
	up = up or roblox.Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	if math.abs(look:Dot(up)) > 0.999 then
		up = roblox.Vector3.new(0, 0, 1)
	end
	local right = look:Cross(up).Unit
	local newUp = right:Cross(look)
	return roblox.CFrame.fromMatrix(at, right, newUp, -look)
end
Engine.CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })

------------------------------------------------------------------
-- Clock (server time)
------------------------------------------------------------------
local startClock = os.clock()
function Engine.now()
	return 1000 + (os.clock() - startClock)
end

------------------------------------------------------------------
-- Random
------------------------------------------------------------------
local Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor((seed or os.clock() * 1e6 + math.random() * 1e6)) % 2147483646 + 1
	return setmetatable({ state = s }, Random)
end
function Random:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local r = self.state / 2147483647
	if min then
		return min + (max - min) * r
	end
	return r
end
function Random:NextInteger(min, max)
	local v = math.floor(self:NextNumber(min, max + 1))
	return math.clamp(v, min, max)
end
Engine.Random = Random

------------------------------------------------------------------
-- Lune stores Position separately from CFrame: keep them in sync
------------------------------------------------------------------
function Engine.setCFrame(part, cf)
	part.CFrame = cf
	part.Position = cf.Position
end

function Engine.syncPositions(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			pcall(function()
				d.Position = d.CFrame.Position
			end)
		end
	end
end

------------------------------------------------------------------
-- Engine methods/properties Lune doesn't have
------------------------------------------------------------------
local implemented = false
function Engine.install(game, options)
	if implemented then
		return
	end
	implemented = true
	local isClient = options and options.client

	local eventNames = {
		"ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged",
		"Destroying", "Changed", "AttributeChanged",
	}
	for _, name in eventNames do
		roblox.implementProperty("Instance", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	roblox.implementMethod("Instance", "WaitForChild", function(inst, name, timeout)
		local child = inst:FindFirstChild(name)
		if not child then
			if timeout then
				return nil
			end
			error(`WaitForChild would wait forever: {inst:GetFullName()}.{name}`)
		end
		return child
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(inst, prop)
		return Engine.signal(inst, "Prop:" .. prop)
	end)
	roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(inst, attr)
		return Engine.signal(inst, "Attr:" .. attr)
	end)

	-- ProximityPrompt
	for _, name in { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded" } do
		roblox.implementProperty("ProximityPrompt", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	roblox.implementMethod("ProximityPrompt", "InputHoldBegin", function() end)
	roblox.implementMethod("ProximityPrompt", "InputHoldEnd", function() end)

	-- Remotes
	for _, name in { "OnServerEvent", "OnClientEvent" } do
		roblox.implementProperty("RemoteEvent", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	roblox.implementMethod("RemoteEvent", "FireClient", function(inst, player, ...)
		table.insert(Engine.log, { remote = inst.Name, method = "FireClient", player = player, args = table.pack(...) })
		if isClient then
			Engine.signal(inst, "OnClientEvent"):Fire(...)
		end
	end)
	roblox.implementMethod("RemoteEvent", "FireAllClients", function(inst, ...)
		table.insert(Engine.log, { remote = inst.Name, method = "FireAllClients", args = table.pack(...) })
		if isClient then
			Engine.signal(inst, "OnClientEvent"):Fire(...)
		end
	end)
	roblox.implementMethod("RemoteEvent", "FireServer", function(inst, ...)
		table.insert(Engine.log, { remote = inst.Name, method = "FireServer", args = table.pack(...) })
		if isClient and Engine.localPlayer then
			Engine.signal(inst, "OnServerEvent"):Fire(Engine.localPlayer, ...)
		end
	end)
	local callbacks = {}
	roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(inst)
		return callbacks[inst]
	end, function(inst, fn)
		callbacks[inst] = fn
	end)
	roblox.implementMethod("RemoteFunction", "InvokeServer", function(inst, ...)
		local fn = callbacks[inst]
		if fn and Engine.localPlayer then
			return fn(Engine.localPlayer, ...)
		end
		return nil
	end)
	function Engine.getServerInvoke(inst)
		return callbacks[inst]
	end

	-- Players
	roblox.implementProperty("Players", "PlayerAdded", function(inst)
		return Engine.signal(inst, "PlayerAdded")
	end)
	roblox.implementProperty("Players", "PlayerRemoving", function(inst)
		return Engine.signal(inst, "PlayerRemoving")
	end)
	roblox.implementMethod("Players", "GetPlayers", function(inst)
		local list = {}
		for _, child in inst:GetChildren() do
			if child:IsA("Player") then
				table.insert(list, child)
			end
		end
		return list
	end)
	roblox.implementMethod("Players", "GetPlayerByUserId", function(inst, userId)
		for _, child in inst:GetChildren() do
			if child:IsA("Player") and child.UserId == userId then
				return child
			end
		end
		return nil
	end)
	roblox.implementProperty("Players", "LocalPlayer", function()
		return Engine.localPlayer
	end)
	roblox.implementProperty("Player", "CharacterAdded", function(inst)
		return Engine.signal(inst, "CharacterAdded")
	end)
	roblox.implementMethod("Player", "Kick", function(inst, message)
		Engine.problem(`{inst.Name} was kicked: {message}`)
	end)

	-- Models / pivots
	local pivots = {}
	local scales = {}
	local function offsetOf(part)
		local ok, offset = pcall(function()
			return part.PivotOffset
		end)
		return if ok and offset then offset else roblox.CFrame.new()
	end
	-- Roblox turns "model.WorldPivot = x" on a model with a PrimaryPart into the PrimaryPart's
	-- PivotOffset. Lune just stores it, so work the offset out once, before anything moves.
	local modelOffsets = {}
	local function getPivot(model)
		if model.PrimaryPart then
			local offset = modelOffsets[model]
			if not offset then
				local ok, stored = pcall(function()
					return model.WorldPivot
				end)
				if ok and stored and stored.Position.Magnitude > 1e-4 then
					offset = model.PrimaryPart.CFrame:ToObjectSpace(stored)
				else
					offset = offsetOf(model.PrimaryPart)
				end
				modelOffsets[model] = offset
			end
			return model.PrimaryPart.CFrame * offset
		end
		if pivots[model] then
			return pivots[model]
		end
		local ok, pivot = pcall(function()
			return model.WorldPivot
		end)
		if ok and pivot then
			return pivot
		end
		return roblox.CFrame.new()
	end
	roblox.implementMethod("Model", "GetPivot", getPivot)
	roblox.implementMethod("BasePart", "GetPivot", function(part)
		return part.CFrame * offsetOf(part)
	end)
	local function movePartsBy(model, delta)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				Engine.setCFrame(d, delta * d.CFrame)
			elseif d:IsA("Model") and pivots[d] then
				pivots[d] = delta * pivots[d]
			end
		end
	end
	roblox.implementMethod("Model", "PivotTo", function(model, target)
		local current = getPivot(model)
		local delta = target * current:Inverse()
		movePartsBy(model, delta)
		if not model.PrimaryPart then
			pivots[model] = target
		end
	end)
	roblox.implementMethod("Model", "GetScale", function(model)
		return scales[model] or 1
	end)
	roblox.implementMethod("Model", "ScaleTo", function(model, newScale)
		local old = scales[model] or 1
		local factor = newScale / old
		local pivot = getPivot(model)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.Size = d.Size * factor
				Engine.setCFrame(d, pivot * (rel - rel.Position + rel.Position * factor))
			end
		end
		scales[model] = newScale
	end)

	-- Workspace
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return Engine.now()
	end)
	roblox.implementMethod("Workspace", "BulkMoveTo", function(_, parts, cframes)
		for i, part in parts do
			Engine.setCFrame(part, cframes[i])
		end
	end)
	roblox.implementProperty("Workspace", "Terrain", function(ws)
		local terrain = ws:FindFirstChildOfClass("Terrain")
		if not terrain then
			terrain = roblox.Instance.new("Terrain")
			terrain.Parent = ws
		end
		return terrain
	end)
	roblox.implementProperty("Workspace", "CurrentCamera", function(ws)
		local camera = ws:FindFirstChildOfClass("Camera")
		if not camera then
			camera = roblox.Instance.new("Camera")
			camera.Parent = ws
		end
		return camera
	end)
	roblox.implementProperty("Camera", "ViewportSize", function()
		return Engine.viewport or roblox.Vector2.new(844, 390)
	end)

	-- DataModel
	pcall(function()
		game.PlaceId = 0
	end)
	pcall(function()
		game.JobId = "harness-job"
	end)
	roblox.implementMethod("DataModel", "BindToClose", function(_, fn)
		Engine.onClose = fn
	end)
	roblox.implementProperty("DataModel", "JobId", function()
		return "harness-job"
	end)
	roblox.implementProperty("DataModel", "PlaceId", function()
		return 0
	end)

	-- Services
	roblox.implementMethod("RunService", "IsStudio", function()
		return true
	end)
	roblox.implementMethod("RunService", "IsServer", function()
		return not isClient
	end)
	roblox.implementMethod("RunService", "IsClient", function()
		return isClient == true
	end)
	for _, name in { "Heartbeat", "RenderStepped", "Stepped" } do
		roblox.implementProperty("RunService", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	roblox.implementMethod("DataStoreService", "GetDataStore", function()
		return {
			SetAsync = function()
				error("You must publish this place to the web to access DataStore.")
			end,
			GetAsync = function()
				error("You must publish this place to the web to access DataStore.")
			end,
			UpdateAsync = function()
				error("You must publish this place to the web to access DataStore.")
			end,
		}
	end)
	roblox.implementMethod("HttpService", "GenerateGUID", function()
		return string.format("%08x-%04x", math.random(0, 0x7fffffff), math.random(0, 0xffff))
	end)
	roblox.implementMethod("MessagingService", "SubscribeAsync", function()
		return { Disconnect = function() end }
	end)
	roblox.implementMethod("MessagingService", "PublishAsync", function() end)
	roblox.implementMethod("ParticleEmitter", "Emit", function() end)

	-- GUI input events
	for _, name in { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click" } do
		roblox.implementProperty("GuiButton", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	for _, name in { "InputBegan", "InputEnded", "InputChanged", "MouseEnter", "MouseLeave" } do
		roblox.implementProperty("GuiObject", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	-- Sounds
	roblox.implementProperty("Sound", "Ended", function(inst)
		return Engine.signal(inst, "Ended")
	end)
	for _, name in { "Play", "Pause", "Resume", "Stop" } do
		roblox.implementMethod("Sound", name, function() end)
	end
	roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
	-- Input services
	for _, name in { "InputBegan", "InputEnded", "InputChanged" } do
		roblox.implementProperty("UserInputService", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	roblox.implementMethod("UserInputService", "GetStringForKeyCode", function(_, keyCode)
		return keyCode.Name
	end)
	for _, name in { "PromptShown", "PromptHidden", "PromptTriggered", "PromptTriggerEnded" } do
		roblox.implementProperty("ProximityPromptService", name, function(inst)
			return Engine.signal(inst, name)
		end)
	end
	-- Tweens jump to their goal after the tween time and fire Completed
	roblox.implementMethod("TweenService", "Create", function(_, inst, info, goals)
		local tween = { Completed = Signal.new("Tween.Completed"), cancelled = false }
		function tween.Play(self)
			task.delay(info.Time or 0, function()
				if self.cancelled or not inst.Parent and not inst:IsA("NumberValue") then
					return
				end
				for key, value in goals do
					inst[key] = value
					if key == "Value" then
						Engine.signal(inst, "Changed"):Fire(value)
					end
				end
				self.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function tween.Cancel(self)
			self.cancelled = true
		end
		function tween.Pause() end
		return tween
	end)
	roblox.implementMethod("DataStoreOptions", "SetExperimentalFeatures", function() end)
	roblox.implementMethod("Debris", "AddItem", function(_, item, seconds)
		task.delay(seconds or 10, function()
			pcall(function()
				item:Destroy()
			end)
		end)
	end)
end

------------------------------------------------------------------
-- Running scripts
------------------------------------------------------------------
local moduleCache = {}
local loading = {}

function Engine.makeEnv(game, scriptInstance)
	local env = {
		script = scriptInstance,
		game = game,
		workspace = game:GetService("Workspace"),
		require = Engine.require,
		Instance = roblox.Instance,
		Enum = roblox.Enum,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = Engine.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		BrickColor = roblox.BrickColor,
		Rect = roblox.Rect,
		Font = roblox.Font,
		Random = Random,
		TweenInfo = Engine.TweenInfo,
		task = task,
		typeof = typeof,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			local msg = table.concat(parts, " ")
			table.insert(Engine.warnings, msg)
			print("WARN: " .. msg)
		end,
		tick = os.clock,
	}
	return setmetatable(env, { __index = _G })
end

function Engine.require(target)
	if typeof(target) ~= "Instance" or not target:IsA("ModuleScript") then
		error("require expects a ModuleScript, got " .. typeof(target))
	end
	local cached = moduleCache[target]
	if cached then
		return cached.value
	end
	if loading[target] then
		error("circular require: " .. target:GetFullName())
	end
	loading[target] = true
	local fn = luau.load(target.Source, {
		debugName = target:GetFullName(),
		environment = Engine.makeEnv(Engine.game, target),
		injectGlobals = true,
	})
	local value = fn()
	loading[target] = nil
	moduleCache[target] = { value = value }
	return value
end

function Engine.run(scriptInstance)
	local fn = luau.load(scriptInstance.Source, {
		debugName = scriptInstance:GetFullName(),
		environment = Engine.makeEnv(Engine.game, scriptInstance),
		injectGlobals = true,
	})
	task.spawn(function()
		local ok, err = xpcall(fn, Engine.traceback)
		if not ok then
			Engine.problem(`script {scriptInstance:GetFullName()} errored: {err}`)
		end
	end)
end

function Engine.loaded(moduleScript)
	local cached = moduleCache[moduleScript]
	return cached and cached.value
end

------------------------------------------------------------------
-- TweenInfo placeholder (server code doesn't tween; the client harness replaces it)
------------------------------------------------------------------
Engine.TweenInfo = {
	new = function(time, style, direction)
		return { Time = time or 1, EasingStyle = style, EasingDirection = direction }
	end,
}

------------------------------------------------------------------
-- Dump every visible part (for the 3D preview)
------------------------------------------------------------------
function Engine.dumpParts(root)
	local parts = {}
	local lights = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Terrain") then
			local kind = "Block"
			if d:IsA("WedgePart") then
				kind = "Wedge"
			elseif d:IsA("Part") then
				kind = d.Shape.Name
			end
			local c = d.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			table.insert(parts, {
				k = kind,
				s = { d.Size.X, d.Size.Y, d.Size.Z },
				r = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				c = { d.Color.R, d.Color.G, d.Color.B },
				m = d.Material.Name,
				t = d.Transparency,
				sh = d.CastShadow,
				n = d.Name,
			})
		elseif d:IsA("PointLight") and d.Parent and d.Parent:IsA("BasePart") then
			local p = d.Parent.CFrame.Position
			table.insert(lights, { p = { p.X, p.Y, p.Z }, c = { d.Color.R, d.Color.G, d.Color.B }, b = d.Brightness, r = d.Range })
		end
	end
	return parts, lights
end

return Engine
