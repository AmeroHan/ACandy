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
local concat = table.concat
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


---@class Symbol

local SYM_LEAF = {} ---@type Symbol
local SYM_ATTRS = {} ---@type Symbol
local SYM_STRING = {} ---@type Symbol
local SYM_CHILDREN = {} ---@type Symbol
local SYM_TAG_NAME = {} ---@type Symbol


--[[
## Fragment

A Fragment is an array-like table with metatable `Fragment_mt`.
]]

---@class Fragment: table

--- Append the serialized string of the Fragment to `strs`.
---@param strs table
---@param frag table
local function extend_strings_with_fragment(strs, frag)
	if #frag == 0 then return end

	local function append_serialized(node)
		local node_type = type(node)
		if node_type == 'table' and not rawget(node, SYM_TAG_NAME) then
			-- Fragment
			for _, child_node in ipairs(node) do
				append_serialized(child_node)
			end
		elseif node_type == 'function' then
			append_serialized(node())
		elseif node_type == 'string' then
			strs[#strs + 1] = utils.html_encode(node)
		else  -- others: Element, boolean, number
			strs[#strs + 1] = tostring(node)
		end
	end

	append_serialized(frag)
end


--- Flat and concat the Fragment, retruns string.
---@param frag table
---@return string
local function concat_fragment(frag)
	if #frag == 0 then return '' end

	local children = {}
	extend_strings_with_fragment(children, frag)
	return concat(children)
end


--- Metatable used by Fragment object.
---@type metatable
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
---@return Fragment
local function Fragment(children)
	-- 浅拷贝children，避免影响children的元表
	local frag = utils.shallow_icopy(children)
	return setmetatable(frag, Fragment_mt)
end


--[[
## Element

An Element is an object which can read tag name, attributes and child nodes,
allowing to be converted to HTML code by using `tostring(element)`.
Elements contains properties, which are tag name, attributes and child nodes.
Properties can be read/assigned by indexing/assigning the element, like
`elem.tag_name = 'p'`, `elem[1]` or `elem.class`.
]]

---@class BareElement
--[[
### BareElement

A BareElement is an Element without any properties except tag name, e.g.
`acandy.div`. It is unmutable and can be cached and reused.

Indexing a BareElement would return a BuildingElement, and calling it would
return a BuiltElement. Both methods would not change the element itself.

```lua
local bare_div = acandy.div
```
]]

---@class BuildingElement
--[[
### BuildingElement

A BuildingElement is an Element derived from attribute shorthand syntex. The
shorthand is a string of id and space-separated class names, and the syntex is
to index the BareElement with a shorthand string, i.e. to put it inside the
brackets followed after the tag name, e.g. `acandy.div['#id cls1 cls2']`.

```lua
local building_div = acandy.div['#id cls1 cls2']
```

Similar to BareElements, a BuildingElement can be called to get a
BuiltElement with properties set.

Setting properties of a BareElement would result in the element being
converted to BuiltElement.

```lua
local my_div = acandy.div['#id cls1 cls2']  -- BuildingElement
my_div.id = "new-id"
-- now `my_div` becomes a BuiltElement
```
]]

---@class ElementLinkedList

---@class BuiltElement
--[[
### BuiltElement

A BuiltElement is an Element derived from a BareElement or a BuildingElement by
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

local BareElement_mt  ---@type metatable
local BuildingElement_mt  ---@type metatable
local ElementLinkedList_mt  ---@type metatable
local BuiltElement_mt  ---@type metatable


---@param tag_name string
---@return BareElement
local function BareElement(tag_name)
	local str
	if VOID_ELEMS[tag_name] then
		str = format('<%s>', tag_name)
	else
		str = format('<%s></%s>', tag_name, tag_name)
	end
	local elem = {
		[SYM_TAG_NAME] = tag_name,  ---@type string
		[SYM_STRING] = str,  ---@type string
	}
	return setmetatable(elem, BareElement_mt)
end


---@param tag_name string
---@param attrs {[string]: string | number | boolean}
---@return BuildingElement
local function BuildingElement(tag_name, attrs)
	local elem = {
		[SYM_TAG_NAME] = tag_name,
		[SYM_ATTRS] = attrs or {},
		[SYM_CHILDREN] = not VOID_ELEMS[tag_name] and {} or nil,
	}
	return setmetatable(elem, BuildingElement_mt)
end


---@return BuiltElement
local function BuiltElement(tag_name, attrs, children)
	local elem = {
		[SYM_TAG_NAME] = tag_name,  ---@type string
		[SYM_ATTRS] = attrs,  ---@type table
		[SYM_CHILDREN] = children,  ---@type table | nil
	}
	return setmetatable(elem, BuiltElement_mt)
end


---@param self BareElement
---@return string
local function bare_elem_to_string(self)
	return self[SYM_STRING]
end


--- Convert the object into HTML code.
---@param self BuildingElement | BuiltElement
---@return string
local function elem_to_string(self)
	local tag_name = self[SYM_TAG_NAME]
	local result = {'<', tag_name}

	-- format attributes
	for k, v in pairs(self[SYM_ATTRS]) do
		if v then  -- exclude the case `v == false`
			result[#result + 1] = ' '
			result[#result + 1] = k
			-- exclude boolean attributes
			-- https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes#boolean_attributes
			if v ~= true then
				result[#result + 1] = '="'
				result[#result + 1] = utils.attr_encode(tostring(v))
				result[#result + 1] = '"'
			end
		end
	end
	result[#result + 1] = '>'

	-- retrun without children or close tag when being a void element
	-- void element: https://developer.mozilla.org/en-US/docs/Glossary/Void_element
	if VOID_ELEMS[tag_name] then
		return concat(result)
	end

	-- format children
	extend_strings_with_fragment(result, rawget(self, SYM_CHILDREN))
	result[#result + 1] = '</'
	result[#result + 1] = tag_name
	result[#result + 1] = '>'

	return concat(result)
end


--- Return tag name, attribute or child node depending on the key.
---@param self BuildingElement | BuiltElement
---@param key string | number
local function get_elem_prop(self, key)
	if key == 'tag_name' or key == 'tagname' then
		-- e.g. `elem.tag_name`
		return self[SYM_TAG_NAME]
	elseif type(key) == 'string' then
		-- e.g. `elem.class`
		return self[SYM_ATTRS][key]
	elseif type(key) == 'number' then
		-- e.g. `elem[1]`
		return self[SYM_CHILDREN][key]
	end

	error('Element键类型只能是string或number', 2)
end


---@param self BareElement | BuildingElement
---@param props any
---@return BuiltElement
local function new_built_elem_by_props(self, props)
	local tag_name = self[SYM_TAG_NAME]
	local attrs = rawget(self, SYM_ATTRS) or {}
	local new_attrs = utils.shallow_copy(attrs)

	if VOID_ELEMS[tag_name] then
		-- void element, e.g. <br>, <img>
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
		return BuiltElement(tag_name, new_attrs)
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

	return BuiltElement(tag_name, new_attrs, new_children)
end


--- Assign to tag name, attribute or child node depending on the key.
---@param self BuildingElement | BuiltElement
---@param key string | number
---@param val any
local function set_elem_prop(self, key, val)
	if key == 'tag_name' or key == 'tagname' then
		-- e.g. elem.tag_name = 'div'
		if not utils.is_valid_xml_name(val) then
			error('Invalid tag name: '..val, 2)
		end

		local lower = val:lower()
		if HTML_ELEMS[lower] then
			val = lower
		end

		if self[SYM_TAG_NAME] == val then return end

		-- 根据元素类型，创建/删除子节点
		if VOID_ELEMS[val] and rawget(self, SYM_CHILDREN) then
			rawset(self, SYM_CHILDREN, nil)
		elseif not (VOID_ELEMS[val] or rawget(self, SYM_CHILDREN)) then
			rawset(self, SYM_CHILDREN, {})
		end

		-- 为tag_name赋值
		rawset(self, SYM_TAG_NAME, val)
	elseif type(key) == 'string' then
		-- e.g. elem.class = 'content'
		if not utils.is_valid_xml_name(key) then
			error('Invalid attribute name: '..key, 2)
		end
		self[SYM_ATTRS][key] = val
	elseif type(key) == 'number' then
		-- e.g. elem[1] = P 'Lorem ipsum dolor sit amet...'
		if nil == val then
			table.remove(self[SYM_CHILDREN], key)
		else
			self[SYM_CHILDREN][key] = val
		end
	else
		error('Element键类型只能是string或number', 2)
	end
end


---@param self BuildingElement
---@param key string | number
---@param val any
local function set_building_elem_prop(self, key, val)
	set_elem_prop(self, key, val)
	setmetatable(self, BuiltElement_mt)
end


--- Sementic sugar for setting attributes.
--- e.g. `local elem = acandy.div['#id cls1 cls2']`
---@param self BareElement
---@param shorthand_attrs string | table
---@return BuildingElement
local function new_building_elem_by_shorthand_attrs(self, shorthand_attrs)
	local attrs
	if type(shorthand_attrs) == 'string' then
		attrs = utils.parse_shorthand_attrs(shorthand_attrs)
	elseif type(shorthand_attrs) == 'table' then
		attrs = shorthand_attrs
	else
		error('Invalid attributes: '..tostring(shorthand_attrs), 2)
	end
	return BuildingElement(self[SYM_TAG_NAME], attrs)
end


BareElement_mt = {
	__tostring = bare_elem_to_string,
	__index = new_building_elem_by_shorthand_attrs,  --> BuildingElement
	__call = new_built_elem_by_props,  --> BuiltElement
	__newindex = function()
		error('Assigning properties is not allowed on bare elements')
	end,
}
BuildingElement_mt = {
	__tostring = elem_to_string,
	__index = get_elem_prop,
	__newindex = set_building_elem_prop,  -- metatable: BareElement_mt -> BuiltElement_mt
	__call = new_built_elem_by_props,  --> BuiltElement
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
---@return Fragment
local function new_frag_from_yields(self, func)
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
--- or with syntex sugar to avoid calling `from_yields`, which may increase
--- indentation level in some coding styles.
--- ```
--- acandy.from_yields ^ function(yield)
---    for i = 1, 5 do
---       yield(i)
---    end
--- end  --> {1, 2, 3, 4, 5}
--- ```
--- The reason why `^` is used is that `^` has a higher priority than `/`, which
--- is used to create elements.
local from_yields = setmetatable({}, {
	__call = new_frag_from_yields,
	__pow = new_frag_from_yields,
})


--- Metatable used by this module.
local acandy_mt = {}  ---@type metatable
local bare_elems_cache = {}  ---@type {[string]: BareElement}


--- When indexing a tag name, returns a constructor of that element.
---@param k string
---@return fun(param?: table | string): table | nil
function acandy_mt:__index(k)
	if not utils.is_valid_xml_name(k) then
		error('Invalid tag name: '..k, 2)
	end

	local lower_k = k:lower()
	if HTML_ELEMS[lower_k] then
		k = lower_k
	end

	if not bare_elems_cache[k] then
		bare_elems_cache[k] = BareElement(k)
	end
	return bare_elems_cache[k]
end


local acandy = setmetatable({
	Fragment = Fragment,
	from_yields = from_yields,
}, acandy_mt)

return acandy
