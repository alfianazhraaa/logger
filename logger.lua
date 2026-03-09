--[[
  AUTO CLAIM GOPAY — ALL MOUNTAIN
  BY ALFIAN
  Talamau · Raja Ampat · Mount Seru · Mount Zihan
]]

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local player     = Players.LocalPlayer

pcall(function()
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g.Name == "ACGAlfian" then g:Destroy() end
    end
end)

-- ══════════════════════════════════════════
-- ANTI-LAG
-- ══════════════════════════════════════════
local antilagOn = false
local function applyAntiLag()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
    pcall(function() workspace.GlobalShadows = false end)
    pcall(function() settings().Rendering.MaxFrameRate = 15 end)
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows = false; L.Brightness = 1
        L.EnvironmentDiffuseScale = 0; L.EnvironmentSpecularScale = 0
        for _, v in ipairs(L:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or
               v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or
               v:IsA("DepthOfFieldEffect") then v.Enabled = false end
        end
    end)
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire") or
               v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") then
                v.Enabled = false
            end
            if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
        end
    end)
end

-- ══════════════════════════════════════════
-- MOUNTAIN DATA
-- ══════════════════════════════════════════
local MOUNTAINS = {
    {
        id      = "talamau",
        name    = "TALAMAU",
        icon    = "🏔",
        status  = "Online",
        -- GoPay claim point dari session log
        target  = Vector3.new(-527.5, 1062.0, 333.4),
        near    = Vector3.new(-527.5, 1062.0, 341.4),
        mode    = "gopay", -- teleport + fire prompt
        -- nama objek dari log
        objName = "RedemptionPointBasepart",
        promptPattern = {"claim","voucher","gopay","redeem"},
    },
    {
        id      = "rajaampat",
        name    = "RAJA AMPAT",
        icon    = "🏝",
        status  = "Online",
        -- summit → basecamp sequence
        summit  = Vector3.new(-658.5, 609.1, -2879.3),
        basecamp= Vector3.new(-1627.0, 65.1, -1355.8),
        mode    = "summit",
        promptPattern = {"basecamp","base","kembali"},
    },
    {
        id      = "seru",
        name    = "MOUNT SERU",
        icon    = "⛰",
        status  = "Online",
        -- dari log: posisi sebelum prompt "Interact" di obj "Gopay"
        target  = Vector3.new(-3498.8, 640.3, 376.1),
        near    = Vector3.new(-3498.8, 640.3, 384.1),
        mode    = "gopay",
        objName = "Gopay",
        promptPattern = {"interact","claim","voucher","gopay"},
    },
    {
        id      = "zihan",
        name    = "MOUNT ZIHAN",
        icon    = "🗻",
        status  = "Online",
        mode    = "multi", -- 4 peti
        peti = {
            {label="PETI 1", pos=Vector3.new(9800.3,2945.9,-21525.8), near=Vector3.new(9800.3,2945.9,-21517.8)},
            {label="PETI 2", pos=Vector3.new(9876.8,2953.1,-21564.6), near=Vector3.new(9876.8,2953.1,-21556.6)},
            {label="PETI 3", pos=Vector3.new(9938.1,2952.4,-21551.0), near=Vector3.new(9938.1,2952.4,-21543.0)},
            {label="PETI 4", pos=Vector3.new(10057.2,2954.7,-21546.0),near=Vector3.new(10057.2,2954.7,-21538.0)},
        },
        promptPattern = {"claim","voucher","interact","gopay"},
        objName = "Primary",
    },
}

-- ══════════════════════════════════════════
-- CORE FUNCTIONS
-- ══════════════════════════════════════════
local running   = false
local logCB     = nil
local statCB    = nil
local claimCount = 0
local claimCB   = nil

local function addLog(msg, cls)
    if logCB then logCB(msg, cls) end
end
local function setStatus(msg, col)
    if statCB then statCB(msg, col) end
end
local function notif(t, m)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            {Title=t, Text=m, Duration=3})
    end)
end
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end
local function tpTo(pos)
    local hrp = getHRP()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0,5,0))
    return true
end

local function findObj(names, patterns, nearPos, radius)
    radius = radius or 150
    -- exact name
    for _, v in ipairs(workspace:GetDescendants()) do
        for _, n in ipairs(names or {}) do
            if v.Name == n and (v:IsA("BasePart") or v:IsA("Model")) then
                return v end
        end
    end
    -- pattern
    for _, v in ipairs(workspace:GetDescendants()) do
        local vn = v.Name:lower()
        for _, p in ipairs(patterns or {}) do
            if vn:match(p) and (v:IsA("BasePart") or v:IsA("Model")) then
                if nearPos then
                    local pos
                    if v:IsA("BasePart") then pos = v.Position
                    elseif v:IsA("Model") then
                        local pp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                        pos = pp and pp.Position
                    end
                    if pos and (pos-nearPos).Magnitude < radius then return v end
                else return v end
            end
        end
    end
    return nil
end

local function getPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        return p and p.Position
    end
end

