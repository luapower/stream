
-- Composable streams for string and cdata-buffer-based I/O.
-- Written by Cosmin Apreutesei. Public Domain.

if not ... then require'stream_test'; return end

local ffi = require'ffi'
local glue = require'glue'

local stream = {}

local const_char_ptr_t = ffi.typeof'const char*'

--allow a function's `buf, sz` args to be `s, [len]`.
function stream.stringdata(buf, sz)
	if type(buf) == 'string' then
		if sz then
			assert(sz <= #buf, 'string too short')
		else
			sz = #buf
		end
		return ffi.cast(const_char_ptr_t, buf), sz
	else
		return buf, sz
	end
end

--make a `read(sz) -> buf, sz` that is reading from a string or cdata buffer.
function stream.memreader(buf, len)
	local buf, len = stream.stringdata(buf, len)
	local i = 0
	return function(n)
		assert(n > 0)
		if i == len then
			return nil, 'eof'
		else
			n = math.min(n, len - i)
			i = i + n
			return buf + i - n, n
		end
	end
end

--convert `read(maxsz) -> buf, sz` into `read(buf, maxsz) -> sz`.
function stream.readtobuffer(read)
	return function(ownbuf, maxsz)
		local buf, sz = read(maxsz)
		if not buf then return nil, sz end
		ffi.copy(ownbuf, buf, sz)
		return sz
	end
end

--Based on `read(buf, maxsz) -> sz`, create the API:
--  `readline() -> s`
--  `read(maxsz) -> buf, sz`
function stream.linebuffer(read, term, sz)

	local find_term
	if #term == 1 then
		local t = string.byte(term)
		function find_term(buf, i, j)
			for i = i, j-1 do
				if buf[i] == t then
					return true, i, i+1
				end
			end
			return false, 0, 0
		end
	elseif #term == 2 then
		local t1, t2 = string.byte(term, 1, 2)
		function find_term(buf, i, j)
			for i = i, j-2 do
				if buf[i] == t1 and buf[i+1] == t2 then
					return true, i, i+2
				end
			end
			return false, 0, 0
		end
	else
		assert(false)
	end

	--single-piece ring buffer (no wrap-around).

	assert(sz >= 1024)
	local buf = ffi.new('char[?]', sz)

	local i = 0 --index of first valid byte.
	local j = 0 --index right after last valid byte.

	local function more()
		if j == i then --buffer empty: reset.
			i, j = 0, 0
		elseif j == sz then --no more space at the end.
			if i == 0 then --buffer full.
				return nil, 'line too long'
			else --move data to make space at the end.
				ffi.copy(buf, buf + i, j - i)
				i, j = 0, j - i
			end
		end
		local n, err = read(buf + j, sz - j)
		if not n then return nil, err end
		if n == 0 then return nil, 'null read' end
		j = j + n
		return true
	end

	local function readline()
		if j == i then --buffer empty: refill.
			local ok, err = more()
			if not ok then return nil, err end
		end
		local n = 0
		while true do
			local found, line_j, next_i = find_term(buf, i + n, j)
			if found then
				local s = ffi.string(buf + i, line_j - i)
				i = next_i
				return s
			else
				n = j - i - (#term - 1)
				local ok, err = more()
				if not ok then return nil, err end
			end
		end
	end

	local function read(maxn)
		if j == i then --buffer empty: refill.
			local ok, err = more()
			if not ok then return nil, err end
		end
		local n = math.min(maxn, j - i)
		local buf = buf + i
		i = i + n
		return buf, n
	end

	return {
		readline = readline,
		read = read,
	}

end

--[[
--convert `read(buf, sz) -> sz` into `read(sz) -> buf, sz` with read-ahead.
function stream.buffered_reader(bufsize, read, ctype)
	local buf, sz = glue.buffer()(bufsize)
	local i, len, err = 0, 0
	return function(n)
		if len == 0 then
			i = 0
			len, err = read(buf, sz)
			if not len then return nil, err end
		end
		n = math.min(n, len)
		i = i + n
		len = len - n
		return buf + i - n, n, len
	end
end
]]

--make a `write(buf, sz)` that appends data to an expanding buffer.
function stream.dynarray_writer(dynarray)
	local buffer = glue.buffer'char[?]'
	local i = 0
	return function(buf, sz)
		local buf0 = buffer(i)
		local buf1 = buffer(i + sz)
		if buf1 ~= buf0 then
			ffi.copy(buf1, buf0, i)
		end
		ffi.copy(buf1 + i, buf, sz)
		i = i + sz
		return sz
	end, function()
		local sz = i
		i = 0
		return buffer(sz), sz
	end
end

function stream.writebuffer(write, dynarray)
	local write, flush = stream.dynarray_writer(dynarray)

end

return stream
