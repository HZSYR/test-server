local weapons = {
    `WEAPON_PISTOL`, `WEAPON_COMBATPISTOL`, `WEAPON_PISTOL50`,
    `WEAPON_MICROSMG`, `WEAPON_SMG`, `WEAPON_ASSAULTSMG`,
    `WEAPON_ASSAULTRIFLE`, `WEAPON_CARBINERIFLE`, `WEAPON_COMPACTRIFLE`,
    `WEAPON_PUMPSHOTGUN`, `WEAPON_SAWNOFFSHOTGUN`,
    `WEAPON_BAT`, `WEAPON_CROWBAR`, `WEAPON_KNIFE`, `WEAPON_MACHETE`,
    `WEAPON_SWITCHBLADE`, `WEAPON_HAMMER`, `WEAPON_HATCHET`
}

local aggroPeds = {}
local policeDispatchEnabled = true

local function GetRandomWeapon()
    return weapons[math.random(1, #weapons)]
end

local function MakePedAggressive(ped, target)
    if not DoesEntityExist(ped) then return end
    if IsPedAPlayer(ped) then return end
    if aggroPeds[ped] then return end
    
    aggroPeds[ped] = true
    
    SetPedMaxHealth(ped, 500)
    SetEntityHealth(ped, 500)
    
    local weapon = GetRandomWeapon()
    GiveWeaponToPed(ped, weapon, 999, false, true)
    SetCurrentPedWeapon(ped, weapon, true)
    
    ClearPedTasks(ped)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 60)
    
    SetPedAsEnemy(ped, true)
    SetPedRelationshipGroupHash(ped, `HATES_PLAYER`)
    
    TaskCombatPed(ped, target, 0, 16)
    
    if policeDispatchEnabled then
        local coords = GetEntityCoords(ped)
        SetPlayerWantedLevel(PlayerId(), 1, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        
        CreateThread(function()
            Wait(3000)
            local x, y, z = table.unpack(coords)
            local blip = AddBlipForCoord(x, y, z)
            SetBlipSprite(blip, 161)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Keributan")
            EndTextCommandSetBlipName(blip)
            
            Wait(30000)
            RemoveBlip(blip)
        end)
    end
end

local function CheckPedDamage()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local peds = {}
    local handle, ped = FindFirstPed()
    local success = true
    
    repeat
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            table.insert(peds, ped)
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)
    
    for _, npc in ipairs(peds) do
        if DoesEntityExist(npc) and not IsPedDeadOrDying(npc) then
            if HasEntityBeenDamagedByEntity(npc, playerPed, true) then
                ClearEntityLastDamageEntity(npc)
                MakePedAggressive(npc, playerPed)
            end
            
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle ~= 0 then
                if HasEntityBeenDamagedByEntity(npc, vehicle, true) then
                    ClearEntityLastDamageEntity(npc)
                    MakePedAggressive(npc, playerPed)
                end
            end
        end
    end
end

local function CleanupDeadPeds()
    for ped, _ in pairs(aggroPeds) do
        if not DoesEntityExist(ped) or IsPedDeadOrDying(ped) then
            aggroPeds[ped] = nil
        end
    end
end

CreateThread(function()
    SetRelationshipBetweenGroups(5, `HATES_PLAYER`, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, `HATES_PLAYER`)
    
    while true do
        Wait(500)
        CheckPedDamage()
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        CleanupDeadPeds()
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        for ped, _ in pairs(aggroPeds) do
            if DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
                local health = GetEntityHealth(ped)
                if health < 150 and health > 0 then
                    SetEntityHealth(ped, 150)
                end
            end
        end
        Wait(100)
    end
end)

RegisterCommand('npcaggro', function()
    local count = 0
    for _ in pairs(aggroPeds) do count = count + 1 end
    TriggerEvent('chat:addMessage', {
        color = {255, 100, 100},
        args = {'[NPC AGGRO]', ('NPC agresif aktif: %d'):format(count)}
    })
end, false)

RegisterCommand('policetoggle', function()
    policeDispatchEnabled = not policeDispatchEnabled
    TriggerEvent('chat:addMessage', {
        color = {100, 150, 255},
        args = {'[POLICE]', policeDispatchEnabled and 'Polisi AKTIF' or 'Polisi NONAKTIF'}
    })
end, false)
