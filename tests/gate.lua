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

local Gate = require'src.Gate'
local t = Gate:new{
  username = 'admin',
  password = '3$rFvCdE',
  ip = '10.244.244.128'
}

assert(t:auth(), 'авторизация не прошла, проверьте правильность настроек')
local Hosts = t:loadCards('Hosts')
assert(Hosts, 'не удалось получить карты для класса Hosts')
local Templates = t:loadCards('templates')
assert(Templates, 'не удалось получить карты для класса Templates')
