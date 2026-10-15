--[[
    ══════════════════════════════════════════════════════════════════════════
    BLISS FARM — YBA (Your Bizarre Adventure)
    Version: 4.1 Speed & Inventory Logic Fix
    Author: BlissOw
    ══════════════════════════════════════════════════════════════════════════
]]

-- =========================================================================
-- 1. СИСТЕМА ОЧИСТКИ ПАМЯТИ (Clean Unload / Re-exec Protection)
-- =========================================================================
if _G.BlissFarm_Cleanup and type(_G.BlissFarm_Cleanup) == "function" then
    pcall(_G.BlissFarm_Cleanup)
end

local CleaningUp = false
local Connections = {}
local RunningThreads = {}

local function trackConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

-- =========================================================================
-- 2. СЕРВИСЫ ROBLOX
-- =========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- 3. КОНФИГУРАЦИЯ И ПРЕДМЕТЫ
-- =========================================================================
local Config = {
    Version = "v4.5 Discord-Pro",
    TargetMoney = 1000000,          -- Целевой баланс: $1,000,000
    TargetArrows = 10,              -- Целевое кол-во Lucky Arrow: 10
    ArrowPrice = 75000,             -- Цена Lucky Arrow: $75,000
    HopMinMinutes = 6,
    DroughtSeconds = 45,            -- Время без лута до смены сервера
    ServerHopEnabled = true,
    BlacklistTTL = 60,              -- Время черного списка застрявших айтемов (сек)
    TeleportOffset = 6.0,           -- Безопасная глубина под предметом (без конфликта коллизий и рэйкастов)
    SellThreshold = 8,              -- Продавать при 8+ предметах
    MinSellBatch = 2,               -- Не бегать к торговцу ради 1 предмета
    MaxInventorySlots = 10,         -- Вместимость инвентаря без 2x Gamepass
    GrabTimeout = 1.2,              -- Максимальное ожидание подбора (сек)

    -- Настройки Discord Webhook:
    WebhookUrl = "",                -- Вставьте вашу ссылку Discord Webhook (или сохраните в BlissFarm_Config.json)
    WebhookEnabled = true,          -- Отправка уведомлений в Discord
    WebhookPingOnLucky = false,     -- Пинг @everyone при нахождении/покупке Lucky Arrow
    WebhookReportInterval = 15,     -- Интервал регулярного отчёта (в минутах)
}

-- Авто-загрузка сохранённых настроек Discord Webhook (BlissFarm_Config.json)
pcall(function()
    if type(readfile) == "function" and type(isfile) == "function" and isfile("BlissFarm_Config.json") then
        local raw = readfile("BlissFarm_Config.json")
        local data = HttpService:JSONDecode(raw)
        if type(data) == "table" then
            if data.WebhookUrl and data.WebhookUrl ~= "" then
                Config.WebhookUrl = data.WebhookUrl
            end
            if data.WebhookEnabled ~= nil then
                Config.WebhookEnabled = data.WebhookEnabled
            end
            if data.WebhookPingOnLucky ~= nil then
                Config.WebhookPingOnLucky = data.WebhookPingOnLucky
            end
            if data.WebhookReportInterval and tonumber(data.WebhookReportInterval) then
                Config.WebhookReportInterval = tonumber(data.WebhookReportInterval)
            end
        end
    end
end)

-- Официальная таблица лимитов стаков спавнящихся предметов (Ровно 16 предметов)
local BaseMaxAmounts = {
    ["Gold Coin"]                      = 45,
    ["Rokakaka"]                       = 25,
    ["Pure Rokakaka"]                  = 10,
    ["Mysterious Arrow"]               = 25,
    ["Diamond"]                        = 30,
    ["Ancient Scroll"]                 = 10,
    ["Caesar's Headband"]              = 10,
    ["Stone Mask"]                     = 10,
    ["Rib Cage of The Saint's Corpse"] = 20,
    ["Quinton's Glove"]                = 10,
    ["Zeppeli's Hat"]                  = 10,
    ["Lucky Arrow"]                    = 10,
    ["Lucky Stone Mask"]               = 10,
    ["Clackers"]                       = 10,
    ["Steel Ball"]                     = 10,
    ["Dio's Diary"]                    = 10,
}
local ItemLimits = BaseMaxAmounts

-- Цены предметов при продаже торговцу (для умного выбора лута)
local ItemPrices = {
    ["Pure Rokakaka"]                  = 1500,
    ["Rib Cage of The Saint's Corpse"] = 1200,
    ["Ancient Scroll"]                 = 1000,
    ["Quinton's Glove"]                = 1000,
    ["Zeppeli's Hat"]                  = 1000,
    ["Clackers"]                       = 1000,
    ["Caesar's Headband"]              = 1000,
    ["Dio's Diary"]                    = 1000,
    ["Steel Ball"]                     = 1000,
    ["Stone Mask"]                     = 1000,
    ["Rokakaka"]                       = 600,
    ["Diamond"]                        = 500,
    ["Mysterious Arrow"]               = 200,
    ["Gold Coin"]                      = 120,
    ["Lucky Arrow"]                    = 1000000, -- Бесценно: абсолютный приоритет
    ["Lucky Stone Mask"]               = 1000000, -- Бесценно: абсолютный приоритет
}

local SellableItems = {
    ["Gold Coin"] = true,
    ["Mysterious Arrow"] = true,
    ["Rokakaka"] = true,
    ["Pure Rokakaka"] = true,
    ["Ancient Scroll"] = true,
    ["Quinton's Glove"] = true,
    ["Diamond"] = true,
    ["Zeppeli's Hat"] = true,
    ["Clackers"] = true,
    ["Rib Cage of The Saint's Corpse"] = true,
    ["Caesar's Headband"] = true,
    ["Dio's Diary"] = true,
    ["Steel Ball"] = true,
    ["Stone Mask"] = true,
}

local KeepItems = {
    ["Lucky Arrow"] = true,
    ["Lucky Stone Mask"] = true,
}

local PatrolPoints = {
    Vector3.new(95, 62, 72),
    Vector3.new(-216, 10, -66),
    Vector3.new(-36, -42, 523),
    Vector3.new(39, -33, 23),
    Vector3.new(-200, -33, -269),
    Vector3.new(-65, -33, -606),
    Vector3.new(73, 24, -932),
    Vector3.new(97, 14, -531),
    Vector3.new(253, 57, -210),
    Vector3.new(509, 14, 106),
    Vector3.new(976, -43, -111),
    Vector3.new(-655, -21, -750),
    Vector3.new(-190, 15, -585),
    Vector3.new(-182, 0, -231)
}

local MerchantPosition = Vector3.new(-702, -25, -335)

-- =========================================================================
-- 4. СОСТОЯНИЕ (State)
-- =========================================================================
local State = {
    Running = true,
    Character = nil,
    Humanoid = nil,
    RootPart = nil,
    RemoteEvent = nil,
    RemoteFunction = nil,
    LastKnownMoney = 0,
    BuyFails = 0,
    Blacklist = {},
    LastLootTime = tick(),
    TotalPicked = 0,
    SellFails = 0,
    LockedPosition = nil,
    LockConnection = nil,
    StartTime = tick(),
    StartMoney = nil,
    RaresFound = 0,
    LastPhase = 1,
    LastWebhookReport = tick(),
}

-- =========================================================================
-- 5. МОЛНИЕНОСНЫЙ И БЕЗОПАСНЫЙ СЛОЙ ЭКСПЛОИТА (Fast Proximity & Input)
-- =========================================================================
local SafePrompt = function(prompt)
    if not prompt or not prompt.Parent then return false end

    -- ТОЛЬКО fireproximityprompt, без палевных InputHoldBegin/End
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt, 0)
        pcall(fireproximityprompt, prompt)
        return true
    end

    return false
end

local SafeClickButton = function(btn)
    if not btn or not btn.Parent then return false end
    local clicked = false

    local fakeInput = {
        UserInputType = Enum.UserInputType.MouseButton1,
        UserInputState = Enum.UserInputState.Begin,
        Position = Vector2.new(100, 100),
        Delta = Vector2.new(0, 0)
    }

    if type(getconnections) == "function" then
        pcall(function()
            for _, sigName in ipairs({"MouseButton1Click", "Activated", "InputBegan"}) do
                local sig = btn[sigName]
                if sig then
                    for _, cn in ipairs(getconnections(sig)) do
                        pcall(function() cn.Function(fakeInput) end)
                        pcall(function() cn.Function() end)
                        clicked = true
                    end
                end
            end
        end)
    end

    if not clicked and VirtualInputManager then
        pcall(function()
            local x = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2
            local y = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.06 + math.random() * 0.04)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            clicked = true
        end)
    end

    return clicked
