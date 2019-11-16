local stream = require'stream'
local ffi = require'ffi'

local s = [[
hello world
wazaa
]]

local crlf = s:find'\r\n' and true or false

local read = stream.mem_reader(s)
local write, flush = stream.dynarray_writer()
local readline = stream.line_reader(read, write, crlf)

while true do
	local ok, err = readline()
	if not ok then break end
	local s = ffi.string(flush())
	print(s)
end
