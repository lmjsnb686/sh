-- ============================================================
-- 顾琼 UI
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiereSeren/UI/refs/heads/main/cyyWind.lua"))()
if not WindUI then
    warn("[GQ] UI load failed")
    return
end

-- ============================================================
-- 十六进制字符串解码
-- ============================================================
local function h(s)
    local t = {}
    for i = 1, #s, 2 do
        t[#t+1] = string.char(tonumber(s:sub(i, i+1), 16))
    end
    return table.concat(t)
end

local K_HMG   = h("6861636b696e674d696e6967616d65")              -- hackingMinigame
local K_SMG   = h("73746172744d696e6967616d65")                  -- startMinigame
local K_DH    = h("64697361626c654861636b696e67")                -- disableHacking
local K_DM    = h("64697361626c654d696e6967616d6573")            -- disableMinigames
local K_BM    = h("426c61636b204d61726b6574")                    -- Black Market
local K_PUR   = h("7075726368617365")                            -- purchase

local K_RULES = "GameRules"
local K_FW    = "Framework"
local K_WEAP  = "Weapons"
local K_STUFF = "Stuff"
local K_REM   = "Remote"
local K_PFUNC = "PlayerFunc"
local K_GLOCK = "Glock 17"
local K_WANT  = "WantedLevel"
local K_PURS  = "Pursuit"
local K_POLICE = "Police"

-- ============================================================
-- 状态
-- ============================================================
local CrimeESPEnabled = false
local ESPEnabled = false
local AutoToolEnabled = false
local Unloaded = false

-- ★ 无限车辆耐久 / 自动捡钱
local InfVehicleHPEnabled = false
local AutoPickupEnabled = false
local autoPickupRange = 30
local autoPickupInterval = 0.15
local autoPickupLast = 0

-- 抓取状态
local GrabEnabled = false
local grabbedPart = nil
local grabbedMass = 50
local grabTargetDistance = 20
local grabOriginalCanCollide = nil
local grabMouseDownConn = nil
local grabMouseUpConn = nil
local grabRenderConn = nil
local grabAttachment = nil
local grabAlignPosition = nil
local grabAlignOrientation = nil
local grabOriginalRotation = nil
local grabSimRadiusApplied = false
local grabOriginalSimRadius = nil
local grabOriginalMaxSimRadius = nil

local grabWindow = nil
local grabWindowCollapsed = false
local grabStatusLabel = nil
local grabToggleBtn = nil
local grabBodyFrame = nil
local grabCollapseBtn = nil

local Connections = {}

local TEAM_COLORS = {
    [K_POLICE]         = Color3.fromRGB(80, 150, 255),
    Civilian           = Color3.fromRGB(255, 255, 255),
    Chef               = Color3.fromRGB(255, 200, 100),
    Delivery           = Color3.fromRGB(255, 255, 100),
    Farmer             = Color3.fromRGB(150, 255, 150),
    Fire               = Color3.fromRGB(255, 100, 100),
    Medical            = Color3.fromRGB(255, 150, 255),
    Prisoner           = Color3.fromRGB(200, 200, 200),
    Criminal           = Color3.fromRGB(255, 80, 80),
    ["Road Service"]   = Color3.fromRGB(180, 180, 180),
    Transit            = Color3.fromRGB(100, 200, 200),
    Default            = Color3.fromRGB(255, 255, 255),
}

local TEAM_CN = {
    [K_POLICE] = "警察", Civilian = "平民", Chef = "厨师",
    Delivery = "外卖", Farmer = "农民", Fire = "消防",
    Medical = "医疗", Prisoner = "囚犯", Criminal = "罪犯",
    ["Road Service"] = "道路救援", Transit = "运输",
}

local function GetCharacter(player)
    player = player or LocalPlayer
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
    if not humanoid or not root then return end
    return character, humanoid, root
end

-- ============================================================
-- 自动工具
-- ============================================================
local autoToolOriginal = {}
local function setAutoTool(enabled)
    AutoToolEnabled = enabled
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local gameRules = modules and modules:FindFirstChild(K_RULES)
        if gameRules then
            local rules = require(gameRules)
            if rules then
                rules[K_DH] = enabled
                rules[K_DM] = enabled
            end
        end
        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local framework = playerScripts and playerScripts:FindFirstChild(K_FW)
        local charMod = framework and framework:FindFirstChild("Character")
        if charMod then
            local char = require(charMod)
            if char then
                if not autoToolOriginal[K_HMG] then
                    autoToolOriginal[K_HMG] = char[K_HMG]
                end
                if not autoToolOriginal[K_SMG] then
                    autoToolOriginal[K_SMG] = char[K_SMG]
                end
                if enabled then
                    char[K_HMG] = function() return true end
                    char[K_SMG] = function() return true end
                else
                    if autoToolOriginal[K_HMG] then
                        char[K_HMG] = autoToolOriginal[K_HMG]
                    end
                    if autoToolOriginal[K_SMG] then
                        char[K_SMG] = autoToolOriginal[K_SMG]
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- Remote
-- ============================================================
local RemoteFolder = ReplicatedStorage:WaitForChild(K_REM, 30)
local PlayerFunc  = RemoteFolder and RemoteFolder:WaitForChild(K_PFUNC, 30)

-- ============================================================
-- ★ 无限车辆耐久
-- ============================================================
local VehicleHP_KEYS = {
    "Durability",
    "Health",
    "VehicleHealth",
    "HP",
    "Condition",
}

local function getCurrentVehicleModel()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    local seat = hum.SeatPart
    if seat then
        local v = seat
        while v and v ~= Workspace do
            if v:FindFirstChild("_Chassis") or v:FindFirstChild("Config") then
                return v
            end
            v = v.Parent
        end
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local ar = hrp.AssemblyRootPart
        if ar and ar ~= hrp then
            local v = ar
            while v and v ~= Workspace do
                if v:FindFirstChild("_Chassis") or v:FindFirstChild("Config") then
                    return v
                end
                v = v.Parent
            end
        end
    end

    return nil
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not InfVehicleHPEnabled or Unloaded then return end

    local model = getCurrentVehicleModel()
    if not model then return end

    pcall(function()
        for _, k in ipairs(VehicleHP_KEYS) do
            local attr = model:GetAttribute(k)
            if attr ~= nil then
                model:SetAttribute(k, 1000000)
            end
        end
    end)

    for _, d in ipairs(model:GetDescendants()) do
        pcall(function()
            for _, k in ipairs(VehicleHP_KEYS) do
                local attr = d:GetAttribute(k)
                if attr ~= nil then
                    d:SetAttribute(k, 1000000)
                end
            end

            if d:IsA("NumberValue") or d:IsA("IntValue") then
                local n = d.Name:lower()
                if n:find("durab")
                or n:find("health")
                or n == "hp"
                or n:find("vehiclehp")
                or n:find("condition") then
                    d.Value = 1000000
                end
            end
        end)
    end
end))

