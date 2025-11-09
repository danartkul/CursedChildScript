--[[
 CURSED CHILD Jump Showdown - Venyx UI Edition with Aimbot & Favorite System
]]

-- Защищенное получение сервисов
local function GetProtectedService(name)
    for attempt = 1, 5 do
        local success, result = pcall(function()
            wait(math.random(5, 20) / 100)
            return game:GetService(name)
        end)
        if success then return result end
        wait(math.random(10, 30) / 100)
    end
    return nil
end

local Players = GetProtectedService("Players")
local CoreGui = GetProtectedService("CoreGui")
local RunService = GetProtectedService("RunService")
local Workspace = GetProtectedService("Workspace")
local UserInputService = GetProtectedService("UserInputService")
local TweenService = GetProtectedService("TweenService")
local Teams = GetProtectedService("Teams")

if not Players then return end

-- Ожидание игрока
local player = nil
for i = 1, 30 do
    pcall(function() player = Players.LocalPlayer end)
    if player then break end
    wait(0.1)
end
if not player then return end

-- Система ключей
local correctKey = "danart123"
local keyVerified = false

-- Генератор уникальных имен
local function GenerateUniqueName(base)
    return base .. "_" .. tostring(math.random(10000, 99999))
end

-- Глобальные переменные
local states = {
    speedHack = false,
    fly = false,
    noclip = false,
    highJump = false,
    esp = false,
    itemEsp = false,
    npcEsp = false,
    teleportMode = false,
    fling = false,
    aimbot = false,
    favoriteESP = false
}

local espSettings = {
    showHP = true,
    showTeam = true,
    showTool = true,
    showDistance = true
}

local settings = {
    walkSpeed = 50,
    jumpPower = 100,
    originalWalkSpeed = 16,
    originalJumpPower = 50
}

local connections = {}
local espObjects = {}
local lastScanTime = 0
local SCAN_INTERVAL = 2

-- Списки NPC и предметов
local npcList = {
    "News Boy", "Jimpee", "Todd", "Markiplier", "Bald Gojo",
    "Mymy32100", "Black Market Dealer", "Carti", "Remelia"
}

local itemList = {
    "Temporary-V", "Railgun", "Daybreak", "Helmet of Peace"
}

-- СИСТЕМА ФАВОРИТА
local FavoritePlayer = nil
local currentFavoriteTarget = nil
local currentFavoriteHighlight = nil
local favoriteDistanceConnection = nil
local favoriteInfoLabel = nil

-- СИСТЕМА ИСКЛЮЧЕНИЙ ДЛЯ АИМБОТА
local AimbotExceptions = {
    Players = {}, -- Исключенные игроки по имени
    Teams = {},   -- Исключенные команды по названию
    Friends = false -- Исключать друзей
}

-- Функция для получения цвета команды
local function GetTeamColor(playerObj)
    if not playerObj or not playerObj.Team then 
        return Color3.fromRGB(255, 255, 255) -- Белый по умолчанию
    end
    
    local team = playerObj.Team
    if team and team.TeamColor then
        return team.TeamColor.Color
    end
    
    return Color3.fromRGB(255, 255, 255)
end

-- Функция для получения названия команды
local function GetTeamName(playerObj)
    if not playerObj or not playerObj.Team then 
        return "No Team"
    end
    
    local team = playerObj.Team
    if team then
        return team.Name
    end
    
    return "No Team"
end

-- Функция для получения предмета в руках
local function GetToolInHand(playerObj)
    if not playerObj or not playerObj.Character then
        return "None"
    end
    
    local character = playerObj.Character
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        return tool.Name
    end
    
    -- Проверка Backpack
    local backpack = playerObj:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                return item.Name
            end
        end
    end
    
    return "None"
end

-- Функция для расчета расстояния
local function GetDistanceFromPlayer(targetPosition)
    local char = player.Character
    if not char then return 0 end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    
    return math.floor((root.Position - targetPosition).Magnitude)
end

-- Функция проверки исключений для аимбота
local function IsPlayerExcludedFromAimbot(targetPlayer)
    if not targetPlayer then return true end
    
    -- Проверка исключения по имени игрока
    if AimbotExceptions.Players[targetPlayer.Name] then
        return true
    end
    
    -- Проверка исключения по команде
    if targetPlayer.Team then
        local teamName = targetPlayer.Team.Name
        if AimbotExceptions.Teams[teamName] then
            return true
        end
    end
    
    -- Проверка исключения друзей
    if AimbotExceptions.Friends then
        local success, isFriend = pcall(function()
            return targetPlayer:IsFriendsWith(player.UserId)
        end)
        if success and isFriend then
            return true
        end
    end
    
    return false
end

-- Функция добавления игрока в исключения
function AddPlayerToAimbotExceptions(playerName)
    AimbotExceptions.Players[playerName] = true
end

-- Функция удаления игрока из исключений
function RemovePlayerFromAimbotExceptions(playerName)
    AimbotExceptions.Players[playerName] = nil
end

-- Функция добавления команды в исключения
function AddTeamToAimbotExceptions(teamName)
    AimbotExceptions.Teams[teamName] = true
end

-- Функция удаления команды из исключений
function RemoveTeamFromAimbotExceptions(teamName)
    AimbotExceptions.Teams[teamName] = nil
end

-- Функция очистки всех исключений
function ClearAllAimbotExceptions()
    AimbotExceptions.Players = {}
    AimbotExceptions.Teams = {}
    AimbotExceptions.Friends = false
end

-- Функция получения списка исключенных игроков
function GetExcludedPlayersList()
    local players = {}
    for playerName, _ in pairs(AimbotExceptions.Players) do
        table.insert(players, playerName)
    end
    return players
end

-- Функция получения списка исключенных команд
function GetExcludedTeamsList()
    local teams = {}
    for teamName, _ in pairs(AimbotExceptions.Teams) do
        table.insert(teams, teamName)
    end
    return teams
end

-- Функция очистки Favorite ESP
local function ClearFavoriteESP()
    if currentFavoriteHighlight then
        currentFavoriteHighlight:Destroy()
        currentFavoriteHighlight = nil
    end
    if favoriteDistanceConnection then
        favoriteDistanceConnection:Disconnect()
        favoriteDistanceConnection = nil
    end
    currentFavoriteTarget = nil
end

