local M = {
  dest = 'site',
}

local slashbyte = ('/'):byte(1)

-- Return path in output directory given URL path.
function M.todest(path)
  assert(path:byte(1) == slashbyte)
  return M.dest .. path
end

-- Return URL path given a path in the output diretory.
function M.fromdest(file)
  assert(file:sub(1, #M.dest) == M.dest)
  return file:sub(#M.dest + 1)
end

local function popen(mode, ...)
  local args = table.pack(...)
  for i, a in ipairs(args) do
    if a:match('[^A-Za-z0-9_/:=-]') then
      args[i] = "'" .. a:gsub("'", "'\\''") .. "'"
    end
  end
  return io.popen(table.concat(args, ' '), mode)
end

local cache_busters = {}

function M.cachebuster(p)
  local b = cache_busters[p]
  if b then
    return b
  end
  local f = assert(popen('r', 'md5', '-q', M.todest(p)))
  local h = assert(f:read('l'))
  f:close()
  b = string.format('%s?%s', p, h)
  cache_busters[p] = b
  return b
end

function M.split(path)
  return path:match('(.-)/([^/]*)$')
end

local function path_iter(f)
  local line = f:read('l')
  if line and line:find('^%./') then
    return line:sub(3)
  end
  return line
end

function M.find(...)
  local f = assert(popen('r', 'find', ...))
  return path_iter, f, nil, f
end

function M.read(filename)
  local file = assert(io.open(filename))
  local src, e = file:read('a')
  file:close()
  return assert(src, e)
end

function M.write(filename, data)
  local file = assert(io.open(filename, 'w+'))
  assert(file:write(data))
  file:close()
end

function M.update(filename, data)
  local file = io.open(filename)
  if file then
    local eq = data == file:read('a')
    file:close()
    if eq then
      return
    end
  end
  M.write(filename, data)
end

return M
