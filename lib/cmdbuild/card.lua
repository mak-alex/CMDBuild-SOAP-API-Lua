--
-- Created by IntelliJ IDEA.
-- User: mak
-- Date: 8/6/17
-- Time: 6:57 AM
-- Class: ${PACKAGE_NAME}
-- To change this template use File | Settings | File Templates.
--
-- @classmod Card
local Card = {
    type = 'Card',
}

Card.__index = Card -- get indices from the table
Card.__metatable = Card -- protect the metatable

------------------------------------------------------------------------
-- get
-- list mts: getCard, getCardList, getCardHistory and etc.
-- @param classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @return table
------------------------------------------------------------------------
function Card:get(classname)
    local mts = {}
    ------------------------------------------------------------------------
    --  Card:card
    --  It returns the required card with all attributes specified in “attributeList” (all card attributes if “attributeList” is null).
    -- @param card_id - {+DESCRIPTION+} (number)
    -- @param attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
    -- They correspond to additional attributes defined in the Card Administration Module and available in the card management.
    -- The list includes also the ClassId (not the className)(table)
    -- ex.: {name='',value=''}
    -- @return xml response (string)
    ------------------------------------------------------------------------
    mts.card = function(card_id, attributes_list)
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
                    { tag = "soap1:name", self.Utils.escape(tostring(k)) },
                    { tag = "soap1:value", self.Utils.escape(tostring(v)) },
                })
            end
            table.insert(request.entries, attributes)
        end

        local resp = self:call(request)
        return xml.eval(resp):find 'ns2:return'
    end

    mts.card_menu_schema = function()
        local request = {}
        request.method = "getCardMenuSchema"
        request.entries = {}

        local resp = self:call(request)
        return xml.eval(resp):find 'ns2:return'
    end
    local getMenuSchemaResponse = {
        id = 0,
        menuType = 0,
        parentId = 0,
        position = 0
    }
    mts.menu_schema = function()
        local request = {}
        request.method = "getMenuSchema"
        request.entries = {}

        local resp = xml.eval(self:call(request)):find'ns2:return'
        for level = 1, #resp do
        end
        for _, node in pairs(resp) do
            if type(node) == 'table' then
                getMenuSchemaResponse[node[node.TAG]]=node[1]
            end
        end
        return getMenuSchemaResponse
    end
    ------------------------------------------------------------------------
    --  Card:history
    --  It returns the list of the historicized versions of the specified card.
    -- @param card_id - CMDBuild Card Id (number)
    -- @return xml response (string)
    ------------------------------------------------------------------------
    mts.history = function(card_id)
        local request = {}
        request.method = "getCardHistory"
        request.entries = {
            { tag = "soap1:className", classname },
            { tag = "soap1:cardId", card_id }
        }

        local resp = self:call(request)
        return xml.eval(resp):find 'ns2:return'
    end

    mts.attributes = function()
        local request = {}
        request.method = "getAttributeList"
        request.entries = {
            { tag = "soap1:className", classname },
        }

        local resp = self:call(request)
        return xml.eval(resp)
    end
    ------------------------------------------------------------------------
    --  Card:list
    --  It returns the card list resulting from the specified query, completed with all attributes specified
    -- in “attributeList” (all card attributes if “attributeList” is null).
    -- If the query is made on a superclass, the "className" attribute of the returned Card objects contains the name of the specific string.subclass
    -- the card belongs to, while in the attributeList it appears the ClassId of the same string.subclass.
    -- @param attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
    -- They correspond to additional attributes defined in the Card Administration Module and available in the card management.
    -- The list includes also the ClassId (not the className)(table) ex.: {name='',value=''}
    -- @param filter - It string.represents an atomic filter condition to select a card list. (table)
    -- @param filter_sq_operator - It string.represents a concatenation of atomic filter conditions connected with an operator. (string)
    -- @param order_type - It string.represents the ordering standard among the cards drawn from the filter query. (table)
    -- @param limit - the number of returned results (number)
    -- @param offset - {+DESCRIPTION+} ({+TYPE+})
    -- @param full_text_query - {+DESCRIPTION+} ({+TYPE+})
    -- @param cql_query - {+DESCRIPTION+} ({+TYPE+})
    -- @param cql_query_parameters - {+DESCRIPTION+} ({+TYPE+})
    -- @return xml response (string)
    ------------------------------------------------------------------------
    mts.list = function(attributes_list, filter, filter_sq_operator, order_type, limit, offset, full_text_query, cql_query, cql_query_parameters)
        self.Log.debug(string.format('Created a request to get cards for the class: Hosts: %s', classname), self._debug)
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
            self.Log.debug(string.format('In a request gets cards for the class: \'%s\', added list of attributes: : \'%s\'',
                classname,
                tostring(unpack(attributes_list))),
                self._debug)
        end

        if filter or filter_sq_operator then
            if filter and not filter_sq_operator then
                local filters = {
                    tag = "soap1:queryType",
                    {
                        tag = "soap1:filter",
                        { tag = "soap1:name", filter.name },
                        { tag = "soap1:operator", filter.operator },
                        { tag = "soap1:value", filter.value }
                    }
                }
                table.insert(request.entries, filters)
                self.Log.debug(
                    string.format('In a request gets cards for the class: \'%s\', added filter: {name=\'%s\', operator=\'%s\', value=\'%s\'}',
                        classname,
                        filter.name,
                        filter.operator,
                        tostring(filter.value)
                    ) ,
                    self._debug
                )
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

        local response = self:call(request)
        local nsreturn = xml.eval(response):find 'ns2:return'

        local countCards = function(classname, nsreturn)
            local decoderesp = self.Utils.decode(nsreturn)
            if not decoderesp.Id then
                self.Log.warn(string.format("Failed to get cards for the class: \'%s\'", classname),
                    self.verbose)
                return
            else
                self.Log.info(
                    string.format('Received cards for the class: \'%s\' in quantity: \'%d\'', classname, self.Utils.tsize(decoderesp)),
                    self.verbose
                )
            end
        end
        countCards(classname, nsreturn)

        return nsreturn
    end
    return mts
