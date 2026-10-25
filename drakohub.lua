local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- // FLIGHT CONFIG & LOGIC //
local FLY_SPEED = 50
local FLY_ACTION_NAME = "AdminFlyMovement"
local isFlying = false
local cameraPitchMode = false -- Toggle for looking up/down flight
local moveDirection = Vector3.zero
local bodyVelocity = nil
local bodyGyro = nil
local flyConnection = nil

local keyStates = {
	Forward = 0,   -- W / I
	Backward = 0,  -- S / K
	Left = 0,      -- A / J
	Right = 0,     -- D / L
	Up = 0,        -- E / Space
	Down = 0,      -- Q
}

local function handleFlightInput(actionName, inputState, inputObject)
	local isPressed = (inputState == Enum.UserInputState.Begin) and 1 or 0

	if inputObject.KeyCode == Enum.KeyCode.W or inputObject.KeyCode == Enum.KeyCode.I then
		keyStates.Forward = isPressed
	elseif inputObject.KeyCode == Enum.KeyCode.S or inputObject.KeyCode == Enum.KeyCode.K then
		keyStates.Backward = isPressed
	elseif inputObject.KeyCode == Enum.KeyCode.A or inputObject.KeyCode == Enum.KeyCode.J then
		keyStates.Left = isPressed
	elseif inputObject.KeyCode == Enum.KeyCode.D or inputObject.KeyCode == Enum.KeyCode.L then
		keyStates.Right = isPressed
	elseif inputObject.KeyCode == Enum.KeyCode.E or inputObject.KeyCode == Enum.KeyCode.Space then
		keyStates.Up = isPressed
	elseif inputObject.KeyCode == Enum.KeyCode.Q then
		keyStates.Down = isPressed
	end

	return Enum.ContextActionResult.Pass
end

local function setFlyEnabled(enabled: boolean)
	local character = LocalPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then return end

	if enabled and not isFlying then
		isFlying = true
		humanoid:ChangeState(Enum.HumanoidStateType.Flying)

		bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 10^6
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity.Parent = rootPart

		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 10^6
		bodyGyro.P = 10000
		bodyGyro.CFrame = rootPart.CFrame
		bodyGyro.Parent = rootPart

		ContextActionService:BindAction(
			FLY_ACTION_NAME,
			handleFlightInput,
			false,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.I, Enum.KeyCode.J, Enum.KeyCode.K, Enum.KeyCode.L,
			Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.Space
		)

		flyConnection = RunService.RenderStepped:Connect(function()
			if not isFlying or not rootPart then return end

			local camCF = Camera.CFrame
			local moveVec = Vector3.zero

			local forwardBack = keyStates.Forward - keyStates.Backward
			local leftRight = keyStates.Right - keyStates.Left
			local upDown = keyStates.Up - keyStates.Down

			if forwardBack ~= 0 or leftRight ~= 0 or upDown ~= 0 then
				if cameraPitchMode then
					moveVec = (camCF.RightVector * leftRight) + (camCF.LookVector * forwardBack) + (Vector3.yAxis * upDown)
				else
					moveVec = (camCF.RightVector * leftRight) + (Vector3.yAxis * upDown) + (camCF.LookVector * Vector3.new(forwardBack, 0, forwardBack))
				end
			else
				local charHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				if charHumanoid and charHumanoid.MoveDirection.Magnitude > 0 then
					local md = charHumanoid.MoveDirection
					if cameraPitchMode then
						moveVec = (camCF.RightVector * md.X) + (camCF.LookVector * md.Z) + (Vector3.yAxis * upDown)
					else
						moveVec = Vector3.new(md.X, upDown, md.Z)
					end
				end
			end

			if moveVec.Magnitude > 0 then
				bodyVelocity.Velocity = moveVec.Unit * FLY_SPEED
			else
				bodyVelocity.Velocity = Vector3.zero
			end

			bodyGyro.CFrame = camCF
		end)
	elseif not enabled and isFlying then
		isFlying = false
		ContextActionService:UnbindAction(FLY_ACTION_NAME)

		if flyConnection then
			flyConnection:Disconnect()
			flyConnection = nil
		end
		if bodyVelocity then bodyVelocity:Destroy() end
		if bodyGyro then bodyGyro:Destroy() end

		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

