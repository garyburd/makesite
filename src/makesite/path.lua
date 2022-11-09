local M = {}

function M.tofile(base, p)
  if p:find('^/') then
    return p:sub(2)
  end
  local d = base:match('.*/')
  if not d then
    return p
  end
  return d .. p
end

function M.tourl(base, p)
  if p == 'index.html' then
    return '/'
  end
  if p:sub(-11) == '/index.html' then
    p = p:sub(1, -11)
  end

  local d = base:match('.*/')
  if not d then
    return p
  end
  if p:sub(1, #d) == d then
    p = p:sub(#d + 1)
    if p == '' then
      return '.'
    end
    return p
  end
  return '/' .. p
end

local function path_iter(f)
  local line = f:read('l')
  if not line then
    return nil
  end
  if line:find('^%./') then
    line = line:sub(3)
  end
  return line
end

function M.find(name, dir)
  local prog = string.format(
    "find '%s' -name '%s'",
    string.gsub(dir or '.', "'", "\\'"),
    name:gsub("'", "\\'")
  )
  local f = assert(io.popen(prog, 'r'))
  return path_iter, f, nil, f
end

function M.glob(glob)
  local prog = "printf '%s\n' " .. glob:gsub(' ', '\\ ')
  local f = assert(io.popen(prog, 'r'))
  return path_iter, f, nil, f
end

function M.read(filename)
  local file = assert(io.open(filename))
  local src, e = file:read('a')
  file:close()
  assert(src, e)
  return src
end

function M.write(filename, new)
  local file = io.open(filename)
  if file then
    local old = file:read('a')
    file:close()
    if old and old == new then
      return
    end
  end
  file = assert(io.open(filename, 'w+'))
  assert(file:write(new))
  file:close()
end

return M