end

-- =========================================================================
-- 6. DISCORD WEBHOOK МОДУЛЬ (Rich Embeds & Notifications)
-- =========================================================================
local function sendDiscordWebhook(embedData, content)
    if not Config.WebhookEnabled or not Config.WebhookUrl or Config.WebhookUrl == "" then
        return false
    end

    local reqFunc = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (syn and type(syn.request) == "function" and syn.request)
        or (http and type(http.request) == "function" and http.request)

    if not reqFunc then
        return false
    end

    local payload = {
        username = "⚡ Bliss Farm • YBA",
        avatar_url = "https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/icon.png",
        content = content or "",
        embeds = { embedData }
    }

    local success, jsonPayload = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not success or not jsonPayload then return false end

    task.spawn(function()
        pcall(function()
            reqFunc({
                Url = Config.WebhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonPayload
            })
        end)
    end)
    return true
end

local function Webhook_SendStartup()
    local embed = {
        title = "⚡ Bliss Farm " .. Config.Version .. " Успешно Запущен!",
        description = string.format("Игрок: `%s`\nСервер: `%s`\nФарм в процессе...", LocalPlayer.Name, game.JobId ~= "" and game.JobId or "Public"),
        color = 3447003, -- Синий
        fields = {
            { name = "🎯 Цели", value = "🏹 10 Lucky | 💰 $1,000,000 | 📦 16/16 Стаков", inline = false },
            { name = "⏱ Интервал отчётов", value = Config.WebhookReportInterval .. " мин", inline = true },
            { name = "🔔 Пинг @everyone", value = Config.WebhookPingOnLucky and "Включён" or "Выключен", inline = true }
        },
        footer = { text = "⚡ Bliss Farm • YBA by BlissOw" },
        timestamp = DateTime.now():ToIsoDate()
    }
    sendDiscordWebhook(embed)
end

local function Webhook_SendLuckyArrow(source, count)
    local embed = {
        title = "🏹 LUCKY ARROW ПОЛУЧЕНА!",
        description = string.format("**Способ:** %s\n**Игрок:** `%s`\n**Текущий запас:** **%d/10** Lucky Arrow",
            source, LocalPlayer.Name, count),
        color = 16766720, -- 0xFFD700 Золотой
        fields = {
            { name = "💰 Баланс", value = "$" .. tostring(getPlayerMoney()), inline = true },
            { name = "⏱ Время сессии", value = math.floor((tick() - State.StartTime) / 60) .. " мин", inline = true },
            { name = "📦 Собрано лута", value = tostring(State.TotalPicked) .. " шт.", inline = true },
        },
        footer = { text = "⚡ Bliss Farm • YBA God-Collector" },
        timestamp = DateTime.now():ToIsoDate()
    }
    local ping = Config.WebhookPingOnLucky and "@everyone" or ""
    sendDiscordWebhook(embed, ping)
end

local function Webhook_SendRareItem(name, count)
    local embed = {
        title = "🍀 ПОДНЯТ РЕДКИЙ ПРЕДМЕТ!",
        description = string.format("**Предмет:** `%s`\n**В рюкзаке:** **%d/%d**\n**Игрок:** `%s`",
            name, count, BaseMaxAmounts[name] or 10, LocalPlayer.Name),
        color = 3066993, -- 0x2ECC71 Изумрудный
        fields = {
            { name = "💰 Баланс", value = "$" .. tostring(getPlayerMoney()), inline = true },
            { name = "⏱ Сессия", value = math.floor((tick() - State.StartTime) / 60) .. " мин", inline = true }
        },
        footer = { text = "⚡ Bliss Farm • YBA" },
        timestamp = DateTime.now():ToIsoDate()
    }
    sendDiscordWebhook(embed)
end

local function Webhook_SendMilestone(title, desc, color, pingEveryone)
    local embed = {
        title = title,
        description = desc,
        color = color or 65280,
        fields = {
            { name = "👤 Игрок", value = "`" .. LocalPlayer.Name .. "`", inline = true },
            { name = "💰 Баланс", value = "$" .. tostring(getPlayerMoney()), inline = true },
            { name = "🏹 Lucky Arrows", value = tostring(countLuckyArrows()) .. "/10", inline = true },
        },
        footer = { text = "⚡ Bliss Farm • YBA God-Collector" },
        timestamp = DateTime.now():ToIsoDate()
    }
    local ping = pingEveryone and "@everyone" or ""
    sendDiscordWebhook(embed, ping)
end

local function Webhook_SendReport(uptimeMinutes, sessionProfit, money, arrows, completedStacks, totalStacks)
    local embed = {
        title = "📊 Отчёт Bliss Farm о прогрессе",
        description = string.format("Регулярный статус-отчёт фарма игрока `%s`", LocalPlayer.Name),
        color = 5793266, -- 0x5865F2 Blurple
        fields = {
            { name = "⏱ Время работы", value = uptimeMinutes .. " мин", inline = true },
            { name = "💵 Прибыль сессии", value = "+$" .. sessionProfit, inline = true },
            { name = "💰 Текущий баланс", value = "$" .. money, inline = true },
            { name = "🏹 Lucky Arrows", value = string.format("%d/%d", arrows, Config.TargetArrows), inline = true },
            { name = "📦 Заполнено стаков", value = string.format("%d/%d", completedStacks, totalStacks), inline = true },
            { name = "⚡ Всего поднято лута", value = tostring(State.TotalPicked) .. " шт.", inline = true },
        },
        footer = { text = "⚡ Bliss Farm • Авто-отчёт" },
        timestamp = DateTime.now():ToIsoDate()
    }
    sendDiscordWebhook(embed)
end

-- =========================================================================
-- 6. ОБХОД АНТИЧИТА (YBA Metamethod Hook)
-- =========================================================================
pcall(function()
    if type(hookmetamethod) == "function" and type(newcclosure) == "function" then
        local originalNamecall
        originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local args = {...}
            local method = getnamecallmethod()
            if method == "InvokeServer" and args[1] == "idklolbrah2de" then
                return "  ___XP DE KEY"
            end
            return originalNamecall(self, ...)
        end))
    end
end)

-- =========================================================================
-- 7. УПРАВЛЕНИЕ ПЕРСОНАЖЕМ
-- =========================================================================
local function refreshCharacter()
    if CleaningUp then return end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    State.Character = char
    State.Humanoid = char:WaitForChild("Humanoid", 10)
    State.RootPart = char:WaitForChild("HumanoidRootPart", 10)
    State.RemoteEvent = char:WaitForChild("RemoteEvent", 10)
    pcall(function()
        State.RemoteFunction = char:FindFirstChild("RemoteFunction") or char:WaitForChild("RemoteFunction", 2)
    end)
end

refreshCharacter()

trackConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if not CleaningUp then
        pcall(refreshCharacter)
        State.Blacklist = {}
        State.LastLootTime = tick()
    end
end))

-- =========================================================================
-- 8. ПРЕМИАЛЬНЫЙ ФИОЛЕТОВЫЙ ИНТЕРФЕЙС (Purple Neon Tabs & Mascot Toggle)
-- =========================================================================
local targetGuiParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if CoreGui and pcall(function() return CoreGui:GetChildren() end) then
        targetGuiParent = CoreGui
    end
end)

for _, g in ipairs(targetGuiParent:GetChildren()) do
    if g.Name == "BlissFarmUI" then
        g:Destroy()
    end
end

