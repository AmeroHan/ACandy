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

	local function append_serialized(node)
		if type(node) == 'table' and not rawget(node, '__tag_name') then
			-- Fragment
			for _, child_node in ipairs(node) do
				append_serialized(child_node)
			end
		elseif type(node) == 'function' then
			-- Generator, Constructor
			append_serialized(node())
		elseif type(node) == 'string' then
			-- string
			table.insert(children, utils.html_encode(node))
		else
			-- Others: Element, boolean, number
			table.insert(children, tostring(node))
		end
	end

	append_serialized(frag)
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



--[[
## Element

An `Element` is a object which can read/assign tag name, attributes and child nodes, allowing
to be converted to HTML code by using `tostring(element)`.
Elements contains properties, which are tag name, attributes and child nodes. Properties can be
read/assigned by indexing/assigning the element, like `elem.tag_name = 'p'`, `elem[1]` or
`elem.class`.

A `CleanElement` is an Element without setting any properties except tag name, like `acandy.div`.
It can be cached and reused by module. It can also turn to BuildingElement or BuiltElement.
It can be called to set properties, like `acandy.div { ... }`.

A `BuildingElement` is an Element derived from attribute shorthand syntex.
The shorthand is a string of space-separated class names and id, and the syntex is to put shorthand
inside the brackets followed after the tag name, like `acandy.div['#id cls1 cls2']`.
Similar to `CleanElement`, `BuildingEmments` can be called to additionnaly set properties, like
`acandy.div['#id cls1 cls2'] { ... }`.

A `BuiltElement` is an Element which derived from `CleanElement` or `BuildingElement` by calling
it, like `acandy.div { ... }`, which provides it with properties. Although named "Built", it is
still mutable. Its properties can be changed by assigning, like `elem[1] = 'Hello!'` or
`elem.class = 'content'`.
]]

local CleanElement_mt
local BuildingElement_mt
local BuiltElement_mt

local clean_elems_cache = {}


local function new_clean_elem(tag_name)
	local str
	if VOID_ELEMS[tag_name] then
		str = string.format('<%s>', tag_name)
	else
		str = string.format('<%s></%s>', tag_name, tag_name)
	end
	local elem = {
		__tag_name = tag_name,  ---@type string
		__string = str,  ---@type string
	}
	return setmetatable(elem, CleanElement_mt)
end

local function new_building_elem(tag_name, attrs)
	local elem = {
		__tag_name = tag_name,  ---@type string
		__attrs = attrs or {},  ---@type table
		__children = not VOID_ELEMS[tag_name] and {} or nil,  ---@type table | nil
	}
	return setmetatable(elem, BuildingElement_mt)
end

local function new_built_elem(tag_name, attrs, children)
	local elem = {
		__tag_name = tag_name,  ---@type string
		__attrs = attrs,  ---@type table
		__children = children,  ---@type table
	}
	return setmetatable(elem, BuiltElement_mt)
end


--- Convert the object into HTML code.
local function elem_to_string(elem)
	local tag_name = rawget(elem, '__tag_name')

	-- Format attributes.
	local attrs = {}
	for k, v in pairs(rawget(elem, '__attrs')) do
		if v == true then
			-- Boolean attributes
			-- https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes#boolean_attributes
			table.insert(attrs, ' '..k)
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


local function clean_elem_to_string(elem)
	return rawget(elem, '__string')
end


--- Return tag name, attribute or child node depending on the key.
local function get_elem_prop(elem, k)
	if k == 'tag_name' or k == 'tagname' then
		-- e.g. `elem.tag_name`
		return rawget(elem, '__tag_name')
	elseif type(k) == 'string' then
		-- e.g. `elem.class`
		return rawget(elem, '__attrs')[k]
	elseif type(k) == 'number' then
		-- e.g. `elem[1]`
		return rawget(elem, '__children')[k]
	end

	error('Element键类型只能是string或number', 2)
end


local function build_elem_with_props(elem, props)
	local tag_name = rawget(elem, '__tag_name')
	local attrs = rawget(elem, '__attrs') or {}
	local new_attrs = {}
	for k, v in pairs(attrs) do
		new_attrs[k] = v;
	end

	if VOID_ELEMS[tag_name] then
		-- Void element, e.g. <br>, <img>
		if type(props) == 'table' then
			for k, v in pairs(props) do
				if type(k) == 'string' then
					if not utils.is_valid_xml_name(k) then
						error('Invalid attribute name: '..k, 2)
					end
					new_attrs[k] = v;
				end
			end
		end
		return new_built_elem(tag_name, new_attrs)
	end

	local new_children = {}
	if type(props) == 'table' then
		for k, v in pairs(props) do
			if type(k) == 'number' then
				new_children[k] = v;
			elseif type(k) == 'string' then
				if not utils.is_valid_xml_name(k) then
					error('Invalid attribute name: '..k, 2)
				end
				new_attrs[k] = v;
			end
		end
	else
		new_children[1] = props
	end

	return new_built_elem(tag_name, new_attrs, new_children)
