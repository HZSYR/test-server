-- ============================================
-- PLAYER MENU - Client Side v2.0
-- By Kapuyuak - Full Rewrite
-- ============================================

local menuOpen = false
local firstSpawn = true
local noclipActive = false
local noclipSpeed = 2.0

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
    espplayer = false,
    espnpc = false,
    espvehicle = false,
    espbox = true,
    espline = true,
    espdistance = true,
    esphealth = true,
    espname = true,
    espskeleton = false
}

-- ============================================
-- MENU CONTROLS - F1 ONLY
-- ============================================

RegisterCommand('menu', function()
    ToggleMenu()
end, false)

RegisterKeyMapping('menu', 'Player Menu', 'keyboard', 'F1')

function ToggleMenu()
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    SendNUIMessage({ action = menuOpen and 'show' or 'hide' })
    if menuOpen then UpdatePlayerList() end
end

RegisterNUICallback('close', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    cb('ok')
end)

-- ============================================
-- NOTIFICATION
-- ============================================

AddEventHandler('playerSpawned', function()
    if firstSpawn then
        firstSpawn = false
        Wait(3000)
        SendNUIMessage({ action = 'notify' })
    end
end)

-- ============================================
-- CALLBACKS
-- ============================================

RegisterNUICallback('toggle', function(data, cb)
    toggles[data.action] = data.state
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    local action = data.action
    local ped = PlayerPedId()
    
    if action == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        SetPedArmour(ped, 100)
    elseif action == 'suicide' then
        SetEntityHealth(ped, 0)
    elseif action == 'repair' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleDirtLevel(veh, 0.0)
        end
    elseif action == 'flip' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then SetVehicleOnGroundProperly(veh) end
    elseif action == 'engine' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true)
        end
    elseif action == 'deleteveh' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then DeleteEntity(veh) end
    elseif action == 'getallweapons' then
        GiveAllWeapons()
    elseif action == 'removeallweapons' then
        RemoveAllPedWeapons(ped, true)
    elseif action == 'tpwaypoint' then
        TeleportToWaypoint()
    end
    cb('ok')
end)

RegisterNUICallback('spawn_vehicle', function(data, cb)
    SpawnVehicle(data.model)
    cb('ok')
end)

