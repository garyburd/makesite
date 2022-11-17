local html = require('makesite.html')
local path = require('makesite.path')
local page = require('makesite.page')

local Layout = {}
Layout.__index = Layout

local examplefile = 'dsrc/examples.lua'
local examplesrc = path.read(examplefile)
local examplemod = assert(load(examplesrc, examplefile))()

function Layout:todest(p)
  return path.todest(self.page:abs(p))
end

function Layout:rel(p)
  return self.page:rel(p)
end

function Layout:example(name)
  local _ = self
  local arg, src = examplesrc:match('\nfunction M%.' .. name .. '%((.-)%)(.-)\nend')
  if not src then
    error(string.format('could not find function M.%s(print) ... end in %s', name, examplefile))
  end
  local ws = src:match('\n%s*')
  src = src:gsub(ws, '\n')

  local out = nil
  if arg == 'print' then
    out = {}
    examplemod[name](function(...)
      local args = table.pack(...)
      for i = 1, args.n do
        args[i] = tostring(args[i])
      end
      out[#out + 1] = table.concat(args, '\t')
    end)
  end
  return html.include {
    html.PRE { src },
    #out > 0 and html.include{'Output:\n', html.PRE { table.concat(out, '\n') }} or false,
  }
end

function Layout:a(arg)
  local _ = self
  local s, u = arg:match('^(.-)%s+(%S+)$')
  return html.A { href = u, html.raw(s) }
end

function Layout:fna(arg)
  local _ = self
  return html.A { href = '#' .. arg, html.CODE { arg } }
end

function Layout:fn(arg)
  local _ = self
  local name = arg:match('[^(]+')
  return html.H3 {
    html.A { name = name, html.CODE { arg } },
    ' ',
    html.A { href = '#' .. name, '#' },
  }
end

function Layout.run(p)
  local l = setmetatable({
    page = p,
  }, Layout)
  local m = p.meta
  local content = p.content(l)
  return html.doc {
    lang = 'en',
    html.HEAD {
      html.META { charset = 'utf-8' },
      '\n',
      html.META { name = 'viewport', content = 'width=device-width, initial-scale=1' },
      '\n',
      html.LINK { href = p:rel(path.cachebuster('/site.css')), rel = 'stylesheet' },
      '\n',
      m.title and html.TITLE { m.title } or false,
    },
    html.BODY {
      html.ARTICLE {
        html.H1 { m.title },
        content,
      },
    },
  }
end

path.dest = 'docs'
page.load('dsrc/index.html'):save(Layout.run)
