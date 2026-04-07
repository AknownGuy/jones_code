-- Menu V1.6 | G=menu | V=breakers | F=generator | X=cursor | H=autofloor

local GITHUB_USER   = "AknownGuy"
local GITHUB_REPO   = "LARP_Hub"
local GITHUB_BRANCH = "master"
local SCRIPT_FILE   = "EARLY-V1.6.lua"

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

local env = (getgenv and getgenv()) or _G

local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local FIRE_DELAY = 0.02
local scriptActive = true
local menuOpen = false

local keybinds = {
    menu = Enum.KeyCode.G,
    breakers = Enum.KeyCode.V,
    generator = Enum.KeyCode.F,
    cursor = Enum.KeyCode.X,
    autofloor = Enum.KeyCode.H,
    fly = nil,
}

local function keyName(kc)
    return typeof(kc) == 'EnumItem' and tostring(kc):gsub('Enum.KeyCode.', '') or 'NONE'
end

local AbilityEvents = RS:WaitForChild('AbilityEvents')
local UltraMechanicUsed = AbilityEvents:WaitForChild('UltraMechanicUsed')
local AllOrNothingRemote = RS:WaitForChild('Game'):WaitForChild('Remotes'):WaitForChild('Abilities'):WaitForChild('AllOrNothing')
local TeleportPlayersRemote = RS:WaitForChild('TeleportPlayers')
local PlayerLoadedRemote = RS:WaitForChild('PlayerLoaded')
local UpdateWalkspeedRemote = RS:WaitForChild('UpdateWalkspeed')

local C = {
    bg = Color3.fromRGB(12,17,26), panel = Color3.fromRGB(21,29,41), panel2 = Color3.fromRGB(15,22,33),
    stroke = Color3.fromRGB(74,99,132), text = Color3.fromRGB(236,241,248), sub = Color3.fromRGB(142,154,173),
    blue = Color3.fromRGB(95,166,255), green = Color3.fromRGB(87,210,170), gold = Color3.fromRGB(234,187,97),
    red = Color3.fromRGB(227,102,102), gray = Color3.fromRGB(94,102,118)
}

local function hum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass('Humanoid')
end

local function root()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function floorObj()
    local data = LocalPlayer:FindFirstChild('InGameData')
    return data and data:FindFirstChild('FloorReached')
end

local function teleportTo(x, y, z)
    local hrp = root()
    if hrp then hrp.CFrame = CFrame.new(x, y, z) end
end

local function smoothTeleport(x, y, z, duration)
    local hrp = root()
    if not hrp then return end
    local startCF, endCF = hrp.CFrame, CFrame.new(x, y, z)
    local steps = math.max(1, math.floor(duration / 0.016))
    for i = 1, steps do
        local a = i / steps
        local t = a < 0.5 and (4 * a * a * a) or (1 - ((-2 * a + 2) ^ 3) / 2)
        if hrp.Parent then hrp.CFrame = startCF:Lerp(endCF, t) end
        task.wait(0.016)
    end
    if hrp.Parent then hrp.CFrame = endCF end
end

local function fireElevatorTrigger()
    local hrp = root()
    local elev = workspace:FindFirstChild('elevator') or workspace:FindFirstChild('Elevator')
    local trig = elev and (elev:FindFirstChild('trigger') or elev:FindFirstChild('Trigger'))
    if not hrp or not trig then return end
    pcall(function() firetouchinterest(hrp, trig, 0) end)
    task.wait(0.05)
    pcall(function() firetouchinterest(hrp, trig, 1) end)
end

local busy, generatorBusy = false, false
local nightVisionEnabled, nightVisionThread = false, nil
local godModeEnabled, godModeThread = false, nil
local cursorLocked, cursorConn = false, nil
local autoFloorEnabled, autoFloorThread = false, nil
local bacteriumEnabled, bacteriumThread = false, nil
local useNewTeleport = false
local flyEnabled, flyConn, flyVelocity, flyGyro = false, nil, nil, nil
local noclipEnabled, noclipConn = false, nil
local walkSpeedValue, flySpeedValue, healValue, moneyValue = 20, 60, 10, 100
local startFire

local function setCursorLock(locked)
    cursorLocked = locked
    if cursorConn then cursorConn:Disconnect(); cursorConn = nil end
    if not locked then
        cursorConn = RunService.RenderStepped:Connect(function()
            UIS.MouseBehavior = Enum.MouseBehavior.Default
            UIS.MouseIconEnabled = true
        end)
    else
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        UIS.MouseIconEnabled = false
    end
end

local function clearFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    local h = hum()
    if h then h.AutoRotate = true end
end

local function startFly()
    if flyConn then return end
    local hrp, h = root(), hum()
    if not hrp or not h then return end
    h.AutoRotate = false
    flyVelocity = Instance.new('BodyVelocity')
    flyVelocity.MaxForce = Vector3.new(9e8, 9e8, 9e8)
    flyVelocity.P = 9e4
    flyVelocity.Parent = hrp
    flyGyro = Instance.new('BodyGyro')
    flyGyro.MaxTorque = Vector3.new(9e8, 9e8, 9e8)
    flyGyro.P = 9e4
    flyGyro.CFrame = hrp.CFrame
    flyGyro.Parent = hrp
    flyConn = RunService.RenderStepped:Connect(function()
        local currentRoot, currentHum, camera = root(), hum(), workspace.CurrentCamera
        if not flyEnabled or not currentRoot or not currentHum or not camera then clearFly(); return end
        local y = 0
        if UIS:IsKeyDown(Enum.KeyCode.Space) then y += 1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) then y -= 1 end
        flyVelocity.Velocity = (currentHum.MoveDirection * flySpeedValue) + Vector3.new(0, y * flySpeedValue * 0.8, 0)
        flyGyro.CFrame = camera.CFrame
    end)
end

local function stopFly() flyEnabled = false clearFly() end
local function startNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not noclipEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA('BasePart') then obj.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    noclipEnabled = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

local function applyWalkSpeed(value)
    if value ~= nil then walkSpeedValue = math.max(1, math.floor(value + 0.5)) end
    pcall(function() UpdateWalkspeedRemote:FireServer(unpack({ walkSpeedValue })) end)
    local h = hum()
    if h then h.WalkSpeed = walkSpeedValue end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.defer(applyWalkSpeed)
    if flyEnabled then task.delay(0.5, function() clearFly() if flyEnabled then startFly() end end) end
    if noclipEnabled then startNoclip() end
end)