-- ============================================================
-- ★ 自动捡钱
-- ============================================================
local function isPickupCandidate(inst)
    if not inst then return false end
    if inst:IsA("Tool") then
        local n = inst.Name:lower()
        if n:find("cash")
        or n:find("money")
        or n:find("dollar")
        or n:find("coin")
        or n:find("bill") then
            return true
        end
    elseif inst:IsA("Model") or inst:IsA("BasePart") then
        local n = inst.Name:lower()
        if n:find("cash")
        or n:find("money")
        or n:find("dollar")
        or n:find("coin")
        or n:find("bill")
        or n:find("drop") then
            return true
        end
    end
    return false
end

local function getTargetRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

local function tryPickupItem(inst, myRoot)
    local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        local d = inst
        while d and d ~= Workspace do
            local p = d:FindFirstChildOfClass("ProximityPrompt")
            if p then prompt = p; break end
            d = d.Parent
        end
    end

    if prompt then
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
            else
                prompt:InputHoldBegin()
                task.wait(0.05)
                prompt:InputHoldEnd()
            end
        end)
        return true
    end

    local base = inst:IsA("BasePart") and inst
        or inst:FindFirstChildWhichIsA("BasePart")
    if base and myRoot then
        pcall(function()
            myRoot.CFrame = CFrame.new(base.Position + Vector3.new(0, 2, 0))
        end)
        return true
    end

    if inst:IsA("Tool") and inst.Parent ~= LocalPlayer.Character then
        pcall(function()
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:EquipTool(inst)
            end
        end)
        return true
    end

    return false
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not AutoPickupEnabled or Unloaded then return end

    local now = tick()
    if now - autoPickupLast < autoPickupInterval then return end

    local myRoot = getTargetRoot()
    if not myRoot then return end

    local folders = {
        Workspace:FindFirstChild("Gameplay"),
        Workspace:FindFirstChild("Items"),
        Workspace:FindFirstChild("Drops"),
        Workspace:FindFirstChild("Debris"),
        Workspace,
    }

    for _, container in ipairs(folders) do
        if not container then continue end
        local children = container:GetChildren()
        for _, inst in ipairs(children) do
            if isPickupCandidate(inst) then
                local pos
                if inst:IsA("BasePart") then
                    pos = inst.Position
                elseif inst:IsA("Model") then
                    local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
                    if p then pos = p.Position end
                elseif inst:IsA("Tool") then
                    local h = inst:FindFirstChild("Handle")
                    if h then pos = h.Position end
                end

                if pos then
                    local dist = (pos - myRoot.Position).Magnitude
                    if dist <= autoPickupRange then
                        if tryPickupItem(inst, myRoot) then
                            autoPickupLast = now
                            return
                        end
                    end
                end
            end
        end
    end
