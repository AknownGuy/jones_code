-- Menu v1.4 | G = menu | V = breakers | F = generator | X = cursor lock

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local LocalPlayer  = Players.LocalPlayer
local FIRE_DELAY   = 0.02
local scriptActive = true

-- ─────────── KEYBINDS (mutable) ───────────────────
local keybinds = {
    menu      = Enum.KeyCode.G,
    breakers  = Enum.KeyCode.V,
    generator = Enum.KeyCode.F,
    cursor    = Enum.KeyCode.X,
}

local function getKeyName(kc)
    return tostring(kc):gsub("Enum.KeyCode.", "")
end

-- ─────────── REMOTES ───────────────────
local AbilityEvents     = ReplicatedStorage:WaitForChild("AbilityEvents")
local UltraMechanicUsed = AbilityEvents:WaitForChild("UltraMechanicUsed")

-- ─────────── SMOOTH TELEPORT ───────────────────
-- Lerps HRP over `duration` seconds using ease-in-out curve.
-- Blocks the calling coroutine until done.
local function smoothTeleport(x, y, z, duration)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local startCF = hrp.CFrame
    local endCF   = CFrame.new(x, y, z)
    local steps   = math.max(1, math.floor(duration / 0.016))

    for i = 1, steps do
        local a = i / steps
        -- ease in-out cubic
        local t = a < 0.5 and (4 * a * a * a) or (1 - (-2 * a + 2) ^ 3 / 2)
        if hrp and hrp.Parent then
            hrp.CFrame = startCF:Lerp(endCF, t)
        end
        task.wait(0.016)
    end
    if hrp and hrp.Parent then
        hrp.CFrame = endCF
    end
end

-- ─────────── BREAKERS ───────────────────
local busy = false

local function scanAndFire(onStatus, onProgress, onDone)
    if busy then return end
    busy = true

    if onStatus then onStatus("Scanning breakers...") end

    local prompts = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local isBreaker = (
                string.find(obj.ObjectText:lower(), "breaker") or
                string.find(obj.ActionText:lower(), "activate") or
                string.find(obj.ActionText:lower(), "breaker")
            )
            if isBreaker then table.insert(prompts, obj) end
        end
    end

    local total = #prompts
    if total == 0 then
        if onDone then onDone(0, 0) end
        busy = false
        return
    end

    if onStatus then onStatus("Found " .. total .. " — activating...") end

    local success = 0
    for i, prompt in ipairs(prompts) do
        local ok = pcall(function()
            UltraMechanicUsed:FireServer()
            if fireproximityprompt then
                local old = prompt.MaxActivationDistance
                prompt.MaxActivationDistance = 9e9
                pcall(fireproximityprompt, prompt)
                prompt.MaxActivationDistance = old
            end
        end)
        if ok then success += 1 end
        if onProgress then onProgress(i, total) end
        if FIRE_DELAY > 0 then task.wait(FIRE_DELAY) end
    end

    if onDone then onDone(success, total) end
    busy = false
end

-- ─────────── NIGHT VISION ───────────────────
local nightVisionEnabled = false
local nightVisionThread  = nil

local function startNightVision()
    if nightVisionThread then return end
    nightVisionThread = task.spawn(function()
        while nightVisionEnabled do
            pcall(function()
                AbilityEvents:WaitForChild("NightVisionUsed"):FireServer()
            end)
            task.wait(10)
        end
        nightVisionThread = nil
    end)
end

local function stopNightVision()
    nightVisionEnabled = false
    nightVisionThread  = nil
end

-- ─────────── GOD MODE (0.1s fast poll) ───────────────────
local godModeEnabled = false
local godModeThread  = nil

local function startGodMode()
    if godModeThread then return end
    godModeThread = task.spawn(function()
        while godModeEnabled do
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health < hum.MaxHealth then
                    local needed = hum.MaxHealth - hum.Health
                    pcall(function()
                        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(-needed, "Weeping")
                    end)
                end
            end
            task.wait(0.1)
        end
        godModeThread = nil
    end)
end

local function stopGodMode()
    godModeEnabled = false
    godModeThread  = nil
end

-- ─────────── CURSOR LOCK ───────────────────
local cursorLocked = false

