fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'w2f-ambulance'
author 'w2f'
description 'Framework-agnostic ambulance and medical gameplay system'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/init.lua',
    'config/*.lua',
    'shared/*.lua'
}

client_scripts {
    'client/init.lua',
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua',
    'server/*.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js'
}

dependencies {
    'ox_lib'
}
