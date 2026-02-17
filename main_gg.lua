-- Anti Idle (предотвращает афк-кик)
local VirtualUser = game:GetService('VirtualUser')
if game:GetService('Players').LocalPlayer then
	game:GetService('Players').LocalPlayer.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end

-- [[ MELEE AURA (из вашего исходника) ]] --
local MeleeAura_Enabled = false
local MeleeAura_Connection

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local remoteFunctionPath = "XMHH.2"
local remoteEventPath = "XMHH2.2"
local remote1 = eventsFolder:WaitForChild(remoteFunctionPath)
local remote2 = eventsFolder:WaitForChild(remoteEventPath)
local maxdist = 5

local function Attack(target)
	if not (target and target:FindFirstChild("Head")) then return end
	local char = LocalPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not remote1 or not remote1:IsA("RemoteFunction") then warn("MeleeAura Ошибка: RemoteFunction не найден."); MeleeAura_Disable(); return end
	if not remote2 or not remote2:IsA("RemoteEvent") then warn("MeleeAura Ошибка: RemoteEvent не найден."); MeleeAura_Disable(); return end

	local arg1 = { [1] = "🍞", [2] = tick(), [3] = tool, [4] = "43TRFWX", [5] = "Normal", [6] = tick(), [7] = true }
	local success1, result = pcall(function() return remote1:InvokeServer(unpack(arg1)) end)
	if not success1 then warn("MeleeAura Ошибка: InvokeServer не удался:", result); return end

	task.wait(0.1)
	local Handle = tool and (tool:FindFirstChild("WeaponHandle") or tool:FindFirstChild("Handle")) or (char and char:FindFirstChild("Right Arm"))
	local head = target:FindFirstChild("Head")
	if Handle and head and hrp then
		local arg2 = { [1] = "🍞", [2] = tick(), [3] = tool, [4] = "2389ZFX34", [5] = result, [6] = false, [7] = Handle, [8] = head, [9] = target, [10] = hrp.Position, [11] = head.Position }
		pcall(function() remote2:FireServer(unpack(arg2)) end)
	end
end

local function runAttackLoop()
	return RunService.RenderStepped:Connect(function()
		if not MeleeAura_Enabled then return end
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					local c = plr.Character
					local hrp2 = c and c:FindFirstChild("HumanoidRootPart")
					local hum = c and c:FindFirstChildOfClass("Humanoid")
					if hrp2 and hum then
						local dist = (hrp.Position - hrp2.Position).Magnitude
						if dist < maxdist and hum.Health > 15 and not c:FindFirstChildOfClass("ForceField") then
							Attack(c)
						end
					end
				end
			end
		end
	end)
end

function MeleeAura_Enable()
	if MeleeAura_Enabled then return end
	MeleeAura_Enabled = true
	if MeleeAura_Connection and MeleeAura_Connection.Connected then MeleeAura_Connection:Disconnect() end
	MeleeAura_Connection = runAttackLoop()
end

function MeleeAura_Disable()
	if not MeleeAura_Enabled then return end
	MeleeAura_Enabled = false
	if MeleeAura_Connection and MeleeAura_Connection.Connected then
		MeleeAura_Connection:Disconnect()
		MeleeAura_Connection = nil
	end
end

