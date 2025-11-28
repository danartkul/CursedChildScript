local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Система оптимизации
local PerformanceManager = {
    LastESPCleanup = 0,
    LastPlayerUpdate = 0,
    LastSafeScan = 0,
    LastDealerScan = 0,
    CleanupInterval = 10,
    UpdateIntervals = {
        PlayerESP = 0.5,
        SafeESP = 3,
        DealerESP = 5,
        FavoriteESP = 0.3
    }
}

local espObjects = {}
local connections = {}

local states = {
    playerESP = false,
    playerHP = false,
    playerTool = false,
    safeESP = false,
    dealerESP = false,
    favoriteESP = false,
    teamColorESP = false,
    spectateFavorite = false
}

local movementStates = {
    noClip = false,
    fly = false,
    speedEnabled = false,
    highJump = false
}

local movementSettings = {
    flySpeed = 50,
    walkSpeed = 16,
    jumpPower = 50
}

local flyEnabled = false
local flyBodyGyro = nil
local flyBodyVelocity = nil
local flyConnection = nil

local combatStates = {
    triggerBot = false,
    aimBot = false,
    godMode = false
}

local aimbotSettings = {
    Enabled = false,
    TeamCheck = true,
    AliveCheck = true,
    WallCheck = true,
    AutoUnlock = true,
    Sensitivity = 0,
    ThirdPerson = false,
    ThirdPersonSensitivity = 3,
    TriggerKey = "MouseButton2",
    Toggle = false,
    LockPart = "Head",
    FOV = 200,
    ShowFOV = false
}

local aimbotRunning = false
local aimbotLocked = nil
local aimbotFOVCircle = nil
local aimbotConnections = {}

local teleportSettings = {
    flyBind = "F",
    behindBind = "T"
}

-- СИСТЕМА ФАВОРИТОВ С БИНДАМИ
local favoriteBinds = {
    setFavorite = "Y", -- Бинд для установки фаворита из аимбота
    spectateFavorite = "I", -- Бинд для переключения спекты
    cycleFavorite = "U" -- Бинд для циклического переключения между фаворитами
}

local FavoritePlayer = nil
local TextSize = 14
local NeutralColor = Color3.fromRGB(255, 105, 180)

local currentFavoriteTarget = nil
local currentFavoriteHighlight = nil
local favoriteDistanceConnection = nil
local favoriteInfoLabel = nil

local godModeConnections = {}
local godModeHumanoids = {}
local originalWalkSpeeds = {}
local originalJumpPowers = {}

local collectedTools = {}
local favoriteBackpackConnection = nil
local favoriteCharacterConnection = nil

-- Система наблюдения
local isSpectating = false
local spectateConnection = nil
local originalCameraType = nil
local spectatorUI = nil
local nearbyPlayersBars = {}

