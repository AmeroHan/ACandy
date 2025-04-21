local getmt = getmetatable
local setmt = setmetatable
local tostring = tostring

local classes = {}

---@class StringSymbol: Symbol
---@field getter fun(t: table): string
local SYM_STRING = {}

function SYM_STRING.getter(t)
	return t[SYM_STRING]
end

classes.SYM_STRING = SYM_STRING


---@type {[metatable]: true, register: fun(self: self, mt: metatable): metatable}
local node_mts = setmt({
	---Register a metatable as a node metatable.
	register = function (self, mt)
		self[mt] = true
		return mt
	end,
}, { __mode = 'k' })
---To judge when a table with `__tostring` is being serialized, whether or not
---escape the string. If the table is an acandy node, it should not be escaped,
---as the node itself will handle the escaping.
classes.node_mts = node_mts


---@class Comment

local Comment_mt = node_mts:register {
	__tostring = function (self)
		return '<!--'..(self[SYM_STRING] or '')..'-->'
	end,
}
---Comment.
---
---Defined at https://html.spec.whatwg.org/#comments
---@param content string?
---@return Comment
---@nodiscard
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
	return setmt({ [SYM_STRING] = content }, Comment_mt)
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
---@operator concat(Raw): Raw

local Raw_mt  ---@type metatable
Raw_mt = node_mts:register {
	__tostring = SYM_STRING.getter,
	__concat = function (left, right)
		if getmt(left) ~= Raw_mt or getmt(right) ~= Raw_mt then
			error('Raw object can only be concatenated with another Raw object', 2)
		end
		return setmt({ [SYM_STRING] = left[SYM_STRING]..right[SYM_STRING] }, Raw_mt)
	end,
	__newindex = function ()
		error('Raw object is immutable', 2)
	end,
}

---Create a Raw object, which would not be encoded when converted to string.
---@param content any value to be converted to string by `tostring()`
---@return Raw
---@nodiscard
function classes.Raw(content)
	return setmt({ [SYM_STRING] = tostring(content) }, Raw_mt)
end

return classes
