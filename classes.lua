local getmt = getmetatable
local setmt = setmetatable
local tostring = tostring

local classes = {}

---@class Doctype
-- Specs:
--   HTML:
--     define: https://html.spec.whatwg.org/multipage/syntax.html#the-doctype
--     serialize: https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments
--   XML: https://www.w3.org/TR/xml/#sec-prolog-dtd
-- TODO: support any doctype

classes.Doctype = {
	---HTML5 doctype shortcut. It is a table rather than string for future extension.
	---@type Doctype
	HTML = setmetatable({}, {
		__tostring = function () return '<!DOCTYPE html>' end,
	}),
}

local SYM_RAW_CONTENT = {}  ---@type Symbol

local Raw_mt
Raw_mt = {  ---@type metatable
	__tostring = function (self)
		return self[SYM_RAW_CONTENT]
	end,
	__concat = function (left, right)
		if getmt(left) ~= Raw_mt or getmt(right) ~= Raw_mt then
			error('Raw object can only be concatenated with another Raw object', 2)
		end
		return setmt({[SYM_RAW_CONTENT] = left[SYM_RAW_CONTENT]..right[SYM_RAW_CONTENT]}, Raw_mt)
	end,
	__newindex = function ()
		error('Raw object is not mutable', 2)
	end,
}

---Create a Raw object, which would not be encoded when converted to string.
---@param content any value to be converted to string by `tostring()`
---@return table
function classes.Raw(content)
	return setmt({[SYM_RAW_CONTENT] = tostring(content)}, Raw_mt)
end

return classes
