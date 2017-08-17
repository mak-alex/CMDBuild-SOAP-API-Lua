LUA_DIR=/usr/local
LUA_LIBDIR=$(LUA_DIR)/lib/lua/5.1
LUA_SHAREDIR=$(LUA_DIR)/share/lua/5.1
HAS_LUACOV=$(shell lua -e "ok, luacov = pcall(require, 'luacov'); if ok then print('true') end")

install:
	mkdir -p $(LUA_SHAREDIR)/cmdbuild
	cp src/cmdbuild.lua $(LUA_SHAREDIR)/
	cp src/cmdbuild/* $(LUA_SHAREDIR)
	cp src/cmdbuild/* $(LUA_SHAREDIR)
	cp src/* $(LUA_SHAREDIR)

test: tests/cmdbuild.lua
ifeq ($(HAS_LUACOV), true)
	lua -lluacov $?
else
	lua $?
endif

.PHONY: install test
