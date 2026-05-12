--[[
    AUTO UPDATER v2.0 - Optimized Hot Reload
    Lightweight & High Performance
]]

local SCAN_INTERVAL = 60000  -- 60 detik (hemat CPU)
local ADMIN_ACE = "command.refresh"

local knownRes = {}
local scanning = false
local resCount = 0

local function Log(msg)
    print(("[^3AUTO-UPDATE^7] %s"):format(msg))
end

local function Notify(msg)
    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 165, 0},
        args = {"[UPDATE]", msg}
    })
end

local function IsAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, ADMIN_ACE)
end

local function GetResources()
    local res, num = {}, GetNumResources()
    for i = 0, num - 1 do
        local name = GetResourceByFindIndex(i)
        if name then res[name] = GetResourceState(name) end
    end
    return res
end

local function Scan()
    if scanning then return {} end
    scanning = true
    
    ExecuteCommand("refresh")
    Wait(500)
    
    local new = {}
    for name, state in pairs(GetResources()) do
        if not knownRes[name] then
            knownRes[name] = true
            resCount = resCount + 1
            new[#new + 1] = name
            if state == "stopped" then
                ExecuteCommand("ensure " .. name)
                Log(("^2Started:^7 %s"):format(name))
                Notify("Resource baru: " .. name)
            end
        end
    end
    
    scanning = false
    return new
end

local function Init()
    for name in pairs(GetResources()) do
        knownRes[name] = true
        resCount = resCount + 1
    end
    Log(("^2Ready^7 - Tracking %d resources"):format(resCount))
end

CreateThread(function()
    Init()
    while true do
        Wait(SCAN_INTERVAL)
        Scan()
    end
end)

RegisterCommand("autoscan", function(src)
    if not IsAdmin(src) then return end
    local new = Scan()
    local msg = #new > 0 and ("Found: " .. table.concat(new, ", ")) or "No new resources"
    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, {color = {0, 255, 0}, args = {"[UPDATE]", msg}})
    end
    Log(msg)
end, false)

RegisterCommand("autorefresh", function(src)
    if not IsAdmin(src) then return end
    ExecuteCommand("refresh")
    Notify("Resources refreshed")
    Log("^2Refreshed^7")
end, false)

RegisterCommand("autostatus", function(src)
    if not IsAdmin(src) then return end
    local msg = ("Tracking %d resources | Interval: %ds"):format(resCount, SCAN_INTERVAL / 1000)
    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, {color = {0, 255, 255}, args = {"[UPDATE]", msg}})
    end
    Log(msg)
end, false)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() and not knownRes[res] then
        knownRes[res] = true
        resCount = resCount + 1
    end
end)
