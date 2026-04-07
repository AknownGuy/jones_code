-- Menu V1.55 | G=menu | V=breakers | F=generator | X=cursor | H=autofloor

local GITHUB_USER   = "AknownGuy"
local GITHUB_REPO   = "LARP_Hub"
local GITHUB_BRANCH = "master"
local SCRIPT_FILE   = "/Error_Code/Error_Code.lua"

local HttpService = game:GetService("HttpService")

local requestFn =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local commitHash = "unknown"

local function githubGet(url)
    local response = requestFn({
        Url = url,
        Method = "GET",
        Headers = {
            ["Accept"] = "application/vnd.github+json",
            ["User-Agent"] = "RobloxCommitFetcher",
            ["X-GitHub-Api-Version"] = "2022-11-28",
        }
    })

    if not response then
        error("No response from GitHub")
    end

    local statusCode = tonumber(response.StatusCode or response.Status) or 0
    return statusCode, response.Body or ""
end

local function getFileCommit()
    if type(requestFn) ~= "function" then
        error("No supported request function found")
    end

    local url = string.format(
        "https://api.github.com/repos/%s/%s/commits?sha=%s&path=%s&per_page=1",
        HttpService:UrlEncode(GITHUB_USER),
        HttpService:UrlEncode(GITHUB_REPO),
        HttpService:UrlEncode(GITHUB_BRANCH),
        HttpService:UrlEncode(SCRIPT_FILE)
    )

    local statusCode, body = githubGet(url)

    if statusCode == 404 then
        error("Repo/file not found, branch is wrong, or repo is private")
    end

    if statusCode ~= 200 then
        error(("GitHub request failed (%d): %s"):format(statusCode, body))
    end

    local data = HttpService:JSONDecode(body)
    if not data or not data[1] or not data[1].sha then
        error("No commit SHA found")
    end

    return data[1].sha
end

local ok, result = pcall(getFileCommit)
if ok then
    commitHash = result:sub(1, 7)
else
    warn("Commit fetch failed: " .. tostring(result))
end

print("Loaded | Commit: " .. commitHash)
-----------------

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer  = Players.LocalPlayer
local FIRE_DELAY   = 0.02
local scriptActive = true

-- ──────────────── KEYBINDS ────────────────
local keybinds = {
    menu      = Enum.KeyCode.G,
    breakers  = Enum.KeyCode.V,
    generator = Enum.KeyCode.F,
    cursor    = Enum.KeyCode.X,
    autofloor = Enum.KeyCode.H,
}

local function getKeyName(kc)
    return tostring(kc):gsub("Enum.KeyCode.", "")
end

-- ──────────────── REMOTES ────────────────
local AbilityEvents     = ReplicatedStorage:WaitForChild("AbilityEvents")
local UltraMechanicUsed = AbilityEvents:WaitForChild("UltraMechanicUsed")

-- ──────────────── TELEPORT HELPERS ────────────────
local function teleportTo(x, y, z)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(x, y, z) end
end

-- Smooth tween using RenderStepped lerp, ease-in-out cubic
-- duration in seconds
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
        local t = a < 0.5 and (4*a*a*a) or (1 - (-2*a+2)^3 / 2)
        if hrp and hrp.Parent then
            hrp.CFrame = startCF:Lerp(endCF, t)
        end
        task.wait(0.016)
    end
    if hrp and hrp.Parent then hrp.CFrame = endCF end
end

-- ──────────────── ELEVATOR TRIGGER ────────────────
-- Fires both TouchInterests inside workspace.elevator.trigger
local function fireElevatorTrigger()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local elev = workspace:FindFirstChild("elevator") or workspace:FindFirstChild("Elevator")
    if not elev then return end
    local trig = elev:FindFirstChild("trigger") or elev:FindFirstChild("Trigger")
    if not trig then return end

    for _, child in ipairs(trig:GetChildren()) do
        if child:IsA("TouchTransmitter") or child.ClassName == "TouchInterest" then
            pcall(function() firetouchinterest(hrp, trig, 0) end)
            task.wait(0.05)
        end
    end
    -- Fire a second pass to catch both entries
    pcall(function() firetouchinterest(hrp, trig, 0) end)
    task.wait(0.05)
    pcall(function() firetouchinterest(hrp, trig, 1) end)
end

-- ──────────────── BREAKERS ────────────────
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

-- ──────────────── NIGHT VISION ────────────────
local nightVisionEnabled = false
local nightVisionThread  = nil

local function startNightVision()
    if nightVisionThread then return end
    nightVisionThread = task.spawn(function()
        while nightVisionEnabled do
            pcall(function() AbilityEvents:WaitForChild("NightVisionUsed"):FireServer() end)
            task.wait(10)
        end
        nightVisionThread = nil
    end)
end

local function stopNightVision()
    nightVisionEnabled = false
    nightVisionThread  = nil
end

-- ──────────────── GOD MODE ────────────────
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
                        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(-needed)
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

-- ──────────────── CURSOR LOCK ────────────────
local cursorLocked = false
local cursorConn   = nil

