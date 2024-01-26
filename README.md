# ACandy: a sugary Lua module for building HTML

ACandy is a Lua module for building HTML, which takes advantage of Lua’s syntactic sugar and metatable, giving an intuitive way to build HTML from Lua. It is, maybe, an internal DSL.

ACandy 是一个构建 HTML 的 Lua 模块。利用 Lua 的语法糖和元表，ACandy 提供了一个易用的方式来从 Lua 构建 HTML。大概算是一个内部 DSL。

## Take a peek / 瞄一瞄

Check [examples.lua](./examples.lua) for more details about features, usages, etc.

于 [examples.lua](./examples.lua) 查阅更多特性、用法。

```lua
local a = require "acandy"
local some = a.some

local example = a.Fragment {
   a.h1["#top heading heading-1"] "Hello!",
   a.div { class="container", style="margin: 0 auto;",
      a.p {
         "My name is ",
         a.dfn "ACandy",
         ", a module for building HTML.",
         a.br,
         "Thank you for your visit.",
      },
      a.p "visitors:",
      a.ul / some.li("Alice", "Bob", "Carol", "..."),
   },
}
print(example)
```

Output (formatted): / 输出（经过格式化）：

```html
<h1 id="top" class="heading heading-1">Hello!</h1>
<div style="margin: 0 auto;" class="container">
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
```

## 导入

```lua
local a = require("acandy")
```

建议使用 `a` 来重命名 `acandy`，这是因为：

- `a` 是 ACandy 的首字母；
- `a` 很短，打起来方便；
- <code>a.*xxx*</code> 可以理解为英语的“一个 *xxx*”。

下文的 `a` 均指代本模块。

## Elements / 元素

一个基本的例子如下：

```lua
local elem = a.p {
   class="my-paragraph", style="color: #114514;",
   "This sentence is inside a ", a.code("<p>"), " element.",
}
print(elem)
```

表的键值对和序列分别表示元素的属性和子元素，正如 `a.p` 那样。若仅有一个子元素且不需要设置属性，可以直接将该元素作为函数参数，所以 `a.code("...")` 和 `a.code({ "..." })` 是等价的。

该代码的输出，格式化后（下同）如下。

```html
<p class="my-paragraph" style="color: #114514;">
   This sentence is inside a <code>&lt;p&gt;</code> element.
</p>
```