-- Функции для спектаторского интерфейса
local function CreateSpectatorUI()
    if spectatorUI then
        spectatorUI:Destroy()
    end
    
    spectatorUI = Instance.new("ScreenGui")
    spectatorUI.Name = "DANART_SIGMA_SpectatorUI"
    spectatorUI.Parent = game:GetService("CoreGui")
    
    -- Панель здоровья фаворита снизу слева
    local favoriteHealthFrame = Instance.new("Frame")
    favoriteHealthFrame.Name = "FavoriteHealthFrame"
    favoriteHealthFrame.Size = UDim2.new(0, 300, 0, 80)
    favoriteHealthFrame.Position = UDim2.new(0, 20, 1, -100)
    favoriteHealthFrame.AnchorPoint = Vector2.new(0, 1)
    favoriteHealthFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    favoriteHealthFrame.BackgroundTransparency = 0.3
    favoriteHealthFrame.BorderSizePixel = 0
    favoriteHealthFrame.Parent = spectatorUI
    
    local favoriteNameLabel = Instance.new("TextLabel")
    favoriteNameLabel.Name = "FavoriteNameLabel"
    favoriteNameLabel.Size = UDim2.new(1, 0, 0.3, 0)
    favoriteNameLabel.Position = UDim2.new(0, 0, 0, 0)
    favoriteNameLabel.BackgroundTransparency = 1
    favoriteNameLabel.Text = "FAVORITE: " .. (FavoritePlayer or "NONE")
    favoriteNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    favoriteNameLabel.TextSize = 16
    favoriteNameLabel.Font = Enum.Font.GothamBold
    favoriteNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    favoriteNameLabel.Parent = favoriteHealthFrame
    
    local healthBarBackground = Instance.new("Frame")
    healthBarBackground.Name = "HealthBarBackground"
    healthBarBackground.Size = UDim2.new(1, -20, 0, 20)
    healthBarBackground.Position = UDim2.new(0, 10, 0.5, 0)
    healthBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBarBackground.BorderSizePixel = 0
    healthBarBackground.Parent = favoriteHealthFrame
    
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.Position = UDim2.new(0, 0, 0, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBarBackground
    
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(1, 0, 1, 0)
    healthText.Position = UDim2.new(0, 0, 0, 0)
    healthText.BackgroundTransparency = 1
    healthText.Text = "100/100"
    healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthText.TextSize = 12
    healthText.Font = Enum.Font.GothamBold
    healthText.Parent = healthBarBackground
    
    return {
        Frame = favoriteHealthFrame,
        HealthBar = healthBar,
        HealthText = healthText,
        NameLabel = favoriteNameLabel
    }
end

local function UpdateFavoriteHealthBar(healthData)
    if not spectatorUI or not healthData then return end
    
    local healthBar = spectatorUI:FindFirstChild("FavoriteHealthFrame")
    if healthBar then
        local healthBarFill = healthBar:FindFirstChild("HealthBarBackground"):FindFirstChild("HealthBar")
        local healthText = healthBar:FindFirstChild("HealthBarBackground"):FindFirstChild("HealthText")
        local nameLabel = healthBar:FindFirstChild("FavoriteNameLabel")
        
        if healthBarFill and healthText then
            local healthPercent = healthData.Health / healthData.MaxHealth
            healthBarFill.Size = UDim2.new(healthPercent, 0, 1, 0)
            healthText.Text = math.floor(healthData.Health) .. "/" .. math.floor(healthData.MaxHealth)
            
            -- Изменение цвета в зависимости от здоровья
            if healthPercent > 0.5 then
                healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.2 then
                healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
            else
                healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            end
        end
        
        if nameLabel then
            nameLabel.Text = "FAVORITE: " .. (FavoritePlayer or "NONE")
        end
    end
end

local function CreatePlayerHealthBar(player, character)
    if not character then return nil end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    
    -- Создаем BillboardGui для полоски здоровья над головой
    local healthBillboard = Instance.new("BillboardGui")
    healthBillboard.Name = "PlayerHealthBar_" .. player.Name
    healthBillboard.Size = UDim2.new(0, 100, 0, 20)
    healthBillboard.StudsOffset = Vector3.new(0, 5, 0)
    healthBillboard.AlwaysOnTop = true
    healthBillboard.Adornee = character:FindFirstChild("Head") or character.PrimaryPart
    healthBillboard.Parent = character
    
    local healthBarBackground = Instance.new("Frame")
    healthBarBackground.Name = "HealthBarBackground"
    healthBarBackground.Size = UDim2.new(1, 0, 1, 0)
    healthBarBackground.Position = UDim2.new(0, 0, 0, 0)
    healthBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBarBackground.BorderSizePixel = 0
    healthBarBackground.Parent = healthBillboard
    
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.Position = UDim2.new(0, 0, 0, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBarBackground
    
    local playerName = Instance.new("TextLabel")
    playerName.Name = "PlayerName"
    playerName.Size = UDim2.new(1, 0, 1, 0)
    playerName.Position = UDim2.new(0, 0, 0, 0)
    playerName.BackgroundTransparency = 1
    playerName.Text = player.Name
    playerName.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerName.TextSize = 10
    playerName.Font = Enum.Font.GothamBold
    playerName.Parent = healthBillboard
    
    local healthData = {
        Billboard = healthBillboard,
        HealthBar = healthBar,
        PlayerName = playerName,
        Humanoid = humanoid,
        Player = player
    }
    
    nearbyPlayersBars[player] = healthData
    
    return healthData
end

local function UpdatePlayerHealthBar(healthData)
    if not healthData or not healthData.Humanoid or not healthData.Humanoid.Parent then
        return false
    end
    
    local healthPercent = healthData.Humanoid.Health / healthData.Humanoid.MaxHealth
    healthData.HealthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
    
    -- Изменение цвета в зависимости от здоровья
    if healthPercent > 0.5 then
        healthData.HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    elseif healthPercent > 0.2 then
        healthData.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
    else
        healthData.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end
    
    return true
end

local function ClearNearbyPlayersBars()
    for player, healthData in pairs(nearbyPlayersBars) do
        if healthData.Billboard then
            healthData.Billboard:Destroy()
        end
    end
    nearbyPlayersBars = {}
end

local function UpdateNearbyPlayersHealthBars(favoriteCharacter)
    if not favoriteCharacter then return end
    
    local favoritePosition = favoriteCharacter:GetPivot().Position
    local currentPlayers = {}
    
    -- Обновляем полоски здоровья для игроков поблизости
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent then
            local playerPosition = player.Character:GetPivot().Position
            local distance = (favoritePosition - playerPosition).Magnitude
            
            -- Если игрок в радиусе 50 studs от фаворита
            if distance <= 50 then
                currentPlayers[player] = true
                
                if not nearbyPlayersBars[player] then
                    CreatePlayerHealthBar(player, player.Character)
                else
                    UpdatePlayerHealthBar(nearbyPlayersBars[player])
                end
            end
        end
    end
    
    -- Удаляем полоски здоровья для игроков, которые ушли далеко
    for player, healthData in pairs(nearbyPlayersBars) do
        if not currentPlayers[player] then
            if healthData.Billboard then
                healthData.Billboard:Destroy()
            end
            nearbyPlayersBars[player] = nil
        end
    end
end

local function SpectateFavorite()
    if not FavoritePlayer or not states.spectateFavorite then
        return
    end
    
    local targetPlayer = Players:FindFirstChild(FavoritePlayer)
    if not targetPlayer or not targetPlayer.Character then
        if isSpectating then
            StopSpectate()
            Rayfield:Notify({
                Title = "Spectate Error",
                Content = "Favorite player not found!",
                Duration = 3,
            })
        end
        return
    end
    
    local character = targetPlayer.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not humanoidRootPart or not humanoid then
        if isSpectating then
            StopSpectate()
        end
        return
    end
    
    if not isSpectating then
        -- Начинаем наблюдение
        isSpectating = true
        originalCameraType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable
        
        -- Создаем интерфейс спектатора
        CreateSpectatorUI()
        
        Rayfield:Notify({
            Title = "DANART SIGMA - Spectate Mode",
            Content = "Now spectating: " .. FavoritePlayer,
            Duration = 3,
        })
    end
    
    -- Обновляем здоровье фаворита
    UpdateFavoriteHealthBar({
        Health = humanoid.Health,
        MaxHealth = humanoid.MaxHealth
    })
    
    -- Обновляем полоски здоровья nearby игроков
    UpdateNearbyPlayersHealthBars(character)
    
    -- Позиция камеры позади персонажа
    local offset = humanoidRootPart.CFrame.LookVector * -8 + Vector3.new(0, 3, 0)
    local targetCFrame = humanoidRootPart.CFrame + offset
    
    -- Плавное перемещение камеры
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 0.1)
end

local function StopSpectate()
    if isSpectating then
        isSpectating = false
        if originalCameraType then
            Camera.CameraType = originalCameraType
        end
        
        -- Очищаем интерфейс спектатора
        if spectatorUI then
            spectatorUI:Destroy()
            spectatorUI = nil
        end
        
        -- Очищаем полоски здоровья nearby игроков
        ClearNearbyPlayersBars()
        
        Rayfield:Notify({
            Title = "DANART SIGMA - Spectate Mode",
            Content = "Spectate mode disabled",
            Duration = 3,
        })
    end
end

function ToggleSpectate(state)
    states.spectateFavorite = state
    
    if state then
        if not FavoritePlayer then
            Rayfield:Notify({
                Title = "Spectate Error",
                Content = "No favorite player set!\nAim at player and press " .. favoriteBinds.setFavorite,
                Duration = 4,
            })
            states.spectateFavorite = false
            return
        end
        
        local targetPlayer = Players:FindFirstChild(FavoritePlayer)
        if not targetPlayer or not targetPlayer.Character then
            Rayfield:Notify({
                Title = "Spectate Error",
                Content = "Favorite player not found: " .. (FavoritePlayer or "None"),
                Duration = 4,
            })
            states.spectateFavorite = false
            return
        end
        
        spectateConnection = RunService.RenderStepped:Connect(SpectateFavorite)
        table.insert(connections, spectateConnection)
        
        Rayfield:Notify({
            Title = "Spectate Started",
            Content = "Now spectating: " .. FavoritePlayer .. "\nPress " .. favoriteBinds.spectateFavorite .. " to stop",
            Duration = 5,
        })
    else
        StopSpectate()
        if spectateConnection then
            spectateConnection:Disconnect()
            spectateConnection = nil
        end
        
        Rayfield:Notify({
            Title = "Spectate Stopped",
            Content = "Stopped spectating: " .. (FavoritePlayer or "None"),
            Duration = 3,
        })
    end
end

-- НОВЫЕ ФУНКЦИИ ДЛЯ СИСТЕМЫ ФАВОРИТОВ С БИНДАМИ
function SetAimbotTargetAsFavorite()
    if not aimbotLocked then
        Rayfield:Notify({
            Title = "Favorite Error",
            Content = "No aimbot target locked!",
            Duration = 3,
        })
        return
    end
    
    local previousFavorite = FavoritePlayer
    FavoritePlayer = aimbotLocked.Name
    
    -- Очищаем предыдущего фаворита если он был
    if previousFavorite and previousFavorite ~= FavoritePlayer then
        local oldPlayer = Players:FindFirstChild(previousFavorite)
        if oldPlayer and oldPlayer.Character then
            RemoveESP(oldPlayer.Character)
        end
    end
    
    -- Обновляем ESP для нового фаворита
    if states.favoriteESP then
        ToggleFavoriteESP(false)
        wait(0.1)
        ToggleFavoriteESP(true)
    end
    
    -- Обновляем текстовое поле в GUI
    if FavoriteTextBox then
        FavoriteTextBox:Set(FavoritePlayer)
    end
    
    Rayfield:Notify({
        Title = "Favorite Updated",
        Content = "New favorite: " .. FavoritePlayer .. "\nPrevious: " .. (previousFavorite or "None"),
        Duration = 4,
    })
    
    print("Favorite player changed to:", FavoritePlayer)
end

function CycleToNextFavorite()
    local allPlayers = Players:GetPlayers()
    local validPlayers = {}
    
    -- Собираем всех валидных игроков (исключая себя)
    for _, player in ipairs(allPlayers) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            table.insert(validPlayers, player)
        end
    end
    
    if #validPlayers == 0 then
        Rayfield:Notify({
            Title = "Cycle Error", 
            Content = "No valid players found!",
            Duration = 3,
        })
        return
    end
    
    -- Находим текущий индекс или начинаем с начала
    local currentIndex = 1
    for i, player in ipairs(validPlayers) do
        if player.Name == FavoritePlayer then
            currentIndex = i
            break
        end
    end
    
    -- Переходим к следующему игроку
    local nextIndex = (currentIndex % #validPlayers) + 1
    local newFavorite = validPlayers[nextIndex]
    
    local previousFavorite = FavoritePlayer
    FavoritePlayer = newFavorite.Name
    
    -- Очищаем предыдущего фаворита
    if previousFavorite and previousFavorite ~= FavoritePlayer then
        local oldPlayer = Players:FindFirstChild(previousFavorite)
        if oldPlayer and oldPlayer.Character then
            RemoveESP(oldPlayer.Character)
        end
    end
    
    -- Обновляем ESP
    if states.favoriteESP then
        ToggleFavoriteESP(false)
        wait(0.1)
        ToggleFavoriteESP(true)
    end
    
    -- Обновляем GUI
    if FavoriteTextBox then
        FavoriteTextBox:Set(FavoritePlayer)
    end
    
    Rayfield:Notify({
        Title = "Favorite Cycled",
        Content = "Now tracking: " .. FavoritePlayer .. "\n(" .. nextIndex .. "/" .. #validPlayers .. ")",
        Duration = 4,
    })
end

local function GetTeamColor(player)
    if not player then return NeutralColor end
    if player.Team then
        return player.Team.TeamColor.Color
    end
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid:GetAttribute("Team") then
                local teamValue = humanoid:GetAttribute("Team")
                if teamValue == "Police" then
                    return Color3.fromRGB(0, 0, 255)
                elseif teamValue == "Criminal" then
                    return Color3.fromRGB(255, 0, 0)
                end
            end
        end
    end
    return NeutralColor
end

local function IsSameTeam(player)
    if not player then return false end
    if player.Team and LocalPlayer.Team then
        return player.Team == LocalPlayer.Team
    end
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local playerTeam = humanoid:GetAttribute("Team")
            local localTeam = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):GetAttribute("Team")
            return playerTeam == localTeam
        end
    end
    return false
end

local function IsVisible(targetPart)
    if not aimbotSettings.WallCheck then
        return true
    end
    local camera = workspace.CurrentCamera
    local origin = camera.CFrame.Position
    local target = targetPart.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    raycastParams.IgnoreWater = true
    local raycastResult = workspace:Raycast(origin, target - origin, raycastParams)
    if not raycastResult then
        return true
    end
    return false
end

local function UpdateFavoriteInfo()
    if not favoriteInfoLabel then return end
    
    local toolList = ""
    local toolCount = 0
    
    for toolName, _ in pairs(collectedTools) do
        toolCount = toolCount + 1
        if toolCount <= 8 then
            toolList = toolList .. "• " .. toolName .. "\n"
        end
    end
    
    if toolCount > 8 then
        toolList = toolList .. "... +" .. (toolCount - 8) .. " more\n"
    end
    
    local baseText = favoriteInfoLabel.Text:match("(Favorite:.-\nStatus:.-\nDistance:.-\nHP:.-\nTool:.-\n?)") or favoriteInfoLabel.Text
    
    favoriteInfoLabel.Text = baseText .. "Inventory (" .. toolCount .. "):\n" .. (toolList ~= "" and toolList or "Empty")
end

local function ClearCollectedTools()
    collectedTools = {}
    if favoriteInfoLabel then
        UpdateFavoriteInfo()
    end
end

local function TrackFavoriteTools(player)
    if favoriteBackpackConnection then
        favoriteBackpackConnection:Disconnect()
        favoriteBackpackConnection = nil
    end
    if favoriteCharacterConnection then
        favoriteCharacterConnection:Disconnect()
        favoriteCharacterConnection = nil
    end
    
    collectedTools = {}
    
    local function AddToolToCollection(tool)
        if tool:IsA("Tool") then
            collectedTools[tool.Name] = true
            UpdateFavoriteInfo()
        end
    end
    
    if player:FindFirstChild("Backpack") then
        local backpack = player.Backpack
        for _, tool in pairs(backpack:GetChildren()) do
            AddToolToCollection(tool)
        end
        favoriteBackpackConnection = backpack.ChildAdded:Connect(AddToolToCollection)
    end
    
    local function TrackCharacterTools(character)
        if character then
            for _, tool in pairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    AddToolToCollection(tool)
                end
            end
            favoriteCharacterConnection = character.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then
                    AddToolToCollection(child)
                end
            end)
        end
    end
    
    if player.Character then
        TrackCharacterTools(player.Character)
    end
    
    player.CharacterAdded:Connect(TrackCharacterTools)
