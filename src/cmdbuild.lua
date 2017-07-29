--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
--         File:  CMDBuild.lua
--
--        Usage:  ./CMDBuild.lua
--
--  Description:  Библиотека для работы с CMDBuild SOAP API
--
--      Options:  ---
-- Requirements:  LuaXML, LuaSocket, LuaSec, LuaExpat, lib/base64.lua
--         Bugs:  ---
--        Notes:  ---
--       Author:  Alex M.A.K. (Mr), <alex-m.a.k@yandex.kz>
-- Organization:  Kazniie Innovation Ltd.
--      Version:  1.0
--      Created:  07/24/2017
--     Revision:  ---
--------------------------------------------------------------------------------
--

-- todo: добавить обработчик ошибок
-- todo: научить формить таблицу на выходе чтобы исключить Gate.lua
-- todo: избавиться от библиотеки LuaXML
-- todo: добавить человеческое логирование
-- todo: добавить описание методов и аргументов
-- todo: избавиться от повторяющихся действий
--

require "luarocks.loader"
require'LuaXML'
local XML = xml
local CMDBuild = {}
local mt = { __index = CMDBuild }
local base64 = require'lib.base64'

local assert, error, pairs, tonumber, tostring, type = assert, error, pairs, tonumber, tostring, type
local table = require"table"
local tconcat, tinsert, tremove = table.concat, table.insert, table.remove
local string = require"string"
local gsub, strfind, strformat = string.gsub, string.find, string.format
local max = require"math".max
local lom = require"lxp.lom"
local parse = lom.parse
local concat = require("table").concat

local ltn12 = require("ltn12")

local tescape = {
	['&'] = '&amp;',
	['<'] = '&lt;',
	['>'] = '&gt;',
	['"'] = '&quot;',
	["'"] = '&apos;',
}
---------------------------------------------------------------------
-- Escape special characters.
---------------------------------------------------------------------
local function escape (text)
	return (gsub (text, "([&<>'\"])", tescape))
end

local tunescape = {
	['&amp;'] = '&',
	['&lt;'] = '<',
	['&gt;'] = '>',
	['&quot;'] = '"',
	['&apos;'] = "'",
}
---------------------------------------------------------------------
-- Unescape special characters.
---------------------------------------------------------------------
local function unescape (text)
	return (gsub (text, "(&%a+%;)", tunescape))
end

local serialize

