-- Menu | G = toggle menu / generator | V = breakers

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ──────────────── CONFIG ────────────────
local FIRE_DELAY   = 0.02
-- ────────────────────────────────────────

-- Remotes
local QuestRemotes      = ReplicatedStorage:WaitForChild("QuestRemotes")
local BreakersRemote    = QuestRemotes:WaitForChild("Breakers")
local FloorsRemote      = QuestRemotes:WaitForChild("Floors")
local AbilityEvents     = ReplicatedStorage:WaitForChild("AbilityEvents")
local UltraMechanicUsed = AbilityEvents:WaitForChild("UltraMechanicUsed")
local JumpscareRemote   = ReplicatedStorage:WaitForChild("Jumpscare")

-- ─────────── JUMPSCARE TRACKER ───────────────────
local badBreakers  = {}
local jumpscareNow = false

JumpscareRemote.OnClientEvent:Connect(function()
    jumpscareNow = true
    task.delay(1, function() jumpscareNow = false end)
end)

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

local function scanAndFire(skipJumpscare, onStatus, onProgress, onDone)
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

    local total   = #prompts
    local skipped = 0

    if total == 0 then
        if onDone then onDone(0, 0, 0) end
        busy = false
        return
    end

    if onStatus then onStatus("Found " .. total .. " — activating...") end

    local success = 0
    for i, prompt in ipairs(prompts) do
        if skipJumpscare and badBreakers[prompt] then
            skipped += 1
            if onProgress then onProgress(i, total, true) end
        else
            jumpscareNow = false
            local ok = pcall(function()
                UltraMechanicUsed:FireServer()
                if fireproximityprompt then
                    local old = prompt.MaxActivationDistance
                    prompt.MaxActivationDistance = 9e9
                    pcall(fireproximityprompt, prompt)
                    prompt.MaxActivationDistance = old
                end
            end)
            task.wait(0.02)
            if jumpscareNow then
                badBreakers[prompt] = true
                skipped += 1
                if onProgress then onProgress(i, total, true) end
            else
                if ok then success += 1 end
                if onProgress then onProgress(i, total, false) end
            end
        end
        if FIRE_DELAY > 0 then task.wait(FIRE_DELAY) end
    end

    if onDone then onDone(success, total, skipped) end
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
            task.wait(11)
        end
        nightVisionThread = nil
    end)
end

local function stopNightVision()
    nightVisionEnabled = false
    nightVisionThread  = nil
end

-- ─────────── EXPERIMENTAL: DAMAGE VALUE ───────────────────
local damageValue = 10  -- change this value as needed

-- ─────────── BUILD GUI ───────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MainMenu"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

-- Theme colors
local COL_BG       = Color3.fromRGB(14, 14, 20)
local COL_PANEL    = Color3.fromRGB(20, 20, 30)
local COL_BORDER   = Color3.fromRGB(60, 60, 100)
local COL_ACCENT   = Color3.fromRGB(80, 120, 255)
local COL_ACCENT2  = Color3.fromRGB(60, 200, 130)
local COL_ACCENT3  = Color3.fromRGB(220, 160, 50)
local COL_ACCENT4  = Color3.fromRGB(200, 70, 70)
local COL_TEXT     = Color3.fromRGB(210, 210, 220)
local COL_SUBTEXT  = Color3.fromRGB(110, 110, 130)

