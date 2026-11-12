--[[
====================================================================
  Ard Hub by Ardhi  |  Garden Tower Defense  |  v2.5.5
====================================================================
  ARSITEKTUR (urutan blok di file ini):
    1. CONFIG ........... judul, versi, tema, ikon, path folder
    2. HELPERS .......... pembuat Instance, safe file I/O (pcall), util
    3. WINDOW ........... ScreenGui, top bar, sidebar, drag/resize/minimize
    4. LIBRARY .......... Tab -> Section -> elemen (Toggle/Slider/Input/
                          Dropdown/Button). Elemen yang diberi FLAG
                          nilainya otomatis tersimpan di config.json.
    5. RUNTIME .......... GAME (nama remote, argumen), notifikasi, State
    6. MAP / REPLAY ..... deteksi map (GUID), Auto Replay, Return Lobby
    7. WEBHOOK .......... Discord embed, tag user, target, ringkasan berkala,
                          Dashboard API (telemetry JSON)
    8. MATCH END ........ satu pemicu akhir match untuk semua fitur
    9. MACRO FILE ....... load/save/sanitize JSON macro
   10. RECORD ........... hook __namecall + hookfunction (hanya saat Record)
   11. PLAY ............. berurutan per waktu, tunggu cash, spread kecil
   12. ANTI BAN ......... Placement Spread kecil, mikro-teleport, Auto Walk
   13. TABS ............. Match, Auto Mode, Macro, Anti Ban, Webhook
   14. CONFIG LOAD ...... muat setting tersimpan lalu jalankan callback

  Semua akses remote, teleport, HTTP dan file executor dibungkus pcall.
  Folder data: ArdHub/  (macro: ArdHub/Macros, setting: ArdHub/config.json)
====================================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local __ok, __err = xpcall(function()

local TITLE = "Ard Hub"
local VERSION = "v2.5.5"
local FOOTER = "Garden Tower Defense | Ard Hub by Ardhi | " .. VERSION
local ROOT_DIR = "ArdHub"                    -- folder utama di workspace executor
local CONFIG_FILE = ROOT_DIR .. "/config.json"
local TOGGLE_KEY = Enum.KeyCode.RightControl -- tombol untuk sembunyikan/tampilkan UI

local THEME = {
    bg = Color3.fromRGB(15, 15, 19),
    side = Color3.fromRGB(12, 12, 15),
    card = Color3.fromRGB(20, 20, 26),
    field = Color3.fromRGB(22, 22, 28),
    stroke = Color3.fromRGB(42, 42, 52),
    accent = Color3.fromRGB(124, 92, 255),
    text = Color3.fromRGB(240, 240, 245),
    muted = Color3.fromRGB(150, 150, 165),
    off = Color3.fromRGB(42, 42, 52),
    tabActive = Color3.fromRGB(26, 26, 34),
}

-- Ikon tab & section.
-- Isi dengan emoji/glyph, atau "rbxassetid://ID" (ikon gambar putih, bisa diwarnai),
-- atau spritesheet: { id = "rbxassetid://ID", offset = Vector2.new(x, y), size = Vector2.new(w, h) }
local ICONS = {
    -- Tab (tab "Match" & section "Match" berbagi ikon yang sama)
    ["Dashboard API"] = "📡",
    ["Humanizer"] = "🎲",
    ["Auto Mode"] = "🤖",
    ["Macro"] = "🎬",
    ["Anti Ban"] = "🛡",
    ["Webhook"] = "🔔",
    -- Section
    ["Match"] = "⚔",
    ["Player"] = "👤",
    ["Performance"] = "⚡",
    ["Lobby"] = "🚪",
    ["Files"] = "📁",
    ["Import / Export"] = "🔄",
    ["Record / Play"] = "🔴",
    ["Time-Based Settings"] = "⏱",
    ["Lobby Return"] = "↩",
    ["Discord Webhook"] = "💬",
}


--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or THEME.stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function setParent(gui)
    local ok = pcall(function()
        if gethui then
            gui.Parent = gethui()
        else
            gui.Parent = game:GetService("CoreGui")
        end
    end)
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function destroyOld(name)
    for _, p in ipairs({ game:GetService("CoreGui"), LocalPlayer:FindFirstChild("PlayerGui") }) do
        if p and p:FindFirstChild(name) then
            p[name]:Destroy()
        end
    end
    pcall(function()
        if gethui and gethui():FindFirstChild(name) then
            gethui()[name]:Destroy()
        end
    end)
end

--------------------------------------------------------------------
-- SAFE FILE I/O
-- Fungsi file executor (writefile, readfile, isfolder, ...) tidak selalu ada
-- dan bisa error (path tidak valid, izin). Semua dipanggil lewat wrapper ini
-- sehingga tidak pernah menjatuhkan script.
--------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local HAS_FS = (writefile and readfile and isfolder and makefolder and isfile) and true or false

-- Buat folder (beserta induknya) bila belum ada. true = folder siap dipakai.
local function safeMakeDir(path)
    if not HAS_FS then return false end
    local ok = pcall(function()
        local acc = ""
        for part in tostring(path):gmatch("[^/]+") do
            acc = (acc == "") and part or (acc .. "/" .. part)
            if not isfolder(acc) then makefolder(acc) end
        end
    end)
    return ok
end

-- Baca file. Mengembalikan isi (string) atau nil.
local function safeRead(path)
    if not HAS_FS then return nil end
    local ok, res = pcall(function()
        if not isfile(path) then return nil end
        return readfile(path)
    end)
    return (ok and type(res) == "string") and res or nil
end

-- Tulis file. true bila berhasil.
local function safeWrite(path, content)
    if not HAS_FS then return false end
    return (pcall(writefile, path, tostring(content)))
end

-- JSON encode/decode tanpa error (nil bila gagal).
local function jsonEncode(v)
    local ok, res = pcall(HttpService.JSONEncode, HttpService, v)
    return ok and res or nil
end
local function jsonDecode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, res = pcall(HttpService.JSONDecode, HttpService, s)
    return ok and res or nil
end

--------------------------------------------------------------------
-- CONFIG PERSISTENCE (FLAGS)
-- Elemen UI yang didaftarkan lewat Flag(nama, elemen) otomatis menyimpan
-- nilainya ke ArdHub/config.json (debounce 1 detik) dan dipulihkan saat
-- script dijalankan ulang (mis. lewat autoexec setelah kembali ke lobby).
--------------------------------------------------------------------
local Flags = {}          -- nama flag -> api elemen
local FlagOrder = {}      -- urutan pendaftaran (input/dropdown dulu, toggle belakangan)
local SavedConfig = jsonDecode(safeRead(CONFIG_FILE)) or {}
if type(SavedConfig) ~= "table" then SavedConfig = {} end
local configLoading = false
local saveQueued = false

local function saveConfigNow()
    safeMakeDir(ROOT_DIR)
    local out = {}
    for name, api in pairs(Flags) do
        local ok, v = pcall(api.Get, api)
        if ok and (type(v) == "boolean" or type(v) == "number" or type(v) == "string") then
            out[name] = v
        end
    end
    local enc = jsonEncode(out)
    if enc then safeWrite(CONFIG_FILE, enc) end
end

-- Simpan tertunda: banyak perubahan beruntun = satu kali tulis file.
local function queueSave()
    if configLoading or saveQueued or not HAS_FS then return end
    saveQueued = true
    task.delay(1, function()
        saveQueued = false
        saveConfigNow()
    end)
end

-- Daftarkan elemen ke sistem config. kind = "toggle" | "input" | "value".
-- Mengembalikan elemen yang sama supaya bisa dipakai inline.
local function Flag(name, api, kind)
    if type(api) ~= "table" then return api end
    Flags[name] = api
    FlagOrder[#FlagOrder + 1] = { name = name, api = api, kind = kind or "value" }
    api.Changed = queueSave
    return api
end

-- Ikon: gambar (rbxassetid / spritesheet), glyph/emoji, atau lingkaran kalau kosong
local function makeIcon(parent, icon, position, size)
    size = size or 16

    -- Gambar
    local img = type(icon) == "table" and icon.id or icon
    if type(img) == "string" and img:find("rbxasset") then
        local obj = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = img,
            ImageColor3 = THEME.muted,
            ScaleType = Enum.ScaleType.Fit,
            Size = UDim2.new(0, size, 0, size),
            Position = position,
            Parent = parent,
        })
        if type(icon) == "table" then
            obj.ImageRectOffset = icon.offset or Vector2.new(0, 0)
            obj.ImageRectSize = icon.size or Vector2.new(0, 0)
        end
        return obj, function(c) obj.ImageColor3 = c end
    end

    -- Glyph / emoji
    if type(icon) == "string" and icon ~= "" then
        local obj = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = icon,
            TextColor3 = THEME.text,
            TextTransparency = 0.45,
            Font = Enum.Font.GothamBold,
            TextSize = size,
            Size = UDim2.new(0, size, 0, size),
            Position = position,
            Parent = parent,
        })
        -- emoji tidak bisa diwarnai, jadi aktif/nonaktif lewat transparansi
        return obj, function(c)
            obj.TextTransparency = (c == THEME.muted) and 0.45 or 0
        end
    end

    -- Fallback: lingkaran
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, size, 0, size),
        Position = position,
        Parent = parent,
    })
    local ring = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, size - 4, 0, size - 4),
        Position = UDim2.new(0, 2, 0, 2),
        BorderSizePixel = 0,
        Parent = holder,
    })
    corner(ring, size)
    local st = stroke(ring, THEME.muted, 1.5)
    return holder, function(c) st.Color = c end
end

--------------------------------------------------------------------
-- WINDOW
--------------------------------------------------------------------
-- Tutup instance Ard Hub sebelumnya supaya tidak jalan dobel
for _, n in ipairs({ "ArdHubGui", "ArdHubBlack", "ArdHubStatus", "ArdHubError" }) do
    pcall(destroyOld, n)
end

local Gui = new("ScreenGui", {
    Name = "ArdHubGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 10,
    IgnoreGuiInset = true,
})
setParent(Gui)

-- Shield: lapisan transparan satu layar, aktif hanya saat drag/resize,
-- supaya jari/kursor yang keluar dari jendela tidak menggerakkan kamera.
local Shield = new("Frame", {
    Name = "Shield",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    Visible = false,
    ZIndex = 0,
    Parent = Gui,
})

local Main = new("Frame", {
    Name = "Main",
    Active = true,
    Size = UDim2.new(0, 600, 0, 340),
    Position = UDim2.new(0.5, -300, 0.5, -170),
    BackgroundColor3 = THEME.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = Gui,
})
corner(Main, 6)
stroke(Main, THEME.stroke, 1)

-- Dekorasi window dibungkus blok do...end: Luau membatasi 200 variabel local
-- per fungsi, dan script ini besar. Hanya 3 referensi yang dipakai di luar blok.
local SearchBox, SideList, Pages
do
-- Top bar ----------------------------------------------------------
local TopBar = new("Frame", {
    Name = "TopBar",
    Active = true,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    Parent = Main,
})

local TitleBox = new("Frame", {
    Active = true,
    Size = UDim2.new(0, 170, 0, 44),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    Parent = TopBar,
})

local Title = new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = TITLE,
    TextColor3 = THEME.text,
    Font = Enum.Font.Code,
    TextSize = 20,
    Parent = TitleBox,
})
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), THEME.accent),
    Rotation = 0,
    Parent = Title,
})

-- garis pemisah
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = THEME.stroke,
    BorderSizePixel = 0,
    Parent = TopBar,
})

-- Search box
local SearchFrame = new("Frame", {
    Size = UDim2.new(1, -290, 0, 30),
    Position = UDim2.new(0, 180, 0, 7),
    BackgroundColor3 = THEME.field,
    BorderSizePixel = 0,
    Parent = TopBar,
})
corner(SearchFrame, 5)
stroke(SearchFrame, THEME.stroke, 1)

-- ikon kaca pembesar (digambar dari Frame)
local mag = new("Frame", {
    Size = UDim2.new(0, 11, 0, 11),
    Position = UDim2.new(0, 11, 0.5, -7),
    BackgroundTransparency = 1,
    Parent = SearchFrame,
})
corner(mag, 6)
stroke(mag, THEME.muted, 1.5)
new("Frame", {
    Size = UDim2.new(0, 6, 0, 1.5),
    Position = UDim2.new(0, 19, 0.5, 4),
    Rotation = 45,
    BackgroundColor3 = THEME.muted,
    BorderSizePixel = 0,
    Parent = SearchFrame,
})

SearchBox = new("TextBox", {
    Size = UDim2.new(1, -44, 1, 0),
    Position = UDim2.new(0, 36, 0, 0),
    BackgroundTransparency = 1,
    ClearTextOnFocus = false,
    PlaceholderText = "Search",
    PlaceholderColor3 = THEME.muted,
    Text = "",
    TextColor3 = THEME.text,
    Font = Enum.Font.Code,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = SearchFrame,
})

-- Drag handle
local DragHandle = new("Frame", {
    Active = true,
    Size = UDim2.new(0, 36, 0, 30),
    Position = UDim2.new(1, -46, 0, 7),
    BackgroundTransparency = 1,
    Parent = TopBar,
})
for k = 0, 2 do
    new("Frame", {
        Size = UDim2.new(0, 14, 0, 2),
        Position = UDim2.new(0.5, -7, 0.5, -6 + k * 5),
        BackgroundColor3 = THEME.muted,
        BorderSizePixel = 0,
        Parent = DragHandle,
    })
end

-- Tombol minimize
local MinBtn = new("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -84, 0, 7),
    BackgroundColor3 = THEME.field,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Parent = TopBar,
})
corner(MinBtn, 5)
stroke(MinBtn, THEME.stroke, 1)
local MinIcon = new("Frame", {
    Size = UDim2.new(0, 12, 0, 2),
    Position = UDim2.new(0.5, -6, 0.5, 3),
    BackgroundColor3 = THEME.text,
    BorderSizePixel = 0,
    Parent = MinBtn,
})

-- Drag logic (handle + judul)
do
    local dragging, dragStart, startPos
    local function begin(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            Shield.Visible = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    Shield.Visible = false
                end
            end)
        end
    end
    DragHandle.InputBegan:Connect(begin)
    TitleBox.InputBegan:Connect(begin)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- Sidebar ----------------------------------------------------------
local Sidebar = new("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0, 170, 1, -66),
    Position = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    Parent = Main,
})
new("Frame", {
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = THEME.stroke,
    BorderSizePixel = 0,
    Parent = Sidebar,
})

SideList = new("Frame", {
    Size = UDim2.new(1, -1, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = Sidebar,
})
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SideList })
new("UIPadding", {
    PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
    Parent = SideList,
})

-- Pages area -------------------------------------------------------
Pages = new("Frame", {
    Name = "Pages",
    Size = UDim2.new(1, -186, 1, -76),
    Position = UDim2.new(0, 178, 0, 52),
    BackgroundTransparency = 1,
    Parent = Main,
})

-- Footer
local Footer = new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22),
    Position = UDim2.new(0, 0, 1, -22),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    Text = FOOTER,
    TextColor3 = THEME.muted,
    Font = Enum.Font.Code,
    TextSize = 11,
    Parent = Main,
})

-- Resize grip (kanan bawah) ----------------------------------------
local MIN_W, MIN_H = 480, 260
local MAX_W, MAX_H = 900, 600
local TOPBAR_H = 44

local Grip = new("Frame", {
    Name = "ResizeGrip",
    Size = UDim2.new(0, 20, 0, 20),
    Position = UDim2.new(1, -20, 1, -20),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 20,
    Parent = Main,
})
for k = 0, 2 do
    new("Frame", {
        Size = UDim2.new(0, 4 + k * 4, 0, 1.5),
        Position = UDim2.new(1, -(4 + k * 4) - 4, 1, -(4 + (2 - k) * 4) - 2),
        BackgroundColor3 = THEME.muted,
        BorderSizePixel = 0,
        Rotation = 0,
        ZIndex = 21,
        Parent = Grip,
    })
end

do
    local resizing, startPos, startSize
    Grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            Shield.Visible = true
            startPos = input.Position
            startSize = Vector2.new(Main.Size.X.Offset, Main.Size.Y.Offset)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    resizing = false
                    Shield.Visible = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startPos
            local w = math.clamp(startSize.X + d.X, MIN_W, MAX_W)
            local h = math.clamp(startSize.Y + d.Y, MIN_H, MAX_H)
            Main.Size = UDim2.new(0, w, 0, h)
        end
    end)
end

-- Minimize ---------------------------------------------------------
local minimized = false
local savedSize = Main.Size
local MINI_W, MINI_H = 140, 32

local function setMinimized(v)
    minimized = v
    if v then
        savedSize = Main.Size
        Sidebar.Visible = false
        Pages.Visible = false
        Footer.Visible = false
        Grip.Visible = false
        SearchFrame.Visible = false
        DragHandle.Visible = false

        TopBar.Size = UDim2.new(1, 0, 0, MINI_H)
        TitleBox.Size = UDim2.new(0, MINI_W - 34, 0, MINI_H)
        Title.TextSize = 14
        MinBtn.Size = UDim2.new(0, 22, 0, 22)
        MinBtn.Position = UDim2.new(1, -28, 0, 5)
        MinIcon.Size = UDim2.new(0, 10, 0, 8)
        MinIcon.Position = UDim2.new(0.5, -5, 0.5, -4)
        MinIcon.BackgroundTransparency = 1
        stroke(MinIcon, THEME.text, 1.5)

        TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, MINI_W, 0, MINI_H),
        }):Play()
    else
        TopBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
        TitleBox.Size = UDim2.new(0, 170, 0, TOPBAR_H)
        Title.TextSize = 20
        MinBtn.Size = UDim2.new(0, 30, 0, 30)
        MinBtn.Position = UDim2.new(1, -84, 0, 7)
        for _, c in ipairs(MinIcon:GetChildren()) do
            if c:IsA("UIStroke") then c:Destroy() end
        end
        MinIcon.Size = UDim2.new(0, 12, 0, 2)
        MinIcon.Position = UDim2.new(0.5, -6, 0.5, 3)
        MinIcon.BackgroundTransparency = 0

        local t = TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = savedSize,
        })
        t:Play()
        t.Completed:Connect(function()
            if not minimized then
                Sidebar.Visible = true
                Pages.Visible = true
                Footer.Visible = true
                Grip.Visible = true
                SearchFrame.Visible = true
                DragHandle.Visible = true
            end
        end)
    end
end

MinBtn.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end)
end -- akhir blok WINDOW (local di dalamnya tidak memakan register fungsi utama)

--------------------------------------------------------------------
-- LIBRARY
--------------------------------------------------------------------
-- Dibungkus do...end supaya local internal library tidak memakan register
-- fungsi utama (batas 200). Hanya AddTab yang diekspor.
local AddTab
do
local Tabs = {}
local Sections = {}
local tabCount = 0
local orderCounter = 0

local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

local function applyFilter(query)
    query = query:lower()
    for _, sec in ipairs(Sections) do
        local any = false
        for _, item in ipairs(sec.Items) do
            local show
            if item.IsDivider then
                show = (query == "")
            else
                show = (query == "") or (item.Text:lower():find(query, 1, true) ~= nil)
                if show then any = true end
            end
            item.Row.Visible = show
        end
        sec.Frame.Visible = (query == "") or any
    end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    applyFilter(SearchBox.Text)
end)

local function selectTab(tab)
    for _, t in ipairs(Tabs) do
        local active = (t == tab)
        t.Page.Visible = active
        t.Bar.Visible = active
        t.Button.BackgroundTransparency = active and 0 or 1
        t.SetIconColor(active and THEME.accent or THEME.muted)
        t.Label.TextColor3 = active and THEME.text or THEME.muted
    end
end

local Section = {}
Section.__index = Section

