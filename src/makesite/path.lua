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

local function path_iter(f)
  local line = f:read('l')
  if line and line:find('^%./') then
    return line:sub(3)
  end
  return line
end

local cache_busters = {}

function M.cachebuster(p)
  local b = cache_busters[p]
  if b then
    return b
  end
  local prog = string.format("md5 -q '%s'", string.gsub(M.todest(p), "'", "\\'"))
  local f = assert(io.popen(prog, 'r'))
  local h = assert(f:read('l'))
  f:close()
  b = string.format('%s?%s', p, h)
  cache_busters[p] = b
  return b
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
  return assert(src, e)
end

function M.write(filename, data)
  local file = assert(io.open(filename, 'w+'))
  assert(file:write(data))
  file:close()
end

return M