end

local function TeleportToPlayer(player, behind)
    if not player or not player.Character then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "Player character not found!",
            Duration = 3,
        })
        return
    end
    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "Target root part not found!",
            Duration = 3,
        })
        return
    end
    if not LocalPlayer.Character then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "Your character not found!",
            Duration = 3,
        })
        return
    end
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "Your root part not found!",
            Duration = 3,
        })
        return
    end
    local targetPosition
    if behind then
        local offset = targetRoot.CFrame.LookVector * -4
        targetPosition = targetRoot.Position + offset + Vector3.new(0, 3, 0)
    else
        targetPosition = targetRoot.Position + Vector3.new(0, 3, 0)
    end
    local originalCollide = {}
    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollide[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    localRoot.CFrame = CFrame.new(targetPosition)
    wait(0.5)
    for part, collide in pairs(originalCollide) do
        if part and part.Parent then
            part.CanCollide = collide
        end
    end
    Rayfield:Notify({
        Title = "Teleport Success",
        Content = "Teleported to " .. player.Name .. (behind and " (behind)" or ""),
        Duration = 3,
    })
end

local function TeleportToRandomPlayer()
    local players = Players:GetPlayers()
    local validPlayers = {}
    for _, player in pairs(players) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validPlayers, player)
        end
    end
    if #validPlayers == 0 then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "No valid players found!",
            Duration = 3,
        })
        return
    end
    local randomPlayer = validPlayers[math.random(1, #validPlayers)]
    TeleportToPlayer(randomPlayer, false)
end

local function TeleportToFavorite()
    if not FavoritePlayer then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "No favorite player set!",
            Duration = 3,
        })
        return
    end
    local targetPlayer = Players:FindFirstChild(FavoritePlayer)
    if not targetPlayer then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "Favorite player not found!",
            Duration = 3,
        })
        return
    end
    TeleportToPlayer(targetPlayer, false)
end

local function TeleportBehindAimbotTarget()
    if not aimbotLocked then
        Rayfield:Notify({
            Title = "Teleport Error",
            Content = "No aimbot target locked!",
            Duration = 3,
        })
        return
    end
    TeleportToPlayer(aimbotLocked, true)
end

function SetupBinds()
    local flyBindConnection
    flyBindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Существующие бинды
        if input.KeyCode == Enum.KeyCode[teleportSettings.flyBind] then
            ToggleFly(not movementStates.fly)
        end
        if input.KeyCode == Enum.KeyCode[teleportSettings.behindBind] then
            TeleportBehindAimbotTarget()
        end
        
        -- НОВЫЕ БИНДЫ ДЛЯ ФАВОРИТОВ
        if input.KeyCode == Enum.KeyCode[favoriteBinds.setFavorite] then
            SetAimbotTargetAsFavorite()
        end
        
        if input.KeyCode == Enum.KeyCode[favoriteBinds.spectateFavorite] then
            ToggleSpectate(not states.spectateFavorite)
        end
        
        if input.KeyCode == Enum.KeyCode[favoriteBinds.cycleFavorite] then
            CycleToNextFavorite()
        end
    end)
    table.insert(connections, flyBindConnection)
end

local function EnableGodMode()
    if not LocalPlayer.Character then
        Rayfield:Notify({
            Title = "God Mode Error",
            Content = "Character not found!",
            Duration = 3,
        })
        return
    end
    for _, connection in pairs(godModeConnections) do
        connection:Disconnect()
    end
    godModeConnections = {}
    godModeHumanoids = {}
    local function ProtectHumanoid(humanoid)
        if godModeHumanoids[humanoid] then return end
        godModeHumanoids[humanoid] = true
        originalWalkSpeeds[humanoid] = humanoid.WalkSpeed
        originalJumpPowers[humanoid] = humanoid.JumpPower
        local healthConnection
        healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if combatStates.godMode and humanoid.Health < humanoid.MaxHealth then
                humanoid.Health = humanoid.MaxHealth
            end
        end)
        local diedConnection
        diedConnection = humanoid.Died:Connect(function()
            if combatStates.godMode then
                wait(2)
                if humanoid and humanoid.Parent then
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end)
        table.insert(godModeConnections, healthConnection)
        table.insert(godModeConnections, diedConnection)
    end
    local function FindAndProtectHumanoids(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            ProtectHumanoid(humanoid)
        end
        for _, child in pairs(character:GetDescendants()) do
            if child:IsA("Humanoid") and child ~= humanoid then
                ProtectHumanoid(child)
            end
        end
        for _, child in pairs(character:GetDescendants()) do
            if (child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("DoubleConstrainedValue")) and 
               (string.lower(child.Name):find("health") or string.lower(child.Name):find("hp")) then
                local healthConnection
                healthConnection = child:GetPropertyChangedSignal("Value"):Connect(function()
                    if combatStates.godMode then
                        if child:IsA("IntValue") then
                            child.Value = 100
                        elseif child:IsA("NumberValue") then
                            child.Value = 100.0
                        end
                    end
                end)
                table.insert(godModeConnections, healthConnection)
            end
        end
    end
    FindAndProtectHumanoids(LocalPlayer.Character)
    local characterAddedConnection
    characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        wait(1)
        if combatStates.godMode then
            FindAndProtectHumanoids(newCharacter)
        end
    end)
    table.insert(godModeConnections, characterAddedConnection)
    local protectionConnection
    protectionConnection = RunService.Heartbeat:Connect(function()
        if not combatStates.godMode then
            protectionConnection:Disconnect()
            return
        end
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health < humanoid.MaxHealth then
                humanoid.Health = humanoid.MaxHealth
            end
            if humanoid and humanoid.Health <= 0 then
                humanoid.Health = humanoid.MaxHealth
            end
        end
        if LocalPlayer.Character then
            for _, child in pairs(LocalPlayer.Character:GetDescendants()) do
                if (child:IsA("IntValue") or child:IsA("NumberValue")) and 
                   (string.lower(child.Name):find("health") or string.lower(child.Name):find("hp")) then
                    if child:IsA("IntValue") and child.Value < 100 then
                        child.Value = 100
                    elseif child:IsA("NumberValue") and child.Value < 100 then
                        child.Value = 100.0
                    end
                end
            end
        end
    end)
    table.insert(godModeConnections, protectionConnection)
    Rayfield:Notify({
        Title = "God Mode",
        Content = "God Mode activated! You are now immortal.\nWorks in any game!",
        Duration = 5,
    })