function Section:AddToggle(text, default, callback)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })

    local label = new("TextLabel", {
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.muted,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local pill = new("Frame", {
        Size = UDim2.new(0, 32, 0, 16),
        Position = UDim2.new(1, -32, 0.5, -8),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(pill, 8)

    local knob = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(235, 235, 240),
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(knob, 6)

    local state = false
    local api = {}

    local function render(animate)
        local goalColor = state and THEME.accent or THEME.off
        local goalPos = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        if animate then
            local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(pill, info, { BackgroundColor3 = goalColor }):Play()
            TweenService:Create(knob, info, { Position = goalPos }):Play()
        else
            pill.BackgroundColor3 = goalColor
            knob.Position = goalPos
        end
        label.TextColor3 = state and THEME.text or THEME.muted
    end

    -- Ubah nilai toggle. silent = true: hanya visual, callback tidak dipanggil.
    function api:Set(v, silent)
        state = v and true or false
        render(true)
        if api.Changed then api.Changed(state) end
        if callback and not silent then
            task.spawn(function()
                local ok, err = pcall(callback, state)
                if not ok then warn("[ArdHub] " .. text .. ": " .. tostring(err)) end
            end)
        end
    end
    function api:Get()
        return state
    end

    row.MouseButton1Click:Connect(function()
        api:Set(not state)
    end)

    if default then
        state = true
        render(false)
        if callback then
            task.defer(function() pcall(callback, true) end)
        end
    end

    table.insert(self.Items, { Row = row, Text = text })
    return api
end

function Section:AddDivider()
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 9),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = THEME.stroke,
        BorderSizePixel = 0,
        Parent = row,
    })
    table.insert(self.Items, { Row = row, IsDivider = true })
end

local function makeButton(parent, text, size, order)
    local btn = new("TextButton", {
        Size = size,
        BackgroundColor3 = THEME.field,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = text,
        TextColor3 = THEME.muted,
        Font = Enum.Font.Code,
        TextSize = 12,
        LayoutOrder = order or 0,
        Parent = parent,
    })
    corner(btn, 4)
    stroke(btn, THEME.stroke, 1)
    btn.MouseEnter:Connect(function() btn.TextColor3 = THEME.text end)
    btn.MouseLeave:Connect(function() btn.TextColor3 = THEME.muted end)
    return btn
end

local function makeFieldHolder(body, title)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
        Parent = body,
    })
    new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = THEME.text,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = holder,
    })
    return holder
end

function Section:AddLabel(text)
    local row = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.muted,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    table.insert(self.Items, { Row = row, IsDivider = true })
    return row
end

function Section:AddButton(text, callback)
    local btn = makeButton(self.Body, text, UDim2.new(1, 0, 0, 24), nextOrder())
    btn.MouseButton1Click:Connect(function()
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then warn("[ArdHub] " .. text .. ": " .. tostring(err)) end
        end)
    end)
    table.insert(self.Items, { Row = btn, Text = text })
    return btn
end

function Section:AddButtonRow(textA, callbackA, textB, callbackB)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    local a = makeButton(row, textA, UDim2.new(0.5, -2, 1, 0), 0)
    local b = makeButton(row, textB, UDim2.new(0.5, -2, 1, 0), 0)
    b.Position = UDim2.new(0.5, 2, 0, 0)
    -- Error callback tidak lagi ditelan diam-diam: ditampilkan di console
    -- Callback menerima tombolnya sendiri (dipakai mis. untuk konfirmasi Delete)
    local function run(label, cb, btn)
        task.spawn(function()
            local ok, err = pcall(cb, btn)
            if not ok then warn("[ArdHub] " .. label .. ": " .. tostring(err)) end
        end)
    end
    a.MouseButton1Click:Connect(function() run(textA, callbackA, a) end)
    b.MouseButton1Click:Connect(function() run(textB, callbackB, b) end)
    table.insert(self.Items, { Row = row, Text = textA .. " " .. textB })
    return row
end

function Section:AddInput(title, placeholder, default, callback, numeric)
    local holder = makeFieldHolder(self.Body, title)
    local box = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = THEME.field,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = THEME.muted,
        Text = default or "",
        TextColor3 = THEME.text,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        Parent = holder,
    })
    corner(box, 4)
    stroke(box, THEME.stroke, 1)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })

    if numeric then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local filtered = box.Text:gsub("%D", "")
            if filtered ~= box.Text then
                box.Text = filtered
            end
        end)
    end
    local api = {}
    local function fire()
        if api.Changed then api.Changed(box.Text) end
        if callback then
            task.spawn(function()
                local ok, err = pcall(callback, box.Text)
                if not ok then warn("[ArdHub] " .. title .. ": " .. tostring(err)) end
            end)
        end
    end
    box.FocusLost:Connect(fire)

    function api:Get() return box.Text end
    -- Set(v, fireCallback): fireCallback = true dipakai saat memuat config
    function api:Set(v, fireCallback)
        box.Text = tostring(v or "")
        if fireCallback then fire() end
    end
    table.insert(self.Items, { Row = holder, Text = title })
    return api
end

function Section:AddDropdown(title, options, default, callback)
    local holder = makeFieldHolder(self.Body, title)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = THEME.field,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 2,
        Parent = holder,
    })
    corner(btn, 4)
    stroke(btn, THEME.stroke, 1)
    local valueLabel = new("TextLabel", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = THEME.text,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = btn,
    })
    local arrow = new("TextLabel", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -22, 0.5, -8),
        BackgroundTransparency = 1,
        Text = "v",
        TextColor3 = THEME.muted,
        Font = Enum.Font.Code,
        TextSize = 12,
        Parent = btn,
    })
    local list = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.field,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 3,
        Parent = holder,
    })
    corner(list, 4)
    stroke(list, THEME.stroke, 1)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = list })

    local api = {}
    local current = default

    local function close()
        list.Visible = false
        arrow.Rotation = 0
    end
    local function setValue(v, silent)
        current = v
        valueLabel.Text = tostring(v or "")
        if api.Changed and not silent then api.Changed(v) end
        if callback and not silent then
            task.spawn(function()
                local ok, err = pcall(callback, v)
                if not ok then warn("[ArdHub] " .. title .. ": " .. tostring(err)) end
            end)
        end
    end
    local function rebuild(opts)
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, opt in ipairs(opts) do
            local b = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Text = "  " .. tostring(opt),
                TextColor3 = THEME.muted,
                Font = Enum.Font.Code,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = list,
            })
            b.MouseEnter:Connect(function() b.TextColor3 = THEME.text end)
            b.MouseLeave:Connect(function() b.TextColor3 = THEME.muted end)
            b.MouseButton1Click:Connect(function()
                setValue(opt)
                close()
            end)
        end
    end

    rebuild(options)
    setValue(default, true)

    btn.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        arrow.Rotation = list.Visible and 180 or 0
    end)

    function api:Set(v, silent) setValue(v, silent) end
    function api:Get() return current end
    function api:SetOptions(opts) rebuild(opts) end

    table.insert(self.Items, { Row = holder, Text = title })
    return api
end

-- step (opsional): kelipatan nilai, mis. 0.1 untuk desimal. Default 1 (bilangan bulat).
function Section:AddSlider(title, min, max, default, suffix, callback, step)
    local holder = makeFieldHolder(self.Body, title)
    local bar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
        Active = true,
        LayoutOrder = 2,
        Parent = holder,
    })
    corner(bar, 4)
    stroke(bar, THEME.stroke, 1)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.accent,
        BorderSizePixel = 0,
        Parent = bar,
    })
    corner(fill, 4)
    local text = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = THEME.text,
        Font = Enum.Font.Code,
        TextSize = 11,
        ZIndex = 2,
        Parent = bar,
    })

    suffix = suffix or ""
    step = (tonumber(step) and step > 0) and step or 1
    -- Bulatkan ke kelipatan step (hindari 0.30000000004)
    local function snap(v)
        local n = math.floor((v - min) / step + 0.5) * step + min
        return math.clamp(tonumber(string.format("%.4f", n)), min, max)
    end
    local function show(v)
        if step < 1 then return string.format("%.1f", v) end
        return tostring(v)
    end
    local value = snap(tonumber(default) or min)
    local api = {}
    local function render()
        -- (max - min) bisa 0 bila salah konfigurasi: hindari pembagian nol
        local span = max - min
        fill.Size = UDim2.new(span > 0 and (value - min) / span or 0, 0, 1, 0)
        text.Text = show(value) .. suffix .. "/" .. show(max) .. suffix
    end
    render()

    -- Terapkan nilai baru + panggil callback (dipakai drag dan Set)
    local function apply(v)
        v = snap(tonumber(v) or value)
        if v == value then return end
        value = v
        render()
        if api.Changed then api.Changed(v) end
        if callback then
            task.spawn(function()
                local ok, err = pcall(callback, v)
                if not ok then warn("[ArdHub] " .. title .. ": " .. tostring(err)) end
            end)
        end
    end

    local function setFromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        apply(min + a * (max - min))
    end

    local sliding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            Shield.Visible = true
            setFromX(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    sliding = false
                    Shield.Visible = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)

    function api:Get() return value end
    function api:Set(v) apply(v) end
    table.insert(self.Items, { Row = holder, Text = title })
    return api
end


local Tab = {}
Tab.__index = Tab

function Tab:AddSection(title, side)
    local col = (side == "right") and self.Right or self.Left

    local frame = new("Frame", {
        Name = title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.card,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
        Parent = col,
    })
    corner(frame, 5)
    stroke(frame, THEME.stroke, 1)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

    local header = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        Parent = frame,
    })

    -- Badge ungu transparan di belakang ikon
    local badge = new("Frame", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 8, 0.5, -11),
        BackgroundColor3 = THEME.accent,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        Parent = header,
    })
    corner(badge, 6)
    local icon, setIconColor = makeIcon(badge, ICONS[title], UDim2.new(0.5, -8, 0.5, -8), 16)
    setIconColor(THEME.accent)

    new("TextLabel", {
        Size = UDim2.new(1, -66, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = THEME.text,
        Font = Enum.Font.Code,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })
    local chevron = new("TextLabel", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -26, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "v",
        TextColor3 = THEME.text,
        Font = Enum.Font.Code,
        TextSize = 14,
        Parent = header,
    })

    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = frame,
    })
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8),
        Parent = body,
    })

    local open = true
    header.MouseButton1Click:Connect(function()
        open = not open
        body.Visible = open
        TweenService:Create(chevron, TweenInfo.new(0.15), { Rotation = open and 0 or 180 }):Play()
    end)

    local sec = setmetatable({ Frame = frame, Body = body, Items = {} }, Section)
    table.insert(Sections, sec)
    return sec
end

function AddTab(name) -- mengisi local AddTab di luar blok
    tabCount = tabCount + 1

    local btn = new("TextButton", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = THEME.tabActive,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = tabCount,
        Parent = SideList,
    })
    corner(btn, 5)

    -- Penanda tab aktif (garis ungu di kiri)
    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundColor3 = THEME.accent,
        BorderSizePixel = 0,
        Visible = false,
        Parent = btn,
    })
    corner(bar, 2)

    local _, setIconColor = makeIcon(btn, ICONS[name], UDim2.new(0, 12, 0.5, -8), 16)
    local label = new("TextLabel", {
        Size = UDim2.new(1, -44, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = THEME.muted,
        Font = Enum.Font.Code,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn,
    })

    local page = new("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.stroke,
        CanvasSize = UDim2.new(0, 0, 0, 300),
        Visible = false,
        Parent = Pages,
    })

    local function column(xScale, xOffset)
        local f = new("Frame", {
            Size = UDim2.new(0.5, -5, 0, 0),
            Position = UDim2.new(xScale, xOffset, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
        return f
    end
    local left = column(0, 0)
    local right = column(0.5, 3)

    local function updateCanvas()
        page.CanvasSize = UDim2.new(0, 0, 0, math.max(left.AbsoluteSize.Y, right.AbsoluteSize.Y) + 4)
    end
    left:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
    right:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
    task.defer(updateCanvas)

    local tab = setmetatable({
        Name = name, Button = btn, Label = label, Page = page, Bar = bar,
        Left = left, Right = right, SetIconColor = setIconColor,
    }, Tab)
    table.insert(Tabs, tab)

    btn.MouseButton1Click:Connect(function()
        selectTab(tab)
    end)

    -- Efek hover
    btn.MouseEnter:Connect(function()
        if not tab.Page.Visible then btn.BackgroundTransparency = 0.6 end
    end)
    btn.MouseLeave:Connect(function()
        if not tab.Page.Visible then btn.BackgroundTransparency = 1 end
    end)

    if #Tabs == 1 then
        selectTab(tab)
    end
    return tab
end

-- Toggle UI dengan keyboard
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == TOGGLE_KEY then
        Gui.Enabled = not Gui.Enabled
    end
end)
end -- akhir blok LIBRARY (hanya AddTab yang dipakai di luar)

--------------------------------------------------------------------
-- RUNTIME
--------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- alive = false saat GUI dihancurkan (script dieksekusi ulang). Semua loop
-- memeriksa flag ini supaya instance lama berhenti dengan bersih.
local alive = true
Gui.Destroying:Connect(function()
    alive = false
    -- Pulihkan rendering bila "Disable 3D Rendering" masih aktif saat script ditutup
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
end)

--------------------------------------------------------------------
-- KONFIGURASI GAME  (ISI SESUAI GAME)
-- Nama RemoteEvent/RemoteFunction asli harus kamu cari sendiri
-- (mis. dengan remote spy). Selama masih "" fiturnya tidak mengirim apa pun
-- dan UI menampilkan pemberitahuan.
--------------------------------------------------------------------
local GAME = {
    LobbyPlaceId = 0,          -- PlaceId lobby untuk TeleportService (0 = pakai remote ReturnLobby)
    ReplayUseButton = true,    -- Auto Replay: klik tombol "Play Again" asli dulu (remote hanya cadangan)
    SendReplayLanded = false,  -- ReplayLanded dikirim game sendiri (AFKCamera); true = kirim manual juga
    TimeLabelName = "",        -- (opsional) nama TextLabel timer game di PlayerGui, mis. "Time"
    -- Timer match ada di pojok kanan atas (TopbarPlus): ...TopbarStandard...IconLabel.
    -- Isinya angka polos "1", "2", ... lalu "1:03" setelah 60 detik.
    TimeLabelHint = "TopbarStandard",
    UnitsFolder = "Towers",    -- folder unit milik pemain di Workspace

    -- Remote yang SUDAH diketahui dari remote spy:
    --   ChangeTickSpeed(speed)            RemoteEvent
    --   SetAutoSkip(bool)                 RemoteEvent
    --   SkipMapEntryCutscene()            RemoteEvent
    --   ReplayHeld(map, true)             RemoteEvent
    --   ReplayLanded(map)                 RemoteEvent
    --   PlaceDifficultyVote(map, "dif_x") RemoteFunction
    --   BackToMainLobby                   (argumen belum dicek)
    Remotes = {
        SkipCutscene = "SkipMapEntryCutscene",
        AutoSkip = "SetAutoSkip",
        Speed = "ChangeTickSpeed",      -- argumen 2 (3x diasumsikan argumen 3)
        Restart = "RestartGame",        -- RemoteFunction: RestartGame(map nil, true); dipakai Auto Replay
        -- Auto Replay: RestartGame(map, false) -> ReplayHeld(map, true) -> map baru muncul -> ReplayLanded(mapBaru).
        ReplayHeld = "ReplayHeld",
        ReplayLanded = "ReplayLanded",
        ReturnLobby = "BackToMainLobby",
        Beggar = "",                    -- belum diketahui
        Difficulty = "PlaceDifficultyVote",
        MatchEnd = "ShowGameEnd",       -- DUGAAN dari Cobalt (muncul x2), cek isinya

        -- Remote macro. Nama = Type di file macro (DUGAAN, cek di Cobalt).
        PlaceUnit = "PlaceUnit",
        BuyPlot = "BuyPlot",
        ToggleAutoUpgrade = "ToggleAutoUpgrade", -- RemoteFunction: ToggleAutoUpgrade(id)
        ChangeTarget = "Entity_ChangeTargetingMode", -- RemoteEvent: FireServer(id, mode)
        ActivateUnitAbility = "ActivateUnitAbility", -- RemoteFunction: InvokeServer(id, nil)
        Sell = "SellUnit",              -- RemoteFunction: SellUnit(id)
    },

    -- Penyusun argumen remote macro. SENGAJA KOSONG sampai bentuk argumennya
    -- dikonfirmasi lewat Cobalt (mengirim argumen salah ke server berisiko).
    -- Tiap fungsi menerima (act, ctx) dan mengembalikan tabel argumen.
    -- act = satu aksi dari file macro. ctx berisi:
    --   map, id (ID unit BARU hasil pemetaan), plot, targetMode,
    --   unit, position (Vector3), cframe, rotation (khusus PlaceUnit)
    -- Contoh bentuk (BUKAN nilai asli, isi sesuai Cobalt):
    --   PlaceUnit = function(act, ctx) return { ctx.unit, ctx.cframe } end,
    --   BuyPlot = function(act, ctx) return { ctx.plot } end,
    --   ToggleAutoUpgrade = function(act, ctx) return { ctx.id } end,
    --   ChangeTarget = function(act, ctx) return { ctx.id, ctx.targetMode } end,
    --   ActivateUnitAbility = function(act, ctx) return { ctx.id } end,
    Args = {
        -- PlaceUnit:InvokeServer("unit_xxx", { Valid, WasFastPlaced, PathIndex, Position,
        --   DistanceAlongPath, Rotation, CF, Attempt })
        -- Unit di plot: { CF, WasFastPlaced, Position, Attempt, Valid, Rotation }.
        -- Unit di jalur menambah PathIndex dan DistanceAlongPath (hanya dikirim bila ada di macro).
        PlaceUnit = function(act, ctx)
            local info = {
                Valid = true,
                WasFastPlaced = false,
                Position = ctx.position,
                Rotation = ctx.rotation or 0,
                CF = ctx.cframe,
                Attempt = 1,
            }
            if act.PathIndex then info.PathIndex = act.PathIndex end
            if act.DistanceAlongPath then info.DistanceAlongPath = act.DistanceAlongPath end
            return { ctx.unit, info }
        end,
        ToggleAutoUpgrade = function(act, ctx) return { ctx.id } end,
        ChangeTarget = function(act, ctx) return { ctx.id, ctx.targetMode } end,
        ActivateUnitAbility = function(act, ctx) return { ctx.id } end,
        Sell = function(act, ctx) return { ctx.id } end,
        BuyPlot = function(act, ctx) return { ctx.plot } end,
    },

    -- Kebalikan Args, hanya untuk Record Macro: (args, ctx) -> tabel field
    -- seperti { ID = .., Unit = .., Position = "x, y, z", CF = "12 angka", Rotation = .. }
    Parse = {
        PlaceUnit = function(args, ctx)
            local info = args[2]
            if type(args[1]) ~= "string" or type(info) ~= "table" then return nil end
            local p, cf = info.Position, info.CF
            if typeof(p) ~= "Vector3" or typeof(cf) ~= "CFrame" then return nil end
            local r, id = ctx.result, nil
            local all = ctx.results -- hasil lengkap InvokeServer: { true, ID }
            if all and all[1] == true and type(all[2]) == "number" then
                id = all[2]
            elseif type(r) == "number" then
                id = r
            elseif type(r) == "table" then
                id = r.ID or r.Id or r.id or r[1]
            end
            if type(id) ~= "number" then id = nil end
            return {
                ID = id,
                Unit = args[1],
                Position = string.format("%.4f, %.4f, %.4f", p.X, p.Y, p.Z),
                CF = table.concat({ cf:GetComponents() }, ", "),
                Rotation = info.Rotation,
                Valid = info.Valid,
                PathIndex = info.PathIndex,
                DistanceAlongPath = info.DistanceAlongPath,
            }
        end,
        ToggleAutoUpgrade = function(args)
            if type(args[1]) ~= "number" then return nil end
            return { ID = args[1] }
        end,
        ChangeTarget = function(args)
            if type(args[1]) ~= "number" or type(args[2]) ~= "number" then return nil end
            return { ID = args[1], TargetMode = args[2] }
        end,
        ActivateUnitAbility = function(args)
            if type(args[1]) ~= "number" then return nil end
            return { ID = args[1] }
        end,
        Sell = function(args)
            if type(args[1]) ~= "number" then return nil end
            return { ID = args[1] }
        end,
        -- RemoteEvents.BuyPlot:FireServer(nomorPlot)  (Cobalt)
        BuyPlot = function(args)
            if type(args[1]) ~= "number" then return nil end
            return { Plot = args[1] }
        end,
    },

    -- Opsional: (hasilInvoke, act) -> ID unit baru. Default: angka, atau tabel dengan ID/Id/id/[1].
    ResolveUnitId = nil,

    -- Remote client (incoming) yang argumen pertamanya adalah Instance map.
    -- EnemyDistanceSync terbukti dari screenshot Cobalt; sisanya dugaan (aman kalau salah).
    MapSources = { "PreloadHint", "EnemyDistanceSync", "CreateEntity", "DestroyEntity", "StartDifficultyVote", "StopDifficultyVote", "ReplayLanded" },

    -- Override ID difficulty bila bentuknya tidak "dif_" .. nama huruf kecil
    DifficultyIds = {
        -- Apocalypse = "dif_apocalypse",
    },

    -- Kirim ulang Skip Cutscene / Auto Skip Wave / Speed tiap map baru
    -- (versi lama hanya sekali saat toggle dinyalakan, jadi hilang setelah replay).
    ReapplyPerMatch = true,
    ReapplyDelay = 2,          -- detik setelah map baru terdeteksi

    -- Pembaca statistik untuk Webhook & Dashboard API (best effort).
    -- Dicari berurutan: leaderstats -> Attribute pemain -> nil.
    -- Ganti nama di sini bila game memakai nama lain (cek via Dex).
    StatNames = {
        Seeds = { "Seeds", "Seed", "Coins", "Money" },
        Wave = { "Wave", "CurrentWave" },
        Cash = { "Cash" },
        Candy = { "CurrencyHalloween26" },
    },

    -- Mata uang event yang ikut dicatat (webhook & dashboard). Ganti bila event berganti.
    EventCurrency = "CurrencyHalloween26",
    EventCurrencyTotal = "TotalCurrencyHalloween26Earned", -- total seumur hidup (tidak turun saat belanja)
    EventEmoji = "🍬",
    SeedsEmoji = "🌱",
    -- Nama tampilan map untuk webhook. Map lain otomatis: "map_back_garden" -> "Back Garden"
    MapNames = {
        map_farm = "Farm",
        map_halloween_event26 = "Halloween Event",
    },
    EventCurrencyLabel = "Candy",
}

--------------------------------------------------------------------
-- DATA PEMAIN (dari remote game)
-- RemoteEvents.UpdatePlayerData(kunci, nilai) dikirim server setiap data
-- berubah, mis. ("Cash", 1394), ("Seeds", 53020), ("GamesWon", 553),
-- ("CurrencyHalloween26", 3800). Nilai angka/teks disimpan di PlayerData.
-- PlayerData.cashVersion naik setiap Cash berubah (dipakai Play saat
-- menunggu cash cukup).
--------------------------------------------------------------------
local PlayerData = { values = {}, cashVersion = 0 }
task.spawn(function()
    for _ = 1, 60 do
        local f = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
        local r = f and f:FindFirstChild("UpdatePlayerData")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(key, value)
                if type(key) ~= "string" then return end
                local t = type(value)
                if t == "number" or t == "string" or t == "boolean" then
                    PlayerData.values[key] = value
                    if key == "Cash" then PlayerData.cashVersion = PlayerData.cashVersion + 1 end
                end
            end)
            return
        end
        task.wait(2)
    end
end)

-- Ambil satu nilai data pemain ("Seeds", "TotalSeedsEarned", ...).
-- 1) cache UpdatePlayerData  2) modul data game (ClientDataHandler.GetValueNow),
-- supaya nilai sudah ada sejak awal walau server belum mengirim update.
local dataGet
do
    local mod -- nil = belum dicoba, false = gagal
    function dataGet(key)
        local v = PlayerData.values[key]
        if v ~= nil then return v end
        if mod == nil then
            mod = false
            pcall(function()
                local m = LocalPlayer.PlayerGui.LogicHolder.ClientLoader.Modules.ClientDataHandler
                local t = require(m)
                if type(t) == "table" and type(t.GetValueNow) == "function" then mod = t end
            end)
        end
        if mod then
            local ok, r = pcall(mod.GetValueNow, key)
            if ok and (type(r) == "number" or type(r) == "string") then return r end
        end
        return nil
    end
