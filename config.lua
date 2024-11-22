-- ref: https://html.spec.whatwg.org/#elements-2

local DEFAULT_CONFIG = {
	html = {
		void_elements = {
			'area',
			'base', 'br',
			'col',
			'embed',
			'hr',
			'img',
			'input',
			'link',
			'meta',
			'param',
			'source',
			'track',
			'wbr',
		},
		raw_text_elements = {
			'script', 'style',
		},
	},
}

local utils = require('.utils')

local module = {}

---ACandy configuration.
---@class Config
---@field void_elements {[string]: boolean}
---@field raw_text_elements {[string]: boolean}

---@param output_type 'html'
---@param modify_config fun(config: Config)?
---@nodiscard
function module.parse_config(output_type, modify_config)
	local base_config = DEFAULT_CONFIG[output_type]
	assert(base_config, 'unsupported output type: '..output_type)

	local config = {
		void_elements = utils.list_to_bool_dict(base_config.void_elements),
		raw_text_elements = utils.list_to_bool_dict(base_config.raw_text_elements),
	}
	if modify_config then
		modify_config(config)
	end
	return config.void_elements, config.raw_text_elements
end

return module