---------------------------------------------------------------------
-- Serialize the table of attributes.
-- @param a Table with the attributes of an element.
-- @return String representation of the object.
---------------------------------------------------------------------
local function attrs (a)
	if not a then
		return "" -- no attributes
	else
		local c = {}
		if a[1] then
			for i = 1, #a do
				local v = a[i]
				c[i] = strformat ("%s=%q", v, a[v])
			end
		else
			for i, v in pairs (a) do
				c[#c+1] = strformat ("%s=%q", i, v)
			end
		end
		if #c > 0 then
			return " "..tconcat (c, " ")
		else
			return ""
		end
	end
end

---------------------------------------------------------------------
-- Serialize the children of an object.
-- @param obj Table with the object to be serialized.
-- @return String representation of the children.
---------------------------------------------------------------------
local function contents (obj)
	if not obj[1] then
		return ""
	else
		local c = {}
		for i = 1, #obj do
			c[i] = serialize (obj[i])
		end
		return tconcat (c)
	end
end

---------------------------------------------------------------------
-- Serialize an object.
-- @param obj Table with the object to be serialized.
-- @return String with representation of the object.
---------------------------------------------------------------------
serialize = function (obj)
	local tt = type(obj)
	if tt == "string" then
		return escape(unescape(obj))
	elseif tt == "number" then
		return obj
	elseif tt == "table" then
		local t = obj.tag
		assert (t, "Invalid table format (no `tag' field)")
		return strformat ("<%s%s>%s</%s>", t, attrs(obj.attr), contents(obj), t)
	else
		return ""
	end
end

---------------------------------------------------------------------
-- @param attr Table of object's attributes.
-- @return String with the value of the namespace ("xmlns") field.
---------------------------------------------------------------------
local function find_xmlns (attr)
	for a, v in pairs (attr) do
		if strfind (a, "xmlns", 1, 1) then
			return v
		end
	end
end

---------------------------------------------------------------------
-- Add header element (if it exists) to object.
-- Cleans old header element anyway.
---------------------------------------------------------------------
local header_template = {
	tag = "soap:Header",
}
local function insert_header (obj, header)
	-- removes old header
	if obj[2] then
		tremove (obj, 1)
	end
	if header then
		header_template[1] = header
		tinsert (obj, 1, header_template)
	end
end

local envelope_template = {
	tag = "soap:Envelope",
	attr = { "xmlns:soap", "xmlns:soap1",
		["xmlns:soap1"] = "http://soap.services.cmdbuild.org", -- to be filled
		["xmlns:soap"] = "http://schemas.xmlsoap.org/soap/encoding/",
	},
	{
		tag = "soap:Body",
		[1] = {
			tag = nil, -- must be filled
			attr = {}, -- must be filled
		},
	}
}
local xmlns_soap = "http://schemas.xmlsoap.org/soap/envelope/"
local xmlns_soap12 = "http://www.w3.org/2003/05/soap-envelope"

---------------------------------------------------------------------
-- Converts a LuaExpat table into a SOAP message.
-- @param args Table with the arguments, which could be:
-- namespace: String with the namespace of the elements.
-- method: String with the method's name;
-- entries: Table of SOAP elements (LuaExpat's format);
-- header: Table describing the header of the SOAP envelope (optional);
-- internal_namespace: String with the optional namespace used
--	as a prefix for the method name (default = "");
-- soapversion: Number of SOAP version (default = 1.1);
-- @return String with SOAP envelope element.
---------------------------------------------------------------------
local function encode (args)
	if tonumber(args.soapversion) == 1.2 then
		envelope_template.attr["xmlns:soap"] = xmlns_soap12
	else
		envelope_template.attr["xmlns:soap"] = xmlns_soap
	end
	local xmlns = "xmlns"
	if args.internal_namespace then
		xmlns = xmlns..":"..args.internal_namespace
		args.method = args.internal_namespace..":"..args.method
	end
	-- Cleans old header and insert a new one (if it exists).
	insert_header (envelope_template, args.header)
	-- Sets new body contents (and erase old content).
	local body = (envelope_template[2] and envelope_template[2][1]) or envelope_template[1][1]
	for i = 1, max (#body, #args.entries) do
		body[i] = args.entries[i]
	end
	-- Sets method (actually, the table's tag) and namespace.
	body.tag = args.method
	body.attr[xmlns] = args.namespace
	return serialize (envelope_template)
end

-- Iterates over the children of an object.
-- It will ignore any text, so if you want all of the elements, use ipairs(obj).
-- @param obj Table (LOM format) representing the XML object.
-- @param tag String with the matching tag of the children
--	or nil to match only structured children (single strings are skipped).
-- @return Function to iterate over the children of the object
--	which returns each matching child.

local function list_children (obj, tag)
	local i = 0
	return function ()
		i = i+1
		local v = obj[i]
		while v do
			if type(v) == "table" and (not tag or v.tag == tag) then
				return v
			end
			i = i+1
			v = obj[i]
		end
		return nil
	end
end

---------------------------------------------------------------------
-- Converts a SOAP message into Lua objects.
-- @param doc String with SOAP document.
-- @return String with namespace, String with method's name and
--	Table with SOAP elements (LuaExpat's format).
---------------------------------------------------------------------
local function decode (doc)
	local obj = assert (parse (doc))
	local ns = obj.tag:match ("^(.-):")
	assert (obj.tag == ns..":Envelope", "Not a SOAP Envelope: "..
		tostring(obj.tag))
	local lc = list_children (obj)
	local o = lc ()
	-- Skip SOAP:Header
	while o and (o.tag == ns..":Header" or o.tag == "SOAP-ENV:Header") do
		o = lc ()
	end
	if o and (o.tag == ns..":Body" or o.tag == "SOAP-ENV:Body") then
		obj = list_children (o)()
	else
		error ("Couldn't find SOAP Body!")
	end

	local namespace = find_xmlns (obj.attr)
	local method = obj.tag:match ("%:([^:]*)$") or obj.tag
	local entries = {}
	for i = 1, #obj do
		entries[i] = obj[i]
	end
	return namespace, method, entries
end

local client = {
	_COPYRIGHT = "Copyright (C) 2004-2013 Kepler Project",
	_DESCRIPTION = "LuaSOAP provides a very simple API that convert Lua tables to and from XML documents",
	_VERSION = "LuaSOAP 3.0 client",

	-- Support for SOAP over HTTP is default and only depends on LuaSocket
	http = require("socket.http"),
}

local xml_header_template = '<?xml version="1.0"?>'

local mandatory_soapaction = "Field `soapaction' is mandatory for SOAP 1.1 (or you can force SOAP version with `soapversion' field)"
local mandatory_url = "Field `url' is mandatory"
local invalid_args = "Supported SOAP versions: 1.1 and 1.2.  The presence of soapaction field is mandatory for SOAP version 1.1.\nsoapversion, soapaction = "

local suggested_layers = {
	http = "socket.http",
	https = "ssl.https",
}

---------------------------------------------------------------------
-- Call a remote method.
-- @param args Table with the arguments which could be:
-- url: String with the location of the server.
-- soapaction: String with the value of the SOAPAction header.
-- namespace: String with the namespace of the elements.
-- method: String with the method's name.
-- entries: Table of SOAP elements (LuaExpat's format).
-- header: Table describing the header of the SOAP-ENV (optional).
-- internal_namespace: String with the optional namespace used
--  as a prefix for the method name (default = "").
-- soapversion: Number with SOAP version (default = 1.1).
-- @return String with namespace, String with method's name and
--	Table with SOAP elements (LuaExpat's format).
---------------------------------------------------------------------
function client.call(args)
	local soap_action, content_type_header
	if (not args.soapversion) or tonumber(args.soapversion) == 1.1 then
		soap_action = '"'..assert(args.soapaction, mandatory_soapaction)..'"'
		content_type_header = "text/xml;charset=UTF-8"
	elseif tonumber(args.soapversion) == 1.2 then
		soap_action = nil
		content_type_header = "application/soap+xml"
	else
		assert(false, invalid_args..tostring(args.soapversion)..", "..tostring(args.soapaction))
	end

	local xml_header = xml_header_template
	if args.encoding then
		xml_header = xml_header:gsub('"%?>', '" encoding="'..args.encoding..'"?>')
	end
	local request_body = xml_header..encode(args)
	local request_sink, tbody = ltn12.sink.table()
	local headers = {
		["Content-Type"] = content_type_header,
		["Content-Length"] = tostring(request_body:len()),
		["SOAPAction"] = soap_action,
	}
	if args.headers then
		for h, v in pairs (args.headers) do
			headers[h] = v
		end
	end
	local url = {
		url = assert(args.url, mandatory_url),
		method = "POST",
		source = ltn12.source.string(request_body),
		sink = request_sink,
		headers = headers,
	}

	local protocol = url.url:match"^(%a+)" -- protocol's name
	local mod = assert(client[protocol], '"'..protocol..'" protocol support unavailable. Try soap.client.'..protocol..' = require"'..suggested_layers[protocol]..'" to enable it.')
	local request = assert(mod.request, 'Could not find request function on module soap.client.'..protocol)
	local one_or_nil, status_code, headers, receive_status = request(url)
	local body = concat(tbody)

  local function retriveMessage(response)
    local resp=jtr(response)
    local istart,iend = resp:find('<soap:Envelope.*</soap:Envelope>');
    if(istart and iend) then
      return resp:sub(istart,iend);
    else
      return nil
    end
  end

  function jtr(text_array)
    local ret=""
    for i = 1,#text_array do if text_array[i] then ret=ret..text_array[i]; end end
    return ret;
  end

	return retriveMessage(tbody)
end
local Header = nil
local wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
local wssu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
local PassText="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText"

local Utils={}

function Utils.isempty(s)
  return (type(s) == "table" and next(s) == nil) or s == nil or s == ''
end

function Utils.isin(tab,what)
  if Utils.isempty(tab) then return false end
  for i=1,#tab do if tab[i] == what then return true end end

  return false
end

------------------------------------------------------------------------
--         Name:  CMDBuild:new
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  credentials - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:new(credentials, verbose, _debug)
  Header = {
    tag = "wsse:Security",
    attr = { ["xmlns:wsse"] = wsse },
    {
      tag = "wsse:UsernameToken",
      attr = { ["xmlns:wssu"] = wssu },
      { tag = "wsse:Username", credentials.username },
      { tag = "wsse:Password", attr = { ["Type"] = PassText}, credentials.password }
    }
  }
  return setmetatable(
    {
      url = credentials.url or 'http://'..credentials.ip..'/cmdbuild/services/soap/Webservices',
      verbose = verbose or true,
      _debug = _debug or false
    }, mt  
  )
end

------------------------------------------------------------------------
--         Name:  CMDBuild:create_lookup
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  lookup_type - {+DESCRIPTION+} ({+TYPE+})
--                code - {+DESCRIPTION+} ({+TYPE+})
--                description - {+DESCRIPTION+} ({+TYPE+})
--                id - {+DESCRIPTION+} ({+TYPE+})
--                notes - {+DESCRIPTION+} ({+TYPE+})
--                parent_id - {+DESCRIPTION+} ({+TYPE+})
--                position - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:create_lookup(lookup_type, code, description, id, notes, parent_id, position)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:createLookup",
    header = Header, 
    entries = {
      { tag = "soap1:lookup",	
        { tag = "soap1:code", code },
        { tag = "soap1:description", description }
      }
    }
  }
  if id then table.insert(request.entries[1], { tag = "soap1:id", id}) end
  if notes then table.insert(request.entries[1], { tag = "soap1:notes", notes}) end
  if parent_id and position then 
    table.insert(request.entries[1], { tag = "soap1:parent" })
    table.insert(request.entries[1], { tag = "soap1:parentId", parent_id })
    table.insert(request.entries[1], { tag = "soap1:position", position })
  end
  table.insert(request.entries[1], { tag = "soap1:type", lookup_type})

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:delete_lookup
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  lookup_id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:delete_lookup(lookup_id)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:deleteLookup",
    header = Header, 
    entries = {
      { tag = "soap1:lookup",	
        { tag = "soap1:lookupId", lookup_id },
      }
    }
  }

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:create_relation
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  domain_name - {+DESCRIPTION+} ({+TYPE+})
--                class1name - {+DESCRIPTION+} ({+TYPE+})
--                card1Id - {+DESCRIPTION+} ({+TYPE+})
--                class2name - {+DESCRIPTION+} ({+TYPE+})
--                card2Id - {+DESCRIPTION+} ({+TYPE+})
--                status - {+DESCRIPTION+} ({+TYPE+})
--                begin_date - {+DESCRIPTION+} ({+TYPE+})
--                end_date - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:create_relation(domain_name, class1name, card1Id, class2name, card2Id, status, begin_date, end_date)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:createRelation",
    header = Header, 
    entries = {
      { tag = "soap1:domainName", domain_name },
      { tag = "soap1:class1Name", class1name },
      { tag = "soap1:card1Id", card1Id },
      { tag = "soap1:class2Name", class2name },
      { tag = "soap1:card2Id", card2Id },
      { tag = "soap1:status", status },
      { tag = "soap1:beginDate", beginDate },
      { tag = "soap1:endDate", endDate },
    }
  }

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:delete_relation
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  domain_name - {+DESCRIPTION+} ({+TYPE+})
--                class1name - {+DESCRIPTION+} ({+TYPE+})
--                card1Id - {+DESCRIPTION+} ({+TYPE+})
--                class2name - {+DESCRIPTION+} ({+TYPE+})
--                card2Id - {+DESCRIPTION+} ({+TYPE+})
--                status - {+DESCRIPTION+} ({+TYPE+})
--                begin_date - {+DESCRIPTION+} ({+TYPE+})
--                end_date - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:delete_relation(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:deleteRelation",
    header = header, 
    entries = {
      { tag = "soap1:domainName", domain_name },
      { tag = "soap1:class1name", class1name },
      { tag = "soap1:card1id", card1id },
      { tag = "soap1:class2name", class2name },
      { tag = "soap1:card2id", card2id },
      { tag = "soap1:status", status },
      { tag = "soap1:begindate", begindate },
      { tag = "soap1:enddate", enddate },
    }
  }

  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:get_relation_list
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  domain_name - {+DESCRIPTION+} ({+TYPE+})
--                classname - {+DESCRIPTION+} ({+TYPE+})
--                id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:get_relation_list(domain_name, classname, id)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:getRelationList",
    header = header, 
    entries = {
      { tag = "soap1:domain", domain_name },
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", id },
    }
  }

  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

function CMDBuild:get_relation_history(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:getRelationHistory",
    header = header, 
    entries = {
      { tag = "soap1:domainName", domain_name },
      { tag = "soap1:class1name", class1name },
      { tag = "soap1:card1id", card1id },
      { tag = "soap1:class2name", class2name },
      { tag = "soap1:card2id", card2id },
      { tag = "soap1:status", status },
      { tag = "soap1:begindate", begindate },
      { tag = "soap1:enddate", enddate },
    }
  }

  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:get_lookup_list
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  lookup_type - {+DESCRIPTION+} ({+TYPE+})
--                value - {+DESCRIPTION+} ({+TYPE+})
--                need_parent_list - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:get_lookup_list(lookup_type, value, need_parent_list)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:getLookUpList",
    header = Header,
    entries = {
      { tag = "soap1:type", lookup_type },
    }
  }

  if value then table.insert(request.entries, { tag = "soap1:value", value}) end
  if need_parent_list then table.insert(request.entries, {tag = "soap1:parentList", true}) end
  
  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:get_lookup_translation_by_id
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  lookup_id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:get_lookup_translation_by_id(lookup_id)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:callFunction",
    header = Header,
    entries = {
      { tag = "soap1:functionName", "dbic_get_lookup_trans_by_id" },
      { tag = "soap1:params",
        { tag = "soap1:name", "itid" },
        { tag = "soap1:value", lookup_id}
      }
    }
  }
  
  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:start_workflow
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                attributes_list - {+DESCRIPTION+} ({+TYPE+})
--                metadata - {+DESCRIPTION+} ({+TYPE+})
--                complete_task - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:start_workflow(classname, attributes_list, metadata, complete_task)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:startWorkflow",
    header = Header,
    entries = {
      { tag = "soap1:card",	
        { tag = "soap1:className", classname },
        { tag = "soap1:id", card_id }
      }
    }
  }

  if attributes_list then
    for k, v in pairs(attributes_list) do
      table.insert(attributes, { tag = "soap1:attributeList", 
        { tag = "soap1:name", Utils.xml_escape(tostring(k)) },  
        { tag = "soap1:value", Utils.xml_escape(tostring(v)) },  
      })
    end
    table.insert(request.entries[1], attributes)
  end
  
  if metadata then
    table.insert(request.entries, { tag = "soap1:metadata", 
      { tag = "soap1:metadata",
        { tag = "soap1:key", metadata.key },
        { tag = "soap1:value", metadata.value }
      }  
    })
  end

  local ctask = complete_task or true
  if complete_task then
    table.insert(request.entries, { tag = "soap1:competeTask", tosstring(ctask) })
  end

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:update_workflow
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  process_id - {+DESCRIPTION+} ({+TYPE+})
--                attributes_list - {+DESCRIPTION+} ({+TYPE+})
--                complete_task - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:update_workflow(process_id, attributes_list, complete_task)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:startWorkflow",
    header = Header,
    entries = {
      { tag = "soap1:card",	
        { tag = "soap1:processId", process_id }
      }
    }
  }

  if attributes_list then
    for k, v in pairs(attributes_list) do
      table.insert(attributes, { tag = "soap1:attributeList", 
        { tag = "soap1:name", Utils.xml_escape(tostring(k)) },  
        { tag = "soap1:value", Utils.xml_escape(tostring(v)) },  
      })
    end
    table.insert(request.entries[1], attributes)
  end

  local ctask = complete_task or true
  if complete_task then
    table.insert(request.entries, { tag = "soap1:competeTask", tosstring(ctask) })
  end

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:upload_attachment
--      Purpose:  
--  Description:  
--   Parameters:  classname - {+DESCRIPTION+} (string)
--                card_id - {+DESCRIPTION+} (number)
--                file - {+DESCRIPTION+} (string)
--                filename - {+DESCRIPTION+} (string)
--                category - {+DESCRIPTION+} (string)
--                description - {+DESCRIPTION+} (string)
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:upload_attachment(classname, card_id, file, filename, category, description)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:uploadAttachment",
    header = header, 
    entries = {
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", card_id },
      { tag = "soap1:fileName", filename },
      { tag = "soap1:category", category },
      { tag = "soap1:description", description },
    }
  }

  if file then
    local i=io.open(file)
    table.insert(request.entries, { tag = "soap1:file", base64.encode(i.read'*a')})
    i:close()
  end

  -- todo: добавить открытие и конвертирование файла в base64
  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

