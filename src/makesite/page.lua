local M = {}

local reqbase = (...):match('(.-)[^%.]+$')
local path = require(reqbase .. 'path')
local html = require(reqbase .. 'html')

local atbyte = ('@'):byte(1)
local slashbyte = ('/'):byte(1)

local Page = {
  __name = 'Page',
  content = function()
    return false
  end,
}
Page.__index = Page

function M.new(ppath, meta, content)
  return setmetatable({
    path = ppath,
    meta = meta or {},
    content = content or function()
      return false
    end,
  }, Page)
end

function Page:save(layout)
  local p = self.path
  if p:byte(-1) == slashbyte then
    p = p .. 'index.html'
  end
  path.update(path.todest(p), html.rendertostring(layout(self)))
  self.content = nil
end

function Page:abs(p)
  if not p:find('^/') then
    p = assert(self.path:match('.*/')) .. p
  end
  return p
end

function Page:rel(p)
  local d = self.path:match('.*/')
  if p:sub(1, #d) ~= d then
    return p
  end
  p = p:sub(#d + 1)
  if p == '' then
    p = '.'
  end
  return p
end

local function fix_file(s)
  if not s then
    return '=(load)'
  end
  if s:byte(1) == atbyte then
    return s:sub(2)
  end
  return s
end

local function eval_meta(src, file)
  local iopen, eopen, eqs = src:find('^%[(%=*)%[')
  if not iopen then
    return {}, 1
  end
  local iclose, eclose = src:find(string.format(']%s]', eqs), eopen + 1, true)
  if not iclose then
    error(string.format('%s:1: closing ]%s] not found', fix_file(file), eqs), 0)
  end
  local env = setmetatable({}, { __index = _G })
  local fn, err = load(src:sub(eopen + 1, iclose - 1), file, 't', env)
  if not fn then
    error(err, 0)
  end
  fn()
  return setmetatable(env, nil), eclose
end

local function eval_content(src, file, pos, ctx)
  -- Skip leading whitespace.
  pos = select(2, src:find('^[ \t\r\n]*', pos + 1))
  pos = pos + 1

  local n = 0
  local strings = {}
  local args = {}

  local chunk = coroutine.wrap(function()
    local yield = coroutine.yield

    local inewline = src:find('\n', 1, true) or #src + 1
    local line = 1

    yield('local c, a, f = ...; return {')

    while true do
      n = n + 1

      local iopen, eopen, eqs, name = src:find('%[(%=*)%[([a-zA-Z][a-zA-Z0-9_]*)%s*', pos)

      if not iopen then
        strings[n] = src:sub(pos)
        break
      end

      strings[n] = src:sub(pos, iopen - 1)

      local prev = line
      while inewline < iopen do
        inewline = src:find('\n', inewline + 1, true) or #src + 1
        line = line + 1
      end
      if line > prev then
        yield(string.rep('\n', line - prev))
      end

      local iclose, eclose = src:find(string.format('%%s*%%]%s%%]', eqs), eopen + 1)
      if not iclose then
        error(
          string.format(
            '%s:%d: closing ]%s] not found for method %s',
            fix_file(file),
            line,
            eqs,
            name
          ),
          0
        )
      end

      args[n] = src:sub(eopen + 1, iclose - 1)
      yield(string.format('c:%s(a[%d], f, %d),', name, n, line))

      pos = eclose + 1
    end
    yield('}')
  end)

  local values = assert(load(chunk, file, 't'))(ctx, args)
  return function(write)
    local render = html.render
    for i = 1, n do
      write(strings[i])
      render(write, values[i])
    end
  end
end

function M.loadstring(ppath, src, name)
  name = name or '=(string)'
  local meta, ehead = eval_meta(src, name)
  local content = function(ctx)
    return eval_content(src, name, ehead, ctx)
  end
  return M.new(ppath, meta, content)
end

function M.load(filename)
  local p = filename:match('^[^/]+(/.*)')
  if p:find('/index%.html$') then
    p = p:sub(1, -11)
  end
  return M.loadstring(p, path.read(filename), '@' .. filename)
end

return M
