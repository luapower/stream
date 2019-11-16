local stream = require'stream'
local ffi = require'ffi'

local s = [[
hello world
wazaa
]]

local term = s:match'\r?\n'

local read = stream.memreader(s)
local read = stream.readtobuffer(read)
local lb = stream.linebuffer(read, term, 8192)

while true do
	local s, err = lb.readline()
	if not s then break end
	print(s)
end