local function scanAndFire(onStatus, onProgress, onDone)
    if busy then return end
    busy = true
    if onStatus then onStatus('Scanning breakers...') end
    local prompts = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA('ProximityPrompt') then
            local objectText = tostring(obj.ObjectText or ''):lower()
            local actionText = tostring(obj.ActionText or ''):lower()
            if string.find(objectText, 'breaker') or string.find(actionText, 'breaker') or string.find(actionText, 'activate') then
                table.insert(prompts, obj)
            end
        end
    end
    local total = #prompts
    if total == 0 then busy = false if onDone then onDone(0, 0) end return end
    if onStatus then onStatus('Found ' .. total .. ' - activating...') end
    local success = 0
    for i, prompt in ipairs(prompts) do
        local ok = pcall(function()
            UltraMechanicUsed:FireServer()
            if fireproximityprompt then
                local old = prompt.MaxActivationDistance
                prompt.MaxActivationDistance = 9e9
                fireproximityprompt(prompt)
                prompt.MaxActivationDistance = old
            end
        end)
        if ok then success += 1 end
        if onProgress then onProgress(i, total) end
        if FIRE_DELAY > 0 then task.wait(FIRE_DELAY) end
    end
    busy = false
    if onDone then onDone(success, total) end
end

local function startNightVision()
    if nightVisionThread then return end
    nightVisionThread = task.spawn(function()
        while nightVisionEnabled do
            pcall(function() AbilityEvents:WaitForChild('NightVisionUsed'):FireServer() end)
            task.wait(10)
        end
        nightVisionThread = nil
    end)
end

local function stopNightVision() nightVisionEnabled = false nightVisionThread = nil end

local function startGodMode()
    if godModeThread then return end
    godModeThread = task.spawn(function()
        while godModeEnabled do
            local h = hum()
            if h and h.Health < h.MaxHealth then
                pcall(function() RS:WaitForChild('TakeDamage'):FireServer(-(h.MaxHealth - h.Health)) end)
            end
            task.wait(0.1)
        end
        godModeThread = nil
    end)
end

local function stopGodMode() godModeEnabled = false godModeThread = nil end

local function findBacteriumPrompts()
    local found = {}
    local floors = workspace:FindFirstChild('Floors')
    local current = floors and floors:FindFirstChild('CurrentFloor')
    local important = current and current:FindFirstChild('Important')
    local folder = important and important:FindFirstChild('Bacterium')
    if not folder then return found end
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA('ProximityPrompt') then table.insert(found, obj) end
    end
    return found
end

local function runBacteriumAvoid(onStatus)
    local hrp = root()
    if not hrp then return end
    local prompts = findBacteriumPrompts()
    if #prompts == 0 then if onStatus then onStatus('[BROKEN] No Bacterium found') end return end
    local origin = hrp.CFrame
    for i, prompt in ipairs(prompts) do
        local part = prompt.Parent
        if part and part:IsA('BasePart') then
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
            if onStatus then onStatus('[BROKEN] Triggered ' .. i .. '/' .. #prompts) end
            task.wait(0.1)
            hrp.CFrame = origin
        end
    end
end

local function startBacterium(onStatus)
    if bacteriumThread then return end
    bacteriumThread = task.spawn(function()
        while bacteriumEnabled do
            local floors = workspace:FindFirstChild('Floors')
            if floors and floors:FindFirstChild('CurrentFloor') then
                runBacteriumAvoid(onStatus)
            elseif onStatus then
                onStatus('[BROKEN] Waiting for floor...')
            end
            task.wait(5)
        end
        bacteriumThread = nil
    end)
end

local function stopBacterium() bacteriumEnabled = false bacteriumThread = nil end

local function startAutoFloor(onStatus)
    if autoFloorThread then return end
    autoFloorThread = task.spawn(function()
        if onStatus then onStatus('Auto floor: starting in 5s...') end
        task.wait(5)
        while autoFloorEnabled do
            local floorsFolder = workspace:FindFirstChild('Floors')
            local hasFloor = floorsFolder and #floorsFolder:GetChildren() > 0
            if hasFloor then
                if onStatus then onStatus('Floor detected - waiting 5s...') end
                task.wait(5)
                if not autoFloorEnabled then break end
                local saved = useNewTeleport
                useNewTeleport = false
                startFire()
                useNewTeleport = saved
                task.wait(0.8)
                while busy do task.wait(0.3) end
                if onStatus then onStatus('Cycle done - waiting 5s...') end
                task.wait(5)
            else
                if onStatus then onStatus('Waiting for floor...') end
                task.wait(1)
            end
        end
        autoFloorThread = nil
    end)
end

local function stopAutoFloor() autoFloorEnabled = false autoFloorThread = nil end

local gui = Instance.new('ScreenGui')
gui.Name = 'MainMenu'
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild('PlayerGui')

local frame = Instance.new('Frame')
frame.Name = 'Main'
frame.Size = UDim2.new(0, 410, 0, 590)
frame.Position = UDim2.new(0.5, -205, 0.5, -295)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Visible = false
frame.Parent = gui
Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 14)
local frameStroke = Instance.new('UIStroke')
frameStroke.Color = C.stroke
frameStroke.Thickness = 1.5
frameStroke.Parent = frame

local titleBar = Instance.new('Frame')
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = C.panel
titleBar.BorderSizePixel = 0
titleBar.Parent = frame
Instance.new('UICorner', titleBar).CornerRadius = UDim.new(0, 14)
local titlePatch = Instance.new('Frame')
titlePatch.Size = UDim2.new(1, 0, 0, 12)
titlePatch.Position = UDim2.new(0, 0, 1, -12)
titlePatch.BackgroundColor3 = C.panel
titlePatch.BorderSizePixel = 0
titlePatch.Parent = titleBar

local titleLabel = Instance.new('TextLabel')
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 14, 0, 4)
titleLabel.Size = UDim2.new(0, 200, 0, 20)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = C.text
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = 'MENU  //  V1.6 (676767)'
titleLabel.Parent = titleBar

local commitLabel = Instance.new('TextLabel')
commitLabel.BackgroundTransparency = 1
commitLabel.Position = UDim2.new(0, 14, 0, 21)
commitLabel.Size = UDim2.new(0, 160, 0, 16)
commitLabel.Font = Enum.Font.Gotham
commitLabel.TextSize = 9
commitLabel.TextColor3 = C.sub
commitLabel.TextXAlignment = Enum.TextXAlignment.Left
commitLabel.Text = 'Commit: ' .. commitHash
commitLabel.Parent = titleBar

