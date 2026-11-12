local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local __ok, __err = xpcall(function()
local TITLE = "Ard Hub"
local VERSION = "v2.5.5"
local FOOTER = "Garden Tower Defense | Ard Hub | " .. VERSION
local ROOT_DIR = "ArdHub"
local CONFIG_FILE = ROOT_DIR .. "/config.json"
local TOGGLE_KEY = Enum.KeyCode.RightControl
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
local ICONS = {
    ["Dashboard API"] = "📡",
    ["Humanizer"] = "🎲",
    ["Auto Mode"] = "🤖",
    ["Macro"] = "🎬",
    ["Anti Ban"] = "🛡",
    ["Webhook"] = "🔔",
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
local function makeIcon(parent, icon, position, size)
    size = size or 16
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
        return obj, function(c)
            obj.TextTransparency = (c == THEME.muted) and 0.45 or 0
        end
    end
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
local SearchBox, SideList, Pages
do
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
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = THEME.stroke,
    BorderSizePixel = 0,
    Parent = TopBar,
})
local SearchFrame = new("Frame", {
    Size = UDim2.new(1, -290, 0, 30),
    Position = UDim2.new(0, 180, 0, 7),
    BackgroundColor3 = THEME.field,
    BorderSizePixel = 0,
    Parent = TopBar,
})
corner(SearchFrame, 5)
stroke(SearchFrame, THEME.stroke, 1)
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
Pages = new("Frame", {
    Name = "Pages",
    Size = UDim2.new(1, -186, 1, -76),
    Position = UDim2.new(0, 178, 0, 52),
    BackgroundTransparency = 1,
    Parent = Main,
})
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
            pcall(callback)
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
                pcall(callback, v)
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
        fill.Size = UDim2.new(span > 0 and (value - min) / span or 0, 0, 1, 0)
        text.Text = show(value) .. suffix .. "/" .. show(max) .. suffix
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
function AddTab(name)
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
local GAME = {
    LobbyPlaceId = 0,
    ReplayUseButton = true,
    SendReplayLanded = false,
    TimeLabelName = "",
    TimeLabelHint = "TopbarStandard",
    UnitsFolder = "Towers",
    Remotes = {
        SkipCutscene = "SkipMapEntryCutscene",
        AutoSkip = "SetAutoSkip",
        Speed = "ChangeTickSpeed",
        Restart = "RestartGame",
        ReplayHeld = "ReplayHeld",
        ReplayLanded = "ReplayLanded",
        ReturnLobby = "BackToMainLobby",
        Beggar = "",
        Difficulty = "PlaceDifficultyVote",
        MatchEnd = "ShowGameEnd",
        PlaceUnit = "PlaceUnit",
        BuyPlot = "BuyPlot",
        ToggleAutoUpgrade = "ToggleAutoUpgrade",
        ChangeTarget = "Entity_ChangeTargetingMode",
        ActivateUnitAbility = "ActivateUnitAbility",
        Sell = "SellUnit",
    },
    Args = {
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
    Parse = {
        PlaceUnit = function(args, ctx)
            local info = args[2]
            if type(args[1]) ~= "string" or type(info) ~= "table" then return nil end
            local p, cf = info.Position, info.CF
            if typeof(p) ~= "Vector3" or typeof(cf) ~= "CFrame" then return nil end
            local r, id = ctx.result, nil
            local all = ctx.results
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
        BuyPlot = function(args)
            if type(args[1]) ~= "number" then return nil end
            return { Plot = args[1] }
        end,
    },
    ResolveUnitId = nil,
    MapSources = { "PreloadHint", "EnemyDistanceSync", "CreateEntity", "DestroyEntity", "StartDifficultyVote", "StopDifficultyVote", "ReplayLanded" },
    DifficultyIds = {
    },
    ReapplyPerMatch = true,
    ReapplyDelay = 2,
    StatNames = {
        Seeds = { "Seeds", "Seed", "Coins", "Money" },
        Wave = { "Wave", "CurrentWave" },
        Cash = { "Cash" },
        Candy = { "CurrencyHalloween26" },
    },
    EventCurrency = "CurrencyHalloween26",
    EventCurrencyTotal = "TotalCurrencyHalloween26Earned",
    EventEmoji = "🍬",
    SeedsEmoji = "🌱",
    MapNames = {
        map_farm = "Farm",
        map_halloween_event26 = "Halloween Event",
    },
    EventCurrencyLabel = "Candy",
}
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
local dataGet
do
    local mod
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
local currentMapRef
local function readStat(kind)
    local names = GAME.StatNames[kind] or {}
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
local Cfg = {
    difficulty = "Normal",
    spread = 0.3,
    microTeleport = 3,
    walkRadius = 6,
    walkMin = 4, walkMax = 9,
    telemetryUrl = "",
    discordUserId = "",
    tagTarget = true,
    tagMatch = false,
    tagDefeat = false,
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
local function bindLoop(key, interval, fn)
    return function(v)
        tokens[key] = (tokens[key] or 0) + 1
        if not v then return end
        local my = tokens[key]
        task.spawn(function()
            while alive and tokens[key] == my do
                pcall(fn)
                task.wait(interval)
            end
        end)
    end
end
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
local walkPoints = {}
local function addWalkPoint(pos)
    if typeof(pos) ~= "Vector3" then return end
    for _, q in ipairs(walkPoints) do
        if (q - pos).Magnitude < 0.5 then return end
    end
    walkPoints[#walkPoints + 1] = pos
    if #walkPoints > 200 then table.remove(walkPoints, 1) end
end
local GUID_PATTERN = "^%x+%-%x+%-%x+%-%x+%-%x+$"
local currentMap = nil
currentMapRef = function() return currentMap end
local lastMapName = nil
local triggerMatchEnd
local matchOver = false
local retired = setmetatable({}, { __mode = "k" })
local MapChanged = Instance.new("BindableEvent")
local watched = {}
local MatchMaps = setmetatable({}, { __mode = "k" })
local MATCH_EVENTS = {
    StartDifficultyVote = true, StopDifficultyVote = true, EnemyDistanceSync = true,
    CreateEntity = true, DestroyEntity = true, ReplayLanded = true,
}
local VoteOpen = setmetatable({}, { __mode = "k" })
local lastEnemyAt = 0
local function isMatchMap(m) return m ~= nil and MatchMaps[m] == true end
local ctxWatched = nil
local function isMapInstance(inst)
    if typeof(inst) ~= "Instance" then return false end
    local n = tostring(inst.Name)
    return n:match(GUID_PATTERN) ~= nil or n:match("^td_%d+$") ~= nil
end
local MatchDetected = Instance.new("BindableEvent")
local function markMatch(m)
    if isMapInstance(m) and not MatchMaps[m] then
        MatchMaps[m] = true
        MatchDetected:Fire(m)
    end
end
local function inMatch()
    return isMatchMap(currentMap) and not matchOver
end
local mapAncestryConn = nil
local function onMapSeen(inst)
    if inst == currentMap or retired[inst] or not isMapInstance(inst) then return end
    if mapAncestryConn then mapAncestryConn:Disconnect() mapAncestryConn = nil end
    currentMap = inst
    lastMapName = inst.Name
    matchOver = false
    MapChanged:Fire(inst)
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
local function watchContexts()
    local folder = workspace:FindFirstChild("Contexts")
    if not folder then return end
    if ctxWatched ~= folder then
        ctxWatched = folder
        folder.ChildAdded:Connect(function(child)
            task.defer(function()
                if not alive or not isMapInstance(child) then return end
                if currentMap and currentMap ~= child then
                    retired[currentMap] = true
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
local function findNilMap()
    if not getnilinstances then return nil end
    local found
    local ok = pcall(function()
        for _, o in ipairs(getnilinstances()) do
            if isMapInstance(o) and not retired[o] then
                if found then found = false return end
                found = o
            end
        end
    end)
    if ok and found then return found end
    return nil
end
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
local replaying = false
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
local lastReplayAt = -100
local clickGuiByText
local function doReplay(forceRemote)
    if replaying or os.clock() - lastReplayAt < 15 then return false end
    local prev = currentMap
    replaying = true
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
    local how = (GAME.ReplayUseButton and not forceRemote) and clickGuiByText({ "play again", "mainkan lagi" })
    if how then
        clicked = true
        ok = waitReplay(12)
    end
    if not ok and not clicked then
        local rfName = GAME.Remotes.Restart
        local rf = rfName and rfName ~= "" and ReplicatedStorage:FindFirstChild(rfName, true)
        local map = resolveReplayMap()
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
        retired[map] = true
        if prev then retired[prev] = true end
        local restartFailed = false
        task.spawn(function()
            local sent, res
            if rf:IsA("RemoteFunction") then
                sent, res = pcall(rf.InvokeServer, rf, map, false)
            else
                sent, res = pcall(rf.FireServer, rf, map, false)
            end
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
        ok = waitReplay(6)
        if not ok and alive then
            local held = fireRemote("ReplayHeld", map, true)
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
                end
            end)
        end
    end
    replaying = false
    if ok then
        lastReplayAt = os.clock()
        notify("Replay berjalan")
    else
        notify("Replay dikirim, tapi layar akhir match masih ada")
    end
    return ok
end
local function difficultyId(name)
    return GAME.DifficultyIds[name] or ("dif_" .. tostring(name):lower())
end
local webhookInput
local function validWebhook(url)
    if type(url) ~= "string" then return false end
    return url:match("^https://[%w]*%.?discord%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
end
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
        payload.allowed_mentions = { users = { uid } }
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
local totalMatches = 0
local Session = {
    startedAt = os.time(),
    lastResult = "-",
    lastWave = nil,
    wins = 0,
    losses = 0,
    rewards = {},
    base = {},
    matchStart = {},
    mapId = nil,
    difficulty = nil,
    avatar = nil,
}
local function totals()
    return {
        seeds = tonumber(dataGet("TotalSeedsEarned")),
        candy = tonumber(dataGet(GAME.EventCurrencyTotal)),
    }
end
task.defer(function()
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
task.spawn(function()
    pcall(function()
        local raw = game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="
            .. LocalPlayer.UserId .. "&size=150x150&format=Png&isCircular=false")
        local d = jsonDecode(raw)
        local url = d and d.data and d.data[1] and d.data[1].imageUrl
        if type(url) == "string" and url:match("^https://") then Session.avatar = url end
    end)
end)
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
local function earnedSince(base, kind)
    local now = totals()[kind]
    if now and base and base[kind] then return now - base[kind] end
    return nil
end
local function seedsEarned() return earnedSince(Session.base, "seeds") end
local function gameEndData(packed)
    if type(packed) ~= "table" then return nil end
    for i = 1, packed.n or #packed do
        if type(packed[i]) == "table" then return packed[i] end
    end
    return nil
end
local function resultText(data)
    if type(data) ~= "table" then return nil end
    if type(data.Victory) == "boolean" then return data.Victory and "Victory" or "Defeat" end
    local r = pick(data, { "Result", "result", "Status", "status" })
    return r and tostring(r) or nil
end
local selectedMacroRef
local buildMatchEmbed, buildSummaryEmbed, buildAlertEmbed
do
    local function fmtNum(n)
        n = tonumber(n)
        if not n then return "-" end
        local neg = n < 0
        local s = tostring(math.floor(math.abs(n) + 0.5))
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    local function fmtTime(sec)
        sec = tonumber(sec)
        if not sec then return "-" end
        sec = math.floor(sec)
        local h, m, x = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, x) end
        return string.format("%d:%02d", m, x)
    end
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
    function buildMatchEmbed(data, isTest, startSnap, rewardList)
        local result = resultText(data)
        local me = type(data) == "table" and type(data.PlayerData) == "table"
            and data.PlayerData[LocalPlayer.Name] or nil
        local wave = pick(data, { "WavesCleared", "Wave" }) or Session.lastWave
        local E, S = GAME.EventEmoji, GAME.SeedsEmoji
        local cur = GAME.EventCurrencyLabel
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
        local sesSeeds = earnedSince(Session.base, "seeds")
        local sesCandy = earnedSince(Session.base, "candy")
        local sessionLines = {
            fmtNum(totalMatches) .. " matches · " .. fmtNum(Session.wins) .. " wins",
            S .. " " .. fmtNum(sesSeeds) .. " seeds · " .. perHour(sesSeeds) .. "/hour",
            E .. " " .. fmtNum(sesCandy) .. " " .. cur:lower() .. " · " .. perHour(sesCandy) .. "/hour",
            "Running " .. fmtTime(os.time() - Session.startedAt),
        }
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
            footer = { text = "Ard Hub • " .. VERSION },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end
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
            footer = { text = "Ard Hub by  • " .. VERSION },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end
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
            footer = { text = "Ard Hub by  • " .. VERSION },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end
end
local Alerts = {
    cfg = {
        target = false, targetCandy = 0, targetSeeds = 0,
        summary = false, summaryMinutes = 60,
    },
    last = {},
    hit = {},
    nextSummary = nil,
}
function Alerts.send(key, title, desc, color, force, mention)
    if not force and Alerts.last[key] and os.clock() - Alerts.last[key] < 300 then return false end
    Alerts.last[key] = os.clock()
    local ok, res = pcall(sendWebhook, buildAlertEmbed(title, desc, color), mention)
    return ok and res
end
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
local httpReq = (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)
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
local function buildTelemetry(event, matchCtx)
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
local MatchEnded = Instance.new("BindableEvent")
local matchEndConnected = false
local sinceReturn = 0
local onMatchEnd
local RETURN_TEXTS = { "kembali ke lobi", "kembali ke lobby", "return to lobby", "back to lobby" }
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
    if clickGuiByText(RETURN_TEXTS) then
        local t0 = os.clock()
        while alive and os.clock() - t0 < 4 do
            task.wait(0.5)
            if not endScreenVisible() then return end
        end
    end
    if GAME.LobbyPlaceId and GAME.LobbyPlaceId > 0 then
        TeleportService:Teleport(GAME.LobbyPlaceId, LocalPlayer)
        return
    end
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
    end)
end
local lastEndAt = -100
triggerMatchEnd = function(packed)
    if os.clock() - lastEndAt < 10 then return end
    lastEndAt = os.clock()
    task.spawn(onMatchEnd, packed)
    MatchEnded:Fire()
end
task.spawn(function()
    local wasVisible = false
    while alive do
        task.wait(matchEndConnected and 8 or 1)
        if State.autoReplay or State.autoReturn or State.returnAfterX or State.webhook
            or State.recArmed or State.macroPlay or State.telemetry then
            local ok, vis = pcall(endScreenVisible)
            vis = ok and vis or false
            if vis and not wasVisible then
                task.delay(1.5, function()
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
        markMatch((...))
        triggerMatchEnd(table.pack(...))
    end)
    return true
end
onMatchEnd = function(packed)
    if not isMatchMap(currentMap) then return end
    matchOver = true
    notify("Match selesai terdeteksi")
    local data = gameEndData(packed)
    totalMatches = totalMatches + 1
    sinceReturn = sinceReturn + 1
    local wc = tonumber(pick(data, { "WavesCleared" }))
    if wc then Session.lastWave = wc end
    local result = resultText(data) or ""
    if result == "" then
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
    local wantWebhook, wantTelemetry = State.webhook, State.telemetry
    local startSnap = Session.matchStart
    Session.rewards = {}
    local rewardList = Session.rewards
    local endMap, endDifficulty = Session.mapId, Session.difficulty
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
        task.wait(1)
        for attempt = 1, 4 do
            if not (alive and State.autoReplay) then break end
            if attempt > 1 and not endScreenVisible() then break end
            lastReplayAt = -100
            if doReplay(attempt % 2 == 0) then break end
            task.wait(3)
        end
    end
end
task.spawn(function()
    while alive and not matchEndConnected do
        pcall(connectMatchEnd)
        task.wait(2)
    end
end)
local FS = HAS_FS and listfiles and true or false
local MACRO_DIR = ROOT_DIR .. "/Macros"
local selectedMacro = nil
selectedMacroRef = function() return selectedMacro end
local macroDropdown, playToggle, recordToggle
local KNOWN_TYPES = {
    PlaceUnit = true, BuyPlot = true, ToggleAutoUpgrade = true,
    ChangeTarget = true, ActivateUnitAbility = true, Sell = true,
}
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
    for i, a in ipairs(out) do a._i = i end
    table.sort(out, function(x, y)
        if x.Time ~= y.Time then return x.Time < y.Time end
        return x._i < y._i
    end)
    for _, a in ipairs(out) do a._i = nil end
    return out
end
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
local function decodeMacro(raw)
    raw = (tostring(raw):gsub("^\239\187\191", ""))
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
local recording, recArmed, recBase, recActions = false, false, 0, {}
local playing = false
local hookInstalled = false
local kindByRemoteName = {}
local recordTargets = {}
local recSeq = 0
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
local gameStartAt, mapSeenAt = nil, os.clock()
local mapSerial = 0
local GameStarted = Instance.new("BindableEvent")
MapChanged.Event:Connect(function()
    gameStartAt = nil
    mapSeenAt = os.clock()
    mapSerial = mapSerial + 1
end)
local function markStartAt(base, sig)
    if gameStartAt then return end
    gameStartAt = base
    GameStarted:Fire()
end
local clockLabel
task.spawn(function()
    for _ = 1, 60 do
        local f = ReplicatedStorage:FindFirstChild("RemoteEvents")
        local r = f and f:FindFirstChild("StopDifficultyVote")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(...)
                for _, a in ipairs({ ... }) do
                    if type(a) == "string" and a:match("^dif_") then Session.difficulty = a end
                    if type(a) == "table" then
                        for _, x in pairs(a) do
                            if type(x) == "string" and x:match("^dif_") then Session.difficulty = x end
                        end
                    end
                end
                local at = os.clock()
                task.wait(3)
                if alive and not gameStartAt and not matchOver then
                    markStartAt(at, "StopDifficultyVote")
                end
            end)
            return
        end
        task.wait(2)
    end
end)
local function parseClock(text, allowPlain)
    if type(text) ~= "string" then return nil end
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
                if clockLast and v < clockLast - 2 then gameStartAt = nil end
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
                                if v > rec.v and v - rec.v <= 10 then rec.up = rec.up + 1 end
                                rec.v = v
                            end
                            if rec.up >= (hint and 1 or 2) then
                                clockLabel, clockLast = d, v
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
                clockDumped = true
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                for _, d in ipairs(pg and pg:GetDescendants() or {}) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and GAME.TimeLabelHint ~= ""
                        and d:GetFullName():find(GAME.TimeLabelHint, 1, true) then
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
local function recordAction(kind, args, result, at, seq, resAll)
    if not recArmed then return end
    if result == false then return end
    local parse = GAME.Parse[kind]
    if not parse then return end
    if lastRec and lastRec.kind == kind and math.abs(at - lastRec.at) < 0.1 and sameArgs(lastRec.args, args) then
        return
    end
    lastRec = { kind = kind, at = at, args = args }
    if not recording then
        startRecording(mapSeenAt)
    end
    local ok, fields = pcall(parse, args, { map = currentMap, result = result, results = resAll })
    if ok and type(fields) == "table" then
        fields.Type = kind
        fields.Time = math.max(0, math.floor((at - recBase) + 0.5))
        fields._seq = seq
        fields._at = at
        table.insert(recActions, fields)
        if kind == "PlaceUnit" then
            local wp = actionPosition(fields)
            if wp then addWalkPoint(wp) end
        end
        autosave()
    else
    end
end
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
                local at = os.clock()
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
GameStarted.Event:Connect(function()
    if recArmed and not recording then startRecording(gameStartAt) end
    if recArmed and recording and gameStartAt and math.abs(recBase - gameStartAt) > 0.5 then
        recBase = gameStartAt
        for _, a in ipairs(recActions) do
            if a._at then a.Time = math.max(0, math.floor((a._at - recBase) + 0.5)) end
        end
        autosave()
    end
end)
MatchEnded.Event:Connect(function()
    gameStartAt = nil
    if recArmed then finishRecording(true) end
end)
local function randOffset(radius)
    local ang = math.random() * 2 * math.pi
    local d = radius * (0.35 + 0.65 * math.random())
    return Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
end
local onPlayToggle
do
    local CASH_WAIT = 1.5
    local progress = { serial = nil, macro = nil, index = 0, idMap = {} }
    local placeAttempt = 0
    local function findRemote(folder, name)
        local ok, r = pcall(function()
            local f = ReplicatedStorage:FindFirstChild(folder)
            return (f and f:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name, true)
        end)
        return ok and r or nil
    end
    local function invoke(r, ...)
        if not r then return false end
        local res = table.pack(pcall(r.InvokeServer, r, ...))
        return res[1], res[2], res[3]
    end
    local function teleportNear(pos)
        pcall(function()
            local hrp = getHRP()
            if not hrp then return end
            local land = pos + randOffset(math.max(Cfg.microTeleport, 1)) + Vector3.new(0, 3, 0)
            hrp.CFrame = CFrame.lookAt(land, Vector3.new(pos.X, land.Y, pos.Z))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
    end
    local function waitCashChange(ctx, limit)
        local ver, w0 = PlayerData.cashVersion, os.clock()
        task.wait(0.75)
        while not ctx.aborted() and PlayerData.cashVersion == ver and os.clock() - w0 < limit do
            task.wait(0.25)
        end
    end
    local function failKind(msg)
        local m = tostring(msg or ""):lower()
        if m:find("cash") or m:find("money") or m:find("afford") then return "cash" end
        if m:find("right now") then return "notready" end
        if m:find("limit") or m:find("max") then return "limit" end
        return "position"
    end
    local function placeUnit(act, ctx)
        if act.Valid == false then return end
        local pos, cf = actionPosition(act), actionCFrame(act)
        if not pos then
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
                CF = cf + offset,
            }
            if act.PathIndex then info.PathIndex = act.PathIndex end
            if act.DistanceAlongPath then info.DistanceAlongPath = act.DistanceAlongPath end
            local sent, ok, res = invoke(r, act.Unit, info)
            if sent and ok == true then
                if act.ID and type(res) == "number" then ctx.idMap[act.ID] = res end
                addWalkPoint(info.Position)
                return "placed"
            end
            local kind = (sent and ok == false and res ~= nil) and failKind(res) or "notready"
            tries = tries + 1
            local why = not sent and ("error: " .. tostring(ok))
                or (ok == false and res ~= nil) and tostring(res)
                or ("tanpa jawaban server (" .. tostring(ok) .. ", " .. tostring(res) .. ")")
            if kind ~= "cash" and (tries == 1 or tries % 10 == 0) then
            end
            if kind == "cash" then
                local cash = PlayerData.values.Cash
                setPlayStatus(string.format("Playing macro: menunggu cash untuk %s%s", tostring(act.Unit),
                    cash and (" (cash " .. tostring(cash) .. ")") or ""))
                waitCashChange(ctx, CASH_WAIT * 2)
            elseif kind == "notready" then
                setPlayStatus("Playing macro: belum bisa menaruh " .. tostring(act.Unit) .. " (" .. why .. "), mencoba lagi")
                if ctx.midStart and (act.Time or 0) < ctx.startElapsed and tries >= 10 then
                    if act.ID then ctx.idMap[act.ID] = false end
                    return "skipped"
                end
                task.wait(1)
            else
                if ctx.midStart and (act.Time or 0) < ctx.startElapsed and tries >= 6 then
                    if act.ID then ctx.idMap[act.ID] = false end
                    return "skipped"
                end
                setPlayStatus("Playing macro: " .. tostring(act.Unit) .. " ditolak (" .. tostring(res) .. "), mencoba lagi")
                if (Cfg.spread or 0) > 0 and tries % 2 == 1 then
                    offset = randOffset(math.min(Cfg.spread * (1 + math.floor(tries / 8) * 0.25), 2))
                else
                    offset = Vector3.zero
                end
                task.wait(math.min(0.5 + tries * 0.1, 2))
            end
        end
        if act.ID then ctx.idMap[act.ID] = false end
    end
    local function unitAction(act, ctx)
        local id = act.ID
        if id ~= nil then
            local mapped = ctx.idMap[id]
            if mapped == false then return end
            id = mapped or id
        end
        if act.Type == "ToggleAutoUpgrade" then
            local r = findRemote("RemoteFunctions", GAME.Remotes.ToggleAutoUpgrade)
            local sent, ok, state = invoke(r, id)
            if sent and ok == true and state == false then
                task.wait(0.3)
                invoke(r, id)
            end
        elseif act.Type == "ChangeTarget" then
            local r = findRemote("RemoteEvents", GAME.Remotes.ChangeTarget)
            if r then pcall(r.FireServer, r, id, act.TargetMode) end
        elseif act.Type == "Sell" then
            local r = findRemote("RemoteFunctions", GAME.Remotes.Sell)
            if r and r:IsA("RemoteFunction") then invoke(r, id)
            elseif r then pcall(r.FireServer, r, id) end
        elseif act.Type == "ActivateUnitAbility" then
            local r = findRemote("RemoteFunctions", GAME.Remotes.ActivateUnitAbility)
            if not r then return end
            local t0 = os.clock()
            while not ctx.aborted() do
                local sent, ok, res = invoke(r, id, nil)
                if sent and ok == false and failKind(res) == "cash" then
                    if os.clock() - t0 > 60 then break end
                    setPlayStatus("Playing macro: menunggu cash untuk ability")
                    waitCashChange(ctx, CASH_WAIT * 2)
                elseif sent and ok == true and res == false then
                    if os.clock() - t0 > 15 then break end
                    task.wait(1)
                else
                    break
                end
            end
        elseif act.Type == "BuyPlot" then
            local r = findRemote("RemoteEvents", GAME.Remotes.BuyPlot)
            if not (r and act.Plot) then return end
            local t0 = os.clock()
            while not ctx.aborted() do
                local before = tonumber(PlayerData.values.Cash)
                pcall(r.FireServer, r, act.Plot)
                if not before then break end
                local w0 = os.clock()
                while os.clock() - w0 < 2 and (tonumber(PlayerData.values.Cash) or before) >= before do
                    task.wait(0.2)
                end
                if (tonumber(PlayerData.values.Cash) or before) < before then
                    break
                end
                if os.clock() - t0 > 120 then
                    break
                end
                setPlayStatus("Playing macro: menunggu cash untuk plot " .. tostring(act.Plot))
                waitCashChange(ctx, CASH_WAIT * 2)
            end
        end
    end
    local function runMatch(token, serial)
        local actions = loadMacro(selectedMacro)
        if not actions then
            notify("Macro tidak ditemukan, pilih macro dulu")
            return "missing"
        end
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
        setPlayStatus("Playing macro: menunggu game mulai")
        local w0 = os.clock()
        local midGame, midSince = false, nil
        while not ctx.aborted() and not gameStartAt do
            local now = os.clock()
            local voting = currentMap and VoteOpen[currentMap]
            if not midGame and not voting
                and (now - mapSeenAt > 8 or (lastEnemyAt > 0 and now - lastEnemyAt < 5)) then
                midGame, midSince = true, now
                setPlayStatus("Playing macro: game sudah berjalan, membaca timer...")
            end
            if midGame and now - midSince >= 6 then break end
            if now - w0 >= 90 then break end
            task.wait(0.25)
        end
        if ctx.aborted() then return "aborted" end
        local t0 = gameStartAt or (midGame and mapSeenAt) or os.clock()
        ctx.startElapsed = os.clock() - t0
        ctx.midStart = resume or ctx.startElapsed > 5
        if resume then
        elseif ctx.midStart then
        end
        playing = true
        for i, act in ipairs(actions) do
            if ctx.aborted() then break end
            if i <= progress.index then continue end
            while not ctx.aborted() and os.clock() - t0 < (act.Time or 0) do
                setPlayStatus(string.format("Playing macro: %s  [%d/%d]  aksi berikut %ds",
                    tostring(selectedMacro), i, #actions, math.max(0, math.ceil(act.Time - (os.clock() - t0)))))
                task.wait(0.2)
            end
            if ctx.aborted() then break end
            setPlayStatus(string.format("Playing macro: %s  [%d/%d]  %s", tostring(selectedMacro), i, #actions, act.Type))
            local ok, res = pcall(act.Type == "PlaceUnit" and placeUnit or unitAction, act, ctx)
            if res == "placed" or res == "skipped" or not ctx.aborted() then progress.index = i end
            task.wait(0.15)
        end
        playing = false
        if not ctx.aborted() then
            setPlayStatus("Playing macro: " .. tostring(selectedMacro) .. "  [selesai, menunggu match berikutnya]")
        end
        return "done"
    end
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
                if isMatchMap(currentMap) and not matchOver and mapSerial ~= played then
                    played = mapSerial
                    local ok, res = pcall(runMatch, token, played)
                    if res == "missing" then break end
                else
                    if not isMatchMap(currentMap) then setPlayStatus("Playing macro: menunggu match") end
                    task.wait(0.5)
                end
            end
            if tokens.play == token then
                State.macroPlay = false
                playing = false
                setPlayStatus(nil)
                if playToggle then playToggle:Set(false, true) end
            end
        end)
    end
end
local setLowPerformance, installPlaceWatch, walkLoop
do
local origMat = setmetatable({}, { __mode = "k" })
local lowConn
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
local walkIdx = 0
local function walkStep()
    if not inMatch() then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
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
    if #list == 0 then
        walkIdx = 0
        return
    end
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
            pcall(walkStep)
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
end
local function buildUI()
local tMatch = AddTab("Match")
local sMatch = tMatch:AddSection("Match", "left")
local speedValue = nil
local function applySpeed()
    if speedValue then fireRemote("Speed", speedValue) end
end
local function applyMatchSettings()
    if not inMatch() then return end
    if State.skipCutscene then fireRemote("SkipCutscene") end
    if State.autoSkipWave then fireRemote("AutoSkip", true) end
    applySpeed()
end
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
local abilityLoop = bindLoop("autoAbility", 10, function()
    if not inMatch() then return end
    local build = GAME.Args.ActivateUnitAbility
    if not build then
        notifyOnce("args_auto_ability", "GAME.Args.ActivateUnitAbility belum diisi")
        return
    end
    for _, u in ipairs(getUnits()) do
        local id = u:GetAttribute("ID") or tonumber(u.Name)
        if id then
            callWithArgs("ActivateUnitAbility", build({ Type = "ActivateUnitAbility", ID = id }, { map = currentMap, id = id }))
            task.wait(0.15 + math.random() * 0.25)
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
    elseif endScreenVisible() then
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
    if v then fireRemote("Beggar") end
end)
local sPerf = tMatch:AddSection("Performance", "right")
Flag("no3d", sPerf:AddToggle("Disable 3D Rendering", false, function(v)
    pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end), "toggle")
Flag("lowPerf", sPerf:AddToggle("Enable Low Performance", false, setLowPerformance), "toggle")
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
        if n > 0 then end
    end)
end)
Flag("cleanOldMaps", sPerf:AddToggle("Clean Old Maps", false, function(v)
    cleanOldMaps = v
    if v and not getnilinstances then notify("Executor tidak mendukung getnilinstances") end
end), "toggle")
sPerf:AddLabel("Clean Old Maps: hapus map match sebelumnya dari memori (cegah crash saat farming lama).")
local tAuto = AddTab("Auto Mode")
local sLobby = tAuto:AddSection("Lobby", "left")
local votedMaps = setmetatable({}, { __mode = "k" })
local function voteDifficulty(map, reason)
    if not State.autoDiff then return end
    if typeof(map) ~= "Instance" or votedMaps[map] then return end
    if not isMatchMap(map) then return end
    votedMaps[map] = true
    task.delay(1, function()
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
        if ok then
            notify("Vote difficulty: " .. Cfg.difficulty)
            Session.difficulty = diff
        end
    end)
end
Flag("difficulty", sLobby:AddDropdown("Difficulty", {
    "Easy", "Normal", "Hard", "Insane", "Impossible", "Apocalypse", "Hell",
}, Cfg.difficulty, function(v)
    Cfg.difficulty = v
end))
Flag("autoDiff", sLobby:AddToggle("Auto Difficulty", false, function(v)
    State.autoDiff = v
    if v and currentMap and VoteOpen[currentMap] and not matchOver then
        voteDifficulty(currentMap, "toggle on")
    end
end), "toggle")
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
    task.wait(3)
    if not voteEventConnected and isMatchMap(map) then voteDifficulty(map, "map baru") end
end)
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
        local path = raw:gsub("[?#].*$", "")
        local last = path:match("([^/]+)$") or ""
        last = last:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        last = last:gsub("%.%w+$", "")
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
local tAnti = AddTab("Anti Ban")
local sAnti = tAnti:AddSection("Anti Ban", "left")
sAnti:AddLabel("Mengurangi pola gerakan robotik. Tidak ada jaminan 100% bebas deteksi.")
Flag("spread", sAnti:AddSlider("Placement Spread", 0, 2, Cfg.spread, " studs", function(v)
    Cfg.spread = v
end, 0.1))
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
Flag("discordUserId", sHook:AddInput("Discord User ID (untuk tag)", "mis. 123456789012345678", "", function(t)
    Cfg.discordUserId = (tostring(t):gsub("%D", ""))
end, true), "input")
Flag("tagMatch", sHook:AddToggle("Tag di Setiap Akhir Match", false, function(v) Cfg.tagMatch = v end), "toggle")
Flag("tagDefeat", sHook:AddToggle("Tag Hanya Saat Defeat", false, function(v) Cfg.tagDefeat = v end), "toggle")
sHook:AddLabel("User ID: Discord > Settings > Advanced > Developer Mode ON, lalu klik kanan namamu > Copy User ID.")
local sTarget = tHook:AddSection("Target", "left")
Flag("alertTarget", sTarget:AddToggle("Kirim Saat Target Tercapai", false, function(v) Alerts.cfg.target = v end), "toggle")
Flag("alertTargetSeeds", sTarget:AddInput("Target Seeds (sesi)", "0 = mati", "", function(t)
    Alerts.cfg.targetSeeds = tonumber(t) or 0
    Alerts.hit.seeds = nil
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
local sSum = tHook:AddSection("Ringkasan Berkala", "right")
Flag("summary", sSum:AddToggle("Kirim Ringkasan", false, function(v)
    Alerts.cfg.summary = v
    Alerts.nextSummary = nil
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
local savedMacro = SavedConfig.selectedMacro
refreshMacros(type(savedMacro) == "string" and savedMacro or nil)
configLoading = true
pcall(function()
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
