--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
-- @file : CMDBuild.lua
--
-- @usage : ./CMDBuild.lua
--
-- @description : Библиотека для работы с CMDBuild SOAP API
--
-- @options : ---
-- @requirements : LuaXML, LuaSocket, LuaSec, lib/{base64.lua,ArgParse.lua,Log.lua}
-- @bugs : ---
-- @notes : ---
-- @author : Alex M.A.K. (Mr), <alex-m.a.k@yandex.kz>
-- @organization : Kazniie Innovation Ltd.
-- @version : 1.0
-- @created : 07/24/2017
-- @revision : ---
--------------------------------------------------------------------------------
--

-- @todo: добавить обработчик ошибок
-- @todo: ВАЖНО! дописать описание методов и аргументов
-- @todo: избавиться от повторяющихся действий
-- @todo: причесать код (это мелочь, но все таки нужна мелочь)
--

--------------------------------------------------------------------------------
--
-- Подключаем библиотеку для логгирования
local Log = require 'lib.Log'
local Utils = require 'lib.Utils'

require 'luarocks.loader'
-- Подключаем библиотеку для работы с base64, нужна для работы с аттачментами
local base64 = require 'lib.base64'
-- Подключаем библиотеку для работы с XML
require 'LuaXML'
local XML = xml
-- Необходимо для работы с сетью
local ltn12 = require("ltn12")
local client = { http = require("socket.http"), }
--
--------------------------------------------------------------------------------

local CMDBuild = {
    type = 'CMDBuild',
    webservices = 'http://__ip__/cmdbuild/services/soap/Webservices',
    Utils = Utils,
    Log = Log
}

CMDBuild.__index = CMDBuild -- get indices from the table
CMDBuild.__metatable = CMDBuild -- protect the metatable

------------------------------------------------------------------------
-- @name : CMDBuild:new
-- @purpose :
-- @description : {+DESCRIPTION+}
-- @params : credentials - credentials table (table)
-- username: (string)
-- password: (sring)
-- url or ip: (string)
-- @params : pid - {+DESCRIPTION+} (string or number)
-- @params : logcolor - {+DESCRIPTION+} (boolean)
-- @params : verbose - {+DESCRIPTION+} (boolean)
-- @params : _debug - {+DESCRIPTION+} (boolean)
-- @returns : {+RETURNS+}
------------------------------------------------------------------------
function CMDBuild:new(pid, logcolor, verbose, _debug)

    Log.pid = pid or 'cmdbuild_soap_api'
    Log.usecolor = logcolor or false

    local obj = {}
    obj.Header = {}
    obj.username = nil
    obj.password = nil
    obj.url = nil
    obj.verbose = verbose or false
    obj._debug = _debug or false

    return setmetatable(obj, CMDBuild)
end


function CMDBuild:set_credentials(credentials)
    if not self.username then
        if credentials.username then
            Log.debug('Added user name', self.verbose)
            self.username = credentials.username
        else
            Log.warn('`credentials.username\' can\'t be empty', self.verbose)
            os.exit(-1)
        end
    end

    if not self.password then
        if credentials.password then
            Log.debug('Added a password for the user', self.verbose)
            self.password = credentials.password
        else
            Log.warn('`credentials.password\' can\'t be empty', self.verbose)
            os.exit(-1)
        end
    end

    if not self.url then
        if credentials.url then
            Log.debug('Added url CMDBuild', self.verbose)
            self.url = credentials.url
        elseif credentials.ip then
            Log.debug('CMDBuild address is formed and added', self.verbose)
            self.url = self.webservices:gsub('__ip__', credentials.ip)
        else
            Log.warn('`credentials.ip\' can\'t be empty', self.verbose)
            os.exit(-1)
        end
    end

    self.Header.insertHeader = function()
        local oasisopen = 'http://docs.oasis-open.org/wss/2004/01/'
        local wsse = oasisopen .. "oasis-200401-wss-wssecurity-secext-1.0.xsd"
        local wssu = oasisopen .. "oasis-200401-wss-wssecurity-utility-1.0.xsd"
        local PassText = oasisopen .. "oasis-200401-wss-username-token-profile-1.0#PasswordText"

        if self.username and self.password then
            Log.info('The SOAP header is formed and added', self.verbose)
            self.Header = {
                tag = "wsse:Security",
                attr = { ["xmlns:wsse"] = wsse },
                {
                    tag = "wsse:UsernameToken",
                    attr = { ["xmlns:wssu"] = wssu },
                    { tag = "wsse:Username", self.username },
                    { tag = "wsse:Password", attr = { Type = PassText }, self.password }
                }
            }
        else
            Log.warn('Failed to generate the SOAP header', self.verbose)
            os.exit(-1)
        end
    end
    return self.Header
end

----- end of function CMDBuild_mt:set_credentials  -----