-- [[ INVISIBILITY (НЕВИДИМОСТЬ) ]] --
local Invis_Fixed = true
do
	repeat task.wait() until game:IsLoaded()
	local cloneref = cloneref or function(...) return ... end
	local Service = setmetatable({}, { __index = function(_, k) return cloneref(game:GetService(k)); end })
	local Player = Service.Players.LocalPlayer
	local Character, Humanoid, HumanoidRootPart
	local UserInputService = Service.UserInputService

	local function UpdateCharacterReferences()
		Character = Player.Character
		if Character then
			HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
			Humanoid = Character:FindFirstChildOfClass("Humanoid")
		else
			HumanoidRootPart = nil
			Humanoid = nil
		end
	end
	UpdateCharacterReferences()

	local InvisEnabled = false
	local Track = nil
	local Animation = Instance.new("Animation")
	Animation.AnimationId = "rbxassetid://215384594"
	local RunService = Service.RunService
	local Heartbeat = RunService.Heartbeat
	local RenderStepped = RunService.RenderStepped
	local CoreGui = Service.CoreGui
	local StarterGui = Service.StarterGui

	if Character and not Character:FindFirstChild("Torso") then
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Невидимость НЕ РАБОТАЕТ",
				Text = "Функция требует R6 аватар.",
				Duration = 5
			})
		end)
		Invis_Fixed = false
	end

	local GUI = Instance.new("ScreenGui")
	GUI.Name = "InvisWarningGUI"
	GUI.Parent = CoreGui
	GUI.ResetOnSpawn = false
	GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local WarnLabel = Instance.new("TextLabel", GUI)
	WarnLabel.Text = "⚠️Вы видны⚠️"
	WarnLabel.Visible = false
	WarnLabel.Size = UDim2.new(0, 200, 0, 30)
	WarnLabel.Position = UDim2.new(0.5, -100, 0.85, 0)
	WarnLabel.BackgroundTransparency = 1
	WarnLabel.Font = Enum.Font.GothamSemibold
	WarnLabel.TextSize = 24
	WarnLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	WarnLabel.TextStrokeTransparency = 0.5
	WarnLabel.ZIndex = 10

	local function Grounded()
		return Humanoid and Humanoid:IsDescendantOf(workspace) and Humanoid.FloorMaterial ~= Enum.Material.Air
	end

	local function LoadAndPrepareTrack()
		if Track then
			pcall(function() Track:Stop() end)
			Track = nil
		end
		if Humanoid then
			local success, result = pcall(function() return Humanoid:LoadAnimation(Animation) end)
			if success then
				Track = result
				Track.Priority = Enum.AnimationPriority.Action4
			else
				Track = nil
			end
		else
			Track = nil
		end
	end

	local function Invis_Disable()
		if not InvisEnabled then return end
		InvisEnabled = false
		if Track then pcall(function() Track:Stop() end) end
		if Humanoid then workspace.CurrentCamera.CameraSubject = Humanoid end
		if Character then
			for _, v in pairs(Character:GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
			end
		end
		WarnLabel.Visible = false
	end

	local function Invis_Enable()
		if InvisEnabled or not Invis_Fixed then return end
		UpdateCharacterReferences()
		if not Character or not Humanoid or not HumanoidRootPart then return end
		if not Character:FindFirstChild("Torso") then
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Невидимость НЕ РАБОТАЕТ",
					Text = "Функция требует R6 аватар.",
					Duration = 5
				})
			end)
			return
		end
		InvisEnabled = true
		workspace.CurrentCamera.CameraSubject = HumanoidRootPart
		LoadAndPrepareTrack()
	end

	local function ToggleInvis()
		if InvisEnabled then
			Invis_Disable()
		else
			Invis_Enable()
		end
	end

	-- Экспорт функций
	_G.Invis_Enable = Invis_Enable
	_G.Invis_Disable = Invis_Disable
	_G.Invis_Toggle = ToggleInvis
	_G.IsInvisEnabled = function() return InvisEnabled end

	Player.CharacterAdded:Connect(function(NewCharacter)
		if Track then pcall(function() Track:Stop() end); Track = nil end
		task.wait()
		UpdateCharacterReferences()
		if not Humanoid then
			task.wait(0.5)
			UpdateCharacterReferences()
			if not Humanoid then
				Invis_Fixed = false
				if InvisEnabled then Invis_Disable() end
				pcall(function()
					StarterGui:SetCore("SendNotification", {
						Title = "Ошибка Невидимости",
						Text = "Не удалось определить тип персонажа.",
						Duration = 5
					})
				end)
				return
			end
		end
		if Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
			Invis_Fixed = false
			if InvisEnabled then Invis_Disable() end
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Предупреждение Невидимости",
					Text = "Обнаружен не-R6 аватар (" .. tostring(Humanoid.RigType) .. "). Невидимость отключена.",
					Duration = 5
				})
			end)
			return
		else
			Invis_Fixed = true
		end
		if InvisEnabled then
			if HumanoidRootPart then workspace.CurrentCamera.CameraSubject = HumanoidRootPart end
			LoadAndPrepareTrack()
		end
	end)

	Player.CharacterRemoving:Connect(function(OldCharacter)
		if Track then pcall(function() Track:Stop() end); Track = nil end
		WarnLabel.Visible = false
	end)

	Heartbeat:Connect(function(deltaTime)
		if not InvisEnabled or not Invis_Fixed then
			if not InvisEnabled and Character then
				for _, v in pairs(Character:GetDescendants()) do
					if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
				end
			end
			WarnLabel.Visible = false
			return
		end
		if not Character or not Humanoid or not HumanoidRootPart or not Humanoid:IsDescendantOf(workspace) or Humanoid.Health <= 0 then
			WarnLabel.Visible = false
			return
		end
		WarnLabel.Visible = not Grounded()

		local speed = 12
		if Humanoid.MoveDirection.Magnitude > 0 then
			local offset = Humanoid.MoveDirection * speed * deltaTime
			HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + offset
		end

		local OldCFrame = HumanoidRootPart.CFrame
		local OldCameraOffset = Humanoid.CameraOffset
		local _, y = workspace.CurrentCamera.CFrame:ToOrientation()

		HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.CFrame.Position) * CFrame.fromOrientation(0, y, 0)
		HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0)
		Humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

		if Track then
			local successPlay, errPlay = pcall(function()
				if not Track.IsPlaying then Track:Play() end
				Track:AdjustSpeed(0)
				Track.TimePosition = 0.3
			end)
			if not successPlay then LoadAndPrepareTrack() end
		elseif Humanoid and Humanoid.Health > 0 then
			LoadAndPrepareTrack()
		end

		RenderStepped:Wait()

		if Humanoid and Humanoid:IsDescendantOf(workspace) then
			Humanoid.CameraOffset = OldCameraOffset
		end
		if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
			HumanoidRootPart.CFrame = OldCFrame
		end
		if Track then pcall(function() Track:Stop() end) end
		if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
			local LookVector = workspace.CurrentCamera.CFrame.LookVector
			local Horizontal = Vector3.new(LookVector.X, 0, LookVector.Z).Unit
			if Horizontal.Magnitude > 0.1 then
				HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, HumanoidRootPart.Position + Horizontal)
			end
		end
		if Character then
			for _, v in pairs(Character:GetDescendants()) do
				if (v:IsA("BasePart") and v.Transparency ~= 1) then
					v.Transparency = 0.5
				end
			end
		end
	end)
