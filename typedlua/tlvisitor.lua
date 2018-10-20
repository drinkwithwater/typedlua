--[[
This module implements a faster visitor for the Typed Lua AST.
--!cz
]]

local tlvisitor = {}

local visit_node
local visit_block, visit_stm, visit_exp, visit_var, visit_type, visit_list, visit_field
local visit_explist, visit_varlist, visit_parlist

local function visit_tag(visit_dict, visitor, t)
  if visitor.stop then
	  return
  end
  local tag = t.tag
  local stack = visitor.stack
  local index = #stack + 1
  stack[index] = t
  local before = visitor.before[tag]
  local override = visitor.override[tag]
  local after = visitor.after[tag]
  if before then
	  before(visitor, t)
  end
  if override then
	  local self_visit = visit_node[tag]
	  override(visitor, t, visit_node, self_visit)
  else
	  local middle = visit_dict[tag]
	  if middle then
		  middle(visitor, t)
	  end
  end
  if after then
	  after(visitor, t)
  end
  stack[index] = nil
end

visit_type = setmetatable({
	TLiteral = false,
	TBase = false,
	TNil = false,
	TValue = false,
	TAny = false,
	TSelf = false,
	TVoid = false,
	TUnion = function(visitor, node)
		for _, v in ipairs(node) do
			visit_type(visitor, v)
		end
	end,
	TUnionlist = function(visitor, node)
		for _, v in ipairs(node) do
			visit_type(visitor, v)
		end
	end,
	TFunction = function(visitor, node)
		visit_type(visitor, node[1])
		visit_type(visitor, node[2])
	end,
	TField = function(visitor, node)
		visit_type(visitor, node[1])
		visit_type(visitor, node[2])
	end,
	TTable = function(visitor, node)
		for _, v in ipairs(node) do
			visit_type(visitor, v)
		end
    end,
	TVariable = false,
	TGlobalVariable = false,
	TRecursive = function(visitor, node)
		visit_type(visitor, node[2])
	end,
	TTuple = function(visitor, node)
		for _, v in ipairs(node) do
			visit_type(visitor, v)
		end
	end,
	TVararg = function(visitor, node)
		visit_type(visitor, node[1])
	end
}, {
	__call=visit_tag,
	__index=function(t, tag)
		error("expecting a type, but got a " .. tag)
	end
})

visit_var = setmetatable({
	Id = false,
	Index = function(visitor, node)
		visit_exp(visitor, node[1])
		visit_exp(visitor, node[2])
	end,
	Dots = false,
}, {
	__call=visit_tag,
	__index=function(t, tag)
		error("expecting a variable, but got a " .. tag)
	end
})

function visit_varlist (visitor, varlist)
  for k, v in ipairs(varlist) do
    visit_var(visitor, v)
  end
end

function visit_parlist (visitor, parlist)
  local len = #parlist
  for i=1, len do
	  visit_var(visitor, parlist[i])
  end
end


visit_exp = setmetatable({
	Nil=false,
	Dots=false,
	True=false,
	False=false,
	Number=false,
	String=false,

	Function = function(visitor, func)
		visit_list(visitor, func[1])
		if func[3] then
			visit_type(visitor, func[2])
			visit_block(visitor, func[3])
		else
			visit_block(visitor, func[2])
		end
	end,
	Table = function(visitor, fieldlist)
		for k, v in ipairs(fieldlist) do
			visit_field(visitor, v)
		end
	end,
	Op = function(visitor, exp)
		-- opid: exp[1]
		visit_exp(visitor, exp[2])
		if exp[3] then
			visit_exp(visitor, exp[3])
		end
	end,
	Paren = function(visitor, exp)
		visit_exp(visitor, exp[1])
	end,
	Call = function(visitor, exp)
		visit_exp(visitor, exp[1])
		if exp[2] then
			for i=2, #exp do
				visit_exp(visitor, exp[i])
			end
		end
	end,
	Invoke = function(visitor, exp)
		visit_exp(visitor, exp[1])
		visit_exp(visitor, exp[2])
		if exp[3] then
			for i=3, #exp do
				visit_exp(visitor, exp[i])
			end
		end
	end,
	Id = visit_var,
	Index = visit_var,
}, {
	__call=visit_tag,
	__index=function(t, tag)
		error("expecting a expression, but got a " .. tag)
	end
})

function visit_explist (visitor, explist)
  for k, v in ipairs(explist) do
	visit_exp(visitor, v)
  end
end