-- Main frame
local frame = Instance.new("Frame")
frame.Name            = "Main"
frame.Size            = UDim2.new(0, 300, 0, 520)
frame.Position        = UDim2.new(0.5, -150, 0.5, -260)
frame.BackgroundColor3 = COL_BG
frame.BorderSizePixel = 0
frame.Active          = true
frame.Draggable       = true
frame.Visible         = false
frame.Parent          = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local fstroke = Instance.new("UIStroke")
fstroke.Color     = COL_BORDER
fstroke.Thickness = 1.2
fstroke.Parent    = frame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = COL_PANEL
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
-- patch bottom corners
local tpatch = Instance.new("Frame")
tpatch.Size             = UDim2.new(1, 0, 0, 8)
tpatch.Position         = UDim2.new(0, 0, 1, -8)
tpatch.BackgroundColor3 = COL_PANEL
tpatch.BorderSizePixel  = 0
tpatch.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Text               = "MENU  //  v2.0"
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.TextSize           = 13
titleLabel.TextColor3         = COL_TEXT
titleLabel.BackgroundTransparency = 1
titleLabel.Size               = UDim2.new(1, -50, 1, 0)
titleLabel.Position           = UDim2.new(0, 12, 0, 0)
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Text               = "X"
closeBtn.Font               = Enum.Font.GothamBold
closeBtn.TextSize           = 12
closeBtn.TextColor3         = COL_ACCENT4
closeBtn.BackgroundColor3   = Color3.fromRGB(40, 18, 18)
closeBtn.Size               = UDim2.new(0, 26, 0, 20)
closeBtn.Position           = UDim2.new(1, -32, 0.5, -10)
closeBtn.BorderSizePixel    = 0
closeBtn.AutoButtonColor    = false
closeBtn.Parent             = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- hint line
local hintLine = Instance.new("TextLabel")
hintLine.Text               = "G = menu / generator    V = breakers"
hintLine.Font               = Enum.Font.Gotham
hintLine.TextSize           = 10
hintLine.TextColor3         = COL_SUBTEXT
hintLine.BackgroundTransparency = 1
hintLine.Size               = UDim2.new(1, -20, 0, 14)
hintLine.Position           = UDim2.new(0, 10, 0, 43)
hintLine.TextXAlignment     = Enum.TextXAlignment.Left
hintLine.Parent             = frame

-- ── Helper: section header ──
local function makeSection(label, posY, col)
    local line = Instance.new("Frame")
    line.Size             = UDim2.new(1, -20, 0, 1)
    line.Position         = UDim2.new(0, 10, 0, posY + 11)
    line.BackgroundColor3 = col or COL_BORDER
    line.BorderSizePixel  = 0
    line.Parent           = frame

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 10
    lbl.TextColor3         = col or COL_ACCENT
    lbl.BackgroundTransparency = 1
    lbl.Size               = UDim2.new(0, 100, 0, 12)
    lbl.Position           = UDim2.new(0, 10, 0, posY)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = frame
end

-- ── Helper: standard button ──
local function makeButton(text, posY, height, bgCol)
    local btn = Instance.new("TextButton")
    btn.Text             = text
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 12
    btn.TextColor3       = COL_TEXT
    btn.BackgroundColor3 = bgCol or COL_ACCENT
    btn.Size             = UDim2.new(1, -20, 0, height or 34)
    btn.Position         = UDim2.new(0, 10, 0, posY)
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- ── Helper: status label ──
local function makeStatus(posY, col)
    local l = Instance.new("TextLabel")
    l.Text               = "Status: ready"
    l.Font               = Enum.Font.Gotham
    l.TextSize           = 11
    l.TextColor3         = col or COL_SUBTEXT
    l.BackgroundTransparency = 1
    l.Size               = UDim2.new(1, -20, 0, 14)
    l.Position           = UDim2.new(0, 10, 0, posY)
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = frame
    return l
end

-- ── Helper: progress bar ──
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

-- ══════════════════════════════════
--  SECTION: BREAKERS   (y=62)
-- ══════════════════════════════════
makeSection("BREAKERS", 62, COL_ACCENT2)

-- Skip jumpscare row
local skipRow = Instance.new("Frame")
skipRow.Size             = UDim2.new(1, -20, 0, 28)
skipRow.Position         = UDim2.new(0, 10, 0, 78)
skipRow.BackgroundColor3 = COL_PANEL
skipRow.BorderSizePixel  = 0
skipRow.Parent           = frame
Instance.new("UICorner", skipRow).CornerRadius = UDim.new(0, 6)

local skipLbl = Instance.new("TextLabel")
skipLbl.Text               = "Skip jumpscare breakers"
skipLbl.Font               = Enum.Font.Gotham
skipLbl.TextSize           = 11
skipLbl.TextColor3         = COL_TEXT
skipLbl.BackgroundTransparency = 1
skipLbl.Size               = UDim2.new(1, -55, 1, 0)
skipLbl.Position           = UDim2.new(0, 8, 0, 0)
skipLbl.TextXAlignment     = Enum.TextXAlignment.Left
skipLbl.Parent             = skipRow