end

local function DisableGodMode()
    for _, connection in pairs(godModeConnections) do
        connection:Disconnect()
    end
    godModeConnections = {}
    for humanoid, _ in pairs(godModeHumanoids) do
        if humanoid and humanoid.Parent then
            if originalWalkSpeeds[humanoid] then
                humanoid.WalkSpeed = originalWalkSpeeds[humanoid]
            end
            if originalJumpPowers[humanoid] then
                humanoid.JumpPower = originalJumpPowers[humanoid]
            end
        end
    end
    godModeHumanoids = {}
    originalWalkSpeeds = {}
    originalJumpPowers = {}
    Rayfield:Notify({
        Title = "God Mode",
        Content = "God Mode deactivated",
        Duration = 3,
    })
end

function ToggleGodMode(state)
    combatStates.godMode = state
    if state then
        EnableGodMode()
    else
        DisableGodMode()
    end
end

local function UpdateAllPlayerESP()
    if not states.playerESP then return end
    
    local currentTime = tick()
    if currentTime - PerformanceManager.LastPlayerUpdate < PerformanceManager.UpdateIntervals.PlayerESP then
        return
    end
    PerformanceManager.LastPlayerUpdate = currentTime
    
    for i = #espObjects, 1, -1 do
        local espData = espObjects[i]
        if espData.Type == "Player" then
            local playerExists = false
            for _, player in pairs(Players:GetPlayers()) do
                if player == espData.Player then
                    playerExists = true
                    break
                end
            end
            if not playerExists or not espData.Player or espData.Player.Parent == nil then
                RemoveESP(espData.Target)
            end
        end
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if FavoritePlayer and player.Name == FavoritePlayer and states.favoriteESP then
                continue
            end
            local hasESP = false
            for _, espData in pairs(espObjects) do
                if espData.Type == "Player" and espData.Player == player then
                    hasESP = true
                    break
                end
            end
            if not hasESP and player.Character then
                CreatePlayerESP(player.Character, player, "Player")
            elseif hasESP and player.Character and not espObjects[player.Character] then
                RemoveESP(player.Character)
                CreatePlayerESP(player.Character, player, "Player")
            end
        end
    end
end

local function EnableFly()
    if not LocalPlayer.Character then 
        Rayfield:Notify({
            Title = "Fly Error",
            Content = "Character not found!",
            Duration = 3,
        })
        return 
    end
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then 
        Rayfield:Notify({
            Title = "Fly Error",
            Content = "Humanoid not found!",
            Duration = 3,
        })
        return 
    end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or 
                    LocalPlayer.Character:FindFirstChild("Torso") or 
                    LocalPlayer.Character:FindFirstChild("UpperTorso")
    if not rootPart then
        Rayfield:Notify({
            Title = "Fly Error",
            Content = "Root part not found!",
            Duration = 3,
        })
        return
    end
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.P = 10000
    flyBodyGyro.MaxTorque = Vector3.new(50000, 50000, 50000)
    flyBodyGyro.CFrame = rootPart.CFrame
    flyBodyGyro.Parent = rootPart
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
    flyBodyVelocity.Parent = rootPart
    humanoid.PlatformStand = true
    flyConnection = RunService.Heartbeat:Connect(function()
        if not flyEnabled or not LocalPlayer.Character or not humanoid or humanoid.Health <= 0 then
            return
        end
        local velocity = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            velocity = velocity + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            velocity = velocity - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            velocity = velocity - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            velocity = velocity + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            velocity = velocity + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            velocity = velocity - Vector3.new(0, 1, 0)
        end
        if velocity.Magnitude > 0 then
            velocity = velocity.Unit * movementSettings.flySpeed
        end
        flyBodyVelocity.Velocity = velocity
        if flyBodyGyro then
            flyBodyGyro.CFrame = Camera.CFrame
        end
    end)
    Rayfield:Notify({
        Title = "Fly",
        Content = "Fly activated! Use W/A/S/D/Space/Shift to fly",
        Duration = 5,
    })
end

local function DisableFly()
    flyEnabled = false
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
        if flyBodyGyro then
            flyBodyGyro:Destroy()
            flyBodyGyro = nil
        end
        if flyBodyVelocity then
            flyBodyVelocity:Destroy()
            flyBodyVelocity = nil
        end
    end
    Rayfield:Notify({
        Title = "Fly",
        Content = "Fly deactivated",
        Duration = 3,
    })
end

function ToggleFly(state)
    movementStates.fly = state
    flyEnabled = state
    if state then
        EnableFly()
    else
        DisableFly()
    end
end

function ToggleNoClip(state)
    movementStates.noClip = state
    if state then
        Rayfield:Notify({
            Title = "NoClip",
            Content = "NoClip activated",
            Duration = 5,
        })
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        local noClipConnection
        noClipConnection = RunService.Stepped:Connect(function()
            if movementStates.noClip and LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            else
                noClipConnection:Disconnect()
            end
        end)
        table.insert(connections, noClipConnection)
    else
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        Rayfield:Notify({
            Title = "NoClip",
            Content = "NoClip deactivated",
            Duration = 3,
        })
    end
end

function ToggleSpeed(state)
    movementStates.speedEnabled = state
    if state then
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = movementSettings.walkSpeed
            end
        end
        Rayfield:Notify({
            Title = "Speed",
            Content = "Speed activated: " .. movementSettings.walkSpeed,
            Duration = 3,
        })
    else
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end
        Rayfield:Notify({
            Title = "Speed",
            Content = "Speed deactivated",
            Duration = 3,
        })
    end
end

function ToggleHighJump(state)
    movementStates.highJump = state
    if state then
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.JumpPower = movementSettings.jumpPower
            end
        end
        Rayfield:Notify({
            Title = "High Jump",
            Content = "High Jump activated: " .. movementSettings.jumpPower,
            Duration = 3,
        })
    else
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.JumpPower = 50
            end
        end
        Rayfield:Notify({
            Title = "High Jump",
            Content = "High Jump deactivated",
            Duration = 3,
        })
    end
end

local function clearFavoriteESP()
    if currentFavoriteHighlight then
        currentFavoriteHighlight:Destroy()
        currentFavoriteHighlight = nil
    end
    if favoriteDistanceConnection then
        favoriteDistanceConnection:Disconnect()
        favoriteDistanceConnection = nil
    end
    currentFavoriteTarget = nil
    ClearCollectedTools()
end

