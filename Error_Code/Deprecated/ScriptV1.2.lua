-- Menu | G = toggle menu | V = breakers | C = generator

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ──────────────── CONFIG ────────────────
local FIRE_DELAY = 0.02
-- ────────────────────────────────────────

local AbilityEvents     = ReplicatedStorage:WaitForChild("AbilityEvents")
local UltraMechanicUsed = AbilityEvents:WaitForChild("UltraMechanicUsed")

-- ─────────── TELEPORT ───────────────────
local function teleportTo(x, y, z)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(x, y, z)
        end
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
            if isBreaker then
                table.insert(prompts, obj)
            end
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

-- ─────────── NIGHT VISION LOOP ───────────────────
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

-- ─────────── GOD MODE ───────────────────
local godModeEnabled   = false
local godModeThread    = nil

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
            task.wait(0.5)
        end
        godModeThread = nil
    end)
end

local function stopGodMode()
    godModeEnabled = false
    godModeThread  = nil
end

-- ─────────── BUILD GUI ───────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MainMenu"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

-- Theme
local COL_BG      = Color3.fromRGB(12, 12, 18)
local COL_PANEL   = Color3.fromRGB(20, 20, 30)
local COL_BORDER  = Color3.fromRGB(55, 55, 90)
local COL_ACCENT  = Color3.fromRGB(80, 120, 255)
local COL_ACCENT2 = Color3.fromRGB(55, 190, 120)
local COL_ACCENT3 = Color3.fromRGB(210, 150, 40)
local COL_ACCENT4 = Color3.fromRGB(200, 65, 65)
local COL_TEXT    = Color3.fromRGB(205, 205, 215)
local COL_SUB     = Color3.fromRGB(100, 100, 120)

-- Main frame
local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, 300, 0, 480)
frame.Position         = UDim2.new(0.5, -150, 0.5, -240)
frame.BackgroundColor3 = COL_BG
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Visible          = false
frame.Parent           = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local fstroke = Instance.new("UIStroke")
fstroke.Color     = COL_BORDER
fstroke.Thickness = 1.2
fstroke.Parent    = frame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = COL_PANEL
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
local tpatch = Instance.new("Frame")
tpatch.Size             = UDim2.new(1, 0, 0, 8)
tpatch.Position         = UDim2.new(0, 0, 1, -8)
tpatch.BackgroundColor3 = COL_PANEL
tpatch.BorderSizePixel  = 0
tpatch.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Text               = "MENU  //  v1.2"
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.TextSize           = 13
titleLabel.TextColor3         = COL_TEXT
titleLabel.BackgroundTransparency = 1
titleLabel.Size               = UDim2.new(1, -130, 1, 0)
titleLabel.Position           = UDim2.new(0, 12, 0, 0)
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

-- Unload button
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
local unloadStroke = Instance.new("UIStroke")
unloadStroke.Color     = Color3.fromRGB(120, 90, 20)
unloadStroke.Thickness = 1
unloadStroke.Parent    = unloadBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Text             = "X"
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 12
closeBtn.TextColor3       = COL_ACCENT4
closeBtn.BackgroundColor3 = Color3.fromRGB(38, 16, 16)
closeBtn.Size             = UDim2.new(0, 26, 0, 20)
closeBtn.Position         = UDim2.new(1, -32, 0.5, -10)
closeBtn.BorderSizePixel  = 0
closeBtn.AutoButtonColor  = false
closeBtn.Parent           = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Hint line
local hintLine = Instance.new("TextLabel")
hintLine.Text               = "G = menu    V = breakers (teleport)    C = generator"
hintLine.Font               = Enum.Font.Gotham
hintLine.TextSize           = 10
hintLine.TextColor3         = COL_SUB
hintLine.BackgroundTransparency = 1
hintLine.Size               = UDim2.new(1, -20, 0, 14)
hintLine.Position           = UDim2.new(0, 10, 0, 42)
hintLine.TextXAlignment     = Enum.TextXAlignment.Left
hintLine.Parent             = frame