> [!TIP]
> - 你不需要在字符串中处理 HTML 转义。如果不期望自动的转义，可以将内容放在 [`a.Raw`](#acandyraw) 中。
> - 子元素并不必须是元素或字符串——虽然这里只展示了这两类，一切能 `tostring` 的值均可作为子元素。

### 属性

通过表的键值对为元素提供属性。其中，键必须是[合法的 XML 字符串](https://www.w3.org/TR/xml/#NT-Name)（目前模块仅支持 ASCII 字符）；值可以是以下内容：

- `nil` 和 `false` 表示没有此属性；
- `true` 表示此为布尔值属性，例如，`a.script { async=true }` 表示 `<script async></script>`；
- 其余值，将会对其进行 `tostring`，并转义其中的 `< > & "`。

### 子元素

通过表的序列部分为元素提供子元素。除 `nil` 之外的值均可作为子元素。

#### 元素、字符串、数字、布尔值等后文没有提到的值

在元素字符串化时，对这些值尝试 `tostring`，并转义其中的 `< > &`。如果不期望自动的转义，可以将内容放在 [`a.Raw`](#acandyraw) 中。

在下面这个例子中，我们将三个元素（`<p>`）作为 `<article>` 的子元素，并分别将字符串、数字、布尔值作为 `<p>` 的元素。结果显而易见。

```lua
local elem = a.article {
   a.p "Lorem ipsum...",  -- or `a.p { "Lorem ipsum..." }`
   a.p(2),  -- or `a.p { 2 }`
   a.p(true),  -- or `a.p { true }`
}
print(elem)
```

```html
<article>
   <p>Lorem ipsum...</p>
   <p>2</p>
   <p>true</p>
</article>
```

#### 表

在元素字符串化时，ACandy 将表视作序列，并递归地对表中的元素尝试字符串化。

```lua
local parts = {
   "consectetur adipiscing elit, ",
   "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
}
local elem = a.div {
   "Lorem ipsum dolor sit amet, ",
   parts,
}
```

```html
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
```

#### 函数

可以将函数作为子元素，这相当于调用函数，并将返回值作为子元素，唯一的区别在于函数将被推迟到 `tostring` 时调用。

```lua
local elem = a.ul {
   a.li "item 1",
   a.li {
      function()  -- function returning string
         return "item 2"
      end,
   }
   function()  -- function returning element
      return a.li "item 3"
   end,
   function()  -- function returning sequence
      local list = {}
      for i = 4, 6 do
         list[#list+1] = a.li("item "..i)
      end
      return list
   end,
}
print(elem)
```

```html
<ul>
   <li>item 1</li>
   <li>item 2</li>
   <li>item 3</li>
   <li>item 4</li>
   <li>item 5</li>
   <li>item 6</li>
</ul>
```

> [!TIP]
> 子元素是递归处理的，所以你可以在函数里返回函数。

### 方括号语法（设置元素属性）

在方括号内放置字符串可以快速设置 `id` 和 `class`。

```lua
local elem = a.div["#my-id my-class-1 my-class-2"] {
   a.p "You know what it is.",
}
print(elem)
```

在方括号内放置表可以设置元素属性，不局限于 `id` 和 `class`。这让复用属性变得更方便。

```lua
local attr = {
   id="my-id",
   class="my-class-1 my-class-2",
}
local elem = a.div[attr] {
   a.p "You know what it is.",
}
print(elem)
```

上面两段代码的输出均为：

```html
<div id="my-id" class="my-class-1 my-class-2">
   <p>You know what it is.</p>
</div>
```

### 斜杠语法（元素链）

```lua
local syntax = <elem1> / <elem2> / <elem3>
local example = a.main / a.div / a.p { ... }
```

相当于

```lua
local syntax = <elem1>(<elem2>(<elem3>))
local example = a.main {
   a.div {
      a.p { ... }
   }
}
```

前提是 `<elem1>`、`<elem2>` 不是[空元素](https://developer.mozilla.org/docs/Glossary/Void_element)（如 `<br>`）或构建好的元素。“构建好的元素”指 `a.div(...)`、`a.div[...](...)` 这类进行函数调用得出的元素，而 `a.div`、`a.div[...]` 则不是“构建好的元素”。

```lua
local li_link = a.li / a.a
local elem = (
   a.header["site-header"] / a.nav / a.ul {
      li_link { href="/home", "Home" },
      li_link { href="/posts", "Posts" },
      li_link { href="/about", "About" },
   }
)
print(elem)
```

```html
<header class="site-header">
   <nav>
      <ul>
         <li>
            <a href="/home">Home</a>
         </li>
         <li>
            <a href="/posts">Posts</a>
         </li>
         <li>
            <a href="/about">About</a>
         </li>
      </ul>
   </nav>
</header>
```

> [!TIP]
> 元素链可以缓存，就像上面这个例子中的 `li_link`。

### `acandy.Fragment`

Fragment 承载多个元素。`a.Fragment` 和普通表的仅有的区别就是：

- 设置了 `__tostring`，可以得到 HTML 字符串；
- 设置了 `__index`，可以以类似面向对象的形式调用 `table.insert`、`table.remove` 等 `table` 库中所有以表为第一个参数的方法。

可以通过 `a.Fragment()` 或 `a.Fragment({})` 创建一个空的 Fragment。

当仅有一个元素时，`a.Fragment(<stuff>)` 与 `a.Fragment({ <stuff> })` 等价。

例子：

```lua
local frag = a.Fragment {
   a.p "First paragraph.",
   a.p "Second paragraph.",
}
frag:insert(a.p("Third paragraph."))
print(frag)
```

```html
<p>First paragraph.</p>
<p>Second paragraph.</p>
<p>Third paragraph.</p>
```

### `acandy.Raw`

`a.Raw` 用于使字符串在最终不被转义。它接收任意类型的值，并调用 `tostring`，存储于内部。

- 设置了 `__tostring`，可以得到对应字符串；
- 设置了 `__concat`，可以连接两个由 `a.Raw` 得到的对象。

例子：

```lua
local elem = a.ul {
   a.li "foo <br> bar",
   a.li(a.Raw "foo <br> bar"),
   a.li(a.Raw("<span>foo")..a.Raw("bar</span>")),
}
```

```html
<ul>
   <li>foo &lt;br&gt; bar</li>
   <li>foo <br> bar</li>
   <li><span>foobar</span></li>
</ul>
```

### `acandy.from_yields`

`a.from_yields` 接收一个生产者函数作为参数，返回 `a.Fragment`。该生产者函数接收 `yield` 作为参数。在生产者函数中每次调用 `yield` 将为 `a.Fragment` 增添一个后代。

`a.from_yields(<func>)` 与 `a.from_yields ^ <func>` 是等价的，后者可以省一对括号，这在某些代码风格中能够减少缩进层级。

```lua
local frag = a.from_yields(function(yield)
   -- your code here, maybe there is a loop
   -- you can yield multiple times
   yield(<stuff>)
end)
```

相当于

```lua
local frag = a.Fragment()
do
   -- your code here, maybe there is a loop
   -- you can insert multiple times
   frag:insert(<stuff>)
end
```

例子：

```lua
local height_weights = {
   { name = "Alice", height = 160, weight = 50 },
   { name = "Bob"  , height = 180, weight = 70 },
   { name = "Carol", height = 170, weight = 60 },
}
local elem = a.table {
   a.tr {
      a.th "Name", a.th "Height", a.th "Weight",
   },
   a.from_yields ^ function(yield)
      for _, item in ipairs(height_weights) do
         yield(a.tr {
            a.td(item.name),
            a.td(item.height..' cm'),
            a.td(item.weight..' kg'),
         })
      end
   end,  -- or `a.from_yields(function(yield) ... end)`
}
print(elem)
```

```html
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
      <td>Carol</td>
      <td>170 cm</td>
      <td>60 kg</td>
   </tr>
</table>
```

### `acandy.some`

```lua
local frag1 = a.some.<tag>(<arg1>, <arg2>, ..., <argN>)
local frag2 = a.some.<tag>[<attr>](<arg1>, <arg2>, ..., <argN>)
```

相当于

```lua
local frag1 = a.Fragment {
   a.<tag>(<arg1>),
   a.<tag>(<arg2>),
   ...,
   a.<tag>(<argN>),
}
local frag2 = a.Fragment {
   a.<tag>[<attr>](<arg1>),
   a.<tag>[<attr>](<arg2>),
   ...,
   a.<tag>[<attr>](<argN>),
}
```

例子：

```lua
local some = a.some
local items = a.ul(some.li['my-li']("item 1", "item 2"))
print(items)
```

```html
<ul>
   <li class="my-li">item 1</li>
   <li class="my-li">item 2</li>
</ul>
```

## Contribution / 贡献

Contributions of any form are welcomed, including bug reports, feature suggestions, documentation improvement, code optimization and so on!

欢迎任何形式的贡献！包括但不限于汇报缺陷、提出功能建议、完善文档、优化代码。
