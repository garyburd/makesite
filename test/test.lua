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
  return self.page.meta.message or '!MISSING!'
end

function Layout.run(p)
  local l = setmetatable({
    page = p,
  }, Layout)
  local content = p.content(l)
  return html.doc {
    html.BODY { content },
  }
end

local function run()
  local render = html.rendertostring

  --expect(html.escape('A<B>C&D'), 'A&lt;B&gt;C&amp;D')
  expect(render(html.HR()), '<hr>')
  expect(
    render(html.DIV { data_example = 20, 'foo', html.P { 'bar' }, 'quux' }),
    [[<div data-example=20>foo<p>bar</p>quux</div>]]
  )
  expect(render('<>&'), '&lt;&gt;&amp;')
  expect(
    render(html.DIV { a1 = "'", a2 = '"', a3 = '<&', a4 = 'foo', a5 = true }),
    [[<div a1="'" a2=&quot; a3="<&amp;" a4=foo a5></div>]]
  )
  expect(render(html.raw('<>')), [[<>]])
  expect(render(html.doc()), '<!DOCTYPE html>\n<html></html>\n')
  expect(render(html.join({ 1, 2, 3 }, ', ')), '1, 2, 3')
  expect(render { 1, 2, 3 }, '123')

  local xml = html.xml
  expect(
    render(xml(xml.rss { version = '2.0', xml.channel { xml.title { 'my feed' } } })),
    '<?xml version="1.0" encoding="UTF-8" ?><rss version="2.0"><channel><title>my feed</title></channel></rss>\n'
  )

  do
    local dir, file = path.split('/foo/bar')
    expect(dir, '/foo')
    expect(file, 'bar')
  end
  expect(path.fromdest(path.dest .. '/file.html'), '/file.html')
  expect(path.todest('/file.html'), 'site/file.html')
  expect(page.new('/'):abs('img.jpg'), '/img.jpg')
  expect(page.new('/dir/'):abs('img.jpg'), '/dir/img.jpg')
  expect(page.new('/dir/'):abs('/img.jpg'), '/img.jpg')
  expect(page.new('/'):rel('/'), '.')
  expect(page.new('/'):rel('/dir/'), 'dir/')
  expect(page.new('/'):rel('/other.html'), 'other.html')
  expect(page.new('/'):rel('/dir/other.html'), 'dir/other.html')
  expect(page.new('/other.html'):rel('/'), '.')
  expect(page.new('/dir/'):rel('/dir/dir2/'), 'dir2/')
  expect(page.new('/dir/other.html'):rel('/dir/'), '.')
  expect(page.new('/dir/'):rel('/dir/other.html'), 'other.html')
  expect(page.new('/dir/'):rel('/dir2/other.html'), '/dir2/other.html')

  local src = [==[
[=[
  message = 'world'
  -- comment
  count = 10
]=]
[[line 6]]Hello [[message]]![[line 6]]
[[line 7]]]==]

  local p = page.loadstring('/index.html', src)
  expect(p.meta.message, 'world')
  expect(p.meta.count, 10)
  expect(render(Layout.run(p)), '<!DOCTYPE html>\n<html><body>Hello world!\n</body></html>\n')

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
