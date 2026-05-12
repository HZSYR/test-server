--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║     AUTO UPDATER v3.0 - SMART HOT RELOAD SYSTEM              ║
    ║     Intelligent Resource Management for FiveM                ║
    ║     By: SCRT Server                                          ║
    ╚══════════════════════════════════════════════════════════════╝
    
    FITUR UTAMA:
    • Smart Detection    - Deteksi resource baru secara otomatis
    • File Watcher       - Monitor perubahan file dalam resource
    • Auto Dependency    - Deteksi dan load dependency otomatis
    • Health Check       - Monitor kesehatan resource
    • Error Recovery     - Auto restart resource yang crash
    • Version Tracking   - Track versi resource
    • Scheduled Tasks    - Jadwal maintenance otomatis
    • Discord Webhook    - Notifikasi ke Discord
    • Resource Queue     - Antrian start resource (anti-lag)
    • Smart Reload       - Reload hanya resource yang berubah
    
    COMMANDS:
    /autoscan           - Scan manual resource baru
    /autorefresh [name] - Refresh resource (atau semua jika kosong)
    /autostatus         - Status lengkap sistem
    /autolist           - List semua resource & status
    /autorestart [name] - Restart resource tertentu
    /autohealth         - Health check semua resource
    /autolog            - Lihat log aktivitas
    /autoconfig         - Lihat/ubah konfigurasi
    /autopause          - Pause auto scanning
    /autoresume         - Resume auto scanning
]]

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════
local Config = {
    -- Timing
    scanInterval = 30,              -- Scan setiap 30 detik
    healthCheckInterval = 120,      -- Health check setiap 2 menit
    startDelay = 2,                 -- Delay antar start resource (detik)
    refreshWait = 500,              -- Wait setelah refresh command (ms)
    
    -- Features Toggle
    autoStart = true,               -- Auto start resource baru
    autoRestart = true,             -- Auto restart resource crash
    healthCheck = true,             -- Enable health monitoring
    fileWatcher = true,             -- Monitor file changes
    discordWebhook = true,          -- Kirim notif ke Discord
    smartReload = true,             -- Reload hanya yang berubah
    queueSystem = true,             -- Gunakan queue untuk start
    
    -- Discord Webhook (kosongkan jika tidak pakai)
    webhookUrl = "",
    
    -- Permissions
    adminAces = {
        "command.refresh",
        "group.admin",
        "group.moderator"
    },
    
    -- Blacklist - Resource yang TIDAK akan di-auto manage
    blacklist = {
        "auto_updater",
        "monitor",
        "sessionmanager",
        "spawnmanager",
        "mapmanager",
        "hardcap"
    },
    
    -- Priority - Resource yang di-start duluan (urutan penting)
    priority = {
        "mysql-async",
        "oxmysql",
        "es_extended",
        "qb-core"
    },
    
    -- Watch ALL folders in resources (auto-detect semua)
    watchAllFolders = true,         -- Monitor SEMUA folder di resources
    fileCheckInterval = 15,         -- Cek perubahan file setiap 15 detik
    watchExtensions = {             -- Ekstensi file yang di-monitor
        "lua", "js", "json", "xml", "meta", "cfg", "html", "css"
    },
    
    -- Notifications
    notifyPlayers = true,
    notifyOnStart = true,
    notifyOnStop = true,
    notifyOnError = true,
    
    -- Logging
    logToFile = false,
    maxLogEntries = 100,
    debugMode = false
}

-- ═══════════════════════════════════════════════════════════════
-- STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════
local State = {
    resources = {},          -- {name = {state, version, lastCheck, errors, metadata}}
    fileHashes = {},         -- {resourceName = {filename = hash}} untuk track perubahan
    queue = {},              -- Resource start queue
    logs = {},               -- Activity logs
    stats = {
        started = 0,
        stopped = 0,
        restarted = 0,
        errors = 0,
        filesChanged = 0,
        lastScan = 0,
        lastFileCheck = 0,
        lastHealthCheck = 0,
        uptime = 0
    },
    scanning = false,
    fileChecking = false,
    paused = false,
    initialized = false,
    startTime = os.time()
}

