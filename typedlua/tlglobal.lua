
local seri = require "typedlua/seri"
local tlast = require "typedlua.tlast"
local tllexer = require "typedlua.tllexer"
local tlst = require "typedlua.tlst"
local tltype = require "typedlua.tltype"

local tlglobal = {}

local traverse_stm, traverse_exp, traverse_var
local traverse_block, traverse_explist, traverse_varlist, traverse_parlist

function traverse_parlist (env, parlist)
  local len = #parlist
  if len > 0 and parlist[len].tag == "Dots" then
    local t = parlist[len][1] or tltype.Any()
    tlst.set_vararg(env, t)
    len = len - 1
  end
  for i = 1, len do
    tlst.set_local(env, parlist[i])
  end
  return true
end

local function traverse_function (env, exp)
  tlst.begin_function(env)
  tlst.begin_scope(env)
  local status, msg = traverse_parlist(env, exp[1])
  if not status then return status, msg end
  if not exp[3] then
    status, msg = traverse_block(env, exp[2])
    if not status then return status, msg end
  else
    status, msg = traverse_block(env, exp[3])
    if not status then return status, msg end
  end
  tlst.end_scope(env)
  tlst.end_function(env)
  return true
end

local function traverse_op (env, exp)
  local status, msg = traverse_exp(env, exp[2])
  if not status then return status, msg end
  if exp[3] then
    status, msg = traverse_exp(env, exp[3])
    if not status then return status, msg end
  end
  return true
end

local function traverse_paren (env, exp)
  local status, msg = traverse_exp(env, exp[1])
  if not status then return status, msg end
  return true
end

local function traverse_table (env, fieldlist)
  for _, v in ipairs(fieldlist) do
    local tag = v.tag
    if tag == "Pair" or tag == "Const" then
      local status, msg = traverse_exp(env, v[1])
      if not status then return status, msg end
      status, msg = traverse_exp(env, v[2])
      if not status then return status, msg end
    else
      local status, msg = traverse_exp(env, v)
      if not status then return status, msg end
    end
  end
  return true
end

local function traverse_vararg (env, exp)
  if not tlst.is_vararg(env) then
    local msg = "cannot use '...' outside a vararg function"
    return nil, tllexer.syntaxerror(env.subject, exp.pos, env.filename, msg)
  end
  return true
end

local function traverse_call (env, call)
  local status, msg = traverse_exp(env, call[1])
  if not status then return status, msg end
  for i=2, #call do
    status, msg = traverse_exp(env, call[i])
    if not status then return status, msg end
  end
  return true
end

local function traverse_invoke (env, invoke)
  local status, msg = traverse_exp(env, invoke[1])
  if not status then return status, msg end
  for i=3, #invoke do
    status, msg = traverse_exp(env, invoke[i])
    if not status then return status, msg end
  end
  return true
end

