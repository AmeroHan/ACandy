# ACandy: a sugary Lua module for building HTML

<p align="center">
This work uses <a href="https://semver.org/">Semantic Versioning</a> | 本项目使用<a href="https://semver.org/">语义化版本</a>
</p>

ACandy is a Lua module for building HTML, which takes advantage of Lua’s syntactic sugar and metatable, giving an intuitive way to build HTML from Lua. It is, maybe, an internal DSL.  
ACandy 是一个构建 HTML 的 Lua 模块。利用 Lua 的语法糖和元表，ACandy 提供了一个易用的方式来从 Lua 构建 HTML。大概算是一个内部 DSL。

## Take a peek | 瞄一瞄

Check [examples.lua](./examples.lua) for more examples.  
于 [examples.lua](./examples.lua) 查阅更多示例。

```lua
local a = require 'acandy'
local some = a.some

local example = a.Fragment {
   a.h1['#top heading heading-1'] 'Hello!',
   a.div { class="container", style="margin: 0 auto;",
      a.p {
         'My name is ', a.dfn('ACandy'), ', a module for building HTML.',
         a.br,
         'Thank you for your visit.',
      },
      a.p 'visitors:',
      a.ul / some.li('Alice', 'Bob', 'Carol', '...'),
   },
}
print(example)
```

Output (formatted): | 输出（经过格式化）：

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

In this documentation, strings related to attributes are enclosed in double quotation marks while others single. It's just my personal preference and you can decide for yourself.  
这篇文档中，代表元素属性的字符串用双引号，其他字符串用单引号，这仅为我的个人习惯，你可以自行决定。

## Import | 导入

```lua
local a = require('acandy')
```

Using `a` as ACandy’s identifier is suggested, because:   
建议使用 `a` 来命名 ACandy，这是因为：

- `a` is ACandy’s first letter;  
  `a` 是 ACandy 的首字母；
- `a` is short to type;  
  `a` 很短，打起来方便；
- <code>a.*xxx*</code> can be understood as “a *xxx*” in English.  
  <code>a.*xxx*</code> 可以理解为英语的“一个 *xxx*”。

In the following context, `a` refers to this module.  
下文的 `a` 均指代本模块。

## Create elements | 创建元素

```lua
local elem = a.p {
   class="my-paragraph", style="color: #114514;",
   'This sentence is inside a ', a.code('<p>'), ' element.',
}
print(elem)
```

In this code, `a.p` is a function that returns an element. It takes a table as its argument, in which key-value pairs and sequences represent attributes and children of the element respectively, and the same applies to other elements. If there is only one child and no attributes need to be set, the child can be passed directly as the argument of the function, so `a.code('...')` is equivalent to `a.code({ '...' })`.  
在这段代码中，`a.p`是一个返回`<p>`元素的函数，参数为一个表，表的键值对和序列分别表示元素的属性和子结点，其他元素同理。若仅有一个子结点且不需要设置属性，可以直接将该结点作为函数参数，所以 `a.code('...')` 和 `a.code({ '...' })` 是等价的。

The output of this code, formatted (the same below), is as follows.  
该代码的输出，格式化后（下同）如下。

```html
<p class="my-paragraph" style="color: #114514;">
   This sentence is inside a <code>&lt;p&gt;</code> element.
</p>
```