end

-- Baca angka statistik pemain (data game / leaderstats / Attribute).
-- Mengembalikan number atau nil. Tidak pernah error.
local currentMapRef -- diisi oleh bagian MAP (dipakai di sini untuk Wave)
local function readStat(kind)
    local names = GAME.StatNames[kind] or {}
    -- 1) Data pemain dari game (paling akurat)
    for _, n in ipairs(names) do
        local v = tonumber(dataGet(n))
        if v then return v end
    end
    local ok, val = pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        for _, n in ipairs(names) do
            local v = ls and ls:FindFirstChild(n)
            if v and v:IsA("ValueBase") and tonumber(v.Value) then return tonumber(v.Value) end
            local a = LocalPlayer:GetAttribute(n)
            if tonumber(a) then return tonumber(a) end
            local m = currentMapRef and currentMapRef()
            if m then
                local ma = m:GetAttribute(n)
                if tonumber(ma) then return tonumber(ma) end
            end
        end
        return nil
    end)
    return ok and val or nil
end

--------------------------------------------------------------------
-- NOTIFIKASI (toast kecil di dalam jendela)
--------------------------------------------------------------------
local Toast = new("TextLabel", {
    Name = "Toast",
    Size = UDim2.new(0, 320, 0, 22),
    Position = UDim2.new(0.5, -160, 1, -50),
    BackgroundColor3 = THEME.card,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = THEME.text,
    Font = Enum.Font.Code,
    TextSize = 12,
    Visible = false,
    ZIndex = 30,
    Parent = Main,
})
corner(Toast, 4)
stroke(Toast, THEME.accent, 1)

local toastToken = 0
local function notify(text)
    print("[ArdHub] " .. tostring(text))
    toastToken = toastToken + 1
    local my = toastToken
    Toast.Text = tostring(text)
    Toast.Visible = true
    task.delay(3, function()
        if toastToken == my then
            Toast.Visible = false
        end
    end)
end

local warned = {}
local function notifyOnce(key, text)
    if not warned[key] then
        warned[key] = true
        notify(text)
    end
end

-- Kotak status "Playing macro": ScreenGui terpisah, tetap terlihat walau UI script disembunyikan.
local StatusGui = new("ScreenGui", {
    Name = "ArdHubStatus",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 11,
    IgnoreGuiInset = true,
})
setParent(StatusGui)
local StatusBox = new("TextLabel", {
    Name = "PlayStatus",
    AnchorPoint = Vector2.new(0.5, 0),
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 0, 26),
    Position = UDim2.new(0.5, 0, 0, 10),
    BackgroundColor3 = THEME.card,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = THEME.text,
    Font = Enum.Font.Code,
    TextSize = 13,
    Visible = false,
    Parent = StatusGui,
})
corner(StatusBox, 5)
stroke(StatusBox, THEME.accent, 1)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = StatusBox })
local function setPlayStatus(text)
    if text then
        StatusBox.Text = text
        StatusBox.Visible = true
    else
        StatusBox.Visible = false
    end
end
Gui.Destroying:Connect(function() StatusGui:Destroy() end)

--------------------------------------------------------------------
-- STATE & LOOP
--------------------------------------------------------------------
-- Cfg = nilai setting (diubah lewat UI). State = status fitur yang sedang berjalan.
local Cfg = {
    difficulty = "Normal",
    spread = 0.3,           -- Placement Spread (studs): geseran kecil bila posisi terisi
    microTeleport = 3,      -- radius acak (studs) titik mendarat mikro-teleport
    walkRadius = 6,         -- radius Auto Walk di sekitar unit
    walkMin = 4, walkMax = 9, -- interval acak Auto Walk (detik)
    telemetryUrl = "",
    discordUserId = "",     -- ID user Discord untuk di-tag (angka, Developer Mode -> Copy User ID)
    tagTarget = true,       -- tag saat target tercapai
    tagMatch = false,       -- tag di setiap webhook akhir match
    tagDefeat = false,      -- tag hanya saat Defeat
    telemetryKey = "",
    telemetryInterval = 30,
    matchesBeforeReturn = 1,
    placementTimed = true,
    sellTimed = true,
    abilityTimed = true,
    teleportBeforePlace = false,
    disableTiming = false,
    disableAfter = 0,
}
local State = {
    recArmed = false, macroPlay = false, autoDiff = false, autoReplay = false,
    autoReturn = false, returnAfterX = false, webhook = false, autoWalk = false,
    telemetry = false, skipCutscene = false, autoSkipWave = false, autoAbility = false,
}
local tokens = {}

-- Membuat callback toggle yang menjalankan fn tiap `interval` detik selama toggle menyala.
local function bindLoop(key, interval, fn)
    return function(v)
        tokens[key] = (tokens[key] or 0) + 1
        if not v then return end
        local my = tokens[key]
        task.spawn(function()
            while alive and tokens[key] == my do
                local ok, err = pcall(fn)
                if not ok then warn("[ArdHub] " .. key .. ": " .. tostring(err)) end
                task.wait(interval)
            end
        end)
    end
end

--------------------------------------------------------------------
-- REMOTE
--------------------------------------------------------------------
local remoteCache = {}
local function getRemote(key)
    local name = GAME.Remotes[key]
    if not name or name == "" then
        notifyOnce("remote_" .. key, "GAME.Remotes." .. key .. " belum diisi")
        return nil
    end
    local r = remoteCache[name]
    if r and r.Parent then return r end
    r = ReplicatedStorage:FindFirstChild(name, true)
    if not r then
        notifyOnce("missing_" .. key, "Remote '" .. name .. "' tidak ditemukan")
        return nil
    end
    remoteCache[name] = r
    return r
end

local function fireRemote(key, ...)
    local r = getRemote(key)
    if not r then return false end
    if r:IsA("RemoteEvent") then
        r:FireServer(...)
        return true
    elseif r:IsA("RemoteFunction") then
        task.spawn(r.InvokeServer, r, ...)
        return true
    end
    return false
end

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getUnits()
    local f = workspace:FindFirstChild(GAME.UnitsFolder)
    return f and f:GetChildren() or {}
end

-- Titik jalan Auto Walk: posisi unit yang dipasang macro (cadangan kalau folder unit tidak terbaca)
local walkPoints = {}
local function addWalkPoint(pos)
    if typeof(pos) ~= "Vector3" then return end
    for _, q in ipairs(walkPoints) do
        if (q - pos).Magnitude < 0.5 then return end
    end
    walkPoints[#walkPoints + 1] = pos
    if #walkPoints > 200 then table.remove(walkPoints, 1) end
end

--------------------------------------------------------------------
-- MAP ID (Instance bernama GUID yang berganti tiap replay)
-- Diambil dari argumen pertama remote incoming (lihat GAME.MapSources).
-- Map lama ditandai "retired" setelah ReplayHeld supaya event telat dari
-- map lama tidak menimpa map baru.
--------------------------------------------------------------------
local GUID_PATTERN = "^%x+%-%x+%-%x+%-%x+%-%x+$"
local currentMap = nil
currentMapRef = function() return currentMap end
local lastMapName = nil
local triggerMatchEnd -- diisi di bagian ALUR AKHIR MATCH
local matchOver = false -- true setelah event akhir match, false lagi saat map baru muncul
local retired = setmetatable({}, { __mode = "k" })
local MapChanged = Instance.new("BindableEvent")
local watched = {}
-- Map yang terbukti MATCH (bukan lobby): pernah muncul di event khusus match.
-- Lobby juga punya context bernama GUID di workspace.Contexts, jadi tanpa ini
-- lobby ikut dianggap match (vote & Play jalan di lobby).
local MatchMaps = setmetatable({}, { __mode = "k" })
local MATCH_EVENTS = {
    StartDifficultyVote = true, StopDifficultyVote = true, EnemyDistanceSync = true,
    CreateEntity = true, DestroyEntity = true, ReplayLanded = true,
}
local VoteOpen = setmetatable({}, { __mode = "k" }) -- map -> true selama layar vote terbuka
local lastEnemyAt = 0 -- os.clock() terakhir ada data musuh (EnemyDistanceSync) = match sedang berjalan
local function isMatchMap(m) return m ~= nil and MatchMaps[m] == true end
local ctxWatched = nil

local function isMapInstance(inst)
    if typeof(inst) ~= "Instance" then return false end
    local n = tostring(inst.Name)
    return n:match(GUID_PATTERN) ~= nil or n:match("^td_%d+$") ~= nil
end

-- PENJAGA LOBBY: semua fitur yang mempengaruhi match hanya jalan bila inMatch().
-- MatchDetected menyala sekali saat sebuah map pertama kali terbukti match.
local MatchDetected = Instance.new("BindableEvent")
local function markMatch(m)
    if isMapInstance(m) and not MatchMaps[m] then
        MatchMaps[m] = true
        MatchDetected:Fire(m)
    end
end
-- Sedang di match yang masih berjalan (bukan lobby, bukan layar akhir)
local function inMatch()
    return isMatchMap(currentMap) and not matchOver
end

-- Koneksi AncestryChanged ke map aktif. FIX MEMORY LEAK: dulu setiap map baru diberi
-- koneksi yang tidak pernah diputus. Map lama dilepas game ke nil (bukan Destroy), dan
-- koneksi itu menahan seluruh model map di memori -> memori naik tiap match -> crash.
local mapAncestryConn = nil
local function onMapSeen(inst)
    if inst == currentMap or retired[inst] or not isMapInstance(inst) then return end
    if mapAncestryConn then mapAncestryConn:Disconnect() mapAncestryConn = nil end
    currentMap = inst
    lastMapName = inst.Name
    matchOver = false
    MapChanged:Fire(inst)
    -- Cadangan pendeteksi akhir match: map dilepas dari workspace (parent jadi nil)
    mapAncestryConn = inst.AncestryChanged:Connect(function(_, parent)
        if parent ~= nil or not alive then return end
        if mapAncestryConn then mapAncestryConn:Disconnect() mapAncestryConn = nil end
        if currentMap ~= inst or retired[inst] then return end
        task.wait(0.5)
        if alive and currentMap == inst and not retired[inst] then
            triggerMatchEnd(nil)
        end
    end)
end

-- Map aktif ada di workspace.Contexts[GUID]. Referensi tetap disimpan setelah map
-- dilepas (parent nil) saat match selesai, karena ReplayHeld memakai map lama itu.
local function watchContexts()
    local folder = workspace:FindFirstChild("Contexts")
    if not folder then return end
    if ctxWatched ~= folder then
        ctxWatched = folder
        folder.ChildAdded:Connect(function(child)
            task.defer(function()
                if not alive or not isMapInstance(child) then return end
                if currentMap and currentMap ~= child then
                    retired[currentMap] = true -- event telat dari map lama diabaikan
                end
                onMapSeen(child)
            end)
        end)
    end
    if currentMap == nil or currentMap.Parent == nil then
        local kids = folder:GetChildren()
        for i = #kids, 1, -1 do
            if isMapInstance(kids[i]) and not retired[kids[i]] then
                onMapSeen(kids[i])
                break
            end
        end
    end
end

local function watchMapSources()
    for _, name in ipairs(GAME.MapSources) do
        if not watched[name] then
            local r = ReplicatedStorage:FindFirstChild(name, true)
            if r and r:IsA("RemoteEvent") then
                watched[name] = true
                r.OnClientEvent:Connect(function(first)
                    if not alive then return end
                    if MATCH_EVENTS[name] then markMatch(first) end
                    if name == "EnemyDistanceSync" then lastEnemyAt = os.clock() end
                    if name == "StartDifficultyVote" and isMapInstance(first) then VoteOpen[first] = true end
                    if name == "StopDifficultyVote" and isMapInstance(first) then VoteOpen[first] = nil end
                    onMapSeen(first)
                end)
            end
        end
    end
end

task.spawn(function()
    while alive do
        pcall(watchContexts)
        pcall(watchMapSources)
        task.wait(2)
    end
end)

-- Cadangan: map lama yang sudah dilepas (parent nil) bisa dicari lewat getnilinstances
local function findNilMap()
    if not getnilinstances then return nil end
    local found
    local ok = pcall(function()
        for _, o in ipairs(getnilinstances()) do
            if isMapInstance(o) and not retired[o] then
                if found then found = false return end -- lebih dari satu: ambigu
                found = o
            end
        end
    end)
    if ok and found then return found end
    return nil
end

-- Instance map yang dipakai game untuk ReplayHeld: instance nil dengan nama GUID map.
-- Utamakan referensi yang kita simpan; kalau tidak ada di daftar nil, cari lewat nama.
local function resolveReplayMap()
    local m = currentMap
    local name = (m and m.Name) or lastMapName
    if name and getnilinstances then
        local byName
        pcall(function()
            for _, o in ipairs(getnilinstances()) do
                if o == m then byName = o return end
                if not byName and typeof(o) == "Instance" and o.Name == name then
                    byName = o
                end
            end
        end)
        if byName then return byName end
    end
    return m or findNilMap()
end

-- Status replay: mencegah dua replay berjalan bersamaan.
local replaying = false

-- Layar akhir match terlihat? (tombol "Mainkan Lagi" / "Play Again" di PlayerGui)
local REPLAY_TEXTS = { "mainkan lagi", "play again", "replay" }
local function guiShown(d)
    local p = d
    while p and p ~= game do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        p = p.Parent
    end
    return true
end
-- Teks yang terlihat di layar: tanpa tag RichText, tanpa spasi tepi, huruf kecil.
local function guiText(d)
    local ok, t = pcall(function() return d.ContentText end)
    t = (ok and type(t) == "string" and t ~= "") and t or d.Text
    t = t:gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return t:lower()
end

local function endScreenVisible()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Text ~= "" and #d.Text < 60 then
            local t = guiText(d)
            for _, k in ipairs(REPLAY_TEXTS) do
                if t == k and guiShown(d) then return true end
            end
        end
    end
    return false
end

-- Auto Replay: RestartGame(true). Kalau remote tidak ada, pakai cara lama (ReplayHeld).
local lastReplayAt = -100
local clickGuiByText -- didefinisikan di bagian ALUR AKHIR MATCH

-- forceRemote = true: lewati klik tombol, langsung lewat remote (dipakai saat percobaan ulang)
local function doReplay(forceRemote)
    if replaying or os.clock() - lastReplayAt < 15 then return false end
    local prev = currentMap
    replaying = true

    -- Berhasil bila map baru muncul, atau layar akhir match hilang
    local function waitReplay(limit)
        local t0 = os.clock()
        while alive and os.clock() - t0 < limit do
            task.wait(0.5)
            if (currentMap ~= nil and currentMap ~= prev)
                or (os.clock() - t0 > 2 and not endScreenVisible()) then
                return true
            end
        end
        return false
    end

    local ok = false
    local clicked = false

    -- 1) Klik tombol "Play Again" asli. Game sendiri lalu mengirim RestartGame(mapLama, false),
    --    ReplayHeld(mapLama, true) dan (lewat AFKCamera) ReplayLanded(mapBaru), serta transisi kamera.
    local how = (GAME.ReplayUseButton and not forceRemote) and clickGuiByText({ "play again", "mainkan lagi" })
    if how then
        print("[ArdHub] tombol Play Again diklik (" .. tostring(how) .. ")")
        clicked = true
        ok = waitReplay(12)
        if not ok then print("[ArdHub] klik Play Again sudah dikirim sekali, tidak diulang") end
    end

    -- 2) Lewat remote HANYA bila tombol tidak ditemukan (tidak ada pengiriman ganda setelah klik)
    if not ok and not clicked then
        local rfName = GAME.Remotes.Restart
        local rf = rfName and rfName ~= "" and ReplicatedStorage:FindFirstChild(rfName, true)
        local map = resolveReplayMap() -- instance nil bernama GUID map lama
        if not rf then
            replaying = false
            notify("Remote RestartGame tidak ditemukan")
            return false
        end
        if not map then
            replaying = false
            notify("Map belum terdeteksi")
            return false
        end
        retired[map] = true -- event telat dari map lama diabaikan
        if prev then retired[prev] = true end
        local restartFailed = false
        task.spawn(function()
            local sent, res
            if rf:IsA("RemoteFunction") then
                sent, res = pcall(rf.InvokeServer, rf, map, false)
            else
                sent, res = pcall(rf.FireServer, rf, map, false)
            end
            print("[ArdHub] RestartGame(" .. map.Name .. ", false) -> ok=" .. tostring(sent)
                .. " hasil=" .. tostring(res))
            if not sent then restartFailed = true end
        end)
        task.wait(0.4)
        if restartFailed then
            retired[map] = nil
            if prev then retired[prev] = nil end
            replaying = false
            notify("RestartGame gagal dikirim")
            return false
        end
        -- ReplayHeld dikirim sendiri oleh script game (AFKCamera) setelah RestartGame.
        -- FIX: dulu script juga mengirim -> ReplayHeld dobel (terlihat di Cobalt:
        -- AFKCamera + Delta). Sekarang hanya dikirim sebagai CADANGAN bila 6 detik
        -- setelah RestartGame replay belum berjalan.
        ok = waitReplay(6)
        if not ok and alive then
            local held = fireRemote("ReplayHeld", map, true)
            print("[ArdHub] ReplayHeld(" .. map.Name .. ", true) cadangan -> terkirim=" .. tostring(held))
            ok = waitReplay(14)
        end
        if not ok then
            retired[map] = nil
            if prev then retired[prev] = nil end
        elseif GAME.SendReplayLanded then
            task.spawn(function()
                local t1 = os.clock()
                while alive and (currentMap == nil or currentMap == prev or currentMap == map)
                    and os.clock() - t1 < 20 do
                    task.wait(0.2)
                end
                if alive and currentMap and currentMap ~= prev and currentMap ~= map then
                    task.wait(1)
                    local landed = fireRemote("ReplayLanded", currentMap)
                    print("[ArdHub] ReplayLanded(" .. currentMap.Name .. ") -> terkirim=" .. tostring(landed))
                end
            end)
        end
    end

    replaying = false
    if ok then
        lastReplayAt = os.clock()
        notify("Replay berjalan")
        task.spawn(function()
            for _, d in ipairs({ 3, 7 }) do
                task.wait(d)
                local cam = workspace.CurrentCamera
                if cam then
                    print("[ArdHub] kamera setelah replay: tipe=" .. tostring(cam.CameraType)
                        .. " subjek=" .. tostring(cam.CameraSubject))
                end
            end
        end)
    else
        notify("Replay dikirim, tapi layar akhir match masih ada")
    end
    return ok
