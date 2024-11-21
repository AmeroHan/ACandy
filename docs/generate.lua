local setmt = setmetatable
local concat = table.concat

local acandy = require('acandy')
local a = acandy.a

local DIR = 'docs'
local NAME = 'README'
local RAW_PATH = DIR..'/'..NAME..'.base.md'
local LANGUAGE_VERSIONS = {  ---@type {lang: string, name: string, main: boolean?}[]
	{lang = 'en', name = 'English', main = true},
	{lang = 'zh', name = '中文'},
}

local function get_file_path(lang_ver, base_dir)
	return (base_dir and base_dir..'/' or '')
		..NAME..(lang_ver.main and '' or ('.'..lang_ver.lang))..'.md'
end

---@alias ParsedLine {text: string, lang: string?}
---@alias MarkupResolver fun(lines: string[]): ParsedLine[]

-- Markup resolvers
local markups = {}  ---@type table<string, MarkupResolver>
setmetatable(markups, {
	__index = function (self, lang)
		---@type MarkupResolver
		local function resolver(lines)
			local res = {}
			for i, line in ipairs(lines) do
				res[i] = {text = line, lang = lang}
			end
			return res
		end
		markups[lang] = resolver  -- cache
		return resolver
	end,
})

function markups.LanguageLinks()
	local res = {}

	for i, file_ver in ipairs(LANGUAGE_VERSIONS) do
		local file_lang = file_ver.lang
		local p = a.p {'🌏 '}
		local children = p.children
		for _, link_ver in ipairs(LANGUAGE_VERSIONS) do
			local link_lang = link_ver.lang
			local link_name = link_ver.name
			if file_lang == link_lang then
				children:insert(a.strong(link_name))
			else
				children:insert(
					a.a {
						href = get_file_path(link_ver, file_ver.main and DIR or '..'),
						link_name,
					}
				)
			end
			children:insert(' | ')
		end
		children:remove()
		res[i] = {text = tostring(p), lang = file_lang}
	end

	return res
end

---@alias Markup {type: 'right-now' | 'block' | 'blocks', resolver: MarkupResolver} | {type: 'end'}

---@param line string
---@param line_num integer
---@return Markup?
local function parse_markup(line, line_num)
	local name, punc = line:match('^<!%-%- *@(.-)([:;]?) *%-%->$')
	if not name then
		return nil
	end
	if name == '' then
		if punc == ':' then
			error('Invalid markup "'..line..'" at line '..line_num)
		end
		return {type = 'end'}
	end
	return {
		type = ({[''] = 'block', [':'] = 'blocks', [';'] = 'right-now'})[punc],
		resolver = markups[name],
	}
end

---@generic T
---@param value T
---@return fun(): T
local function singleton(value)
	return function ()
		return value
	end
end

---@param line string?
---@param level integer?
local function check_not_eof(line, level)
	if not line then
		error('EOF should not be here', (level or 1) + 1)
	end
end

---@class State
---@field consume fun(self: self, line: string | nil, line_num: number): next_state: State, need_reconsume: boolean, parsed_lines: ParsedLine[]?
---@field [any] any

local states = {}

states.TextState = singleton({
	consume = function (self, line, line_num)
		if not line then
			return self, false, nil
		end

		local markup = parse_markup(line, line_num)
		if markup then
			return states.MarkupStartState(markup), true
		end

		local en_text = line:match('^(.-)  $')
		if en_text then
			return states.ZhLineState(), false, {{text = en_text, lang = 'en'}}
		end

		local common, en_text, zh_text = line:match('^(#*[ \t]*)(.-) | (.+)$')
		if common then
			return self, false, {
				{text = common..en_text, lang = 'en'},
				{text = common..zh_text, lang = 'zh'},
			}
		end

		return self, false, {{text = line}}
	end,
})

states.ZhLineState = singleton({
	consume = function (self, line, line_num)
		check_not_eof(line)
		if parse_markup(line, line_num) then
			error('Unexpected markup '..line..' at line '..line_num)
		end

		return states.TextState(), false, {{text = line, lang = 'zh'}}
	end,
})

do
	local mt = {
		__index = {  ---@type State
			consume = function (self, line, line_num)
				check_not_eof(line)
				local markup_type = self.markup.type
				local resolver = self.markup.resolver
				if markup_type == 'end' then
					error('Unexpected end markup at line '..line_num)
				elseif markup_type == 'right-now' then
					return states.TextState(), false, resolver({})
				elseif markup_type == 'block' then
					return states.MarkupedBlockState(resolver), false
				elseif markup_type == 'blocks' then
					return states.MarkupedMultiblocksState(resolver), false
				end
				error('Unknown markup type "'..markup_type..'" at line '..line_num)
			end,
		},
	}
	---@param markup Markup
	---@return State
	function states.MarkupStartState(markup)
		return setmt({markup = markup}, mt)
	end
