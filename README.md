# ACandy - A sugary Lua module for building HTML

ACandy takes advantage of Lua’s syntactic sugar and metatable, giving an intuitive way to build complex HTML from Lua.

ACandy 利用 Lua 的语法糖和元表，提供了一个易用的方式来从 Lua 构建 HTML。

## Take a peek / 瞄一瞄

Check [examples.lua](./examples.lua) for more details about features, usages, etc.

于 [examples.lua](./examples.lua) 查阅更多特性、用法。

```lua
local a = require "acandy"

local example1 = a.Fragment {
   a.h2 "Hello!",
   a.div { class="container", id="container",
      a.p {
         "There is ", a.strong("an example of strong"), ".",
         a.br,
         "This is the second line.",
      },
      a.ul {
         function ()
            local names = { "Alice", "Bob", "Charlie" }
            local out = {}
            for _, name in ipairs(names) do
               table.insert(out, a.li(name))
            end
            return out
         end,
      },
   },
}

print(example1)
```

Output (formatted): / 输出（经过格式化）：

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

Contributions of any form are welcomed! 

欢迎任何形式的贡献！
