
-- Composable streams for string and cdata-buffer-based I/O.
-- Written by Cosmin Apreutesei. Public Domain.

if not ... then require'stream_test'; return end

local ffi = require'ffi'
local glue = require'glue'

local stream = {}

local char_ptr_t = ffi.typeof'char*'

--allow a function's `buf, sz` args to be `s, [len]`.
function stream.stringdata(buf, sz)
	if type(buf) == 'string' then
		if sz then
			assert(sz <= #buf, 'string too short')
		else
			sz = #buf
		end
		return ffi.cast(char_ptr_t, buf), sz
	else
		return buf, sz
	end
end

--convert `write(buf, sz) -> sz_written` into `write(buf, sz) -> true | nil,err`
function stream.repeatwriter(write)
	return function(buf, sz)
		local buf, sz = stream.stringdata(buf, sz)
		while sz > 0 do
			local len, err, errcode = write(buf, sz)
			if not len then return nil, err, errcode end
			buf = buf + len
			sz  = sz  - len
		end
		return true
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
