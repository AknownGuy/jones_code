-- Menu V1.6 | G=menu | V=breakers | F=generator | X=cursor | H=autofloor

local GITHUB_USER   = "AknownGuy"
local GITHUB_REPO   = "jones_code"
local GITHUB_BRANCH = "master"
local SCRIPT_FILE   = "LatestScript.lua"

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
-- ──────────────── SERVICES ────────────────
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
    for idx, prompt in ipairs(prompts) do
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
            if onStatus then onStatus("[BROKEN] Triggered " .. idx .. "/" .. #prompts) end
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

-- ──────────────── FLY ────────────────
local flyEnabled    = false
local flySpeed      = 50
local flyConn       = nil
local flyVelocity   = nil
local flyGyro       = nil

local function startFly()
    if flyConn then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Velocity  = Vector3.zero
    flyVelocity.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    flyVelocity.P         = 9e4
    flyVelocity.Parent    = hrp

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyGyro.D         = 100
    flyGyro.P         = 1e4
    flyGyro.Parent    = hrp

    flyConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            dir += cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            dir -= cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            dir -= cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            dir += cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            dir += Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or
           UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            dir -= Vector3.new(0, 1, 0)
        end
        if flyVelocity and flyVelocity.Parent then
            flyVelocity.Velocity = dir.Magnitude > 0
                and dir.Unit * flySpeed
                or  Vector3.zero
        end
        if flyGyro and flyGyro.Parent then
            flyGyro.CFrame = cam.CFrame
        end
    end)
end

local function stopFly()
    flyEnabled = false
    if flyConn    then flyConn:Disconnect();    flyConn    = nil end
    if flyVelocity then flyVelocity:Destroy();  flyVelocity = nil end
    if flyGyro     then flyGyro:Destroy();      flyGyro     = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

-- respawn cleanup
LocalPlayer.CharacterAdded:Connect(function()
    if flyEnabled then
        task.wait(0.5)
        startFly()
    end
end)

-- ──────────────── NOCLIP ────────────────
local noclipEnabled = false
local noclipConn    = nil

local function startNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    noclipEnabled = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

-- ──────────────── EXPERIMENTAL ────────────────
local useNewTeleport = false

-- ──────────────── FORWARD DECLARE startFire ────────────────
local startFire

-- ──────────────── AUTO FLOOR ────────────────
local autoFloorEnabled = false
local autoFloorThread  = nil

