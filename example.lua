local A = require "acandy"

-----------------
--  EXAMPLE 1  --
-----------------

local example1 = (
	A.Fragment {
		-- String is accepted as argument.
		A.h2 "Hello!",
		-- Table is accepted as argument.
		-- Map part represents attributes, array part represents children.
		A.div { class = "container", id = "container",
			A.p {
				"There is ", A.strong "an example of strong", ".",
				A.br,  -- Putting a constructer without calling is allowed.
				"This is the second line."
			},
			A.ul {
				-- Function is also allowed, which may return an element,
				-- an array, a string, etc.
				function ()
					local names = {
						"Alice", "Bob", "Charlie"
					}
					local out = {}
					for _, name in ipairs(names) do
						table.insert(out, A.li(name))
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
	return A.div { class = "card",
		A.h2 { param.name },
		A.img { width = 100, src = param.avater },
		A.Fragment(param),
	}
end

local example2 = Card { avater = "https://example.com/", name = "amero",
	A.p "Custom component example.",
	A.p "Use Fragment to receive children from param.",
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

local example3 = A.div()
print(example3)
--> <div></div>

-- Set tagName, attributes and children.
example3.tagName = "ol"
example3.id = "example3"
example3[1] = A.li "Item 1"
example3[2] = A.li "Item 2"
print(example3)
--> <ol id="example3"><li>Item 1</li><li>Item 2</li></ol>

-- When deleting a child, siblings automatically shift.
example3[1] = nil
print(example3)
--> <ol id="example3"><li>Item 2</li></ol>
print(example3[1])
--> <li>Item 2</li>

-- Children will be removed when changed to a void element.
example3.tagName = "br"
print(example3)
--> <br id="example3">