-- // NOCLIP LOGIC //
local noclipConnection = nil
local function setNoclipEnabled(enabled: boolean)
	if enabled then
		noclipConnection = RunService.Stepped:Connect(function()
			local character = LocalPlayer.Character
			if character then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
	else
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
	end
end

-- // EXTRA MOVEMENT FEATURES //
local infJumpConnection = nil
local function setInfiniteJump(enabled: boolean)
	if enabled then
		infJumpConnection = UserInputService.JumpRequest:Connect(function()
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	else
		if infJumpConnection then
			infJumpConnection:Disconnect()
			infJumpConnection = nil
		end
	end
end

local function setWalkSpeed(speed: number)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- // PARTY MODE (Map Color Rave every 0.1s) //
local partyTask = nil
local function setPartyModeEnabled(enabled: boolean)
	if enabled then
		partyTask = task.spawn(function()
			while true do
				for _, part in ipairs(workspace:GetDescendants()) do
					if part:IsA("BasePart") and not (LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character)) then
						part.Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
					end
				end
				task.wait(0.1)
			end
		end)
	else
		if partyTask then
			task.cancel(partyTask)
			partyTask = nil
		end
	end
end

-- // FULLBRIGHT //
local function setFullbright(enabled: boolean)
	if enabled then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	else
		Lighting.GlobalShadows = true
	end
end

-- // UI SETUP (Rayfield with Explicit Key Display) //
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Asym Admin Panel",
   LoadingTitle = "Asym Interface",
   LoadingSubtitle = "by Delightlinux",
   ConfigurationSaving = {
      Enabled = false,
   },
   KeySystem = true, 
   KeySettings = {
      Title = "Asym Admin Key",
      Subtitle = "Key System",
      Note = "The key is: cheezeborger",
      FileName = "AsymKey",
      SaveKey = true,
      GrabKeyFromLink = false,
      Key = {"cheezeborger"}
   }
})

-- Movement Tab
local MovementTab = Window:CreateTab("Movement", 4483362458)
MovementTab:CreateSection("Flight & Physics")

MovementTab:CreateToggle({
   Name = "Enable Flight",
   CurrentValue = false,
   Flag = "FlightToggle", 
   Callback = function(Value)
      setFlyEnabled(Value)
   end,
})

MovementTab:CreateToggle({
   Name = "Camera Pitch Fly (Look Up/Down)",
   CurrentValue = false,
   Flag = "PitchModeToggle",
   Callback = function(Value)
      cameraPitchMode = Value
   end,
})

MovementTab:CreateToggle({
   Name = "Enable Noclip",
   CurrentValue = false,
   Flag = "NoclipToggle",
   Callback = function(Value)
      setNoclipEnabled(Value)
   end,
})

MovementTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "InfJumpToggle",
   Callback = function(Value)
      setInfiniteJump(Value)
   end,
})

MovementTab:CreateInput({
   Name = "Set Flight Speed",
   PlaceholderText = "50",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      local num = tonumber(Text)
      if num then
         FLY_SPEED = num
      end
   end,
})

MovementTab:CreateInput({
   Name = "Set WalkSpeed",
   PlaceholderText = "16",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      local num = tonumber(Text)
      if num then
         setWalkSpeed(num)
      end
   end,
})

-- Visuals / Fun Tab
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
VisualsTab:CreateSection("World Effects")

VisualsTab:CreateToggle({
   Name = "Party Mode (Map Rave every 0.1s)",
   CurrentValue = false,
   Flag = "PartyToggle",
   Callback = function(Value)
      setPartyModeEnabled(Value)
   end,
})

VisualsTab:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "FullbrightToggle",
   Callback = function(Value)
      setFullbright(Value)
   end,
})

Rayfield:LoadConfiguration()