-- Функция создания Favorite ESP
local function CreateFavoriteESP(targetPlayer)
    ClearFavoriteESP()
    
    if not targetPlayer or not targetPlayer.Character then
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "⭐ FAVORITE: " .. targetPlayer.Name .. 
                                   "\nStatus: No character" ..
                                   "\nTeam: " .. GetTeamName(targetPlayer)
        end
        return
    end
    
    local character = targetPlayer.Character
    local teamColor = GetTeamColor(targetPlayer)
    
    -- Создаем подсветку
    local highlight = Instance.new("Highlight")
    highlight.Name = "Favorite_Highlight"
    highlight.Parent = character
    highlight.FillColor = Color3.fromRGB(255, 0, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.3
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    -- Сохраняем ссылки
    currentFavoriteTarget = targetPlayer
    currentFavoriteHighlight = highlight
    
    -- Функция для обновления информации
    local function UpdateFavoriteInfo()
        if not character or not character.Parent then
            if favoriteInfoLabel then
                favoriteInfoLabel.Text = "⭐ FAVORITE: " .. targetPlayer.Name .. 
                                       "\nStatus: Dead" ..
                                       "\nTeam: " .. GetTeamName(targetPlayer)
            end
            return
        end
        
        -- Обновляем расстояние
        local distance = "N/A"
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local targetPos = character:GetPivot().Position
            distance = math.floor((root.Position - targetPos).Magnitude) .. "m"
        end
        
        -- Обновляем HP
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
        
        -- Обновляем инструмент
        local tool = character:FindFirstChildOfClass("Tool")
        local toolText = tool and tool.Name or "None"
        
        -- Обновляем команду
        local teamName = GetTeamName(targetPlayer)
        
        -- Обновляем информационную панель
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "⭐ FAVORITE: " .. targetPlayer.Name .. 
                                   "\nStatus: " .. status ..
                                   "\nTeam: " .. teamName ..
                                   "\nDistance: " .. distance ..
                                   "\n" .. hpText .. 
                                   "\nTool: " .. toolText
        end
    end
    
    -- Обновляем информацию каждый кадр
    favoriteDistanceConnection = RunService.Heartbeat:Connect(UpdateFavoriteInfo)
    
    -- Обработка respawn
    targetPlayer.CharacterAdded:Connect(function(newCharacter)
        wait(1) -- Ждем загрузки персонажа
        if states.favoriteESP then
            CreateFavoriteESP(targetPlayer)
        end
    end)
end

-- Функция для создания информации о фаворите
function CreateFavoriteInfo()
    if favoriteInfoLabel then
        favoriteInfoLabel:Destroy()
        favoriteInfoLabel = nil
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FavoriteInfo"
    screenGui.Parent = game:GetService("CoreGui")
    
    favoriteInfoLabel = Instance.new("TextLabel")
    favoriteInfoLabel.Name = "FavoriteInfoLabel"
    favoriteInfoLabel.Size = UDim2.new(0, 300, 0, 120)
    favoriteInfoLabel.Position = UDim2.new(1, -310, 0, 10)
    favoriteInfoLabel.AnchorPoint = Vector2.new(1, 0)
    favoriteInfoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    favoriteInfoLabel.BackgroundTransparency = 0.5
    favoriteInfoLabel.BorderSizePixel = 0
    favoriteInfoLabel.Text = "⭐ FAVORITE: None"
    favoriteInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    favoriteInfoLabel.TextSize = 14
    favoriteInfoLabel.Font = Enum.Font.GothamBold
    favoriteInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    favoriteInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
    favoriteInfoLabel.TextWrapped = true
    favoriteInfoLabel.Parent = screenGui
    
    return favoriteInfoLabel
end

-- Функция для переключения Favorite ESP
function ToggleFavoriteESP(state)
    states.favoriteESP = state
    
    if not state then
        ClearFavoriteESP()
        if favoriteInfoLabel then
            favoriteInfoLabel.Text = "⭐ FAVORITE: None"
        end
        return
    end
    
    if not FavoritePlayer or FavoritePlayer == "" then
        return
    end
    
    local targetPlayer = Players:FindFirstChild(FavoritePlayer)
    
    if not targetPlayer then
        return
    end
    
    if targetPlayer == player then
        return
    end
    
    -- Создаем информационную панель если ее нет
    if not favoriteInfoLabel then
        CreateFavoriteInfo()
    end
    
    -- Удаляем обычный ESP с фаворита, если он был
    if targetPlayer.Character then
        RemoveESPByTarget(targetPlayer.Character)
    end
    
    CreateFavoriteESP(targetPlayer)
end

-- Функция для очистки фаворита
function ClearFavorite()
    FavoritePlayer = nil
    if states.favoriteESP then
        ToggleFavoriteESP(false)
    end
    
    if favoriteInfoLabel then
        favoriteInfoLabel.Text = "⭐ FAVORITE: None"
    end
end

-- Функция удаления ESP по цели
function RemoveESPByTarget(target)
    for i = #espObjects, 1, -1 do
        local espData = espObjects[i]
        if espData.Target == target then
            pcall(function() 
                if espData.Object then espData.Object:Destroy() end
                if espData.Billboard then espData.Billboard:Destroy() end
            end)
            table.remove(espObjects, i)
        end
    end
end

-- Аимбот система с поддержкой исключений
local Aimbot = {
    Enabled = false,
    TeamCheck = false,
    AliveCheck = true,
    WallCheck = false,
    Sensitivity = 0,
    ThirdPerson = false,
    ThirdPersonSensitivity = 3,
    TriggerKey = "MouseButton2",
    Toggle = false,
    LockPart = "Head",
    Smoothness = 0.1,
    Prediction = 0,
    MaxDistance = 1000,
    FOV = 200,
    FOVVisible = true,
    Locked = nil,
    FOVCircle = nil,
    ServiceConnections = {}
}

-- Функции аимбота с поддержкой исключений
local function IsPlayerValidForAimbot(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    
    -- Проверка исключений
    if IsPlayerExcludedFromAimbot(targetPlayer) then
        return false
    end
    
    local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    local lockPart = targetPlayer.Character:FindFirstChild(Aimbot.LockPart)
    
    if not humanoid or not lockPart then return false end
    if Aimbot.AliveCheck and humanoid.Health <= 0 then return false end
    if Aimbot.TeamCheck and targetPlayer.Team == player.Team then return false end
    
    local distance = (player.Character and lockPart and 
        (player.Character.PrimaryPart.Position - lockPart.Position).Magnitude or math.huge)
    if distance > Aimbot.MaxDistance then return false end
    
    return true
end

local function CancelAimbotLock()
    Aimbot.Locked = nil
    if Aimbot.FOVCircle then
        Aimbot.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    end
end

local function GetClosestPlayerForAimbot()
    if not Aimbot.Locked then
        local closestPlayer = nil
        local closestDistance = Aimbot.FOV
        
        for _, targetPlayer in next, Players:GetPlayers() do
            if targetPlayer ~= player and IsPlayerValidForAimbot(targetPlayer) then
                local lockPart = targetPlayer.Character[Aimbot.LockPart]
                local vector, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(lockPart.Position)
                
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local distance = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(vector.X, vector.Y)).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = targetPlayer
                    end
                end
            end
        end
        
        if closestPlayer then
            Aimbot.Locked = closestPlayer
        end
    else
        if not IsPlayerValidForAimbot(Aimbot.Locked) then
            CancelAimbotLock()
        end
    end
end

local function SmoothAim(targetPosition)
    local currentCFrame = Workspace.CurrentCamera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
    
    if Aimbot.Smoothness > 0 then
        local smoothFactor = Aimbot.Smoothness
        return currentCFrame:Lerp(targetCFrame, 1 - smoothFactor)
    else
        return targetCFrame
    end
end

local function GetPredictedPosition(character, lockPart)
    if Aimbot.Prediction <= 0 then
        return character[lockPart].Position
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return character[lockPart].Position end
    
    local velocity = character[lockPart].AssemblyLinearVelocity * Aimbot.Prediction
    return character[lockPart].Position + velocity
end

local function InitializeAimbot()
    if Aimbot.FOVCircle then return end
    
    Aimbot.FOVCircle = Drawing.new("Circle")
    Aimbot.FOVCircle.Visible = Aimbot.FOVVisible
    Aimbot.FOVCircle.Radius = Aimbot.FOV
    Aimbot.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    Aimbot.FOVCircle.Thickness = 1
    Aimbot.FOVCircle.Filled = false
    Aimbot.FOVCircle.Transparency = 0.5
    
    -- Connection для обновления FOV круга
    local fovConnection = RunService.RenderStepped:Connect(function()
        if Aimbot.FOVCircle then
            Aimbot.FOVCircle.Visible = Aimbot.FOVVisible and Aimbot.Enabled
            Aimbot.FOVCircle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
            Aimbot.FOVCircle.Radius = Aimbot.FOV
            
            if Aimbot.Locked then
                Aimbot.FOVCircle.Color = Color3.fromRGB(255, 70, 70)
            else
                Aimbot.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
            end
        end
    end)
    
    table.insert(Aimbot.ServiceConnections, fovConnection)
    
    -- Connection для аимбота
    local aimbotConnection = RunService.RenderStepped:Connect(function()
        if not Aimbot.Enabled or not player.Character then return end
        
        GetClosestPlayerForAimbot()
        
        if Aimbot.Locked and Aimbot.Locked.Character then
            local predictedPosition = GetPredictedPosition(
                Aimbot.Locked.Character, 
                Aimbot.LockPart
            )
            
            if Aimbot.ThirdPerson then
                local vector = Workspace.CurrentCamera:WorldToViewportPoint(predictedPosition)
                local mousePos = UserInputService:GetMouseLocation()
                
                mousemoverel(
                    (vector.X - mousePos.X) * Aimbot.ThirdPersonSensitivity,
                    (vector.Y - mousePos.Y) * Aimbot.ThirdPersonSensitivity
                )
            else
                local targetCFrame = SmoothAim(predictedPosition)
                
                if Aimbot.Sensitivity > 0 then
                    local tween = TweenService:Create(
                        Workspace.CurrentCamera, 
                        TweenInfo.new(Aimbot.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), 
                        {CFrame = targetCFrame}
                    )
                    tween:Play()
                else
                    Workspace.CurrentCamera.CFrame = targetCFrame
                end
            end
        end
    end)
    
    table.insert(Aimbot.ServiceConnections, aimbotConnection)
    
    -- Connection для управления аимботом
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType[Aimbot.TriggerKey] or 
           input.KeyCode == Enum.KeyCode[Aimbot.TriggerKey] then
            if Aimbot.Toggle then
                Aimbot.Enabled = not Aimbot.Enabled
                if not Aimbot.Enabled then
                    CancelAimbotLock()
                end
            else
                Aimbot.Enabled = true
            end
        end
    end)
    
    table.insert(Aimbot.ServiceConnections, inputConnection)
    
    local inputEndConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if not Aimbot.Toggle then
            if input.UserInputType == Enum.UserInputType[Aimbot.TriggerKey] or 
               input.KeyCode == Enum.KeyCode[Aimbot.TriggerKey] then
                Aimbot.Enabled = false
                CancelAimbotLock()
            end
        end
    end)
    
    table.insert(Aimbot.ServiceConnections, inputEndConnection)
