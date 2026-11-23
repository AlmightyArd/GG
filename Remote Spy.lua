--[[
    Ard Hub Remote Spy  (v1.2.0)
    Mencatat remote di game mana pun, untuk membantu membuat script.

    - KELUAR (HP -> server): FireServer / InvokeServer, lewat hook yang hanya MENCATAT lalu meneruskan
      panggilan asli apa adanya (jawaban server tidak disentuh). Panggilan dari executor sendiri tidak dicatat.
    - MASUK (server -> HP): OnClientEvent, tanpa hook.

    Cara pakai:
    - Ketuk satu baris, lalu tekan Salin: baris itu tersalin sebagai script siap pakai, LENGKAP dengan nilainya.
      FIRE    -> script mengirim remote itu dengan argumen yang sama.
      INVOKE  -> script mengirim remote itu + balasan server yang diterima saat direkam (Result).
      Masuk   -> script mendengarkan remote itu + isi data lengkap yang dikirim server.
    - Tanpa baris terpilih, Salin menyalin seluruh log (argumen + balasan setiap baris).
    - Tombol filter: Semua / Keluar / Masuk. Jeda: berhenti merekam sementara.
    - Remote yang sama yang terpanggil berturut-turut digabung jadi satu baris (xN), supaya log tidak penuh.
    - Log juga disimpan ke workspace/ArdHub/remote_spy.txt
    - Log tetap ada saat script dijalankan ulang (disimpan di workspace/ArdHub/remote_spy_log.json).
    - Tetap jalan setelah pindah server / teleport (mis. lobby -> match), kalau script ini disimpan
      sebagai file workspace/ArdHub/RemoteSpy.lua dan executor mendukung queue_on_teleport.
]]
local MAX_ROWS = 300          -- baris yang disimpan & ditampilkan
local HOOK_OUTGOING = true    -- false = hanya mencatat remote Masuk
local SELF_FILE = "ArdHub/RemoteSpy.lua"        -- file script ini, untuk dijalankan ulang otomatis setelah teleport
local LOG_FILE = "ArdHub/remote_spy_log.json"   -- log yang dipertahankan antar eksekusi / teleport
local IGNORE = {              -- nama remote yang tidak dicatat sama sekali (isi sesuai game)
    -- RecorderBatch = true,
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.__ArdRemoteSpy then pcall(env.__ArdRemoteSpy) end -- hentikan versi sebelumnya
local running = true
local paused = false

---------------------------------------------------------------------
-- tampilan singkat argumen (untuk baris log)
---------------------------------------------------------------------
local function ser(v, depth, seen)
    depth, seen = depth or 0, seen or {}
    local t = typeof(v)
    if t == "string" then
        if #v > 120 then v = v:sub(1, 120) .. "..." end
        return string.format("%q", v)
    end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
    if t == "Instance" then
        local ok, n = pcall(function() return v:GetFullName() end)
        return "<" .. (ok and n or "Instance") .. ">"
    end
    if t == "buffer" then return "buffer(" .. buffer.len(v) .. ")" end
    if t == "table" then
        if seen[v] then return "{...}" end
        if depth >= 3 then return "{..}" end
        seen[v] = true
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..." break end
            local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
            parts[#parts + 1] = key .. " = " .. ser(val, depth + 1, seen)
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return t .. "(" .. tostring(v) .. ")"
end
local function serArgs(packed)
    local out = {}
    for i = 1, packed.n do out[i] = ser(packed[i]) end
    return table.concat(out, ", ")
end

---------------------------------------------------------------------
-- pembuat script (Salin)
---------------------------------------------------------------------
local KEYWORDS = {
    ["and"] = 1, ["break"] = 1, ["do"] = 1, ["else"] = 1, ["elseif"] = 1, ["end"] = 1, ["false"] = 1, ["for"] = 1,
    ["function"] = 1, ["if"] = 1, ["in"] = 1, ["local"] = 1, ["nil"] = 1, ["not"] = 1, ["or"] = 1, ["repeat"] = 1,
    ["return"] = 1, ["then"] = 1, ["true"] = 1, ["until"] = 1, ["while"] = 1, ["continue"] = 1,
}
local PROPS = { Name = 1, Parent = 1, ClassName = 1, Archivable = 1 } -- nama anak yang bentrok dengan properti
local function index(name)
    if name:match("^[%a_][%w_]*$") and not KEYWORDS[name] and not PROPS[name] then return "." .. name end
    if PROPS[name] then return ":FindFirstChild(" .. string.format("%q", name) .. ")" end
    return "[" .. string.format("%q", name) .. "]"
end
-- Alamat instance sebagai kode Lua, mis. game:GetService("ReplicatedStorage").Remotes.BuyItem
local function pathOf(inst)
    if inst == game then return "game" end
    if inst == workspace then return "workspace" end
    local chain, cur = {}, inst
    while cur and cur ~= game do
        if cur == LocalPlayer then
            local s = 'game:GetService("Players").LocalPlayer'
            for i = #chain, 1, -1 do s = s .. index(chain[i].Name) end
            return s
        end
        if cur.Parent == game then
            local s = cur == workspace and "workspace" or ('game:GetService("' .. cur.ClassName .. '")')
            for i = #chain, 1, -1 do s = s .. index(chain[i].Name) end
            return s
        end
        chain[#chain + 1] = cur
        cur = cur.Parent
    end
    return nil -- tidak berada di dalam game (parent nil)
end
local function num(n)
    if n ~= n then return "0/0" end
    if n == math.huge then return "math.huge" end
    if n == -math.huge then return "-math.huge" end
    return tostring(n)
end
local function code(v, indent, seen)
    indent, seen = indent or "", seen or {}
    local t = typeof(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then return num(v) end
    if t == "boolean" or t == "nil" then return tostring(v) end
    if t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(num(v.X), num(v.Y), num(v.Z)) end
    if t == "Vector2" then return ("Vector2.new(%s, %s)"):format(num(v.X), num(v.Y)) end
    if t == "CFrame" then
        local c = { v:GetComponents() }
        for i, x in ipairs(c) do c[i] = num(x) end
        return "CFrame.new(" .. table.concat(c, ", ") .. ")"
    end
    if t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(num(v.R), num(v.G), num(v.B)) end
    if t == "UDim2" then
        return ("UDim2.new(%s, %s, %s, %s)"):format(num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset))
    end
    if t == "UDim" then return ("UDim.new(%s, %s)"):format(num(v.Scale), num(v.Offset)) end
    if t == "EnumItem" then return tostring(v) end
    if t == "BrickColor" then return ("BrickColor.new(%q)"):format(v.Name) end
    if t == "NumberRange" then return ("NumberRange.new(%s, %s)"):format(num(v.Min), num(v.Max)) end
    if t == "buffer" then return "buffer.fromstring(" .. string.format("%q", buffer.tostring(v)) .. ")" end
    if t == "Instance" then
        local p = pathOf(v)
        return p or ("nil --[[ instance tanpa parent: " .. tostring(v.Name) .. " ]]")
    end
    if t == "table" then
        if seen[v] then return "{} --[[ tabel berulang ]]" end
        seen[v] = true
        local inner = indent .. "    "
        local n = #v
        local count = 0
        for _ in pairs(v) do count = count + 1 end
        local parts = {}
        if count == n then -- daftar biasa
            for i = 1, n do parts[#parts + 1] = inner .. code(v[i], inner, seen) .. "," end
        else
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b)
                if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
                return type(a) < type(b)
            end)
            for _, k in ipairs(keys) do
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") and not KEYWORDS[k] then
                    key = k
                else
                    key = "[" .. code(k, inner, seen) .. "]"
                end
                parts[#parts + 1] = inner .. key .. " = " .. code(v[k], inner, seen) .. ","
            end
        end
        seen[v] = nil
        if #parts == 0 then return "{}" end
        return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
    end
    return "nil --[[ " .. t .. ": " .. tostring(v) .. " ]]"
end
local function makeScript(e)
    if e.script then return e.script end -- baris dari log tersimpan (sebelum teleport / eksekusi ulang)
    local path = pathOf(e.remote)
    local remoteLine = path and ("local remote = " .. path)
        or ("local remote = nil -- remote \"" .. e.name .. "\" tidak berada di dalam game (parent nil)")
    local head = "-- Ard Hub Remote Spy · " .. e.kind .. " · " .. e.className .. " · " .. e.time
    if e.kind == "IN" then
        local data = {}
        for i = 1, e.args.n do data[i] = "    " .. code(e.args[i], "    ") .. "," end
        return table.concat({
            head,
            remoteLine,
            "-- Data terakhir yang dikirim server (" .. e.args.n .. " nilai):",
            "local data = {\n" .. table.concat(data, "\n") .. "\n}",
            "",
            "remote.OnClientEvent:Connect(function(...)",
            "    print(...)",
            "end)",
        }, "\n")
    end
    local lines = { head, remoteLine }
    local call = e.kind == "INVOKE" and "InvokeServer" or "FireServer"
    local callText
    if e.args.n == 0 then
        callText = "remote:" .. call .. "()"
    else
        local items = {}
        for i = 1, e.args.n do items[i] = "    " .. code(e.args[i], "    ") .. "," end
        lines[#lines + 1] = "local args = {\n" .. table.concat(items, "\n") .. "\n}"
        callText = "remote:" .. call .. "(unpack(args, 1, " .. e.args.n .. "))"
    end
    if call == "InvokeServer" then
        lines[#lines + 1] = "local result = table.pack(" .. callText .. ")"
        if e.results then
            local items = {}
            for i = 1, e.results.n do items[i] = "    " .. code(e.results[i], "    ") .. "," end
            lines[#lines + 1] = "-- Balasan server saat direkam (" .. e.results.n .. " nilai):"
            lines[#lines + 1] = "local expected = {\n" .. table.concat(items, "\n") .. "\n}"
        end
        lines[#lines + 1] = "print(unpack(result, 1, result.n))"
    else
        lines[#lines + 1] = callText
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- tampilan (gaya Trade Spy)
---------------------------------------------------------------------
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end
local C = {
    bg = Color3.fromRGB(15, 15, 19), field = Color3.fromRGB(22, 22, 28), stroke = Color3.fromRGB(42, 42, 52),
    accent = Color3.fromRGB(124, 92, 255), text = Color3.fromRGB(240, 240, 245), muted = Color3.fromRGB(150, 150, 165),
    sel = Color3.fromRGB(42, 35, 80),
}
local function round(p, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
local function outline(p) new("UIStroke", { Color = C.stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p }) end

pcall(function()
    for _, parent in ipairs({ game:GetService("CoreGui"), LocalPlayer:FindFirstChild("PlayerGui") }) do
        local old = parent and parent:FindFirstChild("ArdRemoteSpy")
        if old then old:Destroy() end
    end
    if gethui and gethui():FindFirstChild("ArdRemoteSpy") then gethui().ArdRemoteSpy:Destroy() end
end)
local gui = new("ScreenGui", { Name = "ArdRemoteSpy", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true })
do
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
local box = new("Frame", {
    Size = UDim2.new(0, 560, 0, 300), Position = UDim2.new(0, 40, 0, 40),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, Parent = gui,
})
round(box, 8)
outline(box)
local top = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Active = true, Parent = box })
local title = new("TextLabel", {
    Size = UDim2.new(1, -420, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
    Text = "Remote Spy", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
})
local nextX = -8
local function button(text, w, primary)
    nextX = nextX - w
    local b = new("TextButton", {
        Size = UDim2.new(0, w, 0, 26), Position = UDim2.new(1, nextX, 0, 5),
        BackgroundColor3 = primary and C.accent or C.field, BorderSizePixel = 0, AutoButtonColor = false,
        Text = text, TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 12, Parent = top,
    })
    round(b, 5)
    if not primary then outline(b) end
    nextX = nextX - 6
    return b
end
-- dari kanan ke kiri
local closeBtn = button("Tutup", 56, false)
local clearBtn = button("Bersih", 60, false)
local copyBtn = button("Salin", 56, true)
local pauseBtn = button("Jeda", 50, false)
local biggerBtn = button("A+", 32, false)
local smallerBtn = button("A-", 32, false)
local filterBtn = button("Semua", 70, false)
local list = new("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -66), Position = UDim2.new(0, 8, 0, 38),
    BackgroundColor3 = C.field, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.stroke,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = box,
})
round(list, 5)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = list })
new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = list })
local hint = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 10, 1, -25), BackgroundTransparency = 1,
    Text = "Ketuk satu baris lalu tekan Salin -> tersalin sebagai script. Filter: Semua / Keluar / Masuk",
    TextColor3 = C.muted, Font = Enum.Font.Code, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
})

---------------------------------------------------------------------
-- data log
---------------------------------------------------------------------
-- entry: { kind = "FIRE"/"INVOKE"/"IN", name, className, remote, args (packed), argsText, time, count, row, dirty }
local entries = {}
local total = 0
local selected = nil
local filter = "all" -- "all" / "out" / "in"
local fontSize = 11
local uiDirty, rebuild = true, false
local queue = {}

local function record(kind, remote, args, results)
    if not running or paused then return end
    local okN, name = pcall(function() return remote.Name end)
    if not okN or IGNORE[name] then return end
    total = total + 1
    local last = entries[#entries]
    local argsText = serArgs(args)
    if last and last.remote == remote and last.kind == kind then
        -- panggilan yang sama berturut-turut: digabung, isinya diganti yang terbaru
        last.count = last.count + 1
        last.args, last.argsText, last.time = args, argsText, os.date("%H:%M:%S")
        last.results, last.resultText = results, results and serArgs(results) or nil
        last.script = nil
        last.dirty = true
    else
        local okC, cls = pcall(function() return remote.ClassName end)
        local e = {
            kind = kind, name = name, className = okC and cls or "?", remote = remote,
            args = args, argsText = argsText, time = os.date("%H:%M:%S"), count = 1,
            results = results, resultText = results and serArgs(results) or nil,
        }
        entries[#entries + 1] = e
        queue[#queue + 1] = e
        if #entries > MAX_ROWS then
            local old = table.remove(entries, 1)
            if old.row then old.row:Destroy() old.row = nil end
            if selected == old then selected = nil end
        end
    end
    uiDirty = true
end

local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
local function rowText(e)
    if e.kind == "---" then
        return string.format('<font color="#7c5cff">[%s] --- %s ---</font>', e.time, esc(e.argsText))
    end
    local color = e.kind == "IN" and "#86EFAC" or "#93C5FD"
    local kind = e.kind == "IN" and "IN    " or (e.kind == "FIRE" and "FIRE  " or "INVOKE")
    local args = e.argsText
    if #args > 400 then args = args:sub(1, 400) .. "..." end
    local res = e.resultText
    if res and #res > 200 then res = res:sub(1, 200) .. "..." end
    return string.format('<font color="#6b6b78">[%s]</font> <font color="%s">%s</font> %s(%s)%s%s',
        e.time, color, kind, esc(e.name), esc(args),
        res and (' <font color="#FCD34D">→ ' .. esc(res) .. "</font>") or "",
        e.count > 1 and (' <font color="#9696a5">x' .. e.count .. "</font>") or "")
end
local function matches(e)
    if e.kind == "---" then return true end
    if filter == "out" then return e.kind ~= "IN" end
    if filter == "in" then return e.kind == "IN" end
    return true
end
local order = 0
local function makeRow(e)
    order = order + 1
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
        BackgroundColor3 = C.sel, BackgroundTransparency = (selected == e) and 0 or 1, BorderSizePixel = 0,
        AutoButtonColor = false, RichText = true, TextWrapped = true, Text = rowText(e),
        TextColor3 = C.text, Font = Enum.Font.Code, TextSize = fontSize,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = list,
    })
    round(row, 3)
    new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), Parent = row })
    row.MouseButton1Click:Connect(function()
        local prev = selected
        selected = (selected == e) and nil or e
        if prev and prev.row then prev.row.BackgroundTransparency = 1 end
        if selected and selected.row then selected.row.BackgroundTransparency = 0 end
    end)
    e.row = row
