local stream = require'stream'
local ffi = require'ffi'

local s = [[
hello world
wazaa
]]

local crlf = s:find'\r\n' and true or false

local read = stream.mem_reader(s)
local write, writebuffer = stream.dynarray_writer()
local readline = stream.line_reader(read, write, crlf)

while true do
	local sz, err = readline()
	if not sz then break end
	local s = ffi.string(writebuffer(sz), sz)
	print(s)
end
