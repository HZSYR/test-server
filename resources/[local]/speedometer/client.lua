local showSpeedometer = false
local currentVehicle = 0

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        
        if inVehicle then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= currentVehicle then
                currentVehicle = vehicle
                showSpeedometer = true
                SendNUIMessage({action = "show"})
            end
        else
            if showSpeedometer then
                showSpeedometer = false
                currentVehicle = 0
                SendNUIMessage({action = "hide"})
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(50)
        if showSpeedometer and currentVehicle ~= 0 then
            local speed = GetEntitySpeed(currentVehicle) * 3.6
            local rpm = GetVehicleCurrentRpm(currentVehicle)
            local gear = GetVehicleCurrentGear(currentVehicle)
            local health = GetVehicleEngineHealth(currentVehicle)
            local fuel = GetVehicleFuelLevel(currentVehicle)
            local maxSpeed = GetVehicleEstimatedMaxSpeed(currentVehicle) * 3.6
            
            local vehicleClass = GetVehicleClass(currentVehicle)
            local isBike = vehicleClass == 8
            local isBoat = vehicleClass == 14
            local isPlane = vehicleClass == 15 or vehicleClass == 16
            
            SendNUIMessage({
                action = "update",
                speed = math.floor(speed),
                rpm = rpm,
                gear = gear,
                health = math.floor(health / 10),
                fuel = math.floor(fuel),
                maxSpeed = math.floor(maxSpeed),
                isBike = isBike,
                isBoat = isBoat,
                isPlane = isPlane
            })
        end
    end
end)
