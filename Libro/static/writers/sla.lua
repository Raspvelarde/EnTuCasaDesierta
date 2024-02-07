-- Custom Pandoc Writer for Scribus 1.5
-- Based on sample.lua; cfr https://pandoc.org/custom-writers.html
-- (c) 2022 Perro Tuerto <hi@perrotuerto.blog>
-- Funded by Adjetiva Editorial <https://adjetiva.mx>
-- This code is licensed under GPLv3

-- VARIABLES

local fontsize = 12
local stringify = (require 'pandoc.utils').stringify
local doc = PANDOC_DOCUMENT
local meta = doc.meta
local image_format = meta.image_format and stringify(meta.image_format) or 'png'
local image_mime_type = ({
    jpeg = 'image/jpeg',
    jpg = 'image/jpeg',
    gif = 'image/gif',
    png = 'image/png',
    svg = 'image/svg+xml',
  })[image_format] or error('unsupported image format `' .. image_format .. '`')

-- Stores styles
local styles = {}

-- Stores footnotes
local notes = {}

-- Stores links
local links = {}

-- FUNCTIONS

-- Scapes characters
local function escape(str)
  return tostring(str)
    :gsub('&', '&amp;')
    :gsub('<', '&lt;')
    :gsub('>', '&gt;')
    :gsub('"', '&quot;')
end

-- Adds styles to 'styles'
local function add_style(name, charstyle, extra)
  extra = extra ~= '' and ' ' .. extra or extra
  local exists = false
  local s = charstyle and 'CHARSTYLE' or 'STYLE'
  local n = charstyle and ' CNAME="' .. name .. '"' or ' NAME="' .. name .. '"'
  local p = charstyle and ' CPARENT="Pandoc"' or ' PARENT="Pandoc"'
  local tag = '<' .. s .. n .. p .. extra .. '/>'
  for _, v in pairs(styles) do
    if v == tag then exists = true end
  end
  if not exists then table.insert(styles, tag) end
end

-- Adds required styles
local function prepend_style()
  return {
    '<CHARSTYLE CNAME="Default Character Style" DefaultStyle="1" FONT="Open Sans Regular" FCOLOR="Black"/>',
    '<CHARSTYLE CNAME="Pandoc" FONT="Open Sans Regular" FONTSIZE="' .. fontsize .. '"/>',
    '<STYLE NAME="Default Paragraph Style" DefaultStyle="1"/>',
    '<STYLE NAME="Pandoc" LINESPMode="2" CPARENT="Pandoc" FCOLOR="Black" NACH="' .. fontsize .. '"/>'
  }
end

-- Makes paragraph
local function para(par, extra)
  add_style(par, false, extra)
  return '\n<para PARENT="' .. par .. '"/>\n'
end

-- Makes ITEXT
local function itext(s, cpar, extra)
  if cpar ~= '' then
    add_style(cpar, true, extra)
    cpar = ' CPARENT="' .. cpar .. '"'
  end
  local br = '\n'
  local ch = ' CH="' .. s .. '"'
  local open = '<ITEXT'
  local close = '/>'
  return br .. open .. cpar .. ch .. close .. br
end

-- Converts indicated spans to smallcaps
local function fix_smallcaps(val)
  if val == 'Span-versalita'
  or val == 'Span-smallcaps' 
  or val == 'Span-acronimo' then
    val = 'SmallCaps'
  end
  return val
end

-- Makes CPARENT or CNAME value
local function get_c(pre, attr)
  for x, y in pairs(attr) do
    if y and y ~= '' then
      pre = pre == 'Div' and '' or pre .. '-'
      pre = pre .. y:lower():gsub('%W+', '_')
    end
  end
  return {fix_smallcaps(pre), ''}
end

local inlines = {}

-- Generates inline elements
local function inline(s, cpar, extra)
  table.insert(inlines, {s, cpar, extra})
  return itext(s, cpar, extra)
end

-- Generates block elements
local function block(content, name, styles, mod)
  --print('===')
  for _, inline in pairs(inlines) do
    --print('---')
    --print(table.concat(inline, '\n'))
  end
  inlines = {}
  if name == '' then
    return content
  else
    content = mod and itext(content, '', '') or content
    return content .. para(name, styles)
  end
end

-- Stringifies 'styles'
local function prepare_styles()
  local spaces = string.rep(' ', 8)
  local all = prepend_style()
  table.sort(styles)
  for _, style in pairs(styles) do
    table.insert(all, style)
  end
  return spaces .. table.concat(all, '\n' .. spaces)
end

