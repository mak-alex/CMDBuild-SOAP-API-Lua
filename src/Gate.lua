--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
--         File:  CMDBGate.lua
--
--        Usage:  ./CMDBGate.lua
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

require'luarocks.loader'
local CMDBuild = require'src.cmdbuild'

local Gate = {}
local mt = { __index  = Gate }
local soap=nil

local Utils={}

function Utils.isempty(s)
  return (type(s) == "table" and next(s) == nil) or s == nil or s == ''
end

function Utils.isin(tab,what)
  if Utils.isempty(tab) then return false end
  for i=1,#tab do if tab[i] == what then return true end end

  return false
end

function Gate:new(credentials, verbose, _debug)
  return setmetatable(
    {
      username = assert(credentials.username, '`\username\' can\'t be empty'),
      password = assert(credentials.password, '`\password\' can\'t be empty'),
      url = "http://" .. credentials.ip .. '/cmdbuild/services/soap/Webservices',
      Locations = {},
      hasLocations = false,
      verbose = verbose or true,
      _debug = _debug or false  
    },mt  
  )
end

function Gate:auth()
  soap = CMDBuild:new{ username = self.username, password = self.password , url = self.url }
  self:get_locations()
  return soap
end
  
function Gate:load_cards(classname, attributes, filter, ignoreFields, onCardLoad)
  local xmltab=soap:get_card_list(classname, attributes, filter)

  local outtab={}
  outtab["Id"]={}

  for i=1,#xmltab
  do
    id=xmltab[i]:find("ns2:id")
    if id ~= nil
    then
      id=id[1]
      for j=1, #xmltab[i]
      do
        local attrList=xmltab[i][j]:find("ns2:attributeList")
        if attrList ~= nil
        then
          local key=attrList:find("ns2:name")
          local value=attrList:find("ns2:value") or ""
          local code=attrList:find("ns2:code") or ""
          if key ~= nil and not Utils.isin(ignoreFields,key[1])
          then
            key = key[1]
            value = value[1]
            code = code[1]

            if outtab.Id[tostring(id)] == nil
            then
              outtab.Id[tostring(id)]={}
            end
            if code == nil
            then
              outtab.Id[tostring(id)][key]=value
            else
              outtab.Id[tostring(id)][key]={["value"]=value,["code"]=code}
            end
          end
        end
      end
      if onCardLoad ~= nil
      then
        onCardLoad(outtab,tostring(id))
      end
    end
  end
  return outtab
end

function Gate:create_card(classname, attributes)
  return soap:create_card(classname, attributes)
end

function Gate:update_card(classname, id, attributes)
  return soap:update_card(classname, id, attributes)
end

function Gate:delete_card(classname, id)
  return soap:delete_card(classname, id)
end

function Gate:start_workflow(classname, attributes, metadata, complete_task)
  return soap:start_workflow(classname, attributes, metadata, compete_task)
end

function Gate:get_locations()
  local ignore={"Code","PLZ","Notes","techsupport","BuildingNr","Street"}
  local outtab={}


  outtab["Description2Id"]={}
  outtab["Id2Description"]={}
  outtab["Id2LocationID"]={}
  outtab["LocationID2Id"]={}
  outtab["Id"]={}

   outtab.Id=self:load_cards(
    "Locations",nil,nil,ignore,
    function(otab,_id)
      outtab.Description2Id[otab.Id[_id]["Description"]]=_id
      outtab.Id2Description[_id]=otab.Id[_id]["Description"]
      outtab.Id2LocationID[_id]=otab.Id[_id]["LocationID"]
      outtab.LocationID2Id[otab.Id[_id]["LocationID"]]=_id
    end
  )
  self.hasLocations = true
  self.Locations = outtab
  
  return self.Locations
end

function Gate:get_location_id_by_name(name)
  return self.Locations.Description2Id[name]
end

function Gate:get_location_by_name(name)
  return self.Locations.Id[self.Locations.Description2Id[name]]
end

function Gate:get_location_by_id(Id)
  return self.Locations.Id.Id[Id] 
end

function Gate:get_location_with_name_like_this_one(name)
  local outtab={}
  for key, value in pairs(self.Locations.Description2Id) do
    table.insert(outtab, value)
  end
  return outtab
end

function Gate:get_location_id_by_id(id)
  return self.Locations.LocationID2Id[id]
end

function Gate:get_location_description_by_id(id)
  return self.Locations.Id2Description[self:get_location_id_by_id(id)]
end

function Gate:get_hosts_for_location_id(id)
  return self:load_cards(
    "Hosts", nil, { name = "Location", operator = 'EQUALS', value = id }
  )
end

function Gate:get_items_for_host_id(id)
  return self:load_cards(
    "zItems", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_triggers_for_host_id(id)
  return self:load_cards(
    "ztriggers", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_applications_for_host_id(id)
  return self:load_cards(
    "zapplications", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_interface_for_host_id(id)
  return self:load_cards(
    "zinterfaces", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_items_for_template_id(id)
  return self:load_cards(
    "zItems", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_triggers_for_template_id(id)
  return self:load_cards(
    "ztriggers", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_applications_for_template_id(id)
  return self:load_cards(
    "zapplications", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

function Gate:get_interface_for_template_id(id)
  return self:load_cards(
    "zinterfaces", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

return Gate