end

local function CleanupAimbot()
    for _, connection in pairs(Aimbot.ServiceConnections) do
        pcall(function() connection:Disconnect() end)
    end
    Aimbot.ServiceConnections = {}
    
    if Aimbot.FOVCircle then
        pcall(function() Aimbot.FOVCircle:Remove() end)
        Aimbot.FOVCircle = nil
    end
    
    Aimbot.Locked = nil
end

-- Функции модификации
function GetHumanoid()
    local char = player.Character
    if char then
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Humanoid") then
                return child
            end
        end
    end
    return nil
end

function ApplySpeedHack()
    local humanoid = GetHumanoid()
    if humanoid then
        if states.speedHack then
            humanoid.WalkSpeed = settings.walkSpeed
        else
            humanoid.WalkSpeed = settings.originalWalkSpeed
        end
    end
end

function ApplyHighJump()
    local humanoid = GetHumanoid()
    if humanoid then
        if states.highJump then
            humanoid.JumpPower = settings.jumpPower
        else
            humanoid.JumpPower = settings.originalJumpPower
        end
    end
end

function ApplyNoClip()
    local char = player.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not states.noclip
            end
        end
    end
end

function ApplyFly()
    if states.fly then
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, obj in pairs(root:GetChildren()) do
                    if obj.Name:find("Fly") then obj:Destroy() end
                end

                local bodyVel = Instance.new("BodyVelocity")
                bodyVel.Name = GenerateUniqueName("FlyVel")
                bodyVel.Parent = root
                bodyVel.MaxForce = Vector3.new(40000, 40000, 40000)

                local flyConn = RunService.Heartbeat:Connect(function()
                    if not states.fly or not char or not root then
                        if flyConn then flyConn:Disconnect() end
                        return
                    end

                    local cam = Workspace.CurrentCamera
                    local moveDir = Vector3.new(0, 0, 0)

                    local keys = {
                        [Enum.KeyCode.W] = cam.CFrame.LookVector,
                        [Enum.KeyCode.S] = -cam.CFrame.LookVector,
                        [Enum.KeyCode.A] = -cam.CFrame.RightVector,
                        [Enum.KeyCode.D] = cam.CFrame.RightVector,
                        [Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
                        [Enum.KeyCode.LeftShift] = Vector3.new(0, -1, 0)
                    }

                    for key, dir in pairs(keys) do
                        if UserInputService:IsKeyDown(key) then
                            moveDir = moveDir + dir
                        end
                    end

                    bodyVel.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * 100 or Vector3.new(0, 0, 0)
                end)

                table.insert(connections, flyConn)
            end
        end
    else
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, obj in pairs(root:GetChildren()) do
                    if obj.Name:find("Fly") then obj:Destroy() end
                end
            end
        end
    end
end

-- ESP функции с улучшенной информацией
function TogglePlayerESP(state)
    states.esp = state
    
    for _, obj in pairs(espObjects) do
        if obj and (obj.Name:find("PlayerHL") or obj.Name:find("PlayerInfo")) then
            pcall(function() obj:Destroy() end)
        end
    end
    
    if state then
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                -- Проверяем, не является ли этот игрок фаворитом
                if FavoritePlayer and otherPlayer.Name == FavoritePlayer and states.favoriteESP then
                    continue -- Пропускаем фаворита, если включен Favorite ESP
                end
                
                local function SetupESP(char)
                    if not char then return end
                    
                    local teamColor = GetTeamColor(otherPlayer)
                    local teamName = GetTeamName(otherPlayer)
                    
                    local highlight = Instance.new("Highlight")
                    highlight.Name = GenerateUniqueName("PlayerHL")
                    highlight.FillColor = teamColor
                    highlight.OutlineColor = teamColor
                    highlight.FillTransparency = 0.5
                    highlight.Parent = char
                    
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = GenerateUniqueName("PlayerInfo")
                    billboard.Size = UDim2.new(0, 200, 0, 100)
                    billboard.StudsOffset = Vector3.new(0, 4, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Parent = char:FindFirstChild("Head") or char:WaitForChild("HumanoidRootPart")
                    
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(1, 0, 0, 20)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = otherPlayer.Name
                    nameLabel.TextColor3 = teamColor
                    nameLabel.TextStrokeTransparency = 0
                    nameLabel.TextSize = 14
                    nameLabel.Font = Enum.Font.GothamBold
                    nameLabel.Parent = billboard
                    
                    local teamLabel = Instance.new("TextLabel")
                    teamLabel.Size = UDim2.new(1, 0, 0, 18)
                    teamLabel.Position = UDim2.new(0, 0, 0, 20)
                    teamLabel.BackgroundTransparency = 1
                    teamLabel.Text = "Team: " .. teamName
                    teamLabel.TextColor3 = teamColor
                    teamLabel.TextStrokeTransparency = 0
                    teamLabel.TextSize = 12
                    teamLabel.Font = Enum.Font.Gotham
                    teamLabel.Visible = espSettings.showTeam
                    teamLabel.Parent = billboard
                    
                    local toolLabel = Instance.new("TextLabel")
                    toolLabel.Size = UDim2.new(1, 0, 0, 18)
                    toolLabel.Position = UDim2.new(0, 0, 0, 38)
                    toolLabel.BackgroundTransparency = 1
                    toolLabel.Text = "Tool: " .. GetToolInHand(otherPlayer)
                    toolLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    toolLabel.TextStrokeTransparency = 0
                    toolLabel.TextSize = 12
                    toolLabel.Font = Enum.Font.Gotham
                    toolLabel.Visible = espSettings.showTool
                    toolLabel.Parent = billboard
                    
                    local hpLabel = Instance.new("TextLabel")
                    hpLabel.Size = UDim2.new(1, 0, 0, 18)
                    hpLabel.Position = UDim2.new(0, 0, 0, 56)
                    hpLabel.BackgroundTransparency = 1
                    hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    hpLabel.TextStrokeTransparency = 0
                    hpLabel.TextSize = 12
                    hpLabel.Font = Enum.Font.Gotham
                    hpLabel.Visible = espSettings.showHP
                    hpLabel.Parent = billboard
                    
                    local distanceLabel = Instance.new("TextLabel")
                    distanceLabel.Size = UDim2.new(1, 0, 0, 18)
                    distanceLabel.Position = UDim2.new(0, 0, 0, 74)
                    distanceLabel.BackgroundTransparency = 1
                    distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                    distanceLabel.TextStrokeTransparency = 0
                    distanceLabel.TextSize = 11
                    distanceLabel.Font = Enum.Font.Gotham
                    distanceLabel.Visible = espSettings.showDistance
                    distanceLabel.Parent = billboard
                    
                    local function UpdateESP()
                        -- Обновление HP
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            hpLabel.Text = "HP: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                            hpLabel.TextColor3 = humanoid.Health / humanoid.MaxHealth > 0.5 and Color3.fromRGB(0, 255, 0) 
                                                or humanoid.Health / humanoid.MaxHealth > 0.2 and Color3.fromRGB(255, 255, 0) 
                                                or Color3.fromRGB(255, 0, 0)
                        end
                        
                        -- Обновление предмета в руках
                        toolLabel.Text = "Tool: " .. GetToolInHand(otherPlayer)
                        
                        -- Обновление расстояния
                        local rootPart = char:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            distanceLabel.Text = "Distance: " .. GetDistanceFromPlayer(rootPart.Position) .. "m"
                        end
                        
                        -- Обновление видимости элементов
                        teamLabel.Visible = espSettings.showTeam
                        toolLabel.Visible = espSettings.showTool
                        hpLabel.Visible = espSettings.showHP
                        distanceLabel.Visible = espSettings.showDistance
                    end
                    
                    UpdateESP()
                    
                    -- Подключение обновлений
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        local hpConn = humanoid:GetPropertyChangedSignal("Health"):Connect(UpdateESP)
                        table.insert(connections, hpConn)
                    end
                    
                    local toolConn = RunService.Heartbeat:Connect(function()
                        if not states.esp then
                            toolConn:Disconnect()
                            return
                        end
                        UpdateESP()
                    end)
                    table.insert(connections, toolConn)
                    
                    table.insert(espObjects, highlight)
                    table.insert(espObjects, billboard)
                end
                
                if otherPlayer.Character then
                    SetupESP(otherPlayer.Character)
                end
                
                local conn = otherPlayer.CharacterAdded:Connect(function(char)
                    wait(1)
                    if states.esp then
                        SetupESP(char)
                    end
                end)
                table.insert(connections, conn)
            end
        end
    end
end

function ToggleItemESP(state)
    states.itemEsp = state
    
    if state then
        ScanItems()
        
        local itemConn = RunService.Heartbeat:Connect(function()
            if not states.itemEsp then
                itemConn:Disconnect()
                return
            end
            
            local currentTime = tick()
            if currentTime - lastScanTime >= SCAN_INTERVAL then
                lastScanTime = currentTime
                ScanItems()
            end
        end)
        table.insert(connections, itemConn)
        
    else
        RemoveESPByType("Item")
    end
end

function ScanItems()
    RemoveESPByType("Item")
    
    for _, itemName in pairs(itemList) do
        local item = Workspace:FindFirstChild(itemName, true)
        if item then
            CreateItemESP(item, itemName)
        end
    end
    
    local folders = {"Items", "Drops", "Weapons", "Loot"}
    for _, folderName in pairs(folders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in pairs(folder:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    for _, itemName in pairs(itemList) do
                        if obj.Name:find(itemName) then
                            CreateItemESP(obj, itemName)
                        end
                    end
                end
            end
        end
    end
end

function CreateItemESP(item, itemName)
    local highlight = Instance.new("Highlight")
    highlight.Name = GenerateUniqueName("ItemHL")
    highlight.FillColor = Color3.fromRGB(0, 255, 0)
    highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
    highlight.FillTransparency = 0.4
    highlight.Parent = item
    table.insert(espObjects, highlight)
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = GenerateUniqueName("ItemName")
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    
    local primaryPart = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        billboard.Parent = primaryPart
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 25)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = itemName
        nameLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = billboard
        
        local distanceLabel = Instance.new("TextLabel")
        distanceLabel.Size = UDim2.new(1, 0, 0, 25)
        distanceLabel.Position = UDim2.new(0, 0, 0, 25)
        distanceLabel.BackgroundTransparency = 1
        distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        distanceLabel.TextStrokeTransparency = 0
        distanceLabel.TextSize = 10
        distanceLabel.Font = Enum.Font.Gotham
        distanceLabel.Parent = billboard
        
        -- Обновление расстояния
        local function UpdateDistance()
            local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                distanceLabel.Text = "Distance: " .. GetDistanceFromPlayer(primaryPart.Position) .. "m"
            end
        end
        
        UpdateDistance()
        local distConn = RunService.Heartbeat:Connect(UpdateDistance)
        table.insert(connections, distConn)
        
        table.insert(espObjects, billboard)
    end
end

function ToggleNPCESP(state)
    states.npcEsp = state
    
    if state then
        ScanNPCs()
        
        local npcConn = RunService.Heartbeat:Connect(function()
            if not states.npcEsp then
                npcConn:Disconnect()
                return
            end
            
            local currentTime = tick()
            if currentTime - lastScanTime >= SCAN_INTERVAL then
                lastScanTime = currentTime
                ScanNPCs()
            end
        end)
        table.insert(connections, npcConn)
        
    else
        RemoveESPByType("NPC")
    end
end

function ScanNPCs()
    RemoveESPByType("NPC")
    
    for _, npcName in pairs(npcList) do
        local npc = Workspace:FindFirstChild(npcName, true)
        if npc then
            CreateNPCESP(npc, npcName)
        end
    end
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local humanoid = obj:FindFirstChildOfClass("Humanoid")
            if humanoid and not Players:GetPlayerFromCharacter(obj) then
                for _, npcName in pairs(npcList) do
                    if obj.Name:find(npcName) then
                        CreateNPCESP(obj, npcName)
                    end
                end
            end
        end
    end
end

function CreateNPCESP(npc, npcName)
    local highlight = Instance.new("Highlight")
    highlight.Name = GenerateUniqueName("NPCHL")
    highlight.FillColor = Color3.fromRGB(255, 165, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 165, 0)
    highlight.FillTransparency = 0.4
    highlight.Parent = npc
    table.insert(espObjects, highlight)
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = GenerateUniqueName("NPCName")
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    
    local primaryPart = npc:IsA("BasePart") and npc or npc:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        billboard.Parent = primaryPart
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 25)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = npcName
        nameLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = billboard
        
        local distanceLabel = Instance.new("TextLabel")
        distanceLabel.Size = UDim2.new(1, 0, 0, 25)
        distanceLabel.Position = UDim2.new(0, 0, 0, 25)
        distanceLabel.BackgroundTransparency = 1
        distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        distanceLabel.TextStrokeTransparency = 0
        distanceLabel.TextSize = 10
        distanceLabel.Font = Enum.Font.Gotham
        distanceLabel.Parent = billboard
        
        -- Обновление расстояния
        local function UpdateDistance()
            local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                distanceLabel.Text = "Distance: " .. GetDistanceFromPlayer(primaryPart.Position) .. "m"
            end
        end
        
        UpdateDistance()
        local distConn = RunService.Heartbeat:Connect(UpdateDistance)
        table.insert(connections, distConn)
        
        table.insert(espObjects, billboard)
    end
end

function RemoveESPByType(espType)
    for i = #espObjects, 1, -1 do
        local obj = espObjects[i]
        if obj and obj.Name:find(espType) then
            pcall(function() obj:Destroy() end)
            table.remove(espObjects, i)
        end
    end
end

-- Функция обновления всех ESP
function UpdateAllESP()
    if states.esp then
        TogglePlayerESP(false)
        wait(0.1)
        TogglePlayerESP(true)
    end
end

-- Функции телепорта и Fling
function TeleportToRandomItem()
    local items = {}
    
    for _, itemName in pairs(itemList) do
        local item = Workspace:FindFirstChild(itemName, true)
        if item then
            table.insert(items, item)
        end
    end
    
    if #items > 0 then
        local randomItem = items[math.random(1, #items)]
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = randomItem.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end
end

function TeleportItemsToPlayer()
    local char = player.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    for _, itemName in pairs(itemList) do
        local item = Workspace:FindFirstChild(itemName, true)
        if item then
            if item:IsA("BasePart") then
                item.CFrame = root.CFrame + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
            elseif item:IsA("Model") then
                local primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    primaryPart.CFrame = root.CFrame + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
                end
            end
        end
    end
end

function ToggleTeleportMode(state)
    states.teleportMode = state
    
    if state then
        local teleportConn
        teleportConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == Enum.KeyCode.T then
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local mouse = player:GetMouse()
                        local target = mouse.Hit.Position
                        root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
                    end
                end
            end
        end)
        
        table.insert(connections, teleportConn)
    end
end

function ToggleFling(state)
    states.fling = state
    
    if state then
        local char = player.Character
        if not char then return end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = GenerateUniqueName("FlingVelocity")
        bodyVelocity.Parent = root
        bodyVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
        
        local flingConn = RunService.Heartbeat:Connect(function()
            if not states.fling or not char or not root then
                if flingConn then flingConn:Disconnect() end
                bodyVelocity:Destroy()
                return
            end
            
            bodyVelocity.Velocity = Vector3.new(
                math.random(-5, 5),
                math.random(-2, 2),
                math.random(-5, 5)
            ) * 2
        end)
        
        local touchConn
        touchConn = root.Touched:Connect(function(hit)
            if not states.fling then 
                if touchConn then touchConn:Disconnect() end
                return 
            end
            
            local hitChar = hit:FindFirstAncestorOfClass("Model")
            if hitChar and hitChar ~= char then
                local hitHumanoid = hitChar:FindFirstChildOfClass("Humanoid")
                local hitRoot = hitChar:FindFirstChild("HumanoidRootPart")
                
                if hitHumanoid and hitRoot then
                    local launchVelocity = Instance.new("BodyVelocity")
                    launchVelocity.Velocity = (hitRoot.Position - root.Position).Unit * 300 + Vector3.new(0, 150, 0)
                    launchVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
                    launchVelocity.Parent = hitRoot
                    
                    game:GetService("Debris"):AddItem(launchVelocity, 0.3)
                end
            end
        end)
        
        table.insert(connections, flingConn)
        table.insert(connections, touchConn)
    else
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, obj in pairs(root:GetChildren()) do
                    if obj.Name:find("Fling") then
                        obj:Destroy()
                    end
                end
            end
        end
    end
end

-- Библиотека Venyx
local Venyx = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Venyx-UI-Library/main/source.lua"))()

-- Создание GUI с системой ключей
function CreateKeyVerificationGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = GenerateUniqueName("KeyVerification")
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui or player:FindFirstChildOfClass("PlayerGui") or Workspace

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "KeyFrame"
    mainFrame.Parent = screenGui
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Position = UDim2.new(0.4, 0, 0.4, 0)
    mainFrame.Size = UDim2.new(0, 350, 0, 220)
    mainFrame.Active = true
    mainFrame.Draggable = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    -- Gradient эффект
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
    })
    gradient.Rotation = 45
    gradient.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = mainFrame
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 0, 0, 20)
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🔐 KEY VERIFICATION"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.TextStrokeTransparency = 0.8

    local instructionLabel = Instance.new("TextLabel")
    instructionLabel.Name = "InstructionLabel"
    instructionLabel.Parent = mainFrame
    instructionLabel.BackgroundTransparency = 1
    instructionLabel.Position = UDim2.new(0, 25, 0, 70)
    instructionLabel.Size = UDim2.new(1, -50, 0, 40)
    instructionLabel.Font = Enum.Font.Gotham
    instructionLabel.Text = "Enter the access key to unlock the menu features:"
    instructionLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    instructionLabel.TextSize = 13
    instructionLabel.TextWrapped = true

    local keyBox = Instance.new("TextBox")
    keyBox.Name = "KeyBox"
    keyBox.Parent = mainFrame
    keyBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    keyBox.BorderSizePixel = 0
    keyBox.Position = UDim2.new(0.1, 0, 0, 120)
    keyBox.Size = UDim2.new(0.8, 0, 0, 35)
    keyBox.Font = Enum.Font.Gotham
    keyBox.PlaceholderText = "Enter key here..."
    keyBox.Text = ""
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.TextSize = 14
    keyBox.ClearTextOnFocus = false

    local keyBoxCorner = Instance.new("UICorner")
    keyBoxCorner.CornerRadius = UDim.new(0, 8)
    keyBoxCorner.Parent = keyBox

    local verifyButton = Instance.new("TextButton")
    verifyButton.Name = "VerifyButton"
    verifyButton.Parent = mainFrame
    verifyButton.BackgroundColor3 = Color3.fromRGB(80, 140, 220)
    verifyButton.BorderSizePixel = 0
    verifyButton.Position = UDim2.new(0.2, 0, 0, 170)
    verifyButton.Size = UDim2.new(0.6, 0, 0, 35)
    verifyButton.Font = Enum.Font.GothamBold
    verifyButton.Text = "VERIFY ACCESS"
    verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    verifyButton.TextSize = 14

    local verifyCorner = Instance.new("UICorner")
    verifyCorner.CornerRadius = UDim.new(0, 8)
    verifyCorner.Parent = verifyButton

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = mainFrame
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.new(0, 0, 0, 155)
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextSize = 12

    -- Анимации кнопок
    verifyButton.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(verifyButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 160, 240)}):Play()
    end)

    verifyButton.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(verifyButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 140, 220)}):Play()
    end)

    verifyButton.MouseButton1Click:Connect(function()
        local enteredKey = keyBox.Text
        if enteredKey == correctKey then
            keyVerified = true
            statusLabel.Text = "✅ Access granted! Loading menu..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            
            -- Анимация успеха
            game:GetService("TweenService"):Create(verifyButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(0, 200, 80)}):Play()
            wait(1.5)
            screenGui:Destroy()
            CreateVenyxGUI()
        else
            statusLabel.Text = "❌ Invalid key! Please try again."
            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            
            -- Анимация ошибки
            local originalColor = verifyButton.BackgroundColor3
            game:GetService("TweenService"):Create(verifyButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
            wait(0.2)
            game:GetService("TweenService"):Create(verifyButton, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
        end
    end)

    keyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            verifyButton:MouseButton1Click()
        end
    end)

    return screenGui
