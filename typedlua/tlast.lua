--[[
This module implements Typed Lua AST.
This AST extends the AST format implemented by Metalua.
For more information about Metalua, please, visit:
https://github.com/fab13n/metalua-parser

block: { stat* }

stat:
  `Do{ stat* }
  | `Set{ {lhs+} {expr+} }                    -- lhs1, lhs2... = e1, e2...
  | `While{ expr block }                      -- while e do b end
  | `Repeat{ block expr }                     -- repeat b until e
  | `If{ (expr block)+ block? }               -- if e1 then b1 [elseif e2 then b2] ... [else bn] end
  | `Fornum{ ident expr expr expr? block }    -- for ident = e, e[, e] do b end
  | `Forin{ {ident+} {expr+} block }          -- for i1, i2... in e1, e2... do b end
  | `Local{ {ident+} {expr+}? }               -- local i1, i2... = e1, e2...
  | `Localrec{ ident expr }                   -- only used for 'local function'
  | `Goto{ <string> }                         -- goto str
  | `Label{ <string> }                        -- ::str::
  | `Return{ <expr*> }                        -- return e1, e2...
  | `Break                                    -- break
  | apply
  | `Interface{ <string> type }

expr:
  `Nil
  | `Dots
  | `True
  | `False
  | `Number{ <number> }
  | `String{ <string> }
  | `Function{ { ident* { `Dots type? }? } typelist? block }
  | `Table{ ( `Pair{ expr expr } | expr )* }
  | `Op{ opid expr expr? }
  | `Paren{ expr }       -- significant to cut multiple values returns
  | apply
  | lhs

