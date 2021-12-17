--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

local class = require 'libs.class'
local lfs = require 'lfs'
local common = require 'common'

local ffi = require 'ffi'
ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen, const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *source, unsigned long sourceLen);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib" or "z")
local zlib_buffer
local zlib_buffer_size = 0

local function compress(ptr, n)
      local compress_size = zlib.compressBound(n)
      local buf = ffi.new("uint8_t[?]", compress_size)
      local buflen = ffi.new("unsigned long[1]", compress_size)
      local res = zlib.compress2(buf, buflen, ptr, n, 9)
      assert(res == 0)
      return buf, buflen[0]
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

local base_section = class('BaseSection')
function base_section:init(size)
      self.section_size = size or 0
end

function base_section:get_size()
      return self.section_size + 16
end

local apk = class('APK')

local endiltle = base_section:extend('ENDILTLE')
function endiltle:init(br)
      endiltle.super.init(self)
      br.is_little_endian = true
      self.zero_bytes = br:read_bytes(8)
end

function endiltle:pack(bw)
      bw.is_little_endian = true
      bw:write_string('ENDILTLE')
      bw:write_bytes(self.zero_bytes)
end

local endibige = base_section:extend('ENDIBIGE')
function endibige:init(br)
      endibige.super.init(self)
      br.is_little_endian = false
      self.zero_bytes = br:read_bytes(8)
end

function endibige:pack(bw)
      bw.is_little_endian = false
      bw:write_string('ENDIBIGE')
      bw:write_bytes(self.zero_bytes)
end

local packhedr = base_section:extend('PACKHEDR')
function packhedr:init(br)
      packhedr.super.init(self, br:read_int64())
      self.u1 = br:read_int32()
      self.u2 = br:read_int32()
      self.data_offset = br:read_int32()
      self.u4 = br:read_int32()
      self.bytes = br:read_bytes(16)
end

function packhedr:pack(bw)
      print(self.section_size)
      bw:write_string('PACKHEDR')
      bw:write_int64(self.section_size)
      bw:write_int32(self.u1)
      bw:write_int32(self.u2)
      bw:write_int32(self.data_offset)
      bw:write_int32(self.u4)
      bw:write_bytes(self.bytes)
end

local packtoc_ = base_section:extend('PACKTOC_')
function packtoc_:init(br)
      packtoc_.super.init(self, br:read_int64())
      local p = br.position
      self.block_size = br:read_int32()
      self.files = br:read_int32()
      self.align = br:read_int32()
      self.u1 = br:read_int32()

      self.items = {}
      for i = 1, self.files do
            table.insert(self.items, br:read_bytes(40))
      end

      br.position = p + self.section_size
end

function packtoc_:pack(bw)
      bw:write_string('PACKTOC ')
      bw:write_int64(self.section_size)
      bw:write_int32(self.block_size)
      bw:write_int32(self.files)
      bw:write_int32(self.align)
      bw:write_int32(self.u1)
      for _, v in ipairs(self.items) do
            bw:write_bytes(v)
      end
      bw:alignment(self.align)
end

local stdio = require 'stdio'
local packfsls = base_section:extend('PACKFSLS')
function packfsls:init(br)
      packfsls.super.init(self, br:read_int64())
      local p = br.position
      self.count = br:read_int32()
      self.block_size = br:read_int32()
      self.align = br:read_int32()
      self.u1 = br:read_int32()

      self.items = {}
      print('FILES', self.count)
      for i = 1, self.count do
            --local f = stdio.open('test/tmp_' .. tostring(i) .. '.bin', 'wb')
            local index = tonumber(br:read_int64())
            local offset = tonumber(br:read_int64())
            local size = tonumber(br:read_int64())
            local uarr = br:read_bytes(16)

            --[[print(size, size + common.alignment(size, 0x800))
            local data = br:read_raw_bytes(offset, size + common.alignment(size, 0x800))
            f:write(data, size + common.alignment(size, 0x800))
            f:close()]]

            print('FILE: ', offset, size)
            table.insert(self.items, {
                  index = index,
                  uarr = uarr,
                  offset = offset,
                  apkfile = apk(br:new_from_position(offset)),
            })
      end

      br.position = p + self.section_size
end

function packfsls:get_correct_order()
      local t = {}
      if #self.items > 0 then
            for _, v in ipairs(self.items) do
                  table.insert(t, v)
            end
            table.sort(t, function (a, b)
                  return a.offset < b.offset
            end)
      end
      return t
end

function packfsls:pack(bw)
      bw:write_string('PACKFSLS')
      bw:write_int64(self.section_size)
      bw:write_int32(self.count)
      bw:write_int32(self.block_size)
      bw:write_int32(self.align)
      bw:write_int32(self.u1)
      for i, v in ipairs(self.items) do
            bw:write_int64(v.index)
            bw:write_int64(v.offset)
            bw:write_int64(v.size)
            bw:write_bytes(v.uarr)--{0,0,0,0 ,0,0,0,0, 0,0,0,0 ,0,0,0,0})
      end
      bw:alignment(self.align)
end

local packfshd = base_section:extend('PACKFSHD')
function packfshd:init(br)
      packfshd.super.init(self, br:read_int64())
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
                  u1 = br:read_int32(),
                  offset = tonumber(br:read_int64()),
                  unpacked_size = tonumber(br:read_int64()),
                  size = tonumber(br:read_int64()),
            })
      end

      br.position = p + self.section_size