local unloadBtn = Instance.new('TextButton')
unloadBtn.Size = UDim2.new(0, 62, 0, 22)
unloadBtn.Position = UDim2.new(1, -100, 0.5, -11)
unloadBtn.BackgroundColor3 = Color3.fromRGB(63, 53, 22)
unloadBtn.BorderSizePixel = 0
unloadBtn.AutoButtonColor = false
unloadBtn.Text = 'UNLOAD'
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 10
unloadBtn.TextColor3 = C.gold
unloadBtn.Parent = titleBar
Instance.new('UICorner', unloadBtn).CornerRadius = UDim.new(0, 7)
local unloadStroke = Instance.new('UIStroke')
unloadStroke.Color = Color3.fromRGB(128, 109, 49)
unloadStroke.Parent = unloadBtn

local closeBtn = Instance.new('TextButton')
closeBtn.Size = UDim2.new(0, 24, 0, 22)
closeBtn.Position = UDim2.new(1, -32, 0.5, -11)
closeBtn.BackgroundColor3 = Color3.fromRGB(63, 28, 31)
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Text = 'X'
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.TextColor3 = C.red
closeBtn.Parent = titleBar
Instance.new('UICorner', closeBtn).CornerRadius = UDim.new(0, 7)

local hintLine = Instance.new('TextLabel')
hintLine.BackgroundTransparency = 1
hintLine.Position = UDim2.new(0, 14, 0, 46)
hintLine.Size = UDim2.new(1, -28, 0, 18)
hintLine.Font = Enum.Font.Gotham
hintLine.TextSize = 10
hintLine.TextColor3 = C.sub
hintLine.TextXAlignment = Enum.TextXAlignment.Left
hintLine.Parent = frame

local tabRow = Instance.new('Frame')
tabRow.Size = UDim2.new(1, -28, 0, 28)
tabRow.Position = UDim2.new(0, 14, 0, 68)
tabRow.BackgroundColor3 = C.panel
tabRow.BorderSizePixel = 0
tabRow.Parent = frame
Instance.new('UICorner', tabRow).CornerRadius = UDim.new(0, 10)

local currentTabLabel = Instance.new('TextLabel')
currentTabLabel.BackgroundTransparency = 1
currentTabLabel.Position = UDim2.new(0, 16, 0, 102)
currentTabLabel.Size = UDim2.new(1, -32, 0, 18)
currentTabLabel.Font = Enum.Font.GothamBold
currentTabLabel.TextSize = 12
currentTabLabel.TextColor3 = C.text
currentTabLabel.TextXAlignment = Enum.TextXAlignment.Left
currentTabLabel.Parent = frame

local function makeTabButton(text, positionScale, widthScale)
    local btn = Instance.new('TextButton')
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(widthScale, -4, 1, -6)
    btn.Position = UDim2.new(positionScale, 2, 0, 3)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.TextColor3 = C.sub
    btn.Text = text
    btn.Parent = tabRow
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local tabMain = makeTabButton('MAIN', 0, 0.2)
local tabAbilities = makeTabButton('ABIL', 0.2, 0.2)
local tabUtilities = makeTabButton('UTIL', 0.4, 0.2)
local tabBinds = makeTabButton('BINDS', 0.6, 0.2)
local tabExperimental = makeTabButton('EXPER', 0.8, 0.2)

local function makePage(visible)
    local page = Instance.new('ScrollingFrame')
    page.Size = UDim2.new(1, -28, 1, -130)
    page.Position = UDim2.new(0, 14, 0, 124)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = C.stroke
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = visible
    page.Parent = frame
    local pad = Instance.new('UIPadding')
    pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = page
    local list = Instance.new('UIListLayout')
    list.Padding = UDim.new(0, 10)
    list.Parent = page
    return page
end

local mainPage = makePage(true)
local abilitiesPage = makePage(false)
local utilitiesPage = makePage(false)
local bindsPage = makePage(false)
local experimentalPage = makePage(false)

local tabs = {
    main = { button = tabMain, page = mainPage, full = 'Main Controls' },
    abilities = { button = tabAbilities, page = abilitiesPage, full = 'Abilities' },
    utilities = { button = tabUtilities, page = utilitiesPage, full = 'Utilities' },
    binds = { button = tabBinds, page = bindsPage, full = 'Keybinds' },
    experimental = { button = tabExperimental, page = experimentalPage, full = 'Experimental' },
}

local function setTab(which)
    for id, info in pairs(tabs) do
        local active = id == which
        info.page.Visible = active
        info.button.TextColor3 = active and C.text or C.sub
        info.button.BackgroundTransparency = active and 0 or 1
        if active then info.button.BackgroundColor3 = C.stroke end
    end
    currentTabLabel.Text = tabs[which].full
end

local function makeCard(parent, title, subtitle, accent)
    local card = Instance.new('Frame')
    card.BackgroundColor3 = C.panel2
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, -4, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent
    Instance.new('UICorner', card).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new('UIStroke')
    stroke.Color = accent or C.stroke
    stroke.Transparency = 0.35
    stroke.Parent = card
    local pad = Instance.new('UIPadding')
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = card
    local list = Instance.new('UIListLayout')
    list.Padding = UDim.new(0, 6)
    list.Parent = card

    local titleLabel2 = Instance.new('TextLabel')
    titleLabel2.BackgroundTransparency = 1
    titleLabel2.Size = UDim2.new(1, 0, 0, 16)
    titleLabel2.Font = Enum.Font.GothamBold
    titleLabel2.TextSize = 12
    titleLabel2.TextColor3 = accent or C.text
    titleLabel2.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel2.Text = title
    titleLabel2.Parent = card

    if subtitle then
        local subtitleLabel = Instance.new('TextLabel')
        subtitleLabel.BackgroundTransparency = 1
        subtitleLabel.Size = UDim2.new(1, 0, 0, 0)
        subtitleLabel.AutomaticSize = Enum.AutomaticSize.Y
        subtitleLabel.Font = Enum.Font.Gotham
        subtitleLabel.TextSize = 9
        subtitleLabel.TextColor3 = C.sub
        subtitleLabel.TextWrapped = true
        subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        subtitleLabel.TextYAlignment = Enum.TextYAlignment.Top
        subtitleLabel.Text = subtitle
        subtitleLabel.Parent = card
    end

    return card
end

local function makeButton(parent, text, bg, height)
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, 0, 0, height or 30)
    button.BackgroundColor3 = bg
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.TextColor3 = C.text
    button.Parent = parent
    Instance.new('UICorner', button).CornerRadius = UDim.new(0, 9)
    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 0.88
    stroke.Parent = button
    return button
