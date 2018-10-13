--[[
This module implements a faster visitor for the Typed Lua AST.
--!cz
]]

local tlvisitor = {}

local visit_block, visit_stm, visit_exp, visit_var, visit_type
local visit_explist, visit_varlist, visit_parlist, visit_fieldlist

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
  if override then
	  override(visitor, t, before, after)
  else
	  if before then
		  before(visitor, t)
	  end
	  local middle = visit_dict[tag]
	  if middle then
		  middle(visitor, t)
	  end
	  if after then
		  after(visitor, t)
	  end
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
	Index = false,
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
  local is_vararg = false
  if len > 0 and parlist[len].tag == "Dots" then
    is_vararg = true
    len = len - 1
  end
  local i = 1
  while i <= len do
    visit_var(visitor, parlist[i])
    i = i + 1
  end
  if is_vararg then
    if parlist[i][1] then
      visit_type(visitor, parlist[i][1])
    end
  end
end

function visit_fieldlist (visitor, fieldlist)
  for k, v in ipairs(fieldlist) do
    local tag = v.tag
    if tag == "Pair" then
		visit_exp(visitor, v[1])
		visit_exp(visitor, v[2])
    else -- expr
		visit_exp(visitor, v)
    end
  end
end

visit_exp = setmetatable({
	Nil=false,
	Dots=false,
	True=false,
	False=false,
	Number=false,
	String=false,

	Function = function(visitor, exp)
		visit_parlist(visitor, exp[1])
		if exp[3] then
			visit_type(visitor, exp[2])
			visit_block(visitor, exp[3])
		else
			visit_block(visitor, exp[2])
		end
	end,
	Table = visit_fieldlist,
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
		visit_varlist(visitor, stm[1])
		visit_explist(visitor, stm[2])
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
		visit_varlist(visitor, stm[1])
		visit_explist(visitor, stm[2])
		visit_block(visitor, stm[3])
	end,
	Local=function(visitor, stm)
		visit_varlist(visitor, stm[1])
		if #stm[2] > 0 then
			visit_explist(visitor, stm[2])
		end
	end,
	Localrec=function(visitor, stm)
		visit_var(visitor, stm[1][1])
		visit_exp(visitor, stm[2][1])
	end,
	Goto=false,
	Label=false,
	Return=function(visitor, stm)
		visit_explist(visitor, stm)
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

function tlvisitor.visit(block, visitor)
	setDefaultVistior(visitor)
	visit_block(visitor, block)
end

function tlvisitor.visit_type(node, visitor)
	setDefaultVistior(visitor)
	visit_type(visitor, node)
end

return tlvisitor