-- Загрузка локального ассета маскота (если эксплоит поддерживает getcustomasset)
local LogoAssetId = nil
pcall(function()
    local logoFileName = "bliss_demon_logo.png"
    if type(writefile) == "function" and type(readfile) == "function" and type(getcustomasset) == "function" then
        if not (type(isfile) == "function" and isfile(logoFileName)) then
            local rawImage = game:HttpGet("https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/assets/logo.png?v=2")
            writefile(logoFileName, rawImage)
        end
        LogoAssetId = getcustomasset(logoFileName)
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BlissFarmUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- 🔘 ПЛАВАЮЩАЯ КНОПКА-МАСКОТ (ОТКРЫВАШКА / ЗАКРЫВАШКА ДЛЯ ТЕЛЕФОНОВ И ПК)
local FloatingToggle = Instance.new("ImageButton")
FloatingToggle.Name = "FloatingMascotToggle"
FloatingToggle.Size = UDim2.new(0, 52, 0, 52)
FloatingToggle.Position = UDim2.new(0, 18, 0.45, 0)
FloatingToggle.BackgroundColor3 = Color3.fromRGB(18, 12, 28)
FloatingToggle.BackgroundTransparency = 0.05
FloatingToggle.BorderSizePixel = 0
FloatingToggle.AutoButtonColor = true

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatingToggle

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Thickness = 2.2
FloatStroke.Color = Color3.fromRGB(168, 85, 247) -- Неоновый фиолетовый
FloatStroke.Parent = FloatingToggle

if LogoAssetId then
    FloatingToggle.Image = LogoAssetId
    FloatingToggle.ScaleType = Enum.ScaleType.Fit
else
    local FallbackIcon = Instance.new("TextLabel")
    FallbackIcon.Size = UDim2.new(1, 0, 1, 0)
    FallbackIcon.BackgroundTransparency = 1
    FallbackIcon.Text = "😈"
    FallbackIcon.TextSize = 28
    FallbackIcon.Parent = FloatingToggle
end

-- Перетаскивание плавающей кнопки с защитой от ложного клика
local fDrag, fDragInput, fDragStart, fStartPos
local fHasMoved = false

trackConnection(FloatingToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fDrag = true
        fDragStart = input.Position
        fStartPos = FloatingToggle.Position
        fHasMoved = false
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                fDrag = false
            end
        end)
    end
end))

trackConnection(FloatingToggle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        fDragInput = input
    end
end))

trackConnection(game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == fDragInput and fDrag then
        local delta = input.Position - fDragStart
        if (delta.X * delta.X + delta.Y * delta.Y) > 36 then
            fHasMoved = true
        end
        FloatingToggle.Position = UDim2.new(
            fStartPos.X.Scale,
            fStartPos.X.Offset + delta.X,
            fStartPos.Y.Scale,
            fStartPos.Y.Offset + delta.Y
        )
    end
end))

-- Подсветка при наведении
trackConnection(FloatingToggle.MouseEnter:Connect(function()
    FloatStroke.Color = Color3.fromRGB(220, 180, 255)
    FloatStroke.Thickness = 3
end))
trackConnection(FloatingToggle.MouseLeave:Connect(function()
    FloatStroke.Color = Color3.fromRGB(168, 85, 247)
    FloatStroke.Thickness = 2.2
end))

-- 🌌 ГЛАВНОЕ ОКНО ХАБА
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 430, 0, 240)
MainFrame.Position = UDim2.new(0.5, -215, 0.5, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
MainFrame.BackgroundTransparency = 0.08
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.8
MainStroke.Color = Color3.fromRGB(168, 85, 247)
MainStroke.Parent = MainFrame

-- Нажатие на кнопку-маскот открывает / закрывает окно (если не тащили)
trackConnection(FloatingToggle.MouseButton1Click:Connect(function()
    if not fHasMoved then
        MainFrame.Visible = not MainFrame.Visible
    end
end))

-- Верхняя панель (Header)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(24, 18, 38)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

if LogoAssetId then
    local HeaderMascot = Instance.new("ImageLabel")
    HeaderMascot.Size = UDim2.new(0, 26, 0, 26)
    HeaderMascot.Position = UDim2.new(0, 8, 0, 5)
    HeaderMascot.BackgroundTransparency = 1
    HeaderMascot.Image = LogoAssetId
    HeaderMascot.ScaleType = Enum.ScaleType.Fit
    HeaderMascot.Parent = Header
end

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = LogoAssetId and UDim2.new(1, -148, 1, 0) or UDim2.new(1, -120, 1, 0)
TitleLabel.Position = LogoAssetId and UDim2.new(0, 38, 0, 0) or UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextColor3 = Color3.fromRGB(216, 180, 254)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ BLISS FARM • YBA God-Collector"
TitleLabel.Parent = Header

-- Кнопка Старт/Пауза
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 28, 0, 22)
ToggleButton.Position = UDim2.new(1, -72, 0, 7)
ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
ToggleButton.Text = "■"
ToggleButton.TextColor3 = Color3.new(1, 1, 1)
ToggleButton.TextSize = 13
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.BorderSizePixel = 0
ToggleButton.Parent = Header

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleButton

-- Кнопка скрыть меню (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 28, 0, 22)
CloseBtn.Position = UDim2.new(1, -38, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(38, 28, 54)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(200, 180, 220)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

trackConnection(CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end))

-- Панель навигации по вкладкам (Tabs Bar)
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -20, 0, 28)
TabBar.Position = UDim2.new(0, 10, 0, 42)
TabBar.BackgroundColor3 = Color3.fromRGB(22, 16, 34)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local Tabs = {}
local TabPages = {}

