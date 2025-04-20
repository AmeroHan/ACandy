rockspec_format = '3.0'
package = 'html'
version = 'scm-1'
source = {
   url = 'git+https://github.com/AmeroHan/ACandy.git',
   branch = 'main',
}

description = {
   summary = 'ACandy: a sugary Lua module for building HTML',
   detailed = [[
ACandy is a pure Lua module for building HTML. Taking advantage of Lua’s syntactic sugar and
metatable, it provides an intuitive DSL to build HTML from Lua.

]],
   homepage = 'https://github.com/AmeroHan/ACandy',
   license = 'MIT',
   labels = { 'html', 'dsl' },
}

dependencies = {
   'lua >= 5.1',
}
test_dependencies = {
   'busted',
}
test = {
   type = 'busted',
}

build = {
   type = 'builtin',
   modules = {
      ['acandy.init'] = 'acandy/init.lua',
      ['acandy.classes'] = 'acandy/classes.lua',
      ['acandy.config'] = 'acandy/config.lua',
      ['acandy.utils'] = 'acandy/utils.lua',
      ['acandy.utf8_ponyfill'] = 'acandy/utf8_ponyfill.lua',
   },
   copy_directories = {},
}
