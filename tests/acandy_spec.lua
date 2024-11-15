---@diagnostic disable: undefined-field

local utils = require('tests.utils')
local acandy = require('acandy')
local a, some, Fragment = acandy.a, acandy.some, acandy.Fragment
local match_html = utils.match_html


describe('Overall test', function ()
	it('should succeed', function ()
		local f = Fragment {
			a.h1['#top heading heading-1'] 'Hello!',
			a.div {class = "container", style = "margin: 0 auto;",
				a.p {
					'My name is ', a.dfn('ACandy'), ', a module for building HTML.',
					a.br,
					'Thank you for your visit.',
				},
				a.p 'visitors:',
				a.ul / some.li('Alice', 'Bob', 'Carol', '...'),
			},
		}
		assert.is_true(match_html(tostring(f), [[
			<h1]], {' id="top"', ' class="heading heading-1"'}, [[>Hello!</h1>
			<div]], {' style="margin: 0 auto;"', ' class="container"'}, [[>
				<p>
					My name is <dfn>ACandy</dfn>, a module for building HTML.<br>
					Thank you for your visit.
				</p>
				<p>visitors:</p>
				<ul>
					<li>Alice</li>
					<li>Bob</li>
					<li>Carol</li>
					<li>...</li>
				</ul>
			</div>
		]]))
	end)
end)


describe('ACandy entry', function ()
	it('should return the same instance for the same key', function ()
		assert.is_true(rawequal(a.div, a.div))
		assert.is_true(rawequal(a.MyElement, a.MyElement))
		assert.is_false(rawequal(a.div, a.p))
		assert.is_false(rawequal(a.div, a.MyElement))
	end)

	it('should ignore letter case for HTML elements', function ()
		assert.are.equal(a.div, a.Div)
		assert.are.equal(a.div, a.DIV)
	end)

	it('is case sensitive for non-HTML elements', function ()
		assert.are_not.equal(a.MyElement, a.myelement)
	end)

	it('refuses invalid tag names', function ()
		assert.has.error(function ()
			print(a['invalid tag name'])
		end)
	end)
end)


describe('Base element', function ()
	it('returns HTML string when `tostring`', function ()
		assert.are.equal(tostring(a.div), '<div></div>')
		assert.are.equal(tostring(a.br), '<br>')
		assert.are.equal(tostring(a.MyElement), '<MyElement></MyElement>')
	end)

	it('is immutable', function ()
		assert.has.error(function ()
			a.div.tag_name = 'p'
		end)
		assert.has.error(function ()
			a.div.children = {}
		end)
		assert.has.error(function ()
			a.div.attributes = {id = 'id'}
		end)
		assert.has.error(function ()
			a.div[1] = 'child'
		end)
		assert.has.error(function ()
			a.div.id = 'id'
		end)
	end)
end)


