local utils = {}

local pairs = pairs
local ipairs = ipairs
local s_gsub = string.gsub

local utf8 = utf8 or require('.utf8_polyfill')

---Shallow copy a table's sequence part using `ipairs`.
---@param from table
---@param into table?
---@return table
function utils.copy_ipairs(from, into)
	into = into or {}
	for i, v in ipairs(from) do
		into[i] = v
	end
	return into
end

---Shallow copy a table using `pairs`.
---@param from table
---@---@param into table?
---@return table
function utils.copy_pairs(from, into)
	into = into or {}
	for k, v in pairs(from) do
		into[k] = v
	end
	return into
end

---Shallow copy a table without calling `__pairs` metamethod.
---@param from table
---@param into table?
---@return table
function utils.raw_shallow_copy(from, into)
	into = into or {}
	for k, v in next, from do
		into[k] = v
	end
	return into
end

---Apply `func` to each element of `...` and return a table.
---@param func function | table callable
---@vararg any
---@return any[]
function utils.map_varargs(func, ...)
	local n = select('#', ...)
	local t = {...}
	for i = 1, n do
		t[i] = func(t[i])
	end
	return t
end

local NBSP = '\194\160'
local ENTITY_ENCODE_MAP = {
	['&'] = '&amp;',
	[NBSP] = '&nbsp;',
	['"'] = '&quot;',
	['<'] = '&lt;',
	['>'] = '&gt;',
}

---Replace `&`, NBSP, `"`, `<`, `>` with entities.
---@param str string | number
---@return string
function utils.attr_encode(str)
	return (s_gsub(str, '\194?[\160&"<>]', ENTITY_ENCODE_MAP))
end

---Replace `&`, NBSP, `<`, `>` with entities.
---@param str string | number
---@return string
function utils.html_encode(str)
	return (s_gsub(str, '\194?[\160&<>]', ENTITY_ENCODE_MAP))
end

---Retrun truthy value when `name` is a valid XML name, otherwise falsy value.
---
---Defined at:
---- https://www.w3.org/TR/xml/#NT-Name
---- https://www.w3.org/TR/xml11/#NT-Name
---
---TODO: non-ASCII support
---@param name any
---@return any
function utils.is_xml_name(name)
	return type(name) == 'string' and name:find('^[:%a_][:%w_%-%.]*$')
end

local NON_CUSTOM_NAMES = {
	['annotation-xml'] = true,
	['color-profile'] = true,
	['font-face'] = true,
	['font-face-src'] = true,
	['font-face-uri'] = true,
	['font-face-format'] = true,
	['font-face-name'] = true,
	['missing-glyph'] = true,
}
---defined at https://html.spec.whatwg.org/#prod-pcenchar
local PCEN_CHAR_RANGES = {
	{0x2D,    0x2E},  -- '-', '.'
	{0x30,    0x39},  -- 0-9
	{0x5F,    0x5F},  -- '_'
	{0x61,    0x7A},  -- a-z
	{0xB7,    0xB7},
	{0xC0,    0xD6},
	{0xD8,    0xF6},
	{0xF8,    0x37D},
	{0x37F,   0x1FFF},
	{0x200C,  0x200D},
	{0x203F,  0x2040},
	{0x2070,  0x218F},
	{0x2C00,  0x2FEF},
	{0x3001,  0xD7FF},
	{0xF900,  0xFDCF},
	{0xFDF0,  0xFFFD},
	{0x10000, 0xEFFFF},
}
---@param code_point integer
---@return boolean
local function is_pcen_char_code(code_point)
	for _, range in ipairs(PCEN_CHAR_RANGES) do
		if code_point >= range[1] and code_point <= range[2] then
			return true
		end
	end
	return false
end

---Retrun truthy value when `name` is a valid HTML tag name, otherwise falsy value.
---
---Defined at:
---- https://html.spec.whatwg.org/#syntax-tag-name
---- https://html.spec.whatwg.org/#prod-potentialcustomelementname
---@param name any
---@return any
function utils.is_html_tag_name(name)
	if type(name) ~= 'string' then
		return false
	elseif name:find('^%w+$') then
		return true
	elseif NON_CUSTOM_NAMES[name:lower()] then
		return true
	end
	---@cast name string
	local subs1, subs2 = name:match('^%l('..utf8.charpattern..'-)%-(%l'..utf8.charpattern..'*)$')
	if not subs1 then
		return false
	end

	---@param s string
	---@return boolean
	local function validate(s)
		if s:find('^[%-%.%d_%l]') then
			return true
		end
		for _, cp in utf8.codes(s) do
			if not is_pcen_char_code(cp) then
				return false
			end
		end
		return true
	end

	return validate(subs1) and validate(subs2)
end

---Retrun truthy value when `name` is a valid HTML attribute name, otherwise falsy value.
---
---Defined at:
---- https://html.spec.whatwg.org/#syntax-attribute-name
---@param name any
---@return any
function utils.is_html_attr_name(name)
	if type(name) ~= 'string' then
		return false
	elseif name:find('[%z\1-\31\127 "\'>/=]') then
		return false
	end
	return true
end

---Retrun truthy value when `name` reserved by Lua (e.g., '_G', '_PROMPT'), otherwise falsy value.
---@param name any
---@return any
function utils.is_lua_reserved_name(name)
	return type(name) == 'string' and name:find('^_[%u%d]+$')
end

---@param str string | number
---@return table
function utils.parse_shorthand_attrs(str)
	-- parse id
	local id = nil
	str = s_gsub(str, '#([^%s#]*)', function (s)
		if s == '' then
			error('empty id', 4)
		end
		if id then
			error('puplicate id: '..s, 4)
		end
		id = s
		return ''
	end)

	-- parse class
	local class = str:gsub('^%s*(.-)%s*$', '%1'):gsub('%s+', ' ')

	return {
		id = id,
		class = class ~= '' and class or nil,
	}
end

return utils