local function setCursorLock(locked)
    cursorLocked = locked
    if cursorConn then cursorConn:Disconnect(); cursorConn = nil end
    if not locked then
        cursorConn = RunService.RenderStepped:Connect(function()
            UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    else
        UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    end
end

-- ──────────────── FLOOR TRACKING ────────────────
local function getFloorObj()
    local data = LocalPlayer:FindFirstChild("InGameData")
    return data and data:FindFirstChild("FloorReached")
end

-- ──────────────── BACTERIUM (BROKEN) ────────────────
local bacteriumEnabled = false
local bacteriumThread  = nil

local function findBacteriumPrompts()
    local found   = {}
    local floors  = workspace:FindFirstChild("Floors")
    if not floors then return found end
    local current = floors:FindFirstChild("CurrentFloor")
    if not current then return found end
    local important = current:FindFirstChild("Important")
    if not important then return found end
    local bFolder = important:FindFirstChild("Bacterium")
    if not bFolder then return found end
    for _, obj in ipairs(bFolder:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then table.insert(found, obj) end
    end
    return found
end

local function runBacteriumAvoid(onStatus)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local prompts = findBacteriumPrompts()
    if #prompts == 0 then
        if onStatus then onStatus("[BROKEN] No Bacterium found") end
        return
    end
    local origin = hrp.CFrame
    local done   = 0
    for _, prompt in ipairs(prompts) do
        local part = prompt.Parent
        if part and part:IsA("BasePart") then
            hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.08)
            pcall(function()
                if fireproximityprompt then
                    local old = prompt.MaxActivationDistance
                    prompt.MaxActivationDistance = 9e9
                    fireproximityprompt(prompt)
                    prompt.MaxActivationDistance = old
                end
            end)
            done += 1
            if onStatus then onStatus("[BROKEN] Triggered " .. done .. "/" .. #prompts) end
            task.wait(0.08)
            hrp.CFrame = origin
            task.wait(0.12)
        end
    end
end

local function startBacterium(onStatus)
    if bacteriumThread then return end
    bacteriumThread = task.spawn(function()
        while bacteriumEnabled do
            local floors  = workspace:FindFirstChild("Floors")
            local current = floors and floors:FindFirstChild("CurrentFloor")
            if current then runBacteriumAvoid(onStatus)
            else if onStatus then onStatus("[BROKEN] Waiting for floor...") end end
            task.wait(5)
        end
        bacteriumThread = nil
    end)
end

local function stopBacterium()
    bacteriumEnabled = false
    bacteriumThread  = nil
end

-- ──────────────── EXPERIMENTAL TELEPORT TOGGLE ────────────────
local useNewTeleport = false

-- ──────────────── FORWARD DECLARE startFire ────────────────
local startFire

-- ──────────────── AUTO FLOOR ────────────────
-- Always uses tween system.
-- Sequence: wait 5s → detect floor → wait 5s → run tween activate+tp → wait 5s → repeat
local autoFloorEnabled = false
local autoFloorThread  = nil

local function startAutoFloor(onStatus)
    if autoFloorThread then return end
    autoFloorThread = task.spawn(function()
        if onStatus then onStatus("Auto floor: starting in 5s...") end
        task.wait(5)

        while autoFloorEnabled do
            -- Detect any children in Workspace.Floors
            local floorsFolder = workspace:FindFirstChild("Floors")
            local hasFloor     = floorsFolder and #floorsFolder:GetChildren() > 0

            if hasFloor then
                if onStatus then onStatus("Floor detected — waiting 5s...") end
                task.wait(5)
                if not autoFloorEnabled then break end

                if onStatus then onStatus("Running breakers (tween)...") end

                -- Force tween mode for autofloor regardless of toggle
                local savedNewTp = useNewTeleport
                useNewTeleport   = false
                startFire()
                useNewTeleport   = savedNewTp

                -- Wait for the operation to finish
                task.wait(0.8)
                while busy do task.wait(0.3) end

                if onStatus then onStatus("Cycle done — waiting 5s...") end
                task.wait(5)
            else
                if onStatus then onStatus("Waiting for floor...") end
                task.wait(1)
            end
        end

        autoFloorThread = nil
    end)
end

local function stopAutoFloor()
    autoFloorEnabled = false
    autoFloorThread  = nil
end

-- ════════════════════════════════════════════════
--  BUILD GUI
-- ════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MainMenu"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local CB  = Color3.fromRGB(12,  12,  18)
local CP  = Color3.fromRGB(20,  20,  30)
local CBo = Color3.fromRGB(55,  55,  90)
local CA  = Color3.fromRGB(80,  120, 255)
local CA2 = Color3.fromRGB(55,  190, 120)
local CA3 = Color3.fromRGB(210, 150, 40)
local CA4 = Color3.fromRGB(200, 65,  65)
local CT  = Color3.fromRGB(205, 205, 215)
local CS  = Color3.fromRGB(100, 100, 120)

local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, 300, 0, 600)
frame.Position         = UDim2.new(0.5, -150, 0.5, -300)
frame.BackgroundColor3 = CB
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Visible          = false
frame.Parent           = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local fstroke = Instance.new("UIStroke")
fstroke.Color = CBo; fstroke.Thickness = 1.2; fstroke.Parent = frame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = CP
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
local tpatch = Instance.new("Frame")
tpatch.Size = UDim2.new(1,0,0,8); tpatch.Position = UDim2.new(0,0,1,-8)
tpatch.BackgroundColor3 = CP; tpatch.BorderSizePixel = 0; tpatch.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Text           = "MENU  //  V1.55"

-- small commit label sitting to the right of the version text
local commitLabel = Instance.new("TextLabel")
commitLabel.Text               = commitHash
commitLabel.Font               = Enum.Font.Gotham
commitLabel.TextSize           = 9
commitLabel.TextColor3         = Color3.fromRGB(80, 80, 110)
commitLabel.BackgroundTransparency = 1
commitLabel.Size               = UDim2.new(0, 55, 0, 14)
commitLabel.Position           = UDim2.new(0, 130, 0.5, -7)
commitLabel.TextXAlignment     = Enum.TextXAlignment.Left
commitLabel.Parent             = titleBar
titleLabel.Font           = Enum.Font.GothamBold
titleLabel.TextSize       = 13
titleLabel.TextColor3     = CT
titleLabel.BackgroundTransparency = 1
titleLabel.Size           = UDim2.new(1, -140, 1, 0)
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
local us2 = Instance.new("UIStroke")
us2.Color = Color3.fromRGB(120,90,20); us2.Thickness = 1; us2.Parent = unloadBtn

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

-- Hint line
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
    hintLine.Text =
        getKeyName(keybinds.menu)      .. "=menu  " ..
        getKeyName(keybinds.breakers)  .. "=breakers  " ..
        getKeyName(keybinds.generator) .. "=gen  " ..
        getKeyName(keybinds.cursor)    .. "=cursor  " ..
        getKeyName(keybinds.autofloor) .. "=autofloor"
end
refreshHint()

-- ── TAB ROW (3 tabs) ──
local tabRow = Instance.new("Frame")
tabRow.Size             = UDim2.new(1, -20, 0, 26)
tabRow.Position         = UDim2.new(0, 10, 0, 60)
tabRow.BackgroundColor3 = CP
tabRow.BorderSizePixel  = 0
tabRow.Parent           = frame
Instance.new("UICorner", tabRow).CornerRadius = UDim.new(0, 6)

local function makeTabBtn(text, xs, xo, ws, wo)
    local b = Instance.new("TextButton")
    b.Text               = text
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 10
    b.TextColor3         = CS
    b.BackgroundTransparency = 1
    b.Size               = UDim2.new(ws, wo, 1, -4)
    b.Position           = UDim2.new(xs, xo, 0, 2)
    b.BorderSizePixel    = 0
    b.AutoButtonColor    = false
    b.Parent             = tabRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local tabMain         = makeTabBtn("MAIN",         0,     2,  0.334, -3)
local tabBinds        = makeTabBtn("BINDS",        0.334, 1,  0.333, -2)
local tabExperimental = makeTabBtn("EXPERIMENTAL", 0.667, 1,  0.333, -3)

-- ── PAGES ──
local function makePage(visible)
    local p = Instance.new("ScrollingFrame")
    p.Size                   = UDim2.new(1, 0, 1, -94)
    p.Position               = UDim2.new(0, 0, 0, 94)
    p.BackgroundTransparency = 1
    p.BorderSizePixel        = 0
    p.ScrollBarThickness     = 3
    p.ScrollBarImageColor3   = CBo
    p.CanvasSize             = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    p.Visible                = visible
    p.Parent                 = frame
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent        = p
    return p
end

local mainPage         = makePage(true)
local bindsPage        = makePage(false)
local experimentalPage = makePage(false)

local function setTab(which)
    mainPage.Visible         = (which == "main")
    bindsPage.Visible        = (which == "binds")
    experimentalPage.Visible = (which == "experimental")
    for id, btn in pairs({
        main         = tabMain,
        binds        = tabBinds,
        experimental = tabExperimental
    }) do
        btn.TextColor3           = (id == which) and CT or CS
        btn.BackgroundTransparency = (id == which) and 0 or 1
        if id == which then btn.BackgroundColor3 = CBo end
    end
end

tabMain.MouseButton1Click:Connect(function()         setTab("main")         end)
tabBinds.MouseButton1Click:Connect(function()        setTab("binds")        end)
tabExperimental.MouseButton1Click:Connect(function() setTab("experimental") end)
setTab("main")

-- ══════════════════════════════════════
--  UI HELPERS
-- ══════════════════════════════════════
local function uiSection(parent, label, posY, col)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1,-20,0,1); line.Position = UDim2.new(0,10,0,posY+13)
    line.BackgroundColor3 = col; line.BorderSizePixel = 0; line.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextColor3 = col; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.6,0,0,14); lbl.Position = UDim2.new(0,10,0,posY)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