end

local function difficultyId(name)
    return GAME.DifficultyIds[name] or ("dif_" .. tostring(name):lower())
end

--------------------------------------------------------------------
-- WEBHOOK
--------------------------------------------------------------------
local webhookInput -- diisi saat UI dibuat

local function validWebhook(url)
    if type(url) ~= "string" then return false end
    return url:match("^https://[%w]*%.?discord%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
end

-- mention = true: tag user Discord (Cfg.discordUserId) di atas embed, supaya HP berbunyi.
local function sendWebhook(embed, mention)
    local url = webhookInput and webhookInput:Get() or ""
    if not validWebhook(url) then
        notify("Webhook Link tidak valid")
        return false
    end
    local req = (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)
    if not req then
        notify("Executor tidak mendukung request()")
        return false
    end
    local payload = { username = "Ard Hub", embeds = { embed }, allowed_mentions = { parse = {} } }
    local uid = tostring(Cfg.discordUserId or "")
    if mention and uid:match("^%d+$") and #uid >= 15 then
        payload.content = "<@" .. uid .. ">"
        payload.allowed_mentions = { users = { uid } } -- hanya user ini yang boleh di-tag
    end
    local body = jsonEncode(payload)
    if not body then
        notify("Gagal menyusun data webhook")
        return false
    end
    local ok, res = pcall(req, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    -- FIX: beberapa executor mengembalikan StatusCode sebagai string -> dulu error saat dibandingkan
    local code = ok and type(res) == "table" and tonumber(res.StatusCode or res.status_code) or nil
    if code and code >= 200 and code < 300 then
        return true
    end
    notify("Webhook gagal dikirim" .. (code and (" (" .. tostring(code) .. ")") or ""))
    return false
end


local function pick(data, keys)
    if type(data) ~= "table" then return nil end
    for _, k in ipairs(keys) do
        if data[k] ~= nil then return data[k] end
    end
    return nil
end

-- Statistik sesi (dipakai Webhook dan Dashboard API)
local totalMatches = 0
local Session = {
    startedAt = os.time(),
    lastResult = "-",
    lastWave = nil,
    wins = 0,
    losses = 0,
    rewards = {},      -- pesan hadiah match yang baru selesai, mis. "You got 830 Candy!"
    base = {},         -- total Seeds/Candy saat script mulai
    matchStart = {},   -- total Seeds/Candy saat match ini mulai
    mapId = nil,       -- dari StartDifficultyVote, mis. "map_farm"
    difficulty = nil,  -- mis. "dif_hard"
    avatar = nil,      -- URL foto profil (thumbnail webhook)
}

-- Total seumur hidup (tidak turun saat dibelanjakan) -> dipakai untuk menghitung "didapat"
local function totals()
    return {
        seeds = tonumber(dataGet("TotalSeedsEarned")),
        candy = tonumber(dataGet(GAME.EventCurrencyTotal)),
    }
end
task.defer(function()
    -- Data bisa belum siap saat script baru jalan: coba beberapa kali
    for _ = 1, 30 do
        local t = totals()
        if Session.base.seeds == nil then Session.base.seeds = t.seeds end
        if Session.base.candy == nil then Session.base.candy = t.candy end
        if Session.base.seeds and Session.base.candy then break end
        task.wait(2)
    end
end)
MatchDetected.Event:Connect(function()
    Session.matchStart = totals()
end)

-- Foto profil pemain untuk thumbnail webhook (sekali saja)
task.spawn(function()
    pcall(function()
        local raw = game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="
            .. LocalPlayer.UserId .. "&size=150x150&format=Png&isCircular=false")
        local d = jsonDecode(raw)
        local url = d and d.data and d.data[1] and d.data[1].imageUrl
        if type(url) == "string" and url:match("^https://") then Session.avatar = url end
    end)
end)

-- ShowMessage(teks, tipe, info): simpan pesan hadiah (tipe "item") untuk webhook
task.spawn(function()
    for _ = 1, 60 do
        local f = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
        local r = f and f:FindFirstChild("ShowMessage")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(text, kind)
                if type(text) == "string" and kind == "item" and #Session.rewards < 10 then
                    table.insert(Session.rewards, text)
                end
            end)
            return
        end
        task.wait(2)
    end
end)

-- Didapat sejak script dijalankan. kind = "seeds" | "candy". nil bila tidak terbaca.
local function earnedSince(base, kind)
    local now = totals()[kind]
    if now and base and base[kind] then return now - base[kind] end
    return nil
end
-- Dipakai Dashboard API (nama lama dipertahankan)
local function seedsEarned() return earnedSince(Session.base, "seeds") end

-- Ambil tabel data dari argumen ShowGameEnd.
-- Dari Cobalt: ShowGameEnd(map, { Victory = bool, CanReplay, RunTime = detik,
--   WavesCleared, PlayerData = { [NamaPemain] = { Kills, DamageDealt,
--   UpgradesThisGame, ... } } })
-- FIX: dulu yang diambil argumen ke-1 (Instance map), jadi data selalu kosong.
local function gameEndData(packed)
    if type(packed) ~= "table" then return nil end
    for i = 1, packed.n or #packed do
        if type(packed[i]) == "table" then return packed[i] end
    end
    return nil
end

-- Hasil match sebagai teks: "Victory" / "Defeat" / nil
local function resultText(data)
    if type(data) ~= "table" then return nil end
    if type(data.Victory) == "boolean" then return data.Victory and "Victory" or "Defeat" end
    local r = pick(data, { "Result", "result", "Status", "status" })
    return r and tostring(r) or nil
end

--------------------------------------------------------------------
-- WEBHOOK EMBED (format: Match / Rewards / Session / Account)
--------------------------------------------------------------------
local selectedMacroRef -- diisi bagian MACRO FILE (nama macro aktif)
local buildMatchEmbed, buildSummaryEmbed, buildAlertEmbed
do
    -- 625737.99 -> "625,738"
    local function fmtNum(n)
        n = tonumber(n)
        if not n then return "-" end
        local neg = n < 0
        local s = tostring(math.floor(math.abs(n) + 0.5))
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    -- detik -> "4:26" atau "1:13:14"
    local function fmtTime(sec)
        sec = tonumber(sec)
        if not sec then return "-" end
        sec = math.floor(sec)
        local h, m, x = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, x) end
        return string.format("%d:%02d", m, x)
    end
    -- "map_back_garden" -> "Back Garden"
    local function prettyId(id, prefix)
        if type(id) ~= "string" then return nil end
        if prefix == "map_" and GAME.MapNames[id] then return GAME.MapNames[id] end
        local s = id:gsub("^" .. prefix, ""):gsub("_", " ")
        return (s:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
    end
    local function perHour(n)
        local hours = math.max(os.time() - Session.startedAt, 60) / 3600
        return n and fmtNum(n / hours) or "-"
    end

    -- startSnap/rewardList: patokan & pesan hadiah match yang dilaporkan (dibekukan saat match selesai)
    function buildMatchEmbed(data, isTest, startSnap, rewardList)
        local result = resultText(data)
        local me = type(data) == "table" and type(data.PlayerData) == "table"
            and data.PlayerData[LocalPlayer.Name] or nil
        local wave = pick(data, { "WavesCleared", "Wave" }) or Session.lastWave
        local E, S = GAME.EventEmoji, GAME.SeedsEmoji
        local cur = GAME.EventCurrencyLabel

        -- MATCH
        local where = {}
        table.insert(where, prettyId(Session.mapId, "map_") or "Unknown map")
        local diff = prettyId(Session.difficulty, "dif_")
        if diff then table.insert(where, diff) end
        local matchLines = {
            "**" .. (isTest and "Test" or (result or "Selesai")) .. "**",
            table.concat(where, " · "),
            "Wave " .. (wave and fmtNum(wave) or "-") .. " · " .. fmtTime(pick(data, { "RunTime" })),
            fmtNum(me and me.Kills) .. " kills · " .. fmtNum(me and me.DamageDealt) .. " damage",
        }

        -- REWARDS (selisih total sejak match mulai; cadangan: pesan "You got ...")
        local rewards = {}
        local gotCandy = earnedSince(startSnap or Session.matchStart, "candy")
        local gotSeeds = earnedSince(startSnap or Session.matchStart, "seeds")
        if gotCandy and gotCandy > 0 then table.insert(rewards, E .. " +" .. fmtNum(gotCandy) .. " " .. cur) end
        if gotSeeds and gotSeeds > 0 then table.insert(rewards, S .. " +" .. fmtNum(gotSeeds) .. " Seeds") end
        if #rewards == 0 then
            for _, t in ipairs(rewardList or Session.rewards) do
                table.insert(rewards, (t:gsub("^You got ", "+"):gsub("!$", "")))
            end
        end

        -- SESSION
        local sesSeeds = earnedSince(Session.base, "seeds")
        local sesCandy = earnedSince(Session.base, "candy")
        local sessionLines = {
            fmtNum(totalMatches) .. " matches · " .. fmtNum(Session.wins) .. " wins",
            S .. " " .. fmtNum(sesSeeds) .. " seeds · " .. perHour(sesSeeds) .. "/hour",
            E .. " " .. fmtNum(sesCandy) .. " " .. cur:lower() .. " · " .. perHour(sesCandy) .. "/hour",
            "Running " .. fmtTime(os.time() - Session.startedAt),
        }

        -- ACCOUNT (nama disembunyikan dengan spoiler Discord)
        local accountLines = {
            "||" .. LocalPlayer.Name .. "||",
            S .. " " .. fmtNum(readStat("Seeds")) .. " seeds",
            E .. " " .. fmtNum(readStat("Candy")) .. " " .. cur:lower(),
        }

        return {
            title = "Garden Tower Defense",
            color = result == "Victory" and 0x2ECC71 or (result == "Defeat" and 0xE74C3C or 0x7C5CFF),
            thumbnail = Session.avatar and { url = Session.avatar } or nil,
            fields = {
                { name = "Match", value = table.concat(matchLines, "\n"), inline = false },
                { name = "Rewards", value = #rewards > 0 and table.concat(rewards, "\n") or "-", inline = true },
                { name = "Session", value = table.concat(sessionLines, "\n"), inline = true },
                { name = "Account", value = table.concat(accountLines, "\n"), inline = false },
            },
            footer = { text = "Ard Hub by Ardhi • " .. VERSION },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end

    -- Status singkat akun: "In Match · Halloween Event · Apocalypse" / "Lobby"
    local function statusText()
        if inMatch() then
            local parts = { "In Match", prettyId(Session.mapId, "map_") or "Unknown map" }
            local d = prettyId(Session.difficulty, "dif_")
            if d then table.insert(parts, d) end
            return table.concat(parts, " · ")
        elseif matchOver and isMatchMap(currentMap) then
            return "Layar akhir match"
        end
        return "Lobby"
    end
    local function accountText()
        local E, S = GAME.EventEmoji, GAME.SeedsEmoji
        return table.concat({
            "||" .. LocalPlayer.Name .. "||",
            S .. " " .. fmtNum(readStat("Seeds")) .. " seeds",
            E .. " " .. fmtNum(readStat("Candy")) .. " " .. GAME.EventCurrencyLabel:lower(),
        }, "\n")
    end

    -- RINGKASAN BERKALA: laporan sesi walau tidak ada match yang selesai
    function buildSummaryEmbed()
        local E, S = GAME.EventEmoji, GAME.SeedsEmoji
        local cur = GAME.EventCurrencyLabel
        local decided = Session.wins + Session.losses
        local sesSeeds = earnedSince(Session.base, "seeds")
        local sesCandy = earnedSince(Session.base, "candy")
        local macroName = selectedMacroRef and selectedMacroRef() or nil
        return {
            title = "Ringkasan Sesi · Garden Tower Defense",
            color = 0x7C5CFF,
            thumbnail = Session.avatar and { url = Session.avatar } or nil,
            fields = {
                { name = "Status", value = statusText() .. "\n" .. (State.macroPlay and ("▶ " .. tostring(macroName or "-"))
                    or "Play Macro: off"), inline = false },
                { name = "Session", value = table.concat({
                    fmtNum(totalMatches) .. " matches",
                    fmtNum(Session.wins) .. " wins · " .. fmtNum(Session.losses) .. " losses",
                    "Win rate " .. (decided > 0 and (math.floor(Session.wins / decided * 100 + 0.5) .. "%") or "-"),
                    "Running " .. fmtTime(os.time() - Session.startedAt),
                }, "\n"), inline = true },
                { name = "Earned", value = table.concat({
                    S .. " " .. fmtNum(sesSeeds) .. " seeds",
                    "· " .. perHour(sesSeeds) .. "/hour",
                    E .. " " .. fmtNum(sesCandy) .. " " .. cur:lower(),
                    "· " .. perHour(sesCandy) .. "/hour",
                }, "\n"), inline = true },
                { name = "Account", value = accountText(), inline = false },
            },
            footer = { text = "Ard Hub by Ardhi • " .. VERSION },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end

    -- NOTIFIKASI EVENT: judul + penjelasan + status/akun singkat
    function buildAlertEmbed(title, desc, color)
        return {
            title = title,
            description = desc,
            color = color or 0xE67E22,
            fields = {
                { name = "Status", value = statusText(), inline = true },
                { name = "Session", value = fmtNum(totalMatches) .. " matches · Running "
                    .. fmtTime(os.time() - Session.startedAt), inline = true },
                { name = "Account", value = accountText(), inline = false },
            },
            footer = { text = "Ard Hub by Ardhi • " .. VERSION },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end
end

--------------------------------------------------------------------
-- TARGET & RINGKASAN BERKALA (Discord)
-- Memakai link webhook yang sama dengan webhook akhir match.
--   target  : Seeds / Candy yang didapat sesi ini mencapai target (sekali, bisa tag user)
--   summary : laporan sesi tiap N menit
--------------------------------------------------------------------
local Alerts = {
    cfg = {
        target = false, targetCandy = 0, targetSeeds = 0,
        summary = false, summaryMinutes = 60,
    },
    last = {},          -- jenis -> os.clock() terakhir dikirim
    hit = {},           -- target yang sudah tercapai (dikirim sekali)
    nextSummary = nil,  -- os.clock() ringkasan berikutnya
}
function Alerts.send(key, title, desc, color, force, mention)
    if not force and Alerts.last[key] and os.clock() - Alerts.last[key] < 300 then return false end
    Alerts.last[key] = os.clock()
    local ok, res = pcall(sendWebhook, buildAlertEmbed(title, desc, color), mention)
    return ok and res
end

-- Target & ringkasan berkala: dicek tiap 30 detik
task.spawn(function()
    while alive do
        task.wait(30)
        local c = Alerts.cfg
        if c.target then
            local cur = GAME.EventCurrencyLabel
            local candy = earnedSince(Session.base, "candy")
            local seeds = earnedSince(Session.base, "seeds")
            if c.targetCandy > 0 and candy and candy >= c.targetCandy and not Alerts.hit.candy then
                Alerts.hit.candy = true
                Alerts.send("target_candy", "🎯 Target " .. cur .. " tercapai",
                    string.format("Sesi ini sudah mendapat **%d %s** (target %d).", candy, cur, c.targetCandy), 0x2ECC71, true,
                    Cfg.tagTarget)
            end
            if c.targetSeeds > 0 and seeds and seeds >= c.targetSeeds and not Alerts.hit.seeds then
                Alerts.hit.seeds = true
                Alerts.send("target_seeds", "🎯 Target Seeds tercapai",
                    string.format("Sesi ini sudah mendapat **%d Seeds** (target %d).", seeds, c.targetSeeds), 0x2ECC71, true,
                    Cfg.tagTarget)
            end
        end
        if c.summary then
            Alerts.nextSummary = Alerts.nextSummary or (os.clock() + c.summaryMinutes * 60)
            if os.clock() >= Alerts.nextSummary then
                Alerts.nextSummary = os.clock() + c.summaryMinutes * 60
                pcall(sendWebhook, buildSummaryEmbed())
            end
        else
            Alerts.nextSummary = nil
        end
    end
end)

--------------------------------------------------------------------
-- DASHBOARD API (TELEMETRY)
-- Mengirim status akun ke backend dashboard (Langkah 2 proyek) via POST JSON:
--   {
--     "username": "...", "userId": 123, "placeId": 0, "jobId": "...",
--     "status": "lobby" | "in_match" | "match_end",
--     "wave": 12, "seeds": 4500, "earned": 1200,
--     "match": { "count": 5, "wins": 4, "losses": 1, "lastResult": "Victory" },
--     "macro": { "playing": true, "name": "farm.json" },
--     "event": "heartbeat" | "match_end" | "test",
--     "version": "v2.0.0", "timestamp": 1731300000
--   }
-- Header: Content-Type: application/json, X-Api-Key: <kunci dari UI>
--------------------------------------------------------------------
local httpReq = (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)

-- POST JSON generik. Mengembalikan (berhasil, statusCode).
local function postJson(url, body, headers)
    if not httpReq then return false, nil end
    local enc = jsonEncode(body)
    if not enc then return false, nil end
    local h = { ["Content-Type"] = "application/json" }
    for k, v in pairs(headers or {}) do h[k] = v end
    local ok, res = pcall(httpReq, { Url = url, Method = "POST", Headers = h, Body = enc })
    local code = ok and type(res) == "table" and tonumber(res.StatusCode or res.status_code) or nil
    return (code ~= nil and code >= 200 and code < 300), code
end

local function currentStatus()
    if matchOver then return "match_end" end
    if isMatchMap(currentMap) and currentMap.Parent ~= nil then return "in_match" end
    return "lobby"
end

-- Susun payload telemetry sesuai kontrak API di atas
-- matchCtx (hanya saat match_end) = { data, startSnap, rewardList, map, difficulty, result }
-- Helper dibuat lokal di dalam fungsi supaya tidak menambah local tingkat atas (batas register Luau).
local function buildTelemetry(event, matchCtx)
    -- Salin tabel datar yang aman untuk JSON (maks 50 pasangan)
    local function jsonSafeFlat(t)
        if type(t) ~= "table" then return nil end
        local out, n = {}, 0
        for k, v in pairs(t) do
            local tk, tv = type(k), type(v)
            if (tk == "string" or tk == "number") and (tv == "string" or tv == "number" or tv == "boolean") then
                out[tostring(k)] = v
                n = n + 1
                if n >= 50 then break end
            end
        end
        return n > 0 and out or nil
    end
    -- Ringkasan hasil match untuk dashboard (dari data ShowGameEnd)
    local function buildMatchResult(data, startSnap, rewardList, mapId, difficulty, result)
        local me = type(data) == "table" and type(data.PlayerData) == "table"
            and data.PlayerData[LocalPlayer.Name] or nil
        if type(me) ~= "table" then me = nil end
        local victory = nil
        if type(data) == "table" and type(data.Victory) == "boolean" then victory = data.Victory end
        if victory == nil and type(result) == "string" and result ~= "" then
            local low = result:lower()
            if low:find("vic") or low:find("win") or low:find("menang") then victory = true
            elseif low:find("def") or low:find("lose") or low:find("kalah") then victory = false end
        end
        local rewards = {}
        for _, t in ipairs(rewardList or {}) do
            local amt, item = tostring(t):match("([%d,%.]+)%s+(.-)%s*!?$")
            table.insert(rewards, { text = tostring(t), amount = amt and tonumber((amt:gsub(",", ""))) or nil, item = item })
        end
        return {
            map = mapId,
            difficulty = difficulty,
            victory = victory,
            tie = type(data) == "table" and data.Tie == true or nil,
            runTime = tonumber(pick(data, { "RunTime" })),
            wavesCleared = tonumber(pick(data, { "WavesCleared", "Wave" })),
            kills = me and tonumber(me.Kills) or nil,
            damage = me and tonumber(me.DamageDealt) or nil,
            upgrades = me and tonumber(me.UpgradesThisGame) or nil,
            bossKills = me and tonumber(me.BossKillsThisGame) or nil,
            spaceGems = me and tonumber(me.SpaceGemsFromKills) or nil,
            maxUnits = me and tonumber(me.MaxUnitsPlacedAtOnceThisGame) or nil,
            unitsUsed = me and jsonSafeFlat(me.UsedUnitsThisGame) or nil,
            rewards = rewards,
            seedsGained = earnedSince(startSnap, "seeds"),
            candyGained = earnedSince(startSnap, "candy"),
        }
    end
    local matchResult = nil
    if type(matchCtx) == "table" then
        matchResult = buildMatchResult(matchCtx.data, matchCtx.startSnap, matchCtx.rewardList,
            matchCtx.map, matchCtx.difficulty, matchCtx.result)
    end
    local wave = readStat("Wave")
    if wave then Session.lastWave = wave end
    return {
        username = LocalPlayer.Name,
        userId = LocalPlayer.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        status = currentStatus(),
        wave = wave or Session.lastWave,
        seeds = readStat("Seeds"),
        earned = seedsEarned(),
        cash = readStat("Cash"),
        candy = readStat("Candy"),
        match = {
            count = totalMatches, wins = Session.wins, losses = Session.losses,
            lastResult = Session.lastResult,
        },
        macro = { playing = State.macroPlay, name = selectedMacroRef and selectedMacroRef() or nil },
        map = Session.mapId,
        difficulty = Session.difficulty,
        gamesWon = tonumber(dataGet("GamesWon")),
        seedsTotal = tonumber(dataGet("TotalSeedsEarned")),
        candyTotal = tonumber(dataGet(GAME.EventCurrencyTotal)),
        candyLabel = GAME.EventCurrencyLabel,
        result = matchResult,
        event = event or "heartbeat",
        version = VERSION,
        uptime = os.time() - Session.startedAt,
        timestamp = os.time(),
    }
end

local function sendTelemetry(event, matchCtx)
    local url = Cfg.telemetryUrl
    if type(url) ~= "string" or not url:match("^https?://") then return false end
    local headers = {}
    if Cfg.telemetryKey ~= "" then headers["X-Api-Key"] = Cfg.telemetryKey end
    local ok, code = postJson(url, buildTelemetry(event, matchCtx), headers)
    if not ok then
        notifyOnce("telemetry_fail_" .. tostring(code), "Dashboard API gagal (" .. tostring(code or "no response") .. ")")
    end
    return ok
end

-- Loop heartbeat: kirim status tiap Cfg.telemetryInterval detik selama toggle aktif
task.spawn(function()
    local last = 0
    while alive do
        task.wait(1)
        if State.telemetry and os.clock() - last >= math.max(Cfg.telemetryInterval, 10) then
            last = os.clock()
            task.spawn(sendTelemetry, "heartbeat")
        end
    end
end)

--------------------------------------------------------------------
-- ALUR AKHIR MATCH
--------------------------------------------------------------------
local MatchEnded = Instance.new("BindableEvent")
local matchEndConnected = false
local sinceReturn = 0
local onMatchEnd

local RETURN_TEXTS = { "kembali ke lobi", "kembali ke lobby", "return to lobby", "back to lobby" }
-- Klik satu tombol GUI. Dicoba berurutan, berhenti di cara pertama yang tersedia:
--   1) firesignal   2) getconnections   3) VirtualInputManager (klik mouse sungguhan
--   di tengah tombol). FIX: dulu hanya firesignal; executor tanpa firesignal tidak
--   pernah mengklik "Play Again", jadi Auto Replay hanya lewat remote (kadang gagal).
-- Mengembalikan nama cara yang dipakai, atau nil.
local function clickButton(b)
    if firesignal then
        local ok = pcall(function()
            for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" }) do
                firesignal(b[sig])
            end
        end)
        if ok then return "firesignal" end
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
        if fired then return "getconnections" end
    end
    local ok = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos = b.AbsolutePosition + b.AbsoluteSize / 2
        local sg = b:FindFirstAncestorWhichIsA("ScreenGui")
        if not (sg and sg.IgnoreGuiInset) then
            pos = pos + game:GetService("GuiService"):GetGuiInset()
        end
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.wait(0.05)
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
    if ok then return "VirtualInputManager" end
    return nil
end

-- Klik tombol GUI berdasarkan teks yang terlihat. Mengembalikan nama cara klik, atau nil.
function clickGuiByText(texts)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Text ~= "" and #d.Text < 60 then
            local t = guiText(d)
            for _, k in ipairs(texts) do
                if t == k and guiShown(d) then
                    local b = d
                    while b and not b:IsA("GuiButton") do b = b.Parent end
                    if b then return clickButton(b) end
                end
            end
        end
    end
    return nil
end

local function returnToLobby()
    -- 1) Klik tombol asli; kalau layar akhir match hilang, selesai
    if clickGuiByText(RETURN_TEXTS) then
        print("[ArdHub] tombol kembali ke lobi diklik")
        local t0 = os.clock()
        while alive and os.clock() - t0 < 4 do
            task.wait(0.5)
            if not endScreenVisible() then return end
        end
        print("[ArdHub] klik tombol lobi tidak berefek, memakai remote")
    end
    if GAME.LobbyPlaceId and GAME.LobbyPlaceId > 0 then
        TeleportService:Teleport(GAME.LobbyPlaceId, LocalPlayer)
        return
    end
    -- 2) Remote BackToMainLobby dengan map (id game) saat ini, seperti Auto Replay
    local map = resolveReplayMap()
    local r = getRemote("ReturnLobby")
    if not r then return end
    local args = map and { map } or {}
    task.spawn(function()
        local ok, res
        if r:IsA("RemoteFunction") then
            ok, res = pcall(r.InvokeServer, r, table.unpack(args))
        else
            ok, res = pcall(r.FireServer, r, table.unpack(args))
        end
        print("[ArdHub] BackToMainLobby(" .. (map and map.Name or "-") .. ") -> ok="
            .. tostring(ok) .. " hasil=" .. tostring(res))
    end)