local skipEnabled = true
local toggleBtn = Instance.new("TextButton")
toggleBtn.Text             = "ON"
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 10
toggleBtn.TextColor3       = COL_TEXT
toggleBtn.BackgroundColor3 = COL_ACCENT2
toggleBtn.Size             = UDim2.new(0, 38, 0, 18)
toggleBtn.Position         = UDim2.new(1, -44, 0.5, -9)
toggleBtn.BorderSizePixel  = 0
toggleBtn.AutoButtonColor  = false
toggleBtn.Parent           = skipRow
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)
toggleBtn.MouseButton1Click:Connect(function()
    skipEnabled = not skipEnabled
    toggleBtn.Text             = skipEnabled and "ON" or "OFF"
    toggleBtn.BackgroundColor3 = skipEnabled and COL_ACCENT2 or COL_ACCENT4
end)

local breakerStatus = makeStatus(112, COL_ACCENT2)
breakerStatus.Text = "Status: press V to activate"

local breakerProg = makeProgress(130, COL_ACCENT2)

local fireBtn = makeButton("SCAN AND ACTIVATE  [V]", 138, 34, Color3.fromRGB(28, 80, 58))
fireBtn.MouseEnter:Connect(function()
    if not busy then TweenService:Create(fireBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(38, 110, 78) }):Play() end
end)
fireBtn.MouseLeave:Connect(function()
    if not busy then TweenService:Create(fireBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28, 80, 58) }):Play() end
end)

-- ══════════════════════════════════
--  SECTION: GENERATOR   (y=185)
-- ══════════════════════════════════
makeSection("GENERATOR", 185, COL_ACCENT)

local genStatus = makeStatus(202, COL_ACCENT)
genStatus.Text = "Status: ready  (A to Z)    bind: G"

local genProg = makeProgress(220, COL_ACCENT)

local genBtn = makeButton("SOLVE GENERATOR  [G]", 228, 34, Color3.fromRGB(30, 45, 110))
genBtn.MouseEnter:Connect(function()
    if not generatorBusy then TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(45, 65, 155) }):Play() end
end)
genBtn.MouseLeave:Connect(function()
    if not generatorBusy then TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 45, 110) }):Play() end
end)

local generatorBusy = false

local function runGenerator()
    if generatorBusy then return end
    generatorBusy = true
    genBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    genBtn.Text = "Running..."

    task.spawn(function()
        local genRemote = ReplicatedStorage:WaitForChild("Generator_Events"):WaitForChild("GeneratorFixed")

        -- Fire GeneratorStart first
        pcall(function()
            genRemote:FireServer("GeneratorStart")
        end)
        genStatus.Text = "Fired: GeneratorStart"
        genStatus.TextColor3 = COL_ACCENT
        task.wait(0.1)

        -- Fire A through Z
        for idx = 65, 90 do
            local letter = string.char(idx)
            pcall(function()
                genRemote:FireServer(letter)
            end)
            local rel = (idx - 64) / 26
            TweenService:Create(genProg, TweenInfo.new(0.04), {
                Size = UDim2.new(rel, 0, 1, 0)
            }):Play()
            genStatus.Text      = "Firing: " .. letter .. "  (" .. (idx - 64) .. "/26)"
            genStatus.TextColor3 = COL_ACCENT
            task.wait(0.05)
        end

        genStatus.Text       = "Done — GeneratorStart + A to Z sent"
        genStatus.TextColor3 = Color3.fromRGB(120, 200, 255)
        task.wait(2.5)
        TweenService:Create(genProg, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 1, 0) }):Play()
        genBtn.Text = "SOLVE GENERATOR  [G]"
        TweenService:Create(genBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(30, 45, 110) }):Play()
        genStatus.Text       = "Status: ready  (A to Z)    bind: G"
        genStatus.TextColor3 = COL_ACCENT
        generatorBusy = false
    end)
end

genBtn.MouseButton1Click:Connect(runGenerator)

