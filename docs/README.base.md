# ACandy: a sugary Lua module for building HTML | ACandy：一个甜的构建 HTML 的 Lua 模块

<div align="center">
<!--@LanguageLinks;-->

<p>
This work uses <a href="https://semver.org/">Semantic Versioning</a> | 本项目使用<a href="https://semver.org/lang/zh-CN/">语义化版本</a>
</p>
</div>

<!--@en-->
ACandy is a pure Lua module for building HTML. Taking advantage of Lua’s syntactic sugar and metatable, it provides an intuitive DSL to build HTML from Lua.

ACandy 是一个构建 HTML 的纯 Lua 模块。利用 Lua 的语法糖和元表，ACandy 提供了一个易用的 DSL 来从 Lua 构建 HTML。

## Quick look | 瞄一瞄

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
local acandy = require('acandy')
local a = acandy.a
```

`a` is the entry point for all elements, because:  
`a` 是所有元素的入口，这是因为：

<!--@en-->
- `a` is ACandy’s first letter;
- `a` is short to type;
- <code>a.*xxx*</code> can be understood as “a *xxx*” in English.

<!--@zh-->
- `a` 是 ACandy 的首字母；
- `a` 很短，打起来方便；
- <code>a.*xxx*</code> 可以理解为英语的“一个 *xxx*”。

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

<!--@en-->
> [!TIP]
>
> - You don’t need to handle HTML escaping in strings. If you don't want automatic escaping, you can put the content in [`acandy.Raw`](#acandyraw).
> - Child nodes do not have to be elements or strings—although only these two types are shown here, any value that can be `tostring` is capable of a child node.

<!--@zh-->
> [!TIP]
>
> - 你不需要在字符串中处理 HTML 转义。如果不期望自动的转义，可以将内容放在 [`acandy.Raw`](#acandyraw) 中。
> - 子结点并不必须是元素或字符串——虽然这里只展示了这两类，一切能 `tostring` 的值均可作为子结点。

<code>a.*xxx*</code> is [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive), thus `a.div`, `a.Div`, `a.DIV`, etc., are the same value (i.e., `rawequal(a.div, a.Div) == true` and `rawequal(a.div, a.DIV) == true`) and will all become `<div></div>`.  
<code>a.*xxx*</code> 是 [ASCII 大小写不敏感](https://infra.spec.whatwg.org/#ascii-case-insensitive)的，因此 `a.div`、`a.Div`、`a.DIV`……是同一个值（即 `rawequal(a.div, a.Div) == true`、`rawequal(a.div, a.DIV) == true`），它们都将变成`<div></div>`。

### Attributes | 属性

Attributes are provided to elements through key-value pairs in the table. The attribute values can be:  
通过表的键值对为元素提供属性。值可以是以下内容：

<!--@en-->
- `nil` and `false` indicate no such attribute;
- `true` indicates a boolean attribute, e.g., `a.script { async=true }` means `<script async></script>`;
- for any other value, try `tostring` on it, then escape `&`, `<`, `>` and NBSP.

<!--@zh-->
- `nil` 和 `false` 表示没有此属性；
- `true` 表示此为布尔值属性，例如，`a.script { async=true }` 表示 `<script async></script>`；
- 其余值，将会对其 `tostring`，并转义其中的 `&`、`<`、`>` 和 NBSP。

### Children | 子结点

Child nodes are provided to elements through the sequence part of the table. Any value other than `nil` can be a child node. When serializing, they follow the following rules.  
通过表的序列部分为元素提供子结点。除 `nil` 之外的值均可作为子结点。当序列化时，它们遵循以下规则。

#### Default case | 默认情形

Elements, strings, numbers, booleans, and all other values not mentioned later are applicable to the following rules.  
元素、字符串、数字、布尔值等后文没有提到的值均适用于以下规则。

When serializing, `tostring` will be tried on these values and then escape `&`, `<`, `>` and NBSP. If you don't want automatic escaping, you can put the content in [`acandy.Raw`](#acandyraw).  
在元素字符串化时，对这些值尝试 `tostring`，并转义 `&`、`<`、`>` 和 NBSP。如果不期望自动的转义，可以将内容放在 [`acandy.Raw`](#acandyraw) 中。

In the following example, we use three elements (`<p>`) as child nodes of `<article>`, and use strings, numbers, and booleans as elements of `<p>`. It is trivial to guess the result.  
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

#### Lists | 列表

When serializing, if a node is [list-like](#list-like-values), ACandy will recursively serialize the child nodes inside it.  
在序列化时，如果一个结点是[类列表的](#类列表值)，ACandy 将递归序列化列表中的子结点。

By the way, tables returned by [`acandy.Fragment`](#acandyfragment) (e.g., `Fragment { 1, 2, 3 }`) are list-like, as their metatable has the `'__acandy_list_like'` field set to `true`.  
顺便一提，由 [`acandy.Fragment`](#acandyfragment) 返回的表（如 `Fragment { 1, 2, 3 }`）是类列表的，因为它们的元表的 `'__acandy_list_like'` 字段被设置为 `true`。

Particularly, if a node has a table type but not considered list-like (e.g., table returned by `a.p { 1, 2, 3 }`), it will be directly converted to string according to the [default rule](#default-case), so make sure `__tostring` metamethod is implemented.  
特别地，如果一个表不被认为是类列表的，如 `a.p { 1, 2, 3 }` 返回的表，根据[默认规则](#默认情形)，它将直接通过 `tostring` 转换为字符串，所以确保它实现了 `__tostring` 元方法。

```lua
local list1 = { '3', '4' }
local list2 = { '2', list1 }
local elem = a.div { '1', list2 }
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
      function ()  -- returns string
         return 'item 2'
      end,
   },
   function ()  -- returns element
      return a.li 'item 3'
   end,
   function ()  -- returns list
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
>
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

