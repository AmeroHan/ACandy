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
local classes = require('acandy.classes')
local node_mts = classes.node_mts
local config_module = require('acandy.config')

---@class Symbol

local SYM_STRING = classes.SYM_STRING
local SYM_ATTR_MAP = {}  ---@type Symbol
local SYM_CHILDREN = {}  ---@type Symbol
local SYM_TAG_NAME = {}  ---@type Symbol

local KEY_LIST_LIKE = '__acandy_list_like'
local KEY_TABLE_LIKE = '__acandy_table_like'

---@param v any
---@return integer 1: list-like, 2: table-like, 0: others
---@nodiscard
local function container_level_of(v)
	local mt = getmt(v)
	if not mt then
		return type(v) == 'table' and 2 or 0
	elseif mt[KEY_TABLE_LIKE] == true then
		return 2
	elseif mt[KEY_LIST_LIKE] == true then
		return 1
	end
	return 0
end


---Append the serialized string of the Fragment to `buff`.
---Use len to avoid calling `#buff` repeatedly. This improves performance by
---~1/3.
---@param buff table
---@param frag table
---@param buff_len? integer length of `buff`, used to optimize performance.
---@param no_encode? boolean true to prevent encoding strings, e.g. when in <script>.
local function extend_str_buff_with_frag(buff, frag, buff_len, no_encode)
	if #frag == 0 then return end
	buff_len = buff_len or #buff

	local function append_serialized(node)
		local node_type = type(node)
		if container_level_of(node) >= 1 then  -- Fragment, list
			for _, child_node in ipairs(node) do
				append_serialized(child_node)
			end
		elseif node_type == 'function' then
			append_serialized(node())
		elseif node_type == 'string' then
			buff_len = buff_len + 1
			buff[buff_len] = no_encode and node or utils.html_encode(node)
		else  -- others: Raw, Element, boolean, number
			local str = tostring(node)
			if not (node_mts[getmt(node)] or no_encode) then
				str = utils.html_encode(str)
			end
			buff_len = buff_len + 1
			buff[buff_len] = str
		end
	end

	append_serialized(frag)
end

---@param buff string[]
---@param attr_map {[string]: string | number | boolean}
---@param buff_len integer?
---@return integer new_buff_len
local function extend_str_buff_with_attrs(buff, attr_map, buff_len)
	buff_len = buff_len or #buff
	for k, v in pairs(attr_map) do
		if v == true then
			-- boolean attributes
			-- https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes#boolean_attributes
			buff_len = buff_len + 2
			buff[buff_len - 1] = ' '
			buff[buff_len] = k
		elseif v then  -- exclude the case `v == false`
			buff_len = buff_len + 5
			buff[buff_len - 4] = ' '
			buff[buff_len - 3] = k
			buff[buff_len - 2] = '="'
			buff[buff_len - 1] = utils.attr_encode(tostring(v))
			buff[buff_len] = '"'
		end
	end
	return buff_len
end


local Fragment_mt = node_mts:register {
	---Flat and concat the Fragment, returns string.
	---@param self Fragment
	---@return string
	__tostring = function (self)
		if #self == 0 then return '' end

		local buff = {}
		extend_str_buff_with_frag(buff, self, 0)
		return concat(buff)
	end,
	---ACandy fragment.
	---@class Fragment<T>: {[integer]: T}
	__index = {
		concat = table.concat,
		insert = table.insert,
		---@version <5.1
		---@diagnostic disable-next-line: deprecated
		maxn = table.maxn,  -- Lua 5.1 only
		move = table.move,
		remove = table.remove,
		sort = table.sort,
		unpack = table.unpack or unpack,  ---@diagnostic disable-line: deprecated
	},
	[KEY_LIST_LIKE] = true,
}

---Constructor of Fragment.
---@param children any?
---@return Fragment
---@nodiscard
local function Fragment(children)
	if container_level_of(children) >= 1 then
		return setmt(utils.copy_ipairs(children), Fragment_mt)
	end
	return setmt({ children }, Fragment_mt)
end

---@param breadcrumb Breadcrumb
---@return string[] tag_names
---@return ({[string]: string | number | boolean} | nil)[] attr_maps
---@nodiscard
local function clone_breadcrumb_tags_and_attrs(breadcrumb)
	local new_tag_names = {}
	local new_attr_maps = {}
	local orig_attr_maps = breadcrumb[SYM_ATTR_MAP]
	for i, tag_name in ipairs(breadcrumb[SYM_TAG_NAME]) do
		new_tag_names[i] = tag_name
		new_attr_maps[i] = orig_attr_maps
	end
	return new_tag_names, new_attr_maps
