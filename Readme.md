##API Info:
	doc/CMDBuild_WebserviceManual_ENG_V240.pdf 

##Required
	luasocket 3.0rc1-2 - luarocks install luasocket --local
	luaxml 101012-2 - luarocks install luaxml --local
	bit32 - luarocks install bit32 --local
	lib/base64.lua
  	argparse - luarocks install argparse --local

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
