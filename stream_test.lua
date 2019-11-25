local stream = require'stream'
local ffi = require'ffi'
local clock = require'time'.clock
local pp = require'pp'

local function linebuffer_fuzz_test()
	local seed = math.floor(clock())
	--local seed = 2450522
	--local seed = 2450538
	--local seed = 2450565
	--local seed = 2450639
	print('randomseed', seed)
	math.randomseed(seed)

	local max_line_size = 1024 * 2
	local t = {}
	for i = 1, math.random(max_line_size * math.pi * 1000) do
		t[i] = string.char(math.random(0, 255))
	end
	local s = table.concat(t) .. '\r\n'

	local n1, n2 = 0, 1/0
	for s in s:gmatch'[^\r\n]+' do
		n1 = math.max(n1, #s)
		n2 = math.min(n2, #s)
	end
	local term = s:match'\r?\n'
	print('line size range: '..n2..'..'..n1..
		' (max='..max_line_size..') term: '..pp.format(term))

	local read = stream.memreader(s)
	local read = stream.readtobuffer(read)
	local lb = stream.linebuffer(read, term, max_line_size)

	local t = {}
	while true do
		local s, err
		if math.random() > .5 then
			s, err = lb.readline()
			if not s then break end
			s = s .. term
		else
			local buf, sz = lb.read(math.random(max_line_size * math.pi / 2))
			if not buf then break end
			s = ffi.string(buf, sz)
		end
		t[#t+1] = s
	end
	local s2 = table.concat(t)

	print(#s2, #s)
	assert(s2 == s)
end

linebuffer_fuzz_test()
