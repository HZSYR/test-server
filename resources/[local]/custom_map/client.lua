Citizen.CreateThread(function()
    -- Mengatur limit zoom untuk map radar/minimap dan pause menu (ESC)
    -- Ini mencegah map menjadi rusak, terlalu kecil, atau hilang saat di-zoom.
    SetMapZoomDataLevel(0, 0.96, 0.9, 0.08, 0.0, 0.0) -- Level 0
    SetMapZoomDataLevel(1, 1.6, 0.9, 0.08, 0.0, 0.0) -- Level 1
    SetMapZoomDataLevel(2, 8.6, 0.9, 0.08, 0.0, 0.0) -- Level 2
    SetMapZoomDataLevel(3, 12.3, 0.9, 0.08, 0.0, 0.0) -- Level 3
    SetMapZoomDataLevel(4, 22.3, 0.9, 0.08, 0.0, 0.0) -- Level 4

    while true do
        Citizen.Wait(0)
        -- Force radar to use custom settings and fix pause menu zoom
        if IsPauseMenuActive() then
            -- Mencegah bug map kotak saat di pause menu
            SetBlipScale(GetMainPlayerBlipId(), 1.0)
        end
    end
end)
