--[[
    Ard Hub Auto Trade (script terpisah dari Ard Hub)

    1. Auto Bump        : TradeGlobal("bumpTrade", <ID iklan>) setiap BUMP_EVERY detik
    2. Auto Accept      : menerima permintaan trade (TradeSendInvite -> TradeAcceptInvite)
    3. Auto Trade       : memasukkan unit GIVE ke offer, lalu mengecek offer lawan.
                          Sesuai WANT  -> menekan tombol Accept milik game.
                          Tidak sesuai -> menunggu (tidak Accept). Kalau lawan mengubah offer,
                          server membatalkan ready dua pihak, lalu script mengecek ulang.

    ID item terlihat di Trade Spy, contoh: "unit_oracle", "dp_gd_vip", "unit_coffin_plant".
]]

---------------------------------------------------------------------
-- PENGATURAN
---------------------------------------------------------------------
local CONFIG = {
    -- GIVE / WANT di bawah hanya CADANGAN. Saat script dijalankan, semua iklan trade Anda dibaca otomatis
    -- (queryMyTrades), dan setiap iklan menjadi satu "deal": beri item iklan itu, minta item iklan itu.
    -- Yang Anda berikan (dimasukkan otomatis ke offer).
    -- Boleh pakai nama yang tampil di game (name = "Rageroot") atau ID item (id = "unit_oracle").
    GIVE = {
        { id = "unit_mint_petal", amount = 1 }, -- Rageroot
    },
    -- Yang harus diberikan lawan (minimal jumlahnya)
    WANT = {
        { id = "dp_gd_vip", amount = 1 },
    },
    -- true  = lawan boleh menambah item lain selain WANT (tetap di-Accept)
    -- false = offer lawan harus persis WANT, tidak boleh ada item lain
    ALLOW_EXTRA = true,
    -- Kosong = terima permintaan trade dari siapa saja. Isi username untuk membatasi, mis. { "Aerodep" }
    ACCEPT_FROM = {},
    BUMP_EVERY = 62,          -- detik antar bump (cooldown 1 menit + 2 detik); iklan di-bump bergantian
    ACCEPT_DELAY = 1.5,       -- detik menunggu offer lawan stabil sebelum Accept
    GIVE_DELAY = 3,           -- detik jeda sebelum menaruh item ke offer (diacak +-0,5 detik)
    -- Kalau lawan mengubah offer setelah Anda Accept (server membatalkan Accept), tunggu sekian detik,
    -- lalu kalau offer barunya masih sesuai, Accept ditekan ulang 1 kali dan menunggu lawan Accept.
    REACCEPT_DELAY = 2,
    ACCEPT_RETRY = 1.5,       -- detik sebelum Accept ditekan lagi kalau belum tercatat di server
    ACCEPT_TRIES = 6,         -- maksimal berapa kali Accept dicoba untuk satu versi offer
    -- Decline otomatis kalau offer lawan tidak sesuai
    AUTO_DECLINE = true,
    DECLINE_DELAY = 4,        -- detik offer lawan tidak berubah dan tetap tidak sesuai -> Decline
    EMPTY_TIMEOUT = 30,       -- detik lawan belum menaruh item apa pun -> Decline
    -- Opsional: ID unik item yang diberikan (dari Trade Spy, mis. "unique_346") kalau inventory tidak terbaca
    GIVE_UNIQUE_IDS = {},
}

---------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.__ArdAutoTrade then pcall(env.__ArdAutoTrade) end
local running = true
local conns = {}

local On = { bump = true, accept = true, trade = true }
local stats = { bumps = 0, trades = 0, cancelled = 0 } -- cancelled: offer sesuai, tapi trade batal

---------------------------------------------------------------------
-- UI kecil: tombol on/off, status, log
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
    good = Color3.fromRGB(46, 204, 113), bad = Color3.fromRGB(231, 76, 60),
}
local function round(p, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
local function outline(p) new("UIStroke", { Color = C.stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p }) end

pcall(function()
    for _, parent in ipairs({ game:GetService("CoreGui"), LocalPlayer:FindFirstChild("PlayerGui") }) do
        local old = parent and parent:FindFirstChild("ArdAutoTrade")
        if old then old:Destroy() end
    end
    if gethui and gethui():FindFirstChild("ArdAutoTrade") then gethui().ArdAutoTrade:Destroy() end
end)
local gui = new("ScreenGui", { Name = "ArdAutoTrade", ResetOnSpawn = false, DisplayOrder = 55, IgnoreGuiInset = true })
do
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
local win = new("Frame", {
    Size = UDim2.new(0, 330, 0, 250), Position = UDim2.new(0, 20, 0, 80),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, Parent = gui,
})
round(win, 8)
outline(win)
local top = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Active = true, Parent = win })
new("TextLabel", {
    Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
    Text = "Auto Trade", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = top,
})
local closeBtn = new("TextButton", {
    Size = UDim2.new(0, 56, 0, 22), Position = UDim2.new(1, -62, 0, 4), BackgroundColor3 = C.field,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "Tutup", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 12, Parent = top,
})
round(closeBtn, 5)
outline(closeBtn)

local toggles = {}
local function makeToggle(key, label, x)
    local b = new("TextButton", {
        Size = UDim2.new(1 / 3, -8, 0, 26), Position = UDim2.new((x - 1) / 3, 5, 0, 34),
        BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.text, Parent = win,
    })
    round(b, 5)
    local function render()
        b.Text = label .. ": " .. (On[key] and "ON" or "OFF")
        b.BackgroundColor3 = On[key] and C.accent or C.field
    end
    b.MouseButton1Click:Connect(function()
        On[key] = not On[key]
        render()
    end)
    render()
    toggles[key] = render
end
makeToggle("bump", "Bump", 1)
makeToggle("accept", "Accept", 2)
makeToggle("trade", "Trade", 3)

local statusLabel = new("TextLabel", {
    Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 64), BackgroundTransparency = 1,
    Text = "", TextColor3 = C.muted, Font = Enum.Font.Code, TextSize = 11, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = win,
})
local logBox = new("TextLabel", {
    Size = UDim2.new(1, -16, 1, -108), Position = UDim2.new(0, 8, 0, 100), BackgroundColor3 = C.field,
    BorderSizePixel = 0, Text = "", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 10, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, ClipsDescendants = true, Parent = win,
})
round(logBox, 5)
new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 4), Parent = logBox })

