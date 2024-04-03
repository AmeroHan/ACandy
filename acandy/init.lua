--[[
# ACandy

A module for building HTML.
一个用于构建HTML的模块。

Version requirement: Lua 5.1 or higher

GitHub: https://github.com/AmeroHan/ACandy
MIT License
Copyright (c) 2023 - 2024 AmeroHan
]]

local type = type
local pairs = pairs
local getmt = getmetatable
local setmt = setmetatable
local assert = assert
local concat = table.concat
local ipairs = ipairs
local rawget = rawget
local rawset = rawset
local tostring = tostring

local utils = require('acandy.utils')
local VOID_ELEMS, HTML_ELEMS, NO_ENCODE_ELEMS = (function ()
	local config = require('acandy.elem_config')
	return config.VOID_ELEMS, config.HTML_ELEMS, config.NO_ENCODE_ELEMS
end)()


---@class Symbol

local SYM_ATTR_MAP = {} ---@type Symbol
local SYM_STRING = {} ---@type Symbol
local SYM_CHILDREN = {} ---@type Symbol
local SYM_TAG_NAME = {} ---@type Symbol

local MTKEY_FRAG_LIKE = '__acandy_fragment_like'
local MTKEY_PROPS_LIKE = '__acandy_props_like'


local Raw_mt  ---@type metatable

--- Create a Raw object, which would not be encoded when converted to string.
--- @param val any value to be converted to string by `tostring()`
--- @return table
local function Raw(val)
	return setmt({[SYM_STRING] = tostring(val)}, Raw_mt)
end

Raw_mt = {
	__tostring = function(self)
		return self[SYM_STRING]
	end,
	__concat = function(left, right)
		if getmt(left) ~= Raw_mt or getmt(right) ~= Raw_mt then
			error('Raw object can only be concatenated with another Raw object', 2)
		end
		return setmt({[SYM_STRING] = left[SYM_STRING]..right[SYM_STRING]}, Raw_mt)
	end,
	__newindex = function ()
		error('Raw object is not mutable', 2)
	end,
}


--[[
## Fragment

A Fragment is an array-like table with metatable `Fragment_mt`.
]]

---@class Fragment: table

--- Metatable used by Fragment object.
---@type metatable
local Fragment_mt


--- Whether `t` can be treated as a Fragment.
---@param t table
---@return boolean
local function is_table_fragment_like(t)
	local mt = getmt(t)
	return not mt or mt == Fragment_mt or mt[MTKEY_FRAG_LIKE] == true
end


--- Append the serialized string of the Fragment to `strs`.
--- Use len to avoid calling `#strs` repeatedly. This improves performance by
--- ~1/3.
---@param strs table
---@param frag table
---@param strs_len? integer number of `strs`, used to optimize performance.
---@param no_encode? boolean true to prevent encoding strings, e.g. when in <script>.
local function extend_strings_with_fragment(strs, frag, strs_len, no_encode)
	if #frag == 0 then return end
	strs_len = strs_len or #strs

	local function append_serialized(node)
		local node_type = type(node)
		if node_type == 'table' and is_table_fragment_like(node) then  -- Fragment
			for _, child_node in ipairs(node) do
				append_serialized(child_node)
			end
		elseif node_type == 'function' then
			append_serialized(node())
		elseif node_type == 'string' then
			strs_len = strs_len + 1
			strs[strs_len] = no_encode and node or utils.html_encode(node)
		else  -- others: Raw, Element, boolean, number
			strs_len = strs_len + 1
			strs[strs_len] = tostring(node)
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
	extend_strings_with_fragment(children, frag, 0)
	return concat(children)
end


