##API Info:
	doc/CMDBuild_WebserviceManual_ENG_V240.pdf 

##Required
	luaexpat 1.3.0-1
	luasocket 3.0rc1-2
	luaxml 101012-2
	bit32
	lib/base64.lua
  	lib/ArgParse.lua

##Example
```
	-- include cmdbuild module
	local cmdbuild=require'src.cmdbuild'
	 -- create new instance
	cmdbuild:new{
		username='admin, 
		password='3$rFvCdE', 
		ip='10.244.244.128'
	}
	-- get cards and print table
	table.foreach(
		cmdbuild:get_card_list("Hosts").Id, 
		print
	)
```
	lua src/cmdbuild.lua -h
