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

local cmdbuild = require'lib.cmdbuild'
local t = cmdbuild:new({
  username = 'admin',
  password = '3$rFvCdE',
  ip = '10.244.244.128'
}, nil, nil, true, true)

local Hosts = t:decode(t:getCardList('Hosts'))
assert(Hosts, 'не удалось получить карты для класса Hosts')
local Templates = t:decode(t:getCardList('templates'))
assert(Templates, 'не удалось получить карты для класса Templates')
