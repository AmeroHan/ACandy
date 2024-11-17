local acandy = require('acandy')
local a = acandy.a

local RAW_PATH = 'docs/README.base.md'
local EN_PATH = 'README.md'
local ZH_PATH = 'docs/README_zh.md'

local raw_content
do
	local file = io.open(RAW_PATH, 'r')
	assert(file, 'open '..RAW_PATH..' failed')
	raw_content = file:read('*a'):gsub('\r\n', '\n')
	file:close()
end

local function lang_links(lang)
	local links = {
		{url = '../'..EN_PATH, lang = 'en', text = 'English'},
		{url = './'..ZH_PATH, lang = 'zh-Hans', text = '简体中文'},
	}
	local p = a.p {align = 'center', '🌏 '}
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

local function resolve_markup(content, lang)
	return content:gsub('<!%-%-@(%a[%a%-]-%a)%-%->\n(.-\n\n)', function (l, text)
		if l == lang then
			return text
		else
			return ''
		end
	end)
end

local function add_lang_links(content, lang)
	return content:gsub('\n(# [^\n]+)', '%1\n\n'..lang_links(lang))
end

local en_content = resolve_markup(
	('\n'..raw_content)
	:gsub('  \n[^\n]+', '')
	:gsub(' | [^\n]+', ''),
	'en'
)
en_content = add_lang_links(en_content, 'en')

local zh_content = resolve_markup(
	('\n'..raw_content)
	:gsub('[^\n]+  \n', '')
	:gsub('\n(#* ?)[^\n]+ | ', '\n%1'),
	'zh-Hans'
)
en_content = add_lang_links(en_content, 'zh-Hans')

local function write_into(file_path, content)
	local file = io.open(file_path, 'w+')
	assert(file, 'open '..file_path..' failed')
	file:write(content)
	file:close()
end

write_into(EN_PATH, en_content)
write_into(ZH_PATH, zh_content)
