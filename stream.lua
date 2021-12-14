local ffi = require 'ffi'
local stdlib = require 'stdlib'

local class = require 'libs.class'

local m_stream = class('M_Stream')
function m_stream:init(data, size)
      local c_str
      if type(data) == 'cdata' and size then
            self.size = size
            c_str = ffi.cast("uint8_t*", data)
      else
            local size = #data
            local memblock = stdlib.malloc(size)
            c_str = ffi.cast("uint8_t*", memblock)
            ffi.fill(c_str, size, 0)

            if type(data) == 'string' then
                  ffi.copy(c_str, data, size)
            else
                  for i, v in ipairs(data) do
                        c_str[i - 1] = v
                  end
            end
            self.size = size
      end
      self.buffer = ffi.gc(c_str, stdlib.free)
end

function m_stream:check_capacity(position, size)
      if position + size > self.size then
            local old_capacity = self.size
            local new_capacity = position + size
            self.size = new_capacity + (new_capacity / 2)
            ffi.gc(self.buffer, nil)
            local new_buffer = ffi.cast('uint8_t*', stdlib.realloc(self.buffer, self.size))
            assert(new_buffer, 'realloc failed')
            self.buffer = ffi.gc(new_buffer, stdlib.free)
      end
end

function m_stream:pack(position, size, value, t)
      self:check_capacity(position, size)
      local ptr = ffi.cast(t, self.buffer + position)
      ptr[0] = value
end

function m_stream:unpack(position, t)
      return ffi.cast(t, self.buffer + position)[0]
end

function m_stream:read_data(position, size)
      local data = ffi.new('uint8_t[?]', size)
      ffi.copy(data, self.buffer + position, size)
      return data
end

function m_stream:write_data(position, size, ptr)
      self:check_capacity(position, size)
      ffi.copy(self.buffer + position, ptr, size)
      return ptr
end

local f_stream = class('F_Stream')
function f_stream:init(file)
      self.file = file
      self.size = self.file:size()

      self.buffer = ffi.new('uint8_t[?]', 8)
end

function f_stream:pack(position, size, value, t)
      local ptr = ffi.cast(t, self.buffer)
      ptr[0] = value
      self.file:seek('set', position)
      self.file:write(ptr, size)
end

function f_stream:unpack(position, t)
      self.file:seek('set', position)
      self.file:read_buffer(self.buffer, 8)
      return ffi.cast(t, self.buffer)[0]
end

function f_stream:read_data(position, size)
      local ptr = ffi.new('uint8_t[?]', size)
      self.file:seek('set', position)
      self.file:read_to_buffer(ptr, size)
      return ptr
end

function f_stream:write_data(position, size, ptr)
      self.file:seek('set', position)
      self.file:write(ptr, size)
end

return {
      m_stream = m_stream,
      f_stream = f_stream,
}