Placing a [table-like value](#table-like-values) in brackets can set element attributes, not limited to `id` and `class`. This makes reusing attributes more convenient.  
在方括号内放置[类表值](#类表值)可以设置元素属性，属性不局限于 `id` 和 `class`。这让复用属性变得更方便。

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
elem1 / elem2 / ... / elemN / tail_value
```

is equivalent to:  
相当于：

```lua
elem1(
   elem2(
      ...(
         elemN(tail_value)
      )
   )
)
```

Kind of like CSS’s [child combinator](https://developer.mozilla.org/docs/Web/CSS/Child_combinator) `>`, except that it is used to compose elements rather than select elements.  
有点像 CSS 的[子组合器](https://developer.mozilla.org/docs/Web/CSS/Child_combinator) `>`，只不过它用于创建元素而不是选择元素。

The premise is that `elem1`..`elemN` are not [void elements](https://developer.mozilla.org/docs/Glossary/Void_element) or [constructed elements](#element-instance-properties).  
前提是 `elem1`—`elemN` 不是[空元素](https://developer.mozilla.org/docs/Glossary/Void_element)或[已构建元素](#元素实例属性)。

Example: | 例子：

```lua
local link_item = a.li / a.a
local text = 'More coming soon...'
local elem = (
   a.header['site-header'] / a.nav / a.ul {
      link_item { href="/home", 'Home' },
      link_item { href="/posts", 'Posts' },
      link_item { href="/about", 'About' },
      a.li / text,
   }
)
print(elem)
```

```html
<header class="site-header">
   <nav>
      <ul>
         <li><a href="/home">Home</a></li>
         <li><a href="/posts">Posts</a></li>
         <li><a href="/about">About</a></li>
         <li>More coming soon...</li>
      </ul>
   </nav>
</header>
```

> [!TIP]
>
> breadcrumbs can be cached, just like `link_item` in the above example.  
> 面包屑可以缓存，就像上面这个例子中的 `link_item`。

### `acandy.some`

```lua
local frag1 = some.xxx(arg1, arg2, ...)
local frag2 = some.xxx[attr](arg1, arg2, ...)
```

is equivalent to:  
相当于：

```lua
local frag1 = Fragment {
   a.xxx(arg1),
   a.xxx(arg2),
   ...,
}
local frag2 = Fragment {
   a.xxx[attr](arg1),
   a.xxx[attr](arg2),
   ...,
}
```

Example: | 例子：

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

## Element instance | 元素实例

If an element is obtained by calling functions like `a.div(...)`, `a.div[...](...)`, it is called (tentatively) a "**constructed element**"; when a constructed element is the end of a breadcrumb, the breadcrumb also returns a constructed element; while `a.div`, `a.div[...]` are not constructed elements.  
如果一个元素是 `a.div(...)`、`a.div[...](...)` 这类进行函数调用得出的元素，则称它为“**已构建元素**”（暂定）；已构建元素作为面包屑末端的元素时，该面包屑同样返回一个已构建元素；而 `a.div`、`a.div[...]` 则不属于已构建元素。

A constructed element `elem` has the following properties:  
对于一个已构建的元素 `elem`，它有如下属性：

<!--@en-->
- `elem.tag_name`: the tag name of the element, reassignable.
- `elem.attributes`: a table that stores all the attributes of the element, changes to this table will take effect on the element itself; cannot be reassigned.
- `elem.children`: a [`Fragment`](#acandyfragment) that stores all the child nodes of the element, changes to this table will take effect on the element itself; cannot be reassigned.
- <code>elem.*some_attribute*</code> (<code>*some_attribute*</code> is a string): equivalent to <code>elem.attributes.*some_attribute*</code>.
- <code>elem[*n*]</code> (<code>*n*</code> is an integer): equivalent to <code>elem.children[*n*]</code>.

<!--@zh-->
- `elem.tag_name`：元素的标签名，可以重新赋值。
- `elem.attributes`：一个表，存储着元素的所有属性，对此表的更改会生效于元素本身；不可重新赋值。
- `elem.children`：一个 [`Fragment`](#acandyfragment)，存储着元素的所有子结点，对此表的更改会生效于元素本身；不可重新赋值。
- <code>elem.*some_attribute*</code>（<code>*some_attribute*</code> 为字符串）：相当于 <code>elem.attributes.*some_attribute*</code>。
- <code>elem[*n*]</code>（<code>*n*</code> 为整数）：相当于 <code>elem.children[*n*]</code>。

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

## Node constructors | 结点构造器

### `acandy.Fragment`

`Fragment` holds multiple elements. The only differences between `Fragment` and a regular table are:  
`Fragment` 承载多个元素。`Fragment` 和普通表的仅有的区别就是：

<!--@en-->
- It has `__tostring` set, so you can get the HTML string;
- It has `__index` set, so you can call all methods in the `table` library which take a table as the first parameter (e.g., `table.insert`, `table.remove`) in an object-oriented manner.

<!--@zh-->
- 设置了 `__tostring`，可以得到 HTML 字符串；
- 设置了 `__index`，可以以类似面向对象的形式调用 `table.insert`、`table.remove` 等 `table` 库中所有以表为第一个参数的方法。

You can create an empty Fragment with `Fragment()` or `Fragment({})`.  
可以通过 `Fragment()` 或 `Fragment({})` 创建一个空的 Fragment。

When there is only one element, `Fragment(<child>)` is equivalent to `Fragment({ <child> })`.  
当仅有一个元素时，`Fragment(<child>)` 与 `Fragment({ <child> })` 等价。

Example: | 例子：

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

`Raw` prevents strings from being escaped in the final output. It accepts any type of value, calls `tostring`, and stores it internally.  
`Raw` 用于使字符串在最终不被转义。它接收任意类型的值，并调用 `tostring`，存储于内部。

<!--@en-->
- It has `__tostring` set, so you can get the corresponding string with `tostring`;
- It has `__concat` set, so you can concatenate two objects obtained by `Raw` with `..`.

<!--@zh-->
- 设置了 `__tostring`，可以通过 `tostring` 得到对应字符串；
- 设置了 `__concat`，可以通过 `..` 连接两个由 `Raw` 得到的对象。

Example: | 例子：

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

`Comment` creates a comment node.  
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

Currently only the HTML5 doctype is supported. It is accessed by `Doctype.HTML`.  
目前仅支持 HTML5 的 doctype，通过 `Doctype.HTML` 获取。

```lua
tostring(acandy.Doctype.HTML)  --> '<!DOCTYPE html>'
```

## Environmental methods | 环境方法

### `acandy.extend_env`

```lua
function acandy.extend_env(env: table): ()
```

Extend the environment in place with `acandy.a` as `__index`, e.g., `_ENV`. This makes it possible to directly use the tag name rather than tediously type `a.`, unless there is a naming conflict with local variables or global variables.  
使用 `acandy.a` 作为 `__index` 来扩展传入的环境，例如 `_ENV`。这使得能够直接使用元素名不需要显式地使用 `a.`，除非与局部变量或全局变量有命名冲突。

> [!WARNING]
>
> It is not recommended to use this method on the global environment, as it may cause hard-to-detect naming conflicts.  
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
function acandy.to_extended_env(env: table): table
```

Similar to `acandy.extend_env`, but returns a new table instead of modifying the original table.  
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

## Configuration | 配置

ACandy defaults to HTML mode (currently only HTML mode, XML will be supported in the future), and has predefined some HTML void elements and raw text elements (see [config.lua](/config.lua)).  
ACandy 默认为 HTML 模式（目前只有 HTML 模式，以后将会支持 XML），并预定义了一些 HTML 空元素和原始文本元素（见 [config.lua](/config.lua)）。

ACandy does not support modifying global configuration. To modify the configuration, create a new configured `ACandy` instance. The function signature is as follows.  
ACandy 不支持修改全局配置，要修改配置，请创建一个配置后的 `ACandy` 实例，其函数签名如下。

```lua
type Config = {
   void_elements: { [string]: true },
   raw_text_elements: { [string]: true },
}
function acandy.ACandy(output_type: 'html', modify_config?: (config: Config) -> ()): table
```

The `output_type` parameter currently only accepts `'html'`. The `modify_config` parameter (optional) is a function that takes a table as a parameter and has no return value. The table passed to this function is the basis of the new configuration, and you can modify this value in the function, for example:  
其中，`output_type` 参数目前只能传入 `'html'`。`modify_config` 参数（可选）是一个函数，接收一个表作为参数，无返回值。传入该函数的表是新配置的基础，你可以在函数中修改这个值，例如：

```lua
local acandy = require('acandy').ACandy('html', function (config)
   -- add a void element
   config.void_elements['my-void-element'] = true
   -- remove `br` from void elements
   config.void_elements.br = nil
   -- add a raw text element
   config.raw_text_elements['my-raw-text-element'] = true
   -- remove `script` from raw text elements
   config.raw_text_elements.script = nil
end)
local a = acandy.a
print(
   acandy.Fragment {
      a['my-void-element'],
      a.br,
      a['my-raw-text-element'] '< > &',
      a.script 'let val = 2 > 1',
   }
)
```

```html
<my-void-element>
<br></br>
<my-raw-text-element>< > &</my-raw-text-element>
<script>let val = 2 &gt; 1</script>
```

To use this configuration throughout the project, you can export the configured `ACandy` instance and import it in other files.  
要想在整个项目使用这个配置，可以导出配置后的 `ACandy` 实例，然后在其他文件中导入这个实例。

```lua
-- my_acandy.lua
return require('acandy').ACandy('html', function (config)
   -- ...
end)

-- other files
local acandy = require('my_acandy')
```

## Concepts | 概念

### Table-like values | 类表值

Table-like values are values that can be read as tables. A value `t` is considered a table-like value if and only if it satisfies the following conditions:  
类表（table-like）值是指可以当作表来读取的值。当且仅当一个值 `t` 符合以下条件时，该值被认为是类表值：

<!--@en-->
- Any of the following:

  - `t` is a table and has no metatable.
  - The `'__acandy_table_like'` field of `t`’s metatable is `true` (can be set by `getmetatable(t).__acandy_table_like = true`). The user needs to ensure that `t` can:

    - read content through `t[k]`;
    - get the sequence length through `#t`;
    - traverse keys and values through `pairs(t)` and `ipairs(t)`.

    ACandy only checks the metatable’s `'__acandy_table_like'` field and does not check whether `t` meets the above conditions.

<!--@zh-->
- 满足任意一条：

  - `t` 是一个表，且未设置元表。
  - `t` 的元表的 `'__acandy_table_like'` 字段为 `true`（可通过 `getmetatable(t).__acandy_table_like = true` 设置）。使用者需要确保 `t` 能够：

    - 通过 `t[k]` 读取内容；
    - 通过 `#t` 获取序列长度；
    - 通过 `pairs(t)` 和 `ipairs(t)` 遍历键值。

    ACandy 仅检查元表 `'__acandy_table_like'` 字段，不会检查 `t` 是否满足上述条件。

### List-like values | 类列表值

List-like values are values that can be read as sequences. A value `t` is considered a list-like value if and only if it satisfies the following conditions:  
类列表（list-like）值是指可以当作序列来读取的值。当且仅当一个值 `t` 符合以下条件时，该值被认为是类列表值：

<!--@en-->
- Any of the following:

  - `t` is a [table-like value](#table-like-values).
  - The `'__acandy_list_like'` field of `t`’s metatable is `true` (can be set by `getmetatable(t).__acandy_list_like = true`). The user needs to ensure that `t` can:

    - read content through `t[k]`;
    - get the sequence length through `#t`;
    - traverse values through `ipairs(t)`.

    ACandy only checks the metatable’s `'__acandy_list_like'` field and does not check whether `t` meets the above conditions.

<!--@zh-->
- 满足任意一条：

  - `t` 是一个[类表值](#类表值)。
  - `t` 的元表的 `'__acandy_list_like'` 字段为 `true`（可通过 `getmetatable(t).__acandy_list_like = true` 设置）。使用者需要确保 `t` 能够：

    - 通过 `t[k]` 读取内容；
    - 通过 `#t` 获取序列长度；
    - 通过 `ipairs(t)` 遍历值。

    ACandy 仅检查元表 `'__acandy_list_like'` 字段，不会检查 `t` 是否满足上述条件。

## Contribute | 贡献

Contributions of any form are welcomed, including bug reports, feature suggestions, documentation improvement, code optimization and so on!  
欢迎任何形式的贡献！包括但不限于汇报缺陷、提出功能建议、完善文档、优化代码。
