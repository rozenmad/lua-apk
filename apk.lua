--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

local class = require 'libs.class'
local lfs = require 'lfs'

local ffi = require 'ffi'
ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen, const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *source, unsigned long sourceLen);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib" or "z")
local zlib_buffer
local zlib_buffer_size = 0

local function compress(txt)
      local n = zlib.compressBound(#txt)
      local buf = ffi.new("uint8_t[?]", n)
      local buflen = ffi.new("unsigned long[1]", n)
      local res = zlib.compress2(buf, buflen, txt, #txt, 9)
      assert(res == 0)
      return ffi.string(buf, buflen[0])
end

local function uncompress(ptr, n)
      if zlib_buffer_size < n then
            zlib_buffer_size = n
            zlib_buffer = ffi.new("uint8_t[?]", n)
      end
      local buflen = ffi.new("unsigned long[1]", n)
      local res = zlib.uncompress(zlib_buffer, buflen, ptr, n)
      assert(res == 0)
      return ffi.string(zlib_buffer, buflen[0])
end

local apk = class('APK')

local endiltle = class('ENDILTLE')
function endiltle:init(br)
      br.is_little_endian = true
      self.zero_bytes = br:read_bytes(8)
end

local endibige = class('ENDIBIGE')
function endibige:init(br)
      br.is_little_endian = false
      self.zero_bytes = br:read_bytes(8)
end

local packhedr = class('PACKHEDR')
function packhedr:init(br)
      self.header_size = br:read_int64()
      self.u1 = br:read_int32()
      self.u2 = br:read_int32()
      self.u3 = br:read_int32()
      self.u4 = br:read_int32()
      self.bytes = br:read_bytes(16)
end

local packtoc_ = class('PACKTOC_')
function packtoc_:init(br)
      self.section_size = tonumber(br:read_int64())
      local p = br.position
      self.block_size = br:read_int32()
      self.files = br:read_int32()
      self.align = br:read_int32()
      self.u1 = br:read_int32()

      for i = 1, self.files do
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
            br:read_int32()
      end

      br.position = p + self.section_size
end

local packfsls = class('PACKFSLS')
function packfsls:init(br)
      self.section_size = tonumber(br:read_int64())
      local p = br.position
      self.count = br:read_int32()
      self.block_size = br:read_int32()
      self.align = br:read_int32()
      self.unknown1 = br:read_int32()

      self.items = {}
      for i = 1, self.count do
            local index = tonumber(br:read_int64())
            local file_offset = tonumber(br:read_int64())
            local size = tonumber(br:read_int64())
            local uarr = br:read_bytes(16)

            table.insert(self.items, {
                  index = index,
                  apkfile = apk(br:new_from_position(file_offset)),
                  uarr = uarr,
            })
      end

      br.position = p + self.section_size
end

local packfshd = class('PACKFSHD')
function packfshd:init(br)
      self.section_size = tonumber(br:read_int64())
      local p = br.position
      self.zero = br:read_int32()
      self.block_size = br:read_int32()
      self.count = br:read_int32()
      self.unknown1 = br:read_int32()

      self.u1 = br:read_int32()
      self.u2 = br:read_int32()
      self.u3 = br:read_int32()
      self.u4 = br:read_int32()

      self.items = {}
      for i = 1, self.count do
            table.insert(self.items, {
                  index = br:read_int32(),
                  unknown = br:read_int32(),
                  file_offset = tonumber(br:read_int64()),
                  unpacked_size = tonumber(br:read_int64()),
                  size = tonumber(br:read_int64()),
            })
      end

      br.position = p + self.section_size
end

local genestrt = class('GENESTRT')
function genestrt:init(br)
      self.section_size = tonumber(br:read_int64())
      local p = br.position
      self.count = br:read_int32()
      self.align = br:read_int32()
      self.name_table_offset_size = br:read_int32()
      self.name_table_size = br:read_int32()

      self.names = {}
      for i = 1, self.count do
            local start_position = br:read_int32()
            local prev = br.position
            br.position = p + self.name_table_offset_size + start_position
            table.insert(self.names, br:read_string())
            br.position = prev
      end
      br.position = p + self.section_size
end

local sections = {
      ENDILTLE = endiltle,
      PACKHEDR = packhedr,
      ['PACKTOC '] = packtoc_,
      PACKFSLS = packfsls,
      PACKFSHD = packfshd,
      GENESTRT = genestrt,
}

function apk:init(br)
      self.binaryreader = br
      self.sections = {}

      while not self.binaryreader:is_eof() do
            local section_name = self.binaryreader:read_string(8)
            --print(section_name)
            local section = sections[section_name]
            if section then
                  self.sections[section_name] = section(self.binaryreader)
            else
                  break
            end
      end
end

function apk:unpack_all(path)
      lfs.mkdir(path)
      local sectionfsls = self.sections['PACKFSLS']
      local sectionfshd = self.sections['PACKFSHD']
      local names = self.sections['GENESTRT'].names

      if sectionfsls then
            for _, item in ipairs(sectionfsls.items) do
                  local archive_path = names[item.index + 1]
                  item.apkfile:unpack_all(path .. '/' .. archive_path)
            end
      end
      if sectionfshd then
            for _, item in ipairs(sectionfshd.items) do
                  local folder_path = path
                  local pathname = names[item.index + 1]
                  print('Unpack: ', pathname)
                  for path in pathname:gmatch("([%w%d_]+)/") do
                        folder_path = folder_path  .. '/' .. path
                        lfs.mkdir(folder_path)
                  end
                  local file = io.open(path .. '/' .. pathname, 'wb')
                  local size = item.size
                  if size > 0 then
                        local offset = item.file_offset
                        local unpacked_size = item.unpacked_size
                        local data = self.binaryreader:read_raw_bytes(offset, size)
                        local new_filedata = uncompress(data, unpacked_size)
                        file:write(new_filedata)
                  end
                  file:close()
            end
      end
end

return apk