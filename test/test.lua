local html = require('makesite.html')
local path = require('makesite.path')
local page = require('makesite.page')
local image = require('makesite.image')

local function tprint(tbl, indent)
  if not indent then
    indent = 0
  end
  local n = 0
  local keys = {}
  for k in pairs(tbl) do
    n = n + 1
    keys[n] = k
  end
  table.sort(keys, function(a, b)
    if type(a) ~= type(b) then
      return type(a) < type(b)
    end
    return a < b
  end)
  for _, k in ipairs(keys) do
    local v = tbl[k]
    local formatting = string.rep('  ', indent) .. k .. ': '
    if type(v) == 'table' then
      print(formatting)
      tprint(v, indent + 1)
    else
      print(formatting .. tostring(v))
    end
  end
end

local function expect(got, want)
  got = tostring(got)
  want = tostring(want)
  if got ~= want then
    error(string.format('got: %q, want %q', got, want), 2)
  end
end

local function expect_fail(pat, fn, ...)
  local ok, err = pcall(fn, ...)
  if ok then
    error('function succeded, want failure', 2)
  end
  if not string.find(err, pat) then
    error(string.format('got error %q, want match with %q', err, pat), 2)
  end
end

local Layout = {}
Layout.__index = Layout

function Layout:message()
  return self.page.message or '!MISSING!'
end

function Layout.run(page)
  local l = setmetatable({
    page = page,
  }, Layout)
  local content = page.content(l)
  local tree = html.HTML {
    html.BODY { content },
  }
  return tree
end

local function run()
  expect(html.escape('A<B>C&D'), 'A&lt;B&gt;C&amp;D')
  expect(html.render(html.HR()), '<hr>')
  expect(
    html.render(html.DIV { data_example = 20, 'foo', html.P { 'bar' }, 'quux' }),
    [[<div data-example=20>foo<p>bar</p>quux</div>]]
  )
  expect(
    html.render(html.DIV { a1 = "'", a2 = '"', a3 = '<', a4 = 'foo', a5 = true }),
    [[<div a1="'" a2="&quot;" a3='<' a4=foo a5></div>]]
  )
  expect(html.render(html.raw('<>')), [[<>]])
  expect(html.render(html.list { '1', html.P { '2' }, html.P { 3 }, 4 }), [[1<p>2</p><p>3</p>4]])
  expect(html.render(html.HTML()), '<html></html>\n')
  expect(
    html.render(html.map({ 1, 2, 3 }, function(i)
      return i
    end, ', ')),
    '1, 2, 3'
  )

  expect(path.tourl('index.html', 'img.jpg'), 'img.jpg')
  expect(path.tourl('file.html', 'img.jpg'), 'img.jpg')
  expect(path.tourl('dir/index.html', 'dir/img.jpg'), 'img.jpg')
  expect(path.tourl('dir/file.html', 'dir/img.jpg'), 'img.jpg')
  expect(path.tourl('dir/dir2/file.html', 'dir/dir2/img.jpg'), 'img.jpg')
  expect(path.tourl('index.html', 'index.html'), '/')
  expect(path.tourl('dir/index.html', 'index.html'), '/')
  expect(path.tourl('dir/index.html', 'dir/index.html'), '.')
  expect(path.tourl('dir/file.html', 'dir/index.html'), '.')
  expect(path.tourl('dir1/file.html', 'dir2/index.html'), '/dir2/')
  expect(path.tourl('dir1/file.html', 'dir2/file.html'), '/dir2/file.html')

  expect(path.tofile('index.html', 'img.jpg'), 'img.jpg')
  expect(path.tofile('dir/index.html', 'img.jpg'), 'dir/img.jpg')
  expect(path.tofile('dir/index.html', '/index.html'), 'index.html')

  local src = [==[
${
  -- a comment with }, [[, ', and "
  a = '}',
  b = "}",
  c = [=[}]=],
  d = { nested = "}" },
  e = '\\\\',
  f = '\'',
  g = "\"",
  q = false and x[y],
  message = "world",
}
Hello $message()!
]==]

  local p = page.loadstring(src)
  expect(p.a, '}')
  expect(p.b, '}')
  expect(p.c, '}')
  expect(p.d.nested, '}')
  expect(p.e, '\\\\')
  expect(p.f, "'")
  expect(p.g, '"')
  expect(html.render(Layout.run(p)), '<html><body>Hello world!\n</body></html>\n')

  --p = page.load('test/data/page.x.html')

  expect_fail('file type', image.wh, 'foobar.notanimage')
  local w, h = image.wh('test/data/image.jpg')
  expect(w, 240)
  expect(h, 179)
end

local ok, err = xpcall(run, require('debug').traceback)
if ok then
  print('OK')
else
  print(err)
end