end))

-- ============================================================
-- 抓取核心
-- ============================================================
local function grabExpandSimRadius()
    if not (gethiddenproperty and sethiddenproperty) then return end
    if not grabSimRadiusApplied then
        local ok1, r1 = pcall(gethiddenproperty, LocalPlayer, "SimulationRadius")
        local ok2, r2 = pcall(gethiddenproperty, LocalPlayer, "MaximumSimulationRadius")
        grabOriginalSimRadius = ok1 and type(r1) == "number" and r1 or nil
        grabOriginalMaxSimRadius = ok2 and type(r2) == "number" and r2 or nil
        grabSimRadiusApplied = true
    end
    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", 1e9)
    pcall(sethiddenproperty, LocalPlayer, "MaximumSimulationRadius", 1e9)
end

local function grabRestoreSimRadius()
    if not grabSimRadiusApplied then return end
    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", grabOriginalSimRadius or 1000)
    pcall(sethiddenproperty, LocalPlayer, "MaximumSimulationRadius", grabOriginalMaxSimRadius or 1000)
    grabSimRadiusApplied = false
end

local function grabClear()
    if grabAlignPosition then grabAlignPosition:Destroy(); grabAlignPosition = nil end
    if grabAlignOrientation then grabAlignOrientation:Destroy(); grabAlignOrientation = nil end
    if grabAttachment then grabAttachment:Destroy(); grabAttachment = nil end

    if grabbedPart then
        pcall(function()
            if grabOriginalCanCollide ~= nil then
                grabbedPart.CanCollide = grabOriginalCanCollide
            end
            grabbedPart.AssemblyLinearVelocity = Vector3.zero
            grabbedPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    grabbedPart = nil
    grabOriginalCanCollide = nil
    grabOriginalRotation = nil

    grabRestoreSimRadius()

    if grabRenderConn then
        grabRenderConn:Disconnect()
        grabRenderConn = nil
    end
end

local function grabStart(part)
    if not (part and part:IsA("BasePart") and not part.Anchored) then
        return false
    end
    if LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character) then
        return false
    end
    if part.Size.Magnitude >= 500 then
        return false
    end

    grabExpandSimRadius()

    grabbedMass = 50
    pcall(function() grabbedMass = part.AssemblyMass end)

    grabbedPart = part
    grabOriginalCanCollide = part.CanCollide
    part.CanCollide = false

    grabTargetDistance = math.clamp(
        (Camera.CFrame.Position - part.Position).Magnitude,
        8, 60
    )

    grabAttachment = Instance.new("Attachment")
    grabAttachment.Parent = part

    grabAlignPosition = Instance.new("AlignPosition")
    grabAlignPosition.Attachment0 = grabAttachment
    grabAlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    grabAlignPosition.RigidityEnabled = false
    grabAlignPosition.MaxForce = math.clamp(grabbedMass * 8000, 50000, 100000000)
    grabAlignPosition.Responsiveness = 30
    grabAlignPosition.Position = part.Position
    grabAlignPosition.Parent = part

    grabOriginalRotation = part.CFrame.Rotation

    grabAlignOrientation = Instance.new("AlignOrientation")
    grabAlignOrientation.Attachment0 = grabAttachment
    grabAlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    grabAlignOrientation.RigidityEnabled = false
    grabAlignOrientation.MaxTorque = math.clamp(grabbedMass * 8000, 50000, 100000000)
    grabAlignOrientation.Responsiveness = 30
    grabAlignOrientation.CFrame = grabOriginalRotation
    grabAlignOrientation.Parent = part

    local mouse = LocalPlayer:GetMouse()

    grabRenderConn = RunService.RenderStepped:Connect(function()
        if not grabbedPart or not grabbedPart.Parent then
            grabClear(); return
        end
        if not grabAlignPosition or not grabAlignPosition.Parent then return end

        local unitRay = mouse.UnitRay
        local targetPos = unitRay.Origin + unitRay.Direction * grabTargetDistance

        grabAlignPosition.Position = targetPos

        if grabAlignOrientation and grabOriginalRotation then
            grabAlignOrientation.CFrame = grabOriginalRotation
        end
    end)

    return true
end

local function grabSetEnabled(enabled)
    GrabEnabled = enabled and true or false
    local mouse = LocalPlayer:GetMouse()

    if GrabEnabled then
        if not grabMouseDownConn then
            grabMouseDownConn = mouse.Button1Down:Connect(function()
                if not GrabEnabled then return end
                if grabbedPart then return end
                local target = mouse.Target
                if target then grabStart(target) end
            end)
        end
        if not grabMouseUpConn then
            grabMouseUpConn = mouse.Button1Up:Connect(function()
                if grabbedPart then grabClear() end
            end)
        end
    else
        if grabMouseDownConn then grabMouseDownConn:Disconnect(); grabMouseDownConn = nil end
        if grabMouseUpConn then grabMouseUpConn:Disconnect(); grabMouseUpConn = nil end
        grabClear()
    end
