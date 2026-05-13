local Config = {
    scanInterval = 30,
    fileCheckInterval = 15,
    healthCheckInterval = 120,
    startDelay = 1000,
    autoStart = true,
    autoReload = true,
    autoRestart = true,
    healthCheck = true,
    fileWatcher = true,
    notifyPlayers = true,
    discordWebhook = false,
    webhookUrl = "",
    blacklist = {
        "auto_updater", "monitor", "sessionmanager", 
        "spawnmanager", "mapmanager", "hardcap",
        "yarn", "webpack", "chat", "basic-gamemode",
        "rconlog", "fivem-map-hipster"
    },
    watchFiles = {
        "fxmanifest.lua", "__resource.lua",
        "server.lua", "client.lua", "shared.lua", 
        "config.lua", "config.js", "config.json"
    },
    maxLogEntries = 50,
    debugMode = false
}

local State = {
    resources = {},
    fileHashes = {},
    queue = {},
    logs = {},
    stats = {
        started = 0,
        reloaded = 0,
        errors = 0,
        filesChanged = 0,
        lastScan = 0,
        lastFileCheck = 0
    },
    scanning = false,
    fileChecking = false,
    paused = false,
    initialized = false,
    startTime = os.time()
}

local function Log(msg, level)
    level = level or "INFO"
    local colors = {INFO = "^7", SUCCESS = "^2", WARNING = "^3", ERROR = "^1", DEBUG = "^5"}
    local timestamp = os.date("%H:%M:%S")
    print(("[^3AUTO-UPDATER^7] [%s] %s%s^7"):format(timestamp, colors[level] or "^7", msg))
    if #State.logs >= Config.maxLogEntries then table.remove(State.logs, 1) end
    table.insert(State.logs, {time = timestamp, level = level, message = msg})
end

local function IsBlacklisted(name)
    for _, b in ipairs(Config.blacklist) do
        if name == b then return true end
    end
    return false
end

local function NotifyPlayers(msg, msgType)
    if not Config.notifyPlayers then return end
    local colors = {
        info = {100, 150, 255}, success = {0, 255, 100},
        warning = {255, 200, 0}, error = {255, 50, 50}
    }
    TriggerClientEvent('chat:addMessage', -1, {
        color = colors[msgType] or colors.info,
        args = {"[🔄 AUTO-UPDATE]", msg}
    })
end

local function SendDiscord(title, message, color)
    if not Config.discordWebhook or Config.webhookUrl == "" then return end
    PerformHttpRequest(Config.webhookUrl, function() end, 'POST', 
        json.encode({embeds = {{
            title = title, description = message, color = color or 3447003,
            footer = {text = "SCRT Auto Updater | " .. os.date("%Y-%m-%d %H:%M:%S")}
        }}}), 
        {['Content-Type'] = 'application/json'}
    )
end

local function FormatUptime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return ("%02d:%02d:%02d"):format(h, m, s)
end