local function startAutoFloor(onStatus)
    if autoFloorThread then return end
    autoFloorThread = task.spawn(function()
        if onStatus then onStatus("Auto floor: starting in 5s...") end
        task.wait(5)
        while autoFloorEnabled do
            local floorsFolder = workspace:FindFirstChild("Floors")
            local hasFloor     = floorsFolder and #floorsFolder:GetChildren() > 0
            if hasFloor then
                if onStatus then onStatus("Floor detected — waiting 5s...") end
                task.wait(5)
                if not autoFloorEnabled then break end
                if onStatus then onStatus("Running breakers (tween)...") end
                local savedNew = useNewTeleport
                useNewTeleport = false
                startFire()
                useNewTeleport = savedNew
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

-- ── Theme ──
local CB  = Color3.fromRGB(11,  11,  17)   -- deep background
local CP  = Color3.fromRGB(18,  18,  28)   -- panel
local CP2 = Color3.fromRGB(24,  24,  38)   -- slightly lighter panel
local CBo = Color3.fromRGB(50,  50,  85)   -- border
local CA  = Color3.fromRGB(85,  125, 255)  -- blue
local CA2 = Color3.fromRGB(50,  185, 115)  -- green
local CA3 = Color3.fromRGB(215, 155, 45)   -- gold
local CA4 = Color3.fromRGB(205, 65,  65)   -- red
local CA5 = Color3.fromRGB(160, 100, 230)  -- purple (abilities)
local CA6 = Color3.fromRGB(50,  195, 195)  -- cyan (utilities)
local CT  = Color3.fromRGB(210, 210, 220)  -- main text
local CS  = Color3.fromRGB(95,  95,  115)  -- subtext

-- ── Main Frame ──
local frame = Instance.new("Frame")
frame.Name             = "Main"
frame.Size             = UDim2.new(0, 380, 0, 640)
frame.Position         = UDim2.new(0.5, -190, 0.5, -320)
frame.BackgroundColor3 = CB
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Visible          = false
frame.Parent           = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local fstroke = Instance.new("UIStroke")
fstroke.Color = CBo; fstroke.Thickness = 1.2; fstroke.Parent = frame

-- ── Title Bar ──
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = CP
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local tpatch = Instance.new("Frame")
tpatch.Size = UDim2.new(1,0,0,10); tpatch.Position = UDim2.new(0,0,1,-10)
tpatch.BackgroundColor3 = CP; tpatch.BorderSizePixel = 0; tpatch.Parent = titleBar

-- Title label
local titleLabel = Instance.new("TextLabel")
titleLabel.Text           = "MENU  //  V1.6"
titleLabel.Font           = Enum.Font.GothamBold
titleLabel.TextSize       = 14
titleLabel.TextColor3     = CT
titleLabel.BackgroundTransparency = 1
titleLabel.Size           = UDim2.new(0, 160, 1, 0)
titleLabel.Position       = UDim2.new(0, 14, 0, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent         = titleBar

-- Commit hash label (set by external loader)
local commitLabel = Instance.new("TextLabel")
commitLabel.Text               = commitHash
commitLabel.Font               = Enum.Font.Gotham
commitLabel.TextSize           = 9
commitLabel.TextColor3         = Color3.fromRGB(70, 70, 105)
commitLabel.BackgroundTransparency = 1
commitLabel.Size               = UDim2.new(0, 60, 0, 14)
commitLabel.Position           = UDim2.new(0, 164, 0.5, -7)
commitLabel.TextXAlignment     = Enum.TextXAlignment.Left
commitLabel.Parent             = titleBar

-- Unload button
local unloadBtn = Instance.new("TextButton")
unloadBtn.Text             = "UNLOAD"
unloadBtn.Font             = Enum.Font.GothamBold
unloadBtn.TextSize         = 10
unloadBtn.TextColor3       = Color3.fromRGB(255, 200, 80)
unloadBtn.BackgroundColor3 = Color3.fromRGB(42, 32, 8)
unloadBtn.Size             = UDim2.new(0, 58, 0, 22)
unloadBtn.Position         = UDim2.new(1, -96, 0.5, -11)
unloadBtn.BorderSizePixel  = 0
unloadBtn.AutoButtonColor  = false
unloadBtn.Parent           = titleBar
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0, 5)
local us = Instance.new("UIStroke"); us.Color = Color3.fromRGB(110,85,18); us.Thickness = 1; us.Parent = unloadBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Text             = "X"
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 12
closeBtn.TextColor3       = CA4
closeBtn.BackgroundColor3 = Color3.fromRGB(36, 14, 14)
closeBtn.Size             = UDim2.new(0, 28, 0, 22)
closeBtn.Position         = UDim2.new(1, -34, 0.5, -11)
closeBtn.BorderSizePixel  = 0
closeBtn.AutoButtonColor  = false
closeBtn.Parent           = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- ── Hint Line ──
local hintLine = Instance.new("TextLabel")
hintLine.Font               = Enum.Font.Gotham
hintLine.TextSize           = 9
hintLine.TextColor3         = CS
hintLine.BackgroundTransparency = 1
hintLine.Size               = UDim2.new(1, -20, 0, 13)
hintLine.Position           = UDim2.new(0, 12, 0, 46)
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

-- ── Tab Row (5 tabs) ──
local tabRow = Instance.new("Frame")
tabRow.Size             = UDim2.new(1, -20, 0, 28)
tabRow.Position         = UDim2.new(0, 10, 0, 64)
tabRow.BackgroundColor3 = CP
tabRow.BorderSizePixel  = 0
tabRow.Parent           = frame
Instance.new("UICorner", tabRow).CornerRadius = UDim.new(0, 7)

local TABS = {
    { id = "main",         label = "MAIN"    },
    { id = "abilities",    label = "ABILIT." },
    { id = "utilities",    label = "UTILS"   },
    { id = "binds",        label = "BINDS"   },
    { id = "experimental", label = "EXPER."  },
}

local tabBtns = {}
local N = #TABS
for i, def in ipairs(TABS) do
    local b = Instance.new("TextButton")
    b.Text               = def.label
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 9
    b.TextColor3         = CS
    b.BackgroundTransparency = 1
    b.Size               = UDim2.new(1/N, -4, 1, -4)
    b.Position           = UDim2.new((i-1)/N, 2, 0, 2)
    b.BorderSizePixel    = 0
    b.AutoButtonColor    = false
    b.Parent             = tabRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    tabBtns[def.id] = b
end

-- ── Pages ──
local function makePage(v)
    local p = Instance.new("ScrollingFrame")
    p.Size                   = UDim2.new(1, 0, 1, -100)
    p.Position               = UDim2.new(0, 0, 0, 100)
    p.BackgroundTransparency = 1
    p.BorderSizePixel        = 0
    p.ScrollBarThickness     = 3
    p.ScrollBarImageColor3   = CBo
    p.CanvasSize             = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    p.Visible                = v
    p.Parent                 = frame
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent        = p
    return p
end

local mainPage         = makePage(true)
local abilitiesPage    = makePage(false)
local utilitiesPage    = makePage(false)
local bindsPage        = makePage(false)
local experimentalPage = makePage(false)

local pages = {
    main         = mainPage,
    abilities    = abilitiesPage,
    utilities    = utilitiesPage,
    binds        = bindsPage,
    experimental = experimentalPage,
}

local function setTab(which)
    for id, pg in pairs(pages)   do pg.Visible = (id == which) end
    for id, btn in pairs(tabBtns) do
        btn.TextColor3           = (id == which) and CT or CS
        btn.BackgroundTransparency = (id == which) and 0 or 1
        if id == which then btn.BackgroundColor3 = CBo end
    end
end

for id, btn in pairs(tabBtns) do
    local tabId = id
    btn.MouseButton1Click:Connect(function() setTab(tabId) end)
end
setTab("main")

-- ════════════════════════════════════════════════
--  UI HELPER FUNCTIONS
-- ════════════════════════════════════════════════

-- Section divider + label
local function uiSection(parent, label, posY, col)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1,-24,0,1); line.Position = UDim2.new(0,12,0,posY+15)
    line.BackgroundColor3 = col; line.BorderSizePixel = 0; line.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextColor3 = col; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.7,0,0,16); lbl.Position = UDim2.new(0,12,0,posY)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
end

-- Standard action button
local function uiButton(parent, text, posY, h, bg, sz, pos)
    local b = Instance.new("TextButton")
    b.Text = text; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.TextColor3 = CT; b.BackgroundColor3 = bg or CA
    b.Size = sz or UDim2.new(1,-24,0,h or 36)
    b.Position = pos or UDim2.new(0,12,0,posY)
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    return b
end

-- Status label
local function uiStatus(parent, text, posY, col)
    local l = Instance.new("TextLabel")
    l.Text = text; l.Font = Enum.Font.Gotham; l.TextSize = 11
    l.TextColor3 = col or CS; l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-24,0,15); l.Position = UDim2.new(0,12,0,posY)
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
    return l
end

-- Progress bar, returns the fill frame
local function uiProgress(parent, posY, fillCol)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-24,0,5); track.Position = UDim2.new(0,12,0,posY)
    track.BackgroundColor3 = CP2; track.BorderSizePixel = 0; track.Parent = parent
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0,0,1,0); fill.BackgroundColor3 = fillCol or CA
    fill.BorderSizePixel = 0; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    return fill
end