local function setCursorLock(locked)
    cursorLocked = locked
    UserInputService.MouseBehavior = locked
        and Enum.MouseBehavior.LockCenter
        or  Enum.MouseBehavior.Default
end

-- ─────────── FLOOR TRACKING ───────────────────
local function getFloorObj()
    local data = LocalPlayer:FindFirstChild("InGameData")
    if data then return data:FindFirstChild("FloorReached") end
    return nil
end

-- ─────────── BUILD GUI ───────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MainMenu"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

-- Theme
local CB  = Color3.fromRGB(12,  12,  18)   -- background
local CP  = Color3.fromRGB(20,  20,  30)   -- panel
local CBo = Color3.fromRGB(55,  55,  90)   -- border
local CA  = Color3.fromRGB(80,  120, 255)  -- accent blue
local CA2 = Color3.fromRGB(55,  190, 120)  -- accent green
local CA3 = Color3.fromRGB(210, 150, 40)   -- accent gold
local CA4 = Color3.fromRGB(200, 65,  65)   -- accent red
local CT  = Color3.fromRGB(205, 205, 215)  -- text
local CS  = Color3.fromRGB(100, 100, 120)  -- subtext

-- Main frame
local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, 300, 0, 570)
frame.Position         = UDim2.new(0.5, -150, 0.5, -285)
frame.BackgroundColor3 = CB
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Visible          = false
frame.Parent           = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local fstroke = Instance.new("UIStroke")
fstroke.Color = CBo ; fstroke.Thickness = 1.2 ; fstroke.Parent = frame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = CP
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
local tpatch = Instance.new("Frame")
tpatch.Size = UDim2.new(1,0,0,8) ; tpatch.Position = UDim2.new(0,0,1,-8)
tpatch.BackgroundColor3 = CP ; tpatch.BorderSizePixel = 0 ; tpatch.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Text           = "MENU  //  v1.4"
titleLabel.Font           = Enum.Font.GothamBold
titleLabel.TextSize       = 13
titleLabel.TextColor3     = CT
titleLabel.BackgroundTransparency = 1
titleLabel.Size           = UDim2.new(1, -135, 1, 0)
titleLabel.Position       = UDim2.new(0, 12, 0, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent         = titleBar

local unloadBtn = Instance.new("TextButton")
unloadBtn.Text             = "UNLOAD"
unloadBtn.Font             = Enum.Font.GothamBold
unloadBtn.TextSize         = 10
unloadBtn.TextColor3       = Color3.fromRGB(255, 200, 80)
unloadBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 10)
unloadBtn.Size             = UDim2.new(0, 56, 0, 20)
unloadBtn.Position         = UDim2.new(1, -92, 0.5, -10)
unloadBtn.BorderSizePixel  = 0
unloadBtn.AutoButtonColor  = false
unloadBtn.Parent           = titleBar
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0, 4)
local us = Instance.new("UIStroke")
us.Color = Color3.fromRGB(120,90,20) ; us.Thickness = 1 ; us.Parent = unloadBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Text             = "X"
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 12
closeBtn.TextColor3       = CA4
closeBtn.BackgroundColor3 = Color3.fromRGB(38, 16, 16)
closeBtn.Size             = UDim2.new(0, 26, 0, 20)
closeBtn.Position         = UDim2.new(1, -32, 0.5, -10)
closeBtn.BorderSizePixel  = 0
closeBtn.AutoButtonColor  = false
closeBtn.Parent           = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- Hint line (updated dynamically when binds change)
local hintLine = Instance.new("TextLabel")
hintLine.Font               = Enum.Font.Gotham
hintLine.TextSize           = 9
hintLine.TextColor3         = CS
hintLine.BackgroundTransparency = 1
hintLine.Size               = UDim2.new(1, -20, 0, 14)
hintLine.Position           = UDim2.new(0, 10, 0, 42)
hintLine.TextXAlignment     = Enum.TextXAlignment.Left
hintLine.Parent             = frame

local function refreshHint()
    hintLine.Text = getKeyName(keybinds.menu) .. "=menu  " ..
        getKeyName(keybinds.breakers) .. "=breakers  " ..
        getKeyName(keybinds.generator) .. "=generator  " ..
        getKeyName(keybinds.cursor) .. "=cursor"
end
refreshHint()

