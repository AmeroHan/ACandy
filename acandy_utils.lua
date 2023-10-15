local utils = {}

local insert = table.insert
local gsub = string.gsub


--- Split string by separator.
--- @param str string
--- @param sep string
function utils.split(str, sep)
	local list = {}
	for substr in string.gmatch(str, sep) do
		insert(list, substr)
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
	return (gsub(str, '[<>&"]', HTML_ENCODE_MAP))
end

return utils
