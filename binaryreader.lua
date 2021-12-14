local ffi = require 'ffi'

local binaryreader = {}
binaryreader.__index = binaryreader

local function from_string(str)
      local size = #str
      local c_str = ffi.new("uint8_t[?]", size+1, 0)
      ffi.copy(c_str, str)
      return setmetatable({ c_str = c_str, position = 0, size = size }, binaryreader)
end

local function from_bytearray(array)
      local size = #array
      local c_str = ffi.new("uint8_t[?]", size+1, 0)
      for i, v in ipairs(array) do
            c_str[i - 1] = v
      end
      return setmetatable({ c_str = c_str, position = 0, size = size }, binaryreader)
end

local function new(data)
      if type(data) == 'string' then
            return from_string(data)
      end
      return from_bytearray(data)
end

function binaryreader:ffi_pointer()
      return self.c_str + self.position
end

function binaryreader:alignment(align)
      self.position = math.ceil(self.position / align) * align
end

function binaryreader:read_byte()
	local byte = (self.c_str + self.position)[0]
      self.position = self.position + 1
      return byte
end

function binaryreader:read_byte_array(count)
      local array = {}
      for i = 1, count do
            array[i] = self:read_byte()
      end
      return array
end

function binaryreader:read_int64()
      local t = 'long long*'
	local value = ffi.cast(t, self.c_str + self.position)[0]
      self.position = self.position + 8
      return value
end
function binaryreader:read_int32()
      local t = 'long*'
	local value = ffi.cast(t, self.c_str + self.position)[0]
      self.position = self.position + 4
      return value
end
function binaryreader:read_int16()
      local t = 'short*'
	local value = ffi.cast(t, self.c_str + self.position)[0]
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
      assert(self.position + count <= self.size, 'read_bytes out of range')
      for i = self.position, self.position + count - 1 do
            table.insert(bytes, self.c_str[i])
      end
      self.position = self.position + count
      return bytes
end

--[[
function binaryreader:read_bytes_str(count)
      local new_c_str = ffi.new("char[?]", count+1, 0)
      assert(self.position + count <= self.size, 'read_bytes out of range')
      ffi.copy(new_c_str, self.c_str + self.position, count)
      self.position = self.position + count
      return ffi.string(new_c_str, count)
end]]

function binaryreader:read_bytes_str(count)
      assert(self.position + count <= self.size, 'read_bytes out of range')
      local s = ffi.string(self.c_str + self.position, count)
      self.position = self.position + count
      return s
end

function binaryreader:read_ascii_string(count)
      local bytes = {}
      count = count or (self.size - self.position)
      assert(self.position + count <= self.size, 'read_ascii_string out of range')
      for i = self.position, self.position + count - 1 do
            if self.c_str[i] == 0 then
                  break
            end
            table.insert(bytes, string.char(self.c_str[i]))
      end
      self.position = self.position + count
      return table.concat(bytes)
end

function binaryreader:read_utf8_string(count)
      assert(self.position + count <= self.size, 'read_ascii_string out of range')

      local bytes = {}
      for i = self.position, self.position + count - 1 do
            if self.c_str[i] == 0 then
                  break
            end
            table.insert(bytes, self.c_str[i])
      end
      local c_str = ffi.new("char[?]", #bytes + 1)
      for i, v in ipairs(bytes) do
            c_str[i - 1] = v
      end

      self.position = self.position + count
      return ffi.string(c_str)
end

function binaryreader:is_eof()
      return self.position >= self.size
end

function binaryreader:to_string()
      return ffi.string(self.c_str, self.size - 1)
end

return {
      new = new,
}