end

local function uiButton(parent, text, posY, h, bg, sz, pos)
    local b = Instance.new("TextButton")
    b.Text = text; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.TextColor3 = CT; b.BackgroundColor3 = bg or CA
    b.Size = sz or UDim2.new(1,-20,0,h or 34)
    b.Position = pos or UDim2.new(0,10,0,posY)
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end

local function uiStatus(parent, posY, col)
    local l = Instance.new("TextLabel")
    l.Text = "Status: ready"; l.Font = Enum.Font.Gotham; l.TextSize = 11
    l.TextColor3 = col or CS; l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-20,0,14); l.Position = UDim2.new(0,10,0,posY)
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
    return l
end

local function uiProgress(parent, posY, fillCol)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-20,0,4); track.Position = UDim2.new(0,10,0,posY)
    track.BackgroundColor3 = CP; track.BorderSizePixel = 0; track.Parent = parent
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0,0,1,0); fill.BackgroundColor3 = fillCol or CA
    fill.BorderSizePixel = 0; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    return fill
end

local function uiToggleRow(parent, label, posY, activeCol, inactiveCol)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-20,0,28); row.Position = UDim2.new(0,10,0,posY)
    row.BackgroundColor3 = CP; row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextColor3 = CT; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,-55,1,0); lbl.Position = UDim2.new(0,8,0,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local tog = Instance.new("TextButton")
    tog.Text = "OFF"; tog.Font = Enum.Font.GothamBold; tog.TextSize = 10
    tog.TextColor3 = CT; tog.BackgroundColor3 = inactiveCol
    tog.Size = UDim2.new(0,38,0,18); tog.Position = UDim2.new(1,-44,0.5,-9)
    tog.BorderSizePixel = 0; tog.AutoButtonColor = false; tog.Parent = row
    Instance.new("UICorner", tog).CornerRadius = UDim.new(0,4)
    return tog, activeCol, inactiveCol
end

local function uiInputRow(parent, label, default, posY, strokeCol)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-20,0,28); row.Position = UDim2.new(0,10,0,posY)
    row.BackgroundColor3 = CP; row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextColor3 = CT; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.57,0,1,0); lbl.Position = UDim2.new(0,8,0,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local inp = Instance.new("TextBox")
    inp.Text = tostring(default); inp.Font = Enum.Font.GothamBold; inp.TextSize = 12
    inp.TextColor3 = CT; inp.BackgroundColor3 = Color3.fromRGB(10,10,18)
    inp.Size = UDim2.new(0.32,0,0,20); inp.Position = UDim2.new(0.63,0,0.5,-10)
    inp.BorderSizePixel = 0; inp.ClearTextOnFocus = false
    inp.TextXAlignment = Enum.TextXAlignment.Center; inp.Parent = row
    Instance.new("UICorner", inp).CornerRadius = UDim.new(0,4)
    local s = Instance.new("UIStroke"); s.Color = strokeCol or CA3; s.Thickness = 1; s.Parent = inp
    return inp
end

-- ══════════════════════════════════════
--  MAIN PAGE
-- ══════════════════════════════════════

uiSection(mainPage, "BREAKERS", 8, CA2)

local breakerStatus = uiStatus(mainPage, 26, CA2)
breakerStatus.Text = "Status: ready"

local floorDisplay = uiStatus(mainPage, 42, CS)
floorDisplay.Text = "Floor: —"

local breakerProg = uiProgress(mainPage, 60, CA2)

local fireBtn = uiButton(
    mainPage, "ACTIVATE + TP  [V]", 68, 34,
    Color3.fromRGB(24, 72, 50),
    UDim2.new(0.62, -14, 0, 34),
    UDim2.new(0, 10, 0, 68)
)
local activateBtn = uiButton(
    mainPage, "ACTIVATE", 68, 34,
    Color3.fromRGB(20, 45, 38),
    UDim2.new(0.38, -6, 0, 34),
    UDim2.new(0.62, 0, 0, 68)
)
local actStroke = Instance.new("UIStroke")
actStroke.Color = CA2; actStroke.Thickness = 1; actStroke.Transparency = 0.5
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

-- spacer
local sp1 = Instance.new("Frame")
sp1.Size = UDim2.new(1,0,0,8); sp1.Position = UDim2.new(0,0,0,106)
sp1.BackgroundTransparency = 1; sp1.BorderSizePixel = 0; sp1.Parent = mainPage

uiSection(mainPage, "GENERATOR", 118, CA)

local genStatus = uiStatus(mainPage, 136, CA)
genStatus.Text = "Status: ready  (A to Z)    bind: F"

local genProg = uiProgress(mainPage, 154, CA)

local genBtn = uiButton(mainPage, "SOLVE GENERATOR  [F]", 162, 34, Color3.fromRGB(28,42,105))
genBtn.MouseEnter:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42,62,148) }):Play()
end)
genBtn.MouseLeave:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28,42,105) }):Play()
end)