end

-- Pemicu akhir match dipakai bersama oleh event ShowGameEnd dan deteksi map dilepas
-- dari workspace. Satu map hanya diproses sekali (ShowGameEnd juga muncul 2x).
local lastEndAt = -100
triggerMatchEnd = function(packed)
    -- ShowGameEnd muncul 2x dan beberapa pemicu bisa aktif bersamaan: satu akhir match = satu proses
    if os.clock() - lastEndAt < 10 then return end
    lastEndAt = os.clock()
    task.spawn(onMatchEnd, packed)
    MatchEnded:Fire()
end

-- Pemantau layar akhir match ("Mainkan Lagi"): memicu Auto Replay, Auto Return, Return After X
-- dan Webhook tanpa bergantung pada event ShowGameEnd.
task.spawn(function()
    local wasVisible = false
    while alive do
        -- Memindai seluruh PlayerGui itu berat (ribuan objek). Bila event ShowGameEnd sudah
        -- tersambung, pemindaian hanya cadangan: tiap 8 detik, bukan tiap detik.
        task.wait(matchEndConnected and 8 or 1)
        if State.autoReplay or State.autoReturn or State.returnAfterX or State.webhook
            or State.recArmed or State.macroPlay or State.telemetry then
            local ok, vis = pcall(endScreenVisible)
            vis = ok and vis or false
            if vis and not wasVisible then
                task.delay(1.5, function() -- beri kesempatan event ShowGameEnd (data webhook) tiba dulu
                    if alive then triggerMatchEnd(nil) end
                end)
            end
            wasVisible = vis
        else
            wasVisible = false
        end
    end
end)

local function connectMatchEnd()
    if matchEndConnected then return true end
    local r = getRemote("MatchEnd")
    if not r or not r:IsA("RemoteEvent") then return false end
    matchEndConnected = true
    r.OnClientEvent:Connect(function(...)
        if not alive then return end
        markMatch((...)) -- argumen 1 ShowGameEnd = map match
        triggerMatchEnd(table.pack(...))
    end)
    return true
end

onMatchEnd = function(packed)
    -- Di lobby tidak ada akhir match: abaikan pemicu palsu (Replay/Return/webhook tidak jalan)
    if not isMatchMap(currentMap) then return end
    matchOver = true
    notify("Match selesai terdeteksi")
    local data = gameEndData(packed)
    totalMatches = totalMatches + 1
    sinceReturn = sinceReturn + 1
    local wc = tonumber(pick(data, { "WavesCleared" }))
    if wc then Session.lastWave = wc end

    -- Catat hasil match (Victory/Defeat) untuk Webhook & Dashboard
    local result = resultText(data) or ""
    if result == "" then
        -- Event tidak membawa data: tebak dari teks di layar akhir
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            for _, d in ipairs(pg and pg:GetDescendants() or {}) do
                if d:IsA("TextLabel") and #d.Text < 20 and guiShown(d) then
                    local t = d.Text:lower()
                    if t:find("victory") or t:find("menang") then result = "Victory" break end
                    if t:find("defeat") or t:find("kalah") then result = "Defeat" break end
                end
            end
        end)
    end
    if result ~= "" then
        Session.lastResult = result
        local low = result:lower()
        if low:find("vic") or low:find("win") or low:find("menang") then
            Session.wins = Session.wins + 1
        elseif low:find("def") or low:find("lose") or low:find("kalah") then
            Session.losses = Session.losses + 1
        end
    end
    -- Hadiah (ShowMessage) dan data (UpdatePlayerData) datang SETELAH ShowGameEnd:
    -- kirim webhook/telemetry 3 detik kemudian supaya angkanya sudah terbaru.
    local wantWebhook, wantTelemetry = State.webhook, State.telemetry
    -- FIX: setelah replay, map baru langsung terdeteksi dan patokan "awal match" berganti
    -- sebelum webhook terkirim -> hadiah terhitung 0 / "-". Patokan match ini dibekukan di sini.
    local startSnap = Session.matchStart
    Session.rewards = {}
    local rewardList = Session.rewards
    local endMap, endDifficulty = Session.mapId, Session.difficulty -- dibekukan: replay bisa mengganti map sebelum 5 detik
    task.delay(5, function()
        if not alive then return end
        if wantTelemetry then
            pcall(sendTelemetry, "match_end", {
                data = data, startSnap = startSnap, rewardList = rewardList,
                map = endMap, difficulty = endDifficulty, result = result,
            })
        end
        if wantWebhook then
            local tag = Cfg.tagMatch or (Cfg.tagDefeat and result == "Defeat")
            pcall(sendWebhook, buildMatchEmbed(data, false, startSnap, rewardList), tag)
        end
    end)

    if State.returnAfterX and sinceReturn >= math.max(Cfg.matchesBeforeReturn, 1) then
        sinceReturn = 0
        returnToLobby()
        return
    end
    if State.autoReturn then
        returnToLobby()
        return
    end
    if State.autoReplay then
        -- Maksimal 4 percobaan, bergantian: klik tombol -> remote -> klik -> remote.
        -- Berhenti begitu layar akhir match hilang / map baru muncul.
        -- FIX: dulu hanya sekali; bila gagal, layar Defeat tertinggal selamanya.
        task.wait(1)
        for attempt = 1, 4 do
            if not (alive and State.autoReplay) then break end
            if attempt > 1 and not endScreenVisible() then break end
            lastReplayAt = -100 -- izinkan percobaan ulang segera
            if doReplay(attempt % 2 == 0) then break end
            print("[ArdHub] Auto Replay percobaan " .. attempt .. " gagal, mencoba lagi")
            task.wait(3)
        end
    end
end

-- Sambungkan ke event akhir match sejak awal (bukan saat toggle), supaya akhir match
-- tidak terlewat kalau toggle baru dinyalakan sesudahnya.
task.spawn(function()
    while alive and not matchEndConnected do
        pcall(connectMatchEnd)
        task.wait(2)
    end
end)

--------------------------------------------------------------------
-- FILE MACRO
-- Format file = array JSON, tiap aksi { Type, Time (detik bulat), ... }:
--   PlaceUnit{ID,Unit,Position,CF,Rotation,Valid}  BuyPlot{Plot}
--   ToggleAutoUpgrade{ID}  ChangeTarget{ID,TargetMode}
--   ActivateUnitAbility{ID}  Sell{ID}
-- ID di file = ID saat rekaman. Di game ID unit berbeda tiap match,
-- jadi saat Play, ID dipetakan ke ID baru dari hasil PlaceUnit.
--------------------------------------------------------------------
-- FIX: delfile tidak wajib lagi. Dulu executor tanpa delfile dianggap tidak
-- punya file system sama sekali, sehingga Record/Play macro mati semua.
local FS = HAS_FS and listfiles and true or false
local MACRO_DIR = ROOT_DIR .. "/Macros"
local selectedMacro = nil
selectedMacroRef = function() return selectedMacro end
local macroDropdown, playToggle, recordToggle -- diisi saat UI dibuat

local KNOWN_TYPES = {
    PlaceUnit = true, BuyPlot = true, ToggleAutoUpgrade = true,
    ChangeTarget = true, ActivateUnitAbility = true, Sell = true,
}

-- Pastikan folder macro (ArdHub/Macros) ada. true = siap dipakai.
local function ensureDir()
    if not FS then return false end
    return safeMakeDir(MACRO_DIR)
end

local function macroPath(name)
    return MACRO_DIR .. "/" .. name
end

