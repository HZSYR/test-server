local aggroPeds = {}
local policeDispatchEnabled = true

local function MakePedAggressive(ped, target)
    if not DoesEntityExist(ped) then return end
    if IsPedAPlayer(ped) then return end
    if aggroPeds[ped] then return end
    
    aggroPeds[ped] = true
    print("[NPC AGGRO] ^1NPC MARAH: " .. ped .. "^7")
    
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 256)
        Citizen.Wait(500)
    end
    
    SetPedCanRagdoll(ped, false)
    SetPedMaxHealth(ped, 500)
    SetEntityHealth(ped, 500)
    SetPedArmour(ped, 100)
    
    local weaponList = {
        0x1B06D571, 0x5EF9FEC4, 0x22D8FE39,
        0x13532244, 0x2BE6766B, 0xEFE7E2DF,
        0xBFEFFF6D, 0x83BF0278, 0x0C472FE2,
        0x1D073A89, 0x7FD62962,
        0x958A4A8F, 0x84BD7BFD, 0x99B507EA, 0xDD5DF8D9
    }
    local weapon = weaponList[math.random(#weaponList)]
    
    GiveWeaponToPed(ped, weapon, 9999, false, true)
    SetCurrentPedWeapon(ped, weapon, true)
    SetPedInfiniteAmmo(ped, true, weapon)
    
    ClearPedTasksImmediately(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAttributes(ped, 1, true)
    SetPedCombatAttributes(ped, 2, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 70)
    SetPedSeeingRange(ped, 100.0)
    SetPedHearingRange(ped, 100.0)
    SetPedAlertness(ped, 3)
    
    local hash = GetHashKey("HATES_PLAYER")
    SetPedRelationshipGroupHash(ped, hash)
    
    TaskCombatPed(ped, target, 0, 16)
    SetPedKeepTask(ped, true)
    
    if policeDispatchEnabled then
        SetPlayerWantedLevel(PlayerId(), 1, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
    end
end

Citizen.CreateThread(function()
    print("[NPC AGGRO] ^2=== SISTEM NPC AGGRO AKTIF ===^7")
    print("[NPC AGGRO] ^3Pukul atau tabrak NPC untuk memancing!^7")
    
    while true do
        Citizen.Wait(100)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        local handle, ped = FindFirstPed()
        local found = true
        
        while found do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped) and not aggroPeds[ped] then
                local dist = #(playerCoords - GetEntityCoords(ped))
                
                if dist < 30.0 then
                    local damaged = HasEntityBeenDamagedByEntity(ped, playerPed, true)
                    local vehicleDamage = vehicle ~= 0 and HasEntityBeenDamagedByEntity(ped, vehicle, true)
                    local hitByVehicle = vehicle ~= 0 and dist < 2.5 and GetEntitySpeed(vehicle) > 3.0
                    
                    if damaged or vehicleDamage or hitByVehicle then
                        ClearEntityLastDamageEntity(ped)
                        if vehicle ~= 0 then ClearEntityLastDamageEntity(vehicle) end
                        MakePedAggressive(ped, playerPed)
                    end
                end
            end
            found, ped = FindNextPed(handle)
        end
        EndFindPed(handle)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(50)
        for ped, _ in pairs(aggroPeds) do
            if DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                local health = GetEntityHealth(ped)
                if health < 200 and health > 0 then
                    SetEntityHealth(ped, 200)
                end
                
                local target = PlayerPedId()
                if not IsPedInCombat(ped) then
                    TaskCombatPed(ped, target, 0, 16)
                end
            else
                aggroPeds[ped] = nil
            end
        end
    end
end)

RegisterCommand('testnpc', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local fwd = GetEntityForwardVector(playerPed)
    local spawnCoords = coords + fwd * 3.0
    
    local model = GetHashKey("a_m_m_business_01")
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end
    
    local ped = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, false)
    SetModelAsNoLongerNeeded(model)
    
    Citizen.Wait(500)
    MakePedAggressive(ped, playerPed)
    
    print("[NPC AGGRO] ^2Test NPC spawned dan marah!^7")
end, false)

RegisterCommand('npcaggro', function()
    local count = 0
    for _ in pairs(aggroPeds) do count = count + 1 end
    print("[NPC AGGRO] NPC agresif aktif: " .. count)
end, false)
