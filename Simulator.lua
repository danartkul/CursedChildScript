local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Toggle states
local Farm = false
local Rebirth = false
local ESPEnabled = false
local IsSelling = false -- Флаг процесса продажи

-- AFK Protection System
local AFKProtection = {
    Enabled = false,
    Timer = 0,
    Connection = nil
}

local function EnableAFKProtection()
    if AFKProtection.Connection then
        AFKProtection.Connection:Disconnect()
    end
    
    AFKProtection.Enabled = true
    AFKProtection.Timer = 0
    
    AFKProtection.Connection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
        if not AFKProtection.Enabled then return end
        
        AFKProtection.Timer = AFKProtection.Timer + deltaTime
        
        -- Каждые 10 минут имитируем активность
        if AFKProtection.Timer >= 600 then
            AFKProtection.Timer = 0
            
            pcall(function()
                -- Используем VirtualUser для имитации активности (самый надежный способ)
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(0.1)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                
                -- Дополнительно: легкое движение камеры
                local cam = workspace.CurrentCamera
                if cam then
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(5), 0)
                    task.wait(0.1)
                    cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-5), 0)
                end
                
                print("Anti-AFK: Activity simulated at " .. os.date("%X"))
            end)
        end
    end)
    
    print("Anti-AFK Protection Enabled - VirtualUser activity every 10 minutes")
end

local function DisableAFKProtection()
    AFKProtection.Enabled = false
    if AFKProtection.Connection then
        AFKProtection.Connection:Disconnect()
        AFKProtection.Connection = nil
    end
    print("Anti-AFK Protection Disabled")
end

-- Функция для автоопределения инструмента
local function AutoDetectTool()
    local backpack = game.Players.LocalPlayer.Backpack
    local character = game.Players.LocalPlayer.Character
    
    -- Ищем инструменты в рюкзаке
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            -- Проверяем, является ли это инструментом для копания
            if item:FindFirstChild("RemoteClick") then
                return item.Name
            end
        end
    end
    
    -- Ищем инструмент в инвентаре персонажа
    if character then
        for _, item in pairs(character:GetChildren()) do
            if item:IsA("Tool") and item:FindFirstChild("RemoteClick") then
                return item.Name
            end
        end
    end
    
    return "Bucket" -- Дефолтное значение
end

-- ESP System для сундуков
local activeESP = {}
local chestESPConnection

local function clearESP()
    for chest, espData in pairs(activeESP) do
        if espData.billboard then espData.billboard:Destroy() end
        if espData.highlight then espData.highlight:Destroy() end
    end
    activeESP = {}
    
    if chestESPConnection then
        chestESPConnection:Disconnect()
    end
end

