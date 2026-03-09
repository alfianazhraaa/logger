--[[
  MOTION LOGGER PRO
  Records movement, clicks, jumps, tool use
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

pcall(function()
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g.Name == "MLPro" then g:Destroy() end
    end
end)

-- ══════════════════════════════
-- LOG SYSTEM
-- ══════════════════════════════
local logs = {}
local recording = false
local startTime = 0
local lastPos = nil
local MIN_MOVE = 1.5 -- minimum stud movement to log

local function timestamp()
    return string.format("%.2f", tick() - startTime)
end

local function addLog(type_, data)
    if not recording then return end
    local entry = {
        t    = timestamp(),
        type = type_,
        data = data
    }
    table.insert(logs, entry)
end

local function fmtPos(v3)
    if not v3 then return "nil" end
    return string.format("(%.1f, %.1f, %.1f)", v3.X, v3.Y, v3.Z)
end

-- ══════════════════════════════
-- WATCHERS
-- ══════════════════════════════
local connections = {}

local function startWatching()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart", 5)
    local hum  = char:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end

    -- POSITION TRACKER (every 0.2s)
    local posConn = RunService.Heartbeat:Connect(function()
        if not recording then return end
        local pos = hrp.Position
        if not lastPos or (pos - lastPos).Magnitude >= MIN_MOVE then
            addLog("MOVE", {
                pos   = fmtPos(pos),
                state = tostring(hum:GetState())
            })
            lastPos = pos
        end
    end)
    table.insert(connections, posConn)

    -- JUMP
    local jumpConn = hum.Jumping:Connect(function(active)
        if active then
            addLog("JUMP", {pos = fmtPos(hrp.Position)})
        end
    end)
    table.insert(connections, jumpConn)

    -- STATE CHANGE
    local stateConn = hum.StateChanged:Connect(function(old, new)
        local skip = {
            [Enum.HumanoidStateType.RunningNoPhysics] = true,
            [Enum.HumanoidStateType.Running] = true,
        }
        if not skip[new] then
            addLog("STATE", {
                from = tostring(old),
                to   = tostring(new),
                pos  = fmtPos(hrp.Position)
            })
        end
    end)
    table.insert(connections, stateConn)

    -- TOOL EQUIPPED
    local toolConn = char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            addLog("TOOL_EQUIP", {name = child.Name, pos = fmtPos(hrp.Position)})
        end
    end)
    table.insert(connections, toolConn)

    local toolRConn = char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            addLog("TOOL_UNEQUIP", {name = child.Name})
        end
    end)
    table.insert(connections, toolRConn)
end

local function stopWatching()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}
end

-- MOUSE CLICK
local clickConn
local function watchClicks()
    if clickConn then pcall(function() clickConn:Disconnect() end) end
    clickConn = UIS.InputBegan:Connect(function(inp, gpe)
        if not recording then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            addLog("CLICK_L", {
                pos    = fmtPos(hrp and hrp.Position),
                screen = string.format("(%d, %d)", inp.Position.X, inp.Position.Y)
            })
        elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
            addLog("CLICK_R", {
                screen = string.format("(%d, %d)", inp.Position.X, inp.Position.Y)
            })
        elseif inp.UserInputType == Enum.UserInputType.Touch then
            addLog("TOUCH", {
                screen = string.format("(%d, %d)", inp.Position.X, inp.Position.Y)
            })
        elseif inp.UserInputType == Enum.UserInputType.Keyboard then
            local key = tostring(inp.KeyCode):gsub("Enum.KeyCode.","")
            if key ~= "Unknown" then
                addLog("KEY", {key = key})
            end
        end
    end)
end

-- PROXIMITY PROMPT
local function watchPrompts()
    local function hookPrompt(pp)
        local c = pp.Triggered:Connect(function(p)
            if p == player then
                addLog("PROMPT", {name = pp.ActionText, obj = pp.Parent and pp.Parent.Name or "?"})
            end
        end)
        table.insert(connections, c)
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then hookPrompt(v) end
    end
    local wc = workspace.DescendantAdded:Connect(function(v)
        if v:IsA("ProximityPrompt") then hookPrompt(v) end
    end)
    table.insert(connections, wc)
end

