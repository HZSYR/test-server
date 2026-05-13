-- ============================================
-- PLAYER MENU - Client Side
-- By Kapuyuak
-- ============================================

local menuOpen = false
local firstSpawn = true

-- Toggle States
local toggles = {
    godmode = false,
    invisible = false,
    neverwanted = false,
    stamina = false,
    fastrun = false,
    fastswim = false,
    superjump = false,
    noragdoll = false,
    vehgod = false,
    vehinvisible = false,
    unlimitedammo = true,
    noreload = false,
    freezetime = false,
    noclip = false,
    -- ESP
    espplayer = false,
    espnpc = false,
    espvehicle = false,
    espbox = false,
    espline = false,
    espdistance = false,
    esphealth = false
}

local noclipCam = nil
local noclipSpeed = 1.0

-- ============================================
-- MENU CONTROLS
-- ============================================

RegisterCommand('playermenu', function()
    ToggleMenu()
end, false)

RegisterKeyMapping('playermenu', 'Open Player Menu', 'keyboard', 'F1')

function ToggleMenu()
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    
    if menuOpen then
        SendNUIMessage({ action = 'show' })
        UpdatePlayerList()
    else
        SendNUIMessage({ action = 'hide' })
    end
end

RegisterNUICallback('close', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    cb('ok')
end)

-- ============================================
-- NOTIFICATION ON JOIN
-- ============================================

AddEventHandler('playerSpawned', function()
    if firstSpawn then
        firstSpawn = false
        Wait(3000)
        SendNUIMessage({ action = 'notify' })
    end
end)

-- ============================================
-- TOGGLE HANDLERS
-- ============================================

RegisterNUICallback('toggle', function(data, cb)
    local action = data.action
    local state = data.state
    toggles[action] = state
    cb('ok')
end)

-- ============================================
-- ACTION HANDLERS
-- ============================================

RegisterNUICallback('action', function(data, cb)
    local action = data.action
    local ped = PlayerPedId()
    
    if action == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    elseif action == 'armor' then
        SetPedArmour(ped, 100)
    elseif action == 'suicide' then
        SetEntityHealth(ped, 0)
    elseif action == 'repair' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleUndriveable(veh, false)
        end
    elseif action == 'wash' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            SetVehicleDirtLevel(veh, 0.0)
        end
    elseif action == 'flip' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            SetVehicleOnGroundProperly(veh)
        end
    elseif action == 'engine' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local running = GetIsVehicleEngineRunning(veh)
            SetVehicleEngineOn(veh, not running, false, true)
        end
    elseif action == 'deleteveh' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            DeleteEntity(veh)
        end
    elseif action == 'getallweapons' then
        GiveAllWeapons()
    elseif action == 'removeallweapons' then
        RemoveAllPedWeapons(ped, true)
    elseif action == 'tpwaypoint' then
        TeleportToWaypoint()
    end
    
    cb('ok')
end)

-- ============================================
-- VEHICLE SPAWNER
-- ============================================

RegisterNUICallback('spawn_vehicle', function(data, cb)
    SpawnVehicle(data.model)
    cb('ok')
end)

