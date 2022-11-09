local M = {}

local reqbase = (...):match('(.-)[^%.]+$')
local path = require(reqbase .. 'path')
local html = require(reqbase .. 'html')

local function scan_short_string(src, p, pattern)
  -- The pattern is zero or more backslashes followed by the quote character.
  -- The quote terminates the string when the number of backslashes is odd.
  p = p + 1
  while true do
    local p1, p2 = src:find(pattern, p)
    if not p1 then
      return #src
    end
    if (p2 - p1) % 2 == 0 then
      return p2
    end
    p = p2 + 1
  end
end

local function maybe_scan_long_string(src, p)
  local p1, p2, eq = src:find('^%[(%=*)%[', p)
  if not p1 then
    -- Not a long string. Do nothing.
    return p
  end
  local _, p3 = src:find(']' .. eq .. ']', p2 + 1)
  return p3 or #src
end

local function maybe_scan_comment(src, p)
  if src:byte(p + 1) ~= 45 then
    -- Not a comment. Do nothing.
    return p
  end
  return src:find('\n', p + 1) or #src
end

local function scan_balanced(src, p)
  local open <const> = src:byte(p) -- ( or {
  local close <const> = (open == 123 and 125) or 41
  local balance = 1
  p = p + 1
  while true do
    p = src:find('[-[{}()"\']', p)
    if not p then
      return #src
    end
    local b = src:byte(p)
    if b == open then
      balance = balance + 1
    elseif b == close then
      balance = balance - 1
      if balance == 0 then
        return p
      end
    elseif b == 39 then -- single quote
      p = scan_short_string(src, p, "\\*'")
    elseif b == 34 then -- double quote
      p = scan_short_string(src, p, '\\*"')
    elseif b == 45 then -- dash
      p = maybe_scan_comment(src, p)
    elseif b == 91 then -- square bracket
      p = maybe_scan_long_string(src, p)
    end
    p = p + 1
  end
end

local function adjust_lines(s)
  local n = 0
  for i = 1, #s do
    if s:byte(i) == 10 then
      n = n + 1
    end
  end
  if n > 0 then
    coroutine.yield(string.rep('\n', n))
  end
end

local function eval_header(src, name, env)
  if not src:find('^%${') then
    return {}, 1
  end
  local p = scan_balanced(src, 2)
  return assert(load('return ' .. src:sub(2, p), name, env))(), p
end

local function eval_content(src, name, env, p, x)
  local text = {}
  local ntext = 0
  local chunk = coroutine.wrap(function()
    p = select(2, src:find('^[ \t\r\n]*', p + 1))
    adjust_lines(src:sub(1, p))
    p = p + 1

    coroutine.yield('local x = ...; return {')
    while true do
      local p1, p2 = src:find('%$[a-zA-Z][a-zA-Z0-9_]*[%(%{]', p)

      local s = src:sub(p, (p1 and p1 - 1) or #src)
      adjust_lines(s)
      ntext = ntext + 1
      text[ntext] = s

      if not p1 then
        coroutine.yield('}')
        return
      end

      coroutine.yield('x:')
      p = scan_balanced(src, p2)
      coroutine.yield(src:sub(p1 + 1, p))
      coroutine.yield(',')
      p = p + 1
    end
  end)
  local values = assert(load(chunk, name, 't', env))(x)
  return function(encode, write)
    for i = 1, ntext do
      write(text[i])
      encode(values[i])
    end
  end
end

function M.loadstring(src, name, env)
  local page, p = eval_header(src, name, env)
  page.content = function(x)
    return eval_content(src, name, env, p, x)
  end
  return page
end

function M.convert_filename(p)
  local e = p:find('%.x%.html$')
  assert(e, 'filename does not end with .x.html')
  return p:sub(1, e - 1) .. '.html'
end

function M.load(filename, env)
  local page = M.loadstring(path.read(filename), '@' .. filename, env)
  if not page.path then
    page.path = M.convert_filename(filename)
  end
  return page
end

function M.save(page, layout)
  path.write(page.path, html.render(layout(page)))
  page.content = nil
end

return M