-- ── TAB ROW ──
local tabRow = Instance.new("Frame")
tabRow.Size             = UDim2.new(1, -20, 0, 26)
tabRow.Position         = UDim2.new(0, 10, 0, 60)
tabRow.BackgroundColor3 = CP
tabRow.BorderSizePixel  = 0
tabRow.Parent           = frame
Instance.new("UICorner", tabRow).CornerRadius = UDim.new(0, 6)

local function makeTabBtn(text, xScale, xOff)
    local b = Instance.new("TextButton")
    b.Text               = text
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 11
    b.TextColor3         = CS
    b.BackgroundTransparency = 1
    b.Size               = UDim2.new(0.5, -4, 1, -4)
    b.Position           = UDim2.new(xScale, xOff, 0, 2)
    b.BorderSizePixel    = 0
    b.AutoButtonColor    = false
    b.Parent             = tabRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local tabMain  = makeTabBtn("MAIN",  0,   2)
local tabBinds = makeTabBtn("BINDS", 0.5, 2)

-- ── PAGES ──
-- Main page uses ScrollingFrame so content isn't clipped
local mainPage = Instance.new("ScrollingFrame")
mainPage.Size                = UDim2.new(1, 0, 1, -94)
mainPage.Position            = UDim2.new(0, 0, 0, 94)
mainPage.BackgroundTransparency = 1
mainPage.BorderSizePixel     = 0
mainPage.ScrollBarThickness  = 3
mainPage.ScrollBarImageColor3 = CBo
mainPage.CanvasSize          = UDim2.new(0, 0, 0, 540)
mainPage.AutomaticCanvasSize = Enum.AutomaticSize.None
mainPage.Parent              = frame

local bindsPage = Instance.new("Frame")
bindsPage.Size               = UDim2.new(1, 0, 1, -94)
bindsPage.Position           = UDim2.new(0, 0, 0, 94)
bindsPage.BackgroundTransparency = 1
bindsPage.BorderSizePixel    = 0
bindsPage.Visible            = false
bindsPage.Parent             = frame

local function setTab(isMain)
    mainPage.Visible  = isMain
    bindsPage.Visible = not isMain
    if isMain then
        tabMain.TextColor3  = CT
        tabBinds.TextColor3 = CS
        TweenService:Create(tabMain,  TweenInfo.new(0.1), { BackgroundTransparency = 0, BackgroundColor3 = CBo }):Play()
        TweenService:Create(tabBinds, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
    else
        tabMain.TextColor3  = CS
        tabBinds.TextColor3 = CT
        TweenService:Create(tabBinds, TweenInfo.new(0.1), { BackgroundTransparency = 0, BackgroundColor3 = CBo }):Play()
        TweenService:Create(tabMain,  TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
    end
end

tabMain.MouseButton1Click:Connect(function() setTab(true) end)
tabBinds.MouseButton1Click:Connect(function() setTab(false) end)
setTab(true)

-- ── HELPER FUNCTIONS (all take explicit parent) ──

local function uiSection(parent, label, posY, col)
    local line = Instance.new("Frame")
    line.Size             = UDim2.new(1, -20, 0, 1)
    line.Position         = UDim2.new(0, 10, 0, posY + 13)
    line.BackgroundColor3 = col
    line.BorderSizePixel  = 0
    line.Parent           = parent

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 10
    lbl.TextColor3         = col
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(0.6, 0, 0, 14)
    lbl.Position           = UDim2.new(0, 10, 0, posY)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = parent
end

local function uiButton(parent, text, posY, h, bg, sz, pos)
    local b = Instance.new("TextButton")
    b.Text             = text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 11
    b.TextColor3       = CT
    b.BackgroundColor3 = bg or CA
    b.Size             = sz or UDim2.new(1, -20, 0, h or 34)
    b.Position         = pos or UDim2.new(0, 10, 0, posY)
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Parent           = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local function uiStatus(parent, posY, col)
    local l = Instance.new("TextLabel")
    l.Text               = "Status: ready"
    l.Font               = Enum.Font.Gotham
    l.TextSize           = 11
    l.TextColor3         = col or CS
    l.BackgroundTransparency = 1
    l.Size               = UDim2.new(1, -20, 0, 14)
    l.Position           = UDim2.new(0, 10, 0, posY)
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = parent
    return l
end

local function uiProgress(parent, posY, fillCol)
    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 4)
    track.Position         = UDim2.new(0, 10, 0, posY)
    track.BackgroundColor3 = CP
    track.BorderSizePixel  = 0
    track.Parent           = parent
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = fillCol or CA
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    return fill
end

local function uiToggleRow(parent, label, posY, activeCol, inactiveCol)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -20, 0, 28)
    row.Position         = UDim2.new(0, 10, 0, posY)
    row.BackgroundColor3 = CP
    row.BorderSizePixel  = 0
    row.Parent           = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 11
    lbl.TextColor3         = CT
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(1, -55, 1, 0)
    lbl.Position           = UDim2.new(0, 8, 0, 0)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = row

    local tog = Instance.new("TextButton")
    tog.Text             = "OFF"
    tog.Font             = Enum.Font.GothamBold
    tog.TextSize         = 10
    tog.TextColor3       = CT
    tog.BackgroundColor3 = inactiveCol
    tog.Size             = UDim2.new(0, 38, 0, 18)
    tog.Position         = UDim2.new(1, -44, 0.5, -9)
    tog.BorderSizePixel  = 0
    tog.AutoButtonColor  = false
    tog.Parent           = row
    Instance.new("UICorner", tog).CornerRadius = UDim.new(0, 4)
    return tog, activeCol, inactiveCol
