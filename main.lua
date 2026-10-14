-- BLISS FARM v3.4 | YBA | STACK-SMART
local CFG={TARGET=1000000, ARROWS=10, ARROW_PRICE=75000,
HOP_MIN=6, DROUGHT=60, HOP_ENABLED=true, BL_TTL=120, TPOffset=10}
-- ЛИМИТЫ СТАКОВ (из Void)
local MAX={["Gold Coin"]=45,["Rokakaka"]=25,["Pure Rokakaka"]=10,
["Mysterious Arrow"]=25,["Diamond"]=30,["Ancient Scroll"]=10,
["Caesar's Headband"]=10,["Stone Mask"]=10,
["Rib Cage of The Saint's Corpse"]=20,["Quinton's Glove"]=10,
["Zeppeli's Hat"]=10,["Lucky Arrow"]=10,["Lucky Stone Mask"]=10,
["Clackers"]=10,["Steel Ball"]=10,["Dio's Diary"]=10}
local SELLABLE={["Gold Coin"]=true,["Mysterious Arrow"]=true,["Rokakaka"]=true,
["Pure Rokakaka"]=true,["Ancient Scroll"]=true,["Quinton's Glove"]=true,
["Diamond"]=true,["Zeppeli's Hat"]=true,["Clackers"]=true,
["Rib Cage of The Saint's Corpse"]=true,["Caesar's Headband"]=true,
["Dio's Diary"]=true,["Steel Ball"]=true,["Stone Mask"]=true}
local KEEP={["Lucky Arrow"]=true,["Lucky Stone Mask"]=true}
local TP_POINTS={
Vector3.new(95,62,72),Vector3.new(-216,10,-66),Vector3.new(-36,-42,523),
Vector3.new(39,-33,23),Vector3.new(-200,-33,-269),Vector3.new(-65,-33,-606),
Vector3.new(73,24,-932),Vector3.new(97,14,-531),Vector3.new(253,57,-210),
Vector3.new(509,14,106),Vector3.new(976,-43,-111),Vector3.new(-655,-21,-750),
Vector3.new(-190,15,-585),Vector3.new(-182,0,-231)}
local MERCHANT_POS=Vector3.new(-702,-25,-335)

local plr=game:GetService("Players").LocalPlayer
local RS=game:GetService("RunService")
local VIM=game:GetService("VirtualInputManager")
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local chr,hum,root,re
local RUNNING=true
local blacklist={}
local lastLoot=tick()
local totalPicked=0
local sellFails=0

--==== АНТИЧИТ ====
pcall(function()
    local OriginalNamecallTP
    OriginalNamecallTP = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local Arguments = {...}
        local Method = getnamecallmethod()
        if Method == "InvokeServer" and Arguments[1] == "idklolbrah2de" then
            return "  ___XP DE KEY"
        end
        return OriginalNamecallTP(self, ...)
    end))
end)

local function refreshChar()
    chr=plr.Character or plr.CharacterAdded:Wait()
    hum=chr:WaitForChild("Humanoid")
    root=chr:WaitForChild("HumanoidRootPart")
    re=chr:WaitForChild("RemoteEvent")
end
refreshChar()
plr.CharacterAdded:Connect(function(c)
    task.wait(3)
    pcall(refreshChar)
    blacklist={}
    lastLoot=tick()
end)

--==== GUI ====
for _,g in ipairs(plr:FindFirstChild("PlayerGui"):GetChildren()) do
    if g.Name=="BlissFarmUI" then g:Destroy() end
