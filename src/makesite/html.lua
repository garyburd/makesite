local M = {}

local html_escapes = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
}

function M.render(value)
  local n = 0
  local result = {}
  local function write(s)
    n = n + 1
    result[n] = s
  end
  local function encode(v)
    if v then
      if type(v) == 'function' then
        v(encode, write)
      else
        write((tostring(v):gsub('[&><>]', html_escapes)))
      end
    end
  end
  encode(value)
  return table.concat(result)
end

function M.raw(s)
  assert(type(s) == 'string')
  return function(_, write)
    write(s)
  end
end

function M.list(list)
  assert(type(list) == 'table')
  return function(encode)
    for i = 1, #list do
      encode(list[i])
    end
  end
end

function M.map(list, fn, sep)
  assert(type(list) == 'table')
  local n = 0
  local mapped = {}
  for i, v in ipairs(list) do
    m = fn(v)
    if m then
      n = n + 1
      mapped[n] = m
    end
  end
  if n == 0 then
    return false
  end
  sep = sep and M.render(sep) or ''
  return function(encode, write)
    encode(mapped[1])
    for i = 2, n do
      write(sep)
      encode(mapped[i])
    end
  end
end

local attr_escapes = {
  ['&'] = '&amp;',
  ['"'] = '&quot;',
}

local function write_attrs(elt, write)
  -- Sort attribute names for stable output.
  -- Skip attributes with falsy values.
  local names = {}
  for name, value in pairs(elt) do
    if type(name) == 'string' and value then
      names[#names + 1] = name
    end
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local value = elt[name]
    name = name:gsub('_', '-')
    if value == true then
      write(string.format(' %s', name))
    else
      value = tostring(value):gsub('[&"]', attr_escapes)
      if #value > 0 and not value:find('[ \t\r\n"\'=<>`]') then
        -- unquoted syntax allowed.
        write(string.format(' %s=%s', name, value))
      else
        write(string.format(' %s="%s"', name, value))
      end
    end
  end
end

local empty_elt = {}

function M.define(key, empty, nl)
  local open = string.format('<%s', key:lower())
  local close = string.format('</%s>', key:lower())
  local fn = function(elt)
    elt = elt or empty_elt
    assert(type(elt) == 'table')
    return function(encode, write)
      write(open)
      write_attrs(elt, write)
      write('>')
      if not empty then
        for _, v in ipairs(elt) do
          encode(v)
        end
        write(close)
      end
      if nl then
        write('\n')
      end
    end
  end
  M[key] = fn
  return fn
end

-- Empty elements.
for key in ('AREA BASE BR COL EMBED HR IMG INPUT LINK META PARAM SOURCE TRACK WBR'):gmatch('%u+') do
  M.define(key, true)
end

-- Add newline to end of file.
M.define('HTML', false, true)

-- Define other elements on demand.
setmetatable(M, {
  __index = function(_, key)
    if key:find('^%u+%d?$') then
      return M.define(key, false)
    end
  end,
})

return M