-- ══════════════════════════════════
--  SECTION: EXPERIMENTAL   (y=275)
-- ══════════════════════════════════
makeSection("EXPERIMENTAL", 275, COL_ACCENT3)

-- Damage value input row
local dmgRow = Instance.new("Frame")
dmgRow.Size             = UDim2.new(1, -20, 0, 28)
dmgRow.Position         = UDim2.new(0, 10, 0, 291)
dmgRow.BackgroundColor3 = COL_PANEL
dmgRow.BorderSizePixel  = 0
dmgRow.Parent           = frame
Instance.new("UICorner", dmgRow).CornerRadius = UDim.new(0, 6)

local dmgLbl = Instance.new("TextLabel")
dmgLbl.Text               = "Damage value:"
dmgLbl.Font               = Enum.Font.Gotham
dmgLbl.TextSize           = 11
dmgLbl.TextColor3         = COL_TEXT
dmgLbl.BackgroundTransparency = 1
dmgLbl.Size               = UDim2.new(0.55, 0, 1, 0)
dmgLbl.Position           = UDim2.new(0, 8, 0, 0)
dmgLbl.TextXAlignment     = Enum.TextXAlignment.Left
dmgLbl.Parent             = dmgRow

local dmgInput = Instance.new("TextBox")
dmgInput.Text               = tostring(damageValue)
dmgInput.Font               = Enum.Font.GothamBold
dmgInput.TextSize           = 12
dmgInput.TextColor3         = COL_TEXT
dmgInput.BackgroundColor3   = Color3.fromRGB(10, 10, 18)
dmgInput.Size               = UDim2.new(0.35, 0, 0, 20)
dmgInput.Position           = UDim2.new(0.6, 0, 0.5, -10)
dmgInput.BorderSizePixel    = 0
dmgInput.ClearTextOnFocus   = false
dmgInput.TextXAlignment     = Enum.TextXAlignment.Center
dmgInput.Parent             = dmgRow
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

local dmgStatus = makeStatus(325, COL_ACCENT3)
dmgStatus.Text = "Status: ready"

local dmgBtn = makeButton('FIRE TAKEDAMAGE  "Weeping"', 340, 34, Color3.fromRGB(90, 35, 18))
dmgBtn.MouseEnter:Connect(function()
    TweenService:Create(dmgBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(120, 48, 24) }):Play()
end)
dmgBtn.MouseLeave:Connect(function()
    TweenService:Create(dmgBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(90, 35, 18) }):Play()
end)
dmgBtn.MouseButton1Click:Connect(function()
    local val = tonumber(dmgInput.Text) or damageValue
    damageValue = val
    pcall(function()
        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(damageValue, "Weeping")
    end)
    dmgStatus.Text       = "Fired: " .. damageValue .. ', "Weeping"'
    dmgStatus.TextColor3 = COL_ACCENT3
    task.delay(2, function()
        dmgStatus.Text       = "Status: ready"
        dmgStatus.TextColor3 = COL_ACCENT3
    end)
end)

-- Night vision toggle row
local nvRow = Instance.new("Frame")
nvRow.Size             = UDim2.new(1, -20, 0, 28)
nvRow.Position         = UDim2.new(0, 10, 0, 380)
nvRow.BackgroundColor3 = COL_PANEL
nvRow.BorderSizePixel  = 0
nvRow.Parent           = frame
Instance.new("UICorner", nvRow).CornerRadius = UDim.new(0, 6)

local nvLbl = Instance.new("TextLabel")
nvLbl.Text               = "Night vision loop (every 11s)"
nvLbl.Font               = Enum.Font.Gotham
nvLbl.TextSize           = 11
nvLbl.TextColor3         = COL_TEXT
nvLbl.BackgroundTransparency = 1
nvLbl.Size               = UDim2.new(1, -55, 1, 0)
nvLbl.Position           = UDim2.new(0, 8, 0, 0)
nvLbl.TextXAlignment     = Enum.TextXAlignment.Left
nvLbl.Parent             = nvRow