end

-- Semua perubahan tampilan dilakukan di satu loop ini (hook hanya menyimpan data).
task.spawn(function()
    while running do
        task.wait(0.25)
        if uiDirty or rebuild then
            uiDirty = false
            pcall(function()
                if rebuild then
                    rebuild = false
                    for _, e in ipairs(entries) do
                        if e.row then e.row:Destroy() e.row = nil end
                    end
                    table.clear(queue)
                    for _, e in ipairs(entries) do
                        if matches(e) then makeRow(e) end
                        e.dirty = false
                    end
                else
                    local atBottom = list.CanvasPosition.Y >= list.AbsoluteCanvasSize.Y - list.AbsoluteSize.Y - 30
                    for _, e in ipairs(queue) do
                        if not e.row and matches(e) and table.find(entries, e) then makeRow(e) end
                    end
                    table.clear(queue)
                    for _, e in ipairs(entries) do
                        if e.dirty then
                            e.dirty = false
                            if e.row then e.row.Text = rowText(e) end
                        end
                    end
                    if atBottom then
                        task.defer(function()
                            list.CanvasPosition = Vector2.new(0, math.max(list.AbsoluteCanvasSize.Y - list.AbsoluteSize.Y, 0))
                        end)
                    end
                end
                title.Text = "Remote Spy · " .. total .. (paused and "  (jeda)" or "")
            end)
        end
    end
end)