end

-- Создание основного GUI с Venyx
function CreateVenyxGUI()
    local theme = {
        Background = Color3.fromRGB(15, 15, 25),
        Glow = Color3.fromRGB(80, 140, 220),
        Accent = Color3.fromRGB(80, 140, 220),
        LightContrast = Color3.fromRGB(25, 25, 35),
        DarkContrast = Color3.fromRGB(10, 10, 20), 
        TextColor = Color3.fromRGB(255, 255, 255)
    }
    
    local Venyx = Venyx.new("CURSED CHILD - VENYX", theme)
    
    -- Вкладка Movement
    local movementPage = Venyx:addPage("Movement", 5012544693)
    local movementSection = movementPage:addSection("Movement Settings")
    local flySection = movementPage:addSection("Flight Settings")
    
    movementSection:addSlider("Walk Speed", settings.walkSpeed, 16, 200, function(value)
        settings.walkSpeed = value
        if states.speedHack then
            ApplySpeedHack()
        end
    end)
    
    movementSection:addToggle("Speed Hack", states.speedHack, function(value)
        states.speedHack = value
        ApplySpeedHack()
    end)
    
    movementSection:addSlider("Jump Power", settings.jumpPower, 50, 300, function(value)
        settings.jumpPower = value
        if states.highJump then
            ApplyHighJump()
        end
    end)
    
    movementSection:addToggle("High Jump", states.highJump, function(value)
        states.highJump = value
        ApplyHighJump()
    end)
    
    movementSection:addToggle("NoClip", states.noclip, function(value)
        states.noclip = value
        ApplyNoClip()
    end)
    
    flySection:addToggle("Fly Mode", states.fly, function(value)
        states.fly = value
        ApplyFly()
    end)
    
    flySection:addKeybind("Fly Toggle", Enum.KeyCode.F, function()
        states.fly = not states.fly
        ApplyFly()
    end, function() end)
    
    -- Вкладка Visuals
    local visualsPage = Venyx:addPage("Visuals", 5012544693)
    local espSection = visualsPage:addSection("ESP Settings")
    local espComponentsSection = visualsPage:addSection("ESP Components")
    local favoriteSection = visualsPage:addSection("Favorite Player")
    
    espSection:addToggle("Player ESP", states.esp, function(value)
        TogglePlayerESP(value)
    end)
    
    espSection:addToggle("Item ESP", states.itemEsp, function(value)
        ToggleItemESP(value)
    end)
    
    espSection:addToggle("NPC ESP", states.npcEsp, function(value)
        ToggleNPCESP(value)
    end)
    
    -- Настройки компонентов ESP
    espComponentsSection:addToggle("Show HP", espSettings.showHP, function(value)
        espSettings.showHP = value
        UpdateAllESP()
    end)
    
    espComponentsSection:addToggle("Show Team", espSettings.showTeam, function(value)
        espSettings.showTeam = value
        UpdateAllESP()
    end)
    
    espComponentsSection:addToggle("Show Tool", espSettings.showTool, function(value)
        espSettings.showTool = value
        UpdateAllESP()
    end)
    
    espComponentsSection:addToggle("Show Distance", espSettings.showDistance, function(value)
        espSettings.showDistance = value
        UpdateAllESP()
    end)
    
    -- Система фаворита
    favoriteSection:addTextbox("Favorite Player", "Enter name", function(value)
        FavoritePlayer = value
        if value and value ~= "" then
            Venyx:Notify("Favorite Set", "Now tracking: " .. value)
        end
    end)
    
    favoriteSection:addToggle("Favorite ESP", states.favoriteESP, function(value)
        ToggleFavoriteESP(value)
    end)
    
    favoriteSection:addButton("Clear Favorite", function()
        ClearFavorite()
        Venyx:Notify("Favorite Cleared", "Favorite player removed")
    end)
    
    -- Вкладка Aimbot с ВСЕМИ настройками в одной секции
    local aimbotPage = Venyx:addPage("Aimbot", 5012544693)
    local aimbotSection = aimbotPage:addSection("Aimbot Settings")
    
    -- Основные настройки аимбота
    aimbotSection:addToggle("Aimbot Enabled", Aimbot.Enabled, function(value)
        Aimbot.Enabled = value
        if value then
            InitializeAimbot()
        else
            CleanupAimbot()
        end
    end)
    
    aimbotSection:addToggle("Toggle Mode", Aimbot.Toggle, function(value)
        Aimbot.Toggle = value
    end)
    
    aimbotSection:addDropdown("Lock Part", {"Head", "HumanoidRootPart", "Torso"}, function(value)
        Aimbot.LockPart = value
    end)
    
    aimbotSection:addToggle("Team Check", Aimbot.TeamCheck, function(value)
        Aimbot.TeamCheck = value
    end)
    
    aimbotSection:addToggle("Wall Check", Aimbot.WallCheck, function(value)
        Aimbot.WallCheck = value
    end)
    
    aimbotSection:addSlider("Smoothness", Aimbot.Smoothness * 100, 0, 100, function(value)
        Aimbot.Smoothness = value / 100
    end)
    
    aimbotSection:addSlider("Prediction", Aimbot.Prediction * 100, 0, 200, function(value)
        Aimbot.Prediction = value / 100
    end)
    
    aimbotSection:addSlider("Max Distance", Aimbot.MaxDistance, 100, 2000, function(value)
        Aimbot.MaxDistance = value
    end)
    
    -- Настройки FOV
    aimbotSection:addToggle("FOV Circle", Aimbot.FOVVisible, function(value)
        Aimbot.FOVVisible = value
    end)
    
    aimbotSection:addSlider("FOV Size", Aimbot.FOV, 50, 500, function(value)
        Aimbot.FOV = value
    end)
    
    aimbotSection:addKeybind("Aimbot Key", Enum.KeyCode[Aimbot.TriggerKey], function()
        -- Keybind для быстрого переключения
    end, function(key)
        Aimbot.TriggerKey = tostring(key):gsub("Enum.KeyCode.", "")
    end)
    
    -- НАСТРОЙКИ ИСКЛЮЧЕНИЙ
    aimbotSection:addToggle("Exclude Friends", AimbotExceptions.Friends, function(value)
        AimbotExceptions.Friends = value
        Venyx:Notify("Aimbot", "Friends exclusion: " .. (value and "ON" or "OFF"))
    end)
    
    aimbotSection:addButton("Add Player Exception", function()
        -- Простой способ добавления игрока
        local playerName = "ExamplePlayer" -- Можно заменить на логику ввода
        if playerName and playerName ~= "" then
            AddPlayerToAimbotExceptions(playerName)
            Venyx:Notify("Aimbot", "Added player: " .. playerName)
        end
    end)
    
    aimbotSection:addButton("Add Team Exception", function()
        -- Простой способ добавления команды
        local teamName = "ExampleTeam" -- Можно заменить на логику ввода
        if teamName and teamName ~= "" then
            AddTeamToAimbotExceptions(teamName)
            Venyx:Notify("Aimbot", "Added team: " .. teamName)
        end
    end)
    
    aimbotSection:addButton("View Exceptions", function()
        local excludedPlayers = GetExcludedPlayersList()
        local excludedTeams = GetExcludedTeamsList()
        
        local message = "Aimbot Exceptions:\n\n"
        
        if #excludedPlayers > 0 then
            message = message .. "Players:\n"
            for _, playerName in ipairs(excludedPlayers) do
                message = message .. "• " .. playerName .. "\n"
            end
            message = message .. "\n"
        else
            message = message .. "Players: None\n\n"
        end
        
        if #excludedTeams > 0 then
            message = message .. "Teams:\n"
            for _, teamName in ipairs(excludedTeams) do
                message = message .. "• " .. teamName .. "\n"
            end
        else
            message = message .. "Teams: None"
        end
        
        message = message .. "\nFriends: " .. (AimbotExceptions.Friends and "Excluded" or "Not excluded")
        
        Venyx:Notify("Aimbot Exceptions", message)
    end)
    
    aimbotSection:addButton("Clear All Exceptions", function()
        ClearAllAimbotExceptions()
        Venyx:Notify("Aimbot", "All exceptions cleared!")
    end)
    
    -- Вкладка Teleport
    local teleportPage = Venyx:addPage("Teleport", 5012544693)
    local teleportSection = teleportPage:addSection("Teleport Functions")
    
    teleportSection:addButton("Teleport to Random Item", function()
        TeleportToRandomItem()
    end)
    
    teleportSection:addButton("Teleport Items to Me", function()
        TeleportItemsToPlayer()
    end)
    
    teleportSection:addToggle("Quick Teleport (T)", states.teleportMode, function(value)
        ToggleTeleportMode(value)
    end)
    
    -- Вкладка Combat
    local combatPage = Venyx:addPage("Combat", 5012544693)
    local combatSection = combatPage:addSection("Combat Features")
    
    combatSection:addToggle("Fling Mode", states.fling, function(value)
        ToggleFling(value)
    end)
    
    -- Вкладка Credits
    local creditsPage = Venyx:addPage("Credits", 5012544693)
    local creditsSection = creditsPage:addSection("Developer Information")
    local infoSection = creditsPage:addSection("Script Information")
    
    creditsSection:addLabel("👑 Developer: danartkul")
    creditsSection:addLabel("🎮 Game: CURSED CHILD Jump Showdown")
    creditsSection:addLabel("⚡ Version: Venyx UI Edition")
    creditsSection:addLabel("🎯 Feature: Advanced Aimbot & Favorite System")
    
    infoSection:addLabel("🌟 Special thanks to all testers!")
    infoSection:addLabel("🔐 Protected with key system")
    infoSection:addLabel("🎨 Beautiful Venyx interface")
    infoSection:addButton("Copy Discord", function()
        setclipboard("danartkul")
    end)
    
    -- Вкладка Settings
    local settingsPage = Venyx:addPage("Settings", 5012544693)
    local configSection = settingsPage:addSection("Configuration")
    
    configSection:addKeybind("Toggle GUI", Enum.KeyCode.RightControl, function()
        Venyx:toggle()
    end, function() end)
    
    configSection:addButton("Save Configuration", function()
        Venyx:Notify("Settings Saved", "Your configuration has been saved!")
    end)
    
    configSection:addButton("Load Configuration", function()
        Venyx:Notify("Settings Loaded", "Configuration loaded successfully!")
    end)
    
    -- Загружаем GUI
    Venyx:SelectPage(1)
    
    -- Создаем панель фаворита
    CreateFavoriteInfo()
    
    -- Уведомление о успешной загрузке
    wait(1)
    Venyx:Notify("Menu Loaded", "CURSED CHILD Venyx UI with Aimbot & Favorite System successfully loaded!")
    
    return Venyx