end

local function uiInputRow(parent, label, default, posY, strokeCol)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -20, 0, 28)
    row.Position         = UDim2.new(0, 10, 0, posY)
    row.BackgroundColor3 = CP
    row.BorderSizePixel  = 0
    row.Parent           = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 11
    lbl.TextColor3         = CT
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(0.57, 0, 1, 0)
    lbl.Position           = UDim2.new(0, 8, 0, 0)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = row

    local inp = Instance.new("TextBox")
    inp.Text             = tostring(default)
    inp.Font             = Enum.Font.GothamBold
    inp.TextSize         = 12
    inp.TextColor3       = CT
    inp.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    inp.Size             = UDim2.new(0.32, 0, 0, 20)
    inp.Position         = UDim2.new(0.63, 0, 0.5, -10)
    inp.BorderSizePixel  = 0
    inp.ClearTextOnFocus = false
    inp.TextXAlignment   = Enum.TextXAlignment.Center
    inp.Parent           = row
    Instance.new("UICorner", inp).CornerRadius = UDim.new(0, 4)
    local s = Instance.new("UIStroke")
    s.Color = strokeCol or CA3 ; s.Thickness = 1 ; s.Parent = inp
    return inp
end

-- ══════════════════════════════════════
--  MAIN PAGE LAYOUT
--  All Y positions are within mainPage
-- ══════════════════════════════════════

-- ── BREAKERS (y=5) ──
uiSection(mainPage, "BREAKERS", 5, CA2)

local breakerStatus = uiStatus(mainPage, 23, CA2)
breakerStatus.Text = "Status: ready"

local floorDisplay = uiStatus(mainPage, 38, CS)
floorDisplay.Text = "Floor: —"

local breakerProg = uiProgress(mainPage, 57, CA2)

-- Side-by-side buttons: ACTIVATE+TP (left, wider) | ACTIVATE (right)
local fireBtn = uiButton(
    mainPage, "ACTIVATE + TP  [V]", 65, 34,
    Color3.fromRGB(24, 72, 50),
    UDim2.new(0.62, -14, 0, 34),
    UDim2.new(0, 10, 0, 65)
)
local activateBtn = uiButton(
    mainPage, "ACTIVATE", 65, 34,
    Color3.fromRGB(20, 45, 38),
    UDim2.new(0.38, -6, 0, 34),
    UDim2.new(0.62, 0, 0, 65)
)
local actStroke = Instance.new("UIStroke")
actStroke.Color = CA2 ; actStroke.Thickness = 1 ; actStroke.Transparency = 0.5
actStroke.Parent = activateBtn

fireBtn.MouseEnter:Connect(function()
    if not busy then TweenService:Create(fireBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(34,100,70) }):Play() end
end)
fireBtn.MouseLeave:Connect(function()
    if not busy then TweenService:Create(fireBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(24,72,50) }):Play() end
