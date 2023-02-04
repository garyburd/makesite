export LUA_PATH := ${CURDIR}/src/?.lua;$(LUA_PATH)

.PHONY: test check coverage docs serve

test:
	lua test/test.lua

coverage:
	lua -lluacov test/test.lua
	luacov

check:
	luacheck --no-color --no-redefined --std lua54 src/makesite/*.lua test/*.lua example/main.lua

docs:
	lua example/main.lua

serve:
	python3 -m http.server --directory docs


