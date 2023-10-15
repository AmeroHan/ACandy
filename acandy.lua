--- ACandy
---
--- A module for building HTML.
--- 一个用于构建HTML的模块。
---
--- Version requirement: Lua 5.1 or higher
---
--- GitHub: https://github.com/AmeroHan/ACandy
--- MIT License
--- Copyright (c) 2023 AmeroHan

local VOID_ELEMS, HTML_ELEMS
do
	local element_config = require('acandy_elem_config')
	VOID_ELEMS = element_config.VOID_ELEMS
	HTML_ELEMS = element_config.HTML_ELEMS
end
local utils = require('acandy_utils')


-- ## Fragment
--
-- A Fragment is an array-like table without `__tag_name` property, no matter
-- whether its metatable is `fragment_mt`.


--- Flat and concat the Fragment, retruns string.
--- @param frag table
--- @return string
local function concat_fragment(frag)
	local children = {}

	local function insert_serialized(node)
		if 'table' == type(node) and not rawget(node, '__tag_name') then
			-- Fragment
			for _, child_node in ipairs(node) do
				insert_serialized(child_node)
			end
		elseif 'function' == type(node) then
			-- Generator, Constructor
			insert_serialized(node())
		elseif 'string' == type(node) then
			-- string
			table.insert(children, utils.html_encode(node))
		else
			-- Others: Element, boolean, number
			table.insert(children, tostring(node))
		end
	end

	insert_serialized(frag)
	return table.concat(children)
end

--- Metatable used by Fragment object.
local Fragment_mt = {}
Fragment_mt.__tostring = concat_fragment
Fragment_mt.__index = {
	insert = table.insert,
	remove = table.remove,
	sort = table.sort
}

--- Constructor of Fragment.
--- @param children table
--- @return table
local function Fragment(children)
	-- 浅拷贝children，避免影响children的元表
	local frag = {}
	for i, v in ipairs(children) do
		frag[i] = v
	end
	return setmetatable(frag, Fragment_mt)
end



-- ## Element
-- An Element is a object which can read/assign tag name, attributes and child nodes,
-- allowing to be converted to HTML code by using `tostring(element)`.


--- Metatable used by Element object.
local Element_mt = {}

--- Convert the object into HTML code.
function Element_mt.__tostring(elem)
	local tag_name = rawget(elem, '__tag_name')

	-- Format attributes.
	local attrs = {}
	for k, v in pairs(rawget(elem, '__attrs')) do
		if true == v then
			-- Boolean attributes
			-- https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes#boolean_attributes
			table.insert(attrs, ' ' .. k)
		elseif v then  -- Exclude the case `v == false`.
			table.insert(
				attrs,
				string.format(' %s="%s"', k, utils.html_encode(tostring(v)))
			)
		end
	end
	attrs = table.concat(attrs)

	-- Retrun without children or close tag when being a void element.
	-- Void element: https://developer.mozilla.org/en-US/docs/Glossary/Void_element
	if VOID_ELEMS[tag_name] then
		return string.format('<%s%s>', tag_name, attrs)
	end

	-- Format children.
	local children = concat_fragment(rawget(elem, '__children'))

	return string.format('<%s%s>%s</%s>', tag_name, attrs, children, tag_name)
end

--- Return tag name, attribute or child node depending on the key.
function Element_mt.__index(t, k)
	if 'string' == type(k) then
		if 'tag_name' == k then
			return rawget(t, '__tag_name')
		end
		return rawget(t, '__attrs')[k]
	elseif 'number' == type(k) then
		return rawget(t, '__children')[k]
	end
	return nil
end

--- Retrun truthy value when `name` is a valid XML name, otherwise falsy value.
--- @param name any
--- @return string | boolean | nil
local function is_valid_xml_name(name)
	if 'string' ~= type(name) then
		return false
	end
	return name:match('^[:%a_][:%w_%-%.]*$')  -- https://www.w3.org/TR/xml/#NT-Name
end