-- Toggle row (label on left, ON/OFF button on right)
local function uiToggleRow(parent, label, posY, activeCol, inactiveCol)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-24,0,32); row.Position = UDim2.new(0,12,0,posY)
    row.BackgroundColor3 = CP2; row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextColor3 = CT; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,-58,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local tog = Instance.new("TextButton")
    tog.Text = "OFF"; tog.Font = Enum.Font.GothamBold; tog.TextSize = 10
    tog.TextColor3 = CT; tog.BackgroundColor3 = inactiveCol
    tog.Size = UDim2.new(0,42,0,20); tog.Position = UDim2.new(1,-48,0.5,-10)
    tog.BorderSizePixel = 0; tog.AutoButtonColor = false; tog.Parent = row
    Instance.new("UICorner", tog).CornerRadius = UDim.new(0,5)
    return tog, activeCol, inactiveCol
end

-- Input row (label + textbox)
local function uiInputRow(parent, label, default, posY, strokeCol)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-24,0,32); row.Position = UDim2.new(0,12,0,posY)
    row.BackgroundColor3 = CP2; row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Text = label; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextColor3 = CT; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.58,0,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local inp = Instance.new("TextBox")
    inp.Text = tostring(default); inp.Font = Enum.Font.GothamBold; inp.TextSize = 12
    inp.TextColor3 = CT; inp.BackgroundColor3 = Color3.fromRGB(10,10,18)
    inp.Size = UDim2.new(0.30,0,0,22); inp.Position = UDim2.new(0.65,0,0.5,-11)
    inp.BorderSizePixel = 0; inp.ClearTextOnFocus = false
    inp.TextXAlignment = Enum.TextXAlignment.Center; inp.Parent = row
    Instance.new("UICorner", inp).CornerRadius = UDim.new(0,4)
    local s = Instance.new("UIStroke"); s.Color = strokeCol or CA3; s.Thickness = 1; s.Parent = inp
    return inp
end

-- Spacer
local function uiSpacer(parent, posY, h)
    local s = Instance.new("Frame")
    s.Size = UDim2.new(1,0,0,h or 10)
    s.Position = UDim2.new(0,0,0,posY)
    s.BackgroundTransparency = 1; s.BorderSizePixel = 0; s.Parent = parent
end

-- Ability button with optional tag label (e.g. [BROKEN], [REQ BADGE])
local function uiAbilityButton(parent, label, tag, posY, bg, tagCol)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-24,0,40); row.Position = UDim2.new(0,12,0,posY)
    row.BackgroundColor3 = bg or Color3.fromRGB(28,20,50)
    row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Text = label; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 12
    nameLbl.TextColor3 = CT; nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1,-80,1,0); nameLbl.Position = UDim2.new(0,12,0,0)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row

    if tag then
        local tagLbl = Instance.new("TextLabel")
        tagLbl.Text = tag; tagLbl.Font = Enum.Font.Gotham; tagLbl.TextSize = 9
        tagLbl.TextColor3 = tagCol or CA3; tagLbl.BackgroundTransparency = 1
        tagLbl.Size = UDim2.new(0,70,0,14); tagLbl.Position = UDim2.new(1,-78,0,6)
        tagLbl.TextXAlignment = Enum.TextXAlignment.Right; tagLbl.Parent = row
    end

    local btn = Instance.new("TextButton")
    btn.Text = "USE"; btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    btn.TextColor3 = CT; btn.BackgroundColor3 = CA5
    btn.Size = UDim2.new(0,40,0,22); btn.Position = UDim2.new(1,-48,0.5,-11)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(175,120,255) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = CA5 }):Play()
    end)

    return btn
end

-- Fly speed slider (returns fill frame and knob)
local function uiSlider(parent, posY, minVal, maxVal, currentVal, onChange)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-24,0,18); track.Position = UDim2.new(0,12,0,posY)
    track.BackgroundColor3 = CP2; track.BorderSizePixel = 0; track.Parent = parent
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = CA6; fill.BorderSizePixel = 0; fill.Parent = track
    fill.Size = UDim2.new((currentVal-minVal)/(maxVal-minVal),0,1,0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    local pct0 = (currentVal-minVal)/(maxVal-minVal)
    knob.Size = UDim2.new(0,18,0,18); knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new(pct0,0,0.5,0)
    knob.BackgroundColor3 = CT; knob.BorderSizePixel = 0; knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local dragging = false
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local abs  = track.AbsolutePosition
        local sz   = track.AbsoluteSize
        local relX = math.clamp(inp.Position.X - abs.X, 0, sz.X)
        local pct  = relX / sz.X
        local val  = math.floor(minVal + pct * (maxVal - minVal))
        fill.Size  = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        if onChange then onChange(val) end
    end)

    return fill, knob
end

-- ════════════════════════════════════════════════
--  MAIN PAGE
-- ════════════════════════════════════════════════

-- ── BREAKERS ──
uiSection(mainPage, "BREAKERS", 10, CA2)

local breakerStatus = uiStatus(mainPage, 32, CA2)
breakerStatus.Text = "Status: ready"

local floorDisplay = uiStatus(mainPage, 49, CS)
floorDisplay.Text = "Floor: —"

local breakerProg = uiProgress(mainPage, 68, CA2)

-- Two side-by-side buttons
local fireBtn = uiButton(
    mainPage, "ACTIVATE + TP  [V]", 78, 36,
    Color3.fromRGB(22, 68, 46),
    UDim2.new(0.62, -16, 0, 36),
    UDim2.new(0, 12, 0, 78)
)
local activateBtn = uiButton(
    mainPage, "ACTIVATE", 78, 36,
    Color3.fromRGB(18, 42, 32),
    UDim2.new(0.38, -8, 0, 36),
    UDim2.new(0.62, 0, 0, 78)
)
local actStroke = Instance.new("UIStroke")
actStroke.Color = CA2; actStroke.Thickness = 1; actStroke.Transparency = 0.5
actStroke.Parent = activateBtn