local sp2 = Instance.new("Frame")
sp2.Size = UDim2.new(1,0,0,8); sp2.Position = UDim2.new(0,0,0,200)
sp2.BackgroundTransparency = 1; sp2.BorderSizePixel = 0; sp2.Parent = mainPage

uiSection(mainPage, "PLAYER", 212, CA3)

local godToggle, godActive, godInactive = uiToggleRow(
    mainPage, "God mode (auto-heal to max HP)", 230,
    Color3.fromRGB(28,95,55), Color3.fromRGB(55,18,18)
)
godToggle.BackgroundColor3 = Color3.fromRGB(55,18,18)

local healInput = uiInputRow(mainPage, "Heal amount:", 10, 264, CA2)
local damageValue = 10
healInput.FocusLost:Connect(function()
    local v = tonumber(healInput.Text)
    if v then damageValue = v else healInput.Text = tostring(damageValue) end
end)

local healBtn = uiButton(mainPage, "HEAL PLAYER", 298, 34, Color3.fromRGB(30,80,45))
healBtn.MouseEnter:Connect(function()
    TweenService:Create(healBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42,112,62) }):Play()
end)
healBtn.MouseLeave:Connect(function()
    TweenService:Create(healBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30,80,45) }):Play()
end)

local nvToggle, nvActive, nvInactive = uiToggleRow(
    mainPage, "Night vision loop (every 10s)", 340,
    Color3.fromRGB(28,55,130), Color3.fromRGB(55,18,18)
)
nvToggle.BackgroundColor3 = Color3.fromRGB(55,18,18)