function CMDBuild:download_attachment(classname, card_id, filename)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:downloadAttachment",
    header = header, 
    entries = {
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", card_id },
      { tag = "soap1:fileName", filename },
    }
  }

  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

function CMDBuild:delete_attachment(classname, card_id, filename)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:deleteAttachment",
    header = header, 
    entries = {
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", card_id },
      { tag = "soap1:fileName", filename },
    }
  }

  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

function CMDBuild:update_attachment(classname, card_id, filename, description)
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:updateAttachment",
    header = header, 
    entries = {
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", card_id },
      { tag = "soap1:fileName", filename },
      { tag = "soap1:description", description },
    }
  }

  local resp = client.call(request)
  return xml.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:create_card
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                attributes_list - {+DESCRIPTION+} ({+TYPE+})
--                metadata - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:create_card(classname, attributes_list, metadata)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:createCard",
    header = Header,
    entries = {
      { tag = "soap1:cardType" }
    }
  }

  table.insert(request.entries[1], { tag = "soap1:className", classname })

  if attributes_list then
    for k, v in pairs(attributes_list) do
      table.insert(attributes, { tag = "soap1:attributeList", 
        { tag = "soap1:name", Utils.xml_escape(tostring(k)) },  
        { tag = "soap1:value", Utils.xml_escape(tostring(v)) },  
      })
    end
    table.insert(request.entries[1], attributes)
  end
  
  if metadata then
    table.insert(request.entries[1], { tag = "soap1:metadata", 
      { tag = "soap1:metadata",
        { tag = "soap1:key", metadata.key },
        { tag = "soap1:value", metadata.value }
      }  
    })
  end

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:update_card
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                card_id - {+DESCRIPTION+} ({+TYPE+})
--                attributes_list - {+DESCRIPTION+} ({+TYPE+})
--                metadata - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:update_card(classname, card_id, attributes_list, metadata)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:updateCard",
    header = Header,
    entries = {
      { tag = "soap1:card",
        { tag = "soap1:className", classname },
        { tag = "soap1:id", card_id }
      }
    }
  }

  if attributes_list then
    for k, v in pairs(attributes_list) do
      table.insert(attributes, { tag = "soap1:attributeList", 
        { tag = "soap1:name", Utils.xml_escape(tostring(k)) },  
        { tag = "soap1:value", Utils.xml_escape(tostring(v)) },  
      })
    end
    table.insert(request.entries[1], attributes)
  end
  
  if metadata then
    table.insert(request.entries[1], { tag = "soap1:metadata", 
      { tag = "soap1:metadata",
        { tag = "soap1:key", metadata.key },
        { tag = "soap1:value", metadata.value }
      }  
    })
  end

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:delete_card
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                card_id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:delete_card(classname, card_id)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:deleteCard",
    header = Header,
    entries = {
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", card_id }
    }
  }
  
  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:get_card
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                card_id - {+DESCRIPTION+} ({+TYPE+})
--                attributes_list - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:get_card(classname, card_id, attributes_list)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:getCard",
    header = Header,
    entries = { }
  }
  if classname then
    table.insert(request.entries, { tag = "soap1:className", classname })
  end
  table.insert(request.entries, { tag = "soap1:cardId", card_id })
  if attributes_list then
    for k, v in pairs(attributes_list) do
      table.insert(attributes, { tag = "soap1:attributeList", 
        { tag = "soap1:name", Utils.xml_escape(tostring(k)) },  
        { tag = "soap1:value", Utils.xml_escape(tostring(v)) },  
      })
    end
    table.insert(request.entries, attributes)
  end
  
  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:get_card_history
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                card_id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:get_card_history(classname, card_id)
  local attributes = {}

  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:getCard",
    header = Header,
    entries = { 
      { tag = "soap1:className", classname },
      { tag = "soap1:cardId", card_id }
    }
  }
  
  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  CMDBuild:get_card_list
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                attributes_list - {+DESCRIPTION+} ({+TYPE+})
--                filter - {+DESCRIPTION+} ({+TYPE+})
--                filter_sq_operator - {+DESCRIPTION+} ({+TYPE+})
--                order_type - {+DESCRIPTION+} ({+TYPE+})
--                limit - {+DESCRIPTION+} ({+TYPE+})
--                offset - {+DESCRIPTION+} ({+TYPE+})
--                full_text_query - {+DESCRIPTION+} ({+TYPE+})
--                cql_query - {+DESCRIPTION+} ({+TYPE+})
--                cql_query_parameters - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function CMDBuild:get_card_list(classname, attributes_list, filter, filter_sq_operator, order_type, limit, offset, full_text_query, cql_query, cql_query_parameters)
  local attributes = {}
  local orders = {}
  local _limit = {}
  
  local request = {
    url = self.url,
    soapaction = '',
    method = "soap1:getCardList",
    header = Header,
    entries = {
      { tag = "soap1:className", classname },
    }
  }

  if attributes_list then
    for i=1, #attributes_list do
      attributes[i]= { tag = "soap1:attributesList", 
        { tag = "soap1:name", attributes_list[i] }
      }
    end
    table.insert(request.entries, attributes_list)
  end

  if filter or filter_sq_operator then
    if filter and not filter_sq_operator then
      local filters = {}
      filters = { tag = "soap1:queryType",
        { tag = "soap1:filter", 
          { tag = "soap1:name", filter.name },
          { tag = "soap1:operator", filter.operator },
          { tag = "soap1:value", filter.value }
        }
      }
      table.insert(request.entries, filters)
    end

    if not filter and filter_sq_operator then
      local filters = { tag = "soap1:filterOperator" }
      for i=1, #filter_sq_operator do
        filters[1] = { tag = "soap1:operator", filter_sq_operator.operator }

        if type(filter_sq_operator.subquery) == 'table' then
          for j=1, #filter_sq_operator.subquery do
            filters[1] = { tag = "soap1:subquery",
              { tag = "soap1:filter", 
                { tag = "soap1:name", filter_sq_operator[i].subquery[j].name }, 
                { tag = "soap1:operator", filter_sq_operator[i].subquery[j].operator }, 
                { tag = "soap1:value", filter_sq_operator[i].subquery[j].value }, 
              }
            }
          end
        else
          filters[1] = { tag = "soap1:subquery",
            { tag = "soap1:name", filter_sq_operator[i].subquery.name }, 
            { tag = "soap1:operator", filter_sq_operator[i].subquery.operator }, 
            { tag = "soap1:value", filter_sq_operator[i].subquery.value }, 
          }
        end
      end
    end
    table.insert(request.entries, filters)
  end
  if order_type then
    orders = { tag = "soap1:orderType",
      { tag = "soap1:columnName", order_type.columnName },
      { tag = "soap1:type", order_type.type },
    }
    table.insert(request.entries, orders)
  end

  if limit then
    table.insert(request.entries, { tag = "soap:limit", limit })
  end

  if offset then
    table.insert(request.entries, { tag = "soap1:offset", offset })
  end
  
  if full_text_query then
    table.insert(request.entries, { tag = "soap1:fullTextQuery", full_text_query })
  end

  if cql_query then
    local _cql_query = { tag = "soap1:cqlQuery",
      { tag = "soap1:cqlQuery", cql_query }
    }
    if cql_query_parameters then
      _cql_query = { tag = "soap1:parameters",
        { tag = "soap1:key", cql_query_parameters.key },
        { tag = "soap1:value", cql_query_parameters.value }
      }
    end
    table.insert(request.entries, _cql_query)
  end

  local resp = client.call(request)
  return XML.eval(resp):find'ns2:return'