for _, b in ipairs({fireBtn, activateBtn}) do
    local orig = b.BackgroundColor3
    b.MouseEnter:Connect(function()
        if not busy then
            TweenService:Create(b, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(orig.R*255+14, orig.G*255+28, orig.B*255+18)
            }):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        if not busy then
            TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = orig }):Play()
        end
    end)
end

uiSpacer(mainPage, 120, 12)

-- ── GENERATOR ──
uiSection(mainPage, "GENERATOR", 136, CA)

local genStatus = uiStatus(mainPage, 158, CA)
genStatus.Text = "Status: ready  (A to Z)    bind: F"

local genProg = uiProgress(mainPage, 177, CA)

local genBtn = uiButton(mainPage, "SOLVE GENERATOR  [F]", 186, 36, Color3.fromRGB(26,40,105))
genBtn.MouseEnter:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40,60,148) }):Play()
end)
genBtn.MouseLeave:Connect(function()
    TweenService:Create(genBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(26,40,105) }):Play()
end)

uiSpacer(mainPage, 228, 12)

-- ── PLAYER ──
uiSection(mainPage, "PLAYER", 244, CA3)

local godToggle, godActive, godInactive = uiToggleRow(
    mainPage, "God mode (auto-heal to max HP)", 266,
    Color3.fromRGB(26,90,52), Color3.fromRGB(52,18,18)
)
godToggle.BackgroundColor3 = Color3.fromRGB(52,18,18)

local healInput = uiInputRow(mainPage, "Heal amount:", 10, 306, CA2)
local damageValue = 10
healInput.FocusLost:Connect(function()
    local v = tonumber(healInput.Text)
    if v then damageValue = v else healInput.Text = tostring(damageValue) end
end)

local healBtn = uiButton(mainPage, "HEAL PLAYER", 346, 36, Color3.fromRGB(28,76,42))
healBtn.MouseEnter:Connect(function()
    TweenService:Create(healBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40,108,60) }):Play()
end)
healBtn.MouseLeave:Connect(function()
    TweenService:Create(healBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28,76,42) }):Play()
end)

local nvToggle, nvActive, nvInactive = uiToggleRow(
    mainPage, "Night vision loop (every 10s)", 392,
    Color3.fromRGB(26,52,125), Color3.fromRGB(52,18,18)
)
nvToggle.BackgroundColor3 = Color3.fromRGB(52,18,18)

local cursorBtn = uiButton(mainPage, "CURSOR: UNLOCKED  [X]", 432, 36, Color3.fromRGB(32,28,58))
cursorBtn.MouseEnter:Connect(function()
    TweenService:Create(cursorBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(48,42,85) }):Play()
end)
cursorBtn.MouseLeave:Connect(function()
    TweenService:Create(cursorBtn, TweenInfo.new(0.1), {
        BackgroundColor3 = cursorLocked and Color3.fromRGB(46,38,88) or Color3.fromRGB(32,28,58)
    }):Play()
end)

local autoFloorToggle, afActive, afInactive = uiToggleRow(
    mainPage, "Auto floor  [H]", 476,
    Color3.fromRGB(52,38,98), Color3.fromRGB(38,20,52)
)
autoFloorToggle.BackgroundColor3 = Color3.fromRGB(38,20,52)

local autoFloorStatus = uiStatus(mainPage, 514, Color3.fromRGB(155,125,215))
autoFloorStatus.Text = "Auto floor: off"

uiSpacer(mainPage, 532, 12)

-- ── ADD MONEY ──
uiSection(mainPage, "ADD MONEY", 548, CA3)

local moneyInput = uiInputRow(mainPage, "Token amount:", 100, 570, CA3)
local moneyValue = 100
moneyInput.FocusLost:Connect(function()
    local v = tonumber(moneyInput.Text)
    if v then moneyValue = v else moneyInput.Text = tostring(moneyValue) end
end)

local moneyBtn = uiButton(mainPage, "ADD MONEY", 610, 36, Color3.fromRGB(76,52,12))
moneyBtn.MouseEnter:Connect(function()
    TweenService:Create(moneyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(105,74,18) }):Play()
end)
moneyBtn.MouseLeave:Connect(function()
    TweenService:Create(moneyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(76,52,12) }):Play()
end)

-- ════════════════════════════════════════════════
--  ABILITIES PAGE
-- ════════════════════════════════════════════════
uiSection(abilitiesPage, "ABILITIES", 10, CA5)

local abilityInfo = Instance.new("TextLabel")
abilityInfo.Text = "Fires ability remotes directly. Effects depend on server state and whether you own the required badge."
abilityInfo.Font = Enum.Font.Gotham; abilityInfo.TextSize = 10; abilityInfo.TextColor3 = CS
abilityInfo.BackgroundTransparency = 1; abilityInfo.Size = UDim2.new(1,-24,0,32)
abilityInfo.Position = UDim2.new(0,12,0,30)
abilityInfo.TextXAlignment = Enum.TextXAlignment.Left; abilityInfo.TextWrapped = true
abilityInfo.Parent = abilitiesPage

local abilityStatus = uiStatus(abilitiesPage, 66, CA5)
abilityStatus.Text = "Last fired: —"

-- All Or Nothing
local allOrNothingBtn = uiAbilityButton(abilitiesPage, "All Or Nothing", "REQ BADGE", 84, Color3.fromRGB(28,20,50), CA3)
allOrNothingBtn.MouseButton1Click:Connect(function()
    pcall(function()
        ReplicatedStorage:WaitForChild("Game"):WaitForChild("Remotes")
            :WaitForChild("Abilities"):WaitForChild("AllOrNothing"):FireServer("useAbility")
    end)
    abilityStatus.Text = "Fired: All Or Nothing"
end)

-- Halt
local haltBtn = uiAbilityButton(abilitiesPage, "Halt", nil, 132, Color3.fromRGB(28,20,50))
haltBtn.MouseButton1Click:Connect(function()
    pcall(function()
        AbilityEvents:WaitForChild("HaltUsed"):FireServer()
    end)
    abilityStatus.Text = "Fired: Halt"
end)