local function createFavoriteESP(player)
    clearFavoriteESP()
    if not player or not player.Character then
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "Favorite: " .. player.Name .. "\nStatus: No character\nInventory (0):\nEmpty"
        end
        return
    end
    local character = player.Character
    local highlight = Instance.new("Highlight")
    highlight.Name = "Favorite_Highlight"
    highlight.Parent = character
    highlight.FillColor = Color3.fromRGB(255, 0, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.3
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    currentFavoriteTarget = player
    currentFavoriteHighlight = highlight
    
    TrackFavoriteTools(player)
    
    local function updateFavoriteInfo()
        if not character or not character.Parent then
            if favoriteInfoLabel then
                favoriteInfoLabel.Text = "Favorite: " .. player.Name .. "\nStatus: Dead\nInventory (" .. GetToolCount() .. "):\n" .. GetToolListText()
            end
            return
        end
        local distance = "N/A"
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            local targetPos = character:GetPivot().Position
            distance = math.floor((root.Position - targetPos).Magnitude) .. "m"
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local hpText = "HP: N/A"
        local status = "Alive"
        if humanoid then
            local health = math.floor(humanoid.Health)
            local maxHealth = math.floor(humanoid.MaxHealth)
            hpText = "HP: " .. health .. "/" .. maxHealth
            if humanoid.Health <= 0 then
                status = "Dead"
            end
        end
        local tool = character:FindFirstChildOfClass("Tool")
        local toolText = tool and tool.Name or "None"
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "Favorite: " .. player.Name .. 
                                   "\nStatus: " .. status ..
                                   "\nDistance: " .. distance ..
                                   "\n" .. hpText .. 
                                   "\nTool: " .. toolText ..
                                   "\nInventory (" .. GetToolCount() .. "):\n" .. GetToolListText()
        end
    end
    
    favoriteDistanceConnection = RunService.Heartbeat:Connect(updateFavoriteInfo)
    local charAddedConn
    charAddedConn = player.CharacterAdded:Connect(function(newCharacter)
        charAddedConn:Disconnect()
        ClearCollectedTools()
        wait(1)
        if states.favoriteESP then
            createFavoriteESP(player)
        end
    end)
end

function GetToolCount()
    local count = 0
    for _ in pairs(collectedTools) do
        count = count + 1
    end
    return count
end

function GetToolListText()
    local toolList = ""
    local toolCount = 0
    
    for toolName, _ in pairs(collectedTools) do
        toolCount = toolCount + 1
        if toolCount <= 8 then
            toolList = toolList .. "• " .. toolName .. "\n"
        end
    end
    
    if toolCount > 8 then
        toolList = toolList .. "... +" .. (toolCount - 8) .. " more\n"
    end
    
    return toolList ~= "" and toolList or "Empty"
end

function CreateFavoriteInfo()
    if favoriteInfoLabel and favoriteInfoLabel.Parent then
        favoriteInfoLabel:Destroy()
        favoriteInfoLabel = nil
    end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FavoriteInfo"
    screenGui.Parent = game:GetService("CoreGui")
    favoriteInfoLabel = Instance.new("TextLabel")
    favoriteInfoLabel.Name = "FavoriteInfoLabel"
    favoriteInfoLabel.Size = UDim2.new(0, 300, 0, 160)
    favoriteInfoLabel.Position = UDim2.new(1, -310, 0, 10)
    favoriteInfoLabel.AnchorPoint = Vector2.new(1, 0)
    favoriteInfoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    favoriteInfoLabel.BackgroundTransparency = 0.5
    favoriteInfoLabel.BorderSizePixel = 0
    favoriteInfoLabel.Text = "Favorite: None\nInventory (0):\nEmpty"
    favoriteInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    favoriteInfoLabel.TextSize = 14
    favoriteInfoLabel.Font = Enum.Font.GothamBold
    favoriteInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    favoriteInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
    favoriteInfoLabel.TextWrapped = true
    favoriteInfoLabel.Parent = screenGui
    return favoriteInfoLabel
end

function CreatePlayerESP(target, player, espType)
    if not target or not target:IsDescendantOf(Workspace) then return end
    if FavoritePlayer and player.Name == FavoritePlayer and states.favoriteESP then
        return nil
    end
    RemoveESP(target)
    local color
    if states.teamColorESP then
        color = GetTeamColor(player)
    else
        color = NeutralColor
    end
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerHL_" .. espType
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerInfo_" .. espType
    billboard.Size = UDim2.new(0, 200, 0, 80)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = target:IsA("BasePart") and target or (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart"))
    billboard.Parent = target
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.25, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = TextSize
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    local espData = {
        Object = highlight,
        Billboard = billboard,
        Target = target,
        Player = player,
        Type = espType,
        Color = color,
        NameLabel = nameLabel
    }
    table.insert(espObjects, espData)
    if states.playerHP then
        AddHPToESP(espData)
    end
    if states.playerTool then
        AddToolToESP(espData)
    end
    return highlight
end

function AddHPToESP(espData)
    local target = espData.Target
    local billboard = espData.Billboard
    local color = espData.Color
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Size = UDim2.new(1, 0, 0.25, 0)
    hpLabel.Position = UDim2.new(0, 0, 0.25, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    hpLabel.TextStrokeTransparency = 0
    hpLabel.TextSize = TextSize - 2
    hpLabel.Font = Enum.Font.Gotham
    hpLabel.Parent = billboard
    local function UpdateHP()
        if not humanoid or not humanoid.Parent then
            if espData.HPConnection then
                espData.HPConnection:Disconnect()
                espData.HPConnection = nil
            end
            return
        end
        local health = math.floor(humanoid.Health)
        local maxHealth = math.floor(humanoid.MaxHealth)
        hpLabel.Text = "HP: " .. health .. "/" .. maxHealth
        if humanoid.Health / humanoid.MaxHealth > 0.5 then
            hpLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        elseif humanoid.Health / humanoid.MaxHealth > 0.2 then
            hpLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        else
            hpLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end
    UpdateHP()
    local hpConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(UpdateHP)
    espData.HPConnection = hpConnection
    espData.HPLabel = hpLabel
end

function AddToolToESP(espData)
    local target = espData.Target
    local billboard = espData.Billboard
    local toolLabel = Instance.new("TextLabel")
    toolLabel.Size = UDim2.new(1, 0, 0.25, 0)
    toolLabel.Position = UDim2.new(0, 0, 0.5, 0)
    toolLabel.BackgroundTransparency = 1
    toolLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    toolLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    toolLabel.TextStrokeTransparency = 0
    toolLabel.TextSize = TextSize - 3
    toolLabel.Font = Enum.Font.Gotham
    toolLabel.Parent = billboard
    local function UpdateTool()
        if not target or not target.Parent then
            if espData.ToolConnection then
                espData.ToolConnection:Disconnect()
                espData.ToolConnection = nil
            end
            return
        end
        local tool = target:FindFirstChildOfClass("Tool")
        if tool then
            toolLabel.Text = "Tool: " .. tool.Name
        else
            toolLabel.Text = "Tool: None"
        end
    end
    UpdateTool()
    local toolConnection = RunService.Heartbeat:Connect(UpdateTool)
    espData.ToolConnection = toolConnection
    espData.ToolLabel = toolLabel
end

function UpdateAllTextSizes()
    for _, espData in pairs(espObjects) do
        if espData.NameLabel then
            espData.NameLabel.TextSize = TextSize
        end
        if espData.HPLabel then
            espData.HPLabel.TextSize = TextSize - 2
        end
        if espData.ToolLabel then
            espData.ToolLabel.TextSize = TextSize - 3
        end
    end
end

function RemoveESP(target)
    for i = #espObjects, 1, -1 do
        local espData = espObjects[i]
        if espData.Target == target then
            if espData.HPConnection then
                pcall(function() espData.HPConnection:Disconnect() end)
            end
            if espData.ToolConnection then
                pcall(function() espData.ToolConnection:Disconnect() end)
            end
            pcall(function() 
                if espData.Object then espData.Object:Destroy() end
                if espData.Billboard then espData.Billboard:Destroy() end
            end)
            table.remove(espObjects, i)
        end
    end
end

function ClearESPByType(espType)
    for i = #espObjects, 1, -1 do
        local espData = espObjects[i]
        if espData.Type == espType then
            if espData.HPConnection then
                pcall(function() espData.HPConnection:Disconnect() end)
            end
            if espData.ToolConnection then
                pcall(function() espData.ToolConnection:Disconnect() end)
            end
            pcall(function() 
                if espData.Object then espData.Object:Destroy() end
                if espData.Billboard then espData.Billboard:Destroy() end
            end)
            table.remove(espObjects, i)
        end
    end
end

function TogglePlayerESP(state)
    states.playerESP = state
    if not state then
        ClearESPByType("Player")
        return
    end
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= LocalPlayer then
            if FavoritePlayer and otherPlayer.Name == FavoritePlayer and states.favoriteESP then
                continue
            end
            if otherPlayer.Character then
                CreatePlayerESP(otherPlayer.Character, otherPlayer, "Player")
            end
        end
    end
    local playerAddedConn
    playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if states.playerESP then
            player.CharacterAdded:Connect(function(char)
                wait(1)
                if states.playerESP then
                    if FavoritePlayer and player.Name == FavoritePlayer and states.favoriteESP then
                        return
                    end
                    CreatePlayerESP(char, player, "Player")
                end
            end)
            if player.Character then
                wait(1)
                CreatePlayerESP(player.Character, player, "Player")
            end
        end
    end)
    table.insert(connections, playerAddedConn)
    local playerRemovingConn
    playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            RemoveESP(player.Character)
        end
    end)
    table.insert(connections, playerRemovingConn)
end

function ToggleHPESP(state)
    states.playerHP = state
    if state then
        for _, espData in pairs(espObjects) do
            if (espData.Type == "Player" or espData.Type == "Favorite") and not espData.HPConnection then
                AddHPToESP(espData)
            end
        end
    else
        for _, espData in pairs(espObjects) do
            if espData.HPConnection then
                pcall(function() espData.HPConnection:Disconnect() end)
                espData.HPConnection = nil
            end
            if espData.HPLabel then
                espData.HPLabel:Destroy()
                espData.HPLabel = nil
            end
        end
    end
end

function ToggleToolESP(state)
    states.playerTool = state
    if state then
        for _, espData in pairs(espObjects) do
            if (espData.Type == "Player" or espData.Type == "Favorite") and not espData.ToolConnection then
                AddToolToESP(espData)
            end
        end
    else
        for _, espData in pairs(espObjects) do
            if espData.ToolConnection then
                pcall(function() espData.ToolConnection:Disconnect() end)
                espData.ToolConnection = nil
            end
            if espData.ToolLabel then
                espData.ToolLabel:Destroy()
                espData.ToolLabel = nil
            end
        end
    end
end

function ToggleTeamColorESP(state)
    states.teamColorESP = state
    for _, espData in pairs(espObjects) do
        if espData.Type == "Player" and espData.Player then
            local newColor
            if state then
                newColor = GetTeamColor(espData.Player)
            else
                newColor = NeutralColor
            end
            if espData.Object then
                espData.Object.FillColor = newColor
                espData.Object.OutlineColor = newColor
            end
            if espData.NameLabel then
                espData.NameLabel.TextColor3 = newColor
            end
        end
    end
end

function ToggleSafeESP(state)
    states.safeESP = state
    if not state then
        ClearESPByType("Safe")
        return
    end
    
    local currentTime = tick()
    if currentTime - PerformanceManager.LastSafeScan < PerformanceManager.UpdateIntervals.SafeESP then
        return
    end
    PerformanceManager.LastSafeScan = currentTime
    
    ScanSafes()
end

function ScanSafes()
    ClearESPByType("Safe")
    local bredMakurz = Workspace:FindFirstChild("Map")
    if bredMakurz then
        bredMakurz = bredMakurz:FindFirstChild("BredMakurz")
    end
    if bredMakurz then
        for _, safe in pairs(bredMakurz:GetChildren()) do
            local posPart = safe:FindFirstChild("PosPart")
            local values = safe:FindFirstChild("Values")
            if posPart and values then
                local broken = values:FindFirstChild("Broken")
                if broken and not broken.Value then
                    local color
                    if string.find(safe.Name:lower(), "register") then
                        color = Color3.fromRGB(255, 165, 0)
                    else
                        color = Color3.fromRGB(255, 255, 0)
                    end
                    CreateSafeESP(safe, color)
                end
            end
        end
    end
end

function CreateSafeESP(safe, color)
    if not safe or not safe:IsDescendantOf(Workspace) then return end
    RemoveESP(safe)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Safe"
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = safe
    table.insert(espObjects, {
        Object = highlight,
        Target = safe,
        Type = "Safe"
    })
end

function ToggleDealerESP(state)
    states.dealerESP = state
    if not state then
        ClearESPByType("Dealer")
        return
    end
    
    local currentTime = tick()
    if currentTime - PerformanceManager.LastDealerScan < PerformanceManager.UpdateIntervals.DealerESP then
        return
    end
    PerformanceManager.LastDealerScan = currentTime
    
    ScanDealers()
end

function ScanDealers()
    ClearESPByType("Dealer")
    local dealerNames = {"Dealer", "Black Market Dealer", "Vendor", "Seller", "Merchant"}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            for _, dealerName in pairs(dealerNames) do
                if obj.Name:lower():find(dealerName:lower()) then
                    CreateDealerESP(obj)
                end
            end
        end
    end
end

function CreateDealerESP(dealer)
    if not dealer or not dealer:IsDescendantOf(Workspace) then return end
    RemoveESP(dealer)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Dealer"
    highlight.FillColor = Color3.fromRGB(0, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = dealer
    table.insert(espObjects, {
        Object = highlight,
        Target = dealer,
        Type = "Dealer"
    })
end

function ToggleFavoriteESP(state)
    states.favoriteESP = state
    if not state then
        clearFavoriteESP()
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "Favorite: None\nInventory (0):\nEmpty"
        end
        return
    end
    if not FavoritePlayer or FavoritePlayer == "" then
        Rayfield:Notify({
            Title = "Error",
            Content = "Enter player name first!",
            Duration = 3,
        })
        states.favoriteESP = false
        return
    end
    local targetPlayer = Players:FindFirstChild(FavoritePlayer)
    if not targetPlayer then
        Rayfield:Notify({
            Title = "Error",
            Content = "Player not found: " .. FavoritePlayer,
            Duration = 3,
        })
        states.favoriteESP = false
        return
    end
    if targetPlayer == LocalPlayer then
        Rayfield:Notify({
            Title = "Error",
            Content = "Cannot set yourself as favorite!",
            Duration = 3,
        })
        states.favoriteESP = false
        return
    end
    if not favoriteInfoLabel then
        CreateFavoriteInfo()
    end
    if targetPlayer.Character then
        RemoveESP(targetPlayer.Character)
    end
    createFavoriteESP(targetPlayer)
    Rayfield:Notify({
        Title = "Favorite ESP",
        Content = "Now tracking: " .. FavoritePlayer,
        Duration = 3,
    })
end

function ClearFavorite()
    local previousFavorite = FavoritePlayer
    FavoritePlayer = nil
    
    if FavoriteTextBox then
        FavoriteTextBox:Set("")
    end
    
    if states.favoriteESP then
        ToggleFavoriteESP(false)
    end
    
    if states.spectateFavorite then
        ToggleSpectate(false)
    end
    
    if favoriteInfoLabel then
        favoriteInfoLabel.Text = "Favorite: None\nInventory (0):\nEmpty"
    end
    
    ClearCollectedTools()
    
    Rayfield:Notify({
        Title = "Favorite Cleared",
        Content = "Removed: " .. (previousFavorite or "None"),
        Duration = 3,
    })
end

function ToggleTriggerBot(state)
    combatStates.triggerBot = state
    if state then
        Rayfield:Notify({
            Title = "Trigger Bot",
            Content = "Trigger Bot activated",
            Duration = 3,
        })
    else
        Rayfield:Notify({
            Title = "Trigger Bot",
            Content = "Trigger Bot deactivated",
            Duration = 3,
        })
    end
end

local function CancelLock()
    aimbotLocked = nil
    if aimbotFOVCircle then
        aimbotFOVCircle.Color = Color3.fromRGB(255, 255, 255)
    end
end

local function GetClosestPlayer()
    if not aimbotLocked then
        local requiredDistance = aimbotSettings.FOV
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChildOfClass("Humanoid") then
                    if aimbotSettings.TeamCheck and IsSameTeam(player) then continue end
                    if aimbotSettings.AliveCheck and player.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
                    if aimbotSettings.WallCheck and not IsVisible(player.Character.Head) then continue end
                    local vector, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                    local distance = (Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2.new(vector.X, vector.Y)).Magnitude
                    if distance < requiredDistance and onScreen then
                        requiredDistance = distance
                        aimbotLocked = player
                    end
                end
            end
        end
    else
        local locked = aimbotLocked
        if aimbotSettings.AutoUnlock and locked and locked.Character and locked.Character:FindFirstChild("Head") then
            local vector, onScreen = Camera:WorldToViewportPoint(locked.Character.Head.Position)
            local distance = (Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2.new(vector.X, vector.Y)).Magnitude
            if distance > aimbotSettings.FOV or not onScreen then
                CancelLock()
                return
            end
        end
        if locked and locked.Character and locked.Character:FindFirstChild("Head") then
            if not locked.Character:FindFirstChildOfClass("Humanoid") then
                CancelLock()
                return
            end
            if aimbotSettings.AliveCheck and locked.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                CancelLock()
                return
            end
            if aimbotSettings.WallCheck and not IsVisible(locked.Character.Head) then
                CancelLock()
                return
            end
        else
            CancelLock()
            return
        end
    end
end

function InitializeAimbot()
    aimbotFOVCircle = Drawing.new("Circle")
    aimbotFOVCircle.Visible = aimbotSettings.ShowFOV
    aimbotFOVCircle.Radius = aimbotSettings.FOV
    aimbotFOVCircle.Color = Color3.fromRGB(255, 255, 255)
    aimbotFOVCircle.Thickness = 1
    aimbotFOVCircle.Transparency = 1
    aimbotFOVCircle.Filled = false
    aimbotConnections.render = RunService.RenderStepped:Connect(function()
        if aimbotSettings.ShowFOV and combatStates.aimBot then
            aimbotFOVCircle.Visible = true
            aimbotFOVCircle.Radius = aimbotSettings.FOV
            aimbotFOVCircle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        else
            aimbotFOVCircle.Visible = false
        end
        if aimbotRunning and combatStates.aimBot then
            GetClosestPlayer()
            if aimbotLocked then
                if aimbotSettings.ThirdPerson then
                    local vector = Camera:WorldToViewportPoint(aimbotLocked.Character.Head.Position)
                    mousemoverel(
                        (vector.X - UserInputService:GetMouseLocation().X) * aimbotSettings.ThirdPersonSensitivity,
                        (vector.Y - UserInputService:GetMouseLocation().Y) * aimbotSettings.ThirdPersonSensitivity
                    )
                else
                    if aimbotSettings.Sensitivity > 0 then
                        local tween = TweenService:Create(
                            Camera, 
                            TweenInfo.new(aimbotSettings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), 
                            {CFrame = CFrame.new(Camera.CFrame.Position, aimbotLocked.Character.Head.Position)}
                        )
                        tween:Play()
                    else
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimbotLocked.Character.Head.Position)
                    end
                end
                aimbotFOVCircle.Color = Color3.fromRGB(255, 70, 70)
            end
        end
    end)
    aimbotConnections.inputBegan = UserInputService.InputBegan:Connect(function(input)
        if combatStates.aimBot then
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                if aimbotSettings.Toggle then
                    aimbotRunning = not aimbotRunning
                    if not aimbotRunning then
                        CancelLock()
                    end
                else
                    aimbotRunning = true
                end
            end
        end
    end)
    aimbotConnections.inputEnded = UserInputService.InputEnded:Connect(function(input)
        if combatStates.aimBot and not aimbotSettings.Toggle then
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                aimbotRunning = false
                CancelLock()
            end
        end
    end)
end

function ToggleAimbot(state)
    combatStates.aimBot = state
    if state then
        InitializeAimbot()
        Rayfield:Notify({
            Title = "Aimbot",
            Content = "Aimbot activated",
            Duration = 3,
        })
    else
        for _, connection in pairs(aimbotConnections) do
            connection:Disconnect()
        end
        aimbotConnections = {}
        if aimbotFOVCircle then
            aimbotFOVCircle:Remove()
            aimbotFOVCircle = nil
        end
        aimbotRunning = false
        aimbotLocked = nil
        Rayfield:Notify({
            Title = "Aimbot",
            Content = "Aimbot deactivated",
            Duration = 3,
        })
    end
end

local triggerBotConnection
triggerBotConnection = RunService.Heartbeat:Connect(function()
    if not combatStates.triggerBot then return end
    if not LocalPlayer.Character then return end
    local target = Mouse.Target
    if target and target.Parent then
        local humanoid = target.Parent:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local player = Players:GetPlayerFromCharacter(target.Parent)
            if player and player ~= LocalPlayer then
                if aimbotSettings.TeamCheck and IsSameTeam(player) then
                    return
                end
                mouse1click()
            end
        end
    end
end)

-- Система автоматической очистки памяти
local cleanupConnection
cleanupConnection = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if currentTime - PerformanceManager.LastESPCleanup < PerformanceManager.CleanupInterval then
        return
    end
    PerformanceManager.LastESPCleanup = currentTime
    
    local cleanedCount = 0
    for i = #espObjects, 1, -1 do
        local espData = espObjects[i]
        if not espData.Target or not espData.Target.Parent then
            if espData.HPConnection then
                pcall(function() espData.HPConnection:Disconnect() end)
            end
            if espData.ToolConnection then
                pcall(function() espData.ToolConnection:Disconnect() end)
            end
            pcall(function() 
                if espData.Object then espData.Object:Destroy() end
                if espData.Billboard then espData.Billboard:Destroy() end
            end)
            table.remove(espObjects, i)
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 5 then
        wait(0.1)
        game:GetService("GC"):CollectGarbage()
    end
end)
table.insert(connections, cleanupConnection)

