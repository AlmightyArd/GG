--[[
    Auto Follow Enemy (Tower Defense)
    Dibuat dari data remote Cobalt:
      CreateEntity      (context, name, data)        -> musuh spawn
      EnemyDistanceSync (context, buffer)            -> [u32 ID][f32 Distance] per 8 byte
      EnemyHPBatch      (context, buffer)            -> [u32 ID][f64 HP][u8 flag] per 13 byte
      Entity_UpdateHP   (context, id, hp | nil)      -> hp nil = mati
      DestroyEntity     (context, id)                -> musuh dihapus

    Tekan tombol TOGGLE_KEY untuk nyalakan / matikan.
]]

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local CONFIG = {
    Enabled      = true,
    ToggleKey    = Enum.KeyCode.F,

    -- "First"     = musuh paling depan (DistanceTravelled terbesar)
    -- "Last"      = musuh paling belakang
    -- "Nearest"   = musuh terdekat dari karakter
    -- "Weakest"   = HP paling kecil
    -- "Strongest" = HP paling besar
    TargetMode   = "First",

    -- "Walk"     = Humanoid:MoveTo (paling aman)
    -- "Teleport" = set CFrame HumanoidRootPart
    -- "Camera"   = hanya kamera yang mengikuti
    FollowMode   = "Walk",

    -- Walk: kalau jarak ke musuh lebih dari ini, langsung teleport ke dekatnya
    -- lalu lanjut jalan. Isi math.huge untuk mematikan teleport.
    TeleportDistance = 40,
    TeleportCooldown = 0.5,                -- jeda minimal antar teleport (detik)

    Offset       = Vector3.new(0, 0, 4),   -- posisi relatif terhadap musuh (Walk/Teleport)
    StopDistance = 3,                      -- Walk: berhenti kalau sudah sedekat ini
    CameraOffset = Vector3.new(0, 12, 14), -- Camera mode

    NamePrefix   = "enemy_",  -- hanya entity dengan nama berawalan ini
    TeamIndex    = nil,       -- isi angka (mis. 2) untuk filter team, nil = semua
    OnlyContext  = nil,       -- isi nama context (UUID) untuk filter, nil = semua

    MatchRadius  = 15,        -- radius pencocokan model dengan CF spawn
    Debug        = false,
}

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Remotes     = ReplicatedStorage:WaitForChild("RemoteEvents")

-- bersihkan instance script sebelumnya kalau di-execute ulang
local env = (getgenv and getgenv()) or _G
if env.__AutoFollowEnemy then
    for _, c in ipairs(env.__AutoFollowEnemy) do
        pcall(function() c:Disconnect() end)
    end
end
local connections = {}
env.__AutoFollowEnemy = connections

local function log(...)
    if CONFIG.Debug then print("[AutoFollow]", ...) end
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
-- Enemies[id] = { ID, Name, Context, Speed, Health, MaxHealth, PathIndex,
--                 Distance, LastSync, SpawnCF, Model }
local Enemies = {}

local function contextAllowed(context)
    if not CONFIG.OnlyContext then return true end
    return typeof(context) == "Instance" and context.Name == CONFIG.OnlyContext
end

---------------------------------------------------------------------
-- PENCOCOKAN MODEL (ID entity -> Model di workspace)
---------------------------------------------------------------------
local recentModels = {} -- { {model = Model, t = os.clock(), claimed = bool} }

local function onDescendantAdded(inst)
    if not inst:IsA("Model") then return end
    if inst:FindFirstAncestorOfClass("Model") then return end -- abaikan sub-model
    if Players:GetPlayerFromCharacter(inst) then return end
    table.insert(recentModels, { model = inst, t = os.clock(), claimed = false })
end
table.insert(connections, workspace.DescendantAdded:Connect(onDescendantAdded))

local function pruneRecent()
    local now = os.clock()
    for i = #recentModels, 1, -1 do
        local r = recentModels[i]
        if r.claimed or now - r.t > 6 or not r.model.Parent then
            table.remove(recentModels, i)
        end
    end
end

local function findModelFor(enemy)
    local spawnPos = enemy.SpawnCF and enemy.SpawnCF.Position
    for _ = 1, 20 do -- coba selama ~2 detik
        if not Enemies[enemy.ID] then return end

        local best, bestDist
        for _, r in ipairs(recentModels) do
            local m = r.model
            if not r.claimed and m.Parent then
                -- cocok langsung lewat nama / attribute kalau game menyediakannya
                if m.Name == tostring(enemy.ID)
                    or m:GetAttribute("ID") == enemy.ID
                    or m:GetAttribute("EntityID") == enemy.ID then
                    best, bestDist = r, 0
                    break
                end
                if spawnPos then
                    local ok, pivot = pcall(m.GetPivot, m)
                    if ok then
                        local d = (pivot.Position - spawnPos).Magnitude
                        if d <= CONFIG.MatchRadius and (not bestDist or d < bestDist) then
                            best, bestDist = r, d
                        end
                    end
                end
            end
        end

        if best then
            best.claimed = true
            enemy.Model = best.model
            log("Model ditemukan untuk ID", enemy.ID, best.model:GetFullName())
            pruneRecent()
            return
        end
        task.wait(0.1)
    end
    log("Model TIDAK ditemukan untuk ID", enemy.ID)
    pruneRecent()
