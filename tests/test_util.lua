---@diagnostic disable: undefined-field

local match_html = require('tests.utils').match_html


describe('`match_html` function', function ()
	it('returns true when 2 args provided, and 1st arg equals 2st arg', function ()
		assert.is_true(match_html('a', 'a'))
		assert.is_false(match_html('a', 'b'))
	end)

	it('removes line feeds and leading tabs in segments', function ()
		assert.is_true(match_html('ab', '\ta\n\t\tb\n'))
		assert.is_true(match_html('ab', '\na\n\nb\n'))

		assert.is_false(match_html('\ta\n\t\tb\n', 'ab'))
		assert.is_false(match_html('a', 'a\t'))
		assert.is_false(match_html('ab', 'a\tb'))
		assert.is_false(match_html('a', ' a'))
	end)

	it('how do you describe?', function ()
		assert.is_true(match_html('abc', 'a', 'b', 'c'))
		assert.is_false(match_html('abc', 'a', 'b', 'd'))
	end)

	it('ignores order within a table arg', function ()
		assert.is_true(match_html('ab', {'a', 'b'}))
		assert.is_true(match_html('ba', {'a', 'b'}))

		assert.is_false(match_html('a', {'a', 'b'}))
	end)

	it('can combine strings and tables', function ()
		assert.is_true(match_html('acbd', 'a', {'b', 'c'}, 'd'))
	end)
end)