end

local function makeStatus(parent, text, color)
    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 14)
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextColor3 = color or C.sub
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = parent
    return label
end

local function makeProgress(parent, color)
    local track = Instance.new('Frame')
    track.Size = UDim2.new(1, 0, 0, 5)
    track.BackgroundColor3 = C.panel
    track.BorderSizePixel = 0
    track.Parent = parent
    Instance.new('UICorner', track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new('Frame')
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = color or C.blue
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new('UICorner', fill).CornerRadius = UDim.new(1, 0)
    return fill
end

local function makeToggleRow(parent, label, activeCol, inactiveCol)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(1, -76, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0, 50, 0, 20)
    btn.Position = UDim2.new(1, -60, 0.5, -10)
    btn.BackgroundColor3 = inactiveCol
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = 'OFF'
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = C.text
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 8)
    return btn, activeCol, inactiveCol
end

local function makeInputRow(parent, label, defaultText, accent)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local box = Instance.new('TextBox')
    box.Size = UDim2.new(0.28, 0, 0, 20)
    box.Position = UDim2.new(1, -84, 0.5, -10)
    box.BackgroundColor3 = C.bg
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Text = tostring(defaultText)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 11
    box.TextColor3 = C.text
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = row
    Instance.new('UICorner', box).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new('UIStroke')
    stroke.Color = accent or C.blue
    stroke.Transparency = 0.25
    stroke.Parent = box
    return box, row
end

