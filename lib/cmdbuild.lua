--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab

-- @todo: как только явится Света, дописать handler в соответствии со спекой CMDBuild
-- @todo: ВАЖНО! дописать описание методов и аргументов, пф, осталось чутка, а потом проверять и по новой до усеру
--

--------------------------------------------------------------------------------
require 'luarocks.loader'
require 'LuaXML'
--------------------------------------------------------------------------------

local errors = {
    ['NOTFOUND_ERROR'] = 'Element not found',
    ['AUTH_MULTIPLE_GROUPS'] = 'The user is connected with multiple groups',
    ['AUTH_UNKNOWN_GROUP'] = 'Unknown group',
    ['AUTH_NOT_AUTHORIZED'] = 'The authorizations are not enough to perform the operation',
    ['ORM_GENERIC_ERROR'] = 'An error has occurred while reading/saving data',
    ['ORM_DUPLICATE_TABLE'] = 'There is already a class with this name',
    ['ORM_CAST_ERROR'] = 'Error in the type conversion',
    ['ORM_UNIQUE_VIOLATION'] = 'Not null constraint violated',
    ['ORM_CONTAINS_DATA'] = 'You can\'t delete classes or attributes of tables or domains containing data',
    ['ORM_TYPE_ERROR'] = 'Not corresponding type',
    ['ORM_ERROR_GETTING_PK'] = 'The main key can\'t be determined',
    ['ORM_ERROR_LOOKUP_CREATION'] = 'The lookup can\'t be created',
    ['ORM_ERROR_LOOKUP_MODIFY'] = 'The lookup can\'t be modified',
    ['ORM_ERROR_LOOKUP_DELETE'] = 'The lookup can\'t be deleted',
    ['ORM_ERROR_RELATION_CREATE'] = 'The relation can\'t be created',
    ['ORM_ERROR_RELATION_MODIFY'] = 'The relation can\'t be modified',
    ['ORM_CHANGE_LOOKUPTYPE_ERROR'] = 'The lookup type can\'t be changed',
    ['ORM_READ_ONLY_TABLE'] = 'Read-only table',
    ['ORM_READ_ONLY_RELATION'] = 'Read-only relation',
    ['ORM_DUPLICATE_ATTRIBUTE'] = 'There   is   already   an   attribute   with   this name',
    ['ORM_DOMAIN_HAS_REFERENCE'] = 'Domains with reference attributes can\'t be deleted',
    ['ORM_FILTER_CONFLICT'] = 'Conflict by defining the filter',
    ['ORM_AMBIGUOUS_DIRECTION'] = 'The direction relation can\'t be automatically determined'
}

local CMDBuild = {
    type = 'CMDBuild',
    webservices = 'http://__ip__/cmdbuild/services/soap/Webservices',
    ltn12 = require'ltn12',
    client = { http = require'socket.http', },
    Log = require 'lib.Log',
    Utils = require 'lib.Utils',
    Card = require'lib.cmdbuild.card',
    Relation = require'lib.cmdbuild.relation',
    Attachment = require'lib.cmdbuild.attachment',
    Lookup = require'lib.cmdbuild.lookup',
    Workflow = require'lib.cmdbuild.workflow',
    Xml = require("lib.xmlSimple").newParser()
}

CMDBuild.__index = CMDBuild -- get indices from the table
CMDBuild.__metatable = CMDBuild -- protect the metatable

setmetatable(CMDBuild.Attachment, {__index = CMDBuild})
setmetatable(CMDBuild.Card, {__index = CMDBuild})
setmetatable(CMDBuild.Lookup, {__index = CMDBuild})
setmetatable(CMDBuild.Relation, {__index = CMDBuild})
setmetatable(CMDBuild.Workflow, {__index = CMDBuild})

------------------------------------------------------------------------
--  CMDBuild:new
--  Create new instance
-- @param pid - pid string for log (string or number)
-- @param logcolor - use color log print to stdout (boolean)
-- @param verbose - verbose mode (boolean)
-- @param _debug - debug mode (boolean)
-- @return instance
------------------------------------------------------------------------
function CMDBuild:new(pid, logcolor, verbose, _debug)
    CMDBuild.Log.pid = pid or 'cmdbuild_soap_api'
    CMDBuild.usecolor = logcolor or false
    CMDBuild.Header = {}
    CMDBuild.username = nil
    CMDBuild.password = nil
    CMDBuild.url = nil
    CMDBuild.verbose = verbose or false
    CMDBuild._debug = _debug or false

    return CMDBuild
end

------------------------------------------------------------------------
-- CMDBuild:set_credentials
-- Set credentials for connected to CMDBuild
-- @param `credentials` The value object
-- @field username string
-- @field password string
-- @field url string
-- @field ip string
-- @return soap header
------------------------------------------------------------------------
function CMDBuild:set_credentials(credentials)
    if not self.username then
        if credentials.username then
            self.username = credentials.username
            self.Log.debug('Added user name', self.verbose)
        else
            self.Log.warn('`credentials.username\' can\'t be empty', self.verbose)
            os.exit(-1)
        end
    end

    if not self.password then
        if credentials.password then
            self.password = credentials.password
            self.Log.debug('Added a password for the user', self.verbose)
        else
            self.Log.warn('`credentials.password\' can\'t be empty', self.verbose)
            os.exit(-1)
        end
    end

    if not self.url then
        if credentials.url then
            self.url = credentials.url
            self.Log.debug('Added url CMDBuild', self.verbose)
        elseif credentials.ip then
            self.url = self.webservices:gsub('__ip__', credentials.ip)
            self.Log.debug('CMDBuild address is formed and added', self.verbose)
        else
            self.Log.warn('`credentials.ip\' can\'t be empty', self.verbose)
            os.exit(-1)
        end
    end

    self.Header.insertHeader = function()
        local oasisopen = 'http://docs.oasis-open.org/wss/2004/01/'
        local wsse = oasisopen .. "oasis-200401-wss-wssecurity-secext-1.0.xsd"
        local wssu = oasisopen .. "oasis-200401-wss-wssecurity-utility-1.0.xsd"
        local PassText = oasisopen .. "oasis-200401-wss-username-token-profile-1.0#PasswordText"

        if self.username and self.password then
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
            self.Log.info('The SOAP header is formed and added', self.verbose)
        else
            self.Log.warn('Failed to generate the SOAP header', self.verbose)
            os.exit(-1)
        end
    end

    return self.Header