local function createChestESP(chestPart)
    if activeESP[chestPart] then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ChestESP"
    billboard.Adornee = chestPart
    billboard.Size = UDim2.new(0, 150, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 500
    billboard.Enabled = true

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.new(1, 1, 0)
    frame.Parent = billboard

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "🎯 CHEST"
    label.TextColor3 = Color3.new(1, 1, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame

    local highlight = Instance.new("Highlight")
    highlight.Adornee = chestPart
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.new(1, 1, 0)
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = Color3.new(1, 1, 0)
    highlight.OutlineTransparency = 0
    highlight.Parent = chestPart

    billboard.Parent = game.CoreGui
    activeESP[chestPart] = {billboard = billboard, highlight = highlight}
end

local function updateESP()
    if not ESPEnabled then return end
    
    local character = game.Players.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    for chest, espData in pairs(activeESP) do
        if not chest or not chest.Parent then
            if espData.billboard then espData.billboard:Destroy() end
            if espData.highlight then espData.highlight:Destroy() end
            activeESP[chest] = nil
        end
    end
end

local function initializeESP()
    clearESP()
    
    -- Сканируем существующие сундуки
    for i,v in pairs(game.Workspace.SandBlocks:GetChildren()) do
        if v:FindFirstChild("Chest") then
            createChestESP(v)
        end
    end
    
    -- Мониторим новые сундуки
    game.Workspace.SandBlocks.ChildAdded:Connect(function(child)
        if ESPEnabled and child:FindFirstChild("Chest") then
            task.wait(0.5)
            createChestESP(child)
        end
    end)
    
    chestESPConnection = game:GetService("RunService").Heartbeat:Connect(updateESP)
end

local Character = game.Workspace:WaitForChild(game.Players.LocalPlayer.Name)

-- Функция проверки завершения продажи
local function WaitForSellCompletion()
    local startTime = tick()
    local maxWaitTime = 10 -- Максимальное время ожидания 10 секунд
    
    while IsSelling do
        -- Проверяем видимость попапа продажи
        local sellPopup = game.Players.LocalPlayer.PlayerGui.Gui.Popups:FindFirstChild("SellingItems")
        local backpackFull = game.Players[game.Players.LocalPlayer.Name].PlayerGui.Gui.Popups.BackpackFull.Visible
        
        -- Если попап продажи исчез и инвентарь не полный, значит продажа завершена
        if not sellPopup and not backpackFull then
            IsSelling = false
            break
        end
        
        -- Защита от бесконечного цикла
        if tick() - startTime > maxWaitTime then
            warn("Sell timeout reached")
            IsSelling = false
            break
        end
        
        task.wait(0.5)
    end
end

function Sell()
    if IsSelling then
        print("Already selling, please wait...")
        return
    end
    
    IsSelling = true
    local OldPos = Character.HumanoidRootPart.CFrame
    
    -- Телепортируемся к точке продажи
    Character.HumanoidRootPart.CFrame = CFrame.new(3, 10, -160)
    
    -- Запускаем продажу
    game.ReplicatedStorage.Events.AreaSell:FireServer()
    
    -- Ждем завершения продажи
    WaitForSellCompletion()
    
    -- Возвращаемся обратно
    Character.HumanoidRootPart.CFrame = OldPos
end

local function RE()
    while true do
        wait(1)
        if Rebirth == true then
            local a = game.Players.LocalPlayer.PlayerGui.Gui.Buttons.Coins.Amount.Text:gsub(',','')
            local b = game.Players.LocalPlayer.PlayerGui.Gui.Rebirth.Needed.Coins.Amount.Text:gsub(',','')
            print(tonumber(a))
            print(tonumber(b))
            if tonumber(a) > tonumber(b) then 
                warn('Calculation Complete!')
                game.ReplicatedStorage.Events.Rebirth:FireServer()
                repeat wait(.1) until game.Players.LocalPlayer.PlayerGui.Gui.Popups.GiveReward.Visible == true
                game.Players.LocalPlayer.PlayerGui.Gui.Popups.GiveReward.Visible = false
                wait()
            end
        end
    end
end

spawn(RE)

-- Основное окно с системой ключей
local Window = Rayfield:CreateWindow({
   Name = "Treasure Break Simulator",
   LoadingTitle = "Treasure Break Simulator",
   LoadingSubtitle = "by ScriptHub",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "TreasureBreakSimulator",
      FileName = "Config"
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = true, -- Включаем систему ключей
   KeySettings = {
      Title = "Treasure Break Simulator",
      Subtitle = "Key System",
      Note = "Join Discord for key",
      FileName = "TreasureKey",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"TreasureBreak2024", "TBSimulatorVIP", "GoldDigger123"} -- Доступные ключи
   }
})

-- Главная вкладка
local MainTab = Window:CreateTab("Main", 4483362458)

-- Автофарм секция
local AutoFarmSection = MainTab:CreateSection("Auto Farm")

local ToolNameInput = MainTab:CreateInput({
   Name = "Tool Name",
   PlaceholderText = "Tool will be auto-detected",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
       -- Сохраняем ввод пользователя
   end,
})

-- Кнопка автоопределения инструмента
local DetectToolButton = MainTab:CreateButton({
   Name = "🔧 Auto Detect Tool",
   Callback = function()
       local detectedTool = AutoDetectTool()
       ToolNameInput:Set(detectedTool)
       Rayfield:Notify({
          Title = "Tool Detected",
          Content = "Selected tool: " .. detectedTool,
          Duration = 3,
          Image = 4483362458,
       })
   end,
})

-- Автоопределяем инструмент при запуске
spawn(function()
    wait(2)
    local detectedTool = AutoDetectTool()
    ToolNameInput:Set(detectedTool)
end)

local AutoFarmToggle = MainTab:CreateToggle({
   Name = "Auto Farm",
   CurrentValue = false,
   Flag = "AutoFarmToggle",
   Callback = function(Value)
       Farm = Value
       if Value then
           -- Проверяем наличие инструмента
           local toolName = ToolNameInput.CurrentValue
           if game.Players.LocalPlayer.Character:FindFirstChild(toolName) then
               print('Already EquipTool')
           else
               game.Players.LocalPlayer.Character.Humanoid:EquipTool(game.Players.LocalPlayer.Backpack[toolName])
           end
       end
   end,
})

local AutoRebirthToggle = MainTab:CreateToggle({
   Name = "Auto Rebirth",
   CurrentValue = false,
   Flag = "AutoRebirthToggle",
   Callback = function(Value)
       Rebirth = Value
   end,
})

-- ESP секция
local ESPToggle = MainTab:CreateToggle({
   Name = "Chest ESP",
   CurrentValue = false,
   Flag = "ChestESP",
   Callback = function(Value)
       ESPEnabled = Value
       if Value then
           initializeESP()
       else
           clearESP()
       end
   end,
})

-- Утилиты секция
local UtilitiesSection = MainTab:CreateSection("Utilities")

local SellButton = MainTab:CreateButton({
   Name = "Sell All Items",
   Callback = function()
       Sell()
   end,
})

-- AFK Protection Section
local AFKSection = MainTab:CreateSection("AFK Protection")

local AFKInfo = MainTab:CreateLabel("Prevents kick for inactivity")
local AFKInfo2 = MainTab:CreateLabel("Uses VirtualUser every 10 minutes")

local AFKToggle = MainTab:CreateToggle({
   Name = "Enable Anti-AFK",
   CurrentValue = false,
   Flag = "AntiAFK",
   Callback = function(Value)
       if Value then
           EnableAFKProtection()
           Rayfield:Notify({
              Title = "Anti-AFK Enabled",
              Content = "VirtualUser will prevent AFK kicks",
              Duration = 3,
              Image = 4483362458,
           })
       else
           DisableAFKProtection()
           Rayfield:Notify({
              Title = "Anti-AFK Disabled",
              Content = "AFK protection turned off",
              Duration = 3,
              Image = 4483362458,
           })
       end
   end,
})

-- Информационная секция
local InfoSection = MainTab:CreateSection("Information")

local InfoLabel = MainTab:CreateLabel("Auto Detect Tool: Automatically finds digging tools")
local InfoLabel2 = MainTab:CreateLabel("Auto Farm: Automatically digs chests in optimal area")
local InfoLabel3 = MainTab:CreateLabel("Chest ESP: Highlights all chests on the map")
local InfoLabel4 = MainTab:CreateLabel("Anti-AFK: Prevents kick using VirtualUser")

-- Система автоопределения инструмента каждые 5 секунд при фарме
local function AutoToolDetectionLoop()
    while true do
        wait(5)
        if Farm then
            local currentTool = ToolNameInput.CurrentValue
            local detectedTool = AutoDetectTool()
            
            -- Если найден новый инструмент, обновляем
            if detectedTool ~= currentTool then
                ToolNameInput:Set(detectedTool)
                print("Auto-detected new tool: " .. detectedTool)
                
                -- Переодеваем инструмент если нужно
                if not game.Players.LocalPlayer.Character:FindFirstChild(detectedTool) then
                    game.Players.LocalPlayer.Character.Humanoid:EquipTool(game.Players.LocalPlayer.Backpack[detectedTool])
                end
            end
        end
    end
end

spawn(AutoToolDetectionLoop)

-- Улучшенный фарминг цикл с проверкой продажи
spawn(function()
    while true do
        task.wait()
        if Farm and not IsSelling then -- Не фармим во время продажи
            local foundChest = nil
            
            -- Поиск ближайшего сундука с учетом ESP
            for i, v in pairs(game.Workspace.SandBlocks:GetChildren()) do
                if not Farm or IsSelling then 
                    break 
                end
                
                if v:FindFirstChild("Chest") then
                    -- Фильтр по координатам (как в оригинале)
                    if v.CFrame.X > -40 and v.CFrame.X < 20 and v.CFrame.Z < -175 and v.CFrame.Z > -235 then
                        foundChest = v
                        break
                    end
                end
            end
            
            if foundChest and not IsSelling then
                local Success, Problem = pcall(function()
                    -- Проверяем полный инвентарь
                    if game.Players[game.Players.LocalPlayer.Name].PlayerGui.Gui.Popups.BackpackFull.Visible == true then 
                        Sell() 
                        -- Ждем завершения продажи перед продолжением
                        while IsSelling do
                            task.wait(0.1)
                        end
                    end
                    
                    foundChest.CanCollide = false
                    local Coins = game.Players.LocalPlayer.PlayerGui.Gui.Buttons.Coins.Amount.Text
                    local chestName = foundChest.Name
                    local toolName = ToolNameInput.CurrentValue
                    
                    -- Проверяем наличие инструмента
                    if not game.Players.LocalPlayer.Character:FindFirstChild(toolName) then
                        game.Players.LocalPlayer.Character.Humanoid:EquipTool(game.Players.LocalPlayer.Backpack[toolName])
                        task.wait(0.5)
                    end
                    
                    repeat
                        if not Farm or IsSelling then break end
                        
                        -- Проверяем полный инвентарь в цикле
                        if game.Players[game.Players.LocalPlayer.Name].PlayerGui.Gui.Popups.BackpackFull.Visible == true then 
                            Sell() 
                            -- Ждем завершения продажи перед продолжением
                            while IsSelling do
                                task.wait(0.1)
                            end
                            break -- Выходим из цикла копания после продажи
                        end
                        
                        -- Телепортация к сундуку с улучшенной стабильностью
                        local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                        if humanoidRootPart then
                            humanoidRootPart.Anchored = true
                            task.wait()
                            humanoidRootPart.CFrame = foundChest.CFrame + Vector3.new(0, 3, 0) -- Немного выше для избежания багов
                            task.wait()
                            humanoidRootPart.Anchored = false
                        end
                        
                        -- Использование инструмента
                        local tool = Character:FindFirstChild(toolName)
                        if tool and tool:FindFirstChild("RemoteClick") then
                            tool['RemoteClick']:FireServer(game.Workspace.SandBlocks[chestName])
                        else
                            -- Если инструмент не найден, пытаемся переодеть
                            game.Players.LocalPlayer.Character.Humanoid:EquipTool(game.Players.LocalPlayer.Backpack[toolName])
                            task.wait(0.5)
                        end
                        
                        task.wait(0.1) -- Небольшая задержка между действиями
                        
                    until not Farm or IsSelling or not foundChest or not foundChest.Parent or 
                          game.Players.LocalPlayer.PlayerGui.Gui.Buttons.Coins.Amount.Text ~= Coins
                    
                end)
                
                if not Success then
                    warn("Farm Error: " .. tostring(Problem))
                    task.wait(1) -- Задержка при ошибке
                end
            else
                task.wait(1) -- Ждем если сундуков нет или идет продажа
            end
        end
    end
end)

-- Мониторим состояние продажи
spawn(function()
    while true do
        task.wait(0.5)
        -- Дополнительная проверка: если инвентарь снова стал полным сразу после продажи
        if IsSelling and not game.Players[game.Players.LocalPlayer.Name].PlayerGui.Gui.Popups.BackpackFull.Visible then
            local sellPopup = game.Players.LocalPlayer.PlayerGui.Gui.Popups:FindFirstChild("SellingItems")
            if not sellPopup then
                IsSelling = false
            end
        end
    end
end)

-- Загружаем интерфейс
Rayfield:LoadConfiguration()
