local function alignment(size, align)
      return math.floor((size + (align - 1)) / align) * align - size
end

return {
      alignment = alignment
}