end

------------------------------------------------------------------------
-- Card:create
--  It creates in the database a new card, containing the information inserted in the "Card" object.
-- It returns the "id" identification attribute.
-- @param classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @param attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the Card Administration Module and available in the card management.
-- The list includes also the ClassId (not the className)(table)
-- ex.: {name='',value='',code=''}
-- @param metadata - {+DESCRIPTION+} ({+TYPE+})
-- @return : id - (number)
------------------------------------------------------------------------
function Card:create(classname, attributes_list, metadata)
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
                { tag = "soap1:name", self.Utils.escape(tostring(k)) },
                { tag = "soap1:value", self.Utils.escape(tostring(v)) },
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
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- Card:update
--  It updates a pre-existing card.  It returns “true” if the operation went through.
-- @param classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @param card_id - {+DESCRIPTION+} (number)
-- @param attributes_list - Array of "Attribute" objects containing the values of additional custom attributes in the class.
-- They correspond to additional attributes defined in the Card Administration Module and available in the card management.
-- The list includes also the ClassId (not the className)(table)
-- ex.: {name='',value=''}
-- @param metadata - {+DESCRIPTION+} ({+TYPE+})
-- @return boolean
------------------------------------------------------------------------
function Card:update(classname, card_id, attributes_list, metadata)
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
                { tag = "soap1:name", self.Utils.escape(tostring(k)) },
                { tag = "soap1:value", self.Utils.escape(tostring(v)) },
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
    return xml.eval(resp):find 'ns2:return'
end

------------------------------------------------------------------------
-- Card:delete
--  It deletes logically - in the identified class - the pre-existing card with the identified "id".
-- It returns “true” if the operation went through.
-- @param classname - Class name which includes the card.  It corresponds to the table name in the database. (string)
-- @param card_id - {+DESCRIPTION+} (number)
-- @return boolean
------------------------------------------------------------------------
function Card:delete(classname, card_id)
    local request = {}
    request.method = "deleteCard"
    request.entries = {
        { tag = "soap1:className", classname },
        { tag = "soap1:cardId", card_id }
    }

    local resp = self:call(request)
    return xml.eval(resp):find 'ns2:return'
end

return Card