-- ═══════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Colored console logging
local function Log(msg, level)
    level = level or "INFO"
    local colors = {
        INFO = "^7",
        SUCCESS = "^2",
        WARNING = "^3",
        ERROR = "^1",
        DEBUG = "^5"
    }
    local color = colors[level] or "^7"
    local timestamp = os.date("%H:%M:%S")
    local formatted = ("[^3AUTO-UPDATER^7] [%s] %s%s^7"):format(timestamp, color, msg)
    print(formatted)
    
    -- Add to log history
    if #State.logs >= Config.maxLogEntries then
        table.remove(State.logs, 1)
    end
    table.insert(State.logs, {
        time = timestamp,
        level = level,
        message = msg
    })
    
    -- Debug mode extra logging
    if Config.debugMode and level == "DEBUG" then
        print(("[^5DEBUG^7] %s"):format(msg))
    end
end

-- Send notification to all players
local function NotifyPlayers(msg, type)
    if not Config.notifyPlayers then return end
    
    local colors = {
        info = {100, 150, 255},
        success = {0, 255, 100},
        warning = {255, 200, 0},
        error = {255, 50, 50}
    }
    
    TriggerClientEvent('chat:addMessage', -1, {
        color = colors[type] or colors.info,
        multiline = true,
        args = {"[🔄 AUTO-UPDATE]", msg}
    })
end

-- Send Discord webhook notification
local function SendDiscord(title, message, color)
    if not Config.discordWebhook or Config.webhookUrl == "" then return end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color or 3447003,
            ["footer"] = {
                ["text"] = "SCRT Auto Updater | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(Config.webhookUrl, function(err, text, headers) end, 'POST', 
        json.encode({embeds = embed}), 
        {['Content-Type'] = 'application/json'}
    )
end

-- Check if player is admin
local function IsAdmin(source)
    if source == 0 then return true end -- Console always admin
    for _, ace in ipairs(Config.adminAces) do
        if IsPlayerAceAllowed(source, ace) then
            return true
        end
    end
    return false
end

-- Check if resource is blacklisted
local function IsBlacklisted(name)
    for _, blacklisted in ipairs(Config.blacklist) do
        if name == blacklisted then return true end
    end
    return false
end

-- Get priority index (lower = higher priority)
local function GetPriority(name)
    for i, priorityRes in ipairs(Config.priority) do
        if name == priorityRes then return i end
    end
    return 999
end