-- Log & status hanya disimpan di sini; jendela diperbarui oleh satu loop UI (dibuat saat script dijalankan).
-- Setelah menekan tombol game, sebagian executor menurunkan hak akses thread, sehingga thread itu
-- tidak boleh lagi mengubah jendela ini ("lacking capability Plugin").
local logLines = {}
local statusText = "Siap"
local uiDirty = true
local function log(text)
    logLines[#logLines + 1] = os.date("%H:%M:%S") .. " " .. text
    if #logLines > 12 then table.remove(logLines, 1) end
    uiDirty = true
end
local function setStatus(text)
    statusText = text
    uiDirty = true
end
task.spawn(function()
    while running do
        if uiDirty then
            uiDirty = false
            pcall(function()
                logBox.Text = table.concat(logLines, "\n")
                statusLabel.Text = string.format("%s\nBump %d kali | Trade selesai %d | Sesuai tapi batal %d",
                    statusText, stats.bumps, stats.trades, stats.cancelled)
            end)
        end
        task.wait(0.2)
    end
end)

do -- geser & ubah ukuran
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    local grip = new("TextLabel", {
        Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1,
        Text = "◢", TextColor3 = C.muted, TextSize = 14, Font = Enum.Font.Code, Active = true, ZIndex = 5, Parent = win,
    })
    local resizing, rStart, rSize
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing, rStart, rSize = true, input.Position, win.AbsoluteSize
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then return end
        if dragging then
            local d = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        elseif resizing then
            local d = input.Position - rStart
            win.Size = UDim2.new(0, math.max(rSize.X + d.X, 280), 0, math.max(rSize.Y + d.Y, 180))
        end
    end)
end

---------------------------------------------------------------------
-- remote
---------------------------------------------------------------------
local remoteCache = {}
local function getRemote(name)
    local r = remoteCache[name]
    if r and r.Parent then return r end
    for _, folder in ipairs({ "RemoteFunctions", "RemoteEvents" }) do
        local f = ReplicatedStorage:FindFirstChild(folder)
        local c = f and f:FindFirstChild(name)
        if c and (c:IsA("RemoteFunction") or c:IsA("RemoteEvent")) then r = c break end
    end
    if not r then
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d.Name == name and (d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) then r = d break end
        end
    end
    remoteCache[name] = r
    return r
end
local function call(name, ...)
    local r = getRemote(name)
    if not r then
        log("remote " .. name .. " tidak ditemukan")
        return false
    end
    if r:IsA("RemoteFunction") then
        return pcall(r.InvokeServer, r, ...)
    end
    return pcall(r.FireServer, r, ...)
end
local function onEvent(name, fn)
    task.spawn(function()
        for _ = 1, 60 do
            local r = getRemote(name)
            if r and r:IsA("RemoteEvent") then
                conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
                    if running then
                        local ok, err = pcall(fn, ...)
                        if not ok then log("error " .. name .. ": " .. tostring(err)) end
                    end
                end)
                return
            end
            task.wait(2)
        end
    end)
end

---------------------------------------------------------------------
-- menekan tombol game (Accept di jendela trade)
---------------------------------------------------------------------
local getIdentity = getthreadidentity or getidentity or (syn and syn.get_thread_identity)
local setIdentity = setthreadidentity or setidentity or (syn and syn.set_thread_identity)
local lastClickErr = nil
local function clickButtonRaw(b)
    lastClickErr = nil
    if firesignal then
        local ok, err = pcall(function()
            for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" }) do
                firesignal(b[sig])
            end
        end)
        if ok then return true end
        lastClickErr = tostring(err)
    end
    if getconnections then
        local fired = false
        pcall(function()
            for _, sig in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up" }) do
                for _, c in ipairs(getconnections(b[sig])) do
                    if c.Fire then c:Fire() elseif c.Function then task.spawn(c.Function) end
                    fired = true
                end
            end
        end)
        if fired then return true end
    end
    local ok = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos = b.AbsolutePosition + b.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.wait(0.05)
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
    return ok
end
-- Menekan tombol game, lalu mengembalikan hak akses thread seperti semula.
local function clickButton(b)
    local before
    if getIdentity then pcall(function() before = getIdentity() end) end
    local ok = clickButtonRaw(b)
    if before and setIdentity then pcall(setIdentity, before) end
    return ok
end
-- Tekan tombol lewat input layar (seperti jari / mouse sungguhan), jadi diproses game sendiri.
-- Jendela Auto Trade disembunyikan sebentar supaya tidak menghalangi tombol.
local function clickInput(b)
    local wasEnabled = gui.Enabled
    gui.Enabled = false
    local ok, err = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos = b.AbsolutePosition + b.AbsoluteSize / 2
        local sg = b:FindFirstAncestorOfClass("ScreenGui")
        if not (sg and sg.IgnoreGuiInset) then pos = pos + game:GetService("GuiService"):GetGuiInset() end
        task.wait(0.05)
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.wait(0.08)
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        task.wait(0.05)
    end)
    gui.Enabled = wasEnabled
    if not ok then lastClickErr = tostring(err) end
    return ok
