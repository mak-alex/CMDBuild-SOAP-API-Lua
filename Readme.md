# CMDBuild SOAP API Wrapper
![Alt text](http://www.cmdbuild.org/logo.png)![Alt text](http://www.rozek.de/Lua/Lua-Logo_128x128.png)

CMDBuild is an open source software to manage the configuration database (CMDB).
CMDBuild is compliant with ITIL "best practices" for the IT services management according to process-oriented criteria.

###CMDBuild Webservice Manual:
	doc/CMDBuild_WebserviceManual_ENG_V240.pdf 

###Dependencies
	luasocket 3.0rc1-2 - luarocks install luasocket --local
	luaxml 101012-2 - luarocks install luaxml --local
	bit32 - luarocks install bit32 --local
	lua-cjson - luarocks install lua-cjson --local

```
	CMDBuild.Card:get(classname).list(attributes_list, filter, filter_sq_operator, order_type, limit, offset, full_text_query, cql_query, cql_query_parameters)
	CMDBuild.Card:get(classname).card(card_id, {attributes})
	CMDBuild.Card:create(classname, {your_attributes}, {your_metadata})
	CMDBuild.Card:delete(classname, card_id)
	CMDBuild.Card:update(classname, card_id, {your_attributes}, {your_metadata})
	
	CMDBuild.Workflow:start(classname, {your_attributes}, {your_metadata}, complete_task)
	CMDBuild.Workflow:update(processid, {your_attributes}, complete_task)
	CMDBuild.Workflow:resume(processid, {your_attributes}, complete_task)
	
	CMDBuild.Attachment:upload(classname, card_id, file, filename, category, description)
	CMDBuild.Attachment:download(classname, card_id, filename)
	CMDBuild.Attachment:delete(classname, card_id, filename)
	CMDBuild.Attachment:update(classname, card_id, filename, description)
	
	CMDBuild.Lookup:get(lookup_type).list(value, parent_list)
	CMDBuild.Lookup:get(lookup_type).list_by_code(code, parent_list)
	CMDBuild.Lookup:get().by_id(lookup_id)
	CMDBuild.Lookup:get().translation_by_id(lookup_id)
	CMDBuild.Lookup:create(lookup_type, code, description, id, notes, parent_id, position)
	CMDBuild.Lookup:delete(lookup_id)
	CMDBuild.Lookup:update(lookup_type, code, description, id, notes, parent_id, position)
	
	CMDBuild.Relation:get(domain_name).list(classname, id)
	CMDBuild.Relation:get(domain_name).attributes(classname, id)
	CMDBuild.Relation:get(domain_name).list_ext(classname, id)
	CMDBuild.Relation:get(domain_name).history(class1name, card1id, class2name, card2id, status, begin_date, end_date)
	CMDBuild.Relation:create(domain_name, class1name, card1Id, class2name, card2Id, status, begin_date, end_date)
	CMDBuild.Relation:create_with_attributes(domain_name, class1name, card1Id, class2name, card2Id, status, begin_date, end_date, attributes)
	CMDBuild.Relation:delete(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
```

### Install
	luarocks install cmdbuild --local
	# or 
	git clone https://bitbucket.org/enlab/cmdbuild_soap_api # and install dependencies
	
###Usage
```
  require'luarocks.loader'
  local cmdbuild=require'cmdbuild':new('CMDBuidlPID', false, true, false)
  cmdbuild:set_credentials{
    username='login', 
    password='password', 
    ip='localhost' -- or maybe url = 'http://localhost/services/soap/Webservices'
  }.insertHeader()
  local response = cmdbuild.Card:get('Hosts').list()
  response.decode().tprint()
```

#### Please report error with the hashtag **#cmdbuild_soap_api** to the mail <alex-m.a.k@yandex.kz>