end

-- ============================================================
-- 抓取悬浮窗
-- ============================================================
local function grabGetGuiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    return game:GetService("CoreGui")
end

local function grabUpdateStatus()
    if not grabStatusLabel then return end
    if not GrabEnabled then
        grabStatusLabel.Text = "状态：已关闭"
        grabStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    elseif grabbedPart then
        grabStatusLabel.Text = "抓取中：" .. grabbedPart.Name
        grabStatusLabel.TextColor3 = Color3.fromRGB(150, 220, 200)
    else
        grabStatusLabel.Text = "状态：待抓取（按住左键）"
        grabStatusLabel.TextColor3 = Color3.fromRGB(120, 220, 150)
    end
end

local function grabUpdateToggleVisual()
    if not grabToggleBtn then return end
    if GrabEnabled then
        grabToggleBtn.Text = "关闭抓取"
        grabToggleBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
    else
        grabToggleBtn.Text = "开启抓取"
        grabToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
    end
end

local function grabSetCollapsed(collapsed)
    grabWindowCollapsed = collapsed and true or false
    if not grabWindow then return end
    if grabWindowCollapsed then
        grabWindow.Size = UDim2.fromOffset(200, 26)
        if grabBodyFrame then grabBodyFrame.Visible = false end
        if grabCollapseBtn then grabCollapseBtn.Text = "+" end
    else
        grabWindow.Size = UDim2.fromOffset(200, 138)
        if grabBodyFrame then grabBodyFrame.Visible = true end
        if grabCollapseBtn then grabCollapseBtn.Text = "−" end
    end
end

local function grabBuildWindow()
    if grabWindow and grabWindow.Parent then
        return grabWindow
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GuQiong_GrabTool"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = grabGetGuiParent()

    if syn and syn.protect_gui then
        pcall(syn.protect_gui, screenGui)
    elseif protect_gui then
        pcall(protect_gui, screenGui)
    end

    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.fromOffset(200, 138)
    win.Position = UDim2.new(0, 30, 0, 30)
    win.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    win.BorderSizePixel = 0
    win.Active = true
    win.Parent = screenGui

    local title = Instance.new("Frame")
    title.Name = "TitleBar"
    title.Size = UDim2.new(1, 0, 0, 26)
    title.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    title.BorderSizePixel = 0
    title.Parent = win

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -60, 1, 0)
    titleLbl.Position = UDim2.fromOffset(8, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "抓取工具"
    titleLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    titleLbl.TextSize = 14
    titleLbl.Font = Enum.Font.SourceSansBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = title

    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Size = UDim2.fromOffset(20, 20)
    collapseBtn.Position = UDim2.new(1, -22, 0, 3)
    collapseBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    collapseBtn.Text = "−"
    collapseBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
    collapseBtn.TextSize = 16
    collapseBtn.Font = Enum.Font.SourceSansBold
    collapseBtn.BorderSizePixel = 0
    collapseBtn.Parent = title
    grabCollapseBtn = collapseBtn

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, 0, 1, -26)
    body.Position = UDim2.fromOffset(0, 26)
    body.BackgroundTransparency = 1
    body.Parent = win
    grabBodyFrame = body

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -16, 0, 18)
    statusLbl.Position = UDim2.fromOffset(8, 6)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "状态：已关闭"
    statusLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLbl.TextSize = 12
    statusLbl.Font = Enum.Font.SourceSans
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = body
    grabStatusLabel = statusLbl

    local hintLbl = Instance.new("TextLabel")
    hintLbl.Size = UDim2.new(1, -16, 0, 14)
    hintLbl.Position = UDim2.fromOffset(8, 26)
    hintLbl.BackgroundTransparency = 1
    hintLbl.Text = "按住左键抓取未固定部件"
    hintLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
    hintLbl.TextSize = 11
    hintLbl.Font = Enum.Font.SourceSans
    hintLbl.TextXAlignment = Enum.TextXAlignment.Left
    hintLbl.Parent = body

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -16, 0, 26)
    toggleBtn.Position = UDim2.fromOffset(8, 44)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
    toggleBtn.Text = "开启抓取"
    toggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    toggleBtn.TextSize = 13
    toggleBtn.Font = Enum.Font.SourceSansBold
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = true
    toggleBtn.Parent = body
    grabToggleBtn = toggleBtn

    local releaseBtn = Instance.new("TextButton")
    releaseBtn.Size = UDim2.new(1, -16, 0, 22)
    releaseBtn.Position = UDim2.fromOffset(8, 76)
    releaseBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    releaseBtn.Text = "立即释放"
    releaseBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
    releaseBtn.TextSize = 12
    releaseBtn.Font = Enum.Font.SourceSansBold
    releaseBtn.BorderSizePixel = 0
    releaseBtn.AutoButtonColor = true
    releaseBtn.Parent = body

    collapseBtn.MouseButton1Click:Connect(function()
        grabSetCollapsed(not grabWindowCollapsed)
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        grabSetEnabled(not GrabEnabled)
        grabUpdateToggleVisual()
        grabUpdateStatus()
    end)

    releaseBtn.MouseButton1Click:Connect(function()
        if grabbedPart then grabClear() end
        grabUpdateStatus()
    end)

    local dragging, dragStart, startPos = false, nil, nil
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        win.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end)

    grabWindow = win
    grabSetCollapsed(false)
    grabUpdateStatus()
    grabUpdateToggleVisual()

    return win
