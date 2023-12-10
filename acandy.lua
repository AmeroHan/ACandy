--[[
# ACandy

A module for building HTML.
一个用于构建HTML的模块。

Version requirement: Lua 5.1 or higher

GitHub: https://github.com/AmeroHan/ACandy
MIT License
Copyright (c) 2023 AmeroHan
]]

local type = type
local pairs = pairs
local format = string.format
local ipairs = ipairs
local rawget = rawget
local rawset = rawset
local tostring = tostring
local setmetatable = setmetatable


local VOID_ELEMS, HTML_ELEMS
do
	local element_config = require('acandy_elem_config')
	VOID_ELEMS = element_config.VOID_ELEMS
	HTML_ELEMS = element_config.HTML_ELEMS
end
local utils = require('acandy_utils')


--[[
## Fragment

A Fragment is an array-like table with metatable `Fragment_mt`.
]]

--- Flat and concat the Fragment, retruns string.
---@param frag table
---@return string
local function concat_fragment(frag)
	local children = {}

	local function append_serialized(node)
		local node_type = type(node)
		if node_type == 'table' and not rawget(node, '__tag_name') then
			-- Fragment
			for _, child_node in ipairs(node) do
				append_serialized(child_node)
			end
		elseif node_type == 'function' then
			-- Generator, Constructor
			append_serialized(node())
		elseif node_type == 'string' then
			-- string
			children[#children + 1] = utils.html_encode(node)
		else
			-- Others: Element, boolean, number
			children[#children + 1] = tostring(node)
		end
	end

	append_serialized(frag)
	return table.concat(children)
end


--- Metatable used by Fragment object.
local Fragment_mt = {
	__tostring = concat_fragment,
	__index = {
		concat = table.concat,
		insert = table.insert,
		---@diagnostic disable-next-line: deprecated
		maxn = table.maxn,  -- Lua 5.1 only
		move = table.move,
		remove = table.remove,
		sort = table.sort,
		---@diagnostic disable-next-line: deprecated
		unpack = table.unpack or unpack,
	},
}


--- Constructor of Fragment.
---@param children table
---@return table
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

An Element is an object which can read tag name, attributes and child nodes,
allowing to be converted to HTML code by using `tostring(element)`.
Elements contains properties, which are tag name, attributes and child nodes.
Properties can be read/assigned by indexing/assigning the element, like
`elem.tag_name = 'p'`, `elem[1]` or `elem.class`.

### BasicElement

A BasicElement is an Element without any properties except tag name, e.g.
`acandy.div`. It is unmutable and can be cached and reused.

Indexing a BasicElement would return a BuildingElement, and calling it would
return a BuiltElement. Both methods would not change the element itself.

```lua
local basic_div = acandy.div
```

### BuildingElement

A BuildingElement is an Element derived from attribute shorthand syntex. The
shorthand is a string of id and space-separated class names, and the syntex is
to index the BasicElement with a shorthand string, i.e. to put it inside the
brackets followed after the tag name, e.g. `acandy.div['#id cls1 cls2']`.

```lua
local building_div = acandy.div['#id cls1 cls2']
```

Similar to BasicElements, a BuildingElement can be called to get a
BuiltElement with properties set.

Setting properties of a BasicElement would result in the element being
converted to BuiltElement.

```lua
local my_div = acandy.div['#id cls1 cls2']  -- BuildingElement
my_div.id = "new-id"
-- now `my_div` becomes a BuiltElement
```

### BuiltElement

A BuiltElement is an Element derived from a BasicElement or a BuildingElement by
calling it, which would return the BuiltElement with properties set.

```lua
local built_pre1 = acandy.pre {
	class = 'lang-lua';
	"print('Hello, ACandy!')",
}

local built_pre2 = acandy.pre['lang-lua'] "print('Hello, ACandy!')"
```

Although named "Built", it is still mutable. Its properties can be changed by
assigning.
]]

local BasicElement_mt
local BuildingElement_mt
local BuiltElement_mt


local function new_basic_elem(tag_name)
	local str
	if VOID_ELEMS[tag_name] then
		str = format('<%s>', tag_name)
	else
		str = format('<%s></%s>', tag_name, tag_name)
	end
	local elem = {
		__tag_name = tag_name,  ---@type string
		__string = str,  ---@type string
	}
	return setmetatable(elem, BasicElement_mt)
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
			attrs[#attrs + 1] = ' '..k
		elseif v then  -- Exclude the case `v == false`.
			attrs[#attrs + 1] = format(' %s="%s"', k, utils.html_encode(tostring(v)))
		end
	end
	attrs = table.concat(attrs)

	-- Retrun without children or close tag when being a void element.
	-- Void element: https://developer.mozilla.org/en-US/docs/Glossary/Void_element
	if VOID_ELEMS[tag_name] then
		return format('<%s%s>', tag_name, attrs)
	end

	-- Format children.
	local children = concat_fragment(rawget(elem, '__children'))

	return format('<%s%s>%s</%s>', tag_name, attrs, children, tag_name)
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


BasicElement_mt = {
	__tostring = clean_elem_to_string,
	__index = set_elem_shorthand_attrs,   --> BuildingElement
	__newindex = function() error('Assigning properties is not allowed on clean element') end,
	__call = build_elem_with_props,       --> BuiltElement
}
BuildingElement_mt = {
	__tostring = elem_to_string,
	__index = get_elem_prop,
	__newindex = set_building_elem_prop,  -- metatable: BasicElement_mt -> BuiltElement_mt
	__call = build_elem_with_props,       --> BuiltElement
}
BuiltElement_mt = {
	__tostring = elem_to_string,
	__index = get_elem_prop,
	__newindex = set_elem_prop,
}


--- Create a Fragment from a generator function.
--- e.g.
--- ```
--- new_frag_from_yields(function(yield)
---    for i = 1, 5 do
---       yield(i)
---    end
--- end)  --> {1, 2, 3, 4, 5}
--- ```
---@param func fun(yield: fun(v: any))
---@return table
local function new_frag_from_yields(_self, func)
	local result = {}
	local function yield(v)
		result[#result + 1] = v
	end
	func(yield)
	return setmetatable(result, Fragment_mt)
end

--- Create a Fragment from a generator function.
--- e.g.
--- ```
--- acandy.from_yields(function(yield)
---    for i = 1, 5 do
---       yield(i)
---    end
--- end)  --> {1, 2, 3, 4, 5}
--- ```
--- or
--- ```
--- acandy.from_yields ^ function(yield)
---    for i = 1, 5 do
---       yield(i)
---    end
--- end  --> {1, 2, 3, 4, 5}
--- ```
local from_yields = setmetatable({}, {
	__call = new_frag_from_yields,
	__pow = new_frag_from_yields,
})


-- Metatable used by this module.
local acandy_mt = {}
local basic_elems_cache = {}

--- When indexing a tag name, returns a constructor of that element.
---@param _t table
---@param k string
---@return fun(param?: table | string): table | nil
function acandy_mt.__index(_t, k)
	if not utils.is_valid_xml_name(k) then
		error('Invalid tag name: '..k, 2)
	end

	local lower_k = k:lower()
	if HTML_ELEMS[lower_k] then
		k = lower_k
	end

	if not basic_elems_cache[k] then
		basic_elems_cache[k] = new_basic_elem(k)
	end
	return basic_elems_cache[k]
end

local acandy = setmetatable({
	Fragment = Fragment,
	from_yields = from_yields,
}, acandy_mt)

return acandy