local function createTabButton(name, icon, index, totalTabs)
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. name
    btn.Size = UDim2.new(1 / totalTabs, -4, 1, -4)
    btn.Position = UDim2.new((index - 1) * (1 / totalTabs), 2, 0, 2)
    btn.BackgroundColor3 = (index == 1) and Color3.fromRGB(147, 51, 234) or Color3.fromRGB(28, 20, 44)
    btn.Text = icon .. " " .. name
    btn.TextColor3 = Color3.fromRGB(240, 230, 255)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = TabBar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local page = Instance.new("Frame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, -20, 1, -80)
    page.Position = UDim2.new(0, 10, 0, 74)
    page.BackgroundTransparency = 1
    page.Visible = (index == 1)
    page.Parent = MainFrame

    Tabs[index] = btn
    TabPages[index] = page

    trackConnection(btn.MouseButton1Click:Connect(function()
        for i, b in ipairs(Tabs) do
            b.BackgroundColor3 = (i == index) and Color3.fromRGB(147, 51, 234) or Color3.fromRGB(28, 20, 44)
            TabPages[i].Visible = (i == index)
        end
    end))

    return page
end

local PageDashboard = createTabButton("Главная", "📊", 1, 4)
local PageWebhook   = createTabButton("Discord", "📢", 2, 4)
local PageSettings  = createTabButton("Опции", "⚙️", 3, 4)
local PageAbout     = createTabButton("Автор", "👑", 4, 4)

-- ═════════════════════════════════════════════════════════════════════════
-- ВКЛАДКА 1: ДАШБОРД (Dashboard)
-- ═════════════════════════════════════════════════════════════════════════
local StatusLine1 = Instance.new("TextLabel")
StatusLine1.Size = UDim2.new(1, 0, 0, 24)
StatusLine1.Position = UDim2.new(0, 0, 0, 6)
StatusLine1.BackgroundColor3 = Color3.fromRGB(26, 18, 42)
StatusLine1.TextColor3 = Color3.fromRGB(216, 180, 254)
StatusLine1.TextSize = 12
StatusLine1.Font = Enum.Font.GothamBold
StatusLine1.Text = "🚀 Инициализация системы..."
StatusLine1.Parent = PageDashboard

local S1Corner = Instance.new("UICorner")
S1Corner.CornerRadius = UDim.new(0, 6)
S1Corner.Parent = StatusLine1

local StatusLine2 = Instance.new("TextLabel")
StatusLine2.Size = UDim2.new(1, 0, 0, 22)
StatusLine2.Position = UDim2.new(0, 0, 0, 36)
StatusLine2.BackgroundTransparency = 1
StatusLine2.TextXAlignment = Enum.TextXAlignment.Left
StatusLine2.TextColor3 = Color3.fromRGB(192, 132, 252)
StatusLine2.TextSize = 11
StatusLine2.Font = Enum.Font.GothamSemibold
StatusLine2.Text = "💰 Баланс: $0 | 🏹 Lucky: 0/10"
StatusLine2.Parent = PageDashboard

local StatusLine3 = Instance.new("TextLabel")
StatusLine3.Size = UDim2.new(1, 0, 0, 22)
StatusLine3.Position = UDim2.new(0, 0, 0, 60)
StatusLine3.BackgroundTransparency = 1
StatusLine3.TextXAlignment = Enum.TextXAlignment.Left
StatusLine3.TextColor3 = Color3.fromRGB(240, 240, 255)
StatusLine3.TextSize = 11
StatusLine3.Font = Enum.Font.Gotham
StatusLine3.Text = "⏱ 0m | 💵 +$0 сессия | 🍀 Рарки: 0"
StatusLine3.Parent = PageDashboard

local ActionBadge = Instance.new("TextLabel")
ActionBadge.Size = UDim2.new(1, 0, 0, 36)
ActionBadge.Position = UDim2.new(0, 0, 0, 92)
ActionBadge.BackgroundColor3 = Color3.fromRGB(24, 16, 38)
ActionBadge.TextColor3 = Color3.fromRGB(168, 85, 247)
ActionBadge.TextSize = 11
ActionBadge.Font = Enum.Font.Gotham
ActionBadge.Text = "✨ Stealth Anti-Kick активен • Поиск лута..."
ActionBadge.Parent = PageDashboard

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = ActionBadge

-- ═════════════════════════════════════════════════════════════════════════
-- ВКЛАДКА 2: DISCORD WEBHOOK
-- ═════════════════════════════════════════════════════════════════════════
local WebhookDesc = Instance.new("TextLabel")
WebhookDesc.Size = UDim2.new(1, 0, 0, 18)
WebhookDesc.Position = UDim2.new(0, 0, 0, 4)
WebhookDesc.BackgroundTransparency = 1
WebhookDesc.TextXAlignment = Enum.TextXAlignment.Left
WebhookDesc.TextColor3 = Color3.fromRGB(216, 180, 254)
WebhookDesc.TextSize = 11
WebhookDesc.Font = Enum.Font.GothamBold
WebhookDesc.Text = "Ссылка на ваш Discord Webhook:"
WebhookDesc.Parent = PageWebhook

local WebhookBox = Instance.new("TextBox")
WebhookBox.Name = "WebhookInput"
WebhookBox.Size = UDim2.new(1, 0, 0, 28)
WebhookBox.Position = UDim2.new(0, 0, 0, 24)
WebhookBox.BackgroundColor3 = Color3.fromRGB(26, 18, 42)
WebhookBox.TextColor3 = Color3.fromRGB(240, 240, 255)
WebhookBox.PlaceholderColor3 = Color3.fromRGB(120, 100, 150)
WebhookBox.PlaceholderText = "https://discord.com/api/webhooks/..."
WebhookBox.Text = Config.WebhookUrl or ""
WebhookBox.TextSize = 10
WebhookBox.Font = Enum.Font.Gotham
WebhookBox.ClearTextOnFocus = false
WebhookBox.BorderSizePixel = 0
WebhookBox.Parent = PageWebhook

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = WebhookBox

local BoxStroke = Instance.new("UIStroke")
BoxStroke.Color = Color3.fromRGB(147, 51, 234)
BoxStroke.Thickness = 1
BoxStroke.Parent = WebhookBox

local WebhookStatus = Instance.new("TextLabel")
WebhookStatus.Size = UDim2.new(1, 0, 0, 16)
WebhookStatus.Position = UDim2.new(0, 0, 0, 56)
WebhookStatus.BackgroundTransparency = 1
WebhookStatus.TextXAlignment = Enum.TextXAlignment.Left
WebhookStatus.TextColor3 = Color3.fromRGB(134, 239, 172)
WebhookStatus.TextSize = 10
WebhookStatus.Font = Enum.Font.Gotham
WebhookStatus.Text = (Config.WebhookUrl ~= "") and "✅ Webhook настроен" or "⚠️ Webhook не указан"
WebhookStatus.Parent = PageWebhook

-- Кнопки Сохранить и Тест
local SaveWebhookBtn = Instance.new("TextButton")
SaveWebhookBtn.Size = UDim2.new(0.48, 0, 0, 28)
SaveWebhookBtn.Position = UDim2.new(0, 0, 0, 80)
SaveWebhookBtn.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
SaveWebhookBtn.TextColor3 = Color3.new(1, 1, 1)
SaveWebhookBtn.Text = "💾 Сохранить Webhook"
SaveWebhookBtn.TextSize = 11
SaveWebhookBtn.Font = Enum.Font.GothamBold
SaveWebhookBtn.BorderSizePixel = 0
SaveWebhookBtn.Parent = PageWebhook

local SwCorner = Instance.new("UICorner")
SwCorner.CornerRadius = UDim.new(0, 6)
SwCorner.Parent = SaveWebhookBtn

local TestWebhookBtn = Instance.new("TextButton")
TestWebhookBtn.Size = UDim2.new(0.48, 0, 0, 28)
TestWebhookBtn.Position = UDim2.new(0.52, 0, 0, 80)
TestWebhookBtn.BackgroundColor3 = Color3.fromRGB(38, 26, 60)
TestWebhookBtn.TextColor3 = Color3.fromRGB(216, 180, 254)
TestWebhookBtn.Text = "🚀 Отправить Тест"
TestWebhookBtn.TextSize = 11
TestWebhookBtn.Font = Enum.Font.GothamBold
TestWebhookBtn.BorderSizePixel = 0
TestWebhookBtn.Parent = PageWebhook

local TwCorner = Instance.new("UICorner")
TwCorner.CornerRadius = UDim.new(0, 6)
TwCorner.Parent = TestWebhookBtn

local PingToggleBtn = Instance.new("TextButton")
PingToggleBtn.Size = UDim2.new(1, 0, 0, 24)
PingToggleBtn.Position = UDim2.new(0, 0, 0, 116)
PingToggleBtn.BackgroundColor3 = Color3.fromRGB(24, 16, 38)
PingToggleBtn.TextColor3 = Color3.fromRGB(200, 190, 220)
PingToggleBtn.Text = "🔔 Пинг @everyone при Lucky: " .. (Config.WebhookPingOnLucky and "ВКЛ" or "ВЫКЛ")
PingToggleBtn.TextSize = 10
PingToggleBtn.Font = Enum.Font.Gotham
PingToggleBtn.BorderSizePixel = 0
PingToggleBtn.Parent = PageWebhook

local PtCorner = Instance.new("UICorner")
PtCorner.CornerRadius = UDim.new(0, 6)
PtCorner.Parent = PingToggleBtn

trackConnection(PingToggleBtn.MouseButton1Click:Connect(function()
    Config.WebhookPingOnLucky = not Config.WebhookPingOnLucky
    PingToggleBtn.Text = "🔔 Пинг @everyone при Lucky: " .. (Config.WebhookPingOnLucky and "ВКЛ" or "ВЫКЛ")
end))

trackConnection(SaveWebhookBtn.MouseButton1Click:Connect(function()
    Config.WebhookUrl = WebhookBox.Text:gsub("%s+", "")
    pcall(function()
        if type(writefile) == "function" then
            local toSave = {
                WebhookUrl = Config.WebhookUrl,
                WebhookEnabled = Config.WebhookEnabled,
                WebhookPingOnLucky = Config.WebhookPingOnLucky,
                WebhookReportInterval = Config.WebhookReportInterval,
            }
            writefile("BlissFarm_Config.json", HttpService:JSONEncode(toSave))
        end
    end)
    WebhookStatus.Text = "✅ Сохранено в BlissFarm_Config.json!"
end))

trackConnection(TestWebhookBtn.MouseButton1Click:Connect(function()
    Config.WebhookUrl = WebhookBox.Text:gsub("%s+", "")
    if Config.WebhookUrl == "" then
        WebhookStatus.Text = "❌ Сначала вставьте ссылку на Webhook!"
        return
    end
    WebhookStatus.Text = "⏳ Отправка тестового сообщения..."
    local ok = pcall(Webhook_SendStartup)
    if ok then
        WebhookStatus.Text = "✅ Тестовое сообщение отправлено в Discord!"
    else
        WebhookStatus.Text = "❌ Ошибка при отправке!"
    end
end))

-- ═════════════════════════════════════════════════════════════════════════
-- ВКЛАДКА 3: ОПЦИИ / НАСТРОЙКИ (Settings)
-- ═════════════════════════════════════════════════════════════
local HopToggleBtn = Instance.new("TextButton")
HopToggleBtn.Size = UDim2.new(1, 0, 0, 32)
HopToggleBtn.Position = UDim2.new(0, 0, 0, 10)
HopToggleBtn.BackgroundColor3 = Color3.fromRGB(26, 18, 42)
HopToggleBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
HopToggleBtn.Text = "🚀 Server Hop при засухе спавна: " .. (Config.ServerHopEnabled and "ВКЛ" or "ВЫКЛ")
HopToggleBtn.TextSize = 11
HopToggleBtn.Font = Enum.Font.GothamBold
HopToggleBtn.BorderSizePixel = 0
HopToggleBtn.Parent = PageSettings

local HtCorner = Instance.new("UICorner")
HtCorner.CornerRadius = UDim.new(0, 8)
HtCorner.Parent = HopToggleBtn

trackConnection(HopToggleBtn.MouseButton1Click:Connect(function()
    Config.ServerHopEnabled = not Config.ServerHopEnabled
    HopToggleBtn.Text = "🚀 Server Hop при засухе спавна: " .. (Config.ServerHopEnabled and "ВКЛ" or "ВЫКЛ")
end))

local InfoCard = Instance.new("TextLabel")
InfoCard.Size = UDim2.new(1, 0, 0, 70)
InfoCard.Position = UDim2.new(0, 0, 0, 52)
InfoCard.BackgroundColor3 = Color3.fromRGB(20, 14, 32)
InfoCard.TextColor3 = Color3.fromRGB(192, 132, 252)
InfoCard.TextSize = 11
InfoCard.Font = Enum.Font.Gotham
InfoCard.TextWrapped = true
InfoCard.Text = "🛡️ Защита: Heartbeat Positioning + Human Jitter\n📦 Лимит: BaseMaxAmounts (16 предметов карты)\n🏹 Автопокупка 10 Lucky Arrow за $75k"
InfoCard.Parent = PageSettings

local IcCorner = Instance.new("UICorner")
IcCorner.CornerRadius = UDim.new(0, 8)
IcCorner.Parent = InfoCard

-- ═════════════════════════════════════════════════════════════════════════
-- ВКЛАДКА 4: АВТОР / VIP
-- ═════════════════════════════════════════════════════════════════════════
local AboutTitle = Instance.new("TextLabel")
AboutTitle.Size = UDim2.new(1, 0, 0, 26)
AboutTitle.Position = UDim2.new(0, 0, 0, 8)
AboutTitle.BackgroundTransparency = 1
AboutTitle.TextColor3 = Color3.fromRGB(216, 180, 254)
AboutTitle.TextSize = 14
AboutTitle.Font = Enum.Font.GothamBold
AboutTitle.Text = "⚡ BLISS FARM • God-Collector Edition"
AboutTitle.Parent = PageAbout

local AboutDesc = Instance.new("TextLabel")
AboutDesc.Size = UDim2.new(1, 0, 0, 48)
AboutDesc.Position = UDim2.new(0, 0, 0, 36)
AboutDesc.BackgroundTransparency = 1
AboutDesc.TextColor3 = Color3.fromRGB(180, 160, 210)
AboutDesc.TextSize = 11
AboutDesc.Font = Enum.Font.Gotham
AboutDesc.TextWrapped = true
AboutDesc.Text = "Создатель и разработчик: BlissOw\nВерсия: v4.6 Purple Stealth\nСтатус лицензии: Активна (VIP Commercial)"
AboutDesc.Parent = PageAbout

local CopyRepoBtn = Instance.new("TextButton")
CopyRepoBtn.Size = UDim2.new(1, 0, 0, 30)
CopyRepoBtn.Position = UDim2.new(0, 0, 0, 94)
CopyRepoBtn.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
CopyRepoBtn.TextColor3 = Color3.new(1, 1, 1)
CopyRepoBtn.Text = "📋 Скопировать ссылку на GitHub"
CopyRepoBtn.TextSize = 11
CopyRepoBtn.Font = Enum.Font.GothamBold
CopyRepoBtn.BorderSizePixel = 0
CopyRepoBtn.Parent = PageAbout

local CrCorner = Instance.new("UICorner")
CrCorner.CornerRadius = UDim.new(0, 6)
CrCorner.Parent = CopyRepoBtn

trackConnection(CopyRepoBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if type(setclipboard) == "function" then
            setclipboard("https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/main.lua")
            CopyRepoBtn.Text = "✅ Ссылка скопирована в буфер!"
            task.wait(1.5)
            CopyRepoBtn.Text = "📋 Скопировать ссылку на GitHub"
        end
    end)
end))