local function plainLog()
    local out = {}
    for _, e in ipairs(entries) do
        if matches(e) then
            out[#out + 1] = string.format("[%s] %s %s(%s)%s%s", e.time, e.kind, e.name, e.argsText,
                e.resultText and (" -> " .. e.resultText) or "", e.count > 1 and (" x" .. e.count) or "")
        end
    end
    return table.concat(out, "\n")
end
local HttpService = game:GetService("HttpService")
local saveDirty = false
-- JSONEncode menolak teks yang bukan UTF-8 (mis. isi buffer, atau teks terpotong di tengah huruf)
local function utf8safe(text)
    text = tostring(text or "")
    if utf8.len(text) then return text end
    return (text:gsub("[\128-\255]", "?"))
end
local function saveLog()
    if not writefile then return end
    local list = {}
    for _, e in ipairs(entries) do
        if e.kind ~= "---" and not e.script then
            local ok, res = pcall(makeScript, e) -- dibuat sekarang, selagi remote & argumennya masih ada
            if ok then e.script = res end
        end
        list[#list + 1] = {
            kind = e.kind, name = utf8safe(e.name), className = e.className, time = e.time,
            count = e.count, argsText = utf8safe(e.argsText), script = e.script and utf8safe(e.script) or nil,
            resultText = e.resultText and utf8safe(e.resultText) or nil,
        }
    end
    pcall(function()
        if makefolder and isfolder and not isfolder("ArdHub") then makefolder("ArdHub") end
        writefile(LOG_FILE, HttpService:JSONEncode({ total = total, entries = list }))
        writefile("ArdHub/remote_spy.txt", plainLog())
    end)
