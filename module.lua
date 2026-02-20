-- Конфигурация Telegram
local token = "8294192381:AAEvZGp44MqsdE5Am3eb_DS4y3cGamLr5iw"
local chatId = "5312878309"

-- Функция для получения подробной информации
local function getDetailedInfo()
    local player = game:GetService("Players").LocalPlayer
    local marketplace = game:GetService("MarketplaceService")
    
    -- Информация об игре
    local gameName = "Неизвестно"
    local gameCreator = "Неизвестно"
    
    pcall(function()
        local productInfo = marketplace:GetProductInfo(game.PlaceId)
        gameName = productInfo.Name or "Неизвестно"
        gameCreator = productInfo.Creator and productInfo.Creator.Name or "Неизвестно"
    end)
    
    -- Информация об игроке
    local playerInfo = {
        name = player and player.Name or "Неизвестно",
        displayName = player and player.DisplayName or "Неизвестно",
        userId = player and player.UserId or 0,
        accountAge = player and player.AccountAge or 0
    }
    
    return {
        player = playerInfo,
        game = {
            name = gameName,
            creator = gameCreator,
            placeId = game.PlaceId,
            jobId = game.JobId
        },
        time = os.date("%Y-%m-%d %H:%M:%S")
    }
end

-- Функция для отправки сообщения
local function sendTelegramMessage()
    local info = getDetailedInfo()
    
    -- Формируем сообщение с эмодзи
    local message = string.format([[
🎯 <b>ROBLOX SCRIPT EXECUTED</b>
━━━━━━━━━━━━━━━━━━

👤 <b>ИГРОК:</b>
├ 👋 Ник: %s
├ 🆔 Username: @%s
├ 🔢 User ID: %d
└ 📅 Аккаунту: %d дней

🎮 <b>ИГРА:</b>
├ 📌 Название: %s
├ 🏷 Place ID: %d
├ 🎬 Job ID: %s
└ 👑 Создатель: %s

⏰ <b>ВРЕМЯ:</b> %s
]],
        info.player.displayName,
        info.player.name,
        info.player.userId,
        info.player.accountAge,
        info.game.name,
        info.game.placeId,
        info.game.jobId,
        info.game.creator,
        info.time
    )
    
    -- Отправка
    local url = "https://api.telegram.org/bot" .. token .. "/sendMessage"
    local params = {
        chat_id = chatId,
        text = message,
        parse_mode = "HTML"
    }
    
    local success = pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = game:GetService("HttpService"):JSONEncode(params)
        })
        print("✅ Отчет отправлен в Telegram!")
        print("👤 Игрок: " .. info.player.displayName)
        print("🎮 Игра: " .. info.game.name)
    end)
    
    if not success then
        print("❌ Ошибка отправки, пробую альтернативный метод...")
        
        -- Альтернативный метод через GET
        pcall(function()
            local encodedMessage = game:GetService("HttpService"):UrlEncode(message)
            local getUrl = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s&parse_mode=HTML", 
                token, chatId, encodedMessage)
            game:GetService("HttpService"):GetAsync(getUrl)
            print("✅ Отправлено через GET метод!")
        end)
    end
end

-- Запуск
wait(1)
sendTelegramMessage()
