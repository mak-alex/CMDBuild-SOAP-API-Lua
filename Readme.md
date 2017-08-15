##API Info:
	doc/CMDBuild_WebserviceManual_ENG_V240.pdf 

##Required
	luasocket 3.0rc1-2 - luarocks install luasocket --local
	luaxml 101012-2 - luarocks install luaxml --local
	bit32 - luarocks install bit32 --local
	lib/*.lua
  	argparse - luarocks install argparse --local

##Example
```
	-- include cmdbuild module
	local cmdbuild=require'src.cmdbuild':new{
		username='admin, 
		password='password', 
		ip='localhost' -- or maybe url = 'http://localhost/services/soap/Webservices'
	}
	local response = CMDBuild.Card:get().menu_schema()
	print(utils.pretty(response))
```
