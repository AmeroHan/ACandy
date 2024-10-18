local config = {}

-- ref: https://html.spec.whatwg.org/multipage/syntax.html#elements-2

config.HTML_ELEMS = {}  ---@type table<string, true>
do
	local list = {  ---@type string[]
		'a', 'abbr', 'acronym', 'address', 'area', 'article', 'aside', 'audio',
		'b', 'base', 'bdi', 'bdo', 'big', 'blockquote', 'body', 'br', 'button',
		'canvas', 'caption', 'center', 'cite', 'code', 'col', 'colgroup',
		'data', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'dir', 'div', 'dl', 'dt',
		'em', 'embed',
		'fencedframe', 'fieldset', 'figcaption', 'figure', 'font', 'footer', 'form', 'frame', 'frameset',
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup', 'hr', 'html',
		'i', 'iframe', 'img', 'input', 'ins',
		'kbd',
		'label', 'legend', 'li', 'link',
		'main', 'map', 'mark', 'marquee', 'menu', 'meta', 'meter',
		'nav', 'nobr', 'noembed', 'noframes', 'noscript',
		'object', 'ol', 'optgroup', 'option', 'output',
		'p', 'param', 'picture', 'plaintext', 'portal', 'pre', 'progress',
		'q',
		'rb', 'rp', 'rt', 'rtc', 'ruby',
		's', 'samp', 'script', 'search', 'section', 'select', 'slot', 'small', 'source', 'span', 'strike', 'strong',
		'style', 'sub', 'summary', 'sup',
		'table', 'tbody', 'td', 'template', 'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'tt',
		'u', 'ul',
		'var', 'video',
		'wbr', 'xmp',
	}
	local dict = config.HTML_ELEMS
	for _, tag in pairs(list) do
		dict[tag] = true
	end
end

config.VOID_ELEMS = {
	area = true,
	base = true,
	br = true,
	col = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	link = true,
	meta = true,
	param = true,
	source = true,
	track = true,
	wbr = true,
}

config.RAW_TEXT_ELEMS = {
	script = true, style = true,
}

return config
