-- Obsidian Hub Autofarm with Kill Check (Zenith)
local repo = 'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local player = Players.LocalPlayer

-- Make a window
local Window = Library:CreateWindow({
    Title = 'Zenith Autofarm Hub',
    Footer = 'Obsidian UI',
    Icon = 95816097006870,
    ShowCustomCursor = true,
    NotifySide = 'Right',
})

------------------------------------------------------
-- Main Tab
------------------------------------------------------
local MainTab = Window:AddTab('Main Tab', 'home')
local MainBox = MainTab:AddLeftGroupbox('Player Controls')

-- WalkSpeed slider
MainBox:AddSlider('WalkSpeedSlider', {
    Text = 'Walk Speed',
    Default = 16,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        local char = player.Character
        if char and char:FindFirstChildOfClass('Humanoid') then
            char:FindFirstChildOfClass('Humanoid').WalkSpeed = value
        end
    end,
})

-- JumpPower slider
MainBox:AddSlider('JumpPowerSlider', {
    Text = 'Jump Power',
    Default = 50,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        local char = player.Character
        if char and char:FindFirstChildOfClass('Humanoid') then
            char:FindFirstChildOfClass('Humanoid').UseJumpPower = true
            char:FindFirstChildOfClass('Humanoid').JumpPower = value
        end
    end,
})

-- Label
MainBox:AddLabel('Hello, world!')

------------------------------------------------------
-- AutoFarm Tab
------------------------------------------------------
local AutoFarmTab = Window:AddTab('AutoFarm', 'swords')

local FarmBox = AutoFarmTab:AddLeftGroupbox('AutoFarm Controls')
local FarmExtraBox = AutoFarmTab:AddRightGroupbox('AutoFarm Settings')

local player = game.Players.LocalPlayer
local RunService = game:GetService('RunService')

local selectedEnemies = { Bandit = true, Fatty = true }
local farmingConn, currentTarget

-- Teleport settings
local teleportMode = 'Behind Enemy'
local safeDistance = 10
local heightOffset = 0
local XOffset = 0
local ZOffset = 0

-- New settings
local targetPriority = 'Closest'
local autoRejoin = false
local autoHop = false

FarmExtraBox:AddDropdown('TeleportMode', {
    Values = { 'Behind Enemy', 'In Front', 'On Top', 'Random Offset' },
    Value = 'Behind Enemy',
    Text = 'Teleport Mode',
    Tooltip = 'Choose how your character sticks to the enemy',
    Callback = function(value)
        teleportMode = value
    end,
})

FarmExtraBox:AddSlider('SafeDistance', {
    Text = 'Safe Distance',
    Default = 10,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Tooltip = 'Distance from enemy when farming',
    Callback = function(value)
        safeDistance = value
    end,
})

FarmExtraBox:AddSlider('HeightOffset', {
    Text = 'Height Offset',
    Default = 0,
    Min = -50,
    Max = 50,
    Rounding = 0,
    Tooltip = 'Vertical offset above/below enemy',
    Callback = function(value)
        heightOffset = value
    end,
})

FarmExtraBox:AddSlider('XOffset', {
    Text = 'X Offset',
    Default = 0,
    Min = -25,
    Max = 25,
    Rounding = 0,
    Tooltip = 'Left/Right position offset',
    Callback = function(value)
        XOffset = value
    end,
})

FarmExtraBox:AddSlider('ZOffset', {
    Text = 'Z Offset',
    Default = 0,
    Min = -25,
    Max = 25,
    Rounding = 0,
    Tooltip = 'Forward/Back position offset',
    Callback = function(value)
        ZOffset = value
    end,
})

FarmExtraBox:AddDropdown('TargetPriority', {
    Values = { 'Closest', 'Lowest HP', 'Random' },
    Value = 'Closest',
    Text = 'Target Priority',
    Callback = function(val)
        targetPriority = val
    end,
})

FarmExtraBox:AddToggle('AutoRejoinToggle', {
    Text = 'Auto Rejoin',
    Default = false,
    Callback = function(state)
        autoRejoin = state
    end,
})

FarmExtraBox:AddToggle('AutoHopToggle', {
    Text = 'Auto Server Hop',
    Default = false,
    Callback = function(state)
        autoHop = state
    end,
})

local function getOffset()
    local x = XOffset or 0
    local y = heightOffset or 0
    local z = ZOffset or 0

    if teleportMode == 'Behind Enemy' then
        return CFrame.new(x, y, z - safeDistance)
    elseif teleportMode == 'In Front' then
        return CFrame.new(x, y, z + safeDistance)
    elseif teleportMode == 'On Top' then
        return CFrame.new(x, y + safeDistance, z)
    elseif teleportMode == 'Random Offset' then
        local randX = math.random(-safeDistance, safeDistance)
        local randZ = math.random(-safeDistance, safeDistance)
        return CFrame.new(randX + x, y, randZ + z)
    end

    return CFrame.new(x, y, z)
end

-- Enemy selector
FarmBox:AddDropdown('EnemySelect', {
    Values = { 'Bandit', 'Fatty', 'Boss' },
    Value = 'Fatty',
    Multi = true,
    Text = 'Select Enemies',
    Tooltip = 'Choose which enemies to autofarm',
    Callback = function(values)
        selectedEnemies = values
    end,
})

-- Helper: make player face the target
local function lookAtTarget(char, target)
    local hrp = char:FindFirstChild('HumanoidRootPart')
    local trp = target:FindFirstChild('HumanoidRootPart')
    if hrp and trp then
        local lookVector = (trp.Position - hrp.Position).Unit
        local newCFrame = CFrame.new(hrp.Position, hrp.Position + lookVector)
        hrp.CFrame = newCFrame
    end
end