end


--- Assign to tag name, attribute or child node depending on the key.
local function set_elem_prop(elem, k, v)
	if k == 'tag_name' or k == 'tagname' then
		-- e.g. elem.tag_name = 'div'

		if not utils.is_valid_xml_name(v) then
			error('Invalid tag name: '..v, 2)
		end

		local lower = v:lower()
		if HTML_ELEMS[lower] then
			v = lower
		end

		if rawget(elem, '__tag_name') == v then return end

		-- 根据元素类型，创建/删除子节点
		if VOID_ELEMS[v] and rawget(elem, '__children') then
			rawset(elem, '__children', nil)
		elseif not (VOID_ELEMS[v] or rawget(elem, '__children')) then
			rawset(elem, '__children', {})
		end

		-- 为tag_name赋值
		rawset(elem, '__tag_name', v)
	elseif type(k) == 'string' then
		-- e.g. elem.class = 'content'
		if not utils.is_valid_xml_name(k) then
			error('Invalid attribute name: '..k, 2)
		end
		rawget(elem, '__attrs')[k] = v
	elseif type(k) == 'number' then
		-- e.g. elem[1] = P 'Lorem ipsum dolor sit amet...'
		if nil == v then
			table.remove(rawget(elem, '__children'), k)
		else
			rawget(elem, '__children')[k] = v
		end
	else
		error('Element键类型只能是string或number', 2)
	end
end

local function set_building_elem_prop(elem, k, v)
	set_elem_prop(elem, k, v)
	setmetatable(elem, BuiltElement_mt)
end


--- Sementic sugar for setting attributes.
--- e.g. `local elem = acandy.div['#id cls1 cls2']`
local function set_elem_shorthand_attrs(clean_elem, shorthand_attrs)
	local attrs
	if type(shorthand_attrs) == 'string' then
		attrs = utils.parse_shorthand_attrs(shorthand_attrs)
	elseif type(shorthand_attrs) == 'table' then
		attrs = shorthand_attrs
	else
		error('Invalid attributes: '..tostring(shorthand_attrs), 2)
	end
	return new_building_elem(rawget(clean_elem, '__tag_name'), attrs)
end


CleanElement_mt = {
	__tostring = clean_elem_to_string,
	__index = set_elem_shorthand_attrs,    --> BuildingElement
	__newindex = function() error('Assigning properties is not allowed on clean element') end,
	__call = build_elem_with_props,        --> BuiltElement
}

BuildingElement_mt = {
	__tostring = elem_to_string,
	__index = get_elem_prop,
	__newindex = set_building_elem_prop,   -- metatable: CleanElement_mt -> BuiltElement_mt
	__call = build_elem_with_props,        --> BuiltElement
}

BuiltElement_mt = {
	__tostring = elem_to_string,
	__index = get_elem_prop,
	__newindex = set_elem_prop,
}



--[[
## iter()

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

	return setmetatable(result, Fragment_mt)
	-- For Lua 5.4+, `closing_val` is closed here.
	-- See:
	-- - The generic for loop
	--   http://www.lua.org/manual/5.4/manual.html#3.3.5 
	-- - To-be-closed Variable
	--   http://www.lua.org/manual/5.4/manual.html#3.3.8
end



-- Metatable used by this module.
local acandy_mt = {}

--- When indexing a tag name, returns a constructor of that element.
--- @param t table
--- @param k string
--- @return fun(param?: table | string): table | nil
function acandy_mt.__index(t, k)
	if not utils.is_valid_xml_name(k) then
		error('Invalid tag name: '..k, 2)
	end

	local lower_k = k:lower()
	if HTML_ELEMS[lower_k] then
		k = lower_k
	end

	if not clean_elems_cache[k] then
		clean_elems_cache[k] = new_clean_elem(k)
	end
	return clean_elems_cache[k]
end


local acandy = setmetatable({
	Fragment = Fragment,
	iter = iter
}, acandy_mt)

return acandy
