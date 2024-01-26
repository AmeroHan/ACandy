local utils = {}

local pairs = pairs
local ipairs = ipairs
local s_sub = string.sub
local s_find = string.find
local s_gsub = string.gsub
local s_match = string.match


--- Shallow copy a table.
---@param t table
---@return table
function utils.shallow_copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

--- Shallow copy a table's sequence part.
---@param t table
---@return table
function utils.shallow_icopy(t)
	local out = {}
	for i, v in ipairs(t) do
		out[i] = v
	end
	return out
end


--- Apply `func` to each element of `...` and return a table.
---@param func function
---@vararg any
---@return any[]
function utils.map_varargs(func, ...)
	local t = {}
	for i, v in ipairs {...} do
		t[i] = func(v)
	end
	return t
end


local REMOVE_EMPTY_PREFIXS = {
	[true] = true,
	['^'] = true,
	['^$'] = true,
}
local REMOVE_EMPTY_SUFFIXS = {
	[true] = true,
	['$'] = true,
	['^$'] = true,
}

--- Split string by separator.
---@param str string | number string to split
---@param sep string seperator, a pattern
---@param remove_empty? boolean | '^' | '$' | '^$'
function utils.split(str, sep, remove_empty)
	local out = {}
	local last = 1
	local start, stop = s_find(str, sep, last)

	if start == 1 and REMOVE_EMPTY_PREFIXS[remove_empty] then
		-- skip empty string at the beginning
		last = stop + 1
		start, stop = s_find(str, sep, start <= stop and last or (last + 1))
	end

	while start do
		local sub = s_sub(str, last, start - 1)
		if not (sub == '' and remove_empty == true) then
			out[#out + 1] = sub
		end
		last = stop + 1
		-- when start > stop (stop == start - 1), empty string is matched
		start, stop = s_find(str, sep, start <= stop and last or (last + 1))
	end

	if last <= #str or not REMOVE_EMPTY_SUFFIXS[remove_empty] then
		out[#out + 1] = s_sub(str, last)
	end
	return out
end


local ENTITY_ENCODE_MAP = {
	['<'] = '&lt;',
	['>'] = '&gt;',
	['&'] = '&amp;',
	['"'] = '&quot;'
}

--- Replace `<`, `>`, `&` and `"` with entities.
---@param str string | number
---@return string
function utils.attr_encode(str)
	return (s_gsub(str, '[<>&"]', ENTITY_ENCODE_MAP))
end


--- Replace `<`, `>`, `&` with entities.
---@param str string | number
---@return string
function utils.html_encode(str)
	return (s_gsub(str, '[<>&]', ENTITY_ENCODE_MAP))
end


--- Retrun truthy value when `name` is a valid XML name, otherwise falsy value.
---@param name any
---@return string | boolean | nil
function utils.is_valid_xml_name(name)
	if type(name) ~= 'string' then
		return false
	end
	return s_match(name, '^[:%a_][:%w_%-%.]*$')  -- https://www.w3.org/TR/xml/#NT-Name
end


---@param str string | number
---@return table
function utils.parse_shorthand_attrs(str)
	-- parse id
	local id = nil
	str = s_gsub(str, '#([^%s#]*)', function(s)
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