end

-- ============================================================
-- 远程购买
-- ============================================================
local PurchaseHidden = {
    ["Blue USB"] = true,
    ["Yellow USB"] = true,
}

local function getMarketItems()
    local result = {}
    local stuff = ReplicatedStorage:FindFirstChild(K_STUFF)
    if not stuff then return result end
    local bm = stuff:FindFirstChild(K_BM)
    if not bm then return result end
    for _, category in ipairs(bm:GetChildren()) do
        for _, item in ipairs(category:GetChildren()) do
            if not PurchaseHidden[item.Name] then
                table.insert(result, { name = item.Name, instance = item })
            end
        end
    end
    return result
end

local function findItemByName(name)
    local stuff = ReplicatedStorage:FindFirstChild(K_STUFF)
    if not stuff then return nil end
    local bm = stuff:FindFirstChild(K_BM)
    if not bm then return nil end
    for _, category in ipairs(bm:GetChildren()) do
        local item = category:FindFirstChild(name)
        if item then return item end
    end
    return nil
end

local function purchaseItem(item)
    if not PlayerFunc then
        warn("[购买] PlayerFunc 未找到")
        return false
    end

    local target = item
    if type(item) == "string" then
        target = findItemByName(item)
        if not target then
            warn("[购买] 找不到物品：" .. item)
            return false
        end
    end
    if not target then
        warn("[购买] 物品无效")
        return false
    end

    local ok, result = pcall(function()
        return PlayerFunc:InvokeServer(K_PUR, {
            isRestaurant = false,
            item = target,
        })
    end)

    if not ok then
        warn("[购买] 出错：" .. tostring(result))
        return false
    end
    return result == true
end

_G.BuyScript = {
    getItems = getMarketItems,
    findItem = findItemByName,
    purchase = purchaseItem,
}

-- ============================================================
-- 远程买枪
-- ============================================================
local weaponEntries = {}

local function findWeapons()
    weaponEntries = {}
    local stuff = ReplicatedStorage:FindFirstChild(K_STUFF)
    local weapons = stuff and stuff:FindFirstChild(K_WEAP)
    if not weapons then return end

    for _, slot in ipairs(weapons:GetChildren()) do
        for _, child in ipairs(slot:GetChildren()) do
            table.insert(weaponEntries, {
                name = child.Name,
                slot = slot.Name,
                instance = child,
            })
        end
    end

    if #weaponEntries == 0 then
        for _, child in ipairs(weapons:GetChildren()) do
            table.insert(weaponEntries, {
                name = child.Name,
                slot = nil,
                instance = child,
            })
        end
    end
end

local function buildWeaponNames()
    local names = {}
    for _, entry in ipairs(weaponEntries) do
        table.insert(names, (entry.slot and ("[" .. entry.slot .. "] ") or "") .. entry.name)
    end
    return names
end

local function findEntryByDisplay(display)
    for _, entry in ipairs(weaponEntries) do
        local label = (entry.slot and ("[" .. entry.slot .. "] ") or "") .. entry.name
        if label == display then return entry end
    end
    return nil
end

local function purchaseWeapon(entry)
    if not PlayerFunc then
        warn("[远程买枪] PlayerFunc 未找到")
        return false, "找不到 PlayerFunc"
    end
    if not entry then
        return false, "未选择武器"
    end

    local ok, Result = pcall(function()
        return table.pack(PlayerFunc:InvokeServer(K_PUR, {
            isRestaurant = false,
            item = entry.instance,
        }))
    end)

    if not ok then
        return false, "调用失败: " .. tostring(Result)
    end
    if Result[1] == true then
        return true, "购买成功 " .. entry.name
    else
        return false, "购买失败 → " .. tostring(Result[1])
    end
end

-- ============================================================
-- ESP 工具
-- ============================================================
local function getWantedLevel(pl)
    local wl = pl:GetAttribute(K_WANT)
    if wl == nil then return 0 end
    return tonumber(wl) or 0
