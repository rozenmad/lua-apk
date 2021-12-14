--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

local ffi = require 'ffi'
local Stream = require 'stream'

local binarywriter = {}
binarywriter.__index = binarywriter

local types = {
      ubyte = 'uint8_t*',
      int16 = 'int16_t*',
      int32 = 'int32_t*',
      int64 = 'int64_t*',
      float = 'float*',
}

local types_size = {
      ubyte = ffi.sizeof('uint8_t'),
      int16 = ffi.sizeof('int16_t'),
      int32 = ffi.sizeof('int32_t'),
      int64 = ffi.sizeof('int64_t'),
      float = ffi.sizeof('float'),
}

local function from_file(file)
      local stream
      if type(file) == 'table' and file.class_name == 'STDIOFILE' then
            stream = Stream.f_stream(file)
      end
      return setmetatable({ position = 0, stream = stream }, binarywriter)
end

local function from_data(data)
      local stream
      if data then
            stream = Stream.m_stream(data, #data)
      else
            stream = Stream.m_stream('')
      end
      return setmetatable({ position = 0, stream = stream }, binarywriter)
end

function binarywriter:write_byte(value)
      local t = types.byte
      local t_size = types_size.byte
      self.stream.pack(self.position, t_size, value, t)
      self.position = self.position + t_size
end

function binarywriter:write_int16(value)
      local t = types.int16
      local t_size = types_size.int16
      self.stream:pack(self.position, t_size, value, t)
      self.position = self.position + t_size
end

function binarywriter:write_int32(value)
      local t = types.int32
      local t_size = types_size.int32
      self.stream:pack(self.position, t_size, value, t)
      self.position = self.position + t_size
end

function binarywriter:write_int64(value)
      local t = types.int64
      local t_size = types_size.int64
      self.stream:pack(self.position, t_size, value, t)
      self.position = self.position + t_size
end

function binarywriter:write_int32_array(array)
      for i, v in ipairs(array) do
            self:write_int32(v)
      end
end

function binarywriter:write_bytes(bytearray)
      for i, v in ipairs(bytearray) do
            self:write_byte(v)
      end
end

function binarywriter:fill(size, value)
      for i = 1, size do
            self:write_byte(value)
            self.position = self.position + 1
      end
end

function binarywriter:write_string(s)
      local size = #s
      local c_str = ffi.new("uint8_t[?]", size + 1)
      ffi.copy(c_str, s, size)
      self.stream:write_data(self.position, size + 1, c_str)
      self.position = self.position + size + 1
end

return {
      from_file = from_file,
      from_data = from_data,
}