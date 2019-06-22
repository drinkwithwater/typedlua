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

tllexer.TypeDefineChunkString = lpeg.P("--") * Open * (lpeg.P("@")) * lpeg.Cp()*lpeg.C((lpeg.P(1) - CloseEQ)^0) * Close
tllexer.TypeDecoPrefixString = lpeg.P("--@")*lpeg.Cp()*lpeg.C((lpeg.P(1) - lpeg.P("\n"))^0)*lpeg.P("\n")
tllexer.TypeDecoSuffixString = lpeg.P("--<")*lpeg.Cp()*lpeg.C((lpeg.P(1) - lpeg.P("\n"))^0)*lpeg.P("\n")

function tllexer.token (pat, name)
  return pat * tllexer.Skip + updateffp(name) * lpeg.P(false)
end

function tllexer.symb (str)
	if str=="-" then
	   return tllexer.token(lpeg.P("-")*-lpeg.P("-"), str)
    else
	   return tllexer.token(lpeg.P(str), str)
	end
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

function tllexer.syntax_error()
  return lpeg.Cmt(lpeg.Carg(1), getffp) * (lpeg.C(OneWord) + lpeg.Cc("EOF")) /
  function (vContext, u)
    vContext.unexpected = u
	vContext.ffp = vContext.ffp or 1
    return false
  end
end

function tllexer.context_errormsg(vRootContext)
	-- use sub_context's unexpected & expecting, use root context's ffp
	local nErrorContext = vRootContext
	while nErrorContext.sub_context do
		nErrorContext = nErrorContext.sub_context
	end
	local nLine, nColumn = tllexer.context_fixup_pos(vRootContext, vRootContext.ffp)
	if nErrorContext.semantic_error then
		return string.format("%s:%d:%d: semantic error, %s",
		vRootContext.filename, nLine, nColumn, nErrorContext.semantic_error)
	else
		return string.format("%s:%d:%d: syntax error, unexpected '%s', expecting %s",
		vRootContext.filename, nLine, nColumn, nErrorContext.unexpected, nErrorContext.expected)
	end
end

function tllexer.create_context(vFileEnv, vOffset)
	return {
		filename = vFileEnv.filename,
		env = vFileEnv,
		ffp = 0,		 -- ffp == forward first position ???
		offset = vOffset or 0,
		unexpected = nil,
		expected = nil,
		sub_context = nil,
		semantic_error = nil,
	}
end

function tllexer.create_split_info_list(vSubject)
	local nStartPos = 1
	local nFinishPos = 0
	local nList = {}
	local nLineCount = 0
	while true do
		nLineCount = nLineCount + 1
		nFinishPos = vSubject:find("\n", nStartPos)
		if nFinishPos then
			nList[#nList + 1] = {start_pos=nStartPos, finish_pos=nFinishPos}
			nStartPos = nFinishPos + 1
		else
			if nStartPos <= #vSubject then
				nList[#nList + 1] = {start_pos=nStartPos, finish_pos=#vSubject}
			end
			break
		end
	end
	return nList
end

function tllexer.context_fixup_pos(vContext, vPos)
	if vPos == 0 then
		return 0, 1
	end
	local nList = vContext.env.split_info_list
	local nLeft = 1
	local nRight = #nList
	assert(nRight>=nLeft)
	if vPos > nList[nRight].finish_pos then
		print("warning pos out of range, "..vPos)
		return nRight, nList[nRight].finish_pos - nList[nRight].start_pos + 1
	elseif vPos < nList[nLeft].start_pos then
		print("warning pos out of range, "..vPos)
		return 1, 1
	end
	local nMiddle = (nLeft + nRight)// 2
	while true do
		local nMiddleInfo = nList[nMiddle]
		if vPos < nMiddleInfo.start_pos then
			nRight = nMiddle - 1
			nMiddle = (nLeft + nRight)// 2
		elseif nMiddleInfo.finish_pos < vPos then
			nLeft = nMiddle + 1
			nMiddle = (nLeft + nRight)// 2
		else
			return nMiddle, vPos - nMiddleInfo.start_pos + 1
		end
	end
end

return tllexer
