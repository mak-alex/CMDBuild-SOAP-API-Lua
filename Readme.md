# CMDBuild SOAP API Wrapper
CMDBuild is an open source software to manage the configuration database (CMDB).
CMDBuild is compliant with ITIL "best practices" for the IT services management according to process-oriented criteria.

##API Info:
	doc/CMDBuild_WebserviceManual_ENG_V240.pdf 

##Required
	luasocket 3.0rc1-2 - luarocks install luasocket --local
	luaxml 101012-2 - luarocks install luaxml --local
	bit32 - luarocks install bit32 --local
	lua-cjson - luarocks install lua-cjson --local
	lib/*.lua

##Example
```
	-- include cmdbuild module
	local cmdbuild=require'src.cmdbuild':new('CMDBuidlPID', false, true, false)
	cmdbuild:set_credentials{
		username='admin, 
		password='password', 
		ip='localhost' -- or maybe url = 'http://localhost/services/soap/Webservices'
	}
	local response = CMDBuild.Card:get('Hosts').list()
	response.decode().tprint()
	---- MORE EXAMPLE ----
	-- local response CMDBuild.Card:get('Hosts').list(nil, {name='Id',operator='EQUALS',value=1923934})
	-- local response = CMDBuild.Card:get('Hosts').card(1923934)
	-- local response = CMDBuild.Card:create('Hosts', {your_attributes}, {your_metadata})
	-- local response = CMDBuild.Card:delete('Hosts', card_id)
	-- local response = CMDBuild.Card:update('Hosts', card_id, {your_attributes}, {your_metadata})
	-- local response = CMDBuild.Workflow:start(classname, {your_attributes}, {your_metadata}, complete_task)
	-- local response = CMDBuild.Workflow:update(processid, {your_attributes}, complete_task)
	-- local response = CMDBuild.Workflow:resume(processid, {your_attributes}, complete_task)
	-- local response = CMDBuild.Attachment:upload(classname, card_id, file, filename, category, description)
	-- local response = CMDBuild.Attachment:download(classname, card_id, filename)
	-- local response = CMDBuild.Attachment:delete(classname, card_id, filename)
	-- local response = CMDBuild.Attachment:update(classname, card_id, filename, description)
	-- local response = CMDBuild.Lookup:get().list(lookup_type, value, parent_list)
	-- local response = CMDBuild.Lookup:get().list_by_code(lookup_type, code, parent_list)
	-- local response = CMDBuild.Lookup:get().by_id(lookup_id)
	-- local response = CMDBuild.Lookup:get().translation_by_id(lookup_id)
	-- local response = CMDBuild.Lookup:create(lookup_type, code, description, id, notes, parent_id, position)
	-- local response = CMDBuild.Lookup:delete(lookup_id)
	-- local response = CMDBuild.Lookup:update(lookup_type, code, description, id, notes, parent_id, position)
	-- local response = CMDBuild.Relation:get().list(domain_name, classname, id)
	-- local response = CMDBuild.Relation:get().attributes(domain_name, classname, id)
	-- local response = CMDBuild.Relation:get().list_ext(domain_name, classname, id)
	-- local response = CMDBuild.Relation:get().history(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
	-- local response = CMDBuild.Relation:create(domain_name, class1name, card1Id, class2name, card2Id, status, begin_date, end_date)
	-- local response = CMDBuild.Relation:create_with_attributes(domain_name, class1name, card1Id, class2name, card2Id, status, begin_date, end_date, attributes)
	-- local response = CMDBuild.Relation:delete(domain_name, class1name, card1id, class2name, card2id, status, begin_date, end_date)
```

Please report error with the hashtag #cmdbuild_soap_api to the mail <alex-m.a.k@yandex.kz>
