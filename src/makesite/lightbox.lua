local M = {}

local modname, modfile = ...
local reqbase = modname:match('(.-)[^%.]+$')
local html = require(reqbase .. 'html')
local path = require(reqbase .. 'path')

function M.css()
  return path.read(modfile:gsub('%.lua$', '.css'))
end

function M.js()
  return path.read(modfile:gsub('%.lua$', '.js'))
end

local Lightbox = {}
Lightbox.__index = Lightbox

function M.new()
  return setmetatable({ images = {} }, Lightbox)
end

function Lightbox:add(id, img)
  assert(getmetatable(self) == Lightbox)
  local x = {
    id = id,
    img = img,
  }
  local n = #self.images + 1
  self.images[n] = x
  if n > 1 then
    local prev = self.images[n - 1]
    prev.next = x.id
    x.prev = prev.id
  end
  return html.A { href = '#' .. id, html.IMG(img) }
end

function Lightbox:__len()
  return #self.images
end

function Lightbox:content()
  assert(getmetatable(self) == Lightbox)
  local list = {}
  for _, v in ipairs(self.images) do
    local img = v.img
    table.insert(
      list,
      html.DIV {
        id = v.id,
        class = 'lightbox',
        v.prev and html.A { class = 'lbprev', href = '#' .. v.prev } or false,
        html.A { class = 'lbclose', href = '#_' },
        html.IMG { src = img.src, srcset = img.srcset },
        v.next and html.A { class = 'lbnext', href = '#' .. v.next } or false,
      }
    )
  end
  return html.join(list, '\n')
end

return M