end

---------------------------------------------------------------------
-- REMOTE HANDLERS
---------------------------------------------------------------------
local function removeEnemy(id)
    if Enemies[id] then
        Enemies[id] = nil
        log("Hapus", id)
    end
end

table.insert(connections, Remotes:WaitForChild("CreateEntity").OnClientEvent:Connect(function(context, name, data)
    if type(name) ~= "string" or type(data) ~= "table" or not data.ID then return end
    if name:sub(1, #CONFIG.NamePrefix) ~= CONFIG.NamePrefix then return end
    if CONFIG.TeamIndex and data.TeamIndex ~= CONFIG.TeamIndex then return end
    if not contextAllowed(context) then return end

    local enemy = {
        ID        = data.ID,
        Name      = name,
        Context   = context,
        Speed     = data.Speed or 0,
        Health    = data.Health or data.MaxHealth or 0,
        MaxHealth = data.MaxHealth or data.Health or 0,
        PathIndex = data.PathIndex,
        Distance  = data.DistanceTravelled or 0,
        LastSync  = os.clock(),
        SpawnCF   = data.CF,
        Model     = nil,
    }
    Enemies[enemy.ID] = enemy
    log("Spawn", name, enemy.ID)
    task.spawn(findModelFor, enemy)
end))

-- buffer: [u32 ID][f32 Distance] berulang
table.insert(connections, Remotes:WaitForChild("EnemyDistanceSync").OnClientEvent:Connect(function(_, buf)
    if typeof(buf) ~= "buffer" then return end
    local now = os.clock()
    for offset = 0, buffer.len(buf) - 8, 8 do
        local enemy = Enemies[buffer.readu32(buf, offset)]
        if enemy then
            enemy.Distance = buffer.readf32(buf, offset + 4)
            enemy.LastSync = now
        end
    end
end))

-- buffer: [u32 ID][f64 HP][u8 flag] berulang
table.insert(connections, Remotes:WaitForChild("EnemyHPBatch").OnClientEvent:Connect(function(_, buf)
    if typeof(buf) ~= "buffer" then return end
    for offset = 0, buffer.len(buf) - 13, 13 do
        local id = buffer.readu32(buf, offset)
        local hp = buffer.readf64(buf, offset + 4)
        local enemy = Enemies[id]
        if enemy then
            enemy.Health = hp
            if hp <= 0 then removeEnemy(id) end
        end
    end
end))

table.insert(connections, Remotes:WaitForChild("Entity_UpdateHP").OnClientEvent:Connect(function(_, id, hp)
    local enemy = Enemies[id]
    if not enemy then return end
    if hp == nil or hp <= 0 then
        removeEnemy(id) -- hp nil = mati
    else
        enemy.Health = hp
    end
end))

table.insert(connections, Remotes:WaitForChild("DestroyEntity").OnClientEvent:Connect(function(_, id)
    removeEnemy(id)
end))

---------------------------------------------------------------------
-- TARGETING
---------------------------------------------------------------------
local function estimatedDistance(enemy)
    -- interpolasi di antara dua sync
    return enemy.Distance + enemy.Speed * (os.clock() - enemy.LastSync)
end

local function enemyPosition(enemy)
    local m = enemy.Model
    if m and m.Parent then
        local ok, pivot = pcall(m.GetPivot, m)
        if ok then return pivot.Position end
    end
    return nil
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function pickTarget()
    local root = getRoot()
    local best, bestScore
    for _, enemy in pairs(Enemies) do
        local pos = enemyPosition(enemy)
        if pos then
            local score
            if CONFIG.TargetMode == "First" then
                score = estimatedDistance(enemy)
            elseif CONFIG.TargetMode == "Last" then
                score = -estimatedDistance(enemy)
            elseif CONFIG.TargetMode == "Nearest" then
                score = root and -(root.Position - pos).Magnitude or 0
            elseif CONFIG.TargetMode == "Weakest" then
                score = -enemy.Health
            elseif CONFIG.TargetMode == "Strongest" then
                score = enemy.Health
            else
                score = estimatedDistance(enemy)
            end
            if not bestScore or score > bestScore then
                best, bestScore = enemy, score
            end
        end
    end
    return best
end

---------------------------------------------------------------------
-- FOLLOW LOOP
---------------------------------------------------------------------
local currentTarget
local lastTeleport = 0

table.insert(connections, RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then return end

    local target = pickTarget()
    if target ~= currentTarget then
        currentTarget = target
        if target then log("Target:", target.Name, target.ID) end
    end
    if not target then return end

    local pos = enemyPosition(target)
    if not pos then return end

    if CONFIG.FollowMode == "Camera" then
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.new(pos + CONFIG.CameraOffset, pos)
        end
        return
    end

    local root, hum = getRoot()
    if not root or not hum or hum.Health <= 0 then return end
    local goal = pos + CONFIG.Offset

    local function teleportToGoal()
        root.CFrame = CFrame.new(Vector3.new(goal.X, root.Position.Y, goal.Z), Vector3.new(pos.X, root.Position.Y, pos.Z))
    end

    if CONFIG.FollowMode == "Teleport" then
        teleportToGoal()
    else -- Walk (+ teleport kalau terlalu jauh)
        local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
        local now = os.clock()
        if flat.Magnitude > CONFIG.TeleportDistance and now - lastTeleport >= CONFIG.TeleportCooldown then
            lastTeleport = now
            teleportToGoal()
            log("Teleport ke target, jarak", math.floor(flat.Magnitude))
        elseif flat.Magnitude > CONFIG.StopDistance then
            hum:MoveTo(goal)
        end
    end
end))