end

---@param breadcrumb1 Breadcrumb
---@param breadcrumb2 Breadcrumb
---@return string[] tag_names
---@return ({[string]: string | number | boolean} | nil)[] attr_maps
---@nodiscard
local function connect_breadcrumbs(breadcrumb1, breadcrumb2)
	local new_tag_names, new_attr_maps = clone_breadcrumb_tags_and_attrs(breadcrumb1)
	local len = #new_tag_names
	local attr_maps2 = breadcrumb2[SYM_ATTR_MAP]
	for i, tag_name in ipairs(breadcrumb2[SYM_TAG_NAME]) do
		new_tag_names[len + i] = tag_name
		new_attr_maps[len + i] = attr_maps2[i]
	end
	return new_tag_names, new_attr_maps
end


---@param self Breadcrumb
---@return string
---@nodiscard
local function breadcrumb_to_string(self)
	local tag_names = self[SYM_TAG_NAME]
	local attr_maps = self[SYM_ATTR_MAP]
	local result = {}

	for i, tag_name in ipairs(tag_names) do
		result[#result+1] = '><'
		result[#result+1] = tag_name
		if attr_maps[i] then
			extend_str_buff_with_attrs(result, attr_maps[i])
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


local function ErrorEmitter(msg, level)
	return function ()
		error(msg, level)
	end
end

local error_emitters = {
	unbuilt_elem_index = ErrorEmitter('attempt to access properties of a unbuilt element', 2),
	unbuilt_elem_newindex = ErrorEmitter('attempt to assign properties of a unbuilt element', 2),
	built_elem_div = ErrorEmitter('attempt to perform division on a built element', 2),
}

---@param output_type 'html'
---@param modify_config fun(config: Config)?
---@nodiscard
local function ACandy(output_type, modify_config)
	local void_elems, raw_text_elems = config_module.parse_config(output_type, modify_config)

	---A BareElement is an Element without any properties except tag name, e.g.,
	---`acandy.div`. It is immutable and can be cached and reused.
	---Indexing a BareElement would return a BuildingElement, and calling it would
	---return a BuiltElement. Both methods would not change the element itself.
	---
	---Example:
	---```lua
	---local bare_div = a.div
	---```
	---@class BareElement
	---@operator div(BareElement | BuildingElement | Breadcrumb): Breadcrumb
	---@operator div(any): BuiltElement
	---@overload fun(props: any): BuiltElement
	---@field [string | {[string]: string | number | boolean}] BuildingElement

	---A BuildingElement is an Element derived from attribute shorthand syntax. The
	---shorthand is a string of id and space-separated class names, and the syntax
	---is to index the BareElement with a shorthand string, i.e. to put it inside
	---the brackets followed after the tag name, e.g. `acandy.div['#id cls1 cls2']`.
	---
	---Example:
	---```lua
	---local building_div = a.div['#id cls1 cls2']
	---```
	---
	---Similar to BareElements, a BuildingElement can be called to get a
	---BuiltElement with properties set.
	---@class BuildingElement
	---@operator div(BareElement | BuildingElement | Breadcrumb): Breadcrumb
	---@operator div(any): BuiltElement
	---@overload fun(props: any): BuiltElement

	---A BuiltElement is an Element derived from a BareElement or a BuildingElement
	---by calling it, which would return the BuiltElement with properties set.
	---
	---```lua
	---local built_pre1 = a.pre {
	---	class = 'lang-lua';
	---	"print('Hello, ACandy!')",
	---}
	---
	---local built_pre2 = a.pre['lang-lua'] "print('Hello, ACandy!')"
	---```
	---
	---Although named "Built", it is still mutable. Its properties can be changed by
	---assigning.
	---@class BuiltElement
	---@field tag_name string
	---@field attributes {[string]: string | number | boolean}
	---@field children Fragment?
	---@field [string] string | number | boolean attribute value
	---@field [number] any child node

	---@class Breadcrumb
	---@operator div(BareElement | BuildingElement | Breadcrumb): Breadcrumb
	---@operator div(any): BuiltElement
	---@overload fun(props: any): BuiltElement


	local BareElement_mt  ---@type metatable
	local BuiltElement_mt  ---@type metatable
	local BuildingElement_mt  ---@type metatable


	---@param tag_name string
	---@return BareElement
	---@nodiscard
	local function BareElement(tag_name)
		local str
		if void_elems[tag_name] then
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
	---@nodiscard
	local function BuildingElement(tag_name, attr_map)
		local elem = {
			[SYM_TAG_NAME] = tag_name,
			[SYM_ATTR_MAP] = attr_map,
			[SYM_CHILDREN] = not void_elems[tag_name] and {} or nil,
		}
		return setmt(elem, BuildingElement_mt)
	end


	---@param tag_name string
	---@param attr_map {[string]: string | number | boolean}
	---@param children? any[]
	---@return BuiltElement
	---@nodiscard
	local function BuiltElement(tag_name, attr_map, children)
		assert(not (void_elems[tag_name] and children), 'void elements cannot have children')
		assert(void_elems[tag_name] or type(children) == 'table', 'non-void elements must have children')
		local elem = {
			[SYM_TAG_NAME] = tag_name,
			[SYM_ATTR_MAP] = attr_map,
			[SYM_CHILDREN] = children,
		}
		return setmt(elem, BuiltElement_mt)
	end


	---Convert the object into HTML code.
	---@param self BuildingElement | BuiltElement
	---@return string
	---@nodiscard
	local function elem_to_string(self)
		local tag_name = self[SYM_TAG_NAME]

		-- format open tag
		local result = { '<', tag_name }
		extend_str_buff_with_attrs(result, self[SYM_ATTR_MAP])
		result[#result+1] = '>'

		-- return without children or close tag when being a void element
		-- void element: https://developer.mozilla.org/en-US/docs/Glossary/Void_element
		if void_elems[tag_name] then
			return concat(result)
		end

		-- format children
		extend_str_buff_with_frag(result, self[SYM_CHILDREN], nil, raw_text_elems[tag_name])
		-- format close tag
		result[#result+1] = '</'
		result[#result+1] = tag_name
		result[#result+1] = '>'

		return concat(result)
	end


	---Return tag name, attribute or child node depending on the key.
	---@param self BuiltElement
	---@param key string | number
	---@nodiscard
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

		error("element property key's type is neither 'string' nor 'number'", 2)
	end


	---@param self BareElement | BuildingElement | BuiltElement
	---@param props any
	---@return BuiltElement
	---@nodiscard
	local function new_built_elem_from_props(self, props)
		local tag_name = self[SYM_TAG_NAME]  ---@type any
		local base_attr_map = rawget(self, SYM_ATTR_MAP)
		local new_attr_map = base_attr_map and utils.copy_pairs(base_attr_map) or {}
		local container_level = container_level_of(props)

		if void_elems[tag_name] then  -- void element, e.g. <br>, <img>
			if container_level == 2 then
				-- set attributes
				for k, v in pairs(props) do
					if type(k) == 'string' then
						if not utils.is_html_attr_name(k) then
							error('invalid attribute name: '..k, 2)
						end
						new_attr_map[k] = v
					end
				end
			end
			return BuiltElement(tag_name, new_attr_map)
		end

		local new_children = {}
		if container_level == 2 then
			for k, v in pairs(props) do
				local t = type(k)
				if t == 'number' then
					new_children[k] = v
				elseif t == 'string' then
					if not utils.is_html_attr_name(k) then
						error('invalid attribute name: '..k, 2)
					end
					new_attr_map[k] = v
				end
			end
		elseif container_level == 1 then
			utils.copy_ipairs(props, new_children)
		else  -- treat as a single child
			new_children[1] = props
		end

		return BuiltElement(tag_name, new_attr_map, new_children)
	end


	---Assign to tag name, attribute or child node depending on the key.
	---@param self BuildingElement | BuiltElement
	---@param key string | number
	---@param val any
	local function set_elem_prop(self, key, val)
		if key == 'tag_name' then
			-- e.g., elem.tag_name = 'div'
			if not utils.is_html_tag_name(val) then
				error('invalid tag name: '..val, 2)
			end  ---@cast val string

			val = val:lower()

			if self[SYM_TAG_NAME] == val then return end

			self[SYM_TAG_NAME] = val
			-- create/delete children table based on whether the element is a void element
			if void_elems[val] then
				rawset(self, SYM_CHILDREN, nil)
			elseif not rawget(self, SYM_CHILDREN) then
				rawset(self, SYM_CHILDREN, {})
			end
		elseif key == 'children' or key == 'attributes' then
			error('attempt to replace the '..key..' table of the element')
		elseif type(key) == 'string' then
			-- e.g., elem.class = 'content'
			if not utils.is_html_attr_name(key) then
				error('invalid attribute name: '..key, 2)
			end
			self[SYM_ATTR_MAP][key] = val
		elseif type(key) == 'number' then
			-- e.g., elem[1] = 'some text'
			local children = rawget(self, SYM_CHILDREN)
			if not children then
				error('attempt to assign child on a void element', 2)
			end
			children[key] = val
		else
			error("element property key's type is neither 'string' nor 'number'", 2)
		end
	end


	local Breadcrumb_mt  ---@type metatable

	---@param tag_names string[]
	---@param attr_maps ({[string]: string | number | boolean} | nil)[]
	---@return Breadcrumb
	---@nodiscard
	local function Breadcrumb(tag_names, attr_maps)
		return setmt({
			[SYM_TAG_NAME] = tag_names,
			[SYM_ATTR_MAP] = attr_maps,
		}, Breadcrumb_mt)
	end

	---@param breadcrumb Breadcrumb
	---@return BuiltElement root_elem, BuiltElement leaf_elem
	---@nodiscard
	local function breadcrumb_to_built_elem(breadcrumb)
		local tag_names = breadcrumb[SYM_TAG_NAME]
		local attr_maps = breadcrumb[SYM_ATTR_MAP]
		local n = #tag_names
		local leaf_elem = BuiltElement(tag_names[n], attr_maps[n] or {}, {})
		local parent_elem = leaf_elem
		for i = n - 1, 1, -1 do
			parent_elem = BuiltElement(tag_names[i], attr_maps[i] or {}, { parent_elem })
		end
		return parent_elem, leaf_elem
	end


	---@param left Breadcrumb
	---@param right any
	---@return Breadcrumb | BuiltElement
	local function breadcrumb_div(left, right)
		local right_mt = getmt(right)

		if right_mt == BareElement_mt or right_mt == BuildingElement_mt then
			local right_tag_name = right[SYM_TAG_NAME]
			local right_attr_map = rawget(right, SYM_ATTR_MAP)

			if void_elems[right_tag_name] then
				local root_elem, leaf_elem = breadcrumb_to_built_elem(left)
				leaf_elem[SYM_CHILDREN][1] = BuiltElement(right_tag_name, right_attr_map or {})
				return root_elem
			end

			local new_tag_names, new_attr_maps = clone_breadcrumb_tags_and_attrs(left)
			local n = #new_tag_names + 1
			new_tag_names[n] = right_tag_name
			new_attr_maps[n] = right_attr_map
			return Breadcrumb(new_tag_names, new_attr_maps)
		elseif right_mt == Breadcrumb_mt then
			return Breadcrumb(connect_breadcrumbs(left, right))
		end

		local root_elem, leaf_elem = breadcrumb_to_built_elem(left)
		leaf_elem[SYM_CHILDREN][1] = right
		return root_elem
	end


	---@param left BareElement | BuildingElement | any
	---@param right any | BareElement | BuildingElement
	---@return Breadcrumb | BuiltElement
	---@nodiscard
	local function elem_div(left, right)
		local left_mt = getmt(left)
		if left_mt ~= BareElement_mt and left_mt ~= BuildingElement_mt then
			error('attempt to div a '..type(left)..' with an element', 2)
		end
		---@diagnostic disable-next-line: assign-type-mismatch
		local tag_name = left[SYM_TAG_NAME]  ---@type string
		if void_elems[tag_name] then
			error('attempt to perform division on a void element', 2)
		end
		return breadcrumb_div(Breadcrumb({ tag_name }, { rawget(left, SYM_ATTR_MAP) }), right)
	end

	BareElement_mt = node_mts:register {
		__tostring = SYM_STRING.getter,  --> string
		---Semantic sugar for setting attributes.
		---e.g. `local elem = acandy.div['#id cls1 cls2']`
		---@param self BareElement
		---@param attrs string | table
		---@return BuildingElement
		__index = function (self, attrs)
			local attr_map
			if type(attrs) == 'string' then
				attr_map = utils.parse_shorthand_attrs(attrs)
			elseif container_level_of(attrs) == 2 then
				attr_map = {}
				for k, v in pairs(attrs) do
					if type(k) == 'string' then
						if not utils.is_html_attr_name(k) then
							error('invalid attribute name: '..k, 2)
						end
						attr_map[k] = v
					end
				end
			else
				error('invalid attributes: '..tostring(attrs), 2)
			end
			---@diagnostic disable-next-line: param-type-mismatch
			return BuildingElement(self[SYM_TAG_NAME], attr_map)
		end,
		__call = new_built_elem_from_props,  --> BuiltElement
		__div = elem_div,  --> Breadcrumb | BuiltElement
		__newindex = error_emitters.unbuilt_elem_newindex,
	}
	BuildingElement_mt = node_mts:register {
		__tostring = elem_to_string,  --> string
		__call = new_built_elem_from_props,  --> BuiltElement
		__div = elem_div,  --> Breadcrumb | BuiltElement
		__index = error_emitters.unbuilt_elem_index,
		__newindex = error_emitters.unbuilt_elem_newindex,
	}
	BuiltElement_mt = node_mts:register {
		__tostring = elem_to_string,  --> string
		__index = get_elem_prop,
		__newindex = set_elem_prop,
		__div = error_emitters.built_elem_div,
	}
	Breadcrumb_mt = node_mts:register {
		__tostring = breadcrumb_to_string,  --> string
		__call = function (self, props)  --> BuiltElement
			local root_elem, leaf_elem = breadcrumb_to_built_elem(self)
			local new_leaf_elem = new_built_elem_from_props(leaf_elem, props)
			leaf_elem[SYM_ATTR_MAP] = new_leaf_elem[SYM_ATTR_MAP]
			leaf_elem[SYM_CHILDREN] = new_leaf_elem[SYM_CHILDREN]
			return root_elem
		end,
		__div = function (left, right)  --> Breadcrumb | BuiltElement
			if getmt(left) ~= Breadcrumb_mt then
				error('attempt to div a '..type(left)..' with an breadcrumb', 2)
			end
			return breadcrumb_div(left, right)
		end,
		__index = error_emitters.unbuilt_elem_index,
		__newindex = error_emitters.unbuilt_elem_newindex,
	}


	---@class ElementEntry
	---@field [string] BareElement
	local a = setmt({}, {
		---When indexing a uncached tag name, return a constructor of that element.
		---@param key string
		---@return BareElement
		__index = function (self, key)
			if not utils.is_html_tag_name(key) then
				error('invalid tag name: '..tostring(key), 2)
			end

			local lower_key = key:lower()
			local bare_elem
			if lower_key ~= key then
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
	})

	---@class SomeBareElements
	---@field [string] fun(props: any): BuiltElement[]
	---@overload fun(props: any): BuiltElement[]

	---@class SomeElementsEntry
	---@field [string] SomeBareElements
	local some = setmt({}, {
		__index = function (_, key)
			local bare_elem = a[key]
			local mt = {}

			function mt:__index(shorthand)
				local building_elem = bare_elem[shorthand]
				return function (...)
					---@diagnostic disable-next-line: param-type-mismatch
					return setmt(utils.map_varargs(building_elem, ...), Fragment_mt)
				end
			end

			function mt:__call(...)
				---@diagnostic disable-next-line: param-type-mismatch
				return setmt(utils.map_varargs(bare_elem, ...), Fragment_mt)
			end

			return setmt({}, mt)
		end,
	})

	---@class ACandy
	local acandy = {
		a = a,
		some = some,
		Comment = classes.Comment,
		Doctype = classes.Doctype,
		Fragment = Fragment,
		Raw = classes.Raw,
	}

	---Extend the environment in place with `acandy.a` as `__index`.
	---@param env table the environment to be extended, e.g. `_ENV`, `_G`
	function acandy.extend_env(env)
		utils.extend_env_with_elem_entry(env, a)
	end

	---Return a new environment based on `env` with `acandy.a` as `__index`.
	---@param env table the environment on which the new environment is based, e.g. `_ENV`, `_G`
	---@return table
	---@nodiscard
	function acandy.to_extended_env(env)
		return utils.to_extended_env_with_elem_entry(env, a)
	end

	return acandy
end

local ACANDY_EXPORTED_NAMES = {
	a = true,
	some = true,
	-- classes
	Comment = true,
	Doctype = true,
	Fragment = true,
	Raw = true,
	-- functions
	extend_env = true,
	to_extended_env = true,
}

---@class ACandyModule: ACandy
local acandy_module = setmt({
	ACandy = ACandy,
}, {
	__index = function (self, k)
		if not ACANDY_EXPORTED_NAMES[k] then
			return nil
		end
		local default_acandy = ACandy('html')
		utils.copy_pairs(default_acandy, self)
		assert(
			default_acandy[k] ~= nil,
			('`acandy[%q]` should exist but not found, please contact the author'):format(k)
		)
		return default_acandy[k]
	end,
})
return acandy_module
