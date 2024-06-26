local a = require('acandy')


-- TODO: test cases


-- 1. Basic usage
-----------------

local example1 = (
	a.Fragment {
		-- String is accepted as argument.
		a.h2 'Hello!',
		-- Table is accepted as argument.
		-- Map part represents attributes, array part represents children.
		a.div { id="container", class="container",
			a.p {
				'There is ', a.strong 'an example of strong', '.',
				a.br,  -- Putting a constructer without calling is allowed.
				'This is the second line.',
			},
			a.ul {
				-- Function is also allowed, which may return an element,
				-- an array, a string, etc.
				function ()
					local names = { 'Alice', 'Bob', 'Carol' }
					local out = {}
					for _, name in ipairs(names) do
						table.insert(out, a.li(name))
					end
					return out
				end,
			},
		},
	}
)

print(example1)
--[[ Output (formated):
<h2>Hello!</h2>
<div id="container" class="container">
	<p>
		There is <strong>an example of strong</strong>.
		<br>
		This is the second line.
	</p>
	<ul>
		<li>Alice</li>
		<li>Bob</li>
		<li>Carol</li>
	</ul>
</div>
]]


-- 2. Custom component
----------------------

local Card = function(props)
	return a.div { class="card",
		a.h2 { props.name },
		a.img { width=100, src=props.avater },
		a.Fragment(props),
	}
end

local example2 = Card { avater="https://example.com/", name="amero",
	a.p 'Custom component example.',
	a.p 'Use Fragment to receive children from props.',
}

print(example2)
--[[ Output (formated):
<div class="card">
	<h2>amero</h2>
	<img width="100" src="https://example.com/">
	<p>Custom component example.</p>
	<p>Use Fragment to receive children from props.</p>
</div>
]]


-- 3. Element manipulation
--------------------------

local example3 = a.div()
print(example3)
--> <div></div>

-- Set tag_name, attributes and children.
example3.tag_name = 'ol'
example3.id = 'example3'
example3[1] = a.li 'Item 1'
example3[2] = a.li 'Item 2'
print(example3)
--> <ol id="example3"><li>Item 1</li><li>Item 2</li></ol>

-- Children will be removed when changed to a void element.
example3.tag_name = 'br'
print(example3)
--> <br id="example3">


-- 4. Shorthand attributes
--------------------------

local example5 = a.div['#my-div cls1 cls2'] {
	a.p 'You know what it is.',
}
print(example5)
--> <div id="my-div" class="cls1 cls2"><p>You know what it is.</p></div>


-- 5. Element chains
--------------------

local template_attrs = { class="foo", style="color: green;" }
local example6 = a.header['site-header'] / a.nav / a.ul {
	a.li['foo'] / a.a { href="/home", 'Home' },
	a.li[template_attrs] / a.a { href="/posts", 'Posts' },
	a.li / a.a { href="/about", 'About' },
}
print(example6)
--[[ Output (formated):
<header class="site-header">
	<nav>
		<ul>
			<li class="foo"><a href="/home">Home</a></li>
			<li class="foo" style="color: green;"><a href="/posts">Posts</a></li>
			<li><a href="/about">About</a></li>
		</ul>
	</nav>
</header>
]]



-- 6. acandy.some - Construct multiple elements
-----------------------------------------------

--[[
```
some.th[<index>](<arg1>, <arg2>, ...)
```
is equivalent to
```
a.Fragment {
	a.th[<index>](<arg1>),
	a.th[<index>](<arg2>),
	...
}
```
]]
local some = a.some
local example7 = a.table {
	a.tr / some.th['foo']('One', 'Two', 'Three'),
	a.tr / some.td('A', 'B', 'C'),
}
print(example7)
--[[ Output (formated):
<table>
	<tr>
		<th class="foo">One</th>
		<th class="foo">Two</th>
		<th class="foo">Three</th>
	</tr>
	<tr>
		<td>A</td>
		<td>B</td>
		<td>C</td>
	</tr>
</table>
]]


-- 7. Raw strings
-----------------

local example8_a = a.ul {
	a.li 'Encoded: <br>',
	a.li / a.Raw('Remain: <br>'),
}
print(example8_a)
--[[ Output (formated):
<ul>
	<li>Encoded: &lt;br&gt;</li>
	<li>Remain: <br></li>
</ul>
]]

local example8_b = a.div(a.Raw('<span>')..a.Raw('</span>'))
print(example8_b)  --> <div><span></span></div>