local function SimpleHash(str)
    if not str then return "0" end
    local hash = 5381
    local len = math.min(#str, 50000)
    for i = 1, len do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    return tostring(hash)
end

local function GetFileSignature(resourceName)
    local sig = {}
    for _, file in ipairs(Config.watchFiles) do
        local content = LoadResourceFile(resourceName, file)
        if content then sig[file] = SimpleHash(content) end
    end
    return next(sig) and sig or nil
end

local function CheckResourceFileChanges(resourceName)
    local newSig = GetFileSignature(resourceName)
    if not newSig then return false, nil end
    
    local oldSig = State.fileHashes[resourceName]
    if not oldSig then
        State.fileHashes[resourceName] = newSig
        return false, nil
    end
    
    local changedFiles = {}
    for file, hash in pairs(newSig) do
        if oldSig[file] and oldSig[file] ~= hash then
            table.insert(changedFiles, file)
        elseif not oldSig[file] then
            table.insert(changedFiles, file .. " (new)")
        end
    end
    
    if #changedFiles > 0 then
        State.fileHashes[resourceName] = newSig
        return true, changedFiles
    end
    return false, nil
end

local function GetAllResources()
    local resources = {}
    local numRes = GetNumResources()
    for i = 0, numRes - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            resources[name] = {
                state = GetResourceState(name),
                version = GetResourceMetadata(name, 'version', 0) or "1.0"
            }
        end
    end
    return resources
end

local function CountResources()
    local counts = {total = 0, started = 0, stopped = 0}
    for name, data in pairs(State.resources) do
        counts.total = counts.total + 1
        if data.state == "started" then counts.started = counts.started + 1
        else counts.stopped = counts.stopped + 1 end
    end
    return counts
end

local function ProcessQueue()
    if #State.queue == 0 then return end
    local item = table.remove(State.queue, 1)
    if item then
        local state = GetResourceState(item)
        if state == "stopped" or state == "uninitialized" then
            ExecuteCommand("ensure " .. item)
            State.stats.started = State.stats.started + 1
            Log(("Auto started: ^2%s^7"):format(item), "SUCCESS")
            NotifyPlayers(("Resource %s di-start otomatis"):format(item), "success")
            SendDiscord("📦 Resource Started", ("Resource **%s** di-start otomatis"):format(item), 3066993)
        end
    end
end

local function ScanForResources()
    if State.scanning or State.paused then return {} end
    State.scanning = true
    State.stats.lastScan = os.time()
    
    local currentResources = GetAllResources()
    local newResources = {}
    local count = 0
    
    for name, meta in pairs(currentResources) do
        count = count + 1
        if not State.resources[name] then
            State.resources[name] = {
                state = meta.state,
                version = meta.version,
                firstSeen = os.time(),
                lastCheck = os.time(),
                errors = 0
            }
            if not IsBlacklisted(name) then
                table.insert(newResources, name)
                State.fileHashes[name] = GetFileSignature(name)
                if Config.autoStart and (meta.state == "stopped" or meta.state == "uninitialized") then
                    table.insert(State.queue, name)
                    Log(("New resource queued: ^2%s^7"):format(name), "SUCCESS")
                end
            end
        else
            State.resources[name].state = meta.state
            State.resources[name].lastCheck = os.time()
        end
        if count % 20 == 0 then Wait(0) end
    end
    
    if #newResources > 0 then
        local msg = ("Ditemukan %d resource baru: %s"):format(#newResources, table.concat(newResources, ", "))
        Log(msg, "SUCCESS")
        NotifyPlayers(msg, "success")
        SendDiscord("📦 Resource Baru", msg, 3066993)
    end
    
    State.scanning = false
    return newResources
end

local function CheckAllFileChanges()
    if State.fileChecking or State.paused or not Config.fileWatcher then return {} end
    State.fileChecking = true
    State.stats.lastFileCheck = os.time()
    
    local changedResources = {}
    local count = 0
    
    for name, data in pairs(State.resources) do
        if data.state == "started" and not IsBlacklisted(name) then
            local hasChanges, files = CheckResourceFileChanges(name)
            if hasChanges then
                table.insert(changedResources, {name = name, files = files})
                State.stats.filesChanged = State.stats.filesChanged + 1
                Log(("File changed: ^3%s^7 (%s)"):format(name, table.concat(files, ", ")), "WARNING")
                if Config.autoReload then
                    ExecuteCommand("ensure " .. name)
                    State.stats.reloaded = State.stats.reloaded + 1
                    Log(("Auto reloaded: ^2%s^7"):format(name), "SUCCESS")
                    NotifyPlayers(("Resource %s di-reload (file berubah)"):format(name), "warning")
                    SendDiscord("📝 File Changed", ("Resource **%s** di-reload\nFiles: %s"):format(name, table.concat(files, ", ")), 16776960)
                end
            end
        end
        count = count + 1
        if count % 10 == 0 then Wait(0) end
    end
    
    State.fileChecking = false
    return changedResources
end

local function HealthCheck()
    if State.paused or not Config.healthCheck then return end
    local issues = {}
    local count = 0
    
    for name, data in pairs(State.resources) do
        if not IsBlacklisted(name) then
            local currentState = GetResourceState(name)
            if data.state == "started" and currentState == "stopped" then
                data.errors = (data.errors or 0) + 1
                table.insert(issues, name)
                if Config.autoRestart and data.errors <= 3 then
                    Log(("Resource crashed, restarting: ^1%s^7 (attempt %d/3)"):format(name, data.errors), "ERROR")
                    ExecuteCommand("ensure " .. name)
                    NotifyPlayers(("Resource %s crash, restarting..."):format(name), "error")
                end
            end
            data.state = currentState
        end
        count = count + 1
        if count % 20 == 0 then Wait(0) end
    end
    return issues
end

local function RefreshResources(name)
    if name and name ~= "" then
        if GetResourceState(name) ~= "missing" then
            ExecuteCommand("ensure " .. name)
            Log(("Refreshed: ^2%s^7"):format(name), "SUCCESS")
            return true
        end
        return false
    else
        local count = 0
        for resName, data in pairs(State.resources) do
            if not IsBlacklisted(resName) and data.state == "started" then
                ExecuteCommand("ensure " .. resName)
                count = count + 1
                Wait(100)
            end
        end
        Log(("Refreshed ^2%d^7 resources"):format(count), "SUCCESS")
        return true, count
    end
end

CreateThread(function()
    Wait(3000)
    Log("═══════════════════════════════════════════════")
    Log("   AUTO UPDATER v5.0 - SMART & SAFE EDITION")
    Log("═══════════════════════════════════════════════")
    
    local numRes = GetNumResources()
    local count = 0
    
    for i = 0, numRes - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            State.resources[name] = {
                state = GetResourceState(name),
                version = GetResourceMetadata(name, 'version', 0) or "1.0",
                firstSeen = os.time(),
                lastCheck = os.time(),
                errors = 0
            }
            if not IsBlacklisted(name) then
                State.fileHashes[name] = GetFileSignature(name)
            end
            count = count + 1
        end
        if i % 10 == 0 then Wait(0) end
    end
    
    local counts = CountResources()
    Log(("Tracking ^2%d^7 resources (%d active)"):format(counts.total, counts.started), "SUCCESS")
    Log(("Scan: ^3%d^7s | File check: ^3%d^7s"):format(Config.scanInterval, Config.fileCheckInterval))
    Log("═══════════════════════════════════════════════")
    Log("^2AUTO UPDATER v5.0 READY!^7", "SUCCESS")
    Log("═══════════════════════════════════════════════")
    
    State.initialized = true
    SendDiscord("🚀 Auto Updater Started", ("Monitoring %d resources"):format(counts.total), 3447003)
end)

CreateThread(function()
    Wait(8000)
    while true do
        Wait(Config.scanInterval * 1000)
        if State.initialized and not State.paused then ScanForResources() end
    end
end)

CreateThread(function()
    Wait(10000)
    Log("^3File Watcher started^7")
    while true do
        Wait(Config.fileCheckInterval * 1000)
        if State.initialized and not State.paused then CheckAllFileChanges() end
    end
end)

CreateThread(function()
    Wait(5000)
    while true do
        Wait(Config.startDelay)
        if State.initialized and not State.paused and #State.queue > 0 then ProcessQueue() end
    end
end)

CreateThread(function()
    Wait(15000)
    while true do
        Wait(Config.healthCheckInterval * 1000)
        if State.initialized and not State.paused then HealthCheck() end
    end
end)

RegisterCommand("autoscan", function(source)
    Log("Manual scan triggered...")
    local newRes = ScanForResources()
    local msg = #newRes > 0 and ("Found %d new resources: %s"):format(#newRes, table.concat(newRes, ", ")) or "No new resources found"
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {color = #newRes > 0 and {0, 255, 100} or {100, 200, 255}, args = {"[SCAN]", msg}})
    end
    Log(msg, #newRes > 0 and "SUCCESS" or "INFO")
end, false)

RegisterCommand("autorefresh", function(source, args)
    local name = args[1]
    local success, count = RefreshResources(name)
    local msg = name and (success and ("Refreshed: %s"):format(name) or ("Resource not found: %s"):format(name)) or ("Refreshed %d resources"):format(count or 0)
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {color = success and {0, 255, 100} or {255, 50, 50}, args = {"[REFRESH]", msg}})
    end
end, false)

RegisterCommand("autostatus", function(source)
    local counts = CountResources()
    local uptime = os.time() - State.startTime
    local info = {
        ("═══ AUTO UPDATER v5.0 STATUS ═══"),
        ("Uptime: %s"):format(FormatUptime(uptime)),
        ("Resources: %d total (%d active, %d stopped)"):format(counts.total, counts.started, counts.stopped),
        ("Queue: %d pending"):format(#State.queue),
        ("Stats: %d started, %d reloaded, %d file changes"):format(State.stats.started, State.stats.reloaded, State.stats.filesChanged),
        ("Last scan: %s | Last file check: %s"):format(os.date("%H:%M:%S", State.stats.lastScan), os.date("%H:%M:%S", State.stats.lastFileCheck)),
        ("Status: %s"):format(State.paused and "^1PAUSED^7" or "^2ACTIVE^7")
    }
    for _, line in ipairs(info) do
        if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {100, 200, 255}, args = {"[STATUS]", line}})
        else Log(line) end
    end
end, false)

RegisterCommand("autolist", function(source, args)
    local filter = args[1]
    local count = 0
    for name, data in pairs(State.resources) do
        if not filter or name:lower():find(filter:lower()) then
            local status = data.state == "started" and "^2●^7" or "^1○^7"
            local line = ("%s %s (v%s)"):format(status, name, data.version or "?")
            if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {200, 200, 200}, args = {"", line}})
            else Log(line) end
            count = count + 1
            if count >= 25 then
                if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {255, 200, 0}, args = {"", ("... dan %d lainnya"):format(CountResources().total - 25)}}) end
                break
            end
        end
    end
