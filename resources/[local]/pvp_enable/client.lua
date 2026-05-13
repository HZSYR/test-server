Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        SetCanAttackFriendly(PlayerPedId(), true, false)
        NetworkSetFriendlyFireOption(true)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for _, playerId in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(playerId)
            if ped ~= PlayerPedId() then
                SetPedCanBeTargetted(ped, true)
                SetPedCanBeTargettedByPlayer(ped, PlayerId(), true)
                SetEntityCanBeDamaged(ped, true)
            end
        end
    end
end)

print("[PVP] ^2Player vs Player ENABLED!^7")
