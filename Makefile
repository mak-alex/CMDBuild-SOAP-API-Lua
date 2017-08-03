FILENAME=src/main.lua
LUALIB=/usr/include/lua5.1
LUARLIB=~/.luarocks/lib/lua/5.1/ 
LUAH=/usr/lib/x86_64-linux-gnu/liblua5.1.a #/usr/lib/liblua.a
Z2CLIB= $(wildcard lib/*.lua) $(wildcard src/include/*.lua)
LUASTATIC=./luastatic
BIN=bin/cmdbuild
CLEAN=src/main.lua.c bin/cmdbuild

export SCR_HOME=$(shell pwd)

build:
	$(LUASTATIC) $(FILENAME) $(Z2CLIB) $(LUAH) -I$(LUALIB) -I$(LUARLIB) -o $(BIN);

clean:
	$(RM) $(CLEAN)

units:
	for test in $(wildcard tests/*.lua); do \
		lua $$test; \
	done