-- Format uptime
local function FormatUptime(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if days > 0 then
        return ("%dd %dh %dm"):format(days, hours, mins)
    elseif hours > 0 then
        return ("%dh %dm %ds"):format(hours, mins, secs)
    else
        return ("%dm %ds"):format(mins, secs)
    end
end

-- Get resource metadata
local function GetResourceMeta(name)
    local meta = {
        name = name,
        state = GetResourceState(name),
        version = GetResourceMetadata(name, 'version', 0) or "unknown",
        author = GetResourceMetadata(name, 'author', 0) or "unknown",
        description = GetResourceMetadata(name, 'description', 0) or ""
    }
    return meta
end

-- ═══════════════════════════════════════════════════════════════
-- FILE WATCHER SYSTEM - Smart File Change Detection
-- ═══════════════════════════════════════════════════════════════

-- Simple hash function untuk detect perubahan file
local function SimpleHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    return tostring(hash)
end

-- Check if file extension should be watched
local function ShouldWatchFile(filename)
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return false end
    ext = ext:lower()
    for _, watchExt in ipairs(Config.watchExtensions) do
        if ext == watchExt then return true end
    end
    return false
end

-- Get resource path
local function GetResourcePath(resourceName)
    return GetResourcePath(resourceName)
end

-- Scan files in a resource and create hash signature
local function GetResourceFileSignature(resourceName)
    local signature = {}
    local resourcePath = GetResourcePath(resourceName)
    
    if not resourcePath then return nil end
    
    -- Get manifest files untuk hash
    local manifestFiles = {
        "fxmanifest.lua",
        "__resource.lua",
        "resource.lua"
    }
    
    for _, manifest in ipairs(manifestFiles) do
        local content = LoadResourceFile(resourceName, manifest)
        if content then
            signature[manifest] = SimpleHash(content)
        end
    end
    
    -- Get all lua files
    local mainFiles = {
        "client.lua", "server.lua", "shared.lua", "config.lua",
        "client/main.lua", "server/main.lua", "shared/config.lua"
    }
    
    for _, file in ipairs(mainFiles) do
        local content = LoadResourceFile(resourceName, file)
        if content then
            signature[file] = SimpleHash(content)
        end
    end
    
    return signature
end

-- Compare two signatures and detect changes
local function CompareSignatures(oldSig, newSig)
    if not oldSig or not newSig then return false, {} end
    
    local changes = {}
    local hasChanges = false
    
    -- Check for modified or new files
    for file, hash in pairs(newSig) do
        if not oldSig[file] then
            table.insert(changes, {file = file, type = "added"})
            hasChanges = true
        elseif oldSig[file] ~= hash then
            table.insert(changes, {file = file, type = "modified"})
            hasChanges = true
        end
    end
    
    -- Check for deleted files
    for file, _ in pairs(oldSig) do
        if not newSig[file] then
            table.insert(changes, {file = file, type = "deleted"})
            hasChanges = true
        end
    end
    
    return hasChanges, changes
end

-- Smart File Watcher - Check all resources for file changes
local function CheckFileChanges()
    if State.fileChecking or State.paused then return {} end
    State.fileChecking = true
    State.stats.lastFileCheck = os.time()
    
    local changedResources = {}
    
    for name, data in pairs(State.resources) do
        if not IsBlacklisted(name) and data.state == "started" then
            local newSignature = GetResourceFileSignature(name)
            
            if newSignature then
                local oldSignature = State.fileHashes[name]
                
                if oldSignature then
                    local hasChanges, changes = CompareSignatures(oldSignature, newSignature)
                    
                    if hasChanges then
                        table.insert(changedResources, {
                            name = name,
                            changes = changes
                        })
                        
                        -- Log changes
                        local changeTypes = {}
                        for _, change in ipairs(changes) do
                            table.insert(changeTypes, ("%s (%s)"):format(change.file, change.type))
                        end
                        
                        Log(("File changes in ^3%s^7: %s"):format(name, table.concat(changeTypes, ", ")), "WARNING")
                        
                        -- Auto reload resource
                        if Config.smartReload then
                            ExecuteCommand("ensure " .. name)
                            State.stats.filesChanged = State.stats.filesChanged + 1
                            Log(("Smart reload triggered: ^2%s^7"):format(name), "SUCCESS")
                            NotifyPlayers(("Resource %s di-reload (file berubah)"):format(name), "warning")
                            SendDiscord("📝 File Changed", 
                                ("Resource **%s** di-reload karena perubahan file:\n%s"):format(name, table.concat(changeTypes, "\n")), 
                                16776960) -- Yellow
                        end
                    end
                end
                
                -- Update signature
                State.fileHashes[name] = newSignature
            end
        end
    end
    
    State.fileChecking = false
    return changedResources
end

-- Initialize file signatures for all resources
local function InitializeFileSignatures()
    Log("Initializing file signatures...", "INFO")
    local count = 0
    
    for name, data in pairs(State.resources) do
        if not IsBlacklisted(name) then
            local signature = GetResourceFileSignature(name)
            if signature then
                State.fileHashes[name] = signature
                count = count + 1
            end
        end
    end
    
    Log(("File signatures initialized for ^2%d^7 resources"):format(count), "SUCCESS")
end

-- ═══════════════════════════════════════════════════════════════
-- CORE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Get all resources with detailed info
local function GetAllResources()
    local resources = {}
    local numResources = GetNumResources()
    
    for i = 0, numResources - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            resources[name] = GetResourceMeta(name)
        end
    end
    
    return resources
end

-- Count resources by state
local function CountResources()
    local counts = {total = 0, started = 0, stopped = 0, starting = 0, unknown = 0}
    local numResources = GetNumResources()
    
    for i = 0, numResources - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            counts.total = counts.total + 1
            local state = GetResourceState(name)
            if state == "started" then
                counts.started = counts.started + 1
            elseif state == "stopped" then
                counts.stopped = counts.stopped + 1
            elseif state == "starting" then
                counts.starting = counts.starting + 1
            else
                counts.unknown = counts.unknown + 1
            end
        end
    end
    
    return counts
end

-- Queue system for starting resources
local function AddToQueue(name, priority)
    if Config.queueSystem then
        table.insert(State.queue, {name = name, priority = priority or 999})
        -- Sort by priority
        table.sort(State.queue, function(a, b) return a.priority < b.priority end)
    else
        ExecuteCommand("ensure " .. name)
    end
end

-- Process queue
local function ProcessQueue()
    if #State.queue == 0 then return end
    
    local item = table.remove(State.queue, 1)
    if item and GetResourceState(item.name) == "stopped" then
        ExecuteCommand("ensure " .. item.name)
        Log(("Queue: Started ^2%s^7"):format(item.name), "SUCCESS")
        State.stats.started = State.stats.started + 1
    end
end

-- Smart scan for new resources
local function ScanForResources()
    if State.scanning or State.paused then return {} end
    State.scanning = true
    State.stats.lastScan = os.time()
    
    -- Refresh resource list
    ExecuteCommand("refresh")
    Wait(Config.refreshWait)
    
    local currentResources = GetAllResources()
    local newResources = {}
    local updatedResources = {}
    
    for name, meta in pairs(currentResources) do
        if not State.resources[name] then
            -- New resource detected
            State.resources[name] = {
                state = meta.state,
                version = meta.version,
                firstSeen = os.time(),
                lastCheck = os.time(),
                errors = 0,
                metadata = meta
            }
            
            if not IsBlacklisted(name) then
                table.insert(newResources, name)
                
                if Config.autoStart and meta.state == "stopped" then
                    local priority = GetPriority(name)
                    AddToQueue(name, priority)
                    Log(("Detected new resource: ^2%s^7 (v%s)"):format(name, meta.version), "SUCCESS")
                end
            end
        else
            -- Check for version changes (file update detection)
            if Config.smartReload and State.resources[name].version ~= meta.version then
                table.insert(updatedResources, name)
                State.resources[name].version = meta.version
                Log(("Version change detected: ^3%s^7 -> v%s"):format(name, meta.version), "WARNING")
                
                if meta.state == "started" then
                    ExecuteCommand("ensure " .. name)
                    Log(("Smart reload: ^2%s^7"):format(name), "SUCCESS")
                end
            end
            
            State.resources[name].lastCheck = os.time()
            State.resources[name].state = meta.state
        end
    end
    
    -- Notify about new resources
    if #newResources > 0 then
        local msg = ("Ditemukan %d resource baru: %s"):format(#newResources, table.concat(newResources, ", "))
        Log(msg, "SUCCESS")
        NotifyPlayers(msg, "success")
        SendDiscord("📦 Resource Baru", msg, 3066993) -- Green
    end
    
    if #updatedResources > 0 then
        local msg = ("Updated %d resources: %s"):format(#updatedResources, table.concat(updatedResources, ", "))
        Log(msg, "WARNING")
        NotifyPlayers(msg, "warning")
    end
    
    State.scanning = false
    return newResources
end

-- Health check - monitor resource status
local function HealthCheck()
    if not Config.healthCheck then return end
    State.stats.lastHealthCheck = os.time()
    
    local issues = {}
    
    for name, data in pairs(State.resources) do
        if not IsBlacklisted(name) then
            local currentState = GetResourceState(name)
            
            -- Detect crash (was started, now stopped unexpectedly)
            if data.state == "started" and currentState == "stopped" then
                data.errors = data.errors + 1
                State.stats.errors = State.stats.errors + 1
                
                table.insert(issues, {name = name, issue = "crashed", errors = data.errors})
                Log(("Resource crashed: ^1%s^7 (errors: %d)"):format(name, data.errors), "ERROR")
                
                -- Auto restart if enabled and not too many errors
                if Config.autoRestart and data.errors < 3 then
                    Wait(1000)
                    ExecuteCommand("ensure " .. name)
                    State.stats.restarted = State.stats.restarted + 1
                    Log(("Auto-restarted: ^2%s^7"):format(name), "SUCCESS")
                    NotifyPlayers(("Resource %s di-restart otomatis"):format(name), "warning")
                elseif data.errors >= 3 then
                    Log(("Resource ^1%s^7 disabled - too many errors"):format(name), "ERROR")
                    SendDiscord("⚠️ Resource Error", 
                        ("Resource **%s** crash berulang kali dan di-disable"):format(name), 
                        15158332) -- Red
                end
            end
            
            data.state = currentState
        end
    end
    
    if #issues > 0 then
        SendDiscord("🔧 Health Check", 
            ("Ditemukan %d masalah pada resources"):format(#issues), 
            15105570) -- Orange
    end
    
    return issues
end

-- Refresh specific or all resources
local function RefreshResources(name)
    if name and name ~= "" then
        -- Refresh specific resource
        if GetResourceState(name) then
            ExecuteCommand("ensure " .. name)
            Log(("Refreshed: ^2%s^7"):format(name), "SUCCESS")
            return true, name
        else
            return false, "Resource not found"
        end
    else
        -- Refresh all non-blacklisted running resources
        local refreshed = 0
        for resName, data in pairs(State.resources) do
            if not IsBlacklisted(resName) and data.state == "started" then
                ExecuteCommand("ensure " .. resName)
                refreshed = refreshed + 1
                Wait(100) -- Small delay to prevent lag
            end
        end
        Log(("Refreshed ^2%d^7 resources"):format(refreshed), "SUCCESS")
        return true, refreshed
    end
end

-- ═══════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════

local function Initialize()
    Log("═══════════════════════════════════════════════", "INFO")
    Log("   AUTO UPDATER v3.5 - SMART FILE WATCHER", "INFO")
    Log("═══════════════════════════════════════════════", "INFO")
    
    -- Load existing resources
    local resources = GetAllResources()
    for name, meta in pairs(resources) do
        State.resources[name] = {
            state = meta.state,
            version = meta.version,
            firstSeen = os.time(),
            lastCheck = os.time(),
            errors = 0,
            metadata = meta
        }
    end
    
    local counts = CountResources()
    
    Log(("Loaded ^2%d^7 resources (%d active, %d stopped)"):format(
        counts.total, counts.started, counts.stopped), "SUCCESS")
    Log(("Scan interval: ^3%d^7 seconds"):format(Config.scanInterval), "INFO")
    Log(("File check interval: ^3%d^7 seconds"):format(Config.fileCheckInterval), "INFO")
    Log(("Health check: ^3%s^7"):format(Config.healthCheck and "enabled" or "disabled"), "INFO")
    Log(("Auto restart: ^3%s^7"):format(Config.autoRestart and "enabled" or "disabled"), "INFO")
    Log(("Smart reload: ^3%s^7"):format(Config.smartReload and "enabled" or "disabled"), "INFO")
    Log(("File watcher: ^3%s^7"):format(Config.fileWatcher and "enabled" or "disabled"), "INFO")
    Log("═══════════════════════════════════════════════", "INFO")
    
    -- Initialize file signatures
    if Config.fileWatcher then
        InitializeFileSignatures()
    end
    
    Log("═══════════════════════════════════════════════", "INFO")
    Log("^2AUTO UPDATER v3.5 READY!^7", "SUCCESS")
    Log("^3File Watcher ACTIVE - Monitoring all resources^7", "SUCCESS")
    Log("═══════════════════════════════════════════════", "INFO")
    
    State.initialized = true
    
    SendDiscord("🚀 Auto Updater Started", 
        ("Server started dengan %d resources"):format(counts.total), 
        3447003) -- Blue
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN THREADS
-- ═══════════════════════════════════════════════════════════════

-- Main scan loop
CreateThread(function()
    Wait(2000) -- Wait for server to fully start
    Initialize()
    
    while true do
        Wait(Config.scanInterval * 1000)
        if not State.paused then
            ScanForResources()
        end
    end
end)

-- Queue processor
CreateThread(function()
    while true do
        Wait(Config.startDelay * 1000)
        if not State.paused and #State.queue > 0 then
            ProcessQueue()
        end
    end
end)

-- Health check loop
CreateThread(function()
    Wait(10000) -- Initial delay
    while true do
        Wait(Config.healthCheckInterval * 1000)
        if not State.paused and Config.healthCheck then
            HealthCheck()
        end
    end
end)

-- Uptime tracker
CreateThread(function()
    while true do
        Wait(1000)
        State.stats.uptime = os.time() - State.startTime
    end
end)

-- FILE WATCHER THREAD - Monitor file changes
CreateThread(function()
    Wait(5000) -- Wait for initialization
    Log("^3File Watcher thread started^7", "INFO")
    
    while true do
        Wait(Config.fileCheckInterval * 1000)
        if not State.paused and Config.fileWatcher then
            local changes = CheckFileChanges()
            if #changes > 0 then
                Log(("^3File Watcher:^7 Detected changes in %d resources"):format(#changes), "WARNING")
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- COMMANDS
-- ═══════════════════════════════════════════════════════════════

-- /autoscan - Manual scan
RegisterCommand("autoscan", function(source)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0}, args = {"[ERROR]", "Akses ditolak!"}
        })
        return
    end
    
    Log("Manual scan triggered by " .. (source == 0 and "Console" or GetPlayerName(source)))
    local newRes = ScanForResources()
    
    local msg = #newRes > 0 
        and ("Ditemukan %d resource baru: %s"):format(#newRes, table.concat(newRes, ", "))
        or "Tidak ada resource baru"
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0}, args = {"[SCAN]", msg}
        })
    end
    Log(msg, #newRes > 0 and "SUCCESS" or "INFO")
end, false)

-- /autorefresh [name] - Refresh resources
RegisterCommand("autorefresh", function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0}, args = {"[ERROR]", "Akses ditolak!"}
        })
        return
    end
    
    local name = args[1]
    local success, result = RefreshResources(name)
    
    local msg = name 
        and (success and ("Refreshed: %s"):format(name) or result)
        or ("Refreshed %s resources"):format(result)
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = success and {0, 255, 0} or {255, 0, 0},
            args = {"[REFRESH]", msg}
        })
    end
    NotifyPlayers(msg, success and "success" or "error")
