---Ponyfill for some of functions of `utf8` standard library in Lua 5.3.

assert(type(utf8) ~= 'table', 'utf8 module already exists')

local MAX_CODE_POINT = 0x10FFFF
local MIN_CODE_POINT_BY_TAIL_LEN = { 0x80, 0x800, 0x10000 }

---@param bytes integer[]
---@param pos integer
---@return integer? code_point nil if invalid
---@return integer? next_position nil if invalid. NOTE may be out of bounds
local function utf8_decode(bytes, pos)
	local head = bytes[pos]
	if head < 0x80 then
		return head, pos + 1
	end
	local res, n_tail
	if head < 0xC0 then
		return nil
	elseif head <= 0xDF then
		res, n_tail = head - 0xC0, 1
	elseif head <= 0xEF then
		res, n_tail = head - 0xE0, 2
	elseif head <= 0xF7 then
		res, n_tail = head - 0xF0, 3
	else
		return nil
	end
	if pos + n_tail > #bytes then
		return nil
	end
	for p = pos + 1, pos + n_tail do
		local byte = bytes[p]
		byte = byte - 0x80
		if byte < 0 or byte >= 0x40 then
			return nil
		end
		res = res * 64 + byte
	end
	if res < MIN_CODE_POINT_BY_TAIL_LEN[n_tail] or res > MAX_CODE_POINT then
		return nil
	end
	return res, pos + n_tail + 1
end

local utf8 = {}

---The pattern (a string, not a function) which matches exactly one UTF-8 byte
---sequence, assuming that the subject is a valid UTF-8 string.
---
---- Lua 5.3: `[\0-\x7F\xC2-\xF4][\x80-\xBF]*`
---- Lua 5.4: `[\0-\x7F\xC2-\xFD][\x80-\xBF]*`
---
---The difference is that 5.4 accepts code points > 10FFFF. Here we adopt the
---5.3 pattern.
utf8.charpattern = '[\0-\127\194-\244][\128-\191]*'


---@param byte integer | nil
local function isContinuation(byte)
	return byte and byte >= 0x80 and byte < 0xC0
end

---@param s string
---@param n integer
---@return integer?, integer?
local function code_point_iterator(s, n)
	local bytes = { s:byte(1, -1) }
	if n <= 0 then  -- first iteration?
		n = 1  -- start from here
	elseif n <= #s then
		n = n + 1  -- skip current byte
		while isContinuation(bytes[n]) do
			n = n + 1  -- and its continuations
		end
	end

	if n > #s then
		return nil  -- no more code points
	end

	local cp, next_pos = utf8_decode(bytes, n)
	if not next_pos or isContinuation(bytes[next_pos]) then
		error("invalid UTF-8 code", 2)
	end
	return n, cp
end

---Returns values so that the construction
---```lua
---for p, c in utf8.codes(s) do body end
---```
---will iterate over all UTF-8 characters in string s, with p being the position
---(in bytes) and c the code point of each character. It raises an error if it
---meets any invalid byte sequence.
---@param s string
function utf8.codes(s)
	return code_point_iterator, s, 0
end

return utf8
