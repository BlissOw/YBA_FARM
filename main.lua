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
    Version = "v4.2 Value-Pro",
    TargetMoney = 1000000,          -- Целевой баланс: $1,000,000
    TargetArrows = 10,              -- Целевое кол-во Lucky Arrow: 10
    ArrowPrice = 75000,             -- Цена Lucky Arrow: $75,000
    BuyArrowsAfterMoney = true,     -- ВАЖНО: Покупать Lucky Arrow ТОЛЬКО ПОСЛЕ накопления $1M!
    HopMinMinutes = 6,
    DroughtSeconds = 45,            -- Время без лута до смены сервера
    ServerHopEnabled = true,
    BlacklistTTL = 60,              -- Время черного списка застрявших айтемов (сек)
    TeleportOffset = 3.5,           -- 3.5 studs под предметом (в зоне ProximityPrompt)
    SellThreshold = 8,              -- Продавать при 8+ предметах
    MinSellBatch = 2,               -- Не бегать к торговцу ради 1 предмета
    MaxInventorySlots = 10,         -- Вместимость инвентаря без 2x Gamepass
    GrabTimeout = 1.2,              -- Максимальное ожидание подбора (сек)
}

-- Официальная таблица лимитов стаков (BaseMaxAmounts)
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
    ["Left Arm of The Saint's Corpse"] = 10,
    ["Heart of The Saint's Corpse"]    = 10,
    ["Pelvis of The Saint's Corpse"]   = 10,
    ["Requiem Arrow"]                  = 10,
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
    ["Left Arm of The Saint's Corpse"] = 500000,
    ["Heart of The Saint's Corpse"]    = 500000,
    ["Pelvis of The Saint's Corpse"]   = 500000,
    ["Requiem Arrow"]                  = 500000,
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
    ["Left Arm of The Saint's Corpse"] = true,
    ["Heart of The Saint's Corpse"] = true,
    ["Pelvis of The Saint's Corpse"] = true,
    ["Requiem Arrow"] = true,
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
    Blacklist = {},
    LastLootTime = tick(),
    TotalPicked = 0,
    SellFails = 0,
    LockedPosition = nil,
    LockConnection = nil,
    StartTime = tick(),
    StartMoney = nil,
    RaresFound = 0,
}

-- =========================================================================
-- 5. МОЛНИЕНОСНЫЙ И БЕЗОПАСНЫЙ СЛОЙ ЭКСПЛОИТА (Fast Proximity & Input)
-- =========================================================================
local SafePrompt = function(prompt)
    if not prompt or not prompt.Parent then return false end

    -- Быстрый триггер через fireproximityprompt
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt, 0)
        pcall(fireproximityprompt, prompt)
        return true
    end

    -- Fallback мгновенный сброс удержания
    pcall(function()
        local prev = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(0.02)
        prompt:InputHoldEnd()
        prompt.HoldDuration = prev
    end)
    return true
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
            task.wait(0.04)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            clicked = true
        end)
    end

    return clicked
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
-- 8. ИНТЕРФЕЙС (GUI) С ПОДДЕРЖКОЙ DRAG & DROP
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BlissFarmUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 95)
MainFrame.Position = UDim2.new(0, 15, 0, 85)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.2
MainStroke.Color = Color3.fromRGB(50, 56, 82)
MainStroke.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -50, 0, 20)
TitleLabel.Position = UDim2.new(0, 12, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextColor3 = Color3.fromRGB(255, 204, 77)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "⚡ BLISS FARM • " .. Config.Version
TitleLabel.Parent = MainFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 30, 0, 22)
ToggleButton.Position = UDim2.new(1, -40, 0, 7)
ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
ToggleButton.Text = "■"
ToggleButton.TextColor3 = Color3.new(1, 1, 1)
ToggleButton.TextSize = 13
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.BorderSizePixel = 0
ToggleButton.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleButton

local StatusLine1 = Instance.new("TextLabel")
StatusLine1.Size = UDim2.new(1, -24, 0, 16)
StatusLine1.Position = UDim2.new(0, 12, 0, 30)
StatusLine1.BackgroundTransparency = 1
StatusLine1.TextXAlignment = Enum.TextXAlignment.Left
StatusLine1.TextColor3 = Color3.fromRGB(140, 255, 150)
StatusLine1.TextSize = 11
StatusLine1.Font = Enum.Font.GothamSemibold
StatusLine1.TextWrapped = true
StatusLine1.Text = "🚀 Быстрый сбор активирован"
StatusLine1.Parent = MainFrame