-- AutoFarm toggle
FarmBox:AddToggle('AutoFarmToggle', {
    Text = 'Enable AutoFarm',
    Default = false,
    Callback = function(state)
        if state then
            farmingConn = RunService.Heartbeat:Connect(function()
                local char = player.Character
                if not char or not char:FindFirstChild('HumanoidRootPart') then
                    return
                end
                local hrp = char.HumanoidRootPart

                local npcFolder = workspace:FindFirstChild('Entities')
                    and workspace.Entities:FindFirstChild('NPC')
                if not npcFolder then
                    return
                end

                -- build candidate list
                local candidates = {}
                for _, npc in pairs(npcFolder:GetChildren()) do
                    local hum, root =
                        npc:FindFirstChild('Humanoid'),
                        npc:FindFirstChild('HumanoidRootPart')
                    if hum and root and hum.Health > 0 then
                        for enemy, selected in pairs(selectedEnemies) do
                            if
                                selected
                                and string.find(npc.Name:lower(), enemy:lower())
                            then
                                table.insert(candidates, npc)
                            end
                        end
                    end
                end

                -- select target by priority
                if #candidates > 0 then
                    if targetPriority == 'Closest' then
                        table.sort(candidates, function(a, b)
                            return (a.HumanoidRootPart.Position - hrp.Position).Magnitude
                                < (b.HumanoidRootPart.Position - hrp.Position).Magnitude
                        end)
                        currentTarget = candidates[1]
                    elseif targetPriority == 'Lowest HP' then
                        table.sort(candidates, function(a, b)
                            return a.Humanoid.Health < b.Humanoid.Health
                        end)
                        currentTarget = candidates[1]
                    elseif targetPriority == 'Random' then
                        currentTarget = candidates[math.random(1, #candidates)]
                    end
                else
                    currentTarget = nil
                end

                if
                    currentTarget
                    and currentTarget:FindFirstChild('HumanoidRootPart')
                then
                    hrp.CFrame = currentTarget.HumanoidRootPart.CFrame
                        * getOffset()
                    lookAtTarget(char, currentTarget)
                end
            end)
        else
            if farmingConn then
                farmingConn:Disconnect()
                farmingConn = nil
            end
            currentTarget = nil
        end
    end,
})

-- auto rejoin / hop
game:GetService('Players').LocalPlayer.OnTeleport:Connect(function(state)
    if autoRejoin and state == Enum.TeleportState.Failed then
        game:GetService('TeleportService'):Teleport(game.PlaceId, player)
    end
end)

spawn(function()
    while true do
        task.wait(300) -- every 5 minutes
        if autoHop then
            game:GetService('TeleportService'):Teleport(game.PlaceId, player)
        end
    end
end)

------------------------------------------------------
-- Auto Attack
------------------------------------------------------
local autoAttack = false
local attackDelay = 0.15

FarmBox:AddToggle('AutoAttackToggle', {
    Text = 'Enable Auto Attack',
    Default = false,
    Callback = function(state)
        autoAttack = state
        if state then
            task.spawn(function()
                while autoAttack do
                    if
                        currentTarget
                        and currentTarget:FindFirstChild('Humanoid')
                        and currentTarget.Humanoid.Health > 0
                    then
                        game:GetService('ReplicatedStorage').RemoteEvents.Player.Combat.CombatRemote
                            :FireServer('M1')
                    end
                    task.wait(attackDelay)
                end
            end)
        end
    end,
})

FarmBox:AddSlider('AttackDelaySlider', {
    Text = 'Attack Delay',
    Default = 0.15,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Callback = function(value)
        attackDelay = value
    end,
})

------------------------------------------------------
-- AutoSkill
------------------------------------------------------
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local AbilitiesRemote =
    ReplicatedStorage.RemoteEvents.Player.Combat:WaitForChild(
        'AbilitiesRemote1'
    )

local autoSkill = false
local autoSkillDelay = 0.15
local selectedSkills = {}

local skillFolder = player:WaitForChild('Skills')
local allSkills = {}
for _, skill in ipairs(skillFolder:GetChildren()) do
    table.insert(allSkills, skill.Name)
end

FarmBox:AddDropdown('SkillSelect', {
    Values = allSkills,
    Value = {},
    Multi = true,
    Text = 'Select Skills',
    Callback = function(values)
        selectedSkills = values or {}
    end,
})

FarmBox:AddSlider('SkillDelaySlider', {
    Text = 'Skill Delay',
    Default = 0.15,
    Min = 0.03,
    Max = 0.5,
    Rounding = 2,
    Callback = function(value)
        autoSkillDelay = value
    end,
})

local function useSkill(skillName)
    if skillName and AbilitiesRemote then
        local args = { skillName }
        AbilitiesRemote:FireServer(unpack(args))
    end
end

FarmBox:AddToggle('AutoSkillToggle', {
    Text = 'Enable AutoSkill',
    Default = false,
    Callback = function(state)
        autoSkill = state
        if state then
            task.spawn(function()
                while autoSkill do
                    if
                        farmingConn
                        and currentTarget
                        and currentTarget:FindFirstChild('Humanoid')
                        and currentTarget.Humanoid.Health > 0
                        and next(selectedSkills) ~= nil
                    then
                        for skillName, isSelected in pairs(selectedSkills) do
                            if isSelected then
                                useSkill(skillName)
                                task.wait(autoSkillDelay)
                            end
                        end
                    else
                        task.wait(0.25)
                    end
                end
            end)
        end
    end,
})

-------------------------------
-- Player Tab
------------------------------------------------------
local PlayerTab = Window:AddTab({
    Name = 'Players',
    Icon = 'users',
    Description = 'Player-related features',
})

local PlayerBox = PlayerTab:AddLeftGroupbox('Player Actions')
-------------------------------------------------
-- UI Dropdown for player selection
-------------------------------------------------


------------------------------------------------------
-- Game-specific Features (Players Tab / AutoBox)
------------------------------------------------------

-- Allowed game (replace with your real PlaceId)
local allowedGameId = 1234567890

if game.PlaceId == allowedGameId then
    ------------------------------
    -- Qi Zone Autofarm
    ------------------------------
    local ZoneRemote =
        ReplicatedStorage.RemoteEvents.Player.Cultivation:WaitForChild(
            'ZoneEvent'
        )

    local qiZones = { 'Statue', 'YSW', 'BloodCC', 'SB', 'FoH' }
    local selectedQiZone = qiZones[1]
    local autoQiEnabled = false
    local currentQiZone = nil

    AutoBox:AddDropdown('QiZoneDropdown', {
        Values = qiZones,
        Value = selectedQiZone,
        Text = 'Select Qi Zone',
        Callback = function(value)
            selectedQiZone = value
            if autoQiEnabled then
                if currentQiZone then
                    ZoneRemote:FireServer(LocalPlayer, currentQiZone, 'Exited')
                end
                ZoneRemote:FireServer(LocalPlayer, value, 'Entered')
                currentQiZone = value
            end
        end,
    })

    AutoBox:AddToggle('AutoQiZoneToggle', {
        Text = 'Enable Auto Qi Zone',
        Default = false,
        Callback = function(state)
            autoQiEnabled = state
            if state then
                if selectedQiZone then
                    ZoneRemote:FireServer(
                        LocalPlayer,
                        selectedQiZone,
                        'Entered'
                    )
                    currentQiZone = selectedQiZone
                end
            else
                if currentQiZone then
                    ZoneRemote:FireServer(LocalPlayer, currentQiZone, 'Exited')
                    currentQiZone = nil
                end
            end
        end,
    })

    ------------------------------
    -- Comprehension Zone Autofarm
    ------------------------------
    local CompRemote =
        ReplicatedStorage.RemoteEvents.Player.Comprehension:WaitForChild(
            'ComprehensionZone'
        )

    local compZones = { 'EL', 'HVP' } -- can add more later
    local selectedCompZone = compZones[1]
    local autoCompEnabled = false
    local currentCompZone = nil

    AutoBox:AddDropdown('CompZoneDropdown', {
        Values = compZones,
        Value = selectedCompZone,
        Text = 'Select Comprehension Zone',
        Callback = function(value)
            selectedCompZone = value
            if autoCompEnabled then
                if currentCompZone then
                    CompRemote:FireServer(
                        LocalPlayer,
                        currentCompZone,
                        'Exited'
                    )
                end
                CompRemote:FireServer(LocalPlayer, value, 'Entered')
                currentCompZone = value
            end
        end,
    })

    AutoBox:AddToggle('AutoCompZoneToggle', {
        Text = 'Enable Auto Comprehension Zone',
        Default = false,
        Callback = function(state)
            autoCompEnabled = state
            if state then
                if selectedCompZone then
                    CompRemote:FireServer(
                        LocalPlayer,
                        selectedCompZone,
                        'Entered'
                    )
                    currentCompZone = selectedCompZone
                end
            else
                if currentCompZone then
                    CompRemote:FireServer(
                        LocalPlayer,
                        currentCompZone,
                        'Exited'
                    )
                    currentCompZone = nil
                end
            end
        end,
    })
end

-- Fling function (Infinite Yield style)
local function flingPlayer(target, duration)
    local char = LocalPlayer.Character
    local targetChar = target.Character
    if not (char and targetChar) then
        return
    end

    local root = char:FindFirstChild('HumanoidRootPart')
    local targetRoot = targetChar:FindFirstChild('HumanoidRootPart')
    if not (root and targetRoot) then
        return
    end

    -- Add BodyThrust to fling
    local bv = Instance.new('BodyThrust')
    bv.Force = Vector3.new(9999, 9999, 9999)
    bv.Parent = root

    local startTime = tick()
    while tick() - startTime < (duration or 0.5) do
        root.CFrame = targetRoot.CFrame
        task.wait()
    end

    bv:Destroy()
end

-- Dropdown
local PlayerDropdown
local function refreshPlayers()
    if not PlayerDropdown then
        return
    end
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    PlayerDropdown:SetValues(names)
end

        print('Selected player:', val)
    end,
})


