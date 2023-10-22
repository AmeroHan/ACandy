local utils = {}

local t_insert = table.insert
local s_gsub = string.gsub
local s_match = string.match


--- Split string by separator.
--- @param str string
--- @param sep string
function utils.split(str, sep)
	local list = {}
	for substr in string.gmatch(str, sep) do
		t_insert(list, substr)
	end
	return list
end


local HTML_ENCODE_MAP = {
	['<'] = '&lt;',
	['>'] = '&gt;',
	['&'] = '&amp;',
	['"'] = '&quot;'
}

--- Replace `<`, `>`, `&` and `"` with entities.
--- @param str string
--- @return string
function utils.html_encode(str)
	return (s_gsub(str, '[<>&"]', HTML_ENCODE_MAP))
end


--- Retrun truthy value when `name` is a valid XML name, otherwise falsy value.
--- @param name any
--- @return string | boolean | nil
function utils.is_valid_xml_name(name)
	if type(name) ~= 'string' then
		return false
	end
	return s_match(name, '^[:%a_][:%w_%-%.]*$')  -- https://www.w3.org/TR/xml/#NT-Name
end


--- @return table
function utils.parse_shorthand_attrs(str)
	-- Parse id.
	local id = nil
	str = string.gsub(str, '#([^%s#]*)', function(s)
		if s == '' then
			error('Empty id', 4)
		end
		if id then
			error('Duplicate id: '..s, 4)
		end
		id = s
		return ''
	end)

	-- Parse class.
	local class = s_gsub(str, '%s+', ' ')
	if class == '' or class == ' ' then
		class = nil
	end

	return {
		id = id,
		class = class,
	}
end


return utils
