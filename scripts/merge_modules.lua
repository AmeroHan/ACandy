local FOLDER = 'acandy'
local ENTRY_MODULE = 'init'
local SUBMODULES = {
	'classes',
	'config',
	'utils',
}
local MERGED_FILE_PATH = 'ACandy.lua'


local submodules_set = {}
for _, submodule in ipairs(SUBMODULES) do
	submodules_set[submodule] = true
	submodules_set[#submodules_set+1] = submodule
end

local function get_file_content(file_path)
	local file = io.open(file_path, 'r')
	if not file then
		error('failed to open file: '..file_path)
	end
	local content = file:read('a')
	file:close()
	return content
end

---@param code string
---@return string
local function replace_submodule_require(code)
	local function replacer(module_name)
		if not submodules_set[module_name] then
			error('submodule `'..FOLDER..'.'..module_name..'` not found in `SUBMODULES`')
		end
		return 'acandy_submodules.'..module_name
	end
	local module_name_pattern = FOLDER..'%.([%w_]+)'
	return (code
		:gsub("require%s*%(%s*'"..module_name_pattern.."'%s*%)", replacer)
		:gsub('require%s*%(%s*"'..module_name_pattern..'"%s*%)', replacer)
		:gsub("require%s*'"..module_name_pattern.."'", replacer)
		:gsub('require%s*"'..module_name_pattern..'"', replacer)
	)
end

local submodule_src_codes = {}
for _, submodule in ipairs(SUBMODULES) do
	submodule_src_codes[submodule] = replace_submodule_require(
		get_file_content(FOLDER..'/'..submodule..'.lua')
	)
end

local submodules_table_content = (function ()
	local t = {}
	for name, code in pairs(submodule_src_codes) do
		t[#t+1] = ('load_%s = function ()\n%s\nend,'):format(name, code:match('^%s*(.-)%s*$'))
	end
	return table.concat(t, '\n')
end)()

local submodules_init_code = [[
local acandy_submodules
acandy_submodules = setmetatable({
]]..submodules_table_content..[[

}, { __index = function(t, module_name)
	local loader_key = 'load_'..module_name
	local mod = t[loader_key]()
	t[module_name] = mod
	t[loader_key] = nil
	return mod
end
})

]]

local entry_code = get_file_content(FOLDER..'/'..ENTRY_MODULE..'.lua')
local doc_comment, main_code = entry_code:match('^(%-%-%[%[.-%]%]%s*)(.*)')
if not doc_comment then
	doc_comment, main_code = '', entry_code
end
local merged_code = doc_comment..submodules_init_code..replace_submodule_require(main_code)
local file = io.open(MERGED_FILE_PATH, 'w')
if not file then
	error('failed to open file: '..MERGED_FILE_PATH)
end
file:write(merged_code)
file:close()
print('Merged modules into: '..MERGED_FILE_PATH)