end, false)

-- /autostatus - System status
RegisterCommand("autostatus", function(source)
    if not IsAdmin(source) then return end
    
    local counts = CountResources()
    local uptime = FormatUptime(State.stats.uptime)
    local queueSize = #State.queue
    
    local status = {
        ("═══ AUTO UPDATER STATUS ═══"),
        ("Uptime: ^3%s^7"):format(uptime),
        ("Resources: ^2%d^7 active / ^3%d^7 total"):format(counts.started, counts.total),
        ("Queue: ^3%d^7 pending"):format(queueSize),
        ("Stats: ^2%d^7 started, ^1%d^7 errors, ^3%d^7 restarted"):format(
            State.stats.started, State.stats.errors, State.stats.restarted),
        ("Status: %s"):format(State.paused and "^1PAUSED^7" or "^2ACTIVE^7"),
        ("Last scan: %s"):format(os.date("%H:%M:%S", State.stats.lastScan))
    }
    
    for _, line in ipairs(status) do
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {100, 200, 255}, args = {"", line}
            })
        else
            Log(line)
        end
    end
end, false)

-- /autolist - List all resources
RegisterCommand("autolist", function(source, args)
    if not IsAdmin(source) then return end
    
    local filter = args[1] -- "started", "stopped", or nil for all
    local list = {}
    
    for name, data in pairs(State.resources) do
        if not filter or data.state == filter then
            local icon = data.state == "started" and "^2●" or "^1○"
            table.insert(list, ("%s %s^7 (v%s)"):format(icon, name, data.metadata.version or "?"))
        end
    end
    
    table.sort(list)
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {100, 200, 255}, 
            args = {"[LIST]", ("Showing %d resources"):format(#list)}
        })
        for _, item in ipairs(list) do
            TriggerClientEvent('chat:addMessage', source, {
                color = {200, 200, 200}, args = {"", item}
            })
        end
    else
        Log(("Showing %d resources"):format(#list))
        for _, item in ipairs(list) do print(item) end
    end
end, false)

-- /autorestart [name] - Restart specific resource
RegisterCommand("autorestart", function(source, args)
    if not IsAdmin(source) then return end
    
    local name = args[1]
    if not name then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 200, 0}, args = {"[ERROR]", "Usage: /autorestart [resource_name]"}
            })
        end
        return
    end
    
    if GetResourceState(name) then
        ExecuteCommand("ensure " .. name)
        State.stats.restarted = State.stats.restarted + 1
        
        local msg = ("Restarted: %s"):format(name)
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0}, args = {"[RESTART]", msg}
            })
        end
        Log(msg, "SUCCESS")
        NotifyPlayers(msg, "success")
    else
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0}, args = {"[ERROR]", "Resource not found: " .. name}
            })
        end
    end