end

------------------------------------------------------------------------
--         Name:  dump
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  prefix - {+DESCRIPTION+} ({+TYPE+})
--                a - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

local function dump (prefix, a) 
  local function getArgs(fun)
    local args = {}
    local hook = debug.gethook()

    local argHook = function( ... )
      local info = debug.getinfo(3)
      if 'pcall' ~= info.name then return end

      for i = 1, math.huge do
        local name, value = debug.getlocal(2, i)
        if '(*temporary)' == name then
          debug.sethook(hook)
          error('')
          return
        end
        table.insert(args,name)
      end
    end

    debug.sethook(argHook, "c")
    pcall(fun)

    return args
  end

  local function escapeCSV (s)
    if string.find(s, '[,"]') then s = '"' .. string.gsub(s, '"', '""') .. '"' end
    return s
  end

  local function toCSV (tt)
    local s = ""
    for _,p in ipairs(tt) do  s = s .. ", " .. escapeCSV(p) end
    return string.sub(s, 2)      -- remove first comma
  end

  for i,v in pairs (a) do
    if type(v) == "table" then
      dump(prefix .. '.' .. i,v)
    elseif type(v) == "function" then
      print (prefix .. ':' .. i .. '('..toCSV(getArgs(v))..')')
    end 
  end
end


if (arg ~= nil) then
  local func = 'enc'
  for n,v in ipairs(arg) do
    if (n > 0) then
      if (v == "-h") then dump("CMDBuild", CMDBuild) break end
    end
  end
end

local argparse = require "lib.ArgParse"

local parser = argparse("script", "An example.")
parser:flag("-l --list", "List all methods")
parser:option("-c --credentials", "Set username and password for authorization in CMDBuild"):args(2)
parser:option("-i --ip", "IP address for connect in CMDBuild")
parser:option("-g --get_card_list", "Get card list, ex('Hosts')", nil)
parser:option("-f --filter", "ex.(name operator value)"):args("*")

local args = parser:parse()
if args.list then dump("CMDBuild", CMDBuild) end
if args.credentials and args.ip then
  local cmdbuild = CMDBuild:new{
    username = args.credentials[1],
    password = args.credentials[2],
    ip = args.ip
  }
  if args.get_card_list then
    local filter
    if args.filter then
      filter = { name = args.filter[1], operator = args.filter[2], value = args.filter[3] }
    end
    local resp = cmdbuild:get_card_list(args.get_card_list, nil, filter)
    print(resp)
  end
end

return CMDBuild