local cursorBtn = uiButton(mainPage, "CURSOR: UNLOCKED  [X]", 376, 34, Color3.fromRGB(35,30,60))
cursorBtn.MouseEnter:Connect(function()
    TweenService:Create(cursorBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(52,44,88) }):Play()
end)
cursorBtn.MouseLeave:Connect(function()
    TweenService:Create(cursorBtn, TweenInfo.new(0.1), {
        BackgroundColor3 = cursorLocked and Color3.fromRGB(50,40,90) or Color3.fromRGB(35,30,60)
    }):Play()
end)

local autoFloorToggle, afActive, afInactive = uiToggleRow(
    mainPage, "Auto floor  [H]", 418,
    Color3.fromRGB(55,40,100), Color3.fromRGB(40,22,55)
)
autoFloorToggle.BackgroundColor3 = Color3.fromRGB(40,22,55)

local autoFloorStatus = uiStatus(mainPage, 452, Color3.fromRGB(160,130,220))
autoFloorStatus.Text = "Auto floor: off"

local sp3 = Instance.new("Frame")
sp3.Size = UDim2.new(1,0,0,8); sp3.Position = UDim2.new(0,0,0,470)
sp3.BackgroundTransparency = 1; sp3.BorderSizePixel = 0; sp3.Parent = mainPage

uiSection(mainPage, "ADD MONEY", 482, CA3)

local moneyInput = uiInputRow(mainPage, "Token amount:", 100, 500, CA3)
local moneyValue = 100
moneyInput.FocusLost:Connect(function()
    local v = tonumber(moneyInput.Text)
    if v then moneyValue = v else moneyInput.Text = tostring(moneyValue) end
end)

local moneyBtn = uiButton(mainPage, "ADD MONEY", 534, 34, Color3.fromRGB(80,55,14))
moneyBtn.MouseEnter:Connect(function()
    TweenService:Create(moneyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(110,78,20) }):Play()
end)
moneyBtn.MouseLeave:Connect(function()
    TweenService:Create(moneyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(80,55,14) }):Play()
end)

-- ══════════════════════════════════════
--  BINDS PAGE
-- ══════════════════════════════════════
local bindDefs = {
    { id = "menu",      label = "Toggle Menu"     },
    { id = "breakers",  label = "Activate + TP"   },
    { id = "generator", label = "Solve Generator" },
    { id = "cursor",    label = "Cursor Lock"      },
    { id = "autofloor", label = "Auto Floor"       },
}

local rebindBtns = {}
local rebinding  = nil

for i, def in ipairs(bindDefs) do
    local rowY = 10 + (i-1) * 44
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-20,0,36); row.Position = UDim2.new(0,10,0,rowY)
    row.BackgroundColor3 = CP; row.BorderSizePixel = 0; row.Parent = bindsPage
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)
    local lbl = Instance.new("TextLabel")
    lbl.Text = def.label; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
    lbl.TextColor3 = CT; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.52,0,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local kb = Instance.new("TextButton")
    kb.Text = getKeyName(keybinds[def.id]); kb.Font = Enum.Font.GothamBold; kb.TextSize = 11
    kb.TextColor3 = CT; kb.BackgroundColor3 = Color3.fromRGB(35,35,60)
    kb.Size = UDim2.new(0.35,0,0,24); kb.Position = UDim2.new(0.57,0,0.5,-12)
    kb.BorderSizePixel = 0; kb.AutoButtonColor = false; kb.Parent = row
    Instance.new("UICorner", kb).CornerRadius = UDim.new(0,4)
    local ks = Instance.new("UIStroke"); ks.Color = CBo; ks.Thickness = 1; ks.Parent = kb
    rebindBtns[def.id] = kb
    local bindId = def.id
    kb.MouseButton1Click:Connect(function()
        if rebinding then return end
        rebinding = bindId
        kb.Text = "Press key..."
        kb.TextColor3 = CA3
        kb.BackgroundColor3 = Color3.fromRGB(50,45,15)
    end)
end

