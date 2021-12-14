local ffi = require 'ffi'

ffi.cdef[[
void *malloc(size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
]]

local function malloc(size)
      return ffi.C.malloc(size)
end
local function realloc(ptr, size)
      return ffi.C.realloc(ptr, size)
end

local function free(ptr)
      ffi.C.free(ptr)
end

return {
      malloc = malloc,
      realloc = realloc,
      free = free
}