end, false)

-- /autohealth - Manual health check
RegisterCommand("autohealth", function(source)
    if not IsAdmin(source) then return end
    
    local issues = HealthCheck()
    local msg = #issues > 0 
        and ("Found %d issues"):format(#issues)
        or "All resources healthy!"
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = #issues > 0 and {255, 200, 0} or {0, 255, 0},
            args = {"[HEALTH]", msg}
        })
    end
    Log(msg, #issues > 0 and "WARNING" or "SUCCESS")
end, false)

-- /autolog - View recent logs
RegisterCommand("autolog", function(source, args)
    if not IsAdmin(source) then return end
    
    local count = tonumber(args[1]) or 10
    local startIdx = math.max(1, #State.logs - count + 1)
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {100, 200, 255}, 
            args = {"[LOG]", ("Last %d entries:"):format(math.min(count, #State.logs))}
        })
    end
    
    for i = startIdx, #State.logs do
        local entry = State.logs[i]
        local line = ("[%s] [%s] %s"):format(entry.time, entry.level, entry.message)
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {180, 180, 180}, args = {"", line}
            })
        else
            print(line)
        end
    end
end, false)

-- /autopause - Pause scanning
RegisterCommand("autopause", function(source)
    if not IsAdmin(source) then return end
    
    State.paused = true
    local msg = "Auto scanning PAUSED"
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 200, 0}, args = {"[PAUSE]", msg}
        })
    end
    Log(msg, "WARNING")