end
local gui=Instance.new("ScreenGui") gui.Name="BlissFarmUI" gui.ResetOnSpawn=false
local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,340,0,90) frame.Position=UDim2.new(0,10,0,86)
frame.BackgroundColor3=Color3.fromRGB(12,12,18) frame.BackgroundTransparency=0.2
frame.BorderSizePixel=0
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,12) corner.Parent=frame
local t=Instance.new("TextLabel")
t.Size=UDim2.new(1,-48,0,18) t.Position=UDim2.new(0,10,0,7)
t.BackgroundTransparency=1 t.TextXAlignment=Enum.TextXAlignment.Left
t.TextColor3=Color3.fromRGB(255,215,80) t.TextSize=13 t.Font=Enum.Font.GothamBold
t.Text="⚡ BLISS FARM v3.4" t.Parent=frame
local stopBtn=Instance.new("TextButton")
stopBtn.Size=UDim2.new(0,28,0,20) stopBtn.Position=UDim2.new(1,-36,0,6)
stopBtn.BackgroundColor3=Color3.fromRGB(200,60,60) stopBtn.Text="■"
stopBtn.TextColor3=Color3.new(1,1,1) stopBtn.TextSize=12 stopBtn.Font=Enum.Font.GothamBold
stopBtn.BorderSizePixel=0 stopBtn.Parent=frame
local sc=Instance.new("UICorner") sc.CornerRadius=UDim.new(0,6) sc.Parent=stopBtn
local s=Instance.new("TextLabel")
s.Size=UDim2.new(1,-20,0,16) s.Position=UDim2.new(0,10,0,28)
s.BackgroundTransparency=1 s.TextXAlignment=Enum.TextXAlignment.Left
s.TextColor3=Color3.fromRGB(140,255,140) s.TextSize=11 s.Font=Enum.Font.Gotham
s.TextWrapped=true s.Parent=frame
local s2=Instance.new("TextLabel")
s2.Size=UDim2.new(1,-20,0,16) s2.Position=UDim2.new(0,10,0,48)
s2.BackgroundTransparency=1 s2.TextXAlignment=Enum.TextXAlignment.Left
s2.TextColor3=Color3.fromRGB(160,160,170) s2.TextSize=11 s2.Font=Enum.Font.Gotham
s2.TextWrapped=true s2.Parent=frame
local s3=Instance.new("TextLabel")
s3.Size=UDim2.new(1,-20,0,16) s3.Position=UDim2.new(0,10,0,66)
s3.BackgroundTransparency=1 s3.TextXAlignment=Enum.TextXAlignment.Left
s3.TextColor3=Color3.fromRGB(200,200,220) s3.TextSize=11 s3.Font=Enum.Font.Gotham
s3.TextWrapped=true s3.Text="" s3.Parent=frame
frame.Parent=gui gui.Parent=plr:WaitForChild("PlayerGui")
local function status(a,b,c) s.Text=a if b then s2.Text=b end if c then s3.Text=c end end
stopBtn.MouseButton1Click:Connect(function()
    RUNNING=not RUNNING
    if RUNNING then
        stopBtn.Text="■" stopBtn.BackgroundColor3=Color3.fromRGB(200,60,60)
        status("▶ RESUMED")
    else
        stopBtn.Text="▶" stopBtn.BackgroundColor3=Color3.fromRGB(60,170,80)
        status("⛔ STOPPED","тап ▶ чтобы продолжить")
    end
end)
local function waitIfStopped() while not RUNNING do task.wait(0.5) end end

--==== ДВИЖОК ====
local lockedPosition=nil local lockConn=nil
local function lockToPosition(position)
    lockedPosition=Vector3.new(position.X,position.Y-CFG.TPOffset,position.Z)
    if lockConn then lockConn:Disconnect() end
    lockConn=RS.Heartbeat:Connect(function()
        if not RUNNING or not lockedPosition then return end
        local char=plr.Character
        if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local cam=workspace.CurrentCamera
        local flatDir=Vector3.new(0,0,-1)
        if cam then
            local look=cam.CFrame.LookVector
            local flat=Vector3.new(look.X,0,look.Z)
            if flat.Magnitude>0.01 then flatDir=flat.Unit end
        end
        hrp.CFrame=CFrame.new(lockedPosition,lockedPosition+flatDir)
        hrp.Velocity=Vector3.zero
    end)