-- Перетаскивание главного окна
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

trackConnection(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end))

trackConnection(Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

trackConnection(game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end))

FloatingToggle.Parent = ScreenGui
MainFrame.Parent = ScreenGui
ScreenGui.Parent = targetGuiParent

local function updateStatus(line1, line2, line3)
    if line1 then ActionBadge.Text = line1 end
    if line2 then StatusLine2.Text = line2 end
    if line3 then StatusLine3.Text = line3 end
end

trackConnection(ToggleButton.MouseButton1Click:Connect(function()
    State.Running = not State.Running
    if State.Running then
        ToggleButton.Text = "■"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        updateStatus("▶ РАБОТА ВОЗОБНОВЛЕНА")
    else
        ToggleButton.Text = "▶"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        updateStatus("⛔ НА ПАУЗЕ", "Нажмите ▶ для продолжения")
    end
end))

local function waitIfPaused()
    while not State.Running and not CleaningUp do
        task.wait(0.3)
    end
end

-- =========================================================================
-- 9. БЫСТРЫЙ ДВИЖОК ПЕРЕМЕЩЕНИЯ (Noclip & Position Locking)
-- =========================================================================
local function lockToPosition(targetPos)
    State.LockedPosition = Vector3.new(targetPos.X, targetPos.Y - Config.TeleportOffset, targetPos.Z)

    if State.LockConnection then
        State.LockConnection:Disconnect()
    end

    -- Перемещение ТОЛЬКО внутри Heartbeat (без прямого CFrame снаружи!)
    State.LockConnection = RunService.Heartbeat:Connect(function()
        if not State.Running or not State.LockedPosition or CleaningUp then return end
        local hrp = State.RootPart
        if not hrp or not hrp.Parent then return end

        hrp.CFrame = CFrame.new(State.LockedPosition)
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)
end