-- Fling function (Infinite Yield style)
local function flingPlayer(target, duration)
    local char = LocalPlayer.Character
    local targetChar = target.Character
    if not (char and targetChar) then
        return
    end

    local root = char:FindFirstChild('HumanoidRootPart')
    local targetRoot = targetChar:FindFirstChild('HumanoidRootPart')
    if not (root and targetRoot) then
        return
    end

    -- Add BodyThrust to fling
    local bv = Instance.new('BodyThrust')
    bv.Force = Vector3.new(9999, 9999, 9999)
    bv.Parent = root

    local startTime = tick()
    while tick() - startTime < (duration or 0.5) do
        root.CFrame = targetRoot.CFrame
        task.wait()
    end

    bv:Destroy()
end

-- Dropdown
local PlayerDropdown
local function refreshPlayers()
    if not PlayerDropdown then
        return
    end
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    PlayerDropdown:SetValues(names)
end

        print('Selected player:', val)
    end,
})

-- Buttons
PlayerBox:AddButton('TP to Person', function()
    local target = Players:FindFirstChild(PlayerDropdown.Value)
    if
        target
        and target.Character
        and target.Character:FindFirstChild('HumanoidRootPart')
    then
        LocalPlayer.Character:PivotTo(
            target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        )
    end
end)

PlayerBox:AddButton('Fling Selected', function()
    local target = Players:FindFirstChild(PlayerDropdown.Value)
    if target then
        flingPlayer(target, 0.5)
    end
end)

PlayerBox:AddButton('Fling All', function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            flingPlayer(plr, 0.5)
            task.wait(0.5)
        end
    end
end)

-- Toggles
local flingConn
PlayerBox:AddToggle('ContinuousFling', {
    Text = 'Continuous Fling Selected',
    Default = false,
    Callback = function(state)
        if state then
            flingConn = RunService.Heartbeat:Connect(function()
                local target = Players:FindFirstChild(PlayerDropdown.Value)
                if target then
                    flingPlayer(target)
                end
            end)
        else
            if flingConn then flingConn:Disconnect() flingConn = nil end
        end
    end,
})

local tpConn
PlayerBox:AddToggle('ContinuousTP', {
    Text = 'Continuous TP to Selected',
    Default = false,
    Callback = function(state)
        if state then
            tpConn = RunService.Heartbeat:Connect(function()
                local target = Players:FindFirstChild(PlayerDropdown.Value)
                if target and target.Character and target.Character:FindFirstChild('HumanoidRootPart') then
                    LocalPlayer.Character:PivotTo(
                        target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                    )
                end
            end)
        else
            if tpConn then tpConn:Disconnect() tpConn = nil end
        end
    end,
})

-- Refresh when players join/leave
Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)
refreshPlayers()

-- toggle in UI
AutoBox:AddToggle('AntiAFK', {
    Text = 'Anti AFK',
    Default = false,
    Callback = function(state)
        if state then
            print('Anti AFK Enabled')

            AntiAFKConn = game:GetService('Players').LocalPlayer.Idled
                :Connect(function()
                    local vu = game:GetService('VirtualUser')
                    local cam = workspace.CurrentCamera
                    if cam then
                        vu:Button2Down(Vector2.new(0, 0), cam.CFrame)
                        task.wait(0.1)
                        vu:Button2Up(Vector2.new(0, 0), cam.CFrame)
                        print('[Anti AFK] simulated input')
                    end
                end)
        else
            print('Anti AFK Disabled')

            if AntiAFKConn then
                AntiAFKConn:Disconnect()
                AntiAFKConn = nil
            end
        end
    end,
})
-------------------------------------------------


-------------------------------------------------
-- Continuous Fling All Toggle (One Cycle, same as fling selected)
-------------------------------------------------
PlayerBox:AddToggle("ContinuousFlingAll", {
    Text = "Continuous Fling All (One Cycle)",
    Default = false,
    Callback = function(state)
        if state then
            task.spawn(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        flingPlayer(plr) -- ✅ same fling function as Continuous Fling Selected
                        task.wait(0.2)
                    end
                end
                -- turn itself off after finishing
                Toggles.ContinuousFlingAll:SetValue(false)
            end)
        end
    end
})

local player = game.Players.LocalPlayer
local placeId = game.PlaceId

-- Teleport Tab
local TeleportTab = Window:AddTab('Teleports', 'map-pin')
local TeleBox = TeleportTab:AddLeftGroupbox('Qi Zones')
local ComprehensionBox = TeleportTab:AddRightGroupbox('Comprehension Teleports')
local SafeBox = TeleportTab:AddLeftGroupbox('Special Options')

------------------------------------------------------
-- Common tween setup
------------------------------------------------------
local TweenService = game:GetService('TweenService')
local tweenEnabled = false
local tweenSpeed = 400

TeleBox:AddToggle('TweenTeleport', {
    Text = 'Use Tween Teleport',
    Default = false,
    Callback = function(state)
        tweenEnabled = state
    end,
})

TeleBox:AddSlider('TweenSpeed', {
    Text = 'Tween Speed',
    Min = 100,
    Max = 1000,
    Default = 400,
    Rounding = 0,
    Callback = function(value)
        tweenSpeed = value
    end,
})

local function tweenTo(char, targetCFrame)
    if char and char:FindFirstChild('HumanoidRootPart') then
        local hrp = char.HumanoidRootPart
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        local tweenInfo =
            TweenInfo.new(distance / tweenSpeed, Enum.EasingStyle.Linear)
        local tween =
            TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })
        tween:Play()
    end
end

------------------------------------------------------
-- Zone Data
------------------------------------------------------
local earthZones = {
    ['Statue Of The Great One'] = CFrame.new(-4922, 221, -1086),
    ['Yin Sword'] = CFrame.new(-5657, 217, -700),
    ['Blood Crystal Cave'] = CFrame.new(-4419, 203, -204),
    ["Struggler's Blade"] = CFrame.new(-5239, 441, 564),
    ['Fragment Of Heaven'] = CFrame.new(-6254, 154, 589),
}

local earthComprehension = {
    ['Enlightment Library'] = CFrame.new(-3722, 219, -1901),
    ['Heaven Viewing Platform'] = CFrame.new(-4624, 929, -412),
}

local earthSafeSpots = {
    ['Yin Sword'] = CFrame.new(-5630, 187, -764),
    ['Statue Of The Great One'] = CFrame.new(-4944, 205, -1101),
    ['Blood Crystal Cave'] = CFrame.new(-4410, 185, -210),
    ["Struggler's Blade"] = CFrame.new(-5253, 417, 575),
    ['Fragment Of Heaven'] = CFrame.new(-6268, 115, 532),
}

-- Helper: return keys of a dictionary
local function getKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

------------------------------------------------------
-- UI Handling
------------------------------------------------------
local zoneList = {}
local comprehensionList = {}
local safeSpotsList = {}