-- TODO
local function prepare_links()
  local header = itext('Links', '', '') .. para('Header1', '') 
  local sorted = table.sort(links, function(a, b) return a[1] < b[1] end)
  return header
end

-- Adds parent style in a child style
local function fix_child(child, parent)
  local header = '<para PARENT="'
  local footer = '"/>'
  for par in child:gmatch(header .. '(.+)' .. footer) do
    par = par .. '+' .. parent
    child = header .. par .. footer
    para(par, '')
  end
  return child
end

-- Adds parent style in all children styles
local function fix_children(s, parent)
  local children = {}
  s = s and s or ''
  for child in (s .. '\n'):gmatch('(.-)' .. '\n') do
    table.insert(children, fix_child(child, parent))
  end
  return table.concat(children, '\n')
end

-- Escapes content
local function fix_line(line)
  return line:gsub('(<ITEXT.+CH=")(.+)("/>)', function (ini, txt, fin)
    return ini .. escape(txt) .. fin
  end)
end

-- Formats blocks linebreaks and incomplete tags
local function fix_blocks(blocks, body)
  local br = '\n'
  local lines = {}
  local spaces = body and string.rep(' ', 16) or ''
  blocks = blocks:gsub('><', '>\n<'):gsub('\n\n+', '\n')
  for line in (blocks .. br):gmatch('(.-)' .. br) do
    if line:sub(1, 1) ~= '<' then line = '<ITEXT CH="' .. line end
    if line:sub(-1, -1) ~= '>' then line = line .. '"/>' end
    if not line:match('CH=""') and not line:match('"/>"/>') then
      line = body and fix_line(line) or line
      table.insert(lines, spaces .. line)
    end
  end
  return table.concat(lines, '\n')
end

-- Joins table elements and adds a paragraph style
local function fix_table_children(children, header)
  local par = header and 'TableHeader' or 'TableRow'
  children = table.concat(children, itext(' ', 'TableSeparator', ''))
  return children .. para(par, 'ALIGN="1"')
end

-- Separates block elements
function Blocksep()
  return ''
end

-- Generates document
-- body == string
-- metadata == table
-- variables == table
function Doc(body, metadata, variables)
  variables.all_styles = prepare_styles()
  body = body .. prepare_links()
  body = fix_blocks(body, true)
  return body, variables
end

-- ELEMENTS FUNCTIONS
-- s == string
-- attr == table
-- items == array of strings

-- INLINE ELEMENTS

function Str(s)
  return s
end

function Space()
  return ' '
end

function SoftBreak()
  return ' '
end

function LineBreak()
  return '\n<breakline/>'
end

function Emph(s)
  return inline(s, 'Emph', 'FONT="Open Sans Italic"')
end

function Strong(s)
  return inline(s, 'Strong', 'FONT="Open Sans Bold"')
end

function Subscript(s)
  return inline(s, 'Subscript', 'FEATURES="subscript"')
end

function Superscript(s)
  return inline(s, 'Superscript', 'FEATURES="superscript"')
end

function SmallCaps(s)
  return inline(s, 'SmallCaps', 'FEATURES="smallcaps"')
end

function Strikeout(s)
  return inline(s, 'Strikeout', 'FEATURES="strike"')
end

-- url == string (link url)
-- tit == string (tooltip)
function Link(s, url, tit, attr)
  table.insert(links, {s, url})
  -- TODO url = itext(' <' .. url .. '>', 'LinkUrl', 'FONT="Open Sans Bold"')
  return inline(s, 'Link', 'FCOLOR="Blue"')
end

-- src == string (image source)
-- tit == string (tooltip)
function Image(s, src, tit, attr)
  -- TODO src = itext('IMAGE: ' .. src, 'ImageSrc', 'FONT="Open Sans Bold"')
  -- return src ..  LineBreak() .. s
  return inline(s, 'ImageCaption', '')
end

function Code(s, attr)
  return inline(s, 'Code', 'FONT="Courier New Regular"')
end

function InlineMath(s)
  return inline('RENDER: ' .. s, 'RenderSrc', 'FONT="Open Sans Bold"')
end

function DisplayMath(s)
  return inline('RENDER: ' .. s, 'RenderSrc', 'FONT="Open Sans Bold"')
end

function SingleQuoted(s)
  return inline('‘' .. s .. '’', 'SingleQuoted', '')
end

function DoubleQuoted(s)
  return inline('“' .. s .. '”', 'DoubleQuoted', '')
end