end

-- [[ МИНИ-МЕНЮ ]] --
local Player = game:GetService("Players").LocalPlayer
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local InvisButton = Instance.new("TextButton")
local MeleeButton = Instance.new("TextButton")
local CloseButton = Instance.new("TextButton")

-- Настройка GUI
ScreenGui.Name = "MiniMenu"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
MainFrame.Size = UDim2.new(0, 300, 0, 150)
MainFrame.Active = true
MainFrame.Draggable = false

-- Скругление углов
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Обводка
local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(60, 60, 75)
UIStroke.Thickness = 1
UIStroke.Parent = MainFrame

-- Заголовок
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
Title.BackgroundTransparency = 0
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBold
Title.Text = "MINI MENU | R - невидимость"
Title.TextColor3 = Color3.fromRGB(220, 220, 220)
Title.TextSize = 14

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- Кнопка закрытия
CloseButton.Name = "CloseButton"
CloseButton.Parent = Title
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Position = UDim2.new(1, -25, 0, 5)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 12
CloseButton.AutoButtonColor = false

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseButton

-- Кнопка невидимости
InvisButton.Name = "InvisButton"
InvisButton.Parent = MainFrame
InvisButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
InvisButton.Size = UDim2.new(0.9, 0, 0, 35)
InvisButton.Position = UDim2.new(0.05, 0, 0, 40)
InvisButton.Font = Enum.Font.GothamBold
InvisButton.Text = "НЕВИДИМОСТЬ: ВЫКЛ"
InvisButton.TextColor3 = Color3.fromRGB(255, 100, 100)
InvisButton.TextSize = 14
InvisButton.AutoButtonColor = false