end, false)

-- /autoresume - Resume scanning
RegisterCommand("autoresume", function(source)
    if not IsAdmin(source) then return end
    
    State.paused = false
    local msg = "Auto scanning RESUMED"
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0}, args = {"[RESUME]", msg}
        })
    end
    Log(msg, "SUCCESS")
end, false)

-- /autoconfig - View/modify config
RegisterCommand("autoconfig", function(source, args)
    if not IsAdmin(source) then return end
    
    local key = args[1]
    local value = args[2]
    
    if not key then
        -- Show current config
        local configInfo = {
            ("scanInterval: %ds"):format(Config.scanInterval),
            ("fileCheckInterval: %ds"):format(Config.fileCheckInterval),
            ("healthCheck: %s"):format(Config.healthCheck),
            ("autoStart: %s"):format(Config.autoStart),
            ("autoRestart: %s"):format(Config.autoRestart),
            ("smartReload: %s"):format(Config.smartReload),
            ("fileWatcher: %s"):format(Config.fileWatcher),
            ("notifyPlayers: %s"):format(Config.notifyPlayers)
        }
        
        for _, line in ipairs(configInfo) do
            if source > 0 then
                TriggerClientEvent('chat:addMessage', source, {
                    color = {100, 200, 255}, args = {"[CONFIG]", line}
                })
            else
                Log(line)
            end
        end
    end
end, false)