function Note(s)
  local num = #notes + 1
  table.insert(notes, s)
  -- TODO s = itext(' [' .. s .. ']', 'NoteTxt', 'FONT="Open Sans Bold"')
  return inline(num, 'NoteNum', 'FEATURES="superscript"')
end

function Span(s, attr)
  local span = get_c('Span', attr)
  return inline(s, span[1], span[2])
end

-- format == string (s format)
function RawInline(format, s)
  return inline(s, 'Raw', 'FONT="Courier New Regular"')
end

-- cs == table (list of citations)
function Cite(s, cs)
  return inline(s, 'Cite', 'FONT="Open Sans Italic"')
end

function Plain(s)
  return inline(s, 'Plain', '')
end

-- BLOCK ELEMENTS

function Para(s)
  return block(s, 'Para', '', true) 
end

-- lev == integer (header level)
function Header(lev, s, attr)
  local fs = {24, 22, 20, 18, 16, 14}
  local extra = {
    'FONTSIZE="' .. fs[lev] .. '"',
    'VOR="' .. fs[lev] .. '"',
    'NACH="' .. fs[lev] .. '"',
    'FONT="Open Sans Bold"'
  }
  extra = table.concat(extra, ' ')
  return block(s, 'Header' .. lev, extra, true) 
end

function BlockQuote(s)
  return block(s, 'BlockQuote', 'INDENT="10.0"', true) 
end

function HorizontalRule()
  local styles = 'VOR="' .. fontsize .. '" NACH="' .. fontsize .. '" BCOLOR="Black" FONTSIZE="1"'
  return block(' ', 'HorizontalRule', styles, true) 
end

-- ls = table (lines)
function LineBlock(ls)
  local lines = table.concat(ls, LineBreak())
  return block(lines, 'LineBlocks', '', true) 
end

-- format == string (s format)
function RawBlock(format, s)
  return block(s, 'RawBlock', 'CPARENT="Pandoc_Raw"', true) 
end

function CodeBlock(s, attr)
  return block(s, 'CodeBlock', 'CPARENT="Pandoc_Code"', true) 
end

function BulletList(items)
  local styles = 'Bullet="1" BulletStr="•" Numeration="0"'
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, itext(item, '', ''))
  end
  buffer = table.concat(buffer, '\n')
  return block(buffer, 'BulletList', styles, false)
end

function OrderedList(items)
  local styles = 'Bullet="0" Numeration="1"'
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, itext(item, '', ''))
  end
  buffer = table.concat(buffer, '\n')
  return block(buffer, 'OrderedList', styles, false)
end

-- tit == string (tooltip)
-- caption == string (image caption)
function CaptionedImage(src, tit, caption, attr)
  caption = itext(caption, 'ImageCaption', '')
  src = itext('ADD IMAGE: ' .. src, 'ImageSrc', 'FONT="Open Sans Bold"')
  src = src .. LineBreak() .. caption
  return block(src, 'CaptionedImage', 'ALIGN="1"', false) 
end

-- caption == string (table caption)
-- aligns == array of strings (table aligns)
-- widths == array of floats (table widths)
-- headers == array of strings (table headers)
-- rows == array of array of strings (table rows)
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local all = caption ~= '' and itext(caption, 'TableCaption', 'ALIGN="1"') or ''
  for _, row in pairs(rows) do
    row = fix_table_children(row, false)
    table.insert(buffer, row)
  end
  all = all .. fix_table_children(headers, true)
  all = all .. table.concat(buffer)
  return block(all, '', '', false)
end

function Div(s, attr)
  local div = get_c('Div', attr)[1]
  s = fix_blocks(s, false)
  s = fix_children(s, div)
  return block(s, '', '', false)
end

function DefinitionList(items)
  local buffer = {}
  for _, item in pairs(items) do
    local k, v = next(item)
    k = itext(k, 'DefinitionTerm', '')
    table.insert(buffer, k .. LineBreak() .. table.concat(v))
  end
  buffer = fix_blocks(table.concat(buffer), false)
  --buffer = fix_children(s, 'DefinitionList')
  return block(buffer, '', '', false)
end

--[[
-- Fix writer in Pandoc v3; cfr https://github.com/jgm/pandoc/blob/master/doc/custom-writers.md#changes-in-pandoc-30
function Writer (doc, opts)
  PANDOC_DOCUMENT = doc
  PANDOC_WRITER_OPTIONS = opts
  loadfile(PANDOC_SCRIPT_FILE)()
  return pandoc.write_classic(doc, opts)
end
]]--

-- Debugs writer
-- Prints undefined elements functions
local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n", key))
    return function() return '' end
  end
setmetatable(_G, meta)