local function firePrompts(patterns, nearPos, radius)
    radius = radius or 80
    local candidates, seen = {}, {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local at = (v.ActionText or ""):lower()
            local pn = (v.Parent and v.Parent.Name or ""):lower()
            local match = false
            for _, p in ipairs(patterns) do
                if at:match(p) or pn:match(p) then match=true; break end
            end
            if match and not seen[v] then
                if nearPos then
                    local par = v.Parent
                    local pos
                    if par and par:IsA("BasePart") then pos = par.Position
                    elseif par and par:IsA("Model") then
                        local pp = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart")
                        pos = pp and pp.Position
                    end
                    if pos and (pos-nearPos).Magnitude < radius then
                        seen[v]=true; table.insert(candidates,v)
                    end
                else
                    seen[v]=true; table.insert(candidates,v)
                end
            end
        end
    end
    local fired = 0
    for _, pr in ipairs(candidates) do
        for _ = 1,3 do
            local ok = pcall(function() fireproximityprompt(pr) end)
            if ok then fired=fired+1; break end
            task.wait(0.08)
        end
    end
    return fired
end

-- nudge toward obj if prompt miss
local function nudgeAndFire(hrp, nearPos, patterns, radius)
    local fired = firePrompts(patterns, nearPos, radius)
    if fired == 0 then
        local obj = findObj({}, patterns, nearPos, radius)
        if obj then
            local pos = getPos(obj)
            if pos then
                local dir = (pos - hrp.Position)
                if dir.Magnitude > 0 then
                    hrp.CFrame = CFrame.new(hrp.Position + dir.Unit * 3)
                end
                task.wait(0.15)
                fired = firePrompts(patterns, nearPos, radius)
            end
        end
    end
    return fired
end

-- ── MODE: GOPAY (single point)
local function runGopay(mtn)
    setStatus("FAST TRAVEL", "wait")
    addLog("Teleport ke " .. mtn.name, "")
    tpTo(mtn.near)
    task.wait(0.25)

    setStatus("LOCATING POINT", "wait")
    local obj = findObj({mtn.objName}, mtn.promptPattern, mtn.near, 120)
    if obj then
        local pos = getPos(obj)
        if pos then
            local off = (mtn.near - pos)
            off = off.Magnitude > 0.1 and off.Unit*8 or Vector3.new(0,0,8)
            local hrp = getHRP()
            if hrp then hrp.CFrame = CFrame.new(pos + off + Vector3.new(0,3,0)) end
            task.wait(0.2)
        end
    end

    local hrp = getHRP()
    if hrp then
        local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end

    setStatus("FIRING PROMPT", "wait")
    task.wait(0.12)
    nudgeAndFire(hrp, mtn.near, mtn.promptPattern, 120)

    setStatus("ARRIVED — CLAIM MANUAL", "done")
    addLog(mtn.name .. " — Arrived. Claim manual.", "ok")
    notif(mtn.name, "Sudah tiba. Claim voucher sekarang.")
    claimCount = claimCount + 1
    if claimCB then claimCB(claimCount) end
end

-- ── MODE: SUMMIT → BASECAMP
local function runSummit(mtn)
    setStatus("MENUJU SUMMIT", "wait")
    addLog("Teleport ke summit " .. mtn.name, "")
    tpTo(mtn.summit)
    task.wait(0.5)

    setStatus("MENCARI PROMPT", "wait")
    -- scan prompt ke basecamp
    local prompt = nil
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local pn = (v.Parent and v.Parent.Name or ""):lower()
            local at = (v.ActionText or ""):lower()
            if pn:match("summit") or at:match("basecamp") or
               at:match("base") or at:match("kembali") then
                prompt = v; break
            end
        end
    end
    if not prompt then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local par = v.Parent
                if par and par:IsA("BasePart") then
                    if (par.Position - mtn.summit).Magnitude < 120 then
                        prompt = v; break
                    end
                end
            end
        end
    end

    if prompt then
        local par = prompt.Parent
        if par and par:IsA("BasePart") then
            tpTo(par.Position); task.wait(0.35)
        end
        pcall(function() fireproximityprompt(prompt) end)
        addLog("Prompt 'Ke Basecamp' fired", "ok")
        task.wait(0.7)
    else
        setStatus("DIRECT TP BASECAMP", "wait")
        addLog("Prompt not found — direct TP", "")
        task.wait(0.2)
    end

    setStatus("MENUJU BASECAMP", "wait")
    tpTo(mtn.basecamp)
    task.wait(0.4)

    setStatus("ARRIVED — CLAIM MANUAL", "done")
    addLog(mtn.name .. " — Di basecamp. Claim manual.", "ok")
    notif(mtn.name, "Sudah di basecamp. Claim voucher sekarang!")
    claimCount = claimCount + 1
    if claimCB then claimCB(claimCount) end
end

-- ── MODE: MULTI PETI (Zihan)
local function runMulti(mtn, petiIdx)
    local peti = mtn.peti[petiIdx]
    if not peti then return end

    setStatus("FAST TRAVEL " .. peti.label, "wait")
    addLog("Teleport ke " .. peti.label, "")
    tpTo(peti.near)
    task.wait(0.25)

    setStatus("LOCATING " .. peti.label, "wait")
    local obj = findObj({mtn.objName}, mtn.promptPattern, peti.near, 120)
    if obj then
        local pos = getPos(obj)
        if pos then
            local off = (peti.near - pos)
            off = off.Magnitude > 0.1 and off.Unit*8 or Vector3.new(0,0,8)
            local hrp = getHRP()
            if hrp then hrp.CFrame = CFrame.new(pos + off + Vector3.new(0,3,0)) end
            task.wait(0.18)
        end
    end

    local hrp = getHRP()
    if hrp then
        local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end

    setStatus("FIRING PROMPT", "wait")
    task.wait(0.12)
    nudgeAndFire(hrp, peti.near, mtn.promptPattern, 120)

    setStatus("ARRIVED " .. peti.label .. " — CLAIM", "done")
    addLog(peti.label .. " — Claim manual.", "ok")
    notif("Mount Zihan", peti.label .. " — Claim voucher sekarang.")
    claimCount = claimCount + 1
    if claimCB then claimCB(claimCount) end
end

-- master run
local function runMountain(mtn, petiIdx)
    if running then return end
    running = true
    task.spawn(function()
        local hrp = getHRP()
        if not hrp then
            setStatus("CHARACTER NOT FOUND","err"); running=false; return
        end
        local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 0 end
        task.wait(0.1)

        if mtn.mode == "gopay" then
            runGopay(mtn)
        elseif mtn.mode == "summit" then
            runSummit(mtn)
        elseif mtn.mode == "multi" then
            runMulti(mtn, petiIdx or 1)
        end

        running = false
    end)
end

-- ══════════════════════════════════════════
-- WARNA & HELPER GUI
-- ══════════════════════════════════════════
local BG   = Color3.fromRGB(8,   8,   8)
local PNL  = Color3.fromRGB(14,  14,  14)
local DEEP = Color3.fromRGB(10,  10,  10)
local MID  = Color3.fromRGB(22,  22,  22)
local SURF = Color3.fromRGB(28,  28,  28)
local BRD  = Color3.fromRGB(34,  34,  34)
local BRD2 = Color3.fromRGB(46,  46,  46)
local DIM  = Color3.fromRGB(100, 100, 100)
local SIL  = Color3.fromRGB(153, 153, 153)
local LITE = Color3.fromRGB(204, 204, 204)
local WHT  = Color3.fromRGB(238, 238, 238)
local GR   = Color3.fromRGB(150, 255, 170)
local RD   = Color3.fromRGB(255, 100, 100)
local YL   = Color3.fromRGB(230, 200, 100)

local function uic(p, r)
    local u = Instance.new("UICorner", p); u.CornerRadius = UDim.new(0, r or 6)
end
local function usk(p, c, t)
    local s = Instance.new("UIStroke", p); s.Color = c or BRD; s.Thickness = t or 1; return s
end
local function lbl(p, txt, col, sz, font, xa)
    local l = Instance.new("TextLabel", p)
    l.BackgroundTransparency = 1; l.Text = txt or ""
    l.TextColor3 = col or WHT; l.Font = font or Enum.Font.Gotham
    l.TextSize = sz or 10; l.ZIndex = 14
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    return l
end

-- ══════════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "ACGAlfian"; sg.ResetOnSpawn = false
sg.DisplayOrder = 9999; sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = player.PlayerGui

-- PANEL UTAMA
local F = Instance.new("Frame", sg)
F.Size = UDim2.new(0, 320, 0, 480)
F.Position = UDim2.new(0.5, -160, 0.5, -240)
F.BackgroundColor3 = PNL; F.BorderSizePixel = 0
F.Active = true; F.Draggable = true; F.ZIndex = 10
uic(F, 10); usk(F, BRD, 1)

-- top line gradient simulasi
local TL = Instance.new("Frame", F)
TL.Size = UDim2.new(1,-4,0,1); TL.Position = UDim2.new(0,2,0,0)
TL.BackgroundColor3 = SIL; TL.BorderSizePixel = 0; TL.ZIndex = 15
uic(TL, 1)

-- corner deco
local function cdeco(p, xa, ya, bw, bh)
    local c = Instance.new("Frame", p)
    c.Size = UDim2.new(0,10,0,10)
    c.Position = UDim2.new(xa,xa==0 and 5 or -15, ya, ya==0 and 5 or -15)
    c.BackgroundTransparency = 1; c.BorderSizePixel = 0; c.ZIndex = 16
    local s = Instance.new("UIStroke", c)
    s.Color = BRD2; s.Thickness = 1
    local sp = Instance.new("UISizeConstraint", c)
    sp.MaxSize = Vector2.new(10,10)
    -- simulate corner via a frame with only 2 borders visible
    local inner = Instance.new("Frame", c)
    inner.Size = UDim2.new(1,0,1,0)
    inner.BackgroundTransparency = 1
    return c
end

-- ══ TITLEBAR ══
local TBar = Instance.new("Frame", F)
TBar.Size = UDim2.new(1,0,0,48); TBar.Position = UDim2.new(0,0,0,0)
TBar.BackgroundColor3 = DEEP; TBar.BorderSizePixel = 0; TBar.ZIndex = 11
local tbUIC = Instance.new("UICorner", TBar); tbUIC.CornerRadius = UDim.new(0,10)
local tbFix = Instance.new("Frame", TBar)
tbFix.Size = UDim2.new(1,0,0,10); tbFix.Position = UDim2.new(0,0,1,-10)
tbFix.BackgroundColor3 = DEEP; tbFix.BorderSizePixel = 0; tbFix.ZIndex = 11

-- icon
local TIcon = Instance.new("TextLabel", TBar)
TIcon.Size = UDim2.new(0,28,0,28); TIcon.Position = UDim2.new(0,12,0.5,-14)
TIcon.BackgroundColor3 = MID; TIcon.BorderSizePixel = 0; TIcon.ZIndex = 13
TIcon.Text = "⚡"; TIcon.TextColor3 = WHT; TIcon.Font = Enum.Font.Gotham; TIcon.TextSize = 14
TIcon.TextXAlignment = Enum.TextXAlignment.Center; TIcon.TextYAlignment = Enum.TextYAlignment.Center
uic(TIcon, 6); usk(TIcon, BRD2, 1)

local TName = lbl(TBar, "AUTO CLAIM GOPAY", WHT, 11, Enum.Font.GothamBold)
TName.Size = UDim2.new(1,-110,0,16); TName.Position = UDim2.new(0,48,0,8); TName.ZIndex=13

local TBy = lbl(TBar, "BY ALFIAN  ·  MOUNTAIN VOUCHER SYSTEM", DIM, 8, Enum.Font.Gotham)
TBy.Size = UDim2.new(1,-110,0,12); TBy.Position = UDim2.new(0,48,0,26); TBy.ZIndex=13

-- minimize + close
local function mkCtrl(parent, txt, xOff)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0,24,0,24); b.Position = UDim2.new(1,xOff,0.5,-12)
    b.BackgroundColor3 = MID; b.Text = txt; b.TextColor3 = DIM
    b.Font = Enum.Font.GothamBold; b.TextSize = 10; b.BorderSizePixel = 0; b.ZIndex = 14
    uic(b,5); usk(b,BRD2,1)
    b.MouseEnter:Connect(function() b.TextColor3 = WHT; b.BackgroundColor3 = SURF end)
    b.MouseLeave:Connect(function() b.TextColor3 = DIM; b.BackgroundColor3 = MID end)
    return b