local function unlockPosition()
    State.LockedPosition = nil
    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
    end

    pcall(function()
        if State.Character then
            for _, part in ipairs(State.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end)
end

trackConnection(RunService.Stepped:Connect(function()
    if State.LockedPosition and State.Character and not CleaningUp then
        for _, part in ipairs(State.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end))

local function teleportTo(pos)
    lockToPosition(pos)
    task.wait(0.35 + math.random() * 0.1)
    unlockPosition()
end

local function rescueIfFalling()
    if State.RootPart and State.RootPart.Parent and State.RootPart.Position.Y < -400 then
        updateStatus("🕳 Спасение из ямы...")
        lockToPosition(PatrolPoints[1])
        task.wait(0.4)
        unlockPosition()
    end
end

-- =========================================================================
-- 10. SERVER HOP
-- =========================================================================
local function doServerHop(reason)
    if not Config.ServerHopEnabled then
        updateStatus("⚠ Hop выключен: " .. reason)
        return
    end

    updateStatus("🚀 Смена сервера: " .. reason)
    task.wait(0.5)

    local servers = {}
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local raw = game:HttpGet(url)
        local data = HttpService:JSONDecode(raw)
        if data and data.data then
            for _, sv in ipairs(data.data) do
                if sv.playing and sv.maxPlayers and sv.playing < (sv.maxPlayers - 1) and sv.id ~= game.JobId then
                    table.insert(servers, sv.id)
                end
            end
        end
    end)

    if #servers > 0 then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        end)
    else
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

-- =========================================================================
-- 11. ИНВЕНТАРЬ И БАЛАНС
-- =========================================================================
local function getInventoryTools()
    local list = {}
    local containers = {LocalPlayer:FindFirstChild("Backpack"), State.Character}
    for _, cont in ipairs(containers) do
        if cont then
            for _, item in ipairs(cont:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(list, item)
                end
            end
        end
    end
    return list
end

local function countItem(name)
    local n = 0
    for _, tl in ipairs(getInventoryTools()) do
        if tl.Name == name then
            n = n + 1
        end
    end
    return n
end

local function isItemFull(name)
    local limit = ItemLimits[name]
    if not limit then return false end
    return countItem(name) >= limit
end

local function countSellable()
    local n = 0
    for _, tl in ipairs(getInventoryTools()) do
        if SellableItems[tl.Name] then
            n = n + 1
        end
    end
    return n
end

local function countLuckyArrows()
    return countItem("Lucky Arrow")
end

local function countKeepItems()
    local n = 0
    for _, tl in ipairs(getInventoryTools()) do
        if KeepItems[tl.Name] then
            n = n + 1
        end
    end
    return n
end

local function countCompletedStacks()
    local completed = 0
    local total = 0
    for name, maxLimit in pairs(BaseMaxAmounts) do
        total = total + 1
        if countItem(name) >= maxLimit then
            completed = completed + 1
        end
    end
    return completed, total
end

local function getPlayerMoney()
    -- 1. Чтение из объектов данных игрока (IntValue / NumberValue / Attributes)
    local function checkObj(obj)
        if not obj then return nil end
        for _, name in ipairs({"Money", "Cash", "Yen", "Currency", "Wallet", "Balance"}) do
            local v = obj:FindFirstChild(name)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) and v.Value and v.Value > 0 then
                return v.Value
            end
        end
        return nil
    end

    local val = checkObj(LocalPlayer)
        or checkObj(LocalPlayer:FindFirstChild("leaderstats"))
        or checkObj(LocalPlayer:FindFirstChild("PlayerStats"))
        or checkObj(LocalPlayer:FindFirstChild("PlayerData"))
        or checkObj(LocalPlayer:FindFirstChild("Data"))
    if val and val > 0 then
        State.LastKnownMoney = val
        return val
    end

    local attr = LocalPlayer:GetAttribute("Money")
        or LocalPlayer:GetAttribute("Cash")
        or LocalPlayer:GetAttribute("Yen")
    if type(attr) == "number" and attr > 0 then
        State.LastKnownMoney = attr
        return attr
    end

    -- 2. Чтение из PlayerGui (YBA HUD)
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return State.LastKnownMoney or 0 end

    -- Поиск по специфичным названиям рамок/лейблов YBA (HUD -> Money / DropMoney / Cash)
    for _, d in ipairs(pgui:GetDescendants()) do
        if d:IsA("TextLabel") and not d:IsDescendantOf(ScreenGui) then
            local pName = d.Parent and d.Parent.Name:lower() or ""
            local dName = d.Name:lower()
            if dName:find("money") or dName:find("cash") or dName:find("dropmoney") or dName:find("currency")
               or pName:find("money") or pName:find("cash") or pName:find("dropmoney") or pName:find("currency") then
                local txt = d.Text or ""
                -- Игнорируем всплывающий индикатор продажи вроде "+1200"
                if not txt:find("^%s*[%+]") then
                    local digits = txt:match("[%d,]+")
                    if digits then
                        local num = tonumber(digits:gsub(",", ""))
                        if num and num >= 0 and num <= 2000000 then
                            State.LastKnownMoney = num
                            return num
                        end
                    end
                end
            end
        end
    end

    -- Поиск текста со знаком $ (например: "$75022" или "$ 75,022")
    for _, d in ipairs(pgui:GetDescendants()) do
        if d:IsA("TextLabel") and not d:IsDescendantOf(ScreenGui) and d.Visible then
            local txt = d.Text or ""
            if txt:find("$", 1, true) and not txt:find("^%s*[%+]") then
                local digits = txt:match("[%d,]+")
                if digits then
                    local num = tonumber(digits:gsub(",", ""))
                    if num and num >= 0 and num <= 2000000 then
                        State.LastKnownMoney = num
                        return num
                    end
                end
            end
        end
    end

    -- 3. Умный поиск числа на экране HUD (в YBA баланс отображается рядом с иконкой $)
    local best = 0
    for _, d in ipairs(pgui:GetDescendants()) do
        if d:IsA("TextLabel") and not d:IsDescendantOf(ScreenGui) and d.Visible then
            local txt = d.Text or ""
            -- Исключаем таймеры (29:21:19), версии (v1.8), пинг, индикаторы прибавки (+1200)
            if not txt:find(":") and not txt:find("v%d") and not txt:find("%%") and not txt:find("^%s*[%+]") and not txt:find("Region") and not txt:find("Age") then
                local clean = txt:match("^%s*([%d,]+)%s*$")
                if clean then
                    local num = tonumber(clean:gsub(",", ""))
                    -- Исключаем уровень игрока (1..50)
                    if num and num > 50 and num <= 1000000 and num > best then
                        best = num
                    end
                end
            end
        end
    end

    if best > 0 then
        State.LastKnownMoney = best
        return best
    end

    return State.LastKnownMoney or 0
end

-- =========================================================================
-- 12. ДИАЛОГИ И ПРОДАЖА ТОРГОВЦУ
-- =========================================================================
local function normalizeText(text)
    text = tostring(text or ""):lower()
    text = text:gsub("[%c%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or ""
end

local function getButtonText(btn)
    if not btn then return "" end
    if btn:IsA("TextButton") and btn.Text ~= "" then
        return btn.Text
    end
    for _, child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text ~= "" then
            return child.Text
        end
    end
    return ""
end

local function isActuallyVisible(obj)
    if not obj or not obj.Parent then return false end
    if obj:IsA("GuiObject") and obj.Visible == false then return false end
    local parent = obj.Parent
    while parent and parent ~= LocalPlayer:FindFirstChild("PlayerGui") do
        if parent:IsA("GuiObject") and parent.Visible == false then return false end
        parent = parent.Parent
    end
    return true
end

local function getDialogueGui()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return nil end
    local direct = pgui:FindFirstChild("DialogueGui")
    if direct then return direct end
    for _, obj in ipairs(pgui:GetChildren()) do
        if tostring(obj.Name):lower():find("dialog", 1, true) then
            return obj
        end
    end
    return nil
end

local NegativeKeywords = {"buy", "leave", "cancel", "nevermind", "never mind", "no thanks", "no thank", "goodbye", "exit", "nothing"}
local function scoreDialogueOption(text)
    local n = normalizeText(text)
    if n == "" then return -math.huge end
    for _, w in ipairs(NegativeKeywords) do
        if n:find(w, 1, true) then return -1000 end
    end
    local score = 0
    if n:find("sell", 1, true) then score = score + 100 end
    if n:find("all", 1, true) or n:find("everything", 1, true) or n:find("max", 1, true) then score = score + 150 end
    if n:find("deal", 1, true) then score = score + 90 end
    if n:find("confirm", 1, true) then score = score + 80 end
    if n == "yes" or n:find("yes ", 1, true) == 1 then score = score + 70 end
    if n == "ok" or n == "okay" or n:find("sure", 1, true) then score = score + 55 end
    return score
end

local function waitForDialogueButtons(timeout)
    timeout = timeout or 2.5
    local started = tick()
    while (tick() - started < timeout) and not CleaningUp do
        local dlg = getDialogueGui()
        if dlg then
            local buttons = {}
            for _, obj in ipairs(dlg:GetDescendants()) do
                if obj:IsA("GuiButton") and isActuallyVisible(obj) then
                    local text = getButtonText(obj)
                    if normalizeText(text) ~= "" then
                        table.insert(buttons, {Button = obj, Text = text})
                    end
                end
            end
            if #buttons > 0 then return buttons end
        end
        task.wait(0.12 + math.random() * 0.08)
    end
    return {}
end

local function chooseBestSellButton(buttons)
    local best, bestScore = nil, -math.huge
    for _, e in ipairs(buttons) do
        local score = scoreDialogueOption(e.Text)
        if score > bestScore then
            bestScore = score
            best = e
        end
    end
    if bestScore <= 0 then return nil end
    return best
end

local function findMerchantPrompt()
    local dlgFolder = ReplicatedStorage:FindFirstChild("Dialogue")
    if dlgFolder then
        local merchant = dlgFolder:FindFirstChild("Merchant", true)
        if merchant then
            local prompt = merchant:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then return prompt, merchant end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local depth = 0
            while parent and parent ~= workspace and depth < 6 do
                if tostring(parent.Name):lower():find("merchant", 1, true) then
                    return obj, nil
                end
                parent = parent.Parent
                depth = depth + 1
            end
        end
    end
    return nil, nil
end

local function closeDialogueIfOpen()
    local dlg = getDialogueGui()
    if not dlg then return end
    for _, obj in ipairs(dlg:GetDescendants()) do
        if obj:IsA("GuiButton") and isActuallyVisible(obj) then
            local t = normalizeText(getButtonText(obj))
            if t:find("leave", 1, true) or t:find("cancel", 1, true) or t:find("goodbye", 1, true) or t:find("exit", 1, true) then
                SafeClickButton(obj)
                task.wait(0.18 + math.random() * 0.08)
                return
            end
        end
    end
end

local function equipTool(itemName)
    local char = State.Character
    local hum = State.Humanoid
    if not hum or not char then return nil end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local tool = (backpack and backpack:FindFirstChild(itemName)) or char:FindFirstChild(itemName)
    if not tool then return nil end

    if tool.Parent == backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.12 + math.random() * 0.06)
    end

    local deadline = tick() + 0.35
    while tool.Parent ~= char and tick() < deadline do
        task.wait(0.05)
    end
    return tool.Parent == char and tool or nil
end

local function runMerchantSellDialogue(itemName, beforeCount)
    for step = 1, 7 do
        if countItem(itemName) < beforeCount then return true end
        local buttons = waitForDialogueButtons(step == 1 and 2.5 or 1.5)
        if #buttons == 0 then return false end
        local chosen = chooseBestSellButton(buttons)
        if not chosen then return false end
        SafeClickButton(chosen.Button)
        task.wait(0.35 + math.random() * 0.1)
    end
    return countItem(itemName) < beforeCount
end

local function openMerchant(prompt, merchant)
    lockToPosition(MerchantPosition)
    task.wait(0.3)
    if State.RemoteEvent then
        pcall(function()
            State.RemoteEvent:FireServer("HoldAttack", {Bool = false, Type = "m1"})
        end)
    end
    task.wait(0.1)
    if prompt then SafePrompt(prompt) end
    if merchant and State.RemoteEvent then
        pcall(function() State.RemoteEvent:FireServer("PromptTriggered", merchant) end)
    end
    task.wait(0.3)
end

local function sellAllNow()
    local prompt, merchant = findMerchantPrompt()
    local dlg = ReplicatedStorage:FindFirstChild("Dialogue")
    if not merchant and dlg then
        merchant = dlg:FindFirstChild("Merchant") or dlg
    end
    openMerchant(prompt, merchant)

    local toSell = {}
    for _, tl in ipairs(getInventoryTools()) do
        if SellableItems[tl.Name] and not toSell[tl.Name] then
            toSell[tl.Name] = true
        end
    end

    local soldAny = false
    for itemName in pairs(toSell) do
        if not State.Running or CleaningUp then break end
        local initialCount = countItem(itemName)
        if initialCount > 0 then
            equipTool(itemName)
            closeDialogueIfOpen()
            if prompt then SafePrompt(prompt) end
            task.wait(0.3)
            if runMerchantSellDialogue(itemName, initialCount) then
                soldAny = true
            end
            closeDialogueIfOpen()
        end
        task.wait(0.12 + math.random() * 0.08)
    end

    closeDialogueIfOpen()
    unlockPosition()
    return soldAny
end

local function trySell()
    if sellAllNow() then
        State.SellFails = 0
        updateStatus("💰 Продано успешно", "Баланс: $" .. getPlayerMoney())
    else
        State.SellFails = State.SellFails + 1
        if State.SellFails >= 2 then
            State.SellFails = 0
            doServerHop("Торговец недоступен")
        end
    end
end

-- =========================================================================
-- 13. ПОКУПКА ПРЕДМЕТОВ (Lucky Arrow)
-- =========================================================================
local function buyLuckyArrow()
    local currentMoney = getPlayerMoney()
    if currentMoney < Config.ArrowPrice and (State.LastKnownMoney or 0) < Config.ArrowPrice then 
        return false 
    end

    local before = countLuckyArrows()
    updateStatus("🛒 Покупка Lucky Arrow", "Баланс: $" .. currentMoney .. " | Стрел: " .. before .. "/" .. Config.TargetArrows)

    -- Способ 1: Прямой RemoteEvent персонажа (каноничный YBA вызов)
    if State.RemoteEvent then
        pcall(function()
            State.RemoteEvent:FireServer("PurchaseShopItem", {ItemName = "1x Lucky Arrow"}, 1, 2)
        end)
        pcall(function()
            State.RemoteEvent:FireServer("PurchaseShopItem", {ItemName = "Lucky Arrow"}, 1, 2)
        end)
        pcall(function()
            State.RemoteEvent:FireServer("PurchaseShopItem", "1x Lucky Arrow", 1)
        end)
        pcall(function()
            State.RemoteEvent:FireServer("PurchaseShopItem", "Lucky Arrow", 1)
        end)
        pcall(function()
            State.RemoteEvent:FireServer("BuyShopItem", "Lucky Arrow")
        end)
        pcall(function()
            State.RemoteEvent:FireServer("BuyItem", "Lucky Arrow")
        end)
    end

    -- Способ 2: RemoteFunction персонажа (если магазин использует InvokeServer)
    if State.RemoteFunction then
        pcall(function()
            State.RemoteFunction:InvokeServer("PurchaseShopItem", {ItemName = "1x Lucky Arrow"}, 1, 2)
        end)
        pcall(function()
            State.RemoteFunction:InvokeServer("PurchaseShopItem", {ItemName = "Lucky Arrow"}, 1, 2)
        end)
        pcall(function()
            State.RemoteFunction:InvokeServer("ItemShop", "Lucky Arrow")
        end)
        pcall(function()
            State.RemoteFunction:InvokeServer("BuyItem", "Lucky Arrow")
        end)
    end

    -- Способ 3: Авто-клик по интерфейсу магазина в PlayerGui (если открыт или есть кнопки)
    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return end
        for _, btn in ipairs(pgui:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and not btn:IsDescendantOf(ScreenGui) then
                local bTxt = (btn:IsA("TextButton") and btn.Text:lower()) or ""
                local bName = btn.Name:lower()
                -- Поиск кнопки покупки лаки стрелы
                if (bTxt:find("lucky arrow") or bName:find("lucky")) and (bTxt:find("buy") or bTxt:find("75") or bName:find("buy")) then
                    SafeClickButton(btn)
                    break
                end
            end
        end
    end)

    task.wait(1.5)
    local after = countLuckyArrows()
    if after > before then
        State.BuyFails = 0
        updateStatus("✅ Куплена Lucky Arrow!", "Стрел: " .. after .. "/" .. Config.TargetArrows)
        Webhook_SendLuckyArrow("Куплена в магазине ($75,000)", after)
        return true
    else
        State.BuyFails = (State.BuyFails or 0) + 1
        return false
    end
end

-- =========================================================================
-- 14. МОЛНИЕНОСНЫЙ СКАНЕР ЛУТА И ПОДБОР
-- =========================================================================
local function getItemDisplayName(item)
    local prox = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prox and prox.ObjectText and prox.ObjectText ~= "" then
        return prox.ObjectText
    end
    return item.Name
end

local function isItemAvailable(item)
    if item:IsA("BasePart") then
        return item.Transparency < 0.95
    end
    for _, d in ipairs(item:GetChildren()) do
        if d:IsA("BasePart") and d.Transparency < 0.95 then
            return true
        end
    end
    return false
end

local function getItemPosition(item)
    local pos = nil
    pcall(function()
        if item:IsA("BasePart") then
            pos = item.Position
        elseif item.PrimaryPart then
            pos = item.PrimaryPart.Position
        else
            pos = item:GetPivot().Position
        end
    end)
    return pos
end

local function isItemBlacklisted(item)
    return State.Blacklist[item] and (tick() - State.Blacklist[item] < Config.BlacklistTTL)
end

-- ВАЖНО: Умный сканер с расчетом приоритета ценности предметов!
local function findNearestLoot()
    local folder = workspace:FindFirstChild("Item_Spawns")
    folder = folder and folder:FindFirstChild("Items")
    if not folder then return nil, nil, 0 end

    local bestItem, bestName, bestScore, totalCount = nil, nil, -math.huge, 0
    for _, item in ipairs(folder:GetChildren()) do
        local name = getItemDisplayName(item)
        if (SellableItems[name] or KeepItems[name])
            and isItemAvailable(item)
            and not isItemFull(name)
            and not isItemBlacklisted(item) then

            totalCount = totalCount + 1
            local pos = getItemPosition(item)
            if pos and State.RootPart then
                local dist = (pos - State.RootPart.Position).Magnitude
                local price = ItemPrices[name] or 100

                -- Расчет приоритета:
                local score
                if KeepItems[name] then
                    -- Lucky Arrow / Lucky Mask имеют наивысший абсолютный приоритет на карте!
                    score = 10000000 - dist
                else
                    -- Дорогие предметы (Pure Roka $1500, Rib Cage $1200) выгоднее монет ($120)
                    score = (price * 2.5) - dist
                end

                if score > bestScore then
                    bestScore = score
                    bestItem = item
                    bestName = name
                end
            end
        end
    end
    return bestItem, bestName, totalCount
end

-- Подбор с human-like рандомизацией
local function grabItem(item, name)
    local prox = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prox then return false end
    local pos = getItemPosition(item)
    if not pos then return false end

    local before = countItem(name)

    lockToPosition(pos)
    task.wait(0.15 + math.random() * 0.08)
    SafePrompt(prox)

    local timeout = Config.GrabTimeout + math.random() * 0.3
    local started = tick()
    local success = false

    while (tick() - started < timeout) and not CleaningUp do
        if countItem(name) > before then
            success = true
            break
        end
        if not item.Parent or not isItemAvailable(item) then
            break
        end
        task.wait(0.08 + math.random() * 0.07)
    end

    unlockPosition()

    if success and KeepItems[name] then
        State.RaresFound = State.RaresFound + 1
        if name == "Lucky Arrow" then
            Webhook_SendLuckyArrow("Найдена на карте!", countLuckyArrows())
        else
            Webhook_SendRareItem(name, countItem(name))
        end
    end

    return success
end

local function farmStep()
    local item, name, _ = findNearestLoot()
    if item then
        updateStatus("⚡ Взять: " .. name, "Баланс: $" .. getPlayerMoney())
        if grabItem(item, name) then
            State.TotalPicked = State.TotalPicked + 1
            State.LastLootTime = tick()
            local prefix = KeepItems[name] and "🍀 СОХРАНЕНО: " or "📦 Взято: "
            updateStatus(prefix .. name)
            task.wait(0.15 + math.random() * 0.1)
        else
            State.Blacklist[item] = tick()
            updateStatus("⚠ Пропуск занятого лута")
        end
    else
        if tick() - State.LastLootTime > Config.DroughtSeconds then
            doServerHop("Засуха лута")
            task.wait(2.5)
            pcall(refreshCharacter)
            State.LastLootTime = tick()
        else
            teleportTo(PatrolPoints[math.random(1, #PatrolPoints)])
            task.wait(0.4 + math.random() * 0.15)
        end
    end
end

-- =========================================================================
-- 15. УМНЫЙ ЦИКЛ ФАРМА (Smart Money-First Flow)
-- =========================================================================
local mainThread = task.spawn(function()
    updateStatus("🚀 BLISS FARM v4.1", "Умный поток запущен")
    task.wait(1)

    local lastFullCount = -1
    local lastProgressTime = tick()

    while not CleaningUp do
        waitIfPaused()
        rescueIfFalling()

        if State.Character and State.Character.Parent and State.Humanoid and State.Humanoid.Health > 0 then
            local money = getPlayerMoney()
            local arrows = countLuckyArrows()
            local keepCount = countKeepItems()
            local sellCount = countSellable()
            local completedStacks, totalStacks = countCompletedStacks()

            if not State.StartMoney then
                State.StartMoney = money
            end
            local sessionProfit = math.max(0, money - State.StartMoney)
            local uptimeMinutes = math.floor((tick() - State.StartTime) / 60)

            local isArrowsGoalReached = (arrows >= Config.TargetArrows)
            local isMoneyGoalReached = (money >= Config.TargetMoney)
            local isAllStacksFull = (completedStacks >= totalStacks)

            -- ═════════════════════════════════════════════════════════════
            -- ОПРЕДЕЛЕНИЕ ТЕКУЩЕЙ ФАЗЫ (1 -> 2 -> 3 -> ФИНИШ)
            -- ═════════════════════════════════════════════════════════════
            if isArrowsGoalReached and isMoneyGoalReached and isAllStacksFull then
                -- 🏆 ФИНИШ: GOD ACCOUNT ГОТОВ!
                updateStatus(
                    "🏆 GOD ACCOUNT ПОЛНОСТЬЮ ГОТОВ!",
                    string.format("🏹 10/10 Lucky | 💰 $1,000,000 | 📦 %d/%d FULL", completedStacks, totalStacks),
                    "Абсолютный максимум достигнут!"
                )
                Webhook_SendMilestone(
                    "🏆 GOD ACCOUNT ПОЛНОСТЬЮ ГОТОВ!",
                    string.format("Абсолютный максимум достигнут для `%s`:\n🏹 10/10 Lucky Arrow\n💰 $1,000,000 Баланс\n📦 %d/%d Полных стаков предметов!\nСкрипт успешно завершил работу.", LocalPlayer.Name, completedStacks, totalStacks),
                    10181046,
                    true
                )
                break

            elseif not isArrowsGoalReached then
                -- 🔹 ФАЗА 1: Охота и покупка 10 Lucky Arrow
                StatusLine1.Text = string.format("🏹 [Фаза 1/3] Lucky Arrows: %d/%d", arrows, Config.TargetArrows)
                StatusLine2.Text = string.format("💰 Баланс: $%d / $75,000 на стрелу | 🎒 Продаваемых: %d", money, sellCount)

                -- Если накопили $75,000 — моментально покупаем лаки-стрелу в шопе
                if money >= Config.ArrowPrice then
                    buyLuckyArrow()
                    task.wait(0.4)
                -- Если набрали 8+ продаваемых предметов — сдаем торговцу
                elseif sellCount >= Config.SellThreshold then
                    updateStatus("🛒 Продажа (" .. sellCount .. " шт.) для Lucky Arrow")
                    trySell()
                else
                    farmStep()
                end

            elseif not isMoneyGoalReached then
                -- 🔹 ФАЗА 2: Накопление $1,000,000 (стрелы уже есть!)
                if State.LastPhase < 2 then
                    State.LastPhase = 2
                    Webhook_SendMilestone(
                        "🏹 ФАЗА 1 ЗАВЕРШЕНА: 10/10 LUCKY ARROW!",
                        "Все 10 Lucky Arrow собраны и лежат в рюкзаке!\nПереходим к Фазе 2: Накопление $1,000,000.",
                        16766720,
                        false
                    )
                end

                StatusLine1.Text = string.format("💰 [Фаза 2/3] Копим $1,000,000 ($%d)", money)
                StatusLine2.Text = string.format("🏹 10/10 Lucky на базе! | 🎒 Продаваемых: %d/%d", sellCount, Config.SellThreshold)

                -- Продаем оптом каждые 8 предметов
                if sellCount >= Config.SellThreshold then
                    updateStatus("🛒 Продажа (" .. sellCount .. " шт.) в копилку $1M")
                    trySell()
                else
                    farmStep()
                end

            else
                -- 🔹 ФАЗА 3: Full Collector Mode (Добиваем ВСЕ стаки до упора!)
                -- ТОРГОВЕЦ ОТКЛЮЧЕН — ни один предмет не продается!
                if State.LastPhase < 3 then
                    State.LastPhase = 3
                    Webhook_SendMilestone(
                        "💰 ФАЗА 2 ЗАВЕРШЕНА: $1,000,000 НА СЧЕТУ!",
                        "Целевой баланс $1,000,000 успешно накоплен!\nТорговец ОТКЛЮЧЕН. Переходим к Фазе 3: Сбор всех 16 стаков до упора.",
                        65280,
                        false
                    )
                end

                StatusLine1.Text = string.format("📦 [Фаза 3/3] Фулл-стаки: %d/%d заполнено", completedStacks, totalStacks)
                StatusLine2.Text = string.format("🏹 10 Lucky | 💰 $1M кап | Торговец ОТКЛЮЧЕН")

                farmStep()
            end

            StatusLine3.Text = string.format("⏱ %dm | 💵 +$%d сессия | 🍀 Найдено рарок: %d",
                uptimeMinutes, sessionProfit, State.RaresFound)
        else
            task.wait(0.8)
            pcall(refreshCharacter)
        end
        task.wait(0.15 + math.random() * 0.05)
    end
end)
table.insert(RunningThreads, mainThread)

local hopThread = task.spawn(function()
    while not CleaningUp do
        task.wait(Config.HopMinMinutes * 60)
        if Config.ServerHopEnabled and State.Running and not CleaningUp then
            doServerHop("Таймер периодической смены")
        end
    end
end)
table.insert(RunningThreads, hopThread)

-- Поток периодических отчётов в Discord
local webhookReportThread = task.spawn(function()
    task.wait(10)
    if Config.WebhookEnabled and Config.WebhookUrl ~= "" then
        pcall(Webhook_SendStartup)
    end

    while not CleaningUp do
        task.wait(60)
        if Config.WebhookEnabled and Config.WebhookUrl ~= "" and not CleaningUp then
            if tick() - State.LastWebhookReport >= (Config.WebhookReportInterval * 60) then
                State.LastWebhookReport = tick()
                local money = getPlayerMoney()
                local arrows = countLuckyArrows()
                local completedStacks, totalStacks = countCompletedStacks()
                local uptimeMinutes = math.floor((tick() - State.StartTime) / 60)
                local sessionProfit = math.max(0, money - (State.StartMoney or money))
                pcall(function()
                    Webhook_SendReport(uptimeMinutes, sessionProfit, money, arrows, completedStacks, totalStacks)
                end)
            end
        end
    end
end)
table.insert(RunningThreads, webhookReportThread)

-- =========================================================================
-- 16. ФУНКЦИЯ ДЛЯ ГЛОБАЛЬНОЙ ВЫГРУЗКИ (Clean Unload Handler)
-- =========================================================================
_G.BlissFarm_Cleanup = function()
    CleaningUp = true
    State.Running = false

    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    unlockPosition()

    pcall(function()
        if ScreenGui and ScreenGui.Parent then
            ScreenGui:Destroy()
        end
    end)

    _G.BlissFarm_Cleanup = nil
end
