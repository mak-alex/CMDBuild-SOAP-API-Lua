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
local utils = require'lib.Utils'

-- :new(PID, USECOLOR, VERBOSE, DEBUG)
local CMDBuild = require 'lib.cmdbuild':new(nil, nil, true, false)
-- добавляем пользователя и указываем IP адрес,
-- после чего добавляем сформированный SOAP заголовок
CMDBuild:set_credentials{username = 'admin', password = '3$rFvCdE', ip = '10.244.244.128'}.insertHeader()
-- требуем от CMDBuild'a вернуть список карт для класса zItems
--local response = CMDBuild.Card:get('ztriggers').list()
--local response = CMDBuild.Card:get('ztriggers').history('1392030')
local response = CMDBuild.Card:get().menu_schema()
print(utils.pretty(response))
-- формируем массив формата { Id = { "1922123" = { ... }}
-- форматируем JSON и выводим в stdout
--print(utils.pretty(utils.decode(response)))
