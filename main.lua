local lfs = require 'lfs'
local apk = require 'apk'
local stdio = require 'stdio'
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
      return self.path .. self.name .. self.ext
end

function file_utils:get_filename()
      return self.name .. self.ext
end

local function get_files(path)
      local t1 = {}
      for name, i in lfs.dir(path) do
            if name ~= '.' and name ~= '..' then
                  local f = lfs.attributes(path .. name)
                  if f.mode == 'file' then
                        local n, ext = name:match("^(.+)(%..+)$")
                        local o = setmetatable({
                              name = n,
                              ext = ext,
                              path = path,
                              modification = f.modification,
                        }, file_utils)
                        table.insert(t1, o)
                  end
            end
      end
      return t1
end

local function table_concat(t1, t2)
	for i	= 1,#t2 do
	    t1[#t1+1] = t2[i]
	end
	return t1
end

local function get_files_folder_recursive(path, relative_path)
	relative_path = relative_path or ''
	local t1 = {}
	path = path .. '/'

	for name, i in lfs.dir(path) do
		if name ~= '.' and name ~= '..' then
			local f = lfs.attributes(path .. name)
			if f.mode == 'directory' then
				local t2 = get_files_folder_recursive(path .. name, relative_path .. name .. '/')
				table_concat(t1, t2)
			elseif f.mode == 'file' then
				local n, ext = name:match("^(.+)(%..+)$")
				local o = setmetatable({
					name = n,
					ext = ext,
					path = path,
					relative_path = relative_path,
					modification = f.modification,
				}, file_utils)
				table.insert(t1, o)
			end
		end
	end
	return t1
end

local function read_apk()
      local repack_files = get_files_folder_recursive('repack')
      local repack_list = {}
      for i, v in ipairs(repack_files) do
            local correct_name = v.relative_path:match('.+(data/.+)')
            table.insert(repack_list, {
                  name = correct_name .. v.name .. v.ext,
                  fullpath_filename = v:get_fullpath_filename(),
            })
            print(correct_name .. v.name .. v.ext)
      end

      local t1 = os.time()
      local files = get_files('data/')

      local cmd = arg[1]
      for i, v in ipairs(files) do
            local f = stdio.open(v:get_fullpath_filename(), 'rb')
            local br = BinaryReader.new(f)
            local apk = apk(br)
            if cmd == 'unpack' then
                  apk:unpack_all('unpacked_' .. v.name)
            elseif cmd == 'repack' then
                  local bw = BinaryWriter.from_file(stdio.open('new_data.apk', 'wb'))
                  apk:repack(bw, repack_list)
            end
            f:close()
      end
      print('Time: ', (os.time() - t1) / 60)
end

read_apk()