--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

local ffi = require 'ffi'
local byteswap = require 'byteswap'
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

function binarywriter:write_ubyte(value)
      local t = types.ubyte
      self.stream:pack(self.position, 1, value, t)
      self.position = self.position + 1
end

function binarywriter:write_int16(value)
      local t = types.int16
      if not self.is_little_endian then
            byteswap.union.i16 = value
            value = byteswap.int16(byteswap.union, t)
      end
      self.stream:pack(self.position, 2, value, t)
      self.position = self.position + 2
end

function binarywriter:write_int32(value)
      local t = types.int32
      if not self.is_little_endian then
            byteswap.union.i32 = value
            value = byteswap.int32(byteswap.union, t)
      end
      self.stream:pack(self.position, 4, value, t)
      self.position = self.position + 4
end

function binarywriter:write_int64(value)
      local t = types.int64
      if not self.is_little_endian then
            byteswap.union.i64 = value
            value = byteswap.int64(byteswap.union, t)
      end
      self.stream:pack(self.position, 8, value, t)
      self.position = self.position + 8
end

function binarywriter:write_int32_array(array)
      for i, v in ipairs(array) do
            self:write_int32(v)
      end
end

function binarywriter:write_bytes(bytearray)
      for i, v in ipairs(bytearray) do
            self:write_ubyte(v)
      end
end

function binarywriter:fill(size, value)
      for i = 1, size do
            self:write_ubyte(value)
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