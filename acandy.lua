--- 一个用于构建HTML的模块。
---@author: AmeroHan 2023-09-26

local elementConfig = require('acandy_elem_config')
local voidElements = elementConfig.voidElements
local htmlElements = elementConfig.htmlElements

local htmlEncodeMap = {
	['<'] = '&lt;',
	['>'] = '&gt;',
	['&'] = '&amp;',
	['"'] = '&quot;'
}

--- Replace `<`, `>`, `&` and `"` with entities.
---@param str string
---@return string
local function htmlEncode(str)
	return (str:gsub('[<>&"]', htmlEncodeMap))
end


-- ## Fragment
--
-- A Fragment is an array-like table without `__tagName` property, no matter
-- whether its metatable is `fragmentMetatable`.


--- Flat and concat the Fragment, retruns string.
---@param frag table
---@return string
local function concatFragment(frag)
	local children = {}

	local function insertSerialized(node)
		if 'table' == type(node) and not rawget(node, '__tagName') then
			-- Fragment
			for _, childNode in ipairs(node) do
				insertSerialized(childNode)
			end
		elseif 'function' == type(node) then
			-- Generator, Constructor
			insertSerialized(node())
		elseif 'string' == type(node) then
			-- string
			table.insert(children, htmlEncode(node))
		else
			-- Others: Element, boolean, number
			table.insert(children, tostring(node))
		end
	end

	insertSerialized(frag)
	return table.concat(children)
end

--- Metatable used by Fragment object.
local fragmentMetatable = {}
fragmentMetatable.__tostring = concatFragment
fragmentMetatable.__index = {
	insert = table.insert,
	remove = table.remove,
	sort = table.sort
}

--- Constructor of Fragment.
---@param children table
---@return table
function Fragment(children)
	-- 浅拷贝children，避免影响children的元表
	local frag = {}
	for i, v in ipairs(children) do
		frag[i] = v
	end
	return setmetatable(frag, fragmentMetatable)
end



-- ## Element
-- An Element is a object which can read/assign tag name, attributes and child nodes,
-- allowing to be converted to HTML code by using `tostring(element)`.


--- Metatable used by Element object.
local elementMetatable = {}

--- Convert the object into HTML code.
function elementMetatable.__tostring(elem)
	local tagName = rawget(elem, '__tagName')

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
				string.format(' %s="%s"', k, htmlEncode(tostring(v)))
			)
		end
	end
	attrs = table.concat(attrs)

	-- Retrun without children or close tag when being a void element.
	-- Void element: https://developer.mozilla.org/en-US/docs/Glossary/Void_element
	if voidElements[tagName] then
		return string.format('<%s%s>', tagName, attrs)
	end

	-- Format children.
	local children = concatFragment(rawget(elem, '__children'))

	return string.format('<%s%s>%s</%s>', tagName, attrs, children, tagName)
end

--- Return tag name, attribute or child node depending on the key.
function elementMetatable.__index(t, k)
	if 'string' == type(k) then
		if 'tagName' == k then
			return rawget(t, '__tagName')
		end
		return rawget(t, '__attrs')[k]
	elseif 'number' == type(k) then
		return rawget(t, '__children')[k]
	end
	return nil
end

--- Retrun truthy value when `name` is a valid XML name, otherwise falsy value.
---@param name any
---@return string | boolean | nil
local function isValidXmlName(name)
	if 'string' ~= type(name) then
		return false
	end
	return name:match('^[:%a_][:%w_%-%.]*$')  -- https://www.w3.org/TR/xml/#NT-Name
end

--- Assign to tag name, attribute or child node depending on the key.
function elementMetatable.__newindex(t, k, v)
	if 'tagName' == k then
		-- e.g. elem.tagName = 'div'

		if not isValidXmlName(v) then
			error('Invalid tag name: ' .. v, 2)
		end

		local origTagName = rawget(t, '__tagName')

		local lower = v:lower()
		if htmlElements[lower] then
			v = lower
		end
		if origTagName == v then return end

		-- 根据元素类型，创建/删除子节点
		if voidElements[v] and rawget(t, '__children') then
			rawset(t, '__children', nil)
		elseif not (voidElements[v] or rawget(t, '__children')) then
			rawset(t, '__children', {})
		end

		-- 为tagName赋值
		rawset(t, '__tagName', v)
	elseif 'string' == type(k) then
		-- e.g. elem.class = 'content'
		if not isValidXmlName(k) then
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
---@param tagName string
---@param param? table | string
---@return table
local function Element(tagName, param)
	local o = {
		__tagName = tagName, ---@type string
		__attrs = {},        ---@type table
		__children = nil     ---@type table | nil
	}

	if voidElements[tagName] then
		-- Void element, e.g. <br>, <img>
		if 'table' == type(param) then
			for k, v in pairs(param) do
				if 'string' == type(k) then
					o.__attrs[k] = v;
				end
			end
		end
		return setmetatable(o, elementMetatable)
	end

	-- Not void element.
	o.__children = {}

	if 'table' == type(param) then
		for k, v in pairs(param) do
			if 'number' == type(k) then
				o.__children[k] = v;
			elseif 'string' == type(k) then
				if not isValidXmlName(k) then
					error('Invalid attribute name: ' .. k, 2)
				end
				o.__attrs[k] = v;
			end
		end
	elseif 'string' == type(param) then
		o.__children[1] = param
	end

	return setmetatable(o, elementMetatable)
end


--- Caches the constructors generated by `moduleMetatable.__index`
local constructorCache = {}

--- Metatable used by this module.
local moduleMetatable = {}

--- When indexing a tag name, returns a constructor of that element.
---@param t table
---@param k string | any
---@return fun(param?: table | string): table | nil
function moduleMetatable.__index(t, k)
	if not isValidXmlName(k) then
		error('Invalid tag name: ' .. k, 2)
	end
	local lower = k:lower()
	if htmlElements[lower] then
		k = lower
	end
	if not constructorCache[k] then
		constructorCache[k] = function(param)
			return Element(k, param)
		end
	end
	return constructorCache[k]
end

--- Module.
local m = setmetatable({
	Fragment = Fragment
}, moduleMetatable)

return m