local function cleanName(s)
    s = tostring(s or "")
    s = s:gsub("%.json$", "")
    s = s:gsub("[^%w%-_ ]", "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Semua file di folder macro (dengan atau tanpa ekstensi)
local function listMacros()
    local out = {}
    if not ensureDir() then return out end
    local ok, files = pcall(listfiles, MACRO_DIR)
    if ok and type(files) == "table" then
        for _, p in ipairs(files) do
            local n = p:match("([^/\\]+)$")
            if n and n ~= "" and not n:match("^%.") then
                table.insert(out, n)
            end
        end
    end
    table.sort(out)
    return out
end

-- Data macro tidak dipercaya (file/import): hanya field yang dikenal dan bertipe benar yang dipakai.
local function sanitizeActions(list)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, a in ipairs(list) do
        if #out >= 5000 then break end
        if type(a) == "table" and KNOWN_TYPES[a.Type] and type(a.Time) == "number" then
            local c = { Type = a.Type, Time = a.Time }
            if type(a.ID) == "number" then c.ID = a.ID end
            if type(a.Plot) == "number" then c.Plot = a.Plot end
            if type(a.TargetMode) == "number" then c.TargetMode = a.TargetMode end
            if type(a.Rotation) == "number" then c.Rotation = a.Rotation end
            if type(a.Valid) == "boolean" then c.Valid = a.Valid end
            if type(a.PathIndex) == "number" then c.PathIndex = a.PathIndex end
            if type(a.DistanceAlongPath) == "number" then c.DistanceAlongPath = a.DistanceAlongPath end
            if type(a.Unit) == "string" and #a.Unit <= 64 then c.Unit = a.Unit end
            if type(a.Position) == "string" and #a.Position <= 200 then c.Position = a.Position end
            if type(a.CF) == "string" and #a.CF <= 400 then c.CF = a.CF end
            table.insert(out, c)
        end
    end
    -- urutkan menurut Time (stabil)
    for i, a in ipairs(out) do a._i = i end
    table.sort(out, function(x, y)
        if x.Time ~= y.Time then return x.Time < y.Time end
        return x._i < y._i
    end)
    for _, a in ipairs(out) do a._i = nil end
    return out
end

-- PlaceUnit yang tidak punya ID (hasil PlaceUnit tidak berisi ID): ID unit itu dianggap
-- ID pertama yang BARU muncul pada aksi sesudahnya (ToggleAutoUpgrade, Ability, dst).
-- Ini tebakan berbasis urutan, tapi cocok dengan pola rekaman nyata.
local function backfillIds(actions)
    local seen = {}
    for _, a in ipairs(actions) do
        if a.ID then seen[a.ID] = true end
    end
    local firstSeenAt = {}
    for i, a in ipairs(actions) do
        if a.ID and a.Type ~= "PlaceUnit" and not firstSeenAt[a.ID] then
            firstSeenAt[a.ID] = i
        end
    end
    local claimed = {}
    for _, a in ipairs(actions) do
        if a.ID then claimed[a.ID] = true end
    end
    for i, a in ipairs(actions) do
        if a.Type == "PlaceUnit" and not a.ID then
            for j = i + 1, #actions do
                local b = actions[j]
                if b.Type ~= "PlaceUnit" and b.ID and not claimed[b.ID] then
                    a.ID = b.ID
                    claimed[b.ID] = true
                    break
                end
            end
        end
    end
    return actions
end

-- Menerima array JSON (format file-mu) atau format lama { actions = [...] }
local function decodeMacro(raw)
    raw = (tostring(raw):gsub("^\239\187\191", "")) -- buang BOM
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" then return nil end
    if type(data.actions) == "table" then data = data.actions end
    return backfillIds(sanitizeActions(data))
end

local function loadMacro(name)
    if not FS or not name or name == "" then return nil end
    local ok, raw = pcall(readfile, macroPath(name))
    if not ok then return nil end
    return decodeMacro(raw)
end

local function saveMacro(name, actions)
    if not ensureDir() then
        notify("Executor tidak mendukung file (writefile)")
        return false
    end
    local ok, enc = pcall(function() return HttpService:JSONEncode(actions) end)
    if not ok then
        notify("Gagal meng-encode macro")
        return false
    end
    local ok2 = pcall(writefile, macroPath(name), enc)
    return ok2
end

local function refreshMacros(keep)
    local list = listMacros()
    macroDropdown:SetOptions(list)
    if keep and table.find(list, keep) then
        selectedMacro = keep
        macroDropdown:Set(keep, true)
    elseif #list > 0 then
        selectedMacro = list[1]
        macroDropdown:Set(list[1], true)
    else
        selectedMacro = nil
        macroDropdown:Set("(kosong)", true)
    end
end

--------------------------------------------------------------------
-- PEMANGGILAN REMOTE UNTUK MACRO
--------------------------------------------------------------------
-- Seperti fireRemote, tapi untuk RemoteFunction menunggu dan mengembalikan hasil
local function callRemote(key, ...)
    local r = getRemote(key)
    if not r then return false end
    if r:IsA("RemoteEvent") then
        r:FireServer(...)
        return true
    elseif r:IsA("RemoteFunction") then
        return pcall(r.InvokeServer, r, ...)
    end
    return false
end

local function callWithArgs(key, args)
    if type(args) ~= "table" then return false end
    return callRemote(key, table.unpack(args, 1, args.n or #args))
end

local function nums(s)
    local t = {}
    if type(s) == "string" then
        for tok in s:gmatch("[^,%s]+") do t[#t + 1] = tonumber(tok) end
    end
    return t
end

local function allNumbers(t, count)
    if #t ~= count then return false end
    for i = 1, count do
        if type(t[i]) ~= "number" then return false end
    end
    return true
end

local function actionPosition(a)
    local p = nums(a.Position)
    if allNumbers(p, 3) then return Vector3.new(p[1], p[2], p[3]) end
    local c = nums(a.CF)
    if allNumbers(c, 12) then return Vector3.new(c[1], c[2], c[3]) end
    return nil
end

local function actionCFrame(a)
    local c = nums(a.CF)
    if allNumbers(c, 12) then return CFrame.new(table.unpack(c)) end
    return nil
end

--------------------------------------------------------------------
-- RECORD MACRO
-- Perlu GAME.Parse[Type](args, ctx) -> tabel field (ID, Unit, Position, ...)
-- dan GAME.Remotes[Type]. Tanpa itu Record tidak aktif.
--------------------------------------------------------------------
local recording, recArmed, recBase, recActions = false, false, 0, {}
local playing = false
local hookInstalled = false
local kindByRemoteName = {}
local recordTargets = {} -- { { remote = Instance, kind = Type } }
local recSeq = 0         -- nomor urut panggilan (urutan asli, walau pencatatan telat karena lag)

local function rebuildKinds()
    kindByRemoteName = {}
    recordTargets = {}
    for t in pairs(KNOWN_TYPES) do
        local n = GAME.Remotes[t]
        if n and n ~= "" and GAME.Parse[t] then
            kindByRemoteName[n] = t
            local r = ReplicatedStorage:FindFirstChild(n, true)
            if r then recordTargets[#recordTargets + 1] = { remote = r, kind = t } end
        end
    end
end

-- Sinyal "game mulai" (vote selesai / musuh mulai muncul). Dipakai Record dan Play supaya
-- Time di file macro = detik sejak game mulai. Di-reset tiap map baru dan tiap match selesai.
local gameStartAt, mapSeenAt = nil, os.clock()
local mapSerial = 0 -- naik tiap map baru; Play memakainya untuk menghentikan macro game lama
local GameStarted = Instance.new("BindableEvent")
MapChanged.Event:Connect(function()
    gameStartAt = nil
    mapSeenAt = os.clock()
    mapSerial = mapSerial + 1
end)
-- Sinyal "game mulai" = timer game mulai bergerak (waktu 1). Timer dicari di PlayerGui:
-- TextLabel berformat mm:ss (atau "Time: N") yang nilainya naik tiap detik.
-- Isi GAME.TimeLabelName untuk menunjuk label tertentu. Dipantau hanya saat Play/Record aktif.
local function markStartAt(base, sig)
    if gameStartAt then return end
    gameStartAt = base
    print("[ArdHub] game mulai (sinyal: " .. sig .. ")")
    GameStarted:Fire()
end

-- Cadangan sinyal mulai: event StopDifficultyVote (vote selesai = timer mulai dari 0).
-- Dipakai bila 3 detik setelah vote selesai timer belum memberi sinyal mulai.
local clockLabel -- diisi pemantau timer di bawah
task.spawn(function()
    for _ = 1, 60 do
        local f = ReplicatedStorage:FindFirstChild("RemoteEvents")
        local r = f and f:FindFirstChild("StopDifficultyVote")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(...)
                -- Difficulty hasil vote (bila dikirim server, berbentuk "dif_xxx")
                for _, a in ipairs({ ... }) do
                    if type(a) == "string" and a:match("^dif_") then Session.difficulty = a end
                    if type(a) == "table" then
                        for _, x in pairs(a) do
                            if type(x) == "string" and x:match("^dif_") then Session.difficulty = x end
                        end
                    end
                end
                local at = os.clock()
                task.wait(3) -- beri kesempatan timer terbaca dulu
                if alive and not gameStartAt and not matchOver then
                    markStartAt(at, "StopDifficultyVote")
                end
            end)
            return
        end
        task.wait(2)
    end
end)

-- allowPlain = true: angka polos ("2") juga dianggap detik. Dipakai untuk label timer
-- yang sudah dikenali / berada di TopbarStandard. FIX: dulu angka polos ditolak, jadi
-- timer baru terbaca setelah 60 detik ("1:01") -> log "game mulai (sinyal: timer 61)".
local function parseClock(text, allowPlain)
    if type(text) ~= "string" then return nil end
    -- FIX v2.5.3: buang tag RichText dulu ("<font ...>1:51</font>" dulu ditolak karena
    -- panjangnya > 24 huruf, jadi timer tidak pernah terbaca)
    text = text:gsub("<[^>]+>", "")
    if #text > 24 then return nil end
    local h, m, s = text:match("(%d+):(%d%d):(%d%d)")
    if h then return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) end
    m, s = text:match("(%d+):(%d%d)")
    if m then return tonumber(m) * 60 + tonumber(s) end
    local low = text:lower()
    local n = low:match("^%s*time%s*:?%s*(%d+)%s*$") or low:match("^%s*waktu%s*:?%s*(%d+)%s*$")
    if not n and (allowPlain or GAME.TimeLabelName ~= "") then n = low:match("^%s*(%d+)%s*$") end
    return n and tonumber(n) or nil
end

local clockLast = nil
local clockDumped = false
local clockSeen = setmetatable({}, { __mode = "k" })
task.spawn(function()
    local scanAt, needSince = 0, nil
    while alive do
        task.wait(0.5)
        local need = State.macroPlay or State.recArmed
        if clockLabel and not clockLabel.Parent then clockLabel, clockLast = nil, nil end
        if clockLabel then
            local v = parseClock(guiText(clockLabel), true)
            if v then
                if clockLast and v < clockLast - 2 then gameStartAt = nil end -- timer reset: game baru
                -- FIX: saat layar akhir match, timer lama masih terbaca dan dulu
                -- dianggap "game mulai" (log: timer 337). Abaikan selama matchOver.
                if not gameStartAt and not matchOver and clockLast and v > clockLast and v >= 1 then
                    markStartAt(os.clock() - v, "timer " .. v)
                end
                clockLast = v
            end
        elseif need then
            needSince = needSince or os.clock()
            if os.clock() - scanAt >= 1 then
                scanAt = os.clock()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                for _, d in ipairs(pg and pg:GetDescendants() or {}) do
                    if d:IsA("TextLabel") and (GAME.TimeLabelName == "" or d.Name == GAME.TimeLabelName)
                        and guiShown(d) then
                        local hint = GAME.TimeLabelHint ~= "" and d:GetFullName():find(GAME.TimeLabelHint, 1, true) ~= nil
                        local v = parseClock(guiText(d), hint)
                        if v then
                            local rec = clockSeen[d]
                            if not rec then
                                rec = { v = v, up = 0 }
                                clockSeen[d] = rec
                            else
                                -- FIX v2.5.3: toleransi naik 10 (speed 2x/3x atau scan terlambat)
                                if v > rec.v and v - rec.v <= 10 then rec.up = rec.up + 1 end
                                rec.v = v
                            end
                            -- Harus terlihat naik 2x (sekitar 2 detik) supaya angka lain
                            -- (cash, jumlah, dll.) tidak salah dikira timer. Label di
                            -- TopbarStandard (lokasi timer game) cukup naik 1x.
                            if rec.up >= (hint and 1 or 2) then
                                clockLabel, clockLast = d, v
                                print("[ArdHub] timer game: " .. d:GetFullName() .. " = " .. d.Text)
                                if not gameStartAt and not matchOver and v >= 1 then
                                    markStartAt(os.clock() - v, "timer " .. v)
                                end
                                break
                            end
                        end
                    end
                end
            end
            if not clockLabel and os.clock() - needSince > 10 and not clockDumped then
                -- Debug: tampilkan kandidat teks di TopbarStandard supaya lokasi timer bisa dicek
                clockDumped = true
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                for _, d in ipairs(pg and pg:GetDescendants() or {}) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and GAME.TimeLabelHint ~= ""
                        and d:GetFullName():find(GAME.TimeLabelHint, 1, true) then
                        print(string.format("[ArdHub] kandidat timer: %s = %q (shown=%s)",
                            d:GetFullName(), d.Text, tostring(guiShown(d))))
                    end
                end
            end
            if not clockLabel and os.clock() - needSince > 20 then
                notifyOnce("noclock", "Timer game belum terbaca (isi GAME.TimeLabelName)")
            end
        else
            needSince, clockDumped = nil, false
        end
    end
end)

-- Urutan asli panggilan, bukan urutan saat dicatat
local function orderedRecActions()
    local copy = {}
    for i, a in ipairs(recActions) do copy[i] = a end
    table.sort(copy, function(x, y) return (x._seq or 0) < (y._seq or 0) end)
    return copy
end

local function cleanRecording()
    return backfillIds(sanitizeActions(orderedRecActions()))
end

local function autosave()
    if not (FS and selectedMacro) then return end
    local ok, enc = pcall(function() return HttpService:JSONEncode(cleanRecording()) end)
    if ok then pcall(writefile, macroPath(selectedMacro), enc) end
end

local function startRecording(base)
    recBase = base or gameStartAt or mapSeenAt or os.clock()
    recording = true
    notify("Record dimulai")
end

local function sameArgs(a, b)
    if a.n ~= b.n then return false end
    for i = 1, a.n do
        if not rawequal(a[i], b[i]) then return false end
    end
    return true
end

local lastRec = nil
-- at = waktu saat game MEMANGGIL remote (bukan saat respons server tiba), jadi lag jaringan
-- tidak menggeser Time dan tidak membuat aksi tertukar urutannya.
local function recordAction(kind, args, result, at, seq, resAll)
    if not recArmed then return end
    if result == false then return end -- server menolak aksi ini
    local parse = GAME.Parse[kind]
    if not parse then return end
    -- Satu panggilan bisa tertangkap dua hook: dicatat sekali. Dua panggilan berbeda
    -- (mis. ChangeTarget mode 2 lalu mode 3 dalam lag) argumennya beda, jadi tetap dicatat dua-duanya.
    if lastRec and lastRec.kind == kind and math.abs(at - lastRec.at) < 0.1 and sameArgs(lastRec.args, args) then
        return
    end
    lastRec = { kind = kind, at = at, args = args }
    if not recording then
        print("[ArdHub] tidak ada sinyal game mulai; Time dihitung sejak map muncul")
        startRecording(mapSeenAt)
    end
    local ok, fields = pcall(parse, args, { map = currentMap, result = result, results = resAll })
    if ok and type(fields) == "table" then
        fields.Type = kind
        fields.Time = math.max(0, math.floor((at - recBase) + 0.5)) -- detik bulat
        fields._seq = seq
        fields._at = at -- waktu mentah, untuk koreksi bila sinyal mulai datang belakangan
        table.insert(recActions, fields)
        if kind == "PlaceUnit" then
            local wp = actionPosition(fields)
            if wp then addWalkPoint(wp) end
        end
        autosave()
        print("[ArdHub] rekam " .. kind .. " " .. tostring(fields.Unit or "") .. " ID=" .. tostring(fields.ID)
            .. " t=" .. tostring(fields.Time))
    else
        warn("[ArdHub] gagal merekam " .. kind .. ": " .. tostring(fields))
    end
end

-- Game memanggil remote lewat dua jalur: __namecall (remote:FireServer()) dan pemanggilan
-- fungsi langsung (remote.InvokeServer(remote, ...)). Cobalt menunjukkan InvokeServer
-- game masuk lewat jalur kedua, jadi keduanya dipasang. Semua panggilan lain diteruskan apa adanya.
-- method = nama method namecall (nil untuk jalur fungsi langsung). setnamecallmethod dipulihkan
-- sebelum memanggil fungsi asli, supaya panggilan lain milik game (kamera, input) tidak rusak.
local function callOrig(orig, method, ...)
    if method and setnamecallmethod then setnamecallmethod(method) end
    return orig(...)
end

local function observeCall(orig, method, ...)
    local self = ...
    for i = 1, #recordTargets do
        local tg = recordTargets[i]
        if rawequal(self, tg.remote) then
            if not (checkcaller and checkcaller()) then
                local at = os.clock() -- dicatat SEBELUM menunggu respons server
                recSeq = recSeq + 1
                local seq = recSeq
                local args = table.pack(select(2, ...))
                local res = table.pack(callOrig(orig, method, ...))
                task.spawn(recordAction, tg.kind, args, res[1], at, seq, res)
                return table.unpack(res, 1, res.n)
            end
            break
        end
    end
    return callOrig(orig, method, ...)
end

-- Hook hanya dipasang saat Record dinyalakan pertama kali, dan hanya bekerja saat
-- Record aktif. Di luar itu fungsi asli dipanggil langsung tanpa memeriksa apa pun.
local function installHook()
    if hookInstalled then return true end
    local wrap = newcclosure or function(f) return f end
    local oldNC
    local ok = pcall(function()
        oldNC = hookmetamethod(game, "__namecall", wrap(function(...)
            if not recArmed or playing then
                return oldNC(...)
            end
            local method = getnamecallmethod()
            if method == "InvokeServer" or method == "FireServer" then
                return observeCall(oldNC, method, ...)
            end
            if setnamecallmethod then setnamecallmethod(method) end
            return oldNC(...)
        end))
    end)
    hookInstalled = ok and oldNC ~= nil
    if not hookInstalled then return false end
    if not newcclosure then
        warn("[ArdHub] newcclosure tidak tersedia; hook dipasang tanpa pembungkus C")
    end

    if hookfunction then
        local rf = ReplicatedStorage:FindFirstChildWhichIsA("RemoteFunction", true)
        local re = ReplicatedStorage:FindFirstChildWhichIsA("RemoteEvent", true)
        if rf then
            pcall(function()
                local oldI
                oldI = hookfunction(rf.InvokeServer, wrap(function(...)
                    if recArmed and not playing then return observeCall(oldI, nil, ...) end
                    return oldI(...)
                end))
            end)
        end
        if re then
            pcall(function()
                local oldF
                oldF = hookfunction(re.FireServer, wrap(function(...)
                    if recArmed and not playing then return observeCall(oldF, nil, ...) end
                    return oldF(...)
                end))
            end)
        end
    end
    return true
end

-- Selesai merekam: simpan ke file macro yang dipilih. auto = dipicu akhir match (toggle ikut dimatikan).
local function finishRecording(auto)
    if not recArmed then return end
    recArmed, recording = false, false
    State.recArmed = false
    local clean = cleanRecording()
    if selectedMacro and saveMacro(selectedMacro, clean) then
        refreshMacros(selectedMacro)
        notify("Record selesai: " .. #clean .. " aksi tersimpan")
    end
    if auto and recordToggle then recordToggle:Set(false, true) end
end

local function onRecordToggle(v)
    if v then
        if not (hookmetamethod and getnamecallmethod) then
            notify("Executor tidak mendukung hookmetamethod")
            recordToggle:Set(false, true)
            return
        end
        rebuildKinds()
        if #recordTargets == 0 then
            notify("Remote macro tidak ditemukan di ReplicatedStorage")
            recordToggle:Set(false, true)
            return
        end
        if not ensureDir() then
            notify("Executor tidak mendukung file (writefile)")
            recordToggle:Set(false, true)
            return
        end
        if not installHook() then
            notify("Gagal memasang hook")
            recordToggle:Set(false, true)
            return
        end
        if not selectedMacro then
            selectedMacro = "macro_" .. os.time() .. ".json"
        end
        recActions = {}
        lastRec = nil
        recording = false
        recArmed = true
        State.recArmed = true
        if gameStartAt then
            startRecording(gameStartAt)
        else
            notify("Record siap, mulai saat game dimulai")
        end
    else
        finishRecording(false)
    end
end

-- Record mulai saat game mulai, selesai otomatis saat layar Victory/Defeat muncul.
GameStarted.Event:Connect(function()
    if recArmed and not recording then startRecording(gameStartAt) end
    -- Record sudah berjalan dengan patokan cadangan (map muncul), lalu timer game baru
    -- terbaca: hitung ulang Time semua aksi terhadap waktu mulai yang benar.
    if recArmed and recording and gameStartAt and math.abs(recBase - gameStartAt) > 0.5 then
        recBase = gameStartAt
        for _, a in ipairs(recActions) do
            if a._at then a.Time = math.max(0, math.floor((a._at - recBase) + 0.5)) end
        end
        print("[ArdHub] Record: Time dikoreksi ke timer game")
        autosave()
    end
end)
MatchEnded.Event:Connect(function()
    gameStartAt = nil
    if recArmed then finishRecording(true) end
end)

--------------------------------------------------------------------
-- PLAY MACRO (baru, berdasarkan data Cobalt)
--
-- Remote yang dipakai (hasil remote spy):
--   RemoteFunctions.PlaceUnit:InvokeServer(unit, {
--       Valid = true, WasFastPlaced = false, Position = Vector3,
--       Attempt = n, Rotation = 180, CF = CFrame })
--     -> berhasil : true, ID unit baru (number)
--     -> gagal    : false, "pesan" (mis. "You don't have enough Cash!")
--   RemoteFunctions.ToggleAutoUpgrade:InvokeServer(ID) -> true, true
--   RemoteEvents.Entity_ChangeTargetingMode:FireServer(ID, mode)
--
-- Alur satu match:
--   1. tunggu game mulai (timer game bergerak; sama dengan patokan Record)
--   2. jalankan aksi BERURUTAN sesuai Time di file macro
--   3. PlaceUnit gagal karena cash  -> tunggu & coba lagi di posisi SAMA
--      PlaceUnit gagal "right now"  -> tunggu & coba lagi
--      PlaceUnit gagal alasan lain  -> geser sedikit (Placement Spread)
--   4. ID unit di file (rekaman) dipetakan ke ID baru dari hasil PlaceUnit
-- Play TIDAK memasang hook apa pun (aman dipakai bersama remote spy).
--------------------------------------------------------------------
-- Offset acak horizontal (X/Z); radius dalam studs. Dipakai Play dan Auto Walk.
local function randOffset(radius)
    local ang = math.random() * 2 * math.pi
    local d = radius * (0.35 + 0.65 * math.random())
    return Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
end

local onPlayToggle
do
    local CASH_WAIT = 1.5      -- detik antar percobaan saat cash belum cukup
    -- Kemajuan macro di match saat ini (untuk melanjutkan bila Play dimatikan lalu dinyalakan lagi)
    local progress = { serial = nil, macro = nil, index = 0, idMap = {} }
    -- Nomor Attempt PlaceUnit: naik terus selama sesi (seperti game), tidak di-reset per match
    local placeAttempt = 0
    -- PlaceUnit TIDAK pernah dilewati: dicoba terus sampai terpasang atau match selesai.

    -- Cari remote langsung di folder aslinya (RemoteFunctions / RemoteEvents),
    -- supaya tidak salah ambil remote lain yang namanya sama.
    local function findRemote(folder, name)
        local ok, r = pcall(function()
            local f = ReplicatedStorage:FindFirstChild(folder)
            return (f and f:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name, true)
        end)
        return ok and r or nil
    end

    -- Panggil RemoteFunction; kembalikan (terkirim, hasil1, hasil2)
    local function invoke(r, ...)
        if not r then return false end
        local res = table.pack(pcall(r.InvokeServer, r, ...))
        return res[1], res[2], res[3]
    end

    -- Mikro-teleport ke dekat posisi unit (opsi "Teleport Before Placing")
    local function teleportNear(pos)
        pcall(function()
            local hrp = getHRP()
            if not hrp then return end
            local land = pos + randOffset(math.max(Cfg.microTeleport, 1)) + Vector3.new(0, 3, 0)
            hrp.CFrame = CFrame.lookAt(land, Vector3.new(pos.X, land.Y, pos.Z))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
    end

    -- Tunggu Cash berubah (UpdatePlayerData). Min 0.75s, maks `limit` detik.
    local function waitCashChange(ctx, limit)
        local ver, w0 = PlayerData.cashVersion, os.clock()
        task.wait(0.75)
        while not ctx.aborted() and PlayerData.cashVersion == ver and os.clock() - w0 < limit do
            task.wait(0.25)
        end
    end

    -- Jenis penolakan PlaceUnit dari teks pesan server
    local function failKind(msg)
        local m = tostring(msg or ""):lower()
        if m:find("cash") or m:find("money") or m:find("afford") then return "cash" end
        -- FIX v2.5.5: dulu semua pesan berisi "wait" dianggap "belum bisa" -> diulang tanpa batas
        if m:find("right now") then return "notready" end
        if m:find("limit") or m:find("max") then return "limit" end
        return "position" -- posisi bentrok/tidak valid: coba geser sedikit
    end

    -- Satu sesi Play = satu match. ctx menyimpan status match ini.
    local function placeUnit(act, ctx)
        if act.Valid == false then return end
        local pos, cf = actionPosition(act), actionCFrame(act)
        if not pos then
            print("[ArdHub] Play: PlaceUnit tanpa posisi, dilewati")
            return
        end
        cf = cf or CFrame.new(pos)
        if Cfg.teleportBeforePlace then
            teleportNear(pos)
            task.wait(0.4 + math.random() * 0.4)
        end

        local r = findRemote("RemoteFunctions", GAME.Remotes.PlaceUnit)
        if not r then notifyOnce("play_noplace", "Remote PlaceUnit tidak ditemukan") return end

        local offset = Vector3.zero
        local tries = 0
        while not ctx.aborted() do
            placeAttempt = placeAttempt + 1
            local info = {
                Valid = true,
                WasFastPlaced = false,
                Position = pos + offset,
                Attempt = placeAttempt,
                Rotation = act.Rotation or 180,
                CF = cf + offset, -- CFrame + Vector3 = geser posisi, rotasi tetap
            }
            if act.PathIndex then info.PathIndex = act.PathIndex end
            if act.DistanceAlongPath then info.DistanceAlongPath = act.DistanceAlongPath end

            local sent, ok, res = invoke(r, act.Unit, info)
            if sent and ok == true then
                if act.ID and type(res) == "number" then ctx.idMap[act.ID] = res end
                addWalkPoint(info.Position)
                print(string.format("[ArdHub] Play: %s ditaruh (ID %s -> %s)%s", tostring(act.Unit),
                    tostring(act.ID), tostring(res), offset.Magnitude > 0 and
                    string.format(" geser %.2f", offset.Magnitude) or ""))
                return "placed"
            end

            -- Tanpa jawaban (nil) = server belum menerima (mis. match sedang berakhir): coba lagi
            local kind = (sent and ok == false and res ~= nil) and failKind(res) or "notready"
            tries = tries + 1
            -- Alasan asli penolakan (ditampilkan di status & console supaya bisa dicek)
            local why = not sent and ("error: " .. tostring(ok))
                or (ok == false and res ~= nil) and tostring(res)
                or ("tanpa jawaban server (" .. tostring(ok) .. ", " .. tostring(res) .. ")")
            if kind ~= "cash" and (tries == 1 or tries % 10 == 0) then
                print(string.format("[ArdHub] Play: %s gagal ke-%d: %s", tostring(act.Unit), tries, why))
            end
            if kind == "cash" then
                -- Cash belum cukup: posisi tetap sama, tunggu Cash berubah
                -- (UpdatePlayerData) supaya server tidak dibanjiri PlaceUnit.
                local cash = PlayerData.values.Cash
                setPlayStatus(string.format("Playing macro: menunggu cash untuk %s%s", tostring(act.Unit),
                    cash and (" (cash " .. tostring(cash) .. ")") or ""))
                waitCashChange(ctx, CASH_WAIT * 2)
            elseif kind == "notready" then
                -- "You can't place units right now!" (mis. game belum mulai)
                setPlayStatus("Playing macro: belum bisa menaruh " .. tostring(act.Unit) .. " (" .. why .. "), mencoba lagi")
                if ctx.midStart and (act.Time or 0) < ctx.startElapsed and tries >= 10 then
                    print("[ArdHub] Play: " .. tostring(act.Unit) .. " dilewati (tetap gagal: " .. why .. ")")
                    if act.ID then ctx.idMap[act.ID] = false end
                    return "skipped"
                end
                task.wait(1)
            else
                -- Alasan lain (posisi bentrok, limit unit, dll). Dicoba terus:
                -- percobaan ganjil di posisi asli, genap digeser sedikit (Placement Spread).
                -- Play dinyalakan di tengah game: aksi yang waktunya sudah lewat bisa jadi
                -- posisinya sudah ditempati unit yang kamu taruh sendiri. Setelah 6x ditolak
                -- (bukan karena cash), aksi itu dilewati supaya macro tidak macet di sini.
                if ctx.midStart and (act.Time or 0) < ctx.startElapsed and tries >= 6 then
                    print("[ArdHub] Play: " .. tostring(act.Unit) .. " dilewati (posisi kemungkinan sudah terisi)")
                    if act.ID then ctx.idMap[act.ID] = false end
                    return "skipped"
                end
                setPlayStatus("Playing macro: " .. tostring(act.Unit) .. " ditolak (" .. tostring(res) .. "), mencoba lagi")
                if (Cfg.spread or 0) > 0 and tries % 2 == 1 then
                    offset = randOffset(math.min(Cfg.spread * (1 + math.floor(tries / 8) * 0.25), 2))
                else
                    offset = Vector3.zero
                end
                task.wait(math.min(0.5 + tries * 0.1, 2)) -- makin lama makin pelan, maks 2 detik
            end
        end
        -- Sampai sini hanya bila match selesai / Play dimatikan sebelum unit terpasang
        if act.ID then ctx.idMap[act.ID] = false end -- unit ini tidak terpasang
    end

    -- Aksi yang memakai ID unit. ID rekaman dipetakan ke ID baru.
    local function unitAction(act, ctx)
        local id = act.ID
        if id ~= nil then
            local mapped = ctx.idMap[id]
            if mapped == false then return end -- unitnya gagal ditaruh
            id = mapped or id
        end

        if act.Type == "ToggleAutoUpgrade" then
            -- Toggle: hasil ke-2 = status auto upgrade sekarang. Bila jadi OFF, nyalakan lagi.
            local r = findRemote("RemoteFunctions", GAME.Remotes.ToggleAutoUpgrade)
            local sent, ok, state = invoke(r, id)
            if sent and ok == true and state == false then
                task.wait(0.3)
                invoke(r, id)
            end
            print("[ArdHub] Play: AutoUpgrade ID " .. tostring(id) .. " -> " .. tostring(ok) .. "," .. tostring(state))
        elseif act.Type == "ChangeTarget" then
            local r = findRemote("RemoteEvents", GAME.Remotes.ChangeTarget)
            if r then pcall(r.FireServer, r, id, act.TargetMode) end
        elseif act.Type == "Sell" then
            local r = findRemote("RemoteFunctions", GAME.Remotes.Sell)
            if r and r:IsA("RemoteFunction") then invoke(r, id)
            elseif r then pcall(r.FireServer, r, id) end
        elseif act.Type == "ActivateUnitAbility" then
            -- InvokeServer(ID, nil) -> true, true/false/nil. Ability berbayar cash:
            -- bila ditolak karena cash, tunggu cash bertambah lalu coba lagi.
            local r = findRemote("RemoteFunctions", GAME.Remotes.ActivateUnitAbility)
            if not r then return end
            local t0 = os.clock()
            while not ctx.aborted() do
                local sent, ok, res = invoke(r, id, nil)
                if sent and ok == false and failKind(res) == "cash" then
                    -- ability berbayar, cash kurang: tunggu cash (maks 60 detik)
                    if os.clock() - t0 > 60 then break end
                    setPlayStatus("Playing macro: menunggu cash untuk ability")
                    waitCashChange(ctx, CASH_WAIT * 2)
                elseif sent and ok == true and res == false then
                    -- (true, false) = ability belum siap (cooldown): coba lagi tiap 1 detik, maks 15 detik
                    if os.clock() - t0 > 15 then break end
                    task.wait(1)
                else
                    break -- (true, true) / (true, nil) = berhasil
                end
            end
        elseif act.Type == "BuyPlot" then
            -- RemoteEvents.BuyPlot:FireServer(plot) tidak memberi jawaban. Berhasil
            -- dideteksi dari Cash yang turun; bila tidak turun (cash kurang),
            -- tunggu cash bertambah lalu coba lagi (maks 120 detik).
            local r = findRemote("RemoteEvents", GAME.Remotes.BuyPlot)
            if not (r and act.Plot) then return end
            local t0 = os.clock()
            while not ctx.aborted() do
                local before = tonumber(PlayerData.values.Cash)
                pcall(r.FireServer, r, act.Plot)
                if not before then break end -- cash tidak terbaca: kirim sekali saja
                local w0 = os.clock()
                while os.clock() - w0 < 2 and (tonumber(PlayerData.values.Cash) or before) >= before do
                    task.wait(0.2)
                end
                if (tonumber(PlayerData.values.Cash) or before) < before then
                    print("[ArdHub] Play: plot " .. tostring(act.Plot) .. " dibeli")
                    break
                end
                if os.clock() - t0 > 120 then
                    print("[ArdHub] Play: plot " .. tostring(act.Plot) .. " gagal dibeli, dilewati")
                    break
                end
                setPlayStatus("Playing macro: menunggu cash untuk plot " .. tostring(act.Plot))
                waitCashChange(ctx, CASH_WAIT * 2)
            end
        end
    end

    -- Jalankan macro untuk satu match. Berhenti bila match selesai / map berganti.
    local function runMatch(token, serial)
        local actions = loadMacro(selectedMacro)
        if not actions then
            notify("Macro tidak ditemukan, pilih macro dulu")
            return "missing"
        end
        -- Lanjutkan (resume): Play dimatikan lalu dinyalakan lagi di match yang SAMA
        -- dengan macro yang sama -> mulai dari aksi berikutnya, pakai pemetaan ID yang sudah ada.
        -- FIX: dulu macro diulang dari aksi 1, unit pertama ditolak karena posisinya sudah
        -- terisi, lalu dicoba terus -> macro macet di tengah game.
        local resume = progress.serial == serial and progress.macro == selectedMacro
        if not resume then
            progress = { serial = serial, macro = selectedMacro, index = 0, idMap = {} }
        end
        local ctx = { idMap = progress.idMap }
        function ctx.aborted()
            return not alive or tokens.play ~= token or matchOver or mapSerial ~= serial
        end
        if progress.index >= #actions then
            setPlayStatus("Playing macro: " .. tostring(selectedMacro) .. "  [selesai, menunggu match berikutnya]")
            return "done"
        end

        -- 1) Tunggu game mulai (timer bergerak).
        --    Di tengah game (map sudah lama terlihat ATAU musuh sedang aktif) cukup tunggu
        --    timer terbaca maks 8 detik; bila tetap tidak terbaca pakai waktu map terdeteksi.
        setPlayStatus("Playing macro: menunggu game mulai")
        local w0 = os.clock()
        -- FIX v2.5.3: status "di tengah game" dicek ulang tiap putaran. Dulu hanya dicek sekali
        -- saat Play mulai; bila script baru di-execute di tengah game, map baru saja terdeteksi
        -- dan data musuh belum masuk -> dianggap game belum mulai dan menunggu sampai 90 detik.
        local midGame, midSince = false, nil
        while not ctx.aborted() and not gameStartAt do
            local now = os.clock()
            local voting = currentMap and VoteOpen[currentMap]
            if not midGame and not voting
                and (now - mapSeenAt > 8 or (lastEnemyAt > 0 and now - lastEnemyAt < 5)) then
                midGame, midSince = true, now
                setPlayStatus("Playing macro: game sudah berjalan, membaca timer...")
            end
            if midGame and now - midSince >= 6 then break end -- timer tetap tidak terbaca
            if now - w0 >= 90 then break end
            task.wait(0.25)
        end
        if ctx.aborted() then return "aborted" end
        local t0 = gameStartAt or (midGame and mapSeenAt) or os.clock()
        -- Mulai di tengah game? (dipakai aturan "lewati unit yang posisinya sudah terisi")
        ctx.startElapsed = os.clock() - t0
        ctx.midStart = resume or ctx.startElapsed > 5
        if resume then
            print(string.format("[ArdHub] Play: lanjut dari aksi %d/%d", progress.index + 1, #actions))
        elseif ctx.midStart then
            print(string.format("[ArdHub] Play: mulai di tengah game (detik %d), aksi yang sudah lewat dijalankan berurutan",
                math.floor(ctx.startElapsed)))
        end

        -- 2) Aksi berurutan sesuai waktu
        playing = true
        for i, act in ipairs(actions) do
            if ctx.aborted() then break end
            if i <= progress.index then continue end -- sudah dijalankan sebelumnya di match ini
            while not ctx.aborted() and os.clock() - t0 < (act.Time or 0) do
                setPlayStatus(string.format("Playing macro: %s  [%d/%d]  aksi berikut %ds",
                    tostring(selectedMacro), i, #actions, math.max(0, math.ceil(act.Time - (os.clock() - t0)))))
                task.wait(0.2)
            end
            if ctx.aborted() then break end
            setPlayStatus(string.format("Playing macro: %s  [%d/%d]  %s", tostring(selectedMacro), i, #actions, act.Type))
            local ok, res = pcall(act.Type == "PlaceUnit" and placeUnit or unitAction, act, ctx)
            if not ok then warn("[ArdHub] Play " .. act.Type .. ": " .. tostring(res)) end
            -- Catat kemajuan: aksi selesai (atau dilewati). Bila Play dimatikan di tengah
            -- aksi yang belum berhasil, aksi itu diulang saat dilanjutkan.
            if res == "placed" or res == "skipped" or not ctx.aborted() then progress.index = i end
            task.wait(0.15)
        end
        playing = false
        if not ctx.aborted() then
            setPlayStatus("Playing macro: " .. tostring(selectedMacro) .. "  [selesai, menunggu match berikutnya]")
        end
        return "done"
    end

    -- Toggle Play: loop menunggu match baru, jalankan macro sekali per match.
    function onPlayToggle(v)
        tokens.play = (tokens.play or 0) + 1
        State.macroPlay = v and true or false
        playing = false
        if not v then
            setPlayStatus(nil)
            return
        end
        if not selectedMacro then
            notify("Pilih macro dulu")
        end
        local token = tokens.play
        task.spawn(function()
            local played = nil
            while alive and tokens.play == token do
                -- Hanya di match sungguhan (bukan context lobby)
                if isMatchMap(currentMap) and not matchOver and mapSerial ~= played then
                    played = mapSerial
                    local ok, res = pcall(runMatch, token, played)
                    if not ok then warn("[ArdHub] Play: " .. tostring(res)) end
                    if res == "missing" then break end
                else
                    if not isMatchMap(currentMap) then setPlayStatus("Playing macro: menunggu match") end
                    task.wait(0.5)
                end
            end
            if tokens.play == token then -- berhenti sendiri (macro tidak ada)
                State.macroPlay = false
                playing = false
                setPlayStatus(nil)
                if playToggle then playToggle:Set(false, true) end
            end
        end)
    end
end

--------------------------------------------------------------------
-- PERFORMANCE, FOLLOW, WALK
--------------------------------------------------------------------
-- Dibungkus do...end (hemat register fungsi utama). Diekspor: 3 fungsi di bawah.
local setLowPerformance, installPlaceWatch, walkLoop
do
local origMat = setmetatable({}, { __mode = "k" })
local lowConn

-- Low Performance: kualitas grafis minimum, tanpa bayangan, material polos.
-- FIX: nilai GlobalShadows asli disimpan, jadi mematikan toggle memulihkan
-- kondisi awal (dulu selalu dipaksa true).
local origShadows = nil
function setLowPerformance(v)
    pcall(function()
        settings().Rendering.QualityLevel = v and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
    if v then
        if origShadows == nil then origShadows = Lighting.GlobalShadows end
        Lighting.GlobalShadows = false
    elseif origShadows ~= nil then
        Lighting.GlobalShadows = origShadows
        origShadows = nil
    end
    if lowConn then
        lowConn:Disconnect()
        lowConn = nil
    end
    if v then
        task.spawn(function()
            local n = 0
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Material ~= Enum.Material.SmoothPlastic then
                    origMat[d] = d.Material
                    d.Material = Enum.Material.SmoothPlastic
                end
                n = n + 1
                if n % 400 == 0 then task.wait() end
            end
        end)
        lowConn = workspace.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then
                origMat[d] = d.Material
                d.Material = Enum.Material.SmoothPlastic
            end
        end)
    else
        for part, m in pairs(origMat) do
            if part.Parent then part.Material = m end
        end
        origMat = setmetatable({}, { __mode = "k" })
    end
end

-- Auto Walk membaca posisi dari panggilan PlaceUnit milik game (argumen ke-2: Position)
-- yang berhasil (hasil server { true, ID }). Hanya hook hookfunction pada InvokeServer,
-- tanpa hook __namecall. Aktif hanya saat Auto Walk menyala.
local placeHooked = false
function installPlaceWatch()
    if placeHooked then return true end
    if not hookfunction then
        notify("hookfunction tidak ada: Auto Walk hanya memakai posisi macro")
        return false
    end
    local name = GAME.Remotes.PlaceUnit
    local remote = name and name ~= "" and ReplicatedStorage:FindFirstChild(name, true)
    if not (remote and remote:IsA("RemoteFunction")) then
        notify("Remote PlaceUnit tidak ditemukan")
        return false
    end
    local wrap = newcclosure or function(f) return f end
    local oldI
    local ok = pcall(function()
        oldI = hookfunction(remote.InvokeServer, wrap(function(self, ...)
            if State.autoWalk and rawequal(self, remote) then
                local args = table.pack(...)
                local res = table.pack(oldI(self, ...))
                if res[1] == true and type(args[2]) == "table" then
                    local pos = args[2].Position
                    if typeof(pos) == "Vector3" then
                        task.spawn(addWalkPoint, pos)
                    end
                end
                return table.unpack(res, 1, res.n)
            end
            return oldI(self, ...)
        end))
    end)
    placeHooked = ok and oldI ~= nil
    if not placeHooked then notify("Gagal memasang pemantau PlaceUnit") end
    return placeHooked
end

-- AUTO WALK (Anti-Ban)
-- Tiap Cfg.walkMin..walkMax detik (acak), karakter berjalan ke titik ACAK di sekitar
-- salah satu unit (radius Cfg.walkRadius). FIX versi lama: karakter dulu berjalan
-- tepat ke pivot unit (menabrak/tertahan di model unit) dengan interval tetap 5 detik.
local walkIdx = 0
local function walkStep()
    if not inMatch() then return end -- tidak berjalan-jalan di lobby
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    -- Titik = posisi unit yang terpasang (folder unit); cadangan: posisi unit dari macro
    local list = {}
    for _, u in ipairs(getUnits()) do
        if u:IsA("Model") or u:IsA("BasePart") then
            local ok, p = pcall(function() return u:GetPivot().Position end)
            if ok then list[#list + 1] = p end
        end
    end
    if #list == 0 then
        for _, p in ipairs(walkPoints) do list[#list + 1] = p end
    end
    if #list == 0 then -- belum ada unit: karakter diam
        walkIdx = 0
        return
    end

    -- Urutan titik diacak ringan: kadang lompat ke unit lain, bukan selalu berurutan
    if math.random() < 0.35 then
        walkIdx = math.random(1, #list)
    else
        walkIdx = walkIdx + 1
        if walkIdx > #list then walkIdx = 1 end
    end
    local target = list[walkIdx] + randOffset(math.max(Cfg.walkRadius, 1))
    hum:MoveTo(target)
end

local walkToken = 0
function walkLoop(v)
    walkToken = walkToken + 1
    if not v then return end
    local my = walkToken
    task.spawn(function()
        while alive and walkToken == my do
            local ok, err = pcall(walkStep)
            if not ok then warn("[ArdHub] autoWalk: " .. tostring(err)) end
            local lo = math.max(Cfg.walkMin, 1)
            local hi = math.max(Cfg.walkMax, lo)
            task.wait(lo + math.random() * (hi - lo))
        end
    end)
end
MapChanged.Event:Connect(function()
    walkIdx = 0
    table.clear(walkPoints)
end)
end -- akhir blok PERFORMANCE/WALK
-- Seluruh pembuatan tab + pemuatan config dibungkus fungsi sendiri.
-- Alasannya: Luau membatasi 200 register local per fungsi. Compiler executor
-- (tanpa optimasi) memakai lebih banyak register daripada compiler Roblox,
-- jadi variabel UI (tab, section, toggle) dipisah ke fungsi ini.
local function buildUI()
--------------------------------------------------------------------
-- ISI TAB
-- Urutan tab: Match | Auto Mode | Macro | Anti Ban | Webhook
-- Elemen yang dibungkus Flag(...) nilainya tersimpan di ArdHub/config.json.
--------------------------------------------------------------------

-- ================================================================
-- TAB: MATCH  (kontrol di dalam match + performa)
-- ================================================================
local tMatch = AddTab("Match")

local sMatch = tMatch:AddSection("Match", "left")

-- Kecepatan game yang sedang dipilih (2 / 3) atau nil = normal
local speedValue = nil
local function applySpeed()
    if speedValue then fireRemote("Speed", speedValue) end
end

-- Kirim ulang semua setting match. Dipanggil saat toggle dinyalakan dan
-- (bila GAME.ReapplyPerMatch) tiap map baru, karena setting server ter-reset per match.
local function applyMatchSettings()
    if not inMatch() then return end -- lobby: tidak dikirim
    if State.skipCutscene then fireRemote("SkipCutscene") end
    if State.autoSkipWave then fireRemote("AutoSkip", true) end
    applySpeed()
end
-- Dikirim saat map terbukti match (bukan saat context lobby terdeteksi)
MatchDetected.Event:Connect(function()
    if not GAME.ReapplyPerMatch then return end
    task.delay(GAME.ReapplyDelay or 2, function()
        if alive then pcall(applyMatchSettings) end
    end)
end)

Flag("skipCutscene", sMatch:AddToggle("Auto Skip Cutscene", false, function(v)
    State.skipCutscene = v
    if v and inMatch() then fireRemote("SkipCutscene") end
end), "toggle")

Flag("autoSkipWave", sMatch:AddToggle("Auto Skip Wave", false, function(v)
    State.autoSkipWave = v
    if inMatch() then fireRemote("AutoSkip", v and true or false) end
end), "toggle")

-- 2x dan 3x saling eksklusif. FIX: mematikan keduanya kini mengembalikan speed ke 1x.
local tog2, tog3
local function onSpeedToggle(speed, v, other)
    if v then
        if other and other:Get() then other:Set(false, true) end
        speedValue = speed
        if inMatch() then applySpeed() end
    elseif speedValue == speed then
        speedValue = nil
        if inMatch() then fireRemote("Speed", 1) end
    end
end
tog2 = Flag("speed2x", sMatch:AddToggle("Auto 2x Speed", false, function(v) onSpeedToggle(2, v, tog3) end), "toggle")
tog3 = Flag("speed3x", sMatch:AddToggle("Auto 3x Speed", false, function(v) onSpeedToggle(3, v, tog2) end), "toggle")

-- Auto Ability. FIX: dulu hanya terkirim SEKALI saat toggle dinyalakan; sekarang
-- berulang tiap 10 detik selama toggle aktif dan match berjalan.
local abilityLoop = bindLoop("autoAbility", 10, function()
    if not inMatch() then return end
    local build = GAME.Args.ActivateUnitAbility
    if not build then
        notifyOnce("args_auto_ability", "GAME.Args.ActivateUnitAbility belum diisi")
        return
    end
    for _, u in ipairs(getUnits()) do
        -- ID unit dibaca dari Attribute "ID" atau nama objek (DUGAAN, cek struktur Towers)
        local id = u:GetAttribute("ID") or tonumber(u.Name)
        if id then
            callWithArgs("ActivateUnitAbility", build({ Type = "ActivateUnitAbility", ID = id }, { map = currentMap, id = id }))
            task.wait(0.15 + math.random() * 0.25) -- jeda kecil antar unit
        end
    end
end)
Flag("autoAbility", sMatch:AddToggle("Auto Ability", false, function(v)
    State.autoAbility = v
    abilityLoop(v)
end), "toggle")

sMatch:AddDivider()
Flag("autoReplay", sMatch:AddToggle("Auto Replay", false, function(v)
    State.autoReplay = v
    if not v then return end
    connectMatchEnd()
    if not isMatchMap(currentMap) then
        print("[ArdHub] Auto Replay siap (aktif saat di dalam match)")
    elseif endScreenVisible() then
        -- match sudah selesai sebelum toggle dinyalakan: replay sekarang
        task.wait(0.5)
        if State.autoReplay then doReplay() end
    else
        notify("Auto Replay aktif, menunggu match selesai")
    end
end), "toggle")
Flag("autoReturn", sMatch:AddToggle("Auto Return", false, function(v)
    State.autoReturn = v
    if not v then return end
    connectMatchEnd()
    if isMatchMap(currentMap) and endScreenVisible() then
        task.wait(0.5)
        if State.autoReturn then returnToLobby() end
    end
end), "toggle")

local sPlayer = tMatch:AddSection("Player", "right")
sPlayer:AddToggle("Auto Beggar", false, function(v)
    if v then fireRemote("Beggar") end -- remote belum diketahui (GAME.Remotes.Beggar)
end)

local sPerf = tMatch:AddSection("Performance", "right")
Flag("no3d", sPerf:AddToggle("Disable 3D Rendering", false, function(v)
    pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end), "toggle")
Flag("lowPerf", sPerf:AddToggle("Enable Low Performance", false, setLowPerformance), "toggle")

-- CLEAN OLD MAPS
-- Setelah replay, game melepas map lama ke nil (tidak di-Destroy). Bila game tidak
-- membersihkannya, setiap match menambah satu map penuh di memori. Opsi ini
-- menghancurkan map-map lama itu 20 detik setelah match baru berjalan (saat itu
-- map lama sudah tidak dipakai replay). Map yang sedang dimainkan tidak disentuh.
local cleanOldMaps = false
local function destroyOldMaps()
    if not getnilinstances then return 0 end
    local n = 0
    pcall(function()
        for _, o in ipairs(getnilinstances()) do
            if o ~= currentMap and o.Parent == nil and isMapInstance(o) then
                if pcall(o.Destroy, o) then n = n + 1 end
            end
        end
    end)
    return n
end
MatchDetected.Event:Connect(function()
    task.delay(20, function()
        if not (alive and cleanOldMaps and inMatch()) then return end
        local n = destroyOldMaps()
        if n > 0 then print("[ArdHub] Clean Old Maps: " .. n .. " map lama dihapus dari memori") end
    end)
end)
Flag("cleanOldMaps", sPerf:AddToggle("Clean Old Maps", false, function(v)
    cleanOldMaps = v
    if v and not getnilinstances then notify("Executor tidak mendukung getnilinstances") end
end), "toggle")
sPerf:AddLabel("Clean Old Maps: hapus map match sebelumnya dari memori (cegah crash saat farming lama).")

-- ================================================================
-- TAB: AUTO MODE  (lobby / vote difficulty)
-- ================================================================
local tAuto = AddTab("Auto Mode")
local sLobby = tAuto:AddSection("Lobby", "left")

-- AUTO DIFFICULTY
-- Aturan:
--   * Difficulty dipilih lewat selector, vote hanya jalan bila toggle ON.
--   * Vote dikirim SEKALI per match: 1 detik setelah map baru muncul
--     (yaitu setelah replay / masuk match baru). Setelah terkirim, tidak
--     ada vote lagi sampai replay berikutnya.
--   * Menyalakan toggle saat match berjalan = vote sekali untuk match itu.
local votedMaps = setmetatable({}, { __mode = "k" }) -- map yang sudah di-vote (lemah: tidak menahan map lama)

local function voteDifficulty(map, reason)
    if not State.autoDiff then return end
    if typeof(map) ~= "Instance" or votedMaps[map] then return end
    if not isMatchMap(map) then return end -- jangan pernah vote di lobby
    votedMaps[map] = true -- tandai dulu supaya pemicu ganda tidak mengirim 2x
    task.delay(1, function()
        -- Batal bila toggle dimatikan atau match sudah berganti selama jeda
        if not alive or not State.autoDiff or currentMap ~= map then return end
        local r = getRemote("Difficulty")
        if not r then return end
        local diff = difficultyId(Cfg.difficulty)
        local ok, res
        if r:IsA("RemoteFunction") then
            ok, res = pcall(r.InvokeServer, r, map, diff)
        else
            ok, res = pcall(r.FireServer, r, map, diff)
        end
        print("[ArdHub] vote " .. diff .. " (" .. reason .. ") map " .. map.Name
            .. " -> ok=" .. tostring(ok) .. " hasil=" .. tostring(res))
        if ok then
            notify("Vote difficulty: " .. Cfg.difficulty)
            Session.difficulty = diff
        end
    end)
end

Flag("difficulty", sLobby:AddDropdown("Difficulty", {
    "Easy", "Normal", "Hard", "Insane", "Impossible", "Apocalypse", "Hell",
}, Cfg.difficulty, function(v)
    Cfg.difficulty = v -- dipakai pada vote berikutnya
end))

Flag("autoDiff", sLobby:AddToggle("Auto Difficulty", false, function(v)
    State.autoDiff = v
    -- Toggle dinyalakan (termasuk saat config dimuat): vote HANYA bila layar vote
    -- sedang terbuka di match. Di lobby tidak ada vote.
    if v and currentMap and VoteOpen[currentMap] and not matchOver then
        voteDifficulty(currentMap, "toggle on")
    end
end), "toggle")

-- Pemicu utama: event StartDifficultyVote(map, info) = layar vote dibuka
-- (terjadi setiap setelah replay). Vote dikirim 1 detik sesudahnya.
-- Cadangan bila remote itu tidak ada: map baru terdeteksi.
local voteEventConnected = false
task.spawn(function()
    for _ = 1, 30 do
        if not alive then return end
        local f = ReplicatedStorage:FindFirstChild("RemoteEvents")
        local r = f and f:FindFirstChild("StartDifficultyVote")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(map, info)
                if not alive or typeof(map) ~= "Instance" then return end
                if type(info) == "table" and type(info.MapId) == "string" then Session.mapId = info.MapId end
                markMatch(map)
                VoteOpen[map] = true
                voteDifficulty(map, "vote dibuka")
            end)
            voteEventConnected = true
            return
        end
        task.wait(2)
    end
end)
MapChanged.Event:Connect(function(map)
    task.wait(3) -- beri kesempatan StartDifficultyVote datang dulu
    if not voteEventConnected and isMatchMap(map) then voteDifficulty(map, "map baru") end
end)

-- ================================================================
-- TAB: MACRO  (file, import/export, record/play, timing)
-- ================================================================
local tMacro = AddTab("Macro")

local sFiles = tMacro:AddSection("Files", "left")
macroDropdown = Flag("selectedMacro", sFiles:AddDropdown("Selected Macro", {}, "(kosong)", function(v)
    if v == "(kosong)" then return end
    selectedMacro = v
end))
sFiles:AddButtonRow("Refresh List", function()
    refreshMacros(selectedMacro)
    notify("Daftar macro diperbarui")
end, "Delete", function(btn)
    if not selectedMacro then
        notify("Tidak ada macro yang dipilih")
        return
    end
    if State.macroPlay or State.recArmed then
        notify("Matikan Record/Play dulu sebelum menghapus")
        return
    end
    -- Konfirmasi: klik 1 = "Are you sure?", klik 2 (dalam 3 detik, macro yang sama) = hapus
    local arm = State.deleteArm
    if not (arm and arm.macro == selectedMacro and os.clock() - arm.at <= 3) then
        local mine = { macro = selectedMacro, at = os.clock() }
        State.deleteArm = mine
        btn.Text = "Are you sure?"
        btn.TextColor3 = Color3.fromRGB(255, 95, 95)
        notify("Klik Delete sekali lagi untuk menghapus " .. selectedMacro)
        task.delay(3, function()
            if State.deleteArm == mine then
                State.deleteArm = nil
                btn.Text = "Delete"
                btn.TextColor3 = THEME.muted
            end
        end)
        return
    end
    State.deleteArm = nil
    btn.Text = "Delete"
    btn.TextColor3 = THEME.muted
    if FS and delfile and pcall(delfile, macroPath(selectedMacro)) then
        notify("Dihapus: " .. selectedMacro)
        selectedMacro = nil
        refreshMacros()
    else
        notify("Gagal menghapus file (delfile tidak didukung?)")
    end
end)
local newNameInput = sFiles:AddInput("New File Name", "Name", "", nil, false)
sFiles:AddButton("Create Macro File", function()
    local name = cleanName(newNameInput:Get())
    if name == "" then
        notify("Isi New File Name dulu")
        return
    end
    if not ensureDir() then
        notify("Executor tidak mendukung file")
        return
    end
    local filename = name .. ".json"
    local okExists, exists = pcall(isfile, macroPath(filename))
    if okExists and exists then
        notify("File sudah ada")
        return
    end
    if saveMacro(filename, {}) then
        newNameInput:Set("")
        refreshMacros(filename)
        notify("Dibuat: " .. filename)
    end
end)

local sIO = tMacro:AddSection("Import / Export", "left")
local importInput = sIO:AddInput("Macro Link or JSON", "", "", nil, false)
sIO:AddButtonRow("Import Macro", function()
    local raw = importInput:Get()
    if raw == "" then
        notify("Isi link atau JSON dulu")
        return
    end
    local text = raw
    local isUrl = raw:match("^https?://") ~= nil
    if isUrl then
        local ok, res = pcall(function() return game:HttpGet(raw) end)
        if not ok or type(res) ~= "string" then
            notify("Gagal mengunduh link")
            return
        end
        text = res
    end
    local clean = decodeMacro(text)
    if not clean or #clean == 0 then
        notify("JSON macro tidak valid atau kosong")
        return
    end
    local name
    if isUrl then
        local path = raw:gsub("[?#].*$", "") -- buang ?ex=...&is=...&hm=...
        local last = path:match("([^/]+)$") or ""
        last = last:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        last = last:gsub("%.%w+$", "") -- buang ekstensi (.json / .txt)
        name = cleanName(last)
    end
    if not name or name == "" then name = "imported_" .. os.time() end
    if not ensureDir() then
        notify("Executor tidak mendukung file")
        return
    end
    local filename = name .. ".json"
    local i = 2
    while i < 100 and select(2, pcall(isfile, macroPath(filename))) == true do
        filename = name .. "_" .. i .. ".json"
        i = i + 1
    end
    if saveMacro(filename, clean) then
        importInput:Set("")
        refreshMacros(filename)
        notify("Import berhasil: " .. #clean .. " aksi")
    end
end, "Export Selected", function()
    if not selectedMacro or not FS then
        notify("Pilih macro dulu")
        return
    end
    local raw = safeRead(macroPath(selectedMacro))
    if not raw then
        notify("Gagal membaca file")
        return
    end
    if setclipboard and pcall(setclipboard, raw) then
        notify("JSON disalin ke clipboard")
    else
        notify("Executor tidak mendukung setclipboard")
    end
end)

local sRec = tMacro:AddSection("Record / Play", "right")
sRec:AddLabel("Record merekam: unit, posisi (Position + CF), waktu (detik sejak game mulai), upgrade, target, ability, sell.")
recordToggle = sRec:AddToggle("Record Macro", false, function(v)
    if v and State.macroPlay then
        notify("Matikan Play Macro dulu")
        recordToggle:Set(false, true)
        return
    end
    onRecordToggle(v)
end)
sRec:AddDivider()
playToggle = Flag("macroPlay", sRec:AddToggle("Play Macro", false, function(v)
    if v and State.recArmed then
        notify("Matikan Record Macro dulu")
        playToggle:Set(false, true)
        return
    end
    onPlayToggle(v)
end), "toggle")
Flag("tpBeforePlace", sRec:AddToggle("Teleport Before Placing", false, function(v)
    Cfg.teleportBeforePlace = v
end), "toggle")
sRec:AddLabel("Cash kurang = menunggu di posisi sama. Posisi bentrok = digeser sedikit (Placement Spread).")

-- ================================================================
-- TAB: ANTI BAN  (spread, mikro-teleport, auto walk, lobby return)
-- ================================================================
local tAnti = AddTab("Anti Ban")
local sAnti = tAnti:AddSection("Anti Ban", "left")
sAnti:AddLabel("Mengurangi pola gerakan robotik. Tidak ada jaminan 100% bebas deteksi.")
-- Placement Spread: geseran kecil (0.0 - 2.0 studs) saat posisi persis sudah
-- terisi unit lain. Kecil sekali sehingga secara kasat mata unit tidak pindah.
Flag("spread", sAnti:AddSlider("Placement Spread", 0, 2, Cfg.spread, " studs", function(v)
    Cfg.spread = v
end, 0.1))
-- Radius acak titik mendarat Teleport Before Placing
Flag("microTp", sAnti:AddSlider("Micro Teleport Radius", 0, 8, Cfg.microTeleport, " studs", function(v)
    Cfg.microTeleport = v
end))
sAnti:AddDivider()
Flag("autoWalk", sAnti:AddToggle("Auto Walk", false, function(v)
    State.autoWalk = v
    if v then installPlaceWatch() end
    walkLoop(v)
end), "toggle")
Flag("walkRadius", sAnti:AddSlider("Walk Radius", 2, 15, Cfg.walkRadius, " studs", function(v)
    Cfg.walkRadius = v
end))
Flag("walkMax", sAnti:AddSlider("Walk Interval (max)", 5, 30, Cfg.walkMax, "s", function(v)
    Cfg.walkMax = v
end))

local sRet = tAnti:AddSection("Lobby Return", "right")
Flag("matchesBeforeReturn", sRet:AddInput("Matches Before Lobby Return", "1", "1", function(text)
    Cfg.matchesBeforeReturn = math.max(tonumber(text) or 1, 1)
end, true), "input")
Flag("returnAfterX", sRet:AddToggle("Auto Return After X Matches", false, function(v)
    State.returnAfterX = v
    sinceReturn = 0
    if v then connectMatchEnd() end
end), "toggle")

-- ================================================================
-- TAB: WEBHOOK  (Discord + Dashboard API)
-- ================================================================
local tHook = AddTab("Webhook")
local sHook = tHook:AddSection("Discord Webhook", "left")
webhookInput = Flag("webhookUrl", sHook:AddInput("Webhook Link", "https://discord.com/api/webhooks/...", "", nil, false), "input")
sHook:AddButton("Test Send Webhook", function()
    local ok = sendWebhook(buildMatchEmbed(nil, true))
    if ok then notify("Test webhook terkirim") end
end)
Flag("webhook", sHook:AddToggle("Send Webhook On Match End", false, function(v)
    State.webhook = v
    if v then connectMatchEnd() end
end), "toggle")

-- Tag user Discord (pesan dengan tag membuat HP berbunyi seperti chat pribadi)
Flag("discordUserId", sHook:AddInput("Discord User ID (untuk tag)", "mis. 123456789012345678", "", function(t)
    Cfg.discordUserId = (tostring(t):gsub("%D", ""))
end, true), "input")
Flag("tagMatch", sHook:AddToggle("Tag di Setiap Akhir Match", false, function(v) Cfg.tagMatch = v end), "toggle")
Flag("tagDefeat", sHook:AddToggle("Tag Hanya Saat Defeat", false, function(v) Cfg.tagDefeat = v end), "toggle")
sHook:AddLabel("User ID: Discord > Settings > Advanced > Developer Mode ON, lalu klik kanan namamu > Copy User ID.")

-- Target Seeds / Candy sesi ini (dikirim sekali saat tercapai)
local sTarget = tHook:AddSection("Target", "left")
Flag("alertTarget", sTarget:AddToggle("Kirim Saat Target Tercapai", false, function(v) Alerts.cfg.target = v end), "toggle")
Flag("alertTargetSeeds", sTarget:AddInput("Target Seeds (sesi)", "0 = mati", "", function(t)
    Alerts.cfg.targetSeeds = tonumber(t) or 0
    Alerts.hit.seeds = nil -- target diganti: boleh terkirim lagi
end, true), "input")
Flag("alertTargetCandy", sTarget:AddInput("Target " .. GAME.EventCurrencyLabel .. " (sesi)", "0 = mati", "", function(t)
    Alerts.cfg.targetCandy = tonumber(t) or 0
    Alerts.hit.candy = nil
end, true), "input")
Flag("tagTarget", sTarget:AddToggle("Tag Saat Target Tercapai", true, function(v) Cfg.tagTarget = v end), "toggle")
sTarget:AddButton("Test Tag", function()
    if not tostring(Cfg.discordUserId):match("^%d+$") then
        notify("Isi Discord User ID dulu")
        return
    end
    if Alerts.send("test", "🔔 Test Tag", "Kalau HP-mu berbunyi, tag sudah berfungsi.", 0x7C5CFF, true, true) then
        notify("Test tag terkirim")
    end
end)

-- Ringkasan berkala
local sSum = tHook:AddSection("Ringkasan Berkala", "right")
Flag("summary", sSum:AddToggle("Kirim Ringkasan", false, function(v)
    Alerts.cfg.summary = v
    Alerts.nextSummary = nil -- ringkasan pertama dikirim setelah 1 interval
end), "toggle")
Flag("summaryMin", sSum:AddSlider("Interval", 10, 240, Alerts.cfg.summaryMinutes, " mnt", function(v)
    Alerts.cfg.summaryMinutes = v
    Alerts.nextSummary = nil
end))
sSum:AddButton("Kirim Ringkasan Sekarang", function()
    if sendWebhook(buildSummaryEmbed()) then notify("Ringkasan terkirim") end
end)

local sApi = tHook:AddSection("Dashboard API", "right")
sApi:AddLabel("Kirim status akun (username, status, wave, seeds, earned) ke web dashboard.")
Flag("telemetryUrl", sApi:AddInput("API Endpoint", "https://domainmu.com/api/telemetry", "", function(t)
    Cfg.telemetryUrl = (tostring(t):gsub("^%s+", ""):gsub("%s+$", ""))
end, false), "input")
Flag("telemetryKey", sApi:AddInput("API Key", "secret key", "", function(t)
    Cfg.telemetryKey = tostring(t)
end, false), "input")
Flag("telemetryInterval", sApi:AddSlider("Heartbeat Interval", 10, 120, Cfg.telemetryInterval, "s", function(v)
    Cfg.telemetryInterval = v
end))
sApi:AddButton("Test Send", function()
    if not Cfg.telemetryUrl:match("^https?://") then
        notify("Isi API Endpoint dulu (http/https)")
        return
    end
    if sendTelemetry("test") then notify("Dashboard API: terkirim") end
end)
Flag("telemetry", sApi:AddToggle("Enable Telemetry", false, function(v)
    State.telemetry = v
    if v then
        connectMatchEnd()
        task.spawn(sendTelemetry, "heartbeat")
    end
end), "toggle")

--------------------------------------------------------------------
-- CONFIG LOAD
-- 1) daftar macro dimuat, macro tersimpan dipilih ulang
-- 2) nilai input/dropdown/slider dipulihkan (callback ikut jalan)
-- 3) baru toggle dipulihkan, supaya fitur langsung memakai nilai yang benar
--------------------------------------------------------------------
local savedMacro = SavedConfig.selectedMacro
refreshMacros(type(savedMacro) == "string" and savedMacro or nil)

configLoading = true
local okLoad, errLoad = pcall(function()
    for pass = 1, 2 do
        for _, f in ipairs(FlagOrder) do
            local isToggle = (f.kind == "toggle")
            local v = SavedConfig[f.name]
            if v ~= nil and f.name ~= "selectedMacro" and ((pass == 2) == isToggle) then
                local okGet, cur = pcall(f.api.Get, f.api)
                if not okGet or cur ~= v then
                    if f.kind == "input" then
                        f.api:Set(v, true)
                    else
                        f.api:Set(v)
                    end
                end
            end
        end
        if pass == 1 then task.wait(0.1) end -- beri waktu callback nilai selesai
    end
end)
configLoading = false
if not okLoad then warn("[ArdHub] gagal memuat config: " .. tostring(errLoad)) end
if not HAS_FS then notify("Executor tanpa file system: setting tidak tersimpan") end

print("Ard Hub " .. VERSION .. " by Ardhi loaded. Tekan RightControl untuk sembunyikan/tampilkan.")
end -- akhir buildUI

buildUI()

end, function(e)
    return tostring(e) .. "\n" .. tostring(debug.traceback())
end)

if not __ok then
    warn("[ArdHub] ERROR: " .. tostring(__err))
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name = "ArdHubError"
        g.ResetOnSpawn = false
        g.DisplayOrder = 100
        local okp = pcall(function()
            g.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not okp or not g.Parent then
            g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        end
        local f = Instance.new("TextLabel")
        f.Size = UDim2.new(0, 560, 0, 160)
        f.Position = UDim2.new(0.5, -280, 0, 20)
        f.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
        f.TextColor3 = Color3.new(1, 1, 1)
        f.TextWrapped = true
        f.TextSize = 12
        f.Font = Enum.Font.Code
        f.TextXAlignment = Enum.TextXAlignment.Left
        f.TextYAlignment = Enum.TextYAlignment.Top
        f.Text = "Ard Hub ERROR:\n" .. tostring(__err)
        f.Parent = g
    end)
end
