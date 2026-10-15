-- ═════════════════════════════════════════════════════════════════════════
-- ⚡ BLISS FARM • OFFICIAL VIP LOADER & KEY SYSTEM
-- Разработчик: BlissOw (neoworkd)
-- Официальные продажи: Starvell & FunPay
-- ═════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Настройки монетизации и валидации
local LoaderConfig = {
    -- Ссылка на твой профиль или объявление на Starvell:
    ShopUrl = "https://starvell.com",
    
    -- Имя файла для сохранения ключа на устройстве игрока:
    KeyFileName = "BlissFarm_Key.txt",
    
    -- Ссылка на удалённую базу ключей покупателей (Secret Gist или raw JSON)
    RemoteKeysUrl = "https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/assets/whitelist.json",
    
    -- Локальные мастер-ключи (всегда активны 24/7 без интернета):
    MasterKeys = {
        ["BLISS-NEO-BOSS"] = { owner = "neoworkd", tier = "OWNER" },
        ["BLISS-BRO-VIP"]  = { owner = "Brother",  tier = "VIP" },
        ["BLISS-STARVELL-VIP"] = { owner = "Starvell Customer", tier = "VIP" },
    }
}

-- Проверка родительского контейнера для GUI
local targetGuiParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if CoreGui and pcall(function() return CoreGui:GetChildren() end) then
        targetGuiParent = CoreGui
    end
end)

-- Удаление старого лоадера, если был открыт
for _, g in ipairs(targetGuiParent:GetChildren()) do
    if g.Name == "BlissFarmLoaderUI" then
        g:Destroy()
    end
end

-- Функция запуска основного ядра чита
local function launchMainScript()
    task.spawn(function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/BlissOw/YBA_FARM/main/main.lua?t=" .. tostring(tick())))()
        end)
    end)
end

-- Функция проверки валидности ключа
local function validateKey(key)
    if not key or key == "" then return false, "Ключ не может быть пустым" end
    key = key:gsub("%s+", ""):upper()

    -- 1. Проверка по локальным мастер-ключам (ты и брат)
    if LoaderConfig.MasterKeys[key] then
        return true, LoaderConfig.MasterKeys[key].tier
    end

    -- 2. Проверка по удалённой базе покупателей со Starvell
    local valid = false
    local tier = "VIP"
    pcall(function()
        if LoaderConfig.RemoteKeysUrl and LoaderConfig.RemoteKeysUrl ~= "" then
            local raw = game:HttpGet(LoaderConfig.RemoteKeysUrl .. "?t=" .. tostring(tick()))
            local data = HttpService:JSONDecode(raw)
            if data and data.keys and data.keys[key] then
                valid = true
                tier = data.keys[key].tier or "VIP"
            end
        end
    end)

    if valid then
        return true, tier
    end

    return false, "Неверный ключ активации"
end

-- ═════════════════════════════════════════════════════════════════════════
-- ТИХИЙ АВТО-ВХОД (Если ключ уже сохранён на устройстве)
-- ═════════════════════════════════════════════════════════════
local savedKey = nil
pcall(function()
    if type(readfile) == "function" and type(isfile) == "function" and isfile(LoaderConfig.KeyFileName) then
        savedKey = readfile(LoaderConfig.KeyFileName)
    end
end)

if savedKey and savedKey ~= "" then
    local isValid, tier = validateKey(savedKey)
    if isValid then
        -- Ключ верный! Запускаем чит сразу без лишних окон
        launchMainScript()
        return
    end
end

-- ═════════════════════════════════════════════════════════════════════════
-- НЕОНОВЫЙ UI СИСТЕМЫ КЛЮЧЕЙ С ДЕМОНОМ-МАСКОТОМ
-- ═════════════════════════════════════════════════════════════
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
ScreenGui.Name = "BlissFarmLoaderUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "LoaderMainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 230)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -115)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Color = Color3.fromRGB(168, 85, 247) -- Неоновый фиолетовый
MainStroke.Parent = MainFrame

-- Шапка лоадера
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(24, 18, 38)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = Header

if LogoAssetId then
    local MascotIcon = Instance.new("ImageLabel")
    MascotIcon.Size = UDim2.new(0, 28, 0, 28)
    MascotIcon.Position = UDim2.new(0, 12, 0, 7)
    MascotIcon.BackgroundTransparency = 1
    MascotIcon.Image = LogoAssetId
    MascotIcon.ScaleType = Enum.ScaleType.Fit
    MascotIcon.Parent = Header
end

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = LogoAssetId and UDim2.new(1, -75, 1, 0) or UDim2.new(1, -40, 1, 0)
TitleLabel.Position = LogoAssetId and UDim2.new(0, 46, 0, 0) or UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextColor3 = Color3.fromRGB(216, 180, 254)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ BLISS FARM • Активация VIP"
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 22)
CloseBtn.Position = UDim2.new(1, -34, 0, 10)
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

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Подзаголовок
local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -30, 0, 20)
Subtitle.Position = UDim2.new(0, 15, 0, 50)
Subtitle.BackgroundTransparency = 1
Subtitle.TextColor3 = Color3.fromRGB(180, 160, 210)
Subtitle.TextSize = 11
Subtitle.Font = Enum.Font.Gotham
Subtitle.Text = "Введите персональный VIP-ключ для запуска чита:"
Subtitle.Parent = MainFrame

