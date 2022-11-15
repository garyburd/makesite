local M = {
  site = 'site',
}

-- Return path in site directory given URL path.
function M.tosite(path)
  assert(path:byte(1) == 47) -- slash
  return M.site .. path
end

-- Return URL path given a path in a subdirectory.
function M.tourl(file)
  return assert(file:match('^[^/]+(/.*)'))
end

function M.resolve(base, path)
  if not path:find('^/') then
    path = assert(base:match('.*/')) .. path
  end
  return path
end

-- Return URL path from base to target.
function M.ref(base, target)
  if target:find('/index%.html$') then
    target = target:sub(1, -11)
  end
  local d = base:match('.*/')
  if target:sub(1, #d) ~= d then
    return target
  end
  target = target:sub(#d + 1)
  if target == '' then
    target = '.'
  end
  return target
end

local function path_iter(f)
  local line = f:read('l')
  if line and line:find('^%./') then
    return line:sub(3)
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