-- Seeker
local seekerBtn = uiAbilityButton(abilitiesPage, "Seeker", nil, 180, Color3.fromRGB(28,20,50))
seekerBtn.MouseButton1Click:Connect(function()
    pcall(function()
        AbilityEvents:WaitForChild("NightVisionUsed"):FireServer()
    end)
    abilityStatus.Text = "Fired: Seeker"
end)

-- Dash
local dashBtn = uiAbilityButton(abilitiesPage, "Dash", "BROKEN", 228, Color3.fromRGB(28,20,50), CA4)
dashBtn.BackgroundColor3 = Color3.fromRGB(35,20,20)
dashBtn.MouseButton1Click:Connect(function()
    pcall(function()
        AbilityEvents:WaitForChild("DashUsed"):FireServer()
    end)
    abilityStatus.Text = "Fired: Dash (may not work)"
end)

-- Last Breath
local lastBreathBtn = uiAbilityButton(abilitiesPage, "Last Breath", nil, 276, Color3.fromRGB(28,20,50))
lastBreathBtn.MouseButton1Click:Connect(function()
    pcall(function()
        AbilityEvents:WaitForChild("LastBreathUsed"):FireServer()
    end)
    abilityStatus.Text = "Fired: Last Breath"
end)

-- ════════════════════════════════════════════════
--  UTILITIES PAGE
-- ════════════════════════════════════════════════
uiSection(utilitiesPage, "FLY", 10, CA6)

local flyToggle, flyActive, flyInactive = uiToggleRow(
    utilitiesPage, "Fly  (W/A/S/D + Space / LCtrl)", 30,
    Color3.fromRGB(20,90,90), Color3.fromRGB(52,18,18)
)
flyToggle.BackgroundColor3 = Color3.fromRGB(52,18,18)

local flySpeedLabel = uiStatus(utilitiesPage, 70, CA6)
flySpeedLabel.Text = "Speed: " .. flySpeed .. "  (drag slider or type below)"

-- Slider: 10–300
uiSlider(utilitiesPage, 88, 10, 300, flySpeed, function(val)
    flySpeed = val
    flySpeedLabel.Text = "Speed: " .. flySpeed
end)

local flySpeedInput = uiInputRow(utilitiesPage, "Manual speed value:", flySpeed, 114, CA6)
flySpeedInput.FocusLost:Connect(function()
    local v = tonumber(flySpeedInput.Text)
    if v then
        flySpeed = math.clamp(v, 1, 9999)
        flySpeedLabel.Text = "Speed: " .. flySpeed
    else
        flySpeedInput.Text = tostring(flySpeed)
    end
end)

uiSpacer(utilitiesPage, 154, 12)

-- ── NOCLIP ──
uiSection(utilitiesPage, "NOCLIP", 170, CA6)

local noclipToggle, ncActive, ncInactive = uiToggleRow(
    utilitiesPage, "No Clip (pass through walls)", 190,
    Color3.fromRGB(20,90,90), Color3.fromRGB(52,18,18)
)
noclipToggle.BackgroundColor3 = Color3.fromRGB(52,18,18)

uiSpacer(utilitiesPage, 230, 12)

-- ── SERVER SPEED ──
uiSection(utilitiesPage, "SERVER WALKSPEED", 246, CA6)

local speedInfo = uiStatus(utilitiesPage, 268, CS)
speedInfo.Text = "Fires UpdateWalkspeed to the server."

local speedInput = uiInputRow(utilitiesPage, "Walkspeed value:", 16, 286, CA6)
local speedValue = 16

speedInput.FocusLost:Connect(function()
    local v = tonumber(speedInput.Text)
    if v then speedValue = v else speedInput.Text = tostring(speedValue) end
end)

local speedBtn = uiButton(utilitiesPage, "SET SPEED", 326, 36, Color3.fromRGB(18,72,72))
speedBtn.MouseEnter:Connect(function()
    TweenService:Create(speedBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(26,100,100) }):Play()
end)
speedBtn.MouseLeave:Connect(function()
    TweenService:Create(speedBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(18,72,72) }):Play()
end)
speedBtn.MouseButton1Click:Connect(function()
    local v = tonumber(speedInput.Text) or speedValue
    speedValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("UpdateWalkspeed"):FireServer(speedValue)
    end)
end)

local resetSpeedBtn = uiButton(utilitiesPage, "RESET (16)", 370, 36, Color3.fromRGB(42,30,14))
resetSpeedBtn.MouseEnter:Connect(function()
    TweenService:Create(resetSpeedBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(60,42,20) }):Play()
end)
resetSpeedBtn.MouseLeave:Connect(function()
    TweenService:Create(resetSpeedBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(42,30,14) }):Play()
end)
resetSpeedBtn.MouseButton1Click:Connect(function()
    speedValue = 16
    speedInput.Text = "16"
    pcall(function()
        ReplicatedStorage:WaitForChild("UpdateWalkspeed"):FireServer(16)
    end)
end)

-- ════════════════════════════════════════════════
--  BINDS PAGE
-- ════════════════════════════════════════════════
local bindDefs = {
    { id = "menu",      label = "Toggle Menu"     },
    { id = "breakers",  label = "Activate + TP"   },
    { id = "generator", label = "Solve Generator" },
    { id = "cursor",    label = "Cursor Lock"      },
    { id = "autofloor", label = "Auto Floor"       },
}

local rebindBtns = {}
local rebinding  = nil

uiSection(bindsPage, "KEYBINDS", 10, CBo)

