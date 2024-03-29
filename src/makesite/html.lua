local modname = ...

local M = {}

local html_escapes = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
}

local function render(write, value)
  if type(value) == 'function' then
    return value(write)
  elseif type(value) == 'table' and getmetatable(value) == nil then
    -- render plain tables inline.
    for _, v in ipairs(value) do
      render(write, v)
    end
  elseif value then
    return write((tostring(value):gsub('[&><>]', html_escapes)))
  end
end

M.render = render

function M.rendertostring(value)
  local n = 0
  local output = {}
  local function write(s)
    n = n + 1
    output[n] = s
  end
  render(write, value)
  return table.concat(output)
end

function M.rendertofile(filename, value)
  local f, e = io.open(filename, 'w+')
  if not f then
    return nil, e
  end
  local write = f.write
  render(function(s)
    return write(f, s)
  end, value)
  f:close()
  return true
end

function M.raw(s)
  assert(type(s) == 'string')
  return function(write)
    return write(s)
  end
end

function M.join(list, rawsep)
  assert(type(list) == 'table')
  assert(type(rawsep) == 'string')
  return function(write)
    local sep = ''
    for _, v in ipairs(list) do
      write(sep)
      render(write, v)
      sep = rawsep
    end
  end
end

local attr_escapes = {
  ['&'] = '&amp;',
  ['"'] = '&quot;',
}

local function renderattrs(write, elem)
  -- Sort attribute names for stable output.
  -- Skip attributes with false values.
  local names = {}
  for name, value in pairs(elem) do
    if type(name) == 'string' and value then
      names[#names + 1] = name
    end
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local value = elem[name]
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

local empty_elem = {}

function M.define(key, empty)
  local open = string.format('<%s', key:lower())
  local close = string.format('</%s>', key:lower())
  local fn = function(elem)
    elem = elem or empty_elem
    assert(type(elem) == 'table')
    return function(write)
      write(open)
      renderattrs(write, elem)
      write('>')
      if not empty then
        for _, v in ipairs(elem) do
          render(write, v)
        end
        write(close)
      end
    end
  end
  M[key] = fn
  return fn
end

-- Empty elements.
for key in ('AREA BASE BR COL EMBED HR IMG INPUT LINK META PARAM SOURCE TRACK WBR'):gmatch('%S+') do
  M.define(key, true)
end

function M.doc(elem)
  return function(write)
    write('<!DOCTYPE html>\n')
    M.HTML(elem)(write)
    write('\n')
  end
end

-- Define other elements on demand.
setmetatable(M, {
  __index = function(_, key)
    if key:find('^%u+%d?$') then
      return M.define(key, false)
    else
      error(string.format('%s: invalid key %s', modname, key, 2))
    end
  end,
})

local function renderxmlattrs(write, elem)
  -- Sort attribute names for stable output.
  local names = {}
  for name in pairs(elem) do
    if type(name) == 'string' then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local value = elem[name]
    name = name:gsub('_', '-')
    value = tostring(value):gsub('[&"]', attr_escapes)
    write(string.format(' %s="%s"', name, value))
  end
end

M.xml = {}
setmetatable(M.xml, {
  __call = function(_, root)
    return function(write)
      write('<?xml version="1.0" encoding="UTF-8" ?>')
      render(write, root)
      write('\n')
    end
  end,
  __index = function(_, name)
    local open = string.format('<%s', name)
    local close = string.format('</%s>', name)
    local fn = function(elem)
      elem = elem or empty_elem
      return function(write)
        write(open)
        renderxmlattrs(write, elem)
        if elem[1] == nil then
          write('/>')
        else
          write('>')
          for _, v in ipairs(elem) do
            render(write, v)
          end
          write(close)
        end
      end
    end
    M.xml[name] = fn
    return fn
  end,
})

return M
