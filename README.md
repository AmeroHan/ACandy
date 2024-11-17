# ACandy: a sugary Lua module for building HTML

<p align="center">🌏 <strong>English</strong> | <a href="./docs/README_zh.md">简体中文</a></p>

<p align="center">
This work uses <a href="https://semver.org/">Semantic Versioning</a>
</p>

ACandy is a pure Lua module for building HTML, which takes advantage of Lua’s syntactic sugar and metatable, giving an intuitive DSL to build HTML from Lua.

<!-- 有意显示 -->
ACandy 是一个构建 HTML 的纯 Lua 模块。利用 Lua 的语法糖和元表，ACandy 提供了一个易用的 DSL 来从 Lua 构建 HTML。

## Quick look

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

Output (formatted):

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

## Import

```lua
local acandy = require('acandy')
local a = acandy.a
```

`a` is the entry point for all elements, because:

- `a` is ACandy’s first letter;
- `a` is short to type;
- <code>a.*xxx*</code> can be understood as “a *xxx*” in English.

## Create elements

```lua
local elem = a.p {
   class="my-paragraph", style="color: #114514;",
   'This sentence is inside a ', a.code('<p>'), ' element.',
}
print(elem)
```

In this code, `a.p` is a function that returns an element. It takes a table as its argument, in which key-value pairs and sequences represent attributes and children of the element respectively, and the same applies to other elements. If there is only one child and no attributes need to be set, the child can be passed directly as the argument of the function, so `a.code('...')` is equivalent to `a.code({ '...' })`.

The output of this code, formatted (the same below), is as follows.

```html
<p class="my-paragraph" style="color: #114514;">
   This sentence is inside a <code>&lt;p&gt;</code> element.
</p>
```

> [!TIP]
> - You don’t need to handle HTML escaping in strings. If you don't want automatic escaping, you can put the content in [`acandy.Raw`](#acandyraw).
> - Child nodes do not have to be elements or strings—although only these two types are shown here, any value that can be `tostring` is capable of a child node.

For HTML elements, <code>a.*xxx*</code> is case-**in**sensitive, so `a.div`, `a.Div`, `a.DIV`, etc., are the same value and will all become `<div></div>`. For other elements, <code>a.*xxx*</code> is case-sensitive.

### Attributes