-- Главный цикл обновления ESP
local espUpdateConnection
espUpdateConnection = RunService.Heartbeat:Connect(function()
    if states.playerESP then
        UpdateAllPlayerESP()
    end
end)
table.insert(connections, espUpdateConnection)

local Window = Rayfield:CreateWindow({
    Name = "DANART SIGMA",
    LoadingTitle = "Loading DANART SIGMA...",
    LoadingSubtitle = "ESP + Combat + Movement + Spectate - Ultimate Version",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "DANART_SIGMA",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
})

local Tab1 = Window:CreateTab("ESP", 4483362458)
local Section0 = Tab1:CreateSection("Text Settings")
local TextSizeSlider = Tab1:CreateSlider({
    Name = "Text Size",
    Range = {8, 20},
    Increment = 1,
    Suffix = "px",
    CurrentValue = TextSize,
    Flag = "TextSize",
    Callback = function(Value)
        TextSize = Value
        UpdateAllTextSizes()
    end,
})
local NeutralColorPicker = Tab1:CreateColorPicker({
    Name = "Neutral Player Color",
    Color = NeutralColor,
    Flag = "NeutralColor",
    Callback = function(Value)
        NeutralColor = Value
        if not states.teamColorESP then
            ToggleTeamColorESP(false)
        end
    end,
})
local Section1 = Tab1:CreateSection("Player ESP")
local TogglePlayer = Tab1:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "PlayerESP",
    Callback = function(Value)
        TogglePlayerESP(Value)
    end,
})
local ToggleHP = Tab1:CreateToggle({
    Name = "Show HP",
    CurrentValue = false,
    Flag = "PlayerHP",
    Callback = function(Value)
        ToggleHPESP(Value)
    end,
})
local ToggleTool = Tab1:CreateToggle({
    Name = "Show Tool",
    CurrentValue = false,
    Flag = "PlayerTool",
    Callback = function(Value)
        ToggleToolESP(Value)
    end,
})
local ToggleTeamColor = Tab1:CreateToggle({
    Name = "Team Color ESP",
    CurrentValue = false,
    Flag = "TeamColorESP",
    Callback = function(Value)
        ToggleTeamColorESP(Value)
    end,
})
local Section2 = Tab1:CreateSection("Favorite Player")
local FavoriteTextBox = Tab1:CreateInput({
    Name = "Player Name",
    PlaceholderText = "Enter player name",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        FavoritePlayer = Text
        if Text and Text ~= "" then
            Rayfield:Notify({
                Title = "Favorite Set",
                Content = "Favorite: " .. Text,
                Duration = 3,
            })
        end
    end,
})
local ToggleFavorite = Tab1:CreateToggle({
    Name = "Favorite ESP",
    CurrentValue = false,
    Flag = "FavoriteESP",
    Callback = function(Value)
        ToggleFavoriteESP(Value)
    end,
})
local ToggleSpectate = Tab1:CreateToggle({
    Name = "Spectate Favorite",
    CurrentValue = false,
    Flag = "SpectateFavorite",
    Callback = function(Value)
        ToggleSpectate(Value)
    end,
})
local ClearFavoriteBtn = Tab1:CreateButton({
    Name = "Clear Favorite",
    Callback = function()
        ClearFavorite()
    end,
})
local Section3 = Tab1:CreateSection("Objects ESP")
local ToggleSafe = Tab1:CreateToggle({
    Name = "Safe ESP",
    CurrentValue = false,
    Flag = "SafeESP",
    Callback = function(Value)
        ToggleSafeESP(Value)
    end,
})
local ToggleDealer = Tab1:CreateToggle({
    Name = "Dealer ESP",
    CurrentValue = false,
    Flag = "DealerESP",
    Callback = function(Value)
        ToggleDealerESP(Value)
    end,
})
local Tab2 = Window:CreateTab("Combat", 4483362458)
local SectionCombat0 = Tab2:CreateSection("God Mode")
local ToggleGodModeBtn = Tab2:CreateToggle({
    Name = "God Mode (Universal Infinite HP)",
    CurrentValue = false,
    Flag = "GodMode",
    Callback = function(Value)
        ToggleGodMode(Value)
    end,
})
local GodModeInfo = Tab2:CreateLabel("God Mode: Universal immortality that works in ANY game!\nProtects: Humanoids, Health Values, HP systems")
local SectionCombat1 = Tab2:CreateSection("Trigger Bot")
local ToggleTrigger = Tab2:CreateToggle({
    Name = "Trigger Bot",
    CurrentValue = false,
    Flag = "TriggerBot",
    Callback = function(Value)
        ToggleTriggerBot(Value)
    end,
})
local TriggerInfo = Tab2:CreateLabel("Trigger Bot: Automatically shoots when aiming at enemies")
local SectionCombat2 = Tab2:CreateSection("Aimbot")
local ToggleAimbotBtn = Tab2:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "Aimbot",
    Callback = function(Value)
        ToggleAimbot(Value)
    end,
})
local AimbotTeamCheck = Tab2:CreateToggle({
    Name = "Team Check",
    CurrentValue = aimbotSettings.TeamCheck,
    Flag = "AimbotTeamCheck",
    Callback = function(Value)
        aimbotSettings.TeamCheck = Value
    end,
})
local AimbotAliveCheck = Tab2:CreateToggle({
    Name = "Alive Check",
    CurrentValue = aimbotSettings.AliveCheck,
    Flag = "AimbotAliveCheck",
    Callback = function(Value)
        aimbotSettings.AliveCheck = Value
    end,
})
local AimbotWallCheck = Tab2:CreateToggle({
    Name = "Wall Check (No Wallhack)",
    CurrentValue = aimbotSettings.WallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(Value)
        aimbotSettings.WallCheck = Value
    end,
})
local AimbotAutoUnlock = Tab2:CreateToggle({
    Name = "Auto Unlock (Exit FOV)",
    CurrentValue = aimbotSettings.AutoUnlock,
    Flag = "AimbotAutoUnlock",
    Callback = function(Value)
        aimbotSettings.AutoUnlock = Value
    end,
})
local AimbotFOVSlider = Tab2:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = aimbotSettings.FOV,
    Flag = "AimbotFOV",
    Callback = function(Value)
        aimbotSettings.FOV = Value
    end,
})
local AimbotShowFOV = Tab2:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = aimbotSettings.ShowFOV,
    Flag = "AimbotShowFOV",
    Callback = function(Value)
        aimbotSettings.ShowFOV = Value
    end,
})
local AimbotInfo = Tab2:CreateLabel("Aimbot: Hold Right Mouse Button to activate\nLock Part: Head (Fixed)\nWall Check: Only aim at visible players\nAuto Unlock: Unlocks when target leaves FOV")
local Tab3 = Window:CreateTab("Movement", 4483362458)
local SectionMovement1 = Tab3:CreateSection("Movement Hacks")
local ToggleNoClipBtn = Tab3:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Flag = "NoClip",
    Callback = function(Value)
        ToggleNoClip(Value)
    end,
})
local ToggleFlyBtn = Tab3:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(Value)
        ToggleFly(Value)
    end,
})
local FlySpeedSlider = Tab3:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = movementSettings.flySpeed,
    Flag = "FlySpeed",
    Callback = function(Value)
        movementSettings.flySpeed = Value
    end,
})
local SpeedToggle = Tab3:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedHack",
    Callback = function(Value)
        ToggleSpeed(Value)
    end,
})
local SpeedSlider = Tab3:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 100},
    Increment = 2,
    Suffix = "studs",
    CurrentValue = movementSettings.walkSpeed,
    Flag = "WalkSpeed",
    Callback = function(Value)
        movementSettings.walkSpeed = Value
        if movementStates.speedEnabled then
            ToggleSpeed(true)
        end
    end,
})
local HighJumpToggle = Tab3:CreateToggle({
    Name = "High Jump",
    CurrentValue = false,
    Flag = "HighJump",
    Callback = function(Value)
        ToggleHighJump(Value)
    end,
})
local JumpPowerSlider = Tab3:CreateSlider({
    Name = "Jump Power",
    Range = {50, 200},
    Increment = 10,
    Suffix = "power",
    CurrentValue = movementSettings.jumpPower,
    Flag = "JumpPower",
    Callback = function(Value)
        movementSettings.jumpPower = Value
        if movementStates.highJump then
            ToggleHighJump(true)
        end
    end,
})
local MovementInfo = Tab3:CreateLabel("Fly Controls:\nW - Forward\nA - Left\nS - Backward\nD - Right\nSpace - Up\nShift/Ctrl - Down")
local Tab4 = Window:CreateTab("Teleport", 4483362458)
local SectionTeleport1 = Tab4:CreateSection("Player Teleport")
local TeleportRandomBtn = Tab4:CreateButton({
    Name = "Teleport to Random Player",
    Callback = function()
        TeleportToRandomPlayer()
    end,
})
local TeleportFavoriteBtn = Tab4:CreateButton({
    Name = "Teleport to Favorite",
    Callback = function()
        TeleportToFavorite()
    end,
})
local TeleportBehindBtn = Tab4:CreateButton({
    Name = "Teleport Behind Aimbot Target",
    Callback = function()
        TeleportBehindAimbotTarget()
    end,
})
local SectionTeleport2 = Tab4:CreateSection("Keybinds")
local FlyBindInput = Tab4:CreateInput({
    Name = "Fly Toggle Bind",
    PlaceholderText = "F",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            teleportSettings.flyBind = Text:upper()
            Rayfield:Notify({
                Title = "Bind Set",
                Content = "Fly bind: " .. Text,
                Duration = 3,
            })
            SetupBinds()
        end
    end,
})
local BehindBindInput = Tab4:CreateInput({
    Name = "Teleport Behind Bind",
    PlaceholderText = "T",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            teleportSettings.behindBind = Text:upper()
            Rayfield:Notify({
                Title = "Bind Set",
                Content = "Teleport behind bind: " .. Text,
                Duration = 3,
            })
            SetupBinds()
        end
    end,
})
local TeleportInfo = Tab4:CreateLabel("Current Binds:\nFly: " .. teleportSettings.flyBind .. "\nTeleport Behind: " .. teleportSettings.behindBind .. "\n\nNote: Binds work only when GUI is open")