local bindsNote = Instance.new("TextLabel")
bindsNote.Text = "Click a key button, then press any key.  ESC = cancel"
bindsNote.Font = Enum.Font.Gotham; bindsNote.TextSize = 10; bindsNote.TextColor3 = CS
bindsNote.BackgroundTransparency = 1; bindsNote.Size = UDim2.new(1,-20,0,30)
bindsNote.Position = UDim2.new(0,10,0,10 + #bindDefs*44 + 8)
bindsNote.TextXAlignment = Enum.TextXAlignment.Left; bindsNote.TextWrapped = true
bindsNote.Parent = bindsPage

-- ══════════════════════════════════════
--  EXPERIMENTAL PAGE
-- ══════════════════════════════════════
uiSection(experimentalPage, "TELEPORT SYSTEM", 10, CA)

local newTpToggle, ntpActive, ntpInactive = uiToggleRow(
    experimentalPage,
    "New teleport system (instant TP)",
    28,
    Color3.fromRGB(40, 80, 160),
    Color3.fromRGB(30, 30, 55)
)
newTpToggle.BackgroundColor3 = Color3.fromRGB(30, 30, 55)

local ntpDesc = Instance.new("TextLabel")
ntpDesc.Text = "OFF = tween slide (default, stable)\nON  = instant snap with mid-point steps (experimental)"
ntpDesc.Font = Enum.Font.Gotham; ntpDesc.TextSize = 10; ntpDesc.TextColor3 = CS
ntpDesc.BackgroundTransparency = 1; ntpDesc.Size = UDim2.new(1,-20,0,36)
ntpDesc.Position = UDim2.new(0,10,0,62)
ntpDesc.TextXAlignment = Enum.TextXAlignment.Left; ntpDesc.TextWrapped = true
ntpDesc.Parent = experimentalPage

-- Bacterium section
local sp4 = Instance.new("Frame")
sp4.Size = UDim2.new(1,0,0,8); sp4.Position = UDim2.new(0,0,0,102)
sp4.BackgroundTransparency = 1; sp4.BorderSizePixel = 0; sp4.Parent = experimentalPage

uiSection(experimentalPage, "BACTERIUM AVOID  [BROKEN]", 114, CA4)

local bacteriumToggle, batActive, batInactive = uiToggleRow(
    experimentalPage, "Avoid Bacterium — CURRENTLY BROKEN", 132,
    Color3.fromRGB(100,25,25), Color3.fromRGB(55,18,18)
)
bacteriumToggle.BackgroundColor3 = Color3.fromRGB(55,18,18)

local batStatus = uiStatus(experimentalPage, 166, CA4)
batStatus.Text = "Bacterium: off  (broken — do not rely on this)"

local batInfo = Instance.new("TextLabel")
batInfo.Text = "Teleports to each Bacterium on the current floor and triggers its prompt. Currently unreliable — proximity detection issues pending fix."
batInfo.Font = Enum.Font.Gotham; batInfo.TextSize = 10; batInfo.TextColor3 = CS
batInfo.BackgroundTransparency = 1; batInfo.Size = UDim2.new(1,-20,0,52)
batInfo.Position = UDim2.new(0,10,0,184)
batInfo.TextXAlignment = Enum.TextXAlignment.Left; batInfo.TextWrapped = true
batInfo.Parent = experimentalPage

-- ══════════════════════════════════════
--  BUTTON LOGIC
-- ══════════════════════════════════════

-- New teleport toggle
newTpToggle.MouseButton1Click:Connect(function()
    useNewTeleport              = not useNewTeleport
    newTpToggle.Text             = useNewTeleport and "ON"  or "OFF"
    newTpToggle.BackgroundColor3 = useNewTeleport and ntpActive or ntpInactive
end)

-- God mode
godToggle.MouseButton1Click:Connect(function()
    godModeEnabled               = not godModeEnabled
    godToggle.Text               = godModeEnabled and "ON"  or "OFF"
    godToggle.BackgroundColor3   = godModeEnabled and godActive or godInactive
    if godModeEnabled then startGodMode() else stopGodMode() end
end)

-- Heal
healBtn.MouseButton1Click:Connect(function()
    local v = tonumber(healInput.Text) or damageValue
    damageValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(-damageValue)
    end)
end)

-- Night vision
nvToggle.MouseButton1Click:Connect(function()
    nightVisionEnabled             = not nightVisionEnabled
    nvToggle.Text                  = nightVisionEnabled and "ON"  or "OFF"
    nvToggle.BackgroundColor3      = nightVisionEnabled and nvActive or nvInactive
    if nightVisionEnabled then startNightVision() else stopNightVision() end
end)

-- Cursor
local function toggleCursor()
    setCursorLock(not cursorLocked)
    cursorBtn.Text = cursorLocked
        and ("CURSOR: LOCKED  [" .. getKeyName(keybinds.cursor) .. "]")
        or  ("CURSOR: UNLOCKED  [" .. getKeyName(keybinds.cursor) .. "]")
    cursorBtn.BackgroundColor3 = cursorLocked
        and Color3.fromRGB(50,40,90) or Color3.fromRGB(35,30,60)
end
cursorBtn.MouseButton1Click:Connect(toggleCursor)

-- Add money
moneyBtn.MouseButton1Click:Connect(function()
    local v = tonumber(moneyInput.Text) or moneyValue
    moneyValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("QuestRemotes")
            :WaitForChild("Reward"):FireServer("Tokens", moneyValue)
    end)
end)

-- Bacterium toggle
bacteriumToggle.MouseButton1Click:Connect(function()
    bacteriumEnabled               = not bacteriumEnabled
    bacteriumToggle.Text           = bacteriumEnabled and "ON"  or "OFF"
    bacteriumToggle.BackgroundColor3 = bacteriumEnabled and batActive or batInactive
    if bacteriumEnabled then
        batStatus.Text = "[BROKEN] Active — results unreliable"
        startBacterium(function(msg)
            batStatus.Text       = msg
            batStatus.TextColor3 = CA4
        end)
    else
        batStatus.Text = "Bacterium: off  (broken — do not rely on this)"
        stopBacterium()
    end
    batStatus.TextColor3 = CA4
end)

