local function splice<T>(array: { T }, start: number, deleteCount: number?, ...: T): { T }
	local length = #array
	if start > length then
		return {}
	else
		if start < 1 then
			start = math.max(length - math.abs(start) + 1, 1)
		end

		local deleted: { T } = {}
		local count = deleteCount or length

		if count > 0 then
			local lastIndex = math.min(length, start + math.max(0, count - 1))

			for _ = start, lastIndex do
				local value = table.remove(array, start) :: T
				table.insert(deleted, value)
			end
		end

		return deleted
	end
end

return splice
