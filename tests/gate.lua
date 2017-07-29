--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
--         File:  gate.lua
--
--        Usage:  ./gate.lua
--
--  Description:  
--
--      Options:  ---
-- Requirements:  ---
--         Bugs:  ---
--        Notes:  ---
--       Author:  Alex M.A.K. (Mr), <alex-m.a.k@yandex.kz>
-- Organization:  Kazniie Innovation Ltd.
--      Version:  1.0
--      Created:  07/28/2017
--     Revision:  ---
--------------------------------------------------------------------------------
--

require 'lib.lunity'
module( 'TEST_GATE', lunity )
local Gate = require'src.Gate'
local LocationID = nil
local HostID = nil
local TemplateID = nil

local t = Gate:new{
  username = 'admin',
  password = '3$rFvCdE',
  ip = '10.244.244.128'
}

function test1_auth_in_cmdbuild()
  assertNotNil(t:auth(), 'авторизация не прошла, проверьте правильность настроек')
end

function test2_get_location_id_by_name()
  LocationID = t:get_location_id_by_name('РТС-AT.EXPO-318')
  assertNotNil(LocationID, 'не удалось получить идентификатор указанной локации') 
end

function test3_get_hosts_for_location_id()
  local HostID = next(t:get_hosts_for_location_id(LocationID).Id)
  assertNotNil(HostID, 'не удалось получить хосты для указанной локации')
end

function test4_get_applications_for_host_id()
  local resp = t:get_applications_for_host_id(HostID)
  assertNotNil(resp, 'не удалось получить аппликейшены для указанного хоста')
end

function test5_get_interface_for_host_id()
  local resp = t:get_interface_for_host_id(HostID)
  assertNotNil(resp, 'не удалось получить интерфейсы для указанного хоста')
end

function test6_get_interface_for_host_id()
  local resp = t:get_items_for_host_id(HostID)
  assertNotNil(resp, 'не удалось получить айтемы для указанного хоста')
end

function test7_get_triggers_for_host_id()
  local resp = t:get_triggers_for_host_id(HostID)
  assertNotNil(resp, 'не удалось получить триггеры для указанного хоста')
end
function test8_load_cards()
  TemplateID = next(t:load_cards("templates").Id)
  assertNotNil(TemplateID, 'не удалось получить карты для класса templates')
end

function test9_get_items_for_template_id()
  local resp = t:get_items_for_template_id(TemplateID)
  assertNotNil(resp, 'не удалось получить айтемы для указанного шаблона')
end

runTests()