end

do
	---@class MarkupedBlocksState: State
	---@field lines string[]
	---@field resolver MarkupResolver

	local multiblocks_mt = {
		__index = {
			---@param self MarkupedBlocksState
			---@param line string?
			---@param line_num integer
			consume = function (self, line, line_num)
				check_not_eof(line)  ---@cast line string

				local lines = self.lines
				local resolver = self.resolver
				local new_markup = parse_markup(line, line_num)
				if new_markup then
					if new_markup.type == 'end' then
						return states.TextState(), false, resolver(lines)
					end
					return states.MarkupStartState(new_markup), true, resolver(lines)
				end

				if not (line == '' and #lines == 0) then  -- ignore empty lines at the beginning
					lines[#lines+1] = line
				end

				return self, false, nil
			end,
		},
	}

	local single_block_mt = {
		__index = {
			---@param self MarkupedBlocksState
			---@param line string?
			---@param line_num integer
			consume = function (self, line, line_num)
				local lines = self.lines
				local resolver = self.resolver

				if not line then
					if #lines == 0 then
						error('Unexpected EOF')
					end
					return self, false, resolver(lines)
				end

				local new_markup = parse_markup(line, line_num)
				if new_markup then
					if new_markup.type == 'end' then
						error('Unexpected end markup at line '..line_num)
					end
					return states.MarkupStartState(new_markup), true, resolver(lines)
				end

				if not (line == '' and #lines == 0) then
					-- ignore empty lines at the beginning
					lines[#lines+1] = line
				end

				if line == '' and #lines > 0 then
					return states.MarkupedBlockMayEndState(resolver, lines), false
				end

				return self, false
			end,
		},
	}

	local single_block_may_end_mt = {
		__index = {
			---@param self MarkupedBlocksState
			---@param line string?
			---@param line_num integer
			consume = function (self, line, line_num)
				local lines = self.lines
				local resolver = self.resolver

				if not line then
					return self, false, resolver(lines)
				end

				if line == '' then
					lines[#lines+1] = line
					return self, false
				elseif line:find('^[ \t]') then
					lines[#lines+1] = line
					return states.MarkupedBlockState(resolver, lines), false
				else
					return states.TextState(), true, resolver(lines)
				end
			end,
		},
	}

	---@param resolver MarkupResolver
	function states.MarkupedMultiblocksState(resolver)
		return setmt({
			lines = {},
			resolver = resolver,
		}, multiblocks_mt)
	end

	---@param resolver MarkupResolver
	---@param lines string[]?
	function states.MarkupedBlockState(resolver, lines)
		return setmt({
			lines = lines or {},
			resolver = resolver,
		}, single_block_mt)
	end

	---@param resolver MarkupResolver
	---@param lines string[]
	function states.MarkupedBlockMayEndState(resolver, lines)
		return setmt({
			lines = lines,
			resolver = resolver,
		}, single_block_may_end_mt)
	end
end

---@param content string
---@return ParsedLine[]
local function parse(content)
	local lines = {}
	for line in content:gmatch('[^\n\r]*') do
		lines[#lines+1] = line
	end

	local res = {}
	local function extend_res(parsed_lines)
		for _, line in ipairs(parsed_lines) do
			res[#res+1] = line
		end
	end

	local state = states.TextState()
	local i = 1
	local max_i = #lines + 1  -- for EOF
	while i < max_i do
		local next_state, need_reconsume, parsed_lines = state:consume(lines[i], i)
		if parsed_lines then
			extend_res(parsed_lines)
		end
		state = next_state
		if not need_reconsume then
			i = i + 1
		end
	end
	return res
end

---@param parsed_lines ParsedLine[]
---@param lang string
---@return string
local function render(parsed_lines, lang)
	local note = [[<!--
This file is generated by program.
DO NOT edit it directly. Edit ]]..RAW_PATH..[[ instead.
-->
]]

	local res = {note}
	for _, parsed_line in ipairs(parsed_lines) do
		if not parsed_line.lang or parsed_line.lang == lang then
			res[#res+1] = parsed_line.text
		end
	end
	return concat(res, '\n')
end



local function read_from(path)
	local file = io.open(path, 'r')
	assert(file, 'open '..path..' failed')
	local content = file:read('*a'):gsub('\r\n', '\n')
	file:close()
	return content
end

local function write_into(file_path, content)
	local file = io.open(file_path, 'w+')
	assert(file, 'open '..file_path..' failed')
	file:write(content)
	file:close()
end


local raw_content = read_from(RAW_PATH)
local parsed = parse(raw_content)

for _, ver in ipairs(LANGUAGE_VERSIONS) do
	local lang = ver.lang
	local file_path = get_file_path(ver, not ver.main and DIR or nil)
	local content = render(parsed, lang)
	write_into(file_path, content)
	print('Generated '..file_path..'.')
end

print('Done.')