if placeId == 14483332676 then -- Earth
    zoneList = earthZones
    comprehensionList = earthComprehension
    safeSpotsList = earthSafeSpots
    -- elseif placeId == 123456789 then -- Heaven (later)
    --     zoneList = heavenZones
    --     comprehensionList = heavenComprehension
    --     safeSpotsList = heavenSafeSpots
end

-- Qi Zones Dropdown
local selectedZone = nil
local zoneValues = next(zoneList) and getKeys(zoneList)
    or { 'No Zones Available' }

TeleBox:AddDropdown('QiZones', {
    Values = zoneValues,
    Default = zoneValues[1],
    Text = 'Select Zone',
    Callback = function(value)
        if zoneList[value] then
            selectedZone = value
        end
    end,
})

TeleBox:AddButton('Teleport to Zone', function()
    local char = player.Character
    if char and selectedZone and zoneList[selectedZone] then
        if tweenEnabled then
            tweenTo(char, zoneList[selectedZone])
        else
            char.HumanoidRootPart.CFrame = zoneList[selectedZone]
        end
        Library:Notify('Teleported to ' .. selectedZone)
    end
end)

-- Comprehension Dropdown
local selectedComp = nil
local compValues = next(comprehensionList) and getKeys(comprehensionList)
    or { 'No Spots Available' }

ComprehensionBox:AddDropdown('ComprehensionZones', {
    Values = compValues,
    Default = compValues[1],
    Text = 'Select Spot',
    Callback = function(value)
        if comprehensionList[value] then
            selectedComp = value
        end
    end,
})

ComprehensionBox:AddButton('Teleport', function()
    local char = player.Character
    if char and selectedComp and comprehensionList[selectedComp] then
        if tweenEnabled then
            tweenTo(char, comprehensionList[selectedComp])
        else
            char.HumanoidRootPart.CFrame = comprehensionList[selectedComp]
        end
        Library:Notify('Teleported to ' .. selectedComp)
    end
end)

------------------------------------------------------
-- Freeze on Safe Spot Teleport (FULL SCRIPT)
------------------------------------------------------
local RunService = game:GetService('RunService')
local player = game.Players.LocalPlayer

-- helpers
local function anchorRoot()
    local char = player.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        root.Anchored = true
    end
end

local function unanchorRoot()
    local char = player.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        root.Anchored = false
    end
end

-- freeze loop
local freezeConn
local function startFreeze()
    if freezeConn then
        return
    end
    freezeConn = RunService.Heartbeat:Connect(function()
        if not Toggles.FreezeOnSafeTeleport.Value then
            if freezeConn then
                freezeConn:Disconnect()
                freezeConn = nil
            end
            return
        end
        anchorRoot()
    end)
end

local function stopFreeze()
    if freezeConn then
        freezeConn:Disconnect()
        freezeConn = nil
    end
    unanchorRoot()
end

------------------------------------------------------
-- UI: Dropdown for Safe Spots
------------------------------------------------------
local selectedSafe = nil
local safeValues = next(safeSpotsList) and getKeys(safeSpotsList)
    or { 'No Safe Spots Available' }

SafeBox:AddDropdown('SafeSpots', {
    Values = safeValues,
    Default = safeValues[1],
    Text = 'Safe Spots (Recommended for AFK Farming)',
    Callback = function(value)
        if safeSpotsList[value] then
            selectedSafe = value
        end
    end,
})

------------------------------------------------------
-- Freeze on Safe Spot Teleport (with same logic)
------------------------------------------------------
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local player = Players.LocalPlayer

local freezeOnSafeTP = false
local hbConn_TP, respawnConn_TP

local function freezeCharacter(char)
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        root.Anchored = true
    end
end

local function unfreezeCharacter(char)
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        root.Anchored = false
    end
end

SafeBox:AddToggle('FreezeOnSafeTeleport', {
    Text = 'Freeze on Safe Spot Teleport',
    Default = false,
    Callback = function(state)
        freezeOnSafeTP = state

        -- cleanup old connections
        if hbConn_TP then
            hbConn_TP:Disconnect()
            hbConn_TP = nil
        end
        if respawnConn_TP then
            respawnConn_TP:Disconnect()
            respawnConn_TP = nil
        end

        if state then
            print('✅ Freeze on Safe Spot Teleport enabled')
        else
            -- unfreeze once
            if player.Character then
                unfreezeCharacter(player.Character)
            end
            print('🧊 Freeze on Safe Spot Teleport disabled')
        end
    end,
})

-- Override Teleport to Safe Spot button
SafeBox:AddButton('Teleport to Safe Spot', function()
    local char = player.Character
    if char and selectedSafe and safeSpotsList[selectedSafe] then
        -- teleport
        if tweenEnabled then
            tweenTo(char, safeSpotsList[selectedSafe])
        else
            char.HumanoidRootPart.CFrame = safeSpotsList[selectedSafe]
        end
        Library:Notify('Teleported to ' .. selectedSafe)

        -- if freeze-on-teleport toggle is enabled, start freeze logic
        if freezeOnSafeTP then
            -- freeze instantly
            freezeCharacter(char)

            -- heartbeat spam to keep frozen
            hbConn_TP = RunService.Heartbeat:Connect(function()
                if not freezeOnSafeTP then
                    return
                end
                local c = player.Character
                if c then
                    freezeCharacter(c)
                end
            end)

            -- respawn support
            respawnConn_TP = player.CharacterAdded:Connect(function(c)
                local root = c:WaitForChild('HumanoidRootPart', 10)
                if not root then
                    return
                end
                task.spawn(function()
                    local t0 = tick()
                    while freezeOnSafeTP and tick() - t0 < 1 do
                        if not root.Parent then
                            break
                        end
                        root.Anchored = true
                        task.wait(0.01)
                    end
                end)
            end)

            print('🧊 Frozen at ' .. selectedSafe)
        end
    end
end)

-- PLAYER TELEPORTS
local TelePlayerBox = TeleportTab:AddRightGroupbox('Player Teleport')

-- Get players
local function getPlayerNames()
    local names = {}
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr ~= player then
            table.insert(names, plr.Name)
        end
    end
    return names
end

-- Dropdown for players
local selectedPlayer = nil
TelePlayerBox:AddDropdown('PlayerList', {
    Values = getPlayerNames(),
    Default = '',
    Text = 'Select Player',
    Callback = function(value)
        selectedPlayer = value
    end,
})

-- Refresh Button
TelePlayerBox:AddButton('Refresh Players', function()
    Options.PlayerList:SetValues(getPlayerNames())
    Library:Notify('Player list refreshed')
end)

-- Teleport to Player Button
TelePlayerBox:AddButton('Teleport to Player', function()
    if selectedPlayer then
        local target = game.Players:FindFirstChild(selectedPlayer)
        if
            target
            and target.Character
            and target.Character:FindFirstChild('HumanoidRootPart')
        then
            local char = player.Character
            if char and char:FindFirstChild('HumanoidRootPart') then
                local targetCFrame = target.Character.HumanoidRootPart.CFrame
                    + Vector3.new(2, 0, 0)
                if tweenEnabled then
                    tweenTo(char, targetCFrame)
                else
                    char.HumanoidRootPart.CFrame = targetCFrame
                end
                Library:Notify('Teleported to ' .. selectedPlayer)
            end
        else
            Library:Notify('Target not available')
        end
    else
        Library:Notify('No player selected')
    end
end)