------------------------------------------------------------------------
-- @name : CMDBuild:createLookup
-- @purpose :
-- @description : It creates in the database a new heading of a data Lookup list
-- containing information inserted in the “Lookup” object.
-- It returns the "id" identification attribute.
-- @params : lookup_type - Name of the Lookup list which includes the current heading (string)
-- @params : code - Code of the Lookup heading (one single heading of a Lookup list).(string)
-- @params : description - Description of the Lookup heading (one single heading of a Lookup list) (string)
-- @params : id - Lookup identification, it is automatically assigned by the database (number)
-- @params : notes - Notes connected with the Lookup heading (string)
-- @params : parent_id - Identification of the parent Lookup in the current heading (if applicable) (number)
-- @params : position - Location of the Lookup heading in the related Lookup list (number)
-- @returns : id (integer)
------------------------------------------------------------------------
function CMDBuild:createLookup(lookup_type, code, description, id, notes, parent_id, position)
    local request = {}
    request.method = "createLookup"
    request.entries = {
        {
            tag = "soap1:lookup",
            { tag = "soap1:code", code },
            { tag = "soap1:description", description }
        }
    }

    if id then
        table.insert(request.entries[1], { tag = "soap1:id", id })
    end

    if notes then
        table.insert(request.entries[1], { tag = "soap1:notes", notes })
    end

    if parent_id and position then
        table.insert(request.entries[1], { tag = "soap1:parent" })
        table.insert(request.entries[1], { tag = "soap1:parentId", parent_id })
        table.insert(request.entries[1], { tag = "soap1:position", position })
    end
    table.insert(request.entries[1], { tag = "soap1:type", lookup_type })

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:deleteLookup
-- @purpose :
-- @description : It deletes logically - in the identified class -
-- the pre-existing card with the identified "id".  
-- It returns “true” if the operation went through.
-- @params : lookup_id - {+DESCRIPTION+} (number)
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:deleteLookup(lookup_id)
    local request = {}
    request.method = "deleteLookup"
    request.entries = {
        {
            tag = "soap1:lookup",
            { tag = "soap1:lookupId", lookup_id },
        }
    }

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:updateLookup
-- @purpose :
-- @description : It updates the pre-existing Lookup heading.  It returns “true” if the operation went through.
-- @params : lookup_type - Name of the Lookup list which includes the current heading (string)
-- @params : code - Code of the Lookup heading (one single heading of a Lookup list).(string)
-- @params : description - Description of the Lookup heading (one single heading of a Lookup list).(string)
-- @params : id - Lookup identification, it is automatically assigned by the database (number)
-- @params : notes - Notes connected with the Lookup heading (string)
-- @params : parent_id - Identification of the parent Lookup in the current heading (if applicable) (number)
-- @params : position - Location of the Lookup heading in the related Lookup list (number)
-- @returns : id (integer)
-- @returns : {+RETURNS+}
------------------------------------------------------------------------
function CMDBuild:updateLookup(lookup_type, code, description, id, notes, parent_id, position)
    local request = {}
    request.method = "updateLookup"
    request.entries = {
        {
            tag = "soap1:lookup",
            { tag = "soap1:code", code },
            { tag = "soap1:description", description }
        }
    }

    if id then
        table.insert(request.entries[1], { tag = "soap1:id", id })
    end

    if notes then
        table.insert(request.entries[1], { tag = "soap1:notes", notes })
    end

    if parent_id and position then
        table.insert(request.entries[1], { tag = "soap1:parent" })
        table.insert(request.entries[1], { tag = "soap1:parentId", parent_id })
        table.insert(request.entries[1], { tag = "soap1:position", position })
    end
    table.insert(request.entries[1], { tag = "soap1:type", lookup_type })

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getLookupList
-- @purpose :
-- @description : It returns a complete list of Lookup values corresponding to the specified "type".
-- If the "value" parameter is specified, only the related heading is returned.  
-- If “parentList” takes the “True” value, it returns the complete hierarchy available for the multilevel Lookup lists.
-- @params : lookup_type - Name of the Lookup list which includes the current heading(string)
-- @params : value - {+DESCRIPTION+} ({+TYPE+})
-- @params : need_parent_list - {+DESCRIPTION+} ({+TYPE+})
-- @returns : {+RETURNS+}
------------------------------------------------------------------------
function CMDBuild:getLookupList(lookup_type, value, need_parent_list)
    local request = {}
    request.method = "getLookupList"
    request.entries = {
        { tag = "soap1:type", lookup_type },
    }

    if value then
        table.insert(request.entries, { tag = "soap1:value", value })
    end

    if need_parent_list then
        table.insert(request.entries, { tag = "soap1:parentList", true })
    end

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getLookupById
-- @purpose :
-- @description : It returns the Lookup heading which shows the specified "Id" identification
-- @params : lookup_id - {+DESCRIPTION+} ({+TYPE+})
-- @returns : {+RETURNS+}
------------------------------------------------------------------------
function CMDBuild:getLookupById(lookup_id)
    local request = {}
    request.method = "getLookupById"
    request.entries = {
        { tag = "soap1:id", lookup_id },
    }

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getLookupTranslationById
-- @purpose :
-- @description : Only model from DBIC
-- @params : lookup_id - {+DESCRIPTION+} ({+TYPE+})
-- @returns : {+RETURNS+}
------------------------------------------------------------------------
function CMDBuild:getLookupTranslationById(lookup_id)
    local request = {}
    request.method = "callFunction"
    request.entries = {
        { tag = "soap1:functionName", "dbic_get_lookup_trans_by_id" },
        {
            tag = "soap1:params",
            { tag = "soap1:name", "itid" },
            { tag = "soap1:value", lookup_id }
        }
    }

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:createRelation
-- @purpose :
-- @description : It creates in the database a new relation between the pair of cards specified in the "Relation" object.
-- It returns “true” if the operation went through.
-- @params : domain_name - Domain used for the relation. (string)
-- @params : class1name - ClassName of the first card taking part in the relation (string)
-- @params : card1Id - Identifier of the first card which takes part in the relation (number)
-- @params : class2name - ClassName of the second card which takes part in the relation. (string)
-- @params : card2Id - Identifier of the second card which takes part in the relation. (number)
-- @params : status - Relation status ('A' = active, 'N' = removed) (string)
-- @params : begin_date - Date when the relation was created (format YYYY-MM-DDThh:mm:ssZ) (date)
-- @params : end_date - Date when the relation was created (format YYYY-MM-DDThh:mm:ssZ) (date)
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:createRelation(domain_name, class1name, card1Id, class2name, card2Id, status, begin_date, end_date)
    local request = {}
    request.method = "createRelation"
    request.entries = {
        { tag = "soap1:domainName", domain_name },
        { tag = "soap1:class1Name", class1name },
        { tag = "soap1:card1Id", card1Id },
        { tag = "soap1:class2Name", class2name },
        { tag = "soap1:card2Id", card2Id },
        { tag = "soap1:status", status },
        { tag = "soap1:beginDate", begin_date },
        { tag = "soap1:endDate", end_date },
    }

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:deleteRelation
-- @purpose :
-- @description : It deletes the existing relation between the pair of cards specified in the "Relation" object.
-- It returns “true” if the operation went through.
-- @params : domain_name - Domain used for the relation. (string)
-- @params : class1name - ClassName of the first card taking part in the relation (string)
-- @params : card1Id - Identifier of the first card which takes part in the relation (number)
-- @params : class2name - ClassName of the second card which takes part in the relation. (string)
-- @params : card2Id - Identifier of the second card which takes part in the relation. (number)
-- @params : status - Relation status ('A' = active, 'N' = removed) (string)
-- @params : begin_date - Date when the relation was created (format YYYY-MM-DDThh:mm:ssZ) (date)
-- @params : end_date - Date when the relation was created (format YYYY-MM-DDThh:mm:ssZ) (date)
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:deleteRelation(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
    local request = {}
    request.method = "deleteRelation"
    request.entries = {
        { tag = "soap1:domainName", domain_name },
        { tag = "soap1:class1name", class1name },
        { tag = "soap1:card1id", card1id },
        { tag = "soap1:class2name", class2name },
        { tag = "soap1:card2id", card2id },
        { tag = "soap1:status", status },
        { tag = "soap1:begindate", begin_date },
        { tag = "soap1:enddate", end_date },
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getRelationList
-- @purpose :
-- @description : It returns the complete list of relations of the card specified for the specified domain.
-- @params : domain_name - Domain used for the relation. (string)
-- @params : classname - ClassName of the first card taking part in the relation (string)
-- @params : id - Identifier of the first card which takes part in the relation (number)
-- @returns : {+RETURNS+}
------------------------------------------------------------------------
function CMDBuild:getRelationList(domain_name, classname, id)
    local request = {}
    request.method = "getRelationList"
    request.entries = {
        { tag = "soap1:domain", domain_name },
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", id },
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getRelationHistory
-- @purpose :
-- @description : It returns the relation history of a card starting from a "Relation" object
-- in which only "Class1Name" and "Card1Id" were defined.
-- @params : domain_name - Domain used for the relation. (string)
-- @params : class1name - ClassName of the first card taking part in the relation (string)
-- @params : card1Id - Identifier of the first card which takes part in the relation (number)
-- @params : class2name - ClassName of the second card which takes part in the relation. (string)
-- @params : card2Id - Identifier of the second card which takes part in the relation. (number)
-- @params : status - Relation status ('A' = active, 'N' = removed) (string)
-- @params : begin_date - Date when the relation was created (format YYYY-MM-DDThh:mm:ssZ) (date)
-- @params : end_date - Date when the relation was created (format YYYY-MM-DDThh:mm:ssZ) (date)
-- @returns : table
------------------------------------------------------------------------
function CMDBuild:getRelationHistory(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
    local request = {}
    request.method = "getRelationHistory"
    request.entries = {
        { tag = "soap1:domainName", domain_name },
        { tag = "soap1:class1name", class1name },
        { tag = "soap1:card1id", card1id },
        { tag = "soap1:class2name", class2name },
        { tag = "soap1:card2id", card2id },
        { tag = "soap1:status", status },
        { tag = "soap1:begindate", begin_date },
        { tag = "soap1:enddate", end_date },
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end


------------------------------------------------------------------------
-- @name : CMDBuild:startWorkflow
-- @purpose :
-- @description : It starts a new instance of the workflow described in the specified "Card".
-- If the “CompleteTask” parameter takes the “true” value, the process is advanced to the following step.  
-- It returns the "id" identification attribute.
-- @params : classname - ClassName of the first card taking part in the relation (string)
-- @params : attributes_list - {+DESCRIPTION+} ({+TYPE+})
-- @params : metadata - {+DESCRIPTION+} ({+TYPE+})
-- @params : complete_task - {+DESCRIPTION+} (boolean)
-- @returns : id (number)
------------------------------------------------------------------------
function CMDBuild:startWorkflow(classname, attributes_list, metadata, complete_task)
    local request = {}
    request.method = "startWorkflow"
    request.entries = {
        {
            tag = "soap1:card",
            { tag = "soap1:className", classname },
        }
    }

    if attributes_list then
        local attributes = {}
        for k, v in pairs(attributes_list) do
            table.insert(attributes, {
                tag = "soap1:attributeList",
                { tag = "soap1:name", Utils.escape(tostring(k)) },
                { tag = "soap1:value", Utils.escape(tostring(v)) },
            })
        end
        table.insert(request.entries[1], attributes)
    end

    if metadata then
        table.insert(request.entries, {
            tag = "soap1:metadata",
            {
                tag = "soap1:metadata",
                { tag = "soap1:key", metadata.key },
                { tag = "soap1:value", metadata.value }
            }
        })
    end

    local ctask = complete_task or true
    if complete_task then
        table.insert(request.entries, { tag = "soap1:competeTask", tosstring(ctask) })
    end

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:updateWorkflow
-- @purpose :
-- @description : It updates the information of the card in the specified process instance.
-- If the “CompleteTask” parameter takes the “true” value, the process is advanced to the following step.
-- It returns “true” if the operation went through
-- @params : process_id - {+DESCRIPTION+} ({+TYPE+})
-- @params : attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the CMDBuild Administration Module and available in the card management. 
-- The list includes also the ClassId (not the className)(table) ex.: {name='',value=''}
-- @params : complete_task - boolean
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:updateWorkflow(process_id, attributes_list, complete_task)
    local request = {}
    request.method = "startWorkflow"
    request.entries = {
        {
            tag = "soap1:card",
            { tag = "soap1:processId", process_id }
        }
    }

    if attributes_list then
        local attributes = {}
        for k, v in pairs(attributes_list) do
            table.insert(attributes, {
                tag = "soap1:attributeList",
                { tag = "soap1:name", Utils.escape(tostring(k)) },
                { tag = "soap1:value", Utils.escape(tostring(v)) },
            })
        end
        table.insert(request.entries[1], attributes)
    end

    local ctask = complete_task or true
    if complete_task then
        table.insert(request.entries, { tag = "soap1:competeTask", tosstring(ctask) })
    end

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:uploadAttachment
-- @purpose :
-- @description : It uploads the specified file in the DMS Alfresco and the relating connection
-- to the CMDBuild card belonging to the “className” class and having the “id” identification.  
-- It returns “true” if the operation went through.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @params : file - {+DESCRIPTION+} (string)
-- @params : filename - Attachment name with extension (string)
-- @params : category - Category which the attachment belongs to (from proper Lookup list). (string)
-- @params : description - Description related to the attachment (string)
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:uploadAttachment(classname, card_id, file, filename, category, description)
    local request = {}
    request.method = "uploadAttachment"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id },
        { tag = "soap1:fileName", filename },
        { tag = "soap1:category", category },
        { tag = "soap1:description", description },
    }

    if file then
        local i = io.open(file)
        table.insert(request.entries, { tag = "soap1:file", base64.encode(i.read '*a') })
        i:close()
    end

    -- todo: добавить открытие и конвертирование файла в base64
    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:downloadAttachment
-- @purpose :
-- @description : It returns the file enclosed in the specified card, which has the specified name.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @params filename - {+DESCRIPTION+} ({+TYPE+})
-- @returns : base64 (string)
------------------------------------------------------------------------
function CMDBuild:downloadAttachment(classname, card_id, filename)
    local request = {}
    request.method = "downloadAttachment"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id },
        { tag = "soap1:fileName", filename },
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:deleteAttachment
-- @purpose :
-- @description : It removes from the DMS Alfresco the file enclosed in the specified card, which has the specified name.
-- It returns “true” if the operation went through.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @params : filename - {+DESCRIPTION+} ({+TYPE+})
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:deleteAttachment(classname, card_id, filename)
    local request = {}
    request.method = "deleteAttachment"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id },
        { tag = "soap1:fileName", filename },
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:updateAttachment
-- @purpose :
-- @description : It updates the description of the file enclosed in the specified card, which has the specified name.
-- It returns “true” if the operation went through.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @params : filename - {+DESCRIPTION+} ({+TYPE+})
-- @params : description - {+DESCRIPTION+} ({+TYPE+})
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:updateAttachment(classname, card_id, filename, description)
    local request = {}
    request.method = "updateAttachment"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id },
        { tag = "soap1:fileName", filename },
        { tag = "soap1:description", description },
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:createCard
-- @urpose :
-- @description : It creates in the database a new card, containing the information inserted in the "Card" object.
-- It returns the "id" identification attribute.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the CMDBuild Administration Module and available in the card management.
-- The list includes also the ClassId (not the className)(table) 
-- ex.: {name='',value='',code=''}
-- @params : metadata - {+DESCRIPTION+} ({+TYPE+})
-- @return : id - (number)
------------------------------------------------------------------------
function CMDBuild:createCard(classname, attributes_list, metadata)
    local request = {}
    request.method = "createCard"
    request.entries = {
        { tag = "soap1:cardType" }
    }

    table.insert(request.entries[1], { tag = "soap1:className", classname })

    if attributes_list then
        local attributes = {}
        for k, v in pairs(attributes_list) do
            table.insert(attributes, {
                tag = "soap1:attributeList",
                { tag = "soap1:name", Utils.escape(tostring(k)) },
                { tag = "soap1:value", Utils.escape(tostring(v)) },
            })
        end
        table.insert(request.entries[1], attributes)
    end

    if metadata then
        table.insert(request.entries[1], {
            tag = "soap1:metadata",
            {
                tag = "soap1:metadata",
                { tag = "soap1:key", metadata.key },
                { tag = "soap1:value", metadata.value }
            }
        })
    end

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:updateCard
-- @purpose :
-- @description : It updates a pre-existing card.  It returns “true” if the operation went through.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @params : attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the CMDBuild Administration Module and available in the card management.
-- The list includes also the ClassId (not the className)(table) 
-- ex.: {name='',value=''}
-- @params : metadata - {+DESCRIPTION+} ({+TYPE+})
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:updateCard(classname, card_id, attributes_list, metadata)
    local request = {}
    request.method = "updateCard"
    request.entries = {
        {
            tag = "soap1:card",
            { tag = "soap1:className", classname },
            { tag = "soap1:id", card_id }
        }
    }

    if attributes_list then
        local attributes = {}
        for k, v in pairs(attributes_list) do
            table.insert(attributes, {
                tag = "soap1:attributeList",
                { tag = "soap1:name", Utils.escape(tostring(k)) },
                { tag = "soap1:value", Utils.escape(tostring(v)) },
            })
        end
        table.insert(request.entries[1], attributes)
    end

    if metadata then
        table.insert(request.entries[1], {
            tag = "soap1:metadata",
            {
                tag = "soap1:metadata",
                { tag = "soap1:key", metadata.key },
                { tag = "soap1:value", metadata.value }
            }
        })
    end

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:deleteCard
-- @purpose :
-- @description : It deletes logically - in the identified class - the pre-existing card with the identified "id".
-- It returns “true” if the operation went through.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @returns : boolean
------------------------------------------------------------------------
function CMDBuild:deleteCard(classname, card_id)
    local request = {}
    request.method = "deleteCard"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id }
    }

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getCard
-- @purpose :
-- @description : It returns the required card with all attributes specified in “attributeList” (all card attributes if “attributeList” is null).
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @params : attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the CMDBuild Administration Module and available in the card management.
-- The list includes also the ClassId (not the className)(table) 
-- ex.: {name='',value=''}
-- @returns : xml response (string)
------------------------------------------------------------------------
function CMDBuild:getCard(classname, card_id, attributes_list)
    local request = {}
    request.method = "getCard"
    request.entries = {}

    if classname then
        table.insert(request.entries, { tag = "soap1:className", classname })
    end
    table.insert(request.entries, { tag = "soap1:cardId", card_id })

    if attributes_list then
        local attributes = {}
        for k, v in pairs(attributes_list) do
            table.insert(attributes, {
                tag = "soap1:attributeList",
                { tag = "soap1:name", Utils.escape(tostring(k)) },
                { tag = "soap1:value", Utils.escape(tostring(v)) },
            })
        end
        table.insert(request.entries, attributes)
    end

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getCardHistory
-- @purpose :
-- @description : It returns the list of the historicized versions of the specified card.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : card_id - {+DESCRIPTION+} (number)
-- @returns : xml response (string)
------------------------------------------------------------------------
function CMDBuild:getCardHistory(classname, card_id)
    local request = {}
    request.method = "getCardHistory"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id }
    }

    local resp = self:call(request)
    return XML.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- @name : CMDBuild:getCardList