end

function packfshd:update_table()
      if #self.items > 0 then
            local t = {}
            for _, v in ipairs(self.items) do
                  table.insert(t, v)
            end
            table.sort(t, function (a, b)
                  return a.offset < b.offset
            end)
            local offset = t[1].offset
            for _, v in ipairs(t) do
                  v.offset = offset
                  offset = offset + v.size + common.alignment(v.size, 0x10)
            end
      end
end

function packfshd:pack(bw)
      bw:write_string('PACKFSHD')
      bw:write_int64(self.section_size)

      bw:write_int32(self.zero)
      bw:write_int32(self.block_size)
      bw:write_int32(self.count)
      bw:write_int32(self.unknown1)

      bw:write_int32(self.u1)
      bw:write_int32(self.u2)
      bw:write_int32(self.u3)
      bw:write_int32(self.u4)

      for i, v in ipairs(self.items) do
            bw:write_int32(v.index)
            bw:write_int32(v.u1)
            bw:write_int64(v.offset)
            bw:write_int64(v.unpacked_size)
            bw:write_int64(v.size)
      end
      bw:alignment(0x10)
end

local genestrt = base_section:extend('GENESTRT')
function genestrt:init(br)
      genestrt.super.init(self, br:read_int64())
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

function genestrt:pack(bw)
      bw:write_string('GENESTRT')
      bw:write_int64(self.section_size)
      local block_begin_p = bw.position
      bw:write_int32(self.count)
      bw:write_int32(self.align)
      bw:write_int32(self.name_table_offset_size)
      bw:write_int32(self.name_table_size)

      local names_offset = {}
      bw.position = block_begin_p + self.name_table_offset_size
      local offset = 0
      for _, name in ipairs(self.names) do
            bw:write_string(name)
            bw:write_ubyte(0)
            table.insert(names_offset, offset)
            offset = offset + (#name + 1)
      end

      bw.position = block_begin_p + 0x10
      for _, offset in ipairs(names_offset) do
            bw:write_int32(offset)
      end
      bw.position = block_begin_p + self.name_table_size
end

local geneeof_ = base_section:extend('GENEEOF_')
function geneeof_:init(br)
      geneeof_.super.init(self)
      self.zero_bytes = br:read_bytes(8)
end

function geneeof_:pack(br)
      br:write_string('GENEEOF ')
      br:write_bytes(self.zero_bytes)
end

local sections = {
      ENDILTLE = endiltle,
      ENDIBIGE = endibige,
      PACKHEDR = packhedr,
      ['PACKTOC '] = packtoc_,
      PACKFSLS = packfsls,
      PACKFSHD = packfshd,
      GENESTRT = genestrt,
      ['GENEEOF '] = geneeof_,
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
                        local offset = item.offset
                        local unpacked_size = item.unpacked_size
                        local data = self.binaryreader:read_raw_bytes(offset, size)
                        local new_filedata = uncompress(data, unpacked_size)
                        file:write(new_filedata)
                  end
                  file:close()
            end
      end
end

local function search(list, name)
      for i, v in ipairs(list) do
            if v.name == name then
                  return v
            end
      end
end

function apk:repack(binarywriter, files)
      local bw = binarywriter:new_from_position()
      local begin_position = bw:relative_position()
      local offset = 0
      for _, v in pairs(self.sections) do
            offset = offset + v:get_size()
      end
      bw.position = tonumber(offset)
      bw:alignment(0x10)

      local packfsls = self.sections.PACKFSLS
      local packfshd = self.sections.PACKFSHD
      local end_position = 0
      if packfsls then
            local t = packfsls:get_correct_order()
            for _, item in ipairs(t) do
                  bw:alignment(0x800)
                  local bp, ep = item.apkfile:repack(bw, files)
                  bw.position = ep
                  item.offset = bp
                  item.size = ep - bp
            end
      end
      if packfshd then
            for _, item in ipairs(packfshd.items) do
                  local name = self.sections.GENESTRT.names[item.index + 1]
                  local file = search(files, name)
                  if file then
                        local f = stdio.open(file.fullpath_filename, 'rb')
                        local filedata = f:read()
                        item.unpacked_size = f:size()
                        f:close()
                        local data, size = compress(filedata, item.unpacked_size)
                        item.data = data
                        item.size = size
                        item.name = file.fullpath_filename
                  end
            end
            packfshd:update_table()
            for _, item in ipairs(packfshd.items) do
                  local size = item.size
                  local offset = item.offset
                  local data
                  if item.data then
                        print('Repack: ', item.name)
                        data = item.data
                  else
                        data = self.binaryreader:read_raw_bytes(offset, size)
                  end
                  bw:write_raw_bytes(data, item.size)
                  bw:fill(common.alignment(item.size, 0x10), 0)
            end
            end_position = bw:relative_position()
      end

      local t = {
            self.sections.ENDILTLE,
            self.sections.ENDIBIGE,
            self.sections.PACKHEDR,
            self.sections['PACKTOC '],
            self.sections.PACKFSLS,
            self.sections.PACKFSHD,
            self.sections.GENESTRT,
            self.sections['GENEEOF '],
      }
      bw.position = 0
      for i = 1, 8 do
            local section = t[i]
            if section and section.pack then section:pack(bw) end
      end

      return begin_position, end_position
end

return apk