------------------------------------------------------
-- Safe Spots Comprehension (Teleport side UI)
------------------------------------------------------
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- comprehension safe spots (replace with real coords)
local comprehensionSafeSpots = {
    ['Comp Spot 1'] = CFrame.new(100, 50, 100),
    ['Comp Spot 2'] = CFrame.new(200, 60, 200),
}

-- ✅ Earth Realm only
local EARTH_REALM_PLACEID = 14483332676

-- defaults
local selectedCompSafe = nil
local selectedZone = 'EL'
local freezeOnCompTP = false
local comprehensionEnabled = false
local hbConn_Comp, respawnConn_Comp

------------------------------------------------------
-- Always-visible UI (toggles)
------------------------------------------------------
local CompSafeBox = TeleportTab:AddRightGroupbox('Safe Spots Comprehension')

-- Freeze toggle (always visible)
CompSafeBox:AddToggle('FreezeOnCompTeleport', {
    Text = 'Freeze on Comprehension Teleport',
    Default = false,
    Callback = function(state)
        freezeOnCompTP = state

        if hbConn_Comp then
            hbConn_Comp:Disconnect()
            hbConn_Comp = nil
        end
        if respawnConn_Comp then
            respawnConn_Comp:Disconnect()
            respawnConn_Comp = nil
        end

        if state then
            print('✅ Freeze on Comprehension Teleport enabled')
        else
            if player.Character then
                local root = player.Character:FindFirstChild('HumanoidRootPart')
                if root then
                    root.Anchored = false
                end
            end
            print('🧊 Freeze on Comprehension Teleport disabled')
        end
    end,
})

-- Comprehension toggle (always visible)
CompSafeBox:AddToggle('ComprehensionToggle', {
    Text = 'Comprehension',
    Default = false,
    Callback = function(state)
        comprehensionEnabled = state

        if state then
            -- fire "Entered"
            local args = {
                Players:WaitForChild('BER2342632'),
                selectedZone,
                'Entered',
            }
            ReplicatedStorage:WaitForChild('RemoteEvents')
                :WaitForChild('Player')
                :WaitForChild('Comprehension')
                :WaitForChild('ComprehensionZone')
                :FireServer(unpack(args))

            print(
                '📖 Comprehension started at zone: ' .. tostring(selectedZone)
            )
        else
            -- fire "Exited"
            local args = {
                Players:WaitForChild('BER2342632'),
                selectedZone,
                'Exited',
            }
            ReplicatedStorage:WaitForChild('RemoteEvents')
                :WaitForChild('Player')
                :WaitForChild('Comprehension')
                :WaitForChild('ComprehensionZone')
                :FireServer(unpack(args))

            print('📕 Comprehension stopped, back to Qi gain')
        end
    end,
})

------------------------------------------------------
-- Earth Realm Only: Dropdowns + Teleport Button
------------------------------------------------------
if game.PlaceId == EARTH_REALM_PLACEID then
    -- Safe spot selection
    CompSafeBox:AddDropdown('CompSafeSpots', {
        Values = { 'Comp Spot 1', 'Comp Spot 2' },
        Default = 'Comp Spot 1',
        Text = 'Comprehension Safe Spots',
        Callback = function(value)
            if comprehensionSafeSpots[value] then
                selectedCompSafe = value
            end
        end,
    })

    -- Zone selection
    CompSafeBox:AddDropdown('CompZones', {
        Values = { 'EL', 'HVP' },
        Default = 'EL',
        Text = 'Select Comprehension Zone',
        Callback = function(value)
            selectedZone = value
            print(
                '📌 Selected comprehension zone: ' .. tostring(selectedZone)
            )
        end,
    })

    -- Teleport button
    CompSafeBox:AddButton('Teleport to Comprehension Spot', function()
        local char = player.Character
        if
            char
            and selectedCompSafe
            and comprehensionSafeSpots[selectedCompSafe]
        then
            -- teleport
            if tweenEnabled then
                tweenTo(char, comprehensionSafeSpots[selectedCompSafe])
            else
                char.HumanoidRootPart.CFrame =
                    comprehensionSafeSpots[selectedCompSafe]
            end
            Library:Notify('Teleported to ' .. selectedCompSafe)

            -- freeze logic
            if freezeOnCompTP then
                local function freezeCharacter(c)
                    local root = c and c:FindFirstChild('HumanoidRootPart')
                    if root then
                        root.Anchored = true
                    end
                end
                freezeCharacter(char)

                hbConn_Comp = RunService.Heartbeat:Connect(function()
                    if not freezeOnCompTP then
                        return
                    end
                    local c = player.Character
                    if c then
                        freezeCharacter(c)
                    end
                end)

                respawnConn_Comp = player.CharacterAdded:Connect(function(c)
                    local root = c:WaitForChild('HumanoidRootPart', 10)
                    if not root then
                        return
                    end
                    task.spawn(function()
                        local t0 = tick()
                        while freezeOnCompTP and tick() - t0 < 1 do
                            if not root.Parent then
                                break
                            end
                            root.Anchored = true
                            task.wait(0.01)
                        end
                    end)
                end)

                print('🧊 Frozen at ' .. selectedCompSafe)
            end
        end
    end)
end

-- Custom Teleport Section
local CustomBox = TeleportTab:AddRightGroupbox('Custom Teleport')

local customX, customY, customZ = 0, 5, 0

CustomBox:AddSlider('CustomX', {
    Text = 'X Coord',
    Min = -10000,
    Max = 10000,
    Default = 0,
    Rounding = 0,
    Callback = function(val)
        customX = val
    end,
})

CustomBox:AddSlider('CustomY', {
    Text = 'Y Coord',
    Min = -10000,
    Max = 10000,
    Default = 5,
    Rounding = 0,
    Callback = function(val)
        customY = val
    end,
})

CustomBox:AddSlider('CustomZ', {
    Text = 'Z Coord',
    Min = -10000,
    Max = 10000,
    Default = 0,
    Rounding = 0,
    Callback = function(val)
        customZ = val
    end,
})

CustomBox:AddButton('Teleport to Custom Coords', function()
    local char = player.Character
    if char and char:FindFirstChild('HumanoidRootPart') then
        local targetCFrame = CFrame.new(customX, customY, customZ)
        if useTweenTP then
            tweenTo(char, targetCFrame) -- smooth teleport
        else
            char.HumanoidRootPart.CFrame = targetCFrame -- instant teleport
        end
        Library:Notify('Teleported to Custom Coords!')
    end
end)
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local player = Players.LocalPlayer

-- Registry: maps items to their Remote + Args
local autoUseRegistry = {
    ['Spirit Fruit'] = {
        Remote = ReplicatedStorage.RemoteEvents.Player.Cultivation.ItemBoost,
        Args = function()
            return { Instance.new('Tool', nil) }
        end,
    },
    ['Spirit Dew'] = {
        Remote = ReplicatedStorage.RemoteEvents.Player.Cultivation.ItemBoost,
        Args = function()
            return { Instance.new('Tool', nil) }
        end,
    },
    ['Peach'] = {
        Remote = ReplicatedStorage.RemoteEvents.Player.Cultivation.BodyTempToolRemote,
        Args = function()
            return { 'Peach', Instance.new('Tool', nil) }
        end,
    },
}

local InventoryTab = Window:AddTab('Inventory', 'box')
local InvBox = InventoryTab:AddLeftGroupbox('Player Inventory')

-- Store items + selected item
local items = {}
local selectedItem = nil