end
local XBtn  = mkCtrl(TBar, "✕", -10)
local MinBtn = mkCtrl(TBar, "—", -38)

local minimized = false
XBtn.MouseButton1Click:Connect(function()
    TweenSvc:Create(F, TweenInfo.new(0.2,Enum.EasingStyle.Quart),
        {Size=UDim2.new(0,320,0,0), BackgroundTransparency=1}):Play()
    task.delay(0.22, function() sg:Destroy() end)
end)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    MinBtn.Text = minimized and "□" or "—"
end)

-- ══ STATUS BAR ══
local SBar = Instance.new("Frame", F)
SBar.Size = UDim2.new(1,0,0,24); SBar.Position = UDim2.new(0,0,0,48)
SBar.BackgroundColor3 = Color3.fromRGB(12,12,12); SBar.BorderSizePixel=0; SBar.ZIndex=11
local sbBot = Instance.new("Frame", SBar)
sbBot.Size=UDim2.new(1,0,0,1); sbBot.Position=UDim2.new(0,0,1,-1)
sbBot.BackgroundColor3=BRD; sbBot.BorderSizePixel=0; sbBot.ZIndex=12

local SDot = Instance.new("Frame", SBar)
SDot.Size=UDim2.new(0,5,0,5); SDot.Position=UDim2.new(0,12,0.5,-2)
SDot.BackgroundColor3=WHT; SDot.BorderSizePixel=0; SDot.ZIndex=13
uic(SDot,5)

