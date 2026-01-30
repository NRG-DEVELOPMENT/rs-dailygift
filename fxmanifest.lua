fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rs_dailygift'
author 'NRG Development'
description 'Daily Gift'
version '1.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}


server_scripts {
    'server/server.lua',
    '@oxmysql/lib/MySQL.lua',

}

client_scripts {
    'client/client.lua',
}

dependencies {
    'oxmysql',
}
