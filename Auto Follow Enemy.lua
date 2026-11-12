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
local Ignored = {}      -- ID yang sengaja difilter (prefix / team)
local ExistingById = {} -- model yang sudah ada sebelum script jalan (kalau bisa dikenali)
local Paths = {}        -- jalur yang dipelajari: Paths[key] = { {d = jarak, p = Vector3}, ... }
local seenContexts = {}
local announced = {}

local function once(key, ...)
    if announced[key] then return end
    announced[key] = true
    print("[AutoFollow]", ...)
end

-- Jalur dipelajari dari musuh yang modelnya ketemu: (jarak tempuh -> posisi).
-- Setelah itu posisi musuh lain bisa dihitung dari jarak tempuhnya saja.
local function pathFor(enemy, create)
    local ctx = typeof(enemy.Context) == "Instance" and enemy.Context.Name or "?"
    local key = ctx .. ":" .. tostring(enemy.PathIndex or 1)
    local path = Paths[key]
    if not path and create then
        path = {}
        Paths[key] = path
    end
    return path
end

local function recordPath(enemy)
    local m = enemy.Model
    if not (m and m.Parent) then return end
    local ok, pivot = pcall(m.GetPivot, m)
    if not ok then return end
    local path = pathFor(enemy, true)
    local last = path[#path]
    if not last or enemy.Distance > last.d + 0.5 then
        path[#path + 1] = { d = enemy.Distance, p = pivot.Position }
    end
end

local function pathPosition(enemy, dist)
    local path = pathFor(enemy, false)
    if not path or #path == 0 then return nil end
    if dist <= path[1].d then return path[1].p end
    if dist > path[#path].d then return nil end -- bagian jalur ini belum dipelajari
    local lo, hi = 1, #path
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if path[mid].d <= dist then lo = mid else hi = mid end
    end
    local a, b = path[lo], path[hi]
    local t = (dist - a.d) / math.max(b.d - a.d, 1e-6)
    return a.p:Lerp(b.p, t)
end

-- Dijalankan sekali per context: cetak isinya (untuk diagnosa) dan
-- catat model yang bisa dikenali lewat nama angka / attribute ID.
local function inspectContext(context)
    if typeof(context) ~= "Instance" or seenContexts[context] then return end
    seenContexts[context] = true
    print("[AutoFollow] Context: " .. context:GetFullName())
    for i, child in ipairs(context:GetChildren()) do
        if i > 25 then print("   ...") break end
        print(("   %s [%s] anak=%d"):format(child.Name, child.ClassName, #child:GetChildren()))
    end
    for _, inst in ipairs(context:GetDescendants()) do
        if inst:IsA("Model") then
            local id = inst:GetAttribute("ID") or inst:GetAttribute("EntityID") or tonumber(inst.Name)
            if type(id) == "number" then ExistingById[id] = inst end
        end
    end
end

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
            once("found", "Model musuh ketemu, contoh: " .. best.model:GetFullName())
            pruneRecent()
            return
        end
        task.wait(0.1)
    end
    once("notfound", "PERINGATAN: model untuk musuh ID " .. enemy.ID .. " (" .. enemy.Name .. ") tidak ketemu di workspace")
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
    if not contextAllowed(context) then return end
    if name:sub(1, #CONFIG.NamePrefix) ~= CONFIG.NamePrefix
        or (CONFIG.TeamIndex and data.TeamIndex ~= CONFIG.TeamIndex) then
        Ignored[data.ID] = true
        Enemies[data.ID] = nil
        return
    end
    Ignored[data.ID] = nil
    inspectContext(context)

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
    if typeof(data.CF) == "CFrame" then -- titik spawn = awal jalur
        local path = pathFor(enemy, true)
        if #path == 0 then path[1] = { d = enemy.Distance, p = data.CF.Position } end
    end
    task.spawn(findModelFor, enemy)
end))

-- buffer: [u32 ID][f32 Distance] berulang
table.insert(connections, Remotes:WaitForChild("EnemyDistanceSync").OnClientEvent:Connect(function(context, buf)
    if typeof(buf) ~= "buffer" then return end
    if not contextAllowed(context) then return end
    inspectContext(context)
    local now = os.clock()
    for offset = 0, buffer.len(buf) - 8, 8 do
        local id = buffer.readu32(buf, offset)
        local dist = buffer.readf32(buf, offset + 4)
        local enemy = Enemies[id]
        if enemy then
            local dt = now - enemy.LastSync
            if enemy.Placeholder and dt > 0.05 and dist > enemy.Distance then
                enemy.Speed = (dist - enemy.Distance) / dt -- speed tidak diketahui, hitung sendiri
            end
            enemy.Distance = dist
            enemy.LastSync = now
            recordPath(enemy)
        elseif not Ignored[id] then
            -- musuh yang sudah spawn sebelum script dijalankan (CreateEntity terlewat)
            Enemies[id] = {
                ID = id, Name = CONFIG.NamePrefix .. "unknown", Context = context,
                Speed = 0, Health = 0, MaxHealth = 0, PathIndex = nil,
                Distance = dist, LastSync = now,
                Model = ExistingById[id], Placeholder = true,
            }
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
    -- tidak ada model: hitung dari jarak tempuh di jalur yang sudah dipelajari
    return pathPosition(enemy, estimatedDistance(enemy))
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function pickTarget()
    local root = getRoot()
    local best, bestScore
    for id, enemy in pairs(Enemies) do
        if enemy.Placeholder and os.clock() - enemy.LastSync > 10 then
            Enemies[id] = nil -- tidak ada sync lagi, anggap sudah hilang
            continue
        end
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
        local root, hum = getRoot()
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
-- UI (simple: satu tombol toggle, bisa digeser)
---------------------------------------------------------------------
if env.__AutoFollowEnemyGui then
    pcall(function() env.__AutoFollowEnemyGui:Destroy() end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoFollowEnemy"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
gui.Enabled = true
env.__AutoFollowEnemyGui = gui

-- PlayerGui dulu (paling pasti tampil), baru gethui / CoreGui sebagai cadangan
local function tryParent(getParent)
    local ok = pcall(function() gui.Parent = getParent() end)
    return ok and gui.Parent ~= nil
end
local parented = tryParent(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    or tryParent(function() return gethui() end)
    or tryParent(function() return game:GetService("CoreGui") end)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "Toggle"
toggleBtn.Size = UDim2.fromOffset(180, 50)
toggleBtn.Position = UDim2.new(0, 20, 0.4, 0)
toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = false
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 16
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.ZIndex = 10
toggleBtn.Parent = gui

refreshUI = function()
    local total, located = 0, 0
    for _, enemy in pairs(Enemies) do
        total += 1
        if enemyPosition(enemy) then located += 1 end
    end
    toggleBtn.Text = ("Auto Follow: %s\nMusuh %d | Posisi ketemu %d"):format(
        CONFIG.Enabled and "ON" or "OFF", total, located)
    toggleBtn.BackgroundColor3 = CONFIG.Enabled
        and Color3.fromRGB(46, 160, 90)
        or  Color3.fromRGB(170, 60, 60)
end
refreshUI()

-- klik = toggle, tahan lalu geser = pindahkan tombol
do
    local dragging, moved, dragStart, startPos
    toggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, toggleBtn.Position
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then moved = true end
            if moved then
                toggleBtn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if not moved then setEnabled(not CONFIG.Enabled) end
        end
    end))
end

task.spawn(function()
    while gui.Parent do
        refreshUI()
        task.wait(0.5)
    end
end)

print("[AutoFollow] UI v3: " .. (parented and gui:GetFullName() or "GAGAL dipasang"))
print(("[AutoFollow] Loaded. Mode=%s, Target=%s, Toggle=%s"):format(
    CONFIG.FollowMode, CONFIG.TargetMode, CONFIG.ToggleKey.Name))