end

----- end of function CMDBuild:mt:set_credentials  -----

---------------------------------------------------------------------
--  CMDBuild.call
--  Call a remote method.
-- @table args Table with the arguments which could be
-- @field url String with the location of the server
-- @field namespace String with the namespace of the elements
-- @field method String with the method's name
-- @field entries Table of SOAP elements (LuaExpat's format)
-- @field header Table describing the header of the SOAP-ENV (optional)
-- @field internal_namespace String with the optional namespace used as a prefix for the method name (default = "")
-- @return String with namespace, String with method's name and Table with SOAP elements (LuaExpat's format)
---------------------------------------------------------------------
function CMDBuild:call(args)
    local header_template = { tag = "soap:Header", }
    local xmlns_soap = "http://schemas.xmlsoap.org/soap/envelope/"
    local xmlns_soap12 = "http://www.w3.org/2003/05/soap-envelope"

    ------------------------------------------------------------------------
    -- encode
    -- Converts a LuaXml table into a SOAP message
    -- @table args Table with the arguments, which could be (table)
    -- @field namespace String with the namespace of the elements.
    -- @field method String with the method's name
    -- @field entries Table of SOAP elements (LuaExpat's format)
    -- @field header Table describing the header of the SOAP envelope (optional)
    -- @field internal_namespace String with the optional namespace used as a prefix for the method name (default = "")
    -- @return String with SOAP envelope element
    ------------------------------------------------------------------------
    self.encode = function(args)
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
        --  contents
        --  Serialize the children of an object
        -- @param obj - Table with the object to be serialized (table)
        -- @return String string.representation of the children
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
        --  serialize
        --  Serialize an object
        -- @param obj - Table with the object to be serialized (table)
        -- @return String with string.representation of the object
        ------------------------------------------------------------------------
        serialize = function(obj)
            ------------------------------------------------------------------------
            --  attrs
            --  Serialize the table of attributes
            -- @param a - Table with the attributes of an element (table)
            -- @return String string.representation of the object
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
            if tt then
                if tt == "string" then
                    return self.Utils.escape(self.Utils.unescape(obj))
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
        end

        ------------------------------------------------------------------------
        --  insert_header
        --  Add header element (if it exists) to object
        -- Cleans old header element anywat
        -- @tparam obj - Object for insert new header (table)
        -- @tparam header - template header (table)
        -- @return header_template (table)
        ------------------------------------------------------------------------
        self.insert_header = function(obj, header)
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
        self.insert_header(envelope_templ, args.header or self.Header)

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
    local xml_header_template = '<?xml version="1.0"?>'
    local xml_header = xml_header_template
    if args.encoding then
        xml_header = xml_header:gsub('"%?>', '" encoding="' .. args.encoding .. '"?>')
    end

    local request_body = xml_header .. self.encode(args)
    self.Log.debug('SOAP Request: ' .. tostring(xml.eval(request_body)), self._debug)

    local request_sink, tbody = self.ltn12.sink.table()
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

    local mandatory_url = "Field `url' is mandatory"
    local url = {
        url = assert(args.url or self.url, mandatory_url),
        method = "POST",
        source = self.ltn12.source.string(request_body),
        sink = request_sink,
        headers = headers,
    }

    local suggested_layers = { http = "socket.http", https = "ssl.https", }
    local protocol = url.url:match "^(%a+)" -- protocol's name
    local mod = assert(
        self.client[protocol], '"'
            .. protocol
            .. '" protocol support unavailable. Try soap.CMDBuild.'
            .. protocol
            .. ' = require"'
            .. suggested_layers[protocol]
            .. '" to enable it.'
    )
    local request = assert(mod.request, 'Could not find request function on module soap.CMDBuild.' .. protocol)
    request(url)

    ------------------------------------------------------------------------
    --  retriveMessage
    --  The function truncates the additional information in the SOAP response
    -- @param response - SOAP response (table)
    -- @return resp - (string)
    ------------------------------------------------------------------------
    local function retriveMessage(response)
        ------------------------------------------------------------------------
        --  jtr
        --  Create lua table from SOAP response table
        -- @param text_array - SOAP (table)
        -- @return ret - (string)
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

    local error_handler = function(response)
        local _response = xml.eval(response)

        if _response:find'soap:Fault' then
            local fault = _response:find'soap:Fault':find'faultstring'[1]
            if fault then
                self.Log.error('SOAP Error: '..fault, self.verbose)
            end
        end
        if _response:find'ns2:return':find'ns2:totalRows' then
            local totalRows = tonumber(_response:find'ns2:return':find'ns2:totalRows'[1])
            if totalRows <= 0 then
                self.Log.error('SOAP Error: totalRows is nil', self.verbose)
            end
        end
        return response
    end

    local response = error_handler(retriveMessage(tbody))
    self.Log.debug('SOAP Response: ' .. tostring(xml.eval(response)), self._debug)

    return response
end

return CMDBuild
