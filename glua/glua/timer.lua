timer = timer or {}

local timers = {}

function timer.Simple(delay, func)
    if !isnumber(delay)     then error("bad argument #1 to 'Simple' (number expected, got " .. type(delay) .. ")") end
    if !isfunction(func)    then error("bad argument #2 to 'Simple' (function expected, got " .. type(func) .. ")") end
    if !async.Init()        then return false end

    async.Add(function()
        async.Sleep(delay)
        func()
    end)

    return true
end

function timer.Create(identifier, delay, repetitions, func)
    if !isstring(identifier) then error("bad argument #1 to 'Create' (string expected, got " .. type(identifier) .. ")") end
    if !isnumber(delay)      then error("bad argument #2 to 'Create' (number expected, got " .. type(delay) .. ")") end
    if !isnumber(repetitions)then error("bad argument #3 to 'Create' (number expected, got " .. type(repetitions) .. ")") end
    if !isfunction(func)     then error("bad argument #4 to 'Create' (function expected, got " .. type(func) .. ")") end
    if !async.Init()         then return false end

    if timers[identifier] then timers[identifier].id = timers[identifier].id + 1 end   // stop the current timer with the same identifier

    if delay <= 0 then
        delay = 1/66
    end

    local t = {
        i = 0,
        id = 0,
        delay = delay,
        repetitions = repetitions,
        func = func,
        last_run = CurTime(),
        last_end = CurTime(),
        last_sleep = 0,
        sleep_extra = 0,
        paused_after = 0,
        paused = false
    }

    local this_id = t.id

    async.Add(function()
        while t.repetitions <= 0 or t.i < t.repetitions do
            t.last_sleep = t.delay - (t.last_end - t.last_run) - t.sleep_extra
            async.Sleep(t.last_sleep)

            if(this_id != t.id) then
                return
            end

            t.i = t.i + 1
            t.last_run = CurTime()
            t.sleep_extra = (t.last_run - t.last_end) - t.delay
            t.sleep_extra = t.delay - (-t.sleep_extra + t.last_sleep)
            t.sleep_extra = t.sleep_extra < 0 and 0 or t.sleep_extra

            t.func()
            t.last_end = CurTime()
        end

        timers[identifier] = nil // timer died after completing all its repetitions
    end)

    timers[identifier] = t
    return true
end

function timer.UnPause(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'UnPause' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t or !t.paused then return false end

    t.id = t.id + 1
    t.paused = false

    // unpause is a bit special as we want to continue sleeping where we left off
    local this_id = t.id

    async.Add(function()
        async.Sleep(t.delay - t.paused_after)

        if(this_id != t.id) then
            return
        end

        t.i = t.i + 1
        t.last_run = CurTime()
        t.sleep_extra = 0

        t.func()
        t.last_end = CurTime()

        while t.repetitions <= 0 or t.i < t.repetitions do
            t.last_sleep = t.delay - (t.last_end - t.last_run) - t.sleep_extra
            async.Sleep(t.last_sleep)

            if(this_id != t.id) then
                return
            end

            t.i = t.i + 1
            t.last_run = CurTime()
            t.sleep_extra = (t.last_run - t.last_end) - t.delay
            t.sleep_extra = t.delay - (-t.sleep_extra + t.last_sleep)
            t.sleep_extra = t.sleep_extra < 0 and 0 or t.sleep_extra

            t.func()
            t.last_end = CurTime()
        end

        timers[identifier] = nil // timer died after completing all its repetitions
    end)

    return true
end

function timer.Pause(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'Pause' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t or t.paused then return false end

    t.id = t.id + 1
    t.paused = true
    t.paused_after = CurTime() - t.last_run

    return true
end

function timer.Adjust(identifier, delay, repetitions, func)
    if !isstring(identifier) then error("bad argument #1 to 'Adjust' (string expected, got " .. type(identifier) .. ")") end
    if !isnumber(delay)      then error("bad argument #2 to 'Adjust' (number expected, got " .. type(delay) .. ")") end

    local t = timers[identifier]
    if !t then return false end

    repetitions = isnumber(repetitions) and repetitions or timer.RepsLeft(identifier)
    func = isfunction(func) and func or t.func

    timer.Create(identifier, delay, repetitions, func)
    return true
end

function timer.RepsLeft(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'RepsLeft' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t then return end

    return t.repetitions <= 0 and -1 or t.repetitions - t.i
end

function timer.TimeLeft(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'TimeLeft' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t then return end

    local left
    if t.paused then
       left = - (t.delay - t.paused_after)
    else
       left = t.delay - (CurTime() - t.last_run)
    end

    return left
end

function timer.Check()
end

function timer.Exists(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'Exists' (string expected, got " .. type(identifier) .. ")") end
    return timers[identifier] != nil
end

function timer.Remove(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'Remove' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t then return false end

    t.id = t.id + 1
    timers[identifier] = nil

    return true
end

timer.Destroy = timer.Remove

function timer.Start(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'Start' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t then return false end

    timer.Pause(identifier)
    t.paused_after = 0
    timer.UnPause(identifier)

    return true
end

function timer.Stop(identifier)
    if !isstring(identifier) then error("bad argument #1 to 'Stop' (string expected, got " .. type(identifier) .. ")") end

    local t = timers[identifier]
    if !t then return false end

    timer.Pause(identifier)
    t.paused_after = 0

    return true
end