---------------------------------------------------------------------
-- TOGGLE
---------------------------------------------------------------------
local refreshUI = function() end

local function resetCamera()
    local cam = workspace.CurrentCamera
    if cam and cam.CameraType == Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Custom
    end
end

local function setEnabled(state)
    CONFIG.Enabled = state
    if not state then
        currentTarget = nil
        resetCamera()
        local _, hum = getRoot()
        local root = getRoot()
        if hum and root then hum:MoveTo(root.Position) end -- berhenti jalan
    end
    refreshUI()
    print("[AutoFollow] " .. (state and "ON" or "OFF"))
end

table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or input.KeyCode ~= CONFIG.ToggleKey then return end
    setEnabled(not CONFIG.Enabled)
end))

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
if env.__AutoFollowEnemyGui then
    pcall(function() env.__AutoFollowEnemyGui:Destroy() end)
end

local TARGET_MODES = { "First", "Last", "Nearest", "Weakest", "Strongest" }
local FOLLOW_MODES = { "Walk", "Teleport", "Camera" }

local function nextIn(list, current)
    local i = table.find(list, current) or 0
    return list[i % #list + 1]
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoFollowEnemy"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
env.__AutoFollowEnemyGui = gui

do
    local ok = pcall(function()
        gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function corner(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = inst
end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(210, 178)
frame.Position = UDim2.new(0, 20, 0.5, -89)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
corner(frame, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(235, 235, 240)
title.Text = "Auto Follow Enemy"
title.Parent = frame

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(24, 22)
minimize.Position = UDim2.new(1, -30, 0, 4)
minimize.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
minimize.BorderSizePixel = 0
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 14
minimize.TextColor3 = Color3.fromRGB(235, 235, 240)
minimize.Text = "-"
minimize.AutoButtonColor = true
minimize.Parent = frame
corner(minimize, 4)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -40)
body.Position = UDim2.fromOffset(10, 34)
body.BackgroundTransparency = 1
body.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

local function makeButton(order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.LayoutOrder = order
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(235, 235, 240)
    b.AutoButtonColor = true
    b.Parent = body
    corner(b, 6)
    return b
end

local toggleBtn = makeButton(1)
local targetBtn = makeButton(2)
local modeBtn   = makeButton(3)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 24)
status.LayoutOrder = 4
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.TextColor3 = Color3.fromRGB(160, 160, 170)
status.Text = "Musuh: 0"
status.Parent = body

refreshUI = function()
    toggleBtn.Text = CONFIG.Enabled and "Follow: ON" or "Follow: OFF"
    toggleBtn.BackgroundColor3 = CONFIG.Enabled
        and Color3.fromRGB(46, 160, 90)
        or  Color3.fromRGB(170, 60, 60)
    targetBtn.Text = "Target: " .. CONFIG.TargetMode
    modeBtn.Text   = "Mode: " .. CONFIG.FollowMode
end
refreshUI()

toggleBtn.MouseButton1Click:Connect(function()
    setEnabled(not CONFIG.Enabled)
end)

targetBtn.MouseButton1Click:Connect(function()
    CONFIG.TargetMode = nextIn(TARGET_MODES, CONFIG.TargetMode)
    refreshUI()
end)

modeBtn.MouseButton1Click:Connect(function()
    if CONFIG.FollowMode == "Camera" then resetCamera() end
    CONFIG.FollowMode = nextIn(FOLLOW_MODES, CONFIG.FollowMode)
    refreshUI()
end)

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = minimized and UDim2.fromOffset(210, 30) or UDim2.fromOffset(210, 178)
    minimize.Text = minimized and "+" or "-"
end)

-- drag (mouse & touch)
do
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

-- status: jumlah musuh + target saat ini
task.spawn(function()
    while gui.Parent do
        local count = 0
        for _ in pairs(Enemies) do count += 1 end
        local t = currentTarget
        if CONFIG.Enabled and t and Enemies[t.ID] then
            status.Text = ("Musuh: %d | %s #%d (%d HP)"):format(
                count, t.Name:gsub("^" .. CONFIG.NamePrefix, ""), t.ID, math.floor(t.Health))
        else
            status.Text = ("Musuh: %d"):format(count)
        end
        task.wait(0.25)
    end
end)

print(("[AutoFollow] Loaded. Mode=%s, Target=%s, Toggle=%s"):format(
    CONFIG.FollowMode, CONFIG.TargetMode, CONFIG.ToggleKey.Name))