end

local function isCriminal(pl)
    if getWantedLevel(pl) > 0 then return true end
    return pl:GetAttribute(K_PURS) == true
end

local function getProfession(pl)
    local team = pl.Team
    if not team then return "未知" end
    return TEAM_CN[team.Name] or team.Name
end

local function getTeamColor(pl)
    local team = pl.Team
    local teamName = team and team.Name or "Default"
    return TEAM_COLORS[teamName] or TEAM_COLORS.Default
end

local ESPHighlights = {}
local ESPBillboards = {}

local function getHighlight(pl, character)
    local hl = ESPHighlights[pl]
    if hl and hl.Parent ~= character then
        pcall(function() hl:Destroy() end)
        hl = nil
    end
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "Marker"
        hl.Adornee = character
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = false
        hl.Parent = character
        ESPHighlights[pl] = hl
    end
    return hl
end

local function getBillboard(pl, character)
    local bb = ESPBillboards[pl]
    if bb and bb.Parent ~= character then
        pcall(function() bb:Destroy() end)
        bb = nil
    end
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name = "ESPInfo"
        bb.Size = UDim2.new(0, 300, 0, 60)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 3000
        bb.ResetOnSpawn = false

        local mainLabel = Instance.new("TextLabel")
        mainLabel.Name = "MainText"
        mainLabel.Size = UDim2.new(1, 0, 0, 18)
        mainLabel.BackgroundTransparency = 1
        mainLabel.Font = Enum.Font.Legacy
        mainLabel.TextSize = 14
        mainLabel.TextStrokeTransparency = 0
        mainLabel.TextColor3 = Color3.fromRGB(255,255,255)
        mainLabel.TextXAlignment = Enum.TextXAlignment.Center
        mainLabel.Parent = bb

        local hpLabel = Instance.new("TextLabel")
        hpLabel.Name = "HPText"
        hpLabel.Size = UDim2.new(0, 80, 0, 16)
        hpLabel.Position = UDim2.new(1.3, 0, 0, 2)
        hpLabel.BackgroundTransparency = 1
        hpLabel.Font = Enum.Font.Legacy
        hpLabel.TextSize = 12
        hpLabel.TextStrokeTransparency = 0
        hpLabel.TextColor3 = Color3.fromRGB(255,255,255)
        hpLabel.TextXAlignment = Enum.TextXAlignment.Left
        hpLabel.Parent = bb

        bb.Parent = character
        ESPBillboards[pl] = bb
    end
    return bb
end

local function cleanupPlayerESP(pl)
    if ESPHighlights[pl] then
        pcall(function() ESPHighlights[pl]:Destroy() end)
        ESPHighlights[pl] = nil
    end
    if ESPBillboards[pl] then
        pcall(function() ESPBillboards[pl]:Destroy() end)
        ESPBillboards[pl] = nil
    end
end

local function updateESP()
    if Unloaded then return end
    if not Camera or not Camera.Parent then
        Camera = Workspace.CurrentCamera
        return
    end
    local camPos = Camera.CFrame.Position
    local activePlayers = {}

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local char = pl.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local dist = (camPos - hrp.Position).Magnitude
                    if dist <= 3000 then
                        activePlayers[pl] = true
                        local criminal = isCriminal(pl)
                        local hl = getHighlight(pl, char)
                        if CrimeESPEnabled and criminal then
                            hl.Enabled = true
                            hl.FillColor = Color3.fromRGB(255, 30, 30)
                            hl.OutlineColor = Color3.fromRGB(255, 30, 30)
                            hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0
                        else
                            hl.Enabled = false
                        end
                        local showInfo = ESPEnabled or (CrimeESPEnabled and criminal)
                        if showInfo then
                            local bb = getBillboard(pl, char)
                            bb.Enabled = true
                            local mainLabel = bb:FindFirstChild("MainText")
                            local hpLabel = bb:FindFirstChild("HPText")
                            if mainLabel then
                                mainLabel.Text = pl.Name .. " [" .. getProfession(pl) .. "]"
                                mainLabel.TextColor3 = criminal
                                    and Color3.fromRGB(255, 80, 80)
                                    or getTeamColor(pl)
                            end
                            if hpLabel then
                                hpLabel.Text = string.format("HP:%.0f", hum.Health)
                            end
                        else
                            if ESPBillboards[pl] then ESPBillboards[pl].Enabled = false end
                        end
                    else
                        if ESPHighlights[pl] then ESPHighlights[pl].Enabled = false end
                        if ESPBillboards[pl] then ESPBillboards[pl].Enabled = false end
                    end
                else
                    if ESPHighlights[pl] then ESPHighlights[pl].Enabled = false end
                    if ESPBillboards[pl] then ESPBillboards[pl].Enabled = false end
                end
            end
        end
    end

    for pl in pairs(ESPHighlights) do
        if not activePlayers[pl] then cleanupPlayerESP(pl) end
    end
    for pl in pairs(ESPBillboards) do
        if not activePlayers[pl] then cleanupPlayerESP(pl) end
    end
