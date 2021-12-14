local ffi = require 'ffi'

local binarywriter = {}
binarywriter.__index = binarywriter

local sizeof_int32 = ffi.sizeof('int')

local function new(size)
      local c_str = ffi.new("char[?]", size)
      return setmetatable({ c_str = c_str, position = 0, capacity = size }, binarywriter)
end

function binarywriter:check_capacity(size)
      if self.position + size > self.capacity then
            local old_capacity = self.capacity
            local new_capacity = self.position + size
            self.capacity = new_capacity + (new_capacity / 2)
            local new_c_str = ffi.new("char[?]", self.capacity)
            ffi.copy(new_c_str, self.c_str, old_capacity)
            self.c_str = new_c_str
      end
end

function binarywriter:write_int32(value)
      self:check_capacity(sizeof_int32)
      local int32_pointer = ffi.cast('int*', self.c_str + self.position)
      int32_pointer[0] = value
      self.position = self.position + sizeof_int32
end

function binarywriter:write_int32_array(array)
      for i, v in ipairs(array) do
            self:write_int32(v)
      end
end

function binarywriter:write_bytes(bytearray)
      self:check_capacity(#bytearray)
      for i, v in ipairs(bytearray) do
            self.c_str[self.position] = v
            self.position = self.position + 1
      end
end

function binarywriter:fill(size, value)
      self:check_capacity(size)
      for i = 1, size do
            self.c_str[self.position] = value
            self.position = self.position + 1
      end
end

function binarywriter:write_string(s, size)
      size = size or #s
      self:check_capacity(size)
      local c_str = ffi.new("char[?]", size + 1)
      ffi.copy(c_str, s)
      for i = 0, size - 1 do
            self.c_str[self.position] = c_str[i]
            self.position = self.position + 1
      end
end

function binarywriter:to_string()
      return ffi.string(self.c_str, self.position)
end

function binarywriter:to_bytearray()
      local array = {}
      for i = 1, self.position do
            array[i] = self.c_str[i - 1]
      end
      return array
end

return {
      new = new,
}