local function makeSliderRow(parent, label, minValue, maxValue, initialValue)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.Size = UDim2.new(0.6, 0, 0, 14)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local valueLabel = Instance.new('TextLabel')
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -58, 0, 4)
    valueLabel.Size = UDim2.new(0, 46, 0, 14)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 10
    valueLabel.TextColor3 = C.blue
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    local track = Instance.new('Frame')
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 28)
    track.BackgroundColor3 = C.bg
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new('UICorner', track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new('Frame')
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = C.blue
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new('UICorner', fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new('TextButton')
    knob.AutoButtonColor = false
    knob.Text = ''
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = C.text
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new('UICorner', knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local current = initialValue

    local function clampValue(v)
        return math.clamp(math.floor(v + 0.5), minValue, maxValue)
    end

    local function setValue(v)
        current = clampValue(v)
        local alpha = (current - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(current)
    end

    local function updateFromX(x)
        local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        setValue(minValue + (maxValue - minValue) * alpha)
    end

    knob.MouseButton1Down:Connect(function() dragging = true end)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    setValue(initialValue)
    return {
        row = row,
        set = setValue,
        get = function() return current end,
    }
end

local function makeBadge(parent, text, color)
    local badge = Instance.new('TextLabel')
    badge.AutomaticSize = Enum.AutomaticSize.XY
    badge.BackgroundColor3 = color
    badge.BorderSizePixel = 0
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 8
    badge.TextColor3 = C.bg
    badge.Text = '  ' .. text .. '  '
    badge.Parent = parent
    Instance.new('UICorner', badge).CornerRadius = UDim.new(0, 8)
    return badge
end

local function makeAbilityRow(parent, name, description, buttonText, buttonColor, options)
    local row = Instance.new('Frame')
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.Parent = parent
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 10)
    local pad = Instance.new('UIPadding')
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = row
    local list = Instance.new('UIListLayout')
    list.Padding = UDim.new(0, 5)
    list.Parent = row

    local header = Instance.new('Frame')
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 16)
    header.Parent = row

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(0.62, 0, 1, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextColor3 = C.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = name
    title.Parent = header

    if options and options.badgeText then
        local badgeHost = Instance.new('Frame')
        badgeHost.BackgroundTransparency = 1
        badgeHost.Size = UDim2.new(0.38, 0, 1, 0)
        badgeHost.Position = UDim2.new(0.62, 0, 0, 0)
        badgeHost.Parent = header
        local badgeList = Instance.new('UIListLayout')
        badgeList.FillDirection = Enum.FillDirection.Horizontal
        badgeList.HorizontalAlignment = Enum.HorizontalAlignment.Right
        badgeList.Parent = badgeHost
        makeBadge(badgeHost, options.badgeText, options.badgeColor or C.gold)
    end

    local desc = Instance.new('TextLabel')
    desc.BackgroundTransparency = 1
    desc.Size = UDim2.new(1, 0, 0, 0)
    desc.AutomaticSize = Enum.AutomaticSize.Y
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 9
    desc.TextColor3 = C.sub
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Text = description
    desc.Parent = row

    local btn = makeButton(row, buttonText, buttonColor, options and options.large and 34 or 30)
    if options and options.disabled then
        btn.AutoButtonColor = false
        btn.Active = false
        btn.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
        btn.TextColor3 = Color3.fromRGB(170, 176, 188)
    end
    return btn
end

local breakersCard = makeCard(mainPage, 'Breakers', 'Main run controls and floor status.', C.green)
local breakerStatus = makeStatus(breakersCard, 'Status: ready', C.green)
local floorDisplay = makeStatus(breakersCard, 'Floor: -', C.sub)
local breakerProg = makeProgress(breakersCard, C.green)

local breakerButtons = Instance.new('Frame')
breakerButtons.BackgroundTransparency = 1
breakerButtons.Size = UDim2.new(1, 0, 0, 34)
breakerButtons.Parent = breakersCard

local fireBtn = Instance.new('TextButton')
fireBtn.Size = UDim2.new(0.64, -4, 1, 0)
fireBtn.Position = UDim2.new(0, 0, 0, 0)
fireBtn.BackgroundColor3 = Color3.fromRGB(38, 113, 88)
fireBtn.BorderSizePixel = 0
fireBtn.AutoButtonColor = false
fireBtn.Text = 'ACTIVATE + TP  [' .. keyName(keybinds.breakers) .. ']'
fireBtn.Font = Enum.Font.GothamBold
fireBtn.TextSize = 12
fireBtn.TextColor3 = C.text
fireBtn.Parent = breakerButtons
Instance.new('UICorner', fireBtn).CornerRadius = UDim.new(0, 9)

local activateBtn = Instance.new('TextButton')
activateBtn.Size = UDim2.new(0.36, -4, 1, 0)
activateBtn.Position = UDim2.new(0.64, 4, 0, 0)
activateBtn.BackgroundColor3 = Color3.fromRGB(29, 68, 56)
activateBtn.BorderSizePixel = 0
activateBtn.AutoButtonColor = false
activateBtn.Text = 'ACTIVATE'
activateBtn.Font = Enum.Font.GothamBold
activateBtn.TextSize = 11
activateBtn.TextColor3 = C.text
activateBtn.Parent = breakerButtons
Instance.new('UICorner', activateBtn).CornerRadius = UDim.new(0, 9)

local generatorCard = makeCard(mainPage, 'Generator', 'Activates all the generators on room 19', C.blue)
local genStatus = makeStatus(generatorCard, 'Status: ready  (A to Z)', C.blue)
local genProg = makeProgress(generatorCard, C.blue)
local genBtn = makeButton(generatorCard, 'SOLVE GENERATOR  [' .. keyName(keybinds.generator) .. ']', Color3.fromRGB(42, 71, 135), 32)

local playerCard = makeCard(mainPage, 'Player', 'Player modificators such as god mode', C.gold)
local godToggle, godActive, godInactive = makeToggleRow(playerCard, 'God mode (auto-heal)', Color3.fromRGB(41, 112, 78), Color3.fromRGB(79, 34, 34))
local healInput = makeInputRow(playerCard, 'Heal amount', healValue, C.green)
local healBtn = makeButton(playerCard, 'HEAL PLAYER', Color3.fromRGB(50, 122, 75), 34)
local nvToggle, nvActive, nvInactive = makeToggleRow(playerCard, 'Night vision', Color3.fromRGB(54, 95, 171), Color3.fromRGB(58, 40, 82))
local cursorBtn = makeButton(playerCard, 'CURSOR: UNLOCKED  [' .. keyName(keybinds.cursor) .. ']', Color3.fromRGB(53, 49, 92), 34)
local autoFloorToggle, afActive, afInactive = makeToggleRow(playerCard, 'Auto floor  [' .. keyName(keybinds.autofloor) .. ']', Color3.fromRGB(92, 68, 161), Color3.fromRGB(55, 43, 84))
local autoFloorStatus = makeStatus(playerCard, 'Auto floor: off', Color3.fromRGB(178, 164, 225))

local tokenCard = makeCard(mainPage, 'Tokens', 'Grant yourself any amount of Tokens!.', C.gold)
local moneyInput = makeInputRow(tokenCard, 'Token amount', moneyValue, C.gold)
local moneyBtn = makeButton(tokenCard, 'ADD MONEY', Color3.fromRGB(132, 96, 39), 34)

local abilitiesCard = makeCard(abilitiesPage, 'Abilities', 'Ability triggering, spamming can lead to unexpected results.', C.blue)
local allOrNothingBtn = makeAbilityRow(abilitiesCard, 'All Or Nothing', 'Requires the Badge to gamble', 'USE ALL OR NOTHING', Color3.fromRGB(120, 89, 43), {
    badgeText = 'REQ BADGE',
    badgeColor = C.gold,
    large = true,
})
local haltBtn = makeAbilityRow(abilitiesCard, 'Halt', 'Who controls the past controls the future', 'USE HALT', Color3.fromRGB(58, 113, 171))
local seekerBtn = makeAbilityRow(abilitiesCard, 'Seeker', 'Your basic breaker ESP.', 'USE SEEKER', Color3.fromRGB(47, 128, 120))
local dashBtn = makeAbilityRow(abilitiesCard, 'Dash', 'Currently does not work.', 'USE DASH', Color3.fromRGB(74, 77, 85), {
    badgeText = 'DISABLED',
    badgeColor = C.red,
    disabled = true,
})
local lastBreathBtn = makeAbilityRow(abilitiesCard, 'Last Breath', 'Makes you true Chad and Adam', 'USE LAST BREATH', Color3.fromRGB(146, 82, 86))
local abilitiesStatus = makeStatus(abilitiesCard, 'Abilities: ready', C.sub)

local utilityCard = makeCard(utilitiesPage, 'Utilities', 'Movement tools and server speed controls.', C.green)
local flyToggle, flyActive, flyInactive = makeToggleRow(utilityCard, 'Fly  [' .. keyName(keybinds.fly) .. ']', Color3.fromRGB(49, 132, 123), Color3.fromRGB(47, 62, 79))
local flySlider = makeSliderRow(utilityCard, 'Fly speed', 20, 150, flySpeedValue)
local flyInput = makeInputRow(utilityCard, 'Fly speed input', flySpeedValue, C.blue)
local noclipToggle, noclipActive, noclipInactive = makeToggleRow(utilityCard, 'Noclip', Color3.fromRGB(64, 117, 191), Color3.fromRGB(47, 62, 79))
local speedInput = makeInputRow(utilityCard, 'Server walkspeed', walkSpeedValue, C.green)
local applySpeedBtn = makeButton(utilityCard, 'APPLY WALK SPEED', Color3.fromRGB(48, 123, 87), 34)
local utilityStatus = makeStatus(utilityCard, 'Utilities: ready', C.sub)

local bindCard = makeCard(bindsPage, 'Keybinds', 'Click a value, then press a key. Backspace/Delete clears the fly bind.', C.blue)
local bindDefs = {
    { id = 'menu', label = 'Toggle Menu' },
    { id = 'breakers', label = 'Activate + TP' },
    { id = 'generator', label = 'Solve Generator' },
    { id = 'cursor', label = 'Cursor Lock' },
    { id = 'autofloor', label = 'Auto Floor' },
    { id = 'fly', label = 'Fly Toggle' },
}
local rebindBtns = {}
local rebinding = nil

for _, def in ipairs(bindDefs) do
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.Parent = bindCard
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = def.label
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0, 92, 0, 20)
    btn.Position = UDim2.new(1, -104, 0.5, -10)
    btn.BackgroundColor3 = C.bg
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = keyName(keybinds[def.id])
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = C.text
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new('UIStroke')
    stroke.Color = C.stroke
    stroke.Parent = btn

    rebindBtns[def.id] = btn
    btn.MouseButton1Click:Connect(function()
        if rebinding then return end
        rebinding = def.id
        btn.Text = 'Press key...'
        btn.TextColor3 = C.gold
        btn.BackgroundColor3 = Color3.fromRGB(69, 58, 24)
    end)
end

local bindsNote = makeStatus(bindCard, 'ESC = cancel. Fly can be left as NONE if you do not want a bind.', C.sub)

local experimentalCard = makeCard(experimentalPage, 'Experimental', 'Extra actions that are useful to keep separate from the safer main controls.', C.red)
local teleportPlayersBtn = makeButton(experimentalCard, 'TELEPORT PLAYERS [F.0]', Color3.fromRGB(85, 99, 177), 32)
local playerLoadedBtn = makeButton(experimentalCard, 'FIRE PLAYER LOADED [???]', Color3.fromRGB(72, 123, 110), 32)
local newTpToggle, ntpActive, ntpInactive = makeToggleRow(experimentalCard, 'New teleport system (instant TP)', Color3.fromRGB(67, 118, 198), Color3.fromRGB(49, 58, 86))
local experimentalDesc = makeStatus(experimentalCard, 'OFF = tween slide (stable) | ON = instant snapping', C.sub)
local bacteriumToggle, batActive, batInactive = makeToggleRow(experimentalCard, 'Avoid Bacterium (broken)', Color3.fromRGB(133, 57, 61), Color3.fromRGB(73, 42, 50))
local batStatus = makeStatus(experimentalCard, 'Bacterium: off  (broken - do not rely on this)', C.red)

local function refreshHint()
    hintLine.Text = keyName(keybinds.menu) .. '=menu   ' .. keyName(keybinds.breakers) .. '=breakers   ' .. keyName(keybinds.generator) .. '=generator   ' .. keyName(keybinds.cursor) .. '=cursor   ' .. keyName(keybinds.autofloor) .. '=autofloor   ' .. keyName(keybinds.fly) .. '=fly'
end

local function refreshBoundLabels()
    refreshHint()
    fireBtn.Text = 'ACTIVATE + TP  [' .. keyName(keybinds.breakers) .. ']'
    genBtn.Text = 'SOLVE GENERATOR  [' .. keyName(keybinds.generator) .. ']'
    cursorBtn.Text = cursorLocked and ('CURSOR: LOCKED  [' .. keyName(keybinds.cursor) .. ']') or ('CURSOR: UNLOCKED  [' .. keyName(keybinds.cursor) .. ']')
    local flyLabel = 'Fly  [' .. keyName(keybinds.fly) .. ']'
    if flyToggle and flyToggle.Parent then
        local label = flyToggle.Parent:FindFirstChildWhichIsA('TextLabel')
        if label then label.Text = flyLabel end
    end
    if autoFloorToggle and autoFloorToggle.Parent then
        local label = autoFloorToggle.Parent:FindFirstChildWhichIsA('TextLabel')
        if label then label.Text = 'Auto floor  [' .. keyName(keybinds.autofloor) .. ']' end
    end
    for id, btn in pairs(rebindBtns) do
        if rebinding ~= id then
            btn.Text = keyName(keybinds[id])
            btn.TextColor3 = C.text
            btn.BackgroundColor3 = C.bg
        end
    end
end

refreshHint()
setTab('main')

tabMain.MouseButton1Click:Connect(function() setTab('main') end)
tabAbilities.MouseButton1Click:Connect(function() setTab('abilities') end)
tabUtilities.MouseButton1Click:Connect(function() setTab('utilities') end)
tabBinds.MouseButton1Click:Connect(function() setTab('binds') end)
tabExperimental.MouseButton1Click:Connect(function() setTab('experimental') end)
closeBtn.MouseButton1Click:Connect(function() menuOpen = false frame.Visible = false end)

local function onBreakerProgress(i, total)
    TweenService:Create(breakerProg, TweenInfo.new(FIRE_DELAY * 0.9), { Size = UDim2.new(i / total, 0, 1, 0) }):Play()
    breakerStatus.Text = 'Activating: ' .. i .. ' / ' .. total
    breakerStatus.TextColor3 = C.green
end

local function onBreakerDone(success, total)
    if total == 0 then
        breakerStatus.Text = 'No breakers found'
        breakerStatus.TextColor3 = C.red
    else
        breakerStatus.Text = success .. '/' .. total .. ' activated'
        breakerStatus.TextColor3 = C.green
    end
    task.wait(2)
    TweenService:Create(breakerProg, TweenInfo.new(0.25), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    fireBtn.Text = 'ACTIVATE + TP  [' .. keyName(keybinds.breakers) .. ']'
    activateBtn.Text = 'ACTIVATE'
    fireBtn.BackgroundColor3 = Color3.fromRGB(38, 113, 88)
    activateBtn.BackgroundColor3 = Color3.fromRGB(29, 68, 56)
    breakerStatus.Text = 'Status: ready'
    breakerStatus.TextColor3 = C.green
end

local function runTweenSequence(onScanDone)
    breakerStatus.Text = 'Sliding to position...'
    breakerStatus.TextColor3 = C.blue
    smoothTeleport(0, 5, 5, 0.7)
    task.wait(0.5)

    local floorBefore = floorObj()
    floorBefore = floorBefore and floorBefore.Value or nil

    fireBtn.Text = 'Activating...'
    scanAndFire(function(msg)
        breakerStatus.Text = msg
        breakerStatus.TextColor3 = C.green
    end, onBreakerProgress, function(success, total)
        task.wait(0.5)
        breakerStatus.Text = 'Sliding back...'
        breakerStatus.TextColor3 = C.blue
        smoothTeleport(20, 5, 5, 0.7)
        task.wait(0.15)
        fireElevatorTrigger()
        task.wait(0.2)
        local currentFloor = floorObj()
        if currentFloor and floorBefore ~= nil and currentFloor.Value == floorBefore then
            pcall(function()
                RS:WaitForChild('QuestRemotes'):WaitForChild('Floors'):FireServer()
            end)
        end
        if onScanDone then onScanDone(success, total) end
    end)
end

local function runInstantSequence(onScanDone)
    breakerStatus.Text = '[EXP] Snapping to position...'
    breakerStatus.TextColor3 = C.blue
    teleportTo(10, 5, 5)
    task.wait(0.08)
    teleportTo(0, 5, 5)
    task.wait(0.5)

    local floorBefore = floorObj()
    floorBefore = floorBefore and floorBefore.Value or nil

    fireBtn.Text = '[EXP] Activating...'
    scanAndFire(function(msg)
        breakerStatus.Text = msg
        breakerStatus.TextColor3 = C.green
    end, onBreakerProgress, function(success, total)
        task.wait(0.5)
        breakerStatus.Text = '[EXP] Firing elevator...'
        breakerStatus.TextColor3 = C.sub
        fireElevatorTrigger()
        task.wait(0.2)
        breakerStatus.Text = '[EXP] Snapping back...'
        breakerStatus.TextColor3 = C.blue
        teleportTo(10, 5, 5)
        task.wait(0.08)
        teleportTo(20, 5, 5)
        task.wait(0.2)
        local currentFloor = floorObj()
        if currentFloor and floorBefore ~= nil and currentFloor.Value == floorBefore then
            pcall(function()
                RS:WaitForChild('QuestRemotes'):WaitForChild('Floors'):FireServer()
            end)
        end
        if onScanDone then onScanDone(success, total) end
    end)
end

startFire = function()
    if busy then return end
    fireBtn.BackgroundColor3 = Color3.fromRGB(28, 76, 60)
    fireBtn.Text = 'Running...'
    task.spawn(function()
        if useNewTeleport then runInstantSequence(onBreakerDone) else runTweenSequence(onBreakerDone) end
    end)
end

local function startFireNoTeleport()
    if busy then return end
    activateBtn.BackgroundColor3 = Color3.fromRGB(24, 53, 44)
    activateBtn.Text = 'Running...'
    task.spawn(function()
        scanAndFire(function(msg)
            breakerStatus.Text = msg
            breakerStatus.TextColor3 = C.green
        end, onBreakerProgress, onBreakerDone)
    end)
end

local function runGenerator()
    if generatorBusy then return end
    generatorBusy = true
    genBtn.Text = 'Running...'
    genBtn.BackgroundColor3 = Color3.fromRGB(29, 50, 92)
    task.spawn(function()
        local remote = RS:WaitForChild('Generator_Events'):WaitForChild('GeneratorFixed')
        pcall(function() remote:FireServer('GeneratorStart') end)
        genStatus.Text = 'Fired: GeneratorStart'
        genStatus.TextColor3 = C.blue
        task.wait(0.1)
        for idx = 65, 90 do
            local letter = string.char(idx)
            pcall(function() remote:FireServer(letter) end)
            TweenService:Create(genProg, TweenInfo.new(0.04), { Size = UDim2.new((idx - 64) / 26, 0, 1, 0) }):Play()
            genStatus.Text = 'Firing: ' .. letter .. '  (' .. (idx - 64) .. '/26)'
            task.wait(0.05)
        end
        genStatus.Text = 'Done - GeneratorStart + A to Z sent'
        genStatus.TextColor3 = C.green
        task.wait(2)
        TweenService:Create(genProg, TweenInfo.new(0.25), { Size = UDim2.new(0, 0, 1, 0) }):Play()
        genBtn.Text = 'SOLVE GENERATOR  [' .. keyName(keybinds.generator) .. ']'
        genBtn.BackgroundColor3 = Color3.fromRGB(42, 71, 135)
        genStatus.Text = 'Status: ready  (A to Z)'
        genStatus.TextColor3 = C.blue
        generatorBusy = false
    end)
end

fireBtn.MouseButton1Click:Connect(startFire)
activateBtn.MouseButton1Click:Connect(startFireNoTeleport)
genBtn.MouseButton1Click:Connect(runGenerator)

healInput.FocusLost:Connect(function()
    local v = tonumber(healInput.Text)
    if v then healValue = v else healInput.Text = tostring(healValue) end
end)
moneyInput.FocusLost:Connect(function()
    local v = tonumber(moneyInput.Text)
    if v then moneyValue = v else moneyInput.Text = tostring(moneyValue) end
end)
flyInput.FocusLost:Connect(function()
    local v = tonumber(flyInput.Text)
    if v then
        flySpeedValue = math.clamp(math.floor(v + 0.5), 20, 150)
        flyInput.Text = tostring(flySpeedValue)
        flySlider.set(flySpeedValue)
        utilityStatus.Text = 'Fly speed set to ' .. flySpeedValue
    else
        flyInput.Text = tostring(flySpeedValue)
    end
end)
speedInput.FocusLost:Connect(function()
    local v = tonumber(speedInput.Text)
    if v then walkSpeedValue = math.max(1, math.floor(v + 0.5)) else speedInput.Text = tostring(walkSpeedValue) end
end)

healBtn.MouseButton1Click:Connect(function()
    local v = tonumber(healInput.Text) or healValue
    healValue = v
    pcall(function()
        RS:WaitForChild('TakeDamage'):FireServer(-healValue)
    end)
end)

moneyBtn.MouseButton1Click:Connect(function()
    local v = tonumber(moneyInput.Text) or moneyValue
    moneyValue = v
    pcall(function()
        RS:WaitForChild('QuestRemotes'):WaitForChild('Reward'):FireServer('Tokens', moneyValue)
    end)
end)

allOrNothingBtn.MouseButton1Click:Connect(function()
    abilitiesStatus.Text = 'Abilities: fired All Or Nothing'
    abilitiesStatus.TextColor3 = C.gold
    pcall(function()
        AllOrNothingRemote:FireServer(unpack({ 'useAbility' }))
    end)
end)
haltBtn.MouseButton1Click:Connect(function()
    abilitiesStatus.Text = 'Abilities: fired Halt'
    abilitiesStatus.TextColor3 = C.blue
    pcall(function() AbilityEvents:WaitForChild('HaltUsed'):FireServer() end)
end)
seekerBtn.MouseButton1Click:Connect(function()
    abilitiesStatus.Text = 'Abilities: fired Seeker'
    abilitiesStatus.TextColor3 = C.green
    pcall(function() AbilityEvents:WaitForChild('NightVisionUsed'):FireServer() end)
end)
lastBreathBtn.MouseButton1Click:Connect(function()
    abilitiesStatus.Text = 'Abilities: fired Last Breath'
    abilitiesStatus.TextColor3 = C.red
    pcall(function() AbilityEvents:WaitForChild('LastBreathUsed'):FireServer() end)
end)

godToggle.MouseButton1Click:Connect(function()
    godModeEnabled = not godModeEnabled
    godToggle.Text = godModeEnabled and 'ON' or 'OFF'
    godToggle.BackgroundColor3 = godModeEnabled and godActive or godInactive
    if godModeEnabled then startGodMode() else stopGodMode() end
end)

nvToggle.MouseButton1Click:Connect(function()
    nightVisionEnabled = not nightVisionEnabled
    nvToggle.Text = nightVisionEnabled and 'ON' or 'OFF'
    nvToggle.BackgroundColor3 = nightVisionEnabled and nvActive or nvInactive
    if nightVisionEnabled then startNightVision() else stopNightVision() end
end)

local function toggleCursor()
    setCursorLock(not cursorLocked)
    cursorBtn.Text = cursorLocked and ('CURSOR: LOCKED  [' .. keyName(keybinds.cursor) .. ']') or ('CURSOR: UNLOCKED  [' .. keyName(keybinds.cursor) .. ']')
    cursorBtn.BackgroundColor3 = cursorLocked and Color3.fromRGB(72, 66, 122) or Color3.fromRGB(53, 49, 92)
end
cursorBtn.MouseButton1Click:Connect(toggleCursor)

local function toggleAutoFloor()
    autoFloorEnabled = not autoFloorEnabled
    autoFloorToggle.Text = autoFloorEnabled and 'ON' or 'OFF'
    autoFloorToggle.BackgroundColor3 = autoFloorEnabled and afActive or afInactive
    if autoFloorEnabled then
        autoFloorStatus.Text = 'Auto floor: active'
        startAutoFloor(function(msg) autoFloorStatus.Text = msg end)
    else
        autoFloorStatus.Text = 'Auto floor: off'
        stopAutoFloor()
    end
end
autoFloorToggle.MouseButton1Click:Connect(toggleAutoFloor)

local function toggleFly()
    flyEnabled = not flyEnabled
    flyToggle.Text = flyEnabled and 'ON' or 'OFF'
    flyToggle.BackgroundColor3 = flyEnabled and flyActive or flyInactive
    if flyEnabled then startFly() else stopFly() end
    utilityStatus.Text = flyEnabled and ('Fly enabled @ ' .. flySpeedValue) or 'Fly disabled'
end
flyToggle.MouseButton1Click:Connect(toggleFly)

local function toggleNoclip()
    noclipEnabled = not noclipEnabled
    noclipToggle.Text = noclipEnabled and 'ON' or 'OFF'
    noclipToggle.BackgroundColor3 = noclipEnabled and noclipActive or noclipInactive
    if noclipEnabled then startNoclip() else stopNoclip() end
    utilityStatus.Text = noclipEnabled and 'Noclip enabled' or 'Noclip disabled'
end
noclipToggle.MouseButton1Click:Connect(toggleNoclip)

applySpeedBtn.MouseButton1Click:Connect(function()
    local v = tonumber(speedInput.Text)
    if v then walkSpeedValue = math.max(1, math.floor(v + 0.5)) end
    speedInput.Text = tostring(walkSpeedValue)
    applyWalkSpeed(walkSpeedValue)
    utilityStatus.Text = 'Server walkspeed fired: ' .. walkSpeedValue
    utilityStatus.TextColor3 = C.green
end)

teleportPlayersBtn.MouseButton1Click:Connect(function()
    pcall(function() TeleportPlayersRemote:FireServer() end)
    batStatus.Text = 'Experimental: fired TeleportPlayers'
    batStatus.TextColor3 = C.blue
end)

playerLoadedBtn.MouseButton1Click:Connect(function()
    pcall(function() PlayerLoadedRemote:FireServer() end)
    batStatus.Text = 'Experimental: fired PlayerLoaded'
    batStatus.TextColor3 = C.green
end)

newTpToggle.MouseButton1Click:Connect(function()
    useNewTeleport = not useNewTeleport
    newTpToggle.Text = useNewTeleport and 'ON' or 'OFF'
    newTpToggle.BackgroundColor3 = useNewTeleport and ntpActive or ntpInactive
end)

bacteriumToggle.MouseButton1Click:Connect(function()
    bacteriumEnabled = not bacteriumEnabled
    bacteriumToggle.Text = bacteriumEnabled and 'ON' or 'OFF'
    bacteriumToggle.BackgroundColor3 = bacteriumEnabled and batActive or batInactive
    if bacteriumEnabled then
        batStatus.Text = '[BROKEN] Active - results unreliable'
        batStatus.TextColor3 = C.red
        startBacterium(function(msg)
            batStatus.Text = msg
            batStatus.TextColor3 = C.red
        end)
    else
        batStatus.Text = 'Bacterium: off  (broken - do not rely on this)'
        batStatus.TextColor3 = C.red
        stopBacterium()
    end
end)

task.spawn(function()
    while scriptActive do
        local currentFloor = floorObj()
        floorDisplay.Text = currentFloor and ('Floor: ' .. tostring(currentFloor.Value)) or 'Floor: -'
        if flySlider then
            local sliderValue = flySlider.get()
            if sliderValue ~= flySpeedValue then
                flySpeedValue = sliderValue
                flyInput.Text = tostring(flySpeedValue)
                if flyEnabled then utilityStatus.Text = 'Fly enabled @ ' .. flySpeedValue end
            end
        end
        task.wait(0.1)
    end
end)

UIS.InputBegan:Connect(function(input, processed)
    if not scriptActive then return end

    if rebinding and input.UserInputType == Enum.UserInputType.Keyboard then
        local btn = rebindBtns[rebinding]
        local newKey = input.KeyCode
        if newKey == Enum.KeyCode.Escape then
            if btn then
                btn.Text = keyName(keybinds[rebinding])
                btn.TextColor3 = C.text
                btn.BackgroundColor3 = C.bg
            end
        elseif rebinding == 'fly' and (newKey == Enum.KeyCode.Backspace or newKey == Enum.KeyCode.Delete) then
            keybinds.fly = nil
            if btn then
                btn.Text = 'NONE'
                btn.TextColor3 = C.text
                btn.BackgroundColor3 = C.bg
            end
            refreshBoundLabels()
        else
            keybinds[rebinding] = newKey
            if btn then
                btn.Text = keyName(newKey)
                btn.TextColor3 = C.text
                btn.BackgroundColor3 = C.bg
            end
            refreshBoundLabels()
        end
        rebinding = nil
        return
    end

    if processed then return end
    if input.KeyCode == keybinds.menu then
        menuOpen = not menuOpen
        frame.Visible = menuOpen
    elseif input.KeyCode == keybinds.breakers then
        startFire()
    elseif input.KeyCode == keybinds.generator then
        runGenerator()
    elseif input.KeyCode == keybinds.cursor then
        toggleCursor()
    elseif input.KeyCode == keybinds.autofloor then
        toggleAutoFloor()
    elseif keybinds.fly and input.KeyCode == keybinds.fly then
        toggleFly()
    end
end)

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
    if gui and gui.Parent then gui:Destroy() end
    print('[Menu] V1.6 unloaded - all loops stopped, keybinds dead')
end

unloadBtn.MouseButton1Click:Connect(unload)
refreshBoundLabels()
applyWalkSpeed(walkSpeedValue)

print('[Menu] V1.6 loaded - ' .. keyName(keybinds.menu) .. '=menu  ' .. keyName(keybinds.breakers) .. '=breakers  ' .. keyName(keybinds.generator) .. '=generator  ' .. keyName(keybinds.cursor) .. '=cursor  ' .. keyName(keybinds.autofloor) .. '=autofloor  ' .. keyName(keybinds.fly) .. '=fly')