end

-- ============================================================
-- WindUI 窗口
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "顾琼 辅助",
    Icon = "zap",
    Author = "GU",
    Folder = "GuQiong",
    Size = UDim2.fromOffset(580, 420),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 180,
    Background = "",
})

local MainTab     = Window:Tab({ Title = "主要功能", Icon = "sliders-h" })
local MoneyTab    = Window:Tab({ Title = "刷钱",     Icon = "money-bill-wave" })
local PurchaseTab = Window:Tab({ Title = "远程购买", Icon = "cart-shopping" })
local RemoteBuyTab= Window:Tab({ Title = "远程买枪", Icon = "gun" })
local GrabTab     = Window:Tab({ Title = "抓取",     Icon = "hand" })

-- ============================================================
-- UI 内容
-- ============================================================
MainTab:Toggle({
    Title = "犯罪透视",
    Desc = "高亮显示通缉犯",
    Default = false,
    Callback = function(v) CrimeESPEnabled = v end,
})

MainTab:Toggle({
    Title = "玩家透视",
    Desc = "显示所有玩家信息",
    Default = false,
    Callback = function(v) ESPEnabled = v end,
})

MoneyTab:Toggle({
    Title = "自动工具",
    Default = false,
    Callback = function(v) setAutoTool(v) end,
})

-- ★ 新功能
MoneyTab:Toggle({
    Title = "无限车辆耐久",
    Desc = "当前开的车耐久永远满",
    Default = false,
    Callback = function(v) InfVehicleHPEnabled = v end,
})

MoneyTab:Toggle({
    Title = "自动捡钱",
    Desc = "自动靠近并捡起附近的现金",
    Default = false,
    Callback = function(v) AutoPickupEnabled = v end,
})

MoneyTab:Slider({
    Title = "捡钱范围",
    Value = { Min = 5, Max = 120, Default = 30 },
    Step = 5,
    Callback = function(v) autoPickupRange = v end,
})

-- 远程购买 UI
local purchaseItems = getMarketItems()
local purchaseNames = {}
for _, v in ipairs(purchaseItems) do
    table.insert(purchaseNames, v.name)
end

local selectedItem = nil

if #purchaseNames > 0 then
    selectedItem = purchaseNames[1]
    PurchaseTab:Dropdown({
        Title = "选择物品",
        Values = purchaseNames,
        Default = purchaseNames[1],
        Callback = function(v) selectedItem = v end,
    })
else
    PurchaseTab:Paragraph({
        Title = "未找到物品",
        Desc = "请检查 Stuff 目录是否存在",
    })
end

local purchaseCount = 1
PurchaseTab:Slider({
    Title = "购买数量",
    Value = { Min = 1, Max = 20, Default = 1 },
    Step = 1,
    Callback = function(v) purchaseCount = v end,
})

PurchaseTab:Button({
    Title = "购买当前选中",
    Callback = function()
        if not selectedItem then return end
        local success = 0
        for i = 1, purchaseCount do
            if purchaseItem(selectedItem) then
                success = success + 1
            end
            task.wait(0.1)
        end
        print(string.format("[购买] %s 成功 %d/%d", selectedItem, success, purchaseCount))
    end,
})

