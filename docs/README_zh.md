
# ACandy：甜的构建 HTML 的 Lua 模块

<p align="center">
本项目使用<a href="https://semver.org/lang/zh-CN/">语义化版本</a>
</p>

<!-- 有意显示 -->
ACandy 是一个构建 HTML 的纯 Lua 模块。利用 Lua 的语法糖和元表，ACandy 提供了一个易用的 DSL 来从 Lua 构建 HTML。

## 瞄一瞄

```lua
local acandy = require 'acandy'
local a, some, Fragment = acandy.a, acandy.some, acandy.Fragment

local example = Fragment {
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

输出（经过格式化）：

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

这篇文档中，代表元素属性的字符串用双引号，其他字符串用单引号，这仅为我的个人习惯，你可以自行决定。

## 导入

```lua
local acandy = require('acandy')
local a = acandy.a
```

`a` 是所有元素的入口，这是因为：

- `a` 是 ACandy 的首字母；
- `a` 很短，打起来方便；
- <code>a.*xxx*</code> 可以理解为英语的“一个 *xxx*”。

## 创建元素

```lua
local elem = a.p {
   class="my-paragraph", style="color: #114514;",
   'This sentence is inside a ', a.code('<p>'), ' element.',
}
print(elem)
```

在这段代码中，`a.p`是一个返回`<p>`元素的函数，参数为一个表，表的键值对和序列分别表示元素的属性和子结点，其他元素同理。若仅有一个子结点且不需要设置属性，可以直接将该结点作为函数参数，所以 `a.code('...')` 和 `a.code({ '...' })` 是等价的。

该代码的输出，格式化后（下同）如下。

```html
<p class="my-paragraph" style="color: #114514;">
   This sentence is inside a <code>&lt;p&gt;</code> element.
</p>
```

> [!TIP]
> - 你不需要在字符串中处理 HTML 转义。如果不期望自动的转义，可以将内容放在 [`acandy.Raw`](#acandyraw) 中。
> - 子结点并不必须是元素或字符串——虽然这里只展示了这两类，一切能 `tostring` 的值均可作为子结点。

对于 HTML 元素，<code>a.*xxx*</code> 是不区分大小写的，因此 `a.div`、`a.Div`、`a.DIV`……是同一个值，它们都将变成`<div></div>`。而对于其他元素，<code>a.*xxx*</code> 是大小写敏感的。

### 属性

通过表的键值对为元素提供属性。其中，键必须是[合法的 XML 字符串](https://www.w3.org/TR/xml/#NT-Name)（目前模块仅支持 ASCII 字符）；值可以是以下内容：

- `nil` 和 `false` 表示没有此属性；
- `true` 表示此为布尔值属性，例如，`a.script { async=true }` 表示 `<script async></script>`；
- 其余值，将会对其进行 `tostring`，并转义其中的 `< > & "`。

### 子结点

通过表的序列部分为元素提供子结点。除 `nil` 之外的值均可作为子结点。

#### 元素、字符串、数字、布尔值等后文没有提到的值