describe('Building element', function ()
	local div = a.div

	it('can be gotten by indexing a base element with id and/or class', function ()
		assert.are.equal(tostring(div['my-class']), '<div class="my-class"></div>')
		assert.are.equal(tostring(div[' my-class ']), '<div class="my-class"></div>')

		assert.are.equal(tostring(div['#my-id']), '<div id="my-id"></div>')
		assert.are.equal(tostring(div[' #my-id ']), '<div id="my-id"></div>')

		assert.is_true(match_html(
			tostring(div['#my-id my-class']),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
		assert.is_true(match_html(
			tostring(div['my-class #my-id']),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
		assert.is_true(match_html(
			tostring(div['my-class#my-id']),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
		assert.is_true(match_html(
			tostring(div[' my-class \n #my-id ']),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
	end)

	it('raises an error when multiple id provided', function ()
		assert.has.error(function ()
			local never = div['#id1#id2']
		end)
		assert.has.error(function ()
			local never = div['#id1 #id2']
		end)
	end)

	it('can be gotten by indexing a base element with table', function ()
		assert.is_true(match_html(
			tostring(div[{id = "my-id", class = "my-class"}]),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
	end)

	it('raises errors when trying to get properties', function ()
		local elem = div['my-class']
		assert.has.error(function ()
			print(elem.tag_name)
		end)
		assert.has.error(function ()
			print(elem.children)
		end)
		assert.has.error(function ()
			print(elem.attributes)
		end)
		assert.has.error(function ()
			print(elem[1])
		end)
		assert.has.error(function ()
			print(elem.id)
		end)
	end)

	it('is immutable', function ()
		local elem = div['my-class']
		assert.has.error(function ()
			elem.tag_name = 'p'
		end)
		assert.has.error(function ()
			elem.children = {}
		end)
		assert.has.error(function ()
			elem.attributes = {id = 'id'}
		end)
		assert.has.error(function ()
			elem[1] = 'child'
		end)
		assert.has.error(function ()
			elem.id = 'id'
		end)
	end)
end)


describe('Built element', function ()
	it('can come from base element', function ()
		assert.are.equal(tostring(a.div()), '<div></div>')
		assert.are.equal(tostring(a.div('hi')), '<div>hi</div>')
		assert.are.equal(tostring(a.div(114)), '<div>114</div>')
		assert.are.equal(tostring(a.div(a.p)), '<div><p></p></div>')

		assert.are.equal(tostring(a.div(function ()
			return function () return 'hi' end
		end)), '<div>hi</div>')

		assert.are.equal(tostring(a.div(
			setmetatable({}, {__tostring = function () return 'hi' end})
		)), '<div>hi</div>')

		assert.is_true(match_html(
			tostring(a.div {
				class = "cls", id = "id", ['data-uwu'] = "UwU",
				'a', 1,
				{'b', 2},
				function ()
					return {'c', 3, function () return {'d', 4} end}
				end,
			}),
			'<div', {' class="cls"', ' id="id"', ' data-uwu="UwU"'}, '>a1b2c3d4</div>'
		))
	end)

	it('can come from building element', function ()
		local building = a.div[{class = "cls"}]
		assert.are.equal(tostring(building()), '<div class="cls"></div>')
		assert.are.equal(tostring(building('hi')), '<div class="cls">hi</div>')
		assert.is_true(match_html(
			tostring(building({class = "new", id = "id", 'hi'})),
			'<div', {' class="new"', ' id="id"'}, '>hi</div>'
		))
		assert.are.equal(tostring(building {
			'a', 1,
			{'b', 2},
			function ()
				return {'c', 3, function () return {'d', 4} end}
			end,
		}), '<div class="cls">a1b2c3d4</div>')
	end)

	it('has properties', function ()
		local li = a.li 'item 1'
		local list = a.ol {id = "my-id", li}

		-- get
		assert.are.equal(list.tag_name, 'ol')
		assert.is_true(rawequal(list.children[1], li))
		assert.is_true(rawequal(list[1], li))
		assert.are.equal(list.attributes.id, 'my-id')
		assert.are.equal(list.id, 'my-id')

		-- set
		list.tag_name = 'ul'
		list.children:insert(a.li 'item 2')
		list[3] = a.li 'item 3'
		list.attributes.id = 'new-id'
		list.style = 'color: blue;'
		assert.is_true(match_html(tostring(list), [[
			<ul]], {' id="new-id"', ' style="color: blue;"'}, [[>
				<li>item 1</li>
				<li>item 2</li>
				<li>item 3</li>
			</ul>
		]]))
	end)
end)


describe('String escaping', function ()
	local str = '& \194\160 " \' < > &amp; &nbsp; &quot; &apos; &lt; &gt;'

	it('replaces `& NBSP " < >` in attribute values with named references', function ()
		local answer = '<div class="'
			..'&amp; &nbsp; &quot; \' &lt; &gt; '
			..'&amp;amp; &amp;nbsp; &amp;quot; &amp;apos; &amp;lt; &amp;gt;'
			..'"></div>'
		assert.are.equal(tostring(a.div[str]), answer)
		assert.are.equal(tostring(a.div[{class = str}]), answer)
		assert.are.equal(tostring(a.div {class = str}), answer)
	end)

	it('replaces `& NBSP < >` in texts other than attribute value with named references', function ()
		local answer = '<div>'
			..'&amp; &nbsp; " \' &lt; &gt; '
			..'&amp;amp; &amp;nbsp; &amp;quot; &amp;apos; &amp;lt; &amp;gt;'
			..'</div>'
		assert.are.equal(tostring(a.div(str)), answer)
	end)

	it("does not replace characters in an object's properties", function ()
		local elem = a.div[str](str)
		assert.are.equal(elem.class, str)
		assert.are.equal(elem[1], str)
		local _ = tostring(elem)
		assert.are.equal(elem.class, str)
		assert.are.equal(elem[1], str)
	end)
end)

describe('Raw text element', function ()
	local str = '& \194\160 " \' < > &amp; &nbsp; &quot; &apos; &lt; &gt;'

	it("does not encode any character in text child", function ()
		assert.are.equal(tostring(a.style(str)), '<style>'..str..'</style>')
		assert.are.equal(tostring(a.script(str)), '<script>'..str..'</script>')
	end)

	it("does not check end tag", function ()
		assert.are.equal(tostring(a.style('</style>')), '<style></style></style>')
		assert.are.equal(tostring(a.script('</script>')), '<script></script></script>')
	end)
end)
