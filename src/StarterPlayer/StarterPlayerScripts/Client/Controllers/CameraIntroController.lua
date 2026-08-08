--!strict
-- Plays the spawn cinematic: a scripted camera sweep across Survivor Haven
-- (Eclipse Core -> skyline -> the 4 gates -> settle behind the player) before
-- handing control back. Waypoints are NOT hardcoded here — they're authored
-- as Parts tagged "CameraWaypoint" (with an "Order" and optional "HoldTime"
-- attribute) placed by the world-build tool / hand-tuned by a builder in
-- Studio, per architecture decision #5. If no waypoints exist yet (fresh
-- place before the world has been built), the intro is skipped entirely.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local WAYPOINT_TAG = "CameraWaypoint"
local DEFAULT_SEGMENT_TIME = 3.25

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera

local CameraIntroController = {}

-- Fired exactly once per client session, the moment the player gets control
-- back (whether the cinematic actually played or was skipped entirely
-- because no CameraWaypoint parts exist yet). SpawnBriefingController is the
-- first consumer — it needs "player has control" as its trigger but this
-- file otherwise has no reason to know that controller exists, so this is a
-- plain Signal + a race-safe flag (same pattern as HUDController.MenuOpenRequested),
-- not a direct dependency in either direction.
CameraIntroController.IntroFinished = Signal.new()
CameraIntroController.HasFinished = false

local function markFinished()
	CameraIntroController.HasFinished = true
	CameraIntroController.IntroFinished:Fire()
end

local function getSortedWaypoints(): { BasePart }
	local waypoints = {}
	for _, inst in CollectionService:GetTagged(WAYPOINT_TAG) do
		if inst:IsA("BasePart") then
			table.insert(waypoints, inst)
		end
	end
	table.sort(waypoints, function(a, b)
		return (a:GetAttribute("Order") :: number? or 0) < (b:GetAttribute("Order") :: number? or 0)
	end)
	return waypoints
end

local function buildSkipUi(): (ScreenGui, () -> (), () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "CinematicIntro"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = Color3.new(0, 0, 0)
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(1, 0, 0, 0)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.Parent = gui

	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
	bottomBar.BorderSizePixel = 0
	bottomBar.Size = UDim2.new(1, 0, 0, 0)
	bottomBar.Position = UDim2.new(0, 0, 1, 0)
	bottomBar.AnchorPoint = Vector2.new(0, 1)
	bottomBar.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0.4, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 42
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 1
	title.Text = "SURVIVOR HAVEN"
	title.Parent = gui

	local skipLabel = Instance.new("TextButton")
	skipLabel.Name = "Skip"
	skipLabel.AnchorPoint = Vector2.new(1, 1)
	skipLabel.Position = UDim2.new(1, -24, 1, -24)
	skipLabel.Size = UDim2.new(0, 140, 0, 36)
	skipLabel.BackgroundTransparency = 1
	skipLabel.Font = Enum.Font.Gotham
	skipLabel.TextSize = 16
	skipLabel.TextColor3 = Color3.new(1, 1, 1)
	skipLabel.TextTransparency = 1
	skipLabel.Text = "Skip ▸"
	skipLabel.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	local function fadeIn()
		TweenService:Create(topBar, TweenInfo.new(0.6), { Size = UDim2.new(1, 0, 0.09, 0) }):Play()
		TweenService:Create(bottomBar, TweenInfo.new(0.6), { Size = UDim2.new(1, 0, 0.09, 0) }):Play()
		TweenService:Create(title, TweenInfo.new(1), { TextTransparency = 0 }):Play()
		TweenService:Create(skipLabel, TweenInfo.new(1), { TextTransparency = 0.3 }):Play()
		task.delay(1.4, function()
			TweenService:Create(title, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		end)
	end

	local function fadeOutAndDestroy()
		TweenService:Create(topBar, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		TweenService:Create(bottomBar, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(skipLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end

	return gui, fadeIn, fadeOutAndDestroy
end

local function playSweep(waypoints: { BasePart }, skipRequested: () -> boolean)
	for i, waypoint in waypoints do
		if skipRequested() then
			return
		end

		local holdTime = waypoint:GetAttribute("HoldTime") :: number?
		local segmentTime = waypoint:GetAttribute("SegmentTime") :: number? or DEFAULT_SEGMENT_TIME

		if i == 1 then
			camera.CFrame = waypoint.CFrame
		else
			local tween = TweenService:Create(
				camera,
				TweenInfo.new(segmentTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ CFrame = waypoint.CFrame }
			)
			tween:Play()

			local completed = false
			tween.Completed:Once(function()
				completed = true
			end)

			while not completed do
				if skipRequested() then
					tween:Cancel()
					return
				end
				task.wait()
			end
		end

		if holdTime and holdTime > 0 then
			local elapsed = 0
			while elapsed < holdTime do
				if skipRequested() then
					return
				end
				elapsed += task.wait()
			end
		end
	end
end

local function shouldPlayHavenIntro(): boolean
	local ok, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	return ok and typeof(session) == "table" and session.TutorialCompleted == true
end

function CameraIntroController:Start()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not shouldPlayHavenIntro() then
		markFinished()
		return
	end

	local waypoints = getSortedWaypoints()
	if #waypoints < 2 then
		-- World hasn't been built yet (no CameraWaypoint parts) — nothing to
		-- play, but the player still has control immediately, so this still
		-- counts as "intro finished" for anything waiting on that.
		markFinished()
		return
	end

	local playerModule = require((player:WaitForChild("PlayerScripts") :: Instance):WaitForChild("PlayerModule")) :: any
	local controls = playerModule:GetControls()
	controls:Disable()
	humanoid.AutoRotate = false

	camera.CameraType = Enum.CameraType.Scriptable

	local _gui, fadeIn, fadeOutAndDestroy = buildSkipUi()
	fadeIn()

	local skipped = false
	local skipConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.UserInputType == Enum.UserInputType.Touch
		then
			skipped = true
		end
	end)

	playSweep(waypoints, function()
		return skipped
	end)

	skipConnection:Disconnect()
	fadeOutAndDestroy()

	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	humanoid.AutoRotate = true
	controls:Enable()

	markFinished()
end

return CameraIntroController
