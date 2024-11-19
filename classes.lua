local getmt = getmetatable
local setmt = setmetatable
local tostring = tostring

local classes = {}

---@type {[metatable]: true, register: fun(self: self, mt: metatable): metatable}
local node_mts = {
	---Register a metatable as a node metatable.
	register = function (self, mt)
		self[mt] = true
		return mt
	end,
}
---To judge when a table with `__tostring` is being serialized, whether or not
---escape the string. If the table is an acandy node, it should not be escaped,
---as the node itself will handle the escaping.
classes.node_mts = node_mts

local SYM_CONTENT = {}  ---@type Symbol


---@class Comment

local Comment_mt = node_mts:register {
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
			error('invalid comment content: '..('%q'):format(content), 2)
		end
	end
	return setmt({[SYM_CONTENT] = content}, Comment_mt)
end

---@class Doctype
-- Specs:
--   HTML:
--     definition: https://html.spec.whatwg.org/#the-doctype
--     serialization: https://html.spec.whatwg.org/#serialising-html-fragments
--   XML: https://www.w3.org/TR/xml/#sec-prolog-dtd
-- TODO: support any doctype

local Doctype_mt = node_mts:register {
	__tostring = function ()
		return '<!DOCTYPE html>'
	end,
}
classes.Doctype = {
	---HTML5 doctype shortcut.
	---@type Doctype
	HTML = setmetatable({}, Doctype_mt),
}


---@class Raw

local Raw_mt  ---@type metatable
Raw_mt = node_mts:register {
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
		error('Raw object is immutable', 2)
	end,
}

---Create a Raw object, which would not be encoded when converted to string.
---@param content any value to be converted to string by `tostring()`
---@return Raw
function classes.Raw(content)
	return setmt({[SYM_CONTENT] = tostring(content)}, Raw_mt)
end

return classes