-- ══════════════════════════════
-- EXPORT LOG
-- ══════════════════════════════
local function buildExport()
    if #logs == 0 then return "-- No logs recorded." end

    local lines = {}
    table.insert(lines, "-- ═══════════════════════════════════════════")
    table.insert(lines, "-- MOTION LOG  |  " .. #logs .. " events  |  " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "-- ═══════════════════════════════════════════")
    table.insert(lines, "")

    -- Group summary
    local counts = {}
    for _, e in ipairs(logs) do
        counts[e.type] = (counts[e.type] or 0) + 1
    end
    table.insert(lines, "-- SUMMARY:")
    for k, v in pairs(counts) do
        table.insert(lines, string.format("--   %-16s %d events", k, v))
    end
    table.insert(lines, "")
    table.insert(lines, "-- RAW LOG:")
    table.insert(lines, "local motionLog = {")

    for _, e in ipairs(logs) do
        local parts = {}
        for k, v in pairs(e.data) do
            table.insert(parts, k..'="'..tostring(v)..'"')
        end
        table.insert(lines, string.format(
            '  {t="%s", type="%s", %s},',
            e.t, e.type, table.concat(parts, ", ")
        ))
    end

    table.insert(lines, "}")
    table.insert(lines, "")
    table.insert(lines, "-- REPLAY SCRIPT:")
    table.insert(lines, "local Players = game:GetService('Players')")
    table.insert(lines, "local player = Players.LocalPlayer")
    table.insert(lines, "task.spawn(function()")
    table.insert(lines, "  local char = player.Character or player.CharacterAdded:Wait()")
    table.insert(lines, "  local hrp  = char:WaitForChild('HumanoidRootPart')")
    table.insert(lines, "  local prevT = 0")
    table.insert(lines, "  for _, e in ipairs(motionLog) do")
    table.insert(lines, "    local dt = tonumber(e.t) - prevT")
    table.insert(lines, "    if dt > 0 then task.wait(dt) end")
    table.insert(lines, "    prevT = tonumber(e.t)")
    table.insert(lines, "    if e.type == 'MOVE' then")
    table.insert(lines, "      local x,y,z = e.pos:match('%((.+), (.+), (.+)%)')")
    table.insert(lines, "      if x then hrp.CFrame = CFrame.new(tonumber(x),tonumber(y)+5,tonumber(z)) end")
    table.insert(lines, "    elseif e.type == 'JUMP' then")
    table.insert(lines, "      local hum = char:FindFirstChildOfClass('Humanoid')")
    table.insert(lines, "      if hum then hum.Jump = true end")
    table.insert(lines, "    end")
    table.insert(lines, "  end")
    table.insert(lines, "end)")

    return table.concat(lines, "\n")
end

-- ══════════════════════════════
-- GUI
-- ══════════════════════════════
local BK = Color3.fromRGB(8,8,8)
local DK = Color3.fromRGB(16,16,16)
local CD = Color3.fromRGB(24,24,24)
local BD = Color3.fromRGB(40,40,40)
local W1 = Color3.fromRGB(220,220,220)
local G1 = Color3.fromRGB(70,70,70)
local GR = Color3.fromRGB(80,200,100)
local RD = Color3.fromRGB(210,70,70)
local YL = Color3.fromRGB(220,190,60)
local AC = Color3.fromRGB(140,140,255)

local function cr(p,r) local u=Instance.new("UICorner",p) u.CornerRadius=UDim.new(0,r or 7) end
local function sk(p,c,t) local s=Instance.new("UIStroke",p) s.Color=c or BD s.Thickness=t or 1 end

local sg = Instance.new("ScreenGui")
sg.Name           = "MLPro"
sg.ResetOnSpawn   = false
sg.DisplayOrder   = 9999
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = player.PlayerGui

-- MAIN
local F = Instance.new("Frame", sg)
F.Size             = UDim2.new(0, 250, 0, 420)
F.Position         = UDim2.new(0, 16, 0, 70)
F.BackgroundColor3 = BK
F.BorderSizePixel  = 0
F.Active           = true
F.Draggable        = true
F.ZIndex           = 10
cr(F, 10) sk(F, BD, 1)

-- TOP BAR
local TB = Instance.new("Frame", F)
TB.Size             = UDim2.new(1,0,0,36)
TB.BackgroundColor3 = DK
TB.BorderSizePixel  = 0
TB.ZIndex           = 11
cr(TB, 10)
local TBF = Instance.new("Frame", TB)
TBF.Size            = UDim2.new(1,0,0,10)
TBF.Position        = UDim2.new(0,0,1,-10)
TBF.BackgroundColor3= DK
TBF.BorderSizePixel = 0
TBF.ZIndex          = 11

local Dot = Instance.new("Frame", TB)
Dot.Size            = UDim2.new(0,6,0,6)
Dot.Position        = UDim2.new(0,10,0.5,-3)
Dot.BackgroundColor3= RD
Dot.BorderSizePixel = 0
Dot.ZIndex          = 12
cr(Dot, 6)

local TLbl = Instance.new("TextLabel", TB)
TLbl.Size               = UDim2.new(1,-50,1,0)
TLbl.Position           = UDim2.new(0,22,0,0)
TLbl.BackgroundTransparency = 1
TLbl.Text               = "MOTION LOGGER"
TLbl.TextColor3         = W1
TLbl.Font               = Enum.Font.GothamBold
TLbl.TextSize           = 12
TLbl.TextXAlignment     = Enum.TextXAlignment.Left
TLbl.ZIndex             = 12

local XB = Instance.new("TextButton", TB)
XB.Size             = UDim2.new(0,22,0,22)
XB.Position         = UDim2.new(1,-26,0.5,-11)
XB.Text             = "✕"
XB.TextColor3       = G1
XB.BackgroundColor3 = CD
XB.Font             = Enum.Font.GothamBold
XB.TextSize         = 10
XB.BorderSizePixel  = 0
XB.ZIndex           = 12
cr(XB, 5)
XB.MouseButton1Click:Connect(function() sg:Destroy() end)

-- STAT ROW
local function statLabel(xPct, labelTxt)
    local box = Instance.new("Frame", F)
    box.Size            = UDim2.new(0.3, -4, 0, 36)
    box.Position        = UDim2.new(xPct, 2, 0, 44)
    box.BackgroundColor3= CD
    box.BorderSizePixel = 0
    box.ZIndex          = 11
    cr(box, 6) sk(box, BD, 1)

    local top = Instance.new("TextLabel", box)
    top.Size                = UDim2.new(1,0,0,14)
    top.Position            = UDim2.new(0,0,0,4)
    top.BackgroundTransparency = 1
    top.Text                = labelTxt
    top.TextColor3          = G1
    top.Font                = Enum.Font.Gotham
    top.TextSize            = 8
    top.TextXAlignment      = Enum.TextXAlignment.Center
    top.ZIndex              = 12

    local val = Instance.new("TextLabel", box)
    val.Size                = UDim2.new(1,0,0,16)
    val.Position            = UDim2.new(0,0,0,18)
    val.BackgroundTransparency = 1
    val.Text                = "0"
    val.TextColor3          = W1
    val.Font                = Enum.Font.GothamBold
    val.TextSize            = 13
    val.TextXAlignment      = Enum.TextXAlignment.Center
    val.ZIndex              = 12
    return val
end

local statEvents = statLabel(0,    "EVENTS")
local statTime   = statLabel(0.34, "DURASI")
local statMoves  = statLabel(0.67, "MOVES")

-- RECORD BUTTON
local RecBtn = Instance.new("TextButton", F)
RecBtn.Size             = UDim2.new(1,-20,0,36)
RecBtn.Position         = UDim2.new(0,10,0,88)
RecBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
RecBtn.Text             = "⏺  MULAI REKAM"
RecBtn.TextColor3       = W1
RecBtn.Font             = Enum.Font.GothamBold
RecBtn.TextSize         = 13
RecBtn.BorderSizePixel  = 0
RecBtn.ZIndex           = 11
cr(RecBtn, 8) sk(RecBtn, BD, 1)

-- CLEAR + COPY ROW
local function smallBtn(xPct, txt, w, col)
    local b = Instance.new("TextButton", F)
    b.Size              = UDim2.new(w, -6, 0, 26)
    b.Position          = UDim2.new(xPct, 3, 0, 132)
    b.BackgroundColor3  = col or CD
    b.Text              = txt
    b.TextColor3        = W1
    b.Font              = Enum.Font.GothamBold
    b.TextSize          = 10
    b.BorderSizePixel   = 0
    b.ZIndex            = 11
    cr(b, 6) sk(b, BD, 1)
    return b
end
local ClearBtn = smallBtn(0,    "🗑  CLEAR",  0.33, Color3.fromRGB(60,20,20))
local CopyBtn  = smallBtn(0.34, "📋  COPY LOG", 0.66, Color3.fromRGB(20,50,20))

-- FILTER CHECKBOXES
local filterY = 166
local function mkCheck(y, label, default)
    local row = Instance.new("Frame", F)
    row.Size             = UDim2.new(1,-20,0,20)
    row.Position         = UDim2.new(0,10,0,y)
    row.BackgroundTransparency = 1
    row.ZIndex           = 11

    local box = Instance.new("TextButton", row)
    box.Size             = UDim2.new(0,16,0,16)
    box.Position         = UDim2.new(0,0,0.5,-8)
    box.BackgroundColor3 = default and AC or CD
    box.Text             = default and "✓" or ""
    box.TextColor3       = BK
    box.Font             = Enum.Font.GothamBold
    box.TextSize         = 10
    box.BorderSizePixel  = 0
    box.ZIndex           = 12
    cr(box, 4) sk(box, BD, 1)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(1,-22,1,0)
    lbl.Position         = UDim2.new(0,20,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = G1
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 10
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 11

    local on = default
    box.MouseButton1Click:Connect(function()
        on = not on
        box.BackgroundColor3 = on and AC or CD
        box.Text             = on and "✓" or ""
    end)
    return function() return on end
end

local getMove  = mkCheck(filterY,    "Log Gerakan (MOVE)",   true)
local getClick = mkCheck(filterY+22, "Log Klik / Touch",     true)
local getKey   = mkCheck(filterY+44, "Log Keyboard",         false)
local getState = mkCheck(filterY+66, "Log State (jump/fall)",true)
local getTool  = mkCheck(filterY+88, "Log Tool",             true)
local getProm  = mkCheck(filterY+110,"Log Proximity Prompt", true)

-- DIVIDER
local DivL = Instance.new("Frame", F)
DivL.Size             = UDim2.new(1,-20,0,1)
DivL.Position         = UDim2.new(0,10,0,filterY+136)
DivL.BackgroundColor3 = BD
DivL.BorderSizePixel  = 0
DivL.ZIndex           = 11

-- LIVE LOG SCROLL
local LHdr = Instance.new("TextLabel", F)
LHdr.Size               = UDim2.new(1,-20,0,14)
LHdr.Position           = UDim2.new(0,10,0,filterY+142)
LHdr.BackgroundTransparency = 1
LHdr.Text               = "LIVE LOG"
LHdr.TextColor3         = Color3.fromRGB(45,45,45)
LHdr.Font               = Enum.Font.GothamBold
LHdr.TextSize           = 9
LHdr.TextXAlignment     = Enum.TextXAlignment.Left
LHdr.ZIndex             = 11

local liveScroll = Instance.new("ScrollingFrame", F)
liveScroll.Size             = UDim2.new(1,-20,0,420-(filterY+158)-10)
liveScroll.Position         = UDim2.new(0,10,0,filterY+158)
liveScroll.BackgroundColor3 = DK
liveScroll.BorderSizePixel  = 0
liveScroll.ScrollBarThickness = 2
liveScroll.ScrollBarImageColor3 = BD
liveScroll.CanvasSize       = UDim2.new(0,0,0,0)
liveScroll.ZIndex           = 11
cr(liveScroll, 6) sk(liveScroll, BD, 1)

local liveLayout = Instance.new("UIListLayout", liveScroll)
liveLayout.SortOrder  = Enum.SortOrder.LayoutOrder
liveLayout.Padding    = UDim.new(0,1)
local livePad = Instance.new("UIPadding", liveScroll)
livePad.PaddingTop    = UDim.new(0,4)
livePad.PaddingLeft   = UDim.new(0,4)
livePad.PaddingRight  = UDim.new(0,4)
livePad.PaddingBottom = UDim.new(0,4)

liveLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    liveScroll.CanvasSize = UDim2.new(0,0,0,liveLayout.AbsoluteContentSize.Y+8)
end)

local liveCount = 0
local TYPE_COLOR = {
    MOVE        = Color3.fromRGB(80,80,80),
    JUMP        = Color3.fromRGB(80,180,255),
    CLICK_L     = Color3.fromRGB(200,200,80),
    CLICK_R     = Color3.fromRGB(180,140,60),
    TOUCH       = Color3.fromRGB(200,200,80),
    KEY         = Color3.fromRGB(160,160,255),
    STATE       = Color3.fromRGB(120,120,140),
    TOOL_EQUIP  = Color3.fromRGB(80,220,160),
    TOOL_UNEQUIP= Color3.fromRGB(180,100,100),
    PROMPT      = Color3.fromRGB(220,150,80),
}

local function pushLive(entry)
    -- respect filters
    local t = entry.type
    if t == "MOVE"         and not getMove()  then return end
    if (t == "CLICK_L" or t == "CLICK_R" or t == "TOUCH") and not getClick() then return end
    if t == "KEY"          and not getKey()   then return end
    if t == "STATE"        and not getState() then return end
    if (t == "TOOL_EQUIP" or t == "TOOL_UNEQUIP") and not getTool() then return end
    if t == "PROMPT"       and not getProm()  then return end

    liveCount = liveCount + 1

    -- build display text
    local parts = {}
    for k,v in pairs(entry.data) do
        table.insert(parts, k..":"..tostring(v))
    end
    local line = string.format("[%ss] %s  %s", entry.t, entry.type, table.concat(parts,"  "))

    local lbl = Instance.new("TextLabel", liveScroll)
    lbl.LayoutOrder         = liveCount
    lbl.Size                = UDim2.new(1,0,0,16)
    lbl.BackgroundTransparency = 1
    lbl.Text                = line
    lbl.TextColor3          = TYPE_COLOR[t] or W1
    lbl.Font                = Enum.Font.Code
    lbl.TextSize            = 9
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.ZIndex              = 12
    lbl.TextTruncate        = Enum.TextTruncate.AtEnd

    -- auto scroll to bottom
    task.defer(function()
        liveScroll.CanvasPosition = Vector2.new(0, liveLayout.AbsoluteContentSize.Y)
    end)
end

-- ══════════════════════════════
-- TIMER UPDATE
-- ══════════════════════════════
local timerConn
local moveCount = 0

local origAdd = addLog
addLog = function(type_, data)
    origAdd(type_, data)
    local entry = logs[#logs]
    if not entry then return end
    -- update stats
    statEvents.Text = tostring(#logs)
    if type_ == "MOVE" then
        moveCount = moveCount + 1
        statMoves.Text = tostring(moveCount)
    end
    pushLive(entry)
end

-- ══════════════════════════════
-- RECORD TOGGLE
-- ══════════════════════════════
RecBtn.MouseButton1Click:Connect(function()
    recording = not recording
    if recording then
        startTime  = tick()
        moveCount  = 0
        lastPos    = nil
        RecBtn.Text             = "⏹  BERHENTI"
        RecBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        Dot.BackgroundColor3    = GR

        startWatching()
        watchClicks()
        watchPrompts()

        -- timer tick
        timerConn = RunService.Heartbeat:Connect(function()
            if recording then
                statTime.Text = string.format("%.1fs", tick()-startTime)
            end
        end)
    else
        recording = false
        RecBtn.Text             = "⏺  MULAI REKAM"
        RecBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
        Dot.BackgroundColor3    = RD
        stopWatching()
        if timerConn then timerConn:Disconnect() end
    end
end)

-- CLEAR
ClearBtn.MouseButton1Click:Connect(function()
    logs = {}
    moveCount = 0
    statEvents.Text = "0"
    statTime.Text   = "0"
    statMoves.Text  = "0"
    for _, c in ipairs(liveScroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    liveCount = 0
end)

-- COPY
CopyBtn.MouseButton1Click:Connect(function()
    local export = buildExport()
    -- Write to clipboard via executor
    local ok = pcall(function() setclipboard(export) end)
    if not ok then
        pcall(function() toclipboard(export) end)
    end
    CopyBtn.Text = "✓  TERSALIN!"
    CopyBtn.BackgroundColor3 = Color3.fromRGB(20,80,20)
    task.delay(2, function()
        CopyBtn.Text = "📋  COPY LOG"
        CopyBtn.BackgroundColor3 = Color3.fromRGB(20,50,20)
    end)
end)

-- F9
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F9 then
        F.Visible = not F.Visible
    end
end)

print("✅ Motion Logger Pro | F9 toggle")