-- @purpose :
-- @description : It returns the card list resulting from the specified query, completed with all attributes specified
-- in “attributeList” (all card attributes if “attributeList” is null).  
-- If the query is made on a superclass, the "className" attribute of the returned Card objects contains the name of the specific string.subclass 
-- the card belongs to, while in the attributeList it appears the ClassId of the same string.subclass.
-- @params : classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @params : attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the CMDBuild Administration Module and available in the card management. 
-- The list includes also the ClassId (not the className)(table) ex.: {name='',value=''}
-- @params : filter - It string.represents an atomic filter condition to select a card list. (table)
-- @params : filter_sq_operator - It string.represents a concatenation of atomic filter conditions connected with an operator. (string)
-- @params : order_type - It string.represents the ordering standard among the cards drawn from the filter query. (table)
-- @params : limit - the number of returned results (number)
-- @params : offset - {+DESCRIPTION+} ({+TYPE+})
-- @params : full_text_query - {+DESCRIPTION+} ({+TYPE+})
-- @params : cql_query - {+DESCRIPTION+} ({+TYPE+})
-- @params : cql_query_parameters - {+DESCRIPTION+} ({+TYPE+})
-- @returns : xml response (string)
------------------------------------------------------------------------
function CMDBuild:getCardList(classname, attributes_list, filter, filter_sq_operator, order_type, limit, offset, full_text_query, cql_query, cql_query_parameters)
    Log.debug(string.format('Created a request to get cards for the class: Hosts: %s', classname),
        self._debug)
    local request = {}
    request.method = "getCardList"
    request.entries = {
        { tag = "soap1:className", classname },
    }

    if attributes_list then
        local attributes = {}
        for i = 1, #attributes_list do
            attributes[i] = {
                tag = "soap1:attributesList",
                { tag = "soap1:name", attributes_list[i] }
            }
        end
        table.insert(request.entries, attributes_list)
        Log.debug(string.format('In a request gets cards for the class: \'%s\', added list of attributes: : \'%s\'',
            classname,
            tostring(unpack(attributes_list))),
            self._debug)
    end

    if filter or filter_sq_operator then
        if filter and not filter_sq_operator then
            local filters = {}
            filters = {
                tag = "soap1:queryType",
                {
                    tag = "soap1:filter",
                    { tag = "soap1:name", filter.name },
                    { tag = "soap1:operator", filter.operator },
                    { tag = "soap1:value", filter.value }
                }
            }
            table.insert(request.entries, filters)
            Log.debug(string.format('In a request gets cards for the class: \'%s\', added filter: {name=\'%s\', operator=\'%s\', value=\'%s\'}',
                classname,
                filter.name,
                filter.operator,
                tostring(filter.value)),
                self._debug)
        end

        if not filter and filter_sq_operator then
            local filters = { tag = "soap1:filterOperator" }
            for i = 1, #filter_sq_operator do
                filters[1] = { tag = "soap1:operator", filter_sq_operator.operator }

                if type(filter_sq_operator.subquery) == 'table' then
                    for j = 1, #filter_sq_operator.subquery do
                        filters[1] = {
                            tag = "soap1:subquery",
                            {
                                tag = "soap1:filter",
                                { tag = "soap1:name", filter_sq_operator[i].subquery[j].name },
                                { tag = "soap1:operator", filter_sq_operator[i].subquery[j].operator },
                                { tag = "soap1:value", filter_sq_operator[i].subquery[j].value },
                            }
                        }
                    end
                else
                    filters[1] = {
                        tag = "soap1:subquery",
                        { tag = "soap1:name", filter_sq_operator[i].subquery.name },
                        { tag = "soap1:operator", filter_sq_operator[i].subquery.operator },
                        { tag = "soap1:value", filter_sq_operator[i].subquery.value },
                    }
                end
            end
            table.insert(request.entries, filters)
            log.debug(string.format('The request gets cards for the class: \'%s\', added multiple filter',
                classname),
                self._debug)
        end
    end

    if order_type then
        table.insert(request.entries, {
            tag = "soap1:orderType",
            { tag = "soap1:columnName", order_type.columnName },
            { tag = "soap1:type", order_type.type },
        })
    end

    if limit then
        table.insert(request.entries, { tag = "soap:limit", limit })
        log.debug(string.format('The request gets cards for the class: \'%s\', added limit: \'%d\'',
            classname,
            limit),
            self._debug)
    end

    if offset then
        table.insert(request.entries, { tag = "soap1:offset", offset })
    end

    if full_text_query then
        table.insert(request.entries, { tag = "soap1:fullTextQuery", full_text_query })
    end

    if cql_query then
        local _cql_query = {
            tag = "soap1:cqlQuery",
            { tag = "soap1:cqlQuery", cql_query }
        }
        if cql_query_parameters then
            _cql_query = {
                tag = "soap1:parameters",
                { tag = "soap1:key", cql_query_parameters.key },
                { tag = "soap1:value", cql_query_parameters.value }
            }
        end
        table.insert(request.entries, _cql_query)
    end

    local resp = self:call(request)
    local eval_resp = XML.eval(resp):find 'ns2:return'
    local decode_resp = Utils.decode(eval_resp)
    if not decode_resp.Id then
        Log.warn(string.format("Failed to get cards for the class: \'%s\'", classname),
            self.verbose)
        return
    else
        Log.info(string.format('Received cards for the class: \'%s\' in quantity: \'%d\'', classname, Utils.tsize(decode_resp)),
            self.verbose)
    end

    return eval_resp
