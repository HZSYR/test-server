fx_version 'cerulean'
game 'gta5'

description 'IR153 HD Road Map - Custom Minimap'
version '1.0.0'

-- Stream all minimap .ytd files
files {
    'mapzoomdata.meta'
}

data_file 'MAP_ZOOM_DATA_FILE' 'mapzoomdata.meta'

client_script 'client.lua'
