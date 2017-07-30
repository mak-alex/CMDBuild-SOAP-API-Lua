--- vim: ts=2 tabstop=2 shiftwidth=2 expandtab
--
--------------------------------------------------------------------------------
--         File:  CMDBGate.lua
--
--        Usage:  ./CMDBGate.lua
--
--  Description:  Обертка над cmdbuild.lua, используется во многих скриптах
--  import/export/create_host/create_incident и т.д., поэтому привел ее в
--  порядок
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

------------------------------------------------------------------------
--         Name:  Utils.isempty
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  s - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Utils.isempty(s)
  return (type(s) == "table" and next(s) == nil) or s == nil or s == ''
end

------------------------------------------------------------------------
--         Name:  Utils.isin
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  tab - {+DESCRIPTION+} ({+TYPE+})
--                what - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Utils.isin(tab,what)
  if Utils.isempty(tab) then return false end
  for i=1,#tab do if tab[i] == what then return true end end

  return false
end

------------------------------------------------------------------------
--         Name:  Gate:new
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  credentials - {+DESCRIPTION+} ({+TYPE+})
--                verbose - {+DESCRIPTION+} ({+TYPE+})
--                _debug - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

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

------------------------------------------------------------------------
--         Name:  Gate:auth
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  -
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:auth()
  soap = CMDBuild:new{ username = self.username, password = self.password , url = self.url }
  return soap
end
  
------------------------------------------------------------------------
--         Name:  Gate:loadCards
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                attributes - {+DESCRIPTION+} ({+TYPE+})
--                filter - {+DESCRIPTION+} ({+TYPE+})
--                ignoreFields - {+DESCRIPTION+} ({+TYPE+})
--                onCardLoad - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:loadCards(classname, attributes, filter, ignoreFields, onCardLoad)
  local xmltab=soap:getCardList(classname, attributes, filter)

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

------------------------------------------------------------------------
--         Name:  Gate:createCard
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                attributes - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:createCard(classname, attributes)
  return soap:createCard(classname, attributes)
end

------------------------------------------------------------------------
--         Name:  Gate:updateCard
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                id - {+DESCRIPTION+} ({+TYPE+})
--                attributes - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:updateCard(classname, id, attributes)
  return soap:updateCard(classname, id, attributes)
end

------------------------------------------------------------------------
--         Name:  Gate:deleteCard
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:deleteCard(classname, id)
  return soap:deleteCard(classname, id)
end

------------------------------------------------------------------------
--         Name:  Gate:startWorkflow
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  classname - {+DESCRIPTION+} ({+TYPE+})
--                attributes - {+DESCRIPTION+} ({+TYPE+})
--                metadata - {+DESCRIPTION+} ({+TYPE+})
--                complete_task - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:startWorkflow(classname, attributes, metadata, complete_task)
  return soap:startWorkflow(classname, attributes, metadata, compete_task)
end

------------------------------------------------------------------------
--         Name:  Gate:getLocations
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  -
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocations()
  local ignore={"Code","PLZ","Notes","techsupport","BuildingNr","Street"}
  local outtab={}


  outtab["Description2Id"]={}
  outtab["Id2Description"]={}
  outtab["Id2LocationID"]={}
  outtab["LocationID2Id"]={}
  outtab["Id"]={}

   outtab.Id=self:loadCards(
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

------------------------------------------------------------------------
--         Name:  Gate:getLocationIdByName
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  name - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationIdByName(name)
  if not self.Loacations then self:getLocations() end
  return self.Locations.Description2Id[name]
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationByName
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  name - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationByName(name)
  if not self.Loacations then self:getLocations() end
  return self.Locations.Id[self.Locations.Description2Id[name]]
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationById
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  Id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationById(Id)
  if not self.Loacations then self:getLocations() end
  return self.Locations.Id.Id[Id] 
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationWithNameLikeThisOne
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  name - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationWithNameLikeThisOne(name)
  if not self.Loacations then self:getLocations() end
  local outtab={}
  for key, value in pairs(self.Locations.Description2Id) do
    local found = string.find(key,name)
    if found then
      table.insert(outtab, value)
    end
  end
  return outtab
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationIdByID
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationIdByID(id)
  if not self.Loacations then self:getLocations() end
  return self.Locations.LocationID2Id[id]
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationDescriptionByID
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

------------------------------------------------------------------------
--         Name:  Gate:getLocationDescriptionByID
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationDescriptionByID(id)
  if not self.Loacations then self:getLocations() end
  return self.Locations.Id2Description[self:get_location_id_by_id(id)]
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationDescriptionById
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationDescriptionById(id)
  if not self.Loacations then self:getLocations() end
  return self.Locations.Id2Description[id]
end

------------------------------------------------------------------------
--         Name:  Gate:getLocationHosts
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getLocationHosts(id)
  return self:loadCards(
    'Hosts',
    nil,
    {
      name = 'Location',
      operator = 'EQUALS',
      value = id
    }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getHostItems
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getHostItems(id)
  return self:loadCards(
    "zItems", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getHostTriggers
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getHostTriggers(id)
  return self:loadCards(
    "ztriggers", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getHostApplications
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getHostApplications(id)
  return self:loadCards(
    "zapplications", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getHostInterfaces
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getHostInterfaces(id)
  return self:loadCards(
    "zinterfaces", nil, { name = "hostid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getTemplateItems
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getTemplateItems(id)
  return self:loadCards(
    "zItems", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getTemplateTriggers
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getTemplateTriggers(id)
  return self:loadCards(
    "ztriggers", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getTemplateApplications
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getTemplateApplications(id)
  return self:loadCards(
    "zapplications", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

------------------------------------------------------------------------
--         Name:  Gate:getTemplateInterfaces
--      Purpose:  
--  Description:  {+DESCRIPTION+}
--   Parameters:  id - {+DESCRIPTION+} ({+TYPE+})
--      Returns:  {+RETURNS+}
------------------------------------------------------------------------

function Gate:getTemplateInterfaces(id)
  return self:loadCards(
    "zinterfaces", nil, { name = "templateid", operator = 'EQUALS', value = id }
  )
end

return Gate
