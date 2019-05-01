--[[
This module implements Typed Lua lexer
]]

local tllexer = {}

tllexer.comments = {}

local lpeg = require "lpeg"
lpeg.locale(lpeg)


local function getffp(vSubject, vPos, vContext)
	if vContext.ffp == 0 then
		return vPos, vContext
	else
		return vContext.ffp, vContext
	end
end

local function setffp (vSubject, vPos, vContext, n)
  if vPos > vContext.ffp then
    vContext.ffp = vPos
    vContext.list = {} ;
	vContext.list[n] = n
    vContext.expected = "'" .. n .. "'"
  elseif vPos == vContext.ffp then
    if not vContext.list[n] then
      vContext.list[n] = n
      vContext.expected = "'" .. n .. "', " .. vContext.expected
    end
  end
  return false
end

local function updateffp (name)
  return lpeg.Cmt(lpeg.Carg(1) * lpeg.Cc(name), setffp)
end

local function fix_str (str)
  str = string.gsub(str, "\\a", "\a")
  str = string.gsub(str, "\\b", "\b")
  str = string.gsub(str, "\\f", "\f")
  str = string.gsub(str, "\\n", "\n")
  str = string.gsub(str, "\\r", "\r")
  str = string.gsub(str, "\\t", "\t")
  str = string.gsub(str, "\\v", "\v")
  str = string.gsub(str, "\\\n", "\n")
  str = string.gsub(str, "\\\r", "\r")
  str = string.gsub(str, "\\'", "'")
  str = string.gsub(str, '\\"', '"')
  str = string.gsub(str, '\\\\', '\\')
  return str
end

tllexer.Shebang = lpeg.P("#") * (lpeg.P(1) - lpeg.P("\n"))^0 * lpeg.P("\n")

local Space = lpeg.space^1

local Equals = lpeg.P("=")^0
local Open = "[" * lpeg.Cg(Equals, "init") * "["
local Close = "]" * lpeg.C(Equals) * "]"
local CloseEQ = lpeg.Cmt(Close * lpeg.Cb("init"),
                         function (s, i, a, b) return a == b end)

local LongString = Open * lpeg.P("\n")^-1 *lpeg.C((lpeg.P(1) - CloseEQ)^0) * Close /
                   function (s, o) return s end


-- comment's start charactor cann't be @
local LongComment = (lpeg.P("--") * Open * (-lpeg.P("@")) * lpeg.C((lpeg.P(1) - CloseEQ)^0) * Close ) /
                   function (s, o)
					   tllexer.comments[#tllexer.comments+1] = s
					   return
				   end

-- comment's start charactor cann't be @
local ShortComment = (lpeg.P("--") * (-lpeg.P("@")) * (-lpeg.P("[[@")) * lpeg.C((lpeg.P(1) - lpeg.P("\n"))^0)) /
                function (s)
                  tllexer.comments[#tllexer.comments+1] = s
                  return
                end

local Comment = LongComment + ShortComment

tllexer.Skip = (Space + Comment)^0

local idStart = lpeg.alpha + lpeg.P("_")
local idRest = lpeg.alnum + lpeg.P("_")

local Keywords = lpeg.P("and") + "break" + "do" + "elseif" + "else" + "end" +
                 "false" + "for" + "function" + "goto" + "if" + "in" +
                 "local" + "nil" + "not" + "or" + "repeat" + "return" +
                 "then" + "true" + "until" + "while"

tllexer.Reserved = Keywords * -idRest

local Identifier = idStart * idRest^0

tllexer.Name = -tllexer.Reserved * lpeg.C(Identifier) * -idRest

tllexer.TypeChunkString = lpeg.P("--") * Open * (lpeg.P("@")) * lpeg.C((lpeg.P(1) - CloseEQ)^0) * Close
tllexer.TypeDecoString = lpeg.P("--@")*lpeg.C((lpeg.P(1) - lpeg.P("\n"))^0*lpeg.P("\n"))

function tllexer.token (pat, name)
  return pat * tllexer.Skip + updateffp(name) * lpeg.P(false)
end

function tllexer.symb (str)
  return tllexer.token(lpeg.P(str), str)
end

function tllexer.decokw(str)
  return tllexer.decotoken(lpeg.P(str)*-idRest, str)
end

function tllexer.kw (str)
  return tllexer.token(lpeg.P(str) * -idRest, str)
end

local Hex = (lpeg.P("0x") + lpeg.P("0X")) * lpeg.xdigit^1
local Expo = lpeg.S("eE") * lpeg.S("+-")^-1 * lpeg.digit^1
local Float = (((lpeg.digit^1 * lpeg.P(".") * lpeg.digit^0) +
              (lpeg.P(".") * lpeg.digit^1)) * Expo^-1) +
              (lpeg.digit^1 * Expo)
local Int = lpeg.digit^1

tllexer.Number = lpeg.C(Hex + Float + Int) / tonumber

local ShortString = lpeg.P('"') *
                    lpeg.C(((lpeg.P('\\') * lpeg.P(1)) + (lpeg.P(1) - lpeg.P('"')))^0) *
                    lpeg.P('"') +
                    lpeg.P("'") *
                    lpeg.C(((lpeg.P("\\") * lpeg.P(1)) + (lpeg.P(1) - lpeg.P("'")))^0) *
                    lpeg.P("'")

tllexer.String = LongString + (ShortString / fix_str)

-- for error reporting
local OneWord = tllexer.Name + tllexer.Number + tllexer.String + tllexer.Reserved + lpeg.P("...") + lpeg.P(1)

function tllexer.report_error ()
  return lpeg.Cmt(lpeg.Carg(1), getffp) * (lpeg.C(OneWord) + lpeg.Cc("EOF")) /
  function (t, u)
    t.unexpected = u
    return nil, tllexer.context_errormsg(t)
  end
end

function tllexer.throw_context()
  return lpeg.Cmt(lpeg.Carg(1), getffp) * (lpeg.C(OneWord) + lpeg.Cc("EOF")) /
  function (vContext, u)
    vContext.unexpected = u
	vContext.ffp = vContext.ffp or 1
    return nil, vContext
  end
end

function tllexer.context_lineno(vContext)
	local nSubject = vContext.subject
	local nPos = vContext.ffp
	if nPos <= 1 then return 1, 1 end
	-- replace all char except "\n"
	local nRest, nLine = nSubject:sub(1,nPos):gsub("[^\n]*\n", "")
	local nColumn = #nRest ~= 0 and #nRest or 1
	return nLine + 1, nColumn
end

function tllexer.context_errormsg(vRootContext)
	-- use sub_context's unexpected & expecting, use root context's ffp
	local nErrorContext = vRootContext
	while nErrorContext.sub_context do
		nErrorContext = nErrorContext.sub_context
	end
	local nLine, nColumn = tllexer.context_lineno(vRootContext)
	return string.format("%s:%d:%d: syntax error, unexpected '%s', expecting %s",
	vRootContext.filename, nLine, nColumn, nErrorContext.unexpected, nErrorContext.expected)
end

function tllexer.create_context(vSubject, vFileName)
	return {
		subject = vSubject,
		filename = vFileName,
		ffp = 0,		 -- ffp == forward first position ???
		unexpected = nil,
		expected = nil,
		sub_context = nil,
	}
end

return tllexer