-- Поле ввода ключа
local KeyInputBox = Instance.new("TextBox")
KeyInputBox.Name = "KeyInputBox"
KeyInputBox.Size = UDim2.new(1, -30, 0, 36)
KeyInputBox.Position = UDim2.new(0, 15, 0, 74)
KeyInputBox.BackgroundColor3 = Color3.fromRGB(24, 16, 38)
KeyInputBox.TextColor3 = Color3.fromRGB(240, 230, 255)
KeyInputBox.PlaceholderText = "🔑 BLISS-VIP-XXXX-XXXX"
KeyInputBox.PlaceholderColor3 = Color3.fromRGB(120, 100, 150)
KeyInputBox.Text = ""
KeyInputBox.TextSize = 12
KeyInputBox.Font = Enum.Font.Code
KeyInputBox.ClearTextOnFocus = false
KeyInputBox.BorderSizePixel = 0
KeyInputBox.Parent = MainFrame

local KibCorner = Instance.new("UICorner")
KibCorner.CornerRadius = UDim.new(0, 8)
KibCorner.Parent = KeyInputBox

local KibStroke = Instance.new("UIStroke")
KibStroke.Thickness = 1.2
KibStroke.Color = Color3.fromRGB(147, 51, 234)
KibStroke.Parent = KeyInputBox

-- Статусная строка
local StatusMsg = Instance.new("TextLabel")
StatusMsg.Size = UDim2.new(1, -30, 0, 18)
StatusMsg.Position = UDim2.new(0, 15, 0, 114)
StatusMsg.BackgroundTransparency = 1
StatusMsg.TextColor3 = Color3.fromRGB(168, 85, 247)
StatusMsg.TextSize = 10
StatusMsg.Font = Enum.Font.GothamSemibold
StatusMsg.Text = "Лицензия проверяется по защищённой базе"
StatusMsg.Parent = MainFrame

-- Кнопки действий
local PasteBtn = Instance.new("TextButton")
PasteBtn.Size = UDim2.new(0.48, -4, 0, 32)
PasteBtn.Position = UDim2.new(0, 15, 0, 138)
PasteBtn.BackgroundColor3 = Color3.fromRGB(32, 22, 50)
PasteBtn.TextColor3 = Color3.fromRGB(216, 180, 254)
PasteBtn.Text = "📋 Вставить"
PasteBtn.TextSize = 11
PasteBtn.Font = Enum.Font.GothamBold
PasteBtn.BorderSizePixel = 0
PasteBtn.Parent = MainFrame

local PbCorner = Instance.new("UICorner")
PbCorner.CornerRadius = UDim.new(0, 8)
PbCorner.Parent = PasteBtn

local BuyBtn = Instance.new("TextButton")
BuyBtn.Size = UDim2.new(0.48, -4, 0, 32)
BuyBtn.Position = UDim2.new(0.52, 2, 0, 138)
BuyBtn.BackgroundColor3 = Color3.fromRGB(32, 22, 50)
BuyBtn.TextColor3 = Color3.fromRGB(240, 200, 120)
BuyBtn.Text = "🛒 Купить (Starvell)"
BuyBtn.TextSize = 11
BuyBtn.Font = Enum.Font.GothamBold
BuyBtn.BorderSizePixel = 0
BuyBtn.Parent = MainFrame

local BbCorner = Instance.new("UICorner")
BbCorner.CornerRadius = UDim.new(0, 8)
BbCorner.Parent = BuyBtn

local SubmitBtn = Instance.new("TextButton")
SubmitBtn.Size = UDim2.new(1, -30, 0, 34)
SubmitBtn.Position = UDim2.new(0, 15, 0, 178)
SubmitBtn.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
SubmitBtn.TextColor3 = Color3.new(1, 1, 1)
SubmitBtn.Text = "⚡ Активировать и Войти"
SubmitBtn.TextSize = 12
SubmitBtn.Font = Enum.Font.GothamBold
SubmitBtn.BorderSizePixel = 0
SubmitBtn.Parent = MainFrame

local SbCorner = Instance.new("UICorner")
SbCorner.CornerRadius = UDim.new(0, 8)
SbCorner.Parent = SubmitBtn

-- Логика кнопок
PasteBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if type(getclipboard) == "function" then
            KeyInputBox.Text = getclipboard():gsub("%s+", "")
            StatusMsg.Text = "📋 Ключ вставлен из буфера!"
            StatusMsg.TextColor3 = Color3.fromRGB(168, 85, 247)
        end
    end)
end)

BuyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(LoaderConfig.ShopUrl)
            StatusMsg.Text = "✅ Ссылка на Starvell скопирована в буфер!"
            StatusMsg.TextColor3 = Color3.fromRGB(240, 200, 120)
        end
    end)
end)

SubmitBtn.MouseButton1Click:Connect(function()
    local entered = KeyInputBox.Text:gsub("%s+", "")
    if entered == "" then
        StatusMsg.Text = "❌ Пожалуйста, вставьте ключ!"
        StatusMsg.TextColor3 = Color3.fromRGB(239, 68, 68)
        return
    end

    StatusMsg.Text = "⏳ Проверка ключа в базе..."
    StatusMsg.TextColor3 = Color3.fromRGB(240, 230, 255)

    local isValid, tierOrErr = validateKey(entered)
    if isValid then
        StatusMsg.Text = "✅ Доступ разрешён [" .. tostring(tierOrErr) .. "]! Запуск..."
        StatusMsg.TextColor3 = Color3.fromRGB(34, 197, 94)

        -- Сохраняем проверенный ключ в файл на устройстве
        pcall(function()
            if type(writefile) == "function" then
                writefile(LoaderConfig.KeyFileName, entered)
            end
        end)

        task.wait(0.8)
        ScreenGui:Destroy()
        launchMainScript()
    else
        StatusMsg.Text = "❌ " .. tostring(tierOrErr)
        StatusMsg.TextColor3 = Color3.fromRGB(239, 68, 68)
    end
end)

-- Перетаскивание окна
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
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
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

MainFrame.Parent = ScreenGui
ScreenGui.Parent = targetGuiParent