RegisterNUICallback('spawn_category', function(data, cb)
    local vehicles = {
        super = {'adder', 'zentorno', 't20', 'osiris', 'entityxf', 'turismor', 'nero', 'tempesta'},
        sports = {'elegy2', 'jester', 'massacro', 'ninef', 'rapidgt', 'banshee', 'comet2'},
        muscle = {'dominator', 'gauntlet', 'vigero', 'sabregt', 'phoenix', 'ruiner'},
        offroad = {'sandking', 'rebel', 'bifta', 'insurgent', 'mesa', 'guardian'},
        motorcycle = {'bati', 'akuma', 'hakuchou', 'nemesis', 'pcj', 'sanchez'},
        helicopter = {'buzzard', 'savage', 'valkyrie', 'swift', 'maverick', 'annihilator'},
        plane = {'lazer', 'hydra', 'besra', 'titan', 'luxor', 'vestra'},
        boat = {'speeder', 'jetmax', 'marquis', 'dinghy', 'seashark', 'toro'}
    }
    if vehicles[data.category] then
        SpawnVehicle(vehicles[data.category][math.random(#vehicles[data.category])])
    end
    cb('ok')
end)

RegisterNUICallback('set_ped', function(data, cb)
    SetPlayerPedModel(data.model)
    cb('ok')
end)

RegisterNUICallback('set_weather', function(data, cb)
    TriggerServerEvent('player_menu:setWeather', data.weather)
    cb('ok')
end)

RegisterNUICallback('set_time', function(data, cb)
    TriggerServerEvent('player_menu:setTime', data.hour)
    cb('ok')
end)

RegisterNUICallback('set_torque', function(data, cb) cb('ok') end)
RegisterNUICallback('set_power', function(data, cb) cb('ok') end)

RegisterNUICallback('player_action', function(data, cb)
    if data.action == 'tp' then
        TriggerServerEvent('player_menu:getPlayerCoords', data.target)
    end
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

RegisterNetEvent('player_menu:teleportTo')
AddEventHandler('player_menu:teleportTo', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
end)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

function UpdatePlayerList()
    local players = {}
    for _, id in ipairs(GetActivePlayers()) do
        table.insert(players, { id = GetPlayerServerId(id), name = GetPlayerName(id) })
    end
    SendNUIMessage({ action = 'updatePlayers', players = players })
end

function SpawnVehicle(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Wait(10) end
    if HasModelLoaded(hash) then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local veh = CreateVehicle(hash, c.x, c.y, c.z + 1.0, GetEntityHeading(ped), true, false)
        SetPedIntoVehicle(ped, veh, -1)
        SetVehicleOnGroundProperly(veh)
        SetModelAsNoLongerNeeded(hash)
    end
end

function SetPlayerPedModel(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Wait(10) end
    if HasModelLoaded(hash) then
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
    end
end

function GiveAllWeapons()
    local ped = PlayerPedId()
    local weapons = {
        0x1B06D571, 0x5EF9FEC4, 0x22D8FE39, 0x99AEEB3B, 0x13532244, 0x2BE6766B,
        0xEFE7E2DF, 0x0A3D4D34, 0xBFEFFF6D, 0x83BF0278, 0xAF113F99, 0x9D07F764,
        0x7FD62962, 0x1D073A89, 0x7846A318, 0xE284C527, 0x9D61E50F, 0x3656C8C1,
        0x05FC3C11, 0x0C472FE2, 0xA284510B, 0x42BF8A85, 0x7F7497E5, 0x6D544C99,
        0x63AB0442, 0x0781FE4A, 0xB1CA77B1, 0xA0973D5E, 0x24B17070, 0x2C3731D9
    }
    for _, w in ipairs(weapons) do
        GiveWeaponToPed(ped, w, 9999, false, false)
    end
end

function TeleportToWaypoint()
    local wp = GetFirstBlipInfoId(8)
    if DoesBlipExist(wp) then
        local c = GetBlipCoords(wp)
        local ped = PlayerPedId()
        for z = 1000.0, 0.0, -25.0 do
            SetEntityCoordsNoOffset(ped, c.x, c.y, z, false, false, false)
            Wait(50)
            local found, ground = GetGroundZFor_3dCoord(c.x, c.y, z, false)
            if found then
                SetEntityCoords(ped, c.x, c.y, ground + 1.0, false, false, false, false)
                return
            end
        end
        SetEntityCoords(ped, c.x, c.y, 200.0, false, false, false, false)
    end
end

-- ============================================
-- MAIN LOOP - TOGGLES
-- ============================================

Citizen.CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        
        if toggles.godmode then SetEntityInvincible(ped, true) else SetEntityInvincible(ped, false) end
        if toggles.invisible then SetEntityVisible(ped, false, false) end
        if toggles.neverwanted then ClearPlayerWantedLevel(PlayerId()) SetMaxWantedLevel(0) end
        if toggles.stamina then ResetPlayerStamina(PlayerId()) end
        if toggles.fastrun then SetRunSprintMultiplierForPlayer(PlayerId(), 1.49) end
        if toggles.fastswim then SetSwimMultiplierForPlayer(PlayerId(), 1.49) end
        if toggles.superjump then SetSuperJumpThisFrame(PlayerId()) end
        if toggles.noragdoll then SetPedCanRagdoll(ped, false) end
        if veh ~= 0 and toggles.vehgod then SetEntityInvincible(veh, true) end
        if veh ~= 0 and toggles.vehinvisible then SetEntityVisible(veh, false, false) end
        if toggles.unlimitedammo then SetPedInfiniteAmmo(ped, true, 0) SetPedInfiniteAmmoClip(ped, true) end
    end
end)

-- ============================================
-- NOCLIP - PROPER IMPLEMENTATION
-- ============================================

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if toggles.noclip then
            local ped = PlayerPedId()
            
            SetEntityCollision(ped, false, false)
            FreezeEntityPosition(ped, true)
            
            local camRot = GetGameplayCamRot(2)
            local camCoord = GetGameplayCamCoord()
            
            local speed = noclipSpeed
            if IsControlPressed(0, 21) then speed = speed * 3.0 end
            if IsControlPressed(0, 36) then speed = speed * 0.3 end
            
            local fwd = RotToDir(camRot)
            local right = vector3(fwd.y, -fwd.x, 0.0)
            
            local newPos = GetEntityCoords(ped)
            
            if IsControlPressed(0, 32) then newPos = newPos + fwd * speed end
            if IsControlPressed(0, 33) then newPos = newPos - fwd * speed end
            if IsControlPressed(0, 34) then newPos = newPos - right * speed end
            if IsControlPressed(0, 35) then newPos = newPos + right * speed end
            if IsControlPressed(0, 44) then newPos = newPos + vector3(0, 0, speed) end
            if IsControlPressed(0, 46) then newPos = newPos - vector3(0, 0, speed) end
            
            SetEntityCoordsNoOffset(ped, newPos.x, newPos.y, newPos.z, true, true, true)
        end
    end
end)

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

function RotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- ============================================
-- ESP SYSTEM - CHEAT STYLE
-- ============================================

local ESP = {
    colors = {
        enemy = {255, 0, 0},
        friendly = {0, 255, 0},
        npc = {255, 165, 0},
        vehicle = {0, 255, 255},
        bone = {255, 255, 255}
    }
}

function ESP.DrawText3D(x, y, z, text, r, g, b, scale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextFont(4)
        SetTextScale(scale or 0.35, scale or 0.35)
        SetTextColour(r, g, b, 255)
        SetTextOutline()
        SetTextCentre(true)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(sx, sy)
        return sx, sy
    end
    return nil, nil
end

function ESP.DrawBox2D(entity, r, g, b)
    local pos = GetEntityCoords(entity)
    local head = vector3(pos.x, pos.y, pos.z + 0.9)
    local foot = vector3(pos.x, pos.y, pos.z - 1.0)
    
    local onH, hx, hy = World3dToScreen2d(head.x, head.y, head.z)
    local onF, fx, fy = World3dToScreen2d(foot.x, foot.y, foot.z)
    
    if onH and onF then
        local h = math.abs(fy - hy)
        local w = h * 0.4
        local cx = (hx + fx) / 2
        
        local t = 0.0015
        DrawRect(cx, hy, w, t, 0, 0, 0, 200)
        DrawRect(cx, fy, w, t, 0, 0, 0, 200)
        DrawRect(cx - w/2, (hy+fy)/2, t, h, 0, 0, 0, 200)
        DrawRect(cx + w/2, (hy+fy)/2, t, h, 0, 0, 0, 200)
        
        t = 0.001
        DrawRect(cx, hy, w-0.001, t, r, g, b, 255)
        DrawRect(cx, fy, w-0.001, t, r, g, b, 255)
        DrawRect(cx - w/2, (hy+fy)/2, t, h-0.001, r, g, b, 255)
        DrawRect(cx + w/2, (hy+fy)/2, t, h-0.001, r, g, b, 255)
        
        return cx, hy, fy, w, h
    end
    return nil
end

function ESP.DrawSnapline(sx, sy, r, g, b)
    local steps = 60
    for i = 0, steps do
        local t = i / steps
        local x = 0.5 + (sx - 0.5) * t
        local y = 0.95 + (sy - 0.95) * t
        DrawRect(x, y, 0.001, 0.002, 0, 0, 0, 150)
        DrawRect(x, y, 0.0008, 0.0015, r, g, b, 255)
    end
end

function ESP.DrawHealthBar(cx, hy, fy, w, health, maxHealth)
    local h = math.abs(fy - hy)
    local barW = 0.004
    local barX = cx - w/2 - 0.008
    
    local pct = health / maxHealth
    local barH = h * pct
    local barY = fy - barH/2
    
    DrawRect(barX, (hy+fy)/2, barW + 0.002, h + 0.002, 0, 0, 0, 200)
    
    local hr = math.floor(255 * (1 - pct))
    local hg = math.floor(255 * pct)
    DrawRect(barX, barY, barW, barH, hr, hg, 0, 255)
end

function ESP.DrawSkeleton(ped, r, g, b)
    local bones = {
        {0, 7},
        {7, 6},
        {6, 5},
        {5, 57597},
        {5, 18905},
        {57597, 22711},
        {18905, 61007},
        {0, 58271},
        {0, 51826},
        {58271, 63931},
        {51826, 14201}
    }
    
    for _, pair in ipairs(bones) do
        local b1 = GetPedBoneCoords(ped, pair[1], 0, 0, 0)
        local b2 = GetPedBoneCoords(ped, pair[2], 0, 0, 0)
        
        local on1, x1, y1 = World3dToScreen2d(b1.x, b1.y, b1.z)
        local on2, x2, y2 = World3dToScreen2d(b2.x, b2.y, b2.z)
        
        if on1 and on2 then
            local steps = 20
            for i = 0, steps do
                local t = i / steps
                local x = x1 + (x2 - x1) * t
                local y = y1 + (y2 - y1) * t
                DrawRect(x, y, 0.001, 0.001, r, g, b, 255)
            end
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        if toggles.espplayer or toggles.espnpc or toggles.espvehicle then
            local myPed = PlayerPedId()
            local myPos = GetEntityCoords(myPed)
            
            if toggles.espplayer then
                for _, pid in ipairs(GetActivePlayers()) do
                    local tPed = GetPlayerPed(pid)
                    if tPed ~= myPed and DoesEntityExist(tPed) and not IsPedDeadOrDying(tPed) then
                        local pos = GetEntityCoords(tPed)
                        local dist = #(myPos - pos)
                        
                        if dist < 500.0 then
                            local c = ESP.colors.enemy
                            local name = GetPlayerName(pid)
                            local hp = GetEntityHealth(tPed)
                            local maxHp = GetEntityMaxHealth(tPed)
                            
                            if toggles.espbox then
                                local cx, hy, fy, w, h = ESP.DrawBox2D(tPed, c[1], c[2], c[3])
                                if cx and toggles.esphealth then
                                    ESP.DrawHealthBar(cx, hy, fy, w, hp, maxHp)
                                end
                                if cx and toggles.espline then
                                    ESP.DrawSnapline(cx, fy, c[1], c[2], c[3])
                                end
                            end
                            
                            if toggles.espskeleton then
                                ESP.DrawSkeleton(tPed, 255, 255, 255)
                            end
                            
                            local info = ""
                            if toggles.espname then info = name end
                            if toggles.espdistance then info = info .. " [" .. math.floor(dist) .. "m]" end
                            if toggles.esphealth then info = info .. " " .. math.floor((hp/maxHp)*100) .. "%" end
                            
                            if info ~= "" then
                                ESP.DrawText3D(pos.x, pos.y, pos.z + 1.2, info, c[1], c[2], c[3], 0.3)
                            end
                        end
                    end
                end
            end
            
            if toggles.espnpc then
                local handle, ped = FindFirstPed()
                local success = true
                while success do
                    if ped ~= myPed and not IsPedAPlayer(ped) and DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                        local pos = GetEntityCoords(ped)
                        local dist = #(myPos - pos)
                        
                        if dist < 100.0 then
                            local c = ESP.colors.npc
                            
                            if toggles.espbox then
                                local cx, hy, fy, w, h = ESP.DrawBox2D(ped, c[1], c[2], c[3])
                                if cx and toggles.espline then
                                    ESP.DrawSnapline(cx, fy, c[1], c[2], c[3])
                                end
                            end
                            
                            if toggles.espdistance then
                                ESP.DrawText3D(pos.x, pos.y, pos.z + 1.0, "[" .. math.floor(dist) .. "m]", c[1], c[2], c[3], 0.25)
                            end
                        end
                    end
                    success, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end
            
            if toggles.espvehicle then
                local handle, veh = FindFirstVehicle()
                local success = true
                while success do
                    if DoesEntityExist(veh) then
                        local pos = GetEntityCoords(veh)
                        local dist = #(myPos - pos)
                        
                        if dist < 150.0 and dist > 5.0 then
                            local c = ESP.colors.vehicle
                            local vname = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
                            
                            if toggles.espbox then
                                ESP.DrawBox2D(veh, c[1], c[2], c[3])
                            end
                            
                            local info = vname
                            if toggles.espdistance then info = info .. " [" .. math.floor(dist) .. "m]" end
                            ESP.DrawText3D(pos.x, pos.y, pos.z + 1.5, info, c[1], c[2], c[3], 0.25)
                        end
                    end
                    success, veh = FindNextVehicle(handle)
                end
                EndFindVehicle(handle)
            end
        end
    end
end)
