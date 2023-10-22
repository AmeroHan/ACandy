local a = require("acandy")

-- print(a.div{class="container", id="container", a.p{"Hello, world!"}})
-- print(a.div())

-----------------
--  EXAMPLE 1  --
-----------------

local example1 = (
	a.Fragment {
		-- String is accepted as argument.
		a.h2 "Hello!",
		-- Table is accepted as argument.
		-- Map part represents attributes, array part represents children.
		a.div { class = "container", id = "container",
			a.p {
				"There is ", a.strong "an example of strong", ".",
				a.br,  -- Putting a constructer without calling is allowed.
				"This is the second line."
			},
			a.ul {
				-- Function is also allowed, which may return an element,
				-- an array, a string, etc.
				function ()
					local names = {
						"Alice", "Bob", "Charlie"
					}
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
		<li>Charlie</li>
	</ul>
</div>
]]


-----------------
--  EXAMPLE 2  --
-----------------

local Card = function(param)
	return a.div { class = "card",
		a.h2 { param.name },
		a.img { width = 100, src = param.avater },
		a.Fragment(param),
	}
end

local example2 = Card { avater = "https://example.com/", name = "amero",
	a.p "Custom component example.",
	a.p "Use Fragment to receive children from param.",
}

print(example2)
--[[ Output (formated):
<div class="card">
	<h2>amero</h2>
	<img width="100" src="https://example.com/">
	<p>Custom component example.</p>
	<p>Use Fragment to receive children from param.</p>
</div>
]]


-----------------
--  EXAMPLE 3  --
-----------------

local example3 = a.div()
print(example3)
--> <div></div>

-- Set tag_name, attributes and children.
example3.tag_name = "ol"
example3.id = "example3"
example3[1] = a.li "Item 1"
example3[2] = a.li "Item 2"
print(example3)
--> <ol id="example3"><li>Item 1</li><li>Item 2</li></ol>

-- When deleting a child, siblings automatically shift.
example3[1] = nil
print(example3)
--> <ol id="example3"><li>Item 2</li></ol>
print(example3[1])
--> <li>Item 2</li>

-- Children will be removed when changed to a void element.
example3.tag_name = "br"
print(example3)
--> <br id="example3">


-----------------
--  EXAMPLE 4  --
-----------------

local height_weights = {
	{ name = 'Alice'  , height = 160, weight = 50 },
	{ name = 'Bob'    , height = 180, weight = 70 },
	{ name = 'Charlie', height = 170, weight = 60 },
}

local example4 = a.table {
	a.tr {
		a.th "Name", a.th "Height", a.th "Weight",
	},
	a.iter(
		function(_, item)
			return a.tr {
				a.td(item.name),
				a.td(item.height..' cm'),
				a.td(item.weight..' kg'),
			}
		end,
		ipairs(height_weights)
	)
}
print(example4)
--[[ Output (formated):
<table>
	<tr>
		<th>Name</th>
		<th>Height</th>
		<th>Weight</th>
	</tr>
	<tr>
		<td>Alice</td>
		<td>160 cm</td>
		<td>50 kg</td>
	</tr>
	<tr>
		<td>Bob</td>
		<td>180 cm</td>
		<td>70 kg</td>
	</tr>
	<tr>
		<td>Charlie</td>
		<td>170 cm</td>
		<td>60 kg</td>
	</tr>
</table>
]]


-----------------
--  EXAMPLE 5  --
-----------------

local example5 = a.div['#my-div cls1 cls2'] {
	a.p "You know what it is.",
}
print(example5)
--> <div id="my-div" class="cls1 cls2"><p>You know what it is.</p></div>