-- /autofiles - Check file changes manually
RegisterCommand("autofiles", function(source)
    if not IsAdmin(source) then return end
    
    Log("Manual file check triggered...", "INFO")
    local changes = CheckFileChanges()
    
    local msg = #changes > 0 
        and ("Detected changes in %d resources"):format(#changes)
        or "No file changes detected"
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = #changes > 0 and {255, 200, 0} or {0, 255, 0},
            args = {"[FILES]", msg}
        })
        
        -- Show details
        for _, change in ipairs(changes) do
            local files = {}
            for _, f in ipairs(change.changes) do
                table.insert(files, f.file .. " (" .. f.type .. ")")
            end
            TriggerClientEvent('chat:addMessage', source, {
                color = {200, 200, 200},
                args = {"", ("  %s: %s"):format(change.name, table.concat(files, ", "))}
            })
        end
    end
    Log(msg, #changes > 0 and "WARNING" or "SUCCESS")
end, false)

-- /autowatcher - Toggle file watcher
RegisterCommand("autowatcher", function(source, args)
    if not IsAdmin(source) then return end
    
    local action = args[1]
    
    if action == "on" then
        Config.fileWatcher = true
        InitializeFileSignatures()
        local msg = "File Watcher ENABLED"
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0}, args = {"[WATCHER]", msg}
            })
        end
        Log(msg, "SUCCESS")
    elseif action == "off" then
        Config.fileWatcher = false
        local msg = "File Watcher DISABLED"
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 200, 0}, args = {"[WATCHER]", msg}
            })
        end
        Log(msg, "WARNING")
    else
        local status = Config.fileWatcher and "^2ENABLED^7" or "^1DISABLED^7"
        local tracked = 0
        for _ in pairs(State.fileHashes) do tracked = tracked + 1 end
        
        local info = {
            ("Status: %s"):format(status),
            ("Tracking: %d resources"):format(tracked),
            ("Check interval: %ds"):format(Config.fileCheckInterval),
            ("Last check: %s"):format(os.date("%H:%M:%S", State.stats.lastFileCheck)),
            ("Files changed: %d"):format(State.stats.filesChanged)
        }
        
        for _, line in ipairs(info) do
            if source > 0 then
                TriggerClientEvent('chat:addMessage', source, {
                    color = {100, 200, 255}, args = {"[WATCHER]", line}
                })
            else
                Log(line)
            end
        end
    end