local SConn = lbl(SBar,"Connected",SIL,8,Enum.Font.Gotham)
SConn.Size=UDim2.new(0,70,1,0); SConn.Position=UDim2.new(0,22,0,0); SConn.ZIndex=13

local SDivA = Instance.new("Frame",SBar)
SDivA.Size=UDim2.new(0,1,0,9); SDivA.Position=UDim2.new(0,97,0.5,-4)
SDivA.BackgroundColor3=BRD2; SDivA.BorderSizePixel=0; SDivA.ZIndex=13

local SPing = lbl(SBar,"Ping --ms",DIM,8,Enum.Font.Gotham)
SPing.Size=UDim2.new(0,70,1,0); SPing.Position=UDim2.new(0,105,0,0); SPing.ZIndex=13

local SDivB = Instance.new("Frame",SBar)
SDivB.Size=UDim2.new(0,1,0,9); SDivB.Position=UDim2.new(0,178,0.5,-4)
SDivB.BackgroundColor3=BRD2; SDivB.BorderSizePixel=0; SDivB.ZIndex=13

local SStatVal = lbl(SBar,"READY",GR,8,Enum.Font.GothamBold)
SStatVal.Size=UDim2.new(0,100,1,0); SStatVal.Position=UDim2.new(0,186,0,0); SStatVal.ZIndex=13

statCB = function(msg, col)
    SStatVal.Text = msg
    if col=="done" then SStatVal.TextColor3=GR
    elseif col=="err" then SStatVal.TextColor3=RD
    elseif col=="wait" then SStatVal.TextColor3=YL
    else SStatVal.TextColor3=WHT end
end

-- ping fake
task.spawn(function()
    while sg and sg.Parent do
        task.wait(3.5)
        SPing.Text = "Ping " .. (28+math.random(0,40)) .. "ms"
    end
end)

-- SDot blink
task.spawn(function()
    while sg and sg.Parent do
        TweenSvc:Create(SDot,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0.7}):Play()
        task.wait(1.2)
        TweenSvc:Create(SDot,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0}):Play()
        task.wait(1.2)
    end
end)

-- ══ TABS ══
local TABS_Y = 72
local TabBar = Instance.new("Frame", F)
TabBar.Size = UDim2.new(1,0,0,30); TabBar.Position = UDim2.new(0,0,0,TABS_Y)
TabBar.BackgroundColor3 = Color3.fromRGB(11,11,11); TabBar.BorderSizePixel=0; TabBar.ZIndex=11
local tabBot = Instance.new("Frame", TabBar)
tabBot.Size=UDim2.new(1,0,0,1); tabBot.Position=UDim2.new(0,0,1,-1)
tabBot.BackgroundColor3=BRD; tabBot.BorderSizePixel=0; tabBot.ZIndex=12
local TabLayout = Instance.new("UIListLayout", TabBar)
TabLayout.FillDirection=Enum.FillDirection.Horizontal
TabLayout.SortOrder=Enum.SortOrder.LayoutOrder
TabLayout.Padding=UDim.new(0,0)