apply:
  `Call{ expr expr* }
  | `Invoke{ expr `String{ <string> } expr* }

lhs: ident | `Index{ expr expr }

ident: `Id{ <string> type? }

opid: 'add' | 'sub' | 'mul' | 'div' | 'idiv' | 'mod' | 'pow' | 'concat'
  | 'band' | 'bor' | 'bxor' | 'shl' | 'shr' | 'eq' | 'lt' | 'le'
  | 'and' | 'or' | 'not' | 'unm' | 'len' | 'bnot'

type:
  `TLiteral{ literal }
  | `TBase{ base }
  | `TNil
  | `TValue
  | `TAny
  | `TSelf
  | `TUnion{ type type type* }
  | `TFunction{ type type }
  | `TTable{ type type* }
  | `TVariable{ <string> }
  | `TRecursive{ <string> type }
  | `TVoid
  | `TUnionlist{ type type type* }
  | `TTuple{ type type* }
  | `TVararg{ type }

literal: false | true | <number> | <string>

base: 'boolean' | 'number' | 'string'

field: `TField{ <string> type }
]]

local tlast = {}

--@(integer, integer, any*)->(any)
function tlast.namelist (pos, id, ...)
  local t = { tag = "NameList", pos = pos, id, ... }
  return t
end

--@(integer, integer, any*)->(any)
function tlast.explist (pos, expr, ...)
  local t = { tag = "ExpList", pos = pos, expr, ... }
  return t
end

-- stat

--@(integer, integer, any*)->(any)
function tlast.block (pos, ...)
  return { tag = "Block", pos = pos, ... }
end

--@(any)->(any)
function tlast.chunk(block)
	block.pos = 0
	return {tag = "Chunk", pos = 0, block}
end

--@(any)->(any)
function tlast.statDo (block)
  return { tag = "Do", pos = block.pos, [1] = block}
end

--@(integer, any, any)->(any)
function tlast.statWhile (pos, expr, block)
  return { tag = "While", pos = pos, [1] = expr, [2] = block }
end

--@(integer, any, any)->(any)
function tlast.statRepeat (pos, block, expr)
  return { tag = "Repeat", pos = pos, [1] = block, [2] = expr }
end

--@(integer, any*)->(any)
function tlast.statIf (pos, ...)
  return { tag = "If", pos = pos, ... }
end

--@(integer, any*)->(any)
function tlast.statFornum (pos, ident, e1, e2, e3, block)
  local s = { tag = "Fornum", pos = pos }
  s[1] = ident
  s[2] = e1
  s[3] = e2
  s[4] = e3
  s[5] = block
  return s
end

-- statForin : (number, namelist, explist, block) -> (stat)
function tlast.statForin (pos, namelist, explist, block)
  local s = { tag = "Forin", pos = pos }
  s[1] = namelist
  s[2] = explist
  s[3] = block
  return s
end

function tlast.decoList(...)
	return {...}
end

-- statDecoAssign
function tlast.statDecoAssign(pos, decoList, stat)
	assert(stat.tag == "Local" or stat.tag == "Set" or stat.tag == "Localrec")
	local namelist = stat[1]
	if #namelist ~= #decoList then
		-- TODO throw warning...
		-- print("decorated namelist's size not equal with decolist's size")
	end
	for i, name in ipairs(namelist) do
		name.deco_type = decoList[i]
	end
	return stat
end

-- statLocal : (number, namelist, explist) -> (stat)
function tlast.statLocal (pos, namelist, explist)
  return { tag = "Local", pos = pos, [1] = namelist, [2] = explist or {tag="ExpList"}}
end

-- statLocalrec : (number, ident, expr) -> (stat)
function tlast.statLocalrec (pos, ident, expr)
  return { tag = "Localrec", pos = pos, [1] = { tag="NameList", ident }, [2] = { tag="ExpList", expr } }
end

-- statGoto : (number, string) -> (stat)
function tlast.statGoto (pos, str)
  return { tag = "Goto", pos = pos, [1] = str }
end

-- statLabel : (number, string) -> (stat)
function tlast.statLabel (pos, str)
  return { tag = "Label", pos = pos, [1] = str }
end

-- statReturn : (number, expr*) -> (stat)
function tlast.statReturn (pos, ...)
  return { tag = "Return", pos = pos, [1] = tlast.explist(pos, ...) }
end

-- statBreak : (number) -> (stat)
function tlast.statBreak (pos)
  return { tag = "Break", pos = pos }
end

-- statFuncSet : (number, lhs, expr) -> (stat)
function tlast.statFuncSet (pos, lhs, expr)
  if lhs.is_method then
    table.insert(expr[1], 1, { tag = "Id", [1] = "self" })
  end
  return { tag = "Set", pos = pos, [1] = { tag="VarList", lhs }, [2] = { tag="ExpList", expr } }
end

-- statSet : (expr*) -> (boolean, stat?)
function tlast.statSet (...)
  local vl = { ... }
  local el = vl[#vl]
  table.remove(vl)
  for k, v in ipairs(vl) do
    if v.tag == "Id" or v.tag == "Index" then
      vl[k] = v
    else
      -- invalid assignment
       return false
    end
  end
  vl.tag = "VarList"
  vl.pos = vl[1].pos
  return true, { tag = "Set", pos = vl.pos, [1] = vl, [2] = el }
end

-- statApply : (expr) -> (boolean, stat?)
function tlast.statApply (expr)
  if expr.tag == "Call" or expr.tag == "Invoke" then
    return true, expr
  else
    -- invalid statement
    return false
  end
end

-- statRequire : (number, string) -> (stat)
function tlast.statRequire (pos, modname)
  return { tag = "Require", pos = pos, [1] = modname }
end

-- statLocalTypeDec : (stat) -> (stat)
function tlast.statLocalTypeDec (stat)
  stat.is_local = true
  return stat
end

-- parlist

-- parList0 : (number) -> (parlist)
function tlast.parList0 (pos)
  return { tag = "ParList", pos = pos }
end

-- parList1 : (number, ident) -> (parlist)
function tlast.parList1 (pos, vararg)
  return { tag = "ParList", pos = pos, [1] = vararg }
end

-- parList2 : (number, namelist, ident?) -> (parlist)
function tlast.parList2 (pos, namelist, vararg)
  if vararg then table.insert(namelist, vararg) end
  namelist.tag = "ParList"
  return namelist
end

-- fieldlist

-- fieldPair : (number, expr, expr) -> (field)
function tlast.fieldPair (pos, e1, e2)
  return { tag = "Pair", pos = pos, [1] = e1, [2] = e2 }
end

-- expr

-- exprNil : (number) -> (expr)
function tlast.exprNil (pos)
  return { tag = "Nil", pos = pos }
end

-- exprDots : (number) -> (expr)
function tlast.exprDots (pos)
  return { tag = "Dots", pos = pos }
end

-- exprTrue : (number) -> (expr)
function tlast.exprTrue (pos)
  return { tag = "True", pos = pos }
end

-- exprFalse : (number) -> (expr)
function tlast.exprFalse (pos)
  return { tag = "False", pos = pos }
end

-- exprNumber : (number, number) -> (expr)
function tlast.exprNumber (pos, num)
  return { tag = "Number", pos = pos, [1] = num }
end

-- exprString : (number, string) -> (expr)
function tlast.exprString (pos, str)
  return { tag = "String", pos = pos, [1] = str }
end

-- exprFunction : (number, parlist, stat) -> (expr)
function tlast.exprFunction (pos, parlist, stat)
  return { tag = "Function", pos = pos, [1] = parlist, [2] = stat }
end

-- exprTable : (number, field*) -> (expr)
function tlast.exprTable (pos, ...)
  return { tag = "Table", pos = pos, ... }
end

-- exprUnaryOp : (string, expr) -> (expr)
function tlast.exprUnaryOp (op, e)
  return { tag = "Op", pos = e.pos, [1] = op, [2] = e }
end

-- exprBinaryOp : (expr, string?, expr?) -> (expr)
function tlast.exprBinaryOp (e1, op, e2)
  if not op then
    return e1
  elseif op == "add" or
         op == "sub" or
         op == "mul" or
         op == "idiv" or
         op == "div" or
         op == "mod" or
         op == "pow" or
         op == "concat" or
         op == "band" or
         op == "bor" or
         op == "bxor" or
         op == "shl" or
         op == "shr" or
         op == "eq" or
         op == "lt" or
         op == "le" or
         op == "and" or
         op == "or" then
    return { tag = "Op", pos = e1.pos, [1] = op, [2] = e1, [3] = e2 }
  elseif op == "ne" then
    return tlast.exprUnaryOp ("not", tlast.exprBinaryOp(e1, "eq", e2))
  elseif op == "gt" then
    return { tag = "Op", pos = e1.pos, [1] = "lt", [2] = e2, [3] = e1 }
  elseif op == "ge" then
    return { tag = "Op", pos = e1.pos, [1] = "le", [2] = e2, [3] = e1 }
  end
end

-- exprParen : (number, expr) -> (expr)
function tlast.exprParen (pos, e)
  return { tag = "Paren", pos = pos, [1] = e }
end

-- exprSuffixed : (expr, expr?) -> (expr)
function tlast.exprSuffixed (e1, e2)
  if e2 then
    if e2.tag == "Call" or e2.tag == "Invoke" then
		e2.pos = e1.pos
		e2[1] = e1
		return e2
    elseif e2.tag == "Index" then
      return { tag = "Index", pos = e1.pos, [1] = e1, [2] = e2[1] }
    end
  else
	  error("exprSuffixed args exception")
	  return e1
  end
end

-- exprIndex : (number, expr) -> (lhs)
function tlast.exprIndex (pos, e)
  return { tag = "Index", pos = pos, [1] = e }
end

-- ident : (number, string) -> (ident)
function tlast.ident (pos, str)
  return { tag = "Id", pos = pos, [1] = str }
end

-- index : (number, expr, expr) -> (lhs)
function tlast.index (pos, e1, e2)
  return { tag = "Index", pos = pos, [1] = e1, [2] = e2 }
end

-- identDots : (number, type?) -> (expr)
function tlast.identDots (pos, t)
  return { tag = "Dots", pos = pos, [1] = t }
end

-- funcName : (ident, ident, true?) -> (lhs)
function tlast.funcName (ident1, ident2, is_method)
  if ident2 then
    local t = { tag = "Index", pos = ident1.pos }
    t[1] = ident1
    t[2] = ident2
    if is_method then t.is_method = is_method end
    return t
  else
    return ident1
  end
end

-- apply

-- call : (number, expr, expr*) -> (apply)
function tlast.call (pos, ...)
  return { tag = "Call", pos = pos, [1] = nil, [2] = tlast.explist(pos, ...) }
end

-- invoke : (number, expr, expr, expr*) -> (apply)
function tlast.invoke (pos, e1, e2, ...)
  return { tag = "Invoke", pos = pos, [1] = nil, [2] = e1, [3] = tlast.explist(pos, ...) }
end

return tlast
