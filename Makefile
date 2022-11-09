export LUA_PATH := ./src/?.lua;$(LUA_PATH)

.PHONY: test check coverage

test:
	lua test/test.lua

coverage:
	lua -lluacov test/test.lua
	luacov

check:
	luacheck --no-color --no-redefined --std lua54 src/makesite/*.lua test/*.lua
