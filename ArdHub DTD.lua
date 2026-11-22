local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local __ok, __err = xpcall(function()
local TITLE = "Ard Hub"
local VERSION = "v1.9.0"
local FOOTER = "Dragon Tower Defense | Ard Hub by Ardhi | " .. VERSION
local ROOT_DIR = "ArdHub"
local CONFIG_FILE = ROOT_DIR .. "/dtd_config.json"
local TOGGLE_KEY = Enum.KeyCode.RightControl
-- Tema "Light Clean" dengan warna brand Ard Hub (design system Ard Hub):
-- surface putih, surface-alt, ink navy, muted slate, line, brand violet (aksen tunggal), brand-soft.
local THEME = {
    bg = Color3.fromRGB(255, 255, 255),        -- surface
    side = Color3.fromRGB(241, 245, 249),      -- surface-alt (bar tab)
    card = Color3.fromRGB(255, 255, 255),      -- kartu
    field = Color3.fromRGB(241, 245, 249),     -- kolom isian / dropdown
    stroke = Color3.fromRGB(226, 232, 240),    -- line
    accent = Color3.fromRGB(109, 40, 217),     -- brand (violet)
    soft = Color3.fromRGB(237, 233, 254),      -- brand-soft
    text = Color3.fromRGB(15, 23, 42),         -- ink (navy)
    label = Color3.fromRGB(51, 65, 85),        -- teks baris
    muted = Color3.fromRGB(71, 85, 105),       -- muted
    hint = Color3.fromRGB(148, 163, 184),      -- placeholder
    off = Color3.fromRGB(203, 213, 225),       -- toggle mati
    on = Color3.fromRGB(15, 23, 42),           -- toggle hidup (ink)
    tile = Color3.fromRGB(15, 23, 42),         -- kotak logo
    tabActive = Color3.fromRGB(255, 255, 255),
}
-- Palet Dark Mode (token tema gelap dari design system Ard Hub). Kunci sama dengan THEME.
-- Setiap peran punya warna yang berbeda di dalam satu palet, supaya warna bisa ditukar balik dengan aman.
local THEME_LIGHT, THEME_DARK = {}, {
    bg = Color3.fromRGB(15, 23, 42),           -- surface (gelap)
    side = Color3.fromRGB(30, 41, 59),         -- surface-alt
    card = Color3.fromRGB(15, 23, 42),
    field = Color3.fromRGB(30, 41, 59),
    stroke = Color3.fromRGB(51, 65, 85),       -- line
    accent = Color3.fromRGB(167, 139, 250),    -- brand (violet muda)
    soft = Color3.fromRGB(46, 16, 101),        -- brand-soft
    text = Color3.fromRGB(248, 250, 252),      -- ink (terang)
    label = Color3.fromRGB(226, 232, 240),
    muted = Color3.fromRGB(203, 213, 225),
    hint = Color3.fromRGB(100, 116, 139),
    off = Color3.fromRGB(71, 85, 105),
    on = Color3.fromRGB(248, 250, 252),
    tile = Color3.fromRGB(15, 23, 42),
    tabActive = Color3.fromRGB(15, 23, 42),
}
for k, v in pairs(THEME) do THEME_LIGHT[k] = v end
-- Font: Space Grotesk (font brand) tidak ada di Roblox; dipakai Builder Sans, cadangan Gotham.
local FONTS = {}
do
    local function pick(list)
        for _, n in ipairs(list) do
            local ok, f = pcall(function() return Enum.Font[n] end)
            if ok and f then return f end
        end
        return Enum.Font.SourceSans
    end
    FONTS.regular = pick({ "BuilderSans", "Gotham" })
    FONTS.medium = pick({ "BuilderSansMedium", "GothamMedium" })
    FONTS.bold = pick({ "BuilderSansBold", "GothamBold" })
end
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
local HttpService = game:GetService("HttpService")
local HAS_FS = (writefile and readfile and isfolder and makefolder and isfile) and true or false
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
local function safeRead(path)
    if not HAS_FS then return nil end
    local ok, res = pcall(function()
        if not isfile(path) then return nil end
        return readfile(path)
    end)
    return (ok and type(res) == "string") and res or nil
end
local function safeWrite(path, content)
    if not HAS_FS then return false end
    return (pcall(writefile, path, tostring(content)))
end
local function jsonEncode(v)
    local ok, res = pcall(HttpService.JSONEncode, HttpService, v)
    return ok and res or nil
end
local function jsonDecode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, res = pcall(HttpService.JSONDecode, HttpService, s)
    return ok and res or nil
end
local Flags = {}
local FlagOrder = {}
local SavedConfig = jsonDecode(safeRead(CONFIG_FILE)) or {}
if type(SavedConfig) ~= "table" then SavedConfig = {} end
if SavedConfig.darkMode ~= false then -- default: Dark Mode
    for k, v in pairs(THEME_DARK) do THEME[k] = v end
end
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
local function queueSave()
    if configLoading or saveQueued or not HAS_FS then return end
    saveQueued = true
    task.delay(1, function()
        saveQueued = false
        saveConfigNow()
    end)
end
local function Flag(name, api, kind)
    if type(api) ~= "table" then return api end
    Flags[name] = api
    FlagOrder[#FlagOrder + 1] = { name = name, api = api, kind = kind or "value" }
    api.Changed = queueSave
    return api
end
-- Logo Ard Hub (huruf A dari tiga titik + titik hub violet), digambar dari Frame karena Roblox tidak bisa memuat SVG.
-- Koordinat diambil dari ardhub-app-icon.svg (kotak 400, tanda 200 diskalakan 1.3 dan digeser 70).
local function drawLogo(parent, size, position)
    local tile = new("Frame", {
        Size = UDim2.new(0, size, 0, size),
        Position = position or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = THEME.tile,
        BorderSizePixel = 0,
        Parent = parent,
    })
    corner(tile, math.floor(size * 0.23 + 0.5))
    local function P(cx, cy) return Vector2.new((70 + 1.3 * cx) / 400 * size, (70 + 1.3 * cy) / 400 * size) end
    local top, bl, br, hub = P(100, 34), P(40, 166), P(160, 166), P(100, 118)
    local th = math.max(14 * 1.3 / 400 * size, 1.5)
    local white = Color3.fromRGB(255, 255, 255)
    for _, seg in ipairs({ { top, bl }, { top, br }, { hub, top }, { hub, bl }, { hub, br } }) do
        local a, b = seg[1], seg[2]
        local mid, d = (a + b) / 2, b - a
        local line = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, d.Magnitude, 0, th),
            Position = UDim2.new(0, mid.X, 0, mid.Y),
            Rotation = math.deg(math.atan2(d.Y, d.X)),
            BackgroundColor3 = white,
            BorderSizePixel = 0,
            Parent = tile,
        })
        corner(line, math.ceil(th))
    end
    local function dot(p, r, color, ring)
        local c = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, r * 2, 0, r * 2),
            Position = UDim2.new(0, p.X, 0, p.Y),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = tile,
        })
        corner(c, math.ceil(r * 2))
        if ring then stroke(c, THEME.tile, math.max(7 * 1.3 / 400 * size, 1)) end
        return c
    end
    local nr = 15 * 1.3 / 400 * size
    dot(top, nr, white)
    dot(bl, nr, white)
    dot(br, nr, white)
    dot(hub, 22 * 1.3 / 400 * size, Color3.fromRGB(167, 139, 250), true)
    return tile
end
for _, n in ipairs({ "ArdHubDTDGui", "ArdHubDTDBlack", "ArdHubDTDStatus", "ArdHubDTDError" }) do
    pcall(destroyOld, n)
end
local Gui = new("ScreenGui", {
    Name = "ArdHubDTDGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 10,
    IgnoreGuiInset = true,
})
setParent(Gui)
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
corner(Main, 16)
do -- Ukuran jendela menyesuaikan layar: paling besar 80% lebar dan 75% tinggi layar (diperkecil merata).
    local scale = new("UIScale", { Parent = Main })
    local function fit()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        scale.Scale = math.clamp(math.min(vp.X * 0.8 / 600, vp.Y * 0.75 / 340), 0.6, 1)
    end
    fit()
    -- posisi awal di tengah layar (titik acuan jendela tetap pojok kiri atas, seperti versi lama)
    Main.Position = UDim2.new(0.5, -300 * scale.Scale, 0.5, -170 * scale.Scale)
    pcall(function()
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end)
end
stroke(Main, THEME.stroke, 1)
-- SearchBox: kotak cari fitur; TabBar: deretan tab; Pages: isi tab; HubStatus: badge status di kepala jendela
local SearchBox, TabBar, Pages, HubStatus, ApplyTheme, AddThemeRoot, ThemeToggle
do
local HEADER_H = 54
local Header = new("Frame", {
    Name = "Header",
    Active = true,
    Size = UDim2.new(1, 0, 0, HEADER_H),
    BackgroundTransparency = 1,
    Parent = Main,
})
local Logo = drawLogo(Header, 30, UDim2.new(0, 16, 0, 12))
local TitleLabel = new("TextLabel", {
    Size = UDim2.new(0, 180, 0, 18),
    Position = UDim2.new(0, 54, 0, 10),
    BackgroundTransparency = 1,
    Text = TITLE,
    TextColor3 = THEME.text,
    Font = FONTS.bold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header,
})
local SubLabel = new("TextLabel", {
    Size = UDim2.new(0, 220, 0, 14),
    Position = UDim2.new(0, 54, 0, 29),
    BackgroundTransparency = 1,
    Text = VERSION .. " · Dragon Tower Defense",
    TextColor3 = THEME.muted,
    Font = FONTS.medium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header,
})
local MinBtn = new("TextButton", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -44, 0, 13),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Parent = Header,
})
corner(MinBtn, 8)
local MinIcon = new("Frame", {
    Size = UDim2.new(0, 10, 0, 2),
    Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = THEME.muted,
    BorderSizePixel = 0,
    Parent = MinBtn,
})
corner(MinIcon, 1)
-- Tombol Dark Mode (ikon lingkaran setengah terisi), di kiri tombol perkecil
local ThemeBtn = new("TextButton", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -78, 0, 13),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Parent = Header,
})
corner(ThemeBtn, 8)
do
    local ring = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0.5, -6, 0.5, -6),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, Parent = ThemeBtn,
    })
    corner(ring, 6)
    stroke(ring, THEME.muted, 1.5)
    local half = new("Frame", {
        Size = UDim2.new(0, 6, 0, 12), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = THEME.muted, BorderSizePixel = 0, Parent = ring,
    })
    corner(half, 6)
    new("Frame", { -- meratakan sisi kanan setengah lingkaran
        Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(1, -3, 0, 0),
        BackgroundColor3 = THEME.muted, BorderSizePixel = 0, Parent = half,
    })
end
-- Ganti tema: setiap warna di jendela ditukar ke warna peran yang sama di palet tujuan.
local themeRoots = { Main }
local function colorKey(c) return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
ApplyTheme = function(dark)
    local target = dark and THEME_DARK or THEME_LIGHT
    local map = {}
    for k, v in pairs(THEME) do
        if k ~= "tile" then map[colorKey(v)] = target[k] end -- tile hanya untuk logo (diatur terpisah)
    end
    local function swap(o, prop)
        local ok, c = pcall(function() return o[prop] end)
        if ok and typeof(c) == "Color3" then
            local n = map[colorKey(c)]
            if n then pcall(function() o[prop] = n end) end
        end
    end
    for _, root in ipairs(themeRoots) do
        for _, o in ipairs(root:GetDescendants()) do
            if not o:IsDescendantOf(Logo) then
                if o:IsA("UIStroke") then
                    swap(o, "Color")
                elseif o:IsA("GuiObject") then
                    swap(o, "BackgroundColor3")
                    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                        swap(o, "TextColor3")
                        if o:IsA("TextBox") then swap(o, "PlaceholderColor3") end
                    elseif o:IsA("ScrollingFrame") then
                        swap(o, "ScrollBarImageColor3")
                    end
                end
            end
        end
        if root:IsA("GuiObject") then swap(root, "BackgroundColor3") end
    end
    for k, v in pairs(target) do THEME[k] = v end
    -- kotak logo: di mode gelap diberi warna surface-alt supaya tidak hilang di latar navy
    Logo.BackgroundColor3 = dark and THEME_DARK.side or THEME_LIGHT.tile
    for _, d in ipairs(Logo:GetDescendants()) do
        if d:IsA("UIStroke") then d.Color = Logo.BackgroundColor3 end
    end
    for _, c in ipairs(Main:GetChildren()) do
        if c:IsA("UIStroke") then c.Color = THEME.stroke end
    end
end
AddThemeRoot = function(root) themeRoots[#themeRoots + 1] = root end
ThemeToggle = { dark = SavedConfig.darkMode ~= false }
function ThemeToggle:Get() return self.dark end
function ThemeToggle:Set(v)
    v = v and true or false
    if v == self.dark then return end
    self.dark = v
    ApplyTheme(v)
    if self.Changed then self.Changed(v) end
end
ThemeBtn.MouseButton1Click:Connect(function() ThemeToggle:Set(not ThemeToggle.dark) end)
if ThemeToggle.dark then
    Logo.BackgroundColor3 = THEME_DARK.side
    for _, d in ipairs(Logo:GetDescendants()) do
        if d:IsA("UIStroke") then d.Color = THEME_DARK.side end
    end
end
-- badge status: "Lobby" (abu) / "In match" (violet), diperbarui dari bagian game di bawah
local StatusPill = new("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 0, 24),
    Position = UDim2.new(1, -114, 0, 15),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    Parent = Header,
})
corner(StatusPill, 12)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = StatusPill })
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = StatusPill,
})
local StatusDot = new("Frame", {
    Size = UDim2.new(0, 7, 0, 7), BackgroundColor3 = THEME.muted, BorderSizePixel = 0, LayoutOrder = 1, Parent = StatusPill,
})
corner(StatusDot, 4)
local StatusText = new("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Lobby",
    TextColor3 = THEME.muted,
    Font = FONTS.bold,
    TextSize = 11,
    LayoutOrder = 2,
    Parent = StatusPill,
})
HubStatus = function(text, active)
    StatusText.Text = text
    StatusPill.BackgroundColor3 = active and THEME.soft or THEME.side
    StatusText.TextColor3 = active and THEME.accent or THEME.muted
    StatusDot.BackgroundColor3 = active and THEME.accent or THEME.muted
end
-- kotak cari fitur, di kiri badge status
local SearchFrame = new("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Size = UDim2.new(0, 150, 0, 28),
    Position = UDim2.new(1, -214, 0, 13),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    Parent = Header,
})
corner(SearchFrame, 8)
local mag = new("Frame", {
    Size = UDim2.new(0, 10, 0, 10),
    Position = UDim2.new(0, 10, 0.5, -6),
    BackgroundTransparency = 1,
    Parent = SearchFrame,
})
corner(mag, 6)
stroke(mag, THEME.hint, 1.5)
new("Frame", {
    Size = UDim2.new(0, 5, 0, 1.5),
    Position = UDim2.new(0, 18, 0.5, 4),
    Rotation = 45,
    BackgroundColor3 = THEME.hint,
    BorderSizePixel = 0,
    Parent = SearchFrame,
})
SearchBox = new("TextBox", {
    Size = UDim2.new(1, -36, 1, 0),
    Position = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1,
    ClearTextOnFocus = false,
    PlaceholderText = "Cari fitur",
    PlaceholderColor3 = THEME.hint,
    Text = "",
    TextColor3 = THEME.text,
    Font = FONTS.regular,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = SearchFrame,
})
-- deretan tab (segmen)
local TabHolder = new("Frame", {
    Size = UDim2.new(1, -32, 0, 34),
    Position = UDim2.new(0, 16, 0, HEADER_H),
    BackgroundColor3 = THEME.side,
    BorderSizePixel = 0,
    Parent = Main,
})
corner(TabHolder, 10)
TabBar = new("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Parent = TabHolder,
})
new("UIPadding", {
    PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
    Parent = TabBar,
})
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3),
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabBar,
})
local PAGES_Y = HEADER_H + 34 + 10
Pages = new("Frame", {
    Name = "Pages",
    Size = UDim2.new(1, -32, 1, -(PAGES_Y + 12)),
    Position = UDim2.new(0, 16, 0, PAGES_Y),
    BackgroundTransparency = 1,
    Parent = Main,
})
do -- geser jendela lewat kepala jendela
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
    Header.InputBegan:Connect(begin)
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
local MIN_W, MIN_H = 520, 260
local MAX_W, MAX_H = 960, 640
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
        Position = UDim2.new(1, -(4 + k * 4) - 5, 1, -(4 + (2 - k) * 4) - 3),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
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
            local sc = Main:FindFirstChildOfClass("UIScale")
            local d = (input.Position - startPos) / ((sc and sc.Scale > 0) and sc.Scale or 1)
            local w = math.clamp(startSize.X + d.X, MIN_W, MAX_W)
            local h = math.clamp(startSize.Y + d.Y, MIN_H, MAX_H)
            Main.Size = UDim2.new(0, w, 0, h)
        end
    end)
end
-- Perkecil: jendela menjadi pil kecil (logo + Ard Hub); tekan tombol yang sama untuk membuka lagi.
local minimized = false
local savedSize = Main.Size
local MINI_W, MINI_H = 168, 54
local function setMinimized(v)
    minimized = v
    local full = { TabHolder, Pages, Grip, SearchFrame, StatusPill, SubLabel, ThemeBtn }
    if v then
        savedSize = Main.Size
        for _, o in ipairs(full) do o.Visible = false end
        TitleLabel.Position = UDim2.new(0, 54, 0, 18)
        MinIcon.Size = UDim2.new(0, 10, 0, 10)
        MinIcon.Position = UDim2.new(0.5, -5, 0.5, -5)
        MinIcon.BackgroundTransparency = 1
        stroke(MinIcon, THEME.muted, 1.5)
        TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, MINI_W, 0, MINI_H),
        }):Play()
    else
        TitleLabel.Position = UDim2.new(0, 54, 0, 10)
        for _, c in ipairs(MinIcon:GetChildren()) do
            if c:IsA("UIStroke") then c:Destroy() end
        end
        MinIcon.Size = UDim2.new(0, 10, 0, 2)
        MinIcon.Position = UDim2.new(0.5, -5, 0.5, -1)
        MinIcon.BackgroundTransparency = 0
        -- Saat dibuka lagi, jendela kembali ke tengah layar dengan ukuran sebelum di-minimize.
        local goal = { Size = savedSize }
        pcall(function()
            local sc = Main:FindFirstChildOfClass("UIScale")
            local k = sc and sc.Scale or 1
            goal.Position = UDim2.new(0.5, -savedSize.X.Offset * k / 2, 0.5, -savedSize.Y.Offset * k / 2)
        end)
        local t = TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), goal)
        t:Play()
        t.Completed:Connect(function()
            if not minimized then
                for _, o in ipairs(full) do o.Visible = true end
            end
        end)
    end
