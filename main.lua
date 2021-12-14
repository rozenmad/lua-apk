local lfs = require 'lfs'
local apk = require 'apk'

local BinaryReader = require 'binaryreader'
local BinaryWriter = require 'binarywriter'

local function read_file(filename)
      local file = io.open(filename, 'rb')
      local filedata = file:read('*a')
      file:close()
      return filedata
end

local file_utils = {}
file_utils.__index = file_utils
function file_utils:get_fullpath_filename()
	return self.path .. self.name .. self.format
end

function file_utils:get_filename()
	return self.name .. self.format
end

local function get_files(path)
	local t1 = {}
	for name, i in lfs.dir(path) do
		if name ~= '.' and name ~= '..' then
			local f = lfs.attributes(path .. name)
			if f.mode == 'file' then
				local n, format = name:match("^(.+)(%..+)$")
				local o = setmetatable({
					name = n,
					format = format,
					path = path,
					modification = f.modification,
				}, file_utils)
				table.insert(t1, o)
			end
		end
	end
	return t1
end

local stdio = require 'stdio'

--local f = stdio.open('test.bin', 'wb')
local bw = BinaryWriter.from_data()
bw:write_string('hello world')
bw:write_int32(1024)
bw:write_int64(2048)
local f = stdio.open('test.bin', 'wb')
f:write(bw.stream.buffer, bw.position)
f:close()
--f:close()

local function read_apk()
      local t1 = os.time()
      local files = get_files('data/')
      for i, v in ipairs(files) do
            local f = stdio.open(v:get_fullpath_filename(), 'rb')
		--local filedata = f:read()
		--local filesize = f:size()
		--print(filedata, filesize)
		--local br = BinaryReader.new(f)
            --local apk = apk(br, 'unpacked/')
      end
      print('Time: ', (os.time() - t1) / 60)
end

read_apk()