end)
activateBtn.MouseEnter:Connect(function()
    if not busy then TweenService:Create(activateBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30,65,52) }):Play() end
end)
activateBtn.MouseLeave:Connect(function()
    if not busy then TweenService:Create(activateBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20,45,38) }):Play() end
end)

-- ── GENERATOR (y=112) ──
uiSection(mainPage, "GENERATOR", 112, CA)

local genStatus = uiStatus(mainPage, 130, CA)
genStatus.Text = "Status: ready  (A to Z)    bind: F"

local genProg = uiProgress(mainPage, 148, CA)

local genBtn = uiButton(mainPage, "SOLVE GENERATOR  [F]", 156, 34, Color3.fromRGB(28, 42, 105))
genBtn.MouseEnter:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42,62,148) }):Play()
end)
genBtn.MouseLeave:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28,42,105) }):Play()
end)

-- ── PLAYER (y=204) ──
uiSection(mainPage, "PLAYER", 204, CA3)

local godToggle, godActive, godInactive = uiToggleRow(
    mainPage, "God mode (auto-heal to max HP)", 222,
    Color3.fromRGB(28, 95, 55), Color3.fromRGB(55, 18, 18)
)
godToggle.BackgroundColor3 = Color3.fromRGB(55, 18, 18)

local healInput = uiInputRow(mainPage, "Heal amount:", 10, 256, CA2)
local damageValue = 10

healInput.FocusLost:Connect(function()
    local v = tonumber(healInput.Text)
    if v then damageValue = v else healInput.Text = tostring(damageValue) end
end)

local healStatus = uiStatus(mainPage, 289, CA2)
healStatus.Text = "Status: ready"

local healBtn = uiButton(mainPage, "HEAL PLAYER", 303, 34, Color3.fromRGB(30, 80, 45))
healBtn.MouseEnter:Connect(function()
    TweenService:Create(healBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42,112,62) }):Play()
end)
healBtn.MouseLeave:Connect(function()
    TweenService:Create(healBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30,80,45) }):Play()
end)

local nvToggle, nvActive, nvInactive = uiToggleRow(
    mainPage, "Night vision loop (every 10s)", 345,
    Color3.fromRGB(28, 55, 130), Color3.fromRGB(55, 18, 18)
)
nvToggle.BackgroundColor3 = Color3.fromRGB(55, 18, 18)

local cursorBtn = uiButton(mainPage, "CURSOR: UNLOCKED  [X]", 381, 34, Color3.fromRGB(35, 30, 60))
cursorBtn.MouseEnter:Connect(function()
    TweenService:Create(cursorBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(52,44,88) }):Play()
end)
cursorBtn.MouseLeave:Connect(function()
    TweenService:Create(cursorBtn, TweenInfo.new(0.1), {
        BackgroundColor3 = cursorLocked and Color3.fromRGB(50,40,90) or Color3.fromRGB(35,30,60)
    }):Play()
end)

-- ── ADD MONEY (y=428) ──
uiSection(mainPage, "ADD MONEY", 428, CA3)

local moneyInput = uiInputRow(mainPage, "Token amount:", 100, 446, CA3)
local moneyValue = 100

moneyInput.FocusLost:Connect(function()
    local v = tonumber(moneyInput.Text)
    if v then moneyValue = v else moneyInput.Text = tostring(moneyValue) end
end)

local moneyStatus = uiStatus(mainPage, 479, CA3)
moneyStatus.Text = "Status: ready"

local moneyBtn = uiButton(mainPage, "ADD MONEY", 493, 34, Color3.fromRGB(80, 55, 14))
moneyBtn.MouseEnter:Connect(function()
    TweenService:Create(moneyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(110,78,20) }):Play()
end)
moneyBtn.MouseLeave:Connect(function()
    TweenService:Create(moneyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(80,55,14) }):Play()
end)

mainPage.CanvasSize = UDim2.new(0, 0, 0, 540)

-- ══════════════════════════════════════
--  BINDS PAGE LAYOUT
-- ══════════════════════════════════════
local bindDefs = {
    { id = "menu",      label = "Toggle Menu" },
    { id = "breakers",  label = "Activate + TP" },
    { id = "generator", label = "Solve Generator" },
    { id = "cursor",    label = "Cursor Lock" },
}