在元素字符串化时，对这些值尝试 `tostring`，并转义其中的 `< > &`。如果不期望自动的转义，可以将内容放在 [`acandy.Raw`](#acandyraw) 中。

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

#### 表

在元素字符串化时，表可能被当作序列，ACandy 会递归地对序列中的元素尝试字符串化。

以下表将被视为序列：

- 未设置元表的表，如 `{ 1, 2, 3 }`；
- 由 [`acandy.Fragment`](#acandyfragment) 返回的表，如 `Fragment { 1, 2, 3 }`；
- 元表的 `'__acandy_fragment_like'` 字段为 `true` 的表，即，可通过 <code>getmetatable(*val*).__acandy_fragment_like = true</code> 使 <code>*val*</code> 在字符串化时被视作序列。

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

#### 函数

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
> 子结点是递归处理的，所以你可以在函数里返回函数。

### 方括号语法（设置元素属性）

在方括号内放置字符串可以快速设置 `id` 和 `class`。

```lua
local elem = a.div['#my-id my-class-1 my-class-2'] {
   a.p 'You know what it is.',
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
   a.p 'You know what it is.',
}
print(elem)
```

上面两段代码的输出均为：

```html
<div id="my-id" class="my-class-1 my-class-2">
   <p>You know what it is.</p>
</div>
```

### 斜杠语法（面包屑）

```lua
local syntax = <elem1> / <elem2> / <elem3>
local example = a.main / a.div / a.p { ... }
```

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

前提是 `<elem1>`、`<elem2>` 不是[空元素](https://developer.mozilla.org/docs/Glossary/Void_element)（如 `<br>`）或[已构建元素](#element-instance-properties--元素实例属性)。

```lua
local link_item = a.li / a.a
local elem = (
   a.header['site-header'] / a.nav / a.ul {
      link_item { href="/home", 'Home' },
      link_item { href="/posts", 'Posts' },
      link_item { href="/about", 'About' },
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
> 面包屑可以缓存，就像上面这个例子中的 `link_item`。

### `acandy.some`

```lua
local frag1 = some.<tag>(<arg1>, <arg2>, ...)
local frag2 = some.<tag>[<attr>](<arg1>, <arg2>, ...)
```

相当于：

```lua
local frag1 = Fragment {
   a.<tag>(<arg1>),
   a.<tag>(<arg2>),
   ...,
}
local frag2 = Fragment {
   a.<tag>[<attr>](<arg1>),
   a.<tag>[<attr>](<arg2>),
   ...,
}
```

例子：

```lua
local some = acandy.some
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

## 元素实例

如果一个元素是 `a.div(...)`、`a.div[...](...)` 这类进行函数调用得出的元素，则称它为“**已构建元素**”（暂定）；已构建元素作为面包屑末端的元素时，该面包屑同样返回一个已构建元素；而 `a.div`、`a.div[...]` 则不属于已构建元素。

对于一个已构建的元素 `elem`，它有如下属性：

- `elem.tag_name`：元素的标签名，可以重新赋值。
- `elem.attributes`：一个表，存储着元素的所有属性，对此表的更改会生效于元素本身；不可重新赋值。
- `elem.children`：一个 [Fragment](#acandyfragment)，存储着元素的所有子结点，对此表的更改会生效于元素本身；不可重新赋值。
- <code>elem.*some_attribute*</code>（<code>*some_attribute*</code> 为字符串）：相当于 <code>elem.attributes.*some_attribute*</code>。
- <code>elem[*n*]</code>（<code>*n*</code> 为整数）：相当于 <code>elem.children[*n*]</code>。

例子：

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

## 结点构造器

### `acandy.Fragment`

`Fragment` 承载多个元素。`Fragment` 和普通表的仅有的区别就是：

- 设置了 `__tostring`，可以得到 HTML 字符串；
- 设置了 `__index`，可以以类似面向对象的形式调用 `table.insert`、`table.remove` 等 `table` 库中所有以表为第一个参数的方法。

可以通过 `Fragment()` 或 `Fragment({})` 创建一个空的 Fragment。

当仅有一个元素时，`Fragment(<child>)` 与 `Fragment({ <child> })` 等价。

例子：

```lua
local Fragment = acandy.Fragment
local frag = Fragment {
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

`Raw` 用于使字符串在最终不被转义。它接收任意类型的值，并调用 `tostring`，存储于内部。

- 设置了 `__tostring`，可以通过 `tostring` 得到对应字符串；
- 设置了 `__concat`，可以通过 `..` 连接两个由 `Raw` 得到的对象。

例子：

```lua
local Raw = acandy.Raw
local elem = a.ul {
   a.li 'foo <br> bar',
   a.li(Raw 'foo <br> bar'),
   a.li(Raw('foo <b')..Raw('r> bar')),
   a.li { Raw('foo <b'), Raw('r> bar') },
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

### `acandy.Comment`

`Comment` 创建一个注释结点。

```lua
local elem = a.p {
   'Hello, ',
   acandy.Comment 'This is a comment.',
   'world!',
   acandy.Comment(),
}
print(elem)
```

```html
<p>Hello, <!--This is a comment.-->world!<!----></p>
```

### `acandy.Doctype`

目前仅支持 HTML5 的 doctype，通过 `Doctype.HTML` 获取。

```lua
tostring(acandy.Doctype.HTML)  --> '<!DOCTYPE html>'
```

## 环境方法

### `acandy.extend_env`

```lua
function acandy.extend_env(env: table) -> nil
```

使用 `acandy.a` 作为 `__index` 来扩展传入的环境，例如 `_ENV`。这使得能够直接使用元素名不需要显式地使用 `a.`，除非与局部变量或全局变量有命名冲突。

> [!WARNING]
> 不建议对全局环境使用此方法，因为可能会造成难以察觉的命名冲突。

```lua
local acandy = require 'acandy'
local a = acandy.a
acandy.extend_env(_ENV)

print(
   -- normally you can access an element without `a.`
   div {
      -- use `a.table` to avoid the naming conflict with Lua's `table` module (a global value)
      a.table {
         tr { td 'foo' },
      },
      -- or use a different case
      TABLE {
         tr { td 'bar' },
      }
      ul {
         -- use `a.a` to avoid the naming conflict with `a` from `acandy` (a local value)
         li / a.a { href="/home", 'Home' },
         -- or use a different case
         li / A { href="/about", 'About' },
      }
   }
)
```

```html
<div>
   <table>
      <tr><td>foo</td></tr>
   </table>
   <table>
      <tr><td>bar</td></tr>
   </table>
   <ul>
      <li><a href="/home">Home</a></li>
      <li><a href="/about">About</a></li>
   </ul>
</div>
```

### `acandy.to_extended_env`

```lua
function acandy.to_extended_env(env: table) -> table
```

类似于 `acandy.extend_env`，但返回一个新表而不是修改原表。

```lua
-- on Lua 5.2+
local function get_article()
   local _ENV = acandy.to_extended_env(_ENV)
   return (
      article {
         header / h2 'Title',
         main {
            p 'Paragraph 1',
            p 'Paragraph 2',
         }
      }
   )
end
-- on Lua 5.1
local get_article = setfenv(function ()
   return (
      article {
         header / h2 'Title',
         main {
            p 'Paragraph 1',
            p 'Paragraph 2',
         }
      }
   )
end, acandy.to_extended_env(_G))

print(get_article())
```

```html
<article>
   <header>
      <h2>Title</h2>
   </header>
   <main>
      <p>Paragraph 1</p>
      <p>Paragraph 2</p>
   </main>
</article>
```

## 贡献

欢迎任何形式的贡献！包括但不限于汇报缺陷、提出功能建议、完善文档、优化代码。
