--[[
    Ard Hub Remote Logger — Universal (v1.0.0)
    Untuk game apa saja (GTD, DTD, dll.) dan script apa saja.
    Mencatat remote yang dikirim oleh SCRIPT executor (hub / script lain), dan bisa juga remote dari game.
    (Remote Spy biasa mengabaikan panggilan dari executor, jadi remote dari hub tidak terlihat di sana.)

    Cara pakai: jalankan script ini DULU, lalu jalankan script / hub yang ingin dilihat remote-nya.
    - Sumber: "Script" (hanya dari executor / Ard Hub) atau "Semua" (termasuk dari game).
    - Salin: menyalin log sebagai script Lua siap pakai (dengan sumber, jam, dan balasan server).
    - Log disimpan ke workspace/ArdHub/remote_logger_<PlaceId>.txt (dipisah per game) dan disambung saat dijalankan ulang.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.__ArdRemoteLoggerU then pcall(env.__ArdRemoteLoggerU) end
local running = true
local conns = {}

local MAX = 300
local LOG_FILE = "ArdHub/remote_logger_" .. tostring(game.PlaceId) .. ".txt"
-- remote yang tidak dicatat (biasanya laporan statistik / ping yang terkirim terus-menerus)
local IGNORE = { StatsEvent = true, Ping = true, Heartbeat = true, MouseMove = true }
local Opt = { source = "Script", paused = false }
local list = {}
local dirty, uiDirty = false, true

-- label sumber: "Script" untuk executor, atau nama LocalScript game yang memanggil (kalau executor mendukung)
local function callerLabel(fromScript)
    if fromScript then return "Script" end
    if getcallingscript then
        local ok, sc = pcall(getcallingscript)
        if ok and typeof(sc) == "Instance" then return "Game:" .. sc.Name end
    end
    return "Game"
end

---------------------------------------------------------------------
-- format
---------------------------------------------------------------------
local function luaValue(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
    if t == "Vector3" then return string.format("Vector3.new(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z) end
    if t == "Vector2" then return string.format("Vector2.new(%.3f, %.3f)", v.X, v.Y) end
    if t == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")" end
    if t == "EnumItem" then return tostring(v) end
    if t == "buffer" then return "buffer(" .. tostring(buffer.len(v)) .. ")" end
    if t == "Instance" then
        local ok, full = pcall(function() return v:GetFullName() end)
        if not ok then return "nil --[[Instance]]" end
        if full:match("^Workspace%.") then return "workspace" .. full:sub(10) end
        if v.Parent == nil then return "nil --[[" .. v.Name .. ", tanpa parent]]" end
        return "game." .. full
    end
    if t == "table" then
        if depth > 1 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 8 then parts[#parts + 1] = "..." break end
            local key = type(k) == "number" and "" or (tostring(k) .. " = ")
            parts[#parts + 1] = key .. luaValue(x, depth + 1)
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return tostring(v)
end
local function argsText(pack, from)
    local out = {}
    for i = from or 1, pack.n do out[#out + 1] = luaValue(pack[i]) end
    return table.concat(out, ", ")
end
local function pathOf(r)
    local ok, full = pcall(function() return r:GetFullName() end)
    if not ok then return "nil" end
    local svc = full:match("^([^%.]+)")
    return 'game:GetService("' .. svc .. '")' .. full:sub(#svc + 1)
end
local function lineText(e, asScript)
    local cnt = e.count > 1 and (" x" .. e.count) or ""
    if asScript then
        return string.format("%s:%s(%s) -- %s · %s%s%s", e.path, e.method, e.args, e.feature, e.time, cnt,
            e.reply and (" · balasan: " .. e.reply) or "")
    end
    return string.format("[%s] %s · %s(%s)%s%s", e.time, e.feature, e.name, e.args, e.reply and (" → " .. e.reply) or "", cnt)
end

---------------------------------------------------------------------
-- pencatat
---------------------------------------------------------------------
local function record(remote, method, args, results, fromScript, label)
    if not running or Opt.paused then return end
    local okN, name = pcall(function() return remote.Name end)
    if not okN or IGNORE[name] then return end
    if Opt.source == "Script" and not fromScript then return end
    local a = argsText(args)
    local reply = nil
    if results then reply = results.n > 0 and argsText(results) or "(kosong)" end
    local last = list[#list]
    if last and last.name == name and last.args == a and last.reply == reply then
        last.count = last.count + 1
        last.time = os.date("%H:%M:%S")
    else
        list[#list + 1] = {
            time = os.date("%H:%M:%S"), name = name, method = method, args = a, reply = reply, count = 1,
            path = pathOf(remote), feature = label or (fromScript and "Script" or "Game"),
        }
        if #list > MAX then table.remove(list, 1) end
    end
    dirty, uiDirty = true, true
end
local wrap = newcclosure or function(f) return f end
local hookCount = 0
local inNamecall = setmetatable({}, { __mode = "k" })
local function pass(old, self, method, fromScript, ...)
    local label = nil
    if not (Opt.source == "Script" and not fromScript) then label = callerLabel(fromScript) end
    if method == "InvokeServer" then
        local args = table.pack(...)
        local results = table.pack(old(self, ...))
        task.spawn(record, self, method, args, results, fromScript, label)
        return table.unpack(results, 1, results.n)
    end
    task.spawn(record, self, method, table.pack(...), nil, fromScript, label)
    return old(self, ...)
end
local function finish(co, ...)
    inNamecall[co] = nil
    return ...
end
-- remote:FireServer(...) / remote:InvokeServer(...)
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
            if running then
                local method = getnamecallmethod()
                if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
                    local fromScript = checkcaller and checkcaller() or false
                    local co = coroutine.running()
                    inNamecall[co] = true
                    return finish(co, pass(old, self, method, fromScript, ...))
                end
            end
            return old(self, ...)
        end))
        if old then hookCount = hookCount + 1 end
    end)
end
-- pcall(remote.InvokeServer, remote, ...) — cara Ard Hub memanggil remote (tidak lewat namecall)
if hookfunction then
    for _, cls in ipairs({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" }) do
        local okI, inst = pcall(function() return Instance.new(cls) end)
        if okI and inst then
            for _, method in ipairs({ "FireServer", "InvokeServer" }) do
                pcall(function()
                    local old
                    old = hookfunction(inst[method], wrap(function(self, ...)
                        if running and not inNamecall[coroutine.running()] and typeof(self) == "Instance" then
                            return pass(old, self, method, checkcaller and checkcaller() or false, ...)
                        end
                        return old(self, ...)
                    end))
                    if old then hookCount = hookCount + 1 end
                end)
            end
        end
    end
end
-- simpan / muat
local function scriptText()
    local out = { string.format("-- Remote log · PlaceId %s · %s", tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S")) }
    for _, e in ipairs(list) do out[#out + 1] = lineText(e, true) end
    return table.concat(out, "\n")
end
local previous = nil
pcall(function()
    if isfile and isfile(LOG_FILE) then previous = readfile(LOG_FILE) end
end)
task.spawn(function()
    while running do
        task.wait(5)
        if dirty and writefile then
            dirty = false
            pcall(function()
                if makefolder and isfolder and not isfolder("ArdHub") then makefolder("ArdHub") end
                local body = scriptText()
                if previous and previous ~= "" then body = previous .. "\n-- ---\n" .. body end
                writefile(LOG_FILE, body)
            end)
        end
    end
end)

---------------------------------------------------------------------
-- tampilan
---------------------------------------------------------------------
local T = {
    bg = Color3.fromRGB(15, 23, 42), alt = Color3.fromRGB(30, 41, 59), line = Color3.fromRGB(51, 65, 85),
    ink = Color3.fromRGB(248, 250, 252), muted = Color3.fromRGB(203, 213, 225), brand = Color3.fromRGB(167, 139, 250),
}
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end
local function corner(p, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
pcall(function()
    for _, p in ipairs({ game:GetService("CoreGui"), LocalPlayer:FindFirstChild("PlayerGui"), gethui and gethui() }) do
        local o = p and p:FindFirstChild("ArdRemoteLoggerU")
        if o then o:Destroy() end
    end
end)
local gui = new("ScreenGui", { Name = "ArdRemoteLoggerU", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true })
do
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
local win = new("Frame", {
    Size = UDim2.new(0, 420, 0, 320), Position = UDim2.new(0, 20, 1, -340),
    BackgroundColor3 = T.bg, BorderSizePixel = 0, Active = true, Parent = gui,
})
corner(win, 12)
new("UIStroke", { Color = T.line, Thickness = 1, Parent = win })
local top = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Active = true, Parent = win })
new("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
    Text = "Remote Logger · Universal", TextColor3 = T.ink, Font = Enum.Font.GothamBold, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
})
local closeBtn = new("TextButton", {
    Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -30, 0, 4), BackgroundColor3 = T.alt, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "X", TextColor3 = T.muted, Font = Enum.Font.GothamBold, TextSize = 12, Parent = top,
})
corner(closeBtn, 6)
local function btn(text, x, w)
    local b = new("TextButton", {
        Size = UDim2.new(0, w, 0, 28), Position = UDim2.new(0, x, 0, 36), BackgroundColor3 = T.alt, BorderSizePixel = 0,
        AutoButtonColor = false, Text = text, TextColor3 = T.ink, Font = Enum.Font.GothamBold, TextSize = 12, Parent = win,
    })
    corner(b, 7)
    return b
end
local srcBtn = btn("Sumber: Script", 12, 120)
local pauseBtn = btn("Jeda", 138, 70)
local copyBtn = btn("Salin", 214, 90)
local clearBtn = btn("Bersih", 310, 98)
local hint = new("TextLabel", {
    Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 12, 0, 68), BackgroundTransparency = 1, Text = "",
    TextColor3 = T.muted, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = win,
})
local box = new("ScrollingFrame", {
    Size = UDim2.new(1, -24, 1, -96), Position = UDim2.new(0, 12, 0, 88), BackgroundColor3 = T.alt, BorderSizePixel = 0,
    ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win,
})
corner(box, 7)
local logText = new("TextLabel", {
    Size = UDim2.new(1, -10, 0, 0), Position = UDim2.new(0, 6, 0, 4), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Text = "", TextColor3 = T.ink, Font = Enum.Font.Code, TextSize = 11, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = box,
})
do -- geser jendela
    local dragging, start, startPos
    conns[#conns + 1] = top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, start, startPos = true, input.Position, win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - start
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
srcBtn.MouseButton1Click:Connect(function()
    Opt.source = Opt.source == "Script" and "Semua" or "Script"
    uiDirty = true
end)
pauseBtn.MouseButton1Click:Connect(function()
    Opt.paused = not Opt.paused
    uiDirty = true
end)
copyBtn.MouseButton1Click:Connect(function()
    if setclipboard and pcall(setclipboard, scriptText()) then
        hint.Text = "Disalin " .. #list .. " baris sebagai script"
    else
        hint.Text = "Executor tidak mendukung setclipboard"
    end
end)
clearBtn.MouseButton1Click:Connect(function()
    table.clear(list)
    previous = nil
    dirty, uiDirty = true, true
end)
task.spawn(function()
    while running do
        if uiDirty then
            uiDirty = false
            pcall(function()
                srcBtn.Text = "Sumber: " .. Opt.source
                pauseBtn.Text = Opt.paused and "Lanjut" or "Jeda"
                pauseBtn.BackgroundColor3 = Opt.paused and T.brand or T.alt
                pauseBtn.TextColor3 = Opt.paused and T.bg or T.ink
                hint.Text = string.format("%d baris · %s · hook %d%s", #list,
                    Opt.source == "Script" and "hanya remote dari script executor" or "remote dari script + game",
                    hookCount, hookCount == 0 and " (executor tidak mendukung hook)" or "")
                local lines = {}
                for i = math.max(#list - 120, 1), #list do lines[#lines + 1] = lineText(list[i], false) end
                logText.Text = #lines > 0 and table.concat(lines, "\n") or "Belum ada remote. Jalankan script / hub setelah logger ini."
                box.CanvasPosition = Vector2.new(0, math.huge)
            end)
        end
        task.wait(0.5)
    end
end)

local function stop()
    running = false
    for _, c in ipairs(conns) do pcall(c.Disconnect, c) end
    pcall(function() gui:Destroy() end)
end
env.__ArdRemoteLoggerU = stop
closeBtn.MouseButton1Click:Connect(stop)