-- НОВАЯ ВКЛАДКА ДЛЯ БИНДОВ ФАВОРИТОВ
local Tab5 = Window:CreateTab("Binds", 4483362458)
local SectionBinds1 = Tab5:CreateSection("Favorite Binds")

local FavoriteBindInput = Tab5:CreateInput({
    Name = "Set Favorite Bind",
    PlaceholderText = favoriteBinds.setFavorite,
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            favoriteBinds.setFavorite = Text:upper()
            Rayfield:Notify({
                Title = "Favorite Bind Set",
                Content = "Set favorite: " .. Text,
                Duration = 3,
            })
            SetupBinds()
        end
    end,
})

local SpectateBindInput = Tab5:CreateInput({
    Name = "Spectate Toggle Bind", 
    PlaceholderText = favoriteBinds.spectateFavorite,
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            favoriteBinds.spectateFavorite = Text:upper()
            Rayfield:Notify({
                Title = "Spectate Bind Set",
                Content = "Spectate toggle: " .. Text,
                Duration = 3,
            })
            SetupBinds()
        end
    end,
})

local CycleBindInput = Tab5:CreateInput({
    Name = "Cycle Favorite Bind (Optional)",
    PlaceholderText = favoriteBinds.cycleFavorite,
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            favoriteBinds.cycleFavorite = Text:upper()
            Rayfield:Notify({
                Title = "Cycle Bind Set",
                Content = "Cycle favorites: " .. Text,
                Duration = 3,
            })
            SetupBinds()
        end
    end,
})