local InvisCorner = Instance.new("UICorner")
InvisCorner.CornerRadius = UDim.new(0, 6)
InvisCorner.Parent = InvisButton

-- Кнопка Melee Aura
MeleeButton.Name = "MeleeButton"
MeleeButton.Parent = MainFrame
MeleeButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
MeleeButton.Size = UDim2.new(0.9, 0, 0, 35)
MeleeButton.Position = UDim2.new(0.05, 0, 0, 85)
MeleeButton.Font = Enum.Font.GothamBold
MeleeButton.Text = "MELEE AURA: ВЫКЛ"
MeleeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
MeleeButton.TextSize = 14
MeleeButton.AutoButtonColor = false

local MeleeCorner = Instance.new("UICorner")
MeleeCorner.CornerRadius = UDim.new(0, 6)
MeleeCorner.Parent = MeleeButton

-- Перетаскивание окна
local dragging = false
local dragInput, dragStart, startPos

Title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

Title.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Функции обновления кнопок
local function UpdateInvisButton()
	if _G.IsInvisEnabled and _G.IsInvisEnabled() then
		InvisButton.Text = "НЕВИДИМОСТЬ: ВКЛ"
		InvisButton.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		InvisButton.Text = "НЕВИДИМОСТЬ: ВЫКЛ"
		InvisButton.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
end

local function UpdateMeleeButton()
	if MeleeAura_Enabled then
		MeleeButton.Text = "MELEE AURA: ВКЛ"
		MeleeButton.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		MeleeButton.Text = "MELEE AURA: ВЫКЛ"
		MeleeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
end

-- Начальное обновление
task.wait(0.5)
UpdateInvisButton()
UpdateMeleeButton()

-- Обработчики кнопок
InvisButton.MouseButton1Click:Connect(function()
	if _G.Invis_Toggle then
		_G.Invis_Toggle()
		task.wait(0.1)
		UpdateInvisButton()
	end
end)

MeleeButton.MouseButton1Click:Connect(function()
	if MeleeAura_Enabled then
		MeleeAura_Disable()
	else
		MeleeAura_Enable()
	end
	task.wait(0.1)
	UpdateMeleeButton()
end)

CloseButton.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

-- Эффекты наведения
local function CreateHoverEffect(button)
	button.MouseEnter:Connect(function()
		game:GetService("TweenService"):Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 50, 55)}):Play()
	end)
	button.MouseLeave:Connect(function()
		game:GetService("TweenService"):Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
	end)
end

CreateHoverEffect(InvisButton)
CreateHoverEffect(MeleeButton)

CloseButton.MouseEnter:Connect(function()
	game:GetService("TweenService"):Create(CloseButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
end)
CloseButton.MouseLeave:Connect(function()
	game:GetService("TweenService"):Create(CloseButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}):Play()
end)

-- Управление по клавише R (вынесено в отдельный поток для надежности)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Игнорируем, если обработано игрой или если это не клавиша R
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
		if _G.Invis_Toggle then
			_G.Invis_Toggle()
			task.wait(0.1)
			UpdateInvisButton()
		end
	end
end)

-- Уведомление о загрузке
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Меню загружено",
		Text = "R - невидимость | Меню можно перетаскивать",
		Duration = 3
	})
end)