RegisterNUICallback('spawn_category', function(data, cb)
    local vehicles = {
        super = {'adder', 'zentorno', 't20', 'osiris', 'entityxf', 'turismor', 'reaper', 'fmj', 'penetrator', 'nero'},
        sports = {'elegy2', 'jester', 'massacro', 'ninef', 'rapidgt', 'banshee', 'comet2', 'feltzer2', 'carbonizzare'},
        muscle = {'dominator', 'gauntlet', 'vigero', 'sabregt', 'phoenix', 'ruiner', 'blade', 'buccaneer', 'chino'},
        offroad = {'sandking', 'rebel', 'bifta', 'blazer', 'brawler', 'dubsta3', 'insurgent', 'mesa', 'guardian'},
        motorcycle = {'bati', 'akuma', 'hakuchou', 'nemesis', 'pcj', 'ruffian', 'sanchez', 'thrust', 'vader'},
        helicopter = {'buzzard', 'savage', 'valkyrie', 'swift', 'maverick', 'frogger', 'annihilator', 'cargobob'},
        plane = {'lazer', 'hydra', 'besra', 'titan', 'luxor', 'shamal', 'vestra', 'dodo', 'cuban800'},
        boat = {'speeder', 'jetmax', 'marquis', 'dinghy', 'tropic', 'seashark', 'toro', 'squalo'}
    }
    
    local cat = data.category
    if vehicles[cat] then
        local model = vehicles[cat][math.random(#vehicles[cat])]
        SpawnVehicle(model)
    end
    cb('ok')
end)

function SpawnVehicle(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    
    local timeout = 5000
    local start = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(100)
        if GetGameTimer() - start > timeout then
            return
        end
    end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z + 1.0, heading, true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetModelAsNoLongerNeeded(hash)
end

-- ============================================
-- PED SPAWNER
-- ============================================

RegisterNUICallback('set_ped', function(data, cb)
    SetPlayerPed(data.model)
    cb('ok')
end)

function SetPlayerPed(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    
    local timeout = 5000
    local start = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(100)
        if GetGameTimer() - start > timeout then
            return
        end
    end
    
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
end

-- ============================================
-- WEATHER & TIME
-- ============================================

RegisterNUICallback('set_weather', function(data, cb)
    TriggerServerEvent('player_menu:setWeather', data.weather)
    cb('ok')
end)

RegisterNUICallback('set_time', function(data, cb)
    TriggerServerEvent('player_menu:setTime', data.hour)
    cb('ok')
end)

RegisterNetEvent('player_menu:syncWeather')
AddEventHandler('player_menu:syncWeather', function(weather)
    SetWeatherTypeNowPersist(weather)
end)

RegisterNetEvent('player_menu:syncTime')
AddEventHandler('player_menu:syncTime', function(hour)
    NetworkOverrideClockTime(hour, 0, 0)
end)

-- ============================================
-- VEHICLE PERFORMANCE
-- ============================================

local torqueMultiplier = 1.0
local powerMultiplier = 1.0

RegisterNUICallback('set_torque', function(data, cb)
    torqueMultiplier = data.value
    cb('ok')
end)

RegisterNUICallback('set_power', function(data, cb)
    powerMultiplier = data.value
    cb('ok')
end)

-- ============================================
-- PLAYER ACTIONS
-- ============================================

RegisterNUICallback('player_action', function(data, cb)
    local action = data.action
    local target = data.target
    
    if action == 'tp' then
        TriggerServerEvent('player_menu:getPlayerCoords', target)
    elseif action == 'spectate' then
        TriggerServerEvent('player_menu:spectate', target)
    end
    cb('ok')
end)

RegisterNetEvent('player_menu:teleportTo')
AddEventHandler('player_menu:teleportTo', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)

local spectating = false
local spectateTarget = nil

RegisterNetEvent('player_menu:doSpectate')
AddEventHandler('player_menu:doSpectate', function(targetServerId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
    
    if spectating then
        spectating = false
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        NetworkSetEntityInvisibleToNetwork(ped, false)
        SpectatePlayer(false, targetPed)
    else
        spectating = true
        spectateTarget = targetServerId
        local ped = PlayerPedId()
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        NetworkSetEntityInvisibleToNetwork(ped, true)
        SpectatePlayer(true, targetPed)
    end
end)

function SpectatePlayer(state, targetPed)
    if state then
        local coords = GetEntityCoords(targetPed)
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        NetworkSetInSpectatorMode(true, targetPed)
    else
        NetworkSetInSpectatorMode(false, PlayerPedId())
    end
end

-- ============================================
-- UPDATE PLAYER LIST
-- ============================================

function UpdatePlayerList()
    local players = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(playerId)
        local name = GetPlayerName(playerId)
        table.insert(players, { id = serverId, name = name })
    end
    SendNUIMessage({ action = 'updatePlayers', players = players })
end

-- ============================================
-- TELEPORT TO WAYPOINT
-- ============================================

function TeleportToWaypoint()
    local waypoint = GetFirstBlipInfoId(8)
    if DoesBlipExist(waypoint) then
        local coords = GetBlipCoords(waypoint)
        local ped = PlayerPedId()
        
        local groundZ = 0.0
        local found = false
        
        for z = 1000.0, 0.0, -25.0 do
            SetEntityCoordsNoOffset(ped, coords.x, coords.y, z, false, false, false)
            Wait(50)
            local ground, groundZ2 = GetGroundZFor_3dCoord(coords.x, coords.y, z, false)
            if ground then
                groundZ = groundZ2
                found = true
                break
            end
        end
        
        if found then
            SetEntityCoords(ped, coords.x, coords.y, groundZ + 1.0, false, false, false, false)
        else
            SetEntityCoords(ped, coords.x, coords.y, coords.z + 100.0, false, false, false, false)
        end
    end
end

-- ============================================
-- GIVE ALL WEAPONS
-- ============================================

function GiveAllWeapons()
    local ped = PlayerPedId()
    local weapons = {
        'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50',
        'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW',
        'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE',
        'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_GUSENBERG',
        'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_MARKSMANRIFLE',
        'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN',
        'WEAPON_GRENADELAUNCHER', 'WEAPON_RPG', 'WEAPON_MINIGUN', 'WEAPON_RAILGUN',
        'WEAPON_GRENADE', 'WEAPON_STICKYBOMB', 'WEAPON_SMOKEGRENADE', 'WEAPON_MOLOTOV',
        'WEAPON_KNIFE', 'WEAPON_BAT', 'WEAPON_CROWBAR', 'WEAPON_GOLFCLUB'
    }
    
    for _, weapon in ipairs(weapons) do
        local hash = GetHashKey(weapon)
        GiveWeaponToPed(ped, hash, 9999, false, false)
    end
end

-- ============================================
-- MAIN LOOP - TOGGLE EFFECTS
-- ============================================

Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        
        -- God Mode
        if toggles.godmode then
            SetEntityInvincible(ped, true)
        else
            SetEntityInvincible(ped, false)
        end
        
        -- Invisible
        if toggles.invisible then
            SetEntityVisible(ped, false, false)
        end
        
        -- Never Wanted
        if toggles.neverwanted then
            ClearPlayerWantedLevel(PlayerId())
            SetMaxWantedLevel(0)
        end
        
        -- Unlimited Stamina
        if toggles.stamina then
            ResetPlayerStamina(PlayerId())
        end
        
        -- Fast Run
        if toggles.fastrun then
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
        else
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        end
        
        -- Fast Swim
        if toggles.fastswim then
            SetSwimMultiplierForPlayer(PlayerId(), 1.49)
        else
            SetSwimMultiplierForPlayer(PlayerId(), 1.0)
        end
        
        -- Super Jump
        if toggles.superjump then
            SetSuperJumpThisFrame(PlayerId())
        end
        
        -- No Ragdoll
        if toggles.noragdoll then
            SetPedCanRagdoll(ped, false)
        else
            SetPedCanRagdoll(ped, true)
        end
        
        -- Vehicle God Mode
        if veh ~= 0 and toggles.vehgod then
            SetEntityInvincible(veh, true)
        end
        
        -- Vehicle Invisible
        if veh ~= 0 and toggles.vehinvisible then
            SetEntityVisible(veh, false, false)
        end
        
        -- Unlimited Ammo
        if toggles.unlimitedammo then
            SetPedInfiniteAmmo(ped, true, GetHashKey('WEAPON_UNARMED'))
            SetPedInfiniteAmmoClip(ped, true)
        end
        
        -- No Reload
        if toggles.noreload then
            local _, weaponHash = GetCurrentPedWeapon(ped, true)
            if weaponHash ~= GetHashKey('WEAPON_UNARMED') then
                RefillAmmoInstantly(ped)
            end
        end
        
        -- Vehicle Performance
        if veh ~= 0 then
            if torqueMultiplier > 1.0 then
                SetVehicleEngineTorqueMultiplier(veh, torqueMultiplier)
            end
            if powerMultiplier > 1.0 then
                SetVehicleEnginePowerMultiplier(veh, powerMultiplier)
            end
        end
        
        -- NoClip
        if toggles.noclip then
            HandleNoClip()
        end
    end
end)

-- ============================================
-- NOCLIP
-- ============================================

function HandleNoClip()
    local ped = PlayerPedId()
    
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    
    local speed = noclipSpeed
    if IsControlPressed(0, 21) then speed = speed * 3 end -- Shift
    if IsControlPressed(0, 36) then speed = speed * 0.3 end -- Ctrl
    
    local newPos = camCoords
    
    if IsControlPressed(0, 32) then -- W
        local dir = RotationToDirection(camRot)
        newPos = vector3(newPos.x + dir.x * speed, newPos.y + dir.y * speed, newPos.z + dir.z * speed)
    end
    if IsControlPressed(0, 33) then -- S
        local dir = RotationToDirection(camRot)
        newPos = vector3(newPos.x - dir.x * speed, newPos.y - dir.y * speed, newPos.z - dir.z * speed)
    end
    if IsControlPressed(0, 34) then -- A
        local dir = RotationToDirection(vector3(camRot.x, camRot.y, camRot.z + 90))
        newPos = vector3(newPos.x + dir.x * speed, newPos.y + dir.y * speed, newPos.z)
    end
    if IsControlPressed(0, 35) then -- D
        local dir = RotationToDirection(vector3(camRot.x, camRot.y, camRot.z - 90))
        newPos = vector3(newPos.x + dir.x * speed, newPos.y + dir.y * speed, newPos.z)
    end
    
    SetEntityCoordsNoOffset(ped, newPos.x, newPos.y, newPos.z, false, false, false)
end

function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- Disable NoClip when toggle off
Citizen.CreateThread(function()
    local wasNoclip = false
    while true do
        Wait(100)
        if wasNoclip and not toggles.noclip then
            local ped = PlayerPedId()
            SetEntityCollision(ped, true, true)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true, false)
        end
        wasNoclip = toggles.noclip
    end
end)

-- ============================================
-- ESP SYSTEM
-- ============================================

local espColors = {
    player = {r = 255, g = 0, b = 0, a = 255},      -- Red
    npc = {r = 255, g = 165, b = 0, a = 255},       -- Orange
    vehicle = {r = 0, g = 255, b = 255, a = 255},   -- Cyan
    health = {r = 0, g = 255, b = 0, a = 255},      -- Green
    text = {r = 255, g = 255, b = 255, a = 255}     -- White
}

function DrawESPText(text, x, y, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

function Draw3DText(coords, text, scale, r, g, b, a)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        DrawESPText(text, screenX, screenY, scale, r, g, b, a)
        return screenX, screenY
    end
    return nil, nil
end

function DrawESPBox(entity, r, g, b, a)
    local coords = GetEntityCoords(entity)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    
    if onScreen then
        local camCoords = GetGameplayCamCoord()
        local dist = #(camCoords - coords)
        local boxSize = 0.03 / (dist / 50)
        boxSize = math.max(0.01, math.min(boxSize, 0.08))
        
        local halfW = boxSize / 2
        local halfH = boxSize * 1.5
        
        DrawRect(screenX, screenY - halfH, boxSize, 0.002, r, g, b, a)
        DrawRect(screenX, screenY + halfH, boxSize, 0.002, r, g, b, a)
        DrawRect(screenX - halfW, screenY, 0.002, halfH * 2, r, g, b, a)
        DrawRect(screenX + halfW, screenY, 0.002, halfH * 2, r, g, b, a)
    end
end

function DrawESPLine(entity, r, g, b, a)
    local coords = GetEntityCoords(entity)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    
    if onScreen then
        DrawLine2D(0.5, 1.0, screenX, screenY, r, g, b, a)
    end
end

function DrawLine2D(x1, y1, x2, y2, r, g, b, a)
    local steps = 50
    for i = 0, steps do
        local t = i / steps
        local x = x1 + (x2 - x1) * t
        local y = y1 + (y2 - y1) * t
        DrawRect(x, y, 0.001, 0.001, r, g, b, a)
    end
end

function GetHealthBar(entity)
    local health = GetEntityHealth(entity)
    local maxHealth = GetEntityMaxHealth(entity)
    if maxHealth == 0 then maxHealth = 200 end
    local percent = math.floor((health / maxHealth) * 100)
    return percent
end

Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        local espActive = toggles.espplayer or toggles.espnpc or toggles.espvehicle
        
        if espActive then
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            
            -- ESP Players
            if toggles.espplayer then
                for _, playerId in ipairs(GetActivePlayers()) do
                    local targetPed = GetPlayerPed(playerId)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed) then
                        local coords = GetEntityCoords(targetPed)
                        local dist = #(myCoords - coords)
                        
                        if dist < 500.0 then
                            local playerName = GetPlayerName(playerId)
                            local c = espColors.player
                            
                            -- Box
                            if toggles.espbox then
                                DrawESPBox(targetPed, c.r, c.g, c.b, c.a)
                            end
                            
                            -- Line
                            if toggles.espline then
                                DrawESPLine(targetPed, c.r, c.g, c.b, 150)
                            end
                            
                            -- Text info
                            local info = playerName
                            if toggles.espdistance then
                                info = info .. " [" .. math.floor(dist) .. "m]"
                            end
                            if toggles.esphealth then
                                info = info .. " (" .. GetHealthBar(targetPed) .. "%)"
                            end
                            
                            Draw3DText(vector3(coords.x, coords.y, coords.z + 1.0), info, 0.3, c.r, c.g, c.b, c.a)
                        end
                    end
                end
            end
            
            -- ESP NPCs
            if toggles.espnpc then
                local handle, ped = FindFirstPed()
                local success = true
                
                while success do
                    if ped ~= myPed and not IsPedAPlayer(ped) and DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                        local coords = GetEntityCoords(ped)
                        local dist = #(myCoords - coords)
                        
                        if dist < 150.0 then
                            local c = espColors.npc
                            
                            if toggles.espbox then
                                DrawESPBox(ped, c.r, c.g, c.b, c.a)
                            end
                            
                            if toggles.espline then
                                DrawESPLine(ped, c.r, c.g, c.b, 100)
                            end
                            
                            local info = "NPC"
                            if toggles.espdistance then
                                info = info .. " [" .. math.floor(dist) .. "m]"
                            end
                            if toggles.esphealth then
                                info = info .. " (" .. GetHealthBar(ped) .. "%)"
                            end
                            
                            Draw3DText(vector3(coords.x, coords.y, coords.z + 1.0), info, 0.25, c.r, c.g, c.b, c.a)
                        end
                    end
                    success, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end
            
            -- ESP Vehicles
            if toggles.espvehicle then
                local handle, veh = FindFirstVehicle()
                local success = true
                
                while success do
                    if DoesEntityExist(veh) then
                        local coords = GetEntityCoords(veh)
                        local dist = #(myCoords - coords)
                        
                        if dist < 200.0 and dist > 5.0 then
                            local c = espColors.vehicle
                            
                            if toggles.espbox then
                                DrawESPBox(veh, c.r, c.g, c.b, c.a)
                            end
                            
                            if toggles.espline then
                                DrawESPLine(veh, c.r, c.g, c.b, 100)
                            end
                            
                            local vehName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
                            local info = vehName
                            if toggles.espdistance then
                                info = info .. " [" .. math.floor(dist) .. "m]"
                            end
                            
                            Draw3DText(vector3(coords.x, coords.y, coords.z + 1.5), info, 0.25, c.r, c.g, c.b, c.a)
                        end
                    end
                    success, veh = FindNextVehicle(handle)
                end
                EndFindVehicle(handle)
            end
        end
    end
end)