for i, def in ipairs(bindDefs) do
    local rowY = 30 + (i-1) * 46
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-24,0,38); row.Position = UDim2.new(0,12,0,rowY)
    row.BackgroundColor3 = CP2; row.BorderSizePixel = 0; row.Parent = bindsPage
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Text = def.label; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
    lbl.TextColor3 = CT; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.52,0,1,0); lbl.Position = UDim2.new(0,12,0,0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local kb = Instance.new("TextButton")
    kb.Text = getKeyName(keybinds[def.id]); kb.Font = Enum.Font.GothamBold; kb.TextSize = 11
    kb.TextColor3 = CT; kb.BackgroundColor3 = Color3.fromRGB(32,32,58)
    kb.Size = UDim2.new(0.34,0,0,26); kb.Position = UDim2.new(0.58,0,0.5,-13)
    kb.BorderSizePixel = 0; kb.AutoButtonColor = false; kb.Parent = row
    Instance.new("UICorner", kb).CornerRadius = UDim.new(0,5)
    local ks = Instance.new("UIStroke"); ks.Color = CBo; ks.Thickness = 1; ks.Parent = kb
    rebindBtns[def.id] = kb
    local bindId = def.id
    kb.MouseButton1Click:Connect(function()
        if rebinding then return end
        rebinding = bindId
        kb.Text = "Press key..."
        kb.TextColor3 = CA3
        kb.BackgroundColor3 = Color3.fromRGB(48,42,14)
    end)
end

local bindsNote = Instance.new("TextLabel")
bindsNote.Text = "Click a key slot then press any key to rebind.  ESC = cancel."
bindsNote.Font = Enum.Font.Gotham; bindsNote.TextSize = 10; bindsNote.TextColor3 = CS
bindsNote.BackgroundTransparency = 1; bindsNote.Size = UDim2.new(1,-24,0,32)
bindsNote.Position = UDim2.new(0,12,0,30 + #bindDefs*46 + 10)
bindsNote.TextXAlignment = Enum.TextXAlignment.Left; bindsNote.TextWrapped = true
bindsNote.Parent = bindsPage

-- ════════════════════════════════════════════════
--  EXPERIMENTAL PAGE
-- ════════════════════════════════════════════════
uiSection(experimentalPage, "TELEPORT SYSTEM", 10, CA)

local newTpToggle, ntpActive, ntpInactive = uiToggleRow(
    experimentalPage, "New teleport system (instant snap)", 30,
    Color3.fromRGB(38,76,155), Color3.fromRGB(28,28,52)
)
newTpToggle.BackgroundColor3 = Color3.fromRGB(28,28,52)

local ntpDesc = Instance.new("TextLabel")
ntpDesc.Text = "OFF = smooth tween slide (default, stable)\nON  = instant snap with mid-point steps (experimental)"
ntpDesc.Font = Enum.Font.Gotham; ntpDesc.TextSize = 10; ntpDesc.TextColor3 = CS
ntpDesc.BackgroundTransparency = 1; ntpDesc.Size = UDim2.new(1,-24,0,34)
ntpDesc.Position = UDim2.new(0,12,0,68)
ntpDesc.TextXAlignment = Enum.TextXAlignment.Left; ntpDesc.TextWrapped = true
ntpDesc.Parent = experimentalPage

uiSpacer(experimentalPage, 106, 12)

-- ── REMOTE TOOLS ──
uiSection(experimentalPage, "REMOTE TOOLS", 122, CA3)

local remoteStatus = uiStatus(experimentalPage, 144, CA3)
remoteStatus.Text = "Last fired: —"

local tpPlayersBtn = uiButton(experimentalPage, "Teleport Players", 162, 36, Color3.fromRGB(55,38,14))
tpPlayersBtn.MouseEnter:Connect(function()
    TweenService:Create(tpPlayersBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(78,54,20) }):Play()
end)
tpPlayersBtn.MouseLeave:Connect(function()
    TweenService:Create(tpPlayersBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(55,38,14) }):Play()
end)
tpPlayersBtn.MouseButton1Click:Connect(function()
    pcall(function()
        ReplicatedStorage:WaitForChild("TeleportPlayers"):FireServer()
    end)
    remoteStatus.Text = "Fired: TeleportPlayers"
end)

local playerLoadBtn = uiButton(experimentalPage, "Player Load", 206, 36, Color3.fromRGB(55,38,14))
playerLoadBtn.MouseEnter:Connect(function()
    TweenService:Create(playerLoadBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(78,54,20) }):Play()
end)
playerLoadBtn.MouseLeave:Connect(function()
    TweenService:Create(playerLoadBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(55,38,14) }):Play()
end)
playerLoadBtn.MouseButton1Click:Connect(function()
    pcall(function()
        ReplicatedStorage:WaitForChild("PlayerLoaded"):FireServer()
    end)
    remoteStatus.Text = "Fired: PlayerLoaded"
end)

uiSpacer(experimentalPage, 248, 12)

-- ── BACTERIUM ──
uiSection(experimentalPage, "BACTERIUM AVOID  [BROKEN]", 264, CA4)

local bacteriumToggle, batActive, batInactive = uiToggleRow(
    experimentalPage, "Avoid Bacterium — CURRENTLY BROKEN", 284,
    Color3.fromRGB(95,22,22), Color3.fromRGB(52,18,18)
)
bacteriumToggle.BackgroundColor3 = Color3.fromRGB(52,18,18)

local batStatus = uiStatus(experimentalPage, 322, CA4)
batStatus.Text = "Bacterium: off  (broken — unreliable)"

local batInfo = Instance.new("TextLabel")
batInfo.Text = "Teleports to each Bacterium on the current floor and triggers its proximity prompt. Proximity detection is currently unreliable — pending fix."
batInfo.Font = Enum.Font.Gotham; batInfo.TextSize = 10; batInfo.TextColor3 = CS
batInfo.BackgroundTransparency = 1; batInfo.Size = UDim2.new(1,-24,0,46)
batInfo.Position = UDim2.new(0,12,0,340)
batInfo.TextXAlignment = Enum.TextXAlignment.Left; batInfo.TextWrapped = true
batInfo.Parent = experimentalPage

-- ════════════════════════════════════════════════
--  BUTTON LOGIC — MAIN PAGE
-- ════════════════════════════════════════════════
godToggle.MouseButton1Click:Connect(function()
    godModeEnabled = not godModeEnabled
    godToggle.Text = godModeEnabled and "ON" or "OFF"
    godToggle.BackgroundColor3 = godModeEnabled and godActive or godInactive
    if godModeEnabled then startGodMode() else stopGodMode() end
end)

