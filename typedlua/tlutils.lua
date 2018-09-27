
local tlutils = {}

function tlutils.logat(env, pos, msg)
  local function lineno (s, i)
    if i == 1 then return 1, 1 end
    local rest, num = s:sub(1,i):gsub("[^\n]*\n", "")
    local r = #rest
    return 1 + num, r ~= 0 and r or 1
  end

  local l, c = lineno(env.subject, pos)
  print(string.format("%s:%s:%s:%s", env.filename, l, c, tostring(msg)))
end

return tlutils
