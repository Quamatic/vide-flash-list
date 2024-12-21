export type Debounce<T..., R...> = typeof(setmetatable(
	{} :: {
		cancel: () -> (),
		flush: () -> R...,
		pending: () -> boolean,
	},
	{} :: {
		__call: (_: any, T...) -> R...,
	}
))

local function debounce<T..., R...>(callback: (T...) -> R..., wait_: number?): Debounce<T..., R...>
	local wait = wait_ or 0
	local leading = false
	local trailing = true
	local maxWait = 0
	local maxing = false

	local lastCallTime = 0
	local lastInvokeTime = 0
	local lastArgs: any?
	local result: any
	local cancelTimeout: thread?

	local function invoke(time: number)
		local args = lastArgs :: any
		lastArgs = nil
		lastInvokeTime = time
		result = callback(unpack(args))
		return result
	end

	local function trailingEdge(time: number)
		cancelTimeout = nil

		if trailing and lastArgs ~= nil then
			return invoke(time)
		end

		lastArgs = nil
		return result
	end

	local function remainingWait(time: number)
		local timeSinceLastCall = time - lastCallTime
		local timeSinceLastInvoke = time - lastInvokeTime
		local timeWaiting = wait - timeSinceLastCall

		return if maxing then math.min(timeWaiting, maxWait - timeSinceLastInvoke) else timeWaiting
	end

	local function shouldInvoke(time: number)
		local timeSinceLastCall = time - lastCallTime
		local timeSinceLastInvoke = time - lastInvokeTime

		return (
			lastCallTime == nil
			or timeSinceLastCall >= wait
			or timeSinceLastCall < 0
			or (maxing and timeSinceLastInvoke >= maxWait)
		)
	end

	local function timerExpired()
		local time = os.clock()

		if shouldInvoke(time) then
			trailingEdge(time)
			return
		end

		cancelTimeout = task.delay(remainingWait(time), timerExpired)
	end

	local function leadingEdge(time: number)
		lastInvokeTime = time
		cancelTimeout = task.delay(wait, timerExpired)
		return if leading then invoke(time) else result
	end

	local function cancel()
		if cancelTimeout then
			task.cancel(cancelTimeout)
			cancelTimeout = nil
		end
		lastInvokeTime = 0
		lastArgs = nil
		lastCallTime = 0
	end

	local function flush()
		return if cancelTimeout == nil then result else trailingEdge(os.clock())
	end

	local function pending()
		return cancelTimeout ~= nil
	end

	local function debounced(...: T...)
		local time = os.clock()
		local isInvoking = shouldInvoke(time)

		lastArgs = table.pack(...)
		lastCallTime = time

		if isInvoking then
			if cancelTimeout == nil then
				return leadingEdge(lastCallTime)
			end

			if maxing then
				cancelTimeout = task.delay(wait, timerExpired)
				return invoke(lastCallTime)
			end
		end

		if cancelTimeout == nil then
			cancelTimeout = task.delay(wait, timerExpired)
		end

		return result
	end

	return (
		setmetatable({
			cancel = cancel,
			flush = flush,
			pending = pending,
		}, {
			__call = function(_, ...: T...)
				return debounced(...)
			end,
		}) :: any
	) :: Debounce<T..., R...>
end

return debounce