local rebindBtns = {}
local rebinding  = nil  -- id currently being rebound

for i, def in ipairs(bindDefs) do
    local rowY = 10 + (i - 1) * 44

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -20, 0, 36)
    row.Position         = UDim2.new(0, 10, 0, rowY)
    row.BackgroundColor3 = CP
    row.BorderSizePixel  = 0
    row.Parent           = bindsPage
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Text               = def.label
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 12
    lbl.TextColor3         = CT
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(0.52, 0, 1, 0)
    lbl.Position           = UDim2.new(0, 10, 0, 0)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = row

    local keyBtn = Instance.new("TextButton")
    keyBtn.Text             = getKeyName(keybinds[def.id])
    keyBtn.Font             = Enum.Font.GothamBold
    keyBtn.TextSize         = 11
    keyBtn.TextColor3       = CT
    keyBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
    keyBtn.Size             = UDim2.new(0.35, 0, 0, 24)
    keyBtn.Position         = UDim2.new(0.57, 0, 0.5, -12)
    keyBtn.BorderSizePixel  = 0
    keyBtn.AutoButtonColor  = false
    keyBtn.Parent           = row
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 4)
    local ks = Instance.new("UIStroke")
    ks.Color = CBo ; ks.Thickness = 1 ; ks.Parent = keyBtn

    rebindBtns[def.id] = keyBtn

    local bindId = def.id
    keyBtn.MouseButton1Click:Connect(function()
        if rebinding then return end
        rebinding              = bindId
        keyBtn.Text            = "Press key..."
        keyBtn.TextColor3      = CA3
        keyBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 15)
    end)
end

local bindsNote = Instance.new("TextLabel")
bindsNote.Text               = "Click a key button, then press any key to rebind.  ESC = cancel"
bindsNote.Font               = Enum.Font.Gotham
bindsNote.TextSize           = 10
bindsNote.TextColor3         = CS
bindsNote.BackgroundTransparency = 1
bindsNote.Size               = UDim2.new(1, -20, 0, 28)
bindsNote.Position           = UDim2.new(0, 10, 0, 10 + #bindDefs * 44 + 8)
bindsNote.TextXAlignment     = Enum.TextXAlignment.Left
bindsNote.TextWrapped        = true
bindsNote.Parent             = bindsPage

-- ══════════════════════════════════════
--  BUTTON LOGIC
-- ══════════════════════════════════════

-- God mode toggle
godToggle.MouseButton1Click:Connect(function()
    godModeEnabled = not godModeEnabled
    if godModeEnabled then
        godToggle.Text             = "ON"
        godToggle.BackgroundColor3 = godActive
        startGodMode()
    else
        godToggle.Text             = "OFF"
        godToggle.BackgroundColor3 = godInactive
        stopGodMode()
    end
end)

-- Heal player
healBtn.MouseButton1Click:Connect(function()
    local v = tonumber(healInput.Text) or damageValue
    damageValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(-damageValue, "Weeping")
    end)
    healStatus.Text       = "Healed: +" .. damageValue .. " HP"
    healStatus.TextColor3 = CA2
    task.delay(2, function()
        healStatus.Text       = "Status: ready"
        healStatus.TextColor3 = CA2
    end)
end)

-- Night vision toggle
nvToggle.MouseButton1Click:Connect(function()
    nightVisionEnabled = not nightVisionEnabled
    if nightVisionEnabled then
        nvToggle.Text             = "ON"
        nvToggle.BackgroundColor3 = nvActive
        startNightVision()
    else
        nvToggle.Text             = "OFF"
        nvToggle.BackgroundColor3 = nvInactive
        stopNightVision()
    end
end)

-- Cursor lock
local function toggleCursor()
    setCursorLock(not cursorLocked)
    cursorBtn.Text = cursorLocked
        and "CURSOR: LOCKED  [" .. getKeyName(keybinds.cursor) .. "]"
        or  "CURSOR: UNLOCKED  [" .. getKeyName(keybinds.cursor) .. "]"
    cursorBtn.BackgroundColor3 = cursorLocked
        and Color3.fromRGB(50, 40, 90)
        or  Color3.fromRGB(35, 30, 60)
end

cursorBtn.MouseButton1Click:Connect(toggleCursor)

