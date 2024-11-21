local utils = require('tests.test_utils')
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


describe('ACandy element entry', function ()
	it('should return the same instance for the same key', function ()
		assert.is_true(rawequal(a.div, a.div))
		assert.is_true(rawequal(a['custom-element'], a['custom-element']))
		assert.is_true(rawequal(a['my-custom-element'], a['my-custom-element']))
		assert.is_true(rawequal(a['custom-元素'], a['custom-元素']))
		assert.is_false(rawequal(a.div, a.p))
		assert.is_false(rawequal(a.div, a['custom-element']))
	end)

	it('is case-insensitive for HTML elements', function ()
		assert.is_true(rawequal(a.div, a.dIv))
		assert.is_true(rawequal(a.div, a.Div))
	end)

	it('is case-insensitive for foreign elements', function ()
		assert.is_true(rawequal(a.svg, a.sVg))
		assert.is_true(rawequal(a.svg, a.SvG))
		assert.is_true(rawequal(a['font-face'], a['FonT-fACe']))
	end)

	it('is case-insensitive for unknown elements', function ()
		assert.is_true(rawequal(a.abcdefg, a.ABcdeFg))
	end)

	it('refuses invalid tag names', function ()
		assert.has.error(function ()
			local never = a['invalid tag name']
		end)
		assert.has.error(function ()
			local never = a['Custom-Element']
		end)
	end)
end)


