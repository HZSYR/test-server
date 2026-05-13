local allWeapons = {
    -- Pistols
    "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
    "WEAPON_STUNGUN", "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_SNSPISTOL_MK2",
    "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL", "WEAPON_FLAREGUN", "WEAPON_MARKSMANPISTOL",
    "WEAPON_REVOLVER", "WEAPON_REVOLVER_MK2", "WEAPON_DOUBLEACTION", "WEAPON_RAYPISTOL",
    "WEAPON_CERAMICPISTOL", "WEAPON_NAVYREVOLVER", "WEAPON_GADGETPISTOL",
    
    -- SMGs
    "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
    "WEAPON_COMBATPDW", "WEAPON_MACHINEPISTOL", "WEAPON_MINISMG", "WEAPON_RAYCARBINE",
    
    -- Shotguns
    "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN",
    "WEAPON_ASSAULTSHOTGUN", "WEAPON_BULLPUPSHOTGUN", "WEAPON_MUSKET",
    "WEAPON_HEAVYSHOTGUN", "WEAPON_DBSHOTGUN", "WEAPON_AUTOSHOTGUN", "WEAPON_COMBATSHOTGUN",
    
    -- Assault Rifles
    "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE",
    "WEAPON_CARBINERIFLE_MK2", "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE",
    "WEAPON_SPECIALCARBINE_MK2", "WEAPON_BULLPUPRIFLE", "WEAPON_BULLPUPRIFLE_MK2",
    "WEAPON_COMPACTRIFLE", "WEAPON_MILITARYRIFLE", "WEAPON_HEAVYRIFLE", "WEAPON_TACTICALRIFLE",
    
    -- Machine Guns
    "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
    
    -- Sniper Rifles
    "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2",
    "WEAPON_MARKSMANRIFLE", "WEAPON_MARKSMANRIFLE_MK2", "WEAPON_PRECISIONRIFLE",
    
    -- Heavy Weapons
    "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_GRENADELAUNCHER_SMOKE",
    "WEAPON_MINIGUN", "WEAPON_FIREWORK", "WEAPON_RAILGUN", "WEAPON_HOMINGLAUNCHER",
    "WEAPON_COMPACTLAUNCHER", "WEAPON_RAYMINIGUN", "WEAPON_EMPLAUNCHER",
    
    -- Throwables
    "WEAPON_GRENADE", "WEAPON_BZGAS", "WEAPON_SMOKEGRENADE", "WEAPON_FLARE",
    "WEAPON_MOLOTOV", "WEAPON_STICKYBOMB", "WEAPON_PROXMINE", "WEAPON_SNOWBALL",
    "WEAPON_PIPEBOMB", "WEAPON_BALL",
    
    -- Melee
    "WEAPON_KNIFE", "WEAPON_NIGHTSTICK", "WEAPON_HAMMER", "WEAPON_BAT",
    "WEAPON_GOLFCLUB", "WEAPON_CROWBAR", "WEAPON_BOTTLE", "WEAPON_DAGGER",
    "WEAPON_HATCHET", "WEAPON_MACHETE", "WEAPON_FLASHLIGHT", "WEAPON_SWITCHBLADE",
    "WEAPON_POOLCUE", "WEAPON_WRENCH", "WEAPON_BATTLEAXE", "WEAPON_STONE_HATCHET"
}

local function GiveAllWeapons(ped)
    for _, weapon in ipairs(allWeapons) do
        local hash = GetHashKey(weapon)
        GiveWeaponToPed(ped, hash, 9999, false, false)
        SetPedInfiniteAmmo(ped, true, hash)
    end
    SetPedInfiniteAmmoClip(PlayerPedId(), true)
end

local hasWeapons = false

RegisterNetEvent('weapon_loadout:give')
AddEventHandler('weapon_loadout:give', function()
    GiveAllWeapons(PlayerPedId())
    hasWeapons = true
end)

AddEventHandler('playerSpawned', function()
    Wait(1000)
    GiveAllWeapons(PlayerPedId())
    hasWeapons = true
    print("^2[WEAPONS] Senjata diberikan saat spawn!^7")
end)

Citizen.CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        
        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped) then
            if not hasWeapons then
                GiveAllWeapons(ped)
                hasWeapons = true
                print("^2[WEAPONS] Senjata diberikan (auto-check)!^7")
            end
            
            SetPedInfiniteAmmoClip(ped, true)
        end
        
        if IsPedDeadOrDying(ped) then
            hasWeapons = false
        end
    end
end)

RegisterCommand('weapons', function()
    GiveAllWeapons(PlayerPedId())
    print("^2[WEAPONS] Semua senjata diberikan!^7")
end, false)

print("^2[WEAPON LOADOUT] Sistem senjata lengkap aktif!^7")