end
MinBtn.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end)
end
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
local function resizeTabs()
    local n = math.max(#Tabs, 1)
    for _, t in ipairs(Tabs) do
        t.Button.Size = UDim2.new(1 / n, -3 * (n - 1) / n, 1, 0)
    end
end
local function selectTab(tab)
    for _, t in ipairs(Tabs) do
        local active = (t == tab)
        t.Page.Visible = active
        t.Button.BackgroundTransparency = active and 0 or 1
        t.Shadow.Enabled = active
        t.Button.TextColor3 = active and THEME.text or THEME.muted
        t.Button.Font = active and FONTS.bold or FONTS.medium
    end
end
-- Panah kecil dari dua garis: dir "down" (v), "up" (^), "right" (>)
local function makeChevron(parent, position)
    local holder = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12), Position = position, BackgroundTransparency = 1, Parent = parent,
    })
    local bars = {}
    for i = 1, 2 do
        bars[i] = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 7, 0, 2),
            BackgroundColor3 = THEME.hint, BorderSizePixel = 0, Parent = holder,
        })
        corner(bars[i], 1)
    end
    local shapes = {
        down = { { 4, 6, 45 }, { 8, 6, -45 } },
        up = { { 4, 6, -45 }, { 8, 6, 45 } },
        right = { { 6, 4, 45 }, { 6, 8, -45 } },
    }
    local function set(dir)
        for i, sp in ipairs(shapes[dir] or shapes.down) do
            bars[i].Position = UDim2.new(0, sp[1], 0, sp[2])
            bars[i].Rotation = sp[3]
        end
    end
    set("down")
    return holder, set
end
local Section = {}
Section.__index = Section
function Section:AddToggle(text, default, callback)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = THEME.side,
        BorderSizePixel = 0,
        Parent = row,
    })
    local label = new("TextLabel", {
        Size = UDim2.new(1, -48, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.label,
        Font = FONTS.regular,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local pill = new("Frame", {
        Size = UDim2.new(0, 34, 0, 20),
        Position = UDim2.new(1, -34, 0.5, -10),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(pill, 10)
    local knob = new("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = THEME.bg,
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(knob, 8)
    local state = false
    local api = {}
    local function render(animate)
        local goalColor = state and THEME.on or THEME.off
        local goalPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        if animate then
            local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(pill, info, { BackgroundColor3 = goalColor }):Play()
            TweenService:Create(knob, info, { Position = goalPos }):Play()
        else
            pill.BackgroundColor3 = goalColor
            knob.Position = goalPos
        end
        label.TextColor3 = state and THEME.text or THEME.label
    end
    function api:Set(v, silent)
        state = v and true or false
        render(true)
        if api.Changed then api.Changed(state) end
        if callback and not silent then
            task.spawn(function()
                pcall(callback, state)
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
        Size = UDim2.new(1, 0, 0, 11),
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
        BackgroundColor3 = THEME.bg,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = text,
        TextColor3 = THEME.text,
        Font = FONTS.medium,
        TextSize = 12,
        LayoutOrder = order or 0,
        Parent = parent,
    })
    corner(btn, 8)
    stroke(btn, THEME.stroke, 1)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = THEME.side end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = THEME.bg end)
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
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = holder })
    local titleLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = THEME.muted,
        Font = FONTS.medium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = holder,
    })
    return holder, titleLabel
end
function Section:AddLabel(text)
    local row = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.muted,
        Font = FONTS.regular,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), Parent = row })
    table.insert(self.Items, { Row = row, IsDivider = true })
    return row
end
function Section:AddButton(text, callback)
    local wrap = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    local btn = makeButton(wrap, text, UDim2.new(1, 0, 0, 30), 0)
    btn.Position = UDim2.new(0, 0, 0, 4)
    btn.MouseButton1Click:Connect(function()
        task.spawn(function()
            pcall(callback)
        end)
    end)
    table.insert(self.Items, { Row = wrap, Text = text })
    return btn
end
function Section:AddButtonRow(textA, callbackA, textB, callbackB)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
        Parent = self.Body,
    })
    local a = makeButton(row, textA, UDim2.new(0.5, -4, 0, 30), 0)
    local b = makeButton(row, textB, UDim2.new(0.5, -4, 0, 30), 0)
    a.Position = UDim2.new(0, 0, 0, 4)
    b.Position = UDim2.new(0.5, 4, 0, 4)
    local function run(label, cb, btn)
        task.spawn(function()
            pcall(cb, btn)
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
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = THEME.field,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = THEME.hint,
        Text = default or "",
        TextColor3 = THEME.text,
        Font = FONTS.regular,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
        Parent = holder,
    })
    corner(box, 8)
    local st = stroke(box, THEME.stroke, 1)
    box.Focused:Connect(function() st.Color = THEME.accent end)
    box.FocusLost:Connect(function() st.Color = THEME.stroke end)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box })
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
                pcall(callback, box.Text)
            end)
        end
    end
    box.FocusLost:Connect(fire)
    function api:Get() return box.Text end
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
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = THEME.field,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 2,
        Parent = holder,
    })
    corner(btn, 8)
    stroke(btn, THEME.stroke, 1)
    local valueLabel = new("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = THEME.text,
        Font = FONTS.regular,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = btn,
    })
    local _, setArrow = makeChevron(btn, UDim2.new(1, -22, 0.5, -6))
    -- Daftar pilihan: paling tinggi DROPDOWN_ROWS baris, sisanya di-scroll (tidak memanjang ke bawah).
    local DROPDOWN_ROWS, ROW_H = 5, 26
    local list = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = THEME.bg,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.off,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        LayoutOrder = 3,
        Parent = holder,
    })
    corner(list, 8)
    stroke(list, THEME.stroke, 1)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    new("UIPadding", {
        PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3),
        Parent = list,
    })
    local api = {}
    local current = default
    local function close()
        list.Visible = false
        setArrow("down")
    end
    local function setValue(v, silent)
        current = v
        valueLabel.Text = tostring(v or "")
        if api.Changed and not silent then api.Changed(v) end
        if callback and not silent then
            task.spawn(function()
                pcall(callback, v)
            end)
        end
    end
    local function rebuild(opts)
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        list.Size = UDim2.new(1, 0, 0, math.min(math.max(#opts, 1), DROPDOWN_ROWS) * ROW_H + 6)
        list.CanvasPosition = Vector2.new(0, 0)
        for i, opt in ipairs(opts) do
            local b = new("TextButton", {
                Size = UDim2.new(1, -4, 0, ROW_H),
                BackgroundColor3 = THEME.side,
                BackgroundTransparency = 1,
                Text = "  " .. tostring(opt),
                TextColor3 = THEME.label,
                Font = FONTS.regular,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = list,
            })
            corner(b, 6)
            b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
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
        setArrow(list.Visible and "up" or "down")
    end)
    function api:Set(v, silent) setValue(v, silent) end
    function api:Get() return current end
    function api:SetOptions(opts) rebuild(opts) end
    table.insert(self.Items, { Row = holder, Text = title })
    return api
end
function Section:AddSlider(title, min, max, default, suffix, callback, step)
    local holder, titleLabel = makeFieldHolder(self.Body, title)
    titleLabel.TextColor3 = THEME.label
    titleLabel.Font = FONTS.regular
    titleLabel.TextSize = 13
    titleLabel.Size = UDim2.new(1, -90, 0, 17)
    -- nilai di kanan judul (judul selebar holder - 90, nilai mengisi 90px sisanya)
    local valueLabel = new("TextLabel", {
        Size = UDim2.new(0, 90, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = THEME.muted,
        Font = FONTS.medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = titleLabel,
    })
    -- area sentuh 22px, batang 5px di tengahnya
    local bar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Active = true,
        LayoutOrder = 2,
        Parent = holder,
    })
    local track = new("Frame", {
        Size = UDim2.new(1, -16, 0, 5),
        Position = UDim2.new(0, 8, 0.5, -2),
        BackgroundColor3 = THEME.stroke,
        BorderSizePixel = 0,
        Parent = bar,
    })
    corner(track, 3)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.on,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 3)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = THEME.bg,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = track,
    })
    corner(knob, 8)
    stroke(knob, THEME.on, 2)
    suffix = suffix or ""
    step = (tonumber(step) and step > 0) and step or 1
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
        local span = max - min
        local a = span > 0 and (value - min) / span or 0
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        valueLabel.Text = show(value) .. suffix
    end
    render()
    local function apply(v)
        v = snap(tonumber(v) or value)
        if v == value then return end
        value = v
        render()
        if api.Changed then api.Changed(v) end
        if callback then
            task.spawn(function()
                pcall(callback, v)
            end)
        end
    end
    local function setFromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
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
    corner(frame, 14)
    stroke(frame, THEME.stroke, 1)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
    local header = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        Parent = frame,
    })
    new("TextLabel", {
        Size = UDim2.new(1, -48, 1, 0),
        Position = UDim2.new(0, 14, 0, 2),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = THEME.text,
        Font = FONTS.bold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })
    local _, setChevron = makeChevron(header, UDim2.new(1, -28, 0.5, -5))
    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = frame,
    })
    new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 10),
        Parent = body,
    })
    local open = true
    header.MouseButton1Click:Connect(function()
        open = not open
        body.Visible = open
        setChevron(open and "down" or "right")
    end)
    local sec = setmetatable({ Frame = frame, Body = body, Items = {} }, Section)
    table.insert(Sections, sec)
    return sec
end
function AddTab(name)
    tabCount = tabCount + 1
    local btn = new("TextButton", {
        Name = name,
        Size = UDim2.new(0, 90, 1, 0),
        BackgroundColor3 = THEME.tabActive,
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = THEME.muted,
        Font = FONTS.medium,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        LayoutOrder = tabCount,
        Parent = TabBar,
    })
    corner(btn, 8)
    local shadow = stroke(btn, THEME.stroke, 1)
    shadow.Enabled = false
    local page = new("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.off,
        CanvasSize = UDim2.new(0, 0, 0, 300),
        Visible = false,
        Parent = Pages,
    })
    local function column(xScale, xOffset)
        local f = new("Frame", {
            Size = UDim2.new(0.5, -6, 0, 0),
            Position = UDim2.new(xScale, xOffset, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
        return f
    end
    local left = column(0, 0)
    local right = column(0.5, 6)
    local function updateCanvas()
        -- AbsoluteSize sudah diperkecil oleh UIScale jendela, sedangkan CanvasSize ikut diperkecil lagi:
        -- dibagi skala supaya tinggi area scroll pas dengan isinya.
        local sc = Main:FindFirstChildOfClass("UIScale")
        local k = (sc and sc.Scale > 0) and sc.Scale or 1
        page.CanvasSize = UDim2.new(0, 0, 0, math.max(left.AbsoluteSize.Y, right.AbsoluteSize.Y) / k + 6)
    end
    left:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
    right:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
    task.defer(updateCanvas)
    local tab = setmetatable({
        Name = name, Button = btn, Page = page, Shadow = shadow,
        Left = left, Right = right,
    }, Tab)
    table.insert(Tabs, tab)
    resizeTabs()
    btn.MouseButton1Click:Connect(function()
        selectTab(tab)
    end)
    btn.MouseEnter:Connect(function()
        if not tab.Page.Visible then btn.TextColor3 = THEME.text end
    end)
    btn.MouseLeave:Connect(function()
        if not tab.Page.Visible then btn.TextColor3 = THEME.muted end
    end)
    if #Tabs == 1 then
        selectTab(tab)
    end
    return tab
end
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == TOGGLE_KEY then
        Gui.Enabled = not Gui.Enabled
    end
end)
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local alive = true
Gui.Destroying:Connect(function()
    alive = false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
end)
local Toast = new("TextLabel", {
    Name = "Toast",
    Size = UDim2.new(0, 340, 0, 30),
    Position = UDim2.new(0.5, -170, 1, -44),
    BackgroundColor3 = THEME.text,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = THEME.bg,
    Font = FONTS.medium,
    TextSize = 12,
    TextWrapped = true,
    Visible = false,
    ZIndex = 30,
    Parent = Main,
})
corner(Toast, 10)
local toastToken = 0
local function notify(text)
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
local StatusGui = new("ScreenGui", {
    Name = "ArdHubDTDStatus",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 11,
    IgnoreGuiInset = true,
})
setParent(StatusGui)
AddThemeRoot(StatusGui)
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
    Font = FONTS.medium,
    TextSize = 13,
    Visible = false,
    Parent = StatusGui,
})
corner(StatusBox, 12)
stroke(StatusBox, THEME.stroke, 1)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = StatusBox })
local function setPlayStatus(text)
    if text then
        StatusBox.Text = text
        StatusBox.Visible = true
    else
        StatusBox.Visible = false
    end
end
-- =====================================================================
-- DRAGON TOWER DEFENSE: dasar (remote, atribut akun, status match)
-- =====================================================================
local LOBBY_PLACE = 103076556916764
local function isLobby() return game.PlaceId == LOBBY_PLACE end
-- server match = bukan lobby dan bukan Mine (tiap map bisa punya PlaceId sendiri)
local function inMatch()
    return game.PlaceId ~= LOBBY_PLACE and workspace:FindFirstChild("MyMinePit") == nil
end
local SAVE_DIR = ROOT_DIR .. "/DragonTD"
local Cfg = {
    autoJoin = false, map = "Volcano Fortress", pad = 1, turkeyPad = 4, autoFriends = false,
    autoSummon = false, summonAmount = 10, summonDelay = 1,
    potionCoins = false, potionLuck = false, potionSpeed = false,
    claimQuest = false, claimBonus = false, claimPlaytime = false, claimIndex = false, claimBP = false,
    autoStart = false, autoSkip = false, autoAgain = false, autoReturn = false, returnEvery = 10,
    autoSpeed = false, speed = 2,
    autoWalk = false, walkRadius = 6, walkMax = 9, antiAfk = true,
    spread = 0.3, placeMode = "Time",
    fpsLimit = 30, autoExec = false,
    autoMine = false, autoDig = false, mineDelay = 0, minePattern = "Lorong Cepat",
    discordUserId = "", tagEvery = false, tagDefeat = true, whMatchEnd = false,
    whAvatar = true, whWave = true, whBP = true, whDaily = true, whCoins = true, whSummon = false,
    summary = false, summaryMinutes = 60,
    alertTarget = false, targetCoins = 0, targetGems = 0, tagTarget = true,
    telemetryUrl = "https://joljavywvuegtpeftlga.supabase.co/rest/v1/rpc/ard_telemetry?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpvbGphdnl3dnVlZ3RwZWZ0bGdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0MTEyNzQsImV4cCI6MjEwOTk4NzI3NH0.CV2fW0EQ4Pf_Ab-1zX0mwn34yuXwLKBM6Z-rGE8E0eM",
}
local REQ = (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)