local function traverse_assignment (env, stm)
  local status, msg = traverse_varlist(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_explist(env, stm[2])
  if not status then return status, msg end
  return true
end

local function traverse_const_assignment (env, stm)
  local status, msg = traverse_var(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_exp(env, stm[2])
  if not status then return status, msg end
  return true
end

local function traverse_break (env, stm)
  if not tlst.insideloop(env) then
    local msg = "<break> not inside a loop"
    return nil, tllexer.syntaxerror(env.subject, stm.pos, env.filename, msg)
  end
  return true
end

local function traverse_forin (env, stm)
  local status, msg = traverse_explist(env, stm[2])
  if not status then return status, msg end
  tlst.begin_loop(env)
  tlst.begin_scope(env)
  for _, v in ipairs(stm[1]) do
    tlst.set_local(env, v)
  end
  status, msg = traverse_block(env, stm[3])
  if not status then return status, msg end
  tlst.end_scope(env)
  tlst.end_loop(env)
  return true
end

local function traverse_fornum (env, stm)
  local status, msg
  status, msg = traverse_exp(env, stm[2])
  if not status then return status, msg end
  status, msg = traverse_exp(env, stm[3])
  if not status then return status, msg end
  local block
  if stm[5] then
    status, msg = traverse_exp(env, stm[4])
    if not status then return status, msg end
    block = stm[5]
  else
    block = stm[4]
  end
  tlst.begin_loop(env)
  tlst.begin_scope(env)
  tlst.set_local(env, stm[1])
  status, msg = traverse_block(env, block)
  if not status then return status, msg end
  tlst.end_scope(env)
  tlst.end_loop(env)
  return true
end

local function traverse_goto (env, stm)
  tlst.set_pending_goto(env, stm)
  return true
end

local function traverse_if (env, stm)
  local len = #stm
  if len % 2 == 0 then
    for i=1, len, 2 do
      local status, msg = traverse_exp(env, stm[i])
      if not status then return status, msg end
      status, msg = traverse_block(env, stm[i+1])
      if not status then return status, msg end
    end
  else
    for i=1, len-1, 2 do
      local status, msg = traverse_exp(env, stm[i])
      if not status then return status, msg end
      status, msg = traverse_block(env, stm[i+1])
      if not status then return status, msg end
    end
    local status, msg = traverse_block(env, stm[len])
    if not status then return status, msg end
  end
  return true
end

local function traverse_label (env, stm)
  if not tlst.set_label(env, stm[1]) then
    local msg = string.format("label '%s' already defined", stm[1])
    return nil, tllexer.syntaxerror(env.subject, stm.pos, env.filename, msg)
  else
    return true
  end
end

local function traverse_local (env, stm)
  local status, msg = traverse_explist(env, stm[2])
  if not status then return status, msg end
  for _, v in ipairs(stm[1]) do
    tlst.set_local(env, v)
  end
  return true
end

local function traverse_localrec (env, stm)
  tlst.set_local(env, stm[1][1])
  local status, msg = traverse_exp(env, stm[2][1])
  if not status then return status, msg end
  return true
end

local function traverse_repeat (env, stm)
  tlst.begin_loop(env)
  local status, msg = traverse_block(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_exp(env, stm[2])
  if not status then return status, msg end
  tlst.end_loop(env)
  return true
end

local function traverse_return (env, stm)
  local status, msg = traverse_explist(env, stm)
  if not status then return status, msg end
  return true
end

local function traverse_while (env, stm)
  tlst.begin_loop(env)
  local status, msg = traverse_exp(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_block(env, stm[2])
  if not status then return status, msg end
  tlst.end_loop(env)
  return true
end

local function traverse_interface (env, stm)
  local name, t = stm[1], stm[2]
  local status, msg = tltype.checkTypeDec(name, t)
  if not status then
    return nil, tllexer.syntaxerror(env.subject, stm.pos, env.filename, msg)
  end
  if tltype.checkRecursive(t, name) then
    stm[2] = tltype.Recursive(name, t)
  end
  return true
end

function traverse_var (env, var)
  local tag = var.tag
  if tag == "Id" then
    local id, loc, loop, scope = tlst.get_local(env, var[1])
    if not id then
      local e1 = tlast.ident(var.pos, "_ENV")
      local e2 = tlast.exprString(var.pos, var[1])
      var.tag = "Index"
      var[1] = e1
      var[2] = e2
    else
      var.scope = scope
    end
    return true
  elseif tag == "Index" then
    local status, msg = traverse_exp(env, var[1])
    if not status then return status, msg end
    status, msg = traverse_exp(env, var[2])
    if not status then return status, msg end
    return true
  else
    error("trying to traverse a variable, but got a " .. tag)
  end
end

function traverse_varlist (env, varlist)
  for _, v in ipairs(varlist) do
    local status, msg = traverse_var(env, v)
    if not status then return status, msg end
  end
  return true
end

function traverse_exp (env, exp)
  local tag = exp.tag
  if tag == "Nil" or
     tag == "True" or
     tag == "False" or
     tag == "Number" or
     tag == "String" then
    return true
  elseif tag == "Dots" then
    return traverse_vararg(env, exp)
  elseif tag == "Function" then
    return traverse_function(env, exp)
  elseif tag == "Table" then
    return traverse_table(env, exp)
  elseif tag == "Op" then
    return traverse_op(env, exp)
  elseif tag == "Paren" then
    return traverse_paren(env, exp)
  elseif tag == "Call" then
    return traverse_call(env, exp)
  elseif tag == "Invoke" then
    return traverse_invoke(env, exp)
  elseif tag == "Id" or
         tag == "Index" then
    return traverse_var(env, exp)
  else
    error("trying to traverse an expression, but got a " .. tag)
  end
end

function traverse_explist (env, explist)
  for _, v in ipairs(explist) do
    local status, msg = traverse_exp(env, v)
    if not status then return status, msg end
  end
  return true
end

function traverse_stm (env, stm)
  local tag = stm.tag
  if tag == "Do" then
    return traverse_block(env, stm)
  elseif tag == "Set" then
    return traverse_assignment(env, stm)
  elseif tag == "ConstSet" then
    return traverse_const_assignment(env, stm)
  elseif tag == "While" then
    return traverse_while(env, stm)
  elseif tag == "Repeat" then
    return traverse_repeat(env, stm)
  elseif tag == "If" then
    return traverse_if(env, stm)
  elseif tag == "Fornum" then
    return traverse_fornum(env, stm)
  elseif tag == "Forin" then
    return traverse_forin(env, stm)
  elseif tag == "Local" then
    return traverse_local(env, stm)
  elseif tag == "Localrec" then
    return traverse_localrec(env, stm)
  elseif tag == "Goto" then
    return traverse_goto(env, stm)
  elseif tag == "Label" then
    return traverse_label(env, stm)
  elseif tag == "Return" then
    return traverse_return(env, stm)
  elseif tag == "Break" then
    return traverse_break(env, stm)
  elseif tag == "Call" then
    return traverse_call(env, stm)
  elseif tag == "Invoke" then
    return traverse_invoke(env, stm)
  elseif tag == "Interface" then
    return traverse_interface(env, stm)
  else
    error("trying to traverse a statement, but got a " .. tag)
  end
end

function traverse_block (env, block)
  tlst.begin_scope(env)
  for _, v in ipairs(block) do
    local status, msg = traverse_stm(env, v)
    if not status then return status, msg end
  end
  tlst.end_scope(env)
  return true
end

local function verify_pending_gotos (env)
  for s = tlst.get_maxscope(env), 1, -1 do
    for _, v in ipairs(tlst.get_pending_gotos(env, s)) do
      local l = v[1]
      if not tlst.exist_label(env, s, l) then
        local msg = string.format("no visible label '%s' for <goto>", l)
        return nil, tllexer.syntaxerror(env.subject, v.pos, env.filename, msg)
      end
    end
  end
  return true
end

local function traverse (ast, errorinfo, strict)
  assert(type(ast) == "table")
  assert(type(errorinfo) == "table")
  assert(type(strict) == "boolean")
  local env = tlst.new_env(errorinfo.subject, errorinfo.filename, strict)
  local _env = tlast.ident(0, "_ENV")
  tlst.begin_function(env)
  tlst.set_vararg(env, tltype.String())
  tlst.begin_scope(env)
  tlst.set_local(env, _env)
  for _, v in ipairs(ast) do
    local status, msg = traverse_stm(env, v)
    if not status then return status, msg end
  end
  tlst.end_scope(env)
  tlst.end_function(env)
  local status, msg = verify_pending_gotos(env)
  if not status then return status, msg end
  -- print("tlst", seri(env))
  return ast, env
end

local function lineno (s, i)
  if i == 1 then return 1, 1 end
  local rest, num = s:sub(1,i):gsub("[^\n]*\n", "")
  local r = #rest
  return 1 + num, r ~= 0 and r or 1
end

local function fixup_lin_col(subject, node)
  if node.pos then
    node.l, node.c = lineno(subject, node.pos)
  end
  for _, child in ipairs(node) do
    if type(child) == "table" then
      fixup_lin_col(subject, child)
    end
  end
end

function tlglobal.visit(ast, subject, filename, strict, integer)
  local errorinfo = { subject = subject, filename = filename }
  return traverse(ast, errorinfo, strict)
end

return tlglobal