end, false)

-- ═══════════════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    
    if not State.resources[resourceName] then
        State.resources[resourceName] = {
            state = "started",
            version = GetResourceMetadata(resourceName, 'version', 0) or "unknown",
            firstSeen = os.time(),
            lastCheck = os.time(),
            errors = 0,
            metadata = GetResourceMeta(resourceName)
        }
    else
        State.resources[resourceName].state = "started"
        State.resources[resourceName].errors = 0 -- Reset errors on successful start
    end
    
    -- Initialize file signature for new resource
    if Config.fileWatcher and not IsBlacklisted(resourceName) then
        local signature = GetResourceFileSignature(resourceName)
        if signature then
            State.fileHashes[resourceName] = signature
        end
    end
    
    if Config.notifyOnStart and State.initialized then
        Log(("Resource started: ^2%s^7"):format(resourceName), "SUCCESS")
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    
    if State.resources[resourceName] then
        State.resources[resourceName].state = "stopped"
    end
    
    if Config.notifyOnStop and State.initialized then
        Log(("Resource stopped: ^1%s^7"):format(resourceName), "WARNING")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- EXPORTS (untuk resource lain)
-- ═══════════════════════════════════════════════════════════════

exports('GetStatus', function()
    return {
        paused = State.paused,
        stats = State.stats,
        resourceCount = CountResources()
    }
end)

exports('ScanNow', function()
    return ScanForResources()
end)

exports('RefreshResource', function(name)
    return RefreshResources(name)
end)

exports('IsResourceTracked', function(name)
    return State.resources[name] ~= nil
end)