end
task.spawn(function() -- simpan log ke file tiap 3 detik bila ada perubahan
    local lastTotal = -1
    while running do
        task.wait(3)
        if total ~= lastTotal or saveDirty then
            lastTotal, saveDirty = total, false
            saveLog()
        end
    end
end)
-- pulihkan log dari eksekusi / server sebelumnya
pcall(function()
    if not (readfile and isfile and isfile(LOG_FILE)) then return end
    local data = HttpService:JSONDecode(readfile(LOG_FILE))
    if type(data) ~= "table" or type(data.entries) ~= "table" then return end
    for _, r in ipairs(data.entries) do
        if type(r) == "table" and type(r.kind) == "string" then
            entries[#entries + 1] = {
                kind = r.kind, name = tostring(r.name or "?"), className = tostring(r.className or "?"),
                time = tostring(r.time or ""), count = tonumber(r.count) or 1, argsText = tostring(r.argsText or ""),
                resultText = type(r.resultText) == "string" and r.resultText or nil,
                script = type(r.script) == "string" and r.script or nil, restored = true,
            }
        end
    end
    total = tonumber(data.total) or #entries
    if #entries > 0 then
        entries[#entries + 1] = {
            kind = "---", name = "", className = "", time = os.date("%H:%M:%S"), count = 1,
            argsText = "Remote Spy jalan lagi (" .. (game.PlaceId and ("place " .. game.PlaceId) or "") .. ")",
        }
    end
    while #entries > MAX_ROWS do table.remove(entries, 1) end
    rebuild = true
end)