local StatusLine2 = Instance.new("TextLabel")
StatusLine2.Size = UDim2.new(1, -24, 0, 16)
StatusLine2.Position = UDim2.new(0, 12, 0, 50)
StatusLine2.BackgroundTransparency = 1
StatusLine2.TextXAlignment = Enum.TextXAlignment.Left
StatusLine2.TextColor3 = Color3.fromRGB(175, 180, 200)
StatusLine2.TextSize = 11
StatusLine2.Font = Enum.Font.Gotham
StatusLine2.TextWrapped = true
StatusLine2.Text = "🎒 0/10 | 🏹 0/10 | 💰 $0"
StatusLine2.Parent = MainFrame

local StatusLine3 = Instance.new("TextLabel")
StatusLine3.Size = UDim2.new(1, -24, 0, 16)
StatusLine3.Position = UDim2.new(0, 12, 0, 70)
StatusLine3.BackgroundTransparency = 1
StatusLine3.TextXAlignment = Enum.TextXAlignment.Left
StatusLine3.TextColor3 = Color3.fromRGB(210, 215, 235)
StatusLine3.TextSize = 11
StatusLine3.Font = Enum.Font.Gotham
StatusLine3.TextWrapped = true
StatusLine3.Text = ""
StatusLine3.Parent = MainFrame

-- Drag and Drop
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

