local acandy = require('acandy')
local a = acandy.a

local RAW_PATH = 'docs/README.base.md'
local EN_PATH = 'README.md'
local ZH_PATH = 'docs/README.zh.md'

local raw_content
do
	local file = io.open(RAW_PATH, 'r')
	assert(file, 'open '..RAW_PATH..' failed')
	raw_content = file:read('*a'):gsub('\r\n', '\n')
	file:close()
end

local markups = {}

function markups.LanguageLinks(lang)
	local links = {
		{url = '../'..EN_PATH, lang = 'en', text = 'English'},
		{url = './'..ZH_PATH, lang = 'zh-Hans', text = '简体中文'},
	}
	local p = a.p {'🌏 '}
	local children = p.children
	for _, link in ipairs(links) do
		children:insert(
			lang == link.lang
			and a.strong(link.text)
			or a.a {href = link.url, link.text}
		)
		children:insert(' | ')
	end
	children:remove()
	return tostring(p)
end

local function resolve_markups(content, lang)
	local note = [[<!--
This file is generated by program.
DO NOT edit it directly. Edit ]]..RAW_PATH..[[ instead.
-->

]]
	return note..content:gsub('<!%-%-@(%a[%a%-]-%a)%-%->(.-)\n\n', function (name, text)
		local resolver = markups[name]
		text = text:gsub('^\n', '', 1)
		if resolver then
			return resolver(lang, text)..'\n\n'
		elseif name == lang then
			return text..'\n\n'
		end
		return ''
	end)
end

local en_content = resolve_markups(
	raw_content
	:gsub('  \n[^\n]+', '')
	:gsub(' | [^\n]+', ''),
	'en'
)

local zh_content = resolve_markups(
	('\n'..raw_content)
	:gsub('[^\n]+  \n', '')
	:gsub('\n(#* ?)[^\n]+ | ', '\n%1')
	:gsub('^\n', '', 1),
	'zh-Hans'
)

local function write_into(file_path, content)
	local file = io.open(file_path, 'w+')
	assert(file, 'open '..file_path..' failed')
	file:write(content)
	file:close()
end

write_into(EN_PATH, en_content)
write_into(ZH_PATH, zh_content)