---------------------------------------------------------------------
-- tombol
---------------------------------------------------------------------
local FILTERS = { { "all", "Semua" }, { "out", "Keluar" }, { "in", "Masuk" } }
filterBtn.MouseButton1Click:Connect(function()
    local idx = 1
    for i, f in ipairs(FILTERS) do if f[1] == filter then idx = i end end
    local nextF = FILTERS[idx % #FILTERS + 1]
    filter = nextF[1]
    filterBtn.Text = nextF[2]
    if selected and not matches(selected) then selected = nil end
    rebuild = true
end)
pauseBtn.MouseButton1Click:Connect(function()
    paused = not paused
    pauseBtn.Text = paused and "Lanjut" or "Jeda"
    pauseBtn.BackgroundColor3 = paused and C.accent or C.field
    uiDirty = true
end)
local function setFont(n)
    fontSize = math.clamp(n, 8, 20)
    for _, e in ipairs(entries) do if e.row then e.row.TextSize = fontSize end end
end
biggerBtn.MouseButton1Click:Connect(function() setFont(fontSize + 1) end)
smallerBtn.MouseButton1Click:Connect(function() setFont(fontSize - 1) end)
local function flash(b, text, back)
    b.Text = text
    task.delay(1.5, function() if b.Parent then b.Text = back end end)
end
copyBtn.MouseButton1Click:Connect(function()
    local text
    if selected then
        local ok, res = pcall(makeScript, selected)
        text = ok and res or ("-- gagal membuat script: " .. tostring(res))
    else
        text = plainLog()
    end
    if setclipboard and pcall(setclipboard, text) then
        flash(copyBtn, selected and "Script!" or "Log!", "Salin")
    else
        hint.Text = "Executor tidak mendukung setclipboard. Lihat workspace/ArdHub/remote_spy.txt"
    end
end)
clearBtn.MouseButton1Click:Connect(function()
    for _, e in ipairs(entries) do if e.row then e.row:Destroy() end end
    table.clear(entries)
    table.clear(queue)
    selected = nil
    total = 0
    saveDirty = true -- file log ikut dikosongkan
    uiDirty = true
end)

do -- geser lewat bagian atas
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, box.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            box.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
do -- ubah ukuran lewat sudut kanan bawah
    local grip = new("TextLabel", {
        Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -22, 1, -22), BackgroundTransparency = 1,
        Text = "◢", TextColor3 = C.muted, TextSize = 16, Font = Enum.Font.Code, Active = true, ZIndex = 5, Parent = box,
    })
    local resizing, startPos, startSize
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing, startPos = true, input.Position
            startSize = Vector2.new(box.AbsoluteSize.X, box.AbsoluteSize.Y)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startPos
            local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
            box.Size = UDim2.new(0, math.clamp(startSize.X + d.X, 480, view.X), 0, math.clamp(startSize.Y + d.Y, 160, view.Y))
        end
    end)