Fragment_mt = {
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
---@param children any?
---@return Fragment
local function Fragment(children)
	if type(children) == 'table' and is_table_fragment_like(children) then
		return setmt(utils.shallow_icopy(children), Fragment_mt)
	end
	return setmt({children}, Fragment_mt)
end


---@class BareElement
--[[
### BareElement

A BareElement is an Element without any properties except tag name, e.g.
`acandy.div`. It is immutable and can be cached and reused.

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
]]

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

---@class ElementChain


---@param strs string[]
---@param attr_map {[string]: string | number | boolean}
---@param strs_len integer?
---@return integer
local function extend_strings_with_attrs(strs, attr_map, strs_len)
	strs_len = strs_len or #strs
	for k, v in pairs(attr_map) do
		if v == true then
			-- boolean attributes
			-- https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes#boolean_attributes
			strs_len = strs_len + 2
			strs[strs_len-1] = ' '
			strs[strs_len] = k
		elseif v then  -- exclude the case `v == false`
			strs_len = strs_len + 5
			strs[strs_len-4] = ' '
			strs[strs_len-3] = k
			strs[strs_len-2] = '="'
			strs[strs_len-1] = utils.attr_encode(tostring(v))
			strs[strs_len] = '"'
		end
	end
	return strs_len
end


local BareElement_mt  ---@type metatable
local BuiltElement_mt  ---@type metatable
local BuildingElement_mt  ---@type metatable
local ElementChain_mt  ---@type metatable


---@param tag_name string
---@return BareElement
local function BareElement(tag_name)
	local str
	if VOID_ELEMS[tag_name] then
		str = '<'..tag_name..'>'
	else
		str = '<'..tag_name..'></'..tag_name..'>'
	end
	local elem = {
		[SYM_TAG_NAME] = tag_name,  ---@type string
		[SYM_STRING] = str,  ---@type string
	}
	return setmt(elem, BareElement_mt)
end


---@param tag_name string
---@param attr_map {[string]: string | number | boolean}
---@return BuildingElement
local function BuildingElement(tag_name, attr_map)
	local elem = {
		[SYM_TAG_NAME] = tag_name,
		[SYM_ATTR_MAP] = attr_map,
		[SYM_CHILDREN] = not VOID_ELEMS[tag_name] and {} or nil,
	}
	return setmt(elem, BuildingElement_mt)
end


---@param tag_name string
---@param attr_map {[string]: string | number | boolean}
---@param children? any[]
---@return BuiltElement
local function BuiltElement(tag_name, attr_map, children)
	assert(not (VOID_ELEMS[tag_name] and children), 'void elements cannot have children')
	assert(VOID_ELEMS[tag_name] or type(children) == 'table', 'non-void elements must have children')
	local elem = {
		[SYM_TAG_NAME] = tag_name,
		[SYM_ATTR_MAP] = attr_map,
		[SYM_CHILDREN] = children,
	}
	return setmt(elem, BuiltElement_mt)
end


---@param tag_names string[]
---@param attr_maps {[string]: string | number | boolean}[]
---@return ElementChain
local function ElementChain(tag_names, attr_maps)
	local elem_chain = {
		[SYM_TAG_NAME] = tag_names,
		[SYM_ATTR_MAP] = attr_maps,
	}
	return setmt(elem_chain, ElementChain_mt)
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

	-- format open tag
	local result = {'<', tag_name}
	extend_strings_with_attrs(result, self[SYM_ATTR_MAP])
	result[#result+1] = '>'

	-- retrun without children or close tag when being a void element
	-- void element: https://developer.mozilla.org/en-US/docs/Glossary/Void_element
	if VOID_ELEMS[tag_name] then
		return concat(result)
	end

	-- format children
	extend_strings_with_fragment(result, self[SYM_CHILDREN], nil, NO_ENCODE_ELEMS[tag_name])
	-- format close tag
	result[#result+1] = '</'
	result[#result+1] = tag_name
	result[#result+1] = '>'

	return concat(result)
end


--- Return tag name, attribute or child node depending on the key.
---@param self BuiltElement
---@param key string | number
local function get_elem_prop(self, key)
	if key == 'tag_name' then
		return self[SYM_TAG_NAME]
	elseif key == 'children' then
		local children = rawget(self, SYM_CHILDREN)
		return children and setmt(children, Fragment_mt)
	elseif key == 'attributes' then
		return self[SYM_ATTR_MAP]
	elseif type(key) == 'string' then
		-- e.g. `elem.class`
		return self[SYM_ATTR_MAP][key]
	elseif type(key) == 'number' then
		-- e.g. `elem[1]`
		local children = rawget(self, SYM_CHILDREN)
		return children and children[key]  -- no error for ipairs
	end

	error("element property key type is neither 'string' nor 'number'", 2)
end


local function is_table_props_like(t)
	local mt = getmt(t)
	return not mt or mt[MTKEY_PROPS_LIKE] == true
end


---@param self BareElement | BuildingElement | BuiltElement
---@param props_or_child any
---@return BuiltElement
local function new_built_elem_from_props(self, props_or_child)
	local tag_name = self[SYM_TAG_NAME]
	local attr_map = rawget(self, SYM_ATTR_MAP) or {}
	local new_attr_map = utils.shallow_copy(attr_map)
	local arg_is_props_like = type(props_or_child) == 'table' and is_table_props_like(props_or_child)

	if VOID_ELEMS[tag_name] then  -- void element, e.g. <br>, <img>
		if arg_is_props_like then
			-- props_or_child is props
			-- set attributes
			for k, v in pairs(props_or_child) do
				if type(k) == 'string' then
					if not utils.is_valid_xml_name(k) then
						error('invalid attribute name: '..k, 2)
					end
					new_attr_map[k] = v;
				end
			end
		end
		return BuiltElement(tag_name, new_attr_map)
	end

	local new_children = {}
	if arg_is_props_like then
		-- props_or_child is props
		for k, v in pairs(props_or_child) do
			if type(k) == 'number' then
				new_children[k] = v;
			elseif type(k) == 'string' then
				if not utils.is_valid_xml_name(k) then
					error('invalid attribute name: '..k, 2)
				end
				new_attr_map[k] = v;
			end
		end
	else  -- props_or_child is child
		new_children[1] = props_or_child
	end

	return BuiltElement(tag_name, new_attr_map, new_children)
end


--- Assign to tag name, attribute or child node depending on the key.
---@param self BuildingElement | BuiltElement
---@param key string | number
---@param val any
local function set_elem_prop(self, key, val)
	if key == 'tag_name' then
		-- e.g. elem.tag_name = 'div'
		if not utils.is_valid_xml_name(val) then
			error('invalid tag name: '..val, 2)
		end

		local lower = val:lower()
		if HTML_ELEMS[lower] then
			val = lower
		end

		if self[SYM_TAG_NAME] == val then return end

		-- 根据元素类型，创建/删除子节点
		if VOID_ELEMS[val] and rawget(self, SYM_CHILDREN) then
			self[SYM_CHILDREN] = nil
		elseif not (VOID_ELEMS[val] or rawget(self, SYM_CHILDREN)) then
			rawset(self, SYM_CHILDREN, {})
		end

		-- 为tag_name赋值
		self[SYM_TAG_NAME] = val
	elseif key == 'children' or key == 'attributes' then
		error('attempt to replace the '..key..' table of the element')
	elseif type(key) == 'string' then
		-- e.g. elem.class = 'content'
		if not utils.is_valid_xml_name(key) then
			error('invalid attribute name: '..key, 2)
		end
		self[SYM_ATTR_MAP][key] = val
	elseif type(key) == 'number' then
		-- e.g. elem[1] = 'Lorem ipsum dolor sit amet...'
		local children = rawget(self, SYM_CHILDREN)
		if not children then
			error('attempt to assign child on a void element', 2)
		end
		children[key] = val
	else
		error('Element键类型只能是string或number', 2)
	end
end


--- Sementic sugar for setting attributes.
--- e.g. `local elem = acandy.div['#id cls1 cls2']`
---@param self BareElement
---@param shorthand_attrs string | table
---@return BuildingElement
local function new_building_elem_by_shorthand_attrs(self, shorthand_attrs)
	local attr_map
	if type(shorthand_attrs) == 'string' then
		attr_map = utils.parse_shorthand_attrs(shorthand_attrs)
	elseif type(shorthand_attrs) == 'table' then
		attr_map = shorthand_attrs
	else
		error('invalid attributes: '..tostring(shorthand_attrs), 2)
	end
	return BuildingElement(self[SYM_TAG_NAME], attr_map)
end


---@param self ElementChain
---@return ElementChain
local function copy_elem_chain(self)
	local new_chain = {
		[SYM_TAG_NAME] = utils.shallow_icopy(self[SYM_TAG_NAME]),
		[SYM_ATTR_MAP] = utils.shallow_icopy(self[SYM_ATTR_MAP]),
	}
	return setmt(new_chain, ElementChain_mt)
end


---@param chain ElementChain
---@param tag_name string
---@param attr_map {[string]: string | number | boolean}?
local function append_elem_to_elem_chain(chain, tag_name, attr_map)
	local new_len = #chain[SYM_TAG_NAME] + 1
	chain[SYM_TAG_NAME][new_len] = tag_name
	chain[SYM_ATTR_MAP][new_len] = attr_map
end


---@param chain1 ElementChain
---@param chain2 ElementChain
---@return ElementChain
local function connect_elem_chains(chain1, chain2)
	local new_tag_names = {}
	local new_attr_maps = {}
	local attr_maps_to_copy_from = chain1[SYM_ATTR_MAP]
	for i, tag_name in ipairs(chain1[SYM_TAG_NAME]) do
		new_tag_names[i] = tag_name
		new_attr_maps[i] = attr_maps_to_copy_from[i]
	end
	local len = #new_tag_names
	attr_maps_to_copy_from = chain2[SYM_ATTR_MAP]
	for i, tag_name in ipairs(chain2[SYM_TAG_NAME]) do
		new_tag_names[len+i] = tag_name
		new_attr_maps[len+i] = attr_maps_to_copy_from[i]
	end
	return ElementChain(new_tag_names, new_attr_maps)
end


---@param self ElementChain
---@return string
local function elem_chain_to_string(self)
	local tag_names = self[SYM_TAG_NAME]
	local attr_maps = self[SYM_ATTR_MAP]
	local result = {}

	for i, tag_name in ipairs(tag_names) do
		result[#result+1] = '><'
		result[#result+1] = tag_name
		if attr_maps[i] then
			extend_strings_with_attrs(result, attr_maps[i])
		end
	end
	result[1] = '<'

	for i = #tag_names, 1, -1 do
		result[#result+1] = '></'
		result[#result+1] = tag_names[i]
	end
	result[#result+1] = '>'

	return concat(result)
end


---@param chain ElementChain
---@return BuiltElement root_elem, BuiltElement leaf_elem
local function elem_chain_to_built_elem(chain)
	local tag_names = chain[SYM_TAG_NAME]
	local attr_maps = chain[SYM_ATTR_MAP]
	local leaf_elem
	local function f(i)
		if tag_names[i+1] then
			return BuiltElement(tag_names[i], attr_maps[i] or {}, {f(i+1)})
		end
		leaf_elem = BuiltElement(tag_names[i], attr_maps[i] or {}, {})
		return leaf_elem
	end
	return f(1), leaf_elem
end


---@param left ElementChain
---@param right any
---@return ElementChain | BuiltElement
local function elem_chain_div(left, right)
	local right_mt = getmt(right)

	if right_mt == BareElement_mt or right_mt == BuildingElement_mt then
		local right_tag_name = right[SYM_TAG_NAME]
		local right_attr_map = rawget(right, SYM_ATTR_MAP)

		if VOID_ELEMS[right_tag_name] then
			local root_elem, leaf_elem = elem_chain_to_built_elem(left)
			leaf_elem[SYM_CHILDREN][1] = BuiltElement(right_tag_name, right_attr_map or {})
			return root_elem
		end

		local new_chain = copy_elem_chain(left)
		append_elem_to_elem_chain(new_chain, right_tag_name, right_attr_map)
		return new_chain
	elseif right_mt == ElementChain_mt then
		return connect_elem_chains(left, right)
	end

	local root_elem, leaf_elem = elem_chain_to_built_elem(left)
	leaf_elem[SYM_CHILDREN][1] = right
	return root_elem
end


---@param left BareElement | BuildingElement | any
---@param right any | BareElement | BuildingElement
---@return ElementChain | BuiltElement
local function elem_div(left, right)
	local left_mt = getmt(left)
	if left_mt ~= BareElement_mt and left_mt ~= BuildingElement_mt then
		error('attempt to div a '..type(left)..' with an element', 2)
	end
	local tag_name = left[SYM_TAG_NAME]
	if VOID_ELEMS[tag_name] then
		error('attempt to perform division on a void element', 2)
	end
	return elem_chain_div(ElementChain({tag_name}, {rawget(left, SYM_ATTR_MAP)}), right)
end


local function error_wrong_index()
	error('attempt to access properties of a unbuilt element', 2)
end

local function error_wrong_newindex()
	error('attempt to assign properties of a unbuilt element', 2)
end


BareElement_mt = {
	__tostring = bare_elem_to_string,  --> string
	__index = new_building_elem_by_shorthand_attrs,  --> BuildingElement
	__call = new_built_elem_from_props,  --> BuiltElement
	__div = elem_div,  --> ElementChain | BuiltElement
	__newindex = error_wrong_newindex,
}
BuildingElement_mt = {
	__tostring = elem_to_string,  --> string
	__call = new_built_elem_from_props,  --> BuiltElement
	__div = elem_div,  --> ElementChain | BuiltElement
	__index = error_wrong_index,
	__newindex = error_wrong_newindex,
}
BuiltElement_mt = {
	__tostring = elem_to_string,  --> string
	__index = get_elem_prop,
	__newindex = set_elem_prop,
	__div = function ()
		error('attempt to perform division on a built element', 2)
	end
}
ElementChain_mt = {
	__tostring = elem_chain_to_string,  --> string
	__call = function(self, props)  --> BuiltElement
		local root_elem, leaf_elem = elem_chain_to_built_elem(self)
		local new_leaf_elem = new_built_elem_from_props(leaf_elem, props)
		leaf_elem[SYM_ATTR_MAP] = new_leaf_elem[SYM_ATTR_MAP]
		leaf_elem[SYM_CHILDREN] = new_leaf_elem[SYM_CHILDREN]
		return root_elem
	end,
	__div = function(left, right)  --> ElementChain | BuiltElement
		if getmt(left) ~= ElementChain_mt then
			error('attempt to div a '..type(left)..' with an element chain', 2)
		end
		return elem_chain_div(left, right)
	end,
	__index = error_wrong_index,
	__newindex = error_wrong_newindex,
}


local acandy
--- Metatable used by this module.
local acandy_mt = {  ---@type metatable
	--- When indexing a uncached tag name, return a constructor of that element.
	---@param key string
	---@return BareElement
	__index = function(self, key)
		if not utils.is_valid_xml_name(key) then
			error('invalid tag name: '..tostring(key), 2)
		end

		local lower_key = key:lower()
		local bare_elem
		if lower_key ~= key and HTML_ELEMS[lower_key] then
			bare_elem = rawget(self, lower_key)
			if not bare_elem then
				bare_elem = BareElement(lower_key)
				self[lower_key] = bare_elem
			end
		else
			bare_elem = BareElement(key)
		end
		self[key] = bare_elem
		return bare_elem
	end,
}


local some = setmt({}, {
	__index = function(_, key)
		local bare_elem = acandy[key]

		local mt = {}
		function mt:__index(shorthand)
			local building_elem = bare_elem[shorthand]
			return function(...)
				return setmt(utils.map_varargs(building_elem, ...), Fragment_mt)
			end
		end
		function mt:__call(...)
			return setmt(utils.map_varargs(bare_elem, ...), Fragment_mt)
		end

		return setmt({}, mt)
	end
})


acandy = setmt({
	Fragment = Fragment,
	Raw = Raw,
	some = some,
}, acandy_mt)

return acandy
