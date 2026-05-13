AddEventHandler('playerSpawned', function()
    local src = source
    TriggerClientEvent('weapon_loadout:give', src)
end)

RegisterCommand('giveweapons', function(source, args)
    local target = tonumber(args[1]) or source
    TriggerClientEvent('weapon_loadout:give', target)
    print(("[WEAPONS] Senjata diberikan ke player %d"):format(target))
end, true)

print("^2[WEAPON LOADOUT] Server ready!^7")