-- Dropdown
local InvDropdown = InvBox:AddDropdown('InvDropdown', {
    Values = { '---' },
    Default = '---',
    Text = 'Select Item',
    Callback = function(value)
        selectedItem = value
    end,
})

-- Refresh backpack items
local function refreshInventory()
    items = {}
    local backpack = player:FindFirstChild('Backpack')
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA('Tool') then
                table.insert(items, tool.Name)
            end
        end
    end

    if #items == 0 then
        InvDropdown:SetValues({ '---' })
        InvDropdown:SetValue('---')
        selectedItem = nil
    else
        InvDropdown:SetValues(items)
        InvDropdown:SetValue(items[1])
        selectedItem = items[1]
    end
end

-- Refresh button
InvBox:AddButton('Refresh Inventory', function()
    refreshInventory()
    Library:Notify('Inventory refreshed!')
end)

-- Equip button (manual equip)
InvBox:AddButton('Equip Item', function()
    if selectedItem then
        local tool = player.Backpack:FindFirstChild(selectedItem)
        if tool then
            tool.Parent = player.Character
            Library:Notify('Equipped ' .. selectedItem)
        else
            Library:Notify(selectedItem .. ' not found in backpack!')
        end
    else
        Library:Notify('No item selected!')
    end
end)

-- Drop/Deposit item (simulate backspace)
InvBox:AddButton('Drop/Deposit Item', function()
    if selectedItem then
        local tool = player.Backpack:FindFirstChild(selectedItem)
        if tool then
            tool.Parent = player.Character
            task.wait(0.2)

            game:GetService('VirtualInputManager')
                :SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
            task.wait(0.1)
            game:GetService('VirtualInputManager')
                :SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)

            Library:Notify('Dropped ' .. selectedItem)
            refreshInventory()
        end
    else
        Library:Notify('No item selected!')
    end
end)

-- Sliders
local equipDelay = 0.1

InvBox:AddSlider('EquipDelay', {
    Text = 'Auto Equip Speed (s)',
    Default = 0.1,
    Min = 0.005,
    Max = 0.25,
    Rounding = 3,
    Callback = function(value)
        equipDelay = value
    end,
})

-- Toggles
local continuousEquip = false
local continuousUse = false

InvBox:AddToggle('ContinuousEquip', {
    Text = 'Continuous Equip',
    Default = false,
    Callback = function(state)
        continuousEquip = state
        if state then
            Library:Notify(
                'Continuous Equip enabled for ' .. (selectedItem or '???')
            )
            task.spawn(function()
                while continuousEquip do
                    task.wait(equipDelay)
                    if selectedItem then
                        local tool =
                            player.Backpack:FindFirstChild(selectedItem)
                        if tool then
                            tool.Parent = player.Character
                        end
                    end
                end
            end)
        else
            Library:Notify('Continuous Equip disabled')
        end
    end,
})
-- (use the InventoryTab you already created earlier)
-- Don't create another tab!

-- Left Side: (your current Player Inventory groupbox)
-- local InvBox = InventoryTab:AddLeftGroupbox('Player Inventory')

-- Right Side: Game UI Inventory
local GameInvBox = InventoryTab:AddRightGroupbox('Game UI Inventory')

-- Dropdown for game inventory
local GameInvDropdown = GameInvBox:AddDropdown('GameInvDropdown', {
    Values = {}, -- will populate later
    Default = '',
    Text = 'Select UI Item',
    Callback = function(value)
        selectedGameItem = value
    end,
})

-- Function to fetch items from Players.LocalPlayer.Inventory
local function getUIInventory()
    local items = {}
    local inv = player:FindFirstChild('Inventory')
    if inv then
        for _, item in ipairs(inv:GetChildren()) do
            table.insert(items, item.Name)
        end
    end
    return items
end

-- Refresh button
GameInvBox:AddButton('Refresh UI Inventory', function()
    GameInvDropdown:SetValues(getUIInventory())
    Library:Notify('UI Inventory refreshed!')
end)

-- Auto-update when inventory changes
local invFolder = player:WaitForChild('Inventory')

invFolder.ChildAdded:Connect(function()
    GameInvDropdown:SetValues(getUIInventory())
end)

invFolder.ChildRemoved:Connect(function()
    GameInvDropdown:SetValues(getUIInventory())
end)

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local InventoryRemote =
    ReplicatedStorage.RemoteEvents.Player.Inventory.InventoryRemote

local autoTakeOut = false

-- Function to take out selected item
local function takeOutItem(itemName)
    local inv = player:FindFirstChild('Inventory')
    if inv then
        local item = inv:FindFirstChild(itemName)
        if item and item:IsA('ValueBase') then
            local quantity = tostring(item.Value)
            InventoryRemote:FireServer(itemName, quantity, 'Clicked')
        end
    end
end

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local InventoryRemote =
    ReplicatedStorage.RemoteEvents.Player.Inventory.InventoryRemote

local autoTakeOut = false
local takeOutDelay = 0.01 -- default speed

-- Function to take out selected item
local function takeOutItem(itemName)
    local inv = player:FindFirstChild('Inventory')
    if inv then
        local item = inv:FindFirstChild(itemName)
        if item and item:IsA('ValueBase') then
            local quantity = tostring(item.Value)
            InventoryRemote:FireServer(itemName, quantity, 'Clicked')
        end
    end
end

-- Toggle
GameInvBox:AddToggle('AutoTakeOut', {
    Text = 'Auto Take Out',
    Default = false,
    Callback = function(state)
        autoTakeOut = state
        if state then
            task.spawn(function()
                while autoTakeOut do
                    if selectedGameItem then
                        takeOutItem(selectedGameItem)
                    end
                    task.wait(takeOutDelay) -- uses slider value
                end
            end)
        end
    end,
})

-- Slider
GameInvBox:AddSlider('TakeOutSpeed', {
    Text = 'Take Out Speed',
    Default = 0.01,
    Min = 0.01,
    Max = 0.025,
    Rounding = 3,
    Compact = false,
    Callback = function(value)
        takeOutDelay = value
    end,
})

local autoUse = false
local useDelay = 1 -- delay between re-equips

GameInvBox:AddToggle('AutoUse', {
    Text = 'Auto Use',
    Default = false,
    Callback = function(state)
        autoUse = state
        if state then
            Library:Notify(
                'Auto Use enabled for ' .. (selectedGameItem or '???')
            )
            task.spawn(function()
                while autoUse do
                    task.wait(useDelay)
                    if selectedGameItem then
                        local tool =
                            player.Backpack:FindFirstChild(selectedGameItem)
                        if tool then
                            tool.Parent = player.Character
                        end
                    end
                end
            end)
        else
            Library:Notify('Auto Use disabled')
        end
    end,
})

GameInvBox:AddSlider('UseSpeed', {
    Text = 'Use Speed',
    Default = 1,
    Min = 0.1,
    Max = 3,
    Rounding = 2,
    Callback = function(value)
        useDelay = value
    end,
})

-- Load the LinoriaLib UI
local Library = loadstring(
    game:HttpGet(
        'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua'
    )
)()

-- Create the main window
local ItemTab = Window:AddTab('Items', 'package')

-- Left group: Inventory Collection
local CollectGroup = ItemTab:AddLeftGroupbox('Inventory Collection')
local player = game.Players.LocalPlayer

-- Toggle: Collect All Items (super fast TP every 0.01s)
------------------------------------------------------

-- Collect All Items with TP + ClickDetector search
------------------------------------------------------
local collectAllItemsConnection
local lastTP = 0