local nvToggle = Instance.new("TextButton")
nvToggle.Text             = "OFF"
nvToggle.Font             = Enum.Font.GothamBold
nvToggle.TextSize         = 10
nvToggle.TextColor3       = COL_TEXT
nvToggle.BackgroundColor3 = Color3.fromRGB(60, 22, 22)
nvToggle.Size             = UDim2.new(0, 38, 0, 18)
nvToggle.Position         = UDim2.new(1, -44, 0.5, -9)
nvToggle.BorderSizePixel  = 0
nvToggle.AutoButtonColor  = false
nvToggle.Parent           = nvRow
Instance.new("UICorner", nvToggle).CornerRadius = UDim.new(0, 4)

local nvStatus = makeStatus(414, Color3.fromRGB(160, 200, 255))
nvStatus.Text = "Night vision: off"

nvToggle.MouseButton1Click:Connect(function()
    nightVisionEnabled = not nightVisionEnabled
    if nightVisionEnabled then
        nvToggle.Text             = "ON"
        nvToggle.BackgroundColor3 = Color3.fromRGB(30, 70, 140)
        nvStatus.Text             = "Night vision: active — fires every 11s"
        nvStatus.TextColor3       = Color3.fromRGB(120, 180, 255)
        startNightVision()
    else
        nvToggle.Text             = "OFF"
        nvToggle.BackgroundColor3 = Color3.fromRGB(60, 22, 22)
        nvStatus.Text             = "Night vision: off"
        nvStatus.TextColor3       = Color3.fromRGB(160, 200, 255)
        stopNightVision()
    end
end)

-- ══════════════════════════════════
--  BREAKER LAUNCH
-- ══════════════════════════════════
local function startFire()
    if busy then return end
    fireBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
    fireBtn.Text = "Running..."

    task.spawn(function()
        breakerStatus.Text       = "Teleporting..."
        breakerStatus.TextColor3 = Color3.fromRGB(120, 160, 255)

        teleportTo(20, 5, 6)
        task.wait(0.2)

        teleportTo(25, 5, 6)
        task.wait(0.5)

        teleportTo(0, 5, 6)
        task.wait(0.1)

        scanAndFire(
            skipEnabled,
            function(s)
                breakerStatus.Text       = s
                breakerStatus.TextColor3 = COL_ACCENT2
            end,
            function(i, total, wasSkipped)
                local rel = i / total
                TweenService:Create(breakerProg, TweenInfo.new(FIRE_DELAY * 0.9), {
                    Size = UDim2.new(rel, 0, 1, 0)
                }):Play()
                if wasSkipped then
                    breakerProg.BackgroundColor3 = COL_ACCENT4
                    breakerStatus.Text           = "Jumpscare breaker skipped (" .. i .. "/" .. total .. ")"
                    breakerStatus.TextColor3     = COL_ACCENT4
                else
                    breakerProg.BackgroundColor3 = COL_ACCENT2
                    breakerStatus.Text           = "Activating: " .. i .. " / " .. total
                    breakerStatus.TextColor3     = COL_ACCENT2
                end
            end,
            function(success, total, skipped)
                if total == 0 then
                    breakerStatus.Text       = "No breakers found"
                    breakerStatus.TextColor3 = COL_ACCENT4
                else
                    local skipTxt = skipped > 0 and ("  |  skipped: " .. skipped) or ""
                    breakerStatus.Text       = success .. "/" .. total .. " activated" .. skipTxt
                    breakerStatus.TextColor3 = COL_ACCENT2
                end
                task.wait(2.5)
                breakerProg.BackgroundColor3 = COL_ACCENT2
                TweenService:Create(breakerProg, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 1, 0) }):Play()
                fireBtn.Text = "SCAN AND ACTIVATE  [V]"
                TweenService:Create(fireBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(28, 80, 58) }):Play()
                breakerStatus.Text       = "Status: press V to activate"
                breakerStatus.TextColor3 = COL_ACCENT2
            end
        )
    end)
end

fireBtn.MouseButton1Click:Connect(startFire)

-- ─────────── KEYBINDS ───────────────────
local menuOpen = false
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.G then
        menuOpen = not menuOpen
        frame.Visible = menuOpen
        if menuOpen then runGenerator() end
    end
    if inp.KeyCode == Enum.KeyCode.V then
        startFire()
    end
end)

print("[Menu] Loaded — G = menu/generator | V = breakers")