end
local function unlockPosition()
    lockedPosition=nil
    if lockConn then lockConn:Disconnect() lockConn=nil end
    pcall(function()
        if chr then
            for _,p in pairs(chr:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=true end
            end
        end
    end)
end
RS.Stepped:Connect(function()
    if lockedPosition and chr then
        for _,p in pairs(chr:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end
end)
local function goTo(pos)
    lockToPosition(pos)
    task.wait(0.35)
    unlockPosition()
end
local function rescueIfFalling()
    if root and root.Parent and root.Position.Y<-400 then
        status("🕳 яма — спасаю")
        lockToPosition(TP_POINTS[1])
        task.wait(0.6)
        unlockPosition()
    end
end

--==== SERVER HOP ====
local function doServerHop(reason)
    if not CFG.HOP_ENABLED then status("⚠ HOP off: "..reason) return end
    status("🚀 HOP: "..reason)
    task.wait(1)
    local servers={}
    pcall(function()
        local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local data=HttpService:JSONDecode(game:HttpGet(url))
        for _,sv in ipairs(data.data) do
            if sv.playing<sv.maxPlayers and sv.id~=game.JobId then
                servers[#servers+1]=sv.id
            end
        end
    end)
    if #servers>0 then
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId,servers[math.random(1,#servers)],plr) end)
    else
        pcall(function() TeleportService:Teleport(game.PlaceId,plr) end)
    end
end

--==== ИНВЕНТАРЬ + ЛИМИТЫ ====
local function invTools()
    local list={}
    for _,cont in ipairs({plr.Backpack,chr}) do
        if cont then
            for _,tl in ipairs(cont:GetChildren()) do
                if tl:IsA("Tool") then list[#list+1]=tl end
            end
        end
    end
    return list
end
local function countItem(name)
    local n=0
    for _,tl in ipairs(invTools()) do if tl.Name==name then n=n+1 end end
    return n
end
local function isItemFull(name)
    local cap=MAX[name]
    if not cap then return false end
    return countItem(name)>=cap
end
local function sellCount()
    local n=0
    for _,tl in ipairs(invTools()) do if SELLABLE[tl.Name] then n=n+1 end end
    return n
end
local function arrowCount() return countItem("Lucky Arrow") end
local function fullCount()
    local n=0
    for name in pairs(SELLABLE) do
        if countItem(name)>=(MAX[name] or 1) then n=n+1 end
    end
    return n
end
local function getMoney()
    local m=0
    for _,d in ipairs(plr.PlayerGui:GetDescendants()) do
        if d:IsA("TextLabel") and not d:IsDescendantOf(gui) then
            local t2=d.Text
            if t2:find("$",1,true) and t2:match("^%s*%$?%s*[%d,]+%s*$") then
                local v=tonumber(t2:gsub("[^%d]",""))
                if v and v>m then m=v end
            end
        end
    end
    return m
end

--==== ПРОДАЖА ====
local function fakeInput()
    return {UserInputType=Enum.UserInputType.MouseButton1,
    UserInputState=Enum.UserInputState.Begin,
    Position=Vector2.new(100,100),Delta=Vector2.new(0,0)}
end
local function normalizeText(text)
    text=tostring(text or ""):lower()
    text=text:gsub("[%c%p]"," ")
    text=text:gsub("%s+"," ")
    return text:match("^%s*(.-)%s*$") or ""
end
local function getButtonText(btn)
    if not btn then return "" end
    if btn:IsA("TextButton") and btn.Text~="" then return btn.Text end
    for _,child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text~="" then return child.Text end
    end
    return ""
end
local function isActuallyVisible(obj)
    if not obj or not obj.Parent then return false end
    if obj:IsA("GuiObject") and obj.Visible==false then return false end
    local parent=obj.Parent
    while parent and parent~=plr.PlayerGui do
        if parent:IsA("GuiObject") and parent.Visible==false then return false end
        parent=parent.Parent
    end
    return true
end
local function getDialogueGui()
    local direct=plr.PlayerGui:FindFirstChild("DialogueGui")
    if direct then return direct end
    for _,obj in ipairs(plr.PlayerGui:GetChildren()) do
        if tostring(obj.Name):lower():find("dialog",1,true) then return obj end
    end
    return nil
end
local function clickButton(btn)
    if not btn or not btn.Parent then return false end
    local done=false
    pcall(function()
        for _,sigName in ipairs({"MouseButton1Click","Activated","InputBegan"}) do
            local sig=btn[sigName]
            if sig and getconnections then
                for _,cn in ipairs(getconnections(sig)) do
                    pcall(function() cn.Function(fakeInput()) end)
                    pcall(function() cn.Function() end)
                    done=true
                end
            end
        end
    end)
    if not done then
        pcall(function()
            local x=btn.AbsolutePosition.X+btn.AbsoluteSize.X/2
            local y=btn.AbsolutePosition.Y+btn.AbsoluteSize.Y/2
            VIM:SendMouseButtonEvent(x,y,0,true,game,1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(x,y,0,false,game,1)
        end)
    end
    return true
end
local NEGATIVE_WORDS={"buy","leave","cancel","nevermind","never mind","no thanks","no thank","goodbye","exit","nothing"}
local function containsAny(text,words)
    for _,w in ipairs(words) do if text:find(w,1,true) then return true end end
    return false
end
local function scoreSellOption(text)
    local n=normalizeText(text)
    if n=="" then return -math.huge end
    if containsAny(n,NEGATIVE_WORDS) then return -1000 end
    local score=0
    if n:find("sell",1,true) then score=score+100 end
    if n:find("all",1,true) or n:find("everything",1,true) or n:find("max",1,true) then score=score+150 end
    if n:find("deal",1,true) then score=score+90 end
    if n:find("confirm",1,true) then score=score+80 end
    if n=="yes" or n:find("yes ",1,true)==1 then score=score+70 end
    if n=="ok" or n=="okay" or n:find("sure",1,true) then score=score+55 end
    return score
end
local function waitForDialogueButtons(timeout)
    timeout=timeout or 3
    local started=tick()
    while tick()-started<timeout do
        local dlg=getDialogueGui()
        if dlg then
            local buttons={}
            for _,obj in ipairs(dlg:GetDescendants()) do
                if obj:IsA("GuiButton") and isActuallyVisible(obj) then
                    local text=getButtonText(obj)
                    if normalizeText(text)~="" then table.insert(buttons,{Button=obj,Text=text}) end
                end
            end
            if #buttons>0 then return buttons end
        end
        task.wait(0.1)
    end
    return {}
end
local function chooseBestSellButton(buttons)
    local best,bs=nil,-math.huge
    for _,e in ipairs(buttons) do
        local s2b=scoreSellOption(e.Text)
        if s2b>bs then bs=s2b best=e end
    end
    if bs<=0 then return nil end
    return best
end
local function findMerchantPrompt()
    local dlgFolder=ReplicatedStorage:FindFirstChild("Dialogue")
    if dlgFolder then
        local merchant=dlgFolder:FindFirstChild("Merchant",true)
        if merchant then
            local prompt=merchant:FindFirstChildWhichIsA("ProximityPrompt",true)
            if prompt then return prompt,merchant end
        end
    end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent=obj.Parent
            local depth=0
            while parent and parent~=workspace and depth<6 do
                if tostring(parent.Name):lower():find("merchant",1,true) then return obj,nil end
                parent=parent.Parent
                depth=depth+1
            end
        end
    end
    return nil,nil
end
local function closeDialogueIfOpen()
    local dlg=getDialogueGui()
    if not dlg then return end
    for _,obj in ipairs(dlg:GetDescendants()) do
        if obj:IsA("GuiButton") and isActuallyVisible(obj) then
            local t=normalizeText(getButtonText(obj))
            if t:find("leave",1,true) or t:find("cancel",1,true) or t:find("goodbye",1,true) or t:find("exit",1,true) then
                clickButton(obj)
                task.wait(0.2)
                return
            end
        end
    end
end
local function equipTool(itemName)
    local char=plr.Character
    local h=char and char:FindFirstChildWhichIsA("Humanoid")
    if not h then return nil end
    local tool=plr.Backpack:FindFirstChild(itemName)
    if not tool and char then tool=char:FindFirstChild(itemName) end
    if not tool then return nil end
    if tool.Parent==plr.Backpack then
        pcall(function() h:EquipTool(tool) end)
        task.wait(0.08)
    end
    local deadline=tick()+0.35
    while tool.Parent~=char and tick()<deadline do task.wait() end
    if tool.Parent~=char then return nil end
    return tool
end
local function runMerchantSellDialogue(itemName,beforeCount)
    for step=1,7 do
        if countItem(itemName)<beforeCount then return true end
        local buttons=waitForDialogueButtons(step==1 and 3 or 2)
        if #buttons==0 then return false end
        local chosen=chooseBestSellButton(buttons)
        if not chosen then return false end
        clickButton(chosen.Button)
        task.wait(0.5)
    end
    return countItem(itemName)<beforeCount
end
local function openMerchant(prompt,merchant)
    lockToPosition(MERCHANT_POS)
    task.wait(0.5)
    pcall(function() re:FireServer("HoldAttack",{Bool=false,Type="m1"}) end)
    task.wait(0.2)
    if prompt then pcall(function() fireproximityprompt(prompt) end) end
    if merchant then pcall(function() re:FireServer("PromptTriggered", merchant) end) end
    task.wait(0.5)
end
local function sellAllNow()
    local prompt,merchant=findMerchantPrompt()
    local dlg=ReplicatedStorage:FindFirstChild("Dialogue")
    if not merchant and dlg then merchant=dlg:FindFirstChild("Merchant") or dlg end
    openMerchant(prompt,merchant)
    local toSell={}
    for _,tl in ipairs(invTools()) do
        if SELLABLE[tl.Name] and not toSell[tl.Name] then toSell[tl.Name]=true end
    end
    local soldAny=false
    for itemName in pairs(toSell) do
        if not RUNNING then break end
        local initialCount=countItem(itemName)
        if initialCount>0 then
            equipTool(itemName)
            closeDialogueIfOpen()
            if prompt then pcall(function() fireproximityprompt(prompt) end) end
            task.wait(0.45)
            if runMerchantSellDialogue(itemName,initialCount) then soldAny=true end
            closeDialogueIfOpen()
        end
        task.wait(0.05)
    end
    closeDialogueIfOpen()
    unlockPosition()
    return soldAny
end
local function trySell()
    if sellAllNow() then
        sellFails=0
        status("💰 продала","💰 $"..getMoney())
    else
        sellFails=sellFails+1
        if sellFails>=2 then
            sellFails=0
            doServerHop("селл застрял")
        end
    end
end

--==== ПОКУПКА ====
local function buyLuckyArrow()
    if getMoney()<CFG.ARROW_PRICE then return false end
    local a0=arrowCount()
    status("🛒 ПОКУПКА ЛАКИ","🏹 "..a0.."/"..CFG.ARROWS)
    pcall(function() re:FireServer("PurchaseShopItem",{ItemName="1x Lucky Arrow"},1,2) end)
    task.wait(2)
    if arrowCount()>a0 then
        status("✅ КУПИЛ!","🏹 "..arrowCount().."/"..CFG.ARROWS)
        return true
    end
    return false
end

--==== СКАНЕР (с лимитами!) ====
local function itemName(item)
    local prox=item:FindFirstChildWhichIsA("ProximityPrompt",true)
    if prox and prox.ObjectText and prox.ObjectText~="" then return prox.ObjectText end
    return item.Name
end
local function isAvailable(item)
    if item:IsA("BasePart") then return item.Transparency<0.95 end
    for _,d in ipairs(item:GetChildren()) do
        if d:IsA("BasePart") and d.Transparency<0.95 then return true end
    end
    return false
end
local function itemPos(item)
    local pos=nil
    pcall(function()
        if item:IsA("BasePart") then pos=item.Position
        elseif item.PrimaryPart then pos=item.PrimaryPart.Position
        else pos=item:GetPivot().Position end
    end)
    return pos
end
local function isBL(item)
    return blacklist[item] and (tick()-blacklist[item])<CFG.BL_TTL
end
local function findLoot()
    local folder=workspace:FindFirstChild("Item_Spawns")
    folder=folder and folder:FindFirstChild("Items")
    if not folder then return nil,nil,0 end
    local best,bname,bd,cnt=nil,nil,math.huge,0
    for _,item in ipairs(folder:GetChildren()) do
        local nm=itemName(item)
        if (SELLABLE[nm] or KEEP[nm]) and isAvailable(item) and not isItemFull(nm) then
            cnt=cnt+1
            local pos=itemPos(item)
            if pos and root then
                local dist=(pos-root.Position).Magnitude
                if dist<bd then bd,best,bname=dist,item,nm end
            end
        end
    end
    return best,bname,cnt
end
local function grab(item,name)
    local prox=item:FindFirstChildWhichIsA("ProximityPrompt",true)
    if not prox then return false end
    local pos=itemPos(item)
    local c0=countItem(name)
    if pos then
        lockToPosition(pos)
        task.wait(0.35)
    end
    pcall(function() fireproximityprompt(prox) end)
    local t0=tick()
    local ok=false
    while tick()-t0<5 do
        if countItem(name)>c0 then ok=true break end
        if not item.Parent then break end
        if not isAvailable(item) then break end
        task.wait(0.05)
    end
    unlockPosition()
    return ok
end

--==== ШАГ ФАРМА ====
local function farmStep()
    local item,name,cnt=findLoot()
    if item and not isBL(item) then
        status("⚡ "..name,"💰 $"..getMoney())
        if grab(item,name) then
            totalPicked=totalPicked+1
            lastLoot=tick()
            status(KEEP[name] and ("🍀 KEEP "..name) or ("📦 +"..name))
            task.wait(0.2)
        else
            blacklist[item]=tick()
            status("⚠ пропуск")
        end
    else
        if tick()-lastLoot>CFG.DROUGHT then
            doServerHop("засуха")
            task.wait(3)
            pcall(refreshChar)
            lastLoot=tick()
        else
            goTo(TP_POINTS[math.random(1,#TP_POINTS)])
            task.wait(0.5)
        end
    end
end

--==== SMART LOOP v3.4 ====
task.spawn(function()
    status("🚀 BLISS FARM v3.4","STACK-SMART")
    task.wait(1)
    local lastProgress=tick()
    local lastFull=-1
    while RUNNING do
        waitIfStopped()
        rescueIfFalling()
        if chr and chr.Parent and hum and hum.Health>0 then
            local money=getMoney()
            local arrows=arrowCount()
            local scnt=sellCount()
            local total=#invTools()
            local fc=fullCount()
            if fc~=lastFull then lastFull=fc lastProgress=tick() end
            s2.Text="🎒 "..total.." | 🏹 "..arrows.."/10 | 📦 "..fc.."/14 | 💰 $"..money
            local stackMode=(arrows>=CFG.ARROWS and money>=CFG.TARGET)
            -- 🏆 ФИНАЛ: всё полное
            if stackMode and fc>=14 then
                status("🏆 ВСЁ ГОТОВО, БРО!","🏹 10 | 💰 $1M | 📦 14/14 FULL")
                s3.Text="🏹 10 Lucky | 💰 $1M | 📦 Full Stack"
                break
            end
            -- 🟠 слоты кончились (нужен 2x геймпасс)
            if stackMode and total>=10 and fc<14 and tick()-lastProgress>180 then
                status("🟠 слоты забиты — нужен 2x геймпасс","📦 "..fc.."/14")
                s3.Text="Full Stack невозможен без 2x инвентаря"
                break
            end
            if stackMode then
                -- 📦 режим коллекции: НЕ продаём, добираем стаки до MAX
                farmStep()
            elseif scnt>=8 or (total>=10 and scnt>0) then
                status("🛒 продаю "..scnt,"🎒 "..total)
                trySell()
            elseif total>=10 and scnt==0 then
                status("🎒 полон редкими — жду")
                task.wait(5)
            elseif arrows<CFG.ARROWS and money>=CFG.ARROW_PRICE and total<=9 then
                buyLuckyArrow()
                task.wait(0.5)
            else
                farmStep()
            end
        else
            task.wait(1)
            pcall(refreshChar)
        end
        task.wait(0.15)
    end
end)

task.spawn(function()
    while true do
        task.wait(CFG.HOP_MIN*60)
        if CFG.HOP_ENABLED and RUNNING then
            doServerHop("таймер")
        end
    end
end)