healBtn.MouseButton1Click:Connect(function()
    local v = tonumber(healInput.Text) or damageValue
    damageValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("TakeDamage"):FireServer(-damageValue, "Weeping")
    end)
end)

nvToggle.MouseButton1Click:Connect(function()
    nightVisionEnabled = not nightVisionEnabled
    nvToggle.Text = nightVisionEnabled and "ON" or "OFF"
    nvToggle.BackgroundColor3 = nightVisionEnabled and nvActive or nvInactive
    if nightVisionEnabled then startNightVision() else stopNightVision() end
end)

local function toggleCursor()
    setCursorLock(not cursorLocked)
    cursorBtn.Text = cursorLocked
        and ("CURSOR: LOCKED  [" .. getKeyName(keybinds.cursor) .. "]")
        or  ("CURSOR: UNLOCKED  [" .. getKeyName(keybinds.cursor) .. "]")
    cursorBtn.BackgroundColor3 = cursorLocked and Color3.fromRGB(46,38,88) or Color3.fromRGB(32,28,58)
end
cursorBtn.MouseButton1Click:Connect(toggleCursor)

local function toggleAutoFloor()
    autoFloorEnabled = not autoFloorEnabled
    autoFloorToggle.Text = autoFloorEnabled and "ON" or "OFF"
    autoFloorToggle.BackgroundColor3 = autoFloorEnabled and afActive or afInactive
    if autoFloorEnabled then
        autoFloorStatus.Text = "Auto floor: active"
        startAutoFloor(function(msg)
            autoFloorStatus.Text = msg
        end)
    else
        autoFloorStatus.Text = "Auto floor: off"
        stopAutoFloor()
    end
end
autoFloorToggle.MouseButton1Click:Connect(toggleAutoFloor)

moneyBtn.MouseButton1Click:Connect(function()
    local v = tonumber(moneyInput.Text) or moneyValue
    moneyValue = v
    pcall(function()
        ReplicatedStorage:WaitForChild("QuestRemotes"):WaitForChild("Reward"):FireServer("Tokens", moneyValue)
    end)
end)

-- Floor display live poll
task.spawn(function()
    while scriptActive do
        local fo = getFloorObj()
        floorDisplay.Text = fo and ("Floor: " .. tostring(fo.Value)) or "Floor: —"
        task.wait(0.5)
    end
end)

-- ── UTILITIES BUTTON LOGIC ──
flyToggle.MouseButton1Click:Connect(function()
    flyEnabled = not flyEnabled
    flyToggle.Text = flyEnabled and "ON" or "OFF"
    flyToggle.BackgroundColor3 = flyEnabled and flyActive or flyInactive
    if flyEnabled then startFly() else stopFly() end
end)

-- Sync slider output back to flySpeedInput text
local origSliderChange = nil  -- already wired above via uiSlider onChange

noclipToggle.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    noclipToggle.Text = noclipEnabled and "ON" or "OFF"
    noclipToggle.BackgroundColor3 = noclipEnabled and ncActive or ncInactive
    if noclipEnabled then startNoclip() else stopNoclip() end
end)

-- ── EXPERIMENTAL BUTTON LOGIC ──
newTpToggle.MouseButton1Click:Connect(function()
    useNewTeleport = not useNewTeleport
    newTpToggle.Text = useNewTeleport and "ON" or "OFF"
    newTpToggle.BackgroundColor3 = useNewTeleport and ntpActive or ntpInactive
end)

bacteriumToggle.MouseButton1Click:Connect(function()
    bacteriumEnabled = not bacteriumEnabled
    bacteriumToggle.Text = bacteriumEnabled and "ON" or "OFF"
    bacteriumToggle.BackgroundColor3 = bacteriumEnabled and batActive or batInactive
    if bacteriumEnabled then
        batStatus.Text = "[BROKEN] Active — results unreliable"
        startBacterium(function(msg) batStatus.Text = msg end)
    else
        batStatus.Text = "Bacterium: off  (broken — unreliable)"
        stopBacterium()
    end
end)

-- ════════════════════════════════════════════════
--  GENERATOR LOGIC
-- ════════════════════════════════════════════════
local generatorBusy = false

local function runGenerator()
    if generatorBusy then return end
    generatorBusy = true
    genBtn.BackgroundColor3 = Color3.fromRGB(14,16,36)
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
            genStatus.Text = "Firing: " .. letter .. "  (" .. (idx-64) .. "/26)"
            genStatus.TextColor3 = CA
            task.wait(0.05)
        end
        genStatus.Text = "Done — GeneratorStart + A to Z sent"
        genStatus.TextColor3 = Color3.fromRGB(110,195,255)
        task.wait(2.5)
        TweenService:Create(genProg, TweenInfo.new(0.4), { Size = UDim2.new(0,0,1,0) }):Play()
        genBtn.Text = "SOLVE GENERATOR  [F]"
        TweenService:Create(genBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(26,40,105) }):Play()
        genStatus.Text = "Status: ready  (A to Z)    bind: F"
        genStatus.TextColor3 = CA
        generatorBusy = false
    end)
end

genBtn.MouseButton1Click:Connect(runGenerator)

-- ════════════════════════════════════════════════
--  BREAKER CALLBACKS
-- ════════════════════════════════════════════════
local function onBreakerProgress(i, total)
    TweenService:Create(breakerProg, TweenInfo.new(FIRE_DELAY*0.9), {
        Size = UDim2.new(i/total, 0, 1, 0)
    }):Play()
    breakerProg.BackgroundColor3 = CA2
    breakerStatus.Text = "Activating: " .. i .. " / " .. total
    breakerStatus.TextColor3 = CA2
end