> [!TIP]
> - You don’t need to handle HTML escaping in strings. If you don't want automatic escaping, you can put the content in [`a.Raw`](#acandyraw).  
>   你不需要在字符串中处理 HTML 转义。如果不期望自动的转义，可以将内容放在 [`a.Raw`](#acandyraw) 中。
> - Child nodes do not have to be elements or strings—although only these two types are shown here, any value that can be `tostring` is capable of a child node.
>   子结点并不必须是元素或字符串——虽然这里只展示了这两类，一切能 `tostring` 的值均可作为子结点。

For HTML elements, <code>a.*xxx*</code> is case-**in**sensitive, so `a.div`, `a.Div`, `a.DIV`, etc., are the same value and will all become `<div></div>`. For other elements, <code>a.*xxx*</code> is case-sensitive.  
对于 HTML 元素，<code>a.*xxx*</code> 是不区分大小写的，因此 `a.div`、`a.Div`、`a.DIV`……是同一个值，它们都将变成`<div></div>`。而对于其他元素，<code>a.*xxx*</code> 是大小写敏感的。

### Attributes | 属性

Attributes are provided to elements through key-value pairs in the table. The keys must be [valid XML strings](https://www.w3.org/TR/xml/#NT-Name) (currently the module only supports ASCII characters); the values can be:  
通过表的键值对为元素提供属性。其中，键必须是[合法的 XML 字符串](https://www.w3.org/TR/xml/#NT-Name)（目前模块仅支持 ASCII 字符）；值可以是以下内容：

- `nil` and `false` indicate no such attribute;  
  `nil` 和 `false` 表示没有此属性；
- `true` indicates a boolean attribute, e.g., `a.script { async=true }` means `<script async></script>`;  
  `true` 表示此为布尔值属性，例如，`a.script { async=true }` 表示 `<script async></script>`；
- Other values will be `tostring` and escape `< > & "`.  
  其余值，将会对其进行 `tostring`，并转义其中的 `< > & "`。

### Children | 子结点

Child nodes are provided to elements through the sequence part of the table. Any value other than `nil` can be a child node.  
通过表的序列部分为元素提供子结点。除 `nil` 之外的值均可作为子结点。

#### Elements, strings, numbers, booleans, and other values not mentioned later | 元素、字符串、数字、布尔值等后文没有提到的值

When the element is stringified, these values will be attempted to `tostring` and escape `< > &`. If you don't want automatic escaping, you can put the content in [`a.Raw`](#acandyraw).  
在元素字符串化时，对这些值尝试 `tostring`，并转义其中的 `< > &`。如果不期望自动的转义，可以将内容放在 [`a.Raw`](#acandyraw) 中。

In the following example, we use three elements (`<p>`) as child nodes of `<article>`, and use strings, numbers, and booleans as elements of `<p>`. The result is obvious.  
在下面这个例子中，我们将三个元素（`<p>`）作为 `<article>` 的子结点，并分别将字符串、数字、布尔值作为 `<p>` 的元素。结果显而易见。

```lua
local elem = a.article {
   a.p 'Lorem ipsum...',  -- or `a.p { 'Lorem ipsum...' }`
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

#### Tables | 表

When the element is stringified, tables may be treated as sequences, and ACandy will recursively attempt to stringify the elements in the sequence.  
在元素字符串化时，表可能被当作序列，ACandy 会递归地对序列中的元素尝试字符串化。

The following tables are treated as sequences:  
以下表将被视为序列：
- Tables without metatables, e.g., `{ 1, 2, 3 }`;  
  未设置元表的表，如 `{ 1, 2, 3 }`；
- Tables returned by [`a.Fragment`](#acandyfragment), e.g., `a.Fragment { 1, 2, 3 }`;  
  由 [`a.Fragment`](#acandyfragment) 返回的表，如 `a.Fragment { 1, 2, 3 }`；
- Tables with the `'__acandy_fragment_like'` field in the metatable set to `true`, i.e., you can make <code>*val*</code> be treated as a sequence when stringified by setting <code>getmetatable(*val*).__acandy_fragment_like = true</code>.  
  元表的 `'__acandy_fragment_like'` 字段为 `true` 的表，即，可通过 <code>getmetatable(*val*).__acandy_fragment_like = true</code> 使 <code>*val*</code> 在字符串化时被视作序列。

Other tables (e.g., tables returned by `a.p { 1, 2, 3 }`) will be directly converted to strings by `tostring`, so make sure `__tostring` is defined.  
除此之外的表（如 `a.p { 1, 2, 3 }` 返回的表）会直接通过 `tostring` 转换为字符串，所以需要确保定义了 `__tostring`。

```lua
local sequence1 = { '3', '4' }
local sequence2 = { '2', sequence1 }
local elem = a.div { '1', sequence2 }
print(elem)
```

```html
<p>1234</p>
```

#### Functions | 函数

Functions can be used as child nodes, which is equivalent to calling the function and using the return value as a child node, with the only difference being that the function will be deferred until `tostring` is called.  
可以将函数作为子结点，这相当于调用函数，并将返回值作为子结点，唯一的区别在于函数将被推迟到 `tostring` 时调用。

```lua
local elem = a.ul {
   a.li 'item 1',
   a.li {
      function ()  -- function returning string
         return 'item 2'
      end,
   }
   function ()  -- function returning element
      return a.li 'item 3'
   end,
   function ()  -- function returning sequence
      local list = {}
      for i = 4, 6 do
         list[#list+1] = a.li('item '..i)
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
> Child nodes are processed recursively, so you can return functions within functions.  
> 子结点是递归处理的，所以你可以在函数里返回函数。

### Bracket syntax (setting element attributes) | 方括号语法（设置元素属性）

Placing a string in brackets can quickly set `id` and `class`.  
在方括号内放置字符串可以快速设置 `id` 和 `class`。

```lua
local elem = a.div['#my-id my-class-1 my-class-2'] {
   a.p 'You know what it is.',
}
print(elem)
```

Placing a table in brackets can set element attributes, not limited to `id` and `class`. This makes reusing attributes more convenient.  
在方括号内放置表可以设置元素属性，不局限于 `id` 和 `class`。这让复用属性变得更方便。

```lua
local attr = {
   id="my-id",
   class="my-class-1 my-class-2",
}
local elem = a.div[attr] {
   a.p 'You know what it is.',
}
print(elem)
```

Both of the above code snippets output:  
上面两段代码的输出均为：

```html
<div id="my-id" class="my-class-1 my-class-2">
   <p>You know what it is.</p>
</div>
```

### Slash syntax (breadcrumbs) | 斜杠语法（面包屑）

```lua
local syntax = <elem1> / <elem2> / <elem3>
local example = a.main / a.div / a.p { ... }
```

is equivalent to:  
相当于：

```lua
local syntax = <elem1> { <elem2> { <elem3> } }
local example = (
   a.main {
      a.div {
         a.p { ... }
      }
   }
)
```

The premise is that `elem1`, `elem2` are not [void elements](https://developer.mozilla.org/docs/Glossary/Void_element) (e.g., `<br>`) or [constructed elements](#element-instance-properties--元素实例属性).  
前提是 `<elem1>`、`<elem2>` 不是[空元素](https://developer.mozilla.org/docs/Glossary/Void_element)（如 `<br>`）或[已构建元素](#element-instance-properties--元素实例属性)。

```lua
local li_link = a.li / a.a
local elem = (
   a.header['site-header'] / a.nav / a.ul {
      li_link { href="/home", 'Home' },
      li_link { href="/posts", 'Posts' },
      li_link { href="/about", 'About' },
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
> breadcrumbs can be cached, just like `li_link` in the above example.  
> 元素链可以缓存，就像上面这个例子中的 `li_link`。

### `acandy.Fragment`

Fragment holds multiple elements. The only differences between `a.Fragment` and a regular table are:  
Fragment 承载多个元素。`a.Fragment` 和普通表的仅有的区别就是：

- It has `__tostring` set, so you can get the HTML string;  
  设置了 `__tostring`，可以得到 HTML 字符串；
- It has `__index` set, so you can call all methods in the `table` library which take a table as the first parameter (e.g., `table.insert`, `table.remove`) in an object-oriented manner.  
  设置了 `__index`，可以以类似面向对象的形式调用 `table.insert`、`table.remove` 等 `table` 库中所有以表为第一个参数的方法。

You can create an empty Fragment with `a.Fragment()` or `a.Fragment({})`.  
可以通过 `a.Fragment()` 或 `a.Fragment({})` 创建一个空的 Fragment。

When there is only one element, `a.Fragment(<child>)` is equivalent to `a.Fragment({ <child> })`.  
当仅有一个元素时，`a.Fragment(<child>)` 与 `a.Fragment({ <child> })` 等价。

Example: | 例子：

```lua
local frag = a.Fragment {
   a.p 'First paragraph.',
   a.p 'Second paragraph.',
}
frag:insert(a.p('Third paragraph.'))
print(frag)
```

```html
<p>First paragraph.</p>
<p>Second paragraph.</p>
<p>Third paragraph.</p>
```

### `acandy.Raw`

`a.Raw` prevents strings from being escaped in the final output. It accepts any type of value, calls `tostring`, and stores it internally.  
`a.Raw` 用于使字符串在最终不被转义。它接收任意类型的值，并调用 `tostring`，存储于内部。

- It has `__tostring` set, so you can get the corresponding string with `tostring`;  
  设置了 `__tostring`，可以通过 `tostring` 得到对应字符串；
- It has `__concat` set, so you can concatenate two objects obtained by `a.Raw` with `..`.  
  设置了 `__concat`，可以通过 `..` 连接两个由 `a.Raw` 得到的对象。

Example: | 例子：

```lua
local elem = a.ul {
   a.li 'foo <br> bar',
   a.li(a.Raw 'foo <br> bar'),
   a.li(a.Raw('foo <b')..a.Raw('r> bar')),
   a.li { a.Raw('foo <b'), a.Raw('r> bar') },
}
```

```html
<ul>
   <li>foo &lt;br&gt; bar</li>
   <li>foo <br> bar</li>
   <li>foo <br> bar</li>
   <li>foo <br> bar</li>
</ul>
```

### `acandy.some`

```lua
local frag1 = a.some.<tag>(<arg1>, <arg2>, ...)
local frag2 = a.some.<tag>[<attr>](<arg1>, <arg2>, ...)
```

is equivalent to:  
相当于：

```lua
local frag1 = a.Fragment {
   a.<tag>(<arg1>),
   a.<tag>(<arg2>),
   ...,
}
local frag2 = a.Fragment {
   a.<tag>[<attr>](<arg1>),
   a.<tag>[<attr>](<arg2>),
   ...,
}
```

Example: | 例子：

```lua
local some = a.some
local items = a.ul {
   some.li['my-li']('item 1', 'item 2'),
   some.li('item 3', 'item 4'),
}
print(items)
```

```html
<ul>
   <li class="my-li">item 1</li>
   <li class="my-li">item 2</li>
   <li>item 3</li>
   <li>item 4</li>
</ul>
```

## Element instance properties | 元素实例属性

If an element is obtained by calling functions like `a.div(...)`, `a.div[...](...)`, it is called (tentatively) a "**constructed element**"; when a constructed element is the end of a breadcrumb, the breadcrumb also returns a constructed element; while `a.div`, `a.div[...]` are not constructed elements.  
如果一个元素是 `a.div(...)`、`a.div[...](...)` 这类进行函数调用得出的元素，则称它为“**已构建元素**”（暂定）；已构建元素作为元素链末端的元素时，该元素链同样返回一个已构建元素；而 `a.div`、`a.div[...]` 则不属于已构建元素。

A constructed element `elem` has the following properties:  
对于一个已构建的元素 `elem`，它有如下属性：

- `elem.tag_name`: The tag name of the element, reassignable.  
  `elem.tag_name`：元素的标签名，可以重新赋值。
- `elem.attributes`: A table that stores all the attributes of the element, changes to this table will take effect on the element itself; cannot be reassigned.  
  `elem.attributes`：一个表，存储着元素的所有属性，对此表的更改会生效于元素本身；不可重新赋值。
- `elem.children`: A [Fragment](#acandyfragment) that stores all the child nodes of the element, changes to this table will take effect on the element itself; cannot be reassigned.  
  `elem.children`：一个 [Fragment](#acandyfragment)，存储着元素的所有子结点，对此表的更改会生效于元素本身；不可重新赋值。
- <code>elem.*some_attribute*</code> (<code>*some_attribute*</code> is a string): Equivalent to <code>elem.attributes.*some_attribute*</code>.  
  <code>elem.*some_attribute*</code>（<code>*some_attribute*</code> 为字符串）：相当于 <code>elem.attributes.*some_attribute*</code>。
- <code>elem[*n*]</code> (<code>*n*</code> is an integer): Equivalent to <code>elem.children[*n*]</code>.  
  <code>elem[*n*]</code>（<code>*n*</code> 为整数）：相当于 <code>elem.children[*n*]</code>。

Example: | 例子：

```lua
local elem = a.ol { id="my-id",
   a.li 'item 1',
}

-- get
elem.tag_name  --> 'ol'

elem.children[1]  --> a.li 'item 1'
elem[1] == elem.children[1]  --> true

elem.attributes.id  --> 'my-id'
elem.id == elem.attributes.id  --> true

-- set
elem.tag_name = 'ul'

elem.children:insert(a.li 'item 2')
elem[3] = a.li 'item 3'

elem.attributes.id = 'new-id'
elem.style = 'color: blue;'

print(elem)
```

```html
<ul id="new-id" style="color: blue;">
   <li>item 1</li>
   <li>item 2</li>
   <li>item 3</li>
</ul>
```

## Contribute | 贡献

Contributions of any form are welcomed, including bug reports, feature suggestions, documentation improvement, code optimization and so on!

欢迎任何形式的贡献！包括但不限于汇报缺陷、提出功能建议、完善文档、优化代码。
