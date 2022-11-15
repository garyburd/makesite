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
  if got ~= want then
    error(string.format('got: %q, want %q', tostring(got), tostring(want)), 2)
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

function Layout:line(arg, _, line)
  local _ = self
  local want = tonumber(arg)
  expect(line, want)
  expect(debug.getinfo(2).currentline, want)
end

function Layout:message()
  return self.page.message or '!MISSING!'
end

function Layout.run(p)
  local l = setmetatable({
    page = p,
  }, Layout)
  local content = p.content(l)
  local tree = html.HTML {
    html.BODY { content },
  }
  return tree
end

local function run()
  --expect(html.escape('A<B>C&D'), 'A&lt;B&gt;C&amp;D')
  expect(html.render(html.HR()), '<hr>')
  expect(
    html.render(html.DIV { data_example = 20, 'foo', html.P { 'bar' }, 'quux' }),
    [[<div data-example=20>foo<p>bar</p>quux</div>]]
  )
  expect(html.render('<>&'), '&lt;&gt;&amp;')
  expect(
    html.render(html.DIV { a1 = "'", a2 = '"', a3 = '<&', a4 = 'foo', a5 = true }),
    [[<div a1="'" a2=&quot; a3="<&amp;" a4=foo a5></div>]]
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

  expect(path.tourl('pages/file.html'), '/file.html')
  expect(path.tosite('/file.html'), 'site/file.html')
  expect(path.resolve('/', 'img.jpg'), '/img.jpg')
  expect(path.resolve('/dir/', 'img.jpg'), '/dir/img.jpg')
  expect(path.resolve('/dir/', '/img.jpg'), '/img.jpg')
  expect(path.ref('/', '/'), '.')
  expect(path.ref('/', '/dir/'), 'dir/')
  expect(path.ref('/', '/other.html'), 'other.html')
  expect(path.ref('/', '/dir/other.html'), 'dir/other.html')
  expect(path.ref('/other.html', '/'), '.')
  expect(path.ref('/dir/', '/dir/dir2/'), 'dir2/')
  expect(path.ref('/dir/other.html', '/dir/'), '.')
  expect(path.ref('/dir/', '/dir/other.html'), 'other.html')
  expect(path.ref('/dir/', '/dir2/other.html'), '/dir2/other.html')

  local src = [==[
[=[
  message = 'world'
  -- comment
  count = 10
]=]
[[line 6]]Hello [[message]]![[line 6]]
[[line 7]]]==]

  local p = page.loadstring(src)
  expect(p.message, 'world')
  expect(p.count, 10)
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
