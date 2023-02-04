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
  return html.map(self.images, function(x)
    local img = x.img
    return html.include {
      '\n',
      html.DIV {
        id = x.id,
        class = 'lightbox',
        x.prev and html.A { class = 'lbprev', href = '#' .. x.prev } or false,
        html.A { class = 'lbclose', href = '#_' },
        html.IMG { src = img.src, srcset = img.srcset },
        x.next and html.A { class = 'lbnext', href = '#' .. x.next } or false,
      },
    }
  end)
end

return M