end, false)

RegisterCommand("autorestart", function(source, args)
    local name = args[1]
    if not name then
        if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {255, 50, 50}, args = {"[ERROR]", "Usage: /autorestart [resource_name]"}}) end
        return
    end
    if GetResourceState(name) ~= "missing" then
        ExecuteCommand("stop " .. name)
        Wait(500)
        ExecuteCommand("start " .. name)
        Log(("Restarted: ^2%s^7"):format(name), "SUCCESS")
        if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {0, 255, 100}, args = {"[RESTART]", ("Restarted: %s"):format(name)}}) end
    else
        if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {255, 50, 50}, args = {"[ERROR]", ("Resource not found: %s"):format(name)}}) end
    end
end, false)

RegisterCommand("autohealth", function(source)
    Log("Manual health check...")
    local issues = HealthCheck()
    local msg = #issues > 0 and ("Found %d issues: %s"):format(#issues, table.concat(issues, ", ")) or "All resources healthy"
    if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = #issues > 0 and {255, 200, 0} or {0, 255, 100}, args = {"[HEALTH]", msg}}) end
    Log(msg, #issues > 0 and "WARNING" or "SUCCESS")
end, false)

RegisterCommand("autolog", function(source, args)
    local count = tonumber(args[1]) or 10
    count = math.min(count, #State.logs)
    if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {100, 200, 255}, args = {"[LOG]", ("Last %d entries:"):format(count)}}) end
    for i = math.max(1, #State.logs - count + 1), #State.logs do
        local log = State.logs[i]
        local line = ("[%s] %s"):format(log.time, log.message)
        if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {200, 200, 200}, args = {"", line}})
        else print(line) end
    end
