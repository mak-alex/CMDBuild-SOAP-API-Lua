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
local CMDBuild = require 'src.cmdbuild':new(nil, nil, true, false)
CMDBuild:set_credentials{username = 'admin', password = '3$rFvCdE', ip = '10.244.244.128'}.insertHeader()
local response = CMDBuild.Card:get('Hosts').list()
response.decode().tprint()