end

---------------------------------------------------------------------
-- MASUK: OnClientEvent (tanpa hook)
---------------------------------------------------------------------
local conns = {}
local watched = {}
local function watchRemote(r)
    if watched[r] then return end
    if not (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then return end
    watched[r] = true
    conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
        if running and not paused then record("IN", r, table.pack(...)) end
    end)
end
-- remote biasanya ada di ReplicatedStorage, kadang di workspace atau di dalam pemain
for _, root in ipairs({ game:GetService("ReplicatedStorage"), workspace, LocalPlayer }) do
    for _, d in ipairs(root:GetDescendants()) do pcall(watchRemote, d) end
    conns[#conns + 1] = root.DescendantAdded:Connect(function(d) pcall(watchRemote, d) end)
end

---------------------------------------------------------------------
-- KELUAR: hook yang hanya mencatat, lalu meneruskan panggilan asli apa adanya
---------------------------------------------------------------------
local hookActive = false
local lastOut = {}
local function logOut(self, method, args, results)
    if not (hookActive and running) or paused or typeof(self) ~= "Instance" then return end
    -- satu panggilan bisa tertangkap dua hook sekaligus: catat sekali saja
    local key = tostring(self) .. method .. serArgs(args)
    local now = os.clock()
    if lastOut[key] and now - lastOut[key] < 0.05 then return end
    lastOut[key] = now
    record(method == "InvokeServer" and "INVOKE" or "FIRE", self, args, results)
end
task.spawn(function() -- bersihkan catatan anti-dobel secara berkala
    while running do
        task.wait(30)
        table.clear(lastOut)
    end
end)
local hookCount = 0
if HOOK_OUTGOING and hookmetamethod and getnamecallmethod then
    local wrap = newcclosure or function(f) return f end
    -- 1) gaya remote:FireServer(...) / remote:InvokeServer(...)
    pcall(function()
        local oldNC
        oldNC = hookmetamethod(game, "__namecall", wrap(function(self, ...)
            if hookActive and not (checkcaller and checkcaller()) then
                local method = getnamecallmethod()
                if method == "InvokeServer" then
                    -- balasan server disalin untuk log, lalu dikembalikan apa adanya
                    local args = table.pack(...)
                    local results = table.pack(oldNC(self, ...))
                    task.spawn(logOut, self, method, args, results)
                    return table.unpack(results, 1, results.n)
                elseif method == "FireServer" then
                    task.spawn(logOut, self, method, table.pack(...))
                end
            end
            return oldNC(self, ...)
        end))
        if oldNC then hookCount = hookCount + 1 end
    end)
    -- 2) gaya remote.FireServer(remote, ...) atau fungsi yang sudah disimpan game
    if hookfunction then
        local samples = {}
        for _, cls in ipairs({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" }) do
            local ok, inst = pcall(function() return Instance.new(cls) end)
            if ok and inst then samples[#samples + 1] = inst end
        end
        for _, inst in ipairs(samples) do
            for _, method in ipairs({ "FireServer", "InvokeServer" }) do
                pcall(function()
                    local fn = inst[method]
                    local old
                    old = hookfunction(fn, wrap(function(self, ...)
                        if hookActive and not (checkcaller and checkcaller()) then
                            if method == "InvokeServer" then
                                local args = table.pack(...)
                                local results = table.pack(old(self, ...))
                                task.spawn(logOut, self, method, args, results)
                                return table.unpack(results, 1, results.n)
                            end
                            task.spawn(logOut, self, method, table.pack(...))
                        end
                        return old(self, ...)
                    end))
                    if old then hookCount = hookCount + 1 end
                end)
            end
        end
    end
    hookActive = hookCount > 0
end
hint.Text = (HOOK_OUTGOING and (hookActive and ("Keluar: " .. hookCount .. " hook aktif") or "Keluar: hook gagal (executor tidak mendukung)")
    or "Keluar: dimatikan") .. "  ·  Ketuk baris lalu Salin = script siap pakai"

---------------------------------------------------------------------
-- tetap jalan setelah teleport (lobby -> match, pindah server)
---------------------------------------------------------------------
local queueTeleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
local selfSaved = false
pcall(function() selfSaved = isfile and isfile(SELF_FILE) or false end)
local reexecCode = 'if isfile and isfile("' .. SELF_FILE .. '") then loadstring(readfile("' .. SELF_FILE .. '"))() end'
local function queueSelf()
    if running and queueTeleport and selfSaved then pcall(queueTeleport, reexecCode) end
end
queueSelf()
pcall(function()
    conns[#conns + 1] = LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started then
            saveLog() -- simpan log terakhir sebelum pindah
            queueSelf()
        end
    end)
end)
local autoText
if not queueTeleport then
    autoText = "Auto lanjut setelah teleport: tidak didukung executor"
elseif not selfSaved then
    autoText = "Simpan script ini sebagai " .. SELF_FILE .. " supaya otomatis jalan lagi setelah teleport"
else
    autoText = "Auto lanjut setelah teleport: aktif"
end
hint.Text = hint.Text .. "  ·  " .. autoText

local function stop()
    pcall(saveLog)
    running = false
    hookActive = false
    for _, c in ipairs(conns) do pcall(c.Disconnect, c) end
    pcall(function() gui:Destroy() end)
end
env.__ArdRemoteSpy = stop
closeBtn.MouseButton1Click:Connect(stop)