-- ── Helpers ──
local function makeSection(label, posY, col)
    local line = Instance.new("Frame")
    line.Size             = UDim2.new(1, -20, 0, 1)
    line.Position         = UDim2.new(0, 10, 0, posY + 13)
    line.BackgroundColor3 = col or COL_BORDER
    line.BorderSizePixel  = 0
    line.Parent           = frame

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 10
    lbl.TextColor3         = col or COL_ACCENT
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(0.5, 0, 0, 14)
    lbl.Position           = UDim2.new(0, 10, 0, posY)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = frame
end

local function makeButton(text, posY, height, bgCol, w, xOffset)
    local btn = Instance.new("TextButton")
    btn.Text             = text
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 12
    btn.TextColor3       = COL_TEXT
    btn.BackgroundColor3 = bgCol or COL_ACCENT
    btn.Size             = w or UDim2.new(1, -20, 0, height or 34)
    btn.Position         = UDim2.new(0, xOffset or 10, 0, posY)
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local function makeStatus(posY, col)
    local l = Instance.new("TextLabel")
    l.Text               = "Status: ready"
    l.Font               = Enum.Font.Gotham
    l.TextSize           = 11
    l.TextColor3         = col or COL_SUB
    l.BackgroundTransparency = 1
    l.Size               = UDim2.new(1, -20, 0, 14)
    l.Position           = UDim2.new(0, 10, 0, posY)
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = frame
    return l
end

local function makeProgress(posY, fillCol)
    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 4)
    track.Position         = UDim2.new(0, 10, 0, posY)
    track.BackgroundColor3 = COL_PANEL
    track.BorderSizePixel  = 0
    track.Parent           = frame
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = fillCol or COL_ACCENT
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    return fill
end

local function makeToggleRow(labelText, posY, activeCol, inactiveCol)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -20, 0, 28)
    row.Position         = UDim2.new(0, 10, 0, posY)
    row.BackgroundColor3 = COL_PANEL
    row.BorderSizePixel  = 0
    row.Parent           = frame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Text               = labelText
    lbl.Font               = Enum.Font.Gotham
    lbl.TextSize           = 11
    lbl.TextColor3         = COL_TEXT
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(1, -55, 1, 0)
    lbl.Position           = UDim2.new(0, 8, 0, 0)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = row

    local tog = Instance.new("TextButton")
    tog.Text             = "OFF"
    tog.Font             = Enum.Font.GothamBold
    tog.TextSize         = 10
    tog.TextColor3       = COL_TEXT
    tog.BackgroundColor3 = inactiveCol or Color3.fromRGB(55, 18, 18)
    tog.Size             = UDim2.new(0, 38, 0, 18)
    tog.Position         = UDim2.new(1, -44, 0.5, -9)
    tog.BorderSizePixel  = 0
    tog.AutoButtonColor  = false
    tog.Parent           = row
    Instance.new("UICorner", tog).CornerRadius = UDim.new(0, 4)
    return tog
end

-- ══════════════════════════════════
--  SECTION: BREAKERS  y=62
-- ══════════════════════════════════
makeSection("BREAKERS", 62, COL_ACCENT2)

local breakerStatus = makeStatus(80, COL_ACCENT2)
breakerStatus.Text = "Status: ready"

local breakerProg = makeProgress(98, COL_ACCENT2)

-- Two buttons side by side: main teleport button + plain activate button
local fireBtn = makeButton(
    "SCAN + ACTIVATE  [V]", 106, 34,
    Color3.fromRGB(24, 72, 50),
    UDim2.new(0.63, -14, 0, 34), 10
)
fireBtn.TextSize = 11

local activateBtn = makeButton(
    "ACTIVATE", 106, 34,
    Color3.fromRGB(20, 45, 38),
    UDim2.new(0.37, -6, 0, 34),
    UDim2.new(0.63, -1, 0, 106) -- will reposition below
)
-- Reposition activateBtn properly
activateBtn.Position = UDim2.new(0.63, 0, 0, 106)
activateBtn.Size     = UDim2.new(0.37, -10, 0, 34)
activateBtn.TextSize = 11
local activateStroke = Instance.new("UIStroke")
activateStroke.Color     = COL_ACCENT2
activateStroke.Thickness = 1
activateStroke.Transparency = 0.5
activateStroke.Parent    = activateBtn

