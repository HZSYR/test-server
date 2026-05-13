local armedPeds = {}
local aggroPeds = {}
local CHAOS_GROUP = nil

local weapons = {
    0x1B06D571, 0x5EF9FEC4, 0x22D8FE39, 0xD205520E,
    0x13532244, 0x2BE6766B, 0xEFE7E2DF, 0xBD248B55,
    0xBFEFFF6D, 0x83BF0278, 0x0C472FE2, 0x969C3D67,
    0x1D073A89, 0x7FD62962, 0xE284C527
}

Citizen.CreateThread(function()
    AddRelationshipGroup("CHAOS_GROUP")
    CHAOS_GROUP = GetHashKey("CHAOS_GROUP")
    SetRelationshipBetweenGroups(5, CHAOS_GROUP, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), CHAOS_GROUP)
    SetRelationshipBetweenGroups(5, CHAOS_GROUP, CHAOS_GROUP)
end)

local function ArmPed(ped)
    if armedPeds[ped] then return end
    if not DoesEntityExist(ped) then return end
    if IsPedAPlayer(ped) then return end
    
    armedPeds[ped] = true
    
    local weapon = weapons[math.random(#weapons)]
    GiveWeaponToPed(ped, weapon, 9999, false, true)
    SetCurrentPedWeapon(ped, weapon, true)
    SetPedInfiniteAmmo(ped, true, weapon)
end

local function MakePedAggro(ped, target)
    if aggroPeds[ped] then return end
    if not DoesEntityExist(ped) then return end
    if IsPedAPlayer(ped) then return end
    if IsPedDeadOrDying(ped) then return end
    
    aggroPeds[ped] = true
    
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 4160)
    end
    
    ClearPedTasksImmediately(ped)
    
    if not armedPeds[ped] then
        ArmPed(ped)
    end
    
    SetPedRelationshipGroupHash(ped, CHAOS_GROUP)
    SetPedAsEnemy(ped, true)
    
    SetEntityHealth(ped, 300)
    SetPedArmour(ped, 100)
    SetPedCanRagdoll(ped, false)
    
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedConfigFlag(ped, 2, false)
    SetPedConfigFlag(ped, 281, true)
    SetPedConfigFlag(ped, 292, true)
    
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAttributes(ped, 1, true)
    SetPedCombatAttributes(ped, 2, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAbility(ped, 100)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 80)
    SetPedHearingRange(ped, 200.0)
    
    TaskCombatPed(ped, target, 0, 16)
    SetPedKeepTask(ped, true)
end

local function TriggerChaos(sourceCoords, radius)
    local handle, ped = FindFirstPed()
    local success = true
    local player = PlayerPedId()
    
    while success do
        if ped ~= 0 and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped) and not aggroPeds[ped] then
            local dist = #(sourceCoords - GetEntityCoords(ped))
            if dist < radius then
                local targets = {}
                local h2, p2 = FindFirstPed()
                local s2 = true
                while s2 do
                    if p2 ~= 0 and p2 ~= ped and not IsPedDeadOrDying(p2) then
                        local d2 = #(GetEntityCoords(ped) - GetEntityCoords(p2))
                        if d2 < 50.0 then
                            table.insert(targets, p2)
                        end
                    end
                    s2, p2 = FindNextPed(h2)
                end
                EndFindPed(h2)
                
                if #targets > 0 then
                    local randomTarget = targets[math.random(#targets)]
                    MakePedAggro(ped, randomTarget)
                else
                    MakePedAggro(ped, player)
                end
            end
        end
        success, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
end

Citizen.CreateThread(function()
    print("^1==========================================^7")
    print("^1   CHAOS MODE - SEMUA NPC BERSENJATA!    ^7")
    print("^1==========================================^7")
    
    while true do
        Wait(0)
        
        local player = PlayerPedId()
        local pCoords = GetEntityCoords(player)
        
        local handle, ped = FindFirstPed()
        local success = true
        
        while success do
            if ped ~= 0 and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped) then
                local dist = #(pCoords - GetEntityCoords(ped))
                
                if dist < 100.0 and not armedPeds[ped] then
                    ArmPed(ped)
                end
                
                if dist < 25.0 and not aggroPeds[ped] then
                    local vehicle = GetVehiclePedIsIn(player, false)
                    local trigger = false
                    
                    if HasEntityBeenDamagedByEntity(ped, player, true) then
                        trigger = true
                        ClearEntityLastDamageEntity(ped)
                    end
                    
                    if vehicle ~= 0 and HasEntityBeenDamagedByEntity(ped, vehicle, true) then
                        trigger = true
                        ClearEntityLastDamageEntity(ped)
                        ClearEntityLastDamageEntity(vehicle)
                    end
                    
                    if trigger then
                        MakePedAggro(ped, player)
                        TriggerChaos(GetEntityCoords(ped), 50.0)
                    end
                end
            end
            success, ped = FindNextPed(handle)
        end
        EndFindPed(handle)
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        local handle, ped = FindFirstPed()
        local success = true
        
        while success do
            if ped ~= 0 and DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                if IsPedShooting(ped) then
                    local shooterCoords = GetEntityCoords(ped)
                    
                    local h2, nearby = FindFirstPed()
                    local s2 = true
                    while s2 do
                        if nearby ~= 0 and nearby ~= ped and not IsPedDeadOrDying(nearby) and not aggroPeds[nearby] then
                            local dist = #(shooterCoords - GetEntityCoords(nearby))
                            if dist < 80.0 then
                                MakePedAggro(nearby, ped)
                            end
                        end
                        s2, nearby = FindNextPed(h2)
                    end
                    EndFindPed(h2)
                end
            end
            success, ped = FindNextPed(handle)
        end
        EndFindPed(handle)
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(50)
        
        for ped in pairs(aggroPeds) do
            if DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                if GetEntityHealth(ped) < 150 then
                    SetEntityHealth(ped, 150)
                end
                if not IsPedInCombat(ped) then
                    local handle, target = FindFirstPed()
                    local success = true
                    local closest = nil
                    local closestDist = 999.0
                    
                    while success do
                        if target ~= 0 and target ~= ped and not IsPedDeadOrDying(target) then
                            local d = #(GetEntityCoords(ped) - GetEntityCoords(target))
                            if d < closestDist then
                                closestDist = d
                                closest = target
                            end
                        end
                        success, target = FindNextPed(handle)
                    end
                    EndFindPed(handle)
                    
                    if closest then
                        TaskCombatPed(ped, closest, 0, 16)
                    end
                end
            else
                aggroPeds[ped] = nil
                armedPeds[ped] = nil
            end
        end
    end
end)

RegisterCommand('forceaggro', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local count = 0
    
    local handle, ped = FindFirstPed()
    local found = true
    while found do
        if ped and DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped) then
            local dist = #(playerCoords - GetEntityCoords(ped))
            if dist < 20.0 and not aggroPeds[ped] then
                Citizen.CreateThread(function() MakePedAggro(ped) end)
                count = count + 1
            end
        end
        found, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
    
    print("[NPC AGGRO] ^1Forced " .. count .. " NPCs to aggro!^7")
end, false)

RegisterCommand('testnpc', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local fwd = GetEntityForwardVector(playerPed)
    local spawnCoords = coords + fwd * 3.0
    
    local models = {"a_m_m_business_01", "a_m_y_hipster_01", "g_m_y_mexgoon_01", "s_m_y_dealer_01"}
    local model = GetHashKey(models[math.random(#models)])
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    local ped = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, GetEntityHeading(playerPed) + 180.0, true, false)
    SetModelAsNoLongerNeeded(model)
    
    Wait(300)
    MakePedAggro(ped)
    
    print("[NPC AGGRO] ^2Test NPC spawned!^7")
end, false)

RegisterCommand('npcstatus', function()
    local count = 0
    for _ in pairs(aggroPeds) do count = count + 1 end
    print("[NPC AGGRO] ^3NPC agresif aktif: ^1" .. count .. "^7")
end, false)