end
-- Tulisan tombol. Tombol bergambar (ImageButton) tidak punya properti Text, jadi dibaca dengan aman
-- dari tombol itu sendiri (kalau ada) dan dari tulisan di dalamnya.
local function buttonText(b)
    local texts = {}
    local ok, own = pcall(function() return b.Text end)
    if ok and type(own) == "string" then texts[#texts + 1] = own end
    for _, c in ipairs(b:GetDescendants()) do
        if c:IsA("TextLabel") or c:IsA("TextButton") then texts[#texts + 1] = tostring(c.Text) end
    end
    return (table.concat(texts, " "):gsub("<[^>]+>", ""):lower())
end
local function declineButton()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ok, b = pcall(function()
        return pg.GameGui.Screen.Middle.Trade.Items.Container.Items.Right.Controls.Items.Buttons.Decline
    end)
    if ok and b then return b end
    for _, d in ipairs(pg and pg:GetDescendants() or {}) do
        if d:IsA("GuiButton") and d.Name == "Decline" and d:FindFirstAncestor("Trade") then return d end
    end
    return nil
end
local function acceptButton()
    -- GameGui.Screen.Middle.Trade.Items.Container.Items.Right.Controls.Items.Buttons.Accept
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ok, b = pcall(function()
        return pg.GameGui.Screen.Middle.Trade.Items.Container.Items.Right.Controls.Items.Buttons.Accept
    end)
    if ok and b then return b end
    for _, d in ipairs(pg and pg:GetDescendants() or {}) do
        if d:IsA("GuiButton") and d.Name == "Accept" and d:FindFirstAncestor("Trade") then return d end
    end
    return nil
end

---------------------------------------------------------------------
-- inventory: ID unik item ("unique_346") -> ID item ("unit_oracle")
---------------------------------------------------------------------
local inventory = {}   -- [unique] = { id = "unit_oracle", equipped = bool }
local usedUniques = {} -- yang sudah diberikan (tidak dipakai lagi)
local function scanInventory(t, depth, seen)
    depth, seen = depth or 0, seen or {}
    if type(t) ~= "table" or depth > 5 or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        if type(k) == "string" and k:match("^unique_%d+$") and type(v) == "table" then
            local id = (type(v.ItemData) == "table" and v.ItemData.ID) or v.ID or v.Id
            if type(id) == "string" then
                inventory[k] = { id = id, equipped = v.Equipped == true, amount = tonumber(v.Amount) or 1 }
            end
        elseif type(v) == "table" then
            scanInventory(v, depth + 1, seen)
        end
    end
end
local function loadInventory()
    pcall(function()
        local m = LocalPlayer.PlayerGui.LogicHolder.ClientLoader.Modules.ClientDataHandler
        local data = require(m)
        if type(data) ~= "table" then return end
        scanInventory(data, 2)
        if type(data.GetValueNow) == "function" then
            for _, key in ipairs({ "Inventory", "UnitInventory", "Units", "Items", "UniqueItems", "Backpack" }) do
                local ok, v = pcall(data.GetValueNow, key)
                if ok then scanInventory(v) end
            end
        end
    end)
end
onEvent("UpdateUnitInventory", function(...) for _, a in ipairs({ ... }) do scanInventory(a) end end)
loadInventory()
-- Nama tampilan ("Rageroot") -> ID item ("unit_xxx"), dibaca dari daftar inventory di jendela trade game.
-- Setiap item di daftar itu berupa objek bernama ID item, berisi tulisan nama tampilannya.
local function resolveGiveId(entry)
    if entry.id then return entry.id end
    local want = tostring(entry.name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if want == "" then return nil end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local inv
    pcall(function() inv = pg.GameGui.Screen.Middle.Trade.Inventory end)
    for _, root in ipairs({ inv, pg }) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) then
                    local t = tostring(d.Text):gsub("<[^>]+>", ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
                    if t == want then
                        local p = d.Parent
                        while p and p ~= root do
                            if p.Name:match("^unit_[%w_]+$") or p.Name:match("^dp_[%w_]+$") then return p.Name end
                            p = p.Parent
                        end
                    end
                end
            end
        end
    end
    -- cadangan: cocokkan nama dengan ID item di inventory ("Rageroot" -> "...rageroot...")
    local key = want:gsub("%s+", "_")
    for _, info in pairs(inventory) do
        if info.id:lower():find(key, 1, true) then return info.id end
    end
    return nil
end
local function pickUniques(id, amount)
    local list, picked = {}, {}
    for _, u in ipairs(CONFIG.GIVE_UNIQUE_IDS) do
        if #list >= amount then break end
        if not usedUniques[u] then list[#list + 1] = u picked[u] = true end
    end
    -- utamakan unit yang tidak sedang dipakai (Equipped)
    for pass = 1, 2 do
        for u, info in pairs(inventory) do
            if #list >= amount then break end
            if info.id == id and not usedUniques[u] and not picked[u] and (pass == 2 or not info.equipped) then
                list[#list + 1] = u
                picked[u] = true
            end
        end
    end
    return list
end

---------------------------------------------------------------------
-- offer lawan sesuai?
---------------------------------------------------------------------
local function offerCounts(offer)
    local counts = {}
    for _, v in pairs(type(offer) == "table" and offer or {}) do
        if type(v) == "table" then
            local id = (type(v.ItemData) == "table" and v.ItemData.ID) or v.ID
            if type(id) == "string" then counts[id] = (counts[id] or 0) + (tonumber(v.Amount) or 1) end
        end
    end
    return counts
end
local function offerText(counts)
    local parts = {}
    for id, n in pairs(counts) do parts[#parts + 1] = id .. " x" .. n end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "(kosong)"
end
local function offerMatches(counts, want)
    local wanted = {}
    for _, w in ipairs(want or CONFIG.WANT) do
        wanted[w.id] = true
        if (counts[w.id] or 0) < (w.amount or 1) then return false end
        if not CONFIG.ALLOW_EXTRA and (counts[w.id] or 0) ~= (w.amount or 1) then return false end
    end
    if not CONFIG.ALLOW_EXTRA then
        for id in pairs(counts) do
            if not wanted[id] then return false end
        end
    end
    return true
end

---------------------------------------------------------------------
-- iklan trade saya (dibaca otomatis saat script dijalankan)
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local myAds = {}   -- { { id = 27461515, give = { {id=,amount=} }, want = { {id=,amount=} } }, ... }
local knownAds = {} -- ID iklan dari bump manual (cadangan)
local AD_ID_KEYS = { id = true, tradeid = true, adid = true, listingid = true, advertid = true, tradeadid = true }
local WANT_KEYS = { "want", "request", "receive", "recv", "get", "ask", "looking", "for" }
local GIVE_KEYS = { "give", "offer", "have", "sell", "send" }
local function isItemId(s) return type(s) == "string" and (s:match("^unit_[%w_]+$") or s:match("^dp_[%w_]+$")) ~= nil end
local function sideOf(key)
    local k = tostring(key):lower()
    for _, w in ipairs(WANT_KEYS) do if k:find(w, 1, true) then return "want" end end
    for _, g in ipairs(GIVE_KEYS) do if k:find(g, 1, true) then return "give" end end
    return nil
end
local function collectItems(v, counts, depth, seen)
    depth, seen = depth or 0, seen or {}
    if depth > 6 then return end
    if isItemId(v) then counts[v] = (counts[v] or 0) + 1 return end
    if type(v) ~= "table" or seen[v] then return end
    seen[v] = true
    local id = (type(v.ItemData) == "table" and v.ItemData.ID) or v.ID or v.Id or v.ItemId
    if isItemId(id) then
        counts[id] = (counts[id] or 0) + (tonumber(v.Amount or v.amount or v.Count or v.Quantity) or 1)
        return
    end
    for k, val in pairs(v) do
        if isItemId(k) then
            counts[k] = (counts[k] or 0) + ((type(val) == "number" and val > 0) and val or 1)
        else
            collectItems(val, counts, depth + 1, seen)
        end
    end
end
local function toList(counts)
    local list = {}
    for id, n in pairs(counts) do list[#list + 1] = { id = id, amount = n } end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end
local function listText(list)
    local parts = {}
    for _, x in ipairs(list) do parts[#parts + 1] = x.id .. " x" .. x.amount end
    return #parts > 0 and table.concat(parts, ", ") or "?"
end
local function parseAds(res)
    local ads, seenIds = {}, {}
    local function walk(v, depth, seen)
        if type(v) ~= "table" or depth > 6 or seen[v] then return end
        seen[v] = true
        local adId
        for k, val in pairs(v) do
            if type(k) == "string" and AD_ID_KEYS[k:lower()] and type(val) == "number" and val >= 1e6
                and val ~= LocalPlayer.UserId then
                adId = val
            end
        end
        if adId and not seenIds[adId] then
            seenIds[adId] = true
            local give, want = {}, {}
            for k, val in pairs(v) do
                local side = type(k) == "string" and sideOf(k)
                if side == "give" then collectItems(val, give) elseif side == "want" then collectItems(val, want) end
            end
            ads[#ads + 1] = { id = adId, give = toList(give), want = toList(want) }
            return
        end
        for _, val in pairs(v) do walk(val, depth + 1, seen) end
    end
    walk(res, 0, {})
    table.sort(ads, function(a, b) return a.id < b.id end)
    return ads
end
local function dump(v, depth, seen)
    depth, seen = depth or 0, seen or {}
    local t = typeof(v)
    if t == "string" then return string.format("%q", v) end
    if t ~= "table" then return tostring(v) end
    if seen[v] or depth > 6 then return "{...}" end
    seen[v] = true
    local pad, parts = string.rep("  ", depth + 1), {}
    for k, val in pairs(v) do parts[#parts + 1] = pad .. tostring(k) .. " = " .. dump(val, depth + 1, seen) end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("  ", depth) .. "}"
end
local function saveFile(name, text)
    if not writefile then return end
    pcall(function()
        if makefolder and isfolder and not isfolder("ArdHub") then makefolder("ArdHub") end
        writefile("ArdHub/" .. name, text)
    end)
end
local function refreshAds(verbose)
    local ok, res = call("TradeGlobal", "queryMyTrades")
    if not ok then
        if verbose then log("daftar iklan tidak terbaca (queryMyTrades gagal)") end
        return false
    end
    myAds = parseAds(res)
    if verbose then
        saveFile("my_trades_raw.txt", dump(res))
        local out = {}
        for _, ad in ipairs(myAds) do out[#out + 1] = { id = ad.id, give = ad.give, want = ad.want } end
        local okJ, enc = pcall(HttpService.JSONEncode, HttpService, out)
        if okJ then saveFile("my_trades.json", enc) end
        log(#myAds .. " iklan trade terbaca:")
        for i, ad in ipairs(myAds) do
            log(string.format("  %d. beri %s -> minta %s", i, listText(ad.give), listText(ad.want)))
        end
    end
    return true
end
-- Deal = pasangan beri/minta. Dari iklan yang terbaca lengkap; kalau tidak ada, pakai GIVE/WANT di pengaturan.
local function deals()
    local list = {}
    for _, ad in ipairs(myAds) do
        if #ad.give > 0 and #ad.want > 0 then
            list[#list + 1] = { give = ad.give, want = ad.want, label = "iklan " .. ad.id }
        end
    end
    if #list == 0 then
        list[1] = { give = CONFIG.GIVE, want = CONFIG.WANT, label = "pengaturan" }
    end
    return list
end
local function findDeal(counts)
    for _, d in ipairs(deals()) do
        if offerMatches(counts, d.want) then return d end
    end
    return nil
end

---------------------------------------------------------------------
-- trade aktif
---------------------------------------------------------------------
local active = nil -- { id, partner, counts, filled, given, mine, theirs, version }
local function allowed(player)
    if #CONFIG.ACCEPT_FROM == 0 then return true end
    for _, n in ipairs(CONFIG.ACCEPT_FROM) do
        if n:lower() == tostring(player and player.Name):lower() then return true end
    end
    return false
end

local evaluate
local function declineTrade(t, reason)
    if active ~= t or t.declined then return end
    t.declined = true
    local b = declineButton()
    local ok = b and clickButton(b)
    if not ok then call("TradeCloseActive", t.id) end
    t.declinedAt = os.clock()
    log("Decline: " .. reason)
    -- Server tidak selalu mengirim TradeClose untuk trade yang kita tolak sendiri,
    -- jadi status trade dilepas sendiri supaya permintaan berikutnya tidak dianggap "sedang trade".
    task.delay(2, function()
        if active == t then
            active = nil
            setStatus("Menunggu trade")
        end
    end)
end
-- Jendela trade game (dari log Trade Spy):
--   tombol +           : Trade.Items.Container.Items.Left.Give.Items.ScrollingFrame.unit_more.TextButton
--   item di inventory  : Trade.Inventory.Inventory.Frame.Items.Items.ScrollingFrame.<ID item>.TextButton
--   tombol Add         : Trade.AmountAdd.Frame.Frame.Actions.Items.Add
local function tradeGui()
    local ok, tr = pcall(function() return LocalPlayer:FindFirstChildOfClass("PlayerGui").GameGui.Screen.Middle.Trade end)
    return ok and tr or nil
end
local function find(root, path)
    local cur = root
    for name in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(name)
    end
    return cur
end
local function giveList()
    local tr = tradeGui()
    return tr and find(tr, "Items.Container.Items.Left.Give.Items.ScrollingFrame")
end
-- Jumlah total item di offer kita. Item bertumpuk (mis. Rageroot) masuk ke kotak yang sama
-- dengan tulisan "x2", jadi yang dihitung jumlahnya, bukan banyaknya kotak.
local function slotAmount(slot)
    for _, d in ipairs(slot:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local txt = tostring(d.Text):gsub("\u{00D7}", "x")
            local n = txt:match("^%s*[xX]%s*(%d+)%s*$") or txt:match("^%s*(%d+)%s*[xX]%s*$")
            if n then return tonumber(n) end
        end
    end
    return 1
end
local function giveCount()
    local list = giveList()
    if not list then return nil end
    local n = 0
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("GuiObject") and c.Name ~= "unit_more" then n = n + slotAmount(c) end
    end
    return n
end
local function asButton(o)
    if not o then return nil end
    if o:IsA("GuiButton") then return o end
    return o:FindFirstChild("TextButton") or o:FindFirstChildWhichIsA("GuiButton", true)
end
local function waitCountAbove(before, limit)
    local w0 = os.clock()
    while os.clock() - w0 < limit do
        local n = giveCount()
        if n and before and n > before then return true end
        task.wait(0.2)
    end
    return false
end
-- Diagnosa: simpan isi kotak offer kita dan jendela jumlah (AmountAdd) ke file, supaya bisa dilihat
-- bagaimana game menampilkan item bertumpuk.
local function dumpTradeGui(tag)
    local tr = tradeGui()
    if not tr then return end
    local out = { "== " .. tag .. " " .. os.date("%H:%M:%S") }
    local function walk(root, label)
        if not root then out[#out + 1] = label .. ": (tidak ada)" return end
        out[#out + 1] = label .. ":"
        for _, d in ipairs(root:GetDescendants()) do
            local line = "  " .. d:GetFullName():sub(#root:GetFullName() + 2) .. " [" .. d.ClassName .. "]"
            local okT, txt = pcall(function() return d.Text end)
            if okT and type(txt) == "string" and txt ~= "" then line = line .. ' text="' .. txt .. '"' end
            local okV, vis = pcall(function() return d.Visible end)
            if okV and vis == false then line = line .. " (hidden)" end
            out[#out + 1] = line
        end
    end
    walk(giveList(), "OFFER KITA")
    walk(find(tr, "AmountAdd"), "AMOUNTADD")
    local text = table.concat(out, "\n")
    local old = ""
    if readfile and isfile then pcall(function() if isfile("ArdHub/trade_gui_dump.txt") then old = readfile("ArdHub/trade_gui_dump.txt") .. "\n\n" end end) end
    saveFile("trade_gui_dump.txt", old .. text)
    -- ringkas di log: semua tulisan di kotak offer kita
    local texts = {}
    local list = giveList()
    if list then
        for _, d in ipairs(list:GetDescendants()) do
            local okT, txt = pcall(function() return d.Text end)
            if okT and type(txt) == "string" and txt ~= "" then texts[#texts + 1] = txt end
        end
    end
    log("[diag] " .. tag .. " | jumlah terbaca=" .. tostring(giveCount()) .. " | tulisan offer: " .. table.concat(texts, " / "))
end
-- Jendela jumlah ("How many Rageroots do you want to add?") punya slider 1..maks.
-- Slider digeser lewat input layar sampai angka di atasnya sama dengan jumlah yang dibutuhkan.
local function screenPos(o, x, y)
    local sg = o:FindFirstAncestorOfClass("ScreenGui")
    if not (sg and sg.IgnoreGuiInset) then
        local inset = game:GetService("GuiService"):GetGuiInset()
        return x + inset.X, y + inset.Y
    end
    return x, y
end
local function centerOf(o) return o.AbsolutePosition + o.AbsoluteSize / 2 end
local function readSlider(root)
    -- angka-angka di jendela: min & maks sebaris dengan slider, nilai sekarang di atasnya
    local nums = {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local n = tonumber((tostring(d.Text):gsub("%s", "")))
            if n and d.AbsoluteSize.X > 0 then nums[#nums + 1] = { obj = d, n = n, c = centerOf(d) } end
        end
    end
    if #nums < 3 then return nil end
    table.sort(nums, function(a, b) return a.c.Y < b.c.Y end)
    local cur = nums[1] -- paling atas
    local row = {}
    for i = 2, #nums do row[#row + 1] = nums[i] end
    table.sort(row, function(a, b) return a.c.X < b.c.X end)
    local lo, hi = row[1], row[#row]
    -- batang slider: objek lebar & tipis di antara label min dan maks
    local track, bestW = nil, 0
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiObject") and not d:IsA("TextLabel") then
            local sz, c = d.AbsoluteSize, centerOf(d)
            if sz.X > bestW and sz.X > sz.Y * 4 and c.X > lo.c.X and c.X < hi.c.X
                and math.abs(c.Y - lo.c.Y) < math.max(sz.Y, 20) then
                track, bestW = d, sz.X
            end
        end
    end
    if not track then return nil end
    -- kenop: objek kira-kira persegi, sebaris dengan batang, paling dekat ke posisi nilai sekarang
    local knob, knobDist = nil, math.huge
    local tl, tw = track.AbsolutePosition.X, track.AbsoluteSize.X
    local f = (hi.n > lo.n) and (cur.n - lo.n) / (hi.n - lo.n) or 0
    local guessX = tl + f * tw
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiObject") and d ~= track and not d:IsA("TextLabel") then
            local sz, c = d.AbsoluteSize, centerOf(d)
            if sz.X > 4 and math.abs(sz.X - sz.Y) <= math.max(sz.X, sz.Y) * 0.35
                and math.abs(c.Y - centerOf(track).Y) < math.max(sz.Y, 12) and sz.X < tw / 3 then
                local dist = math.abs(c.X - guessX)
                if dist < knobDist then knob, knobDist = d, dist end
            end
        end
    end
    return { cur = cur, lo = lo.n, hi = hi.n, track = track, knob = knob }
end
local function dragX(o, fromX, toX, y)
    local vim = game:GetService("VirtualInputManager")
    local x1, y1 = screenPos(o, fromX, y)
    local x2 = select(1, screenPos(o, toX, y))
    vim:SendMouseMoveEvent(x1, y1, game)
    task.wait(0.03)
    vim:SendMouseButtonEvent(x1, y1, 0, true, game, 0)
    for i = 1, 8 do
        task.wait(0.03)
        vim:SendMouseMoveEvent(x1 + (x2 - x1) * i / 8, y1, game)
    end
    task.wait(0.05)
    vim:SendMouseButtonEvent(x2, y1, 0, false, game, 0)
    task.wait(0.15)
end
-- Atur slider ke `amount` (dibatasi maks). Mengembalikan nilai yang terbaca setelahnya, atau nil.
-- Susunan jendela (dari trade_gui_dump.txt):
--   AmountAdd.Frame.Frame.Items.Items.Picker.Amount / AmountMin / AmountMax   (TextLabel angka)
--   AmountAdd.Frame.Frame.Items.Items.Picker.SliderContainer.DragCircle       (kenop, punya UIDragDetector)
--   AmountAdd.Frame.Frame.Items.Items.Picker.SliderContainer.Scroll           (batang)
local function setAmount(root, amount)
    local picker = root and find(root, "Frame.Frame.Items.Items.Picker")
    if not picker then return nil end
    local amountL, minL, maxL = picker:FindFirstChild("Amount"), picker:FindFirstChild("AmountMin"), picker:FindFirstChild("AmountMax")
    local cont = picker:FindFirstChild("SliderContainer")
    local circle = cont and cont:FindFirstChild("DragCircle")
    local bar = cont and (cont:FindFirstChild("Scroll") or cont)
    if not (amountL and minL and maxL and circle and bar) then return nil end
    local det = circle:FindFirstChildWhichIsA("UIDragDetector")
    local identity
    if getIdentity then pcall(function() identity = getIdentity() end) end
    local function value() return tonumber((tostring(amountL.Text):gsub("%s", ""))) end
    local lo, hi = tonumber(minL.Text) or 1, tonumber(maxL.Text) or 1
    local target = math.clamp(amount, lo, hi)
    if value() == target then return target end
    local span = math.max(hi - lo, 1)
    local function pointAt(f)
        local x = bar.AbsolutePosition.X + bar.AbsoluteSize.X * f
        local y = circle.AbsolutePosition.Y + circle.AbsoluteSize.Y / 2
        return x, y
    end
    local wasEnabled = gui.Enabled
    gui.Enabled = false
    local ok = pcall(function()
        -- sedikit digeser ke tengah "petak" angka supaya pembulatan game jatuh di angka yang benar
        for _, nudge in ipairs({ 0, 0.35, -0.35 }) do
            local f = math.clamp((target - lo + nudge) / span, 0, 1)
            local x, y = pointAt(f)
            -- Cara A: kirim sinyal tarik ke UIDragDetector seperti saat kenop ditarik jari
            if det and firesignal then
                pcall(function()
                    local cx, cy = circle.AbsolutePosition.X + circle.AbsoluteSize.X / 2, y
                    firesignal(det.DragStart, Vector2.new(cx, cy))
                    task.wait(0.03)
                    circle.Position = UDim2.new(f, 0, circle.Position.Y.Scale, circle.Position.Y.Offset)
                    firesignal(det.DragContinue, Vector2.new(x, y))
                    task.wait(0.03)
                    firesignal(det.DragEnd, Vector2.new(x, y))
                end)
                task.wait(0.15)
                if value() == target then return end
            end
            -- Cara B: geser kenop lewat input layar
            dragX(circle, circle.AbsolutePosition.X + circle.AbsoluteSize.X / 2, x, y)
            if value() == target then return end
        end
    end)
    if identity and setIdentity then pcall(setIdentity, identity) end
    gui.Enabled = wasEnabled
    if not ok then log("[diag] error saat mengatur slider") end
    return value()
end
-- Cara 1: tekan tombol game seperti orang (game sendiri yang memilih salinan unit yang valid)
local function addViaButtons(t, id, amount)
    amount = amount or 1
    local tr = tradeGui()
    if not tr then return false, "jendela trade tidak ditemukan" end
    local before = giveCount()
    local plus = asButton(find(tr, "Items.Container.Items.Left.Give.Items.ScrollingFrame.unit_more"))
    if not plus then return false, "tombol + tidak ditemukan" end
    clickButton(plus)
    task.wait(0.6 + math.random() * 0.3)
    if active ~= t then return false, "trade selesai" end
    local item = asButton(find(tr, "Inventory.Inventory.Frame.Items.Items.ScrollingFrame." .. id))
    if not item then return false, id .. " tidak ada di inventory trade" end
    -- Angka di jendela jumlah masih berisi angka item sebelumnya (mis. "3" dari Ghost Lily).
    -- Dikosongkan dulu; game mengisinya lagi ("1") saat jendela jumlah benar-benar terbuka untuk item ini.
    local amountL = find(tr, "AmountAdd.Frame.Frame.Items.Items.Picker.Amount")
    local function windowOpen() return amountL and tostring(amountL.Text) ~= "" end
    if amountL then pcall(function() amountL.Text = "" end) end
    local opened = false
    for _ = 1, 2 do
        clickButton(item)
        local w0 = os.clock()
        repeat task.wait(0.15) until windowOpen() or os.clock() - w0 > 1.5 or active ~= t
        if active ~= t then return false, "trade selesai" end
        if windowOpen() then opened = true break end
        if not amountL then break end
        item = asButton(find(tr, "Inventory.Inventory.Frame.Items.Items.ScrollingFrame." .. id)) or item
    end
    -- tunggu animasi jendela jumlah selesai; game mengabaikan Add yang ditekan terlalu cepat
    task.wait(opened and (0.6 + math.random() * 0.3) or (0.2 + math.random() * 0.2))
    if active ~= t then return false, "trade selesai" end
    if amount > 1 and amountL and not opened then
        return false, "jendela jumlah tidak muncul untuk " .. id
    end
    local add = asButton(find(tr, "AmountAdd.Frame.Frame.Actions.Items.Add"))
    local want = 1
    if add and add.Visible and (opened or not amountL or amount == 1) then
        if amount > 1 then
            -- item bertumpuk: atur jumlah di slider dulu, lalu Add sekali
            local got = setAmount(find(tr, "AmountAdd"), amount)
            if got and got > 1 and got <= amount then
                want = got
            else
                -- jumlah tidak pas: jangan Add, tutup jendela jumlah
                log("[diag] slider jumlah tidak bisa diatur (terbaca: " .. tostring(got) .. ")")
                local cancel = asButton(find(tr, "AmountAdd.Frame.Frame.Actions.Items.Cancel"))
                if cancel then clickButton(cancel) end
                return false, "slider jumlah tidak bisa diatur"
            end
        end
        clickButton(add)
    end
    if before == nil then return true, nil, want end -- daftar offer tidak terbaca: anggap berhasil
    local landed = waitCountAbove(before, 1.5)
    if not landed and add and add.Visible and (opened or amount == 1) then
        -- Add tidak tercatat: tekan sekali lagi lewat input layar (seperti jari).
        -- Aman, karena hanya dilakukan kalau isi offer belum bertambah sama sekali.
        log("[diag] Add belum tercatat, ditekan lagi lewat input layar")
        clickInput(add)
        landed = waitCountAbove(before, 2)
    end
    if landed then
        task.wait(0.3)
        local now = giveCount() or (before + 1)
        return true, nil, math.max(now - before, 1)
    end
    dumpTradeGui("GAGAL tambah " .. id)
    return false, "item tidak masuk ke offer"
end
-- Cara 2 (cadangan): kirim ID unik item langsung ke server
local function addViaRemote(t, id, amount)
    -- baca inventory dari awal supaya unit yang sudah terjual tidak ikut dipilih
    local old = inventory
    inventory = {}
    loadInventory()
    if next(inventory) == nil then inventory = old end
    local list = pickUniques(id, amount)
    if #list == 0 then return false, "ID unik " .. id .. " tidak terbaca" end
    if #list < amount then return false, "hanya " .. #list .. " " .. id .. " terbaca di inventory" end
    local before = giveCount()
    -- sama seperti game: semua salinan dikirim sekaligus, mis. { "unique_22", "unique_21" }
    call("TradeAddToOffer", t.id, list)
    if before ~= nil then
        if not waitCountAbove(before, 2.5) then
            return false, "server menolak " .. table.concat(list, ", ")
        end
        task.wait(0.3)
        local now = giveCount() or before
        if now - before ~= amount then
            return false, string.format("jumlah di offer bertambah %d, seharusnya %d", now - before, amount)
        end
    end
    t.given = t.given or {}
    for _, u in ipairs(list) do t.given[#t.given + 1] = u end
    return true, nil
end

local function fillOffer(t)
    if t.filling or t.filled then return end
    t.filling = true
    -- jeda seperti orang sungguhan sebelum menaruh item
    task.wait(math.max(CONFIG.GIVE_DELAY + (math.random() - 0.5), 0.5))
    if active ~= t then return end
    local allOk = true
    for _, g in ipairs((t.deal and t.deal.give) or CONFIG.GIVE) do
        local id = resolveGiveId(g)
        local label = g.name or g.id or "?"
        if not id then
            log(label .. " tidak ditemukan di inventory trade (cek ejaan nama, atau isi id)")
            allOk = false
        else
            local total, done, tries = g.amount or 1, 0, 0
            while done < total and tries < total + 2 do
                tries = tries + 1
                if active ~= t then return end
                local ok, why, n
                local beforeTry = giveCount()
                ok, why, n = addViaButtons(t, id, total - done) -- jumlah diatur lewat slider jendela jumlah
                if not ok and total - done > 1 then
                    -- cadangan: kirim beberapa ID unik sekaligus, seperti yang dikirim game saat Add
                    log("lewat tombol gagal (" .. tostring(why) .. "), coba lewat server")
                    if beforeTry and (giveCount() or 0) > beforeTry then break end -- sebagian sudah masuk
                    ok, why = addViaRemote(t, id, total - done)
                    n = total - done
                    if not ok then
                        log("GAGAL menaruh " .. label .. ": " .. tostring(why))
                        break
                    end
                end
                if ok then
                    done = done + (n or 1)
                    log("offer diisi: " .. label .. " (" .. math.min(done, total) .. "/" .. total .. ")")
                else
                    log("lewat tombol gagal (" .. tostring(why) .. "), coba lewat server")
                    ok, why = addViaRemote(t, id, 1)
                    log(ok and ("offer diisi lewat server: " .. label) or ("GAGAL menaruh " .. label .. ": " .. tostring(why)))
                    if not ok then break end
                    done = done + 1
                end
                task.wait(0.4)
            end
            if done ~= total then
                if done > total then log("PERINGATAN: " .. label .. " di offer " .. done .. ", seharusnya " .. total) end
                allOk = false
            end
        end
    end
    t.filling = false
    t.filled = allOk
    if allOk then
        -- offer lawan bisa sudah masuk duluan: cek sekarang juga
        evaluate(t)
    elseif active == t and On.trade and CONFIG.AUTO_DECLINE then
        -- item iklan tidak bisa ditaruh (mis. unitnya sudah habis): trade tidak mungkin jalan, langsung decline
        declineTrade(t, "item iklan gagal ditaruh ke offer")
    end
end

function evaluate(t)
    if active ~= t or not On.trade then return end
    local counts = t.counts or {}
    -- Deal ditentukan dari offer lawan (iklan mana yang dia balas). Setelah item kita ditaruh,
    -- deal dikunci: offer lawan harus sesuai deal itu.
    local deal = t.deal or findDeal(counts)
    local good = deal ~= nil and offerMatches(counts, deal.want)
    setStatus(string.format("Trade dengan %s\nLawan: %s -> %s", tostring(t.partner),
        offerText(counts), good and ("SESUAI (" .. deal.label .. ")") or "belum sesuai"))
    if not good then
        -- Decline kalau offer lawan tidak berubah selama DECLINE_DELAY detik dan tetap tidak sesuai
        -- (atau masih kosong setelah EMPTY_TIMEOUT detik).
        if CONFIG.AUTO_DECLINE and t.declineScheduled ~= t.version then
            t.declineScheduled = t.version
            local version = t.version
            local wait = next(counts) and CONFIG.DECLINE_DELAY or CONFIG.EMPTY_TIMEOUT
            task.delay(wait, function()
                if active ~= t or t.version ~= version or not On.trade or not CONFIG.AUTO_DECLINE then return end
                local d = t.deal or findDeal(t.counts or {})
                if d and offerMatches(t.counts or {}, d.want) then return end
                declineTrade(t, next(t.counts or {}) and ("offer lawan tidak sesuai: " .. offerText(t.counts)) or "lawan tidak menaruh item")
            end)
        end
        return
    end
    if not t.deal and not t.filling then
        t.deal = deal
        log("cocok dengan " .. deal.label .. ": beri " .. listText(deal.give))
        task.spawn(fillOffer, t) -- setelah item ditaruh, fillOffer memanggil evaluate lagi
        return
    end
    if not t.filled or t.mine then return end
    -- Satu Accept per versi offer: tombol game berubah jadi "Unaccept" setelah ditekan,
    -- jadi tekanan kedua justru membatalkan Accept.
    if t.acceptedVersion == t.version or t.scheduled == t.version then return end
    t.scheduled = t.version
    local version = t.version
    -- Accept pertama: ACCEPT_DELAY. Accept ulang (lawan mengubah offer setelah Accept): REACCEPT_DELAY.
    local wait = t.acceptPressed and CONFIG.REACCEPT_DELAY or CONFIG.ACCEPT_DELAY
    -- Setelah lawan mengubah offer, game kadang mengabaikan klik Accept untuk sesaat.
    -- Karena itu Accept dicek: kalau server belum mencatat Accept kita (TradeReady mine = false),
    -- tombol ditekan lagi setiap ACCEPT_RETRY detik, maksimal ACCEPT_TRIES kali.
    local function stillValid()
        return active == t and t.version == version and not t.mine and On.trade
            and t.deal ~= nil and offerMatches(t.counts or {}, t.deal.want)
    end
    task.delay(wait, function() local okRun, errRun = pcall(function()
        for attempt = 1, CONFIG.ACCEPT_TRIES do
            if not stillValid() then return end
            local b = acceptButton()
            if not b then
                log("tombol Accept tidak ditemukan")
                return
            end
            local text = buttonText(b)
            if attempt <= 2 then log("[diag] tulisan tombol: \"" .. text .. "\"") end
            if text:find("unaccept", 1, true) then
                log("tombol sudah bertuliskan Unaccept, Accept tidak ditekan lagi")
                return -- sudah Accept: jangan ditekan lagi (bisa membatalkan Accept sendiri)
            end
            -- Percobaan pertama: cara biasa (berhasil untuk Accept pertama).
            -- Percobaan berikutnya: lewat input layar, karena cara biasa diabaikan game setelah offer berubah.
            local useInput = attempt >= 2
            local clicked = useInput and clickInput(b) or (not useInput and clickButton(b))
            if lastClickErr then log("[diag] error klik: " .. lastClickErr) end
            if not clicked then
                log("tombol Accept gagal ditekan")
                return
            end
            if attempt == 2 then log("[diag] Accept dicoba lewat input layar") end
            t.acceptedVersion = version
            if attempt == 1 then
                log(t.acceptPressed and "Accept ditekan ulang (offer baru lawan masih sesuai), menunggu lawan Accept"
                    or "Accept ditekan (offer lawan sesuai), menunggu lawan Accept")
            else
                log(string.format("Accept belum tercatat, ditekan lagi (%d/%d)", attempt, CONFIG.ACCEPT_TRIES))
            end
            t.acceptPressed = true
            task.wait(CONFIG.ACCEPT_RETRY)
        end
        if stillValid() then log("Accept tetap belum tercatat setelah " .. CONFIG.ACCEPT_TRIES .. " kali, tekan manual") end
    end)
    if not okRun then log("error saat Accept: " .. tostring(errRun)) end
    end)
end

-- Permintaan trade masuk
onEvent("TradeSendInvite", function(player)
    if not On.accept then return end
    if active then
        -- Trade yang tercatat bisa sudah tidak ada (TradeClose tidak datang). Dianggap sudah selesai kalau:
        -- yang mengirim permintaan adalah lawan trade itu sendiri, trade itu sudah kita decline,
        -- atau jendela trade game sudah tertutup.
        local t = active
        local name = typeof(player) == "Instance" and player.Name or tostring(player)
        local tr = tradeGui()
        local closed = tr ~= nil and tr:IsA("GuiObject") and not tr.Visible
        if name == t.partner or t.declined or closed then
            active = nil
            setStatus("Menunggu trade")
        else
            log("permintaan dari " .. tostring(player) .. " diabaikan (sedang trade dengan " .. t.partner .. ")")
            return
        end
    end
    if not allowed(player) then log("permintaan dari " .. tostring(player) .. " diabaikan (bukan ACCEPT_FROM)") return end
    task.wait(0.5)
    local ok = call("TradeAcceptInvite", player)
    log((ok and "menerima permintaan dari " or "gagal menerima permintaan dari ") .. tostring(player))
end)

-- Trade dimulai
onEvent("ConfirmationPrompt", function(kind, player, id)
    if kind ~= "Trade" or type(id) ~= "string" then return end
    active = { id = id, partner = player and player.Name or "?", counts = {}, version = 0 }
    log("trade dimulai dengan " .. active.partner)
    setStatus("Trade dengan " .. active.partner)
    if On.trade then
        -- item kita baru ditaruh setelah offer lawan cocok dengan salah satu iklan
        evaluate(active) -- mulai hitung EMPTY_TIMEOUT selama offer lawan masih kosong
    end
end)

-- Offer lawan berubah
onEvent("TradeUpdateOffer", function(id, offer)
    local t = active
    if not t or t.id ~= id then return end
    t.counts = offerCounts(offer)
    t.version = t.version + 1
    t.mine = false -- server mereset Accept kedua pihak setiap offer berubah
    log("offer lawan: " .. offerText(t.counts))
    evaluate(t)
end)

-- Status ready kedua pihak (direset server setiap offer berubah)
onEvent("TradeReady", function(id, mine, theirs)
    local t = active
    if not t or t.id ~= id then return end
    -- diagnosa: catat status Accept dari server
    log(string.format("[diag] server TradeReady: kamu=%s, lawan=%s", tostring(mine), tostring(theirs)))
    t.mine, t.theirs = mine == true, theirs == true
    if not t.mine then evaluate(t) end
end)

onEvent("TradeStartCountdown", function(id, secs)
    if active and active.id == id then log("finalizing trade... " .. tostring(secs) .. " detik") end
end)

-- Trade selesai / batal
onEvent("TradeClose", function(id, completed)
    local t = active
    if not t or t.id ~= id then return end
    if completed then
        stats.trades = stats.trades + 1
        for _, u in ipairs(t.given or {}) do usedUniques[u] = true end
        log("TRADE SELESAI dengan " .. t.partner)
    elseif t.deal and not t.declined then
        -- offer lawan sudah cocok dengan iklan, tapi trade batal (bukan karena kita decline)
        stats.cancelled = stats.cancelled + 1
        log("trade dengan " .. t.partner .. " dibatalkan (offer sudah sesuai " .. t.deal.label .. ")")
    else
        log("trade dengan " .. t.partner .. " dibatalkan")
    end
    active = nil
    setStatus("Menunggu trade")
end)

---------------------------------------------------------------------
-- Anti AFK: Roblox mengeluarkan pemain yang diam 20 menit.
-- (1) Saat Roblox menandai Anda diam (event Idled), langsung dikirim input kecil.
-- (2) Cadangan: input kecil setiap 10-15 menit (acak), walau Idled tidak muncul.
---------------------------------------------------------------------
do
    local VirtualUser = game:GetService("VirtualUser")
    local function nudge()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
    conns[#conns + 1] = LocalPlayer.Idled:Connect(function()
        if running then nudge() end
    end)
    task.spawn(function()
        while running do
            local w0, wait = os.clock(), 600 + math.random() * 300
            while running and os.clock() - w0 < wait do task.wait(5) end
            if running then nudge() end
        end
    end)
    log("Anti AFK aktif")
end

---------------------------------------------------------------------
-- Auto Bump
---------------------------------------------------------------------
local function findAdIds(v, out, depth, seen)
    depth, seen = depth or 0, seen or {}
    if type(v) ~= "table" or depth > 5 or seen[v] then return end
    seen[v] = true
    for k, val in pairs(v) do
        if type(k) == "string" and AD_ID_KEYS[k:lower()] and type(val) == "number" and val >= 1e6
            and val ~= LocalPlayer.UserId then
            out[val] = true
        elseif type(val) == "table" then
            findAdIds(val, out, depth + 1, seen)
        end
    end
end
-- Catat ID iklan saat Anda menekan Bump manual (cadangan kalau daftar iklan tidak terbaca)
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local wrap = newcclosure or function(f) return f end
        local oldNC
        task.defer(function() log("[diag] pencatat TradeSetReady aktif") end)
        oldNC = hookmetamethod(game, "__namecall", wrap(function(self, ...)
            -- diagnosa: catat apa yang dikirim tombol Accept ke server (dari script ini maupun klik manual)
            if running and typeof(self) == "Instance" and self.Name == "TradeSetReady" then
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    local _, ready = ...
                    local manual = not (checkcaller and checkcaller())
                    task.spawn(function()
                        log(string.format("[diag] kirim TradeSetReady(%s)%s", tostring(ready), manual and " - klik manual" or ""))
                    end)
                end
            end
            if running and not (checkcaller and checkcaller()) and getnamecallmethod() == "InvokeServer" then
                local a, b = ...
                if a == "bumpTrade" and type(b) == "number" and typeof(self) == "Instance" and self.Name == "TradeGlobal" then
                    task.spawn(function()
                        if not knownAds[b] then log("ID iklan dicatat dari bump manual: " .. b) end
                        knownAds[b] = true
                    end)
                end
            end
            return oldNC(self, ...)
        end))
    end)
end
-- Jumlah item di inventory saat ini: { [id item] = jumlah }. nil kalau inventory tidak terbaca.
local function inventoryCounts()
    local old = inventory
    inventory = {}
    loadInventory()
    if next(inventory) == nil then
        inventory = old -- tidak terbaca: pakai data lama
    end
    if next(inventory) == nil then return nil end
    local have = {}
    for u, info in pairs(inventory) do
        if not usedUniques[u] then have[info.id] = (have[info.id] or 0) + (info.amount or 1) end
    end
    return have
end
-- Item iklan yang kurang di inventory, atau nil kalau semua ada.
local function missingGive(ad, have)
    for _, g in ipairs(ad.give or {}) do
        if (have[g.id] or 0) < (g.amount or 1) then return g.id end
    end
    return nil
end
local skipped = {} -- [ID iklan] = item yang kurang (supaya log tidak diulang tiap giliran)
task.spawn(function()
    task.wait(1)
    refreshAds(true) -- baca & simpan iklan saat script dijalankan
    local nextBump, turn = 0, 0
    while running do
        task.wait(1)
        if On.bump and os.clock() >= nextBump then
            nextBump = os.clock() + CONFIG.BUMP_EVERY
            refreshAds(false) -- iklan bisa bertambah / berkurang
            -- Iklan yang itemnya sudah tidak ada di inventory tidak di-bump
            -- (server menolak: "offer exceeds current inventory contents").
            local have = inventoryCounts()
            local ids, seen = {}, {}
            for _, ad in ipairs(myAds) do
                local missing = have and missingGive(ad, have)
                if missing then
                    if skipped[ad.id] ~= missing then
                        skipped[ad.id] = missing
                        log(string.format("iklan %d tidak di-bump: %s tidak ada di inventory", ad.id, missing))
                    end
                    seen[ad.id] = true
                elseif not seen[ad.id] then
                    if skipped[ad.id] then
                        skipped[ad.id] = nil
                        log(string.format("iklan %d di-bump lagi (item sudah ada di inventory)", ad.id))
                    end
                    seen[ad.id] = true
                    ids[#ids + 1] = ad.id
                end
            end
            for id in pairs(knownAds) do
                if not seen[id] then seen[id] = true ids[#ids + 1] = id end
            end
            table.sort(ids)
            if #ids == 0 then
                if next(skipped) == nil then
                    log("tidak ada iklan untuk di-bump (pasang iklan dulu, atau tekan Bump manual sekali)")
                end
            else
                -- satu iklan per giliran, bergantian
                turn = turn % #ids + 1
                local id = ids[turn]
                local ok, res = call("TradeGlobal", "bumpTrade", id)
                local msg = type(res) == "string" and res:lower() or ""
                if ok and res ~= false and not (msg:find("can't", 1, true) or msg:find("cannot", 1, true)
                    or msg:find("exceed", 1, true)) then
                    stats.bumps = stats.bumps + 1
                    log(string.format("bump iklan %d/%d (%d)", turn, #ids, id))
                else
                    log(string.format("bump iklan %d ditolak: %s", id, tostring(res)))
                end
            end
            if not active then setStatus("Menunggu trade") end
        end
    end
end)

---------------------------------------------------------------------
local function stop()
    running = false
    for _, c in ipairs(conns) do pcall(c.Disconnect, c) end
    pcall(function() gui:Destroy() end)
end
env.__ArdAutoTrade = stop
closeBtn.MouseButton1Click:Connect(stop)
local invCount = 0
for _ in pairs(inventory) do invCount = invCount + 1 end
log("Auto Trade siap. Item terbaca di inventory: " .. invCount)