local BindsInfo = Tab5:CreateLabel("Current Favorite Binds:\nSet Favorite: " .. favoriteBinds.setFavorite .. 
                                  "\nSpectate Toggle: " .. favoriteBinds.spectateFavorite ..
                                  "\nCycle Favorite: " .. favoriteBinds.cycleFavorite ..
                                  "\n\nHow to use:\n1. Aim at player with aimbot" ..
                                  "\n2. Press " .. favoriteBinds.setFavorite .. " to set as favorite" ..
                                  "\n3. Press " .. favoriteBinds.spectateFavorite .. " to spectate" ..
                                  "\n4. Previous favorite is automatically removed")

local Section4 = Tab1:CreateSection("Utility")
local ClearButton = Tab1:CreateButton({
    Name = "Clear All ESP",
    Callback = function()
        for i = #espObjects, 1, -1 do
            local espData = espObjects[i]
            if espData.HPConnection then
                pcall(function() espData.HPConnection:Disconnect() end)
            end
            if espData.ToolConnection then
                pcall(function() espData.ToolConnection:Disconnect() end)
            end
            pcall(function() 
                if espData.Object then espData.Object:Destroy() end
                if espData.Billboard then espData.Billboard:Destroy() end
            end)
            table.remove(espObjects, i)
        end
        clearFavoriteESP()
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "Favorite: None\nInventory (0):\nEmpty"
        end
        Rayfield:Notify({
            Title = "ESP Cleared",
            Content = "All ESP removed",
            Duration = 3,
        })
    end,
})
CreateFavoriteInfo()
SetupBinds()
Rayfield:Notify({
    Title = "DANART SIGMA Loaded",
    Content = "Ultimate version with advanced spectate system!\nSpectate features:\n- Health bar for favorite player (bottom left)\n- Health bars for nearby players (above heads)\n- Automatic cleanup and optimization\nEnjoy DANART SIGMA!",
    Duration = 6,
})
print("DANART SIGMA Loaded - Ultimate Version with Advanced Spectate System!")