-- Add money
moneyBtn.MouseButton1Click:Connect(function()
    local v = tonumber(moneyInput.Text) or moneyValue
    moneyValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("QuestRemotes"):WaitForChild("Reward"):FireServer("Tokens", moneyValue)
    end)
    moneyStatus.Text       = "Sent: Tokens x" .. moneyValue
    moneyStatus.TextColor3 = CA3
    task.delay(2, function()
        moneyStatus.Text       = "Status: ready"
        moneyStatus.TextColor3 = CA3
    end)
end)

-- Floor display live update
task.spawn(function()
    while scriptActive do
        local fo = getFloorObj()
        if fo then
            floorDisplay.Text = "Floor: " .. tostring(fo.Value)
        else
            floorDisplay.Text = "Floor: —"
        end
        task.wait(0.5)
    end
end)

-- ── GENERATOR ──
local generatorBusy = false

local function runGenerator()
    if generatorBusy then return end
    generatorBusy = true
    genBtn.BackgroundColor3 = Color3.fromRGB(16, 18, 38)
    genBtn.Text = "Running..."

    task.spawn(function()
        local genR = ReplicatedStorage:WaitForChild("Generator_Events"):WaitForChild("GeneratorFixed")

        pcall(function() genR:FireServer("GeneratorStart") end)
        genStatus.Text       = "Fired: GeneratorStart"
        genStatus.TextColor3 = CA
        task.wait(0.1)

        for idx = 65, 90 do
            local letter = string.char(idx)
            pcall(function() genR:FireServer(letter) end)
            local rel = (idx - 64) / 26
            TweenService:Create(genProg, TweenInfo.new(0.04), { Size = UDim2.new(rel, 0, 1, 0) }):Play()
            genStatus.Text       = "Firing: " .. letter .. "  (" .. (idx - 64) .. "/26)"
            genStatus.TextColor3 = CA
            task.wait(0.05)
        end

        genStatus.Text       = "Done — GeneratorStart + A to Z sent"
        genStatus.TextColor3 = Color3.fromRGB(110, 195, 255)
        task.wait(2.5)
        TweenService:Create(genProg, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 1, 0) }):Play()
        genBtn.Text = "SOLVE GENERATOR  [F]"
        TweenService:Create(genBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(28, 42, 105) }):Play()
        genStatus.Text       = "Status: ready  (A to Z)    bind: F"
        genStatus.TextColor3 = CA
        generatorBusy = false
    end)
end

genBtn.MouseButton1Click:Connect(runGenerator)

-- ── BREAKER SHARED CALLBACKS ──
local function onBreakerProgress(i, total)
    local rel = i / total
    TweenService:Create(breakerProg, TweenInfo.new(FIRE_DELAY * 0.9), { Size = UDim2.new(rel, 0, 1, 0) }):Play()
    breakerProg.BackgroundColor3 = CA2
    breakerStatus.Text           = "Activating: " .. i .. " / " .. total
    breakerStatus.TextColor3     = CA2
end

local function onBreakerDone(success, total)
    if total == 0 then
        breakerStatus.Text       = "No breakers found"
        breakerStatus.TextColor3 = CA4
    else
        breakerStatus.Text       = success .. "/" .. total .. " activated"
        breakerStatus.TextColor3 = CA2
    end
    task.wait(2.5)
    TweenService:Create(breakerProg, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    fireBtn.Text     = "ACTIVATE + TP  [V]"
    activateBtn.Text = "ACTIVATE"
    TweenService:Create(fireBtn,     TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(24, 72, 50) }):Play()
    TweenService:Create(activateBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(20, 45, 38) }):Play()
    breakerStatus.Text       = "Status: ready"
    breakerStatus.TextColor3 = CA2
end

