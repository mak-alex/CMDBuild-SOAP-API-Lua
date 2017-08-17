require'luarocks.loader'
local CMDBuild = require 'cmdbuild':new(nil, nil, true, false)
CMDBuild:set_credentials{username = 'admin', password = '3$rFvCdE', ip = '10.244.244.128'}.insertHeader()
local response = CMDBuild.Card:get('Hosts').list()
response.decode().tprint()