trackConnection(MainFrame.InputBegan:Connect(function(input)
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

trackConnection(MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

trackConnection(game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end))

MainFrame.Parent = ScreenGui
ScreenGui.Parent = targetGuiParent

local function updateStatus(line1, line2, line3)
    if line1 then StatusLine1.Text = line1 end
    if line2 then StatusLine2.Text = line2 end
    if line3 then StatusLine3.Text = line3 end
end

trackConnection(ToggleButton.MouseButton1Click:Connect(function()
    State.Running = not State.Running
    if State.Running then
        ToggleButton.Text = "■"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        updateStatus("▶ РАБОТА ВОЗОБНОВЛЕНА")
    else
        ToggleButton.Text = "▶"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
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

    -- Мгновенно перемещаем CFrame
    if State.RootPart and State.RootPart.Parent then
        State.RootPart.CFrame = CFrame.new(State.LockedPosition)
        State.RootPart.Velocity = Vector3.zero
        State.RootPart.RotVelocity = Vector3.zero
    end

    if State.LockConnection then
        State.LockConnection:Disconnect()
    end

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
    task.wait(0.15)
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
    local n = 0
    for name in pairs(SellableItems) do
        if countItem(name) >= (ItemLimits[name] or 1) then
            n = n + 1
        end
    end
    return n
end

local function getPlayerMoney()
    local best = 0
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        for _, d in ipairs(pgui:GetDescendants()) do
            if d:IsA("TextLabel") and not d:IsDescendantOf(ScreenGui) then
                local txt = d.Text
                if txt:find("$", 1, true) and txt:match("^%s*%$?%s*[%d,]+%s*$") then
                    local v = tonumber(txt:gsub("[^%d]", ""))
                    if v and v > best then
                        best = v
                    end
                end
            end
        end
    end
    return best
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
        task.wait(0.08)
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
                task.wait(0.15)
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
        task.wait(0.05)
    end

    local deadline = tick() + 0.3
    while tool.Parent ~= char and tick() < deadline do
        task.wait()
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
        task.wait(0.35)
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
        task.wait(0.04)
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
    if getPlayerMoney() < Config.ArrowPrice then return false end
    local before = countLuckyArrows()
    updateStatus("🛒 Покупка Lucky Arrow", "Стрел: " .. before .. "/" .. Config.TargetArrows)
    if State.RemoteEvent then
        pcall(function()
            State.RemoteEvent:FireServer("PurchaseShopItem", {ItemName = "1x Lucky Arrow"}, 1, 2)
        end)
    end
    task.wait(1.5)
    if countLuckyArrows() > before then
        updateStatus("✅ Куплена Lucky Arrow!", "Стрел: " .. countLuckyArrows() .. "/" .. Config.TargetArrows)
        return true
    end
    return false
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

-- Быстрый подбор за доли секунды
local function grabItem(item, name)
    local prox = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prox then return false end
    local pos = getItemPosition(item)
    if not pos then return false end

    local before = countItem(name)

    -- Мгновенная позиция (3.5 studs прямо под предметом)
    lockToPosition(pos)

    -- Сразу жмем промпт без промедления
    SafePrompt(prox)

    local started = tick()
    local success = false

    -- Ждем максимум 1.2 секунды. Если предмет украли или не берется — сразу летим дальше!
    while (tick() - started < Config.GrabTimeout) and not CleaningUp do
        if countItem(name) > before then
            success = true
            break
        end
        if not item.Parent or not isItemAvailable(item) then
            break
        end
        -- Дублируем быстрый клик через 0.15с на случай лагов
        if tick() - started > 0.15 and not success then
            SafePrompt(prox)
        end
        task.wait(0.04)
    end

    unlockPosition()

    if success and KeepItems[name] then
        State.RaresFound = State.RaresFound + 1
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
            task.wait(0.04)
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
            task.wait(0.2)
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
            local totalSlots = #getInventoryTools()
            local fullStacks = countCompletedStacks()
            local freeSlots = math.max(0, Config.MaxInventorySlots - totalSlots)

            if not State.StartMoney then
                State.StartMoney = money
            end
            local sessionProfit = math.max(0, money - State.StartMoney)
            local uptimeMinutes = math.floor((tick() - State.StartTime) / 60)

            if fullStacks ~= lastFullCount then
                lastFullCount = fullStacks
                lastProgressTime = tick()
            end

            StatusLine2.Text = string.format("🎒 %d/%d (Свободно: %d) | 🏹 %d/%d | 💰 $%d",
                totalSlots, Config.MaxInventorySlots, freeSlots, arrows, Config.TargetArrows, money)
            StatusLine3.Text = string.format("⏱ %dm | 💵 +$%d сессия | 🍀 Рарки: %d",
                uptimeMinutes, sessionProfit, State.RaresFound)

            local isMoneyGoalReached = (money >= Config.TargetMoney)
            local isArrowsGoalReached = (arrows >= Config.TargetArrows)

            -- 🏆 Финал: накоплен $1M и 10 Lucky Arrow
            if isMoneyGoalReached and isArrowsGoalReached and fullStacks >= 14 then
                updateStatus("🏆 ЦЕЛЬ ДОСТИГНУТА!", "🏹 10 Lucky | 💰 $1M | 📦 Full Stack")
                break
            end

            -- ⚠️ ПРОВЕРКА: Если весь рюкзак (10/10) забит несдаваемыми рарками
            if freeSlots == 0 and sellCount == 0 then
                if isMoneyGoalReached and not isArrowsGoalReached then
                    -- Если деньги есть, но слотов нет — покупаем стрелы, если хватает места
                    updateStatus("🎒 Инвентарь полон", "Ожидание свободного слота")
                    task.wait(3)
                else
                    updateStatus("⚠️ Все 10 слотов заняты рарками!", "Освободите слот для фарма денег")
                    task.wait(3)
                end

            -- 💰 ПРОДАЖА ТОРГОВЦУ:
            -- 1. Набрали 8+ предметов
            -- 2. ИЛИ инвентарь заполнен до предела (freeSlots == 0), и у нас есть хотя бы 2+ предмета на продажу
            elseif sellCount >= Config.SellThreshold or (freeSlots == 0 and sellCount >= Config.MinSellBatch) then
                updateStatus("🛒 Продажа (" .. sellCount .. " шт.)", "Баланс: $" .. money)
                trySell()

            -- 🏹 ПОКУПКА LUCKY ARROW:
            -- Если включен BuyArrowsAfterMoney: покупаем стрелы ТОЛЬКО когда накоплен $1,000,000!
            -- Это гарантирует, что все 10 слотов свободны для быстрого фарма денег.
            elseif (not Config.BuyArrowsAfterMoney or isMoneyGoalReached)
                and arrows < Config.TargetArrows
                and money >= Config.ArrowPrice
                and freeSlots > 0 then

                buyLuckyArrow()
                task.wait(0.4)

            -- ⚡ ФАРМ ЛУТА:
            else
                farmStep()
            end
        else
            task.wait(0.8)
            pcall(refreshCharacter)
        end
        task.wait(0.08)
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