PurchaseTab:Button({
    Title = "一键购买全部",
    Callback = function()
        local items = getMarketItems()
        if #items == 0 then return end
        local okCount = 0
        for _, v in ipairs(items) do
            if purchaseItem(v.name) then
                okCount = okCount + 1
            end
            task.wait(0.1)
        end
        print(string.format("[购买] 全部购买完成 %d/%d", okCount, #items))
    end,
})

PurchaseTab:Button({
    Title = "刷新物品列表",
    Callback = function()
        purchaseItems = getMarketItems()
        purchaseNames = {}
        for _, v in ipairs(purchaseItems) do
            table.insert(purchaseNames, v.name)
        end
        print(string.format("[购买] 已刷新，共 %d 个物品", #purchaseNames))
    end,
})

-- 远程买枪 UI
findWeapons()
local weaponDisplayNames = buildWeaponNames()
local selectedWeaponDisplay = nil

for _, name in ipairs(weaponDisplayNames) do
    if name == K_GLOCK or name:find(K_GLOCK, 1, true) then
        selectedWeaponDisplay = name
        break
    end
end
if not selectedWeaponDisplay and #weaponDisplayNames > 0 then
    selectedWeaponDisplay = weaponDisplayNames[1]
end

if #weaponDisplayNames > 0 then
    RemoteBuyTab:Dropdown({
        Title = "选择武器",
        Values = weaponDisplayNames,
        Default = selectedWeaponDisplay,
        Callback = function(v) selectedWeaponDisplay = v end,
    })
else
    RemoteBuyTab:Paragraph({
        Title = "未找到武器",
        Desc = "请检查 Stuff/Weapons 是否存在",
    })
end

local remoteBuyCount = 1
RemoteBuyTab:Slider({
    Title = "购买数量",
    Value = { Min = 1, Max = 20, Default = 1 },
    Step = 1,
    Callback = function(v) remoteBuyCount = v end,
})

RemoteBuyTab:Button({
    Title = "购买当前选中",
    Callback = function()
        local entry = findEntryByDisplay(selectedWeaponDisplay)
        if not entry then return end
        local success = 0
        for i = 1, remoteBuyCount do
            local ok, msg = purchaseWeapon(entry)
            if ok then success = success + 1 end
            if msg then print("[远程买枪] " .. msg) end
            task.wait(0.1)
        end
        print(string.format("[远程买枪] %s 成功 %d/%d", entry.name, success, remoteBuyCount))
    end,
})

RemoteBuyTab:Button({
    Title = "一键购买全部武器",
    Callback = function()
        if #weaponEntries == 0 then return end
        local okCount = 0
        for _, entry in ipairs(weaponEntries) do
            local ok, msg = purchaseWeapon(entry)
            if ok then okCount = okCount + 1 end
            if msg then print("[远程买枪] " .. msg) end
            task.wait(0.1)
        end
        print(string.format("[远程买枪] 全部购买完成 %d/%d", okCount, #weaponEntries))
    end,
})

RemoteBuyTab:Button({
    Title = "刷新武器列表",
    Callback = function()
        findWeapons()
        weaponDisplayNames = buildWeaponNames()
        print(string.format("[远程买枪] 已刷新，共 %d 把武器", #weaponDisplayNames))
    end,
})

RemoteBuyTab:Divider()

-- 抓取 UI
GrabTab:Toggle({
    Title = "开启抓取",
    Desc = "开启后弹出独立悬浮窗，按住左键抓取部件",
    Default = false,
    Callback = function(v)
        grabSetEnabled(v)
        if v then
            grabBuildWindow()
            if grabWindow then grabWindow.Visible = true end
        end
        grabUpdateToggleVisual()
        grabUpdateStatus()
    end,
})

GrabTab:Button({
    Title = "显示/隐藏悬浮窗",
    Callback = function()
        if not grabWindow then
            grabBuildWindow()
        end
        if grabWindow then
            grabWindow.Visible = not grabWindow.Visible
        end
    end,
})

-- ============================================================
-- 关闭
-- ============================================================
local function unload()
    if Unloaded then return end
    Unloaded = true

    if AutoToolEnabled then setAutoTool(false) end
    InfVehicleHPEnabled = false
    AutoPickupEnabled = false
    grabSetEnabled(false)

    if grabWindow then
        pcall(function()
            local gui = grabWindow.Parent
            grabWindow:Destroy()
            grabWindow = nil
            if gui then gui:Destroy() end
        end)
    end

    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    for pl, _ in pairs(ESPHighlights) do cleanupPlayerESP(pl) end
    for pl, _ in pairs(ESPBillboards) do cleanupPlayerESP(pl) end
    ESPHighlights = {}
    ESPBillboards = {}

    if Window then
        pcall(function() Window:Destroy() end)
        Window = nil
    end

    print("[GQ] unloaded")
end

_G.GUQIONG_Unload = unload

-- ============================================================
-- 热键
-- ============================================================
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or Unloaded then return end
    if UserInputService:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.F1 then
        CrimeESPEnabled = not CrimeESPEnabled
    elseif input.KeyCode == Enum.KeyCode.F2 then
        setAutoTool(not AutoToolEnabled)
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ESPEnabled = not ESPEnabled
    elseif input.KeyCode == Enum.KeyCode.F4 then
        unload()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        InfVehicleHPEnabled = not InfVehicleHPEnabled
    elseif input.KeyCode == Enum.KeyCode.F6 then
        AutoPickupEnabled = not AutoPickupEnabled
    elseif input.KeyCode == Enum.KeyCode.F12 then
        grabSetEnabled(not GrabEnabled)
        if GrabEnabled then
            grabBuildWindow()
            if grabWindow then grabWindow.Visible = true end
        end
        grabUpdateToggleVisual()
        grabUpdateStatus()
    end
end))

-- ============================================================
-- 主循环
-- ============================================================
local frameCounter = 0
table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    if Unloaded then return end

    frameCounter = frameCounter + 1
    if frameCounter % 2 == 0 then
        pcall(updateESP)
    end

    pcall(grabUpdateStatus)
end))

print("[GQ] loaded")