-- Auto floor
local function toggleAutoFloor()
    autoFloorEnabled               = not autoFloorEnabled
    autoFloorToggle.Text           = autoFloorEnabled and "ON"  or "OFF"
    autoFloorToggle.BackgroundColor3 = autoFloorEnabled and afActive or afInactive
    if autoFloorEnabled then
        autoFloorStatus.Text       = "Auto floor: active"
        autoFloorStatus.TextColor3 = Color3.fromRGB(160,130,220)
        startAutoFloor(function(msg)
            autoFloorStatus.Text       = msg
            autoFloorStatus.TextColor3 = Color3.fromRGB(160,130,220)
        end)
    else
        autoFloorStatus.Text       = "Auto floor: off"
        autoFloorStatus.TextColor3 = Color3.fromRGB(160,130,220)
        stopAutoFloor()
    end
end
autoFloorToggle.MouseButton1Click:Connect(toggleAutoFloor)

-- Floor display live poll
task.spawn(function()
    while scriptActive do
        local fo = getFloorObj()
        floorDisplay.Text = fo and ("Floor: " .. tostring(fo.Value)) or "Floor: —"
        task.wait(0.5)
    end
end)

-- ══════════════════════════════════════
--  GENERATOR LOGIC
-- ══════════════════════════════════════
local generatorBusy = false

local function runGenerator()
    if generatorBusy then return end
    generatorBusy = true
    genBtn.BackgroundColor3 = Color3.fromRGB(16,18,38)
    genBtn.Text = "Running..."
    task.spawn(function()
        local genR = ReplicatedStorage:WaitForChild("Generator_Events"):WaitForChild("GeneratorFixed")
        pcall(function() genR:FireServer("GeneratorStart") end)
        genStatus.Text = "Fired: GeneratorStart"; genStatus.TextColor3 = CA
        task.wait(0.1)
        for idx = 65, 90 do
            local letter = string.char(idx)
            pcall(function() genR:FireServer(letter) end)
            TweenService:Create(genProg, TweenInfo.new(0.04), {
                Size = UDim2.new((idx-64)/26, 0, 1, 0)
            }):Play()
            genStatus.Text       = "Firing: " .. letter .. "  (" .. (idx-64) .. "/26)"
            genStatus.TextColor3 = CA
            task.wait(0.05)
        end
        genStatus.Text       = "Done — GeneratorStart + A to Z sent"
        genStatus.TextColor3 = Color3.fromRGB(110,195,255)
        task.wait(2.5)
        TweenService:Create(genProg, TweenInfo.new(0.4), { Size = UDim2.new(0,0,1,0) }):Play()
        genBtn.Text = "SOLVE GENERATOR  [F]"
        TweenService:Create(genBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(28,42,105) }):Play()
        genStatus.Text       = "Status: ready  (A to Z)    bind: F"
        genStatus.TextColor3 = CA
        generatorBusy = false
    end)
end

genBtn.MouseButton1Click:Connect(runGenerator)

-- ══════════════════════════════════════
--  BREAKER CALLBACKS
-- ══════════════════════════════════════
local function onBreakerProgress(i, total)
    TweenService:Create(breakerProg, TweenInfo.new(FIRE_DELAY*0.9), {
        Size = UDim2.new(i/total, 0, 1, 0)
    }):Play()
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
    TweenService:Create(breakerProg, TweenInfo.new(0.4), { Size = UDim2.new(0,0,1,0) }):Play()
    fireBtn.Text     = "ACTIVATE + TP  [V]"
    activateBtn.Text = "ACTIVATE"
    TweenService:Create(fireBtn,     TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(24,72,50) }):Play()
    TweenService:Create(activateBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(20,45,38) }):Play()
    breakerStatus.Text       = "Status: ready"
    breakerStatus.TextColor3 = CA2
end

-- ══════════════════════════════════════
--  TWEEN SEQUENCE  (default)
--  1. Smooth slide → 0,5,5  (0.7s)
--  2. Wait 0.5s
--  3. Activate breakers
--  4. Wait 0.5s
--  5. Smooth slide → 20,5,5  (0.7s)
--  6. Fire elevator TouchInterests
-- ══════════════════════════════════════
local function runTweenSequence(onScanDone)
    breakerStatus.Text       = "Sliding to position..."
    breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
    smoothTeleport(0, 5, 5, 0.7)
    task.wait(0.5)

    local floorBefore = nil
    local fo = getFloorObj()
    if fo then floorBefore = fo.Value end

    fireBtn.Text = "Activating..."
    scanAndFire(
        function(s)
            breakerStatus.Text       = s
            breakerStatus.TextColor3 = CA2
        end,
        onBreakerProgress,
        function(success, total)
            task.wait(0.5)

            breakerStatus.Text       = "Sliding back..."
            breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
            smoothTeleport(20, 5, 5, 0.7)

            -- Fire elevator trigger after arriving
            task.wait(0.15)
            fireElevatorTrigger()

            -- Fallback floor remote if FloorReached hasn't changed
            task.wait(0.2)
            local foNow = getFloorObj()
            if foNow and floorBefore ~= nil and foNow.Value == floorBefore then
                pcall(function()
                    ReplicatedStorage:WaitForChild("QuestRemotes")
                        :WaitForChild("Floors"):FireServer()
                end)
            end

            if onScanDone then onScanDone(success, total) end
        end
    )
