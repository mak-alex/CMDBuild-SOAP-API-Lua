--
--------------------------------------------------------------------------------
-- @file : main.lua
--
-- @usage : ./main.lua
--
-- @description :
--
-- @options : ---
-- @requirements : ---
-- @bugs : ---
-- @notes : ---
-- @author : Alexandr Mikhailenko a.k.a Alex M.A.K. (), <alex-m.a.k@yandex.kz>
-- @organization :
-- @version : 1.0
-- @created : 08/02/2017
-- @revision : ---
--------------------------------------------------------------------------------
--
-- Подключаем библиотеку для работы с CMDBuild SOAP API
local CMDBuild = require "lib.cmdbuild"
-- Подключаем библиотеку для работу с аргументами командной строки
local argparse = require "lib.argparse"
-- Подключаем библиотеку для работы с JSON
local cjson = require 'cjson'

local function main()
    local parser = argparse():name "cmdbuild":description [[Скрипт-библиотека для работы с CMDBuild SOAP API.
      Примеры:
        # авторизовываем в CMDBuild и запрашиваем карты для класса Hosts
        lua main.lua -u admin -p '3$rFvCdE' -i 10.244.244.128 -g Hosts

        # а теперь используем фильтр CMDBuild для выбора нужной карточки, для класса Hosts
        # где -f Id EQUALS 1392123 это {name='Id',operator='EQUALS',value=1392123} данный фильтр описан в документации
        lua main.lua -u admin -p '3$rFvCdE' -i 10.244.244.128 -g Hosts -f Id EQUALS 1392123
        
        # а теперь выгрузим дерево зависимостей для класс Hosts (внимание! работает только для классов Hosts & Templates (модель Казниие Инновейшен))
        lua main.lua -u admin -p '3$rFvCdE' -i 10.244.244.128 -g Hosts -D
    ]]:epilog "Для получения дополнительной информации, читайте doc/CMDBuild_WebserviceManual_ENG_V240.pdf"
    parser:option("-u --username", "Имя пользователя для подключения к CMDBuild")
    parser:option("-p --password", "Пароль для подключения к CMDBuild")
    parser:option("-i --ip", "IP адресс для подключения к CMDBuild")
    parser:option("-g --getCardList", "Название выгружаемого класса, (пример: Hosts)", nil)
    parser:option("-c --card_id", "Идентификатор выгружаемой карты", nil)
    parser:option("-f --filter", "Фильтр для выгружаемых карт, (пример: hostid EQUALS or LIKE 1328439)"):args("*")
    parser:option("-F --format", "Формат вывода в stdout (xml или json)", 'json')
    parser:flag '-v --verbose'
    parser:flag '-d --debug'
    parser:flag('-D --dependencies', 'Выгрузка зависимостей для классов Hosts & Templates и формирование JSON структуры (xml не поддерживается)')

    local args = parser:parse()
    local username = args.username
    local password = args.password
    local ip = args.ip

    -- Создаем новый инстанс
    local cmdbuild = CMDBuild:new(nil, nil, args.verbose, args.debug)
    -- Добавляем пользователя и создаем SOAP заголовок
    cmdbuild:set_credentials({ username = username, password = password, ip = ip }).insertHeader()

    if args.getCardList then
        local filter, resp
        if args.filter then
            filter = { name = args.filter[1], operator = args.filter[2], value = args.filter[3] }
        end

        if args.card_id then
            resp = cmdbuild:getCard(args.getCardList, args.card_id)
        else
            ------------------------------------------------------------------------
            -- @name : kazniie_model
            -- @purpose :
            -- @description : Only Kazniie Innovation models
            -- @params : name - classname (string)
            -- @returns : table
            ------------------------------------------------------------------------
            function kazniie_model(name, filtername, filter)
                local Hosts = cmdbuild.Utils.decode(cmdbuild:getCardList(name, nil, filter))
                for k, v in pairs(Hosts.Id) do
                    Hosts.Id[k]["Items"] = cmdbuild.Utils.decode(cmdbuild:getCardList("zItems", nil, { name = filtername, operator = 'EQUALS', value = k }))
                    Hosts.Id[k]["Triggers"] = cmdbuild.Utils.decode(cmdbuild:getCardList("ztriggers", nil, { name = filtername, operator = 'EQUALS', value = k }))
                    Hosts.Id[k]["Applications"] = cmdbuild.Utils.decode(cmdbuild:getCardList("zapplications", nil, { name = filtername, operator = 'EQUALS', value = k }))
                end
                return cjson.encode(Hosts)
            end

            if args.getCardList == 'Templates' then args.getCardList = 'templates' end

            if args.dependencies and args.getCardList == 'Hosts' then
                resp = kazniie_model("Hosts", 'hostid', filter)
            elseif args.dependencies and args.getCardList == 'templates' then
                resp = kazniie_model("templates", 'hostid', filter)
            else
                resp = cmdbuild:getCardList(args.getCardList, nil, filter)
            end
        end

        if args.format == 'xml' and not args.dependencies then
            print(resp)
        elseif args.format == 'xml' and args.dependencies then
            print('XML is not supported, the output is produced in JSON format')
            print(cmdbuild.Utils.pretty(cjson.decode(resp)))
        elseif args.format == 'json' and args.dependencies then
            if args.getCardList == 'Templates' or args.getCardList == 'Hosts' then
                print(cmdbuild.Utils.pretty(cjson.decode(resp)))
            end
        else
            print(cmdbuild.Utils.pretty(cmdbuild.Utils.decode(resp)))
        end
    end
end

main()
