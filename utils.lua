local utils = {}

local pairs = pairs
local ipairs = ipairs
local s_gsub = string.gsub


---Shallow copy a table's sequence part using `ipairs`.
---@generic T
---@param from T[]
---@param into T[]?
---@return T[]
function utils.copy_ipairs(from, into)
	into = into or {}
	for i, v in ipairs(from) do
		into[i] = v
	end
	return into
end

---Shallow copy a table using `pairs`.
---@param from table
---@param into table?
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
---@generic TIn
---@generic TOut
---@param func fun(arg: TIn): TOut
---@vararg TIn
---@return TOut[]
function utils.map_varargs(func, ...)
	local n = select('#', ...)
	local t = {...}
	for i = 1, n do
		t[i] = func(t[i])
	end
	return t
end

---@generic T
---@param list T[]
---@return {[T]: true}
function utils.list_to_bool_dict(list)
	local dict = {}
	for _, v in ipairs(list) do
		dict[v] = true
	end
	return dict
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

--[[ Unneeded for MW
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
]]

---Return truthy value when `name` is a valid HTML tag name, otherwise falsy value.
---
---Defined at:
---- https://html.spec.whatwg.org/#syntax-tag-name
---- https://html.spec.whatwg.org/#valid-custom-element-name
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

	--[[ Unneeded for MW
	---@cast name string
	local subs1, subs2 = name:match('^%l(.*)%-(.*)$')
	if not subs1 then
		return false
	end

	---@param s string
	---@return boolean
	local function validate(s)
		if s:find('^[%-%.%d_%l]*$') then
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
	]]
	return false
end

---Return truthy value when `name` is a valid HTML attribute name, otherwise falsy value.
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

---@param str string
---@return table
function utils.parse_shorthand_attrs(str)
	-- parse id
	local id = nil
	str = s_gsub(str, '#([^%s#]*)', function (s)
		if s == '' then
			error('empty id found in '..('%q'):format(str), 4)
		end
		if id then
			error('two or more ids found in '..('%q'):format(str), 4)
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
