local type = type
local concat = table.concat


local function match_html(str, ...)
	local parts = {...}

	local last = 1
	for _, v in ipairs(parts) do
		if type(v) == 'string' then
			v = v:gsub('^\t+', ''):gsub('\n[\t]*', '')
			local s, e = str:find(v, last, true)
			if s ~= last then return false end
			last = e + 1
		else  -- table
			local unmatched = {}
			for i, part in ipairs(v) do
				unmatched[i] = part
			end
			local total_len = #concat(v)
			local substr = str:sub(last, last + total_len - 1)
			for _ = 1, #v do
				local found = false
				for i = 1, #unmatched do
					local s, e = substr:find(unmatched[i], 1, true)
					if s == 1 then  -- matched
						found = true
						substr = substr:sub(e + 1)
						table.remove(unmatched, i)
						break
					end
				end
				if not found then return false end
			end
			-- all matched
			last = last + total_len
		end
	end
	if last ~= #str + 1 then
		return false
	end
	return true
end


return {
	match_html = match_html,
}
