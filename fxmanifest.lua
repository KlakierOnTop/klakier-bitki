-- =========================================================
--  BITKI
--  Autor: Klakier
--  Wersja: 1.0.0
-- =========================================================

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Klakier'
description 'System bitek organizacji (ESX)'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