end

-- ══════════════════════════════════════
--  EXPERIMENTAL INSTANT SEQUENCE
--  1. Teleport to midpoint  (10, 5, 5)
--  2. Teleport fully        ( 0, 5, 5)
--  3. Wait 0.5s
--  4. Activate breakers
--  5. Wait 0.5s
--  6. Fire elevator TouchInterests
--  7. Wait 0.2s
--  8. Teleport to midpoint  (10, 5, 5)
--  9. Teleport fully        (20, 5, 5)
-- ══════════════════════════════════════
local function runInstantSequence(onScanDone)
    breakerStatus.Text       = "[EXP] Snapping to position..."
    breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)

    -- Step 1 + 2
    teleportTo(10, 5, 5)
    task.wait(0.08)
    teleportTo(0, 5, 5)
    task.wait(0.5)

    local floorBefore = nil
    local fo = getFloorObj()
    if fo then floorBefore = fo.Value end

    -- Step 4: breakers
    fireBtn.Text = "[EXP] Activating..."
    scanAndFire(
        function(s)
            breakerStatus.Text       = s
            breakerStatus.TextColor3 = CA2
        end,
        onBreakerProgress,
        function(success, total)
            -- Step 5
            task.wait(0.5)

            -- Step 6: elevator triggers
            breakerStatus.Text       = "[EXP] Firing elevator..."
            breakerStatus.TextColor3 = CS
            fireElevatorTrigger()

            -- Step 7
            task.wait(0.2)

            -- Step 8 + 9
            breakerStatus.Text       = "[EXP] Snapping back..."
            breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
            teleportTo(10, 5, 5)
            task.wait(0.08)
            teleportTo(20, 5, 5)

            -- Fallback floor remote
            task.wait(0.2)
            local foNow = getFloorObj()
            if foNow and floorBefore ~= nil and foNow.Value == floorBefore then
                pcall(function()
                    ReplicatedStorage:WaitForChild("QuestRemotes")
                        :WaitForChild("Floors"):FireServer()
                end)
            end

            if onScanDone then onScanDone(success, total) end
        end
    )
end

-- ══════════════════════════════════════
--  startFire — dispatches to tween or instant
-- ══════════════════════════════════════
startFire = function()
    if busy then return end
    fireBtn.BackgroundColor3 = Color3.fromRGB(16,26,20)
    fireBtn.Text             = "Running..."

    task.spawn(function()
        if useNewTeleport then
            runInstantSequence(onBreakerDone)
        else
            runTweenSequence(onBreakerDone)
        end
    end)
end

-- ACTIVATE only (no teleport, no elevator)
local function startFireNoTeleport()
    if busy then return end
    activateBtn.BackgroundColor3 = Color3.fromRGB(14,30,22)
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
--  INPUT / KEYBINDS
-- ══════════════════════════════════════
local menuOpen = false

UserInputService.InputBegan:Connect(function(inp, processed)
    if not scriptActive then return end

    if rebinding and inp.UserInputType == Enum.UserInputType.Keyboard then
        local newKey = inp.KeyCode
        local btn    = rebindBtns[rebinding]
        if newKey == Enum.KeyCode.Escape then
            if btn then
                btn.Text             = getKeyName(keybinds[rebinding])
                btn.TextColor3       = CT
                btn.BackgroundColor3 = Color3.fromRGB(35,35,60)
            end
        else
            keybinds[rebinding] = newKey
            if btn then
                btn.Text             = getKeyName(newKey)
                btn.TextColor3       = CT
                btn.BackgroundColor3 = Color3.fromRGB(35,35,60)
            end
            refreshHint()
        end
        rebinding = nil
        return
    end

    if processed then return end

    if      inp.KeyCode == keybinds.menu      then menuOpen = not menuOpen; frame.Visible = menuOpen
    elseif  inp.KeyCode == keybinds.breakers  then startFire()
    elseif  inp.KeyCode == keybinds.generator then runGenerator()
    elseif  inp.KeyCode == keybinds.cursor    then toggleCursor()
    elseif  inp.KeyCode == keybinds.autofloor then toggleAutoFloor()
    end
end)

-- ══════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════
local function unload()
    scriptActive = false
    stopNightVision()
    stopGodMode()
    stopBacterium()
    stopAutoFloor()
    setCursorLock(false)
    if cursorConn then cursorConn:Disconnect(); cursorConn = nil end
    task.wait(0.05)
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
    print("[Menu] V1.55 unloaded — all loops stopped, keybinds dead")
end

unloadBtn.MouseButton1Click:Connect(unload)

print("[Menu] V1.55 loaded — " ..
    getKeyName(keybinds.menu)      .. "=menu  " ..
    getKeyName(keybinds.breakers)  .. "=breakers  " ..
    getKeyName(keybinds.generator) .. "=generator  " ..
    getKeyName(keybinds.cursor)    .. "=cursor  " ..
    getKeyName(keybinds.autofloor) .. "=autofloor"
)