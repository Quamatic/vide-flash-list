local function isSameRange(left: { number }, right: { number })
	return left[1] == right[1] and left[2] == right[2]
end

return isSameRange
