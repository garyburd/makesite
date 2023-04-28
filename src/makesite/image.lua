local M = {}

local reqbase = (...):match('(.-)[^%.]+$')
local path = require(reqbase .. 'path')

function M.wh(filename) --> width, height
  if filename:find('%.jpg$') or filename:find('%.jpeg$') then
    local file <close> = assert(io.open(filename))
    local size = 2
    local ftype = 0
    while ftype < 0xc0 or ftype > 0xcf do
      assert(file:seek('cur', size))
      local b = assert(file:read(1)):byte()
      while b == 0xff do
        b = assert(file:read(1)):byte()
      end
      ftype = b
      size = string.unpack('>I2', assert(file:read(2))) - 2
    end
    -- We are at a SOFn block
    file:seek('cur', 1) -- Skip `precision' byte.
    local h, w = string.unpack('>I2I2', file:read(4))
    return w, h
  end
  error(string.format('%s does not have a recognized file type', filename))
end

function M.src(page, src, img)
  local w, h = M.wh(path.todest(page:abs(src)))
  img = img or {}
  img.width = w
  img.height = h
  img.src = src
  return img
end

function M.srcset(page, glob, img)
  img = img or {}
  local srcset = {}
  local maxw, maxh, maxsrc = 0, 0, nil
  local dir, name = path.split(path.todest(page:abs(glob)))
  for fname in path.find(dir, '-maxdepth', '1', '-name', name) do
    local w, h = M.wh(fname)
    local src = page:rel(path.fromdest(fname))
    srcset[#srcset + 1] = string.format('%s %dw', src, w)
    if w > maxw then
      maxw = w
      maxh = h
      maxsrc = src
    end
  end
  if not maxsrc then
    error(string.format('no image found for pattern %s/%s', dir, name))
  end
  table.sort(srcset)
  img.src = maxsrc
  img.width = maxw
  img.height = maxh
  img.srcset = table.concat(srcset, ', ')
  return img
end

return M
