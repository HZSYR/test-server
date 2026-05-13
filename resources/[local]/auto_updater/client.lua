local menuOpen = false

RegisterKeyMapping('openautopdater', 'Buka Menu Auto Updater', 'keyboard', 'F3')

RegisterCommand('openautopdater', function()
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    SendNUIMessage({action = "toggle", show = menuOpen})
    if menuOpen then
        TriggerServerEvent('auto_updater:requestData')
    end
end, false)

RegisterNUICallback('close', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('scan', function(data, cb)
    TriggerServerEvent('auto_updater:scan')
    cb('ok')
end)

RegisterNUICallback('refresh', function(data, cb)
    TriggerServerEvent('auto_updater:refresh', data.name)
    cb('ok')
end)

RegisterNUICallback('restart', function(data, cb)
    TriggerServerEvent('auto_updater:restart', data.name)
    cb('ok')
end)

RegisterNUICallback('health', function(data, cb)
    TriggerServerEvent('auto_updater:health')
    cb('ok')
end)

RegisterNUICallback('pause', function(data, cb)
    TriggerServerEvent('auto_updater:pause')
    cb('ok')
end)

RegisterNUICallback('resume', function(data, cb)
    TriggerServerEvent('auto_updater:resume')
    cb('ok')
end)

RegisterNUICallback('filecheck', function(data, cb)
    TriggerServerEvent('auto_updater:filecheck')
    cb('ok')
end)

RegisterNetEvent('auto_updater:updateData')
AddEventHandler('auto_updater:updateData', function(data)
    SendNUIMessage({action = "updateData", data = data})
end)

RegisterNetEvent('auto_updater:notify')
AddEventHandler('auto_updater:notify', function(msg, msgType)
    SendNUIMessage({action = "notify", message = msg, type = msgType})
end)