visit_stm = setmetatable({
	Do=function(visitor, stm)
		visit_block(visitor, stm)
	end,
	Set=function(visitor, stm)
		visit_list(visitor, stm[1])
		visit_list(visitor, stm[2])
	end,
	While=function(visitor, stm)
		visit_exp(visitor, stm[1])
		visit_block(visitor, stm[2])
	end,
	Repeat=function(visitor, stm)
		visit_block(visitor, stm[1])
		visit_exp(visitor, stm[2])
	end,
	If=function(visitor, stm)
		local len = #stm
		if len % 2 == 0 then
			for i=1,len-2,2 do
				visit_exp(visitor, stm[i])
				visit_block(visitor, stm[i+1])
			end
			visit_exp(visitor, stm[len-1])
			visit_block(visitor, stm[len])
		else
			for i=1,len-3,2 do
				visit_exp(visitor, stm[i])
				visit_block(visitor, stm[i+1])
			end
			visit_exp(visitor, stm[len-2])
			visit_block(visitor, stm[len-1])
			visit_block(visitor, stm[len])
		end
	end,
	Fornum=function(visitor, stm)
		visit_var(visitor, stm[1])
		visit_exp(visitor, stm[2])
		visit_exp(visitor, stm[3])
		if stm[5] then
			visit_exp(visitor, stm[4])
			visit_block(visitor, stm[5])
		else
			visit_block(visitor, stm[4])
		end
	end,
	Forin=function(visitor, stm)
		visit_list(visitor, stm[1])
		visit_list(visitor, stm[2])
		visit_block(visitor, stm[3])
	end,
	Local=function(visitor, stm)
		visit_list(visitor, stm[1])
		if #stm[2] > 0 then
			visit_list(visitor, stm[2])
		end
	end,
	Localrec=function(visitor, stm)
		visit_list(visitor, stm[1])
		visit_list(visitor, stm[2])
	end,
	Goto=false,
	Label=false,
	Return=function(visitor, stm)
		visit_list(visitor, stm)
	end,
	Break=false,
	Call=function(visitor, stm)
		visit_exp(visitor, stm[1])
		if stm[2] then
			for i=2, #stm do
				visit_exp(visitor, stm[i])
			end
		end
	end,
	Invoke=function(visitor, stm)
		visit_exp(visitor, stm[1])
		visit_exp(visitor, stm[2])
		if stm[3] then
			for i=3, #stm do
				visit_exp(visitor, stm[i])
			end
		end
	end,
	Interface=function(visitor, stm)
		-- TODO? stm[1]
		visit_type(visitor, stm[2])
	end,
}, {
	__call=visit_tag,
	__index=function(t, tag)
		error("expecting a statement, but got a " .. tag)
	end
})

visit_block = setmetatable({
	Block=function(visitor, block)
	  for k, v in ipairs(block) do
		  visit_stm(visitor, v)
	  end
	end,
	Do=function(visitor, block)
	  for k, v in ipairs(block) do
		  visit_stm(visitor, v)
	  end
	end,
}, {
	__call=visit_tag,
	__index=function(t, tag)
		error("expecting a block or do, but got a " .. tag)
	end
})

local function setDefaultVistior(visitor)
	visitor.before = visitor.before or {}
	visitor.after = visitor.after or {}
	visitor.override = visitor.override or {}
	visitor.stack = visitor.stack or {}
	visitor.stop = false
end

visit_list = setmetatable({
	ExpList=visit_explist,
	Return=visit_explist,
	ParList=visit_parlist,
	VarList=visit_varlist,
	NameList=visit_varlist,
}, {
	__call=visit_tag,
	__index=function(t, tag)
	end
})

visit_field = setmetatable({
	Pair=function(visitor, node)
		visit_exp(visitor, node[1])
		visit_exp(visitor, node[2])
	end
},{
	__call=visit_tag,
	__index=function(t, tag)
		return visit_exp[tag]
	end
})


local sub_visitor_list = {
	visit_block,
	visit_stm,
	visit_exp,
	visit_var,
	visit_type,
	visit_list,
	visit_field,
}

visit_node = setmetatable({},{
	__call=visit_tag,
	__index=function(t, tag)
		error("expecting a valid tag, but got a " .. tag)
	end
})


for _, sub_visitor in ipairs(sub_visitor_list) do
	for tag, func in pairs(sub_visitor) do
		visit_node[tag] = func
	end
end

function tlvisitor.visit_node(node, visitor)
	visit_node(visitor, node)
end

function tlvisitor.visit(block, visitor)
	setDefaultVistior(visitor)
	visit_block(visitor, block)
end

function tlvisitor.visit_type(node, visitor)
	setDefaultVistior(visitor)
	visit_type(visitor, node)
end

function tlvisitor.concat(...)
	local nDict = {}
	for i=1, select("#", ...) do
		local t = select(i, ...)
		for k,v in pairs(t) do
			if nDict[k] then
				error("visitor concat duplicate")
			end
			nDict[k] = v
		end
	end
	return nDict
end

return tlvisitor
