
local Hook = require "typedlua.yue.Hook"
local Runtime = {}

function Runtime.new()
	local self = setmetatable({
		mHook=nil,
	}, {
		__index=Runtime,
	})
	self.mHook = Hook.new(self)
	return self
end

return Runtime
