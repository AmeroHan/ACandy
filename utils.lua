local utils = {}

local pairs = pairs
local ipairs = ipairs
local s_gsub = string.gsub


---Shallow copy a table.
---@param t table
---@return table
function utils.shallow_copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

---Shallow copy a table without calling `__pairs` metamethod
---@param t table
---@return table
function utils.raw_shallow_copy(t)
	local out = {}
	for k, v in next, t do
		out[k] = v
	end
	return out
end

---Shallow copy a table's sequence part.
---@param t table
---@return table
function utils.shallow_icopy(t)
	local out = {}
	for i, v in ipairs(t) do
		out[i] = v
	end
	return out
end

---Apply `func` to each element of `...` and return a table.
---@param func function | table callable
---@vararg any
---@return any[]
function utils.map_varargs(func, ...)
	local t = {}
	for i, v in ipairs {...} do
		t[i] = func(v)
	end
	return t
end

local ENTITY_ENCODE_MAP = {
	['&'] = '&amp;',
	['\160'] = '&nbsp;',
	['"'] = '&quot;',
	['<'] = '&lt;',
	['>'] = '&gt;',
}

---Replace `&`, NBSP, `"`, `<`, `>` with entities.
---@param str string | number
---@return string
function utils.attr_encode(str)
	return (s_gsub(str, '[&\160"<>]', ENTITY_ENCODE_MAP))
end

---Replace `&`, NBSP, `<`, `>` with entities.
---@param str string | number
---@return string
function utils.html_encode(str)
	return (s_gsub(str, '[&\160<>]', ENTITY_ENCODE_MAP))
end

---Retrun truthy value when `name` is a valid XML name, otherwise falsy value.
---@param name any
---@return any
function utils.is_valid_xml_name(name)
	return type(name) == 'string' and name:find('^[:%a_][:%w_%-%.]*$')  -- https://www.w3.org/TR/xml/#NT-Name
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
