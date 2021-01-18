local tltype = {}

function tltype.Literal (vValue)
	return {
		tag = "TLiteral",
		[1] = vValue
	}
end

function tltype.Boolean ()
  return tltype.Base("boolean")
end

function tltype.Number ()
  return tltype.Base("number")
end

function tltype.String ()
  return tltype.Base("string")
end

function tltype.Integer ()
	return tltype.Base("integer")
end

function tltype.tostring (vType)
	local nFunc = assert(formatterDict[vType.tag], "type formatter not found"..vType.tag)
	return vType.tag.."`"..nFunc(vType).."`"
end

function tltype.NativeFunction(vFunc)
end

return tltype
