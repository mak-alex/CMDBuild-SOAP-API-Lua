--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
--         File:  l.lua
--
--        Usage:  ./l.lua
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
cmdbuild.cards = require'lib.cmdbuild.cards'
local t = cmdbuild({username='admin',password='3$rFvCdE'}, true, true)
t.cards:get_card_list('Hosts')