local function onBreakerDone(success, total)
    if total == 0 then
        breakerStatus.Text = "No breakers found"
        breakerStatus.TextColor3 = CA4
    else
        breakerStatus.Text = success .. "/" .. total .. " activated"
        breakerStatus.TextColor3 = CA2
    end
    task.wait(2.5)
    TweenService:Create(breakerProg, TweenInfo.new(0.4), { Size = UDim2.new(0,0,1,0) }):Play()
    fireBtn.Text     = "ACTIVATE + TP  [V]"
    activateBtn.Text = "ACTIVATE"
    TweenService:Create(fireBtn,     TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(22,68,46)  }):Play()
    TweenService:Create(activateBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18,42,32)  }):Play()
    breakerStatus.Text = "Status: ready"
    breakerStatus.TextColor3 = CA2
end

-- ════════════════════════════════════════════════
--  TWEEN SEQUENCE (default)
--  1. Smooth slide → 0,5,5   (0.7s)
--  2. Wait 0.5s
--  3. Activate breakers
--  4. Wait 0.5s
--  5. Smooth slide → 20,5,5  (0.7s)
--  6. Fire elevator TouchInterests
-- ════════════════════════════════════════════════
local function runTweenSequence(onScanDone)
    breakerStatus.Text = "Sliding to position..."
    breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
    smoothTeleport(0, 5, 5, 0.7)
    task.wait(0.5)

    local floorBefore = nil
    local fo = getFloorObj()
    if fo then floorBefore = fo.Value end

    fireBtn.Text = "Activating..."
    scanAndFire(
        function(s) breakerStatus.Text = s; breakerStatus.TextColor3 = CA2 end,
        onBreakerProgress,
        function(success, total)
            task.wait(0.5)
            breakerStatus.Text = "Sliding back..."
            breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
            smoothTeleport(20, 5, 5, 0.7)
            task.wait(0.15)
            fireElevatorTrigger()
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

-- ════════════════════════════════════════════════
--  EXPERIMENTAL INSTANT SEQUENCE
--  1. Snap mid (10,5,5) → full (0,5,5)
--  2. Wait 0.5s → activate breakers
--  3. Wait 0.5s → fire elevator triggers
--  4. Wait 0.2s → snap mid (10,5,5) → full (20,5,5)
-- ════════════════════════════════════════════════
local function runInstantSequence(onScanDone)
    breakerStatus.Text = "[EXP] Snapping to position..."
    breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
    teleportTo(10, 5, 5)
    task.wait(0.08)
    teleportTo(0, 5, 5)
    task.wait(0.5)

    local floorBefore = nil
    local fo = getFloorObj()
    if fo then floorBefore = fo.Value end

    fireBtn.Text = "[EXP] Activating..."
    scanAndFire(
        function(s) breakerStatus.Text = s; breakerStatus.TextColor3 = CA2 end,
        onBreakerProgress,
        function(success, total)
            task.wait(0.5)
            breakerStatus.Text = "[EXP] Firing elevator..."
            breakerStatus.TextColor3 = CS
            fireElevatorTrigger()
            task.wait(0.2)
            breakerStatus.Text = "[EXP] Snapping back..."
            breakerStatus.TextColor3 = Color3.fromRGB(120,160,255)
            teleportTo(10, 5, 5)
            task.wait(0.08)
            teleportTo(20, 5, 5)
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

-- ── startFire: dispatches based on toggle ──
startFire = function()
    if busy then return end
    fireBtn.BackgroundColor3 = Color3.fromRGB(14,24,18)
    fireBtn.Text = "Running..."
    task.spawn(function()
        if useNewTeleport then
            runInstantSequence(onBreakerDone)
        else
            runTweenSequence(onBreakerDone)
        end
    end)
end

-- ACTIVATE only (no teleport)
local function startFireNoTeleport()
    if busy then return end
    activateBtn.BackgroundColor3 = Color3.fromRGB(12,28,20)
    activateBtn.Text = "Running..."
    task.spawn(function()
        scanAndFire(
            function(s) breakerStatus.Text = s; breakerStatus.TextColor3 = CA2 end,
            onBreakerProgress,
            onBreakerDone
        )
    end)
end

fireBtn.MouseButton1Click:Connect(startFire)
activateBtn.MouseButton1Click:Connect(startFireNoTeleport)

-- ════════════════════════════════════════════════
--  INPUT / KEYBINDS
-- ════════════════════════════════════════════════
local menuOpen = false

UserInputService.InputBegan:Connect(function(inp, processed)
    if not scriptActive then return end

    -- Rebind capture (before processed guard)
    if rebinding and inp.UserInputType == Enum.UserInputType.Keyboard then
        local newKey = inp.KeyCode
        local btn    = rebindBtns[rebinding]
        if newKey == Enum.KeyCode.Escape then
            if btn then
                btn.Text = getKeyName(keybinds[rebinding])
                btn.TextColor3 = CT
                btn.BackgroundColor3 = Color3.fromRGB(32,32,58)
            end
        else
            keybinds[rebinding] = newKey
            if btn then
                btn.Text = getKeyName(newKey)
                btn.TextColor3 = CT
                btn.BackgroundColor3 = Color3.fromRGB(32,32,58)
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

-- ════════════════════════════════════════════════
--  UNLOAD
-- ════════════════════════════════════════════════
local function unload()
    scriptActive = false
    stopNightVision()
    stopGodMode()
    stopBacterium()
    stopAutoFloor()
    stopFly()
    stopNoclip()
    setCursorLock(false)
    if cursorConn then cursorConn:Disconnect(); cursorConn = nil end
    task.wait(0.05)
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
    print("[Menu] V1.6 unloaded — all loops stopped, keybinds dead")
end

unloadBtn.MouseButton1Click:Connect(unload)

print("[Menu] V1.6 loaded — " ..
    getKeyName(keybinds.menu)      .. "=menu  " ..
    getKeyName(keybinds.breakers)  .. "=breakers  " ..
    getKeyName(keybinds.generator) .. "=generator  " ..
    getKeyName(keybinds.cursor)    .. "=cursor  " ..
    getKeyName(keybinds.autofloor) .. "=autofloor"
)