end, false)

RegisterCommand("autoconfig", function(source)
    local info = {
        ("scanInterval: %ds"):format(Config.scanInterval),
        ("fileCheckInterval: %ds"):format(Config.fileCheckInterval),
        ("autoStart: %s"):format(Config.autoStart),
        ("autoReload: %s"):format(Config.autoReload),
        ("autoRestart: %s"):format(Config.autoRestart),
        ("fileWatcher: %s"):format(Config.fileWatcher),
        ("notifyPlayers: %s"):format(Config.notifyPlayers)
    }
    for _, line in ipairs(info) do
        if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {100, 200, 255}, args = {"[CONFIG]", line}})
        else Log(line) end
    end
end, false)

RegisterCommand("autopause", function(source)
    State.paused = true
    local msg = "Auto scanning PAUSED"
    if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {255, 200, 0}, args = {"[PAUSE]", msg}}) end
    Log(msg, "WARNING")
end, false)

RegisterCommand("autoresume", function(source)
    State.paused = false
    local msg = "Auto scanning RESUMED"
    if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = {0, 255, 100}, args = {"[RESUME]", msg}}) end
    Log(msg, "SUCCESS")
end, false)

RegisterCommand("autofiles", function(source)
    Log("Manual file check...")
    local changed = CheckAllFileChanges()
    local msg = #changed > 0 and ("Detected changes in %d resources"):format(#changed) or "No file changes detected"
    if source > 0 then TriggerClientEvent('chat:addMessage', source, {color = #changed > 0 and {255, 200, 0} or {0, 255, 100}, args = {"[FILES]", msg}}) end
    Log(msg, #changed > 0 and "WARNING" or "SUCCESS")
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    if IsBlacklisted(resourceName) then return end
    if State.resources[resourceName] then
        State.resources[resourceName].state = "started"
        State.resources[resourceName].errors = 0
    end
    if State.initialized then Log(("Resource started: ^2%s^7"):format(resourceName), "SUCCESS") end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    if IsBlacklisted(resourceName) then return end
    if State.resources[resourceName] then State.resources[resourceName].state = "stopped" end
    if State.initialized then Log(("Resource stopped: ^1%s^7"):format(resourceName), "WARNING") end
end)

exports('GetStatus', function() return {paused = State.paused, stats = State.stats, resourceCount = CountResources()} end)
exports('ScanNow', function() return ScanForResources() end)
exports('RefreshResource', function(name) return RefreshResources(name) end)
exports('IsResourceTracked', function(name) return State.resources[name] ~= nil end)

RegisterNetEvent('auto_updater:requestData')
AddEventHandler('auto_updater:requestData', function()
    local src = source
    local counts = CountResources()
    TriggerClientEvent('auto_updater:updateData', src, {
        total = counts.total,
        active = counts.started,
        reloaded = State.stats.reloaded,
        paused = State.paused,
        logs = State.logs
    })
end)

RegisterNetEvent('auto_updater:scan')
AddEventHandler('auto_updater:scan', function()
    local src = source
    local newRes = ScanForResources()
    local msg = #newRes > 0 and ("Ditemukan %d resource baru"):format(#newRes) or "Tidak ada resource baru"
    TriggerClientEvent('auto_updater:notify', src, msg, #newRes > 0 and "success" or "info")
    Wait(500)
    TriggerEvent('auto_updater:requestData')
end)

RegisterNetEvent('auto_updater:refresh')
AddEventHandler('auto_updater:refresh', function(name)
    local src = source
    RefreshResources(name)
    TriggerClientEvent('auto_updater:notify', src, "Refresh selesai", "success")
    Wait(500)
    TriggerEvent('auto_updater:requestData')
end)

RegisterNetEvent('auto_updater:restart')
AddEventHandler('auto_updater:restart', function(name)
    local src = source
    if name and GetResourceState(name) ~= "missing" then
        ExecuteCommand("stop " .. name)
        Wait(500)
        ExecuteCommand("start " .. name)
        TriggerClientEvent('auto_updater:notify', src, ("Resource %s di-restart"):format(name), "success")
    end
end)

RegisterNetEvent('auto_updater:health')
AddEventHandler('auto_updater:health', function()
    local src = source
    local issues = HealthCheck()
    local msg = #issues > 0 and ("Ditemukan %d masalah"):format(#issues) or "Semua resource sehat"
    TriggerClientEvent('auto_updater:notify', src, msg, #issues > 0 and "warning" or "success")
    Wait(500)
    TriggerEvent('auto_updater:requestData')
end)

RegisterNetEvent('auto_updater:pause')
AddEventHandler('auto_updater:pause', function()
    local src = source
    State.paused = true
    Log("Auto scan di-PAUSE", "WARNING")
    TriggerClientEvent('auto_updater:notify', src, "Auto scan di-pause", "warning")
    Wait(200)
    TriggerEvent('auto_updater:requestData')
end)

RegisterNetEvent('auto_updater:resume')
AddEventHandler('auto_updater:resume', function()
    local src = source
    State.paused = false
    Log("Auto scan DILANJUTKAN", "SUCCESS")
    TriggerClientEvent('auto_updater:notify', src, "Auto scan dilanjutkan", "success")
    Wait(200)
    TriggerEvent('auto_updater:requestData')
end)

RegisterNetEvent('auto_updater:filecheck')
AddEventHandler('auto_updater:filecheck', function()
    local src = source
    local changed = CheckAllFileChanges()
    local msg = #changed > 0 and ("Ditemukan %d file berubah"):format(#changed) or "Tidak ada perubahan file"
    TriggerClientEvent('auto_updater:notify', src, msg, #changed > 0 and "warning" or "success")
    Wait(500)
    TriggerEvent('auto_updater:requestData')
end)

Log("^3Auto Updater v5.0 loaded^7")