CollectGroup:AddToggle('CollectAllItems', {
    Text = 'Collect All Items',
    Default = false,
    Callback = function(State)
        if State then
            Library:Notify('Collect All Items Enabled')

            collectAllItemsConnection = game:GetService('RunService').Heartbeat
                :Connect(function()
                    local now = os.clock()
                    if now - lastTP < 0.01 then
                        return
                    end -- 🔥 TP every 0.01s
                    lastTP = now

                    local player = game.Players.LocalPlayer
                    local char = player.Character
                        or player.CharacterAdded:Wait()
                    local hrp = char:FindFirstChild('HumanoidRootPart')
                    if not hrp then
                        return
                    end

                    for _, model in
                        pairs(workspace.SpawnedMaterials:GetChildren())
                    do
                        if not collectAllItemsConnection then
                            return
                        end -- instantly stop if disabled
                        if model:IsA('Model') then
                            local part = model.PrimaryPart
                                or model:FindFirstChildWhichIsA('BasePart')
                            if part then
                                print('Teleporting & Collecting:', model.Name)
                                hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)

                                -- 🔎 Look through all descendants for ClickDetectors
                                for _, desc in ipairs(model:GetDescendants()) do
                                    if desc:IsA('ClickDetector') then
                                        fireclickdetector(desc)
                                        print('Clicked:', model.Name)
                                    end
                                end
                            end
                        end
                    end
                end)
        else
            Library:Notify('Collect All Items Disabled')
            if collectAllItemsConnection then
                collectAllItemsConnection:Disconnect()
                collectAllItemsConnection = nil
            end
        end
    end,
})

------------------------------------------------------
-- Multi Dropdown: Specific Items
------------------------------------------------------
local selectedItems = {}

CollectGroup:AddDropdown('SpecificItemsDropdown', {
    Values = { 'Sword', 'Meat', 'Scroll', 'Crystal' }, -- placeholder
    Default = {},
    Multi = true,
    Text = 'Select Items to Collect',
    Callback = function(Values)
        selectedItems = {}
        for Value, Selected in pairs(Values) do
            if Selected then
                table.insert(selectedItems, Value)
            end
        end
        Library:Notify(
            'Now set to collect: '
                .. (
                    #selectedItems > 0 and table.concat(selectedItems, ', ')
                    or 'None'
                )
        )
    end,
})

------------------------------------------------------
-- Toggle: Auto Collect Selected Items
------------------------------------------------------
CollectGroup:AddToggle('AutoCollectSelectedItems', {
    Text = 'Auto Collect Selected Items',
    Default = false,
    Callback = function(State)
        if State then
            hrp = getHRP()
            Library:Notify('Auto Collect Selected Items Enabled')

            collectSelectedConn = workspace.SpawnedMaterials.ChildAdded:Connect(
                function(model)
                    task.wait(0.1)
                    if
                        model:IsA('Model')
                        and table.find(selectedItems, model.Name)
                    then
                        local part = model.PrimaryPart
                            or model:FindFirstChildWhichIsA('BasePart')
                        if part then
                            print('TP to selected:', model.Name)
                            hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            )
        else
            Library:Notify('Auto Collect Selected Items Disabled')
            if collectSelectedConn then
                collectSelectedConn:Disconnect()
                collectSelectedConn = nil
            end
        end
    end,
})

-- Right group: Chest Collection
local ChestGroup = ItemTab:AddRightGroupbox('Chest Collection')
local autoCollectChests = false
ChestGroup:AddToggle('AutoCollectChests', {
    Text = 'Auto Collect Chests',
    Default = false,
    Callback = function(State)
        autoCollectChests = State
        Library:Notify(
            'Auto Collect Chests ' .. (State and 'Enabled' or 'Disabled')
        )
        if State then
            task.spawn(function()
                while autoCollectChests do
                    task.wait(0.01)
                    local char = player.Character
                        or player.CharacterAdded:Wait()
                    local hrp = char:FindFirstChild('HumanoidRootPart')
                        or continue
                    for _, chest in
                        ipairs(workspace.SpawnedChests:GetChildren())
                    do
                        local click =
                            chest:FindFirstChildOfClass('ClickDetector')
                        if click and chest:FindFirstChild('ChestScript') then
                            if chest:IsA('BasePart') then
                                hrp.CFrame = chest.CFrame + Vector3.new(0, 3, 0)
                            end
                            fireclickdetector(click)
                            task.wait(0.2)
                        end
                    end
                end
            end)
        end
    end,
})

-- ✅ Add Exploits tab
local ExploitsTab = Window:AddTab('Exploits', 'zap') -- ⚡ icon

------------------------------------------------------
-- Groupbox: Auto Spin Physique (Left)
------------------------------------------------------
------------------------------------------------------
-- ✅ Auto Spin Physique + Talent (Left)
------------------------------------------------------
local player = game.Players.LocalPlayer

------------------------------------------------------
-- Physique
------------------------------------------------------
local autoSpin = false
local spinDelayPhysique = 0.3 -- default

local PhysiqueGroup = ExploitsTab:AddLeftGroupbox('Auto Spin Physique')

-- Dropdown: Physiques to keep
PhysiqueGroup:AddDropdown('PhysiqueKeepList', {
    Values = {
        'Mortal Low',
        'Mortal Mid',
        'Mortal High',
        'Mortal Peak',
        'Spirit Low',
        'Spirit Mid',
        'Spirit High',
        'Spirit Peak',
        'Sacred Low',
        'Sacred Mid',
        'Sacred High',
        'Sacred Peak',
        'Origin Low',
        'Origin Mid',
        'Origin High',
        'Origin Peak',
    },
    Default = {},
    Multi = true,
    Text = 'Physiques to Keep',
    Callback = function(values)
        print('Keeping physiques:', values)
    end,
})

-- Slider: Spin speed (Physique)
PhysiqueGroup:AddSlider('PhysiqueSpinDelay', {
    Text = 'Spin Speed (Physique)',
    Default = 0.3,
    Min = 0.01,
    Max = 0.5,
    Rounding = 2,
    Callback = function(value)
        spinDelayPhysique = value
        Library:Notify('Physique spin delay set to ' .. value .. 's')
    end,
})

-- Toggle: Auto Spin Physique
PhysiqueGroup:AddToggle('AutoSpinToggle', {
    Text = 'Auto Spin Physique',
    Default = false,
    Callback = function(state)
        autoSpin = state
        if state then
            Library:Notify('Auto Spin Physique Enabled')
            task.spawn(function()
                while autoSpin do
                    task.wait(spinDelayPhysique)

                    local current = player.PlrStats.Physique.Value
                    local keepList = Options.PhysiqueKeepList.Value

                    if not keepList[current] then
                        game.ReplicatedStorage.RemoteEvents.Player.Stats.PhysiqueRemote:FireServer(
                            'Spin'
                        )
                        print('Spinning Physique... Current:', current)
                    else
                        Library:Notify('✅ Got physique: ' .. current)
                        autoSpin = false
                        Toggles.AutoSpinToggle:SetValue(false)
                        break
                    end
                end
            end)
        else
            Library:Notify('Auto Spin Physique Disabled')
        end
    end,
})

------------------------------------------------------
-- Talent (directly under Physique)
------------------------------------------------------
local AutoTalent = false
local minTalent = 20
local spinDelayTalent = 0.3

-- Slider: Talent minimum
PhysiqueGroup:AddSlider('TalentKeep', {
    Text = 'Keep Talent ≥',
    Default = 20,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(value)
        minTalent = value
        Library:Notify('Talent keep set to ' .. value .. '+')
    end,
})