Attributes are provided to elements through key-value pairs in the table. The keys must be [valid XML strings](https://www.w3.org/TR/xml/#NT-Name) (currently the module only supports ASCII characters); the values can be:

- `nil` and `false` indicate no such attribute;
- `true` indicates a boolean attribute, e.g., `a.script { async=true }` means `<script async></script>`;
- Other values will be `tostring` and escape `< > & "`.

### Children

Child nodes are provided to elements through the sequence part of the table. Any value other than `nil` can be a child node.

#### Elements, strings, numbers, booleans, and other values not mentioned later

When the element is stringified, these values will be attempted to `tostring` and escape `< > &`. If you don't want automatic escaping, you can put the content in [`acandy.Raw`](#acandyraw).

In the following example, we use three elements (`<p>`) as child nodes of `<article>`, and use strings, numbers, and booleans as elements of `<p>`. It is trivial to guess the result.

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

#### Tables

When the element is stringified, tables may be treated as sequences, and ACandy will recursively attempt to stringify the elements in the sequence.

The following tables are treated as sequences:

- Tables without metatables, e.g., `{ 1, 2, 3 }`;
- Tables returned by [`acandy.Fragment`](#acandyfragment), e.g., `Fragment { 1, 2, 3 }`;
- Tables with the `'__acandy_fragment_like'` field in the metatable set to `true`, i.e., you can make <code>*val*</code> be treated as a sequence when stringified by setting <code>getmetatable(*val*).__acandy_fragment_like = true</code>.

Other tables (e.g., tables returned by `a.p { 1, 2, 3 }`) will be directly converted to strings by `tostring`, so make sure `__tostring` is defined.

```lua
local sequence1 = { '3', '4' }
local sequence2 = { '2', sequence1 }
local elem = a.div { '1', sequence2 }
print(elem)
```

```html
<p>1234</p>
```

#### Functions

Functions can be used as child nodes, which is equivalent to calling the function and using the return value as a child node, with the only difference being that the function will be deferred until `tostring` is called.

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

### Bracket syntax (setting element attributes)

Placing a string in brackets can quickly set `id` and `class`.

```lua
local elem = a.div['#my-id my-class-1 my-class-2'] {
   a.p 'You know what it is.',
}
print(elem)
```

Placing a table in brackets can set element attributes, not limited to `id` and `class`. This makes reusing attributes more convenient.

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

```html
<div id="my-id" class="my-class-1 my-class-2">
   <p>You know what it is.</p>
</div>
```

### Slash syntax (breadcrumbs)

```lua
local syntax = <elem1> / <elem2> / <elem3>
local example = a.main / a.div / a.p { ... }
```

is equivalent to:

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
> breadcrumbs can be cached, just like `link_item` in the above example.

### `acandy.some`

```lua
local frag1 = some.<tag>(<arg1>, <arg2>, ...)
local frag2 = some.<tag>[<attr>](<arg1>, <arg2>, ...)
```

is equivalent to:

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

Example:

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

## Element instance

If an element is obtained by calling functions like `a.div(...)`, `a.div[...](...)`, it is called (tentatively) a "**constructed element**"; when a constructed element is the end of a breadcrumb, the breadcrumb also returns a constructed element; while `a.div`, `a.div[...]` are not constructed elements.

A constructed element `elem` has the following properties:

- `elem.tag_name`: The tag name of the element, reassignable.
- `elem.attributes`: A table that stores all the attributes of the element, changes to this table will take effect on the element itself; cannot be reassigned.
- `elem.children`: A [Fragment](#acandyfragment) that stores all the child nodes of the element, changes to this table will take effect on the element itself; cannot be reassigned.
- <code>elem.*some_attribute*</code> (<code>*some_attribute*</code> is a string): Equivalent to <code>elem.attributes.*some_attribute*</code>.
- <code>elem[*n*]</code> (<code>*n*</code> is an integer): Equivalent to <code>elem.children[*n*]</code>.

Example:

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

## Node constructors

### `acandy.Fragment`

`Fragment` holds multiple elements. The only differences between `Fragment` and a regular table are:

- It has `__tostring` set, so you can get the HTML string;
- It has `__index` set, so you can call all methods in the `table` library which take a table as the first parameter (e.g., `table.insert`, `table.remove`) in an object-oriented manner.

You can create an empty Fragment with `Fragment()` or `Fragment({})`.

When there is only one element, `Fragment(<child>)` is equivalent to `Fragment({ <child> })`.

Example:

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

- It has `__tostring` set, so you can get the corresponding string with `tostring`;
- It has `__concat` set, so you can concatenate two objects obtained by `Raw` with `..`.

Example:

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

Currently only the HTML5 doctype is supported. It is accessed by `DocType.HTML`.

```lua
tostring(acandy.Doctype.HTML)  --> '<!DOCTYPE html>'
```

## Environmental methods

### `acandy.extend_env`

```lua
function acandy.extend_env(env: table) -> nil
```

Extend the environment in place with `acandy.a` as `__index`, e.g., `_ENV`. This makes it possible to directly use the tag name rather than tediously type `a.`, unless there is a naming conflict with local variables or global variables.

> [!WARNING]
> It is not recommended to use this method on the global environment, as it may cause hard-to-detect naming conflicts.

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

Similar to `acandy.extend_env`, but returns a new table instead of modifying the original table.

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

## Contribute

Contributions of any form are welcomed, including bug reports, feature suggestions, documentation improvement, code optimization and so on!