end

------------------------------------------------------------------------
-- @name : CMDBuild:__call
-- @purpose :
-- @description : {+DESCRIPTION+}
-- @params : method_name - getCardList or maybe other methods (string)
-- @params : params - lua table (table)
-- { tag = "soap1:className", 'Hosts' },
-- @usage : CMDBuidl:__call('getCardList', { tag = 'soap1:classname', 'Hosts' })
-- @returns : soap response (string)
------------------------------------------------------------------------
function CMDBuild:__call(method_name, params)
    local request = {}
    request.method = method_name
    request.entries = params

    local resp = self:call(request)
    local eval_resp = XML.eval(resp):find 'ns2:return'
    return eval_resp
end

---------------------------------------------------------------------
-- @name : CMDBuild:call
-- @description : Call a remote method.
-- @params : args Table with the arguments which could be:
-- url: String with the location of the server.
-- namespace: String with the namespace of the elements.
-- method: String with the method's name.
-- entries: Table of SOAP elements (LuaExpat's format).
-- header: Table describing the header of the SOAP-ENV (optional).
-- internal_namespace: String with the optional namespace used
-- as a prefix for the method name (default = "").
-- soapversion: Number with SOAP version (default = 1.1).
-- @return : String with namespace, String with method's name and
-- Table with SOAP elements (LuaExpat's format).
---------------------------------------------------------------------
function CMDBuild:call(args)
    local xml_header_template = '<?xml version="1.0"?>'
    local header_template = { tag = "soap:Header", }
    local xmlns_soap = "http://schemas.xmlsoap.org/soap/envelope/"
    local xmlns_soap12 = "http://www.w3.org/2003/05/soap-envelope"
    local mandatory_url = "Field `url' is mandatory"
    local mandatory_soapaction = "Field `soapaction' is mandatory for SOAP 1.1 (or you can force SOAP version with `soapversion' field)"
    local invalid_args = "Supported SOAP versions: 1.1 and 1.2.  The presence of soapaction field is mandatory for SOAP version 1.1.\nsoapversion, soapaction = "

    ------------------------------------------------------------------------
    -- @name : encode
    -- @purpose :
    -- @description : Converts a LuaXml table into a SOAP message
    -- @params : args - Table with the arguments, which could be: (table)
    -- namespace: String with the namespace of the elements.
    -- method: String with the method's name;
    -- entries: Table of SOAP elements (LuaExpat's format);
    -- header: Table describing the header of the SOAP envelope (optional);
    -- internal_namespace: String with the optional namespace used
    -- as a prefix for the method name (default = "");
    -- soapversion: Number of SOAP version (default = 1.1);
    --
    -- @returns : String with SOAP envelope element
    ------------------------------------------------------------------------
    local function encode(args)
        local serialize

        -- Template SOAP Table
        local envelope_templ = {
            tag = "soap:Envelope",
            attr = {
                "xmlns:soap", "xmlns:soap1",
                ["xmlns:soap1"] = "http://soap.services.cmdbuild.org", -- to be filled
                ["xmlns:soap"] = "http://schemas.xmlsoap.org/soap/encoding/",
            },
            {
                tag = "soap:Body",
                [1] = {
                    tag = "soap1", -- must be filled
                    attr = {}, -- must be filled
                },
            }
        }

        ------------------------------------------------------------------------
        -- @name : contents
        -- @purpose :
        -- @description : Serialize the children of an object
        -- @params : obj - Table with the object to be serialized (table)
        -- @returns : String string.representation of the children
        ------------------------------------------------------------------------
        local function contents(obj)
            if not obj[1] then
                return ""
            else
                local c = {}
                for i = 1, #obj do
                    c[i] = serialize(obj[i])
                end
                return table.concat(c)
            end
        end

        ------------------------------------------------------------------------
        -- @name : serialize
        -- @purpose :
        -- @description : Serialize an object
        -- @params : obj - Table with the object to be serialized (table)
        -- @returns : String with string.representation of the object
        ------------------------------------------------------------------------

        serialize = function(obj)

            ------------------------------------------------------------------------
            -- @name : attrs
            -- @purpose :
            -- @description : Serialize the table of attributes
            -- @params : a - Table with the attributes of an element (table)
            -- @returns : String string.representation of the object
            ------------------------------------------------------------------------
            local function attrs(a)
                if not a then
                    return "" -- no attributes
                else
                    local c = {}
                    if a[1] then
                        for i = 1, #a do
                            local v = a[i]
                            c[i] = string.format("%s=%q", v, a[v])
                        end
                    else
                        for i, v in pairs(a) do
                            c[#c + 1] = string.format("%s=%q", i, v)
                        end
                    end
                    if #c > 0 then
                        return " " .. table.concat(c, " ")
                    else
                        return ""
                    end
                end
            end


            local tt = type(obj)
            if tt == "string" then
                return Utils.escape(Utils.unescape(obj))
            elseif tt == "number" then
                return obj
            elseif tt == "table" then
                local t = obj.tag
                assert(t, "Invalid table format (no `tag' field)")
                return string.format("<%s%s>%s</%s>", t, attrs(obj.attr), contents(obj), t)
            else
                return ""
            end
        end

        ------------------------------------------------------------------------
        -- @name : insert_header
        -- @purpose :
        -- @description : Add header element (if it exists) to object
        -- Cleans old header element anywat
        -- @params : obj - {+DESCRIPTION+} (table)
        -- header - template header (table)
        -- @returns : header_template (table)
        ------------------------------------------------------------------------
        local function insert_header(obj, header)
            -- removes old header
            if obj[2] then
                table.remove(obj, 1)
            end
            if header then
                header_template[1] = header
                table.insert(obj, 1, header_template)
            end
        end

        if tonumber(args.soapversion) == 1.2 then
            envelope_templ.attr["xmlns:soap"] = xmlns_soap12
        else
            envelope_templ.attr["xmlns:soap"] = xmlns_soap
        end

        local xmlns = "xmlns"
        if args.internal_namespace then
            xmlns = xmlns .. ":" .. args.internal_namespace
            args.method = args.internal_namespace .. ":" .. args.method
        else
            xmlns = xmlns .. ":soap1"
            args.method = "soap1:" .. args.method
        end

        -- Cleans old header and insert a new one (if it exists).
        insert_header(envelope_templ, args.header or self.Header)

        -- Sets new body contents (and erase old content).
        local body = (envelope_templ[2] and envelope_templ[2][1]) or envelope_templ[1][1]
        for i = 1, math.max(#body, #args.entries) do
            body[i] = args.entries[i]
        end

        -- Sets method (actually, the table's tag) and namespace.
        body.tag = args.method
        body.attr[xmlns] = args.namespace

        return serialize(envelope_templ)
    end

    local soap_action, content_type_header
    if (not args.soapversion) or tonumber(args.soapversion) == 1.1 then
        content_type_header = "text/xml;charset=UTF-8"
    else
        content_type_header = "application/soap+xml"
    end
    local xml_header = xml_header_template
    if args.encoding then
        xml_header = xml_header:gsub('"%?>', '" encoding="' .. args.encoding .. '"?>')
    end

    local request_body = xml_header .. encode(args)
    Log.debug('SOAP Request: ' .. tostring(XML.eval(request_body)), self._debug)

    local request_sink, tbody = ltn12.sink.table()
    local headers = {
        ["Content-Type"] = content_type_header,
        ["Content-Length"] = tostring(request_body:len()),
        ["SOAPAction"] = soap_action,
    }

    if args.headers then
        for h, v in pairs(args.headers) do
            headers[h] = v
        end
    end

    local url = {
        url = assert(args.url or self.url, mandatory_url),
        method = "POST",
        source = ltn12.source.string(request_body),
        sink = request_sink,
        headers = headers,
    }

    local suggested_layers = { http = "socket.http", https = "ssl.https", }
    local protocol = url.url:match "^(%a+)" -- protocol's name
    local mod = assert(client[protocol], '"' .. protocol .. '" protocol support unavailable. Try soap.CMDBuild:' .. protocol .. ' = require"' .. suggested_layers[protocol] .. '" to enable it.')
    local request = assert(mod.request, 'Could not find request function on module soap.CMDBuild:' .. protocol)
    local one_or_nil, status_code, headers, receive_status = request(url)
    local body = table.concat(tbody)

    ------------------------------------------------------------------------
    -- @name : retriveMessage
    -- @purpose :
    -- @description : The function truncates the additional information in the SOAP response
    -- @params : response - cmdbuild response (string)
    -- @returns : soap response (string)
    ------------------------------------------------------------------------
    local function retriveMessage(response)
        ------------------------------------------------------------------------
        -- @name : jtr
        -- @purpose :
        -- @description : {+DESCRIPTION+}
        -- @params : text_array - {+DESCRIPTION+} ({+TYPE+})
        -- @returns : {+RETURNS+}
        ------------------------------------------------------------------------
        local function jtr(text_array)
            local ret = ""
            for i = 1, #text_array do if text_array[i] then ret = ret .. text_array[i]; end end
            return ret;
        end

        local resp = jtr(response)
        local istart, iend = resp:find('<soap:Envelope.*</soap:Envelope>');
        if (istart and iend) then
            return resp:sub(istart, iend);
        else
            return nil
        end
    end

    local response = retriveMessage(tbody)
    Log.debug('SOAP Response: ' .. tostring(XML.eval(response)), self._debug)

    return response
end

return CMDBuild
