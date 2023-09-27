local config = {}

config.htmlElements = {
	a = true, abbr = true, acronym = true,
	address = true, area = true, article = true,
	aside = true, audio = true, b = true,
	base = true, bdi = true, bdo = true,
	big = true, blockquote = true, body = true,
	br = true, button = true, canvas = true,
	caption = true, center = true, cite = true,
	code = true, col = true, colgroup = true,
	data = true, datalist = true, dd = true,
	del = true, details = true, dfn = true,
	dialog = true, dir = true, div = true,
	dl = true, dt = true, em = true,
	embed = true, fieldset = true, figcaption = true,
	figure = true, font = true, footer = true,
	form = true, frame = true, frameset = true,
	h1 = true, h2 = true, h3 = true,
	h4 = true, h5 = true, h6 = true,
	head = true, header = true,hgroup = true,
	hr = true, html = true, i = true,
	iframe = true, image = true, img = true,
	input = true, ins = true, kbd = true,
	label = true, legend = true,li = true,
	link = true, main = true,map = true,
	mark = true, marquee = true,menu = true,
	menuitem = true, meta = true,meter = true,
	nav = true, nobr = true,noembed = true,
	noframes = true, noscript = true,object = true,
	ol = true, optgroup = true,option = true,
	output = true, p = true,param = true,
	picture = true, plaintext = true, portal = true,
	pre = true, progress = true, q = true,
	rb = true, rp = true, rt = true,
	rtc = true, ruby = true, s = true,
	samp = true, script = true, search = true,
	section = true, select = true, slot = true,
	small = true, source = true, span = true,
	strike = true, strong = true, style = true,
	sub = true, summary = true, sup = true,
	table = true, tbody = true, td = true,
	template = true, textarea = true, tfoot = true,
	th = true, thead = true, time = true,
	title = true, tr = true, track = true,
	tt = true, u = true, ul = true,
	var = true, video = true,
	wbr = true, xmp = true
}

config.voidElements = {
	area = true, base = true, br = true,
	col = true, embed = true, hr = true,
	img = true, input = true, link = true,
	meta = true, param = true, source = true,
	track = true, wbr = true
}

return config