-- Slider: Spin speed (Talent)
PhysiqueGroup:AddSlider('TalentSpinDelay', {
    Text = 'Spin Speed (Talent)',
    Default = 0.3,
    Min = 0.01,
    Max = 0.5,
    Rounding = 2,
    Callback = function(value)
        spinDelayTalent = value
        Library:Notify('Talent spin delay set to ' .. value .. 's')
    end,
})

-- Toggle: Auto Spin Talent
PhysiqueGroup:AddToggle('AutoTalentToggle', {
    Text = 'Auto Spin Talent',
    Default = false,
    Callback = function(state)
        AutoTalent = state
        if state then
            Library:Notify('Auto Spin Talent Enabled')
            task.spawn(function()
                while AutoTalent do
                    task.wait(spinDelayTalent)

                    local currentTalent = player.PlrStats.Talent.Value
                    if currentTalent < minTalent then
                        game.ReplicatedStorage.RemoteEvents.Player.Stats.TalentRemote:FireServer(
                            'Spin'
                        )
                        print('Spinning Talent... Current:', currentTalent)
                    else
                        Library:Notify('🎉 Got Talent ' .. currentTalent)
                        AutoTalent = false
                        Toggles.AutoTalentToggle:SetValue(false)
                        break
                    end
                end
            end)
        else
            Library:Notify('Auto Spin Talent Disabled')
        end
    end,
})

------------------------------------------------------
-- Groupbox: Cultivation Exploits (Right)
------------------------------------------------------
local CultivationGroup = ExploitsTab:AddRightGroupbox('Cultivation Exploits')

------------------------------------------------------
-- ✅ Auto Breakthrough (now inside right groupbox)
------------------------------------------------------
------------------------------------------------------
-- ✅ Auto Breakthrough + Auto Resume Meditation
------------------------------------------------------
local AutoBreakthrough = false
local stats = player:WaitForChild('PlrStats')

CultivationGroup:AddToggle('AutoBreakthrough', {
    Text = 'Auto Breakthrough',
    Default = false,
    Callback = function(State)
        AutoBreakthrough = State
        if State then
            Library:Notify('Auto Breakthrough Enabled')

            task.spawn(function()
                while AutoBreakthrough do
                    task.wait(1) -- check every 1s

                    local qiCurrent = stats:WaitForChild('QiCurrent').Value
                    local requirement = stats:WaitForChild('Requirement').Value

                    if qiCurrent >= requirement then
                        -- Trigger breakthrough
                        game.ReplicatedStorage.RemoteEvents.Player.Cultivation.BreakthroughRemote:FireServer(
                            'Breakthrough'
                        )
                        Library:Notify('⚡ Breakthrough triggered!')

                        -- Wait for stats to update after breakthrough
                        task.wait(5)

                        -- Check again, if can't breakthrough → resume meditation
                        local newQi = stats:WaitForChild('QiCurrent').Value
                        local newReq = stats:WaitForChild('Requirement').Value
                        if newQi < newReq then
                            game.ReplicatedStorage.RemoteEvents.Player.Cultivation.CultivationRemote:FireServer(
                                'Meditate'
                            )
                            Library:Notify(
                                '🧘 Resumed Meditation after breakthrough'
                            )
                        end
                    end
                end
            end)
        else
            Library:Notify('Auto Breakthrough Disabled')
        end
    end,
})

-------------------------------------------------
-- Qi Progress + ETA (under CultivationGroup)
------------------------------------------------------
local qiCurrent = stats:WaitForChild('QiCurrent')
local requirement = stats:WaitForChild('Requirement')

local lastQi = qiCurrent.Value
local gainPerSecond = 0

-- Add label inside the right group
local qiLabel =
    CultivationGroup:AddLabel('⚡ Qi until breakthrough: calculating...')

task.spawn(function()
    while task.wait(1) do
        -- Calculate how much Qi is left
        local current = qiCurrent.Value
        local req = requirement.Value
        local remaining = math.max(req - current, 0)

        -- Calculate gain rate
        local gained = current - lastQi
        lastQi = current
        if gained > 0 then
            gainPerSecond = gained
        end

        -- Estimate time
        local etaText = '∞'
        if gainPerSecond > 0 then
            local secondsLeft = math.floor(remaining / gainPerSecond)
            local minutes = math.floor(secondsLeft / 60)
            local seconds = secondsLeft % 60
            etaText = string.format('%02dm %02ds', minutes, seconds)
        end

        -- Update label
        qiLabel:SetText(
            string.format('⚡ Qi needed: %s | ETA: %s', remaining, etaText)
        )
    end
end)

------------------------------------------------------
-- ✅ Auto Pushup (inside Cultivation Exploits)
------------------------------------------------------
local AutoPushup = false
local autoPushupConnection

CultivationGroup:AddToggle('AutoPushup', {
    Text = 'Auto Pushup',
    Default = false,
    Callback = function(state)
        AutoPushup = state
        if state then
            Library:Notify('💪 Auto Pushup Enabled')

            if autoPushupConnection then
                autoPushupConnection:Disconnect()
                autoPushupConnection = nil
            end

            autoPushupConnection = game:GetService('RunService').Heartbeat
                :Connect(function()
                    if AutoPushup then
                        local player = game:GetService('Players').LocalPlayer
                        if
                            player.Character
                            and player.Character:FindFirstChild('Pushups')
                        then
                            local args = {
                                [1] = 'PushUp',
                                [2] = player.Character.Pushups,
                            }
                            game:GetService('ReplicatedStorage').RemoteEvents.Player.Cultivation.BodyTemperingRemote
                                :FireServer(unpack(args))
                        end
                    end
                end)
        else
            Library:Notify('❌ Auto Pushup Disabled')
            if autoPushupConnection then
                autoPushupConnection:Disconnect()
                autoPushupConnection = nil
            end
        end
    end,
})

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local ZoneRemote = ReplicatedStorage:WaitForChild('RemoteEvents')
    :WaitForChild('Player')
    :WaitForChild('Cultivation')
    :WaitForChild('ZoneEvent')

local qiZones = { 'FoH', 'YSW', 'Statue', 'SB', 'BloodCC' }
local selectedQiZone = 'FoH'
local currentZone = nil
local zoneEnabled = false

-- Dropdown to select Qi Zone
AutoBox:AddDropdown('QiZoneDropdown', {
    Values = qiZones,
    Value = selectedQiZone,
    Text = 'Select Qi Zone',
    Callback = function(value)
        local oldZone = selectedQiZone
        selectedQiZone = value

        if zoneEnabled then
            -- Exit old zone if different
            if oldZone and oldZone ~= selectedQiZone then
                ZoneRemote:FireServer(LocalPlayer, oldZone, 'Exited')
            end
            -- Enter new zone
            ZoneRemote:FireServer(LocalPlayer, selectedQiZone, 'Entered')
            currentZone = selectedQiZone
        end
    end,
})

-- Toggle to enable/disable auto zone
AutoBox:AddToggle('EnableQiZone', {
    Text = 'Enable Auto Qi Zone',
    Default = false,
    Callback = function(state)
        zoneEnabled = state
        if state then
            -- Enter selected zone
            ZoneRemote:FireServer(LocalPlayer, selectedQiZone, 'Entered')
            currentZone = selectedQiZone
        else
            -- Exit current zone if active
            if currentZone then
                ZoneRemote:FireServer(LocalPlayer, currentZone, 'Exited')
                currentZone = nil
            end
        end
    end,
})

getgenv().Window = Window



