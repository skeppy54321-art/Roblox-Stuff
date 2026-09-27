--!strict
-- CustomerAnimator (ModuleScript) — StarterPlayer.StarterPlayerScripts.ClientMain.CustomerAnimator
-- Makes customers walk from the plaza to the counter and away again, from the
-- phase/time attributes the server sets (see CustomerService). Only this client's
-- copy moves; the server keeps each customer standing at the counter, so walking
-- costs no network traffic at all.

local RunService = game:GetService("RunService")

-- A posable body: every part's offset from the pivot, and which parts swing.
-- Also used by Townsfolk (width subtyping: an Anim is a Rig with extra fields).
export type Rig = {
	Model: Model,
	Rest: CFrame, -- the pivot the offsets were measured from
	Parts: { BasePart },
	Offsets: { CFrame }, -- each part relative to the pivot
	Swing: { number }, -- 0 = still, 1 = left leg, 2 = right leg, 3 = left arm, 4 = right arm
	Joints: { Vector3 }, -- hip / shoulder each swinging part turns around
}

type Anim = {
	Model: Model,
	Rest: CFrame, -- the customer's pivot standing at the counter (as the server built it)
	Parts: { BasePart },
	Offsets: { CFrame },
	Swing: { number },
	Joints: { Vector3 },
	Phase: string,
	Moved: boolean, -- parts are away from their rest pose
	Seed: number,
}

local CustomerAnimator = {}

local anims: { [Model]: Anim } = {}

local SWING: { [string]: number } =
	{ LegL = 1, ShoeL = 1, LegR = 2, ShoeR = 2, ArmL = 3, HandL = 3, ArmR = 4, HandR = 4 }
local JOINT_X = { -0.5, 0.5, -1.55, 1.55 }
local HIP_Y, SHOULDER_Y = 2.1, 3.9

-- Records where every part sits relative to the rest pivot (again when leaving,
-- so a giant head, a frog or a tiny customer walks away as it is).
local function capture(anim: Rig)
	local scale = anim.Model:GetScale()
	local parts, offsets, swing, joints = {}, {}, {}, {}
	for _, d in anim.Model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, anim.Rest:ToObjectSpace(d.CFrame))
			local kind = if d.Parent == anim.Model then SWING[d.Name] or 0 else 0
			table.insert(swing, kind)
			local joint = if kind == 0
				then Vector3.zero
				else Vector3.new(JOINT_X[kind], if kind <= 2 then HIP_Y else SHOULDER_Y, 0)
			table.insert(joints, joint * scale)
		end
	end
	anim.Parts, anim.Offsets, anim.Swing, anim.Joints = parts, offsets, swing, joints
end

local function pose(anim: Rig, pivot: CFrame, stride: number)
	local cframes = table.create(#anim.Parts)
	for i, offset in anim.Offsets do
		local kind = anim.Swing[i]
		if kind ~= 0 and stride ~= 0 then
			local angle = if kind == 1 or kind == 4 then stride else -stride
			if kind >= 3 then
				angle *= 0.7
			end
			local joint = anim.Joints[i]
			offset = CFrame.new(joint) * CFrame.Angles(angle, 0, 0) * CFrame.new(-joint) * offset
		end
		cframes[i] = pivot * offset
	end
	workspace:BulkMoveTo(anim.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function number(model: Model, name: string): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function update(anim: Anim, now: number)
	local model = anim.Model
	local phaseValue = model:GetAttribute("Phase")
	local phase = if typeof(phaseValue) == "string" then phaseValue else "Waiting"
	if phase ~= anim.Phase then
		if anim.Phase == "Reacting" and phase ~= "Leaving" then
			return -- frozen for an effect (Freeze) until the server says they're leaving
		end
		if anim.Moved then
			pose(anim, anim.Rest, 0)
			anim.Moved = false
		end
		if phase == "Leaving" then
			capture(anim)
		end
		anim.Phase = phase
	end

	if phase == "Arriving" or phase == "Leaving" then
		local from = model:GetAttribute("WalkFrom")
		if typeof(from) ~= "Vector3" then
			return
		end
		local start, finish = number(model, "PhaseStart"), number(model, "PhaseEnd")
		local t = if finish > start then math.clamp((now - start) / (finish - start), 0, 1) else 1
		local restPos = anim.Rest.Position
		local a, b = if phase == "Arriving" then from else restPos, if phase == "Arriving" then restPos else from
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if flat.Magnitude < 0.01 then
			return
		end
		local position = a:Lerp(b, t)
		local travelled = (b - a).Magnitude * t
		local stride = if t < 1 then math.sin(travelled * 1.4) * math.rad(32) else 0
		local bob = if t < 1 then math.abs(math.sin(travelled * 1.4)) * 0.12 else 0
		pose(anim, CFrame.lookAt(position, position + flat.Unit) + Vector3.new(0, bob, 0), stride)
		anim.Moved = true
	elseif phase == "Waiting" then
		-- a gentle idle bob while they wait for their potion
		local bob = math.sin(now * 2.2 + anim.Seed) * 0.05
		pose(anim, anim.Rest + Vector3.new(0, bob, 0), 0)
		anim.Moved = true
	end
	-- "Reacting": the potion effect is in control; leave the parts alone.
end

-- A rig for any customer-built body (legs and arms swing with `stride`).
function CustomerAnimator.NewRig(model: Model): Rig
	local rig: Rig = { Model = model, Rest = model:GetPivot(), Parts = {}, Offsets = {}, Swing = {}, Joints = {} }
	capture(rig)
	return rig
end

-- Moves the whole rig to `pivot`, legs and arms swung by `stride` (radians, 0 = standing).
function CustomerAnimator.PoseRig(rig: Rig, pivot: CFrame, stride: number)
	pose(rig, pivot, stride)
end

-- Start animating a customer model (call as soon as it appears).
function CustomerAnimator.Track(model: Model)
	if anims[model] then
		return
	end
	local anim: Anim = {
		Model = model,
		Rest = model:GetPivot(),
		Parts = {},
		Offsets = {},
		Swing = {},
		Joints = {},
		Phase = "",
		Moved = false,
		Seed = math.random() * 10,
	}
	capture(anim)
	anims[model] = anim
	update(anim, workspace:GetServerTimeNow()) -- move it to the right spot before it's ever drawn
	model.Destroying:Connect(function()
		anims[model] = nil
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			anims[model] = nil
		end
	end)
end

-- A potion effect is about to play: put the customer back in their rest pose now and
-- leave them alone until they start walking away (the effect is in control until then).
function CustomerAnimator.Freeze(model: Model)
	local anim = anims[model]
	if not anim then
		return
	end
	if anim.Moved then
		pose(anim, anim.Rest, 0)
		anim.Moved = false
	end
	anim.Phase = "Reacting"
end

-- Watches a plot for customers arriving.
function CustomerAnimator.WatchPlot(plot: Instance)
	local function onChild(child: Instance)
		if child.Name == "Customer" and child:IsA("Model") then
			child:WaitForChild("Torso", 3)
			CustomerAnimator.Track(child)
		end
	end
	plot.ChildAdded:Connect(onChild)
	for _, child in plot:GetChildren() do
		task.spawn(onChild, child)
	end
end

function CustomerAnimator.Init()
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, anim in anims do
			update(anim, now)
		end
	end)
end

return CustomerAnimator