-- ── ACTIVATE + TP ──
-- Sequence:
--   1. Smooth slide to 0, 5, 5
--   2. Run scanAndFire (no teleport)
--   3. Wait 2 seconds
--   4. Smooth slide to 20, 5, 6
--   5. Try Floors remote to help floor registration (best-effort)
local function startFire()
    if busy then return end
    fireBtn.BackgroundColor3 = Color3.fromRGB(16, 26, 20)
    fireBtn.Text             = "Sliding..."

    task.spawn(function()
        breakerStatus.Text       = "Sliding to position..."
        breakerStatus.TextColor3 = Color3.fromRGB(120, 160, 255)

        -- Phase 1: smooth slide to activation position
        smoothTeleport(0, 5, 5, 0.45)

        fireBtn.Text = "Activating..."

        -- Capture floor value before activating
        local floorBefore = nil
        local fo = getFloorObj()
        if fo then floorBefore = fo.Value end

        -- Phase 2: activate breakers (no extra teleport inside)
        scanAndFire(
            function(s)
                breakerStatus.Text       = s
                breakerStatus.TextColor3 = CA2
            end,
            onBreakerProgress,
            function(success, total)
                -- Phase 3: wait 2 seconds
                breakerStatus.Text       = "Waiting 2s before returning..."
                breakerStatus.TextColor3 = CS
                task.wait(2)

                -- Phase 4: smooth slide back toward elevator
                breakerStatus.Text       = "Sliding back..."
                breakerStatus.TextColor3 = Color3.fromRGB(120, 160, 255)
                smoothTeleport(20, 5, 6, 0.45)

                -- Phase 5: give the game a moment to detect the player
                -- in the elevator area (collision / touched events)
                task.wait(0.5)

                -- Attempt to advance floor if it hasn't changed
                local foNow = getFloorObj()
                if foNow and floorBefore ~= nil and foNow.Value == floorBefore then
                    pcall(function()
                        ReplicatedStorage:WaitForChild("QuestRemotes")
                            :WaitForChild("Floors"):FireServer()
                    end)
                    breakerStatus.Text       = "Floor advance fired (was " .. floorBefore .. ")"
                    breakerStatus.TextColor3 = CS
                    task.wait(1)
                end

                onBreakerDone(success, total)
            end
        )
    end)
end

-- ── ACTIVATE (no teleport) ──
local function startFireNoTeleport()
    if busy then return end
    activateBtn.BackgroundColor3 = Color3.fromRGB(14, 30, 22)
    activateBtn.Text             = "Running..."

    task.spawn(function()
        scanAndFire(
            function(s)
                breakerStatus.Text       = s
                breakerStatus.TextColor3 = CA2
            end,
            onBreakerProgress,
            onBreakerDone
        )
    end)
end

fireBtn.MouseButton1Click:Connect(startFire)
activateBtn.MouseButton1Click:Connect(startFireNoTeleport)

-- ══════════════════════════════════════
--  KEYBIND INPUT
-- ══════════════════════════════════════
local menuOpen = false

UserInputService.InputBegan:Connect(function(inp, processed)
    if not scriptActive then return end

    -- Rebind capture runs before processed check
    if rebinding and inp.UserInputType == Enum.UserInputType.Keyboard then
        local newKey = inp.KeyCode
        local btn    = rebindBtns[rebinding]
        if newKey == Enum.KeyCode.Escape then
            -- cancel
            if btn then
                btn.Text             = getKeyName(keybinds[rebinding])
                btn.TextColor3       = CT
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
            end
        else
            keybinds[rebinding] = newKey
            if btn then
                btn.Text             = getKeyName(newKey)
                btn.TextColor3       = CT
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
            end
            refreshHint()
        end
        rebinding = nil
        return
    end

    if processed then return end

    if inp.KeyCode == keybinds.menu then
        menuOpen = not menuOpen
        frame.Visible = menuOpen

    elseif inp.KeyCode == keybinds.breakers then
        startFire()

    elseif inp.KeyCode == keybinds.generator then
        runGenerator()

    elseif inp.KeyCode == keybinds.cursor then
        toggleCursor()
    end
end)

-- ══════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════
local function unload()
    scriptActive = false          -- disables all keybind handlers permanently
    stopNightVision()
    stopGodMode()
    setCursorLock(false)          -- always restore cursor on unload
    task.wait(0.05)
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
    print("[Menu] v1.4 unloaded — all loops stopped, keybinds disabled")
end

unloadBtn.MouseButton1Click:Connect(unload)

print("[Menu] v1.4 loaded — " ..
    getKeyName(keybinds.menu) .. "=menu  " ..
    getKeyName(keybinds.breakers) .. "=breakers  " ..
    getKeyName(keybinds.generator) .. "=generator  " ..
    getKeyName(keybinds.cursor) .. "=cursor"
)