-- panes container
local BODY_Y = TABS_Y + 30
local PaneContainer = Instance.new("Frame", F)
PaneContainer.Size = UDim2.new(1,0,1,-(BODY_Y+32))
PaneContainer.Position = UDim2.new(0,0,0,BODY_Y)
PaneContainer.BackgroundTransparency=1; PaneContainer.ZIndex=11
PaneContainer.ClipsDescendants=true

local activePaneName = "gunung"
local panes = {}
local tabBtns = {}

local function mkPane(name)
    local p = Instance.new("ScrollingFrame", PaneContainer)
    p.Size=UDim2.new(1,0,1,0); p.Position=UDim2.new(0,0,0,0)
    p.BackgroundTransparency=1; p.BorderSizePixel=0
    p.ScrollBarThickness=2; p.ScrollBarImageColor3=BRD2
    p.CanvasSize=UDim2.new(0,0,0,0); p.AutomaticCanvasSize=Enum.AutomaticSize.Y
    p.ZIndex=12; p.Visible=(name==activePaneName)
    local L = Instance.new("UIPadding", p)
    L.PaddingLeft=UDim.new(0,12); L.PaddingRight=UDim.new(0,12)
    L.PaddingTop=UDim.new(0,10); L.PaddingBottom=UDim.new(0,10)
    local LL = Instance.new("UIListLayout", p)
    LL.SortOrder=Enum.SortOrder.LayoutOrder; LL.Padding=UDim.new(0,8)
    panes[name] = p
    return p
end

local function mkTab(txt, name, order)
    local b = Instance.new("TextButton", TabBar)
    b.LayoutOrder=order
    b.Size=UDim2.new(0,80,1,0)
    b.BackgroundColor3 = (name==activePaneName) and PNL or Color3.fromRGB(11,11,11)
    b.Text=txt; b.BorderSizePixel=0; b.ZIndex=13
    b.TextColor3 = (name==activePaneName) and WHT or DIM
    b.Font=Enum.Font.GothamBold; b.TextSize=9

    -- active underline
    local ul = Instance.new("Frame", b)
    ul.Size=UDim2.new(1,0,0,1); ul.Position=UDim2.new(0,0,1,-1)
    ul.BackgroundColor3=WHT; ul.BorderSizePixel=0; ul.ZIndex=14
    ul.BackgroundTransparency = (name==activePaneName) and 0.5 or 1

    b.MouseButton1Click:Connect(function()
        activePaneName = name
        for nm, pn in pairs(panes) do pn.Visible=(nm==name) end
        for nm, tb in pairs(tabBtns) do
            tb.btn.TextColor3 = (nm==name) and WHT or DIM
            tb.btn.BackgroundColor3 = (nm==name) and PNL or Color3.fromRGB(11,11,11)
            tb.ul.BackgroundTransparency = (nm==name) and 0.5 or 1
        end
    end)
    tabBtns[name] = {btn=b, ul=ul}
    return b
end

mkTab("⛰ GUNUNG", "gunung", 1)
mkTab("🛠 TOOLS",  "tools",  2)
mkTab("📋 LOG",    "log",    3)

-- ══ PANE HELPER ══
local function secLabel(parent, txt, order)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder=order; row.Size=UDim2.new(1,0,0,14)
    row.BackgroundTransparency=1; row.ZIndex=12
    local l = lbl(row, txt, DIM, 7, Enum.Font.GothamBold)
    l.Size=UDim2.new(0,80,1,0); l.LetterSpacing=3
    local line = Instance.new("Frame", row)
    line.Size=UDim2.new(1,-90,0,1); line.Position=UDim2.new(0,88,0.5,0)
    line.BackgroundColor3=BRD; line.BorderSizePixel=0; line.ZIndex=13
end

-- ══════════════════════════════════════════
-- PANE: GUNUNG
-- ══════════════════════════════════════════
local PGunung = mkPane("gunung")

-- info row (Claimed / Gunung / Aktif)
local InfoRow = Instance.new("Frame", PGunung)
InfoRow.LayoutOrder=1; InfoRow.Size=UDim2.new(1,0,0,56)
InfoRow.BackgroundTransparency=1; InfoRow.ZIndex=12
local IR_L = Instance.new("UIListLayout", InfoRow)
IR_L.FillDirection=Enum.FillDirection.Horizontal; IR_L.Padding=UDim.new(0,6)
IR_L.SortOrder=Enum.SortOrder.LayoutOrder

local claimValLbl, activeValLbl