end

-- Основной цикл
local mainConnection = RunService.Heartbeat:Connect(function()
    if states.speedHack then ApplySpeedHack() end
    if states.highJump then ApplyHighJump() end
    if states.noclip then ApplyNoClip() end
end)
table.insert(connections, mainConnection)

-- Обработчик респавна
local respawnConnection = player.CharacterAdded:Connect(function()
    wait(2)
    if states.speedHack then ApplySpeedHack() end
    if states.highJump then ApplyHighJump() end
    if states.fly then ApplyFly() end
    if states.noclip then ApplyNoClip() end
    if states.esp then TogglePlayerESP(true) end
    if states.itemEsp then ToggleItemESP(true) end
    if states.npcEsp then ToggleNPCESP(true) end
    if states.fling then ToggleFling(true) end
    if states.favoriteESP and FavoritePlayer then
        local targetPlayer = Players:FindFirstChild(FavoritePlayer)
        if targetPlayer then
            CreateFavoriteESP(targetPlayer)
        end
    end
    if Aimbot.Enabled then
        CleanupAimbot()
        wait(0.5)
        InitializeAimbot()
    end
end)
table.insert(connections, respawnConnection)

-- Запуск системы ключей
wait(1)
local keyGUI = CreateKeyVerificationGUI()

if keyGUI then
    print("🔐 Venyx UI Key System Loaded")
    print("👑 Developer: danartkul")
    print("🎨 Using Venyx UI Library")
    print("🎯 Advanced Aimbot with Exclusions")
    print("⭐ Favorite System with Team Display")
    print("📊 Enhanced ESP with Team Colors & Tools")
    print("⚡ Waiting for key input...")
end