fireBtn.MouseEnter:Connect(function()
    if not busy then TweenService:Create(fireBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(34, 100, 70) }):Play() end
end)
fireBtn.MouseLeave:Connect(function()
    if not busy then TweenService:Create(fireBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(24, 72, 50) }):Play() end
end)
activateBtn.MouseEnter:Connect(function()
    if not busy then TweenService:Create(activateBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 65, 52) }):Play() end
end)
activateBtn.MouseLeave:Connect(function()
    if not busy then TweenService:Create(activateBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20, 45, 38) }):Play() end
end)

-- ══════════════════════════════════
--  SECTION: GENERATOR  y=153
-- ══════════════════════════════════
makeSection("GENERATOR", 153, COL_ACCENT)

local genStatus = makeStatus(171, COL_ACCENT)
genStatus.Text = "Status: ready  (A to Z)    bind: C"

local genProg = makeProgress(189, COL_ACCENT)

local genBtn = makeButton("SOLVE GENERATOR  [C]", 197, 34, Color3.fromRGB(28, 42, 105))
genBtn.MouseEnter:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42, 62, 148) }):Play()
end)
genBtn.MouseLeave:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28, 42, 105) }):Play()
end)

local generatorBusy = false

local function runGenerator()
    if generatorBusy then return end
    generatorBusy = true
    genBtn.BackgroundColor3 = Color3.fromRGB(16, 18, 38)
    genBtn.Text = "Running..."

    task.spawn(function()
        local genRemote = ReplicatedStorage:WaitForChild("Generator_Events"):WaitForChild("GeneratorFixed")

        pcall(function() genRemote:FireServer("GeneratorStart") end)
        genStatus.Text       = "Fired: GeneratorStart"
        genStatus.TextColor3 = COL_ACCENT
        task.wait(0.1)

        for idx = 65, 90 do
            local letter = string.char(idx)
            pcall(function() genRemote:FireServer(letter) end)
            local rel = (idx - 64) / 26
            TweenService:Create(genProg, TweenInfo.new(0.04), {
                Size = UDim2.new(rel, 0, 1, 0)
            }):Play()
            genStatus.Text       = "Firing: " .. letter .. "  (" .. (idx - 64) .. "/26)"
            genStatus.TextColor3 = COL_ACCENT
            task.wait(0.05)
        end

        genStatus.Text       = "Done — GeneratorStart + A to Z sent"
        genStatus.TextColor3 = Color3.fromRGB(110, 195, 255)
        task.wait(2.5)
        TweenService:Create(genProg, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 1, 0) }):Play()
        genBtn.Text = "SOLVE GENERATOR  [C]"
        TweenService:Create(genBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(28, 42, 105) }):Play()
        genStatus.Text       = "Status: ready  (A to Z)    bind: C"
        genStatus.TextColor3 = COL_ACCENT
        generatorBusy = false
    end)
end

genBtn.MouseButton1Click:Connect(runGenerator)

-- ══════════════════════════════════
--  SECTION: PLAYER  y=244
-- ══════════════════════════════════
makeSection("PLAYER", 244, COL_ACCENT3)

-- ── God Mode ──
local godToggle = makeToggleRow("God mode (auto-heal to max HP)", 262, Color3.fromRGB(28, 95, 55), Color3.fromRGB(55, 18, 18))
godToggle.BackgroundColor3 = Color3.fromRGB(55, 18, 18)

godToggle.MouseButton1Click:Connect(function()
    godModeEnabled = not godModeEnabled
    if godModeEnabled then
        godToggle.Text             = "ON"
        godToggle.BackgroundColor3 = Color3.fromRGB(28, 95, 55)
        startGodMode()
    else
        godToggle.Text             = "OFF"
        godToggle.BackgroundColor3 = Color3.fromRGB(55, 18, 18)
        stopGodMode()
    end
end)

