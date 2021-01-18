
local tltRuntime = {}

function tltRuntime:dosth()
end

function tltRuntime.new()
	return setmetatable({
		type_set={},
		name_template_type={},
		ast_template_type={},
		term2type={},
	}, {
		__index=tltRuntime
	})
end

return tltRuntime