--- Assign to tag name, attribute or child node depending on the key.
function Element_mt.__newindex(t, k, v)
	if 'tag_name' == k then
		-- e.g. elem.tag_name = 'div'

		if not is_valid_xml_name(v) then
			error('Invalid tag name: ' .. v, 2)
		end

		local orig_tag_name = rawget(t, '__tag_name')

		local lower = v:lower()
		if HTML_ELEMS[lower] then
			v = lower
		end
		if orig_tag_name == v then return end

		-- 根据元素类型，创建/删除子节点
		if VOID_ELEMS[v] and rawget(t, '__children') then
			rawset(t, '__children', nil)
		elseif not (VOID_ELEMS[v] or rawget(t, '__children')) then
			rawset(t, '__children', {})
		end

		-- 为tag_name赋值
		rawset(t, '__tag_name', v)
	elseif 'string' == type(k) then
		-- e.g. elem.class = 'content'
		if not is_valid_xml_name(k) then
			error('Invalid attribute name: ' .. k, 2)
		end
		rawget(t, '__attrs')[k] = v
	elseif 'number' == type(k) then
		-- e.g. elem[1] = P 'Lorem ipsum dolor sit amet...'
		if nil == v then
			table.remove(rawget(t, '__children'), k)
		else
			rawget(t, '__children')[k] = v
		end
	else
		error('Element键类型只能是string或number', 2)
	end
end

--- Constructor of Element.
--- @param tag_name string
--- @param param? table | string
--- @return table
local function Element(tag_name, param)
	local o = {
		__tag_name = tag_name, --- @type string
		__attrs = {},        --- @type table
		__children = nil     --- @type table | nil
	}

	if VOID_ELEMS[tag_name] then
		-- Void element, e.g. <br>, <img>
		if 'table' == type(param) then
			for k, v in pairs(param) do
				if 'string' == type(k) then
					o.__attrs[k] = v;
				end
			end
		end
		return setmetatable(o, Element_mt)
	end

	-- Not void element.
	o.__children = {}

	if 'table' == type(param) then
		for k, v in pairs(param) do
			if 'number' == type(k) then
				o.__children[k] = v;
			elseif 'string' == type(k) then
				if not is_valid_xml_name(k) then
					error('Invalid attribute name: ' .. k, 2)
				end
				o.__attrs[k] = v;
			end
		end
	else
		o.__children[1] = param
	end

	return setmetatable(o, Element_mt)
end


--[[--
Iterate over the return values of an iterator and call `user_func` with them.
Returns an array whose items are the non-nil value returned by `user_func`.

```lua
local function user_func(__1__)
	-- Do something with __1__...
	return __3__
end
local array = iter(user_func, __2__)
```

is approximately equivalent to

```lua
local array = {}
for __1__ in __2__ do
	-- Do something with __1__...
	-- and get __3__.
	table.insert(array, __3__)
end
```

except that if `user_func` returns multiple values, all of them are inserted into `array`,
while nil values being ignored.

## Example

```lua
local array = iter(
	function(i, v)
		return i, v
	end,
	ipairs({ 'a', 'b', 'c' })
)
```

Now `array` is

```lua
{ 1, 'a', 2, 'b', 3, 'c' }
```
]]
local function iter(user_func, iter_func, state, ctrl_var, closing_val)
	local insert = table.insert
	local select = select
	local result = {}

	--- Insert non-nil values returned by `user_func` into `result`.
	local function insert_non_nil_vals(...)
		local n = select('#', ...)
		for i = 1, n do
			local v = select(i, ...)
			if v ~= nil then
				insert(result, v)
			end
		end
	end

	--- Deal with values returned by `iter_func`, like what `for` statement does.
	local function iter_once(...)
		ctrl_var = ...
		if ctrl_var == nil then return false end

		insert_non_nil_vals(user_func(...))
		return true
	end

	while iter_once(iter_func(state, ctrl_var)) do
		-- Do nothing.
	end

	return result
	-- For Lua 5.4+, `closing_val` is closed here.
	-- See:
	-- - The generic for loop
	--   http://www.lua.org/manual/5.4/manual.html#3.3.5 
	-- - To-be-closed Variable
	--   http://www.lua.org/manual/5.4/manual.html#3.3.8
end


-- Caches the constructors generated by `module_mt.__index`
local constructor_cache = {}

-- Metatable used by this module.
local acandy_mt = {}

--- When indexing a tag name, returns a constructor of that element.
--- @param t table
--- @param k string | any
--- @return fun(param?: table | string): table | nil
function acandy_mt.__index(t, k)
	if not is_valid_xml_name(k) then
		error('Invalid tag name: ' .. k, 2)
	end
	local lower = k:lower()
	if HTML_ELEMS[lower] then
		k = lower
	end
	if not constructor_cache[k] then
		constructor_cache[k] = function(param)
			return Element(k, param)
		end
	end
	return constructor_cache[k]
end


local acandy = setmetatable({
	Fragment = Fragment,
	iter = iter
}, acandy_mt)

return acandy
