--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
-- File:  gate.lua
--
-- Usage:  ./gate.lua
--
-- Description:
--
-- Options:  ---
-- Requirements:  ---
-- Bugs:  ---
-- Notes:  ---
-- Author:  Alex M.A.K. (Mr), <alex-m.a.k@yandex.kz>
-- Organization:  Kazniie Innovation Ltd.
-- Version:  1.0
-- Created:  07/28/2017
-- Revision:  ---
--------------------------------------------------------------------------------
--
local utils = require'src.Utils'
local CMDBuild = require 'src.cmdbuild':new(nil, nil, true, true)
CMDBuild:set_credentials{username = 'admin', password = '3$rFvCdE', ip = 'localhost'}.insertHeader()
--local response = CMDBuild.Card:get('ztriggers').card(1392030)
--local response = CMDBuild.Card:get('Hosts').list()
--local response = CMDBuild.Card:get('zItems').attributes()
--print(response.decode().method)
--response.decode().tprint()
--print(utils.pretty(response.entries))
local response = CMDBuild.Card:create('AddressesIPv4', {Address='192.168.88.37/24'})
response.decode().tprint()
local decresp = response.decode().entries
table.foreach(decresp.Id, function(id, _)
    --local response = CMDBuild.Card:update('AddressesIPv4', id, {Address='192.168.88.37/24'})
    if type(id) ~= 'number' then return end
    local resp = CMDBuild.Card:delete('AddressesIPv4', id)
    resp.decode().tprint()
end)
--if resp then resp.decode().tprint() end

