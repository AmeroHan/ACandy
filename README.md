# ACandy - A Lua module for building HTML

ACandy takes advantage of Lua’s syntactic sugar and metatable, giving a intuitive way to build complex (maybe) HTML from Lua.

ACandy 利用 Lua 的语法糖和元表，提供了一个易用的方式来从 Lua 构建 HTML。

## Glimpse / 瞄一瞄

Check [example.lua](./example.lua) for more details.

于 [example.lua](./example.lua) 查阅更多。

```lua
local A = require "acandy"

local example1 = (
	A.Fragment {
		A.h2 "Hello!",
		A.div { class = "container", id = "container",
			A.p {
				"There is ", A.strong "an example of strong", ".",
				A.br,
				"This is the second line."
			},
			A.ul {
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
```

Output (formated): / 输出（经过格式化）：

```html
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
```

## Contribution / 贡献

Any form of contribution is welcomed! 

欢迎任何形式的贡献！