describe('Base element', function ()
	it('returns HTML string when `tostring`', function ()
		assert.are.equal(tostring(a.div), '<div></div>')
		assert.are.equal(tostring(a.br), '<br>')
		assert.are.equal(tostring(a['my-element']), '<my-element></my-element>')
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
		assert.are.equal(tostring(div[' \t\rmy-class\n\f']), '<div class="my-class"></div>')

		assert.are.equal(tostring(div['#my-id']), '<div id="my-id"></div>')
		assert.are.equal(tostring(div[' \t\r#my-id\n\f']), '<div id="my-id"></div>')

		assert.is_true(match_html(
			tostring(div['#my-id my-class-1 my-class-2 my-class-3']),
			'<div', {' id="my-id"', ' class="my-class-1 my-class-2 my-class-3"'}, '></div>'
		))
		assert.is_true(match_html(
			tostring(div['my-class-1 #my-id my-class-2 my-class-3']),
			'<div', {' id="my-id"', ' class="my-class-1 my-class-2 my-class-3"'}, '></div>'
		))
		assert.is_true(match_html(
			tostring(div['my-class#my-id']),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
		assert.is_true(match_html(
			tostring(div[' \t\rmy-class\n\f#my-id ']),
			'<div', {' id="my-id"', ' class="my-class"'}, '></div>'
		))
	end)

	it('raises an error when multiple id provided', function ()
		assert.has.error(function ()
			local never = div['##id2']
		end)
		assert.has.error(function ()
			local never = div['#id1#id2']
		end)
		assert.has.error(function ()
			local never = div['class1 #id1 class2 #id2 class3']
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
			local never = elem.tag_name
		end)
		assert.has.error(function ()
			local never = elem.children
		end)
		assert.has.error(function ()
			local never = elem.attributes
		end)
		assert.has.error(function ()
			local never = elem[1]
		end)
		assert.has.error(function ()
			local never = elem.class
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

	it("does not check end tags in raw text elements", function ()
		assert.are.equal(tostring(a.style('</style>')), '<style></style></style>')
		assert.are.equal(tostring(a.script('</script>')), '<script></script></script>')
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
	local function func_returns_string()
		return str
	end
	-- issue: #11
	local table_with_tostring = setmetatable({}, {__tostring = func_returns_string})

	it('replaces `& NBSP " < >` in attribute values with named references', function ()
		local answer = '<div class="'
			..'&amp; &nbsp; &quot; \' &lt; &gt; '
			..'&amp;amp; &amp;nbsp; &amp;quot; &amp;apos; &amp;lt; &amp;gt;'
			..'"></div>'
		assert.are.equal(tostring(a.div[str]), answer)
		assert.are.equal(tostring(a.div[{class = str}]), answer)
		assert.are.equal(tostring(a.div[{class = table_with_tostring}]), answer)
		assert.are.equal(tostring(a.div {class = str}), answer)
		assert.are.equal(tostring(a.div {class = table_with_tostring}), answer)
	end)

	it('replaces `& NBSP < >` in texts other than attribute value with named references', function ()
		local answer = '<div>'
			..'&amp; &nbsp; " \' &lt; &gt; '
			..'&amp;amp; &amp;nbsp; &amp;quot; &amp;apos; &amp;lt; &amp;gt;'
			..'</div>'
		assert.are.equal(tostring(a.div(str)), answer)
		assert.are.equal(tostring(a.div(func_returns_string)), answer)
		assert.are.equal(tostring(a.div(table_with_tostring)), answer)
	end)

	it('does not escape string from acandy nodes', function ()
		local node1 = a.div
		assert.are.equal(tostring(a.div(node1)), '<div>'..tostring(node1)..'</div>')
		local node2 = acandy.Doctype.HTML
		assert.are.equal(
			tostring(Fragment {node2, a.html {a.head, a.body}}),
			tostring(node2)..'<html><head></head><body></body></html>'
		)
		local node3 = acandy.Comment(str)
		assert.are.equal(tostring(a.div(node3)), '<div>'..tostring(node3)..'</div>')
	end)

	it("does not replace characters in an object's properties", function ()
		local elem = a.div[str](str)
		assert.are.equal(elem.class, str)
		assert.are.equal(elem[1], str)
		local _ = tostring(elem)
		assert.are.equal(elem.class, str)
		assert.are.equal(elem[1], str)
	end)

	it("does not encode any character in raw text elements", function ()
		assert.are.equal(tostring(a.style(str)), '<style>'..str..'</style>')
		assert.are.equal(tostring(a.script(str)), '<script>'..str..'</script>')
	end)
end)

describe('`acandy.Comment`', function ()
	-- spec: https://html.spec.whatwg.org/#comments

	local Comment = acandy.Comment
	it('arg is content', function ()
		local comment = Comment('<>&"')
		assert.are.equal(tostring(comment), '<!--<>&"-->')
		assert.are.equal(tostring(a.div(comment)), '<div><!--<>&"--></div>')
	end)

	it('raises an error when content is invalid', function ()
		-- the text must not start with the string ">" or "->",
		-- nor contain the strings "<!--", "-->", or "--!>",
		-- nor end with the string "<!-".
		for _, invalid_content in ipairs {
			'>', '>text', '->', '->text',
			'<!--', 'text<!--', '<!--text', 'text<!--text',
			'-->', 'text-->', '-->text', 'text-->text',
			'--!>', 'text--!>', '--!>text', 'text--!>text',
			'<!-', 'text<!-',
		} do
			assert.has.error(function ()
				local never = Comment(invalid_content)
			end)
		end

		for _, valid_content in ipairs {
			'text>', 'text>text', 'text->', 'text->text',
			'<!-text', 'text<!-text',
			-- the text is allowed to end with the string "<!",
			-- as in <!--My favorite operators are > and <!-->.
			'<!', 'text<!', '<!text', 'text<!text',
		} do
			assert.is.equal(tostring(Comment(valid_content)), '<!--'..valid_content..'-->')
		end
	end)
end)

describe('`acandy.Doctype`', function ()
	-- spec: https://html.spec.whatwg.org/#the-doctype

	local Doctype = acandy.Doctype
	it('has HTML5 doctype', function ()
		assert.are.equal(tostring(Doctype.HTML), '<!DOCTYPE html>')
		assert.are.equal(tostring(Fragment {Doctype.HTML, a.html}), '<!DOCTYPE html><html></html>')
	end)
end)

describe('`acandy.Raw`', function ()
	local str = '& \194\160 " \' < > &amp; &nbsp; &quot; &apos; &lt; &gt;'
	it('is not escaped as a child node', function ()
		local raw = acandy.Raw(str)
		assert.are.equal(tostring(raw), str)
		assert.are.equal(tostring(a.div(raw)), '<div>'..str..'</div>')
		assert.are.equal(tostring(a.div {raw}), '<div>'..str..'</div>')
	end)

	it('can concat with another `Raw`, returns `Raw`', function ()
		local str1, str2 = '1'..str, '2'..str
		local raw1 = acandy.Raw(str1)
		local raw2 = acandy.Raw(str2)
		assert.are.equal(getmetatable(raw1), getmetatable(raw2), getmetatable(raw1..raw2))
		assert.are.equal(tostring(raw1..raw2), str1..str2)
		assert.are.equal(tostring(a.div(raw1..raw2)), '<div>'..str1..str2..'</div>')
		assert.are.equal(tostring(raw1..raw2..raw1), str1..str2..str1)
		assert.are.equal(tostring(a.div(raw1..raw2..raw1)), '<div>'..str1..str2..str1..'</div>')
	end)

	it('cannot concat with a string or number', function ()
		local raw = acandy.Raw(str)
		assert.has.error(function ()
			local never = raw..str
		end)
		assert.has.error(function ()
			local never = str..raw
		end)
		assert.has.error(function ()
			local never = raw..1
		end)
		assert.has.error(function ()
			local never = (1)..raw
		end)
	end)
end)
