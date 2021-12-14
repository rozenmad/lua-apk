--[[
-------------------------------------------------------------------------------
	Menori
	@author rozenmad
	2021
-------------------------------------------------------------------------------
--]]

local new_class
new_class = function(class_name, base_class)
	local __mt = {
		__tostring = function(self)
			return string.format('%p instance of "%s"', self, self.class_name)
		end,
	}
      local class = {
            super = base_class,
            class_name = class_name,
            extend = function (self, _class_name)
                  return new_class(_class_name, self)
            end,
		include = function (self, other)
			for k, v in pairs(other) do
				if self[k] == nil then self[k] = v end
			end
		end,
            __index = base_class,
		__call = function (self, ...)
			local t = setmetatable({}, self.__mt)
			if self.init then self.init(t, ...) end
			return t
		end,
		__mt = __mt,
      }
	__mt.__index = class
      return setmetatable(class, class)
end

return new_class