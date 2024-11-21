local config = {}

-- ref: https://html.spec.whatwg.org/#elements-2

config.void_elements = {
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
}

config.raw_text_elements = {
	'script', 'style',
}

return config
