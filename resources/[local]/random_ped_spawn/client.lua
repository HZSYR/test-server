-- =============================================================
-- Random Ped Spawner
-- Memberikan ped custom random saat player spawn & respawn
-- =============================================================

-- Daftar semua custom ped model (9 ped)
local customPeds = {
    'ArcherBunny',
    'DenjiChainsaw',
    'SatoruGojo',
    'chamber',
    'KRATOS',
    'Omen1',
    'SpidermanClassic',
    'JJKCCSuguruGeto',
    'TanjiroKamada',
}

-- Fungsi untuk set ped model secara random
local function SetRandomPed()
    -- Pilih model random dari daftar
    local randomIndex = math.random(1, #customPeds)
    local modelName = customPeds[randomIndex]
    local modelHash = GetHashKey(modelName)

    -- Request model
    RequestModel(modelHash)

    -- Tunggu sampai model ter-load (timeout 15 detik)
    local timeout = 15000
    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Citizen.Wait(100)
        if GetGameTimer() - startTime > timeout then
            print('[Random Ped] GAGAL load model: ' .. modelName .. ' - Coba model lain...')
            -- Jika gagal, coba model lain
            local fallbackIndex = math.random(1, #customPeds)
            local fallbackModel = customPeds[fallbackIndex]
            local fallbackHash = GetHashKey(fallbackModel)
            RequestModel(fallbackHash)
            local startTime2 = GetGameTimer()
            while not HasModelLoaded(fallbackHash) do
                Citizen.Wait(100)
                if GetGameTimer() - startTime2 > timeout then
                    print('[Random Ped] GAGAL load fallback model: ' .. fallbackModel)
                    return
                end
            end
            modelHash = fallbackHash
            modelName = fallbackModel
            break
        end
    end

    -- Pastikan model sudah loaded
    if HasModelLoaded(modelHash) then
        -- Set player model
        SetPlayerModel(PlayerId(), modelHash)
        -- Lepas model dari memory
        SetModelAsNoLongerNeeded(modelHash)
        print('[Random Ped] Player spawn dengan ped: ' .. modelName)
    end
end

local isFirstSpawn = true

AddEventHandler('playerSpawned', function()
    if isFirstSpawn then
        -- Pertama kali masuk server, loading lama
        Citizen.Wait(8000)
        isFirstSpawn = false
    else
        -- Respawn setelah mati, loading cepat
        Citizen.Wait(2000)
    end
    SetRandomPed()
end)