-- ── Heal Player ──
local dmgRow = Instance.new("Frame")
dmgRow.Size             = UDim2.new(1, -20, 0, 28)
dmgRow.Position         = UDim2.new(0, 10, 0, 298)
dmgRow.BackgroundColor3 = COL_PANEL
dmgRow.BorderSizePixel  = 0
dmgRow.Parent           = frame
Instance.new("UICorner", dmgRow).CornerRadius = UDim.new(0, 6)

local dmgLbl = Instance.new("TextLabel")
dmgLbl.Text               = "Manual heal value:"
dmgLbl.Font               = Enum.Font.Gotham
dmgLbl.TextSize           = 11
dmgLbl.TextColor3         = COL_TEXT
dmgLbl.BackgroundTransparency = 1
dmgLbl.Size               = UDim2.new(0.57, 0, 1, 0)
dmgLbl.Position           = UDim2.new(0, 8, 0, 0)
dmgLbl.TextXAlignment     = Enum.TextXAlignment.Left
dmgLbl.Parent             = dmgRow

local damageValue = 10
local dmgInput = Instance.new("TextBox")
dmgInput.Text             = tostring(damageValue)
dmgInput.Font             = Enum.Font.GothamBold
dmgInput.TextSize         = 12
dmgInput.TextColor3       = COL_TEXT
dmgInput.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
dmgInput.Size             = UDim2.new(0.32, 0, 0, 20)
dmgInput.Position         = UDim2.new(0.63, 0, 0.5, -10)
dmgInput.BorderSizePixel  = 0
dmgInput.ClearTextOnFocus = false
dmgInput.TextXAlignment   = Enum.TextXAlignment.Center
dmgInput.Parent           = dmgRow
Instance.new("UICorner", dmgInput).CornerRadius = UDim.new(0, 4)
local dmgStroke = Instance.new("UIStroke")
dmgStroke.Color     = COL_ACCENT3
dmgStroke.Thickness = 1
dmgStroke.Parent    = dmgInput

dmgInput.FocusLost:Connect(function()
    local val = tonumber(dmgInput.Text)
    if val then
        damageValue = val
    else
        dmgInput.Text = tostring(damageValue)
    end
end)

local dmgFireStatus = makeStatus(331, COL_ACCENT3)
dmgFireStatus.Text = "Status: ready"

local dmgBtn = makeButton("HEAL PLAYER", 345, 34, Color3.fromRGB(30, 80, 45))
dmgBtn.MouseEnter:Connect(function()
    TweenService:Create(dmgBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42, 112, 62) }):Play()
end)
dmgBtn.MouseLeave:Connect(function()
    TweenService:Create(dmgBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 80, 45) }):Play()
end)
dmgBtn.MouseButton1Click:Connect(function()
    local val = tonumber(dmgInput.Text) or damageValue
    damageValue = val
    pcall(function()
        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(-damageValue, "Weeping")
    end)
    dmgFireStatus.Text       = "Healed: " .. damageValue .. " HP"
    dmgFireStatus.TextColor3 = COL_ACCENT2
    task.delay(2, function()
        dmgFireStatus.Text       = "Status: ready"
        dmgFireStatus.TextColor3 = COL_ACCENT3
    end)
end)

-- ── Night Vision ──
local nvToggle = makeToggleRow("Night vision loop (every 10s)", 387, Color3.fromRGB(28, 55, 130), Color3.fromRGB(55, 18, 18))
nvToggle.BackgroundColor3 = Color3.fromRGB(55, 18, 18)

local nvStatus = makeStatus(420, Color3.fromRGB(140, 175, 255))
nvStatus.Text = "Night vision: off"