local function mkInfoCard(parent, val, key, order)
    local c = Instance.new("Frame", parent)
    c.LayoutOrder=order; c.Size=UDim2.new(1/3,-4,1,0)
    c.BackgroundColor3=MID; c.BorderSizePixel=0; c.ZIndex=13
    uic(c,7); usk(c,BRD,1)
    local vl = lbl(c, val, WHT, 18, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    vl.Size=UDim2.new(1,0,0,28); vl.Position=UDim2.new(0,0,0,8); vl.ZIndex=14
    local kl = lbl(c, key, DIM, 7, Enum.Font.Gotham, Enum.TextXAlignment.Center)
    kl.Size=UDim2.new(1,0,0,12); kl.Position=UDim2.new(0,0,0,34); kl.ZIndex=14
    return vl
end

claimValLbl = mkInfoCard(InfoRow, "0",   "CLAIMED", 1)
mkInfoCard(InfoRow, "4",   "GUNUNG",  2)
activeValLbl = mkInfoCard(InfoRow, "–",  "AKTIF",   3)

secLabel(PGunung, "PILIH DESTINASI", 2)

-- mountain grid (2×2)
local MtnGrid = Instance.new("Frame", PGunung)
MtnGrid.LayoutOrder=3; MtnGrid.Size=UDim2.new(1,0,0,150)
MtnGrid.BackgroundTransparency=1; MtnGrid.ZIndex=12
local MG_L = Instance.new("UIGridLayout", MtnGrid)
MG_L.CellSize=UDim2.new(0.5,-4,0,68); MG_L.CellPadding=UDim2.new(0,6,0,6)
MG_L.SortOrder=Enum.SortOrder.LayoutOrder

local selectedMtn  = MOUNTAINS[1]
local selectedPeti = 1
local mtnCards     = {}

local function updateActiveVal()
    if selectedMtn.mode == "multi" then
        activeValLbl.Text = selectedMtn.name:sub(1,5) .. " P"..selectedPeti
    else
        activeValLbl.Text = selectedMtn.name:sub(1,5)
    end
end
updateActiveVal()

claimCB = function(n)
    claimValLbl.Text = tostring(n)
end

for i, mtn in ipairs(MOUNTAINS) do
    local card = Instance.new("TextButton", MtnGrid)
    card.LayoutOrder=i; card.BackgroundColor3=MID
    card.Text=""; card.BorderSizePixel=0; card.ZIndex=13
    uic(card,8)
    local csk = usk(card, i==1 and BRD2 or BRD, 1)

    -- top accent on card
    local cAccent = Instance.new("Frame",card)
    cAccent.Size=UDim2.new(1,-4,0,1); cAccent.Position=UDim2.new(0,2,0,0)
    cAccent.BackgroundColor3 = i==1 and WHT or BRD; cAccent.BorderSizePixel=0; cAccent.ZIndex=15
    uic(cAccent,1)

    local cIcon = lbl(card, mtn.icon, WHT, 18, Enum.Font.Gotham, Enum.TextXAlignment.Left)
    cIcon.Size=UDim2.new(1,-8,0,22); cIcon.Position=UDim2.new(0,8,0,6); cIcon.ZIndex=14

    -- badge "AKTIF"
    local badge = Instance.new("TextLabel", card)
    badge.Size=UDim2.new(0,32,0,12); badge.Position=UDim2.new(1,-36,0,5)
    badge.BackgroundColor3=SURF; badge.BorderSizePixel=0; badge.ZIndex=15
    badge.Text="AKTIF"; badge.TextColor3=WHT; badge.Font=Enum.Font.GothamBold; badge.TextSize=6
    badge.TextXAlignment=Enum.TextXAlignment.Center; badge.Visible=(i==1)
    uic(badge,3); usk(badge,BRD2,1)

    local cName = lbl(card, mtn.name, i==1 and WHT or LITE, 9, Enum.Font.GothamBold)
    cName.Size=UDim2.new(1,-8,0,14); cName.Position=UDim2.new(0,8,0,30); cName.ZIndex=14

    local dotF = Instance.new("Frame",card)
    dotF.Size=UDim2.new(0,4,0,4); dotF.Position=UDim2.new(0,8,0,48)
    dotF.BackgroundColor3=i==1 and WHT or DIM; dotF.BorderSizePixel=0; dotF.ZIndex=15
    uic(dotF,5)
    local stLbl = lbl(card, mtn.status, i==1 and SIL or DIM, 7, Enum.Font.Gotham)
    stLbl.Size=UDim2.new(1,-18,0,12); stLbl.Position=UDim2.new(0,16,0,45); stLbl.ZIndex=14

    table.insert(mtnCards, {card=card, csk=csk, cAccent=cAccent, cName=cName, badge=badge, dotF=dotF, stLbl=stLbl})

    card.MouseButton1Click:Connect(function()
        selectedMtn = mtn; selectedPeti = 1
        -- reset all
        for j, mc in ipairs(mtnCards) do
            mc.csk.Color = BRD
            mc.cAccent.BackgroundColor3 = BRD
            mc.cName.TextColor3 = LITE
            mc.badge.Visible = false
            mc.dotF.BackgroundColor3 = DIM
            mc.stLbl.TextColor3 = DIM
            mc.card.BackgroundColor3 = MID
        end
        -- activate
        mtnCards[i].csk.Color = BRD2
        mtnCards[i].cAccent.BackgroundColor3 = WHT
        mtnCards[i].cName.TextColor3 = WHT
        mtnCards[i].badge.Visible = true
        mtnCards[i].dotF.BackgroundColor3 = WHT
        mtnCards[i].stLbl.TextColor3 = SIL
        mtnCards[i].card.BackgroundColor3 = SURF
        updateActiveVal()
        addLog("Destinasi: " .. mtn.name, "ok")

        -- jika Zihan, tampilkan peti selector
        PetiFrame.Visible = (mtn.mode == "multi")
    end)
end

-- PETI SELECTOR (hanya muncul jika Zihan dipilih)
local PetiFrame = Instance.new("Frame", PGunung)
PetiFrame.LayoutOrder=4; PetiFrame.Size=UDim2.new(1,0,0,36)
PetiFrame.BackgroundTransparency=1; PetiFrame.ZIndex=12
PetiFrame.Visible=false

local PF_L = Instance.new("UIListLayout",PetiFrame)
PF_L.FillDirection=Enum.FillDirection.Horizontal
PF_L.Padding=UDim.new(0,5); PF_L.SortOrder=Enum.SortOrder.LayoutOrder

local petiBtns = {}
for pi, pt in ipairs(MOUNTAINS[4].peti) do
    local pb = Instance.new("TextButton", PetiFrame)
    pb.LayoutOrder=pi; pb.Size=UDim2.new(0.25,-5,1,0)
    pb.BackgroundColor3 = pi==1 and SURF or MID
    pb.Text=pt.label:gsub("PETI ","P"); pb.BorderSizePixel=0; pb.ZIndex=13
    pb.TextColor3 = pi==1 and WHT or DIM
    pb.Font=Enum.Font.GothamBold; pb.TextSize=9
    uic(pb,6)
    local pbsk = usk(pb, pi==1 and BRD2 or BRD, 1)
    table.insert(petiBtns, {btn=pb, sk=pbsk})

    pb.MouseButton1Click:Connect(function()
        selectedPeti = pi
        for j2, ppb in ipairs(petiBtns) do
            ppb.btn.TextColor3 = j2==pi and WHT or DIM
            ppb.btn.BackgroundColor3 = j2==pi and SURF or MID
            ppb.sk.Color = j2==pi and BRD2 or BRD
        end
        updateActiveVal()
        addLog("Peti dipilih: " .. pt.label, "ok")
    end)
end

-- CLAIM BUTTON
local ClaimBtn = Instance.new("TextButton", PGunung)
ClaimBtn.LayoutOrder=5; ClaimBtn.Size=UDim2.new(1,0,0,40)
ClaimBtn.BackgroundColor3=WHT; ClaimBtn.BorderSizePixel=0; ClaimBtn.ZIndex=12
ClaimBtn.Text="⚡  TELEPORT & AUTO CLAIM"; ClaimBtn.TextColor3=DEEP
ClaimBtn.Font=Enum.Font.GothamBold; ClaimBtn.TextSize=11
uic(ClaimBtn,8); usk(ClaimBtn,BRD2,1)

ClaimBtn.MouseEnter:Connect(function()
    if not running then ClaimBtn.BackgroundColor3=Color3.fromRGB(255,255,255) end
end)
ClaimBtn.MouseLeave:Connect(function()
    if not running then ClaimBtn.BackgroundColor3=WHT end
end)

ClaimBtn.MouseButton1Click:Connect(function()
    if running then return end
    ClaimBtn.BackgroundColor3=SURF
    ClaimBtn.TextColor3=YL; ClaimBtn.Text="⏳  TELEPORTING..."
    runMountain(selectedMtn, selectedPeti)
    task.spawn(function()
        while running do task.wait(0.1) end
        task.wait(0.5)
        ClaimBtn.BackgroundColor3=WHT
        ClaimBtn.TextColor3=DEEP; ClaimBtn.Text="⚡  TELEPORT & AUTO CLAIM"
    end)
end)

-- ══════════════════════════════════════════
-- PANE: TOOLS
-- ══════════════════════════════════════════
local PTools = mkPane("tools")

secLabel(PTools, "UTILITAS", 1)

local TOOLS = {
    {icon="💨", name="Speed Boost",    desc="WalkSpeed × 2.0", def=false,
     fn=function(on)
         local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
         if hum then hum.WalkSpeed=on and 32 or 16 end
     end},
    {icon="🦘", name="Jump Boost",     desc="JumpPower × 1.5", def=true,
     fn=function(on)
         local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
         if hum then hum.JumpPower=on and 75 or 50 end
     end},
    {icon="⚙️",  name="Anti-Lag",      desc="Kualitas grafis minimum", def=true,
     fn=function(on)
         antilagOn=on; if on then applyAntiLag() end
         ALGlobalBtn.Text = on and "ON" or "OFF"
         ALGlobalBtn.TextColor3 = on and WHT or DIM
     end},
    {icon="🔁", name="Auto Rejoin",    desc="Reconnect saat terputus", def=false, fn=function() end},
}

local ALGlobalBtn -- forward ref

local function mkToggleRow(parent, tool, order)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder=order; row.Size=UDim2.new(1,0,0,44)
    row.BackgroundColor3=MID; row.BorderSizePixel=0; row.ZIndex=12
    uic(row,7); usk(row,BRD,1)

    local iconL = lbl(row, tool.icon, WHT, 14, Enum.Font.Gotham, Enum.TextXAlignment.Center)
    iconL.Size=UDim2.new(0,28,1,0); iconL.Position=UDim2.new(0,10,0,0); iconL.ZIndex=13

    local nameL = lbl(row, tool.name, LITE, 10, Enum.Font.GothamBold)
    nameL.Size=UDim2.new(1,-90,0,16); nameL.Position=UDim2.new(0,44,0,8); nameL.ZIndex=13

    local descL = lbl(row, tool.desc, DIM, 8, Enum.Font.Gotham)
    descL.Size=UDim2.new(1,-90,0,12); descL.Position=UDim2.new(0,44,0,26); descL.ZIndex=13

    local state = tool.def
    local tgl = Instance.new("TextButton", row)
    tgl.Size=UDim2.new(0,38,0,20); tgl.Position=UDim2.new(1,-48,0.5,-10)
    tgl.BackgroundColor3=state and SURF or Color3.fromRGB(18,18,18)
    tgl.BorderSizePixel=0; tgl.ZIndex=13
    tgl.Text=state and "ON" or "OFF"
    tgl.TextColor3=state and WHT or DIM
    tgl.Font=Enum.Font.GothamBold; tgl.TextSize=8
    uic(tgl,5); local tsk=usk(tgl, state and BRD2 or BRD, 1)

    if tool.name == "Anti-Lag" then ALGlobalBtn = tgl end

    tgl.MouseButton1Click:Connect(function()
        state=not state
        tgl.Text=state and "ON" or "OFF"
        tgl.TextColor3=state and WHT or DIM
        tgl.BackgroundColor3=state and SURF or Color3.fromRGB(18,18,18)
        tsk.Color=state and BRD2 or BRD
        pcall(function() tool.fn(state) end)
        addLog(tool.name .. ": " .. (state and "ON" or "OFF"), state and "ok" or "")
    end)
    return tgl
end

for ti, t in ipairs(TOOLS) do
    mkToggleRow(PTools, t, ti+1)
end

-- ══════════════════════════════════════════
-- PANE: LOG
-- ══════════════════════════════════════════
local PLog = mkPane("log")

secLabel(PLog, "ACTIVITY LOG", 1)

local LogBox = Instance.new("ScrollingFrame", PLog)
LogBox.LayoutOrder=2; LogBox.Size=UDim2.new(1,0,0,160)
LogBox.BackgroundColor3=DEEP; LogBox.BorderSizePixel=0; LogBox.ZIndex=12
LogBox.ScrollBarThickness=2; LogBox.ScrollBarImageColor3=BRD2
LogBox.CanvasSize=UDim2.new(0,0,0,0); LogBox.AutomaticCanvasSize=Enum.AutomaticSize.Y
uic(LogBox,6); usk(LogBox,BRD,1)
local LBpad=Instance.new("UIPadding",LogBox)
LBpad.PaddingLeft=UDim.new(0,8); LBpad.PaddingRight=UDim.new(0,8)
LBpad.PaddingTop=UDim.new(0,6); LBpad.PaddingBottom=UDim.new(0,6)
local LBlay=Instance.new("UIListLayout",LogBox)
LBlay.SortOrder=Enum.SortOrder.LayoutOrder; LBlay.Padding=UDim.new(0,3)

local logIdx = 0
logCB = function(msg, cls)
    logIdx=logIdx+1
    local row=Instance.new("Frame",LogBox)
    row.LayoutOrder=logIdx; row.Size=UDim2.new(1,0,0,16)
    row.BackgroundTransparency=1; row.ZIndex=13

    local ts = os.date("%H:%M:%S")
    local tl=lbl(row,ts,DIM,8,Enum.Font.Code)
    tl.Size=UDim2.new(0,54,1,0); tl.ZIndex=14

    local ml=lbl(row,msg, cls=="ok" and SIL or (cls=="hi" and WHT or DIM),8,Enum.Font.Gotham)
    ml.Size=UDim2.new(1,-58,1,0); ml.Position=UDim2.new(0,56,0,0); ml.ZIndex=14

    LogBox.CanvasPosition=Vector2.new(0,99999)
end

-- clear button
local ClearBtn=Instance.new("TextButton",PLog)
ClearBtn.LayoutOrder=3; ClearBtn.Size=UDim2.new(1,0,0,22)
ClearBtn.BackgroundTransparency=1; ClearBtn.BorderSizePixel=0; ClearBtn.ZIndex=12
ClearBtn.Text="↺  CLEAR LOG"; ClearBtn.TextColor3=DIM
ClearBtn.Font=Enum.Font.GothamBold; ClearBtn.TextSize=8
ClearBtn.TextXAlignment=Enum.TextXAlignment.Left
ClearBtn.MouseEnter:Connect(function() ClearBtn.TextColor3=SIL end)
ClearBtn.MouseLeave:Connect(function() ClearBtn.TextColor3=DIM end)
ClearBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(LogBox:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    logIdx=0; addLog("Log dibersihkan.","ok")
end)

-- ══ FOOTER ══
local Foot = Instance.new("Frame", F)
Foot.Size=UDim2.new(1,0,0,28); Foot.Position=UDim2.new(0,0,1,-28)
Foot.BackgroundColor3=DEEP; Foot.BorderSizePixel=0; Foot.ZIndex=11
local ftTop=Instance.new("Frame",Foot)
ftTop.Size=UDim2.new(1,0,0,1); ftTop.BackgroundColor3=BRD; ftTop.BorderSizePixel=0; ftTop.ZIndex=12

local fVer=lbl(Foot,"v2.0 · ROBLOX",DIM,8,Enum.Font.Gotham)
fVer.Size=UDim2.new(0.4,0,1,0); fVer.Position=UDim2.new(0,12,0,0); fVer.ZIndex=13

local fBy=lbl(Foot,"BY ALFIAN",SIL,9,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
fBy.Size=UDim2.new(0.3,0,1,0); fBy.Position=UDim2.new(0.35,0,0,0); fBy.ZIndex=13

local fClock=lbl(Foot,os.date("%H:%M:%S"),DIM,8,Enum.Font.Code,Enum.TextXAlignment.Right)
fClock.Size=UDim2.new(0.3,-12,1,0); fClock.Position=UDim2.new(0.7,0,0,0); fClock.ZIndex=13
task.spawn(function()
    while sg and sg.Parent do
        task.wait(1); fClock.Text=os.date("%H:%M:%S")
    end
end)

-- F9
UIS.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.F9 then F.Visible=not F.Visible end
end)

-- auto antilag + initial log
task.spawn(function()
    task.wait(0.6)
    applyAntiLag(); antilagOn=true
    if ALGlobalBtn then
        ALGlobalBtn.Text="ON"; ALGlobalBtn.TextColor3=WHT
    end
    addLog("Script dijalankan.", "ok")
    addLog("Anti-Lag aktif.", "ok")
    addLog("Menunggu pilihan gunung.", "")
    setStatus("READY", "done")
end)

print("Auto Claim GoPay | By Alfian | 4 Mountain | F9 toggle")
