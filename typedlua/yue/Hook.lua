
local Hook = {}

-->> (TRuntime)->(THook)
function Hook.new(vRuntime)
	local self = setmetatable({
		mRuntime=vRuntime,
	}, {
		__index=Hook,
	})
	return self
end

function Hook:table_new(vValue)
	return vValue
end

function Hook:symbol_init(vSymbolTable, vName, vValue)
	vSymbolTable[vName] = vValue
end

function Hook:symbol_get(vSymbolTable, vName)
	return vSymbolTable[vName]
end

function Hook:symbol_set(vSymbolTable, vName, vValue)
	vSymbolTable[vName] = vValue
end

function Hook:meta_get(vItem, vName)
	return vItem[vName]
end

function Hook:meta_set(vItem, vName, vValue)
	vItem[vName] = vValue
end

function Hook:meta_call(vItem, ...)
	return vItem(...)
end

function Hook:meta_invoke(vItem, vName, ...)
	local nFunc = self:meta_get(vItem, vName)
	return self:meta_call(nFunc, vItem, ...)
end

function Hook:meta_bop(vOper, vLeftItem, vRightItem)
	if vOper == "add" then
		return vLeftItem + vRightItem
	elseif vOper == "sub" then
		return vLeftItem - vRightItem
	elseif vOper == "mod" then
		return vLeftItem % vRightItem
	elseif vOper == "eq" then
		return vLeftItem == vRightItem
	else
		error("TODO")
	end
end

function Hook:meta_uop(vOper, vItem)
	if vOper == "-" then
		return - vItem
	elseif vOper == "~" then
		return ~ vItem
	elseif vOper == "#" then
		return # vItem
	else
		error("invalid oper")
	end
end

function Hook:func_return(...)
	return ...
end

function Hook:func_define()
	error("func_define TODO")
end

function Hook:logic_or(vLeftItem, vRightItem)
	return vLeftItem or vRightItem
end

function Hook:logic_and(vLeftItem, vRightItem)
	return vLeftItem and vRightItem
end

function Hook:logic_not(vItem)
	return not vItem
end

return Hook
