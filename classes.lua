local getmt = getmetatable
local setmt = setmetatable
local tostring = tostring

local classes = {}

local SYM_CONTENT = {}  ---@type Symbol

---@class Comment

local Comment_mt = {
	__tostring = function (self)
		return '<!--'..(self[SYM_CONTENT] or '')..'-->'
	end,
}
---Comment.
---
---Defined at https://html.spec.whatwg.org/#comments
---@param content string?
---@return Comment
function classes.Comment(content)
	if content then
		-- the text must not start with the string ">" or "->",
		-- nor contain the strings "<!--", "-->", or "--!>",
		-- nor end with the string "<!-"
		local s = '--'..content..'-'
		if
			s:find('<!--', 1, true)
			or s:find('-->', 1, true)
			or content:find('--!>', 1, true)
		then
			error('invalid comment content: '..content, 2)
		end
	end
	return setmt({[SYM_CONTENT] = content}, Comment_mt)
end

---@class Doctype
-- Specs:
--   HTML:
--     defination: https://html.spec.whatwg.org/#the-doctype
--     serializion: https://html.spec.whatwg.org/#serialising-html-fragments
--   XML: https://www.w3.org/TR/xml/#sec-prolog-dtd
-- TODO: support any doctype

classes.Doctype = {
	---HTML5 doctype shortcut. It is a table rather than string for future extension.
	---@type Doctype
	HTML = setmetatable({}, {
		__tostring = function () return '<!DOCTYPE html>' end,
	}),
}


local Raw_mt
Raw_mt = {  ---@type metatable
	__tostring = function (self)
		return self[SYM_CONTENT]
	end,
	__concat = function (left, right)
		if getmt(left) ~= Raw_mt or getmt(right) ~= Raw_mt then
			error('Raw object can only be concatenated with another Raw object', 2)
		end
		return setmt({[SYM_CONTENT] = left[SYM_CONTENT]..right[SYM_CONTENT]}, Raw_mt)
	end,
	__newindex = function ()
		error('Raw object is not mutable', 2)
	end,
}

---Create a Raw object, which would not be encoded when converted to string.
---@param content any value to be converted to string by `tostring()`
---@return table
function classes.Raw(content)
	return setmt({[SYM_CONTENT] = tostring(content)}, Raw_mt)
end

return classes
