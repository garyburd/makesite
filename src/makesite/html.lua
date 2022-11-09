local M = {}

local html_escapes = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
}

local function escape(s)
  return (s:gsub('[&<>]', html_escapes))
end

M.escape = escape

function M.render(value)
  local n = 0
  local out = {}
  local function write(s)
    n = n + 1
    out[n] = s
  end
  local function encode(v)
    if v then
      if type(v) == 'function' then
        v(encode, write)
      else
        write(escape(tostring(v)))
      end
    end
  end
  encode(value)
  return table.concat(out)
end

function M.raw(s)
  return function(_, write)
    write(s)
  end
end

function M.list(list)
  return function(encode)
    for i = 1, #list do
      encode(list[i])
    end
  end
end

function M.map(list, fn, sep)
  local n = 0
  local mapped = {}
  for i = 1, #list do
    local x = fn(list[i])
    if x then
      n = n + 1
      mapped[n] = x
    end
  end
  sep = sep and M.render(sep) or ''
  return function(encode, write)
    if n == 0 then
      return
    end
    encode(mapped[1])
    for i = 2, n do
      write(sep)
      encode(mapped[i])
    end
  end
end

local function write_attrs(elt, write)
  -- Sort keys by name for stable output.
  local keys = {}
  for key, value in pairs(elt) do
    if type(key) == 'string' and value then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    local value = elt[key]
    local attr = key:gsub('_', '-')
    if value == true then
      write(string.format(' %s', attr))
    else
      value = tostring(value)
      if value:find('["\']') then
        write(string.format(' %s="%s"', attr, (value:gsub('"', '&quot;'))))
      elseif value:find('[=<> \n\r\t\b\f]') then
        write(string.format(" %s='%s'", attr, value))
      else
        write(string.format(' %s=%s', attr, value))
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