local function comma(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if s:sub(1, 1) == "," then s = s:sub(2) end
    return (n < 0 and "-" or "") .. s
end
local function plainText(t) return (tostring(t or ""):gsub("<[^>]->", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function guiShown(g)
    local x = g
    while x and x ~= game do
        if x:IsA("GuiObject") and not x.Visible then return false end
        if x:IsA("ScreenGui") and not x.Enabled then return false end
        x = x.Parent
    end
    return true
end
local function flatDist(a, b) return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude end
local function charParts()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health <= 0 then return nil end
    return char, hum, hrp
end
local function pivotOf(inst)
    local ok, p = pcall(function() return inst:IsA("BasePart") and inst.Position or inst:GetPivot().Position end)
    return ok and p or nil
end
local function kindOf(model) return tostring(model.Name):match("^(.-)_%d+$") or tostring(model.Name) end
local function prettyMap(name) return (tostring(name or "?"):gsub("(%l)(%u)", "%1 %2")) end

-- remote
local remoteCache = {}
local function findRemote(name)
    local r = remoteCache[name]
    if r and r.Parent then return r end
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    r = (folder and folder:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name)
    if not r then
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d.Name == name and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then r = d break end
        end
    end
    remoteCache[name] = r
    return r
end
-- hasil: ok, balasan1, balasan2, ...
local function callRemote(name, ...)
    local r = findRemote(name)
    if not r then return false, "remote " .. name .. " tidak ditemukan" end
    if r:IsA("RemoteFunction") then return pcall(r.InvokeServer, r, ...) end
    return pcall(r.FireServer, r, ...)
end

-- atribut akun (Coins, Gems, Battlepass, Quests, ...)
local function attr(n)
    local ok, v = pcall(LocalPlayer.GetAttribute, LocalPlayer, n)
    if ok then return v end
    return nil
end
local function jattr(n)
    local v = attr(n)
    if type(v) == "string" then return jsonDecode(v) end
    return nil
end
-- Battle Pass: tier ke-k (mulai 0) butuh 10.000 + 500 x k XP. XP harian maksimal 25.000 (lewat itu 10%).
local function bpInfo()
    local bp = jattr("Battlepass") or {}
    local total = tonumber(bp.xp) or 0
    local xp, tier = total, 0
    local need = 10000
    while xp >= need and tier < 30 do
        xp = xp - need
        tier = tier + 1
        need = 10000 + 500 * tier
    end
    local today = math.floor(os.time() / 86400)
    local daily = (tonumber(bp.dd) == today) and (tonumber(bp.dx) or 0) or 0
    return {
        tier = tier, xp = xp, need = need, total = total, daily = daily, dailyMax = 25000,
        free = type(bp.cf) == "table" and #bp.cf or 0, pass = type(bp.cp) == "table" and #bp.cp or 0, paid = bp.paid == true,
    }
end
local QUEST_TARGET = { d_play = 2, d_evolve = 3, d_win = 1, w_nightmare = 1, w_legend = 1, w_time90 = 5400, w_play = 20, w_summon = 50 }
local QUEST_NAME = {
    d_play = "Play 2 matches", d_evolve = "Evolve 3 dragons", d_win = "Win 1 match", w_nightmare = "Win on Nightmare",
    w_legend = "Summon a Legendary", w_time90 = "Play 1h 30m", w_play = "Play 20 matches", w_summon = "Summon 50 times",
}
local function questInfo()
    local q = jattr("Quests") or {}
    local out = {}
    for _, kind in ipairs({ "daily", "weekly" }) do
        local list = type(q[kind]) == "table" and q[kind].list or {}
        local done, open = 0, {}
        for _, it in ipairs(type(list) == "table" and list or {}) do
            if it.claimed then
                done = done + 1
            else
                local tgt = QUEST_TARGET[it.id]
                open[#open + 1] = string.format("%s %s/%s", QUEST_NAME[it.id] or tostring(it.id),
                    comma(it.id == "w_time90" and (tonumber(it.n) or 0) / 60 or it.n), tgt and comma(it.id == "w_time90" and tgt / 60 or tgt) or "?")
            end
        end
        out[kind] = { done = done, total = #(type(list) == "table" and list or {}), open = open,
            period = type(q[kind]) == "table" and q[kind].period or nil, list = list }
    end
    return out
end
local questCache = nil
local function questLine()
    local qi = questInfo()
    if qi.daily.total + qi.weekly.total == 0 then
        return questCache or "Quest: belum terbaca (hanya ada di lobby)"
    end
    local parts = {
        string.format("Daily %d/%d%s", qi.daily.done, qi.daily.total, (qi.daily.total > 0 and qi.daily.done == qi.daily.total) and " ✅" or ""),
        string.format("Weekly %d/%d%s", qi.weekly.done, qi.weekly.total, (qi.weekly.total > 0 and qi.weekly.done == qi.weekly.total) and " ✅" or ""),
    }
    for _, o in ipairs(qi.weekly.open) do parts[#parts + 1] = o end
    questCache = table.concat(parts, " · ")
    return questCache
end

-- Sesi: tetap dihitung lintas server (lobby <-> match) lewat file, reset kalau 30 menit tidak aktif
local SESSION_FILE = ROOT_DIR .. "/dtd_session.json"
local Session = jsonDecode(safeRead(SESSION_FILE))
if type(Session) ~= "table" or not tonumber(Session.updated) or os.time() - Session.updated > 1800 then
    Session = { start = os.time(), matches = 0, wins = 0, losses = 0, coinsEarned = 0, summons = {}, summonCount = 0, claimed = 0 }
end
Session.summons = type(Session.summons) == "table" and Session.summons or {}
local function saveSession()
    Session.updated = os.time()
    if Session.coinsStart == nil and tonumber(attr("Coins")) then
        Session.coinsStart = tonumber(attr("Coins"))
        Session.gemsStart = tonumber(attr("Gems")) or 0
    end
    safeMakeDir(ROOT_DIR)
    local enc = jsonEncode(Session)
    if enc then safeWrite(SESSION_FILE, enc) end
end
saveSession()
task.spawn(function()
    while alive do
        task.wait(30)
        pcall(saveSession)
    end
end)
local function sessionTime()
    local s = os.time() - (tonumber(Session.start) or os.time())
    local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
    return h > 0 and string.format("%dj %dm", h, m) or string.format("%dm", m)
end
-- wave tertinggi per map (dari match yang dimenangkan), untuk bar wave saat kalah
local WAVES_FILE = ROOT_DIR .. "/dtd_waves.json"
local MapWaves = jsonDecode(safeRead(WAVES_FILE))
if type(MapWaves) ~= "table" then MapWaves = {} end

-- status match
local Match = { started = nil, endedAt = 0, lastCamera = 0, lastCombat = 0, scriptStart = os.clock(), map = nil, count = 0, lastTimer = nil }
local MatchEndedEv = Instance.new("BindableEvent")
local KNOWN_MAPS = { "CastleTown", "SunnyMeadow", "PirateCove", "SnowySummit", "VolcanoFortress" }
if inMatch() then
    for _, n in ipairs(KNOWN_MAPS) do
        if workspace:FindFirstChild(n) then Match.map = n break end
    end
end

-- timer game: label "m:ss" yang terus naik = detik sejak match mulai
local timerLabel = nil
local function parseClock(text)
    local m, s = plainText(text):match("^(%d+):(%d%d)$")
    if not m then return nil end
    return tonumber(m) * 60 + tonumber(s)
end
local function gameElapsed()
    if timerLabel and timerLabel.Parent and guiShown(timerLabel) then
        local v = parseClock(timerLabel.Text)
        if v then return v end
    end
    timerLabel = nil
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg or not inMatch() then return nil end
    local first = {}
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") and guiShown(d) then
            local v = parseClock(d.Text)
            if v then first[d] = v end
        end
    end
    if next(first) == nil then return nil end
    task.wait(1.2)
    for d, v in pairs(first) do
        local v2 = parseClock(d.Text)
        if v2 and v2 - v >= 1 and v2 - v <= 3 then
            timerLabel = d
            return v2
        end
    end
    return nil
end
-- wave dari layar ("Wave 12", "Wave 12/40", "WAVE 12 / 40")
local waveLabel = nil
local function parseWave(text)
    local t = plainText(text)
    local w, total = t:match("^[Ww][Aa][Vv][Ee]%s*(%d+)%s*/%s*(%d+)$")
    if not w then w = t:match("^[Ww][Aa][Vv][Ee]%s*(%d+)$") end
    return tonumber(w), tonumber(total)
end
local function readWave()
    if not inMatch() then return nil end
    if waveLabel and waveLabel.Parent and guiShown(waveLabel) then
        local w, t = parseWave(waveLabel.Text)
        if w then return w, t end
    end
    waveLabel = nil
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    for _, d in ipairs(pg and pg:GetDescendants() or {}) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and guiShown(d) then
            local w, t = parseWave(d.Text)
            if w then
                waveLabel = d
                return w, t
            end
        end
    end
    return nil
end
local function matchRunning()
    return (Match.started and Match.started > Match.endedAt) or (os.clock() - Match.lastCombat < 5)
end

-- remote masuk
do
    local watched = setmetatable({}, { __mode = "k" })
    local function watch(r)
        if watched[r] or not (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then return end
        local n = r.Name
        if n == "EnemyHits" or n == "EnemyKilled" then
            watched[r] = true
            r.OnClientEvent:Connect(function() if alive then Match.lastCombat = os.clock() end end)
        elseif n == "CameraTurn" then
            watched[r] = true
            r.OnClientEvent:Connect(function(spawn)
                if not alive then return end
                Match.lastCamera = os.clock()
                pcall(function() if spawn and spawn.Parent then Match.map = spawn.Parent.Name end end)
            end)
        elseif n == "MatchEnded" then
            watched[r] = true
            r.OnClientEvent:Connect(function(data)
                if not alive then return end
                Match.endedAt = os.clock()
                Match.count = Match.count + 1
                data = type(data) == "table" and data or {}
                Session.matches = (Session.matches or 0) + 1
                if data.won then Session.wins = (Session.wins or 0) + 1 else Session.losses = (Session.losses or 0) + 1 end
                data._coinPotion = (tonumber(attr("BoostCoinsEnd")) or 0) > os.time()
                data._gain = (tonumber(data.coins) or 0) * (data._coinPotion and 2 or 1)
                Session.coinsEarned = (Session.coinsEarned or 0) + data._gain
                if data.won and tonumber(data.wave) and Match.map then
                    MapWaves[Match.map] = math.max(tonumber(MapWaves[Match.map]) or 0, tonumber(data.wave))
                    local enc = jsonEncode(MapWaves)
                    if enc then safeWrite(WAVES_FILE, enc) end
                end
                pcall(saveSession)
                MatchEndedEv:Fire(data)
            end)
        end
    end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do pcall(watch, d) end
    ReplicatedStorage.DescendantAdded:Connect(function(d) pcall(watch, d) end)
end

-- remote keluar: hook yang hanya mencatat lalu meneruskan panggilan apa adanya
local OutHandlers = {}
do
    local function handleOut(self, method, args, results)
        if not alive then return end
        local okN, name = pcall(function() return self.Name end)
        if not okN then return end
        if name == "StartMatch" then Match.started = os.clock() end
        for _, h in ipairs(OutHandlers) do pcall(h, name, method, args, results) end
    end
    local inNamecall = setmetatable({}, { __mode = "k" })
    local function passThrough(old, self, method, ...)
        if method == "InvokeServer" then
            local args = table.pack(...)
            local results = table.pack(old(self, ...))
            task.spawn(handleOut, self, method, args, results)
            return table.unpack(results, 1, results.n)
        end
        task.spawn(handleOut, self, method, table.pack(...), nil)
        return old(self, ...)
    end
    local function finishNamecall(co, ...)
        inNamecall[co] = nil
        return ...
    end
    local wrap = newcclosure or function(f) return f end
    if hookmetamethod and getnamecallmethod then
        pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                if alive and not (checkcaller and checkcaller()) then
                    local method = getnamecallmethod()
                    if (method == "InvokeServer" or method == "FireServer") and typeof(self) == "Instance" then
                        local co = coroutine.running()
                        inNamecall[co] = true
                        return finishNamecall(co, passThrough(old, self, method, ...))
                    end
                end
                return old(self, ...)
            end))
        end)
    end
    if hookfunction then
        for _, cls in ipairs({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" }) do
            local okI, inst = pcall(function() return Instance.new(cls) end)
            if okI and inst then
                for _, method in ipairs({ "FireServer", "InvokeServer" }) do
                    pcall(function()
                        local old
                        old = hookfunction(inst[method], wrap(function(self, ...)
                            if alive and not inNamecall[coroutine.running()] and not (checkcaller and checkcaller())
                                and typeof(self) == "Instance" then
                                return passThrough(old, self, method, ...)
                            end
                            return old(self, ...)
                        end))
                    end)
                end
            end
        end
    end
end

-- request HTTP
local function postJson(url, body)
    if not REQ then return false end
    local enc = jsonEncode(body)
    if not enc then return false end
    local ok, res = pcall(REQ, { Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = enc })
    local code = ok and type(res) == "table" and tonumber(res.StatusCode or res.status_code) or nil
    return code ~= nil and code >= 200 and code < 300, code
end

-- =====================================================================
-- LOBBY: Auto Join, Auto Friends Only, Auto Summon, Auto Claim
-- =====================================================================
local inMine -- diisi di bagian MINE
local mineBusy = function() return false end -- true saat di Mine / Auto Mine sedang mengejar Mine
local MAP_PAD = { ["Castle Town"] = 1, ["Sunny Meadow"] = 4, ["Pirate Cove"] = 7, ["Snowy Summit"] = 10, ["Volcano Fortress"] = 13 }
local MAP_LIST = { "Castle Town", "Sunny Meadow", "Pirate Cove", "Snowy Summit", "Volcano Fortress", "Turkey (event)" }
local TURKEY_DIFF = { "Easy", "Normal", "Hard", "Nightmare" } -- PlayPadTurkey1..4
local LobbyStatus = { summon = "Status: mati", lastSummon = nil }
local padCache = nil
local function allPads()
    if not padCache or #padCache == 0 then
        padCache = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d.Name:match("^PlayPad%d+$") or d.Name:match("^PlayPadTurkey%d+$") then padCache[#padCache + 1] = d end
        end
    end
    return padCache
end
local function padByName(name)
    for _, p in ipairs(allPads()) do
        if p.Name == name and p.Parent then return p end
    end
    padCache = nil
    return nil
end
-- pad tempat karakter berdiri (dalam 8 stud), atau nil
local function standingPad()
    local _, _, hrp = charParts()
    if not hrp then return nil end
    local best, bestD
    for _, pad in ipairs(allPads()) do
        local pos = pivotOf(pad)
        if pos then
            local d = flatDist(pos, hrp.Position)
            if not bestD or d < bestD then best, bestD = pad, d end
        end
    end
    if best and bestD < 8 then return best.Name end
    return nil
end
-- panel pad: "ON" / "OFF" dari tombol Friends Only, atau nil kalau panel tidak tampil
local function friendsState()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and plainText(d.Text):lower():find("friends only", 1, true) and guiShown(d) then
            local own = plainText(d.Text):upper()
            if own:find("%f[%w]OFF%f[%W]") then return "OFF" end
            if own:find("%f[%w]ON%f[%W]") then return "ON" end
            for _, box in ipairs({ d.Parent, d.Parent and d.Parent.Parent }) do
                if box then
                    for _, e in ipairs(box:GetDescendants()) do
                        if e:IsA("TextLabel") or e:IsA("TextButton") then
                            local t = plainText(e.Text):upper()
                            if t == "ON" or t == "OFF" then return t end
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Auto Join: berjalan ke pad map yang dipilih (berdiri di pad = masuk antrean)
task.spawn(function()
    task.wait(5) -- beri waktu Auto Claim jalan dulu
    local since, lastDist = nil, nil
    local lastHall = 0
    while alive do
        task.wait(1)
        if Cfg.autoJoin and isLobby() and not mineBusy() then
            pcall(function()
                local name
                if Cfg.map == "Turkey (event)" then
                    name = "PlayPadTurkey" .. tostring(math.clamp(tonumber(Cfg.turkeyPad) or 4, 1, 4))
                else
                    name = "PlayPad" .. tostring((MAP_PAD[Cfg.map] or 1) + (math.clamp(tonumber(Cfg.pad) or 1, 1, 3) - 1))
                end
                local pad = padByName(name)
                -- pad event Turkey ada di dalam Turkey Hall: masuk dulu lewat TurkeyHall("enter")
                if Cfg.map == "Turkey (event)" and os.clock() - lastHall > 20 then
                    local _, _, hrp0 = charParts()
                    local p0 = pad and pivotOf(pad)
                    if not p0 or (hrp0 and flatDist(p0, hrp0.Position) > 150) then
                        lastHall = os.clock()
                        callRemote("TurkeyHall", "enter")
                        padCache = nil
                        task.wait(2)
                        pad = padByName(name)
                    end
                end
                local _, hum, hrp = charParts()
                if not (pad and hum and hrp) then return end
                local pos = pivotOf(pad)
                if not pos then return end
                local d = flatDist(pos, hrp.Position)
                if d <= 4 then since, lastDist = nil, nil return end
                if not since or (lastDist and d < lastDist - 1) then since = os.clock() end
                lastDist = d
                hum:MoveTo(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
                -- macet lebih dari 15 detik: pindah langsung ke atas pad
                if os.clock() - since > 15 then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
                    since = nil
                end
            end)
        end
    end
end)

-- Auto Friends Only: Friends Only selalu OFF saat baru masuk pad; diklik sekali = ON
task.spawn(function()
    local lastFire, tries, lastPad, padSince = 0, 0, nil, 0
    while alive do
        task.wait(0.15)
        if Cfg.autoFriends and isLobby() and not mineBusy() then
            pcall(function()
                local pad = standingPad()
                if not pad then tries, lastPad = 0, nil return end
                if pad ~= lastPad then tries, lastPad, padSince = 0, pad, os.clock() end
                if tries >= 3 then return end
                local state = friendsState()
                if state == "ON" then tries = 3 return end
                if state == nil then
                    if tries >= 1 or os.clock() - padSince < 1.5 then return end
                elseif os.clock() - lastFire < 2 then
                    return
                end
                lastFire, tries = os.clock(), tries + 1
                callRemote("PadFriends", pad)
            end)
        end
    end
end)

-- Auto Summon
task.spawn(function()
    while alive do
        task.wait(math.max(tonumber(Cfg.summonDelay) or 1, 1))
        if Cfg.autoSummon and isLobby() then
            local n = tonumber(Cfg.summonAmount) == 1 and 1 or 10
            local ok, res, msg, list = callRemote("Summon", n)
            if ok and res == true then
                local got = type(list) == "table" and #list or n
                Session.summonCount = (Session.summonCount or 0) + got
                for _, name in ipairs(type(list) == "table" and list or {}) do
                    Session.summons[tostring(name)] = (Session.summons[tostring(name)] or 0) + 1
                end
                LobbyStatus.lastSummon = type(list) == "table" and table.concat(list, ", ") or nil
                LobbyStatus.summon = string.format("Status: summon %dx · total sesi %s", n, comma(Session.summonCount))
            else
                local why = tostring(ok and (msg or res) or res)
                if why:lower():find("hatch", 1, true) or why:lower():find("wait", 1, true) then
                    -- animasi telur menetas belum selesai: coba lagi sebentar lagi, bukan gagal
                    LobbyStatus.summon = "Status: menunggu telur menetas..."
                else
                    LobbyStatus.summon = "Status: gagal · " .. why
                    task.wait(10)
                end
            end
        elseif not Cfg.autoSummon then
            LobbyStatus.summon = "Status: mati"
        end
    end
end)

-- Auto Drink Potion: diminum saat efeknya habis dan stok masih ada.
-- Coins & Speed hanya diminum saat match berjalan (efeknya untuk match), Luck kapan saja (untuk summon).
local POTIONS = {
    { key = "coins", cfg = "potionCoins", stock = "PotionCoins", ends = "BoostCoinsEnd", matchOnly = true },
    { key = "luck", cfg = "potionLuck", stock = "PotionLuck", ends = "BoostLuckEnd", matchOnly = false },
    { key = "speed", cfg = "potionSpeed", stock = "PotionSpeed", ends = "BoostSpeedEnd", matchOnly = true },
}
task.spawn(function()
    local lastTry = {}
    while alive do
        task.wait(3)
        for _, p in ipairs(POTIONS) do
            if Cfg[p.cfg] and (not p.matchOnly or (inMatch() and matchRunning())) then
                pcall(function()
                    local active = (tonumber(attr(p.ends)) or 0) > os.time() + 5
                    local stock = tonumber(attr(p.stock)) or 0
                    if active or stock <= 0 or os.clock() - (lastTry[p.key] or -99) < 30 then return end
                    lastTry[p.key] = os.clock()
                    local ok, res, msg = callRemote("Potion", "drink", p.key)
                    if ok and res == true then notify("Potion: " .. tostring(msg or p.key)) end
                end)
            end
        end
    end
end)

-- Auto Claim: quest, bonus quest, playtime, index, battle pass (dibaca dari atribut akun)
local ClaimLog = {}
local function claimNote(text)
    Session.claimed = (Session.claimed or 0) + 1
    ClaimLog[#ClaimLog + 1] = text
    if #ClaimLog > 20 then table.remove(ClaimLog, 1) end
    notify("Klaim: " .. text)
end
task.spawn(function()
    local tried, bonusTried = {}, {}
    local playtimeNext = 0
    task.wait(2)
    while alive do
        if Cfg.claimQuest or Cfg.claimBonus then
            pcall(function()
                local q = jattr("Quests") or {}
                for _, kind in ipairs({ "daily", "weekly" }) do
                    local box = type(q[kind]) == "table" and q[kind] or {}
                    local list = type(box.list) == "table" and box.list or {}
                    local allClaimed = #list > 0
                    for i, it in ipairs(list) do
                        if not it.claimed then
                            allClaimed = false
                            local tgt = QUEST_TARGET[it.id]
                            local key = kind .. ":" .. tostring(box.period) .. ":" .. i
                            local ready = tgt and (tonumber(it.n) or 0) >= tgt
                            local unknownTry = not tgt and (not tried[key] or os.clock() - tried[key] > 300)
                            if Cfg.claimQuest and (ready or unknownTry) and (not tried[key] or os.clock() - tried[key] > 20) then
                                tried[key] = os.clock()
                                local ok, res, msg = callRemote("ClaimQuest", kind, i)
                                if ok and res == true then claimNote((QUEST_NAME[it.id] or it.id) .. " " .. tostring(msg or "")) end
                                task.wait(0.5)
                            end
                        end
                    end
                    local bkey = kind .. ":" .. tostring(box.period)
                    if Cfg.claimBonus and allClaimed and not bonusTried[bkey] then
                        bonusTried[bkey] = true
                        local ok, res, msg = callRemote("ClaimQuestBonus", kind)
                        if ok and res == true then claimNote("Bonus " .. kind .. " " .. tostring(msg or "")) end
                        task.wait(0.5)
                    end
                end
            end)
        end
        if Cfg.claimPlaytime and os.clock() >= playtimeNext then
            pcall(function()
                local claimed, top = {}, 0
                for n in tostring(attr("PlaytimeClaimed") or ""):gmatch("%d+") do
                    claimed[tonumber(n)] = true
                    top = math.max(top, tonumber(n))
                end
                local got = false
                for i = 1, top + 1 do
                    if not claimed[i] then
                        local ok, res, msg = callRemote("ClaimPlaytime", i)
                        if ok and res == true then
                            claimNote("Playtime " .. tostring(msg or i))
                            got = true
                        end
                        break
                    end
                end
                playtimeNext = os.clock() + (got and 5 or 60)
            end)
        end
        if Cfg.claimIndex then
            pcall(function()
                local idx = jattr("Index") or {}
                local need = false
                for _, v in pairs(idx) do if v ~= "claimed" then need = true break end end
                if need then
                    local ok, res, msg = callRemote("ClaimIndexAll")
                    if ok and res == true then claimNote("Index " .. tostring(msg or "")) end
                end
            end)
        end
        if Cfg.claimBP then
            pcall(function()
                local bp = bpInfo()
                if bp.tier > bp.free or (bp.paid and bp.tier > bp.pass) then
                    local ok, res, list = callRemote("Battlepass", "claimAll")
                    if ok and res == true then
                        claimNote("Battle Pass " .. (type(list) == "table" and table.concat(list, ", ") or ""))
                    end
                end
            end)
        end
        task.wait(15)
    end
end)

-- =====================================================================
-- MINE (minigame)
-- Blok = MineDig(id), id = (lapisan - 1) x 100 + baris x 10 + kolom (lapisan 10 x 10).
-- Server membalas MineMsg("dug", id, ok, { {idItem, jenis}, ... }, _, ringkasan, _); ok = false = belum pecah.
-- Auto Mine terjadwal: saat Mine buka -> keluar dari match ke lobby -> MineJoin -> gali.
-- Mine selesai -> server memindahkan ke lobby -> Auto Join map / Play Macro jalan lagi seperti biasa.
-- =====================================================================
local Mine = {
    dug = {}, items = {}, failed = {}, hits = {}, closeNeeded = {}, pending = nil, rejected = nil, finds = nil,
    status = "Mati", lastItems = {}, news = nil, raw = {}, fails = 0, schedule = "-",
}
local mineFlag, mineCheck = false, 0
-- di dalam Mine: panel "Your Finds" / "Blocks dug" tampil di layar, atau lubang MyMinePit ada
function inMine()
    if os.clock() - mineCheck < 3 then return mineFlag end
    mineCheck = os.clock()
    mineFlag = workspace:FindFirstChild("MyMinePit") ~= nil
    if not mineFlag then
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        for _, d in ipairs(pg and pg:GetDescendants() or {}) do
            if d:IsA("TextLabel") and guiShown(d) then
                local t = plainText(d.Text)
                if t == "Your Finds" or t:find("^Blocks dug") then mineFlag = true break end
            end
        end
    end
    return mineFlag
end
local function mineNeighbors(id)
    local d, r, c = math.floor(id / 100), math.floor(id % 100 / 10), id % 10
    local out = {}
    if c > 0 then out[#out + 1] = id - 1 end
    if c < 9 then out[#out + 1] = id + 1 end
    if r > 0 then out[#out + 1] = id - 10 end
    if r < 9 then out[#out + 1] = id + 10 end
    if d > 0 then out[#out + 1] = id - 100 end
    out[#out + 1] = id + 100
    return out
end
local function mineBlocks()
    local pit = workspace:FindFirstChild("MyMinePit")
    return pit and pit:FindFirstChild("Blocks")
end
-- blok asli: yang hilang = sudah digali, yang berisi model (Chest / Egg / ...) = item terlihat
local function mineSync()
    local f = mineBlocks()
    if not f then return false end
    local present, maxId = {}, -1
    for _, b in ipairs(f:GetChildren()) do
        local id = tonumber(b:GetAttribute("Idx")) or tonumber(tostring(b.Name):match("^B(%d+)$"))
        if id then
            present[id] = true
            if id > maxId then maxId = id end
            for _, c in ipairs(b:GetChildren()) do
                if c:IsA("Model") or c:IsA("Folder") or c:IsA("BasePart") or c:IsA("Tool") then Mine.items[id] = c.Name break end
            end
        end
    end
    if maxId < 0 then return false end
    for id = 0, math.floor(maxId / 100) * 100 + 99 do
        if present[id] then
            Mine.dug[id] = nil
        else
            Mine.dug[id] = true
            Mine.items[id] = nil
        end
    end
    return true
end
local function mineState()
    local ms = ReplicatedStorage:FindFirstChild("MineState")
    if not ms then return nil end
    local ok, a = pcall(ms.GetAttributes, ms)
    return ok and a or nil
end
-- modul game Shared.Mine: jadwal buka (opening) dan waktu gali (digSeconds)
local MineMod = nil
task.spawn(function()
    pcall(function() MineMod = require(ReplicatedStorage:WaitForChild("Shared", 15):WaitForChild("Mine", 15)) end)
end)
-- jadwal: mulai, selesai, sedang buka?
local function mineSchedule()
    local now = os.time()
    if MineMod and MineMod.opening then
        local ok, st, en, open = pcall(MineMod.opening, now)
        if ok and tonumber(st) and tonumber(en) then return tonumber(st), tonumber(en), open == true end
    end
    local ms = mineState()
    if ms and tonumber(ms.EndsAt) then
        return tonumber(ms.Start) or now, tonumber(ms.EndsAt), ms.Phase == "Open" and tonumber(ms.EndsAt) > now
    end
    return nil
end
local digTimeCache, digTimeAt = nil, 0
local function mineDigTime()
    if digTimeCache and os.clock() - digTimeAt < 10 then return digTimeCache end
    local bonus = 0
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    for _, d in ipairs(pg and pg:GetDescendants() or {}) do
        if d:IsA("TextLabel") then
            local pct = plainText(d.Text):match("[Dd]ig speed%s*%+?(%-?%d+)%%")
            if pct then bonus = tonumber(pct) / 100 break end
        end
    end
    local t = nil
    if MineMod and MineMod.digSeconds then
        local ok, v = pcall(MineMod.digSeconds, bonus)
        if ok and tonumber(v) then t = tonumber(v) end
    end
    digTimeCache, digTimeAt = t or 1.2, os.clock()
    return digTimeCache
end
-- Data Mine: setiap blok yang isinya sudah terlihat dan setiap item dicatat per lapisan, untuk dianalisis
-- (lapisan mana yang paling sering berisi item, berapa peluang item per blok).
-- File: ArdHub/DragonTD/mine_data.json (gabungan semua sesi) dan mine_items.csv (daftar item satu per baris).
local MINE_DATA_FILE = SAVE_DIR .. "/mine_data.json"
local MINE_CSV_FILE = SAVE_DIR .. "/mine_items.csv"
local MineData = jsonDecode(safeRead(MINE_DATA_FILE))
if type(MineData) ~= "table" then MineData = {} end
MineData.sessions = tonumber(MineData.sessions) or 0
MineData.layers = type(MineData.layers) == "table" and MineData.layers or {}
MineData.kinds = type(MineData.kinds) == "table" and MineData.kinds or {}
MineData.seen = tonumber(MineData.seen) or 0
MineData.items = tonumber(MineData.items) or 0
MineData.digs = tonumber(MineData.digs) or 0
local mineKnown, mineCounted = {}, {}
local mineDataDirty, mineSessionOn = false, false
local function layerRow(L)
    local key = tostring(L)
    local row = MineData.layers[key]
    if type(row) ~= "table" then row = { seen = 0, items = 0, kinds = {} } MineData.layers[key] = row end
    row.kinds = type(row.kinds) == "table" and row.kinds or {}
    return row
end
local function markKnown(id)
    if mineKnown[id] then return end
    mineKnown[id] = true
    local row = layerRow(math.floor(id / 100) + 1)
    row.seen = (tonumber(row.seen) or 0) + 1
    MineData.seen = MineData.seen + 1
    mineDataDirty = true
end
local function markItem(id, kind)
    if mineCounted[id] then return end
    mineCounted[id] = true
    local L = math.floor(id / 100) + 1
    local row = layerRow(L)
    row.items = (tonumber(row.items) or 0) + 1
    row.kinds[kind] = (tonumber(row.kinds[kind]) or 0) + 1
    MineData.items = MineData.items + 1
    MineData.kinds[kind] = (tonumber(MineData.kinds[kind]) or 0) + 1
    mineDataDirty = true
    local line = string.format("%s,%d,%d,%s,%s\n", os.date("%Y-%m-%d %H:%M:%S"), L, id, kind, tostring(Cfg.minePattern))
    pcall(function()
        safeMakeDir(SAVE_DIR)
        if appendfile and isfile and isfile(MINE_CSV_FILE) then appendfile(MINE_CSV_FILE, line)
        else safeWrite(MINE_CSV_FILE, "waktu,lapisan,blok,jenis,pola\n" .. line) end
    end)
end
local function saveMineData()
    if not mineDataDirty then return end
    mineDataDirty = false
    safeMakeDir(SAVE_DIR)
    local enc = jsonEncode(MineData)
    if enc then safeWrite(MINE_DATA_FILE, enc) end
end
task.spawn(function()
    while alive do
        task.wait(20)
        if inMine and inMine() and not mineSessionOn then
            mineSessionOn = true
            MineData.sessions = MineData.sessions + 1
            mineDataDirty = true
        end
        pcall(saveMineData)
    end
end)
-- ringkasan untuk UI: peluang item per blok, dan kelompok 5 lapisan dengan peluang tertinggi
local function mineDataSummary()
    local per = MineData.items > 0 and (MineData.seen / MineData.items) or nil
    local groups = {}
    for key, row in pairs(MineData.layers) do
        local g = math.floor(((tonumber(key) or 1) - 1) / 5)
        groups[g] = groups[g] or { seen = 0, items = 0 }
        groups[g].seen = groups[g].seen + (tonumber(row.seen) or 0)
        groups[g].items = groups[g].items + (tonumber(row.items) or 0)
    end
    local best, bestRate = nil, -1
    for g, v in pairs(groups) do
        if v.seen >= 50 then
            local rate = v.items / v.seen
            if rate > bestRate then best, bestRate = g, rate end
        end
    end
    local kinds = {}
    for k, n in pairs(MineData.kinds) do kinds[#kinds + 1] = k .. " " .. n end
    table.sort(kinds)
    return string.format("Data %d sesi: %s blok terlihat · %s item%s\nJenis: %s%s", MineData.sessions, comma(MineData.seen),
        comma(MineData.items), per and string.format(" (1 per %.0f blok)", per) or "",
        #kinds > 0 and table.concat(kinds, ", ") or "-",
        best and string.format("\nLapisan terbaik sejauh ini: %d-%d (1 per %.0f blok)", best * 5 + 1, best * 5 + 5, 1 / math.max(bestRate, 1e-9)) or "")
end
Mine.dataSummary = mineDataSummary

local LORONG = {} -- [sel 0..99] = urutan di jalur lorong (diisi di bawah)
Mine.entryIdx, Mine.chestDone, Mine.lastPath, Mine.curLayer = {}, {}, nil, nil
-- remote masuk MineMsg
do
    local function onMsg(kind, ...)
        if not alive then return end
        local a = table.pack(...)
        Mine.raw[#Mine.raw + 1] = tostring(kind) .. " " .. tostring(a[1]) .. " " .. tostring(a[2])
        if #Mine.raw > 5 then table.remove(Mine.raw, 1) end
        if kind == "dug" then
            local id, ok, items, summary = tonumber(a[1]), a[2], a[3], a[5]
            if id and ok then
                local L = math.floor(id / 100)
                -- Lorong Cepat: chest di lapisan ini sudah diambil -> lapisan dianggap selesai
                if Mine.items[id] and tostring(Mine.items[id]):lower():find("chest", 1, true) then Mine.chestDone[L] = true end
                Mine.dug[id] = true
                Mine.items[id] = nil
                Mine.hits[id] = nil
                -- blok ini dan semua tetangganya sekarang sudah diketahui isinya
                MineData.digs = MineData.digs + 1
                markKnown(id)
                for _, n in ipairs(mineNeighbors(id)) do markKnown(n) end
            elseif id then
                -- belum pecah (chest / egg / blok keras butuh beberapa pukulan): pukul lagi blok yang sama
                Mine.hits[id] = (Mine.hits[id] or 0) + 1
                if Mine.pending == id then Mine.rejected = id end

            end
            for _, it in ipairs(type(items) == "table" and items or {}) do
                if type(it) == "table" and tonumber(it[1]) and not Mine.dug[tonumber(it[1])] then
                    Mine.items[tonumber(it[1])] = tostring(it[2])
                    markItem(tonumber(it[1]), tostring(it[2]))
                    Mine.lastItems[#Mine.lastItems + 1] = tostring(it[2])
                    if #Mine.lastItems > 6 then table.remove(Mine.lastItems, 1) end
                end
            end
            if type(summary) == "table" then Mine.finds = summary end
            if id and Mine.pending == id then Mine.pending = nil end
        elseif kind == "news" then
            Mine.news = plainText(a[1])
        end
    end
    local function hook(r)
        if r.Name == "MineMsg" and r:IsA("RemoteEvent") then r.OnClientEvent:Connect(onMsg) return true end
        return false
    end
    local found = false
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do if hook(d) then found = true end end
    if not found then
        local c
        c = ReplicatedStorage.DescendantAdded:Connect(function(d) if hook(d) and c then c:Disconnect() end end)
    end
end
-- urutan zig-zag: baris berganti arah, lapisan berikutnya mulai tepat di bawah blok terakhir
local function zigKey(id)
    local L, r, c = math.floor(id / 100), math.floor(id % 100 / 10), id % 10
    local er = (L % 2 == 0) and r or (9 - r)
    local ec = (er % 2 == 0) and c or (9 - c)
    return L * 100 + er * 10 + ec
end
-- Pola Lorong: di setiap lapisan hanya digali jalur ular baris 0, 3, 6, 9 + penghubung di ujungnya
-- (46 blok per lapisan, sisanya tetap terlihat dari samping). Lapisan berikutnya mulai tepat di bawah ujung terakhir.
do
    local path = {}
    local function row(r, rev) for i = 0, 9 do path[#path + 1] = r * 10 + (rev and (9 - i) or i) end end
    row(0, false); path[#path + 1] = 19; path[#path + 1] = 29
    row(3, true); path[#path + 1] = 40; path[#path + 1] = 50
    row(6, false); path[#path + 1] = 79; path[#path + 1] = 89
    row(9, true)
    for i, cell in ipairs(path) do
        LORONG[cell] = i -- urutan di lapisan genap; lapisan ganjil dibalik
    end
end
local function lorongKey(id)
    local L, cell = math.floor(id / 100), id % 100
    local i = LORONG[cell]
    if not i then return nil end
    if L % 2 == 1 then i = 47 - i end
    return L * 100 + i
end
-- item terlihat (terdekat) dulu, lalu blok berikutnya sesuai pola (Lorong / Zig-zag)
local function minePick()
    local f = mineBlocks()
    if not f then return nil end
    local list = {}
    for _, b in ipairs(f:GetChildren()) do
        local id = tonumber(b:GetAttribute("Idx")) or tonumber(tostring(b.Name):match("^B(%d+)$"))
        if id and not Mine.dug[id] and (not Mine.failed[id] or os.clock() - Mine.failed[id] > 120) then list[#list + 1] = id end
    end
    local _, _, hrp = charParts()
    local bestItem, bestD = nil, nil
    for _, id in ipairs(list) do
        if Mine.items[id] then
            local part = f:FindFirstChild("B" .. id)
            local d = (hrp and part and part:IsA("BasePart")) and (hrp.Position - part.Position).Magnitude or 0
            if not bestD or d < bestD then bestItem, bestD = id, d end
        end
    end
    if bestItem then return bestItem, "ambil " .. Mine.items[bestItem] end
    if Cfg.minePattern == "Lorong Cepat" then
        -- jalur lorong yang sama, tapi tiap lapisan berhenti begitu chest-nya sudah diambil (paling banyak 1 chest
        -- per lapisan), lalu turun tepat di bawah posisi terakhir. Lapisan 1 (belum pernah ada chest) langsung ditembus.
        local present = {}
        for _, id in ipairs(list) do present[id] = true end
        -- lapisan yang sedang dikerjakan (dicatat oleh loop gali); kalau script baru jalan, tebak dari blok yang sudah digali
        local L = Mine.curLayer
        if L == nil then
            L = -1
            for id in pairs(Mine.dug) do
                if LORONG[id % 100] and math.floor(id / 100) > L then L = math.floor(id / 100) end
            end
        end
        if L < 0 then
            if present[0] then return 0, "mulai" end
        else
            if L > 0 and not Mine.chestDone[L] then
                local e = Mine.entryIdx[L] or 1
                local best, bestR = nil, nil
                for _, id in ipairs(list) do
                    local i = (math.floor(id / 100) == L) and LORONG[id % 100] or nil
                    if i then
                        local r = (i >= e) and (i - e) or (100 + e - i) -- maju dari titik masuk, lalu sisi sebaliknya
                        if not bestR or r < bestR then best, bestR = id, r end
                    end
                end
                if best then return best, "lorong cepat" end
            end
            local from = (Mine.lastPath and math.floor(Mine.lastPath / 100) == L) and Mine.lastPath or nil
            if not from then
                for id in pairs(Mine.dug) do
                    if LORONG[id % 100] and math.floor(id / 100) == L then from = id break end
                end
            end
            if from then
                local t = from + 100
                while Mine.dug[t] do t = t + 100 end
                if present[t] then return t, Mine.chestDone[L] and "turun (chest sudah)" or "turun" end
            end
        end
    end
    if Cfg.minePattern == "Lorong" or Cfg.minePattern == "Lorong Cepat" then
        local best, bestK = nil, nil
        for _, id in ipairs(list) do
            local k = lorongKey(id)
            if k and (not bestK or k < bestK) then best, bestK = id, k end
        end
        if best then return best, "lorong" end
    end
    table.sort(list, function(a, b) return zigKey(a) < zigKey(b) end)
    if not list[1] then return nil end
    return list[1], "urut"
end
-- karakter berjalan ke ruang kosong di sebelah blok (utamakan di atasnya) sampai dalam jangkauan gali
local function mineWalkTo(id)
    local f = mineBlocks()
    local part = f and f:FindFirstChild("B" .. id)
    local _, hum, hrp = charParts()
    if not (part and hum and hrp and part:IsA("BasePart")) then return false end
    local reach = Mine.closeNeeded[id] and 5.5 or 8
    local off = nil
    for _, n in ipairs(mineNeighbors(id)) do
        if Mine.dug[n] then
            local diff = n - id
            local o = (diff == 1 and Vector3.new(0, 0, 5)) or (diff == -1 and Vector3.new(0, 0, -5))
                or (diff == 10 and Vector3.new(5, 0, 0)) or (diff == -10 and Vector3.new(-5, 0, 0))
                or (diff == -100 and Vector3.new(0, 5, 0)) or nil
            if o and (not off or o.Y > off.Y) then off = o end
        end
    end
    local goal = part.Position + (off or Vector3.new(0, 5, 0))
    local t0, bestD, lastGain = os.clock(), math.huge, os.clock()
    while alive and Cfg.autoDig do
        local d = (hrp.Position - part.Position).Magnitude
        if d <= reach then hum:MoveTo(hrp.Position) return true end
        if d < bestD - 0.5 then bestD, lastGain = d, os.clock()
        elseif os.clock() - lastGain > 1.2 then hum.Jump = true lastGain = os.clock() end
        hum:MoveTo(goal)
        if os.clock() - t0 > 20 then return false end
        task.wait(0.15)
    end
    return false
end
local function fmtWait(sec)
    sec = math.max(math.floor(sec), 0)
    local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
    return h > 0 and string.format("%dj %dm", h, m) or string.format("%dm %ds", m, sec % 60)
end

-- Auto Mine terjadwal: tunggu Mine buka -> keluar dari match -> MineJoin di lobby -> Auto Dig di dalam Mine
local MINE_MIN_LEFT = 5 * 60 -- kalau Mine tutup kurang dari 5 menit lagi, tidak dikejar
local function mineWanted()
    if not Cfg.autoMine then return false end
    local _, en, open = mineSchedule()
    return open == true and en ~= nil and en - os.time() > MINE_MIN_LEFT
end
Mine.wanted = mineWanted
mineBusy = function() return inMine() or mineWanted() end
task.spawn(function()
    local lastLeave, lastJoin = 0, 0
    while alive do
        task.wait(1)
        pcall(function()
            local st, en, open = mineSchedule()
            if st then
                Mine.schedule = open and ("Buka · tutup dalam " .. fmtWait(en - os.time()))
                    or ("Tutup · buka " .. os.date("%H:%M", st) .. " (dalam " .. fmtWait(st - os.time()) .. ")")
            else
                Mine.schedule = "Jadwal belum terbaca"
            end
            if not Cfg.autoMine then return end
            if inMine() then
                Cfg.autoDig = true -- di dalam Mine: langsung gali
                return
            end
            if not mineWanted() then
                if Cfg.autoMine then Mine.status = "Menunggu Mine buka · " .. Mine.schedule end
                return
            end
            if inMatch() and os.clock() - lastLeave > 15 and os.clock() - Match.scriptStart > 15 then
                -- keluar dari match ke lobby (tombol Lobby; kalau tidak diterima, teleport ke lobby)
                lastLeave = os.clock()
                Mine.status = "Mine buka: keluar ke lobby"
                if Mine.queueExec then pcall(Mine.queueExec) end
                callRemote("ReturnToLobby")
                task.delay(8, function()
                    if alive and inMatch() and mineWanted() then
                        pcall(function() game:GetService("TeleportService"):Teleport(LOBBY_PLACE, LocalPlayer) end)
                    end
                end)
            elseif isLobby() and os.clock() - lastJoin > 15 then
                lastJoin = os.clock()
                if Mine.queueExec then pcall(Mine.queueExec) end
                local ok, res, msg = callRemote("MineJoin")
                Mine.status = "Masuk Mine: " .. tostring(ok and (msg or res) or res)
            end
        end)
    end
end)
-- Auto Dig
task.spawn(function()
    while alive do
        task.wait(0.1)
        if Cfg.autoDig and inMine() then
            pcall(function()
                if not mineSync() then Mine.status = "Blok Mine belum ada" task.wait(1) return end
                local id, why = minePick()
                if not id then Mine.status = "Tidak ada blok yang bisa digali" task.wait(1) return end
                Mine.status = string.format("Jalan ke blok %d", id)
                if not mineWalkTo(id) then
                    Mine.failed[id] = os.clock()
                    Mine.status = string.format("Blok %d tidak terjangkau, dilewati 2 menit", id)
                    return
                end
                -- seperti menahan klik: tunggu waktu gali penuh (+ jeda tambahan) sebelum blok dikirim
                task.wait(mineDigTime() + 0.15 + (tonumber(Cfg.mineDelay) or 0))
                if not Cfg.autoDig then return end
                Mine.pending, Mine.rejected = id, nil
                callRemote("MineDig", id)
                local t0 = os.clock()
                while alive and Mine.pending == id and os.clock() - t0 < 3 do task.wait(0.1) end
                if Mine.pending == id then
                    Mine.pending = nil
                    if not Mine.closeNeeded[id] then
                        Mine.closeNeeded[id] = true -- mungkin kurang dekat: coba sekali lagi dari jarak dekat
                        Mine.status = string.format("Blok %d tidak dibalas, coba lebih dekat", id)
                        return
                    end
                    Mine.failed[id] = os.clock()
                    Mine.fails = Mine.fails + 1
                    Mine.status = string.format("Blok %d tidak dibalas (%dx)", id, Mine.fails)
                    if Mine.fails >= 5 then task.wait(5) Mine.fails = 0 end
                elseif Mine.rejected == id then
                    -- dibalas "false": bisa berarti belum pecah, bisa juga posisi kurang pas.
                    -- Setelah 2x: maju sampai tepat di sebelah blok. Batas: item 12x, blok biasa 4x, lalu dilewati 2 menit.
                    local n = Mine.hits[id] or 0
                    local _, _, hrp = charParts()
                    local part = mineBlocks() and mineBlocks():FindFirstChild("B" .. id)
                    local dist = (hrp and part and part:IsA("BasePart")) and (hrp.Position - part.Position).Magnitude or -1
                    if n >= 2 then Mine.closeNeeded[id] = true end
                    if n >= (Mine.items[id] and 12 or 4) then
                        Mine.failed[id] = os.clock()
                        Mine.hits[id] = nil
                        Mine.status = string.format("Blok %d tetap false setelah %dx (jarak %.1f), dilewati 2 menit", id, n, dist)
                    else
                        Mine.status = string.format("Pukul %d (%s) · %dx · jarak %.1f", id, why, n, dist)
                    end
                else
                    Mine.fails = 0
                    if why == "mulai" or why == "lorong cepat" or tostring(why):find("^turun") then
                        local L = math.floor(id / 100)
                        Mine.lastPath, Mine.curLayer = id, L
                        if not Mine.entryIdx[L] then Mine.entryIdx[L] = LORONG[id % 100] end
                    end
                    Mine.status = string.format("Gali %d (%s) · lapisan %d · %.2f dtk", id, why, math.floor(id / 100) + 1, mineDigTime())
                end
            end)
        elseif Cfg.autoDig and not inMine() and not Cfg.autoMine then
            Mine.status = "Auto Dig: tidak di Mine"
        end
    end
end)

-- =====================================================================
-- MATCH: Auto Start, Auto Skip, Auto Play Again / Return, Auto Target, Auto Walk, Anti AFK
-- =====================================================================
task.spawn(function()
    local lastFire, firedFor = 0, nil
    while alive do
        task.wait(0.5)
        if Cfg.autoStart and inMatch() and not mineBusy() then
            pcall(function()
                local now_ = os.clock()
                if matchRunning() then return end
                local readyAt
                if Match.endedAt == 0 then readyAt = math.max(Match.scriptStart, Match.lastCamera)
                elseif Match.lastCamera > Match.endedAt then readyAt = Match.lastCamera end
                if not readyAt or now_ - readyAt < 3 then return end
                if firedFor == readyAt and now_ - lastFire < 8 then return end
                if gameElapsed() then Match.started = os.clock() return end -- timer sudah jalan: match sudah mulai
                lastFire, firedFor = now_, readyAt
                if callRemote("StartMatch") then Match.started = os.clock() end
            end)
        end
    end
end)
task.spawn(function()
    while alive do
        task.wait(3)
        if Cfg.autoSkip and inMatch() and attr("AutoSkip") ~= true then
            callRemote("SetAutoSkip", true)
        end
    end
end)
MatchEndedEv.Event:Connect(function()
    local endedAt = Match.endedAt
    task.delay(4, function()
        if not alive or Match.endedAt ~= endedAt or Match.lastCamera > endedAt then return end
        if mineBusy() then
            callRemote("ReturnToLobby") -- Mine sedang buka: Auto Mine yang mengambil alih
        elseif Cfg.autoReturn and Match.count >= math.max(tonumber(Cfg.returnEvery) or 1, 1) then
            callRemote("ReturnToLobby")
        elseif Cfg.autoAgain then
            callRemote("PlayAgain")
        end
    end)
end)
-- Auto Set Speed: kecepatan game dikirim sekali setiap match berjalan (dan saat pilihan diubah)
local speedSent = { match = nil, speed = nil }
task.spawn(function()
    while alive do
        task.wait(1)
        if Cfg.autoSpeed and inMatch() and matchRunning() then
            local key = Match.started or Match.scriptStart
            -- x4 hanya bisa saat Speed Potion aktif (atribut BoostSpeedEnd); tanpa potion dipakai x2
            local want = Cfg.speed
            if want == 4 and not ((tonumber(attr("BoostSpeedEnd")) or 0) > os.time()) then want = 2 end
            if speedSent.match ~= key or speedSent.speed ~= want then
                speedSent.match, speedSent.speed = key, want
                callRemote("SetSpeed", want)
            end
        end
    end
end)
-- Auto Walk: tiap 4 detik s/d interval maksimal, berjalan ke dekat salah satu naga (geseran acak sampai radius)
task.spawn(function()
    local idx = 0
    while alive do
        if Cfg.autoWalk and inMatch() then
            pcall(function()
                local _, hum = charParts()
                if not hum then return end
                local list = {}
                local folder = workspace:FindFirstChild("Dragons")
                for _, m in ipairs(folder and folder:GetChildren() or {}) do
                    local p = pivotOf(m)
                    if p then list[#list + 1] = p end
                end
                if #list == 0 then idx = 0 return end
                if math.random() < 0.35 then idx = math.random(1, #list) else idx = idx % #list + 1 end
                local ang = math.random() * 2 * math.pi
                local d = (tonumber(Cfg.walkRadius) or 6) * (0.35 + 0.65 * math.random())
                hum:MoveTo(list[idx] + Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d))
            end)
            local hi = math.max(tonumber(Cfg.walkMax) or 9, 4)
            task.wait(4 + math.random() * (hi - 4))
        else
            task.wait(1)
        end
    end
end)
-- Anti AFK
pcall(function()
    local vu = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if alive and Cfg.antiAfk then
            pcall(function()
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end
    end)
end)
-- timer terakhir yang terbaca (untuk lama match di webhook)
task.spawn(function()
    while alive do
        task.wait(2)
        if inMatch() and matchRunning() then
            local e = gameElapsed()
            if e then Match.lastTimer = e end
        end
    end
end)

-- =====================================================================
-- MACRO: Record / Play (format file sama dengan DTD Macro: ArdHub/DragonTD/<nama>.json)
-- =====================================================================
local Macro = { selected = nil, status = "Mati" }
local Rec = { on = false, actions = {}, ids = setmetatable({}, { __mode = "k" }), nextId = 0, pending = {}, placedAt = {}, startClock = nil, waitStart = false, meta = {} }
local Play = { on = false, token = 0 }
local EXTRA_PATTERNS = { "sell", "target", "ability", "skill" }

local function cleanName(s)
    return (tostring(s or ""):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
local function macroPath(name) return SAVE_DIR .. "/" .. name .. ".json" end
local function listMacros()
    local out = {}
    pcall(function()
        for _, p in ipairs(listfiles(SAVE_DIR)) do
            local n = tostring(p):match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end)
    table.sort(out)
    return out
end
local function round3(n) return math.floor(n * 1000 + 0.5) / 1000 end
local function vecText(v) return string.format("%.3f,%.3f,%.3f", v.X, v.Y, v.Z) end
local function parseVec(text)
    local x, y, z = tostring(text):match("^%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*$")
    if not x then return nil end
    return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end
-- simpan dengan urutan kolom tetap, satu aksi per blok
local function encodeMacro(actions, meta)
    local ORDER = { "ID", "Type", "Time", "Wave", "Dragon", "Position", "Model", "Method" }
    local function encStr(s)
        return '"' .. tostring(s):gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' end
            if c == "\\" then return "\\\\" end
            if c == "\n" then return "\\n" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    local function encVal(v)
        local t = type(v)
        if t == "string" then return encStr(v) end
        if t == "boolean" then return tostring(v) end
        if t == "number" then
            if v ~= v or v == math.huge or v == -math.huge then return "null" end
            if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
            return tostring(v)
        end
        return nil
    end
    local blocks = {}
    for _, a in ipairs(actions) do
        local parts, seen = {}, {}
        local function add(k)
            seen[k] = true
            local e = encVal(a[k])
            if e then parts[#parts + 1] = encStr(k) .. ": " .. e end
        end
        for _, k in ipairs(ORDER) do add(k) end
        local extra = {}
        for k in pairs(a) do if not seen[k] then extra[#extra + 1] = k end end
        table.sort(extra)
        for _, k in ipairs(extra) do add(k) end
        blocks[#blocks + 1] = "  {\n    " .. table.concat(parts, ",\n    ") .. "\n  }"
    end
    local head = {}
    for _, k in ipairs({ "map", "wave", "won", "recordedAt" }) do
        local e = encVal(meta and meta[k])
        if e then head[#head + 1] = "  " .. encStr(k) .. ": " .. e end
    end
    return "{\n" .. table.concat(head, ",\n") .. (#head > 0 and ",\n" or "") ..
        '  "actions": [\n' .. table.concat(blocks, ",\n") .. "\n  ]\n}"
end
local function saveMacro(name, actions, meta)
    name = cleanName(name)
    if name == "" then return nil end
    safeMakeDir(SAVE_DIR)
    if safeWrite(macroPath(name), encodeMacro(actions, meta)) then return name end
    return nil
end
local function loadMacro(name)
    local data = name and jsonDecode(safeRead(macroPath(name)))
    if type(data) ~= "table" then return nil end
    local list = data.actions or data
    if type(list) ~= "table" then return nil end
    table.sort(list, function(a, b) return (tonumber(a.Time) or 0) < (tonumber(b.Time) or 0) end)
    return list, data
end

-- ---------- Record ----------
local function recNow() return Rec.startClock and (os.clock() - Rec.startClock) or 0 end
local function claimModel(model)
    if Rec.ids[model] then return end
    local kind = kindOf(model)
    local pivot = pivotOf(model)
    local best, bestD
    for i, p in ipairs(Rec.pending) do
        if p.dragon == kind then
            local d = pivot and flatDist(pivot, p.pos) or 0
            if not bestD or d < bestD then best, bestD = i, d end
        end
    end
    if best and (bestD or 0) < 12 then
        local p = table.remove(Rec.pending, best)
        Rec.ids[model] = p.id
        p.action.Model = model.Name
    end
end
-- upgrade bisa mengganti model (Storm_1 -> Storm_2): model baru diberi ID naga jenis sama terdekat
local function claimReplaced(model)
    local pivot = pivotOf(model)
    if not pivot then return end
    local kind = kindOf(model)
    local best, bestD
    for id, p in pairs(Rec.placedAt) do
        if p.kind == kind then
            local d = flatDist(pivot, p.pos)
            if not bestD or d < bestD then best, bestD = id, d end
        end
    end
    if best and bestD < 6 then Rec.ids[model] = best end
end
local function idOf(model)
    if typeof(model) ~= "Instance" then return nil end
    if not Rec.ids[model] then claimModel(model) end
    if not Rec.ids[model] then claimReplaced(model) end
    return Rec.ids[model]
end
local function plainArg(v)
    local t = typeof(v)
    if t == "Instance" then
        local id = idOf(v)
        return id and ("#" .. id) or v.Name
    end
    if t == "Vector3" then return vecText(v) end
    if t == "string" or t == "number" or t == "boolean" then return v end
    return tostring(v)
end
local function isExtra(name)
    local low = tostring(name):lower()
    for _, p in ipairs(EXTRA_PATTERNS) do if low:find(p, 1, true) then return true end end
    return false
end
local function startRecording()
    table.clear(Rec.actions)
    table.clear(Rec.pending)
    table.clear(Rec.placedAt)
    Rec.ids = setmetatable({}, { __mode = "k" })
    Rec.nextId = 0
    Rec.meta = { recordedAt = os.date("%Y-%m-%d %H:%M:%S"), map = Match.map }
    local e = inMatch() and matchRunning() and gameElapsed() or nil
    if e then
        Rec.startClock, Rec.waitStart = os.clock() - e, false
    elseif Match.started and Match.started > Match.endedAt and os.clock() - Match.started < 600 then
        Rec.startClock, Rec.waitStart = Match.started, false
    else
        Rec.startClock, Rec.waitStart = os.clock(), true -- disetel ulang saat StartMatch terlihat
    end
    Rec.on = true
    Macro.status = "Merekam · 0 aksi"
end
local function stopRecording(reason)
    if not Rec.on then return end
    Rec.on = false
    if #Rec.actions == 0 then
        Macro.status = "Rekam berhenti (" .. reason .. "), belum ada aksi"
        return
    end
    local name = Macro.selected
    if not name or name == "" then name = cleanName((Rec.meta.map or "dtd") .. "_" .. os.date("%Y%m%d_%H%M%S")) end
    local saved = saveMacro(name, Rec.actions, Rec.meta)
    Macro.status = saved and string.format("Tersimpan: %s (%d aksi)", saved, #Rec.actions) or "Gagal menyimpan macro"
    notify(Macro.status)
    if saved and Macro.onSaved then pcall(Macro.onSaved, saved) end
end
OutHandlers[#OutHandlers + 1] = function(name, method, args, results)
    if name == "StartMatch" and Rec.on and Rec.waitStart and #Rec.actions == 0 then
        Rec.startClock, Rec.waitStart = os.clock(), false
    end
    if not Rec.on then return end
    if name == "PlaceDragon" then
        local dragon, pos = args[1], args[2]
        if typeof(pos) ~= "Vector3" then return end
        local res = results and results[1]
        if res == false then return end -- ditolak server (cash kurang / terlalu dekat): tidak direkam
        Rec.nextId = Rec.nextId + 1
        local a = { ID = Rec.nextId, Type = "PlaceDragon", Time = round3(recNow()), Wave = readWave(), Dragon = tostring(dragon), Position = vecText(pos) }
        Rec.actions[#Rec.actions + 1] = a
        Rec.placedAt[Rec.nextId] = { kind = tostring(dragon), pos = pos }
        if typeof(res) == "Instance" then
            Rec.ids[res] = Rec.nextId
            a.Model = res.Name
        else
            Rec.pending[#Rec.pending + 1] = { id = Rec.nextId, dragon = tostring(dragon), pos = pos, action = a }
        end
    elseif name == "UpgradeDragon" then
        if results and results[1] == false then return end
        local model = args[1]
        local id = idOf(model)
        local a = { ID = id, Type = "UpgradeDragon", Time = round3(recNow()), Wave = readWave() }
        if not id then a.Model = typeof(model) == "Instance" and model.Name or tostring(model) end
        Rec.actions[#Rec.actions + 1] = a
        local newModel = results and results[3]
        if typeof(newModel) == "Instance" and id then Rec.ids[newModel] = id end
    elseif isExtra(name) and name ~= "StatsEvent" then
        local a = { Type = name, Time = round3(recNow()), Wave = readWave(), Method = method }
        for i = 1, args.n do a["Arg" .. i] = plainArg(args[i]) end
        Rec.actions[#Rec.actions + 1] = a
    else
        return
    end
    Macro.status = string.format("Merekam · %d aksi", #Rec.actions)
end
task.spawn(function()
    local folder = inMatch() and workspace:WaitForChild("Dragons", 60)
    if not folder then return end
    folder.ChildAdded:Connect(function(m)
        task.wait(0.1)
        if alive and Rec.on then pcall(claimModel, m) end
    end)
end)
MatchEndedEv.Event:Connect(function(data)
    if Rec.on then
        Rec.meta.wave = tonumber(data.wave)
        if type(data.won) == "boolean" then Rec.meta.won = data.won end
        Rec.meta.map = Rec.meta.map or Match.map
        stopRecording("MatchEnded")
        if Macro.onRecordStop then pcall(Macro.onRecordStop) end
    end
end)

-- ---------- Play ----------
local function spreadOffset(n)
    local s = tonumber(Cfg.spread) or 0
    if s <= 0 then return Vector3.new(0, 0, 0) end
    local radius = math.min(s * (1 + math.floor(n / 5) * 0.25), 2)
    local ang = math.random() * 2 * math.pi
    local d = radius * (0.35 + 0.65 * math.random())
    return Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
end
local function looksFailed(ok, res)
    if not ok or res == false then return true end
    if type(res) == "string" then
        local l = res:lower()
        for _, w in ipairs({ "enough", "cash", "can't", "cannot", "fail", "max" }) do
            if l:find(w, 1, true) then return true end
        end
    end
    return false
end
local function runMacro(list, token)
    local function alivePlay() return alive and Play.on and Play.token == token end
    local folder = workspace:FindFirstChild("Dragons")
    local idModel, idPos, idKind, adopted, skipped = {}, {}, {}, {}, {}
    local mode = Cfg.placeMode
    -- waktu dasar: timer game > StartMatch > saat Play ditekan
    local t0 = (Match.started and os.clock() - Match.started < 600 and Match.started > Match.endedAt) and Match.started or os.clock()
    local elapsed = gameElapsed()
    if elapsed then t0 = os.clock() - elapsed end
    local timeAtStart = os.clock() - t0
    local waveAtStart = readWave()
    local endedBefore = Match.endedAt
    local function over() return Match.endedAt ~= endedBefore end
    local function isPast(a)
        if mode == "Wave" and tonumber(a.Wave) and waveAtStart then return tonumber(a.Wave) < waveAtStart end
        return (tonumber(a.Time) or 0) < timeAtStart - 1
    end
    local function waitFor(a)
        if mode == "Money" then return end
        if mode == "Wave" and tonumber(a.Wave) then
            while alivePlay() and not over() do
                local w = readWave()
                if not w or w >= tonumber(a.Wave) then break end
                task.wait(0.3)
            end
            if readWave() then return end -- wave tidak terbaca: pakai waktu
        end
        local t = tonumber(a.Time) or 0
        while alivePlay() and not over() and os.clock() - t0 < t do task.wait(0.1) end
    end
    local function resolve(id, modelName)
        if id and idModel[id] and idModel[id].Parent then return idModel[id] end
        folder = folder or workspace:FindFirstChild("Dragons")
        if not folder then return nil end
        if id and idPos[id] then
            -- model diganti saat evolusi: naga jenis sama paling dekat dengan posisi taruhnya
            local best, bestD
            for _, m in ipairs(folder:GetChildren()) do
                if kindOf(m) == idKind[id] then
                    local p = pivotOf(m)
                    if p then
                        local d = flatDist(p, idPos[id])
                        if not bestD or d < bestD then best, bestD = m, d end
                    end
                end
            end
            if best and bestD < 6 then idModel[id] = best return best end
        end
        if modelName then return folder:FindFirstChild(modelName) end
        return nil
    end
    local function findExisting(kind, pos)
        folder = folder or workspace:FindFirstChild("Dragons")
        local used = {}
        for _, m in pairs(idModel) do used[m] = true end
        for _, m in ipairs(folder and folder:GetChildren() or {}) do
            if not used[m] and kindOf(m) == kind then
                local p = pivotOf(m)
                if p and flatDist(p, pos) < 3 then return m end
            end
        end
        return nil
    end
    for i, a in ipairs(list) do
        if not alivePlay() or over() then break end
        Macro.status = string.format("Play · aksi %d/%d · menunggu %s", i, #list,
            mode == "Wave" and a.Wave and ("wave " .. tostring(a.Wave)) or mode == "Money" and "cash" or (math.floor(tonumber(a.Time) or 0) .. " dtk"))
        waitFor(a)
        if not alivePlay() or over() then break end
        Macro.status = string.format("Play · aksi %d/%d · %s", i, #list, tostring(a.Type))
        local deadline = os.clock() + 120
        if a.Type == "PlaceDragon" then
            local pos = parseVec(a.Position)
            local pre = pos and isPast(a) and findExisting(a.Dragon, pos)
            if pre then
                if a.ID then idModel[a.ID], idPos[a.ID], idKind[a.ID], adopted[a.ID] = pre, pos, a.Dragon, true end
            elseif pos then
                local done, tries = false, 0
                local offset = spreadOffset(0)
                while alivePlay() and not over() and not done and os.clock() < deadline do
                    folder = folder or workspace:FindFirstChild("Dragons")
                    local before = {}
                    for _, m in ipairs(folder and folder:GetChildren() or {}) do before[m] = true end
                    local placePos = pos + offset
                    local ok, res, msg = callRemote("PlaceDragon", a.Dragon, placePos)
                    local model = typeof(res) == "Instance" and res or nil
                    local placed = model ~= nil or (ok and res == true)
                    if placed and not model then
                        local w0 = os.clock()
                        while not model and os.clock() - w0 < 2 do
                            task.wait(0.15)
                            folder = folder or workspace:FindFirstChild("Dragons")
                            for _, m in ipairs(folder and folder:GetChildren() or {}) do
                                if not before[m] and kindOf(m) == a.Dragon then model = m break end
                            end
                        end
                    end
                    if placed then
                        done = true
                        if a.ID then idModel[a.ID], idPos[a.ID], idKind[a.ID] = model, placePos, a.Dragon end
                    else
                        local low = type(msg) == "string" and msg:lower() or ""
                        Macro.status = string.format("Place #%s %s: %s", tostring(a.ID), tostring(a.Dragon), msg ~= nil and tostring(msg) or "menunggu cash")
                        if (low:find("don't have", 1, true) or low:find("dont have", 1, true) or low:find("max", 1, true)) then
                            if a.ID then skipped[a.ID] = true end
                            notify(string.format("Place %s dilewati: %s", tostring(a.Dragon), tostring(msg)))
                            break
                        elseif low:find("too close", 1, true) then
                            local own = findExisting(a.Dragon, pos)
                            if own then
                                done = true
                                if a.ID then idModel[a.ID], idPos[a.ID], idKind[a.ID], adopted[a.ID] = own, pos, a.Dragon, true end
                            else
                                tries = tries + 1
                                offset = tries == 1 and Vector3.new(0, 0, 0) or spreadOffset(tries)
                            end
                        elseif low ~= "" and not low:find("cash", 1, true) then
                            tries = tries + 1
                            offset = spreadOffset(tries)
                        end
                        if not done then task.wait(1) end
                    end
                end
            end
        elseif a.Type == "UpgradeDragon" then
            if not (a.ID and (skipped[a.ID] or (adopted[a.ID] and isPast(a)))) then
                local done = false
                while alivePlay() and not over() and not done and os.clock() < deadline do
                    local model = resolve(a.ID, a.Model)
                    if not model then
                        Macro.status = "Upgrade #" .. tostring(a.ID or a.Model) .. ": naga tidak ditemukan"
                        task.wait(1)
                    else
                        local ok, res, msg = callRemote("UpgradeDragon", model)
                        if looksFailed(ok, res) then
                            Macro.status = "Upgrade #" .. tostring(a.ID) .. ": " .. (type(msg) == "string" and msg or "menunggu cash")
                            if type(msg) == "string" and msg:lower():find("max", 1, true) then break end
                            task.wait(1)
                        else
                            done = true
                        end
                    end
                end
            end
        elseif type(a.Type) == "string" then
            -- aksi lain (sell / target / ability): argumen "#n" = naga dengan ID n
            local args, n = {}, 0
            for k = 1, 10 do
                local v = a["Arg" .. k]
                if v == nil then break end
                n = k
                if type(v) == "string" and v:match("^#%d+$") then
                    local id = tonumber(v:sub(2))
                    if skipped[id] or (adopted[id] and isPast(a)) then n = -1 break end
                    v = resolve(id, nil) or v
                end
                args[k] = v
            end
            if n >= 0 then callRemote(a.Type, table.unpack(args, 1, n)) end
        end
    end
    if alivePlay() then
        Macro.status = over() and "Match selesai · menunggu match berikutnya" or "Macro selesai · menunggu match selesai"
    end
end
local function playLoop(token)
    local list = Macro.selected and loadMacro(Macro.selected)
    if not list or #list == 0 then
        Macro.status = "File macro tidak terbaca"
        notify(Macro.status)
        Play.on = false
        if Macro.onPlayStop then pcall(Macro.onPlayStop) end
        return
    end
    while alive and Play.on and Play.token == token do
        if inMatch() then
            runMacro(list, token)
            local endedAt = Match.endedAt
            while alive and Play.on and Play.token == token and Match.endedAt == endedAt do task.wait(0.5) end
            if not (alive and Play.on and Play.token == token) then break end
            Macro.status = "Menunggu StartMatch berikutnya..."
            local seen = Match.started
            while alive and Play.on and Play.token == token and Match.started == seen do task.wait(0.5) end
        else
            Macro.status = "Play aktif · menunggu masuk match"
            task.wait(2)
        end
    end
end
local function setPlay(v)
    Play.on = v and true or false
    Play.token = Play.token + 1
    if Play.on then
        if Rec.on then stopRecording("Play dinyalakan") end
        task.spawn(playLoop, Play.token)
    else
        Macro.status = "Mati"
    end
end

-- =====================================================================
-- PERFORMANCE
-- =====================================================================
local Perf = {}
function Perf.set3d(off)
    pcall(function() RunService:Set3dRenderingEnabled(not off) end)
end
do
    local disabledFx = setmetatable({}, { __mode = "k" })
    local savedLighting = nil
    local fxConn = nil
    local function isFx(d)
        return d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")
    end
    function Perf.lowGraphics(on)
        if on then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            pcall(function()
                savedLighting = savedLighting or { shadows = Lighting.GlobalShadows }
                Lighting.GlobalShadows = false
            end)
            for _, d in ipairs(workspace:GetDescendants()) do
                if isFx(d) and d.Enabled then disabledFx[d] = true d.Enabled = false end
            end
            if not fxConn then
                fxConn = workspace.DescendantAdded:Connect(function(d)
                    if alive and isFx(d) then task.defer(function() if d.Enabled then disabledFx[d] = true d.Enabled = false end end) end
                end)
            end
        else
            if fxConn then fxConn:Disconnect() fxConn = nil end
            for d in pairs(disabledFx) do pcall(function() d.Enabled = true end) end
            table.clear(disabledFx)
            pcall(function() if savedLighting then Lighting.GlobalShadows = savedLighting.shadows end end)
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        end
    end
    -- Hide Attack Effects: koneksi client ke AttackFX dimatikan (efek serangan tidak digambar, damage tetap dari server)
    function Perf.hideFx(on)
        if not getconnections then notifyOnce("noconn", "Executor tidak mendukung getconnections") return end
        local r = findRemote("AttackFX")
        if not r then return end
        for _, c in ipairs(getconnections(r.OnClientEvent)) do
            pcall(function() if on then c:Disable() else c:Enable() end end)
        end
    end
    -- Hide Enemy: model musuh disembunyikan dari tampilan saja (musuh tetap ada di server)
    local hiddenParts = setmetatable({}, { __mode = "k" })
    local enemyConn = {}
    local function enemyFolders()
        local out = {}
        for _, n in ipairs({ "Enemies", "Enemy", "Mobs", "Monsters", "Units" }) do
            local f = workspace:FindFirstChild(n, true)
            if f and (f:IsA("Folder") or f:IsA("Model")) and f.Name ~= "Dragons" then out[#out + 1] = f end
        end
        return out
    end
    local function hideModel(m, on)
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") then
                if on then hiddenParts[d] = true d.LocalTransparencyModifier = 1
                elseif hiddenParts[d] then d.LocalTransparencyModifier = 0 end
            elseif d:IsA("BillboardGui") then
                d.Enabled = not on
            end
        end
    end
    function Perf.hideEnemy(on)
        for _, c in ipairs(enemyConn) do c:Disconnect() end
        table.clear(enemyConn)
        local folders = enemyFolders()
        if on and #folders == 0 then notify("Hide Enemy: folder musuh belum ditemukan (nyalakan saat di match)") return end
        for _, f in ipairs(folders) do
            for _, m in ipairs(f:GetChildren()) do pcall(hideModel, m, on) end
            if on then
                enemyConn[#enemyConn + 1] = f.ChildAdded:Connect(function(m)
                    task.wait(0.1)
                    if alive then pcall(hideModel, m, true) end
                end)
            end
        end
    end
end
function Perf.fpsCap(on, n)
    local f = setfpscap or (syn and syn.setfpscap)
    if not f then notifyOnce("nofps", "Executor tidak mendukung setfpscap") return end
    pcall(f, on and (tonumber(n) or 30) or 0)
end
local PerfInfo = { fps = 0 }
do
    local frames, t0 = 0, os.clock()
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        if os.clock() - t0 >= 1 then
            PerfInfo.fps = frames / (os.clock() - t0)
            frames, t0 = 0, os.clock()
        end
    end)
end

-- Auto Execute: script dijalankan lagi otomatis setelah teleport (lobby <-> match, saat loading map).
-- Sumber script: file ArdHub/ArdHub_DTD.lua kalau ada, kalau tidak dari LOADER_URL.
local LOADER_URL = "https://raw.githubusercontent.com/AlmightyArd/GG/refs/heads/main/ArdHub%20DTD.lua"
local SELF_FILE = ROOT_DIR .. "/ArdHub_DTD.lua"
do
    local queued = false
    function Perf.queueExec()
        local q = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
        if not (Cfg.autoExec and q) or queued then return end
        local code = 'task.wait(1) if isfile and isfile("' .. SELF_FILE .. '") then loadstring(readfile("' .. SELF_FILE .. '"))()'
        if LOADER_URL ~= "" then code = code .. ' else loadstring(game:HttpGet("' .. LOADER_URL .. '"))()' end
        code = code .. ' end'
        if pcall(q, code) then queued = true end
    end
    function Perf.execSource()
        local q = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
        if not q then return "Executor tidak mendukung queue_on_teleport" end
        if isfile and isfile(SELF_FILE) then return "Sumber: file " .. SELF_FILE end
        if LOADER_URL ~= "" then return "Sumber: link script" end
        return "Simpan script ini ke workspace/" .. SELF_FILE .. " supaya bisa dijalankan ulang"
    end
    LocalPlayer.OnTeleport:Connect(function(st)
        if alive and st == Enum.TeleportState.Started then Perf.queueExec() end
    end)
    Mine.queueExec = Perf.queueExec
end

-- =====================================================================
-- WEBHOOK (gaya progress bar + avatar)
-- =====================================================================
local Webhook = { url = "" }
local function validWebhook(url)
    if type(url) ~= "string" then return false end
    return url:match("^https://[%w]*%.?discord%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
end
local function sendWebhook(embed, mentionText)
    if not validWebhook(Webhook.url) then notify("Webhook Link tidak valid") return false end
    if not REQ then notify("Executor tidak mendukung request()") return false end
    local payload = { username = "Ard Hub", embeds = { embed }, allowed_mentions = { parse = {} } }
    local uid = tostring(Cfg.discordUserId or "")
    if mentionText and uid:match("^%d+$") and #uid >= 15 then
        payload.content = "<@" .. uid .. "> " .. mentionText
        payload.allowed_mentions = { users = { uid } }
    end
    local ok, code = postJson(Webhook.url, payload)
    if not ok then notify("Webhook gagal dikirim" .. (code and (" (" .. tostring(code) .. ")") or "")) end
    return ok
end
local avatarUrl = nil
local function getAvatar()
    if avatarUrl or not REQ then return avatarUrl end
    pcall(function()
        local res = REQ({
            Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. LocalPlayer.UserId .. "&size=150x150&format=Png&isCircular=false",
            Method = "GET",
        })
        local data = res and jsonDecode(res.Body)
        local item = data and data.data and data.data[1]
        if item and type(item.imageUrl) == "string" and item.imageUrl ~= "" then avatarUrl = item.imageUrl end
    end)
    return avatarUrl
end
local function bar(cur, max)
    local n = 10
    local f = (max and max > 0) and math.clamp(math.floor(cur / max * n + 0.5), 0, n) or 0
    return string.rep("▰", f) .. string.rep("▱", n - f)
end
local function sessionFooter()
    return string.format("Sesi: %d match · %dW %dL · +%s coins · %s · %s", Session.matches or 0, Session.wins or 0,
        Session.losses or 0, comma(Session.coinsEarned or 0), sessionTime(), VERSION)
end
local function mmss(s)
    s = math.floor(tonumber(s) or 0)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
local function buildMatchEmbed(data)
    local won = data.won == true
    local wave = tonumber(data.wave) or 0
    local total = won and wave or tonumber(MapWaves[Match.map or ""])
    local dur = Match.lastTimer or (Match.started and (os.clock() - Match.started)) or nil
    local lines = { "||" .. LocalPlayer.Name .. "||", string.format("%s · **Wave %s%s**%s", prettyMap(Match.map), wave, total and ("/" .. total) or "", dur and (" · " .. mmss(dur)) or "") }
    local bars = {}
    if Cfg.whWave and total then bars[#bars + 1] = string.format("🌊 `Wave   %s %d/%d`", bar(wave, total), wave, total) end
    local bp = bpInfo()
    if Cfg.whBP then bars[#bars + 1] = string.format("⭐ `BP T%-3d %s %s/%s`", bp.tier, bar(bp.xp, bp.need), comma(bp.xp), comma(bp.need)) end
    if Cfg.whDaily then bars[#bars + 1] = string.format("📅 `Daily  %s %s/%s`", bar(bp.daily, bp.dailyMax), comma(bp.daily), comma(bp.dailyMax)) end
    if #bars > 0 then lines[#lines + 1] = "\n" .. table.concat(bars, "\n") end
    local fields = {}
    if Cfg.whCoins then
        fields[#fields + 1] = { name = "🪙 Coins", value = string.format("+%s%s · %s", comma(data._gain or data.coins), data._coinPotion and " (potion x2)" or "", comma(attr("Coins"))), inline = true }
        fields[#fields + 1] = { name = "💎 Gems", value = comma(attr("Gems")), inline = true }
    end
    local embed = {
        author = { name = "Ard Hub · Dragon Tower Defense" },
        title = won and "🏆 Victory" or "💀 Defeat",
        description = table.concat(lines, "\n"),
        color = won and 0xF59E0B or 0xEF4444,
        fields = fields,
        footer = { text = sessionFooter() },
        timestamp = DateTime.now():ToIsoDate(),
    }
    if Cfg.whAvatar and getAvatar() then embed.thumbnail = { url = avatarUrl } end
    return embed
end
-- ringkasan berkala: selisih sejak ringkasan sebelumnya
local SumBase = nil
local function snapshot()
    local bp = bpInfo()
    return { matches = Session.matches or 0, wins = Session.wins or 0, coins = tonumber(attr("Coins")) or 0, gems = tonumber(attr("Gems")) or 0,
        tier = bp.tier, claimed = Session.claimed or 0, summons = Session.summonCount or 0, t = os.time() }
end
local function buildSummaryEmbed()
    local now = snapshot()
    local base = SumBase or { matches = 0, wins = 0, coins = Session.coinsStart or now.coins, gems = Session.gemsStart or now.gems,
        tier = now.tier, claimed = 0, summons = 0, t = tonumber(Session.start) or now.t }
    local mins = math.max(math.floor((now.t - base.t) / 60 + 0.5), 1)
    local bp = bpInfo()
    local m = now.matches - base.matches
    local bars = {}
    if Cfg.whBP then
        bars[#bars + 1] = string.format("⭐ `BP %s %s %s/%s`", base.tier ~= now.tier and ("T" .. base.tier .. "→T" .. now.tier) or ("T" .. now.tier),
            bar(bp.xp, bp.need), comma(bp.xp), comma(bp.need))
    end
    if Cfg.whDaily then bars[#bars + 1] = string.format("📅 `Daily %s %s/%s`", bar(bp.daily, bp.dailyMax), comma(bp.daily), comma(bp.dailyMax)) end
    local fields = {
        { name = "⚔️ Match", value = string.format("%d (%d menang)", m, now.wins - base.wins), inline = true },
        { name = "🪙 Coins", value = string.format("%+d · %s", now.coins - base.coins, comma(now.coins)), inline = true },
        { name = "💎 Gems", value = string.format("%+d · %s", now.gems - base.gems, comma(now.gems)), inline = true },
        { name = "🎁 Diklaim", value = tostring(now.claimed - base.claimed) .. " hadiah", inline = true },
    }
    if m > 0 then fields[#fields + 1] = { name = "⏱️ Rata-rata", value = mmss((now.t - base.t) / m) .. " / match", inline = true } end
    if Cfg.whSummon then fields[#fields + 1] = { name = "🐉 Summon", value = tostring(now.summons - base.summons) .. "x", inline = true } end
    local embed = {
        author = { name = "Ard Hub · Dragon Tower Defense" },
        title = string.format("📊 Ringkasan %d menit", mins),
        description = "||" .. LocalPlayer.Name .. "||" .. (#bars > 0 and ("\n\n" .. table.concat(bars, "\n")) or ""),
        color = 0xA78BFA,
        fields = fields,
        footer = { text = VERSION },
        timestamp = DateTime.now():ToIsoDate(),
    }
    if Cfg.whAvatar and getAvatar() then embed.thumbnail = { url = avatarUrl } end
    SumBase = now
    return embed
end
MatchEndedEv.Event:Connect(function(data)
    if not Cfg.whMatchEnd or not validWebhook(Webhook.url) then return end
    task.wait(2) -- tunggu Coins / Battlepass di atribut ikut diperbarui
    local mention = nil
    if Cfg.tagEvery then mention = data.won and "match selesai" or "match kalah"
    elseif Cfg.tagDefeat and not data.won then mention = "match kalah" end
    pcall(function() sendWebhook(buildMatchEmbed(data), mention) end)
end)
task.spawn(function()
    local nextAt = nil
    local hit = {}
    while alive do
        task.wait(10)
        if Cfg.summary and validWebhook(Webhook.url) then
            nextAt = nextAt or (os.time() + (tonumber(Cfg.summaryMinutes) or 60) * 60)
            if os.time() >= nextAt then
                nextAt = os.time() + (tonumber(Cfg.summaryMinutes) or 60) * 60
                pcall(function() sendWebhook(buildSummaryEmbed()) end)
            end
        else
            nextAt = nil
        end
        if Cfg.alertTarget and validWebhook(Webhook.url) then
            pcall(function()
                local coins = (tonumber(attr("Coins")) or 0) - (Session.coinsStart or 0)
                local gems = (tonumber(attr("Gems")) or 0) - (Session.gemsStart or 0)
                for _, t in ipairs({ { "coins", coins, tonumber(Cfg.targetCoins) or 0, "🪙 Coins" }, { "gems", gems, tonumber(Cfg.targetGems) or 0, "💎 Gems" } }) do
                    if t[3] > 0 and t[2] >= t[3] and not hit[t[1]] then
                        hit[t[1]] = true
                        sendWebhook({
                            author = { name = "Ard Hub · Dragon Tower Defense" },
                            title = "🎯 Target tercapai",
                            description = string.format("%s sesi ini: **+%s** (target %s)", t[4], comma(t[2]), comma(t[3])),
                            color = 0x22C55E, footer = { text = sessionFooter() }, timestamp = DateTime.now():ToIsoDate(),
                            thumbnail = (Cfg.whAvatar and getAvatar()) and { url = avatarUrl } or nil,
                        }, Cfg.tagTarget and "target tercapai" or nil)
                    end
                end
            end)
        end
    end
end)

-- penghitung pengguna
do
    local ID_FILE = ROOT_DIR .. "/install_id.txt"
    local function installId()
        local id = safeRead(ID_FILE)
        id = id and id:gsub("%s+", ""):lower() or nil
        if id and id:match("^%x+$") and #id == 32 then return id end
        id = HttpService:GenerateGUID(false):gsub("%-", ""):lower()
        safeMakeDir(ROOT_DIR)
        safeWrite(ID_FILE, id)
        return id
    end
    task.spawn(function()
        local okId, id = pcall(installId)
        local url = (Cfg.telemetryUrl:gsub("/rpc/ard_telemetry", "/rpc/ard_usage_ping", 1))
        if not (okId and id) then return end
        local event = "execute"
        while alive do
            pcall(postJson, url, { p_id = id, p_version = "DTD " .. VERSION, p_event = event, p_user = LocalPlayer.Name })
            event = "heartbeat"
            local untilAt = os.clock() + 600
            while alive and os.clock() < untilAt do task.wait(5) end
        end
    end)
end

-- =====================================================================
-- UI
-- =====================================================================
local function buildUI()
task.spawn(function() -- badge status di kepala jendela
    local last
    while alive do
        local m = inMatch()
        if m ~= last then
            last = m
            pcall(HubStatus, m and "In match" or "Lobby", m)
        end
        task.wait(2)
    end
end)
Flag("darkMode", ThemeToggle, "toggle")

-- ---------------- Lobby ----------------
do
    local tLobby = AddTab("Lobby")
    local sJoin = tLobby:AddSection("Auto Join", "left")
    Flag("map", sJoin:AddDropdown("Map", MAP_LIST, Cfg.map, function(v) Cfg.map = v end))
    Flag("turkeyPad", sJoin:AddDropdown("Difficulty (Turkey)", TURKEY_DIFF, "Nightmare", function(v)
        for i, n in ipairs(TURKEY_DIFF) do if n == v then Cfg.turkeyPad = i end end
    end))
    Flag("pad", sJoin:AddDropdown("Pad", { "Pad 1", "Pad 2", "Pad 3" }, "Pad 1", function(v)
        Cfg.pad = tonumber(tostring(v):match("%d+")) or 1
    end))
    Flag("autoJoin", sJoin:AddToggle("Auto Join Map (jalan ke pad)", false, function(v) Cfg.autoJoin = v end), "toggle")
    Flag("autoFriends", sJoin:AddToggle("Auto Friends Only", false, function(v) Cfg.autoFriends = v end), "toggle")

    local sSum = tLobby:AddSection("Auto Summon", "left")
    Flag("summonAmount", sSum:AddDropdown("Summon", { "1x", "10x" }, "10x", function(v)
        Cfg.summonAmount = (v == "1x") and 1 or 10
    end))
    Flag("summonDelay", sSum:AddSlider("Delay Summon", 1, 5, 1, " detik", function(v) Cfg.summonDelay = math.max(v, 1) end, 0.5))
    local sumStatus = sSum:AddLabel("Status: mati")
    Flag("autoSummon", sSum:AddToggle("Auto Summon", false, function(v) Cfg.autoSummon = v end), "toggle")
    sSum:AddDivider()
    sSum:AddLabel("Auto Sell hasil summon (setting game, tersimpan di akun)")
    for _, r in ipairs({ "Common", "Uncommon", "Rare", "Epic" }) do
        sSum:AddToggle("Sell " .. r, attr("AutoSell" .. r) == true, function(v)
            if attr("AutoSell" .. r) ~= v then callRemote("SetSetting", "sell" .. r, v) end
        end)
    end

    local sPot = tLobby:AddSection("Auto Potion", "right")
    Flag("potionCoins", sPot:AddToggle("Auto Coins Potion", false, function(v) Cfg.potionCoins = v end), "toggle")
    Flag("potionLuck", sPot:AddToggle("Auto Luck Potion", false, function(v) Cfg.potionLuck = v end), "toggle")
    Flag("potionSpeed", sPot:AddToggle("Auto 4x Speed Potion", false, function(v) Cfg.potionSpeed = v end), "toggle")
    local potStatus = sPot:AddLabel("-")
    sPot:AddLabel("Diminum saat efeknya habis dan stok masih ada. Coins & Speed hanya saat match berjalan, Luck kapan saja.")
    task.spawn(function()
        while alive do
            pcall(function()
                local parts = {}
                for _, p in ipairs(POTIONS) do
                    local left = (tonumber(attr(p.ends)) or 0) - os.time()
                    parts[#parts + 1] = string.format("%s: %s · %s", p.key:sub(1, 1):upper() .. p.key:sub(2), comma(attr(p.stock)),
                        left > 0 and (math.floor(left / 60) .. "m aktif") or "mati")
                end
                potStatus.Text = table.concat(parts, "\n")
            end)
            task.wait(2)
        end
    end)

    local sInfo = tLobby:AddSection("Info Akun", "right")
    local infoBP = sInfo:AddLabel("Battle Pass: -")
    local infoDaily = sInfo:AddLabel("XP Harian: -")
    local infoMoney = sInfo:AddLabel("Coins: - · Gems: -")
    local infoMisc = sInfo:AddLabel("Free Summons: -")
    for _, l in ipairs({ infoBP, infoDaily, infoMoney, infoMisc }) do
        l.TextSize = 12
        l.TextColor3 = THEME.label
    end

    local sClaim = tLobby:AddSection("Auto Claim", "right")
    Flag("claimQuest", sClaim:AddToggle("Claim Quest (daily & weekly)", false, function(v) Cfg.claimQuest = v end), "toggle")
    local questStatus = sClaim:AddLabel("Quest: -")
    Flag("claimBonus", sClaim:AddToggle("Claim Quest Bonus", false, function(v) Cfg.claimBonus = v end), "toggle")
    Flag("claimPlaytime", sClaim:AddToggle("Claim Playtime Reward", false, function(v) Cfg.claimPlaytime = v end), "toggle")
    Flag("claimIndex", sClaim:AddToggle("Claim Index", false, function(v) Cfg.claimIndex = v end), "toggle")
    Flag("claimBP", sClaim:AddToggle("Claim Battle Pass", false, function(v) Cfg.claimBP = v end), "toggle")

    task.spawn(function()
        while alive do
            pcall(function()
                local bp = bpInfo()
                infoBP.Text = string.format("Battle Pass · Tier %d / 30\n%s  %s / %s XP", bp.tier, bar(bp.xp, bp.need), comma(bp.xp), comma(bp.need))
                infoDaily.Text = string.format("XP Harian\n%s  %s / %s", bar(bp.daily, bp.dailyMax), comma(bp.daily), comma(bp.dailyMax))
                infoMoney.Text = string.format("Coins: %s   ·   Gems: %s", comma(attr("Coins")), comma(attr("Gems")))
                infoMisc.Text = string.format("Free Summons: %s   ·   Trait Shards: %s", comma(attr("FreeSummons")), comma(attr("TraitShards")))
                questStatus.Text = questLine()
                sumStatus.Text = LobbyStatus.summon .. (LobbyStatus.lastSummon and ("\nTerakhir: " .. LobbyStatus.lastSummon) or "")
            end)
            task.wait(2)
        end
    end)
end

-- ---------------- Match ----------------
do
    local tMatch = AddTab("Match")
    local sMatch = tMatch:AddSection("Match", "left")
    Flag("autoStart", sMatch:AddToggle("Auto Start Match", false, function(v) Cfg.autoStart = v end), "toggle")
    Flag("autoSkip", sMatch:AddToggle("Auto Skip Wave", false, function(v) Cfg.autoSkip = v end), "toggle")
    Flag("autoAgain", sMatch:AddToggle("Auto Play Again", false, function(v) Cfg.autoAgain = v end), "toggle")
    Flag("autoReturn", sMatch:AddToggle("Auto Return to Lobby", false, function(v) Cfg.autoReturn = v end), "toggle")
    Flag("returnEvery", sMatch:AddInput("Return ke Lobby setiap (match)", "10", "10", function(t)
        Cfg.returnEvery = math.max(tonumber(t) or 10, 1)
    end, true), "input")
    sMatch:AddLabel("Auto Return lebih diutamakan dari Play Again saat jumlah match di server ini sudah tercapai.")

    local sSpeed = tMatch:AddSection("Game Speed", "left")
    Flag("speed", sSpeed:AddDropdown("Speed", { "x2", "x3", "x4" }, "x2", function(v)
        Cfg.speed = tonumber(tostring(v):match("%d+")) or 2
    end))
    Flag("autoSpeed", sSpeed:AddToggle("Auto Set Speed", false, function(v) Cfg.autoSpeed = v end), "toggle")
    sSpeed:AddLabel("x4 hanya aktif saat Speed Potion menyala; tanpa potion otomatis x2. x3 butuh gamepass.")

    local sPlayer = tMatch:AddSection("Player", "right")
    Flag("autoWalk", sPlayer:AddToggle("Auto Walk", false, function(v) Cfg.autoWalk = v end), "toggle")
    Flag("walkRadius", sPlayer:AddSlider("Walk Radius", 2, 12, 6, " studs", function(v) Cfg.walkRadius = v end))
    Flag("walkMax", sPlayer:AddSlider("Walk Interval (maks)", 5, 20, 9, " detik", function(v) Cfg.walkMax = v end))
    sPlayer:AddDivider()
    Flag("antiAfk", sPlayer:AddToggle("Anti AFK", true, function(v) Cfg.antiAfk = v end), "toggle")

    local sInfo = tMatch:AddSection("Info Match", "right")
    local l1 = sInfo:AddLabel("-")
    local l2 = sInfo:AddLabel("-")
    task.spawn(function()
        while alive do
            pcall(function()
                if inMatch() then
                    local w, t = readWave()
                    l1.Text = string.format("Map: %s · Wave %s · %s", prettyMap(Match.map), w and (tostring(w) .. (t and ("/" .. t) or "")) or "?",
                        Match.lastTimer and mmss(Match.lastTimer) or "-")
                else
                    l1.Text = "Di lobby"
                end
                l2.Text = string.format("Sesi %s: %d match · %d menang · %d kalah · +%s coins", sessionTime(), Session.matches or 0,
                    Session.wins or 0, Session.losses or 0, comma(Session.coinsEarned or 0))
            end)
            task.wait(2)
        end
    end)
end

-- ---------------- Macro ----------------
do
    local tMacro = AddTab("Macro")
    local sFiles = tMacro:AddSection("Files", "left")
    local dd
    dd = sFiles:AddDropdown("Selected Macro", listMacros(), nil, function(v) Macro.selected = v end)
    Flag("selectedMacro", dd)
    local function refresh(keep)
        local list = listMacros()
        dd:SetOptions(list)
        if keep then dd:Set(keep) Macro.selected = keep end
    end
    Macro.onSaved = function(name) refresh(name) end
    sFiles:AddButtonRow("Refresh List", function() refresh(Macro.selected) end, "Delete", function()
        if not Macro.selected then return end
        if delfile then pcall(delfile, macroPath(Macro.selected)) end
        notify("Dihapus: " .. tostring(Macro.selected))
        Macro.selected = nil
        refresh(nil)
    end)
    sFiles:AddDivider()
    local nameInput = sFiles:AddInput("New File Name", "Nama macro", "", nil, false)
    sFiles:AddButton("Create Macro File", function()
        local n = cleanName(nameInput:Get())
        if n == "" then notify("Isi nama macro dulu") return end
        if saveMacro(n, {}, { recordedAt = os.date("%Y-%m-%d %H:%M:%S") }) then
            refresh(n)
            notify("Macro dibuat: " .. n)
        end
    end)

    local sIO = tMacro:AddSection("Import / Export", "left")
    local ioInput = sIO:AddInput("Macro Link or JSON", "Tempel link atau JSON di sini", "", nil, false)
    sIO:AddButtonRow("Import Macro", function()
        local src = tostring(ioInput:Get() or "")
        if src:match("^https?://") then
            local ok, body = pcall(function() return game:HttpGet(src) end)
            src = ok and body or ""
        end
        local data = jsonDecode(src)
        local list = type(data) == "table" and (data.actions or data) or nil
        if type(list) ~= "table" or #list == 0 then notify("Macro tidak valid") return end
        local n = cleanName(nameInput:Get())
        if n == "" then n = "import_" .. os.date("%Y%m%d_%H%M%S") end
        if saveMacro(n, list, type(data) == "table" and data or nil) then
            refresh(n)
            notify("Macro diimpor: " .. n)
        end
    end, "Export Selected", function()
        local raw = Macro.selected and safeRead(macroPath(Macro.selected))
        if not raw then notify("Pilih macro dulu") return end
        if setclipboard and pcall(setclipboard, raw) then notify("Macro disalin ke clipboard") else notify("Executor tidak mendukung setclipboard") end
    end)

    local sRP = tMacro:AddSection("Record / Play", "right")
    sRP:AddLabel("Record merekam: naga, posisi, waktu, wave, upgrade, target, sell. Disimpan ke macro yang dipilih (kosong = nama map + waktu).")
    local recToggle, playToggle
    recToggle = sRP:AddToggle("Record Macro", false, function(v)
        if v then
            if Play.on and playToggle then playToggle:Set(false) end
            startRecording()
        else
            stopRecording("tombol")
        end
    end)
    sRP:AddDivider()
    playToggle = sRP:AddToggle("Play Macro", false, function(v)
        if v and Rec.on then recToggle:Set(false, true) stopRecording("Play dinyalakan") end
        setPlay(v)
    end)
    Flag("playMacro", playToggle, "toggle")
    Macro.onRecordStop = function() recToggle:Set(false, true) end
    Macro.onPlayStop = function() playToggle:Set(false, true) end
    local status = sRP:AddLabel("Status: mati")
    task.spawn(function()
        while alive do
            status.Text = "Status: " .. tostring(Macro.status)
            task.wait(0.5)
        end
    end)

    local sPlace = tMacro:AddSection("Placement", "right")
    Flag("placeMode", sPlace:AddDropdown("Mode Placement", { "Time", "Wave", "Money" }, "Time", function(v) Cfg.placeMode = v end))
    sPlace:AddLabel("Time: sesuai detik rekaman. Wave: sesuai wave saat direkam. Money: langsung begitu cash cukup, urutan tetap.")
    Flag("spread", sPlace:AddSlider("Placement Spread", 0, 2, 0.3, " studs", function(v) Cfg.spread = v end, 0.1))
    sPlace:AddLabel("Naga yang tidak dimiliki atau kena batas \"Max\" otomatis dilewati.")
end

-- ---------------- Mine ----------------
do
    local tMine = AddTab("Mine")
    local sMine = tMine:AddSection("Auto Mine", "left")
    Flag("autoMine", sMine:AddToggle("Auto Mine (terjadwal)", false, function(v) Cfg.autoMine = v end), "toggle")
    sMine:AddLabel("Menunggu Mine buka. Saat buka: keluar dari match ke lobby, masuk Mine, lalu gali otomatis. Setelah Mine selesai, Auto Join map / Play Macro jalan lagi. Nyalakan Auto Execute (tab Performance) supaya script ikut jalan setelah pindah server.")
    local sched = sMine:AddLabel("Jadwal: -")
    Flag("autoDig", sMine:AddToggle("Auto Dig (saat sudah di Mine)", false, function(v) Cfg.autoDig = v end), "toggle")
    Flag("minePattern", sMine:AddDropdown("Pola Gali", { "Lorong Cepat", "Lorong", "Zig-zag" }, "Lorong Cepat", function(v) Cfg.minePattern = v end))
    sMine:AddLabel("Lorong Cepat: sama dengan Lorong, tapi begitu chest di satu lapisan sudah diambil (data: paling banyak 1 chest per lapisan), sisa lapisan dilewati dan langsung turun. Lapisan 1 langsung ditembus.")
    sMine:AddLabel("Lorong: hanya jalur baris 0, 3, 6, 9 yang digali (46 blok/lapisan), blok lain tetap terlihat isinya dari samping, jadi lebih cepat turun dan lebih banyak blok terlihat. Zig-zag: semua blok digali. Item yang terlihat selalu dipukul duluan.")
    Flag("mineDelay", sMine:AddSlider("Jeda Tambahan", 0, 2, 0, " detik", function(v) Cfg.mineDelay = v end, 0.1))
    local st = sMine:AddLabel("Status: mati")
    local sPool = tMine:AddSection("Sisa Harta (semua server)", "right")
    local pool = sPool:AddLabel("-")
    local sFind = tMine:AddSection("Your Finds", "right")
    local finds = sFind:AddLabel("-")
    local items = sFind:AddLabel("-")
    local news = sFind:AddLabel("-")
    local raw = sFind:AddLabel("-")
    local sData = tMine:AddSection("Data Mine", "right")
    local dataL = sData:AddLabel("-")
    sData:AddLabel("Tersimpan di ArdHub/DragonTD/mine_data.json dan mine_items.csv untuk dianalisis.")
    task.spawn(function()
        while alive do
            pcall(function()
                st.Text = "Status: " .. tostring(Mine.status)
                sched.Text = string.format("Jadwal Mine: %s\nServer: %s (PlaceId %s)", tostring(Mine.schedule),
                    inMine() and "Mine" or isLobby() and "Lobby" or "Match", tostring(game.PlaceId))
                local ms = mineState()
                if ms then
                    local left = (tonumber(ms.EndsAt) or 0) - os.time()
                    pool.Text = string.format("%s%s\nSECRET %s/%s · Pass %s/%s · Gems %s/%s\nPotions %s/%s · Shards %s/%s · Coins %s",
                        ms.Phase == "Open" and "Buka" or ("Tutup (" .. tostring(ms.Phase) .. ")"),
                        (ms.Phase == "Open" and left > 0) and (" · tutup dalam " .. mmss(left)) or "",
                        comma(ms.Left_secret), comma(ms.Total_secret), comma(ms.Left_pass), comma(ms.Total_pass),
                        comma(ms.Left_gems), comma(ms.Total_gems), comma(ms.Left_potions), comma(ms.Total_potions),
                        comma(ms.Left_shards), comma(ms.Total_shards), comma(ms.Left_coins))
                else
                    pool.Text = "Data Mine belum terbaca"
                end
                local f = Mine.finds or {}
                finds.Text = string.format("Blok: %s · Gems: %s · Coins: %s\nPotion: %s · Shards: %s · Pets: %s",
                    comma(f.blocks), comma(f.gems), comma(f.coins), comma(f.potions), comma(f.shards), comma(f.pets))
                local open = 0
                for _ in pairs(Mine.items) do open = open + 1 end
                items.Text = string.format("Item terlihat: %d · Terakhir: %s", open, #Mine.lastItems > 0 and table.concat(Mine.lastItems, ", ") or "-")
                news.Text = "Kabar: " .. tostring(Mine.news or "-")
                raw.Text = "[diag] " .. (#Mine.raw > 0 and table.concat(Mine.raw, " | ") or "-")
                dataL.Text = Mine.dataSummary()
            end)
            task.wait(1)
        end
    end)
end

-- ---------------- Performance ----------------
do
    local tPerf = AddTab("Performance")
    local sPerf = tPerf:AddSection("Performance", "left")
    Flag("disable3d", sPerf:AddToggle("Disable 3D Rendering", false, function(v) Perf.set3d(v) end), "toggle")
    Flag("lowGfx", sPerf:AddToggle("Low Graphics", false, function(v) Perf.lowGraphics(v) end), "toggle")
    Flag("hideFx", sPerf:AddToggle("Hide Attack Effects", false, function(v) Perf.hideFx(v) end), "toggle")
    Flag("hideEnemy", sPerf:AddToggle("Hide Enemy", false, function(v) Perf.hideEnemy(v) end), "toggle")
    -- Ukuran teks: semua teks di jendela Ard Hub ditambah N poin dari ukuran aslinya
    local sView = tPerf:AddSection("Tampilan", "left")
    local baseSize = setmetatable({}, { __mode = "k" })
    local textDelta = 0
    local function applyText(d)
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            if not baseSize[d] then baseSize[d] = d.TextSize end
            d.TextSize = baseSize[d] + textDelta
        end
    end
    local function applyAll()
        for _, root in ipairs({ Gui, StatusGui }) do
            for _, d in ipairs(root:GetDescendants()) do pcall(applyText, d) end
        end
    end
    for _, root in ipairs({ Gui, StatusGui }) do
        root.DescendantAdded:Connect(function(d)
            task.defer(function() if textDelta ~= 0 then pcall(applyText, d) end end)
        end)
    end
    Flag("textSize", sView:AddSlider("Ukuran Teks", 0, 6, 2, "", function(v)
        textDelta = math.floor(tonumber(v) or 0)
        applyAll()
    end))
    sView:AddLabel("Menambah ukuran semua teks di Ard Hub (0 = ukuran asli).")
    textDelta = 2 -- bawaan +2
    task.defer(applyAll)
    local sExec = tPerf:AddSection("Auto Execute", "left")
    local execInfo
    Flag("autoExec", sExec:AddToggle("Auto Execute", false, function(v)
        Cfg.autoExec = v
        if v then Perf.queueExec() end
        if execInfo then execInfo.Text = v and Perf.execSource() or "Mati" end
    end), "toggle")
    execInfo = sExec:AddLabel("Mati")
    sExec:AddLabel("Script langsung jalan lagi setelah pindah lobby <-> match (saat loading map), dengan setting yang sama.")
    local sFps = tPerf:AddSection("FPS", "left")
    local capToggle
    Flag("fpsLimit", sFps:AddSlider("FPS Limit", 15, 120, 30, " fps", function(v)
        Cfg.fpsLimit = v
        if capToggle and capToggle:Get() then Perf.fpsCap(true, v) end
    end, 5))
    capToggle = sFps:AddToggle("Cap FPS", false, function(v) Perf.fpsCap(v, Cfg.fpsLimit) end)
    Flag("fpsCap", capToggle, "toggle")
    local sInfo = tPerf:AddSection("Info", "right")
    local l = sInfo:AddLabel("-")
    sInfo:AddLabel("Disable 3D Rendering paling hemat, tapi layar jadi hitam. Hide Enemy dan Hide Attack Effects hanya menyembunyikan tampilan; musuh dan serangan tetap berjalan di server.")
    task.spawn(function()
        while alive do
            pcall(function()
                l.Text = string.format("FPS %d · Memory %d MB", math.floor(PerfInfo.fps + 0.5), math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb()))
            end)
            task.wait(1)
        end
    end)
end

-- ---------------- Webhook ----------------
do
    local tHook = AddTab("Webhook")
    local sHook = tHook:AddSection("Discord Webhook", "left")
    Flag("webhook", sHook:AddInput("Webhook Link", "https://discord.com/api/webhooks/...", "", function(t)
        Webhook.url = tostring(t or "")
    end, false), "input")
    sHook:AddButton("Test Send Webhook", function()
        if sendWebhook({
            author = { name = "Ard Hub · Dragon Tower Defense" }, title = "✅ Test Webhook",
            description = "Webhook tersambung. Akun: ||" .. LocalPlayer.Name .. "||", color = 0xA78BFA,
            thumbnail = (Cfg.whAvatar and getAvatar()) and { url = avatarUrl } or nil,
            footer = { text = VERSION }, timestamp = DateTime.now():ToIsoDate(),
        }) then notify("Webhook terkirim") end
    end)
    Flag("whMatchEnd", sHook:AddToggle("Send Webhook On Match End", false, function(v) Cfg.whMatchEnd = v end), "toggle")
    Flag("discordUserId", sHook:AddInput("Discord User ID (untuk tag)", "mis. 123456789012345678", "", function(t)
        Cfg.discordUserId = tostring(t or "")
    end, true), "input")
    Flag("tagEvery", sHook:AddToggle("Tag di Setiap Akhir Match", false, function(v) Cfg.tagEvery = v end), "toggle")
    Flag("tagDefeat", sHook:AddToggle("Tag Hanya Saat Defeat", true, function(v) Cfg.tagDefeat = v end), "toggle")

    local sSum = tHook:AddSection("Ringkasan Berkala", "left")
    Flag("summary", sSum:AddToggle("Kirim Ringkasan", false, function(v) Cfg.summary = v end), "toggle")
    Flag("summaryMin", sSum:AddSlider("Interval", 10, 240, 60, " mnt", function(v) Cfg.summaryMinutes = v end, 5))
    sSum:AddButton("Kirim Ringkasan Sekarang", function()
        if sendWebhook(buildSummaryEmbed()) then notify("Ringkasan terkirim") end
    end)

    local sIsi = tHook:AddSection("Isi Webhook", "right")
    for _, it in ipairs({
        { "whAvatar", "Avatar Roblox di thumbnail", true }, { "whWave", "Progress Bar Wave", true },
        { "whBP", "Progress Bar Battle Pass", true }, { "whDaily", "XP Harian", true },
        { "whCoins", "Coins & Gems", true }, { "whSummon", "Hasil Summon", false },
    }) do
        Flag(it[1], sIsi:AddToggle(it[2], it[3], function(v) Cfg[it[1]] = v end), "toggle")
    end

    local sTarget = tHook:AddSection("Target", "right")
    Flag("alertTarget", sTarget:AddToggle("Kirim Saat Target Tercapai", false, function(v) Cfg.alertTarget = v end), "toggle")
    Flag("targetCoins", sTarget:AddInput("Target Coins (sesi)", "0 = mati", "", function(t) Cfg.targetCoins = tonumber(t) or 0 end, true), "input")
    Flag("targetGems", sTarget:AddInput("Target Gems (sesi)", "0 = mati", "", function(t) Cfg.targetGems = tonumber(t) or 0 end, true), "input")
    Flag("tagTarget", sTarget:AddToggle("Tag Saat Target Tercapai", true, function(v) Cfg.tagTarget = v end), "toggle")
end

-- muat setting tersimpan
local savedMacro = SavedConfig.selectedMacro
if type(savedMacro) == "string" and isfile and isfile(macroPath(savedMacro)) then
    Macro.selected = savedMacro
    pcall(function() Flags.selectedMacro:Set(savedMacro, true) end)
end
configLoading = true
pcall(function()
    for pass = 1, 2 do
        for _, f in ipairs(FlagOrder) do
            local isToggle = (f.kind == "toggle")
            local v = SavedConfig[f.name]
            if v ~= nil and f.name ~= "selectedMacro" and ((pass == 2) == isToggle) then
                local okGet, cur = pcall(f.api.Get, f.api)
                if not okGet or cur ~= v then
                    if f.kind == "input" then f.api:Set(v, true) else f.api:Set(v) end
                end
            end
        end
        if pass == 1 then task.wait(0.1) end
    end
end)
configLoading = false
if not HAS_FS then notify("Executor tanpa file system: setting tidak tersimpan") end
end
buildUI()
end, function(e)
    return tostring(e) .. "\n" .. tostring(debug.traceback())
end)
if not __ok then
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name = "ArdHubDTDError"
        g.ResetOnSpawn = false
        g.DisplayOrder = 100
        local okp = pcall(function()
            g.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not okp or not g.Parent then
            g.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
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
        f.Text = "Ard Hub DTD ERROR:\n" .. tostring(__err)
        f.Parent = g
    end)
end
