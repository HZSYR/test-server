-- ============================================
-- PLAYER MENU - Server Side
-- By Kapuyuak
-- ============================================

local currentWeather = 'CLEAR'
local currentHour = 12

-- ============================================
-- WEATHER SYNC
-- ============================================

RegisterNetEvent('player_menu:setWeather')
AddEventHandler('player_menu:setWeather', function(weather)
    currentWeather = weather
    TriggerClientEvent('player_menu:syncWeather', -1, weather)
end)

-- ============================================
-- TIME SYNC
-- ============================================

RegisterNetEvent('player_menu:setTime')
AddEventHandler('player_menu:setTime', function(hour)
    currentHour = hour
    TriggerClientEvent('player_menu:syncTime', -1, hour)
end)

-- ============================================
-- PLAYER ACTIONS
-- ============================================

RegisterNetEvent('player_menu:getPlayerCoords')
AddEventHandler('player_menu:getPlayerCoords', function(targetId)
    local src = source
    local targetPed = GetPlayerPed(targetId)
    if targetPed then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('player_menu:teleportTo', src, coords)
    end
end)

RegisterNetEvent('player_menu:spectate')
AddEventHandler('player_menu:spectate', function(targetId)
    local src = source
    TriggerClientEvent('player_menu:doSpectate', src, targetId)
end)

-- ============================================
-- SYNC ON JOIN
-- ============================================

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    Wait(1000)
    TriggerClientEvent('player_menu:syncWeather', src, currentWeather)
    TriggerClientEvent('player_menu:syncTime', src, currentHour)
end)
