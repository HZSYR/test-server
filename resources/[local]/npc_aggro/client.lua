local aggroPeds = {}

local weaponList = {
    "WEAPON_PISTOL", "WEAPON_COMBATPISTOL", "WEAPON_PISTOL50",
    "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_ASSAULTSMG",
    "WEAPON_ASSAULTRIFLE", "WEAPON_CARBINERIFLE", "WEAPON_COMPACTRIFLE",
    "WEAPON_PUMPSHOTGUN", "WEAPON_SAWNOFFSHOTGUN",
    "WEAPON_BAT", "WEAPON_CROWBAR", "WEAPON_KNIFE", "WEAPON_MACHETE"
}

local function GiveRandomWeapon(ped)
    local weaponName = weaponList[math.random(#weaponList)]
    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(ped, weaponHash, 9999, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
    return weaponName
end

local function MakePedAggro(ped)
    if not DoesEntityExist(ped) then return end
    if IsPedAPlayer(ped) then return end
    if aggroPeds[ped] then return end
    
    local playerPed = PlayerPedId()
    aggroPeds[ped] = true
    
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 256)
        Wait(800)
    end
    
    ClearPedTasksImmediately(ped)
    
    SetPedMaxHealth(ped, 300)
    SetEntityHealth(ped, 300)
    SetPedArmour(ped, 50)
    SetPedCanRagdoll(ped, false)
    
    local weapon = GiveRandomWeapon(ped)
    print("[NPC AGGRO] ^1NPC MARAH!^7 Senjata: " .. weapon)
    
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAttributes(ped, 1, true)
    SetPedCombatAttributes(ped, 2, true)
    SetPedCombatAttributes(ped, 3, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 17, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 52, true)
    
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 50)
    SetPedSeeingRange(ped, 100.0)
    SetPedHearingRange(ped, 100.0)
    SetPedAlertness(ped, 3)
    
    local relGroup = GetHashKey("HATES_PLAYER")
    SetPedRelationshipGroupHash(ped, relGroup)
    SetRelationshipBetweenGroups(5, relGroup, GetHashKey("PLAYER"))
    
    TaskCombatPed(ped, playerPed, 0, 16)
    SetPedKeepTask(ped, true)
    
    SetPlayerWantedLevel(PlayerId(), 1, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
end

Citizen.CreateThread(function()
    print("^2==========================================^7")
    print("^2   NPC AGGRO SYSTEM - AKTIF!             ^7")
    print("^3   Pukul atau tabrak NPC = NPC MARAH!    ^7")
    print("^2==========================================^7")
    
    local relGroup = GetHashKey("HATES_PLAYER")
    AddRelationshipGroup("HATES_PLAYER")
    SetRelationshipBetweenGroups(5, relGroup, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), relGroup)
end)

Citizen.CreateThread(function()
    while true do
        Wait(50)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        for ped in EnumeratePeds() do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped) and not aggroPeds[ped] then
                local dist = #(playerCoords - GetEntityCoords(ped))
                
                if dist < 25.0 then
                    local isDamaged = HasEntityBeenDamagedByEntity(ped, playerPed, true)
                    local isVehicleDamage = vehicle ~= 0 and HasEntityBeenDamagedByEntity(ped, vehicle, true)
                    
                    if isDamaged or isVehicleDamage then
                        ClearEntityLastDamageEntity(ped)
                        if vehicle ~= 0 then ClearEntityLastDamageEntity(vehicle) end
                        MakePedAggro(ped)
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(100)
        local playerPed = PlayerPedId()
        
        for ped, _ in pairs(aggroPeds) do
            if DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                if GetEntityHealth(ped) < 150 then
                    SetEntityHealth(ped, 150)
                end
                
                if not IsPedInCombat(ped) then
                    TaskCombatPed(ped, playerPed, 0, 16)
                end
            else
                aggroPeds[ped] = nil
            end
        end
    end
end)

function EnumeratePeds()
    return coroutine.wrap(function()
        local handle, ped = FindFirstPed()
        local success
        repeat
            if ped ~= 0 then coroutine.yield(ped) end
            success, ped = FindNextPed(handle)
        until not success
        EndFindPed(handle)
    end)
end

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
