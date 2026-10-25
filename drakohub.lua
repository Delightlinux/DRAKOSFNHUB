local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- // FLIGHT CONFIG & LOGIC //
local FLY_SPEED = 50
local FLY_ACTION_NAME = "AdminFlyMovement"
local isFlying = false
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

local function updateMovementVector()
	local forwardBack = keyStates.Forward - keyStates.Backward
	local leftRight = keyStates.Right - keyStates.Left
	local upDown = keyStates.Up - keyStates.Down

	local keyDir = Vector3.new(leftRight, upDown, -forwardBack)
	local mobileDir = Vector3.zero
	
	local character = LocalPlayer.Character
	if character and character:FindFirstChildOfClass("Humanoid") then
		mobileDir = character:FindFirstChildOfClass("Humanoid").MoveDirection
	end

	if keyDir.Magnitude > 0 then
		moveDirection = keyDir.Unit
	elseif mobileDir.Magnitude > 0 then
		moveDirection = Vector3.new(mobileDir.X, upDown, mobileDir.Z)
	else
		moveDirection = Vector3.zero
	end
end

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

	updateMovementVector()
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
			if UserInputService.TouchEnabled then
				updateMovementVector()
			end

			local camCF = Camera.CFrame
			local flyVector = (camCF.RightVector * moveDirection.X) 
				+ (Vector3.yAxis * moveDirection.Y) 
				+ (camCF.LookVector * -moveDirection.Z)

			bodyVelocity.Velocity = flyVector * FLY_SPEED
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

-- // LOAD EXISTING UI LIBRARY (Rayfield) //
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Asym Admin Panel",
   LoadingTitle = "Asym Interface",
   LoadingSubtitle = "by Delightlinux",
   ConfigurationSaving = {
      Enabled = false,
   },
   KeySystem = false,
})

local Tab = Window:CreateTab("Movement", 4483362458) -- Title, Icon ID

Tab:CreateSection("Flight & Noclip")

Tab:CreateToggle({
   Name = "Enable Flight",
   CurrentValue = false,
   Flag = "FlightToggle", 
   Callback = function(Value)
      setFlyEnabled(Value)
   end,
})

Tab:CreateToggle({
   Name = "Enable Noclip",
   CurrentValue = false,
   Flag = "NoclipToggle",
   Callback = function(Value)
      setNoclipEnabled(Value)
   end,
})

Tab:CreateInput({
   Name = "Set Flight Speed",
   PlaceholderText = "50",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      local num = tonumber(Text)
      if num then
         FLY_SPEED = num
         print("Flight speed updated to:", FLY_SPEED)
      end
   end,
})

Rayfield:LoadConfiguration()
