--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

local ffi = require 'ffi'
local Stream = require 'stream'

local binaryreader = {}
binaryreader.__index = binaryreader

local types = {
      ubyte = 'uint8_t*',
      int16 = 'int16_t*',
      int32 = 'int32_t*',
      int64 = 'int64_t*',
      float = 'float*',
}

local function new(data, size)
      local stream
      if type(data) == 'table' and data.class_name == 'STDIOFILE' then
            stream = Stream.f_stream(data)
      else
            stream = Stream.m_stream(data, size)
      end
      return setmetatable({ position = 0, stream = stream }, binaryreader)
end

function binaryreader:ffi_pointer()
      assert(false)
      return self.c_str + self.position
end

function binaryreader:alignment(align)
      self.position = math.ceil(self.position / align) * align
end

function binaryreader:read_byte()
      local t = types.ubyte
      local value = self.stream:unpack(self.position, t)
      self.position = self.position + 1
      return value
end

function binaryreader:read_int64()
      local t = types.int64
      local value = self.stream:unpack(self.position, t)
      self.position = self.position + 8
      return value
end

function binaryreader:read_int32()
      local t = types.int32
      local value = self.stream:unpack(self.position, t)
      self.position = self.position + 4
      return value
end

function binaryreader:read_int16()
      local t = types.int16
      local value = self.stream:unpack(self.position, t)
      self.position = self.position + 2
      return value
end

function binaryreader:read_int32_array(count)
      local array = {}
      for i = 1, count do
            array[i] = self:read_int32()
      end
      return array
end

function binaryreader:read_bytes(count)
      local bytes = {}
      assert(self.position + count <= self.stream.size, 'read_bytes out of range')
      for i = 1, count do
            table.insert(bytes, self:read_byte())
      end
      return bytes
end

function binaryreader:read_string(count)
      if count then
            assert(self.position + count <= self.stream.size, 'read_ascii_string out of range')
            local s = self.stream:read_data(self.position, count)
            self.position = self.position + count
            return ffi.string(s, count)
      else
            local bytes = {}
            while not self:is_eof() do
                  local value = self:read_byte()
                  if value == 0 then
                        break
                  end
                  table.insert(bytes, value)
            end
            local count = #bytes
            local s = ffi.new("uint8_t[?]", count)
            for i, v in ipairs(bytes) do
                  s[i - 1] = v
            end
            return ffi.string(s, count)
      end
end

function binaryreader:read_raw_bytes(offset, size)
      return self.stream:read_data(offset, size)
end

function binaryreader:size()
      return self.stream.size
end

function binaryreader:is_eof()
      return self.position >= self.stream.size
end

return {
      new = new,
}