nvToggle.MouseButton1Click:Connect(function()
    nightVisionEnabled = not nightVisionEnabled
    if nightVisionEnabled then
        nvToggle.Text             = "ON"
        nvToggle.BackgroundColor3 = Color3.fromRGB(28, 55, 130)
        nvStatus.Text             = "Night vision: active — fires every 10s"
        nvStatus.TextColor3       = Color3.fromRGB(140, 175, 255)
        startNightVision()
    else
        nvToggle.Text             = "OFF"
        nvToggle.BackgroundColor3 = Color3.fromRGB(55, 18, 18)
        nvStatus.Text             = "Night vision: off"
        nvStatus.TextColor3       = Color3.fromRGB(140, 175, 255)
        stopNightVision()
    end
end)

-- ══════════════════════════════════
--  BREAKER CALLBACKS
-- ══════════════════════════════════
local function onBreakerProgress(i, total)
    local rel = i / total
    TweenService:Create(breakerProg, TweenInfo.new(FIRE_DELAY * 0.9), {
        Size = UDim2.new(rel, 0, 1, 0)
    }):Play()
    breakerProg.BackgroundColor3 = COL_ACCENT2
    breakerStatus.Text           = "Activating: " .. i .. " / " .. total
    breakerStatus.TextColor3     = COL_ACCENT2
end

local function onBreakerDone(success, total)
    if total == 0 then
        breakerStatus.Text       = "No breakers found"
        breakerStatus.TextColor3 = COL_ACCENT4
    else
        breakerStatus.Text       = success .. "/" .. total .. " activated"
        breakerStatus.TextColor3 = COL_ACCENT2
    end
    task.wait(2.5)
    breakerProg.BackgroundColor3 = COL_ACCENT2
    TweenService:Create(breakerProg, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    fireBtn.Text     = "SCAN + ACTIVATE  [V]"
    activateBtn.Text = "ACTIVATE"
    TweenService:Create(fireBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(24, 72, 50) }):Play()
    TweenService:Create(activateBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(20, 45, 38) }):Play()
    breakerStatus.Text       = "Status: ready"
    breakerStatus.TextColor3 = COL_ACCENT2
end

-- Fire WITH teleport (keybind V + main button)
local function startFire()
    if busy then return end
    fireBtn.BackgroundColor3 = Color3.fromRGB(16, 26, 20)
    fireBtn.Text = "Teleporting..."

    task.spawn(function()
        breakerStatus.Text       = "Teleporting..."
        breakerStatus.TextColor3 = Color3.fromRGB(120, 160, 255)

        teleportTo(0, 5.5, 6)
        task.wait(0.5)

        teleportTo(19, 5.5, 6)
        task.wait(0.3)

        fireBtn.Text = "Running..."
        scanAndFire(
            function(s)
                breakerStatus.Text       = s
                breakerStatus.TextColor3 = COL_ACCENT2
            end,
            onBreakerProgress,
            onBreakerDone
        )
    end)
end

-- Fire WITHOUT teleport (ACTIVATE button)
local function startFireNoTeleport()
    if busy then return end
    activateBtn.BackgroundColor3 = Color3.fromRGB(14, 30, 22)
    activateBtn.Text = "Running..."

    task.spawn(function()
        scanAndFire(
            function(s)
                breakerStatus.Text       = s
                breakerStatus.TextColor3 = COL_ACCENT2
            end,
            onBreakerProgress,
            onBreakerDone
        )
    end)
end

fireBtn.MouseButton1Click:Connect(startFire)
activateBtn.MouseButton1Click:Connect(startFireNoTeleport)

-- ─────────── KEYBINDS ───────────────────
local menuOpen = false
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.G then
        menuOpen = not menuOpen
        frame.Visible = menuOpen
    end
    if inp.KeyCode == Enum.KeyCode.V then
        startFire()
    end
    if inp.KeyCode == Enum.KeyCode.C then
        runGenerator()
    end
end)

-- ─────────── UNLOAD ───────────────────
local function unload()
    stopNightVision()
    stopGodMode()
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
    print("[Menu] Unloaded")
end

unloadBtn.MouseButton1Click:Connect(unload)

print("[Menu] v1.2 loaded — G = menu | V = breakers | C = generator")